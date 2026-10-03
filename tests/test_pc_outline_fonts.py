import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from fontTools.ttLib import TTFont
from tools.pc_fonts import decode_font
from tools.build_pc_outline_fonts import build_face

ROOT=Path(__file__).resolve().parents[1]
DIRECTORY=ROOT/'local-art/pc-outline-fonts-v5'


def classify(point,contours):
    x,y=point;winding=0
    for polygon in contours:
        for a,b in zip(polygon,polygon[1:]+polygon[:1]):
            area=(x-a[0])*(b[1]-a[1])-(y-a[1])*(b[0]-a[0])
            if abs(area)<1e-8 and min(a[0],b[0])<=x<=max(a[0],b[0]) and min(a[1],b[1])<=y<=max(a[1],b[1]):return None
            if (a[1]>y)!=(b[1]>y) and x<a[0]+(y-a[1])*(b[0]-a[0])/(b[1]-a[1]):winding+=1 if b[1]>a[1] else -1
    return winding!=0


def intervals(contours,y):
    """Independent cross-section of the actual glyph, including overlapping ink."""
    crossings=[]
    for polygon in contours:
        for a,b in zip(polygon,polygon[1:]+polygon[:1]):
            if min(a[1],b[1])<y<max(a[1],b[1]):
                crossings.append(a[0]+(y-a[1])*(b[0]-a[0])/(b[1]-a[1]))
    crossings=sorted(set(crossings));result=[]
    for a,b in zip(crossings,crossings[1:]):
        if classify(((a+b)/2,y),contours):
            if result and abs(result[-1][1]-a)<1e-7:result[-1][1]=b
            else:result.append([a,b])
    return result


class OutlineFontTests(unittest.TestCase):
    def test_source_aliases_retain_identical_outlines(self):
        manifest=json.loads((DIRECTORY/'manifest.json').read_text())
        for face in manifest['faces']:
            glyphs=decode_font((ROOT/'GAME'/face['source']).read_bytes())['glyphs']
            aliases={}
            for item in face['glyphs']:
                bits=tuple(glyphs[item['code']-32])
                if bits in aliases:self.assertEqual(item['contours'],aliases[bits])
                aliases[bits]=item['contours']

    def test_reproducible_faces(self):
        manifest=json.loads((DIRECTORY/'manifest.json').read_text())
        with tempfile.TemporaryDirectory() as tmp:
            for face in manifest['faces']:
                output=Path(tmp)
                regenerated=build_face(ROOT/'GAME'/face['source'],output)
                self.assertEqual(json.loads(json.dumps(regenerated)),face)
                self.assertEqual((output/face['file']).read_bytes(),(DIRECTORY/face['file']).read_bytes())

    def test_true_type_matches_outline_catalog_and_original_cells(self):
        manifest=json.loads((DIRECTORY/'manifest.json').read_text())
        changed=0;cells=0;optical=0
        for face in manifest['faces']:
            source=decode_font((ROOT/'GAME'/face['source']).read_bytes())
            w,h=face['cell'];scale=1536/h
            with TTFont(DIRECTORY/face['file']) as font:
                cmap=font.getBestCmap();self.assertEqual(set(cmap),set(range(32,127)))
                self.assertEqual(font['hhea'].ascent,1536);self.assertEqual(font['hhea'].descent,0)
                for item in face['glyphs']:
                    glyph=font['glyf'][cmap[item['code']]]
                    coords,endpoints,_=glyph.getCoordinates(font['glyf'])
                    polys=[];start=0
                    for end in endpoints:
                        polys.append([[x/scale,h-y/scale] for x,y in coords[start:end+1]])
                        start=end+1
                    # Compare integer design units exactly. A float y flip
                    # otherwise introduces harmless final-bit roundoff.
                    to_units=lambda ps:[[(round(x*scale),round((h-y)*scale)) for x,y in p] for p in ps]
                    self.assertEqual(to_units(polys),to_units(item['contours']))
                    self.assertEqual(font['hmtx'][cmap[item['code']]][0],int(w*scale))
                    bits=source['glyphs'][item['code']-32]
                    self.assertEqual(bool(polys),any(bits))
                    for i,ink in enumerate(bits):
                        classification=classify((i%w+.5,i//w+.5),polys)
                        # Source-bit recognition is unchanged. Authored optical
                        # shapes deliberately relax pixel-centre fidelity, which
                        # previously forced pinched joins and uneven weights.
                        if classification is not None and not item['optically_shaped']:
                            self.assertEqual(classification,bool(ink))
                        cells+=1
                    for polygon in polys:
                        for x,y in polygon:self.assertTrue(0<=x<=w and 0<=y<=h)
                    changed+=int(item['redrawn'])
                    optical+=int(item['optically_shaped'])
        self.assertEqual(changed,290)
        self.assertEqual(optical,223)
        self.assertEqual(cells,21660)

    def test_capitals_figures_and_symbols_keep_approved_geometry(self):
        # Pins are the complete non-lowercase contour inventories from v3.
        expected={
            '6X6.FNT':'709a0cb707f9d1d773081d02abf90692fca3d321a5b076752355192a8b4ff572',
            '8X6.FNT':'85979323cc9c03d32136265b0419b21f583ab914022eb46ea26cdc52334ab1d4',
            '8X8.FNT':'f3a6a586da9235327f20dd0dd5066ae02db8027cf0496f2d26856469a37295fb',
            'STENCIL.FNT':'7f74d7d79baa48c8c3ebb068441cfebdcea3614a85e62e0574d2b4f3cfa7f533'}
        manifest=json.loads((DIRECTORY/'manifest.json').read_text())
        for face in manifest['faces']:
            records=[(g['code'],g['contours']) for g in face['glyphs']
                     if not chr(g['code']).islower()]
            actual=hashlib.sha256(json.dumps(records,separators=(',',':')).encode()).hexdigest()
            self.assertEqual(actual,expected[face['source']])

    def test_all_lowercase_keep_source_extents_and_regular_stems(self):
        manifest=json.loads((DIRECTORY/'manifest.json').read_text())
        for face in manifest['faces']:
            source=decode_font((ROOT/'GAME'/face['source']).read_bytes());w=source['width']
            glyphs={chr(g['code']):g['contours'] for g in face['glyphs']}
            for item in face['glyphs']:
                if not chr(item['code']).islower():continue
                self.assertTrue(item['optically_shaped'])
                ink=[(i%w,i//w) for i,b in enumerate(source['glyphs'][item['code']-32]) if b]
                pts=[p for poly in item['contours'] for p in poly]
                self.assertEqual((min(p[0] for p in pts),min(p[1] for p in pts),
                                  max(p[0] for p in pts),max(p[1] for p in pts)),
                                 (min(p[0] for p in ink),min(p[1] for p in ink),
                                  max(p[0] for p in ink)+1,max(p[1] for p in ink)+1),
                                 (face['source'],chr(item['code'])))
            # Source classifications are mandatory for every lowercase face,
            # including open light e, split stencil shoulders, m/w branches,
            # serif feet and the original unequal s terminals.
            for item in face['glyphs']:
                if not chr(item['code']).islower():continue
                bits=source['glyphs'][item['code']-32]
                for i,ink in enumerate(bits):
                    actual=classify((i%w+.5,i//w+.5),item['contours'])
                    self.assertIsNotNone(actual,(face['source'],chr(item['code']),i))
                    self.assertEqual(actual,bool(ink),(face['source'],chr(item['code']),i))
            # Measure the actual source stems, rather than insisting that the
            # asymmetric stencil face have the dialogue face's two-unit stem.
            for char in 'hn':
                bands=intervals(glyphs[char],4.5 if face['cell'][1]==8 else 3.5)
                self.assertEqual(len(bands),2,(face['source'],char,bands))
                row=4 if face['cell'][1]==8 else 3
                bits=source['glyphs'][ord(char)-32][row*w:(row+1)*w]
                weights=[];length=0
                for ink in bits+[0]:
                    if ink:length+=1
                    elif length:weights.append(length);length=0
                self.assertEqual(len(weights),len(bands),(face['source'],char))
                for (a,b),weight in zip(bands,weights):self.assertAlmostEqual(b-a,weight,delta=.012)

    def test_distinctive_source_letter_topology_is_retained(self):
        manifest=json.loads((DIRECTORY/'manifest.json').read_text())
        probes={
            '8X8.FNT':{'r':[(5.5,4.5,True)],'a':[(4.5,6.5,False),(5.5,6.5,True)],
                       'g':[(4.5,2.5,False),(5.5,7.5,False)],
                       'm':[(3.5,6.5,False),(3.5,4.5,True)],
                       'w':[(.5,6.5,False),(3.5,4.5,True)]},
            '8X6.FNT':{'e':[(3.5,2.5,True),(3.5,3.5,True)],
                       's':[(.5,2.5,False),(5.5,2.5,True),(3.5,3.5,True)]},
            'STENCIL.FNT':{'n':[(2.5,2.5,False)],'a':[(4.5,3.5,False)],
                           'w':[(1.5,2.5,False)],'e':[(3.5,2.5,False)]}}
        for face in manifest['faces']:
            glyphs={chr(g['code']):g['contours'] for g in face['glyphs']}
            for char,points in probes.get(face['source'],{}).items():
                for x,y,ink in points:self.assertEqual(classify((x,y),glyphs[char]),ink,(face['source'],char,x,y))

    def test_lowercase_freetype_pixels_match_the_actual_outline_interior(self):
        from PIL import Image, ImageDraw, ImageFont
        manifest=json.loads((DIRECTORY/'manifest.json').read_text())
        for face in manifest['faces']:
            w,h=face['cell']
            for scale in (3,6):
                font=ImageFont.truetype(str(DIRECTORY/face['file']),h*scale)
                for item in face['glyphs']:
                    if not chr(item['code']).islower():continue
                    glyph=Image.new('L',(w*scale,h*scale))
                    ImageDraw.Draw(glyph).text((0,h*scale),chr(item['code']),font=font,
                                              fill=255,anchor='ls',stroke_width=0)
                    segments=[(a,b) for poly in item['contours']
                              for a,b in zip(poly,poly[1:]+poly[:1])]
                    for py in range(h*scale):
                        for px in range(w*scale):
                            x,y=(px+.5)/scale,(py+.5)/scale
                            distance=1e6
                            for a,b in segments:
                                dx,dy=b[0]-a[0],b[1]-a[1]
                                t=max(0,min(1,((x-a[0])*dx+(y-a[1])*dy)/(dx*dx+dy*dy)))
                                distance=min(distance,((x-a[0]-t*dx)**2+(y-a[1]-t*dy)**2)**.5)
                            if distance*scale<=.8:continue
                            ink=classify((x,y),item['contours'])
                            self.assertIsNotNone(ink)
                            # FreeType's area coverage rounds to 8-bit gray.
                            # Use the same 2/255 allowance as the native oracle.
                            self.assertAlmostEqual(glyph.getpixel((px,py)),255 if ink else 0,
                                                   delta=2,
                                                   msg=(face['source'],chr(item['code']),scale,px,py))

    def test_measured_stem_weights_bars_and_stencil_bridges(self):
        manifest=json.loads((DIRECTORY/'manifest.json').read_text())
        for face in manifest['faces']:
            name=face['source'];glyphs={chr(g['code']):g['contours'] for g in face['glyphs']}
            bold=name in ['8X8.FNT','STENCIL.FNT']
            middle=2.45 if name=='6X6.FNT' else 3.45
            for char in 'DO':
                bands=intervals(glyphs[char],middle)
                self.assertEqual(len(bands),2,(name,char,bands))
                for left,right in bands:self.assertAlmostEqual(right-left,2 if bold else 1,delta=0.012)
                for polygon in glyphs[char]:
                    for a,b in zip(polygon,polygon[1:]+polygon[:1]):
                        dx,dy=abs(b[0]-a[0]),abs(b[1]-a[1])
                        if dx>0.012 and dy>0.012:self.assertAlmostEqual(dx,dy,delta=0.012)
            x=2.6 if name=='STENCIL.FNT' else 2.45 if name=='6X6.FNT' else 3.45
            rotated=[[(y,x) for x,y in p] for p in glyphs['O']]
            bands=intervals(rotated,x)
            self.assertEqual(len(bands),2,(name,bands))
            for top,bottom in bands:self.assertAlmostEqual(bottom-top,1,delta=0.012)
            if name=='STENCIL.FNT':
                for char in 'DO':
                    for y in [0.45,6.55]:
                        self.assertTrue(classify((3.075,y),glyphs[char]))
                        self.assertFalse(classify((3.5,y),glyphs[char]))
                        self.assertTrue(classify((3.925,y),glyphs[char]))
                        bands=intervals(glyphs[char],y)
                        gaps=[b[0]-a[1] for a,b in zip(bands,bands[1:])]
                        self.assertTrue(any(abs(gap-0.75)<0.012 for gap in gaps))

    def test_diagonals_have_real_weight_and_counters_remain_open(self):
        from math import sqrt
        manifest=json.loads((DIRECTORY/'manifest.json').read_text())
        for face in manifest['faces']:
            glyphs={chr(g['code']):g['contours'] for g in face['glyphs']}
            name=face['source'];bold=name in ['8X8.FNT','STENCIL.FNT']
            # D/O counters must survive the regularized bowls.
            for char in 'DO':self.assertFalse(classify((3.8,3.45 if name!='6X6.FNT' else 2.45),glyphs[char]))
            if name=='6X6.FNT':
                normal=(-1/sqrt(2),1/sqrt(2))
                for sign in [-1,1]:
                    self.assertTrue(classify((1.5+sign*normal[0]*0.4,1.5+sign*normal[1]*0.4),glyphs['X']))
                    self.assertFalse(classify((1.5+sign*normal[0]*0.6,1.5+sign*normal[1]*0.6),glyphs['X']))

    def test_cap_heights_and_open_terminals_reach_source_lines(self):
        manifest=json.loads((DIRECTORY/'manifest.json').read_text())
        for face in manifest['faces']:
            source=decode_font((ROOT/'GAME'/face['source']).read_bytes())
            glyphs={chr(g['code']):g['contours'] for g in face['glyphs']}
            for char in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789':
                rows=[i//source['width'] for i,b in enumerate(source['glyphs'][ord(char)-32]) if b]
                ys=[y for p in glyphs[char] for x,y in p]
                self.assertEqual((min(ys),max(ys)),(min(rows),max(rows)+1),(face['source'],char))
            if face['source']=='8X6.FNT':
                # The reported DAMON SLYE defect was local to open terminals,
                # not just each glyph's overall bounding box (N already passed).
                for char,x,y in [('A',0.5,5.99),('M',0.5,5.99),('M',6.5,5.99),
                                 ('N',6.5,1.01),('Y',0.5,1.01),('Y',6.5,1.01),('Y',3.5,5.99)]:
                    self.assertTrue(classify((x,y),glyphs[char]),(char,x,y))

    def test_r_has_level_foot_open_counter_and_continuous_stencil_channel(self):
        manifest=json.loads((DIRECTORY/'manifest.json').read_text())
        for face in manifest['faces']:
            glyph=next(g['contours'] for g in face['glyphs'] if g['code']==ord('R'))
            baseline=max(y for p in glyph for x,y in p)
            # Check a complete right-leg horizontal edge at the baseline, not
            # the left stem/serif which hid the slanted foot in old bbox tests.
            feet=[abs(b[0]-a[0]) for p in glyph for a,b in zip(p,p[1:]+p[:1])
                  if a[1]==b[1]==baseline and min(a[0],b[0])>3]
            self.assertTrue(feet,face['source'])
            self.assertGreater(max(feet),0.8,face['source'])
            if face['source']=='STENCIL.FNT':
                for y in [i/20 for i in range(1,140)]:
                    self.assertFalse(classify((3.4,y),glyph),y)
                self.assertFalse(classify((4.3,1.7),glyph))
                self.assertTrue(classify((6.3,6.99),glyph))


if __name__=='__main__':unittest.main()
