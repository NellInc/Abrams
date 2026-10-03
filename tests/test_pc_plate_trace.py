from pathlib import Path
import struct
import unittest
from tools.pc_plate_trace import PLATES, PlateLoads

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(all((ROOT / 'GAME' / name).is_file() for name in PLATES + ('ATBASE.BIN', 'SCENE1.BIN', 'SCENE2.BIN')),
                     'Requires separately supplied original PC files')
class PlateTraceTests(unittest.TestCase):
    def make(self):
        return PlateLoads(ROOT / 'GAME', history_limit=2)

    def chunk(self, trace, y=0, count=3200, page=0xA000, x=0, data=None):
        if data is None: data = trace.resources['GPS.BIN'][0][y*160:y*160+count]
        return struct.pack('<6H',0x1234,0x5000,count,x,y,page)+data

    def complete(self, trace, page=0xA000):
        trace.observe(20, b'gps.bin\0')
        for y in range(0,200,20): trace.observe(21,self.chunk(trace,y,page=page))
        trace.observe(22,b'',1)

    def test_all_original_loader_bytes_and_chunk_boundaries(self):
        t = self.make()
        self.complete(t)
        record = t.report()['loads'][0]
        self.assertTrue(record['verified'])
        self.assertEqual(record['bytes'],32000)
        self.assertEqual(record['page_offset'],0)
        self.assertEqual(len(record['chunks']),10)
        self.complete(t,0xA200)
        self.assertEqual(t.report()['loads'][-1]['page_offset'],8192)
        self.complete(t)
        self.assertEqual(t.report()['completed_count'],3)
        self.assertEqual(len(t.report()['loads']),2)

    def test_motor_pool_original_bytes_are_verified(self):
        t=self.make()
        t.observe(20,b'atbase.bin\0')
        for y in range(0,200,20):
            t.observe(21,self.chunk(t,y,data=t.resources['ATBASE.BIN'][0][y*160:y*160+3200]))
        t.observe(22,b'',1)
        record=t.report()['loads'][0]
        self.assertTrue(record['verified'])
        self.assertEqual(record['source_sha256'],'7a2b2e763b37623f423c7f332c2a34d4bb810f5a457a3d8f55aec27e9262ac03')

    def test_unobserved_entry_and_failed_load_never_verify(self):
        t = self.make()
        t.observe(21,self.chunk(t))
        t.observe(22,b'',1)
        self.assertEqual(t.report()['orphan_chunks'],1)
        self.assertEqual(t.report()['loads'],[])
        t.observe(20,b'gps.bin\0')
        t.observe(22,b'',0)
        self.assertFalse(t.report()['loads'][0]['verified'])
        self.assertFalse(t.report()['incomplete_load'])

    def test_unknown_filename_is_data_not_a_path(self):
        t = self.make()
        t.observe(20,b'../gps.bin\0')
        for y in range(0,200,20): t.observe(21,self.chunk(t,y))
        t.observe(22,b'',1)
        self.assertFalse(t.report()['loads'][0]['verified'])
        self.assertIsNone(t.report()['loads'][0]['source_sha256'])

    def test_bad_geometry_order_page_and_bytes_fail_closed(self):
        for change in ({'x':8}, {'y':20}, {'count':159}, {'page':0xA100}, {'data':b'X'*3200}):
            t = self.make()
            t.observe(20,b'gps.bin\0')
            with self.subTest(change=change.keys()), self.assertRaises(ValueError):
                t.observe(21,self.chunk(t,**change))
        t = self.make()
        t.observe(20,b'gps.bin\0')
        t.observe(21,self.chunk(t))
        with self.assertRaisesRegex(ValueError,'page mid-load'):
            t.observe(21,self.chunk(t,20,page=0xA200))
        with self.assertRaisesRegex(ValueError,'incomplete'): t.observe(22,b'',1)

    def test_malformed_nested_and_incomplete_loads(self):
        for raw in (b'',b'\0',b'gps.bin',b'gps\0.bin\0',b'x'*13+b'\0'):
            with self.subTest(raw=raw), self.assertRaises(ValueError): self.make().observe(20,raw)
        t = self.make()
        t.observe(20,b'gps.bin\0')
        self.assertTrue(t.report()['incomplete_load'])
        with self.assertRaisesRegex(ValueError,'nested'): t.observe(20,b'aa.bin\0')
        with self.assertRaisesRegex(ValueError,'header'): t.observe(21,b'')


if __name__ == '__main__': unittest.main()
