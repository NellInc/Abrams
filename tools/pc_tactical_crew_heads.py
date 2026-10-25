"""Authored volumetric heads for the independently observed crew round command.

The polygon body and its source bounds are untouched. Raw head coordinates are
used in editable exports; runtime records normalize X/Y by 18 and Z by 15.
"""
import math
from tools.build_pc_modern_assets import MATERIALS, add_face, bounds

FINISHES={
    'crew_head_skin':('skin',(187,143,107),None),
    'crew_head_skin_light':('skin',(204,158,119),None),
    'crew_head_skin_shadow':('skin',(151,110,82),None),
    'crew_head_lip':('skin',(133,86,66),None),
    'crew_head_eye':('skin',(162,157,130),None),
    'crew_head_iris':('rubber',(40,47,37),None),
    'crew_head_brow':('cloth_shadow',(77,66,45),None),
    'crew_head_helmet':('equipment',(91,107,68),None),
    'crew_head_rim':('leather',(57,67,43),None),
    'crew_head_strap':('webbing',(81,82,56),None),
    'crew_head_collar':('cloth',(87,101,65),None),
}
MATERIALS.update({k:list(v[1]) for k,v in FINISHES.items()})

def geometry(base,master=False):
    shape=base['shape_index']
    if shape not in (161,162):raise ValueError('Crew head shape')
    command=next(c for c in base['visual_commands'] if c['command_bytes']==[170,15,2,171])
    out=[];n=40 if master else 20
    def face(points,material,component):
        add_face(out,points,'crew_head_'+material,command['command_offset'],[],'crew_head_'+component)
    def loft(stations,material,component,count=n):
        rings=[[[x+rx*math.cos(j*math.tau/count),y+ry*math.sin(j*math.tau/count),z] for j in range(count)] for x,y,z,rx,ry in stations]
        for a,b in zip(rings,rings[1:]):
            for j in range(count):
                k=(j+1)%count;face([a[j],a[k],b[k],b[j]],material,component)
        for ring,station,reverse in ((rings[0],stations[0],True),(rings[-1],stations[-1],False)):
            for j in range(count):
                t=[list(station[:3]),ring[j],ring[(j+1)%count]]
                face(t[::-1] if reverse else t,material,component+'_end')
    def oval(c,r,material,component,count=12,rows=6):
        stations=[]
        for i in range(rows+1):
            a=-math.pi/2+math.pi*i/rows;s=max(.012,math.cos(a))
            stations.append((c[0],c[1],c[2]+r[2]*math.sin(a),r[0]*s,r[1]*s))
        loft(stations,material,component,count)
    # Preserve a natural helmet/jaw silhouette inside the original head mask.
    # Facial landmarks share one continuous skin, including the nose bridge,
    # sockets and lips. Separate oval noses made the prior profile look assembled.
    skin=[(0,-.2,-14,3.8,3.4),(0,-1.1,-12.2,6.65,5.55),(0,-.7,-10,8.1,6.3),(0,-.2,-8.5,9.3,6.2),
          (0,0,-4,10.4,7.0),(0,.2,1.5,11.0,7.5),(0,.4,6.1,10.6,7.9),
          (0,.5,9,8.0,6.4)]
    def profile(z):
        index=next(i for i,(a,b) in enumerate(zip(skin,skin[1:])) if a[2]<=z<=b[2])
        a,b=skin[index:index+2];t=(z-a[2])/(b[2]-a[2]);before=skin[max(0,index-1)];after=skin[min(len(skin)-1,index+2)]
        def interpolate(k):
            m0=(b[k]-before[k])/(b[2]-before[2]);m1=(after[k]-a[k])/(after[2]-a[2])
            return (2*t**3-3*t*t+1)*a[k]+(t**3-2*t*t+t)*(b[2]-a[2])*m0+(-2*t**3+3*t*t)*b[k]+(t**3-t*t)*(b[2]-a[2])*m1
        return tuple(interpolate(k) for k in (1,3,4))
    def relief(x,z):
        def g(cx,cz,sx,sz):return math.exp(-((x-cx)/sx)**2-((z-cz)/sz)**2)
        nose=1.25*g(0,-1.5,.95,2.8)+2.15*g(0,-4.0,1.35,1.0)
        wings=.48*(g(-1.25,-4.3,.7,.65)+g(1.25,-4.3,.7,.65))
        sockets=-.48*(g(-4.1,-.8,2.1,.85)+g(4.1,-.8,2.1,.85))
        brow=.42*(g(-4.1,.75,2.3,.65)+g(4.1,.75,2.3,.65))
        cheek=.50*(g(-6.0,-4.1,2.3,2.0)+g(6.0,-4.1,2.3,2.0))
        lips=.23*g(0,-6.62,2.6,.22)+.19*g(0,-6.92,2.4,.24)-.13*g(0,-6.78,2.5,.08)
        return nose+wings+sockets+brow+cheek+lips
    def skin_y(x,z):
        y,rx,ry=profile(z)
        front=math.sqrt(max(0.,1-(x/rx)**2))
        return y-ry*front-relief(x,z)*front**8
    def jaw_lift(z,front,back=0.):
        lower=max(0.,(-z-4.5)/7.7)**2
        chin=1.14*max(0.,(-z-6.3)/5.9)**1.5*front**4
        return lower*(3.6*(1-front**4)-.6*back-.9*back**6)+chin
    levels=sorted({-12.2,-11,-10,-8.5,-7.6,-7,-6.92,-6.78,-6.62,-6.3,-5.8,-4.5,-4.0,-3.5,-2.5,-1.0,.5,1.5,3,4.7,6.1,7.5,9})
    if master:levels=sorted(set(levels)|{(a+b)/2 for a,b in zip(levels,levels[1:])})
    # Extra longitudinal edges give the bridge a joined front/side profile.
    angles=sorted(set(round(j*math.tau/n,10) for j in range(n))|{round(1.5*math.pi+d,10) for d in (-.16,-.08,.08,.16)})
    rings=[]
    for z in levels:
        y,rx,ry=profile(z);ring=[]
        for a in angles:
            x=rx*math.cos(a);front=max(0.,-math.sin(a))
            # The jaw ascends from chin to angle below the ear. Horizontal
            # lower rings previously made a cylindrical jaw/neck shelf.
            # Working if the jaw corner sits above the chin in profile.
            jaw_rise=jaw_lift(z,front,max(0.,math.sin(a)))
            nape=1.0*math.exp(-((z+8.5)/3.4)**2)*max(0.,math.sin(a))**2
            ring.append([x,y+ry*math.sin(a)-relief(x,z)*front**8-nape,z+jaw_rise])
        rings.append(ring)
    def seat(v):return [round(v[0]*.74,6),round(v[1]*.85+7.9,6),round(v[2]*.70-.6,6)]
    neck_stations=[(0,10.8,-14.9,1.7,2.0),(0,10.8,-14.5,2.8,2.1),(0,10.8,-14,4.1,2.3),
                   (0,10.6,-13.6,4.1,2.6),(0,10.4,-12.8,4.0,2.7),(0,10.0,-11.6,3.85,2.9),
                   (0,9.5,-10.3,3.7,2.8),(0,8.7,-8.2,3.6,2.45)]
    neck_rings=[[[x+rx*math.cos(a),y+ry*math.sin(a),z] for a in angles] for x,y,z,rx,ry in neck_stations]
    # The neck enters the underside of the jaw behind the chin, rising at
    # the nape instead of leaning forward as a broad, bent cylinder.
    for j,a in enumerate(angles):
        neck_rings[-1][j][2]+=.5*max(0.,-math.sin(a))**2+.2*max(0.,math.sin(a))**2
    # Join the inclined neck directly to the jaw: no intersecting capped tube
    # or visible rear ledge. These rings are already in seated head coordinates.
    face_rings=[[seat(v) for v in ring] for ring in rings]
    neck_top=neck_rings[-1]
    for t in (.25,.5,.75):
        transition=[]
        for j,(a,start,end) in enumerate(zip(angles,neck_top,face_rings[0])):
            v=[(1-t)*start[k]+t*end[k] for k in range(3)]
            # A tangent-continuous nape blends the inclined neck into the skull.
            # Working if the rear profile has no horizontal lower-skull shelf.
            back=max(0.,math.sin(a))**4
            span=math.dist(start,end)
            before=neck_rings[6][j];after=face_rings[1][j]
            d0=[start[k]-before[k] for k in range(3)];d1=[after[k]-end[k] for k in range(3)]
            l0=math.sqrt(sum(x*x for x in d0));l1=math.sqrt(sum(x*x for x in d1))
            for k in range(3):
                curve=(2*t**3-3*t*t+1)*start[k]+(t**3-2*t*t+t)*span*d0[k]/l0+(-2*t**3+3*t*t)*end[k]+(t**3-t*t)*span*d1[k]/l1
                v[k]=(1-back)*v[k]+back*curve
            v[2]-=.20*math.sin(math.pi*t)*max(0.,-math.sin(a))**4
            transition.append(v)
        neck_rings.append(transition)
    rings=neck_rings+face_rings
    for row,(a,b) in enumerate(zip(rings,rings[1:])):
        for j in range(len(angles)):
            k=(j+1)%len(angles);points=[a[j],a[k],b[k],b[j]]
            x,y,z=[sum(v[i] for v in points)/4 for i in range(3)]
            x/= .74;z=(z+.6)/.70
            front=math.sin(angles[j])<-.7
            component='neck' if row<len(neck_rings) else 'nose_bridge' if front and abs(x)<1.7 and -4.8<z<1.5 else 'skin_surface'
            material='lip' if front and abs(x)<2.7 and -7.02<z<-6.52 else 'skin'
            face(points,material,component)
    for ring,centre,reverse,component in ((rings[0],[0,10.8,-14.9],True,'neck_end'),(rings[-1],seat([0,profile(levels[-1])[0],levels[-1]]),False,'skin_surface')):
        for j in range(len(angles)):
            points=[centre,ring[j],ring[(j+1)%len(angles)]]
            face(points[::-1] if reverse else points,'skin',component)
    # A closed folded cloth collar covers the ragged neck insertion line.
    # Working if its upper rim surrounds skin and the lower band enters the tunic.
    loft([(0,10.8,-14.2,4.4,2.85),(0,10.4,-12.5,4.4,3.0),
          (0,10.4,-12.5,4.05,2.65),(0,10.8,-14.2,4.05,2.5)],'collar','collar')
    seated_surface_count=len(out)
    def cheek_y(x,z):
        return skin_y(x,z)-.14
    for side in (-1,1):
        # A thin cupped pinna with a rolled helix, inset concha and tapered
        # lobe. The old concentric ellipsoids read as raised circular buttons.
        ear_rings=[]
        for radius,projection in ((1.0,.25),(.82,1.05),(.54,.72),(.22,.38)):
            ring=[]
            for j in range(12):
                a=j*math.tau/12;vertical=math.sin(a)
                taper=1+.20*vertical
                ring.append([side*(10.35+projection),.45+1.05*radius*math.cos(a)*taper-(1-radius)*.3,
                             -3.5+2.8*radius*vertical])
            ear_rings.append(ring)
        for outer,inner in zip(ear_rings,ear_rings[1:]):
            for j in range(12):
                k=(j+1)%12;points=[outer[j],outer[k],inner[k],inner[j]]
                face(points if side>0 else points[::-1],'skin','ear')
        for j in range(12):
            k=(j+1)%12
            front=[ear_rings[-1][j],ear_rings[-1][k],[side*10.70,.15,-3.5]]
            back=[ear_rings[0][k],ear_rings[0][j],[side*10.3,.45,-3.5]]
            face(front if side>0 else front[::-1],'skin_shadow','ear_inner')
            face(back if side>0 else back[::-1],'skin','ear')
        eye_y=skin_y(side*4.1,-.9)
        oval((side*4.1,eye_y-.15,-.9),(1.08,.24,.30),'eye','eye',10,4)
        oval((side*4.0,eye_y-.39,-.86),(.29,.11,.26),'iris','iris',8,4)
        # Eyebrows follow the recessed socket instead of floating ahead of it.
        for x0,x1 in zip((2.1,3.1,4.1,5.1),(3.1,4.1,5.1,6.1)):
            face([[side*x,cheek_y(side*x,z)-.03,z] for x,z in ((x0,.62),(x1,.62),(x1,.84),(x0,.84))],'brow','brow')
        oval((side*.85,skin_y(side*.85,-4.5)-.08,-4.5),(.26,.15,.12),'skin_shadow','nostril',8,4)
        # Straps sit on the cheeks and turn under the jaw.
        strap=[]
        anchors=[(-9.4,6.8),(-7,8.1),(-3,9.1),(1,9.5)]
        for z in (1,0,-1,-3,-5,-7,-8.2,-9.4):
            a,b=next((a,b) for a,b in zip(anchors,anchors[1:]) if a[0]<=z<=b[0])
            x=a[1]+(b[1]-a[1])*(z-a[0])/(b[0]-a[0])
            ring=[]
            for dx in (-.4,.4):
                xx=side*(x+dx);front=math.sqrt(max(0.,1-(xx/profile(z)[1])**2))
                zz=z+jaw_lift(z,front)
                ring.append([xx,cheek_y(xx,z),zz])
            strap.append(ring)
        for a,b in zip(strap,strap[1:]):
            points=[a[0],a[1],b[1],b[0]]
            face(points[::-1] if side>0 else points,'strap','chinstrap')
    # Rolled steel rim and a proper domed shell with a slight front overhang.
    loft([(0,0,1.4,12.8,10.0),(0,-.25,1.9,13.3,10.7),
          (0,-.25,2.4,13.3,10.7),(0,0,2.9,12.8,9.9)],'rim','helmet_rim')
    loft([(0,0,2.4,13.0,10.3),(0,.4,5.2,12.3,10.0),(0,.8,8.5,10.5,8.1),
          (0,1.0,11.1,7.5,6.0),(0,1.1,12.3,3.3,2.8),(0,1.1,12.6,.3,.3)],'helmet','helmet_dome')
    # The round command fixes X/Z; depth can seat the skull above the neck.
    # Previously the skull was a full half-head in front of the jacket.
    for index,triangle in enumerate(out):
        if index>=seated_surface_count:
            triangle['vertices']=[seat(v) for v in triangle['vertices']]
        # Restore a modest adult skull width around the fixed eye landmarks.
        # Working if the helmet and face are about ten percent wider together.
        for v in triangle['vertices']:
            t=max(0.,min(1.,(v[2]+12.5)/4.5));blend=t*t*(3-2*t)
            if abs(v[0])>3.9 and v[2]>-13.6:v[0]=round(math.copysign(3.9+(abs(v[0])-3.9)*(.78+.14*blend),v[0]),6)
            if triangle['component'].startswith(('crew_head_eye','crew_head_iris')):continue
            # Grow height and depth about the eye plane, fading to the unchanged
            # collar. A smooth transition avoids stretching the whole neck.
            # Working if sight contact and collar insertion stay exact while
            # the skull, facial relief and helmet grow as one fitted assembly.
            v[1]=round(2.0+(v[1]-2.0)*(1+.08*blend),6)
            v[2]=round(-1.23+(v[2]+1.23)*(1+.08*blend),6)
    model={'name':base['name']+'_HEAD','shape_index':shape,'triangles':out,'bounds':bounds([v for t in out for v in t['vertices']])}
    return model,{'schema':1,'command_offset':command['command_offset'],'command':[170,15,2,171],
                  'coordinate_contract':'command-local normalized X/Y by18 and Z by15; observed ellipse and spans remain authoritative',
                  'triangles':out}
