import copy
import hashlib
from pathlib import Path
import struct
import unittest

from tools.inspect_scenarios import decode_resource
from tools.inspect_shapes import inspect_shapes, cube_geometry, cube_obj

ROOT = Path(__file__).resolve().parents[1]


class ShapeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = (ROOT / "GAME/SHAPE.TBL").read_bytes()
        cls.decoded = decode_resource(cls.original)
        cls.report = inspect_shapes(cls.decoded)

    def test_corpus_partition_and_counts(self):
        shapes = self.report["shapes"]
        self.assertEqual(len(shapes), 188)
        self.assertEqual(sum(bool(s["vector_count"]) for s in shapes), 168)
        self.assertEqual(sum(len(s["primitives"]) for s in shapes), 992)
        self.assertEqual(sum(len(s["opaque_commands"]) for s in shapes if s["vector_count"]), 11)
        for shape in shapes:
            self.assertEqual(shape["vectors_offset"] + 6 * shape["vector_count"],
                             shape["offset"] + shape["size"])
            self.assertEqual(shape["control_coverage"], "exact nonoverlapping partition")
            for primitive in shape["primitives"]:
                self.assertTrue(all(i < shape["vector_count"] for i in primitive["indices_low7"]))

    def test_reference_bytes_preserved_and_deterministic(self):
        self.assertEqual((ROOT / "GAME/SHAPE.TBL").read_bytes(), self.original)
        self.assertEqual(self.report, inspect_shapes(self.decoded))
        self.assertEqual(hashlib.sha256(self.decoded).hexdigest(),
                         "e7568bbb8f51909e7baefa87f20f663c41fc840b9c337bf6eb22f187e7419020")

    def test_cube_coordinates_and_topology(self):
        shape = self.report["shapes"][166]
        vertices, faces = cube_geometry(shape)
        self.assertEqual((len(vertices), len(faces)), (8, 6))
        obj = cube_obj(shape)
        self.assertEqual(obj, cube_obj(shape))
        self.assertEqual(sum(line.startswith("v ") for line in obj.splitlines()), 8)
        self.assertEqual(sum(line.startswith("f ") for line in obj.splitlines()), 6)
        self.assertIn("v 32 32 32\n", obj)

    def test_cube_invalid_topology_rejected(self):
        shape = copy.deepcopy(self.report["shapes"][166])
        shape["primitives"][0]["indices_low7"] = [0, 0, 0, 0]
        with self.assertRaises(ValueError):
            cube_geometry(shape)
        with self.assertRaises(ValueError):
            cube_geometry(self.report["shapes"][0])

    def test_malformed_vector_count_and_pointer(self):
        for offset, value in ((0x17a + 3, 255), (0x17a + 4, 0)):
            malformed = bytearray(self.decoded)
            malformed[offset] = value
            with self.subTest(offset=offset), self.assertRaises(ValueError):
                inspect_shapes(bytes(malformed))

    def test_out_of_bounds_and_overlapping_graph(self):
        for value in (0, 0x17a):
            malformed = bytearray(self.decoded)
            struct.pack_into("<H", malformed, 0x17a + 8, value)
            with self.subTest(value=value), self.assertRaises(ValueError):
                inspect_shapes(bytes(malformed))

    def test_invalid_primitive_index(self):
        shape = self.report["shapes"][166]
        malformed = bytearray(self.decoded)
        malformed[shape["primitives"][0]["offset"] + 3] = 127
        with self.assertRaises(ValueError):
            inspect_shapes(bytes(malformed))

    def test_truncation(self):
        for size in (0, 2, 378, len(self.decoded) - 1):
            with self.subTest(size=size), self.assertRaises(ValueError):
                inspect_shapes(self.decoded[:size])


if __name__ == "__main__":
    unittest.main()
