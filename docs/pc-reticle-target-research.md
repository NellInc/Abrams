# Original target-selection box

The Upscaled target box now shares the existing gunner sight's resolution-
independent, square-ended analytic strokes. Original PC drawing supplies its
selection, projected centre, clipping, colour and visible timing. The box adds
no targeting data, marker, lock status or aiming calculation. The Genesis gunner
capture supplies the square-ended sight style; its captured view has no selected
target, so a Genesis selected-box comparison remains outstanding.

Working if: only current, source-owned target ink is replaced; original integer-
scale output is identical; fractional changes match analytic rectangle coverage;
missing, overwritten or stale evidence leaves the current PC image untouched.

## Source and binding

Authority is unchanged `GAME/SIM.EXE`, SHA256
`9ee5a5898ddcb8192d30b4083981419515eb3ca220e6cbcd214df628bb164099`.

* `66a9` begins each original gunner selection draw and invalidates the prior
  candidate for that page, including when selection is absent.
* Original projection `309c` supplies stack coordinates. Calls `66db`, `66f9`,
  `6717`, `6735` draw the four sides at centre plus/minus five. The observer
  copies the four actual call arguments, not a substitute projection formula.
* Readback occurs at `6760`, after the entire original gunner draw. Host EGA
  backing planes are read without guest VGA latch reads or guest writes.
* The complete sight rectangle (32,13,256,97) must survive scanout byte-for-byte
  in the actual displayed RGB frame. The candidate belongs to the original
  scanned page and presented triple-buffer slot.
* Godot independently checks the source hash, integral coordinates, four exact
  lines, page, clip, palette, full crop hash and UI ownership/colour of every
  original ink pixel. Each frame clears old geometry before checking new data.

The four-line axis rasterizer keeps the source's endpoint conventions, including
clipping-induced vertical endpoint swaps. Antialias coverage stays inside the
original owned source cells. At some fractional alignments every eligible pixel
already has full coverage; these cases correctly show no visual change.

## Evidence

Receipts are under `artifacts/finish-20260928/`:

* `target-oracle.json`: 722 unchanged original target-draw fragment and line-
  rasterizer cases, both colours/pages and all clip edges/corners, 231 checked
  instruction locations, 189,267,968 full-plane byte comparisons. Inputs are
  isolated projected-coordinate fixtures, not claims of live reachability.
* `target-live-trace-02/report.json` and `target-live-parity.json`: 1,227 frames
  with identical full conventional RAM, video, inputs and stage states compared
  with the source baseline. 143 completed target draws produce 619 fully matched
  presented candidates; 125 mismatched presentations keep original content.
* `target-live-visibility.json`: both original colours, right-edge clipping,
  centre movement, selection, lock, zoom, thermal and station return are observed;
  every saved target crop hash matches. No target is exposed in commander or
  unselected gunner samples.
* `target-unit.log`: 38 Python tests pass across target, existing reticle and
  collector contracts. `target-headless.log`: 745 Godot checks pass, including
  all original CPU geometry fixtures and corrupt/missing evidence rejection.

* `target-native-02/report.json`: 899 checks, zero errors; 51,942,400 full-frame
  pixel comparisons across 30 renders at 1280x800, 1728x1080 and 1920x1200.
  Six actual source states and four isolated clipped positions retain exact
  integer-scale output and analytic fractional coverage confined to original ink.
  The author inspected the rendered output from this session; this is self-review,
  with independent visual acceptance outstanding.

The first target trace is retained. Readback at `674c` preceded remaining gunner
cosmetics, so every whole-sight comparison rejected it. Moving readback to the
verified routine return corrected timing without weakening the full-crop gate.
The first native test also retained a false assertion that every fractional
alignment must visibly change. Its analytic-coverage and outside-ink checks
passed; the corrected test requires fractional refinement across the suite and
retains exact per-pixel coverage and integer-scale parity for every sample.

This work leaves remaining warning symbols, damaged schematics and Genesis
selected-target comparison explicitly open. It does not remaster original flat
vehicle models or textures and does not claim whole-game timing equivalence.
