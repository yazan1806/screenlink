# ScreenLink 0.4 upgrade

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
