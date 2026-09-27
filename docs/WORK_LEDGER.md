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
5. **Visual restoration:** first four static assets complete as v1 local artwork.
   A proven-pixel high-resolution gunner-surround pilot is now opt-in. Remaining
   cockpit materials/instruments, recognition art, Wilson animation, in-world models, effects and all
   UI states remain. Preserve PC information density and four-station controls.
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
4. Continue the now-proven Genesis capture/extraction pipeline for remaining
   artwork, then remaster with unchanged source layers retained for comparison.

No completed subtask closes the parent goal. No exact-gameplay or finished-remake
claim is supported by the current range and artwork milestones.
