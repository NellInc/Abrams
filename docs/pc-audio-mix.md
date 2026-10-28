# Presentation audio controls

## Current saved controls, 28 October 2026

Native Settings and Audio expose 29 saved controls: five groups (Master volume,
Sound effects, Crew voices, Engine and turret, Music) and 24 individual controls.
These cover Cannons, Machine gun, Impacts, Smoke, Engine, Turret, Rivers, Hind
engine, Radio alerts, Switches, Field air, Animals, T-80 engine, T-72 engine, Other tank engines,
M113 engine, Bradley engine, Woodland air, Truck engines, Track texture,
Mechanical detail, Interface tones, Visible fire and Missile flight. Every control supports Off
through 100%. Existing group defaults and individual 100% defaults are retained.

The sixteen optional world/detail controls stay native-only because their local
banks are excluded from browser discovery and packaging. Current Web source
supports thirteen controls; the previously published game pack supplies five.
The shell deployed at `6a19ea9` displays only capabilities reported by that
runtime and retains a working Restore default mix. More source controls require
a matching future game-pack build; the shell update did not rebuild that pack.

Accepted Hind/tank/crew/cow/field levels and source-owned motor pitch/amplitude
remain unchanged. The generic tank fallback, M113 and Bradley are installed;
their earlier acquisition and integration holds below are historical. Woodland
and fire replacements were reviewed after Nell rejected their first character.
Nell accepted both the character/wrap preview and production-level reel. The
approved forest-edge28second master (-35LUFS) and wood-fire24second master
(-25LUFS) are installed, retaining factors0.08 and0.12 respectively. All other
accepted masters, controls and factors remain unchanged. Complete previous
banks are retained for rollback. German/Central European woodland is the accepted
art direction, without an authenticated German recording-location claim.

The approved private T-72 idle now replaces generic playback for exact moving
model119 after the unchanged native ownership gate. Its -25.01LUFS master uses
the same0.30factor as the generic recording. Existing saved Other tank engines
gain, including Off, carries to T-72 only when no dedicated preference is saved.
An explicit dedicated Off remains silent. No other master, factor, source clock,
event, own-motor pitch/amplitude or mask changes. Human loop approval and24native
retained-source checks are complete; no new live combined-mix or device hearing
verdict is inferred. The original mask-qualified source had no paired historical
audio, so its native mixer check uses an explicitly empty synthetic envelope.

Missile flight is an approved authored steady fizz,8seconds at -30.49LUFS,
factor0.30. Its source-qualified original flare owners alone admit one centred,
fixed-pitch bed. Both alternating phases and all ten registered sizes use exact
canonical original pixels and unchanged owner/UI separation. Tiny or hidden
sprites remain silent; there is no inferred full-flight timer or new ignition.
The14second held original-boundary mix was accepted as comfortable alongside
the existing motors. The separate recorded TOW launch and combined audition
remain uninstalled. Original launch/alert requests and all incumbent levels
are unchanged. This source-bound Dummy/native capture is no physical-device
or fresh live mission/pacing claim.

Working if: settings isolate their own cues, old configs preserve their values,
the browser advertises only real runtime capabilities, and only an explicitly
accepted new cue can alter the incumbent mix.

Radio alerts and Switches now have the same immediate gain/mute and durable
preference behavior as the earlier individual controls. Muting consumes an
original request; unmuting never replays it. It neither changes crew gain nor
the original source-driven motor pitch/amplitude. The approved switch is one
120 ms CC0/authored contact at the same original request 14; the original radio
attention signal and all speech remain unchanged. Native Settings 37 checks and
post-import mixer 334 checks pass, with scoped wide/compact/scrolled screenshots.
These local controls require a matching future browser pack before publication;
no web or standalone edition was rebuilt by this follow-up.

Nell heard the captured continuous Hind/engine/turret mix and asked to keep its
balance. The approved clips and relative factors remain unchanged: Hind 0.30
through Effects, engine 0.08 and turret 0.10 through Motors, with the existing
0.65 base master gain and -1 dB limiter. Individual saved controls remain usable.
Original source motor pitch/amplitude stays dynamic. Approval covers this
continuous mix; earlier crew-mix listening and fresh live machine proof remain
separate. The private acceptance receipt pins the three clips and heard WAV at
`artifacts/audio-batch-20261026/accepted-motor-balance.json`.

## Cow and field bindings, local preparation

Field air follows the exact original static field shape 48/root 5109, primitive
5123, filled palette [8,8]. It is authored visible-scene air, without an original
weather or vegetation-contact claim. Ordinary owner texels and the original UI
mask control audibility. The new narrow-field path leaves existing Hind/river
admission unchanged. The field factor is 0.08, below the existing river factor.
The initial tall-grass preview was rejected as storm-like; it is not installed.
Nell accepted the gentler replacement alongside the unchanged motors at the
0.08 field factor. Recording/runtime gates remain separate.

Animals uses a single sparse cow call, eligible only when the actual restored
cow component is visible. Whole-farm ownership is insufficient. The private
companion copies complete submitted farm groups and the production shader's
source discard rules, applies pessimistic depth, then requires separated opaque
cow interiors with original UI clearance. It never edits production geometry,
materials, ownership targets or guest state. Unsupported or ambiguous input is
silent. The first call waits 180 accepted source frames; repeats require 2400
source frames. Held frames, mute, lost visibility and checkpoint resets cannot
create catch-up calls. One centred fixed-level voice reveals no count or range.

The separate optional local environment bank is independently atomic, so an
invalid cow/field bank cannot disable the accepted Hind/river bank. Native
Settings exposes saved Off-to-100% controls for both cues. Their source and
native acceptance evidence is kept in artifacts/environment-bindings-20261026.
The separate private bank is installed locally. Production loader/mixer checks
pass. A genuine original zoomed farm now qualifies the component proof natively;
world, ownership and source bytes remain identical. Render-cache reuse still
checks the current source frame and epoch before and after drawing. Exact UI,
clip, ownership, geometry or material changes invalidate the relevant cache.
An isolated tagged-fragment warmup runs before the source bridge starts, with
the selected MSAA/anisotropy. It publishes no visibility or audio authority.
The qualified MSAA4 retained case measured 156.592 ms startup work and 23.647 ms
first real proof, versus 144.262 ms without that warmup. These are bounded
retained-scene measurements, without a sustained-FPS or cold-cache claim.
A second earlier original case qualifies after ordinary sight controls move
the reticle clear of the cow, without changing the camera or geometry. Enforced
native positive checks pass 92. With an uninterrupted foreground interval,
actual native original execution passes 325 focused samples and one cow call
at source frame13098, exactly180 after exposure12918. The 8.266-second private
post-limiter capture peaks at -5.3dBTP, with zero unfocused recording samples.
Nell could not hear the cow in that mix. Its quiet master had an additional
0.12 cue factor, approximately -50LUFS before panning. Only the cow factor is now
0.80 (about16.5dB higher); Animals still supplies its saved Off-to-100% adjustment.
Field/Hind/river, tank motors and crew levels remain exact. Focused checks pass.
Audio-level QA now runs headlessly:324 fresh original-core frames match the
prior native RAM/video audits and audio envelopes, with the corresponding sealed
historical visibility decisions. The production mixer independently computes
one cow at13098 from exposure12918, preserving180 source frames. The8.173-second
corrected background mix peaks at -4.5dBTP, with no clipped frames or pacing
rebases. Nell hears the cow and accepts this level: retain the0.80 cow factor.
The normal frontend focus-mute rule
is untouched. This is historical-visibility mixer QA, without fresh GPU,
physical-device or live-pacing proof. The isolated reference remains an audition
only.
Field level acceptance and native source-mask admission are recorded separately.
No browser or standalone edition has been rebuilt or published.

## Suno score production, 23 October 2026

Nell requested original Suno music across the menu and every game-screen family,
including battles, quiet travel, mission results, friendly-fire consequences,
briefings, ammunition selection and endings. The authoring catalogue is
`godot/data/pc_suno_score.json`. It contains twelve complete instrumental prompts,
arrangement directions, a common five-note motif and the intended screen roles:

| Master | Screen or event family |
|---|---|
| Iron on the Horizon | Publisher, intro/credits, menus, scenario/name/joystick selection, information, help and settings |
| Maplight | Briefings, orders and mission maps |
| Before the Breech | Motor pool and ammunition choice |
| Fields Beyond the Armour | Quiet travel and campaign rest |
| Tracks into Fire | Confirmed contact and sustained battle |
| Hull Down | Visible damage and urgent combat |
| The Ground We Held | Mission success, commendation and promotion |
| Orders Unfulfilled | Confirmed abort, failure and poor results |
| Blue on Blue | Confirmed friendly-fire consequences and disciplinary scenes |
| Four Empty Stations | Destroyed tank, crew loss and aftermath |
| Home by First Light | Campaign victory |
| The Last Dispatch | Campaign defeat |

Production status: **twelve Suno v6 masters generated, downloaded and integrated
locally**, with 24 takes retained in the dedicated Suno workspace. The selected
masters total approximately 25.6 minutes. The account used 120 existing credits
and twelve included downloads; 2,270 credits remained at completion. No purchase,
audio upload, public publication or installed-app update was performed.

`local-audio/suno-score-v1/masters/` preserves all twelve 48 kHz stereo WAV
exports unchanged. `manifest.json` binds those hashes, alternate song links and
separate 24 kHz game derivatives. The authored-order M3U8 in the same directory
plays the full masters. The polished game edits use -18 LUFS / -2 dBTP
normalization, fitted musical pulse and whole 8/16/24/32-bar phrases. Their loop
tails blend into a matching earlier phrase over one fitted beat, with a smooth
64-frame endpoint bridge. The cold opening is retained for the six original
sustained themes. Estimated tempo, source cuts, phrase length, tonal/onset
similarity and seam level differences are recorded in the manifest. These are
signal-based musical edits; listening acceptance and motif fidelity remain open.

The seven additions are arrangements of the preserved Suno masters, with no
extra generation, export purchase or upload:

| Addition | Source and use |
|---|---|
| Objective Secured | Short success stinger from The Ground We Held |
| Orders Broken | Short failure/abort stinger from Orders Unfulfilled |
| Wrong Side | Short disciplinary stinger from Blue on Blue |
| Four Stations Silent | Short destruction stinger from Four Empty Stations |
| Flanking Movement | Separate first-half battle passage, softened upper spectrum |
| Sustained Pressure | Separate second-half battle passage, full voicing |
| When the Turbines Fall Quiet | Subdued, band-limited minor-key aftermath loop |

The four stingers last 2 to 6 seconds and retain their opening attacks. The
original full result compositions remain available in the master playlist.
Battle passages keep their original pitch and tempo. Three battle arrangements
rotate in authored order when a fresh encounter begins after the previous
900-frame hold expires; continued fire never changes arrangements. Crisis
interrupts temporarily, then returns to the same encounter arrangement.

`python3 -m tools.import_suno_score --polish local-audio/suno-score-v1 --output
<new-empty-directory>` rebuilds the edits from hash-verified originals. This
offline command additionally needs NumPy and SciPy, already available on the
production machine; neither dependency is needed by the game. The command
refuses existing output directories. Previous derivatives are retained under
`local-audio/suno-score-v1/previous-edit/` when promoting the polished pack.

`pc_suno_music.gd` reuses the existing bank loader. It selects original publisher,
information, motor-pool, destroyed-tank and newspaper pixels through source-bound
fingerprints; other frontends use current pixel-qualified original text. Confirmed
player fire/impact holds combat music for 900 source frames, visible damage
holds crisis music for 600, and quiet release returns to the idyll. Visible
original radio completion/abort messages select result cues. END's visible
friendly-fire verdict selects the Wrong Side stinger. Each result stinger plays
once, then releases to the aftermath loop without a redraw replay. Neutral
debrief, partial success and stalemate use aftermath directly. Campaign endings
retain their complete compositions, then release to aftermath. Screen changes crossfade
for 600 ms, voices duck music by approximately 10 dB, and completed stingers and
ending tracks do not restart on redraw. Stingers retain a crisp attack while
the previous bed fades away. The independent score also works in
PC-only mode without a Genesis import. Restoring a checkpoint clears outcome
and combat holds; restarting the save worker retains their remaining duration.

Focused local checks: `PC_SUNO_MUSIC: 68 checks, 0 errors`, including twelve actual
PCM streams, source screen fixtures/reconstructions, combat release, friendly-fire
pixel rejection, voice ducking, source mute, natural one-shot completion, restore
and shutdown. The historical frontend bank still passes 61 checks, the mixer 138,
and original audio dispatch 829. The shutdown check releases its three actual
playback instances. A fresh native cold-boot capture reached the original motor
pool with `music_context=arming`, `music_playing=true`, `independent_score=true`
and no music failure, in PC-only EGA mode. The ten gate-registration checks pass.
These checks are separate from whole-campaign listening and
from a published release. Receipts are in `artifacts/suno-score-20261023/`.


### Polished arrangement acceptance

This chat authored the edits and performed these machine checks; they are
self-verification, separate from independent listening:

* `PC_SUNO_MUSIC: 112 checks, 0 errors`, with all nineteen actual PCM streams,
  whole-bar loop lengths, four short stingers, stable encounter rotation,
  stinger-to-aftermath completion without redraw replay, mute/unmute, source F5,
  destruction after SIM detaches, restore and shutdown.
* 36 focused Python checks passed, including master/derivative hashes, loop
  phrase durations, non-overlapping battle passages, packaging and gate tests.
* Historical frontend 61 checks, PC mixer 138 and original audio dispatch 829
  still pass. Shutdown releases its three live playback instances.
* A fresh native cold boot reached the original ammunition-choice screen with
  `music_context=arming`, `music_track=arming`, playback active and no score
  failure. This is a real game capture, separate from the headless classifiers.
* Package selection includes all nineteen derivatives and the manifest, while
  excluding masters and previous edits. Source-code closure passes. Full private
  resource closure currently reports the concurrent cover export's
  `res://../local-art/cover-blender-v1/source.json` path as missing; the model
  owner has the finding. No installed application or website bundle was rebuilt.

The initial new Godot bar-count assertion failed because parsed JSON numbers
were floats; its corrected integer comparison passes. No runtime or asset defect
was hidden by that change. The preserved original WAV hashes are unchanged.
Receipts and nine short seam auditions are in
`artifacts/suno-score-polish-20261023/`. The game-edit playlist is
`local-audio/suno-score-v1/Abrams - Game edits.m3u8`; the full-master playlist
remains unchanged. Machine seams and playback are accepted locally; perceptual
continuity, generated motif accuracy and full-campaign mix listening remain open.

The source boundary remains unchanged: score selection must use the displayed
original scene or an already validated original visible/audio event. Hidden
world objects, queued messages and guessed campaign outcomes must never select
music. In particular, a generic kill report cannot establish friendly fire, and
a facepalm alone cannot establish disciplinary guilt. Original F5/pause,
transport mute, restore and shutdown retain priority. Sustained combat needs
paced transitions and speech ducking. Pause should retain the current cue's
cursor, rather than starting a new track. Original downloads must remain
unchanged beside separately normalized, loop-edited game derivatives.

Working if: all twelve masters have actual Suno song identities and preserved
downloads; each requested screen family has a source-qualified playback route;
focused runtime checks demonstrate the mute, restore, transition and speech
priority contracts; no hidden tactical information or simulation change is
introduced. The polished local machine gate is complete; listening and full-campaign acceptance remain open.

## Mixer and historical fallback

Play's **Audio** menu has five independent levels: master, sound effects, crew
voices, engine/turret motors, and music. Each offers Off and 10% steps through 100%. A saved or browser-selected level between those steps appears as one exact checked entry, removed when the level changes.
Restore default mix returns the original four levels to 100% and music to 70%,
preserving the authored gains (including the existing 0.65 overall gain).
When the independent Suno pack is absent, the historical donor bank still plays
only in source-qualified title, menu, briefing and debrief contexts, with quiet
in-mission gameplay. A damaged independent pack is reported and remains silent;
it does not silently substitute donor music.

macOS uses the system menu bar, leaving the game image untouched. The non-native
fallback reserves a small header above the largest complete 4:3 game view. No
new keyboard accelerator replaces an original game command. Menu-navigation
keys are withheld from the original, and a closing Enter/Escape must be released
before another game command can be forwarded. Source stepping policy remains
one frame at a time; no pause command, speed setting or gameplay value is sent
by the mix controls. Use the original game's pause when desired.

The presentation menu uses Godot's standard
[MenuBar](https://docs.godotengine.org/en/stable/classes/class_menubar.html) and
[PopupMenu](https://docs.godotengine.org/en/stable/classes/class_popupmenu.html)
APIs. Native OS typography is used outside the original game; source-faithful
cockpit/menu lettering is unchanged.

## Behaviour and persistence

Changing a level updates already-playing streams immediately. Off stops the
selected stream category. Source events are still consumed once while their
presentation gain is zero; raising gain cannot replay old effects or speech.
Continuous motors resume only while their original sound channels are active.
Original F5, pause, departed SIM epochs and invalid audio envelopes retain their
mute/fail-closed authority. User gain changes never clear that source gate.

Preferences live in Godot's `user://pc_audio.cfg`, separately from the original
PC filesystem overlay and campaign files. Missing preferences use the previous
mix. Invalid preferences use defaults and show a menu notice. A failed save
retains the chosen session levels and shows the failure. Diagnostic `--capture`
launches use defaults and do not read or write the user's preferences. Native UI
acceptance explicitly selects its own artifact-local config file.

The shared range audio base gains default to 1.0, preserving the separate
calibration range. Source-dependent motor control remains in `pc_audio.gd`.

## Browser mixer

**More controls: audio and graphics quality** exposes the same five gains and shared **Restore default mix** operation. Saved integer levels between menu steps remain visible exactly. Settings warnings appear independently of checkpoint status. Original F5/pause and fast-forward mute retain priority, and resetting the mix never changes source event identities.

## Verification

* `pc-audio-mix-unit-02/report.json`: 97 checks, zero errors. Covers pre-ready
  preference loading, exact default/live gains, zero-volume stop, no one-shot
  catchup, original gate priority, separate category controls, configuration
  reload/failure and menu-key release. Native stream construction is exercised.
* `pc-audio-mix-work-01/scheduling.log`: 82 checks, zero errors. The production
  scheduler continues neutral source input while presentation menus own keys,
  then resumes fresh original controls. No batching/catchup policy was changed.
* `pc-audio-mix-native-02/mix-report.json`: nine gain changes during the existing
  1,020-frame live native control route. All compared input requests and complete
  framebuffer-paired RAM/video records match `pc-play-final-controls-02`.
  `image-comparison.json` also proves every decoded pixel of the final original,
  paired, tandem and world images unchanged. Process exit 0, no script errors.
* `pc-audio-menu-native-04/menu-report.json` (a four-channel run that predates
  the Music channel and Restore default mix; the current
  `test_pc_audio_menu_native.gd` expects `music:70` and has no recorded native
  receipt yet; the -04 fallback half built the bare `pc_audio_menu.gd`, while
  the current test builds the production `pc_play_menu.gd` with
  `prefer_global_menu=false`, as players see it, and adds a
  `fallback_is_play_menu` check): all 15 checks pass after actual
  macOS menu clicks set effects to 40% and voices to 70%. The players change,
  saved configuration reloads exactly, and the diagnostic's frozen original
  frame/state remain unchanged. Native menu consumes no game pixels. A fresh
  non-native menu is also rendered above the intact 4:3 cockpit. This does not
  establish Windows/Linux backend support. The native menu was inspected through
  accessibility; its screenshot API was unavailable. The fallback image was
  captured and visually inspected.
* `validation-20260928T101218Z`: all 41 stages, 286 Python tests, 642 existing
  Godot audio checks, 97 mix checks and 82 scheduling checks pass, terminal 0.
  Original reference preservation remains exact.

The live mix run measured 47.53 fps, compared with 57.93 in the earlier matched
route. These different-time runs are not a controlled performance A/B. Sustained
pacing and historical speed calibration remain open; no 60 fps claim is made.

Working if: mix changes affect only audible presentation, leave original
input/state/render records unchanged for the same delivered controls, retain the
original sound gate, and persist separately from original game saves.

## Overlap protection

The existing per-player/category gains now feed a dedicated PC-only hard-limiter
bus, with a -1 dB ceiling and no added pre-gain. Master and calibration buses are
unchanged. This preserves volume controls while protecting against coincident
peak overload from the eight-effect pool, voice and motors. The bus is removed
with its owning scene. Synthetic actual-mixer overload and latency results are
recorded in `pc-audio-completeness.md`; they do not substitute for listening.

## Native and Web delivery, 23 October 2026

The owner requested both installed-app and browser delivery. The delivery
candidate is based on the current public release, with only the independent
score changes overlaid; unfinished parallel HUD and model work is excluded.
All nineteen game derivatives and their manifest are included in the original-free
Mac app and the Web common asset set. Original masters and prior edits stay
private. PC-only Web sessions receive the score without a Genesis ROM.

The signed application's bundled runtime imported the supported PC files,
started the original game, and captured ammunition choice with
`music_context=arming`, `music_track=arming`, `music_playing=true` and no score
failure. The browser logged `PC_SCORE_READY: 19 verified PCM streams` and
`PC_SCORE_PLAYING: context=menu track=menu playing=true`, with no warning/error
logs; Music Off and 70% were exercised through the browser controls.

The first signed-app smoke exposed a pre-existing native-menu crash: the
Tactical separator callback mutated a native menu while AppKit was populating
it. Native separators are now left to AppKit; non-native separator behavior is
unchanged. The repaired signed-app capture passes, as do 290 existing menu checks,
112 soundtrack checks and the clean source-kit gate (210 tests, 22 environment-
dependent skips). Web contracts pass 46 Node and 40 Python checks. The original
crash and all later receipts are retained in `artifacts/suno-score-delivery-20261023/`.
These are self-verification checks by the authoring chat, not independent listening.

Working if: the installed app and served Web bundle contain the nineteen pinned
cues; PC-only menu/arming playback is observed; source mute, result/aftermath,
encounter rotation and restore checks pass without shipping original game files.


## Exact-model T-80, private noncommercial pass

Nell supplied SoundFX.studio's Freesound456277 original. Its creator labels it
T-80 GTD turbine material; independent recording-session authentication is not
claimed. The original and SHA-verified recovery copy remain private. CC BY-NC4.0
attribution and processing notes accompany the optional separate bank at
`local-audio/pc-soviet-effects-v1/`. This pass authorizes private noncommercial
evaluation only, with no commercial/public packaging or paid acquisition.

The full1,062,930-frame (22.144375-second) source is downmixed arithmetically to
48kHz mono16 and statically attenuated to -25.0LUFS, 1LU below the accepted Hind
master. Peak is -17.72dBTP. No dynamics, EQ, pitch change, trim or loop-boundary
edit is applied. The source page's22.144seconds is rounded,18frames shorter
than the actual file if treated as exact. Provenance pins the actual length.
Human cleanliness, loop and combined-level approval remain separate gates.

Only exact intact model121 with a unique original pointer/model actor join and
finite nonzero signed16 movement can become a candidate. Stationary engine-on
state is unproven; stationary objects and wreck122 remain silent. The existing
postdraw owner/original-UI, mesh/camera, frame/epoch and transport guards decide
audibility. One centred fixed-pitch bed uses factor0.30 through Effects and its
independent saved Off–100% T-80 control. Missing or invalid new assets cannot
disable accepted world/environment banks. Requests7/9/10/15/16 remain unknown.

Accepted cow0.80, field0.08, Hind0.30, own engine0.08, turret0.10, river0.20,
crew/music, original event timing and source-owned motor pitch/amplitude are
unchanged. Adding a new bed can affect shared limiter attenuation; unchanged
input gains alone do not prove identical mixed-output levels. Focused mix and
visibility qualification, then human listening, decide the new combination.
T-62, T-64 and T-72 have no acquired qualified exact-model recording in this
finite pass; the T-80 is never used as their substitute. The held T-55 purchase
is roster-incompatible and remains unpurchased.

The final machine checkpoint passes200 world-audio checks,373 mixer checks,
62 native owner/playback checks and40 native Settings checks. Compact, wide
and scrolled native Settings images were inspected; preferences are isolated
to the test output, with no manual native-menu selection claim.

A demonstrated sparse-grid miss on a thin T-80 silhouette now reuses the bounded
exact-owner scan. Its witnesses remain two actual same-owner original pixels,
separated by at least4pixels, with accepted blue0/8, opaque alpha and clear
original UI. No source/ownership pixels or geometry change. The8192-byte-hit
cap fails closed; at most49 unique coordinate witnesses are needed before a
qualifying pair exists. Existing field behavior and Hind/river grids are
unchanged. Sourceframe42389 remains negative (maximum distance squared9);
two genuine defense3 cases qualify (distance squared20). The native positive
uses sourceframe42755/owner16 and retains the complete original painter queue,
including occluders. No possible pose substitution or configured surface
passthrough exists in that packet; protected standalone segments cannot be
witnesses. This qualifies source ownership, not a new full-Tactical visual pass.

The full-world diagnostic timed out at its100-second cap and is not acceptance
or a performance diagnosis. An initial platform-name preflight and an initial
wall-timer PCM-duration check also failed; their receipts are retained. The
accepted background sample-clock capture instead reads the production bus
after its existing limiter: exactly12seconds,44.1kHz stereo16, -17.8dBTP,
zero clipped samples or discarded capture frames. It holds authenticated
sourceframe42755 after1026 original envelopes were consumed silently;
no crew events, source frames or onset sequences are invented. About4seconds
of existing engine/score precede8seconds with T-80. Headless/Dummy proves no
physical-device or fresh-live-motion claim. Human loop/mix judgment is pending.
All15 incumbent private-bank files remain byte-identical. No publication.


Nell subsequently says “Proceed please” after both T-80 previews were presented.
Retain the installed candidate at factor0.30 and continue sourcing the other
exact models. This is authorization to use the presented candidate/level; no
explicit cleanliness, seam or hearing observation is invented. Candidate and
heard-preview references are bound in the private t80-continue-authority.json
receipt. All accepted incumbent banks and source/mask/motor inputs were
rechecked unchanged. New purchases and publication remain outside this go-ahead.

## Generic tank fallback

The optional native bank at `local-audio/pc-tank-fallback-v1/` contains the
approved JoniHeinonen heavy-diesel recording, Freesound161896, under CC BY3.0.
It is a generic texture with unidentified vehicle provenance. The original
24-bit WAV and both edits remain recoverable outside tracked assets. The
accepted equal-power revision is exactly1,152,000frames,24seconds,48kHz mono16,
-25LUFS, SHA256
`2ce260b7ac2f9b611dc85c02d12c2e12bc0fb0c097d200fa5f08bee017ee593f`.
Attribution and modifications accompany the installed bank.

Exact intact original shapes115(T-62),117(T-64),119(T-72) and127(M60A3) use
this fallback. Shape121(T-80) retains its validated dedicated recording, using
the fallback only if that optional recording is absent or invalid. Muting a
dedicated recording never substitutes the generic sound for the same actor.
M1-A1 keeps the original source-owned Abrams motor path; no claim is made that
this covers every visible M1 actor. Wrecks, unverified F-ST, IFVs, trucks and
stationary actors receive no new cue. Movement is an audibility qualification,
not a decoded engine-start, idle or RPM event.

The strict unique pointer/model join and finite nonzero signed16 speed rules,
postdraw frame/epoch/mesh/camera guards, original UI exclusions and two
separated same-owner pixel witnesses are inherited from the existing T-80
path. No painter, visibility-mask or guest state is modified. Working if:
offscreen/occluded, invalid, paused and restored timelines cannot start or
retain a fallback from stale proof.

One centred fixed-pitch generic bed serves all eligible fallback owners,
without count-, direction- or distance-dependent gain. It uses the existing
Effects group, factor0.30 and shared-1dB limiter. The native-only saved
“Other tank engines” control provides Off through100%; old settings retain
their values and acquire the new100% default. Different visible classes may
play dedicated and generic beds together; neither automatically ducks the
other. Existing own-engine/turret, T-80, Hind, river, cow, field, crew and music
gains and source event onsets/cadence remain unchanged.

Verification uses focused source/mixer/limiter checks and the real native
production owner target from a retained original scene. Source JSON, UI and
owner bytes remain identical before/after audio observation. The historical
audio sequence beside that capture is no longer present, so the native check
uses an explicitly synthetic empty presenter transport and proves no fresh
live-guest playback, device listening or sustained performance claim. The
approved loop audition remains the human hearing evidence. Local integration
only; no web/standalone rebuilding, packaging or publication is performed.


## Current private native root and missile scope

Native checkout playback retains its existing `local-audio` discovery. A native
owner may instead set `ABRAMS_AUDIO_ROOT` to the absolute directory containing
the ten fixed bank folders. The standalone launcher defaults this to its stable
profile `audio` folder, outside versioned installs. Invalid explicit roots select
no optional recordings, and Web ignores this setting. Each bank still requires
its existing manifest/hash/PCM validation. This neither copies media nor grants
redistribution rights. Review-profile links reference the accepted local banks.

The FST and ACRV held-source mixes are accepted at their current unchanged levels.
Nell's launch-sound request covers Sagger/Spigot and the rail-mounted missile
vehicle; M1A1 AX continues using the regular round firing sound. The own-AX
variant was withdrawn, and enemy ignition remains uninstalled pending its exact
original launch boundary. Current flight fizz and every accepted motor/ambience
master and gain stay unchanged.

Working if: all 26 accepted private cues load through one explicit root, missing
banks retain their existing fallbacks, and M1A1 AX is acoustically unchanged.
