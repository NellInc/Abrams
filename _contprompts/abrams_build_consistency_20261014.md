# Abrams build/install consistency pass, 14 October 2026

## Authorization and current state

Nell requested another detailed improvement list and execution only where polish is warranted. Local source changes only, no publication, no new rendering/UI/artwork changes. Preserve Modernized, EGA Upscaled and Genesis Upscaled. Current branch codex/modern-lowpoly, HEAD6d6d749f, shared dirty tree. Normal PCK410f723e and BUNDLEb1156c29 are independently refreshed. Map/Edge geometry and measured performance belong to Assess Rea for Abrams. This lane will respect an actually reserved quiet tranche and touch no foreign job or old September app expansion.

## Findings

The already improved player-facing paths do not warrant another cosmetic rewrite. Two actual integrity failures remain: a corrupted native copy is renamed into its accepted version directory before its checksum is checked, leaving that version unusable on retry; and an edit to Godot source during Web staging is accepted without a consistency check. Both are reproduced in `artifacts/abrams-build-consistency-20261014/reproduction.log`. The first fixture call omitted a copy-helper keyword argument; that fixture was corrected before either reproduction was claimed as confirmed.

## Long, detailed finite task list

| # | Warrant and implementation | Acceptance |
|---|---|---|
| 1 | Validate native staged presentation payloads against the current reviewed manifest before committing the version directory. Validation currently occurs after rename. | Corrupt successful copy is refused, final version remains absent. |
| 2 | Validate the staged original PC files and reconstructed archive before promotion too, preserving pinned content identity. | Altered staged GAME/archive is refused without changing source or campaign. |
| 3 | Reuse the incumbent payload/content checks for staging and existing installations, without adding another manifest format. | Existing tampered-version refusal and two-version/profile tests pass. |
| 4 | Preserve cleanup of only this invocation's unfinished .install directory; allow clean retry with the same build ID. | No leaked staging or poisoned version after failure; retry succeeds. |
| 5 | Capture a finite Web presentation-source inventory: project.godot, export_presets.cfg and the existing four included directories. Continue excluding diagnostics/cache/bytecode. | Snapshot includes every copied input and no original game, tests/artifacts or generated cache. |
| 6 | Reject linked presentation inputs instead of silently dereferencing them into export. | Linked leaf/directory cases fail before copy/export. |
| 7 | Compare copied presentation bytes with the captured input identities before applying the reviewed Web-specific transformations. | Copy corruption or mixed copied generation refused; original code/art bytes unchanged. |
| 8 | Re-enumerate source before export, detecting edited, added or removed files and changed control files. | Source edit/add/remove/config drift cases refuse before Godot invocation. |
| 9 | Recheck the source after Godot export completes, so a later edit cannot be mistaken for the candidate's source state. | Late source mutation fails while prior playable outputs remain exact. |
| 10 | Carry a task-owned source receipt through authored-asset staging and recheck immediately before combined normal promotion. Preserve the existing export return API. | Root source change between successful export and asset completion prevents installation. |
| 11 | Retain all existing diagnostic, six-file, audio-anchor, asset-manifest, lock and rollback gates. | Existing export/asset fault tests remain passing; no weakened safeguard. |
| 12 | Add small regressions only for the reproduced or changed integrity contracts, using the existing unittest fixtures. | Focused terminal receipts, originals/profile/sentinel preservation. |
| 13 | Run the required source-only check and, if no quiet reservation conflicts, one private pinned-export smoke. No redundant browser/3D timing check. | Source-kit acceptance; actual exporter receipt labelled separately. |
| 14 | Independently confirm every normal browser BUNDLE record, both PCKs, loader and source presentation files unchanged. | Current accepted browser still usable; no experimental geometry included. |
| 15 | Update existing recovery/build guidance and WORK_LEDGER; provide per-item evidence and actual resource handback. | Exact source/normal epoch handback, no own lingering job and no publication. |

## Boundaries

A stable captured snapshot is not a claim of filesystem atomicity against malicious/uncooperative editors or power loss. No new global locks/framework, original ABI/state changes, packaged desktop binary rebuild, speculative 3D polish, new dependencies, cloud spending or foreign cleanup. Source changes are immediately local; native packaged binaries receive them only through the established future package build. Read-only Astra advice challenges the multi-stage contract; root retains implementation and proof.

Working if: inconsistent candidates never become accepted installations/builds, clean retries succeed, protected presentation and player data stay exact, and all15 outcomes have confirming receipts.

## Completion

All 15 items complete. Local source changes are in the two existing helpers, their existing regression files and recovery/build guidance. The native helper verifies a candidate before rename and binds original-file expectations to captured manifest bytes. The Web builder verifies the raw copied namespace and carries one original source receipt through all sampled checkpoints. Native candidate corruption, same-ID retry, protected fixture state, late expectation edits, Web edits/additions/removals/config drift, linked inputs, ignored cache activity and post-asset refusal have direct regressions.

Checks: native 40; builder 24; packaging 9; clean source-kit 138 tests (10 skips), 520 source files. Actual pinned private export completed successfully with six nonempty runtime files, clean diagnostics and 1,125 stable selected inputs. Its temporary project/output was removed normally; terminal session 66541 exited 0. An independent census found no task-owned smoke process. All 45 normal BUNDLE records and 1,126 presentation files including an ignored metadata file remain exact. Normal PCK 410f723e, loader efb91721 and BUNDLE b1156c29 are unchanged.

The private smoke is exporter proof, not gameplay, FPS or device proof. No normal playable output or existing packaged desktop binary was replaced. Those binaries receive the native change through their future established package build. No new cosmetic rewrite was warranted by the current audit. No publication, foreign process action, cloud work, geometry candidate installation or lingering resource hold.

Canonical receipts and item dispositions: `artifacts/abrams-build-consistency-20261014/completion.json`, `source-ci.log`, `native-tests.log`, `builder-tests.log`, `package-tests.log`, `private-export.json`, `private-export.log`, `protected-verification.json` and `process-handback.json`.

## Subsequent experimental owner handback

After this programme completed, Assess Rea for Abrams installed its separately owned experimental geometry/resolved-map candidate and released the five-target reservation. This lane independently checked the later PCK 75fe6ca8 (both trees), BUNDLE f7e986fb (all 45 records), Edge source 94317bfe and Map shader ae5090fc. Only those two presentation source files differ from this programme's 1,126-file bookend; the other 1,124 files and audio loader remain exact. The historical completion receipts above still describe the earlier b115/410f epoch.

The owner's installed-byte cold/fidelity results were read but not rerun by this lane. Performance benefit remains unverified; the owner reports Nell authorised experimental installation with timing acceptance waived. No publication, pending reservation or new runtime work in this lane. The three older diagnostic packs remain untouched. Current-epoch read-only proof: `artifacts/abrams-build-consistency-20261014/later-experimental-handoff.json`; owner acceptance/rollback custody: `artifacts/performance-edge-geometry-map-20261014/installed-experimental-review.json` and `delivery.json`.
