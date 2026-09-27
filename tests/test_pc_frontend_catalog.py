import hashlib
import json
from pathlib import Path
import unittest
from PIL import Image

from tools.build_pc_frontend_catalog import build, compose, motor_pool, PALETTE

ROOT=Path(__file__).resolve().parents[1]


class FrontendCatalogTests(unittest.TestCase):
    def test_transparent_zero_and_opaque_black(self):
        rgb=compose([2]*64000,{'width':8,'height':1,'pixels':[0,11,1,6,2,0,0,0]},2,3)
        at=(3*320+2)*3
        self.assertEqual(rgb[at:at+12],bytes([*PALETTE[2],*PALETTE[11],*PALETTE[1],*PALETTE[6]]))
        with self.assertRaisesRegex(ValueError,'outside'):
            compose([2]*64000,{'width':8,'height':1,'pixels':[1]*8},319,0)

    def test_exact_native_office_prefixes(self):
        data=build(ROOT/'GAME')
        fixtures=ROOT/'artifacts/pc-live-type-lifecycle-01'
        if not fixtures.exists():self.skipTest('requires local original lifecycle capture')
        # Independent complete RGB prefix equality, not a similarity metric.
        cases=[('boot-15',2,187),('boot-17',0,167),('boot-19',1,167),('debrief',1,147)]
        for name,pose,height in cases:
            with self.subTest(name=name):
                im=Image.open(fixtures/(name+'.png')).convert('RGB')
                prefix=im.tobytes()[:height*320*3]
                self.assertEqual(hashlib.sha256(prefix).hexdigest(),data['templates'][pose]['hashes'][str(height)])
                self.assertTrue(all(im.getpixel((x,height))==(255,255,255) for x in range(320)))
        self.assertEqual(len(data['templates']),3)
        self.assertEqual(PALETTE[6],(255,85,85))

    def test_reproducible_local_catalog(self):
        local=ROOT/'local-art/pc-frontend-v1/office.json'
        if not local.exists():self.skipTest('requires generated local recognition catalog')
        payload=(json.dumps(build(ROOT/'GAME'),indent=2)+'\n').encode()
        self.assertEqual(payload,local.read_bytes())

    def test_motor_pool_catalog_is_exact_pinned_original_indices(self):
        import base64
        from tools.inspect_scenarios import decode_resource
        data=motor_pool(ROOT/'GAME')
        packed=base64.b64decode(data['packed_indices_base64'],validate=True)
        self.assertEqual(len(packed),32000)
        self.assertEqual(packed,decode_resource((ROOT/'GAME/ATBASE.BIN').read_bytes()))
        local=ROOT/'local-art/pc-motor-pool-v1/motor-pool.json'
        self.assertEqual((json.dumps(data,indent=2)+'\n').encode(),local.read_bytes())


if __name__=='__main__':unittest.main()
