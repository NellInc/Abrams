"""Collapsed family-specific wreck art with original primitive/group custody.

All positions fit the game's shared wreck envelope, not intact-vehicle dimensions.
Alias geometry is deliberately independent of shape index inside each family.
"""
import math

FAMILY_KEYS = {
    116: 't62', 118: 't64', 120: 't72', 122: 't80', 124: 'fst',
    126: 'abrams', 128: 'm60', 130: 'm113', 132: 'bradley',
    134: 'bmp1', 136: 'bmp2', 138: 'btr8', 140: 'acrv',
    142: 'brdm4', 144: 'brdm4', 160: 'truck6',
}


def geometry(base, master=False):
    from tools.build_pc_tactical_vehicles import source_groups, emit, solid, box, tube
    family = FAMILY_KEYS[base['shape_index']]
    sources = source_groups(base)[0]
    out = []

    def face(points, material, name):
        emit(out, sources, points, material, name)

    def block(lo, hi, material, name):
        box(out, sources, lo, hi, material, name)

    def pipe(a, b, radius, material, name, segments=12, tip=None):
        tube(out, sources, a, b, radius, material, name, segments, tip=tip)

    def shell(rings, material, name, cap_end=True):
        solid(out, sources, rings, material, name, cap_end=cap_end)

    def torn(points, name, material='burnt', thickness=.4):
        # Closed thin plates with irregular torn edges, no zero-area fragments.
        shell([points, [[x,y,z-thickness] for x,y,z in points]], material, name)
        for j in range(0,len(points)-1,2) if master or 'track' not in name else ():
            pipe(points[j],points[j+1],.17,'exposed',name+'_torn_edge',6)

    def roadwheel(side, y, i, wheeled=False):
        r = 10 if wheeled else {'t64':4.9,'t72':6.8,'m113':6.8,'m60':6.6}.get(family,6.3)
        z = -19 if wheeled else -22
        x = 37 if wheeled else 36
        # A collapsed tyre at one station, deformed roadwheel rims elsewhere.
        squash = .43 if i == 1 else (.75 if i == 3 else 1)
        n = 32 if master else 20
        rings=[]
        for xx,rr in ((x-5,r*.77),(x-3.8,r),(x+3,r*.94),(x+4,r*.73)):
            rings.append([[side*(xx+.6*math.sin(j*math.tau/n)),y+rr*math.cos(j*math.tau/n),
                           z+rr*squash*math.sin(j*math.tau/n)] for j in range(n)])
        shell(rings,'scorch' if wheeled else 'burnt','collapsed_tyre' if wheeled else 'damaged_roadwheel')
        # A seated rear rim, raised lip and recessed well share the wheel's
        # existing crushed profile. Round cylinders protruded through the
        # flattened tyres and left their hubs/bolt circle visually disconnected.
        dish_segments=16 if master else 12
        shell([[[side*xx,y+rr*math.cos(j*math.tau/dish_segments),
                  z+rr*squash*math.sin(j*math.tau/dish_segments)] for j in range(dish_segments)]
               for xx,rr in ((x+3.9,r*.54),(x+4.8,r*.54),(x+4.65,r*.28))],
              'rust','exposed_wheel_dish')
        hub_start=len(out)
        pipe([side*(x+4.5),y,z],[side*(x+5),y,z],r*.22,'exposed','axle_hub',12 if master else 8)
        for triangle in out[hub_start:]:
            triangle['vertices']=[[v[0],v[1],round(z+(v[2]-z)*squash,6)] for v in triangle['vertices']]
        if master:
            for j in range(8):
                t=j*math.tau/8
                a=[side*(x+4.6),y+r*.37*math.cos(t),z+r*.37*squash*math.sin(t)]
                pipe(a,[a[0]+side*.25,a[1],a[2]],.27,'exposed','wheel_bolt',6)
        pipe([side*25,y,-21],[side*(x-4),y,z],1.2,'exposed','broken_suspension_arm',10 if master else 8)

    def engine(y=-43, length=21, width=23):
        block([-width/2,y-length/2,-25],[width/2,y+length/2,-19],'scorch','open_engine_sump')
        for side in (-1,1):
            block([side*7-3,y-length*.39,-19],[side*7+3,y+length*.39,-15.6],'rust','exposed_engine_bank')
            for j in range(5):
                yy=y-length*.3+j*length*.15
                pipe([side*7,yy,-15.5],[side*7,yy,-14.8],1.5,'exposed','engine_cylinder_cap',10 if master else 6)
        pipe([-12,y+3,-17],[11,y+3,-17],1.3,'rust','engine_manifold',12)
        for j in range(3):
            pipe([-9+j*8,y+length*.5,-18],[-8+j*8,y+length*.8,-15-j],.7,'exposed','severed_engine_pipe',8)

    def hull(width=30, rear=-58, front=54, roof=-11, carrier=False):
        lower=[[-width+5,rear+5,-27],[width-5,rear+5,-27],[width-4,front-7,-27],[-width+4,front-7,-27]]
        upper=[[-width,rear,roof-2],[width,rear+2,roof-1],[width,front,roof-3],[-width,front-2,roof]]
        shell([lower,upper],'burnt','crushed_open_chassis',False)
        # Substantial surviving front armour, with a buckled deck edge.
        torn([[-width+1,front-2,roof+.2],[width-1,front,roof-2.8],
              [width-4,14,roof-1],[12,9,roof+1],[2,16,roof-1],[-width+3,11,roof+1.4]],'buckled_front_deck')
        block([-width+5,rear+6,-26],[width-5,8,-24.5],'scorch','open_bay_floor')
        for side in (-1,1):
            torn([[side*(width-.3),rear+2,roof-1],[side*(width+3),rear+18,roof+5],
                  [side*(width-1),rear+27,roof+2],[side*(width+2),rear+34,roof+6],
                  [side*(width-1),4,roof]],'torn_sidewall','rust')
        if carrier:
            # Crushed troop compartment sides stand above the low floor.
            for side in (-1,1):
                torn([[side*(width-2),-26,roof],[side*(width-5),-24,-4],
                      [side*(width-4),-2,-6],[side*(width-1),5,roof]],'carrier_ripped_roof_side')
            for y in (-18,-5):
                block([-18,y,-24],[18,y+2,-19],'rust','interior_bulkhead_stump')

    wheel_counts={'t62':5,'t64':6,'t72':6,'t80':6,'fst':7,'abrams':7,
                  'm60':6,'m113':5,'bradley':6,'bmp1':6,'bmp2':6,'acrv':7}
    tracked=family in wheel_counts
    if tracked:
        count=wheel_counts[family]
        for side in (-1,1):
            for i in range(count):
                y=-47+i*91/(count-1)
                roadwheel(side,y,i)
            # Track shoes are individually closed, interrupted by a blast gap.
            # One upper run is folded inward rather than a pristine belt.
            for i in range(24):
                y=-57+i*4.7
                if side==1 and 10<=i<=14:
                    continue
                z=-28.5 if i<26 else -27.2
                skew=1.3*math.sin(i*.8)
                block([side*36-4,y,z],[side*36+4,y+3.4,z+1.2],'scorch','broken_lower_track_shoe')
                if i%2==0 and not (side==-1 and 9<=i<=17):
                    x=side*(35-(5 if side==-1 and i>17 else 0))
                    zz=-13.5+1.3*math.sin(i*.8)
                    torn([[x-4,y,zz],[x+4,y+.3,zz-.4],[x+3.6,y+3.2,zz+.4],[x-4,y+3.2,zz+skew*.25]],'buckled_upper_track_shoe','rust',.7)
            for j in range(6):
                y=-17+j*3.8
                torn([[side*35-3,y,-28],[side*35+4,y,-28],[side*35+5,y+3,-27],[side*35-2,y+3,-26]],'shed_track_link','rust',.5)
        carrier=family in ('m113','bradley','bmp1','bmp2','acrv')
        hull(29 if carrier else 31,roof=-12,carrier=carrier)
        engine()
        # Torn engine cover folded off the open rear bay.
        torn([[-25,-61,-14],[-18,-66,-6],[-1,-56,-8],[8,-62,-12],[19,-50,-13],[4,-46,-16]],'peeled_engine_cover')
        for i in range(8):
            pipe([-17+i*3,-61,-9],[-12+i*3,-53,-10],.32,'exposed','engine_grille_remnant',6)
        if not carrier and family!='fst':
            # Low displaced turret is hollow through a ragged roof opening.
            # An asymmetric outline distinguishes it from a scaled intact cone.
            n=24 if master else 20
            rings=[]
            if family=='abrams':
                # The intact model's angular cheeks and rear bustle remain
                # recognizable after crushing; never substitute a cast dome.
                outline=[[-21,-20],[17,-20],[29,-8],[26,13],[16,29],[-8,31],[-23,17],[-26,-5]]
                for scale,z in ((1.,-14),(.96,-9),(.69,-3.2)):
                    rings.append([[x*scale+4,y*scale+6,z+.7*math.sin(j*1.9)] for j,(x,y) in enumerate(outline)])
                shell(rings,'burnt','abrams_collapsed_angular_turret',False)
            else:
                rx,ry,top={'t62':(22,19,-3.5),'t64':(19,17,-4.5),
                           't72':(23,18,-3.2),'t80':(21,19,-4.),'m60':(23,24,-2.8)}[family]
                for scale,z in ((1.,-13),(1.045,-9),(.70,top)):
                    rings.append([[8+rx*scale*math.cos(j*math.tau/n),8+ry*scale*math.sin(j*math.tau/n),
                                   z+(1.1*math.sin(j*math.tau/n*4) if z==top else .5*math.sin(j*math.tau/n*3))] for j in range(n)])
                shell(rings,'burnt',family+'_displaced_cast_turret',False)
            block([-3,-2,-14],[16,17,-12],'scorch','turret_open_interior')
            # Bent gun lies close to the wreck floor, not raised in fighting pose.
            pipe([8,24,-8],[12,49,-13],2.4,'burnt','bent_gun_root',16,tip=1.5)
            pipe([12,49,-13],[25,74,-19],1.5,'rust','bent_gun_barrel',16,tip=1.2)
            pipe([25,73,-19],[25.5,75,-19.4],1.3,'scorch','broken_muzzle',12)
            torn([[-8,0,-3],[-1,-8,-1],[11,-5,-2],[4,4,-6]],'turret_roof_flap','rust')
            if family=='abrams':
                torn([[-15,-18,-9],[24,-18,-8],[25,-6,-4],[-12,-7,-5]],'collapsed_bustle')
                for x in (-12,0,12,24):
                    pipe([x,-19,-13],[x,-19,-7],.55,'exposed','bustle_rack_stump',8)
            elif family=='m60':
                pipe([-5,-3,-6],[-5,-3,-2.4],6.5,'burnt','m60_crushed_cupola',20,tip=5)
                for x in (-15,-5,5,15):
                    pipe([x,-17,-11],[x,-20,-6],.45,'rust','m60_broken_basket_stay',8)
            else:
                # Family-specific roof remnants follow the existing intact
                # layouts without introducing any new observed weapon state.
                xx={'t62':-5,'t64':-3,'t72':-7,'t80':-2}[family]
                pipe([xx,8,-6],[xx,8,-2.5],5,'burnt',family+'_crushed_hatch_coaming',16,tip=4.2)
                if family=='t80':
                    for x in (-18,-11,-4,3,10,17):
                        torn([[x,-61,-13],[x+4,-60,-13],[x+4,-53,-10],[x,-54,-11]],'t80_turbine_exhaust_remnant')
        elif family=='fst':
            # Molot's broad low turret and protected central gun shroud retain
            # their identity after collapse, without the former upright pods.
            for side in (-1,1):
                x=side*15
                torn([[x-11,-25,-13],[x+9,-20,-11],[x+8,17,-5.5],[x-10,23,-8]],'molot_collapsed_turret_cheek')
                for j in range(4):
                    y=-43+j*22
                    torn([[side*36,y,-12],[side*37,y+18,-13],[side*38,y+17,-20],[side*35,y,-22]],'molot_buckled_side_skirt')
            block([-7,-21,-10],[6,17,-5],'burnt','molot_split_gun_shroud')
            pipe([1,13,-7],[2.4,21,-8.6],3.0,'burnt','molot_collapsed_armoured_gun_root',16,tip=2.3)
            pipe([1,12,-7],[8,51,-15],2.3,'burnt','fst_bent_weapon_remnant',16,tip=1.8)
            pipe([8,51,-15],[12,69,-20],1.8,'rust','molot_broken_muzzle',12,tip=1.5)
        else:
            torn([[-24,14,-12],[-23,25,-5],[-7,24,-7],[1,18,-11],[-10,11,-13]],'carrier_crushed_cab_roof')
            torn([[-24,-28,-13],[-11,-22,-4],[4,-28,-10],[16,-21,-14]],'carrier_torn_rear_roof')
            if family=='m113':
                torn([[-23,-24,-12],[-20,-21,-4],[-19,8,-6],[-24,11,-12]],'m113_torn_high_side_return')
                torn([[-16,-40,-13],[14,-38,-12],[12,-15,-6],[-17,-18,-8]],'m113_folded_cargo_hatch')
                for x in (-14,10):
                    pipe([x,-55,-23],[x,-55,-9],.65,'exposed','m113_ramp_hinge_remnant',8)
            elif family=='bradley':
                rings=[[[x,y,z] for x,y in ((-9,3),(10,2),(20,13),(15,27),(-5,28),(-13,16))] for z in (-13,-6)]
                rings[1]=[[x*.80,y*.86+2,z] for x,y,z in rings[1]]
                shell(rings,'burnt','bradley_crushed_angular_turret',False)
                pipe([8,27,-8],[13,54,-18],1.05,'rust','bradley_bent_autocannon',12)
                for z in (-10,-6.8):
                    pipe([-11,7,z],[-11,24,z-1.6],1.5,'scorch','bradley_split_launcher_case',12)
            elif family in ('bmp1','bmp2'):
                radius=11 if family=='bmp1' else 13
                pipe([6,14,-13],[6,14,-5.8],radius,'burnt',family+'_collapsed_low_turret',24,tip=radius*.62)
                pipe([7,24,-8],[13,45 if family=='bmp1' else 58,-18],1.7 if family=='bmp1' else .85,'rust',family+'_bent_gun',12)
                if family=='bmp1':pipe([2,6,-4.5],[6,26,-6],.65,'exposed','bmp1_broken_launch_rail',8)
                else:pipe([1,12,-4.8],[2,24,-6.4],1.2,'burnt','bmp2_torn_launcher_mount',12)
            if family=='acrv':
                torn([[15,-19,-11],[27,-14,-3],[23,2,-6],[15,-1,-13]],'command_compartment_fold')
    elif family in ('btr8','brdm4'):
        ys=(-49,-27,22,46) if family=='btr8' else (-41,43)
        for side in (-1,1):
            for i,y in enumerate(ys):roadwheel(side,y,i,True)
        hull(29,rear=-60,front=60,roof=-13)
        engine(-43,20,22)
        torn([[-25,7,-12],[-22,25,-5],[-4,22,-8],[2,13,-10],[19,17,-14]],'scout_crushed_crew_roof')
        for side in (-1,1):
            torn([[side*29,-50,-11],[side*36,-40,-6],[side*34,-19,-12],[side*29,-16,-15]],'bent_wheel_fender','rust')
            torn([[side*28,18,-12],[side*36,26,-10],[side*31,53,-15],[side*27,48,-17]],'ripped_front_fender')
        if family=='btr8':
            pipe([4,17,-13],[7,20,-6],10,'burnt','btr_caved_turret',20,tip=7)
            pipe([6,27,-7],[12,48,-12],.9,'rust','btr_bent_gun_remnant',10)
        else:
            # Crushed launcher pivot and broken transport/launch canisters.
            block([-6,-28,-14],[6,-18,-9],'burnt','brdm_crushed_launcher_pedestal')
            for x in (-9,1,11):
                pipe([x,-43,-13],[x+5,-7,-7],2.3,'burnt','brdm_crushed_launch_canister',12,tip=1.9)
                pipe([x+5,-7,-7],[x+5.3,-5.6,-6.7],2.25,'rust','brdm_split_canister_lip',12)
    else:
        for side in (-1,1):
            for i,y in enumerate((-47,-20,46)):roadwheel(side,y,i,True)
            block([side*15-2,-61,-26],[side*15+2,62,-22],'burnt','truck_twisted_chassis_rail')
        block([-28,-59,-24],[28,18,-20],'scorch','truck_cargo_floor')
        for side in (-1,1):
            torn([[side*27,-58,-20],[side*32,-48,-13],[side*29,-32,-16],[side*34,-19,-12],[side*27,16,-20]],'truck_split_bed_side')
        engine(47,19,22)
        # Open crushed cab, broken window pillars and one roof fold.
        for side in (-1,1):
            torn([[side*26,20,-22],[side*29,27,-9],[side*23,38,-6],[side*26,43,-20]],'truck_crushed_cab_side')
            pipe([side*24,40,-18],[side*21,34,-5],.8,'exposed','truck_broken_screen_pillar',8)
        torn([[-21,23,-6],[1,20,-2],[19,26,-4],[20,35,-7],[2,32,-6]],'truck_folded_roof')
        torn([[-26,42,-16],[-29,56,-12],[-5,51,-9],[0,60,-15],[19,54,-20]],'truck_peeled_bonnet','rust')
        block([-24,65,-25],[24,67,-21],'exposed','truck_bent_front_bumper')
        for y in (-53,-25,3):
            pipe([-27,y,-19],[-18,y+4,-9],.65,'rust','truck_collapsed_canvas_bow',8)
            pipe([-18,y+4,-9],[11,y+7,-13],.65,'rust','truck_collapsed_canvas_bow',8)
            pipe([11,y+7,-13],[26,y,-21],.65,'rust','truck_collapsed_canvas_bow',8)
        torn([[-27,-54,-17],[-21,-44,-10],[-7,-39,-16],[0,-27,-19],[-11,-23,-18],[-24,-29,-19]],'truck_burned_canvas_shred','scorch')
    # Shared bounded loose fragments are deliberately different from a debris
    # box: narrow torn sheet, a fallen wheel/rim and exposed severed pipe.
    torn([[43,16,-28],[61,9,-29],[57,27,-26],[50,23,-24]],'detached_torn_side_plate','rust')
    pipe([46,42,-24],[49,44,-20],5,'burnt','detached_roadwheel',20,tip=4)
    # Both caps clear the tilted wheel faces instead of competing coplanarly
    # for the same baked/rendered pixels. The shaft remains seated inside it.
    axis=[v/math.sqrt(29) for v in (3,2,4)]
    pipe([a-.15*u for a,u in zip((46,42,-24),axis)],
         [b+.15*u for b,u in zip((49,44,-20),axis)],2,'exposed','detached_hub',12)
    pipe([-36,59,-28],[-21,65,-24],.8,'rust','severed_pipe',10)
    return out
