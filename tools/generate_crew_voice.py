#!/usr/bin/env python3
"""Generate separate crew samples using Gemini TTS, retaining dry masters.

Only the selected dialogue and acting directions are sent to Google. Credentials
are read from Keychain at request time and never written to receipts or arguments.
The output is staged outside Godot until independently verified and installed.
"""
from __future__ import annotations
import argparse
import base64
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import urllib.error
import urllib.request
import wave

ROOT = Path(__file__).resolve().parents[1]
PREFERRED = "gemini-3.8-flash-tts"
FALLBACK = "gemini-3.1-flash-tts-preview"
BASE = "https://generativelanguage.googleapis.com/v1beta"
DIGIT_WORDS = ("zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine")


def pronounce_headings(text):
    """Keep captions numeric; speak each digit of a three-digit heading/bearing."""
    def expand(match):
        number = match.group(2)
        if not number.isascii() or not number.isdigit() or not 0 <= int(number) <= 360 or len(number) > 3:
            raise ValueError("Heading/bearing must be an integer from 0 through 360")
        return match.group(1) + " ".join(DIGIT_WORDS[int(d)] for d in number.zfill(3))
    return re.sub(r"\b((?:heading|bearing)\s+(?:is\s+)?)([+-]?\d+(?:\.\d+)?)", expand, text, flags=re.I)


def request_for(model, role, cue):
    style = role["style"] + " " + cue["direction"]
    if model == PREFERRED:
        return BASE + "/interactions", {
            "model": model,
            "input": [{"type": "user_input", "content": [{"type": "text", "text": pronounce_headings(cue["text"]),
                "annotations": [{"type": "speech_metadata", "style": style}]}]}],
            "response_format": {"type": "audio"},
            "generation_config": {"speech_config": [{"voice": role["voice"]}]}}
    if model == FALLBACK:
        # Earlier TTS uses prompt directions and raw PCM. Do not send 3.8-only
        # metadata or vocal/backchannel syntax to this API shape.
        prompt = f'Read only this transcript verbatim. {style} Transcript: "{pronounce_headings(cue["caption"])}"'
        return BASE + f"/models/{model}:generateContent", {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"responseModalities": ["AUDIO"], "speechConfig": {
                "voiceConfig": {"prebuiltVoiceConfig": {"voiceName": role["voice"]}}}}}
    raise ValueError("Unsupported crew voice model")


def decode_audio(response, model):
    if model == PREFERRED:
        parts = [p for step in response.get("steps", []) if step.get("type") == "model_output"
                 for p in step.get("content", []) if p.get("type") == "audio"]
        if len(parts) != 1:
            raise ValueError("Expected exactly one complete WAV audio block")
        raw = base64.b64decode(parts[0]["data"], validate=True)
        if raw[:4] != b"RIFF" or raw[8:12] != b"WAVE":
            raise ValueError("3.8 response did not contain its documented WAV output")
        return raw
    candidates = response.get("candidates", [])
    if len(candidates) != 1:
        raise ValueError("Expected one completed speech candidate")
    if candidates[0].get("finishReason") != "STOP":
        raise ValueError("Speech candidate was incomplete or blocked")
    parts = [p["inlineData"] for p in candidates[0].get("content", {}).get("parts", []) if "inlineData" in p]
    if len(parts) != 1:
        raise ValueError("Expected exactly one PCM audio part")
    mime = parts[0].get("mimeType", "")
    rate = re.search(r"(?:^|;)\s*rate=(\d+)(?:;|$)", mime)
    if not mime.lower().startswith("audio/l16") or rate is None:
        raise ValueError("Unrecognized PCM audio format")
    pcm = base64.b64decode(parts[0]["data"], validate=True)
    if not pcm or len(pcm) % 2:
        raise ValueError("Incomplete PCM sample")
    out = io.BytesIO()
    with wave.open(out, "wb") as writer:
        writer.setparams((1, 2, int(rate.group(1)), 0, "NONE", "not compressed"))
        writer.writeframes(pcm)
    return out.getvalue()


def validate_wav(raw):
    with wave.open(io.BytesIO(raw), "rb") as reader:
        channels, width, rate, frames, *_ = reader.getparams()
        pcm = reader.readframes(frames)
    if channels != 1 or width != 2 or not 16000 <= rate <= 96000:
        raise ValueError("Expected mono 16-bit speech at a supported rate")
    if len(pcm) != frames * 2 or not 0.15 <= frames / rate <= 20:
        raise ValueError("Truncated or implausibly short/long crew sample")
    if not any(pcm):
        raise ValueError("Speech response is silent")
    return {"sample_rate": rate, "channels": channels, "bits_per_sample": width * 8,
            "sample_frames": frames, "duration_seconds": frames / rate,
            "sha256": hashlib.sha256(raw).hexdigest()}


def keychain_secret(service, account):
    result = subprocess.run(["security", "find-generic-password", "-s", service,
                             "-a", account, "-w"], stdout=subprocess.PIPE,
                            stderr=subprocess.DEVNULL, text=True, timeout=10)
    if result.returncode or not result.stdout.strip():
        raise RuntimeError("Gemini credential unavailable in the selected Keychain item")
    return result.stdout.strip()


def generate(args):
    script = json.loads(args.script.read_text())
    jobs = {key: value for key, value in script["cues"].items() if not args.cue or key in args.cue}
    if not jobs or (args.cue and set(args.cue) - jobs.keys()):
        raise ValueError("Unknown or empty crew cue selection")
    args.output.mkdir(parents=True, exist_ok=False)
    manifest = {"provider": "Google Gemini", "model": args.model,
                "script_sha256": hashlib.sha256(args.script.read_bytes()).hexdigest(),
                "processing": "Original dry generated WAV, no audio processing",
                "status": "dry-run" if args.dry_run else "in-progress", "voices": {}}
    receipt = args.output / "manifest.json"
    receipt.write_text(json.dumps(manifest, indent=2) + "\n")
    for name, cue in jobs.items():
        if not re.fullmatch(r"[a-z_]+", name):
            raise ValueError("Unsafe cue filename")
        role = script["roles"][cue["role"]]
        url, body = request_for(args.model, role, cue)
        (args.output / f"{name}.request.json").write_text(json.dumps(body, indent=2) + "\n")
        if args.dry_run:
            continue
        secret = keychain_secret(args.keychain_service, args.keychain_account)
        request = urllib.request.Request(url, data=json.dumps(body).encode(),
            headers={"Content-Type": "application/json", "x-goog-api-key": secret})
        try:
            with urllib.request.urlopen(request, timeout=180) as response:
                data = json.load(response)
        except urllib.error.HTTPError as error:
            # No response bodies, headers or request representations in logs.
            raise RuntimeError(f"Gemini returned HTTP {error.code}; generation stopped without retry") from None
        raw = decode_audio(data, args.model)
        metrics = validate_wav(raw)
        with (args.output / f"voice_{name}.wav").open("xb") as destination:
            destination.write(raw)
        manifest["voices"][name] = {"role": cue["role"], "voice": role["voice"],
                                    "text": cue["caption"], "performed_text": pronounce_headings(cue["text"] if args.model == PREFERRED else cue["caption"]),
                                    "direction": role["style"] + " " + cue["direction"],
                                    "generator": args.model, **metrics}
        receipt.write_text(json.dumps(manifest, indent=2) + "\n")
        print(f"Generated {name}: {metrics['duration_seconds']:.2f}s, {metrics['sample_rate']} Hz", flush=True)
    manifest["status"] = "dry-run" if args.dry_run else "generated, listening review pending"
    receipt.write_text(json.dumps(manifest, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--script", type=Path, default=ROOT / "godot/data/crew_voice_script.json")
    parser.add_argument("--model", choices=(PREFERRED, FALLBACK), default=PREFERRED)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--cue", action="append")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--keychain-service", default="aiguardians-google-ai")
    parser.add_argument("--keychain-account", default="gemini-api-key")
    generate(parser.parse_args())


if __name__ == "__main__":
    main()
