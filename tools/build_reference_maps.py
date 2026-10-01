#!/usr/bin/env python3
"""Author static north-up terrain diagrams from the original PC world placement.

No guest is executed and no actor/mission-trigger position is inferred. The
START scenario selector and SIM resource loader bind title index to WLD index.
"""
from pathlib import Path
import hashlib,html,json,math,struct
from tools.inspect_scenarios import decode_resource,parse_world
from tools.unpack_pc_executables import unpack
ROOT=Path(__file__).resolve().parents[1]
REF=ROOT/'docs/player-reference'
ORDER=['Nuremberg Highway','Mass Destruction','The Road to Bonn','Hannover Push','Convoy','The Mossel Intercept','The Mossel Defense','Siegen Infiltration']
COLORS={'water':'#568a99','road':'#8b6950','grass':'#8f9b62','earth':'#b6ad7f'}

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

def geometry(world,catalog):
    faces=[]
    for cell in world['records']:
        for entry in cell['entries']:
            if entry['unused']:continue
            model=catalog['models'][entry['shape_index']]
            wx,wy,_=entry['world_position_raw']
            for t in model['triangles']:
                if t['material'] not in COLORS:continue
                points=[(wx+p[0],wy-p[1]) for p in t['vertices']]
                area=abs(sum(points[i][0]*points[(i+1)%3][1]-points[(i+1)%3][0]*points[i][1] for i in range(3)))
                if area<1:continue
                faces.append({'material':t['material'],'points':points,'height':sum(p[2] for p in t['vertices'])/3})
    return sorted(faces,key=lambda f:({'earth':0,'grass':1,'water':2,'road':3}[f['material']],f['height']))

def main():
    mapping=source_mapping();catalog=json.loads((ROOT/'local-art/pc-modern/catalog.json').read_text());rows=[]
    for index,name in enumerate(ORDER):
        raw=(ROOT/f'GAME/SNARIO{index}.WLD').read_bytes();world=parse_world(decode_resource(raw));faces=geometry(world,catalog)
        extent=50*4096 # Source terrain envelope, without displaying unused directory margin.
        ox,oy,side=44,44,780
        polys=[]
        for face in faces:
            points=' '.join(f'{ox+x/extent*side:.3f},{oy+y/extent*side:.3f}' for x,y in face['points'])
            fill=COLORS[face['material']]
            if face['material']=='grass':
                # Cartographic height bands, original elevations only.
                h=min(1,max(0,face['height']/2048));rgb=[round(a+(b-a)*h) for a,b in zip([143,155,98],[92,113,71])]
                fill='#{:02x}{:02x}{:02x}'.format(*rgb)
            polys.append(f'<polygon fill="{fill}" points="{points}"/>')
        legend=''.join(f'<rect x="867" y="{272+j*60}" width="34" height="18" rx="2" fill="{c}"/><text x="920" y="{287+j*60}" font-size="22">{label}</text>' for j,(m,c,label) in enumerate([(m,COLORS[m],label) for m,label in [('water','Water'),('road','Road'),('grass','High ground'),('earth','Earth faces')]]))
        svg=f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1130 868" role="img"><title>{html.escape(name)}: original game terrain</title><defs><clipPath id="map"><rect x="44" y="44" width="780" height="780"/></clipPath></defs><rect width="1130" height="868" fill="#f7f2e7"/><g clip-path="url(#map)"><rect x="44" y="44" width="780" height="780" fill="#e1e4cf"/>{''.join(polys)}</g><rect x="44" y="44" width="780" height="780" fill="none" stroke="#384e52" stroke-width="2"/><g fill="#253c41" font-family="sans-serif"><text x="879" y="102" font-size="26" font-weight="bold">N</text><polygon points="889,118 877,157 889,149 901,157" fill="#253c41"/><line x1="889" y1="147" x2="889" y2="208" stroke="#253c41" stroke-width="2"/>{legend}<text x="867" y="606" font-size="20">Original PC terrain</text><text x="867" y="640" font-size="17">North-up projection</text><text x="867" y="674" font-size="17">Static world geometry</text><text x="867" y="708" font-size="17">No actor positions</text></g></svg>'''
        file='scenario-'+name.lower().replace(' ','-')+'.svg';(REF/file).write_text(svg)
        rows.append({'name':name,'file':file,'caption':'PC terrain map','resource':f'SNARIO{index}.WLD','source_sha256':fingerprint(raw),'svg_sha256':fingerprint(svg.encode()),'faces':len(faces)})
    (REF/'maps-provenance.json').write_text(json.dumps({'mapping':mapping,'geometry_catalog_sha256':fingerprint((ROOT/'local-art/pc-modern/catalog.json').read_bytes()),'maps':rows},indent=2)+'\n')
    visuals=json.loads((REF/'visuals.json').read_text());visuals['maps']=[{k:r[k] for k in ['name','file','caption']} for r in rows];(REF/'visuals.json').write_text(json.dumps(visuals,indent=2)+'\n')
    print('Source mapping verified. Eight original-world terrain diagrams created.')
if __name__=='__main__':main()
