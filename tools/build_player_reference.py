#!/usr/bin/env python3
"""Author the offline player references from reviewed manual facts and current models.

Requires ReportLab only for authoring. The installed app reads static HTML/PDF,
never the original manual, a browser server, or an additional runtime package.
"""
from __future__ import annotations
import argparse
import hashlib
import html
import json
import math
from pathlib import Path
from reportlab.pdfgen import canvas
from reportlab import rl_config
from reportlab.lib.colors import HexColor, Color
from reportlab.lib.pagesizes import A4, landscape
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph
from reportlab.lib.styles import ParagraphStyle

ROOT=Path(__file__).resolve().parents[1]
REF=ROOT/'docs/player-reference'
PDF=ROOT/'output/pdf'
ESC=html.escape
rl_config.useA85=0  # binary streams: ASCII85 would add a quarter to every embedded image
BG='#111a21'; INK='#17242b'; CREAM='#f4ead4'; MUTED='#bec7c8'; RED='#b84638'; GOLD='#e4b879'
SHORTCUTS=[
 ('Quick save, slot 1','Cmd+S','Ctrl+Alt+S'),
 ('Quick load, slot 1','Cmd+L','Ctrl+Alt+L'),
 ('Undo last load','Cmd+Shift+L','Ctrl+Alt+Shift+L'),
 ('Cycle graphics','Cmd+G','Ctrl+Alt+G'),
 ('Toggle 8x / normal speed','Tab','Tab'),
]
MODEL_NAMES={'M1A1 Abrams':'M1-A1','M60A3':'M60a3','M2 Bradley':'M2','Mi-24 Hind':'HIND','FST-1':'F-ST','BTR':'BTR-70'}
SPEC_LABELS={'introduced_year':'Introduced','combat_weight_tons':'Weight (t)','length_m':'Length (m)','width_m':'Width (m)','height_m':'Height (m)','maximum_speed_kmh':'Maximum speed (km/h)','primary_armament':'Primary weapon','secondary_armament':'Secondary weapon','reload_seconds':'Reload (s)','range_m':'Range (m)','armor':'Armour','overall_threat':'Threat'}

def slug(name): return name.lower().replace(' ','-')

def credit_html():
    credits=json.loads((REF/'credits.json').read_text())
    rows=''.join('<dt>'+ESC(r['role'])+'</dt><dd>'+ESC(', '.join(r['names']))+'</dd>' for r in credits['rows'])
    return '<section class="credits"><h2>Original creators</h2><h3>Original game by Dynamix</h3><p>Published by Electronic Arts</p><dl>'+rows+'</dl><p>'+ESC(credits['copyright'])+'</p><h3>Fan remaster</h3><p>Fan Remastered by Nell Watson<br>Dedicated to David “Ming” Kenny.</p></section>'

def visual(name,group):
    return next((r for r in json.loads((REF/'visuals.json').read_text()).get(group,[]) if r['name']==name),None)

def figure(name,group):
    row=visual(name,group)
    if not row:return ''
    if not row.get('file'):return ''
    return '<figure class="'+group+'"><img src="'+ESC(row['file'])+'" alt="'+ESC(name+': '+row['caption'])+'" loading="lazy"><figcaption>'+ESC(row['caption'])+'</figcaption></figure>'


def refs(row):
    pages=sorted({p['printed_page'] for p in row.get('page_refs',[]) if p.get('printed_page') is not None})
    return 'Manual p. '+', '.join(map(str,pages))


def model_shapes(catalog):
    return {row['name']:row['shapes']['primary'] for row in catalog['classes']}


def noise(point):
    def mix(a,b,t): return a+(b-a)*t
    def cell_hash(x,y):
        p=[(x*.1031)%1,(y*.1030)%1,(x*.0973)%1]
        d=sum(a*(b+33.33) for a,b in zip(p,[p[1],p[2],p[0]]))
        p=[v+d for v in p]
        return ((p[0]+p[1])*p[2])%1
    x,y=point;ix,iy=math.floor(x),math.floor(y);fx,fy=x-ix,y-iy
    bx,by=fx*fx*(3-2*fx),fy*fy*(3-2*fy)
    return mix(mix(cell_hash(ix,iy),cell_hash(ix+1,iy),bx),mix(cell_hash(ix,iy+1),cell_hash(ix+1,iy+1),bx),by)


def study_colour(model,triangle):
    # Static facet samples of the existing source-local livery. No gameplay shader changes.
    color=triangle['color'][:3]
    if triangle.get('material') not in ['olive','olive_edge']:return color
    raw=[sum(v[i] for v in triangle['vertices'])/3 for i in range(3)]
    if model['shape_index'] in [163,164]:
        y,z=raw[1:];px,py=y/86+4.3,z/70+1.9
        px,py=px+math.sin(py*2.1)*.25,py+math.sin(px*1.7)*.25
        patch=noise((px,py))>.49
        tint=[1.663793,1.554688,2.104651] if patch else [1.129310,1.156250,1.023256]
        bottom=-40+max(0,min(1,(-40-y)/260))*100
        if z-bottom<18:tint=[.534483,1.203125,2.151163]
        return [c*t for c,t in zip(color,tint)]
    if model.get('paint_style')=='two_tone_olive':
        x,y,z=raw;px,py=(y+x*.45)/62+1.8,(z+x*.25)/54+3.2
        px,py=px+math.sin(py*1.6)*.22,py+math.sin(px*1.8)*.22
        tint=[1.16,1.12,1.19] if noise((px,py))>.49 else [.85,.90,.83]
        return [c*t for c,t in zip(color,tint)]
    return color


def model_polygons(model,width=640,height=245):
    # Same existing authored mesh and colours, projected as a static catalogue study.
    faces=[]
    for triangle in model['triangles']:
        v=triangle['vertices']
        points=[(p[0]*.78+p[1]*.62,p[2]*.85+(p[1]*.78-p[0]*.62)*.32) for p in v]
        depth=sum(p[0]*.62-p[1]*.78+p[2]*.5 for p in v)/3
        a=[v[1][i]-v[0][i] for i in range(3)];b=[v[2][i]-v[0][i] for i in range(3)]
        n=[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
        length=math.sqrt(sum(x*x for x in n)) or 1
        light=.76+.24*abs(sum(n[i]*[.35,-.25,.9][i] for i in range(3))/length)
        color=tuple(min(255,round(x*light)) for x in study_colour(model,triangle))
        faces.append((depth,points,color))
    for line in model.get('source_lines',[]):
        v=line['vertices']
        if len(v)!=2:continue
        points=[(p[0]*.78+p[1]*.62,p[2]*.85+(p[1]*.78-p[0]*.62)*.32) for p in v]
        depth=sum(p[0]*.62-p[1]*.78+p[2]*.5 for p in v)/2
        faces.append((depth,points,(45,54,47)))
    all_points=[p for _,points,_ in faces for p in points]
    if not all_points:return []
    xmin=min(p[0] for p in all_points);xmax=max(p[0] for p in all_points)
    ymin=min(p[1] for p in all_points);ymax=max(p[1] for p in all_points)
    scale=min((width-28)/max(1,xmax-xmin),(height-22)/max(1,ymax-ymin))
    ox=(width-(xmax-xmin)*scale)/2;oy=(height-(ymax-ymin)*scale)/2
    return [([(ox+(x-xmin)*scale,oy+(y-ymin)*scale) for x,y in points],color) for _,points,color in sorted(faces,key=lambda r:r[0])]


def illustrations(data):
    catalogue=json.loads((ROOT/'local-art/pc-modern/catalog.json').read_text())
    shapes=model_shapes(catalogue); manifest=[]
    for row in data['vehicles']:
        name=MODEL_NAMES.get(row['name'],row['name']);index=shapes[name]
        filename='vehicle-'+row['name'].lower().replace(' ','-')+'.svg'
        polygons=model_polygons(catalogue['models'][index])
        markup=''.join(('<polyline fill="none" stroke-width="1.4" stroke="#{:02x}{:02x}{:02x}" points="'.format(*color) if len(pts)==2 else '<polygon fill="#{:02x}{:02x}{:02x}" points="'.format(*color))+' '.join(f'{x:.2f},{245-y:.2f}' for x,y in pts)+'"/>' for pts,color in polygons)
        svg=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 245" role="img"><title>{ESC(row["name"])}: current Modern mesh study</title>{markup}</svg>'
        (REF/filename).write_text(svg,encoding='utf-8')
        manifest.append({'name':row['name'],'shape_index':index,'svg':filename,'triangles':sum(len(pts)==3 for pts,_ in polygons),'lines':sum(len(pts)==2 for pts,_ in polygons),'model_sha256':hashlib.sha256(json.dumps(catalogue['models'][index],sort_keys=True).encode()).hexdigest()})
    (REF/'illustrations.json').write_text(json.dumps({'catalog_sha256':hashlib.sha256((ROOT/'local-art/pc-modern/catalog.json').read_bytes()).hexdigest(),'kind':'static orthographic studies of current Modern mesh geometry','vehicles':manifest},indent=2)+'\n')
    return catalogue,shapes


CSS='''
:root{color-scheme:dark;--bg:#111a21;--cream:#f4ead4;--muted:#bec7c8;--gold:#e4b879;--line:#405058}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--cream);font:16px/1.6 system-ui,-apple-system,"Segoe UI",sans-serif}
main{max-width:1050px;margin:auto;padding:40px 32px 64px}h1,h2{font-family:Barlow,system-ui,sans-serif;line-height:1.15;letter-spacing:0}h1{font-size:46px;margin:0 0 14px}h2{font-size:30px;margin:44px 0 18px}h3{font-size:21px;line-height:1.3;margin:0 0 8px;font-weight:650}p{max-width:72ch;margin:9px 0 16px}.lead{font-size:18px;color:var(--muted)}nav{display:flex;flex-wrap:wrap;gap:20px;padding:18px 0;margin:22px 0 28px;border-block:1px solid var(--line)}a{color:var(--gold);text-underline-offset:4px}a:focus-visible,summary:focus-visible,input:focus-visible{outline:2px solid var(--gold);outline-offset:5px}input{font:inherit;background:#19262e;color:var(--cream);border:1px solid #61727b;border-radius:8px;padding:10px 14px;width:100%;max-width:540px}label{display:block;margin:18px 0 8px}article{scroll-margin-top:24px;padding:24px 0;border-bottom:1px solid var(--line);break-inside:avoid}article header{display:flex;gap:14px;align-items:baseline;justify-content:space-between;flex-wrap:wrap}.badge{color:var(--gold);font-size:13px}.friendly{color:#b5d8c5}.objective{font-weight:650;color:var(--cream)}.source{font-size:13px;color:var(--muted)}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:0 38px}figure{margin:18px 0;background:#e9e3d5;border-radius:12px;padding:10px}figure img{width:100%;height:auto;display:block}figcaption{font-size:12px;color:#39484c;text-align:center}dl{display:grid;grid-template-columns:minmax(120px,1fr) 1.65fr;gap:6px 16px;font-size:14px;margin:16px 0}dt{color:var(--muted)}dd{margin:0}table{border-collapse:collapse;width:100%;font-size:14px;margin:14px 0 24px}th{text-align:left;font-weight:650;color:var(--gold)}th,td{padding:10px 12px;border-bottom:1px solid var(--line);vertical-align:top}th:first-child,td:first-child{padding-left:0}kbd{display:inline-block;font-family:Barlow,system-ui,sans-serif;font-size:24px;line-height:1.25;font-weight:700;color:var(--cream);padding:4px 10px;background:#26343d;border:1px solid #52656e;border-radius:6px;white-space:normal}.key{width:210px}td:has(kbd){padding-right:28px}.scenario-map-pair{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px;align-items:start}.scenario-map-pair figure{margin:24px 0;min-width:0}figure.wireframes{background:#fff}figure.maps,figure.manual_maps{max-width:720px;margin:24px auto}.credits{margin:40px 0;padding-block:8px 24px;border-block:1px solid var(--line)}.credits dl{max-width:680px} .credits h3{font-size:25px}footer{margin-top:42px;padding-top:20px;border-top:1px solid var(--line);font-size:13px;color:var(--muted)}details{margin:12px 0}summary{cursor:pointer;color:var(--gold)}[hidden]{display:none!important}::selection{background:#724635;color:#fff}html{scrollbar-color:#70858d #111a21}
@media(max-width:700px){main{padding:28px 20px}h1{font-size:36px}.grid,.scenario-map-pair{grid-template-columns:1fr}.key{width:135px}kbd{font-size:21px}table{font-size:16px}th,td{padding:9px 6px}}
@media(prefers-reduced-transparency:no-preference){nav{background:#152129d9;backdrop-filter:blur(12px);border-radius:10px;padding:18px}}
@media print{body{background:white;color:#17242b}main{padding:0;max-width:none}h1{font-size:30px}h2{font-size:24px}nav,.search,.print-link{display:none}a,.badge,.source,dt,.lead,footer,th,kbd,.objective{color:#33484e}article{border-color:#b9c1c4}table{font-size:11px}th,td{padding:6px}kbd{background:#e1e4da;border-color:#66767b}figure{background:#eee}.grid{gap:24px}details{display:block}}
'''


def html_page(title,body,other):
    # All links/assets are local. The only script is local catalogue filtering.
    font='';fp=ROOT/'godot/assets/fonts/BarlowCondensed-SemiBold.ttf'
    import base64
    if fp.is_file():font='@font-face{font-family:Barlow;src:url(data:font/ttf;base64,'+base64.b64encode(fp.read_bytes()).decode()+') format("truetype");font-weight:600;font-display:swap}'
    return f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; font-src data:; img-src 'self' data:; script-src 'unsafe-inline'"><title>{ESC(title)} | Abrams Fan Remaster</title><style>{font}{CSS}</style></head><body><main><h1>{ESC(title)}</h1><p class="lead">M1 Abrams Battle Tank Fan Remaster</p><p class="creator">Original game by <strong>Dynamix</strong>, published by <strong>Electronic Arts</strong>.</p><nav aria-label="Reference navigation">{other}<a href="#content">Read reference</a></nav>{body}{credit_html()}<footer>Original game by Dynamix. Fan Remastered by Nell Watson. Dedicated to David “Ming” Kenny.<br>Manual references use the original printed page numbers. Vehicle figures and threat ratings reproduce the manual's game-era data.</footer></main></body></html>'''


def controls_html(data):
    controls=data['keyboard_controls']; sections=[]
    groups=[('Stations and general commands',lambda r: r['name'].startswith('F') and r['name'] not in ['F7','F8','F9','F10'] or r['name'] in ['Q','Esc','Shift+3']),('Hull and turret',lambda r:r['name'] in ['A','C'] or r['name'].startswith('Keypad')),('Gunner',lambda r:r.get('stations')==['gunner']),('Commander',lambda r:r.get('stations')==['commander']),('Radio and thermal',lambda r:r['name'] in ['R','T']),('Menus and briefings',lambda r:any(v in ['menus','mission_start','presentation'] for v in r.get('stations',[])))]
    covered=set()
    for title,predicate in groups:
        rows=[]
        for i,row in enumerate(controls):
            if predicate(row) and i not in covered:
                covered.add(i); rows.append(row)
        if rows:sections.append('<section><h2>'+title+'</h2><table><thead><tr><th class="key">Key</th><th>Action</th></tr></thead><tbody>'+''.join(f'<tr><td><kbd>{ESC(r["name"])}</kbd></td><td>{ESC(r["description"])}</td></tr>' for r in rows)+'</tbody></table></section>')
    remaining=[r for i,r in enumerate(controls) if i not in covered]
    if remaining:sections.append('<section><h2>Additional context</h2><table>'+''.join(f'<tr><td><kbd>{ESC(r["name"])}</kbd></td><td>{ESC(r["description"])}</td></tr>' for r in remaining)+'</table></section>')
    chords=''.join(f'<tr><td>{ESC(action)}</td><td><kbd>{mac}</kbd></td><td><kbd>{other}</kbd></td></tr>' for action,mac,other in SHORTCUTS)
    body='<p class="print-link"><a href="keyboard-controls.pdf">Printable keyboard sheet (PDF)</a></p><div id="content"><h2>Remaster shortcuts</h2><table><tr><th>Action</th><th>macOS</th><th>Windows / Linux</th></tr>'+chords+'</table><p>Press Tab to toggle 8x fast forward and normal speed. Session provides five save slots and Undo last load. Graphics switches EGA, Genesis, Upscaled and Modern. Audio is muted during fast forward.</p><p>Pause with Esc before opening a reference if you want the original simulation to wait. Help never sends an extra command to the game. Release held keys after returning from a menu or another window.</p>'+''.join(sections)+'<p class="source">Original controls: manual pp. 4 to 7, with station and menu context on pp. 9 to 20. Remaster shortcuts are taken from the implemented Play controls.</p></div>'
    return html_page('Keyboard controls',body,'<a href="field-guide.html">Scenarios & vehicles</a>')


def catalogue_html(data):
    missions=''.join(f'<article data-search><header><h3>{ESC(row["name"])}</h3><span class="source">{refs(row)}</span></header><p>{ESC(row["description"])}</p><p class="objective">Objective: {ESC(row["primary_objective"])}</p>'+(''.join(f'<p>{ESC(row[k])}</p>' for k in ['secondary_objective','restriction'] if k in row))+('<p>Watch for: '+ESC(' '.join(row['hazards']))+'</p>' if row.get('hazards') else '')+'<div class="scenario-map-pair">'+figure(row['name'],'manual_maps')+figure(row['name'],'maps')+'</div>'+'</article>' for row in data['missions'])
    vehicles=[]
    for row in data['vehicles']:
        specs=''.join(f'<dt>{SPEC_LABELS[k]}</dt><dd>{ESC(str(v)) if v is not None else "Unknown / not stated"}</dd>' for k,v in row['specs'].items())
        image='vehicle-'+row['name'].lower().replace(' ','-')+'.svg'
        vehicles.append(f'<article data-search><header><h3>{ESC(row["name"])}</h3><span class="badge '+('friendly' if row['allegiance']=='FRIENDLY' else '')+'">'+row['allegiance']+'</span></header><p class="source">'+ESC(row['role'])+' · '+refs(row)+'</p>'+figure(row['name'],'wireframes')+figure(row['name'],'models')+'<p>'+ESC(row['description'])+'</p>'+'<details><summary>Manual specifications</summary><dl>'+specs+'</dl></details></article>')
    extra=[]
    for key,title in [('anti_tank_guided_weapons','Anti-tank guided weapons'),('ammunition_and_armament','Ammunition & armament'),('other_units_and_objectives','Other units & objectives')]:
        entries=''.join('<article data-search><header><h3>'+ESC(row['name'])+'</h3><span class="source">'+refs(row)+'</span></header><p>'+ESC(row['description'])+'</p>'+('<p>Range: '+ESC(str(row['range_m']))+' m</p>' if row.get('range_m') is not None else '')+'</article>' for row in data[key])
        extra.append('<section><h2>'+ESC(title)+'</h2>'+entries+'</section>')
    body='<p class="print-link"><a href="field-guide.pdf">Printable scenario and vehicle catalogue (PDF)</a></p><div class="search"><label for="search">Find a scenario, vehicle or weapon</label><input id="search" type="search" placeholder="For example: Convoy, M113, sabot" autocomplete="off"><p id="count" role="status" aria-live="polite"></p></div><div id="content"><section id="scenarios"><h2>The eight scenarios</h2><p>'+ESC(data['training']['description'])+'</p><p>Choose your ammunition mix and governor in the Motor Pool. Each scenario pairs a NATO-style manual map with its extracted PC game-data map.</p>'+missions+'</section><section id="vehicles"><h2>Vehicle recognition</h2><p>Recognise friendly and enemy vehicles. Specifications and threat ratings follow the original game manual.</p><div class="grid">'+''.join(vehicles)+'</div></section>'+''.join(extra)+'<section><h2>Campaign and stations</h2><p>'+ESC(data['campaign']['description'])+'</p>'+''.join('<article data-search><h3>'+ESC(row['name'])+(' · '+row['key'] if row['key'] else '')+'</h3><p>'+ESC(row['description'])+'</p><p class="source">'+refs(row)+'</p></article>' for row in data['stations'])+'</section></div><script>const q=document.getElementById("search"),rows=[...document.querySelectorAll("[data-search]")],count=document.getElementById("count");q.addEventListener("input",()=>{let shown=0;for(const row of rows){row.hidden=!row.textContent.toLowerCase().includes(q.value.toLowerCase().trim());if(!row.hidden)shown++}count.textContent=q.value ? shown+(shown===1?" matching entry":" matching entries") : ""});</script>'
    return html_page('Scenarios & vehicles',body,'<a href="keyboard-controls.html">Keyboard controls</a><a href="#scenarios">Scenarios</a><a href="#vehicles">Vehicles</a>')


class Book:
    def __init__(self,path,title,page_size=A4,doc_title=None):
        self.c=canvas.Canvas(str(path),pagesize=page_size,pageCompression=1)
        self.c.setTitle(doc_title or title);self.c.setAuthor('Nell Watson / Abrams Fan Remaster')
        self.c.setSubject('Player reference for the fan remaster of Dynamix’s Abrams Battle Tank')
        self.c.setKeywords('Abrams Battle Tank, Dynamix, M1 Abrams, tank simulator, MS-DOS, fan remaster');self.c.setCreator('Abrams Fan Remaster')
        self.w,self.h=page_size;self.page_size=page_size;self.number=0;self.title=title
        self.style=ParagraphStyle('body',fontName='Helvetica',fontSize=10,leading=14,textColor=HexColor(INK))
    def page(self,heading,page_size=None):
        if self.number:self.c.showPage()
        page_size=page_size or self.page_size
        self.w,self.h=page_size;self.c.setPageSize(page_size)
        self.number+=1; c=self.c
        c.setFillColor(HexColor('#f7f2e7'));c.rect(0,0,self.w,self.h,fill=1,stroke=0)
        c.setFillColor(HexColor(INK));c.rect(0,self.h-92,self.w,92,fill=1,stroke=0)
        c.setFillColor(HexColor(CREAM));c.setFont('Helvetica',10);c.drawString(32,self.h-30,'M1 ABRAMS BATTLE TANK FAN REMASTER')
        c.setFont('Barlow',27);c.drawString(32,self.h-64,heading)
        c.setStrokeColor(HexColor('#bbc0ba'));c.line(32,40,self.w-32,40)
        c.setFont('Helvetica',8);c.setFillColor(HexColor('#4c5a5e'));c.drawString(32,25,'Original game by Dynamix · Fan Remastered by Nell Watson')
        c.drawRightString(self.w-32,25,str(self.number))
    def para(self,text,x,y,width,size=10,color=INK):
        style=ParagraphStyle('p',parent=self.style,fontSize=size,leading=size*1.4,textColor=HexColor(color))
        p=Paragraph(text,style);_,h=p.wrap(width,self.h)
        assert y-h>=47,('Page overflow',self.number,text[:55],y,h)
        p.drawOn(self.c,x,y-h);return y-h-8
    def heading(self,text,x,y,size=18):
        self.c.setFont('Barlow',size);self.c.setFillColor(HexColor(INK));self.c.drawString(x,y,text);return y-16
    def finish(self):self.c.save()


def key_rows(b, rows, x, y, width, key_width=92):
    for key,action in rows:
        kp=Paragraph(ESC(key),ParagraphStyle('key',fontName='Helvetica-Bold',fontSize=13,leading=16,textColor=HexColor(INK)))
        dp=Paragraph(ESC(action),ParagraphStyle('action',fontName='Helvetica',fontSize=10,leading=14,textColor=HexColor(INK)))
        _,kh=kp.wrap(key_width-10,b.h);_,dh=dp.wrap(width-key_width-14,b.h)
        h=max(kh,dh)+14
        assert y-h>=47,('Key row overflow',key,y,h)
        b.c.setFillColor(HexColor('#e5e6db'));b.c.roundRect(x-5,y-h+5,key_width,h-5,4,fill=1,stroke=0)
        kp.drawOn(b.c,x+2,y-kh-4);dp.drawOn(b.c,x+key_width+10,y-dh-4)
        y-=h
    return y


def keyboard_pdf(data):
    b=Book(PDF/'keyboard-controls.pdf','Keyboard controls',landscape(A4),'M1 Abrams Battle Tank Fan Remaster – Keyboard Controls')
    b.page('Keyboard controls')
    top=b.h-125
    groups=[
      [('Stations',[('F1','Gunner'),('F2','Commander'),('F3','Cupola'),('F4','Driver')]),('Hull and turret',[('C','Switch hull / turret control'),('A','Align turret with hull'),('Up / KP8','Forward / raise sight'),('Down / KP2','Reverse / lower sight'),('Left / KP4','Turn left'),('Right / KP6','Turn right'),('KP5','Stop hull / turret')])],
      [('Gunner',[('Enter','Cycle available targets'),('L','Lock selected target'),('Space','Fire selected weapon'),('M','Fire machine gun'),('1 / 2 / 3','HEAT / sabot / AX'),('S','Smoke'),('Z','Sight: normal, 3x, 10x')]),('Gunner & commander',[('T','Thermal imaging'),('R','Retrieve waiting radio message')])],
      [('Commander',[('D','Damage screen, any key returns'),('Z','Map: close-up / overview'),('F7','Current turret bearing'),('F8','Scan +90 degrees'),('F9','Scan +180 degrees'),('F10','Scan +270 degrees')]),('Session',[('Esc','Pause / back, any key resumes'),('Q','Quit sequence'),('F5','Sound on / off'),('Shift+3','Original system speed')])]
    ]
    for x,group in zip([32,303,574],groups):
        y=top
        for title,rows in group:
            y=b.heading(title,x,y,21)-5
            y=key_rows(b,rows,x,y,236)-24
    b.page('Remaster shortcuts & menus')
    y=b.h-126
    y=b.para('The remaster uses Command on macOS and Control + Alt on Windows and Linux. These shortcuts are separate from the original game commands.',32,y,b.w-64,11)-12
    b.c.setFillColor(HexColor(INK));b.c.setFont('Barlow',20)
    for x,title in [(32,'macOS'),(276,'Windows / Linux'),(561,'Action')]:b.c.drawString(x,y,title)
    y-=18
    for action,mac,other in SHORTCUTS:
        b.c.setFillColor(HexColor('#e5e6db'));b.c.roundRect(27,y-41,787,40,4,fill=1,stroke=0)
        b.para('<b>'+mac.replace('+',' + ')+'</b>',36,y-8,225,15)
        b.para('<b>'+other.replace('+',' + ')+'</b>',280,y-8,264,15)
        b.para(ESC(action),561,y-11,245,11)
        y-=50
    y=b.heading('Session, graphics & help',32,y-23,21)
    y=b.para('Press Tab to toggle 8x fast forward and normal speed. Session provides five save slots and Undo last load. Graphics switches immediately between EGA, Genesis, Upscaled and Modern. Help opens the offline controls and field guide. Audio is muted during fast forward.',32,y,b.w-64,11)
    b.page('Menus, context & original creators')
    y=b.h-126
    y=b.heading('Menus and briefings',32,y,21)
    y=key_rows(b,[('Enter','Choose mission, day/night or skill; submit names or identification; advance credits and briefings.'),('Space','Advance past a mission-title screen.'),('Left / Right','Adjust ammunition in the Motor Pool.')],32,y,365,108)-22
    for title,text in [('Movement','Arrow keys and keypad control the hull or turret selected by C. Hull forward and reverse move the tank; turret mode raises and lowers the sight.'),('Scan and zoom','Gunner Z changes magnification. Commander Z changes map scale. Commander scan is relative to turret bearing.'),('References and saves','Pause with Esc if you want the simulation to wait while reading. Help sends no extra game command. Release held keys after returning. Save states restore the machine and campaign disk; back up your profile before upgrading.')]:
        y=b.heading(title,32,y,21);y=b.para(ESC(text),32,y,365,10)-10
    credits_pdf(b,439,b.h-126,365)
    b.finish()


def credits_pdf(b,x,y,width):
    credits=json.loads((REF/'credits.json').read_text())
    y=b.heading('Original game by Dynamix',x,y,22)
    y=b.para('Published by Electronic Arts',x,y,width,11)
    for row in credits['rows']:
        y=b.para('<b>'+ESC(row['role'])+':</b> '+ESC(', '.join(row['names'])),x,y,width,10)
    y=b.para(ESC(credits['copyright']),x,y,width,9)
    b.para('Fan Remastered by Nell Watson. Dedicated to David “Ming” Kenny.',x,y-6,width,11)


def pdf_image(b,file,x,y,width,height):
    if file.endswith('.svg'):
        # The authored terrain diagrams use only geometric SVG primitives.
        # Keep them vector in print; no converter or raster enlargement.
        import xml.etree.ElementTree as ET
        root=ET.parse(REF/file).getroot();_,_,iw,ih=map(float,root.attrib['viewBox'].split())
        scale=min(width/iw,height/ih)
        b.c.saveState();b.c.translate(x+(width-iw*scale)/2,y-ih*scale);b.c.scale(scale,scale)
        excluded=set(root.findall(".//{http://www.w3.org/2000/svg}defs//*"))
        for node in root.iter():
            if node in excluded:continue
            tag=node.tag.split('}')[-1];a=node.attrib
            if tag=='rect' and 'clipPath' not in str(node.tag):
                b.c.setFillColor(HexColor(a.get('fill','#ffffff')) if a.get('fill')!='none' else HexColor('#ffffff'))
                b.c.setStrokeColor(HexColor(a.get('stroke','#ffffff')));b.c.setLineWidth(float(a.get('stroke-width',0)))
                b.c.rect(float(a['x']) if 'x' in a else 0,ih-float(a.get('y',0))-float(a['height']),float(a['width']),float(a['height']),fill=0 if a.get('fill')=='none' else 1,stroke=1 if 'stroke' in a else 0)
            elif tag=='polygon':
                pts=[tuple(map(float,p.split(','))) for p in a['points'].split()]
                p=b.c.beginPath();p.moveTo(pts[0][0],ih-pts[0][1])
                for px,py in pts[1:]:p.lineTo(px,ih-py)
                # Same-colour edge coverage prevents hairline seams between
                # adjacent terrain triangles in antialiased PDF viewers.
                p.close();colour=HexColor(a.get('fill','#253c41'))
                b.c.setFillColor(colour);b.c.setStrokeColor(colour)
                b.c.setLineWidth(0.35);b.c.drawPath(p,stroke=1,fill=1)
            elif tag=='text':
                b.c.setFillColor(HexColor('#253c41'));b.c.setFont('Helvetica-Bold' if a.get('font-weight')=='bold' else 'Helvetica',float(a.get('font-size',17)))
                b.c.drawString(float(a['x']),ih-float(a['y']),node.text or '')
            elif tag=='line':
                b.c.setStrokeColor(HexColor(a.get('stroke','#253c41')));b.c.setLineWidth(float(a.get('stroke-width',2)))
                b.c.line(float(a['x1']),ih-float(a['y1']),float(a['x2']),ih-float(a['y2']))
        b.c.restoreState()
        return y-height
    # Rasters are opaque RGB, capped at 300 dpi of their printed size; ReportLab passes
    # JPEG through as DCTDecode, keeping the guide a few MB instead of tens of MB of Flate RGB.
    from io import BytesIO
    from PIL import Image
    from reportlab.lib.utils import ImageReader
    buffer=BytesIO()
    with Image.open(REF/file) as source:
        iw,ih=source.size;scale=min(width/iw,height/ih);w,h=iw*scale,ih*scale
        image=source.convert('RGB');limit=round(w*300/72)
        if iw>limit*1.05:image=image.resize((limit,round(ih*limit/iw)),Image.LANCZOS)
        image.save(buffer,'JPEG',quality=90,optimize=True,subsampling=0)
    buffer.seek(0)
    b.c.drawImage(ImageReader(buffer),x+(width-w)/2,y-h,w,h)
    return y-height


def field_pdf(data,catalog,shapes):
    b=Book(PDF/'field-guide.pdf','Scenarios & vehicles',doc_title='M1 Abrams Battle Tank Fan Remaster – Field Guide: Scenarios & Vehicles');b.page('Scenarios & vehicles')
    y=b.h-135
    y=b.heading('Eight missions. Know your crew and your targets.',32,y,23)
    y=b.para('A remastered companion to the original DOS manual: scenario objectives, vehicle recognition, ammunition and anti-tank threats. The original simulation remains the authority during play.',32,y-12,b.w-64,12)
    for title,desc in [('Scenario briefs','All eight missions, with their stated objectives and relevant hazards.'),('Vehicle recognition','All sixteen manual entries. M113, M1A1, M2 Bradley and M60A3 are friendly units.'),('Weapons and objectives','ATGW teams, tank ammunition and the convoy, bases and rescue objectives.'),('Source','Content is paraphrased from the supplied DOS manual. Page references use its printed numbering; add four for the PDF page number. Specifications and threat levels reflect the manual, and its threat ratings.')]:
        y=b.heading(title,32,y-25)
        y=b.para(ESC(desc),32,y,b.w-64,11)
    y=b.para('Dedicated to David “Ming” Kenny.',32,y-25,b.w-64,12)
    b.page('Original creators')
    credits_pdf(b,32,b.h-138,b.w-64)
    for row in data['missions']:
        map_row=visual(row['name'],'manual_maps')
        b.page(row['name'],landscape(A4))
        b.c.setFont('Helvetica',9);b.c.setFillColor(HexColor(CREAM))
        b.c.drawRightString(b.w-32,b.h-64,refs(row))
        gap=24;column=(b.w-64-gap)/2
        top=b.h-117;image_top=top-23;image_height=300
        b.heading('NATO-style manual map',32,top,21)
        b.heading('Extracted PC game-data map',32+column+gap,top,21)
        pdf_image(b,map_row['file'],32,image_top,column,image_height)
        terrain=visual(row['name'],'maps')
        pdf_image(b,terrain['file'],32+column+gap,image_top,column,image_height)
        y=image_top-image_height-10
        left=b.para('Manual scenario geography and tactical symbols.',32,y,column,9,'#4c5a5e')
        right=b.para('Original PC terrain geometry. Moving units and objectives are omitted.',32+column+gap,y,column,9,'#4c5a5e')
        divider=min(left,right)-5
        b.c.setStrokeColor(HexColor('#bbc0ba'));b.c.line(32,divider,b.w-32,divider)
        y=divider-8
        b.para(ESC(row['description']),32,y,column,11)
        objectives='<b>Objective:</b> '+ESC(row['primary_objective'])
        for key in ['secondary_objective','restriction']:
            if row.get(key):objectives+='<br/>'+ESC(row[key])
        if row.get('hazards'):objectives+='<br/><b>Watch for:</b> '+ESC(' '.join(row['hazards']))
        b.para(objectives,32+column+gap,y,column,11)
    for row in data['vehicles']:
        b.page(row['name'])
        y=b.h-123
        y=b.para(ESC(row['allegiance']+' · '+row['role']),32,y,b.w-64,11)
        drawing=visual(row['name'],'wireframes')
        if drawing.get('file'):y=pdf_image(b,drawing['file'],32,y-4,b.w-64,126)
        if drawing.get('file'):y=b.para(ESC(drawing['caption']),32,y-7,b.w-64,9,'#4c5a5e')
        # The model study is vector geometry, retaining every current mesh facet.
        model=catalog['models'][shapes[MODEL_NAMES.get(row['name'],row['name'])]]
        polys=model_polygons(model,b.w-64,135)
        for pts,color in polys:
            if len(pts)==2:
                b.c.setStrokeColor(Color(*(c/255 for c in color)));b.c.setLineWidth(.7)
                b.c.line(32+pts[0][0],y-135+pts[0][1],32+pts[1][0],y-135+pts[1][1]);continue
            b.c.setFillColor(Color(*(c/255 for c in color)));p=b.c.beginPath();p.moveTo(32+pts[0][0],y-135+pts[0][1])
            for px,py in pts[1:]:p.lineTo(32+px,y-135+py)
            p.close();b.c.drawPath(p,stroke=0,fill=1)
        y=b.para('Modern model study',32,y-144,b.w-64,9,'#4c5a5e')
        y=b.para(ESC(row['description']),32,y-10,b.w-64,11)-12
        left=[];right=[]
        for i,(k,v) in enumerate(row['specs'].items()):
            text='<b>'+SPEC_LABELS[k]+':</b> '+ESC(str(v) if v is not None else 'Not stated')
            (left if i<6 else right).append(text)
        l=b.para('<br/>'.join(left),32,y,236,10)
        r=b.para('<br/>'.join(right),290,y,273,10)
        b.para(refs(row),32,min(l,r)-8,b.w-64,9,'#4c5a5e')
    for key,title in [('anti_tank_guided_weapons','Anti-tank guided weapons'),('ammunition_and_armament','Ammunition & armament')]:
        b.page(title);y=b.h-127
        for row in data[key]:
            y=b.heading(row['name'],32,y,20)
            y=b.para(ESC(row['description']),32,y,b.w-64,10)
            if row.get('range_m') is not None:y=b.para('Range: '+ESC(str(row['range_m']))+' m',32,y,b.w-64,9)
            y=b.para(refs(row),32,y,b.w-64,8,'#4c5a5e')-9
    for start in range(0,len(data['other_units_and_objectives']),5):
        b.page('Other units & objectives');y=b.h-127
        for row in data['other_units_and_objectives'][start:start+5]:
            y=b.heading(row['name'],32,y,20);y=b.para(ESC(row['description']),32,y,b.w-64,11)
            y=b.para(refs(row),32,y,b.w-64,9,'#4c5a5e')-14
    b.page('Campaign & crew');y=b.h-127
    y=b.para(ESC(data['campaign']['description']),32,y,b.w-64,11)-18
    for row in data['stations']:
        y=b.heading(row['name']+(' · '+row['key'] if row['key'] else ''),32,y,20)
        y=b.para(ESC(row['description']),32,y,b.w-64,11)
        y=b.para(refs(row),32,y,b.w-64,9,'#4c5a5e')-12
    b.finish()


def native_maps():
    """Render authored SVG diagrams with their labels for Godot's SVG decoder.

    The canonical SVG stays vector in HTML and PDF. Godot omits SVG text, so
    the native reader receives a 2400-pixel rendering of the same diagram.
    """
    import shutil, subprocess
    poppler=shutil.which('pdftoppm')
    if not poppler:raise RuntimeError('Map authoring requires pdftoppm')
    visuals=json.loads((REF/'visuals.json').read_text())
    provenance=json.loads((REF/'maps-provenance.json').read_text())
    destination=PDF/'native-maps';destination.mkdir(parents=True,exist_ok=True)
    for row in visuals['maps']:
        name=Path(row['file']).stem
        book=Book(destination/(name+'.pdf'),row['name'],(1130,868))
        pdf_image(book,row['file'],0,868,1130,868);book.finish()
        prefix=REF/name
        subprocess.run([poppler,'-singlefile','-scale-to','2400','-png',str(destination/(name+'.pdf')),str(prefix)],check=True)
        row['native_file']=name+'.png'
        source=next(r for r in provenance['maps'] if r['name']==row['name'])
        source['native_file']=row['native_file']
        source['native_png_sha256']=hashlib.sha256((REF/row['native_file']).read_bytes()).hexdigest()
        source['native_render']='2400-pixel ReportLab/Poppler rendering of the same authored SVG, including its labels'
    (REF/'visuals.json').write_text(json.dumps(visuals,indent=2)+'\n')
    (REF/'maps-provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--render-maps',action='store_true',help='Regenerate native map PNGs when the terrain SVGs change (requires Poppler).')
    parser.add_argument('--field-guide-only',action='store_true',help='Update the field-guide HTML/PDF and keyboard HTML, keeping the keyboard PDF and existing model studies; requires an unchanged Modern catalogue.')
    args=parser.parse_args()
    REF.mkdir(parents=True,exist_ok=True);PDF.mkdir(parents=True,exist_ok=True)
    data=json.loads((REF/'manual-content.json').read_text())
    assert len(data['missions'])==8 and len(data['vehicles'])==16
    assert next(v for v in data['vehicles'] if v['name']=='M113')['allegiance']=='FRIENDLY'
    pdfmetrics.registerFont(TTFont('Barlow',str(ROOT/'godot/assets/fonts/BarlowCondensed-SemiBold.ttf')))
    # Preflight before any reference file is rewritten, so a failure never leaves a half-updated set.
    if args.render_maps:native_maps()
    else:
        for row in json.loads((REF/'visuals.json').read_text())['maps']:
            if not (REF/row.get('native_file','')).is_file():
                raise RuntimeError('Native terrain map PNG missing; run with --render-maps')
    if args.field_guide_only:
        # PDF studies must match the kept SVG studies, which were built from the catalogue recorded here.
        raw=(ROOT/'local-art/pc-modern/catalog.json').read_bytes()
        built=json.loads((REF/'illustrations.json').read_text()).get('catalog_sha256') if (REF/'illustrations.json').is_file() else None
        if built!=hashlib.sha256(raw).hexdigest():raise SystemExit('Modern catalogue changed since the model studies were built; rerun without --field-guide-only')
        catalog=json.loads(raw);shapes=model_shapes(catalog)
    else:
        catalog,shapes=illustrations(data)
        keyboard_pdf(data)
    (REF/'keyboard-controls.html').write_text(controls_html(data),encoding='utf-8')
    (REF/'field-guide.html').write_text(catalogue_html(data),encoding='utf-8')
    field_pdf(data,catalog,shapes)
    import shutil
    outputs=['field-guide.pdf'] if args.field_guide_only else ['keyboard-controls.pdf','field-guide.pdf']
    for name in outputs:shutil.copyfile(PDF/name,REF/name)
    print('Updated field guide; 8 scenarios, 16 vehicles.' if args.field_guide_only else 'Created two offline HTML references and two printable PDFs; 8 scenarios, 16 vehicles.')

if __name__=='__main__':main()
