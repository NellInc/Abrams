#!/usr/bin/env python3
"""Enumerate complete chained Genesis map/tile resources for donor research.

Decoding executes the untouched original ROM routine in isolated private RAM.
Map previews use diagnostic grayscale, not a claim about the live palette.
"""
import argparse,hashlib,json,struct,sys
from pathlib import Path
ROOT_FOR_IMPORT = Path(__file__).resolve().parents[1]
if str(ROOT_FOR_IMPORT) not in sys.path: sys.path.insert(0, str(ROOT_FOR_IMPORT))
from tools.extract_genesis_newspapers import ROOT,ROM_SHA
from tools.source_guard import inside_source

def chain(rom,start,stop,kind):
    items=[];at=start
    while at<stop:
        length,w,h=struct.unpack_from('>IHH',rom,at)
        end=(at+4+length+1)&~1
        if not at<end<=stop or not 0<w<=2048:raise ValueError('invalid chain record')
        items.append({'index':len(items),'record':at,'end':end,'compressed_size':length,'width':w,'height':h,'kind':kind})
        at=end
    if at!=stop:raise ValueError('chain boundary')
    return items

def decode(rom,items,out):
    from unicorn import Uc,UC_ARCH_M68K,UC_MODE_BIG_ENDIAN,UC_PROT_READ,UC_PROT_EXEC
    from unicorn.m68k_const import UC_CPU_M68K_M68000,UC_M68K_REG_SR,UC_M68K_REG_A0,UC_M68K_REG_A1,UC_M68K_REG_A7,UC_M68K_REG_PC
    m=Uc(UC_ARCH_M68K,UC_MODE_BIG_ENDIAN);m.ctl_set_cpu_model(UC_CPU_M68K_M68000)
    m.mem_map(0,0x80000);m.mem_write(0,rom);m.mem_protect(0,0x80000,UC_PROT_READ|UC_PROT_EXEC);m.mem_map(0xffff0000,65536)
    for entry in items:
        m.mem_write(0xffff0000,bytes(65536));m.reg_write(UC_M68K_REG_SR,0x2000);m.reg_write(UC_M68K_REG_A7,0xffffef00);m.mem_write(0xffffef00,struct.pack('>I',0x70000));m.reg_write(UC_M68K_REG_A0,entry['record']+12);m.reg_write(UC_M68K_REG_A1,0xffff0000)
        m.emu_start(0x9afe,0x70000,count=3000000)
        if m.reg_read(UC_M68K_REG_PC)!=0x70000:raise ValueError('decoder did not return')
        size=m.reg_read(UC_M68K_REG_A1)-0xffff0000
        expected=entry['width']*(entry['height']*2 if entry['kind']=='map' else 32)
        if size!=expected or not 0<size<0xd000:raise ValueError('resource extent differs')
        data=bytes(m.mem_read(0xffff0000,size));p=out/(entry['kind']+f"-{entry['index']:02}.bin");p.write_bytes(data)
        entry.update(file=p.name,size=size,sha256=hashlib.sha256(data).hexdigest())

def render(out,report,rom):
    from PIL import Image,ImageDraw
    maps=report['maps'];banks=report['tiles'];candidates=[]
    # Diagnose direct tile-bank/map script pairs, bounded by 96-byte locality.
    # These are research pointers; the native captures remain visual authority.
    for bank in banks:
        needle=struct.pack('>HHH',10,0,bank['index']);at=0
        while (at:=rom.find(needle,at))>=0:
            if 0x7000<=at<0xa000:
                for d in range(at+6,min(at+96,len(rom)-10),2):
                    if rom[d:d+2]==b'\x00\x0d':
                        _,x,y,layer,index=struct.unpack_from('>5H',rom,d)
                        if index<len(maps) and x<64 and y<32 and layer<3:
                            candidates.append({'tiles':bank['index'],'map':index,'script':at,'map_command':d,'destination':[x,y],'layer':layer})
            at+=1
    for e in maps:
        table=(out/e['file']).read_bytes();maxindex=max(d&2047 for d, in struct.iter_unpack('>H',table));e['max_tile']=maxindex
        possible=[c for c in candidates if c['map']==e['index'] and banks[c['tiles']]['width']>maxindex]
        selected=possible[0]['tiles'] if possible else min((b for b in banks if b['width']>maxindex),key=lambda b:b['width'])['index']
        tiles=(out/banks[selected]['file']).read_bytes();im=Image.new('RGB',(e['width']*8,e['height']*8))
        for y in range(im.height):
            for x in range(im.width):
                d=struct.unpack_from('>H',table,((y//8)*e['width']+x//8)*2)[0];index=d&2047;tx=7-x%8 if d&0x800 else x%8;ty=7-y%8 if d&0x1000 else y%8;b=tiles[index*32+ty*4+tx//2];c=(b>>(4 if tx%2==0 else 0))&15;v=c*17;im.putpixel((x,y),(v,v,v))
        file=f"map-{e['index']:02}-candidate-bank-{selected:02}.png";im.save(out/file);e.update(preview=file,preview_bank=selected,script_candidates=possible)
    report['script_pair_candidates']=candidates
    sheet=Image.new('RGB',(1280,((len(maps)+3)//4)*232),'#333333');draw=ImageDraw.Draw(sheet)
    for e in maps:
        x=e['index']%4*320;y=e['index']//4*232;draw.text((x+4,y+3),f"MAP {e['index']} / BANK {e['preview_bank']} / {e['width']}x{e['height']}",fill='white');im=Image.open(out/e['preview']);sheet.paste(im,(x,y+20))
    sheet.save(out/'map-candidate-contact-sheet.png')

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--render',action='store_true');a=p.parse_args()
    if inside_source(a.output, ROOT):p.error('output must be outside original source directories')
    rom=(ROOT/'GENESIS/M-1 Abrams Battle Tank (USA, Europe).md').read_bytes()
    if hashlib.sha256(rom).hexdigest()!=ROM_SHA:raise ValueError('ROM differs')
    if a.render:
        report=json.loads((a.output/'inventory.json').read_text());render(a.output,report,rom)
    else:
        a.output.mkdir(parents=True,exist_ok=True);maps=chain(rom,0x18628,0x1dfde,'map');tiles=chain(rom,0x1dfde,0x3c09e,'tiles');decode(rom,maps+tiles,a.output);report={'rom_sha256':ROM_SHA,'maps':maps,'tiles':tiles,'scope':__doc__}
    (a.output/'inventory.json').write_text(json.dumps(report,indent=2)+'\n');print('GENESIS_INFORMATION_INVENTORY:',len(report['maps']),'maps;',len(report['tiles']),'tile banks')
if __name__=='__main__':main()
