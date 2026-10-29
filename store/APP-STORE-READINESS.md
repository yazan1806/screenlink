# ScreenLink — public release readiness

This is a product/design readiness pass, not an App Store approval or a completed submission. The current build remains a personal preview for the configured Windows PC.

## Delivered in 0.6

A shared original vector identity, a 1024px RGB app icon without alpha, Windows executable/taskbar icons, guided My PC and Mirror flows, adaptive iPhone colors and text sizing, 52-point primary buttons, in-app setup help, a privacy overview, saved-device removal with confirmation, separate Windows task panels, and explicit remote-access revocation confirmation. Technical connection fields are secondary. No network permissions were broadened. Existing authorization remains in Keychain and the PC's private device store.

## Submission gates

1. **Distribution:** enroll/activate the Apple Developer Program; register the final bundle ID; produce an archive signed for App Store distribution and validate it in App Store Connect. The current unsigned IPA and AltServer installation are not an App Store distribution pipeline. Keep the same signing identity and bundle ID for preview upgrades to preserve saved credentials.
2. **Public onboarding:** ship an installer and a supported way to provision a new PC. This PC's private LiveKit configuration/helper are intentionally excluded from the EXE. A new customer cannot simply download the current EXE and expect configured hosting. Choose and implement the production service model before public release.
3. **Hosting:** replace the temporary Cloudflare Quick Tunnel dependency with a supported production setup. Define project quotas, service costs, recovery, availability and persistence. The personal backend is not a production multi-customer service. Do not ship your personal API secret inside an app.
4. **Privacy/support:** publish an operator-approved privacy policy and support contact/site. Add the real policy URL in-app and in App Store Connect; the current local overview is not that hosted policy. Complete the data inventory, actual provider retention settings and privacy labels. The manifest declares no tracking and no app-level required-reason APIs; it does not claim third parties collect no data.
5. **Review access:** supply a safe, dedicated review environment and clear Windows-companion instructions; do not grant reviewers access to this personal PC. The backend must be available during review.
6. **Device QA:** test the new UI on a physical iPhone in portrait/landscape and light/dark, with large text and VoiceOver. Verify camera denied, cancelled authentication, failed pairing, expired/replaced QR, revoked access, offline PC, Wi-Fi/mobile data, reconnect after PC restart, app backgrounding, fullscreen exit, keyboard, drag cancellation and audio behavior. Measure latency, sustained frame rate, heat and bandwidth instead of promising 60 fps.
7. **Package validation:** inspect all linked SDK manifests, entitlements and API usage; validate IPv6 connectivity and App Store Connect's archive report. The present iPhone target requires iOS 27. Confirm that deployment choice in the listing.
8. **Brand clearance:** check ScreenLink name availability and trademark conflicts before investing in release. The original mark is not a name/trademark clearance.

## Apple guidance used

Apple requires complete metadata, working review access and available backend services; an accessible privacy-policy link is required both in-app and in App Store Connect. Screen capture must have explicit consent and a clear indication. These are submission requirements, not items a logo can resolve.

ScreenLink is a generic mirror of a user-owned Windows desktop. Our interpretation is that guideline 4.2.7's additional restrictions target clients mirroring specific software/services rather than generic host mirroring. Preserve generic-desktop functionality and do not turn the client into a software store, launcher for unowned software or a cloud-app thin client. Apple makes the final review decision.

Source, checked 29 October 2026: https://developer.apple.com/app-store/review/guidelines/ (Before You Submit; 2.5.14; 4.2.7; 5.1.1).

## Not included in this pass

No App Store upload, account enrollment, paid hosting, public legal-policy publication, trademark clearance or claim of approval. No production uptime, zero-latency, guaranteed 60-fps or application-level end-to-end-encryption claim. The logo/UI update does not change the expiry of free Apple signing.
