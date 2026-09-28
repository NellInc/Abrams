#!/usr/bin/env python3
"""Inventory the supplied START's unreachable vehicle-identification resources.

Read-only source analysis. No original executable, native instruction, gameplay
state or copy-protection control flow is changed.
"""
import hashlib,json,struct
from pathlib import Path
from tools.unpack_pc_executables import unpack
from tools.inspect_scenarios import decode_resource
from tools.pc_bitmaps import decode_bitmaps
ROOT=Path(__file__).resolve().parents[1]
NAMES=['M60A3','M1A1','M113','M2 Bradley','T-62','T-64','T-72','T-80','BMP-1','BMP-2','BTR-70','ACRV-2','BRDM-2']
# Five-parameter tuples match the supplied manual's vehicle specifications.
# Page numbers are PDF pages (the local manual-text extraction marks these).
PAGES=[38,37,37,38,40,40,41,42,33,34,36,33,34]
EXPECTED=[(57,48,694,363,327),(63,72,791,365,237),(12,67,486,228,254),
          (24,66,645,323,256),(44,50,663,330,239),(42,60,645,362,233),
          (45,60,695,360,237),(46,68,691,364,228),(14,78,674,294,215),
          (16,62,671,309,206),(12,80,785,280,245),(13,58,632,284,234),(8,95,575,235,231)]

def inspect(root=ROOT):
    source=(root/'GAME/START.EXE').read_bytes();pin=hashlib.sha256(source).hexdigest()
    if pin!='a6fd07ae3df4f61806852d92c0c50354b7f7afccee10da88710ef0bc3361ca6a':raise ValueError('START source differs')
    raw,meta=unpack(source);ds=0x15050
    if raw[0xd66:0xd6b]!=bytes.fromhex('558bec eb4f'):raise ValueError('entry skip differs')
    if 0xd69+2+raw[0xd6a]!=0xdba:raise ValueError('entry skip target differs')
    if raw[0xda5:0xda8]!=bytes.fromhex('e8621c') or 0xda8+0x1c62!=0x2a0a:raise ValueError('unreached quiz call differs')
    if raw[0x2c00:0x2c03]!=bytes.fromhex('b80100'):raise ValueError('quiz return differs')
    if raw[0x2b43:0x2b48]!=bytes.fromhex('b90d00f7f9'):raise ValueError('sprite selector count differs')
    sprites=decode_bitmaps(decode_resource((root/'GAME/TANKS.BMP').read_bytes()))
    if len(sprites)!=13:raise ValueError('recognition image count differs')
    tables=[list(raw[ds+a:ds+a+13]) for a in [0x23da,0x23e7]]
    tables += [list(struct.unpack_from('<13H',raw,ds+a)) for a in [0x23fa,0x2414,0x242e]]
    entries=[]
    for i,sprite in enumerate(sprites):
        values=tuple(t[i] for t in tables)
        if values!=EXPECTED[i] or (sprite['width'],sprite['height'])!=(200,79):raise ValueError('identity tuple or sprite dimensions differ')
        entries.append({'index':i,'identity':NAMES[i],'size':[200,79],'manual_pdf_page':PAGES[i],
                        'weight_tons':values[0],'speed_kmh':values[1],'dimensions_cm':list(values[2:]),
                        'source_pixel_sha256':hashlib.sha256(bytes(sprite['pixels'])).hexdigest(),
                        'file':f'tanks-{i:02}.png','live_reachable':False})
    return {'start_sha256':pin,'decoded_sha256':meta['decoded_sha256'],'count':13,'entries':entries,
            'table_offsets_ds':{'weight':0x23da,'speed':0x23e7,'length':0x23fa,'width':0x2414,'height':0x242e},
            'question_forms':['weight','speed','length','width','height'],
            'instruction_evidence':{'entry':'0D66: 55 8B EC; 0D69: EB 4F -> 0DBA','skipped_quiz_call':'0DA5: E8 62 1C -> 2A0A','quiz_return':'2C00: B8 01 00','selector':'2B43: B9 0D 00 F7 F9, signed remainder by13','sprite_position':[60,40]},
            'classification':'Unreachable legacy resources of the supplied source build, excluded from missing live-play art. Isolated source inventory only. Original control flow preserved.'}

if __name__=='__main__':
    out=ROOT/'artifacts/finish-20260928/recognition-source/inventory.json';out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(inspect(),indent=2)+'\n');print('PC_RECOGNITION: 13 identities; five question forms; supplied entry unconditionally skips quiz')
