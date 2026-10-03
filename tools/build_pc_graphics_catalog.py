#!/usr/bin/env python3
"""Prewarm authentic native Genesis donors; no generated art is an input."""
import base64
import hashlib
import json
import sys
from pathlib import Path
from PIL import Image
ROOT_FOR_IMPORT = Path(__file__).resolve().parents[1]
if str(ROOT_FOR_IMPORT) not in sys.path: sys.path.insert(0, str(ROOT_FOR_IMPORT))
from tools.inspect_scenarios import decode_resource
from tools.extract_pc_ui import screen_pixels

ROOT = Path(__file__).resolve().parents[1]
PALETTE = [(0,0,0),(255,255,255),(170,170,170),(85,85,85),(85,85,255),(85,255,255),(170,0,0),(170,85,0),(0,170,0),(85,255,85),(255,255,85),(0,0,0),(255,85,85),(0,0,170),(85,255,255),(255,255,255)]
EXCLUDE = {
 # Native gunner wells are wider and shifted relative to the PC wells. Keep
 # both complete lower side consoles PC-owned, including every outer margin;
 # destination-only instrument masks otherwise leak captured labels/widgets.
 1:[(0,123,103,200),(108,132,212,199),(215,123,320,200)],
 2:[(14,61,162,161),(13,175,164,195),(206,80,290,188)],
 3:[], 4:[(53,168,268,200)], 5:[],
 6:[(0,87,320,200)]}
PLATES = [('GPS.BIN','gunner'),('TC.BIN','commander'),('AA.BIN','cupola'),('DRIVER.BIN','driver'),('STATUS.BIN','systems-status'),('ATBASE.BIN','motor-pool')]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def build(root=ROOT):
 out=root/'local-art/pc-graphics-native-v1';out.mkdir(exist_ok=True)
 donors={}
 def donor(name,path,pin):
  path=root/path
  if sha(path)!=pin:raise ValueError('native source hash differs: '+str(path))
  with Image.open(path) as im: size=list(im.size)
  donors[name]={'path':str(path.relative_to(root)),'sha256':pin,'size':size}
 source=root/'local-art/genesis/source'
 for e in json.loads((source/'source-manifest.json').read_text())['assets']:
  donor(e['file'].removesuffix('-original.png'),'local-art/genesis/source/'+e['file'],e['sha256'])
 for e in json.loads((source/'crew-information-receipt.json').read_text())['assets']:
  donor(e['file'].removesuffix('-original.png'),'local-art/genesis/source/'+e['file'],e['sha256'])
 for e in json.loads((source/'info-v1/manifest.json').read_text())['assets']:
  if e['key'].endswith('-illustration'):donor(e['key'],e['file'],e['sha256'])
 for i,e in enumerate(json.loads((source/'intro-v1/manifest.json').read_text())['sources']):
  donor('flash-'+str(i+1),'local-art/genesis/source/intro-v1/'+e['image'],e['sha256'])
 for i,e in enumerate(json.loads((source/'wilson-animation-v1/manifest.json').read_text())['assets']):
  donor('wilson-'+str(i),e['image'],e['sha256'])
 diagram=json.loads((source/'crew-diagram-v1/manifest.json').read_text());donor('crew-diagram','local-art/genesis/source/crew-diagram-v1/crew-diagram-original.png',diagram['sha256'])
 status=json.loads((source/'systems-status-receipt.json').read_text());donor('systems-status',status['image'],status['image_sha256'])
 atlas=Image.new('RGBA',(320,1200));expected=Image.new('RGB',(320,1200));plates={}
 for id,(original,key) in enumerate(PLATES,1):
  raw=root/'GAME'/original;indices=screen_pixels(decode_resource(raw.read_bytes()))
  pc=Image.new('RGB',(320,200));pc.putdata([PALETTE[x] for x in indices]);expected.paste(pc,(0,(id-1)*200))
  with Image.open(root/donors[key]['path']) as im: native=im.convert('RGBA')
  for y in range(200):
   for x in range(320):
    if any(a<=x<c and b<=y<d for a,b,c,d in EXCLUDE[id]):continue
    # Never sample a captured sky/world or a dashboard state into a PC surround.
    if id==1 and 28<=x<292 and y<123:continue
    if id==2 and y<56:continue
    if id==3 and y<115:continue
    if id==4 and y<128:continue
    if id==5 and not (123<=x<305 and 37<=y<100):continue
    sy=int(113+(y-128)*87/72) if id==4 else y
    sx=x
    if id==5:sx=120+(x-123)*176//182;sy=17+(y-37)*63//63
    atlas.putpixel((x,(id-1)*200+y),native.getpixel((sx,min(sy,199))))
  plates[str(id)]={'source':original,'source_sha256':sha(raw)}
 for name,im in [('plates',atlas),('expected',expected)]:
  path=out/(name+'.png');im.save(path);donor(name,str(path.relative_to(root)),sha(path))
 catalogs={}
 for name,rel in [('intro','pc-intro-v2/intro.json'),('information','pc-information-v3/information.json'),('office','pc-frontend-v1/office.json'),('portraits','pc-portraits-v1/faces.json')]:
  path=root/'local-art'/rel;catalogs[name]={'path':str(path.relative_to(root)),'sha256':sha(path)}
 data={'native_information':[{'name':'heat','rgb_sha256':'ecbf07d088290867a0f78d6760ffa7b90f4d293014d4a42646c169f90186a890','donor':'ammo-heat-illustration','rect':[104,22,208,67],'proof':'Complete PC baseline frame artifacts/pc-information-baseline-02/heat.png; retains all original text outside illustration'}],'schema':1,'donors':donors,'plates':plates,'catalogs':catalogs,'scope':'Native extracted Genesis donors, nearest source-pixel sampling; PC pixels retained for unmatched and dynamic regions. No vehicle replacement.'}
 path=out/'graphics.json';path.write_text(json.dumps(data,indent=2)+'\n');print(path,sha(path))
 return data
if __name__=='__main__':build()
