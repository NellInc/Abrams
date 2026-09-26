"""Storage and reader regressions; original-CPU proof is pc_world_oracle.py."""
from pathlib import Path
import struct
import unittest

from tools.inspect_scenarios import decode_resource, parse_world
from tools.pc_world import world_position, read_objects
from tools.pc_live_state import SimStateReader

ROOT = Path(__file__).resolve().parents[1]


def world_fixture(payload, index=0):
    result = bytearray(8192)
    struct.pack_into("<H", result, index * 2, 8192)
    return bytes(result) + payload


class WorldTests(unittest.TestCase):
    def test_packed_and_extended_entries_keep_independent_offsets(self):
        parsed = parse_world(world_fixture(b"\x03\xb2\x88\x03" + struct.pack("<3h", -10, 20, -5)
                                          + b"\xff\x00", index=2 * 64 + 3))
        record = parsed["records"][0]
        self.assertEqual((record["row"], record["column"]), (2, 3))
        a, b, unused = record["entries"]
        self.assertEqual(a["shape_index"], 50)
        self.assertEqual(a["world_position_raw"], [14336, 10240, 0])
        self.assertEqual(b["world_position_raw"], [14326, 10220, -5])
        self.assertEqual([e["offset"] for e in record["entries"]], [8193, 8195, 8202])
        self.assertFalse(b["compact"])
        self.assertTrue(unused["unused"])

    def test_invalid_worlds_fail_closed(self):
        for payload in (b"", b"\x00", b"\x05", b"\x01", b"\x01\x80",
                        b"\x01\x00\0\0\0\0\0", b"\x01\x80\0\0"):
            with self.subTest(payload=payload), self.assertRaises(ValueError):
                parse_world(world_fixture(payload))
        data = bytearray(world_fixture(b"\x01\x80\0"))
        struct.pack_into("<H", data, 2, 8192)
        with self.assertRaises(ValueError):
            parse_world(bytes(data))

    def test_all_world_entries_fit_declared_cell_coordinates(self):
        counts = [510, 609, 529, 733, 1014, 876, 879, 1013]
        for index, count in enumerate(counts):
            world = parse_world(decode_resource((ROOT / f"GAME/SNARIO{index}.WLD").read_bytes()))
            self.assertEqual(sum(r["count"] for r in world["records"]), count)
            for r in world["records"]:
                for e in r["entries"]:
                    self.assertTrue(e["compact"])
                    x, y, z = e["world_position_raw"]
                    self.assertTrue(r["column"] * 4096 <= x < (r["column"] + 1) * 4096)
                    self.assertTrue(r["row"] * 4096 < y <= (r["row"] + 1) * 4096)
                    self.assertEqual(z, 0)

    def test_streaming_rebase_preserves_world_position(self):
        self.assertEqual(world_position([4097, 2000, 50], [15, 31]),
                         world_position([1, 2000, 50], [16, 31]))
        self.assertEqual(world_position([2048, 4100, 50], [15, 31]),
                         world_position([2048, 4, 50], [15, 30]))
        self.assertEqual(world_position([-4097, -4100, -50], [15, 31]),
                         world_position([-1, -4, -50], [14, 32]))

    def test_runtime_pool_signed_positions_flags_and_stable_source_offset(self):
        ram, ds = bytearray(640 * 1024), 0x1BCD0
        ram[ds + 0x886A], ram[ds + 0x776C] = 15, 31
        at = ds + 0x7ACE + 4 * 23
        ram[at:at + 4] = bytes([0xC8, 50, 132, 0])
        struct.pack_into("<3h", ram, at + 4, -256, 4096, -10)
        struct.pack_into("<H", ram, at + 18, 8193)
        ram[at + 20] = 9
        before = bytes(ram)
        world = read_objects(ram, ds)
        self.assertEqual(world["dynamic"], [])
        self.assertEqual(len(world["static"]), 1)
        obj = world["static"][0]
        self.assertEqual(obj["slot"], 4)
        self.assertEqual(obj["position_local_raw"], [-256, 4096, -10])
        self.assertEqual(obj["world_position_raw"], [77568, 139264, -10])
        self.assertEqual(obj["cell"], [16, 32])
        self.assertEqual(obj["world_entry_offset"], 8193)
        self.assertIn("unverified", world["visibility"])
        self.assertEqual(before, bytes(ram))

    def test_player_schema_corrects_unsigned_local_coordinate_bug(self):
        reader = SimStateReader(ROOT / "GAME/SIM.EXE")
        ram, base = bytearray(640 * 1024), 0x1ED0
        ds = base + 0x19E00
        for offset, anchor in reader.anchors:
            ram[base + offset:base + offset + len(anchor)] = anchor
        struct.pack_into("<HH", ram, ds + 0x7999, 0x8FE0, 0x709E)
        struct.pack_into("<3h", ram, ds + 0x709E + 4, -256, 4100, -50)
        ram[ds + 0x886A], ram[ds + 0x776C] = 15, 31
        state = reader.read(ram)
        self.assertEqual(state["schema"], 2)
        self.assertEqual(state["position_raw"], [-256, 4100, -50])
        self.assertEqual(state["world_position_raw"], [77568, 139260, -50])


if __name__ == "__main__":
    unittest.main()
