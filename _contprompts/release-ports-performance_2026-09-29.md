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
