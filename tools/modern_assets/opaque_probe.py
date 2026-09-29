#!/usr/bin/env python3
"""Finite read-only original-CPU probe of SHAPE.TBL round-form commands.

Runs unmodified relocated SIM code on disposable RAM. Stops at the original
raster entry, before graphics memory writes. Never patches instructions.
"""
import argparse
import json
from pathlib import Path
import struct
from tools.pc_world_oracle import OriginalWorld, CODE_SEGMENT, DS
from tools.pc_bearing_oracle import LOAD, DATA_SEGMENT, set_registers, run_until
from tools.pc_vehicle_catalog import source_catalog, ROOT
from tools.inspect_shapes import primitive_vertices
from tools.inspect_scenarios import decode_resource
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_ES,UC_X86_REG_SS,UC_X86_REG_SP,UC_X86_REG_EFLAGS,UC_X86_REG_BP,UC_X86_REG_DI


def run():
    catalog,shapes=source_catalog();raw=decode_resource((ROOT/'GAME/SHAPE.TBL').read_bytes())
    original=OriginalWorld((ROOT/'GAME/SIM.EXE').read_bytes(),raw)
    rows=[]
    for index in (111,145,153,156,161,162):
        shape=shapes[index]
        for cmd in shape['opaque_commands']:
            data=bytes.fromhex(cmd['hex'])
            center=primitive_vertices(shape,{'encoded_indices':[data[3]]})[0]
            for depth in (512,1024,2048):
                original.write(0x1CDF,b'\x01');original.write(0x1CDE,b'\0')
                original.write(0x1425,bytes([shape['header_byte_2']]))
                original.write(0x142C,struct.pack('<3h',0,depth-center[1],0))
                original.write(0x1499,bytes(128))
                original.write(0x12C2,struct.pack('<3h',1,32767,8))
                original.write(0x1B2B,struct.pack('<2h',160,100))
                machine=original.machine
                set_registers(machine,((UC_X86_REG_CS,CODE_SEGMENT),(UC_X86_REG_DS,DATA_SEGMENT),(UC_X86_REG_ES,0x5000),(UC_X86_REG_SS,0x8000),(UC_X86_REG_SP,0xF000),(UC_X86_REG_EFLAGS,2),(UC_X86_REG_BP,shape['vectors_offset']),(UC_X86_REG_DI,cmd['offset'])))
                machine.mem_write(0x8F000,struct.pack('<H',0xFF00))
                run_until(machine,CODE_SEGMENT*16+0x31A6,(LOAD+0xF8D)*16+0x123E,5000)
                sp=machine.reg_read(UC_X86_REG_SP)
                radius,x,y=struct.unpack('<3h',machine.mem_read(0x80000+sp+4,6))
                expected=[data[1]*256//depth,160+int(center[0]*256/depth),100-int(center[2]*256/depth)]
                if [radius,x,y]!=expected:raise ValueError(f'original arguments differ: {[radius,x,y]} != {expected}')
                colors=list(machine.mem_read(DS+0x359D,2))
                if colors!=[data[2]]*2:raise ValueError('original colors differ')
                rows.append({'shape_index':index,'command_offset':cmd['offset'],'hex':cmd['hex'],'center_raw':center,'radius_raw':data[1],'material_index':data[2],'camera_depth':depth,'raster_arguments':[radius,x,y],'match':True})
    bridge=[]
    shape=shapes[167]
    for static_mode in (0,1):
        original.write(0x1CDF,bytes([static_mode]))
        addresses=[]
        hook=original.machine.hook_add(UC_HOOK_CODE,lambda _m,address,_s,_u:addresses.append(address-CODE_SEGMENT*16),begin=CODE_SEGMENT*16+0x541,end=CODE_SEGMENT*16+0x6CF)
        original.call(0x541,(),far=False,registers=((UC_X86_REG_ES,0x5000),(UC_X86_REG_BP,shape['vectors_offset']),(UC_X86_REG_DI,shape['groups'][0]['offset'])))
        original.machine.hook_del(hook)
        if any(0x576<=a<=0x6C6 for a in addresses):raise ValueError('invisible bridge entered projection/raster path')
        if 0x560 not in addresses or 0x571 not in addresses:raise ValueError('bridge skip branch not witnessed')
        bridge.append({'static_mode':static_mode,'instruction_offsets':addresses,'unconditional_material255_skip':True})
    return {'schema':1,'bridge167':bridge,'source_sha256':catalog['sources'],'executed':'0b4d:31a6 through unmodified far call to0f8d:123e','scope':'Exact original projection/radius/color arguments at raster entry; no claim of new camera-facing geometry or bitmap coverage','cases':rows,'cases_matched':len(rows)}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=ROOT/'local-art/pc-modern/opaque-command-proof.json');args=p.parse_args()
    result=run();args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,indent=2)+'\n');print(f"{result['cases_matched']} original CPU command cases matched")
