"""Source custody and scope tests for the information-page supplement."""
import hashlib
import json
from pathlib import Path
import unittest
from PIL import Image
from tools.build_pc_information_completion import build, ROOT

class InformationCompletionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data=build()

    def test_reproducible_pinned_catalog(self):
        path=ROOT/'local-art/pc-information-completion-v1/information.json'
        self.assertEqual(json.loads(path.read_text()),self.data)
        pin=hashlib.sha256(path.read_bytes()).hexdigest()
        self.assertIn('const COMPLETION_SHA := "'+pin+'"',(ROOT/'godot/scripts/pc_information_art.gd').read_text())

    def test_three_original_selection_variants_only(self):
        self.assertEqual([(e['name'],e['source_sprite']) for e in self.data['entries']],
                         [('coax',3),('cannon',5),('smoke',7)])
        self.assertEqual([e['layer']['rect'] for e in self.data['entries']],
                         [[124,22,184,64],[125,22,184,64],[125,22,184,64]])
        for e in self.data['entries']:
            self.assertGreater(e['source_pixels_checked'],10000)
            self.assertGreater(e['layer']['size'][0],2000)
            self.assertGreater(e['layer']['size'][1],700)

    def test_surround_does_not_cover_any_original_text_run(self):
        original=json.loads((ROOT/'local-art/pc-information-v3/information.json').read_text())
        for frame in self.data['frames']:
            entry=next(e for e in original['entries'] if e['name']==frame['name'])
            for x,y,w,h in frame['rects']+[frame['footer_rect']]:
                for run in entry['text_runs']:
                    a,b,c,d=run['rect']
                    self.assertFalse(x<a+c and a<x+w and y<b+d and b<y+h)

    def test_footer_mutation_not_authorized(self):
        for frame in self.data['frames']:
            image=Image.open(ROOT/'artifacts/pc-information-baseline-02'/(frame['name']+'.png')).convert('RGB')
            original=hashlib.sha256(image.crop((0,175,320,200)).tobytes()).hexdigest()
            self.assertIn(original,frame['footer_sha256'])
            image.putpixel((200,175),(255,0,255))
            self.assertNotIn(hashlib.sha256(image.crop((0,175,320,200)).tobytes()).hexdigest(),frame['footer_sha256'])

    def test_blocked_heat_not_added(self):
        self.assertNotIn('heat',[e['name'] for e in self.data['entries']+self.data['frames']])

    def test_embedded_caption_contours_preserve_source_cells(self):
        from tools.build_pc_outline_fonts import point_in_polygon
        self.assertEqual([c['text'] for c in self.data['crew_captions']],['ABRAMS','M1A1'])
        for caption in self.data['crew_captions']+self.data['overhead_captions']:
            x,y,w,h=caption['rect']
            for i,ink in enumerate(caption['mask']):
                values=[point_in_polygon((i%w+.5,i//w+.5),p) for p in caption['contours']]
                if None not in values:self.assertEqual(sum(values)%2==1,bool(ink))

    def test_overhead_captions_retain_original_pc_masks(self):
        for caption in self.data['overhead_captions']:
            image=Image.open(ROOT/'artifacts/pc-information-baseline-02'/(caption['page']+'.png')).convert('RGB')
            x,y,w,h=caption['original_rect']
            self.assertEqual(caption['original_mask'],[int(c==(255,255,255)) for c in image.crop((x,y,x+w,y+h)).getdata()])
            self.assertEqual(sum(caption['mask']),46)

    def test_observed_crew_variants_are_exact_full_frame_pins(self):
        frames=self.data['crew_frames']
        self.assertEqual(len(frames['full_rgb_sha256']),4)
        self.assertEqual(frames['difference_bounds'],[10,175,300,1])
        source=Image.open(ROOT/'artifacts/pc-information-baseline-02/crew.png').convert('RGB')
        source.putpixel((10,190),(255,0,255))
        self.assertNotIn(hashlib.sha256(source.tobytes()).hexdigest(),frames['full_rgb_sha256'])

    def test_legacy_recognition_is_source_proven_unreachable(self):
        from tools.inspect_pc_recognition import inspect
        data=inspect()
        self.assertEqual(len(data['entries']),13)
        self.assertEqual(len(data['question_forms']),5)
        self.assertTrue(all(not e['live_reachable'] for e in data['entries']))

    def test_complete_genesis_resource_chain_boundaries(self):
        from tools.extract_genesis_information_inventory import chain
        rom=(ROOT/'GENESIS/M-1 Abrams Battle Tank (USA, Europe).md').read_bytes()
        maps=chain(rom,0x18628,0x1dfde,'map')
        tiles=chain(rom,0x1dfde,0x3c09e,'tiles')
        self.assertEqual((len(maps),len(tiles)),(53,26))
        self.assertEqual((maps[-1]['end'],tiles[-1]['end']),(0x1dfde,0x3c09e))

if __name__=='__main__': unittest.main()
