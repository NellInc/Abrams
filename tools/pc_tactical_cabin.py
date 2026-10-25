"""Source-attributed cottage for Tactical shape 147, authored in raw units.

The original five planes remain pose/visibility anchors. All new construction
stays inside their immutable 128-unit cube; original gameplay owns that cube.
"""
import copy
import math
from tools.build_pc_modern_assets import MATERIALS, add_face, bounds, validate_model, cross, sub, dot
from tools.build_pc_tactical_vehicles import box, emit, tube

# Role, authored sRGB, optional finish override. Individual clay/stone pieces
# already have geometry, so they must not acquire a second procedural tile grid.
FINISHES = {
    'cabin_render': ('plaster', (201, 191, 164), None),
    'cabin_render_edge': ('plaster', (188, 180, 155), None),
    'cabin_mortar': ('stone_edge', (119, 115, 101), None),
    'cabin_frame': ('door', (177, 177, 156), None),
    'cabin_sash': ('door', (161, 165, 148), None),
    'cabin_sill': ('stone_edge', (170, 166, 145), None),
    'cabin_wood': ('timber', (91, 80, 61), None),
    'cabin_door': ('door', (82, 99, 91), None),
    'cabin_glass': ('glass', (48, 64, 67), None),
    'cabin_glass_sky': ('glass', (76, 93, 95), None),
    'cabin_void': ('vent', (35, 39, 36), None),
    'cabin_zinc': ('steel', (100, 111, 109), None),
    'cabin_hardware': ('steel', (111, 106, 82), None),
    'cabin_brick': ('stone_edge', (145,101,77), ('stone',.93,0.,.00045)),
}
for i, rgb in enumerate(((137,82,59),(148,91,65),(155,96,68),(143,88,62),(160,101,73))):
    FINISHES[f'cabin_tile_{i}']=('roof_clay',rgb,('ceramic',.83,0.,.00022))
for i,rgb in enumerate(((119,114,99),(137,130,111),(128,123,105),(146,137,116))):
    FINISHES[f'cabin_stone_{i}']=('stone_edge',rgb,('stone',.93,0.,.00045))
MATERIALS.update({name:list(spec[1]) for name,spec in FINISHES.items()})


def geometry(base, master=False):
    if base['shape_index']!=147:raise ValueError('Cottage recipe is shape 147 only')
    model=copy.deepcopy(base);out=[]
    sources={p['id']:dict(p,groups=[g['offset'] for g in base['groups'] if p['id'] in g['primitive_pointers']]) for p in base['source_primitives']}
    roof=sources[25908]

    def face(points,mat,part,source,inside=(0,0,55)):
        emit(out,[source],points,mat,part,inside)

    def roofpoint(side,u,y,lift=0):
        return [side*u,y,125.3-40.3*u/63+lift]

    # A real deck, with two separate pitched planes and dark timber edges.
    for side in (-1,1):
        face([roofpoint(side,0,-63,-.45),roofpoint(side,63,-63,-.45),
              roofpoint(side,63,63,-.45),roofpoint(side,0,63,-.45)],'cabin_wood','cabin_roof_deck',roof)
        # Overlapping, gently crowned individual clay tiles. High masters use
        # a denser cross section, while the game mesh retains actual tile lips.
        for row in range(8):
            u0=max(0,row*63/8-.65);u1=(row+1)*63/8
            shift=(row%2)*3.9375
            for col in range(-1,17):
                y0=max(-62.8,-62.8+col*7.85+shift+.10)
                y1=min(62.8,-62.8+(col+1)*7.85+shift-.10)
                if y1-y0<.5:continue
                mat=f'cabin_tile_{(row*7+col*3+(1 if side>0 else 0))%5}'
                n=4 if master else 2
                edge=[];lift=.10+row*.07+.035*math.sin(row*9.7+col*5.3)
                for j in range(n+1):
                    y=y0+(y1-y0)*j/n
                    crown=.36*math.sin(math.pi*j/n)
                    edge.append([roofpoint(side,u0,y,lift+crown),roofpoint(side,u1,y,lift+crown)])
                for j in range(n):
                    a,b=edge[j];c,d=edge[j+1]
                    face([a,b,d,c],mat,'cabin_clay_tile',roof)
                    # Down-slope leading lip casts an actual contact shadow.
                    face([b,[b[0],b[1],b[2]-.35],[d[0],d[1],d[2]-.35],d],mat,'cabin_tile_lip',roof)
                for j in (0,n):
                    a,b=edge[j]
                    face([a,[a[0],a[1],a[2]-.25],[b[0],b[1],b[2]-.25],b],mat,'cabin_tile_edge',roof)
    # Segmented ridge caps have a curved profile and physical overlap.
    for col in range(16):
        y0=-63+col*7.875;y1=min(63,y0+8.25)
        profile=[(-3.3,123.9),(-1.8,126.1),(0,127.25),(1.8,126.1),(3.3,123.9)]
        for a,b in zip(profile,profile[1:]):
            face([[a[0],y0,a[1]],[b[0],y0,b[1]],[b[0],y1,b[1]],[a[0],y1,a[1]]],f'cabin_tile_{col%5}','cabin_ridge_cap',roof)

    # Each wall owns only its original source primitive. Removing rectangles
    # from the wall gives real reveals; glazing never floats over solid plaster.
    for pid,normal in ((25884,(1,0)),(25892,(0,1)),(25900,(0,-1)),(25916,(-1,0))):
        src=sources[pid];nx,ny=normal;hx,hy=-ny,nx
        def p(u,z,d=0):return [nx*(59+d)+hx*u,ny*(59+d)+hy*u,z]
        def panel(u0,z0,u1,z1,d,mat,part):
            face([p(u0,z0,d),p(u1,z0,d),p(u1,z1,d),p(u0,z1,d)],mat,part,src)
        def block(u0,z0,u1,z1,d0,d1,mat,part):
            points=[p(u,z,d) for u in (u0,u1) for z in (z0,z1) for d in (d0,d1)]
            box(out,[src],[min(q[k] for q in points) for k in range(3)],
                [max(q[k] for q in points) for k in range(3)],mat,part)
        holes=[(-48,41,-22,71),(22,41,48,71)]
        entrance=normal==(0,-1)
        if entrance:holes.append((-12,10,12,74))
        us=sorted({-59,59,*[h[i] for h in holes for i in (0,2)]})
        zs=sorted({10,84,*[h[i] for h in holes for i in (1,3)]})
        for u0,u1 in zip(us,us[1:]):
            for z0,z1 in zip(zs,zs[1:]):
                u,z=(u0+u1)/2,(z0+z1)/2
                if any(a<u<b and c<z<d for a,c,b,d in holes):continue
                panel(u0,z0,u1,z1,0,'cabin_render','cabin_wall')
        # Solid gable end, below the roof; a small opaque louvred attic vent.
        if ny:
            face([p(-59,84),p(59,84),p(0,122.9)],'cabin_render','cabin_gable',src)
            panel(-5,100,5,110,.08,'cabin_void','cabin_attic_vent_back')
            for z in (101,103.5,106,108.5):block(-5,z,5,z+.8,.1,.7,'cabin_wood','cabin_attic_louvre')
        # Recessed two-course masonry base with quiet, varied stones and joints.
        panel(-59,0,59,10,.05,'cabin_mortar','cabin_foundation_mortar')
        for row in range(2):
            offset=5.4*(row%2)
            for j in range(-1,12):
                a=max(-59,-59+j*10.8+offset+.18);b=min(59,-59+(j+1)*10.8+offset-.18)
                if b-a<.6:continue
                if entrance and a<12 and b>-12:continue
                block(a,row*5+.25,b,row*5+4.75,.1,.8,f'cabin_stone_{(j+row+pid)%4}','cabin_foundation_stone')
        for number,(u0,z0,u1,z1) in enumerate(holes[:2]):
            # Four deep jambs, in the actual opening, with a recessed sash.
            cavity=p((u0+u1)/2,(z0+z1)/2,-1.6)
            for a,b in (((u0,z0),(u1,z0)),((u1,z0),(u1,z1)),((u1,z1),(u0,z1)),((u0,z1),(u0,z0))):
                points=[p(*a),p(*b),p(*b,-3.2),p(*a,-3.2)]
                centre=[sum(q[k] for q in points)/4 for k in range(3)]
                if dot(cross(sub(points[1],points[0]),sub(points[2],points[0])),sub(cavity,centre))<0:points.reverse()
                face(points,'cabin_sill','cabin_window_reveal',src,inside=None)
            for a,c,b,d in ((u0,z0,u0+1.7,z1),(u1-1.7,z0,u1,z1),
                             (u0,z0,u1,z0+1.7),(u0,z1-1.7,u1,z1)):
                block(a,c,b,d,-1.1,.6,'cabin_frame','cabin_window_frame')
            mid=(u0+u1)/2;transom=61.5
            block(mid-.65,z0+1.7,mid+.65,z1-1.7,-2.7,-1.1,'cabin_sash','cabin_window_mullion')
            block(u0+1.7,transom-.6,u1-1.7,transom+.6,-2.7,-1.1,'cabin_sash','cabin_window_transom')
            for a,b in ((u0+1.7,mid-.65),(mid+.65,u1-1.7)):
                panel(a,z0+1.7,b,transom-.6,-3.15,'cabin_glass','cabin_recessed_glazing')
                panel(a,transom+.6,b,z1-1.7,-3.15,'cabin_glass_sky','cabin_recessed_glazing')
            block(u0-2.4,z0-1.8,u1+2.4,z0-.25,-.5,2.0,'cabin_sill','cabin_projecting_sill')
            # Thin drip groove underneath, not a giant decorative surround.
            block(u0-1.8,z0-1.85,u1+1.8,z0-1.6,1.2,1.5,'cabin_void','cabin_sill_drip')
            block(u0-1.1,z1+.3,u1+1.1,z1+2.0,-.05,.35,'cabin_render_edge','cabin_lintel')
        if entrance:
            panel(-12,10,12,74,-2.0,'cabin_void','cabin_door_reveal')
            for u in (-12,10.3):block(u,10,u+1.7,74,-1.9,.6,'cabin_frame','cabin_door_jamb')
            block(-12,72.3,12,74,-1.9,.6,'cabin_frame','cabin_door_header')
            # A continuous leaf with four broad panels survives atlas mips.
            # Separate thin plank islands alias into a perforated grille.
            block(-10.2,10.8,10.2,72.1,-1.8,-1.2,'cabin_door','cabin_door_leaf')
            for a,b in ((-10.2,-8.4),(8.4,10.2),(-.8,.8)):
                block(a,10.8,b,72.1,-1.2,-.7,'cabin_door','cabin_door_stile')
            for z in (11.0,40.2,70.3):
                block(-10.2,z,10.2,z+1.7,-1.2,-.7,'cabin_door','cabin_door_rail')
            for a,b in ((-8.4,-.8),(.8,8.4)):
                for c,d in ((12.7,40.2),(41.9,70.3)):
                    block(a+.25,c+.3,b-.25,d-.3,-1.2,-1.0,'cabin_door','cabin_door_panel')
            block(6.7,37,7.8,44,-.8,-.2,'cabin_hardware','cabin_door_latch')
            block(4.8,40.7,7.8,41.5,-.3,.9,'cabin_hardware','cabin_door_handle')
            for z in (22,62):block(-10.3,z,-7,z+.9,-1.1,-.5,'cabin_hardware','cabin_door_hinge')
            block(-15,0,15,3,.2,4.5,'cabin_sill','cabin_lower_step')
            block(-13,3,13,7,.2,2.8,'cabin_sill','cabin_upper_step')
        if nx:
            # Eaves/fascia, half-round metal rain gutter and original-bounded pipe.
            block(-62.8,82.3,62.8,85.2,2.4,4.2,'cabin_wood','cabin_eave_fascia')
            tube(out,[src],p(-62,83.4,3.4),p(62,83.4,3.4),.55,'cabin_zinc','cabin_gutter',12 if master else 8)
            u=53
            for a,b in ((p(u,82.8,3.3),p(u,79.7,2.2)),(p(u,79.7,2.2),p(u,11,1.4)),(p(u,11,1.4),p(u,8,2.6))):
                tube(out,[src],a,b,.48,'cabin_zinc','cabin_downpipe',12 if master else 8)
            for z in (22,52,77):block(u-.8,z-.35,u+.8,z+.35,.5,2.0,'cabin_zinc','cabin_pipe_bracket')
        if ny:
            # Real bargeboards follow the two roof slopes, with plank thickness.
            for side in (-1,1):
                a,b=(-63*side,84),(0,125.3)
                pts=[p(a[0],a[1]-1,2.8),p(b[0],b[1]-1,2.8),p(b[0],b[1]+.3,2.8),p(a[0],a[1]+.3,2.8)]
                face(pts,'cabin_wood','cabin_bargeboard',src)
    # A small coursed chimney rises from the lower roof pitch, entirely below
    # the original128-unit roof bound. The metal apron follows that pitch;
    # coping and a recessed dark flue give the stack an actual hollow mouth.
    box(out,[roof],[30.3,19.3,103.0],[41.7,30.7,120.8],'cabin_mortar','cabin_chimney_core')
    for row in range(5):
        z=103.4+row*3.6
        for axis,fixed in ((0,30.1),(0,41.9),(1,19.1),(1,30.9)):
            for j in range(2):
                a=19.4+j*5.4 if axis==0 else 30.4+j*5.4
                lo=[a,fixed,z] if axis else [fixed,a,z]
                hi=[a+5.0,fixed+.35,z+3.1] if axis else [fixed+.35,a+5.0,z+3.1]
                box(out,[roof],lo,hi,'cabin_brick','cabin_chimney_brick')
    for a,b in (((29.2,18.2,121.4),(42.8,21.2,124.0)),((29.2,28.8,121.4),(42.8,31.8,124.0)),
                ((29.2,21.2,121.4),(32.2,28.8,124.0)),((39.8,21.2,121.4),(42.8,28.8,124.0))):
        box(out,[roof],a,b,'cabin_stone_2','cabin_chimney_coping')
    face([[32.3,21.3,121.3],[39.7,21.3,121.3],[39.7,28.7,121.3],[32.3,28.7,121.3]],
         'cabin_void','cabin_recessed_flue',roof)
    for y0,y1 in ((17.5,20.0),(30.0,32.5)):
        face([[28.5,y0,125.3-40.3*28.5/63+.45],[43.5,y0,125.3-40.3*43.5/63+.45],
              [43.5,y1,125.3-40.3*43.5/63+.45],[28.5,y1,125.3-40.3*28.5/63+.45]],
             'cabin_zinc','cabin_chimney_apron',roof)
    model['triangles']=out;model['source_passthrough']=[]
    model['bounds']=bounds([v for t in out for v in t['vertices']])
    validate_model(model)
    lo,hi=base['source_bounds']['min'],base['source_bounds']['max']
    if not master and len(out)>8192:raise ValueError('Cottage runtime triangle allowance')
    if any(not lo[k]<=v[k]<=hi[k] for t in out for v in t['vertices'] for k in range(3)):
        raise ValueError('Cottage exceeds immutable source envelope')
    return model
