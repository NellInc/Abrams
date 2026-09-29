import base64
import copy
from pathlib import Path
import struct
import unittest
from tools.pc_frontend_scene import FrontendScene, START_PALETTE, PREVIEW, MENU_PREVIEW
from tools.inspect_shapes import primitive_vertices
from tools.inspect_scenarios import decode_resource
from tools.inspect_shapes import inspect_shapes
from tests.test_pc_session import program_ram
ROOT=Path(__file__).resolve().parents[1]

class FrontendSceneTests(unittest.TestCase):
    def setUp(self):self.scene=FrontendScene(ROOT/'GAME')

    def snapshot(self):
        ram=program_ram('START');load=0x1ed;ds=(load+0x1505)*16
        for at,code in self.scene.anchors:ram[load*16+at:load*16+at+len(code)]=code
        struct.pack_into('<H',ram,ds+0x9a0c,0x7000)
        ram[0x70000:0x70000+len(self.scene.shape_bytes)]=self.scene.shape_bytes
        struct.pack_into('<4h',ram,ds+0x264b,10,309,22,175)
        struct.pack_into('<3h',ram,ds+0x4912,16,128,7)
        struct.pack_into('<2h',ram,ds+0x517b,159,98)
        struct.pack_into('<H',ram,ds+0x2660,0xa000)
        struct.pack_into('<9h',ram,ds+0x47cd,16384,0,0,0,16384,0,0,0,16384)
        return ram,{'ds':load+0x1505},ds

    def ready(self):
        ram,regs,ds=self.snapshot();self.scene.observe(49,regs,ram,0)
        shape=self.scene.shapes[20];root=shape['roots'][0];pid=shape['primitives'][0]['offset']
        self.scene.active['background']={'kind':'solid','color':5}
        self.scene.active['objects']=[{'shape_index':20,'root':root['offset'],'primitive_ids':[pid],
                                      'polygons':[{'primitive':pid}]}]
        self.scene.observe(53,regs,bytes([8])*64000,0)
        labels=[{'text':s,'rect':r} for s,r in [('MISSION:',[18,16,64,8]),('TIME:',[42,27,40,8]),('SKILL:',[34,40,48,8])]]
        return bytearray(bytes([0,170,0,0])*64000),copy.deepcopy(START_PALETTE),labels

    def test_pinned_begin_camera_and_resource(self):
        ram,regs,ds=self.snapshot();self.scene.observe(49,regs,ram,0)
        self.assertEqual(self.scene.active['camera']['clip'],[10,22,309,175])
        self.assertEqual(self.scene.active['camera']['focal_pixels'],128)
        for at in (0x70000,0x1ed0+self.scene.anchors[0][0]):
            changed=bytearray(ram);changed[at]^=1;self.scene.observe(49,regs,changed,0)
            self.assertIsNone(self.scene.active)
        struct.pack_into('<h',ram,ds+0x4916,15);self.scene.observe(49,regs,ram,0)
        self.assertIsNone(self.scene.active)

    def test_begin_rejects_wrong_program_and_segment(self):
        ram,regs,ds=self.snapshot()
        self.scene.observe(49,{'ds':0},ram,0);self.assertIsNone(self.scene.active)
        ram[(0x1dd-1)*16+8:(0x1dd-1)*16+16]=b'BRIEF\0\0\0'
        self.scene.observe(49,regs,ram,0);self.assertIsNone(self.scene.active)

    def test_whole_preview_pair_and_geometry_alias(self):
        raw,palette,runs=self.ready();paired=self.scene.paired(raw,palette,runs,None)
        self.assertEqual(paired['objects'][0]['shape_index'],103)
        self.assertEqual(paired['objects'][0]['source_anim_shape'],20)
        self.assertEqual(self.scene.completed[-1][0]['objects'][0]['shape_index'],20)
        self.assertEqual(paired['frontend_scene'],'START/ANIM')
        self.assertEqual(paired['preview_rect'],list(PREVIEW))

    def test_main_menu_pairs_every_exposed_pixel_and_exact_labels(self):
        raw,palette,_=self.ready()
        runs=[{'text':s,'rect':r} for s,r in [('SCENARIO',[20,12,64,8]),
              ('CAMPAIGN',[104,12,64,8]),('M1-INFO',[188,12,56,8]),('EXIT',[264,12,32,8])]]
        paired=self.scene.paired(raw,palette,runs,None)
        self.assertEqual(paired['frontend_view'],'menu')
        self.assertEqual(paired['preview_rect'],list(MENU_PREVIEW))
        for x,y in [(10,22),(309,22),(160,40),(10,175),(309,175)]:
            changed=bytearray(raw);changed[(y*320+x)*4]^=1
            self.assertIsNone(self.scene.paired(changed,palette,runs,None))
        self.assertIsNone(self.scene.paired(raw,palette,runs[:-1],None))
        wrong=copy.deepcopy(runs);wrong[0]['rect'][0]+=1
        self.assertIsNone(self.scene.paired(raw,palette,wrong,None))

    def test_one_changed_pixel_at_each_boundary_rejects_stale_preview(self):
        raw,palette,runs=self.ready()
        for x,y in [(10,78),(309,78),(10,175),(309,175),(160,100)]:
            changed=bytearray(raw);changed[(y*320+x)*4]^=1
            self.assertIsNone(self.scene.paired(changed,palette,runs,None))
        # Original panel contents are separate from the exposed scene.
        raw[(30*320+120)*4]^=1
        self.assertIsNotNone(self.scene.paired(raw,palette,runs,None))

    def test_only_verified_opaque_cursor_cells_are_excluded(self):
        raw,palette,runs=self.ready();x,y=12,90;raw[(y*320+x)*4]^=1
        cursor={'rect':[x,y,2,1],'indices':base64.b64encode(bytes([15,0])).decode()}
        self.assertIsNotNone(self.scene.paired(raw,palette,runs,cursor))
        raw[(y*320+x+1)*4]^=1
        self.assertIsNone(self.scene.paired(raw,palette,runs,cursor))

    def test_wrong_palette_missing_labels_partial_panel_and_transition_fail_closed(self):
        raw,palette,runs=self.ready()
        self.assertIsNone(self.scene.paired(raw,palette,runs[:-1],None))
        changed=copy.deepcopy(runs);changed[0]['rect'][0]+=1
        self.assertIsNone(self.scene.paired(raw,palette,changed,None))
        palette[0][0]=1;self.assertIsNone(self.scene.paired(raw,palette,runs,None))
        self.scene.clear();self.assertIsNone(self.scene.paired(raw,START_PALETTE,runs,None))

    def test_every_alias_is_exact_original_geometry_and_colours(self):
        target=inspect_shapes(decode_resource((ROOT/'GAME/SHAPE.TBL').read_bytes()))['shapes']
        self.assertEqual(len(self.scene.aliases),21)
        for source,alias in self.scene.aliases.items():
            s=self.scene.shapes[source];t=target[alias['shape']]
            for p in s['primitives']:
                match=next(q for q in t['primitives'] if q['offset']==alias['faces'][p['offset']])
                self.assertEqual(primitive_vertices(s,p),primitive_vertices(t,match))
                self.assertEqual(p['prefix_bytes'][1:],match['prefix_bytes'][1:])

    def test_source_vertices_checked_before_polygon_acceptance(self):
        ram,regs,ds=self.snapshot();self.scene.observe(49,regs,ram,0)
        data=bytearray(ram[ds:ds+65536]);shape=self.scene.shapes[2]
        struct.pack_into('<H',data,0x491c,0x9000);data[0x9001]=2
        data[0x532f]=1;data[0x532e]=0
        struct.pack_into('<H',data,0x532a,0x47cd)
        self.scene.observe(50,{'di':shape['roots'][0]['offset']},data,0)
        primitive=shape['primitives'][0]
        self.scene.observe(51,{'si':primitive['offset']},data,0)
        with self.assertRaisesRegex(ValueError,'vertex mismatch'):self.scene.observe(52,{},data,0)

if __name__=='__main__':unittest.main()
