# Abrams project webpage

A dependency-free, responsive project site using approved Abrams artwork, refined scenario maps and the captioned project trailer.

Serve `dist` with any static web server. For example, from this directory:

```sh
python3 -m http.server 4173 --bind 127.0.0.1 --directory dist
```

The page contains the graphics comparison, all eight restored scenario maps,
direct release/source downloads, installation instructions, a "Before you download" questions band, original creator credits and the dedication.

`dist` is the complete deployable site. Do not serve or upload the parent game
repository. Asset origins and hashes are recorded in `asset-provenance.json`.
`robots.txt` points crawlers at the sitemap, `llms.txt` states the project facts
and credits, and `404.html` is the branded page GitHub Pages serves for unknown
paths; it uses root-absolute URLs because it can be served at any depth.
The font licence ships alongside the self-hosted font. The display font is a
Latin WOFF2 subset of Barlow Condensed SemiBold (the OFL names no Reserved Font
Name), made from `godot/assets/fonts/BarlowCondensed-SemiBold.ttf` with:

```sh
pyftsubset BarlowCondensed-SemiBold.ttf --unicodes=U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+2000-206F,U+2074,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD --flavor=woff2 --layout-features='*' --output-file=BarlowCondensed-SemiBold-latin.woff2
```

The header icon is served as 88px and 132px WebP variants for 2x and 3x
screens; the box art has 520w and 760w variants beside the 1039px original. Underlying game artwork
retains its original rights, as described by the project notice.

Nell selected GitHub Pages. The project's `Project webpage` workflow verifies
and publishes only `dist`, on changes to the website on `main`.
Project URL: https://abramsremastered.com/.
Nell authorized making NellInc/Abrams public with the website publication.
The download block links to the notarized macOS and native Windows/Linux alpha.4 packages, their release notes, checksums and matching DOSBox-Pure source archives. Original PC files and the optional Genesis
ROM are excluded from both Git and the download package.

The native trailer player has captions, a descriptive transcript (including on-screen text and the end card) and a poster extracted at 2.70 seconds, between the opening captions, so no caption is burned into it. Poster URLs carry the poster file's own hash as their cache token; the movie and caption track keep the movie's hash.
The accepted V8 movie is captioned directly; its matching optional English text track is off by default to avoid duplicate captions.
It does not autoplay or preload the movie, and playback starts with sound after the visitor presses Play. The native player retains its own download option; no separate trailer download link is shown.
Canonical, Open Graph and Twitter metadata use the project URL; the sitemap
includes the trailer. Structured metadata describes the webpage and video,
without fabricated reviews or ratings. Search indexing is controlled by the
search engines, not by the deployment check.

Polished website map PNGs and exact generation prompts are in artwork/maps.
All eight maps share the approved NATO-inspired treatment. The matching field-guide PDF, including side-by-side manual and extracted PC game-data maps, is served from assets/guides/field-guide.pdf. Source originals remain unchanged.

Scenario maps load and decode at low priority as the section approaches (not at all when Save-Data is on); mission selection reuses the decoded image, and failed preloads remain retryable. A `#scenario-<slug>` link opens that mission's map.

The download section offers large Keyboard controls and Field guide buttons.
Both PDFs are authored remaster references; the original manual stays private.
The field guide (31 pages, about 4.8 MB) has one paired-map spread per scenario; its links carry the file's hash as their cache token.
The platform download buttons have equal weight without JavaScript; the script
promotes the visitor's own desktop platform to the primary style when it can be
detected, and never on phones or tablets. Neither PDF contains game files. The favicon
uses the title emblem's white star on a black disc, with SVG and PNG editions.

Run `python3 verify.py`, `node --check dist/app.js` and `node test-maps.cjs` before publishing.
