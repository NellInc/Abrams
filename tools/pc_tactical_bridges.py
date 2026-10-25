"""Authored panel construction on original bridge/hangar surface coverage.

Original wirework, bridge gaps, endpoints and painter ownership remain exact.
Deck and cladding partitions occupy the incumbent triangles without extrusion.
"""
import copy,math
from tools.build_pc_modern_assets import MATERIALS,add_face,area2,bounds,validate_model,REGISTRY_FIELDS
FINISHES={
 'bridge_concrete_0':('stone_edge',(151,151,135),None),
 'bridge_concrete_1':('stone_edge',(143,146,134),None),
 'bridge_concrete_2':('stone_edge',(158,155,139),None),
 'bridge_concrete_3':('stone_edge',(147,147,132),None),
 'bridge_seal':('tyre',(69,74,70),None),
 'bridge_edge':('stone_edge',(176,172,151),None),
 'bridge_hangar_sheet':('equipment',(124,139,132),None),
 'bridge_hangar_seam':('equipment_edge',(77,91,86),None),
 'bridge_hangar_door':('door',(72,91,84),None),
 'bridge_roof_sheet':('equipment',(92,109,118),None),
 'bridge_flag_cloth':('cloth_light',(246,245,237),('fabric',.90,0.,.00018)),
 'bridge_flag_hem':('cloth_light',(236,236,227),('fabric',.93,0.,.00012)),
}
MATERIALS.update({k:list(v[1]) for k,v in FINISHES.items()})
SHAPES=(0,1,45,46,47,108,114)
# Original prefix-normal directions, independently verified against SHAPE.TBL.
# Coincident upper/underside owners are selected separately by the original.
DECK_NORMAL_Z={432:1,651:1,4419:1,4639:1,11023:1,11187:-1,
               12947:1,12957:1,13065:-1,13075:-1}

def clip(poly,axis,value,above):
 out=[]
 for a,b in zip(poly,poly[1:]+poly[:1]):
  da=(a[axis]-value)*(1 if above else -1);db=(b[axis]-value)*(1 if above else -1)
  if da>=0:out.append(a)
  if (da>=0)!=(db>=0):
   f=da/(da-db);out.append([a[k]+f*(b[k]-a[k]) for k in range(3)])
 return out

def geometry(base,master=False):
 model=copy.deepcopy(base);out=[];flag_written=False
 for t in base['triangles']:
  if base['shape_index']==47 and t['source_primitive']==4915:
   if not flag_written:
    source=next(p for p in base['source_primitives'] if p['id']==4915)
    if source['prefix_bytes']!=[27,1,1]:raise ValueError('Original white hangar flag changed')
    outer=source['vertices'];lo,hi=bounds(outer).values()
    # Cloth and its hem partition the exact original plane. The old lamp
    # inset and metal cladding grid made this sheet read as a rigid sign.
    inner=[[p[0]+(3 if p[0]==lo[0] else -3),p[1],
            p[2]+(3 if p[2]==lo[2] else -3)] for p in outer]
    add_face(out,inner,'bridge_flag_cloth',4915,t['source_groups'],'bridge_flag_field')
    for i in range(4):
     j=(i+1)%4
     add_face(out,[outer[i],outer[j],inner[j],inner[i]],'bridge_flag_hem',4915,t['source_groups'],'bridge_flag_hem')
    flag_written=True
   continue
  if t['material'] in ('lamp','glass','optic'):
   out.append(copy.deepcopy(t));continue
  pts=t['vertices'];n=[(pts[1][1]-pts[0][1])*(pts[2][2]-pts[0][2])-(pts[1][2]-pts[0][2])*(pts[2][1]-pts[0][1]),(pts[1][2]-pts[0][2])*(pts[2][0]-pts[0][0])-(pts[1][0]-pts[0][0])*(pts[2][2]-pts[0][2]),(pts[1][0]-pts[0][0])*(pts[2][1]-pts[0][1])-(pts[1][1]-pts[0][1])*(pts[2][0]-pts[0][0])]
  axes=[k for k in range(3) if k!=max(range(3),key=lambda k:abs(n[k]))]
  source=next(p for p in base['source_primitives'] if p['id']==t['source_primitive'])
  spans={k:max(v[k] for v in source['vertices'])-min(v[k] for v in source['vertices']) for k in axes}
  u,v=sorted(axes,key=lambda k:spans[k],reverse=True)
  lo={k:min(p[k] for p in source['vertices']) for k in axes};hi={k:max(p[k] for p in source['vertices']) for k in axes}
  if min(spans.values())<.001:out.append(copy.deepcopy(t));continue
  hangar=base['shape_index']==47
  # Hangar cladding has broad ribbed sheets rather than a masonry-like grid.
  nu=min(24,max(4,int(spans[u]/(150 if not hangar else 140))));nv=(2 if hangar else min(6,max(2,int(spans[v]/180))))
  for j in range(nu):
   a=lo[u]+spans[u]*j/nu;b=lo[u]+spans[u]*(j+1)/nu
   for k in range(nv):
    c=lo[v]+spans[v]*k/nv;d=lo[v]+spans[v]*(k+1)/nv
    # Closed joint strips retain coverage instead of cutting source gaps.
    wu=min(1.4,(b-a)*.035);wv=min(1.2,(d-c)*.035)
    for A,B,C,D,joint in ((a,a+wu,c,d,True),(b-wu,b,c,d,True),(a+wu,b-wu,c,c+wv,True),(a+wu,b-wu,d-wv,d,True),(a+wu,b-wu,c+wv,d-wv,False)):
     poly=pts
     for axis,val,above in ((u,A,True),(u,B,False),(v,C,True),(v,D,False)):
      poly=clip(poly,axis,val,above)
      if len(poly)<3:break
     if len(poly)<3:continue
     if hangar:
      mat='bridge_hangar_seam' if joint else 'bridge_hangar_door' if t['material']=='door' else 'bridge_roof_sheet' if t['material']=='roof' else 'bridge_hangar_sheet'
     else:mat='bridge_seal' if joint else 'bridge_concrete_'+str((j+2*k)%4)
     try:add_face(out,poly,mat,t['source_primitive'],t['source_groups'],'bridge_expansion_joint' if joint else 'bridge_cladding_panel' if hangar else 'bridge_cast_deck_panel')
     except ValueError:
      if sum(area2([poly[0],poly[q],poly[q+1]]) for q in range(1,len(poly)-1))>1e-6:raise
 if base['shape_index']!=47:
  for triangle in out:
   a,b,c=triangle['vertices']
   z=(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
   if z*DECK_NORMAL_Z[triangle['source_primitive']]<0:
    triangle['vertices']=[a,c,b]
 model['triangles']=out;model['source_passthrough']=[];model['bounds']=bounds([v for t in out for v in t['vertices']]);validate_model(model)
 if len(out)>8192:raise ValueError('Bridge authored allowance')
 for key in (*REGISTRY_FIELDS,'source_bounds','status'):
  if model[key]!=base[key]:raise ValueError('Bridge source metadata '+key)
 return model
