# Original effect sprites in the tandem renderer

## Current result

The optional source-built tandem backend now observes and displays the original
effect bitmap selected by the PC executable. Its animation frame, detail level,
screen position, clipping rectangle and draw order come from the running original.
The seven sprite omissions in the preceding four-station trace are now rendered.
Godot never decides when an effect advances, appears or disappears.

This is native sample extraction and faithful playback. The effects remain
original-resolution artwork pending remastering. Cockpit/HUD, four-byte opaque
commands, integer polygon edges and full game/campaign parity remain open.

## Resource and runtime layout

The decoded `EFFECTS.BMP` contains a 16-bit count of 64, a separate array of 64
16-bit half-widths, 64 16-bit heights, then sequential packed-nibble images.
Each byte contains the left pixel in its high nibble. The parser consumes all
14,738 decoded bytes, with no unexplained tail. This format claim is bounded to
the supplied resource, not every historical Dynamix bitmap variant.

`DS:358e` points to the loaded bitmap pointer table. Each ten-byte descriptor
contains segment, image offset, mask offset, byte-sized pixel width and height,
then flags. Four sequential bitplanes encode palette indices. The fifth plane
is a preservation mask: a set bit leaves the background untouched. All 28,960
pixels and masks across the 64 loaded images match the extracted source. Zero
is transparent in this resource; the renderer still uses the explicit mask,
so it does not silently turn every black pixel into a hole.

`local-art/pc-effects-v1` contains 64 transparent PNGs, a contact sheet, source
hash, matching RAM hash, observed palette and decoded pixels/masks in
`effects.json`. These are samples decoded directly from the supplied file and
checked against memory, not cropped gameplay recordings. This ignored directory
is local reference material; no redistribution permission is implied.

## Original drawing path and observation

* `0b4d:28d0` selects the shape root. Bit 7 dispatches its second byte as the
  bitmap ID, bypassing the vector matrix path.
* `0b4d:437c` performs the original near-plane rejection and integer projection.
* `0000:8b08` resolves the original bitmap descriptor and subtracts half its
  dimensions from the projected centre. The read-only hook at `0000:8b49`
  observes the resulting signed top-left coordinates and loaded bitmap bytes.
* `0b4d:28e4` observes return from that path. A root that never reached the blit
  is explicitly marked `rejected-before-blit`. A missing completion remains an
  unsupported command, rather than being treated as a successful empty effect.

Each sprite occupies its observed position in the same ordered object stream
as vector geometry. Opaque same-colour horizontal runs become screen-aligned
quads. Transparent pixels emit no triangles. Direct bitmap palette entries use
separate solid swatches, independent of polygon material remapping/dither.
Later original polygons can cover a sprite, and the converse, irrespective of
Godot depth. Unsupported plane masks and unattributed draws remain explicit.

Working if: source-selected frames and positions appear in their original draw
order, native RGB/mask checks pass, and every original RAM/video/input hash stays
identical to the unmodified source baseline.

## Independent blitter evidence

`pc_bitmap_oracle.py` executes original instructions at the loaded EGA driver's
entry, alias `0f8d:4512`. A bounded hardware observer models the mode-0/mode-2
planar memory reads/writes, bit masks, read-map and plane-enable registers used
by that routine. Unsupported register operations fail rather than being ignored.
No original instruction is patched or replaced.

All 64 images pass at eight aligned, unaligned, clipped and wholly offscreen
positions: 512 blits, 32,768,000 checked framebuffer pixels, including untouched
background. Receipt: `artifacts/pc-bitmap-oracle-03.json`. The oracle validates
this bitmap path, not all VGA modes or polygon drawing.

The first harness failed at the terminal far return. Instrumented execution
showed RETF being re-executed with an advanced stack. The retained `-01.log` and
`-02.log` record failures; the underlying Unicorn cause is unresolved. The final
oracle runs through the complete blit and stack epilogue, verifies restored SS/SP,
and stops before RETF. It therefore makes no return-transfer correctness claim.
The ordinary DOSBox execution tests still execute the complete original routine.

## Live and native evidence

* `pc-sprite-controls-comparison-01.json`: all 1,167 frame input/RAM/video records
  and all 23 decoded stage states match the retained unmodified source baseline.
  All ten established four-station/control checks remain true. There are 261
  complete passes and no unsupported commands in this bounded scenario.
* The seven observed sprites occur in passes 165 through 171: bitmap 51 at
  `[156,58]`, 52 at `[152,58]`, then 53 at `[152,57]`. Their order and duration
  are captured, not re-authored. Other effect sequences still need live coverage.
* `pc-sprite-fixture-01.log`: all 261 Godot replay passes have no surface warnings,
  all seven sprites are emitted, and 33,551 projection checks retain maximum
  error 0.003906 source pixels under the unchanged 0.01 threshold.
* `pc-sprite-native-test-02.log`: 57,546 exact native GPU RGB samples pass. These
  cover all 64 original images at central and clipped positions, transparent
  gaps, explicit opaque black, polygon-material independence and both painter
  orders. Native tests run on the current Compatibility renderer only.
* `pc-sprite-live-integration-01.log`: the live process-pipe controls and graceful
  helper shutdown pass. That shorter test contains no effect draw; the longer
  profile and native replay above provide the sprite evidence.
* `pc-sprite-viewer-native-01.log`: the updated native viewer captures and exits
  successfully. Its sprite counter and longer status/footer fit the window;
  this layout was inspected by the implementation's author. The preceding solid
  capture is preserved in `artifacts/pc-solid-viewer-v3`.
* `pc-sprite-controls-02/report.json` records source presentations for bitmap IDs
  51, 52 and 53, at host frame indices 701, 713 and 721. Native Godot replays use
  their attributed passes 165, 168 and 170. `pc-sprite-paired-comparison-01.png`
  shows all three pairs and was inspected by this implementation's author.
  Of 89 sampled opaque effect pixels, 84 match the final original framebuffer;
  five are black in the source reticle region. The missing original HUD is still
  visible in the comparison. This is not a full-scene raster-equivalence claim.
* `validation-20260927T012101Z/results.txt`: all thirteen aggregate stages pass,
  including 113 Python tests and original-file preservation.

The first native test used arbitrary synthetic greys and failed two samples:
RGB 17 became 12, and 51 became 50. The actual EGA palette and all supplied effect
images passed in that same run. The final sprite test uses the original EGA
colour domain, retaining exact equality and recording the failed probe in
`pc-sprite-native-test-01.log`. Arbitrary dark-colour fidelity remains a separate
high-resolution material acceptance item. The upstream Compatibility
[scene shader](https://github.com/godotengine/godot/blob/master/drivers/gles3/shaders/scene.glsl)
converts unshaded albedo to linear and back, consistent with the observed
round-trip discrepancy; this is not proof of the exact installed shader cause.
No speculative colour compensation was applied.

## Custody and reproduction

The new trace core SHA-256 is
`3d6c999303783935bce869b0a5f5928ec3dc149bbfe4ac6374de297e24565124`.
The previous core and manifest remain in `artifacts/pc-trace-build-v3`. Original
files, source baseline, content archive and mission-entry snapshot are unchanged.
No binaries or derived assets were staged or published.

```sh
python3 tools/build_pc_trace_core.py
python3 tools/capture_pc_render_trace.py --mode trace --profile controls \
  --capture-sprites --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-sprite-controls-NEW
.runtime/pc-analysis-venv/bin/python tools/pc_bitmap_oracle.py \
  --capture artifacts/pc-sprite-controls-NEW/first-render.bin \
  --output artifacts/pc-bitmap-oracle-NEW.json
python3 tools/extract_pc_effects.py \
  --capture artifacts/pc-sprite-controls-NEW/first-render.bin \
  --trace artifacts/pc-sprite-controls-NEW/report.json --output local-art/pc-effects-NEW
./tools/godot.sh --script res://tests/test_pc_sprites.gd -- --native \
  --fixture "$PWD/local-art/pc-effects-NEW/effects.json"
./tools/godot.sh --headless --script res://tests/test_pc_draw_pass.gd -- \
  --fixture "$PWD/artifacts/pc-sprite-controls-NEW/report.json" --solid
./tools/validate.sh
```

The whole remaster goal remains open. High-resolution effects should replace
these samples only after matching their original anchors, extents, timing and
information visibility, with full palette/alpha validation of the new artwork.
