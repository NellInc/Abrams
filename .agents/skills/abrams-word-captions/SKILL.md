---
name: abrams-word-captions
description: Generate and validate word-level timed subtitles from the final Abrams promo audio using an ASR model, with SRT, VTT and optional burned-in output.
---

Transcribe the final video mix, not the source script. Prefer local faster-whisper with `word_timestamps=True`; OpenRouter's transcription endpoint may be used if its current contract supports word timings. Do not infer ASR timestamps by dividing the script duration.

Save the ASR word records and exact source-media hash. Align against the approved narration to flag omissions, additions and names. Correct display spelling from the script only after verifying what was actually spoken. Keep original ASR evidence.

Group words into readable sentence fragments, ordinarily two lines or fewer. Preserve punctuation and use conventional sentence case. Keep captions inside safe margins, avoid obscuring game instruments and put export options in SRT and WebVTT. An optional burned-in export should use phrase captions rather than distracting word-by-word effects.

Check strictly ordered word boundaries, positive durations, no overlapping caption cues and no cue beyond the final video duration. Review sampled frames where captions meet dense game UI.

Working if: the subtitle timing is ASR-derived from the actual final mix, wording agrees with audible narration, and all timing and safe-area checks pass.
