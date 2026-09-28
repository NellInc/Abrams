"""Original orientation geometry and completed-draw visibility evidence.

Only presentation metadata is produced. No replacement simulation or guest writes.
"""
import hashlib
import struct
try:
    from tools.pc_pixel_bytes import bgrx_rect_rgb, indexed_rgb
    from tools.pc_live_state import SIM_SHA256
except ModuleNotFoundError:
    from pc_pixel_bytes import bgrx_rect_rgb, indexed_rgb
    from pc_live_state import SIM_SHA256

TRIG_SHA256 = 'ded7bcfa752de6745823d08d80aeab33fdbb77a7d9fda2ddc8f86bb99d437c9e'
QUAD_CALLERS = (0x6135, 0x615E, 0x6214, 0x62A3)
GRID_CALLERS = (0x567F, 0x56A5, 0x56DD)
EDGE_CALLERS = (0x5FA5, 0x5FC3, 0x5FE1, 0x5FFF)


def diagram(ram, ds):
    """Independently model 600c/5da8 fixed-point vertices before rasterization."""
    def word(at): return struct.unpack_from('<H', ram, ds+at)[0]
    station = ram[ds+0x799D]
    if station not in (0,1): raise ValueError('unsupported orientation station')
    table = ram[ds+0x1D9C:ds+0x1D9C+640]
    if hashlib.sha256(table).hexdigest() != TRIG_SHA256: raise ValueError('unknown orientation trig table')
    body, turret = word(0x799B), word(0x7999)
    if max(body+0x1A,turret+0x0B)+ds >= len(ram): raise ValueError('invalid orientation objects')
    sine = struct.unpack_from('<256h',table)
    cosine = struct.unpack_from('<256h',table,128)
    hull_angle = (ram[ds+body+0x1A]+64)&255
    turret_angle = (hull_angle+ram[ds+turret+0x0B])&255
    left,top = (128,137) if station==0 else (216,83)
    grid = [];grid_callers=[]
    x = left-((word(body+4)>>4)&15)
    y = top+((word(body+6)>>4)&15)
    for i in range(5):
        if left <= x+i*16 <= left+61:
            grid.append([x+i*16,top,x+i*16,top+44]);grid_callers.append(0x56DD if i==4 else 0x567F)
        if i<4 and top <= y+i*16 <= top+43:
            grid.append([left,y+i*16,left+61,y+i*16]);grid_callers.append(0x56A5)
    quads=[]
    for i in range(4):
        angle = hull_angle if i<2 else turret_angle
        length,width = (16,10) if i<2 else (8,6)
        ux,uy = length*cosine[angle],length*sine[angle]
        vx,vy = width*sine[angle],-width*cosine[angle]
        ox,oy = (ux>>3,uy>>3) if i==0 else (0,0)
        if i==3: vx,vy,ox,oy = vx>>2,vy>>2,ux+(ux>>3),uy+(uy>>3)
        # Memory order at DS:6496 is Ux,Vx,Uy,Ox,Vy,Oy.
        basis=[ux,vx,uy,ox,vy,oy]
        precise=[[((left+32)<<14)+u*ux+v*vx+ox,((top+21)<<14)-(u*uy+v*vy+oy)]
                 for u,v in ((1,1),(-1,1),(-1,-1),(1,-1))]
        # Original Y subtracts the floored product from the integer centre.
        points=[[left+32+((u*ux+v*vx+ox)>>14),top+21-((u*uy+v*vy+oy)>>14)]
                for u,v in ((1,1),(-1,1),(-1,-1),(1,-1))]
        quads.append({'basis':basis,'points':points,'vertices_q14':precise})
    return {'station':station,'rect':[left,top,62,44],'grid':grid,'grid_callers':grid_callers,'quads':quads}


class OrientationRuns:
    """Completed original draws, bound to scanout and a full visible RGB match."""
    def __init__(self):
        from collections import Counter
        self.pages = {}
        self.pending = None
        self.counts = Counter()

    def begin(self, raw, regs):
        if len(raw)!=65536 or regs['ds']!=regs['cs']+0x19E0:
            raise ValueError('invalid native orientation entry')
        if self.pending is not None: raise ValueError('nested orientation draw')
        page=(struct.unpack_from('<H',raw,0x35A8)[0]-0xA000)*16
        self.pages.pop(page,None)
        self.pending={'page':page,'valid':False,'quads':[],'lines':[]}
        self.counts['entries']+=1
        try:
            if page not in (0,8192) or raw[0x35AE]!=16: raise ValueError('unsupported orientation video mode')
            geometry=diagram(raw,0)
            x,y,w,h=geometry['rect']
            if struct.unpack_from('<4h',raw,0x3593)!=(x,x+w-1,y,y+h-1):
                raise ValueError('unsupported orientation clip bounds')
            if raw[0x359C] not in (0,1): raise ValueError('unsupported orientation fill mode')
            theme=bool(struct.unpack_from('<H',raw,0x8D68)[0])
            status=raw[0xC9D]
            if status not in (0,1,2): raise ValueError('unsupported orientation component status')
            edges=[raw[at] for at in (0xCB8,0xCB9,0xCB7,0xCB6)]
            if max(edges)>15: raise ValueError('unsupported orientation edge colour')
            self.pending.update(valid=True,geometry=geometry,theme=theme,status=status,
                                fill=raw[0x359C],edge_colors=edges)
        except ValueError as error:
            self.counts['unsupported: '+str(error)]+=1

    def quad(self, raw):
        if len(raw)!=50 or self.pending is None: raise ValueError('invalid orientation polygon observation')
        p=self.pending
        if not p['valid']: return
        clip,fill,interior,border,page,edges,caller,*values=struct.unpack('<4B3H8h6i',raw)
        i=len(p['quads'])
        if i>=4: p['valid']=False; return
        expected=p['geometry']['quads'][i]
        points=[list(v) for v in zip(values[:4],values[4:8])]
        color=(3 if p['theme'] else 1) if i<2 else (1 if p['theme'] else 2)
        if i==3 and p['status']: color=10 if p['status']==1 else 6
        if (points!=expected['points'] or values[8:]!=expected['basis'] or caller!=QUAD_CALLERS[i]
            or [clip,fill,interior,border]!=[0,p['fill'],0,color] or
            (page-0xA000)*16!=p['page'] or edges!=int(i==2 and not p['theme'])):
            p['valid']=False; self.counts['geometry_mismatches']+=1; return
        p['quads'].append(expected | {'border':border,'fill':interior,'filled':bool(fill),
                                      'edges':p['edge_colors'] if edges else []})

    def line(self, raw):
        if len(raw)!=14 or self.pending is None: raise ValueError('invalid orientation line observation')
        caller,x1,y1,x2,y2,color,clip,page=struct.unpack('<H4hBBH',raw)
        p=self.pending
        if not p['valid']: return
        if clip!=0 or (page-0xA000)*16!=p['page']:
            p['valid']=False; return
        p['lines'].append((caller,[x1,y1,x2,y2],color))

    def finish(self, raw):
        if self.pending is None: raise ValueError('orientation return without entry')
        p=self.pending; self.pending=None
        if not raw or not p['valid']: self.counts['rejected_draws']+=1; return
        if len(raw)<10: raise ValueError('invalid orientation readback')
        x,y,w,h,page=struct.unpack_from('<5H',raw);pixels=bytes(raw[10:])
        if len(pixels)!=w*h or max(pixels,default=0)>15: raise ValueError('invalid orientation pixels')
        if [x,y,w,h]!=p['geometry']['rect'] or page!=p['page']: raise ValueError('orientation readback differs')
        if len(p['quads'])!=4: self.counts['incomplete_draws']+=1; return
        wanted=[(caller,line,8) for caller,line in zip(p['geometry']['grid_callers'],p['geometry']['grid'])]
        grid=[(caller,line,color) for caller,line,color in p['lines'] if caller in GRID_CALLERS]
        edges=[(caller,line,color) for caller,line,color in p['lines'] if caller in EDGE_CALLERS]
        points=p['quads'][2]['points']
        wanted_edges=[] if p['theme'] else [(caller,points[i]+points[(i+1)%4],p['edge_colors'][i]) for i,caller in enumerate(EDGE_CALLERS)]
        known=all(caller in GRID_CALLERS+EDGE_CALLERS for caller,_,_ in p['lines'])
        if not known or grid!=wanted or edges!=wanted_edges:
            self.counts['line_mismatches']+=1; return
        item={'schema':1,'source_sha256':SIM_SHA256,'rect':[x,y,w,h],'page_offset':page,
              'station':p['geometry']['station'],'grid':[{'points':line,'color':color} for _,line,color in grid],
              'quads':p['quads']}
        self.pages[page]=(item,pixels)
        self.counts['completed_draws']+=1

    def scanout(self, page):
        return self.pages.get(page)

    def present(self, candidate, raw, width, height, palette):
        if candidate is None or (width,height)!=(320,200) or not palette or len(palette)!=16: return {}
        item,pixels=candidate
        x,y,w,h=item['rect']
        rgb=indexed_rgb(pixels,palette)
        actual=bgrx_rect_rgb(raw,width,height,(x,y,w,h))
        if rgb!=actual:
            self.counts['frame_mismatches']+=1; return {}
        self.counts['presented_draws']+=1
        return item | {'pixel_sha256':hashlib.sha256(actual).hexdigest(),
                       'basis':'original completed draw, source geometry and full presented RGB rectangle'}

    def report(self): return dict(self.counts)
