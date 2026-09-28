#!/usr/bin/env python3
"""Finite original-source portrait denominator and captured visibility audit.

No guest execution, game mutation, inferred speech performance or artwork edits.
"""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
from PIL import Image
from tools.extract_pc_portraits import catalog, verify_loaded
from tools.inspect_scenarios import decode_resource
from tools.pc_bitmaps import decode_bitmaps

ROOT=Path(__file__).resolve().parents[1]
ROLES=('commander','gunner','driver','loader')
CREW_INDICES=(3,0,1,2)
ART=('commander-v1.png','gunner-v2.png','driver-v2.png','loader-v1.png')
ART_SHA=('5f16b256d211dbdbf4dd6a49bf81e8dedd9000444901e691c7081baa77efbbd6',
         '60428eddc7c59fbdde2bc0f13693f1c2e2c7e8f3fc0dc6f70774b4c3d8be8e96',
         'fff88ec76c9455500b6564b1c78be5495b3009e4cee728d582b3fd557db548d1',
         'a392fe5714d04c05098eddb17d468f0c41bbdb4d851d67d2ad61742a8819e919')
CREW_SHA='6351763f4ccbe4daca199a0ac9738039ddbd6a30720476dc5488fd84d95805bf'


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def source_audit(root=ROOT):
    saved=json.loads((root/'local-art/pc-portraits-v1/faces.json').read_text())
    faces=catalog((root/'GAME/FACES.BMP').read_bytes(),saved['palette_rgb'])
    if faces!=saved:raise ValueError('portrait catalog differs from original decode')
    if sha(root/'GAME/CREW.BMP')!=CREW_SHA:raise ValueError('unsupported CREW resource')
    crew=decode_bitmaps(decode_resource((root/'GAME/CREW.BMP').read_bytes()))
    if len(crew)!=5 or (crew[4]['width'],crew[4]['height'])!=(208,61):raise ValueError('crew diagram denominator changed')
    information=json.loads((root/'local-art/pc-information-v3/information.json').read_text())
    page=next(e for e in information['entries'] if e['name']=='crew')
    face_ram=(root/'artifacts/pc-live-type-crew-02/first-render.bin').read_bytes()
    crew_ram=(root/'artifacts/pc-information-baseline-02/crew.bin').read_bytes()
    rows=[]
    for face_id,(role,crew_id,art,pin) in enumerate(zip(ROLES,CREW_INDICES,ART,ART_SHA)):
        face=faces['images'][face_id];entry=crew[crew_id]
        layer=next(x for x in page['layers'] if x['name']=='crew-'+role)
        path=root/'local-art/genesis/remastered/crew-v1'/art
        if sha(path)!=pin or layer['art_sha256']!=pin or layer['art']!='crew-v1/'+art:
            raise ValueError('live donor mismatch: '+role)
        with Image.open(path) as image:
            if image.size!=(1254,1254):raise ValueError('authored donor size mismatch')
        rows.append({'role':role,'faces_index':face_id,'crew_index':crew_id,
                     'faces_size':[face['width'],face['height']], 'crew_size':[entry['width'],entry['height']],
                     'faces_opaque_pixels':sum(c!=0 for c in face['pixels']),
                     'crew_opaque_pixels':sum(c!=0 for c in entry['pixels']),
                     'resource_pixel_differences':sum(a!=b for a,b in zip(face['pixels'],entry['pixels'])),
                     'faces_loaded_proof':verify_loaded(face_ram,face),'crew_loaded_proof':verify_loaded(crew_ram,entry),
                     'art':str(path.relative_to(root)),'art_sha256':pin})
    return {'portrait_count':4,'faces_bitmap_count':4,'crew_portrait_count':4,
            'crew_nonportrait_bitmaps':[{'index':4,'size':[208,61],'kind':'tank-and-seat diagram'}],
            'roles':rows,'scope':'Complete FACES and four CREW portrait entries. Distinct resource pixels are independently verified; injury/talking/radio are not invented extra assets.'}


def driver_visibility(root=ROOT):
    faces=json.loads((root/'local-art/pc-portraits-v1/faces.json').read_text())
    expected=[]
    for entry in faces['images']:
        expected.append([(i%entry['width'],i//entry['width'],bytes(faces['palette_rgb'][c]))
                         for i,c in enumerate(entry['pixels']) if c])
    directory=root/'artifacts/pc-portrait-lifecycle-trace-01'
    rows=[]
    for frame in range(3570,3716):
        image=Image.open(directory/('text-%05d.png'%frame)).convert('RGB')
        ui=Image.open(directory/('text-%05d-mask.png'%frame)).convert('L')
        rgb=image.tobytes();mask=ui.tobytes()
        matches=[]
        for index,points in enumerate(expected):
            if all(mask[(y+59)*320+x+37]==255 and rgb[((y+59)*320+x+37)*3:((y+59)*320+x+37)*3+3]==colour
                   for x,y,colour in points):matches.append(index)
        result=matches[0] if len(matches)==1 else -1
        if result!=(2 if 3583<=frame<3690 else -1):raise ValueError('driver source visibility changed: '+str(frame))
        rows.append({'frame':frame,'portrait':result})
    return {'frames':len(rows),'first_complete':3583,'last_complete':3689,'first_erased':3690,'rows':rows,
            'scope':'Independent exact current RGB and ownership comparison on captured frames. No caption or queued-state dependency.'}


def main():
    output=ROOT/'artifacts/finish-20260928/portrait-coverage.json'
    result={'source':source_audit(),'driver':driver_visibility()}
    output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(result,indent=2)+'\n')
    print('PC_PORTRAIT_COVERAGE: 4 FACES + 4 crew portraits, 146 exact driver lifecycle frames')


if __name__=='__main__':main()
