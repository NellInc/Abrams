import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from fontTools.ttLib import TTFont
from tools.pc_fonts import decode_font
from tools.build_pc_outline_fonts import build_face

ROOT=Path(__file__).resolve().parents[1]
DIRECTORY=ROOT/'local-art/pc-outline-fonts-v2'


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
        self.assertEqual(changed,295)
        self.assertEqual(optical,203)
        self.assertEqual(cells,21660)

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


if __name__=='__main__':unittest.main()
