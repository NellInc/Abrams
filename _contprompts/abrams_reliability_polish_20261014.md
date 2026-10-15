# Abrams reliability and player-control polish, 14 October 2026

## Authorization and source state

Nell requested the next long detailed improvement programme, restricted to warranted polish. This pass is local only. Publish nothing. Modernized's renderer, HUD/art and simulation stay exact; both EGA Upscaled and Genesis Upscaled remain available. Leave other chats and their processes alone. Per-chat automation rule permits one isolated QA browser belonging to this chat.

Checkout: `/Users/nellwatson/Documents/GitHub/Abrams`, branch `codex/modern-lowpoly`, HEAD `6d6d749f9f23081ff5c285e7bb6acb59adac1194`. Dirty shared source, preserve unrelated work. Accepted normal packs initially `580ce33299fea3494dc9aa3b03a6fd16b4a72754a65e5bdf423770137edb9d1e`, BUNDLE `3175224bd68e1152e4c85b8024b948b58bc306654a1c7004000cf773615c0b0c`. Map/Edge geometry experiments belong to Assess Rea for Abrams; do not incorporate unaccepted changes.

## Finite programme and warrants

| # | Task and warrant | Confirmation |
|---|---|---|
| 1 | Export to a unique private project/output instead of overwriting the playable prototype while Godot runs. Current builder writes normal outputs directly. | Failed export retains every old output. |
| 2 | Reject parse/script/export diagnostics even when Godot returns zero. An exit code alone does not prove export validity. | Synthetic zero-exit diagnostic is refused; complete clean export is accepted. |
| 3 | Require every expected nonempty runtime file before accepting the export; continue excluding generated HTML/PWA entry points. | Missing file is refused, six-file export namespace remains exact. |
| 4 | Apply the reviewed audio teardown patch before installation, retaining its fail-closed template anchors. | Template drift retains the previous build; existing seven audio regressions pass. |
| 5 | Build authored ZIP parts and manifests privately. Current writer can truncate an accepted part before reading the remaining assets. | Mid-build failure leaves normal parts/manifests exact. |
| 6 | Close ZIP handles on every failure and remove only this invocation's temporary files. | Fault injection permits temporary directory removal; foreign sentinels survive. |
| 7 | Recheck source identities/content before accepting asset packaging. A source edit during the build must not create a mixed release. | Changed-during-read and later source changes are refused. |
| 8 | Validate part sizes including central-directory overhead against the established 48MB bound. Keep full-resolution assets and lossless ZIP_STORED. | Parts/entry bytes/hash match, oversized authored input is refused. |
| 9 | Commit export and authored assets together after both succeed, with handled-failure rollback. Separate successful export plus failed assets currently leaves an inconsistent prototype. | Failure in either stage preserves the entire managed namespace. |
| 10 | Detect a concurrently changed target immediately before installation. Leave core/Pyodide and other unrelated generated files untouched. | Concurrent-edit fixture refused; unrelated sentinel exact. |
| 11 | Remove obsolete managed parts/PWA files only after acceptance. Retain recoverable backup with explicit path if rollback itself fails. | Fewer-part rebuild removes stale part; rollback failure retains old files. |
| 12 | Show an exact checked native audio radio for every valid integral preference, including67%. Browser already supports this; native currently has no checked item. |67→63→70 updates one checked item with no stale custom entries. |
| 13 | Preserve original mute/pause/fast-forward gates and event identity while updating menu representation. | Existing audio tests plus irregular-gain checks. |
| 14 | Add an explicit native Restore full-quality defaults command, using shared4x MSAA/16x anisotropy defaults. Players need a reliable return path. | One complete settings write and one quality notification. |
| 15 | Expose the same opt-in reset in browser extended controls; no automatic fidelity reduction or new preset system. | Real Godot acknowledgement restores4/16 and browser matches. |
| 16 | Preserve graphics-mode intent, selected HUD and audio while resetting quality; surface failed persistence while retaining live defaults. | Settings/reload and failed-write regressions. |
| 17 | Hide the inactive player wrapper, eliminating the empty framed strip after shutdown and before startup. | Initial/recovery captures have no empty player; active viewport remains the incumbent size. |
| 18 | Focus the visible recovery action after engine/worker failure, and the retry action after an early import failure. Current focus can remain in hidden canvas. | Actual browser keyboard focus, no source keys delivered after shutdown. |
| 19 | Keep stopped-runtime causes intact through actual engine exit; preserve checkpoint data and supported original-only input. | Existing real recovery observer plus source preservation proof. |
| 20 | Verify responsive controls/keyboard focus on desktop and narrow windows, triage available design lint against rendered results. | Bounded screenshots, no horizontal overflow; intentional incumbent styling preserved. |
| 21 | Reuse focused tests and fail-closed source-only safeguards; verify the new production builder import/test is allowlisted. | Actual terminal test receipts, no original files in source export. |
| 22 | Install only the verified three-script/menu delta and web shell into both local normal builds, checking all unrelated PCK payloads and45 BUNDLE records. | Exact resource/source/installed hashes, rollback backup, no publication. |
| 23 | Document new recovery/control/build behavior in existing docs and deliver source/package/resource handback. | Per-item receipts and actual owning-process closure. |

## Non-goals and verification economy

No speculative 3D changes, graphics redesign, new simulation, cloud provisioning, acoustic claims, FPS claims, whole-repository rewrites, or publication. Reference-library, checkpoint and launcher improvements from the previous programme already passed; audit their preservation rather than repeat that programme. Use existing focused menu/audio/quality tests, small established unittest failure fixtures for changed build contracts, normal Node tests, one isolated actual WebGL UI/recovery check and source-only required gate. No redundant broad suite. Consult read-only contract advice before locking the generated-output swap.

## Deviations and receipts

All23 bounded outcomes are implemented, verified and installed locally. The coordinated normal-package reservation was explicitly released before installation. Receipts are in `artifacts/abrams-reliability-polish-20261014/`.

Observed initial sandbox-only Godot logging/certificate failures were rerun using the supported permission path: audio125, quality535 and menu271 checks pass with no errors. Actual native UI11 and real browser13 checks pass, normal engine exit0. Builder18 and package9 regressions pass from both workspace and isolated stdlib-only source archive. Source-only125 tests(10skips),520 files. Actual pinned exporter and299 full-resolution authored assets pass private staging, all accepted asset payload identities exact. Design lint flags the incumbent Arial body/shadow; rendered identity is preserved.

Astra contract advice led to a shared exclusive-writer/shared-reader lock and retained recovery journal. Guarantees cover cooperating builders and handled failures, not multi-file atomic visibility or power loss. Production changes span the necessary native/shared-web control and export/asset/package boundaries. No speculative3D work was added; all1117 unrelated presentation payloads and unowned Godot sources remain exact.

Normal580c/317 was retained until the geometry owner explicitly released the reservation. Installed normal PCK is410f723e6c1b309b263a8abcd74340b3404d12113c75affc5025f20790295069, BUNDLE27851e29565a718a8f23a62fd8191d7bd0134381eb08477a576a80cd5c014fd3. Both packs, all45manifest rows and matching web source are independently verified; website72-link/asset gate passes. Unaccepted geometry changes remain excluded. Own browser/context/server closed2026-10-14T17:55:24.404Z; later private exporter/native UI processes exited normally. Nothing published, no foreign process actions.

Working if: all23 bounded outcomes have confirming evidence; failed replacement leaves the prior playable build usable; exact fidelity and both upscale choices survive; no foreign process/profile or publication is touched.
