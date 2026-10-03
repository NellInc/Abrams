"""Only completed original map draw calls, with whole-map scanout equality."""
import hashlib
import struct
from collections import Counter
try:
    from tools.pc_live_state import SIM_SHA256
    from tools.pc_pixel_bytes import bgrx_rect_rgb, indexed_rgb
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from pc_live_state import SIM_SHA256
    from pc_pixel_bytes import bgrx_rect_rgb, indexed_rgb
RECT=(16,63,144,96)

class MapRuns:
    def __init__(self):
        self.terrain={};self.pages={};self.pending=None;self.markers=[];self.counts=Counter()
    def begin(self,raw):
        if len(raw)!=6: raise ValueError('invalid map begin')
        page,color,station,mode,video=struct.unpack('<H4B',raw)
        self.pages.pop(page,None);self.terrain.pop(page,None)
        self.pending={'page':page,'color':color,'lines':[],
            'valid':page in (0,8192) and color<16 and station==1 and mode==0 and video==16}
    def line(self,raw):
        if len(raw)!=16: raise ValueError('invalid map primitive')
        caller,x1,y1,x2,y2,color,clip,page,station,mode=struct.unpack('<H4hBBHBB',raw)
        line=[x1,y1,x2,y2,color]
        valid=page in (0,8192) and station==1 and color<16 and clip in (0,1) and 16<=x1<=x2<=159 and 63<=y1==y2<=158
        if caller in (0x1011,0x102c):
            if self.pending is None:
                self.counts['unobserved_entry']+=1;return
            p=self.pending
            p['valid'] &= valid and page==p['page'] and mode==0 and x2-x1==2 and (x1-16)%3==0 and (y1-63)%2==(caller==0x102c)
            p['lines'].append(line)
            if len(p['lines'])>4608: raise ValueError('too many map cells')
        elif caller in (0x1197,0x1263,0x1279):
            valid &= (mode==0 and caller==0x1197 and x1==x2) or (mode==1 and [x1,y1,x2,y2]==[87,110+(caller==0x1279),88,110+(caller==0x1279)])
            if caller in (0x1197,0x1263): self.markers=[];self.pages.pop(page,None)
            self.markers.append((page,mode,line,valid))
        else: raise ValueError('unknown map caller')
    def finish(self,raw,caller):
        if len(raw)!=10+144*96: raise ValueError('invalid map readback')
        x,y,w,h,page=struct.unpack_from('<5H',raw);pixels=bytes(raw[10:])
        if (x,y,w,h)!=RECT or page not in (0,8192) or max(pixels)>15: raise ValueError('invalid map readback bounds')
        if caller==0x1052:
            p=self.pending;self.pending=None
            if p is None:
                self.counts['unobserved_entry']+=1;return
            if not p['valid'] or p['page']!=page: self.counts['rejected']+=1;return
            expected=bytearray([p['color']])*(w*h)
            for x1,y1,x2,_,color in p['lines']:
                expected[(y1-y)*w+x1-x:(y1-y)*w+x2-x+1]=bytes([color])*(x2-x1+1)
            if expected!=pixels: self.counts['raster_mismatch']+=1;return
            self.terrain[page]={'background':p['color'],'lines':p['lines']}
            self.counts['terrain_completed']+=1;return
        if caller not in (0x11ae,0x1285): raise ValueError('unknown map completion')
        mode=int(caller==0x1285);markers=self.markers;self.markers=[]
        if len(markers)!=(2 if mode else 1) or any(not valid or pg!=page or md!=mode for pg,md,_,valid in markers):return
        terrain=self.terrain.get(page) if mode==0 else None
        if mode==0 and terrain is None:return
        lines=[entry[2] for entry in markers]
        if terrain:
            expected=bytearray([terrain['background']])*(w*h)
            for x1,y1,x2,_,color in terrain['lines']+lines:
                expected[(y1-y)*w+x1-x:(y1-y)*w+x2-x+1]=bytes([color])*(x2-x1+1)
            if expected!=pixels:self.counts['raster_mismatch']+=1;return
        elif any(pixels[(py-y)*w+px-x]!=color for x1,py,x2,_,color in lines for px in range(x1,x2+1)):return
        self.pages[page]=({'schema':1,'source_sha256':SIM_SHA256,'rect':list(RECT),'page_offset':page,
            'mode':mode,'background':terrain['background'] if terrain else None,
            'lines':(terrain['lines'] if terrain else [])+lines},pixels)
        self.counts['completed']+=1
    def scanout(self,page):return self.pages.get(page)
    def present(self,candidate,raw,width,height,palette):
        if candidate is None or (width,height)!=(320,200) or not palette or len(palette)!=16:return {}
        item,pixels=candidate;actual=bgrx_rect_rgb(raw,width,height,RECT)
        if indexed_rgb(pixels,palette)!=actual:self.counts['frame_mismatch']+=1;return {}
        self.counts['presented']+=1
        return item|{'pixel_sha256':hashlib.sha256(actual).hexdigest(),'palette_rgb':palette,
            'basis':'original map primitives, completed map readback and exact scanout RGB'}
    def report(self):return dict(self.counts)
