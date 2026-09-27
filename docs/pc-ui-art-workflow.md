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
evidence and visual agreement with their corresponding interface components.
The original extraction receipt predates the independent packed-driver and live
loader checks below; it is preserved unchanged rather than retrospectively
rewritten. Live loader coverage now includes all four station plates and STATUS.
FRAME and IDENTIFY have isolated packed-driver proof only.

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

At the study stage neither image was installed in the tandem runtime. The first aperture was too
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

## Original packed-plate proof

`tools/pc_plate_oracle.py` executes the loaded `DS:35f0` driver, resolving to
`load+1388:2217`, and its `2206` helper in Unicorn 2.1.4. The complete observed
code span also matches original `SIM.EXE` bytes at file offset `15c86`.
No instruction is replaced. A bounded VGA mode-0 observer records all four planes;
interrupts and unsupported operations fail closed. Execution stops after the
epilogue, immediately before RETF, as in the earlier bitmap oracle.

`artifacts/pc-plate-oracle-01.json` passes all seven extracted plates across both
EGA pages and 1-, 20- and 200-row chunks: 42 cases, 2,688,000 rendered pixels and
11,010,048 planar bytes including untouched memory. Non-canonical source pointers,
saved registers, stack and restored VGA mode/plane mask are checked separately.
This isolated test does not execute file I/O.

The live core now observes `0f8d:1170` (filename), `123a` (actual decoded buffer
and driver arguments), and the success/failure returns `1226`/`1238`. Events
20 through 23 are bounded host copies. `pc_plate_trace.py` compares each buffer
against a fixed local source catalog, checks contiguous rows and constant page,
and issues a receipt only after a complete successful load. Unknown filenames
never become host paths or verified assets. Partial snapshot attachments remain
unattributed. Receipt history is bounded.

`pc-plate-controls-01` verifies all four stations, and `pc-plate-modal-02` adds
STATUS.BIN through the original D damage-screen command. Each successful plate
arrives as ten exact 3,200-byte chunks. The first modal probe ended during the
return-to-gunner drawing work; the second adds neutral frames and captures its
completed plate. No original menu or station logic is reimplemented.

## Surviving-plate provenance

The separate `abrams_plate_ownership.h` stores the original plate ID, source byte
coordinate and qualifying bits for each EGA planar byte. It begins empty.
Only observed, content-checked original packed-driver writes assign plate IDs.
Direct instrument writes clear them even when the new colour is identical or
black. Latch copies, masks, raster operations and transparent bitmap preservation
carry or conservatively discard provenance. XOR changes discard the changed bit.
Mixed origins are dropped; copies to another coordinate never qualify as art at
the destination coordinate. Every visible pixel requires all four plane bits to
agree. This mask deliberately makes no completeness claim.

Event 24 follows the original scanlines and completed triple-buffer slot, beside
the original UI mask. The host rejects non-UI claims, invalid IDs and slot changes.
It exposes `presentation.plate_overlay` as optional metadata; older consumers and
the default source-cockpit view remain compatible.

* `pc-plate-bit-oracle-02.json`: compiled C++ against an independent per-bit model,
  4,096 operations, 131,072 checked plane bits and 14 explicit ID/page cases.
* `pc-plate-pixels-02.json`: all 482,370 attributed pixels across 30 captured
  samples equal the original source plate at the exact source coordinate and
  observed palette, including station changes, bitmap effects and the damage screen.
* `pc-plate-ownership-comparison-02.json`: all 1,533 full-RAM, framebuffer and
  input records, plus stage states, equal the unmodified source baseline.
* `pc-plate-lifecycle-03/report.json`: all 7,267 shared-neutral-boot RAM/video/input
  records, 52 stage states and original program boundaries equal the unmodified
  baseline across quit, debrief, menus and reentry. Both SIM epochs are retained.

The new core is `890f45a517b0e88b52278e24087ff236333c27f1f2684957cc3d386f7effec19`;
its trace header is `066aafc1430979a04770b3e2666b9f0a1fcceb127e408be9d94d6e7152efae31`.
The plate header is `5996b49c83e12819e28f3e0ed339d84ab4c537a24010f9868ab2d542db227922`.
The build receipt is `artifacts/pc-plate-core-build-03.log`; the unmodified baseline
pin and original VGA ownership header remain unchanged.

### Original dissolve copy and first-entry regression

The first actual cold-boot viewer (`pc-gunner-material-viewer-01`) correctly
fell back to original materials. Its CPU-assembled dissolve erased our initial
plate provenance. The original dispatch `0f8d:1a7c`, through `DS:3604`, resolves
to `load+1388:1ff3`. That code reads each source plane, assembles a colour in the
CPU, refreshes the destination latch, then writes one mode-2 pixel. The observer
now carries the source's qualifying bits through that specific, bounded path.
It does not infer provenance from matching colours or alter the transition.

`pc_dissolve_oracle.py` independently executes the unchanged driver in both page
directions. The first attempt did not reach the return within its initial bound;
the longer bounded run then disproved the assumed complete-page copy. A diagnostic
found exactly four mismatched plane bytes and 63,999 pixel writes. Disassembly
confirms that returning to LFSR seed `f9ff` ends the loop before drawing the seed.
Because its low bits select mask `80`, **physical pixel (312,199) remains from the
destination page**. The original quirk is preserved. The corrected expectation
passes all 128,000 output pixels and 524,288 plane bytes, including untouched
memory, in `pc-dissolve-oracle-04.json`. Earlier failing logs are retained.

`pc-gunner-material-viewer-02` now cold-boots through the real Godot pipe and
displays the new materials on first mission entry, with clean exit. Its 26-sample
receipt confirms both world and gunner-material composition. The captured
33,620 plate-provenance pixels independently match the original source in
`plate-pixel-proof.json`. The final side-by-side capture was visually inspected.

## Local material pilot

`./PC\ Bridge.command --gunner-art` loads the preserved `gunner-plate-v2.png`
study locally. It replaces only surviving GPS.BIN material pixels above source
row 123, outside the original camera rectangle. The lower instrument panel is
entirely original. Original writes retain the reticle, bearing scale, values,
messages and modal overlays. The image's incorrect aperture does not define the
sight opening. Palette changes, absent/malformed provenance, unsupported source
fingerprints or missing local art disable the pilot. It is opt-in, with the
default source-resolution interface retained for comparison.

The first native pilot test correctly failed because no real fixture enabled the
art. Godot JSON parses numbers as floats and nested array equality distinguished
the recorded palette from the identical integer constant. Component-wise numeric
validation fixes that gate without accepting changed colours. The failing capture
and diagnostic are retained as `pc-plate-art-native-01` and `pc-plate-art-probe.gd`.
Synthetic tests now round-trip through the JSON wire representation.
The final native run, `artifacts/pc-plate-art-native-03`, passes 2,771,432 exact
RGB checks and changes 172,484 source-pixel samples across the captured gunner
frames. Synthetic testing covers every 1280x800 output pixel, including genuine
sub-source-pixel detail, alpha holes, other plate IDs and the original aperture.
Recorded tests check every protected source-pixel centre. The gunner and damage
captures were visually inspected: the new surround is visible, while the lower
instruments and complete damage screen remain original. The transition between
new materials and the old lower panel is visibly unfinished, as expected for this
restricted pilot.
The complete 17-stage local gate passes in
`artifacts/validation-20260927T093036Z/results.txt`, including 137 Python tests,
unchanged original files, Godot parsing/runtime, simulation and audio gates.
No optional Impeccable linter is configured for this GDScript project; none was installed.

Working if: high-resolution material detail appears only in proven gunner plate
pixels, every protected original pixel matches its paired frame, and unsupported
states show original materials rather than a stale or inferred station.

This remains a material pilot, not a completed high-resolution cockpit. Fonts,
instrument graphics, the other stations and world-asset replacement remain open.
The author both implemented and reviewed this work; native rendering and original
replay checks are separate evidence from visual judgment.

```sh
.runtime/pc-analysis-venv/bin/python tools/pc_plate_oracle.py \
  --capture artifacts/pc-ui-controls-02/first-render.bin \
  --output artifacts/pc-plate-oracle-new.json
python3 tools/capture_pc_render_trace.py --mode trace --profile plates \
  --capture-ui --capture-sprites \
  --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-plate-capture-new
python3 tools/verify_pc_plate_overlay.py \
  --report artifacts/pc-plate-capture-new/report.json \
  --output artifacts/pc-plate-pixels-new.json
./tools/godot.sh --disable-render-loop --script res://tests/test_pc_plate_art.gd -- \
  --native --fixture "$PWD/artifacts/pc-plate-capture-new/report.json" \
  --art "$PWD/local-art/pc-ui-remastered/gunner-plate-v2.png" \
  --output "$PWD/artifacts/pc-plate-art-native-new"
```
