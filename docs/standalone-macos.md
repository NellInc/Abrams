# Standalone macOS private alpha

The local ARM64 `.app` bundles Godot and its Python/Pillow bridge runtime. Players
need no separately installed interpreter or engine. It targets macOS 14 or newer;
other OS versions and Intel Macs have not been validated. Windows packaging and
Modern graphics remain deferred.

## Original game inputs

**The original PC game is required. Genesis is optional.** The PC executable
continues to run the simulation, menus, campaign and combat. Genesis supplies
presentation references, never replacement gameplay rules.

On first launch choose the extracted PC folder containing `ABRAMS.COM` and
`SIM.EXE`. All 68 supported files are fingerprinted before import. The exact
supported edition is recorded in `tools/package/game-inputs.json`. Filenames
are case-insensitive; conflicting spellings, changed files and unsupported
editions are rejected. There is no game downloader.

For the full current artwork, add the supported raw Genesis ROM with SHA-256
`ff83dc53b33252d42ac624e11a2ce717428b75f48f2e56a20b3d38f78e6ca4ea`.
The importer validates it and retains a small revision receipt, without copying
the ROM. This receipt identifies the imported revision; it establishes no rights.

Without Genesis, EGA and PC-only Upscaled remain available. PC-only Upscaled
retains high-resolution PC typography/world rendering, generated crew speech and
synthesized gameplay samples. Cockpits, portraits and effects use the PC fallback;
Genesis donor imagery, hills and frontend music stay disabled. Adding Genesis
later enables the full Genesis/Upscaled presentation and the three-way graphics
shortcut. Modern remains visibly unavailable.

The application excludes raw PC game files, the reconstructed PC content ZIP,
and the Genesis ROM. Its reviewed derived assets are still private: removal of
raw originals does not establish redistribution permission. This alpha uses an
ad-hoc local signature, with no Developer ID signing or notarization. It has not
been published or uploaded.

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
Changes to frozen-runtime inputs require a fresh `--cache` directory. Compiler
bit-reproducibility and public distribution clearance are separate work.

## Verification boundaries

Importer contracts use tiny synthetic fixtures in source-only CI. Native checks
must additionally exercise real supported imports, a sanitized environment with
no package-manager Python/Godot, PC-only and Genesis-enabled playback, actual
window focus/fullscreen/menu transitions, and a 30-minute paced production soak.
A build or a short smoke alone does not satisfy those native gates. The bounded
soak cycles the four original stations, EGA/Genesis/Upscaled, quick saves/restores
and fast forward; it makes no mission-victory or human-listening claim.

The 28 September local ARM64 candidate completed a 30-minute audited SIM soak,
all four stations and 18 restores. Native import, PC-only play, graphics switching,
checkpoint recovery and fullscreen/focus interactions have local receipts. The
heavily instrumented run averaged about 36 to 38 original replies per second;
sustained unaudited target-rate acceptance remains separate. Detailed local
receipts are under `artifacts/alpha-readiness-20260928/ACCEPTANCE.md`.
