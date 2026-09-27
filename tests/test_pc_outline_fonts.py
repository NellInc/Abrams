import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from fontTools.ttLib import TTFont
from tools.pc_fonts import decode_font
from tools.build_pc_outline_fonts import build_face

ROOT=Path(__file__).resolve().parents[1]
DIRECTORY=ROOT/'local-art/pc-outline-fonts-v1'


def classify(point,contours):
    x,y=point;inside=False
    for polygon in contours:
        for a,b in zip(polygon,polygon[1:]+polygon[:1]):
            area=(x-a[0])*(b[1]-a[1])-(y-a[1])*(b[0]-a[0])
            if abs(area)<1e-8 and min(a[0],b[0])<=x<=max(a[0],b[0]) and min(a[1],b[1])<=y<=max(a[1],b[1]):return None
            if (a[1]>y)!=(b[1]>y) and x<a[0]+(y-a[1])*(b[0]-a[0])/(b[1]-a[1]):inside=not inside
    return inside


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
        changed=0;cells=0
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
                    self.assertEqual(polys,item['contours'])
                    self.assertEqual(font['hmtx'][cmap[item['code']]][0],int(w*scale))
                    bits=source['glyphs'][item['code']-32]
                    self.assertEqual(bool(polys),any(bits))
                    for i,ink in enumerate(bits):
                        classification=classify((i%w+.5,i//w+.5),polys)
                        if classification is not None:self.assertEqual(classification,bool(ink))
                        cells+=1
                    for polygon in polys:
                        for x,y in polygon:self.assertTrue(0<=x<=w and 0<=y<=h)
                    changed+=int(item['redrawn'])
        self.assertEqual(changed,281)
        self.assertEqual(cells,21660)


if __name__=='__main__':unittest.main()
