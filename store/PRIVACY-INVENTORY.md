# Privacy inventory — working document

This is an engineering inventory, not a legal policy. Provider retention and final App Store privacy labels still require confirmation by the operator.

| Data | Current path / storage | Control |
| --- | --- | --- |
| Screen video and app audio | Captured after system approval; relayed through configured LiveKit; no recording saved by ScreenLink | Stop on phone/PC; provider behavior must be verified |
| Remote mouse/keyboard input | LiveKit data channel to an authorized PC; structured commands to a non-elevated helper | Disconnect / revoke; held mouse released on disconnect |
| QR camera frames | VisionKit scanner on iPhone | Camera requested only for scanning; frames not uploaded by app code |
| Remote device credential | iPhone Keychain, device-only while unlocked; hash in PC private store | Remove saved PC / revoke all PC devices |
| Temporary pairing credentials | In-memory backend; one-use, expires after ten minutes | Expiry / consume / replace |
| Service credentials | PC private LocalAppData configuration, outside source/distributable | Operator manages/rotates; never included in IPA |
| Connection identifiers, IP/transport metadata and usage | Connection providers / configured infrastructure | Confirm provider settings, retention and deletion process before release |
| Desktop display/quality preferences | PC local storage | Local preference changes |

No advertising, cross-app tracking, microphone capture or recording persistence is implemented by app code. This does not imply provider logs contain no user data. LiveKit dependency manifests and transitive SDKs must be included in the distribution audit. Face ID/passcode checking uses LocalAuthentication; the app does not receive biometric templates.

The app's PrivacyInfo.xcprivacy declares tracking false and no app-level required-reason API calls. Legacy UserDefaults flag writes were removed; saved-device existence is read from Keychain. Do not fill App Store privacy labels with guesses or describe transport encryption as end-to-end encryption.
