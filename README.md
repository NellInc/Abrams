# Abrams Battle Tank reconstruction

A local Godot remaster project for Dynamix's PC **Abrams Battle Tank**.
The PC version is definitive for gameplay. The Genesis version supplies artwork,
music and sound-effect references for a faithful presentation upgrade.

## Play the current local build

* Open **Play.command** for the authored calibration range.
* Open **Art Review.command** for original/remaster artwork comparisons.
* Open **PC Bridge.command** for the original-PC/Godot tandem research view.
  It cold-boots the original menus, briefings and missions, using the ignored
  local tracing core and content ZIP. Mission exit and reentry stay in the
  original game. Its Godot view shows
  original solid geometry, EGA materials, live vehicles and bitmap effects beneath
  the original cockpit/HUD. The cockpit is still source-resolution artwork.
  Add `--wire` for its wireframe diagnostic. `--trace` retains the old mission
  snapshot probe; `--reference` selects the older static research backend.
  See `docs/pc-live-bridge.md` for controls, snapshot limits and lifecycle evidence.
  Add `--gunner-art` for the local high-resolution gunner-surround pilot. It uses
  verified surviving plate pixels above the instruments; all instruments and the
  original sight geometry stay unchanged. Missing art/provenance falls back to
  the original. See `docs/pc-ui-art-workflow.md` for its restricted scope.
  Add `--audio` for original-event sample playback and generated firing/smoke
  crew calls, plus engine and turret loops driven by original sound channels.
  F5 and original pause mute them. Remaining dialogue and music are unfinished;
  see `docs/pc-audio-research.md`.
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
* `docs/pc-sprites-research.md`: native effect extraction, original bitmap-blitter checks and tandem playback.
* `docs/pc-ui-research.md`: scanline UI provenance, transparent cockpit edges and native composition checks.
* `docs/pc-ui-art-workflow.md`: native PC cockpit plates/struts and high-resolution material studies.
* `docs/genesis-art-workflow.md`: exact graphic extraction and remaster workflow.
* `docs/genesis-audio-workflow.md`: native sample extraction and music-data boundaries.
* `docs/pc-audio-research.md`: original sound requests, bounded transport and native playback proof.
* `docs/voice-workflow.md`: generative crew speech and performance directions.
* `docs/simulation-contract.md`: provisional range behaviour and test boundaries.

Run `./tools/validate.sh` for the local test gate. Python resource tests need the
supplied PC reference files; Genesis capture tests additionally need local
captures. Pillow is required for graphics tests and extraction. Godot 4 is
required for simulation and runtime checks. The UI ownership test compiles the
actual read-only C++ observer with the local `c++` compiler.

## Distribution boundary

Nothing has been published or deployed. Supplied game files and extracted or
derived artwork have no redistribution permission established by this work.
Newly written code is unlicensed pending the project's licensing decision.
Font licenses are retained beside their files. Current effects are newly
synthesized. Crew speech uses generated performances; final casting and listening
review remain open. Emulator libraries are local research dependencies only.
