import hashlib
import json
import re
from pathlib import Path
import unittest
from PIL import Image
from tools.build_pc_intro_catalog import build, FRAMES
from tests._inputs import requires

ROOT = Path(__file__).resolve().parents[1]


@requires('GAME', 'artifacts/pc-intro-baseline-02', 'artifacts/pc-intro-trace-01',
          'artifacts/pc-intro-skip-baseline-01', 'artifacts/pc-intro-skip-trace-01')
class IntroCatalogTests(unittest.TestCase):
    def test_source_composition_and_reproducible_catalog(self):
        capture=ROOT/'artifacts/pc-intro-trace-01'
        data = build(ROOT,capture)
        published=(ROOT/'local-art/pc-intro-v2/intro.json').read_bytes()
        pin=re.search(r'const CATALOG_SHA := "([a-f0-9]{64})"',
                      (ROOT/'godot/scripts/pc_intro_art.gd').read_text())
        self.assertIsNotNone(pin)
        self.assertEqual(hashlib.sha256(published).hexdigest(),pin[1])
        self.assertEqual(data['capture_report_sha256'],hashlib.sha256((capture/'report.json').read_bytes()).hexdigest())
        # A fresh source/control run has its own provenance. Preserve the
        # published catalogue pin and require every other serialized byte.
        reproduced=data | {'capture_report_sha256':json.loads(published)['capture_report_sha256']}
        self.assertEqual((json.dumps(reproduced,indent=2)+'\n').encode(),published)
        self.assertEqual(data['source_proof']['compared_rgb_pixels'],320000)
        self.assertEqual(len(data['entries']),13)
        self.assertEqual([e['flash'] for e in data['entries']],[0,1,2,3]+[4]*9)

    def test_every_credit_pixel_preserves_original_letterforms(self):
        data = build(ROOT,ROOT/'artifacts/pc-intro-trace-01')
        for frame,entry in zip(FRAMES[5:],data['entries'][5:]):
            with Image.open(ROOT/f'artifacts/pc-intro-trace-01/frame-{frame:04d}.png') as raw:
                original=raw.convert('RGB')
            covered=set()
            for overlay in entry['overlays']:
                for x,y,w,h in overlay['rects']:
                    self.assertEqual(h,1)
                    for xx in range(x,x+w):
                        self.assertNotIn((xx,y),covered);covered.add((xx,y))
                        self.assertEqual(original.getpixel((xx,y)),tuple(overlay['rgb']))
            x,y,w,h=entry['credit_rect']
            self.assertEqual(covered,{(xx,yy) for yy in range(y,y+h) for xx in range(x,x+w)})

    def test_full_and_early_input_routes_match_baseline(self):
        for stem in ['pc-intro','pc-intro-skip']:
            base=ROOT/('artifacts/'+stem+'-baseline-'+('02' if stem=='pc-intro' else '01'))
            trace=ROOT/('artifacts/'+stem+'-trace-01')
            a=json.loads((base/'report.json').read_text());b=json.loads((trace/'report.json').read_text())
            count,skip=(6000,None) if stem=='pc-intro' else (1800,450)
            self.assertEqual((a['frames'],b['frames']),(count,count))
            self.assertEqual((len(a['records']),len(b['records'])),(count,count))
            self.assertEqual((a['skip_after'],b['skip_after']),(skip,skip))
            self.assertEqual(a['records'],b['records'])
            self.assertEqual(a['images'],b['images'])
            self.assertEqual(a['transitions'],b['transitions'])
            inputs=[(r['index'],r['keys']) for r in b['records'] if r['keys']]
            expected=[(i,['return']) for i in range(3)]
            if skip is not None:expected += [(i,['space']) for i in range(skip,skip+3)]
            self.assertEqual(inputs,expected)
            for fingerprint,item in b['images'].items():
                with Image.open(trace/item['image']) as image:
                    self.assertEqual(hashlib.sha256(image.convert('RGB').tobytes()).hexdigest(),fingerprint)


if __name__=='__main__': unittest.main()
