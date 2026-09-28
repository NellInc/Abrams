# Abrams remaster goal

Reconstruct and remaster Dynamix's **Abrams Battle Tank** in Godot, preserving the definitive PC version's gameplay while giving its presentation a faithful high-resolution restoration. Genesis artwork is the primary visual basis wherever available; PC EGA art is reserved for genuine Genesis gaps and for layout/visibility verification. Genesis also supplies music and sound-effect references for later upgrading. Preserve recognizable composition, silhouettes, palette and illustrated character; use extracted resources as evidence and editable sources. Any proposed gameplay departure requires Nell's agreement.

Preserve the PC missions, objectives, controls, crew stations, movement, targeting, ammunition, enemy behaviour, damage, repairs, fuel, difficulty, scoring, campaign progression, timing and meaningful quirks. Add new sound effects and crew voices, clear captions, scalable interfaces and presentation-only accessibility options without changing simulation outcomes or revealing additional tactical information.

Current priority (Nell, 28 September 2026): retain original flat-colour vehicle models. Rejected APC/tank texture panels stay out of live Play; replacement models are deferred. Prioritize complete playable flows, correct existing graphics, sound and TTS before further vehicle beautification.

Completion requires:

1. Fingerprinted, unchanged reference files; documented provenance; a working original-game comparison workflow; and an evidence ledger separating observed behaviour, manual descriptions, inferences and unknowns.
2. Tandem architecture: the original PC executable under pinned emulation owns all gameplay. Godot supplies presentation through a read-only state/drawing bridge and forwards original input. Keep the original renderer running where its work affects gameplay. No parallel replacement simulation or silently invented rules.
3. All eight PC missions and complete briefing, motor-pool, four-station, debriefing, campaign and persistence flows.
4. Cohesive high-resolution graphics grounded in the original assets, upgraded music, new SFX and generative crew voice, adjustable mixes and captions. Extract native samples and music data rather than mixed gameplay recordings. Prefer Gemini 3.8 Flash TTS, with 3.1 Flash TTS as fallback, using character-specific acting direction and suitable vocal cues. Speak bearings digit by digit, including leading zeroes; retain numeric captions. Preserve recognizable musical motifs and cue identities where appropriate; PC events determine playback timing. Retain untouched extracts beside remastered variants and record their source and transformation history.
5. Repeatable original-versus-remaster input traces and state/outcome comparisons, regression tests, and native runtime evidence. Internal consistency alone cannot establish exact parity.
6. A reproducible, playable community release candidate with controls, build instructions, asset provenance and a remaining-differences report. Exclude proprietary source files from distribution. Publishing, uploading, pushing and redistribution decisions require separate explicit authorization.

Continue substantial authorized local research, implementation and validation across milestones. Preserve unrelated work and source material. Maintain a local evidence and work ledger. Keep the goal open until the entire remaster and its parity requirements are proven. An authored calibration range or an initial artwork collection is an intermediate deliverable.
