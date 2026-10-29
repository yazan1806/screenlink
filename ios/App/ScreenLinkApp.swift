import SwiftUI
import Foundation
import UIKit
import Observation
import LiveKit
import VisionKit

@main
struct ScreenLinkApp: App {
    @State private var model = ShareModel()
    @State private var remote = RemoteModel()
    @State private var tab = RemoteModel.hasSavedCredential() ? 1 : 0
    var body: some Scene { WindowGroup {
        TabView(selection:$tab){
            ShareView(model:model).disabled(remote.connected).tabItem{Label("Mirror",systemImage:"iphone")}.tag(0)
            RemoteView(model:remote).disabled(model.connected).tabItem{Label("My PC",systemImage:"desktopcomputer")}.tag(1)
            ScreenLinkSettingsView(remote:remote).tabItem{Label("Settings",systemImage:"gearshape")}.tag(2)
        }.tint(ScreenLinkStyle.accent).onOpenURL{url in
            if url.host == "remote" {tab = 1;remote.receive(url.absoluteString)}
            else {tab = 0;model.receive(url.absoluteString)}
        }
    } }
}

struct Pairing: Identifiable {
    let id: String
    let key: String
    let server: URL
    init(url: URL) throws {
        guard url.scheme == "screenlink", url.host == "pair",
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let serverString = parts.queryItems?.first(where: { $0.name == "server" })?.value,
              let server = URL(string: serverString), server.scheme == "https",
              server.host != nil, server.user == nil, server.password == nil,
              server.query == nil, server.fragment == nil,
              server.path.isEmpty || server.path == "/",
              let id = parts.queryItems?.first(where: { $0.name == "id" })?.value,
              let key = parts.queryItems?.first(where: { $0.name == "key" })?.value,
              id.count == 48, key.count == 48,
              id.allSatisfy({ $0.isHexDigit }), key.allSatisfy({ $0.isHexDigit })
        else { throw ShareError.message("Invalid pairing code. Create a new code on your PC.") }
        self.id = id; self.key = key; self.server = server
    }
}

enum ShareError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}

@MainActor @Observable
final class ShareModel {
    var pairing: Pairing?
    var message = "Open ScreenLink on your PC, then scan its QR code."
    var working = false
    var connected = false
    var preset = "balanced"
    @ObservationIgnored let room = Room()

    func receive(_ text: String) {
        guard !working, !connected else { message = "Disconnect before pairing with another PC."; return }
        do {
            guard let url = URL(string: text) else { throw ShareError.message("Invalid pairing link.") }
            pairing = try Pairing(url: url)
            message = "Check the server address, then connect."
        } catch { message = error.localizedDescription }
    }

    func connect() async {
        guard !working, !connected, let pairing else { return }
        working = true
        defer { working = false }
        do {
            var request = URLRequest(url: pairing.server.appendingPathComponent("api/claim"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(Claim(id: pairing.id, key: pairing.key))
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                let detail = try? JSONDecoder().decode(ServerError.self, from: data)
                throw ShareError.message(detail?.error ?? "Pairing failed. Create a fresh QR code on your PC.")
            }
            let access = try JSONDecoder().decode(Access.self, from: data)
            guard URL(string: access.serverUrl)?.scheme == "wss" else { throw ShareError.message("The media server must use encrypted WSS.") }
            preset = access.preset
            let dimensions: Dimensions
            let bitrate: Int
            switch preset {
            case "fast": dimensions = .h720_169; bitrate = 4000000
            case "detail": dimensions = .h1440_169; bitrate = 20000000
            default: dimensions = .h1080_169; bitrate = 10000000
            }
            let options = RoomOptions(
                defaultScreenShareCaptureOptions: ScreenShareCaptureOptions(
                    dimensions: dimensions, fps: 60, appAudio: true,
                    useBroadcastExtension: false, useScreenCaptureKit: true),
                defaultVideoPublishOptions: VideoPublishOptions(
                    screenShareEncoding: VideoEncoding(maxBitrate: bitrate, maxFps: 60), simulcast: false,
                    preferredCodec: .h264),
                suspendLocalVideoTracksInBackground: false)
            try await room.connect(url: access.serverUrl, token: access.token, roomOptions: options)
            connected = true
            self.pairing = nil
            message = "Connected. Tap Share Screen and select your entire screen in the system picker."
        } catch {
            await room.disconnect()
            pairingFailed(error.localizedDescription)
        }
    }
    private func pairingFailed(_ text: String) { pairing = nil; connected = false; message = text }

    func share() async {
        guard !working, connected else { return }
        working = true
        defer { working = false }
        do {
            // iOS 27 native capture avoids App Group entitlements and a separate broadcast extension.
            // Explicitly select the native capturer so an unavailable picker cannot silently fall back
            // to recording only this app.
            let dimensions: Dimensions = preset == "fast" ? .h720_169 : preset == "detail" ? .h1440_169 : .h1080_169
            let track = await LocalVideoTrack.createIOSScreenShareTrack(options: ScreenShareCaptureOptions(
                dimensions: dimensions, fps: 60, appAudio: true, useBroadcastExtension: false, useScreenCaptureKit: true))
            // Manual rendering feeds captured application audio without opening the microphone.
            try AudioManager.shared.setManualRenderingMode(true)
            try await room.localParticipant.publish(videoTrack: track)
            let audio = await LocalAudioTrack.createTrack(name: "iPhone application audio", options: .noProcessing)
            try await room.localParticipant.publish(audioTrack: audio, options: AudioPublishOptions(dtx: false))
            message = "Sharing screen and app audio to the PC. Lower the iPhone speaker volume if you also hear sound locally. You can switch to other apps."
        } catch { message = error.localizedDescription }
    }

    func stop() async {
        guard !working else { return }
        working = true
        defer { working = false }
        // Disconnecting unpublishes and stops all local capture tracks.
        await room.disconnect()
        try? AudioManager.shared.setManualRenderingMode(false)
        connected = false
        message = "Screen sharing ended. Create a new QR code on the PC to reconnect."
    }
    private struct Claim: Encodable { let id: String; let key: String }
    private struct Access: Decodable { let serverUrl: String; let token: String; let preset: String }
    private struct ServerError: Decodable { let error: String }
}

struct ShareView: View {
    @Bindable var model:ShareModel
    @State private var scanning=false
    @State private var pasted=""
    @State private var help=false
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    BrandHeader(subtitle:"Bring your iPhone to the big screen.")
                    if !model.connected {
                        AppCard {
                            Image(systemName:"iphone.and.arrow.forward").font(.system(size:42,weight:.light)).foregroundStyle(ScreenLinkStyle.accent).accessibilityHidden(true)
                            Text("Share your iPhone.").font(.largeTitle.bold()).tracking(-1)
                            Text("See your screen and hear app audio on your PC. Works across Wi-Fi and mobile data.").foregroundStyle(.secondary)
                            Button{scanning=true}label:{Label("Scan mirror code",systemImage:"qrcode.viewfinder")}.buttonStyle(ScreenLinkPrimaryButton())
                            DisclosureGroup("Use a pairing link instead") {
                                TextField("Paste ScreenLink link",text:$pasted).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                                Button("Read link"){model.receive(pasted);pasted=""}.padding(.top,8)
                            }.font(.subheadline)
                        }
                        if let pairing=model.pairing {
                            AppCard {
                                Label("Ready to connect",systemImage:"checkmark.circle").font(.headline)
                                Text("Only connect if this is the address shown by your PC.").font(.subheadline).foregroundStyle(.secondary)
                                Text(pairing.server.absoluteString).font(.caption.monospaced()).textSelection(.enabled)
                                Button("Connect to PC"){Task{await model.connect()}}.buttonStyle(ScreenLinkPrimaryButton())
                            }
                        } else {
                            AppCard {
                                Text("Get connected").font(.headline)
                                SetupStep(number:1,title:"Open ScreenLink on your PC",detail:"Choose Mirror iPhone to display a private pairing code.")
                                SetupStep(number:2,title:"Scan the code above",detail:"You'll confirm the PC and approve sharing on your iPhone.")
                            }
                        }
                    } else {
                        AppCard {
                            Label("PC connected",systemImage:"checkmark.circle.fill").font(.headline).foregroundStyle(ScreenLinkStyle.accent)
                            Text("Choose what to share.").font(.title.bold())
                            Text("Apple will ask you to approve your screen. Sharing can include other apps and their audio.").foregroundStyle(.secondary)
                            TimelineView(.periodic(from:.now,by:1)){_ in
                                if !model.room.localParticipant.isScreenShareEnabled(){
                                    Button{Task{await model.share()}}label:{Label("Share screen",systemImage:"rectangle.on.rectangle")}.buttonStyle(ScreenLinkPrimaryButton())
                                } else {Label("Screen sharing is active",systemImage:"record.circle").foregroundStyle(.red)}
                            }
                            Button("Stop sharing and disconnect",role:.destructive){Task{await model.stop()}}.frame(minHeight:44)
                        }
                    }
                    InfoBanner(text:model.message)
                    Label("Sharing starts only after your approval.",systemImage:"lock.shield").font(.footnote).foregroundStyle(.secondary).padding(.horizontal,4)
                }.padding(20).frame(maxWidth:620).frame(maxWidth:.infinity)
            }.background(ScreenLinkStyle.canvas)
                .navigationTitle("Mirror").navigationBarTitleDisplayMode(.inline)
                .toolbar{ToolbarItem(placement:.topBarTrailing){Button{help=true}label:{Image(systemName:"questionmark.circle")}.accessibilityLabel("Help with mirroring")}}
                .disabled(model.working)
                .overlay{if model.working{ProgressView("Connecting…").padding(24).background(.regularMaterial,in:RoundedRectangle(cornerRadius:20))}}
                .sheet(isPresented:$help){ScreenLinkInfoSheet()}
                .sheet(isPresented:$scanning){NavigationStack{QRScanner{text in scanning=false;model.receive(text)}onError:{text in scanning=false;model.message=text}.navigationTitle("Scan mirror code").navigationBarTitleDisplayMode(.inline).toolbar{Button("Cancel"){scanning=false}}}}
        }
    }
}

struct QRScanner: UIViewControllerRepresentable {
    let onRead: (String) -> Void
    let onError: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onRead: onRead, onError: onError) }
    func makeUIViewController(context: Context) -> UIViewController {
        guard DataScannerViewController.isSupported, DataScannerViewController.isAvailable else {
            DispatchQueue.main.async { onError("Camera scanning is unavailable. Paste the pairing link instead.") }
            return UIViewController()
        }
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced, recognizesMultipleItems: false, isGuidanceEnabled: true, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        DispatchQueue.main.async {
            do { try scanner.startScanning() }
            catch { onError(error.localizedDescription) }
        }
        return scanner
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) {
        (uiViewController as? DataScannerViewController)?.stopScanning()
    }
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onRead: (String) -> Void
        let onError: (String) -> Void
        var consumed = false
        init(onRead: @escaping (String) -> Void, onError: @escaping (String) -> Void) { self.onRead = onRead; self.onError = onError }
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !consumed else { return }
            for item in addedItems {
                if case let .barcode(code) = item, let text = code.payloadStringValue, text.hasPrefix("screenlink://") {
                    consumed = true; dataScanner.stopScanning(); onRead(text); return
                }
            }
        }
        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            onError("Camera scanning stopped. Paste the pairing link instead.")
        }
    }
}
