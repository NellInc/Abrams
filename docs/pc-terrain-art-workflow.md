# High-resolution terrain detail

This document records the first flat-terrain material pass. The later
32-shape hillside pass, including Genesis colour evidence and vertical faces,
is documented separately in `pc-hill-art-integration.md`.

## Scope and source identities

The tandem renderer now applies authored grass and asphalt detail to the original
ground background and seven explicitly selected static source shapes. It retains
the Genesis-derived colour mapping introduced in the cockpit correction. This
pass changes surface colour within existing triangles. No new vegetation, road
markings, rocks, silhouette edges, lighting, fog or collision are introduced.
Original CPU rendering and simulation still execute unchanged.

The supplied `SHAPE.TBL` SHA-256 is
`81cf10917d8647e8ac187e49887494992828277333f17d6c1926e59581f0a193`.
The selected shape/primitive pairs are:

| Shape | Primitive | Original material | Authored treatment |
|---|---|---|---|
| 48 | 5123 | 8 | grass detail |
| 49 | 5199 | 3 | asphalt detail |
| 50 | 5275 | 3 | asphalt detail |
| 51 | 5351 | 3 | asphalt detail |
| 52 | 5427 | 3 | asphalt detail |
| 53 | 5503 | 3 | asphalt detail |
| 54 | 5579 | 3 | asphalt detail |

`pc-terrain-source-check-01.json` records all original selected vertices: every
face is flat at source height zero. These authored material names are visual
assignments, not claims about recovered gameplay semantics. Both the shape and
primitive identity, expected fill/material and original static-allocation flag
must match. A dynamic actor with the same colours never qualifies. All other
shapes, effect sprites and polygon outlines retain their previous rendering.

Working if: only those original surface fragments change, the triangle stream
and painter order remain identical, and missing assets or unsupported palettes
disable detail rather than substituting guessed materials.

## Local image-software assets

The built-in image generation tool produced two new, reference-free detail
images, saved unchanged in `local-art/pc-terrain-remastered/detail-v1/`:

* `field.png`, 1254 by 1254 RGB, SHA-256
  `36eb892810f7f233b6ca4bff909ce1990ff727e6307350445398e6ef6bd6109c`.
* `road.png`, 1254 by 1254 RGB, SHA-256
  `737334a62f68cde25b62a61356c468888a12071fa1352bace2c32594af8be480`.

The prompt requested square 2048-pixel donors; the tool returned the measured
1254-pixel images above. No upscaling or pixel-editing substitute was used.
`prompts.json` preserves both exact prompts. `manifest.json` records fingerprints,
measured red-channel means and presentation parameters. The generated originals
also remain in the image tool's output directory. No ROM, executable, reference
image or workspace content was submitted for these two generations.

Their red channel provides neutral detail only; slight generated colour casts
cannot tint the game. The original/Genesis palette supplies the surface colour.
Both texture hashes are checked before loading, and mipmaps are generated locally.
The images and local receipts remain ignored and excluded from distribution.
No publication or redistribution decision is implied.

## Coordinate and colour handling

The shader reconstructs local coordinates from the original camera's Q14 matrix,
then uses continuous east/south world position. Streaming-window changes therefore
do not reset the pattern phase. The original camera-relative triangle coordinates
and projection are untouched. Inverting the quantized matrix for texture placement
does not undo the original integer vertex arithmetic; small source-rounding
differences remain possible. This does not claim exhaustive motion stability.

The flat original ground background has no geometric depth. Its existing ground
fragments are projected onto height zero only when the original camera is above
that plane and the ray points down. Its original horizon and painted area remain
unchanged. Road repeats every 256 raw coordinate units, grass every 512; these are
authored texture scales, not a claim about physical metres. Detail fades to neutral
between distances 2048 and 8192, without fading the original surface or targets.

Thirty-three precomputed RGB levels bound source-channel multipliers to 0.75
through 1.25. Level 16 is exactly the selected palette colour. The existing
Compatibility colour compensation is applied after computing each level, avoiding
the earlier dark-colour error. Lookup textures are cached by palette, original
material words and level count. Unselected surfaces always sample the exact
neutral level. Detail images use filtered mipmaps; palette ramps stay nearest.
This uses the documented Godot 4.7
[spatial varying pipeline](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html)
and [sampler filtering hints](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/shading_language.html).

The default four-station bridge enables detail when both local donors are present.
`--flat-world` retains the preceding flat-colour world, new cockpit and Genesis
palette. `--original-art` remains the full original-art diagnostic. Wireframe and
the earlier explicitly selected gunner-only pilot do not enable terrain detail.

## Verification

* `pc-terrain-headless-02/report.json`: 65,245 assertions across all 292 recorded
  original driver-route draw passes. Triangle vertices/order and material IDs
  are identical; original pass dictionaries remain unmodified.
* `pc-terrain-native-04/report.json`: 3,422,771 assertions, zero failures.
  Seven native views inspect 3,977,216 world pixels, including 1,166,244 changed
  terrain pixels. A separate eligibility rendering verifies exact RGB preservation
  outside selected terrain, including sky and visible vehicles. 223,349 original
  UI pixel centres remain exact after actual tandem composition.
  Each view independently requires visible detail; an initially cumulative
  counter could have missed one view losing detail and was corrected before
  this final run. The change count itself is unchanged.
* The same native test uses an analytic ramp to check both road and background
  grass shader coordinates under translation, a 90-degree camera rotation and
  a 4096-unit world shift.
  Headless checks cover additional rotations, invalid matrices, unknown palettes,
  absent assets, actor exclusion and all 256 neutral channel levels.
* `pc-terrain-genesis-regression-01.log`: native Genesis road RGB remains exact
  with terrain disabled. The unchanged source geometry check also passes.
* `pc-terrain-surfaces-native-01.log`, `pc-terrain-sprites-native-01.log` and
  `pc-terrain-colour-native-01.json`: original palette, dither, painter-order,
  horizon and seven synthetic sprite pixel checks pass; all 1,280 arbitrary
  RGB readbacks remain exact. These regressions exercise the shared shader and
  newly cached material lookup with detail disabled.
* `validation-20260927T130747Z/results.txt`: all 21 stages pass, including the
  new terrain stage, original-file preservation, 189 Python tests and 150 Godot
  audio assertions. No emulator, original-game or bridge-protocol code changed.
* `pc-terrain-live-default-01`: actual cold boot through the original menu and
  briefing reaches the driver with 28 samples, seven selected terrain polygons,
  original UI composition, moving driver assembly and terrain detail enabled.
  The child exits cleanly. Its paired capture was visually inspected.
* `pc-terrain-shared-state-comparison-01.json`: detail-on and flat-world viewers
  started from the same preserved mission snapshot and followed the same five
  sampled input stages. All eight checks pass, including identical original
  framebuffer bytes, decoded state, complete presentation metadata and the
  original render-start RAM fingerprint. Both children exit cleanly.

The two independently cold-booted viewers (`pc-terrain-live-default-01` and
`pc-terrain-live-flat-01`) have identical final original framebuffer and decoded
state, but their render-start RAM hashes differ. The full-presentation comparison
therefore **fails** in `pc-terrain-live-comparison-01.json`. The only differing
presentation field is that RAM hash. Its underlying cause was not established;
startup clock/disk variation is a hypothesis, not evidence. The shared-state
comparison above controls startup and passes. Neither receipt establishes
all-mission parity or closes the wider cold-boot determinism investigation.

The first native receipt, `pc-terrain-native-01`, correctly reports six fixture
composition failures: captured JSON stores UI masks separately, and the test had
not reattached those PNGs. Its terrain/coordinate checks passed, but its UI fallback
was insufficient evidence. The second run restores the fixture masks and verifies
that real composition succeeds before checking the original UI pixels. The failed
receipt remains intact. The first shell wrapper returned the final `cat` status;
the corrected wrapper explicitly preserves the Godot process exit code.

The implementing assistant generated, integrated and visually reviewed this work.
Human visual/motion acceptance remains open. The images show deliberately subtle
surface detail with the source palette and flat-shaded silhouette language.
Vehicles, buildings, trees, other terrain, effects and high-resolution instrument
graphics remain unfinished. This is one material pass within the active remaster.
No optional Impeccable linter is configured for this GDScript project.

```sh
./tools/godot.sh --disable-render-loop \
  --script res://tests/test_pc_terrain_style.gd -- --native \
  --fixture "$PWD/artifacts/pc-driver-assembly-trace-03/report.json" \
  --output "$PWD/artifacts/pc-terrain-NEW"
./PC\ Bridge.command --capture --capture-station driver \
  --output "$PWD/artifacts/pc-terrain-live-NEW"
./PC\ Bridge.command --capture --capture-station driver --flat-world \
  --output "$PWD/artifacts/pc-terrain-flat-NEW"
```
