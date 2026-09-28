# Release rights and dependency review

Reviewed 28 September 2026. **Private development repository. Community release is not cleared.**
This inventory records evidenced provenance and missing decisions; it is not
legal advice or a permission grant. Possession, extraction, a paid generation
account and byte-perfect provenance do not establish redistribution rights.

| Family | Evidence and licence | Package handling / unresolved gate |
|---|---|---|
| Newly written project code | No project licence has been selected. | Private repository and source review kit only. Owner must choose a licence and review compatibility before public distribution. |
| PC game executables, data and native fonts | Supplied original files; exact fingerprints in `tools/package/game-inputs.json`. No redistribution permission found in supplied materials. | Private kit only. No download route or public game bundle. Ownership/use and distribution authorization remain separate. |
| Genesis originals, palette and extracted art/audio | Existing extraction receipts tie outputs to the supplied cartridge. | No ROM or standalone native-audio collection in either kit. Required palette, art donors and music containing derived percussion are private-only. Redistribution permission is unestablished. |
| Genesis/PC-derived remasters and outline fonts | Existing local source hashes, prompts, recognition catalogues and generated-asset receipts. | Private-only, even where a generator produced the final bytes. Underlying art/font rights remain unresolved. |
| Authored frontend score with Genesis percussion | Local `frontend-music-v1` score/asset manifest; the percussion is derived from original Genesis samples. | Private-only exception for this exact runtime directory. Authorship of the score does not clear the donor samples. |
| Synthesized effects and generated speech | `godot/assets/audio/provenance.json` and provider-specific receipts where present; authored effects builder and voice-generation scripts. | All binaries and voice scripts private-only pending ownership, provider terms at generation, voice/casting and final listening review. No inference of clearance from provider provenance. |
| DOSBox Pure, pinned commit `73e03aa...` | Upstream README and source headers state GPL version 2 or later; LICENSE is GPLv2. | Private native dylib only; licence text accompanies it. Before distributing a modified binary, prepare complete corresponding source, modifications, build scripts and notices under applicable GPL terms. Source kit has project patch/build code only and is not a corresponding-source distribution. |
| Godot | MIT licence; engine also includes third-party components. | Not bundled. If bundling later, preserve the engine licence and applicable third-party notices. |
| Python | PSF licence and historical/third-party notices. | Not bundled. A future embedded runtime needs its own matching notice inventory. |
| Pillow | HPND licence, with additional component notices. | Not bundled. A future wheel/runtime bundle must preserve applicable notices. |
| FontTools (outline builder) | MIT, according to upstream LICENSE. | Research/build dependency only, not bundled. Does not grant rights to input game fonts. |
| Unicorn (CPU oracle tooling) | Upstream identifies GPLv2. | Research dependency only, not bundled; separate from DOSBox runtime. |
| Genesis Plus GX (donor extraction) | Upstream licence contains multiple component terms, including noncommercial restrictions. | Research dependency only, excluded from both kits. Never assume DOSBox Pure terms cover it. |
| Blender (vehicle authoring) | Official COPYING identifies the GNU GPL; component terms need a separate inventory if ever bundled. | Optional authoring tool only, not bundled or required by Play. No vehicle-study outputs included. |
| EXEPACK 1.4.0 (independent comparison) | Local COPYING contains a CC0 waiver. | Research binary/source tree excluded. The project's Python unpacker remains in source. |
| Barlow and IBM Plex fonts | SIL Open Font License 1.1, retained beside current font files. | Private kit retains both licence files. These licences do not clear reconstructed original-game fonts. |

Primary sources consulted:

* [DOSBox Pure pinned LICENSE](https://github.com/schellingb/dosbox-pure/blob/73e03aa145e0549ed4d5a20f8e65532714da33f5/LICENSE) and [upstream README](https://github.com/schellingb/dosbox-pure/blob/73e03aa145e0549ed4d5a20f8e65532714da33f5/README.md).
* [Godot engine licence and third-party obligations](https://godotengine.org/license/).
* [Python history and licence](https://docs.python.org/3/license.html).
* [Blender COPYING](https://raw.githubusercontent.com/blender/blender/main/COPYING).
* [FontTools licence](https://github.com/fonttools/fonttools/blob/main/LICENSE), [Unicorn licence declaration](https://www.unicorn-engine.org/), and [Genesis Plus GX component terms](https://github.com/ekeeke/Genesis-Plus-GX/blob/master/LICENSE.txt).
* [Pillow licence](https://pillow.readthedocs.io/en/stable/about.html#license).
* Bundled `godot/assets/fonts/Barlow-OFL.txt` and `Plex-OFL.txt` identify the font-specific terms. Runtime dependency version checks appear in `tools/package_runtime.py`.

## Release gates

Publication needs a deliberate project licensing decision, a rights disposition
for each distributed asset family, a complete dependency/notice and corresponding
source package where required, a supported installation route from legitimate
user inputs, complete gameplay/graphics/audio acceptance, and explicit authority
to publish a particular candidate. None is waived by a successful ZIP build.

The private receipt lists exact bytes but does not claim their rights are cleared.
Generated-material source receipts remain local working evidence. The allowlist
retains installed runtime provenance files; archive hashes make the particular
selected bytes independently auditable. No online upload, release, push, signing
or deployment is performed by these tools.
