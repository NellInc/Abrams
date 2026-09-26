# Original PC camera and static drawing

The PC executable remains the sole simulation authority. This extension reads
its cached drawing state and reproduces its camera and static face selection in
Godot. It adds no gameplay visibility, collision or targeting decisions.

## Recovered contract

All data offsets below are relative to SIM's data segment.

* `116e`: current view index. The saved rectangle is in four arrays at `1a8b`,
  `1a9f`, `1ab3`, `1ac7`, indexed by twice the view index. These are inclusive
  left/right/top/bottom bounds. The shared raster clip at `3593..3599` is later
  overwritten by cockpit instruments and is unsuitable for the 3D camera.
* `8b52..8b56`: cached camera position; `117d`: nine signed Q14 matrix words;
  `12c1`: transform mode. Original `0b4d:1175` multiplies matrix columns, shifts
  each accumulated component right by 14 and wraps to a signed word.
* `1b2b/1b2d`: projection center; `12c2`: near plane; `12c6`: projection shift.
  The observed shift 7 gives a focal length of 128 source pixels.
* `8dd2`: draw-queue count; `6f58`: near-pointer queue. Allocation alone never
  establishes membership in this list or visibility through other objects.
* Object `+10` hex: signed projected size. `0b4d:2867` selects the first shape
  root whose signed threshold is at most this size, with a final-root fallback.
* `0b4d:0541/1cf3`: a static primitive's first prefix byte selects its normal;
  `ff` bypasses rejection. Otherwise a second prefix byte of `ff` rejects the
  face. The signed 32-bit dot product of the normal and first translated vertex
  must be negative. Vertex and normal decoding use the original high-bit rule.

The driver temporarily zeros relative turret yaw during drawing. The commander
can temporarily add a view offset. The cached matrix includes these effects;
raw hull/turret fields alone would produce the wrong crew view.

Godot uses an asymmetric frustum with the original center, focal length, near
plane and rectangle. Source pixel proportions (320 by 200 displayed at 4:3)
are applied outside the 3D viewport. Four-times resolution changes presentation
sampling only. The 1:64 scene scale is still an inspection convention, with no
claim about physical units. API reference:
[Camera3D](https://docs.godotengine.org/en/latest/classes/class_camera3d.html).

## Independent checks

`tools/pc_camera_oracle.py` executes unmodified original instructions in isolated
copies of captured RAM. Its draw callback must use the original SS=DS convention:
the normal-dot helper addresses stack temporaries through DS. Nothing from the
oracle is written into the live PC game.

Canonical receipt: `artifacts/pc-camera-oracle-05.json`, successful terminal exit.

* Nine captured crew-view cases plus two explicitly synthetic pitch/roll cases.
* 1,133 original matrix/vector comparisons.
* 598 original signed integer perspective projections.
* 151 original static-object root and face comparisons.
* 508 detail-root threshold cases across static shape records.

`artifacts/pc-camera-godot-03.log` checks 233 projected points against the
original-derived fixture, maximum error 0.063590 source pixels. This checks
camera geometry before integer raster rounding; it is not raster equivalence.

`artifacts/pc-camera-live-godot-02.log` records protocol-2 process-pipe integration,
camera/static masks, original movement, stations, braking, turret, firing and
graceful helper exit. `artifacts/pc-camera-replay-01/report.json` retains two
identical 978-sample original runs. Their RAM/video/input samples also match the
pre-camera baseline (`pc-camera-baseline-comparison.json`).

The full local gate `artifacts/validation-20260926T232721Z/results.txt` passed all
ten stages, including 87 Python tests, 11 world-view checks and 12 synthetic
camera checks. The later protocol-2 integration was checked separately above.
Native `artifacts/pc-camera-viewer-02.log` exited successfully after capturing
`artifacts/pc-bridge-viewer/paired-view.png`; the same author inspected the image.

## Retained mistakes and limits

The first capture metadata and `pc-camera-oracle-01.json` used the overwritten
UI clip. They are superseded by oracle 02 onward, which re-decodes the unchanged
RAM. Two old capture filenames say `driver-moving` and `driver-stopped`, but both
captured speed zero: they establish input/view probes only. The capture script
now calls these `driver-forward-input` and `driver-stop-input`.

The first native camera-viewer attempt exited 1 without recording the cause.
After adding phase/failure logging, the next attempt passed. No specific cause
or repair is claimed for that unexplained first failure.

The VGA boundary is demonstrably capable of catching an intermediate state.
Replay sample 464 (`control`, neutral input) contains player local position
`[2048,510,50]` and cached camera `[2048,410,40]`. Adjacent samples agree again;
the player's 100-unit displacement is transient. The exact instruction boundary
and cause remain unverified. Rendering uses the cached original camera, and
neither this decoder nor a passing replay proves atomic logic-tick sampling.

Dynamic geometry, solid occlusion, material/dither interpretation, opaque/sprite
commands, historical timing, complete combat and campaign parity remain open.
The diagnostic view stays separate from the main authored calibration range.

Working if: original-instruction comparisons and Godot projection checks pass,
only original draw-queue static faces appear in the diagnostic view, and no
renderer-derived decision changes the original simulation.

## Reproduction

```sh
.runtime/pc-analysis-venv/bin/python tools/pc_camera_oracle.py \
  --captures artifacts/pc-camera-captures-01 --output artifacts/pc-camera-oracle-NEW.json
./tools/godot.sh --headless --script res://tests/test_pc_camera.gd -- \
  --fixture "$PWD/artifacts/pc-camera-oracle-NEW.json"
ABRAMS_PYTHON=$(command -v python3) ./tools/godot.sh --headless \
  --script res://tests/test_pc_live_bridge.gd
./PC\ Bridge.command --capture
```
