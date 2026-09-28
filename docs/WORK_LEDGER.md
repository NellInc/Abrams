# Local work ledger

## Authorization and goal

2026-09-26: Nell requested a substantial local Godot reconstruction, exact PC
logic, higher-resolution graphics, new effects and voice. She then supplied the
Genesis ROM and requested graphic extraction and style-preserving remastering.
Her clarification explicitly retains PC gameplay as definitive.
She subsequently authorized Genesis sound and music extraction as reference
material for likely upgrades. PC events and timing continue to govern playback.
She clarified that native samples should be used rather than mixed recordings,
and requested generative crew speech, preferring Gemini 3.8 Flash TTS with 3.1
Flash TTS as fallback. This authorizes sending the authored crew script to Google
for speech generation. Original game audio and ROM data stay local.
Nell also specified digit-by-digit bearing barks. The generation pipeline now
expands heading/bearing numerals while retaining numeric captions; a separate
Gemini 3.8 audition says the supplied heading-280 line. It is an audition, not an
added simulation event.

Authorized: inspect supplied references, execute local emulators, create source
extracts, use selected images with the built-in image editor, author Godot code,
generate local sound/voice, test and document. No publication, push, deployment,
ROM upload or redistribution was requested. Preserve the supplied files.

The active goal remains open. `GOAL.md` incorporates the platform clarification.

Nell asked whether to transplant/rewrite the code or retain the original behind
a new renderer. The recommended direction is original-PC-executable authority
inside an instrumented emulator, with a read-only Godot presentation bridge.
The following goal continuation authorized continued local execution. Neither
the current authored range nor a diagnostic pose view counts as the remaster.

## Original-frame dispatch overlap and boundary audit, 2026-09-28

Previous goal turn: progress, exact observer/clock work committed as `85165ba`.
The next clock-eligible original frame now dispatches after the current packet's
existing audio, required-state and PNG checks, before Godot constructs its
presentation. There is still one outstanding request, current held-key sampling,
one original frame per interactive request, and no catch-up queue. Capture batches
retain their old ordering. No original/core/artwork bytes changed.

`docs/pc-pacing-research.md` records the ordering, reproduction and remaining
limits. A diagnostic-only `--frame-audit` option hashes the existing paired
conventional RAM and native video buffers; it neither advances nor re-reads the
guest, writes no memory dumps, and is off during ordinary Play. It was added to
prove this scheduling change against more than decoded state alone.

Evidence:

* `artifacts/pc-transport-profile-01/full-boundary-parity.json`: all 1,020 original
  input requests, complete packet hashes and paired conventional-RAM/framebuffer
  hashes match between late and early dispatch. The hashes cover 668,467,200 RAM
  bytes and 261,120,000 framebuffer bytes. Exact consecutive-frame counts and
  expanded control-fixture keys pass. Final metadata, all four native PNGs and
  audio receipts/loop transitions match. The replay uses the real Godot keyboard
  path for movement, braking, turret, firing, smoke and four station routes.
* The non-audited control/audio A/B pair also matches every complete packet and
  request, with final native image equality. Its measured rate is 44.33 fps late
  versus 55.29 early. **The audit-enabled pair reverses this: 51.04 late versus
  46.19 early.** Both results are retained. A general performance gain under
  variable machine load is unproven; the verified change removes a mandatory
  serialized wait, and sustained target-rate acceptance remains open.
* Final 1,200-frame stationary probes measure 57.21 fps gunner and 59.91 driver.
  The original advertises 59.92 Hz. These roughly twenty-second local tests do
  not establish historical machine-speed or full wall-clock input parity.
* `artifacts/validation-20260928T040422Z`: final aggregate terminal exit 0,
  all 36 stages and 247 Python tests pass. The production scheduling fixture
  passes 54 checks, including exact held-key identity, pending/closing/error
  guards, phase, capture ordering and original capture deadlines.
* The opt-in corrupt-PNG test passes 55 assertions and deliberately emits the
  decoder's corruption errors. It verifies that invalid image data cannot send
  another original frame. This negative case is separate from the aggregate's
  unchanged no-engine-errors check.

An initial transport probe failed its 60-second final-capture deadline at
19.08 fps. An uninstrumented control was similarly slow at 19.04 fps, with frame
application exceeding 14 ms instead of roughly 5 ms. System load average was
15.85; unrelated processes were left alone. No probe recorded a partial JSON
prefix, so packet splitting was not supported as the cause. The bounded profiler
now retains its explicit 90-second deadline through final capture; ordinary
mission/cold-boot capture timeouts remain 60/180 seconds.

The initial public-launcher visual comparison was incorrectly paired with a
different-sized reference (1440x900 versus 1440x810). Original/world images and
every non-display metadata field matched. The failed receipt is retained; it is
not treated as a passing screenshot comparison. The correctly size-matched rerun
exits 0 and passes complete capture metadata and original/world/tandem/window PNG
equality, as does the cold-boot joystick menu comparison:
`artifacts/pc-transport-profile-01/public-matched-parity.json`.

The implementing assistant inspected the control-run native image. This remains
self-review of assistant-produced work, not Nell's art acceptance. Local only;
the same five unrelated untracked vehicle-study files remain untouched. The
overall remaster remains active. Sustained timing calibration, remaining
graphics/audio, all mission/campaign/save flows, cross-platform acceptance and
release custody still require work under the unchanged full goal.

## Exact observer optimization and live pacing, 2026-09-28

Previous goal turn: progress, native-resolution Play committed as `4fcb4f6`.
This continuation profiles the actual original-PC host and production Godot
viewer, reduces exact pixel-processing overhead, and preserves fractional clock
phase. Original source/core binaries, CPU settings, artwork and input batching
remain unchanged. `docs/pc-pacing-research.md` records methods and limits.

The initial native gunner probes achieved 27.80 and 29.55 fps. Matched 120-frame
unpaced throughput now reaches 55.78 fps; mean sample application falls from
15.73 to 5.49 ms. The final 1,200-frame actual interactive probes measure gunner
54.23, driver 58.57, commander 59.10 and cupola 59.98 fps, against the original
core's advertised 59.92 Hz. **Sustained pacing is still open**, especially gunner,
combat, changing masks and optional audio. An intermediate phase-only gunner run
measured 47.19 fps; the final result does not erase that earlier measurement.

Repeated plate predicate validation falls from 7.47 to 0.18 ms, and the driver's
moving-assembly predicate from 15.62 to 0.46 ms on unchanged frames. The latter
baseline is the intermediate phase-corrected build. Bounded caches retain exact
byte pairs only; current provenance, source hashes and artwork availability
remain checked. Bulk Python RGB operations preserve all compared pixels. PNG
encoding reuses exactly matching raw bytes only after current-frame validation.

The old clock reset reproduced 1,800 requests in a steady 60-second 60 Hz
fixture. Retaining fractional phase yields 3,595, with one outstanding request
and no catch-up bursts or backdated input. Overload can still slow the original;
this is not historical machine-speed or wall-clock input parity.

Evidence, all root-run with terminal completion:

* `artifacts/pc-pacing-profile-01/before-after-parity.json`: complete 1,458-frame
  trace report and all 76 PNG files are byte-identical to the pre-change trace.
  No fields excluded. Gunner and driver native capture JSON and all four PNG
  outputs are also identical after the same input/frame sequence.
* `artifacts/pc-pacing-profile-01/source-parity.json`: all 20 source-baseline and
  visible-crop checks pass. There are 337 completed reticle draws, 1,207 verified
  presented candidates and the same 246 rejected stale/overwritten candidates.
* `artifacts/pc-pacing-profile-final-01/host-report.json`: all 147 paired original
  RAM/video/input records match baseline. Mean traced step time is 6.31 ms,
  versus 10.05 ms in the initial instrumented probe. Machine variance remains.
* Native synthetic fixtures pass 1,024,000 gunner and 4,096,000 multi-station/
  moving-roof RGB checks, plus current-metadata and warm-cache corruption cases.
* `artifacts/pc-pacing-genesis-native-01/report.json`: all 12,238,012 checks pass
  across 21 recorded cases. Actual Play also cold-boots the joystick menu with
  complete capture metadata and all compared PNG bytes identical to its earlier
  public-launcher capture (`menu-parity.json` in the profiling directory).
* `artifacts/validation-20260928T034057Z`: aggregate terminal exit 0, all 35 stages
  and 246 Python tests pass, including 49,159 deterministic clock checks.

The implementing assistant inspected the actual gunner frame; this is self-review,
not Nell's art approval. The repaired surround joins and ammunition proportions
remain intact. No new styling or optional linter dependency was added. Local only;
the same five unrelated untracked vehicle-study files remain untouched.

Next pacing question is pipe-ready versus Godot-poll/render latency, followed by
longer combat/audio and standalone-original timing comparisons. All remaining
graphics/audio families, complete mission/campaign/save parity, cross-platform
runtime and release custody conditions in `GOAL.md` remain open. This is progress
within the active full-remaster goal, not completion of that goal.

## Native-resolution play window, 2026-09-28

Previous goal turn: progress, committed source-verified graticule `b8c1dbb`.
This continuation makes Play a clean, resizable 4:3 game window, with native
fullscreen available through `--fullscreen` and the window controls. The original
comparison layout remains available through `--compare` or PC Bridge. No game
keys are intercepted. No emulator, original input, camera projection or source
asset changed. `docs/pc-display-research.md` records the architecture and controls.

The interface now renders at the actual physical game-rectangle size instead of
stretching a fixed 1280x800 composite. The world target scales isotropically from
the original clip, preserving source camera aspect and projection while covering
both output axes. Child-first viewport rendering preserves scanout pairing during
resizes. All original content remains visible, with black letterboxes rather
than an expanded field of view or additional tactical information.

Evidence:

* Final headless display contracts: 694 checks pass, including 360 projections
  across six window shapes, four original clips and three focal lengths.
  Maximum error is below 0.000017 original pixels. Negative sampling-oracle
  cases reject non-boundary neighbours and unrelated colours.
* `artifacts/pc-native-display-tests-04/report.json`: native terminal exit 0,
  792 assertions and 24,999,518 full-frame pixel comparisons pass across 18
  cases. Five first-resize colour/clip changes and five source fallbacks are
  followed by four recorded stations at two window sizes. Exact texel-boundary
  neighbours are explicitly accounted for; all other RGB checks remain exact.
* `artifacts/pc-native-window-resize-02/resize-report.json`: six actual-window
  transitions pass, including fullscreen and return to a requested 1440x900
  window. Render targets exactly match the displayed game rectangle, all
  letterboxes are black, and state/presentation/original image and guest sample
  count remain unchanged throughout the frozen-frame test.
* `artifacts/pc-native-display-validation-01/capture-parity.json`: native Play
  and the public comparison launcher retain identical original state, program,
  presentation, sample count and framebuffer to the pre-change capture. The
  optional comparison composite is byte-identical as well. The public Play
  cold-boot joystick menu renders at the requested 1440x1080 with all three
  original text runs recognized. These are bounded checks, not campaign parity.

* `artifacts/validation-20260928T030919Z`: final aggregate terminal exit 0;
  all 34 stages and 241 Python tests pass, including the final 694 display
  contracts, launcher argument routing, keyboard checks and source preservation.

The initial window test exposed the engine's startup size override, fixed by
applying requested dimensions after initialization. The first strict-floor RGB
oracle failed on exact texture boundaries; independent pixel and rational-ratio
checks demonstrated valid adjacent samples, now covered without broad tolerance.
The first actual-window fixture also failed to require the requested size after
leaving fullscreen: the OS ignored its premature resize. That fixture was broken,
not accepted proof. It now waits for the mode transition before requesting size
and asserts the exact result; the second run above passes.

Actual Play, the returned window and the joystick menu were visually inspected by
the implementing assistant. This remains self-review, not Nell's art acceptance.
Optional Impeccable is unavailable; no dependency was installed. Native runtime
coverage is local macOS only. Other platforms, sustained interactive timing,
remaining graphics/audio families and complete-game parity remain open. Local
only; five unrelated untracked vehicle-study files remain untouched.

## Source-verified gunner graticule, 2026-09-28

Continued the local remaster after the frame/ammunition repair in `1bc6bd3`.
The eight-stroke gunner sight now has a resolution-independent Godot layer,
retaining the Genesis reference's square-ended, open-centre style and the PC
executable's exact geometry, projected centre, clipping, colour and timing.
Read-only native observations bind completed original draws to full scanout RGB.
Unknown or altered frames retain the original content. No guest logic or input
path changed. `docs/pc-reticle-research.md` records source and reproduction.

Evidence:

* `artifacts/pc-reticle-cpu-03/oracle.json`: 522 whole-routine fixtures and 304
  original line-wrapper clipping fixtures pass. All 331 executed instruction
  locations match the supplied executable, and 216,530,944 VGA plane bytes
  compare exactly. Isolated fixture coverage is not a live-reachability claim.
* `artifacts/pc-reticle-live-parity-02.json`: all 20 checks pass across 1,458
  frames; trace and baseline RAM, video, inputs and stage states match. All 337
  observed draws complete, with 1,207 scanout matches and 246 rejected stale or
  overwritten candidates. Live zoom, four centres, both thermal colours,
  return to normal colour and station transitions are covered.
* `artifacts/pc-reticle-native-01/report.json`: 30 samples at 1280x800,
  1728x1080 and 1920x1200 pass 1,003 assertions and 51,942,400 full-frame pixel
  comparisons. Integer output is identical. Fractional edge changes stay
  within original ink and match analytic coverage over an unrelated test world.
  The expanded headless comparison passes 1,154 checks against all 826 CPU
  fixtures; seven Python tests cover observer corruption and lifecycle.
* `artifacts/pc-reticle-play-01/reticle-verification.json`: actual Play launcher
  exits 0 with the new layer active. Source metadata/crop hashes match, original
  state and framebuffer are unchanged, and the complete 1280x800 remastered
  image is byte-identical to the repaired cockpit capture. This intentionally
  preserves integer-scale sight appearance, rather than inventing a new reticle.
* `artifacts/validation-20260928T024325Z`: final aggregate exits 0, all 33 stages
  and 241 Python tests pass, including reference preservation. Optional
  Impeccable remains unavailable; no dependency was installed.

The implementing assistant inspected both actual Play art and the fractional
white-sight fixture. This is self-review, not Nell's aesthetic acceptance.
The research viewer remains fixed at 1280x800 internally; native-resolution
window/fullscreen configuration needs separate camera-aspect validation. The
TADS target-selection box still uses original pixels. Whole-game parity and the
broader remaster remain open. Local only, no remote publication; five unrelated
untracked vehicle-study files remain untouched.

## Gunner frame and ammunition correction, 2026-09-28

Nell's `download.png` exposed a broken join across the gunner surround and
incorrect ammunition proportions. The prior visual acceptance claim was wrong;
passing source-ownership checks had not caught bad component registration.

Corrected the side-frame join at PC row 123, restored the donor's actual right
surround instead of stretching a blank silver strip, and made the central bevel
transition continuously into the wider heading frame. Eight instrument icons
now use tight, uniformly scaled crops; four coloured ammunition silhouettes
are drawn over the original verified cell background. No donor image, original
count, source rectangle, visibility guard, emulator or input path changed.

Evidence:

* `artifacts/pc-cockpit-repair-native-02/report.json`: 21 recorded station/status
  frames, all five plate IDs, 12,238,012 checks, zero errors, terminal exit 0.
  New crop/aspect/centering checks and native icon sampling cover 1280x800 and
  1920x1200; sixteen donor probes cover both repaired joins and the right frame.
  Existing protected-pixel and damage-fallback checks still pass.
* `artifacts/pc-cockpit-repair-play-03/`: actual public launcher capture,
  terminal exit 0. The complete 1280x800 composite and native 1920x1200 fixture
  were visually inspected. This is the implementing assistant's self-review,
  not Nell's art acceptance. The fixture deliberately uses source-crop scenery;
  the actual Play capture shows the paired high-resolution world.
* `artifacts/pc-cockpit-repair-01/before-after-final.json`: original framebuffer,
  Godot world image and complete capture metadata are identical to the rejected
  `pc-world-bearing-play-01` capture. The old composite passes only four of
  sixteen new join probes; the repaired composite passes all sixteen.
* `artifacts/validation-20260928T021709Z`: final aggregate exit 0, all 32 stages
  and 234 Python tests pass. Source reference preservation passes. Optional
  Impeccable was unavailable; no dependency was installed.

The first local repair capture retained screw shear from blending every panel
column; blending only the outer side-frame columns corrected it. A subsequent
1920-pixel inspection exposed the central heading-bevel cut, now also corrected.
Those intermediate captures remain under `pc-cockpit-repair-play-01/02` and
`pc-cockpit-repair-native-01`; they are superseded, not final acceptance images.

This fixes the reported composition faults. Cockpit-family completion and the
broad remaster remain open. Local only, no remote publication. Five unrelated
untracked vehicle-study files remain untouched.

## Transparent bearing lettering, 2026-09-28

Completed the next text presentation pass: the original BEARING label and its
three-digit value now use the same polished 6x6-derived face over scenery in
both original placements. Leading zeroes, words, colours, geometry and timing
come from observed PC text calls, never current RAM. The Genesis source shows
the same compact strip. Every original glyph ink bit must be UI-owned and every
counter/background bit world-owned; the complete RGB crop, page and camera must
match. Only accepted old ink is removed from a copy of the composition mask,
revealing the paired world texture under transparent new outlines. No flat
background rectangle, extra label or tactical value is introduced.

No emulation, hook, input or audio code changed. Existing 1,113-frame parity
receipts remain the bounded original authority. New evidence:

* `docs/pc-world-bearing-text.md`: original call sites, source constraints,
  independent composition checks and reproduction.
* `artifacts/pc-world-bearing-native-01/report.json`: 374,947 assertions and
  66,560,000 full-frame pixel comparisons pass across 40 native samples at
  1280x800 and 1920x1200. Deliberately nonuniform clean world backgrounds prove
  that old ink disappears and new counters expose the actual paired world.
* Contract test: 387 checks pass, including all 000..359 synthetic labels,
  black/white, both placements, JSON numbers, corruption, ownership conflicts,
  page/camera mismatches, missing fonts, missing text and fallback clearing.
* Existing four-station/status and typography native tests pass 12,237,884 and
  4,573,806 checks respectively. Their supplied source-crop backgrounds are now
  handled explicitly by the transparent-label oracle, not mistaken for uniform
  backing colours.
* `artifacts/pc-world-bearing-play-01/`: actual launcher capture exits 0, shows
  polished BEARING 000 with Genesis art, vector gauges and orientation active;
  both original text source hashes match independently. Final image inspected.
* `artifacts/validation-20260928T015742Z`: final aggregate exit 0, 234 Python
  tests and all 32 stages pass. Optional Impeccable is absent; none installed.

The work was authored and reviewed in this session; Nell's visual acceptance
is separate. Reticles remain original and are next, followed by further cockpit,
status, maps, world/effect, audio and whole-game parity coverage. No live white-
bearing reachability, whole-game parity, finished remaster or release candidate
is claimed. The broad goal remains active. Local only, no remote publication;
unrelated vehicle-study files are unchanged.

## Rotating hull/turret display, 2026-09-28

Completed the next cockpit presentation slice under the existing local remaster
authority. The PC executable remains definitive, with no replacement simulation.
The read-only bridge now observes complete original orientation draws, checks
fixed-point geometry and per-edge colours, and binds them to actual scanout RGB.
Godot draws crisp, clipped vectors using the extracted Genesis display's visual
language. The moving grid, independent hull/turret positions, black fill versus
outline-only mode, component colours and original timing are retained. Heading
text remains in its existing separately verified renderer.

Evidence:

* `docs/pc-orientation-research.md` records source hashes, instruction/data
  addresses, isolated versus live claims, visual decisions and reproduction.
* `artifacts/pc-orientation-cpu-01/oracle-integrated.json`: all 1,024 source-CPU
  cases and observer bindings pass, covering both stations/themes/pages,
  every hull and absolute turret angle, varied relative angles, fills and
  component colours. Original raster bytes are retained; this is not an
  independent polygon-fill or whole-game timing equivalence claim.
* `artifacts/pc-orientation-live-parity-02.json`: all checks pass across 1,113
  frames with identical trace/baseline RAM, video, input and stage states.
  All 225 draws completed, 1,097 presentations matched, and eleven mismatches
  retained original pixels. Source crops, moving grid, hull turning and
  turret-relative movement with a stationary hull are directly checked.
* `artifacts/pc-orientation-native-03/report.json`: 321,049 assertions, zero
  errors, 59,904,000 full-frame pixel comparisons at 1280x800 and 1920x1200.
  Changes remain inside the proven source rectangles. Both stations render;
  missing plate provenance after snapshot restore correctly retains originals.
  Eight additional original-CPU damage/theme examples were visually reviewed.
* `artifacts/pc-orientation-play-02/`: actual Play capture passed with the new
  diagram enabled, source RGB hash matched, and the rendered packet identical
  to the presented observer packet. Final crisp output was visually inspected.
* Final `./tools/validate.sh`: exit 0, 234 Python tests and all 31 stages pass,
  completion receipt `artifacts/validation-20260928T014131Z`.

Corrections made during verification: the first replay turned the hull rather
than the turret until the original C control-mode key was added; Godot's JSON
floats required explicit integral-array comparisons; snapshot-entry frames
correctly lacked plate provenance and must remain original; the first rendered
antialiasing fringe scaled with source pixels and was replaced with display-
pixel smoothing. These failed/intermediate artifacts remain separate from the
final evidence. The work was authored and reviewed in the same Codex session;
Nell's aesthetic acceptance is not claimed. Optional Impeccable is unavailable,
with no installation or dependency-policy workaround.

Next: source-verified reticles and bearing text over nonuniform world imagery,
remaining cockpit/status variants, then broader world/effect restoration.
No live damage-event reachability, all-mission parity, completed audio package,
or release candidate is claimed. The overall goal remains active. No remote
publication occurred; the five unrelated vehicle-study files remain untouched.

## R and cap/baseline correction, 2026-09-28

Nell identified the remaining R defect and unequal lower-row letter heights in
the enlarged credit card. The earlier outlines used inset, open stroke ends;
these shortened A/M/Y and N's right stem and left R's foot slanted. The new v3
pack corrects outer terminal geometry within the original cells, gives R a level
foot and preserves its continuous stencil channel. Stroke weights and fixed
advances remain; lowercase and symbols are unchanged. Existing credits, menus,
briefings and other verified text bindings share the correction.

Two targeted regressions reject the old pack, including local endpoint checks
that the earlier whole-glyph bounds test could not cover. Both now pass alongside
the original reproducibility, binary-outline, spacing, weight and alias tests.
The old pack and unselected studies are preserved locally. No original binaries,
font sources, input/game logic, artwork or unrelated vehicle files were edited.
The assistant authored and reviewed the correction. Exact pack hash, rendering
evidence and scope are recorded in `pc-text-research.md`. Local only.

Validation completed: 227 Python tests, all 29 repository stages, native specimens
at five scales, all intro cards/dedication and office scenes. The Play credit PNG
matches its native fixture exactly. The enlarged lower row measures one common
60-pixel cap height and baseline for every letter, and both R feet/channel masks
pass direct native pixel checks. Evidence is in
`artifacts/pc-font-terminals-recap-01/receipt.json`. Optional Impeccable is absent.
No push or publication; the broader remaster goal remains open.

## Menu and frontend typography coverage, 2026-09-28

Nell requested the same polishing for the joystick prompt, game menus and other
text. The existing optically refined four-face pack now serves source-observed
text across START, BRIEF and END as well as the existing SIM bindings. This
covers original prompts, menu labels and selections, scenario values, entered
names, mission titles, information text including HEAT, and summaries/scores.
All wording, controls and values remain the original executable's output.

The additional files are necessary to observe three distinct original programs,
compose verified cursor pixels above their highlighted text, and exercise both
source non-interference and native typography. No authored menu logic or new
font/art pack was introduced. A read-only source-analysis agent supplied bounded
profiles/cursor findings; the root inspected the source, reran the derivations,
owned integration and performed the final checks.

The native observer now attaches before the first boot prompt. Each accepted run
requires original code/font identity, completed draw evidence and current glyph
pixels. Original highlight recolouring and page copies are handled explicitly.
The original cursor remains pixel art and is independently verified rather than
painted over. Source changes, unsupported cells, stale program states and invalid
metadata retain original pixels or clear derived text.

Proof: `artifacts/pc-menu-text-comparison-01.json` records 18,206 identical
original RAM/video/input frames across three shared-state routes; sampled
programs, decoded states and source PNGs also match. All eight mission choices,
time/skill changes, name editing, information submenus, original exit and the
mission/debriefing lifecycle were exercised. Three native suites passed with no
errors and protected every nontext/cursor pixel against the corresponding base
render. Three actual Play captures completed. Joystick, scenario, name entry,
mission title, summary and HEAT typography were visually reviewed.

`validation-20260928T000139Z` passed all 29 repository stages, including 225 Python
tests. Earlier failures were genuine: the capture check incorrectly required a
game PSP after original Exit, and malformed base64 in the new cursor negative
test emitted engine errors. The checks and decoder guard were corrected; neither
failed artifact is counted as a pass. Exact native counts, source profiles,
capture commands and comparison limits are in `pc-text-research.md`.

This integration was authored and visually reviewed by the assistant. Optional
Impeccable is unavailable; native Godot rendering supplies the visual evidence.
Arbitrary restored snapshots still require fresh text observation. Bitmap-baked
captions/logos, nonuniform-background glyphs and exhaustive campaign/save/end
variants remain open, as does the broader remaster goal. Original resources,
generated derivatives and the five unrelated vehicle-study files are unchanged.
Local only; no push, deployment, upload or publication.

## Optical typeface refinement, 2026-09-28

Nell requested a second beautification pass to regularize thicknesses and angles.
The four-face v2 pack optically shapes 203 alphanumeric glyphs with shared stroke,
bowl and bevel geometry. Technical strokes are one source unit; bold vertical
stems are two units with one-unit horizontal bars. Related bowl cuts are 45
degrees and stencil slits are 0.75 units. Original fixed advances, distinctive
forms and source recognition remain. The previous local bitmap stair decisions
no longer constrain authored alphanumeric joins. Symbols and already rectilinear
serif forms retain their earlier contours.

This is a rendering-only change to existing bindings: credits, David "Ming"
Kenny's dedication, briefing/debriefing, cockpit readouts, arming and supported
information text. The PC still owns content and timing. Generated fonts stay in
ignored local art; original sources and the five unrelated untracked vehicle
study files are untouched. No new dependency, publication or push was needed.

Proof: `validation-20260927T230059Z/results.txt` has 28 passing stages including
220 Python tests. Six native suites cover all glyphs at five scales and the
integrated screens, with zero errors. Exact counts and current manifest hash are
in `pc-text-research.md`. Three actual launcher captures (credit, briefing and
dedication) match those native fixtures byte-for-byte, recorded in
`artifacts/pc-font-beauty-launcher-receipt-01.json`. The same-scale comparison is
`artifacts/pc-font-beauty-recap-01/credits-before-after.png`.

The assistant authored and visually reviewed these shapes. Nell's stylistic
acceptance remains separate. The optional Impeccable linter is unavailable;
native Godot checks provide rendered evidence. This completed local typography
pass does not close the broader remaster goal or imply full gameplay parity.

## High-resolution original-style typefaces, 2026-09-27

Nell supplied the DIRECTOR / DAMON SLYE credit screenshot and requested the very
same typeface style at high resolution, including briefing text. The previous
bitmap-shaped mesh pass was insufficient. The current pass reconstructs four
local outline faces from the original FNT cells, preserving source spacing,
proportions and stencil/serif details while simplifying diagonal stair chains.
Direct Potrace and Scale2x/Potrace trials were rejected after visual inspection.

Default integration covers all eight credits, the memorial, eligible cockpit,
arming and office runs, and 81 exact source-string information-page runs. The
last extension uses the pinned original loaded string table and full font-cell
comparisons rather than OCR, keeping the PC wording/specifications. Small
embedded diagram captions, unsupported pages and unknown states retain original
pixels. This changes rendering only; the PC still owns inputs, content and timing.

The local pack, catalog hashes, reproducible generation and independent geometry
oracles are documented in `pc-text-research.md`. Source bits remain the recognition
oracle and fallback. Native verification includes every printable glyph of every
face at five scales, plus rendered credits, briefing, arming, cockpit and
information fixtures. The assistant authored and reviewed these changes; Nell's
stylistic acceptance remains separate. No original binaries, ROM, generated font
payloads or derivative art are committed or published.

Completed evidence: all six native font/screen tests passed (font specimens,
intro, office, arming, cockpit and information), and actual Play captures passed
for credits, briefing and dedication. All three live PNGs exactly match their
native renders (`pc-outline-launcher-receipt-01.json`).
`validation-20260927T223817Z` completed all 28 stages, including
218 Python tests and source preservation. Native captures of all four faces and
representative screens were visually inspected. Optional Impeccable is
absent. The broader remaster goal remains open, with no new whole-game parity or
publication claim.

## Original typeface request, 2026-09-27

Nell requested the same fonts/typefaces as the originals. Removed the IBM Plex
Mono substitute from verified game text and retained each run's original font
identity and metrics. Four original faces now render as scalable glyph meshes,
with their pixel-shaped contours unchanged. Genesis VDP tiles prove an exact
printable stencil-face match. Original-only page text stays untouched; developer
range/gallery fonts are outside the game lettering change.

The code and native pixel checks are documented in `pc-text-research.md`.
The 27-stage full gate and 211 Python tests pass; native empty-backdrop font,
arming, office and Genesis-cockpit checks pass. No source executable, bridge, input route or
simulation file changed. The original-text fallback remains available. Proprietary
font data stays local. The wider remaster goal remains open.

## Crew information composition, 2026-09-27

The previous goal turn made progress: commit e0a1181 restored the original
letterforms and passed native fidelity checks. This continuation binds the four
existing Genesis portraits and a new clean-contour Genesis wireframe to the
complete original PC crew-information page. Labels, four seat positions and
callout relationships remain original. The footer/frame is replaced only when
all 64,000 source pixels match, beyond the earlier 175-row illustration gate.

The diagram's first generated pass retained coarse stairs and was rejected.
The selected second pass and both exact prompts remain local under
`local-art/genesis/remastered/crew-diagram-v1/`. The earlier unrelated HEAT image
rejection remains open; no retry or workaround was attempted for it.

Catalog v2 verifies 63,840 loaded source pixels and mask bits, including all five
CREW sprites. Caption/diagram registration independently matches the Genesis
source. Native standalone and complete-tandem checks pass, as do actual Play
remaster/original source and state comparisons. The two test renders and actual
launcher output have identical PNG bytes. A misleading image preview initially
looked incomplete; original-resolution inspection and byte equality disproved
my rendering-fault diagnosis. No production workaround was made for that preview.

Evidence and current limits are in `genesis-information-integration.md`. The
19-page gallery, 27-stage gate and strengthened 48-check tandem information test
pass. This remains local work. No game executable, emulator, input route or
simulation changed; full-game parity and the whole remaster remain open.

## Proven local milestones

| Outcome | Evidence | Boundary |
|---|---|---|
| Preserve PC reference | 68-file SHA-256 manifest and verification | Supplied package includes PTL distribution branding; historical authenticity unresolved. |
| Recover PC compression/data | All 48 type-2 resources decode to declared lengths; eight SSS/WLD pairs inspected | Field storage is not full mission semantics. |
| Recover PC vector storage | 188 shape records; 992 primitive lists; closed cube OBJ independently checked | Renderer flags, units, materials and object identities unresolved. |
| Recover PC executable images | Four EXEPACK images match an independent unpacker and execution of their original stubs | Isolated CPU proof, not complete game behaviour. |
| Original bearing calculation | All 256 inputs match the Godot port; all 256 padded hit-call strings pass digit-wise TTS expansion | Angle integration and actual incoming-hit events remain. |
| Live original PC core | Original Mossel Defense briefing, motor pool and mission executed inside the local core | Emulator timing calibration, complete mission outcomes and all eight missions remain. |
| Original replay bridge | Two 978-sample traces match full 640 KiB RAM and framebuffer bytes exactly | Same-core bounded replay, not historical-machine or whole-game parity. |
| Godot live integration | Input forwarding, player movement, braking, stations, turret and HEAT consumption pass; helper exit zero | Diagnostic vehicle pose only; original world, cameras, visibility and combat presentation remain. |
| Read original manual | 48-page scan, extracted page images, mechanics ledger | Manual statements require runtime confirmation. |
| Testable simulation | 1,093 Godot checks pass | Provisional authored range only. |
| Functional range | Native/headless movement, four stations, targeting, fire, effects and menus | No original campaign or enemy AI. |
| Terrain correctness | 60,000 upward triangle normals and flat range bounds pass | Procedural presentation remains preliminary. |
| New audio | Seven original synthesized effects; nine generative crew samples replace scratch speech | Eight Gemini 3.8 takes, one 3.1 fallback; final casting/listening review remains. |
| Genesis source integrity | 512 KB ROM checksum `727b` and unchanged SHA-256 | PC mechanics remain authoritative. |
| Genesis extraction | Ten independent captured scenes reconstruct with zero pixel differences | Bounded video mode; not exhaustive ROM asset recovery. |
| Genesis native audio | Ten PCM assets, 25 FM patches and four music containers extracted directly from ROM | Cue identities and music-command interpretation remain; earlier mixed recordings are comparison-only. |
| Initial high-resolution art | Four generated assets saved locally with prompts and receipts | Fine details are interpreted; first Wilson/office treatment approved by Nell. |
| Godot art comparison | Three scenes in both modes captured in native renderer | External local art only; no release bundle. |

## Validation receipts

* `artifacts/reference-tests-genesis.log`: 29 Python tests passed, including PC
  resources, cube topology, Genesis byte order, palette, flips, integrity and
  full-frame comparisons. One test image-handle warning was corrected. The later
  suite extends the corpus from seven to ten captures.
* Godot simulation: `SIMULATION: 1093 checks passed`.
* Godot geometry: `GEOMETRY: 60000 upward normals and complete range bounds verified`.
* Godot runtime: `RUNTIME_SMOKE_PASS: movement, four stations, selection, fire,
  effects, screen navigation`.
* `artifacts/art-review.log`: native `ART_REVIEW_PASS` and exit zero.
* `artifacts/art-review/`: all three original/remaster screenshot pairs.
* `artifacts/screenshots-final/`: initial range presentation captures.

The combined gate failed because Godot reported two ObjectDB instances and
one resource still in use at shutdown, despite the runtime smoke assertions
passing. Two verbose diagnostic runs and a bounded six-run check did not reproduce
it. The exact cause remains unconfirmed. Explicit audio playback/cache release
and deferred smoke-test shutdown did not eliminate the combined-gate failure.
Standalone, shell-context, Dummy audio and post-geometry probes exited cleanly.
The gate now requests verbose runtime diagnostics so any recurrence identifies
the retained objects/resources. This is an observability change, not a verified
repair. A clean rerun must not erase the original failure or be described as
causal proof of repair. The error check remains enabled.

Latest complete gate: `artifacts/validation-20260926T204843Z/results.txt` records
PASS for reference tests (29), preservation, simulation (1,093 checks), geometry
and verbose runtime. Exit status was zero. The earlier shutdown issue remains
open despite this successful diagnostic-mode run. Artwork captures also pass at
1440x810 and 1920x1080. The local art-workbench ZIP contains 162 verified entries;
neither the ROM nor an emulator is included.

Audio update gate: `artifacts/validation-20260926T212412Z/results.txt` passes
reference tests, source preservation, simulation, geometry, imported audio and
runtime checks, with a terminal exit status of zero. The nine selected voice
transcripts match automatically; casting/listening approval remains open. The
effects rebuild was separately checked to preserve their hashes and metadata.
The historical shutdown warning remains unresolved; a passing run is not a repair.

### Original-core bridge pass

`artifacts/pc-bridge-replay-02/report.json` proves two 978-sample original-PC
replays with identical conventional RAM and framebuffer bytes. The first replay
check failed on a stale initial restored framebuffer and an incorrect instant-
braking expectation; that artifact is retained. Explicit video priming and enough
original braking time resolved those specific failures without replacing rules.
`artifacts/pc-live-godot/report.json` verifies native Godot input/state transport
and graceful helper exit. `artifacts/pc-bridge-viewer-run-02.log` and the paired
native PNG show the read-only pose viewer with no engine errors. The earlier
viewer run's premature camera look-at was corrected. These checks do not establish
original terrain/camera/visibility fidelity or historical CPU/input timing.

The native 1440x810 paired view was visually inspected. No optional Impeccable
linter is installed/configured for this GDScript-only project; none was installed
to replace native rendering checks. The original GAME bytes were reverified and
all 68 files in the local content ZIP match them byte-for-byte.

### Audio shutdown regression

The first bridge-wide gate (`artifacts/validation-20260926T222702Z`) failed after
the runtime assertions with a retained `voice_ready.wav` and its playback.
An initial drain guard watched only currently attached playback and still missed
players stopped earlier by a menu change. A focused stopped-before-drain test
reproduced that failure (`artifacts/audio-already-stopped-before-fix.log`).

The controller now retains weak lifetime observations of started/stopped playback,
releases owned streams and waits for those observed instances to be freed before
scene teardown, with a one-second failure deadline. Window close, capture and
smoke-test shutdown use that path. Five stopped-before-drain checks now pass
(`artifacts/audio-already-stopped-fixed-1.log` through `-5.log`), as does the full
runtime smoke (`artifacts/runtime-audio-drain-fixed.log`). This is a demonstrated
project-level teardown repair for the reproduced path, not a Godot-engine fix or
a claim about every platform. Earlier passing runs did not prove this repair.

Final combined gate for this pass:
`artifacts/validation-20260926T223708Z/results.txt`, terminal exit zero. All eight
checks pass: 75 Python tests, reference preservation, 1,093 authored simulation
checks, 512 original-bearing fixture outputs, 60,000 geometry normals, nine
generated voices, observed audio playback deallocation, and runtime smoke.
The separate live-core replay and native Godot bridge receipts above are required
alongside that gate; the normal source gate does not silently claim to run them.

## Original world bridge, 27 September 2026

The preceding architecture answer was a discussion checkpoint, with no source
progress. This pass implements the next original-PC presentation dependency.

**Recovered and executed:** WLD shape IDs and packed/extended coordinates, signed
streaming-local positions, continuous map coordinates, active static/dynamic
pool layouts, and primitive high-bit vertex scaling. The original executable's
own routines match all 6,163 static entries across eight worlds, 16,384 packed
positions, 192 extended cases, 192 cell-center/inverse cases, 1,894 distinct
primitive references and all four map-window shifts. Receipt:
`artifacts/pc-world-oracle-02.json` (terminal exit zero). The first narrower
oracle is retained as `pc-world-oracle-01.json`; neither run failed.

**Independent decoder evidence:** entire decoded SHAPE.TBL (33,830 bytes) and
SNARIO6.WLD (10,778 bytes) match the running original's buffers. All 37 current
static objects match the source window. This upgrades those two resources from
structural evidence to original-decoder comparison; other resources remain
unverified by an independent decoder.

**Bridge repair:** schema 1's unsigned local coordinates were wrong for world
placement. Schema 2 reads signed coordinates and carries the shifting window
origin. `artifacts/pc-world-live-01/report.json` contains two identical 978-sample
traces, one real northward rebase, no movement discontinuity and zero static
placement mismatches at every sampled frame. Original files stayed unchanged.
The prior pre-world bridge trace also matches all 978 RAM/framebuffer/input
samples exactly (`artifacts/pc-world-baseline-comparison.json`), so this richer
read-only observer did not alter that original execution.

**Native presentation:** replaced the invented grid with original static geometry
outlines. Source WLD entry offsets keep instance identities stable across slot
reuse. The original PC executable alone governs movement and combat; the authored
vehicle is still a calibration model. `artifacts/pc-world-viewer-01.log` records
native capture and graceful exit zero; `artifacts/pc-bridge-viewer/paired-view.png`
was visually inspected. `artifacts/pc-world-godot-01.log` and the updated
`artifacts/pc-live-godot/report.json` prove actual process-pipe delivery of geometry,
37 static objects, continuous movement and helper exit zero. This work and its
visual review were performed by the same root agent.

**Aggregate gate:** `artifacts/validation-20260926T230149Z/results.txt`, terminal
exit zero. All nine checks passed, including 83 Python tests, source preservation,
1,093 authored simulation checks, 512 original-bearing outputs, nine new Godot
world-view checks, geometry, audio, playback teardown and runtime smoke. The
original-CPU oracle and live replays remain separate explicit gates. After the
report schema/evidence-text update, 21 focused decoder/shape tests also passed. No optional
Impeccable linter is installed/configured; native rendered inspection was used.

**Limits:** this is an elevated wire survey of allocated static objects and all
primitive lists. It deliberately remains outside the main gameplay application.
Original camera, visibility/occlusion, LOD/material selection, dynamic geometry,
physical units, mission/campaign outcomes and timing calibration are unfinished.
It is not a completed mission, remaster or release. Nothing was pushed/published.

Next evidence-led renderer targets: `0b4d:0412` establishes camera pose and matrix;
`0b4d:1684/1776` builds the candidate list; `0b4d:2867` selects geometry roots;
`0b4d:0541` applies face rejection and materials. The mission-entry RAM has camera
position `[2048,2048,50]`, identity matrix diagonal 16384, center `[159,61]`,
projection shift 7 and near value 16. DS `8dd2` counts 14 candidates at DS `6f58`,
compared with 37 allocated static objects. These are observed fields and code
leads, **not yet a validated camera/visibility bridge**. Preserve that distinction.

## Original camera bridge, 27 September 2026

The architecture discussion was a status checkpoint, not a source milestone.
The completed camera implementation and original-instruction checks are now
recorded in `pc-camera-research.md`. Protocol 2 sends the original crew camera,
primitive-ID geometry and original static face masks. Godot's view now uses that
camera rather than an elevated survey or authored vehicle.

Receipts: `pc-camera-oracle-05.json` (1,133 matrix vectors, 598 integer
projections, 151 static-object selections, 508 root-threshold cases);
`pc-camera-godot-03.log` (233 points, maximum 0.063590 source-pixel error);
`pc-camera-live-godot-02.log` (protocol-2 integration and exit zero);
`pc-camera-replay-01/report.json` (978 samples twice, matching original RAM and
video). The pre-camera RAM/video/input baseline also matches. The ten-stage
aggregate gate passed at `validation-20260926T232721Z`, with 87 Python tests.
Native capture `pc-camera-viewer-02.log` passed and was visually reviewed by the
same root author; the preceding unexplained exit-1 attempt remains recorded.

Camera sampling is explicitly not atomic: sample 464 catches a transient
100-unit player displacement and changed height while the drawing cache retains
its previous pose. The decoder preserves the original drawing cache. Old
UI-clip metadata and two misleading movement capture filenames are documented
as superseded in the camera research note. Dynamic vehicles, solid occlusion,
materials, timing calibration and full gameplay parity remain open.

## Vehicle arithmetic and actual renderer hooks, 27 September 2026

Recovered original vehicle orientation matrices, staged packed-vector rotation
and register-dependent matrix composition. `pc-vehicle-oracle-01.json` checks
2,280 orientations, 915,705 packed lookup words (5,985 coefficients) and 1,920
compositions. A synthetic original-CPU witness proves that incoming CX affects
yaw-specialized arithmetic. The running executable contains the same instructions.
No conventional engine rotation was substituted.

Built an unmodified baseline and a read-only instruction-observer variant from
pinned DOSBox Pure source `73e03aa145e0549ed4d5a20f8e65532714da33f5`. The old
nightly save state failed the native format check in both builds; the logs remain.
Bootstrapped the original game afresh, with a verified 3,600-frame fixture builder.
The default nightly core, its original save state and the working Godot bridge
are unchanged. Explicit alternate binary and source-state hashes are required
for the experimental backend; state-format checks remain in force.

`pc-render-hook-comparison-03.json`: 180 original input frames on source baseline
and traced libraries, zero RAM/framebuffer/input differences. The traced run
captured 45 complete drawing passes, 66 vehicle contexts and 5,341 exact original
vertex-cache matches. Godot recorded-pass replay checks 5,243 projected vertices
(maximum 0.000062 source pixels). Its first failed check was a root-viewport
scaling error in the test harness, repaired with a dedicated SubViewport and no
tolerance change. Full detail, scope and retained failures: `pc-vehicle-research.md`.

This is source-built renderer observation and recorded-pass replay, not a live
vehicle renderer or full raster/occlusion match yet. The next integration must
pair complete render passes with original video boundaries. No assets or binaries
were published. The whole remaster goal remains active.

Validation: eleven aggregate stages passed in `validation-20260927T000739Z`,
including 95 Python tests and original-file preservation. Default live bridge
integration passed in `pc-core-pin-godot-01.log`. Native captured draw replay
passed in `pc-draw-pass-native-01.log`; the author inspected its output. Final
classification/projection tests and the repeated source-baseline comparison
passed after separating dynamic allocation from the static arithmetic shortcut.
The optional Impeccable linter remains unavailable; native Godot rendering and
projection checks provide the applicable visual evidence here.

## Live source renderer and EGA scanout attribution

The optional `PC Bridge.command --trace` viewer now renders observed static and
dynamic original geometry live. Protocol 3 carries a drawing pass attributed to
the original scanned EGA page and the exact submitted host framebuffer slot.
The default nightly/static bridge remains intact. The extracted collector has
bounded live history; sprite/opaque commands are explicitly counted rather than
inheriting stale previous-object matrices. Startup/unsafe page associations clear
the Godot geometry instead of substituting another pass.

The 180-frame source-baseline comparison still has zero original RAM/video/input
mismatches. Of 175 paired presentations, 152 lag the newest completed original
draw pass, confirming that newest-pass selection would be incorrect. All 5,341
observed original vertices retain exact cache agreement. Native process-pipe
integration passes the existing controls/movement/braking/turn/fire checks and
renders vehicle polygons; native side-by-side capture was inspected by its author.

A subsequent 1,167-frame profile matches source baseline and trace in every
RAM/video/input record and every decoded end-of-stage state. All four crew
stations, driving, braking, turning, firing and world rebasing pass ten explicit
checks. There are 261 original draw passes, 34,444 exact vertex-cache checks and
33,551 Godot projection checks (maximum 0.003906 source pixels). Seven sprite-root
draws remain unsupported and explicitly recorded. See
`pc-scanout-controls-comparison-01.json` and `pc-scanout-controls-projection-01.log`.
The default nightly bridge separately retains passing live integration evidence.

Eleven aggregate validation stages and 102 Python tests passed in
`validation-20260927T003103Z`. Source-build anchor and mistyped hash failures were rejected by existing guards,
retained and corrected without weakening the checks. Full scope, source hooks,
receipts and launch instructions: `pc-render-sync-research.md`.

This advances live presentation integration. Solid surfaces, original material
patterns, clipping/opaque drawing, high-resolution replacements and the full
mission/campaign/release outcome matrix remain open. No content was published.

## Filled original surfaces and materials, 27 September 2026

The optional source-built tandem viewer now renders filled original static and
dynamic geometry, sky/ground boundaries, EGA material patterns and the actual
remapped game palette. `--wire` retains the diagnostic view. Original painter
order is preserved in one triangle stream with depth testing disabled. The PC
executable still executes its own renderer and remains the sole gameplay
authority. Godot's fractional clipping and edges never feed simulation state.

The original span instruction oracle passes 10,240 cases, with 3,276,800 checked
pixel positions. Native Godot tests pass palette RGB, source-coordinate dither
phase, painter order and sky/ground checks. The updated tracing core matches the
retained unmodified baseline in all 1,167 input/RAM/video frames and all 23 stage
states. All ten four-station/control checks pass. All 261 recorded passes render
without surface warnings and retain 33,551 passing projection checks, maximum
0.003906 source pixels. The seven known sprite-root omissions remain recorded.

Live filled integration passes with 15 paired samples and 161 vehicle polygons.
The first native capture timed out on a draw notification after its samples
completed. Explicit main-thread drawing/synchronization fixes capture without
advancing PC frames or extending the deadline. Its OS scheduling cause remains
unverified. The successful paired image was inspected by its author. Exact RGB
matches at 24,219 of 24,832 source-pixel centre samples in that scene; missing
HUD/reticle/target-box drawing and integer-edge differences remain, so this is
not full raster parity. Retained images, failed/successful logs, custody pins
and commands are detailed in `pc-surfaces-research.md`.

All twelve aggregate stages pass in `validation-20260927T005801Z`, including 107
Python tests and original-file preservation. No content was published. Sprite
and opaque commands, integer raster coverage, original cockpit/HUD, replacement
art, full missions/campaign, timing calibration and release work remain open.

## Original bitmap effects integrated, 27 September 2026

Decoded all 64 `EFFECTS.BMP` images and checked 28,960 pixels and transparency
masks against the original loaded EGA buffers. Local native PNG samples and a
contact sheet are in `local-art/pc-effects-v1`, with provenance and the captured
palette. These are exact original extracts, not yet remastered artwork.

New read-only hooks observe the original bitmap selection, projected position,
clipping and completion. Godot emits masked source-pixel runs at the correct
position in the original painter stream. All seven formerly missing sprite
draws in the four-station profile now render. The full 1,167-frame trace and all
23 stage states still match the unmodified source baseline; this scenario has
no unsupported commands. Other sequences and opaque four-byte commands remain.

The independent original bitmap-blitter oracle passes 512 cases and 32,768,000
framebuffer-pixel checks, including clipping and untouched backgrounds. Its
initial far-return harness failed; the verified scope stops before RETF after
checking restored SS/SP and does not claim return-transfer correctness. Native
Godot passes 57,546 exact RGB samples across all 64 source effects, transparency,
clipping, palette/material separation and painter order. A non-EGA dark-grey
probe failed separately (17 became 12; 51 became 50). This discrepancy remains
an explicit high-resolution material acceptance item, with the failed log kept.

All 261 recorded passes replay with seven sprites and the existing 33,551
projection checks. Three source-frame/attributed-pass pairs were captured and
inspected by their author. Five of 89 opaque sprite sample positions are black
in the source reticle region; the Godot view still lacks the original HUD.
All thirteen aggregate stages and 113 Python tests pass in
`validation-20260927T012101Z`. Detailed proof, limitations, hashes and commands:
`pc-sprites-research.md`. No content was published; the parent goal remains open.

## Original cockpit/UI composition, 27 September 2026

Added a read-only EGA bit-provenance observer and scanline-sampled UI masks to
the same original-core presentation stream. Godot now draws the paired world
under the original cockpit, reticle, target box, instruments and messages, with
explicit full-original fallback when attribution is unavailable. Pixels outside
the paired main camera, including the commander's map, remain original. This is
temporary source-resolution UI, not finished high-resolution artwork.

The first mask prototype retained scenery rectangles around transparent cockpit
bitmaps. Original-driver inspection identified CPU read/modify/write ORs outside
the VGA raster-op register. Observing the loaded preservation mask for the
duration of that blit fixes those edges while leaving all original operations
intact. The compiled observer passes 4,096 hardware-mode combinations and
2,048,000 bitmap-provenance pixel comparisons. The final four-station run's
1,167 input/RAM/video records and 23 stage states equal the unmodified source
baseline, with 261 complete passes and no unsupported commands in this scenario.

The first native composition test's retained-UI checks passed, but its world
coverage was inadequate. Visual review found blank commander/cupola scenery.
A controlled one-draw test reproduced the viewport-order defect. Nesting the
world viewport under the composition viewport fixes it without extra PC frames
or redraws. The extended test passes 3,648,005 native RGB checks, including all
659,422 replacement-world sample positions and the five original reticle pixels
that covered effects in the preceding sprite milestone. All four station
captures were inspected by their author. The failed/insufficient receipts remain.

All 14 aggregate stages and 117 Python tests pass in
`validation-20260927T015107Z`; the subsequent viewport-order repair is covered by
the single-draw native regression. Live pipe integration passes with 15 paired
draws/UI masks and graceful child exit. Full evidence, pins, limitations and
commands are in `pc-ui-research.md`. No content was published. The overall goal
remains active.

## Native cockpit assets and first material study

Exported seven original full-screen PC plates and all seven `STRUTS.BMP` images
with a reproducible local extractor. All 16,024 strut pixels and masks match
loaded original memory. Full independent plate-loader parity remains unverified.
The focused seven tests and extraction receipt pass; `local-art/pc-ui-v2` is the
canonical extraction, with the exploratory v1 inputs preserved.

Two built-in image-editor studies of the gunner plate are saved at 1586x992 in
`local-art/pc-ui-remastered`, with exact prompts and measured receipts. Both
failed the authoritative aperture-geometry gate and remain uninstalled studies.
After a targeted revision still gave the wrong vertical bounds, equivalent
prompt retries stopped. Integration must use exact renderer-owned apertures and
instrument layout, with generated art supplying surface treatment. Dynamic UI
semantics, erasure and modal coverage still need separation before a static plate
can replace original UI pixels. See `pc-ui-art-workflow.md`. No new artwork was
silently substituted into the proven tandem path.

## Original cold boot and mission reentry, 2026-09-27

Nell explicitly approved the tandem architecture: "Tandem it is, proceed."
The default `PC Bridge.command` now cold-boots the original through START, BRIEF,
SIM and END. The old snapshot/static paths remain explicit diagnostics. The
original owns menus, motor pool, quit choice, debrief and second mission entry.
Godot uses full original pixels outside attributed battle views.

The read-only session tracks the active DOS PSP/MCB, checks executable anchors,
waits for matching SHAPE.TBL, detaches callbacks on program changes and creates a
fresh rendering epoch for reentry. Freed resident SIM code cannot authorize a
render. Trace protocol is now 4. The keyboard preserves top-row digits, keypad
and arrow identities; eight mapping cases pass, and original up/right match
keypad 8/6 in decoded state and framebuffer in the driver probe.

A real fixture flaw was found: RAM-only mission restore omitted the disk overlay.
The source snapshot's SHELL selected resource 6, while the pristine ZIP selected
1. Quitting the restored mission with an empty overlay produced the wrong
Mass Destruction summary. The same inputs with the source disk overlay restored
Wilson's debrief. The cold-boot flow keeps the original disk writes together and
shows the correct Mossel summary. Saved-session packaging must include both RAM
and disk state; historical within-mission traces do not establish this contract.

The first lifecycle script inherited the shortened RAM-only debrief sequence and
failed to reenter SIM under cold boot. The failed artifacts are retained. The
corrected script includes the original debrief screen. Independent cold boots
also had different starting RAM and some video frames, so none were claimed as
non-interference evidence. The pinned core reads host time. The definitive
comparison uses one neutral START snapshot before any input or overlay changes.

Verified receipts:

* `artifacts/pc-lifecycle-baseline-02/report.json` and
  `artifacts/pc-lifecycle-trace-02/report.json`: 7,267 identical paired full-RAM,
  framebuffer and input records; 52 matching stage states; identical START,
  BRIEF, SIM, END, START, BRIEF, SIM boundaries; fresh epoch 2; zero sampled
  unsupported drawing commands; quit mask covers all 64,000 pixels.
* `artifacts/pc-session-native-02/report.json`: actual cold boot through Godot's
  pipe, 52 stages, nine paired worlds, 3,328,000 exact RGB checks, no failures,
  helper exit zero. Menu/modal pixels match the source and world pixels match
  the corresponding Godot viewport. This is not world-raster parity.
* `artifacts/pc-session-live-integration-01.log`: existing snapshot control
  regression still passes with 15 paired draws/masks and 161 vehicle polygons.
* `artifacts/pc-arrow-identity-01/report.json`: original arrow/keypad equivalence
  for the tested driving directions. No claim covers all keyboard layouts.
* `artifacts/validation-20260927T023626Z/results.txt`: all 15 aggregate stages
  pass, including 127 Python tests, eight original-key mappings, reference
  preservation and the existing simulation/audio/runtime gates, exit zero.

`artifacts/pc-default-boot-native-01.log` verifies the new default launcher
through a 26-sample capture into the original SIM, with cockpit composition
enabled and exit zero. Its side-by-side capture and native lifecycle screenshots
were visually inspected. The original cockpit/menu artwork is still source-resolution.
High-resolution art installation, event-driven remastered audio, complete
missions/campaign/save coverage and historical pacing remain open. No publication
or original-source modification occurred. See `pc-live-bridge.md` for reproduction
commands, exact boundaries and the preserved failed probes.

## Dark-colour material correction, 2026-09-27

Nell requested continued work. The previously recorded non-EGA dark-grey defect
was reproduced across 1,280 native swatches: 390 failed before correction.
Version-matched upstream shader inspection identified the lossy approximate
unshaded sRGB round trip. A bounded float lookup correction in the Compatibility
material path now passes all 1,280 exact RGB samples. Source images are untouched;
other renderers bypass this path. Native EGA, 57,546 bitmap pixels and 3,648,005
UI-composition RGB checks still pass. The complete 16-stage gate passes in
`artifacts/validation-20260927T024842Z/results.txt`, exit zero.

The correction covers nearest-filtered unshaded swatches on the tested M1 Max /
Godot 4.7.2 path. It does not establish lit/interpolated high-resolution texture
fidelity or cross-platform results. Version changes require the native gate.
`pc-surfaces-research.md` records source links, failed baseline and exact receipts.

## Original cockpit provenance and material pilot, 2026-09-27

Nell's continuation authorizes the tandem remaster, with original PC logic and
renderer still running. No publishing, external upload or original-file changes
were performed. Local art from the preceding approved studies is reused unchanged.

The original packed-plate driver now has an independent 42-case instruction
oracle covering all seven extracted plates, both EGA pages and three chunk sizes.
Live file-loader tracing verifies all four crew-station plates and STATUS.BIN.
A separate conservative all-plane provenance mask tracks surviving source plate
pixels through subsequent UI writes, transparent bitmaps and page copies, then
follows actual scanlines and the completed host buffer slot.

The first recorded material test failed because JSON float arrays did not compare
equal to the identical integer palette constant. Component-wise validated numeric
comparison fixes it, with a wire-round-trip regression test. The first cold-boot
viewer then exposed missing provenance through the original CPU dissolve.
That exact driver is now observed and independently tested. Its untouched pixel
at (312,199) was discovered and preserved rather than silently repaired.

`PC Bridge.command --gunner-art` enables the new local gunner-surround pilot.
Only proven material pixels above row 123, outside the PC camera, may change.
The lower instrument panel, reticles, messages and other stations stay original.
Missing metadata, art, matching source fingerprint or supported palette disables
the pilot. Default launch remains the source-resolution comparison view.

Final evidence:

* `pc-plate-oracle-01.json`: 2,688,000 original packed-driver pixels;
  `pc-dissolve-oracle-04.json`: 128,000 dissolve pixels, both page directions.
* `pc-plate-pixels-02.json`: 482,370 surviving plate pixels across 30 captured
  samples exactly match original source pixels and palette.
* `pc-plate-ownership-comparison-02.json`: all 1,533 original input/RAM/video
  records and stage states equal the unmodified source baseline.
* `pc-plate-lifecycle-03/report.json`: all 7,267 input/RAM/video records, 52 stages
  and original program boundaries equal the same neutral-start baseline through
  mission quit, debrief, menu and reentry.
* `pc-plate-art-native-03/report.json`: 2,771,432 exact RGB checks pass; 172,484
  source samples acquire new materials while protected pixels remain original.
* `pc-gunner-material-viewer-02`: real cold-boot pipe and native Godot viewer,
  both world and material composition enabled, 33,620 source plate pixels
  verified, clean exit, final side-by-side capture visually inspected.
* `validation-20260927T093036Z/results.txt`: all 17 stages pass, including 137
  Python tests and original-source preservation, terminal exit zero.

Full commands, current core/header pins, failing probes and scope are in
`pc-ui-art-workflow.md`. The implementation and visual review were performed by
the same assistant. This remains a partial material restoration. Other stations,
fonts/instruments, high-resolution world assets, event-driven remastered audio,
full mission/campaign/save coverage and historical pacing remain open. The parent
goal stays active.

## Original-event audio pilot, 2026-09-27

Continued under Nell's approval to use the original PC as authority. The native
observer now reads the original sound dispatcher, sound gate, engine parameter
and reload completion. The sound/voice layer has no keyboard-driven firing or
replacement combat rules. Read-only trace event 25 feeds a bounded once-only
queue with original frame and SIM epoch custody.

The opt-in `PC Bridge.command --audio` pilot maps accepted cannon, coax and smoke
requests to existing newly synthesized sample files, with the selected generated
“On the way!” and “Smoke out.” takes. Original F5 and pause stop playback. Impact
and menu requests have bounded callsite mappings; their native acoustic coverage
remains unproven. Engine/turret loops, warnings, radio, the complete PC dialogue
catalogue and music remain open. Original reload completion is recorded without
a bark pending readiness-display timing. Bearings retain digit-wise speech.

Evidence checked directly by the implementing assistant:

* `pc-audio-comparison-02.json`: all 12 checks pass. 2,091 frames of RAM, video,
  inputs and stage states match the unmodified source-built baseline exactly.
  113 original events include three accepted main-gun shots, one coax and one
  smoke request. An extra fire input while loading is rejected without an extra
  sound. A muted accepted shot still consumes its original ammunition.
* `pc-audio-native-01/report.json`: 1,050 actual original frames through the PC
  child and native Godot audio. Two cannon samples, one coax and one smoke sample
  played; one muted cannon stayed silent. Four F5/pause gates, zero errors,
  child exit 0. Generated speech uses the existing selected samples. No mixed
  audio was recorded; this establishes machine playback rather than mix approval.
* `pc-audio-lifecycle-01/report.json`: all 7,267 frames, 52 stages and program
  boundaries still match the original boot/mission/debrief/reentry baseline.
* `pc-audio-unit-01.log`: 38 Godot assertions, including actual sample/voice
  startup, duplicate suppression, stale research batches, epoch transitions,
  malformed packets and playback drain. Six additional Python tests cover
  source-qualified cues, gate state, invalid reload events, queue limits and
  session delivery custody.
* `validation-20260927T095432Z/results.txt`: all 18 gates pass, 143 Python tests,
  preserved source files, terminal exit 0.

The implementation and review were performed by the same assistant. Native
viewer research captures deliberately suppress sounds older than six emulated
frames when a single diagnostic command fast-forwards hundreds of frames.
Interactive one-frame delivery is tested separately. Current pins, exact commands
and remaining coverage are in `pc-audio-research.md`. No new external generation,
publication, upload or push occurred. The full remaster goal stays active.

## Original sound-channel loops, 2026-09-27

Extended the original-event audio pilot with engine and turret loops. Source
ownership comes from the original sound interpreter's channel timer, program
cursor, tone period and amplitude. Keyboard or vehicle-state heuristics are
absent. The original turret deceleration tail is retained. A separate newly
synthesized two-second turret sample accompanies the existing turbine sample;
all 16 prior effect/voice WAVs stayed byte-identical.

The implementing assistant also performed the review. It found two in-scope
faults and retained before/after evidence: mute stops were omitted from the
transition log, and the shared engine player treated compressed QOA byte length
as a 16-bit PCM frame count. The latter truncated each two-second loop at 19,432
frames. Both engine and turret now loop at the full 96,000 frames; regression
tests inspect actual imported resources. The range's shared player is fixed too.

* `pc-audio-loop-oracle-01.json`: unchanged original dispatch/interpreter routines
  execute for 3,744 ticks in each of PC-speaker and Tandy modes. All 14 case
  checks pass, including starts, release, parameter change, stops and rejecting
  unrelated channel occupants. Live Tandy coverage remains open.
* `pc-audio-comparison-03.json`: 18 checks pass, 2,091 RAM/video/input/gameplay
  and original sound-channel states match the unmodified baseline.
* `pc-audio-native-04/report.json`: 1,692 original frames, 3,386 native loop
  activation/pitch comparisons, 130 active turret frames and 370 muted-loop
  observations. Correct full sample endpoints, four engine periods, F5/pause
  stop/resume receipts, five played one-shots including one impact, zero errors,
  child exit 0. The muted accepted cannon shot stays silent.
* `validation-20260927T101153Z/results.txt`: all 18 stages pass, 146 Python tests,
  52 Godot audio assertions, original source preservation, terminal exit 0.

Current runtime is still an opt-in presentation pilot. Radio/warnings, original
message-linked dialogue/readiness, subtitles/mix controls and music remain.
PC-speaker arbitration and old waveforms are replaced by authored timbres and a
modern mix; original gameplay and loop ownership are retained. Human listening
approval and historical pacing are not established. Full details and both repair
receipts are in `pc-audio-research.md`. The parent goal remains active.

## Original fonts and visible crew text, 2026-09-27

Recovered all five original fixed-cell font files and selected-font identity.
The original character-driver oracle passes 3,912 blits and 1,025,507,328 complete
plane-byte comparisons, including the original signed-comparison quirk rejecting
nine stored 8X8 glyphs. The initial failed expectation and corrected proof remain
in `pc-font-oracle-01.log` and `pc-font-oracle-02.json`.

Added read-only original string-entry/return hooks and `presentation.text_runs`.
Source glyphs must match the completed native EGA rectangle; that entire rectangle
must then match the actual presented RGB pixels on the same original scanout
page and buffer slot. Unknown, overwritten or erased runs are omitted. Original
rendering continues, and Godot still displays the source text unchanged.

* `pc-text-parity-01.json`: 18 audio/control parity checks, 2,091 frames exactly
  equal to the untouched core. All 372 text calls match source glyphs; READY,
  TRACK and LOAD visibility is proven separately.
* `pc-text-crew-comparison-01.json`: 12 checks, 1,308 frames and all stage states
  exactly equal; original empty-smoke warning visible for 134 frames, absent
  after erasure. Twenty-four saved source crops match the runtime RGB hashes.
* `pc-text-lifecycle-02/report.json`: all 11 checks pass, 7,267 frames and 52
  stages equal to the original lifecycle baseline. The first comparison failed
  on a mistyped baseline filename; corrected, then rerun to terminal exit 0.
  The capture now checks baseline readability before emulation.
* `pc-text-native-01/report.json`: updated core through actual Godot playback,
  1,692 frames, 3,386 loop comparisons, unchanged one-shot/mute counts, zero
  errors, full loop endpoints and child exit 0.
* `validation-20260927T104409Z/results.txt`: all 18 stages, 158 Python tests,
  52 Godot audio assertions, terminal exit 0.

All three observed reload completions precede the first visible READY label by
three frames. This confirms why the remaining readiness bark must wait for the
presentation boundary rather than merely watch the RAM loading flag.

The implementing assistant reviewed these changes and visually inspected the
original crew-warning frame. Live radio text and hit-bearing suffixes remain
unexercised, although their source callsites are identified. No high-resolution
font, caption replacement, additional bark or whole-game parity is claimed.
The full remaster remains active. Exact boundary and reproduction instructions
are in `pc-text-research.md`.

## Loader voice after visible readiness, 2026-09-27

Connected the existing generated “Up!” performance to the original reload plus
source-frame visibility boundary. The source reload records a text-draw barrier;
a strictly newer, pixel-verified READY label can qualify one voice-only event
within six emulated frames. New fire, SIM exit, timeout, mute and stale delivery
remain suppressing conditions. No original state, timers or sample bytes change.
The local audio envelope advances to schema 2, with source/draw/hash validation.

* `pc-readiness-comparison-01.json`: 23 checks, all 2,091 RAM/video/input and
  original sound-channel observations match the untouched baseline. Three
  qualified readiness receipts, each three frames after completion; one muted.
* `pc-readiness-native-02/report.json`: 1,712 actual PC frames through native
  Godot, two loader voice starts and one muted load, three paired READY proofs,
  3,426 loop checks, unchanged existing effect counts, zero errors, child exit 0.
  The first test ended exactly at the final reload instruction and failed its
  overly early third-bark expectation. Twenty extra neutral frames cover the
  subsequent display update; the gate was not weakened.
* `pc-readiness-lifecycle-01/report.json`: all 11 checks, 7,267 compared frames,
  52 stage states and program boundaries equal to the original baseline.
* `validation-20260927T105237Z/results.txt`: all 18 stages, 165 Python tests,
  77 Godot audio assertions, terminal exit 0.

The implementing assistant reviewed the integrated source and reran these checks.
Coverage remains bounded to the exact visible READY path. Other readiness labels,
crew/radio/bearing dialogue, human listening, end-to-end display/audio-device
latency and the wider remaster remain open. The existing loader sample is the
Gemini 3.1 fallback; this work made no additional generation/network request.

## Original visible crew dialogue, 2026-09-27

Recovered once-only identity at the original crew-message setters and coupled it
to complete source-pixel-verified prefix/suffix display. Original simulation and
rendering still execute unchanged. Queued text cannot become a caption or voice
before all parts appear together. The public bridge audio envelope is schema 3.

Fourteen new dry Gemini 3.8 Flash TTS performances are installed: five observed
hit bearings and nine damage reports. Orus is the authored voice for original
portrait index 3, whose named role is not yet recovered. Bearing words are spoken
one digit at a time, including zeroes; captions retain the original numerals.
The first transcription's separated numeric formatting failed the strict word
gate. A separate blinded phonetic question recovered all five correct literal
three-word sequences. Both checks and generated WAV hashes are retained. Nine
damage lines passed the first transcription. Human listening remains open.

Verification performed by the implementing assistant:

* `pc-crew-comparison-01.json`: all fourteen checks pass. Every one of 8,576
  original RAM/video/input/queued-message records equals the untouched baseline.
  Seventeen assignments yield sixteen complete visible reports and sixteen
  once-only voice events from fourteen assets. Repeated 041 reports remain
  distinct. The never-fully-visible COAX-destroyed assignment remains silent.
* `pc-crew-crop-verification-01.json`: all 28 saved PNG prefix/suffix crops match
  their independently recalculated RGB hashes. The incoming 043 frame was viewed.
* `pc-crew-native-01/report.json`: 8,576 original frames through native Godot,
  sixteen actual generated stream starts matching the parity trace, fourteen
  voices, zero errors, original END transition and child exit 0.
* `pc-crew-lifecycle-01/report.json`: all eleven checks, 7,267 identical frames,
  52 stage states and identical original program boundaries.
* `validation-20260927T112933Z/results.txt`: all eighteen stages, 181 Python tests
  and 150 Godot audio assertions. The later reusable number-classifier test is
  separately covered in `pc-crew-python-final-01.log`: all 182 Python tests pass.
* `pc-crew-regression-native-01/report.json`: the prior 1,712-frame native
  firing/loader/motor/gate fixture still passes, with 3,426 loop checks, three
  visible-readiness receipts (two audible), zero errors and child exit 0.

The first synthetic grouping test had the suffix rectangle six pixels too far
left. Actual source capture established x=190 for the 24-character prefix; the
fixture was corrected without weakening the grouping check. Failed logs remain.
The current new trace header is `97798516834b2cfd97f00458f6fbf5743df17e593d569964f15cc3f7ef63a2b8`;
core `9c63ca3140bc5063767da0a5b3e8ec9a6e4a5cd92d18d445b699b39739dbaaee`.

No mixed game recording, guest-memory edit, push, upload of proprietary files or
publication occurred. Authored scripts went to Google for the requested TTS;
generated samples went back for blinded QA. The mission snapshot's disk-dependent
debrief outcome is outside this fixture. Radio entry points have source evidence
but no observed live radio message yet. Full bearing/dialogue coverage, listening
and mix approval, physical audio/display timing and the broader remaster remain
open. This milestone does not close the parent goal.

## Four-station cockpit materials and verified struts, 2026-09-27

The user-approved tandem now has opt-in high-resolution material donors for all
four original stations via `--cockpit-art`. Three new built-in imagegen outputs
under `local-art/pc-ui-remastered/cockpit-set-v1/` join the existing gunner study.
PC extracts control geometry; Genesis images provide style only. Original masks,
source fingerprints and protected instrument rectangles retain live information,
visibility, text and original modal transitions. Exact prompts and provenance
remain local beside the ignored generated PNGs. Human art approval is open.

The first integration exposed a real first-plane provenance loss on plate changes
and missing source attribution after original STRUTS redraws. The observer now
retains incoming known bits on origin conflict. New read-only bitmap entry/return
observations verify the original descriptor, pixels, placement, clip and completed
page before claiming host-only provenance. Unmapped or ambiguous draws remain
original. No guest logic, timing, memory or original rendering was replaced.

Evidence: `pc-cockpit-comparison-03.json` matches all 2,214 RAM/video/input frames
and 21 stage states with the untouched core, covering four stations and STATUS.
414 verified strut draws account for 551,098 source/completed pixel instances.
`pc-cockpit-pixel-proof-03.json` checks 641,384 plate pixels independently.
The per-bit oracle passes 4,096 operations and 20 explicit cases.
`pc-cockpit-art-native-04/report.json` passes 2,102,889 native checks, including
protected original pixels and high-resolution detail. Existing gunner native
regression passes 2,309,888 RGB checks. `pc-cockpit-lifecycle-01/report.json`
passes all eleven checks with 7,267 identical frames and 52 stage states.
`validation-20260927T120418Z/results.txt` passes all nineteen stages, 188 Python
tests and 150 Godot audio assertions. Actual commander cold boot and driver/cupola
viewer captures compose the correct station material and exit cleanly.

The implementing assistant also performed the source and visual review. Some
original flat/dithered fragments, all instruments and fonts remain source
resolution. This is material restoration with bounded replay evidence, not full
cockpit, world-art or mission parity completion. Failed first captures and the
corrected test expectation are retained. Current core pins, reproduction commands
and exact boundaries are in `docs/pc-ui-art-workflow.md`. No publication occurred;
all other open outcomes remain active.

## Visual correction following Nell's review, 2026-09-27

Nell flagged the EGA-looking world and mismatched gunner/driver overlays. The
first pass's parity and pixel-protection results did not establish finished
visual restoration. The world had retained the PC diagnostic colours, while
static material attribution omitted the driver's procedurally redrawn assembly.

The bridge now defaults to high-resolution cockpit donors with colours read
from the actual verified Genesis CRAM extraction. `--original-art` restores the
original diagnostic; `--pc-colours` retains new cockpit materials with PC world
colours. This is a source-based colour pass; remastered terrain/vehicles remain
unfinished. The gunner donor is fitted to the PC sight rows, with explicit
texel-centre sampling. Original sight geometry and information remain unchanged.

Read-only observation of original main-CS `5ba1..5da3` now attributes the fixed
lower driver struts and turret-relative roof writes. Each qualifying pixel
retains its original horizontal offset at scanline time. The full 527-byte
routine matches the unpacked, relocated executable. No original simulation,
rendering, memory or timing is replaced. The native driver view now has continuous
materials, and the original turret control/A alignment moves them appropriately.

Final observer receipts: `pc-driver-assembly-proof-03.json` matches 1,257 frames
and 19 stages, checks 218,484 assembly pixel instances and both turn directions.
`pc-cockpit-comparison-05.json` matches all 2,214 frames and 21 station/modal states.
`pc-driver-assembly-lifecycle-02/report.json` passes all eleven checks, 7,267
matching frames and 52 stage states. Gunner alignment passes 2,309,888 native RGB
checks. `validation-20260927T124323Z/results.txt` passes all twenty stages,
189 Python tests and 150 Godot audio assertions. Default cold boot, explicit
original-art opt-out and the final driver/gunner native viewers exit cleanly.
Failed test fixtures and the one-texel sampling failure are retained, diagnosed
and repaired. Current pins, remaining limits and further native receipts are in
`docs/pc-ui-art-workflow.md`. The same assistant implemented and reviewed this
revision; Nell's final art approval and the full remaster remain open. Local only.

## World-anchored grass and road detail, 2026-09-27

The preceding goal turn made verified progress on cockpit fit and default colours.
This continuation adds two built-in image-generated detail donors, retained
unchanged locally with prompts and hashes. The default tandem now maps them onto
the original ground and seven selected static shape/primitive pairs. Genesis
colours, triangle vertices, material identities, painter order and silhouettes
remain authoritative. Actor colours alone never select terrain detail. The
original quantized camera and continuous world origin anchor texture placement;
the original flat ground background receives a presentation-only plane mapping.

The source receipt verifies all seven selected shapes and their flat vertices.
Across 292 recorded passes, the geometry/material/data checks pass. Native GPU
tests check actual terrain-only changes, protected original UI and analytic
texture coordinates under translation/rotation. The 21-stage aggregate gate in
`validation-20260927T130747Z` passes, including 189 Python tests, source-file
preservation and 150 audio assertions. Current receipts and precise boundaries
are in `docs/pc-terrain-art-workflow.md`.

Actual live cold boot enables detail; `--flat-world` retains the preceding view.
Their final original framebuffer and decoded state match, but independently
cold-booted full-RAM fingerprints differ. This is a retained failed comparison,
not a parity pass. Two viewers restored from the same original snapshot have
identical full presentation metadata including the render RAM hash, state and
framebuffer; all eight shared-state checks pass. The core remains unchanged at
`f7452d08d9fb1bdf3f7cf73ddc1870bbe8c62192b01c8251d38a0e90a990baa3`.

The first native fixture omitted separately stored mask PNGs and fell back to the
original frame. The corrected fixture requires successful composition before
claiming UI protection. Failed receipts remain. The implementing assistant also
reviewed the source and native images; human motion/art acceptance remains open.
Other terrain, vehicles, buildings, trees, effects, instruments, complete mission
parity and release packaging remain unfinished. Local only; the parent goal stays
active.

## Pixel-verified live typography, 2026-09-27

The preceding terrain milestone was verified progress. This continuation expands
read-only source text observation from four semantic calls to all 49 main-segment
calls to the same original string wrapper. Generic numeric helper calls retain
separate page/coordinate candidates. Blank clearing draws are verified and
remove labels. Existing crew identity, readiness and speech rules remain intact.

Godot now independently decodes the fingerprinted original font and checks every
source pixel and complete UI ownership before drawing scalable IBM Plex Mono
inside the original cells. Unknown, overwritten or scenery-bearing text stays
original. The default tandem enables this; `--original-text` is the opt-out.
The same assistant implemented and reviewed the change. Native gunner/driver
captures were inspected with the existing remastered materials and terrain.

The unchanged-core routes match 19,365 recorded RAM/video/input frames, including
station/modal, smoke-warning, incoming hit/damage and original mission exit/reentry. Two native
fixture suites pass 5,577,448 assertions with zero errors. The live gunner
on/off comparison changes 5,434 pixels, all inside the ten verified text boxes,
with identical original RAM fingerprint, state, framebuffer and world rendering.
The 22-stage aggregate gate passes 192 Python tests and 150 audio assertions.
The first aggregate run correctly failed a hardcoded test width; the corrected
source-derived width passes and the failed receipt remains. Blank-draw handling
was separately repaired and recaptured. A native crew test against an older
observer reference rejected changed draw-sequence numbering; a fresh trace
passes all original baseline checks and all 1,849 audio events match after
normalizing only that observer counter. The unchanged strict native crew test
then passes all 8,576 frames and sixteen calls from fourteen generated clips,
with zero errors and child exit zero. Exact receipts, current core pins and
coverage limits are in `docs/pc-text-research.md`.

Static bitmap instruments/labels, text over scenery, complete fonts/dialogue,
mission outcomes and release packaging remain unfinished. No historical timing,
full-game parity, human art approval or publication is claimed. Local only; the
parent goal remains active.

## Genesis-first restoration, 2026-09-27

Nell clarified that Genesis artwork takes precedence wherever available. The
default tandem now loads five fingerprinted Genesis-only material illustrations,
covering all four stations and STATUS, rather than the previous PC-first studies.
Original PC camera, UI ownership, live values, layout and drawing offsets remain
authoritative. Nine unchanged gunner illustration cells now use remastered donor
regions; original overwrites reject the entire affected cell. Twenty-two fixed
label candidates and six STATUS numeric wells require exact original glyph/pixel
agreement before scalable redraw. A single write into the STATUS tank schematic
preserves that complete original schematic, avoiding a misleading pristine tank.

Native-08 passes 11,944,300 checks across 21 recorded station/status frames and a
synthetic damage overwrite, with exit 0. The actual moving-driver fixture reports
10,537,279 checks and no errors. The legacy native renderer passes 4,096,017 checks
and exit 0. Cold-boot captures show the new default art. A shared-state comparison
matches the prior build's complete presentation/state, original framebuffer and
world image while changing the composite. Precise receipts, including lost
terminal-handle boundaries on two earlier runs, are in
`docs/genesis-cockpit-integration.md`. The tracing core remains unchanged at
`537c524451028b5b5a2952901a40fc2abbf8a5af77adb5e8caba792d2fd7b024`.

Native review caught duplicate gauge framing, driver registration drift and a
white STATUS texture. Component registration and a lossless two-row texture
atlas repair those observed faults. Native probes now check actual STATUS artwork
in addition to protected pixels. A mistaken missing-fixture invocation exposed
a broken test that could print zero failures after a script error; explicit
argument/path/structure rejection now returns exit 1. Failed receipts remain.

The Genesis catalog now additionally includes exact STATUS, two Wilson poses,
four crew portraits, and six ammo/armament information pages. Twenty recorded
frames reconstruct all 1,433,600 pixels exactly. New selected local illustrations
include the second Wilson gesture, four crew portraits and AX/SABOT ammunition.
The HEAT revision was rejected by the image tool's output safety filter; its
coarse candidate remains excluded. No alternate bypass was attempted. The crew
information whole-page study was rejected for layout drift and added boxes.

`Play.command` now launches the original-PC tandem; the authored range has a
separate `Calibration Range.command`. Art Review now forwards capture arguments
instead of silently opening an interactive window. A launcher unit test verifies
all three dispatch paths, spaces and forwarded arguments without running a game.
The inadvertently opened review window was closed normally through its own UI;
no process was killed. The new gallery contains fifteen comparison pages.

The same assistant implemented and reviewed the art/code; this is not independent
art acceptance. The final 23-stage gate in
`artifacts/validation-20260927T174003Z/results.txt` passes, including **198 Python
tests**, original-file preservation, 31 typography checks and 150 audio checks.
The fifteen-page native gallery exits 0 with thirty 1440x810 PNGs, audited in
`artifacts/genesis-art-review-v5/capture-audit.json`. The public Play launcher
cold-boot run `pc-genesis-play-boot-01` also exits 0. The optional Impeccable
linter is absent; no dependency was installed, and native render checks provide
the visual evidence. `docs/graphics-coverage.md` retains the entire all-graphics scope,
including the distinction between gallery assets and live bindings. Dynamic
gauges, reticles, maps, remaining portraits/animation, all informational/menu
flows, world models and effects remain unfinished. Local only. The parent goal
remains active; this milestone does not close it.

## Genesis-first live crew portraits (2026-09-27)

The four selected Genesis crew derivatives now have a presentation-only live
binding in `pc_portrait_art.gd`. The PC FACES data supplies exact source identity
and transparency samples only; no PC illustration becomes a visual donor.
`extract_pc_portraits.py` proves all 10,696 pixels and original preservation-mask
bits against four unique loaded EGA plane blocks. Its local catalog and all four
Genesis images are hash-pinned. Partial, overwritten, ambiguous, non-UI or
unrecognised portraits retain the original; menu/fallback transitions clear art.

Native `pc-portrait-native-01` covers all four identities synthetically and 35
recorded source frames: **39,757,118 checks, zero errors, terminal exit 0**.
The real gunner is visibly restored. `pc-portrait-loader-native-01` adds the
original loader bearing-043 hit report, **5,965,113 checks, zero errors, exit 0**.
Every pixel outside original face coverage is checked unchanged, and independent
bilinear donor probes verify the selected Genesis image. The author performed
this visual review; no independent human acceptance is claimed.

`pc-genesis-crew-live-02` runs the actual bridge and shows the Genesis gunner,
cockpit and nine illustrated cells together. `pc-genesis-crew-original-01` runs
identical original inputs with `--original-art`. Both exit 0; their complete PC
state/program/presentation and original framebuffer bytes match. The remastered
composite differs as intended. The receipt is
`pc-genesis-crew-presentation-comparison-01.json`. A new optional `--capture-ui`
flag in the existing dialogue recorder stores paired masks. All 2,500 original
RAM/video/program/input records match the prior same-core trace in
`pc-portrait-loader-trace-comparison-01.json`; this is not new uninstrumented-core
parity evidence. No trace core or guest binary was changed.

The first snapshot probe retains the PC cockpit because no source-plate
provenance survives restoring that old snapshot. Switching stations through the
original controls supplies fresh provenance. This limitation and the bridge's
one-frame offset from the standalone recorder are documented, rather than
concealed by accepting unproven pixels. Native regression
`pc-genesis-cockpits-portrait-regression-01` still passes **11,944,300 checks**.
The complete source gate `validation-20260927T180807Z/results.txt` passes all
**24 stages**, **200 Python tests**, 37 portrait checks, and original-file
preservation, with terminal exit 0. The optional Impeccable linter remains
unavailable; native captures and pixel checks cover this Godot surface.

Details and repeatable commands are in `genesis-portrait-integration.md`.
Live commander/driver evidence, additional poses, coarse source-mask edges,
front-end/information bindings and the remaining whole-graphics register stay
open. Proprietary samples/art remain ignored and local. This is a verified
portrait milestone, not completion of the remaster or its active parent goal.

## Genesis office, Wilson and visible briefing text (2026-09-27)

The default Play/tandem path now replaces matched original BRIEF and END office
scenes with the Genesis-derived office and three corresponding character
performances. A new 1293x1217 RGBA facepalm image was made with the built-in image
generator from the selected Genesis character, preserving the original PC pose
meaning. It is an authored variant, not a claimed extraction of a native Genesis
facepalm frame. Its source, exact prompt, dimensions and hash remain in the local
asset sidecar. No original executable/core was changed or uploaded.

The local recognition catalog composes the original OFFICE/CO resources at
measured coordinates, with the actual bright-red BRIEF palette. Complete RGB
prefix hashes above a verified original dialogue border select the scene. An
altered pixel, partial border, unknown pose or wrong program retains the original.
The dialogue renderer uses exact original 8x8 glyph patterns, unique character
lookup and a second complete line check. No queued text or inferred string is
used. Every uncertain line remains original; all controls and timing stay with
the PC executable. The office restoration and typography clear on state changes.

`pc-frontend-native-01` preserves every dialogue pixel with text restoration off,
**8,148,958 checks, zero errors, exit 0**. `pc-frontend-native-02` tests combined
art and text, **6,825,954 checks, zero errors, exit 0**, across 19 captures and 12
eligible recorded frames (four each of the three poses). Independent donor/alpha
probes and original-pixel checks cover registration, overwrite rejection and
unknown-state fallback. Native live Play captures show the facepalm and speaking
poses. The paired original-art run has identical original framebuffer bytes and
program/presentation packets, recorded in `pc-genesis-brief-comparison-01.json`.
BRIEF has no active SIM state, so this is not full-RAM/all-mission parity evidence.

The complete gate `validation-20260927T183539Z/results.txt` passes **25 stages**,
**203 Python tests**, **109 frontend checks** and original-file preservation,
terminal exit 0. Cockpit/status regression still passes **11,944,300 checks**, exit
0. A missing frontend fixture exits 1. The first headless prototype failed to
compile because PackedByteArray has no sha256_text method. The existing
HashingContext pattern fixed it; the new gate has a quit bound and requires an
explicit completion marker. The failed receipt is retained, not counted as a pass.
The optional Impeccable linter is unavailable; native visual evidence was inspected
by the same assistant that authored this work, not an independent reviewer.

A stop request is pending for that first failed, idle headless test (PID 87427,
exec session 39692). Do not signal it or its shell without the requested approval;
recheck its exact identity before any approved cleanup. Subsequent tests and all
live captures have completed. This pending cleanup does not block other local
restoration work.

Details: `genesis-briefing-integration.md`. The complete graphics register remains
open: other Wilson/animation variants, motor-pool and information bindings,
remaining gauges, world objects and effects still require work. Local only.

## Genesis motor pool and original arming menu (2026-09-27)

The selected donor is now `motor-pool-v2.png`, a 1586x992 built-in image edit
of only the Genesis scene and its earlier Genesis-derived remaster. Clean ink
contours replace v1's enlarged stairs/dither; both versions and the exact prompt
remain local. SHA-256 is
`3fb46798b867ca528f96e8bc0a70d6f3a9e7a1016ca87f3e8549562469019c76`.
The gallery and live PC frontend use v2. No original resource was modified.

The loader begins before a safe observer attachment. The initial additive tag
change therefore passed replay parity but correctly restored nothing. A bounded
caller-frame recovery plus exact 64,000-index readback at ATBASE loader success
now bootstraps host-only provenance. Later UI writes remove it. Internal domain
9 maps to transport ID 8 without taking the moving driver's domain 8. The first
new export build lacked a visibility annotation and the capture failed; the
corrected build exports the callback, which refuses calls outside its scoped
readback window. Source/core details are in `genesis-motor-pool-integration.md`.

The Genesis background is live behind the PC's irregular clipboard, with no
rectangle guess or colour key. Seven visible text runs are scalable. Numeric
cells use the original font and numeric alphabet, avoiding its ambiguous O/0
and I/1 glyphs. Governor ON/OFF, red focus and white unfocused variants use exact
whole-run verification. Unsupported glyphs retain their original pixels.
The clipboard border/clip is still source-resolution; this family is not closed.

Verified receipts:

* `pc-motor-pool-trace-03` equals the unmodified source baseline for all 7,267
  full RAM/video/input records, 52 stage states and original program boundaries.
  Two complete readbacks and 428,072 attributed pixels pass separately.
* `pc-motor-pool-controls-baseline-01` equals the trace through 7,366 frames and
  58 stages, including real arrow-key governor selection/toggle and mission entry.
* Native art-only, art/text and control-state gates pass respectively 581,353,
  431,597 and 1,046,842 checks. Rendered outputs were visually inspected.
* `pc-genesis-motor-pool-live-01` is an actual Play launcher capture; its original-
  art comparator retains identical terminal state/presentation/source framebuffer.
* The new core retains exact original driver replay over 1,257 frames and 19
  stages; 218,484 moving-assembly and 364,645 static plate pixels pass.
* `validation-20260927T191709Z` completes 26 stages including 207 Python tests,
  original-file preservation, frontend, audio and runtime checks.
* Final focused motor-pool/office gates pass 158/109 checks after avoiding mask
  decoding when ATBASE is absent. Final native office and cockpit/status
  regressions pass 6,825,954 and 12,371,690 checks respectively. Optional
  Impeccable is unavailable; native rendering was used, with no linter install.

The older failed briefing test PID 87427 remains subject to the prior unanswered
cleanup request; it was not signalled. No new test process was left active.
No push, publication or proprietary-art redistribution. Parent goal remains open.

## Genesis arming-panel restoration (2026-09-27)

The complete verified PC clipboard now receives a scalable Genesis-style frame,
white lettering, grey heading and inverse selection. The PC owns all seven
source text cells, quantities, focus and key processing. All static clipboard
pixels and text must match before replacing the panel; partial/unknown drawing
falls back. One untraced intermittently overwritten bottom pixel is retained.
The original CLIP.BMP is recognition data only; Genesis supplies visual style.

Verified: the 7,630-frame allocation replay matches the original baseline at
all 74 stages, including HEAT 11 / SABOT 5 / AX 19 at mission entry. Source-plane
proof covers 9,944 clipboard pixels and preservation bits; attributed-plate
proof covers 1,647,444 pixels. The final native gate passes 95,050 checks across
27 motor-pool samples. Its headless companion passes 378 checks. Actual Play
capture source PNG, state, program, presentation and sample count exactly equal
the original-art comparator. Images were visually inspected by their implementer.

`validation-20260927T194023Z` completes all 26 stages and 208 Python tests. The
separate native office regression passes 8,148,962 checks, zero errors. Initial
panel runs failed two synthetic assertions because the fixture changed a pixel
without clearing its old provenance; corrected tests model the real UI write.
Failed receipts are retained. Detailed artifact pointers and source/catalog pins
are in `genesis-motor-pool-integration.md`. Optional Impeccable remains absent.

No original files, gameplay logic, emulator core or unrelated vehicle studies
were changed in this pass. The earlier idle test remains untouched pending
its unanswered cleanup request. No push or redistribution. Parent goal stays open.

## Genesis armament illustrations (2026-09-27)

Previous goal segment classified as progress: the arming panel changed runtime
presentation and produced terminal parity/native evidence. Continued with the
three extracted Genesis armament illustrations, using the built-in image tool.
Coax v2 is 2168x725; cannon and smoke v2 are 2172x724. All are local under
`local-art/genesis/remastered/armament-v1/`, with source/output hashes and exact
prompts in its manifest. The first versions are retained but rejected for
palette drift. Revised images use the extracted cyan/green/grey palette family.
No PC EGA imagery was used as a visual reference.

The gallery now has 18 comparison pages. Native source aspect is preserved for
these differently proportioned source crops. Both 18-page capture passes exited
0, and the final `genesis-armament-gallery-02` contains 36 saved native images.
Source/remaster images were visually reviewed by their author. The optional
Impeccable tool remains absent. These three assets are gallery-ready only;
original-PC information screen bindings, layouts, labels and variants remain.
No HEAT generation retry, public upload, publication or proprietary-art commit.

## Genesis information-page bindings (2026-09-27)

All seven original M1-Info pages were reached through ordinary PC keys. The
three-level menus need sufficiently long input pulses; diagnostic labels in
`pc-information-probe-01` through `07` describe attempted inputs, not always the
actual selected page. The final authoritative route is `information_steps()`
in `capture_pc_session.py`, mirrored by the tested native launcher fixture.
The PC START executable owns every transition and remains active throughout.

Five Genesis illustrations now bind to AX, SABOT, coax, cannon and smoke pages.
A full 320x175 content-prefix match is required, plus pinned original executable,
bitmap, recognition catalog and generated image hashes. Six native bitmap
instances verify 40,456 original pixels and preservation-mask bits. The first
full-frame hash gate failed six pages because row 175 retains variable pixels
from the animated menu. Direct comparison isolated every difference to that
untouched border row. Rows 175 through 199 remain original in every replacement.
Changed captions, partial draws and unsupported crew/HEAT pages also stay original.

Verified evidence:

* `pc-information-baseline-02` and `pc-information-trace-01`: every one of 5,749
  RAM/video/input records, all 72 stage states and original program boundaries
  agree. All seven information pages and their settled waits match their source
  fingerprints. The two raw report arrays were compared again directly.
* `pc-information-native-01`: 11,559,472 native checks, zero errors; all five
  illustrations, source-prefix/caption/image rejection, unsupported-page
  fallback, exact protected pixels and Genesis donor/filter probes. Native
  source and remastered screenshots were visually inspected by their implementer.
* `pc-information-headless-01`: 37 checks, zero errors. Focused Python catalog,
  route, session and launcher tests: 14 passed.
* `validation-20260927T202710Z`: terminal exit 0, all 27 stages pass, including
  210 Python tests, unchanged original files, frontend/audio and runtime gates.
* `pc-information-live-02` and `pc-information-original-live-02`: both actual
  Play captures exit 0. The receipt `pc-information-launcher-parity-02.json`
  confirms equal source PNG, state, program, presentation and all 60 samples;
  only the remastered composite has the active Genesis cannon illustration.

The first live/original launcher attempts failed the bridge's 600-frame request
limit at the 720-frame boot wait. The launcher now partitions such waits while
preserving their duration and key state. Both failed-01 logs remain. Their
corrected-02 terminal results and rendered image were inspected. No emulator
instruction, simulation rule, proprietary reference file or original input event
was replaced. Optional Impeccable remains unavailable; no tool was installed.
The earlier idle test PID 87427 was confirmed still sleeping and was not signalled,
respecting the pending unanswered cleanup request.

Details and reproduction are in `genesis-information-integration.md`. Typography,
outer frames, top-down weapon-location diagrams, complete crew composition and
HEAT art remain open. The existing AX/SABOT grid palette also merits comparison
against the sampled native Genesis palette before declaring those families
finished. The new armament v2 palette correction should guide that pass.
No assets were published or committed, and the whole remaster goal remains active.

## Genesis title animation and original PC credits (2026-09-27)

Nell asked whether animations, particularly the intro, had been restored. The
answer at that point was no for the intro: the title was gallery-only. This
continuation adds its live animation and credit sequence, with evidence in
`genesis-intro-integration.md`. The overall goal remains active and incomplete.

Implemented:

* Captured every PC boundary across 6,000 unattended frames and a separate
  1,800-frame early-space route. Both routes match the unmodified core's paired
  full RAM, framebuffer and inputs exactly, covering 7,800 records.
* Decoded the original CREDITS plate and four EXPLO.BMP poses; independently
  composed five complete title/flash frames, 320,000 matching RGB pixels.
* Extracted the four corresponding Genesis flash poses. Their VDP reconstructions
  match 286,720 pixels exactly. Source cutouts and manifests remain local.
* Generated a transparent 1448x1086 four-pose atlas using the built-in image tool.
  Its exact prompt and measured dimensions are retained beside it. The native
  preview was reviewed against the source, and the generated PNG is unchanged.
* Added 13 full-frame-gated compositions: clean title, four flash phases and
  eight credit cards. Credit text, metrics, colours and borders are native
  source-shaped meshes. START still owns order, timing, key response and exit.
  Unknown/partial frames retain original pixels; no independent timer was added.

Validation:

* `pc-intro-native-01/report.json`: 2,259,820 checks, zero errors beneath the full
  tandem renderer, including independent donor/alpha checks and every credit
  pixel at 4x. The headless suite passed 7,921 checks.
* `validation-20260927T214511Z`: 28 stages and 214 Python tests, terminal exit 0.
* The first separate cold-boot launcher pair reached different original frames,
  so `pc-intro-launcher-parity-01.json` correctly failed. No green parity claim
  was made from it. The diagnostic capture now uses the shared neutral START
  snapshot; ordinary Play remains a cold boot. Both final native launcher runs
  (`pc-intro-live-02`, `pc-intro-original-live-02`) exit 0. The nine checks in
  `pc-intro-launcher-parity-02.json` pass, including identical source PNGs and
  pixel-exact original-art fallback. This final diagnostic change was validated
  by those launcher runs after the aggregate gate, without repeating that gate.
* A 44.340459-second silent preview at `pc-intro-native-01/title-sequence-v2.mp4`
  assembles native renders with original holds. All transition timestamps and
  2,657 encoded frames are checked. It is not a real-time recording. The first
  encoding used a 25 Hz input clock and is superseded, with the reason retained
  in `preview-receipt.json`.
* Optional Impeccable is absent; native rendering/pixel tests cover this surface.

Remaining: publisher splash, moving 3D menu backdrop, other transition variants,
intro audio, human art acceptance, the other animation families, all remaining
mission/runtime parity and release requirements. No emulator, simulation or
original source files changed. Media/catalogs remain ignored; no publication or
push. The five pre-existing untracked vehicle-study files remain untouched.

Nell then explicitly requested a dedication to her father, David "Ming" Kenny.
The final intro credit now adds a lower-left memorial panel reading "Dedicated
to the memory of" and "David \"Ming\" Kenny", using the original 6X6/8X8 faces,
black field and matching red border. No original credit is covered or replaced,
and its duration remains the original final-card hold. This new authored text is
kept distinct from the original credit evidence. The intro capture accepts
`--capture-intro dedication` to verify the final card through the actual launcher.

## Source-driven speed, fuel and temperature (2026-09-28)

Continued after the roadmap-only turn, which added no implementation progress.
Nell's earlier tandem/Genesis-first authorization remains in force, with no
space-saving constraint imposed on this pass. The goal remains the complete
remaster, original PC gameplay, all missions/campaign/persistence and the local
release candidate; no publication, push or source redistribution is authorized.

Added vector speed bars in both applicable stations, commander fuel, and gunner
and driver temperature lamps to the existing instrument component. The visible
original pixels select every lit segment, colour and blink phase. Exact source
context, UI ownership, post-plate writes and original gaps must all match.
Unknown or partial content remains original. Geometry is confined to the proven
rectangles and follows the Genesis donor's clipped, lightly beveled cells.

The original-instruction oracle covers 1,332 cases and 349,175,808 VGA plane
bytes, including negative speed, narrowing overflow, both warning thresholds
and blink phases. It established the six-row endpoint-excluding bar raster.
Native tests cover every bar fill count and both warning colours/off phases;
507 applicable CPU-oracle outputs feed the actual Godot recognizer. Two-scale
native replay compares 56,576,000 pixels with zero errors. Original forward,
reverse, coast, brake and station sequences match baseline RAM/video/input for
1,608 frames. A captured speed 40 RAM value with only 18 visible strips proves
why the binding must stay presentation-driven. Fuel remained 100 and temperature
green in that replay; warning reachability is isolated-source/synthetic evidence.

Actual Play initially failed a 30-second response timeout. A direct host probe
measured a valid 300-frame request at 53.029 seconds; profiling located Python
per-pixel provenance scans. Replaced those scans with equivalent bulk byte
predicates, retaining all guards. Exhaustive byte-pair tests and full-mask
corruptions pass. All 22 replay report fields and 51 PNGs are identical before
and after the optimization. The unchanged Play capture deadlines then passed,
with both gunner gauges active and native output inspected. Failed evidence is
retained. No guest code, trace core, input or simulation rule was modified.

Final aggregate gate `artifacts/validation-20260928T010215Z`: 229 Python
tests and all 30 stages pass, exit 0. Reference files verify unchanged.

Evidence and reproduction: `docs/pc-gauges-research.md`. Actual captures and
receipts are under `artifacts/pc-gauges-*`. Optional Impeccable was unavailable;
no dependency was installed. The five pre-existing untracked vehicle-study
files remain untouched. This is local work only. Orientation, reticles, other
instrument variants, world art, audiovisual completion, mission/campaign/save
parity and release remain open. Orientation source notes exist at
`artifacts/pc-orientation-source-01/findings.md`; those static findings still
need root original-instruction/runtime verification before implementation.

## Open outcome matrix

1. **Exact PC simulation:** retain the original as authority rather than porting
   provisional rules. Live control traces now establish persistent motion on
   release and braking over time with keypad 5. Governor/heat/fuel, targeting
   probability, weapon class effects, damage, guided fire, smoke and AI remain
   unresolved. Current provisional numerical constants are labelled in data/docs.
2. **Eight PC missions:** containers and all static placements recovered; trigger
   execution semantics and matching
   start-to-end success/failure traces remain. No mission is marked complete.
3. **PC original runtime:** explicit `ABRAMS.COM EGA` startup is now verified.
   The raw framebuffer had correct colors while the OpenGL window showed a blue
   cast. Switching the running emulator to Surface corrected the displayed
   colors, confirmed by Nell. `.runtime/dosbox-x.conf` saves `output=surface`.
   Underlying OpenGL defect remains undiagnosed; source files stayed unchanged.
4. **Campaign/persistence:** original progression, scores, ranks and save format
   remain; the range's save/restore is separate developer functionality.
5. **Visual restoration:** Genesis-first material donors now cover all four
   stations and STATUS in the default tandem. Four crew portraits, another Wilson
   gesture and two ammunition illustrations join the first static collection in
   the gallery. Eligible crew portraits now bind to original visible crew messages,
   with native gunner and loader evidence. The office and three Wilson poses now
   bind to original briefing/debrief frames with exact visible dialogue decoding;
   the motor pool now has its Genesis background, verified scalable arming panel and
   text live, including governor/focus variants. Five information illustrations
   now bind to original START pages; the complete observed crew page adds its
   Genesis portraits and wireframe. The title now has four Genesis-derived flash
   poses and eight original-font credit cards, driven by complete PC frames.
   Publisher splash and moving menu backdrop remain original.
   Embedded information-page captions, frames
   and top-down tank schematics remain open. Other gallery families need live bindings. Nine gunner illustration cells and
   scalable pixel-verified live/fixed text are enabled; remaining cockpit trims,
   bitmap instruments/labels, scenery-bearing text, recognition art,
   Wilson animation, in-world models, effects and all
   UI states remain. Preserve PC information density and four-station controls.
   Grass and seven selected flat source surfaces now have world-anchored detail;
   this does not complete terrain or model restoration.
6. **Audio:** final voice performances, per-event coverage, mixing/listening,
   accessibility and source/licensing records remain. Direct native extraction
   replaces recordings as the asset source. Eleven WAV payloads (ten assets and
   one silence placeholder) match the ROM byte-for-byte; 25 FM patches and four
   native music containers are preserved. The 68-entry native archive is verified.
   Nine generative range voices are installed, with unchanged cues/caption words.
   Original-event cannon, smoke and visible-readiness calls now reuse three
   selected takes in the opt-in tandem audio pilot; F5 and pause retain authority. Fourteen additional Gemini 3.8 takes now cover sixteen fully displayed original hit/damage reports in the bounded incoming-fire trace, with source-message identities preventing repeats and hidden-text disclosure. Engine and turret
   loops now follow original interpreter state, including the turret release tail.
   Automated transcription matched the selected set after a revised 3.8 readiness
   take and a 3.1 fallback for the one-word loader call. Rejected takes are retained.
   No human listening approval, complete PC dialogue coverage or finished music
   arrangement is claimed.
7. **Release:** no production package, export templates or community publication
   approved; build reproducibility, target platforms and redistribution decisions
   remain. Source-only work can continue locally.

## Next bounded investigations

1. Recover logical update boundaries. Original camera transforms now have
   bounded instruction/projection evidence; current
   snapshots are VGA-frame-boundary samples; original UI drawing may lag them.
   Calibrate real-time input/CPU pacing against the standalone reference.
2. Recover remaining opaque drawing commands and integer polygon edge coverage.
   Solid geometry, original materials and bitmap effects now run under the
   original source-resolution cockpit/HUD in the scanout-paired renderer. Recover
   UI semantics and assets for a faithful high-resolution replacement. Expand live coverage beyond the three
   observed effect IDs. The unshaded arbitrary-colour lookup now passes its native
   gate; validate future lit/interpolated high-resolution materials separately. Evidence is in `pc-surfaces-research.md` and
   `pc-sprites-research.md` and `pc-ui-research.md`.
3. Extend original-executable replay coverage to station/weapon modes, enemy
   state, damage, mission outcomes and campaign/persistence, one scenario at a
   time. Current bridge receipts and limitations are in `pc-live-bridge.md`.
4. Continue the Genesis-first restoration register in `graphics-coverage.md`:
   bind restored static flows to original visible content, complete dynamic
   instruments, recover remaining portrait/effect variants, then restore world
   objects. Keep untouched extracts beside derivatives. Resolve the recorded
   image-tool HEAT rejection without silently substituting PC art or claiming
   that illustration complete.

No completed subtask closes the parent goal. No exact-gameplay or finished-remake
claim is supported by the current range and artwork milestones.

## Genesis effect resource recovery (2026-09-28)

The preceding goal continuation produced local checkpoint `f36b468`: overlapped
frame dispatch and 1,020-frame boundary comparison evidence. Its performance
results were mixed; it did not close stable pacing or the overall remaster goal.
This continuation returned to the Genesis-first graphics work rather than
continuing performance-only refinements.

Recovered the complete 64-entry Genesis effect bitmap directory at ROM 0x431be.
All 28,960 source pixel indices and masks match PC EFFECTS.BMP, independently
decoded, while ordinary gunner presentation uses Genesis palette bank 3.
The original Genesis blitter at 0x5988 passes an isolated M68000 oracle across
2,688 cases and 13,762,560 pixels. Two native impact frames reconstruct exactly
from VDP state and verify 43 visible effect pixels plus six sight occlusions.
No emulator source, original game bytes or gameplay code changed.

Corrected broken host capture provenance after repeated restores: old counters,
cached frame and input no longer survive a successful restore. Fresh repeat
captures both report frame 24 and have identical complete file hashes. The
earlier valid frame's image and VDP bytes remain unchanged. Earlier exploratory
button-probe counters and unhashed supplementary RAM dumps are labelled in
`genesis-effects-research.md`, not silently promoted into clean evidence.

Generated and self-reviewed initial impact/smoke studies through the built-in
image tool. Two atlas candidates lost source detail. Switching to isolated,
enlarged native references yielded cleaner individual frames 15, 16 and 17,
with exact prompts and hashes retained. They remain unselected pending animation,
footprint and runtime visibility checks. No new effect art was installed in
Godot, and this is not a completed graphics-family claim.

Focused tests: 19 pass. Original-instruction oracle: zero mismatches. Aggregate
gate `artifacts/validation-20260928T043521Z`: terminal exit 0, all 36 stages and
254 Python tests pass. Failed exploratory checks and their explanations remain
in `artifacts/genesis-effects-research-01/` and the research document.

Whole-goal outcomes remain open: all required high-resolution animation/art,
source-selected event/audio coverage, pacing, full mission/campaign/save parity,
and the reproducible release candidate. Continue with effect selection/timing
and complete animation sets before enabling their PC-driven bindings. Source
extracts and generated media remain ignored/local. No push or publication.
The five pre-existing untracked vehicle-study files remain untouched.


## PC-selected high-resolution impact integration (2026-09-28)

The preceding continuation produced source-recovery checkpoint `cff6041`, with
64 verified native Genesis bitmaps and three unselected art studies. This
continuation integrated those three individual donors across nine verified PC
impact bitmaps. The broader remaster goal remains active and incomplete.

The original `SHAPE.TBL` proves the three roots/detail variants for each of
shapes 183, 184 and 185. Runtime selection requires an observed original sprite,
exact source pixels/mask/dimensions/flags, matching shape/root/bitmap and known
ordinary palette. Original bounds, row padding, clips and ordered draw stream
own placement and occlusion. Unknown/thermal palettes or missing art retain the
original renderer. `--original-effects` provides an explicit comparison mode.
The three high-resolution images are selected in the local manifest; earlier
rejected atlases and all prompts, hashes and unchanged extracts remain retained.

Self-review: the implementing assistant selected and viewed these generated
images and the native Play capture. This is not Nell's art acceptance. Alpha
contours are redrawn, with an alpha-0.5 runtime cutout; original silhouette masks
are not preserved pixel-for-pixel. Tactical readability remains a review boundary.
There is no gameplay-state mutation, additional visibility query or effect timer.

Native Compatibility tests at 4x and 5x span 12,217,344 rendered pixels and
27,521 independent authored-colour samples, maximum RGB channel error one byte.
Outside-bound changes are zero; both painter orders, clips and original palette
fallback pass. Existing original-sprite regression passes 57,546 exact pixel
checks. All 261 recorded render passes retain their source packets and select
exactly the original seven observed impact draws. Full receipts and reproduction
commands are in `pc-effect-art-integration.md`.

Actual Play A/B captures stop on source effect 52 at original sequence 712. The
original image and source metadata match, and the 552 changed presentation pixels
remain inside the effect. Four UI-owned fractional reticle-edge pixels initially
failed a naive equality check. Their existing 80% sight/20% scenery blend predicts
both original and new RGB exactly; no unexplained UI changes remain. No reticle
code was changed to hide the comparison failure.

The separate 1,020-frame native input replay has identical requests, bridge
packet hashes, full conventional-RAM hashes and packed original-video hashes
with art enabled and disabled. Per run this audits 668,467,200 RAM bytes and
261,120,000 callback-video bytes, sequences 607 through 1626. Final source frames
and metadata also match. This is a bounded replay proof, not all-game parity or
whole-emulator-state identity.

An initial headless failure (`source animation sequence changed`) exposed a
false palette rejection: nested Godot array equality distinguished JSON floats
from constant ints. Per-channel numeric checks fixed it; the retained second
headless run passes 648 checks. Aggregate `artifacts/validation-20260928T050146Z`
has terminal exit 0, all 37 stages and 255 Python tests pass. The later test-only
native-scale option passed in the completed 5x run. Optional Impeccable was not
available; no dependency was installed. No original game, emulator or reference
files changed, and no push or publication was performed.

Remaining outcomes include the other 55 effect bitmaps and palette/overlay
families, remaining high-resolution world/UI/animation art, complete audio,
pacing, mission/campaign/save parity and a reproducible release candidate. Keep
the parent goal open. All five pre-existing untracked vehicle-study files remain
untouched; local source and generated media remain excluded from distribution.


## Genesis-coloured hillside restoration (2026-09-28)

The previous goal turn made substantive progress in local commit `87da9e3`:
three Genesis-derived impact phases now bind to nine original PC bitmap variants,
with native and 1,020-frame source-boundary evidence. The goal remains active.
This continuation addresses the enlarged checkerboard hills visible behind the
impact capture, advancing the unfinished world-art outcome.

Fresh Genesis turn captures expose the hillside at original bearing 078. The
frame reconstructs from VDP state with 71,680 exact pixels. Three interior probes
contain equal black and (172,170,0) swatches, establishing the olive source mean.
The built-in image tool generated a neutral terrain-detail image from that
selected reference; its unchanged 1254-square output, prompt and hashes are kept
locally. Only the selected image was submitted, never game binaries or workspace.

The runtime now resolves the dither and adds restrained world-anchored detail to
49 source faces across PC shapes 2 through 33. All roots and primitive/material
pairs are verified directly against pinned SHAPE.TBL. Seventeen vertical faces
receive source-fixed XZ/YZ projection; ordinary slopes use XY. Original triangles,
material identities, ordering and gameplay remain unchanged. Unsupported palettes,
source identities and missing assets retain the old renderer. `--original-hills`
allows a direct A/B comparison without turning off other remastered components.

Native final gate: 4,571,057 checks, zero errors, covering 4,838,656 rendered pixels.
All 4,490,887 pixels outside the selected visible hill faces are unchanged.
There are six visible cases and two fully occluded cases, plus 244 analytic slope
and 152 vertical-coordinate samples. A 20,000-pixel neutral-colour check, both
painter orders and exact unknown-palette fallback pass. All 261 recorded passes
retain geometry, material IDs and source packets. Evidence and exact failed-run
explanations are in `pc-hill-art-integration.md`.

The source test initially miscounted 50 faces instead of 49; source decoding
corrected the denominator. The first native/aggregate attempt failed on a test
Dictionary type inference error. The next native attempt incorrectly demanded
changes where the source hills were fully occluded. Original ownership masks
proved those two zero-change cases correct, and the final gate tests them
explicitly. Further source inspection exposed 17 vertical faces needing height
coordinates; that incomplete XY-only mapping was repaired and independently
checked before final acceptance. Earlier receipts remain retained as intermediate
or failed evidence rather than relabelled as final passes.

This work was generated, implemented and visually reviewed by the same assistant.
It does not establish Nell's visual/motion acceptance, all-map graphics coverage,
subjective tactical readability or finished high-resolution vehicles/buildings.
Whole-goal audio, remaining art/animations, pacing, full mission/campaign/save
parity and a reproducible release candidate remain open. Source files and the
five pre-existing untracked vehicle-study files remain untouched. No push or
publication is authorized or performed.

Final acceptance receipts: aggregate `artifacts/validation-20260928T053853Z`
completed with terminal exit 0, all 38 stages and 257 Python tests pass. The final
native effect regression passes 4,719,653 checks and the arbitrary-colour gate
passes 1,280 exact RGB samples. Actual Play A/B captures have identical original
framebuffers and metadata except the new surface counters; all 53,733 changed
composite pixels stay in the hillside region. Final native captures were viewed.
The final 1,020-frame replay has identical requests, complete packet hashes,
full conventional-RAM digests and packed original-video digests at every boundary.
Receipts: `artifacts/pc-hill-art-01/play-parity-final.json` and
`replay-parity-final.json`. This is source noninterference on that replay, not a
claim of finished gameplay parity across all missions. Optional Impeccable was
unavailable; native rendering was verified instead. No goal completion is claimed.

## Genesis model recovery and editable vehicle studies (2026-09-28)

The preceding goal turn made bounded verification progress: the corrected
cockpit passed a fresh 12,238,012-check native run and public-launcher capture.
The current continuation resumes the incomplete world-vehicle art outcome.
The overall goal remains active; `docs/GOAL.md` retains the PC-authoritative,
Genesis-first tandem scope.

Recovered 53 Genesis drawing programs, rather than treating their ROM bytes as
ordinary XYZ meshes. Control-flow traversal retains 1,423 distinct commands,
34 literal vertex blocks, nineteen references to shared replacement geometry,
and both procedurally constructed truck paths. Editable local exports include
53 full program JSONs, 54 OBJ pose unions, original materials and explicit
PC-polygon-to-Genesis-command correspondence. Original VM conditions and special
circle commands remain visible instead of becoming invented mesh semantics.

For 52 indices, all PC primitive-used coordinates and unique polygons match
Genesis definitions after the source axis conversion. There are 585 matched
unique polygons; one of the 52 records contains no polygon. Material bytes also
correspond as Genesis = PC + 16. The truck differs and is explicitly excluded
from an equivalence claim. No live renderer or original gameplay changed.

Original-instruction oracle `artifacts/genesis-model-research-01/oracle-02.json`
passes with read/execute-only ROM: 188 pointers and extents, 54 neutral poses,
528 construction commands, 221,184 workspace bytes, 62 control cases, 1,166
clipped polygon cases, 94 clipped line cases, 26 sorted call lists and 16 material
lookups, zero mismatches, terminal exit 0. This is synthetic source recovery,
not visible vehicle-frame, nontrivial depth-order or gameplay parity proof.

Created three Genesis-based editable Blender/glTF bevel studies, T-62, M1-A1 and
M113. Original colours, proportions and VM component boundaries are retained.
These are initial authoring foundations, with no new joints or detailed parts,
and remain disabled in live gameplay. The assistant created and visually reviewed
the studies, including native side/rear views; this is not Nell's acceptance.

Native final receipt `artifacts/genesis-vehicle-studies-native-02/report.json`:
580,234 checks, zero errors, terminal exit 0. All nine views import/render;
48,616 sampled model pixels show materials and 527,384 sampled outside pixels
retain the empty background. Measured axis expansion stays below the declared
0.45 raw-unit envelope. The first native run failed an unsuitable minimum-colour
quota; inspecting the actual frames established correct limited-palette models.
The repaired test checks independent geometry ownership, not extra colours.
The failed initial run remains retained. Earlier CPU exploration also failed
at the truck branch before its two construction paths were recovered.

Final aggregate `artifacts/validation-20260928T063107Z` completed with terminal
exit 0: all 39 stages and 269 Python tests pass, including twelve new model
tests and unchanged reference inventory. No dependency was installed. Research,
commands, limitations and local output pointers are in `genesis-models-research.md`.
The five pre-existing untracked PC vehicle-study files remain untouched.

Continue detailed Genesis-first vehicle surfaces and source-selected face
integration, then animation and remaining classes/states. Truck mapping, special
draws and visible original-Genesis comparison are still required. Whole-goal
audio, pacing, mission/campaign/save parity and release-candidate work remain
open. All source/derived media stay local; no push or publication occurred.

## First Genesis-derived vehicle surfaces (2026-09-28)

The immediately preceding response verified the already repaired cockpit and
showed a fresh matching Play capture. It did not advance the remaining art
families. This continuation makes implementation progress on the unfinished
vehicle outcome rather than repeating that cockpit gate. The whole goal remains
active and PC-authoritative; no replacement simulation is introduced.

Authored and integrated three high-resolution running-gear/side-armour panels
from the recovered Genesis T-62, M1A1 and M113 side views. Exact prompts, unchanged
PNGs, hashes and generation provenance remain under
`local-art/genesis/remastered/vehicles-v1/`. Six source faces now receive uniformly
fitted, perspective-correct texture coordinates in the PC's exact triangle stream.
Near-plane clipping, painter order, source vertices/material identities and
unknown-palette fallback are retained. Alpha changes detail strength only;
it never exposes another actor or creates new silhouette pixels.

The first native view revealed that the previous global world colour study used
its road grey for vehicles. Original Genesis model evidence establishes the
correct (65,68,65) shade. Six textured sides and seven other verified dark-grey
faces now use that model-specific colour. PC-colour mode remains (85,85,85).
No other model or arbitrary world surface is silently recoloured.

Native final gate `pc-vehicle-art-native-02` passes 19,783,292 checks with zero
errors and terminal exit 0. It checks all six sides at two scales plus near-plane
views, 261 original recorded draw passes, independent ray/plane UVs, both painter
orders, unknown palettes and 280,000 exact PC/Genesis grey probes. All 18,707,238
pixels outside the selected visible faces are unchanged. The close-up images
are isolated synthetic authoring views, not claimed reachable game positions.
The same assistant generated, implemented and visually reviewed this work.

The complete aggregate at `artifacts/validation-20260928T074431Z` passes all 40
stages and 273 Python tests with terminal exit 0, including source preservation.
Fresh native shared-shader hill/effect regressions pass 4,571,057 and 4,719,653
checks. Two actual 1,020-frame interactive-control replays have identical complete
source packets, conventional RAM digests and original packed-video digests at
every boundary. Their final view has no selected vehicle faces, so visible-art
evidence comes from the native fixtures rather than that unchanged final image.
The replay audit measured 31.10/34.40 fps, not sustained unaudited speed proof.
The actual public launcher capture also exits 0 and retains every prior metadata
field; one distant vehicle face changes exactly 30 pixels in a 6x5 region, with
the repaired cockpit unchanged. Its capture and comparison receipt are retained
under `pc-vehicle-art-play-remastered-01` and `pc-vehicle-art-play-parity-01.json`.

The initial test calls had two setup errors, then a gutter-extent assertion was
corrected. The first native run passed mechanical tests with the wrong road grey;
the final run includes the corrected model colour and explicit RGB checks.
Earlier receipts remain retained. Full details and reproduction commands are in
`docs/pc-vehicle-art-integration.md`. Optional Impeccable was unavailable and was
not installed. The five pre-existing untracked vehicle-study files are untouched.

Remaining work includes other vehicle surfaces/types/LODs and damaged states,
truck mapping, movement/animation and representative close-range gameplay review.
The whole remaster's other graphics, music/voice coverage, pacing, all-mission,
campaign/save parity and release-candidate requirements remain open. No broad
completion or artistic acceptance is claimed. Everything remains local; no push
or publication occurred.

## Playability priority, flat vehicles, full bearings (2026-09-28)

Nell rejected the vehicle texture panels and deferred replacement models. Their
live instantiation has been removed; existing authoring studies are preserved.
The current priority is playable original-PC flows with correct graphics and
audio. No original game files, CPU settings or game instructions were changed.
The same assistant implemented and reviewed this pass. The whole goal stays open.

### Completed local evidence

* `pc-vehicle-flat-play-01/verification.json`: public Play, 1,679 ordinary-input
  approach frames, zero textured vehicle polygons. Source frame, gameplay state,
  program, presentation/cockpit/instrument metadata and baseline frame records
  match the prior source route. The visible APC retains flat original faces.
* `pc-play-default-audio-native-01/report.json`: audio is now on by default.
  Original one-frame playback passes 1,712 frames and 3,426 loop comparisons,
  including cannon, coax, smoke, impact, loader and motor playback; zero errors,
  child exit 0. F5, pause, freshness, original-event and no-extra-information
  gates remain. `--no-audio` disables presentation audio explicitly.
* 355 additional full-sentence Gemini 3.8 Flash TTS masters complete bearings
  000–359, retaining the five existing takes and nine existing damage reports.
  All generated masters passed independent wording QA. `install_pc_bearings.py`
  checks complete batch/repair script custody, caption, WAV metrics, hashes and
  transcripts before installation. Re-running its dry-run verifies all 355.
  This uses generated dry samples, never mixed gameplay recordings or stitched
  number fragments. `pc_bearing_provenance.json` retains source/model/take hashes.
* Nell explicitly accepts “niner”. Both transcript and digit-delivery QA now accept
  that synonym within bearing/heading calls while rejecting wrong digits,
  omissions and compound numbers. Two initial niner takes had already been
  retaken; both earlier and selected masters remain preserved. No additional
  regeneration was performed after that clarification.
* `pc-full-bearings-native-01/report.json`: 1,680 packets from the real original
  child, one complete displayed bearing 058, exactly one matching stream start,
  zero errors and child exit 0. Godot unit checks load all 369 PC voice resources.
* `pc-all-scenarios-baseline-02` / `pc-all-scenarios-trace-01`: all eight original
  scenarios, all four stations, F5, pause/resume, cannon/coax/smoke inputs, quit,
  debrief and return to the original menus. All 54,657 paired RAM/video/input
  records and 561 stage states match; all 118 trace checks pass. HEAT decreases
  10 to 9 and coax 80 to 79 in all eight stage records. This does not cover mission
  victories, defeats or full campaign outcomes.
* `pc-all-scenario-frames-native-02`: all 32 recorded scenario/station packets
  pass through the actual production Godot renderer, 161 checks, zero errors.
  These images are a rendering replay; simulation parity is established by the
  separate original execution above. Review found a commander rail discontinuity.
  The compositor now eases its donor mapping around the heading opening. Only
  the eight commander surrounds change in an exact 32-image before/after
  comparison; see `pc-commander-frame-join-01.json`. The fresh native protected-
  pixel cockpit gate passes 12,238,012 checks with zero errors and exit 0 in
  `pc-playability-cockpits-native-01`.
* `pc-campaign-play-new-03` / `pc-campaign-play-continue-01`: real public Play
  creates PLAYQA, executes original Take R+R, closes, then a second cold-boot Play
  resumes it from the same original disk overlay. No RAM save state is restored.
  Its 50-byte PLAYQA.TC survives byte-identically, SHA-256
  `67a48985d2706258b7f94ff2cb4d8e2c213e6c932cea1d4d8e1268ff94bbbc54`.
  `pc-campaign-play-verification-01.json` passes seven save/resume/audio/render
  checks. Normal Play's existing save path remains unchanged. `--saves` allows
  a separate profile; an exclusive lock prevents two bridge hosts writing it.
  Original GAME/GENESIS paths are rejected as save destinations.
* Fixed missing Shift/Ctrl/Alt forwarding. The original Shift+3 command now
  cycles its speed index 0, 1, 2. Original scancode polling also selects AX;
  preserve that source behavior. `pc-modifiers-baseline-02` / `pc-modifiers-trace-01`
  agree on all 530 frame records and outcomes. Native keyboard/scheduler tests
  cover the modifier chord and release order. No emulation speed setting changed.
* Interactive launch/bridge failures now stay visible until the window closes.
  Captures still exit nonzero. Large diagnostic steps are divided into at most
  60-frame pipe requests, preserving every frame and held key. The 1,679-frame
  approach remains byte-identical after this transport-only chunking.

### Performance and validation

Profiling identified repeated loaded-font decoding and mask validation overhead.
An eight-entry immutable exact-byte font cache is used only after current loaded
bytes match the supplied resource catalog. Bulk byte predicates retain the same
mask rejection rules. The host caches one PNG only when every source framebuffer
byte and its dimensions/pitch match. State, audio and presentation metadata are
always fresh. `pc-playability-01/observer-parity/final-verification.json` proves
all 601 complete audit-enabled host packets byte-identical before/after; the JSON
stream SHA-256 is
`1046f10252ae6b9a7733902153e5d8a61665fc24f3c2629cdc3ec89f32be0c67`.

Initial 600-frame native probes measured 23.68, 53.41 and 48.10 fps during this
investigation. The final 1,200-frame stationary run measured 59.03 fps against
59.47 advertised by the core, mean interval 16.94 ms. Machine load varies;
per-change causal speedups and sustained moving-gameplay acceptance are not
claimed. No synchronization fence, source frame or input request was skipped.

`validation-20260928T091102Z` passes all 40 stages and 281 Python tests, including
source preservation, 522 Godot audio checks and 79 scheduling checks. This gate
precedes the final one-frame PNG cache, whose focused 14 Python bridge tests and
601-packet runtime comparison pass. Final aggregate/replay results are recorded
below when terminal. Optional Impeccable is unavailable and was not installed.

### Corrected diagnostic assumptions and remaining work

The first all-scenario harness incorrectly expected baseline audio metadata,
fixed-count END pages and persistent START mission selection. Original observations
corrected those expectations; failed receipts remain retained. Campaign capture
first used unsupported PackedStringArray.filter, then a fixed-page route selected
Continue instead of R+R. The final driver recognizes the exact original prompt,
uses ordinary keys, and validates its resulting program boundary. The first
modifier test wrongly expected Shift+3 to leave HEAT selected; the original
also selects AX and the corrected test preserves it.

`docs/playability-status.md` now names the finite verified flows and remaining
outcomes. Victory/defeat/progression, sustained pacing, remaining voices/warnings/
music and graphics, mix controls, listening/art acceptance and portable release
packaging remain open. Replacement vehicle models are deferred at Nell's request.
The five pre-existing untracked vehicle-study files remain untouched. Everything
is local only; no push, publication or proprietary redistribution occurred.

Final gate: `validation-20260928T092053Z` passes all 40 stages and 282 Python
tests, terminal exit 0, including the final PNG cache. A first attempted comparison
of native controls used the default 459-frame warmup against the old explicit
606-frame gunner warmup, so its source mismatch is not a regression finding.
That failed comparison is retained in `pc-play-final-controls-01/verification.json`.
The corrected `pc-play-final-controls-02/verification.json` compares the same
1,020 original input frames and all paired RAM/video hashes. Diagnostic chunking
changes pipe request IDs; those transport IDs are not gameplay parity fields.
The corrected moving replay passes all checks and measures 57.93 original fps
against 59.47 advertised, with default audio. Root inspected its native gunner
capture and the commander station image. Original smoke obscures the world in
the final gunner frame; the matched source framebuffer confirms this is gameplay,
not a missing-world rendering failure. The commander joins are continuous.

## Actual combat-loss flow and remaining damage voices (2026-09-28)

Authority remains Nell's playable-first request: flat source vehicles, PC-owned
logic, Genesis-priority presentation, sample-based effects and generative TTS.
“Niner is fine” remains accepted for individual bearing digits. Original GAME
and GENESIS files, default user saves and unrelated vehicle-study work are
preserved. No push, publication or proprietary redistribution is authorized.

### Original loss and native replay

Added `--combat-loss` to `tools/capture_pc_session.py`: ordinary original boot
inputs, then neutral combat until the original exits SIM, original END review
keys, main menu and a second mission. It never presses Q, restores midmission
RAM or manufactures an outcome. An 18,000-frame bound fails if END never occurs.
Two unit tests cover the route and its failure boundary.

`pc-combat-loss-baseline-01` and `pc-combat-loss-trace-01` compare all 15,122
original frame records, 187 stages, program boundaries and damage-exit flag
frames exactly. All 15 trace checks pass. Original DS:0cca becomes nonzero at
frame 11625, END begins at 12150, START at 12783, and the second SIM at 14638.
This is a genuine Mossel Defense combat loss, not a quit/debrief substitute.
The neutral START snapshot is SHA-256
`874330f12864965bbfdb5a57f52759bc8cadc78e2c90dc0a2dace3a840d09f53`;
each run has its own fresh disk overlay.

`godot/tests/test_pc_combat_outcome.gd` extends the actual production viewer and
host. `pc-combat-loss-native-03` passes 1,841 checks over 271 received packets and
all 187 original boundaries, terminal exit 0. Every received packet's complete
paired RAM/video agrees with the baseline-compared fixture. All original frames
execute, but diagnostic transport batches mean this is not 15,122 individually
rendered Godot frames or a sustained-speed claim. Default audio and flat vehicle
geometry survive END and reentry. Root viewed the damage, debrief, main-menu and
second-mission native images. Source colours, actual loss text, original menu
and a fresh high-resolution cockpit return correctly.

The first native test captured synchronously inside scene mutation, producing
white backgrounds and stale label placement even though the settled final frame
was correct. This was a test capture defect. Deferred capture now lets the scene
redraw without applying another packet. A follow-up test initially assumed an
original border probe was black; its failed receipt is retained. Final probes
compare exact original colours instead. No production renderer was modified
for these test errors. Native 01's image acceptance is superseded by 03.

### Additional generative damage samples

Recovered 24 damage captions using original isolated CPU instructions: nine
subsystem damaged/destroyed pairs and three mobility damaged/getting-really-bad
pairs. The 36-case oracle also proves 12 terminal-condition repeat suppressions.
The CPU fixture and reproducible oracle are committed. Subsystem selection is a
supplied isolated context; no claim is made about random hit distribution or
live occurrence of every caption.

Fifteen missing takes were generated with Gemini 3.8 Flash TTS and existing Orus
casting. All 15 blinded transcripts match. Dry 24 kHz mono 16-bit WAV masters
are installed unchanged with provenance. Runtime only adds this catalogue to
the existing two-part, speaker-3, IP-3dd2 visible-message route. No earlier speech,
new tactical cue, source mutation or mixed recording is introduced. Unknown
messages remain silent. Existing installer now supports a separate damage bank;
the original 14-take bank still verifies unchanged. Native audio passes 642
checks, including real stream/player starts for all 15 additions, exact imported
format/duration and once-only delivery. These are synthetic source-qualified
player packets, not proof every added report has occurred during live play.

Remaining outcomes: victories and other defeats, campaign progression, longer
sessions/pacing, other dialogue/radio/warnings/music, remaining art families,
volume/mix controls, listening/art acceptance and portable packaging. The goal
remains active and unfinished. Everything remains local only.

Final gate: `artifacts/validation-20260928T095017Z` completed all 40 stages,
286 Python tests and 642 Godot audio checks, terminal exit 0. The separate native
OpenGL audio run also passes 642 checks, and the original 14-take installer dry
run still passes. Source preservation and `git diff --check` pass. No production
visual layout changed in this pass; the native outcome images validate the
existing renderer and the repaired diagnostic capture timing.

## Presentation-only audio mix controls (2026-09-28)

Previous goal turn was progress: committed actual combat-loss parity and 15
additional damage takes. The goal remains active. This pass addresses the
explicit adjustable-mix requirement without adding cockpit artwork, textures,
gameplay hotkeys, pause commands or a substitute sound-state machine.

Implemented native Audio menu with master, effects, voices and motor controls,
10% increments/Off and default reset. macOS native menu occupies no game pixels;
other backends reserve a header outside the original 4:3 view. User choices use
separate Godot preferences, with visible load/save failure notices. Captures
ignore user settings and never write them. Gains apply immediately, source-gated
loops can resume, and old one-shots/speech never replay on user unmute. Original
F5/pause/epoch/failure gates retain priority. The range base class's new gains
are unity by default, preserving its independent mix.

Validated the actual production input loop with presentation menus open/closed,
including release-before-forwarding of a menu closing key. Native macOS UI clicks
set effects 40% and voices 70%, and persisted reload matches. The actual original
is frozen only for this diagnostic UI-acceptance boundary. It is not used to
claim real-time stepping while an OS menu is open. Godot MenuBar/PopupMenu APIs
were checked against official documentation; no new dependency was installed.

Evidence: `pc-audio-mix-native-02` compares all 1,020 original input/RAM/video
records with `pc-play-final-controls-02` during nine gain changes. All checks
pass. Four final rendered/source images are decoded-byte-identical. Native menu
receipt `pc-audio-menu-native-04` passes all 15 checks, terminal 0; root inspected
the fallback screenshot and real native accessibility menus. Native screenshot
capture was unavailable. Non-native fallback on macOS is not other-OS proof.

Initial native run exposed a real pre-ready player dereference, fixed by storing
startup levels until player construction. Its source comparison passed, but the
script-error run is superseded by native-02. Menu-native-01 inherited a too-short
diagnostic deadline. Menu-native-02's actual UI checks passed but switching an
already-native menu to local left a cached zero-size layout; the fallback test
now constructs its startup mode independently. Native-03 had a test-only missing
Dictionary annotation; native-04 compiles and completes. Failed receipts remain.
An extra project-manager instance opened while selecting an exited test app was
closed via its own native Quit menu; no unrelated Godot process was signalled.

Final aggregate `validation-20260928T101218Z`: 41 stages, 286 Python tests,
642 existing audio checks, 97 mix checks, 82 production scheduling checks,
terminal exit 0. Source preservation passes. Optional Impeccable is unavailable
and was not installed; native layout and actual UI interaction were checked.
The native mix route measured 47.53 fps versus the older matched 57.93 fps;
host load was not controlled, and sustained pacing remains an open gate.

Remaining goal outcomes are unchanged except adjustable volume controls are now
implemented. Music, wider speech/warnings, remaining graphics, victories and
campaign progression, sustained pacing, listening/art acceptance and portable
packaging are still incomplete. No push, publication or redistribution occurred.


## Exact instrument checks and sustained playback (2026-09-28)

Previous goal turn was progress, committed as `258349b`: persistent source-gated
mix controls. The whole remaster remains active, not complete. This pass addresses
playability/frame pacing without changing the original executable, timing, live
input cadence, game rules, source palettes or authored art.

Measured the current moving/station/firing route first. Native sample application
was expensive; repeated instrument checks took 4.83 ms and typography 4.07 ms.
Static icons and gauge surrounds now compare current source RGB/RGBA bytes and
L8 mask/tag bytes in native operations, rather than thousands of per-pixel script
calls. Guard complements cover exactly the old pixels. Mixed RGB/RGBA comparison
includes alpha; unsupported formats retain original pixel predicates, and colour
masks retain red-channel semantics. There is no cached validity or tolerance.
Dynamic gauge/state recognition and drawing are unchanged.

Focused tests pass 14,003 checks, including each icon pixel corrupted separately,
all mask byte values, alpha/mixed-format handling and exact guard coverage. The
source-instruction gauge oracle extension passes 14,939 checks. Initial test-only
image type inference failed and was repaired; its failed log is retained.

Native before/after evidence: `pc-pacing-cache-work-01/comparison.json` proves all
1,020 full source packets, original requests, final metadata and all four decoded
native/source images equal. Root visually inspected the resulting gunner frame;
this is self-review of existing artwork, not new user art approval. Repeated
instrument-check time was 4.83 then 1.96 ms. Overall rate was 20.04 then 30.17 fps.
Host load varied; these different-time timings are not a controlled causal claim.

Extended only the diagnostic profiler to support repeated control cycles with a
bounded length-aware deadline and per-frame original-program/audio status. The
six-cycle run `pc-pacing-sustained-01` exits 0 with 6,120 consecutive SIM frames,
134.84 seconds, all exact one-frame scripted controls, 25 delivered audio events,
healthy audio and zero textured vehicle polygons. The first 1,020 complete packets
match the retained prior route; remaining 5,100 audits are recorded without a
second original execution. Full long-route parity remains unproven. Sustained
rate was 45.39 against 59.47 target, with final segment 32.80. Target-rate
acceptance is failing on this loaded host; no timing substitution was made.

No unrelated process, original file, user campaign save or rejected vehicle study
was modified. No external upload, publication or push occurred. Remaining speech,
music, graphics, campaign outcomes, target-rate pacing and portable packaging
remain outcomes of the active goal.

Final gate `validation-20260928T103922Z` completes all 41 stages, terminal exit 0:
286 Python tests, 14,003 gauge checks, 642 existing audio checks, 97 mix checks and
82 scheduling checks. Reference preservation and `git diff --check` pass.
`pc-instrument-regions-stations-01` passes 161 native replay checks across all
32 scenario/station cases. Complete case metadata and all 39,321,600 rendered
pixels equal `pc-all-scenario-frames-native-02`; comparison receipt saved beside
its report. No visual styling changed, so no design linter was required.

Next measured performance surface is typography (3.36 ms in the after probe),
plus host/poll latency under varying load. Do not change historical CPU speed or
live input batching to meet a presentation benchmark. Wider goal outcomes above
remain required; this optimization and longer-run receipt close no aggregate
completion gate.


## Expected-glyph reuse and longer-route parity (2026-09-28)

Previous goal turn was progress (`1bc962e`), reducing instrument checks and
recording a 6,120-frame run below the core's target rate. This pass addresses
its next measured presentation cost, typography, while retaining all current
pixel, ownership, hash and event checks. No historical CPU/input/timing policy,
original font, outline contour, palette or game rule changed.

A bounded 64-entry expected-glyph byte store is keyed by exact font identity,
words and both colours, with complete actual font-byte equality before reuse.
Current source RGBA bytes and L8 ownership are compared in native operations;
current RGB hashes and metadata still qualify each individual run. A font reload,
including failure, clears expected bytes. Cursors and other source/mask formats
retain the previous pixel loop. No result/validity/run/event cache was introduced.

The test-only pixel oracle's complete verified_run function is byte-identical to
commit `1bc962e`. Focused comparison covers every printable character of all four
faces, each pixel of a warm text field, source alpha/formats, red-only mask
semantics, cursor exclusions and UI ownership, actual font mutations, bounded
storage eviction, current event identities, hashes and every palette pair.
Six alternating in-process batches initially measured about 14 us per new
verification versus 116 us for the prior loop, with no timing pass threshold.

Native short route `pc-typography-pacing-native-01` compares all 1,020 complete
packets, original requests, capture metadata and final decoded image pixels with
the previous instrument-only optimization. All match. Recorded rate is 59.61 fps;
repeated typography component cost is 0.66 ms. Other components also ran faster,
so these different-time process timings do not isolate a whole-game speedup.

Native longer route `pc-typography-sustained-01` completes 6,120 consecutive SIM
frames in 103.38 seconds at 59.20 fps versus 59.47 advertised, healthy audio and
all original one-frame inputs unchanged. All 6,120 complete packets, final
capture metadata and four decoded images equal `pc-pacing-sustained-01` (formerly
only its first 1,020 frames had a full packet comparison). Segment rates span
58.89 to 59.54. This is a near-target local sustained probe, not historical-machine
calibration, an arbitrary-load guarantee or complete campaign acceptance. The
earlier 45.39-fps run remains retained. No unrelated processes were controlled.

The whole remaster is still active and incomplete: remaining dialogue/radio,
music, graphics families, victories/campaign outcomes, longer/cross-machine
pacing and portable packaging remain. Work is local only, with no publication,
external upload, push or changes to original reference files or user saves.

Aggregate `validation-20260928T104953Z` passes all 41 stages on the final production
source, terminal exit 0: 286 Python tests, 185,967 typography checks, 14,003 gauge
checks, 642 existing audio checks, 97 mix checks and 82 scheduling checks. Native
32-station replay passes 161 checks and retains every one of 39,321,600 pixels
and all case metadata. Native menu replay passes 46,080,268 checks across 45
frames, 211 text runs. Root inspected the current joystick frame (self-review).

An attempted menu byte comparison with `pc-menu-text-native-02` failed. That
receipt predates the R/terminal refinement commit `07bcb77` (report UTC 23:54 on
27 September, refinement 00:25 on 28 September), so it is an invalid immediate
before/after baseline. The failure is retained at the new menu comparison receipt.
Added a diagnostic-only `--pixel-oracle` mode which substitutes the frozen prior
verifier into current frontend typography nodes before loading current sources.
This avoids restoring old code/assets in the working tree or trusting stale art.

The current-assets frozen-verifier native menu run completes with the same
46,080,268 passing checks. Its complete report and all 45 images (46,080,000
pixels) equal the optimized version; `pc-typography-menus-01/oracle-comparison.json`
passes all 47 comparisons. Original failed historical comparison is retained.
No production style/layout changed, so no design linter was required. Exact
before/after code diff, bounded cache lifetime and all current-source predicates
were reviewed by the implementing assistant.

Near-target local pacing is now evidenced for the full six-cycle route. Avoid an
unbounded optimization loop: the next material remaining lane is wider original
crew/warning/radio speech or mission victory/campaign acceptance, with historical
speed and cross-machine calibration still recorded as open requirements.
