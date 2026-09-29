---
status: implementing
stepsCompleted: []
verification_criteria:
  - "Performance changes preserve source execution, input cadence and rendered pixels on retained replay."
  - "Windows and Linux produce self-contained native packages without original game files."
  - "Setup requires verified PC files, accepts Genesis optionally, preserves profiles and reports errors."
  - "Sol 6.1 Medium mission attempt records original inputs and an honest outcome."
  - "Next private GitHub alpha includes the selector and Nell Watson About credit, current installation docs, checksums and corresponding core source."
---

# Release, ports and performance

## Authorization

Nell's 29 September 2026 request: "Fix everything please. The original geometry is fine if it looks nice and crisp. For 4, try to play the game with a Sol 6.1 medium subagent. Also, ports for Linux and Windows please."

This approves the previously proposed performance pass, documentation and next private alpha refresh, mission attempt and Windows/Linux ports. The original selector tank geometry is accepted. Keep the repository private and keep original PC/Genesis inputs outside Git, CI and distributed packages. Existing sound-off request remains active for all runtime work. No process termination permission is inferred.

Working if: the release contains the approved local changes, platform builds are evidenced, source simulation remains authoritative, and no original games or audible tests are distributed/run.

## Pre-check and scope

Baseline: clean local 2953414, GitHub main 2e126c8 and private alpha.2. Two accepted local commits contain the selector upgrade and About credit. Current Modern moving-route benchmark is around 40 fps; a consistent source-rate target is still unmet. Target the original advertised 59.47 frames/s without frame skipping, reduced assets/resolution, altered emulated CPU settings or hidden catch-up. Record any remaining failure honestly.

Portable packages reuse bundled Godot and the verified frozen Python/Pillow bridge. Preserve native AppKit on macOS. Native Windows/Linux runners can build and test synthetic/no-original setup contracts; actual gameplay requires an owner-supplied PC copy on the target platform. Do not upload that copy to CI.

A Developer ID Application certificate is available locally. No notary-tool Keychain profile was found by service-name inspection. Nell explicitly approved Developer ID signing: “Sign now, leave notarization pending.” Her subsequent request to look into notarization authorizes research and preparation only. Do not submit an app to Apple until a fresh go and a Keychain credential profile are available. Signing and notarization are distinct outcomes.

## Work lanes

1. Root: Modern CPU/render profiling and bounded optimizations, source and pixel oracles, integrated validation, docs, packaging and private release.
2. Sol 6.1 Medium mission agent: owns artifacts/mission-playtest-20260929 only. Original keys and visible outputs, no guest-state edits or forced outcomes, sound disabled.
3. Windows/Linux worker: owns standalone/portable runtime, launcher, platform adapters, focused tests and proposed native workflow. No remote mutations; root owns review and dispatch.

## Required proof

* Focused tests first; integrated source/Python and Godot gates after all edits.
* Native before/after replay, exact inputs and rendering comparison for performance; record mean/tail rates and whether source-rate acceptance passes.
* Native OS package builds, integrity/boundary checks, setup UI and frozen-runtime smoke receipts; label missing real-game platform validation separately.
* Mission inputs, screenshots/debrief, campaign effects and reproducible outcome; independent listening remains unavailable while muted.
* Signed macOS bundle verification, native prepared launch, artifact hashes and corresponding core source. Notarization only with suitable authorization/credentials.
* Pre-push 50 MB/history/originals/credential boundary, unchanged repository visibility, latest CI terminal results, release asset download/hash verification.

## Deviations and remaining gates

Record evidence and reversible deviations here as work proceeds. Do not substitute partial/focused checks for aggregate completion, claim mission victory without its original outcome, or mark unsupported OS gameplay as verified.

## 29 September execution evidence

* Aggregate terminal gate passed: artifacts/validation-20260929T210927Z, 536 Python tests and 68 Godot checks. After frozen-entry repair, all 538 Python tests passed. Corresponding-source target regression adds one later test; clean Python 3.10 source kit now passes 87 tests (two optional-input skips).
* Modern mapping oracle: 68,150 checks, 482,759 facets. Native 32-screen production-viewer replay: 39,321,600 pixels identical to the preceding candidate. New focused FPS runs could not acquire actual focus and ended at their deadline, including the unique-renderer attempt. They provide no accepted FPS measurement. The historical 40.12 fps result remains the last accepted moving-route baseline; 60 fps is still unproven.
* Sol agent reached two natural Mossel Defense defeats. Root inspected both enlarged original debriefs: scores 180 and 96, respectively five and three enemy kills. Neither proves victory or campaign continuation. Original-EGA play only; no listening.
* Root repaired macOS frozen bundle discovery after a real signed-play failure. Corrected signed runtime subsequently cold-booted 3,663 original frames into a gunner capture, in a sanitized environment with no external Python/Godot. Signatures: Developer ID team BBYYCBH7EW, secure timestamps, hardened runtime, 81 nested targets. No JIT/library-validation exceptions were needed. A final build including the source-archiver repair is being sealed and retained separately.
* GitHub main/codex branch 761991d, source-only CI green. Native build run 36632731281 failed before compilation: Windows Python 3.12.11 unavailable; Linux integration token HTTP 403 retrieving a private draft asset. Windows pin corrected to official available 3.12.10. The token is restricted to the download step. A question requests permission for contents-write on that job; no permission increase or equivalent retry occurs before Nell answers. Windows/Linux native packages remain unbuilt, not delivered.
* Alpha.3 is a private draft, not a published completed release. Existing alpha.2 is preserved. Draft CI input asset 599250516 is original-free, SHA-256 2eddf068497501c6130ad682e5fbb8e13e31d85453e27bb88e015fa1c3d4cbf2. The workflow consumes that immutable asset. Prior input candidates are retained separately and must not be used for native dispatch.
* Notarization researched against official Apple docs; instructions saved in docs/macos-notarization.md. No notarytool Keychain profile is available. Nell must create/store an app-specific password directly in her Terminal, or supply an existing profile name, then explicitly approve submission. No Apple notarization upload was made.

Nell's explicit question reply approves the scoped contents-write permission for the native build job. Token remains exposed only during original-free draft-input retrieval; no Git edit, release publication or Git Data API operation is authorized by that token. This releases the build permission hold only. Apple notarization stays pending.

## Native build repair after run 36633592772

The approved draft-input permission succeeded on both runners. Both native cores compiled and the 240-frame original-free observer smoke passed. The contracts then failed because three bridge state-reader tests required GAME/SIM.EXE; Windows also failed the POSIX directory-fsync step in checkpoint replacement. Root preserved those three tests for equipped local runs and explicitly skips them without original inputs, while all other bridge/save tests still run. Checkpoints flush their temporary file on every platform and sync the parent directory on POSIX only; Windows does not claim directory-fsync or power-loss durability. Replace errors still preserve previous checkpoints and remove the temporary file. Native notices now use the caller's pinned source checkout.

Root verification: 65 focused equipped tests pass (one optional native smoke skipped); isolated source-only bridge/save/portable run passes 35 tests (three original-dependent tests and native smoke explicitly skipped). New immutable native input is port-input-private-alpha3-native-repair.zip, SHA-256 0b8590518270572ac94b584f84a8562b1bbbfb03582fd2d12e76d979c851cd53. Rebuild and sign the macOS alpha after this shared checkpoint change; do not ship the earlier final/ archive as the new candidate.

## Packaging-mode and profile-path repair

Run 36638314145: Linux passed native contracts, compilation and app assembly, then its frozen-runtime smoke failed with permission denied. Root reproduced the cause: the copy fallback discarded executable mode. It now uses copy2, with a POSIX executable-mode regression check. Windows passed native boot and checkpoint tests; its profile-path test failed because a Path.home fallback was evaluated eagerly despite LOCALAPPDATA/XDG_DATA_HOME being provided. Profile selection now evaluates only the selected branch and bypasses defaults entirely for an explicit profile. Regression checks deliberately make Path.home fail.

Aggregate validation after the checkpoint change completed at artifacts/validation-20260929T221216Z: 541 Python tests and 68 Godot checks, terminal exit 0. Current signed native-repair/ macOS app passed 3,663-frame original boot and all 26 packaged frozen-runtime checkpoint checks. Another candidate must include the latest profile/copy fix. The 08f3d18 source-only workflows passed on main and codex/modern-lowpoly.

Nell reports that notarytool credentials were validated and saved in Keychain as Abrams. A new question asks explicit permission to upload the original-free app to Apple and staple an accepted ticket. Until she answers yes, submission remains on hold. A malformed dispatch (36638241691) was caused by root using the draft tag's unavailable REST lookup and continuing after its 404; it rejects before input retrieval. Future dispatch commands fail fast and resolve draft assets through the release list.

## Windows text encoding

Native run 36639603006 produced a fully smoke-checked Linux package. Windows passed all original-free bridge/checkpoint/native-core checks, then source-closure reading failed with cp1252 UnicodeDecodeError. Root makes the CI interpreter use PYTHONUTF8=1 and pins X utf8 in the PyInstaller native bootloader/config cache, following the installed tool's supported interpreter-option interface. Windows setup explicitly rejects a non-UTF-8 frozen runtime, so its native setup smoke cannot hide a missing option. No system-wide locale or user environment is changed. Two targeted regressions added; 51 focused tests pass (native opt-in smoke skipped locally).

Notarization Keychain profile Abrams is ready. Submission approval question remains unanswered; no Apple upload has been made.

## Formal application name and startup

Nell requests removing the Godot splash and a more formal app name. Root selects M1 Abrams Battle Tank Remastered, consistently in native metadata, launcher/window/About titles and player launcher filenames. Preserve bundle identifiers and the existing Abrams profile paths; preserve Godot user:// through its original directory. Use a black engine startup, no logo and no artificial minimum display delay. Rebuild all three platform candidates before shipping.

Nell answered the Apple submission question: “When finished, soon, some tasks remaining,”. Submission remains on hold while these tasks are unfinished. Credentials in Keychain profile Abrams are ready; no Apple upload has occurred.

Native run 36640764180 assembled Windows successfully, then corresponding-source integrity rejected a CRLF-converted upstream workflow file. The clone's temporary -c core.autocrlf=false did not persist for the later pinned checkout. Set repository-local clone config core.autocrlf=false and core.eol=lf. Keep the source byte oracle strict. Linux passed.

## Opening menu refinement, 30 September

Nell reports the intro menu still looks low resolution. Root confirms the START scenery predicate previously accepted only the scenario selector. Extend the existing read-only observer to the full main menu through its four pixel-verified labels, exact source rectangles, palette and every visible scenery pixel. Keep cursor, original input, geometry and animation source-owned. The complete guarded FRAME footer is now rebuilt at native resolution rather than retaining enlarged dithering. All release candidates are held until this refinement is validated and rebuilt.

Formal naming and splash changes are committed/pushed at 0f5cd00. Source CI passes; Windows and Linux native build/setup/launcher/source gates pass in run 36643490889. Mac Developer ID Build 24 is signed, with setup/About visually verified. Its later packaged capture exited 1 without a fresh capture receipt, so no packaged gameplay pass is claimed for it. Prior formal-name full Python suite: 548 pass, one optional native skip, terminal exit 0.

Opening-menu focused Python checks: 14 pass. A replay against the older baseline records has identical frames, inputs and video, but 1,171 full-RAM hashes differ; retain the failed aggregate parity receipt. Diagnose with current core/state before treating guest-memory parity as proven. The first native fixture test found a stale scenario-only panel expectation and a deliberately reduced fixture lacked the existing 16-scene coverage; adjust the panel boundary by the verified view and run the complete menu fixture. No failed gate is removed.

Fresh current-core baseline versus observed replay passes all 5,190 frames, original memory/video/inputs and program identity, terminal exit 0 (artifacts/intro-menu-20260930/baseline-current/report.json). Full native frontend fixture passes 448 checks across 23 scene views and eight missions; native FRAME rendering passes 28 checks at both resolutions. The combined frontend/text/frame/launcher Python contracts pass 23 tests. Root visually inspected the new main menu and return frames. Previous stale-baseline failures are retained separately. Rebuild as macOS Build 25; notarization remains on hold.
