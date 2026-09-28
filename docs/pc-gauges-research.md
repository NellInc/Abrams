# Source-driven cockpit gauges

## Scope and presentation

The speed bars in the gunner and commander stations, commander fuel bar, and
both temperature lamps now have resolution-independent geometry. Their clipped
edges and restrained bevels follow the flat illuminated cells in the extracted
Genesis cockpit and the selected Genesis-derived cockpit artwork. PC output
supplies layout, colour meanings, visible segments and warning phase. No hidden
value, invented scale, glow, interpolation or additional precision is displayed.

This pass was authored and reviewed within the same Codex session. Rendered
inspection and executable checks are evidence; Nell's visual acceptance remains
separate. Orientation, reticles, status-system lamps and further instrument
variants remain open.

## Original executable evidence

Source: unchanged `GAME/SIM.EXE`, SHA256
`9ee5a5898ddcb8192d30b4083981419515eb3ca220e6cbcd214df628bb164099`.
Addresses below are load-relative code segments or original DS offsets.

* `0000:5a72..5ae7` draws the segmented bar. It computes signed absolute input,
  multiplies by segment count, narrows the result to signed 16 bits and divides
  by the denominator with truncation toward zero. Its overflow and -32768
  behaviour are retained in the isolated comparison model. Godot does not
  re-evaluate this formula.
* Speed caller `5b2e..5b96`: 39 strips at two-pixel pitch, threshold 30,
  denominator 76, x13 for gunner or x16 for commander, y186. Other stations
  return without drawing. In the selected palette all active strips are green.
* Fuel caller `5ae8..5b2c`: 28 strips, threshold 4, denominator 100,
  x103/y186. The first four active strips are red, subsequent ones green.
* The bar calls line wrapper `0f8d:025a` with endpoints y186 and y192.
  **The original line rasterizer excludes the final endpoint.** Actual strips
  are one by six pixels, y186..191; y192 is the existing frame border.
* Classifier `7136..7181`: signed word79a4 below 175 selects green. Otherwise
  signed word887a at most 12 selects yellow, with higher values selecting red.
  The physical meaning of word887a is not established here.
* Gunner caller `5a14..5a70` and driver fragment `684f..6892` turn red to black
  when byte0a6a is zero. Green and yellow do not blink in these routines.
  They use filled rectangle wrapper `0f8d:1749`, respectively at
  `(271,154,13,11)` and `(233,190,19,7)`.

`tools/pc_gauge_oracle.py` runs the unchanged callers, classifier, line and
rectangle instructions under the already pinned Unicorn 2.1.4. Every newly
executed instruction location is checked against the unpacked and relocated
original executable. A narrow mode-2 VGA observer compares all four complete
64 KiB planes against expected output, including untouched bytes. No original
instruction is replaced. Test stack/data changes occur only in isolated fixture
memory, never in the running game.

Receipt: `artifacts/pc-gauges-source-01/oracle.json` and `oracle.log`:
1,332 cases, 409 executed instruction locations, 189,768 VGA writes and
349,175,808 plane-byte comparisons. Both pages, both caller palette branches,
all normal speed inputs from -76 to 76, all fuel inputs from -2 to 102, boundary
and overflow inputs, both warning thresholds and both blink phases pass.
The driver fragment is entered after its red-colour setup and stopped before
its containing function's epilogue; this is explicitly not a whole driver-call
or timing test. The first run rejected a rectangle driver's explicit mode-2
register reset; the observer was extended only to accept those known identity
pipeline settings, then the full oracle passed.

## Visible-frame binding

`pc_instrument_art.gd` validates the original palette through its tandem caller
and requires the exact original plate pixels/ownership around each gauge.
Every dynamic strip/lamp pixel must be UI-owned, overwritten after the plate
load (plate tag zero), and have an allowed uniform colour. Bars must be a
contiguous active prefix followed by gray, with the original fuel threshold
colours and unchanged black gaps. The driver additionally verifies its drawn
blue readout frame and surviving DRIVER plate strip above it.

Only the currently presented source image is examined. A RAM update before
scanout cannot advance the restored gauge. Mixed station frames are resolved
by their actual per-pixel plate provenance, not the latest selected station.
An incomplete draw, changed pixel, unexpected colour, lost ownership or bad
context keeps original pixels for the whole affected gauge. Snapshot restores
without observed plate provenance remain original until the game redraws them.

Rendering stays inside the proven rectangles. Native tests compare the entire
composition with the gauges enabled and disabled, check central source colours,
and require coverage of all five gauge placements. Constructed green, yellow,
red and black warning fixtures exercise native rendering separately from live
warning reachability. No live overheat sequence is claimed by these fixtures.

## Reproduction

```sh
.runtime/pc-analysis-venv/bin/python tools/pc_gauge_oracle.py \
  --capture artifacts/pc-source-boot-01/mission-entry/conventional.bin \
  --output artifacts/pc-gauges-source-NEW/oracle.json
./tools/godot.sh --headless --quit-after 1200 \
  --script res://tests/test_pc_gauges.gd -- \
  --oracle ../artifacts/pc-gauges-source-NEW/oracle.json
python3 tools/capture_pc_render_trace.py --mode trace --profile gauges \
  --capture-ui --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-gauges-live-trace-NEW
python3 tools/capture_pc_render_trace.py --mode baseline --profile gauges \
  --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-gauges-live-baseline-NEW
./tools/godot.sh --rendering-method gl_compatibility --quit-after 1200 \
  --script res://tests/test_pc_gauges.gd -- --native \
  --fixture ../artifacts/pc-gauges-live-trace-NEW/report.json \
  --output ../artifacts/pc-gauges-live-native-NEW
```

The source snapshots are isolated reproduction fixtures. They do not prove
campaign/filesystem persistence, historical speed, full mission outcomes or
whole-game parity. No emulator/core or original reference bytes changed here.

## Native and replay evidence

* `pc-gauges-live-trace-01` / `pc-gauges-live-baseline-01` and
  `pc-gauges-live-parity-01.json`: 1,608 original frames with identical full-RAM,
  video and inputs, identical stage states, and nine passed visibility/parity
  checks. This exercises forward movement, coasting, braking, reverse and station
  changes. Fuel stayed at 100 and live temperature stayed green in this route.
* `pc-gauges-live-source-readings-01.json`: an independent source-image count
  confirms zero, 18, 19 and 24 active speed strips. At the forward-key sample RAM
  already contains speed 40 while the image still has 18 strips, demonstrating
  the need for scanout-based binding rather than latest-RAM reconstruction.
* `pc-gauges-live-native-01/report.json`: 17 recorded frames at 4x and 6x,
  56,576,000 whole-image comparisons, 18,986 assertions, zero errors, exit 0.
  All five placements are exercised, plus native constructed warning colours,
  blink-off, wrong-palette rejection and fallback clearing.
* `pc-gauges-native-01/report.json`: earlier 21-frame station/status fixture at
  both scales, including status-page removal of the cockpit gauges, exit 0.
* Optional Impeccable is unavailable; no linter dependency was installed. Actual
  Godot Compatibility renders, geometry bounds and source-colour tests cover
  this visual change.

All artifact names above are below `artifacts/`. Original battlefield pixels
are deliberately retained in the native gauge fixtures to isolate this change;
these images do not represent completion of world graphics.

### Launcher failure and bounded observer repair

`pc-gauges-play-01` failed the existing 30-second bridge response timeout. This
was a genuine failed launcher check. `pc-gauges-host-diagnostic-01/receipt.json`
then measured a valid 300-frame request at 53.029 seconds, without a Godot renderer.
`pc-gauges-host-profile-01/profile.txt` attributed most time to the per-pixel
UI/driver/plate provenance predicates in `Collector.observe_video`.

The four slow predicates now use C-backed byte counts, byte maxima and byte-lane
bit operations. The predicates, dimensions, paired-slot checks, image encoding
and original callbacks remain intact. Each possible ownership byte is tested;
65,536 plate/ownership combinations and 262,144 driver field combinations are
compared directly with the old expressions, along with mixed 64000-pixel buffers
and corruptions at the first, last and row-boundary pixels. This repair neither
loosens the watchdog nor skips original simulation or validation work. It was
included because the measured defect blocked actual launcher verification.


`pc-gauges-observer-equivalence-01.json` confirms that all 22 fields of the
fresh 1,608-frame presentation report and all 51 saved source/UI/plate PNGs
are identical before and after the guard optimization. The prior baseline
parity proof therefore still applies without a weaker mask or skipped callback.
`pc-gauges-play-02` then completed through actual `Play.command`, exit 0,
with `gunner_speed` and `gunner_temperature` in the capture metadata and
visually inspected `tandem-frame.png`. The 30-second response timeout and
60-second snapshot-capture deadline were unchanged.


Final aggregate gate: `artifacts/validation-20260928T010215Z`, **229 Python tests
and all 30 stages pass, exit 0**. The preceding focused observer run passed
23 tests. Original reference inventory verification also passed after a negative
check confirmed the new oracle refuses output inside GAME or GENESIS.
