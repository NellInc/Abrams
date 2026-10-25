"""Shallow volumetric Tactical crews, constrained by source X/Z footprints.

The original round/head command remains authoritative. Individual source sheets
become rounded lofts, with integrated garment/kit relief and no sheet-face caps.
Source registry metadata and primitive attribution remain immutable.
Redundant disconnected sheet lobes are intentional empty presentation faces;
the original ownership raster still occludes actors behind every such face.
"""
import copy
import math
from pathlib import Path
from tools.build_pc_modern_assets import (
    MATERIALS, REGISTRY_FIELDS, add_face, area2, bounds, cross, dot,
    sub, validate_model,
)

FINISHES = {
    'crew_cloth': ('cloth', (87, 101, 65), None),
    'crew_cloth_light': ('cloth_light', (102, 116, 76), None),
    'crew_cloth_shadow': ('cloth_shadow', (85, 99, 68), None),
    'crew_seam': ('cloth_shadow', (67, 80, 55), None),
    'crew_webbing': ('webbing', (130, 126, 89), None),
    'crew_webbing_edge': ('webbing', (90, 94, 61), None),
    'crew_boot': ('leather', (42, 45, 39), None),
    'crew_boot_light': ('leather', (79, 72, 53), None),
    'crew_sole': ('tyre', (35, 37, 32), None),
    'crew_skin': ('skin', (187, 143, 107), None),
    'crew_skin_shadow': ('skin', (158, 114, 82), None),
    'crew_skin_light': ('skin', (217, 174, 131), None),
    'crew_equipment': ('equipment', (98, 114, 75), None),
    'crew_equipment_light': ('equipment', (130, 140, 97), None),
    'crew_equipment_edge': ('equipment_edge', (59, 73, 52), None),
    'crew_metal': ('steel', (120, 124, 107), None),
    'crew_optic': ('optic', (42, 65, 65), None),
}
MATERIALS.update({name: list(spec[1]) for name, spec in FINISHES.items()})



def _span(vertices, z, side=0):
    """Horizontal span of a source polygon, including horizontal end edges."""
    xs=[]
    for a,b in zip(vertices,vertices[1:]+vertices[:1]):
        if side and abs(a[2]-b[2])>1e-9 and min(a[2],b[2])<=z<=max(a[2],b[2]):
            if (side>0 and max(a[2],b[2])>z) or (side<0 and min(a[2],b[2])<z):
                xs.append(a[0]+(b[0]-a[0])*(z-a[2])/(b[2]-a[2]))
        if not side and abs(a[2]-z)<1e-7:xs.append(a[0])
        if min(a[2],b[2])<z<max(a[2],b[2]):
            xs.append(a[0]+(b[0]-a[0])*(z-a[2])/(b[2]-a[2]))
    return min(xs),max(xs)


def _surface(part, x, z, side, shape):
    """Material and real depth displacement of broad authored garment features.

    The shell itself carries relief; there are no overlapping coplanar patches.
    Both front and rear have cloth volume; pockets/controls occupy the front.
    """
    mat='cloth';component='crew_jacket' if part==0 else 'crew_trousers' if part<5 else 'crew_sleeve'
    lift=0.
    if part==0:
        # The jacket is one continuous cloth surface. Belts and sewn pockets
        # have deliberate borders instead of angular material-cell patches.
        if -55.6<z<-52.0:
            mat='webbing_edge';component='crew_belt';lift=.35
        if z>-18.5 and abs(x)<4.8:
            mat='skin_shadow';component='crew_neck';lift=0.
    elif part in (1,2,3,4):
        # Actual knees/cuffs have a shaped cross-section rather than painted lines.
        if part in (2,3) and z<-80.8:
            mat='boot';component='crew_boot'
            if z<-87.4:mat='sole';component='crew_boot_sole';lift=.25
            elif z>-83.3:mat='boot';component='crew_boot_cuff';lift=.45
        elif part==1 and -64<z<-60 or part==4 and -64<z<-59:
            mat='cloth_shadow';component='crew_knee_fold';lift=.35
    elif part in (5,6):
        if z<-34:
            mat='skin';component='crew_hand';lift=.1
        elif z<-31.5:
            mat='webbing_edge';component='crew_cuff';lift=.45
        elif -30<z<-27:
            mat='cloth_shadow';component='crew_elbow_fold';lift=.25
    elif part==8:
        if z>-19:
            mat='skin';component='crew_hand';lift=.15
            if side>0 and z>-13:mat='skin_light';component='crew_knuckles';lift=.35
        elif z>-22:mat='webbing_edge';component='crew_cuff';lift=.4
    elif part==9 and z<-34:
        mat='cloth_shadow';component='crew_elbow_fold';lift=.3
    elif part>=10:
        mat='equipment';component='launcher_case' if part==10 else 'launcher_sight_body'
        if part==10:
            if -11<z<-9 or -.3<z<1.4:
                mat='equipment_light';component='launcher_band';lift=.35
            if -16.7<z<-16.2 or 3.5<z<4.1:
                mat='equipment_edge';component='launcher_case_seam';lift=-.12
            if side>0 and 18<x<29 and -8<z<-2:
                mat='equipment_edge';component='launcher_control_panel';lift=.5
                if shape==161 and x>25 and z>-5.5:
                    mat='boot';component='launcher_manual_control';lift=1.4
                elif shape==162 and x<23 and z>-6:
                    mat='optic';component='launcher_sight';lift=1.1
        else:
            if z<8:mat='metal';component='launcher_collar';lift=.4
            if side>0 and 7<x<13 and 18<z<23:
                mat='optic';component='launcher_optic';lift=.9 if shape==161 else 1.4
            elif z>23:mat='equipment_edge';component='launcher_optic_hood';lift=.6
    return 'crew_'+mat,component,lift


def _rows(vertices, part):
    lo=min(v[2] for v in vertices);hi=max(v[2] for v in vertices)
    specific={
        0:(-59,-55.6,-54.5,-50.6,-48,-40.5,-32.5,-30.4,-29,-24,-21,-18.5),
        1:(-64,-62,-59,-55),2:(-87.4,-83.3,-80.8,-76,-70),
        3:(-87.4,-83.3,-80.8,-76,-70),4:(-80,-72,-64,-59,-52),
        5:(-37,-34,-31.5,-30,-27,-23),6:(-37,-34,-31.5,-30,-27,-23),
        8:(-35,-29,-24,-22,-19,-16,-13),9:(-37,-34,-31,-28),
        10:(-16.7,-16.2,-13,-11,-9,-8,-6,-5.5,-2,-.3,1.4,3.5,4.1),
        11:(6,8,12,17,18,20,23,24),
    }[part]
    return sorted({lo,hi,*[v[2] for v in vertices],*[z for z in specific if lo<z<hi]})


# Bone-aligned stations are (X,Z,in-plane radius,depth). The existing pose is
# retained, with rounded deltoids, knees, wrists and ankles inside each owner.
LIMBS={
    1:((16,-56,2.4,4.8),(20,-57.5,4.2,5.8),(27,-60,4.6,6.0),(32.5,-62.5,2.7,5.1)),
    2:((33.8,-64,3.2,5.1),(33.5,-68.5,4.3,5.4),(34,-77,3.2,4.2),(34,-83.5,3.8,5.5),(34,-88.7,4.7,6.0)),
    3:((-4.8,-62,4.9,5.6),(-6,-69,4.2,5.3),(-7.2,-78,3.2,4.3),(-8,-84,4.0,5.5),(-9,-88.7,4.4,6.0)),
    4:((-28.5,-49,1.0,3.4),(-26.2,-57,2.8,5.0),(-21.5,-68,2.8,4.4),(-17.5,-79,1.7,3.8),(-16.1,-86,0.7,3.0)),
    5:((-10.8,-21,3.1,4.8),(-10.9,-24.5,3.2,5.0),(-8.4,-28.8,3.4,4.8),(-2.8,-32.2,3.2,4.0),(2.6,-33.9,2.5,3.4),(5.8,-35.0,2.3,3.1),(7.1,-35.6,1.0,2.4)),
    6:((18.8,-20.5,1.0,5.0),(23,-22,3.3,5.4),(24.5,-25.5,3.2,5.2),(22,-28,3.5,4.7),(16,-31.2,3.5,4.2),(10,-34.3,2.6,3.3),(7.5,-35.2,1.6,2.5)),
    8:((41.5,-38.2,2.5,3.8),(41.5,-31,3.1,4.4),(41.5,-23,2.4,3.1),(41.5,-19.6,2.1,2.8),(41.5,-16,3.25,3.7),(41.5,-12.5,3.45,3.9),(41.5,-10,3.0,3.5),(41.5,-9.08,1.0,1.2)),
    9:((25.5,-28.6,1.5,3.9),(29.2,-30.5,2.2,4.4),(34,-33.4,2.7,4.5),(37.1,-35.2,.7,3.4)),
}


def _contact_ring(center, planar, depth, count):
    """A shared section lies on both original polygon edges, never across them."""
    x,y,z=center;px,pz=planar
    return [[round(x+px*math.cos(j*math.tau/count),6),
             round(y+depth*math.sin(j*math.tau/count),6),
             round(z+pz*math.cos(j*math.tau/count),6)] for j in range(count)]


def _limb_rings(vertices,part,master,cy):
    stations=list(LIMBS[part])
    if master:
        stations=[v for a,b in zip(stations,stations[1:]) for v in (a,tuple((x+y)/2 for x,y in zip(a,b)))]+[stations[-1]]
    n=20 if master else 14;rings=[]
    low=min(v[2] for v in vertices);high=max(v[2] for v in vertices)
    for i,(x,z,radius,depth) in enumerate(stations):
        a=stations[max(0,i-1)];b=stations[min(len(stations)-1,i+1)]
        dx,dz=b[0]-a[0],b[1]-a[1];length=math.hypot(dx,dz);px,pz=-dz/length,dx/length
        def valid(scale):
            for j in range(n):
                c=math.cos(j*math.tau/n);xx=x+px*radius*scale*c;zz=z+pz*radius*scale*c
                if not low+1e-5<zz<high-1e-5:return False
                left,right=_span(vertices,zz)
                if not left+1e-5<=xx<=right-1e-5:return False
            return True
        if not valid(0):raise ValueError(f'Limb station outside source {part}/{i}')
        lo,hi=0.,1.
        for _ in range(24):
            mid=(lo+hi)/2
            if valid(mid):lo=mid
            else:hi=mid
        scale=min(1.,lo*.995)
        ring=[]
        for j in range(n):
            c=math.cos(j*math.tau/n);ss=math.sin(j*math.tau/n)
            xx=x+px*radius*scale*c;zz=z+pz*radius*scale*c
            # A gently asymmetric palm/boot toe keeps a human profile in depth.
            toe=.35 if part in (2,3) and z<-83 and ss<0 else 0.
            yy=cy+ss*(depth+toe)
            ring.append([round(xx,6),round(yy,6),round(zz,6)])
        rings.append(ring)
    # The old inset terminal stations left visible gaps. Seat terminal sections
    # on the original shared knee/elbow edges, using identical perimeter points.
    if part==1:
        rings[0]=_contact_ring((14.5,10.8,-55),(.45,4.5),4.5,n)
        rings[-1]=_contact_ring((33,7,-63),(5,2),5.1,n)
    elif part==2:
        rings[0]=_contact_ring((33,7,-63),(5,2),5.1,n)
        rings[-1]=_contact_ring((34,7,-90),(5.5,0),7.0,n)
    elif part==3:
        rings[0]=_contact_ring((-4,10.8,-60),(6,0),5.0,n)
        rings[-1]=_contact_ring((-9,7,-90),(5.5,0),7.0,n)
    elif part==6:rings[0]=_contact_ring((18.8,8.5,-20.5),(1,0),5.0,n)
    elif part==9:rings[-1]=_contact_ring((38,5.7,-35),(0,4.7),4.0,n)
    return rings


def _blocking_geometry(base, master=False):
    """Build source-attributed rounded anatomy, without runtime pose changes."""
    if base['shape_index'] not in (161,162):raise ValueError('Crew recipe requires shape 161 or 162')
    model=copy.deepcopy(base);out=[]
    shape=base['shape_index']
    for part,source in enumerate(base['source_primitives']):
        vertices=source['vertices']
        if not vertices or part in (4,8,9,10,11):continue
        groups=[g['offset'] for g in base['groups'] if source['id'] in g['primitive_pointers']]
        # Arms sit proud of the jacket; the case uses the source's positive-Y
        # equipment envelope. All relief remains strictly inside [-1,20].
        cy,depth=((10.8,7.5) if part==0 else (7.,5.8) if part<5 else
                  (5.7,5.0) if part<10 else (13.,5.4))
        sides=(40 if master else 32) if part==0 else (24 if master else 16)
        rows=_rows(vertices,part)
        if part==0:rows=sorted(set(rows+list(range(-58,-16,2))))
        if master:rows=sorted(set(rows+[(a+b)/2 for a,b in zip(rows,rows[1:])]))
        # Horizontal ledges need two sections at the same Z. The torso's
        # shoulder shelf narrows abruptly into the neck; interpolating one
        # full-width ring to the neck would escape the concave source polygon.
        sections=[]
        for z in rows:
            spans=[]
            if z>rows[0]:spans.append(_span(vertices,z,-1))
            if z<rows[-1]:spans.append(_span(vertices,z,1))
            for span in spans:
                if not sections or sections[-1]!=(z,span):sections.append((z,span))
        rings=[]
        for z,(left,right) in sections:
            cx=(left+right)/2;rx=(right-left)/2
            if part==0:
                # Keep the actual shoulder/hip contacts; only the waist draws in.
                rx*=1.-.055*math.exp(-((z+43)/6.)**2)
                if z>=-20:rx*=.66+.34*min(1.,(-z-16)/4) if z<=-16 else 1.
            ry=min(depth,rx*.95)
            ring=[]
            for j in range(sides):
                angle=2*math.pi*j/sides;c,s=math.cos(angle),math.sin(angle)
                # Case/periscope are bevelled rectangular housings; anatomy is
                # elliptical, with small cuff/fold radius changes sewn into it.
                if part>=10:
                    c=math.copysign(abs(c)**.25,c);s=math.copysign(abs(s)**.25,s)
                x=cx+rx*c
                # The original operator faces negative Y. Keep pockets and
                # controls on that side, with the jacket seam on the rear.
                mat,component,lift=_surface(part,x,z,-1 if s>=0 else 1,shape)
                # End cross-sections taper in depth; extrema retain the source
                # X/Z outline. No original X/Z sheet closes the rounded body.
                end=min(1.,.48+(z-rows[0])*.28,.48+(rows[-1]-z)*.28)
                crease={0:-46.,1:-61.,2:-75.,3:-74.,4:-60.,5:-28.,6:-29.,8:-25.,9:-34.}.get(part)
                fold=1. if crease is None else 1.+.07*math.exp(-((z-crease)/2.1)**2)-.04*math.exp(-((z-crease-2.)/1.4)**2)
                anatomy=1.+.10*math.exp(-((z+31)/8)**2)-.09*math.exp(-((z+49)/5)**2) if part==0 else 1.
                y=cy+s*min(8.8,(ry*end*fold*anatomy+lift))
                ring.append([round(x,6),round(y,6),z])
            rings.append(ring)
        if part in LIMBS:
            rings=_limb_rings(vertices,part,master,cy);sides=len(rings[0])
        def face(points,mat,component,inside=None):
            for tri in [points] if len(points)==3 else ([points[0],points[1],points[2]],[points[0],points[2],points[3]]):
                if area2(tri)<=1e-8:continue
                z=sum(p[2] for p in tri)/3;left,right=_span(vertices,z)
                interior=inside if inside is not None else [(left+right)/2,cy,z]
                normal=cross(sub(tri[1],tri[0]),sub(tri[2],tri[0]))
                if dot(normal,sub([sum(p[k] for p in tri)/3 for k in range(3)],interior))<0:tri=list(reversed(tri))
                add_face(out,tri,mat,source['id'],groups,component)
        for a,b in zip(rings,rings[1:]):
            for j in range(sides):
                k=(j+1)%sides
                x=sum(p[0] for p in (a[j],a[k],b[k],b[j]))/4
                z=(a[j][2]+b[j][2])/2
                side=1 if sum(p[1] for p in (a[j],a[k],b[k],b[j]))/4<cy else -1
                mat,component,_=_surface(part,x,z,side,shape)
                interior=[sum(v[k] for v in a+b)/(2*sides) for k in range(3)]
                face([a[j],a[k],b[k],b[j]],mat,component,interior)
        # Caps follow each bone's actual axis. No original painter sheet is
        # reinstated over the anatomy.
        for index,other in ((0,1),(-1,-2)):
            ring=rings[index];ctr=[sum(v[k] for v in ring)/sides for k in range(3)]
            interior=[sum(v[k] for v in rings[other])/sides for k in range(3)]
            for j in range(sides):
                mat,component,_=_surface(part,ctr[0],ctr[2],1,shape)
                face([ctr,ring[j],ring[(j+1)%sides]],mat,component+'_end',interior)
        if part==0:
            from tools.build_pc_tactical_vehicles import box,tube,solid
            src=dict(source,groups=groups)
            def block(a,b,material,label):
                box(out,[src],a,b,'crew_'+material,label)
            # Compact guidance/control unit held at chest height. These fit
            # wholly inside the jacket owner, so no source-mask expansion is
            # needed to support them and no old floating case is reinstated.
            outline=[(-2.8,-39),(9.5,-39),(10.2,-38.3),(10.2,-30.7),
                     (9.5,-30),(-2.8,-30),(-3.5,-30.7),(-3.5,-38.3)]
            solid(out,[src],[[[x,y,z] for x,z in outline] for y in (3.5,-.25)],
                  'crew_equipment','launcher_case')
            inset=[(x+(3.35-x)*.025,z+(-34.5-z)*.025) for x,z in outline]
            solid(out,[src],[[[x,-.25,z] for x,z in outline],[[x,-.6,z] for x,z in inset]],
                  'crew_equipment_light','launcher_case_bevel',cap_start=False)
            block([-3.0,-.8,-38.5],[9.7,-.55,-37.9],'equipment_edge','launcher_case_seam')
            for x in (-2.7,8.0):
                block([x,-.95,-32],[x+1.1,-.5,-30.8],'metal','launcher_case_catch')
            for x in (-1.3,6.5):
                block([x,-.9,-38],[x+.8,1,-36.3],'equipment_edge','launcher_handle_standoff')
            block([-1.3,-.95,-38],[7.3,-.55,-37.3],'metal','launcher_carry_handle')
            if shape==161:
                # Sagger manual-control box with a recessed joystick well.
                block([2.0,-.85,-35.6],[6.2,-.65,-32.7],'boot','launcher_manual_control')
                tube(out,[src],[4.1,-.4,-34],[4.1,-.7,-32.2],.25,
                     'crew_boot','launcher_manual_stick',12 if master else 8)
            else:
                # Spigot's compact optical head is distinct from the manual box.
                tube(out,[src],[3.5,1.4,-28.0],[3.5,-.8,-28.0],2.3,
                     'crew_equipment_edge','launcher_ocular_rim',20 if master else 16)
                tube(out,[src],[3.5,-.72,-28.0],[3.5,-.88,-28.0],1.6,
                     'crew_optic','launcher_ocular_glass',20 if master else 16)
                block([1.5,1.0,-32],[5.5,3.6,-27],'equipment','launcher_sight_mount')
            # Tailored chest pocket, flap and belt buckle, seated on the shell.
            block([-8,2.3,-47.0],[-2,7.8,-40.8],'cloth','crew_chest_pocket')
            block([-8.1,2.15,-42.0],[-1.9,8,-40.6],'cloth_light','crew_pocket_flap')
            block([.2,2.2,-55.0],[3.4,8,-52.4],'metal','crew_buckle')
        if part in (5,6):
            # A palm and thumb at the end of each sleeve, never extra arms.
            # All points are projected into this same original arm footprint.
            def hand_volume(center,radii,label):
                count=12 if master else 10;rows=6 if master else 4;rr=[]
                for i in range(rows+1):
                    angle=-math.pi/2+math.pi*i/rows;ss=max(.01,math.cos(angle))
                    z=center[2]+radii[2]*math.sin(angle);left,right=_span(vertices,z)
                    rr.append([[min(right-.02,max(left+.02,center[0]+radii[0]*ss*math.cos(j*math.tau/count))),
                                max(-.96,center[1]+radii[1]*ss*math.sin(j*math.tau/count)),z]
                               for j in range(count)])
                for a,b in zip(rr,rr[1:]):
                    for j in range(count):face([a[j],a[(j+1)%count],b[(j+1)%count],b[j]],'crew_skin',label,center)
            x,y,z=(5.5,2.8,-34.9) if part==5 else (8.8,2.5,-34.9)
            hand_volume((x,y,z),(2.4,1.55,2.4),'crew_hand_palm')
            hand_volume((x-1.0,y-1.2,z+1.5),(.9,.75,1.55),'crew_hand_thumb')
            for dx in (-.8,.2,1.2):
                hand_volume((x+dx,y-1.25,z-.9),(.6,.5,.8),'crew_hand_knuckle')
    model['source_passthrough']=[]
    model['triangles']=out;model['bounds']=bounds([v for t in out for v in t['vertices']])
    validate_model(model)
    if not master and not 2000<=len(out)<=6500:raise ValueError('Crew runtime facet target')
    for key in (*REGISTRY_FIELDS,'status','source_bounds'):
        if model[key]!=base[key]:raise ValueError('Crew source metadata changed: '+key)
    return model


def formed_hands(base,master=False):
    """Two fitted grips, with four curled digits and mirrored opposed thumbs.

    Fingers stay explicit after retopology so voxel relaxation cannot merge
    them into a single mitten. They remain inside the original torso owner.
    """
    from tools.build_pc_tactical_vehicles import solid
    out=[];source=base['source_primitives'][0]
    src=dict(source,groups=[g['offset'] for g in base['groups'] if source['id'] in g['primitive_pointers']])
    count=12 if master else 8
    def digit(stations,label):
        rings=[]
        for i,(p,radius) in enumerate(stations):
            a=stations[max(0,i-1)][0];b=stations[min(len(stations)-1,i+1)][0]
            axis=sub(b,a);length=math.sqrt(dot(axis,axis));axis=[v/length for v in axis]
            guide=[1,0,0]
            right=cross(axis,guide);length=math.sqrt(dot(right,right));right=[v/length for v in right];up=cross(axis,right)
            rings.append([[round(p[k]+radius*(right[k]*math.cos(j*math.tau/count)+up[k]*math.sin(j*math.tau/count)),6)
                           for k in range(3)] for j in range(count)])
        def face(points,component):
            add_face(out,points,'crew_skin',source['id'],src['groups'],component)
        # A consistent frame and explicit diagonals keep curved sections closed.
        # Ear-clipping a twisted quad can discard one of its boundary edges.
        for row,(a,b) in enumerate(zip(rings,rings[1:])):
            component='crew_hand_knuckle' if row==0 and label!='crew_hand_thumb' else label
            for j in range(count):
                k=(j+1)%count
                face([a[j],a[k],b[k]],component);face([a[j],b[k],b[j]],component)
        for ring,reverse in ((rings[0],True),(rings[-1],False)):
            # Planar ring caps retain the curvature budget for the digits.
            for j in range(1,count-1):
                points=[ring[0],ring[j],ring[j+1]]
                face(points[::-1] if reverse else points,label)
    for side,x,inner in (('left',2.0,1),('right',9.8,-1)):
        rings=[]
        palm_count=12 if master else 8
        # A broad metacarpal pad joins the fingers instead of exposing bony roots.
        for z,shift,rx,ry,cy in ((-33.15,0,1.15,.80,1.72),(-34.05,.10,1.95,1.10,1.60),
                                (-35.0,0,1.95,1.12,1.55),(-35.8,-.10,1.55,.90,1.50)):
            rings.append([[round(x+inner*shift+rx*math.cos(j*math.tau/palm_count),6),
                           round(cy+ry*math.sin(j*math.tau/palm_count),6),z] for j in range(palm_count)])
        solid(out,[src],rings,'crew_skin','crew_hand_palm')
        for name,offset,extra,root,radius in (('index',1.30,.10,-34.35,.59),
                                            ('middle',.43,.42,-34.55,.61),
                                            ('ring',-.44,.25,-34.40,.58),
                                            ('little',-1.27,-.32,-34.05,.49)):
            fx=x+inner*offset
            digit([([fx+inner*.10,1.32,root],radius),
                   ([fx+inner*.06,.18,-35.2-extra*.15],radius*.96),
                   ([fx-inner*.08,.28,-36.05-extra*.75],radius*.86),
                   ([fx-inner*.14,1.13 if name=='little' else 1.02,-36.65-extra],radius*.64)],'crew_hand_'+side+'_'+name)
        digit([([x+inner*.95,1.5,-33.75],.75),([x+inner*1.70,.75,-33.15],.68),
               ([x+inner*1.20,.25,-33.35],.53),([x+inner*.55,.55,-33.95],.31)],'crew_hand_thumb')
    return out


SCULPT_PATH = Path(__file__).resolve().parents[1]/'local-art/pc-tactical-crew-ground-v1/geometry.json.gz'


def geometry(base, master=False):
    """Load the Blender sculpt with its original per-primitive attribution."""
    import gzip,json,hashlib
    generator=SCULPT_PATH.parents[1].parent/'tools/sculpt_pc_tactical_ground_crews.py'
    with gzip.open(SCULPT_PATH,'rt',encoding='utf-8') as f:data=json.load(f)
    if (data['generator_sha256']!=hashlib.sha256(generator.read_bytes()).hexdigest() or
        data['recipe_sha256']!=hashlib.sha256(Path(__file__).read_bytes()).hexdigest() or
        data.get('ground_recipe_sha256')!=hashlib.sha256(generator.with_name('pc_tactical_ground_crews.py').read_bytes()).hexdigest()):
        raise ValueError('Crew Blender sculpt is stale; rerun tools/sculpt_pc_tactical_ground_crews.py in Blender')
    model=copy.deepcopy(base)
    model['triangles']=data['states'][str(base['shape_index'])]['master' if master else 'game']
    model['source_passthrough']=[]
    model['presentation_pose']=copy.deepcopy(data['presentation_pose'])
    model['bounds']=bounds([v for t in model['triangles'] for v in t['vertices']])
    validate_model(model)
    return model
