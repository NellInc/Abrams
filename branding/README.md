# Original box-art restoration

The current app icon is based on the original PC box artwork, as requested.
The local cover scan is `reference/manual-pages/scan-000.jpg`. Its composition,
red sky, dark tank, crew and ivory/gold title treatment guide the restoration.
The full restored cover is `abrams-cover-remastered.png`; the app uses the
square adaptation `abrams-icon.png`. Both remain private derived assets.

Built-in image generation restored the scan, removing paper damage and the
obsolete blue specifications label. A second generative pass recomposed it
for the square icon while retaining the original title and visual identity.
Native sips/iconutil only scales and converts the final icon for macOS.

Sources and inspection notes are retained in `tmp/custom-icons/abrams-app/`.
The approved glass-rim pass and previous icon are retained separately in
`tmp/custom-icons/abrams-app-glass/`. The active `abrams-icon.png` and README
image use the glass-rim variant. macOS and Windows icon conversions read this
same active file; the Linux kit includes it as well.
The earlier generic navy-tank icon is superseded and is not used by the app.
The original artwork copyrights remain with their respective owners.

Both final assets retain BY DYNAMIX and explicitly add FAN REMASTER.

FAN REMASTER uses the ivory stencil-title treatment, reduced slightly for
balanced spacing while remaining prominent. BY DYNAMIX stays visible.

Ordinary Play uses the full restored cover during startup, with its complete
lettering and painting preserved. A dark red surround and a warm ivory caption
frame the artwork at every window size. The cover is drawn before the asset
preload and leaves when the first valid original-game frame is composed.
There is no timed hold or extra game input. Startup failures retain the cover
and an actionable message; a missing image falls back to a readable title.

Latest built-in image-edit direction: add a narrow clear-glass bevel and light
surface sheen while preserving the title lettering, restored tank painting
and red/orange palette. Transparent exterior corners remain transparent.
This changes the app icon only; the full startup cover remains unchanged.
