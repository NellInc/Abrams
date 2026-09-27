# Original PC fonts and visible text

The tandem bridge supplies read-only `presentation.text_runs` metadata for
original labels. Every supplied run passes native glyph and presented-frame
checks. Eligible runs now use locally reconstructed TrueType outlines of the
four original faces after a second, independent Godot source-pixel check. The source letters
remain available with `--original-text`. The READY-specific loader voice gate
is described in `pc-audio-research.md`.

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

The selected pack is `local-art/pc-outline-fonts-v2/manifest.json`, SHA-256
`3d87b1ade72efd6f975895e10d16b1082d49f6eec6a6776da85c1d1091d6f574`.
Generate with the existing Python FontTools dependency into a fresh directory:

```sh
python3 -m tools.build_pc_outline_fonts --output local-art/pc-outline-fonts-v2
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
source-rendered. Some static labels become eligible only on observed source
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
