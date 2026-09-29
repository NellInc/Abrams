# Release rights and dependency review

Reviewed 29 September 2026. **Private GitHub alpha distribution.**

The owner has authorised a free alpha release to the existing private repository.
Repository visibility remains private. The project claims no rights over original
game content. Our licensing grants cover our own contributions only; they cannot
clear the underlying game or third-party rights. See [NOTICE.md](../NOTICE.md).
This inventory records evidenced provenance and missing decisions; it is not
legal advice or a permission grant. Possession, extraction, a paid generation
account and byte-perfect provenance do not establish redistribution rights.

| Family | Evidence and licence | Package handling / unresolved gate |
|---|---|---|
| Newly written project code | MIT, except the modified emulator and its headers, which are GPL-2.0-or-later. | Full texts and scope in `LICENSE` and `LICENSES/`. |
| PC game executables, data and native fonts | Supplied original files; exact fingerprints in `tools/package/game-inputs.json`. No redistribution permission found in supplied materials. | Excluded from the standalone app and Git. Players import their own PC files. The legacy private developer kit includes owner-supplied content and is not the tester handoff. |
| Genesis originals, palette and extracted art/audio | Existing extraction receipts tie outputs to the supplied cartridge. | No ROM or standalone native-audio collection in either kit. Required palette, art donors and music containing derived percussion are private-only. Redistribution permission is unestablished. |
| Genesis/PC-derived remasters and outline fonts | Existing local source hashes, prompts, recognition catalogues and generated-asset receipts. | Our original remaster contributions are dedicated under CC0. Underlying art/font rights remain unresolved; CC0 does not cover those rights. Kept in the private alpha. |
| Authored frontend score with Genesis percussion | Local `frontend-music-v1` score/asset manifest; the percussion is derived from original Genesis samples. | Our original score contribution is under CC0; donor sample rights remain unchanged. This exact runtime directory remains in the private alpha. |
| Synthesized effects and generated speech | `godot/assets/audio/provenance.json` and provider-specific receipts where present; authored effects builder and voice-generation scripts. | Our original effects and speech contributions are under CC0 to the extent we hold rights. Provider and third-party rights remain applicable. Human listening acceptance remains separate. |
| DOSBox Pure, pinned commit `73e03aa...` | Upstream README and source headers state GPL version 2 or later; LICENSE is GPLv2. | Bundled with its licence text. The GitHub release includes all 291 tracked/patched source files and added headers, upstream notices and Makefile, plus the exact core build receipt, in a separate corresponding-source archive. |
| Godot | MIT licence; engine also includes third-party components. | Godot 4.7.2 is bundled in the standalone app. Engine and third-party notices are in `Contents/Resources/notices/Godot.json`. |
| Python | PSF licence and historical/third-party notices. | Bundled in the standalone bridge runtime. Matching notices are in `Contents/Resources/notices/Python-runtime.json`. |
| Pillow | HPND licence, with additional component notices. | Pillow 12.0.0 is bundled; its distribution notices are in `Contents/Resources/notices/Python-runtime.json`. |
| PyInstaller | Build/runtime component notices are collected from the pinned 6.22.3 installation. | Frozen bridge runtime bundled; matching notices are in `Contents/Resources/notices/Python-runtime.json`. |
| FontTools (outline builder) | MIT, according to upstream LICENSE. | Research/build dependency only, not bundled. Does not grant rights to input game fonts. |
| Unicorn (CPU oracle tooling) | Upstream identifies GPLv2. | Research dependency only, not bundled; separate from DOSBox runtime. |
| Genesis Plus GX (donor extraction) | Upstream licence contains multiple component terms, including noncommercial restrictions. | Research dependency only, excluded from both kits. Never assume DOSBox Pure terms cover it. |
| Blender (vehicle authoring) | Official COPYING identifies the GNU GPL; component terms need a separate inventory if ever bundled. | Optional authoring tool only, not bundled or required by Play. No vehicle-study outputs included. |
| EXEPACK 1.4.0 (independent comparison) | Local COPYING contains a CC0 waiver. | Research binary/source tree excluded. The project's Python unpacker remains in source. |
| Barlow and IBM Plex fonts | SIL Open Font License 1.1, retained beside current font files. | The standalone app and private developer kit retain both licence files. These licences do not clear reconstructed original-game fonts. |

Primary sources consulted:

* [DOSBox Pure pinned LICENSE](https://github.com/schellingb/dosbox-pure/blob/73e03aa145e0549ed4d5a20f8e65532714da33f5/LICENSE) and [upstream README](https://github.com/schellingb/dosbox-pure/blob/73e03aa145e0549ed4d5a20f8e65532714da33f5/README.md).
* [Godot engine licence and third-party obligations](https://godotengine.org/license/).
* [Python history and licence](https://docs.python.org/3/license.html).
* [Blender COPYING](https://raw.githubusercontent.com/blender/blender/main/COPYING).
* [FontTools licence](https://github.com/fonttools/fonttools/blob/main/LICENSE), [Unicorn licence declaration](https://www.unicorn-engine.org/), and [Genesis Plus GX component terms](https://github.com/ekeeke/Genesis-Plus-GX/blob/master/LICENSE.txt).
* [Pillow licence](https://pillow.readthedocs.io/en/stable/about.html#license).
* Bundled `godot/assets/fonts/Barlow-OFL.txt` and `Plex-OFL.txt` identify the font-specific terms. Runtime dependency version checks appear in `tools/package_runtime.py`.

## Distribution boundaries

The alpha requires a separately supplied supported PC game. Original PC files,
its reconstructed content archive and the Genesis ROM are excluded from the app,
Git history and downloadable corresponding source. The Genesis import remains
optional. Both imports verify the source before copying and preserve the user's
originals.

A disclaimer, an ownership check and a free price do not grant redistribution
rights over the original or derived third-party material. No blanket clearance
is claimed. The repository remains private; a later public distribution needs a
separate disposition of those underlying rights.

The app is ad-hoc signed, without Developer ID signing or notarization. Modern's
consistent 60 fps target and whole-mission human acceptance are still open. Those
limitations appear in the alpha release notes. Corresponding source and dependency
notices accompany the release; archive hashes identify the distributed bytes.

[MIT licence](https://opensource.org/license/mit),
[CC0 legal terms](https://creativecommons.org/publicdomain/zero/1.0/legalcode.en)
and [GPLv2 source-distribution guidance](https://www.gnu.org/licenses/old-licenses/gpl-2.0-faq.html)
provide the governing licence references. This inventory is not legal advice.
