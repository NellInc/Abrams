"""Byte-level tests only. Passing does not establish gameplay fidelity."""
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest

from tools.inspect_scenarios import (decode_resource, parse_world, parse_scenario,
                                     parse_shape_table, inspect_file)
from tools.reference_inventory import inventory, serialize, verify

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "GAME"


def literal_resource(values: list[int], expected: int) -> bytes:
    packed = sum(value << (9 * index) for index, value in enumerate(values))
    return b"\x02" + struct.pack("<I", expected) + packed.to_bytes((9 * len(values) + 7) // 8, "little")


class DecoderTests(unittest.TestCase):
    def test_literal_and_dictionary_special_case(self):
        self.assertEqual(decode_resource(literal_resource([65, 66], 2)), b"AB")
        self.assertEqual(decode_resource(literal_resource([65, 257], 3)), b"AAA")

    def test_reset_block_padding(self):
        # Reset occupies the second 9-bit slot, then six slots of padding.
        values = [65, 256] + [0] * 6 + [66]
        self.assertEqual(decode_resource(literal_resource(values, 2)), b"AB")

    def test_malformed_input(self):
        for data in (b"", b"\x01\0\0\0\0", b"\x02\x01\0\0\0",
                     literal_resource([258], 1), literal_resource([65, 257], 2),
                     literal_resource([65], 1) + b"\0"):
            with self.subTest(data=data), self.assertRaises(ValueError):
                decode_resource(data)
        with self.assertRaises(ValueError):
            decode_resource(b"\x02\xff\xff\xff\xff")

    def test_regression_hashes(self):
        expected = {
            "SNARIO0.SSS": "f5b915cc1dd4ce4b50f2b3f9a605d812387e82a5c48611db2281f8a320bc785f",
            "SNARIO0.WLD": "139da1b222ae5ef15c39cfcf5aaa9495f0818b87c46db58094ade201825b807b",
            "SHAPE.TBL": "e7568bbb8f51909e7baefa87f20f663c41fc840b9c337bf6eb22f187e7419020",
            "CO.BMP": "b1f18b11f2bfd918374481dd5cc5f6d54761e4c1fe424533d486838c03520ddd",
            "SCENE1.BIN": "4b5d79800687c5d40e0e8cace46cea69b27bf08547a197688a1a2f15c553b02a",
            "TANKS.BMP": "214c57d23e2ae15548b380406d11448628fc8503f3b5d6e7f552deac3d81485e",
        }
        for name, digest in expected.items():
            with self.subTest(name=name):
                data = (GAME / name).read_bytes()
                decoded = decode_resource(data)
                self.assertEqual(len(decoded), int.from_bytes(data[1:5], "little"))
                self.assertEqual(hashlib.sha256(decoded).hexdigest(), digest)

    def test_every_supplied_type_two_resource(self):
        count = 0
        before = inventory(GAME)
        for path in GAME.iterdir():
            if path.is_file():
                data = path.read_bytes()
                if data[:1] == b"\x02":
                    with self.subTest(file=path.name):
                        self.assertEqual(len(decode_resource(data)), int.from_bytes(data[1:5], "little"))
                    count += 1
        self.assertEqual(count, 48)
        self.assertEqual(before, inventory(GAME))


class StructureTests(unittest.TestCase):
    def test_scenarios_and_worlds(self):
        counts = [45, 62, 35, 53, 73, 31, 21, 52]
        worlds = [486, 560, 501, 690, 978, 826, 828, 977]
        for index in range(8):
            scenario = parse_scenario(decode_resource((GAME / f"SNARIO{index}.SSS").read_bytes()))
            world = parse_world(decode_resource((GAME / f"SNARIO{index}.WLD").read_bytes()))
            self.assertEqual(scenario["record_count"], counts[index])
            self.assertEqual(len(world["records"]), worlds[index])
            self.assertTrue(scenario["messages"])
        self.assertEqual(inspect_file(GAME / "SNARIO0.SSS")["scenario"]["messages"][0]["text"],
                         "Radar shows hind entering your sector!")

    def test_shape_directory(self):
        result = parse_shape_table(decode_resource((GAME / "SHAPE.TBL").read_bytes()))
        self.assertEqual(result["count"], 188)
        self.assertEqual(result["sentinel_offset"], 376)
        self.assertEqual(result["records"][-1], {"index": 187, "offset": 33792, "size": 38})

    def test_malformed_structures(self):
        for parser in (parse_scenario, parse_world, parse_shape_table):
            with self.subTest(parser=parser), self.assertRaises(ValueError):
                parser(b"\0")
        world = bytearray(8195)
        struct.pack_into("<H", world, 0, 8193)
        with self.assertRaises(ValueError):
            parse_world(bytes(world))
        scenario = bytearray(34)
        struct.pack_into("<H", scenario, 28, 100)
        with self.assertRaises(ValueError):
            parse_scenario(bytes(scenario))
        with self.assertRaises(ValueError):
            parse_shape_table(b"\x04\0\0\0\x01")


class InventoryTests(unittest.TestCase):
    def test_supplied_baseline_unchanged(self):
        baseline = ROOT / "reference/reports/game-manifest.json"
        self.assertEqual(verify(GAME, baseline), [])
        self.assertEqual(serialize(inventory(GAME)), baseline.read_text())

    def test_determinism_changes_and_preservation(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            source = base / "source"
            source.mkdir()
            (source / "b").write_bytes(b"second")
            (source / "a").write_bytes(b"first")
            manifest = base / "manifest.json"
            original = serialize(inventory(source))
            manifest.write_text(original)
            self.assertEqual(original, serialize(inventory(source)))
            self.assertEqual(verify(source, manifest), [])
            (source / "a").write_bytes(b"changed")
            (source / "b").unlink()
            (source / "c").write_bytes(b"new")
            self.assertEqual(verify(source, manifest), ["missing: b", "unexpected: c", "changed: a"])
            self.assertEqual(manifest.read_text(), original)

    def test_malformed_manifest_and_symlink(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            source = base / "source"
            source.mkdir()
            manifest = base / "manifest.json"
            manifest.write_text(json.dumps({"schema": 1, "algorithm": "sha256", "files": [
                {"path": "../escape", "size": 0, "sha256": "0" * 64}]}))
            with self.assertRaises(ValueError):
                verify(source, manifest)
            (source / "link").symlink_to(manifest)
            with self.assertRaises(ValueError):
                inventory(source)

if __name__ == "__main__":
    unittest.main()
