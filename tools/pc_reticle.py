"""Original gunner graticule geometry; read-only presentation evidence."""
import hashlib
import struct

try:
    from tools.pc_pixel_bytes import bgrx_rect_rgb, indexed_rgb
    from tools.pc_live_state import SIM_SHA256
except ModuleNotFoundError:
    from pc_pixel_bytes import bgrx_rect_rgb, indexed_rgb
    from pc_live_state import SIM_SHA256

TABLE_SHA256 = 'b7cba01774ea26a79711b547634c0b0c46abebe9f9b214f110b37db594316a9c'
OFFSETS = ((-4,20,4,20),(0,20,0,3),(25,3,25,-4),(25,0,4,0),
           (-4,-20,4,-20),(0,-20,0,-3),(-25,3,-25,-4),(-25,0,-4,0))
CLIP = (32,13,287,109)


def lines(center):
    return [(159+x1,center+y1,159+x2,center+y2) for x1,y1,x2,y2 in OFFSETS]


def ink_pixels(center):
    """Axis-only 0f8d:025a clipping and original EGA endpoint convention.

    Horizontal lines include both ends; vertical lines exclude the destination.
    A clipped endpoint becomes the start, matching the original wrapper swaps.
    """
    ink=set()
    for x1,y1,x2,y2 in lines(center):
        if y1==y2:
            if CLIP[1]<=y1<=CLIP[3]:
                ink.update((x,y1) for x in range(min(x1,x2),max(x1,x2)+1))
            continue
        if y1<CLIP[1]:
            if y2<CLIP[1]: continue
            y1=CLIP[1]
        elif y2<CLIP[1]:
            y1,y2=CLIP[1],y1
        if y1>CLIP[3]:
            if y2>CLIP[3]: continue
            y1=CLIP[3]
        elif y2>CLIP[3]:
            y1,y2=CLIP[3],y1
        ink.update((x1,y) for y in range(y1,y2,1 if y2>y1 else -1))
        if y1==y2: ink.add((x1,y1))
    return sorted(ink,key=lambda p:(p[1],p[0]))


class ReticleRuns:
    """Only completed eight-line draws whose whole readback survives scanout."""
    def __init__(self):
        from collections import Counter
        self.pages={};self.pending=None;self.counts=Counter()

    def begin(self,raw,regs):
        if len(raw)!=65536 or regs['ds']!=regs['cs']+0x19E0: raise ValueError('invalid reticle entry')
        if self.pending is not None: raise ValueError('nested reticle draw')
        page=(struct.unpack_from('<H',raw,0x35A8)[0]-0xA000)*16
        self.pages.pop(page,None);self.counts['entries']+=1
        center=(regs['ax']+32768)%65536-32768
        valid=(page in (0,8192) and raw[0x799D]==0 and raw[0x35AE]==16 and raw[0x359B]==1
               and raw[0x359E] in (0,1) and struct.unpack_from('<4h',raw,0x3593)==(32,287,13,109)
               and hashlib.sha256(raw[0xBBA:0xBFA]).hexdigest()==TABLE_SHA256)
        self.pending={'valid':valid,'page':page,'center':center,'color':raw[0x359E],'lines':[]}

    def line(self,raw):
        if self.pending is None or len(raw)!=12: raise ValueError('invalid reticle line event')
        x1,y1,x2,y2,color,clip,page=struct.unpack('<4hBBH',raw)
        p=self.pending
        if color!=p['color'] or clip!=1 or (page-0xA000)*16!=p['page']: p['valid']=False
        p['lines'].append((x1,y1,x2,y2))

    def finish(self,raw):
        if self.pending is None: raise ValueError('reticle return without entry')
        p=self.pending;self.pending=None
        if not raw or not p['valid'] or p['lines']!=lines(p['center']):
            self.counts['rejected_draws']+=1;return
        if len(raw)!=10+51*97: raise ValueError('invalid reticle readback length')
        x,y,w,h,page=struct.unpack_from('<5H',raw);pixels=bytes(raw[10:])
        if (x,y,w,h,page)!=(134,13,51,97,p['page']) or max(pixels)>15: raise ValueError('invalid reticle readback')
        ink=ink_pixels(p['center'])
        if not ink: self.counts['fully_clipped_draws']+=1;return
        if any(pixels[(py-y)*w+px-x]!=p['color'] for px,py in ink):
            self.counts['raster_mismatches']+=1;return
        item={'schema':1,'source_sha256':SIM_SHA256,'table_sha256':TABLE_SHA256,
              'rect':[x,y,w,h],'page_offset':page,'center_y':p['center'],'color':p['color'],
              'lines':[list(line) for line in p['lines']]}
        self.pages[page]=(item,pixels);self.counts['completed_draws']+=1

    def scanout(self,page): return self.pages.get(page)

    def present(self,candidate,raw,width,height,palette):
        if candidate is None or (width,height)!=(320,200) or not palette or len(palette)!=16: return {}
        item,pixels=candidate;x,y,w,h=item['rect']
        expected=indexed_rgb(pixels,palette)
        actual=bgrx_rect_rgb(raw,width,height,(x,y,w,h))
        if expected!=actual: self.counts['frame_mismatches']+=1;return {}
        self.counts['presented_draws']+=1
        return item|{'pixel_sha256':hashlib.sha256(actual).hexdigest(),
                     'basis':'original completed eight-line draw and full scanout RGB match'}

    def report(self): return dict(self.counts)
