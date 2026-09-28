#!/usr/bin/env python3
"""Check original orientation instructions, geometry and bounded VGA output.

No instruction replacement or live guest writes. The raster bytes are original
CPU outputs, not an independently implemented polygon rasterizer.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import unicorn
from unicorn import UC_HOOK_CODE, UC_HOOK_INSN, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import (UC_X86_INS_OUT, UC_X86_REG_CS, UC_X86_REG_DS,
    UC_X86_REG_ES, UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_BP, UC_X86_REG_EFLAGS)
try:
    from tools.pc_bearing_oracle import cpu,set_registers,run_until
    from tools.pc_live_state import SimStateReader,SIM_SHA256
    from tools.unpack_pc_executables import unpack
    from tools.pc_orientation import diagram,OrientationRuns,QUAD_CALLERS,GRID_CALLERS,EDGE_CALLERS
except ModuleNotFoundError:
    from pc_bearing_oracle import cpu,set_registers,run_until
    from pc_live_state import SimStateReader,SIM_SHA256
    from unpack_pc_executables import unpack
    from pc_orientation import diagram,OrientationRuns,QUAD_CALLERS,GRID_CALLERS,EDGE_CALLERS

ROOT=Path(__file__).resolve().parents[1]


def verify(ram,quick=False):
    if unicorn.__version__!='2.1.4': raise ValueError('requires pinned Unicorn 2.1.4')
    state=SimStateReader(ROOT/'GAME/SIM.EXE').read(ram)
    if not state: raise ValueError('missing original SIM')
    load=state['load_segment'];base=load*16;ds=load+0x19E0;data=ds*16
    source,report=unpack((ROOT/'GAME/SIM.EXE').read_bytes());source=bytearray(source)
    for entry in report['relocations']:
        at=entry['load_offset'];struct.pack_into('<H',source,at,(struct.unpack_from('<H',source,at)[0]+load)&65535)
    m=cpu();m.mem_write(0,ram)
    seed=[bytes((i*13+p*57)&255 for i in range(65536)) for p in range(4)]
    planes=[];latch=[0]*4;mask=255;checked=set();quads=[];lines=[];writes=0;observer=OrientationRuns()

    def instruction(_m,address,size,_user):
        if (address,size) not in checked:
            at=address-base
            if not 0<=at<=len(source)-size or m.mem_read(address,size)!=source[at:at+size]:
                raise ValueError(f'instruction differs from original: {address:x}')
            checked.add((address,size))
        ip=address-base
        if ip==0x6040:
            observer.begin(bytes(m.mem_read(data,65536)),{'cs':load,'ds':ds})
        elif ip==0x5F81:
            bp=m.reg_read(UC_X86_REG_BP);stack=m.reg_read(UC_X86_REG_SS)*16+bp
            caller,outline=struct.unpack('<HH',m.mem_read(stack+2,4))
            raw=m.mem_read(data+0x6486,40)
            x=struct.unpack_from('<4h',raw);y=struct.unpack_from('<4h',raw,8)
            quads.append({'caller':caller,'edges':bool(outline),'points':[list(p) for p in zip(x,y)],
                          'basis':list(struct.unpack_from('<6i',raw,16)),
                          'flags':list(m.mem_read(data+0x359B,4))})
            observer.quad(bytes(m.mem_read(data+0x359B,4))+bytes(m.mem_read(data+0x35A8,2))+struct.pack('<HH',outline,caller)+bytes(raw))
        elif ip in GRID_CALLERS+EDGE_CALLERS:
            stack=m.reg_read(UC_X86_REG_SS)*16+m.reg_read(UC_X86_REG_SP)
            lines.append({'caller':ip,'points':list(struct.unpack('<4h',m.mem_read(stack,8))),
                          'colour':m.mem_read(data+0x359E,1)[0]})
            observer.line(struct.pack('<H',ip)+bytes(m.mem_read(stack,8))+bytes(m.mem_read(data+0x359E,1))+bytes(m.mem_read(data+0x359B,1))+bytes(m.mem_read(data+0x35A8,2)))

    def out(_m,port,size,value,_user):
        nonlocal mask
        if port==0x3CE and size==2 and value in (0x205,0x003,0x001,0x000,0x004):return
        if port!=0x3CE or size!=2 or value&255!=8:raise ValueError(f'unsupported orientation VGA port {port:x}/{size}/{value:x}')
        mask=value>>8
    def read(_m,_access,address,size,_value,_user):
        if size!=1:raise ValueError('unsupported orientation VGA read size')
        latch[:]=[p[address-0xA0000] for p in planes]
        m.mem_write(address,bytes([latch[0]]))
    def write(_m,_access,address,size,value,_user):
        nonlocal writes
        if size!=1:raise ValueError('unsupported orientation VGA write size')
        at=address-0xA0000
        for p in range(4):planes[p][at]=((255 if value&(1<<p) else 0)&mask)|(latch[p]&(mask^255))
        writes+=1
    m.hook_add(UC_HOOK_CODE,instruction)
    m.hook_add(UC_HOOK_INSN,out,None,1,0,UC_X86_INS_OUT)
    m.hook_add(UC_HOOK_MEM_READ,read,None,0xA0000,0xAFFFF)
    m.hook_add(UC_HOOK_MEM_WRITE,write,None,0xA0000,0xAFFFF)
    cases=[]
    body,turret=(struct.unpack_from('<H',ram,data+at)[0] for at in (0x799B,0x7999))
    for station in (0,1):
        for theme in (0,1):
            for h in range(0,256,32 if quick else 1):
                page=8192*(h&1);status=h%3;relative=(h*16+37)&255;fill=int(h%5!=0)
                fixture=bytearray(ram)
                for at,value,width in [(0x799D,station,1),(0x8D68,theme,2),(body+0x1A,h,1),
                    (turret+0x0B,relative,1),(body+4,h*17-2000,2),(body+6,h*29-1000,2),
                    (0xC94+9,status,1),(0x359C,fill,1),(0x35A8,0xA000+page//16,2)]:
                    fixture[data+at:data+at+width]=(value&((1<<(width*8))-1)).to_bytes(width,'little')
                fixture[data+0xCB6:data+0xCBA]=bytes([6,10,2,8])
                m.mem_write(0,bytes(fixture));quads=[];lines=[];planes=[bytearray(p) for p in seed];mask=255;latch[:]=[0]*4
                m.mem_write(0x8F000,struct.pack('<H',0xFF00))
                set_registers(m,((UC_X86_REG_CS,load),(UC_X86_REG_DS,ds),(UC_X86_REG_ES,ds),
                    (UC_X86_REG_SS,0x8000),(UC_X86_REG_SP,0xF000),(UC_X86_REG_EFLAGS,2)))
                run_until(m,base+0x600C,base+0x62A6,200_000)
                if m.reg_read(UC_X86_REG_SP)!=0xEFF0:raise ValueError('orientation stack differs before text')
                expected=diagram(fixture,data)
                if len(quads)!=4:raise ValueError('original did not draw four orientation polygons')
                for i,(actual,wanted) in enumerate(zip(quads,expected['quads'])):
                    border=(3 if theme else 1) if i<2 else (1 if theme else 2)
                    if i==3 and status:border=10 if status==1 else 6
                    if (actual['caller']!=QUAD_CALLERS[i] or actual['points']!=wanted['points'] or
                        actual['basis']!=wanted['basis'] or actual['flags']!=[0,fill,0,border] or actual['edges']!=(i==2 and theme==0)):
                        raise ValueError(f'quad mismatch station={station} theme={theme} heading={h} i={i}: {actual} != {wanted}')
                grid=[line['points'] for line in lines if line['caller'] in GRID_CALLERS]
                if grid!=expected['grid'] or any(line['colour']!=8 for line in lines if line['caller'] in GRID_CALLERS):raise ValueError('original grid differs')
                edges=[line for line in lines if line['caller'] in EDGE_CALLERS]
                wanted_edges=[] if theme else [{'caller':caller,'colour':colour,'points':quads[2]['points'][i]+quads[2]['points'][(i+1)%4]} for i,(caller,colour) in enumerate(zip(EDGE_CALLERS,[2,8,10,6]))]
                if edges!=wanted_edges:raise ValueError('original edge order/colours differ')
                x,y,w,height=expected['rect'];pixels=bytearray()
                untouched=[bytearray(p) for p in planes]
                for py in range(y,y+height):
                    for px in range(x,x+w):
                        at=page+py*40+px//8;bit=128>>(px&7)
                        pixels.append(sum(1<<p for p in range(4) if planes[p][at]&bit))
                        for p in range(4):untouched[p][at]=(untouched[p][at]&(255^bit))|(seed[p][at]&bit)
                if untouched!=[bytearray(p) for p in seed]:raise ValueError('orientation wrote outside its source rectangle')
                observer.finish(struct.pack('<5H',x,y,w,height,page)+bytes(pixels))
                candidate=observer.scanout(page)
                if candidate is None: raise ValueError('runtime observer rejected original CPU case')
                cases.append({'presentation':candidate[0],'station':station,'theme':theme,'heading':h,'relative':relative,'page':page,'status':status,
                    'geometry':expected,'quads':quads,'lines':lines,'pixels_hex':pixels.hex()})
    return {'sim_sha256':SIM_SHA256,'capture_sha256':hashlib.sha256(ram).hexdigest(),
        'case_count':len(cases),'observer':observer.report(),'instruction_locations':len(checked),'vga_writes':writes,'cases':cases,
        'scope':'unchanged 600c through 62a6; independently checked geometry/grid/edge colours and outside bounds; original CPU raster bytes, no independent polygon-fill or timing parity'}


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--quick',action='store_true');a=p.parse_args()
    if any(a.output.resolve().is_relative_to((ROOT/n).resolve()) for n in ('GAME','GENESIS')):p.error('output must be outside original references')
    result=verify(a.capture.read_bytes(),a.quick);a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='cases'},indent=2))
