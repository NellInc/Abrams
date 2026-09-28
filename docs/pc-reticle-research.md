# Source-verified gunner graticule

## Visual and gameplay contract

The extracted Genesis gunner screen is the visual reference:
`local-art/genesis/source/gunner-original.png`, SHA256
`7bfad2d4bae51ab9a59a7e93ddbcaffcaeec35b19ddbc4c96e135dd54319f5b3`.
Its square-ended, open-centre sight is retained. The original PC executable
supplies the eight lines, projected vertical position, clipping, colour and
visible timing. There is no new aiming dot, interpolated position, range mark,
target indicator or replacement targeting calculation.

The Godot layer uses analytic rectangle coverage at display resolution.
At integer scales its ink is pixel-identical to the original. At fractional
scales its edges receive subpixel coverage instead of uneven nearest-neighbour
steps. Coverage remains inside the original source-owned ink cells. A copy of
the composition mask removes only that verified old ink, exposing the paired
Godot world underneath. Other symbols and scene pixels remain untouched.

Working if: the original aim gap, line endpoints and colour remain unchanged;
integer-scale captures match the previous image; fractional-scale changes are
confined to the original sight pixels; unsupported frames retain PC content.

The research viewer still renders its tandem surface at 1280x800. This pass
makes the sight layer resolution-independent and tests three target sizes;
it does not complete native-resolution window/fullscreen configuration.

## Original source and observation

Authority: `GAME/SIM.EXE`, SHA256
`9ee5a5898ddcb8192d30b4083981419515eb3ca220e6cbcd214df628bb164099`.
Main-code addresses are load-segment relative. DS is load segment plus `19e0`.

* `65e4..6635` draws eight table-driven lines. `21ea..2276` supplies the original
  integer projected centre. Observation at `65f1` reads the returned AX; no
  projection or targeting formula is substituted in the live bridge.
* DS:`0bba..0bf9` contains eight signed endpoint tuples, centred at X=159.
  The table hash is
  `b7cba01774ea26a79711b547634c0b0c46abebe9f9b214f110b37db594316a9c`.
* `6620` calls the original `0f8d:025a` line wrapper eight times. Horizontal
  strokes include both endpoints. Vertical strokes exclude their destination.
  Clipping can swap the endpoints before rasterization. The normal centre-60
  graticule covers 106 distinct source pixels.
* `6670..66a6` supplies the gunner clip `[32,13,287,109]` and black/white colour.
  `66db/66f9/6717/6735` draw the separate target box; that remains original.
* Native observation events 37, 38 and 39 copy entry state, line arguments and
  completed EGA backing-plane pixels. They do not read guest VGA latches, write
  guest memory, skip instructions or alter emulated cycles.

The observer checks the original table, all eight calls, page, mode, station,
clip and colour. Beginning another draw invalidates that page's previous
candidate. Scanout retains the completed candidate, then requires its entire
51x97 RGB readback to match the actual displayed framebuffer. Godot independently
checks the geometry, page, palette, source fingerprint, full crop hash and UI
ownership of every ink pixel. Incomplete, changed or unknown content falls back.

An initial static lookup mistakenly reused a relocated segment address from an
older diagnostic. The retained `sight-wrapper.asm` is not authority. The corrected
lookup and main-code listings are in `artifacts/pc-reticle-source-01/`; all final
CPU evidence compares executed bytes with unpacked, relocated original bytes.

## Evidence

* `artifacts/pc-reticle-cpu-03/oracle.json`: 522 unchanged whole-reticle routine
  fixtures plus 304 direct original-line-wrapper clipping fixtures. All 331
  executed instruction locations match the original; all 216,530,944 plane
  bytes compare exactly, including untouched pixels. Both colours/pages and
  every integer clipping centre from -21 through 130 are covered. Whole-routine
  fixtures include mostly fully clipped cases; 30 have visible ink. Isolated
  fixture inputs are not claims of live reachability or exhaustive targeting.
* `artifacts/pc-reticle-live-parity-02.json`: all checks pass across 1,458 frames.
  Trace and uninstrumented baseline RAM, framebuffer, inputs and stage states
  match. All 337 observed sight draws complete. There are 1,207 matching visible
  candidates; 246 mismatching presented candidates retain original content.
  Centres 60, 61, 62 and 64, zoom changes, both thermal colours, return to normal
  colour, station transitions and commander absence are observed live.
* `artifacts/pc-reticle-native-01/report.json`: 1,003 assertions and 51,942,400
  full-frame pixel comparisons pass, terminal exit 0. Thirty samples at
  1280x800, 1728x1080 and 1920x1200 cover six live states and four isolated white
  clipping examples. Integer scales match exactly. Fractional changes remain
  inside original ink and match the analytic coverage over a deliberately
  unrelated patterned world. That pattern is a test background, not game art.
* The expanded headless geometry comparison passes 1,154 checks against all
  826 CPU fixtures. Seven Python tests cover line/context corruption, page
  invalidation, immutable scanned candidates, RGB overwrites and callback errors.
  A first Godot run caught float-versus-int array membership after JSON transport;
  explicit integral conversion fixes it. The earlier parse-error run and this
  failed contract run are not passing evidence.
* `artifacts/pc-reticle-play-01/reticle-verification.json`: actual Play launcher
  exits 0 with the new layer active. Its packet equals the source observer's
  packet and its source crop hash matches independently. Game state, original
  framebuffer and the complete 1280x800 remastered image match the pre-change
  capture exactly, including the repaired cockpit and ammunition.

The implementing assistant inspected the actual Play image and fractional white
sight test. This is self-review, not independent aesthetic acceptance. The
optional Impeccable executable was unavailable; no dependency was installed.
Final aggregate evidence is recorded in `WORK_LEDGER.md`.

## Reproduction

From the repository root, with the existing local source dependencies:

```sh
.runtime/pc-analysis-venv/bin/python tools/pc_reticle_oracle.py \
  --capture artifacts/pc-source-boot-01/mission-entry/conventional.bin \
  --output artifacts/pc-reticle-cpu-NEW/oracle.json
python3 tools/build_pc_trace_core.py
python3 tools/capture_pc_render_trace.py --mode trace --profile reticle \
  --capture-ui --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-reticle-live-trace-NEW
python3 tools/capture_pc_render_trace.py --mode baseline --profile reticle \
  --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-reticle-live-baseline-NEW
python3 tools/verify_pc_text_trace.py \
  --trace artifacts/pc-reticle-live-trace-NEW/report.json \
  --baseline artifacts/pc-reticle-live-baseline-NEW/report.json \
  --output artifacts/pc-reticle-live-parity-NEW.json
./tools/godot.sh --disable-render-loop --quit-after 2400 \
  --script res://tests/test_pc_reticle.gd -- --native \
  --oracle "$PWD/artifacts/pc-reticle-cpu-NEW/oracle.json" \
  --fixture "$PWD/artifacts/pc-reticle-live-trace-NEW/report.json" \
  --output "$PWD/artifacts/pc-reticle-native-NEW"
```

Retained proprietary sources, snapshots, diagnostic images and native libraries
remain local. No redistribution, publication or whole-game parity is claimed.
