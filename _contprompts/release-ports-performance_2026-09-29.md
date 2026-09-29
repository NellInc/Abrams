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
