# Local work ledger

## Bounded rehearsal and conditional campaign gate, 2026-10-13

Nell authorized one bounded opening rehearsal and one campaign combat attempt
only if the rehearsal passed. The gate requires an operational main gun and
mobility, with at least 80 integrity through the pre-bridge staging approach.
At frame 10933, after 5925 battle frames, integrity falls from 88 to 63. The
main gun remains partially operational (condition one), mobility conditions are
all 100, and objective progress is zero. Contact freezes execution at that exact
frame and cancels the remaining sight-sweep input. The gate fails; no second
combat is entered, and no victorious-save or winning cold Continue is claimed.

The original abandonment handoff is `01 01 00`. Original END writes an active
fifty-byte career with zero points. Cleanup then mistakenly selects Continue
instead of R&R and opens the next original briefing, "THE MOSSEL INTERCEPT",
"MISSION #2". The native process closes normally in BRIEF before another SIM
load. The misleading capture label `rehearsal-final-start` is retained as evidence;
its actual program is explicitly BRIEF. This error was disclosed in the chat.

The observer checks 1609 read-only loop diagnostics, 1679 original draw passes
and 101674 vertices without error. All 81 protected hashes, including the 68
original GAME files, remain unchanged; prior career seals are preserved. The
host-only own-system reporting change and verification were performed here.
Initialization uses the same pre-career checkpoint with a process-local
`Etc/GMT+12` October 12 date guard. No machine clock or guest date is edited.

Original Enter cycles eligible targets; L retains a selected target or selects
the nearest reticle candidate when none is selected, then locks. This distinction
is verified in the manual and original dispatch at `1edf`, `1f9e`, `35f4` and
`3646`. Its ability to prevent the observed incoming-fire failure is unverified.
The attacker was not identified through original TADS; no combat rounds fired.

Evidence: `artifacts/rea-victory-pilot-20261012/rehearsal-conditional-20261013/`.
Status: local only, rehearsal failed, conditional campaign combat held, victorious
save and corresponding cold Continue acceptance incomplete. No native job remains.
Working if: the failed health gate prevents a second battle, actual program
transitions override intended capture labels, and target-selection hypotheses
remain separate from demonstrated victory or tactical identification.

## Escape-controller revision and fourth attempt, 2026-10-13

Nell explicitly authorized one additional attempt after the previous three.
The task-local controller now freezes frame execution and cancels queued routes
at contact, preserving latched controls. It injects no automatic C, keypad 5
or settling frames. Ten native contacts demonstrate exact freeze frames and
zero automatic keys; the first moving escape resumes explicitly with throttle
preserved. Implementation and verification were performed in this chat.

The fourth attempt takes the static-map covered corridor, but loses its main
gun before reaching the Bridge. The original own-system condition is two,
nonoperational. Original "Abandon the M1" produces SIM.OUT `01 01 00` and an
active fifty-byte career with zero points, count one and status zero. After
normal closure, a fresh native process without RAM restore accepts that exact
career and opens "NUREMBURG HIGHWAY", "MISSION #2". This proves cold persistence
after failure; the requested victorious-save and victorious-Continue gates
remain unmet. No additional combat was entered during the cold check.

The live observer checks 2148 loop diagnostics, 2214 original draw passes and
146119 vertices without error. An accidental unfiltered state print exposed
allocated actor records; it is recorded explicitly. Subsequent routing follows
the previously selected static corridor, and the sight scan uses the public
crew hit bearing. Those actor records are not used to select or aim at targets.

Two initial replay pairs finish all 16217 frames but fail their actual-outcome
gate: they select scenario seven rather than the live scenario two. The native
serializer omits DOS date, and host local midnight separates live initialization
from those replays. Process-local UTC reproduces the original October 12 date
without changing the machine clock or guest state. A menu-only discriminator
then matches all 31 available live RAM, video-RAM and framebuffer milestones.
Corrected on/off replay matches all 16217 frames exactly in RAM, video RAM,
framebuffer, existing presentation, audio and original draw/slot/scanout pairing.
All 244 actual input milestones and the sealed save contents also match. The
replay retains 7967 presentations older than the latest completed draw; diagnostic
state never replaces their attribution. All 81 protected hashes, including the
68 original game files, remain unchanged. This correction is scoped to the
recorded initialization recipe; universal cross-day restore remains unproven.
No original game files or native core were patched.

Evidence: `artifacts/rea-victory-pilot-20261012/escape-revision-attempt-04/`.
Status: local only, requested victorious campaign acceptance incomplete; the
one additional authorized combat attempt is used.
Working if: contact freezes preserve escape controls, cold continuation of a
failed career is labelled separately from victory, and every replay reproduces
the actual initialization and original draw/slot/scanout attribution.

## Bounded REA campaign continuation, 2026-10-12

Nell authorized phases 1 to 5 with ordinary controls, read-only `0000:0e85`
diagnostics, unchanged original files and preserved draw/scanout pairing. After
the two planned combat attempts failed, she explicitly authorized one further
revised attempt. All three saves and input records are retained separately in
`artifacts/rea-victory-pilot-20261012/phases-1-to-5/`.

The third attempt completes the Bridge objective with integrity three, then loses
the tank during withdrawal. Original SIM.OUT is `02 01 01` followed by its kill
counters. Original END reports the primary goal achieved and saves 360 points,
mission count one and career status two. A fresh native process, without RAM
restore, attempts original Continue from a copied sealed disk overlay and receives
"NO ACTIVE PLAYERS TO CHOOSE FROM". The fifty-byte career record is unchanged.
This does not satisfy the surviving victorious campaign-save/Continue gate.

The task-local controller cancels queued batches during actual movement and turn
contacts. Its hull-mode stop correction is implemented; its terminal-destruction
correction passes three actual-state predicate checks but has not been freshly
native-replayed. The third run checks 5604 diagnostics, 5650 original passes and
626595 vertices without collector errors. The successful-campaign full-frame
enabled/off replay remains unexecuted because no accepted winning route exists.

All 81 protected hashes, including 68 original GAME files, the reference archive,
native core and observer headers, match the task baseline. Concurrent changes
outside this pilot's edit set were observed and preserved. A fresh REA dossier
refresh fails at Ghidra startup; earlier pinned REA evidence and unchanged
disassembly remain available. See `docs/pc-executable-research.md` for the exact
distinctions and evidence paths.

Status: local only, requested acceptance incomplete, three authorized combat
attempts exhausted. No successful campaign return or cold progression is claimed.
Working if: the completed objective is distinguished from the destroyed career,
the original cold rejection remains visible, and a failed run never closes the
surviving-victory or successful-campaign parity gates.

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
all 187 original boundaries, terminal exit 0. [15 October 2026 note: this total counted one constant-true `vehicle_art` check per frame; tests now count it once per run, so re-quote from the next `VALIDATE_LIVE=1 ./tools/validate.sh` run.] Every received packet's complete
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

## Original warning voices and live mute/restore parity (2026-09-28)

Continues the active local remaster goal after `26e045d`. Nell's “Niner is fine”
remains implemented: both nine/niner qualify as individual bearing digits,
with no permission for whole-number delivery. This pass adds eight original
warning/outcome captions and keeps all simulation authority in original SIM.

Pinned Unicorn source oracle executes nine already-selected argument/assignment
blocks. Results recover eight distinct captions, portraits 0/1/2, setter
completion 3d8e or 3dd2 and exact pointer variants. Assigned-area text has two
source pointers. No live RAM or original instruction is modified. Branch
eligibility, timing and whole trigger routines are not proved by this oracle.
`pc-warning-work-01/oracle-check.json` matches the committed fixture exactly.

Eight Gemini 3.8 Flash TTS takes are installed unchanged, with Orus, Iapetus and
Algenib authored by original portrait index. No named crew role was invented.
The installed PC message catalogue totals 392 (360 bearings, 24 damage, eight
warnings/outcome calls). Provenance retains original dry hashes, casting, request,
transcripts and comparison metadata. Generated samples alone were submitted for
blind recognition; no original binary or mixed gameplay recording was sent.

Seven initial blind transcripts matched. “M one” versus expected “M1” was a
lexical-format false negative. Added a narrowly scoped comparator equivalence
and rejection tests. The original failed report and raw recognition are retained;
the same unchanged transcripts were reevaluated offline. Corrected QA and the
installed receipt explicitly retain this custody, without claiming a fresh
recognition or changing a transcript. Human listening/mix acceptance stays open.

Both Python and Godot require exact source caption, speaker, assignment IP and
pointer variant. Existing complete visible-message, pixel, age, epoch, once-only,
F5/pause and source sound gates remain. Actual native and headless audio tests
pass 731 checks each, including all eight new streams and both area pointers.
Those per-cue player tests are synthetic source-qualified packets, not live
occurrences for every warning.

First actual smoke route `pc-warning-trace-01` matched all 1,023 baseline records.
`pc-warning-native-01` passed 7,284 checks and observed two audible warnings plus
one muted call. Self-review of its screenshot exposed an inadequate visual test
setup: a restored RAM-only snapshot has no historical plate-load provenance, so
cockpit artwork correctly stayed original. The implementer reviewed their own
existing presentation; this was not external art approval. No guard was weakened.

The final route reloads stations using ordinary F2/F1 input. An intermediate
1,059-frame capture pair (`trace-02`/`baseline-02`) matched, but began on F2 while
the production host's ready packet always uses neutral input. It was not used
for native acceptance. The corrected fixture starts with one neutral frame,
then the station reload and the same smoke/F5 sequence: 1,060 source frames.
`pc-warning-trace-03/comparison.json` passes eleven checks against baseline-03,
including every input, complete paired RAM/video and queued state, final state,
three source assignments and their exact visible frame/identity/sound gates.
The comparator also requires the committed input sequence, and mutation tests
reject altered RAM, video, keys, wording, identity, timing, gate or provenance.

`pc-warning-native-02` passes 7,549 checks, terminal exit 0. [15 October 2026 note: this total counted one constant-true `vehicle_art` check per frame; tests now count it once per run, so re-quote from the next `VALIDATE_LIVE=1 ./tools/validate.sh` run.] Actual production
viewer and original child reproduce all 1,060 RAM/video boundaries and every
source audio event. All three warning RGB crops match their original hashes.
Genesis cockpit, high-resolution portrait and type are active on every warning.
Two generated streams start, one muted warning is consumed, and all 98 frames
between F5 restore and the fresh warning remain silent. The implementer visually
inspected the native first warning, including the original smoke-obscured view.
No vehicle textures were enabled. No visual style/layout was changed, so an
optional frontend design linter was not applicable to this audio/test change.

Aggregate `validation-20260928T111639Z` passes all 41 stages, terminal exit 0:
290 Python tests, 185,967 typography checks, 14,003 gauges, 731 PC audio checks,
97 mix checks and 82 scheduling checks. After final diagnostic route/comparator
changes, full Python discovery again passes 290 tests (`python-final-route.log`)
and the final native route above passes. Relevant import/headless/native/aggregate
logs contain no script, parse or engine errors. Reference inventory and
`git diff --check` pass. All validation sessions completed; no owned process was
left running. Unrelated vehicle studies and generated UID files remain untouched.

This closes the bounded warning-bank integration, not the whole remaster.
Seven new calls still need live occurrence coverage. Radio, remaining dialogue,
music, graphics families, victories/campaign outcomes, historical/cross-hardware
pacing, listening/art acceptance and portable packaging remain. Next useful
source lane is remaining dialogue/radio selection and visibility, with music
extraction/arrangement another open presentation lane. Existing source utilities
and provenance should be extended rather than inventing trigger rules.
Work remains local only, with no push, publication, release or redistribution.

## Original radio speech and notification (2026-09-28)

Continues Nell's authorized local remaster work after `24bae58`. No push,
publication or original-file mutation. PC execution remains authoritative;
Genesis presentation priority, original-style type, dedication and rejected
vehicle-texture hold are unchanged. The overall remaster remains unfinished.

`pc_radio_voice_oracle.py` executes all ten radio entries across three original
radio-health states, plus the FFFF no-message sentinel. Eight scenario entries
supply five distinct captions; two SIM strings supply the other two. Full original
selection, equipment gate, queue, notification and retrieval routines execute in
isolated memory without instruction replacements. All 30 cases, exact pointers,
timers, dispatcher callers and stack balance match the committed fixture in
`pc-radio-work-01/oracle-check.json`. Trigger eligibility and whole mission
occurrence are separate from this isolated proof.

Seven dry Gemini 3.8 Flash TTS performances use authored Charon radio casting.
Six first takes passed blind wording QA. The airborne take said “Mark one” and
its second attempt “Mike one”; both remain excluded with their failure reports.
The third attempt spells “M one” explicitly in the spoken script and passes a
fresh blind transcription. On-screen M1 remains exact. Existing installer now
selects a fingerprinted original bank plus an independently checked repair subset,
validates unchanged selected cues/casting, and retains each source/QA/script hash.
Tests reject altered scripts, missing repair and wrong repaired wording. Seven
installed masters equal selected source WAVs byte-for-byte. All 409 previously
committed WAV files also remain identical. The PC message banks now total 399.
Human listening/mix approval remains open.

An authored 950 Hz attention sample is requested only by original dispatcher 11
at callers 3c97/3cdb. Queued RAM is never sent to speech. Radio uses the existing
complete-current-pixel message proof with separate once-only identities, exact
caption, source IP and fixed-pointer checks where applicable. The native-event
observer itself was not changed; original gate, staleness, program epoch and
bounded event ordering remain authoritative.

Driving discovery had three inadequate probes, all retained: first used gunner
controls, second stalled on a longer route, third stopped within the radius but
outside the required trigger cell. The corrected probe entered the original
cell and queued the airborne report. Frozen ordinary key inputs in
`pc_radio_steps.json` include station reload, three R retrievals and F5 mute/restore.
No terrain, health, position or trigger was bypassed. Overheating, engine damage
and a later excessive-slope call occur under the actual original rules.

`pc-radio-trace-01` and `pc-radio-baseline-01` match all 3,716 full paired
RAM/video/input/queued records and final SIM state. Thirteen comparator checks
pass. Notification fires at index 2614 without speech; unopened queue identity
3 never becomes public. Displayed report identities 4/5/6 appear at indices
2868/3145/3482 with gates true/false/true. Tests mutate source records, timing,
identity, wording, pointers, gate, notification speech and premature disclosure.
This restored in-mission route does not establish disk-dependent outcomes.

Native `pc-radio-native-01` passes 26,142 checks, terminal exit 0 with child 0. [15 October 2026 note: this total counted one constant-true `vehicle_art` check per frame; tests now count it once per run, so re-quote from the next `VALIDATE_LIVE=1 ./tools/validate.sh` run.]
Every original RAM/video boundary and audio event equals the trace. Current
message pixel hashes, Genesis cockpit and high-resolution radio type are checked.
One notification sample and two generated voice streams start; one muted report
is consumed, with 98 silent frames after F5 restore before fresh R retrieval.
Other six radio captions still lack live occurrences. Original overheating and
slope calls now have source occurrence evidence; their individual native-player
start assertions are not part of this radio-specific test.

The implementing assistant reviewed their own native radio image. Radio type,
cockpit and restrained ammunition bindings are present. The same view reveals
coarse original green checkerboard terrain across the hillside. Final capture
reports Genesis colours and terrain detail enabled, four terrain polygons and
one hill polygon; this alone does not explain or excuse the retained original
pixels. That visible presentation gap needs discriminating mask/draw evidence.
No vehicle texture was enabled and no existing guard was weakened.

`validation-20260928T115653Z` passes all 42 stages, terminal exit 0: 297 Python
tests, 185,967 type checks, 14,003 gauges, 731 existing PC audio checks, 229 radio
checks, 97 mix checks and 82 scheduling checks. Import, headless and native logs
contain no script/parse/engine errors. Reference inventory and `git diff --check`
pass. All owned jobs completed. Unrelated vehicle-study files and generated UIDs
remain untouched. No optional design lint was needed for this audio-only change.

Remaining whole-goal work includes the visible hillside gap, other graphics
families, remaining dialogue/SFX/music, victories/campaign outcomes, historical
and cross-hardware speed calibration, listening/art acceptance and packaging.

## Raised plateau dither repair (2026-09-28)

Continued after local commit `2e40fc2` without requiring another “proceed”.
The radio screenshot's checkerboard was diagnosed as an omitted shape family,
not missing world rendering or a broken cockpit mask. Only 24 of 9,840 ground
probe pixels had original UI ownership, corresponding to the sight. Godot was
replaying original dither for raised terrain shapes 55..71, outside HILLS 2..33.

Extended only the exact terrain identity table: 17 shapes, 32 faces and 15
source-fixed vertical projection axes. The whole hill/plateau mapping is now
49 shapes, 81 faces and 32 vertical planes. Reused the existing authored terrain
image unchanged. No shader, original geometry, source code, visibility,
physics, source file, vehicle texture or bitmap was changed.

Existing Genesis extraction helpers recover counterparts for all 17 shapes.
Independent tests find all 32 exact face cycles and source material+16 matches,
without absent/extra polygons. PC roots, primitives, materials, vertex bounds
and vertical normals are independently checked. A one-off comparison helper
initially omitted its neutral vertices and failed with KeyError; combining the
two existing documented outputs fixed the diagnostic. No parser workaround.

`pc-embankment-native-01/report.json` passes 5,999,173 checks over 6,874,880
pixels: 956,145 selected hill pixels change, all 5,918,735 outside pixels remain
exact, ten visible and two fully occluded cases. Includes two actual Escort
viewpoints at 4x/5x alongside the prior geometry/order, mean-colour, anchor,
vertical-plane, clipping, palette-fallback and occlusion regression cases.

`pc-radio-native-02` reruns the entire production viewer route with the new
terrain mapping: 26,142 checks, 3,716 original frames, zero errors, native/child
exit 0. [15 October 2026 note: this total counted one constant-true `vehicle_art` check per frame; tests now count it once per run, so re-quote from the next `VALIDATE_LIVE=1 ./tools/validate.sh` run.] All full original RAM/video boundaries and audio events remain exact.
The final complete presentation, original state and audio metadata match native-01
except terrain/hill counters; selected hill faces rise from 1 to 11. No vehicle
receives a texture. The implementer visually reviewed their own full new cockpit
and isolated terrain images, confirming the checkerboard is gone in this view.

Initial source-UI A/B check failed at 40 first-view and four final-view pixels.
Exact coordinates coincide with the unchanged reticle's analytic 0.8-coverage
edges at fractional vertical scaling. These blend the underlying changed terrain.
The revised diagnostic derives allowed fractional coverage from source strokes,
requires all opaque source HUD pixels exact, and uses any-channel RGB difference.
It does not exempt whole reticle rectangles or alter a production guard. Original
failed and intermediate receipts remain. Final `live-comparison-v3.json` passes
12 checks; all changes in three radio photographs and the final frame remain
inside the viewport. First view has 234,616 changed pixels.

`validation-20260928T120651Z` completes all 42 stages with exit 0 and 298 Python
tests. Native/aggregate logs have no script/parse/engine errors; reference
inventory and diff whitespace checks pass. Optional offline/no-install Impeccable
detect exited 0 with empty output; GDScript coverage is not inferred. No packages
were installed. All owned jobs are complete. Other untracked vehicle studies and
UIDs remain preserved. Work is local only, with no release/publication claim.

The observed plateau issue is repaired. The whole remaster remains unfinished:
remaining graphics/effect and dialogue/music families, mission victories and
campaign outcomes, historical/cross-hardware pacing, human art/listening review,
and portable packaging are still required. The earlier image-tool rejection for
the HEAT contour revision is a retained external art-production limitation.


## Requested play conveniences and local finish pass (2026-09-28)

Nell requested the presentation, audio and local-packaging work (items 2/3/4),
explicitly excluding an attempt to win a mission, and added save states, fast
forward and live EGA/Genesis/Upscaled switching. Modern is an unavailable future
mode. Authority covers local implementation, generated speech, checks and private
packaging; no push, release or public distribution. Prior unrelated vehicle
studies and generated UID files remain outside this work.

The production viewer now has Audio, Session and Graphics menus. Five numbered
checkpoints include native emulated state and the campaign overlay. Loading
first captures the current session in recovery slot 0. Atomic archives retain
the previous overwritten slot. Strict size, content/core/platform pins and
member hashes reject invalid states before replacing the current session.

Two real native failures shaped the implementation: reinitializing the upstream
dylib in one process crashed, so each restore uses a fresh worker; fresh DOS
startup deletes SIM.OUT, so RAM-only restoration failed full disk equality. A
paused-only native overlay reload/flush ABI now preserves the full checkpoint
disk and recreates saved handles via native unserialize. Ordinary execution
never calls this helper. The original source-baseline binary is unchanged.

First restored video is explicitly held, without an extra guest priming frame.
New draw ownership/audio counters are observed from original execution rather
than fabricated. Fast forward requests 2/4/8 original frames per presentation
request, preserving CPU settings and source order. It consumes events silently;
returning to normal resumes current loops/music without queued old voices.

EGA bypasses all presentation replacements. Genesis uses hash-pinned extracted
original-resolution donors, with PC fallback in unmatched and live regions.
Upscaled uses the existing high-resolution pack and original-style outlines. All
mode assets load at startup; switching recomposes the cached paired frame.
Modern is disabled. Vehicles remain flat original geometry. The memorial stays
in the Genesis/Upscaled final credit card; exact EGA remains original.

Root self-review of the new Genesis view found captured widget fragments in the
lower gunner margins. The first pixel gate only proved self-consistent sampling,
so it missed the content defect. Both complete side consoles now fall back to
original PC pixels, with independent forbidden-donor and rendered-pixel checks.
Root reviewed the repaired native image. This remains implementer visual review,
not independent aesthetic acceptance.

Audio adds 50 distinct source-verified scenario/destruction/speed captions
(49 Gemini 3.8, one authorized 3.1 fallback), five individually synthesized
source-request samples and four authored sample-based frontend arrangements.
The latter use extracted Genesis percussion, never mixed gameplay recordings.
They are new arrangements, not recovered original score sequences. Blinded
wording QA retained original responses and replaced two mispronounced takes.
Original installed audio bytes are unchanged. Music joins the persisted mix
without overriding gameplay F5/pause. Frontend paragraphs remain unvoiced.

Root verification receipts, all terminal exit 0:

* `pc-state-root-native-01/report.json`: 19/19 full native/disk checks, including
  held keys, cold reload, corruption/incompatibility rejection, playable native
  rejection rollback, actual PLAYQA campaign data and unrelated-save protection.
* `pc-conveniences-native-02/conveniences-report.json`: 113 checks, zero errors.
  Production viewer/menu callbacks; no original frame on graphics switches;
  exact same RAM/video and game state after 15 normal frames versus 1+2+4+8;
  persisted state save/load, transport mute and recovery visibility.
* `pc-graphics-root-native-02/report.json`: 10,253,369 checks across 158 native
  transition fixtures, zero errors, including repaired gunner margins.
* `pc-conveniences-parity-01/comparison.json`: 13 checks, all 3,716 original
  RAM/video/input/queued-message records equal the unmodified baseline after the
  new core helper build. Final original SIM state also matches.
* Root native audio gates: 165 remaining-audio and 47 music/transport checks.
  Unit menu/mix/scheduling gates: 59, 110 and 92 checks respectively.
* `validation-20260928T131813Z`: 46 stages, 328 Python tests, complete. Final
  affected graphics and source-parity receipts above supersede its first native
  pack. `validation-20260928T132451Z` is the final completed aggregate after the repaired pack and packaging fixture: 46 stages, 329 Python tests, exit 0.
* Optional Impeccable offline/no-install detect exits 0 with no output. No
  GDScript lint coverage is inferred; native image/functional gates provide proof.

Packaging uses an explicit allowlist, deterministic local ZIP assembly, an
external persistent profile, prerequisite checks and hash-pinned owned inputs.
The private kit replaces its own Play launcher without changing the checkout
launcher. The source kit excludes originals, derivative art/audio and extracted
dialogue; it is a review kit, not a complete runnable distribution. A documented
rights inventory leaves publication blocked pending permissions, code licensing
and dependency/corresponding-source obligations. No public operation occurred.

Mission victory/campaign completion, wider individual cue occurrence, independent
listening/art acceptance, modern models and supported-platform standalone
installers remain outside this delivered local slice. The whole remaster goal
is not declared complete.


## 2026-09-28: Non-Modern completion programme

Nell authorized the six-part completion programme and all remaining graphics,
explicitly deferring Modern. This pass preserves original PC authority and
Genesis donor precedence. Original games, ROM, extracted assets and private
kits remain ignored and excluded from Git. No public release is authorized.

Delivered all three source-selected ending newspapers with distinct full-paper
and later PC-prose phases, two aftermath scenes, PC publisher card, three added
Wilson performances, four-role portrait coverage, crew/armament diagram and
caption completion, five STATUS damage overlays covering 32 combinations,
24 systems lamps and the red/off lock lamp, observed target box, map surround
and source-defined dynamic map geometry, source-vector cursor and clipped strut
custody. All 64 masked effect bindings use 20 authored donors. The unreachable
13-image manual quiz and distributor-only banner remain explicitly inventoried.
Original flat world polygons remain the selected non-Modern geometry style;
rejected vehicle textures and replacement models stay disconnected.

Checkpoint archives now preserve validated host EGA ownership alongside the
native machine and campaign disk. Root native verification passes 26 checks,
including source-video/ownership continuity against uninterrupted rendering,
cross-process reload and rollback. Fresh scanlines rebuild masks; partial draw
candidates and stale audio do not replay. Old core fingerprints remain incompatible.

The finite audio audit accounts for 30 sound and 21 message/radio callsites,
345 original captions and 449 installed caption takes. All 476 WAVs pass PCM,
provenance, silence and sample-clipping checks after repairing bearing 182 with
a new dry Gemini 3.8 take. A dedicated PC-only limiter prevents sample-domain
mixed-output overload; Master and calibration audio remain untouched.

Root aggregate validation: `artifacts/validation-20260928T162843Z`, all 61 gates
pass, including 418 Python tests. The earlier gate correctly failed an obsolete
frontend test that allowed only intro outside office programs. The test now
requires a valid current child binding for each newly supported START family
and independently excludes stale office poses; no production guard was weakened.
Root native graphics switching: 10,253,369 checks across 158 frames. Root native
damage: 899 checks / 96 renders; lock: 83; portraits: 825; effect modes: 19,930,986;
complete-map integration: 84. Root newspapers: 780,124 checks; information: 22,375,982; Wilson: 2,392;
publisher/aftermath: all three scenes. Clean stdlib-only source kit: 401 files,
37 tests passing (two private-input skips). Full receipts are
under `artifacts/finish-20260928/`, alongside retained diagnostic failures.

Final-core root endurance passes 71,873 original frames and 2,839 checks across
all eight scenarios,32 stations,19 checkpoint replays, information screens and
cold campaign Continue. Native resize covered six transitions including fullscreen.
Earlier long native pacing measured 26.41 to 31.28 fps. Profiling led to two exact
fast paths: reuse only the identical immutable RAM snapshot's completed locate
result, and prove an entire zero driver-mask byte array directly. All 1,200
before/after inputs, full packets and RAM/video hashes match. Ordinary/audited
playback improved from 42.61/37.92 to 53.58/53.75 fps, still below 59.5 fps. This is
reported as improved, sub-target throughput, not a full-speed acceptance claim.

Source-only CI now excludes owned inputs and runs from a temporary stdlib-only
source kit. The staged/history boundary rejects known original hashes, private
paths, recognizable secrets, nonregular entries and files over 50 MB. Importer
reconstruction validates the complete archive before destination writes.
Managed private-kit installation keeps profiles outside replaceable kit files.
Packaging, dependency and recovery evidence is separate from native OS support.

The HEAT illustration remains externally blocked by the recorded image-tool
rejection; no retry or alternate route was used. Modern remains deferred.
Independent aesthetic/listening acceptance, naturally occurring mission outcomes,
historical speed calibration, native non-macOS ports and redistribution/licence
clearance are not claimed. This is local implementation and machine evidence.


Final private packaging: two deterministic builds, two clean installations and
three real managed native cold boots (the third independently run by root).
All 1,224 installed files and three existing synthetic profile/checkpoint files
remain unchanged. Invalid checkpoint archives and managed-path overrides reject.
Root verified every packaged input against the checkout and installed tree.
Final closing-doc rebuild retains byte-identical runtime content. Staged/index
and reachable-history guards pass; originals, ROMs and private kits are excluded
from Git. No push, hosted CI execution or public release is claimed.

## Expressive crew performance pass, 28 September 2026

Directed and regenerated the 50 remaining mission/destruction/status calls and
seven radio calls with Gemini 3.8 Flash TTS. Existing casting, captions, source
identity and event eligibility are unchanged. T-series destruction calls request
pride and energetic emphasis on “destroyed”; success, threat and loss reports
have distinct acting direction. A documented inline short pause resolves the
“com station” abbreviation. The remaining 415 installed WAVs are byte-identical.

All 57 selected dry masters pass blinded wording QA and exact request/hash
custody checks. Four initial wording failures were replaced; one needed a second
repair with the pause. Transcript punctuation/model-name equivalences were
corrected without relaxing digit-wise bearing or extra-word checks. Original
responses and rejected takes remain retained. Blinded audio comparisons selected
the new T-62, T-72, mission-success and radio-approval takes as more energetic.
These comparisons evaluate work directed in this pass and remain automated,
without independent human listening acceptance.

Root checks: 53 Python tests, 1,107 headless Godot checks, 165 native Godot stream
checks, and the full 476-WAV audit (zero errors or timing advisories). No PCM
full-scale samples; the existing limiter gate also passes. Evidence and rollback
copies: `artifacts/bark-direction-20260928/` and
`local-audio/bark-direction-20260928/`. Local project updated; the earlier private
ZIP is unchanged. No push or release.


## HEAT illustration completed, 28 September 2026

Finished the exterior-only Genesis HEAT illustration and integrated it at the
verified PC sprite bounds (104,22), 208x67. Rejected an initial style-drift output
that resembled SABOT. Source text, timing and original files remain unchanged.
Seven information pages now cover 99 original text runs and 77,776 source sprite
pixels. The earlier unfinished HEAT status is superseded.

Root checks passed: 422 Python tests, 83 headless information checks,
25,865,418 native information checks, and 10,253,373 native graphics-mode checks.
Two live launcher cold boots have identical original framebuffer bytes, state,
program, presentation and samples; their final artwork differs as intended.
Selected asset, prompts, failures and receipts are retained in the ignored local
art manifest and `artifacts/heat-finish-20260928/`. Local only, no new ZIP or push.


## Gunner screws, aperture and console trim, 28 September 2026

Corrected six stretched upper fasteners using independently registered donor
sampling, replaced warped console margins with Genesis-style code-native bevels
and eight round fasteners, and cleaned up the static display rims. The aperture
now has a smooth red lip instead of exposed low-resolution grey steps. Its 84
original corner pixels are verified as a complete shape. Antialiasing reuses
already-visible scenery colours; hidden world pixels cannot leak through.
Original instrument values, source-visible world pixels and gameplay remain
outside the trim's ownership.

Root checks passed: 2,160,931 focused native trim checks at three resolutions;
12,051,382 all-station native checks; 4,096,050 legacy material checks; and full
62-stage `tools/validate.sh` with 422 Python tests. Full terminal receipt:
`artifacts/validation-20260928T174932Z/`. Live 1280x960 launcher captures with and
without Upscaled art have identical original framebuffer, world image, decoded
state, program and sample count. Their draw-entry RAM hashes differ between
independent cold boots; no full-RAM parity claim is made. Same-packet EGA,
Genesis and Upscaled switching passes exact renderer restoration separately.

Visual self-review and failed development renders are retained in
`artifacts/cockpit-trim-20260928/`, alongside the final completion receipt.
The source archive allowlist includes the new renderer/test; assets remain
private. No push, new private ZIP or public release.


## Held controls, station audit and private-kit refresh, 28 September 2026

Save/load/undo shortcuts now quarantine only their own chord, preserving held
movement and fire. Native menu/focus safety remains separate, requiring neutral
input before resumption. Six same-timeline fresh-process native probes and 18
supervisor checks cover saved controls, release/change, Shift+3, an eight-frame
batch, undo, invalid-container rejection and native rollback. Root reran them in
`artifacts/next-pass-20260928/held-native-root/`. Godot shortcut and scheduling
checks pass 112 and 157 cases. Focus signals are exercised through the connected
Window API; physical hardware delivery remains separate. No core change needed.

The commander has four round lower-console fasteners. The cupola rail uses the
Genesis donor only after exact source and ownership proof of all 457 fixed pixels.
Its original outer silhouette and every world pixel remain protected. Existing
heading join and gunner appearance are retained. Root native all-station checks:
12,058,687; focused gunner: 2,160,931; orientation: 321,377. All 25 integrated station
captures match the visually reviewed candidate byte for byte.

Current-pixel orientation proof now uses exact packed-byte operations, with the
old loop retained for other formats. The same validated plate-mask image is reused
within one compositor call. Root original-CPU/mutation oracle: 2,430 checks. No
source timing, native core or original game data changed. Ordinary pacing was
37.60 fps before and 45.86 after under varying desktop load. Final unattended
3,600-frame endurance measured 58.98 to 59.78 fps with zero consumer lag; sustained
load performance remains open. The first endurance screenshot helper stalled on
an inactive-window draw signal. Its repaired explicit flush path completed the
full rerun without intervention. Detailed limitations and retained first-run
results are in `artifacts/next-pass-20260928/performance-report.md`.

Root aggregate `artifacts/validation-20260928T183423Z/`: all 62 stages and 422
Python tests passed. Host endurance: 70,553 frames, 2,822 checks, eight scenarios,
19 checkpoint cycles and cold campaign Continue. Native conveniences: 144 checks;
six resize/fullscreen transitions passed. Native graphics-mode regression also
passed 10,253,373 checks across 158 frames. Source-only packaging contract: 37 tests,
two documented private-input skips, 406 allowlisted files. Private-kit assembly and
installation evidence for this candidate is recorded in
`artifacts/next-pass-20260928/private-kit/receipt.json`. The kit includes the current
HEAT illustration, 57 directed Gemini 3.8 takes, cockpit repairs and held-control
fixes. It stays local, separate from Git; originals remain excluded. Human listening,
mission/campaign acceptance, other native platforms and rights remain separate.

## Standalone macOS alpha and paced soak, 2026-09-28

Local candidate `41e285f25225189b5936` bundles ARM64 Godot, the frozen Python/Pillow
bridge and a native PC-required/Genesis-optional importer. It excludes raw PC
files, the reconstructed PC ZIP and Genesis ROM. Player data lives outside the
app; invalid inputs/tampered installs are rejected, and upgrade paths preserve
existing profiles. The original-box-art-derived cover/icon retain BY DYNAMIX and
Nell's slightly reduced ivory stencil FAN REMASTER treatment.

Root-run aggregate: 63 stages and 446 Python tests. Source kit: 61 tests, two
private-input skips. Native frozen-runtime convenience route: 144 checks. Actual
focus/fullscreen/menu interactions, fresh final PC-only SIM boot, post-play
signatures and original/profile byte-preservation receipts are retained under
`artifacts/alpha-readiness-20260928/`. A late shutdown packet could restart music;
a native failing probe and the repaired passing probe accompany 159 scheduling
checks. Startup text's zero-width wrapping was also repaired (42 focused checks).

The 30-minute RAM-audited production run passed 271,348 checks over 1,801.013 normal
SIM seconds plus 36.788 fast-forward seconds, all four stations and 18 restores.
Static memory ended at 90.31 MB, from 88.94 MB; peak 90.92 MB. Sampled process-tree
RSS peaked at 992,224 KiB, potentially double-counting shared pages. No test child
remains. Instrumented normal throughput was about 36 to 38 source replies/second;
this does not meet the roughly 59.92 Hz source clock in wall time. Ordinary
unaudited sustained speed and wider-machine acceptance remain open.

The limiter fixture's independent mixer-buffer reads could race and throw out of
bounds. With Nell's case-specific permission, only the verified stuck test PID
was terminated. Paired-prefix reads fixed the fixture, a bounded run now protects
the gate, and the complete aggregate rerun exited successfully. No production
limiter was weakened. Native popup callbacks were not exposed to GDScript on this
engine build; UI selections were independently observed. Physically held hardware
keys, campaign victories, independent listening, other OSs and release rights are
not claimed. Modern remains deferred. See the local ACCEPTANCE.md for exact logs.

## Whole-codebase audit, fixes and website polish, 2026-10-03

Nell asked Claude Code to scan and fix all contemporary code and polish the
website. Baseline before any edit (WIP snapshotted as
`refs/claude/baseline-20261003`): Python 580 OK/1 skip; validate.sh Godot checks
67/69, with `pc_live_scheduling` failing (fixture never set `startup_ready`
after the startup splash) and `pc_audio_assets` failing (a retired promo dry
master; restored byte-identical from the installed voice, hash matching the
retained receipt). Thirty-nine read-only finders produced 155 candidates;
adversarial verification confirmed 148 (2 high, 11 medium, 135 low, none
gameplay-affecting). Two reviewed fix passes resolved all but three: F025 needs
a local-art catalogue hash rotation, F067 waits for the next pinned core rebuild,
and F038's strengthened check needs a windowed native run. Final: Python 683
OK/1 opt-in skip (with unicorn available), validate.sh 72/72 including three
newly wired checks and a per-check time bound, source CI PASS, native
`verify_pc_save_states` 26/26, joystick and scenario launcher captures clean.
The website gained aligned layout, FAQ, branded 404, robots/sitemap/JSON-LD/
llms.txt, WOFF2 and right-sized images, and a 4.8 MB field guide (was 36 MB).
Nothing committed or deployed. Follow-ups: `_contprompts/audit-followups_2026-10-03.md`.
Finishing pass the same day: Nell applied the gated CI patch; F025's map-frame
catalogue now records its rebuilt footer (hash rotated); F038 ran natively at
208 checks, 0 errors, after replacing the stale 1+2+4+8 replay with the menu's
real 1x/8x speeds; tool import fallbacks no longer mask missing dependencies.
After Nell accepted Apple's updated agreement, a fresh current-source app (signed
build 1a61287931510c16adc4, 87 Developer ID targets, core text unchanged) passed a
signed-app import and capture smoke, was notarized (submission 871599ab-b8f4-45c7-
a920-e303cf985360: Accepted, 0 issues), stapled, and passes Gatekeeper as
"Notarized Developer ID", including from the extracted release ZIP. Receipt:
`artifacts/notarization-20261003/RELEASE-RECEIPT.json`. On Nell's "All live, all
finished" it was attached to the v0.1.0-alpha.4 release (GitHub asset digests
match), the website switched to it, and the work merged to main as a fast-forward
with Pages and source CI green and the live index byte-identical to local. The
website dedication also gained Nell's portrait of her father, David "Ming" Kenny.

## Browser edition publication and Tactical mode, 10 to 11 October 2026

Recorded retrospectively on 15 October 2026 from Git history (audit finding #85);
this period previously had no ledger entry.

Browser edition (10 October 2026): `88d1bc9` "Ship browser Play remaster and site
entry", followed by `48aeb3a` (Web runtime dependency licences) and `7f5a815`
(browser frame and observer transfers). `88d1bc9` committed
`website/dist/play/.generated/`: 217,489,816 bytes in total, including the four
remaster asset parts `remaster-assets-00..03.zip` (283 files, 145,522,643 bytes per
`git ls-tree -l 88d1bc9`; sha256
prefixes `715afab15a4b5227`, `b85088ba09795ccb`, `6a9147a8db28c73d`,
`67b5fe13e0b27dd0`), the Godot `index.pck`/`index.wasm`, the Pyodide runtime, the
Web core `core.wasm` (sha256 `0d7e1b9b…`, DOSBox Pure `73e03aa…`) and its
corresponding source. Those parts contained Genesis-derived and other remaster
assets and, as the 15 October audit found, decoded original PC recognition data
and raw Genesis extracts (see `release-rights.md`).

Owner instructions, quoted from the Codex session transcript
`~/.codex/sessions/2026/10/10/rollout-2026-10-10T14-39-55-01…` (UTC): 13:40 "Could
we, should we craft a web version of the Abrams Fan Remaster, still requiring
upload of the game?"; 13:49 "Proceed please."; 14:24 "Not much good without the
remaster! Get it all 1:1 with desktop please. Also update the site with the new
option."; 15:05 "Get it completed please."; 15:28 "Do it yourself please.";
17:15 "Get it all fixed perfectly please."; 17:29 "GET IT FINISHED please." At
15:29 the agent said it would not treat "do it yourself" as permission to
publish assets with unresolved redistribution rights. At 18:57, before pushing,
it cited "your authorization to publish the remaster assets". The specific
message was not among that session's retained user messages; on 15 October 2026
Nell confirmed it directly: "Public use of my remaster assets is fine."

Tactical mode and HUD Style (11 October 2026): Tactical first appears in
`de06c50` "Polish Tactical web graphics and reconcile source-only safeguards"
(`pc_play_display.gd`, `pc_tactical_hud.gdshader`, `pc_tactical_chrome.gd`,
`test_pc_tactical_hud.gd`), then `44e55fc` (hedgerows and tree trunks), `53ce654`
(Tactical layouts across every crew station), `8881d39` (instruments and vehicle
schematics), `7a6e790` (Tactical map and unified HUD presentation), `60c20e8` (map
contours and terrain materials) and `6d6d749` (rounded map roads and riverbanks).
Origin, quoted from `~/.codex/sessions/2026/10/10/rollout-2026-10-10T20-48-08-01…`
and the browser session above (10 October, UTC): 19:42 "No, that's normal, I mean
there was like a green HUD and such at one point?"; 19:48 "I didn't know we had
this! This looks cool as shit. Can we offer this as a graphics option in the
game?"; 20:28 "Proceed please, and also remake all of the Hud elements in a
modern style please." These requests created Tactical mode and the independent
HUD Style. [Inference] They approved the mode and the HUD restyle, not any
information departure: Tactical effects and HUD remain bound by the
`docs/GOAL.md` fidelity clause. The 14 October entries record approval of
refinements only.

Working if: `release-rights.md` links here, and Nell's confirmation of the
browser-asset public-use wording is recorded here, quoted.

## REA setup and SIM pilot, 12 October 2026

Nell requested: "Set up REA and run the SIM.EXE pilot, keeping the original game
files unchanged." Installed pinned REA 6.4.0 locally with package lifecycle
scripts disabled; configured Codex only against existing Ghidra 12.1.4/JDK 21.
The unrelated Codex configuration digest is unchanged. Analysed a read-only
copy of the independently unpacked SIM, with successful MCP/native load-image
verification and a fresh 256-input original bearing/bark oracle. Identified
load-relative `0000:0e5f` as the post-dispatch/pre-station-render boundary; four
historical-RAM isolated CPU witnesses reach it in the recovered call order.
Live atomic sampling remains unverified. No core, bridge, simulation, gameplay
or original source file was changed. Evidence and acceptance checks:
`artifacts/rea-pilot-20261012/`; interpretation and limitations:
`docs/pc-executable-research.md` section "REA SIM pilot". Local only.

Working if: all 68 original files retain their fingerprints, unrelated settings
are preserved, and isolated boundary evidence is kept distinct from live parity.

## REA candidate live tracing, 12 October 2026

Nell authorized read-only live traces at load-relative `0000:0e5f` during
movement and station changes, with original files unchanged. A task-local
native probe in a private copy of the pinned source records 1,878 instruction
samples, including 470 candidate observations, all four stations while moving,
three world rebases, braking and turret rotation. Probe-on, probe-off and the
unchanged shipping core replay 1,737 frames each with exact conventional-RAM,
video-boundary-RAM and framebuffer agreement. All 68 originals and 374 protected
game/core/source/header files retain their fingerprints.

Rejected the candidate as an atomic whole-scene boundary: cached camera data
lags movement and station changes, a rebase combines old camera coordinates
with a new world origin, and dynamic-pool slot 1 refreshes during rendering.
Forty-four full-RAM witnesses match their recorded decoding. Keep existing
render-pass/scanout pairing; no production hook, bridge or gameplay change.
Receipt: `artifacts/rea-live-boundary-20261012/report.json`; details and bounded
coverage: `docs/pc-executable-research.md`, "Live boundary traces". Local only.

Working if: exact replay parity and unchanged input/core fingerprints hold,
and the mixed-age counterexamples remain explicit rather than being promoted
into a whole-scene sampling contract.

## REA later-boundary live tracing, 12 October 2026

Nell authorized read-only live traces at `0000:0e62` and later loop boundaries,
with original files unchanged. The private native probe and existing original
render-pass observer recorded 4,254 instruction samples across 531 complete
iterations. At `0e62`, every sampled camera/origin and every queued/drawn
object pose agrees with the latest completed original world pass. The selected
scene and player/control fields stay stable through `0e85`, the recommended
clean iteration-end diagnostic marker. All four stations were sampled while
moving, with three world rebases, turret rotation and one original HEAT shot.

Three 1,920-frame native runs, observer-on/off/unchanged shipping core, have
exact RAM/video-boundary-RAM/framebuffer/diagnostic parity. All 68 originals
and 374 protected source/core/header/game files retain their fingerprints.
All 178 saved RAM witnesses were re-read; 43,592 original vertices were checked.
Full allocated-pool differences in 49 post-render samples involve no queued or
drawn objects; 1,643 presented frames belong to an older pass. Keep original
pass participation and framebuffer-slot/scanout attribution. No production
integration. Receipt: `artifacts/rea-later-boundary-20261012/report.json`;
scoped recommendation and limits: `docs/pc-executable-research.md`, "Later loop
boundaries". Local only.

Working if: parity and input/core fingerprints hold, the coherent-field scope
stays explicit, and the recommendation preserves original pass/display pairing.


## Original loop-end diagnostic integration, 12 October 2026

Implemented the approved load-relative `0000:0e85` sample in the native tracing
observer, guarded decoder, collector and bridge session. `--loop-diagnostics`
opts into separate nullable `loop_diagnostic` packets. Normal Play stays unchanged.
The copied conventional RAM is independently pinned to active SIM, CS/DS and the
relocated loop instructions. Original draw participation, pass/page/scanout and
native framebuffer-slot custody remain the presentation authority.

A task-private build from the pinned dependency is activated in the local trace
core/manifest. The previous core/manifest are retained under
`.runtime/rea-loop-diagnostic-20261012/`; existing player save slots are untouched
and no cross-core save migration is performed. Shared dependency source and all
68 original game-file contents and paths are unchanged.

Validation: three 1920-frame runs (enabled, disabled, previous core) exactly match
conventional RAM, video-boundary RAM, framebuffer, existing session/presentation
and audio-event packets. There are 532 native loop-end observations, 531 attributed;
577 original world passes and 43,592 vertex checks per run. All 1643 presentations
whose pass is older than the latest completed draw retain their original pairing.
Focused tests: 81 passed; additional current lifecycle/save-state run: 63 passed,
with overlap. The first run's new fixture identity assertion was corrected;
the failure and passing rerun are retained. The final camera sampling annotation
is covered by the current lifecycle tests and actual bridge protocol check.
All 17 real-bridge checks pass for enabled save/load, held packet clearing,
reacquisition, and disabled loading of a diagnostic-bearing save. Invalid
diagnostics do not clear drawing context. Independent read-only Astra review
accepts the actual contract and recorded evidence; root verifies the receipts.

Evidence: `artifacts/rea-loop-diagnostic-20261012/`. No Godot/frontend edits, uploads,
publication or deployment. The tested mission/normal-CPU/EGA scope remains bounded;
universal atomicity, other modes/backends, wall-clock and waveform parity are open.

Working if: the opt-in diagnostic stays separate, exact original frame/presentation
parity holds, restore/program lifecycle drops stale observations, and all original
file hashes remain unchanged.

## Mission-victory and campaign-progression pilot, 12 October 2026

REA SIM/END analysis identifies the original twelve-byte objective, hostile-first
quit gate, 34-byte SIM.OUT handoff and fifty-byte campaign save. Ordinary-control
Road to Bonn scenario execution proves objective 1/1 complete while alive at
original frame 26423. Its subsequent withdrawal loses the tank; that objective
witness alone does not establish a completed exit or career progression.

The longer route exposed a host observer phase error when the original draws a
destroyed-GPS black panel. The stale callback marker incorrectly began world
ownership. `tools/pc_core/abrams_trace.h` now reads the original SS:BP return
CS/IP and admits only the two actual world-background callers. Original draw
calls and the guard are unchanged. Exact same-state RAM/framebuffer parity
through the previously failing frame 10331 passes; 43 focused render/session/
UI/plate tests pass. Current trace pin:
`bd3877f73c1505bc9d6883fbcbd9d860f71f7d56ee51d50a21887da3b5723191`.

Enabled/disabled replay of all 646 ordinary input steps proves exact per-frame
RAM, video-boundary RAM, framebuffer, existing session and audio-event parity
across 26,183 frames per run. Each retains 5,133 original draw passes, 583,388
vertex checks and 17,245 presentations whose original pass is older than latest.
The enabled hook observes 5,114 loop ends; disabled observes none. Two loop
observations decode a null camera while the completed original draw has its
camera. No diagnostic replaces the original paired pass. The failed overstrong
camera-match research assertion and passing corrected comparison are both kept.

Campaign combat trials identify separate overall hull/crew integrity at DS:CC2.
A tank can be destroyed while its three component conditions remain high; the
task-local control helper initially watched only the components. Its read-only
smoke trigger was corrected, and routes now engage visibly identified pursuers
before exposing depleted rear armour. No guest state is changed.

The campaign persistence lane follows original abandonment, not victory. END
reports primary goal failure, four BRDM-2 kills, one HIND kill, score 55, and
observed SIM.OUT `01 01 00` plus 31 counters. The original save becomes fifty
bytes, score 55, mission count one, career status zero, and scenario-two played
marker one. Original R&R returns to START; normal closure retains that record
and original loadout/handoff data. No campaign bytes are authored by the pilot.
Fresh-process Continue, without a RAM restore, loads the exact saved record and
enters mission two, Siegen Infiltration (scenario seven, objective 0/2), with a
healthy tank. The original score, count, status and played marker remain unchanged.
The resumed Siegen attempt destroys a visibly locked T-64 and BRDM-2, then takes
further original equipment damage while still at objective 0/2. Original
abandonment and END confirm failure: SIM.OUT `01 02 00`, eighteen mission points,
saved total score 73, count two, status zero and played markers two and seven.
Original R&R returns to START; the task-owned core closes normally.
The victorious campaign return-to-base boundary remains unverified.

Evidence: `artifacts/rea-victory-pilot-20261012/`; detailed contracts and outcome
limits are recorded in `docs/pc-executable-research.md`. All 68 original inputs
and the original input ZIP currently match their baseline hashes. Local only.

Working if: genuine objective victory, completed exit, campaign disk save and
fresh-process Continue are independently evidenced, original files stay unchanged,
and latest diagnostic observations remain outside displayed draw/scanout pairing.

## Checkpoint calendar and focused native playability repairs, 13 October 2026

Fixed the emulator calendar omission through the reviewed trace-core builder:
new native save format9 stores explicit DOS year/month/day, validates date fields
before assignment and preserves reset behavior. Legacy8 research blobs remain
readable with the boot date; exact-core player slots are preserved without
migration. The previous core/manifest are retained with the task evidence.
Activated local core: `b859afb15676cc7fc019154d84983ec40b139c2b813d1b11ce503328f8de28a5`.

Cross-day continuation matches all32 original menu/mission-selection RAM,
video-RAM and framebuffer milestones; the legacy8 control diverges. Ordinary
old/new native execution matches. Malformed month/day and truncated date states
are rejected. The existing native checkpoint gate passes26checks, including
input continuation, fresh-process restoration, recovery and campaign-disk custody.

The focused pass exposed512-byte pipe backpressure coupled to rendered-frame
polls. A bounded fragment drain now yields briefly after progress, retains the
2ms/read/size bounds and keeps the original protocol/sequence checks. Nine
focused transport regressions pass. Initial timed-out audio runs and the first
insufficient immediate-empty receiver change are retained; changed host pipe
capacity prevents a controlled before/after performance claim.

An explicit EGA sampler initially caused white ammunition wells and exceeded
the dense cockpit's preceding eight-custom-sampler budget. Shared graphics work
extracts the unchanged Scale3x algorithm to a separate one-sampler shader and
binds/rebinds PC crops, preserving the non-EGA compositor byte-for-byte. Root
native verification passes329342exact RGB checks, five frozen full-donor views
and bit-identical Modern switchback. These are current-source renderer checks,
separate from the shared chat's WebGL delivery receipt.

Native play visits all four stations and menu save/load succeeds with no bridge
or audio validation failures. Extra real keyboard input and focus changes reject
that run as an exact scripted replay or FPS comparison. The separate1712-frame
CoreAudio48000Hz run passes128events,3426loop checks, three readiness receipts,
cannon/coax/smoke and loader voices, F5 mute and pause/resume; its child exits0.
System output settings are unchanged; human listening is not assessed.

All70protected original files, including68GAME files, retain their starting
hashes. Source allowlist/dependency closure passes508files. All task-native jobs
exit and the shared resource slot is returned. Unrelated graphics/pack work is
preserved. This task does not push, deploy or publish.

Evidence: `artifacts/checkpoint-playability-20261013/REPORT.md` and `report.json`.
Universal CMOS/wall-clock/cross-platform portability, old-slot migration and a
victorious campaign are outside this bounded acceptance. The optional Impeccable
CLI was unavailable. Working if: new checkpoints retain their calendar across
restore, fragmented replies preserve exact payload/sequence limits, donor/PC
ammunition pixels survive mode switching, source-driven audio and all original
file hashes remain unchanged.

### 2026-10-13: measured native palette fast path

Retained five production lines in ModernAssets: exact canonical integer/JSON
palette comparisons use native Array equality, while the existing mixed/malformed
scalar fallback and identity order remain unchanged. Integrated predicate checks
pass311. An admitted ordinary-control ABBA completes four1020-sample, fully focused
four-station routes at unchanged tactical quality with Dummy plus no-audio.
Decoded packets, frame audits, requests and all four paired capture PNGs match
exactly. Every run has209mesh builds and811reuses.

Mapping means are9.161/9.205ms baseline versus8.696/8.606ms candidate, a conservative
5.074percent reduction. Total rebuilt-frame apply improves only1.392percent;
no overall FPS gain is demonstrated. Host load remains substantial. Source cadence
and p95 pass the declared no-material-regression gates. The wider17717-check
Modern suite has material/UV failures reproduced by unchanged baseline; it is not
reported green or rewritten for this focused optimization.

Native session10964 exits0 at15:27:44UTC, before15:30:30stop; exact owned-process
census is empty15:28:13. Before retention,2434frozen source/assets/core hashes and
70original hashes match, and own2source files are restored exactly. Only the
verified candidate pair is then reapplied. Draw, shaders, diagnostics, original
simulation and files, PCK/BUNDLE and unrelated dirty work remain untouched.
Local source only; installed web PCK retains preceding592b2401graphics delivery.
Evidence: artifacts/mesh-performance-20261013/REPORT.md, native-comparison.json
and native-handback.json. No additional runtime trial, push or deployment.

## 2026-10-14: HUD performance fix verified and installed locally

Retained only the reviewed PlayDisplay CPU mask optimization. The independent
320x200 unmipped L8 snapshot follows the existing texture upload and clear
lifecycle, and consumers receive fresh copies. Unsupported representations retain
the original GPU readback. Fresh authority, provenance and UI ownership checks
continue unchanged. Foliage cache, palette web integration and pending material
grain were excluded from this delivery; their prior failed or unverified receipts
remain intact.

Final browser session11795 exits0. All1536 paired, focused, silent full-quality
samples,182 mask lifecycle checks,8 backend fixture proofs,16 live CPU/GPU fast
path proofs and50 complete PNG comparisons pass, including Modernized and normal
cold-load controls. Conservative rebuilt-frame elapsed processing reduction is
7.7738percent; baseline rebuilt spread is0.5932percent. This measures the paired
renderer replay, not whole-game FPS. An earlier one-red-LSB baseline-self map
variance remains recorded; an equal unmeasured map primer was the only QA helper
change, with full pixel equality and all frozen thresholds retained.

Both local browser PCKs are3d3f8d78739660af8fd2a9d2723b0c60fed2f477179da14e7ab7d86935a09693.
Only PlayDisplay changes among1118 normal payloads;1117 remain exact. All45 BUNDLE
rows verify,44 non-PCK rows are unchanged, original70 hashes and other frozen
sources remain exact. Guarded installation updates only both PCKs, their BUNDLE
record and PlayDisplay source. Pending grain is marked stale/rebase-required.
Actual browser/server closure03:51:56.458UTC and subsequent empty ownership census
are recorded. No foreign processes were signalled and nothing was published.

Evidence: artifacts/performance-hud-only-20261014/comparison.json,
final-pass-handback.json, delivery.json and installed-verification.json.
Working if: the installed normal builds retain the reviewed HUD snapshot lifecycle,
all other normal payloads remain exact and Modernized captures are unchanged.

## 2026-10-14: complete local Tactical visual/UI pass

Nell approved the complete 32-item programme, local only. Installed normal Web PCK SHA-256 `4dffebf0862d0d820fe0f8cba3074ff0ee309b9bdb1896e95a6eb62b6acad76e` (15,924,552 bytes, 1,120 entries) into both local playable trees; BUNDLE `733c1fce193ae967163051602744a3a0987d0a2f94c8c3dd34c9f9e899174d2b`, all 45 records independently verified. No publication, original-file mutation, foreign process signal or guest-memory/timing/quality change.

Changes: admitted Tactical finish grain and restrained family-specific chroma; verified straight-road face edge finishing inside the existing road footprint; consistent filtered near/distant crown palette and upper-stem colour; basal shrub colouring, quieter meadow tones and source-seeded canopy variation; colour-only particle volume; larger verified priority instrument readings and source-segment gauge engraving; bounded C2 map corner joins and source marker hierarchy; Tactical tooltips and correct six-mode art descriptions. EGA Upscaled retains original colours; Genesis Upscaled remains the generated-art renderer. Tactical icon tinting duplicates the engine Image so shared Restored theme data cannot be mutated.

Actual acceptance: six WebGL contracts, 2,677 checks, zero errors; 35 paired full playable view controls, 17 protected whole frames pixel-exact; Modernized world with Tactical HUD and thermal world exact; fixed-source repeat frames exact. Native headless HUD (1,303) and menu (290) pass. The headless-only foliage proportion failure reproduced on the unchanged predecessor and passes the real WebGL backend without relaxing the assertion. Initial material whitelist/orientation and particle-study accounting failures remain retained, corrected in private fixtures before acceptance.

Existing matched ABBA profiler: 4 × 384 source-paired full-quality rows; baseline rebuilt drift 4.294%, conservative candidate rebuilt application cost +0.662%, below the frozen 5% no-regression gate. This is CPU application elapsed, not GPU or whole-game FPS. Actual normal original-input cold drive/station/save/load route: 489 source-paired handoffs per arm, gunner/commander/cupola/driver, 61/62 distinct original world XY positions; unchanged source FPS/one-frame requests. A later rAF callback is recorded, not a draw-completion fence. Final owning live browser/server closed 13:34:05.055 UTC; job 96529 terminal 0.

The separate exact texture-mask cache proposal passed fidelity but missed its frozen gain thresholds (1.31% edge, 3.13% rebuilt); excluded. The accepted HUD performance source remains byte-exact. A subsequently assigned Edge geometry optimisation belongs to the REA chat and must rebase on this actually installed epoch.

Canonical item dispositions, source snapshots, failed/partial attempts and receipts: `artifacts/tactical-complete-polish-20261014/plan.json`, `contracts-report.json`, `view-comparison.json`, `performance-report.json`, `live-summary.json`, `delivery.json`, `installed-verification.json`. Optional Impeccable package was unavailable and was not installed. Native GPU/device acceptance is not claimed by this pass.

## 14 October 2026: complete local browser reliability/usability pass

The23-item next-pass programme is installed locally. Visible file selection, prerequisite/error recovery, staged progress, save provenance/busy state, original-key-safe form editing, Game keyboard focus and fullscreen are verified through the real browser entry point. Restores prepare all fallible components before durable undo and commit; unavailable storage permits gameplay with an explicit warning and disabled browser checkpoint controls. Authored/original imports retain their pinned identities and full-resolution content. Local packaging stages a complete replacement and preserves recovery data even if both swap and rollback fail.

Receipts: `artifacts/abrams-next-pass-20261014/`. Node15 plus Python rollback6 checks, focused Python98(1skip), clean-source125(10skips), audio476WAVs/345captions with0errors, Godot viewer parse, actual browser29checks/3458 normal1-frame requests and website72-link/asset verification passed. Both normal PCKs7a14b802..., BUNDLEde7eb915... with45records;1119 unrelated presentation payloads and70 originals exact. Modernized and all art choices remain intact. Existing performance fixes retained, no extra FPS gain claimed. Source/package/resource epoch returned to the separately assigned map/performance owner. Nothing published.

Working if: the local bundle matches its verified hashes, checkpoint and startup recovery remain actionable, all modes preserve source-driven gameplay, and the separate performance experiment cannot silently enter this installed pass.

## 14 October 2026: full-experience36-item local programme

Completed remembered graphics and transient CLI choices, unavailable-import fallback with retained intent, browser5-channel mixer/default reset and MSAA/filter controls, compact keyboard disclosure, real stopped-runtime recovery, portable setup/thread/status/picker/recheck/scroll/About recovery, bounded owned launcher output/lifetime, Tactical guide wrapping/token search/counts/Escape/lazy lifecycle, and manifest-bound local distribution. Original guide data and Modernized visuals remain unchanged. Detailed list/dispositions: `_contprompts/abrams_full_experience_20261014.md` and `artifacts/abrams-full-experience-20261014/completion.json`.

Proof: menu270, quality531, audio116, reference search45, existing reference211 plus portable recovery; Mac native UI-only244checks/29screens; real browser29checks,364 normal1-frame requests, independent mode/HUD/quality/mix reload, actual worker fault/onExit0/error retention and hidden dead canvas. Node 24+bundle9, Python58(1skip), source-only 125(10skips)/515files, reference inventory and site72links/assets pass. A pinned Godot Web audio teardown race was repaired with two fail-closed anchored cleanup functions; all normal startup/mixing/licence bytes reconstruct exactly, seven pending/rejected/absent/normal-buffer regressions and the real early-exit path pass. Prior failed/partial attempts remain recorded.

Both normalPCKs580ce332..., GodotJSefb917..., BUNDLE3175224b.../45records verified after installation. Five logical presentation/setup scripts changed;1115 other PCK payloads exact. Protected Map1e8a..., Edgee663..., HUD/display794... and original inventory exact. Separate map/performance candidates excluded; no additionalFPS claim, Windows/Linux runtime or human acoustic proof. Last own browser/context/server closed16:28:51.979UTC, actual source/package/resource handback sent. No publication or foreign process action.

Nell changed the automation-browser rule to per thread/chat, persistently recorded in globalCodexAGENTS:190. Each thread still owns its isolated browser and cleanup.

Working if: local installed bytes match the confirmed candidate, all36 dispositions have their scoped receipts, original/full-quality/Modernized boundaries hold, and failed runtime recovery never leaves a dead frame presented as running.

## 2026-10-14: local reliability and player-control polish

Completed the23 warranted tasks in `_contprompts/abrams_reliability_polish_20261014.md`. Native audio menus now show exactly one checked entry for irregular saved gains. Native/browser full-quality reset restores 4× MSAA/16× anisotropy together while preserving mode/HUD/audio and reporting failed writes. Inactive browser player frames are hidden; early errors focus retry, stopped initialized runtimes focus Reload and retain the actual error through normal engine exit.

Export and authored-asset builds now use unique staging, diagnostic/file/audio-patch acceptance, source/target identity checks, cooperative writer/packager locking, handled-failure rollback and retained recovery journals. Obsolete managed files are removed only after acceptance, unrelated generated outputs remain intact. Both new builders and regressions are exported in the reviewed source kit. The actual pinned export and299 lossless authored assets passed private staging; all accepted authored payloads remain exact.

Verification: Godot 931 checks, native UI 11, actual browser 13(normal engine exit0), Node 24, builder 18, package 9, clean source-only 125(10skips)/520 files and website 72 links/assets. Scope excludes new 3D geometry/material work;1117 other PCK payloads remain exact. Both local packs 410f723e and 45-row BUNDLE 27851e29 were installed only after the other geometry chat released the finite reservation. Modernized rendering, original simulation, both upscale options and audio loader remain unchanged. Local only; nothing published and no foreign process action. Evidence, rollback backups and per-item completion are in `artifacts/abrams-reliability-polish-20261014/`.

Working if: exact quality/audio/recovery behavior is available locally, failed builds retain the prior managed output, the complete 23-item receipt matches installed bytes, and unrelated work/presentation fidelity stays unchanged.

## 2026-10-14: local import, startup and reference polish

Completed the 17 warranted tasks in `_contprompts/abrams_import_startup_polish_20261014.md`. Browser optional-ROM clearing preserves PC selection and gives clear PC-only retry feedback; unrelated folder extras no longer create false collisions. Required originals retain exact size/hash/collision verification and the pinned reconstructed ZIP. Desktop source rejects renderer preflight diagnostics even with exit0, bounds only preflight to 300 seconds, retains complete logs/current-error context, checks managed log leaves and removes only unfinished invocation-owned version staging. Originals, campaigns and accepted versions remain intact.

Keyboard HTML/PDF and native/browser runtime reference clarify browser modifiers, six graphics options, independent HUD and quality reset. Original manual data/35 controls, maps, model studies and field guide are unchanged. The three-page keyboard PDF and responsive HTML were rendered and reviewed. Browser 17 checks, Python 58 and 22 installed-reference tests, Node 8 (final shell 7), source-only 134 (10 skips)/520 files, website 72 links and actual pinned Godot preflight pass.

Both local browser builds carry the tested shell/import/asset changes, 45-row BUNDLE b1156c29 verified. PCK 410f723e, audio loader efb91721, all rendering sources and 298 other authored asset payloads are exact. Existing packaged desktop binaries were not rebuilt; native changes are source/source-kit behavior. No publication or foreign process action. Evidence, rollback backups and per-item receipts are in `artifacts/abrams-import-startup-polish-20261014/`.

Working if: valid originals tolerate unrelated extras, optional-ROM recovery works immediately, broken desktop preflight reports failure before gameplay, installed guide/bundle bytes match their verified candidates, and protected fidelity/player state stay unchanged.

## 2026-10-14: local build and installation consistency

Completed the 15 warranted items in `_contprompts/abrams_build_consistency_20261014.md`. Reproduced and repaired two integrity defects: native copy verification happened after version promotion and poisoned the build ID on failure; Web export could accept source edited during staging. New native candidates now validate payload, original files and archive before rename using captured hash-verified original expectations. Clean same-build retry works; accepted changed versions remain preserved. Web staging now rejects linked inputs, verifies raw copied bytes/inventory and checks one original source receipt before export, after export and after authored-asset staging. Ignored cache/bytecode activity remains harmless. Existing diagnostic, audio, asset, cooperative lock and handled-failure rollback gates are retained.

Proof: native 40, builder 24, packaging 9 and clean source-only 138 tests (10 skips)/520 files pass. A single real pinned private export passed six runtime-file checks, clean diagnostics and 1,125 source-input consistency checks. Its project and outputs were removed normally after receipt capture; own-process census empty. Independent verification finds all 45 normal BUNDLE rows, both PCKs/audio loader and 1,126 presentation files unchanged. Normal tuple remains BUNDLE b1156c29/PCK 410f723e/JS efb91721.

Delivery is local helper/test/documentation source only. Existing playable packs and packaged desktop binaries were not rebuilt or replaced, Modernized and both upscale options remain unchanged, and the separate geometry experiment remains excluded. These are sampled consistency checks, not an atomic editor snapshot or power-loss guarantee. No publication, cloud use, foreign process action or resource hold. Exact per-item proof and retained failure reproductions: `artifacts/abrams-build-consistency-20261014/`.

Working if: inconsistent copies cannot commit a new version, inconsistent export candidates cannot reach normal replacement, clean retry succeeds and the previously playable/personal data bytes remain intact.


## 14 October 2026: performance, controls and platform acceptance follow-through

Nell assigned the three remaining acceptance lanes, locally only. Controls are now verified and installed: real original boot, movement/keypad stop, distinct row/keypad keys, both release orders, NumLock-off Clear, outside-canvas key-up recovery, fresh focus press, held-fire repeat suppression, real Audio-popup closing/release and all four registered original station views pass 41 browser checks. Fixed two observed input defects without changing guest memory, emulated timing, gameplay authority or graphics. Native Keyboard original/physical/focus cases have zero failures, AudioMix 125 and PlayShortcuts 137 pass; source-only 141 tests (10 skips), 521 files pass. Both local PCKs 531f393c and 45-record BUNDLE 9010e27d match the tested candidate. Three input resources changed, 1,117 other runtime payloads exact against starting experimental 75fe6ca8. Modernized, Tactical rendering, audio loader and both upscale options retain their prior bytes. Existing packaged desktop binaries remain unchanged.

Performance remains unqualified. Independently checked 1,536 paired rows and all 60 complete PNG files, exact across all arms and normal cold. The existing loaded-host comparison had 2.6787% conservative rebuilt gain and 22.4703% baseline variation, failing the frozen thresholds and quiet admission. Fresh post-QA samples remained 0% idle. No additional loaded-host timing run, altered thresholds or whole-game FPS claim. The separately authorized experimental Edge/Map sources remain untouched.

Windows/Linux native graphics, acoustic and campaign acceptance remains unavailable without equipped x86_64 graphical targets; only local Apple Silicon and unsupported ARM Docker were discovered. Older platform binaries do not match current source. The current original-free portable input is rebuilt locally after source-closure repairs: bounded escaped/plain resource parsing, the missing actual effect-finish include, and seven exact historical comparison exceptions only in generic resource scanning. Runtime and explicit load/preload checks remain strict. Absent historical comparison modes are not claimed runnable. No originals or compiled trace cores are included in that input.

Exact dispositions and retained failed/incomplete attempts: `_contprompts/abrams_acceptance_20261014.md`, `artifacts/abrams-acceptance-20261014/installed-verification.json`, `performance-diagnostic-verification.json`, `final-admission.json`, `port-input-20261014-local-v2.json` and `output/playwright/abrams-acceptance-20261014/focus-repair-sequential/report.json`. First station captures were mid-transition; final captures wait for original plate registration. All own QA jobs closed; no publication, paid capacity or foreign process control. Remaining gates need quiet capacity and actual native-device access, not another cosmetic pass.

Working if: the current local tuple is exact, controls recover without stale or resumed trigger input, existing menu-close protection remains intact, and timing/native-device limits stay separate from passing browser/source checks.

## 15 October 2026: bounded Google Cloud QA and fresh portable setup repair

Actual Linux L4 testing recovered 1,536 paired sample rows, 52 identical matched screenshots, eight matching normal cold-load views and 48 map images. All 108 PNG hashes were independently checked against the recovered files. Map/source, HUD and isolated backend contracts passed. This does **not** qualify the edge optimization: the ordinary PC-only route intentionally leaves Genesis-donor-dependent edges inactive, and the during-arm host-idle gate also failed. No timing thresholds were changed and no speedup is claimed. The optional Genesis ROM was subsequently approved for private testing, but no valid ROM-enabled hardware timing run completed.

Native Windows Server 2022 x86_64 functional checks passed on a CPU-only replacement after Google rejected L4 capacity in multiple zones. Pinned baseline and trace DLLs built; keyboard, AudioMix 125, shortcuts 137 and 26 checkpoint tests passed. Actual ordinary boot, acceleration, gradual KP5 braking, three stable zero-speed samples across advancing read-only `0000:0e85` diagnostics, exact checkpoint state/sequence restoration and zero restore priming passed. Diagnostics remained separate from scanout-paired presentation. The checkpoint test fixture needed explicit Windows DLL unloading before temporary-directory cleanup; the original failed teardown remains retained.

The original-free Windows portable build, frozen PC/Genesis import and prepare, status, and native launcher invoke-status passed. Fresh-kit setup failed on a missing imported TTF resource and timed out. A later PowerShell retry returned empty logs and remains unverified. Repaired the local portable launcher to run the existing bounded asset-import and parse preflights before setup, retaining diagnostic logs and environment scrubbing. Local proof: 31 focused tests (one opt-in skip), 40 standalone runtime tests, and an actual silent Godot 4.7.2 reproduction that failed before font import and passed afterward. The corrected launcher has **not** been retested on Windows or installed in a new packaged build. Self-review: this launcher repair was produced and verified by this chat; Windows runtime acceptance is explicitly withheld.

All disposable VMs, disks and the private recovery image were removed after hash-verified result recovery; the task's memory-only SSH agent was closed. Conservative creation-to-deletion accounting totals 6,006.27 VM-seconds against 7,200 allowed. The conservative price estimate including a US$1 storage/network reserve is US$2.74, below the US$5 cap; the actual invoice is unverified. No AWS allocation, public game hosting, publication, original-game mutation, simulation/pairing change, or PCK/HUD replacement occurred. All 70 local originals, both installed PCKs `531f393c`, BUNDLE `9010e27d` and HUD `794202ea` were rehashed unchanged. Earlier unrelated dirty changes were preserved.

Remaining acceptance is genuinely incomplete: valid active-edge hardware timing and native Windows graphical/end-to-end frozen playback need available GPU capacity and a newly authorised bounded allocation. No background cloud test or automatic resumption remains active. Full receipts and failures: `artifacts/performance-edge-geometry-map-20261014/cloud-runners-20261015/FINAL-STATUS.json`.

### 15 October 2026: Native Windows graphics and fresh portable first-start verified

The isolated Google Cloud L4 WindowsServer2022 test completed eight current sealed-source station/mode captures plus campaign New/coldContinue on NVIDIA596.86 OpenGL. Actual uncached C-launcher setup and packaged InvokePlay driver/new/coldContinue pass. A real muted-launch fault was repaired: explicit --no-audio now also selects Godot's Dummy backend before its argument separator, eliminating WASAPI initialization errors while leaving normal audio selection unchanged. The unchanged game-side mute flag remains forwarded.62focused tests pass with one native opt-in skip; actual Windows rebuilt runtime passes with clean logs and source/original copy bookends. These are this chat's own build/test outputs, verified directly, not an independent review.

Private local Windows build62a744645007be1c27f1 is recovered at artifacts/performance-edge-geometry-map-20261014/cloud-finish-20261015/Abrams-Windows-muted-current.zip, SHA2ff8f6a858bcd1b473c5ae26479009e0021d3ca6973bb496905c6681f59f3d11; all RUNTIME payload hashes verified, no original game files included. Final Windows evidence tarSHA98217c32574d3495e6a230add38c58d2ec4d2f7897e7c59ecdbc237c4c5b8e49. Earlier fixture compiler failure and muted WASAPI failure are retained. The result covers frozen sourceZIP7b0201a7 plus the isolated mute delta, and excludes78 concurrent unrelated live-tree changes of unverified ownership. Installed web531f/9010/HUD7942 remain held. No publication or installation replacement.

WindowsVM and owned RDP/tunnel/credential are closed after verified recovery. Sequential LinuxL4g2-standard-16 bootstrap is active under the newly approved total5USD/7200VMsecond limit and fixed04:35UTC automatic deletion. Matched active-Edge performance remains unverified until its actual frozen gates finish. No whole-gameFPS claim.

### 15 October 2026: Matched active-Edge GPU qualification complete

The actual quiet Google Cloud g2-standard-16 L4 run7ce406d7-0c32-426a-9b8f-8981e5dd9e51 passes the unchanged strict ABBA gates:1,536rows with32positive driver/cupola Edge calls per arm; conservative rebuilt-renderer elapsed-cost reduction5.3698865%, conservative edge-cost reduction98.5567948%, baseline rebuild variation2.3896956% and mapping variation4.4121320%. During-arm host idle minimum89.8623%, with zero throttling and pressure/steal limits passed. This is renderer-work evidence, with no whole-gameFPS claim. Original fresh mask-texture uploads remain, candidate geometry builds stay at2 and baseline rebuild counters advance.

Root re-ran the frozen comparator against recovered raw rows, verified all108actualPNGhashes,60full matched/normal-cold exact images and48Mapimages, and re-ran the unchanged Map pixel/source/registration checks with only local path translation. Actual backend CPU/GPU mask, vertex/UV/colour/index, lifecycle, HUD338, Edge1643 and bounded-cache checks pass on the same NVIDIA ANGLE/Vulkan backend. Actual desktop OVERVIEW/compact LOCAL and cold-driver frames were opened for visual review. Existing metadata records canvas backing extent; full CSS-element PNGs include the edge row, and all full bytes remain exact without cropping or tolerance. The initial missing per-unit cgroup quota was caught before timing, retained and corrected in launch setup only, with all capacity/gain/fidelity gates unchanged.

Both installed531fPCKs,9010BUNDLE, HUD/Edge/Map sources and all70originals were independently rehashed exact. The already installed experimental geometry reuse is now qualified for this frozen tested tuple; no new install or publication was performed. Windows proof remains scoped to the recovered62a74464 build and exact isolated mute delta; unrelated live-tree source changes stay excluded. Final status/evidence: artifacts/performance-edge-geometry-map-20261014/cloud-finish-20261015/FINAL-STATUS.json and root-review/FINAL-VERIFICATION.json.

Every new task VM/disk/custom image is deleted, provider confirmed empty. Task SSH agent and Windows RDP/tunnel/temporary credential are closed. Conservative aggregate3,525.41VMseconds, below7,200; price upperUS$2.92 includingUS$1reserve, belowUS$5; invoice unverified. No active job or automatic continuation remains. Assigned frozen-candidate Windows/first-start/GPU qualification complete, local only.

## 15 October 2026: Whole-project audit and fix pass

**Audit.** A read-only, whole-project audit of `codex/modern-lowpoly`, including
the uncommitted multi-session WIP (snapshot base `1d039e0`), ran as a 292-agent
workflow (count reported by the workflow). 29 finder slices produced 275 raw
findings, 246 unique after deduplication. 223 survived adversarial verification
(three skeptics each for high/critical) and 23 were refuted. Report:
`abrams-audit-20261015.md` in the session scratchpad (not in the repository).

**Authorisation.** Nell: "Commit and push everything. Then, FIX EVERYTHING, NO
EXCEPTIONS, GET IT ALL FIXED AND BUILT AND DELPOYED END OF." The fix pass treats
this as her authorisation to remove decoded original PC content and raw Genesis
extracts from public (Web) and native distribution, deriving them at runtime or
import from the player's own verified files instead. It does not cover a
Git-history purge of the parts already published, which remains her decision.
Her standing rule sets the Git file limit at 100 MB: files up to 100,000,000 bytes
are ordinary Git objects.

**Fix pass.** About 15 fix agents ran concurrently with disjoint file ownership,
then two documentation agents. The subsections below record what each cluster
reported. Numbers come from those agents' own runs and were not re-measured by the
documentation pass unless stated. Everything is local only and not live. No build,
bundle, PCK, core rebuild or deploy ran in the fix agents. The lead runs those.

### Web publication boundary (rights-web)

Decoded PC recognition data (the five station plates, `expected.png`,
`faces.json`, ATBASE.BIN and CLIP.BMP indices, the arming panel) is now derived in
the browser by `web-prototype/derived_art.mjs` and no longer published. Raw
Genesis capture donors and the captured palette are withdrawn from the Web. The
browser derives the 64 effects from the visitor's verified ROM. Fallbacks are
recorded in `release-rights.md`. The publication list is
`tools/package/web-publication.json`: 166 files in two sets, 179 denylisted
decode hashes, 7 historical publications, and no exceptions (checked here). The
earlier open `pc-modern` catalogue exception was removed by splitting its decoded
`source_primitives` into a player-derived `source-shapes.json`. As of this entry
no browser or import step derives that file (grep of `web-prototype/`,
`tools/standalone/` and `web-publication.json`); the lead has the derivation on
the post-workflow integration list.

`tools.package.git_boundary` now has a 100 MB limit, rejects LFS, applies the
decode denylist, requires exact index membership for asset-part members, and
applies decode rules to superseded parts. The service worker is a streaming,
content-addressed cache. The frontend-music manifest text changed. Godot pins for
the five plates and `expected.png` now cover decoded RGB8 pixels. Asset parts
published from 10 to 15 October 2026 remain in Git history, pending Nell's purge
decision. The bundle under `website/dist/play/.generated/` has not been rebuilt.

### Native apps (native-standalone)

Native apps no longer bundle raw or decoded original data or the ROM-derived
frontend score. An import-time derivation table
(`tools/standalone/import-derived.json`) pins 25 files, 18 PC and 7 Genesis
(counts checked here), all reported byte-identical locally. They include 5 Genesis
plates decoded by a pure-Python port of ROM routine 9AFE/9B20
(`tools/standalone/runtime.py`), reported as 11 receipts and 105 chain entries
identical to unicorn. A schema-2 Genesis receipt cannot be satisfied by a
hand-written receipt. Other changes:

* junction guards are scoped to reparse tags;
* the portable workflow is split into a write-scoped fetch job and a read-only
  build job, with hash-locked dependencies installed before extraction, and
  native build files must byte-match the ref;
* setup requests go through `execute_with_pipe`;
* the portable launcher honours `--data-home`.

`NATIVE_RAW_WHITELIST` is empty (checked here). Losses that remain because they
depend on captures: Genesis mode, the map frame and the clipboard. The frontend
score is excluded.

### Trace core and GPL source (core-gpl)

The source bundle is restored for the 7-file patch set. It now imports
`tools.build_pc_trace_core.PATCHED_SOURCES` and defaults to the receipt's build
tree. The reported proof archive has sha256
`03ae42df0b4a0d78fb03dc1a5a27ccc49a60b382f7f7b0517c5b9a07e0928510`, 294 members,
core `b859afb1…`. The builder receipt now records a relative source path and the
resolved compiler, is written before the swap, and retains the previous core
under `.runtime/pc-core/previous/<sha256>/`.

Pending a core rebuild (source landed; pinned core `b859afb1…` unchanged; see
`pc-live-bridge.md`) [15 October 2026 note: all four are in core `37bff087…`,
installed later that day; see "Trace core rebuilt with RAM window bundles"
below]:

* the event-12 frame fence;
* frontend mask gating and the empty driver mask;
* strut-page arming and checkpoint-save validation, including the strut behaviour
  change;
* event 57 for non-world background calls.

Still open: Nell's decision on existing save slots after the rebuild, and the new
`trace_sha256`. Neither is recorded yet. [15 October 2026 note: both are now
recorded under "Trace core rebuilt with RAM window bundles" below: core
`37bff087…`, save compatibility waived.]

### Bridge host (py-host)

`--slim-samples` is used by desktop Play, and the Web edition always slims.
Snapshot runs get a fresh `.snapshot-overlay-*`. A `receipt.json` is required
for every restore. Capture-death recovery and quiet EPIPE/EINVAL shutdown are
added. There is a fifth host operation, `load_previous`. All are documented in
`pc-live-bridge.md`. `python3 -m unittest tests.test_pc_save_states` was run
here: 39 tests pass.

### Web runtime (web-runtime)

Each core runs in its own `core_worker.mjs`, which is terminated when a load
replaces it. RSS across loads went from 309 to 494 MiB (base plus 4 loads) to flat
(about 279 MiB over 8 loads, or 384 to 390 MiB over 4 loads on a busier machine).
Load time went from about 5 to 7 s to about 1 to 2 s. The desktop VGA RAM pairing
is ported, with frontend identity and SHAPE.TBL checks. The first post-restore
frame is held. JSON is serialised once. The state timeout is 300 s. These results
are verified in Node only; the browser smoke test is still pending.

### Frame and draw pass (godot-frame)

Fixes 19, 20, 21, 24, 102, 103, 104, 119, 200 and 222:

* The Tactical HUD is gated on graphics mode only, not `world_enabled`, so that
  fallback frames do not flicker between HUD styles.
* Every unsupported kind without trace evidence now fails closed: a pass with a
  non-empty `draw_pass.unsupported` list or a replay warning shows the exact
  original framebuffer.
* #104: the deep copy measured about 1.05 ms per pass.
* #21 rework: stable outline 17 to 23 us (was 15 to 16 ms after the first
  column-scan fix); traverse miss 0.52 to 0.71 ms (was 11.4 to 14.0 ms); driver
  validation 0.63 to 0.83 ms (was 16.3 to 21.0 ms).
* A null-background SCRIPT ERROR was found in `pc_draw_pass.gd:513` and fixed.
  The same error in `pc_tactical_foliage.gd:154` and `pc_tactical_effects.gd:123`
  was handed on as shared edits.
* Portraits are no longer gated on cockpit donors. Damage art remains inherently
  coupled to them.

### Modern effect ownership (modern)

The Modern effect ownership union is removed. Ownership is now exactly the
original opaque sprite runs. Under the fidelity boundary, the union could hide an
actor that EGA/Upscaled shows through transparent original pixels. The visible
consequence is that authored outer effect contours return to source-pixel steps
in Modern. Evidence is the headless `effect_ownership_contract` and
`test_pc_effect_inventory`; the native re-capture is pending. Restoring the union
needs Nell's agreement.

### Tactical particles (tactical; fidelity clause, `docs/GOAL.md`)

Cues derived from RAM speed, heading and position are removed: speed-gated
exhaust, heading drift, low dust and the missile travel-axis wake. The guided
flare keeps a motor glow confined to its own sprite rectangle. Vehicle fumes are
now identical idle plumes on every visible admitted vehicle, confined to that
vehicle's own painted pixels inside its drawn rectangle. A vent outside the
on-screen hull emits nothing.

This retracts the earlier rule that stationary engines are not assumed to be
running. The original never draws fumes, so **idle fumes on parked vehicles await
Nell's one-time confirmation**. If she declines, no vehicle fumes are emitted at
all; a motion-gated version is not an option. Re-enabling any motion cue needs
her explicit agreement. No earlier sign-off for the removed cues exists in this
ledger.

### Art and audio performance (art-audio; headless evidence)

Changes to findings 26, 105, 118, 120 and 122 to 127, as reported by the cluster:

* Motor-pool frontend:
  * mask decodes are cached by exact base64 key;
  * plate-8 and clipboard proofs are reduced to native byte-slice compares over
    mask-derived runs;
  * the arming fixture went from 33.94 to 1.91 ms per frame, with 1320 + 1320
    differential fuzz trials against `1d039e0` showing 0 differences.
* The STATUS plate-5 pristine proof is native.
* The cupola/driver donor alpha check and clear are native, with byte-identical
  output: 57.8 to 11.0 ms and 81.2 to 34.0 ms.
* Typography has a per-run cursor fast path, exact by construction.
* The Tactical fitted point size is memoised.
* Trims and the frontend keep persistent mask and source textures. The gunner
  trim skips the upload when its mask bytes are unchanged.
* The effects pool takes idle players first, then the one with the shortest
  remaining tail.
* START skips the full-frame hash when there are no intro fingerprints.

Frontend music is prewarmed at startup. Tracks are re-hashed once per session.
Later reloads in that session trust the manifest sha, file size and mtime (1 s
resolution). A same-size replacement within the same second therefore decodes
unverified until the next session.

Crew, information and Wilson portraits are now mipmapped (Wilson premultiplied).
The frontend shader samples the portrait in uniform control flow. Native
`--native` captures have not been rerun, so shader compilation and pixels are not
yet verified.

### Gates and evidence notes (gates-tests)

* The 2026-10-14 41-check browser acceptance had four flaws:
  * it used `.some` exactKeys semantics;
  * it set status before checking protected bytes;
  * it read speed from `window.__controls`;
  * it could not tell a latched key from a fresh one on immediate focus return.

  The harness is now strict and needs a rerun before that acceptance is cited.
* The 2026-09-28 soak evidence predates the 8x-only menu, so `test_pc_soak` needs
  a native rerun.
* The quoted native check totals in the 28 September entries count one
  constant-true `vehicle_art` check per frame. The tests now count it once per
  run, so a rerun reports smaller totals for the same evidence:
  * `pc-combat-loss-native-03`, 1,841 checks (Actual combat-loss flow entry);
  * `pc-warning-native-02`, 7,549 (Original warning voices entry);
  * `pc-radio-native-01` and `-02`, 26,142 (Original radio speech and Raised
    plateau entries).

  Those entries are left unchanged as history. Re-quote all of them from the next
  `VALIDATE_LIVE=1 ./tools/validate.sh` run.

### Documentation

Docs were brought into line with the changed behaviour. This covers protocol and
restore contracts, native and Web rights boundaries, the six graphics modes, the
HUD Style gates, quick-save confirmation, the AltGr limit, fast forward and Tab,
verifier acceptance rules and stale core pins. The 10 to 11 October 2026 gap
(browser publication and Tactical origin) now has a retrospective entry above.
The Tactical request is quoted from the Codex transcript. Nell confirmed the browser
public-use grant on 15 October 2026: "Public use of my remaster assets is fine."

### Other clusters (reported by their fix agents; not re-measured here)

* py-trace: round-form `colors` are published as [DS:359E, DS:359D], the same
  order as polygon colours. Alternating dithers use a compact
  `{y,left,right,colors:[even x, odd x]}` span that `round_runs()` expands per
  pixel (`modern-asset-register.md`). Native event 57 is described under core-gpl.
* tools-guards: `install_pc_bearings` admits custody-checked repairs and records
  `previous_take_sha256`. `verify_pc_audio_trace`, `verify_pc_readiness`,
  `verify_pc_dialogue`, `verify_pc_driver_overlay` and `verify_pc_text_trace`
  require a trace report against a distinct, pinned baseline core. Only trace
  halves need recapture after a core rebuild. Player-reference PDFs build with
  ReportLab invariant mode.
* play-shell: a quick save onto an occupied slot 1 needs a second press within
  four seconds. Load state offers the overwritten slot archive
  (`load_previous`). A load mutes presentation audio from the request; a save
  keeps it. Windows AltGr chords are reported as Ctrl+Alt, so those shortcuts are
  unavailable on layouts where AltGr+S/L/G types a character.
* packaging: the private kit re-imports Godot resources when its receipt, the
  Godot executable or `godot/.godot/` changes, and applies a 300 s preflight
  deadline. Build and verify inspect every member with the Git boundary rules.
* website: the Pages build job runs `python3 -m tools.package.git_boundary`
  before `website/verify.py` and the upload.
* promo: `tools/promo/brief.json` narration is the superseded v1 script. Each
  production's approved script lives with that production.
* source bundle: the corresponding-source README now names the bundle's own
  platform, toolchain and `dosbox_pure_libretro`/`abrams-trace` suffix, and
  repeats the receipt's recorded `make` arguments, including the Windows
  `LDFLAGS` (`tools.build_pc_trace_core.WINDOWS_LDFLAGS`). Any Windows or Linux
  source archive built before 15 October 2026 still carries the macOS-only
  build text until `portable-alpha.yml` regenerates it.

Working if: after the lead rebuilds the Web bundle, the trace core and the
native apps, `python3 -m tools.package.git_boundary --history` passes, the Web
and native editions derive every `runtime_derived` / `import-derived.json` path
from the player's files, and the pending items above have recorded receipts or
decisions.

## 15 October 2026: Trace core rebuilt with RAM window bundles and installed

**Authorisation.** Covered by the audit fix-pass instruction above. Nell waived
save-state compatibility for this rebuild: "No need for compatibility, it's not
proliferated yet." (relayed by the lead). Slots and checkpoints saved with the
previous core are not migrated.

**Native core.** `python3 tools/build_pc_trace_core.py --source
.runtime/checkpoint-date-20261013/source` built and installed the uncommitted
`tools/pc_core/` header set: AWB1 RAM window bundles for SIM events 26/28/29,
the driver-seen reset on checkpoint load, strut display-page arming, frontend
mask gating, event 57 and checkpoint-save validation (`pc-live-bridge.md`,
"Observer events changed in the 15 October 2026 core"). Receipt
`.runtime/pc-core/abrams-trace.json`:

* `trace_sha256` `37bff08762031c40fe5843e2be8dc98e6d5d777497284797590f7e6ec4fdc55e`
  (byte-identical to an earlier scratch build of the same headers);
* `trace_header_sha256` `ae4ab78203c2bb9b0ef619c52a0d3bd0c254012acd379b945dd1ec4cf58657f9`;
* `observer_checkpoint_header_sha256` `57b419c7dc3c964ae5cd5130306c73a9be6c115b0572246120c5116b72cbac2d`;
* `text_event_schema` 3, `message_event_schema` 2, `strut_event_schema` 2; save
  format 9; ownership, plate, state-overlay and baseline hashes unchanged.

The previous core `b859afb1…` and its receipt are retained under
`.runtime/pc-core/previous/b859afb15676cc7fc019154d84983ec40b139c2b813d1b11ce503328f8de28a5/`.
No Python, Godot or gate fixture pins the core hash; every consumer reads the
receipt, and `tests/gate_fixtures.json` pins captures only, so it was not re-pinned.

**Live check (installed core, read-only observer).** For every SIM 26/28/29
packet, the packet was compared with the reference bundle cut from full guest RAM
at that instant, and a bundle-fed `Collector` was compared with a full-RAM-fed one
frame by frame:

| Start state | Frames | Events 26 / 28 / 29 | Bundle / full bytes | Mismatches | Presentation diffs |
|---|---|---|---|---|---|
| `pc-source-bootstrap-02/mission-entry` | 720 | 529 / 0 / 192 | 47,682,686 / 472,514,560 (10.1%) | 0 | 0 |
| `pc-radio-scout-01/entry` | 720 | 648 / 0 / 208 | 56,607,718 / 560,988,160 (10.1%) | 0 | 0 |
| `pc-radio-scout-01/entry`, radio route | 7,316 | 13,323 / 7 / 0 | 881,802,072 / 8,735,948,800 (10.1%) | 0 | 0 |

400 native START frames delivered only events 10/11/12/26/27, with no 19, 24 or
31, and every frontend event 26 was the full 655,360 bytes. The destroyed-GPS
event-57 frame was not exercised.

**Web core.** `web-prototype/build_core.py` gained `--source` so it can build from
the receipt's tree. `.runtime/dosbox-pure-source` still holds the 12 October
patch set: a consent hook (`policy-gate-edit`) denied the copy of the 13 pinned
files into it, pending Nell's approval. Until it is synced, `build_core.py`
without `--source` refuses with "The local DOSBox Pure source differs from the
native pin: src/cpu/abrams_trace.h". The pins still require byte-identical
reviewed sources. Emscripten 6.0.10 built `core.wasm`
`c84edcbc036b09e510fda60df020c522d529bcf044f260e4ddc28d0f7cc06c2f`, and two builds
gave the same bytes. `build-info.json` records schemas 3/2/2. `build_observer.py`
and `build_web_source.py` ran (299 source files; the archive's headers match the
receipt). `test_core.mjs` passed (frontend kinds 10/11/12/26/27). `test_mission.mjs`
passed: scenario 6 gunner, fresh-core checkpoint restore, SIM draw observer and
desktop replay. `npm --prefix web-prototype test` passed 46 Node tests and 40
Python tests. Its asset-contract test printed "local generated assets predate
schema 3; rebuild with build_remaster_assets.py". `test_bridge.mjs` passed four
save/load cycles. `build_remaster.py` (Godot Web export) and `package_site.py`
were not run, so `website/dist/play/` still carries the previous Web core.
The GPL proof archive `python3 -m tools.standalone.source_bundle --output <scratch>`
(gzip tar, 294 members, core `37bff087…`) has sha256
`a9731b3e12e8313c7d57c26657fc575bf517304c390dc95d48cd9c3a1963f281`.

**Tests.** The ten targeted modules (`test_pc_trace_windows`, `test_pc_text_trace`,
`test_pc_message_events`, `test_pc_strut_trace`, `test_pc_render_trace`,
`test_pc_observer_checkpoint`, `test_packaging`, `test_pc_bridge`,
`test_pc_session`, `test_pc_ui_ownership`) ran 157 tests: 157 passed, 0 skipped.
That includes `test_private_runtime_asset_provenance`, which had errored against
the stale core.

Local only, not live.

Working if: `.runtime/pc-core/abrams-trace.json` pins `37bff087…` with schemas
3/2/2, `web-prototype/.generated/build-info.json` pins `c84edcbc…` with the same
schemas, and trace-half evidence captured with `b859afb1…` is recaptured before
anyone cites it as current-core evidence.

## 15 October 2026: Calibration Range title tank matched to the box cover

Nell asked for the title-screen tank to be a 3D 1:1 match of the restored box cover
(`branding/abrams-cover-remastered.png`), with no photo plate.

- **Camera.** Fitted to the cover in pixels of an 880-pixel-tall framing of the cover
  (cover rows 560-1440): focal 2000 px, camera at (2.195, 0.9, -12.721) in the hull
  frame, looking up 9.2 degrees with a 3.9-degree roll, hull pitched 2.9 degrees nose
  down. The six fender and headlight landmarks reproject within 1-7 px. `CoverScene.frame()`
  draws that framing right-aligned at full screen height with an off-axis frustum, so the
  tank keeps the cover's perspective beside the title column.
- **Model.** Hull front, fenders, headlight clusters, turret slab sides, cheeks, mantlet
  slot, bustle box with the two-disc-and-triangle marking, rack, cupola, open hatch lid,
  M2 with sight box, and both crew were placed by back-projecting the cover's outlines onto
  the fitted camera (turret traverse 0.7 rad). [Inference] The cover's gun cannot share one
  rigid pose with its turret, so the gun carries its own yaw (-0.54 rad) inside the mantlet
  to land on the cover's muzzle; only the title pose uses it.
- **Second pass.** The hull roof now sits at 1.3 m under a turret ring at 1.4 m, so the
  roof stays hidden behind the nose line and only the dark ring gap shows, as on the cover.
  Other changes: rounded fender tops with the seam below them, slimmer headlight housings
  with amber lamps, an upright triangle in the marking, and face-projected grime. The crew
  now hang from head positions measured on the cover, so the commander holds the M2 at chest
  height and the loader bends forward over the roof toward the gun.
- **Third pass.** The work was done in an isolated scratch project, so the Alpha 5 build
  running alongside it was not disturbed. Changes:
  - **Skirt plates:** the cover shows the right front skirt plate splayed toward the camera,
    which a straight skirt cannot show from this camera, so both front plates now splay
    0.3 rad, with a rolled lip and a raked lower edge.
  - **Gun:** rebuilt to the cover's proportions: a heavy boot at the mantlet, a tapering
    sleeve with one bore-evacuator bulge, a single joint, and the muzzle reference sensor.
  - **Turret and hull fittings:** the loader's M240 now points up and out as on the cover,
    the fender tops fall toward the rear so they stay hidden, the tow eyes are gone, and
    there is a pack by the commander's hatch and a worn roof edge on the slab sides.
  - **Armour finish:** pitted shading noise, mud flecks and dust specks.
  - **Foreground:** dense crumbs where the frame meets the ground, plus mud spray and denser
    thrown earth at the tracks.
  - **Sky and smoke:** soot pockets and fire-lit rims on the billows, sparse cinders, and
    smoke over the far turret cheek. Region colour means now sit within about 30 levels of
    the cover except the lower glacis, the foreground ground and the title-veiled corner.
- **Fourth pass.** Steered by a 40-pixel block colour-difference map against the cover; the
  mean block difference fell from 59 to 55 levels.
  - **Rack and markings:** the bustle rack rails now sit on the cover's back-projected
    positions with a slight sag toward the back. The triangle in the marking
    is now a real flat triangle, and the ink is dimmer.
  - **M2:** slimmer receiver with a feed cover, a barrel jacket and a flash hider.
  - **Dust:** bright fire-lit dust moved down into the foreground band, with smaller dark dust
    under the nose.
  - **Crew and sight:** dimmer shirt and sight box, so they no longer outshine the cover's.
- **Fifth pass.** Mean block colour difference against the cover is about 51 levels, down
  from 55; particle randomness moves it by about one level between renders.
  - **Dust:** placed by projecting every plume onto the cover framing. The dark, shadowed
    dust now rolls along the right flank under the turret overhang, the bright fire-lit dust
    is kept to a low band in the foreground, and low plumes roll along the ground.
  - **Thrown earth:** finer and denser.
  - **Headlights:** soft amber halo sprites around the lamps, on the title scene only.
  - **Commander:** goggles with round lenses on both crew helmets, and arms lowered toward
    the grips. The M2 is swung so its receiver side and ammunition belt face the camera, and
    the sight box shows a lit glass face toward the cover's right.
  - **Loader:** dark CVC helmet.
- **Sixth pass.** Mean block colour difference against the cover is about 50 levels.
  - **Dark band under the turret:** a dark well under the bustle overhang now fills the band
    below the turret side, where red sky used to show through.
  - **Smoke and dust:** fire-lit dust billows high behind the rear of the tank, the flame
    cores are hotter, the low left plumes are dimmer, and the headlight halos are smaller.
  - **Crew:** both figures have tapered, faceted torsos (waist, chest, shoulders) in place of
    capsules. The commander's arms are no longer mirrored: both gloved hands come together on
    the gun at chest height, as on the cover. The sight box hangs from a bracket on the gun
    cradle.
  - **Capture note:** in one `--capture` still the first menu button was not highlighted; a
    repeat capture had it highlighted. [Inference] The focus highlight sometimes lands after
    the first frame is captured.
- **Seventh pass.** Mean block colour difference against the cover is about 49-50 levels.
  - **Tracks:** the fronts are now visible under the fenders, as on the cover: mud-caked shoes
    carry grey-violet rubber pads.
  - **Armour and skirts:** the armour grit and specks are toned down, so the plates read as
    worn metal rather than render. The splayed front skirt plates take the hull paint rather
    than the paler fender dust.
  - **Thrown earth:** now coarse, angular clumps instead of round beads.
  - **Rejected:** a camera-side bounce light flattened the fenders to plaster and worsened the
    match.
- **Eighth pass.** This pass was steered by a fine-detail measure as well as colour, because
  the render's dust and ground were smoother than the cover's (detail energy about 4.5 against
  the cover's 7 in the lower half).
  - **Dust and ground:** the dust puffs now carry fine grit, and sand grains (dark, with some
    glinting orange) hang low around the tracks. The ground crumbs vary between wet loam and
    dry, dusty earth.
  - **Turret front:** the paint's rim term is cut from 0.25 to 0.08, and the cheek front face
    is now vertical, so the face reads dark as on the cover.
  - **Score:** mean block colour difference is about 49 levels.
- **Ninth pass.** Mean block colour difference, averaged over three renders, is about 47
  levels, down from about 49. The particles now use fixed seeds, but frame timing still moves
  single renders by about one level.
  - **Nose lip:** a brightness profile down the hull front showed the cover's lit, dust-coated
    nose band (nose-plane height 1.20-1.31 m, peak luminance 135) at about half that brightness
    in the render. A rounded dusty nose lip now carries that band, and the lower glacis below
    it is mud-brown rather than black.
  - **Turret and crew:** the commander's M2 is heavier and more upright. The sight box is a
    dark frame with teal glass on its right face, as on the cover, and the helmet ear cups are
    smaller. A sloped, dust-lit skirt plate flares out under the rear of each side bin.
  - **Rejected:** brighter dust past the far cheek, a bright plume behind the left rear, and
    two re-posed hunched loaders all scored worse or looked worse.
- **Tenth pass.** Mean block colour difference, averaged over three renders, is about 45
  levels, down from about 47.5. Each change was checked against the blocks it targeted:
  - **Pack:** the commander's dark pack is enlarged to the size the cover's back-projected
    outline gives. Its blocks fell from about 126 to 34.
  - **Loader:** a reaching arm now runs along the roof where the cover shows his sleeve
    (about 132 to 55).
  - **Far cheek:** a small fire-lit dust puff sits right of the gun root, where the cover shows
    lit haze over the far cheek (about 160 to 35, without spilling onto the dark mantlet).
  - **Sky:** the low glow fades toward the cover's right, where its smoke is dark.
  - **Headlights:** the right-hand cluster sits 0.07 m further outboard, as on the cover, so
    both lamps now land within 3 px of the cover's.
- **Eleventh pass (the crew).** Both crewmen were rebuilt from joints back-projected off the
  cover's figures, using camera-facing planes, with hands and elbows pulled toward the camera
  to reach the grips. The commander's joints now land within 3 px of the cover's, except the
  helmet, which sits about 15 px low.
  - **Commander:** a white shirt with loose sleeves under a black flak vest, with the open
    collar showing. His left arm is down by his side, both gloved fists are on the M2's spade
    grips and back plate, and his face is shadowed under the goggles.
  - **Loader:** in desert khaki, risen out of his hatch and bent forward over the roof toward
    the gun, head down, without goggles.
  - **Helmets:** a CVC shell with rim and large ear cups.
  - **Builder:** `_man` builds each figure: a loft torso from hip to shoulder line, optional
    vest, jointed sleeves and fists. `_head` builds the face, shell, cups and goggles.
  - **Fix:** the first head basis was mirrored, so the shells rendered inside out; it is now
    right-handed.
  - **Score:** the crew region's mean 20-pixel block difference fell from about 67 to about
    60; the whole frame is about 45.
- **Twelfth pass (heads and cloth).** Nell's screenshot showed skull-like heads with ball
  helmets.
  - **Heads:** `_head` now builds a CVC helmet: a hemispherical dome down to the brow, a padded
    nape piece, a brow roll and ear cups at eye height. The commander's goggles are two matte
    lenses in a rubber frame. Each face has a wider jaw and a nose, and a stand-up shirt collar
    closes the neck.
  - **Loader's helmet:** a lumpy, dusty cloth scrim.
  - **Cloth:** a new cloth shader puts creases with lit ridges on the commander's white shirt
    and a subtle three-colour desert camouflage on the loader. Sleeves are fuller.
- **Winding fix.** The faceted hull and turret panels were wound inside-out (Godot front
  faces are clockwise), so their lighting was inverted; `_tri` now emits clockwise faces.
- **Look.** Linear tonemap with no contrast adjustment; a low key light from the cover's
  left; fire rim light that skips the ground layer; textured dust plumes and thrown earth
  at the tracks; sky smoke with fire on the cover's upper left and a red band behind the tank.
  Title veils now darken only the title column, and the range landscape is hidden on the
  title screen. Mean colours over 14 cover regions (sky, turret side, fenders, lower plate,
  turret front, barrel, dust) are within about 30 levels of the cover except the upper-left
  sky under the title veil and the dusty foreground ground, which stay darker.
- **Checks.** `GEOMETRY: 60000 upward normals and complete range bounds verified`;
  `RUNTIME_SMOKE_PASS`; `SIMULATION: 1162 checks passed`; `--capture` stills of the title,
  gunner and cupola views inspected.

Working if: a `--capture` 01-menu.png overlaid with the cover framing puts the headlights,
fender tops, turret slab and muzzle within a few pixels of the cover's.

## 15 October 2026: Standalone Alpha 5 built, notarized and published

**Authorisation.** Nell: "FIX EVERYTHING, NO EXCEPTIONS, GET IT ALL FIXED AND BUILT
AND DEPLOYED" (relayed by the lead), covering the build, notarization, portable
dispatch, public release and site update. Save-state compatibility was waived for
the new core.

**Version.** `tools/standalone/build.py` VERSION `0.1.0-alpha.5`, CFBundleVersion
`31` (alpha 4 was `30`), `godot/project.godot` `config/version` to match (commit
`6ac9b80`).

**macOS.** Built from the clean `9cb9336` tree with the existing
`.runtime/app-build-venv` (PyInstaller 6.22.3, Pillow 12.0.0, Python 3.14.8) and a
fresh `.runtime/app-build-cache-alpha5`. Every older cache predated the
`python`/`cache_tag` freeze keys. The kit differs from the release commit only in
`tests/test_standalone_runtime.py`, a test fixture.

* Unsigned build `71fc11aacb155644ad55`, 1,353 files, 84 Mach-O, no originals and
  no external dylibs. Kit core `37bff087…`, 26 derived rows including
  `local-art/pc-modern/source-shapes.json`.
* Developer ID signed build `0c4842b0d9a008c4f167`: 87 targets, hardened runtime,
  secure timestamps, core text unchanged.
* Signed-app smoke with a scratch data home:
  * PC and Genesis import passed and derived `source-shapes.json`
    `3be92319…`, matching the pin.
  * Prepare passed.
  * `--play --no-audio --capture --capture-station cupola` cold-booted into SIM
    with graphics `tactical` and HUD `tactical`. It reported "Modern geometry
    preloaded: 57 source shapes" and 73 samples, exited 0 and printed no script
    errors. The captured frame was inspected.
* Notary input `Abrams-0.1.0-alpha.5-macOS-arm64-notary-input.zip`
  `129ec620c09fd0b53850d9f6ad08112b8f30604a320fe1fc2984e450b920590b`.
  Submission `eb640586-15a0-4e00-aa90-ab643dd0dc5d`: Accepted, "Ready for
  distribution", no issues in the downloaded log.
* Stapled and validated. Strict codesign and Gatekeeper `accepted,
  source=Notarized Developer ID` passed on both the app and the copy extracted
  from the release ZIP.
* Release ZIP, built after stapling: 321,901,413 bytes,
  `cabd9c01743c52d4e14319d33fb148fddddc3b5ea5e10c96c903dd15f111159c`.
* GPL source `dosbox-pure-abrams-source-macOS-arm64.tar.gz`
  `a9731b3e12e8313c7d57c26657fc575bf517304c390dc95d48cd9c3a1963f281`. Its
  `CORE-BUILD.json` names `37bff087…`, and the archive is byte-identical to the
  audit-day proof archive.

**Windows and Linux.** The original-free input was exported by
`artifacts/release-20261001-portables/export_input.py`, then checked with a local
copy of the workflow's guard and by comparing all 1,101 tracked members with their
commit. It was uploaded to the private alpha.3 draft and never to the public
release. Three runs failed, and each cause was fixed before the next dispatch:

1. Run 38741813182: upstream schellingb/dosbox-pure rewrote its history, so pinned
   `73e03aa` shares no ancestor with its `main` and a default clone lacks it
   ("unable to read tree"). The workflow now fetches the pinned commit by SHA (tree
   `e8771cbd`, identical to the local checkout). Fixed in `9cb9336`.
2. Run 38742575255:
   * Windows: the runtime test fixture wrote `str(relative_to)` payload paths,
     which have backslashes on Windows, and `prepare_install` now validates names
     up front. Fixed in `5fc5e37`.
   * Linux: the frozen setup smoke ran `portable_setup.gd` on a never-imported kit.
     `pc_interface_theme.gd`'s preloaded TTF failed to compile and `--setup-smoke`
     never quit. This was reproduced locally (alarm after 45 s). The workflow now
     runs `--editor --import` on the kit first, as the launcher does, after the
     ZIP is sealed. Fixed in `f9b7872`.
3. Run 38744191141: two new corrupt-copy tests patched only `shutil.copyfile`, but
   on Windows `copytree`'s `copy2` uses CopyFile2. The tests now route `copytree`
   through the same hook. This was verified by emulating a `copy2` that never calls
   `copyfile`: 3 failures before the fix, OK after. Fixed in `f9b7872`.

Run 38746120300 used input asset 644014485,
`e83f9e1f25348c1912c3fb8133ee6a1fde9bd640eb061bfe20d35d3c8e9b257e`, from
`f9b7872`. It passed on ubuntu-22.04 and windows-2022:

* 147 tests OK;
* `PC_BRIDGE_TRANSPORT: 12 checks, 0 errors`;
* `PORTABLE_SETUP_RECOVERY: PASS`;
* `PORTABLE_SETUP_SMOKE: PASS`.

A local re-audit (alpha 4's `audit_fresh.py`, adapted) checked member safety,
original and derived hashes, credential signatures, manifest closure against the
input, build-id, Linux exec bits, and each core against its source archive's
`CORE-BUILD.json`:

* Windows: `Abrams-0.1.0-alpha.5-Windows-x86_64.zip`, 324,686,096 bytes,
  `f22bede94b1b54cfa4030c02e5ed9d911df80d739f0ab1bdc80ac9bd3391bab0`. Build
  `154c3608eaab61679348`, core `df3bb6ce…`, source
  `c1149bfc8672113a75514c0f476ec88d8d4eb45dc58fc56ea05483a203da4047`.
* Linux: `Abrams-0.1.0-alpha.5-Linux-x86_64.zip`, 336,625,228 bytes,
  `53fb1d2f5c3197bc6e08e4ea96f69778b450b44cbc335503e24894ab26338f19`. Build
  `d1878c0f113a5ba0f752`, core `1589d8d1…`, source
  `c1f39ad962197a61aec54402c2d670c7bd0d9df7fb00c995d3f255a079bd56ed`.

**Release.** https://github.com/NellInc/Abrams/releases/tag/v0.1.0-alpha.5 is a
pre-release in the alpha 4 format. It holds the three app ZIPs, three source
archives and `SHA256SUMS.txt`
(`3db910a87cb254725d2cdfecaa5b5068b0d71294a684140508782b92b79233b7`). The
website, `llms.txt`, `verify.py` checks and the version references in these docs
now name alpha 5. Local evidence (ignored): `builds/alpha5/`.

**Not verified:** full missions on any platform, graphical playback of this
Windows/Linux build, and the Modern/Tactical frame-rate target.

Working if: `gh release view v0.1.0-alpha.5` lists those seven assets with matching
digests, and https://abramsremastered.com/ serves alpha 5 download links.

## 15 October 2026: Remaining calls made on Claude's judgement

Nell, 15 October 2026: "Fix everything according to your best judgment please", about the
items left open (history purge, voice keychain item, Tactical map threading, native Genesis
captures).

- **Voice keychain item.** Crew-voice generation and transcript checks now read Nell's
  personal Google key (`GOOGLE_API_KEY` / `nellwatson`) instead of the AI Guardians
  project's key; see `docs/voice-workflow.md`.
- **Tactical map threading.** The LOCAL map rebuild stays synchronous, because presentation
  never lags the original frame it accompanies; see `docs/graphics-modes.md`.
- **Native Genesis captures.** Native apps and the Web edition fall back to original PC
  pixels where captured Genesis screens would be used; this is accepted and recorded in
  `docs/playability-status.md`.
- **History purge.** Carried out on 16 October 2026, after Alpha 6; see "16 October 2026: History purge of decoded Web asset parts".

Working if: these three documents carry the decisions, and `tools/generate_crew_voice.py`
defaults to `GOOGLE_API_KEY` / `nellwatson`.

## 16 October 2026: Alpha 6 built, notarized and published

**Authorisation.** Nell, 16 October 2026: "get everything formulated for a release, and
uploaded", then "Get it all live". She chose the authored intro shot ("Animate it") after
being told the original pops in 7 frames.

**Defects fixed before release** (Nell's reports this session):

1. "The animation of the tank shot is missing from the intro." The original PC draws its
   four poses in 7 frames and holds the last. Traces from both the cold-boot and neutral
   routes bind every pose. The fix is the authored shot recorded in
   `docs/genesis-intro-integration.md`.
2. "The menu is also very small, small buttons." This was the macOS launcher: fixed
   760x610 points on a 1728x1117-point display. It now scales from 1x to 2x, and the
   About panel grows to show its whole text.
3. "Try to avoid any need for a scrollbar." The portable setup fits its height to its
   content after the OS window exists. Before, its size was never applied: it opened at
   the project override. Its reader is laid out in logical units when content-scaled.

**Commits:** `ccdc7fd` (version 0.1.0-alpha.6, bundle 32), `30783d3`, `bc5415c`,
`146bbfb`. The release commit adds the site and docs.

**Gate.** `./tools/validate.sh` on `146bbfb` completed: `VALIDATION_COMPLETE`, 927
Python tests OK, 71 skipped.
* Two earlier runs failed on `test_both_pipes_exceed_pipe_capacity_and_keep_only_tails`
  (3 s timeout). Kernel pipe memory was exhausted again: pipes held 512 bytes, and
  `codex` PID 39290 held 1,054 pipe handles. That process is not ours and was left
  running. The test passes alone.
* One earlier run caught a real bug, fixed in `146bbfb`: the viewer touched
  `frontend_art` on the scheduling test's stub frame.

**macOS.**
* Unsigned build `4e5cd81ae862a4243eb9`, 1,353 files, no originals. Signed build
  `60b1fe1028a52fabbbc8`, 87 targets, core text unchanged.
* Smoke with a fresh profile: PC and Genesis import, `source-shapes.json` `3be92319…`,
  prepare, and a cold boot into the Tactical cupola (no script errors). The launcher was
  captured on screen at 1064x886 points.
* Notary submission `c15859b3-4728-449a-a32b-b1495bf7fa10`: Accepted, no issues.
  Stapled; Gatekeeper accepted the app and the copy extracted from the ZIP.
* Two earlier signed builds were superseded and deleted: `a633b502…` (notary
  `136be7c5…`) and `ad7b1699…`.

**Windows and Linux.**
* Input `port-input-alpha6b-20261016.zip`: asset 645759293,
  `7968045aacf44246250197d6f20d8b22e7c84f9b4daae62bde2aaa8df8271f5a`. It is on the
  private alpha.3 draft only. A local copy of the fetch guard passed, and all 1,101
  tracked members match HEAD.
* Run 38835631121 passed on both OSes: 147 tests, `PC_BRIDGE_TRANSPORT: 12 checks, 0
  errors`, `PORTABLE_SETUP_RECOVERY: PASS` and `PORTABLE_SETUP_SMOKE: PASS`. Run
  38835106352 (input `349c2069…`) was cancelled because it predated the fix.
* The adapted archive audit (build-id now includes `derived`; secret patterns are tuples)
  passed for both. Windows: build `36ed23c3f2462e898684`, core `00ce8483…`. Linux: build
  `692ab6727667978242e0`, core `1589d8d1…`.
* The Windows core differs in bytes from Alpha 5's `df3bb6ce…`, although the source is
  the same. Save restore pins the exact core, so Windows Alpha 5 save states need Alpha 5.
  The release notes and site say so.

**Assets (SHA-256).**
* `Abrams-0.1.0-alpha.6-macOS-arm64.zip`, 321,920,889 bytes: `c4d77c71eda2a878983ef1ba936e40d568c66dfd9def5f1b46574a0eb601365d`
* `Abrams-0.1.0-alpha.6-Windows-x86_64.zip`, 324,704,477 bytes: `a57ae05476229f111cc307cdef133c7ea8a2042648493a0491409d5ee7da5387`
* `Abrams-0.1.0-alpha.6-Linux-x86_64.zip`, 336,642,498 bytes: `859fa531fe22e6915f51356395421e9c07fa92892eb88a6e7e521d28f81c3e6b`
* macOS source `a9731b3e…` and Linux source `c1f39ad9…` are identical to Alpha 5's.
  Windows source: `f2332d91ec4d0500bfad5b504467137a812d8bd0eb4076a2540188457771cfcd`.

**Web edition.** Rebuilt the Godot pack (`build_remaster.py`) and the observer/Python
source (`build_observer.py`, needed for `tools/generate_crew_voice.py`). The asset parts
are byte-identical, so no new archive blobs. The core was unchanged and not rebuilt.
Passed: the node core, mission, bridge and map tests, and `website/verify.py`.

**Not verified:** full missions; the Web edition's intro shot in a browser (same code,
and its worker sends `sequence`); Windows/Linux graphical playback and their scaled
setup window.

Working if: `gh release view v0.1.0-alpha.6` lists the seven assets with these digests,
and https://abramsremastered.com/ serves alpha 6 links.

## 16 October 2026: History purge of decoded Web asset parts

Nell approved purging the published Web asset parts that carried decoded original data
("Ideally, if it's not too difficult"; then "Fix everything according to your best judgment").

- **What changed:** six blobs, the earlier versions of `website/dist/play/.generated/remaster-assets-0*.zip`,
  were each replaced by a small valid zip holding `REMOVED.txt`. The removed blob IDs are
  0b4f8178…, 602a5657…, 70e9cb3a…, b00442e3…, c5fc48c7… and e7d049f2…
- **Method:** `git filter-repo` deadlocked, because kernel pipe memory on this machine is
  exhausted by other processes, so the rewrite went through files: `git fast-export` to a file,
  a stream rewrite (`builds/purge-alpha6/` holds the tooling), then `git fast-import` into a
  fresh repository.
- **Checks before the push:** trees were identical for `main`, `codex/modern-lowpoly` and
  both release tags; 160 of 160 commits were present; all six blobs were absent; and
  `git_boundary --history` passed.
- **Push:** the managed hook blocks agent force-pushes, so Nell ran the lease-protected push
  herself (`builds/purge-alpha6/push.sh`).
  - Branches: `main` and `codex/modern-lowpoly` went from 91959e0 to 718ca81; the two closed
    Codex branches were rewritten.
  - Tags: `v0.1.0-alpha.5` went from 162335b to ad8c69b, and `v0.1.0-alpha.6` from 91959e0
    to 718ca81. Tags alpha.1, .2 and .4 were unaffected.
- **Local checkout:** realigned with `git reset --mixed origin/codex/modern-lowpoly`; its tree
  was identical (2474aa94), so no working files changed.
- **Still open:**
  - `refs/pull/1/head` and `refs/pull/2/head` are read-only on GitHub and still reach the old
    commits. Nell is to send `builds/purge-alpha6/github-support-request.txt` to GitHub Support.
  - The Codex worktree `~/.codex/worktrees/promo-v9-publication/Abrams` (local branch
    `codex/tactical-site-gallery`) is on the old history and was left to its owner.
  - The pre-purge backup, `builds/purge-alpha6/backup-before-purge.bundle`, is kept until Nell
    confirms.

Working if: `git ls-remote origin` shows `main` at the rewritten head, `git cat-file -e` fails
for each removed blob in a fresh clone, and `git_boundary --history` passes.

## 16 October 2026: Pre-rule app downloads withdrawn

Nell approved withdrawing the public app builds that predate the 15 October 2026
distribution rules ("yes please").

- **Evidence:** the Alpha 4 Linux zip ships 209 entries under the paths those rules now
  exclude: `kit/local-art/genesis/source/` (including `*-original.png` extracts),
  `kit/local-art/pc-ui-v2/` and `kit/reference/`.
- **Removed:** the app downloads from `v0.1.0-alpha.2` (macOS) and `v0.1.0-alpha.4`
  (macOS, Windows, Linux). Their release pages stay, each with a "Withdrawn 16 October
  2026" note pointing to Alpha 6.
- **Kept:** the DOSBox Pure corresponding-source archives and the checksum files, for the
  people who already downloaded those builds (about 46 downloads in all).
- **Private alpha.3 draft:** 16 superseded port-input kits were removed. Only
  `port-input-alpha6b-20261016.zip`, the input for the current Windows and Linux builds,
  remains. The draft still holds its own Alpha 3 app zips, which are not public.

Working if: `gh release view v0.1.0-alpha.4` lists only the three source archives and
`SHA256SUMS.txt`, and the old Alpha 4 download URL returns 404.

## 17 October 2026: Local Blender Tactical vehicle pair

Nell approved the first M1A1/T-62 pair after asking for higher-quality Tactical
models and textures. The editable packed master is
`local-art/pc-tactical-vehicles-v1/vehicles.blend`; the same folder holds GLBs,
master bakes and the three runtime atlases. The source-bound builder and an
optional, atomic loader are in source. Persistent GPU face meshes replace only
actually observed source primitives in Tactical. Original simulation, ownership,
incumbent models and the other modes remain authoritative.

Native pair: 27,410 checks, zero errors, fourteen views and zero outside-owner
pixels. Additional near/edge/overlap run: 27,301 checks, zero errors. An original
game gunner approach completed using the existing mission snapshot, with two
upgraded T-62 actors. Clean-source kit: 210 tests, 22 skips, 551 files. All 68
original pins and the incumbent catalogue/builder match their starting hashes.
Full evidence and limits are in `docs/modern-asset-register.md` and
`artifacts/tactical-vehicles-20261017/`.

The broader graphics-mode check remains incomplete because an old cockpit
fixture mask is absent. Focused native Modern restoration passed independently.
The models retain the source's coarse proportions. No other catalogue model,
standalone app or published build was replaced. Local only.

Working if: the optional pair appears only in Tactical, missing optional files
retain incumbent rendering, and the documented native checks report zero errors.

### Silhouette and proportion revision

Nell then asked for much more realistic silhouettes and proportions while
preserving original gameplay. Rebuilt the M1A1/T-62 hulls, turret profiles,
running gear and fittings in Blender; the former roof-gun sheets are replaced.
The original engine retains hit regions, targeting, movement and damage, and
the original owner mask still limits outward coverage. Each complete visual
part requires a near-rigid pose validated against all observed vertices in its
own source group; otherwise the per-face GPU fallback remains available.

Final local assets: 7,122 T-62 and 7,814 M1A1 runtime triangles. Native gate:
59,634 checks, zero errors; fourteen Modern views remained pixel-identical,
with zero visible pixels outside original ownership. GPU readback and actual
captured integer poses passed. Final source kit: 210 tests, 22 skips, 551 files;
three final authoring checks passed. The viewer completed a new 36-sample
snapshot-based gunner capture with the revised pair. All 68 original pins and
the incumbent catalogue/builder are unchanged. Evidence:
`artifacts/tactical-proportions-20261017/`, especially `accepted/`,
`original-approach/` and `completion.json`.

Same author performed the modelling and mechanical review. Outward fittings
can still be trimmed by original visibility, and the visual hull does not
replace the original hit regions. Water commit `9bd2914` was made by its owning
chat during this work; its hunks are preserved. Vehicle edits remain unstaged.
No installed app or published build was updated. Local only.

Working if: independently observed parts follow their own original poses,
original owner coverage is respected, Modern images remain unchanged and the
native receipt above is reproducible with the installed local pair.


## Tactical full vehicle roster, 17 October 2026

Nell approved extending the accepted M1A1/T-62 detail and realism to the rest
of the tactical vehicle models while preserving original gameplay. Completed
all 34 renderable vehicle/state definitions: 115 through 144, 159/160 and
163/164. Weapon crews and unresolved A-10/MiG placeholders stay incumbent.

Implemented five source-owned geometry families, a resumable per-model Blender
bake/export builder and a complete three-bank runtime bundle. Accepted pair
triangles/UVs/map bytes remain exact. New tanks/carriers/scouts/truck/Hind and
collapsed wreck families have independent forms and original group custody.
Baked aliases are expanded only after ordered source/owner/root and authored
geometry/UV-basis proof. The loader atomically selects the complete roster,
independently validated legacy pair, or incumbent rendering; pooled group and
face paths bind their own bank without extra shader samplers.

Native review caught and fixed a real transverse Hind rotor overpaint. Only
observed two-point primitives from the admitted model registry receive the
optional compensated ownership blue byte 64. Round writes remain 255, ordinary
fill stays 0, and source painter order remains authoritative. The dedicated
vehicle shader rejects protected writes; common surface/water shader bytes and
Modern's default masks remain unchanged.

Proof: 49 Python tests, 680,246 headless checks and 682,193 native checks passed.
The final native sweep covers 206 views across all 34 states with zero owner
escape, exact Modern restoration and unchanged packets. Both original Hind
rotor states retain every measured line pixel (873/1,198) with zero loss and
sampled exact byte 64. Original source lines, group motion and round-command
precedence remain tested independently of authored body geometry. Headless
format fixtures and native pixel checks are split by backend; the existing
120-second deadline remains enabled.

Evidence: `artifacts/tactical-roster-20261017/acceptance.json`,
`accepted-headless.log`, `verified-native.log`, `python-final.log`,
`verified-native/report.json` and `roster-native-contact.png`. Editable masters,
GLBs and baked maps remain under the two local Tactical asset directories.
No simulation/input/bridge changes, original file writes, installed-app update,
commit, push or publication was performed. Status: local only.


## 2026-10-17: Tactical proportion quality pass

Nell requested a quality pass after the full roster, identifying the Bradley as
too squat. Eleven intact models now have corrected reference-led proportions:
Bradley/M113 tall troop bodies and smaller circular running gear, Bradley twin
TOW housing and infantry fittings, M60 casting/cupola and fender-mounted storage,
BMP roof-adjacent ATGM equipment, narrower BTR/BRDM bodies and shorter Soviet tank
gun overhang. BRDM has a longer boat hull and an open rack under its source-pinned
roof equipment. Native inspection caught and corrected a roof-equipment mask
slicing regression before acceptance. The strict source mask still trims small
tyre/fitting edges in some views; original gameplay/hit regions stay unchanged.

Revision4 contains 171,594 triangles in the same 34 states. The 23 unaffected
catalogue entries and accepted pair maps remain exact. All 68 original inputs,
Modern catalogue/builder and common surface/water shader retain prior hashes.
Editable Blender masters, GLBs and baked maps are installed in the local roster
bundle; original and first-quality bundles are retained under the evidence folder.

Proof: 50 asset tests and 10 validation-runner tests passed. All six format cases
passed under the unchanged 120-second guard. Two native partitions passed with
685,591/685,573 checks, zero errors; their exact union covers all 206 expected
views, unchanged packets, zero owner escape and exact Modern restoration. Both
Hind states retain all 873/1,198 original line pixels. The validator runs the
complete fixed case inventory and validates exact success receipts. Earlier
monolithic/combined-format deadline failures are retained, with no false green.

Evidence: `artifacts/tactical-quality-20261017/acceptance.json`,
`dimensions.json`, `quality-notes.md`, `format-0.log` through `format-5.log`,
`native/aggregation.json`, `native/report.json`, `bradley-before-after.png`
and the three fleet contact sheets. Status: local only. No installed-app update,
commit, push or publication performed.


## 2026-10-17: Tactical visibility-mask correction

Nell approved fixing the remaining mask trimming while retaining original
gameplay. The old final-owner equality test clipped new tyres and roof fittings
against the legacy outline. The BRDM reproduction measured 1,657 missing pixels.

The optional Tactical mask now distinguishes guarded nonterrain pixels (8),
ordinary terrain/background (0), protected original lines (64) and round writes
(255). The four-sampler vehicle shader accepts its own ordinary coverage or
earlier background, rejecting all other original target pixels and later owners.
Source command order, original queue/group admission and fitted poses remain
unchanged. Default Modern/fallback masks and the common surface shader remain
exact. No new viewport, CPU triangle traversal, gameplay readback or asset rebake.

The protection is pixel-local: the improved outline can occupy empty pixels
beyond an old occluder footprint, and overlapping authored-only extensions use
native mesh depth. Whole-object old-raster visibility parity is not claimed.
Hit regions, targeting, movement, damage, input and original simulation code
were not changed. GOAL and the asset register now state this boundary explicitly.

Proof: both native partitions passed under the unchanged 120-second guard,
685,591/685,652 checks, 206 distinct views over all 34 states, zero forbidden
pixels. Twelve unmasked-geometry coverage comparisons have zero missing eligible
pixels or protected-pixel leaks. All 1,657 BRDM pixels are restored. Every prior
Modern screenshot (206) is byte-identical. Both original rotor sets retain all
873/1,198 pixels. Headless partition 0 passed 684,536 checks, 60 Python tests
passed, original reference inventory and authored bundle hashes are unchanged.
Two initial focused runs failed on malformed/sample-edge test fixtures; logs
are retained, the corrected native partition passes those same cases. The
implementing chat also performed final visual inspection; the independent
advisor was read-only and did not replace root verification.

Evidence: `artifacts/tactical-visibility-20261017/acceptance.json`,
`aggregation.json`, `native-1/visibility.json`, both native logs and the before/
after and full-roster contact sheets. Status: local only. No installed-app update,
commit, push or publication performed.


## 2026-10-17: Tactical cosmetic dynamics

Nell requested a Tactical dynamics pass preserving gameplay, saves and other
modes, with native and browser verification. Added a bounded spring response
from original travel/speed and accepted cannon dispatches, including muted shots.
Gunner upper housing, Cupola and Driver sample their own verified armour only;
world camera, aperture, silhouette, instruments, fastener cores and aiming stay
fixed. The registered impact donors 0/1 receive short ballistic colour paths
inside their unchanged alpha/ownership, with no collision, debris or guest state.
Explicit clocks freeze on focus/menu/original pause and reset across loads,
stations and mode changes. Browser startup reduced motion and the native
`--no-tactical-dynamics` opt-out keep the presentation static.

Armour motion is visible with Restored HUD. The existing panoramic Tactical HUD
covers that armour and retains its fixed optics; impact sparks work with either.
This is cosmetic weight response, with no physical suspension or ragdoll solver.

Native OpenGL and actual windowed Chromium WebGL each passed 217 focused checks,
including predecessor-exact neutral/five other modes, fixed Gunner aperture and
lower panel, rigid fastener cores, Driver instruments, unchanged impact alpha
and protected occluders. Both platforms ran two matched 947-frame original
routes from the same platform-local checkpoint: zero state/framebuffer hash
differences with dynamics disabled/enabled, successful save/two loads, accepted
normal and muted cannon events, and zero stale station uniforms. Gameplay/save/
input sources and original files remain exact across 77 recorded hashes.

Native live motion was rendered using a private Window.focus_entered signal
fixture, peak 0.840 original pixels. A separate actual unfocused native run
correctly retained impulses without advancing the clock. Browser live motion
used actual focused window events, peak 0.873 pixels, and its normal importer,
save/load controls and reduced-motion startup path. Initial failures are retained:
headless Chromium lacked WebGL, a private route originally fired from Cupola,
and a retained/continuous viewport policy error was fixed before final checks.
No failing attempt is counted as an aggregate pass.

Evidence: `artifacts/tactical-dynamics-20261017/delivery.json`, native-final,
native-play-final, native-motion-focused, browser-contract-report.json,
browser-report.json and browser-pack.json. Both local normal browser PCKs now
carry only the eight production resources; every other payload stays exact and
all 51 served-bundle records were checked. The source/native checkout launcher
uses the same implementation. Existing vehicle/roster work was preserved.
Status: local only. No installed-app update, commit, push or publication.


## 2026-10-17: Complete Tactical scene model and texture pass

Nell explicitly selected all Tactical scene models, including architecture,
bridges and weapon crews alongside the 34 vehicle states. Revision 5 refreshes
all 57 authored states with newly baked albedo, tangent normal, AO, roughness and
metallic maps. Painted steel, tracks, rubber, canvas, timber, plaster, masonry,
roofing, skin/leather, optics and burnt wreckage have distinct finishes. High
master welds and fasteners bake into the unchanged runtime geometry. Fifty
unique editable Blender masters and seven proven aliases supply 57 GLBs and
five bounded runtime PBR banks. Existing textured terrain/foliage and unresolved
A-10/MiG placeholders retain their existing original-authoritative paths; the
188-definition inventory records every disposition.

Schema 3 preserves exact source topology/status, independently observed groups,
bridge lines, original flags and command-only heads. Static source coverage is
strict; vehicle extensions keep the accepted earlier-background rule. Flat
bridges and crew sheets follow original primitive painter order, with complete
common fallback for unsupported faces or priority overflow. Schema-2 and legacy
pair admission remain independently verified. No simulation, input, targeting,
hit-region or original-file changes belong to this pass.

Proof: 53 asset tests and 10 validator tests passed; the six-partition validator
passed its ten tests again after registration changed. All eight headless cases
passed 708,413 checks. All six native partitions passed 3,992 checks and cover
exactly 344 distinct views across 57 states, with zero forbidden pixels and
exact packet/mode restoration. Every prior Modern vehicle image (206) is
byte-identical. Twelve coverage studies have zero missing eligible pixels or
protected leaks, flags have zero changed protected pixels, and both original
rotor sets retain all 873/1,198 pixels. Crew painter witnesses in both orders
exercise 5,477 overlapping pixels each with zero mismatches; original round/head
pixels and whole-object fallback remain exact.

The unchanged 120-second guard rejected earlier combined format and two-partition
native attempts. Those failures remain in the evidence folder. Backend-independent
mapping assertions remain in the required headless gate; six smaller fixed native
partitions cover the same complete view inventory. The native witness's clear-
background mistake was fixed by comparing against an actual empty GPU capture,
retaining overlap/order assertions. The implementing chat visually reviewed the
native captures; independent advice was read-only. Concurrent Tactical dynamics
work was coordinated separately and preserved, not claimed as this task's work.

Evidence: `artifacts/tactical-scene-polish-20261017/acceptance.json`,
`aggregation.json`, `format-acceptance.json`, `accepted-native-0.log` through
`accepted-native-5.log`, `source-pins-final.log`, the complete contact sheet and
matching-camera before/after images. Runtime hashes and all 50 current finish
receipts match; original inputs, Modern, common shader, standalone pair maps and
the deadline retain their prior bytes. Decoded new-pack texture use is 480 MiB
with mipmaps. Source checkout only, no installed-app update, commit, push or
publication. Status: local only.

Working if: every authored state uses its approved bank, exact 344-view coverage
and protected-command witnesses remain green, original gameplay stays owned by
the pinned engine, and source-only delivery is distinguished from app deployment.


## 2026-10-17: Cabin 147 substantial rebuild

Nell identified the cubic cabin in her screenshot as inadequate. Shape 147 now
has a properly pitched clay-tile roof, physical tile lips/ridge caps, window
openings with deep reveals and multi-pane timber sashes, projecting sills,
louvred gable vents, a panelled door with hardware, steps, stonework, eaves,
gutters and downpipes. Native inspection caught aliasing on the first slatted
door; the final continuous four-panel leaf is rebaked and reads cleanly. The
implementing chat reviewed its own actual native captures.

The new cottage has 6,116 runtime triangles (previously 230), inside the unchanged
8,192 limit and original source envelope. Source primitive/root/group identity,
original hit regions and gameplay remain authoritative. Runtime renderer,
visibility masks, Modern and the test deadline remain byte-identical. All five
PBR master channels were rebaked at 2048 square. Editable Blender/GLB/maps are in
the existing local asset directory. A guarded `--patch-cabin` operation changes
only shape 147 and its existing 1024-square atlas tile. All other 56 catalogue
entries, other banks and every pixel outside that tile remain exact; no new
runtime map or sampler. Mixed bake provenance is recorded explicitly rather
than claiming older bakes use the new recipe.

Final proof: 731,764 headless checks, 615 checks over 54 native views, and 14
focused native checks over four matching-camera studies and one observed-wall
pose. Zero protected-pixel leaks, 54 Modern images and 48 unaffected Tactical
images byte-identical to the accepted previous pack. Native runs finished in
40.71 and 14.58 seconds under the original 120-second guard. The initial 64-test
Python suite passed; five focused geometry/pack tests passed again after the
final door repair and completed pack write. A provisional result that overlapped
the write was discarded. Original reference inventory remains unchanged.

Evidence: `artifacts/tactical-cabin-20261017/acceptance.json`, `scope-proof.json`,
`headless-final.log`, `native.log`, `after-views.log`, `python-final-stable.log`,
`source-pins.log` and the native before/after image. Existing concurrent dynamics
and local browser PCK work was preserved. No installed-app/browser PCK update,
commit, push or publication was performed by this cabin pass. Status: local only.

Working if: the cabin reads as constructed architecture at Tactical zoom, its
source-owned poses and protected visibility remain valid, and unchanged models,
Modern and original gameplay keep their preceding behaviour.


## 2026-10-17: Remaining Tactical architecture, ruins, crews and grounding

Nell approved all four proposed follow-ons. Thirteen further building/ruin
states now use source-owned construction, including matching collapsed cabin
materials, real apertures/joinery, individual slate/clay courses, masonry and
exposed/broken structure. Crews 161/162 have tailored clothing and equipment
partitions while preserving original flat poses, outlines, painter ordering and
separate source head commands. The initial rendered review caught erased stars,
communications flags, the 151 red ridge and farm yard; these were restored before
acceptance. A float32 atlas-sliver check repairs one final tiny insignia UV
without changing source geometry or weakening runtime validation.

The pack contains 250,108 definition triangles and 77,069,055 catalogue bytes.
The bounded roster-only cap increases to 96 MiB; the original 32 MiB source reader,
8,192 per-model cap, 57-state/five-bank admission and four samplers remain.
Recipes remain explicit: 13 architecture states at 8, crews at 7, cabin 147 at 6,
other states at 5. All 42 retained catalogue entries, non-scene banks and pixels
outside the 15 changed scene tiles remain exact. Scoped patching still requires
fresh selected receipts; full packing rejects old recipes.

Lower-body/footing shading supplements local AO inside the unchanged ownership
discard. Authored whole-model height occupies UV2.y on group/affine/piecewise
meshes; exact flags are excluded from bounds. Aircraft/flat crews/bridges and
zero-height geometry remain neutral. There is no projected terrain shadow,
new visibility or guest-state access. Original game inventory, hit regions,
Modern catalogue/common shader, draw pass, pose view and 120-second test deadline
remain unchanged. The implementing lead reviewed its own and delegated renders.

Accepted locally: 66 Python tests, 988,804 full headless geometry/binding checks,
and the catalogue-size/scene-mutation/compatibility partitions pass. All six
native partitions finish under the unchanged 120-second guard, covering 344 views
and 4,010 checks with zero forbidden pixels. All 344 Modern images are byte-exact
against the preceding accepted matrix; 54 unchanged bridge/aircraft Tactical
images are also byte-exact. Four ordered crew composites have zero mismatches
across 5,477 overlap pixels each. Flag pixels remain exact at near/far scales.
Grounding on/off studies change no exterior or coverage pixels and remain
neutral for aircraft/flat crews. Texture allocation remains 503,316,477 bytes
including mipmaps. Representative synchronized Tactical renderer samples are
0.98 to 2.70 ms on this Mac; native process maximum RSS is 2.68 to 3.65 GB. These are
native diagnostic measurements, not browser/WASM or general gameplay benchmarks.

Evidence:
`artifacts/tactical-scene-finish-20261017/acceptance.json`, `scope-proof.json`,
`source-invariants.json`, `python.log`, `headless-{0,5,6,7}.log`, the six
`native-*.log`/reports, `after-views.log` and `scene-before-after.png`. Status:
local only. No installed/browser PCK update, commit, push or publication.


Concurrent dynamics and cover-menu work were preserved. Task-owned completed
rejection fixtures and SHA-identical staging/backup duplicates were removed
under the separate authorised storage cleanup. Detailed receipts retain paths,
logical sizes and before/after APFS free-space observations; concurrent volume
activity prevents attributing net physical recovery to this chat alone.


## 2026-10-17: Farm animal and complete Tactical roster refinement

Nell requested a further farm upgrade and another pass across all models,
explicitly including Sagger and Spigot. Revision 9 refines all 57 authored states.
The farm has a static source-owned piebald cow, trough and braced gate; the
destroyed farm retains broken fittings without animal remains. Architecture,
vehicles, wrecks, helicopters and bridge/hangar surfaces receive construction
and mechanical refinements. All 50 unique editable masters and their PBR maps
were freshly baked, with seven source-proven aliases.

Crews now have closed shallow body/limb/equipment volumes, integrated garment
relief and real opaque self-occlusion. Original round heads and strict source
silhouettes remain. Final native review caught reversed-facing details and
material projection misses. The lead corrected the facing and arm depth, baked
crew material maps directly from the runtime shell, enlarged the normal cage,
and installed only the two corrected entries/tiles through recorded scoped
patches. The other 55 entries and all pixels outside those tiles remain exact.
The implementing lead reviewed its own and delegated native captures.

The final catalogue is 83,749,195 bytes and 271,204 definition triangles; the
largest state is 8,178 triangles. The existing 8,192 per-model limit, 96 MiB
catalogue cap, five banks and four samplers remain. Decoded texture allocation
including mipmaps remains 503,316,477 bytes. Original game inputs, hit regions,
simulation, source draw path, Modern catalogue/common shader and native deadline
remain unchanged. No new actor or collision is added by the cow.

Evidence: `artifacts/tactical-roster-refinement-20261017/acceptance.json`,
`scope-proof.json`, `crew-final-proof.json`, `source-invariants.json`, native
captures and terminal-result logs. Concurrent dynamics, cover-menu and browser
bundle work is preserved. Status: local only. No installed/browser PCK update,
commit, push or publication belongs to this pass.

Working if: all 57 authored states retain source ownership, the cow and crew
volume read correctly in native captures, corrected crew textures have no
interior projection misses, protected commands stay exact, and Modern restores
without a pixel change.

Validation status: 59 asset tests, 10 runner tests, 1,071,530 headless checks,
maps/size rejection, three mandatory scene mutation cases and legacy
compatibility pass. The 344-view current-equivalent matrix has exact Modern
pixels and zero protected-pixel leaks. Initial final-pack native scene/common
phases passed 155/691 checks; shard 5 passed 646. Review then found a broken
foreground filter: the Compatibility clear colour is grey. The witness now
compares against its captured empty frame. Its completed first crew has 38,548
actual foreground-interior samples and zero ordering mismatches, but the full
corrected scene follow-up hit the unchanged deadline twice during severe CPU
contention (131.47 and 126.43 seconds). The final follow-up remains pending a
quieter resource window, coordinated with JANUS without interrupting its active
job. No aggregate acceptance is claimed for this last follow-up. Continuation
commands and evidence are saved in this pass's `CONTINUE.md`.


## 2026-10-17: Focused cow and Sagger/Spigot follow-up

Revision 10 revises only states 157, 161 and 162. The cow receives a continuous
body and face profile, tapered jointed legs and split grounded hooves. Crews
receive joint-aligned limb sections and clearer equipment grips, catches,
controls and recessed optics. All three Blender/GLB/five-channel sets are fresh.
Farm/crew runtime triangle counts are 7,862/2,904/2,904. Original poses, heads,
source ownership, hit regions and gameplay remain authoritative; no runtime
visibility policy changes. The implementing lead reviewed its own captures.

Scoped installation proves 54 other entries, 12 non-scene maps, and every
scene-bank pixel outside the three selected tiles exact. Farm building/yard
geometry is unchanged. The catalogue is 83,920,408 bytes and 271,640 definition
triangles; all existing runtime limits remain. A documented offline repair to
24 tiny nostril-cap UVs preserves geometry/maps and keeps strict transport checks.
Cow texture QA samples all safely interior texel centres, rather than demanding
the crew-sized percentage of large UV triangles from a small farm decoration.

Four focused Python tests and 224 native checks pass. All 18 Modern comparison
PNGs are byte-exact; Tactical forbidden pixels are zero. Both corrected crew
foreground witnesses have 32,371 interior samples and zero ordering mismatches,
with effective depth-disabled negative controls. Original heads, head removal
and unsupported-primitive fallback pass. The older full revision-9 scene timeout
remains historical; these are focused revision-10 results, not a new full gate.

Evidence: `artifacts/tactical-cow-crews-refinement-20261017/acceptance.json`,
`scope-proof.json`, `comparison.json`, before/after sheets and terminal logs.
Status: local only. No PCK update, commit, push or publication by this pass.
Concurrent dirty work was preserved; no foreign process was signalled.

Working if: the requested three models visibly improve within original source
coverage, the independent original heads and fallback stay exact, and Modern
restores byte-identical images.


## 2026-10-17: Complete Sagger/Spigot head review

Nell flagged the headless crew previews. The prior material-study fixtures used
only polygon bodies and omitted the separate original head commands. The lead
apologised for accepting incomplete visual studies, then reused the established
original-CPU head witnesses with the installed Tactical meshes. Both complete
crews now have inspected helmet/face captures. All 22 native checks pass,
including exact original head coverage, visible face/helmet, mode restoration
and rejection of unsupported/missing commands. No renderer, model, texture,
source registry or gameplay change was necessary; the runtime pack hashes remain
exact. The source-bound body GLBs still require their independent head layer.

Evidence: `artifacts/tactical-crew-head-review-20261017/acceptance.json`, native
captures and terminal log. The implementing lead reviewed its own work. Status:
local only, no PCK update or publication. Working if: crew quality review shows
the complete body plus witnessed original helmet/face, with source coverage
unchanged.


## 2026-10-17: Actual modelled Sagger/Spigot heads

Nell repeated that the crews had no heads. The preceding correction verified a
separate 2D head overlay and did not complete the 3D assets. Revision 11 fixes
both actual Blender/GLB models and the Tactical renderer: 2,224-triangle textured
heads, 5,128 triangles per complete crew. Original root/command pins, observed
spans and ownership control admission; ambiguous or unsupported packets retain
exact incumbent fallback. Natural head cutouts retain original actor occlusion.

Two fresh bake sets were followed by deletion-only backing removal and a strict
stored-float32 iris-UV repair. Original/derived producer hashes and all-map exactness
are recorded. Existing crew slots now have padded body/head regions. The five
banks, four samplers, decoded allocation and source body bounds stay unchanged.
All 55 other entries, 12 other-bank maps, and scene pixels outside two tiles are
exact. Catalogue size is 85,833,523 bytes, within the existing 96 MiB limit.

Four Python tests and 267 native checks pass. The 159-check scene phase completes
in 105.49 seconds under the existing 120-second guard. Both heads have zero
forbidden pixels and zero concealed-actor leaks; the negative control changes
1,924 pixels per crew. Six original/Modern comparison PNGs remain byte-exact.
Failed fixture, numeric-array loader and provisional full-ellipse opacity checks
are retained in logs and were not counted as passes. Numeric validation fixes
JSON-type admission; natural head silhouettes are tested through retained source
ownership and explicit actor-occlusion controls. The implementing lead reviewed
its own actual GLB/native captures and reconciled independent read-only advice.

Evidence: `artifacts/tactical-modelled-heads-20261017/acceptance.json`,
`scope-proof.json`, finishing receipts and terminal logs. Gameplay/hit regions
remain original. Status: local only; no PCK, commit, push or publication. Concurrent
dirty work was preserved. Working if: both exported and rendered crew heads are
real geometry, source command visibility remains authoritative, concealed actors
stay hidden, and rejected/Modern views restore exactly.


## 2026-10-17: Tactical truck front and destroyed farmyard

- Rebuilt truck 159 cab/front integration: enclosed engine bay, upright split
  glass, rounded roof shoulders, rolled mudguards, front wings and seated lamps.
- Added 47 masonry chunks, fallen roof sections and snapped rafters to ruined
  farm 158, all owned by original yard primitive 29245. Retained original roof
  tile/hole topology; reallocated foundation/frame tessellation within the cap.
- Fresh editable Blender files, textured GLBs and five-map bakes installed.
  Truck: 5,820 triangles. Ruined farm: 7,990. Catalogue: 85,946,167 bytes.
- Verified 55 other entries, nine bank maps and atlas pixels outside two slots
  exact. Eight Python tests and 109 native checks pass; zero forbidden pixels;
  twelve Modern baseline captures byte-exact. Original gameplay is untouched.
- Export review caught inward glass normals in an intermediate bake, corrected
  before delivery. A premature installation was rejected by manifest hashes
  before any writes; the final install followed terminal packing and fresh-model
  equality checks. Intermediate failed/superseded logs are retained.
- Local only. No PCK rebuild, commit, push or publication by this pass.
  Receipt: `artifacts/tactical-truck-farmyard-20261017/acceptance.json`.


## 2026-10-18: Truck and ruined farm finishing

- Recessed truck grille with an actual open throat, inset slats and chamfered
  apron. Removed the engine-bay cap that would otherwise occlude the recess.
- Authored rubber chevron tyre tread, smooth 48-segment game tyres, 64-segment
  baking masters and matching six wheel nuts. Restrained paint mottling and
  localized contact dust and edge wear.
- Varied ruined-yard rubble counts, scale, orientation and profiles. Chipped
  fallen roof pieces and 466 matching game/master roof-fracture triangles.
  Source-unit collapse centres also anchor irregular low-contrast ground dust.
- Fresh Blender files, textured GLBs and five-map bakes installed. Truck: 7,600
  triangles; ruined farm: 7,776; catalogue: 86,432,229 bytes. Existing caps retained.
- Verified 55 other entries, nine untouched maps and atlas pixels outside two
  slots exact. Runtime/gameplay source unchanged. Eight Python tests and 109 native
  checks pass; zero forbidden pixels; twelve Modern PNGs byte-exact.
- Implementing lead reviewed own GLBs, tyre close-up and native captures. Pale
  dust and wheel-nut projection mismatch corrected before final installation.
  Supported escalated native/baking runs succeeded after sandbox startup failures.
- Local only. No PCK rebuild, commit, push or publication by this pass.
  Receipt: `artifacts/tactical-truck-farm-polish-20261018/acceptance.json`.


## 2026-10-18: Remaining Tactical roster finishing

- Finished all 55 remaining authored states: 48 fresh unique Blender/GLB/map
  masters and seven proven geometry aliases. Truck 159 and ruined farm 158
  catalogue entries and atlas pixels remain exact; their asset directories were
  excluded from installation.
- Matched track-shoe stations; refined BTR/BRDM tyres/hubs and outward glass;
  restrained paint, cloth, masonry and wreck wear; smoother Hind baking masters.
  Added original-floor-owned rubble, fractured roof breaches, broader hangar
  panels and worn farm paths. Existing crew poses and command-bound heads retained.
- Fixed mesh-selection isolation after pilot GLB review proved all 2,904 body
  UVs had been re-unwrapped when the later head was created. Saved corrected body
  and head UVs now match baked receipts; the actual GLB no longer has black patches.
- Installed catalogue: 87,956,917 bytes; maximum complete model: 8,178 triangles.
  Existing five-bank, four-sampler and decoded-allocation limits remain unchanged.
- 21 Python tests and 3,093 native after-checks pass. All 332 multiview studies
  have zero forbidden pixels; 334 Modern captures including both complete crews
  are byte-exact. Head hidden-actor/fallback contracts pass with zero leaks.
- Corrected a broken artifact install preflight which had applied texture UV
  validation to the two pinned source-rendered flags. Runtime exclusions, source
  flags and the strict textured body/head gate remain unchanged. Failure retained
  in `install-invalid-passthrough-preflight.log`; no live files changed on rejection.
- Implementing lead reviewed own 110 actual GLB renders and ten native comparison
  sheets. Runtime/gameplay source hashes remain exact. Native model studies do
  not claim a live-mission or full-simulation gate.
- Local only. No PCK rebuild, commit, push or publication by this pass.
  Receipt: `artifacts/tactical-roster-polish-20261018/acceptance.json`.


## 2026-10-18: Tactical family and collapse quality pass

- Reviewed all 57 authored states in 114 actual GLB views. Refined 24 states with
  23 fresh masters and one verified alias; retained 33 entries and all atlas
  pixels outside selected slots exactly. No runtime/gameplay source changes.
- Authored distinct wreck-family profiles and fittings, including angular Abrams
  cheeks, cast-turret variants, F-ST pod remnants, M113 cargo structure, Bradley
  and BMP remnants. Smoother damaged wheels and matched game/master track stations.
  Five former aliases now have distinct masters within the existing wreck bank.
  Canonical alias metadata now describes the actual pack; old scoped proof remains.
- Fitted hull-owned driver vision coamings/glass and rear access hardware on five
  carriers. Replaced tent-like long ruin panels with chipped short slabs, staggered
  spacing/yaw, 15 grounded chunks, fallen rafters and tile fans on three ruins.
- First ruin pilot was still too regular. Preserved it under rejected-regular-slabs
  and corrected the layout before final baking. Initial baseline launch raced its
  snapshot and exited127 without starting an engine; retried after snapshot exit0.
- Installed catalogue: 93,714,174 bytes. Complete pack: 294,840 body plus 4,448 head
  triangles. Maximum model: 8,178. Existing 96 MiB/8,192 caps, five banks, four
  samplers and decoded allocation remain unchanged.
- 23 Python tests and 1,304 native after-checks pass. All 144 changed-state views
  have zero forbidden pixels and byte-exact Modern PNGs. All Godot source hashes
  remain exact. No new head run or full57 native/simulation gate is claimed;
  crew entries, maps and runtime are among the exact retained surfaces.
- Implementing lead reviewed own 48 final GLB views and all four native comparison
  sheets. Local only. No PCK rebuild, commit, push or publication by this pass.
  Receipt: `artifacts/tactical-model-quality-pass-20261018/acceptance.json`.


## 2026-10-18, Tactical launcher and attachment polish (revision 16)

- Reviewed all 57 current GLBs in 114 views. Refined seven states through six
  fresh Blender/GLB/PBR masters and the proven Hind alias; retained 50 entries,
  their asset files and all outside-slot pixels exactly.
- Rebuilt BMP-1 channel rail, mounted finned missile and pivot; BMP-2 pedestal,
  pivot, cradle and clamped/sealed canister. Original ATGM owner retained.
- Fitted BTR/BRDM wipers to post-scale glass, corrected left Hind window/frame
  normals and replaced flat retracted gear doors with skin-following panels.
- 25 Python tests, 381 native after-checks, zero forbidden pixels and 42 exact
  Modern captures pass. All 197 Godot source hashes remain unchanged.
- Catalogue 94,283,653 bytes; 296,620 body plus 4,448 head triangles; max 8,178.
  Existing geometry/texture/sampler limits unchanged. Own-work visual review
  completed; rejected pre-bake evidence retained. No live-mission/full57 native
  matrix or new head-contract/simulation gate claimed.
- Evidence: `artifacts/tactical-attachment-polish-20261018/acceptance.json`.
  Local only, no PCK rebuild, commit, push or publication.


## 2026-10-18, Tactical service and construction polish (revision 17)

- Re-reviewed all55 remaining states in110 exact-GLB-verified export views.
  Refined18 states with18 fresh Blender/GLB/PBR masters; retained39 entries,
  recorded asset files and all outside-slot atlas pixels exactly.
- Nine armoured vehicles have recessed engine-grille beds/painted slats and
  surrounds; five tank families have fitted case lids, hinges and latches.
- Nine architectural states have outward façades/glazing/roofs, inward-facing
  opening reveals and restored valid gable ends. Roof, rafter and foundation
  bake stations now match game construction. Flat-wall subdivision reduction
  keeps large base156 under the unchanged geometry limit.
- 28 Python tests,996 native after-checks,zero forbidden pixels and110 exact
  Modern captures pass.197 Godot source hashes remain exact. Own final36 GLB
  views and5 native sheets personally reviewed; pre-bake failures retained.
- Catalogue94,587,389bytes;298,108body+4,448head triangles;max8,190. Existing
 8192/96MiB/five-bank/four-sampler caps retained. No live-mission/full57 native
  matrix, new head-contract or simulation gate claimed.
- Evidence: `artifacts/tactical-roster-service-polish-20261018/acceptance.json`.
  Local only; no PCK rebuild, commit, push or publication.


## 2026-10-19, Tactical fitting quality pass (revision 18)

- Reviewed all 57 states in 114 exact-current-GLB-verified views. Refined ten
  states with ten fresh Blender/GLB/PBR masters; retained 47 entries, model files
  and outside-slot atlas pixels exactly.
- Seated searchlight/sight assemblies against finished turret casting, refitted
  guards, added connected searchlight stems and snorkel stays/retaining bands.
  Three carrier weapon pedestals and the M60 mount now contact their supports.
  Weapons/aim remain fixed; game and bake masters share game-skin fitting seats.
- Cottage 147/149 window reveals face into their recesses, correcting 48 of 64
  misoriented triangles each, without changing geometry bounds or source owners.
- 31 focused Python tests, 553 native after-checks, zero forbidden pixels and 61
  exact Modern captures pass. All 197 Godot source hashes remain exact. Own four
  pilots, 20 fresh GLB views and three native comparison sheets reviewed.
- Catalogue 94,715,182 bytes; 298,436 body plus 4,448 head triangles; max 8,190.
  Existing 8192/96MiB/five-bank/four-sampler caps retained. No live-mission or
  full57 native matrix claimed. Evidence:
  `artifacts/tactical-fitting-quality-pass-20261018/acceptance.json`.
- Local only; no PCK rebuild, commit, push or publication. All task jobs finished.


## 2026-10-19, Tactical running-gear polish (revision 19)

- Reviewed all 57 states in 114 exact-current-GLB views. Refined twelve tracked
  models with twelve fresh Blender/GLB/PBR masters; retained 45 catalogue entries,
  model files and outside-slot atlas pixels exactly.
- Fixed T-62 front-idler/road-wheel overlap and misplaced idler teeth; tightened
  road-wheel station span while retaining the already-correct front/rear gap
  ordering. No spacing reversal was required. All twelve tracked states have
  closed dished smooth idlers, integral-tooth drives and recessed hubs. End-wheel
  centres/radii follow actual track shoulders, with both-side road-wheel clearance.
- New checks protect clearance, closed topology, idler/drive distinction, exact
  game/master tooth stations and diagonal-track contact. Initial assertion message
  typo fixed; original failed log retained, no geometry guard weakened.
- 34 focused Python tests, 670 native after-checks, zero forbidden pixels and 74
  exact Modern captures pass. All 197 Godot source hashes remain exact. Own five
  final pilots, 24 fresh GLB views, three native sheets and T-62 side views reviewed.
- Catalogue 95,073,533 bytes; 299,524 body plus 4,448 head triangles; max 8,158.
  Existing 8192/96MiB/five-bank/four-sampler caps retained. No live-mission or full57
  native matrix claimed. Evidence:
  `artifacts/tactical-running-gear-polish-20261019/acceptance.json`.
- Local only; no PCK rebuild, commit, push or publication. All task jobs finished.


## 2026-10-19, Tactical remaining-surface polish (revision 20)

- Reviewed the remaining 45 states in 90 exact-current-GLB views. Refreshed six
  states through five unique BTR/BRDM/truck/Hind Blender/GLB/PBR masters and the
  proven Hind alias; retained 51 entries, model files and outside-slot pixels.
- Corrected inward side panels, exposed buried BTR/BRDM headlamp apertures with
  seated feet, and replaced hovering Hind wing paint with actual facet partitions.
  All twelve previously polished tracked vehicles remain exact.
- Additional truck shell occlusion rejected an incomplete bake. Read-only advice
  derived the limiting vent height; root independently reran full-surface checks
  on all vent triangles against both shells, game/master. Minimum clearance
  .0211473 raw units. Failed logs and rejected receipts remain preserved.
- 80 focused Python tests, 326 native after-checks, zero forbidden pixels and
  36 exact Modern captures pass. All 197 Godot source hashes remain exact. Own
  final pilots, twelve fresh GLB views, two native sheets and highlights reviewed.
- Catalogue 95,120,082 bytes; 299,644 body plus
  4,448 head triangles; max 8,158.
  Existing 8192/96MiB/five-bank/four-sampler caps retained. No live-mission or full57
  native matrix claimed. Evidence:
  `artifacts/tactical-remaining-surface-polish-20261019/acceptance.json`.
- Local only; no PCK rebuild, commit, push or publication. All task jobs finished.


## 2026-10-19, Tactical façade and slate polish (revision 21)

- Reviewed all 57 states in 114 hash-verified GLB views. Refreshed states 145,
  151, 153, 155, 156 and 157 through six unique Blender/GLB/PBR masters. The
  other 51 entries, model files and outside-slot pixels remain exact, including
  all vehicles, crews/heads, bridges and ruins. Cow geometry and placement remain
  exact inside the refreshed farm.
- Exposed buried drainage through coherent façade setbacks within original bounds.
  Joinery/reveals move together; existing decorated support planes stay exact.
  Brackets embed into walls. Five restrained slate tones follow the original roof
  planes; corrected courses run along the eaves and lap downslope on both pitches.
- Three regressions cover observed drainage, slate and course-direction defects.
  Initial bracket depth failed and was corrected explicitly. A completed first
  candidate was superseded after reverse-view course-direction review; its
  receipts, renders and failed logs are retained. Five pre-bake checks pass.
  All seven other architecture recipes and other family sources remain exact.
- 83 asset tests, 326 native after-checks, zero forbidden pixels, 36 exact Modern
  captures and 197 exact Godot source hashes. Own drainage/roof pilots, twelve
  fresh GLB views, both native sheets and highlights reviewed. No live-mission
  or full 57-state native matrix claimed.
- Catalogue 95,200,533 bytes; 299,758 body plus 4,448 head triangles; max 8,158.
  Existing 8192/96MiB/five-bank/four-sampler caps retained. Evidence:
  `artifacts/tactical-roster-detail-polish-20261019/acceptance.json`.
- Local only; no PCK rebuild, commit, push or publication. All task jobs finished.


## 2026-10-19, Tactical wreck-wheel polish (revision 22)

- Reviewed all 57 states in 114 hash-current GLB views. Refreshed all sixteen
  wreck states through fifteen unique Blender/GLB/PBR masters and the verified
  BRDM wreck alias. The other 41 entries, model files and outside-slot pixels
  remain exact, including all intact vehicles, scenes, crews/heads and bridges.
- Replaced round plates with seated, lipped, recessed rim profiles matching the
  existing wheel squash; hubs follow the same deformation. Loose-wheel caps
  clear both wheel-end planes. Tyres, axle/bolt stations, suspension, tracks,
  other wreck parts and original source/pose metadata remain exact.
- Three regressions reproduced the defects; four pre-bake checks pass. Own three
  initial pilots, corrected loose-hub pilot, 32 fresh GLB views, four native
  comparison sheets and detail highlights reviewed.
- 86 asset tests, 868 native after-checks, zero forbidden pixels, 96 exact Modern
  captures and 197 exact Godot source hashes. No live-mission or full 57-state
  native matrix claimed. Shared capacity sequencing and fresh fail-closed guards
  preceded the one scoped four-thread bake batch; no foreign process control.
- Catalogue 96,399,853 bytes; 303,694 body plus
  4,448 head triangles; max 8,158.
  Existing geometry/96MiB/five-bank/four-sampler caps retained. Evidence:
  `artifacts/tactical-wreck-fit-polish-20261019/acceptance.json`.
- Local only; no PCK rebuild, commit, push or publication. All task jobs finished.

## 2026-10-19, Blender crew, complete roster, world and animated cover

- Installed revision 23 Sagger/Spigot Blender sculpts and fresh PBR bakes, with
  joined anatomy, fitted hands and boots, and modelled heads. The original
  round-command mapping now includes the full source pixel cells. The two native
  head fixtures pass 80 checks with no neck gaps at 2x/4x, no changes outside the
  head ownership, and no concealed-actor leaks.
- Reopened all 55 editable roster masters in Blender and repaired tangent-frame
  and baked occlusion export across all 57 GLBs, including the two verified aliases.
  Geometry, UVs, bake receipts, catalogue and atlas pixels are unchanged by this
  export pass. A separate `export-polish.json` records it. Runtime daylight and
  contact shading have stronger shape separation; source ownership remains exact.
- Added Blender-authored shrub and grass meshes (582/122 triangles) with the
  original footprints, planting grids and two draw batches. Missing optional
  assets retain the original fallback. No foliage ownership shader changes.
- Refined the cover tank and both crew in an editable Blender master, preserving
  pivots, indices, UVs, vertex colours and materials. Added two rising, drifting
  smoke plumes and sky advection. Native checks prove isolated smoke motion,
  pixel-identical Reduced Motion frames, and suspension on entering the range.
- Verification: 90 asset tests and 12 gate/package tests pass. The initial missing
  world-test gate registration and malformed cover-loader type checks were fixed;
  failed logs remain. Root checks: simulation 1,265; world 15; draw pass 53;
  effects 34. The full 57-state native matrix passes 3,106 checks over 344 views,
  with zero forbidden pixels, identical Modern restores and unchanged packets.
- Implementing lead reviewed its own 114 GLB views, all native roster sheets,
  separate composed crew-head renders, world studies, and wide/compact menu with
  both crew close-ups. The body-only roster fixture omits separate head commands;
  head visibility is covered by the dedicated composed fixtures. These are native
  fixture results, not a full mission or packaged-build acceptance.
- 156 of 160 pinned runtime files remain exact; the four changed scripts are
  presentation-only. Source/private package lists and the world gate are updated.
  Optional Impeccable lint was unavailable offline (`ENOTCACHED`); no installation
  was attempted. Evidence: `artifacts/tactical-complete-blender-20261019/acceptance.json`.
- Local only; no installed/browser PCK rebuild, commit, push or publication.

Working if: composed crews retain connected heads, original visibility ownership
and Modern pixels remain exact, both menu smoke plumes move, Reduced Motion freezes
them, and the editable Blender masters match the installed exports.

## 2026-10-19, active continual Blender goal, human-anatomy pass (revision 24)

- Nell activated the continual refinement goal, retaining original gameplay and
  visibility boundaries. This is its first finite pass; the broader goal remains
  active. A 57-state rotating review/action roster is saved with the evidence.
- Rebuilt both command-bound operator faces as continuous skin, nasal bridge,
  sockets and lips. Matched Blender studies exposed the old disconnected features.
  A rear GLB study then exposed a neck ledge, so the first candidate was rejected.
  The accepted neck and face share one closed surface and smooth bake normals;
  cheek straps follow the new surface. The topology regression fails the old mesh.
- Fresh Blender head-only PBR bakes preserve both accepted body meshes, UVs and
  maps exactly. Both editable masters and GLBs are updated. The other 55 states,
  original head bindings and all pixels outside the two head rectangles remain
  exact. Complete crew budgets are 7,947/8,039 triangles; roster maximum 8,158.
- Fitted 4,469 menu-garment vertices across both crew, including lining and trim.
  Elbow/wrist anchors, hands and non-crew batches remain unchanged. Maximum
  displacement stays below the existing 1cm loader limit. All 42 authored batches
  are admitted in the native scene, with no silent fallback.
- Root verification: 103 Python tests, 80 native head checks and 1,265 simulation
  checks pass. Neck gaps at 2x/4x, outside-head changes and concealed-actor leaks
  are zero. Menu native acceptance covers wide/compact layout, both crew, smoke,
  exact Reduced Motion freezing and range lifecycle. The implementing lead
  reviewed its own final exports and native composed/head/crew/hand captures.
- All 68 pinned original inputs and all pinned Godot runtime files remain exact.
  No full-mission, aggregate repository gate or packaged-build acceptance claimed.
  Local only; no PCK rebuild, commit, push or publication. All finite-phase jobs
  are terminal and the shared native slot is released. Evidence:
  `artifacts/tactical-continuous-blender-20261019/acceptance.json`.

Working if: the face, nose and neck form one closed surface, rear views have no
neck ledge, original head ownership/concealment and Modern pixels remain exact,
and menu garment refinement leaves the pose contacts and smoke lifecycle intact.

## 2026-10-19, connected shrub canopy and completed rotating Blender review

- Replaced the five closed shrub crown volumes with 120 slender folded leaves in
  60 attached pairs on ten connected twigs. Blender masters and bounded Godot
  resources are installed reproducibly. Two intermediate appearances were rejected:
  sparse horizontal shelves, then overly broad square blades. The accepted version
  stays at 682 triangles, inside the unchanged 700-triangle shrub cap.
- Grass remains 122 triangles with the exact incumbent vertex, normal, UV and tag
  stream. Nine native grass image buffers are pixel-exact. Both footprint streams,
  two batches, planting grids/caches, shader and source admission/ownership logic
  are unchanged. Reversing the single author SHA pin restores all of Foliage.gd.
- Root checks: 12 Python tests and 152 focused Godot checks pass. The native asset
  studies cover close views and three sizes at 0/90/180 degrees, with deterministic
  images and zero actor-owned painted pixels. The final smallest studies retain at
  least 217 green pixels. All 68 original input hashes and 57 current GLBs are exact.
- Completed the rotating review of all 57 Tactical states, world presentation and
  the current wide/compact menu. Current revision 24 head views supersede the old
  head cells. The implementing lead self-reviewed its own work. No additional
  material worthwhile refinement was found after the accepted fixes, satisfying
  this continual goal's stop criterion. Fine hangar seam aliasing at subpixel sizes
  and strict original source silhouettes/planes remain explicit limits.
- Blender's first sandbox invocation crashed at Metal startup before authoring;
  scoped native access succeeded. An invalid unittest method invocation was fixed;
  the actual gate module passes. Failed logs and rejected candidates are retained.
- Local only: no full mission or aggregate gate claim, package/PCK rebuild, Git
  mutation or publication. All finite-phase jobs are terminal and the native slot
  is returned. Evidence: `artifacts/tactical-leaf-canopy-20261019/acceptance.json`;
  the 57-state dispositions are in its adjacent `review.json`.

Working if: authored leaves remain connected and readable at the reviewed sizes,
all source-owned actor pixels remain uncovered, grass/planting stay exact, and
further changes require a newly evidenced material defect rather than cosmetic churn.

## 2026-10-20, fresh all-roster Blender refinement (revision 25)

- Nell assigned a fresh refinement pass after the previous continual goal closed.
  Reviewed all 57 Tactical states in 114 new low-angle GLB captures, plus component
  closeups and the retained world/menu inputs. The final disposition is 19 changed
  states and 38 retained states, recorded individually in `review.json`.
- Rebuilt roadwheel shoulders on 12 intact tracked states as joined tyre/rim
  shells. An initial 16-sided candidate was rejected for a worse faceted outline.
  The accepted design keeps 20 circumferential sides, original centres/extrema
  and exact runtime triangle counts. Removing two buried caps and reducing the
  small hub by one side funds the extra shoulder section. Non-roadwheel geometry
  and original registry bindings remain exact. The new regression covers closed
  joined shells, three sections, shared mounting rings and per-wheel budgets.
- Re-baked seven bridge/structure states with continuous padded UV charts per
  original physical source plane. Matched native exports show continuous hangar
  wall joints; all world triangles, bounds, surface area and original lines remain
  exact. Fine distant roof-seam aliasing remains a limit. A second regression
  protects shared-point UV continuity. All incumbent test-method ASTs are exact.
- All 19 fresh five-channel bakes, masters and tangent/AO-equipped GLBs are
  installed through the existing scoped packer. Verified 164 installed files,
  38 exact retained catalogue entries/exports and exact pixels outside the changed
  slots in all 15 bank maps. All 171 rollback files remain authenticated. Shrub,
  grass and calibration-menu art are unchanged from the accepted prior pass.
- Root verification: 105 Python asset/gate/package tests pass with no skips.
  Headless admission passes 1,217,582 checks. Five serial native batches cover
  116 views at 4x, passing 1,049 checks with zero forbidden pixels, exact Modern
  restoration and unchanged source packets. The implementing lead reviewed its
  own final textured exports, matched wheel closeups and all changed production
  states. All 68 original inputs, 160 runtime source pins and 121 untouched art
  pins remain exact.
- Retained failures honestly: a 900-second batch guard stopped after completing
  state 129; later single-state jobs completed its unstarted peers. State 139
  reached three maps before its separate 1,200-second guard. Channel timestamps
  showed progress rather than a demonstrated stall. Independent read-only advice
  supported a newly declared 2,400-second single-state budget, with recipe,
  samples, resolution, CPU/RSS/disk limits unchanged. That fresh run completed
  naturally in 209 seconds; the earlier throughput difference remains unverified.
  Both guard failures remain recorded. Two capture wrappers failed after writing
  complete images; file/receipt checks verified those captures without re-rendering.
  Sandbox-only Godot log-write errors made the first admission wrapper fail;
  scoped native access passed the unchanged check. No failing assertion was removed.
- Local only: no full-mission or aggregate repository gate claim, package/PCK
  rebuild, Git mutation or publication. All phase jobs are terminal. No new
  discretionary CPU-heavy authoring phase is planned; the resource coordinator
  has the actual terminal state. Evidence:
  `artifacts/tactical-all-model-refinement-20261019-r2/acceptance.json`.

Working if: the 12 wheel assemblies retain their original runtime budgets and
source bindings, the seven structures retain exact geometry with continuous UVs,
all retained art stays exact, and native ownership/Modern/source-packet checks pass.

## 2026-10-20, another Blender pass, flags and insignia (revision 26)

- Nell requested another pass and asked whether the hangar flag should be white.
  Freshly decoded the pinned original SHAPE.TBL: shape 47, primitive 4915 has
  prefix `[27,1,1]`; observed original palettes and the supported art palette map
  colour 1 to white. Its original black pole is primitive 4909. The existing
  Tactical flag incorrectly used a glossy lamp field and mechanical cladding.
- Replaced that construction with matte white cloth and a restrained hem on the
  original plane, preserving its full area, bounds, source owner and pole line.
  The flag drops from 152 facets to 10, and the complete hangar from 3,416 to
  3,274. All 3,264 non-flag facets remain exact. Baked field samples are neutral
  near-white, nonmetallic and rough; no faction emblem or motion was added.
- Reviewed all 57 current GLBs from two new elevated opposing angles, with
  focused flag and building-marking captures. This exposed a black Army star on
  building 155. Eight star-bearing surfaces across 153/155/156 had inward-facing
  facets and systematic black occlusion. Independent read-only advice confirmed
  the winding diagnosis and the need to repair it before UV/bake generation.
- Reversed only the 224 inward facets in the Tactical authoring path, for game
  and master. Each individual facet retains its vertices, material, colour,
  component, position in the facet list and source ownership. All other facets,
  original registry, markings, flags and support setbacks remain exact. Modern
  generation/assets and runtime code were not changed. Fresh bakes remove the
  systematic zero-occlusion interiors; native captures restore the white Army
  stars and retain the red/gold markings.
- The prior exact-order decoration assertion pinned the defective winding. It
  now checks per-facet vertex membership and unchanged metadata, together with
  outward normals in game/master. Exact flag-passthrough assertions remain.
  Added two observed-defect regressions: white matte cloth on the original flag
  plane, and absence of systematic black painted-star occlusion. The old bake
  fails the latter at shape 153/27027; the installed corrected bakes pass.
- Four finite Blender jobs completed naturally within their original CPU4,
  4 GiB RSS and 900/1,200-second limits. All four editable masters and GLBs have
  fresh PBR maps, normal tangents and occlusion. The existing scoped packer
  installs 40 files, preserving 53 catalogue entries/exports and every pixel
  outside the four changed slots across all 15 maps. All 51 rollback files are
  authenticated. The phase's revised 1.5 GiB all-in forecast replaces its initial
  1 GiB estimate after the three building defects were found.
- Root verification: 107 Python tests pass with no skips, alongside 1,217,038
  headless admission checks and 24 native views at 4x with 218 checks. Forbidden
  pixels are zero, Modern restoration is exact and original packets are unchanged.
  All 68 original files, 160 runtime source pins and 170 untouched art pins remain
  exact. A fresh original decode reproduces the current source-registry pin.
  The implementing lead reviewed its own final GLB closeups, complete models
  and source-bound production renders.
- An initial focused-test command named the wrong class and ran no source tests;
  the corrected command passes. A camera-preparation syntax typo failed before
  execution and was corrected. The intentionally red old-bake regression is
  retained separately from the green final suite. No assertion, cap or gate was
  removed to obtain a pass. Cross-chat coordination tools were unavailable in
  this runtime; no foreign process was controlled or signalled.
- Local only: all phase jobs are terminal, with no package/PCK rebuild, commit,
  push or publication. No full-mission or aggregate repository gate claim.
  Evidence: `artifacts/tactical-thin-part-refinement-20261020-r3/acceptance.json`.

Working if: the white flag retains its original plane and source identity, the
corrected star facets keep their original paint and vertices while facing outward,
black occlusion interiors disappear, and the source/Modern/retained-art checks pass.


## 2026-10-20, whole-roster Blender material and source-normal pass (revision 27)

- Nell assigned another pass across the complete roster, explicitly using Blender.
  Reviewed all 57 states in 114 new editable-master geometry views and 57 Cycles
  baked-material views. Two exact aliases retain their donor master basis. Thirteen
  final before/after renders separately inspect original bridge top/underside sets
  and the seven corrected masters. The implementing lead reviewed its own output.
- Reoriented finished facets for six bridge states to match the freshly decoded
  original prefix normals. Top and underside owners retain distinct signs. Corrected
  the ten inward red roof-cap facets on building 151, preserving its deliberate red
  colour. Every affected facet keeps its exact vertex membership, material, colour,
  component and original ownership. Bounds, surface area, source wirework, bridge
  gaps and all runtime triangle counts remain unchanged.
- Cycles exposed false occlusion and inverted normal-map patches where bridge
  108/114 top and underside owners were baked together. Fresh original decoding and
  the existing static-face selector confirm that these coincident owners are
  alternatives, despite sharing a root. Read-only Astra advice was independently
  checked. A 256px winding-only pilot still produced median AO 0. Owner-matched,
  temporary low/master subsets fixed all six owners to AO 255 and normal-blue 255.
  Five-channel baking clears once per channel and retains both sides' UV islands.
  Complete original-owner meshes are exported, with no temporary subsets saved.
- Seven full Blender rebakes completed naturally under CPU4, 4 GiB RSS and the
  declared 1,200-second aggregate budget (517 seconds, peak 1.43 GB RSS). The actual
  masters, normal/tangent/AO-equipped GLBs and affected atlas slots are installed
  through the existing scoped packer. All full-resolution sampled deck/cap interiors
  have median AO 255 and outward tangent normals. The other 50 catalogue entries
  and exports, and every pixel outside the seven slots across all 15 maps, are exact.
- Root verification: 110 Python asset/gate/package tests pass with no skips.
  Headless admission passes 1,217,162 checks. Four serial native batches pass
  382 checks across 42 views at 4x, with zero forbidden pixels, exact Modern
  restoration and unchanged source packets. Original 68 inputs, 160 runtime source
  pins and 156 untouched art pins remain exact. A fresh original decode reproduces
  the source-registry pin. All 80 rollback files are authenticated; 95 incumbent
  test-method ASTs are unchanged, with three observed-defect regressions added.
- Retained failures and corrections: an initial helper assumed a dictionary where
  the catalogue supplies a list and made no asset writes. An initial all-up bridge
  hypothesis was corrected from the actual original normals before production
  baking. The first admission wrapper incorrectly applied the native 120-second
  outer guard to headless admission. A subsequent run completed all assertions but
  failed the inherited 120-second watchdog. Neither is recorded as PASS. After
  independent timing review, the unchanged gate completed naturally in 104.90 real
  seconds (31.89 user, 2.21 system), within the same watchdog. All failure logs and
  the timing receipt are retained; no assertion, sample setting or deadline was
  removed or raised. Severe host contention was observed; its exact contribution
  to the earlier failure remains an inference.
- Local only: no PCK/package rebuild, commit, push or publication, and no full
  mission or aggregate repository gate claim. All task-owned heavy jobs are
  terminal. Cross-chat messaging tools were unavailable; no foreign process was
  controlled or signalled. Evidence:
  `artifacts/tactical-blender-roster-20261020-r4/acceptance.json`.

Working if: each bridge side follows its original normal and visibility owner,
separate bakes eliminate false coincident occlusion and inverted tangent patches,
the original red cap and source geometry remain intact, and production ownership,
Modern restoration and the unchanged admission deadline all pass.


## 2026-10-20, Molot, Bradley, BRDM and crew feet (revision 28)

- Nell requested stronger BRDM weapon detail, formed Sagger/Spigot feet, Object
  477A Molot identity for F-ST and a more recognisable Bradley. Her subsequent
  9P148 photograph corrected the BRDM launcher arrangement and road-going pose.
  Both variants now have five enclosed canisters on a central pedestal, saddles
  and end caps, with smooth stowed-auxiliary-wheel panels and four main wheels.
  The earlier exposed rack and belly wheels were an inaccurate combination for
  this reference pose. Corresponding wrecks are updated; 144 remains a 142 alias.
- Molot has a connected low, broad turret, single heavy gun, skirts and seven road
  wheels, with matching wreck structure. Bradley has a compact faceted turret,
  fitted mantlet, raised twin TOW enclosure, intake and trim vane. Both crews have
  Blender-sculpted toes, heels, arches, insteps and fitted ankles. Complete
  body-plus-head counts are 7,776/7,868, below the unchanged 8,192 cap.
- Eight editable Blender masters, their normal/tangent/AO-equipped GLBs and nine
  states are installed through the existing scoped packer, 79 changed files.
  Final geometry fingerprints match current source recipes. Actual bake-recipe
  hashes remain recorded per model, including the separate corrections; older
  bakes have not been relabelled as fresh. The implementing lead inspected its own
  Blender material renders. All 48 other entries and every outside-slot pixel
  across all 15 maps stay exact.
- Root validation: the initial 37-test asset run had 36 passes and one Molot
  sprocket/road-wheel clearance failure. Corrected wheel stations pass that exact
  incumbent regression; a fresh Molot bake then passes six affected export,
  ownership, geometry and material checks. The failed log is retained. There are
  37 distinct asset contracts closed, rather than an all-green initial run.
- Headless admission completes naturally with 1,219,370 checks in 112.79 seconds,
  inside the unchanged internal 120-second watchdog. Five serial native batches
  pass 491 checks over 54 views, with zero forbidden pixels, exact Modern
  restoration and unchanged source packets. These angular crew views are
  body-only; independently commanded heads are tested by the established scene
  contracts. No complete-mission claim is made.
- The initial crew scene run failed two per-order negative-control assertions:
  depth-disabled forward order differs from proper depth by only nine pixels,
  while reverse differs by 342. Proper depth images are byte-identical in both
  orders. A read-only independent review and root pixel comparison identified the
  invalid assumption that every painter order must visibly disagree with depth.
  The fixture now requires depth-disabled forward/reverse images to disagree by
  >20 uniform-interior pixels, while proper-depth interior mismatch remains zero.
  Both crews produce 154 negative-control interior differences, with 520 overlap
  samples each. Filled-area, opaque shader/priority, coverage, restoration and
  head-command checks remain. The corrected native scene run passes 113 checks
  naturally in 95.43 seconds under the unchanged 120-second outer limit. This is
  one explicit test-fixture repair; all 160 pinned runtime source files stay exact.
- Original 68 inputs, source-registry fresh decoding and 328 retained pins remain
  exact. All 96 art rollback files and the fixture preimage are authenticated.
  Ninety-six incumbent Python test methods are exact; two are updated for the
  authorised redesign and four observed-feature regressions are added.
- Retained authoring failures: the initial eight-model aggregate bake reached its
  1,200-second deadline after two completions, and an isolated Bradley bake reached
  900 seconds with advancing channels. Timing evidence and read-only advice led
  to serial per-model 1,800-second authoring budgets. CPU4, 4 GiB RSS, 2 GiB phase
  cap, original bake resolutions and 12 samples were retained. Runtime/test
  deadlines were unchanged. A baseline scene diagnostic lacked the old runtime
  dependencies and failed admission; it is retained as inconclusive, not evidence
  of baseline depth behaviour. No foreign process was controlled or signalled.
- Local only: all task-owned jobs are terminal. No package/PCK rebuild, commit,
  push or publication. Evidence:
  `artifacts/tactical-blender-roster-20261020-r5/acceptance.json` and
  `finished-models.png` in that directory.

Working if: the supplied BRDM launcher and stowed-wheel pose are recognisable,
Molot and Bradley have their specified silhouettes, both crews have formed boots,
and unchanged source ownership, head isolation, budgets and Modern restoration
pass the finite asset/native checks.


## 2026-10-20, complete military vehicle camouflage (revision 29)

- Nell requested camouflage/textures for all tanks and related vehicles. Applied
  family-authored woodland finishes to all 34 vehicle states through 32 masters,
  including every tank, carrier, BRDM, truck, Hind state and matching wreck. The
  existing 144/142 and 164/163 aliases keep their exact donor basis. NATO-style
  green/brown/charcoal and Eastern-style olive/khaki/dark-green use stable physical
  object coordinates. The Hind retains its blue underside. Surviving wreck plates
  retain scorched family paint; tyres, tracks, glazing, optics, bare metal, true
  signals and woven truck cover retain their material identities.
- Rebaked albedo only in Blender, retaining 2048px intact/1024px wreck sources and
  12 samples. The 128 source normal/AO/roughness/metallic files are byte-exact.
  All 34 GLB exports preserve every mesh attribute and index byte-for-byte, and
  exported non-colour map pixels are exact. Every one of the 57 catalogue model
  entries remains identical, including geometry, UVs and source ownership. All
  23 nonvehicle states and every outside-slot pixel across all 15 maps are exact.
  Installed 136 authenticated file deltas through the established scoped packer.
- Root inspected its own 64 front/rear textured Blender views, the two Cycles
  Abrams pilot views and all 34 native game-scale colour witnesses. Six Python
  checks pass: three new camouflage eligibility/family regressions, the incumbent
  material-profile check and two existing baked export/alias checks. A direct
  Blender smoke check exercises the changed component-aware material-slot API
  for both intact armour and surviving wreck plates, preserving source IDs.
- Nine serial native batches pass 315 checks over all 34 states, with zero
  forbidden pixels, exact Modern restoration and unchanged source packets.
  Each finishes naturally within the unchanged 120-second guard. Geometry, UVs
  and other maps are independently exact, so this colour-only witness uses one
  readable game-scale pose per state with all inherited per-view assertions.
  No aggregate repository or full-mission gate claim is made.
- Original 68 inputs and all 160 runtime source pins remain exact. All 472 art
  preimages and the four source/test backups are authenticated. The 102 incumbent
  Python test methods remain exact; three camouflage regressions are added.
  Actual per-model colour-refresh and prior non-colour recipe provenance remain
  recorded rather than treating retained maps as fresh bakes.
- Retained pilot failures: the first geometry fingerprint incorrectly included
  deliberate material-slot changes. A diagnostic isolates `material_index` as
  its only changed field. The revised guard still checks positions, polygons,
  UVs and source/component IDs; the completed colour image was authenticated and
  retained before finishing export. Source-bound GLB identity is independently
  verified for every final state.
- Several accepted Blender files retain older hidden donor masters. The first
  refresh selector used the first `_MASTER` name, and five completed candidate
  bakes were disqualified: 118, 119, 120, 121 and 122. They are quarantined and
  never installed. The 124 eligibility failure stopped before its bake. A full
  32-file inventory established exact source-shape selection for both GAME and
  MASTER objects. Corrected bakes and every final receipt use the requested ID.
- BTR 137 reached the initial 900-second authoring bound before output. Host
  pressure was observed at load 470 on 10 logical CPUs with 27.5 GiB swap used;
  a task-only CPU readback also shows severely reduced scheduling throughput.
  A proposed emission-colour shortcut failed its comparison, up to 85 RGB units
  and mean 11 to 13 per channel. It was rejected, and 116's original diffuse
  colour image was restored exactly before export. No emission result is installed.
- Remaining authoring budgets were explicitly bounded at 1,800 seconds, keeping
  CPU4, RSS4 GiB, original resolution, samples and runtime deadlines unchanged.
  Short wreck jobs ran first, with BTR last. All completed naturally; BTR's final
  accepted run took 595.6 seconds. The phase stays below its 4 GiB artifact cap;
  managed authoring jobs retained at least 40 GiB free space. No foreign process
  was controlled or signalled.
- Local only: all task-owned jobs are terminal. No PCK/package rebuild, commit,
  push or publication. Final receipt and full front/rear/native contact sheets:
  `artifacts/tactical-camouflage-20261020-r6/acceptance.json`.

Working if: all 34 vehicle states show coherent camouflage in Blender and the
native renderer, surviving wreck paint matches its family, all source/geometry/
non-colour invariants pass, and no invalid pilot or shortcut reaches the installed
pack.


## 2026-10-20: Further Blender model refinement, revision 30

- Completed the requested model pass on eight masters and nine states. Molot
  receives a broader low turret and weapon hood, heavier gun root and fuller
  seven-wheel running gear. Bradley receives a tapered mantlet, fitted race
  and hatch collars, chamfered twin TOW enclosure and connected pivots. BRDM
  receives longer closed canisters, dust covers, bands, saddles and a seated
  central mount, with belly wheels stowed. Matching wrecks retain those family
  cues. Both crews receive lower toes, formed insteps, raised narrow arches
  and distinct heels through the shared editable Blender sculpt.
- Fresh full-resolution five-channel Blender bakes are installed through the
  existing scoped packer: 83 authenticated file deltas. All 48 other states,
  all outside-slot pixels across 15 maps, original source commands and all
  160 runtime source pins remain exact. Original 68 inputs and fresh SHAPE.TBL
  registry decoding pass. All 105 incumbent Python test methods remain exact;
  two focused geometric regressions are added. Eighteen focused checks pass.
- The author reviewed its own 18 PBR views and all 42 native vehicle angles.
  Four native batches pass 382 checks, with zero forbidden pixels, exact Modern
  restoration and unchanged input packets. Each returns naturally within its
  unchanged 120-second bound. Exact per-batch elapsed values were not persisted
  before a later scene timeout; the terminal results and reports are retained.
- Two CPU BRDM bakes reached their finite authoring limits under severe host
  pressure. A real production five-channel Metal smoke comparison passed,
  with normal/AO/roughness/metallic exact and at most 1/255 albedo deviation
  on three probe pixels. Full fresh Metal BRDM retries completed; no partial
  channels or invalid candidate maps were installed. Four masters use CPU and
  four use Metal, with actual device provenance recorded only for executed
  bakes. Resolution, samples, cages, material recipe and runtime guards remain
  unchanged. Historical failures remain in the phase evidence.
- Runtime acceptance is INCOMPLETE. Initial admission prints 1,223,094 checks
  and zero content errors, then fails the unchanged watchdog with exit 2. One
  timestamped warm retry also fails, at 189.3 seconds process elapsed: load
  finishes at 99.8 seconds engine time, mapping at 148.4, and all checks at
  176.8. Removing timestamp prints from the diagnostic copies recovers the
  original run and grounding functions byte-for-byte. No third equivalent
  admission retry or watchdog change was made.
- The initial complete native scene prints 113 checks and zero content errors
  but misses its external 120-second deadline, so it fails. The first warm
  native diagnostic exits 0 at 54.1 seconds without completion markers and is
  correctly rejected. Godot help confirms its separate --quit-after 1200
  setting counts iterations, not seconds. One discriminating retry omits that
  iteration cap while retaining both actual 120-second guards and all scene
  assertions. It times out after loading and grounding 115, during grounding
  163, before the crew scene. Thus removal of the cap does not close acceptance.
  Exact host/GPU delay cause is unverified; observed load was 826 to 893 on ten
  logical CPUs during these checks. No foreign process was controlled.
- Local model delivery is complete; full runtime sign-off remains blocked by
  the failed timing checks. Closing it requires natural completion of both
  complete checks with their required markers inside the existing deadlines.
  No PCK/package rebuild, commit, push or deployment was performed. All owned
  authoring and validation jobs are terminal. Evidence and actual preview:
  `artifacts/tactical-model-refinement-20261020-r7/acceptance.json` and
  `artifacts/tactical-model-refinement-20261020-r7/finished-models.png`.

Working if: the requested model forms and camouflage are present in editable
Blender masters and installed art, untouched source and atlas regions stay exact,
and no incomplete or over-deadline runtime run is presented as accepted.


## 2026-10-21: Focused Sagger and Spigot Blender refinement, revision 31

- Nell requested another pass to perfect the two operators. Reworked the shared
  sculpt with slimmer shoulders/elbows, less bulky hands and fitted cuffs.
  Seated the independent heads further over the jacket neck and eased the neck
  profile. Added a standing collar, folded collar leaves, fitted twin pockets
  and flaps, placket, belt loops and a buckle at the actual belt height. The
  held cases have chamfered edges and retain distinct manual/optical controls.
  Boot toe creases are integrated into the continuous leather last. The source
  pose envelopes, ownership, command offsets and head bindings remain intact.
- Retained pilot failures and rejected candidates. The first sculpt stopped on
  my incorrect helper import before export. Subsequent inspection and tests
  caught a missing cuff, pocket/body intersections and a reversed collar cap.
  Those are corrected in the final source and protected by the added fitted
  tailoring regression and retained visual evidence. Raised wire-like toe
  seams were discarded in favour of an integrated leather crease.
- The first full bake revealed a broad dark armpit patch. An AO-only bypass
  leaves it unchanged; removing only the normal-map link removes it. A real
  2048px/12-sample normal pilot with cage 0.012 and max ray distance 0.04 removes
  the broad patch, with 4,270 unambiguous normal interiors and no black misses.
  Applied that projection only to crew bodies, retaining independent-head and
  other-family recipes. Fresh full five-channel bakes replace both candidates.
  No pilot map or disabled normal link is installed.
- Both final Metal bakes complete naturally, in 36.1 and 34.4 seconds. They use
  the retained validated device-only backend path, full 2048px body/512px head
  sources and 12 samples. Geometry totals including heads are 7,999 and 8,091.
  The author inspected its own ten final PBR views: front, rear, side, equipment
  and boot detail for each. The Blender preview uses actual baked game meshes.
- Installed 32 authenticated deltas through the existing scoped packer. All
  55 other states, every outside-slot pixel across all 15 maps, original 68
  inputs and 382 runtime-directory pins remain exact. Fresh SHAPE.TBL registry
  decoding matches. All 107 incumbent Python test methods remain exact and
  one focused regression is added. Thirteen focused tests pass, including
  installed export, tangent, contact-occlusion and bake-interior contracts.
- Native scoped crew verification passes 69 checks in 35.35 seconds. It copies
  the complete incumbent crew block verbatim and retains its positive and
  depth-disabled negative controls, fallback/restoration checks, independent
  heads and subsequent pooled-vehicle occluder. Material and visibility
  restoration remain intact. Fixed synthetic head anchors prove binding and
  occupancy rather than a complete natural mission pose.
- Measured full-roster loading improved to 24.5 seconds from the prior 99.8.
  This new evidence justified one retry of the two historical open checks.
  Complete headless admission now passes 1,225,006 checks in 38.58 seconds.
  The complete native scene passes 113 checks in 40.83 seconds. Both exit 0
  naturally within unchanged inherited 120,000ms and external 120-second wall
  guards. The separate --quit-after iteration cap is omitted because it can
  prematurely terminate awaited tests; no assertion or wall guard is changed.
  These fresh results close the old timing gaps for the current installed pack.
- Local only. All task-owned jobs are terminal. No PCK rebuild, commit, push or
  deployment. Evidence: `artifacts/tactical-crew-refinement-20261021-r8/acceptance.json`;
  final actual render recap: `artifacts/tactical-crew-refinement-20261021-r8/finished-crews.png`.

Working if: the two revised operators retain their original source and command
contracts, fitted garment and boot forms remain visible with normal maps active,
all 55 retained states stay exact, and every recorded acceptance run has a
natural successful terminal result inside its unchanged wall-clock bound.


## 2026-10-21: Sagger and Spigot formed-grip pass, revision 32

- Refined both operators in Blender: explicit separated fingers, curved tips,
  mirrored opposed thumbs, smaller balanced heads/helmets and directional cloth
  folds. Kept the accepted boots and original pose, owner and head-command
  contracts. Game-plus-head counts are 8,033 and 8,125, within 8,192 each.
- Corrected open finger joins and inconsistent winding before baking. An
  incumbent depth check rejected an overly shallow resized head; restored its
  depth without relaxing the assertion. All 108 incumbent test methods remain
  exact; one new grip topology/proportion regression is added.
- Actual full-quality PBR inspection exposed black finger slivers. Disconnecting
  only the normal link removed them. Matched per-part normal projection and
  shared knuckle vertices correct the bake with normal maps active. Twelve grip
  parts use cage 0.002/max ray 0.008, the remaining body retains 0.012/0.04,
  independent heads retain their recipe, and contact AO uses the complete shell.
  The Sagger pilot has 4,610 unambiguous albedo/normal interiors, including 510
  hand interiors, with no black misses. The installed test covers both operators.
- Final five-channel Metal bakes retain 2048px body, 512px head and 12 samples.
  The implementing author inspected ten actual baked Blender views. A render
  aborted in native Metal shader-cache allocation; the macOS stack is recorded,
  and one fresh-process retry completed naturally with unchanged quality.
- Recovered required disk headroom by converting 474 byte-identical private R8
  staging copies to independently verified APFS clones. No path or data bytes
  were lost, and no master, backup, unique output or evidence was removed. All
  original memory, disk, artifact and wall-clock guards remain unchanged.
- Installed 32 authenticated deltas through the existing scoped packer. All
  55 other states, outside-slot pixels across 15 maps, 68 original inputs and
  382 runtime-directory pins remain exact. Fresh source-registry decoding agrees.
- Fourteen focused Python tests pass. Original headless admission passes
  1,227,614 checks in 21.85 seconds. The complete native scene passes
  113 checks in 30.53 seconds. Both exit 0 naturally within inherited
  120,000ms and external 120-second guards, with original assertions unchanged.
  Native synthetic head anchors prove binding/occupancy rather than a natural
  full-mission pose. No aggregate repository or package gate is claimed.
- Local only. No PCK rebuild, commit, push or deployment. Evidence and actual
  recap: `artifacts/tactical-crew-refinement-20261021-r9/acceptance.json` and
  `artifacts/tactical-crew-refinement-20261021-r9/finished-crews.png`.

Working if: the installed grips show separated fingers and opposed thumbs with
active corrected normal maps, original pose/source/head contracts and 55 retained
states remain exact, and acceptance logs have natural successful terminal results
inside their unchanged guards.


## 2026-10-21: Complete Sagger/Spigot body, boot and hand refinement, revision 34

- Completed the requested Blender pass, integrating the earlier disk-blocked
  R10 body and boots. Raised the waist 3.5 raw units and shortened the pelvis;
  softened shoulder/knee volumes and retained tapered limbs and a connected
  raised thigh. Formed boots are about 14 percent shorter than installed R9,
  with asymmetric rounded toes, narrower heels, closer ankles and grounded
  toe/heel contacts. Original independent heads and source pose envelopes remain.
- Reformed palms and opposing thumbs. Fingers have graded lengths/radii and
  eight-sided game sections, with articulated distal pads seated near the held
  case front at Y1.2. Planar caps retain closed outward topology while allocating
  the existing polygon budget to curvature. Four source-only low/master cases
  and the actual geometry checks pass. Final combined totals are 8,073/8,165.
- Fresh full-quality five-channel Metal bakes and editable masters replace both
  states, with 2048px body/512px head sources and 12 samples. Matched per-grip
  normal projection and complete-shell contact AO remain active. The implementing
  author reviewed ten actual baked Blender views. No partial prior channels or
  quality-reduced map is installed.
- Nell answered the storage question: "Proceed anyway. Do not stop." Recorded a
  task-specific two-model reserve of 16GiB at launch and 12GiB while running,
  based on prior measured RSS/output and retained guard margins. All 4GiB RSS
  and phase-output caps, full bake quality, 1800s authoring and 120s runtime
  guards remain. Native jobs run serially. No foreign process, unique master,
  rejected candidate, rollback or source evidence is removed. The active scope
  and resource record reflect this explicit case-specific choice.
- Installed 26 authenticated deltas through the existing scoped packer. All
  55 other states, outside-slot pixels across 15 maps, 68 original inputs and
  382 runtime-directory pins remain exact. Original head geometry is exact.
  Six freshly baked head maps are byte-identical to the prior maps; a recursive
  before/after comparison proves the complete 26-file delta, instead of the
  anticipated 32. No map or state is omitted.
  All 111 immediate-baseline methods remain unchanged; one fingertip-contact
  regression is added. Relative to accepted R9, 107 incumbent methods remain
  exact, two authoring expectations follow the shorter boots/higher belt, and
  three focused regressions protect joined anatomy, UV slivers and fingertip fit.
- Seventeen focused Python tests pass. Complete original admission passes
  1,228,006 checks in 101.04 seconds. The complete native scene passes
  113 checks in 43.20 seconds. Both exit 0 naturally within inherited
  120,000ms and external 120-second guards; no runtime assertion is changed.
- R11 closes the outstanding requested model delivery. R10 remains a preserved
  historical incomplete candidate, superseded by the verified R11 pair. Native
  fixed head anchors prove binding/occupancy rather than a full-mission pose.
  Local only, no PCK rebuild, commit, push or publication. Evidence and actual
  recap: `artifacts/tactical-crew-refinement-20261021-r11/acceptance.json` and
  `artifacts/tactical-crew-refinement-20261021-r11/finished-crews.png`.

Working if: both final operators are installed with joined anatomy, natural
boot and grip forms, full-quality active normal/AO maps and original head/source
contracts, while 55 retained states and all untouched atlas pixels stay exact
and the complete native checks finish successfully inside their original limits.


## Fuller Sagger/Spigot anatomy, Blender revision 35

Both operators receive fuller thighs, knees and calves, with a continuous taper
into wider boot shafts. The sculpt increases calf radii by roughly 25 to 30
percent and gives the thighs fuller width and depth. Rounded toe boxes and fuller heels/instep transitions retain planted
contacts and the existing foot length. The new palms carry more metacarpal volume;
thicker fingers taper gently to broad pads, and fuller opposed thumbs keep the
control grip readable. Individual graded fingers and original hand ownership
remain intact. Body/head totals are 8,064/8,156, within 8,192 each.

Both editable Blender masters and exports have fresh full five-channel bakes at
2048px body, 512px head and 12 samples, with matched grip normal projection and
full-shell contact AO active. The implementing author reviewed its own ten actual
PBR views. A concave source-boundary opening found in the rear view was
corrected by keeping seam Z fixed and projecting newly sliced seam vertices.
Normal and AO maps stay active. This remains a stylized, source-bound game pose.

The scoped install changes 26 authenticated files. All 55 other states,
outside-slot pixels across 15 maps, 68 original inputs, 382 runtime pins and the
independent head geometry remain exact. All 112 immediate-baseline test methods
are unchanged; one regression protects fleshy digit/palm and calf volume,
plus entering-ray coverage at the source thigh seam in both low and master meshes.
Eighteen focused tests pass. Original admission passes 1,227,806
checks in 31.91s; the complete native scene passes
113 in 41.11s, naturally inside unchanged 120s guards.

The existing 4GiB RSS/output caps, 16GiB launch/12GiB running disk reserve and
1800s authoring limits are retained. No prior master, rollback or evidence is
removed. Local only: no PCK rebuild, commit, push or publication. Evidence:
`artifacts/tactical-crew-refinement-20261021-r12/acceptance.json`.

Working if: both operators visibly show fuller hands and legs with fitting boots,
original source/head contracts and all other states remain exact, and the final
full-quality Blender bakes and original complete admission/scene checks pass.


## Photograph-referenced ground crews, Blender revision 36

Nell explicitly selected the real firing setup. This supersedes revision 35's
upright per-face crew silhouette for Sagger 161 and Spigot 162 only. The new
kneeling crews have joined clothed anatomy, full thighs and calves, shaped
boots and closed graded fingers with opposed thumbs. The grounded Sagger
controller carries a joystick and tall periscope, beside a separate finned
missile on its case lid. Spigot has a horizontal container, guidance housing,
attached ocular and three grounded tripod feet. The controller and tripod
clear the boots. Both full five-channel bakes retain 2048 px body, 512 px head
and 12 samples. Complete body/head totals are 6,630 and 6,332, below 8,192.
The implementing lead authored and inspected ten actual PBR Blender views.

References retained with source metadata: US DoD DD-ST-85-01240 and 01242,
14 November 1984, public domain per their Commons pages; Dmitry Shutov/Mil.ru,
12 May 2021, CC BY 4.0. The 2021 photograph informs equipment and firing posture,
not era-exact uniform reproduction. Unmodified photographs are packed as
non-rendering references in the shared editable sculpt, with no photographic
pixels incorporated into the model textures.

Only these two Modern models advertise the optional ground-atgm-v1 pose.
A single admitted rigid transform drives body and attached head, real depth,
and the replacement ownership mask at the original painter slot. Any missing
or inconsistent source/head witness selects the complete incumbent path.
The original normalized head geometry and command identity remain exact.
A pose-only dynamic Q14-context candidate handles independently rounded
original anchors, rechecking every vertex under unchanged 2.0001 raw / .25 pixel
limits; malformed, reflected, sheared or inconsistent context fails closed.
Classic, gameplay, registry, roots, bounds and original input bytes remain.

Eighteen focused Python checks pass. The complete asset admission gate passes
1,215,064 checks; the adapted native scene gate passes 51; the
focused native pose gate passes 236, including near-plane
crossing, bidirectional mask coverage, vacated upright pixels, real-depth
negative control, mode/cache restoration and later-occluder protection.
Nine Python expectations and the obsolete upright scene branches are explicitly
dispositioned, rather than reported unchanged. 104 incumbent Python methods
remain exact. A genuine unmodified scenario 3 packet admits one of two Sagger
candidates; the other has no visible head span. Fourteen negative context
mutations reject. In that capture, foreground terrain hides the lower pose; the old upright
head pixels correctly vacate while all noncrew coverage remains exact. This
is admission and occlusion evidence, not a visible live-mission crew demonstration.

The scoped install changes 28 authenticated files. All 55 other catalogue entries,
outside-slot pixels across 15 maps, 68 original inputs, 377 untouched runtime pins
and all 869 backup pins remain exact. Existing 16 GiB start / 12 GiB running disk
reserves, 4 GiB RSS/output caps, 1800 s authoring and 120 s runtime guards remain.
No prior master or rollback was deleted. Local only, without PCK rebuild,
commit, push or publication. Evidence:
`artifacts/tactical-crew-refinement-20261021-r13/acceptance.json`.

Working if: both correct low firing setups appear in the actual Blender and
native model studies, their masks contain no upright ghost silhouette, rejected
witnesses and original foreground remain authoritative, and unrelated states
and source data stay exact.


## Ground-crew finishing polish, Blender revision 37

The approved kneeling Sagger and Spigot firing setups remain. Leather/cloth and
sole material changes now follow actual cut planes, removing the sawtooth rims
from centroid-coloured triangles. The folded rear calf also has a straight
shaft boundary and a correctly leather-coloured heel. Small sewn cuffs surround the sleeve/wrist
joints. The Spigot near hand and Sagger far hand are reseated on their controls;
all four index-to-control vertex distances are below .5 raw units, with the
closed graded fingers and opposed thumbs preserved.

Controller, missile-case and guidance-housing edges have small physical bevels.
Sagger fins have tapered profiles; Spigot container bands have chamfered edges.
Microscopic hinge relief belongs to the bake master; small game sockets use
an efficient eight-sided profile. The first pilot failed the unchanged 85 percent
interior-texel coverage check. Its full assets and views remain under the R14
pilot directory. The corrected geometry passes that check without a threshold,
map-resolution, sample-count or normal/AO reduction. A native pilot also
caught one ownership pixel at a redundant forearm subdivision. Belt-only
material cuts now stay within the belt region; the runtime and zero-mismatch
coverage assertion remain unchanged. The failed assets and reports are retained.

Both editable masters, GLBs and five-channel maps are freshly baked at 2048 px
body, 512 px head and 12 samples. Complete body/head totals are 7,866 and
7,614, within 8,192 each. The implementing lead inspected its own ten
actual PBR views, including unobstructed boot profiles and control close-ups.
Twenty focused Python tests pass. All 113 immediate-baseline Python methods and
all 416 runtime pins remain exact; two new regressions cover rim/cuff geometry,
hand contact and shaped equipment profiles. Fresh installed-art gates pass
48 pose-admission checks, 236 native-pose
checks, 1,225,044 format-shard-0 asset-admission checks and 51 native-scene
checks. The retained genuine R13 source packet is exercised against these new
assets, preserving its noncrew foreground and correctly vacating the old head.
This does not claim a visible live-mission crew demonstration.

The scoped install changes 28 authenticated files. All 55
other entries, every outside-slot pixel across 15 maps, 68 original inputs and
the raw head geometry/pose remain exact. Existing 4 GiB RSS/output caps,
16 GiB start / 12 GiB running disk reserve, 1800 s authoring and 120 s runtime guards
remain. R13 masters and all 913 preimages are retained. Local only, without
package rebuild, commit, push or publication. Evidence:
`artifacts/tactical-crew-refinement-20261021-r14/acceptance.json`.

Working if: the final Blender close-ups show clean boot rims, seated cuffs and
control grips, finer launcher profiles, unchanged firing/head poses and source
data, while unrelated assets remain exact and full-quality native checks pass.


## Kneeling crew anatomy refinement, Blender revision 38

Sagger and Spigot retain their approved ground-supported equipment and rigid
head pose. The clothed pelvis and tunic are rebalanced, shoulder/elbow masses
reduced, and the forward shin's authored centreline increased from about 9 to
14 raw units. The raised knee remains distinct from the weight-bearing rear
knee, which now reaches -89.878 against the -90 ground plane. The rear boot
is rebuilt around the horizontal calf: lowered toe, lifted heel and a folded
ankle, replacing the upright duplicate front boot. The front shoe has a softer
toe box, shallower arch and less blocky heel.

Palms gain depth, opposed thumbs are less erect, and each curled finger ends
in a shallow rounded pad. All twelve closed palm/digit parts remain, with
consistent winding and four distinct graded fingers per hand. All four grips
remain within the existing .7-raw-unit control-contact limit. Pockets now fit
the revised tunic surface explicitly, excluding neighbouring sleeves.

Twenty-one focused Python checks pass. Two previous rear-boot expectations
were revised because they required an upright shaft and grounded rear heel;
the new checks require the intended raised heel and grounded toe. All 113
other immediate-baseline methods remain exact. A new regression checks closed
rounded hand pads, cushioned palms and the grounded rear knee. The first
anatomy trial and its three test failures remain in the R15 evidence: two old
rear-heel expectations and the real pocket-fit defect corrected in source.

Fresh Blender masters, GLBs and all five channels retain 2048 px body / 512 px
head and 12 samples. Body/head totals are 7,730 and 7,480, within
8,192 each. Albedo and normal interior-texel coverage passes the unchanged
85 percent floor, with zero black interior misses. The lead inspected its own
ten final PBR views, including both boot profiles and control close-ups.
Installed-art gates pass 48 headless pose checks,
236 native pose checks, 1,223,972
format-shard-0 admission checks and 51 native-scene checks.
The twelve native pose studies have zero ownership mismatches, stale pixels
or unexplained mask pixels. The retained genuine gameplay packet preserves
all noncrew foreground and vacates the old upright head; its lower crew is
occluded, so this is not a visible live-mission crew demonstration.

All 55 unrelated entries, outside-slot pixels across 15 maps, 68 original
inputs, raw head/pose, launcher geometry and 416 runtime pins remain exact.
The scoped install contains 29 authenticated deltas;
R14 masters and all 913 preimages are retained. Existing 4 GiB RSS/output,
16 GiB start / 12 GiB running disk and 1800 s authoring / 120 s runtime guards
remain unchanged. Local only, without package rebuild, commit or publication.
Evidence: `artifacts/tactical-crew-refinement-20261021-r15/acceptance.json`.
The supplemental kneeling anatomy photograph and inspection record are linked
in `references/kneeling-anatomy.json`; its pixels are not used in textures.

Working if: side/rear Blender views show continuous folded calves and ankles,
weight-bearing knees, proportioned trousers and rounded working grips, while
source data, launchers, runtime and unrelated assets remain unchanged.


## Kneeling crew proportion polish, Blender revision 39

Sagger and Spigot receive a bounded anatomy pass over revision 38. Lower,
flattened shoulder masses merge into a sloping tunic transition; waist and
seat volumes are fuller. Thighs and calves gain proximal fullness rather
than uniform cylindrical thickness. Leg joint centres and the approved
grounded-knee, folded-ankle firing setups are retained. The front boot gains
rounded toe/heel end stations, and the rear boot has a smoother
instep transition and narrower rounded toe. Four distinct finger curls vary
across each grip, and opposed thumbs gain closed rounded terminal pads.
Pocket faces now follow the curved tunic in the clear medial chest region.
This corrects the old fit query mistaking upper arms for jacket and the
flat faces cutting through the tunic. Both rejected trials are retained
under `pilots/`.

All 116 incumbent test methods remain unchanged. One regression now checks
pocket ray ambiguity and face-interior clearance; 22 focused Python checks
pass. Both fresh editable Blender masters retain 2048 px body / 512 px head,
12 samples and all five channels. Body/head totals are 7,892 and
7,644, below 8,192 each. The unchanged interior-texel check exceeds
85 percent on albedo/normal maps with zero black misses. The lead authored
this pass and inspected its own ten actual baked PBR views against revision
38 and the retained equipment photographs.

Installed-art gates pass 48 headless pose checks,
236 native pose checks, 1,225,252
format-shard-0 checks and 51 native-scene checks. Twelve
native pose cases have zero ownership mismatch, stale or unexplained mask
pixels. The retained genuine gameplay packet preserves noncrew foreground
and vacates the old upright head. Its lower crew is occluded, so it does
not demonstrate a visible live-mission crew.

All 55 unrelated entries, outside-slot pixels across 15 maps, 68 original
inputs, independent raw head/pose, launcher geometry and 416 runtime pins
remain exact. All 913 R15 preimages are authenticated and retained. The
scoped install contains 28 exact deltas. Existing memory,
output, time and disk guards remain unchanged. Local only, without package
rebuild, commit or publication.
Evidence: `artifacts/tactical-crew-refinement-20261021-r16/acceptance.json`.

Working if: side/rear views show sloping shoulders, contoured clothed limbs,
rounded boot ends and differentiated working grips, while source, head,
equipment, runtime and unrelated assets stay unchanged.


## Crew head proportion polish, Blender revision 40

Sagger and Spigot receive a head-only pass over the accepted revision 39
bodies. Helmet lateral width is reduced by 12.5 percent while its
front-to-back clearance and command depth contract are retained. The chin
and lower jaw gain depth and breadth; the occiput tapers into a continuous
nape. Thin, elongated cupped ears replace the raised oval volumes, with a
rolled helix and inset concha. The neck root, eye/iris geometry, complete
body meshes, launchers and rigid firing poses remain exact.
A normal-map-off diagnostic identified cross-surface projection seams.
One inward cheek-strap winding is corrected. The complete head donor and
receiver retain global UV padding, with shorter head-only normal rays
(.006 cage/.018 maximum ray distance). Contact AO and non-head bakes are
unchanged. Rejected donor-isolation trials and their artifacts are retained.

All 117 incumbent test methods remain unchanged. One new regression
reproduced the inward strap before repair; 23 focused Python checks pass. Both fresh editable Blender masters retain 2048 px body / 512 px head,
12 samples and all five channels. Body/head totals are 7,636 and
7,388, below 8,192 each. The unchanged body interior-texel check
exceeds 85 percent on albedo/normal maps with zero black misses. The lead
authored this pass and inspected its own thirteen actual baked PBR views,
including front/profile/rear head closeups. Earlier diagnostic profiles are
retained and are not the installed result. The retained real Spigot photo
supports the equipment/posture reference; its obscured face does not supply
head-anatomy evidence. No reference pixels enter the textures.

Installed-art gates pass 48 headless pose checks,
236 native pose checks, 1,225,252
format-shard-0 checks and 51 native-scene checks. Twelve
native pose cases have zero ownership mismatch, stale or unexplained mask
pixels. The retained genuine gameplay packet preserves noncrew foreground
and vacates the old upright head. Its lower crew is occluded, so it does
not demonstrate a visible live-mission crew.

All 55 unrelated entries, outside-slot pixels across 15 maps, 68 original
inputs and 416 runtime pins remain exact. The accepted body sculpt cache,
its authoring scene and body recipe are retained unchanged; the canonical
updated complete models are the two roster vehicle.blend files. All 913
preimages are authenticated and retained. The scoped install contains
28 exact deltas. Existing memory, output, time and disk
guards remain unchanged. Local only, without package rebuild or publication.
Evidence: `artifacts/tactical-crew-refinement-20261022-r17/acceptance.json`.

Working if: head closeups show a fitted helmet, elongated cupped ears and a
continuous jaw/nape transition, while eye-to-sight contact, body, equipment,
runtime and unrelated assets remain unchanged.


## Crew jaw and neck proportion correction, Blender revision 41

Nell rejected the revision 40 head proportions. Revision 41 narrows the
head and helmet around unchanged eye landmarks, lowers the crown, raises
the mouth and chin, and replaces horizontal jaw rings with an ascending
mandible. The fitted neck enters behind the chin with a visible throat
recess. Three transition rings soften the chin underside. The posterior
jaw deformation is monotonic; the former reversal that compressed the
lower occiput into a shelf is removed. The lowest three neck insertion
rings, eyes, body geometry, launchers and rigid firing poses remain exact.

Reference inspection used the public Anatomy For Sculptors head/skull
illustration at https://anatomy4sculptors.com/product/head-anatomy-course/
and Jilai's SSh-68 photograph at
https://commons.wikimedia.org/wiki/File:SSh-68.jpg (CC BY 4.0).
The reference images supplied visual guidance only; none of their pixels
enter the models or textures. The previously retained real firing-setup
references remain unchanged.

The lead authored and reviewed this work. A read-only independent advisor
rejected an intermediate profile and identified the heavy chin/throat
connector and folded occiput rows. Root reproduced the geometric fault,
implemented the correction and inspected the final actual baked views.
The result remains a stylized low-poly model with close-up faceting and
fine normal-map seams. Source inspection confirms flat shading is retained
through the bake, matching the unchanged runtime tangent-frame contract.
No seam-free or photorealistic result is claimed.

All 118 incumbent test methods remain exact. A new jaw-angle regression
fails revision 40 and passes this correction; 24 focused installed Python
checks pass. Both fresh editable masters retain 2048 px body / 512 px head,
12 samples, all five channels, the existing head-normal projection and
complete-shell contact AO. Triangle totals are 7,920 and
7,672, both within 8,192. Body interior-texel coverage remains above
85 percent; head and body checks find no black albedo/normal interior misses.

The four inherited 120-second runtime gates pass 48
headless pose checks, 236 native pose checks,
1,225,252 format-shard-0 checks and 51
native-scene checks. The initial native-pose attempt timed out at 120
seconds after nine cases. Its logs and partial images remain intact. A
single retry, after normal timing in the separate native-scene gate,
completed in 97.383 seconds with the same
120-second limit. Twelve synthetic native pose cases have no ownership
mismatch, stale or unexplained mask pixels. The retained genuine gameplay
packet preserves noncrew foreground but occludes the lower crew; it does
not prove a visible live-mission crew.

All 55 unrelated entries, outside-slot pixels across 15 maps, 68 original
inputs and 416 runtime pins remain exact. All 913 preimages and rejected
prototype evidence are retained. The scoped install contains
28 exact deltas. Existing time, memory, output and disk
guards remain; authoring additionally checks the live shared disk forecast
and a 512 MiB next-write allowance. Local only, no package rebuild or
publication. Evidence:
`artifacts/tactical-crew-refinement-20261022-r18/acceptance.json`.

Working if: front and profile views show a balanced head, ascending jaw and
clear throat recess without a lower-skull shelf, while sight contact,
jacket insertion, body, equipment and unrelated assets remain unchanged.


## Crew collar and head bake finishing, Blender revision 42

Nell requested completion of the Sagger/Spigot polish. Both editable masters
now have a fitted, closed cloth collar and a curved rear jaw/neck transition.
Eye positions, firing poses, body geometry, hands, boots and launchers remain
exact. The independent head UV layout splits larger tangent-frame bends;
only hidden closure disks are down-weighted. The visible underside brim and
helmet top cap retain their charts.

The first split-UV trial improved the grid-like seams but introduced black
marks. Root reproduced 281 unpainted head-triangle samples, including eight
skin triangles and the helmet top cap. Independent read-only advice identified
zero pixel-centre coverage on the implicated tiny charts. Whole-chart minimum
footprints before packing removed the marks. Four barycentric samples on every
head triangle now have no black albedo/roughness misses at either the 512 px
master size or the actual 232 px packed-head size. Earlier interior-only
sampling missed this defect; a new regression covers those small triangles.

The lead authored and personally reviewed all 13 final baked views. Both
models retain stylized low-poly silhouettes and fine close-up shading seams;
this is no claim of photorealism or literal perfection. The collar covers the
ragged insertion strip, and the rear neck transition is less abrupt.

The 26 focused installed checks pass; all 119 incumbent methods remain exact.
The new collar and subpixel-bake regressions are additive. Fresh body2048/head512
five-channel bakes retain 12 samples, full-shell AO and existing normal rays.
Triangle totals are 8,080 and 7,832, below the 8,192 cap.
An initial headless gate timed out under host contention. Its evidence is
retained; one retry followed a normal-timing native scene result.
Runtime checks pass 48, 236,
1,225,252 and 51 assertions within the unchanged
120-second guards. Native pose fixtures have no ownership-mask mismatch.
The retained genuine gameplay capture is partially occluded and does not
establish a visible live-mission crew.

All 55 unrelated entries, 15 outside-slot atlas regions, 68 original inputs
and 416 runtime pins remain exact. All 913 fresh preimages and rejected
candidate evidence remain retained, including the first prototype abort
and geometry-test failures. Those failures were repaired, never removed.
Local only: no package rebuild, commit, push or publication.
Evidence: `artifacts/tactical-crew-refinement-20261023-r19/acceptance.json`.

Working if: the collar closes the exposed join, the rear neck is continuous,
and head maps have no unpainted subpixel islands while original ownership,
firing setups and unrelated roster assets stay intact.


## Crew head proportions, Blender revision 43

Nell requested a slightly larger head on the Sagger and Spigot crews. Both
skulls now have approximately eight percent more height and depth. Facial
width increases about eight percent and the fitted helmet width about ten
percent. The deformation fades smoothly into the unchanged collar. Eyes,
irises and their end caps remain exact, preserving the approved sight contact.
Body geometry, hands, boots, launchers and firing poses remain exact.

The lead authored this pass and personally inspected all 13 final baked
Blender views. The models retain the intended low-poly style. Full-resolution
body2048/head512 five-channel bakes retain 12 samples, full-shell contact AO
and the existing normal projection settings. Four samples per head triangle
show no black albedo or roughness misses at 512 px and 232 px packed sizes.
Triangle totals remain 8,080 and 7,832, below the 8,192 cap.

All 26 focused tests pass, with all 121 incumbent test methods unchanged.
The four runtime gates pass 48, 236,
1,225,252 and 51 assertions within the
unchanged 120-second limits. Native pose fixtures have no ownership-mask
mismatch. The inherited gameplay capture remains partially occluded and does
not establish a visible live-mission crew.

All 55 unrelated roster entries, 15 outside-slot atlas regions, 68 original
inputs and 416 runtime pins remain exact. All 913 fresh preimages are retained.
Local only: no package rebuild, commit, push or publication.
Evidence: `artifacts/tactical-crew-refinement-20261023-r20/acceptance.json`.

Working if: full-body and profile views show larger, fitted heads while the
closed neck join, eye-to-sight contact and all non-head geometry stay intact.


## Whole-roster and menu polish, Blender revision 44

Reviewed paired views of all 57 roster states, the menu Abrams and both crew,
and the grass/shrub masters. The lead authored this pass and personally
reviewed its final images. Six roster states were refined; 51 remain exact.

The truck canopy now sags gently between its retained support bows, with
shaped skirts and closed ends. Five building states (145, 146, 154, 155,
158) have corrected non-metallic roof bakes. The three surviving ruin roofs
also have correctly oriented overlapping tile courses and narrower joints.
All 19,024 sampled roof interiors have zero metalness. Full 2048 px,
five-channel, 12-sample bakes retain normal projection and full-shell AO.
Both menu crew have softer neck and elbow transitions. Armour, faces,
helmets, gloves and pose contacts are retained; the maximum deformation
remains below one centimetre. Editable Blender masters are installed.

All 124 asset tests pass. Native checks pass: simulation 1,265, foliage 17,
complete-roster admission with format shard 0 1,226,248, scene 51, and
view shard 0 671. The menu also passes wide/compact rendering, reduced
motion, menu actions and range lifecycle. These are the named scoped gates,
not a claim that every rejection or view shard was rerun.

All 928 fresh backup pins verify, together with the separately reconstructed
and geometry-authenticated truck-source preimage. The 51 retained states,
15 outside-slot atlas regions, original GAME manifest, source registry and
121 incumbent test methods remain exact. Failed pilots and two incomplete
test-supervisor runs remain recorded; the Python launch-identity fault was
reproduced and repaired before the successful suite. Resource guards were
retained. Local only: no package rebuild, commit, push or publication.
Evidence: `artifacts/tactical-all-model-refinement-20261023-r21/acceptance.json`.

Working if: all models have a fresh review disposition, the truck and roofs
render cleanly, menu crew joints are softer, and original source ownership,
pose contacts and every untouched asset stay intact.


## Whole-roster review and crew refinement, Blender revision 45

Reviewed all 57 current roster states, foliage, the menu Abrams and both menu
crew. This is a self-review of work authored by this chat. Fifty-five roster
states are retained byte-exact; Sagger and Spigot have fuller shoulder/collar
transitions, cheeks, lower jaws, palms and articulated fingers. The approved
kneeling poses, launchers and knee contact heights remain exact. Boot recipes
are unchanged; shared-body remeshing changes some tessellation while silhouette
bounds stay within 0.01 source units. Eyes follow the cheek surface by less
than 0.00011 normalized head units in depth, retaining size and orientation.

The floating menu barrel is repaired as one overlapping receiver/barrel/cradle
assembly on a visible roof pedestal. An initial native close-up caught the
pedestal crowding the loader's braced hand; its final position clears both
hands. Wide/compact menu views and three complete-assembly angles verify the
connection. Both crew have fitted helmet assemblies, slimmer sleeves, fuller
palms and staggered finger lengths. The unchanged one-centimetre Blender
replacement limit remains enforced, with maximum displacement 0.0095001m.

Editable Blender masters and the matching runtime assets are installed.
All 13 final crew PBR views were inspected. Five-channel body2048/head512
bakes retain 12 samples, existing normal projection and full-shell AO.
Triangle totals are 8,074 and 7,826, below the 8,192 cap.
UV interior and four-samples-per-head-triangle checks show no black misses.

All 124 asset tests pass, unchanged from the fresh preimage. Three focused
native assertions protect gun continuity and hand clearance; the simulation
check passes 1,268 assertions. Pose admission/native,
world admission, full roster admission with format shard0, native scene and
view shard0 pass 48, 257,
17, 1,226,212,
51 and 671 checks.
The native pose test now ends raw-schema parsing before compiled assets load,
and uses one production renderer load for admission and pixels. Two earlier
runs reached the unchanged 4GiB bound; their uninstrumented logs do not locate
the precise allocation. A bounded read-only second opinion supported the
test-lifetime repair. All schema, mutation, protected-pixel, stale-silhouette, depth-negative and
immutability checks remain exact, including restoration of published poses
after the optional synthetic smoke.
The final phase-instrumented gate passes within the original memory and time
limits. A focused diagnostic reproduced one background boundary pixel at (411,355)
in the Sagger rear view. Actual appearance is black there; the production
shader clips it correctly. The prior test implemented its one-pixel boundary
allowance in only one direction. The corrected check permits at most one
background-only gap per view, touching both silhouette boundaries, and adds
strict masked-coverage equality to the eligible triangle intersection. All
12 fixtures have zero leaked or missing eligible rendered pixels; boundary
disagreement counts are retained separately. These are scoped
checks, without a new claim of visible live-mission footage or every shard.
The native menu also passes reduced motion, actions and range lifecycle.

All 929 fresh preimages, 68 original inputs, the source
registry and all 15 outside-slot atlas regions verify. The launch sequencing
incident is retained: an early shell precheck did not gate two successful
jobs. Remaining Blender supervisors were corrected to fail closed before
launch; memory, disk, thread, output and time bounds remained in force.
No foreign process was controlled. Cleanup pass6 removed zero bytes.
Local only: no package rebuild, commit, push or publication.
Evidence: `artifacts/tactical-all-model-refinement-20261023-r22/acceptance.json`.

Working if: crew proportions and hands read naturally, knee/boot/grip contacts
remain coherent, the menu weapon has a visible continuous mount, and retained
assets and original ownership remain intact.


## Base and truck proportion correction, Blender revision 46

Nell rejected Base155 and Truck159 in the previous roster review. This pass
corrects those two assets; it is a self-review of work authored by this chat.
The base now reads as two storeys, with a normal-height door, two window rows
and a sealed recessed flat roof. Its footprint and original stars are exact.
The truck body is 25 percent narrower; its canvas crown is lowered from 69.6
to 46.5 source units, just above the cab. All six wheel Y/Z profiles and ground
contacts are exact. The fittings follow the complete width adjustment.
M35 photo references and attribution are retained in the phase references.

Both editable Blender masters and matching runtime exports are installed.
Five-channel 2048 px bakes retain 12 samples. Eight final Blender PBR views
and eight native GLB views were inspected. The production renderer also
passes admission (1,223,508 checks), truck view
partition 3 (617) and base view partition
5 (626). Four production close-ups were
inspected; the base close-ups intentionally extend outside the test viewport.
These are scoped gates, without a claim that every mission or partition ran.

Sixteen focused asset checks pass. Initial test-class selection errors were
corrected, and one truck fitting assertion now converts the narrowed width
back to the original scale, preserving its relative-clearance threshold.
The failed intermediate logs are retained. Nine geometry expectations were
updated, two proportion regressions added, and 115 incumbent methods remain
unchanged. The full 126-test suite was not rerun.

All 897 fresh backups authenticate, with 866 protected live files, 68 original
inputs, 55 peer model entries and all 15 outside-slot atlas maps unchanged.
No menu or crew assets changed. All jobs completed within the existing
resource guards. No cleanup, package rebuild, commit, push or publication.
Local only. Evidence: `artifacts/tactical-base-truck-refinement-20261023-r23/acceptance.json`.

Working if: the door and windows read at human scale, the truck cover sits
close to the cab, wheels remain round, and source ownership stays intact.


## Whole-roster polish, Blender revision 47

All 57 roster states were reviewed from front and reverse, together with the
menu tank, both menu crew and foliage. This is self-review of this chat's work.
Bradley131 now has seated commander/gunner roof optics and the early-M2 side
and rear port arrangement. The other 56 roster entries are retained, including
the corrected base, truck and grounded Sagger/Spigot crews.

Both menu crew have lower sleeve roots, untwisted sleeve sections and slimmer
cuffs. An intermediate chest change intersected the collar and was rejected;
the final version preserves the previous chest, heads, grips and pose anchors.
The menu tank and its continuous weapon mount are unchanged. Editable Blender
masters and matching runtime assets are installed. Bradley retains five-channel
2048 px, 12-sample bakes and 7,452 triangles. Menu refinement stays below 1 cm.

Five focused asset tests pass. All 130 incumbent test/helper methods are exact,
with one added Bradley regression; the full 127-test suite was not rerun.
Full roster admission passes 1,224,048 checks, native view partition5 passes
626, and the final menu simulation passes 1,268. Final native menu checks pass
wide/compact views, two pixel-identical frozen intervals, actions and range
lifecycle. The failed intermediate and diagnostic corrections remain recorded.

All 918 fresh backups and 68 original inputs authenticate. The 56 peer model
entries, 15 outside-slot atlas regions and menu armour/gun batches are exact.
Four concurrent audio-owned files were preserved and excluded from unchanged
claims. No cleanup or package rebuild. Local only, with no R24 commit, push or
publication. Evidence: `artifacts/tactical-all-model-refinement-20261023-r24/acceptance.json`.

Working if: crew shoulders flow into the shirt, sleeves follow the bent arms,
Bradley optics read clearly, and retained contacts and source ownership hold.

R24 closeout also registers the existing ground-crew test in the headless and
native gate tiers, with its exact success receipt and source-kit dependency.
All 10 gate-coverage tests pass; the aggregate validation gate was not rerun.


## 2026-10-23: R25 whole-roster and menu polish

Reviewed all 57 roster models and retained their current assets. Joined both
menu crew shirts through real armholes and corrected garment winding; added
the loader gun's recessed muzzle. Blender master and matching runtime export
installed. Heads, hands, contacts, poses, tank hull and main gun are unchanged.

1,276 simulation/presentation checks and native wide/compact menu, reduced-motion,
action and range-lifecycle checks pass. Final native views were self-reviewed.
All 474 roster files and 68 original GAME inputs are exact. No aggregate-gate
or all-mission claim. No cleanup or publication; local only. Full evidence and
retained diagnostic failures: `artifacts/tactical-all-model-refinement-20261023-r25/acceptance.json`.

Concurrent audio and Tactical HUD edits were preserved and classified separately
in the R25 closeout. Native evidence covers the model candidate at capture time;
validation of later audio/HUD work remains with its owning chats.

## 2026-10-23: Plain-language practice menu

Nell found the main-menu terms cryptic. Renamed its four actions to Practice
Range, Controls, Mission Guide and Compare Artwork. Return buttons now say
Main Menu, including the artwork viewer. The guide headings and range HUD use
the same vocabulary. Removed the menu tagline and internal development notes,
including the obsolete statement that original campaign play was unavailable.
Mission objectives, layout, actions and gameplay are unchanged.

Both edited scripts pass headless parsing. Native checks pass at 1920x1080 and
1152x648, including label fit, controls and mission-guide navigation, all eight
mission summaries, range entry and pause-menu return. The artwork viewer's
return label also fits. Self-review: the author of these copy edits inspected
all five resulting captures. No material layout change or web surface was
edited, so the web design detector and aggregate gate were not run.
Evidence: `artifacts/menu-copy-20261023/`. The initial sandboxed native launch
aborted during macOS app registration; a temporary preview-script type error
was then corrected before the passing native run. Local only; no package,
install, commit, push or deployment from this chat. Concurrent work preserved.

Working if: players can identify each destination from its label, with no
clipped text or change to the actions those buttons perform.

## 2026-10-23: Tactical HUD and crew views, concept fidelity

Implemented Nell's request to bring the HUD and every crew view close to the
approved concepts, including the commander, with subtler weathering and no
gameplay changes. Replaced the first, overly flat pass with concept-derived
physical skins: continuous olive housings, deep rubber sight seals, recessed
instrument modules, integrated driver roof/dashboard and an open cupola with
its padded hatch lip. Commander and status use the same equipment language.
All lettering and readings remain live, source-verified rendering. Removed
redundant secondary role labels. Fixed the encountered read-only damage-catalog
alias by making the renderer's copy explicit.

The independent, hash-pinned RGB bank loads before the PC-only early return and
never enables Genesis data or labels. Both compositor and edge pass use the
same selected material and signed driver registration. Missing/corrupt banks
fall back. All five camera/source-region layouts match the original task
checkpoint exactly; only destinations and presentation have changed. Unknown
UI keeps the complete 4:3 view. A final PC-only correction colours only the
84 exactly proven original grey sight-corner pixels; unknown writes reject it.

Verification: 1,305 HUD checks and 36 focused graphics-mode checks pass. Native
Compatibility captures cover nine station/variant fixtures at 1600x900 and
960x540, both with and without the optional bank. Four material comparisons,
including driver offsets -16, 0 and +16, show zero forbidden changed pixels.
Four unknown-UI fallback views pass at both sizes. Six Restored/Modern baseline
pairs remain byte-exact. The final PC-only corner capture passes its pixel
checks. Source allowlist/closure and diff whitespace checks pass. The installed
Impeccable detector reports no findings; it does not certify native GDScript
visuals, so rendered inspection is the primary visual evidence.

Self-review: concepts and implementation were produced in this chat, and the
implementing lead inspected the resulting native images. These are recorded
frame checks, not a full live campaign playthrough. Legacy broad compositor
checks cannot complete because archived PNG fixtures are absent. Private
resource closure also flags the pre-existing cover-export authoring output
reference; the separate packaging owner is addressing its classification.
No aggregate-package pass is claimed. Shared rendering windows were coordinated
with the model-work chat, and unrelated dirty work was preserved.

Evidence: `artifacts/tactical-field-instrument-20261023/acceptance.json`.
Asset hashes, original concept references and final ImageGen prompts:
`local-art/pc-tactical-interior-v1/provenance.json`. Local only; no HUD package,
install, commit, push or deployment from this chat.

Working if: every crew station uses the concept-derived equipment treatment,
readings and controls retain their original meaning, and source ownership,
unknown-UI fallback and mode-restoration checks remain green.

## 2026-10-23: Tank-cover main menu and isolated Extras

Nell approved making the cover the real Play entry point: Scenario, Campaign,
Settings, Extras and Quit. Scenario and Campaign now use bounded ordinary keys
to open verified original menus. Cancelling back to the stable original root
returns to the cover. A failed route stops and offers the original game directly.
The original executable retains all mission and campaign/save decisions.

Extras contains Practice Range, Compare Artwork, Practice Controls and Mission
Guide. Its viewport owns a separate 3D world. Cover, Settings and Extras freeze
guest frames and block original checkpoints and fast-forward. Settings reuses
the existing graphics/audio controller, including cover/range viewport quality.
Embedded scenes no longer replace the tree or own shutdown. Capture tools keep
the direct original-game path; the editor's default scene stays range-focused.

Final native acceptance passes 58 checks, including real pointer/keyboard input,
held-Enter quarantine, both original menu routes, campaign-name cancellation,
return navigation, frozen guest, shared settings and clean host/audio shutdown.
Route unit checks pass 63, play-menu 290, shortcuts 158, and nine generated audio
samples validate. Native startup/early-close/invalid-frame checks pass 12/5/10.
Gate coverage passes 10 tests. Browser-shell checks pass 15 with 7 skipped.
The private Web export verifies all six required files; all eight integrated
scripts match final source after the normal Web class-prefix transform.

Self-review: the integration author inspected final wide/compact cover, Settings,
Extras, artwork and original-menu captures. A read-only advisor found no source
blocker. Browser runtime remains unverified because the browser file-chooser
API did not select the local originals. Populated campaign continuation and
exhaustive transient-root coverage were not exercised by this new check. The
optional design detector failed with npm registry ENOTFOUND. No aggregate gate
or package/release claim. Intermediate test-input and sandbox-export failures
are retained in the evidence directory.

Evidence: `artifacts/frontdoor-20261023/acceptance.json`, final native captures
and logs in `native-final/`, final private export in `web-final/`. Concurrent
model/audio work is preserved; the audio chat's native-menu crash guard remains.
Local only: this chat did not install, commit, push or deploy the menu.

Working if: Play opens the five-action tank cover, original Scenario/Campaign
setup remains authoritative, Extras cannot advance or checkpoint the guest,
and return/quit work without replacing or restarting the original session.


## 2026-10-23: R26 convoy truck and complete-roster review

Nell requested another all-model pass, especially the convoy truck wheels and
cab, then specified a broader nose, boarding platforms and a rear entry flap.
The truck was rebuilt against M35 reference photographs in Blender. Its bonnet
and grille are broader, the cab sits farther aft with rounded corners and
framed glazing, and its front axle sits beneath the longer bonnet. Both doors
have supported treaded steps. The rear canvas has a real opening with a rolled
flap and straps; the tailgate stays closed in the transport pose.

The ten tyres use hollow annular rubber, rear dual-wheel spacing, recessed
vented steel dishes and distinct front/rear hubs. Weathering follows the moved
front axle. The editable master, GLB and five-channel 2048 px, 12-sample bake are
installed locally. Runtime geometry is 8,150 triangles, within the existing
8,192 limit and original source bounds/groups. Four source files and 14 asset
files changed. All other 56 roster entries and all 15 outside-slot atlas regions
remain exact. The 57-model roster, menu tank and both crew were visually reviewed
using hash-bound current-asset views. This is self-review of this chat's work;
the menu assets were retained without another bake.

Six source checks and two baked-asset checks pass. Four Blender finished views,
four native GLB views and three production-renderer truck views were inspected.
Production native view partition 3 passes 617 checks. Positive full-roster
admission, mapping and pair-format rejection pass 1,225,308 checks in 49.20 s.
Two earlier admission attempts reached the unchanged 120 s wall limit and are
retained as failures. The successful diagnostic copy adds only 11 timestamp
print statements; removing those lines reproduces the original test byte for
byte, including every assertion and its order. It keeps the 120 s and 4 GiB
guards. No production renderer or test change was needed. The timeouts' precise
cause is unproven. Other format shards, the full repository gate and all-mission
runtime were not rerun.

Preservation verifies 920 pins, 33 scoped backups, 879 protected live files and
all 68 original inputs. Twenty-one concurrent audio, HUD and main-menu deltas
were owner-classified and preserved, not counted as unchanged. Earlier bakes,
failed logs and rollback assets remain intact. No cleanup, package rebuild,
commit, push or publication. This local candidate is excluded from the separate
frozen soundtrack app/Web delivery.

Evidence: `artifacts/tactical-all-model-refinement-20261023-r26/acceptance.json`.
Reference attribution: the same directory's `references/sources.json`; reference
photos informed geometry and were not used as texture pixels.

Working if: the nose fills the cab width, both boarding steps remain visible,
the rolled rear flap exposes cargo space, wheel dishes read as recessed, and
retained source ownership and asset checks remain green.


## 2026-10-23: Animated main-menu tank (R27)

Nell requested a moving tank, subtle crew/turret movement, undulating smoke
and the existing forward camera following the hull. The cover now advances
at 0.85 m/s with rolling shoes and road wheels, moving earth, small suspension
heave/roll, independently moving heads and breathing torsos. Hand weights stay
fixed at the existing grips and hatch contacts. Turret tracking stays inward
to retain the muzzle in frame. The camera keeps the exact authored offset and
orientation while following hull translation; headlight halos stay attached.

Runtime skinning is applied after all 42 Blender batch matches. Authored vertex
buffers and all Blender masters/assets remain unchanged. Reduced Motion freezes
the complete image, hidden/artwork lifecycle suspends animation, and practice
entry restores the rigs to rest. The original guest and practice simulation
do not advance during the animated cover. Existing frontend routes are intact.

Final checks pass: 1,668 simulation/presentation, 63 frontend route unit, 151
native lifecycle and 299 native preview assertions. Wide/compact menu views and
crew close-ups were self-reviewed. The first combined capture reached its
unchanged 120 s guard after 176 frames; recording and lifecycle checks were
separated and pass within the same bounds. A later suffix typo was rejected
before spawning, then corrected. Both failure records are retained. The design
detector returned no findings, but native renders provide the Godot visual proof.

All 484 protected live files and 68 original inputs remain exact. Six-second
24 fps H.264 preview: `artifacts/menu-motion-20261023-r27/menu-animation.mp4`.
Acceptance: `artifacts/menu-motion-20261023-r27/acceptance.json`. Local only,
with no package rebuild, installation, commit, push, deployment or notarization.
Browser runtime, full repository gate and all-mission runtime were not rerun.

Working if: the tank visibly drives beneath a steady forward-follow camera,
crew contacts stay seated, and every motion freezes when the menu is paused.


## 2026-10-23: Slightly stronger main-menu turret and crew motion

Nell requested slightly more turret and personnel movement. Four production
lines increase turret/gun and crew head/torso amplitudes by 40%, preserving the
existing pace, camera, hull, tracks, smoke, menu lifecycle and rig weights.
All nine scoped controller/artwork hash pins remain exact.

Final checks pass: 1,668 simulation/presentation, 151 native lifecycle and 299
native preview assertions. The first sandboxed simulation had a fixture-write
script error and was rejected; the permitted rerun completed cleanly. The first
native lifecycle had one reduced-motion pixel-equality failure. An unchanged-
assertion diagnostic rerun retained both frames and passed, with exact RGBA
equality independently confirmed. That first discrepancy remains unexplained.

Self-review of this chat's amplitude adjustment to the existing peer-authored
rig inspected crew close-ups and the wide frame. Crew contacts remain seated
and the muzzle stays in frame. The bundled design detector returned no findings;
its GDScript coverage is unestablished, so native renders are the visual proof.

The six-second, 144-frame H.264 preview decodes completely without errors:
`artifacts/menu-motion-20261023-more/menu-animation.mp4`. Acceptance evidence:
`artifacts/menu-motion-20261023-more/acceptance.json`. Local only; no package
rebuild, installation, commit, push, deployment or Apple submission.


## 2026-10-23: More pronounced main-menu turret and crew movement

Nell found the previous adjustment still too subtle. The same four amplitude
lines now give 70% more turret/gun and crew head/torso movement than that preview.
Timing, follow camera, hull/tracks, smoke, rig weights and menu routes are unchanged.
Nine scoped controller/artwork hash pins remain exact.

Checks pass on this candidate: 1,668 simulation, 151 native lifecycle and 299
native preview assertions. Reduced Motion matched exact RGBA on the first run.
Self-review covered crew close-ups, the wide view near maximum inward turret
sweep and the final preview frame: hands stay planted and the barrel stays in
frame. The bundled design detector returned no findings; its GDScript coverage
is unestablished, so the native renders remain the visual proof.

The six-second, 24 fps H.264 preview fully decodes without errors:
`artifacts/menu-motion-20261023-stronger/menu-animation.mp4`. Evidence:
`artifacts/menu-motion-20261023-stronger/acceptance.json`. Local only; no package
rebuild, installation, commit, push, deployment or Apple submission. The full
repository gate was not rerun for this bounded amplitude adjustment.


## 2026-10-23: Molot and convoy-truck reference polish, R28

Nell requested Object 477A wheel, turret-fitting and periscope refinement, then a
softer truck bonnet, large cargo crates, mostly closed ajar rear flap and better
front/rear lamps. The two supplied images guide geometry only.

Molot 123 has fuller seven-station running gear with recessed rims, raised sloped
periscope glass, two seated smoke banks, protected lights and connected turret
fittings. Truck 159 retains its broad nose and boarding steps, adds rolled bonnet
shoulders, three large bound crates behind a narrow flap slit, convex headlamps
and separate red/amber rear lenses. Runtime counts are 7,648 and 8,166 triangles,
inside the 8,192 cap and original source bounds/groups. Editable Blender masters
and five-channel 2,048 px, 12-sample bakes are installed locally. The authenticated
Metal device override retains the bake recipe and retained comparison evidence.

Final checks: 11 source tests, 4 baked tests, 1,230,784 headless admission/mapping
and pair-format checks, plus 617 checks in each native view partition 3 and 4.
Partition 3 covers both changed models; partition 4 covers retained peers. Native
runs retain the 120-second/4 GiB guards. Admission adds only 11 timestamp prints;
stripping them restores the original test exactly. Other format/native shards,
the full repository gate and all-mission runtime were not rerun.

Self-review of this chat's work inspected 11 selected final Blender PBR, culled
GLB and production Tactical images. The first geometry failed ground/louvre
checks and was repaired. A black flap projection triangle and inward Molot rim
faces were caught visually, corrected and rebaked; direct regressions now pass.
All failed/intermediate candidates remain. Final preservation confirms 43 exact
backups, 1,043 live hash pins accounted for, 55 untouched roster states, 15 unchanged
outside-tile atlas regions and 68 original inputs. Concurrent menu source edits
remain owned by the menu chat and are untouched. No cleanup or package rebuild.

Evidence: `artifacts/molot-truck-refinement-20261023-r28/acceptance.json`.
Local only; no commit, push, publication or Apple submission.

Working if: the fuller Molot wheels and raised sight read correctly in Godot,
and the truck has a crowned broad bonnet, narrow loaded-bed glimpse and distinct
lamps while peer artwork and original source custody remain exact.


## 2026-10-23: Clearly visible main-menu scan and crew movement

Nell found the amplitude-only adjustments still too subtle. The previous
six-second native preview recorded only 1.977 degrees of turret travel. The
cover now scans through 12 degrees in an 11.4-second cycle, with distinct crew
head turns, torso rotation and body shifts. Camera, hull/tracks, smoke, planted
hand weights and original-guest lifecycle are unchanged. Nine scoped protected
controller/artwork files remain exact.

This candidate passes 1,668 simulation, 151 native lifecycle and 587 native
preview checks. Reduced Motion retained frames match exact RGBA. The recorded
12-second native preview spans 12.000 degrees of turret motion. Self-review of
this chat's changes inspected crew close-ups and wide start/peak frames: hands
and necks remain connected, with visible muzzle travel inside the composition.
The bundled design detector returned no findings; GDScript coverage remains
unestablished. The 288-frame H.264 clip fully decodes without errors.

Preview: `artifacts/menu-motion-20261023-visible/menu-animation.mp4`. Evidence:
`artifacts/menu-motion-20261023-visible/acceptance.json`. Local only; no package
rebuild, installation, commit, push, deployment or Apple submission. Full
repository gate not rerun for this bounded presentation change.

Working if: a brief visit shows a broad inward turret scan and crew looking
around, while Reduced Motion freezes the image and crew grips stay planted.


## 2026-10-23: Main-menu animation selected by Nell

Nell approved the visible-motion preview: "Much better! Please use this version
for the main menu animation." The current production motion sources still match
that candidate, and the embedded main menu calls those functions directly.
Retain the 12-degree turret scan and stronger crew head/body movement. The
approved preview is `artifacts/menu-motion-20261023-visible/menu-animation.mp4`.
No source change or repeat runtime gate was necessary to select the already
installed local implementation. Packaged builds and deployment are unchanged.

Working if: ordinary local Play uses the approved scan and crew motion, while
subsequent geometry polishing preserves those animation functions.


## 2026-10-23: Whole-roster polish and inset truck lamps, R29

Nell requested another pass across the roster, especially the truck and Molot,
then asked to move the truck headlights inward and narrow the grille. All 57
states were reviewed in 114 fresh opposed native GLB views; 55 were retained.
This chat authored and self-reviewed the refinements, without independent
artistic approval.

Molot 123 receives deeper recessed wheel discs, seated shouldered hub castings
and bolt circles seated on the recessed discs, retaining seven road wheels per
side. Truck 159 receives painted wheel-vent returns and a softly curved rear
entry flap. Both headlamp/indicator assemblies move inward by six raw lateral
units; grille half-width falls from 29 to 23 with 11 closer-spaced bars. Broad
bonnet, apron and cab widths remain unchanged. Runtime counts are 7,928/8,190,
inside the 8,192 cap and original source owners/bounds. Editable Blender masters,
five 2,048 px maps and the 12-sample bake recipe remain in place.

Menu-crew shoulder cloth has smoother joins in four batches. All 42 batch
contracts, 16 noncrew batches, topology, pivots and material selectors remain
exact. The 11,703 checked grip/contact vertices change by at most 0.000007775 m
from the previous sculpt. The approved 12-degree turret scan and stronger crew
movement sources remain byte-identical; reduced-motion RGBA remains exact.

Final evidence: 11 source tests, four baked tests, 1,231,984 headless admission,
mapping and pair-format checks, and 617 production native checks in partition 3.
The current menu artwork retains its 1,668 simulation and 151 native lifecycle
checks. Blender PBR, installed GLB and selected Tactical frames were inspected.
The admission helper adds only 11 timestamp prints; removing them restores the
original test exactly. The menu test-only reporting fallback retains the exact
existing assertions and report block; no production reporting code was changed.

An earlier admission timed out at 120 seconds under observed host pressure;
the final fresh-boundary run passes in 51.43 seconds with the same time/RSS
limits. Installer-overlap checks, an incomplete menu receipt, the initial source
test typo and the user-interrupted headlight bake are excluded from acceptance
and retained. The explicitly resumed, sealed replacement bake passes. No
quality, resource or source-custody guard was relaxed.

Preservation accounts for all 1,043 pins, 49 exact scoped backups, 55 retained
catalogue entries, 15 outside-tile atlas maps and all 68 original inputs.
No cleanup or R29 app/Web package rebuild. Other format/native partitions,
all-mission runtime and the aggregate repository gate were not rerun. Separate
HUD delivery remains outside this pass. Evidence:
`artifacts/roster-polish-20261023-r29/acceptance.json`. Local only; no R29 commit,
push, publication or Apple submission.

Working if: the inset truck lamps frame the narrower grille without shrinking
its broad nose, Molot wheel castings read correctly, and the menu crew retain
natural shoulder transitions, planted grips and the approved motion.


## 2026-10-25: Wheel clearance, retained validation inputs and local release cleanup

Nell requested fixes for the wheel-authoring and fixture-dependent failures,
with commit/push to main and removal of local releases already live on GitHub.
The implementing chat authored and reviewed this bounded source/test change.

Molot's end-wheel radius falls from 3.76 to 3.29 raw units. Its seven road
wheels, their spacing, source ownership and the existing 0.25 clearance assertion
remain unchanged. All 131 modern-asset tests pass. Existing baked model packs,
installed apps and published native/Web releases were not rebuilt.

Thirteen pinned default capture directories had lost images. A further driver
capture, referenced indirectly by the cursor/roof JSON, was also incomplete and
was absent from the fixture registry. Fourteen complete captures were regenerated
with the existing capture tools. Every referenced PNG was checked before the
intentional repin. Seven unaffected default fixtures and the complete live-tier
pin set remain byte-identical. The default preflight now verifies 21 inputs with
zero problems. Historical partial directories and their reports remain under
`artifacts/wheel-fixture-fix-20261025/previous-fixtures/`; capture payloads stay
local and gitignored.

The neutral research snapshot is version 8 and does not restore the DOS calendar.
Fresh neutral replays therefore are not asserted to reproduce the historical
full-RAM/mission recordings. Current trace captures instead match independent
unchanged-baseline runs for every RAM/video/input record, sampled state and
program boundary in all three mission-bearing routes (22,263 frames). A further
1,800-frame intro control matches records, images and transitions. Historical
input/video hashes remain exact for menus, information and both intro captures.
The five mission-entry captures, including the driver capture, retain exact
historical input/RAM/video sequences. No host clock or guest RAM was modified.

The frontend test now defaults to the pinned lifecycle capture, and validate.sh
supplies that path explicitly. Missing reports/images return a clear nonzero
failure rather than dereferencing a null image. Regression checks cover the
frontend invocation and the indirect driver input. Eighteen fixture/gate tests
pass. Restored Godot receipts: presentation reuse 840, commander trim 27, cockpit
mask reuse 2,995, graphics modes 18,629 and portrait coverage 328 checks. Frontend
completeness passes 91 headless and 96 native checks; native cockpit refinement
passes 94. The first native run's missing-driver error and partial receipt are
retained and excluded from acceptance. Original reference inventory is unchanged.
The aggregate repository gate and opt-in live tier were not rerun.

Seven local release archives (2,306,915,689 logical bytes) were deleted only
after matching their SHA-256/size to published GitHub assets, confirming HTTP 200
at the public downloads and checking they were not open. These are the Alpha 7
macOS/Windows/Linux archives, their three source archives, and the model-menu
preview archive. Public releases remain live; unpublished intermediates, working
apps, source inputs and unrelated files were retained. Before/after filesystem
free space and exact paths are in the local release audit.

Evidence: `artifacts/wheel-fixture-fix-20261025/` (replay plan/results, baseline
parity, preserved reports, native receipts and local-release audit).

Working if: the unchanged wheel-clearance assertion passes, fixture preflight
rejects missing input images before the gate, standalone and gated frontend
checks complete, and deleted local packages remain recoverable from identical
live GitHub assets.

## 2026-10-25: Tactical lighting and particle motion

Implemented Nell's four approved presentation changes: periodic rolling smoke
and exhaust interiors, world-sun-relative plume shading, source-donor impact
colour progression, and baked-occlusion/specular plus lower-body grounding
refinement. Density/opacity, source cutouts, geometry, ownership rejection and
original event lifetimes remain unchanged. Motion uses the existing guarded
Tactical dynamics caller and a separate bounded colour phase. Existing pause,
focus/menu, reduced-motion and timeline-reset controls remain authoritative.

Native Compatibility checks passed: dynamics 234, paired particles/source donors
346, material/grounding 55. Predecessor opacity and white visibility masks are
byte-exact. The new black-RGB material diagnostic initially flagged one green
1/255 antialiased texel that rounded to black; replacing that invalid coverage
proxy with actual white-mask outputs passed all six model studies. Headless
checks passed: particle queue 40, dynamics 167, draw pass 53, graphics modes
18,629. The old effect-mode test initially failed because two STATUS fixture
PNGs were missing. The validation-owner chat recovered the exact pinned bytes;
the unchanged test then passed 271 checks. Reference inventory is unchanged.

Three completed actual keyboard routes exercised four stations, driving,
cannon impacts and screening smoke. The two no-readback candidate routes each
match all 1,020 baseline packet hashes, RAM/video audits, station/position paths
and final original framebuffer bytes. Both retained full native focus and exact
one-frame ordinary-key requests. At unchanged 5x world scale, 4x MSAA and 16x
anisotropy, baseline source handoff throughput was 21.473 FPS; candidates were
21.327 and 23.402. Display p95 was 20.109 ms before, then 17.677 and 19.395 ms.
These bounded measurements establish no sustained regression or speed gain.
One 725.802 ms display stall at first smoke in the first candidate did not recur
in the second no-readback run (maximum 113.374 ms). Its cause is unverified.
The separate screenshot-producing route is excluded from performance acceptance.

Evidence: `artifacts/tactical-light-particles-20261025/verification.json`, paired
native images, actual in-game effect captures, complete logs and owned source
hashes. An initial native run expired waiting for focus and is excluded. All
task-owned engines and original hosts closed normally. Source/GPU handback went
to the full-suite owner; that chat owns the aggregate gate and publication.
Repository `Play.command` uses the changed source. Standalone applications and
the hosted browser bundle were not rebuilt or deployed by this task.

Working if: the original source packets and masks remain exact, permitted plume
colour moves without mesh rebuilds, registered impact donors select the colour
phase, and the retained native route measurements remain distinguishable from
aggregate release validation and the isolated first-use stall.

## 2026-10-25 Full-suite repair checkpoint

Recovered five complete live-tier captures and independent full/early-skip intro
controls. Current pinned trace and unchanged baseline cores agree on all 90,991
RAM/video/input records, session states/transitions and dialogue final states.
Historical neutral captures are retained separately; current parity does not
claim historical calendar-dependent RAM identity. The fixture preflight now pins
24 default inputs and five live inputs, including the previously omitted intro
controls and STATUS capture. All 63 STATUS PNGs were recovered from an exact
2,214-frame replay; its original report and selected image/mask hashes match
without changing the historical effect-mode pins. Originals and cores are unchanged.

Intro validation separates fresh capture provenance from exact published-catalog
reproduction, retaining the runtime catalog hash and every other serialized byte.
Office validation covers all three actual poses and 14 exact prefixes; debrief is
a mission-summary map in this capture. Authoring tools call the source guard
explicitly, and refinement boundaries remain enforced under Python optimization.
The scheduling test double now implements the production dynamics setter.

Bulk Git attribute and object-size queries could deadlock through bidirectional
pipes. The existing Git helper now retains complete output in a temporary file.
A bounded regression covers more than 131 KB of cached attributes, Unicode/space
paths, scattered LFS positives and 4,097 object-size responses. All size, LFS,
original-content, archive and credential checks remain. The actual index/history
boundary passes, and clean stdlib-only source CI passes 211 tests (22 intentional
private-input/optional-authoring skips).

Aggregate attempt 03 passed all 104 default checks, including 1,019 Python tests
with one redundant interpreter-check skip. Native dynamics passed 221 checks.
The next native Modern check found fixture-setup reads inside its rendering-I/O
measurement. Its metadata is now preloaded outside that interval; the unchanged
zero-I/O assertion and all 159,125 native checks pass. Full native/live aggregate
closure is still pending, together with the separately assigned graphics follow-up.
No public binary release, website rebuild or remote push is part of this checkpoint.

Evidence: `artifacts/full-suite-20261025/` and
`artifacts/validation-20261025T105313Z/`. Failed attempts and fixture preimages
remain retained. Working if: the final coherent candidate completes the unchanged
default/native/live gate with its completion receipt and terminal exit zero.

## 2026-10-25: Tactical warm-up, projected plume flow and fold lighting

Nell approved all three follow-ups, preserving original timing and visibility.
The isolated pre-tree warm-up now exercises both Tactical surface programs,
ownership, vehicles and particles with admitted fragments and production controls.
It frees its temporary rendering resources without touching live effects, guest
frames or masks. Source-root perspective projection orients plume colour flow;
analytic derivatives of the existing billow hashes light moving folds. Bounded
relief, footprint filtering and zenith fading affect RGB alone.

The baseline reproduced a 721.750 ms display interval at first smoke, sequence
1321, coincident with the daylight-to-smoke-fallback surface switch. The first
new-program native process measured 108.012 ms there; a repeat measured 108.147
ms. Display p95 was 25.303 ms before, 24.696/21.946 ms after. These are bounded
local measurements, with a residual first-smoke delay. Explicit warm-up took
2.889/1.233 seconds before play. No shared driver caches were cleared; Compatibility
pipeline counters returned zero and cannot establish compilation attribution.
A sustained FPS gain or universally cold driver-cache result is not established.

All 1,020 original packets, RAM/video audits, station/position samples and final
original PNG bytes match in all three timing runs. Each request remains one
original frame, fully focused, with exact controls and all four stations. Actual
1280x960 presentation, 5x world scale, 4x MSAA and 16x filtering are unchanged.
PNG-producing visual runs are separate from performance acceptance.

Headless checks pass: effects 42, dynamics 167, draw pass 53 and graphics modes
18,629. Native Compatibility checks pass: dynamics 264, effect art 346 and Modern
159,125, plus pre-tree startup with every program admitted and untouched effect
clocks. Paired production-shader renders retain exact opacity/coverage for smoke,
missile trails and diesel exhaust, and exact source-effect cutouts. Native GPU
finite differences cover warped gradients and pitched/rolled/off-centre projection.
Actual-game captures cover smoke, exhaust and impact phases. Additional ordinary
C/KP8/KP2 routes did not expose a pitched source camera, so live tilted-sight
reachability is unverified; the controlled GPU projection check is separate.
Reference inventory remains unchanged.

Evidence and retained unsuccessful sight probes:
`artifacts/tactical-plume-followup-20261025/`. This is local source work for
`Play.command`; standalone/web releases are unchanged. The full-suite owner
retains the coherent aggregate and remote-push gate. Working if: the first-smoke
transition retains its measured reduction, all required warm-up paths admit real
fragments, and predecessor timing, ownership and opacity checks stay exact.

## Full repository and opt-in live validation repair, 25 October 2026

This chat implemented these repairs and checked the actual integrated diff.
Read-only second opinions informed the provenance and historical-rendering
contracts. The complete original aggregate gate is still pending at this
checkpoint; diagnostic receipts do not replace it.

The earlier repair commit restores independent complete intro and STATUS
fixtures, retains published catalog identity, corrects the Office/debrief
fixture assumption, enforces authoring output boundaries, supplies the missing
live-scheduling test setter, and preloads test-only catalogue metadata outside
the renderer's measured zero-I/O interval. Its bulk Git input fix replaces
pipe-backed stdout with temporary-file capture, preventing both attribute and
blob-size queries from deadlocking without weakening publication checks.

Additional native/live failures were stale tests or missing reference inputs:

* Same-shape occlusion now retains the original two actors and adds a third
  same-shape foreground witness. Both original targets and painter orders must
  encounter decoded foreign owners, retain eligible coverage, and leak zero
  protected pixels. Independent roster and fallback-model probes pass.
* Historical palette tests match current material-tag transport and tree
  filtering while retaining historical colour expressions. This isolates
  palette changes; it does not claim full historical-renderer identity.
* Frozen authored pre-radiance and pre-microfinish helpers replace absent local
  scratch shaders. Provenance identifies the retained source snapshots and
  their hashes. Source-kit allowlisting includes both helpers, and their two
  obsolete optional-missing exemptions are removed. No original-game data is
  added to the source kit.
* Canvas GPU probes use the pinned Compatibility renderer's true
  OUTPUT_IS_SRGB value. The microfinish comparison retains all 33 assertions,
  samples and tolerances. Its three Ground expectations independently account
  for the intentional broad colour tail using frozen predecessor helpers.
  This is a near-sample contract, not proof of every distance or renderer.
* Session and combat checks accept only START's explicitly owned START/ANIM
  preview outside SIM, while continuing to reject retained SIM state or
  unattributed geometry. Combat summary checks recognise the restored FRAME
  surround and retain three exact unlettered-interior RGB probes.
* The original 1,020-request control-replay pacing reference is now an explicit
  sixth live-fixture pin. Existing live pins remain unchanged.

Evidence, failed actuals, fixture preimages and diagnostic provenance remain
under `artifacts/full-suite-20261025/`. Original inputs, cores, snapshots and
user saves remain separate from source delivery. There is no new binary or
website release in this task.

Final aggregate: passed on the frozen candidate, with terminal exit 0 and
`VALIDATION_COMPLETE artifacts/validation-20261025T151153Z`. Main delivery uses
the commit containing this entry; no binary or website release is included.

Further live-tier repairs at the same checkpoint:

* Empty decoded PNG buffers are rejected before entering Godot's image loader.
  The existing invalid-first-frame startup test now passes without an engine
  assertion, while retaining the original failure and visible-cover checks.
* Endurance uses the supported 1x and 8x menu choices for the same fifteen
  original frames, and confirms an existing checkpoint with the real second
  shortcut press. The overwrite guard remains intact. All three checkpoint
  cycles and 3,600 paced original frames pass.
* Native resize retains all six exact Restored 4:3 pixel/fullscreen checks and
  adds source-proven Tactical 16:9 display/chrome/source-extent checks at each
  size. Tactical's final shader output is not falsely equated with the raw
  tandem texture; original state, pixels and guest sample counts stay fixed.
* Profiling requires real native focus, with passive focus-change receipts.
  Setup/focus acquisition is bounded at 90 seconds. The existing profile/capture
  allowance starts once at profile_begin, without extension on focus changes;
  the 1,020-frame route retains its 132-second measured allowance. The inherited
  deadline uses the same clock calculation, and failures close the diagnostic
  instead of leaving an interactive error window. The outer validator watchdog
  is unchanged. These bounds do not assert a sustained FPS improvement.
* The mix test explicitly requires all samples focused. A fully focused run
  retains exact 1,020-request controls, complete paired RAM/video and all nine
  gain changes. Accessibility-only raising was insufficient; the actual native
  window was activated through an inert content region. Failed attempts remain
  in the evidence directory.

Diagnostic 19 closes the remaining native/live checks, including 15,221 soak
checks and 75.198 measured normal-speed seconds for the requested 60-second
minimum. This is still diagnostic evidence, pending the original aggregate run.

The minimized native setup regression probe exits with the expected failure in
92.581 seconds wall time, reports the setup deadline, never starts a profile,
and emits no engine errors. Native window minimization happens after startup
window setup, rather than substituting a focus flag. The invalid initial probe
and its unexpected successful profile are retained separately.

Final acceptance evidence: the original, unmodified `tools/validate.sh` completed
all 104 default, 34 native and 18 live checks. Its exact 156 PASS identities
match the declared automated set. The Python suite passes 1,019 tests with one
redundant interpreter-guard skip: this interpreter already runs those oracle
guards. The final soak passes 16,596 checks, measuring 74.707 normal-speed seconds
against the requested 60-second minimum. All 2,109 tracked file fingerprints
and the staged tree remained unchanged throughout the aggregate.

Four declared interactive/research entries remain NOT RUN: human Audio menu
choices, externally observed native-window interactions, the timing-only
endurance profiler, and asset-dependent vehicle authoring studies. These are
separate from the completed automated default/native/live gate. Acoustic-device
latency, physical listening, a long release soak and a new public runtime
release are not established by this run. Canonical completion and custody proof:
`artifacts/full-suite-20261025/final-aggregate-proof.json`.

## 25 October 2026: installed specialist skills and eight-mission campaign lifecycle

Nell assigned installation/use of the researched skills, performance and complete
mission/campaign coverage, plus direct coordination with Improve Tactical lighting
and FX. Five previously absent skills are installed under ~/.codex/skills from
pinned upstream snapshots: performance-optimization, godot-debugging-profiling,
godot-shaders, reverse-engineer-anything and hyperframes. Installation hashes and
authority are retained in artifacts/finish-abrams-20261025/state.json. Main skill
guidance was loaded directly; no additional framework, emulator or paid service
was installed. Tactical owns the lighting/FX/profile/SFX lane; this chat preserves
its experimental candidate and the six concurrent intro/music edits.

This chat implemented and reviewed an opt-in --campaign-tour extension to the
existing endurance runner, with three small record-classification regressions.
The twelve focused endurance tests pass. Retained REA END assembly was checked
against a freshly unpacked original END: load image, entry/stack and every
relocation match the independent retained executable. Read-only Astra advice
challenged the outcome contract; the root independently inspected its source.

Actual native campaign tour passes 956 checks, zero failures, in 96.51 seconds.
Eight original incomplete exits visit all distinct scenario indexes, seven original
R&R saves survive cooperative process closure and fresh Continue, and the eighth
record has count8, all played markers and original status3. A final cold Continue
rejects the completed career without changing its exact fifty-byte record. The
root independently reread all eight record files and the closed overlay and
inspected the original Paris-loss ending and no-active-player screen. Played
markers and tour termination do not establish objective victories. No guest RAM,
original disk input, objective or career bytes were authored; no RAM checkpoint
was loaded by the campaign tour.

The existing host CPU diagnostic was adapted to an ordinary current cold boot,
removing its stale snapshot dependency rather than weakening core pins. Its
1020-frame/four-station run measures mean6.4966ms and p95 8.7880ms including
cProfile and audit overhead. This is CPU diagnosis, not native FPS acceptance.
No speculative frame-fence or simulation optimization was made.

Clean stdlib source-kit validation also exits0:211 tests,22 intentional/private
skips and593 packaged files. This does not substitute for native/full validation.

Separate ordinary-control combat research has reached original Mossel Defense
progress7/14, integrity100 and exit-mobility conditions85/100/100. Exact source
ID-cell, nonzero source box and LOCKED-cell guards are independently checked.
The rect-qualified controller's6402-frame neutral-START replay and subsequent
reload-corrected11279-frame replay each matched all655360 RAM bytes exactly.
No combat-state restore occurred. Two HEAT shots at2398/2662m exposed another
pilot policy error: the original manual's HEAT maximum is2000m. A range-aware
correction passes17 focused cases. Its15343-frame neutral ordinary-input replay
then matches all655360 RAM bytes and the revised controller resumes play. These
are private playtest helpers, no replacement
simulation or runtime gameplay changes.

The Tactical owner rejected its warm-target candidate after a matched normal-speed
run showed108.371ms first smoke versus107.152ms baseline. Renderer changes were
reverted; no speedup is claimed. A later atomic-receipt diagnostic delays the
visible particle child for the first smoke draw. Its first pre/post draw remains
142.436ms with child hidden; the next, restored draw is7.219ms. The root read
both rows and checked the renderer source remains unchanged. This rules out the
visible child draw as necessary for the stall, without identifying a cause.
The717-sample altered-pixel diagnostic explicitly rejects full1020-route
acceptance. The preceding132s timeout and lost attribution receipt are retained
as an incomplete attempt, never a passing performance result.

Actual ENOSPC temporarily halted all runtime writers. The needed pilot and
unique evidence were preserved; no safely disposable owned data was identified.
After free space recovered to23.39GB, a small atomic handoff checkpoint succeeded
and bounded CPU-only functional work resumed. Heavy native experiments remain
coordinated separately; no free-space recovery is attributed to this chat.

Evidence: artifacts/finish-abrams-20261025/. Successful mission objectives,
surviving victorious saves, independent winning-route parity and whole-game
performance qualification remain open. No standalone/web rebuild or publication
was performed. Working if: each new campaign receipt retains exact original
record custody and outcome labels, and remaining victory/performance gates stay
open until their own native evidence exists.


## 25 October 2026: private effects-bank support and open smoke follow-up

The delivered baseline is `6f5d634766bb99bf497a9a63b5191f543d315b10`.
Its final default/native/live delivery receipts were inspected before source,
index and GPU handback was accepted. Subsequent foreign intro/music and
campaign/outcome work remains separate and preserved.

The free-first sourcing pass retains 463 decoded CC0 audio files across 46 cue
groups, including the cow and rivers, with source URLs, licence/provenance and
SHA custody under `artifacts/world-sfx-20261025/`. No paid recordings were
purchased or downloaded. The refreshed signed-in Chrome account still shows
zero credits. The five-credit US$20 pack is selected for Nell's own purchase;
four Abrams recordings are planned and the fifth credit remains reserved.
An alternate cannon take is also distant and is not an automatic extra buy.

`pc_audio.gd` now supports an optional atomic native-only six-effect private
bank. Fixed filenames, hashes, decoded 48 kHz mono 16-bit PCM and incumbent
frame counts are verified before any replacement is published. Invalid banks
warn separately and retain stock audio. Voices, music, source event routing,
limiter, transport/state rules and source-owned motor pitch/amplitude are
unchanged. No bank is installed yet. Existing audio tests use explicit stock
fixtures, with disposable private-bank cases added to the same test. Final
checks: PC_AUDIO 924 checks, PC_AUDIO_MIX 138, PC_AUDIO_LIMITER 33, all zero
failures/errors. The limiter probe has zero clipped frames and output peak
0.8912613 for input peak 2.9120, with Dummy audio; this is not device latency
or in-game listening evidence. The asset audit reports 476 WAVs, 345 source
captions, zero errors/timing advisories. All 472 tracked original WAV hashes
remain identical to the sourcing seal. Private recordings are absent from
packaging and are rejected by the existing package path boundary.

The first-smoke hitch remains open. A native baseline records 107.152 ms at
source sequence 1321, with 89.368 ms between pre/post draw. Matching warm target
settings, including an owner-zero whitelist path, still gives 108.371 ms and
90.049 ms pre/post draw in the actual normal-speed route. All 1,020 requests
and source hashes match; focus, exact route and all-station completion pass.
That renderer candidate was fully reverted. Isolated first-draw improvements
were cache/context-confounded on baseline recheck and are not a shipped gain.
The earlier current-source warm experiment is also inconclusive because its
camera duplicate could copy presentation children. Shared caches were not
cleared; sustained FPS gains remain unproven.

The profiler now waits for normal transport before the existing real-focus
setup dwell and fails cleanly if transport or original draw context changes.
The 90-second setup guard remains. The observed 8x-contaminated run and its
nil-context error log are retained as failures. A source-sequence-triggered
native stack sample completes, but has only three main-thread observations
and likely trails the stall; it proves no compilation cause. A private
one-frame particle-child delay diagnostic is parsed and queued, never visual
or shipping acceptance. New GPU work was deferred with available disk about
1.4 GB and falling; all task-owned native/sampler jobs have finished and the
resource slot was explicitly returned. Cleanup retired zero bytes because
owned originals, controls, recovery clips and evidence remain needed.

Actual raised/lowered-reticle smoke images are retained. Their source camera
remains level, so they are not physical tilt verification. The original manual
and camera contract were inspected; no genuine non-level camera has yet been
observed. No guest state was changed to manufacture one. Actual licensed SFX
editing, matched-loudness previews, in-game mix/listening, the smoke remedy and
physical tilt check remain pending. No push, standalone/web rebuild or new
aggregate release gate was performed under this follow-up.

Evidence: `artifacts/tactical-postdelivery-20261025/`, the sourcing catalogue,
and `artifacts/tactical-plume-followup-20261025/state.json`.

Working if: optional bank loading preserves the source event/motor/voice
contracts and stock fallback, original assets remain recoverable, and open
in-game/performance/listening criteria stay visibly open until actual proof.

## 25 October 2026, 22:35 UTC: recording preview accepted, individual sound options

This supersedes the earlier same-day open-status notes, without changing the
delivered 6f5d634 baseline or claiming a new release. Four licensed Abrams
recordings are now held privately (241,068,580 bytes, verified provenance and
hashes), using four of Nell's five credits; one remains reserved. Balanced-v3
private edits and matched comparisons retain exact incumbent frame lengths.
Nell confirms a single MG shot, clean motor sections and an acceptable preview.
No recording bank is installed yet; actual in-game mix/listening remains open.

Nell additionally requested sound options because repeated effects may annoy.
The existing Audio/Settings controls now include six saved individual gains:
cannon, machine gun, impact, smoke, engine and turret. Off mutes a cue, defaults
are 100%, and crew/music and original group gains stay separate. Legacy configs
and API callers remain supported. The same gains reach practice and browser
controls; browser publication must pair the controls with the rebuilt pack.
Focused checks pass: audio 924, mix 262, limiter 33, play menu 326, frontdoor 63,
base sample loading and live-script parse. Read-only Astra review found no
blocking contract defect; its simultaneous-shot isolation gap is now checked.
No source events, source motor authority, renderer, stock WAVs or limiter
settings changed. Native UI acceptance remains open; no rebuild or push.

Smoke attribution progressed: with particles still visible, hiding only the
surface gives 7.096 ms pre/post draw; restoring it gives 99.672 ms. All 716
focused diagnostic samples match baseline source hashes AND requests. Pixels
were deliberately altered for attribution and cannot establish visual/shipping
acceptance. The first source smoke selects Modern fallback, following an
already-used Groundlight surface. The first shader-only attempt failed its
unchanged 90-second setup guard because this task focused it too late. It
produced no measured rows and is not a performance result. A corrected, fixed-
clock early-focus attempt awaits a new explicit native window. No production
renderer fix or compilation-cause claim is retained.

A genuine approximately 2.809-degree original camera tilt was captured after
ordinary reversing by the campaign owner. Paired JSON/PNG support that source
case; the adjacent raw dump is later and differs. Raised/lowered reticle checks
remain separately valid. Native acceptance of the genuine tilt remains open.

Evidence: artifacts/tactical-audio-options-20261025/,
artifacts/sfx-recorded-candidate-20261025-balanced-v3/,
artifacts/tactical-postdelivery-20261025/surface-isolation-verification.json
and actual-tilt-source-case.json. Foreign intro/music/campaign work is preserved.

Working if: six independent controls preserve event/motor/mute contracts,
preview acceptance is distinct from actual in-game mix, and smoke/tilt/native
UI outcomes remain open until their direct runtime evidence is obtained.

## 25 October 2026, 23:22 UTC: direct Tactical completion checkpoint

Nell requested an end to cross-chat messaging. No further coordination messages
are sent. The two scheduled jobs are terminal: Settings launched at 23:03:00,
exited 0 at 23:03:50 with 33 checks, zero errors and unchanged user preferences;
the shader diagnostic launched at 23:06:30, reached focused setup at 63.909 s,
then failed the original 132-second measured guard. No smoke row was reached
or retained, so it supplies no first-smoke timing or shader-cause conclusion.
The private diagnostic now preserves failure progress at the close boundary,
with no additional successful-frame I/O or relaxed guard. It parses cleanly.

The accepted six-clip recording bank is now atomically installed privately,
after both fixed windows ended. All actual clips pass production loader format,
frame count and SHA checks. Installed-bank mix: 262 checks, zero errors. Stock
WAVs, voices/music, limiter and source-event authority remain unchanged. Actual
in-game recorded mix/listening remains open. No public assets were replaced.

The genuine approximately 2.809-degree source-camera case was replayed through
the native production Tactical world with Restored HUD. Terminal 0, exact
source packet retained, source/material unchanged, world 1280x485, MSAA4 and
anisotropy16, no renderer warnings. Native sight/world/original screenshots
were inspected. Reticle and visible effect/actor cluster align in this thermal
red-background case. There is no visible skyline from which to judge slope.
This source contains seven exhaust and five other effects, no smoke; the
separate raised/lowered-reticle smoke checks are not relabelled as tilted smoke.
This is a genuine captured-source native visual check, not a fresh live replay.

The remaining smoke remedy is still open. A finite retained-first-smoke packet
probe is prepared and parsed: one fully bound duplicate Groundlight draw, then
exact Modern restoration plus two unchanged Modern draws at the real target.
It has not run for timing. Current iostat records 0% CPU idle and about 35 GiB
swap use, so no new performance claim is admissible; that later observation
does not retrospectively prove the failed live run's cause. No third equivalent
full-route retry, shared-cache clearing or production renderer change occurred.

Evidence: artifacts/tactical-audio-options-20261025/;
artifacts/tactical-postdelivery-20261025/natural-tilt-native-2320/;
actual-tilt-source-case.json and retained-source-parse.log. No push, web or
standalone rebuild, publication or new aggregate release gate.

Working if: native and installed-bank proof remain distinct from live listening,
genuine tilt is distinguished from smoke-only reticle elevation, and the smoke
hitch stays open until a behavior-preserving fix passes comparable timing.

## 25 October 2026: independent baseline-origin entry comparison

Root directly re-read both 3,360-row journals: all full fence-RAM, paired-RAM,
framebuffer and key records agree. Both pinned processes exit zero and reach
fully initialized original Mossel gunner state. The shared state is an authentic
unmodified-core format-8 neutral START snapshot, with unchanged version bytes
and the established one-frame restore priming. Evidence is retained under
`artifacts/finish-abrams-20261025/shared-entry-*-02/`.

The separate historical Bonn input replay is a new outcome attempt from this
origin. It loses the tank at objective progress zero, then reaches original END
and START. Its observer retains 4,812 loops, 4,831 passes and no error. It proves
neither a victory nor winning-route parity. The live Mossel attempt and positive
mission/campaign outcome coverage remain unfinished. No public delivery occurred.

Working if: independent entry parity and the failed outcome remain separately
labelled, and neither is used to close a surviving-victory or campaign gate.

## 25 October 2026: original-core recording mix evidence

The installed six-effect bank has now passed the existing original-core audio
route: 1,712 frames, 128 events, 3,426 source-loop checks, zero errors, correct
cannon/MG/smoke/impact, crew/readiness and F5/pause/muted-shot counts. Actual
post-limiter Godot PCM is retained privately, -6.8 dBTP with no full-scale
samples. A 32.5-second excerpt is presented for human crew-clarity/balance
review. This is Dummy-driver headless original-core/mixer proof, no visual,
device-latency or healthy-host pacing claim. Recorded sample and wall clocks
differ: the initial wall-offset silence assertion failed and was discarded;
two long PCM zero runs and direct source-player gates remain valid evidence.
The smoke fix/comparable timing and human mix judgment remain open.

Working if: actual source-contract proof is retained, human listening is not
invented, and loaded-host recordings are not reported as timing acceptance.

## 25 October 2026: listening accepted

Nell confirms “Crew clear, balance comfortable” for the original-core mix
excerpt. The approved private balance is retained unchanged. This completes
the requested subjective mix check alongside the original-core source/motor/
gate checks; the documented Dummy-driver, capture-clock and host-pacing limits
remain. A fresh finite smoke attribution admission sampled 2% and 4% CPU idle,
so it returned unused before any native launch or bank exclusion. No failed
capacity guard was relaxed. The first-smoke fix/comparable timing remains open.

Working if: accepted audio is left stable, no unqualified performance claim is
made, and the remaining renderer experiment runs only with actual capacity.

## 26 October 2026: first-smoke transition fixed locally

Nell released the CPU-idle admission floor with “Ignore CPU, continue working.”
Disk and owned-child deadlines remained. No cross-chat messages were sent.
The retained-frame investigation isolated first-use Modern fallback work in
its actual source render target. Independent warm-target variants failed and
were reverted. The retained production change draws a duplicate, fully bound
material once in the actual target with buffer swaps disabled, then restores
the original override and both retained targets before normal composition.
Guest state, source material/mesh/camera, geometry, masks and effect clocks stay
unchanged. The successful native warm cost was 523.285 ms during preparation.

Matched actual original-core checkpoint continuations reduced first-smoke
post-to-post time from **147.696 to 29.194 ms**, and pre/post render time from
**122.578 to 8.580 ms**. Both runs exited zero, with 16 focused frames and exact
controls/full packets. All paired RAM/video hashes match the original route.
The checkpoint was created through the production save path after 684 exact
original-prefix packets, without guest or mode edits. Twenty-four original
neutral frames reacquire the observed draw after restore. This finite gunner
check correctly leaves all-four-stations completion false. The earlier full
route stopped at its unchanged 132-second guard after 465 exact focused frames;
it did not reach smoke and is not acceptance evidence.

A separate baseline/candidate capture has zero changed RGBA or alpha pixels in
both the 1280x485 world and whole game composition. A genuine driver-to-gunner
retained-source check warmed at 1600x680 and rendered unmodified smoke at
1280x485 in 13.428 ms. A further original-core smoke visual capture was inspected
separately from timing. Existing draw-pass 53 and Tactical effects 42 checks pass
with zero errors; scripts parse. `--timing-only` now lets the existing profiler
write its measurement receipt and close without producing PNGs.

Evidence: `artifacts/tactical-postdelivery-20261025/smoke-fix-verification.json`.
The private recording bank is restored unchanged; accepted mix and individual
sound controls remain intact. The earlier genuine tilted-source native visual
check retains its static/no-smoke qualification. This completes the approved
follow-up locally. No shared driver caches were cleared, compilation causation
and sustained FPS gains remain unproven, and no public release, web/standalone
rebuild or push was performed. Loaded-host transport throughput varied; the
measured improvement concerns the first-smoke render transition only.

Working if: original source packets, opacity and ownership remain identical,
the finite first-smoke transition is improved without presenting warm pixels,
and local acceptance is kept distinct from any later release gate.

## Independent combat parity and root performance reconciliation (26 October 2026)

The root independently compared all 19,214 Hannover control frames against the
unmodified baseline. Current RAM, paired RAM, original framebuffer and keys
match on every frame; final full RAM also matches at original frame 19,455.
The route includes an actual AX shot and original "SAGGER destroyed." message.
Its objective remains 0/2. This is combat parity, with no winning-exit claim.
The original surviving incomplete Mossel SIM.OUT is `[0,14,12]`, so outcome
zero is also kept separate from objective victory.

The root read the actual finite smoke A/B receipts and render-boundary rows,
compared all sixteen source sample hashes and requests, verified byte-identical
first-smoke packets, and independently compared both world/composition RGBA
image pairs. Both native receipts exit zero. The unchanged first-smoke source
packet renders in 8.580 ms versus 122.578 ms, with the 523.285 ms warm cost
moved into preparation. These loaded-host samples establish a finite transition
improvement. Sustained FPS and full-route/all-station performance remain unproven.
Root reruns pass all 53 draw-pass and 42 Tactical effects checks, both exit zero.

Proofs are private under `artifacts/finish-abrams-20261025/`:
`hannover-independent-combat-prefix-proof.json` and
`root-smoke-performance-reconciliation.json`. Gameplay and winning campaign
coverage continue independently. No outgoing cross-chat coordination, public
rebuild, deployment or push was performed by this root after Nell's stop request.

## 26 October 2026: ordered free-first whole-game sound bank

Nell requested a long detailed list and acquisition, free first. The existing
463-file bank was reused and 76 additional audio files were obtained, including
recorded mechanical/wood/glass/water/bird components, verified stationary and
load-changing truck sources, the 56-file prepared Free Firearm Sound Library,
and an openly redistributed jet-flyby derivative. All new audio fully decodes;
all 539 free file hashes and all 49 original source/archive hashes verify.
Three pre-existing byte-identical aliases are retained for custody and omitted
from playback lists, leaving 536 distinct file hashes in 11 free playlists.
A twelfth playlist references the six accepted private runtime clips.

The detailed inventory contains 89 cue/component roles in 14 categories,
with source pages, licences, representative files, acquisition/runtime states,
and original-event/visibility requirements. It is appended to
`docs/pc-audio-completeness.md`; the full per-file CSV, cue CSV, catalogue,
source snapshots and verification are under `artifacts/world-sfx-20261026/`.
New originals/media, category playlists and attribution are under
`local-audio/world-sfx-20261026/`. Old originals and archive licence notes remain
in the prior bank. A proposed truck URL resolved to a cartoon effect; that
candidate is quarantined and excluded from the active inventory/playlists.
Correctly identified truck recordings replaced it.

The free inventory has 538 CC0 files and one CC-BY3.0 jet derivative. Its pinned
source-tree licence/README and required attribution are retained; the derivative
is not relabelled CC0. Aircraft models remain unverified. Generic chain, lock,
lid and compressor recordings are labelled as components, without claims of
recorded Abrams hatch/breech/suspension or smoke-launcher authenticity. The
firearm library remains a source reserve, without substituting mismatched
weapons or changing shot counts.

The four previously licensed Abrams originals verify and remain private.
No new money or paid credits were spent. All 485 protected audio/runtime-pipeline
files, including the accepted six-clip bank, remain byte-identical. No new
runtime cue binding, subjective audition/mix acceptance, native/GPU run,
publication, web/standalone rebuild, packaging or push is claimed. Unknown
original requests7/9/10/15/16, crew/music and all existing audio gates remain
unchanged. No cross-chat messages were sent.

Working if: the list resolves to verified, rights-documented local material,
acquired stock remains distinct from installed sound, and new source material
cannot silently change the accepted mix or expose hidden actors.

## 26 October 2026, authentic Hind and Soviet tank source acquisition

Nell requested actual Hind and Soviet tank sounds. Obtained three free
attribution-licensed field videos and extracted their audio: Mi-24 Hind at ILA
Berlin 2016 (CC-BY3.0), T-72B mod. 1989 and T-80U exercise footage (CC-BY4.0).
The retained source pages identify the vehicles; sampled live-action frames
were inspected. Audio is 44.1 kHz stereo, 442.214 seconds total. All originals
and extracts fully decode, and the three active extracts match original
decoded PCM hashes. An initial T-80 Ogg remux failed sample equality and is
quarantined; a lossless float WAV replacement passes. No cause is inferred.

Originals total 211,478,137 bytes, active audio 38,318,984 bytes. Provenance,
formats, hashes, extraction commands, contact sheets, CSV and selection notes
are in `artifacts/soviet-sfx-20261026/`; originals, audio, attribution and a
three-source playlist are in `local-audio/soviet-sfx-20261026/`.
Cost $0, paid account untouched, no credits redeemed. No cross-chat messages.

These are source candidates rather than isolated studio samples or accepted
game audio. Listening must still reject speech/music/wind or unrelated sounds
and select appropriate takes. Exact Hind subvariant and clean exact-model
T-62/T-64 sources remain unverified. The primary Pole Position T-72 page lists
a dedicated $119 recording library, outside the existing cap; no purchase.
All 485 protected audio/pipeline files are unchanged. No new event/actor
binding, native run, publication, rebuild, packaging or push.

Working if: each candidate retains its original, licence and attribution,
extracted audio matches the source, and stock acquisition cannot alter the
accepted mix or disclose hidden source actors.


## 26 October 2026, clean-source rejection and economical replacement search

Nell rejected the three field-video acquisitions as unsuitable clean sources.
They are now explicitly excluded in the source state, CSV/JSON inventory and
playlist name. Originals, extracts and decode/hash evidence remain recoverable;
none was ever installed. The active usable count for this supplement is zero.
The audio completeness document corrects the previous audition recommendation.

Verified current primary product pricing: Rabbit Ears Hind $139, Pole Position
T-72 $119. Both document original recording sessions. Nell declined the proposed
$350 total cap as excessive. No new numerical cap, purchase, credit redemption,
subscription, account or agreement acceptance follows from that refusal.

Economical research found an indexed Sound Ideas Mi-24 single exterior pass-by
at $4.75, backed by the manufacturer's Mi-24 catalogue. Pond5's live device
check prevents current price, audition and licence verification in this browser;
no challenge bypass, streaming scrape or download was attempted. SoundFX Studio
lists a $12.99 T-72 pack and $39.99 Hind pack. Their live nonbinding two-item cart
showed $52.98, with no mixed-product discount. It was a comparison only, without
checkout/payment, then both task-added items were removed and the empty cart
verified. Provenance and acoustic cleanliness are still unqualified:
the Hind product explicitly mentions both its own and internet-sourced samples.
Neither cheaper pack is declared an accepted original field-recording bank.

The finite free search checked six annual Sonniss CSVs plus its 2015 PDF, with
no exact requested Hind/T-62/T-64/T-72/T-80 match. The CC-BY-NC T-80 Freesound
sampler remains outside the commercially reusable bank. PSE public exact
Mi-24/T-72 searches had no result; no reserved credit used. Soundsnap's actual
Pole Position T-72 clips are available, but its displayed six-month minimum
$135 subscription is uneconomical here. No subscription started. SoundDogs
searches and their exact scope are retained, without a global no-source claim.

Evidence is in `artifacts/soviet-sfx-clean-20261026/`. A fresh SHA-256 comparison
of all 485 protected audio/pipeline files passed, with zero changes or missing
files. The accepted six-clip bank and levels remain unchanged. No native/GPU
job, cross-chat message, push, packaging or web/standalone rebuild occurred.
Clean replacement acquisition remains open at source-quality, access and bounded
spending gates; this research is not completion of that outcome.

Working if: rejected video audio cannot appear as usable stock, no expensive
library or recurring plan is bought, and every economical candidate keeps its
unresolved model/rights/cleanliness checks beside its price.


## 26 October 2026, preferred Hind engine preview

Nell approved a US$25 additional, tax-inclusive cap. She correctly rejected the
selected Mi-24 pass-by as an active-engine cue, and cancelled the proposed
vendor inquiry. No inquiry sent, no contact email collected. Played the official
SoundFX T-72 idle (10s) and Hind Engine (15s) SoundCloud previews through native
player controls. Correct track titles/Pause states observed. Unrelated autoplay
was stopped; Hind reselected and paused for replay. No audio stream downloaded.
Nell accepted the Hind preview: “That last one sounded good.”

At this preview checkpoint, the $39.99 pack exceeded the then-current cap.
Asked whether to replace US$25 additional with US$50 including tax for the Hind
pack alone. No purchase or agreement acceptance occurred at this checkpoint.
The supplier's own/internet-source declaration remains explicit; no claim every
file is an original field master. Rights allow game synchronization and restrict
raw sharing. All 485 protected audio/pipeline hashes rechecked unchanged. Foreign
files/processes untouched, no cross-chat communication or publication.

Working if: accepted preview character and current spending authority remain
separate, and a wrong pass-by selection never enters the engine-loop bank.


## 26 October 2026, Hind-only cap and checkout handoff

Nell approved US$50 additional including tax for the preferred SoundFX Studio
Hind pack alone, replacing US$25 and excluding other purchases/subscriptions.
Verified one pack, quantity1, $39.99 in regular Chrome checkout. Final tax/payment
await billing. Auto-review rejected attempted billing-name entry/PayPal selection
for missing specific billing-data permission. No workaround or equivalent retry.
Private billing/payment and licence acceptance are handed to Nell in the existing
Chrome checkout; no payment details requested in chat. No agent order submission,
payment, new agreement acceptance, audio download or runtime change.

Working if: only one approved pack is ordered within the tax-inclusive cap,
private billing stays in the merchant/payment UI, and a purchase receipt precedes
licensed download or any acquisition-complete claim.


## 26 October 2026, Hind pack acquired and verified privately

Nell completed the purchase and download, then supplied the archive password.
Order 6997 shows one pack, $39.99 total, Processing, with licensed download
enabled. No second purchase or agent agreement acceptance. The original ZIP has
182,757,232 bytes. Its SHA-256 is
e74dab5eec5b6b8daae0bc21a2c0779ab2b2ebcb3286463e725c0856f373c507.
A private copy is retained, with the user download untouched. Safe path/size/symlink
checks and extraction succeeded. All 158 audio files fully decode: 79 WAVs and
79 OGGs, plus a manual. There are 79 named cues with 78 distinct WAV PCM payloads,
including one supplied cockpit gun-stop alias. All are 44.1 kHz stereo;
67 WAVs are 24-bit and 12 impact WAVs are 16-bit.

The steady Engine_Loop master is 18.190680 seconds and 24-bit. Source level is
about -8.6 LUFS and 0 dBTP. A separate private audition copy, attenuated 12 dB,
measures -20.6 LUFS and -12 dBTP, with
unchanged duration/rate/channels. Existing audio skill dry-run, render/probe and
focused check passed; generic subtitle warning is inapplicable to this wordless
audio-only file. No denoise, EQ or master modification. Actual-master listening
is not claimed beyond Nell's accepted web preview.

Media/original/provenance/playlist are in local-audio/soundfx-hind-20261026;
158-row metadata, file/PCM hashes, public licence snapshots and verification are
in artifacts/soundfx-hind-20261026. Vendor identifies real Hind inputs and also
internet-sourced components; no claim all 79 cues are original field recordings.
Paid files remain private, excluded from Git/packages and never uploaded to a
model. No runtime binding or simulator recipes applied. All 485 protected audio
and pipeline hashes remain unchanged. No source/GPU work, other purchase, push,
web/standalone build or cross-chat message. Clean Soviet tank engines remain
open; the current paid authority is Hind-only.

Working if: originals remain recoverable, every supplied audio file decodes,
paid stock stays private, and acquisition cannot alter original audio events
or reveal a hidden actor.

## 26 October 2026, private world-audio integration checkpoint

Nell asked to get the acquired sounds in place. Added a separate optional native
bank with quiet mono stream and actual purchased Hind engine loops; the accepted
six core recordings, stock WAVs, crew and music assets remain unchanged. Fixed
private filenames/hash/PCM bounds and atomic optional fallback reuse the existing
PC bus/limiter. Saved Rivers/Hind engine controls are independent; Web skips the
private bank and hides these two native-only controls. No paid media enters Git,
source/private kits or public packaging. No purchase, publication or rebuild.

Admission reads the existing production ownership target after an explicit draw,
checks its same-frame mesh/camera/extent and original binary UI mask, and requires
two separated original-pixel witnesses of one owner. Only pinned water-only
objects and a unique moving intact Hind163 from the paired draw-start world can
qualify. Fixed centred mono beds convey no range/direction/count or hidden actor.
All original requests/onsets/voices and source-owned Abrams motor parameters stay
on their existing paths. New mute/reset/focus/frontend/graphics/menu guards clear
pending admission. Bounded read-only Astra contract review found old-reply and
last-fast-reply gaps; both were corrected before acceptance. Sol owns this code.

Focused checks: source audio924, mix289, limiter33, play menu338, frontdoor63;
Python audio9 and package contracts16. Native Settings35 passed; wide, compact
and bottom-scrolled screenshots were visually inspected. A generated-owner
native test covers visibility IDs/UI masks, atomic bank failure, private bus,
source/transport mute, stale replies, resize and shutdown. Its current receipt
is artifacts/world-audio-integration-20261026/native-grid. Production-script
skill lint has zero errors and four pre-existing warnings; the whole-project
linter additionally flags its pre-existing dynamic voice_%s.wav test path.

The neutral native live attempt reached1480 samples with no admitted world cue.
The changed turret-sweep run hit its fixed140-second outer cap, without a terminal
receipt. Neither is a positive playback/performance pass, and no CPU/compilation
cause is asserted. A different finite retained-source check now admits river:
301 authentic original audio envelopes accepted; original source frame29314,
epoch5; source/material unchanged; no guest starts. Final window-focus guard
passes with actual root/menu focus. World1600x585 and composed1440x810 decoded
RGBA pixels are exactly identical before/after admission. Post-limiter capture:
5.851429s,44.1kHz stereo16,-36.24LUFS,-23.21dBTP. Eight generated mask grid reads
cost0.787 to1.698ms; one actual retained target read/probe cost1.955ms. These are
local read/probe observations, not sustained-FPS or device-pacing proof.

Nell explicitly heard the edited Hind master and answered "Clean, loop sounds
good." Fresh live Hind occurrence/mix remains unobserved; master approval is not
relabeled an encounter. The complete89-role disposition records which stock is
ready and which actions remain unbound. Cow is authored Farm157/yard28751 detail,
not a separate original actor; a yard-wide moo could announce an occluded cow,
so it remains dormant. Weather, footsteps, hatches, extra weapon actions and
unknown requests7/9/10/15/16 are likewise never guessed. Clean actual Soviet-tank
recordings remain missing; current paid authority is Hind-only. All private
originals, aliases and rejected drafts remain recoverable.

Current authority/evidence: artifacts/world-audio-integration-20261026/state.json,
cue-dispositions.json, protected-assets.json, pixel-equivalence.json,
retained-final, native-grid and settings-native. Foreign intro/music edits and
untracked godot/godot plus the web build lock remain untouched. No messages to
other chats or control of foreign processes. Old completed smoke/tilt follow-up
and its paused heartbeat remain unchanged.

Working if: native visible-source beds and individual saved mute work, private
stock stays private, originals/voices/motor authority/masks remain intact, and
reserved bindings plus unverified live Hind acceptance remain explicit.

Final qualification addendum: 34 portable world checks and56 native world checks
pass. Exact-input ownership reuse now needs one GPU read for eight unchanged
source packets, with seven delayed/postdraw cache hits. Changed UI reclassifies
without a read; a new occluder forces a new read and silence; queued cached
proofs cannot survive mute or reset. Bounded read-only Astra challenge confirmed
the immutable-mesh dependency and required delayed cached admission. The genuine
retained river records one1.818ms read and one cached reuse, no repeated readback;
its world and composed RGBA images remain exactly identical to the before case.
This is work elimination, not a healthy-host sustained-FPS claim.

Existing owner captures were searched read-only, with no campaign execution.
A paired visible Hind case (guarded-armour-30-1792991410536) now admits Hind in
the native production mask; the earlier non-visible case correctly excludes it.
Positive source PNG BGRX bytes exactly match its recorded VGA SHA. Both JSONs
omit audio envelopes; their later loop diagnostics explicitly are not video
paired. No substitute audio gate or RAM-derived manufactured pass was made.
A wider18-case visual batch timed out after ten source applications without a
terminal receipt; it is not counted as a passing check. The independent positive
and negative single-case receipts are retained. Fresh live Hind mix remains open.
The completed source dependency-closure check excludes the private bank from
both kit kinds; no kit was built. All 472 stock WAVs and accepted private clips
remain unchanged. Current focused test receipts and source hashes are recorded
in verification.json before the local checkpoint.

Capacity custody correction: some intermediate native launch shells used set+e,
so a failed separate disk assertion would not have stopped the subsequent command;
later calls also lacked individual admission receipts. Those are functional
observations, not a uniformly capacity-qualified benchmark series. The final
native checker uses a same-process disk decision followed by exec, and exits
before Godot on a below8GiB result. Its admission/terminal receipt is retained in
final-guarded-native. No CPU/compilation cause or healthy-host FPS claim follows
from any of these observations. This correction changes no source timing or
qualification assertions.

Final guarded launch outcome: admission recorded8,221,691,904 free bytes against
the unchanged8,589,934,592-byte floor and exited1 before Godot. This is a correct
refusal, not a failed audio assertion or a native test pass. The existing56-check
functional cache receipt remains valid within its documented capacity limits;
no equivalent native retry was started. All472 tracked WAVs and both installed
private-bank manifests were rechecked unchanged before the local checkpoint.


## 26 October 2026: Sol6.1 xhigh audio batch

Nell explicitly requested batching with Sol 6.1 xhigh subagents. Five finite
lanes investigated original-visible ambience, qualified source actions, clean
Soviet recording sources, radio/switch candidates and the missing Hind audio
pair. Their files stay under artifacts/audio-batch-20261026; no cross-chat
messages, foreign process control or new spending. Root retains integration.

Nell selected "New switch only". The approved Kenney CC0/authored switch is
installed at the incumbent 120 ms/5,760-frame request 14 asset, with old radio
unchanged and recovery copies retained. Its event loudness matches stock
(-33.85 LUFS), true peak -10.75 dBTP; no blanket gain increase. tools/build_audio.py
checks/copies the approved master exactly, without refading or requiring
NumPy/SciPy/FFmpeg at rebuild. The binary master is only in the existing
asset-bearing kit allowlist, preserving the code-only source guard. CC0 licence
text, source/member hashes, recipe and provenance are tracked. The accepted six
private cues, Hind/river bank and 471 other stock WAVs are unchanged.

Added saved independent Radio alerts and Switches gains via the existing
individual-control path. They preserve source delivery, speech and motor
parameters. Post-import mixer 334, source audio 924, remaining samples 172, Python
remaining audio 7, event tests 6 and package contracts 16 pass. Native Settings 37
checks pass; compact/scrolled images inspected, no manual Audio-menu selection
claim. The sandboxed initial GUI process aborted before logging; desktop retry
passed with fresh 8 GiB admission. Source reimport updated the approved asset;
editor-settings save was denied by the sandbox. That log is not called a clean
editor pass. Generated unreferenced UID sidecars were preserved in recovery and
pre-import absence restored; existing foreign work remains.

Source-pair investigation found 343 unchanged audio envelopes, contiguous IDs
1..2498, matching the prior visible Hind's exact presentation and VGA PNG. The
first proposed replay could collapse historical tails; root rejected that mix
claim. Corrected native replay consumes the prefix silently and captures only
current original engine/turret plus source-visible Hind. It passed with actual
focus, frame 14362/epoch 1, zero transient onsets, one fresh owner read and one
cache reuse. World/composed RGBA images equal the existing same-source images;
source/material unchanged. Capture5.851429s,44.1k stereo16,-33.8LUFS/-25.0dBTP,
no clipping. No whole-mix, source-loop-phase, live-motion or performance claim
is inferred. Separate listening question asks combined continuous balance.

A new exact ordinary-input replay then executed 343 segments/14,121 frames from
the authentic neutral checkpoint, under 90 s setup and 8 GiB admission. It completed
in 50.845 s and matched all 343RAM/video boundaries, producing an authentic native
state/observer/disk-overlay checkpoint at14362. Observed core FPS 59.468765; no
recorded historical cadence was invented. Root verified state/observer/overlay
hashes. This enables a short fresh native case without repeating long
unsuccessful neutral routes or doing new campaign discovery.

Remaining stock bindings stay silent where source action/component visibility
is unproven. No guessed weather, hidden cow or semantic mapping for requests
7/9/10/15/16. Clean Soviet recording search obtained 0 files/$0; qualifications
remain open. Source closure and paid/private exclusions pass without a build.
No push, package rebuild or publication.

Fresh live Hind closure: the newly authentic checkpoint resumed through the
unchanged production host. Ordinary neutral step(1) produced 255 consecutive
focused original samples, source frames 14364..14618, with complete paired VGA/RAM
audits. Actual actor motion supplied 27 different Hind positions during recording
and 227 admitted native draws. Source enabled/active gates, event IDs and production
owner masks were not injected. Native receipt passed, audio drained, original
host exit 0, no renderer/audio/bridge failures. The 5.665669 s stereo capture has
no clipping and true peak -21.8 dBTP. Root verified first/final PNG/VGA pair hashes,
source-event continuity, disk admission and frozen source/bank hashes, and
visually inspected the native live image. This closes the former fresh live
Hind execution/playback gap. The Dummy driver and host pacing are documented;
device hearing and human combined-balance feedback are separate. Evidence:
artifacts/audio-batch-20261026/hind-proof/live-native/verification.json.


## 26 October 2026: accepted Hind/tank-motor balance

Nell replayed the native captured-source continuous mix and said: "That sounds
good. Keep the Hind and tank motors balanced like that please." Recorded this
acceptance with the heard WAV hash, private Hind/engine/turret hashes and
unchanged baseline factors in artifacts/audio-batch-20261026/accepted-motor-balance.json.
No runtime sample, gain, preference, limiter or source motor parameter changed.
Individual saved controls remain usable. This closes combined continuous-balance
listening, while whole historical mix/device hearing are not newly claimed.
The existing fresh live machine proof remains separate and passing. No native
rerun, purchase, publication or foreign-file/process changes were necessary.

## 26 October 2026: visible field air and guarded cow preparation

Nell requested Soviet recordings and cow/environment bindings, free first,
without changing the accepted Hind/tank balance, timing or visibility masks.
She explicitly requested batched subagents. Sol retained integration and native
execution; isolated workers supplied source/component/mastering lanes, with a
bounded read-only Astra contract review. No cross-chat messages were sent.

Installed a separate optional local cow/field bank atomically. Its production
loader passes five exact SHA/PCM/frame/loop checks; installed-bank mixer 360,
original source audio 924, limiter 33 and asset/snapshot 76 pass. The existing
three accepted motor WAV hashes and factors remain exact. Cow uses one CC0 call,
with source-frame exposure/cooldown and no count/range/pan modulation. Field uses
CC0 tree-air-derived material. Nell rejected the original tall-grass preview as
storm-like and accepted the gentler edit at factor 0.08 alongside the unchanged
motors. Stock assets, crew/music and original requests/cadence were not replaced.

Saved Animals/Field air controls bring native Settings to 17. The actual native
Settings-only route passes 39 checks; compact, wide and scrolled screenshots
were inspected. Changes target artifact preferences during the test. No fresh
manual OS Audio-menu or user-preference pre/post byte claim is made.

Real JSON-number container comparisons initially rejected the field predicate.
Fixed exact typed scalar comparisons, with genuine parsed-source and JSON-roundtrip
regressions. A one-pixel original field also fell between incumbent sparse probes;
only the new field cue adds bounded exact ownership-texel sampling. Existing
Hind/river admission stays unchanged. Portable world checks pass 135. Focused native
retained-field replay passes seven, including current postdraw playback, original
UI-cover stop, and world/source/ownership byte equality. The native fixture uses
generated silent PCM and disables unrelated score prewarm. Two earlier 90-second
setup timeouts remain failures, with no proven global CPU/GPU/music cause.

Cow tags copy all production mesh arrays into private proof meshes: 1266 cow
triangles among 7938 catalog triangles. Complete actually submitted farm groups,
independent source fits, pooled-state/current-frame validation and the original
ownership shader discards are retained. The opaque private companion biases cow
away and occluders near, requires separated exact 3x3 WORLD component interiors
and original UI clearance. It never edits production meshes/materials/masks.
The bounded-search/premultiplied-copy final native matrix passes 114 checks;
portable 71 and the asset/snapshot 76 pass. Genuine distant and offscreen cases
stay silent. A five-pixel, 4x2 unbiased cow patch is explicitly insufficient.
No universal floating-point precision or sustained-FPS claim is made. Sampled
static CPU phase costs remain separate from visual PNG capture and frame-rate
claims; a natural positive and comparable performance acceptance remain open.

Recovered an authentic baseline by replaying 489 ordinary segments/12169 frames,
matching every original RAM/video boundary. Read-only source control diagnosis
showed accumulated steering and delayed yaw; ordinary stopping/alignment/approach
then captured a centred farm at source depth 4931, without guest/camera overrides.
The further drive ended when the original left SIM. The next native closer-farm
check returned UNUSED before launch: fresh free space 5,636,829,184 bytes was below
the mandatory 8 GiB floor. No guard was relaxed and no foreign process/cache or
recording/evidence was deleted. No owned native reservation remains.

Nell auditioned the Sound Ideas T-55 front steady-idle single, Stockmusic item
22935298 at US$1.99, and approved up to US$3 total. Sign-in was completed by Nell.
Local browser control is now disabled in Work settings, so checkout/download and
licence entitlement remain open. No paid source is placed in Git or a package,
no other spending/subscription is inferred, and no T-62/T-72 identity is claimed.

Source closure and 33 packaging/remaining-audio Python tests pass without a kit
build. Root inspected the integrated owned diff and kept foreign intro/music/
campaign changes separate. The linter's dynamic voice_%s.wav load placeholder in
an unmodified test is not a new resource defect. No push, standalone/web rebuild,
packaging or publication. Current evidence and exact remaining gates:
artifacts/environment-bindings-20261026/{state,verification}.json.


## 26 October 2026: cow proof startup and exact-input cache checkpoint

Nell explicitly released the free-space hold. No CPU or disk admission hold was
retained, no shared cache was cleared, and no foreign process was signalled.
The accepted engine/turret/Hind PCM hashes and factors remain exact. No push,
package, browser or standalone rebuild/publication was performed.

A genuine ordinary-Z source case at frame13519/focal512 passes 12/12 native
component proofs, including production world/ownership/source byte equality.
Cache-only portable82/native138 checks pass: current frame/epoch still gate
pre/postdraw validity; exact render inputs, clip and source epoch qualify reuse;
mask version/UI/owners/clip qualify classification reuse. Hidden/UI-covered or
mutated inputs retain their fail-closed behavior.

One isolated real tagged-fragment startup warmup was qualified and integrated
before bridge.start. It matches the selected raster quality, retains the Shader
used by the live proof, frees temporary rendering RIDs, and publishes no dummy
mask, source provenance, admission or audio. The promoted PNG-free retained
benchmark passes with 156.592ms warm work, first real proof23.647ms versus the
cache-only144.262ms, subsequent fresh median12.201ms and cached median8.1265ms.
Cached classification is0usec. This is bounded MSAA4 retained-scene evidence,
without a sustained-FPS, compilation-cause, universal driver or cold-cache claim.
The bounded read-only Astra review found no blocking warm/cache contract defect.
Root inspected the actual changes and verified the promoted startup hook in
fresh native runs; those hooks report valid real fragments and empty live caches.

Initial integration enum conversions and a private helper indentation error were
caught, corrected and parsed before guest validation. A live capture with PNG
finalization timed out and remains failed. The changed source-event endpoint
removed that screenshot wait. A later run lost actual focus and stayed silent;
another had412 focused source samples, but the cow was legitimately visible for
only150 before the original UI became fully opaque at13677. The unchanged
180-frame exposure delay correctly prevented a moo. No mask or timer was relaxed.
An earlier genuine frame12899 has356 UI-clear source frames, but native component
readback still rejects it:77 exact interiors all meet the original reticle row60.
Its91-check result was never a positive-acceptance claim. An incorrectly shortened
expectation CLI flag was ignored; the fixture now rejects unknown --expect- flags
with exit2. Ordinary original gunner controls are being investigated next.

Root reran installed mix360 and portable world135, all passing; component portable
82 passes. Source closure and the Git index boundary pass without a build. The
linter still reports its known dynamic voice_%s.wav placeholder in the unmodified
source-audio test; no new parse errors were reported. Foreign sealed files remain
byte-identical. The T55 single is still not downloaded: a targeted task-filename
check found no supplied file, and disabled Work browser access remains external.
Actual source-timed moo/mix acceptance and that licensed download remain open.


Later source-only work found an earlier genuine native resume at12899. Its cow
remained too close to the original reticle row60. Ordinary C/KP8 then moved the
original reticle60to58 in13source frames while camera/farm projection remained
unchanged. Root verified checkpoint hashes and frame12912 packet, then enforced
--expect-visible-cow:92checks0errors, actualowner6 admitted, source/world/owner
bytes unchanged. No camera/mode/RAM write or visibility/timer override was used.

Fresh live capture still has no accepted moo. Native05 exposed a diagnostic
startup focus dependency and closed cleanly at its unchanged90second cap.
Native06 fixed that dependency and performed one real OS activation on its
verified own game PID, returning0. Eight actualfocused samples/four positive
cow draws were followed by actualOSfocus loss; it correctly aborted/stopped
sound after0.093seconds, hostexit0/audio drained. No focus flag was forged and
no repeated foreground stealing was installed. Final capture needs stable real
foreground; this is not a renderer/component or mix-listening pass. A scoped
current Chrome check again reports localbrowseruse disabledinWorksettings.
The approved T55 file remains absent and cannot be obtained through that UI.


Nell then supplied a bounded foreground interval. Current native07 is terminal0:
325/325 live samples focused,320focused recording samples,0unfocused,320actual
positive draws, one cowcall/oneplayingedge. Its first exposure12918 matures at
13098, exactly180sourceframes, with no early/replayed event. Source audit325
rows is monotonic step1. Root asserted terminal host0, audio drained, no bank or
component errors, and unchanged source/mask/timer contracts. The8.266second
private post-limiter stereo PCM has -5.3dBTP and no clipping. This is actual
native original-resume/production-mixer execution with the Dummy driver, without
physical-device/healthy-host pacing claims. All earlier failures remain failures.
The actual new mix was presented for human balance judgment; no listening result
is invented. The redundant helper first-sample focus request was removed before
this run; focus transitions are retained, no admission flag was overridden.
T55 entitlement/download remains the external dependency described above.


## Cow audibility follow-up

Nell reports the cow cannot be heard in native07. Its raw master measures
-27.9LUFS/-11.9dBTP; the old0.12 cue factor plus0.65 master implies roughly
-50LUFS before panning. An FFT template check is too weak to isolate the cow
reliably from that capture, so no measured standalone in-mix level is claimed.
Only the cow factor is raised0.12to0.80 (+16.48dB), effective0.52 at the incumbent
master. Raw PCM and all accepted motor/field/Hind/river/crew/music gains stay
unchanged. World136, mix360 and limiter33 pass; the new assertion protects the
cow-only default while retaining independent Animals mute and source timers.

The first corrected native attempt acquired no stable post-startup focus. A
changed one-time activation after the actual startup marker allowed32source
samples before actualOSfocus loss. Both are failed captures, not mix acceptance;
source masks/focus flags/timers were never bypassed. A further real foreground
interval is requested. A2.444second +8dB isolated reference, -3.9dBTP, was supplied
solely to identify the cow; it is explicitly separate from the game mix. No
publication, extra purchase, source asset overwrite or foreign process changes.


## Background audio QA workflow

Nell explicitly requested background operation after repeated focus losses.
Stopped foreground/focus-attribution attempts. The private background helper
reuses the production original-core bridge and mixer, with no Window focus flag
or OS activation. It exports324fresh original packets from the genuine12912
checkpoint, requiring exact native07audio envelopes and RAM/video audits per
contiguous epoch/frame12914..13237. Frame13238 has no native admission and is
excluded. Source presentation metadata is reconstructed by the unchanged trace
observer; RAM/video hashes alone are not independent metadata authentication.

A separate QA-only transport replays the matching sealed historical postdraw
admission, with rendering callbacks disconnected. The production scheduler
computes its own exposure/onset; no historical clock/player state is injected.
Music context uses original RGB/program/presentation/state and the production
API. All mixer settings equal the prior capture, with only the committed cow
factor changed. Tail playback holds the last authenticated frame for3seconds,
without source increments or additional onsets. Normal frontend focus-mute,
visibility masks, source events and motor authority remain unchanged.

The first headless attempt correctly failed on a JSON float/int owner-membership
check before source playback. Reused the existing exact numeric-leaf validator.
Background02 then passed:324source and admission rows,18originalevents/lastid18,
one cow at13098 from12918, originalhostexit0/drained mixer. Its8.173-second
post-limiter PCM measures -4.5dBTP with0clipped stereo frames. Maximum dispatch
lateness13614usec,0pacingrebases/slip. Root independently checked the packets,
settings, clocks, WAV SHA and metering. Bounded read-only Astra independently
checked all324source and historical admission/exposure/onset rows and found no
blocking false-acceptance or historical-authority leak. Human corrected-level
review is requested; no subjective hearing result is invented.

Use this task-specific headless replay for subsequent level-only checks.
Working if: no foreground activation is requested, changed sealed source bytes
fail before playback, and every accepted cue comes from its exact historical
frame. A passed functional result with pacing rebases does not qualify unchanged
listening cadence; inspect the recorded pacing fields. Renderer changes require
separate visual qualification, and no device/fresh-GPU claim follows from this
fixture. No publication or extra spending occurred.


Nell confirms: "I can hear the cow now. That sounds good, keep it at that level
please." The corrected background02 mix is accepted, bound to its exact WAV SHA
in cow-audibility/cow-level-acceptance.json. Retain cow factor0.80 (effective0.52
at the recorded settings). No further gain, source-timer, mask, other sound or
user-preference changes were made. Cow/field outcomes are complete; the licensed
T55 download remains the separate external dependency. No publication occurred.


## Roster-correct Soviet source preparation

Nell requested Soviet recordings next, preserving the accepted balance and
background operation. Reused bounded read-only source and catalogue workers;
no other chats were contacted. Root decoded the hash-pinned original catalogue:
T-62/115,T-64/117,T-72/119,T-80/121 and corresponding wrecks116/118/120/122.
There is no T-55. The prior approved cheap T-55 lead is held, not substituted or
purchased. The earlier3,837-hit T72 search count was loose token matching, not
model availability; exact/alias checks and50returnedtitles found no match.
Six official SONNISS lists(5,584entries) likewise supplied no exact eligible
recording in that finite metadata pass. No catalogue-wide absence is claimed.

The current free candidate is creator-labelled T-80 GTD turbine material on
Freesound456277, CC BY-NC4.0. Keep attribution and the noncommercial restriction,
separate/private in this pass; do not label it CC0 or claim human/field-recording
verification before acquisition/audition. Original WAV login is required.
Nell twice reports browser enabled; the tool still returns the explicit Work
settings denial after supported js_reset. Read-only Codex settings inspection
is independently refused for safety. No permission, browser-profile, credential
or alternate-driver workaround was attempted. Targeted file checks found only
old rejected T80exercise media, which remains quarantined and unused. A supplied
legitimate original or restored permitted browser access is the remaining
acquisition input. No money, credit redemption, subscription or agreement.

Read-only existing source cases provide moving T80/T72/T62 and stationaryT64
negative candidates. Root checked T80shape121/pointer29062/owner15/speed30,
and frame42389/index1020 with matching compact-sorted presentation SHA. These
are source candidates, not painter visibility acceptance; no ownership receipt
was found. Only visible-moving intact models may be considered, with unique
pointer/shape joins and the incumbent owner/UI/current-frame transport guards.
Stationary idle-engine state, allegiance and health are not decoded; unknown
requests7/9/10/15/16 stay unknown. One fixed centred bed may not reveal actor
counts, ranges, direction or offscreen presence. Working if: no new tank cue
plays until a roster-correct licensed source and corresponding current/historical
qualified painter observation both exist; cow admission is never tank proof.

No runtime, asset, accepted level, original timing or visibility-mask changes.
Cow.80,field.08,Hind.30,ownengine.08,turret.10 and crew/music remain untouched.
Source/licence plan and provenance live under
artifacts/environment-bindings-20261026/soviet-sources/. No release or publication.
