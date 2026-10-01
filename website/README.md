# Abrams project webpage

A dependency-free, responsive project site using approved Abrams artwork, refined scenario maps and the captioned project trailer.

Serve `dist` with any static web server. For example, from this directory:

```sh
python3 -m http.server 4173 --bind 127.0.0.1 --directory dist
```

The page contains the graphics comparison, all eight restored scenario maps,
direct release/source downloads, installation instructions, original creator credits and the dedication.

`dist` is the complete deployable site. Do not serve or upload the parent game
repository. Asset origins and hashes are recorded in `asset-provenance.json`.
The font licence ships alongside the self-hosted font. Underlying game artwork
retains its original rights, as described by the project notice.

Nell selected GitHub Pages. The project's `Project webpage` workflow verifies
and publishes only `dist`, on changes to the website on `main`.
Project URL: https://abramsremastered.com/.
Nell authorized making NellInc/Abrams public with the website publication.
The download block links to macOS alpha.2 and native Windows/Linux alpha.4 packages, their release notes, checksums and matching DOSBox-Pure source archives. Original PC files and the optional Genesis
ROM are excluded from both Git and the download package.

The native trailer player has captions, a transcript and an extracted poster.
It does not autoplay or preload the movie, and playback starts with sound after the visitor presses Play. The native player retains its own download option; no separate trailer download link is shown.
Canonical, Open Graph and Twitter metadata use the project URL; the sitemap
includes the trailer. Structured metadata describes the webpage and video,
without fabricated reviews or ratings. Search indexing is controlled by the
search engines, not by the deployment check.

Polished website map PNGs and exact generation prompts are in artwork/maps.
All eight maps share the approved NATO-inspired treatment. The matching field-guide PDF, including side-by-side manual and extracted PC game-data maps, is served from assets/guides/field-guide.pdf. Source originals remain unchanged.

Run `python3 verify.py` and `node --check dist/app.js` before publishing.
