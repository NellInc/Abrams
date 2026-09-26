#!/usr/bin/env python3
"""Create original, deterministic PCM effects and local radio-voice scratch tracks.

Effects use only the Python standard library. Voice generation uses local eSpeak NG
and ffmpeg, never a hosted service. These synthetic takes are development casting,
not final voice performances. Original game audio is never read.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import shutil
import struct
import subprocess
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "godot/assets/audio"
RATE = 48000
LINES = {
    "ready": ("Commander", "Crew ready. Range is clear. Move out.", "en-us+m3"),
    "on_the_way": ("Gunner", "On the way!", "en-us+m2"),
    "loaded": ("Loader", "Up!", "en-us+m4"),
    "target": ("Gunner", "Target acquired.", "en-us+m2"),
    "hit": ("Commander", "Good hit.", "en-us+m3"),
    "cease_fire": ("Commander", "Cease fire. Range complete.", "en-us+m3"),
    "smoke": ("Gunner", "Smoke out.", "en-us+m2"),
    "empty": ("Loader", "No rounds remaining.", "en-us+m4"),
    "moving": ("Driver", "Moving.", "en-us+m5"),
}


def pcm(path: Path, samples: list[float], loop: bool = False) -> None:
    peak = max(max(abs(x) for x in samples), 1e-9)
    gain = min(0.89 / peak, 1.0)
    if not loop:
        for i in range(min(256, len(samples))):
            samples[i] *= i / 256
            samples[-1-i] *= i / 256
    values = (int(max(-1, min(1, x * gain)) * 32767) for x in samples)
    with wave.open(str(path), "wb") as stream:
        stream.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        stream.writeframes(struct.pack(f"<{len(samples)}h", *values))


def effect(kind: str, seconds: float, seed: int) -> list[float]:
    rng = random.Random(seed)
    low = 0.0
    result = []
    for i in range(int(seconds * RATE)):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        low += 0.035 * (noise - low)
        if kind == "cannon":
            x = 2.0 * low * math.exp(-t * 2.8)
            x += 0.65 * noise * math.exp(-t * 35)
            x += 0.5 * math.sin(2*math.pi*(62*t-9*t*t)) * math.exp(-t*5)
        elif kind == "impact":
            x = 2.5 * low * math.exp(-t * 2.2) + noise * 0.5 * math.exp(-t * 14)
            x += math.sin(t * 220) * math.exp(-t * 7) * 0.35
        elif kind == "machinegun":
            x = noise * math.exp(-t*48) * 0.65 + math.sin(t*720)*math.exp(-t*40)*0.3
        elif kind == "reload":
            x = 0.15 * noise * math.exp(-((t-0.23)/0.1)**2)
            for at in [0.02, 0.47, 0.62]:
                age = max(0.0,t-at)
                if t >= at:
                    x += (0.24*noise + 0.18*math.sin(age*1950)) * math.exp(-age*45)
        elif kind == "smoke":
            x = 0.45*noise*math.exp(-t*3) + 1.2*low*math.exp(-t*7)
        elif kind == "switch":
            x = (noise*0.22 + math.sin(t*14000)*0.17)*math.exp(-t*90)
        else:
            # Periodic turbine spectrum. Every partial repeats at the loop boundary.
            x = 0.16*math.sin(TAU*48*t) + 0.10*math.sin(TAU*96*t)
            x += 0.08*math.sin(TAU*192*t) + 0.045*math.sin(TAU*768*t)
            x += 0.03*math.sin(TAU*1536*t)*(0.5+0.5*math.sin(TAU*4*t))
        result.append(math.tanh(x))
    return result


TAU = math.pi*2


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--effects-only", action="store_true")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {"sample_rate": RATE, "effects": {}, "voice_status": "development synthetic radio takes", "voices": {}}
    for i, (kind, duration) in enumerate({"cannon":2.4,"impact":2.8,"machinegun":0.22,"reload":0.85,"smoke":1.3,"switch":0.12,"engine":2.0}.items()):
        path = OUT / f"{kind}.wav"
        pcm(path, effect(kind, duration, 1988+i), loop=kind == "engine")
        manifest["effects"][kind] = {"sha256":hashlib.sha256(path.read_bytes()).hexdigest(), "source":"original mathematical synthesis, tools/build_audio.py"}
    if not args.effects_only:
        for cmd in ["espeak-ng", "ffmpeg"]:
            if not shutil.which(cmd):
                raise SystemExit(f"Missing {cmd}; effects created. Use --effects-only or install local voice tools.")
        with tempfile.TemporaryDirectory(prefix="abrams-voice-") as tmp:
            for cue, (role, line, voice) in LINES.items():
                dry = Path(tmp) / f"{cue}.wav"
                subprocess.run(["espeak-ng", "-v",voice,"-s","155","-p","36","-w",str(dry),line],check=True)
                path = OUT / f"voice_{cue}.wav"
                subprocess.run(["ffmpeg","-v","error","-y","-i",str(dry),"-af","highpass=f=320,lowpass=f=2900,acompressor=threshold=0.12:ratio=4,volume=1.4,alimiter=limit=0.89","-ar",str(RATE),"-ac","1",str(path)],check=True)
                manifest["voices"][cue] = {"role":role,"text":line,"generator":"eSpeak NG local","voice":voice,"sha256":hashlib.sha256(path.read_bytes()).hexdigest()}
    (OUT / "provenance.json").write_text(json.dumps(manifest, indent=2)+"\n")
    print(f"Built {len(manifest['effects'])} effects and {len(manifest['voices'])} voice takes")


if __name__ == "__main__":
    main()
