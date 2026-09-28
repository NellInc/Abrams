# Generative crew speech

Nell requested proper generative TTS, preferring Gemini 3.8 Flash TTS with Gemini
3.1 Flash TTS as fallback. Local API discovery confirmed both models are available.
The source script is `godot/data/crew_voice_script.json`; it preserves the nine
existing calibration-range cue identifiers, roles and caption words.

## Casting and direction

| Role | Prebuilt voice | Direction |
|---|---|---|
| Commander | Orus | Experienced, firm, controlled American delivery. |
| Gunner | Iapetus | Clear, alert, clipped calls. |
| Loader | Fenrir | Energetic, physically engaged, intelligible short reports. |
| Driver | Algenib | Low, slightly gravelly, matter of fact. |

Gemini 3.8 receives the spoken script separately from structured acting direction
in `speech_metadata`. Inline pauses are used where appropriate. The initial
loader exhalation and readiness pause were removed during wording QA; an effect
should not encourage an added or substituted command. The cease-fire performance
retains a short scripted pause. Captions contain spoken words, without vocal tags.

Bearing and heading barks use three separately spoken digits, as Nell requested:
`heading 280` becomes “heading two eight zero”, and `bearing 045` becomes “bearing
zero four five”. Numeric captions remain unchanged. This conversion is applied
before either TTS model receives a script; ordinary ammunition counts and distances
are unaffected. Nell also accepts the aviation pronunciation “niner” for the
digit nine. QA permits either form in bearing/heading calls while still rejecting
whole-number phrases and incorrect digits. Working if: request payload tests contain the digit words, and
the corresponding caption still contains its numeric bearing.

This follows Google's current [3.8 model documentation](https://ai.google.dev/gemini-api/docs/models/gemini-3.8-flash-tts)
and [speech-generation guide](https://ai.google.dev/gemini-api/docs/speech-generation).
Version 3.8 returns a WAV file directly. The 3.1 fallback uses its older request
shape and returns PCM that is wrapped once in a WAV header.

## Files and reproducibility

`tools/generate_crew_voice.py` writes dry mono masters, per-cue requests and source
receipts outside Godot. It reads the selected Keychain item only when making a
request. No key is written to an argument, request JSON or receipt. Only authored
dialogue and performance direction are sent for generation. Generated speech may
be sent back for transcription QA; original game audio and ROM data are not.

```sh
python3 tools/generate_crew_voice.py \
  --output local-audio/crew-new
python3 tools/generate_crew_voice.py \
  --model gemini-3.1-flash-tts-preview --cue loaded \
  --output local-audio/crew-loader-fallback
```

Use `--dry-run` to save requests without reading credentials or calling the API.
The Keychain service/account are configurable; defaults select the existing
Google credential already used by Nell's local voice tooling. No key is copied
into this project. Existing output directories cannot be overwritten, and failed
HTTP calls stop without automatic paid retries.

## Verification and integration

The first pass produced nine Gemini 3.8 files. Automated transcription matched
seven scripts and flagged two possible wording errors. An isolated follow-up
returned an incomplete response, so it established no verdict. A revised readiness
take then matched its script. The revised loader take transcribed as “Hup”; that
line moved to the explicitly authorized 3.1 fallback rather than repeating the
same unsuccessful 3.8 direction.
The 3.1 take transcribed as “up”. All nine selected clips now match their caption
words in automated transcription: eight 3.8 performances and one 3.1 performance.

Dry generated masters and rejected variants remain under `local-audio/`. The
selected set is installed as the existing `godot/assets/audio/voice_*.wav` names,
with per-cue provider, model, voice, performed text, duration and SHA-256 recorded
in `provenance.json`. Installation does not change simulation events or captions.
The previous eSpeak takes are retained locally for recovery.

The legacy effects builder preserves speech by default. Its explicit
`--scratch-voices` option refuses to overwrite generative voices.

Working if: all nine Godot resources load with the receipt's format and duration,
their hashes and caption words match, and a default effects rebuild leaves the
installed speech untouched.

Automated transcription checks intelligibility and wording, with expected words
withheld from the recognizer. It does not establish final casting, acting quality
or listening approval. The entire PC dialogue catalogue, mission briefings and
final mixes remain separate unfinished parts of the remaster.

## Original PC tandem use

Default tandem audio reuses “On the way!” at the
original accepted cannon request and “Smoke out.” at the original smoke request.
It does not borrow training-range outcomes or interpret “Good hit” as an incoming
hit. The loader says “Up!” after an original reload and a strictly newer,
pixel-verified READY display, with mute, freshness and duplicate safeguards.
All bearing calls still require digit-wise speech with numeric captions.
See [original audio research](pc-audio-research.md) for the live event boundary.


## Original PC crew catalogue

`godot/data/pc_crew_voice_script.json` is the bounded PC-source catalogue, separate
from the calibration-range script. Fourteen Gemini 3.8 takes use Orus for original
portrait index 3: five observed hit bearings and nine damage reports. The named
crew role is unknown; the cast is authored. Native dry WAV masters remain in
`local-audio/pc-crew-gemini-3.8-v1`, installed unchanged beside the range clips.
Their receipt is `godot/assets/audio/pc_crew_provenance.json`.

The first blinded transcription matched all nine damage lines. Its five bearing
transcripts used separated numerals such as `0 4 3`, despite asking for literal
spoken words. That first check correctly failed the strict word-form gate.
A separate blinded number-delivery question then classified all five clips as
individual digits and returned each literal three-word sequence, including
leading zeroes. Both responses and audio hashes are retained. Numeric text alone
never establishes digit-by-digit delivery. The offline installer requires either
matching literal words, or the separated-digit transcript plus the independently
matching phonetic classification. Whole-number transcripts remain rejected.

`tools/check_crew_transcripts.py` sends only fingerprinted generated WAVs, neutral
clip IDs and a generic transcription/classification question. Expected words,
cue identifiers and reference game files are withheld. No original recording,
ROM or game binary is sent. `--number-delivery --cue <cue>` selects the second
question when needed. Each call uses a fresh output directory and never retries
a paid request automatically. The API shape follows Google's
[audio documentation](https://ai.google.dev/gemini-api/docs/audio).

```sh
python3 tools/generate_crew_voice.py \
  --script godot/data/pc_crew_voice_script.json --output local-audio/pc-crew-new
python3 tools/check_crew_transcripts.py --directory local-audio/pc-crew-new \
  --output local-audio/pc-crew-new/qa-first
# After the separately selected bearing classification, verify/install offline:
python3 tools/install_pc_crew_voice.py --source local-audio/pc-crew-new --dry-run
python3 tools/install_pc_crew_voice.py --source local-audio/pc-crew-new
```

Working if: installed bytes match generated hashes, numeric captions remain
unchanged, and live voices start once per fully displayed original assignment.
These checks passed for the observed set. Automated wording and native playback
proof do not establish human performance approval or all-PC-dialogue coverage.

## Full hit-bearing coverage, 28 September 2026

The five original selected bearing takes are retained. A second catalogue,
`godot/data/pc_bearing_voice_script.json`, adds 355 full-sentence Gemini 3.8
Flash TTS performances in the same Orus casting, covering every remaining value
from 000 through 359. These are complete generated lines, not spliced digits or
recorded game audio. Every installed master passed blinded wording QA. Two
initial “niner” takes were replaced before Nell clarified that niner is accepted;
the earlier and replacement takes are both retained. Current QA accepts nine or
niner as one digit and still rejects compound numbers, omissions or wrong digits.

`tools/install_pc_bearings.py` verifies the four generation receipts, selected
repair receipts, unchanged WAV bytes and matching transcripts before installing
anything. It refuses differing existing voices. `pc_bearing_provenance.json`
records each selected source, script, model, voice, hash and QA result. Dry
masters and batch scripts remain in `local-audio/pc-bearings-gemini-3.8-v2/`.

The existing original message identity, visible two-part text, speaker, source IP,
F5/pause and freshness gates are unchanged. Numeric captions are unchanged. The
real one-frame native approach replay reaches bearing 058 and starts its newly
installed stream once, paired with the complete original displayed message.
Receipt: `artifacts/pc-full-bearings-native-01/report.json`, 1,680 packets,
one voice start, no errors and original child exit 0. Audio remains a presentation
layer. Human performance/mix acceptance and the other dialogue families remain open.

Working if: all 360 bearing captions select their own installed full-sentence
sample, a new bearing speaks on its original visible frame, and muted, hidden,
stale or repeated source messages cannot queue speech.

## Remaining two-part damage reports, 28 September 2026

`godot/data/pc_damage_voice_script.json` adds 15 Orus performances using Gemini
3.8 Flash TTS. Together with the original nine reports, the bank covers 24
captions: damaged/destroyed for nine turret subsystems, and damaged/getting
really bad for left tread, right tread and engine. The latter suffix is the
original wording; it is not replaced with an invented “destroyed” message.

`tools/pc_damage_voice_oracle.py` executes original isolated instructions and
matches `godot/tests/fixtures/pc_damage_voice_oracle.json`. All 36 cases pass:
24 two-part assignments and 12 already-terminal-condition suppressions.
Subsystem cases start after random subsystem selection, supplying the selected
record and stack locals. Mobility cases execute the full original routine.
Original data, source pointers, speaker 3 and assignment IP 3dd2 are recovered
from actual CPU results. This is source-path evidence, not live occurrence or
historical timing proof. Nothing writes live game RAM.

Generation masters and blinded QA are in `local-audio/pc-damage-gemini-3.8-v1`.
All 15 independent transcripts match, with expected words and cue names withheld
from the model. `godot/assets/audio/pc_damage_provenance.json` retains each dry
WAV hash, provider, request wording and QA result. No mixed recordings or original
binary were sent. Installed audio is byte-identical to its generated master.

```sh
.runtime/pc-analysis-venv/bin/python tools/pc_damage_voice_oracle.py \
  --check-fixture godot/tests/fixtures/pc_damage_voice_oracle.json \
  --output artifacts/pc-damage-oracle-check.json
python3 tools/install_pc_crew_voice.py --bank damage \
  --source local-audio/pc-damage-gemini-3.8-v1 --dry-run
```

Python and Godot share the additional catalogue. The existing speaker, original
assignment, complete two-part visibility, original sound gate, epoch, age and
once-only checks are unchanged. Unknown or partial messages still stay silent.
The native audio gate passes 642 checks, including actual player starts for all
15 additions and repeat suppression (`pc-combat-outcome-work-01/damage-native-audio.log`).
Those starts use source-qualified synthetic test packets. Individual live combat
occurrence and human performance/mix acceptance remain open.

Working if: all 24 source captions select their own verified dry take only after
the complete original message is displayed, while unrecognized, partial, old or
muted messages never catch up audibly later.

## Source warnings and outcome calls, 28 September 2026

`godot/data/pc_warning_voice_script.json` adds eight dry Gemini 3.8 Flash TTS
performances: out of fuel, overheating, assigned-area boundary, non-amphibious
vehicle, steep slope, inoperable smoke dischargers, exhausted smoke mortars and
destroyed convoy. The original captions are unchanged. Orus, Iapetus and Algenib
are authored casting choices for original portrait indices 0, 1 and 2. These
indices do not establish named crew roles. The PC message catalogue now has
392 performances, including its 360 bearings and 24 damage reports.

`tools/pc_warning_voice_oracle.py` executes nine original assignment blocks in
pinned Unicorn 2.1.4. The assigned-area caption has two distinct original pointer
variants. Eight blocks use setter completion 3d8e; overheating uses 3dd2. The
oracle proves wording, portrait index, pointers and setter identity after the
caller selects the branch. It does not prove branch eligibility, whole-routine
behaviour, timing or occurrence during play. No live RAM or original instruction
is modified. The fixture is `godot/tests/fixtures/pc_warning_voice_oracle.json`.

Generation and blind-transcription masters are retained under
`local-audio/pc-warning-gemini-3.8-v1`. Seven transcriptions matched immediately.
The eighth transcribed “M1” as the correctly spoken “M one”. The comparator now
accepts that exact lexical equivalence only when the expected script contains
the designation M1. It rejects M two, M eleven, M won and M1A1; bearings retain
their separate digit-word checks. The original failed comparison is preserved
as `qa-first/transcription-check-original.json`. The corrected report reevaluates
the same raw recognition response offline, with an explicit revalidation record.
Neither speech nor transcript was changed and no second recognition was claimed.

`godot/assets/audio/pc_warning_provenance.json` retains the model, authored voice,
request, unmodified WAV hashes, original transcript, corrected comparison and
revalidation custody. All eight installed files equal their generated masters.
They are mono 16-bit 24 kHz WAVs. Automated wording checks do not substitute for
human listening or final mix acceptance.

Python and Godot both require the exact source caption, portrait, assignment IP
and an allowed pointer sequence. Single-part warnings qualify only with their
single expected part; the overheating prefix and suffix must both be complete.
Existing pixel ownership, current-frame visibility, monotone message identity,
epoch, age and original sound gates remain authoritative. Headless and native
Godot checks each pass 731 assertions, including all eight new sample players
and both assigned-area source variants. These per-cue tests use qualified
synthetic packets; seven of the new calls still lack individual live occurrence
evidence. Smoke exhaustion has a separate real-source/native route below.

```sh
.runtime/pc-analysis-venv/bin/python tools/pc_warning_voice_oracle.py \
  --check-fixture godot/tests/fixtures/pc_warning_voice_oracle.json \
  --output artifacts/pc-warning-oracle-check.json
python3 tools/install_pc_crew_voice.py --bank warning \
  --source local-audio/pc-warning-gemini-3.8-v1 --dry-run
```

Working if: each installed warning can speak only on its complete original
displayed assignment, and a warning first displayed under F5 mute is consumed
silently without replay when sound returns.

### Live smoke-warning acceptance

`pc_warning_steps.json` uses ordinary F2/F1 station changes to reestablish
original cockpit provenance after the diagnostic RAM snapshot. It exhausts all
six smoke mortars, requests an empty discharge, mutes with F5, requests another,
restores sound and requests a fresh warning. The initial neutral frame matches
the production host's ready packet; each later request advances one PC frame.

`artifacts/pc-warning-trace-03/comparison.json` passes eleven checks. All 1,060
original input, paired RAM, framebuffer and queued-message records match
`pc-warning-baseline-03`. The final source state/program matches. Complete
warnings first appear at route indices 631, 759 and 944, with sound gates true,
false and true and identities 1, 2 and 3.

`artifacts/pc-warning-native-02/report.json` passes 7,549 checks through the actual
production viewer and source host. All source RAM/video boundaries and audio
events match the parity-tested trace. Every warning's current RGB crop matches
its original hash; high-resolution type, portrait and Genesis cockpit are active.
Two generated sample starts and one silent consumption are observed. The 98
frames after F5 restore before the fresh warning stay silent. The native process
and its original-PC child exit successfully, with no script/engine errors.

```sh
python3 tools/capture_pc_dialogue.py --mode trace --warnings --capture-ui \
  --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-warning-trace-new
python3 tools/capture_pc_dialogue.py --mode baseline --warnings \
  --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-warning-baseline-new
python3 tools/verify_pc_dialogue.py \
  --trace artifacts/pc-warning-trace-new/report.json \
  --baseline artifacts/pc-warning-baseline-new/report.json \
  --output artifacts/pc-warning-trace-new/comparison.json
./tools/godot.sh --script res://tests/test_pc_warning_bridge.gd -- \
  --fixture "$PWD/artifacts/pc-warning-trace-new/report.json" \
  --output "$PWD/artifacts/pc-warning-native-new" \
  --capture --trace --play --frame-audit
```


## Original radio reports, 28 September 2026

Seven distinct captions now have dry Gemini 3.8 Flash TTS performances, with
Charon cast as an American radio operator. Five captions occur in eight scenario
message entries; two fixed captions reside in SIM. The PC message banks total
399 performances: 360 bearings, 24 damage, eight warnings and seven radio reports.
`godot/data/pc_radio_voice_script.json` retains exact original captions and source
locations. Only the spoken script expands the airborne report's M1 to “M one”.

Six initial takes passed blind transcription. The airborne take instead produced
“Mark one”, and a second attempt produced “Mike one”. Both are genuine wording
failures and remain excluded. Explicit “M one” in the third take's spoken script
passed a fresh blind transcription. None of those transcripts was rewritten or
normalized into a passing result. Original request, generation and QA files are
retained in `local-audio/pc-radio-gemini-3.8-v1`, `v2` and `v3` (with the same
`pc-radio-gemini-3.8-` prefix for each folder).

The offline installer accepts a fingerprinted original script and an independently
validated repair subset. It checks each selected cue and casting against the
current script, the unchanged WAV, original manifest, and that take's own blind
transcript. `pc_radio_provenance.json` records each selected master, original
script hash and QA inputs. Six original takes and the third airborne take are
installed without audio processing. Human listening/mix approval remains open.

```sh
python3 tools/install_pc_crew_voice.py --bank radio \
  --source local-audio/pc-radio-gemini-3.8-v1 \
  --source-script local-audio/pc-radio-gemini-3.8-v1/script.json \
  --repair-source local-audio/pc-radio-gemini-3.8-v3 --dry-run
.runtime/pc-analysis-venv/bin/python tools/pc_radio_voice_oracle.py \
  --check-fixture godot/tests/fixtures/pc_radio_voice_oracle.json \
  --output artifacts/pc-radio-oracle-new.json
```

The isolated source oracle executes 30 selection/equipment/retrieval cases and
the no-message sentinel without replacing original instructions. It proves the
radio condition gate, original queue pointers and timers, dispatcher 11 caller,
and R retrieval. It does not prove all mission triggers or live visibility.

Speech uses the existing complete current-pixel message proof. Radio identities
have a separate once-only consumer from crew identities; queued text never enters
speech. The source's R retrieval or a new report drawn while the radio is already
open may qualify. Exact caption, assignment IP and one complete source run are
required; fixed SIM captions additionally require their exact string pointer.
F5 mute consumes a newly displayed report silently. Restoring sound alone cannot
replay it, while a new original R retrieval can speak again.

`radio.wav` is an authored 950 Hz attention sample with shaped short/long bursts.
It contains no message words or encoded tactical information. Only verified
original dispatcher-11 calls at return IP 3c97 or 3cdb request it. All 409 prior
WAV files remain byte-identical after adding this effect.

Working if: a pending report plays only the notification sample, and speech first
occurs with the complete original displayed message; muted retrievals never catch
up after sound restoration.


### Live radio acceptance

`pc_radio_steps.json` records 3,716 ordinary original input frames from an Escort
mission snapshot. `pc-radio-trace-01/comparison.json` passes 13 checks against the
untouched baseline, including every input, paired RAM/video and queued state.
Only the attention sample fires at index 2614. R produces complete displayed
radio assignments at 2868, 3145 and 3482, with enabled states true/false/true.

`pc-radio-native-01/report.json` passes 26,142 checks through the production Godot
viewer and original-PC host. All 3,716 full RAM/video boundaries and source audio
events match the parity-tested trace. Genesis cockpit and high-resolution radio
type are active. Each original message crop matches its current pixel digest.
One attention sample and two generated voice streams start; the muted retrieval
is consumed silently. All 98 frames between F5 restore and the fresh R report
remain silent. Native process and child exit successfully. The seven-cue player
contract adds 229 passing checks; the six other radio captions still lack live
occurrence coverage. This route also observes original overheating and steep-slope
messages, extending their source occurrence evidence beyond isolated assignments.

```sh
python3 tools/capture_pc_dialogue.py --mode trace --radio --capture-ui \
  --state artifacts/pc-radio-scout-01/entry/reference.state \
  --output artifacts/pc-radio-trace-new
python3 tools/capture_pc_dialogue.py --mode baseline --radio \
  --state artifacts/pc-radio-scout-01/entry/reference.state \
  --output artifacts/pc-radio-baseline-new
python3 tools/verify_pc_dialogue.py \
  --trace artifacts/pc-radio-trace-new/report.json \
  --baseline artifacts/pc-radio-baseline-new/report.json \
  --output artifacts/pc-radio-trace-new/comparison.json
./tools/godot.sh --script res://tests/test_pc_radio_bridge.gd -- \
  --fixture "$PWD/artifacts/pc-radio-trace-new/report.json" \
  --output "$PWD/artifacts/pc-radio-native-new" \
  --capture --trace --play --frame-audit
```
