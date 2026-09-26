# Abrams Battle Tank reconstruction

A local Godot remaster project for Dynamix's PC **Abrams Battle Tank**.
The PC version is definitive for gameplay. The Genesis version supplies visual
inspiration for faithful higher-resolution artwork.

## Play the current local build

* Open **Play.command** for the authored calibration range.
* Open **Art Review.command** for original/remaster artwork comparisons.
* Alternatively import `godot/project.godot` in Godot 4 and run the main scene.
* Set `GODOT_BIN` to the engine executable if the launcher cannot find it.

The range supports four stations, driving/turret modes, target selection/lock,
three main ammunition types, machine gun, smoke effects, zoom, a thermal preview,
captions and scratch crew voice, pause/settings and local range save/restore.
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

## Research and validation

* `docs/GOAL.md`: full objective, under 3,800 characters.
* `docs/WORK_LEDGER.md`: current evidence, open outcomes and next actions.
* `docs/original-mechanics.md`: manual-derived PC requirements and unknowns.
* `docs/reference-formats.md`: PC compression and scenario/world storage.
* `docs/shape-format.md`: bounded PC vector-geometry recovery.
* `docs/genesis-art-workflow.md`: exact graphic extraction and remaster workflow.
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
synthesized; crew recordings are temporary synthetic takes, not final voice
performances. Emulator libraries are local research dependencies only.
