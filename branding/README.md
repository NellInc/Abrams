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
The earlier generic navy-tank icon is superseded and is not used by the app.
The original artwork copyrights remain with their respective owners.

Both final assets retain BY DYNAMIX and explicitly add FAN REMASTER.

FAN REMASTER uses the ivory stencil-title treatment, reduced slightly for
balanced spacing while remaining prominent. BY DYNAMIX stays visible.

Latest built-in image-edit direction: reduce only FAN REMASTER slightly,
preserving its ivory stencil treatment, the BATTLE TANK title, BY DYNAMIX,
the restored tank painting and the established composition. The actual result
was reviewed visually; no exact percentage reduction is claimed.
