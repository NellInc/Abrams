"""Photo-led ground ATGM presentation, retaining immutable source provenance."""
import copy,math
from tools.build_pc_modern_assets import add_face,bounds,validate_model,clip_plane

POSE={'schema':1,'kind':'ground-atgm-v1',
      'head_basis':[[0,.6,0],[-.579555496,0,.155291427],[.155291427,0,.579555496]],
      'head_origin':[-3.427887,6,-48.042329]}

# The forearm endpoints and explicit palms share one contact recipe.
HAND_CENTRES={161:((8.5,6.0,-73.8),(11.6,7.967,-77)),
              162:((1,5.2,-59),(1,17.4,-58.5))}
WRISTS={shape:tuple((x,y,z+(1.5 if shape==161 else 1.4)) for x,y,z in hands)
        for shape,hands in HAND_CENTRES.items()}
ELBOWS={161:((-5,2.7,-68),(-3,16,-70)),162:((-10,2.7,-66),(-10,16,-65))}

def material_sections(vertices):
    """Cut real material boundaries, avoiding centroid-painted sawtooth rims."""
    pieces=[vertices]
    for level in (-88.7,-83.0,-73.0,-71.0):
        divided=[]
        for poly in pieces:
            # Belt cuts have no material purpose on either forearm.
            if level in (-73.0,-71.0) and min(v[0] for v in poly)>=-16.0:
                divided.append(poly);continue
            if min(v[2] for v in poly)<level-1e-7 and max(v[2] for v in poly)>level+1e-7:
                divided.extend(clip_plane(poly,2,level,side) for side in (False,True))
            else:divided.append(poly)
        pieces=divided
    # The folded rear calf meets its boot along X, not the standing shin's Z.
    # Partition the shaft and heel limits too, so their colour cannot sawtooth.
    for axis,level in ((0,-19.0),):
        divided=[]
        for poly in pieces:
            rear=(max(v[2] for v in poly)<=-83.0+1e-7 and min(v[1] for v in poly)>9.0
                  and min(v[0] for v in poly)<-16.0)
            if rear and min(v[axis] for v in poly)<level-1e-7 and max(v[axis] for v in poly)>level+1e-7:
                divided.extend(clip_plane(poly,axis,level,side) for side in (False,True))
            else:divided.append(poly)
        pieces=divided
    return [[[round(c,6) for c in v] for v in poly] for poly in pieces if len(poly)>=3]

def cuffs(base,master=False):
    """Small sewn cuffs overlap the actual sleeve endpoint and wrist."""
    from tools.build_pc_tactical_vehicles import solid,unit,cross
    source=base['source_primitives'][0]
    src=dict(source,groups=[g['offset'] for g in base['groups'] if source['id'] in g['primitive_pointers']])
    out=[];shape=base['shape_index'];n=24 if master else 12
    for elbow,wrist in zip(ELBOWS[shape],WRISTS[shape]):
        axis=unit([wrist[k]-elbow[k] for k in range(3)])
        right=unit(cross(axis,[0,0,1]));up=cross(axis,right);rings=[]
        for along,r in ((-.85,1.78),(-.65,2.04),(-.12,2.04),(.05,1.78)):
            rings.append([[wrist[k]+axis[k]*along+r*(right[k]*math.cos(j*math.tau/n)+up[k]*math.sin(j*math.tau/n)) for k in range(3)] for j in range(n)])
        solid(out,[src],rings,'crew_cloth_light','crew_cuff')
    return out

def head_point(v):
    return [round(POSE['head_origin'][k]+sum(POSE['head_basis'][j][k]*v[j] for j in range(3)),6) for k in range(3)]

def grips(base,master=False):
    from tools.pc_tactical_crews import formed_hands
    from collections import Counter
    ts=formed_hands(base,master)
    # Rounded finger and thumb pads retain each exact terminal boundary.
    def rounded_pad(label,end,prev,side,amount):
        nonlocal ts
        axis=[end[k]-prev[k] for k in range(3)];length=math.sqrt(sum(c*c for c in axis));axis=[c/length for c in axis]
        caps=[t for t in ts if t['component']==label
              and (sum(v[0] for v in t['vertices'])/3<6)==(side=='left')
              and all(abs(sum((v[k]-end[k])*axis[k] for k in range(3)))<2e-6 for v in t['vertices'])]
        assert len(caps)==(10 if master else 6),(label,len(caps))
        edges=Counter((tuple(a),tuple(b)) for t in caps for a,b in zip(t['vertices'],t['vertices'][1:]+t['vertices'][:1]))
        tip=[round(end[k]+axis[k]*amount,6) for k in range(3)]
        ts=[t for t in ts if t not in caps]
        for (a,b),count in edges.items():
            if edges[(b,a)]:continue
            q=copy.deepcopy(caps[0]);q['vertices']=[list(a),list(b),tip];ts.append(q)
    for side,x,inner in (('left',2.0,1),('right',9.8,-1)):
        for name,offset,extra in (('index',1.30,.10),('middle',.43,.42),('ring',-.44,.25),('little',-1.27,-.32)):
            end=[x+inner*(offset-.14),1.13 if name=='little' else 1.02,-36.65-extra]
            prev=[x+inner*(offset-.08),.28,-36.05-extra*.75]
            rounded_pad('crew_hand_'+side+'_'+name,end,prev,side,.16)
        rounded_pad('crew_hand_thumb',[x+inner*.55,.55,-33.95],
                    [x+inner*1.20,.25,-33.35],side,.16)
    out=[]
    for t in ts:
        # Keep the twelve closed, independently projected grip parts intact.
        left=sum(v[0] for v in t['vertices'])/3<6
        oldx=2.0 if left else 9.8
        centre=HAND_CENTRES[base['shape_index']][0 if left else 1]
        sign=1 if left else -1
        q=copy.deepcopy(t)
        palm=t['component']=='crew_hand_palm';thumb=t['component']=='crew_hand_thumb'
        q['vertices']=[]
        for v in t['vertices']:
            # A continuous, gentle curl varies across the four digits. Applying
            # it by position keeps shared knuckle edges exactly closed.
            localx=sign*(v[0]-oldx);curl=max(0,min(1,(-34.3-v[2])/2.6))
            bend=0 if thumb else .25*math.sin(localx*1.35)*curl*curl
            q['vertices'].append([round(centre[0]+sign*(v[0]-oldx)*(1.04 if palm else .96 if thumb else 1.0),6),
                                  round(centre[1]+sign*((v[1]-1.5)*(1.22 if palm else 1.12)+bend),6),
                                  round(centre[2]+(v[2]+34.3)*(.87 if thumb else 1.0)-(.10 if thumb else 0),6)])
        out.append(q)
    return out

def equipment(base,master=False):
    from tools.build_pc_tactical_vehicles import box,tube,solid
    source=base['source_primitives'][0];src=dict(source,groups=[g['offset'] for g in base['groups'] if source['id'] in g['primitive_pointers']]);out=[]
    n=24 if master else 12
    def block(a,b,mat,label):
        if label not in {'launcher_case','launcher_control_lid','launcher_sagger_case_base','launcher_sagger_case_lid','launcher_spigot_guidance_housing','launcher_canister_cradle','launcher_periscope_hood'}:
            box(out,[src],a,b,mat,label);return
        bevel=min(.35,min(b[k]-a[k] for k in range(3))*.16)
        def outline(inset,z):
            x,y=a[0]+inset,a[1]+inset;X,Y=b[0]-inset,b[1]-inset;c=bevel*.6
            return [[x+c,y,z],[X-c,y,z],[X,y+c,z],[X,Y-c,z],[X-c,Y,z],[x+c,Y,z],[x,Y-c,z],[x,y+c,z]]
        solid(out,[src],[outline(bevel,a[2]),outline(0,a[2]+bevel),outline(0,b[2]-bevel),outline(bevel,b[2])],mat,label)
    def rod(a,b,r,mat,label,count=None):tube(out,[src],a,b,r,mat,label,count or n)
    def turned(stations,cy,cz,mat,label,count=None):
        count=count or n
        solid(out,[src],[[[x,cy+r*math.cos(j*math.tau/count),cz+r*math.sin(j*math.tau/count)] for j in range(count)] for x,r in stations],mat,label)
    if base['shape_index']==161:
        # US DoD DD-ST-85-01240/01242: controller, tall periscope,
        # separate finned missile and case lid with its launch support.
        block([-7,1,-90.0],[7,14.5,-80.0],'crew_equipment_edge','launcher_case')
        block([-7.2,1,-80.0],[7.2,14.5,-78.0],'crew_equipment','launcher_control_lid')
        block([-6.8,.8,-80.1],[6.8,1.2,-79.5],'crew_equipment_light','launcher_case_seam')
        for x in(-5.5,4.8):block([x,.6,-84.0],[x+.7,1,-82.5],'crew_metal','launcher_case_catch')
        rod([-5.2,.7,-86.0],[4.8,.7,-86.0],.35,'crew_boot','launcher_carry_handle',8)
        rod([3,8,-78],[3,8,-47],1.0,'crew_equipment','launcher_sagger_periscope_mast',32 if master else 16)
        rod([3,8,-50],[3,8,-47],1.35,'crew_equipment_light','launcher_periscope_collar')
        block([1.3,6.6,-47.2],[5,9.4,-42.5],'crew_equipment','launcher_periscope_hood')
        block([4.8,6.9,-46],[5.1,9.1,-43],'crew_optic','launcher_periscope_window')
        rod([5,6,-48],[-3.5,4.1,-48.4],.95,'crew_equipment_light','launcher_ocular_rim')
        turned([(-4.8,1.05),(-4.0,1.15),(-3.1,.85)],4.1,-48.4,'crew_boot','launcher_ocular_eyecup')
        turned([(-4.9,.65),(-4.8,.65)],4.1,-48.4,'crew_optic','launcher_ocular_glass')
        # Rubber bellows, short joystick and discrete control knobs.
        for z,r in((-78.1,1.5),(-77.7,1.3),(-77.3,1.05),(-76.9,.8)):
            rod([-1,8,z-.18],[-1,8,z+.18],r,'crew_boot','launcher_manual_control',n)
        rod([-1,8,-77.0],[-1,8,-74.6],.23,'crew_metal','launcher_manual_stick',8)
        rod([-1,8,-75.0],[-1,8,-74.1],.55,'crew_boot','launcher_manual_knob',n)
        for x,y in((-4.5,4),(3.7,12),(-4,12)):
            rod([x,y,-78.3],[x,y,-77.7],.7,'crew_boot','launcher_control_knob',n)
        for x in(-4,0,4):rod([x,.5,-88.0],[x,.2,-88.0],.65,'crew_equipment_edge','launcher_cable_socket',n if master else 8)
        if master:
            for x in (-4,2):
                rod([x,14.5,-79.6],[x+2,14.5,-79.6],.22,'crew_metal','launcher_lid_hinge',n)
        # The compact controller sits ahead of the forward boot and beside
        # the separate missile case. Keep the eye cup fixed at the real eye.
        for t in out:
            c=t['component']
            if 'ocular' in c:continue
            if 'periscope' in c:
                t['vertices']=[[round(x+2,6),round(y-2,6),z] for x,y,z in t['vertices']]
            else:
                t['vertices']=[[round(x+10.3,6),round((y-1)*2/3,6),z] for x,y,z in t['vertices']]
        # Case halves are low supports, not a fabricated shoulder launcher.
        block([3,10,-89.7],[43.5,19.7,-85.6],'crew_equipment_edge','launcher_sagger_case_base')
        block([3.3,10.2,-85.7],[43.2,19.5,-84.9],'crew_equipment','launcher_sagger_case_lid')
        for x in(10,28):block([x,12,-85],[x+1.2,17,-80],'crew_equipment_light','launcher_sagger_launch_support')
        turned([(6,1.6),(10,2.2),(29,2.4),(35,2.15),(40,1.3),(43,.12)],14.8,-77.7,'crew_equipment','launcher_sagger_missile',32 if master else 16)
        for x0,x1,r in((10,19,5.0),(26,31,3.3)):
            for j in range(4):
                angle=j*math.pi/2;radial=(math.cos(angle),math.sin(angle));normal=(-radial[1],radial[0])
                profile=((x0,2.25),(x0+(x1-x0)*.2,r),(x1-(x1-x0)*.1,r),(x1,2.25))
                rings=[[[x,14.8+radial[0]*radius+normal[0]*width,-77.7+radial[1]*radius+normal[1]*width] for x,radius in profile] for width in(-.16,.16)]
                solid(out,[src],rings,'crew_equipment','launcher_sagger_cruciform_fin')

    else:
        # Mil.ru field photograph: long horizontal container, guidance housing,
        # offset optical sight, cradle and three spreading legs with ground feet.
        turned([(-7,2.4),(-6.5,2.7),(40.8,2.7),(42,2.9),(43,2.9)],17,-49,'crew_equipment','launcher_spigot_canister',32 if master else 16)
        for x in(-5,29):turned([(x-.6,2.7),(x-.43,2.85),(x+.43,2.85),(x+.6,2.7)],17,-49,'crew_equipment_light','launcher_canister_band',32 if master else 16)
        turned([(43.05,2.5),(43.2,2.5)],17,-49,'crew_equipment_edge','launcher_canister_endcap',n)
        block([0,6,-65],[14,17,-55],'crew_equipment','launcher_spigot_guidance_housing')
        block([-.2,5.7,-64],[13.8,6,-63.4],'crew_equipment_light','launcher_case_seam')
        block([0,6,-65.2],[14,17,-64.4],'crew_equipment_edge','launcher_case')
        for x in(1,11):block([x,5.4,-58],[x+.7,6,-56.7],'crew_metal','launcher_case_catch')
        rod([2,5.4,-62],[10,5.4,-62],.3,'crew_boot','launcher_carry_handle',8)
        block([5,12,-55],[15,18,-52],'crew_equipment_edge','launcher_canister_cradle')
        rod([3,8,-56],[-3.5,4.1,-48.4],1.15,'crew_equipment_light','launcher_ocular_rim')
        turned([(-4.8,1.2),(-4.0,1.3),(-3.1,.9)],4.1,-48.4,'crew_boot','launcher_ocular_eyecup')
        turned([(-4.9,.75),(-4.8,.75)],4.1,-48.4,'crew_optic','launcher_ocular_glass')
        for y in(5.3,17.5):rod([3,y,-60],[3,y+.25,-60],1.1,'crew_equipment_edge','launcher_aiming_handwheel',n)
        rod([11,12,-71],[11,12,-65],1.15,'crew_equipment_edge','launcher_tripod_pivot',n)
        for x,y in((2,10),(25,3),(21,18.5)):
            rod([11,12,-70],[x,y,-88.7],.65,'crew_equipment','launcher_tripod_leg',n)
            block([x-1.5,y-.7,-90],[x+1.5,y+.7,-89],'crew_equipment_edge','launcher_tripod_foot')
    return out
