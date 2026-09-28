# Abrams Battle Tank reconstruction

A local Godot remaster project for Dynamix's PC **Abrams Battle Tank**.
The PC version is definitive for gameplay. The Genesis version is the primary artwork source wherever available, and supplies
music and sound-effect references for a faithful presentation upgrade.

## Play the current local build

* Open **Play.command** for the original-PC/Godot tandem remaster in a clean,
  resizable game window. The original 4:3 display is letterboxed rather than
  cropped or widened. Graphics and lettering render at the actual window size.
  Use `./Play.command --fullscreen` for fullscreen, or the native window controls.
  `--window-size 1920x1080` selects a starting window size. Original game keys
  remain untouched. `--compare` restores the side-by-side research view.
  See `docs/pc-display-research.md` for rendering and resize evidence.
  Campaigns use the original auto-save and Take R+R flow. Normal Play retains its
  local disk overlay in `artifacts/pc-boot-viewer/saves`; keep that directory when
  clearing diagnostic output. `--saves /absolute/path` chooses a separate profile.
  Concurrent windows cannot write the same save directory. No source game files
  are modified. See `docs/playability-status.md` for tested flows and limits.
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
  Vehicles retain their original flat-colour geometry. The experimental vehicle
  texture panels were rejected and are no longer loaded by Play. Model replacement
  is deferred while complete playability, graphics correctness and audio take priority.
  Pixel-verified instrument values, weapon status and eligible crew messages
  now use high-resolution outline reconstructions of the original typefaces
  inside their original display cells.
  Nine gunner instrument illustrations and the systems-status artwork now use
  Genesis-derived high-resolution assets. Actual PC damage indicators and live
  values remain authoritative. Verified visible crew faces use the four Genesis
  portrait derivatives; unsupported or partial faces retain the original.
  Original briefing/debriefing scenes now use the Genesis office and three
  Wilson poses, with exactly decoded scalable dialogue. Unknown poses and
  transitions retain the original. The motor pool now uses a clean-contour Genesis
  remaster with pixel-verified scalable arming labels and values; the original PC
  menu still owns selections and loadout. Other instruments, models and terrain are unfinished.
  The title now uses its Genesis-derived remaster, four high-resolution flash
  poses and the original credit lettering, selected by original PC frames.
  Its final credit screen dedicates the remaster to David "Ming" Kenny.
  Credits, briefings and 81 verified information-page text runs share those
  original-style outlines, preserving their wording, spacing and colours.
  Optical shaping regularizes letter weights, diagonal joins and stencil gaps.
  The same faces now cover the original joystick prompt, game menus, changing
  scenario options, typed names, mission titles and summary/score text. A read-only
  frontend observer verifies original font draws and current pixels, including
  selection colours; original controls and wording are unchanged.
  The publisher splash and moving 3D menu backdrop remain original.
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
  Original-event sample playback is enabled by default, with generated firing/smoke
  crew calls, plus engine and turret loops driven by original sound channels.
  The loader says “Up!” once a completed reload has a verified visible READY label.
  Generated full-sentence takes cover all 360 hit bearings, 24 damage reports and
  eight source-verified warnings/outcome calls, gated on complete original
  displayed messages. Seven original radio reports use dry Gemini speech; the
  notification sounds on arrival, and R retrieves the original displayed report.
  Bearings speak
  by digit, with both “nine” and “niner” accepted.
  F5 and original pause mute them; `--no-audio` disables remastered audio.
  The app's **Audio** menu controls master, effects, crew voices and engine/turret
  volumes independently, and remembers the mix. These controls cannot override
  the original sound gate. On macOS the menu occupies no cockpit space.
  Remaining dialogue and music are unfinished;
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

**This is an in-progress remaster.** Play runs the original PC executable, which
owns missions, enemy behaviour, movement, damage and scoring. All eight scenario
entries, four stations, weapon inputs, pause/mute, quit and debrief flows now have
an unchanged-original replay comparison across 54,657 frames. A separate
15,122-frame combat-loss, debrief and reentry route also matches the unmodified
original and passes native Godot rendering checks. Complete victory,
defeat and campaign-outcome coverage, remaining audio/graphics and historical
speed calibration are still open. The calibration range remains separate authored
content and is never the authoritative game.

The local artwork collection includes the title, Colonel Wilson in three
poses, his office, motor pool, four crew portraits, four cockpit plates,
systems status, two ammunition illustrations and three armament illustrations. The gallery has 19 comparison
pages. The additional facepalm variant appears in the live briefing restoration.
Eligible crew portraits, office/Wilson scenes, the motor pool, crew information page and five information
illustrations bind to the PC game. The title/fire/credits sequence is also live;
see `docs/genesis-intro-integration.md` for source and animation evidence.
Remaining information-page components and
other frontend scenes still need restoration and live binding.
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
* `docs/genesis-models-research.md`: recovered Genesis model programs, PC face correspondence and editable vehicle studies.
* `docs/genesis-cockpit-integration.md`: Genesis-first live cockpit/status integration and native proof.
* `docs/genesis-portrait-integration.md`: Genesis faces, original visibility matching and native proof.
* `docs/genesis-briefing-integration.md`: restored office/Wilson poses and exact visible-dialogue decoding.
* `docs/genesis-motor-pool-integration.md`: Genesis background, original arming controls and replay proof.
* `docs/graphics-coverage.md`: whole-graphics scope, source precedence and remaining families.
* `docs/genesis-audio-workflow.md`: native sample extraction and music-data boundaries.
* `docs/pc-audio-research.md`: original sound requests, bounded transport and native playback proof.
* `docs/voice-workflow.md`: generative crew speech and performance directions.
* `docs/simulation-contract.md`: provisional range behaviour and test boundaries.

Run `./tools/validate.sh` for the local test gate. Python resource tests need the
supplied PC reference files; Genesis capture tests additionally need local
captures. The Genesis cockpit and frontend tests need the local fingerprinted
remaster sets and recognition catalogs described in their integration documents.
The Genesis vehicle study check needs the local generated glTF set described
in `docs/genesis-models-research.md`; it is an authoring check, not live gameplay.
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
