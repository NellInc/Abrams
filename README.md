# Abrams Battle Tank Remaster

A faithful, high-resolution Godot remaster of Dynamix's **Abrams Battle Tank**, with the original PC game running underneath.

**Dedicated to the memory of David “Ming” Kenny.** The dedication appears in the remastered intro credits.

## About

This project revisits a childhood favourite with clearer artwork, original-style scalable lettering, new sound effects and generated crew speech. The aim is to preserve the character and complexity of the PC game while making it comfortable to play on modern displays.

The **PC version is the gameplay authority**. The **Genesis version supplies the preferred visual references wherever suitable equivalents exist**. Its artwork, palette and native sound resources guide the restoration; its simpler game logic does not replace the PC simulation.

Development is active. The current local build runs the original menus, briefings, motor pool, missions and debriefing flow through a Godot presentation layer. Three ending newspapers, the remaining source effect families, damage displays and frontend artwork now have source-bound restoration paths. The HEAT illustration, full mission-outcome acceptance and community-ready cross-platform installers remain outstanding. This is an independent fan project.

## How it works

The remaster uses a **tandem architecture**:

```text
Original keyboard input
        |
        v
Original PC executables running in a pinned DOSBox Pure core
        |
        +--> Original missions, simulation, damage, scoring and campaign saves
        |
        +--> Read-only observer: displayed pixels, draw calls, state and events
                    |
                    v
             Python bridge
                    |
                    v
             Godot presentation
             Graphics, lettering, sampled audio and crew speech
```

The original executables retain control of gameplay, including movement, targeting, ammunition, enemy behaviour, fuel, damage, repairs, difficulty and campaign progression. Godot consumes observed game output and forwards original input. The original renderer continues running because its work can affect the game.

Visual substitutions require matching source content and visibility information. Unknown scenes, unsupported drawing commands and unverified artwork fall back to the original PC presentation. A separate authored **calibration range** exists for development; it is not the original game and does not determine remaster gameplay.

## Features

### Graphics and interfaces

* **Resizable, high-resolution presentation** with a complete, letterboxed 4:3 game image, fullscreen support and rendering at the actual window resolution.
* **Genesis-first restoration** of supported cockpit plates, crew portraits, Colonel Wilson and his office, the motor pool, systems-status artwork and information illustrations.
* **Original-style scalable typefaces** for supported credits, briefings, the joystick prompt, menus, mission titles, information pages and live instruments. Text is reconstructed from verified original glyphs and screen content.
* **Source-driven intro animation**, including restored title/fire poses, original credit timing and the memorial dedication.
* **Live PC instruments and values** remain authoritative. Original damage indicators, map information, crew visibility, selections and loadouts retain their game-defined behaviour.
* **Terrain and effect treatment** follows observed original geometry and drawing order.
* **Original flat-colour vehicles** remain in Play. Experimental vehicle texture panels are disabled; replacement models and realistic rendering are deferred.

Coverage varies by screen. The publisher splash, moving menu backdrop and unsupported transitions retain original artwork. See [graphics coverage](docs/graphics-coverage.md) and [Genesis cockpit integration](docs/genesis-cockpit-integration.md).

### Sound, music and crew speech

* Event-driven cannon, coax, smoke, impact, loader, engine and turret sounds use individual samples.
* Crew calls use generated performances, with Gemini voice workflows and character-specific direction. Hit bearings are spoken digit by digit, including leading zeroes; “niner” is accepted.
* Generated takes cover bearing calls, damage reports, warnings, radio messages and further source-verified captions. Resource coverage does not mean every line has independently occurred in live testing.
* Four sample-based frontend arrangements accompany recognized intro, menu, briefing and debrief screens. They are authored arrangements, not recovered original scores.
* The **Audio** menu independently controls master, effects, voices, motors and music, and remembers the mix.
* Original **F5** and pause still govern gameplay sound. Muted or fast-forwarded events do not produce a backlog of speech when normal playback resumes.

Mixed gameplay recordings are not used as live samples. Direct Genesis sample extractions and music-data research stay in the excluded local reference directories. See [audio research](docs/pc-audio-research.md), [Genesis audio workflow](docs/genesis-audio-workflow.md) and [voice workflow](docs/voice-workflow.md).

### Save states and fast forward

* **Five numbered save-state slots**, plus **Undo last load**.
* A checkpoint includes the native emulated machine and its writable campaign disk. Loading rewinds both.
* Quick save/load uses **slot 1**. The Session menu provides all five slots.
* Overwriting a numbered slot retains its preceding archive. A load also saves a recovery checkpoint of the current session.
* **2x, 4x and 8x fast forward** executes every original frame in sequence, with presentation audio muted. The original emulated CPU settings remain unchanged.
* The original auto-save and **Take R+R** flow remains available separately.

Checkpoints are tied to the supported game bytes, native core and platform. Preserve the whole save directory and back it up before upgrades. They are not portable interchange files.

**Current save-state graphics limitation:** saving or loading restarts the observer. After the restored display frame, some remastered cockpit artwork falls back to PC artwork until the original game redraws those elements. Native game state and campaign-disk restoration are separate from this presentation limitation.

## Controls

### Keyboard shortcuts

These shortcuts apply to **Play**, including fullscreen and original game menus/briefings:

| Action | macOS | PC / other platforms |
| --- | --- | --- |
| Quick save to slot 1 | **Cmd+S** | **Ctrl+Alt+S** |
| Quick load from slot 1 | **Cmd+L** | **Ctrl+Alt+L** |
| Undo last load | **Cmd+Shift+L** | **Ctrl+Alt+Shift+L** |
| Cycle graphics | **Cmd+G** | **Ctrl+Alt+G** |

On PC, the modifier is **Ctrl+Alt together**. Alt alone is not a shortcut. Holding a shortcut does not repeatedly save, load or switch modes. Shortcut keys are withheld from the original game until released; unmodified S, L, G and the original function keys keep their original roles. A brief message confirms the action.

### Menus

* **Session → Save state / Load state → Slot 1 to 5**: choose a checkpoint explicitly.
* **Session → Load state → Undo last load**: restore the recovery checkpoint.
* **Session → Fast forward**: select normal speed, 2x, 4x or 8x.
* **Graphics**: choose a presentation directly.
* **Audio**: adjust the independent volume channels.

On macOS these menus appear in the system menu bar. The original game continues running while a remaster menu is open; use its pause control when needed. There is no permanent on-screen button toolbar.

### Graphics modes

| Mode | Presentation |
| --- | --- |
| **EGA** | Untouched original PC framebuffer and lettering. |
| **Genesis** | Verified original-resolution Genesis donor artwork where available, with original PC pixels in unmatched areas. PC gameplay and geometry remain authoritative. |
| **Upscaled** | The high-resolution remaster, including reconstructed original-style lettering. Default mode. |
| **Modern** | Reserved for future models and realistic graphics. Currently disabled. |

The shortcut cycles **EGA → Genesis → Upscaled → EGA**, skipping Modern. Switching recomposes the current frame from preloaded resources without restarting or advancing the original game.

See [the full control guide](docs/play-controls.md) for checkpoint behaviour, audio rules and [graphics-mode coverage](docs/graphics-modes.md) for exact source boundaries.

## Getting started

### Requirements and platform status

The currently validated native setup is **ARM64 macOS**, Python **3.10+** with Pillow, and **Godot 4.4+**. Local checks currently use Godot **4.7.2**; earlier engine versions are not separately certified. The native tracing-core build also needs Apple's command-line developer tools, Git and make.

The PC shortcut mapping is implemented, but a Windows/Linux runtime package has not been validated or supplied. This repository is a development checkout, not a signed standalone installer.

### Original games are supplied separately

**This repository does not contain the PC game or the Genesis ROM.** Supply your own appropriate original files locally:

| Local path | Purpose | In Git? |
| --- | --- | --- |
| `GAME/` | Supported PC executables and data. | **No** |
| `GENESIS/` | Genesis cartridge input for reference extraction. | **No** |
| `.runtime/` | Locally built emulator cores, content ZIP and build receipts. | **No** |
| `reference/` | Extracted resources, captures and fingerprint inventories. | **No** |
| `local-art/` | Extracted/remastered graphics and authoring files. | **No** |
| `local-audio/` | Native samples, music arrangements and audio working files. | **No** |
| `artifacts/` | Test evidence, captures and default checkout saves. | **No** |
| `builds/` | Local review kits, including private playable archives. | **No** |

A fresh clone cannot immediately run the tandem game. Follow [local setup and packaging](docs/packaging.md) for the supported PC input importer, pinned core build and presentation-resource requirements. The helpers do not download the original games or supply missing remastered artwork.

### Launch an equipped local checkout

```sh
./Play.command
./Play.command --fullscreen
./Play.command --window-size 1920x1080
./Play.command --graphics ega
./Play.command --saves /absolute/path/to/a/separate/profile
```

Set `GODOT_BIN` or `ABRAMS_PYTHON` to existing executables if the launcher cannot find the appropriate runtime. `./Play.command --compare` opens the side-by-side original/remaster research view.

| Entry point | Purpose |
| --- | --- |
| `Play.command` | Original-PC/Godot tandem game. |
| `PC Bridge.command` | Side-by-side bridge and rendering research. |
| `Art Review.command` | Local original/remaster artwork comparisons. |
| `Calibration Range.command` | Separate authored test range. |
| `godot/project.godot` | Godot editor project; its default main scene is the calibration range. Use Play for the original game. |

Useful rendering diagnostics include `--pc-colours`, `--flat-world`, `--original-text`, `--original-effects` and `--no-audio`. `--wire`, `--trace` and `--reference` are research modes with separate local dependencies. See [the bridge guide](docs/pc-live-bridge.md) before using them.

### Where saves live

* **Checkout Play:** `artifacts/pc-boot-viewer/saves/`, or the directory selected with `--saves`.
* **Managed private kit:** `~/Library/Application Support/Abrams/saves/`, with an optional external profile selected through `ABRAMS_DATA_HOME`.
* **Save-state slots:** `states/` beneath the chosen save directory.

**Do not delete `artifacts/` indiscriminately: it contains the checkout's default player saves.** An exclusive session lock prevents two game windows from writing the same campaign overlay. The supplied original game files remain unchanged. Audio preferences are kept separately in Godot's user-data location.

## Repository layout

| Directory | Contents |
| --- | --- |
| `godot/scripts/` | Presentation, bridge client, typography, audio and remaster controls. |
| `godot/scenes/` | Authored range and art-review scenes. |
| `godot/assets/`, `godot/data/` | Tracked presentation resources, generated audio, scripts and provenance metadata. These do not include the original games. |
| `godot/tests/` | Headless checks and native Godot acceptance fixtures. |
| `tools/` | Original-resource inspection, extraction, bridge host, emulation observers, asset builders and local packaging. |
| `tools/pc_core/` | Read-only native tracing and checkpoint support sources. |
| `tests/` | Python unit and contract tests. |
| `docs/` | Project goal, implementation evidence, workflows and remaining differences. |

Vehicle-authoring tools and studies are development material. Their presence in the repository does not enable replacement vehicles in Play.

## Validation and current limits

```sh
./tools/validate.sh
```

The full local gate needs the separately supplied originals, pinned runtime, reference captures and fingerprinted local remaster sets. Pillow supports graphics tests; Godot runs presentation and simulation checks; some observer tests compile C++ locally. Missing private inputs mean the full gate cannot run from a bare clone.

Packaging and launcher contracts can be checked without the original games:

```sh
python3 -m tools.package.source_ci
python3 -m tools.package.git_boundary
```

Validation combines original-versus-observed replay comparisons, RAM/video/input checks, source-pixel verification, native rendered captures, audio event checks and checkpoint persistence tests. Recorded routes cover all eight scenario entries, four stations, weapon inputs, pause/mute, quit/debrief, a combat-loss route and a campaign save/continue route. These bounded routes do not establish complete mission or campaign parity.

Remaining work includes:

* Complete victory, defeat and campaign-outcome coverage.
* The blocked HEAT illustration and conservative fallbacks for unrecognized frontend transitions.
* Independent art acceptance of the completed non-Modern families, including original-derived ending fixtures.
* Wider live occurrence checks and independent listening review for speech, effects and music.
* Sustained playback performance and historical speed calibration across machines; current long-run measurements and any regressions are recorded separately from correctness.
* Supported-platform installers, asset redistribution decisions and project licensing.

[Playability status](docs/playability-status.md) records what has actually been exercised. [The work ledger](docs/WORK_LEDGER.md) retains the detailed evidence and open outcomes.

## Documentation

* [Project goal](docs/GOAL.md), [original mechanics](docs/original-mechanics.md) and [simulation contract](docs/simulation-contract.md).
* [PC bridge](docs/pc-live-bridge.md), [display and resizing](docs/pc-display-research.md), [executable research](docs/pc-executable-research.md) and [reference formats](docs/reference-formats.md).
* [Shape format](docs/shape-format.md), [surfaces](docs/pc-surfaces-research.md), [sprites](docs/pc-sprites-research.md) and [UI composition](docs/pc-ui-research.md).
* [Typography](docs/pc-text-research.md), [PC UI art workflow](docs/pc-ui-art-workflow.md) and [Genesis art workflow](docs/genesis-art-workflow.md).
* [Cockpits](docs/genesis-cockpit-integration.md), [portraits](docs/genesis-portrait-integration.md), [briefings](docs/genesis-briefing-integration.md), [motor pool](docs/genesis-motor-pool-integration.md) and [intro](docs/genesis-intro-integration.md).
* [Genesis model research](docs/genesis-models-research.md), [graphics coverage](docs/graphics-coverage.md) and [graphics modes](docs/graphics-modes.md).
* [Audio research](docs/pc-audio-research.md), [Genesis audio extraction](docs/genesis-audio-workflow.md) and [voice production](docs/voice-workflow.md).
* [Remaster controls](docs/play-controls.md), [packaging](docs/packaging.md), [installation and recovery](docs/install-recovery.md), [source CI](docs/source-ci.md) and [rights/dependency review](docs/release-rights.md).
* [Ending newspapers](docs/pc-newspaper-integration.md), [Wilson poses](docs/wilson-completion.md), [maps](docs/pc-map-restoration.md), [effects](docs/pc-effect-art-completion.md), [audio audit](docs/pc-audio-completeness.md) and [endurance](docs/pc-endurance.md).

## Contributing and distribution

Keep the PC simulation authoritative, reproduce issues with the original input route where possible, and separate observed behaviour from assumptions. Include relevant tests or rendered evidence with a change. Gameplay departures, replacement vehicle integration and changes to asset sourcing require project discussion.

Never commit the PC game, Genesis ROM, extracted game resources, local native cores, personal saves, private kits or credentials. Keep original inputs in their ignored directories. Asset extraction and byte-perfect provenance do not grant redistribution rights.

Before pushing, `git ls-files GAME GENESIS reference local-art local-audio .runtime artifacts builds` should return no paths. Review outgoing history as well as the current tree; an ignored file can still exist in an earlier commit.

The GitHub repository is private during development. No project-wide licence has been selected, and no public game release is available. Existing third-party components retain their own notices and licence terms. The generated samples and other tracked presentation resources still require their recorded rights and review decisions before public distribution. See [release rights](docs/release-rights.md).
