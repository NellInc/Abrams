"""Source-owned, independently proportioned Tactical personnel carriers.

Raw y is forward. Each articulated assembly draws only from its own original
filled group. In particular BMP line-only groups and ACRV antenna lines stay
untouched; the engine remains authoritative for visibility and collision.
"""
import math
from tools.build_pc_tactical_vehicles import source_groups, emit, solid, box, tube, hatch, end_wheel, end_wheel_height, roadwheel_shell


def running_gear(out, src, width, rear, front, ground, top, count, master, wheel_radius=None):
    """Closed individual shoes, recessed hull, paired dished road wheels."""
    radius=wheel_radius or min((top-ground)*.45,(front-rear)*.70/(count-1)*.47)
    z=ground+radius+1
    wheel_y=[rear+(front-rear)*(.15+.70*i/(count-1)) for i in range(count)]
    loop=[(rear+radius,ground),(front-radius,ground),(front,ground+radius),
          (front,top-radius*.35),(front-radius*.7,top),
          (rear+radius*.7,top),(rear,top-radius*.35),(rear,ground+radius)]
    lengths=[math.dist(loop[i],loop[(i+1)%8]) for i in range(8)]
    total=sum(lengths); shoes=46
    path=[]
    for j in range(shoes):
        d=total*j/shoes
        for i,length in enumerate(lengths):
            if d<=length:
                a,b=loop[i],loop[(i+1)%8];t=d/length
                path.append([a[k]+(b[k]-a[k])*t for k in range(2)]);break
            d-=length
    for side in (-1,1):
        inner=side*(width*.70);outer=side*(width-.35)
        for j,p in enumerate(path):
            q=path[(j+1)%shoes];mid=[(p[k]+q[k])/2 for k in range(2)]
            a=[mid[k]+(p[k]-mid[k])*.93 for k in range(2)]
            b=[mid[k]+(q[k]-mid[k])*.93 for k in range(2)]
            # Thin closed shoe has radial inward depth, preserving source bounds.
            cy=(rear+front)/2;cz=(ground+top)/2
            dy,dz=mid[0]-cy,(mid[1]-cz)*6;n=math.hypot(dy,dz)
            dy,dz=dy/n*.65,dz/n*.65
            solid(out,src,[[[xx,a[0],a[1]],[xx,b[0],b[1]],
                           [xx,b[0]-dy,b[1]-dz],[xx,a[0]-dy,a[1]-dz]]
                          for xx in (inner,outer)],'track_edge' if j%4==0 else 'track','track_shoe')
        for i,y in enumerate(wheel_y):
            xx=side*(width-1.1)
            roadwheel_shell(out,src,side,side*(width*.76),xx,y,z,radius,'tyre',f'roadwheel_{i}',master,.83,.73)
            tube(out,src,[xx+side*.26,y,z],[xx+side*.52,y,z],radius*.26,'hub',f'roadwheel_{i}_hub',12 if master else 11)
            if master:
                for j in range(6):
                    t=j*math.tau/6
                    yy,zz=y+radius*.52*math.cos(t),z+radius*.52*math.sin(t)
                    tube(out,src,[xx+side*.3,yy,zz],[xx+side*.44,yy,zz],radius*.055,'steel',f'roadwheel_{i}_bolt',6)
        for y,name in ((front-radius*.80,'drive_sprocket'),(rear+radius*.80,'track_idler')):
            rr=radius*.72
            end_wheel(out,src,side,inner,side*(width-.9),y,end_wheel_height(loop,y,rr),rr,name,master)
        xx0,xx1=sorted((side*(width*.73),side*(width-.1)))
        box(out,src,[xx0,rear,top+.1],[xx1,front,top+.9],'olive','track_fender')


def hull(out,src,width,rear,front,ground,roof,nose,kind,master,gear_fraction=.66,wheel_radius=None):
    """Distinct APC profile, with thin fenders surrounding a narrow boat hull."""
    lower=ground+2;tracktop=ground+(roof-ground)*gear_fraction
    half=width*.76 if kind!='m113' else width*.79
    solid(out,src,[[[-half,rear+5,lower],[half,rear+5,lower],
                     [half,front-15,lower],[-half,front-15,lower]],
                    [[-half,rear,tracktop],[half,rear,tracktop],
                     [half,front,nose],[-half,front,nose]]],'olive_edge','lower_hull_boat')
    # Bow rake and rear roof edge are independent for each vehicle family.
    shoulder=width*.84
    solid(out,src,[[[-shoulder,rear,tracktop],[shoulder,rear,tracktop],
                     [shoulder,front,nose],[-shoulder,front,nose]],
                    [[-shoulder,rear,roof],[shoulder,rear,roof],
                     [shoulder,front-(front-rear)*(.19 if kind=='m113' else .25),roof],
                     [-shoulder,front-(front-rear)*(.19 if kind=='m113' else .25),roof]]],
          'olive','armoured_upper_hull_sloped_glacis')
    # Rear access: M113/Bradley large ramp; Soviet families have twin doors.
    doors=2 if kind.startswith('bmp') else 1
    for i in range(doors):
        x0=-half*.83+i*(half*1.66/doors);x1=x0+half*1.66/doors-.5
        box(out,src,[x0,rear-.2,ground+4 if kind in ('m113','bradley') else tracktop+.8],[x1,rear+.5,roof-1],
            'hatch','rear_door' if doors==2 else 'rear_ramp')
        box(out,src,[x1-1.2,rear-.45,roof*.5-1],[x1-.7,rear-.22,roof*.5+2],'steel','rear_access_handle')
        for zz in (tracktop+2,roof-3):
            tube(out,src,[x0,rear-.5,zz],[x0+2,rear-.5,zz],.4,'steel','rear_access_hinge',8)
    # Separate engine louvres occupy the front-right deck, away from roof hatches.
    fy=front-(front-rear)*.36
    for i in range(9):
        yy=fy-i*(front-rear)*.011
        box(out,src,[width*.08,yy,roof+.05],[width*.63,yy+.65,roof+.35],'vent','engine_deck_grille')
    hatch(out,src,-width*.40,fy-4,roof+.15,width*.13,master,'driver_hatch')
    for side in (-1,1):
        xx=side*width*.70
        tube(out,src,[xx,front-6,nose+1],[xx,front-4,nose+1],width*.035,'lamp','headlight',12)
        for dx in (-width*.045,width*.045):
            tube(out,src,[xx+dx,front-5,nose],[xx+dx,front-5,nose+3],.25,'steel','headlight_guard',6)
        if kind.startswith('bmp'):
            for i in range(4):
                yy=rear+14+i*(front-rear)*.12
                tube(out,src,[side*(shoulder-.15),yy,roof-5],[side*(shoulder+.35),yy,roof-5],1.2,'vent','infantry_firing_port',10)
                x0,x1=sorted((side*(shoulder-.2),side*(shoulder+.4)))
                box(out,src,[x0,yy-1.8,roof-2],[x1,yy+1.8,roof-.7],'optic','infantry_vision_block')
    if kind=='m113':
        box(out,src,[-width*.54,rear+12,roof+.12],[width*.54,rear+43,roof+.7],'hatch','rectangular_cargo_hatch')
        for x in (-width*.45,width*.45):
            box(out,src,[x-1,rear+21,roof+.75],[x+1,rear+26,roof+1.25],'steel','cargo_hatch_handle')
    elif kind.startswith('bmp'):
        for side in (-1,1):
            for i in range(2):
                x=side*width*.43;y=rear+15+i*(front-rear)*.13
                box(out,src,[x-width*.22,y,roof+.12],[x+width*.22,y+(front-rear)*.10,roof+.65],'hatch','troop_roof_hatch')
    elif kind=='acrv':
        for side in (-1,1):
            x=side*width*.37
            box(out,src,[x-5,front-28,nose+4],[x+5,front-22,nose+5],'hatch','front_vision_armour')
            box(out,src,[x-3.5,front-27,nose+5.01],[x+3.5,front-23,nose+5.2],'optic','front_vision_block')
    if kind=='bradley':
        # Early Bradley: tall slab-sided troop compartment, shallow running
        # gear, two ports per side and two on the rear ramp, without later ERA.
        # Working if the early M2's six ports remain on the original hull owner.
        for side in (-1,1):
            for i in range(2):
                y=rear+19+i*(front-rear)*.19
                tube(out,src,[side*(shoulder-.1),y,roof-7],
                     [side*(shoulder+.35),y,roof-7],.8,'steel','bradley_firing_port',10)
                x0,x1=sorted((side*(shoulder-.1),side*(shoulder+.3)))
                box(out,src,[x0,y-1.5,roof-3.8],[x1,y+1.5,roof-2.5],
                    'optic','bradley_troop_periscope')
            x=side*half*.46
            tube(out,src,[x,rear-.25,roof-7],[x,rear-.65,roof-7],
                 .8,'steel','bradley_rear_firing_port',10)
            box(out,src,[x-1.5,rear-.45,roof-3.8],[x+1.5,rear-.21,roof-2.5],
                'optic','bradley_rear_periscope')
        box(out,src,[-width*.48,rear+9,roof+.08],[width*.48,rear+30,roof+.55],
            'hatch','bradley_troop_roof_hatch')
        # Front-right engine intake, opposite the driver's hatch; the folded
        # swim trim vane follows the two-slope bow rather than a tank glacis.
        box(out,src,[width*.27,fy-4,roof+.4],[width*.65,fy+9,roof+3.2],
            'olive_edge','bradley_raised_engine_intake')
        for j in range(5):
            y=fy-2+j*2
            box(out,src,[width*.30,y,roof+3.21],[width*.62,y+1.1,roof+3.45],
                'vent','bradley_intake_louvre')
        slope_start=front-(front-rear)*.25
        for y0,y1 in ((front-21,front-12),(front-11.6,front-7)):
            z0=roof+(nose-roof)*(y0-slope_start)/(front-slope_start)+.22
            z1=roof+(nose-roof)*(y1-slope_start)/(front-slope_start)+.22
            emit(out,src,[[-width*.67,y0,z0],[width*.67,y0,z0],
                          [width*.67,y1,z1],[-width*.67,y1,z1]],
                 'olive_edge','bradley_folded_trim_vane')
    running_gear(out,src,width,rear+1,front-1,ground,tracktop-.9,
                 5 if kind=='m113' else 7 if kind=='acrv' else 6,master,wheel_radius)


def cupola_gun(out,src,x,y,z,end,master):
    tube(out,src,[x,y,z],[x,y,z+4],.65,'steel','machinegun_pedestal',12)
    box(out,src,[x-1.1,y-2,z+3],[x+1.1,y+4,z+5],'equipment','machinegun_receiver')
    tube(out,src,[x,y+4,z+4.2],[x,end,z+4.2],.40,'steel','machinegun_barrel',12)
    box(out,src,[x-3,y,z+3],[x-1.2,y+3,z+5],'equipment','machinegun_ammunition_box')


def turret(out,src,kind,master):
    # All dimensions come from the intact turret group, never hull scaling.
    if kind=='bradley':
        # Compact two-man turret with a narrowed gun face and rear bustle.
        # The old near-hull-width cuboid obscured the Bradley's IFV identity.
        tube(out,src,[0,-4,9.55],[0,-4,11.1],17,'steel','bradley_turret_race',32)
        lower=[[-20,-31,10],[18,-31,10],[21,-15,10],[18,13,10],[9,25,10],[-12,25,10],[-22,8,10],[-23,-15,10]]
        upper=[[-17,-27,22],[15,-27,22],[18,-13,23],[15,8,22],[8,19,18.5],[-10,19,18.5],[-18,6,22],[-19,-13,23]]
        solid(out,src,[lower,upper],'olive','bradley_angular_turret')
        solid(out,src,[[[-6.2,14,16.2],[6.2,14,16.2],[6.2,14,23.2],[-6.2,14,23.2]],
                       [[-4.6,27,17.2],[4.6,27,17.2],[4.6,27,22.4],[-4.6,27,22.4]]],
              'olive_edge','bradley_gun_mantlet')
        for x,y,r in ((-9,-13,4.7),(9,-15,4.2)):
            tube(out,src,[x,y,22.0],[x,y,23.6],r+.45,'olive_edge','bradley_seated_hatch_collar',24)
            hatch(out,src,x,y,23.6,r,master,'commander_hatch' if x<0 else 'gunner_hatch')
        # TM 9-2350-252-10-2: eight commander vision blocks and two gunner
        # blocks. Raised coamings and outward-facing glass replace a bare roof.
        # Working if all ten housings seat into the turret without hiding hatches.
        for cx,cy,radius,angles,role in ((-9,-13,6.5,range(8),'commander'),
                                        (9,-15,5.9,(1,3),'gunner')):
            for step in angles:
                a=step*math.tau/8;dx,dy=math.cos(a),math.sin(a)
                def point(u,v,z):return [cx+dx*(radius+v)-dy*u,cy+dy*(radius+v)+dx*u,z]
                solid(out,src,[[point(u,v,z) for u,v in ((-1.35,-.65),(1.35,-.65),(1.35,.65),(-1.35,.65))]
                               for z in (22.1,24.4)],'olive_edge','bradley_'+role+'_vision_coaming')
                emit(out,src,[point(-1.03,.665,23.15),point(1.03,.665,23.15),
                              point(1.03,.665,24.03),point(-1.03,.665,24.03)],
                     'optic','bradley_'+role+'_vision_glass')
        # Large raised twin TOW box on the left cheek, with recessed mouths,
        # hinge brackets and a folded lid, rather than two dots in a slab.
        # Chamfered enclosure and projecting face plate protect the two bores.
        section=[(-34,16),(-25,16),(-24,17),(-24,26.5),(-25,27.5),(-34,27.5),(-35,26.5),(-35,17)]
        solid(out,src,[[[x,y,z] for x,z in section] for y in (-20,17)],'equipment','tow_launcher_housing')
        for z in (18.8,24.2):
            tube(out,src,[-29.5,17,z],[-29.5,18,z],2.2,'steel','tow_launcher_rim',12)
            tube(out,src,[-29.5,17.98,z],[-29.5,18.01,z],1.7,'vent','tow_launcher_tube',12)
        box(out,src,[-35.3,-18,27.5],[-23.7,17,28.2],'olive_edge','bradley_tow_lid')
        for y in (-16,11):
            box(out,src,[-35.4,y,18.0],[-34.8,y+1.2,25.8],'olive_edge','bradley_tow_case_rib')
        for y in (-13,8):
            tube(out,src,[-24,y,19.5],[-19,y,19.5],1.7,'steel','bradley_tow_pivot',12)
        box(out,src,[7,1,21.6],[15,11,25.7],'equipment','bradley_sight_housing')
        box(out,src,[8,10.95,22.7],[14,11.2,24.9],'optic','turret_sight')
        box(out,src,[6.6,.8,25.7],[15.4,12,26.2],'olive_edge','bradley_sight_armoured_brow')
        for side in (-1,1):
            for y in (-26,-12):
                x=side*18
                tube(out,src,[x,y,18],[x,y,24],.35,'steel','bradley_bustle_stay',6)
            tube(out,src,[side*18,-26,24],[side*18,-12,24],.35,'steel','bradley_bustle_rail',6)
        for side in (-1,1):
            for i in range(3):
                x=side*(16+i*1.4)
                tube(out,src,[x,11,14],[x,14,18],.65,'steel','smoke_launcher',8)
    elif kind.startswith('bmp'):
        bmp1=kind=='bmp1';w=36 if bmp1 else 23;cy=-39 if bmp1 else -26
        z0,z1=(19,36) if bmp1 else (12,23)
        rings=[]
        for z,scale in ((z0,1),(z1,.68)):
            rings.append([[w*scale*math.cos(j*math.tau/20),cy+w*.80*scale*math.sin(j*math.tau/20),z] for j in range(20)])
        solid(out,src,rings,'olive','bmp1_low_conical_turret' if bmp1 else 'bmp2_two_man_turret')
        hatch(out,src,-w*.28,cy-3,z1,w*.22,master,'commander_hatch')
        if not bmp1:hatch(out,src,w*.30,cy-2,z1,w*.21,master,'gunner_hatch')
        box(out,src,[w*.35,cy+7,z1-2],[w*.61,cy+12,z1+.7],'optic','turret_sight')
    else:
        solid(out,src,[[[-21,-31,16],[21,-31,16],[21,1,16],[-21,1,16]],
                       [[-15,-27,25],[15,-27,25],[15,-5,25],[-15,-5,25]]],'olive','acrv_observation_cupola')
        hatch(out,src,0,-17,25,6,False,'observation_hatch')
        for x in (-9,0,9):box(out,src,[x-2,-6,24],[x+2,-4,26],'optic','observation_periscope')


def bmp_launcher(out,src,bmp1,master):
    """Distinct rail/round and canister assemblies on the original ATGM owner.

    These are visual approximations inside the incumbent pose envelope, not
    physical dimensions or a change to missile type, aim or launch behaviour.
    Build after the turret's plan-view correction to keep round sections round.
    """
    a,b=([.7,-60,40],[3.8,-18.8,44.4]) if bmp1 else ([.6,-33.5,27.4],[1.4,-10.8,29.8])
    direction=[b[k]-a[k] for k in range(3)];length=math.sqrt(sum(v*v for v in direction))
    forward=[v/length for v in direction]
    across=[forward[1],-forward[0],0];n=math.hypot(*across[:2]);across=[v/n for v in across]
    up=[across[1]*forward[2],-across[0]*forward[2],across[0]*forward[1]-across[1]*forward[0]]
    def point(t,x=0,z=0):return [a[k]+t*direction[k]+x*across[k]+z*up[k] for k in range(3)]
    def prism(t0,t1,x0,x1,z0,z1,material,name):
        solid(out,src,[[point(t,x,z) for x,z in ((x0,z0),(x1,z0),(x1,z1),(x0,z1))]
                       for t in (t0,t1)],material,name)
    def round_part(stations,material,name):
        count=24 if master else 16
        solid(out,src,[[point(t,r*math.cos(j*math.tau/count),z+r*math.sin(j*math.tau/count))
                       for j in range(count)] for t,r,z in stations],material,name)
    if bmp1:
        # Open channel section, two supporting shoes and a cross-axis pivot.
        # A round rod cannot read as a launch rail, even with a baked highlight.
        prism(0,1,-1.25,1.25,-.65,-.10,'steel','sagger_launch_rail_web')
        for x0,x1 in ((-1.25,-.78),(.78,1.25)):
            prism(0,1,x0,x1,-.10,.62,'olive_edge','sagger_launch_rail_flange')
        for t in (.34,.66):
            q=point(t);box(out,src,[q[0]-1.4,q[1]-1.6,35.85],
                           [q[0]+1.4,q[1]+1.6,q[2]-.55],'equipment','sagger_rail_mount')
        tube(out,src,point(.48,-2,-.7),point(.48,2,-.7),1.05,'steel','sagger_rail_pivot',12)
        # Recognisable stepped warhead, narrow nose and four swept tail fins.
        round_part([(.18,.65,2.35),(.21,1.50,2.35),(.60,1.50,2.35),
                    (.70,1.72,2.35),(.81,1.90,2.35),(.90,1.35,2.35),
                    (.985,.24,2.35)],'equipment','sagger_missile_body')
        tube(out,src,point(.985,0,2.35),point(1.015,0,2.35),.18,'steel','sagger_nose_probe',8,tip=.08)
        round_part([(.19,.68,2.35),(.195,.68,2.35)],'vent','sagger_tail_aperture')
        for j in range(4):
            angle=math.pi*.25+j*math.pi*.5
            # Thin closed swept plates give real silhouettes from both sides.
            rings=[]
            for thickness in (-.16,.16):
                rings.append([point(t,r*math.cos(angle)+thickness*math.sin(angle),
                                    2.35+r*math.sin(angle)-thickness*math.cos(angle))
                              for t,r in ((.22,1.35),(.30,5.5),(.49,5.5),(.56,1.35))])
            solid(out,src,rings,'olive_edge','sagger_swept_fin')
        for t in (.23,.58):prism(t-.025,t+.025,-.65,.65,.4,1.2,'steel','sagger_rail_shoe')
    else:
        # Roof pedestal, trunnion and saddle are separate load-bearing forms.
        box(out,src,[-1.3,-25.6,22.85],[3.0,-21.4,23.6],'olive_edge','atgm_pedestal_foot')
        tube(out,src,[.85,-23.5,23.4],[.85,-23.5,26.4],1.0,'steel','atgm_launcher_support',16)
        tube(out,src,[-1.6,-23.5,26.3],[3.3,-23.5,26.3],.85,'steel','atgm_cradle_pivot',12)
        prism(.32,.57,-1.3,1.3,-2.1,-1.4,'equipment','atgm_launch_cradle')
        round_part([(0,1.45,0),(.04,1.7,0),(.96,1.7,0),(1,1.8,0)],'equipment','atgm_launch_canister')
        for t in (.20,.76):
            round_part([(t-.018,1.87,0),(t+.018,1.87,0)],'olive_edge','atgm_canister_clamp')
            prism(t-.025,t+.025,-.6,.6,-2.25,-1.45,'steel','atgm_clamp_foot')
        for t in (0,1):
            round_part([(t-.015,1.93,0),(t+.015,1.93,0)],'steel','atgm_canister_end_collar')
        # Recessed, closed protective end faces, not a second exposed rocket.
        round_part([(1.016,1.42,0),(1.018,1.42,0)],'vent','atgm_canister_end_seal')
        round_part([(-.018,1.42,0),(-.016,1.42,0)],'hatch','atgm_canister_rear_seal')
        prism(.27,.43,1.7,2.15,-.5,.35,'olive_edge','atgm_canister_carry_handle')


def geometry(base,master=False):
    shape=base['shape_index'];groups=source_groups(base);out=[]
    profiles={129:(27.6,-48,51,-20,19,-6,'m113'),
              131:(27.6,-49,59,-20,9.7,-2,'bradley'),
              133:(45,-107.16,97.76,-27,19.6,12,'bmp1'),
              135:(27.2,-60.75,55.89,-18,11,8,'bmp2'),
              139:(30,-65,75,-20,15,4,'acrv')}
    if shape not in profiles:raise ValueError(f'Unsupported tracked carrier {shape}')
    # Keep source ceiling/ground planes. Correct width and length rather than
    # stretching wheels or expanding the original visibility/hit envelope.
    gear={129:(.48,6.15),131:(.48,5.65),133:(.66,9.8),135:(.56,5.8),139:(.66,None)}
    hull(out,groups[0],*profiles[shape],master,*gear[shape])
    hull_end=len(out)
    if shape==129:
        # Filled group is the elevated .50-calibre pose, no invented turret.
        tube(out,groups[1],[-12,9,20],[-12,9,26],1.2,'steel','commander_gun_mount',12)
        cupola_gun(out,groups[1],-12,9,26,29,master)
    elif shape==131:
        turret(out,groups[1],'bradley',master)
        cupola_gun(out,groups[2],-12,-3,26,19,master)
        tube(out,groups[3],[0,24,20],[0,62,20],1.1,'steel','25mm_autocannon',20)
        tube(out,groups[3],[0,62,20],[0,66,20],1.45,'vent','25mm_muzzle',16)
        tube(out,groups[3],[0,25,20],[0,33,20],1.8,'olive_edge','gun_mantlet_sleeve',16)
        tube(out,groups[3],[0,32,20],[0,36,20],1.38,'steel','bradley_gun_recoil_collar',16)
    elif shape in (133,135):
        kind='bmp1' if shape==133 else 'bmp2';turret(out,groups[2],kind,master)
        if shape==133:
            tube(out,groups[4],[0,-9,31],[0,72,31],2.1,'steel','73mm_low_pressure_gun',20)
            tube(out,groups[4],[0,72,31],[0,75,31],2.6,'vent','73mm_muzzle',16)
        else:
            tube(out,groups[4],[0,-5,20],[0,47,20],.72,'steel','30mm_autocannon',20)
            tube(out,groups[4],[0,47,20],[0,50,20],1.05,'vent','30mm_muzzle_brake',16)
    else:
        turret(out,groups[1],'acrv',master)
        cupola_gun(out,groups[2],0,-12,27,12,master)
    sx,sy={129:(.726,.773),131:(.726,.730),133:(.90,.94),135:(.85,.81),139:(1,1)}[shape]
    for tri in out[hull_end:]:
        for v in tri['vertices']:
            v[0]*=sx;v[1]*=sy
            if shape==131 and tri['component'] in ('tow_launcher_rim','tow_launcher_tube'):
                bore=18.8 if v[2]<21.5 else 24.2
                v[2]=bore+(v[2]-bore)*sx
            # Radial section of the main gun stays circular after narrowing.
            if shape in (131,133,135) and base['groups'][3 if shape==131 else 4]['offset'] in tri['source_groups']:
                bore={131:20,133:31,135:20}[shape]
                v[2]=bore+(v[2]-bore)*sx
    if shape in (133,135):bmp_launcher(out,groups[3],shape==133,master)
    return out
