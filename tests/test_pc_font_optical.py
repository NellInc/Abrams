"""Optical outline primitives and one pinned golden face, without a font rebuild."""
import json
from pathlib import Path
import unittest
from tools.pc_font_optical import area, bounds, clip, cut, normalize, rect, shape, stroke

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'local-art/pc-outline-fonts-v5/manifest.json'


class OpticalPrimitiveTests(unittest.TestCase):
    def test_area_sign_and_rectangles(self):
        self.assertEqual(area(rect(0, 0, 4, 2)), 8)
        self.assertEqual(area(rect(0, 0, 4, 2)[::-1]), -8)

    def test_clip_and_bounds_keep_only_the_requested_half_planes(self):
        left = clip(rect(0, 0, 4, 2), 0, 1, True)
        self.assertEqual(area(left), 2)
        self.assertTrue(all(x <= 1 for x, y in left))
        self.assertEqual(clip([], 0, 1, True), [])
        box = bounds(rect(-1, -1, 6, 4), (0, 0, 4, 2))
        self.assertEqual(abs(area(box)), 8)
        self.assertTrue(all(0 <= x <= 4 and 0 <= y <= 2 for x, y in box))

    def test_cut_removes_exactly_the_stencil_slit(self):
        pieces = cut([rect(0, 0, 4, 2)], (1, 0.5, 1, 1))
        self.assertEqual(len(pieces), 4)
        self.assertAlmostEqual(sum(abs(area(p)) for p in pieces), 8 - 1)
        # A slit spanning the whole height leaves only the two side pieces.
        self.assertEqual(len(cut([rect(0, 0, 4, 2)], (1, 0, 1, 2))), 2)

    def test_open_stroke_width_caps_and_contrast_weight(self):
        self.assertEqual(stroke([(0, 1), (4, 1)]), [[(0.0, 0.5), (4.0, 0.5), (4.0, 1.5), (0.0, 1.5)]])
        capped = stroke([(0, 1), (4, 1)], caps=(1, 0))[0]
        self.assertEqual(min(x for x, y in capped), -1)
        bold = stroke([(2, 0), (2, 4)], weight=(2, 1))[0]
        self.assertEqual((min(x for x, y in bold), max(x for x, y in bold)), (1, 3))
        self.assertGreater(area(bold), 0)
        self.assertEqual(stroke([(1, 1), (1, 1)]), [])
        with self.assertRaisesRegex(ValueError, 'reversed stroke'):
            stroke([(0, 0), (2, 0), (0, 0)])

    def test_closed_stroke_has_outer_and_counter_contours(self):
        outer, inner = stroke([(0, 0), (2, 0), (2, 2), (0, 2)], closed=True)
        self.assertEqual((area(outer), area(inner)), (9, -1))

    def test_normalize_clips_snaps_and_drops_degenerate_polygons(self):
        self.assertEqual(normalize([rect(0, 0, 4, 2.0004)], (0, 0, 4, 2), 8),
                         [[(0.0, 2.0), (0.0, 0.0), (4.0, 0.0), (4.0, 2.0)]])
        snapped = normalize([rect(0.0001, 0, 1, 1)], (0, 0, 4, 2), 8)[0]
        self.assertTrue(all((x * 192).is_integer() and (y * 192).is_integer() for x, y in snapped))
        self.assertEqual(normalize([[(0, 0), (1, 0), (1, 0), (0, 0)]], (0, 0, 4, 2), 8), [])


@unittest.skipUnless((ROOT / 'GAME/8X8.FNT').exists() and MANIFEST.exists(), 'local original font and outline catalog required')
class OpticalGoldenTests(unittest.TestCase):
    def test_shape_matches_pinned_catalog_contours(self):
        from tools.build_pc_outline_fonts import PINS, contours
        from tools.pc_fonts import decode_font
        import hashlib
        raw = (ROOT / 'GAME/8X8.FNT').read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), PINS['8X8.FNT'])
        font = decode_font(raw)
        face = next(f for f in json.loads(MANIFEST.read_text())['faces'] if f['source'] == '8X8.FNT')
        glyphs = {g['code']: g for g in face['glyphs']}
        for char in 'O8RSa':
            code = ord(char)
            original = contours(font['glyphs'][code - font['first']], font['width'], font['height'])
            with self.subTest(char=char):
                self.assertTrue(glyphs[code]['optically_shaped'])
                self.assertEqual(json.loads(json.dumps(shape(font, code, '8X8.FNT', original))), glyphs[code]['contours'])
        self.assertIsNone(shape(font, ord('I'), '8X8.FNT'))
        with self.assertRaisesRegex(ValueError, 'lowercase requires original contour topology'):
            shape(font, ord('a'), '8X8.FNT')


if __name__ == '__main__': unittest.main()
