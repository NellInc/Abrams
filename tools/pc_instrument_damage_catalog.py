#!/usr/bin/env python3
"""Package unchanged original-CPU STATUS fixtures and authored patch hashes."""
import hashlib,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
def sha(data):return hashlib.sha256(data).hexdigest()
def main():
    source=ROOT/'artifacts/finish-20260928/status-damage-oracle-02'
    out=ROOT/'local-art/genesis/status-damage-v1'
    palette=[[0,0,0],[255,255,255],[170,170,170],[85,85,85],[85,85,255],[85,255,255],
        [170,0,0],[170,85,0],[0,170,0],[85,255,85],[255,255,85],[0,0,0],[255,85,85],[0,0,170],[85,255,255],[255,255,255]]
    states=[]
    for bits in range(32):
        raw=(source/f'state-{bits:02}.bin').read_bytes();tags=(source/f'tags-{bits:02}.bin').read_bytes()
        rgb=Image.frombytes('RGB',(320,200),bytes(c for i in raw for c in palette[i]))
        tag=Image.frombytes('L',(320,200),tags)
        rgb.save(source/f'state-{bits:02}.png');tag.save(source/f'tags-{bits:02}.png')
        states.append({'bits':bits,'rgb_sha256':sha(rgb.crop((123,37,307,100)).tobytes()),'tags_sha256':sha(tag.crop((123,37,307,100)).tobytes())})
    base=Image.open(ROOT/'local-art/genesis/source/systems-status-original.png').convert('RGB')
    genesis=ROOT/'local-art/genesis/source/status-damage-v1'
    donor_manifest=json.loads((genesis/'manifest.json').read_text())
    for e in donor_manifest['images']:
        patch=Image.open(genesis/e['image']).convert('RGB');x,y=[v*8 for v in e['tile_origin']]
        mask=Image.new('L',patch.size)
        mask.putdata([255 if p!=base.getpixel((x+i%patch.width,y+i//patch.width)) else 0 for i,p in enumerate(patch.getdata())])
        mask.save(out/f'difference-{e["index"]}.png')
    assets=[{'file':f'damage-{i}.png','sha256':sha((out/f'damage-{i}.png').read_bytes()),'genesis_descriptor':[0x9AD4,0x9AC4,0x9ACC,0x9ADC,0x9ABC][i]} for i in range(5)]
    masks=[{'file':f'difference-{i}.png','sha256':sha((out/f'difference-{i}.png').read_bytes())} for i in range(5)]
    report={'masks':masks,'states':states,'assets':assets,'pristine_sha256':sha((ROOT/'local-art/genesis/cockpit-v2/systems-status-genesis-v1.png').read_bytes()),'source_hashes':{name:sha((ROOT/'GAME'/name).read_bytes()) for name in ['STATUS.BIN','DAMAGE.BMP','SIM.EXE']},'source':'PC DAMAGE.BMP five sprites at original 6f22..7007 positions, original CPU bitmap fixture outputs','generation':'Built-in imagegen 2026-09-28, one high-resolution redraw per exact Genesis extracted damage patch; preserve diagram composition, grey/black/blue palette and damage condition. No gameplay state inferred from artwork.','geometry':'Genesis 98ce descriptors transformed by existing STATUS donor registration'}
    (out/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    print('STATUS_DAMAGE_CATALOG: 32 source states, 5 authored patches')
if __name__=='__main__':main()
