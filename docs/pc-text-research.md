# Original PC fonts and visible text

The tandem bridge supplies read-only `presentation.text_runs` metadata for
original labels. Every supplied run passes native glyph and presented-frame
checks. Eligible runs now use locally reconstructed TrueType outlines of the
four original faces after a second, independent Godot source-pixel check. The source letters
remain available with `--original-text`. The READY-specific loader voice gate
is described in `pc-audio-research.md`.

## Original-typeface fidelity, 2026-10-02

Revision 5 restores the actual lowercase construction of all four source faces.
Revision 4 regularised them too far: it replaced distinct `m`/`w` branches,
closed the light `e`, shortened the dialogue `r` hook, and changed stencil
islands and terminals. Direct source comparison confirmed Nell's observation.

Each lowercase starts from its original contour topology. Local staircase
chords are accepted only when every source ink and blank centre keeps its
classification, ink centres retain at least 0.4 source units of clearance, and
all original extents remain exact. This preserves the original asymmetric
serifs, shoulders, stem widths, split terminals, stencil gaps and descenders.
Unambiguous square features remain square. Approved v3 capitals, figures and
symbols are unchanged, including the earlier R and baseline corrections.
Original wording, colours, cells, source recognition and game logic are unchanged.

The selected pack is `local-art/pc-outline-fonts-v5/manifest.json`, SHA-256
`f5450780ff5161c57837fe758a5bc4d6fd90cbb3cb164d7b31fe464c10aac74d`.
The shared runtime loader and private packaging allowlist select it for dialogue,
briefings, menus and existing text overlays. Previous packs remain preserved.

Working if: every lowercase source-cell centre retains the exact original ink
classification, source extents and measured stem widths remain intact, actual
TTF pixels match the outline interiors at multiple scales, and existing fixed
advance, capital, symbol, alias and stencil-channel tests pass.

Evidence is under `artifacts/pc-font-cohesion-20261002/`. 21 focused font/text tests and 110 clean-source tests pass (seven skips). Both
new source-fidelity regressions reject the preserved v4 pack. The isolated
fidelity assessment and actual TTF/source comparisons are separate from native rendering.
The optional design detector does not cover Python or Godot. New native Godot
validation is pending a fresh shared-resource admission; v4 native passes cannot
establish acceptance of changed v5 bytes. Existing windows and built apps keep
the fonts loaded at launch until a fresh launch/build.

The prior menu test also compared composited vector-arrow pixels against a
2-colour glyph oracle. All 191 independently reproduced joystick mismatches are
inside the verified cursor allocation. The corrected test checks every font
pixel beneath the hidden arrow, then checks that the final cursor composite
cannot alter the surrounding text. It removes no glyph preservation checks.

## Lowercase cohesion, 2026-10-02

The dialogue screenshot exposed short lowercase stems, irregular terminals and
generic diagonal forms that did not fit the original face. Revision 4 authors
all 104 lowercase glyphs across the four original fonts as coherent families.
Shared bowl construction, level stem ends, controlled shoulder joins and serif
terminals replace those defects. The bold face retains two-unit main stems,
one-unit bars and its original one-unit middle stem in `m`. Lowercase stencil
openings remain deliberate. Source ink extents and fixed advances are unchanged.

That pass selected `local-art/pc-outline-fonts-v4/manifest.json`, SHA-256
`c45b765f6db77f7afb58297de6841106f2a234ef56171bbe1fa34c6a15531833`.
The shared runtime loader and packaging allowlist select this pack for dialogue,
briefings, menus and the existing text overlays. Capitals, figures and symbols
retain their approved v3 contour inventories, including the earlier R correction.
The original files, recognition checks, text content and game logic are unchanged.

Working if: all lowercase glyphs retain source extents, measured stems remain
consistent, reported short terminals reach their baseline, and actual TTF pixels
match the outline interiors at multiple scales. The existing uppercase, symbol,
alias, counter, stencil-channel and fixed-cell checks must continue to pass.

Completed source proof is under `artifacts/pc-font-cohesion-20261002/`:
31 focused font/text tests pass, and source-only CI passes 110 tests with seven
skips. The reported-stem regression rejects the old v3 pack. All four actual TTF
hashes, the runtime pin, private packaging closure and original source hashes
match. Raster checks compare every lowercase outline interior with FreeType at
two scales, using the existing native oracle's 2/255 gray tolerance. This exposed
overlapping strokes in the bold `w`; a continuous outline removes that defect.
The tolerance was not widened to conceal it.

`dialogue-original-refined.png` compares original pixels with the selected pack;
`all-faces-refined.png` renders all four current faces. Both use fixed source
cells and the real baseline. This correction was authored and visually reviewed
by the assistant, with an isolated typographic assessment. Native Godot all-face and office checks later passed, but the menu oracle
failed at the vector cursor and the stopped batch left intro unrun. Those
receipts are preserved as historical v4 evidence.
Existing windows and previously built apps retain their loaded v3 assets; they
are not updated by changing the source pack. Earlier packs are preserved. The
optional detector does not cover Python or Godot typography.

## R and cap/baseline correction, 2026-09-28

Nell's enlarged DIRECTOR / DAMON SLYE screenshot exposed two remaining defects:
the R leg had an angled, short foot and a nearly closed stencil channel; open
strokes in A/M/N/Y stopped short of their intended cap/baseline. Whole-glyph
bounding-box checks missed N's short right stem because its other corner already
reached the cap line. The source letters themselves have consistent heights.

`tools/pc_font_optical.py` now extends exposed uppercase/digit terminals along
their existing stroke direction before clipping at the original glyph bounds.
The extension accounts for the inset corner of diagonal strokes. R's diagonal
targets the actual baseline centre to retain its foot width, and its stencil
channel remains open for the complete height. There is no vertical stretching,
change to fixed advances, replacement of lower-case/symbol shapes, or per-string
credit-screen workaround. The shared pack applies to every existing font binding.

That pass selected `local-art/pc-outline-fonts-v3/manifest.json`, SHA-256
`a9d68ef60adbca97c3f3917817c272dacf6f81f5e92171a8cb8cab837fe1b099`.
Build each revision into a fresh directory with the existing `build_pc_outline_fonts` tool.
The v2 pack is preserved. All 380 glyph/face combinations and 203 authored
alphanumeric shapes remain; 68 uppercase/digit contour records changed.

Working if: all capitals/digits reach their original cap/baseline, the reported
open stem ends pass local ink probes, each R has a horizontal right-leg foot,
and the stencil channel and counter remain open. Existing stem/bar weights,
diagonal weight, source aliases and fixed-cell checks must still pass.

Both new regression tests reject v2 and pass v3. An initial candidate's terminal
extension left the small technical R foot too narrow; the baseline-centre
correction fixed it before selection. Study packs remain under
`artifacts/pc-font-terminals-study-01/`. The same-scale production-renderer recap
is `artifacts/pc-font-terminals-recap-01/credits-before-after.png`.
The assistant authored and reviewed this correction; Nell's stylistic judgment
remains separate. Source recognition, PC logic and original resources are unchanged.

Completed proof is in `artifacts/pc-font-terminals-recap-01/receipt.json`:
227 Python tests and all 29 validation stages pass in
`validation-20260928T001833Z`. Native all-face/five-scale, intro and office checks
report 3,421,787; 2,840,243; and 8,148,962 checks, respectively, with zero errors.
The actual Play credit capture is byte-identical to the native credit fixture.
In the enlarged production-renderer credit, all nine lower-row letters occupy
exactly rows 264 through 323; both R channels are open and both feet reach the
same baseline. `credit-corrected.png` is the current close-up. The optional
Impeccable linter remains unavailable; the checks above use native Godot rendering.
Existing live windows retain the font data loaded at startup; the selected pack
is used on the next ordinary launch. No unrelated running process was stopped.

## Menu and remaining frontend text, 2026-09-28

The refined faces now extend to the original joystick prompt, main and nested
menus, changing scenario/time/skill values, campaign name entry, mission-title
letters, information-page prose (including HEAT), and END summary/score/kill text.
No substitute menu, game value or wording is authored. Existing fitted credits,
office dialogue, Genesis information colours and arming layout retain precedence.

`tools/pc_frontend_text.py` adds pinned START, BRIEF and END profiles alongside the
existing SIM observer. Their original main-CS far-call counts are 46, 5 and 17.
Each profile verifies its relocation-free 80-byte string wrapper, 709-byte EGA
character driver, entry anchor, active PSP/MCB, known caller and loaded original
font payload. Source-relative profiles are:

| Program | DS | Wrapper segment:entry | Driver segment:entry | Foreground field |
|---|---|---|---|---|
| START | 1505 | 0760:0212 | 0b5a:0060 | 2648 |
| BRIEF | 0c71 | 03c7:0212 | 06e7:005c | 0894 |
| END | 0d22 | 0477:020e | 0798:005c | 637c |

All values are hexadecimal, relative to the original executable's load segment.
Wrapper/driver derivation and disassembly are in
`artifacts/pc-menu-text-source-01/`; the root reran the source derivation and
cursor proof rather than relying only on the read-only agent's findings.

The native text-only hook is armed before EXEC/unpacking, including the first
cold-boot joystick prompt. Entry snapshots and completed draw rectangles are
observations only. It never writes guest RAM, registers, inputs or VGA state.
SIM geometry, audio/message attribution and rendering epochs remain separate.
Completed candidates are frozen with the original scanout/triple-buffer slot.
Page-copy survivors require current source-glyph matches rather than an assumption
that the active page redrew each label. Classification runs on requested bridge
presentations, avoiding extra work on fast-forwarded emulator frames.

Original menu selection reverses colours after drawing. The frontend therefore
checks the original ink mask against the current foreground/background pair,
retaining the original highlight. Whole current rectangle hashes and font bits
are independently checked again in Godot. Newer matching draws win overlaps;
changed or unsupported cells retain original pixels.

The original arrow can cover highlighted letters. Its resource hash, loaded
16x15 bitmap/mask, frame-paired position and all 79 opaque presented pixels must
match before those exact pixels can be excluded from glyph recognition. Godot
independently pins the decoded cursor and composites it above the refined text.
It never clears the complete cursor rectangle or reuses a stale mask. Forged or
malformed cursor metadata is rejected without engine errors. The arrow remains
original pixel art, intentionally outside this typography change.

Working if: changing selections and edited names retain original wording and
colours, the arrow remains above polished letters, transitions clear old text,
and nontext pixels and original core execution are unchanged in bounded checks.

Evidence:

* `pc-menu-text-comparison-01.json`: all 18,206 shared-state original frames match
  the unmodified core in RAM, video and input, across menus (5,190), information
  (5,749) and mission lifecycle (7,267). Sampled programs, decoded SIM states and
  every saved source PNG also match. All eight scenario choices, DAY/NIGHT,
  NOVICE/MODERATE, name editing/cancellation and original exit were exercised.
* `pc-menu-text-native-02/report.json`: 46,080,266 checks, zero errors over 45
  rendered frontend samples and 211 accepted text runs.
* `pc-menu-text-lifecycle-native-01/report.json`: 36,864,197 checks, zero errors
  over 36 rendered frontend samples, including mission-title and summary text.
* `pc-menu-text-information-native-01/report.json`: 45,056,264 checks, zero errors
  over 44 rendered samples. HEAT's 18 text runs are refined independently of its
  still-original illustration. Its native render was visually inspected.
* `validation-20260928T000139Z/results.txt`: all 29 stages passed, including 225
  Python tests, original-file preservation, the new frontend-text gate, audio and
  runtime smoke checks. `pc-menu-text-negative-02.log` independently reports 222
  checks with no engine errors after the malformed-cursor correction.
* Actual Play captures `pc-menu-text-{joystick,scenario,name}-live-01` exited zero
  with completion sentinels and no engine errors. Joystick, scenario/name menus,
  mission title and mission summary were visually inspected. These are
  assistant-authored integration and self-review; stylistic acceptance is Nell's.

The initial capture check wrongly required an active game executable after
original Exit returned to DOS. It was corrected to test actual image dimensions,
allow that explicit exit transition and require the final original exit. The
first full gate also caught engine errors from intentionally malformed cursor
base64; fixed-length/alphabet and decoded-size guards now reject it before the
decoder. Neither failed run is counted as a passing gate.

The shared neutral snapshot removes independent cold-boot RAM noise for the
comparison only. Cold boot is separately exercised by actual Play captures.
The source routes are reproducible with `python3 -m tools.capture_pc_menu_text
--mode trace --route menus --output <fresh-directory>`; use `information` or
`lifecycle` for the other routes and `baseline` for the unmodified core. The new
Godot suite accepts `--fixture <directory>/report.json`; its local default is
the recorded `artifacts/pc-menu-text-trace-04/report.json` fixture.
Restoring arbitrary snapshots clears observation history; already-drawn text
stays original until observed again. Bitmap-baked diagram captions/logos and
nonuniform-background glyphs remain distinct work. These routes establish
bounded observer non-interference, not exhaustive campaign, save or historical
hardware timing equivalence. Original files and generated derivatives stay local.
The optional Impeccable linter is unavailable; native Godot pixel checks and
visual inspection provide the rendered evidence for this game interface.

## Optical refinement, 2026-09-28

Nell requested more regular thicknesses and angles after reviewing the first
outline pass. `tools/pc_font_optical.py` now supplies authored centre-line geometry
for 203 alphanumeric glyphs across the four faces. Shared bowl, shoulder, stroke
and bevel construction replaces the local pixel-corner decisions that produced
pinched joins and thin diagonal strokes. The bold faces retain two-unit vertical
stems and one-unit bars; the technical faces use one-unit strokes. Related bowl
corners share 45-degree cuts. Stencil openings use consistent 0.75-unit slits.
Measurements are in the original glyph-cell coordinate space.

The source's fixed advance, cap/ascender/descender bounds, slab serifs, squared
technical Y, distinctive technical 4/7 and slashed 8X8 zero remain. Already
rectilinear serif forms and unmodified symbols retain their earlier contours.
All 380 glyph/face combinations remain present, with identical source aliases.
The runtime bindings, colours, original text verification and game logic are
unchanged. This pack replaces the font shapes in the same previously verified
credit, memorial, office, cockpit, arming and information-page cells.

The original bitmap-centre equality requirement remains for unshaped glyphs and
for source recognition. Optical shaping deliberately relaxes it for the 203
authored glyphs; enforcing it there would preserve the irregularities Nell asked
to remove. New binary-level checks measure D/O stems and bars, related bowl
angles, stencil gaps, diagonal weight, counters, bounds and fixed advances.
The native oracle uses TrueType's nonzero winding rule for joined strokes and
counter contours, independently of Godot's font rasterizer.

Working if: related glyphs have measured consistent stems and bevels, stencil
gaps and counters remain open, and native text still fits every verified original
cell without changing protected pixels or displayed wording.

That pass selected `local-art/pc-outline-fonts-v2/manifest.json`, SHA-256
`3d87b1ade72efd6f975895e10d16b1082d49f6eec6a6776da85c1d1091d6f574`.
The later corrections above supersede it. Generate the current shapes with
the existing Python FontTools dependency into a fresh directory:

```sh
python3 -m tools.build_pc_outline_fonts --output local-art/pc-outline-fonts-v4
```

The v1 pack remains available for comparison. Development studies are under
`artifacts/pc-font-beauty-study-01/`. The first binary check exposed float
round-trip noise, then a redundant closing vertex removed by the TTF writer.
The check now compares exact integer design units, and contour normalization
removes duplicate vertices before both metadata and binary serialization.
These were representation defects; neither was accepted as a passing check.

Selected-pack evidence:

* `validation-20260927T230059Z/results.txt`: all 28 repository stages passed,
  including 220 Python tests, preservation and runtime smoke checks.
* `pc-font-beauty-native-02/report.json`: 4,765,809 checks, zero errors, four
  faces at five scales plus cockpit fixtures.
* Native intro, office, arming, information and cockpit reports under
  `pc-font-beauty-{intro,office,arming,information,cockpits}-01`: respectively
  2,840,243; 8,148,962; 1,068,308; 17,760,849; and 12,371,692 checks, zero errors.
* Three actual launcher runs exited zero with no engine errors.
  `pc-font-beauty-launcher-receipt-01.json` verifies byte-identical credit,
  briefing and dedication PNGs against their independently checked native
  fixtures and records the selected font-manifest hash.
* The 8x complete glyph specimen, briefing and dedication were visually reviewed.
  `pc-font-beauty-recap-01/credits-before-after.png` compares the two font packs
  through the real credit renderer at the same scale, spacing and colours.

The assistant authored the refinements and performed their visual review.
Stylistic acceptance remains Nell's. Original supplied files and derivative-font
redistribution boundaries are unchanged; the optional Impeccable linter is absent.

## First outline pass, 2026-09-27 (superseded shapes)

This section records the earlier v1 construction and its evidence. Coverage and
source recognition remain current; the optical v2 pack above supplies the shapes.

Nell's credit-card screenshot clarified that literal enlargement of the bitmap
stair-steps was insufficient. The current default reconstructs clean angular
contours from the four pinned original faces. The stencil cuts, protected serif
corners, fixed cell widths, line spacing and original placement remain. This is
a new outline interpretation of the supplied bitmap designs; no original vector
master has been recovered. The earlier source-bit meshes remain a fallback.

`tools/build_pc_outline_fonts.py` joins source boundary edges and simplifies
alternating one-cell stairs into diagonals. It preserves rectilinear glyphs and
selected serif/stem corners. All 380 printable face/character combinations have
local TTF glyphs; 281 have simplified contours. Every unambiguous original pixel
centre retains its ink/background classification. Points on a new diagonal
boundary are explicitly treated as ambiguous. Identical source aliases retain
identical outlines. Direct native-size Potrace and Scale2x/Potrace experiments
distorted thin letters and serifs and were rejected; their evidence remains in
`artifacts/pc-font-contour-study-01/`.

Godot rasterizes these faces at the actual display size with grey antialiasing,
no hinting and no subpixel positioning. No new words, inferred game values,
line reflow or timing changes are introduced. Default coverage includes:

* All eight intro credits and David "Ming" Kenny's dedication.
* Verified briefing/debrief dialogue, cockpit readouts and arming-menu labels.
* 81 source-matched headings, descriptions, specifications and crew-role labels
  across the six currently supported information pages.

The information bindings derive words from the pinned original loaded string
table, then compare every complete font cell to the original page. They do not
use OCR. Original PC specifications and the existing Genesis crew-label palette
remain. Embedded bitmap captions, unsupported pages, unobserved text layouts and
developer-only chrome remain outside this font binding. In particular, the small
ABRAMS/M1A1 diagram captions remain source-shaped. HEAT's illustration blocker is
unrelated and unchanged.

Working if: diagonal edges render as outlines rather than enlarged pixel steps,
all complete verified runs fit their original cells, every nontext pixel stays
protected, and `--original-text` retains the source-shaped rendering.

The earlier local pack is `local-art/pc-outline-fonts-v1/manifest.json`, SHA-256
`5301f992bf938ef537161b89bbb712d66ef7471d4c4305709008787634dd8a6b`.
Its generator is preserved in commit `5d98bc3`. The loader verifies the selected
pack's manifest, every original FNT and every TTF payload.

Use a fresh output directory when rebuilding; generated fonts and catalogs stay
ignored local derivatives. No redistribution permission is implied.

First-pass evidence:

* `tests/test_pc_outline_fonts.py`: deterministic TTF bytes, actual TTF contour
  coordinates, advances, 21,660 original cell centres, bounds and aliases.
* `pc-outline-fonts-native-01/report.json`: 4,765,809 checks, zero errors, all
  four faces on an empty backdrop at 1x, 3x, 3.5x, 4x and 8x, plus live cockpit
  fixtures. The independent polygon oracle never invokes the font renderer.
  Exact foreground/background interiors and exteriors are checked separately
  from the subpixel edge band, which permits only their antialias mixtures.
* `pc-outline-intro-native-01/report.json`: 2,840,243 checks, zero errors,
  credit/dedication contours, original-text modes, protected panels and all
  7,800 recorded PC boundaries.
* `pc-outline-office-native-01/report.json`: 8,148,962 checks, zero errors.
* `pc-outline-arming-native-01/report.json`: 1,068,308 checks, zero errors.
* `pc-outline-cockpits-native-01/report.json`: 12,371,692 checks, zero errors.
* `pc-outline-information-native-01/report.json`: 17,760,849 checks, zero errors,
  all six supported pages, source-only fallbacks, original-text crew mode,
  changed-source rejection and protected illustration/callout pixels.
* Actual `Play.command` runs in `pc-outline-credits-live-01`,
  `pc-outline-briefing-live-01` and `pc-outline-dedication-live-01` exited zero.
  `pc-outline-launcher-receipt-01.json` confirms that all three live PNGs are
  byte-identical to their independently checked native renders.
* `validation-20260927T223817Z/results.txt`: all 28 repository stages passed,
  including 218 Python tests and the original source-preservation check.

The implementation, test oracles and visual review are by the same assistant.
Nell's stylistic acceptance is separate. The optional Impeccable linter is absent;
native Godot rendering supplies visual/layout evidence.

## Earlier source-bit typeface pass, 2026-09-27 (superseded default)

Nell requested the original font/typeface. The prior IBM Plex Mono substitution
is removed from verified game text. The renderer now keeps the source font hash
and cell dimensions through verification and constructs geometry directly from
the pinned original font bits. Original side bearings, baseline, spacing, stroke
weight, counters and stencil cuts are unchanged. Each label caches only its
current text mesh; resizing changes the drawing transform, not the letter design.
The original pixel-shaped contours are intentional. This is exact scalable
geometry, not invented smooth outlines or a lookalike typeface.

All four supplied faces support the 95 printable ASCII characters (32 through
126) already admitted by the visible-text gate. This does not expand the original
character set. Unknown fonts, rejected characters and incomplete/overwritten
runs still retain the original framebuffer. No new font binaries or proprietary
font payloads are committed; glyph geometry is made locally from supplied files.

The Genesis capture at `reference/genesis/graphics-ammo-pages-01/ax` contains a
contiguous stencil font bank at VDP tile 1504. All 95 printable glyph masks match
PC `STENCIL.FNT` exactly. Tile 1599 (DEL) differs and is excluded. This establishes
that specific shared face; it does not identify every other Genesis bitmap font.
`test_pc_fonts.py` validates the entire capture receipt and compares each mask.
Original information-page text is already retained verbatim. It has not acquired
new high-resolution page bindings in this change. Developer-only range/gallery
chrome keeps its separate fonts.

Working if: restored game text uses the verified original face and metrics,
all 380 printable glyph/face combinations preserve their bit silhouettes at
multiple scales, and no replacement can draw outside its verified source box.

Evidence:

* `pc-original-fonts-headless-02/report.json`: 182,924 geometry/visibility checks,
  no errors. The native pass below repeats these checks.
* `pc-original-fonts-native-02/report.json`: 9,088,617 checks, no errors. All four
  faces are drawn on an empty backdrop at 1x, 3x, 3.5x, 4x and 8x and compared with
  an independent direct-bit oracle. An invisible renderer cannot pass by exposing
  original text underneath. Recorded cockpit text also matches its source.
* `pc-original-fonts-arming-native-01/report.json`: 1,068,308 checks, no errors.
  Complete glyphs and original allocation/focus states match, with the existing
  Genesis menu colour mapping retained.
* `pc-original-fonts-office-native-01/report.json`: 8,148,962 checks, no errors.
  Native briefing/debrief dialogue letterforms and protected regions match.
* `pc-original-fonts-cockpits-native-01/report.json`: 12,371,692 checks, no errors.
  Four stations and STATUS retain exact lettering under the live Genesis art profile.
* `validation-20260927T204936Z/results.txt`: all 27 repository stages pass,
  including 211 Python tests. The subsequent native-02 test strengthens the
  specimen oracle with an empty backdrop; production code is unchanged.

The previous typography assertion demanded more than 100 changed pixels and
multiple antialiasing colours. That rewarded the unwanted substitute design.
Its replacement demands original glyph fidelity. These checks were implemented
and reviewed by the same assistant. This presentation-only change adds no new
simulation, timing, campaign or whole-game parity evidence. The optional
Impeccable linter is not installed; visual validation uses native Godot captures
and pixel comparisons.

## Native font storage

The four-byte header is cell width, height, first character and character count.
The payload is glyph-major, row-major, with `ceil(width/8)` bytes per row and the
most significant bit at the left. File length must equal the header's declared
payload exactly. The supplied files are:

| Resource | Cell | First | Count | Observation |
|---|---|---|---|---|
| `6X6.FNT` | 6 x 6 | 32 | 96 | Same bytes as VM.FNT |
| `VM.FNT` | 6 x 6 | 32 | 96 | Alias, preserve both original names |
| `8X6.FNT` | 8 x 8 | 32 | 96 | Header takes precedence over filename |
| `8X8.FNT` | 8 x 8 | 32 | 105 | Nine stored upper-code glyphs are rejected by the original driver |
| `STENCIL.FNT` | 8 x 8 | 32 | 96 | Separate glyph artwork |

Main DS offsets 364e, 3662, 3676 and 368a hold the selected header fields;
369e holds the payload segment. `pc_fonts.loaded_font` reconstructs the complete
source bytes and requires a match against the supplied files. Unfamiliar fonts
stay source-only.

The original character driver is relative CS:IP `1388:0068..032c`, selected by
main DS:35b4. Its 709 original instruction bytes match SIM.EXE offset 80616 and
SHA-256 `f4139b282b485998e11c05b9c9ca4f87b0a3f583ee7e2a167f9e7acebfa194c7`.
Signed comparisons reject codes 128 through 136 even though 8X8.FNT stores them.
The observer preserves that behaviour. It does not repair the original font.

`pc_font_oracle.py` executes those unchanged instructions in the pinned isolated
Unicorn 2.1.4 CPU. It compares all four complete 64 KiB planes, including untouched
bytes, at four aligned/unaligned positions, on both EGA pages, with opaque and
transparent text. `pc-font-oracle-02.json` records 3,912 blits, 1,025,507,328 checked
plane bytes and 62,208 VGA writes. The retained first attempt correctly failed
at code 128 because the initial expectation incorrectly rendered every stored
glyph. This is font-driver evidence, with no DOS or historical timing claim.

## Original display boundary

The original string wrapper runs at `0f8d:020a..0259`. Its far-call stack contains
return IP/CS, string pointer, x and y. It reads the selected font and drawing page,
converts foreground/background indices through the original word table at 48a6,
then calls the original character driver for each byte.

The observer originally recognized four semantic return addresses in the
original main code segment:

| Return IP | Meaning | Source routine |
|---|---|---|
| 3f1d | Primary crew text | 0000:3e7e |
| 3f58 | Secondary crew text, including formatted hit bearings | 0000:3e7e |
| 400d | Radio text actually being drawn | 0000:3f7a |
| 55df | Weapon status, including READY, TRACK and LOAD | 0000:54b6 |

Native event 26 copies conventional RAM at wrapper entry. Event 27 copies a
six-word rectangle header `(x,y,width,height,page_offset,return_ip)`, followed by
one EGA colour index per pixel, immediately before the wrapper's RETF. It reads
host plane storage directly, avoiding guest VGA reads that would change latches.
The original instructions, rendering, registers and emulated cycle schedule
continue unchanged. The expanded observer requires `text_event_schema: 2`.
It recognizes all 49 main-segment far calls to the same source string wrapper.
The additional calls have the conservative `instrument` kind; their inclusion
does not assign new speech or message identities. A source test matches the
native and Python allowlists against the unpacked executable's call bytes.

## Visibility gate

1. Decode the exact loaded source font and original string at the known draw call.
2. Match every glyph foreground pixel and, for opaque text, every background pixel
   against the original completed EGA rectangle. Transparent text retains the
   actual background from the original draw.
3. Freeze completed candidates for the original page at scanout start. Keep them
   with the same native triple-buffer slot as its pixels and palette.
4. At presentation, compare every RGB channel in the entire rectangle with the
   actual BGRX framebuffer. Require visible ink/background contrast.
5. Expose only matching runs. Empty, offscreen, rejected-character, unknown-font,
   overwritten, wrong-page, unknown-palette and unobserved runs remain absent.

Candidates are bounded to 256 `(page, callsite, x, y)` entries, with oldest-entry
eviction. Coordinates distinguish labels drawn through the same numeric helper.
A redraw replaces that key's candidate; a verified blank clearing draw leaves
no label. A new SIM collector discards the old mission's candidates. A later
draw cannot mutate an older scanout's evidence. Internal candidate pixels never
appear in the JSON bridge payload.

Working if: a queued or erased message cannot become visible metadata, altered
rectangle pixels invalidate the run, and original RAM/video/input comparisons
remain equal to the untouched core.

The metadata contains the displayed words, rectangle, source pointer, font hash,
callsite, monotone draw sequence, palette indices, cell dimensions, uniform
background RGB (or null), and complete RGB rectangle hash. The crew speaker byte
is captured at the original draw, with no added character identity inferred.
These are visible **runs**, not once-only message occurrences. Repeated drawing,
repeated identical messages, primary/secondary grouping, radio acknowledgement
and speech cancellation still need a separate occurrence/timing contract.

## Historical visible-text evidence

* `pc-text-audio-01/report.json`: 2,091 actual frames, 372 observed text calls, all
  372 source-glyph matches, 1,570 presented runs. READY appears in 1,148 frames,
  LOAD in 381 and TRACK in 41. There are 516 rejected frame/candidate comparisons.
  `pc-text-parity-01.json` passes all 18 existing audio/control checks against
  `pc-audio-baseline-03`; RAM, video, input and sound-channel states match exactly.
* `pc-text-visibility-audio-01.json`: all eleven visibility/parity checks pass. This
  capture has no saved per-stage source crops; its live RGB comparison is separate
  from the saved-crop proof below. All three reload-completion hooks precede the
  first visible READY label by three emulated frames: 822 to 825, 1477 to 1480,
  and 1918 to 1921. Triggering a bark directly from the RAM update would reveal
  readiness before the original interface does in this probe.
* `pc-text-crew-01` and `pc-text-crew-baseline-01`: 1,308 frames and all stage states
  match. Seven ordinary smoke-key requests exhaust the six original mortars and
  cause the original crew warning. All 260 native text calls match source glyphs;
  the warning is visible in 134 frames. It is absent after the original clears it.
  Station-key requests remain original inputs; this capture proves the crew
  warning in the gunner display only.
* `pc-text-crew-comparison-01.json`: all 12 checks pass. Twenty-four saved source
  image crops independently match their runtime RGB rectangle hashes, including
  the crew warning. `ui-smoke-7-frame-00260.png` was also visually inspected.
* `pc-text-lifecycle-02/report.json`: all 11 lifecycle checks pass, including
  7,267 equal RAM/video/input frames, 52 stage states and identical original
  START/BRIEF/SIM/END/reentry transitions against `pc-lifecycle-baseline-02`.
  The first run used a wrong baseline filename and failed at comparison; its
  log is retained. Baseline readability is now checked before launching a core.
* `pc-text-native-01/report.json`: the updated core also passes the native Godot
  one-frame bridge/audio test: 1,692 original frames, 3,386 loop checks, correct
  96,000-frame loop endpoints, two audible cannon shots, one silent shot, one
  impact, one coax request, one smoke request, zero errors and child exit 0.
* `validation-20260927T104409Z/results.txt`: all 18 repository stages pass,
  including 158 Python tests and 52 Godot audio assertions.

The implementation was reviewed by the same assistant that wrote it. No live
hit-bearing suffix or displayed radio message was exercised in these probes.
Their recognized callsites are source-derived; live acceptance remains open.
The earlier all-256 bearing formatter/TTS tests do not close that gap. These font/text probes predate the subsequent loader integration. They do not
establish a font remaster or full dialogue coverage.

## Reproduction

Use fresh output directories. All proprietary source files and captures remain
local and excluded from Git and exports.

```sh
.runtime/pc-analysis-venv/bin/python tools/pc_font_oracle.py \
  --capture artifacts/pc-ui-controls-02/first-render.bin \
  --output artifacts/pc-font-oracle-03.json
python3 tools/build_pc_trace_core.py
python3 tools/capture_pc_render_trace.py --mode baseline --profile text \
  --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-text-crew-baseline-02
python3 tools/capture_pc_render_trace.py --mode trace --profile text --capture-ui \
  --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-text-crew-02
python3 tools/verify_pc_text_trace.py \
  --trace artifacts/pc-text-crew-02/report.json \
  --baseline artifacts/pc-text-crew-baseline-02/report.json \
  --output artifacts/pc-text-crew-comparison-02.json
```

The font/readiness build used trace core SHA-256
`303d494ecbb28a900d3732fc772e292b3a4fa271036f9c2cdf214f60698776e2`;
trace header SHA-256 is
`e42c666bad4102220c158506fc27329d8d49ec21f84f9021d5f9cdc7b9d34869`.
The unchanged source baseline remains
`57edbd309eb2ab6264b70188c3a85408fbcfa8c62e83b8c7b9c39b7309f61ac6`.


The subsequent [original crew-message integration](pc-audio-research.md#fully-displayed-original-crew-messages-2026-09-27)
adds assignment identity, complete prefix/suffix grouping, and live incoming-hit
and damage coverage. Its updated native core fingerprints and acceptance
receipts supersede the font/readiness build pins above. Displayed radio coverage
remains open.

## Scalable live typography, 2026-09-27

The default four-station material view now enables `pc_typography.gd`. It uses
our existing SIL Open Font License IBM Plex Mono face, with a 64-pixel glyph
cache and fixed source-cell advance. Each accepted run has its own clipped
Control, preserving its original rectangle, foreground and background. Resizing
changes presentation dimensions only. `--original-text` disables replacement;
`--original-art` also retains the source letters.

The original `6X6.FNT`, `8X6.FNT`, `8X8.FNT` and `STENCIL.FNT` files remain local.
Godot loads them only after checking all four SHA-256 fingerprints. It decodes
the bitmaps independently of the Python observer and checks:

1. ASCII words, cell dimensions, font identity and complete on-screen bounds.
2. Every pixel against the source glyph foreground or a single uniform actual
   background colour, plus the complete original RGB rectangle hash.
3. Every pixel's original UI ownership. Any scenery pixel rejects the whole run.
4. Nonblank visible ink and a non-overlapping replacement rectangle. Later
   surviving candidates take precedence when their rectangles overlap.

Every new frame clears the previous labels before accepting current runs. A
missing font, incomplete frame, unsupported text, changed background, menu or
fallback clears replacements and retains the source pixels. Working if: erased
or altered values disappear immediately, no replacement can cover a world pixel,
and native images change only within verified source UI rectangles.

The source font bytes serve as evidence, rather than the new visible font.
Static bitmap lettering, gauges, icons and text over scenery still use their
original pixels. In particular, the bearing strip over the world remains
source-rendered at this historical checkpoint. The subsequent bearing-only
transparent-world restoration is documented in `pc-world-bearing-text.md`.
Other scenery-backed labels remain unsupported. Some static labels become eligible only on observed source
redraws. This pass does not claim complete high-resolution instruments or
uniform text coverage across every state.

### Verified receipts

* `pc-live-type-crew-comparison-02.json`: all twelve checks pass against
  `pc-text-crew-baseline-01`. All 1,308 full-RAM/video/input frames and stage
  states match. All 3,105 observed string calls match their source glyphs,
  including 226 blank clearing draws. There are 13,058 presented runs and
  11,255 rejected stale/background comparisons. All 316 saved source crops
  independently match their runtime RGB hashes.
* `pc-live-type-cockpit-comparison-02.json`: all nine checks pass against
  `pc-cockpit-baseline-02`. All 2,214 frames and 21 stage states match. All 2,235
  observed calls match glyphs, including 130 blank draws. All 117 saved source
  crops match; 38,297 candidate/frame comparisons are rejected.
* `pc-live-type-lifecycle-01/report.json`: all eleven checks pass, including
  7,267 identical RAM/video/input frames, 52 stage states and original
  START/BRIEF/SIM/END/START/BRIEF/SIM boundaries against
  `pc-lifecycle-baseline-02`. These three routes total 10,789 matching frames.
* `pc-live-type-dialogue-comparison-01.json`: all fourteen checks pass against
  `pc-dialogue-baseline-01`, including 8,576 matching RAM/video/input/queued-text
  frames, seventeen original assignments and sixteen fully visible crew calls.
  All 22,229 string calls match source glyphs, including 1,814 clearing draws.
  Together with the three routes above, 19,365 recorded frames match the
  untouched core. Routes can overlap; this is not 19,365 unique game situations.
* `pc-live-type-dialogue-event-comparison-01.json`: all three checks pass against
  the earlier crew trace. All 1,849 audio events remain exactly equal after
  removing only observer `draw_sequence` from their source parts. Frames,
  words, pixel hashes, rectangles, source pointers, voices, IDs and gates are
  unchanged; all original assignment records also match.
* `pc-live-type-crew-audio-native-02/report.json`: the unchanged strict native
  playback test passes with the fresh verified reference. All 8,576 original
  frames complete, sixteen once-only crew events start fourteen generated
  streams on their exact reference frames, END is reached, and the child exits
  zero with no errors. This is stream-start evidence, not physical-device
  latency or human listening approval.
* `pc-live-type-crew-native-02/report.json`: 3,227,083 native Godot assertions,
  zero errors, 3,264,000 visited pixels, including the synthetic 1280 x 800
  full-frame boundary test and 35 actual source captures. There are 10,654
  changed text samples. Every protected source-pixel centre remains unchanged.
* `pc-live-type-cockpit-native-02/report.json`: 2,350,365 native assertions,
  zero errors and 2,368,000 visited pixels over the synthetic image and 21
  actual station/modal samples. There are 5,544 changed text samples. Both
  native reports include rejection, stale-label and resize checks.
* `pc-live-type-viewer-comparison-01.json`: all eight checks pass for two actual
  gunner viewers from the same original snapshot, with replacement on/off.
  Complete presentation metadata (including render RAM hash), original state,
  original framebuffer and Godot world framebuffer are identical. Ten text
  runs change 5,434 of 1,024,000 output pixels, all inside independently checked
  UI boxes. The original-text opt-out reports zero replacements.
* `pc-live-type-driver-viewer-01`: live driver capture shows three restored
  numeric runs with the moving assembly, Genesis colours and terrain detail
  still enabled. Gunner and driver captures were visually inspected. Their
  native viewer processes exit zero.
* `validation-20260927T133757Z/results.txt`: all 22 repository stages pass,
  including 192 Python tests, source preservation, 18 headless typography
  assertions, 150 Godot audio assertions and the existing runtime smoke gate.

These changes were implemented and reviewed by the same assistant. The first
aggregate run failed a new test's hardcoded ten-character width for an
actually eleven-character label. The test now derives bounds from the source
rectangle; the failed log is retained in `pc-live-type-validation-01.log`.
The earlier crew/cockpit `-01` observer captures categorized blank clearing
runs as unsupported; the corrected `-02` captures prove them against the actual
original background and never expose them as visible labels. No guard was
removed to obtain these passes. The optional Impeccable linter is unavailable
locally; actual Godot rendering and pixel checks provide the visual validation.

The first native crew regression, `pc-live-type-crew-audio-native-01`, stopped
on its first bark because the previous four-callsite reference had different
observer draw-sequence numbers (592/593 versus 7684/7685). Its source frame 2369,
voice, words, rectangles and RGB hashes agree. The strict reference comparison
is retained. The fresh baseline-verified dialogue capture and complete event
comparison above establish that only this observer numbering changed.

All 49 source callsites are allowed, but these bounded routes do not prove live
coverage of every callsite, dialogue, font, weapon mode or mission. These are
shared-state emulator comparisons, with no new historical hardware timing or
physical display/audio latency claim. The independently cold-booted RAM
fingerprint difference retained in the terrain investigation remains unresolved.

### Current observer pins and reproduction

This typography build supersedes the older font, crew and cockpit core pins:

* Core: `537c524451028b5b5a2952901a40fc2abbf8a5af77adb5e8caba792d2fd7b024`.
* Trace header: `7aef474f9f410f4414dc68856d4e793b0964f26c3866c3c884fe6bb335d9f0e4`.
* Plate observer: `3720a03996d3e22c6c756365da122e11d9d72c2fbfd35c7a09c25e6b465da00e`.
* Unchanged baseline: `57edbd309eb2ab6264b70188c3a85408fbcfa8c62e83b8c7b9c39b7309f61ac6`.

Use fresh output names:

```sh
python3 tools/build_pc_trace_core.py
python3 tools/capture_pc_render_trace.py --mode trace --profile text --capture-ui \
  --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-live-type-crew-NEW
python3 tools/verify_pc_text_trace.py \
  --trace artifacts/pc-live-type-crew-NEW/report.json \
  --baseline artifacts/pc-text-crew-baseline-01/report.json \
  --output artifacts/pc-live-type-crew-comparison-NEW.json
./tools/godot.sh --disable-render-loop --script res://tests/test_pc_typography.gd -- \
  --native --fixture "$PWD/artifacts/pc-live-type-crew-NEW/report.json" \
  --output "$PWD/artifacts/pc-live-type-native-NEW"
./PC\ Bridge.command --trace --capture --capture-station gunner \
  --output "$PWD/artifacts/pc-live-type-viewer-NEW"
```

The font cache uses the documented Godot 4.7
[FontFile glyph APIs](https://docs.godotengine.org/en/4.7/classes/class_fontfile.html).
No new external font dependency or proprietary distribution is introduced.
