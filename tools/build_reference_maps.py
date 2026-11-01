#!/usr/bin/env python3
"""Author static north-up terrain diagrams from the original PC world placement.

No guest is executed and no actor/mission-trigger position is inferred. The
START scenario selector and SIM resource loader bind title index to WLD index.
"""
from pathlib import Path
import hashlib,html,json,math,struct,sys
ROOT_FOR_IMPORT = Path(__file__).resolve().parents[1]
if str(ROOT_FOR_IMPORT) not in sys.path: sys.path.insert(0, str(ROOT_FOR_IMPORT))
from tools.inspect_scenarios import decode_resource,parse_world
from tools.unpack_pc_executables import unpack
ROOT=Path(__file__).resolve().parents[1]
REF=ROOT/'docs/player-reference'
ORDER=['Nuremberg Highway','Mass Destruction','The Road to Bonn','Hannover Push','Convoy','The Mossel Intercept','The Mossel Defense','Siegen Infiltration']
COLORS={'water':'#568a99','road':'#8b6950','grass':'#8f9b62','earth':'#b6ad7f'}
FEATURES={'bridge':'#d8d2c2','building':'#7a6a5c','tree':'#4d6a3a'}
CASINGS={'bridge':'#4a463f','building':'#3b332c'}

def fingerprint(data):return hashlib.sha256(data).hexdigest()

def source_mapping():
    start,meta=unpack((ROOT/'GAME/START.EXE').read_bytes())
    sim,sim_meta=unpack((ROOT/'GAME/SIM.EXE').read_bytes())
    # Same selector local [bp-18] goes to title arg3 and handoff arg2;
    # d66 writes arg2 to DS845c; 39f6 writes it as byte4 at physical 0510.
    # SIM8398 reads byte4 to DS7784; 7d52 copies it to8d74; 7de6 formats
    # SNARIO<index>. These exact slices are checked, not pattern-inferred.
    checks={
      'selector_title':(start,0x1091,bytes.fromhex('ff76e8ff76faff76e2e8d500')),
      'selector_handoff':(start,0x1156,bytes.fromhex('8a46e88846eaff76faff76e2ff76e88d46ea50e8fafb')),
      'handoff_arg':(start,0x0dff,bytes.fromhex('8b4606a35c84')),
      'handoff_call':(start,0x0e05,bytes.fromhex('b8aa0050ff36029aff36447bff365c84ff36847dff362096ff360493e8d22b')),
      'handoff_byte4':(start,0x3a2e,bytes.fromhex('c45efcff46fc8a460a268807')),
      'sim_reader_byte4':(sim,0x83d8,bytes.fromhex('c45efcff46fc268a07988b5e0a8907')),
      'sim_reader_args':(sim,0x7d3c,bytes.fromhex('b8847750b8967050b8828950b8628650e84906')),
      'sim_byte4':(sim,0x7d52,bytes.fromhex('a08477a2748d')),
      'resource_index':(sim,0x7de6,bytes.fromhex('a0748d0430a27e10')),
    }
    for key,(data,offset,expected) in checks.items():
        if data[offset:offset+len(expected)]!=expected:raise ValueError('Source mapping changed: '+key)
    titles=[]
    for i in range(8):
        pointer=struct.unpack_from('<H',start,0x15050+0x24da+2*i)[0]
        at=0x15050+pointer;end=start.index(b'\0',at)
        titles.append(start[at:end].decode('ascii'))
    if titles!=['NUREMBURG HIGHWAY','MASS DESTRUCTION','THE ROAD TO BONN','HANNOVER PUSH','CONVOY','THE MOSSEL INTERCEPT','THE MOSSEL DEFENSE','SIEGEN INFILTRATION']:
        raise ValueError('Unexpected original scenario title table: '+repr(titles))
    return {'START.EXE':meta['source_sha256'],'SIM.EXE':sim_meta['source_sha256'],'original_titles':titles,
            'association':'START 1091/1172 title,1156/dff/e05/39f6 fourth handoff byte; SIM8398/7d52/7de6 SNARIO index',
            'instruction_slices':{k: {'offset':hex(o),'sha256':fingerprint(v)} for k,(_,o,v) in checks.items()}}

# Static placed structures drawn by their whole top-down footprint. Shapes 45/46
# are ground-level stone crossings, 108 the raised 4096-unit stone deck, and 47
# the gabled building (walls, roof, door, lamp) that sits on earth pad 48.
# Tree 103's crown faces are vertical, so it gets a fixed-size symbol instead.
BRIDGES={45,46,108}
BUILDINGS={47}
TREES={103}
ORDER_KEY={'earth':0,'grass':1,'water':2,'road':3,'bridge':4,'building':5,'tree':6}
CELL=4096
WORLD_CELLS=48  # the original overview spans 48x48 terrain cells

def relief(points3):
    """North-west hillshade factor for one planar face; 1.0 for level ground.

    Every triangle of one plane gets the same value, so split quads and adjacent
    slope pieces read as one surface instead of a patchwork of centroid bands.
    """
    (ax,ay,az),(bx,by,bz),(cx,cy,cz)=points3
    ux,uy,uz=bx-ax,by-ay,bz-az;vx,vy,vz=cx-ax,cy-ay,cz-az
    nx,ny,nz=uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx
    length=math.sqrt(nx*nx+ny*ny+nz*nz)
    if length==0:return 1.0
    nx,ny,nz=nx/length,ny/length,nz/length
    if nz<0:nx,ny,nz=-nx,-ny,-nz
    # Map x is east and y is south; light from the north-west at 45 degrees.
    light=(-0.5,-0.5,math.sqrt(0.5))
    shade=nx*light[0]+ny*light[1]+nz*light[2]
    return min(1.2,max(0.62,shade/math.sqrt(0.5)))

def footprint(wx,wy,model,pad=0.0):
    xs=[wx+p[0] for t in model['triangles'] for p in t['vertices']]
    ys=[wy-p[1] for t in model['triangles'] for p in t['vertices']]
    x0,x1,y0,y1=min(xs)-pad,max(xs)+pad,min(ys)-pad,max(ys)+pad
    return [(x0,y0),(x1,y0),(x1,y1),(x0,y1)]

def geometry(world,catalog):
    faces=[]
    for cell in world['records']:
        for entry in cell['entries']:
            if entry['unused']:continue
            shape=entry['shape_index'];model=catalog['models'][shape]
            wx,wy,_=entry['world_position_raw']
            if shape in BRIDGES or shape in BUILDINGS:
                material='bridge' if shape in BRIDGES else 'building'
                top=max(p[2] for t in model['triangles'] for p in t['vertices'])
                faces.append({'material':material,'points':footprint(wx,wy,model),'height':top,'structure':True})
                continue
            if shape in TREES:
                faces.append({'material':'tree','center':(wx,wy),'height':0})
                continue
            # One elevation band per placed shape: its own summit height.
            top=max(p[2] for t in model['triangles'] for p in t['vertices'])
            for t in model['triangles']:
                if t['material'] not in COLORS:continue
                points=[(wx+p[0],wy-p[1]) for p in t['vertices']]
                area=abs(sum(points[i][0]*points[(i+1)%3][1]-points[(i+1)%3][0]*points[i][1] for i in range(3)))
                if area<1:continue
                points3=[(wx+p[0],wy-p[1],p[2]) for p in t['vertices']]
                faces.append({'material':t['material'],'points':points,'height':sum(p[2] for p in t['vertices'])/3,
                              'summit':top,'relief':relief(points3) if t['material'] in ('grass','earth') else 1.0})
    return sorted(faces,key=lambda f:(ORDER_KEY[f['material']],f['height']))

def frame(faces):
    """Cell-aligned view of the terrain actually present, aspect preserved.

    One empty cell of margin is kept where terrain stops short of the world edge;
    nothing is drawn past the 48-cell overview boundary unless terrain is there.
    """
    xs=[p[0] for f in faces if 'points' in f for p in f['points']]+[f['center'][0] for f in faces if 'center' in f]
    ys=[p[1] for f in faces if 'points' in f for p in f['points']]+[f['center'][1] for f in faces if 'center' in f]
    hi=max(WORLD_CELLS,math.ceil(max(max(xs),max(ys))/CELL))
    x0=max(0,math.floor(min(xs)/CELL)-1);x1=min(hi,math.ceil(max(xs)/CELL)+1)
    y0=max(0,math.floor(min(ys)/CELL)-1);y1=min(hi,math.ceil(max(ys)/CELL)+1)
    return x0*CELL,y0*CELL,(x1-x0)*CELL,(y1-y0)*CELL

def main():
    mapping=source_mapping();catalog=json.loads((ROOT/'local-art/pc-modern/catalog.json').read_text());rows=[]
    for index,name in enumerate(ORDER):
        raw=(ROOT/f'GAME/SNARIO{index}.WLD').read_bytes();world=parse_world(decode_resource(raw));faces=geometry(world,catalog)
        # Fit the terrain actually present into the 780-unit panel, centred,
        # one scale for both axes. A fixed 50-cell box left Mass Destruction
        # and The Road to Bonn half empty and every map off-centre.
        fx,fy,fw,fh=frame(faces);scale=780/max(fw,fh)
        bw,bh=fw*scale,fh*scale;bx,by=44+(780-bw)/2,44+(780-bh)/2
        def at(x,y):return f'{bx+(x-fx)*scale:.3f},{by+(y-fy)*scale:.3f}'
        def hexrgb(rgb):return '#{:02x}{:02x}{:02x}'.format(*[max(0,min(255,round(v))) for v in rgb])
        polys=[]
        for face in faces:
            material=face['material']
            if material=='tree':
                cx,cy=face['center'];r=2.4
                points=' '.join(f'{bx+(cx-fx)*scale+r*math.cos(math.pi*k/4+math.pi/8):.3f},{by+(cy-fy)*scale+r*math.sin(math.pi*k/4+math.pi/8):.3f}' for k in range(8))
                fill=FEATURES['tree']
            elif face.get('structure'):
                # Dark casing, then the deck/roof. Bridges keep a legible
                # minimum symbol size; buildings are drawn to scale.
                (x0,y0),(x1,y1)=face['points'][0],face['points'][2]
                cx,cy=bx+((x0+x1)/2-fx)*scale,by+((y0+y1)/2-fy)*scale
                w,h=(x1-x0)*scale,(y1-y0)*scale
                if material=='bridge':
                    along,across=max(w,h,8.0),max(min(w,h),3.6)
                    w,h=(along,across) if w>=h else (across,along)
                for pad,fill in ((0.8,CASINGS[material]),(0.0,FEATURES[material])):
                    hw,hh=w/2+pad,h/2+pad
                    points=f'{cx-hw:.3f},{cy-hh:.3f} {cx+hw:.3f},{cy-hh:.3f} {cx+hw:.3f},{cy+hh:.3f} {cx-hw:.3f},{cy+hh:.3f}'
                    polys.append(f'<polygon fill="{fill}" stroke="{fill}" stroke-width="0.35" stroke-linejoin="round" points="{points}"/>')
                continue
            else:
                points=' '.join(at(x,y) for x,y in face['points'])
                base=[int(COLORS[material][i:i+2],16) for i in (1,3,5)]
                if material=='grass':
                    # Elevation band from the placed shape's summit, so all
                    # faces of one hill share it; relief shades its slopes.
                    h=min(1,max(0,face['summit']/2048));base=[a+(b-a)*h for a,b in zip([143,155,98],[92,113,71])]
                shade=1+(face['relief']-1)*0.5
                fill=hexrgb([v*shade for v in base])
            # Same-colour edge coverage closes antialiasing hairlines between
            # adjacent triangles, matching the PDF renderer.
            polys.append(f'<polygon fill="{fill}" stroke="{fill}" stroke-width="0.35" stroke-linejoin="round" points="{points}"/>')
        entries=[('Water',COLORS['water'],None),('Road',COLORS['road'],None),('High ground',COLORS['grass'],None),('Earth faces',COLORS['earth'],None),
                 ('Bridge',FEATURES['bridge'],CASINGS['bridge']),('Building',FEATURES['building'],CASINGS['building']),('Trees',FEATURES['tree'],'tree')]
        legend=''
        for j,(label,colour,casing) in enumerate(entries):
            y=258+j*50
            if casing=='tree':
                legend+='<polygon fill="{}" points="{}"/>'.format(colour,' '.join(f'{884+7*math.cos(math.pi*k/4+math.pi/8):.2f},{y+9+7*math.sin(math.pi*k/4+math.pi/8):.2f}' for k in range(8)))
            elif casing:
                legend+=f'<rect x="867" y="{y}" width="34" height="18" rx="2" fill="{casing}"/><rect x="870" y="{y+3}" width="28" height="12" rx="1" fill="{colour}"/>'
            else:
                legend+=f'<rect x="867" y="{y}" width="34" height="18" rx="2" fill="{colour}"/>'
            legend+=f'<text x="920" y="{y+15}" font-size="22">{label}</text>'
        box=f'x="{bx:.3f}" y="{by:.3f}" width="{bw:.3f}" height="{bh:.3f}"'
        svg=f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1130 868" role="img"><title>{html.escape(name)}: original game terrain</title><defs><clipPath id="map"><rect {box}/></clipPath></defs><rect width="1130" height="868" fill="#f7f2e7"/><g clip-path="url(#map)"><rect {box} fill="#e1e4cf"/>{''.join(polys)}</g><rect {box} fill="none" stroke="#384e52" stroke-width="2"/><g fill="#253c41" font-family="sans-serif"><text x="879" y="102" font-size="26" font-weight="bold">N</text><polygon points="889,118 877,157 889,149 901,157" fill="#253c41"/><line x1="889" y1="147" x2="889" y2="208" stroke="#253c41" stroke-width="2"/>{legend}<text x="867" y="640" font-size="20">Original PC terrain</text><text x="867" y="674" font-size="17">North-up projection</text><text x="867" y="708" font-size="17">Static world geometry</text><text x="867" y="742" font-size="17">No actor positions</text></g></svg>'''
        file='scenario-'+name.lower().replace(' ','-')+'.svg';(REF/file).write_text(svg)
        rows.append({'name':name,'file':file,'caption':'PC terrain map','resource':f'SNARIO{index}.WLD','source_sha256':fingerprint(raw),'svg_sha256':fingerprint(svg.encode()),'faces':len(faces),
                     'frame_cells':[fx//CELL,fy//CELL,fw//CELL,fh//CELL],
                     'features':{k:sum(1 for f in faces if f['material']==k) for k in ('bridge','building','tree')}})
    (REF/'maps-provenance.json').write_text(json.dumps({'mapping':mapping,'geometry_catalog_sha256':fingerprint((ROOT/'local-art/pc-modern/catalog.json').read_bytes()),'maps':rows},indent=2)+'\n')
    visuals=json.loads((REF/'visuals.json').read_text());visuals['maps']=[{k:r[k] for k in ['name','file','caption']} for r in rows];(REF/'visuals.json').write_text(json.dumps(visuals,indent=2)+'\n')
    print('Source mapping verified. Eight original-world terrain diagrams created.')
if __name__=='__main__':main()
