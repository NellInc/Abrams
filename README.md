# Abrams Battle Tank reconstruction

A local Godot remaster project for Dynamix's PC **Abrams Battle Tank**.
The PC version is definitive for gameplay. The Genesis version supplies artwork,
music and sound-effect references for a faithful presentation upgrade.

## Play the current local build

* Open **Play.command** for the authored calibration range.
* Open **Art Review.command** for original/remaster artwork comparisons.
* Open **PC Bridge.command** for the local original-PC/Godot pose research view.
  It requires the ignored local emulator, content ZIP and mission snapshot.
  Run `./PC\ Bridge.command --trace` for the source-built tandem renderer with
  original solid geometry, EGA materials and live vehicles. Add `--wire` for its
  wireframe diagnostic. See `docs/pc-surfaces-research.md` for evidence and limits.
* Alternatively import `godot/project.godot` in Godot 4 and run the main scene.
* Set `GODOT_BIN` to the engine executable if the launcher cannot find it.

The range supports four stations, driving/turret modes, target selection/lock,
three main ammunition types, machine gun, smoke effects, zoom, a thermal preview,
captions and crew voice, pause/settings and local range save/restore.
F1-F4 select stations; C changes control mode; arrows move; Enter selects a
target; L locks; Space fires; M fires the machine gun; 1/2/3 select ammunition;
Z zooms; T toggles thermal; H shows help; Escape pauses.

## Current boundary

**This is an in-progress reconstruction, not a completed remake.** The current
range is authored test content. Original missions, enemy AI, exact movement,
damage, scoring and campaign parity remain unfinished. Passing internal tests
does not prove that the original game logic has been recreated.

The first remastered artwork collection includes the title, Colonel Wilson,
his office and the motor pool. It is available locally under
`local-art/genesis/`. Untouched PNG extracts, original layered OpenRaster,
palettes, exact prompts and source receipts accompany it. The original cartridge
and derived art are excluded from Git and normal project exports.

Directly extracted Genesis audio assets are in `local-audio/genesis-native-v1/`:
ten PCM samples, 25 FM patches and four native music containers. WAV wrappers
preserve every sample byte. These remain excluded from Git and game exports.
Earlier mixed recordings are retained only as comparison material.

## Research and validation

* `docs/GOAL.md`: full objective, under 3,800 characters.
* `docs/WORK_LEDGER.md`: current evidence, open outcomes and next actions.
* `docs/original-mechanics.md`: manual-derived PC requirements and unknowns.
* `docs/reference-formats.md`: PC compression and scenario/world storage.
* `docs/shape-format.md`: bounded PC vector-geometry recovery.
* `docs/pc-executable-research.md`: unpacked PC code and executable bearing comparisons.
* `docs/pc-live-bridge.md`: original-executable authority, live Godot bridge and replay evidence.
* `docs/pc-surfaces-research.md`: live original surfaces, material patterns and native colour checks.
* `docs/genesis-art-workflow.md`: exact graphic extraction and remaster workflow.
* `docs/genesis-audio-workflow.md`: native sample extraction and music-data boundaries.
* `docs/voice-workflow.md`: generative crew speech and performance directions.
* `docs/simulation-contract.md`: provisional range behaviour and test boundaries.

Run `./tools/validate.sh` for the local test gate. Python resource tests need the
supplied PC reference files; Genesis capture tests additionally need local
captures. Pillow is required for graphics tests and extraction. Godot 4 is
required for simulation and runtime checks.

## Distribution boundary

Nothing has been published or deployed. Supplied game files and extracted or
derived artwork have no redistribution permission established by this work.
Newly written code is unlicensed pending the project's licensing decision.
Font licenses are retained beside their files. Current effects are newly
synthesized. Crew speech uses generated performances; final casting and listening
review remain open. Emulator libraries are local research dependencies only.
