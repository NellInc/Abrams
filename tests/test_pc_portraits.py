import json
from pathlib import Path
import unittest

from tools.extract_pc_portraits import catalog, planar_sample, verify_loaded

ROOT = Path(__file__).resolve().parents[1]


class PortraitProofTests(unittest.TestCase):
    def test_planes_and_transparent_zero_mask(self):
        item = {'index': 0, 'width': 8, 'height': 1, 'pixels': [0, 1, 2, 4, 8, 15, 0, 3]}
        planes, mask = planar_sample(item)
        self.assertEqual(planes, bytes([0x45, 0x25, 0x14, 0x0c]))
        self.assertEqual(mask, bytes([0x82]))
        self.assertEqual(verify_loaded(b'prefix' + planes + mask, item)['physical_offset'], 6)
        with self.assertRaisesRegex(ValueError, 'mask differs'):
            verify_loaded(b'prefix' + planes + b'\0', item)
        with self.assertRaisesRegex(ValueError, 'ambiguous'):
            verify_loaded(planes + mask + planes + mask, item)
        with self.assertRaisesRegex(ValueError, 'missing'):
            verify_loaded(b'', item)

    def test_original_catalogue_and_loaded_pixels(self):
        capture = ROOT / 'artifacts/pc-live-type-crew-02/first-render.bin'
        if not capture.exists(): self.skipTest('requires local original capture')
        trace = json.loads((capture.parent / 'report.json').read_text())['render_passes'][0]
        source = (ROOT / 'GAME/FACES.BMP').read_bytes()
        data = catalog(source, trace['palette_rgb'])
        proof = [verify_loaded(capture.read_bytes(), s) for s in data['images']]
        self.assertEqual(len(proof), 4)
        self.assertEqual(sum(p['pixels_checked'] for p in proof), 10696)
        with self.assertRaisesRegex(ValueError, 'fingerprint'):
            catalog(source[:-1] + bytes([source[-1] ^ 1]), trace['palette_rgb'])


if __name__ == '__main__': unittest.main()
