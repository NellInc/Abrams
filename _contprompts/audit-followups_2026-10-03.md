# Audit and fix pass follow-ups (2026-10-03)

Claude Code audited all project code (36 slices + 3 cross-cutting contracts,
155 candidates, 148 confirmed by adversarial verification) and fixed them in two
reviewed passes, plus a website polish. Nothing is committed or deployed.
`git diff refs/claude/baseline-20261003` shows only this pass; the ref snapshots
the earlier uncommitted WIP so the two stay separable.

Final local evidence: Python 683 tests OK (1 opt-in skip, run with an
interpreter that has both Pillow and unicorn; plain python3 skips 26 more
unicorn-only subtests), all 72 validate.sh Godot checks PASS (baseline 67/69),
`tools.package.source_ci` PASS, `website/verify.py` + `test-maps.cjs` PASS.
Real runtime path after the fixes: `Play.command --capture` joystick and scenario
routes exit 0 with clean host logs, and native `tools/verify_pc_save_states.py`
passes 26/26. `git_boundary` passes on a throwaway index holding the whole tree.

## Resolved in the finishing pass (same day)

- CI patch applied by Nell after consent (F013, F072/F146, F138).
- F025: builder metadata now records `rebuilt_footer` and a truthful scope;
  `local-art/pc-map-frame-v1/frame.json` regenerated (only those four fields
  changed) and `CATALOG_SHA` rotated to 8b1fc84c...; `PC_MAP_ART` 18 checks,
  0 errors.
- F038 run natively: `test_pc_conveniences.gd -- --trace --play --frame-audit
  --capture --output DIR` gives 208 checks, 0 errors. The baseline WIP failed 5
  checks because the test still requested 2x/4x after the Session menu became
  normal/8x only; the replay is now 7x1 + 1x8 (the same fifteen frames), and the
  test fails fast with a usage message when run without `--play`.
- Import fallbacks (85 handlers, 71 tools): a missing real dependency such as
  Pillow now surfaces under its own name instead of "No module named <sibling>".

- **Published 3 October 2026.** The notarized macOS alpha.4 (signed build
  1a61287931510c16adc4; submission 871599ab-b8f4-45c7-a920-e303cf985360,
  Accepted, 0 issues; stapled; Gatekeeper "Notarized Developer ID" from the
  extracted ZIP) is attached to the v0.1.0-alpha.4 release with its source
  archive and a combined SHA256SUMS.txt (GitHub digests match). Commits
  a824e01 (pre-audit WIP), 7e3d1d2 (this pass) and merge e4fc48f were pushed to
  main as a fast-forward; Pages and source CI succeeded, and the live index is
  byte-identical to the local one. Receipt: `artifacts/notarization-20261003/`.

## Remaining

1. **F067** stays deferred by judgment: removing the dead store rotates the
   pinned trace-core hash, invalidates every checkpoint and needs parity reruns,
   for zero behavioural change. Do it with the next deliberate core rebuild.
2. **Endurance receipt** on an idle machine:
   `python3 tools/verify_pc_endurance.py --output artifacts/endurance-host-<date>`.
3. **Optional website choices** (defaults kept): a caption-free trailer encode;
   clean Modern recaptures instead of the recorded 4:3 trim; a player-facing
   name for the supported PC edition; the GitHub repo homepage URL ->
   abramsremastered.com.
4. **Project-rules files** from `/init-project` (the bilateral-alignment quick
   reference and the Bash hook registration in `hooks/`, left uncommitted) still
   need a fresh `consent-gate approve policy-gate-edit --ttl 300 --uses 3`.

## Local environment changes (not in Git)

- `.runtime/Godot.app` -> the PA copy of Godot 4.7.2, because `tools/godot.sh`
  no longer carries a developer-machine path (F074/F137).
- Restored `artifacts/promo-20260930-v4/motion/media/driver-overheating-urgent-clear-v4-dry.wav`
  from the byte-identical installed voice (sha256 d13d94d6..., matching the
  retained receipt's `media_sha256`), so `audit_pc_audio.py` passes again.
