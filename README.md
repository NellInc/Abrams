# Abrams Battle Tank reconstruction

A local Godot remaster project for Dynamix's PC **Abrams Battle Tank**.
The PC version is definitive for gameplay. The Genesis version is the primary artwork source wherever available, and supplies
music and sound-effect references for a faithful presentation upgrade.

## Play the current local build

* Open **Play.command** for the original-PC/Godot tandem remaster.
* Open **Calibration Range.command** for the separate authored test range.
* Open **Art Review.command** for original/remaster artwork comparisons.
* Open **PC Bridge.command** for the original-PC/Godot tandem research view.
  It cold-boots the original menus, briefings and missions, using the ignored
  local tracing core and content ZIP. Mission exit and reentry stay in the
  original game. Its Godot view shows
  original solid geometry, live vehicles and bitmap effects with high-resolution
  cockpit material donors redrawn from Genesis sources and a colour study drawn from the extracted Genesis
  palette. Original PC instruments, map, text and visibility remain authoritative.
  The driver's overhead assembly follows its original turret-relative drawing.
  Grass and road surfaces now carry world-anchored high-resolution detail.
  Pixel-verified instrument values, weapon status and eligible crew messages
  now use scalable lettering inside their original display cells.
  Nine gunner instrument illustrations and the systems-status artwork now use
  Genesis-derived high-resolution assets. Actual PC damage indicators and live
  values remain authoritative. Verified visible crew faces use the four Genesis
  portrait derivatives; unsupported or partial faces retain the original.
  Original briefing/debriefing scenes now use the Genesis office and three
  Wilson poses, with exactly decoded scalable dialogue. Unknown poses and
  transitions retain the original. Other instruments, models and terrain are unfinished.
  Add `--original-art` for the PC-colour/source-cockpit diagnostic, or
  `--pc-colours` to keep the new cockpit materials with original world colours.
  `--flat-world` disables terrain detail while retaining cockpit art and colours.
  `--original-text` keeps the source lettering without disabling other artwork.
  `--gunner-art` selects the earlier gunner-only pilot. `--cockpit-art` explicitly
  selects the default Genesis four-station/status pass. Missing local assets or
  provenance retain the original. See `docs/genesis-cockpit-integration.md` and
  `docs/graphics-coverage.md` for current coverage and remaining work.
  Add `--wire` for the wireframe diagnostic. `--trace` retains the old mission
  snapshot probe; `--reference` selects the older static research backend.
  See `docs/pc-live-bridge.md` for controls, snapshot limits and lifecycle evidence.
  Add `--audio` for original-event sample playback and generated firing/smoke
  crew calls, plus engine and turret loops driven by original sound channels.
  The loader says “Up!” once a completed reload has a verified visible READY label.
  Fourteen additional generated takes cover the observed hit-bearing and damage
  reports, gated on complete original displayed messages. Bearings speak by digit.
  F5 and original pause mute them. Remaining dialogue and music are unfinished;
  see `docs/pc-audio-research.md`.
* Importing `godot/project.godot` in Godot 4 still runs the authored calibration
  range as its main scene. Use **Play.command** for the PC-authoritative game.
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

The local artwork collection includes the title, Colonel Wilson in three
poses, his office, motor pool, four crew portraits, four cockpit plates,
systems status, and two ammunition illustrations. The gallery has 15 comparison
pages. The additional facepalm variant appears in the live briefing restoration.
Eligible crew portraits and office/Wilson scenes bind to the PC game; information
illustrations and other frontend scenes still need live binding.
Assets are available locally under
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
* `docs/pc-text-research.md`: native fonts, visibility gates and scalable live typography.
* `docs/pc-ui-art-workflow.md`: native PC cockpit plates/struts and high-resolution material studies.
* `docs/genesis-art-workflow.md`: exact graphic extraction and remaster workflow.
* `docs/genesis-cockpit-integration.md`: Genesis-first live cockpit/status integration and native proof.
* `docs/genesis-portrait-integration.md`: Genesis faces, original visibility matching and native proof.
* `docs/genesis-briefing-integration.md`: restored office/Wilson poses and exact visible-dialogue decoding.
* `docs/graphics-coverage.md`: whole-graphics scope, source precedence and remaining families.
* `docs/genesis-audio-workflow.md`: native sample extraction and music-data boundaries.
* `docs/pc-audio-research.md`: original sound requests, bounded transport and native playback proof.
* `docs/voice-workflow.md`: generative crew speech and performance directions.
* `docs/simulation-contract.md`: provisional range behaviour and test boundaries.

Run `./tools/validate.sh` for the local test gate. Python resource tests need the
supplied PC reference files; Genesis capture tests additionally need local
captures. The Genesis cockpit and frontend tests need the local fingerprinted
remaster sets and recognition catalogs described in their integration documents.
Pillow is required for graphics tests and extraction. Godot 4 is
required for simulation and runtime checks. The UI ownership test compiles the
actual read-only C++ observer with the local `c++` compiler.

## Distribution boundary

Nothing has been published or deployed. Supplied game files and extracted or
derived artwork have no redistribution permission established by this work.
Newly written code is unlicensed pending the project's licensing decision.
Font licenses are retained beside their files. Current effects are newly
synthesized. Crew speech uses generated performances; final casting and listening
review remain open. Emulator libraries are local research dependencies only.
