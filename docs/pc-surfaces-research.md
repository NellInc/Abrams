# Original PC surfaces in the tandem renderer

## Current result

`PC Bridge.command --trace` now draws filled original scenery and vehicles,
observed sky/ground boundaries and original EGA material patterns in Godot. The
PC executable retains simulation authority, including its original rendering
side effects. Godot receives observations only. `--wire` preserves the prior
wireframe diagnostic. The nightly/static backend remains unchanged.

The rendered geometry has higher-resolution edges, while its palette and dither
patterns deliberately retain source appearance. It is the reference presentation
layer for later remastered assets. It is not the finished high-resolution art.
The subsequent [sprite implementation](pc-sprites-research.md) closes the seven
effect omissions recorded in this stage; its remaining limitations are separate.

## Material and palette recovery

The original tables at `DS:43a6` and `DS:4626` hold 32 pairs of words. A material
is more than a 16-colour index:

* When both words match, the original solid span at `0f8d:5aef` uses AL only.
* Otherwise, `0f8d:59fd` uses the second word on even scanlines and the first on
  odd scanlines. Even screen columns use the high byte, odd columns the low byte.
* Pattern phase uses original framebuffer coordinates, including the crew
  viewport origin. Enlarging the viewport does not shift the checkerboard.

`tools/pc_material_oracle.py` runs those original, unpatched span instructions
in Unicorn 2.1.4 and observes mode-2 VGA bit-mask writes. All 32 materials, both
row parities, 16 starting columns and ten span lengths pass: 10,240 cases and
3,276,800 checked pixels, including untouched pixels. Receipt:
`artifacts/pc-material-oracle-01.json`. The observation layer models the selected
VGA write mode; this is isolated span evidence, not a complete VGA or polygon
rasterization proof.

The game remaps its EGA palette. A conventional fixed palette gives wrong
colours. The trace copies the emulator's first 16 RGB entries at draw start and
scanout. Each submitted framebuffer retains its scanout palette independently
of later palette observations. The live viewer uses that palette for its paired
pass. Mid-scan palette changes have not been investigated.

## Backgrounds and drawing order

Read-only hooks observe `0b4d:3707` after the original horizon endpoint clipping,
including upper/lower mapped materials from SS:[BP+12], and `0b4d:36c8` for a
solid background. Backgrounds are associated with the original draw page and
cleared when that page starts being redrawn. In the four-station profile there
are 256 horizon passes and five solid-background passes.

The renderer submits one ordered triangle stream with depth testing/writes and
culling disabled. This preserves original painter order instead of introducing
Godot's depth-based surface selection. UV values select the observed material;
an unshaded shader samples a 2-by-2 RGB pattern. Original polygon fill mode and
separate outline/fill colours are retained.

`pc_surface_geometry.gd` uses fractional near-plane clipping, screen-space
triangulation and one-source-pixel outline quads. This is explicitly not the
original integer edge rasterizer. Vertical horizons remain unsupported and
reported. Sprite roots and opaque commands retain their existing omission
records. No replacement geometry feeds visibility, targeting or other gameplay.

Working if: all original RAM/video/input records remain unchanged, native
readback matches the observed palette/pattern phase, later original faces cover
earlier ones irrespective of depth, and unsupported commands remain visible.

## Verification

* `pc-material-controls-comparison-01.json`: all 1,167 frame records and all 23
  decoded stage states match the retained unmodified source baseline. Ten checks
  cover four crew stations, driving, braking, turret rotation, firing and world
  rebasing. There are 261 complete passes, 34,444 exact original vertex-cache
  checks and 1,162 paired presentations after five startup-unavailable frames.
  The seven previously recorded sprite-root omissions remain open.
* `pc-solid-fixture-01.log`: all 261 passes render without surface warnings;
  33,551 projected vertices pass the unchanged 0.01-source-pixel threshold.
  Maximum projection error is 0.003906. This tests projection, not integer fill.
* `pc-surface-native-test-01.log`: native Godot GPU readback passes all 16 palette
  colours, 64 dither positions, both painter-order tests and sky/ground colours.
* `pc-solid-recorded-native-01.png`: native filled replay of the last fixture
  pass. It is a recorded replay, not a paired live-frame comparison.
* `pc-solid-live-native-02.log`: live side-by-side native capture exits zero.
  `pc-trace-viewer/capture.json` records draw pass 116; `original-frame.png` and
  `surface-view.png` retain separate source and Godot images.
* `pc-solid-live-integration-01.log`: the native process-pipe test passes with
  filled rendering enabled, 15 sampled paired passes, 161 vehicle polygons,
  no surface warnings and graceful helper shutdown. Its shorter scenario has
  no unsupported commands; the broader profile still has seven sprite omissions.
* `validation-20260927T005801Z/results.txt`: all twelve aggregate stages pass,
  including 107 Python tests and original-file preservation.
* `pc-trace-viewer/pixel-comparison.json`: 24,219 of 24,832 source-pixel centre
  samples match exact RGB (97.5314%). The comparison includes original text,
  reticle and target-box overlays that are not yet reproduced, plus fractional
  versus integer edge differences. This is one-scene evidence, not a general
  raster-equivalence acceptance threshold.

Visual review was performed by the author of this implementation. The paired
image shows corresponding road edges, trees and a distant vehicle with the
original cyan/green palette. Original cockpit/HUD remains on the reference side.
The optional Impeccable linter is unavailable in this repository; native Godot
tests and image inspection provide the applicable rendering evidence.

## Retained failure and correction

The first live solid capture completed its nine samples but timed out waiting
for `frame_post_draw`; `pc-solid-live-native-01.log` retains the failure. The
capture now explicitly draws and synchronizes on the main thread before GPU
readback. It advances no PC frames and keeps the same capture deadline. The
second capture succeeds. The underlying reason the ordinary draw notification
did not arrive was not established. See the official
[RenderingServer API](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html).

## Custody and reproduction

The tracing core uses DOSBox Pure commit
`73e03aa145e0549ed4d5a20f8e65532714da33f5`. Its new binary hash is
`3166c246da684464ea4cd950ca5685bd491d4a4c59860a91ed57b7923ceda803`.
The previous tracing binary/manifest remain in `artifacts/pc-trace-build-v2`;
the prior wireframe screenshot is in `artifacts/pc-wire-viewer-v2`. Original
GAME files, content archive, baseline library and mission-entry state are
unchanged. Local emulator/reference/derived assets remain excluded from Git.

```sh
python3 tools/build_pc_trace_core.py
.runtime/pc-analysis-venv/bin/python tools/pc_material_oracle.py \
  --capture artifacts/pc-scanout-trace-02/first-render.bin \
  --output artifacts/pc-material-oracle-NEW.json
python3 tools/capture_pc_render_trace.py --mode trace --profile controls \
  --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-material-controls-NEW
./tools/godot.sh --headless --script res://tests/test_pc_draw_pass.gd -- \
  --fixture "$PWD/artifacts/pc-material-controls-NEW/report.json" --solid
./tools/godot.sh --script res://tests/test_pc_surfaces.gd -- --native
./tools/godot.sh --headless --script res://tests/test_pc_live_bridge.gd -- --trace
./PC\ Bridge.command --trace --capture
./tools/validate.sh
```

Remaining work includes sprites/opaque commands, integer clipping/coverage,
cockpit/HUD reproduction, high-resolution replacement art, runtime timing
calibration, full-mission/campaign evidence and release packaging. This local
surface milestone does not complete the remaster goal. Nothing was published.

## Arbitrary RGB correction, 2026-09-27

A native 1,280-swatch test expanded the earlier two dark-grey failures to all
256 grey levels, three primary ramps and a mixed-colour permutation. Before the
fix, 390 swatches failed, with inputs 1 through 7 becoming black. Source images
and the EGA palette were unchanged. The failed baseline remains in
`artifacts/pc-colour-before-01.json`.

The version-matched Godot 4.7.2
[scene shader](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/gles3/shaders/scene.glsl)
converts unshaded albedo through the approximate cubic and power functions in
[tonemap_inc.glsl](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/gles3/shaders/tonemap_inc.glsl).
These functions are not inverses. A CPU model predicted the main darkening,
though 131 readback samples differed by quantization from that model; the CPU
model alone was not accepted as repair proof.

`pc_colour.gd` inverts that pair for the Compatibility material lookup. The
256-entry mapping is computed once, is bounded/monotone, and uses float RGBA
storage to avoid requantization before shading. Original source RGB is retained.
Other rendering backends bypass the compensation. This is scoped to the current
unshaded, nearest-filtered, linear-tone-map presentation path. HDR, interpolated
colour, lit remastered materials and other platforms need separate evidence.

`artifacts/pc-colour-after-02.json` now passes all 1,280 exact RGB readbacks in
Godot 4.7.2 Compatibility on M1 Max. The aggregate gate checks the mapping and
geometry headlessly; GPU equality requires the native test.

Working if: all 256 levels in each native test channel survive exactly, the EGA
palette/dither and painter-order checks stay unchanged, and source artwork is
never pre-darkened or overwritten.

Regression receipts, all with terminal exit zero:

* `pc-colour-surfaces-native-01.log`: EGA palette, dither, painter order and horizon.
* `pc-colour-sprites-native-01.log`: 57,546 exact native bitmap pixel checks.
* `pc-colour-ui-native-01.log`: 3,648,005 exact RGB checks, including 1,004,578
  original UI pixels, 659,422 world-texture samples and five UI-over-effect pixels.
* `validation-20260927T024842Z/results.txt`: all 16 stages, including 127 Python
  tests, source preservation and existing Godot/runtime gates.

```sh
./tools/godot.sh --disable-render-loop --script res://tests/test_pc_colour.gd -- \
  --native --output "$PWD/artifacts/pc-colour-NEW.json"
```

No original emulator or simulation code changed in this correction. The native
colour gate must be rerun on engine upgrades before retaining this compatibility
compensation. New high-resolution textures are not yet installed.
