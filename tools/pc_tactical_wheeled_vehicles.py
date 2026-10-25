"""Source-group-owned Tactical wheeled silhouettes, in raw source coordinates.

Family references and source-equipment limitations are in wheeled-notes.md.
This module supplies geometry only; it never changes game logic or source assets.
"""
import math
from tools.build_pc_modern_assets import MATERIALS

FINISHES = {
    'truck_headlamp_glass': ('lamp',(215,211,174),('optic',.22,0.,0.)),
    'truck_stop_glass': ('lamp',(150,29,19),('optic',.24,0.,0.)),
    'truck_indicator_glass': ('lamp',(207,121,25),('optic',.24,0.,0.)),
    'truck_crate_wood': ('timber',(111,91,60),None),
}
MATERIALS.update({name:list(spec[1]) for name,spec in FINISHES.items()})


def _side_skin_x(triangles,names,y,z,side):
    """Intersect the actual side skin, including its tapered triangular facets."""
    hits=[]
    for t in triangles:
        if t['component'] not in names:continue
        a,b,c=t['vertices'];den=(b[2]-c[2])*(a[1]-c[1])+(c[1]-b[1])*(a[2]-c[2])
        if abs(den)<1e-9:continue
        u=((b[2]-c[2])*(y-c[1])+(c[1]-b[1])*(z-c[2]))/den
        v=((c[2]-a[2])*(y-c[1])+(a[1]-c[1])*(z-c[2]))/den;w=1-u-v
        if min(u,v,w)>=-1e-7:hits.append(u*a[0]+v*b[0]+w*c[0])
    if not hits:raise ValueError(f'Side fitting missed skin at {y,z}')
    return max(hits) if side>0 else min(hits)


def geometry(base, master=False):
    from tools.build_pc_tactical_vehicles import source_groups, emit, solid, box, tube, hatch
    out = []
    wheel_centres = {}
    groups = source_groups(base)
    shape = base['shape_index']
    if shape==159:
        from tools.build_pc_tactical_vehicles import TACTICAL_PALETTE
        TACTICAL_PALETTE.update({name:list(spec[1]) for name,spec in FINISHES.items()})
    if shape not in (137, 141, 143, 159):
        raise ValueError(f'Unsupported wheeled Tactical shape: {shape}')

    def plate(g, points, material, name):
        emit(out, groups[g], points, material, name)

    def side_plate(g,side,yzs,skin,material,name):
        from tools.build_pc_modern_assets import cross,sub
        names={skin} if isinstance(skin,str) else skin
        points=[[_side_skin_x(out,names,y,z,side)+side*.10,y,z] for y,z in yzs]
        if cross(sub(points[1],points[0]),sub(points[2],points[0]))[0]*side<0:points.reverse()
        plate(g,points,material,name)

    def block(g, lo, hi, material, name):
        box(out, groups[g], lo, hi, material, name)

    def pipe(g, a, b, r, material, name, segments=12, tip=None):
        tube(out, groups[g], a, b, r, material, name, segments, tip=tip)

    def loft(g, rings, material, name,cap_end=True):
        solid(out, groups[g], rings, material, name,cap_end=cap_end)

    def wheel(g, side, y, z, radius, inner, outer, name):
        if shape == 159:
            truck_wheel(g,side,y,z,radius,outer,name)
            return
        # Rounded shoulder: five rings, so the tyre has volume and the rim is
        # visibly recessed. The tread is actual master geometry for the bake.
        wheel_centres[name]=y
        n = 64 if master else 48
        rings = []
        crown=.965 if master else 1.
        shoulder=.945 if master else .98
        for x, r in ((inner, radius*.82), (inner+1.2, radius*shoulder),
                     ((inner+outer)*.5, radius*crown), (outer-1.2, radius*shoulder),
                     (outer, radius*.82)):
            rings.append([[side*x, y+r*math.cos(j*math.tau/n), z+r*math.sin(j*math.tau/n)] for j in range(n)])
        loft(g, rings, 'tyre', name+'_tyre')
        pipe(g,[side*(outer-.4),y,z],[side*(outer+.1),y,z],radius*.57,'wheel',name+'_rim',24 if master else 16)
        pipe(g,[side*(outer+.1),y,z],[side*(outer+.65),y,z],radius*.26,'hub',name+'_hub',16 if master else 12)
        lug_count=6
        for j in range(lug_count):
            t=j*math.tau/lug_count
            yy=y+radius*.39*math.cos(t); zz=z+radius*.39*math.sin(t)
            pipe(g,[side*(outer+.12),yy,zz],[side*(outer+.31),yy,zz],radius*.045,'steel',name+'_lug',6)
        if master:
            # Broad staggered rubber lugs, with real channels between them.
            # All crowns stay within the existing tyre radius. Unlike narrow
            # metallic tubes these bake as continuous chevrons, not bright dots.
            middle=(inner+outer)*.5
            def treadpoint(x,t,r):return [side*x,y+r*math.cos(t),z+r*math.sin(t)]
            for j in range(24):
                for half in (-1,1):
                    t=(j+(0.15 if half<0 else 0))*math.tau/24
                    x0=middle+half*.3;x1=middle+half*((outer-inner)*.5-1.7)
                    path=((x0,t-.075,radius*.999),(x1,t-.14,radius*.954),
                          (x1,t+.01,radius*.954),(x0,t+.075,radius*.999))
                    loft(g,[[treadpoint(x,a,r-depth) for x,a,r in path] for depth in (.45,0)],
                         'tyre',name+'_rubber_chevron_tread')

    def truck_wheel(g,side,y,z,radius,outer,name):
        # Real annular rubber leaves the wheel dish exposed. Working if the
        # outer bead surrounds a recessed rim instead of a rubber end cap.
        front=name.endswith('_2')
        spans=[(outer-8.3,outer,name)]
        if not front:spans.append((outer-17.4,outer-9.1,name+'_inner'))
        for inner,edge,label in spans:
            n=48 if master else (12 if label.endswith('_inner') else 24)
            middle=(inner+edge)*.5
            profile=((inner,.59),(inner+.6,.93),(middle,.975 if master else 1.),
                     (edge-.6,.93),(edge,.59))
            rings=[[[side*x,y+radius*r*math.cos(j*math.tau/n),z+radius*r*math.sin(j*math.tau/n)]
                    for j in range(n)] for x,r in profile]
            for a,b in zip(rings,rings[1:]+rings[:1]):
                for j in range(n):
                    k=(j+1)%n;t=(j+.5)*math.tau/n
                    inside=[side*middle,y+radius*.80*math.cos(t),z+radius*.80*math.sin(t)]
                    emit(out,groups[g],[a[j],a[k],b[k],b[j]],'tyre',label+'_tyre',inside)
            if master:
                def treadpoint(x,t,r):return [side*x,y+r*math.cos(t),z+r*math.sin(t)]
                for j in range(24):
                    for half in (-1,1):
                        t=(j+(.15 if half<0 else 0))*math.tau/24
                        x0=middle+half*.2;x1=middle+half*((edge-inner)*.5-.7)
                        path=((x0,t-.075,radius*.999),(x1,t-.14,radius*.945),
                              (x1,t+.01,radius*.945),(x0,t+.075,radius*.999))
                        loft(g,[[treadpoint(x,a,r-d) for x,a,r in path] for d in (.38,0)],
                             'tyre',label+'_rubber_chevron_tread')
        depth=1.25 if front else 3.1
        n=32 if master else 24
        rings=[[[side*x,y+radius*r*math.cos(j*math.tau/n),z+radius*r*math.sin(j*math.tau/n)]
                for j in range(n)] for x,r in ((outer+.12,.605),(outer+.12,.54),(outer-depth,.48))]
        solid(out,groups[g],rings,'wheel',name+'_rim',cap_start=False,cap_end=False)
        # Six punched ventilation openings and six nuts surround a seated hub.
        # Working if front spindle and deeper rear dish have different profiles.
        rise=.8 if front else .45
        def dishpoint(r,t,back=0):
            xx=outer-depth+rise*(.48-r)/.26-back
            return [side*xx,y+radius*r*math.cos(t),z+radius*r*math.sin(t)]
        for sector in range(6):
            angles=[(sector*60+a)*math.pi/180 for a in (-30,-12,12,30)]
            radii=(.22,.30,.43,.48)
            for row in range(3):
                for col in range(3):
                    if row==1 and col==1:continue
                    points=[dishpoint(radii[row],angles[col]),dishpoint(radii[row+1],angles[col]),
                            dishpoint(radii[row+1],angles[col+1]),dishpoint(radii[row],angles[col+1])]
                    emit(out,groups[g],points,'wheel',name+'_vented_dish',[side*(outer-depth-2),y,z])
            hole=[(.30,angles[1]),(.43,angles[1]),(.43,angles[2]),(.30,angles[2])]
            for a,b in zip(hole,hole[1:]+hole[:1]):
                emit(out,groups[g],[dishpoint(*a),dishpoint(*b),dishpoint(*b,.5),dishpoint(*a,.5)],
                     'wheel',name+'_vent_return')
            t=sector*math.tau/6
            yy=y+radius*.265*math.cos(t);zz=z+radius*.265*math.sin(t)
            xx=outer-depth+rise*(.48-.265)/.26
            pipe(g,[side*(xx+.02),yy,zz],[side*(xx+.32),yy,zz],radius*.04,'steel',name+'_lug',6)
        root=outer-depth+rise-.12;tip=outer+.65 if front else root+.65
        pipe(g,[side*root,y,z],[side*tip,y,z],radius*.22,'hub',name+'_hub',10,tip=radius*.18)

    def lights(g, width, y, z, radius=2):
        from tools.pc_tactical_vehicle_refinement import _skin_z
        skin={'btr_compound_bow' if shape==137 else 'brdm_compound_boat_hull'}
        for side in (-1,1):
            x=side*width
            top=max(_skin_z({'triangles':out},skin,xx,yy)
                    for xx in (x-radius*1.2,x,x+radius*1.2) for yy in (y-.6,y,y+.3))
            centre=max(z,top+radius*1.2+.12)
            # The complete aperture clears the bow; a short foot contacts the
            # actual armour below the housing instead of leaving it suspended.
            block(g,[x-radius*.3,y-.5,top-.2],[x+radius*.3,y-.1,centre-radius*1.2+.15],
                  'steel','headlight_mount_foot')
            pipe(g,[x,y-.6,centre],[x,y,centre],radius*1.2,'steel','headlight_housing',16)
            pipe(g,[x,y,centre],[x,y+.3,centre],radius,'lamp','headlight_lens',16)
            for dx in (-radius*1.35,radius*1.35):
                pipe(g,[x+dx,y+.35,centre-radius],[x+dx,y+.35,centre+radius*1.3],.28,'steel','lamp_guard',6)
            pipe(g,[x-radius*1.35,y+.35,centre+radius*1.3],[x+radius*1.35,y+.35,centre+radius*1.3],.28,'steel','lamp_guard',6)

    if shape == 137:
        # Eight wheels in paired axles, with the characteristic central gap.
        # Their diameter is restricted by the source's unusually shallow bounds.
        for side in (-1,1):
            for i,y in enumerate((-61,-36,18,43)):
                wheel(0,side,y,-1,10.8,21.5,29.2,f'btr_{side}_axle_{i}')
        loft(0,[[[-18,-79,-6],[18,-79,-6],[18,57,-6],[-18,57,-6]],
                [[-25,-82,7],[25,-82,7],[26,57,7],[-26,57,7]],
                [[-23,-61,15],[23,-61,15],[24,38,15],[-24,38,15]]], 'olive','btr_boat_armour')
        # Compound truncated bow, with thickness below the forward deck.
        loft(0,[[[-23,38,-5],[23,38,-5],[24,38,12],[-24,38,12]],
                [[-21,60,-3],[21,60,-3],[22,60,9],[-22,60,9]],
                [[-18,74,0],[18,74,0],[20,74,4],[-20,74,4]]],
             'olive','btr_compound_bow')
        loft(0,[[[-24,28,10],[24,28,10],[24,61,10],[-24,61,10]],
                [[-21,30,18],[21,30,18],[21,43,18],[-21,43,18]]],
             'olive','btr_raised_crew_wedge')
        for x0,x1 in ((-18,-1.5),(1.5,18)):
            plate(0,[[x0,46.75,16.4],[x1,46.75,16.4],[x1,57.55,11.6],[x0,57.55,11.6]],
                  'optic','btr_crew_windscreen')
            plate(0,[[x0-.5,46.6,16.6],[x1+.5,46.6,16.6],[x1+.5,43.4,18],[x0-.5,43.4,18]],
                  'hatch','btr_window_shutter')
            tube(out,groups[0],[x0,57.8,11.5],[x1,57.8,11.5],.3,'olive_edge','btr_window_sill',8)
        plate(0,[[-19,65,7.8],[19,65,7.8],[18,70,6],[-18,70,6]],'hatch','btr_folded_trim_vane')
        for side in (-1,1):
            # Long fender strips and triangular central troop doors.
            lo,hi=sorted((side*22,side*29.5))
            block(0,[lo,-77,9],[hi,56,10],'olive_edge','btr_fender')
            side_plate(0,side,[(-17,7),(5,7),(1,14),(-10,14)],'btr_boat_armour','hatch','btr_triangular_door')
            for y in (-43,-25,-7):
                pipe(0,[side*24.5,y,12],[side*25,y,12],1,'steel','btr_firing_port',10)
            for y in (-48,-29,-9):
                block(0,[min(side*23.3,side*24.1),y,14.7],[max(side*23.3,side*24.1),y+4,15.4],'optic','btr_vision_block')
        for x in (-11,11):
            hatch(out,groups[0],x,-20,15,5,master,'btr_roof_hatch')
        for i in range(12):
            block(0,[-15,-75+i*1.1,11.6],[15,-74.5+i*1.1,12.0],'vent','btr_engine_louvre')
        lights(0,20,62,8,1.2)
        pipe(0,[0,-82,2],[0,-83,2],7,'vent','btr_waterjet',20)
        # Turret alone belongs to original filled group 2. Existing line gun
        # groups remain authoritative and receive no replacement triangles.
        rings=[]
        for r,z in ((14,16),(14.5,18),(10,26.8)):
            rings.append([[r*math.cos(j*math.tau/24),18+r*.86*math.sin(j*math.tau/24),z] for j in range(24)])
        loft(2,rings,'olive','btr_conical_turret')
        pipe(2,[0,18,26.8],[0,18,27.4],5,'hatch','btr_turret_lid',20)
        block(2,[-3,24,19],[3,32,24],'equipment','btr_source_mantlet')

    elif shape in (141,143):
        # Both game labels retain the same three original equipment anchor sheets.
        # Deep boat lower hull: rounded rear, full shoulders, a two-slope
        # bow and a short vertical nose rather than a single knife-like facet.
        loft(0,[[[-27,-93,-12],[27,-93,-12],[33,-93,5],[-33,-93,5]],
                [[-31,-76,-19],[31,-76,-19],[42,-76,7],[-42,-76,7]],
                [[-31,56,-19],[31,56,-19],[41,56,8],[-41,56,8]],
                [[-29,88,-10],[29,88,-10],[37,88,7],[-37,88,7]],
                [[-25,105,-2],[25,105,-2],[31,105,3],[-31,105,3]]],
             'olive','brdm_compound_boat_hull')
        # Separate crew enclosure gives the windshield a real, steep face.
        loft(0,[[[-36,-77,7],[36,-77,7],[36,48,7],[-36,48,7]],
                [[-32,-66,20],[32,-66,20],[32,18,20],[-32,18,20]]],
             'olive','brdm_raised_crew_enclosure')
        for x0,x1 in ((-29,-2),(2,29)):
            plate(0,[[x0,22.85,18],[x1,22.85,18],[x1,41.3,10],[x0,41.3,10]],
                  'optic','brdm_broad_crew_windscreen')
            # Upper armoured shutters and pronounced lower window sills frame
            # the broad paired glass, without hiding it under another shell.
            plate(0,[[x0-1,22.6,18.2],[x1+1,22.6,18.2],[x1+1,18.5,20],[x0-1,18.5,20]],
                  'hatch','brdm_armoured_window_shutter')
            pipe(0,[x0-1,41.8,9.8],[x1+1,41.8,9.8],.55,'olive_edge','brdm_window_sill',8)
        for side in (-1,1):
            window=[[side*35.0,-9,10.8],[side*35.0,11,10.8],
                    [side*32.7,11,18.2],[side*32.7,-9,18.2]]
            plate(0,window if side>0 else window[::-1],'optic','brdm_crew_side_glass')
            pipe(0,[side*35.2,-10,10.5],[side*35.2,12,10.5],.45,'olive_edge','brdm_side_window_sill',8)
        plate(0,[[-31,83,8.1],[31,83,8.1],[29,92,6.3],[-29,92,6.3]],
              'hatch','brdm_folded_wave_deflector')
        for side,g in ((1,2),(-1,3)):
            for i,y in enumerate((-40,50)):
                wheel(g,side,y,-20,14.8,31.3,44.2,f'brdm_{side}_wheel_{i}')
            # Road-going 9P148 reference: auxiliary trench wheels are stowed
            # behind the lower side panel, with no exposed mini road wheels.
            lo,hi=sorted((side*30.8,side*31.3))
            block(0,[lo,-18,-18.5],[hi,28,-11.8],'olive','brdm_stowed_auxiliary_wheel_panel')
            # Flat narrow fenders do not fill the open wheel spaces.
            lo,hi=sorted((side*32,side*44))
            block(0,[lo,-64,3.2],[hi,73,4.2],'olive_edge','brdm_fender')
            for y in (-23,-4):
                side_plate(0,side,[(y,17.1),(y+7,17.1),(y+7,14.9),(y,14.9)],
                           'brdm_raised_crew_enclosure','optic','brdm_side_periscope')
            x=side*17
            hatch(out,groups[0],x,-6,20,6,master,'brdm_crew_hatch')
        for j in range(15):
            block(0,[-22,-62+j*1.2,20.05],[22,-61.5+j*1.2,20.5],'vent','brdm_rear_engine_louvre')
        lights(0,28,99,5,2)
        pipe(0,[0,-93,-2],[0,-94,-2],9,'vent','brdm_waterjet',24)
        # 9P148 Konkurs: five enclosed transport/launch canisters carried on
        # one elevating centre mount. All remain in the original equipment pose
        # group; the game's three old sheets are anchors, not a weapon count.
        block(1,[-12,-59,20.0],[12,-38,21.3],'hatch','brdm_launcher_roof_base')
        loft(1,[[[-6,-54,21.2],[6,-54,21.2],[6,-44,21.2],[-6,-44,21.2]],
                [[-5,-53,28.6],[5,-53,28.6],[5,-44,28.6],[-5,-44,28.6]]],
             'olive','brdm_launcher_central_pedestal')
        pipe(1,[-19,-49,29.2],[19,-49,29.2],1.1,'steel','brdm_launcher_trunnion',12)
        for side in (-1,1):
            pipe(1,[side*6,-49,28.0],[side*6,-49,30.4],2.0,'olive_edge','brdm_launcher_pivot_cheek',16)
        for x in (-16,-8,0,8,16):
            n=24 if master else 16
            def axis(y):return [x,y,26.8+(y+77)*.13]
            pipe(1,axis(-77),axis(-12),2.85,'equipment','brdm_launcher_canister',n)
            pipe(1,axis(-78.4),axis(-76.7),3.1,'olive_edge','brdm_launcher_rear_cap',n)
            pipe(1,axis(-12.4),axis(-10.7),3.18,'olive_edge','brdm_launcher_front_rim',n)
            # Shallow closed olive dust covers, not empty black missile mouths.
            pipe(1,axis(-10.65),axis(-10.45),2.72,'hatch','brdm_launcher_end_cap',n)
            for y in (-64,-31):
                pipe(1,axis(y-.65),axis(y+.65),3.04,'steel','brdm_launcher_retaining_band',n)
            block(1,[x-1.8,-51,29.0],[x+1.8,-47,30.2],'steel','brdm_launcher_saddle')

    else:
        # Generic bonneted 6x6 utility truck. Body, screen, bonnet, tailgate,
        # canvas and each wheel side follow seven distinct source groups.
        for side,g in ((1,5),(-1,6)):
            for i,y in enumerate((-59,-22,55)):
                wheel(g,side,y,-20,14.8,30.5,44.2,f'truck_{side}_axle_{i}')
            lo,hi=sorted((side*15,side*19))
            block(0,[lo,-76,-21],[hi,103,-15],'steel','truck_chassis_rail')
            # Rolled mudguard follows the tyre crown instead of a flat shelf.
            profile=[(34,-9),(36,-2),(44,2),(64,2),(74,-2),(77,-10),
                     (75,-10),(72,-4),(63,0),(45,0),(38,-4),(36,-9)]
            loft(0,[[[side*x,y,z] for y,z in profile] for x in (31.5,44.5)],'olive','truck_front_fender')
            for y in (-59,-22,55):
                pipe(0,[0,y,-20],[side*31,y,-20],2,'steel','truck_axle',12)
            lo,hi=sorted((side*33.5,side*44.7))
            block(0,[lo,46,-17],[hi,72,-14.5],'olive_edge','truck_cab_step')
            for y in (48,68):
                lo,hi=sorted((side*38,side*39.5))
                block(0,[lo,y,-16],[hi,y+1.5,-6.5],'steel','truck_cab_step_bracket')
            for y in (52,63):
                lo,hi=sorted((side*36.5,side*44.4))
                block(0,[lo,y,-14.5],[hi,y+1,-14.1],'steel','truck_cab_step_tread')
        block(0,[-39,-78,0],[39,42,5],'olive','truck_bed_floor')
        for side in (-1,1):
            x=side*42
            for z in (6,11):
                block(0,[min(x,side*43),-78,z],[max(x,side*43),42,z+3],'olive','truck_bed_sideboard')
            for y in (-76,-46,-16,14,39):
                block(0,[min(x,side*43.5),y,3],[max(x,side*43.5),y+1.6,16],'steel','truck_bed_stake')
        # Large load boxes rest on the bed, visible only through the flap gap.
        for x0,x1,y0,y1,z0,z1 in ((-31,1,-70,-31,5,29),(3,32,-68,-29,5,29),(-24,22,-24,15,5,31)):
            block(0,[x0,y0,z0],[x1,y1,z1],'truck_crate_wood','truck_bed_cargo_crate')
            for x in (x0+2,x1-3):
                block(0,[x,y0-.18,z0+1],[x+1,y0-.05,z1-1],'steel','truck_bed_crate_binding')
            for z in (z0+3,z1-4):
                block(0,[x0+.5,y0-.23,z],[x1-.5,y0-.10,z+.5],'truck_crate_wood','truck_bed_crate_batten')
        # Upright split screen and rounded pressed-steel roof shoulders. The
        # original cab/bonnet break and all seven visibility groups are retained.
        def cab_ring(x,back,front,z,r):
            return [[-x+r,back,z],[x-r,back,z],[x,back+r,z],[x,front-r,z],
                    [x-r,front,z],[-x+r,front,z],[-x,front-r,z],[-x,back+r,z]]
        loft(0,[cab_ring(40,45,80,-7,1.6),cab_ring(40,45,80,17.5,1.6),
                cab_ring(38.5,46,78,36.5,1.8),cab_ring(34,49,76.8,39.5,3.)],
             'olive','truck_cab_shell')
        for side in (-1,1):
            window_yz=[(49,20),(74,20),(73,35.2),(49,35.2)]
            side_plate(0,side,window_yz,'truck_cab_shell','optic','truck_cab_sideglass')
            window=[[_side_skin_x(out,{'truck_cab_shell'},y,z,side)+side*.16,y,z] for y,z in window_yz]
            for a,b in zip(window,window[1:]+window[:1]):pipe(0,a,b,.24,'vent','truck_sideglass_gasket',4)
            block(0,[min(side*40,side*40.7),52,14],[max(side*40,side*40.7),58,15],'steel','truck_door_handle')
            for a,b in (([side*40.1,47,-5],[side*40.1,76,-5]),
                        ([side*40.1,76,-5],[side*40.1,76,17]),
                        ([side*40.1,47,-5],[side*40.1,47,17])):
                pipe(0,a,b,.18,'vent','truck_door_shutline',6)
            pipe(0,[side*39.0,47.5,36.3],[side*39.0,76.5,36.3],.45,'olive_edge','truck_roof_drip_rail',8)
            for a,b in (([side*39,73,26],[side*44.3,74,28]),([side*39,74,34],[side*44.3,74,30])):
                pipe(0,a,b,.3,'steel','truck_cab_mirror_arm',4)
            block(0,[min(side*43.5,side*44.7),73.6,26],[max(side*43.5,side*44.7),75,33],'olive_edge','truck_cab_mirror')
        # Screen g1 lies just ahead of its sloping cab surround.
        for x0,x1 in ((-35,-1.4),(1.4,35)):
            screen=[[x0,78.25,35.5],[x1,78.25,35.5],[x1,80.05,18.5],[x0,80.05,18.5]]
            plate(1,screen,'optic','truck_split_windscreen')
            for a,b in zip(screen,screen[1:]+screen[:1]):pipe(1,a,b,.24,'vent','truck_screen_gasket',4)
            pipe(1,[x0+3,80.07,19.8],[x1-5,79.05,29.5],.26,'steel','truck_wiper',6)
        # Bonnet group2 follows its source slope, leaving the grille to body g0.
        # Rolled shoulders and a slight crown, preserving the broad nose width.
        bonnet=[]
        for y,half,z,lower in ((80,38.5,15,8),(108,36.5,12,5)):
            bonnet.append([[-half,y,lower],[half,y,lower],[half,y,z-2.1],[half-1.0,y,z-.6],
                           [half-2.8,y,z],[0,y,z+.7],[-half+2.8,y,z],[-half+1.0,y,z-.6],[-half,y,z-2.1]])
        loft(2,bonnet,'olive','truck_sloping_bonnet')
        pipe(2,[0,82,15.6],[0,105,13.15],.25,'olive_edge','truck_bonnet_spine',6)
        loft(0,[[[-38,79,-13],[38,79,-13],[38,79,14],[-38,79,14]],
                [[-36,108,-12.5],[36,108,-12.5],[36,108,11.5],[-36,108,11.5]]],
             'olive','truck_enclosed_engine_bay',cap_end=False)
        for side in (-1,1):
            loft(0,[[[side*x,76,z] for x,z in ((37,-3),(44,-3),(44,-1),(37,-1))],
                    [[side*x,107,z] for x,z in ((35.5,-5),(43.5,-5),(43.5,-3.2),(35.5,-3.2))]],
                 'olive','truck_front_wing')
        # Open ring construction gives the radiator genuine depth. A solid
        # backing box here would cover the recess, however dark its texture.
        def rim(x0,x1,z0,z1,r,y):
            return [[x0+r,y,z0],[x1-r,y,z0],[x1,y,z0+r],[x1,y,z1-r],
                    [x1-r,y,z1],[x0+r,y,z1],[x0,y,z1-r],[x0,y,z0+r]]
        back=rim(-44,44,-12.5,11.5,2.,106.5)
        shoulder=rim(-44,44,-12.5,11.5,2.,108.2)
        front=rim(-43.4,43.4,-11.9,10.9,1.7,109.)
        opening=rim(-23,23,-10.5,9.5,1.2,109.)
        throat=rim(-22.1,22.1,-9.6,8.6,.8,106.7)
        for a,b,part in ((back,shoulder,'truck_radiator_apron'),
                         (shoulder,front,'truck_radiator_apron'),
                         (front,opening,'truck_radiator_apron'),
                         (opening,throat,'truck_grille_return')):
            for j in range(8):
                k=(j+1)%8
                quad=[a[j],a[k],b[k],b[j]]
                plate(0,quad[::-1],
                      'olive_edge' if part=='truck_grille_return' else 'olive',part)
        plate(0,throat[::-1],'vent','truck_grille_recess')
        for x in range(-20,21,4):
            pipe(0,[x,108.25,-9.2],[x,108.25,8.1],.58,'olive_edge','truck_grille_bar',4 if not master else 8)
        for j in range(8):
            pipe(0,opening[j],opening[(j+1)%8],.22,'olive_edge','truck_grille_surround',6 if master else 4)
        block(0,[-44.5,107,-16.5],[44.5,109.7,-13],'steel','truck_front_bumper')
        for side in (-1,1):
            # Inset lamps and a narrower radiator share the broad outer apron.
            # Working if the front face tightens without narrowing the bonnet.
            x=side*30.5
            pipe(0,[x,108.6,4],[x,109.35,4],4.8,'olive_edge','truck_seated_headlight_bezel',16)
            # Convex inset glass, seated within the metal bezel.
            lens=[]
            for y,r in ((109.36,3.35),(109.6,2.5),(109.67,.5)):
                lens.append([[x+r*math.cos(j*math.tau/12),y,4+r*math.sin(j*math.tau/12)] for j in range(12)])
            solid(out,groups[0],lens,'truck_headlamp_glass','truck_recessed_headlight_lens',cap_start=False)
            pipe(0,[x,108.4,-7.7],[x,109.25,-7.7],1.65,'steel','truck_front_signal_housing',8)
            pipe(0,[x,109.26,-7.7],[x,109.43,-7.7],1.15,'truck_indicator_glass','truck_front_indicator',8)
            for y in (86,90,94):
                lower=lambda yy:10.4-3*(yy-80)/28
                # Seat the vent on whichever overlapping panel is outermost.
                upper=lambda yy:12.1-3*(yy-80)/28
                side_plate(2,side,[(y,lower(y)),(y+2.2,lower(y+2.2)),
                                  (y+2.2,upper(y+2.2)),(y,upper(y))],
                           {'truck_sloping_bonnet','truck_enclosed_engine_bay'},'vent','truck_bonnet_side_louvre')
            latch=[[_side_skin_x(out,{'truck_sloping_bonnet','truck_enclosed_engine_bay'},83,z,side)+side*.2,83,z] for z in (9,13)]
            pipe(2,*latch,.45,'steel','truck_bonnet_latch',8)
        block(3,[-41,-79.8,1],[41,-78.5,15],'olive','truck_tailgate')
        for x in (-29,29):
            block(3,[x-3.9,-79.95,-9],[x+3.9,-77.9,-2],'steel','truck_tail_lamp_housing')
            pipe(3,[x-1.6,-79.94,-5.6],[x-1.6,-80,-5.6],1.75,'truck_stop_glass','truck_tail_lamp',8)
            pipe(3,[x+2,-79.94,-5.6],[x+2,-80,-5.6],1.05,'truck_indicator_glass','truck_rear_indicator',8)
        # Cargo cover sits just above the cab, following the reference truck.
        # Working if the tarp no longer towers over cab, wheels and cargo bed.
        section=[(-43,16),(-43,36),(-39,42),(-28,45.4),(0,46.5),(28,45.4),(39,42),(43,36),(43,16)]
        # Cloth hangs between the five retained bows. Extra shoulder/side rows
        # give the skirt a shallow belly without shifting seams or tied hems.
        # Working if mid-bay cloth sags while every bow and lower tie stays put.
        fabric=[(-43,16),(-43,23),(-43,30),*section[1:-1],(43,30),(43,23),(43,16)]
        bows=(-76,-48,-20,8,39)
        stations=sorted({-78,41,*bows,*((a+b)/2 for a,b in zip(bows,bows[1:]))})
        rings=[]
        for y in stations:
            hang=max((math.sin(math.pi*(y-a)/(b-a))**2 for a,b in zip(bows,bows[1:]) if a<=y<=b),default=0.)
            ring=[]
            for x,z in fabric:
                belly=.9*hang*max(0.,1-abs(z-26)/10)
                drop=1.0*hang*max(0.,min(1.,(z-16)/20))
                ring.append([x-math.copysign(belly,x) if x else x,y,z-drop])
            rings.append(ring)
        solid(out,groups[4],rings,'canvas_edge','truck_canvas_cover',cap_start=False,cap_end=False)
        # Close the cab-facing end; rear curtains leave only a narrow ajar slit.
        # Working if cargo reads through the gap without an open-ended tent.
        for ring in (rings[-1],):
            centre=[0,ring[0][1],29]
            for a,b in zip(ring,ring[1:]+ring[:1]):
                emit(out,groups[4],[centre,a,b],'canvas_edge','truck_canvas_cover',inside=[0,-18.5,29])
        for side in (-1,1):
            points=[[side*x,-78,z] for x,z in ((43,16),(27,16),(27,39),(41,39),(43,36))]
            emit(out,groups[4],points,'canvas_edge','truck_canvas_entry_surround',inside=[0,-18.5,29])
            pipe(4,[side*27,-78.15,16],[side*27,-78.15,39],.18,'equipment','truck_canvas_entry_hem',4)
        top=[[-41,-78,39],[-39,-78,42],[-28,-78,45.4],[0,-78,46.5],
             [28,-78,45.4],[39,-78,42],[41,-78,39]]
        for a,b in zip(top,top[1:]+top[:1]):
            emit(out,groups[4],[[0,-78,42.5],a,b],'canvas_edge','truck_canvas_entry_surround',inside=[0,-18.5,29])
        for profile in ([[-27,-78.45,16],[-14,-79.0,16.3],[-2.6,-79.25,17],[-1.6,-78.65,38.8],[-14,-78.7,38.9],[-27,-78.45,39]],
                        [[2.6,-77.45,17],[14,-78.8,16.3],[27,-78.45,16],[27,-78.45,39],[14,-78.65,38.9],[1.6,-78.20,38.8]]):
            # Explicit strips keep corresponding front/back diagonals on the
            # folded cloth. A six-corner nonplanar cap crossed its thin back
            # surface in the projection bake and produced a black triangle.
            # Working if the finished rear-facing flap charts contain colour.
            # One intermediate row gives the hanging cloth a soft belly while
            # retaining its narrow entry gap and exact top/bottom attachment.
            # Working if the flap curves without a folded-cardboard silhouette
            # or the old nonplanar-cap projection hole.
            bottom=profile[:3];top=list(reversed(profile[3:]))
            middle=[[(a[k]+b[k])*.5-(.38 if j==1 else .12) if k==1 else (a[k]+b[k])*.5
                     for k in range(3)] for j,(a,b) in enumerate(zip(bottom,top))]
            grid=bottom+middle+top
            back=[[x,y+.4,z] for x,y,z in grid]
            for row in range(2):
                for col in range(2):
                    ids=(row*3+col,row*3+col+1,(row+1)*3+col+1,(row+1)*3+col)
                    emit(out,groups[4],[grid[i] for i in ids],'canvas_edge','truck_canvas_entry_ajar_flap',inside=[0,-70,27])
                    emit(out,groups[4],[back[i] for i in ids],'canvas_edge','truck_canvas_entry_ajar_flap',inside=[0,-85,27])
            outline=(0,1,2,5,8,7,6,3)
            inside=[sum(v[k] for v in grid)/len(grid)+(0.2 if k==1 else 0) for k in range(3)]
            for i,j in zip(outline,outline[1:]+outline[:1]):
                emit(out,groups[4],[grid[i],back[i],back[j],grid[j]],'canvas_edge','truck_canvas_entry_ajar_flap',inside=inside)
            pipe(4,profile[2] if profile[0][0]<0 else profile[0],profile[3] if profile[0][0]<0 else profile[5],.16,'equipment','truck_canvas_entry_fold')
        # Seams/ties remain on the canvas group, never leak into the cab mask.
        for y in (-76,-48,-20,8,39):
            for (x,z),(xx,zz) in zip(section[1:-1],section[2:-1]):
                pipe(4,[x,y,z],[xx,y,zz],.25 if master else .18,'equipment','truck_canvas_bow',6 if master else 4)
            for side in (-1,1):
                pipe(4,[side*43.3,y,17],[side*43.3,y,35],.24,'equipment','truck_canvas_tie',6 if master else 4)
        for side in (-1,1):
            for y in range(-73,40,14):
                pipe(4,[side*43.1,y,17],[side*43.1,y+4,21],.3,'steel','truck_canvas_lacing',6 if master else 4)
    # These source hulls are unusually wide/flat. Inset their horizontal
    # proportions, keeping ground/roof planes and original line-only weapons.
    # Wheels and fenders scale about the ground so tyres stay circular and
    # in contact with it. A blanket XYZ stretch would ovalise every wheel.
    if shape in (137,141,143):
        scale=.82 if shape==137 else .80
        ground=-11.8 if shape==137 else -34.8
        for tri in out:
            c=tri['component']
            # Equipment retains its independent original pose, without the
            # horizontal hull narrowing applied to the running gear below.
            if c.startswith('brdm_launcher_'):continue
            running=c.startswith('btr_') and '_axle_' in c or c.startswith('brdm_') and ('_wheel_' in c or '_belly_' in c)
            fender=c in ('btr_fender','brdm_fender')
            cy=next((y for name,y in wheel_centres.items() if c.startswith(name+'_')),0)
            for v in tri['vertices']:
                v[0]*=scale
                if shape in (141,143):
                    # Longer boat hull, with wheel radii independent of axle spacing.
                    v[1]=cy*.88+(v[1]-cy)*scale if running else v[1]*.88
                elif c!='btr_source_mantlet':v[1]*=scale
                if running or fender:v[2]=ground+(v[2]-ground)*scale
    return out
