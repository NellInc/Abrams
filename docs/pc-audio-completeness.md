# PC audio coverage and machine QA

The finite source audit now accounts for every relative-near-call candidate in
SIM's first 64 KiB code segment targeting the known original sound and message
routines. The fingerprinted original executable is decoded afresh. Unclassified
calls fail the audit. This denominator does not establish the absence of arbitrary
indirect calls elsewhere in the program.

| Source domain | Original coverage | Installed coverage |
|---|---:|---:|
| Sound dispatcher | 30 callsites: 21 sampled, 9 motor/stop | 11 one-shot sample types, 2 source-driven loops |
| Incoming bearing | 256 original byte inputs | 360 digit-wise takes, including 104 supplemental bearings |
| Damage | 24 captions | 24 takes |
| Warning/outcome | 8 captions | 8 takes |
| Scenario, destroyed class and speed | 50 captions from 54 assignments | 50 takes |
| Radio | 7 captions | 7 takes |
| Accepted cannon, smoke and visible READY | 3 qualified event routes | 3 reused authored voices |
| Historical frontend music | 4 source-qualified contexts | 4 local authored arrangements |
| Independent Suno score | Source-qualified frontend, combat, outcome and ending routes | 12 preserved masters, 19 derivatives: 9 loops, 4 stingers, 6 full one-shots |

There are 345 distinct caption strings in the checked original CPU domains and
449 installed PC-caption takes. A further nine shared calibration voices are
installed, three of which have explicit PC event routes. The bank contains 472
export-tree WAVs: 458 voices and 14 effects/loops. The reload effect is retained
for the calibration range; PC READY uses its source-visible voice gate. Four
source-derived local music WAVs remain outside the export tree. The additional
Suno pack is independently authored from text prompts, uses no uploaded game
audio, and stays in `local-audio/suno-score-v1/`; production and the 112-check
focused playback receipt are recorded in `pc-audio-mix.md`.

The 21 original message/radio routing callsites are classified separately from
caption counts. A caption count alone cannot establish that every caller has
been considered. Fresh isolated CPU execution reproduces all six committed
bearing, damage, warning, remaining, radio and additional-request fixtures.
Individual live mission occurrence remains a separate claim.

## Repeatable asset gate

```sh
python3 tools/audit_pc_audio.py --output artifacts/pc-audio-audit.json
python3 -m unittest tests.test_pc_audio_audit
```

The audit measures every installed and local-music WAV: complete 16-bit PCM,
receipt/master SHA-256 custody, sample peak, RMS, full-scale samples, and leading
and trailing silence at a -60 dBFS threshold. Speech starts later than 0.5 seconds
or tails longer than one second are reported as timing advisories. These metrics
are sample-domain measurements; they do not measure LUFS, true peak, subjective
balance or all possible concurrent output combinations.

The 28 September pass found three full-scale samples in the old bearing 182
master. A fresh Gemini 3.8 Flash TTS dry take replaced that installed file only,
after blind transcription and independent individual-digit classification.
Its peak is -1.18 dBFS. The prior dry master remains unchanged; provenance records
its hash and the replacement master. No source game audio or mixed gameplay
recording was uploaded. “Nine” and “niner” remain accepted individual-digit forms.

The runtime now checks sound dispatch IP, exact caller, request value, selected
sample, paired voice and enabled backend before any playback. The Python source
mapping and Godot constants are compared by a regression test. Known sample
names cannot legitimize a wrong original callsite. Existing once-only identity,
stale-batch suppression, source mute, transport mute, restore and shutdown gates
continue to apply. New speech replaces the shared current voice rather than
building a playback queue.

## Remaining boundaries

Briefing/debriefing narration remains unvoiced because the available frontend
text has no complete utterance grouping or interruption identity. Synthesizing
arbitrary visible fragments would introduce narration with weaker source custody.
The frontend arrangements are authored sample-based music, not a reconstruction
of the original Genesis score. Independent human listening, subjective mix
acceptance, per-cue live mission occurrence and redistribution permission are
not claimed by these machine checks.

## Dedicated PC overlap safeguard

Every PC presentation instance owns a separate audio bus containing Godot's
[AudioEffectHardLimiter](https://docs.godotengine.org/en/stable/classes/class_audioeffecthardlimiter.html).
All its existing effect, voice, motor and music players route through that bus.
The ceiling is -1 dB, pre-gain is 0 dB and release is 100 ms. Player/category
levels remain unchanged. The shared Master bus and calibration audio remain
untouched; scene teardown removes only the instance's own bus.

`test_pc_audio_limiter.gd` exercises actual Godot bus processing using newly
synthesized PCM, with
[AudioEffectCapture](https://docs.godotengine.org/en/stable/classes/class_audioeffectcapture.html)
before and after the limiter. No game recording is made. Eight overlapping
synthetic effects plus one synthetic voice produce a 2.912 pre-effect peak;
the protected peak is 0.891261, with zero full-scale frames. The measured added
onset delay is 2.04 ms and the added stop tail is 1.86 ms at 44.1 kHz, both below
the test's 15 ms bound. Tests also prove bus isolation, routing and teardown.

These are Dummy-driver mixer measurements on the pinned Godot runtime, rather
than hardware round-trip latency, an inter-sample true-peak proof or a human
intelligibility assessment. The limiter provides sample-domain overload protection
for the PC bus. Unrelated downstream gain and simultaneous external audio are
outside that guarantee.


## Optional private recording bank, 25 October 2026

The native PC audio player can preload a six-cue bank from
`local-audio/pc-recorded-effects-v1/manifest.json`. The manifest has schema 1,
kind `private authored recording effects`, and a `cues` dictionary containing
exactly `cannon`, `machinegun`, `impact`, `smoke`, `engine` and `turret`. Each entry
names its fixed `cue.wav` file and SHA-256. Files must decode to 48 kHz, mono,
16-bit PCM with the incumbent frame counts: 115,200, 10,560, 134,400, 62,400,
96,000 and 96,000 respectively. Manifest and file sizes are bounded before
reading or decoding. An absent bank uses stock audio; an invalid bank warns
once per player and retains the complete stock bank, including when the last
file fails. Bank errors do not replace source-event validation failures.

Crew voices, music, unknown request identities, event IDs, source onset and
cadence, audibility, limiter settings, pause/mute/checkpoint rules and motor
pitch/amplitude remain on the existing paths. Shot streams explicitly disable
embedded loops. Engine and turret loop over their complete verified PCM;
source events still own their playback parameters. Private streams are released
with the existing shutdown drain. Web returns before private-bank discovery.

The existing audio check passes 924 checks, including disposable generated
fixtures for valid loading, atomic fallback, malformed format/duration and
shutdown. This verifies the loader contract. The actual balanced recording bank was
subsequently installed and accepted; see "Installed recordings through original
source events" below. Equal file duration alone does not establish transient
alignment, seamless loops, loudness balance or an acceptable in-game mix.

Licensed originals and derivatives must remain private. The bank is absent
from the packaging allowlist, and `package_build.py` rejects its directory even
for private review kits. No packaging permission is granted by loader support.
Any later outgoing artifact must be inspected for private filenames/hashes.
Existing stock WAVs remain the recovery source. Evidence:
`artifacts/tactical-postdelivery-20261025/private-audio-final-test.log`.

Working if: valid local PCM replaces only the six effects, invalid or absent
banks retain stock playback, source contracts and voices remain unchanged,
and no private recordings appear in a source or distributable review artifact.

## Individual sound options (25 October 2026)

The Audio menu and Settings panel now expose Cannons, Machine gun, Impacts,
Smoke, Engine and Turret, each from Off to 100%. They multiply the existing
master/group gain; all six default to 100%, preserving the incumbent mix.
Crew voices and music retain their separate controls. Preferences persist,
including individual mute and intermediate integer percentages. Old configs
receive 100% cue defaults; legacy four/five-channel API updates retain any
individual choices already made.

Live shot gain changes use the cue of each active player. Muting one cue stops
only that cue; restoring its gain cannot replay a consumed shot. Motor gains
multiply the original source amplitude without changing source pitch, events
or clocks. Only a source-active motor can resume, and original/transport mute
still wins. Motor unmute restarts the sample, as the existing group mute did.
The practice range uses the same individual settings.

Focused checks: PC_AUDIO 924, PC_AUDIO_MIX 262, PC_AUDIO_LIMITER 33,
PC_PLAY_MENU 326 and PC_FRONTDOOR 63, all passing. Base audio samples load,
and the live settings script parses. These are machine checks; native panel
interaction/layout acceptance remains pending a coordinated runtime window.
Browser HTML/JavaScript exposes the same six keys but requires a matching
rebuilt Godot pack before publication. No web or standalone rebuild occurred.
The optional UI detector is not installed; no dependency was added for it.

Nell accepted the balanced-v3 recording preview as a single MG shot with clean
motor sections and said it sounds okay. This qualifies preview listening only.
The private bank remains absent pending matched renderer qualification and
actual in-game mix verification. No stock WAV or crew/music asset was changed.

Working if: each cue can be reduced or muted without changing another cue or
source authority, choices survive restart, defaults retain the original mix,
and native/browser delivery claims require their applicable runtime evidence.

### Native completion and private integration, 25 October 2026

The native in-game Settings-only check now passes 33 checks with zero errors.
Wide, compact and scrolled individual-control screenshots were inspected;
engine 0%, cannon 40% and turret 40% reached the corresponding practice gains.
User audio/graphics preferences remained absent and unchanged; test choices
were saved only under the isolated output directory. This is automated native
UI proof, separate from manual menu navigation and listening.

After the two fixed native windows closed, the approved balanced-v3 six-file
bank was atomically installed privately at local-audio/pc-recorded-effects-v1.
The production loader accepts all six actual clips, and the installed-bank mix
check passes 262 checks. Original stock assets, licensed originals and accepted
preview packs remain recoverable. Actual in-game recorded mix/listening is
still open. The bank must be reversibly excluded for a future bank-absent
renderer comparison. No paid audio is tracked, packaged, rebuilt or published.

Working if: native controls reach the correct gains without changing user
preferences during QA, the private loader accepts all six actual recordings,
and installed-bank tests are not mislabelled as device or in-game listening.

### Installed recordings through original source events

A CPU-only original-core run now exercises 1,712 guest frames and 128 source
events through the installed bank and production Godot mixer: zero event
errors, 3,426 loop checks, two audible cannon shots, one MG, one smoke, one
impact, one source-muted cannon and all four F5/pause gate events. Crew barks
and four original engine periods are retained. Post-limiter PCM measures
-6.8 dB true peak with no full-scale samples. Two long exact-zero PCM runs
correspond in order to the two source mute intervals.

The Dummy-driver recording clock differs from logged wall offsets on this
loaded host. A first wall-offset silence assertion failed and was discarded;
no exact temporal alignment or device-latency claim is made. The full private
recording is 180.094 seconds; a 32.5-second excerpt is offered for human crew
clarity and balance review. Only 10 ms excerpt-edge fades were applied, with
no gameplay asset, gain or pitch edits. Nell accepted this mix: “Crew clear, balance comfortable.”
No further level or asset changes were made after that feedback.
Evidence: artifacts/tactical-audio-options-20261025/original-mix/.

Working if: actual source event/motor/gate checks pass with the installed bank,
the mix retains headroom, and recorded proof and human clarity judgment remain
distinct from healthy-host cadence or device acceptance.


## Whole-game source acquisition inventory (26 October 2026)

**89 cue roles; 539 free audio files from 49 sources/packs; four previously licensed Abrams recordings. New spending: US$0.**

The six accepted effects and their saved volume controls remain unchanged. Everything else below is obtained source stock or preserved existing material. Rows describe cue/component roles, with several reusing a source library. Representative files are un-auditioned source examples. No new playback triggers were added. New source stock needs take selection, editing where appropriate, and source-qualified integration before it becomes game audio.

## Detailed cue list

**LIVE**: accepted installed effect. **STOCK**: obtained material, uninstalled. **KEEP**: existing route/assets preserved. Gates: **P** original qualified sound event; **M** original motor/motion authority; **V** verified visible ownership including occlusion; **A** verified original action; **F** actual frontend action; **R** reserve until action/scene identity is established.

### 01 Weapons and accepted effects

| Cue | Intended character | Obtained material | State and binding |
|---|---|---|---|
| Main cannon attack, body and decay | Single original shot, low-frequency body and natural decay. Accepted recording edit remains unchanged. | [M1 Abrams Military Tank Distant Cannon Blast](https://www.prosoundeffects.com/sound-effects/PSE_KCV1/PYt7L/m1-abrams-military-tank-distant-cannon-blast) | **LIVE / P**. Installed and human accepted; private. |
| Machine-gun report | One apparent round per original event. Preserve the accepted transient and exact original cadence. | [M1 Abrams Military Tank Machine Gun Blasts 01](https://www.prosoundeffects.com/sound-effects/PSE_KCV1/UvgL2/m1-abrams-military-tank-machine-gun-blasts-01) | **LIVE / P**. Installed and human accepted; private. |
| Smoke launch pressure and hiss | Short launch pressure with a restrained hiss. Existing accepted edit retained. | [oga-steam-release-sounds](https://opengameart.org/content/steam-release-sounds); Project-authored synthesis and accepted sweeteners (project source) | **LIVE / P**. CC0/authored construction; no dedicated Abrams smoke-launcher recording claimed. |
### 02 Abrams running gear and motors

| Cue | Intended character | Obtained material | State and binding |
|---|---|---|---|
| Abrams turbine idle and load texture | Grounded turbine idle/load body, with original source pitch and amplitude authority. | [M1 Abrams Military Tank Engine Idle Whine](https://www.prosoundeffects.com/sound-effects/PSE_KCV1/boejC/m1-abrams-military-tank-engine-idle-whine); [M1 Abrams Tank Drive Int](https://www.prosoundeffects.com/sound-effects/PSE_AAC/PUOZV/m1-abrams-tank-drive-int) | **LIVE / M**. Installed and human accepted; no raw loop-level increases. |
| Hull and equipment rattle | Short, irregular metal jingle, kept well below speech. | [M1 Abrams Tank Drive Int](https://www.prosoundeffects.com/sound-effects/PSE_AAC/PUOZV/m1-abrams-tank-drive-int); [Medium chain](https://bigsoundbank.com/medium-chain-s0619.html) | **STOCK / M**. Additional source take selection pending; no blind use of loud raw motor files. |
| Onboard engine and mechanical hull detail | Onboard drive texture and restrained hull resonance. | [M1 Abrams Tank Drive Int](https://www.prosoundeffects.com/sound-effects/PSE_AAC/PUOZV/m1-abrams-tank-drive-int) | **STOCK / M**. Licensed source obtained. Additional isolated edits require selection/listening; no extra runtime layer installed. |
| Suspension-like creak component | Small mechanical creaks for sparse chassis detail. | [oga-wood-and-metal-sound-effects-volume-2](https://opengameart.org/content/wood-and-metal-sound-effects-volume-2); [oga-100-cc0-metal-and-wood-sfx](https://opengameart.org/content/100-cc0-metal-and-wood-sfx) | **STOCK / R**. Generic Foley, not an actual Abrams suspension recording. |
| Recorded running-gear detail | Running-gear clatter and rough metal detail under verified movement. | [M1 Abrams Tank Drive Int](https://www.prosoundeffects.com/sound-effects/PSE_AAC/PUOZV/m1-abrams-tank-drive-int); [Heavy chain](https://bigsoundbank.com/heavy-chain-s0359.html); [Medium chain](https://bigsoundbank.com/medium-chain-s0619.html) | **STOCK / V**. Abrams onboard source plus generic chain components; dedicated track-only take not established. |
| Gravel running-gear texture | Restrained granular contact layer rather than louder engine sound. | [oga-42-snow-and-gravel-footsteps](https://opengameart.org/content/42-snow-and-gravel-footsteps); [M1 Abrams Tank Drive Int](https://www.prosoundeffects.com/sound-effects/PSE_AAC/PUOZV/m1-abrams-tank-drive-int) | **STOCK / R**. Gravel Foley is a design component; no existing track/surface classifier is assumed. |
| Heavy link rattle component | Low irregular metal clatter with controlled ringing. | [Heavy chain](https://bigsoundbank.com/heavy-chain-s0359.html); [Medium chain](https://bigsoundbank.com/medium-chain-s0619.html) | **STOCK / M**. Real chain recordings, not tank-track field recordings. |
| Track rolling body | Steady onboard running-gear bed, restrained beneath the turbine. | [M1 Abrams Tank Drive Int](https://www.prosoundeffects.com/sound-effects/PSE_AAC/PUOZV/m1-abrams-tank-drive-int) | **STOCK / M**. Recording obtained; no separately isolated track-only edit is claimed. |
| Turret hydraulics and gear body | Motor/hydraulic whine and restrained gear body, active only when the source motor is active. | [M1 Abrams Military Tank Engine Idle Whine](https://www.prosoundeffects.com/sound-effects/PSE_KCV1/boejC/m1-abrams-military-tank-engine-idle-whine); [oga-chain-winch-sounds](https://opengameart.org/content/chain-winch-sounds) | **LIVE / M**. Installed and human accepted; additional winch textures are generic components. |
### 03 Hatches and mechanical actions

| Cue | Intended character | Obtained material | State and binding |
|---|---|---|---|
| Air-pump motor body | Low machinery/pump component for a verified matching action. | [Air compressor](https://bigsoundbank.com/air-compressor-s1487.html) | **STOCK / R**. Small electric compressor recording; not an Abrams turbine or hydraulic motor. |
| Pressure and air-release textures | Pressure and air-release textures | [oga-steam-release-sounds](https://opengameart.org/content/steam-release-sounds) | **STOCK / P**.  |
| Breech-closing component | A single heavy closure, without repeated bangs. | [Metal box lid](https://bigsoundbank.com/metal-box-lid-s0053.html); [Lock and big key](https://bigsoundbank.com/lock-and-big-key-s0378.html) | **STOCK / R**. Generic recorded components; original READY timing and crew voice remain authoritative. |
| Breech-opening component | Dry latch release and small metal movement. | [Lock and big key](https://bigsoundbank.com/lock-and-big-key-s0378.html); [oga-100-cc0-metal-and-wood-sfx](https://opengameart.org/content/100-cc0-metal-and-wood-sfx) | **STOCK / R**. No dedicated Abrams breech take or automatic-loader mechanism is claimed. |
| Latches, metal openings and closings | Heavy but restrained latch, lid and hinge components. | [Metal box lid](https://bigsoundbank.com/metal-box-lid-s0053.html); [Lock and big key](https://bigsoundbank.com/lock-and-big-key-s0378.html); [Metal barrier: Opening #1](https://bigsoundbank.com/grinding-metal-barrier-opening-1-s2355.html); [Metal Barrier: Closure #2](https://bigsoundbank.com/grinding-metal-barrier-closure-2-s2359.html) | **STOCK / A**. Generic recorded components; no exact Abrams hatch recording or original hatch event is claimed. |
| Heavy lid closure | One controlled closure with a short body. | [Metal box lid](https://bigsoundbank.com/metal-box-lid-s0053.html); [Metal Barrier: Closure #2](https://bigsoundbank.com/grinding-metal-barrier-closure-2-s2359.html) | **STOCK / R**. Generic recorded components, not a tank hatch field recording. |
| Heavy lid opening | Metal movement with a brief hinge character. | [Metal box lid](https://bigsoundbank.com/metal-box-lid-s0053.html); [Metal barrier: Opening #1](https://bigsoundbank.com/grinding-metal-barrier-opening-1-s2355.html) | **STOCK / R**. Recorded lid/gate components; no unrelated station-switch or keypress binding. |
| Heavy latch release | A short, close latch click and release. | [Lock and big key](https://bigsoundbank.com/lock-and-big-key-s0378.html) | **STOCK / R**. Actual large-lock recording, not an Abrams-specific latch. |
| Loader equipment handling component | Small equipment handling and restrained metal jingle. | [oga-100-cc0-metal-and-wood-sfx](https://opengameart.org/content/100-cc0-metal-and-wood-sfx); [M1 Abrams Tank Drive Int](https://www.prosoundeffects.com/sound-effects/PSE_AAC/PUOZV/m1-abrams-tank-drive-int) | **STOCK / R**. Additional take isolation/listening pending; do not imply an automatic loader. |
| Pressure-release decay | Soft pressure tail to complement an existing qualified discharge. | [oga-steam-release-sounds](https://opengameart.org/content/steam-release-sounds) | **STOCK / P**. Steam component; no real Abrams smoke-launcher identity claimed. |
| Recoil mechanical component | One dull mechanical punctuation within a single accepted shot. | [oga-wood-and-metal-sound-effects-volume-2](https://opengameart.org/content/wood-and-metal-sound-effects-volume-2); [Metal box lid](https://bigsoundbank.com/metal-box-lid-s0053.html) | **STOCK / P**. Generic component only. The current accepted cannon clip is unchanged. |
| Mechanical reload parts | Dry breech/latch/loading components, with one coherent mechanical action. | [Metal box lid](https://bigsoundbank.com/metal-box-lid-s0053.html); [Lock and big key](https://bigsoundbank.com/lock-and-big-key-s0378.html); [oga-100-cc0-metal-and-wood-sfx](https://opengameart.org/content/100-cc0-metal-and-wood-sfx) | **STOCK / P**. Generic components. Original PC READY voice remains unchanged; calibration or verified reload action only. |
### 04 Contacts, impacts and destruction

| Cue | Intended character | Obtained material | State and binding |
|---|---|---|---|
| Armour hit body and metallic detail | Heavy strike body and metallic detail, without a second apparent gunshot. | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds); [oga-wood-and-metal-sound-effects-volume-2](https://opengameart.org/content/wood-and-metal-sound-effects-volume-2); Project-authored synthesis and accepted sweeteners (project source) | **LIVE / P**. Accepted generic impact retained; new free materials are uninstalled alternatives, not actual shell-strike recordings. |
| Earth, gravel and stone fragments | Earth, gravel and stone fragments | [oga-42-snow-and-gravel-footsteps](https://opengameart.org/content/42-snow-and-gravel-footsteps); Project-authored synthesis and accepted sweeteners (project source) | **STOCK / P**. Recorded gravel can be edited as a design layer; it is not a recorded shell impact. |
| Glass break textures | Break attack plus lighter shard tail, with no exaggerated cinematic explosion. | [A Mirror Explodes](https://bigsoundbank.com/mirror-explodes-s0387.html); [Broken glass](https://bigsoundbank.com/broken-glass-s0771.html); [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | **STOCK / P**. Real mirror-break and Foley sources obtained; explicitly saturated Glass Burst remains excluded. |
| Glass shard tail | Light brittle debris after one verified break. | [A Mirror Explodes](https://bigsoundbank.com/mirror-explodes-s0387.html); [Broken glass](https://bigsoundbank.com/broken-glass-s0771.html) | **STOCK / P**. Keep this a tail of one event, not a separate tactical cue. |
| Dull ground-contact body | Small dry low-mid contact body. | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | **STOCK / P**. Designed impact library; surface identity must be established before classification. |
| Metal clanks, ringing and falling fragments | Metal clanks, ringing and falling fragments | [oga-100-cc0-metal-and-wood-sfx](https://opengameart.org/content/100-cc0-metal-and-wood-sfx); [oga-metal-clang-sounds](https://opengameart.org/content/metal-clang-sounds) | **STOCK / P**.  |
| Metal resonance tail | Restrained ringing after a qualified strike. | [oga-metal-clang-sounds](https://opengameart.org/content/metal-clang-sounds); [oga-wood-and-metal-sound-effects-volume-2](https://opengameart.org/content/wood-and-metal-sound-effects-volume-2) | **STOCK / P**. Generic metal, not measured armour resonance. |
| Metal scrape component | Short rough friction, without continuous scraping spam. | [oga-100-cc0-metal-and-wood-sfx](https://opengameart.org/content/100-cc0-metal-and-wood-sfx); [oga-wood-and-metal-sound-effects-volume-2](https://opengameart.org/content/wood-and-metal-sound-effects-volume-2) | **STOCK / R**. Component selection pending; no collision or contact simulator added. |
| Stone and small debris | Hard contact and small falling fragments. | [Fall of Stone](https://bigsoundbank.com/fall-of-stone-s1022.html) | **STOCK / P**. Actual stone-fall recording, not a live shell impact. |
| Wood crack and splinter component | Dry cracking with a lighter splinter tail. | [oga-wood-and-metal-sound-effects-volume-2](https://opengameart.org/content/wood-and-metal-sound-effects-volume-2); [Broken twigs #1](https://bigsoundbank.com/broken-twigs-1-s1299.html); [Broken twigs #2](https://bigsoundbank.com/broken-twigs-2-s1300.html) | **STOCK / P**. Twig and wood recordings/components must not imply a larger structure than the visible event. |
| Wood breaks, splinters and structural creaks | Wood breaks, splinters and structural creaks | [oga-100-cc0-metal-and-wood-sfx](https://opengameart.org/content/100-cc0-metal-and-wood-sfx); [oga-wood-and-metal-sound-effects-volume-2](https://opengameart.org/content/wood-and-metal-sound-effects-volume-2) | **STOCK / P**.  |
### 05 Rivers and water

| Cue | Intended character | Obtained material | State and binding |
|---|---|---|---|
| Stream and broader flowing-river bed | Quiet stream and broader flowing-water beds with useful looping material. | [Small Stream #4](https://bigsoundbank.com/small-stream-4-s1354.html); [Watercourse 5.2](https://bigsoundbank.com/watercourse-5-2-s3137.html) | **STOCK / V**. Recorded sources obtained. River source ownership and audio eligibility must be verified before integration. |
| Riverbank lapping and small waves | Riverbank lapping and small waves | [oga-sea-and-river-wave-sounds](https://opengameart.org/content/sea-and-river-wave-sounds) | **STOCK / V**. Recorded on the Vistula; choose a calm matching section. |
| Small river ripple and bank waves | A quieter small-wave layer under a visible river. | [oga-sea-and-river-wave-sounds](https://opengameart.org/content/sea-and-river-wave-sounds) | **STOCK / V**. Vistula recording; final looping and take selection pending. |
| Water splash texture | Water splash texture | [Splash, Big #3](https://bigsoundbank.com/splash-big-3-s1521.html) | **STOCK / P**. Actual source is a stone dropped into a water tank. Do not invent a vehicle-water entry event. |
| Larger splash component | Heavier water contact only for a verified suitable event. | [Splash, Big #3](https://bigsoundbank.com/splash-big-3-s1521.html) | **STOCK / R**. Original source uses a stone in a water tank, not an Abrams crossing. |
| Small shallow splash | A brief small contact splash, with a short water tail. | [Splash, Small #1](https://bigsoundbank.com/splash-small-1-s1529.html) | **STOCK / R**. Source is a recorded small splash; no invented vehicle-entry event. |
### 06 Countryside, foliage and fire

| Cue | Intended character | Obtained material | State and binding |
|---|---|---|---|
| Common blackbird call | Occasional natural bird phrases, never a constant loop. | [Common Blackbird #30](https://bigsoundbank.com/common-blackbird-30-s3503.html) | **STOCK / R**. Provider identifies common blackbird; season and source-qualified environment must match. |
| Small branch/twig snap | Dry small branch break, appropriate to a verified visible event. | [Broken twigs #1](https://bigsoundbank.com/broken-twigs-1-s1299.html); [Broken twigs #2](https://bigsoundbank.com/broken-twigs-2-s1300.html) | **STOCK / R**. Do not simulate unobserved movement or vegetation contact. |
| Birds, insects and country ambience | Sparse temperate-country bird detail, with plenty of quiet. | [Countryside](https://bigsoundbank.com/countryside-s0097.html); [Common Blackbird #30](https://bigsoundbank.com/common-blackbird-30-s3503.html); [Carrion Crow #4](https://bigsoundbank.com/carrion-crow-4-s3464.html) | **STOCK / R**. Recordings obtained; choose suitable seasons/scenes and audition for wind/unwanted background sound. |
| Carrion-crow call | Rare natural calls with long quiet gaps. | [Carrion Crow #4](https://bigsoundbank.com/carrion-crow-4-s3464.html) | **STOCK / R**. Species-specific source available; no invisible animal cue binding. |
| Sparse country bird bed | Low, intermittent temperate-country birds. | [Countryside](https://bigsoundbank.com/countryside-s0097.html) | **STOCK / R**. Scene/season eligibility and unwanted background noise require selection; no bird actor is invented. |
| Visible burning-wreck fire body | Visible burning-wreck fire body | [Big Branching Fire #1](https://bigsoundbank.com/big-branching-fire-1-s0987.html); [oga-fire-crackling](https://opengameart.org/content/fire-crackling) | **STOCK / V**. No new offscreen target or damage information. |
| Burning-object crackle detail | Sparse close crackles, with adequate quiet. | [oga-fire-crackling](https://opengameart.org/content/fire-crackling) | **STOCK / V**. No new offscreen damage or wreck information. |
| Burning-object fire body | Low fire body for a legitimately visible burning object. | [Big Branching Fire #1](https://bigsoundbank.com/big-branching-fire-1-s0987.html) | **STOCK / V**. Recorded branch fire, not a recording of a burning tank. |
| Dry foliage rustles | Dry foliage rustles | [oga-20-rustles-dry-leaves](https://opengameart.org/content/20-rustles-dry-leaves) | **STOCK / V**. Recorded leaf Foley, not a new vegetation-contact simulator. |
| Tree and branch creaks | Tree and branch creaks | [Wind and tree squeaks](https://bigsoundbank.com/wind-and-tree-squeaks-s1051.html) | **STOCK / V**.  |
| Open-field wind and grass | Open-field wind and grass | [Wind in Tall Grass](https://bigsoundbank.com/wind-in-tall-grass-s0908.html) | **STOCK / V**.  |
| Wind through trees | Wind through trees | [Wind in the Trees](https://bigsoundbank.com/forest-wind-in-the-trees-s0904.html) | **STOCK / V**. Recorded in a French forest; retain a geographically suitable selection. |
### 07 Farm detail

| Cue | Intended character | Obtained material | State and binding |
|---|---|---|---|
| Farm cow moos and natural variations | Occasional natural moo variations, avoiding a repetitive farm loop. | [Cow Moos #6](https://bigsoundbank.com/cow-moos-6-s2386.html); [Cow Moos #1](https://bigsoundbank.com/cow-moos-s0546.html) | **STOCK / V**. Real cow recordings obtained; only a verified, legitimately visible cow may qualify a future cue. |
| Farm metal gate closure | One restrained gate closure. | [Metal Barrier: Closure #2](https://bigsoundbank.com/grinding-metal-barrier-closure-2-s2359.html) | **STOCK / R**. Actual barn-barrier recording; remains stock until an original action is verified. |
| Farm metal gate opening | Low metal hinge/grind for an actual matching action. | [Metal barrier: Opening #1](https://bigsoundbank.com/grinding-metal-barrier-opening-1-s2355.html) | **STOCK / R**. Actual barn-barrier recording; no new door interaction invented. |
### 08 Other visible vehicles

| Cue | Intended character | Obtained material | State and binding |
|---|---|---|---|
| Rotor and flyby material | Rotor and flyby material | [Helicopter #2](https://bigsoundbank.com/helicopter-2-s0264.html); [Helicopter (Transition)](https://bigsoundbank.com/helicopter-transition-s0113.html) | **STOCK / V**. Exact helicopter type is unverified, so no claim of a recorded Mi-24. Loopability needs editing. |
| Helicopter flyby component | A restrained pass for an observed source actor. | [Helicopter (Transition)](https://bigsoundbank.com/helicopter-transition-s0113.html) | **STOCK / V**. Recorded stereo path cannot create new positional information; source matching or neutral rendering required. |
| Helicopter rotor body | Rotor rhythm appropriate to a verified visible helicopter. | [Helicopter #2](https://bigsoundbank.com/helicopter-2-s0264.html) | **STOCK / V**. Exact helicopter model is unverified; no Mi-24 authenticity claim. |
| Generic military jet flyby | Short recorded jet flyby derivative, with restrained level. | [Jet flyby, AltSFX59 recording derivative](https://github.com/ALEX11BR/AltSFX) | **STOCK / V**. Free CC-BY3.0 derivative obtained at44.1kHz/16bit mono. Exact aircraft unverified; not labelled MiG. |
| Jet-flyby recording derivative | Short restrained flyby with required attribution. | [Jet flyby, AltSFX59 recording derivative](https://github.com/ALEX11BR/AltSFX) | **STOCK / V**. CC-BY3.0 derivative,44.1kHz/16bit mono. Exact airframe is not verified. |
| Generic truck idle/reversing body | Stationary diesel body and restrained load changes. | [Truck Engine #2](https://bigsoundbank.com/truck-engine-2-s1443.html); [Truck engine #1](https://bigsoundbank.com/truck-engine-1-s1442.html); [Truck engine, small accelerations](https://bigsoundbank.com/truck-engine-small-accelerations-s1146.html) | **STOCK / V**. Generic truck and identified Iveco Daily source; no Cold-War military-model accuracy claim. |
| Stationary truck engine | Restrained stationary diesel body. | [Truck engine #1](https://bigsoundbank.com/truck-engine-1-s1442.html); [Truck Engine #2](https://bigsoundbank.com/truck-engine-2-s1443.html) | **STOCK / V**. Generic model; do not use it for the Abrams turbine. |
| Truck acceleration/load texture | Small diesel load changes and acceleration body. | [Truck engine, small accelerations](https://bigsoundbank.com/truck-engine-small-accelerations-s1146.html) | **STOCK / V**. Identified Iveco Daily3.0 recording, not a verified original-game military-truck model. |
### 09 Switches and radio

| Cue | Intended character | Obtained material | State and binding |
|---|---|---|---|
| Radio squelch/static texture | Radio squelch/static texture | [Crackling Radio #2](https://bigsoundbank.com/crackling-radio-2-s0313.html) | **STOCK / P**. Retain existing attention signal and all crew speech; inspect candidate for unwanted broadcast voices before use. |
| Radio open/close texture | Short restrained contact/noise edges, without new speech. | [Crackling Radio #2](https://bigsoundbank.com/crackling-radio-2-s0313.html); [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) | **STOCK / P**. Design components rather than a dedicated squelch field recording. Preserve message onsets and intelligibility. |
| Radio static component | Very low static beneath a qualified radio event. | [Crackling Radio #2](https://bigsoundbank.com/crackling-radio-2-s0313.html) | **STOCK / P**. Audition for unwanted voices/broadcasts; accepted crew speech stays unchanged. |
| Switch or control click | Switch or control click | [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds); [oga-equipment-click](https://opengameart.org/content/equipment-click) | **STOCK / P**.  |
| Heavy industrial switch | A short, tactile, substantial switch. | [Industrial switch #1](https://bigsoundbank.com/industrial-switch-1-s3061.html) | **STOCK / R**. Real industrial-switch recording; no hidden or newly invented combat feedback. |
| Small mechanical switch | A quiet close click. | [Old switch](https://bigsoundbank.com/old-switch-s0540.html); [oga-equipment-click](https://opengameart.org/content/equipment-click) | **STOCK / R**. Original qualified action or actual frontend action only. |
### 10 Frontend interface

| Cue | Intended character | Obtained material | State and binding |
|---|---|---|---|
| Confirm | Confirm | [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) | **STOCK / F**. No new source gameplay confirmation or input-derived combat sounds. |
| Back/cancel | Back/cancel | [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) | **STOCK / F**. No new source gameplay confirmation or input-derived combat sounds. |
| Error | Error | [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) | **STOCK / F**. No new source gameplay confirmation or input-derived combat sounds. |
| Panel open/close | Panel open/close | [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) | **STOCK / F**. No new source gameplay confirmation or input-derived combat sounds. |
| Toggle | Toggle | [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) | **STOCK / F**. No new source gameplay confirmation or input-derived combat sounds. |
### 11 Weather reserves

| Cue | Intended character | Obtained material | State and binding |
|---|---|---|---|
| Rain on ground and puddles | Rain on ground and puddles | [Rain on Puddle](https://bigsoundbank.com/rain-on-puddle-s1290.html) | **STOCK / R**. Do not add rain to clear-weather original scenes. |
| Isolated thunder | Isolated thunder | [Thunder #4](https://bigsoundbank.com/thunder-4-s3115.html) | **STOCK / R**. No arbitrary weather simulation or random artillery-like cues. |
### 12 Contact and firearm reserves

| Cue | Intended character | Obtained material | State and binding |
|---|---|---|---|
| Gravel and snow contacts | Gravel and snow contacts | [oga-42-snow-and-gravel-footsteps](https://opengameart.org/content/42-snow-and-gravel-footsteps) | **STOCK / R**.  |
| Grass, concrete and wood contacts | Grass, concrete and wood contacts | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | **STOCK / R**.  |
| Recorded pistol-shot reserve | Actual prepared pistol recordings, held as reserve. | [The Free Firearm Sound Library, prepared collection](https://opengameart.org/content/the-free-firearm-sound-library) | **STOCK / R**. No current original PC pistol event is established. |
| Recorded rifle-shot reserve | Actual prepared rifle recordings for any later verified matching use. | [The Free Firearm Sound Library, prepared collection](https://opengameart.org/content/the-free-firearm-sound-library) | **STOCK / R**. AK-47,AR-15,SKS and other identified folders; never substitute blindly for Abrams cannon or machine gun. |
| Recorded submachine-gun reserve | Actual prepared M45/PPSh recordings, held as reserve. | [The Free Firearm Sound Library, prepared collection](https://opengameart.org/content/the-free-firearm-sound-library) | **STOCK / R**. Different weapons from the installed Abrams MG; no automatic replacement. |
### 13 Unclassified original requests

| Cue | Intended character | Obtained material | State and binding |
|---|---|---|---|
| Original request 07 | Original request 07 | Existing source-qualified original request samples (project source) | **KEEP / P**. Semantic identity remains unverified. Do not relabel as cow, jet, missile or damage by guesswork. |
| Original request 09 | Original request 09 | Existing source-qualified original request samples (project source) | **KEEP / P**. Semantic identity remains unverified. Do not relabel as cow, jet, missile or damage by guesswork. |
| Original request 10 | Original request 10 | Existing source-qualified original request samples (project source) | **KEEP / P**. Semantic identity remains unverified. Do not relabel as cow, jet, missile or damage by guesswork. |
| Original request 15 | Original request 15 | Existing source-qualified original request samples (project source) | **KEEP / P**. Semantic identity remains unverified. Do not relabel as cow, jet, missile or damage by guesswork. |
| Original request 16 | Original request 16 | Existing source-qualified original request samples (project source) | **KEEP / P**. Semantic identity remains unverified. Do not relabel as cow, jet, missile or damage by guesswork. |
### 14 Preserved voices and music

| Cue | Intended character | Obtained material | State and binding |
|---|---|---|---|
| Existing crew voices, radio and source captions | Existing crew voices, radio and source captions | Existing installed crew and original-caption voices (project source) | **KEEP / P**. No stock replacement, new words, changed onsets or lost intelligibility. |
| Existing authored score and music transport | Existing authored score and music transport | Existing authored music banks (project source) | **KEEP / P**. Preserve music assets, order, ducking, pause, restore and mute rules. |

## Licence, authenticity and use boundaries

* CC0 material can form the free-first source bank; provider pages and available archive licence notes are retained.
* The AltSFX jet derivative requires CC-BY3.0 attribution. Its underlying recording is credited to qubodup; the derivative is not relabelled CC0.
* The four purchased Abrams originals and the accepted private bank remain local and recoverable. Their raw/edited stock does not enter public Git or packaging.
* Generic chain, lid, lock, compressor, twig and glass components are labelled as such. They are not represented as recordings of specific Abrams mechanisms, shell strikes or smoke launchers.
* The diesel acceleration source is an Iveco Daily recording. Helicopter and jet airframes remain unverified. These are stock sources, without claims of original-game model accuracy.
* One original shot must remain one apparent shot. Voices/music, event cadence, source motor authority, mute/pause/checkpoint gates and the limiter are preserved.
* New actor sounds require verified visible source ownership, including occlusion. Weather/walking/mechanical events stay reserved until established. Unclassified original requests remain unclassified.

## Organisation and next selection order

1. Keep the accepted cannon/MG/impact/smoke/engine/turret clips and current gains.
2. Select quiet river, wind, cow and visible-fire material, with appropriate source/scene qualification.
3. Select subtle running-gear, hull and mechanical components, avoiding repetitive ringing or continuous rattling.
4. Qualify other vehicles against actual visible source identities; retain model limitations.
5. Consider short frontend clicks. Weather, footsteps and unrelated firearm models remain reserves.

Existing six per-effect Off-to100% controls remain in place. Ambience and Mechanical Detail are proposed future group controls, not implemented by this sourcing pass.

## Files

* Machine-readable cue list: `artifacts/world-sfx-20261026/cue-inventory.csv`.
* Every free file, hash, format, duration and licence: `artifacts/world-sfx-20261026/asset-inventory.csv`.
* Full catalogue and source links: `artifacts/world-sfx-20261026/catalogue.json`.
* Category playlists, with no duplicate media copies: `local-audio/world-sfx-20261026/collections/`.
* Provenance and verification: `artifacts/world-sfx-20261026/verification.json` and `pages/`.

Working if: every listed acquisition has a verified local file and rights record, the existing mix remains byte-identical, and acquired stock is clearly distinguished from installed or subjectively accepted audio.

## Authentic Hind and Soviet vehicle supplement (26 October 2026)

Nell requested actual Hind and Soviet tank recordings after the general stock
inventory. Three free, attribution-licensed field-video soundtracks have now
been obtained, with recoverable original videos and audio extracts:

| Named vehicle | Audio duration | Source and licence |
|---|---:|---|
| Mi-24 Hind, Czech Air Force air-show display | 325.660 seconds | [LEJ.approach/dvldi, ILA Berlin 2016](https://commons.wikimedia.org/wiki/File:Mi-24_Hind_at_ILA_Berlin_Air_Show_2016.ogv), CC-BY3.0 |
| T-72B mod. 1989 | 48.041 seconds | [Mil.ru field footage](https://commons.wikimedia.org/wiki/File:%D0%A2-72B_mod._1989.webm), CC-BY4.0 |
| T-80U | 68.513 seconds | [Mil.ru exercise footage](https://commons.wikimedia.org/wiki/File:T-80U_tanks_exercise.webm), CC-BY4.0 |

These model identities are documented by the retained source pages. Sampled
frames were visually inspected and show live-action aircraft/tank footage.
The exact Hind subvariant is not established. These are 44.1 kHz stereo video
soundtracks, with possible wind, speech, music, editing or other-vehicle
contamination. Clean isolated takes, loopability and subjective sound quality
remain unverified. They are source candidates, with no new runtime bindings.
Existing generic helicopter files retain their unverified-model labels.

All three originals and extracts fully decode. Two audio streams were copied
without re-encoding. The initial T-80 Ogg remux failed decoded-sample equality
and was quarantined; its lossless float WAV replacement passes. All three
active extracts have identical decoded PCM hashes to their original videos.
Original/extract/page SHA-256s, licence snapshots and required attribution
are retained under `artifacts/soviet-sfx-20261026/` and
`local-audio/soviet-sfx-20261026/`. Downloaded originals total 211,478,137 bytes;
active audio totals 38,318,984 bytes. No money or credits were spent.

Recommendation: audition/select the Hind, T-72B and T-80U material before buying
another library. Exact-model T-62 and T-64 clean sources remain gaps; neither is
silently represented by a T-72 recording. Pole Position's dedicated T-72
recording library is a documented paid fallback at the currently listed $119,
outside the existing spending cap. Rabbit Ears REA010 has an authentic historical
recordist announcement, but its current official availability/price could not
be verified. No paid library or preview was downloaded.

All 485 protected audio/pipeline files, including the accepted private effects
bank, remain byte-identical. No new in-game mix, device listening, public
release, packaging, web/standalone rebuild or push is claimed.

Working if: named-vehicle candidates resolve to retained originals and licences,
attribution follows any use, clean take selection precedes integration, and
the accepted mix and source-qualified audibility remain unchanged.
