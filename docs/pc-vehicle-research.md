# Original vehicle drawing and emulator observation

## Integer arithmetic recovered

`tools/pc_vehicle_math.py` is a presentation-research library. Its outputs are
compared with unmodified original instructions by `tools/pc_vehicle_oracle.py`.
It is not a replacement vehicle simulation or a live renderer yet.

`artifacts/pc-vehicle-oracle-01.json` and its successful terminal log establish:

* 2,280 original object-orientation matrices, including all 256 values on each
  axis, boundary combinations and deterministic mixed-axis inputs.
* 5,985 distinct packed-rotation coefficients, checking 915,705 lookup words.
* 1,920 matrix compositions covering every original mode pairing and five
  explicitly supplied incoming CX values.

The original mode priority is first angle nonzero -> 3, second nonzero -> 2,
third nonzero -> 1, otherwise 0. This differs from assigning generic engine Euler
rotations. The helper uses the original sine/cosine tables read from local RAM.
Packed vectors use staged shifts, additions and symmetric negation, rather than
one floating-point matrix multiplication.

## Register-dependent original quirk

In SIM `0b4d:0c6e`, yaw-specialized branches execute `MOV AX,CX` after the first
multiply, while the general branch executes `MOV CX,AX`. The specialized branches
therefore retain an incoming-register contribution in the low word of their dot
product. The running original has these same bytes; this is not a disassembler
transcription error. The observer must preserve it rather than substitute the
mathematically conventional result.

The receipt's witness uses identical original matrices for angle triples
`[0,0,30]` and `[0,0,47]`. Incoming CX=0 and CX=65535 produce different matrices.
This executes the original routine with explicit synthetic register inputs; it
is not a claim that either value occurred in the live mission. The current VGA
snapshot protocol contains RAM, not the required CPU register at that call.

Working if: the original-CPU arithmetic oracle passes and no live integration
silently assumes CX=0 or replaces this branch with ordinary matrix arithmetic.

## Source-built observation backend

A local source dependency has been built from
[DOSBox Pure revision 73e03aa](https://github.com/schellingb/dosbox-pure/tree/73e03aa145e0549ed4d5a20f8e65532714da33f5).
The upstream LICENSE and notices remain in `.runtime/dosbox-pure-source`.
`tools/build_pc_trace_core.py` pins that revision, preserves the unmodified
baseline library and adds a read-only callback to the normal CPU instruction
loop. The callback copies registers and bounded conventional-memory regions at
original render-begin, object-ready, primitive, matrix-composition, polygon and
render-end locations. It changes no guest bytes, instructions or cycle counters.
Actual noninterference still requires baseline comparisons; source inspection
alone does not prove it.

The generated `.runtime/pc-core/abrams-trace.json` records source/header/compiler
and binary fingerprints. The default bridge continues to require its original
nightly binary pin. Research variants require an explicit alternative binary
hash. Cross-build state restores also require an explicit source-receipt pin,
and still undergo the core's own format checks.

Both source-built variants rejected the old nightly save state with `Load State
Error: Invalid file format`. These failed runs are retained in
`artifacts/pc-render-baseline-01.log` and `pc-render-trace-01.log`. The exact layout
difference has not been diagnosed. No state-format guard was removed or bypassed.
A fresh source-build boot resolved this local research dependency without
changing the old state. `tools/bootstrap_pc_source.py` replays the observed 3,600
keyboard-input frames, enters the original Mossel scenario and checks its station,
position and ammunition. `artifacts/pc-source-bootstrap-02.log` completed with
exit zero. The earlier interactive source state remains in
`artifacts/pc-source-boot-01/mission-entry` and is the input to the hook tests
below. The nightly reference and default Godot bridge remain intact.

No binary, proprietary state or graphics were added to a distributable package.
The backend remains local research, separate from the working default bridge.

## Actual original instruction-hook evidence

`artifacts/pc-render-baseline-02/report.json` and `pc-render-trace-03/report.json`
run the same source-build state and 180 input frames on the unmodified and traced
libraries. `pc-render-hook-comparison-03.json` compares every RAM/framebuffer hash
and input set: **zero mismatches**. This is bounded source-build noninterference,
not equivalence to the old nightly library or a historical PC.

The traced run contains 45 complete original rendering passes and 66 dynamic
object contexts. All 5,341 checked source vertex calculations exactly match the
original renderer's live vertex caches. Original matrix composition also matches
for each observed dynamic context. Incoming CX was zero in these captures; the
independent synthetic witness above establishes why that cannot be assumed for
all possible game states. The observer now reads it at the actual call site.

Godot's `pc_draw_pass.gd` replays the captured camera-space geometry, including
vehicles. `artifacts/pc-draw-pass-godot-03.log` checks 5,243 projections across all
45 passes: maximum error **0.000062 source pixels** against fractional projection
of the original cached vertices. Eighteen dynamic polygons occur in the last
pass. This is a recorded-pass research renderer, separate from the live default
bridge; it does not claim filled-surface, material or original integer-raster
parity. Near/viewport clipping and opaque draw commands need their own checks.

The first Godot check failed because its root viewport retained the application's
1600 by 900 content scaling. The diagnostic log recorded the mismatched viewport.
A dedicated SubViewport corrected that harness error; the failed and diagnostic
logs remain alongside the successful check. No tolerance was widened.

Working if: source baseline and traced runs retain identical RAM/video hashes,
the checked live vertex caches match reconstructed vertices, and Godot projection
checks use the actual original camera frustum without applying its rotation twice.

## Reproduction

The initial baseline was built with `make -j4` in the clean pinned upstream
checkout, then copied to `.runtime/pc-core/source-baseline.dylib`. Subsequent
tracing builds use `python3 tools/build_pc_trace_core.py`. The script refuses
unrecognized dependency edits; neither binary is the default live bridge core.
The manifest records the compiler and hashes, but cross-machine byte-for-byte
build reproducibility is not yet established.

```sh
.runtime/pc-analysis-venv/bin/python tools/pc_vehicle_oracle.py \
  --capture artifacts/pc-camera-captures-01/gunner-forward.bin \
  --output artifacts/pc-vehicle-oracle-NEW.json
python3 tools/bootstrap_pc_source.py --output artifacts/pc-source-bootstrap-NEW
python3 tools/capture_pc_render_trace.py --mode baseline --frames 180 \
  --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --state-core-sha256 57edbd309eb2ab6264b70188c3a85408fbcfa8c62e83b8c7b9c39b7309f61ac6 \
  --output artifacts/pc-render-baseline-NEW
# Repeat with --mode trace and --output artifacts/pc-render-trace-NEW.
python3 - <<'CHECK'
import json
from pathlib import Path
baseline = json.loads(Path('artifacts/pc-render-baseline-NEW/report.json').read_text())
traced = json.loads(Path('artifacts/pc-render-trace-NEW/report.json').read_text())
assert baseline['source_commit'] == traced['source_commit']
assert baseline['frames'] and baseline['frames'] == traced['frames']
print('Every input set and full-RAM/framebuffer hash matches')
CHECK
./tools/godot.sh --headless --script res://tests/test_pc_draw_pass.gd -- \
  --fixture "$PWD/artifacts/pc-render-trace-03/report.json"
```

The source-built trace backend must next be integrated into the live Godot view
with an explicit render-pass/framebuffer alignment contract. Solid surfaces,
materials, opaque/sprite commands, high-resolution vehicle replacements and all
original-game parity outcomes remain required. This milestone does not close
any mission, campaign or release outcome.

## Final local gate for this pass

`artifacts/validation-20260927T000739Z/results.txt` passed all eleven stages,
including 95 Python tests, source preservation and the Godot draw-pass checks.
The unchanged default live bridge also passed after the core-pin API extension
(`artifacts/pc-core-pin-godot-01.log`). Native draw replay and capture completed
with exit zero (`pc-draw-pass-native-01.log`, `pc-draw-pass-native-01.png`). This
native image was inspected by the same root author who implemented the replay.
It is an intentionally unfilled research view, with the distant original actors
at their original projected sizes. No high-resolution vehicle artwork is claimed.

A final metadata/classification adjustment distinguishes dynamic allocation from
the zero-angle static-transform shortcut. Its focused Godot classification check
and repeated traced capture/projection passed; the repeated 180-frame trace still
matches the unmodified source baseline. Captured camera metadata now identifies
the actual drawing callback boundary, rather than labelling it a VGA snapshot.
