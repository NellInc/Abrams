# Source-shaped map and mission frame

`pc_map_art.gd` supplies a resolution-independent FRAME surround for the original
START and END screens. It replaces the bevel, green inset rule and all twelve
fasteners. The original content rectangle `(10,10,300,166)` and lower patterned
strip `(0,187,320,13)` remain untouched. Original frontend typography can render
above it independently. This surface is implemented; dynamic tactical maps and
the patterned footer are not counted as restored artwork.

## Source custody and Genesis correspondence

The resource is the fingerprinted `GAME/FRAME`, decoded through the existing
resource/packed-plate implementation. Original START at `0000:0be1` calls loader
`0760:07fa` with DS:02d0, and END at `0000:02e4` calls `0477:0802` with DS:03aa.
Both strings are `frame`. `pc_map_frame_oracle.py` executes each unchanged
argument block in an isolated CPU, stopping before file loading; it also verifies
each original far-call target. This proves the source reference rather than a
full-screen live rendering path.

The twelve PC fasteners occupy four rotated forms of one exact 5x5 motif. The
same 25-pixel geometry occurs ten times in the existing original Genesis commander
donor after matching its grayscale palette roles. The source catalog records all
twelve placements, quarter turns, ten donor matches and hashes. The vector drawing
retains the original fastener position and lighting orientation and uses the
Genesis gray/white palette. No new bitmap texture or world model is introduced.

`build_pc_map_frame_catalog.py` reproduces the catalog under
`local-art/pc-map-frame-v1`. Runtime loading validates catalog, source executable,
FRAME and donor hashes. Each displayed frame must exactly match the complete
source border, including the preserved footer, before any replacement appears.
Wrong programs, stale supplied frontend program identity, partial borders,
changed pixels and unsupported image formats clear the replacement. The module
reads no gameplay, campaign or tactical object state.

## Existing map domain and remaining work

The manual describes two commander overhead views, selected by Z: whole scenario
and local close-up. Source inspection identifies SIM `11b0` as the overview
refresh wrapper, `0f6a` as its 144x96 rectangle at `(16,63)` with 3x2 cell draws,
and `10de` as the pixel-marker save/restore and current marker draw route. `11ea`
selects the close-up path at `0ee8` when DS:799f is nonzero; its explicit two-line
marker calls are at `1263` and `1279`. The keyboard handler at `2002..2012` toggles
that original byte and requests the original refresh. These source findings do
not establish a fresh live trace or permission to disclose unseen entities.

The current observer does not provide complete source-command identity for these
map draws. A future dynamic map implementation needs observed original draw
commands and page/scanout pairing, then exact current-pixel verification of the
complete map region. Terrain, object visibility, marker colour/blink and zoom must
remain source-selected. Inferred markers from colours or fresh game-state reads
would weaken the existing visibility guarantee. Both dynamic map views therefore
remain original pixels, explicitly unfinished in this pass.

## Validation

- Original isolated argument-block oracle: 2 cases pass.
- Python catalog/custody/full-border tests: 2 pass.
- Godot headless acceptance/mutation checks: 18 pass.
- Native Compatibility rendering: 26 checks pass at 1280x800 and 1920x1200;
  every content/footer output pixel matches nearest-neighbour original bytes.
- The native screenshot was visually inspected for fastener placement, rule width,
  clean frame borders and retained text. This is author review, not independent
  human design acceptance or integrated live gameplay proof.

Evidence: `artifacts/finish-20260928/maps/`; integration hooks and remaining
boundaries are recorded in `artifacts/finish-20260928/map-report.md`.

## Dynamic commander maps, source-owned vector path

`pc_dynamic_map.py` observes the original overview clear and line calls at
`0F73`, `1011`, `102C`, the overview player dot at `1197`, and the local player
mark at `1263` and `1279`. `abrams_trace.h` events 43–45 carry those visible draw
arguments and a completed 144×96 map readback. These hooks read the original
stack, rendering mode, page and planar framebuffer only. They introduce no guest
writes, new simulation, hidden object lists, or checkpoint fields.

The overview intentionally consists of 3×2 cells. The local player mark consists
of two horizontal 2-pixel lines. `pc_dynamic_map_art.gd` renders those exact
source-colour rectangles at the presentation resolution. It preserves the
original grid style. Local terrain/world geometry continues through the existing
original draw-pass renderer, unchanged by this module. No inferred additional
map detail is introduced.

The observer reconstructs every overview pixel from the observed clear/cells/dot
and rejects a mismatch. Local observations verify both mark lines. Both modes
require complete map RGB equality with the scanout-paired framebuffer before
export. Godot checks the full-region hash and independently rasterizes the
proposed vector rectangles back onto the original map before drawing. Missing
entries after a mid-draw attachment fall back until a complete draw is observed.
The map never selects targets or reveals positions beyond original visible ink.

Root integration: create a `pc_dynamic_map_art.gd` child in the authored tandem
path, clear it when clearing presentation, and call `set_frame(source,
presentation)`. It consumes `presentation.dynamic_map`, and the original source
texture remains underneath. Its local mode draws only the player mark; its
other pixels are transparent. Do not apply the module in Original mode.

Checks:

```
.runtime/pc-analysis-venv/bin/python tools/pc_dynamic_map_oracle.py --output artifacts/finish-20260928/maps/dynamic-oracle.json
python3 -m unittest tests.test_pc_dynamic_map tests.test_pc_render_trace
./tools/godot.sh --headless --script res://tests/test_pc_dynamic_map.gd -- --live
./tools/godot.sh --script res://tests/test_pc_dynamic_map.gd -- --native --live
```

The local live gate uses `tools/verify_pc_dynamic_map.py` separately in trace and
baseline modes from the same source-baseline mission-entry checkpoint. Its
455-frame keyboard route covers commander entry, both Z map toggles, station
exit and commander return. The report binds RAM/video/input parity to the exact
new core SHA. This short gate does not renew long endurance evidence obtained
against an earlier core.

For complete paired-presentation integration, capture to
`artifacts/finish-20260928/maps/live-integration` with the verifier above, then add
`--integrated` to the Godot test command. The integration fixture retains the
original program and full presentation, including actual masks and world pass.
The test runs the real tandem child, replays that world, and checks EGA/Genesis
clearing plus exact Upscaled packet/native-pixel restoration after each switch.
