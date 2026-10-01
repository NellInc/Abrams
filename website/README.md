# Abrams project webpage

A dependency-free, responsive project site using approved Abrams artwork.

Serve `dist` with any static web server. For example, from this directory:

```sh
python3 -m http.server 4173 --bind 127.0.0.1 --directory dist
```

The page contains the graphics comparison, all eight restored scenario maps,
installation instructions, original creator credits and the dedication.

`dist` is the complete deployable site. Do not serve or upload the parent game
repository. Asset origins and hashes are recorded in `asset-provenance.json`.
The font licence ships alongside the self-hosted font. Underlying game artwork
retains its original rights, as described by the project notice.

Nell selected GitHub Pages. The project's `Project webpage` workflow verifies
and publishes only `dist`, on changes to the website on `main`.
GitHub download links currently require access to the private NellInc/Abrams
repository. The public webpage does not change repository visibility.

Run `python3 verify.py` and `node --check dist/app.js` before publishing.
