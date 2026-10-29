import SwiftUI
import LiveKit
import Observation
import LocalAuthentication
import Security

private struct RemoteDevice: Codable {
    let id: String
    let key: String
    let server: String
    let serverUrl: String
    let discoveryToken: String
}

@MainActor @Observable
final class RemoteModel {
    var message = "Authorize this iPhone using the Remote PC QR in your Windows app."
    var pending: URL?
    var connected = false
    var working = false
    var saved = RemoteModel.hasSavedCredential()
    var pointer = CGPoint(x: 0.5, y: 0.5)
    var dragging = false
    @ObservationIgnored private var inputTask: Task<Void,Never>?
    @ObservationIgnored private var lastMove = Date.distantPast
    static func hasSavedCredential() -> Bool {
        let query: [String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"personal.screenlink",kSecAttrAccount as String:"ScreenLinkRemoteDevice",kSecReturnAttributes as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var attributes: CFTypeRef?
        return SecItemCopyMatching(query as CFDictionary,&attributes) == errSecSuccess
    }
    @ObservationIgnored let room = Room()
    private let account = "ScreenLinkRemoteDevice"

    func receive(_ text: String) {
        guard !connected, let url = URL(string: text), url.scheme == "screenlink", url.host == "remote",
              let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let server = c.queryItems?.first(where: {$0.name == "server"})?.value,
              validServer(server) != nil,
              let id = c.queryItems?.first(where: {$0.name == "id"})?.value, id.count == 64, id.allSatisfy(\.isHexDigit),
              let key = c.queryItems?.first(where: {$0.name == "key"})?.value, key.count == 64, key.allSatisfy(\.isHexDigit)
        else { message = "Invalid remote authorization code."; return }
        pending = url
        message = "Only authorize a PC you own. This grants access to its desktop and keyboard."
    }
    private func validServer(_ text: String) -> URL? {
        guard let u = URL(string: text), u.scheme == "https", u.host != nil, u.user == nil, u.password == nil,
              u.query == nil, u.fragment == nil, u.path.isEmpty || u.path == "/" else { return nil }
        return u
    }
    private func request<T: Decodable>(_ server: URL, path: String, key: String? = nil, body: [String:String] = [:]) async throws -> T {
        var request = URLRequest(url: server.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key { request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONEncoder().encode(body)
        let (data,response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ShareError.message("Remote connection failed. Check that ScreenLink is running and this iPhone is still authorized.") }
        return try JSONDecoder().decode(T.self, from: data)
    }
    func authorize() async {
        guard !working, let pending, let parts = URLComponents(url: pending, resolvingAgainstBaseURL: false) else { return }
        working = true
        defer { working = false }
        do {
            let values = (parts.queryItems ?? []).reduce(into: [String:String]()) { $0[$1.name] = $1.value ?? "" }
            guard let server = validServer(values["server"] ?? "") else { return }
            let device: RemoteDevice = try await request(server, path: "api/remote/claim", body: ["id":values["id"] ?? "","key":values["key"] ?? ""])
            let query: [String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"personal.screenlink",kSecAttrAccount as String:account]
            SecItemDelete(query as CFDictionary)
            var item = query
            item[kSecValueData as String] = try JSONEncoder().encode(device)
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary,nil) == errSecSuccess else { throw ShareError.message("Could not save the remote credential in Keychain.") }
            saved = true; UserDefaults.standard.set(true, forKey:"remoteDeviceSaved");self.pending = nil
            message = "PC saved. Connect with Face ID or your device passcode. Keep ScreenLink running on the PC."
        } catch { message = error.localizedDescription }
    }
    func connect() async {
        guard !working, !connected else { return }
        working = true
        defer { working = false }
        let discovery = Room()
        do {
            let context = LAContext()
            guard try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Connect to your remote PC") else { return }
            let query: [String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"personal.screenlink",kSecAttrAccount as String:account,kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
            var result: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary,&result) == errSecSuccess, let data = result as? Data else { throw ShareError.message("Authorize this iPhone again from the PC.") }
            let device = try JSONDecoder().decode(RemoteDevice.self, from:data)
            message = "Finding your PC…"
            // Discovery grants no video, audio or data access. Actual access requires the revocable device key.
            try await discovery.connect(url:device.serverUrl,token:device.discoveryToken)
            struct Location: Decodable {let server:String}
            guard let metadata = discovery.metadata?.data(using:.utf8), let location = try? JSONDecoder().decode(Location.self,from:metadata), let server = validServer(location.server) else { throw ShareError.message("PC address unavailable. Open ScreenLink on the PC.") }
            await discovery.disconnect()
            struct Access: Decodable {let serverUrl:String;let token:String}
            let access: Access = try await request(server,path:"api/remote/connect",key:device.key)
            try AudioManager.shared.setManualRenderingMode(false)
            try await room.connect(url:access.serverUrl,token:access.token)
            connected = true;message = "Swipe to move the mouse. Tap to click; use two fingers to scroll. Hold, then move to drag."
        } catch { await discovery.disconnect();await room.disconnect();message = error.localizedDescription }
    }
    func send(_ value: [String:Any]) {
        guard connected, let data = try? JSONSerialization.data(withJSONObject:value) else { return }
        let previous = inputTask
        inputTask = Task { [weak self] in
            await previous?.value
            guard let self, self.connected else { return }
            do { try await self.room.localParticipant.publish(data:data,options:DataPublishOptions(topic:"screenlink-input",reliable:true)) }
            catch { self.message = error.localizedDescription }
        }
    }
    func moveMouse(_ delta: CGSize, in size: CGSize) {
        pointer.x = min(1,max(0,pointer.x + delta.width / max(1,size.width) * 1.4))
        pointer.y = min(1,max(0,pointer.y + delta.height / max(1,size.height) * 1.4))
        if Date().timeIntervalSince(lastMove) >= 1.0 / 60.0 {
            lastMove = Date(); send(["type":"move","x":Double(pointer.x),"y":Double(pointer.y)])
        }
    }
    func clickMouse(_ type: String = "click") { send(["type":type,"x":Double(pointer.x),"y":Double(pointer.y)]) }
    func dragMouse(_ held: Bool) {
        dragging = held
        clickMouse(held ? "mouseDown" : "mouseUp")
    }
    func releaseMouse() { dragging = false;send(["type":"release"] ) }
    func stop() async {
        releaseMouse();await inputTask?.value
        await room.disconnect();connected = false;message = "PC saved. Connect again from anywhere without scanning a QR."
    }
    func forget() {
        let query:[String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"personal.screenlink",kSecAttrAccount as String:account]
        SecItemDelete(query as CFDictionary);saved = false;UserDefaults.standard.removeObject(forKey:"remoteDeviceSaved")
        message = "PC removed from this iPhone. You can also revoke authorization from Windows."
    }
}

struct RemoteView: View {
    @Bindable var model: RemoteModel
    @State private var scanning = false
    @State private var fullscreen = false
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                VStack(spacing:16) {
                    if model.connected {
                        RemoteSessionView(model:model,fullscreen:false,onFullscreen:{fullscreen = true})
                    } else {
                        Text(model.message).font(.footnote).padding(.horizontal)
                        if model.saved {
                            Label("Your saved PC",systemImage:"desktopcomputer").font(.title2.bold())
                            Button("Connect to saved PC"){Task{await model.connect()}}.buttonStyle(.borderedProminent).controlSize(.large)
                            Text("Use Face ID or your passcode. Connect over mobile data or another Wi-Fi network—even from another country. No QR is needed after authorization.").font(.footnote).foregroundStyle(.secondary).padding(.horizontal)
                        }
                        Button(model.saved ? "Authorize a different PC" : "Authorize a PC · scan once"){scanning = true}
                        if model.pending != nil {Button("Authorize this PC"){Task{await model.authorize()}}.buttonStyle(.borderedProminent)}
                        if model.saved {Button("Forget saved PC",role:.destructive){model.forget()}}
                        Text("Keep the PC on, signed in and running ScreenLink. Windows sign-in and security prompts cannot be controlled remotely.").font(.footnote).foregroundStyle(.secondary).padding()
                        Spacer()
                    }
                }
                .onChange(of:geo.size.width > geo.size.height){_,landscape in if landscape && model.connected {fullscreen = true}}
                .onChange(of:model.connected){_,connected in if connected && geo.size.width > geo.size.height {fullscreen = true};if !connected {fullscreen = false}}
            }
            .navigationTitle("Remote PC")
            .disabled(model.working)
            .overlay{if model.working {ProgressView().padding().background(.regularMaterial)}}
            .sheet(isPresented:$scanning){NavigationStack{QRScanner{text in scanning = false;model.receive(text)}onError:{error in scanning = false;model.message = error}.toolbar{Button("Cancel"){scanning = false}}}}
            .fullScreenCover(isPresented:$fullscreen){
                RemoteSessionView(model:model,fullscreen:true,onFullscreen:{fullscreen = false})
                    .ignoresSafeArea().statusBarHidden(true).persistentSystemOverlays(.hidden)
                    .onChange(of:model.connected){_,connected in if !connected {fullscreen = false}}
            }
        }
    }
}
