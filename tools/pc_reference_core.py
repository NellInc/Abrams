#!/usr/bin/env python3
"""Bounded DOSBox Pure host for original-PC state/renderer bridge research.

The original game stays inside a ZIP; writes go to a separate save directory.
Memory access is read-only. This is a research backend, not a shipped emulator.
"""
from __future__ import annotations

import ctypes as C
import hashlib
import json
import sys
from pathlib import Path

from PIL import Image

try:
    from tools.genesis_capture import AVInfo, GameInfo, Variable
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from genesis_capture import AVInfo, GameInfo, Variable

def core_suffix():
    return ".dll" if sys.platform == "win32" else ".dylib" if sys.platform == "darwin" else ".so"


CORE_SHA256 = "f21c70074c8432a634d82e9daa187a9424c629d9d503270a7a663d0751ebc3d8"
KEYS = {"backspace": 8, "tab": 9, "return": 13, "escape": 27, "space": 32, "up": 273,
        "down": 274, "right": 275, "left": 276, "shift": 304, "ctrl": 306, "alt": 308,
        **{f"kp{i}": 256 + i for i in range(10)},
        **{f"f{i}": 281 + i for i in range(1, 13)},
        **{chr(i): i for i in range(48, 58)}, **{chr(i): i for i in range(97, 123)}}
KEY_CALLBACK = C.CFUNCTYPE(None, C.c_bool, C.c_uint, C.c_uint32, C.c_uint16)


class MemoryDescriptor(C.Structure):
    _fields_ = [("flags", C.c_uint64), ("ptr", C.c_void_p),
                ("offset", C.c_size_t), ("start", C.c_size_t),
                ("select", C.c_size_t), ("disconnect", C.c_size_t),
                ("length", C.c_size_t), ("address_space", C.c_char_p)]


class MemoryMap(C.Structure):
    _fields_ = [("descriptors", C.POINTER(MemoryDescriptor)), ("count", C.c_uint)]


class ThrottleState(C.Structure):
    _fields_ = [("mode", C.c_uint), ("rate", C.c_float)]


class PcReferenceCore:
    def __init__(self, library: Path, content: Path, saves: Path, *, expected_sha256: str = CORE_SHA256):
        # The ordinary bridge retains the reviewed upstream-binary pin. Separate
        # source-built research variants must explicitly supply their build pin;
        # this does not establish their timing/memory compatibility.
        if (len(expected_sha256) != 64 or any(c not in "0123456789abcdef" for c in expected_sha256)
                or hashlib.sha256(library.read_bytes()).hexdigest() != expected_sha256):
            raise ValueError("memory/thread assumptions require the fingerprinted DOSBox Pure core")
        self.core_sha256 = expected_sha256
        if content.suffix.lower() != ".zip":
            raise ValueError("load a ZIP to keep source game writes isolated")
        saves.mkdir(parents=True, exist_ok=True)
        self.directory = str(saves.resolve()).encode()
        self.core = C.CDLL(str(library.resolve()))
        self.callbacks = []
        self.variables = {}
        self.overrides = {
            b"dosbox_pure_conf": b"inside", b"dosbox_pure_machine": b"ega",
            b"dosbox_pure_cpu_core": b"normal", b"dosbox_pure_cpu_type": b"386",
            b"dosbox_pure_cycles": b"3000", b"dosbox_pure_auto_mapping": b"false",
            b"dosbox_pure_voodoo": b"off", b"dosbox_pure_voodoo_perf": b"0",
        }
        self.memory_maps = []
        self.keyboard = None
        self.pressed = set()
        self.last_video = None
        self.last_video_ram = None
        self.frame = 0
        self.callback_error = None
        self.shutdown = False
        bindings = [
            ("environment", C.CFUNCTYPE(C.c_bool, C.c_uint, C.c_void_p), self._environment),
            ("video_refresh", C.CFUNCTYPE(None, C.c_void_p, C.c_uint, C.c_uint, C.c_size_t), self._video),
            ("audio_sample", C.CFUNCTYPE(None, C.c_int16, C.c_int16), lambda *_: None),
            ("audio_sample_batch", C.CFUNCTYPE(C.c_size_t, C.c_void_p, C.c_size_t), lambda _, n: n),
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
        self.core.retro_get_system_av_info.argtypes = [C.POINTER(AVInfo)]
        self.core.retro_get_system_av_info.restype = None
        self.core.retro_serialize_size.restype = C.c_size_t
        self.core.retro_serialize.argtypes = [C.c_void_p, C.c_size_t]
        self.core.retro_serialize.restype = C.c_bool
        self.core.retro_unserialize.argtypes = [C.c_void_p, C.c_size_t]
        self.core.retro_unserialize.restype = C.c_bool
        self.core.retro_init()
        self.content_path = str(content.resolve()).encode()
        info = GameInfo(self.content_path, None, 0, None)
        if not self.core.retro_load_game(C.byref(info)):
            self.core.retro_deinit()
            raise RuntimeError("DOSBox Pure rejected reference ZIP")
        self._check()
        self.pause_at_frame_end()

    def _check(self):
        if self.callback_error:
            raise RuntimeError("DOS reference callback failed") from self.callback_error
        if self.shutdown:
            raise RuntimeError("DOS reference requested shutdown")

    def _environment(self, command, data):
        try:
            if command in (9, 31):
                C.cast(data, C.POINTER(C.c_char_p))[0] = self.directory
                return True
            if command == 3:
                C.cast(data, C.POINTER(C.c_bool))[0] = True
                return True
            if command == 10:
                return C.cast(data, C.POINTER(C.c_uint))[0] == 1  # XRGB8888
            if command == 12:
                self.keyboard = C.cast(data, C.POINTER(KEY_CALLBACK))[0]
                return True
            if command == 16:
                entries = C.cast(data, C.POINTER(Variable))
                for i in range(512):
                    if not entries[i].key:
                        return True
                    self.variables[entries[i].key] = entries[i].value.split(b"; ")[-1].split(b"|")[0]
                raise ValueError("unterminated core option list")
            if command == 15:
                entry = C.cast(data, C.POINTER(Variable)).contents
                value = self.overrides.get(entry.key, self.variables.get(entry.key))
                if value is None:
                    return False
                entry.value = value
                return True
            if command == 17:
                C.cast(data, C.POINTER(C.c_bool))[0] = False
                return True
            if command == (71 | 0x10000):
                state = C.cast(data, C.POINTER(ThrottleState)).contents
                state.mode, state.rate = 1, 0.0  # explicit single-frame stepping
                return True
            if command in (39, 52):
                C.cast(data, C.POINTER(C.c_uint))[0] = 0
                return True
            if command == (36 | 0x10000):
                mapping = C.cast(data, C.POINTER(MemoryMap)).contents
                if not 1 <= mapping.count <= 8:
                    raise ValueError("unexpected memory map count")
                self.memory_maps = [MemoryDescriptor.from_buffer_copy(mapping.descriptors[i])
                                    for i in range(mapping.count)]
                return True
            if command in (32, 37):
                return True
            if command == 7:
                self.shutdown = True
                return True
            return False
        except Exception as error:
            self.callback_error = error
            return False

    def _video(self, data, width, height, pitch):
        try:
            if data:
                if not 1 <= width <= 2048 or not 1 <= height <= 2048 or not width * 4 <= pitch <= 16384:
                    raise ValueError("unexpected software framebuffer geometry")
                self.last_video = (C.string_at(data, pitch * height), width, height, pitch)
        except Exception as error:
            self.callback_error = error

    def pause_at_frame_end(self):
        # In this pinned core, AV-info calls TCM_FINISH_FRAME and leaves the
        # emulation worker paused. retro_run alone returns with it running.
        # Never read shared RAM without this fence.
        info = AVInfo()
        self.core.retro_get_system_av_info(C.byref(info))
        self._check()
        return info

    def set_keys(self, names):
        keys = {KEYS[name] for name in names}
        if not self.keyboard:
            raise RuntimeError("keyboard callback not registered")
        for key in sorted(self.pressed - keys):
            self.keyboard(False, key, 0, 0)
        # Physical modifier down must precede the printable key in one held
        # input set, so original DOS receives its Shift+3 (#) speed command.
        # The original also polls scancode 3 for AX; preserve that side effect.
        for key in sorted(keys - self.pressed, key=lambda k: (k not in (304,306,308),k)):
            self.keyboard(True, key, key if 32 <= key < 127 else 0, 0)
        self.pressed = keys

    def _input(self, port, device, index, key):
        # DOSBox Pure polls physical keys to release stale keyboard callbacks.
        # Reporting zero here truncates every hold to a momentary key press.
        return int(port == 0 and device == 3 and index == 0 and key in self.pressed)

    def run(self, count, keys=()):
        if not 1 <= count <= 36000:
            raise ValueError("bounded frame count required")
        self.set_keys(keys)
        for index in range(count):
            if index == count - 1:
                # retro_run submits the already completed framebuffer before
                # advancing another frame. Pair it with RAM from that boundary.
                self.last_video_ram = self.conventional_memory()
            self.core.retro_run()
            self.frame += 1
            self._check()
        self.pause_at_frame_end()

    def conventional_memory(self):
        self.pause_at_frame_end()
        maps = {m.start: m for m in self.memory_maps}
        if 0 not in maps or 0x100000 not in maps:
            raise ValueError("expected DOS game/OS memory maps")
        game, os = maps[0], maps[0x100000]
        if (game.length + os.length != 640 * 1024 or not os.ptr or not game.ptr
                or game.ptr != os.ptr + os.length
                or any(m.offset or m.select or m.disconnect for m in (game, os))):
            raise ValueError("unrecognized conventional memory mapping")
        return C.string_at(os.ptr, os.length) + C.string_at(game.ptr, game.length)

    def screenshot(self):
        if self.last_video is None:
            raise RuntimeError("no software framebuffer received")
        raw, width, height, pitch = self.last_video
        return Image.frombytes("RGB", (width, height), raw, "raw", "BGRX", pitch)

    def dump(self, directory: Path):
        # RAM is from the next completed VGA frame relative to last_video.
        # Keep that known offset explicit until a synchronized bridge is built.
        ram = self.conventional_memory()
        directory.mkdir(parents=True, exist_ok=False)
        self.screenshot().save(directory / "screen.png")
        (directory / "conventional.bin").write_bytes(ram)
        size = self.core.retro_serialize_size()
        if not 0 < size <= 128 * 1024 * 1024:
            raise ValueError("invalid serialized-state size")
        state = C.create_string_buffer(size)
        if not self.core.retro_serialize(state, size):
            raise RuntimeError("original reference serialization failed")
        (directory / "reference.state").write_bytes(state.raw)
        self.pause_at_frame_end()
        receipt = {"core_sha256": self.core_sha256, "retro_run_count": self.frame,
                   "memory_basis": "physical conventional RAM, 640 KiB",
                   "video_memory_alignment": "video precedes RAM by one completed VGA frame",
                   "options": {k.decode(): v.decode() for k, v in (self.variables | self.overrides).items()},
                   "files": {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                             for p in directory.iterdir() if p.is_file()}}
        receipt["pressed_keys"] = sorted(self.pressed)
        receipt["throttle"] = "FRAME_STEPPING"
        (directory / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")

    def restore(self, path: Path, *, expected_source_sha256: str | None = None):
        raw = path.read_bytes()
        if not 0 < len(raw) <= 128 * 1024 * 1024:
            raise ValueError("invalid saved-state size")
        # The research restore contract supports neutral-key snapshots only.
        # Do not silently clear a held-key snapshot and call that exact replay.
        receipt_path = path.with_name("receipt.json")
        if receipt_path.exists():
            receipt = json.loads(receipt_path.read_text())
            source_pin = expected_source_sha256 or self.core_sha256
            if receipt.get("core_sha256") != source_pin or receipt.get("pressed_keys"):
                raise ValueError("restore requires this core and a neutral-key snapshot")
            if receipt.get("files", {}).get(path.name) != hashlib.sha256(raw).hexdigest():
                raise ValueError("saved-state fingerprint mismatch")
        self.set_keys(())
        self.pause_at_frame_end()
        buffer = C.create_string_buffer(raw)
        if not self.core.retro_unserialize(buffer, len(raw)):
            raise ValueError("DOS core rejected saved state")
        self.pressed.clear()
        self.last_video = self.last_video_ram = None
        self.pause_at_frame_end()

    def local_overlay(self, operation):
        """Pinned checkpoint ABI; caller owns the exclusive overlay lock."""
        self.pause_at_frame_end()
        abi = self.core.abrams_state_overlay_abi
        abi.restype = C.c_uint
        if abi() != 1: raise ValueError("unsupported checkpoint overlay ABI")
        function = getattr(self.core, 'abrams_state_' + operation + '_overlay')
        function.argtypes = []
        function.restype = C.c_bool
        if not function(): raise ValueError("Native checkpoint overlay " + operation + " failed")
        self.pause_at_frame_end()

    def observer_checkpoint(self, raw=None):
        """Exact-core, host-only EGA ownership companion at the native fence."""
        self.pause_at_frame_end()
        abi = self.core.abrams_observer_checkpoint_abi
        abi.argtypes, abi.restype = [], C.c_uint
        size_fn = self.core.abrams_observer_checkpoint_size
        size_fn.argtypes, size_fn.restype = [], C.c_size_t
        size = size_fn()
        if abi() != 1 or not 0 < size <= 2 * 1024 * 1024:
            raise ValueError("unsupported observer checkpoint ABI")
        if raw is not None and len(raw) != size:
            raise ValueError("invalid observer checkpoint size")
        buffer = C.create_string_buffer(size) if raw is None else C.create_string_buffer(raw, size)
        function = getattr(self.core, 'abrams_observer_checkpoint_' + ('save' if raw is None else 'load'))
        function.argtypes, function.restype = [C.c_void_p, C.c_size_t], C.c_bool
        if not function(buffer, size):
            raise ValueError("Observer checkpoint does not match the restored native display")
        return buffer.raw

    def serialize_local(self):
        """Native bytes at the paused logical boundary, without keyboard edits."""
        self.pause_at_frame_end()
        size = self.core.retro_serialize_size()
        if not 0 < size <= 128 * 1024 * 1024:
            raise ValueError("invalid serialized-state size")
        state = C.create_string_buffer(size)
        if not self.core.retro_serialize(state, size):
            raise ValueError("The original game is not ready for a checkpoint yet")
        self.pause_at_frame_end()
        return state.raw

    def restore_local(self, raw, keys, frame, ram_sha256):
        """Validated local checkpoint, separate from the neutral research guard.

        A fresh process is mandatory: the upstream library cannot safely be
        unloaded and reinitialized in one process. Establish physical inputs
        before restore so its keyboard reconciliation preserves held keys.
        """
        if not 0 < len(raw) <= 128 * 1024 * 1024:
            raise ValueError("invalid saved-state size")
        if (not isinstance(keys, list) or len(keys) > 16 or len(set(keys)) != len(keys)
                or any(key not in KEYS for key in keys)):
            raise ValueError("invalid checkpoint keyboard set")
        self.set_keys(keys)
        self.pause_at_frame_end()
        buffer = C.create_string_buffer(raw)
        if not self.core.retro_unserialize(buffer, len(raw)):
            raise ValueError("DOS core rejected checkpoint")
        self.pause_at_frame_end()
        if hashlib.sha256(self.conventional_memory()).hexdigest() != ram_sha256:
            raise ValueError("Restored RAM does not match the checkpoint")
        self.frame = frame
        self.last_video = self.last_video_ram = None

    def close(self):
        self.core.retro_unload_game()
        self.core.retro_deinit()
