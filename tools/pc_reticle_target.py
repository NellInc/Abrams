"""Completed original-PC target-selection box, paired to displayed RGB only."""
import hashlib
import struct
try:
    from tools.pc_pixel_bytes import bgrx_rect_rgb, indexed_rgb
    from tools.pc_live_state import SIM_SHA256
    from tools.pc_reticle import CLIP
except ModuleNotFoundError:
    from pc_pixel_bytes import bgrx_rect_rgb, indexed_rgb
    from pc_live_state import SIM_SHA256
    from pc_reticle import CLIP


def lines(x, y):
    return [(x-5,y-5,x+5,y-5),(x-5,y+5,x+5,y+5),
            (x-5,y-5,x-5,y+5),(x+5,y-5,x+5,y+5)]


def ink_pixels(x, y):
    ink=set()
    for x1,y1,x2,y2 in lines(x,y):
        if y1==y2:
            if CLIP[1]<=y1<=CLIP[3]:
                ink.update((px,y1) for px in range(max(x1,CLIP[0]),min(x2,CLIP[2])+1))
        elif CLIP[0]<=x1<=CLIP[2]:
            if y1<CLIP[1]:
                if y2<CLIP[1]: continue
                y1=CLIP[1]
            if y2>CLIP[3]:
                if y1>CLIP[3]: continue
                y1,y2=CLIP[3],y1
            ink.update((x1,py) for py in range(y1,y2,1 if y2>y1 else -1))
            if y1==y2: ink.add((x1,y1))
    return sorted(ink,key=lambda p:(p[1],p[0]))


class TargetBoxRuns:
    def __init__(self):
        from collections import Counter
        self.pages={};self.pending=None;self.counts=Counter()

    def begin(self,raw,regs):
        if len(raw)!=65536 or regs['ds']!=regs['cs']+0x19E0: raise ValueError('invalid target entry')
        # A fresh original gunner draw invalidates stale selection immediately.
        page=(struct.unpack_from('<H',raw,0x35A8)[0]-0xA000)*16
        self.pages.pop(page,None);self.counts['entries']+=1
        valid=(page in (0,8192) and raw[0x799D]==0 and raw[0x35AE]==16 and raw[0x359B]==1
               and raw[0x359E] in (0,1) and struct.unpack_from('<4h',raw,0x3593)==(32,287,13,109)
               and struct.unpack_from('<H',raw,0x79AF)[0]!=0)
        self.pending={'valid':valid,'page':page,'color':raw[0x359E],'lines':[]}

    def line(self,raw):
        if self.pending is None or len(raw)!=12: raise ValueError('invalid target line event')
        x1,y1,x2,y2,color,clip,page=struct.unpack('<4hBBH',raw)
        p=self.pending
        if color!=p['color'] or clip!=1 or (page-0xA000)*16!=p['page']: p['valid']=False
        p['lines'].append((x1,y1,x2,y2))

    def finish(self,raw):
        if self.pending is None: raise ValueError('target return without entry')
        p=self.pending;self.pending=None
        if not raw or not p['valid'] or len(p['lines'])!=4:
            self.counts['absent_or_rejected_draws']+=1;return
        cx,cy=p['lines'][0][0]+5,p['lines'][0][1]+5
        if p['lines']!=lines(cx,cy): self.counts['geometry_mismatches']+=1;return
        if len(raw)!=10+256*97: raise ValueError('invalid target readback length')
        x,y,w,h,page=struct.unpack_from('<5H',raw);pixels=bytes(raw[10:])
        if (x,y,w,h,page)!=(32,13,256,97,p['page']) or max(pixels)>15: raise ValueError('invalid target readback')
        ink=ink_pixels(cx,cy)
        if not ink: self.counts['fully_clipped_draws']+=1;return
        if any(pixels[(py-y)*w+px-x]!=p['color'] for px,py in ink):
            self.counts['raster_mismatches']+=1;return
        item={'schema':1,'source_sha256':SIM_SHA256,'rect':[x,y,w,h],'page_offset':page,
              'center':[cx,cy],'color':p['color'],'lines':[list(line) for line in p['lines']]}
        self.pages[page]=(item,pixels);self.counts['completed_draws']+=1

    def scanout(self,page): return self.pages.get(page)

    def present(self,candidate,raw,width,height,palette):
        if candidate is None or (width,height)!=(320,200) or not palette or len(palette)!=16:return {}
        item,pixels=candidate
        actual=bgrx_rect_rgb(raw,width,height,item['rect'])
        if indexed_rgb(pixels,palette)!=actual:self.counts['frame_mismatches']+=1;return {}
        self.counts['presented_draws']+=1
        return item|{'pixel_sha256':hashlib.sha256(actual).hexdigest(),
                     'basis':'four original target-box calls, completed gunner sight and exact scanout RGB'}

    def report(self): return dict(self.counts)
