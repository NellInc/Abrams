# Install Abrams on macOS

The ARM64 `.app` bundles Godot and its Python/Pillow bridge runtime. Players
need no separately installed interpreter or engine. It targets macOS 14 or newer;
other OS versions and Intel Macs have not been validated. Windows packaging remains deferred. Modern is included as an experimental mode; retain the preceding alpha for rollback.

## Install and play

**PC files are required. The Genesis ROM is optional. Neither is bundled.**

1. Download the macOS ZIP from [GitHub Releases](https://github.com/NellInc/Abrams/releases),
   extract it and move `Abrams.app` to Applications. Keep your previous app until
   you have tested the new one.
2. Open `Abrams.app`. Click **Choose PC folder…** and select your extracted PC
   game folder containing `ABRAMS.COM`, `SIM.EXE` and the remaining data files.
3. Optionally click **Add Genesis ROM…** and select the supported raw ROM.
   You can add it later through the same launcher.
4. Once the launcher reports **Ready to play**, click **Play Abrams**.

You do not need to install Godot, Python or Pillow. The importer leaves your
source files unchanged. Genesis alone cannot run the game.

| Available content | Presentation |
| --- | --- |
| PC only | EGA, PC-only Upscaled and Modern when included, high-resolution lettering/world rendering, generated speech and synthesized gameplay sounds. PC graphics remain where Genesis assets would be used. |
| PC and Genesis | Also enables Genesis mode, Genesis-based remastered artwork and frontend music. |

Use **Cmd+S** to save, **Cmd+L** to load, **Cmd+Shift+L** to undo a load and
**Cmd+G** to cycle the available graphics modes. The **Session** menu contains all
five slots and fast-forward speeds; **Audio** controls the mix.

### If installation stops

* **PC import rejected:** select the complete extracted game folder, rather than
  a ZIP or a folder containing only the executables. The importer checks all 68
  files against the supported edition in `tools/package/game-inputs.json`.
  Changed files, conflicting filename spellings and other editions are rejected.
* **Genesis import rejected:** use the supported raw ROM, rather than a ZIP.
  Its SHA-256 is `ff83dc53b33252d42ac624e11a2ce717428b75f48f2e56a20b3d38f78e6ca4ea`.
  You can continue with PC-only play. The importer stores a revision receipt,
  without copying the ROM into the profile.
* **macOS blocks the app:** this alpha is ad-hoc signed, without Developer
  ID signing or notarization. Report the warning; do not disable system security
  to run it.
* **Startup error:** keep the displayed message and the profile's `logs/` folder.
  Do not delete the profile or alter integrity receipts to work around an error.

The application excludes the original PC game files, reconstructed PC content
archive and Genesis ROM. Original and third-party rights remain intact; see [the notice](../NOTICE.md).
 Releases are available to people who have access to the GitHub repository.
The launcher includes **About** and **GitHub** buttons, licence information and
the dedication to David “Ming” Kenny.

## Profiles, upgrades and rollback

Mutable files are outside the app, in
`~/Library/Application Support/Abrams/`:

* `content/` contains the verified PC import and optional Genesis revision receipt.
* `versions/<build-id>/` contains a verified runnable copy of that app's payload.
* `saves/` holds campaign disk changes, five save-state slots and load recovery.
* `logs/` holds startup/bridge diagnostics and explicitly requested captures.

An upgrade stages a new version without replacing older versions, imported
content or saves. Older apps remain usable for rollback with the same data home,
subject to the tracing core's existing save-state compatibility checks. Back up
profiles before upgrades. No automatic cleanup, profile migration or save repair
runs. Changed payload/content is refused and preserved for diagnosis. The app
bundle itself is never used for saves, caches or Godot imports.

For an independent profile, set `ABRAMS_DATA_HOME` to an absolute directory, or
run `Abrams.app/Contents/MacOS/Abrams --data-home /absolute/profile/path`.
Do not run two game instances against one profile. Close the game window before
quitting the launcher, so the original simulation can close its campaign disk.
Godot audio preferences retain the existing separate `user://` location.

## Build locally

Use the existing pinned trace core, reviewed assets and supported original inputs
in the checkout. The originals are validated during assembly, then excluded.
Create an isolated build environment with PyInstaller 6.22.3 and Pillow 12.0.0.
No dependency installer runs in the app or builder.

```sh
python3 tools/standalone/build.py \
  --python /absolute/build-venv/bin/python \
  --godot /absolute/Godot.app/Contents/MacOS/Godot \
  --output /absolute/new/Abrams.app
python3 tools/standalone/build.py --verify /absolute/new/Abrams.app
```

Outputs must be new paths. The builder copies and thins Godot to ARM64, freezes
the bridge runtime, compiles the AppKit importer, records every payload hash,
checks original-file fingerprints and non-system Mach-O dependencies, and seals
the app with an ad-hoc signature. Third-party notices accompany the bundle.
This Modern build updates the trace core. Earlier snapshot saves remain on disk but require their matching older app; original campaign saves are separate. Keep the preceding alpha for those snapshots.

Changes to frozen-runtime inputs require a fresh `--cache` directory. Compiler
bit-reproducibility and public distribution clearance are separate work.

## Verification boundaries

Importer contracts use tiny synthetic fixtures in source-only CI. Native checks
must additionally exercise real supported imports, a sanitized environment with
no package-manager Python/Godot, PC-only and Genesis-enabled playback, actual
window focus/fullscreen/menu transitions, and the Modern two-hour paced production soak.
A build or a short smoke alone does not satisfy those native gates. The bounded
soak cycles the four original stations, all available graphics modes, quick saves/restores
and fast forward; it makes no mission-victory or human-listening claim.

See [build status](playability-status.md) for the current runtime checks and
remaining performance, mission and platform testing.
