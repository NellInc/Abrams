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
are unaffected. Working if: request payload tests contain the digit words, and
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

The opt-in `PC Bridge.command --audio` pilot reuses only “On the way!” at the
original accepted cannon request and “Smoke out.” at the original smoke request.
It does not borrow training-range outcomes or interpret “Good hit” as an incoming
hit. The loader call is withheld pending original readiness-display timing.
All bearing calls still require digit-wise speech with numeric captions.
See [original audio research](pc-audio-research.md) for the live event boundary.
