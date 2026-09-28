# Abrams Battle Tank Remaster

A high-resolution Godot fan remaster of Dynamix's **Abrams Battle Tank**, powered by the original PC game.

**Dedicated to the memory of David “Ming” Kenny.**

## Artwork and screenshots

<p align="center">
  <img src="docs/images/abrams-cover-remastered.png" width="300" alt="Abrams Battle Tank box art, by Dynamix, Fan Remaster">
  &nbsp;&nbsp;
  <img src="docs/images/abrams-icon.png" width="160" alt="Abrams Fan Remaster app icon">
</p>

Colonel Wilson's office in three graphics modes. Click an image for full resolution.

| EGA | Genesis | Upscaled |
| --- | --- | --- |
| [![Colonel Wilson's office in original PC EGA](docs/images/colonel-ega.png)](docs/images/colonel-ega.png) | [![Colonel Wilson's office with Genesis artwork](docs/images/colonel-genesis.png)](docs/images/colonel-genesis.png) | [![Colonel Wilson's office remastered in high resolution](docs/images/colonel-upscaled.png)](docs/images/colonel-upscaled.png) |

## About

This project revisits a childhood favourite with restored artwork, original-style lettering, new sound effects and expressive crew speech. The Genesis version provides the visual basis wherever suitable artwork exists. The more complex PC version supplies the gameplay.

The two run in tandem: the original PC executables run inside DOSBox Pure, while Godot presents their output through a Python bridge. Missions, combat, enemy behaviour, ammunition, fuel, damage and campaign progression remain under the original game's control.

## Features

* High-resolution cockpits, portraits, briefings, information screens and ending newspapers, retaining the original visual style.
* Reconstructed typefaces, animated intro credits and a memorial dedication.
* Instant switching between **EGA**, **Genesis** and **Upscaled** graphics.
* Sample-based sound effects, new music arrangements and generative crew speech, with separate volume controls.
* Five save-state slots, quick save/load and **Undo last load**, alongside the original campaign saves.
* **2x, 4x and 8x fast forward**, with sound muted during accelerated play.
* Resizable windows and fullscreen, preserving the complete 4:3 display.

Upscaled is the default. Genesis mode uses original-resolution Genesis artwork where available; unmatched areas keep PC graphics. Vehicles retain their original flat-colour appearance. **Modern** graphics and replacement models are deferred.

## Play the private alpha

The standalone app currently targets **Apple Silicon Macs running macOS 14 or newer**. Godot and Python are bundled; players do not need to install them.

**You must supply the original PC game. The Genesis ROM is optional. Neither is bundled.**

1. Copy `Abrams.app` to a local folder and open it.
2. Click **Choose PC folder…** and select the extracted folder containing `ABRAMS.COM`, `SIM.EXE` and the remaining game files.
3. Optionally click **Add Genesis ROM…** to enable the Genesis-based artwork and music.
4. Click **Play**.

The importer checks the supported editions and leaves your originals unchanged. Without Genesis, EGA and PC-only Upscaled remain playable, with high-resolution lettering and crew speech; Genesis-based graphics and music stay disabled.

The app is a local private alpha, without notarization or a public download. Windows, Linux and Intel Mac packages are not available. See [installation and troubleshooting](docs/standalone-macos.md).

## Controls

| Action | macOS | PC mapping |
| --- | --- | --- |
| Quick save to slot 1 | **Cmd+S** | **Ctrl+Alt+S** |
| Quick load from slot 1 | **Cmd+L** | **Ctrl+Alt+L** |
| Undo last load | **Cmd+Shift+L** | **Ctrl+Alt+Shift+L** |
| Cycle graphics | **Cmd+G** | **Ctrl+Alt+G** |

The **Session** menu provides all five save slots and fast-forward speeds. **Graphics** selects a mode directly; **Audio** controls the mix. On macOS these are in the system menu bar. The game continues while a remaster menu is open, so pause first when needed. Original game controls remain unchanged.

Save states restore both the running game and campaign disk. New checkpoints also preserve the remastered display. Saves live outside the app at `~/Library/Application Support/Abrams/saves/`. Back up the whole profile before upgrading; checkpoints require a compatible core and game edition. See [controls and save behaviour](docs/play-controls.md).

## Development

A fresh clone needs separately supplied game files, local presentation assets and a built tracing core. Follow [source setup and packaging](docs/packaging.md). Source development requires Python 3.10+ with Pillow, Godot and Apple's native build tools; current local testing uses Godot 4.7.2.

From an equipped checkout:

```sh
./Play.command
./Play.command --fullscreen
./Play.command --graphics ega
./tools/validate.sh
```

`Play.command` runs the original game. The Godot editor's default scene is a separate development range. Checkout saves default to `artifacts/pc-boot-viewer/saves/`; preserve them when clearing test output.

* `godot/`: presentation, audio, controls and rendering tests.
* `tools/`: emulation bridge, resource extraction and packaging.
* `tests/`: Python tests.
* `docs/`: setup, architecture, asset workflows and test results.

[Architecture](docs/simulation-contract.md) · [Graphics coverage](docs/graphics-coverage.md) · [Audio](docs/pc-audio-research.md) · [Build status](docs/playability-status.md) · [Installation and recovery](docs/install-recovery.md)

## Project status and contributions

Development is active. Remaining work includes sustained playback performance, complete mission and campaign testing, listening and art review, and wider platform support. Unsupported artwork and transitions retain the original PC graphics.

Contributions should preserve original gameplay and include relevant tests or screenshots. Keep original games, ROMs, extracted resources, saves, private builds and credentials out of Git.

This is an independent fan project. The repository is private, no project-wide licence has been selected, and public distribution requires asset and dependency clearance. See [rights and dependencies](docs/release-rights.md).
