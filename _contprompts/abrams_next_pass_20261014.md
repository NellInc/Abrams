# Abrams next complete improvement pass, 14 October 2026

## Scope and authorization

Nell: "Proceed please. Make and execute the next detailed task list for improving Abrams in all aspects."
Delivery is local only. Publish nothing. Preserve Modernized, EGA, original-colour EGA Upscaled, Genesis and Genesis Upscaled. The original executables retain simulation, timing, input and campaign authority. No extra tactical knowledge, resolution cuts, sample reductions or invented source events.

Checkout: `/Users/nellwatson/Documents/GitHub/Abrams`, branch `codex/modern-lowpoly`, HEAD `6d6d749f9f23081ff5c285e7bb6acb59adac1194`. Shared dirty work is preserved. Accepted presentation base: both PCKs `4dffebf0862d0d820fe0f8cba3074ff0ee309b9bdb1896e95a6eb62b6acad76e`. Before fingerprints and scoped source backups: `artifacts/abrams-next-pass-20261014/`.

The REA chat owns `pc_cockpit_edges.gd` and its geometry-cache experiment. Its source/package epoch remains frozen through its already-prepared comparison. This programme prepares private candidates meanwhile and integrates only after actual release. Do not duplicate that experiment or interfere with any foreign process.

## Detailed task list and acceptance

### Startup and importing
1. **Explain prerequisites before import.** Detect unavailable WebAssembly/WebGL2 and secure/isolation support before starting a costly game import. Give a specific recovery, with no repeated reload loop.
2. **Make file selection legible.** Show selected PC file count and optional ROM name, expose visible keyboard focus on the real chooser, preserve native file-picking and local-only handling.
3. **Bound original verification work.** Reject oversized/wrong-sized originals before reading them; keep exact hashes, ZIP identity and original source catalogue authoritative. Validate malformed manifests and ambiguous filenames.
4. **Expose startup stages and progress.** Show verification, engine download, artwork, original boot and first-view progress. Keep startup statuses available to assistive technology and avoid announcing every emulator frame.
5. **Recover failed startup cleanly.** Bound network/startup waits, terminate the task-owned worker, gracefully request the engine to quit, clear stale bridge references, preserve game files and checkpoints. Retry only when runtime cleanup actually permits it.

### Saves, recovery and lifecycle
6. **Make load atomic.** Prepare restored core, observer and presentation snapshot before changing the active session. Persist undo before the swap. A failed prepare must leave the current core/frame/input/observer intact.
7. **Make local storage failures actionable.** Reject blocked IndexedDB opens in bounded time, handle version changes, preserve durable write errors. Never silently advertise volatile saves as persistent.
8. **Show save-slot provenance.** Display original programme and saved timestamp, distinguish empty versus incompatible slots and retain before-last-load recovery.
9. **Respect busy state.** Disable incompatible save/load/speed commands during state operations and report queue refusal instead of silently losing actions.
10. **Close the bridge reliably.** Make closure idempotent, settle pending startup promises, ignore late worker callbacks, release queued frames and task-owned worker on exit/page teardown.

### Controls, accessibility and interface
11. **Keep shortcuts out of form editing.** Match native/browser chord rules, do not steal shortcuts while editing/selecting controls, retain original game key delivery.
12. **Make canvas access explicit.** Provide a keyboard-accessible return-to-game control and accurately describe focus behaviour; no automatic stealing of focus from open help/readers.
13. **Add reliable fullscreen access.** Browser-native, feature-detected fullscreen with accurate enter/leave state and rejection messages; keep controls reachable and renderer quality unchanged.
14. **Fit controls across real sizes.** Group graphics, session and help controls; prevent horizontal overflow at narrow/zoomed desktop sizes, maintain visible focus and readable disabled/working states.
15. **Clarify art choices.** Preserve six modes and independent HUD selection, explain both EGA Upscaled and Genesis Upscaled, keep optional-ROM requirements accurate.

### Artwork, simulation, sound and performance
16. **Harden authored asset loading.** Validate bounded manifest rows/part identities, reject unsafe paths/unsupported ZIP records/truncation/duplicates, verify complete part hashes and completion. Keep full-resolution assets unchanged.
17. **Protect gameplay contracts.** Run existing focused input/session/save-state/observer tests. No private guest writes, new game mechanics or timing changes.
18. **Protect audio.** Run existing event/loop/crew/mix-related contracts, keep source-driven sounds and fast-forward mute. Do not change original sound toggles or introduce unverified events.
19. **Protect 3D and HUD fidelity.** Verify unchanged presentation-source bookends and installed resource payloads, preserve previously accepted all-station/full-quality presentation. New QA exercises the real browser entry point, without treating replay as live gameplay.
20. **Protect performance gains.** Avoid new per-frame host work, polling loops or parallel engines. Preserve accepted HUD optimization; reconcile only REA's actually accepted geometry outcome. No unsupported FPS claims.

### Distribution, tests and player guidance
21. **Protect local distribution.** Install only changed verified web-shell files into the existing owned bundle, retain normal PCK/core/artwork, recompute exact BUNDLE records, retain rollback copies, and prove no originals added.
22. **Make checks reproducible.** Add small existing-style Node contract checks only for demonstrated changed risks, include them in the established validation path, run applicable source-kit and website gates without changing safeguards.
23. **Bring player documentation up to date.** Document actual web import, local-save limits/recovery, shortcuts/fullscreen, six graphics modes and local delivery status. Preserve historical evidence with dates.

## Minimum sufficient proof

Private candidates first. Node syntax and focused contract tests; existing Python input/session/checkpoint/audio/package tests; source-only safeguards; website verification; one bounded browser QA batch of representative startup/error/keyboard/toolbar/fullscreen/save-load states and narrow/desktop layouts. Actual worker/core integration for the changed atomic restore path. Inspect full coherent scoped diff and both installed bundles before completion. No broad Godot gate rerun for untouched shaders, no new visual/performance benchmark framework.

Working if: each numbered outcome has a recorded disposition and confirming receipt; complete local files match their verified candidate; protected modes/core/art payloads remain exact; no publication or foreign process action occurs.

## Status

COMPLETE, installed locally. All23 numbered outcomes have individual dispositions and evidence in `artifacts/abrams-next-pass-20261014/completion.json`. Items17-20 preserved and verified existing gameplay, sound, graphics and performance work; no extra FPS improvement is claimed.

Local PCK: `7a14b802a9ab463474038e7d9ceb08d049d61028eb80cfcc3b4218725e08767f` in both playable builds. BUNDLE: `de7eb915f8a62aa1e7485984da73bf9ac55ffdb5dfcc2d1ad7f7667667eb5e6f`, all45 records verified. All1119 other presentation payloads are byte-identical. All70 original inputs remain exact.

Proof: 15 Node contract tests plus6 Python bundle-recovery tests, 98 focused Python tests (1skip), clean source-kit125 tests (10skips), audio audit476 WAVs/345 captions with0errors, clean Godot4.7.2 viewer parse, 29 real-browser checks including actual mission,3458 normal original1-frame requests, save/load/undo, reload persistence and explicit no-storage gameplay fallback. Website verification passed72 links/assets,8 scenarios,25 image origins. Visual desktop/compact screenshots inspected. Two design-lint findings triaged against actual behavior.

The initial sandboxed parser had platform log/certificate initialization errors; the finite check then passed cleanly through the supported permission mechanism with task-local logging. One newly authored rollback-test typo failed, was diagnosed and repaired; the corrected6-case recovery gate passed. No failing check was suppressed.

Actual QA73462 exited0, single muted browser/context/server closed normally at14:26:51.215Z. Resources and actual installed epoch were handed to the coordinator and REA chat. REA's earlier geometry candidate failed its separate acceptance gate and was excluded. Its newly assigned map-variation/quiet-performance work remains a separate owner's task.

Nothing committed, pushed, deployed or published. No foreign process was signalled. This pass needs no further implementation or validation.
