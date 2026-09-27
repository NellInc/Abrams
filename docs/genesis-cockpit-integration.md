# Genesis-first cockpit integration

## Authority and deliverables

Nell explicitly selected Genesis graphics wherever available, with the PC
executable definitive for gameplay. This supersedes the previous PC-first
material-donor study. No emulator, executable, gameplay rule or input sequence
was changed for this presentation revision.

The five generated images in `local-art/genesis/cockpit-v2/` use only extracted
Genesis images as visual references. Each is **1586x992**, measured after
generation. They are high-resolution interpretations, not 4K images or exact
asset decodes. Untouched native sources, exact prompts, hashes and measured
dimensions are retained alongside them. The built-in image generator received
only the selected graphics, never a ROM, executable or workspace archive.

| Source | Selected image | Runtime binding |
|---|---|---|
| Genesis gunner | `gunner-genesis-v1.png` | PC GPS plate, nine static instrument cells |
| Genesis commander | `commander-genesis-v1.png` | PC TC plate outside map and live instruments |
| Genesis cupola | `cupola-genesis-v1.png` | PC AA plate with original visibility |
| Genesis driver | `driver-genesis-v1.png` | PC DRIVER plate and observed moving roof assembly |
| Genesis CHECK DAMAGE | `systems-status-genesis-v1.png` | PC STATUS plate, pristine schematic only |

The runtime checks every generated image against a pinned hash and dimension
before selecting the complete set. Missing or changed assets retain the original
presentation. `Play.command` now selects this tandem by default; the previous
authored range has its own `Calibration Range.command`. Importing the Godot
project still opens the range. `--gunner-art` explicitly selects the older
PC-first research pilot, never the new default.

## Layout, values and damage

Generated pictures supply materials and illustrations; their painted openings
do not define camera visibility. Piecewise renderer registration fits their
components to the PC camera, instrument and original UI-provenance coordinates.
The driver's original per-pixel horizontal roof offsets are reused unchanged.
No image-derived approximation controls the viewport or moving assembly.

`pc_instrument_art.gd` checks every pixel, source-plate ID and UI-ownership bit
in each of nine gunner cells before replacing it: three ammunition icons, coax,
smoke, temperature label, display, target and the speed-scale legend. A single
overwrite rejects the whole affected cell. The PC GPS image is used for this
verification only, not as the new illustration's visual reference. Ammunition
counts, temperature state, speed bars and orientation diagram remain live.

Twenty-two fixed label candidates pass the same exact original-font and visible
pixel checks as the existing observed text. Completed observed text has priority
over an overlapping fixed-label candidate. STATUS adds six three-cell numeric
wells through exact original-glyph matching, including leading spaces. This is
neither OCR nor a read of hidden current RAM values. The full original foreground,
background, source-font hash and UI ownership still have to match before redraw.

The STATUS schematic uses its high-resolution donor only while every pixel in
the complete original schematic retains pristine plate provenance. An overwrite
anywhere preserves the **entire original schematic**, including unchanged
surrounding pixels. Twelve lamps and their wells also remain source-driven.
This conservative fallback has synthetic native overwrite coverage; a complete
set of real damaged-diagram variants is still required for remastering them.

Working if: original values and changed damage information remain visible, and
unknown or overwritten regions fall back to the actual current PC pixels.

## Rendering repairs and retained failures

Initial native captures exposed duplicated gauges and displaced driver framing.
Component-specific donor registration corrected them. The old captures remain
under `pc-genesis-gunner-viewer-01` and `pc-genesis-driver-viewer-01`.

A ninth custom sampler rendered STATUS white on the tested Compatibility
renderer even though its CPU texture and shader binding were present. Reusing
an existing sampler rendered the same image correctly. The final implementation
uses a lossless two-row commander/status atlas, including mixed transition
frames. This is an observed workaround, not proof of the underlying driver cause.
The diagnostic is retained as `artifacts/pc-status-texture-probe.gd` and its PNGs.
Three native donor probes now fail if STATUS artwork is absent or misplaced;
protected-pixel tests alone would have missed this visual fault.

The native-07 invocation used a nonexistent fixture. Godot emitted a script
error but the earlier test reported zero failed checks. That gate was broken.
The test now explicitly rejects missing paths/unsupported fixture structures,
requires native arguments, and records the fixture path and hash in its report.
`pc-genesis-invalid-fixture.log` confirms exit 1 for the missing-file case.
Native-07 is a failed run despite its process's historical exit 0.

## Evidence

* `artifacts/pc-genesis-cockpits-native-08/report.json`: 21 original recorded
  station/status frames, actual material changes, all five plate IDs, all nine
  eligible instrument cells, twelve system labels and six stores values.
  **11,944,300 checks, zero errors, exit 0**, including whole-schematic fallback
  after one synthetic damage overwrite. Native Godot, 1280x800 output.
* `artifacts/pc-genesis-driver-native-01/report.json`: 19 recorded driving and
  station samples, including moving-assembly offsets; **10,537,279 checks,
  zero errors**. The completion report and process disappearance were observed,
  but the original shell session handle was lost during output truncation;
  do not claim a separately recovered terminal exit code for that run.
* `artifacts/pc-genesis-legacy-regression-01.log`: unchanged legacy shader branch
  and synthetic roof offsets -37, 0, +51; **4,096,017 checks, zero failures,
  exit 0**.
* `artifacts/pc-genesis-boot-viewer-01/`: actual original cold boot through the
  live Godot bridge; new gunner art, nine illustration cells and thirteen text
  runs visible. Completion receipt and image inspected; its shell handle was
  likewise lost, so no separate terminal-exit claim is made.
* `artifacts/pc-genesis-play-boot-01/`: follow-up through the changed public
  `Play.command` launcher, actual cold boot, new gunner art and thirteen text
  runs; capture inspected and **terminal exit 0** recorded in its sibling log.
* `artifacts/pc-genesis-art-shared-state-comparison-02.json`: identical original
  program, decoded state, complete presentation metadata, source framebuffer
  and Godot world image versus `pc-live-type-gunner-viewer-01`; the composite
  changes. The first comparison mistakenly used a driver route and is retained
  as a failed comparison, not a parity pass.

The implementing assistant also reviewed the native images. This is self-review,
not independent art acceptance. Full mission/timing parity and all graphics are
still open. The latest aggregate gate is recorded in `WORK_LEDGER.md`.

Reproduce the current native material/damage check:

```sh
./tools/godot.sh --disable-render-loop \
  --script res://tests/test_pc_genesis_cockpits.gd -- --native --text \
  --fixture "$PWD/artifacts/pc-live-type-cockpit-02/report.json" \
  --output "$PWD/artifacts/pc-genesis-cockpits-new"
```

All generated/reference graphics remain ignored local files and are excluded
from normal source-only exports. No publication or redistribution is authorized.
