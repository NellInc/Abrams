#!/usr/bin/env python3
"""Recover five Genesis STATUS damage maps using its unchanged decompressor.

Original sources are read-only. Native capture palette/tiles are authenticated.
The outputs are extraction oracles, never generated replacement artwork.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys

ROOT=Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:sys.path.insert(0,str(ROOT))
from tools.extract_genesis_aftermath import record
from tools.extract_genesis_newspapers import ROM_SHA
from tools.source_guard import inside_source
DESCRIPTORS=[0x9AD4,0x9AC4,0x9ACC,0x9ADC,0x9ABC]
PC_ORIGINS=[(188,54),(206,38),(203,83),(251,50),(146,65)]


def decode(rom):
    from unicorn import Uc, UC_ARCH_M68K, UC_MODE_BIG_ENDIAN, UC_PROT_READ, UC_PROT_EXEC
    from unicorn.m68k_const import (UC_CPU_M68K_M68000,UC_M68K_REG_SR,UC_M68K_REG_A0,
        UC_M68K_REG_A1,UC_M68K_REG_A7,UC_M68K_REG_PC)
    if hashlib.sha256(rom).hexdigest()!=ROM_SHA:raise ValueError('unsupported Genesis source')
    m=Uc(UC_ARCH_M68K,UC_MODE_BIG_ENDIAN);m.ctl_set_cpu_model(UC_CPU_M68K_M68000)
    m.mem_map(0,0x80000);m.mem_write(0,rom);m.mem_protect(0,0x80000,UC_PROT_READ|UC_PROT_EXEC)
    m.mem_map(0xFFFF0000,0x10000)
    result=[]
    for index,at in enumerate(DESCRIPTORS):
        x,y,base,chain=struct.unpack_from('>4H',rom,at)
        start=record(rom,0x18628,chain);width,height=struct.unpack_from('>2H',rom,start+4)
        m.mem_write(0xFFFF0000,bytes(65536));m.reg_write(UC_M68K_REG_SR,0x2000)
        m.reg_write(UC_M68K_REG_A7,0xFFFFEF00);m.mem_write(0xFFFFEF00,struct.pack('>I',0x70000))
        m.reg_write(UC_M68K_REG_A0,start+12);m.reg_write(UC_M68K_REG_A1,0xFFFF0000)
        m.emu_start(0x9AFE,0x70000,count=2000000)
        size=m.reg_read(UC_M68K_REG_A1)-0xFFFF0000
        if m.reg_read(UC_M68K_REG_PC)!=0x70000 or size!=width*height*2:raise ValueError('original decoder extent/return mismatch')
        result.append({'index':index,'descriptor':at,'map_index':chain,'map_record':start,
            'tile_base':base,'tile_origin':[x,y],'size':[width*8,height*8],
            'pc_origin':PC_ORIGINS[index],'data':bytes(m.mem_read(0xFFFF0000,size))})
    return result


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--render',action='store_true');a=p.parse_args()
    if inside_source(a.output,ROOT,('GAME','GENESIS')):p.error('output must be outside original sources')
    rom=(ROOT/'GENESIS/M-1 Abrams Battle Tank (USA, Europe).md').read_bytes()
    if a.render:
        from PIL import Image
        from tools.extract_genesis_vdp import VDP
        capture=ROOT/'reference/genesis/graphics-status-action-01/status';vdp=VDP(capture)
        report=json.loads((a.output/'manifest.json').read_text())
        for e in report['images']:
            data=(a.output/e['map_file']).read_bytes()
            if hashlib.sha256(data).hexdigest()!=e['map_sha256']:raise ValueError('map source changed')
            im=Image.new('RGB',tuple(e['size']));width=e['size'][0]//8
            for i in range(len(data)//2):
                d=(struct.unpack_from('>H',data,i*2)[0]+e['tile_base'])&65535
                index=d&2047;bank=(d>>13&3)*16
                for y in range(8):
                    for x in range(8):
                        color=vdp.tiles[index][(7-y if d&0x1000 else y)*8+(7-x if d&0x800 else x)]
                        im.putpixel((i%width*8+x,i//width*8+y),vdp.palette[bank+color])
            target=a.output/f"genesis-damage-{e['index']}.png";im.save(target)
            e['image']=target.name;e['image_sha256']=hashlib.sha256(target.read_bytes()).hexdigest()
        report['palette_tiles_capture']=str(capture.relative_to(ROOT));report['capture_receipt_sha256']=hashlib.sha256((capture/'receipt.json').read_bytes()).hexdigest()
    else:
        a.output.mkdir(parents=True,exist_ok=False);entries=decode(rom)
        for e in entries:
            data=e.pop('data');f=a.output/f"damage-{e['index']}-map.bin";f.write_bytes(data)
            e['map_file']=f.name;e['map_sha256']=hashlib.sha256(data).hexdigest()
        report={'rom_sha256':ROM_SHA,'source_routine':'98ce..992a; five conditional map draws; original map decoder9afe',
            'images':entries,'scope':__doc__}
    (a.output/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    print('GENESIS_STATUS_DAMAGE:',len(report['images']),'rendered' if a.render else 'decoded')


if __name__=='__main__':main()
