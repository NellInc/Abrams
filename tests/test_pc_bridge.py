from pathlib import Path
import ctypes as C
import struct
import unittest
import hashlib
import json
import tempfile
from types import SimpleNamespace

from tools.pc_live_state import SimStateReader, bearing
from tools.pc_reference_core import PcReferenceCore, KEYS, MemoryDescriptor, ThrottleState
from tools.pc_bridge_host import validate_command

ROOT = Path(__file__).resolve().parents[1]


class PcBridgeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.reader = SimStateReader(ROOT / "GAME/SIM.EXE")

    def fixture(self):
        ram = bytearray(640 * 1024)
        base, ds = 0x1ED0, 0x1BCD0
        for offset, anchor in self.reader.anchors:
            ram[base + offset:base + offset + len(anchor)] = anchor
        body, turret = 0x709E, 0x8FE0
        struct.pack_into("<HH", ram, ds + 0x7999, turret, body)
        struct.pack_into("<3H", ram, ds + body + 4, 2048, 2048, 50)
        struct.pack_into("<4h", ram, ds + 0x79B4, 80, 10, 6, 18)
        return ram, ds, body, turret

    def test_anchor_rejects_absent_incomplete_and_ambiguous_images(self):
        self.assertIsNone(self.reader.read(bytes(640 * 1024)))
        with self.assertRaises(ValueError):
            self.reader.read(bytes(1024))
        ram, *_ = self.fixture()
        ram[0x1ED0 + 0x6790] ^= 1
        self.assertIsNone(self.reader.locate(ram))
        ram, *_ = self.fixture()
        for offset, anchor in self.reader.anchors:
            ram[0x40000 + offset:0x40000 + offset + len(anchor)] = anchor
        with self.assertRaisesRegex(ValueError, "ambiguous"):
            self.reader.locate(ram)

    def test_read_only_state_uses_original_numeric_conventions(self):
        ram, ds, body, turret = self.fixture()
        ram[ds + body + 26], ram[ds + turret + 11] = 185, 71
        struct.pack_into("<h", ram, ds + body + 36, -66)
        before = bytes(ram)
        state = self.reader.read(ram)
        self.assertEqual(state["heading_degrees"], 100)
        self.assertEqual(state["bearing_degrees"], 0)
        self.assertEqual(state["speed_display"], -86)
        self.assertEqual(state["ammunition"], {"COAX": 80, "HEAT": 10, "SABOT": 6, "AX": 18})
        self.assertEqual(state["position_units"], "unverified-original-units")
        self.assertEqual(bytes(ram), before)

    def test_uninitialized_or_unknown_fields_fail_closed(self):
        for offset, value in ((0x7999, 0), (0x799B, 65535)):
            ram, ds, *_ = self.fixture()
            struct.pack_into("<H", ram, ds + offset, value)
            self.assertIsNone(self.reader.read(ram))
        for offset, value in ((0x799D, 4), (0x79A9, 3)):
            ram, ds, *_ = self.fixture()
            ram[ds + offset] = value
            self.assertIsNone(self.reader.read(ram))

    def test_bearings_match_executed_original_fixture(self):
        import json
        fixture = json.loads((ROOT / "godot/tests/fixtures/pc_bearings.json").read_text())
        self.assertEqual(fixture["row_fields"], ["internal_byte", "display_degrees", "hit_bark_digits"])
        for row in fixture["rows"]:
            self.assertEqual(bearing(row[0]), row[1])

    def test_keyboard_callback_and_poll_agree_through_holds(self):
        core = PcReferenceCore.__new__(PcReferenceCore)
        core.pressed = set()
        events = []
        core.keyboard = lambda *event: events.append(event)
        core.set_keys(["kp6", "space"])
        for _ in range(120):
            self.assertEqual(core._input(0, 3, 0, KEYS["kp6"]), 1)
        core.set_keys(["kp6", "space"])
        self.assertEqual(len(events), 2)
        core.set_keys([])
        self.assertEqual(len(events), 4)
        self.assertEqual(core._input(0, 3, 0, KEYS["kp6"]), 0)
        self.assertEqual(core._input(1, 3, 0, KEYS["kp6"]), 0)
        self.assertEqual(core._input(0, 1, 0, KEYS["kp6"]), 0)

    def test_explicit_frame_stepping(self):
        core = PcReferenceCore.__new__(PcReferenceCore)
        state = ThrottleState()
        self.assertTrue(core._environment(71 | 0x10000, C.byref(state)))
        self.assertEqual((state.mode, state.rate), (1, 0.0))

    def test_alternative_core_still_requires_an_exact_explicit_pin(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "core.dylib"
            path.write_bytes(b"not a core")
            for pin in ("", "bad", "0" * 64):
                with self.assertRaisesRegex(ValueError, "fingerprinted"):
                    PcReferenceCore(path, Path("game.zip"), Path(directory) / "saves", expected_sha256=pin)

    def test_cross_build_restore_requires_explicit_source_receipt_pin(self):
        core = PcReferenceCore.__new__(PcReferenceCore)
        core.core_sha256 = "a" * 64
        core.pressed = set()
        core.set_keys = lambda _: None
        core.pause_at_frame_end = lambda: None
        loaded = []
        core.core = SimpleNamespace(retro_unserialize=lambda *args: loaded.append(args[1]) or True)
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory) / "reference.state"
            state.write_bytes(b"test state")
            receipt = {"core_sha256": "b" * 64, "pressed_keys": [],
                       "files": {state.name: hashlib.sha256(state.read_bytes()).hexdigest()}}
            receipt_path = state.with_name("receipt.json")
            receipt_path.write_text(json.dumps(receipt))
            with self.assertRaises(ValueError): core.restore(state)
            self.assertEqual(loaded, [])
            core.restore(state, expected_source_sha256="b" * 64)
            self.assertEqual(loaded, [10])
            receipt["pressed_keys"] = [32]
            receipt_path.write_text(json.dumps(receipt))
            with self.assertRaises(ValueError): core.restore(state, expected_source_sha256="b" * 64)

    def test_protocol_accepts_only_bounded_keyboard_steps(self):
        validate_command({"op": "quit"})
        valid = {"op": "step", "id": 1, "frames": 60, "keys": ["kp6"]}
        validate_command(valid)
        cases = [None, [], {"op": "write_memory"}, {"op": "quit", "path": "elsewhere"}]
        cases += [valid | {"frames": v} for v in (0, 601, True, 1.5, "60")]
        cases += [valid | {"keys": v} for v in (["unknown"], ["kp6", "kp6"], [3], "kp6", [{}])]
        cases += [valid | {"id": v} for v in (-1, True, "1")]
        cases += [valid | {"path": "elsewhere"}]
        for case in cases:
            with self.subTest(case=case), self.assertRaises(ValueError):
                validate_command(case)

    def test_memory_maps_reconstruct_physical_order_and_reject_unknown_layout(self):
        core = PcReferenceCore.__new__(PcReferenceCore)
        core.pause_at_frame_end = lambda: None
        ram = C.create_string_buffer(b"OS" + bytes(640 * 1024 - 2))
        ptr = C.addressof(ram)
        os_map, game_map = MemoryDescriptor(), MemoryDescriptor()
        os_map.start, os_map.ptr, os_map.length = 0x100000, ptr, 6240
        game_map.start, game_map.ptr, game_map.length = 0, ptr + 6240, 655360 - 6240
        core.memory_maps = [game_map, os_map]
        self.assertEqual(core.conventional_memory(), ram.raw[:-1])
        game_map.ptr += 16
        with self.assertRaises(ValueError):
            core.conventional_memory()


if __name__ == "__main__":
    unittest.main()
