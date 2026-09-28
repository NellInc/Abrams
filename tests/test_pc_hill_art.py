"""Source-bound terrain selection, independent of the runtime lookup table."""
import ast
from collections import Counter
import hashlib
from pathlib import Path
import re
import tempfile
import unittest
from PIL import Image

from tools.extract_genesis_vdp import VDP
from tools.inspect_scenarios import decode_resource
from tools.inspect_shapes import inspect_shapes, primitive_vertices

ROOT = Path(__file__).resolve().parents[1]


class HillSourceTests(unittest.TestCase):
    @unittest.skipUnless((ROOT / "reference/genesis/terrain-turn-02/turned220").exists(), "Native Genesis hill capture required")
    def test_genesis_hill_colour_and_complete_capture_reconstruction(self):
        vdp = VDP(ROOT / "reference/genesis/terrain-turn-02/turned220")
        self.assertEqual(vdp.receipt["rom_sha256"],
                         "ff83dc53b33252d42ac624e11a2ce717428b75f48f2e56a20b3d38f78e6ca4ea")
        self.assertEqual(vdp.receipt["files"]["screen.png"],
                         "e70f8a6faf365bc2fc718e46b6e8aecee0635231761c8cb3f9dd086abd75225d")
        with tempfile.TemporaryDirectory() as temp:
            result = vdp.export(Path(temp) / "decoded")["compositor"]
            self.assertEqual(result["compared_pixels"], 71680)
            self.assertEqual(result["mismatched_pixels"], 0)
        screen = Image.open(vdp.capture / "screen.png").convert("RGB")
        for box in [(165, 61, 181, 69), (188, 66, 204, 74), (178, 61, 194, 65)]:
            sample = screen.crop(box)
            self.assertEqual(Counter(sample.getdata()),
                             {(0, 0, 0): sample.width * sample.height // 2,
                              (172, 170, 0): sample.width * sample.height // 2})

    @unittest.skipUnless((ROOT / "GAME/SHAPE.TBL").exists(), "Local original required")
    def test_complete_hill_family_matches_original_shapes(self):
        raw = (ROOT / "GAME/SHAPE.TBL").read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(),
                         "81cf10917d8647e8ac187e49887494992828277333f17d6c1926e59581f0a193")
        shapes = inspect_shapes(decode_resource(raw))["shapes"]
        script = (ROOT / "godot/scripts/pc_terrain_style.gd").read_text()
        actual = ast.literal_eval(re.search(r"const HILLS := (\{.*?\})\n", script, re.S)[1])
        vertical = ast.literal_eval(re.search(r"const HILL_VERTICAL := (\{.*?\})\n", script, re.S)[1])
        expected_vertical = {}
        self.assertEqual(set(actual), set(range(2, 34)))
        faces = 0
        for index, (root, primitives) in actual.items():
            shape = shapes[index]
            self.assertEqual([s["target"] for s in shape["selectors"]], [root])
            self.assertEqual(primitives, {p["offset"]: p["prefix_bytes"][2]
                                          for p in shape["primitives"]})
            for p in shape["primitives"]:
                self.assertEqual(p["prefix_bytes"][1], p["prefix_bytes"][2])
                self.assertIn(p["prefix_bytes"][2], (17, 19, 26, 28))
                vertices = primitive_vertices(shape, p)
                self.assertIn(len(vertices), (3, 4))
                self.assertTrue(all(-2048 <= v[0] <= 2048 and -2048 <= v[1] <= 2048
                                    and 0 <= v[2] <= 2048 for v in vertices))
                self.assertTrue(any(v[2] > 0 for v in vertices))
                a = [vertices[1][i] - vertices[0][i] for i in range(3)]
                b = [vertices[2][i] - vertices[0][i] for i in range(3)]
                normal = [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]
                self.assertNotEqual(normal, [0, 0, 0])
                if normal[2] == 0:
                    self.assertTrue(normal[0] == 0 or normal[1] == 0)
                    expected_vertical[p["offset"]] = 8 if normal[0] else 9
                faces += 1
        self.assertEqual(faces, 49)
        self.assertEqual(vertical, expected_vertical)
        self.assertEqual(len(vertical), 17)


if __name__ == "__main__":
    unittest.main()
