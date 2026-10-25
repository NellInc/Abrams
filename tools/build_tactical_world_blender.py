#!/usr/bin/env python3
"""Author two bounded Tactical foliage meshes in Blender, then export via Godot.

Blender --background --factory-startup --python tools/build_tactical_world_blender.py
The generated export_meshes.gd is run by the project's Godot binary afterwards.
No original game inputs, placement, ownership logic, materials or shaders change.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.source_guard import inside_source
REVISION = 1


def build(output):
    import bpy
    from mathutils import Vector
    output = Path(output).resolve()
    if inside_source(output):
        raise ValueError('Cannot write original game inputs')
    output.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    author_sha = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    meshes = {}
    palette = [(0.28, .39, .17, 1), (.31, .25, .16, 1), (.08, .11, .05, 1)]
    materials = []
    for name, colour in zip(('Leaf', 'Rooted bark', 'Exact incumbent contact footprint'), palette):
        mat = bpy.data.materials.new(name)
        mat.diffuse_color = colour
        mat.use_nodes = True
        mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = colour
        mat.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value = .86
        materials.append(mat)

    def author(name):
        points, faces, tags, normal_groups = [], [], [], []

        def face(vertices, kind=0., tone=1., normal_group=None):
            start = len(points)
            points.extend(vertices)
            faces.append(tuple(range(start, start+len(vertices))))
            tags.append((kind, tone))
            normal_groups.append(normal_group)

        def footprint(r):
            # Same corners, winding and y=0.08 as the incumbent Godot mesh.
            face([(-r,-r,.08), (r,-r,.08), (r,r,.08)], 1.)
            face([(-r,-r,.08), (r,r,.08), (-r,r,.08)], 1.)

        def branch(a, b, radius):
            a, b = Vector(a), Vector(b)
            axis = (b-a).normalized()
            right = axis.cross(Vector((0,0,1))).normalized()
            if right.length < .1: right = Vector((1,0,0))
            up = axis.cross(right)
            rings = [[tuple(c+(right*math.cos(i*math.tau/5)+up*math.sin(i*math.tau/5))*r)
                      for i in range(5)] for c,r in ((a,radius),(b,radius*.35))]
            if abs(a.z)<1e-9:
                rings[0]=[(p[0],p[1],0.) for p in rings[0]]
            for i in range(5):
                j=(i+1)%5
                face([rings[0][i],rings[0][j],rings[1][j],rings[1][i]], .5, .95)

        def spray_leaf(base,angle,length,width,rise,tone,roll):
            # A joined midrib and cupped blade, front/back windings kept separate
            # for correct light and visibility from either side of each spray.
            base=Vector(base);direction=Vector((math.cos(angle),math.sin(angle),0))
            side=Vector((-math.sin(angle)*math.cos(roll),math.cos(angle)*math.cos(roll),math.sin(roll)))
            middle=base+direction*(length*.46)+Vector((0,0,rise*.54))
            left=middle-side*width;right=middle+side*width
            tip=base+direction*length+Vector((0,0,rise))
            left.z-=width*.22;right.z-=width*.22
            group=len(faces)*2
            for triangle in ((base,left,tip),(base,tip,right)):
                vertices=[tuple(p) for p in triangle]
                face(vertices,0.,tone,group)
                face(vertices[::-1],0.,tone,group+1)

        def leaf(base, angle, length, width, rise, tone, double=True):
            # A tapering, folded ribbon, curving out of the crown or grass root.
            direction=Vector((math.cos(angle),math.sin(angle),0))
            side=Vector((-math.sin(angle),math.cos(angle),0))
            rows=[]
            for i in range(4):
                t=i/3
                c=Vector(base)+direction*(length*t*t)+Vector((0,0,rise*(t-.2*t*t)))
                w=width*math.sin(math.pi*(.10+.90*t)) if i<3 else .012
                rows.append([tuple(c-side*w),tuple(c+Vector((0,0,w*.3))),tuple(c+side*w)])
            for a,b in zip(rows,rows[1:]):
                for j in range(2):
                    vertices=[a[j],a[j+1],b[j+1],b[j]]
                    face(vertices,0.,tone)
                    if double: face(vertices[::-1],0.,tone)

        if name=='shrub':
            footprint(25.)
            sprays=[]
            for i,(x,y,z) in enumerate(((-9,0,4.98),(7,3,5.74),(0,-4,7.26),(-2,8,4.6),(5,-9,3.84))):
                base=(x*.3,y*.3,0)
                fork=(x*.7,y*.7,z*.45)
                branch(base,fork,.62)
                branch(fork,(x,y,z),.38)
                # Two divergent twigs carry six alternating leaf pairs each.
                # Their shared nodes eliminate floating foliage and closed lumps.
                for j in range(2):
                    a=i*1.7+j*1.9
                    start=Vector(fork).lerp(Vector((x,y,z)),.20+j*.60)
                    end=start+Vector((math.cos(a)*3.9,math.sin(a)*3.6,1.35+j*.25))
                    branch(start,end,.20)
                    for k,t in enumerate((.10,.25,.40,.55,.70,.85)):
                        node=start.lerp(end,t)
                        for side in (-1,1):
                            angle=a+side*(.86+.06*k)+.08*math.sin(i*2+j+k)
                            length=4.5+((i+k+j)%3)*.25
                            width=1.02+((i+j+k)%2)*.13
                            rise=1.1+.22*k+.24*((i+j)%3)
                            roll=side*(.48+.19*((i+j+k)%4))
                            sprays.append((node,angle,length,width,rise,.86+((i*3+j+k)%5)*.035,roll))
            # Emit foliage after the branch scaffold so stems cannot overpaint
            # earlier crowns in the existing depth-disabled presentation pass.
            for parameters in sprays:spray_leaf(*parameters)
        else:
            footprint(5.)
            for i in range(5):
                a=i*2.4
                leaf((math.cos(a)*1.2,math.sin(a)*1.2,0),a,3.25,.58,6.25+float((i*3)%7)*.66,.86+(i%3)*.06)
        mesh=bpy.data.meshes.new('Tactical '+name+' authored mesh')
        mesh.from_pydata(points,[],faces)
        mesh.update()
        obj=bpy.data.objects.new('Tactical '+name,mesh)
        bpy.context.collection.objects.link(obj)
        for mat in materials: mesh.materials.append(mat)
        uv=mesh.uv_layers.new(name='UVMap')
        uv2=mesh.uv_layers.new(name='Material kind and tone')
        for poly,(kind,tone) in zip(mesh.polygons,tags):
            poly.material_index=0 if kind<.25 else 1 if kind<.75 else 2
            # Blender Z-up converts to Godot Y-up. Godot front winding is clockwise.
            n=Vector((poly.normal.x,poly.normal.z,poly.normal.y))
            axis=max(range(3),key=lambda k:abs(n[k]))
            for loop in poly.loop_indices:
                p=mesh.vertices[mesh.loops[loop].vertex_index].co
                uv.data[loop].uv=(p.x/25,p.y/25)
                uv2.data[loop].uv=(kind+axis/16,tone)
        # Smooth the actual joined blade surface, without blending opposite
        # windings or changing the untouched grass's incumbent plane normals.
        averaged={}
        for poly,group in zip(mesh.polygons,normal_groups):
            if group is None:continue
            for loop in poly.loop_indices:
                key=(group,tuple(mesh.vertices[mesh.loops[loop].vertex_index].co))
                averaged[key]=averaged.get(key,Vector((0,0,0)))+poly.normal*poly.area
        corner_normals=[]
        for poly,group in zip(mesh.polygons,normal_groups):
            for loop in poly.loop_indices:
                n=poly.normal.copy()
                if group is not None:
                    key=(group,tuple(mesh.vertices[mesh.loops[loop].vertex_index].co))
                    n=averaged[key].normalized()
                corner_normals.append(n)
        mesh.normals_split_custom_set(corner_normals)
        mesh.update()
        mesh.calc_loop_triangles()
        stream=[]
        for tri in mesh.loop_triangles:
            for loop in tri.loops:
                p=mesh.vertices[mesh.loops[loop].vertex_index].co
                n=corner_normals[loop]
                stream.append([*[round(v,6) for v in (p.x,p.z,p.y,n.x,n.z,n.y)],
                               *[round(v,6) for v in uv.data[loop].uv],
                               *[round(v,6) for v in uv2.data[loop].uv]])
        meshes[name]={'revision':REVISION,'author_sha256':author_sha,'vertices':stream}
        (output/(name+'.json')).write_text(json.dumps(meshes[name],separators=(',',':'))+'\n')
        obj['runtime_contract']='Source-unit geometry only; original planting and ownership gates unchanged'
        obj['author_sha256']=author_sha
        return obj
    shrub=author('shrub')
    grass=author('grass')
    grass.location.x=36
    bpy.context.scene.world.color=(.19,.19,.19)
    bpy.ops.wm.save_as_mainfile(filepath=str(output/'tactical-world.blend'))
    manifest={'schema':1,'author_sha256':author_sha,'blender_version':bpy.app.version_string,
              'coordinate_system':'raw source units, Blender Z up to Godot Y up',
              'runtime':['godot/assets/tactical_world_v1/shrub.tres','godot/assets/tactical_world_v1/grass.tres'],
              'meshes':{name:{'triangles':len(data['vertices'])//3,'bounds_min':[min(v[k] for v in data['vertices']) for k in range(3)],'bounds_max':[max(v[k] for v in data['vertices']) for k in range(3)]} for name,data in meshes.items()}}
    (output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (output/'export_meshes.gd').write_text(EXPORT_GD)
    print('TACTICAL_WORLD_AUTHORED '+json.dumps(manifest))


EXPORT_GD = '''extends SceneTree
func _initialize() -> void:
    var args:=OS.get_cmdline_user_args()
    var source:String=args[0]
    var destination:String=args[1]
    DirAccess.make_dir_recursive_absolute(destination)
    for name:String in ["shrub","grass"]:
        var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source.path_join(name+".json")))
        var st:=SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        for v:Array in data.vertices:
            st.set_normal(Vector3(v[3],v[4],v[5]))
            st.set_uv(Vector2(v[6],v[7]))
            st.set_uv2(Vector2(v[8],v[9]))
            st.add_vertex(Vector3(v[0],v[1],v[2]))
        var mesh:=st.commit()
        mesh.set_meta("tactical_world_revision",int(data.revision))
        mesh.set_meta("author_sha256",data.author_sha256)
        var result:=ResourceSaver.save(mesh,destination.path_join(name+".tres"))
        if result!=OK:quit(1);return
        print("TACTICAL_WORLD_EXPORTED "+name+" "+str(data.vertices.size())+" vertices")
    quit(0)
'''

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',default=str(ROOT/'local-art/pc-tactical-world-v1'))
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    build(args.output)
