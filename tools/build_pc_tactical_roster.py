#!/usr/bin/env python3
"""Build the optional complete Tactical roster, preserving the accepted pair.

Blender: --background --factory-startup --python THIS -- --shapes 129,131
Python: THIS --pack. Per-model editable masters permit bounded resumed baking.
After a fresh shape-147 bake: THIS --patch-cabin replaces only its existing tile.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil
import struct
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from tools.build_pc_tactical_vehicles import (ROSTER_SHAPES,REGISTRY_FIELDS,build_geometry,
    load_catalog,make_object,bake,guard,sha,bounds,SCALE)
PAIR=ROOT/'local-art/pc-tactical-vehicles-v1'
OUT=ROOT/'local-art/pc-tactical-roster-v1'
INTACT=(117,119,121,123,127,129,131,133,135,137,139,141,143,159,163)
# Exact baked geometry aliases are expanded at build time, never at runtime.
# Filled source geometry can match while the authored vehicle family differs.
# Fifteen wreck masters fit the existing sixteen-slot bank without new textures.
ALIASES={164:163,144:142}
WRECKS=tuple(i for i in ROSTER_SHAPES if i%2==0 and i<161)
DONORS=tuple(i for i in WRECKS if i not in ALIASES)
SCENE=tuple(range(145,159))+(161,162)
BRIDGES=(0,1,45,46,47,108,114)
SCENE_SHAPES=tuple(sorted(ROSTER_SHAPES+SCENE+BRIDGES))
BANKS={'pair':(2048,1024,1024),'intact':(4096,4096,1024),'wreck':(2048,2048,512),'scene':(4096,4096,1024),'bridge':(2048,1024,512)}
FINISH_REVISION=50
from tools.pc_tactical_crews import SCULPT_PATH
FINISH_SHA=hashlib.sha256("".join(sha(p) for p in (__file__,ROOT/"tools/build_pc_tactical_vehicles.py",ROOT/"tools/sculpt_pc_tactical_crews.py",ROOT/"tools/sculpt_pc_tactical_ground_crews.py",*sorted((ROOT/"tools").glob("pc_tactical_*.py")),*([SCULPT_PATH] if SCULPT_PATH.exists() else []))).encode()).hexdigest()

def authored(base,master=False):
    if base['shape_index'] in ROSTER_SHAPES:
        from tools.pc_tactical_vehicle_refinement import refine
        model=refine(build_geometry(base,master),master)
        if base['shape_index']==159:
            # Fit the complete truck, including refinement fittings, in width
            # only. Y/Z wheel profiles and ground contact remain circular/exact.
            # Working if length-to-width is credible without floating fittings.
            for triangle in model['triangles']:
                component=triangle['component']
                for vertex in triangle['vertices']:
                    vertex[0]=round(vertex[0]*.75,6)
                    # Shorter cargo body, complete cab moved aft, longer bonnet.
                    # Working if attached fittings follow their parent panels.
                    y=vertex[1]
                    if component.startswith(('truck_bed_','truck_canvas_')):
                        y=-78+(y+78)*102/119
                    elif component.startswith(('truck_cab_','truck_door_','truck_roof_','truck_sideglass_','truck_screen_')) or component in ('truck_split_windscreen','truck_wiper'):
                        y-=17
                    elif component in ('truck_sloping_bonnet','truck_bonnet_spine','truck_enclosed_engine_bay','truck_front_wing','truck_bonnet_side_louvre','truck_bonnet_latch'):
                        y=63+(y-80)*45/28
                    elif '_axle_2_' in component or component=='truck_front_fender' or component=='truck_axle' and y>45:
                        y+=15
                    vertex[1]=round(y,6)
            model['bounds']=bounds([v for t in model['triangles'] for v in t['vertices']])
    else:
        from tools.pc_tactical_scene import geometry
        model=geometry(base,master)
    if master:
        from tools.pc_tactical_scene import mechanical_details
        mechanical_details(model)
    if base['shape_index'] in (161,162):
        from tools.pc_tactical_crew_heads import geometry
        _,model['command_head']=geometry(base,master)
    return model


def fingerprint(model):
    value=[model['triangles'],model.get('command_head')]
    if 'presentation_pose' in model:value.append(model['presentation_pose'])
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()

def public(model):
    result={k:copy.deepcopy(v) for k,v in model.items() if k not in REGISTRY_FIELDS}
    result['source_lines']=[{k:v for k,v in line.items() if k not in ('vertices','prefix_bytes')} for line in model['source_lines']]
    result['status']='partial_opaque' if model.get('status')=='partial_opaque' else 'authored_mesh';result['tactical_vehicle_detail']=True
    if 'command_head' in result:
        for triangle in result['command_head']['triangles']:
            triangle['vertices']=[[round(v[0]/18,8),round(v[1]/18,8),round(v[2]/15,8)] for v in triangle['vertices']]
    return result

def atlas_triangles(model):
    return model['triangles']+model.get('command_head',{}).get('triangles',[])

def scene_tile(directory,model,kind,tile):
    """Share one existing crew tile, with 16+ pixel gutters between regions."""
    from PIL import Image
    def image(folder,channel):
        if channel=='orm':return Image.merge('RGB',[Image.open(folder/(k+'.png')).convert('L') for k in ('ao','roughness','metallic')])
        return Image.open(folder/(channel+'.png')).convert('RGB')
    pixels=image(directory,kind)
    if 'command_head' not in model:return pixels.resize((tile,tile),Image.Resampling.LANCZOS)
    result=Image.new('RGB',(tile,tile),(128,128,255) if kind=='normal' else (255,180,0) if kind=='orm' else (30,35,24))
    result.paste(pixels.resize((752,1008),Image.Resampling.LANCZOS),(8,8))
    result.paste(image(directory/'head',kind).resize((232,232),Image.Resampling.LANCZOS),(784,16))
    return result

def tile_uvs(model,col,row,tile,width,height):
    head='command_head' in model
    for triangle in model['triangles']:
        triangle['uvs']=[[(col+(8+u*752)/1024 if head else col+u)*tile/width,
                           (row+(8+v*1008)/1024 if head else row+v)*tile/height] for u,v in triangle['uvs']]
    for triangle in model.get('command_head',{}).get('triangles',[]):
        triangle['uvs']=[[(col+(784+u*232)/1024)*tile/width,(row+(16+v*232)/1024)*tile/height] for u,v in triangle['uvs']]

def alias_model(donor_base,target_base,donor):
    """Verify ordered owners, winding, pose membership and authored bake basis."""
    src=[p for p in donor_base['source_primitives'] if len(p['vertices'])>=3]
    dst=[p for p in target_base['source_primitives'] if len(p['vertices'])>=3]
    if len(src)!=len(dst):raise ValueError('Alias primitive count')
    pm={a['id']:b['id'] for a,b in zip(src,dst)}
    if len(donor_base['groups'])!=len(target_base['groups']):raise ValueError('Alias group count')
    gm={a['offset']:b['offset'] for a,b in zip(donor_base['groups'],target_base['groups'])}
    for a,b in zip(src,dst):
        if a['vertices']!=b['vertices'] or a['prefix_bytes']!=b['prefix_bytes']:raise ValueError('Alias vertex/winding/material mismatch')
        ag=[g['offset'] for g in donor_base['groups'] if a['id'] in g['primitive_pointers']]
        bg=[g['offset'] for g in target_base['groups'] if b['id'] in g['primitive_pointers']]
        if [gm[g] for g in ag]!=bg:raise ValueError('Alias pose membership')
    # Root group layout must agree; lines are deliberately target-original.
    if len(donor_base['roots'])!=len(target_base['roots']):raise ValueError('Alias roots')
    for a,b in zip(donor_base['roots'],target_base['roots']):
        if [gm[g] for g in a['group_pointers']]!=b['group_pointers']:raise ValueError('Alias root membership')
    model=authored(target_base)
    if len(model['triangles'])!=len(donor['triangles']):raise ValueError('Alias authored count')
    for a,b in zip(donor['triangles'],model['triangles']):
        if any(a[k]!=b[k] for k in ('vertices','material','component')) or pm[a['source_primitive']]!=b['source_primitive'] or [gm[g] for g in a['source_groups']]!=b['source_groups']:
            raise ValueError('Alias authored geometry/bake basis')
        b['uvs']=copy.deepcopy(a['uvs'])
    return public(model),{'donor':donor_base['shape_index'],'primitive_map':pm,'group_map':gm,'ordered_geometry_verified':True}

def expand_glb_alias(source,destination,source_index,target_index):
    """Keep exact baked binary geometry; remap only glTF object metadata."""
    raw=source.read_bytes();magic,version,total=struct.unpack_from('<4sII',raw)
    if magic!=b'glTF' or version!=2 or total!=len(raw):raise ValueError('Invalid donor glTF')
    length,kind=struct.unpack_from('<II',raw,12)
    if kind!=0x4e4f534a:raise ValueError('Missing donor glTF JSON')
    data=json.loads(raw[20:20+length])
    for node in data.get('nodes',[]):
        extras=node.get('extras',{})
        if extras.get('source_shape')==source_index:extras['source_shape']=target_index
        extras['exact_bake_alias_of']=source_index
    encoded=json.dumps(data,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4)
    binary=raw[20+length:]
    destination.write_bytes(struct.pack('<4sII',b'glTF',2,20+len(encoded)+len(binary))+struct.pack('<II',len(encoded),kind)+encoded+binary)


def pack(out):
    from PIL import Image
    base=load_catalog();old=json.loads((PAIR/'catalog.json').read_text())
    models=[];evidence={}
    for bank,indices in (('pair',(115,125)),('intact',INTACT),('wreck',DONORS),('scene',SCENE),('bridge',BRIDGES)):
        width,height,tile=BANKS[bank];columns=width//tile
        atlases={k:Image.new('RGB',(width,height),(128,128,255) if k=='normal' else (255,180,0) if k=='orm' else (0,0,0)) for k in ('albedo','normal','orm')}
        for slot,index in enumerate(indices):
            directory=out/str(index);receipt=json.loads((directory/'model.json').read_text());current=authored(base['models'][index])
            if receipt.get('finish_sha256')!=FINISH_SHA or receipt.get('finish_revision')!=FINISH_REVISION or receipt['geometry_sha256']!=fingerprint(current):raise ValueError(f'Stale authored bake {index}')
            m=receipt['model'];m['texture_bank']=bank
            col,row=slot%columns,slot//columns
            tile_uvs(m,col,row,tile,width,height)
            models.append(m)
            for kind in ('albedo','normal'):
                pixels=scene_tile(directory,m,kind,tile)
                atlases[kind].paste(pixels,(col*tile,row*tile))
            atlases['orm'].paste(scene_tile(directory,m,'orm',tile),(col*tile,row*tile))
        for kind,pixels in atlases.items():pixels.save(out/(bank+'-'+kind+'.png'))
    for target,source in ALIASES.items():
        donor=next(m for m in models if m['shape_index']==source)
        m,proof=alias_model(base['models'][source],base['models'][target],donor)
        m['texture_bank']=donor['texture_bank'];models.append(m);evidence[target]=proof
        target_dir=out/str(target);target_dir.mkdir(exist_ok=True)
        expand_glb_alias(out/str(source)/(donor['name'].lower()+'.glb'),target_dir/(m['name'].lower()+'.glb'),source,target)
    if sorted(m['shape_index'] for m in models)!=list(SCENE_SHAPES):raise ValueError('Incomplete roster')
    data={'schema':1,'authoring_revision':FINISH_REVISION,'sources':old['sources'],'source_registry':old['source_registry'],
        'models':sorted(models,key=lambda m:m['shape_index']),
        'texture_contract':'Five fixed PBR banks; fresh authored geometry and finish revision 9; top-left PNG origin; exact alias bake basis.',
        'visibility_contract':old['visibility_contract']}
    (out/'catalog.json').write_text(json.dumps(data,separators=(',',':'))+'\n')
    bank_data={bank:{'size':[w,h],'maps':{k:bank+'-'+k+'.png' for k in ('albedo','normal','orm')}} for bank,(w,h,t) in BANKS.items()}
    names=['catalog.json']+[path for b in bank_data.values() for path in b['maps'].values()]
    (out/'manifest.json').write_text(json.dumps({'schema':3,'shapes':list(SCENE_SHAPES),'banks':bank_data,'files':{name:sha(out/name) for name in names}},indent=2)+'\n')
    (out/'authoring.json').write_text(json.dumps({'builder_sha256':sha(__file__),'geometry_builder_sha256':sha(ROOT/'tools/build_pc_tactical_vehicles.py'),
        'family_modules':{p.name:sha(p) for p in (ROOT/'tools').glob('pc_tactical_*.py')},
        'accepted_pair_catalog_sha256':sha(PAIR/'catalog.json'),'aliases':evidence,
        'models':{m['shape_index']:len(m['triangles']) for m in models},'catalog_bytes':(out/'catalog.json').stat().st_size,
        'limits':'Source-bounded visual art only. Original engine/owner/pose remains authoritative. Placeholder aircraft, trees and terrain keep their existing original-authoritative paths.'},indent=2)+'\n')
    print('TACTICAL_ROSTER_PACK: 57 models, 5 banks, verified aliases',flush=True)

def patch_scene(out,indices):
    if any(i not in SCENE for i in indices):raise ValueError('Scene patch inventory')
    patch_models(out,indices)


def patch_models(out,indices):
    """Verify a complete accepted bundle, then patch fresh existing bank slots.

    Full --pack still rejects stale recipes. Scoped provenance identifies every
    replaced state and records unchanged peers without relabelling their bakes.
    """
    from PIL import Image
    slots={i:(bank,ids.index(i)) for bank,ids in (('pair',(115,125)),('scene',SCENE),('intact',INTACT),('wreck',DONORS),('bridge',BRIDGES)) for i in ids}
    if not indices or len(set(indices))!=len(indices) or any(i not in slots for i in indices):raise ValueError('Model patch inventory')
    manifest=json.loads((out/'manifest.json').read_text())
    if manifest.get('schema')!=3 or manifest.get('shapes')!=list(SCENE_SHAPES):raise ValueError('Complete scene pack required')
    for name,digest in manifest['files'].items():
        if sha(out/name)!=digest:raise ValueError('Existing pack hash mismatch: '+name)
    data=json.loads((out/'catalog.json').read_text())
    if sorted(m['shape_index'] for m in data['models'])!=list(SCENE_SHAPES):raise ValueError('Existing model inventory')
    base=load_catalog();replacements={};proofs=[]
    images={bank:{k:Image.open(out/(bank+'-'+k+'.png')).convert('RGB') for k in ('albedo','normal','orm')}
            for bank in {slots[i][0] for i in indices}}
    for index in indices:
        receipt=json.loads((out/str(index)/'model.json').read_text())
        if receipt.get('finish_sha256')!=FINISH_SHA or receipt.get('finish_revision')!=FINISH_REVISION or receipt.get('geometry_sha256')!=fingerprint(authored(base['models'][index])):raise ValueError(f'Stale scene bake {index}')
        bank,slot=slots[index];width,height,tile=BANKS[bank]
        model=copy.deepcopy(receipt['model']);model['texture_bank']=bank
        col,row=slot%(width//tile),slot//(width//tile)
        tile_uvs(model,col,row,tile,width,height)
        replacements[index]=model
        for kind,image in images[bank].items():
            pixels=scene_tile(out/str(index),model,kind,tile)
            image.paste(pixels,(col*tile,row*tile))
        proofs.append({'shape':index,'bank':bank,'geometry_sha256':receipt['geometry_sha256'],'atlas_uv_repairs':receipt.get('atlas_uv_repairs',[]),'tile':[col*tile,row*tile,tile,tile]})
    for target,donor in ALIASES.items():
        if donor not in replacements:continue
        model,proof=alias_model(base['models'][donor],base['models'][target],replacements[donor])
        model['texture_bank']=replacements[donor]['texture_bank'];replacements[target]=model
        directory=out/str(target);directory.mkdir(exist_ok=True)
        expand_glb_alias(out/str(donor)/(replacements[donor]['name'].lower()+'.glb'),directory/(model['name'].lower()+'.glb'),donor,target)
        proofs.append({'shape':target,'alias_of':donor,'alias_proof':proof,'bank':model['texture_bank']})
    data['models']=[replacements.get(m['shape_index'],m) for m in data['models']]
    data['authoring_revision']=FINISH_REVISION
    data['texture_contract']='Five fixed PBR banks; mixed recipes recorded in authoring.json scoped_patches; unchanged state entries and bank tiles retained exactly.'
    authoring_raw=(out/'authoring.json').read_bytes();authoring=json.loads(authoring_raw)
    # A newly distinct master supersedes its former alias claim. Historical
    # scoped patches remain intact; the top-level inventory describes this pack.
    for index in replacements:authoring.setdefault('aliases',{}).pop(str(index),None)
    for proof in proofs:
        if 'alias_of' in proof:authoring['aliases'][str(proof['shape'])]=proof['alias_proof']
    authoring.setdefault('scoped_patches',[]).append({'states':proofs,'revision':FINISH_REVISION,'finish_sha256':FINISH_SHA,'builder_sha256':sha(__file__),'family_modules':{p.name:sha(p) for p in (ROOT/'tools').glob('pc_tactical_*.py')},'base_authoring_sha256':hashlib.sha256(authoring_raw).hexdigest(),'retained_states':len(SCENE_SHAPES)-len(replacements)})
    for index,model in replacements.items():authoring['models'][str(index)]=len(model['triangles'])
    for bank,maps in images.items():
        for kind,image in maps.items():image.save(out/(bank+'-'+kind+'.png'))
    (out/'catalog.json').write_text(json.dumps(data,separators=(',',':'))+'\n')
    authoring['catalog_bytes']=(out/'catalog.json').stat().st_size
    (out/'authoring.json').write_text(json.dumps(authoring,indent=2)+'\n')
    manifest['files']={name:sha(out/name) for name in manifest['files']}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'TACTICAL_MODEL_PATCH: {len(replacements)} states, {len(SCENE_SHAPES)-len(replacements)} entries and other bank tiles preserved',flush=True)


def patch_cabin(out):
    patch_scene(out,(147,))


def guard_atlas_uvs(obj,model,index,head=False):
    """Repair sub-texel unwrap slivers before baking, never relax runtime UV gates.

    Near-collinear original insignia facets can have nonzero UV area in double
    precision yet collapse when translated into a float32 atlas slot. Retain
    their exact source geometry and move one UV corner inside baked padding.
    """
    def f32(value):return struct.unpack('<f',struct.pack('<f',value))[0]
    bank,indices=next((name,ids) for name,ids in (('pair',(115,125)),('intact',INTACT),('wreck',DONORS),('scene',SCENE),('bridge',BRIDGES)) if index in ids)
    slot=indices.index(index)
    width,height,tile=BANKS[bank];col,row=slot%(width//tile),slot//(width//tile)
    def area(points):
        if head:points=[((784+u*232)/1024,(16+v*232)/1024) for u,v in points]
        elif 'command_head' in model:points=[((8+u*752)/1024,(8+v*1008)/1024) for u,v in points]
        q=[(f32((u+col)*tile/width),f32((v+row)*tile/height)) for u,v in points]
        a=[f32(q[1][k]-q[0][k]) for k in (0,1)];b=[f32(q[2][k]-q[0][k]) for k in (0,1)]
        return abs(f32(f32(a[0]*b[1])-f32(a[1]*b[0])))
    uv=obj.data.uv_layers.active.data;repairs=[]
    target=4e-12 if head else 1e-12
    for j,poly in enumerate(obj.data.polygons):
        if model['triangles'][j]['source_primitive'] in model.get('source_passthrough',[]):continue
        old=[[round(float(uv[i].uv.x),8),round(1-float(uv[i].uv.y),8)] for i in poly.loop_indices]
        if area(old)>=target:continue
        # Clipped sculpt slivers can collapse their first UV edge while another
        # edge still spans the island. Use that edge without altering geometry.
        a,b,c=max(((0,1,2),(1,2,0),(2,0,1)),key=lambda abc:sum((old[abc[1]][k]-old[abc[0]][k])**2 for k in (0,1)))
        dx=old[b][0]-old[a][0];dy=old[b][1]-old[a][1];length=(dx*dx+dy*dy)**.5
        for amount in ((.000004,.000008,.000016,.000032,.000128,.000512,.002,.004) if head else (.000004,.000008,.000016,.000032)):
            new=copy.deepcopy(old)
            if length<1e-12:
                # A fully collapsed micro-island needs both axes restored.
                # Stay inside the same sub-texel padding; retain every vertex.
                new[b]=[round(old[a][0]+amount,8),old[a][1]]
                new[c]=[old[a][0],round(old[a][1]+amount,8)]
            else:new[c]=[round(old[c][0]-dy/length*amount,8),round(old[c][1]+dx/length*amount,8)]
            if not all(0<=v<=1 for pair in new for v in pair):continue
            for i,(u,v) in zip(poly.loop_indices,new):uv[i].uv=(u,1-v)
            stored=[[round(float(uv[i].uv.x),8),round(1-float(uv[i].uv.y),8)] for i in poly.loop_indices]
            if area(stored)>=target:
                new=stored;break
        else:raise ValueError(f'Atlas UV repair failed {index}/{j}')
        for i,(u,v) in zip(poly.loop_indices,new):uv[i].uv=(u,1-v)
        repairs.append({'triangle':j,'source_primitive':model['triangles'][j]['source_primitive'],'old_uvs':old,'new_uvs':new,'source_texel_displacement':amount*(512 if head else 2048 if index in (115,125)+INTACT+SCENE else 1024)})
    return repairs


def main():
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else sys.argv[1:]
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=OUT);p.add_argument('--shapes');p.add_argument('--pack',action='store_true');p.add_argument('--patch-cabin',action='store_true');p.add_argument('--patch-scene',action='store_true');p.add_argument('--patch-models',action='store_true');p.add_argument('--preview',action='store_true');p.add_argument('--resume',action='store_true');a=p.parse_args(args)
    out=guard(a.output);out.mkdir(parents=True,exist_ok=True)
    if a.patch_cabin:patch_cabin(out);return
    if a.patch_scene:patch_scene(out,tuple(int(x) for x in a.shapes.split(',')) if a.shapes else tuple(i for i in SCENE if i!=147));return
    if a.patch_models:patch_models(out,tuple(int(x) for x in a.shapes.split(',')) if a.shapes else ());return
    if a.pack:pack(out);return
    import bpy
    base=load_catalog();indices=[int(x) for x in a.shapes.split(',')] if a.shapes else list((115,125)+INTACT+DONORS+SCENE+BRIDGES)
    for index in indices:
        if index not in (115,125)+INTACT+DONORS+SCENE+BRIDGES:raise ValueError('Only approved unique bake donors')
        directory=out/str(index);directory.mkdir(exist_ok=True)
        model=authored(base['models'][index]);digest=fingerprint(model)
        if a.resume and (directory/'model.json').exists() and json.loads((directory/'model.json').read_text())['geometry_sha256']==digest and json.loads((directory/'model.json').read_text()).get('finish_revision')==FINISH_REVISION and json.loads((directory/'model.json').read_text()).get('finish_sha256')==FINISH_SHA:
            print(f'TACTICAL_ROSTER_RESUME {index}',flush=True);continue
        bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
        bpy.data.orphans_purge(do_recursive=True)
        for image in list(bpy.data.images):
            if image.users==0:bpy.data.images.remove(image)
        obj=make_object(bpy,model)
        print(f'TACTICAL_ROSTER_GEOMETRY {index}: {len(model["triangles"])} triangles',flush=True)
        if a.preview:
            if 'command_head' in model:
                from tools.pc_tactical_crew_heads import geometry as head_geometry
                preview_head,_=head_geometry(base['models'][index]);make_object(bpy,preview_head)
            from mathutils import Vector
            scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.render.resolution_x=800;scene.render.resolution_y=520;scene.render.resolution_percentage=100
            scene.world.color=(.25,.25,.25)
            lo,hi=model['bounds'].values();c=Vector([(x+y)/2/SCALE for x,y in zip(lo,hi)]);size=max(y-x for x,y in zip(lo,hi))/SCALE
            bpy.ops.object.camera_add(location=c+Vector((1.5,1.9,1.1))*size);cam=bpy.context.object;cam.rotation_euler=(c-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=size*1.35;scene.camera=cam
            bpy.ops.object.light_add(type='AREA',location=c+Vector((1,1,2))*size);bpy.context.object.data.energy=600;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=size*2
            scene.render.filepath=str(directory/'preview.png');bpy.ops.render.render(write_still=True);continue
        # Per-model master maps retain 2048px intact and 1024px wreck sources.
        uv_repairs=guard_atlas_uvs(obj,model,index)
        high=make_object(bpy,authored(base['models'][index],True));high.name=obj.name.replace('_GAME','_MASTER')
        bake(bpy,obj,high,directory,2048 if index in (115,125)+INTACT+SCENE else 1024)
        uv=obj.data.uv_layers.active.data
        for tri,poly in zip(model['triangles'],obj.data.polygons):tri['uvs']=[[round(float(uv[i].uv.x),8),round(1-float(uv[i].uv.y),8)] for i in poly.loop_indices]
        head_obj=None
        if 'command_head' in model:
            from tools.pc_tactical_crew_heads import geometry as head_geometry
            head_model,_=head_geometry(base['models'][index])
            head_obj=make_object(bpy,head_model)
            head_obj['source_command_offset']=model['command_head']['command_offset']
            head_obj['source_command_binding']='Independent observed original round command; not a body polygon'
            model['command_head']['atlas_uv_repairs']=guard_atlas_uvs(head_obj,head_model,index,True)
            head_master,_=head_geometry(base['models'][index],True)
            head_high=make_object(bpy,head_master);head_high.name=head_obj.name.replace('_GAME','_MASTER')
            head_dir=directory/'head';head_dir.mkdir(exist_ok=True)
            if 'presentation_pose' in model:
                from mathutils import Matrix,Vector
                pose=model['presentation_pose'];basis=Matrix(pose['head_basis']).transposed()
                transform=basis.to_4x4();transform.translation=Vector(pose['head_origin'])/SCALE
                head_obj.matrix_world=transform;head_high.matrix_world=transform
            bake(bpy,head_obj,head_high,head_dir,512)
            head_uv=head_obj.data.uv_layers.active.data
            for tri,poly in zip(model['command_head']['triangles'],head_obj.data.polygons):
                tri['uvs']=[[round(float(head_uv[i].uv.x),8),round(1-float(head_uv[i].uv.y),8)] for i in poly.loop_indices]
        for o in bpy.context.selected_objects:o.select_set(False)
        obj.select_set(True);bpy.context.view_layer.objects.active=obj
        if head_obj is not None:head_obj.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(directory/(model['name'].lower()+'.glb')),export_format='GLB',use_selection=True,export_extras=True,export_tangents=True)
        bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(directory/'vehicle.blend'),check_existing=False)
        (directory/'model.json').write_text(json.dumps({'model':public(model),'geometry_sha256':digest,'finish_revision':FINISH_REVISION,'finish_sha256':FINISH_SHA,'atlas_uv_repairs':uv_repairs},separators=(',',':'))+'\n')
        print(f'TACTICAL_ROSTER_BAKED {index}',flush=True)
    print('TACTICAL_ROSTER_AUTHORING: complete',flush=True)
if __name__=='__main__':main()
