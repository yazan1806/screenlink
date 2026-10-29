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
    var saved = UserDefaults.standard.bool(forKey: "remoteDeviceSaved")
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
            connected = true;message = "Tap the desktop to click. Use the controls below to type or scroll."
        } catch { await discovery.disconnect();await room.disconnect();message = error.localizedDescription }
    }
    func send(_ value: [String:Any]) {
        guard connected, let data = try? JSONSerialization.data(withJSONObject:value) else { return }
        Task { do { try await room.localParticipant.publish(data:data,options:DataPublishOptions(topic:"screenlink-input",reliable:true)) } catch {message = error.localizedDescription} }
    }
    func stop() async {await room.disconnect();connected = false;message = "Disconnected from your PC."}
    func forget() {
        let query:[String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"personal.screenlink",kSecAttrAccount as String:account]
        SecItemDelete(query as CFDictionary);saved = false;UserDefaults.standard.removeObject(forKey:"remoteDeviceSaved")
        message = "PC removed from this iPhone. You can also revoke authorization from Windows."
    }
}

struct RemoteView: View {
    @Bindable var model: RemoteModel
    @State private var scanning = false
    @State private var text = ""
    @State private var fullscreen = false
    var body: some View {
        NavigationStack {
            VStack(spacing:12) {
                if !fullscreen { Text(model.message).font(.footnote).padding(.horizontal) }
                if model.connected {
                    TimelineView(.periodic(from:.now,by:0.5)) { _ in
                        if let track = model.room.remoteParticipants.values.first?.videoTracks.first?.track as? VideoTrack {
                            GeometryReader { geo in
                                let d = track.dimensions
                                let ratio = CGFloat(d?.width ?? 1920) / CGFloat(max(1,d?.height ?? 1080))
                                let w = min(geo.size.width,geo.size.height * ratio)
                                let h = w / ratio
                                SwiftUIVideoView(track,layoutMode:.fit,mirrorMode:.off)
                                    .frame(width:w,height:h)
                                    .contentShape(Rectangle())
                                    .gesture(SpatialTapGesture().onEnded {tap in model.send(["type":"click","x":Double(tap.location.x / w),"y":Double(tap.location.y / h)])})
                                    .position(x:geo.size.width / 2,y:geo.size.height / 2)
                            }.background(.black)
                        } else {ProgressView("Waiting for PC screen…").frame(maxWidth:.infinity,maxHeight:.infinity)}
                    }
                    HStack {
                        Button("Scroll ↑"){model.send(["type":"scroll","delta":360])}
                        Button("Scroll ↓"){model.send(["type":"scroll","delta":-360])}
                        Button(fullscreen ? "Exit fullscreen" : "Fullscreen"){fullscreen.toggle()}
                    }.font(.footnote)
                    HStack {
                        TextField("Type on PC",text:$text).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                        Button("Send"){model.send(["type":"text","text":String(text.prefix(1024))]);text = ""}
                    }.padding(.horizontal)
                    HStack {
                        ForEach(["Enter","Backspace","Tab","Escape"],id:\.self){key in Button(key){model.send(["type":"key","key":key])}}
                    }.font(.caption)
                    Button("Disconnect",role:.destructive){Task{await model.stop()}}
                } else {
                    if model.saved {Button("Connect to my PC"){Task{await model.connect()}}.buttonStyle(.borderedProminent)}
                    Button("Scan Remote PC authorization QR"){scanning = true}
                    if model.pending != nil {Button("Authorize this PC"){Task{await model.authorize()}}.buttonStyle(.borderedProminent)}
                    if model.saved {Button("Forget saved PC",role:.destructive){model.forget()}}
                    Text("Your PC must be on, signed in, and running ScreenLink. Remote access works over different networks. Windows security prompts and the sign-in screen cannot be controlled.").font(.footnote).foregroundStyle(.secondary).padding()
                    Spacer()
                }
            }
            .navigationTitle(fullscreen ? "" : "Remote PC")
            .toolbar(fullscreen ? .hidden : .visible,for:.navigationBar)
            .disabled(model.working)
            .overlay{if model.working {ProgressView().padding().background(.regularMaterial)}}
            .sheet(isPresented:$scanning){NavigationStack{QRScanner{text in scanning = false;model.receive(text)}onError:{error in scanning = false;model.message = error}.toolbar{Button("Cancel"){scanning = false}}}}
        }
    }
}
