# PC cockpit art preparation

## Native sources

`tools/extract_pc_ui.py` extends the existing PC resource/bitmap decoders.
It exports seven 320x200 packed-nibble plates directly from `FRAME`, `DRIVER.BIN`,
`AA.BIN`, `TC.BIN`, `GPS.BIN`, `STATUS.BIN` and `IDENTIFY`, plus all seven
`STRUTS.BMP` images. These are source samples, not crops of gameplay recordings.

Canonical local extraction: `local-art/pc-ui-v2/manifest.json`. The preceding
exploratory `pc-ui-v1` is preserved because it supplied the generated studies.
The observed palette is tied to the first render RAM hash in
`artifacts/pc-ui-controls-02/report.json`.

All 16,024 strut pixels and preservation-mask bits equal the original EGA
descriptors reached through `DS:798e`. The seven plates have structural format
evidence and visual agreement with their corresponding interface components;
full independent original-loader parity for those plates remains unverified.
The extractor states that boundary in each asset receipt.

```sh
python3 tools/extract_pc_ui.py \
  --capture artifacts/pc-ui-controls-02/first-render.bin \
  --trace artifacts/pc-ui-controls-02/report.json \
  --output local-art/pc-ui-new
python3 -m unittest tests.test_pc_ui_assets tests.test_pc_bitmaps -v
```

The focused seven-test run passes in `artifacts/pc-ui-assets-tests-01.log`.
The tool's full source/RAM verification passes in
`artifacts/pc-ui-assets-extraction-01.log`. Source files remain unchanged.

## High-resolution material studies

The built-in image-generation editor produced two local 1586x992 RGBA studies:

* `local-art/pc-ui-remastered/gunner-plate-v1.png`
* `local-art/pc-ui-remastered/gunner-plate-v2.png`

Inputs were the extracted PC `GPS.BIN` plate, an original PC frame identifying
the viewport, and the already-extracted Genesis gunner graphic as style reference.
The PC remains authoritative for camera, controls, information and layout.
Only those selected image references were submitted, never the ROM, executable
or other workspace data. Exact prompts are in `prompts.json`; measured sizes,
hashes and alpha bounds are in `manifest.json` alongside the studies.

The treatment retains the source's steel panels, blue padding, ammo pictograms
and restrained coloured instruments. Changing values, heading graphics and
world content are absent so they can remain live original data. These images
were generated and reviewed by the same assistant.

**Neither image is installed in the tandem runtime.** The first aperture was too
wide. The targeted revision corrected its horizontal position but made it too
short. Mapped into source coordinates, the second alpha bounds are approximately
`[32.28,19.96,287.72,93.55]`; the original camera rectangle is
`[32,13,287,109]` inclusive. Visual appeal is insufficient to waive that mismatch.

After two geometry failures, further equivalent prompting stopped. The next
integration step needs renderer-owned exact aperture and instrument geometry,
with generated imagery supplying materials inside that layout. Static artwork
also needs separation from original dynamic UI writes, so text, erasure regions,
damage and modal overlays cannot be hidden by a new plate.

Working if: high-resolution material/detail changes leave the original visible
camera region and every live instrument value intact, with original-frame
fallback whenever station or UI attribution is unavailable.

All extracts and derivatives remain local, ignored by Git and excluded from
normal exports. No redistribution rights or publication are established.
