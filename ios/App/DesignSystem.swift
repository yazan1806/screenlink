import SwiftUI

enum ScreenLinkStyle {
    static let accent = Color("AccentColor")
    static let canvas = Color(uiColor:.systemGroupedBackground)
    static let surface = Color(uiColor:.secondarySystemGroupedBackground)
}

struct BrandHeader: View {
    let subtitle: String
    var body: some View {
        HStack(spacing:12) {
            Image("BrandIcon").resizable().frame(width:48,height:48).clipShape(RoundedRectangle(cornerRadius:13)).accessibilityHidden(true)
            VStack(alignment:.leading,spacing:3) {
                Text("ScreenLink").font(.title2.weight(.bold)).tracking(-0.6)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }.padding(.vertical,8)
    }
}

struct AppCard<Content:View>: View {
    let content:Content
    init(@ViewBuilder content:()->Content){self.content=content()}
    var body:some View {VStack(alignment:.leading,spacing:18){content}.frame(maxWidth:.infinity,alignment:.leading).padding(22).background(ScreenLinkStyle.surface,in:RoundedRectangle(cornerRadius:24))}
}

struct ScreenLinkPrimaryButton: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    func makeBody(configuration:Configuration)->some View {
        configuration.label.font(.body.weight(.semibold)).frame(maxWidth:.infinity,minHeight:52)
            .foregroundStyle(scheme == .dark ? Color(red:0.03,green:0.15,blue:0.13) : .white)
            .background(ScreenLinkStyle.accent,in:RoundedRectangle(cornerRadius:15))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct SetupStep: View {
    let number:Int
    let title:String
    let detail:String
    var body:some View {
        HStack(alignment:.top,spacing:12){
            Text("\(number)").font(.footnote.bold()).frame(width:28,height:28).background(ScreenLinkStyle.accent.opacity(0.12),in:Circle()).foregroundStyle(ScreenLinkStyle.accent)
            VStack(alignment:.leading,spacing:4){Text(title).font(.subheadline.weight(.semibold));Text(detail).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)}
        }
    }
}

struct InfoBanner: View {
    let text:String
    var body:some View {Label(text,systemImage:"info.circle").font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true).padding(16).frame(maxWidth:.infinity,alignment:.leading).background(ScreenLinkStyle.surface,in:RoundedRectangle(cornerRadius:16))}
}

struct ScreenLinkInfoSheet: View {
    var privacy=false
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:22){
                    if privacy {
                        AppCard {
                            Label("You're in control",systemImage:"hand.raised").font(.title3.bold())
                            Text("The camera is used to scan pairing codes. Screen sharing begins only after you approve Apple's system picker. You can end a session from either device.")
                        }
                        AppCard {
                            Text("Where your data goes").font(.headline)
                            Text("Screen video, application audio and remote-control input travel through your configured LiveKit service. Transport is encrypted. Application-level end-to-end encryption is not enabled, so the media service must be trusted.")
                            Text("ScreenLink does not save recordings or capture microphone input. The connection provider can process connection metadata and usage. Your PC's temporary internet address uses Cloudflare Tunnel.")
                        }
                        AppCard {
                            Text("Saved devices").font(.headline)
                            Text("Your remote-access credential is stored in this iPhone's Keychain. The PC stores its hash. Face ID or your passcode is required to reconnect. Remove the saved PC here, or revoke all devices in the Windows app to end their future access.")
                        }
                    } else {
                        AppCard {
                            Label("Use your PC from anywhere",systemImage:"desktopcomputer").font(.title3.bold())
                            SetupStep(number:1,title:"Open ScreenLink on Windows",detail:"Leave your PC on and signed in. In Remote access, choose Add iPhone.")
                            SetupStep(number:2,title:"Scan once",detail:"In My PC on this iPhone, choose Add a PC and scan the remote-access code. Approve only a PC you own.")
                            SetupStep(number:3,title:"Connect whenever you need",detail:"Tap Connect on your saved PC and authenticate. Different Wi-Fi networks and mobile data are supported.")
                        }
                        AppCard {
                            Label("Show your iPhone on the PC",systemImage:"iphone").font(.title3.bold())
                            Text("Choose Mirror, scan the code in the PC's Mirror iPhone panel, then connect and approve Share Screen. This code is separate from remote-PC authorization.")
                        }
                        AppCard {
                            Label("Mouse gestures",systemImage:"computermouse").font(.headline)
                            Text("Swipe to move. Tap to click. Double-tap for a double click. Use two fingers to right-click or scroll. Hold briefly, then move to drag. Rotate horizontally for fullscreen.")
                            Text("Fit shows the whole desktop. Fill covers the phone display and may crop its edges.").foregroundStyle(.secondary)
                        }
                        AppCard {
                            Text("If a connection fails").font(.headline)
                            Text("Check that the PC is on, signed in, connected to the internet, and running ScreenLink. Try Connect again. Windows sign-in and security prompts cannot be controlled remotely.")
                        }
                    }
                }.padding(20)
            }.background(ScreenLinkStyle.canvas)
                .navigationTitle(privacy ? "Privacy overview" : "Help & setup").navigationBarTitleDisplayMode(.inline)
                .toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){dismiss()}}}
        }
    }
}

struct ScreenLinkSettingsView: View {
    @Bindable var remote:RemoteModel
    @State private var help=false
    @State private var privacy=false
    @State private var confirmRemoval=false
    var body:some View {
        NavigationStack {
            List {
                Section {BrandHeader(subtitle:"Your screens, connected.")}
                Section("Support") {
                    Button{help=true}label:{Label("Help & setup",systemImage:"questionmark.circle")}
                    Button{privacy=true}label:{Label("Privacy & data",systemImage:"hand.raised")}
                }
                if remote.saved {
                    Section {
                        Label("Face ID or passcode required",systemImage:"lock.shield")
                        Button("Remove saved PC",role:.destructive){confirmRemoval=true}
                    }header:{Text("Saved PC")}footer:{Text("Removing this PC clears its credential from this iPhone. Revoke devices in Windows to remove their authorization on the PC too.")}
                }
                Section("About") {
                    LabeledContent("Version",value:Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    Text("ScreenLink is designed for your own devices. Keep the Windows app running to receive connections.").font(.footnote).foregroundStyle(.secondary)
                }
            }.navigationTitle("Settings")
                .sheet(isPresented:$help){ScreenLinkInfoSheet()}
                .sheet(isPresented:$privacy){ScreenLinkInfoSheet(privacy:true)}
                .confirmationDialog("Remove your saved PC?",isPresented:$confirmRemoval,titleVisibility:.visible){
                    Button("Remove PC",role:.destructive){Task{if remote.connected{await remote.stop()};remote.forget()}}
                }message:{Text("You'll need to authorize this iPhone again before connecting to this PC.")}
        }
    }
}
