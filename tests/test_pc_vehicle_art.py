"""Original face identities, Genesis correspondence and unchanged donor bytes."""
import ast
import hashlib
from pathlib import Path
import re
import unittest
from PIL import Image
from tools.inspect_scenarios import decode_resource
from tools.inspect_shapes import inspect_shapes, primitive_vertices
from tools.extract_genesis_models import decode_models, compare_pc

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = (ROOT / 'godot/scripts/pc_vehicle_art.gd').read_text()


def constant(name, terminator):
    return ast.literal_eval(re.search(r'const '+name+r' := (.*?)'+terminator, SCRIPT, re.S)[1])


class VehicleArtSourceTests(unittest.TestCase):
    @unittest.skipUnless((ROOT / 'GAME/SHAPE.TBL').exists(), 'Local PC source required')
    def test_six_exact_faces_and_ordered_uv_coordinates(self):
        raw = (ROOT / 'GAME/SHAPE.TBL').read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(),
                         re.search(r'const SOURCE_HASH := "([a-f0-9]+)"', SCRIPT)[1])
        shapes = inspect_shapes(decode_resource(raw))['shapes']
        models = constant('MODELS', r'\nconst LEVELS')
        self.assertEqual(set(models), {115, 125, 129})
        for index, (root, donor, faces) in models.items():
            shape = shapes[index]
            self.assertEqual([s['target'] for s in shape['selectors']], [root])
            self.assertIn(donor, (0, 1, 2))
            self.assertEqual(len(faces), 2)
            for primitive, vertices in faces.items():
                p = next(p for p in shape['primitives'] if p['offset'] == primitive)
                self.assertEqual(p['prefix_bytes'][1:], [3, 3])
                self.assertEqual(vertices, primitive_vertices(shape, p))
                self.assertEqual(len(vertices), 6)
                self.assertEqual(len({v[0] for v in vertices}), 1)

    @unittest.skipUnless((ROOT / 'GENESIS/M-1 Abrams Battle Tank (USA, Europe).md').exists(), 'Local Genesis source required')
    def test_each_face_matches_genesis_program(self):
        catalog = decode_models((ROOT / 'GENESIS/M-1 Abrams Battle Tank (USA, Europe).md').read_bytes())
        result = compare_pc(catalog['models'], ROOT / 'GAME/SHAPE.TBL')
        models = constant('MODELS', r'\nconst LEVELS')
        for model in result['models']:
            if model['index'] not in models: continue
            for primitive in models[model['index']][2]:
                link = next(p for p in model['polygon_links'] if p['pc_primitive'] == primitive)
                self.assertTrue(link['material_plus_16_matches'])
                self.assertTrue(link['genesis_commands'])
                self.assertEqual(set(link['genesis_materials']), {19})

    @unittest.skipUnless((ROOT / 'local-art/genesis/remastered/vehicles-v1/t62-track-v1.png').exists(), 'Local authored art required')
    def test_source_images_and_measured_content_bounds(self):
        for name, digest, size, box in constant('ASSETS', r'\n# Source vertices'):
            path = ROOT / 'local-art/genesis/remastered/vehicles-v1' / name
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)
            with Image.open(path) as image:
                self.assertEqual(list(image.size), size)
                alpha = image.convert('RGBA').getchannel('A')
                x, y, right, bottom = alpha.point(lambda v: 255 if v >= 128 else 0).getbbox()
                self.assertEqual([x, y, right-x, bottom-y], box)
                self.assertEqual(alpha.getpixel((0, 0)), 0)

    @unittest.skipUnless((ROOT / 'GAME/SHAPE.TBL').exists(), 'Local PC source required')
    def test_all_other_dark_faces_have_source_verified_identity(self):
        shapes = inspect_shapes(decode_resource((ROOT / 'GAME/SHAPE.TBL').read_bytes()))['shapes']
        for index, faces in constant('PLAIN_FACES', r'\nconst GENESIS_DARK').items():
            expected = {p['offset']: [p['prefix_bytes'][1], len(primitive_vertices(shapes[index], p))]
                        for p in shapes[index]['primitives'] if p['prefix_bytes'][2] == 3
                        and len(primitive_vertices(shapes[index], p)) != 6}
            self.assertEqual(faces, expected)
        palette = (ROOT / 'reference/genesis/extracted/gunner/palette.gpl').read_text()
        self.assertRegex(palette, r'65\s+68\s+65\s+Index 51\b')


if __name__ == '__main__':
    unittest.main()
