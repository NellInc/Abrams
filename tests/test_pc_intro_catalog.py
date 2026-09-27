import hashlib
import json
from pathlib import Path
import unittest
from PIL import Image
from tools.build_pc_intro_catalog import build, FRAMES

ROOT = Path(__file__).resolve().parents[1]


class IntroCatalogTests(unittest.TestCase):
    def test_source_composition_and_reproducible_catalog(self):
        data = build(ROOT,ROOT/'artifacts/pc-intro-trace-01')
        self.assertEqual((json.dumps(data,indent=2)+'\n').encode(),(ROOT/'local-art/pc-intro-v2/intro.json').read_bytes())
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
            self.assertEqual(a['records'],b['records'])
            self.assertEqual(a['images'],b['images'])
            for fingerprint,item in b['images'].items():
                with Image.open(trace/item['image']) as image:
                    self.assertEqual(hashlib.sha256(image.convert('RGB').tobytes()).hexdigest(),fingerprint)


if __name__=='__main__': unittest.main()
