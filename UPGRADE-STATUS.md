# Version 0.6.0 — a simpler, branded ScreenLink

Delivered: an original linked-screen S logo in editable SVG, light/dark wordmarks, opaque RGB 1024px app icon, native iPhone asset catalog, and matching Windows ICO/executable metadata. The iPhone has guided My PC and Mirror cards, a prominent saved-PC Connect action, secondary advanced/link setup, Settings, Help, Privacy overview and confirmed removal of a saved PC. The Windows companion has two clear task panels, a quieter connection form, collapsible quality/audio options, current task status, QR consumption/expiry feedback and explicit revocation confirmation.

Validation: backend tests and frontend build passed. All referenced frontend IDs were checked for duplicates/missing controls. Windows packaging passed; native visual checks covered Mirror, Remote access and Help at desktop/narrower window widths. The actual configured PC and metadata-only discovery participant remained connected through LiveKit, and existing device authorizations were preserved. The startup launcher matches the delivered EXE. Windows version resources report ScreenLink 0.6.0.

Cloud build passed: https://github.com/yazan1806/screenlink/actions/runs/40942850784 . The downloaded iPhone artifact's SHA-256 matched GitHub's artifact digest. IPA metadata reports 0.6.0 build 6 and includes its AppIcon, asset catalog and privacy manifest. The 1024px source icon is RGB without an alpha channel.

The new iPhone UI needs installing and physical-device QA; compilation is not that QA. Store materials are drafts, not a submission or approval. See store/APP-STORE-READINESS.md for the concrete public-release gaps and store/PRIVACY-INVENTORY.md for the working data inventory. Temporary hosting, general-customer PC provisioning, support/policy publication, review access and distribution signing remain release work.

---

Previous release notes:

# Version 0.5.0: fullscreen, touchpad mouse, saved PC

- A true full-screen cover replaces the old stacked fullscreen layout. It hides navigation/tab bars, status bar and the large keyboard/control rows. Rotate to landscape while connected to open it automatically. Compact keyboard/mouse/exit overlays remain available. Fill covers the phone display (cropping when aspect ratios differ); Fit shows the complete desktop with proportional borders.
- The desktop acts as a touchpad with a visible pointer: swipe to move, tap for left click, double tap for double click, two-finger tap for right click, two-finger pan for scrolling, and hold then move to drag. Mouse buttons are released on disconnect, backgrounding, helper EOF and after a ten-second held-button inactivity timeout.
- Saved authorization is detected from Keychain rather than a separate preferences flag. The app opens the Remote PC tab when a credential is saved. Connect to saved PC uses Face ID/passcode and address discovery; it needs no new QR after the initial authorization. Existing PC device authorizations are preserved.
- The PC stays connected to its metadata-only discovery room so the room cannot expire while idle. Its discovery credential grants no media, subscription or data privileges. This adds an active LiveKit connection while remote access is enabled; project quotas still apply.

Checks: backend tests cover a changed public PC address with the same device credential and discovery-room identity, as well as revoked access and least-privilege discovery grants. Native input helper compiled and release/EOF exit passed. Windows package built. iPhone and Windows cloud builds passed: https://github.com/yazan1806/screenlink/actions/runs/40931334745 . IPA 0.5.0 build 5 declares both landscape orientations. The installed PC host and metadata-only discovery participant were both observed connected through the real LiveKit service. One existing authorized device was preserved. New fullscreen layout and mouse gestures still need physical-phone verification after installing the IPA.

Keep the PC on, signed in and running ScreenLink. Free Apple-ID signing still expires after seven days unless refreshed; QR-free remote access does not renew an expired app. See https://faq.altstore.io/altstore-classic/your-altstore and https://faq.altstore.io/altstore-classic/altserver .

---

Previous release notes:

# ScreenLink Windows 0.4.1 / iPhone 0.4.0 upgrade

Implemented in source:

- Automatic private configuration loading in portable Windows builds; confirmed automatic QR setup in the packaged app.
- Detail preset by default (2560px bound, 20 Mbps, requested 60 fps), portrait/landscape/auto display, and fullscreen with an exit control.
- iPhone app-audio capture via ScreenCaptureKit and LiveKit manual-rendering audio. The microphone is not opened. PC playback has volume, mute, and an enable-audio control.
- Separate unattended remote PC authorization: one-use 10-minute QR, random device credential saved in iPhone Keychain, Face ID/passcode authentication before connecting, server-side hashed credentials, revocation with room rotation, and permission-scoped 60-second join tokens.
- A discovery room publishes only the current HTTPS address so an authorized phone can find the PC after its temporary tunnel address changes. Discovery credentials grant no media or control access.
- Remote primary-monitor video, system-audio capture where supported, tap-to-click, text input, scrolling, and common keyboard keys. Input helper runs without administrator rights and accepts structured input only.
- Enabling remote access installs a personal launcher in LocalAppData and enables launch at Windows sign-in. While remote access is enabled, the app prevents automatic system sleep (the display may still turn off). Disabling/revoking access removes that startup entry.

Verification: backend authorization/expiry/revocation tests pass; Windows build and native input-helper compilation pass. Cloud iPhone compilation passed. The public pairing endpoint returned healthy; unauthenticated remote host requests were rejected. The packaged PC app showed automatic QR pairing and Remote access ready. Physical-device audio and remote-control behavior are not yet validated because the updated phone app is not installed and Windows detects no connected iPhone.

Limits: iOS controls its screen-capture rate; 60 fps is a requested encoding ceiling, not a measured guarantee. The current SDK does not expose automatic suppression of the iPhone speaker. Lower the phone volume for PC-only listening; capture behavior still needs physical-device verification. Protected content may exclude audio/video. The PC must remain on, signed in, awake and running ScreenLink. Windows secure desktop, elevated windows, wake-from-off and remote power-on are not supported. Remote control currently covers the primary monitor and basic touch/keyboard input, not a complete desktop-client feature set. Internet media uses the configured LiveKit service and its quotas. Cloudflare Quick Tunnels have no production uptime guarantee. Media transport is encrypted, but application-level E2EE is not enabled.

The updated IPA must be signed and installed before the new phone features can work. Building an IPA alone does not install it or verify its behavior on a physical iPhone.

Cloud build passed for the iPhone (release 0.4.0, build 4), Windows package and backend checks: https://github.com/yazan1806/screenlink/actions/runs/40918196623
The delivered Windows 0.4.1 additionally has a dedicated ScreenLink startup entry and an automatic-sleep blocker while remote mode is enabled. Its local package compiled successfully.
