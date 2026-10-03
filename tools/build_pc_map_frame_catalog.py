#!/usr/bin/env python3
"""Build source custody for a vector FRAME surround; no tactical data is read."""
import argparse,base64,hashlib,json,sys
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from tools.inspect_scenarios import decode_resource
from tools.extract_pc_ui import screen_pixels
PALETTE=[(0,0,0),(255,255,255),(170,170,170),(85,85,85),(85,85,255),(85,255,255),
 (170,0,0),(170,85,0),(0,170,0),(85,255,85),(255,255,85),(0,0,0),(255,85,85),(0,0,170),(85,255,255),(255,255,255)]
RECTS=[[0,0,320,10],[0,10,10,166],[310,10,10,166],[0,176,320,24]]
FRAME_SHA='bafdc568df27f74147d00cdd6a9efa6ead8dcb5167dfaf71f5be3543fa228d20'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def border_bytes(image):return b''.join(image.crop((x,y,x+w,y+h)).tobytes() for x,y,w,h in RECTS)
def build(root=ROOT):
 source=root/'GAME/FRAME'
 if sha(source)!=FRAME_SHA:raise ValueError('Unsupported FRAME resource')
 indices=screen_pixels(decode_resource(source.read_bytes()));im=Image.new('RGB',(320,200));im.putdata([PALETTE[c] for c in indices])
 motif_image=im.crop((34,2,39,7));motif=list(motif_image.getdata())
 variants=[list(motif_image.rotate(90*i).getdata()) for i in range(4)]
 rivets=[]
 for y in range(182):
  for x in range(316):
   if not (x<10 or x>=310 or y<10 or y>=176):continue
   pixels=list(im.crop((x,y,x+5,y+5)).getdata())
   if pixels in variants:rivets.append({'center':[x+2.5,y+2.5],'quarter_turns':variants.index(pixels)})
 if len(rivets)!=12:raise ValueError('Unexpected FRAME fastener denominator')
 donor=root/'local-art/genesis/source/commander-original.png';genesis=Image.open(donor).convert('RGB')
 def role(c,levels):
  if max(c)-min(c)>10:return -1
  return min(range(4),key=lambda i:abs(c[0]-levels[i]))
 pattern=[role(c,[0,85,170,255]) for c in motif];matches=[]
 for y in range(196):
  for x in range(316):
   if [role(c,[0,65,172,238]) for c in genesis.crop((x,y,x+5,y+5)).getdata()]==pattern:matches.append([x,y,5,5])
 if len(matches)!=10:raise ValueError('Genesis fastener correspondence changed')
 return {'schema':1,'sources':{'FRAME':sha(source),'START.EXE':sha(root/'GAME/START.EXE'),'END.EXE':sha(root/'GAME/END.EXE')},
  'donor':{'path':str(donor.relative_to(root)),'sha256':sha(donor),'matched_motif_rects':matches,
           'basis':'All 25 source motif pixels match grayscale palette roles; geometry shared with Genesis commander'},
  'guard_rects':RECTS,'border_rgb_sha256':hashlib.sha256(border_bytes(im)).hexdigest(),'content_rect':[10,10,300,166],
  'rivets':rivets,'render_rect':[0,0,320,200],'rebuilt_footer':[0,187,320,13],
  'scope':'Analytic original-shaped bevel/green rule/Genesis-shared fasteners and a rebuilt matte-metal footer, applied only when the complete border, footer included, matches border_rgb_sha256. The original content rect remains untouched.'}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=ROOT/'local-art/pc-map-frame-v1/frame.json');a=p.parse_args();d=build()
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(d,indent=2)+'\n');print(sha(a.output))
