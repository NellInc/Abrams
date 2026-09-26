#!/usr/bin/env python3
"""Capture original Genesis stereo PCM through the existing local reference host.

This records the running game's mixed output. It is not a MIDI conversion,
sound-driver rip, isolated instrument stem, or upgraded/remastered recording.
"""
from __future__ import annotations
import argparse
from array import array
import hashlib
import json
import math
from pathlib import Path
import sys
import wave

try:
    from .genesis_capture import BUTTONS, ROOT, ReferenceCore
except ImportError:
    from genesis_capture import BUTTONS, ROOT, ReferenceCore


def parse_sequence(raw):
    steps = []
    for value in raw.split(","):
        count, *buttons = value.split("+")
        count = int(count)
        if not 1 <= count <= 36000 or any(b not in BUTTONS for b in buttons):
            raise ValueError("Expected 1..36000 frames and known controller buttons")
        steps.append((count, buttons))
    if sum(s[0] for s in steps) > 36000:
        raise ValueError("A reference recording is limited to 36000 emulated frames")
    return steps


class WaveSink:
    """Streaming little-endian 16-bit stereo, without gain or resampling."""
    def __init__(self, filename: Path, sample_rate: float):
        if not math.isfinite(sample_rate) or sample_rate != int(sample_rate) or not 8000 <= sample_rate <= 192000:
            raise ValueError("Core did not report a supported integral sample rate")
        self.file = filename.open("xb")
        self.writer = wave.open(self.file, "wb")
        self.writer.setparams((2, 2, int(sample_rate), 0, "NONE", "not compressed"))
        self.frames = 0

    def write(self, raw: bytes):
        if len(raw) % 4:
            raise ValueError("Stereo audio callback contained an incomplete frame")
        if sys.byteorder == "big":
            values = array("h", raw)
            values.byteswap()
            raw = values.tobytes()
        self.writer.writeframesraw(raw)
        self.frames += len(raw) // 4

    def close(self):
        try:
            self.writer.close()
        finally:
            self.file.close()


def audio_metrics(filename: Path):
    peak = nonzero = endpoints = samples = energy = 0
    with wave.open(str(filename), "rb") as reader:
        if reader.getnchannels() != 2 or reader.getsampwidth() != 2:
            raise ValueError("Expected stereo signed 16-bit PCM")
        sample_rate, frames = reader.getframerate(), reader.getnframes()
        while raw := reader.readframes(65536):
            values = array("h", raw)
            if sys.byteorder == "big":
                values.byteswap()
            samples += len(values)
            for value in values:
                peak = max(peak, abs(value))
                nonzero += value != 0
                endpoints += value in (-32768, 32767)
                energy += value * value
    if samples != frames * 2 or not frames:
        raise ValueError("Empty or truncated reference recording")
    rms = math.sqrt(energy / samples)
    return {"sample_rate": sample_rate, "channels": 2, "bits_per_sample": 16,
            "sample_frames": frames, "duration_seconds": frames / sample_rate,
            "peak_integer": peak, "peak_dbfs": 20 * math.log10(peak / 32768) if peak else None,
            "rms_dbfs": 20 * math.log10(rms / 32768) if rms else None,
            "nonzero_samples": nonzero, "samples_at_integer_limits": endpoints,
            "sha256": hashlib.sha256(filename.read_bytes()).hexdigest()}


def capture(args):
    steps = parse_sequence(args.sequence)
    args.output.mkdir(parents=True, exist_ok=False)
    core = ReferenceCore(args.core, args.rom, ROOT / ".runtime/genesis/saves")
    sink = None
    timeline = []
    try:
        if args.restore:
            core.restore(args.restore)
        info = core.av_info()
        sink = WaveSink(args.output / "original.wav", info.timing.sample_rate)
        core.audio_sink = sink.write
        for frames, buttons in steps:
            start = sink.frames
            core.run(frames, buttons)
            timeline.append({"emulated_frames": frames, "buttons": buttons,
                             "audio_frame_start": start, "audio_frame_end": sink.frames})
        core.audio_sink = None
        sink.close()
        sink = None
        core.screenshot().save(args.output / "end-screen.png")
        metrics = audio_metrics(args.output / "original.wav")
        expected_seconds = core.frame / info.timing.fps
        if abs(metrics["duration_seconds"] - expected_seconds) > 2 / info.timing.fps:
            raise ValueError("Captured sample count disagrees with the core's reported timing")
        manifest = {"label": args.label, "method": "Unmodified emulator mixed PCM output",
                    "role": "Genesis audiovisual reference only; PC gameplay remains definitive",
                    "rom": args.rom.name, "rom_sha256": hashlib.sha256(core.rom_bytes).hexdigest(),
                    "core_sha256": hashlib.sha256(args.core.read_bytes()).hexdigest(),
                    "restore": str(args.restore) if args.restore else None,
                    "restore_sha256": hashlib.sha256(args.restore.read_bytes()).hexdigest() if args.restore else None,
                    "video_fps": info.timing.fps, "emulated_frames": core.frame,
                    "sequence": args.sequence, "timeline": timeline, "audio": metrics,
                    "core_options": {k.decode(): v.decode() for k, v in core.variables.items()},
                    "processing": "No gain, normalization, denoising, resampling, trim or fade"}
        (args.output / "receipt.json").write_text(json.dumps(manifest, indent=2) + "\n")
        print(json.dumps({"output": str(args.output), "audio": metrics}, indent=2))
    finally:
        core.audio_sink = None
        if sink is not None:
            sink.close()
        core.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom", type=Path, default=ROOT / "GENESIS/M-1 Abrams Battle Tank (USA, Europe).md")
    parser.add_argument("--core", type=Path, default=ROOT / ".runtime/genesis/genesis_plus_gx_libretro.dylib")
    parser.add_argument("--restore", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--sequence", default="1800", help="Comma-separated frames[+button] steps")
    parser.add_argument("--label", required=True)
    capture(parser.parse_args())


if __name__ == "__main__":
    main()
