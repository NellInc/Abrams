#!/usr/bin/env python3
"""Package unchanged original-CPU STATUS fixtures and authored patch hashes.

The state-XX.png/tags-XX.png renders of the oracle .bin fixtures are written to
--pngs, which defaults to the oracle fixture directory itself: that is where
godot/tests/test_pc_instrument_damage.gd and test_pc_tactical_hud.gd load them,
and this tool is their only producer (pc_instrument_damage_oracle.py writes the
.bin files only)."""
import argparse,hashlib,json,sys
from pathlib import Path
from PIL import Image,ImageChops
ROOT=Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:sys.path.insert(0,str(ROOT))
from tools.source_guard import inside_source
def sha(data):return hashlib.sha256(data).hexdigest()
def difference_mask(patch,base,x,y):
    """255 wherever any RGB channel of the patch differs from the base at its origin."""
    if x<0 or y<0 or x+patch.width>base.width or y+patch.height>base.height:
        raise ValueError('donor patch lies outside the original STATUS image')
    r,g,b=ImageChops.difference(patch,base.crop((x,y,x+patch.width,y+patch.height))).split()
    return ImageChops.lighter(ImageChops.lighter(r,g),b).point(lambda v:255 if v else 0)
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source',type=Path,default=ROOT/'artifacts/finish-20260928/status-damage-oracle-02',
                   help='original-CPU oracle fixture directory holding state/tags-XX.bin')
    p.add_argument('--out',type=Path,default=ROOT/'local-art/genesis/status-damage-v1',
                   help='existing catalog directory holding the authored damage-*.png patches')
    p.add_argument('--pngs',type=Path,
                   help='directory for the state/tags-XX.png fixtures the Godot STATUS tests read '
                        '(default: --source, where those tests load them)')
    a=p.parse_args();source,out=a.source,a.out;pngs=a.pngs if a.pngs is not None else source
    for path in (out,pngs):
        if inside_source(path):p.error('outputs must be outside original sources')
    pngs.mkdir(parents=True,exist_ok=True)
    palette=[[0,0,0],[255,255,255],[170,170,170],[85,85,85],[85,85,255],[85,255,255],
        [170,0,0],[170,85,0],[0,170,0],[85,255,85],[255,255,85],[0,0,0],[255,85,85],[0,0,170],[85,255,255],[255,255,255]]
    states=[]
    for bits in range(32):
        raw=(source/f'state-{bits:02}.bin').read_bytes();tags=(source/f'tags-{bits:02}.bin').read_bytes()
        rgb=Image.frombytes('RGB',(320,200),bytes(c for i in raw for c in palette[i]))
        tag=Image.frombytes('L',(320,200),tags)
        rgb.save(pngs/f'state-{bits:02}.png');tag.save(pngs/f'tags-{bits:02}.png')
        states.append({'bits':bits,'rgb_sha256':sha(rgb.crop((123,37,307,100)).tobytes()),'tags_sha256':sha(tag.crop((123,37,307,100)).tobytes())})
    base=Image.open(ROOT/'local-art/genesis/source/systems-status-original.png').convert('RGB')
    genesis=ROOT/'local-art/genesis/source/status-damage-v1'
    donor_manifest=json.loads((genesis/'manifest.json').read_text())
    for e in donor_manifest['images']:
        patch=Image.open(genesis/e['image']).convert('RGB');x,y=[v*8 for v in e['tile_origin']]
        difference_mask(patch,base,x,y).save(out/f'difference-{e["index"]}.png')
    assets=[{'file':f'damage-{i}.png','sha256':sha((out/f'damage-{i}.png').read_bytes()),'genesis_descriptor':[0x9AD4,0x9AC4,0x9ACC,0x9ADC,0x9ABC][i]} for i in range(5)]
    masks=[{'file':f'difference-{i}.png','sha256':sha((out/f'difference-{i}.png').read_bytes())} for i in range(5)]
    report={'masks':masks,'states':states,'assets':assets,'pristine_sha256':sha((ROOT/'local-art/genesis/cockpit-v2/systems-status-genesis-v1.png').read_bytes()),'source_hashes':{name:sha((ROOT/'GAME'/name).read_bytes()) for name in ['STATUS.BIN','DAMAGE.BMP','SIM.EXE']},'source':'PC DAMAGE.BMP five sprites at original 6f22..7007 positions, original CPU bitmap fixture outputs','generation':'Built-in imagegen 2026-09-28, one high-resolution redraw per exact Genesis extracted damage patch; preserve diagram composition, grey/black/blue palette and damage condition. No gameplay state inferred from artwork.','geometry':'Genesis 98ce descriptors transformed by existing STATUS donor registration'}
    (out/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    print('STATUS_DAMAGE_CATALOG: 32 source states, 5 authored patches')
if __name__=='__main__':main()
