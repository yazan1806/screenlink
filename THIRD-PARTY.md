# Third-party components

ScreenLink's custom application source is included in this package. It uses these libraries; the built app is not a replacement for their licenses.

- LiveKit Swift 2.19.0, JavaScript client 2.23.0 and server SDK 2.19.2 — Apache-2.0; https://github.com/livekit
- Electron 45.1.0 — MIT, with Chromium and other third-party notices included in its distributed runtime; https://github.com/electron/electron
- node-qrcode 1.5.4 — MIT; https://github.com/soldair/node-qrcode
- Vite — MIT; https://github.com/vitejs/vite
- electron-builder — MIT; https://github.com/electron-userland/electron-builder

Dependency versions are locked in each npm package-lock.json. Swift dependencies are pinned in ios/project.yml, with transitive versions defined by that SDK's manifest. GitHub Actions resolves the packages during the cloud build. Dependencies retain their copyright and license notices. Preserve the runtime's license files when redistributing a packaged Windows app.

Apple, AirPlay, iPhone and Xcode are trademarks of Apple. ScreenLink is an independent personal project. LiveKit Cloud, GitHub and Render are optional external account/hosting providers, not accounts or subscriptions created by this package.
