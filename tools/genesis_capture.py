#!/usr/bin/env python3
"""Local, headless reference capture through Genesis Plus GX's libretro ABI.

Never distributes or modifies the supplied ROM. VDP dumps use this core's native
in-memory format, recorded in each receipt, rather than pretending to be ROM files.
Requires Pillow and a locally supplied Genesis Plus GX shared library.
"""
from __future__ import annotations

import argparse
import ctypes as C
import hashlib
import json
from pathlib import Path
import struct
import sys

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BUTTONS = {"b": 0, "start": 3, "up": 4, "down": 5, "left": 6,
           "right": 7, "c": 8, "a": 1}


class GameInfo(C.Structure):
    _fields_ = [("path", C.c_char_p), ("data", C.c_void_p),
                ("size", C.c_size_t), ("meta", C.c_char_p)]


class Variable(C.Structure):
    _fields_ = [("key", C.c_char_p), ("value", C.c_char_p)]


class Geometry(C.Structure):
    _fields_ = [("base_width", C.c_uint), ("base_height", C.c_uint),
                ("max_width", C.c_uint), ("max_height", C.c_uint),
                ("aspect_ratio", C.c_float)]


class Timing(C.Structure):
    _fields_ = [("fps", C.c_double), ("sample_rate", C.c_double)]


class AVInfo(C.Structure):
    _fields_ = [("geometry", Geometry), ("timing", Timing)]


class ReferenceCore:
    def __init__(self, library: Path, rom: Path, directory: Path):
        self.library, self.rom = library.resolve(), rom.resolve()
        self.core = C.CDLL(str(self.library))
        self.directory = str(directory.resolve()).encode()
        directory.mkdir(parents=True, exist_ok=True)
        self.pixel_format = 0
        self.frame = 0
        self.pressed: set[int] = set()
        self.variables: dict[bytes, bytes] = {}
        self.last_video = None
        self.capture_video = False
        self.audio_sink = None
        self.audio_error = None
        self.callbacks = []
        self.rom_bytes = rom.read_bytes()
        if self.rom_bytes[0x100:0x104] != b"SEGA":
            raise ValueError("Expected an uninterleaved Genesis ROM with SEGA header")
        self.rom_buffer = C.create_string_buffer(self.rom_bytes)
        # Keep every callback and every buffer alive until retro_deinit.
        bindings = [
            ("environment", C.CFUNCTYPE(C.c_bool, C.c_uint, C.c_void_p), self._environment),
            ("video_refresh", C.CFUNCTYPE(None, C.c_void_p, C.c_uint, C.c_uint, C.c_size_t), self._video),
            ("audio_sample", C.CFUNCTYPE(None, C.c_int16, C.c_int16), self._audio_sample),
            ("audio_sample_batch", C.CFUNCTYPE(C.c_size_t, C.c_void_p, C.c_size_t), self._audio_batch),
            ("input_poll", C.CFUNCTYPE(None), lambda: None),
            ("input_state", C.CFUNCTYPE(C.c_int16, C.c_uint, C.c_uint, C.c_uint, C.c_uint), self._input),
        ]
        for name, signature, function in bindings:
            callback = signature(function)
            self.callbacks.append(callback)
            setter = getattr(self.core, "retro_set_" + name)
            setter.argtypes = [signature]
            setter(callback)
        self.core.retro_load_game.argtypes = [C.POINTER(GameInfo)]
        self.core.retro_load_game.restype = C.c_bool
        self.core.retro_serialize_size.restype = C.c_size_t
        self.core.retro_serialize.argtypes = [C.c_void_p, C.c_size_t]
        self.core.retro_serialize.restype = C.c_bool
        self.core.retro_unserialize.argtypes = [C.c_void_p, C.c_size_t]
        self.core.retro_unserialize.restype = C.c_bool
        self.core.retro_get_system_av_info.argtypes = [C.POINTER(AVInfo)]
        self.core.retro_get_system_av_info.restype = None
        self.core.retro_init()
        info = GameInfo(str(self.rom).encode(), C.cast(self.rom_buffer, C.c_void_p), len(self.rom_bytes), None)
        if not self.core.retro_load_game(C.byref(info)):
            self.core.retro_deinit()
            raise RuntimeError("Reference core rejected the ROM")
        self.core.retro_set_controller_port_device(0, 1)

    def av_info(self) -> AVInfo:
        info = AVInfo()
        self.core.retro_get_system_av_info(C.byref(info))
        return info

    def _write_audio(self, raw):
        if self.audio_sink is not None and self.audio_error is None:
            try:
                self.audio_sink(raw)
            except Exception as error:
                # ctypes callbacks cannot propagate exceptions through C. Surface
                # the failure immediately after retro_run returns instead.
                self.audio_error = error

    def _audio_sample(self, left, right):
        self._write_audio(struct.pack("=hh", left, right))

    def _audio_batch(self, data, frames):
        if self.audio_sink is not None:
            self._write_audio(C.string_at(data, frames * 4))
        return frames

    def _environment(self, command, data):
        if command in (9, 31):
            C.cast(data, C.POINTER(C.c_char_p))[0] = self.directory
            return True
        if command == 3:
            C.cast(data, C.POINTER(C.c_bool))[0] = True
            return True
        if command == 10:
            value = C.cast(data, C.POINTER(C.c_uint))[0]
            if value not in (0, 1, 2):
                return False
            self.pixel_format = value
            return True
        if command == 16:
            entries = C.cast(data, C.POINTER(Variable))
            i = 0
            while entries[i].key:
                raw = entries[i].value or b""
                self.variables[entries[i].key] = raw.split(b"; ")[-1].split(b"|")[0]
                i += 1
            return True
        if command == 15:
            entry = C.cast(data, C.POINTER(Variable)).contents
            if entry.key in self.variables:
                entry.value = self.variables[entry.key]
                return True
            return False
        if command == 17:
            C.cast(data, C.POINTER(C.c_bool))[0] = False
            return True
        if command == 52:
            C.cast(data, C.POINTER(C.c_uint))[0] = 0
            return True
        return False

    def _input(self, port, device, index, button):
        return int(port == 0 and (device & 255) == 1 and button in self.pressed)

    def _video(self, data, width, height, pitch):
        if data and self.capture_video:
            self.last_video = (C.string_at(data, pitch * height), width, height, pitch)

    def run(self, count: int, buttons=()):
        self.pressed = {BUTTONS[x] for x in buttons}
        for i in range(count):
            self.capture_video = i == count - 1
            self.core.retro_run()
            if self.audio_error is not None:
                raise RuntimeError("Reference audio capture failed") from self.audio_error
            self.frame += 1
        self.pressed.clear()

    def restore(self, filename: Path):
        raw = filename.read_bytes()
        buffer = C.create_string_buffer(raw)
        if not self.core.retro_unserialize(buffer, len(raw)):
            raise ValueError("Core rejected reference state")
        # These are host observations, not part of the restored guest state.
        # A prior frame must never be presented as a frame from this restore.
        self.frame = 0
        self.last_video = None
        self.capture_video = False
        self.pressed.clear()

    def screenshot(self) -> Image.Image:
        if self.last_video is None:
            raise RuntimeError("No rendered frame received")
        raw, width, height, pitch = self.last_video
        if self.pixel_format == 1:
            return Image.frombytes("RGB", (width, height), raw, "raw", "BGRX", pitch)
        colors = []
        for y in range(height):
            row = struct.unpack("=" + "H" * width, raw[y * pitch:y * pitch + width * 2])
            for p in row:
                if self.pixel_format == 2:
                    colors.append((((p >> 11) & 31) * 255 // 31,
                                   ((p >> 5) & 63) * 255 // 63, (p & 31) * 255 // 31))
                else:
                    colors.append((((p >> 10) & 31) * 255 // 31,
                                   ((p >> 5) & 31) * 255 // 31, (p & 31) * 255 // 31))
        result = Image.new("RGB", (width, height))
        result.putdata(colors)
        return result

    def dump(self, destination: Path):
        destination.mkdir(parents=True, exist_ok=False)
        self.screenshot().save(destination / "screen.png")
        for symbol, size in (("vram", 65536), ("cram", 128), ("vsram", 128), ("reg", 32)):
            raw = bytes((C.c_ubyte * size).in_dll(self.core, symbol))
            (destination / (symbol + ".bin")).write_bytes(raw)
        size = self.core.retro_serialize_size()
        state = C.create_string_buffer(size)
        if not self.core.retro_serialize(state, size):
            raise RuntimeError("Reference serialization failed")
        (destination / "reference.state").write_bytes(state.raw)
        receipt = {
            "rom": self.rom.name, "rom_sha256": hashlib.sha256(self.rom_bytes).hexdigest(),
            "core_sha256": hashlib.sha256(self.library.read_bytes()).hexdigest(),
            "frames_since_load_or_restore": self.frame, "pixel_format": self.pixel_format,
            "host_byteorder": sys.byteorder,
            "memory_format": "Genesis Plus GX native exports. CRAM is native-endian packed BBBGGGRRR, NOT bus-format 0BBB0GGG0RRR0.",
            "options": {k.decode(): v.decode() for k, v in self.variables.items()},
            "files": {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                      for p in sorted(destination.iterdir()) if p.is_file()},
        }
        (destination / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
        print(f"Captured frame {self.frame}: {destination}")

    def close(self):
        self.core.retro_unload_game()
        self.core.retro_deinit()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom", type=Path, default=ROOT / "GENESIS/M-1 Abrams Battle Tank (USA, Europe).md")
    parser.add_argument("--core", type=Path, default=ROOT / ".runtime/genesis/genesis_plus_gx_libretro.dylib")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--restore", type=Path)
    parser.add_argument("--sequence", default="180:title", help="Comma-separated frames[+button+button][:capture-name] steps")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    core = ReferenceCore(args.core, args.rom, ROOT / ".runtime/genesis/saves")
    try:
        if args.restore:
            core.restore(args.restore)
        for step in args.sequence.split(","):
            frame_spec, _, name = step.partition(":")
            frame_count, *buttons = frame_spec.split("+")
            count = int(frame_count)
            if not 1 <= count <= 36000:
                raise ValueError("Each step must run between 1 and 36000 frames")
            if name and (Path(name).name != name or name in (".", "..")):
                raise ValueError("Capture names must be single safe path components")
            core.run(count, buttons)
            if name:
                core.dump(args.output / name)
        (args.output / "sequence.json").write_text(json.dumps({"sequence": args.sequence, "restore": str(args.restore) if args.restore else None}, indent=2) + "\n")
    finally:
        core.close()


if __name__ == "__main__":
    main()
