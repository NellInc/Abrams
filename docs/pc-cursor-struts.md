# Cursor and moving cockpit struts

The source cursor remains authoritative for position and visibility. Its pinned
16 by 15 descriptor, all 79 opaque indices and their current palette colours
must match the original frame before the vector arrow is drawn. The original
mask still protects typography. Straight contours replace the bitmap stair
steps, and the outer contour plus stroke covers the original ink allocation.
Malformed receipts or changed pixels leave the original frame untouched.

The seven STRUTS.BMP entries keep their original blitter geometry and timing.
The existing plate matcher handles the static placements. Two remaining routes
need specific custody:

* Index 3 is drawn at (240,128) by SIM's lower driver assembly. Existing native
  driver ownership supplies its displacement and material. Four captured driver
  poses preserve 595 source strut pixels; a later DRIVER.BIN draw overwrites the
  remaining 79 pixels. Both groups sample the reviewed Genesis driver surround.
* Index 5 is drawn at (159,110), so seven columns extend beyond the screen. Only
  that exact 168 by 7 source placement and return address SIM:0D92 can use the
  clip-aware matcher. All visible opaque source pixels must uniquely match
  AA.BIN, then match the completed original blit. Its 457 visible pixels sample
  the reviewed Genesis cupola surround. Transparency and the original clip
  rectangle remain authoritative. Other offscreen layouts still fail closed.

## Reproducible checks

With the separately owned originals and existing analysis dependencies:

```sh
python -m unittest tests.test_pc_strut_trace tests.test_pc_strut_completion
python -m tools.pc_strut_oracle --capture artifacts/pc-driver-assembly-trace-02/first-render.bin --output artifacts/finish-20260928/cursor-struts/source-oracle.json
python -m tools.verify_pc_strut_coverage
sh tools/godot.sh --headless --script res://tests/test_pc_cursor_struts.gd
sh tools/godot.sh --script res://tests/test_pc_cursor_struts.gd -- --native
```

The oracle executes unchanged original instructions for all seven entries under
full and restricted clipping. The native check renders an actual menu capture,
four historical driver poses and an explicitly synthetic cupola source fixture.
It compares every output subpixel in the audited strut regions with the actual
high-resolution donor, and checks unchanged transparent/offscreen neighbours.
Working if: malformed or ambiguous ownership is rejected, no cursor ink square
escapes the authored contour, and audited surviving struts sample the donor.

This is bounded source and presentation evidence. The cupola fixture is not a
new ordinary-play capture; these checks do not retroactively clear historical
unmapped-draw counters or prove every possible gameplay path.
