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
