---
name: abrams-emotive-speech
description: Produce emotionally directed Abrams promo narration through OpenRouter using Gemini 3.8 Flash TTS and secure Keychain credentials.
---

Discover speech models with `GET https://openrouter.ai/api/v1/models?output_modalities=speech`. Verify the selected model and exact `supported_voices` before a paid request. Prefer `google/gemini-3.8-flash-tts`, voice `Orus`, when listed.

Read the OpenRouter secret from macOS Keychain directly into the requesting process. Never put a secret in a file, argument, receipt or log. Stop on an ambiguous paid submission; check the existing job or result before any retry.

For `POST /api/v1/audio/speech`, send the spoken script as `input` and the voice separately. The verified Google contract puts direction in `provider.options["google-ai-studio"].speech_metadata.style`; Gemini 3.8 reads `input` verbatim. Recheck the current contract if it changes. Preserve a dry WAV master and a sanitized model/cost receipt. TTS generates speech; the skill and script are authored separately.

Direction comes from the current brief: Nell replaced professorly delivery with an engaging, thrilling promo. Use firm crew-command diction, controlled urgency and a confident closing, while preserving her intentional short sentences. Aim near 160 words per minute across the spoken portion. Avoid exaggerated trailer gravel, shouting and reading stage directions aloud. Working if: the approved 149-word script remains intelligible in the sixty-second edit, with its emotional contour audible.

Transcribe the generated audio independently, compare against the exact approved script and check its duration before assembling. Correct a failed passage within the approved budget; do not silently replace Gemini with another voice model.

Working if: the dry master contains only the approved spoken words, the narration matches the chosen model/voice receipt, and its timing leaves room for the closing dedication.
