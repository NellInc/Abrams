"""Run with Blender's Python to author source-fitted, editable mesh studies.

These are local presentation assets, not a replacement simulation or live
visibility implementation. Original controls, vertex coordinates and classes
come from pc_vehicle_catalog.py. Bevels/materials are authored restoration.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
import bmesh
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--source',type=Path,default=ROOT/'reference/pc-vehicles/source-v1')
p.add_argument('--output',type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
if any(a.output.resolve().is_relative_to((ROOT/n).resolve()) for n in ('GAME','GENESIS','reference')):raise ValueError('author studies outside original/reference directories')
a.output.mkdir(parents=True,exist_ok=False)
catalog=json.loads((a.source/'catalog.json').read_text())
if catalog['schema']!=1 or catalog['live']['classes_matched']!=31:raise ValueError('source-named model proof required')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=40
scene.render.resolution_x=1600;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world.color=(0.12,0.12,0.12)
scene.view_settings.view_transform='Standard'
scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=False
scene.render.image_settings.color_mode='RGBA'
scene.unit_settings.system='NONE'

SOURCE_COLORS=[(0,0,0),(1,1,1),(.402,.402,.402),(.091,.091,.091),(.091,.091,1),(.091,1,1),(.402,0,0),(.402,.091,0), (0,.402,0),(.091,1,.091),(1,1,.091)]
MESH_COLORS=[(.035,.04,.04),(.57,.59,.59),(.28,.3,.3),(.11,.13,.13),(.05,.1,.26),(.1,.3,.32),(.18,.012,.01),(.17,.08,.02),(0.035,.14,.035),(.1,.2,.08),(.4,.34,.08)]
materials={}
for restored,colors in [(False,SOURCE_COLORS),(True,MESH_COLORS)]:
    for i,color in enumerate(colors):
        mat=bpy.data.materials.new(('restored' if restored else 'source')+f'_material_{i}');mat.use_nodes=True
        shader=mat.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Base Color'].default_value=(*color,1)
        shader.inputs['Roughness'].default_value=.56 if restored else 1
        shader.inputs['Metallic'].default_value=.25 if restored else 0
        if not restored:
            shader.inputs['Emission Color'].default_value=(*color,1)
            shader.inputs['Emission Strength'].default_value=1
            shader.inputs['Base Color'].default_value=(0,0,0,1)
        materials[restored,i]=mat


def geometry(model,restored):
    collection=bpy.data.collections.new(f'{model["shape_index"]}_'+('restored' if restored else 'source'))
    scene.collection.children.link(collection)
    primitives={p['id']:p for p in model['primitives']};report=[]
    for group in model['groups']:
        verts=[];faces=[];colors=[];wires=[]
        for pid in group['primitive_pointers']:
            part=primitives[pid];points=[tuple(c/64 for c in v) for v in part['vertices']]
            if len(points)<3:
                if len(points)==2:wires.append((pid,points,part['prefix_bytes'][1]))
                continue
            if points[-1]==points[0]:points=points[:-1]
            if len(set(points))<3:continue
            faces.append(tuple(range(len(verts),len(verts)+len(points))));verts.extend(points)
            colors.append(part['prefix_bytes'][2])
        if verts:
            mesh=bpy.data.meshes.new(f'group_{group["offset"]}')
            mesh.from_pydata(verts,[],faces);mesh.update()
            for i in range(11):mesh.materials.append(materials[restored,i])
            for face,color in zip(mesh.polygons,colors):
                if not 0<=color<11:raise ValueError('unsupported study material')
                face.material_index=color
            bm=bmesh.new();bm.from_mesh(mesh)
            bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=0.00001)
            bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
            source_vertices=len(bm.verts);source_faces=len(bm.faces)
            if restored:
                bmesh.ops.bevel(bm,geom=list(bm.edges),offset=.65/64,segments=4,affect='EDGES',clamp_overlap=True)
                bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
            bm.to_mesh(mesh);bm.free();mesh.update()
            obj=bpy.data.objects.new(mesh.name,mesh);collection.objects.link(obj)
            obj['source_shape']=model['shape_index'];obj['source_group']=group['offset']
            obj['source_primitives']=group['primitive_pointers']
            report.append({'source_group':group['offset'],'source_vertices':source_vertices,'source_faces':source_faces,
                           'vertices':len(mesh.vertices),'faces':len(mesh.polygons)})
        for pid,points,color in wires:
            curve=bpy.data.curves.new(f'line_{pid}','CURVE');curve.dimensions='3D';curve.resolution_u=1
            curve.bevel_depth=(.6 if restored else .3)/64;curve.bevel_resolution=3 if restored else 0
            spline=curve.splines.new('POLY');spline.points.add(1)
            for point,value in zip(spline.points,points):point.co=(*value,1)
            curve.materials.append(materials[restored,color])
            obj=bpy.data.objects.new(curve.name,curve);collection.objects.link(obj);obj['source_primitive']=pid
    return collection,report


def t62_detail(collection):
    """Authored surface relief fitted to source side/deck planes, never collision."""
    def attach(obj,primitive):
        for owner in list(obj.users_collection):owner.objects.unlink(obj)
        collection.objects.link(obj)
        obj['source_shape']=115;obj['source_primitive']=primitive;obj['authored_detail']=True
    def cylinder(name,position,radius,depth,material,primitive,axis='X'):
        bpy.ops.mesh.primitive_cylinder_add(vertices=40,radius=radius/64,depth=depth/64,location=tuple(v/64 for v in position))
        obj=bpy.context.object;obj.name=name
        if axis=='X':obj.rotation_euler.y=math.pi/2
        obj.data.materials.append(material);attach(obj,primitive)
        for face in obj.data.polygons:face.use_smooth=len(face.vertices)==4
    track=bpy.data.materials.new('T62_track_rubber');track.use_nodes=True
    track.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.017,.021,.021,1)
    track.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.9
    rim=materials[True,3];hub=materials[True,2]
    contour=[(-68,-29.5),(84,-29.5),(123,-2),(120,5),(-98,5),(-95,-21)]
    for sign,primitive in [(-1,13323),(1,13333)]:
        mesh=bpy.data.meshes.new('track_band');mesh.from_pydata([(sign*58.14/64,y/64,z/64) for y,z in contour],[],[tuple(range(6))]);mesh.update()
        obj=bpy.data.objects.new('T62_track_band',mesh);collection.objects.link(obj);mesh.materials.append(track)
        obj['source_shape']=115;obj['source_primitive']=primitive;obj['authored_detail']=True
        for i,y in enumerate([-70,-28,16,50,84]):
            cylinder(f'T62_roadwheel_{sign}_{i}',(sign*58.24,y,-12.5),13.5,.28,track,primitive)
            cylinder(f'T62_rim_{sign}_{i}',(sign*58.41,y,-12.5),10.5,.15,rim,primitive)
            cylinder(f'T62_hub_{sign}_{i}',(sign*58.52,y,-12.5),3,.13,hub,primitive)
        for y,radius in [(-90,7),(110,9)]:
            cylinder('T62_endwheel',(sign*58.4,y,-4),radius,.2,rim,primitive)
        for first,last in zip(contour,contour[1:]+contour[:1]):
            delta=Vector((last[0]-first[0],last[1]-first[1]));count=max(1,int(delta.length()/5))
            for i in range(count):
                at=Vector(first).lerp(Vector(last),(i+.5)/count)
                bpy.ops.mesh.primitive_cube_add(size=1,location=(sign*58.3/64,at.x/64,at.y/64))
                obj=bpy.context.object;obj.name='T62_track_link'
                obj.scale=(.2/64,3.3/64,1.8/64);obj.rotation_euler.x=math.atan2(delta.y,delta.x)
                obj.data.materials.append(rim);attach(obj,primitive)
    # Small relief remains on existing roof surfaces. Its layout is authored.
    cylinder('T62_roof_hatch',(-12,-12,39.5),11,.5,hub,13413,axis='Z')
    for x in range(-28,29,7):
        bpy.ops.mesh.primitive_cube_add(size=1,location=(x/64,-77/64,17.2/64))
        obj=bpy.context.object;obj.name='T62_engine_grille';obj.scale=(2/64,25/64,.4/64)
        obj.data.materials.append(track);attach(obj,13367)
    return {'roadwheels_per_side':5,'authored_surface_relief':True,
            'reference':'https://odin.t2com.army.mil/WEG/Asset/T-62_Russian_Medium_Tank',
            'scope':'Visual wheel count reference only. Positions, relief, hatch and grille fitted by the artist to original model proportions; no drivetrain or damage semantics.'}


def select(collection):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in collection.objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=collection.objects[0]


# Authoring lights and camera are never exported as gameplay content.
bpy.ops.object.camera_add(location=(8,12,8));camera=bpy.context.object
camera.rotation_euler=(Vector((0,.3,.2))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=13;scene.camera=camera
for location,power,size in [((1,4,8),1800,7),((-6,-4,4),1300,5)]:
    bpy.ops.object.light_add(type='AREA',location=location);light=bpy.context.object
    light.data.energy=power;light.data.shape='DISK';light.data.size=size
    light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.58));floor=bpy.context.object
floor_mat=bpy.data.materials.new('studio_floor');floor_mat.use_nodes=True
floor_mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.035,.04,.045,1)
floor_mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85
floor.data.materials.append(floor_mat)

receipts=[]
for index in (115,125,129):
    entry=next(item for item in catalog['models'] if item['shape_index']==index)
    model=json.loads((a.source/entry['json']).read_text())
    if model['opaque_commands']:raise ValueError('opaque source commands need a separate authoring interpretation')
    source,source_report=geometry(model,False);restored,restored_report=geometry(model,True)
    details=t62_detail(restored) if index==115 else None
    floor.location.z=min(v[2] for p in model['primitives'] for v in p['vertices'])/64-.025
    stem=Path(entry['json']).stem
    # Export at the exact original source origin and scale before arranging the comparison.
    select(restored)
    glb=a.output/(stem+'-study.glb')
    bpy.ops.export_scene.gltf(filepath=str(glb),use_selection=True,export_extras=True,export_yup=True)
    right=camera.rotation_euler.to_quaternion() @ Vector((3,0,0))
    for obj in source.objects:obj.location-=right
    for obj in restored.objects:obj.location+=right
    scene.render.filepath=str(a.output/(stem+'-comparison.png'));bpy.ops.render.render(write_still=True)
    for collection in (source,restored):
        collection.hide_render=True;collection.hide_viewport=True
    receipts.append({'shape_index':index,'name':entry['class_roles'][0]['name'],'source_json_sha256':hashlib.sha256((a.source/entry['json']).read_bytes()).hexdigest(),
                     'groups':restored_report,'authored_details':details,'glb':glb.name,'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),
                     'preview':stem+'-comparison.png'})
# Editable masters retain original and restored versions and their source identifiers.
bpy.ops.wm.save_as_mainfile(filepath=str(a.output/'source-fitted-studies.blend'))
(a.output/'manifest.json').write_text(json.dumps({'schema':1,'blender':bpy.app.version_string,'models':receipts,
    'transformation':{'raw_units_per_blender_unit':64,'bevel_raw_units':.65,'bevel_segments':4,'line_radius_raw_units':.6},
    'scope':'Source-fitted geometry/material studies with explicitly authored T-62 surface relief, no inferred joints or live tandem integration. glTF contains the same supported PBR materials as the Blender master; original source variants are preserved separately.'},indent=2)+'\n')
print('PC_VEHICLE_STUDIES',json.dumps({'models':len(receipts),'output':str(a.output)}))
