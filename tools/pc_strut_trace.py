"""Source-verified original strut redraws, attributed back to matching plates.

The source of a claim is an actually executed STRUTS bitmap blit. Matching
framebuffer colours alone never creates provenance. Every opaque source pixel
must match the plate at the original coordinate, and the completed driver must
produce that source colour before any host-only ownership bits are assigned.
"""
from collections import Counter,deque
import struct
try:
    from tools.pc_bitmaps import decode_bitmaps,read_ega_bitmap
    from tools.inspect_scenarios import decode_resource
except ModuleNotFoundError:
    from pc_bitmaps import decode_bitmaps,read_ega_bitmap
    from inspect_scenarios import decode_resource


class StrutDraws:
    def __init__(self,game,plates):
        self.sources=decode_bitmaps(decode_resource((game/'STRUTS.BMP').read_bytes()))
        self.plates={i+1:[c for byte in plates.resources[name][0] for c in (byte>>4,byte&15)]
                     for i,name in enumerate(('GPS.BIN','TC.BIN','AA.BIN','DRIVER.BIN'))}
        self.pending=None;self.counts=Counter();self.draws=deque(maxlen=64)

    def begin(self,ram,regs,index):
        if self.pending is not None:raise ValueError('nested original strut draw')
        if len(ram)!=640*1024 or not 0<=index<len(self.sources):raise ValueError('invalid strut snapshot')
        load=regs['ds']-0x19E0;ds=regs['ds']*16;stack=regs['ss']*16+regs['sp']
        if load<=0 or regs['cs']!=load+0xF8D or ds+65536>len(ram) or stack+10>len(ram):raise ValueError('invalid strut segments')
        def word(at):return struct.unpack_from('<H',ram,ds+at)[0]
        descriptor,x,y=struct.unpack_from('<Hhh',ram,stack+4)
        table=word(0x798E)
        if not table or table+2*len(self.sources)>65536 or word(table+index*2)!=descriptor:raise ValueError('strut descriptor not in original table')
        source=self.sources[index];actual=read_ega_bitmap(ram,ds,descriptor)
        if any(actual[k]!=source[k] for k in ('width','height','pixels')) or actual['opaque']!=[c!=0 for c in source['pixels']]:
            raise ValueError('original strut differs from supplied source')
        self.counts['source_draws']+=1
        self.counts[f'source_draws_index_{index}']+=1
        w,h=source['width'],source['height'];page=(word(0x35A8)-0xA000)*16
        caller=struct.unpack_from('<HH',ram,stack)
        # Original cupola call0D8D deliberately draws STRUT5 seven pixels
        # beyond the right edge. Only this exact source route may use clipped
        # placement proof; all other offscreen layouts remain unsupported.
        clipped_cupola=(index==5 and (w,h,x,y)==(168,7,159,110) and caller==(0x0D92,load))
        if ((x<0 or y<0 or x+w>320 or y+h>200) and not clipped_cupola) or page not in (0,8192) or ram[ds+0x359F]!=15:
            self.counts['unsupported_layout']+=1;return
        # This relationship uses the actual named source bitmap and its original
        # placement, including pixels outside clipping, not the displayed frame.
        occupied=[((y+sy)*320+x+sx,source['pixels'][sy*w+sx])
                  for sy in range(h) for sx in range(w)
                  if source['pixels'][sy*w+sx]!=0 and 0<=x+sx<320 and 0<=y+sy<200]
        candidates=[plate for plate,pixels in self.plates.items() if occupied and all(pixels[at]==c for at,c in occupied)]
        if len(candidates)!=1:
            self.counts['unmapped_source_placement']+=1;return
        left,top,right,bottom=0,0,319,199
        if ram[ds+0x359B]:left,right,top,bottom=struct.unpack_from('<4h',ram,ds+0x3593)
        if not 0<=left<=right<320 or not 0<=top<=bottom<200:raise ValueError('unsupported strut clip')
        visible=[(at,c) for at,c in occupied if left<=at%320<=right and top<=at//320<=bottom]
        self.pending={'plate':candidates[0],'page':page,'pixels':visible,'index':index,'origin':[x,y],
                      'caller':caller,'source_clipped_cupola':clipped_cupola}

    def finish(self,pixels,page):
        pending,self.pending=self.pending,None
        if len(pixels)!=64000 or page not in (0,8192):raise ValueError('invalid completed strut pixels')
        if pending is None:return None
        if page!=pending['page']:raise ValueError('strut changed drawing page')
        if any(pixels[at]!=colour for at,colour in pending['pixels']):
            raise ValueError('completed original strut pixels differ from source')
        masks=bytearray(8000)
        for at,_ in pending['pixels']:masks[at//8]|=128>>(at&7)
        self.counts['verified_draws']+=1;self.counts['verified_pixels']+=len(pending['pixels'])
        self.counts[f"verified_draws_index_{pending['index']}"]+=1
        self.draws.append({k:v for k,v in pending.items() if k!='pixels'}|{'opaque_pixels':len(pending['pixels'])})
        return pending['plate'],bytes(masks)

    def report(self):return {'counts':dict(self.counts),'recent_draws':list(self.draws)}
