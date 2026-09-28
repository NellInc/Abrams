import ast
import hashlib
import json
import re
import unittest
from pathlib import Path

from tools.audit_pc_effect_inventory import BASES, inventory, source_bindings
from tools.inspect_scenarios import decode_resource

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless((ROOT / 'GAME/SHAPE.TBL').exists(), 'Requires local original game')
class EffectInventoryTests(unittest.TestCase):
    def test_every_runtime_binding_matches_original_shape_command(self):
        bindings = source_bindings(decode_resource((ROOT / 'GAME/SHAPE.TBL').read_bytes()))
        code = (ROOT / 'godot/scripts/pc_effect_art.gd').read_text()
        def table(name):
            return ast.literal_eval(re.search(r'const ' + name + r' := (\{[^\n]+\})', code)[1])
        self.assertEqual(table('ROOTS'), {i: b['root'] for i, b in bindings.items()})
        self.assertEqual(table('SHAPES'), {i: b['shape'] for i, b in bindings.items()})
        self.assertEqual(table('DONORS'), {i: BASES.index(i % 18 if i < 54 else 62 + i % 2) for i in bindings})
        self.assertEqual({b['shape'] for b in bindings.values()}, set(range(168, 188)))

    def test_all_source_pixels_and_donors_are_pinned_and_inventoried(self):
        result = inventory(ROOT)
        self.assertEqual((result['count'], result['authored_donors']), (64, 20))
        self.assertEqual([r['index'] for r in result['images']], list(range(64)))
        code = (ROOT / 'godot/scripts/pc_effect_art.gd').read_text()
        catalog = ROOT / 'local-art/genesis/source/effects-v1/effects.json'
        self.assertIn(hashlib.sha256(catalog.read_bytes()).hexdigest(), code)
        for row in result['images']:
            self.assertIn(row['authored_asset'], code)
            self.assertGreater(row['source_opaque'], 0)
            self.assertGreater(row['candidate_opaque_native_scale'], 0)
            self.assertLessEqual(row['native_mask_iou'], 1)
            asset = ROOT / 'local-art/genesis/remastered' / row['authored_asset']
            self.assertIn(hashlib.sha256(asset.read_bytes()).hexdigest(), code)

    def test_generated_padding_is_registered_from_actual_cutout_bounds(self):
        from PIL import Image
        folder = ROOT / 'local-art/genesis/remastered'
        manifest = json.loads((folder / 'effects-v2/manifest.json').read_text())
        code = (ROOT / 'godot/scripts/pc_effect_art.gd').read_text()
        regions = ast.literal_eval(re.search(r'const ART_BOUNDS := (\[[^\n]+\])', code)[1])
        for index, entry in enumerate(manifest['assets']):
            with Image.open(folder / entry['file']) as image:
                box = image.getchannel('A').point(lambda a: 255 if a >= 128 else 0).getbbox()
                self.assertEqual(list(box), entry['cutout_bbox'])
                expected = [box[0] / image.width, box[1] / image.height,
                            (box[2] - box[0]) / image.width, (box[3] - box[1]) / image.height]
                self.assertEqual(regions[index], expected)

    def test_atlas_stays_in_existing_ordered_effect_branch(self):
        draw = (ROOT / 'godot/scripts/pc_draw_pass.gd').read_text()
        shader = (ROOT / 'godot/scripts/pc_surface.gdshader').read_text()
        self.assertIn('"impact_burst",effect_art.atlas', draw)
        self.assertIn('materials.append(Vector2(0,4))', draw)
        self.assertIn('uniform sampler2D impact_burst : filter_linear, repeat_disable;', shader)
        self.assertIn('if (effect.a < 0.5) discard;', shader)

@unittest.skipUnless((ROOT / 'artifacts/finish-20260928/target-live-trace-02/report.json').exists(), 'Requires retained source mode captures')
class EffectModeInventoryTests(unittest.TestCase):
    def test_observed_thermal_and_status_contexts_keep_exact_source_palette(self):
        from tools.audit_pc_effect_modes import audit
        report = audit(ROOT)
        self.assertEqual(report['unique_palettes'], 1)
        self.assertEqual([r['stage'] for r in report['modes']], ['selected', 'thermal', 'thermal-off', 'damage-settled'])
        self.assertEqual(report['modes'][1]['reticle_color'], 1)
        self.assertEqual(report['modes'][2]['reticle_color'], 0)
        self.assertEqual(report['modes'][3]['ui_owned_pixels'], 64000)
        self.assertGreater(report['modes'][3]['status_plate_pixels'], 0)
        self.assertEqual(len(report['source_regions']), 3)


if __name__ == '__main__':
    unittest.main()
