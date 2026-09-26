from pathlib import Path
import struct
import unittest

from tools.inspect_scenarios import decode_resource
from tools.inspect_shapes import inspect_shapes
from tools.pc_render_state import read_camera, select_static_faces, transform, signed16

ROOT = Path(__file__).resolve().parents[1]


class RenderStateTests(unittest.TestCase):
    def test_fixed_transform_signed_rounding_and_wrap(self):
        identity = [16384, 0, 0, 0, 16384, 0, 0, 0, 16384]
        self.assertEqual(transform([-99, 100, 200], identity, 3), [-99, 100, 200])
        self.assertEqual(transform([-1, -1, -1], [8192] * 9, 3), [-2, -2, -2])
        self.assertEqual(signed16(65535), -1)
        self.assertEqual(transform([100, 200, 300], [0] * 9, 0), [100, 200, 300])

    def fixture(self):
        ram, ds = bytearray(640 * 1024), 0x1BCD0
        for at, value in ((0x1A8B, 32), (0x1A9F, 287), (0x1AB3, 13), (0x1AC7, 109)):
            struct.pack_into("<H", ram, ds + at, value)
        struct.pack_into("<3H", ram, ds + 0x12C2, 16, 128, 7)
        return ram, ds

    def test_camera_uses_saved_view_rectangle_not_overwritten_raster_clip(self):
        ram, ds = self.fixture()
        struct.pack_into("<4H", ram, ds + 0x3593, 216, 277, 83, 126)
        frame = read_camera(ram, ds, {"static": [], "dynamic": []})
        self.assertEqual(frame["clip"], [32, 13, 287, 109])
        self.assertEqual(frame["focal_pixels"], 128)

    def test_invalid_or_incoherent_renderer_returns_no_camera(self):
        for at, value in ((0x116E, 10), (0x1A9F, 321), (0x12C2, 0), (0x12C6, 5), (0x8DD2, 164)):
            ram, ds = self.fixture()
            struct.pack_into("<H", ram, ds + at, value)
            self.assertIsNone(read_camera(ram, ds, {"static": [], "dynamic": []}))
        ram, ds = self.fixture()
        struct.pack_into("<H", ram, ds + 0x8DD2, 1)
        struct.pack_into("<H", ram, ds + 0x6F58, 0x709E)
        self.assertIsNone(read_camera(ram, ds, {"static": [], "dynamic": []}))
        self.assertEqual(read_camera(ram, ds, {"static": [], "dynamic": [{"pointer": 0x709E}]})["draw_order"], [0x709E])

    def test_static_normal_faces_reverse_with_camera_side(self):
        shape = inspect_shapes(decode_resource((ROOT / "GAME/SHAPE.TBL").read_bytes()))["shapes"][166]
        a = select_static_faces(shape, 100, [0, 0, -100])
        b = select_static_faces(shape, 100, [0, 0, 100])
        self.assertTrue(a["primitive_ids"] and b["primitive_ids"])
        self.assertNotEqual(a["primitive_ids"], b["primitive_ids"])
        self.assertEqual(a["root"], b["root"])


if __name__ == "__main__":
    unittest.main()
