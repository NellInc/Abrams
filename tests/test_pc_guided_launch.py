import copy
import struct
import unittest
from pathlib import Path
from tools.pc_guided_launch import GuidedLaunches, catalog, links
from tools.pc_audio_events import AudioEvents


class GuidedTests(unittest.TestCase):
    def fixture(self):
        source = catalog()
        ds = bytearray(65536)
        def w(at,value): struct.pack_into('<H',ds,at,value)
        w(0x79c2,source['shape_base']); w(0x6f54,0x9000); w(0xa08,1)
        w(0x8dc4,0x9100); w(0x798a,1); w(0x8654,0x9200)
        row = source['classes'][15]; at=row['table_offset']
        w(0x9200+30,at); w(at,row['name_pointer'])
        ds[at+6:at+9] = bytes([161,161,255])
        ds[row['name_pointer']:row['name_pointer']+len(row['name'])+1]=row['name'].encode()+b'\0'
        actor,projectile,player=0x709e,0x709e + 58,0x709e+116
        for pointer,shape in ((actor,161),(projectile,source['shape_base']+71),(player,1)):
            ds[pointer]=128;ds[pointer+1]=shape
        w(projectile+2,100);w(projectile+36,250)
        ds[0x9000]=1;w(0x9001,0x9100);w(0x9003,actor);w(0x900f,projectile);w(0x900c,10)
        w(0x9100,15);w(0x777e,0x9000);w(0x7776,actor);w(0x799b,player);w(0x5fc6,player)
        registers=[0,0x9000,0,0,0,0,0x8000,0x7fc0,0x1000,0x29e0,0x29e0,0x4000]
        helper=GuidedLaunches(source=source,shapes=[{}]*161+[{'roots':[{'offset':99}]}])
        helper.enabled=True;helper.before_frame(50,2)
        ram=bytes(0x29e00)+ds+bytes(640*1024-0x29e00-65536)
        helper.freeze(ram,0x1000,7)
        drawing={'sequence':7,'start_ram_sha256':'a'*64,'objects':[{'dynamic_instance':True,'pointer':actor,'shape_index':161,'root':99}]}
        presented={'draw_pass':drawing,'video_sha256':'b'*64,'ui_overlay':{'mask_sha256':'c'*64}}
        return helper,ds,registers,presented

    def packet(self,ds,gate=1): return struct.pack('<4H',1,0,gate,0)+ds

    def test_exact_already_presented_pose_and_unique_owner(self):
        h,ds,r,p=self.fixture()
        c=h.candidate(r,self.packet(ds),0x33f,p)
        self.assertEqual(c['source']['owner'],1)
        self.assertEqual(c['pose'],{'position':[16384,16384,0],'orientation':[0,0,0]})
        self.assertEqual((c['frame'],c['epoch'],c['token']),(50,2,1))
        p['draw_pass']['objects'].append(copy.deepcopy(p['draw_pass']['objects'][0]))
        self.assertIsNone(h.candidate(r,self.packet(ds),0x33f,p))
        p['draw_pass']['objects'].pop()
        p['draw_pass']['objects'][0]['root']=999
        self.assertIsNone(h.candidate(r,self.packet(ds),0x33f,p))
        p['draw_pass']['objects'][0]['root']=99
        ds[0x709e+24]=1
        moved=h.candidate(r,self.packet(ds),0x33f,p)
        self.assertEqual(moved['display_pose']['orientation'],[0,0,0])
        self.assertEqual(moved['pose']['orientation'],[1,0,0])

    def test_bad_packet_register_pool_class_gate_and_old_capability(self):
        h,ds,r,p=self.fixture()
        packet=self.packet(ds)
        for raw in (packet[:-1],packet+b'X',b'\2'+packet[1:],self.packet(ds,0)):
            self.assertIsNone(h.candidate(r,raw,0x33f,p))
        for index,value in ((9,0),(7,2),(11,65535),(1,0)):
            altered=r.copy();altered[index]=value
            self.assertIsNone(h.candidate(altered,packet,0x33f,p))
        for at,value in ((0x900f,0xffff),(0x8654,0xffff),(0x6f54,0xffff)):
            altered=bytearray(ds);struct.pack_into('<H',altered,at,value)
            self.assertIsNone(h.candidate(r,self.packet(altered),0x33f,p))
        ds[0x709e]|=16
        self.assertIsNone(h.candidate(r,self.packet(ds),0x33f,p))
        h.enabled=False
        self.assertIsNone(h.candidate(r,packet,0x33f,p))

    def test_immediate_original_pair_preserves_sample_and_bytes(self):
        h,ds,r,p=self.fixture();packet=self.packet(ds)
        h.observe(59,r,packet,0x33f,p)
        audio_raw=struct.pack('<6H',0x9107,0x34f,15,0,1,0)
        audio_regs=r.copy();audio_regs[0]=15;audio_regs[7]-=4
        candidate=h.observe(25,audio_regs,audio_raw,0,p)
        audio=AudioEvents();audio.observe(audio_raw,guided_launch=candidate)
        event,=audio.drain()
        self.assertEqual((event['sample'],event['voice'],event['value'],event['return_ip']),('pc_request_15',None,15,0x34f))
        self.assertEqual(event['guided_launch']['token'],1)
        h.observe(59,r,packet,0x33f,p)
        bad_regs=audio_regs.copy();bad_regs[1]=0
        self.assertIsNone(h.observe(25,bad_regs,audio_raw,0,p))
        self.assertIsNone(h.observe(25,audio_regs,audio_raw,0,p))
        for clear in ('callback','frame','reset'):
            h.observe(59,r,packet,0x33f,p)
            if clear=='callback':h.observe(1,r,b'',0,p)
            elif clear=='frame':h.before_frame(51,2)
            else:h.reset()
            self.assertIsNone(h.observe(25,audio_regs,audio_raw,0,p))

    def test_other_target_sidechannel_once_without_original_audio(self):
        h,ds,r,p=self.fixture()
        struct.pack_into('<H',ds,0x5fc6,0x709e+174);ds[0x709e+174]=128
        h.observe(59,r,self.packet(ds),0x33f,p)
        launch,=h.drain();self.assertFalse(launch['player_target'])
        self.assertIsNone(h.pending);self.assertEqual(h.drain(),[])

    def test_continuity_barriers_reject_recycled_and_rebound_identities(self):
        for kind,pointer,offset in ((1,0x709e,0x02bc),(1,0x709e,0x02b4),
                                    (2,0x9000,0x443f),(1,0x709e,0x0a95),(3,0,0x885a)):
            h,ds,r,p=self.fixture()
            barrier_regs=r.copy()
            if offset in (0x02bc,0x02b4):barrier_regs[8]+=0x0b4d
            h.observe(60,barrier_regs,struct.pack('<4H',1,kind,pointer,0),offset,p)
            self.assertIsNone(h.candidate(r,self.packet(ds),0x33f,p))
        h,ds,r,p=self.fixture()
        ds[0x709e+4]=123;ds[0x709e+26]=17
        self.assertIsNotNone(h.candidate(r,self.packet(ds),0x33f,p))
        # An allocation at another pool slot cannot invalidate the actor.
        other_regs=r.copy();other_regs[8]+=0x0b4d
        h.observe(60,other_regs,struct.pack('<4H',1,1,0x709e + 58,0),0x02b4,p)
        self.assertIsNotNone(h.candidate(r,self.packet(ds),0x33f,p))
        h.reset();self.assertEqual(h.actor_revisions,{})
        self.assertEqual(h.controller_revisions,{})
        self.assertFalse(h.frozen)

    def test_barrier_removes_paired_context_without_changing_original_audio(self):
        h,ds,r,p=self.fixture()
        audio_regs=r.copy();audio_regs[0]=15;audio_regs[7]-=4
        raw=struct.pack('<6H',0x9107,0x34f,15,0,1,0)
        h.observe(59,r,self.packet(ds),0x33f,p)
        candidate=h.observe(25,audio_regs,raw,0,p)
        audio=AudioEvents();audio.observe(raw,guided_launch=candidate)
        h.observe(60,r,struct.pack('<4H',1,2,0x9000,0),0x429a,p)
        event,=audio.drain()
        self.assertNotIn('guided_launch',event)
        self.assertEqual(event['sample'],'pc_request_15')
        h,ds,r,p=self.fixture()
        target=0x709e+174;ds[target]=128;struct.pack_into('<H',ds,0x5fc6,target)
        h.observe(59,r,self.packet(ds),0x33f,p)
        h.observe(60,r,struct.pack('<4H',1,3,0,0),0x516a,p)
        self.assertEqual(h.drain(),[])

    def test_actual_native_blocks_compile_and_revision_only_on_changes(self):
        import shutil
        import subprocess
        import tempfile
        compiler=shutil.which('clang++') or shutil.which('c++')
        if not compiler:self.skipTest('C++ compiler unavailable')
        source=Path('tools/pc_core/abrams_trace.h').read_text()
        block=source[source.index('// Stateless continuity barriers.'):source.index('static INLINE void AbramsTraceInstruction()')]
        launch=source[source.index('    // Stateless successful enemy launch'):source.index('    // Stateless round-form observations')]
        stub=r'''
#include <cstdint>
#include <cstring>
#include <cassert>
using Bit32u=uint32_t; using Bit16u=uint16_t; using Bit8u=uint8_t;
static Bit16u reg_ax,reg_bx,reg_cx,reg_dx,reg_si,reg_di,reg_bp,reg_sp;
static Bit16u cs,ds,es,ss;
#define SegValue(x) (x)
#define SegPhys(x) ((x)*16u)
static unsigned abrams_trace_load=0x1000;
static unsigned calls=0,last_kind=0,last_pointer=0;
static Bit8u ram[640*1024];
static Bit8u mem_readb(unsigned at) { assert(at<sizeof(ram)); return ram[at]; }
static Bit16u mem_readw(unsigned at) { return mem_readb(at)|(mem_readb(at+1)<<8); }
static void MEM_BlockRead(unsigned at,Bit8u* out,unsigned size) { assert(at+size<=sizeof(ram)); memcpy(out,ram+at,size); }
static void abrams_trace_callback(unsigned event,const Bit16u*,const Bit8u* bytes,unsigned,unsigned size) {
    ++calls; if(event==60) {assert(size==8); last_kind=bytes[2]|bytes[3]<<8; last_pointer=bytes[4]|bytes[5]<<8;}
}
static void w(unsigned at,unsigned value) {ram[at]=value;ram[at+1]=value>>8;}
'''
        harness=r'''
static void Launch(unsigned segment,unsigned ip) { const unsigned base=ds*16u;
LAUNCH_BLOCK
}
int main() {
    cs=0x1000;ds=0x29e0;ss=0x4000;reg_sp=0x7fc0;
    const unsigned base=ds*16u;
    reg_bx=0x709e;ram[base+reg_bx+1]=141;reg_ax=141;
    AbramsTraceGuidedContinuity(0x3a73);assert(calls==0);
    reg_ax=142;AbramsTraceGuidedContinuity(0x3a73);
    assert(calls==1 && last_kind==1 && last_pointer==0x709e);
    calls=0;reg_ax=142;ram[base+reg_bx+1]=142;
    AbramsTraceGuidedContinuity(0x3a73);assert(calls==0);
    w(base+0x6f54,0x9000);w(base+0xa08,1);reg_bx=0x9000;
    AbramsTraceGuidedContinuity(0x443f);assert(calls==1 && last_kind==2 && last_pointer==0x9000);
    calls=0;cs=0x1b4d;reg_ax=0x709e + 58;ram[base+reg_ax]=128;
    w(ss*16u+reg_sp,0x02de);w(ss*16u+reg_sp+2,0x1000);
    AbramsTraceGuidedContinuity(0x02b4);assert(calls==1 && last_kind==1 && last_pointer==0x709e + 58);
    // Unknown original or foreign far callers cannot retain stale identity.
    calls=0;w(ss*16u+reg_sp,0xffff);w(ss*16u+reg_sp+2,0x1234);
    Bit8u before[sizeof(ram)];memcpy(before,ram,sizeof(ram));
    AbramsTraceGuidedContinuity(0x02b4);
    assert(calls==1 && last_kind==1 && last_pointer==0x709e + 58);
    assert(memcmp(before,ram,sizeof(ram))==0);
    calls=0;reg_bx=0x709e;reg_bp=0x7f00;
    w(ss*16u+reg_bp+2,0xffff);w(ss*16u+reg_bp+4,0x1234);
    memcpy(before,ram,sizeof(ram));
    AbramsTraceGuidedContinuity(0x02bc);
    assert(calls==1 && last_kind==1 && last_pointer==0x709e);
    assert(memcmp(before,ram,sizeof(ram))==0);
    calls=0;cs=0x1000;reg_bx=58;
    AbramsTraceGuidedContinuity(0x885a);assert(calls==1 && last_kind==3);
    calls=0;reg_bx=1;AbramsTraceGuidedContinuity(0x885a);assert(calls==0);
}
'''.replace('LAUNCH_BLOCK',launch)
        with tempfile.TemporaryDirectory(prefix='abrams-guided-unit-') as directory:
            unit=Path(directory)/'test.cpp';binary=Path(directory)/'test'
            unit.write_text(stub+block+harness)
            built=subprocess.run([compiler,'-std=c++11','-Werror','-Wno-unused-function',str(unit),'-o',str(binary)],capture_output=True,text=True)
            self.assertEqual(built.returncode,0,built.stderr)
            subprocess.run([str(binary)],check=True,capture_output=True,text=True)

    def test_native_hook_read_only_and_own_fire_excluded(self):
        source=Path('tools/pc_core/abrams_trace.h').read_text()
        hook=source[source.index('    // Stateless successful enemy launch'):source.index('    // Stateless round-form observations')]
        self.assertIn('segment == abrams_trace_load && ip == 0x033f',hook)
        self.assertIn('abrams_trace_callback(59,regs,guided_packet,ip,sizeof(guided_packet))',hook)
        for forbidden in ('MEM_BlockWrite','mem_write','CPU_Cycles','reg_ax =','0x2f4b'):
            self.assertNotIn(forbidden,hook)
        self.assertIn('static Bit8u guided_packet[8+65536]',hook)


if __name__=='__main__': unittest.main()
