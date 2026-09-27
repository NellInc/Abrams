# Original EGA scanout to live Godot drawing

## Scope and architecture

The PC executable remains the only simulation authority. The optional source-built
trace backend now streams actual static and dynamic drawing passes into the live
Godot viewer. This note records the initial wireframe integration. The subsequent
[surface implementation](pc-surfaces-research.md) adds filled geometry and original
materials; `--wire` retains the diagnostic view. Opaque/sprite command rendering,
remastered models and complete mission parity remain required. The nightly
reference backend stays the default.

The preceding interactive turn answered Nell's architecture question and
rechecked existing evidence; it made no implementation progress. This pass
implements the next available safe action, live render-pass attribution.

## Why the newest completed pass is wrong

Original EGA setup at `0f8d:3fbf..3fd3` establishes display/draw pages at segments
`a000` and `a200` (byte offsets 0 and 8192 in planar video memory). The camera
background routine selects `DS:35a2` into `DS:35a8` at `0b4d:3405..3408`.
Original `0f8d:59bd..59fc` swaps the page segments and writes the CRTC start-address
high byte. The hardware latches that start address separately from completion of
the original polygon drawing callback.

The pinned DOSBox Pure source uses `vga.config.real_start` when it begins scanning
a frame (`src/hardware/vga_draw.cpp`, `VGA_VerticalTimer`). A completed framebuffer
then occupies one of three host buffer slots. `retro_run` retains a reference to
that slot before advancing the worker and later submits the retained buffer.
Observing current RAM or the newest draw callback at submission time cannot
establish which geometry the retained framebuffer contains.

In the 180-frame trace, 152 presented frames belong to a pass older than the
newest complete pass at the host sample boundary (after its worker fence). This
is a measured synchronization dependency.

## Read-only hook contract

The tracing build adds three host annotations:

1. At assignment of the scanout address, capture the latched original EGA page.
2. At `GFX_EndUpdate`, attach that observation to the completed host buffer slot.
3. Immediately before the normal software `video_cb`, identify the submitted slot
   and copy its XRGB8888 framebuffer bytes for comparison with the libretro host callback.

The guest hooks additionally observe:

- Background draw-page selection at `0b4d:340b`, before the clear/drawing work.
- Every selected object root at `0b4d:28d0`, resetting stale object context even
  when a sprite-only root skips the matrix-ready hook.
- Opaque commands at `0b4d:31a6`, recorded explicitly as unsupported.
- The original CRTC write at `0f8d:59e4` for research; the actual scanout address,
  rather than this earlier write, determines presentation attribution.

`tools/pc_render_trace.py` freezes the complete pass for the scanned page and
carries it through the exact buffer slot. It checks submitted framebuffer bytes
and dimensions against the host's received frame. A page being redrawn during
scanout is explicitly unavailable. Startup frames without an observed complete
pass are unavailable too. The viewer clears geometry in these cases; it never
falls back to a different pass or an authored simulation.

Live history retains two completed passes, two ordinary EGA page associations
and the core's three framebuffer slots. Research captures retain bounded pass
history. Object-root, opaque-command and unattributed-polygon omissions are
reported in the presentation packet and viewer caption.

Working if: the original framebuffer bytes remain identical to the unmodified
source baseline, submitted-slot hashes match the host callback, offscreen passes
are never selected solely because they are newer, and unsupported drawing is
visible in the packet/UI rather than silently counted as complete.

## Native Godot integration

`PC Bridge.command --trace` selects the separately pinned source backend and its
compatible source-build mission-entry state. The host emits protocol 3 with a
`presentation` record; protocol 2 remains the default nightly/static bridge.
The recorded-pass renderer is reused directly beneath the camera. Vertices are
already in original camera coordinates, so the viewer applies an identity camera
basis and the original asymmetric frustum, avoiding a second camera rotation.

The diagnostic readouts still come from the paired VGA-boundary RAM snapshot.
They are not labelled an atomic simulation tick or the exact UI-text draw time.
Geometry uses its own original drawing-pass camera and world snapshot. Real-time
wall-clock pacing and reference-machine CPU calibration remain open.

## Evidence so far

- `artifacts/pc-scanout-comparison-02.json`: all 180 input/RAM/framebuffer records
  match the prior unmodified source baseline. There are 45 complete drawing
  passes, 5,341 exact original vertex-cache checks and 175 paired presentations.
  Five startup presentations lack an observed complete pass and say so.
- `artifacts/pc-scanout-live-godot-01.log`: native process-pipe integration passes
  driver/gunner controls, movement, world rebasing, braking, turret rotation,
  ammunition consumption, PNG decoding and graceful child exit. Fifteen sampled
  presentations include 161 vehicle polygons and no observed unsupported commands.
- `artifacts/pc-scanout-native-01.log` and
  `artifacts/pc-trace-viewer/paired-view.png`: native side-by-side capture exits
  zero. The root author inspected the resulting original scene and corresponding
  wireframe. This is self-review of work produced in this session.
- `artifacts/validation-20260927T003103Z/results.txt`: all eleven aggregate stages
  pass, including the new scanout attribution unit tests and original-file
  preservation. The optional Impeccable executable is unavailable; native Godot
  rendering supplies the applicable layout evidence.

These checks do not establish all-mission behaviour, filled raster parity,
visibility/hit equivalence of future high-resolution assets, historical PC timing,
or a release candidate.

## Broader four-station check

`artifacts/pc-scanout-controls-comparison-01.json` compares fresh baseline and
traced source-core runs over 1,167 input frames. Every full-RAM hash, framebuffer
hash, input set and end-of-stage decoded state matches. Ten explicit checks cover
all four stations, returning to gunner, movement, completed braking, turret
rotation, one HEAT consumed and a world-window rebase.

The trace contains 261 complete passes, 34,444 exact original vertex-cache
comparisons and 1,162 paired presentations after the same five unavailable
startup frames. Seven unsupported sprite-root draws occur (commands 51, 52, 53,
passes 165 through 171); these remain renderer omissions and are retained in the
comparison receipt. No completion claim is inferred from a zero omission count
in the shorter initial trace.

`pc-scanout-controls-projection-01.log` verifies 33,551 projected points across all
261 passes in Godot, maximum error 0.003906 source pixels, below the unchanged
0.01 threshold. This compares fractional projection, not original integer raster
coverage. The unchanged default backend separately passes its live integration
check in `pc-scanout-reference-live-01.log`. The aggregate gate contains 102 Python
tests; the later capture-CLI controls extension is verified by both full-profile
terminal runs and the projection check above.

## Retained failed checks

The first source-build patch correctly refused a nonunique `buffer_active`
anchor. The second occurrence was a separate reset path. Anchoring the exact
newline selects only `GFX_EndUpdate`; the guard remains in place. See
`pc-core-scanout-build-01.log` and the successful `-02.log`.

The first trace launch supplied a mistyped source-core hash and was rejected by
the existing restore guard (`pc-scanout-trace-01.log`). The corrected run reads
the pin from the manifest. The capture CLI now requires an explicit state file
and derives the source-baseline pin by default. Its former nightly-state default
was incompatible with the source-built backend and was broken. No guard was
removed. The old trace binary/manifest are retained locally in
`artifacts/pc-trace-build-v1`.

## Reproduction

```sh
python3 tools/build_pc_trace_core.py
python3 tools/capture_pc_render_trace.py --mode trace --frames 180 \
  --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-scanout-trace-NEW
# Full bounded driving/firing and four-station profile, both backends:
python3 tools/capture_pc_render_trace.py --mode baseline --profile controls \
  --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-scanout-controls-baseline-NEW
python3 tools/capture_pc_render_trace.py --mode trace --profile controls \
  --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-scanout-controls-trace-NEW
./tools/godot.sh --headless --script res://tests/test_pc_live_bridge.gd -- --trace
./PC\ Bridge.command --trace --capture
```

## Material evidence identified during this stage

Original material IDs exceed 15. The observed values include 17 and 26, so a
plain 16-colour palette lookup would be wrong. `0f8d:0c34..0c9d` reads the material's
words from `DS:43a6` and `DS:4626`; the EGA span routine at `0f8d:59fd` alternates
word/byte colours by scanline and pixel parity. For example, the captured ID 17
has words `0700` and `0007`. These are source/snapshot observations, not yet a
verified replacement material implementation at this stage. The subsequent
[surface research](pc-surfaces-research.md) implements and tests those patterns,
with integer clipping/raster coverage still explicitly separate.
