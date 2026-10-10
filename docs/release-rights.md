# Release rights and dependency review

Reviewed 29 September 2026 for the private alpha; the owner's browser-edition
publication decision was recorded 10 October 2026. The browser package is
assembled for the project site and includes corresponding Web core source.

The owner authorised a free alpha release. The project claims no rights over original
game content. Our licensing grants cover our own contributions only; they cannot
clear the underlying game or third-party rights. See [NOTICE.md](../NOTICE.md).
This inventory records evidenced provenance and missing decisions; it is not
legal advice or a permission grant. Possession, extraction, a paid generation
account and byte-perfect provenance do not establish redistribution rights.

| Family | Evidence and licence | Package handling / unresolved gate |
|---|---|---|
| Newly written project code | MIT, except the modified emulator and its headers, which are GPL-2.0-or-later. | Full texts and scope in `LICENSE` and `LICENSES/`. |
| PC game executables, data and native fonts | Supplied original files; exact fingerprints in `tools/package/game-inputs.json`. No redistribution permission found in supplied materials. | Excluded from the standalone app and Git. Players import their own PC files. The legacy private developer kit includes owner-supplied content and is not the tester handoff. |
| Genesis originals, palette and extracted art/audio | Existing extraction receipts tie outputs to the supplied cartridge. | No ROM or standalone native-audio collection in either kit. The owner authorised public use of remaster assets for the proposed browser edition on 10 October 2026; redistribution permission from underlying rights holders remains unestablished. |
| Genesis/PC-derived remasters and outline fonts | Existing local source hashes, prompts, recognition catalogues and generated-asset receipts. | Our original remaster contributions are dedicated under CC0. The owner authorised public browser use, but CC0 does not cover unresolved underlying art/font rights. |
| Authored frontend score with Genesis percussion | Local `frontend-music-v1` score/asset manifest; the percussion is derived from original Genesis samples. | Our original score contribution is under CC0; donor sample rights remain unchanged. Owner authorisation for browser use does not clear those rights. |
| Synthesized effects and generated speech | `godot/assets/audio/provenance.json` and provider-specific receipts where present; authored effects builder and voice-generation scripts. | Our original effects and speech contributions are under CC0 to the extent we hold rights. Provider and third-party rights remain applicable. Human listening acceptance remains separate. |
| DOSBox Pure, pinned commit `73e03aa...` | Upstream README and source headers state GPL version 2 or later; LICENSE is GPLv2. | Bundled with its licence text. The native GitHub release includes corresponding source and its core build receipt. The browser site separately links its modified Web core source, frontend and reproducible build script. |
| Godot | MIT licence; engine also includes third-party components. | Godot 4.7.2 is bundled in both editions. Native notices are in `Contents/Resources/notices/Godot.json`; the browser includes the matching extracted notices under `play/LICENSES/`. |
| Python | PSF licence and historical/third-party notices. | The standalone bridge has `Contents/Resources/notices/Python-runtime.json`. The Web edition bundles CPython 3.13.2 through Pyodide and its licence under `play/LICENSES/`. |
| Pyodide | MPL-2.0 for its 0.29.5 runtime. | The Web edition includes its licence and source location in `play/THIRD_PARTY.txt`. |
| Pillow | HPND/MIT-CMU licence, with additional component notices. | Native Pillow 12.0.0 notices are in `Contents/Resources/notices/Python-runtime.json`; the Web edition ships Pillow 11.3.0 and the licence from its exact wheel. |
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
is claimed. The owner chose public use of the browser assets despite the
unresolved underlying rights. This records her publication decision, not
rights-holder permission or legal clearance. A rights-holder claim remains a
material publication risk.

The app is ad-hoc signed, without Developer ID signing or notarization. Modern's
consistent 60 fps target and whole-mission human acceptance are still open. Those
limitations appear in the alpha release notes. Corresponding source and dependency
notices accompany the release; archive hashes identify the distributed bytes.

[MIT licence](https://opensource.org/license/mit),
[CC0 legal terms](https://creativecommons.org/publicdomain/zero/1.0/legalcode.en)
and [GPLv2 source-distribution guidance](https://www.gnu.org/licenses/old-licenses/gpl-2.0-faq.html)
provide the governing licence references. This inventory is not legal advice.
