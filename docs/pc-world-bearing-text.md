# Original-style bearing text over scenery

## Presentation change

The tandem display now uses the existing polished 6x6-derived outline face for
`BEARING` and its three-digit value over the world view. Both extracted Genesis
cockpits show this same compact bearing strip. Original fixed cells, placement,
black/white choice and leading zeroes remain. No background panel or new value
is introduced. Spoken bearings are unchanged by this presentation-only work.

The PC function `5728..57a8` draws the word through far call `575f` (return
`5764`) at x128, and its formatted digits through `579d` (return `57a2`) at x173.
Callers supply y17 (`0c78..0c7f`) or y12 (`0d0c..0d13`). The function sets
transparent mode at DS:3592 and chooses foreground 0 or 1 from original state.
It obtains the displayed angle through the original `56ea` conversion and
`527c` three-character zero-padded formatter. The commander temporarily alters
the turret byte before drawing and restores it afterward. Consequently the
restored text uses the observed string, never a recalculation from latest RAM.
Source remains the fingerprinted `SIM.EXE` recorded in the orientation research.

## Why the earlier text path rejected it

The standard label renderer requires every cell pixel to be UI-owned and its
background to be uniform. Transparent bearing glyphs own only their ink. Sky,
terrain and scenery retain world ownership between and within those letters.
Painting a flat backing rectangle would discard that scenery; retaining the
original bitmap ink beneath new outlines would leave a double image.

The additional, narrowly scoped acceptance path requires:

1. An observed original bearing call, matching page, pinned original 6x6 font,
   supported source position, original transparent mode and black/white colour.
2. `BEARING` or exactly three decimal digits within the original numeric range.
   Synthetic testing covers 000..359; this is not a claim that every integer is
   produced by the original 256-angle conversion.
3. Every original glyph ink pixel UI-owned and matching the observed foreground.
   Every non-ink cell pixel must be world-owned. Another overlay or ownership
   conflict rejects the whole run.
4. A hash match for the entire source RGB cell rectangle, plus the same frame's
   valid paired camera enclosing the whole text run. Nonuniform backgrounds
   are checked by their complete RGB hash, without inventing a flat colour.
5. The selected original-style outline font available, visible contrast and
   non-overlapping accepted label cells.

Only accepted original ink pixels are removed from a **copy** of the compositor
UI mask. The same paired world texture fills those pixels, and the existing
label renderer draws the outline face transparently. Original provenance stays
unchanged for all cockpit, portrait, gauge and orientation checks. Every frame
resets label/removal state before accepting new content; fallback resets both.
No native hook, emulation instruction, input, game variable or audio event is
changed in this pass. The underlying original trace and parity evidence are
`pc-orientation-live-trace-02` and `pc-orientation-live-parity-02`.

Working if: polished bearing outlines track only the original visible digits,
scenery remains continuous through their counters, unrelated UI is untouched,
and any failed visibility/provenance check restores the original bitmap text.

## Validation scope

`godot/tests/test_pc_world_bearing.gd` constructs nonuniform source backgrounds,
black and white lettering, both source positions, all 360 decimal strings and
JSON transport. It rejects missing fields, wrong glyphs, changed source pixels,
wrong ownership, page/camera mismatches, unrelated callers, unsupported fonts,
missing outlines and unobserved text. It checks stale-mask and fallback clearing.

Native tests supply a deliberately different, high-frequency, high-resolution
world image beneath both synthetic and saved original text. An independent
outline-contour oracle checks every output pixel inside the bearing cells,
including the actual world colour behind every glyph counter. Full-frame
before/after comparisons reject changes outside accepted bearing rectangles.
Both 1280x800 and 1920x1200 are exercised. The actual Play launcher is a separate
integration check using the live world renderer.

Existing typography/cockpit native tests use source crops as a diagnostic world
texture. Their transparent-label oracle now samples that supplied world colour
per pixel, instead of assuming a flat label background. Such crops include
original bitmap ink, so those old fixture tests alone cannot prove its removal;
the new clean-world tests and actual launcher supply that evidence.

This work was authored and reviewed in the same Codex session. It does not
establish aesthetic acceptance by Nell, live white-bearing state reachability,
reticle restoration or complete-world rendering parity. Unsupported overlays
continue to retain original pixels. Optional Impeccable is unavailable locally;
no dependency was installed.

## Verified receipts

* `artifacts/pc-world-bearing-01/contracts.log`: 387 checks, zero errors.
* `artifacts/pc-world-bearing-native-01/report.json`: 374,947 assertions, zero
  errors, 66,560,000 full-frame pixel comparisons across 40 station/scale/colour
  samples. Native images were visually inspected, including nonuniform scenery
  through black lettering. The bright gradient is a diagnostic texture only.
* `artifacts/pc-world-bearing-01/cockpits.log`: the existing four-station/status
  native test with text enabled passes 12,237,884 checks. Captures are in
  `artifacts/pc-world-bearing-cockpits-01/`.
* `artifacts/pc-world-bearing-01/typography.log`: the existing native typography
  test passes 4,573,806 assertions and 2,176,000 pixel samples. Captures are in
  `artifacts/pc-world-bearing-type-01/`.
* `artifacts/pc-world-bearing-play-01/`: actual Play capture exits cleanly,
  rendering `BEARING 000` with the new transparent outlines, Genesis art,
  vector gauges and the orientation diagram active. Original source crops
  independently match both text-run hashes in `bearing-verification.json`.
  The final `tandem-frame.png` was visually inspected.
* Aggregate `./tools/validate.sh`: exit 0, 234 Python tests and all 32 stages
  pass, receipt `artifacts/validation-20260928T015742Z`.

## Reproduction

```sh
./tools/godot.sh --headless --quit-after 1200 \
  --script res://tests/test_pc_world_bearing.gd
./tools/godot.sh --quit-after 3000 \
  --script res://tests/test_pc_world_bearing.gd -- --native \
  --fixture "$PWD/artifacts/pc-orientation-live-trace-02/report.json" \
  --output "$PWD/artifacts/pc-world-bearing-native-NEW"
./Play.command --trace --capture --capture-station gunner \
  --output "$PWD/artifacts/pc-world-bearing-play-NEW"
./tools/validate.sh
```
