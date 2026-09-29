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
counts and the orientation diagram remain live. The subsequent
[source-driven gauge pass](pc-gauges-research.md) adds scalable speed/fuel strips
and temperature lamps, including the original displayed warning phases.

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

### Gunner composition correction, 2026-09-28

Nell rejected the assembled gunner screen for a horizontal tear and distorted
ammunition. Earlier protected-pixel checks passed while these visual defects
remained. The previous visual review was insufficient.

At PC row 123 the upper and lower frame used discontinuous horizontal donor
coordinates. The right console sampled a seven-pixel-high blank silver strip
instead of its actual surround. The corrected mapping joins the outer diagonals
at identical coordinates, transitions only the side metalwork, and retains the
right surround and screws. The central bevel now flares continuously into the
wider heading opening instead of switching horizontal anchors at row 184.

The eight icon cells previously compressed whole donor wells, including their
empty count areas. Tight illustration crops now fit uniformly with a one-source-
pixel inset. Textured silhouette polygons isolate the four coloured ammunition
illustrations from the generated well backgrounds; the original verified well
colours remain. Smoke, temperature, display and target symbols also retain their
aspect ratios. The existing donor PNG, source rectangles, original counts,
ownership guards and fallback rules are unchanged. No raster assets were edited.

The repaired native test checks independent donor probes at the joins and right
surround, tight crops, containment, centring and uniform icon sampling at both
1280x800 and 1920x1200. These tests supplement whole-frame visual inspection;
they do not establish artistic acceptance. The retained pre-repair Play capture
fails eight of the first eleven join/surround probes.

Current repair evidence and terminal results are in `WORK_LEDGER.md`.

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

## Gunner hardware and trim repair, 28 September 2026

Nell's later screenshot exposed oval fasteners, coarse grey aperture corners,
and doubled or broken lower display edges. The earlier seam check did not
cover those defects. This pass keeps the pinned Genesis-derived artwork and
changes its registration plus the code-native metalwork surrounding PC cells.

The six upper-shell fasteners now sample their measured donor centres with
output-aspect correction and a feathered return to the surrounding plate. The
Gunner donor uses linear filtering; the legacy material pilot explicitly
samples texel centres. Eight lower fasteners are drawn as concentric circles
in output pixels. The console margins use straight registered bevels and the
same grey, blue and green palette. The original instrument positions, live
counts, lamps, labels and ammunition illustrations remain source-owned.
Only the two-pixel static display rims receive the new trim, subject to their
original plate and UI ownership masks.

The four original aperture corners contain exactly 84 grey UI pixels. All 84
must match the current source colour and ownership before their high-resolution
lip is eligible. Its antialiasing can reuse the nearest already-visible world
colour; it never samples scenery concealed behind the original corners. Every
originally visible world pixel stays unchanged. Changing one corner pixel or
ownership bit disables the whole corner treatment. Missing source provenance,
other camera bounds, and EGA/Genesis modes clear the overlay immediately.

`test_pc_gunner_trim.gd` renders 1280x800, 1280x960 and 1920x1200. It measures
visible screw bounds, checks live-pixel preservation, plants a bright sentinel
in concealed scenery, renders whole-corner fallback after three corruption
kinds, and verifies byte-identical same-frame Upscaled restoration. The focused
native run passed 2,160,931 checks. The headless guard tests are included in
`tools/validate.sh`; private-package allowlisting includes both new code files.
Evidence is retained under `artifacts/cockpit-trim-20260928/`.

The implementing assistant performed the visual review. Failed development
renders remain in the evidence directory, including the shader type error
caught by world-pixel protection checks. Impeccable is not installed in this
native Godot project; native rendering and pixel/geometry checks are used.

Working if: the gunner sight has a smooth red rim, screws remain round in 4:3,
console edges are aligned, original live pixels and hidden-world boundaries
remain protected, and graphics switching never retains stale trim.


Final root checks passed: 12,051,382 native all-station checks; 4,096,050 legacy
material checks; and the full 62-stage validation, including 422 Python tests,
source preservation and the new trim guard test. Aggregate terminal receipt:
`artifacts/validation-20260928T174932Z/`. Two live launcher cold boots completed
at 1280x960. Their original framebuffer, world image, decoded state, program and
sample count are identical; the remastered composite differs. The independent
boots differ in `draw_pass.start_ram_sha256`, so full-RAM cross-boot identity is
not claimed. All other presentation metadata matches. The focused same-packet
mode-switch test provides exact renderer restoration evidence separately.

Final receipt: `artifacts/cockpit-trim-20260928/completion.json`. Local changes
only. No original game files were modified or included in Git; no push or new
private package was made.

## Commander hardware and cupola rail follow-up

The four lower commander-console fasteners now use circular output-space geometry,
including the 4:3 correction. The existing continuous heading surround is retained.
The cupola forward rail no longer mixes fragmented low-resolution stipple with its
Genesis donor. Its 457 source-owned, untagged rail pixels require an exact AA source
fingerprint, camera, UI mask, pixel comparison and adjacent plate context. A single
mismatch rejects the entire extension. Original world pixels and the PC's stepped
outer silhouette remain unchanged. EGA and Genesis modes retain their own paths.

Current native evidence is in `artifacts/next-pass-20260928/`. Root reviewed the
commander 1280x960 and cupola images; this is self-review of work integrated in this
session. The native route covers all five plates and negative source/ownership
cases. Performance-only changes replace the orientation guard loop with an exact
packed-byte predicate for supported formats and reuse this call's already validated
plate-mask image. Other formats retain the old loop; no previous-frame validity is
reused. The 1,024-case original CPU orientation oracle and format/mutation comparisons
remain required. No raster artwork or original game files changed in this follow-up.

## First-person refinement, 29 September 2026

The commander monitor now has straight registered bevels and six round fasteners.
Its speed scale and four miniature illustration wells use the high-resolution
Genesis-derived donors. Each well requires unchanged original RGB, UI ownership
and the correct plate tag. The two driver instrument-pod fasteners use small
scalable cross-heads under the same checks. Live numbers, bars, lamps, maps and
orientation remain independently source-selected.

Driver and cupola silhouettes receive a narrow antialiased contour pass in
Upscaled and Modern. The fitted outline stays within 0.98 source pixels of the
observed column profile; drawing is limited to a 1.65-pixel strip. The moving
roof retains the original signed horizontal donor offsets. Edge reconstruction
samples scenery only from already-visible original pixels. It never exposes
world texels behind the original cockpit. Mixed stations, partial plates and
unsupported cameras retain their previous presentation.

The gunner surround and STATUS layout retain their established artwork and
source-driven instruments. The refinement tests cover hidden-world sentinel
colours, per-cell rejection, both original graphics modes, transition clearing,
output-space round screws and geometry-cache reuse. Native transition checks
retain the protected-pixel oracle outside the explicitly tested contour strip.
