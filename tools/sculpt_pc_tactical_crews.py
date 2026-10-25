#!/usr/bin/env python3
"""Blender sculpt/retopology for the two Tactical operators (local-only source).

Run in Blender with --background --factory-startup --python THIS_FILE.
Joined anatomical volumes are voxel-remeshed, relaxed, retopologized, then
partitioned across unchanged original polygon owners. Empty source faces keep
their original runtime occlusion. This changes no runtime or guest contract.
"""
import gzip,hashlib,json,math,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
import bpy
from mathutils import Vector
from tools.build_pc_modern_assets import add_face,area2,bounds,triangulate,validate_model,clip_plane
from tools.build_pc_tactical_vehicles import load_catalog,make_object,guard,SCALE
from tools.pc_tactical_crews import _blocking_geometry, _span, formed_hands
OUT=guard(ROOT/'local-art/pc-tactical-crew-sculpt-v1');OUT.mkdir(exist_ok=True)


def mesh_object(name,verts,faces):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata([[c/SCALE for c in v] for v in verts],[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);return obj


def loft(name,stations,n=32):
    verts=[[x+rx*math.cos(j*math.tau/n),y+ry*math.sin(j*math.tau/n),z]
           for x,y,z,rx,ry in stations for j in range(n)]
    faces=[]
    for i in range(len(stations)-1):
        for j in range(n):faces.append([i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j])
    faces+=[list(reversed(range(n))),list(range((len(stations)-1)*n,len(stations)*n))]
    return mesh_object(name,verts,faces)


def oval(name,c,r):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,location=Vector(c)/SCALE)
    ob=bpy.context.object;ob.name=name;ob.scale=Vector(r)/SCALE
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return ob


def limb(name,a,b,r0,r1,depth=1.):
    axis=(Vector(b)-Vector(a)).normalized();p=Vector((0,1,0));p=(p-axis*p.dot(axis)).normalized();q=axis.cross(p)
    verts=[];n=24;levels=12
    for i in range(levels+1):
        t=i/levels;c=Vector(a).lerp(Vector(b),t);r=r0+(r1-r0)*t
        r*=.82+.18*math.sin(math.pi*t)
        for j in range(n):verts.append(list(c+r*(p*math.sin(j*math.tau/n)*depth+q*math.cos(j*math.tau/n))))
    faces=[]
    for i in range(levels):
        for j in range(n):faces.append([i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j])
    faces+=[list(reversed(range(n))),list(range(levels*n,(levels+1)*n))]
    return mesh_object(name,verts,faces)


def rounded_box(name,c,size,r):
    bpy.ops.mesh.primitive_cube_add(size=1,location=Vector(c)/SCALE);ob=bpy.context.object;ob.name=name;ob.scale=Vector(size)/SCALE
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bevel=ob.modifiers.new('Rounded toe, heel and sole','BEVEL');bevel.width=r/SCALE;bevel.segments=4
    bpy.ops.object.modifier_apply(modifier=bevel.name);return ob


def boot_last(x):
    """A shaped shoe last: rounded toe, rising instep, hollow arch and heel.

    Forward is negativeY for these original operator sheets. Width remains
    inside each original leg owner; useful foot length comes from legal depth.
    """
    rings=[]
    section=[(1,0),(.97,.35),(.78,.75),(.40,.96),(0,1),(-.40,.96),(-.78,.75),
             (-.97,.35),(-1,0),(-.95,-.65),(-.72,-1),(0,-1),(.72,-1),(.95,-.65)]
    for y,w,bottom,top in [(-.6,2.0,-89.5,-88.6),(.6,2.9,-90,-88.0),
                         (2.8,3.8,-90,-87.4),(5.2,3.65,-90,-86.65),
                         (7.5,3.3,-88.5,-85.1),(9.8,3.0,-88.35,-83.7),
                         (10.9,3.05,-88.35,-83.9),(11.8,3.1,-90,-84.8),(14.1,3.0,-90,-86.1),
                         (15.3,1.7,-90,-87.2)]:
        mid=(bottom+top)/2;h=(top-bottom)/2
        inner=1 if x<0 else -1
        toe_roll=math.exp(-((y-1.0)/3.0)**2)
        rings.append([[x+w*u,y+.45*(1-inner*u)*.5*toe_roll,mid+h*v] for u,v in section])
    verts=[v for ring in rings for v in ring];faces=[];n=len(section)
    for i in range(len(rings)-1):
        for j in range(n):faces.append([i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j])
    faces.extend([list(reversed(range(n))),list(range((len(rings)-1)*n,len(rings)*n))])
    return mesh_object('Boot shaped toe, instep, arch and heel',verts,faces)


def clip(poly,a,b,inside):
    def d(p):return ((b[0]-a[0])*(p[2]-a[2])-(b[2]-a[2])*(p[0]-a[0]))*(1 if inside else -1)
    out=[]
    for p,q in zip(poly,poly[1:]+poly[:1]):
        dp,dq=d(p),d(q)
        if dp>=-1e-9:out.append(p)
        if (dp>=0)!=(dq>=0):
            t=dp/(dp-dq);out.append([p[k]+t*(q[k]-p[k]) for k in range(3)])
    return out


def attributed(ob,base):
    """Split actual Blender triangles at original owner edges, never grow masks."""
    owners=[]
    # Central body first; the rest cover only their original protruding area.
    for part in (0,1,2,3,5,6):
        src=base['source_primitives'][part]
        for tri in triangulate(src['vertices']):
            if sum(a[0]*b[2]-b[0]*a[2] for a,b in zip(tri,tri[1:]+tri[:1]))<0:tri=tri[::-1]
            owners.append((part,src['id'],tri))
    out=[];ob.data.calc_loop_triangles()
    # Shrinkwrap the sculpt to the union before ownership partitioning. Pure
    # clipping cut holes through shoulders and thighs in the rejected preview.
    polygons=[base['source_primitives'][i]['vertices'] for i in (0,1,2,3,5,6)]
    def in_poly(v,poly):
        if not min(p[2] for p in poly)<=v[2]<=max(p[2] for p in poly):return False
        lo,hi=_span(poly,v[2]);return lo-1e-8<=v[0]<=hi+1e-8
    def project(v):
        # Keep horizontal source seams at their exact Z. Nearest-edge XZ
        # projection can move a seam off a concave silhouette corner, leaving
        # an open notch when owner clipping removes the crossing triangle.
        v=list(v);v[1]=min(19.98,max(-.98,v[1]));v[2]=min(-14,max(-90,v[2]))
        if not any(in_poly(v,poly) for poly in polygons):
            intervals=[_span(poly,v[2]) for poly in polygons
                       if min(p[2] for p in poly)<=v[2]<=max(p[2] for p in poly)]
            candidates=[min(hi,max(lo,v[0])) for lo,hi in intervals]
            v[0]=min(candidates,key=lambda x:abs(x-v[0]))
        return v
    projected=[project(ob.matrix_world@vertex.co*SCALE) for vertex in ob.data.vertices]
    for tri in ob.data.loop_triangles:
        points=[projected[i] for i in tri.vertices]
        points=[[v[0],min(19.98,max(-.98,v[1])),max(-90,v[2])] for v in points]
        pieces=[points]
        cuts=[(2,z) for z in (-88.8,-81.3,-65.,-61.,-60.,-48.5,-45.5,-38.,-31.)]
        for axis,value in cuts:
            pieces=[part for poly in pieces for part in (clip_plane(poly,axis,value,True),clip_plane(poly,axis,value,False)) if len(part)>=3]
        for polygon in pieces:
          # Newly inserted source-seam vertices must follow the legal corner.
          for points in triangulate([project(v) for v in polygon]):
            c=[sum(v[k] for v in points)/3 for k in range(3)];x,y,z=c
            material='crew_cloth';label='crew_jacket_sculpt'
            if z<-47.5:label='crew_trousers_sculpt'
            if -48.5<z<-45.5:material='crew_webbing_edge';label='crew_belt'
            if z<-81.3:material='crew_boot';label='crew_boot_sculpt'
            if z<-88.8:material='crew_sole';label='crew_boot_sole'
            # Do not split an already contained triangle along arbitrary source
            # triangulation diagonals. Only genuine owner-boundary crossings split.
            contained=None
            samples=points+[[sum(v[k] for v in points)/3 for k in range(3)]]
            for part in (0,1,2,3,5,6):
                src=base['source_primitives'][part];vs=src['vertices']
                if all(min(v[2] for v in vs)-1e-7<=v[2]<=max(v[2] for v in vs)+1e-7 for v in samples):
                    if all((lambda span:span[0]-1e-7<=v[0]<=span[1]+1e-7)(_span(vs,v[2])) for v in samples):
                        contained=(part,src['id']);break
            if contained is not None:
                part,pid=contained;name='crew_sleeve_sculpt' if part in (5,6) and label=='crew_jacket_sculpt' else label
                groups=[g['offset'] for g in base['groups'] if pid in g['primitive_pointers']]
                t=[[round(k,6) for k in v] for v in points]
                if area2(t)>1e-8:add_face(out,t,material,pid,groups,name)
                continue
            pending=[points]
            for part,pid,boundary in owners:
                remain=[]
                for poly in pending:
                    inner=poly
                    for a,b in zip(boundary,boundary[1:]+boundary[:1]):
                        outside=clip(inner,a,b,False)
                        if len(outside)>=3:remain.append(outside)
                        inner=clip(inner,a,b,True)
                        if len(inner)<3:break
                    if len(inner)>=3:
                        name=label
                        if part in (5,6) and label=='crew_jacket_sculpt':name='crew_sleeve_sculpt'
                        groups=[g['offset'] for g in base['groups'] if pid in g['primitive_pointers']]
                        rounded=[[round(k,6) for k in v] for v in inner]
                        for t in triangulate(rounded):
                            if area2(t)>1e-8:add_face(out,t,material,pid,groups,name)
                pending=remain
                if not pending:break
    return out


def fitted_details(out,base,master):
    """Seat tailoring on the actual sculpt rather than an old blocking box.

    Every detail keeps the same original polygon owner. The small raised
    surfaces supply readable seams, while the master carries the fine stitch.
    """
    from tools.build_pc_tactical_vehicles import tube,emit
    source=base['source_primitives'][0]
    src=dict(source,groups=[g['offset'] for g in base['groups'] if source['id'] in g['primitive_pointers']])
    shell=[t for t in out if t['component'] in ('crew_jacket_sculpt','crew_belt','crew_trousers_sculpt')]
    def front(x,z):
        hits=[]
        for t in shell:
            a,b,c=t['vertices'];den=(b[2]-c[2])*(a[0]-c[0])+(c[0]-b[0])*(a[2]-c[2])
            if abs(den)<1e-9:continue
            u=((b[2]-c[2])*(x-c[0])+(c[0]-b[0])*(z-c[2]))/den
            v=((c[2]-a[2])*(x-c[0])+(a[0]-c[0])*(z-c[2]))/den
            if min(u,v,1-u-v)>=-1e-6:hits.append(u*a[1]+v*b[1]+(1-u-v)*c[1])
        if not hits:raise ValueError(f'Tailoring missed actual jacket {x,z}')
        return min(hits)
    def panel(points,material,label,lift=.22):
        # A bevelled perimeter follows the cloth, with its rear buried .08 raw
        # units into the sculpt. No floating rectangular pocket backs remain.
        # The waist rises 3.5 raw units; keep sewn details fitted to that waist.
        if label in ('crew_chest_pocket','crew_pocket_flap','crew_belt_loop','crew_buckle'):
            points=[(x,z+3.5) for x,z in points]
        cx=sum(x for x,z in points)/len(points);cz=sum(z for x,z in points)/len(points)
        if label=='crew_chest_pocket':
            points=[p for a,b in zip(points,points[1:]+points[:1]) for p in (a,((a[0]+b[0])/2,(a[1]+b[1])/2))]
        back=[[x,front(x,z)+.08,z] for x,z in points]
        rim=[[x,front(x,z)-lift*.55,z] for x,z in points]
        top=[[x+(cx-x)*.06,front(x+(cx-x)*.06,z+(cz-z)*.06)-lift,z+(cz-z)*.06] for x,z in points]
        from tools.build_pc_tactical_vehicles import solid
        solid(out,[src],[back,rim,top],material,label,cap_end=False)
        centre=[cx,front(cx,cz)-lift,cz]
        for a,b in zip(top,top[1:]+top[:1]):
            emit(out,[src],[a,b,centre],material,label,[cx,front(cx,cz)+.1,cz])
    for x in (-6.0,3.0):
        panel([(x,-46.5),(x+5.5,-46.5),(x+5.5,-41.1),(x,-41.1)],'crew_cloth','crew_chest_pocket',.70)
        panel([(x-.15,-42.25),(x+2.75,-42.7),(x+5.65,-42.25),(x+5.65,-40.8),(x-.15,-40.8)],'crew_cloth_light','crew_pocket_flap',.85)
    for low,high in ((-45.1,-39.0),(-29.5,-23.0)):
        panel([(-.1,low),(.85,low),(.85,high),(-.1,high)],'crew_cloth_shadow','crew_jacket_placket',.16)
    for side in (-1,1):
        panel([(side*1.0,-23.3),(side*5.5,-20.2),(side*4.2,-17.3),(side*.5,-19.6)],'crew_cloth_light','crew_folded_collar',.30)
    # The standing rear collar surrounds the independently commanded neck.
    # Its narrow top also stays inside the original shoulder/neck silhouette.
    from tools.build_pc_tactical_vehicles import solid
    rings=[]
    for z,rx,ry in ((-17.6,5.9,3.8),(-16.1,4.65,3.2),(-14.45,4.55,3.1)):
        rings.append([[rx*math.cos(j*math.tau/20),10.7+ry*math.sin(j*math.tau/20),z] for j in range(20)])
    solid(out,[src],rings,'crew_cloth_shadow','crew_standing_collar',cap_start=False,cap_end=False)
    for a,b in (([-.1,3.25,-32.8],[.7,2.95,-33.25]),([12.6,3.35,-32.3],[11.7,3.0,-32.9])):
        tube(out,[src],a,b,2.55,'crew_cloth_light','crew_cuff',16 if master else 10)
    # Waist, belt loops and buckle rise together, retaining fitted relief.
    for x in (-7.5,7.5):
        panel([(x-.5,-52.3),(x+.5,-52.3),(x+.5,-48.8),(x-.5,-48.8)],'crew_cloth','crew_belt_loop',.32)
    for x,z,w,h in ((-.7,-51.7,3.2,.45),(-.7,-49.4,3.2,.45),(-.7,-51.7,.45,2.75),(2.05,-51.7,.45,2.75)):
        panel([(x,z),(x+w,z),(x+w,z+h),(x,z+h)],'crew_metal','crew_buckle',.32)
    if master:
        for z in (-24.6,-27.5,-40.5,-43.5):
            y=front(.35,z)
            tube(out,[src],[.35,y-.17,z],[.35,y-.32,z],.22,'crew_cloth_shadow','crew_jacket_button',8)


bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
parts=[]
parts.append(loft('Tailored jacket with ribcage, waist and hem',[
 (1.4,10.7,-49.5,10.2,6.0),(1.4,10.7,-47.5,10.4,6.2),(1.6,10.7,-44.5,9.8,5.9),
 (1.9,10.7,-41.5,9.8,5.7),(2.1,10.6,-37.5,10.6,6.2),(2.2,10.3,-33.5,11.8,6.5),
 (2.3,10.1,-29,12.9,6.7),(2.2,10.0,-25,13.3,6.6),(2.1,10.0,-22,13.7,6.2),
 (2.0,10.1,-20,13.1,5.7),(1.7,10.3,-18,9.6,4.7),(0,10.7,-16,5.0,3.7),(0,10.7,-14,4.2,3.0)]))
parts.append(oval('Pelvis', (1.3,10.5,-51.0),(11.0,5.8,5.3)))
parts.append(limb('Left thigh',(-4.2,10.5,-52.5),(-6.4,7.9,-67),6.3,4.8,1.12))
parts.append(oval('Left kneecap',(-6.4,7.9,-67),(4.5,4.7,3.8)))
parts.append(limb('Left calf',(-6.4,7.9,-68),(-8.3,7.0,-82),5.0,3.7,1.15))
parts.append(limb('Right raised thigh',(9.5,10.0,-53.5),(32.8,7.5,-63),5.5,5.2,1.12))
parts.append(oval('Right kneecap',(33,7.2,-64),(4.9,5.0,4.4)))
parts.append(limb('Right calf',(33.0,7.2,-65),(34.0,7.0,-82),5.1,3.7,1.17))
for x in (-9,34):
    parts.append(boot_last(x))
    parts.append(loft('Boot fitted ankle and upper',[
        (x,9.3,-85.5,3.15,3.5),(x,9.0,-84,3.25,3.7),(x,8.2,-82,3.45,3.9),
        (x,7.5,-80,3.6,4.0),(x,7.2,-79,3.65,4.0)],24))
for side,shoulder,elbow,wrist in [
 ('Left',(-10.0,8.1,-22.4),(-8.6,5.3,-28.7),(2.0,2.7,-34.2)),
 ('Right',(17.0,8.2,-22.2),(24.0,5.7,-25.6),(9.8,2.8,-34.4))]:
    parts.append(oval(side+' deltoid',shoulder,(3.2,3.6,3.3)))
    parts.append(limb(side+' upper arm',shoulder,elbow,3.3,3.0,1.12))
    parts.append(oval(side+' elbow',elbow,(2.8,3.1,2.7)))
    parts.append(limb(side+' forearm',elbow,wrist,2.8,2.4,1.08))
# A joined sculpt removes the intersecting cylindrical joint caps.
bpy.ops.object.select_all(action='DESELECT')
for ob in parts:ob.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();sculpt=bpy.context.object;sculpt.name='OPERATOR_JOINED_SCULPT'
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
mod=sculpt.modifiers.new('Joined anatomy voxel sculpt','REMESH');mod.mode='VOXEL';mod.voxel_size=.38/SCALE;mod.use_smooth_shade=True
bpy.ops.object.modifier_apply(modifier=mod.name)
mod=sculpt.modifiers.new('Relax anatomical intersections','SMOOTH');mod.factor=.65;mod.iterations=4;bpy.ops.object.modifier_apply(modifier=mod.name)
# Restrained directional garment folds, strongest at elbows, waist and knees.
for v in sculpt.data.vertices:
    x,y,z=(c*SCALE for c in v.co)
    if -80<z<-18:
        front=max(0,min(1,(10.5-y)/6))
        waist=.18*math.exp(-((z+41.5)/5.5)**2)*math.sin((z+41.5)*1.25+x*.25)
        elbow=.30*math.exp(-((z+29-.24*abs(x-2))/3.2)**2)*math.sin(z*1.45-x*.48)
        knee=.32*math.exp(-((z+66)/4.0)**2)*math.sin(z*1.35+x*.40)
        v.co.y+=front*(waist+elbow+knee)/SCALE
    if -88<z<-83 and 2.8<y<5.6:
        # Sculpt the toe-cap crease into the leather, keeping the outsole,
        # raised arch and fitted ankle continuous rather than adding a wire.
        upper=max(0,min(1,(z+88)/1.5))
        v.co.z-=upper*.10*math.exp(-((y-4.2)/1.0)**2)/SCALE
sculpt.data.update()
# Keep the editable high sculpt and deterministic low retopology together.
low=sculpt.copy();low.data=sculpt.data.copy();bpy.context.collection.objects.link(low);low.name='OPERATOR_GAME_RETOPOLOGY'
bpy.context.view_layer.objects.active=low
mod=low.modifiers.new('Game retopology','DECIMATE');mod.ratio=min(1,1050/max(1,len(low.data.polygons)));mod.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=mod.name)
# Compress the high mesh to a practical bake master, preserving silhouette.
bpy.context.view_layer.objects.active=sculpt
mod=sculpt.modifiers.new('Bake master topology','DECIMATE');mod.ratio=min(1,8000/max(1,len(sculpt.data.polygons)));mod.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=mod.name)
base=load_catalog()['models'];data={'schema':1,'generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'recipe_sha256':hashlib.sha256((ROOT/'tools/pc_tactical_crews.py').read_bytes()).hexdigest(),'states':{}}
for shape in (161,162):
    data['states'][str(shape)]={}
    for master,ob in ((False,low),(True,sculpt)):
        ts=attributed(ob,base[shape])
        details=_blocking_geometry(base[shape],master)['triangles']
        # Reuse only fitted hardware; anatomical shells come from the sculpt.
        for tri in details:
            if tri['component'].startswith('launcher_'):
                if tri['component'].startswith('launcher_'):
                    tri['vertices']=[[v[0],v[1]+1.8,v[2]] for v in tri['vertices']]
                ts.append(tri)
        fitted_details(ts,base[shape],master)
        ts.extend(formed_hands(base[shape],master))
        m=dict(base[shape],triangles=ts);validate_model(m)
        data['states'][str(shape)]['master' if master else 'game']=ts
        print('SCULPT',shape,'master' if master else 'game',len(ts),flush=True)
with gzip.open(OUT/'geometry.json.gz','wt',encoding='utf-8') as f:json.dump(data,f,separators=(',',':'))
# Organized, editable Blender production scene, plus a lit sculpt preview.
sculpt.hide_render=True;sculpt.hide_set(True);low.hide_render=True;low.hide_set(True)
m=dict(base[161],triangles=data['states']['161']['master']);m['bounds']=bounds([v for t in m['triangles'] for v in t['vertices']]);shown=make_object(bpy,m);shown.name='SAGGER_SCULPT_REVIEW'
for poly in shown.data.polygons:poly.use_smooth=True
from tools.pc_tactical_crew_heads import geometry
head,_=geometry(base[161]);head_obj=make_object(bpy,head)
for poly in head_obj.data.polygons:poly.use_smooth=True
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.world.color=(.18,.18,.18)
center=Vector((7,6,-39))/SCALE;size=106/SCALE
bpy.ops.object.camera_add();cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=size*1.12;scene.camera=cam
for direction,energy,scale in [((-.8,-1.5,2),450,1.6),((1.4,1.2,1),300,1.3)]:
    bpy.ops.object.light_add(type='AREA',location=center+Vector(direction)*size);ob=bpy.context.object;ob.data.energy=energy;ob.data.size=size*scale;ob.rotation_euler=(center-ob.location).to_track_quat('-Z','Y').to_euler()
for name,direction in [('front',(0,-2,.15)),('threequarter',(1.0,-2,.3)),('rear',(-1.1,2,.3))]:
    cam.location=center+Vector(direction)*size;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'operators.blend'))
print('BLENDER_CREW_SCULPT_COMPLETE',flush=True)
