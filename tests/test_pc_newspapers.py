import hashlib
from pathlib import Path
import struct
import unittest
from tools.extract_genesis_newspapers import render, palette, ROM_SHA
from tools.build_pc_newspaper_catalog import build, PALETTE
from tools.inspect_scenarios import decode_resource
from tools.extract_pc_ui import screen_pixels

ROOT=Path(__file__).resolve().parents[1]
class NewspaperTests(unittest.TestCase):
    def test_tile_flips_and_palette(self):
        tiles=bytearray(32)
        tiles[0]=0x10;tiles[-1]=0x02
        colors=[(i,i,i) for i in range(64)]
        for flag,location in [(0,(0,0)),(0x800,(7,0)),(0x1000,(0,7)),(0x1800,(7,7))]:
            table=struct.pack('>H',flag|0x2000)*1000
            im=render(bytes(tiles),table,colors)
            self.assertEqual(im.getpixel(location),(17,17,17))
    def test_bad_geometry_and_missing_tiles(self):
        for tiles,table in [(b'\0'*31,b'\0'*2000),(b'\0'*32,b'\0'*1998),(b'\0'*32,b'\0\1'*1000)]:
            with self.assertRaises(ValueError):render(tiles,table,[(0,0,0)]*64)
    @unittest.skipUnless((ROOT/'GAME/END.EXE').exists(),'private original inputs unavailable')
    def test_three_exact_source_bindings(self):
        data=build()
        self.assertEqual({e['source'] for e in data['entries']},{'MOSCOW','PARIS','STALE'})
        for e in data['entries']:
            pixels=screen_pixels(decode_resource((ROOT/'GAME'/e['source']).read_bytes()))
            rgb=bytes(c for i in pixels for c in PALETTE[i])
            self.assertEqual(hashlib.sha256(rgb).hexdigest(),e['rgb_sha256'])
            self.assertEqual(hashlib.sha256(rgb[:320*72*3]).hexdigest(),e['header_sha256'])
            self.assertGreaterEqual(e['art']['size'][0],1280)
            self.assertEqual(e['native']['size'],[320,200])
    @unittest.skipUnless((ROOT/'GENESIS').exists(),'private Genesis input unavailable')
    def test_original_palette_commands(self):
        rom=next((ROOT/'GENESIS').glob('*.md')).read_bytes()
        self.assertEqual(hashlib.sha256(rom).hexdigest(),ROM_SHA)
        colors=palette(rom)
        self.assertEqual(len(colors),64)
        self.assertEqual(colors[0],(0,0,0))
        self.assertEqual(colors[30],(0,0,0))
        self.assertEqual(colors[31],colors[1])

if __name__=='__main__':unittest.main()
