# Hull/turret orientation display

## Source and visual treatment

The gunner and commander now receive resolution-independent orientation
geometry in the tandem renderer. The extracted Genesis displays are the visual
references: black field, green moving grid, nested rectangular hull/turret/gun
outlines, and the original component-colour vocabulary. The original PC drawing
routine supplies position, geometry, colours, fill mode and visible timing.
No new labels, numeric precision, interpolation or gameplay state are added.
The existing verified heading text remains outside this replacement rectangle.

Inspected source images:

* `local-art/genesis/source/gunner-original.png`, SHA256
  `7bfad2d4bae51ab9a59a7e93ddbcaffcaeec35b19ddbc4c96e135dd54319f5b3`.
* `local-art/genesis/source/commander-original.png`, SHA256
  `74cf4eed090be8b2f25fc8b3bbf1a7bdfb7198ad61d932a5a909aac825b3a22f`.

This pass was authored and visually reviewed within the same Codex session.
Native images were compared with these extracts. Nell's aesthetic acceptance
is separate. In particular, this is no claim that all cockpit trims, reticles,
system schematics, maps, bearing lettering or world graphics are finished.

## Original instructions and integer geometry

Authority: unchanged `GAME/SIM.EXE`, SHA256
`9ee5a5898ddcb8192d30b4083981419515eb3ca220e6cbcd214df628bb164099`.
Code addresses below are relative to its main load segment; data addresses
are relative to original DS, load segment plus `19e0`.

* `600c..62a6` selects gunner station 0 or commander station 1. Other stations
  return. The rectangles are `(128,137,62,44)` and `(216,83,62,44)` respectively.
* `6040` calls the black clear and grid routine `55e6`. Position words at
  body pointer `799b`, offsets 4 and 6, select the grid's 16-pixel phase.
  Calls `567f`, `56a5`, `56dd` produce vertical/horizontal lines in source
  order. Vertical calls exclude their final y endpoint (`box.end.y`);
  horizontal calls light their final column `x=left+61`, as every
  `pc-orientation-cpu-01` oracle case shows.
* Four calls return at `6135`, `615e`, `6214`, `62a3`. Function `5da8`
  prepares four signed integer points at `6486/648e` and six signed Q14
  basis values at `6496`. Far call `5f81` draws the polygon.
* Hull angle is body byte `1a` plus 64 modulo 256. Turret angle additionally
  includes turret pointer `7999`, byte `0b`. The original overlapping 256-entry
  sine/cosine tables occupy 640 bytes at `1d9c`, pinned by SHA256
  `ded7bcfa752de6745823d08d80aeab33fdbb77a7d9fda2ddc8f86bb99d437c9e`.
* Hull half-length/width are 16/10, turret 8/6. The first hull is displaced by
  one eighth of its longitudinal vector. The gun uses the turret's longitudinal
  vector, a quarter-width transverse vector, and a longitudinal displacement
  of one plus one eighth. Arithmetic right shifts preserve source rounding.
* Original X adds a floored Q14 displacement; original Y subtracts a floored
  displacement. Treating both axes as floor(final coordinate) is incorrect.
  Godot draws the unrounded source Q14 vertices at high resolution, without
  interpolating between source angles or introducing a new angle calculation.
* Original `359c=0` is outline-only; nonzero is the fill path. The supported
  values are 0 and 1. Interior `359d` is black, not white. White/gray outlines
  vary with word `8d68`. Component byte `c9d` selects normal/yellow/red gun
  borders. Its physical interpretation beyond source component status is not
  asserted here. Four turret-edge colours come from `cb8,cb9,cb7,cb6`, observed
  at `5fa5,5fc3,5fe1,5fff`, and are suppressed by the alternate theme.

## Visibility and no-write boundary

The native hooks emit only snapshots and draw observations: event 33 at `6040`,
34 at `5f81`, 36 at the seven line calls, and 35 at `62a6`. Readback accesses
host `vga.mem.linear` directly, preserving guest VGA latches. No original
instruction, cycle count, register, game memory or gameplay input is changed.

`OrientationRuns` compares the actual calls with an independent fixed-point
geometry model, expected caller order, fill flags, grid and edge colours. It
retains at most the latest completed candidate for each of two video pages.
Beginning a new draw invalidates that page's prior candidate. Scanout retains
an immutable completed candidate, so later draws cannot mutate the observation
attached to a triple-buffer slot. The entire 62x44 RGB rectangle must match
the presented original framebuffer before metadata is published.

The Godot layer additionally requires the supported palette, source identity,
valid geometry, full UI ownership, zero plate tags inside the drawn rectangle,
and exact surviving source plate pixels/tags around it. It independently hashes
the whole RGB crop. Unsupported, incomplete, corrupt or overwritten content
retains original pixels. A restored state without observed plate provenance
also stays original until the PC redraws the plate.

A clipped child Control confines every changed pixel to the proven rectangle.
Geometry scales to the destination, while antialiasing stays at display-pixel
resolution. This avoids the soft halo produced by scaling Godot's antialiasing
fringe with source coordinates. No glow or extra symbols are added.

## Evidence and limitations

* `artifacts/pc-orientation-cpu-01/oracle-integrated.json`: 1,024 cases,
  1,626 original instruction locations, 1,160,858 VGA writes. Every newly
  executed instruction location is compared with the fingerprinted, unpacked,
  relocated source. Both stations/themes/pages, all 256 hull angles and all
  256 absolute turret angles, 16 relative angles, outline/fill modes, three
  gun-border states and varied edge colours pass. The runtime observer accepts
  all 1,024 cases. This is not an exhaustive angle/state Cartesian product.
* The isolated CPU oracle uses Unicorn 2.1.4 and a bounded VGA mode-2 observer.
  It checks independent geometry, line calls, flags, colours and unchanged
  plane bytes outside the diagram. The saved raster bytes come from original
  CPU execution; no independently implemented polygon-fill equivalence or
  whole-game timing proof is claimed.
* `artifacts/pc-orientation-live-parity-02.json`: all checks pass over 1,113
  frames. Trace and uninstrumented baseline RAM, video, inputs and stage states
  are identical. All 225 native draws completed; 1,097 presented candidates
  matched. Eleven mismatched frames retained original content. Saved source
  crops independently match metadata hashes. Both stations, moving grid,
  moving hull and independent turret motion with a stationary hull are covered.
* The first replay used cursor keys while still in hull-control mode. Its
  hashes matched, but it did not prove turret-relative motion. The corrected
  profile sends the original C control-mode key before the turret sequence.
* Native tests cover original CPU fixtures, malformed packets, changed pixels,
  lost ownership, JSON numeric transport, missing plate provenance, palette
  changes and fallback clearing. Full-frame enabled/disabled comparisons at
  1280x800 and 1920x1200 require all changes to stay inside the source rectangle.
  Damage and alternate-theme render examples use isolated original-CPU fixtures;
  they do not establish live damage-event reachability.
* `artifacts/pc-orientation-native-03/report.json`: 321,049 assertions, zero
  errors, 59,904,000 full-frame pixel comparisons. Thirty-two station/scale
  samples accept the new geometry; four initial restored-snapshot samples
  correctly retain original pixels until source plate provenance is observed.
  Eight isolated CPU warning/theme examples are also rendered. The final crisp
  edge treatment was inspected at native resolution.
* `artifacts/pc-orientation-play-02/capture.json` and
  `orientation-verification.json`: actual Play launcher completed with Genesis
  art, gunner gauges and the orientation replacement enabled. Its source crop
  matches the orientation hash and its native packet equals the presented
  observer packet. `tandem-frame.png` was visually inspected. Existing response
  and capture deadlines were retained; the owned launcher/host exited normally.
* Final aggregate: `artifacts/validation-20260928T014131Z`, `./tools/validate.sh`
  exits 0 with 234 Python tests and all 31 stages passing.
* The optional Impeccable executable is unavailable locally. No dependency was
  installed. Native rendering, pixel comparisons and the existing test gate
  provide the relevant validation here.

## Reproduction

From the repository root:

```sh
.runtime/pc-analysis-venv/bin/python tools/pc_orientation_oracle.py \
  --capture artifacts/pc-source-boot-01/mission-entry/conventional.bin \
  --output artifacts/pc-orientation-cpu-NEW/oracle.json
python3 tools/capture_pc_render_trace.py --mode trace --profile orientation \
  --capture-ui --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-orientation-live-trace-NEW
python3 tools/capture_pc_render_trace.py --mode baseline --profile orientation \
  --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-orientation-live-baseline-NEW
python3 tools/verify_pc_text_trace.py \
  --trace artifacts/pc-orientation-live-trace-NEW/report.json \
  --baseline artifacts/pc-orientation-live-baseline-NEW/report.json \
  --output artifacts/pc-orientation-live-parity-NEW.json
./tools/godot.sh --quit-after 2400 --script res://tests/test_pc_orientation.gd -- \
  --oracle "$PWD/artifacts/pc-orientation-cpu-NEW/oracle.json" --native \
  --fixture "$PWD/artifacts/pc-orientation-live-trace-NEW/report.json" \
  --output "$PWD/artifacts/pc-orientation-native-NEW"
./Play.command --trace --capture --capture-station gunner \
  --output "$PWD/artifacts/pc-orientation-play-NEW"
```

The tracing core must be rebuilt with `python3 tools/build_pc_trace_core.py`
after changing native hooks. That script preserves the pinned unmodified
baseline and atomically replaces the local tracing dylib.
