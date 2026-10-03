#!/usr/bin/env python3
"""Source-named PC model references for local remaster authoring, never gameplay.

Original class names/shape fields are recovered from SIM's class table. OBJ
exports retain source vertex order and line primitives; opaque commands remain
explicit in the manifest rather than becoming invented geometry.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
try:
    from tools.unpack_pc_executables import unpack
    from tools.inspect_scenarios import decode_resource
    from tools.inspect_shapes import inspect_shapes, primitive_vertices
    from tools.pc_live_state import SimStateReader, SIM_SHA256
    from tools.source_guard import inside_source
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from unpack_pc_executables import unpack
    from inspect_scenarios import decode_resource
    from inspect_shapes import inspect_shapes, primitive_vertices
    from pc_live_state import SimStateReader, SIM_SHA256
    from source_guard import inside_source

ROOT = Path(__file__).resolve().parents[1]
DATA = 0x19E00
TABLE, STRIDE, COUNT = 0x510, 30, 31
VARIANTS = ('primary', 'alternate', 'replacement')
SOURCE_HASHES = {'SIM.EXE':SIM_SHA256,
    'SHAPE.GI':'107fc411632ad9754ccc6d82678d7f9de501dad397c3e47a16cdece3dae73faf',
    'SHAPE.TBL':'81cf10917d8647e8ac187e49887494992828277333f17d6c1926e59581f0a193'}


def source_catalog(source=ROOT/'GAME'):
    for name,expected in SOURCE_HASHES.items():
        if hashlib.sha256((source/name).read_bytes()).hexdigest()!=expected:
            raise ValueError('unsupported '+name+' fingerprint')
    exe=(source/'SIM.EXE').read_bytes()
    image,_=unpack(exe)
    gi=decode_resource((source/'SHAPE.GI').read_bytes())
    base=struct.unpack_from('<H',gi)[0]
    shapes=inspect_shapes(decode_resource((source/'SHAPE.TBL').read_bytes()))['shapes']
    rows=[]
    for index in range(COUNT):
        offset=TABLE+index*STRIDE
        raw=image[DATA+offset:DATA+offset+STRIDE]
        pointer=struct.unpack_from('<H',raw)[0]
        end=image.find(b'\0',DATA+pointer,DATA+pointer+32)
        if end<0: raise ValueError('unterminated source model name')
        name=image[DATA+pointer:end].decode('ascii')
        if not name or not all(32<=ord(c)<127 for c in name): raise ValueError('unsupported source model name')
        variants={kind:None if relative==255 else base+relative for kind,relative in zip(VARIANTS,raw[6:9])}
        if any(shape is not None and not 0<=shape<len(shapes) for shape in variants.values()):
            raise ValueError('class shape outside original table')
        rows.append({'class_index':index,'name':name,'table_offset':offset,'name_pointer':pointer,
                     'raw_hex':raw.hex(),'shapes':variants})
    return {'schema':1,'shape_base':base,'classes':rows,
            'sources':{name:hashlib.sha256((source/name).read_bytes()).hexdigest() for name in ('SIM.EXE','SHAPE.GI','SHAPE.TBL')},
            'scope':'Original class/shape reference, not a visibility list. Field names describe table roles; no inferred physical dimensions.'},shapes


def verify_live(ram, catalog, source=ROOT/'GAME'):
    state=SimStateReader(source/'SIM.EXE').read(ram)
    if not state: raise ValueError('missing fingerprinted original SIM')
    ds=(state['load_segment']+0x19E0)*16
    def word(offset):
        if not 0<=offset<=65534: raise ValueError('invalid DS pointer')
        return struct.unpack_from('<H',ram,ds+offset)[0]
    if word(0x79C2)!=catalog['shape_base']: raise ValueError('live shape base differs')
    pointers=word(0x8654)
    if pointers+2*COUNT>65536: raise ValueError('invalid class pointer array')
    for row in catalog['classes']:
        at=word(pointers+2*row['class_index'])
        if at!=row['table_offset'] or word(at)!=row['name_pointer']: raise ValueError('live class pointer differs')
        expected=[255 if row['shapes'][v] is None else row['shapes'][v] for v in VARIANTS]
        if list(ram[ds+at+6:ds+at+9])!=expected: raise ValueError('live relocated shape fields differ')
        name=ram[ds+word(at):ram.find(b'\0',ds+word(at))].decode('ascii')
        if name!=row['name']: raise ValueError('live model name differs')
    controls,count=word(0x6F54),word(0xA08)
    scenario,scenario_count=word(0x8DC4),word(0x798A)
    if controls+count*17>65536 or scenario+scenario_count*42>65536: raise ValueError('invalid original instance array')
    objects={o['pointer']:o for o in state['world']['dynamic']}
    links=[]
    for slot in range(count):
        at=controls+slot*17
        if not ram[ds+at]: continue
        record,pointer=word(at+1),word(at+3)
        if not scenario<=record<scenario+scenario_count*42 or (record-scenario)%42:
            raise ValueError('actor does not point to an original scenario record')
        kind=word(record)
        if not 0<=kind<COUNT or pointer not in objects: raise ValueError('unsupported actor class/object linkage')
        row=catalog['classes'][kind]; obj=objects[pointer]
        if obj['shape_index'] not in row['shapes'].values(): raise ValueError('actor shape differs from class table')
        links.append({'control_slot':slot,'control_pointer':at,'scenario_record':(record-scenario)//42,
                      'class_index':kind,'name':row['name'],'object_pointer':pointer,'shape_index':obj['shape_index']})
    player=objects.get(word(0x799B))
    if not player or player['shape_index']!=catalog['classes'][5]['shapes']['primary'] or ram[ds+0x7998]!=player['shape_index']:
        raise ValueError('original player class selection differs')
    return {'capture_sha256':hashlib.sha256(ram).hexdigest(),'classes_matched':COUNT,'actor_links':links,
            'player':{'class_index':5,'name':catalog['classes'][5]['name'],'shape_index':player['shape_index']},
            'scope':'Read-only current original allocation linkage, never proof of visibility or allegiance.'}


def mesh_reference(shape):
    return {'shape_index':shape['index'],'selectors':shape['selectors'],'roots':shape['roots'],'groups':shape['groups'],
            'primitives':[{'id':p['offset'],'prefix_bytes':p['prefix_bytes'],'vertices':primitive_vertices(shape,p)} for p in shape['primitives']],
            'opaque_commands':shape['opaque_commands'],
            'scope':'Source-local axes and raw units. Original group order/selection retained as metadata; no conventional culling or animation inferred.'}


def obj_reference(model):
    lines=['# Local source reference. Original units/axes; material and culling semantics remain external.',f'o shape_{model["shape_index"]}']
    offset=1
    for primitive in model['primitives']:
        vertices=primitive['vertices']
        lines.append(f'g primitive_{primitive["id"]}')
        lines.append('# source_prefix '+ ' '.join(map(str,primitive['prefix_bytes'])))
        lines += ['v '+' '.join(map(str,v)) for v in vertices]
        if vertices:
            command='f' if len(vertices)>=3 else 'l' if len(vertices)==2 else 'p'
            lines.append(command+' '+' '.join(str(offset+i) for i in range(len(vertices))))
        offset+=len(vertices)
    for command in model['opaque_commands']: lines.append('# unsupported_command '+json.dumps(command,sort_keys=True))
    return '\n'.join(lines)+'\n'


def export(output, catalog, shapes):
    output.mkdir(parents=True,exist_ok=False)
    models=[]
    for index in sorted({s for r in catalog['classes'] for s in r['shapes'].values() if s is not None}):
        owners=[{'class_index':r['class_index'],'name':r['name'],'variant':v} for r in catalog['classes'] for v,s in r['shapes'].items() if s==index]
        slug=re.sub('[^a-z0-9]+','-',owners[0]['name'].lower()).strip('-')
        stem=f'{index:03d}-{slug}'
        model=mesh_reference(shapes[index]);model['class_roles']=owners
        (output/(stem+'.json')).write_text(json.dumps(model,indent=2)+'\n')
        (output/(stem+'.obj')).write_text(obj_reference(model))
        models.append({'shape_index':index,'json':stem+'.json','obj':stem+'.obj','class_roles':owners,
                       'primitives':len(model['primitives']),'opaque_commands':len(model['opaque_commands']),
                       'obj_sha256':hashlib.sha256((output/(stem+'.obj')).read_bytes()).hexdigest()})
    result=catalog|{'models':models}
    (output/'catalog.json').write_text(json.dumps(result,indent=2)+'\n')
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--capture',type=Path,required=True);a=p.parse_args()
    if inside_source(a.output,ROOT,('GAME','GENESIS')):p.error('output must be outside original source directories')
    catalog,shapes=source_catalog();catalog['live']=verify_live(a.capture.read_bytes(),catalog)
    result=export(a.output,catalog,shapes)
    print(json.dumps({'classes':len(result['classes']),'models':len(result['models']),'live':result['live']},indent=2))
