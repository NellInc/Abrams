# M1 Abrams Battle Tank Fan Remaster

A high-resolution Godot fan remaster of Dynamix's **Abrams Battle Tank**, powered by the original PC game.

**Dedicated to the memory of David “Ming” Kenny.**

## Original creators

**Original game by Dynamix, published by Electronic Arts.**

| Contribution | Creator |
| --- | --- |
| Director and design | Damon Slye |
| Simulation | David McClurg |
| Product shell | Richard Rayl, Greg Volkmer |
| Artistry | Kobi Miller, Cyrus Kanga |
| World creation | Jerry Luttrell |
| Producer | Rich Hilleman |

Original game copyright 1988, 1989 Dynamix, Inc. The original intro credits are retained. The full credits also appear in About and the offline player guides.

**Fan Remastered by Nell Watson.**

## Trailer

[![Watch the Abrams Battle Tank Fan Remaster trailer](website/dist/assets/images/trailer-poster.jpg)](https://abramsremastered.com/#trailer)

[Watch the captioned trailer](https://abramsremastered.com/#trailer) · [Project website](https://abramsremastered.com/)

## Artwork and screenshots

<p align="center">
  <img src="docs/images/abrams-cover-remastered.png" width="300" alt="Abrams Battle Tank box art, by Dynamix, Fan Remaster">
  &nbsp;&nbsp;
  <img src="docs/images/abrams-icon.png" width="160" alt="Abrams Fan Remaster app icon">
</p>

Colonel Wilson's office in three graphics modes. Click an image for full resolution.

| EGA | Genesis | Genesis Upscaled |
| --- | --- | --- |
| [![Colonel Wilson's office in original PC EGA](docs/images/colonel-ega.png)](docs/images/colonel-ega.png) | [![Colonel Wilson's office with Genesis artwork](docs/images/colonel-genesis.png)](docs/images/colonel-genesis.png) | [![Colonel Wilson's office remastered in high resolution](docs/images/colonel-upscaled.png)](docs/images/colonel-upscaled.png) |

<p align="center">
  <img src="docs/images/startup-splash.png" width="640" alt="Box-art loading screen for M1 Abrams Battle Tank Fan Remaster">
</p>

## About

This project revisits a childhood favourite with restored artwork, original-style lettering, new sound effects and expressive crew speech. The Genesis version provides the visual basis wherever suitable artwork exists. The more complex PC version supplies the gameplay.

The two run in tandem: the original PC executables run inside DOSBox Pure, while Godot presents their output through a Python bridge. Missions, combat, enemy behaviour, ammunition, fuel, damage and campaign progression remain under the original game's control.

## Features

* High-resolution cockpits, portraits, briefings, information screens and ending newspapers, retaining the original visual style.
* Reconstructed typefaces, animated intro credits and a memorial dedication.
* Instant switching between six graphics modes: **EGA**, **EGA Upscaled**, **Genesis**, **Genesis Upscaled**, and the experimental **Modern** and **Tactical**, with an independent **HUD Style** (Restored or Tactical).
* Sample-based sound effects, generative crew speech and an independent authored soundtrack, with separate volume controls.
* Five save-state slots, quick save/load and **Undo last load**, alongside the original campaign saves.
* **8x fast forward, toggled with Tab**, with sound muted during accelerated play.
* Resizable windows and fullscreen, preserving the complete 4:3 display.
* **4× MSAA and 16× anisotropic filtering** for remastered scenery, adjustable in Graphics.

Tactical (`tactical`) with the Tactical HUD is the default view; Genesis Upscaled (`upscaled`) stands in when the Modern catalogue has not been derived from your PC files. EGA Upscaled enlarges the original PC frame using only its own colours. Genesis mode uses original-resolution Genesis artwork where available; unmatched areas keep PC graphics. Modern adds source-bound low-poly vehicle and building detail, illustrated trees and a restrained battlefield palette. Tactical uses the same source-bound geometry with a Calibration Range-inspired palette and decorative near-field plants. HUD Style selects Restored or Tactical instruments and layouts independently of the graphics mode. The original PC simulation, terrain and camera remain authoritative. Modern and Tactical remain experimental while performance tuning and playtesting continue. See [graphics modes](docs/graphics-modes.md).

## Install

Standalone packages target **Apple Silicon macOS 14+**, **Windows x86_64** and **Linux x86_64**. Godot and Python are bundled; players do not need to install them.

**Alpha 7 (`0.1.0-alpha.7`) is available for Windows, Linux and browser. macOS Alpha 7 is not yet available.** The separately labelled 23 October macOS preview remains available.

**You must supply the original PC game. The Genesis ROM is optional. Neither is bundled.**

1. Download your platform's ZIP from [GitHub Releases](https://github.com/NellInc/Abrams/releases), extract it, and open `M1 Abrams Battle Tank Fan Remaster.app`, `M1 Abrams Battle Tank Fan Remaster.exe` or `M1 Abrams Battle Tank Fan Remaster.sh`. On macOS, move the app to Applications.
2. Open Abrams, choose **Choose PC folder…** and select the extracted folder containing `ABRAMS.COM`, `SIM.EXE` and the remaining game files.
3. Optionally choose **Add Genesis ROM…** to enable the Genesis-based remastered artwork.
4. Click **Play Abrams** (macOS) or **Play** (Windows/Linux).

The importer checks the supported editions and leaves your originals unchanged. Without Genesis, EGA, EGA Upscaled, Genesis Upscaled, Modern and Tactical remain playable. PC-only sessions include source-verified high-resolution frontend artwork, crew portraits, lettering, animated ending smoke and the independent soundtrack. A Genesis import additionally derives its native palette, effects and original-resolution plates from your own verified ROM into your profile; the ROM itself is not copied. Native app builds made after 15 October 2026 (Alpha 4 predates this) do not offer native Genesis graphics mode or sampled Genesis frontend arrangements. The authored FRAME surround and arming clipboard require only the verified PC sources.

These are alpha packages. macOS Alpha 6 is Developer ID signed and notarized by Apple; the later 23 October preview is signed but not notarized. Windows signing is not supplied. Intel Macs are not supported. See [macOS installation](docs/standalone-macos.md), [Windows/Linux installation](docs/standalone-portable.md) and the release notes for platform testing status.

## Controls

| Action | macOS | PC mapping |
| --- | --- | --- |
| Quick save to slot 1 (press twice to overwrite) | **Cmd+S** | **Ctrl+Alt+S** |
| Quick load from slot 1 | **Cmd+L** | **Ctrl+Alt+L** |
| Undo last load | **Cmd+Shift+L** | **Ctrl+Alt+Shift+L** |
| Cycle graphics | **Cmd+G** | **Ctrl+Alt+G** |

The **Session** menu provides all five save slots and normal/8x speed. **Graphics** selects a mode directly; **Audio** controls the mix. **Help** opens the in-app keyboard sheet, searchable scenario/vehicle field guide and original credits. The loading screen and setup offer the same offline guides. Printable PDFs are bundled, with larger, bold command labels, restored manual side views, Modern model studies and original manual maps alongside maps drawn from the original PC terrain. On macOS these are in the system menu bar. The game continues while a remaster menu is open, so pause first when needed. Original game controls remain unchanged.

Save states restore both the running game and campaign disk. New checkpoints also preserve the remastered display. Saves live outside the app in the platform's player profile. Back up the whole profile before upgrading; checkpoints require a compatible core and game edition. See [controls and save behaviour](docs/play-controls.md).

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

[Architecture](docs/pc-live-bridge.md) · [Calibration range (separate)](docs/simulation-contract.md) · [Graphics coverage](docs/graphics-coverage.md) · [Audio](docs/pc-audio-research.md) · [Build status](docs/playability-status.md) · [Installation and recovery](docs/install-recovery.md)

## Project status and contributions

Development is active. Remaining work includes sustained playback performance, complete mission and campaign testing, listening and art review, and wider hardware testing. Unsupported artwork and transitions retain the original PC graphics.

Contributions should preserve original gameplay and include relevant tests or screenshots. Keep original games, ROMs, extracted resources, saves, private builds and credentials out of Git.

## Rights and original game requirement

This is an unofficial, independent fan remaster, unaffiliated with Dynamix or the original game's rights holders. The project claims no ownership, moral rights or other rights in the original game, its content, names or trademarks. Those rights remain with their respective holders.

The remaster is provided free of charge. Its own code is MIT-licensed (emulator modifications are GPL-2.0-or-later), and its original artwork/audio contributions are dedicated under CC0; those terms do not grant rights to the original game or third-party material. See [the project notice](NOTICE.md) and [rights and dependencies](docs/release-rights.md).

**The remaster cannot run without a separately obtained, supported copy of the original PC game.** No original PC game or Genesis ROM is included. A Genesis ROM is optional and cannot replace the PC game.

The software is provided as is, without warranty. Back up your profile before upgrading.
