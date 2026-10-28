# Requested upgrade

Windows v0.3.1 adds Auto/Portrait/Landscape viewing and a fullscreen toggle inside the viewer, including an exit control. Detail is now the default pairing preset (up to a 2560px capture bound, 20 Mbps and a requested 60 fps). The installed iPhone version already understands that preset. Restarting and pairing again is required to apply it; the currently running stream has not been interrupted.

These are capture/encoding targets, not measured improvements. LiveKit's iOS 27 ScreenCaptureKit capturer states that the fps option has no effect on the underlying capture rate because iOS selects that rate. Measure motion-heavy content and actual network performance before claiming a frame-rate improvement.

Still required for the full request:

- Capture app audio in the iPhone companion and publish it independently of microphone input, add PC audio playback/output controls, and test behavior when the phone's volume is lowered. Automatic phone-speaker suppression has not been established and is not implemented.
- Build and sign the updated iPhone companion after audio changes.
- Add remote PC viewing and control. The user chose unattended access with secure authentication. This needs a separate PC capture/input component, an authenticated iPhone viewer/control mode, revocable device authorization, and explicit installation/startup configuration. A screen-sharing QR must not also grant desktop-control privileges. None of these control components are implemented yet. Remote access does not imply the ability to power on an off PC or bypass a Windows secure desktop.

The audio and remote-control features must not be advertised as working until those components are implemented and tested.
