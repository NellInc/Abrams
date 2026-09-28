import hashlib
import json
from pathlib import Path
import unittest

from tools.extract_pc_portraits import catalog, planar_sample, verify_loaded
from tools.pc_live_state import SIM_SHA256
from tools.unpack_pc_executables import unpack

ROOT = Path(__file__).resolve().parents[1]


class PortraitProofTests(unittest.TestCase):
    def test_original_fixed_anchor_precedes_caption(self):
        source = ROOT / 'GAME/SIM.EXE'
        if not source.exists(): self.skipTest('requires supplied original SIM')
        raw = source.read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), SIM_SHA256)
        decoded, _ = unpack(raw)
        # SIM:3ee1 checks station zero, then pushes y=59, x=37 and the
        # current FACES entry before calling the bitmap wrapper at f8d:347.
        self.assertEqual(decoded[0x3ee1:0x3f03], bytes.fromhex(
            '80 3e 9d 79 00 75 1e b8 3b 00 50 b8 25 00 50 a0 64 64 '
            '98 8b d8 d1 e3 8b 36 60 8d ff 30 9a 47 03 8d 0f'))
        # Only afterward are text coordinates/pointer passed to f8d:20a.
        self.assertEqual(decoded[0x3f03:0x3f1d], bytes.fromhex(
            '83 c4 06 a1 6e 64 05 02 00 50 a1 6c 64 05 06 00 50 '
            'ff 36 4c 09 9a 0a 02 8d 0f'))

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
