# Local packaging

These are local review kits. Neither archive is cleared for publication.
`source` contains the implementation and build instructions; it omits PC and
Genesis originals, all presentation assets, voice scripts and recognition data.
It cannot play by itself. `private` adds the current owner's supplied PC content,
local tracing core and reviewed presentation-file allowlist. Keep it private.
Neither archive contains saves, save states, campaign overlays, captures,
research output, credentials, editor caches or unrelated vehicle studies.
The private audio exception is exactly `local-audio/frontend-music-v1/`; raw
generation sessions and all other local-audio working directories are excluded.

## Build and verify

From the project directory, with Python 3.10 or newer:

```sh
python3 tools/package_build.py --kind source --output builds/abrams-source-review.zip
python3 tools/package_build.py --kind private --output builds/abrams-private-local.zip
python3 tools/package_build.py --verify builds/abrams-private-local.zip
python3 -m unittest tests.test_packaging
```

Outputs must be new files. The explicit allowlist is
`tools/package/allowlist.json`. Adding a runtime dependency requires reviewing
and adding its path there. A new file elsewhere is never included automatically.
`PACKAGE.json` records every member's SHA-256, byte count and normalized mode.
Sorted uncompressed ZIP members, fixed timestamps and normalized modes yield
identical archive bytes from identical inputs. Hashes detect changed bytes;
they are integrity evidence rather than a publisher signature. This proves archive assembly
reproducibility, not bit-identical native compilation or identical generated art.
Build after runtime edits have stopped; an archive assembled during concurrent
source edits is not a coherent release candidate.

## Run the private kit

Extract into a writable directory. Open the top-level `Play.command`, or run:

```sh
python3 tools/package_runtime.py --check
sh Play.command
```

Prerequisites are a native ARM64 macOS Python 3.10+ with Pillow and an installed
Godot 4.4+ executable. Current local validation uses Godot 4.7.2; earlier supported
API versions are not separately certified. Set `ABRAMS_PYTHON` and `GODOT_BIN` to
existing executables when necessary. No dependency installer or download runs.
This is a playable source kit with prerequisites, not a signed standalone app.
The private archive replaces only its Play launcher with the managed template,
leaving the checkout and source-kit Play unchanged. The launcher imports Godot
resources, checks script compilation, then invokes the existing PC Bridge with
`--play`. The nested `tools/package/Launch.command` is an equivalent entry point. Missing dependencies and altered core/content hashes fail
before gameplay. `--check` does not start gameplay or modify saves.

Player profiles live under `~/Library/Application Support/Abrams/`:

* `saves/` holds the original disk overlay and save-state slots.
* `logs/` holds local host output and explicitly requested capture output.

Set `ABRAMS_DATA_HOME` to an absolute directory outside the kit for another
profile. The managed launcher rejects `--saves` and `--output` overrides and
legacy snapshot backends. It never resets, migrates or deletes a profile.
Upgrade by extracting the next kit separately and using the same data-home path.
Godot's audio/presentation preferences remain in its separate `user://` location.
Older checkout play data under `artifacts/pc-boot-viewer/saves` is not automatically
moved; close all game windows, retain that directory, and explicitly copy the
whole profile to the new `saves` directory if desired. Back up profiles before
upgrades; native snapshot compatibility is governed by the core/format checks.

## Rebuild from separately owned inputs

A source kit deliberately omits originals and generated presentation assets.
This helper validates all 68 supported PC input files before copying them:

```sh
python3 tools/package_setup.py --game /absolute/path/to/owned/GAME --destination /absolute/path/to/source-kit
```

Existing GAME directories and ZIPs are never overwritten. The importer recreates
the existing content ZIP, including its frozen metadata, to its pinned SHA-256.
It neither obtains game files nor establishes rights to use or redistribute them.
Other revisions are unsupported until separately validated.

The native build needs Apple's command-line developer tools, Git and make.
Obtain the DOSBox Pure source separately from its official repository, pin commit
`73e03aa145e0549ed4d5a20f8e65532714da33f5`, and place that clean checkout at
`.runtime/dosbox-pure-source`. Before applying the observer:

```sh
make -C .runtime/dosbox-pure-source -j4
cp .runtime/dosbox-pure-source/dosbox_pure_libretro.dylib .runtime/pc-core/source-baseline.dylib
python3 -m tools.build_pc_trace_core
```

The existing builder checks the commit and recognized edits, retains baseline
identity, applies the local headers and records compiler/input/output hashes.
The native binary can vary across toolchains. Runtime parity must be rerun for a
new build; a successful compile is insufficient. The private kit intentionally
omits the separate reference backend and historical mission snapshots.

Presentation assets must be generated or supplied locally through the documented
project workflows; the source kit does not reconstruct unavailable generated
outputs or grant permission to reproduce derivative art. Full community setup,
rights clearance, supported-platform installers and publication remain open.
See [rights review](release-rights.md).

## Source-test fixture boundary

The source kit includes authored keyboard-step sequences (`*_steps.json`), the
numeric bearing results (`pc_bearings.json`) and numeric sound request expectations
(`pc_request_sound_oracle.json`). These are test inputs/results, not copied ROM,
framebuffer or PCM assets. Dialogue oracle files (`pc_damage_voice_oracle.json`,
`pc_radio_voice_oracle.json`, `pc_warning_voice_oracle.json`, and the newer
`pc_remaining_voice_oracle.json`) contain extracted original text; they remain
private alongside voice scripts. Tests needing them or original game files require
the corresponding local inputs. Pure packaging and launcher tests run from the
source kit without those inputs. The private kit's managed Play entry intentionally
differs from the research launcher's command contract tested by `test_launchers`.

## Repository and installation gates

The dependency-free source gate and read-only staged/history exclusions are
specified in [source-ci.md](source-ci.md). Fresh installs, profile-preserving
upgrades, rollback and the native Windows/Linux boundary are documented in
[install-recovery.md](install-recovery.md). Source CI does not certify gameplay,
rights clearance, signing, or a supported native port.
