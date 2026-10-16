# Abrams Alpha 6 release, history purge and disk cleanup, 16 October 2026

Pick up from the 15–16 October session. Nell, 16 October 2026: "get everything formulated for
a release, and uploaded. Note that we are very low on space, so let's find things in the
Abrams repo we can clean up." She has already authorised fixing, building and deploying
everything ("FIX EVERYTHING, NO EXCEPTIONS, GET IT ALL FIXED AND BUILT AND DEPLOYED") and the
history purge ("Fix everything according to your best judgment"). Carry the release through
every gate, and end site work with exactly one of "local only — not live" or
"live — verified in the served bytes".

## Where things stand

- **Branch:** `codex/modern-lowpoly` = `main` = `6b4dc62` on GitHub. The only untracked item
  is `godot/godot`, a self-referencing symlink of unknown origin created at 05:41 on
  15 October. Leave it out of commits; don't delete it without asking Nell.
- **Site:** live at https://abramsremastered.com, deployed from `d41f635` with Alpha 5
  download links (Pages run 38762028913). Later commits haven't touched `website/**`.
- **Alpha 5** (`v0.1.0-alpha.5`, tag at `162335b`) is published:
  https://github.com/NellInc/Abrams/releases/tag/v0.1.0-alpha.5
  - **macOS:** notarized (submission `eb640586-…`, Accepted, stapled).
  - **Windows/Linux:** built by `portable-alpha.yml` run 38746120300. That run's input ZIP is
    attached only to the private alpha.3 draft release.
- **Since Alpha 5:** six commits, all on the Calibration Range title screen plus three
  small decisions:
  - `9f5ccf9`, `b5db0dd`, `867cab7`, `18596d5`, `fd8fa0c`: title-tank passes matched to
    the box cover.
  - `6b4dc62`: new crew heads and cloth; voice tools now read `GOOGLE_API_KEY`/`nellwatson`;
    the Tactical map rebuild stays synchronous; native Genesis captures fall back to PC
    pixels, accepted.
  - The changed files are `godot/scripts/vehicle.gd`, `godot/scripts/cover_scene.gd`,
    `tools/generate_crew_voice.py` and docs.
  - None of this is in any app build yet. That is what Alpha 6 ships.
- **Gates passed on `6b4dc62`:** `GEOMETRY`, `RUNTIME_SMOKE_PASS`,
  `SIMULATION: 1162 checks passed`, `PC_TACTICAL_HUD: 1005 checks, 0 errors`, index
  boundary PASS. The last full `./tools/validate.sh` run (`VALIDATION_COMPLETE`, 927 Python
  tests OK, 71 skipped) was on `d41f635`. Rerun it before the release.

## Machine hazards (read before running anything heavy)

- **Disk:** about 19 GB free on `/System/Volumes/Data` after this session's cleanup, but
  something else on the machine keeps writing (free space fell about 1 GB every few
  minutes on 15 October). Check `df -h /System/Volumes/Data` before every build step, and
  delete your own intermediates as you go.
- **Kernel pipe memory is exhausted:** new pipes hold 512 bytes. It is held by a `codex`
  process (PID 41591, about 1,115 pipe handles) and a Wine session (wineserver 57653). These
  are not ours, so don't kill them; tell Nell that ending them would clear the problem.
  Until then:
  - Any Python `subprocess.run(input=…)` and `git filter-repo` deadlock (0% CPU).
  - Run the boundary check through `builds/purge-20261016/run_boundary.py` (it feeds stdin
    from a temp file), from the repo root, with `PYTHONPATH=.`:
    `PYTHONPATH=. python3 builds/purge-20261016/run_boundary.py` and `... --history`.
  - Ordinary `git push`, Godot runs and shell redirects to files work.
- **Force-pushes to `main` are blocked:** the managed hook (`ALWAYS_BLOCKED`) refuses them,
  even when the command text only appears in a heredoc. Don't try to work around it; give
  Nell the exact command to run herself with `!`.

## 1. Disk cleanup (done, plus candidates)

- **Deleted 16 October**, each item listed in `builds/purge-20261016/cleanup-manifest.txt`:
  - `builds/alpha5`, about 3 GB. All seven Alpha 5 release assets are on GitHub and
    hash-verified.
  - Five obsolete `.runtime/app-build-*` caches. The Alpha 5 builder rejected all of them;
    `.runtime/app-build-cache-alpha5` is kept for reuse.
  - Three `.runtime/*-material-test.pck` leftovers.
  - 31 old built `.app` bundles under `artifacts/` (about 11 GB). No tracked file cites them,
    and they are copies of builds already published as alpha 1–4.
- **Candidates for Nell to approve** (not deleted). The scan is in
  `builds/purge-20261016/cleanup-scan.json`:
  - 50 large `.zip` files under `artifacts/` that no tracked file cites, about 9.7 GB. Many
    are old release and input kits. Check that none is the current portable input before
    removing.
  - 32 cited `.app` bundles (about 9.6 GB) and 34 cited zips (about 7 GB). Docs name these
    as evidence locations, so ask before deleting. A gentler option: keep each folder's
    reports and receipts, and drop only the binaries.
  - The largest evidence folders (`release-alpha3-*`, `alpha-readiness-20260928`,
    `modern-pass-20260928`, `release-20260929`, `rea-victory-pilot-20261012`,
    `performance-edge-geometry-map-20261014`) are 3–5 GB each.
  - Never delete `artifacts/pc-boot-viewer/saves/` or anything pinned in
    `tests/gate_fixtures.json`.
- **Old session scratch:** `/private/tmp/claude-501/-Users-nellwatson-Documents-GitHub-Abrams/11b4e714-9fcc-4b8b-91c0-ef3fc05cb07b/scratchpad`
  (about 1 GB) can go once the purge is pushed. The cover-fit tooling has been copied to
  `builds/cover-fit-20261016/`.

## 2. Alpha 6 release

Follow `docs/standalone-macos.md`, `docs/standalone-portable.md` and
`docs/macos-notarization.md`, and copy what the Alpha 5 run did; its ledger entry in
`docs/WORK_LEDGER.md` has every hash and ID.

1. **Bump the version.**
   - In `tools/standalone/build.py`: `VERSION = '0.1.0-alpha.6'` and `BUNDLE_VERSION = '32'`.
   - In `godot/project.godot`: `config/version="0.1.0-alpha.6"`. This is checked by
     `tests/test_launcher_release_ui.py`.
   - Grep the tests and docs for `alpha.5`/`alpha5` to find any other pins.
2. **Run the gate.** Run `./tools/validate.sh </dev/null` in the background, plus
   `python3 -m tools.package.source_ci` and the boundary check via the wrapper.
3. **Build the macOS app.**
   - Build under `builds/alpha6/` with the existing build venv and
     `.runtime/app-build-cache-alpha5`, then `--verify` it.
   - Sign with "Developer ID Application: Nell Watson Ltd (BBYYCBH7EW)", notarize with the
     keychain profile `Abrams`, staple, and check with Gatekeeper.
   - Smoke-launch the signed app with a scratch profile, as Alpha 5 did (cold boot into the
     cupola in Tactical).
   - Produce the release zip and the GPL corresponding-source tarball.
   - Capture the Calibration Range title from the built app if possible, to prove it ships
     the new tank.
4. **Build Windows/Linux.**
   - Build the original-free input ZIP with the documented exporter and verify it.
   - Attach it only to the private alpha.3 draft, as for Alpha 5, never to a public release.
   - Dispatch `.github/workflows/portable-alpha.yml` and watch it to completion. It now
     fetches the pinned DOSBox Pure commit by SHA, because upstream rewrote its history.
5. **Publish.**
   - Create the GitHub pre-release `v0.1.0-alpha.6` in Alpha 5's format: three platform zips,
     three GPL source tarballs and `SHA256SUMS.txt`.
   - Release notes: the title-screen tank and crew remade to match the box cover; crew
     voice tooling moved to Nell's own key (developer-facing); no gameplay change; saves
     from Alpha 5 load as before.
   - Confirm the notes against the actual diff before writing them.
6. **Update the site.**
   - In `website/dist` (`index.html`, `app.js`, `llms.txt`), plus `website/verify.py`
     expectations, `website/README.md` and `PRODUCT.md`, update the version text and
     download links.
   - Also update `docs/playability-status.md`, `docs/standalone-*.md` and the ledger.
   - Run `python3 website/verify.py`, commit, push `codex/modern-lowpoly`, then fast-forward
     `main` (`git push origin HEAD:main`; ordinary fast-forward pushes are allowed).
   - Watch the Pages run, then curl https://abramsremastered.com/ and grep for
     `alpha.6`/`alpha 6`. Check that the trailer `<video>` still has `preload="auto"`.
   - Delete `builds/alpha6` intermediates afterwards, keeping only what the docs require.

## 3. History purge (blocked on Nell's push, which must be redone after Alpha 6)

- **Why:** six old versions of `website/dist/play/.generated/remaster-assets-0*.zip` in
  history carried data decoded from the original game. Nell approved purging them.
- **How the rewrite works:** a file-based rewrite, because filter-repo deadlocks here. It
  swaps each listed blob for a small valid zip holding `REMOVED.txt`, so every path stays a
  well-formed asset part.
  - The tool is `builds/purge-20261016/strip_stream.py`; the blob list is `strip-blobs.txt`
    (six IDs).
  - The steps: `git clone --mirror` from GitHub into `builds/purge-…`, take a `git bundle`
    backup, `git fast-export --all --show-original-ids --reencode=yes --signed-tags=strip > export.fi`,
    `python3 strip_stream.py export.fi filtered.fi strip-blobs.txt`, `git init --bare new.git`,
    and `git fast-import --quiet < filtered.fi`.
  - Verify that the main tree id is unchanged, the commit count is unchanged, and
    `git cat-file --batch-check < strip-blobs.txt` reports every blob missing. Then clone
    `new.git`, check out the branch, and run the history boundary check through the wrapper
    (it must say PASS).
- **What exists now:** `builds/purge-20261016/new.git` is a verified rewrite of the history
  up to `6b4dc62`, with backup `backup-before-purge.bundle`.
  - It passed the boundary check, has the same 155 commits and the same trees, and none of
    the six blobs.
  - Tags alpha.1, .2 and .4 are untouched. Only `v0.1.0-alpha.5` is rewritten
    (162335b → ad8c69b).
  - It is valid only while `main` is still `6b4dc62`. Once Alpha 6 commits land, redo the
    rewrite on the new history with the same steps, which now also cover the alpha.6 tag.
- **Give Nell the push command for the final rewrite,** with a lease per ref so it refuses
  if GitHub moved. It force-pushes `main`, `codex/modern-lowpoly`,
  `codex/bing-site-auth-20261012`, `codex/indexnow-verification-20261012` and the rewritten
  tags (alpha.5 and alpha.6), using `--force-with-lease=<ref>:<old sha>`. Then:
  - Realign the local checkout: `git fetch origin`, then `git reset --mixed` to the new
    branch head (trees are identical, so the working files don't change).
  - Record the purge in `docs/WORK_LEDGER.md` and in `docs/release-rights.md`, which flags
    the purge decision.
  - Delete the backup bundle only after Nell confirms.
- **GitHub Support:** Nell needs to send
  `builds/purge-20261016/github-support-request.txt`. Only Support can remove
  `refs/pull/1/head` and `refs/pull/2/head` and run GC on the cached objects. If the alpha.6
  rewrite changes nothing for those PR refs, the text stays valid; recheck the IDs.
- **Codex worktree:** `~/.codex/worktrees/promo-v9-publication/Abrams` holds a local branch,
  `codex/tactical-site-gallery`, on the old history. It is not ours; leave it and mention it.

## 4. Title screen (only if asked again)

- **Tooling** is in `builds/cover-fit-20261016/`. It needs `render.gd` inside a scratch
  Godot project whose `scripts/` holds copies of `vehicle.gd` and `cover_scene.gd`, so it
  never disturbs builds. The Godot binary is `.runtime/Godot.app/Contents/MacOS/Godot`.
  - `cam.json` holds the fitted camera; `geo.py` back-projects cover pixels to hull and
    turret coordinates.
  - `avg.py` averages a block colour-difference score over three renders. The current
    whole frame scores about 45, and the crew region (20-pixel blocks) about 59.
  - `crew.py` renders the crew beside the cover; `menucmp.py` and `menustats.py` compare a
    real `--capture` of the menu with the cover.
- **Capture the menu** with `./tools/godot.sh -- --capture <dir>`, then open
  `<dir>/01-menu.png`.
- **Watchlist for Nell's visual reports:**
  - "FAN REMASTER" stays on the menu, with only the approved words.
  - The tank must be 3D, never a photo plate.
  - The title column keeps its dim veil.
  - Heads must not read as skulls with balls on top (her 15 October screenshot).
  - Range views still render: gunner, cupola, thermal.

Working if: Alpha 6 is published with all seven assets hash-verified; the site serves the
Alpha 6 links (curl-verified); the gate is green on the release commit; the purge push
command for the final history has been handed to Nell, with the support request ready;
free disk is higher than at the start; and every deletion is listed in a manifest.

## Outcome, 16 October 2026

- **Release.** https://github.com/NellInc/Abrams/releases/tag/v0.1.0-alpha.6 holds three
  app ZIPs, three source tarballs and `SHA256SUMS.txt`. Hashes, IDs and evidence are in
  the `docs/WORK_LEDGER.md` entry "Alpha 6 built, notarized and published".
  - macOS ZIP: `c4d77c71…`
  - Windows ZIP: `a57ae054…`
  - Linux ZIP: `859fa531…`
- **Added after the brief**, at Nell's request:
  - the authored intro shot;
  - the scaled macOS launcher and About panel;
  - the scaled portable setup with no scrollbars.
- **Save states.** Alpha 5 states load on macOS and Linux. The Windows core was
  recompiled to different bytes, so Windows Alpha 5 states need Alpha 5.
- **Purge.** Redone on the final history after the release. The lease-protected push
  command and the old/new SHAs are in `builds/purge-alpha6/PUSH-COMMAND.txt`. Nell runs
  it. Then realign the checkout, record the purge in the ledger (which the 15 October
  entry already promises) and in `docs/release-rights.md`, and send the GitHub Support
  request.
- **Environment.** Kernel pipe memory was exhausted again: `codex` PID 39290 held 1,054
  pipe handles. Ending it clears the 512-byte pipes.
