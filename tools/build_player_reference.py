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
BG='#111a21'; INK='#17242b'; CREAM='#f4ead4'; MUTED='#bec7c8'; RED='#b84638'; GOLD='#e4b879'
SHORTCUTS=[
 ('Quick save, slot 1','Cmd+S','Ctrl+Alt+S'),
 ('Quick load, slot 1','Cmd+L','Ctrl+Alt+L'),
 ('Undo last load','Cmd+Shift+L','Ctrl+Alt+Shift+L'),
 ('Cycle graphics','Cmd+G','Ctrl+Alt+G'),
]
MODEL_NAMES={'M1A1 Abrams':'M1-A1','M60A3':'M60a3','M2 Bradley':'M2','Mi-24 Hind':'HIND','FST-1':'F-ST','BTR':'BTR-70'}
SPEC_LABELS={'introduced_year':'Introduced','combat_weight_tons':'Weight (t)','length_m':'Length (m)','width_m':'Width (m)','height_m':'Height (m)','maximum_speed_kmh':'Maximum speed (km/h)','primary_armament':'Primary weapon','secondary_armament':'Secondary weapon','reload_seconds':'Reload (s)','range_m':'Range (m)','armor':'Armour','overall_threat':'Threat'}


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
main{max-width:1050px;margin:auto;padding:40px 32px 64px}h1,h2{font-family:Barlow,system-ui,sans-serif;line-height:1.15;letter-spacing:0}h1{font-size:46px;margin:0 0 14px}h2{font-size:30px;margin:44px 0 18px}h3{font-size:21px;line-height:1.3;margin:0 0 8px;font-weight:650}p{max-width:72ch;margin:9px 0 16px}.lead{font-size:18px;color:var(--muted)}nav{display:flex;flex-wrap:wrap;gap:20px;padding:18px 0;margin:22px 0 28px;border-block:1px solid var(--line)}a{color:var(--gold);text-underline-offset:4px}a:focus-visible,summary:focus-visible,input:focus-visible{outline:2px solid var(--gold);outline-offset:5px}input{font:inherit;background:#19262e;color:var(--cream);border:1px solid #61727b;border-radius:8px;padding:10px 14px;width:100%;max-width:540px}label{display:block;margin:18px 0 8px}article{scroll-margin-top:24px;padding:24px 0;border-bottom:1px solid var(--line);break-inside:avoid}article header{display:flex;gap:14px;align-items:baseline;justify-content:space-between;flex-wrap:wrap}.badge{color:var(--gold);font-size:13px}.friendly{color:#b5d8c5}.objective{font-weight:650;color:var(--cream)}.source{font-size:13px;color:var(--muted)}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:0 38px}figure{margin:18px 0;background:#e9e3d5;border-radius:12px;padding:10px}figure img{width:100%;height:auto;display:block}figcaption{font-size:12px;color:#39484c;text-align:center}dl{display:grid;grid-template-columns:minmax(120px,1fr) 1.65fr;gap:6px 16px;font-size:14px;margin:16px 0}dt{color:var(--muted)}dd{margin:0}table{border-collapse:collapse;width:100%;font-size:14px;margin:14px 0 24px}th{text-align:left;font-weight:650;color:var(--gold)}th,td{padding:10px 12px;border-bottom:1px solid var(--line);vertical-align:top}th:first-child,td:first-child{padding-left:0}kbd{font-family:inherit;font-weight:650;color:var(--cream);white-space:nowrap}.key{width:150px}footer{margin-top:42px;padding-top:20px;border-top:1px solid var(--line);font-size:13px;color:var(--muted)}details{margin:12px 0}summary{cursor:pointer;color:var(--gold)}[hidden]{display:none!important}::selection{background:#724635;color:#fff}html{scrollbar-color:#70858d #111a21}
@media(max-width:700px){main{padding:28px 20px}h1{font-size:36px}.grid{grid-template-columns:1fr}.key{width:100px}table{font-size:13px}th,td{padding:9px 6px}}
@media(prefers-reduced-transparency:no-preference){nav{background:#152129d9;backdrop-filter:blur(12px);border-radius:10px;padding:18px}}
@media print{body{background:white;color:#17242b}main{padding:0;max-width:none}h1{font-size:30px}h2{font-size:24px}nav,.search,.print-link{display:none}a,.badge,.source,dt,.lead,footer,th,kbd,.objective{color:#33484e}article{border-color:#b9c1c4}table{font-size:11px}th,td{padding:6px}figure{background:#eee}.grid{gap:24px}details{display:block}}
'''


def html_page(title,body,other):
    # All links/assets are local. The only script is local catalogue filtering.
    font='';fp=ROOT/'godot/assets/fonts/BarlowCondensed-SemiBold.ttf'
    import base64
    if fp.is_file():font='@font-face{font-family:Barlow;src:url(data:font/ttf;base64,'+base64.b64encode(fp.read_bytes()).decode()+') format("truetype");font-weight:600;font-display:swap}'
    return f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; font-src data:; img-src 'self' data:; script-src 'unsafe-inline'"><title>{ESC(title)} | Abrams Fan Remaster</title><style>{font}{CSS}</style></head><body><main><h1>{ESC(title)}</h1><p class="lead">M1 Abrams Battle Tank Fan Remaster</p><nav aria-label="Reference navigation">{other}<a href="#content">Read reference</a></nav>{body}<footer>Original game by Dynamix. Remastered by Nell Watson. Dedicated to David “Ming” Kenny.<br>Manual references use the original printed page numbers. Vehicle figures and threat ratings reproduce the manual's game-era data.</footer></main></body></html>'''


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
    body='<p class="print-link"><a href="keyboard-controls.pdf">Printable keyboard sheet (PDF)</a></p><div id="content"><h2>Remaster shortcuts</h2><table><tr><th>Action</th><th>macOS</th><th>Windows / Linux</th></tr>'+chords+'</table><p>Session provides five save slots, Undo last load and Normal, 2x, 4x or 8x fast forward. Graphics switches EGA, Genesis, Upscaled and Modern. Audio is muted during fast forward.</p><p>Pause with Esc before opening a reference if you want the original simulation to wait. Help never sends an extra command to the game. Release held keys after returning from a menu or another window.</p>'+''.join(sections)+'<p class="source">Original controls: manual pp. 4 to 7, with station and menu context on pp. 9 to 20. Remaster shortcuts are taken from the implemented Play controls.</p></div>'
    return html_page('Keyboard controls',body,'<a href="field-guide.html">Scenarios & vehicles</a>')


def catalogue_html(data):
    missions=''.join(f'<article data-search><header><h3>{ESC(row["name"])}</h3><span class="source">{refs(row)}</span></header><p>{ESC(row["description"])}</p><p class="objective">Objective: {ESC(row["primary_objective"])}</p>'+(''.join(f'<p>{ESC(row[k])}</p>' for k in ['secondary_objective','restriction'] if k in row))+('<p>Watch for: '+ESC(' '.join(row['hazards']))+'</p>' if row.get('hazards') else '')+'</article>' for row in data['missions'])
    vehicles=[]
    for row in data['vehicles']:
        specs=''.join(f'<dt>{SPEC_LABELS[k]}</dt><dd>{ESC(str(v)) if v is not None else "Unknown / not stated"}</dd>' for k,v in row['specs'].items())
        image='vehicle-'+row['name'].lower().replace(' ','-')+'.svg'
        vehicles.append(f'<article data-search><header><h3>{ESC(row["name"])}</h3><span class="badge '+('friendly' if row['allegiance']=='FRIENDLY' else '')+'">'+row['allegiance']+'</span></header><p class="source">'+ESC(row['role'])+' · '+refs(row)+f'</p><figure><img src="{image}" alt="{ESC(row["name"])} Modern model study" width="640" height="245" loading="lazy"><figcaption>Modern model study</figcaption></figure><p>'+ESC(row['description'])+'</p>'+('<p>The FST-1 model is the remaster’s interpretation; the manual supplies no illustration.</p>' if row['name']=='FST-1' else '')+'<details><summary>Manual specifications</summary><dl>'+specs+'</dl></details></article>')
    extra=[]
    for key,title in [('anti_tank_guided_weapons','Anti-tank guided weapons'),('ammunition_and_armament','Ammunition & armament'),('other_units_and_objectives','Other units & objectives')]:
        entries=''.join('<article data-search><header><h3>'+ESC(row['name'])+'</h3><span class="source">'+refs(row)+'</span></header><p>'+ESC(row['description'])+'</p>'+('<p>Range: '+ESC(str(row['range_m']))+' m</p>' if row.get('range_m') is not None else '')+'</article>' for row in data[key])
        extra.append('<section><h2>'+ESC(title)+'</h2>'+entries+'</section>')
    body='<p class="print-link"><a href="field-guide.pdf">Printable scenario and vehicle catalogue (PDF)</a></p><div class="search"><label for="search">Find a scenario, vehicle or weapon</label><input id="search" type="search" placeholder="For example: Convoy, M113, sabot" autocomplete="off"><p id="count" role="status" aria-live="polite"></p></div><div id="content"><section id="scenarios"><h2>The eight scenarios</h2><p>'+ESC(data['training']['description'])+'</p><p>The manual gives these briefings as preparation. Its maps are rough guidelines. Choose your ammunition mix and governor in the Motor Pool; no compulsory mission loadout is specified.</p>'+missions+'</section><section id="vehicles"><h2>Vehicle recognition</h2><p>Friendly and enemy identification follows the manual. Specifications below are its game-era reference values, rather than a current military specification sheet. FST-1 features are explicitly tentative in that source.</p><div class="grid">'+''.join(vehicles)+'</div></section>'+''.join(extra)+'<section><h2>Campaign and stations</h2><p>'+ESC(data['campaign']['description'])+'</p>'+''.join('<article><h3>'+ESC(row['name'])+(' · '+row['key'] if row['key'] else '')+'</h3><p>'+ESC(row['description'])+'</p><p class="source">'+refs(row)+'</p></article>' for row in data['stations'])+'</section></div><script>const q=document.getElementById("search"),rows=[...document.querySelectorAll("[data-search]")],count=document.getElementById("count");q.addEventListener("input",()=>{let shown=0;for(const row of rows){row.hidden=!row.textContent.toLowerCase().includes(q.value.toLowerCase().trim());if(!row.hidden)shown++}count.textContent=q.value ? shown+" matching entries" : ""});</script>'
    return html_page('Scenarios & vehicles',body,'<a href="keyboard-controls.html">Keyboard controls</a><a href="#scenarios">Scenarios</a><a href="#vehicles">Vehicles</a>')


class Book:
    def __init__(self,path,title,page_size=A4):
        self.c=canvas.Canvas(str(path),pagesize=page_size,pageCompression=1)
        self.c.setTitle(title);self.c.setAuthor('Nell Watson / Abrams Fan Remaster')
        self.w,self.h=page_size;self.number=0;self.title=title
        self.style=ParagraphStyle('body',fontName='Helvetica',fontSize=10,leading=14,textColor=HexColor(INK))
    def page(self,heading):
        if self.number:self.c.showPage()
        self.number+=1; c=self.c
        c.setFillColor(HexColor('#f7f2e7'));c.rect(0,0,self.w,self.h,fill=1,stroke=0)
        c.setFillColor(HexColor(INK));c.rect(0,self.h-92,self.w,92,fill=1,stroke=0)
        c.setFillColor(HexColor(CREAM));c.setFont('Helvetica',10);c.drawString(32,self.h-30,'M1 ABRAMS BATTLE TANK FAN REMASTER')
        c.setFont('Barlow',27);c.drawString(32,self.h-64,heading)
        c.setStrokeColor(HexColor('#bbc0ba'));c.line(32,40,self.w-32,40)
        c.setFont('Helvetica',8);c.setFillColor(HexColor('#4c5a5e'));c.drawString(32,25,'Original game by Dynamix · Remastered by Nell Watson')
        c.drawRightString(self.w-32,25,str(self.number))
    def para(self,text,x,y,width,size=10,color=INK):
        style=ParagraphStyle('p',parent=self.style,fontSize=size,leading=size*1.4,textColor=HexColor(color))
        p=Paragraph(text,style);_,h=p.wrap(width,self.h)
        assert y-h>=47,('Page overflow',self.number,text[:55],y,h)
        p.drawOn(self.c,x,y-h);return y-h-8
    def heading(self,text,x,y,size=18):
        self.c.setFont('Barlow',size);self.c.setFillColor(HexColor(INK));self.c.drawString(x,y,text);return y-16
    def finish(self):self.c.save()


def keyboard_pdf(data):
    b=Book(PDF/'keyboard-controls.pdf','Keyboard controls',landscape(A4));b.page('Keyboard controls')
    columns=[(32,244),(302,244),(572,236)];top=b.h-122
    groups=[
      [('Stations','F1  Gunner\nF2  Commander\nF3  Cupola\nF4  Driver'),('Hull and turret','C  Switch hull / turret control\nA  Align turret to hull\nUp / KP8  Forward / raise sight\nDown / KP2  Reverse / lower sight\nLeft / KP4  Turn left\nRight / KP6  Turn right\nKP5  Stop hull / turret'),('Session','Esc  Pause / back; any key resumes\nQ  Quit mission / campaign\nF5  Sound on / off\nShift+3  Original system speed')],
      [('Gunner','Enter  Cycle targets\nL  Lock selected target\nSpace  Fire selected weapon\nM  Fire machine gun\n1  HEAT    2  Sabot    3  AX\nS  Smoke\nT  Thermal imaging\nR  Retrieve waiting radio message\nZ  Normal, 3x, 10x sight'),('Commander','D  Damage screen; any key returns\nT  Thermal    R  Radio\nZ  Map close-up / overview\nF7  Current turret bearing\nF8  Scan +90 degrees\nF9  Scan +180 degrees\nF10  Scan +270 degrees')],
      [('Remaster shortcuts','macOS: Cmd + key\nWindows / Linux: Ctrl+Alt + key\n\nS  Quick save to slot 1\nL  Quick load from slot 1\nShift+L  Undo last load\nG  Cycle graphics'),('Remaster menus','Session: save / load slots 1 to 5\nFast forward: Normal, 2x, 4x, 8x\nGraphics: EGA / Genesis /\nUpscaled / Modern\nHelp: keyboard / field guide'),('Keep control','Pause before opening references.\nAfter leaving a menu or another\nwindow, release all keys once.\nFast forward mutes presentation audio.')]
    ]
    for (x,width),group in zip(columns,groups):
        y=top
        for title,text in group:
            y=b.heading(title,x,y-12 if y!=top else y,19)
            y=b.para(ESC(text).replace('\n','<br/>'),x,y,width,10)-10
    b.c.setFont('Helvetica',8);b.c.setFillColor(HexColor('#4c5a5e'));b.c.drawString(32,53,'Original commands: manual pp. 4 to 7. Station-specific meanings are preserved. Genesis mode needs the optional original ROM.')
    b.page('Menus, stations & practical reference')
    y=b.h-122; x=32; width=b.w-64
    y=b.heading('Context matters',x,y)
    for text in ['The arrow keys and keypad control whichever part is selected by C. In hull mode, forward and reverse move the tank; in turret mode, they raise and lower the sight.', 'Gunner Z changes magnification. Commander Z changes map scale. Commander scan is relative to turret bearing and does not rotate the hull or turret.', 'Enter advances timed intro and briefing screens, changes highlighted mission/day/night/skill choices, and submits names or vehicle identification. In the gunner station it cycles targets. Space advances a mission-title screen and fires in the gunner station.', 'Left and right adjust the selected Motor Pool ammunition quantity. The loader works automatically and has no station screen.']:
        y=b.para(ESC(text),x,y,width)
    y=b.heading('Quick save and load',x,y-26)
    y=b.para('Save states include the original machine and writable campaign disk. Loading rewinds both. Quick save uses slot 1; Session exposes all five slots. Undo last load restores the automatic recovery state. Existing states may be incompatible after a native-core update.',x,y,width)
    y=b.heading('Platform shortcuts',x,y-26)
    for action,mac,other in SHORTCUTS:y=b.para(f'<b>{ESC(action)}</b>: macOS {mac}; Windows / Linux {other}.',x,y,width)
    b.finish()


def field_pdf(data,catalog,shapes):
    b=Book(PDF/'field-guide.pdf','Scenarios & vehicles');b.page('Scenarios & vehicles')
    y=b.h-135
    y=b.heading('Eight missions. Know your crew and your targets.',32,y,23)
    y=b.para('A remastered companion to the original DOS manual: scenario objectives, vehicle recognition, ammunition and anti-tank threats. The original simulation remains the authority during play.',32,y-12,b.w-64,12)
    for title,desc in [('Scenario briefs','All eight missions, with their stated objectives and relevant hazards.'),('Vehicle recognition','All sixteen manual entries. M113, M1A1, M2 Bradley and M60A3 are friendly units.'),('Weapons and objectives','ATGW teams, tank ammunition and the convoy, bases and rescue objectives.'),('Source','Content is paraphrased from the supplied DOS manual. Page references use its printed numbering; add four for the PDF page number. Specifications and threat levels reflect the manual, including unknown FST-1 values.')]:
        y=b.heading(title,32,y-25)
        y=b.para(ESC(desc),32,y,b.w-64,11)
    y=b.para('Dedicated to David “Ming” Kenny.',32,y-25,b.w-64,12)
    for start in range(0,8,2):
        b.page('The eight scenarios')
        for offset,row in enumerate(data['missions'][start:start+2]):
            y=b.h-132-offset*325
            y=b.heading(row['name'],32,y,23)
            y=b.para(ESC(row['description']),32,y-4,b.w-64,11)
            y=b.para('<b>Objective:</b> '+ESC(row['primary_objective']),32,y-8,b.w-64,11)
            for key in ['secondary_objective','restriction']:
                if row.get(key):y=b.para(ESC(row[key]),32,y,b.w-64,11)
            if row.get('hazards'):y=b.para('<b>Watch for:</b> '+ESC(' '.join(row['hazards'])),32,y,b.w-64,10)
            b.para(refs(row),32,y-8,b.w-64,9,'#4c5a5e')
    for start in range(0,16,2):
        b.page('Vehicle recognition')
        for offset,row in enumerate(data['vehicles'][start:start+2]):
            y=b.h-129-offset*328; x=32
            y=b.heading(row['name'],x,y,24)
            y=b.para(ESC(row['allegiance']+' · '+row['role']),x,y,b.w-64,9,'#526264')
            polys=model_polygons(catalog['models'][shapes[MODEL_NAMES.get(row['name'],row['name'])]],210,90)
            for pts,color in polys:
                if len(pts)==2:
                    b.c.setStrokeColor(Color(*(c/255 for c in color)));b.c.setLineWidth(.7)
                    b.c.line(x+pts[0][0],y-94+pts[0][1],x+pts[1][0],y-94+pts[1][1]);continue
                b.c.setFillColor(Color(*(c/255 for c in color)));p=b.c.beginPath();p.moveTo(x+pts[0][0],y-94+pts[0][1])
                for px,py in pts[1:]:p.lineTo(x+px,y-94+py)
                p.close();b.c.drawPath(p,stroke=0,fill=1)
            b.para(ESC(row['description']),x+224,y,b.w-288,10)
            y-=112
            left=[];right=[]
            for i,(k,v) in enumerate(row['specs'].items()):
                text='<b>'+SPEC_LABELS[k]+':</b> '+ESC(str(v) if v is not None else 'Unknown / not stated')
                (left if i<6 else right).append(text)
            b.para('<br/>'.join(left),x,y,236,9)
            bottom=b.para('<br/>'.join(right),x+258,y,273,9)
            b.para(refs(row),x,bottom-3,236,8,'#4c5a5e')
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


def main():
    REF.mkdir(parents=True,exist_ok=True);PDF.mkdir(parents=True,exist_ok=True)
    data=json.loads((REF/'manual-content.json').read_text())
    assert len(data['missions'])==8 and len(data['vehicles'])==16
    assert next(v for v in data['vehicles'] if v['name']=='M113')['allegiance']=='FRIENDLY'
    pdfmetrics.registerFont(TTFont('Barlow',str(ROOT/'godot/assets/fonts/BarlowCondensed-SemiBold.ttf')))
    catalog,shapes=illustrations(data)
    (REF/'keyboard-controls.html').write_text(controls_html(data),encoding='utf-8')
    (REF/'field-guide.html').write_text(catalogue_html(data),encoding='utf-8')
    keyboard_pdf(data);field_pdf(data,catalog,shapes)
    import shutil
    for name in ['keyboard-controls.pdf','field-guide.pdf']:shutil.copyfile(PDF/name,REF/name)
    print('Created two offline HTML references and two printable PDFs; 8 scenarios, 16 vehicles.')

if __name__=='__main__':main()
