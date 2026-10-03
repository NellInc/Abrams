import hashlib
import json
from pathlib import Path
import unittest
from PIL import Image
from tools.build_pc_frontend_catalog import build as existing_catalog, compose
from tools.build_pc_wilson_completion import ROOT, HEIGHTS, build, source_templates


@unittest.skipUnless((ROOT/'GAME/CO.BMP').exists(), 'requires private original PC resources')
class WilsonSourceTests(unittest.TestCase):
    def test_exact_original_tables_and_all_six_prefixes_are_distinct(self):
        entries,sprites,office=source_templates()
        self.assertEqual([e['pose'] for e in entries],[3,4,5])
        self.assertEqual([e['portrait_rect'] for e in entries],
                         [[84,36,136,130],[82,36,138,130],[66,33,148,132]])
        all_entries=existing_catalog(ROOT/'GAME')['templates']+entries
        for height in HEIGHTS:
            self.assertEqual(len({e['hashes'][str(height)] for e in all_entries}),6)
        for entry in entries:
            rgb=compose(office,sprites[entry['pose']],*entry['source_origin'])
            for height in HEIGHTS:
                original=rgb[:320*height*3]
                self.assertEqual(hashlib.sha256(original).hexdigest(),entry['hashes'][str(height)])
        # Prefix-mutation rejection is a runtime property; test_pc_wilson_completion.gd checks the real matcher.

    @unittest.skipUnless((ROOT/'local-art/pc-wilson-completion-v1/office.json').exists(),
                         'requires private generated Wilson artwork')
    def test_authored_art_and_written_catalog_match(self):
        catalog=build()
        saved=json.loads((ROOT/'local-art/pc-wilson-completion-v1/office.json').read_text())
        self.assertEqual(json.loads(json.dumps(catalog)),saved)
        for entry in catalog['templates']:
            path=ROOT/'local-art/genesis/remastered'/entry['art']['file']
            with Image.open(path) as image:
                self.assertEqual(image.mode,'RGBA')
                self.assertGreaterEqual(min(image.size),512)
                alpha=image.getchannel('A')
                self.assertEqual(alpha.getextrema(),(0,255))
                self.assertGreater(alpha.histogram()[0],image.width*image.height//10)
            self.assertIn('Authored performance variant',entry['art']['basis'])


if __name__=='__main__': unittest.main()
