#!/usr/bin/env python3
"""Blender author for photograph-referenced kneeling Sagger/Spigot crews.

Original registry and object bounds remain intact. This pose deliberately uses
whole-object rigid presentation admission, not upright per-face silhouette clips.
"""
import argparse,copy,gzip,hashlib,json,math,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
import bpy
from mathutils import Vector,Matrix
from tools.build_pc_tactical_vehicles import load_catalog,make_object,SCALE
from tools.build_pc_modern_assets import add_face,area2,bounds,validate_model,triangulate
from tools.pc_tactical_ground_crews import POSE,head_point,grips,equipment,WRISTS,ELBOWS,cuffs,material_sections
from tools import pc_tactical_crews  # Registers the existing crew finish palette.
from tools.source_guard import inside_source
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output',type=Path,default=ROOT/'local-art/pc-tactical-crew-ground-v1')
options=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT=options.output.resolve()
if inside_source(OUT):raise ValueError('Refusing original inputs or pinned evidence')
OUT.mkdir(parents=True,exist_ok=True)

def mesh(name,vs,fs):
 m=bpy.data.meshes.new(name);m.from_pydata([[v/SCALE for v in p] for p in vs],[],fs);m.update();o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o);return o

def loft(name,stations,n=24):
 vs=[[x+rx*math.cos(j*math.tau/n),y+ry*math.sin(j*math.tau/n),z] for x,y,z,rx,ry in stations for j in range(n)];fs=[]
 for i in range(len(stations)-1):
  for j in range(n):fs.append([i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j])
 fs.extend([list(reversed(range(n))),list(range((len(stations)-1)*n,len(stations)*n))]);return mesh(name,vs,fs)

def oval(name,c,r):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,location=Vector(c)/SCALE);o=bpy.context.object;o.name=name;o.scale=Vector(r)/SCALE;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return o

def limb(name,a,b,r0,r1,depth=1,fullness=0):
 axis=(Vector(b)-Vector(a)).normalized();p=Vector((0,1,0));p=(p-axis*p.dot(axis)).normalized();q=axis.cross(p);vs=[];n=20;levels=9
 for i in range(levels+1):
  t=i/levels;c=Vector(a).lerp(Vector(b),t);r=(r0+(r1-r0)*t)*(.86+.14*math.sin(math.pi*t))*(1+fullness*math.exp(-((t-.35)/.25)**2))
  for j in range(n):vs.append(list(c+r*(p*math.sin(j*math.tau/n)*depth+q*math.cos(j*math.tau/n))))
 fs=[]
 for i in range(levels):
  for j in range(n):fs.append([i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j])
 fs.extend([list(reversed(range(n))),list(range(levels*n,(levels+1)*n))]);return mesh(name,vs,fs)

def boot(name,cy,offset=0,forward=1):
 section=[(1,0),(.94,.55),(.60,.90),(0,1),(-.60,.90),(-.94,.55),(-1,0),(-.85,-.8),(0,-1),(.85,-.8)]
 stations=[(-1.2,.8,-89.5,-89.0),(-.6,2.1,-89.8,-88.6),(.6,3.0,-90,-88),(2.8,3.65,-90,-87.5),(5.2,3.8,-90,-86.8),(7.5,3.2,-89.35,-85.2),(9.8,2.9,-89.1,-83.8),(11.8,3.0,-90,-84.8),(14.1,2.35,-90,-85.9),(15.3,1.8,-89.9,-87.1),(16.1,.65,-89.65,-88.4)]
 vs=[]
 for y,w,bot,top in stations:
  for u,v in section:vs.append([offset+forward*(2.5-.72*y),cy+.72*w*u,-90+((bot+top)/2+(top-bot)*.5*v+90)*.8])
 fs=[];n=len(section)
 for i in range(len(stations)-1):
  for j in range(n):fs.append([i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j])
 fs.extend([list(reversed(range(n))),list(range((len(stations)-1)*n,len(stations)*n))])
 o=mesh(name,vs,fs)
 # Reflection changes orientation; fix before joining/remeshing.
 if forward<0:
  import bmesh
  bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(o.data);bm.free()
 return o

def folded_boot():
 # A plantar-flexed rear ankle: toe on the ground, heel lifted, shaft along
 # the folded calf. Reusing the upright front boot creates a broken ankle.
 stations=[(-29.6,14.2,-88.5,.45,.3),(-29.2,14.2,-88.5,1.2,.65),(-28.4,14.2,-88.8,2.0,.95),
           (-26.6,14.2,-88.2,2.55,1.5),(-25.4,14.15,-87.6,2.4,1.55),
           (-24.2,14.1,-86.7,2.3,1.9),(-22.8,14.0,-85.7,2.2,1.95),(-21.0,14.0,-85.4,2.35,2.2),
           (-18.8,14.0,-85.3,2.45,2.35)]
 n=24;vs=[[x,cy+ry*math.cos(j*math.tau/n),z+rz*math.sin(j*math.tau/n)]
          for x,cy,z,ry,rz in stations for j in range(n)];fs=[]
 for i in range(len(stations)-1):
  for j in range(n):fs.append([i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j])
 fs.extend([list(reversed(range(n))),list(range((len(stations)-1)*n,len(stations)*n))])
 return mesh('Articulated folded rear boot',vs,fs)

def anatomy(shape):
 # Raise and round the shoulder yoke into the fitted collar. The eye/sight,
 # wrist, hip and kneeling contacts remain fixed; less bare neck is exposed.
 # Working if the head sits into a supported shoulder line in profile.
 parts=[loft('Kneeling field tunic', [(-24,9,-76.2,4.8,6.4),(-23,9,-72,4.9,6.6),(-21,9,-68,5.4,7.3),(-18.8,9,-63.3,5.9,8.0),(-16.3,9,-58.7,5.6,7.7),(-14.8,8.4,-56.1,4.8,6.6),(-13.5,7.5,-54.1,3.8,4.8),(-11.8,6,-52.6,2.8,3.2)])]
 parts += [oval('Pelvis',(-23,9,-74.5),(4.9,6.5,3.9)),
           limb('Forward thigh',(-22,3.8,-74.6),(-4.5,3.8,-70.8),4.2,3.6,fullness=.10),
           oval('Forward knee',(-4.5,3.8,-70.8),(3.5,3.6,3.3)),
           limb('Forward shin',(-4.5,3.8,-70.8),(-4.8,3.8,-84.8),3.0,2.25,fullness=.16),
           limb('Kneeling thigh',(-23,14,-74.5),(-11,14.8,-86.1),4.2,3.35,fullness=.12),
           oval('Weight-bearing kneeling knee',(-11,14.8,-86.65),(3.5,3.4,3.25)),
           limb('Folded calf',(-11,14.8,-85.6),(-23.2,14,-85.5),3.0,2.35,fullness=.12),
           boot('Forward formed boot',3.8),folded_boot(),
           loft('Forward boot shaft',[(-4.7,3.8,-86,2.45,2.6),(-4.8,3.8,-83,2.6,2.8),(-4.8,3.8,-81.8,2.8,2.9)])]
 wrists=WRISTS[shape]
 elbows=ELBOWS[shape]
 for side,shoulder,elbow,wrist in zip(('Near','Far'),((-16.8,2.9,-59.0),(-16.8,15.1,-59.0)),elbows,wrists):
  parts.extend([oval(side+' shoulder',shoulder,(3.1,2.7,2.0)),limb(side+' upper arm',shoulder,elbow,2.85,2.45),oval(side+' elbow',elbow,(2.55,2.5,2.6)),limb(side+' forearm',elbow,wrist,2.55,2.0)])
 bpy.ops.object.select_all(action='DESELECT')
 for o in parts:o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object;o.name=str(shape)+'_JOINED_ANATOMY';bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 mod=o.modifiers.new('Joined anatomy','REMESH');mod.mode='VOXEL';mod.voxel_size=.32/SCALE;mod.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=mod.name)
 # Voxel union may leave microscopic enclosed islands. Keep the connected
 # body shell before retopology; never ship disconnected remesh debris.
 import bmesh
 bm=bmesh.new();bm.from_mesh(o.data);unseen=set(bm.verts);components=[]
 while unseen:
  todo=[unseen.pop()];island=set(todo)
  while todo:
   for edge in todo.pop().link_edges:
    for v in edge.verts:
     if v in unseen:unseen.remove(v);island.add(v);todo.append(v)
  components.append(island)
 keep=max(components,key=len)
 bmesh.ops.delete(bm,geom=[v for island in components if island is not keep for v in island],context='VERTS')
 bm.to_mesh(o.data);bm.free()
 mod=o.modifiers.new('Natural cloth transitions','SMOOTH');mod.factor=.6;mod.iterations=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 for v in o.data.vertices:
  x,y,z=v.co*SCALE
  if z>-83:
   fold=.08*math.sin(z*1.8+y*.5)*math.exp(-((z+70)/6)**2)
   v.co.x+=fold/SCALE
 o.data.update();return o

def triangles(o,base):
 source=base['source_primitives'][0];groups=[g['offset'] for g in base['groups'] if source['id'] in g['primitive_pointers']];out=[];o.data.calc_loop_triangles()
 for t in o.data.loop_triangles:
  vs=[[round(c,6) for c in(o.matrix_world@o.data.vertices[i].co*SCALE)] for i in t.vertices]
  for polygon in material_sections(vs):
   c=[sum(v[k] for v in polygon)/len(polygon) for k in range(3)];x,y,z=c
   label='crew_jacket_sculpt';mat='crew_cloth'
   if z>-71 and x>-11:label='crew_sleeve_sculpt'
   if z<-71:label='crew_trousers_sculpt'
   if -73<z<-71 and x<-16:label='crew_belt';mat='crew_webbing_edge'
   if z<-83 and ((x>-10 and y<8) or(y>9 and x<-19)):label='crew_boot_sculpt';mat='crew_boot'
   if label=='crew_boot_sculpt' and z<-88.7:label='crew_boot_sole';mat='crew_sole'
   for face in triangulate(polygon):
    if area2(face)>1e-8:add_face(out,face,mat,source['id'],groups,label)
 return out

def details(out,base):
 from tools.build_pc_tactical_vehicles import solid
 src=dict(base['source_primitives'][0],groups=[g['offset'] for g in base['groups'] if base['source_primitives'][0]['id'] in g['primitive_pointers']]);shell=[t for t in out if t['component']=='crew_jacket_sculpt']
 def front(y,z):
  hits=[]
  for t in shell:
   a,b,c=t['vertices'];den=(b[2]-c[2])*(a[1]-c[1])+(c[1]-b[1])*(a[2]-c[2])
   if abs(den)<1e-10:continue
   u=((b[2]-c[2])*(y-c[1])+(c[1]-b[1])*(z-c[2]))/den;v=((c[2]-a[2])*(y-c[1])+(a[1]-c[1])*(z-c[2]))/den
   if min(u,v,1-u-v)>=-1e-6:
    x=u*a[0]+v*b[0]+(1-u-v)*c[0]
    if x<-11:hits.append(x)
  if not hits:raise ValueError(('Pocket missed tunic',y,z))
  return max(hits)
 def pocket(y0,y1,z0,z1,lifts,mat,label,nz):
  # A fitted grid follows the tunic between corners too. Flat four-corner
  # plates intersect its convex surface and expose dark slivers.
  ny=3;vs=[]
  for lift in lifts:
   for i in range(nz+1):
    z=z0+(z1-z0)*i/nz
    for j in range(ny+1):
     y=y0+(y1-y0)*j/ny;vs.append([front(y,z)+lift,y,z])
  stride=ny+1;layer=stride*(nz+1)
  def face(ids):add_face(out,[vs[i] for i in ids],mat,src['id'],src['groups'],label)
  for i in range(nz):
   for j in range(ny):
    a=i*stride+j;b=a+1;c=b+stride;d=a+stride
    face([d,c,b,a]);face([a+layer,b+layer,c+layer,d+layer])
  edge=list(range(stride))+[i*stride+ny for i in range(1,nz+1)]+[nz*stride+j for j in range(ny-1,-1,-1)]+[i*stride for i in range(nz-1,0,-1)]
  for a,b in zip(edge,edge[1:]+edge[:1]):face([a,b,b+layer,a+layer])
 for y in(6.0,9.5):
  pocket(y,y+2.4,-67,-62.6,(.12,.32),'crew_cloth_light','crew_chest_pocket',3)
  pocket(y-.1,y+2.5,-63.0,-62.2,(.12,.40),'crew_cloth','crew_pocket_flap',1)

bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
base=load_catalog()['models'];data={'schema':2,'generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'recipe_sha256':hashlib.sha256((ROOT/'tools/pc_tactical_crews.py').read_bytes()).hexdigest(),'ground_recipe_sha256':hashlib.sha256((ROOT/'tools/pc_tactical_ground_crews.py').read_bytes()).hexdigest(),'presentation_pose':POSE,'states':{}}
for shape in(161,162):
 high=anatomy(shape);low=high.copy();low.data=high.data.copy();bpy.context.collection.objects.link(low);low.name=str(shape)+'_GAME_ANATOMY'
 for o,target in((low,1000),(high,7500)):
  bpy.context.view_layer.objects.active=o;mod=o.modifiers.new('Bounded retopology','DECIMATE');mod.ratio=min(1,target/max(1,len(o.data.polygons)));mod.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=mod.name)
 data['states'][str(shape)]={}
 for master,o in((False,low),(True,high)):
  ts=triangles(o,base[shape]);details(ts,base[shape]);ts.extend(equipment(base[shape],master));ts.extend(grips(base[shape],master));ts.extend(cuffs(base[shape],master));m=dict(base[shape],triangles=ts);validate_model(m);data['states'][str(shape)]['master' if master else 'game']=ts;print('GROUND_CREW',shape,'master' if master else 'game',len(ts),flush=True)
 high.hide_render=True;high.hide_set(True);low.hide_render=True;low.hide_set(True)
with gzip.open(OUT/'geometry.json.gz','wt',encoding='utf-8') as f:json.dump(data,f,separators=(',',':'))
# Editable native scene and honest actual geometry review, with reference images
# packed as non-rendering image datablocks for subsequent Blender work.
shown=[]
from tools.pc_tactical_crew_heads import geometry as head_geometry
for shape in(161,162):
 m=dict(base[shape],triangles=data['states'][str(shape)]['master']);o=make_object(bpy,m);o.name=str(shape)+'_REFERENCE_MASTER';shown.append(o)
 h,_=head_geometry(base[shape]);h=copy.deepcopy(h)
 for t in h['triangles']:t['vertices']=[head_point(v) for v in t['vertices']]
 ho=make_object(bpy,h);shown.append(ho)
 for ob in(o,ho):
  for poly in ob.data.polygons:poly.use_smooth=True
refs=ROOT/'artifacts/tactical-crew-refinement-20261021-r16/references'
for f in refs.glob('*.jpg'):bpy.data.images.load(str(f),check_existing=True).pack()
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.render.resolution_x=1100;scene.render.resolution_y=850;scene.render.resolution_percentage=100;scene.world.color=(.18,.18,.18)
center=Vector((5,9,-65))/SCALE;size=90/SCALE
bpy.ops.object.camera_add();cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=size*1.15;scene.camera=cam
for d,e in [((-.6,-1.5,2),450),((1.4,1.2,1),300)]:
 bpy.ops.object.light_add(type='AREA',location=center+Vector(d)*size);o=bpy.context.object;o.data.energy=e;o.data.size=size*1.6;o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
for shape in(161,162):
 for j,o in enumerate(shown):o.hide_render=(j//2)!=(0 if shape==161 else 1)
 for name,d in [('front',(1,-2,.5)),('rear',(-1,2,.5)),('side',(2,-.3,.25))]:
  cam.location=center+Vector(d)*size;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/f'{shape}-{name}.png');bpy.ops.render.render(write_still=True)
for o in shown:o.hide_render=False
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'operators.blend'));print('BLENDER_CREW_SCULPT_COMPLETE',flush=True)
