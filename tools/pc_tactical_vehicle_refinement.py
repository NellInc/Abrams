"""Construction-scale second-pass details for the complete Tactical vehicle set.

This pass changes rendered triangles only. Original groups, poses, primitives,
lines, source bounds and gameplay metadata are immutable. Geometry is deliberately
alias-neutral for each source-equivalent wreck family and the two Hind states.
"""
from __future__ import annotations

import copy
import math


# Direct palette roles reuse the established bake shaders, with no new finishes.
FINISHES = {}


def _eye(out, src, centre, radius, material, name, axis='x'):
    """Forged closed towing/lifting eye with a genuine open centre."""
    from tools.build_pc_tactical_vehicles import solid
    x,y,z=centre;minor=radius*.22;rings=[]
    for i in range(9):
        t=i*math.tau/8;ring=[]
        for j in range(4):
            a=j*math.tau/4;radial=radius+minor*math.cos(a);axial=minor*math.sin(a)
            if axis=='x':ring.append([x+axial,y+radial*math.cos(t),z+radial*math.sin(t)])
            else:ring.append([x+radial*math.cos(t),y+axial,z+radial*math.sin(t)])
        rings.append(ring)
    solid(out,src,rings,material,name,cap_start=False,cap_end=False)


def _tow_pair(out, src, halfwidth, y, z, radius=1.8, rear=False):
    from tools.build_pc_tactical_vehicles import box
    direction=-1 if rear else 1
    for side in (-1,1):
        x=side*halfwidth
        a,b=sorted((y-direction*radius*.65,y+direction*.45))
        box(out,src,[x-radius*.42,a,z-radius*.65],
            [x+radius*.42,b,z+radius*.65],'olive_edge','refine_tow_mount')
        _eye(out,src,[x,y+direction*radius*.8,z],radius,'steel','refine_forged_tow_eye')


def _component_bounds(model,names):
    from tools.build_pc_tactical_vehicles import bounds
    points=[v for t in model['triangles'] if t['component'] in names for v in t['vertices']]
    if not points:raise ValueError(f'Missing authored refinement anchor {names}')
    return bounds(points)


def _skin_z(model,names,x,y):
    """Top intersection with the actual finished triangle skin, not old scales."""
    hits=[]
    for tri in model['triangles']:
        if tri['component'] not in names:continue
        a,b,c=tri['vertices'];den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        if abs(den)<1e-9:continue
        u=((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(y-c[1]))/den
        v=((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(y-c[1]))/den;w=1-u-v
        if min(u,v,w)>=-1e-7:hits.append(u*a[2]+v*b[2]+w*c[2])
    if not hits:raise ValueError(f'Refinement anchor missed authored skin {names} at {x,y}')
    return max(hits)


def _skin_y(model,names,x,z,front=True):
    """Fore/aft intersection with the casting; None outside its silhouette."""
    hits=[]
    for tri in model['triangles']:
        if tri['component'] not in names:continue
        a,b,c=tri['vertices'];den=(b[2]-c[2])*(a[0]-c[0])+(c[0]-b[0])*(a[2]-c[2])
        if abs(den)<1e-9:continue
        u=((b[2]-c[2])*(x-c[0])+(c[0]-b[0])*(z-c[2]))/den
        v=((c[2]-a[2])*(x-c[0])+(a[0]-c[0])*(z-c[2]))/den;w=1-u-v
        if min(u,v,w)>=-1e-7:hits.append(u*a[1]+v*b[1]+w*c[1])
    return (max(hits) if front else min(hits)) if hits else None


def _seat_fittings(out,groups,model,anchor):
    """Seat existing assemblies on game skin, identically in baking masters.

    Move housings and apertures together, before fitting their guards. Supports
    retain each assembly's original owner; weapons and their aim stay fixed.
    """
    from tools.build_pc_tactical_vehicles import box,tube
    shape=model['shape_index'];s=.65 if shape==121 else 1
    def shift(names,axis,amount):
        for t in model['triangles']:
            if t['component'] in names:
                t['vertices']=[[v[k]+(amount if k==axis else 0) for k in range(3)] for v in t['vertices']]
    def stations(lo,hi):return (lo,(lo+hi)/2,hi)
    cast={115:'cast_turret_dome',117:'t64_compound_cast_turret',
          119:'t72_compound_cast_turret',121:'t80_compound_cast_turret',127:'m60_long_nose_cast_turret'}
    if shape in cast:
        skin={cast[shape]}
        if shape!=127:
            housing,lens=('infrared_searchlight_housing','infrared_searchlight_glass') if shape==115 else ('infrared_searchlight','infrared_lens')
            lo,hi=_component_bounds(anchor,{lens}).values()
            # Clear the complete aperture footprint, not only its centre ray.
            hits=[_skin_y(anchor,skin,x,z) for x in stations(lo[0],hi[0]) for z in stations(lo[2],hi[2])]
            delta=max(0,max(y for y in hits if y is not None)+.15*s-lo[1])
            shift({housing,lens},1,delta)
            a,b=_component_bounds(anchor,{housing}).values();x,z=(a[0]+b[0])/2,(a[2]+b[2])/2
            surface=_skin_y(anchor,skin,x,z);back=a[1]+delta
            if back>surface+.25*s:
                tube(out,groups[1],[x,surface-.2*s,z],[x,back+.2*s,z],.85*s,
                     'steel','refine_searchlight_mount_stem',6)
        optics=() if shape==115 else (('thermal_sight_housing','thermal_sight_aperture'),
              ('laser_rangefinder_housing','laser_rangefinder_aperture')) if shape==127 else (('gunner_day_sight','gunner_sight_aperture'),)
        for housing,lens in optics:
            lo,hi=_component_bounds(anchor,{lens}).values()
            top=max(_skin_z(anchor,skin,x,y) for x in stations(lo[0],hi[0]) for y in stations(lo[1],hi[1]))
            shift({housing,lens},2,max(0,top+.15*s-lo[2]))
        if shape in (117,119,121):
            lo,hi=_component_bounds(anchor,{'snorkel_stowage_tube'}).values()
            y,z=(lo[1]+hi[1])/2,(lo[2]+hi[2])/2;r=(hi[2]-lo[2])/2
            for x in (lo[0]*.52,hi[0]*.52):
                surface=_skin_y(anchor,skin,x,z,False)
                box(out,groups[1],[x-.55*s,min(y+r*.4,surface)-.2*s,z-.45*s],
                    [x+.55*s,max(y+r*.4,surface)+.2*s,z+.45*s],
                    'steel','refine_snorkel_stowage_stay')
                tube(out,groups[1],[x-.55*s,y,z],[x+.55*s,y,z],r+.18*s,
                     'olive_edge','refine_snorkel_retaining_band',8)
        if shape==127:
            # Lower end of the incumbent sloping M85 support, in its existing
            # narrowed turret coordinates. The gun itself is never translated.
            x,y=10*.72,12*.74;z=_skin_z(anchor,skin,x,y)
            tube(out,groups[3],[x,y,z-.2],[x,y,29.2],.8,'steel','refine_cupola_mount_foot',8)
    if shape in (129,131,139):
        part,skin={129:('commander_gun_mount',{'armoured_upper_hull_sloped_glacis'}),
                   131:('machinegun_pedestal',{'bradley_angular_turret'}),
                   139:('machinegun_pedestal',{'acrv_observation_cupola','observation_hatch'})}[shape]
        lo,hi=_component_bounds(anchor,{part}).values();x,y=(lo[0]+hi[0])/2,(lo[1]+hi[1])/2
        seat=_skin_z(anchor,skin,x,y)-.2
        for t in model['triangles']:
            if t['component']==part:
                t['vertices']=[[v[0],v[1],seat if abs(v[2]-lo[2])<1e-7 else v[2]] for v in t['vertices']]


def _guard_component(out,src,model,names,scale=1):
    from tools.build_pc_tactical_vehicles import tube
    b=_component_bounds(model,names);lo,hi=b['min'],b['max'];r=.3*scale
    x0,x1=lo[0]-r*1.8,hi[0]+r*1.8;y=hi[1]+r*1.4
    z0,z1=lo[2]+r,hi[2]+r*1.8
    for a,c in (([x0,y,z0],[x0,y,z1]),([x0,y,z1],[x1,y,z1]),([x1,y,z1],[x1,y,z0])):
        tube(out,src,a,c,r,'steel','refine_optical_housing_guard',6)


def _service_hardware(out,src,model,casework=False,frame=True):
    """Fit service hardware to existing solids, without new vehicle systems."""
    from tools.build_pc_tactical_vehicles import tube,box,bounds
    from tools.build_pc_modern_assets import MATERIALS
    if casework:
        # Each authored box is a closed twelve-triangle solid. Keep individual
        # lids separate: an aggregate bound would bridge unrelated side bins.
        for name in ('fender_stowage','long_fender_toolbox'):
            triangles=[t for t in model['triangles'] if t['component']==name]
            if len(triangles)%12:raise ValueError('Service case is not a closed box: '+name)
            for start in range(0,len(triangles),12):
                points=[v for t in triangles[start:start+12] for v in t['vertices']]
                lo,hi=bounds(points).values()
                if any(not all(abs(v[k]-lo[k])<1e-6 or abs(v[k]-hi[k])<1e-6 for k in range(3)) for v in points):
                    raise ValueError('Service case lost its rectangular anchor')
                box(out,src,[lo[0]+.12,lo[1]+.2,hi[2]+.04],
                    [hi[0]-.12,hi[1]-.2,hi[2]+.40],'olive_edge','refine_service_case_lid')
                width=hi[0]-lo[0];middle=(hi[0]+lo[0])/2
                for x in (lo[0]+width*.25,lo[0]+width*.75):
                    tube(out,src,[x-width*.08,lo[1]+.08,hi[2]+.03],
                         [x+width*.08,lo[1]+.08,hi[2]+.03],.22,'steel','refine_service_case_hinge',6)
                box(out,src,[middle-width*.07,hi[1]-.12,hi[2]-.85],
                    [middle+width*.07,hi[1]+.08,hi[2]+.25],'steel','refine_service_case_latch')
    grilles=[t for t in model['triangles'] if t['component']=='engine_deck_grille' or t['component'].startswith('engine_grille_')]
    if not grilles:raise ValueError('Missing authored engine grille anchor')
    lo,hi=bounds([v for t in grilles for v in t['vertices']]).values()
    # Painted raised slats over an actual dark bed read as open slots, rather
    # than dark bars lying on an uninterrupted green deck. Existing deck metal
    # supplies the M1 surround, keeping its complete model below the 8192 cap.
    for t in grilles:t['material']='olive_edge';t['color']=MATERIALS['olive_edge'][:]
    box(out,src,[lo[0],lo[1],lo[2]-.08],[hi[0],hi[1],lo[2]-.01],
        'vent','refine_recessed_engine_grille_bed')
    if frame:
        r=min(.45,(hi[2]-lo[2])*2)
        for a,b in (([lo[0]-r,lo[1]-r],[lo[0],hi[1]+r]),
                    ([hi[0],lo[1]-r],[hi[0]+r,hi[1]+r]),
                    ([lo[0],lo[1]-r],[hi[0],lo[1]]),
                    ([lo[0],hi[1]],[hi[0],hi[1]+r])):
            box(out,src,[*a,lo[2]-.02],[*b,hi[2]+.06],
                'olive_edge','refine_engine_grille_surround')


def _tank(out,groups,shape,model):
    from tools.build_pc_tactical_vehicles import box
    hull_names={'lower_hull_boat','upper_hull_sloped_glacis','sloped_glacis'}
    hb=_component_bounds(model,hull_names);w=hb['max'][0];y=hb['max'][1]-.8
    z=_skin_z(model,hull_names,w*.57,y)
    r=1.3 if shape in (121,125) else 1.8
    _tow_pair(out,groups[0],w*.57,y,z,r)
    turret_names={115:'cast_turret_dome',117:'t64_compound_cast_turret',
                  119:'t72_compound_cast_turret',121:'t80_compound_cast_turret',
                  125:'angular_turret_cheeks',127:'m60_long_nose_cast_turret'}
    names={turret_names[shape]};tb=_component_bounds(model,names)
    x=tb['max'][0]*.50;y=tb['min'][1]+(tb['max'][1]-tb['min'][1])*.30
    r=1 if shape in (121,125) else 1.4
    for side in (-1,1):
        z=_skin_z(model,names,side*x,y)
        box(out,groups[1],[side*x-r*.65,y-r*.38,z-.3],
            [side*x+r*.65,y+r*.38,z+.4],'olive_edge','refine_turret_lifting_foot')
        _eye(out,groups[1],[side*x,y,z+r*.7],r,'olive_edge','refine_turret_lifting_eye','y')
    # Guard each model's existing sight or searchlight, rather than inventing
    # a different optical system or borrowing coordinates from another tank.
    optic={115:{'infrared_searchlight_housing'},125:{'gunner_sight_housing'},
           127:{'thermal_sight_housing'}}.get(shape,{'gunner_day_sight'})
    _guard_component(out,groups[1],model,optic,.7 if shape==121 else 1)

def _carrier(out,groups,shape,model):
    from tools.build_pc_tactical_vehicles import tube,box
    names={'armoured_upper_hull_sloped_glacis'};hb=_component_bounds(model,names)
    width=hb['max'][0]/.84;front=hb['max'][1]-(2 if shape==139 else .8);rear=hb['min'][1]+.5
    roof=hb['max'][2];x=hb['max'][0]*.52;z=_skin_z(model,names,x,front)
    r=1.2 if width<35 else 1.6
    _tow_pair(out,groups[0],x,front,z,r)
    # Vision blocks sit on the actual driver-hatch coaming. Shallow housings
    # and glass apertures survive tactical scale without widening the hull.
    hatch=_component_bounds(model,{'driver_hatch'})
    hx=(hatch['min'][0]+hatch['max'][0])*.5
    hy=(hatch['min'][1]+hatch['max'][1])*.5
    radius=(hatch['max'][0]-hatch['min'][0])*.62
    for angle in (.35,1.05,1.75):
        xx=hx+radius*math.cos(angle);yy=hy+radius*math.sin(angle)
        box(out,groups[0],[xx-.95,yy-.7,roof+.05],[xx+.95,yy+.7,roof+1.15],
            'olive_edge','refine_driver_vision_coaming')
        box(out,groups[0],[xx-.65,yy+.705,roof+.42],[xx+.65,yy+.78,roof+.93],
            'optic','refine_driver_vision_glass')
    # Embarkation steps sit at the actual rear access threshold.
    door=_component_bounds(model,{'rear_ramp','rear_door'})
    # Hinge knuckles and a service latch attach to the existing rear panel,
    # rather than floating in a generic hull-relative position.
    for side in (-1,1):
        xx=side*(door['max'][0]-door['min'][0])*.35
        yy=door['min'][1]-.12
        for zz in (door['min'][2]+4,door['max'][2]-3):
            tube(out,groups[0],[xx-1.4,yy,zz],[xx+1.4,yy,zz],.40,
                 'olive_edge','refine_rear_hinge_knuckle',8)
    xx=door['max'][0]-2.1;yy=door['min'][1]-.18;zz=(door['min'][2]+door['max'][2])*.5
    box(out,groups[0],[xx-.45,yy-.2,zz-1.3],[xx+.45,yy+.2,zz+1.3],
        'equipment','refine_rear_service_latch')
    z=door['min'][2]+2
    # A rear embarkation step is functional structure on the ramp/door hull
    # owner. Its open U shape keeps access panels readable instead of obscured.
    for side in (-1,1):
        xx=side*width*.46
        a=[xx,rear+.5,z];b=[xx,rear-1.0,z-3]
        c=[xx-side*width*.16,rear-1.0,z-3];d=[xx-side*width*.16,rear+.5,z]
        for u,v in ((a,b),(b,c),(c,d)):
            tube(out,groups[0],u,v,.35,'steel','refine_rear_embarkation_step',6)
    if shape in (129,139):
        # Raised hatch/coaming rails are broad enough to survive gameplay views.
        for side in (-1,1):
            xx=side*width*.61;y=rear+24
            for a,b in (([xx,y,roof+.1],[xx,y,roof+2.3]),
                        ([xx,y,roof+2.3],[xx,y+16,roof+2.3]),
                        ([xx,y+16,roof+2.3],[xx,y+16,roof+.1])):
                tube(out,groups[0],a,b,.42,'steel','refine_roof_handhold',6)
    else:
        # The original small weapon turret owns its existing sight guard.
        gi=1 if shape==131 else 2
        _guard_component(out,groups[gi],model,{'turret_sight'},.7 if shape==135 else 1)


def _molot(out,groups):
    from tools.build_pc_tactical_vehicles import box,tube
    _tow_pair(out,groups[0],12,55,-8,1.0)
    box(out,groups[4],[-3.8,-15.5,8.85],[3.8,-13.5,9.2],
        'equipment','refine_fst_weapon_service_hinge')


def _wheeled(out,groups,shape,model):
    from tools.build_pc_tactical_vehicles import tube,box
    def wipers(screen,name):
        glass=_component_bounds(model,{screen});lo,hi=glass['min'],glass['max']
        y,z=lo[1],hi[2];dy,dz=hi[1]-lo[1],lo[2]-hi[2];width=hi[0]
        n=math.hypot(dy,dz);normal=[0,-dz/n,dy/n]
        def p(x,t,offset=.26):return [x,y+dy*t+normal[1]*offset,z+dz*t+normal[2]*offset]
        for side in (-1,1):
            tube(out,groups[0],p(side*3,.88),p(side*width*.67,.40),.20,'steel',name,6)
            tube(out,groups[0],p(side*width*.48,.20,.30),p(side*width*.85,.57,.30),.22,'tyre',name+'_blade',6)
    if shape==137:
        _tow_pair(out,groups[0],12,59.7,1,1.2)
        _tow_pair(out,groups[0],12,-66.5,5,1.2,True)
        # Broad crew screens get actual wiper linkages on their sloping plane.
        wipers('btr_crew_windscreen','refine_btr_windscreen_wiper')
        # Rear amphibious-hull boarding grips, well clear of turret owners.
        for side in (-1,1):
            x=side*16
            for a,b in (([x,-61,12],[x,-61,15]),([x,-61,15],[x,-48,15]),([x,-48,15],[x,-48,12])):
                tube(out,groups[0],a,b,.35,'steel','refine_btr_rear_grip',6)
    elif shape in (141,143):
        _tow_pair(out,groups[0],13,91.4,-4,1.5)
        _tow_pair(out,groups[0],13,-81.4,-5,1.5,True)
        wipers('brdm_broad_crew_windscreen','refine_brdm_windscreen_wiper')
        for side in (-1,1):
            # Side access handhold follows the raised shoulder, rather than
            # moving with independently observed wheels or source roof rails.
            x=side*26.2
            for a,b in (([x,-10,18],[x,-10,22]),([x,-10,22],[x,6,22]),([x,6,22],[x,6,18])):
                tube(out,groups[0],a,b,.4,'steel','refine_brdm_access_grip',6)
    else:
        _tow_pair(out,groups[0],24,107.5,-14,1.05)
        # Tailgate hinges belong to the tailgate's independent original group3.
        for x in (-25,25):
            tube(out,groups[3],[x-3,-79.1,1.4],[x+3,-79.1,1.4],.65,'steel','refine_truck_tailgate_hinge',10)
            box(out,groups[3],[x-2,-79.75,1.4],[x+2,-79.1,5],
                'olive_edge','refine_truck_tailgate_hinge_leaf')
        # Short bent underbody diesel exhaust, with an open dark outlet.
        tube(out,groups[0],[25,40,-12],[25,14,-12],1.0,'steel','refine_truck_exhaust_pipe',10)
        tube(out,groups[0],[25,14,-12],[34,9,-12],1.0,'steel','refine_truck_exhaust_tailpipe',10,open_end=True)
        tube(out,groups[0],[33.1,9.5,-12],[33.4,9.3,-12],.65,'vent','refine_truck_exhaust_bore',10)


def _hind(out,groups):
    from tools.build_pc_tactical_vehicles import tube,box
    # Rolled heat shields and intake reinforcement collars stay on dorsal
    # owner5, with no rotor volume or changes to the retracted undercarriage.
    for side in (-1,1):
        x=side*37
        tube(out,groups[5],[x,-77,91],[x,-80,91],11.2,'steel','refine_hind_exhaust_heat_shield',20,tip=11.7,open_end=True)
        tube(out,groups[5],[x,73.4,94],[x,75.3,94],14.4,'hind_olive','refine_hind_intake_collar',20,tip=14.1,open_end=True)
        # A raised, shallow service latch attaches to each nacelle access skin.
        box(out,groups[5],[x-2,-26,111],[x+2,-22,112.2],
            'steel','refine_hind_nacelle_service_latch')
    # Nose light guard surrounds the existing aperture, rather than inventing
    # an extended gear/light state or a new gun emplacement.
    for x in (-6.7,6.7):
        tube(out,groups[0],[x,278,-11],[x,278,-2],.55,'hind_olive','refine_hind_nose_aperture_guard',6)
    tube(out,groups[0],[-6.7,278,-2],[6.7,278,-2],.55,'hind_olive','refine_hind_nose_aperture_guard',6)


def _wreck(out,groups,shape):
    from tools.pc_tactical_wrecks import FAMILY_KEYS
    from tools.build_pc_tactical_vehicles import solid,tube,box
    family=FAMILY_KEYS[shape];src=groups[0]
    truck=family=='truck6';y=48 if truck else -43
    # Exposed gearbox, output shaft and broken crossmember are a connected
    # drivetrain remnant visible through the existing open engine/crew bays.
    box(out,src,[-7,y-4,-22],[7,y+5,-17.8],'burnt','refine_wreck_transmission_case')
    end=y-23 if truck else y+24
    tube(out,src,[0,y,-21],[0,end,-23],1.5,'rust','refine_wreck_output_shaft',10)
    tube(out,src,[-23,end,-23],[22,end+2,-22],1.0,'exposed','refine_wreck_crossmember',10)
    # Torn radiator has a coherent buckled surround and surviving tilted fins.
    # Different family construction keeps the same source-alias equivalence.
    width=12 if family in ('brdm4','truck6') else 15
    ry=y+(8 if truck else -10)
    lower=[[-width,ry,-23],[width,ry,-23],[width-2,ry+1,-15],[-width+3,ry-1,-13]]
    upper=[[x,yy+.7,z] for x,yy,z in lower]
    solid(out,src,[lower,upper],'rust','refine_wreck_buckled_radiator_frame')
    for i in range(5):
        x=-width+4+i*(width*2-8)/4
        tube(out,src,[x,ry+1,-22],[x+.8,ry+.8,-14.5],.38,'exposed','refine_wreck_radiator_fin',6)
    # One torn structural flange exposes its folded, irregular edge. It is a
    # connected part of the chassis, not a scatter of unrelated debris cubes.
    xx=-24 if not truck else 20
    points=[[xx,end-8,-24],[xx+4,end-6,-16],[xx+2,end+1,-18],
            [xx+5,end+8,-15],[xx+1,end+10,-24]]
    solid(out,src,[points,[[x+.7,yy,z] for x,yy,z in points]],
          'exposed','refine_wreck_torn_chassis_flange')


def refine(model,master=False):
    """Return a refined copy; colour new authored materials, then validate.

    Calling once per fresh build is intentional. This is an authoring stage,
    never a runtime mutation, and does not change any original source metadata.
    """
    from tools.build_pc_tactical_vehicles import source_groups,bounds,validate_model,build_geometry
    from tools.build_pc_modern_assets import MATERIALS
    shape=model['shape_index'];groups=source_groups(model);out=[]
    if shape in (115,117,119,121,127,129,131,139):
        anchor=build_geometry(model,False) if master else model
        model=copy.deepcopy(model)
        _seat_fittings(out,groups,model,anchor)
    if shape in (115,117,119,121,125,127):_tank(out,groups,shape,model)
    elif shape in (129,131,133,135,139):_carrier(out,groups,shape,model)
    elif shape==123:_molot(out,groups)
    elif shape in (137,141,143,159):_wheeled(out,groups,shape,model)
    elif shape in (163,164):_hind(out,groups)
    else:
        from tools.pc_tactical_wrecks import FAMILY_KEYS
        if shape not in FAMILY_KEYS:raise ValueError(f'Unsupported Tactical refinement shape {shape}')
        _wreck(out,groups,shape)
    result=copy.deepcopy(model)
    if shape in (115,117,119,121,125,127,129,131,139):
        _service_hardware(out,groups[0],result,shape in (115,117,119,121,127),shape!=125)
    for tri in out:tri['color']=MATERIALS[tri['material']][:]
    result['triangles'].extend(out)
    result['bounds']=bounds([v for t in result['triangles'] for v in t['vertices']])
    validate_model(result)
    if not master and len(result['triangles'])>8192:
        raise ValueError(f'Tactical refinement runtime triangle cap: {shape} has {len(result["triangles"])}')
    return result
