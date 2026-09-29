#!/usr/bin/env python3
"""Verify stateless round-span hook stack contracts against original EGA writes.

Uses an existing local capture in disposable Unicorn RAM. Original instructions
execute unchanged; VGA mode-2 bit-mask writes are observed as in pc_material_oracle.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
from unicorn import UC_HOOK_CODE,UC_HOOK_INSN,UC_HOOK_MEM_WRITE
from unicorn.x86_const import *
from tools.pc_bearing_oracle import cpu,set_registers,run_until
from tools.pc_live_state import SimStateReader
from tools.pc_render_trace import Collector
from tools.modern_assets.native_round_hook import NativeRoundHook
from tools.pc_vehicle_catalog import ROOT,source_catalog
from tools.inspect_shapes import primitive_vertices
from tools.inspect_scenarios import decode_resource

SITES={0x1446:20,0x1495:20,0x14c4:16,0x1573:18,0x15c2:18,0x15f1:14,0x125f:14}


def run():
    capture=ROOT/'artifacts/pc-camera-captures-01/gunner-forward.bin'
    ram=capture.read_bytes();state=SimStateReader(ROOT/'GAME/SIM.EXE').read(ram)
    if not state:raise ValueError('supported original capture required')
    load=state['load_segment'];ds=load+0x19e0;cs=load+0xb4d;raster=load+0xf8d
    catalog,shapes=source_catalog();shape_data=decode_resource((ROOT/'GAME/SHAPE.TBL').read_bytes())
    cases=[];fixture=None;native=NativeRoundHook()
    for index,depth,fill,x,y in ((145,512,1,160,100),(145,512,0,160,100),(145,4096,1,160,100),(145,10000,1,160,100),(153,200,1,20,20),(161,256,1,300,195),(111,512,1,160,100),(153,200,1,400,100),(145,512,1,-100,100),(111,1,1,160,100),(161,256,1,160,55),(162,256,1,160,55)):
        shape=shapes[index];cmd=shape['opaque_commands'][0];rawcmd=bytes.fromhex(cmd['hex'])
        point=primitive_vertices(shape,{'encoded_indices':[rawcmd[3]]})[0]
        m=cpu();m.mem_write(0,ram);m.mem_write(0x50000,shape_data)
        def put(at,data):m.mem_write(ds*16+at,data)
        def word(at):return struct.unpack('<H',m.mem_read(at,2))[0]
        put(0x1cdf,b'\1');put(0x1cde,b'\0');put(0x1425,bytes([shape['header_byte_2']]))
        put(0x142c,struct.pack('<3h',-point[0],depth-point[1],-point[2]))
        put(0x1499,bytes(128));put(0x12c2,struct.pack('<3h',1,32767,8));put(0x1b2b,struct.pack('<2h',x,y))
        put(0x3593,struct.pack('<4h',0,319,0,199));put(0x359c,bytes([fill]));put(0x35a8,struct.pack('<H',0xa000));put(0x12cc,struct.pack('<H',100))
        c=Collector(None,history_limit=2);c.active={'sequence':1,'page_offset':0,'objects':[],'unsupported':[]}
        c.current={'pointer':100,'shape_index':index,'polygons':[],'round_forms':[],'draw_order':[]}
        c.active['objects'].append(c.current)

        pixels={};mask=[255];mode=[2];hooks=[]
        def observe(_m,address,_size,_user):
            segment=m.reg_read(UC_X86_REG_CS);ip=address-segment*16
            sp=m.reg_read(UC_X86_REG_SP);stack=m.reg_read(UC_X86_REG_SS)*16+sp
            def transport(event,payload):
                regids=(UC_X86_REG_AX,UC_X86_REG_BX,UC_X86_REG_CX,UC_X86_REG_DX,UC_X86_REG_SI,UC_X86_REG_DI,UC_X86_REG_BP,UC_X86_REG_SP,UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_ES,UC_X86_REG_SS)
                registers=[m.reg_read(r) for r in regids]
                actual=native.observe(bytes(m.mem_read(0,640*1024)),registers,load,ip)
                if actual!=[(event,registers,payload,cmd['offset'])]:raise ValueError(f'native hook transport mismatch at {ip:x}')
                c.observe_round_form(actual[0][0],{'di':registers[5]},actual[0][2],actual[0][3])
            if segment==cs and ip in (0x31a6,0x324a):
                transport(8 if ip==0x31a6 else 47,rawcmd if ip==0x31a6 else b'');return
            if segment!=raster:return
            if ip==0x123e:
                if word(stack)!=0x3247 or word(stack+2)!=cs:raise ValueError('entry caller mismatch')
                fields=[1,cmd['offset'],100,word(stack+4),word(stack+6),word(stack+8),0,0,319,199,0,word(ds*16+0x359d),word(ds*16+0x359b),int.from_bytes(rawcmd[:2],'little'),int.from_bytes(rawcmd[2:],'little')]
                transport(46,struct.pack('<15H',*fields))
            elif ip in SITES:
                d=SITES[ip]
                if word(stack+d)!=0x3247 or word(stack+d+2)!=cs or word(stack+d-6)!=cmd['offset'] or word(stack+d-8)!=0x5000:
                    raise ValueError(f'span stack witness differs at {ip:x}')
                yy=m.reg_read(UC_X86_REG_DI) if ip==0x125f else m.reg_read(UC_X86_REG_BP)//2
                xx=m.reg_read(UC_X86_REG_SI) if ip==0x125f else m.reg_read(UC_X86_REG_BX)
                width=1 if ip==0x125f else m.reg_read(UC_X86_REG_CX)
                first=rawcmd[2] if ip==0x125f else m.reg_read(UC_X86_REG_AX)
                second=m.reg_read(UC_X86_REG_DX) if ip in (0x1495,0x15c2) else first
                fields=[1,cmd['offset'],100,yy,xx,width,0,first,second]
                transport(48,struct.pack('<9H',*fields));hooks.append(ip)
        def out(_m,port,size,value,_u):
            # Original point driver1f66 selects mode2, resets raster-op,
            # then restores mode0/mapmask15/mode2 after its single write.
            if size==2 and port==0x3ce and value in (5,0x205):mode[0]=value>>8;return
            if size==2 and ((port==0x3ce and value==3) or (port==0x3c4 and value==0xf02)):return
            if port!=0x3ce or size!=2 or value&255!=8:raise ValueError(f'unsupported VGA output {port:x}/{size}/{value:x}')
            mask[0]=value>>8
        def write(_m,_access,address,size,value,_u):
            if not 0xa0000<=address<0xa1f40:return
            if address+size>0xa1f40:raise ValueError('round write outside screen')
            if mode[0]!=2:raise ValueError('round write outside verified VGA mode2')
            for j in range(size):
                color=(value>>(j*8))&15;pixel=(address+j-0xa0000)*8
                for bit in range(8):
                    if mask[0]&(128>>bit):pixels[pixel+bit]=color
        m.hook_add(UC_HOOK_CODE,observe)
        m.hook_add(UC_HOOK_INSN,out,None,1,0,UC_X86_INS_OUT)
        m.hook_add(UC_HOOK_MEM_WRITE,write)
        set_registers(m,((UC_X86_REG_CS,cs),(UC_X86_REG_DS,ds),(UC_X86_REG_ES,0x5000),(UC_X86_REG_SS,ds),(UC_X86_REG_SP,0xf000),(UC_X86_REG_EFLAGS,2),(UC_X86_REG_BP,shape['vectors_offset']),(UC_X86_REG_DI,cmd['offset'])))
        m.mem_write(ds*16+0xf000,struct.pack('<H',0xff00))
        run_until(m,cs*16+0x31a6,cs*16+0xff00,1000000)
        form=c.current['round_forms'][0];expected={}
        for span in form['spans']:
            for px in range(span['left'],span['right']):expected[span['y']*320+px]=span['color']
        if pixels!=expected:
            mismatches=[(k,pixels.get(k),expected.get(k)) for k in sorted(set(pixels)|set(expected)) if pixels.get(k)!=expected.get(k)]
            raise ValueError(f'round spans differ shape{index}/depth{depth}/fill{fill}: {mismatches[:12]}, actualrange{(min(pixels),max(pixels)) if pixels else None}, expectedrange{(min(expected),max(expected)) if expected else None}, spans{form["spans"][:5]}')
        cases.append({'shape_index':index,'depth':depth,'fill_mode':fill,'center':[x,y],'pixels_matched':len(pixels),'span_sites':sorted(set(hooks)),'form':form})
        if fixture is None:
            fixture={'schema':1,'scope':'Synthetic pose in disposable original CPU capture; observed exact EGA coverage and color. Not a live gameplay scene.',
                     'sources':catalog['sources'],'capture_sha256':hashlib.sha256(ram).hexdigest(),'camera':state['camera'],'palette_rgb':[[0,0,0],[0,0,170],[0,170,0],[0,170,170],[170,0,0],[170,0,170],[170,85,0],[170,170,170],[85,85,85],[85,85,255],[85,255,85],[85,255,255],[255,85,85],[255,85,255],[255,255,85],[255,255,255]],
                     'objects':[c.current]}
    receipt={'calls_matched':native.calls,'header_sha256':native.header_sha256,'guest_snapshot_unchanged':True,'scope':'Exact compiled cheap-filter/round-form/common-dispatch blocks from production header; not live DOSBox instruction scheduling.'}
    native.close()
    return {'schema':1,'native_hook':receipt,'source_sha256':catalog['sources'],'capture_sha256':hashlib.sha256(ram).hexdigest(),'cases':cases,'cases_matched':len(cases),'pixels_matched':sum(c['pixels_matched'] for c in cases)},fixture

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir',type=Path,default=ROOT/'local-art/pc-modern')
    args=parser.parse_args()
    report,fixture=run();directory=args.output_dir
    directory.mkdir(parents=True,exist_ok=True)
    (directory/'round-span-proof.json').write_text(json.dumps(report,indent=2)+'\n')
    (directory/'round-form-fixture.json').write_text(json.dumps(fixture,indent=2)+'\n')
    print(f"{report['cases_matched']} original CPU raster cases, {report['pixels_matched']} pixels matched")
