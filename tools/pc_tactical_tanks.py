"""Remaining Tactical tanks, authored inside immutable original owner envelopes.

T64/T72/T80 share their real layout but have independent casting profiles,
wheel diameters/spacing, engine arrangements and fittings. F-ST depicts the
requested Object 477A Molot while retaining the original five pose owners.
"""
import math

PROFILES = {
    117: dict(width=57, rear=-97, front=119, ground=-31, deck=16,
              tracktop=4, radius=9.4, wheels=(-67,-37,-7,23,53,83)),
    119: dict(width=57, rear=-97, front=119, ground=-31, deck=16,
              tracktop=4, radius=13.7, wheels=(-67,-36,-5,26,57,88)),
    121: dict(width=37, rear=-65, front=78, ground=-20, deck=9,
              tracktop=3, radius=8.3, wheels=(-46,-28,-8,12,34,56)),
    127: dict(width=44, rear=-78, front=91, ground=-40, deck=-.8,
              tracktop=-14, radius=9.6, wheels=(-53,-29,-5,19,43,67)),
    123: dict(width=25.5, rear=-46.5, front=58.5, ground=-16, deck=-4.5,
              tracktop=-4.25, radius=5.65, wheels=(-33.5,-20.75,-8,4.75,17.5,30.25,43)),
}


def running_gear(out, src, shape, master):
    from tools.build_pc_tactical_vehicles import solid, tube, box, end_wheel, end_wheel_height, roadwheel_shell,emit
    p=PROFILES[shape];w=p['width'];rear=p['rear'];front=p['front']
    bottom=p['ground'];top=p['tracktop'];radius=p['radius'];z=bottom+radius+1
    if shape==123:z=bottom+radius+.4
    # Closed articulated steel shoes, with open running space above wheels.
    corner=(top-bottom)*.36
    loop=[(rear+corner,bottom),(front-corner,bottom),(front,bottom+corner),
          (front,top-corner*.6),(front-corner*.5,top),
          (rear+corner*.5,top),(rear,top-corner*.6),(rear,bottom+corner)]
    lengths=[math.dist(loop[i],loop[(i+1)%8]) for i in range(8)]
    total=sum(lengths);count=46;path=[]
    for j in range(count):
        d=total*j/count
        for i,L in enumerate(lengths):
            if d<=L:
                a,b=loop[i],loop[(i+1)%8];t=d/L
                path.append([a[k]+t*(b[k]-a[k]) for k in range(2)]);break
            d-=L
    for side in (-1,1):
        inside=side*w*.72;outside=side*w
        for j,p0 in enumerate(path):
            p1=path[(j+1)%count];mid=[(p0[k]+p1[k])/2 for k in range(2)]
            a=[mid[k]+(p0[k]-mid[k])*.94 for k in range(2)]
            b=[mid[k]+(p1[k]-mid[k])*.94 for k in range(2)]
            dy,dz=mid[0]-(front+rear)/2,(mid[1]-(top+bottom)/2)*6
            length=math.hypot(dy,dz);thickness=.65 if shape in (121,123) else 1.0
            dy,dz=dy/length*thickness,dz/length*thickness
            rings=[[[xx,a[0],a[1]],[xx,b[0],b[1]],
                    [xx,b[0]-dy,b[1]-dz],[xx,a[0]-dy,a[1]-dz]] for xx in (inside,outside)]
            solid(out,src,rings,'track_edge' if j%4==0 else 'track','track_shoe')
            if shape==123 and master:
                # The projection master carries steel grousers into the normal
                # map without spending the runtime silhouette budget.
                tangent=[p1[k]-p0[k] for k in range(2)];span=math.hypot(*tangent)
                ty,tz=tangent[0]/span*.18,tangent[1]/span*.18
                solid(out,src,[[[x,mid[0]-ty,max(bottom,mid[1]-tz)],[x,mid[0]+ty,max(bottom,mid[1]+tz)],
                                [x,mid[0]+ty+dy*.32,max(bottom,mid[1]+tz+dz*.32)],
                                [x,mid[0]-ty+dy*.32,max(bottom,mid[1]-tz+dz*.32)]] for x in (inside,outside)],
                      'steel','molot_track_grouser')
        xx=side*(w-.9)
        for i,y in enumerate(PROFILES[shape]['wheels']):
            # T64 has visibly small all-metal discs with internal damping.
            if shape==123:
                start=len(out)
                roadwheel_shell(out,src,side,inside,xx,y,z,radius,'tyre',f'roadwheel_{i}',master,
                                rim_radius=.86,rim_tip=.70,rim_depth=-.75)
                # The recess is concave: its interior lies behind the entire
                # wheel, not midway between the lip and recessed disc.
                # Working if every outer disc faces out in Godot's culled mesh.
                for triangle in out[start:]:
                    if triangle['component']!=f'roadwheel_{i}_dish':continue
                    faces=[]
                    emit(faces,src,triangle['vertices'],'wheel',triangle['component'],inside=[(inside+xx)*.5,y,z])
                    assert len(faces)==1
                    triangle.update(faces[0])
                # A seated casting widens into the recessed disc, then rolls
                # into its smaller axle cap. Working if the hub has shoulders
                # rather than reading as a flat cylinder pasted on the wheel.
                n=16 if master else 10
                rings=[[[xx+side*dx,y+radius*r*math.cos(j*math.tau/n),
                         z+radius*r*math.sin(j*math.tau/n)] for j in range(n)]
                       for dx,r in ((-.78,.29),(-.20,.25),(.12,.17))]
                solid(out,src,rings,'hub',f'roadwheel_{i}_hub')
            else:
                roadwheel_shell(out,src,side,inside,xx,y,z,radius,'steel' if shape==117 else 'tyre',f'roadwheel_{i}',master)
                tube(out,src,[xx+side*.26,y,z],[xx+side*.50,y,z],radius*.26,'hub',f'roadwheel_{i}_hub',12 if master else 11)
            if master:
                for j in range(8):
                    t=j*math.tau/8;yy=y+radius*.54*math.cos(t);zz=z+radius*.54*math.sin(t)
                    a,b=(-.71,-.55) if shape==123 else (.27,.43)
                    tube(out,src,[xx+side*a,yy,zz],[xx+side*b,yy,zz],radius*.045,'steel',f'roadwheel_{i}_bolt',6)
        # Molot's seven full-size road wheels leave less end clearance.
        # Working if both end wheels clear the tyres and still seat inside the track.
        rr=(top-bottom)*(.28 if shape==123 else .25)
        for y,name in ((rear+rr+.6,'drive_sprocket'),(front-rr-.6,'track_idler')):
            end_wheel(out,src,side,inside,xx,y,end_wheel_height(loop,y,rr),rr,name,master)
        if shape!=123:
            rollers={117:4,119:3,121:5,127:5}[shape]
            for i in range(rollers):
                yy=rear+(front-rear)*(.17+.66*i/(rollers-1))
                tube(out,src,[inside,yy,top-radius*.22],[side*(w-1.1),yy,top-radius*.22],radius*.23,'tyre','return_roller',12)
        x0,x1=sorted((side*w*.71,side*w))
        box(out,src,[x0,rear,top+.1],[x1,front,top+.9],'olive','track_fender')
        if shape in (119,121):
            for i in range(6):
                a=rear+i*(front-rear)/6
                xx0,xx1=sorted((side*(w-.2),side*(w-.7)))
                box(out,src,[xx0,a,top-radius*.40],[xx1,a+(front-rear)/6-.8,top],'equipment','side_skirt_panel')
        elif shape==117:
            for yy in (-50,-8,34,76):
                xx0,xx1=sorted((side*(w-1.7),side*w))
                box(out,src,[xx0,yy,top-7],[xx1,yy+21,top],'olive_edge','gill_armour_panel')


def hull(out, src, shape, master):
    from tools.build_pc_tactical_vehicles import solid, box, tube, hatch
    p=PROFILES[shape];w=p['width'];r=p['rear'];f=p['front'];z=p['deck'];ground=p['ground']
    hw=w*(.73 if shape!=127 else .76);nose=f-(f-r)*.03
    bowbase=ground+(z-ground)*.42;shoulder=z-2
    solid(out,src,[[[-hw,r+9,ground+3],[hw,r+9,ground+3],
                     [hw,f-21,ground+3],[-hw,f-21,ground+3]],
                    [[-hw,r,z-4],[hw,r,z-4],[hw,nose,bowbase],[-hw,nose,bowbase]]],
          'olive_edge','lower_hull_boat')
    setback=(f-r)*(.21 if shape==127 else .23)
    solid(out,src,[[[-hw,r,z-4],[hw,r,z-4],[hw,nose,bowbase],[-hw,nose,bowbase]],
                    [[-hw,r,z],[hw,r,z],[hw,f-setback,z],[-hw,f-setback,z]]],
          'olive','upper_hull_sloped_glacis')
    # Broad front plate, raised splash strip and source-centred driver's hatch.
    hatch(out,src,0,f-setback-7,z+.05,w*.105,master,'driver_hatch')
    box(out,src,[-hw*.75,f-setback+1,z-.2],[hw*.75,f-setback+2,z+.45],'steel','glacis_splash_strip')
    for side in (-1,1):
        x=side*w*.66
        tube(out,src,[x,nose-3,bowbase+2],[x,nose-1.7,bowbase+2],w*.033,'lamp','headlight',12)
        for dx in (-w*.045,w*.045):
            tube(out,src,[x+dx,nose-2.5,bowbase+.4],[x+dx,nose-2.5,bowbase+4],.25,'steel','headlight_guard',6)
        # Distinct fender stowage spacing is separate from the load-bearing hull.
        for i in range(3 if shape in (117,119) else 2):
            yy=r+8+i*(f-r)*.18
            x0,x1=sorted((side*w*.77,side*(w-.5)))
            floor=p['tracktop']+1 if shape==127 else z-.8
            box(out,src,[x0,yy,floor],[x1,yy+(f-r)*.145,floor+(7 if shape==127 else 3.8)],'equipment','fender_stowage')
    # Engine decks: flat opposed diesel, left exhaust V12, broad turbine outlet.
    count=14 if shape==117 else 10 if shape==119 else 12
    for i in range(count):
        yy=r+3+i*(f-r)*.24/count
        box(out,src,[-hw*.72,yy,z+.1],[hw*.72,yy+(f-r)*.007,z+.4],'vent','engine_deck_grille')
    if shape==117:
        box(out,src,[-hw*.66,r-.6,z-5],[hw*.66,r+.8,z-1],'vent','opposed_diesel_rear_exhaust')
    elif shape==119:
        box(out,src,[-w*.93,r+18,z-4],[-w*.74,r+36,z+1],'steel','left_diesel_exhaust')
        for i in range(5):box(out,src,[-w*.94,r+20+i*3,z-3],[-w*.935,r+21+i*3,z],'vent','diesel_exhaust_slot')
    elif shape==121:
        box(out,src,[-hw*.78,r-.7,z-9],[hw*.78,r+.7,z-1],'steel','gas_turbine_exhaust_frame')
        for i in range(8):
            x=-hw*.70+i*hw*1.4/8
            box(out,src,[x,r-.8,z-8],[x+hw*.10,r-.72,z-2],'vent','turbine_exhaust_vane')
    elif shape==127:
        for x in (-hw*.54,hw*.54):
            box(out,src,[x-9,r+.2,z-10],[x+9,r+1,z-2],'vent','rear_engine_louvre')
        # M60's long fender boxes remain above exposed wheels.
        for side in (-1,1):
            x0,x1=sorted((side*w*.76,side*(w-.3)))
            box(out,src,[x0,-66,p['tracktop']+1],[x1,-8,p['tracktop']+8.5],'equipment','long_fender_toolbox')
    running_gear(out,src,shape,master)


def cast_turret(out, src, shape, master):
    from tools.build_pc_tactical_vehicles import solid, tube, hatch, box
    # Each horizontal contour has its own x/y radii and fore-aft centre.
    profiles={
        117:[(17,34,31,4),(20,43,39,4),(27,42,39,6),(34,35,31,3),(39,24,23,0)],
        119:[(17,35,32,4),(21,44,40,5),(29,43,40,7),(35,37,31,3),(39,25,24,-1)],
        121:[(10,23,20,3),(13,29,27,3),(19,28,26,4),(24,23,20,0),(25,17,16,-2)],
        127:[(0,36,55,8),(5,49,63,12),(12,49,64,17),(20,37,53,16),(25,29,43,9)],
    }
    segments=52 if master else 32;rings=[]
    for z,rx,ry,cy in profiles[shape]:
        ring=[]
        for j in range(segments):
            t=j*math.tau/segments
            # Cast cheek fullness and a narrowed gun nose create real lobes.
            x=rx*math.cos(t);y=cy+ry*math.sin(t)
            if shape==127 and y>42:x*=1-.36*(y-42)/42
            if shape in (117,119,121) and y>cy+ry*.63:x*=.84
            ring.append([x,y,z])
        rings.append(ring)
    solid(out,src,rings,'olive','m60_long_nose_cast_turret' if shape==127 else f't{ {117:64,119:72,121:80}[shape]}_compound_cast_turret')
    small=shape==121;s=.65 if small else 1;roof=profiles[shape][-1][0]
    if shape==127:
        # Tall enclosed M19 cupola is a turret-owned fixed casting; gun remains separate.
        tube(out,src,[10,-8,24],[10,-8,34],8,'olive','m19_commander_cupola',32 if master else 24,tip=6.7)
        hatch(out,src,10,-8,34,6.4,master,'commander_hatch')
        hatch(out,src,-17,-8,25,7,master,'loader_hatch')
        for i in range(6):
            t=i*math.tau/6
            tube(out,src,[10+7.3*math.cos(t),-8+7.3*math.sin(t),31],
                 [10+7.3*math.cos(t),-8+7.3*math.sin(t),32],1.1,'optic','cupola_vision_block',8)
        box(out,src,[29,5,17],[36,16,22],'equipment','laser_rangefinder_housing')
        box(out,src,[29.5,15.8,18],[35.5,16.2,21],'optic','laser_rangefinder_aperture')
        box(out,src,[-19,15,23],[-11,27,27],'equipment','thermal_sight_housing')
        box(out,src,[-18,26.8,24],[-12,27.2,26],'optic','thermal_sight_aperture')
        # Open rail bustle rack, rather than a solid block.
        for zz in (10,18):
            tube(out,src,[-32,-53,zz],[32,-53,zz],.45,'steel','bustle_rack',8)
            for side in (-1,1):tube(out,src,[side*32,-53,zz],[side*32,-35,zz],.45,'steel','bustle_rack',8)
        for x in (-32,-16,0,16,32):tube(out,src,[x,-53,10],[x,-53,18],.4,'steel','bustle_rack_upright',8)
    else:
        # Preserve source handedness for the separate AA weapon group.
        cx=-20 if not small else -12;cy=-5*s
        tube(out,src,[cx,cy,roof-.5],[cx,cy,roof+3*s],6*s,'hatch','commander_cupola',24)
        hatch(out,src,cx,cy,roof+3*s,5.6*s,master,'commander_hatch')
        hatch(out,src,17*s,-5*s,roof,6*s,master,'gunner_hatch')
        bx=18*s if shape==117 else -17*s
        box(out,src,[bx-4*s,10*s,roof-3*s],[bx+4*s,20*s,roof+2*s],'equipment','gunner_day_sight')
        box(out,src,[bx-3*s,19.8*s,roof-2*s],[bx+3*s,20.2*s,roof+1*s],'optic','gunner_sight_aperture')
        lightx=23*s if shape!=119 else -24*s
        tube(out,src,[lightx,25*s,roof-8*s],[lightx,28*s,roof-8*s],3.8*s,'equipment','infrared_searchlight',20)
        tube(out,src,[lightx,28*s,roof-8*s],[lightx,28.3*s,roof-8*s],3.1*s,'optic','infrared_lens',20)
        # Rear snorkel stowage follows each vehicle's compact casting.
        tube(out,src,[-25*s,-32*s,roof-7*s],[24*s,-32*s,roof-7*s],2*s,'equipment','snorkel_stowage_tube',16)
        for side in (-1,1):
            for i in range(3):
                x=side*(29+i*2.5)*s;y=(16-i*2)*s
                tube(out,src,[x,y,roof-13*s],[x*1.03,y+4*s,roof-9*s],.9*s,'steel','smoke_launcher',10)
    if master:
        for i in range(12):
            t=i*math.tau/12
            x=profiles[shape][0][1]*.87*math.cos(t);y=profiles[shape][0][3]+profiles[shape][0][2]*.87*math.sin(t)
            tube(out,src,[x,y,profiles[shape][0][0]+.1],[x,y,profiles[shape][0][0]+.35],.35,'steel','turret_ring_fastener',6)


def gun(out,src,shape,master):
    from tools.build_pc_tactical_vehicles import tube, box, emit
    if shape==127:start,end,z,r=74,199.7,16,2.2
    elif shape==121:start,end,z,r=27,132,20,1.4
    else:start,end,z,r=41,208 if shape==117 else 199,31,2.1
    box(out,src,[-r*2.6,start-3,z-r*2],[r*2.6,start+6,z+r*2],'equipment','gun_mantlet')
    # Thermal sleeve, stepped joints and non-central bore evacuator.
    profile=[(0,r*1.2),(.07,r),(.30,r),(.32,r*1.48),(.46,r*1.48),
             (.49,r),(.72,r),(.74,r*.88),(1,r*.88)]
    segments=32 if master else 20
    for i,((a,R),(b,S)) in enumerate(zip(profile,profile[1:])):
        tube(out,src,[0,start+a*(end-start),z],[0,start+b*(end-start),z],R,'olive_edge' if i==3 else 'olive',
             'bore_evacuator' if i in (2,3,4) else 'thermal_sleeved_gun',segments,tip=S,open_end=i==len(profile)-2)
    outer=r*.88;inner=outer*.60
    for j in range(segments):
        a,b=j*math.tau/segments,(j+1)*math.tau/segments
        emit(out,src,[[outer*math.cos(a),end,z+outer*math.sin(a)],
                      [outer*math.cos(b),end,z+outer*math.sin(b)],
                      [inner*math.cos(b),end+.02,z+inner*math.sin(b)],
                      [inner*math.cos(a),end+.02,z+inner*math.sin(a)]],'steel','muzzle_rim')
    tube(out,src,[0,end-.7,z],[0,end-.65,z],inner,'vent','recessed_bore',segments)


def roof_weapon(out,src,shape,master):
    from tools.build_pc_tactical_vehicles import tube, box
    if shape==127:
        # This group contains the sloping source weapon above its M19 cupola.
        tube(out,src,[10,12,29],[10,22,34],1.0,'steel','cupola_weapon_mount',12)
        box(out,src,[8.5,20,32],[11.5,30,35],'equipment','m85_machinegun_receiver')
        tube(out,src,[10,30,34],[10,59,38],.55,'steel','m85_machinegun_barrel',12)
    else:
        small=shape==121;s=.65 if small else 1;x=-12 if small else -20;z=37 if small else 56
        tube(out,src,[x,-6*s,26 if small else 40],[x,-6*s,z],.8*s,'steel','aa_gun_pedestal',12)
        box(out,src,[x-1.8*s,-9*s,z-1.4*s],[x+1.8*s,7*s,z+1.5*s],'equipment','aa_machinegun_receiver')
        tube(out,src,[x,7*s,z+.6*s],[x,29*s,z+.6*s],.5*s,'steel','aa_machinegun_barrel',12)
        box(out,src,[x-4.6*s,-4*s,z-2*s],[x-1.9*s,4*s,z+1.6*s],'equipment','aa_ammunition_box')


def molot(out,groups,master):
    from tools.build_pc_tactical_vehicles import source_groups, solid, box, tube, hatch,emit
    src=groups[0]
    # Low glacis and long protected flanks, with an independent semi-recessed
    # gun housing. Dimensions remain inside the game's complete source bounds.
    solid(out,src,[[[-19,-40,-14.5],[19,-40,-14.5],[19,42,-14.5],[-19,42,-14.5]],
                   [[-21,-47,-5.5],[21,-47,-5.5],[21,58,-8],[-21,58,-8]],
                   [[-20,-44,-4.45],[20,-44,-4.45],[20,32,-4.45],[-20,32,-4.45]]],
          'olive','fst_low_wedge_hull')
    for i in range(10):
        y=-43+i*2.1
        box(out,src,[-14,y,-4.9],[14,y+1,-4.55],'vent','fst_engine_louvre')
    running_gear(out,src,123,master)
    for side in (-1,1):
        for j in range(7):
            y=-43+j*13.5;x0,x1=sorted((side*24.8,side*25.4))
            box(out,src,[x0,y,-8.2],[x1,y+12.9,-4.05],'equipment','molot_segmented_side_skirt')
        for j in range(4):
            y=33+j*5.7;x0,x1=side*10-8,side*10+8
            def deck(yy):return -4.45-(yy-32)*3.55/26
            solid(out,src,[[[x0,y,deck(y)+dz],[x1,y,deck(y)+dz],
                            [x1,y+5.1,deck(y+5.1)+dz],[x0,y+5.1,deck(y+5.1)+dz]]
                           for dz in (-.08,.24)],'olive_edge','molot_glacis_armour_module')
    hatch(out,src,-11,27,-4.4,3.2,master,'molot_driver_hatch')
    # Paired protected lamps and towing eyes belong to the hull, not the gun.
    for side in (-1,1):
        x=side*20.5
        box(out,src,[x-2.9,44,-5.8],[x+2.9,48.5,-3.65],'olive_edge','molot_headlight_platform')
        for dx,r in ((-1.35,1.02),(1.35,.8)):
            tube(out,src,[x+dx,46.3,-3.5],[x+dx,48.6,-3.5],r,'equipment','molot_headlight_housing',10)
            tube(out,src,[x+dx,48.61,-3.5],[x+dx,48.72,-3.5],r*.72,'lamp','molot_headlight_lens',10)
        tube(out,src,[x-2.8,47.8,-3.7],[x-2.8,47.8,-1.95],.14,'steel','molot_lamp_guard',6)
        tube(out,src,[x+2.8,47.8,-3.7],[x+2.8,47.8,-1.95],.14,'steel','molot_lamp_guard',6)
        tube(out,src,[x-2.8,47.8,-1.95],[x+2.8,47.8,-1.95],.14,'steel','molot_lamp_guard',6)
    # A single connected turret shell belongs entirely to group4. The two
    # former upright groups remain separate sight and auxiliary assemblies.
    src=groups[4]
    tube(out,src,[0,-1,-4.4],[0,-1,-3.2],12.5,'steel','molot_seated_turret_race',32)
    solid(out,src,[[[-18,-25,-3.6],[18,-25,-3.6],[20,10,-3.6],[10,22,-3.6],[-10,22,-3.6],[-20,10,-3.6]],
                   [[-15.5,-22,4.4],[15.5,-22,4.4],[16.8,9,5.1],[8,18,5.3],[-8,18,5.3],[-16.8,9,5.1]]],
          'olive','molot_low_armoured_turret')
    # Semi-recessed gun in a stepped armoured hood, with a narrowed nose.
    # The broad shoulder roof remains lower than this central housing.
    solid(out,src,[[[-5.4,-21,4.2],[5.4,-21,4.2],[5.4,12,4.2],[3.8,20,3.8],[-3.8,20,3.8],[-5.4,12,4.2]],
                   [[-4.2,-18,8.9],[4.2,-18,8.9],[4.2,10,8.5],[3.2,18,8.0],[-3.2,18,8.0],[-4.2,10,8.5]]],
          'olive_edge','fst_central_weapon_housing')
    for side in (-1,1):
        for j in range(3):
            x0,x1=sorted((side*5.8,side*14.8));y=-18+j*9.0
            solid(out,src,[[[x0,y,4.4],[x1,y,4.4],[x1,y+8.2,4.7],[x0,y+8.2,4.7]],
                           [[x0,y,4.8],[x1,y,4.8],[x1,y+8.2,5.1],[x0,y+8.2,5.1]]],
                  'olive_edge','molot_turret_armour_module')
    hatch(out,src,10,-12,5.1,3.6,master,'molot_crew_hatch')
    box(out,src,[-3.7,-21.1,6],[3.7,-20.8,9.3],'equipment','molot_breech_service_cover')
    # Tall armoured panoramic head: sloped front glass sits outside its hood.
    # Working if it reads as the reference's raised periscope rather than a box.
    sight=groups[1]
    tube(out,sight,[-10.5,9.8,4.7],[-10.5,9.8,6.0],2.5,'steel','molot_sight_pedestal',16)
    solid(out,sight,[[[-13.1,7.2,5.5],[-7.9,7.2,5.5],[-7.9,12.4,5.5],[-13.1,12.4,5.5]],
                     [[-12.6,7.6,11.7],[-8.4,7.6,11.7],[-8.4,10.9,11.7],[-12.6,10.9,11.7]]],
          'equipment','molot_sight_head')
    glass=[[-12.1,12.21,6.5],[-8.9,12.21,6.5],[-9.1,11.20,10.9],[-11.9,11.20,10.9]]
    emit(out,sight,glass,'optic','molot_sight_glass',inside=[-10.5,9,8])
    for a,b in zip(glass,glass[1:]+glass[:1]):
        tube(out,sight,a,b,.16,'olive_edge','molot_periscope_window_rim',6)
    box(out,sight,[-12.8,10.5,11.45],[-8.2,11.35,11.95],'olive_edge','molot_periscope_brow')
    # Twin six-tube smoke clusters, staggered in two ranks on seated brackets.
    for side in (-1,1):
        x0,x1=sorted((side*7,side*16))
        box(out,src,[x0,8.2,4.8],[x1,11,6.9],'steel','molot_smoke_cluster_bracket')
        for row in range(2):
            for j in range(3):
                x=side*(8.2+j*2.6+row*.35);y=9.7-row*2.2;z=6.9+row*1.0
                a=[x,y,z];b=[x+side*.8,y+3.1,z+1.25]
                tube(out,src,a,b,.72,'equipment','molot_smoke_launch_tube',10,open_end=True)
                tube(out,src,[b[0]-.05*side,b[1]-.18,b[2]-.07],b,.55,'vent','molot_smoke_tube_recess',10)
    for side in (-1,1):
        x=side*16.4
        box(out,src,[min(x,x+side*.35),-9,-.5],[max(x,x+side*.35),-4,2.6],'olive_edge','molot_turret_service_latch')
        tube(out,src,[x,-12,4.45],[x,-7,4.55],.25,'steel','molot_turret_handhold',6)
    tube(out,src,[13.8,-18,4.45],[13.8,-18,5.7],.7,'equipment','molot_aerial_base',10)
    tube(out,src,[13.8,-18,5.7],[13.8,-18,11.85],.09,'steel','molot_aerial',6)
    box(out,groups[2],[8.5,8,5.7],[13.5,15.8,8.3],'equipment','molot_auxiliary_receiver')
    tube(out,groups[2],[11,15.8,7],[11,32,7],.42,'steel','molot_auxiliary_barrel',10)
    # Single heavy main gun replaces the misleading twin pencil barrels.
    src=groups[3]
    tube(out,src,[0,16.2,6],[0,24,6],2.35,'olive_edge','molot_armoured_gun_root',20,tip=1.85)
    tube(out,src,[0,22,6],[0,85,6],1.8,'olive','molot_main_gun',20,tip=1.35)
    for a,b in ((19,21),(42,43.5),(64,65.5)):
        tube(out,src,[0,a,6],[0,b,6],1.72,'olive_edge','molot_thermal_sleeve_collar',16)
    tube(out,src,[0,84.5,6],[0,87.8,6],1.65,'steel','molot_muzzle_lip',20,open_end=True)
    tube(out,src,[0,87.1,6],[0,87.2,6],1.18,'vent','fst_recessed_bore',16)


def geometry(base,master=False):
    from tools.build_pc_tactical_vehicles import source_groups
    shape=base['shape_index'];groups=source_groups(base);out=[]
    if shape not in PROFILES:raise ValueError(f'Unsupported Tactical tank {shape}')
    if shape==123:molot(out,groups,master)
    else:
        hull(out,groups[0],shape,master);hull_end=len(out)
        cast_turret(out,groups[1],shape,master)
        gun(out,groups[2] if shape==127 else groups[4],shape,master)
        roof_weapon(out,groups[3],shape,master)
        if shape==127:
            # Tall M60 casting/cupola, slimmer hull, circular rebuilt running
            # gear. Fit inside the original envelope without changing poses.
            gun_group=base['groups'][2]['offset']
            for tri in out[hull_end:]:
                for v in tri['vertices']:
                    v[0]*=.72;v[1]*=.74
                    if gun_group in tri['source_groups']:v[2]=16+(v[2]-16)*.72
    return out
