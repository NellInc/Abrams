#!/usr/bin/env python3
"""Blender authoring/baking for the optional Tactical M1A1 and T-62 pair.

Run with Blender --background --factory-startup --python THIS_FILE -- --output DIR.
The incumbent Modern catalogue is read only. Source attribution survives every
face, including Blender's UV unwrap and high-to-low normal bake. Units stay raw
source units on export; the editable Blender scene uses raw / 64, z up.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.build_pc_modern_assets import (REGISTRY_FIELDS, MATERIALS, add_face, bounds,
    center, clean_polygon, cross, dot, finish_colours, load_catalog, sub, validate_model)
from tools import source_guard

VERSION = 2
SHAPES = (115, 125)
SCALE = 64.0
ROSTER_SHAPES = tuple(range(115,145)) + (159,160,163,164)
# Tactical-only author palette. The incumbent builder and catalogue stay intact.
TACTICAL_PALETTE = {
    'hind_olive':[90,105,57], 'hind_pale':[164,164,139],
    'hind_blue':[91,126,143], 'red':[166,45,29],
    'burnt':[54,53,44], 'rust':[105,63,37], 'scorch':[23,25,23],
    'exposed':[112,112,100],
}
MATERIALS.update(TACTICAL_PALETTE)



def source_groups(base):
    """Authored parts may use only the original group's filled pose anchors."""
    primitives=copy.deepcopy(base['source_primitives'])
    for p in primitives:
        p['vertices']=clean_polygon(p['vertices'])
        p['groups']=[g['offset'] for g in base['groups'] if p['id'] in g['primitive_pointers']]
    return [[p for p in primitives if p['id'] in g['primitive_pointers'] and len(p['vertices'])>=3]
            for g in base['groups']]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def guard(path):
    path = Path(path).resolve()
    if source_guard.inside_source(path):
        raise ValueError('Output must be outside original game inputs')
    return path


# Visual dimensions are authored independently of the coarse source faces.
# Source units remain a pose/coverage coordinate system, never physical metres.
# Relative proportions: GDLS M1A1 fact sheet and museum T-62 references.
PROFILES = {
    125: {'half_width': 31.5, 'rear': -65.0, 'front': 71.5, 'ground': -26.0,
          'roof': 14.5, 'muzzle': 104.0, 'wheel_y': [-45,-30,-15,0,15,30,45]},
    115: {'half_width': 50.0, 'rear': -88.0, 'front': 112.0, 'ground': -31.0,
          'roof': 36.0, 'muzzle': 194.0, 'wheel_y': [-53,-19,15,45.5,76]},
}


def unit(v):
    length=math.sqrt(dot(v,v))
    return [x/length for x in v] if length>1e-12 else [0,0,1]


def emit(out, sources, points, material, component, inside=None):
    points=[list(p) for p in points]
    n=cross(sub(points[1],points[0]),sub(points[2],points[0]))
    if dot(n,n)<1e-12:return
    if inside is not None and dot(n,sub(center(points),inside))<0:
        points.reverse();n=[-x for x in n]
    normal=unit(n)
    def alignment(p):
        q=p['vertices'];pn=unit(cross(sub(q[1],q[0]),sub(q[2],q[0])))
        if dot(pn,sub(center(q),center([v for f in sources for v in f['vertices']])))<0:pn=[-x for x in pn]
        return dot(normal,pn)
    p=max(sources,key=alignment)
    add_face(out,points,material,p['id'],p['groups'],component)


def solid(out, sources, rings, material, component, cap_start=True, cap_end=True):
    inside=center([v for ring in rings for v in ring])
    if cap_start:emit(out,sources,rings[0],material,component,inside)
    if cap_end:emit(out,sources,rings[-1],material,component,inside)
    for a,b in zip(rings,rings[1:]):
        for j in range(len(a)):
            k=(j+1)%len(a)
            emit(out,sources,[a[j],a[k],b[k],b[j]],material,component,inside)


def box(out,sources,lo,hi,material,component):
    x,y,z=lo;X,Y,Z=hi
    solid(out,sources,[[[x,y,z],[X,y,z],[X,Y,z],[x,Y,z]],
                       [[x,y,Z],[X,y,Z],[X,Y,Z],[x,Y,Z]]],material,component)


def tube(out,sources,a,b,radius,material,component,segments=12,tip=None,open_end=False):
    axis=unit(sub(b,a));right=unit(cross(axis,[0,0,1] if abs(axis[2])<.9 else [0,1,0]));up=cross(axis,right)
    rings=[]
    for c,r in ((a,radius),(b,radius if tip is None else tip)):
        rings.append([[c[k]+r*(right[k]*math.cos(j*math.tau/segments)+up[k]*math.sin(j*math.tau/segments)) for k in range(3)] for j in range(segments)])
    solid(out,sources,rings,material,component,cap_end=not open_end)


def hatch(out,sources,x,y,z,radius,master,component):
    tube(out,sources,[x,y,z],[x,y,z+.65],radius,'hatch',component,32 if master else 20,tip=radius*.94)
    box(out,sources,[x-radius*.38,y-.28,z+.63],[x+radius*.38,y+.28,z+1.05],'steel',component+'_handle')
    for side in (-1,1):
        box(out,sources,[x+radius*.72,y+side*radius*.42-.6,z+.2],[x+radius*1.08,y+side*radius*.42+.6,z+.8],'steel',component+'_hinge')
    if master:
        for j in range(12):
            t=j*math.tau/12
            tube(out,sources,[x+radius*.82*math.cos(t),y+radius*.82*math.sin(t),z+.64],
                 [x+radius*.82*math.cos(t),y+radius*.82*math.sin(t),z+.78],.21,'steel',component+'_bolt_'+str(j),6)


def roadwheel_shell(out,sources,side,inner,outer,y,z,radius,material,name,master,
                    rim_radius=.85,rim_tip=.76,rim_depth=.25):
    """Joined tyre/rim with formed shoulders and the original round outline.

    The shared mounting ring removes two buried facing caps. Twenty-sided
    shoulders and an eleven-sided small hub retain the incumbent facet count.
    The middle section keeps the original track contact radius and wheel centre.
    """
    n=32 if master else 20
    rings=[[[x,y+radius*r*math.cos(j*math.tau/n),z+radius*r*math.sin(j*math.tau/n)]
            for j in range(n)] for x,r in ((inner,.94),(inner+(outer-inner)*.55,1.),(outer,rim_radius))]
    solid(out,sources,rings,material,name+'_tyre',cap_end=False)
    front=[[outer+side*rim_depth,y+radius*rim_tip*math.cos(j*math.tau/n),
            z+radius*rim_tip*math.sin(j*math.tau/n)] for j in range(n)]
    solid(out,sources,[rings[-1],front],'wheel',name+'_dish',cap_start=False)


def end_wheel(out,sources,side,inner,outer,y,z,radius,name,master):
    """Closed dished idler or integral toothed drive, with a recessed hub.

    Teeth are part of the sprocket rim instead of intersecting box blocks.
    The unpowered idler has a smooth, bevelled circumference on both sides.
    """
    # Preserve the exact tooth stations in the projection master. Subdividing
    # its crowns independently would bake a different sprocket silhouette.
    drive=name=='drive_sprocket';n=36 if drive else (32 if master else 16)
    rings=[]
    profile=((inner,1),(outer,1),(outer-side*.55,.48)) if drive else (
        (inner,.80),(outer-side*.35,1),(outer,.88),(outer-side*.55,.48))
    for x,r in profile:
        ring=[]
        for j in range(n):
            angle=j*math.tau/n
            # Each tooth has a flat crown and a genuine root between teeth.
            tooth=(.84 if j%(n//12)==0 else 1) if drive and r==1 else 1
            ring.append([x,y+radius*r*tooth*math.cos(angle),z+radius*r*tooth*math.sin(angle)])
        rings.append(ring)
    solid(out,sources,rings,'steel' if drive else 'wheel',name)
    tube(out,sources,[outer-side*.54,y,z],[outer+side*.22,y,z],radius*.24,'hub',name+'_hub',12 if master else 8)


def end_wheel_height(loop,y,radius):
    """Highest round-wheel seat touching the inside of the authored track.

    Account for the chamfered end shoes as well as the flat upper run. A wheel
    which fits the track's bounding box can still cut through those shoulders.
    """
    lower=[];upper=[];r=radius+.15
    for a,b in zip(loop,loop[1:]+loop[:1]):
        dy,dz=b[0]-a[0],b[1]-a[1];length=math.hypot(dy,dz)
        if abs(dy)<1e-9:
            if -dz*(y-a[0])/length<r:raise ValueError('End wheel exceeds vertical track run')
        else:
            seat=a[1]+(r*length+dz*(y-a[0]))/dy
            (lower if dy>0 else upper).append(seat)
    z=min(upper)
    if z<max(lower):raise ValueError('End wheel cannot fit authored track loop')
    return z


def running_gear(out,sources,tank,master):
    m1=tank==125; width=PROFILES[tank]['half_width']; x=width-1.3
    radius=8.0 if m1 else 15.0; z=-17.1 if m1 else -15.0
    rear,front=(-59,60) if m1 else (-83,110)
    top,bottom=(-3.2,-25.8) if m1 else (1.5,-30.8)
    # Track is a narrow three-dimensional belt, with open running-gear space.
    loop=[(rear+7,bottom),(front-8,bottom),(front+1,bottom+8),
          (front+2,top-4),(front-4,top),(rear+2,top),(rear-5,top-5),(rear-5,bottom+9)]
    centre_y=(rear+front)/2;centre_z=(top+bottom)/2
    count=48
    lengths=[math.dist(loop[i],loop[(i+1)%len(loop)]) for i in range(len(loop))];total=sum(lengths)
    path=[]
    for j in range(count):
        distance=j*total/count
        for i,length in enumerate(lengths):
            if distance<=length:
                a,b=loop[i],loop[(i+1)%len(loop)];t=distance/length
                path.append([a[k]*(1-t)+b[k]*t for k in range(2)]);break
            distance-=length
    for side in (-1,1):
        outside=side*x;inside=side*(x-(7.3 if m1 else 10.2))
        for j,p in enumerate(path):
            q=path[(j+1)%count]
            # Closed individual track shoes with a small articulation gap.
            mid=[(p[k]+q[k])/2 for k in range(2)]
            p=[mid[k]+(p[k]-mid[k])*.93 for k in range(2)]
            q=[mid[k]+(q[k]-mid[k])*.93 for k in range(2)]
            thickness=1.25 if m1 else 1.65
            normal=unit([0,mid[0]-centre_y,(mid[1]-centre_z)*5])
            rings=[]
            for xx in (inside,outside):
                rings.append([[xx,p[0],p[1]],[xx,q[0],q[1]],
                              [xx,q[0]-normal[1]*thickness,q[1]-normal[2]*thickness],
                              [xx,p[0]-normal[1]*thickness,p[1]-normal[2]*thickness]])
            solid(out,sources,rings,'track_edge' if j%4==0 else 'track','track_shoe')
            # Centred rubber pad; the steel end connectors remain visible.
            xx0,xx1=sorted((inside+side*.8,outside-side*.8))
            if master and abs(q[1]-p[1])<1.0 and mid[1]>centre_z:
                box(out,sources,[xx0,min(p[0],q[0])+.15,mid[1]-.1],
                    [xx1,max(p[0],q[0])-.15,mid[1]+.32],'tyre','track_pad')
        outer=side*(x-.8); inner=side*(x-4.0)
        for i,y in enumerate(PROFILES[tank]['wheel_y']):
            # Raised rim, dark rubber tyre and recessed pressed-metal dish.
            roadwheel_shell(out,sources,side,inner,outer,y,z,radius,'tyre',f'roadwheel_{i}',master,.86,.80,.35)
            tube(out,sources,[outer+side*.36,y,z],[outer+side*.70,y,z],radius*.29,'hub',f'roadwheel_{i}_hub',20 if master else 11)
            if master:
                for j in range(8):
                    t=j*math.tau/8
                    a=[outer+side*.36,y+radius*.57*math.cos(t),z+radius*.57*math.sin(t)]
                    b=[a[0]+side*.18,a[1],a[2]]
                    tube(out,sources,a,b,radius*.044,'steel',f'roadwheel_{i}_bolt_{j}',6)
        rr=(top-bottom)*(.22 if m1 else .30)
        for y,label in ((min(q[0] for q in loop)+rr+.6,'drive_sprocket'),
                        (max(q[0] for q in loop)-rr-.6,'track_idler')):
            end_wheel(out,sources,side,inner,outer,y,end_wheel_height(loop,y,rr),rr,label,master)
        # Separate fender/skirt planes no longer inflate the hull side volume.
        if m1:
            for i in range(7):
                y0=-61+i*17.5
                xx0,xx1=sorted((side*(width-.5),side*width))
                box(out,sources,[xx0,y0,-11.7],[xx1,y0+17.0,-1.7],'olive','skirt_panel_'+str(i))
        else:
            xx0,xx1=sorted((side*38.0,side*width))
            box(out,sources,[xx0,-86,6.0],[xx1,108,7.3],'olive','fender_plate')
            for i in range(3):
                y=-65+i*33
                box(out,sources,[xx0+.8,y,7.5],[xx1-.8,y+28,12.5],'equipment','fender_stowage')


def hull(out,sources,tank,master):
    if tank==125:
        lower=[[-21,-61,-21],[21,-61,-21],[23,59,-21],[-23,59,-21]]
        upper=[[-27,-64,-3.8],[27,-64,-3.8],[27,43,-3.8],[-27,43,-3.8]]
        solid(out,sources,[lower,upper],'olive','lower_hull_boat')
        # Separate upper glacis and lower nose give the front its wedge profile.
        solid(out,sources,[[[-27,42,-15],[27,42,-15],[25,70,-14],[-25,70,-14]],
                           [[-27,29,-3.4],[27,29,-3.4],[27,70,-10.5],[-27,70,-10.5]]],'olive','sloped_glacis')
        box(out,sources,[-27,-64,-5],[27,-35,-2.6],'olive','engine_deck')
        for side in (-1,1):
            xx0,xx1=sorted((side*27,side*31.5))
            box(out,sources,[xx0,-64,-3],[xx1,66,-1.8],'olive','fender_plate')
        hatch(out,sources,-5,40,-5.5,4.1,master,'driver_hatch')
        rear_y=-62;end=-39;w=46;deck=-2.5
    else:
        solid(out,sources,[[[-36,-84,-23],[36,-84,-23],[37,105,-23],[-37,105,-23]],
                           [[-39,-88,8.4],[39,-88,8.4],[39,85,8.4],[-39,85,8.4]]],'olive','lower_hull_boat')
        solid(out,sources,[[[-37,82,-22],[37,82,-22],[37,111,-12],[-37,111,-12]],
                           [[-39,77,8.4],[39,77,8.4],[39,111,-8],[-39,111,-8]]],'olive','sloped_glacis')
        rear_y=-85;end=-49;w=65;deck=8.5
        hatch(out,sources,-15,65,8.5,5.8,master,'driver_hatch')
        # Optional fixed rear drums, visual fittings only, no fuel state.
        for x in (-23,23):
            tube(out,sources,[x-13,-91,5],[x+13,-91,5],7.2,'equipment','rear_fuel_drum',32 if master else 20)
            for dx in (-8,8):tube(out,sources,[x+dx-.45,-91,5],[x+dx+.45,-91,5],7.4,'steel','drum_strap',24 if master else 16)
    for i in range(14):
        y=rear_y+(end-rear_y)*i/14
        box(out,sources,[-w/2,y,deck],[w/2,y+(end-rear_y)/22,deck+.22],'vent','engine_grille_'+str(i))
    for side in (-1,1):
        y=64 if tank==125 else 96;xx=side*(24 if tank==125 else 35);zz=-6 if tank==125 else -1
        tube(out,sources,[xx,y,zz],[xx,y+1.5,zz],1.5,'lamp','headlight',16 if master else 12)
        # Bent guards remain closed solid rails at gameplay scale.
        for dx in (-2,2):tube(out,sources,[xx+dx,y-.5,zz-1.5],[xx+dx,y-.5,zz+2.6],.32,'steel','headlight_guard',8)
        tube(out,sources,[xx-2,y-.5,zz+2.6],[xx+2,y-.5,zz+2.6],.32,'steel','headlight_guard',8)


def turret(out,sources,tank,master):
    if tank==125:
        lower=[[-24,-38,-1],[24,-38,-1],[27,12,-1],[16,37,2],[5.2,42,3],[-5.2,42,3],[-16,37,2],[-27,12,-1]]
        roof=[[-23,-39,14.5],[23,-39,14.5],[24,6,14],[17,25,12],[5.1,31,10],[-5.1,31,10],[-17,25,12],[-24,6,14]]
        solid(out,sources,[lower,roof],'olive','angular_turret_cheeks')
        # Bustle rear, blow-off panels, storage rack, and shallow side bins.
        for x in (-11,0,11):box(out,sources,[x-5,-36,14.52],[x+5,-20,14.85],'hatch','bustle_blowoff_panel')
        for side in (-1,1):
            xx0,xx1=sorted((side*23.5,side*25.3))
            box(out,sources,[xx0,-34,4],[xx1,-10,10],'equipment','turret_side_bin')
        for z in (3,9):
            tube(out,sources,[-24,-44,z],[24,-44,z],.45,'steel','bustle_rack',10)
            for side in (-1,1):tube(out,sources,[side*24,-44,z],[side*24,-36,z],.45,'steel','bustle_rack',10)
        for x in (-24,-12,0,12,24):tube(out,sources,[x,-44,3],[x,-44,9],.45,'steel','bustle_rack',10)
        for side in (-1,1):
            for j in range(3):tube(out,sources,[side*23,16+j*2.2,6],[side*26,18+j*2.2,7.5],.85,'equipment','smoke_launcher',12)
        # Low commander cupola and loader hatch retain a compact target profile.
        tube(out,sources,[-10,-6,14],[-10,-6,17],5.7,'hatch','commander_cupola',32 if master else 20)
        hatch(out,sources,-10,-6,17,5.4,master,'commander_hatch')
        hatch(out,sources,11,-7,14.2,5.4,master,'loader_hatch')
        box(out,sources,[6,8,13.4],[13,16,18.2],'equipment','gunner_sight_housing')
        box(out,sources,[6.7,15.8,14.5],[12.3,16.1,17.3],'optic','gunner_sight_glass')
        for j in range(6):
            a=j*math.tau/6
            box(out,sources,[-10+5.3*math.cos(a)-.8,-6+5.3*math.sin(a)-.6,16.1],
                [-10+5.3*math.cos(a)+.8,-6+5.3*math.sin(a)+.6,16.8],'optic','cupola_periscope')
    else:
        # Broad flattened cast turret with a lower undercut and asymmetric nose.
        segments=64 if master else 40
        profile=[(0,33,11.0),(1,41,13.0),(2,40,21.0),(3,34,29.0),(4,24,35.0),(5,18,36.0)]
        rings=[]
        for _,r,z in profile:
            rings.append([[r*math.cos(j*math.tau/segments),3+r*.97*math.sin(j*math.tau/segments),z] for j in range(segments)])
        solid(out,sources,rings,'olive','cast_turret_dome')
        tube(out,sources,[-14,-3,35],[-14,-3,40],8.0,'hatch','commander_cupola',40 if master else 24)
        hatch(out,sources,-14,-3,40,7.5,master,'commander_hatch')
        hatch(out,sources,14,-1,35.5,8,master,'loader_hatch')
        box(out,sources,[20,-5,29],[26,5,33.5],'equipment','infrared_searchlight_housing')
        tube(out,sources,[23,5,31],[23,6,31],2.1,'optic','infrared_searchlight_glass',24 if master else 16)
        # Rear ejector port is part of the casting, no independent animation.
        box(out,sources,[-8,-35,23],[8,-33,29],'equipment','shell_ejector_port')
        for j in range(6):
            a=j*math.tau/6
            tube(out,sources,[-14+7.5*math.cos(a),-3+7.5*math.sin(a),38.2],
                 [-14+7.5*math.cos(a),-3+7.5*math.sin(a),39.1],1.1,'optic','cupola_periscope',8)


def gun_tube(out,sources,tank,master):
    m1=tank==125;z=9.8 if m1 else 31.0;start=34 if m1 else 34;end=PROFILES[tank]['muzzle']
    box(out,sources,[-5.0,start-2,z-4.0],[5.0,start+6,z+4.0],'equipment','gun_mantlet')
    profile=[(0,2.5),(.08,1.8),(.30,1.7),(.34,2.65),(.52,2.65),(.56,1.7),(.97,1.55),(1,1.55)] if m1 else [(0,2.7),(.06,2.05),(.60,2.0),(.63,2.85),(.76,2.85),(.79,1.95),(1,1.75)]
    segments=48 if master else 24
    for i,((a,r),(b,R)) in enumerate(zip(profile,profile[1:])):
        tube(out,sources,[0,start+(end-start)*a,z],[0,start+(end-start)*b,z],r,'olive',
             'bore_evacuator' if max(r,R)>2.6 else 'turned_gun_tube',segments,tip=R,open_end=i==len(profile)-2)
    # Real open muzzle: wall and recessed dark bore, no black painted end disk.
    r=profile[-1][1];inner=r*.60
    for j in range(segments):
        a,b=j*math.tau/segments,(j+1)*math.tau/segments
        emit(out,sources,[[r*math.cos(a),end,z+r*math.sin(a)],[r*math.cos(b),end,z+r*math.sin(b)],
                          [inner*math.cos(b),end+.03,z+inner*math.sin(b)],[inner*math.cos(a),end+.03,z+inner*math.sin(a)]],'steel','muzzle_rim')
    tube(out,sources,[0,end-.8,z],[0,end-.75,z],inner,'vent','barrel_bore',segments)


def roof_gun(out,sources,tank,master):
    # The source's triangular roof sheets are gun placeholders, not fins.
    # Give this independently observed group its own fixed receiver and mount.
    if tank==125:
        tube(out,sources,[6,-6,15],[6,-6,20.2],.8,'steel','roof_gun_pedestal',12)
        box(out,sources,[4.3,-9,19.2],[7.7,16,21.6],'equipment','roof_gun_receiver')
        tube(out,sources,[6,16,21.2],[6,40,25.3],.5,'vent','roof_gun_barrel',16 if master else 10)
        box(out,sources,[7.7,-2,18.5],[11.0,5,22.0],'equipment','roof_gun_ammunition_box')
    else:
        tube(out,sources,[-20,-10,40],[-20,-10,54.5],1.0,'steel','roof_gun_pedestal',16 if master else 10)
        box(out,sources,[-22.2,-10,55],[-17.8,15,59.4],'equipment','roof_gun_receiver')
        tube(out,sources,[-20,15,59.35],[-20,55,59.35],.6,'vent','roof_gun_barrel',20 if master else 12)
        box(out,sources,[-25,0,54],[-22.2,9,59],'equipment','roof_gun_ammunition_box')
    box(out,sources,[-.8+(6 if tank==125 else -20),-11,18 if tank==125 else 53],
        [.8+(6 if tank==125 else -20),-8,20 if tank==125 else 55],'steel','roof_gun_traverse_bracket')


def build_geometry(base,master=False):
    tank=base['shape_index'];primitives=copy.deepcopy(base['source_primitives']);groups=base['groups'];output=[]
    for p in primitives:
        p['vertices']=clean_polygon(p['vertices']);p['groups']=[g['offset'] for g in groups if p['id'] in g['primitive_pointers']]
    def group(index):return [p for p in primitives if p['id'] in groups[index]['primitive_pointers'] and len(p['vertices'])>=3]
    if tank in (115,125):
        hull(output,group(0),tank,master);running_gear(output,group(0),tank,master)
        turret(output,group(1),tank,master);gun_tube(output,group(2 if tank==125 else 3),tank,master)
        roof_gun(output,group(3 if tank==125 else 2),tank,master)
    elif tank in (117,119,121,123,127):
        from tools.pc_tactical_tanks import geometry
        output=geometry(base,master)
    elif tank in (129,131,133,135,139):
        from tools.pc_tactical_tracked_vehicles import geometry
        output=geometry(base,master)
    elif tank in (137,141,143,159):
        from tools.pc_tactical_wheeled_vehicles import geometry
        output=geometry(base,master)
    elif tank in (163,164):
        from tools.pc_tactical_aircraft import geometry
        output=geometry(base,master)
    elif tank in ROSTER_SHAPES:
        from tools.pc_tactical_wrecks import geometry
        output=geometry(base,master)
    else:raise ValueError(f'Not an approved Tactical vehicle: {tank}')
    authored_materials=[t['material'] for t in output]
    finish_colours(tank,base['name'],base['class_roles'],output,primitives)
    # Explicit Hind camouflage and wreck heat damage are authored surfaces,
    # independent of the incumbent per-owner flat-colour finish.
    for tri,mat in zip(output,authored_materials):
        if tank in (163,164) or mat in TACTICAL_PALETTE:
            tri['material']=mat;tri['color']=MATERIALS[mat][:]
    model=copy.deepcopy(base);model['triangles']=output;model['bounds']=bounds([v for t in output for v in t['vertices']])
    model['visual_proportions']='Reference-led hull, turret and running gear; original owner mask and hit regions remain authoritative.'
    validate_model(model)
    if not master and len(output)>8192:raise ValueError(f'{tank} exceeds runtime triangle budget: {len(output)}')
    return model


def material(bpy, name, tank, camo_role=None):
    from tools.pc_tactical_finish import material as finish
    return finish(bpy,name,tank,camo_role)


def make_object(bpy, model):
    # Smart Project edits every selected mesh in multi-object edit mode.
    # Isolate this object so a later head/master cannot invalidate baked UVs.
    for previous in bpy.context.selected_objects:previous.select_set(False)
    vertices=[];faces=[];ids=[];mats=[];components=[];lookup={}
    from tools.pc_tactical_finish import camouflage_role
    material_key=lambda t:(t['material'],camouflage_role(model['shape_index'],t['material'],t['component']))
    names=sorted({material_key(t) for t in model['triangles']});component_names=sorted({t['component'] for t in model['triangles']})
    for t in model['triangles']:
        f=[]
        for v in t['vertices']:
            # Facial landmarks retain per-face semantics, with shared vertices
            # so a smooth bake master has no artificial nose/cheek normal seam.
            component='crew_head_skin_surface' if t['component'].startswith(('crew_head_skin_surface','crew_head_nose_bridge','crew_head_neck')) else 'crew_hand_surface' if t['component'].startswith('crew_hand') else t['component']
            key=(tuple(v),t['source_primitive'],component)
            if key not in lookup:lookup[key]=len(vertices);vertices.append([c/SCALE for c in v])
            f.append(lookup[key])
        faces.append(f);ids.append(t['source_primitive']);mats.append(names.index(material_key(t)));components.append(component_names.index(t['component']))
    mesh=bpy.data.meshes.new(model['name']+'_source_bound');mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new(model['name']+'_GAME',mesh);bpy.context.collection.objects.link(obj)
    for name,camo in names:mesh.materials.append(material(bpy,name,model['shape_index'],camo))
    for attr,values in (('source_primitive',ids),('component_id',components)):
        a=mesh.attributes.new(attr,'INT','FACE')
        for item,v in zip(a.data,values):item.value=v
    for poly,i,t in zip(mesh.polygons,mats,model['triangles']):
        poly.material_index=i
        if model['shape_index']==159 and t['component'].endswith('_tyre'):
            poly.use_smooth=True
        if t['component']=='truck_canvas_cover' and len({v[1] for v in t['vertices']})>1:
            poly.use_smooth=True
    obj['source_shape']=model['shape_index'];obj['source_units_per_blender_unit']=SCALE;obj['component_names']=json.dumps(component_names)
    bpy.context.view_layer.objects.active=obj;obj.select_set(True)
    if model['shape_index'] in (0,1,45,46,47,108,114):
        # Panel joints share their physical plane's UVs. Smart Project split
        # narrow strips into sub-texel islands with independent padded edges.
        from mathutils.geometry import box_pack_2d
        planes={}
        for triangle in model['triangles']:
            planes.setdefault(triangle['source_primitive'],[]).extend(triangle['vertices'])
        specifications={};rectangles=[]
        for identifier,points in sorted(planes.items()):
            lo=[min(p[k] for p in points) for k in range(3)]
            hi=[max(p[k] for p in points) for k in range(3)]
            axes=sorted(range(3),key=lambda k:hi[k]-lo[k],reverse=True)[:2]
            width,height=(hi[k]-lo[k] for k in axes)
            if min(width,height)<1e-7:raise ValueError('Flat source UV plane lost its area')
            specifications[identifier]=(axes,lo,width,height)
        scale=max(max(s[2:]) for s in specifications.values());padding=scale*.02
        identifiers=sorted(specifications)
        for identifier in identifiers:
            _,_,width,height=specifications[identifier]
            rectangles.append([0.,0.,width+2*padding,height+2*padding])
        width,height=box_pack_2d(rectangles);extent=max(width,height)
        uv=mesh.uv_layers.new(name='UVMap')
        locations={identifier:rectangle[:2] for identifier,rectangle in zip(identifiers,rectangles)}
        for poly,triangle in zip(mesh.polygons,model['triangles']):
            identifier=triangle['source_primitive'];axes,lo,_,_=specifications[identifier]
            x,y=locations[identifier]
            for loop,point in zip(poly.loop_indices,triangle['vertices']):
                uv.data[loop].uv=((x+padding+point[axes[0]]-lo[axes[0]])/extent,
                                  (y+padding+point[axes[1]]-lo[axes[1]])/extent)
        obj['bake_uv_layout']='Connected original-owner planes, padded once per physical sheet'
    else:
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
        # Flat receiver tangent frames need separate charts at large bends.
        # Working if crew head bakes no longer show broad cross-face normal seams.
        head=model['name'].endswith('_HEAD') and model['shape_index'] in (161,162)
        bpy.ops.uv.smart_project(angle_limit=math.radians(12 if head else 55),island_margin=.006 if head else .003,area_weight=.8,correct_aspect=True)
        bpy.ops.object.mode_set(mode='OBJECT')
        if head:
            # Hidden closure disks waste head texels; retain the visible lower brim disk.
            # Working if visible head charts retain detail after crease splitting.
            uv=mesh.uv_layers.active.data
            for label in ('crew_head_helmet_rim_end','crew_head_helmet_dome_end','crew_head_neck_end'):
                loops=[i for poly,t in zip(mesh.polygons,model['triangles']) if t['component']==label and (label!='crew_head_helmet_rim_end' or sum(v[2] for v in t['vertices'])/3>1.0) and (label!='crew_head_helmet_dome_end' or sum(v[2] for v in t['vertices'])/3<2.0) for i in poly.loop_indices]
                if loops:
                    centre=sum((uv[i].uv for i in loops),uv[loops[0]].uv*0)/len(loops)
                    for i in loops:uv[i].uv=centre+(uv[i].uv-centre)*.15
            # Tiny disconnected charts can receive no diffuse bake samples.
            # Give each complete chart a raster footprint before packing, rather
            # than moving individual triangles into a neighbour's padded texels.
            # Working if four barycentric samples per head triangle contain colour.
            parents=list(range(len(mesh.polygons)));owners={}
            def root(i):
                while parents[i]!=i:parents[i]=parents[parents[i]];i=parents[i]
                return i
            for poly in mesh.polygons:
                for loop in poly.loop_indices:
                    key=(mesh.loops[loop].vertex_index,tuple(round(v,8) for v in uv[loop].uv))
                    if key in owners:parents[root(poly.index)]=root(owners[key])
                    else:owners[key]=poly.index
            charts={}
            for poly in mesh.polygons:charts.setdefault(root(poly.index),[]).append(poly)
            expanded=0
            for polys in charts.values():
                loops=[i for poly in polys for i in poly.loop_indices]
                lo=[min(uv[i].uv[k] for i in loops) for k in (0,1)]
                hi=[max(uv[i].uv[k] for i in loops) for k in (0,1)]
                factors=[max(1.,.008/max(hi[k]-lo[k],1e-12)) for k in (0,1)]
                area=0.
                for poly in polys:
                    a,b,c=[uv[i].uv for i in poly.loop_indices]
                    area+=abs((b-a).cross(c-a))*.5
                extra=max(1.,math.sqrt(.00004/max(area*factors[0]*factors[1],1e-15)))
                factors=[f*extra for f in factors]
                if max(factors)>1:
                    expanded+=1
                    for i in loops:
                        for k in (0,1):uv[i].uv[k]=(lo[k]+hi[k])*.5+(uv[i].uv[k]-(lo[k]+hi[k])*.5)*factors[k]
            obj['head_uv_chart_minimum']=json.dumps({'charts':len(charts),'expanded':expanded,'minimum_span':.008,'minimum_area':.00004,'before_final_pack':True})
            bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
            bpy.ops.uv.pack_islands(rotate=True,scale=True,margin=.006)
            bpy.ops.object.mode_set(mode='OBJECT')
    return obj


def image_target(bpy,obj,label,size):
    image=bpy.data.images.new(label,width=size,height=size,alpha=False)
    if label.endswith(('normal','ao','roughness','metallic')):image.colorspace_settings.name='Non-Color'
    for mat in obj.data.materials:
        node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=image
        mat.node_tree.nodes.active=node
    return image


def attach_occlusion(bpy, material, image):
    """Retain the baked AO using Blender's official glTF material socket."""
    from io_scene_gltf2.blender.com.material_helpers import create_settings_group
    group=bpy.data.node_groups.get('glTF Material Output')
    if group is None:group=create_settings_group('glTF Material Output')
    nodes,links=material.node_tree.nodes,material.node_tree.links
    output=next((n for n in nodes if n.type=='GROUP' and n.node_tree==group),None)
    if output is None:
        output=nodes.new('ShaderNodeGroup');output.node_tree=group
    texture=nodes.new('ShaderNodeTexImage');texture.name='Baked contact occlusion';texture.image=image
    image.colorspace_settings.name='Non-Color'
    links.new(texture.outputs['Color'],output.inputs['Occlusion'])


def bridge_bake_subsets(bpy,obj,high):
    """Bake original top/underside alternatives without coincident ray hits.

    Only the two source bridges with coincident opposite owners need this.
    Temporary meshes keep the complete mesh's UVs and are never exported.
    """
    shape=int(obj.get('source_shape',-1))
    sets={108:((11023,),(11187,)),
          114:((12947,12957),(13065,13075))}.get(shape)
    if sets is None:return []
    import bmesh
    pairs=[]
    for owners in sets:
        pair=[]
        for original in (obj,high):
            mesh=original.data.copy();bm=bmesh.new();bm.from_mesh(mesh)
            layer=bm.faces.layers.int.get('source_primitive')
            if layer is None:raise ValueError('Bridge bake lost source ownership')
            bmesh.ops.delete(bm,geom=[f for f in bm.faces if f[layer] not in owners],context='FACES')
            bm.to_mesh(mesh);bm.free();mesh.update()
            if not mesh.polygons:raise ValueError('Empty bridge bake owner set')
            subset=original.copy();subset.data=mesh
            subset.name=original.name+'_BAKE_'+str(owners[0])
            bpy.context.collection.objects.link(subset)
            subset.hide_set(False);subset.hide_render=True
            pair.append(subset)
        pairs.append(tuple(pair))
    obj['bake_visibility_sets']=json.dumps(sets)
    return pairs


def crew_normal_bake_subsets(bpy,obj,high):
    """Project each close-set grip part from its own master, retaining UVs.

    Working if fingers retain their smooth normal bake without rays striking
    neighbouring digits or the held case; full-shell contact AO is unchanged.
    """
    if int(obj.get('source_shape',-1)) not in (161,162) or obj.get('source_command_offset') is not None:return []
    import bmesh
    from mathutils import Vector
    def groups(original):
        mesh=original.data;names=json.loads(original['component_names'])
        hand={p.index for p,c in zip(mesh.polygons,mesh.attributes['component_id'].data) if names[c.value].startswith('crew_hand')}
        if not hand:raise ValueError('Crew normal bake lost its formed hands')
        adjacent={}
        for i in hand:
            for v in mesh.polygons[i].vertices:adjacent.setdefault(v,set()).add(i)
        pending=set(hand);parts=[]
        while pending:
            found=set();queue=[next(iter(pending))]
            while queue:
                i=queue.pop()
                if i in found:continue
                found.add(i)
                for v in mesh.polygons[i].vertices:queue.extend(adjacent[v]-found)
            pending-=found
            vertices={v for i in found for v in mesh.polygons[i].vertices}
            centre=sum((mesh.vertices[v].co for v in vertices),Vector())/len(vertices)
            parts.append((found,centre))
        if len(parts)!=12:raise ValueError('Expected two palms, eight fingers and two thumbs')
        return set(range(len(mesh.polygons)))-hand,parts
    body_low,low_parts=groups(obj);body_high,high_parts=groups(high)
    matched=[(body_low,body_high,False)]
    for low_ids,centre in low_parts:
        at=min(range(len(high_parts)),key=lambda i:(high_parts[i][1]-centre).length)
        high_ids,other=high_parts.pop(at)
        if (other-centre).length>.005:raise ValueError('Crew grip master correspondence lost')
        matched.append((low_ids,high_ids,True))
    pairs=[]
    for number,(low_ids,high_ids,hand) in enumerate(matched):
        pair=[]
        for original,ids in ((obj,low_ids),(high,high_ids)):
            mesh=original.data.copy();bm=bmesh.new();bm.from_mesh(mesh);bm.faces.ensure_lookup_table()
            bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.index not in ids],context='FACES')
            bm.to_mesh(mesh);bm.free();mesh.update()
            subset=original.copy();subset.data=mesh;subset.name=original.name+'_NORMAL_'+str(number)
            subset['crew_hand_projection']=hand;bpy.context.collection.objects.link(subset)
            subset.hide_set(False);subset.hide_render=True;pair.append(subset)
        pairs.append(tuple(pair))
    obj['bake_normal_visibility_sets']=json.dumps({'body':1,'grip_parts':12,'hand_cage':.002,'hand_max_ray_distance':.008,'contact_ao':'complete game shell'})
    return pairs


def bake(bpy,obj,high,directory,size):
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.device='CPU'
    crew=int(obj.get('source_shape',-1)) in (161,162)
    crew_body=crew and obj.get('source_command_offset') is None
    crew_head=crew and not crew_body
    # Thin roof tiles share a cage with nearby zinc flashing. Projecting
    # their colour/roughness/metalness painted metal flecks onto ceramic. Use
    # their own authored materials, retaining high-to-low normals and shell AO.
    # Working if ceramic tile interiors remain dielectric with no mirror flecks.
    exact_surface=int(obj.get('source_shape',-1)) in (145,146,154,155,158)
    if crew_head:obj['bake_head_normal_projection']=json.dumps({'cage':.006,'max_ray_distance':.018,'donor':'complete head','margin':8})
    organic=crew or int(obj.get('source_shape',-1))==157
    scene.render.bake.margin=8
    bpy.context.preferences.filepaths.save_version=0
    bevel=high.modifiers.new('Fine mechanical edge radii','BEVEL');bevel.width=.002;bevel.segments=3;bevel.affect='EDGES';bevel.limit_method='ANGLE';bevel.angle_limit=math.radians(35)
    component_names=json.loads(high['component_names'])
    for poly,identifier in zip(high.data.polygons,high.data.attributes['component_id'].data):
        label=component_names[identifier.value]
        if label in ('cast_turret_dome','turned_gun_tube','bore_evacuator','thermal_sleeved_gun',
                     'm60_long_nose_cast_turret','bmp1_low_conical_turret','bmp2_two_man_turret') or label.endswith(('_rim','_compound_cast_turret')) or label.startswith(('architecture_cow_piebald_barrel','architecture_cow_sloping_neck','architecture_cow_head_profile','architecture_cow_broad_muzzle','architecture_cow_jointed_leg','crew_jacket','crew_trousers','crew_sleeve','crew_hand','crew_boot_sculpt','crew_belt','crew_head_skin_surface','crew_head_nose_bridge','crew_head_neck','crew_head_helmet_dome','crew_head_ear','crew_head_collar')):poly.use_smooth=True
        if int(obj['source_shape']) not in (158,159) and (label.endswith('_tyre') or label in ('sculpted_fuselage','dorsal_fairing','pilot_canopy','gunner_canopy','collapsed_tyre','damaged_roadwheel')):
            poly.use_smooth=True
    isolated=bridge_bake_subsets(bpy,obj,high)
    normal_isolated=crew_normal_bake_subsets(bpy,obj,high)
    receivers=isolated or [(obj,high)]
    if isolated:obj.hide_render=True;high.hide_render=True
    images={}
    for kind in ('albedo','normal','ao','roughness','metallic'):
        active_receivers=normal_isolated if kind=='normal' and normal_isolated else receivers
        for low,master in receivers+normal_isolated:
            low.hide_render=True;master.hide_render=True
        image=image_target(bpy,obj,obj.name+'_'+kind,size)
        # Garments and the farm animal use exact game-shell material colours.
        # Independent heads and the farm animal retain their generous cage;
        # the close sleeve/jacket gap needs the crew-body projection below.
        scene.render.bake.use_selected_to_active=kind=='normal' or (not (organic or exact_surface) and kind in ('albedo','roughness','metallic'))
        # A broad organic cage crosses the close sleeve/jacket gap and captures
        # the opposite surface. The body-only .768-raw-unit cage avoids that;
        # independent heads and all other asset families retain their recipe.
        scene.render.bake.cage_extrusion=.012 if crew_body else .04 if organic else .006
        scene.render.bake.max_ray_distance=.04 if crew_body else .08 if organic else .018
        if kind=='metallic':
            restoration=[]
            for mat in (high.data.materials if scene.render.bake.use_selected_to_active else obj.data.materials):
                nodes=mat.node_tree.nodes;links=mat.node_tree.links;bs=nodes.get('Principled BSDF');output=nodes.get('Material Output')
                emission=nodes.new('ShaderNodeEmission');socket=bs.inputs['Metallic'];v=socket.default_value
                if socket.is_linked:links.new(socket.links[0].from_socket,emission.inputs['Color'])
                else:emission.inputs['Color'].default_value=(v,v,v,1)
                links.new(emission.outputs[0],output.inputs['Surface']);restoration.append((mat,emission,bs,output))
        for number,(receiver,source) in enumerate(active_receivers):
            hand=bool(receiver.get('crew_hand_projection',False))
            # Keep the complete head and UV padding together. Short normal rays
            # avoid crossing from thin ears/straps into adjacent facial skin.
            # Working if both cheek straps and ear edges bake without black seams.
            head_normal=crew_head and kind=='normal'
            scene.render.bake.cage_extrusion=.002 if hand else .012 if crew_body else .006 if head_normal else .04 if organic else .006
            scene.render.bake.max_ray_distance=.008 if hand else .04 if crew_body else .018 if head_normal else .08 if organic else .018
            for o in bpy.context.selected_objects:o.select_set(False)
            for low,master in active_receivers:
                low.hide_render=low!=receiver
                master.hide_render=master!=source or not scene.render.bake.use_selected_to_active
            receiver.select_set(True);bpy.context.view_layer.objects.active=receiver
            if scene.render.bake.use_selected_to_active:source.select_set(True)
            # Clear once per channel, then retain the other side's UV islands.
            scene.render.bake.use_clear=number==0
            if kind=='metallic':bpy.ops.object.bake(type='EMIT')
            elif kind=='albedo':bpy.ops.object.bake(type='DIFFUSE',pass_filter={'COLOR'})
            else:bpy.ops.object.bake(type={'normal':'NORMAL','ao':'AO','roughness':'ROUGHNESS'}[kind])
        if kind=='metallic':
            for mat,emission,bs,output in restoration:
                mat.node_tree.links.new(bs.outputs[0],output.inputs['Surface']);mat.node_tree.nodes.remove(emission)
        image.filepath_raw=str(directory/(kind+'.png'));image.file_format='PNG';image.save();images[kind]=image
    for pair in isolated+normal_isolated:
        for subset in pair:
            mesh=subset.data;bpy.data.objects.remove(subset,do_unlink=True)
            bpy.data.meshes.remove(mesh)
    scene.render.bake.use_clear=True
    obj.hide_render=False
    high.hide_render=True;high.hide_set(True)
    # Replace authoring materials by their actual baked maps for previews/export.
    baked=bpy.data.materials.new(obj.name+'_baked');baked.use_nodes=True
    n=baked.node_tree.nodes;l=baked.node_tree.links;bs=n.get('Principled BSDF')
    for kind,target in (('albedo','Base Color'),('roughness','Roughness'),('metallic','Metallic')):
        tex=n.new('ShaderNodeTexImage');tex.image=images[kind];l.new(tex.outputs['Color'],bs.inputs[target])
    tex=n.new('ShaderNodeTexImage');tex.image=images['normal'];normal=n.new('ShaderNodeNormalMap');l.new(tex.outputs['Color'],normal.inputs['Color']);l.new(normal.outputs['Normal'],bs.inputs['Normal'])
    attach_occlusion(bpy,baked,images['ao'])
    obj.data.materials.clear();obj.data.materials.append(baked)
    for poly in obj.data.polygons:poly.material_index=0
    return images,high


def pack_outputs(out):
    from PIL import Image
    out=guard(out)
    atlases={k:Image.new('RGB',(2048,1024)) for k in ('albedo','normal','orm')}
    for slot,index in enumerate(SHAPES):
        folder=out/str(index)
        for kind in ('albedo','normal'):
            pixels=Image.open(folder/(kind+'.png')).convert('RGB').resize((1024,1024),Image.Resampling.LANCZOS)
            atlases[kind].paste(pixels,(slot*1024,0))
        channels=[Image.open(folder/(kind+'.png')).convert('L').resize((1024,1024),Image.Resampling.LANCZOS) for kind in ('ao','roughness','metallic')]
        atlases['orm'].paste(Image.merge('RGB',channels),(slot*1024,0))
    for name,pixels in atlases.items():pixels.save(out/(name+'.png'))
    (out/'manifest.json').write_text(json.dumps({'schema':1,'files':{name:sha(out/name) for name in ('catalog.json','albedo.png','normal.png','orm.png')},
        'maps':{'albedo':'sRGB RGB','normal':'linear OpenGL tangent RGB, original Blender UV V','orm':'linear R ambient occlusion, G roughness, B metallic'},
        'runtime_size':[2048,1024],'source':'Blender-authored and baked; see authoring.json'},indent=2)+'\n')
    print('TACTICAL_VEHICLE_TEXTURES: complete')


def export_model(obj,model,uv_offset):
    mesh=obj.data;uv=mesh.uv_layers.active.data
    for tri,poly in zip(model['triangles'],mesh.polygons):
        tri['uvs']=[[round((float(uv[i].uv.x)+uv_offset)/2,8),round(1-float(uv[i].uv.y),8)] for i in poly.loop_indices]
    public={k:v for k,v in model.items() if k not in REGISTRY_FIELDS}
    public['source_lines']=[{k:v for k,v in line.items() if k not in ('vertices','prefix_bytes')} for line in model['source_lines']]
    public['status']='authored_mesh';public['tactical_vehicle_detail']=True
    public['bounds']=bounds([v for t in model['triangles'] for v in t['vertices']])
    return public


def main():
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else sys.argv[1:]
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=ROOT/'local-art/pc-tactical-vehicles-v1');p.add_argument('--size',type=int,default=2048);p.add_argument('--geometry-only',action='store_true');p.add_argument('--pack',action='store_true');a=p.parse_args(args)
    out=guard(a.output);out.mkdir(parents=True,exist_ok=True)
    if a.pack:pack_outputs(out);return
    import bpy
    if a.size not in (1024,2048):p.error('--size must be 1024 or 2048')
    base=load_catalog();models=[]
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    for slot,index in enumerate(SHAPES):
        directory=out/str(index);directory.mkdir(exist_ok=True)
        model=build_geometry(base['models'][index]);print(f'TACTICAL_VEHICLE_GEOMETRY {index}: {len(model["triangles"])} triangles',flush=True)
        for o in bpy.context.selected_objects:o.select_set(False)
        obj=make_object(bpy,model)
        if not a.geometry_only:
            high=make_object(bpy,build_geometry(base['models'][index],True));high.name=obj.name.replace('_GAME','_MASTER')
            bake(bpy,obj,high,directory,a.size)
            for o in bpy.context.selected_objects:o.select_set(False)
            obj.select_set(True);bpy.context.view_layer.objects.active=obj
            bpy.ops.export_scene.gltf(filepath=str(directory/(model['name'].lower()+'.glb')),export_format='GLB',use_selection=True,export_extras=True)
        models.append(export_model(obj,model,slot));obj.hide_render=True;obj.hide_set(True)
        bpy.ops.file.pack_all()
        bpy.ops.wm.save_as_mainfile(filepath=str(out/'vehicles.blend'),check_existing=False)
    public={'schema':1,'authoring_revision':VERSION,'sources':base['sources'],'source_registry':base['source_registry'],
            'models':models,'texture_contract':'Full-colour albedo, tangent normal, ambient occlusion and roughness. UVs use top-left PNG origin. Two equal horizontally packed model tiles.',
            'visibility_contract':'Original source owner and source anchors only; no new visibility or gameplay state.'}
    (out/'catalog.json').write_text(json.dumps(public,separators=(',',':'))+'\n')
    (out/'authoring.json').write_text(json.dumps({'tool':'Blender '+bpy.app.version_string,'builder_sha256':sha(__file__),'base_catalog_sha256':sha(ROOT/'local-art/pc-modern/catalog.json'),
        'master_texture_size':a.size,'models':{m['name']:len(m['triangles']) for m in models},'reference_only_images':['https://international.gdls.com/english/products/ABRAMS/M1A1.pdf','https://www.marines.mil/Photos/igphoto/2000021653/','https://www.tucsonmilitaryvehicle.org/exhibit/t-62-main-battle-tank/','https://commons.wikimedia.org/wiki/Category:Ex-Iraqi_T-62_tank_in_Bovington_Tank_Museum'],
        'limits':'Independently authored visual proportions inside original owner coverage. Original hit regions and simulation are unchanged. Reference photographs are not copied into texture pixels.'},indent=2)+'\n')
    for slot,index in enumerate(SHAPES):
        obj=next(o for o in bpy.data.objects if o.type=='MESH' and o.name.endswith('_GAME') and o.get('source_shape')==index)
        obj.hide_render=False;obj.hide_set(False);obj.location.x=(slot-.5)*7
        for high in bpy.data.objects:
            if high.name.endswith('_MASTER') and high.get('source_shape')==index:high.location.x=obj.location.x
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'vehicles.blend'),check_existing=False)
    print('TACTICAL_VEHICLE_AUTHORING: complete',flush=True)


if __name__=='__main__':main()
