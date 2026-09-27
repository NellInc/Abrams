#!/usr/bin/env python3
"""Reconstruct local scalable outline faces from the four original PC fonts.

Fixed cells and original character identity are retained. Authored centre lines
regularize alphanumeric stroke weights, bevels, bowls and stencil gaps. Source
serifs and symbols retain their traced contours. These are optical reconstructions
of the supplied bitmap designs, not recovered original vector masters.
"""
import argparse
import hashlib
import json
from pathlib import Path
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from tools.pc_fonts import decode_font
from tools.pc_font_optical import shape

ROOT=Path(__file__).resolve().parents[1]
PINS={
 '6X6.FNT':'a1ab3119ad84f1debb4fda3a57271e08ed9f0bdf1e535a5885a92758e07d5840',
 '8X6.FNT':'aa295b11f913a8829baf0590fc9405a602deae2a50a00ee592ffaac2f1099567',
 '8X8.FNT':'857af65a215ccfcf92508ad43848c63e08bcef7ed2da2f3bcd75b670cd515812',
 'STENCIL.FNT':'3f92e8c7488278d86aeaa978d87d980d6a688fc9c8dbf87befaf4e6bbc9f4181'}
UNITS=1536

def contours(bits,w,h):
 def ink(x,y):return 0<=x<w and 0<=y<h and bits[y*w+x]
 edges=set()
 for y in range(h):
  for x in range(w):
   if not ink(x,y):continue
   for flag,a,b in [(not ink(x,y-1),(x,y),(x+1,y)),(not ink(x+1,y),(x+1,y),(x+1,y+1)),(not ink(x,y+1),(x+1,y+1),(x,y+1)),(not ink(x-1,y),(x,y+1),(x,y))]:
    if flag:edges.add((a,b))
 result=[]
 while edges:
  a,b=min(edges);edges.remove((a,b));points=[a,b]
  while b!=points[0]:
   choices=[q for p,q in edges if p==b]
   dx,dy=b[0]-a[0],b[1]-a[1]
   # Join diagonally touching ink through the shared corner, preserving counters.
   q=min(choices,key=lambda q:dx*(q[1]-b[1])-dy*(q[0]-b[0]));edges.remove((b,q));a,b=b,q;points.append(b)
  points=points[:-1]
  compact=[]
  for i,p in enumerate(points):
   prev=points[i-1];nxt=points[(i+1)%len(points)]
   if (p[0]-prev[0])*(nxt[1]-p[1])!=(p[1]-prev[1])*(nxt[0]-p[0]):compact.append(p)
  result.append(compact)
 return result

def simplify(p, name, code):
 # Replace only unambiguous alternating unit-edge stair runs, preserving long
 # stems, crossbars, serifs and separate stencil islands.
 n=len(p);remove=set()
 if n<=4 or chr(code) in 'IEFHLTiefhlt':return p
 for i in range(n):
  if i in remove:continue
  def delta(j):return (p[(j+1)%n][0]-p[j%n][0],p[(j+1)%n][1]-p[j%n][1])
  a,b=delta(i),delta(i+1)
  if sum(map(abs,a))!=1 or sum(map(abs,b))!=1 or a[0]*b[0]+a[1]*b[1]!=0:continue
  count=2
  while count<n-1 and delta(i+count)==(a if count%2==0 else b):count+=1
  if count>=2:
   points=[p[(i+j)%n] for j in range(count+1)]
   if name in ['8X8','STENCIL'] and chr(code).upper() in 'BDEFGHKLPR' and all(x<=3 for x,y in points) and (all(y<=1 for x,y in points) or all(y>=6 for x,y in points)):continue
   for j in range(1,count):remove.add((i+j)%n)
 return [q for i,q in enumerate(p) if i not in remove]


def point_in_polygon(p,poly):
    x,y=p;inside=False
    for a,b in zip(poly,poly[1:]+poly[:1]):
        cross=(x-a[0])*(b[1]-a[1])-(y-a[1])*(b[0]-a[0])
        if abs(cross)<1e-7 and min(a[0],b[0])<=x<=max(a[0],b[0]) and min(a[1],b[1])<=y<=max(a[1],b[1]): return None
        if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:inside=not inside
    return inside


def glyph_contours(font,code,name):
    bits=font['glyphs'][code-font['first']]
    original=contours(bits,font['width'],font['height'])
    optical=shape(font,code,name)
    if optical is not None:return optical,optical!=original
    result=[simplify(poly,name.removesuffix('.FNT'),code) for poly in original]
    for i,ink in enumerate(bits):
        values=[point_in_polygon((i%font['width']+.5,i//font['width']+.5),poly) for poly in result]
        if None not in values and (sum(values)%2==1)!=bool(ink):
            raise ValueError(f'outline changed an unambiguous source cell: {name} {code}')
    return result, result!=original


def build_face(path,output):
    name=path.name;raw=path.read_bytes()
    if hashlib.sha256(raw).hexdigest()!=PINS[name]:raise ValueError('unsupported original '+name)
    font=decode_font(raw);w,h=font['width'],font['height'];glyphs={};metrics={};entries=[]
    order=['.notdef']+[f'uni{i:04X}' for i in range(32,127)]
    pen=TTGlyphPen(None);glyphs['.notdef']=pen.glyph();metrics['.notdef']=(round(w/h*UNITS),0)
    for code in range(32,127):
        polygons,changed=glyph_contours(font,code,name)
        pen=TTGlyphPen(None)
        for polygon in polygons:
            points=[(x*UNITS/h,(h-y)*UNITS/h) for x,y in polygon]
            pen.moveTo(points[0])
            for p in points[1:]:pen.lineTo(p)
            pen.closePath()
        glyph=pen.glyph();key=f'uni{code:04X}';glyphs[key]=glyph
        if glyph.numberOfContours:glyph.recalcBounds(None)
        metrics[key]=(round(w/h*UNITS),glyph.xMin if glyph.numberOfContours else 0)
        entries.append({'code':code,'contours':polygons,'redrawn':changed,
                        'optically_shaped':shape(font,code,name) is not None})
    fb=FontBuilder(UNITS,isTTF=True);fb.setupGlyphOrder(order)
    fb.setupCharacterMap({i:f'uni{i:04X}' for i in range(32,127)})
    fb.setupGlyf(glyphs);fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=UNITS,descent=0,lineGap=0)
    fb.setupOS2(sTypoAscender=UNITS,sTypoDescender=0,sTypoLineGap=0,usWinAscent=UNITS,usWinDescent=0)
    family='Abrams Remaster '+path.stem
    fb.setupNameTable({'familyName':family,'styleName':'Regular','uniqueFontIdentifier':family+' v2',
                      'fullName':family,'psName':family.replace(' ','-'),
                      'copyright':'Local derivative of supplied original game font. Redistribution rights unestablished.'})
    fb.setupPost(isFixedPitch=1);fb.setupMaxp()
    fb.font['head'].created=fb.font['head'].modified=3862857600
    fb.font.recalcTimestamp=False
    output.mkdir(parents=True,exist_ok=True);filename=path.stem.lower()+'.ttf';fb.save(output/filename)
    return {'source':name,'source_sha256':PINS[name],'file':filename,
            'sha256':hashlib.sha256((output/filename).read_bytes()).hexdigest(),
            'cell':[w,h],'glyphs':entries,'redrawn_glyphs':sum(e['redrawn'] for e in entries),
            'optically_shaped_glyphs':sum(e['optically_shaped'] for e in entries)}


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);args=p.parse_args()
    if any(args.output.resolve().is_relative_to((ROOT/n).resolve()) for n in ['GAME','GENESIS']):p.error('output must be outside source directories')
    args.output.mkdir(parents=True,exist_ok=False)
    faces=[build_face(ROOT/'GAME'/name,args.output) for name in PINS]
    data={'schema':2,'units_per_em':UNITS,'faces':faces,'fill_rule':'nonzero','scope':__doc__}
    path=args.output/'manifest.json';path.write_text(json.dumps(data,indent=2)+'\n')
    print('Four original-style outline faces;',sum(f['redrawn_glyphs'] for f in faces),'contour-redrawn glyphs;',hashlib.sha256(path.read_bytes()).hexdigest())


if __name__=='__main__':main()
