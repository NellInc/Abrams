"""Static-plate source and authored-asset custody; gameplay timing is untouched."""
import hashlib
import json
from pathlib import Path
import unittest
from PIL import Image
from tools.extract_genesis_aftermath import decode, record, composite_smoke, colours
from tools.build_pc_splash_aftermath import build, ROOT, OUT
from tools.extract_genesis_newspapers import render


class SplashAftermathTests(unittest.TestCase):
    def test_unrecognized_rom_rejected_before_optional_emulator(self):
        with self.assertRaisesRegex(ValueError, 'unsupported ROM'):
            decode(b'wrong ROM')

    @unittest.skipUnless((ROOT/'GAME/SCENE1.BIN').exists() and (ROOT/OUT/'catalog.json').exists(), 'requires owned inputs and generated plate kit')
    def test_catalog_exact_source_pixels_and_generated_pins(self):
        data=json.loads((ROOT/OUT/'catalog.json').read_text())
        self.assertEqual({r['name'] for r in data['entries']},{'publisher','scene1','scene2'})
        script=(ROOT/'godot/scripts/pc_splash_aftermath_art.gd').read_text()
        self.assertIn(hashlib.sha256((ROOT/OUT/'catalog.json').read_bytes()).hexdigest(),script)
        for row in data['entries']:
            with self.subTest(name=row['name']):
                with Image.open(ROOT/row['expected_path']) as im:
                    self.assertEqual(im.size,(320,200))
                    self.assertEqual(hashlib.sha256(im.convert('RGB').tobytes()).hexdigest(),row['rgb_sha256'])
                self.assertEqual(hashlib.sha256((ROOT/'GAME'/row['source']).read_bytes()).hexdigest(),row['source_sha256'])
                for field in ['asset','native_asset']:
                    if field not in row: continue
                    asset=row[field]
                    self.assertEqual(hashlib.sha256((ROOT/asset['path']).read_bytes()).hexdigest(),asset['sha256'])
                    with Image.open(ROOT/asset['path']) as im: self.assertEqual(list(im.size),asset['size'])
                self.assertEqual(row['program'],'START' if row['name']=='publisher' else 'SIM')

    @unittest.skipUnless((ROOT/'GENESIS/M-1 Abrams Battle Tank (USA, Europe).md').exists() and (ROOT/'local-art/genesis/source/aftermath-v1/manifest.json').exists(), 'requires owned Genesis ROM and extracted donors')
    def test_scene2_includes_original_smoke_overlay(self):
        rom=(ROOT/'GENESIS/M-1 Abrams Battle Tank (USA, Europe).md').read_bytes()
        base=ROOT/'local-art/genesis/source/aftermath-v1'
        data=json.loads((base/'manifest.json').read_text())['entries']['scene2']
        self.assertEqual(record(rom,0x18628,23),0x1C5AC)
        resources=data['resources']
        tiles=(base/resources['tiles']['file']).read_bytes()
        background=(base/resources['map']['file']).read_bytes()
        smoke=(base/resources['smoke_map']['file']).read_bytes()
        palette=colours(rom,data['palette_command'])
        image=render(tiles,background,palette); original=image.tobytes()
        composite_smoke(image,tiles,smoke,palette)
        self.assertNotEqual(image.tobytes(),original)
        with Image.open(base/data['image']) as final: self.assertEqual(final.tobytes(),image.tobytes())
        self.assertEqual(data['overlay']['rect'],[160,16,32,128])


if __name__=='__main__': unittest.main()
