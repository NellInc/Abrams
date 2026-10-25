"""Source-owned Tactical buildings and collapsed construction, in raw units.

No gameplay, roots, commands or visibility programs are authored here. The
source primitive remains the indivisible attribution/visibility owner.
"""
import copy
import math
from tools.build_pc_modern_assets import MATERIALS, REGISTRY_FIELDS, bounds, validate_model
from tools.build_pc_tactical_vehicles import emit, box, tube
from tools.pc_tactical_cabin import FINISHES as CABIN_FINISHES

FINISHES = {
    'architecture_render': ('plaster', (201,191,164), None),
    'architecture_render_edge': ('plaster', (185,177,153), None),
    'architecture_mortar': ('stone_edge', (116,112,99), None),
    'architecture_wood': ('timber', (91,80,61), None),
    'architecture_char': ('timber', (49,47,40), None),
    'architecture_frame': ('door', (177,177,156), None),
    'architecture_door': ('door', (82,99,91), None),
    'architecture_glass': ('glass', (48,64,67), None),
    'architecture_glass_sky': ('glass', (76,93,95), None),
    'architecture_void': ('vent', (35,39,36), None),
    'architecture_zinc': ('steel', (100,111,109), None),
    'architecture_slate': ('roof_slate', (65,79,89), ('stone',.88,0.,.00035)),
    'architecture_brick': ('stone_edge', (143,100,77), ('stone',.93,0.,.00045)),
    'architecture_cow_white': ('plaster', (220,216,196), ('skin',.88,0.,.00012)),
    'architecture_cow_black': ('timber', (39,39,35), ('skin',.87,0.,.00012)),
    'architecture_cow_muzzle': ('plaster', (171,126,115), ('skin',.79,0.,.00008)),
    'architecture_cow_hoof': ('timber', (62,57,47), ('skin',.92,0.,.0001)),
    'architecture_cow_eye': ('glass', (24,25,21), None),
    'architecture_trough': ('stone_edge', (137,139,126), ('stone',.93,0.,.00045)),
    'architecture_water': ('glass', (57,78,75), None),
    'architecture_yard_dust': ('stone_edge', (116,112,99), ('stone',.98,0.,.0002)),
    'architecture_ruin_dust': ('stone_edge', (128,122,104), ('stone',.98,0.,.0002)),
}
# These physical collapse centres also anchor offline dust and contact staining.
# Keeping one coordinate list prevents detached or camera-dependent dirt halos.
FARM_RUBBLE_CLUSTERS=((-236,-101,1.1),(-143,-131,.85),(-48,-102,1.),
                      (52,-137,.7),(249,-165,.94),(-251,56,.72),
                      (-108,159,.9),(116,154,.65))
for name,spec in CABIN_FINISHES.items():
    if name.startswith(('cabin_tile_', 'cabin_stone_')):
        FINISHES[name.replace('cabin_', 'architecture_')]=spec
for i,rgb in enumerate(((198,119,48),(187,110,44),(206,127,56),(192,115,46),(211,132,61))):
    FINISHES[f'architecture_ochre_{i}']=('roof_clay',rgb,('ceramic',.83,0.,.00022))
for i,rgb in enumerate(((62,76,86),(67,81,91),(64,78,88),(69,83,93),(65,79,89))):
    FINISHES[f'architecture_slate_{i}']=('roof_slate',rgb,('stone',.88,0.,.00035))
MATERIALS.update({k:list(v[1]) for k,v in FINISHES.items()})
SHAPES=(145,146,148,149,150,151,152,153,154,155,156,157,158)
RUINS=(146,148,150,152,154,158)


def geometry(base, master=False):
    """Return a copied registry plus source-attributed authored construction."""
    shape=base['shape_index']
    if shape not in SHAPES:raise ValueError('Unsupported Tactical architecture')
    if shape==149:
        # These two source cubes share topology. Reuse the rebuilt cottage's
        # full construction while rebinding every owner to this cube's registry.
        from tools.pc_tactical_cabin import geometry as cottage
        proxy=copy.deepcopy(base);proxy['shape_index']=147
        ids=(25884,25892,25900,25908,25916)
        remap={p['id']:n for p,n in zip(proxy['source_primitives'],ids)}
        reverse={v:k for k,v in remap.items()}
        for p in proxy['source_primitives']:p['id']=remap[p['id']]
        for g in proxy['groups']:g['primitive_pointers']=[remap.get(i,i) for i in g['primitive_pointers']]
        out=cottage(proxy,master)['triangles']
        for t in out:t['source_primitive']=reverse[t['source_primitive']]
        model=copy.deepcopy(base);model['triangles']=out;model['source_passthrough']=[]
        model['bounds']=bounds([v for t in out for v in t['vertices']]);validate_model(model)
        return model
    model=copy.deepcopy(base);out=[]
    sources=[dict(p,groups=[g['offset'] for g in base['groups'] if p['id'] in g['primitive_pointers']]) for p in base['source_primitives']]
    lo,hi=base['source_bounds']['min'],base['source_bounds']['max']
    def shifted(v,src):
        offset=src.get('_decoration_shift',(0,0,0))
        return [v[k]+offset[k] for k in range(3)]
    def face(pts,mat,part,src):
        # Clamp only the small thickness/inset offsets at immutable extrema.
        pts=[[max(lo[k],min(hi[k],v[k])) for k in range(3)] for v in [shifted(p,src) for p in pts]]
        if len(pts)<3:return
        emit(out,[src],pts,mat,'architecture_'+part)
    def block(a,b,mat,part,src):
        a,b=shifted(a,src),shifted(b,src)
        a=[max(lo[k],min(hi[k],a[k])) for k in range(3)]
        b=[max(lo[k],min(hi[k],b[k])) for k in range(3)]
        if any(b[k]-a[k]<1e-6 for k in range(3)):return
        box(out,[src],a,b,mat,'architecture_'+part)
    def beam(a,b,r,mat,part,src):
        a,b=shifted(a,src),shifted(b,src)
        # tubes stay genuinely inside the source envelope, without flattening.
        a=[max(lo[k]+r,min(hi[k]-r,a[k])) for k in range(3)]
        b=[max(lo[k]+r,min(hi[k]-r,b[k])) for k in range(3)]
        if math.dist(a,b)>.001:tube(out,[src],a,b,r,mat,'architecture_'+part,8 if master else 4 if shape==158 else 6)
    if shape in (148,150,152):
        _collapsed(sources,face,block,beam,shape,master)
    else:
        ruin=shape in RUINS
        for src in sources:
            pid=src['id'];q=src['vertices']
            incumbent=[t for t in base['triangles'] if t['source_primitive']==pid]
            if shape==151 and pid==26634:
                # The source's flat red cap is retained verbatim apart from
                # its inward painter winding, which darkens the exterior bake.
                from tools.build_pc_modern_assets import cross,sub
                for original in incumbent:
                    triangle=copy.deepcopy(original)
                    a,b,c=triangle['vertices']
                    if cross(sub(b,a),sub(c,a))[2]<0:
                        triangle['vertices']=[a,c,b]
                    out.append(triangle)
                continue
            # Painted flags, insignia and source-authoritative line structures
            # are retained exactly, including their original color bytes.
            if len(q)<3 or pid in (27177,28325,27061,28209,25313,25650,28751):
                out.extend(copy.deepcopy(incumbent));continue
            decorations=[t for t in incumbent if t['component'] in ('soviet_star','us_army_star')]
            if decorations:
                fixed_axis=next((k for k in (0,1) if max(v[k] for v in q)-min(v[k] for v in q)<.001),None)
                axis=2 if fixed_axis is None else fixed_axis
                outward=1 if axis==2 or q[0][axis]>0 else -1
                if shape not in (153,155,156):raise ValueError('Unreviewed star support orientation')
                from tools.build_pc_modern_assets import cross,sub
                for decoration in decorations:
                    triangle=copy.deepcopy(decoration)
                    a,b,c=triangle['vertices']
                    # Fixed-axis outlines inherited two inward wall/roof
                    # windings. Repair before unwrap, keeping every facet.
                    if cross(sub(b,a),sub(c,a))[axis]*outward<0:
                        triangle['vertices']=[a,c,b]
                    out.append(triangle)
                # Source decorations sit slightly inside the coarse plane.
                # Recess only the authored support so the exact incumbent
                # facet positions stay exposed without changing their paint.
                shift=[0,0,0]
                vertices=[v for t in decorations for v in t['vertices']]
                if fixed_axis is None:
                    a=[q[1][k]-q[0][k] for k in range(3)];b=[q[2][k]-q[0][k] for k in range(3)]
                    normal=[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
                    inset=max(q[0][2]-(normal[0]*(v[0]-q[0][0])+normal[1]*(v[1]-q[0][1]))/normal[2]-v[2] for v in vertices)
                    shift[2]=-(inset+3.0)
                else:
                    sign=-1 if q[0][fixed_axis]>0 else 1
                    inset=max((v[fixed_axis]-q[0][fixed_axis])*sign for v in vertices)
                    shift[fixed_axis]=sign*(inset+3.0)
                src['_decoration_shift']=shift
            xs=[v[0] for v in q];ys=[v[1] for v in q];zs=[v[2] for v in q]
            vertical=(max(xs)-min(xs)<.001 or max(ys)-min(ys)<.001) and max(zs)-min(zs)>.001
            if vertical:
                axis=0 if max(xs)-min(xs)<.001 else 1
                _wall(src,axis,ruin,face,block,beam,shape,master)
            elif max(zs)-min(zs)<.001 and max(zs)<=lo[2]+.001:
                face(q,'architecture_yard_dust' if shape==158 and pid==29245 else 'architecture_mortar','floor',src)
            elif len(q)==4:
                _roof(src,ruin,face,beam,shape,master)
            else:face(q,'architecture_render','retained_panel',src)
    if shape in (157,158):
        yard=next(src for src in sources if src['id']==(28751 if shape==157 else 29245))
        _farmyard(out,yard,shape==158,master)
    model['triangles']=out
    model['source_passthrough']={153:[27177],156:[28325]}.get(shape,[])
    model['bounds']=bounds([v for t in out for v in t['vertices']]);validate_model(model)
    if not master and len(out)>8192:raise ValueError(f'Architecture {shape}: {len(out)} exceeds runtime allowance')
    if any(not lo[k]<=v[k]<=hi[k] for t in out for v in t['vertices'] for k in range(3)):raise ValueError('Architecture source envelope')
    for field in (*REGISTRY_FIELDS,'source_bounds','status'):
        if field in base and model[field]!=base[field]:raise ValueError('Registry modified: '+field)
    return model


def _wall(src,axis,ruin,face,block,beam,shape,master):
    q=src['vertices'];uaxis=1-axis;fixed=q[0][axis]
    us=[v[uaxis] for v in q];zs=[v[2] for v in q]
    umin,umax=min(us),max(us);zmin,zmax=min(zs),max(zs)
    w=umax-umin;h=zmax-zmin
    if w<.001:return
    # Thickness points into the building, preserving the landmark footprint.
    inward=-1 if fixed>0 else 1
    if shape in (153,154) and axis==0 and fixed==112:inward=-1
    if shape==157 and axis==0 and fixed==120:inward=1
    thick=min(w*.025,h*.045,5)
    drain_radius=max(.18,min(1,h*.007))
    # Reserve real room for drainage inside the original footprint. Previously
    # the gutter and downpipe were wholly inside the opaque plaster plane.
    # Move the complete joinery/reveal assembly together, preserving its depth.
    drain_clearance=2*drain_radius+.2
    existing_setback=inward*src.get('_decoration_shift',(0,0,0))[axis]
    setback=0 if ruin or h<25 else max(0,drain_clearance-existing_setback)
    def p(u,z,d=0):
        v=[0,0,z];v[axis]=fixed+inward*(setback+d);v[uaxis]=u;return v
    def wallface(points,mat,part):
        from tools.build_pc_modern_assets import cross,sub,clean_polygon
        points=clean_polygon(points)
        if len(points)<3:return
        n=cross(sub(points[1],points[0]),sub(points[2],points[0]))
        face(points[::-1] if n[axis]*inward>0 else points,mat,part,src)
    def panel(a,b,c,d,mat,part,depth=0):wallface([p(a,b,depth),p(c,b,depth),p(c,d,depth),p(a,d,depth)],mat,part)
    def bar(a,b,c,d,mat,part,depth=0,back=None):
        pts=[p(u,z,v) for u in (a,c) for z in (b,d) for v in (depth,depth+thick*.4 if back is None else back)]
        block([min(v[k] for v in pts) for k in range(3)],[max(v[k] for v in pts) for k in range(3)],mat,part,src)
    # Upper boundary is interpolated from the actual source polygon, including
    # gables and the asymmetric destroyed HQ wall. No rectangular gable fill.
    def top(u):
        hits=[]
        for a,b in zip(q,q[1:]+q[:1]):
            ua,ub=a[uaxis],b[uaxis]
            if min(ua,ub)-1e-8<=u<=max(ua,ub)+1e-8 and abs(ub-ua)>1e-8:
                hits.append(a[2]+(b[2]-a[2])*(u-ua)/(ub-ua))
        return max(hits) if hits else zmax
    # Exact end elevations prevent the old inward sample from lifting the
    # gable baseline through its end triangles and creating reversed slivers.
    eave=min(top(umin),top(umax));body=eave-zmin
    # Low farm perimeter walls have stone coping instead of improbable windows.
    if h<25:
        panel(umin,zmin,umax,zmax,'architecture_mortar','yard_wall')
        n=max(2,min(18,int(w/35)))
        for j in range(n):
            a=umin+w*j/n+.3;b=umin+w*(j+1)/n-.3
            bar(a,zmin+.4,b,zmax-.4,f'architecture_stone_{j%4}','yard_stone',thick*.1)
        return
    holes=[]
    if shape==155:
        # The source cube represents a two-storey block. A single tall door
        # previously consumed 86% of its height and made every fitting stretch.
        # Working if doors have human proportions and two aligned window rows.
        for mid in (umin+w*.25,umin+w*.75):
            for low,high in ((.14,.39),(.60,.85)):
                holes.append((mid-w*.105,zmin+body*low,mid+w*.105,zmin+body*high))
        if axis==1 and fixed<0:
            mid=(umin+umax)/2
            holes.append((mid-w*.09,zmin,mid+w*.09,zmin+body*.41))
    elif body>12:
        n=max(2,min(4,int(w/max(body*.65,1))))
        for j in range(n):
            mid=umin+w*(j+.5)/n;hw=min(w/n*.25,body*.18)
            holes.append((mid-hw,zmin+body*.40,mid+hw,zmin+body*.78))
        if axis==1 and fixed<0:
            mid=(umin+umax)/2;hw=min(w*.075,body*.18)
            holes=[x for x in holes if x[2]<mid-hw or x[0]>mid+hw]
            holes.append((mid-hw,zmin,mid+hw,zmin+body*.86))
    # The large intact base needs no arbitrary subdivisions of planar plaster.
    # Keep all source/door/window boundaries while reserving its fixed triangle
    # budget for the now-complete, correctly wound gable ends.
    subdivisions=() if shape==156 else (umin+w*j/12 for j in range(1,12))
    ugrid=sorted({umin,umax,*us,*[x[k] for x in holes for k in (0,2)],*subdivisions})
    zgrid=sorted({zmin,eave,*[x[k] for x in holes for k in (1,3)]})
    for a,c in zip(ugrid,ugrid[1:]):
        if c-a<1e-6:continue
        for b,d in zip(zgrid,zgrid[1:]):
            if d-b<1e-6 or any(x<(a+c)/2<xx and y<(b+d)/2<yy for x,y,xx,yy in holes):continue
            # Deliberate wide blast breach leaves a supported return at each end.
            if ruin and .32<(a+c-2*umin)/(2*w)<.63 and b>zmin+body*.24:continue
            panel(a,b,c,d,'architecture_render','wall')
        ta,tb=top(a),top(c)
        if max(ta,tb)>eave+.001 and not (ruin and a<umin+w*.6 and c>umin+w*.34):
            wallface([p(a,eave),p(c,eave),p(c,tb),p(a,ta)],'architecture_render','gable')
    for j,(a,b,c,d) in enumerate(holes):
        if ruin and .3<((a+c)/2-umin)/w<.65:continue
        # Real jamb depth, with a recessed opaque interior/glazing plane.
        for A,B in (((a,b),(c,b)),((c,b),(c,d)),((c,d),(a,d)),((a,d),(a,b))):
            from tools.build_pc_modern_assets import cross,sub,dot
            points=[p(*A),p(*B),p(*B,thick),p(*A,thick)]
            n=cross(sub(points[1],points[0]),sub(points[2],points[0]))
            centre=[sum(v[k] for v in points)/4 for k in range(3)]
            cavity=p((a+c)/2,(b+d)/2,thick/2)
            # Opening sidewalls face into the opening, independently of which
            # side of the building owns this source plane.
            face(points[::-1] if dot(n,sub(centre,cavity))>0 else points,'architecture_mortar','reveal',src)
        rim=min((c-a)*.07,(d-b)*.06)
        door=b==zmin
        panel(a,b,c,d,'architecture_void' if ruin else 'architecture_door' if door else 'architecture_glass','interior' if ruin else 'recessed_leaf' if door else 'glazing',thick)
        for aa,bb,cc,dd in ((a,b,a+rim,d),(c-rim,b,c,d),(a,d-rim,c,d)):
            bar(aa,bb,cc,dd,'architecture_wood' if ruin else 'architecture_frame','broken_jamb' if ruin else 'frame',thick*.3)
        if not ruin:
            if door:
                for z in (.2,.52,.82):bar(a+rim,b+(d-b)*z,c-rim,b+(d-b)*z+rim,'architecture_door','door_rail',thick*.55)
                bar(c-rim*3,b+(d-b)*.48,c-rim*2,b+(d-b)*.55,'architecture_zinc','door_latch',thick*.3)
            else:
                mid=(a+c)/2
                bar(mid-rim*.3,b,mid+rim*.3,d,'architecture_frame','mullion',thick*.5)
                bar(a,b+(d-b)*.65,c,b+(d-b)*.65+rim*.6,'architecture_frame','transom',thick*.5)
                bar(a-rim,b-rim,c+rim,b,'architecture_stone_2','sill',0)
                panel(a+rim,b+(d-b)*.68,c-rim,d-rim,'architecture_glass_sky','upper_glazing',thick*.99)
    if shape==155:
        panel(umin,zmin+body*.48,umax,zmin+body*.495,'architecture_frame','floor_course',-.12)
    # Foundation courses and quoins relate to the wall, not random box scatter.
    foundation_count=7 if shape==158 else 10
    for row in range(2):
        for j in range(foundation_count):
            a=umin+w*j/foundation_count+.15;c=umin+w*(j+1)/foundation_count-.15
            b=zmin+body*.055*row;d=b+body*.05
            if any(x<c and xx>a and y==zmin for x,y,xx,yy in holes):continue
            bar(a,b,c,d,f'architecture_stone_{(j+row)%4}','foundation',.05)
    if ruin:
        for j in range(12):
            u=umin+w*(j+.5)/12;zt=min(top(u),eave)
            if .32<(u-umin)/w<.63:zt=zmin+body*.20
            width=w/28
            bar(u-width,zt-body*.065,u+width,zt,'architecture_brick','exposed_core',thick*.2)
            beam(p(u,zt,thick),p(u+w*.08,zmin+body*.14,thick*2),max(.2,thick*.25),'architecture_char','splintered_stud',src)
    else:
        # Exposed gutter/downpipe, with clearance behind and a small inset from
        # the immutable outer boundary. Straps bridge back into the plaster.
        z=eave-min(1,h*.025);r=drain_radius
        gutter_depth=-drain_clearance+r+.05;pipe_depth=-drain_clearance+r*.75+.05
        beam(p(umin+w*.01,z,gutter_depth),p(umax-w*.01,z,gutter_depth),r,'architecture_zinc','gutter',src)
        u=umin+w*.065
        beam(p(u,z,pipe_depth),p(u,zmin+h*.08,pipe_depth),r*.75,'architecture_zinc','downpipe',src)
        for frac in (.2,.55,.82):bar(u-r*1.5,zmin+body*frac,u+r*1.5,zmin+body*frac+r,'architecture_zinc','pipe_strap',pipe_depth-r*.6,back=.2)
        for a,b in zip(q,q[1:]+q[:1]):
            if a[2]>=eave-.01 and b[2]>=eave-.01 and math.dist(a,b)>h*.15:
                beam(p(a[uaxis],a[2]-.7,thick*.3),p(b[uaxis],b[2]-.7,thick*.3),r,'architecture_wood','bargeboard',src)


def _roof(src,ruin,face,beam,shape,master):
    q=src['vertices']
    if len(q)==4:
        # Source quads can begin on a rake instead of a ridge. Keep courses
        # parallel to the eaves and lap toward them on both roof pitches.
        level=[j for j in range(4) if abs(q[j][2]-q[(j+1)%4][2])/max(.000001,math.dist(q[j],q[(j+1)%4]))<.15]
        if level:
            start=max(level,key=lambda j:((q[j][2]+q[(j+1)%4][2])/2,math.dist(q[j],q[(j+1)%4])))
            q=q[start:]+q[:start]
    # Incumbent painter polygons have mixed winding. Authored exterior skins
    # must face upward, including the bake master, without changing that source.
    from tools.build_pc_modern_assets import cross,sub
    if cross(sub(q[1],q[0]),sub(q[2],q[0]))[2]<0:
        original_face=face
        def face(points,mat,part,owner):original_face(points[::-1],mat,part,owner)
    def p(u,v,depth=0):
        return [(1-u)*(1-v)*q[0][k]+u*(1-v)*q[1][k]+u*v*q[2][k]+(1-u)*v*q[3][k]-(depth if k==2 else 0) for k in range(3)]
    if shape==155:
        # Flat roofs need a recessed weathering surface and perimeter coping,
        # rather than hundreds of pitched slate tiles laid like a checkerboard.
        # Working if the top reads as one flat roof with a defined parapet edge.
        face([p(.025,.025,3.0),p(.975,.025,3.0),p(.975,.975,3.0),p(.025,.975,3.0)],'architecture_slate','flat_roof',src)
        for a,b,c,d in ((0,0,1,.025),(0,.975,1,1),(0,.025,.025,.975),(.975,.025,1,.975)):
            face([p(a,b),p(c,b),p(c,d),p(a,d)],'architecture_frame','roof_coping',src)
        for a,b,c,d in ((.025,.025,.975,.025),(.975,.025,.975,.975),(.975,.975,.025,.975),(.025,.975,.025,.025)):
            face([p(a,b),p(c,d),p(c,d,3),p(a,b,3)],'architecture_frame','roof_coping_return',src)
        for u in (.25,.5,.75):beam(p(u,.025,2.85),p(u,.975,2.85),.12,'architecture_mortar','flat_roof_seam',src)
        return
    length=math.dist(q[0],q[1]);width=math.dist(q[0],q[3])
    # Individual lapped tiles, staggered along the roof's long axis. All lips
    # descend into the source plane so source maxima are never inflated.
    nu=max(4,min(18,int(length/15)));nv=max(4,min(14,int(width/12)))
    if shape in (153,154,156):nu,nv=(7,4) if shape==156 else (9,6)
    if shape==154:nu,nv=9,6
    if shape==157:nu,nv=7,5
    face([p(0,0,1.0),p(1,0,1.0),p(1,1,1.0),p(0,1,1.0)],'architecture_char' if ruin else 'architecture_wood','roof_deck',src) if not ruin else None
    slate=shape in (145,146,151,153,154,155,156) or src['id'] in (28819,29312)
    ochre=shape in (157,158) and not slate
    # Surviving ruin courses still lap horizontally. Narrow physical joints
    # prevent the bright opposite wall showing between every surviving tile.
    # Working if ruin lips follow the eaves and only authored breaches stay open.
    gap=.00035 if ruin else .002
    for row in range(nv):
        v0=row/nv+gap;v1=(row+1)/nv-gap
        for col in range(-1,nu):
            u0=max(gap,(col+(row%2)*.5)/nu+gap);u1=min(1-gap,(col+1+(row%2)*.5)/nu-gap)
            if u1-u0<.004:continue
            if shape in (146,154,158):
                left=.27+.055*math.sin(row*1.8+src['id']%3)
                right=.61+.05*math.cos(row*2.1)
                if (left<u0<right and row>nv*.22) or (row+col*2)%13==0:continue
            elif ruin and ((.25<u0<.61 and row>nv*.25) or (row+col*2)%11==0):continue
            mat='architecture_slate' if slate else f'architecture_ochre_{(row*7+col*3)%5}' if ochre else f'architecture_tile_{(row*7+col*3)%5}'
            if slate and not ruin:mat=f'architecture_slate_{(row*7+col*3+src["id"])%5}'
            if shape in (146,154,158) and row>nv*.18 and (abs(u1-left)<.085 or abs(u0-right)<.085):
                # Chipped, staggered tile edges interrupt the old rectangular
                # roof cut. The game and bake master share this exact polygon.
                du=u1-u0;dv=v1-v0
                outline=((u0,v0),(u1,v0),(u1,v1-dv*.31),
                         (u1-du*.29,v1),(u0+du*.13,v1-dv*.07),(u0,v1-dv*.18))
                points=[p(u,v,.25) for u,v in outline]
                face(points,mat,'fractured_roof_tile',src)
                a,b=outline[2],outline[3]
                face([p(*a,.25),p(*b,.25),p(*b,1.2),p(*a,1.2)],
                     'architecture_mortar','roof_fracture_core',src)
                continue
            mid=(u0+u1)/2
            # Shallow crown and physically exposed overlap lip.
            for a,b in ((u0,mid),(mid,u1)):
                da=.10 if a==mid else .35;db=.10 if b==mid else .35
                face([p(a,v0,da),p(b,v0,db),p(b,v1,db),p(a,v1,da)],mat,'slate_course' if slate else 'clay_tile',src)
            face([p(u0,v1,.35),p(u1,v1,.35),p(u1,v1,.9),p(u0,v1,.9)],mat,'tile_lip',src)
    # Folded edge flashing physically closes the tile/deck gap. Sparse joints
    # follow the roof structure, including the exact retained red ridge151.
    for edge in (0,1):
        v0,v1=(.004,.023) if edge==0 else (.977,.996)
        face([p(.008,v0,.03),p(.992,v0,.03),p(.992,v1,.04),p(.008,v1,.04)],
             'architecture_zinc','folded_roof_flashing',src)
        face([p(.008,v0,.03),p(.992,v0,.03),p(.992,v0,1.3),p(.008,v0,1.3)],
             'architecture_zinc','flashing_return',src)
    # Short end-grain rafter tails stay connected to surviving eave framing.
    tails=(.09,) if shape==156 else (.09,.31,.53,.75,.93)
    for u in tails:
        if ruin and .25<u<.61:continue
        beam(p(u,.012,1.8),p(u,.085,1.8),max(.25,min(1.1,width*.007)),
             'architecture_char' if ruin else 'architecture_wood','rafter_tail',src)
    # Exposed roof frame in destruction state; orderly rafters remain attached
    # to surviving edges rather than floating uniformly through holes.
    if ruin:
        for j in range(7):
            u=(j+.4)/7
            beam(p(u,.02,1.5),p(u,.94 if j%3 else .48,1.5),max(.3,min(2,width*.009)),'architecture_char','exposed_rafter',src)
        beam(p(.02,.05,1.6),p(.97,.05,1.6),max(.3,min(2,width*.008)),'architecture_wood','broken_purlin',src)
    else:
        for j in range(12):
            a=j/12;b=(j+1)/12
            face([p(a,0,.04),p(b,0,.04),p(b,.025,.25),p(a,.025,.25)],'architecture_slate' if slate else f'architecture_ochre_{j%5}' if ochre else f'architecture_tile_{j%5}','ridge_flashing',src)


def _collapsed(sources,face,block,beam,shape,master):
    """Low rubble source has a different pivot/envelope from its intact pair.

    Cottage materials and joinery survive, translated into this 30-unit deep
    footprint. Never copy the intact cube's coordinates into the destroyed pose.
    """
    floor=sources[0];walls=sources[1:]
    face(floor['vertices'][::-1],'architecture_ruin_dust','collapsed_floor',floor)
    # Grounded fragments lie inside this destroyed pose's existing floor,
    # rather than copying the intact house footprint into the low wreck pivot.
    for i,(x,y) in enumerate(((-28,-49),(24,-43),(-25,48),(26,55),(7,64),
                            (-31,-18),(29,11),(-17,-42),(18,48),(-6,-57),
                            (-29,27),(30,-33),(2,53),(19,-58),(-18,65))):
        n=5+i%2;ring=[]
        for j in range(n):
            angle=j*math.tau/n+i*.7
            ring.append([x+(7+i%3)*math.cos(angle),y+(4+i%2)*math.sin(angle),-29.85])
        top=[[v[0]*.98,v[1],-27.5+(i%4)*.45+(j%3)*.65] for j,v in enumerate(ring)]
        face(top,f'architecture_stone_{i%4}','grounded_ruin_masonry',floor)
        for j in range(n):
            k=(j+1)%n
            face([ring[j],ring[k],top[k],top[j]],'architecture_brick' if j%2 else 'architecture_render','ruin_masonry_core',floor)
    # Broken rendered returns, with exposed stone cores and window fragments.
    for i,src in enumerate(walls):
        q=src['vertices'];a,b,peak=q
        # Short, independently fractured slabs replace continuous tall panels
        # meeting along a tent-like ridge. The original mound pose still owns
        # every piece, including its original source height and coverage.
        for j in range(15):
            col,row=j%5,j//5
            if (i*3+col+row*2)%7==0:continue
            t0=max(.005,(col+.04+.14*math.sin(row*2+i+col*.7))/5)
            t1=min(.995,(col+.90+.09*math.cos(j*1.3+i))/5)
            v0=max(.018,(.025,.29,.555)[row]+.055*math.sin(col*1.9+i*2+row))
            v1=min(.82,v0+(.18,.19,.17)[row]+.045*math.cos(col*2.7-row+i))
            def point(u,v):
                foot=[a[k]*(1-u)+b[k]*u for k in range(3)]
                result=[foot[k]*(1-v)+peak[k]*v for k in range(3)]
                result[2]-=1.2+1.4*(.5+.5*math.sin(col*2.3+row*1.7+i))
                return result
            A,B,C,D=point(t0,v0),point(t1,v0),point(t1,v1),point(t0,v1)
            centre=[sum(v[k] for v in (A,B,C,D))*.25 for k in range(3)]
            yaw=.13*math.sin(j*1.7+i*.8)
            for v in (A,B,C,D):
                x,y=v[0]-centre[0],v[1]-centre[1]
                v[0]=centre[0]+x*math.cos(yaw)-y*math.sin(yaw)
                v[1]=centre[1]+x*math.sin(yaw)+y*math.cos(yaw)
            # A six-corner chipped crest exposes two unequal broken edges.
            E=[D[k]*.38+C[k]*.62 for k in range(3)]
            E[2]-=.65+(col%3)*.3
            outline=[A,B,C,E,[D[k]*.76+C[k]*.24 for k in range(3)],D]
            face(outline,'architecture_render','fallen_render_slab',src)
            # Slab underside and perimeter expose masonry thickness.
            lower=[[v[0],v[1],v[2]-1.4] for v in outline]
            face(lower[::-1],'architecture_mortar','fallen_slab_back',src)
            for aa,bb,cc,dd in zip(outline,outline[1:]+outline[:1],lower[1:]+lower[:1],lower):
                face([aa,bb,cc,dd],'architecture_stone_1','fallen_slab_edge',src)
            face([C,D,[D[0],D[1],D[2]-1.2],[C[0],C[1],C[2]-1.2]],'architecture_brick','slab_exposed_core',src)
            # Surviving clay tile patch follows the slope of a collapsed panel.
            for tile in range(3):
                u0=(tile+.06)/3;u1=(tile+.94)/3
                def mix(u,v):return [(A[k]*(1-u)+B[k]*u)*(1-v)+(D[k]*(1-u)+C[k]*u)*v+(.22 if k==2 else 0) for k in range(3)]
                if j%2==0:
                    T=[mix(u0,.40),mix(u1,.40),mix(u1,.74),mix(u0,.74)]
                    mat=('roof_ridge' if i==1 and j==0 and tile==1 else 'architecture_slate') if shape==152 else f'architecture_tile_{(tile+j+i)%5}'
                    face(T,mat,'fallen_slate' if shape==152 else 'fallen_clay_tile',src)
                    for aa,bb in zip(T,T[1:]+T[:1]):
                        face([aa,bb,[bb[0],bb[1],bb[2]-.45],[aa[0],aa[1],aa[2]-.45]],mat,'fallen_tile_edge',src)
        # Attached broken sash: three sides, one missing, burnt timber inside.
        u=[a[k]*.7+peak[k]*.3 for k in range(3)]
        v=[b[k]*.7+peak[k]*.3 for k in range(3)]
        beam(u,v,.52,'architecture_char','collapsed_joist',src)
        mid=[(u[k]+v[k])*.5 for k in range(3)]
        end=[mid[0]*.65+peak[0]*.35,mid[1]*.65+peak[1]*.35,mid[2]*.65+peak[2]*.35]
        beam(mid,end,.35,'architecture_frame','broken_sash',src)
    # Long splintered timber and tile fans break up the empty flat yard. These
    # are grounded on its own floor owner, never new visibility or actors.
    for i,(x,y,dx,dy) in enumerate(((-24,-37,18,11),(8,-20,17,-7),
                                   (-16,39,19,15),(17,28,-11,19))):
        beam([x,y,-28.8],[x+dx,y+dy,-27.8],.62,'architecture_char','fallen_floor_rafter',floor)
        for j in range(3):
            xx=x+3+j*3.2;yy=y-3+(j%2)*2.4
            z=-29.1+j*.23
            mat='architecture_slate' if shape==152 else f'architecture_tile_{(i+j)%5}'
            face([[xx,yy,z],[xx+4.3,yy+.7,z+.25],[xx+3.6,yy+4.3,z+.5],
                  [xx-.5,yy+3.1,z+.15]],mat,'scattered_floor_roof_tile',floor)
    # A split masonry window lintel lies across the collapsed slab peak.
    # Its two unequal supported halves expose a real broken cross section.
    for i,(a,b,z) in enumerate(((-15,-2,-9),(1,13,-11))):
        src=walls[2 if i else 1]
        block([a,26,z-2.8],[b,31,z],'architecture_stone_2','fallen_window_lintel',src)
        face([[b,26,z],[b,31,z],[b-1.8,30,z+1.5],[b-1.8,27,z+.8]],
             'architecture_mortar','lintel_fracture',src)
    # The former cottage's foundation courses remain identifiable around two
    # returns. Missing spans are deliberate blast openings, never full new walls.
    for side in (-1,1):
        src=walls[0 if side<0 else -1]
        for row in range(2):
            for j in range(11):
                if j in (4,5,6) and side>0:continue
                y=-60+j*11.5
                top=-24+row*4.1+(1 if j%3==0 else 0)
                block([side*39-2,y,-29+row*4.1],[side*39+2,y+10.8,top],f'architecture_stone_{(j+row)%4}','remaining_foundation',src)
        # A low surviving window jamb, with plaster over its masonry core.
        block([side*39-1.6,-49,-24],[side*39+1.6,-44,-10],'architecture_render','standing_jamb',src)
        beam([side*39,-47,-12],[side*26,-32,-23],.55,'architecture_frame','torn_window_frame',src)


def _farmyard(out,src,ruin,master):
    """Static yard scenery, entirely owned by the original grass/floor face.

    The cow is a surface-lofted dairy animal, with an articulated standing pose.
    It is deliberately absent from the destroyed farm. No simulation entity,
    collider, additional visibility owner or military marking is introduced.
    """
    def face(points,material,part):emit(out,[src],points,material,'architecture_'+part)
    def block(a,b,material,part):box(out,[src],a,b,material,'architecture_'+part)
    def beam(a,b,r,material,part,tip=None):
        tube(out,[src],a,b,r,material,'architecture_'+part,8 if master else 6,tip)
    # A concrete trough has a real recessed basin and separate rim, not a solid
    # grey slab with water painted over it. Its space remains clear of the cow.
    block([-441,25,1],[-370,51,4],'architecture_trough','trough_base')
    for a,b in (((-441,25,4),(-438,51,16)),((-373,25,4),(-370,51,16)),
                ((-438,25,4),(-373,28,16)),((-438,48,4),(-373,51,16))):
        if ruin and a[1]==48:continue
        block(a,b,'architecture_trough','broken_trough_rim' if ruin else 'trough_rim')
    if not ruin:
        face([[-438,28,11],[-373,28,11],[-373,48,11],[-438,48,11]],'architecture_water','trough_water')
        beam([-435,27,16],[-435,27,22],.8,'architecture_zinc','trough_supply')
    else:
        # Fallen rim pieces beside the damaged trough, with no animal remains.
        block([-432,53,1],[-405,57,4],'architecture_trough','fallen_trough_rim')
        block([-398,49,1],[-379,55,5],'architecture_trough','fallen_trough_rim')
    # Yard entrance: braced timber gate, with round iron hinge pins. Destruction
    # retains posts and a grounded, split diagonal rather than another actor.
    for x in (-455,-275):
        block([x-3,-321,0],[x+3,-315,40 if not ruin else 23],'architecture_wood','gate_post')
        block([x-3.5,-321.5,37],[x+3.5,-314.5,39],'architecture_zinc','gate_post_cap') if not ruin else None
    if not ruin:
        for z in (10,23,35):
            block([-451,-320,z],[-279,-317,z+3],'architecture_wood','gate_rail')
        beam([-448,-319,8],[-282,-319,36],1.4,'architecture_wood','gate_diagonal')
        for z in (11,34):beam([-453,-316,z],[-447,-316,z],.9,'architecture_zinc','gate_hinge')
        block([-282,-321,25],[-274,-316,27],'architecture_zinc','gate_latch')
    else:
        beam([-450,-317,8],[-365,-301,3],1.4,'architecture_char','fallen_gate_rail')
        beam([-363,-300,3],[-287,-319,6],1.4,'architecture_wood','split_gate_rail')
        beam([-449,-319,20],[-375,-315,2],1.4,'architecture_char','broken_gate_brace')
    if ruin:
        # Collapse fans follow the breached house and annex walls. Broad broken
        # masonry and tiled roof fragments carry the destruction at game scale;
        # the master retains fine roof courses without spending the game budget.
        def chunk(x,y,z,rx,ry,height,angle,seed):
            ca,sa=math.cos(angle),math.sin(angle)
            sides=5+seed%2
            profile=[(math.cos(j*math.tau/sides)*(.87+.12*math.sin(seed+j*2.3)),
                      math.sin(j*math.tau/sides)*(.87+.12*math.cos(seed*1.7+j))) for j in range(sides)]
            bottom=[];top=[]
            for j,(u,v) in enumerate(profile):
                bottom.append([x+ca*u*rx-sa*v*ry,y+sa*u*rx+ca*v*ry,z])
                top.append([x+ca*(u*rx*.84+rx*.08)-sa*v*ry*.8,
                            y+sa*(u*rx*.84+rx*.08)+ca*v*ry*.8,
                            z+height*(.66+.11*((j+seed)%4))])
            # Buried undersides spend no triangles. Each piece rests directly
            # on the yard; AO and the shared dust field supply ground contact.
            face(top,f'architecture_stone_{seed%4}','yard_broken_masonry')
            for j in range(sides):
                k=(j+1)%sides
                face([bottom[j],bottom[k],top[k],top[j]],
                     'architecture_render' if (j+seed)%3==0 else 'architecture_brick',
                     'yard_exposed_masonry_core')
        for i,(cx,cy,scale) in enumerate(FARM_RUBBLE_CLUSTERS):
            for j in range(3+(i*3)%5):
                angle=i*.83+j*2.39
                spread=0 if j==0 else 16+5*j
                dx=math.cos(angle)*spread;dy=math.sin(angle)*spread*.58
                size=(1.2 if j==0 else .36+.12*((j+i)%4))*scale
                chunk(cx+dx,cy+dy,.12,24*size,16*size,(12 if j==0 else 7)*size,
                      angle+.6,i*7+j)
        # Fallen roof panels retain related tile courses and broken thickness.
        for i,(x,y,angle) in enumerate(((-177,-166,-.2),(-65,-153,.4),
                                       (45,-185,-.45),(272,-245,.7))):
            ca,sa=math.cos(angle),math.sin(angle)
            def p(u,v,z):return [x+u*ca-v*sa,y+u*sa+v*ca,z]
            face([p(-23,-11,.15),p(-11,-14,.15),p(23,-12,.15),p(20,7,2),p(9,14,3),p(-18,11,2)],
                 'architecture_char','yard_fallen_roof_deck')
            for row in range(3):
                for col in range(4):
                    if (i*3+row+col)%5==0 or row==2 and col in (0,3):continue
                    u=-22+col*11+(row%2)*2;v=-13+row*8
                    face([p(u,v,2+row*.7),p(u+10,v,2+row*.7),
                          p(u+9,v+4.5,3+row*.7),p(u+6.5,v+7,3.6+row*.7),p(u+1,v+6,3.6+row*.7)],
                         f'architecture_ochre_{(row+col+i)%5}','yard_fallen_roof_tile')
            beam(p(-21,-12,2),p(20,12,4),1.6,'architecture_char','yard_snapped_roof_batten')
        for a,b in (((-216,-96,10),(-161,-185,2)),((-141,-121,8),(-88,-190,2)),
                    ((-38,-116,10),(32,-174,2)),((239,-111,9),(283,-190,2)),
                    ((-272,57,8),(-322,4,2))):
            beam(a,b,2,'architecture_char','yard_fallen_rafter',tip=.7)
        # Isolated pieces connect the piles without filling the entire lawn.
        for i,(x,y) in enumerate(((-300,-145),(-225,-222),(-124,-238),
                                 (-10,-224),(76,-269),(291,-294),(-332,91))):
            chunk(x,y,.5,6+i%3,5,3.5,i*.8,i)
        return

    white='architecture_cow_white';black='architecture_cow_black'
    pink='architecture_cow_muzzle';hoof='architecture_cow_hoof'
    segments=20 if master else 12

    def loft(stations,part,coat,cap=True):
        # Longitudinal sections carry the back, brisket and hanging belly in
        # one continuous skin, avoiding overlapping spherical body parts.
        rings=[]
        for x,y,z,ry,rz in stations:
            rings.append([[x,y+ry*math.cos(j*math.tau/segments),z+rz*math.sin(j*math.tau/segments)] for j in range(segments)])
        for i,(a,b) in enumerate(zip(rings,rings[1:])):
            for j in range(segments):
                k=(j+1)%segments
                label='broad_muzzle' if part=='head_profile' and i>=3 else part
                face([a[j],a[k],b[k],b[j]],coat(i,(j+.5)/segments),'cow_'+label)
        if cap:
            for ring,station,reverse in ((rings[0],stations[0],True),(rings[-1],stations[-1],False)):
                centre=list(station[:3])
                for j in range(segments):
                    triangle=[centre,ring[j],ring[(j+1)%segments]]
                    face(list(reversed(triangle)) if reverse else triangle,coat(0,(j+.5)/segments),'cow_'+part+'_end')

    def oval(c,r,mat,part,n=8,rows=4):
        stations=[]
        for i in range(rows+1):
            theta=-math.pi/2+math.pi*i/rows
            radius=max(.025,math.cos(theta))
            stations.append((c[0]+r[0]*math.sin(theta),c[1],c[2],r[1]*radius,r[2]*radius))
        # Small features need fewer facets than the primary anatomical skin.
        rings=[[[x,y+ry*math.cos(j*math.tau/n),z+rz*math.sin(j*math.tau/n)] for j in range(n)] for x,y,z,ry,rz in stations]
        for a,b in zip(rings,rings[1:]):
            for j in range(n):face([a[j],a[(j+1)%n],b[(j+1)%n],b[j]],mat,'cow_'+part)
        for ring,c0,rev in ((rings[0],stations[0],True),(rings[-1],stations[-1],False)):
            for j in range(n):
                tri=[list(c0[:3]),ring[j],ring[(j+1)%n]]
                face(tri[::-1] if rev else tri,mat,'cow_'+part)

    body=[(-396,-75,52,5,11),(-388,-75,54,13,20),(-374,-75,51,17,23),
          (-355,-75,51,18,23),(-338,-75,53,16,21),(-328,-75,56,13,20),(-319,-75,58,8,15)]
    def coat(i,t):
        # Broad, contiguous Holstein patches; the white belly and dorsal line
        # remain legible. Their borders follow the skin rather than floating.
        patch=(i<3 and .04<t<.43) or (i>=3 and .55<t<.91)
        return black if patch else white
    loft(body,'piebald_barrel',coat)
    loft([(-328,-75,57,10,16),(-320,-75,60,9,17),(-312,-75,65,7.8,14),(-306,-75,67,7,10)],
         'sloping_neck',lambda i,t:black if .54<t<.94 else white)
    # A long downturned face with a narrow bridge and broad soft muzzle, not
    # a ball attached to a pink cylinder. Forehead, jaw and nose are connected.
    loft([(-311,-75,68,6.5,9),(-304,-75,69,8.7,11),(-296,-75,65,7.3,10),
          (-288,-75,58,6.5,7),(-282,-75,55,7.4,5.3),(-277,-75,55,6,3.7)],
         'head_profile',lambda i,t:pink if i>=3 else white if .12<t<.40 else black)

    # Staggered, weight-bearing legs. Hip/thigh, knee/hock and narrow cannon
    # are continuous tapered sections; rear hocks bend back below the thigh.
    for front in (False,True):
        for side in (-1,1):
            y=-75+side*11.7;shift=1.8 if side>0 else -1.1
            if front:
                joints=[(-330+shift,y,51,5.2,5.0),(-329+shift,y,37,3.6,3.7),
                        (-330+shift,y+side*.6,25,2.9,3.2),(-328+shift,y+side*.9,12,1.9,2.1),(-328+shift,y+side,5.2,2,2.1)]
            else:
                joints=[(-381+shift,y,51,6.2,6.7),(-375+shift,y,35,4,4.4),
                        (-373+shift,y+side*.7,26,2.7,3.0),(-381+shift,y+side,16,2.1,2.5),(-380+shift,y+side,5.2,1.9,2.0)]
            rings=[];n=12 if master else 8
            for x,yy,z,rx,ry in joints:
                rings.append([[x+rx*math.cos(j*math.tau/n),yy+ry*math.sin(j*math.tau/n),z] for j in range(n)])
            for a,b in zip(rings,rings[1:]):
                for j in range(n):
                    k=(j+1)%n
                    face([a[j],b[j],b[k],a[k]],black if not front and a[j][2]>30 else white,'cow_jointed_leg')
            for ring,rev in ((rings[0],False),(rings[-1],True)):
                c=[sum(v[k] for v in ring)/n for k in range(3)]
                for j in range(n):
                    tri=[c,ring[j],ring[(j+1)%n]];face(tri[::-1] if rev else tri,white,'cow_leg_end')
            x,yy,z,_,_=joints[-1]
            for toe in (-1,1):
                # Split wedge-shaped hooves carry a flat grounded sole.
                ya=yy+toe*1.15
                a=[[x-2.6,ya-1.0,1.0],[x+4.0,ya-1.0,1.0],[x+4.0,ya+1.0,1.0],[x-2.6,ya+1.0,1.0]]
                b=[[x-1.8,ya-.85,5.8],[x+2.3,ya-.85,5.8],[x+2.3,ya+.85,5.8],[x-1.8,ya+.85,5.8]]
                face(a[::-1],hoof,'cow_cloven_hoof');face(b,hoof,'cow_cloven_hoof')
                for j in range(4):face([a[j],a[(j+1)%4],b[(j+1)%4],b[j]],hoof,'cow_cloven_hoof')

    oval([-371,-75,28],[9,6.2,4.6],white,'udder',n=8,rows=3)
    for x in (-374,-368):
        for y in (-77.4,-72.6):beam([x,y,24.5],[x,y,22.3],.65,pink,'cow_teat',.45)
    for side in (-1,1):
        # Thick leaf-shaped ears slope out from the poll. Tiny eyes/nostrils
        # use their budget for readable placement rather than sphere tessels.
        yy=-75+side*7.7
        ear=[[-305,yy,76],[-299,yy,75.5],[-299,-75+side*19,77],[-306,-75+side*15,79]]
        face(ear,black,'cow_ear');face([[x,y,z-.7] for x,y,z in ear[::-1]],black,'cow_ear_back')
        face([[-304,yy+side*2,76.1],[-300,-75+side*16,77.1],[-305,-75+side*14,78.3]],pink,'cow_ear_inner')
        oval([-300,-75+side*8.4,71.2],[1.6,.75,1.25],'architecture_cow_eye','eye',n=6,rows=2)
        oval([-278.6,-75+side*4.7,56.1],[1.1,.8,.8],black,'nostril',n=6,rows=2)
        beam([-284,-75+side*6.1,51.8],[-278.5,-75+side*4.3,52.5],.28,black,'cow_mouth',.18)
    beam([-394,-73,61],[-400,-71,36],1.25,white,'cow_tail',.9)
    beam([-400,-71,36],[-399,-66,19],.9,white,'cow_tail',.6)
    oval([-399,-66,16.4],[1.6,1.6,4.4],black,'tail_switch',n=8,rows=3)
