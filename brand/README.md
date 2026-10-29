# ScreenLink identity

Original geometric vector artwork created for this project. Two offset screen corners form an S and suggest a connection between devices. No trademark/name clearance has been performed.

- Mint #94F4DF → #3CCEBB
- Periwinkle #C6D1FF → #839BFA
- Ink #0C1829
- Native light-mode action color #006F71; dark mode uses mint.

Assets: screenlink-mark.svg (transparent), screenlink-icon.svg (full-bleed square), wordmark-light.svg / wordmark-dark.svg (for light/dark backgrounds), ScreenLink-Icon-1024.png (RGB, opaque, 1024px).

The wordmark uses system Segoe UI/Arial fallbacks; font files are not distributed. Keep generous clear space around the symbol. Do not stretch, rotate or add effects. The OS supplies iPhone icon corner masking. No Apple or Microsoft logos are incorporated.

Regenerate build assets with npm ci in desktop, then node tools/build-brand.mjs from the repository root. This deterministically creates iOS asset catalog entries, the Windows ICO and browser SVG copies. App icons are encoded as RGB without an alpha channel.
