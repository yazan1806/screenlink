# ScreenLink

A personal iPhone-to-Windows screen mirroring app with QR pairing and internet streaming. The phone and PC can be on different networks, including mobile data.

- **Windows:** portable Electron receiver with fullscreen video and quality presets.
- **iPhone:** native Swift app, iOS 27+, Apple's screen-sharing picker, and camera-based QR scanning.
- **Pairing service:** single-use, expiring QR credentials; authenticated PC controls; short-lived, permission-scoped media tokens.
- **Video:** H.264-preferred WebRTC through a configurable LiveKit media service, with NAT traversal and TURN fallback.

## Get started

### Personal PC connection (v0.3)

On this configured PC, the Windows app starts its private pairing service on loopback, creates a temporary Cloudflare HTTPS address, joins LiveKit as a viewer and displays a fresh QR code. Open ScreenLink on the iPhone, scan the QR, confirm the server, connect and approve Share Screen. The phone may be on mobile data or another Wi-Fi network.

The private `server.env` and the official `cloudflared.exe` helper are stored in `%LOCALAPPDATA%/ScreenLink`, outside this repository. Closing the app closes the temporary connection and requests closure of its media room. A new launch creates a new address and pairing code. Cloudflare Quick Tunnels are a testing connection without an uptime guarantee; LiveKit remains the video transport. No paid backend host or Cloudflare account is used for this test. Usage remains subject to LiveKit's project quotas.

For another PC or permanent hosting, follow the general setup below. The portable EXE does not contain API credentials or the separately installed Cloudflare helper.

[Cloud build #1 passed](https://github.com/yazan1806/screenlink/actions/runs/40773951395): iPhone compilation, Windows packaging and backend checks. The iPhone app has since been signed and installed through AltServer. A physical iPhone stream was received successfully in the Windows app using the configured LiveKit project. Latency, sustained performance and cellular-network behavior still need measurement.

Read [SETUP.md](SETUP.md) for cloud account setup, hosting, Windows launch, and signing the iPhone IPA from Windows using AltStore Classic. You do not need your own Mac. The iPhone cloud build does not require Apple credentials; signing happens on your Windows PC.

Run the **Build ScreenLink** workflow in the repository's Actions tab. Successful jobs provide a Windows executable and an **unsigned** iPhone IPA as downloadable artifacts. The IPA needs signing before installation. A successful build does not validate physical-device capture or remote video transmission.

The pairing/media hosting must be configured before QR pairing works. Never commit a `.env` file, API secret, Apple password, or signing certificate. The PC takes your pairing server's HTTPS address and personal access key; it never needs your Apple ID.

## Quality

Presets target 720p, 1080p, or a 2560-pixel capture bound, with up to 60 fps and adaptive WebRTC delivery. These are requested limits, not guaranteed resolution, frame rate or delay. Higher upload bandwidth and a nearby media server improve the result. End-to-end delay still needs measurement on the actual phone and PC.

## Development

Inside `server`, run `npm ci` then `npm test` for backend checks. See `.env.example` for configuration. Inside `desktop`, run `npm ci` then `npm run dev`, or `npm run package` to build the Windows executable. The generated Xcode project is created from `ios/project.yml` with XcodeGen.

Video is transport-encrypted, but application-level end-to-end encryption is not enabled. The configured media service must be trusted. Version 0.4 adds app-audio capture and a separate authorized Remote PC mode. See [UPGRADE-STATUS.md](UPGRADE-STATUS.md) for implementation, validation and limits. Phone control, recording and production hosting are not included. Third-party dependencies are described in [THIRD-PARTY.md](THIRD-PARTY.md).
