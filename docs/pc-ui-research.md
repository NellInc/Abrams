# Original cockpit and HUD in the tandem renderer

## Composition contract

The original executable still runs every gameplay and rendering instruction.
Godot replaces observed world pixels inside the paired camera rectangle, while
retaining the original cockpit, reticle, target box, instruments and messages.
This is a source-resolution UI foundation for the remaster. It does not count as
finished high-resolution cockpit artwork or full-game presentation parity.

The original full frame is the fallback when the world pass, camera or UI mask
is unavailable. Pixels outside the main paired camera remain original, including
the commander's map. Camera rectangles, masks and displayed pixels follow the
same completed scanout and host buffer slot. Current RAM state never chooses
which cockpit belongs on an older displayed frame.

Working if: the original reticle can cover a new world effect, bitmap-transparent
cockpit edges expose Godot scenery without copied-background rectangles, and
missing attribution displays the actual original frame with an explicit label.

## Read-only EGA provenance

`abrams_vga_ownership.h` tracks ownership of every bit in each of four EGA planes.
UI bits are one; world bits are zero. Unobserved initial memory is conservatively
UI. The observer follows latch reads, all four write modes, plane and bit masks,
rotation, set/reset and hardware AND/OR/XOR operations. It changes no guest RAM,
VGA register, latch, instruction, event schedule or cycle count.

The original world phase begins at background-page selection `0b4d:340b` with
`DS:358c == 012c`, and ends at `0000:02c1`. Source phases retain their previous
instruction evidence. At each actual EGA scanline, the observer samples the
corresponding pixel addresses, rather than consulting the latest drawing page
after the frame. All 200 rows must be present in the supported 320x200 mode.
Event 19 delivers a binary mask immediately before event 11 completes that
framebuffer slot. The Python collector rejects mismatched slots and malformed
masks, then compresses the mask as an L8 PNG for the existing local bridge.

Each pixel remains original if any contributing plane bit belongs to UI.
This avoids colour-key holes: opaque black, or UI drawn over an identical world
colour, still belongs to the original interface.

### CPU bitmap transparency

The first live masks retained rectangular pieces of scenery around the tank
barrel and cupola. `pc-ui-controls-01` preserves that failed visual result.
The original driver clears opaque bits through VGA, then ORs source planes into
the destination with CPU read/modify/write instructions (`0f8d:46ff` onward).
Those fully assembled writes can copy transparent destination bits even when
the VGA raster-op register says replace.

The observer now samples the actual descriptor and preservation plane at the
`0f8d:0347` bitmap dispatch, checks that it resolves to the verified `4512`
driver, and retains previous provenance under transparent pixels throughout
the original blit. Signed placement, clipping, edge bytes and drawing page are
accounted for. The recorded far-return address ends this observation; no
original instruction is substituted. Unsupported descriptors invalidate UI
attribution instead of guessing a mask.

The corrected four-station mask contact sheet is
`artifacts/pc-ui-controls-02/ui-mask-contact.png`. The source bitmap path itself
has the separate 512-case original-instruction oracle described in
`pc-sprites-research.md`; the new ownership tests do not replace that evidence.

## Evidence

* `pc-ui-ownership-test-02.log`: the compiled C++ observer passes 4,096 mode,
  operation, rotation and phase combinations, 131,072 plane-bit comparisons,
  32,768 pixel unions, and 2,048,000 bitmap-provenance pixel comparisons across
  16 aligned, unaligned, clipped, offscreen and cross-page cases.
* `pc-ui-controls-comparison-01.json`: all 1,167 input/RAM/video frame records
  and 23 decoded stage states equal the retained unmodified source baseline.
  All ten control checks pass; 261 completed passes contain no unsupported
  commands in this scenario. 1,166 frames have UI masks; 1,162 have paired world
  geometry. Startup frames conservatively retain the original display.
* Python collector checks cover scanout/slot custody, PNG round trips, missing
  masks and invalid dimensions/values. Godot checks cover source fallback,
  camera bounds, binary L8 validation and opaque-black preservation.
* `pc-ui-live-integration-01.log`: live process-pipe inputs, movement, braking,
  turret, ammunition and graceful helper exit pass with 15 paired draws, 15
  accepted UI masks and 161 vehicle polygons.
* `pc-ui-viewer-native-02.log` and `pc-ui-viewer-comparison-01.json`: the actual
  live viewer captures with automatic redraws disabled and exits cleanly. All
  64,000 source-pixel centre samples match either the original UI (39,537) or
  that draw's world texture (24,463), with zero composition mismatches.
* `pc-ui-native-04.log` and its report: 3,648,005 exact native RGB comparisons
  pass, including 1,664,000 source-reconstruction pixels in 26 captures,
  1,004,578 retained original UI/outside-camera pixels, and 659,422 composited
  world pixels. All five reticle-over-effect positions identified in the
  preceding sprite pass now match the original final frame. Synthetic colours,
  opaque black and missing-attribution fallback are included in the total.
* `validation-20260927T015107Z/results.txt`: all 14 source-gate stages pass,
  including 117 Python tests and unchanged original files. The subsequent
  viewport-order repair has the controlled native regression evidence below.

### Viewport-order regression

The first native UI test checked retained pixels but omitted replacement-world
pixels. Its PASS was insufficient: the author's visual inspection found blank
commander and cupola scenery. Comparing the saved composite against its saved
world texture found 13,018/13,018 and 35,356/35,356 mismatched world pixels.
The next ordinary-redraw run passed after adding those assertions, so that pass
alone did not establish a repair.

`pc-ui-native-03.log` reproduces the failure with `--disable-render-loop`, forcing
one explicit draw per capture. The world viewport was a sibling of the
composition viewport, which could sample its unrendered texture. Making it a
child establishes child-first rendering. The unchanged single-draw test then
passes in `pc-ui-native-04.log`; no extra PC frames or extra redraws were added.
The live viewer uses the same hierarchy. Failed receipts and the earlier
insufficient test output remain available.

These images and code were produced and reviewed by the same assistant.
Native validation used Godot 4.7.2 Compatibility on the local M1 Max. No optional
Impeccable linter is configured for this GDScript-only project; none was installed.

Capture names such as `driver` or `gunner` name the input stage. They are not a
claim that the corresponding cockpit has already appeared. The original can
still be presenting an older station frame; preserving that pairing is intended.

## Reproduce locally

```sh
python3 tools/build_pc_trace_core.py
python3 -m unittest tests.test_pc_ui_ownership tests.test_pc_render_trace -v
python3 tools/capture_pc_render_trace.py --mode trace --profile controls \
  --capture-ui --capture-sprites \
  --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-ui-controls-new
./tools/godot.sh --disable-render-loop --script res://tests/test_pc_tandem_frame.gd -- \
  --native --fixture "$PWD/artifacts/pc-ui-controls-new/report.json" \
  --output "$PWD/artifacts/pc-ui-native-new"
./PC\ Bridge.command --trace
```

## Local custody

Source revision: DOSBox Pure `73e03aa145e0549ed4d5a20f8e65532714da33f5`.
Unmodified baseline SHA-256:
`57edbd309eb2ab6264b70188c3a85408fbcfa8c62e83b8c7b9c39b7309f61ac6`.
UI-foundation observed-core SHA-256 (before the later plate extension):
`f0af54e7f16a412651eaadec93d8572564d38e75992580e80f23cb6fa3ab37af`.
Ownership header SHA-256:
`af16f5561b6f8069d9c545b84fd253eab591bfca8c1e4290107c0847b1d7d488`.

The build manifest records exact original/patched dependency file hashes and
compiler identity. The earlier sprite core remains in `pc-trace-build-v4`; the
first UI prototype remains in `pc-trace-ui-prototype`. No proprietary files,
captures, emulator binaries or derived graphics are added to Git or published.

## Remaining boundaries

The later plate provenance, source-verified strut redraws, moving driver assembly and four-station
material pilot are documented in
`pc-ui-art-workflow.md`, including current core pins and bounded replay evidence.
High-resolution cockpit instruments/fonts, remastered world assets, remaining opaque
commands, exact polygon edge coverage, other game modes and full mission/campaign
coverage remain open. The map is retained from the PC frame. EGA RGB fidelity
is distinct from the arbitrary-colour Compatibility correction subsequently
verified in `pc-surfaces-research.md`.
Wall-clock pacing and historical machine timing remain separate acceptance work;
matching frame-stepped RAM/video hashes establishes neither.
