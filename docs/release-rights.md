# Release rights and dependency review

Reviewed 29 September 2026 for the private alpha; the owner's browser-edition
publication decision was recorded 10 October 2026 (see the
[work ledger](WORK_LEDGER.md) entry for 10 to 11 October 2026), and its asset
boundary was revised on 15 October 2026 to stop publishing decoded original data. The browser package is
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
| PC game executables, data and native fonts | Supplied original files; exact fingerprints in `tools/package/game-inputs.json`. No redistribution permission found in supplied materials. | Excluded from the standalone app and Git. Players import their own PC files. The legacy private developer kit includes owner-supplied content and is not the tester handoff. Since 15 October 2026 native apps also ship no decoded PC data: the 19 PC rows of `tools/standalone/import-derived.json` are derived on the player's machine from their verified files into `content/derived/<sha256>`. |
| Recognition data decoded from PC files | Five station plates (`local-art/pc-ui-v2/*-bin.png`), the stacked `expected.png`, FACES.BMP portrait pixels (`faces.json`), ATBASE.BIN and CLIP.BMP indices. Decoded by `web-prototype/derived_art.mjs` and the desktop extractors from verified files. | Not distributed by the Web edition: the browser derives them from the visitor's verified PC files, and `tools.package.git_boundary` rejects them in Git. Web parts published 10 to 15 October 2026 did contain them, plus the strut and frame plates (audit, 15 October 2026). Those six part versions were purged from Git history on 16 October 2026: each is replaced by a small archive holding `REMOVED.txt` (see Distribution boundaries). Native kits derive them at import (see the PC row above). Since 15 October 2026 `local-art/pc-modern/catalog.json` no longer carries the decoded SHAPE.TBL `source_primitives` beside its authored meshes: that per-shape structure moved to a player-derived `source-shapes.json` (`tools/build_pc_modern_assets.py`), and `tools/package/web-publication.json` records no exceptions. Godot's Modern catalogue loader (and so Modern and Tactical) requires that file. `derived_art.mjs` derives it in the browser, and the native import derives it with the `pc-shape-registry` recipe in `tools/standalone/import-derived.json`. Both produce bytes identical to `registry_bytes(source_registry(SHAPE.TBL))` under the catalogue's pin (3be92319…, 175,371 bytes). That hash is in `decoded_denylist`, and the path is in `runtime_derived`. |
| Genesis originals, palette and extracted art/audio | Existing extraction receipts tie outputs to the supplied cartridge. Most donors are lossless crops of emulator screen captures, not direct ROM decodes. | No ROM or standalone native-audio collection in either kit. Native apps built after 15 October 2026 ship no raw Genesis extracts, reference captures or ROM-derived audio (`reference/**`, `local-art/genesis/source/**`, `local-audio/frontend-music-v1/**` and the pinned paths in `tools/standalone/import-derived.json`). Its 7 Genesis rows (palette, effects, the ending newspaper and destroyed-tank plates) are derived from the player's verified ROM into the profile; the plates come from a pure-Python port of the ROM's own 9AFE/9B20 decoder (`tools/standalone/runtime.py`), checked against the original routine. The Genesis receipt lists the files actually derived, and Genesis turns on only when every pinned row is verified (only encoder-dependent PNGs may be unavailable). Native Genesis graphics mode, map frame, clipboard and remastered frontend music are therefore unavailable. The status-damage difference masks are one-bit masks, and the information-completion caption masks are one-bit cell masks of the words ABRAMS and M1A1, so both ship [Inference: not decodes of original pixels]. `NATIVE_RAW_WHITELIST` in `tools/standalone/build.py` is empty; adding anything to it requires the owner's decision. From 15 October 2026 the Web edition publishes no raw extracts (`*-original.png`, the captured palette, effects pixels). The browser derives the 64 effects from the visitor's verified ROM. Capture-based donors cannot be derived in the browser, so on the Web the Genesis-native mode, the Genesis newspaper, map-frame and clipboard restorations and Genesis vehicle colours fall back to original PC pixels. Parts published before that date were purged from Git history on 16 October 2026. |
| Genesis/PC-derived remasters and outline fonts | Existing local source hashes, prompts, recognition catalogues and generated-asset receipts. | Our original remaster contributions are dedicated under CC0. The owner authorised public browser use, but CC0 does not cover unresolved underlying art/font rights. The site hosts the Genesis-derived remaster art and frontend score; the Web ROM check is an ownership check that unlocks them, not technical protection. |
| Box-art-derived cover and app icon | `branding/README.md`: restored from the local box scan `reference/manual-pages/scan-000.jpg` by generative restoration, then adapted for the icon. | The owner approved public use for the project page (1 October 2026) and the browser edition (10 October 2026). Published copies are `docs/images/abrams-cover-remastered.png` and `abrams-icon.png`, the site WebP derivatives and the cover inside the browser pack. The underlying Dynamix/Electronic Arts artwork rights remain with their holders; CC0 covers only our edits. |
| Authored frontend score with Genesis percussion | Local `frontend-music-v1` score/asset manifest; the percussion is derived from original Genesis samples. | Our original score contribution is under CC0; donor sample rights remain unchanged. Owner authorisation for browser use does not clear those rights. |
| Independent Suno score | Twelve original instrumental masters generated and downloaded on the owner's Pro subscription on 23 October 2026, with no uploaded game audio, plus local phrase edits and arrangements. [Suno paid-plan rights](https://help.suno.com/en/articles/9601665) expressly include video-game use; [terms](https://suno.com/terms-of-service) remain applicable. | The owner explicitly authorised installed-app and Web delivery on 23 October 2026. Nineteen hash-pinned game derivatives and their manifest ship in both editions, including PC-only Web sessions. Original masters and prior edits remain private. This records provider usage rights and owner authorisation, not a guarantee of copyright registration or independent listening acceptance. |
| Synthesized effects and generated speech | `godot/assets/audio/provenance.json` and provider-specific receipts where present; authored effects builder and voice-generation scripts. | Our original effects and speech contributions are under CC0 to the extent we hold rights. Provider and third-party rights remain applicable. Human listening acceptance remains separate. |
| Approved switch/contact effect | Kenney Interface Sounds `click_002.ogg`, archive/member hashes and the authored mechanical recipe in `tools/audio/switch-approved-provenance.json`; original licence text in `tools/audio/Kenney-Interface-License.txt`. | Kenney's retained licence permits personal, educational and commercial use under CC0. This designed contact and our authored layers contain no original-game, paid recording, voice or music. The approved PCM is tracked and copied unchanged by the effects builder; the code-only source kit continues to exclude PCM, while the existing asset-bearing kit allowlist includes this input. No kit was rebuilt here. |
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
| Barlow and IBM Plex fonts | SIL Open Font License 1.1, retained beside current font files. | The standalone app, private developer kit and Web edition (`/play` `LICENSES/IBM-Plex-OFL.txt` and `assets/Barlow-OFL.txt`; both TTFs are embedded in the Godot PCK) retain both licence files. These licences do not clear reconstructed original-game fonts. |

## Recorded effects and environment pass, 28 October 2026

The latest recorded effects are optional local banks, excluded from public Git,
source kits and the currently published game packs. The selected originals,
edits, purchase/download evidence and licence snapshots remain private. A source
push and a browser-shell update do not establish redistribution clearance or
deliver these banks to players.

| Selected family | Current evidence | Distribution boundary |
|---|---|---|
| Abrams cannon/MG/motors and M113 | Purchased PSE originals; [individual EULA](https://www.prosoundeffects.com/individual-end-user-license-agreement) and [licensing summary](https://www.prosoundeffects.com/licensing) rechecked. | Ordinary production editing and synchronized end-user works are covered subject to the agreement. Standalone-file access and extraction restrictions remain. No paid PCM is committed or exposed as a public download. |
| Hind engine | Human-purchased SoundFX Studio pack and [publisher licence](https://soundfx.studio/soundfx-studio-license/), rechecked. | Game synchronization and edits are permitted subject to the licence; unsynchronized sharing and unlicensed multi-user access are restricted. The selected engine remains private. This does not certify every alternative pack cue as an original field recording. |
| T-72 engine | Human-supplied purchased SoundFX Studio archive, vendor-labelled Idle original, approved loop and [publisher licence](https://soundfx.studio/soundfx-studio-license/) rechecked28October. | Approved derivative installed only in the optional private local bank. Editing and game synchronization are described; standalone sharing and unlicensed multiuser access remain restricted. No independent field-session/exterior-perspective certification, new purchase or agreement acceptance. |
| Bluezone smoke preview | Human explicitly identifies the supplied MP3 as a preview copy. | Audition-only reference, excluded from runtime and derivative authoring. Current approved authored/CC0 smoke remains unchanged. No Soundsnap subscription or purchase. |
| Bradley-family engine | Human-supplied purchased SoundDogs original and [sound-effects EULA](https://sounddogs.com/Page/Sound-Effects-End-User-License), rechecked. | Game synchronization and ordinary edits are described. Standalone-source and AI/ML-use restrictions remain; no recording is sent to a model. This inventory does not assert universal clearance for every assistant-operated workflow or exact M2/M3 recording identity. |
| T-80 engine | Creator-labelled Freesound456277 source, CC BY-NC4.0. | Attribution, modification notice and noncommercial limits remain. Keep the private boundary unless the intended release is specifically cleared; otherwise use a cleared fallback. |
| Generic tank fallback | JoniHeinonen Freesound161896, CC BY3.0, retained source and modification attribution. | Exact tank model is unidentified. Any distributable derivative must retain the applicable credit/licence/modification notice; its present bank remains local. |
| Woodland/fire revisions | Saved La Sonotheque forest-edge0905 and PagDev fireplace originals, retained CC0 source-page/licence evidence. | Replacement character/loop and production-level reviews are accepted; the derivatives are installed privately. Fire provenance is a fireplace, without an actual military-blaze claim. German woodland is the accepted art direction, not a verified field-recording location. |

Before any new asset-bearing game release, enumerate its exact selected files,
check each intended use against the retained terms, include required notices and
inspect the actual outgoing package. Free source material and local possession
do not by themselves close the release gate. No new purchase, agreement or
vendor communication was made in this review.

Working if: every selected derivative has a recorded source and release
disposition, private paid audio stays out of public source/download inventories,
and a new game package is checked independently of source-only publication.

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
originals. Web asset parts contain only the exact paths and bytes listed in
`tools/package/web-publication.json`. That list never includes decodes of
original data, and `tools.package.git_boundary` enforces it in the index and in
history after the listed historical parts.

On 16 October 2026 the six earlier versions of `website/dist/play/.generated/remaster-assets-0*.zip`
(published 10 to 15 October, which carried decoded original data) were purged from Git
history on Nell's instruction. Each blob was replaced by a small, valid archive holding only
`REMOVED.txt`, so every commit's paths stay well-formed. Current trees and commit count are
unchanged, and the alpha.5 and alpha.6 tags were rewritten with the branches. GitHub's
read-only `refs/pull/1/head` and `refs/pull/2/head` can still reach the old commits until
GitHub Support removes them.

Working if: `python3 -m tools.package.git_boundary --history` passes, and a Web
session with only PC files derives every `runtime_derived` path locally.

A disclaimer, an ownership check and a free price do not grant redistribution
rights over the original or derived third-party material. No blanket clearance
is claimed. The owner chose public use of the browser assets despite the
unresolved underlying rights. This records her publication decision, not
rights-holder permission or legal clearance. A rights-holder claim remains a
material publication risk.

macOS Alpha 4, Alpha 5 and Alpha 6 are Developer ID signed and notarized, with their tickets stapled (see
[macOS notarization](macos-notarization.md)); earlier alphas were not notarized.
Windows and Linux builds are unsigned. Modern's
consistent 60 fps target and whole-mission human acceptance are still open. Those
limitations appear in the alpha release notes. Corresponding source and dependency
notices accompany the release; archive hashes identify the distributed bytes.

[MIT licence](https://opensource.org/license/mit),
[CC0 legal terms](https://creativecommons.org/publicdomain/zero/1.0/legalcode.en)
and [GPLv2 source-distribution guidance](https://www.gnu.org/licenses/old-licenses/gpl-2.0-faq.html)
provide the governing licence references. This inventory is not legal advice.

On 23 October 2026, the existing authored frontend illustrations and caption
fonts were moved from the optional Genesis Web download set into the common set.
The exact existing asset hashes remain pinned. PC-source proof now selects this
artwork in PC-only sessions; no ROM, original decoded plates, reference captures
or sampled donor audio was added to the publication set. This changes delivery
availability under the existing publication decision, not underlying rights.
