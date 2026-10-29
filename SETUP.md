# ScreenLink — your internet screen mirroring app

## This PC is configured for the first test

The installed phone app opens on iOS 27.0.1. The ScreenLink LiveKit project and its PC backend key are configured privately on this computer. The v0.3 Windows app can start a temporary HTTPS pairing connection using the official Cloudflare helper in `%LOCALAPPDATA%/ScreenLink`. The private environment file is stored there too, not in GitHub or the source archive.

Run the updated Windows app and wait for its QR code. In the phone app choose **Scan QR → confirm server → Connect to my PC → Share Screen**, then approve entire-screen capture in Apple's picker. Keep the PC app open. A physical stream has now been verified in the Windows viewer, with both viewer and phone participants connected. A separate mobile-data test and glass-to-glass delay measurement are still needed.

This temporary address changes on each app launch. Cloudflare Quick Tunnels have no uptime guarantee and are intended for testing. Video travels through LiveKit, not the HTTPS tunnel. If the tunnel stops, restart the PC app and pair again. If ending a session fails, stop sharing on the phone. No paid backend host has been created.

The remaining sections document the general setup for a new PC or permanent hosting.

This replaces the earlier local-only ScreenLink prototype. The new project contains your own Windows app, iPhone companion, and private pairing backend. It uses the open-source LiveKit SDK and a configurable media server. You do not install AirDroid or another mirroring product.

**Current status:** Windows v0.3 was built and launched locally. The backend checks pass. [GitHub build #1](https://github.com/yazan1806/screenlink/actions/runs/40773951395) compiled the installed iPhone app. Signing, installation and physical-device capture have since succeeded, and live video was received by the Windows viewer. LiveKit credentials were verified, and a temporary public pairing endpoint rejected unauthenticated control requests with HTTP 401. A real media room was created and closed successfully during the backend check. Permanent backend hosting is optional and has not been provisioned. Do not enter any Apple password into the app or this chat. The Windows executable is unsigned.

## 1. Check the iPhone version

The user has confirmed an iPhone 14 Pro running **iOS 27.0.1**. This meets the companion's **iOS 27 or later** requirement. It uses Apple's native ScreenCaptureKit picker, avoiding a separate broadcast extension and App Group entitlement. A physical-device test is still required.

If your phone is on an earlier iOS version, stop here and report the exact version. Do not install a beta to satisfy this project. The earlier ReplayKit source is retained separately in the original ScreenLink folder, but it is not the internet implementation and its signing/entitlement path has not been validated.

## 2. Create the source repository and build your iPhone IPA

1. Sign up at [GitHub](https://github.com/signup) if needed.
2. Create a **private repository** called `screenlink`. An empty repository is easiest. You choose whether to enable paid build minutes; the build workflow does not do so.
3. Upload the contents of this `ScreenLink-Internet` folder, including `.github/workflows/build.yml`. Do **not** upload `node_modules`, `.env`, `desktop/release`, or any account credentials. `ScreenLink-Source.zip` contains the required files without these directories. When uploading with Git, the included `.gitignore` excludes them. GitHub's browser uploader may hide `.github`; verify the workflow exists after upload.
4. Open the repository's **Actions → Build ScreenLink → Run workflow**.
5. The iPhone job uses GitHub's `xcode-27` cloud Mac image. It generates the Xcode project, resolves the pinned SDK, and builds without an Apple account or signing certificate. Runner availability and billing are controlled by GitHub.
6. Download the **ScreenLink-iPhone-unsigned** artifact. Extract it to obtain `ScreenLink-unsigned.ipa`. A successful job is required before treating the iPhone source as compiled. If it fails, keep the job's errors so they can be fixed.

The same workflow builds the Windows portable executable and runs backend tests. The local Windows executable is already provided; a GitHub run isn't needed just to launch it.

## 3. Sign and install the iPhone app from Windows

Use **AltStore Classic**, not AltStore PAL. Follow its [official Windows setup guide](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows). It requires Apple device support software, a USB connection for initial setup, trusting the PC, and Developer Mode on the phone.

1. Install AltServer on Windows and AltStore Classic on your iPhone following that guide.
2. Enter your Apple ID directly into AltServer when it asks. The ScreenLink project needs no Apple ID, password, signing certificate or developer-team secret.
3. Transfer the unsigned IPA to Files on your iPhone, for example through iCloud Drive.
4. In AltStore Classic, open **My Apps → +**, then select the IPA. AltStore signs it for your phone.
5. Open ScreenLink on the iPhone. Keep AltServer available for refreshing the app. With free signing, installed apps expire after **seven days**, and the app-slot/App-ID limits of AltStore and Apple apply.

Signing/install success and the new `screen-capture` background mode have **not** been verified on your device. Free signing is an installation route to test, not a guarantee that every Apple capability will be accepted. If signing rejects a capability, report the exact error rather than stripping it: removing background capture would defeat sharing other apps.

## 4. Create the media service

1. Create an account at [LiveKit Cloud](https://cloud.livekit.io/), then a project near your location. Region selection and latency-routing options depend on your plan.
2. In project settings, find the **WebSocket URL** (`wss://…livekit.cloud`) and create a server API key and secret.
3. Keep these in the hosting provider's environment-variable settings. Do not put the API secret in the Windows app, the iPhone source, GitHub source files, or chat.
4. Review the provider's quotas and prices before activating billable services. The app does not promise free or unlimited relay bandwidth.

The Windows PC and iPhone both connect to the configured media service. They may be on different Wi-Fi networks or the iPhone may use mobile data. LiveKit uses WebRTC with NAT traversal and TURN fallback; it is an SFU-mediated stream, **not** a direct peer-to-peer-only implementation. This project can instead use a correctly configured, TLS-enabled self-hosted LiveKit server by changing the environment variables.

## 5. Deploy the pairing service

The included `render.yaml` and Dockerfile prepare a single Render web service; they do not create an account or start a paid plan automatically.

1. Sign up at [Render](https://dashboard.render.com/), connect the GitHub repository, and choose **New → Blueprint**.
2. Select this repository and review `render.yaml`. It requests a **Starter** web service, which may be billable. Approve the provider's cost only if it suits you. You may use another Node/Docker host instead.
3. Supply `LIVEKIT_URL`, `LIVEKIT_API_KEY`, and `LIVEKIT_API_SECRET` in the provider's settings. Render generates `SCREENLINK_OWNER_KEY` for you. This is your personal PC access key, not your Apple ID.
4. Deploy and wait for the service to become healthy. Note its HTTPS address, for example `https://screenlink-xxxx.onrender.com`.
5. Copy `SCREENLINK_OWNER_KEY` from Render's environment settings into your Windows app when connecting. Keep it private.

The service must run as **one instance**; active pairing state is in memory. Restarts invalidate pending pairing codes. `/health` reports whether the required environment variables exist, but does not prove that the LiveKit credentials or network are working. Creating a session performs the first real LiveKit API request.

## 6. Use your app

1. Run `ScreenLink-Windows-0.2.0.exe` on the PC.
2. Enter your HTTPS server address and personal access key. Choose a preset and select **Create pairing code**.
3. Open **ScreenLink** on the iPhone and choose **Scan QR code**. If camera scanning fails, copy the pairing link on the PC and paste it into the iPhone app. Links may also open through the registered `screenlink://` scheme.
4. Confirm the displayed server matches the one in the PC app. Tap **Connect to my PC**, then **Share Screen**. Choose the entire screen in Apple's picker and approve.
5. Switch to another app. The PC should display the shared video. Use **Fullscreen** for a larger view.
6. Use **End session** on the PC or **Stop and disconnect** on the phone to finish. If the PC reports a disconnect failure, retry or stop on the phone; the UI does not claim the server stopped streaming when the server could not be reached.

Codes expire after ten minutes and are single-use. A new session closes the old media room. Room join tokens last 60 seconds for the initial join; an established connection can last longer. At most two participants can join a room. On self-hosted LiveKit, deletion alone may not revoke a previously issued JWT until its short expiry; a stale token may briefly rejoin an empty room. It is not supplied to a different session.

## Quality, privacy and limits

| Preset | Requested capture bound | Maximum encoding target |
| --- | --- | --- |
| Fast | 1280 × 720, orientation fitted | 4 Mbps / 60 fps |
| Balanced | 1920 × 1080, orientation fitted | 10 Mbps / 60 fps |
| Detail | 2560 × 1440, orientation fitted | 20 Mbps / 60 fps |

These are requested bounds/ceilings, not measured guarantees. The SDK and OS may scale capture to fit aspect ratio, reduce frame rate, or adjust bitrate. The system may choose its own iOS capture rate. H.264 is preferred to encourage hardware encoding. Simulcast is disabled for this single-viewer use. A higher quality ceiling can increase bandwidth and latency when upload speed is limited. No 120-fps, lossless, zero-latency or HDR claim is made.

This version is video-only: no microphone, camera streaming, phone control or screen recording. The camera permission is used only for QR scanning. The UI shows actual displayed frame count and video dimensions. It does not invent a glass-to-glass latency value. Measure that by filming the phone and PC displaying a moving timer together. Different-network video has additional propagation/relay delay; choose a nearby media region and test over mobile data as well as Wi-Fi.

HTTPS/WSS protects control traffic; WebRTC encrypts media transport. **Application-level end-to-end encryption is not configured**, so trust the media service operator. The app itself does not save video. The PC access key lives in the current window's memory, while only the server address is remembered. The server holds LiveKit API credentials and room/pairing state. The pairing QR is a temporary credential: keep it private. Sessions expire after four hours, or earlier when an unused QR expires.

Before calling this ready: complete the cloud iPhone build, verify free signing and background capture on your iPhone, connect over Wi-Fi and mobile data, check landscape rotation, disconnect/reconnect and protected content, measure delay and heat during a long stream, and verify TURN fallback on a restrictive network.

## Local development

- Backend: `cd server`, `npm ci`, copy `.env.example` to `.env`, enter your own media credentials and generated owner key, then `npm start`.
- UI/browser: `cd desktop`, `npm ci`, `npm run dev`. It can test a loopback backend, but a phone on another network needs a public HTTPS backend.
- Windows package: inside `desktop`, run `npm run package`. Launch `desktop/release/ScreenLink-Windows-0.2.0.exe`.
- Checks: inside `server`, run `npm test`. These verify configuration handling, owner authentication, JWT permissions and expiration, duplicate claim rejection, malformed/oversize requests, expired/replaced codes, and correct reporting when room deletion fails. Tests use a fake media admin service; they do **not** test video transmission or Apple signing.

Sources: [Apple iOS screen capture](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-on-ios), [LiveKit iOS capture guide](https://github.com/livekit/client-sdk-swift/blob/2.19.0/Docs/ios-screen-sharing.md), [GitHub cloud Mac image](https://github.blog/changelog/2026-09-10-xcode-27-runner-image-now-runs-on-macos-27/), [AltStore free-signing limitations](https://faq.altstore.io/altstore-classic/your-altstore).

## Version 0.4 on this configured PC

Launch `ScreenLink-Windows.exe`. Server/key load automatically from the private LocalAppData setup. No LiveKit API secret belongs in the form. Use Auto/Portrait/Landscape and Fullscreen in the viewer. The new phone IPA is required for app audio and Remote PC mode. PC sound uses the Windows default output, with a volume and mute control in ScreenLink. iOS speaker suppression is not implemented; lower the phone speaker volume.

For unattended remote control, enable Remote PC access on Windows, select Authorize an iPhone, then scan that separate QR in the iPhone Remote PC tab and approve authorization. Later connections use Face ID or the device passcode. Keep the PC on, awake and signed in. The enabled app starts at Windows sign-in. Disable and revoke all devices removes authorization and startup. The app must already be running to receive connections; it cannot power on an off PC or control Windows security prompts. Revocation is performed from Windows.

Discovery tokens can reveal the current public pairing address for one year but grant no video, audio or data privileges. The revocable random device credential is required to obtain each short-lived remote-control token. After discovery-token expiry, authorize the phone again. Only hashes of device credentials are saved on the PC. The original private server configuration remains outside the repository.
