import hashlib
import json
from pathlib import Path
import unittest
from PIL import Image

from tools.build_pc_frontend_catalog import build, compose, motor_pool, arming_panel, information, PALETTE

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

    def test_clipboard_geometry_is_original_and_loaded_planes_match(self):
        import base64
        from tools.inspect_scenarios import decode_resource
        from tools.pc_bitmaps import decode_bitmaps
        from tools.extract_pc_portraits import verify_loaded
        data=arming_panel(ROOT/'GAME')
        sprite=decode_bitmaps(decode_resource((ROOT/'GAME/CLIP.BMP').read_bytes()))[0]
        self.assertEqual(base64.b64decode(data['indices_base64']),bytes(sprite['pixels']))
        local=ROOT/'local-art/pc-arming-panel-v1/arming-panel.json'
        self.assertEqual((json.dumps(data,indent=2)+'\n').encode(),local.read_bytes())
        ram=ROOT/'artifacts/pc-motor-pool-loader-diagnostic-01/boot-21.bin'
        if ram.exists():self.assertEqual(verify_loaded(ram.read_bytes(),sprite)['pixels_checked'],9944)

    def test_information_sources_and_native_loaded_planes(self):
        data=information(ROOT/'GAME',ROOT/'artifacts/pc-information-baseline-02')
        local=ROOT/'local-art/pc-information-v3/information.json'
        self.assertEqual((json.dumps(data,indent=2)+'\n').encode(),local.read_bytes())
        self.assertEqual(data['recognition_height'],175)
        self.assertEqual([e['name'] for e in data['entries']],['ax','heat','sabot','coax','cannon','smoke','crew'])
        heat=next(e for e in data['entries'] if e['name']=='heat')
        self.assertEqual(heat['rect'],[104,22,208,67])
        self.assertEqual(heat['loaded_source_proof'][0]['index'],1)
        self.assertEqual(heat['loaded_source_proof'][0]['pixels_checked'],208*67)
        self.assertEqual(heat['art'],'info-v1/ammo-heat-v2.png')
        crew=data['entries'][-1]
        self.assertEqual(crew['full_rgb_sha256'],'ab6177af9b4cf2442a41a1a7bf3f88dbafb5116186cbf4b7760efa196e798977')
        self.assertEqual(crew['genesis_caption_pixels_checked'],386)
        self.assertEqual((crew['genesis_wire_pixels_checked'],crew['original_red_callout_overdraw_pixels']),(1853,22))
        self.assertEqual([x['name'] for x in crew['layers']],['crew-diagram','crew-gunner','crew-driver','crew-loader','crew-commander'])
        self.assertEqual(sum(x['pixels_checked'] for x in crew['loaded_source_proof']),23384)
        self.assertEqual(crew['layers'][0]['rect'],[63,64,194,53])
        for entry in data['entries']:
            x,y,w,h=entry['rect']
            self.assertLessEqual(y+h,200 if entry['name']=='crew' else 175)
            for proof in entry['loaded_source_proof']:
                self.assertEqual(proof['pixels_checked'],proof['mask_bits_checked'])

    def test_information_route_and_native_launcher_fixture_agree(self):
        from tools.capture_pc_session import information_steps, INFORMATION_PAGES
        route=information_steps()
        self.assertEqual(len(route),72)
        self.assertEqual(sum(s['frames'] for s in route),5749)
        self.assertEqual(len({s['label'] for s in route}),len(route))
        self.assertEqual(route,json.loads((ROOT/'godot/tests/fixtures/pc_information_steps.json').read_text()))
        self.assertEqual([s['label'] for s in route if s['label'] in INFORMATION_PAGES],list(INFORMATION_PAGES))

    def test_information_text_matches_every_original_font_bit(self):
        from tools.pc_fonts import decode_font,text_pixels
        data=json.loads((ROOT/'local-art/pc-information-v3/information.json').read_text())
        counts={'ax':19,'heat':18,'sabot':19,'coax':12,'cannon':16,'smoke':10,'crew':5}
        for entry in data['entries']:
            image=Image.open(ROOT/'artifacts/pc-information-baseline-02'/(entry['name']+'.png')).convert('RGB')
            occupied=set()
            self.assertEqual(len(entry['text_runs']),counts[entry['name']])
            for run in entry['text_runs']:
                font=decode_font((ROOT/'GAME'/run['font']).read_bytes())
                self.assertEqual(font['sha256'],run['font_sha256'])
                w,h,bits=text_pixels(font,run['text'].encode('ascii'))
                x,y,rw,rh=run['rect'];self.assertEqual((w,h),(rw,rh))
                expected=bytes(c for bit in bits for c in (run['source_foreground'] if bit else run['source_background']))
                self.assertEqual(image.crop((x,y,x+w,y+h)).tobytes(),expected)
                cells={(sx,sy) for sy in range(y,y+h) for sx in range(x,x+w)}
                self.assertFalse(occupied.intersection(cells));occupied |= cells
                if entry['name']!='crew':
                    ax,ay,aw,ah=entry['rect']
                    self.assertFalse(any(ax<=sx<ax+aw and ay<=sy<ay+ah for sx,sy in cells))


if __name__=='__main__':unittest.main()
