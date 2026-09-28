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
