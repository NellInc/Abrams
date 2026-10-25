"""Reference-led Hind shells, strictly partitioned by observed source owner.

Shapes 163 and 164 differ only in the line-only main rotor state.  Their filled
owners are aliases.  Nothing in this module generates rotor blades or motion.
Coordinates are original engine-local units, +Y forward, +Z up.
"""
from __future__ import annotations

import math


def geometry(base, master=False):
    # Local import avoids a circular dependency when the roster builder dispatches.
    from tools.build_pc_tactical_vehicles import source_groups, emit, solid, box, tube

    groups = source_groups(base)
    out = []
    n = 32 if master else 24

    def paint(y, j, count, lower=False):
        # Broad, contiguous piebald patches; the underside stays sky blue.
        t = j * math.tau / count
        if lower and math.sin(t) < -.38:
            return 'hind_blue'
        return 'hind_pale' if math.cos(y / 67 + .8 * math.sin(t)) + .65 * math.cos(2*t) > .35 else 'hind_olive'

    def loft(src, stations, name, material=None, count=n, lower=False, x=0):
        """Y-axis ellipsoidal sections, each station is y, width, centre, height."""
        rings = [[[x + w*math.cos(j*math.tau/count), y,
                   z + h*math.sin(j*math.tau/count)] for j in range(count)]
                 for y, w, z, h in stations]
        inside = [x, sum(s[0] for s in stations)/len(stations),
                  sum(s[2] for s in stations)/len(stations)]
        for k, (a, b) in enumerate(zip(rings, rings[1:])):
            for j in range(count):
                mat = material or paint(stations[k][0], j, count, lower)
                owner = src
                if src is groups[5]:
                    yy=(stations[k][0]+stations[k+1][0])/2
                    lateral=math.cos((j+.5)*math.tau/count)
                    if abs(lateral)>.45:
                        # Side faces share normals, so normal matching alone
                        # would silently drop the right forward owner entirely.
                        pi=(4 if lateral>0 else 3) if yy>=-40 else (1 if lateral>0 else 2)
                    else:
                        pi=6 if yy>=100 else 5
                    owner=[src[pi]]
                emit(out, owner, [a[j], a[(j+1)%count], b[(j+1)%count], b[j]], mat, name, inside)
        for ring in (rings[0], rings[-1]):
            emit(out, src, ring, material or 'hind_olive', name, inside)
        return rings

    def wing_paint(start,quad,src):
        """Partition the real upper wing facets; paint adds no second skin."""
        from tools.build_pc_modern_assets import cross,sub,triangulate,clean_polygon
        original=out[start:];del out[start:]
        sign=1 if sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(quad,quad[1:]+quad[:1]))>0 else -1
        def clip(poly,a,b,inside):
            result=[]
            def distance(p):return sign*((b[0]-a[0])*(p[1]-a[1])-(b[1]-a[1])*(p[0]-a[0]))*(1 if inside else -1)
            for p,q in zip(poly,poly[1:]+poly[:1]):
                u,v=distance(p),distance(q)
                if u>=0:result.append(p)
                if (u>=0)!=(v>=0):result.append([p[k]+u/(u-v)*(q[k]-p[k]) for k in range(3)])
            return clean_polygon(result)
        for t in original:
            points=t['vertices'];a,b,c=points
            if t['component']!='stub_wing' or cross(sub(b,a),sub(c,a))[2]<=0:
                out.append(t);continue
            owner=[p for p in src if p['id']==t['source_primitive']]
            poly=points
            for a,b in zip(quad,quad[1:]+quad[:1]):
                if len(poly)<3:break
                outside=clip(poly,a,b,False)
                for face in triangulate(outside):emit(out,owner,face,'hind_olive','stub_wing')
                poly=clip(poly,a,b,True)
            for face in triangulate(poly):emit(out,owner,face,'hind_pale','stub_wing_piebald')

    hull, upper = groups[0], groups[5]
    # The lower fuselage has a broad troop compartment, a tapered belly and
    # rounded nose. The independently observed dorsal owner starts at z=60.
    hull_rings = loft(hull, [(-300,2,59,1),(-240,11,51,9),(-165,24,39,20),
                (-90,48,20,38),(-40,65,12,47),(25,69,10,49),
                (85,67,11,48),(145,59,12,45),(205,45,12,40),
                (253,33,11,33),(280,20,9,24),(290,4,8,13)],
         'sculpted_fuselage', lower=True)
    def skin_x(y, z, side):
        # Interpolate the actual authored polygonal skin, keeping detail attached
        # to the rounded body rather than floating at the source box's width.
        a,b=next((a,b) for a,b in zip(hull_rings,hull_rings[1:])
                 if a[0][1]<=y<=b[0][1])
        t=(y-a[0][1])/(b[0][1]-a[0][1])
        ring=[[u[k]*(1-t)+v[k]*t for k in range(3)] for u,v in zip(a,b)]
        candidates=[]
        for u,v in zip(ring,ring[1:]+ring[:1]):
            if min(u[2],v[2])<=z<=max(u[2],v[2]) and abs(u[2]-v[2])>1e-8:
                f=(z-u[2])/(v[2]-u[2]);candidates.append(u[0]+f*(v[0]-u[0]))
        return side*(max(candidates)+.35)

    # Dorsal engine/gearbox fairing and upper tail boom retain group 5.
    loft(upper, [(-300,2,81,20),(-245,10,78,18),(-170,23,77,17),
                 (-95,44,79,19),(-40,54,82,22),(20,54,82,22),
                 (75,47,80,20),(105,35,76,16)], 'dorsal_fairing')

    # Raised rear pilot and lower forward gunner canopy, separated by a painted
    # inter-seat bridge. Curved panes stay restrained instead of opaque cyan.
    for label, stations in (
        ('pilot',[(69,25,78,17),(87,36,88,28),(112,38,91,32),
                  (142,34,88,31),(162,20,79,20),(171,5,69,9)]),
        ('gunner',[(161,18,69,9),(178,29,76,19),(203,32,79,23),
                   (229,27,74,21),(249,16,65,14),(260,3,61,2)])):
        rings = loft(upper, stations, label+'_canopy', 'optic', count=16)
        # Narrow metal frames follow the canopy crown and lateral sill.
        for k in (1, len(rings)-2):
            ring = rings[k]
            for j in range(8):
                tube(out, upper, ring[j], ring[j+1], .7, 'hind_olive', label+'_arch_frame', 6)
        for j in (0,4,8):
            for a,b in zip(rings,rings[1:]):
                tube(out, upper, a[j], b[j], .65, 'hind_olive', label+'_longitudinal_frame', 6)
        # Opaque lower canopy skirts obscure the underside of the closed glazing.
        for side in (-1,1):
            for a,b in zip(rings,rings[1:]):
                j=0 if side==1 else 8
                emit(out, upper, [[a[j][0],a[j][1],60],a[j],b[j],
                                 [b[j][0],b[j][1],60]], 'hind_olive',label+'_armoured_sill')

    # Paired axial turbines: round intake lips, recessed intake discs and rear
    # exhaust mouths. There are no modern countermeasure or sensor upgrades.
    for side in (-1,1):
        xx=side*37
        loft(upper,[(-79,9,89,10),(-60,17,91,16),(-25,19,93,19),
                    (20,18,94,18),(54,16,94,16),(75,14,94,14)],
             'engine_nacelle',x=xx)
        tube(out,upper,[xx,75,94],[xx,79,94],14,'hind_pale','intake_lip',n,tip=13)
        tube(out,upper,[xx,79.05,94],[xx,79.3,94],10.8,'vent','recessed_engine_intake',n)
        tube(out,upper,[xx,-68,91],[xx,-83,91],10.5,'steel','exhaust_lip',n,tip=11.5)
        tube(out,upper,[xx,-83.1,91],[xx,-83.3,91],9.2,'vent','exhaust_opening',n)
        for yy in (-38,-22,-6):
            tube(out,upper,[xx-12,yy,108],[xx+12,yy,108],.65,'vent','engine_access_seam',6)
    tube(out,upper,[0,-5,99],[0,-5,131],5.5,'steel','main_mast',n,tip=4)
    tube(out,upper,[0,-5,126],[0,-5,137],10,'steel','stationary_hub_fairing',n,tip=8)
    # No main-rotor geometry: group 6 remains the engine's original line program.

    # Fin is the thin, swept source-owned tail silhouette. Small thickness gives
    # the painted edge volume without broadening it into an invented rotor.
    profile=[(-300,68),(-380,61),(-425,177),(-398,162),(-306,103)]
    solid(out,[upper[0]],[[[xx,y,z] for y,z in profile] for xx in (-3,3)],
          'hind_olive','swept_tail_fin')
    for side in (-1,1):
        emit(out,[upper[0]],[[side*3.05,-395,110],[side*3.05,-412,153],
                        [side*3.05,-384,140],[side*3.05,-350,84]],
             'hind_pale','fin_piebald_patch',[0,-380,110])

    # Original separate left/right stub-wing owners retain independent coverage.
    for gi,side in ((3,-1),(4,1)):
        src=groups[gi]
        root=side*65;tip=side*199
        start=len(out)
        solid(out,src,[[[root,-40,31],[tip,-36,27],[tip,48,27],[root,60,35]],
                       [[root,-40,37],[tip,-36,30],[tip,48,30],[root,60,40]]],
              'hind_olive','stub_wing')
        wing_paint(start,[[side*102,-35],[side*164,-32],[side*176,47],[side*136,53]],src)
        # One pylon for each independently observed pod, plus source tip marker.
        box(out,src,[min(side*144,side*151),-20,18],
            [max(side*144,side*151),10,29],'hind_olive','pod_pylon')
        tube(out,src,[tip,-33,30],[tip,-25,30],1,'red','wingtip_marker',8)

    # Groups 1 and 2 are the two source-red side pods, not the wing owners.
    # Avoid declaring a precise rocket model or loading from this coarse source.
    for gi,side in ((1,-1),(2,1)):
        src=groups[gi];xx=side*148
        loft(src,[(-39,4,11,4),(-31,12,11,11),(58,12,11,11),
                  (75,10,11,9),(85,8,11,7)],'source_observed_pod','hind_olive',count=n,x=xx)
        tube(out,src,[xx,85,11],[xx,86,11],7.5,'red','source_red_pod_face',n)
        # Discrete dark bores, rather than an invented modern missile launcher.
        for j in range(7):
            t=j*math.tau/6 if j<6 else 0
            dx=4.6*math.cos(t) if j<6 else 0
            dz=4.6*math.sin(t) if j<6 else 0
            tube(out,src,[xx+dx,86.1,11+dz],[xx+dx,86.3,11+dz],
                 1.25,'vent','pod_face_recess',8)
        for y in (-19,45):
            tube(out,src,[xx,y,11],[xx,y+1.4,11],12.3,'steel','pod_band',n)

    # Closed/retracted undercarriage is consistent with the airborne source.
    # Shallow door seams and wheel recesses stay inside the lower owner envelope;
    # extended wheels would invent a new gear state beyond the source belly.
    for side in (-1,1):
        for yy in (-30,65):
            def door_point(y,z):return [skin_x(y,z,side)+side*.08,y,z]
            for y in (yy,yy+11,yy+22):
                for z in (-6,1,8):
                    quad=[door_point(y,z),door_point(y+11,z),door_point(y+11,z+7),door_point(y,z+7)]
                    emit(out,hull,quad if side==1 else quad[::-1],'hind_olive','main_gear_door')
            for z in (-4,13):
                for y in (yy,yy+11,yy+22):
                    tube(out,hull,door_point(y,z),door_point(y+11,z),.32,'vent','gear_door_seam',6)
        # Four cabin windows and door edges, separately framed, below z=60.
        for yy in (-15,17,49,81):
            def pane(y0,y1,z0,z1,offset=0):
                quad=[[skin_x(y,z,side)+side*offset,y,z]
                      for y,z in ((y0,z0),(y1,z0),(y1,z1),(y0,z1))]
                return quad if side==1 else quad[::-1]
            emit(out,hull,pane(yy,yy+22,31,48),'hind_pale','cabin_window_frame')
            emit(out,hull,pane(yy+2,yy+20,33,46,.15),'optic','cabin_window')
        for yy in (-20,105):
            # The segmented edge follows the body curvature at every height.
            for z0,z1 in ((2,15),(15,28),(28,40),(40,51)):
                tube(out,hull,[skin_x(yy,z0,side),yy,z0],
                     [skin_x(yy,z1,side),yy,z1],.5,'vent','cabin_door_seam',6)
        tube(out,hull,[skin_x(95,24,side),95,24],
             [skin_x(104,24,side),104,24],.65,'steel','cabin_door_handle',8)
    # Nose landing-light and compact weapon fairing are within the source nose;
    # no specific four-barrel turret or unobserved side cannon is asserted.
    loft(hull,[(233,11,-9,9),(253,14,-10,12),(274,9,-9,8)],
         'chin_fairing','hind_blue',count=16)
    tube(out,hull,[0,278,-7],[0,280,-7],6,'optic','nose_aperture',16)
    if not master and len(out)>8192:
        raise ValueError(f'Hind runtime triangle budget exceeded: {len(out)}')
    return out
