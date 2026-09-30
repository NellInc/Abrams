# Box-art startup splash

## Approved outcome

Nell requested that the grey “Starting the original PC game...” window be
beautified with a version of the box art. Reuse the approved restored full
cover, retaining By Dynamix, Fan Remaster, the painting and all lettering.
Local source edits, focused tests and native visual validation are in scope.
No original PC or Genesis inputs enter Git or any upload. Apple notarization
remains on hold. Existing release binaries are unchanged.

## Acceptance

- Complete uncropped cover, dark red surround and restrained loading caption.
- Artwork drawn before the synchronous presentation preload in ordinary Play.
- First valid composed game frame replaces the artwork immediately, without
  a timer, minimum hold, intercepted input or changed original game timing.
- Early Close starts no guest, malformed source pixels keep the loading/error
  screen, and a missing cover remains readable.
- Resizing, native first-draw images, source-only package and payload closure
  checks have terminal evidence.

## Implementation and scope

`pc_startup_splash.gd` reuses `branding/abrams-cover-remastered.png` through the
existing original-free player payload. Ordinary Play yields until the first
rendered cover before preloading assets. Capture and headless setup retain
their established synchronous path. `_process` cannot poll or advance the
guest during that yield. No model, audio, source simulation or raster changes.

## Native admission

Trusted human scheduling authorization: COVENANT thread
01a083a7-ddd6-7760-b699-02839469c6b0, user message
01a0effe-9353-7e31-83ef-7a496b8101ef. Scheduling messages only.
After current PORT and ART host-only work, Abrams has a queued bounded slot:
at most four serial Godot calls, 12 minutes, no Blender, Dummy/no audio,
no signals or retries. Await explicit actual handback before any launch.
Final roster: splash native render/contracts; ordinary actual PC boot and
first-frame handoff; early Close before preload/guest; malformed-frame
fixture with retained actionable error. No extra animation census.

## Evidence and completion

Evidence: artifacts/startup-splash-20260930. Source-kit contract passed 92
checks/tests (three private-input skips), and focused package/UI/runtime checks
passed 75 tests. Private and source payload closure passed. Approved cover bytes
are unchanged. The four native calls ended naturally in 20.08 seconds. Root
read the logs, reports and first-draw/game/error images. Splash (114), real cold
boot (8), invalid-frame (8) passed. Early-close (2) is REJECTED despite exit 0:
a deferred `_complete_startup` call survived script teardown. The first runner
missed this engine error; raw receipts remain, corrected root verdict is failed.
The slot was returned with fresh inactive inventory. A source repair now guards
Close immediately after the first-draw await, before enqueueing more work.
Eight UI source contracts pass after that repair. A separately admitted one-call
repair gate completed naturally in 2.02 seconds: two early-close checks pass,
zero engine errors, no preload or guest, exact fresh inactive resource return.
Root independently read and hashed the actual terminal log/report/source pins;
receipt: root-repair-readback-and-handback.json. Both native admissions are
closed. Final repaired-source isolated source kit passes 92 tests, three skips.
No further native launch is authorized. Optional Impeccable is not installed;
native rendering and functional tests provide visual/layout evidence instead.
The separate tank-firing question still awaits Nell's scene clarification.

The requested splash is implemented and locally validated. Native images at
1280x960, 640x480, 1920x1080 and portrait sizing retain the complete cover;
actual production before-preload pixels match the 1280x960 fixture PNG exactly.
Normal first-frame handoff and malformed-frame handling pass. The repaired
Close guard is the only code difference since those original native cases;
its separate gate validates current-source teardown. Sound stayed off. No
release binary, original raster asset or original game data was changed.
