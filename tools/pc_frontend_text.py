"""Observe original START/BRIEF/END font draws, never author menu state.

Profiles are derived from pinned executables. Completed source glyphs must match
an entire presented RGB rectangle. No OCR, guest writes or inferred menu values.
"""
import base64
import ctypes as C
import hashlib
import io
import struct
from pathlib import Path
from PIL import Image
try:
    from tools.pc_live_state import active_program
    from tools.pc_text_trace import TextRuns
    from tools.unpack_pc_executables import unpack
    from tools.pc_bitmaps import decode_bitmaps,read_ega_bitmap
    from tools.inspect_scenarios import decode_resource
    from tools.pc_frontend_scene import FrontendScene
except ModuleNotFoundError:
    from pc_live_state import active_program
    from pc_text_trace import TextRuns
    from unpack_pc_executables import unpack
    from pc_bitmaps import decode_bitmaps,read_ega_bitmap
    from inspect_scenarios import decode_resource
    from pc_frontend_scene import FrontendScene

ROOT = Path(__file__).resolve().parents[1]
CALLBACK = C.CFUNCTYPE(None,C.c_uint32,C.POINTER(C.c_uint16),C.c_void_p,C.c_uint32,C.c_uint32)
# DS, wrapper segment/IP, driver segment/IP, foreground field, source SHA.
PROFILES = {
    'START':(0x1505,0x760,0x212,0xb5a,0x60,0x2648,'a6fd07ae3df4f61806852d92c0c50354b7f7afccee10da88710ef0bc3361ca6a'),
    'BRIEF':(0xc71,0x3c7,0x212,0x6e7,0x5c,0x894,'11565943351af89d069595864d26728c866ffa30cb09e66a1765c571978a7c92'),
    'END':(0xd22,0x477,0x20e,0x798,0x5c,0x637c,'82ab4efab14dfdfd6d9d0c6c8276e2c2187dbe4e6f8f09cc9fc0fa6267ad0c40')}

CURSOR_SHA='a7b6148ea54b389b1385c0932d8d9c6ae071cec5edbec75c8e13f1ae17bb6495'

def cursor_cells(cursor):
    if not cursor:return set()
    x,y,w,h=cursor['rect']
    return {(x+i%w,y+i//w) for i,c in enumerate(base64.b64decode(cursor['indices'])) if c}

def visible_runs(candidates,raw,width,height,palette,cursor=None):
    """Match complete source cells after original selection-colour inversion.

    Menus invert highlights after drawing their strings. Match the original ink
    mask against two uniform current colours, never infer a word from RAM alone.
    A pointer/overwrite rejects its cell; adjacent intact letters can still draw.
    """
    if (width,height)!=(320,200) or not palette or len(palette)!=16:return []
    found={};covered=cursor_cells(cursor)
    for item,pixels,ink in candidates:
        x,y,w,h=item['rect'];cell=item['cell_size'][0];groups=[]
        for i,char in enumerate(item['text']):
            colours=[set(),set()];actual=bytearray()
            for dy in range(h):
                for dx in range(cell):
                    if (x+i*cell+dx,y+dy) in covered:continue
                    start=((y+dy)*320+x+i*cell+dx)*4
                    rgb=bytes((raw[start+2],raw[start+1],raw[start]))
                    actual.extend(rgb);colours[ink[dy*w+i*cell+dx]].add(rgb)
            if len(colours[0])==1 and not colours[1]:
                bg=next(iter(colours[0]))
                if groups and groups[-1]['rect'][0]+groups[-1]['rect'][2]==x+i*cell and groups[-1]['uniform_background_rgb']==list(bg):
                    groups[-1]['text']+=char;groups[-1]['rect'][2]+=cell
                continue
            if len(colours[0])!=1 or len(colours[1])!=1:continue
            bg=next(iter(colours[0]));fg=next(iter(colours[1]))
            if bg==fg or list(fg) not in palette:continue
            value=item|{'text':char,'rect':[x+i*cell,y,cell,h],
                'foreground':palette.index(list(fg)),'uniform_background_rgb':list(bg),
                'basis':'completed original string and exact full current glyph cell; original highlight colours retained'}
            if groups and groups[-1]['rect'][0]+groups[-1]['rect'][2]==value['rect'][0] and all(groups[-1][k]==value[k] for k in ('foreground','uniform_background_rgb')):
                groups[-1]['text']+=char;groups[-1]['rect'][2]+=cell
            else:groups.append(value)
        for value in groups:
            xx,yy,ww,hh=value['rect']
            actual=bytes(raw[((yy+dy)*320+xx+dx)*4+c] for dy in range(hh) for dx in range(ww) for c in (2,1,0))
            value['pixel_sha256']=hashlib.sha256(actual).hexdigest()
            key=(tuple(value['rect']),value['font_sha256'],value['text'])
            if key not in found or value['draw_sequence']>found[key]['draw_sequence']:found[key]=value
    return sorted(found.values(),key=lambda r:r['draw_sequence'])

class FrontendSources:
    def __init__(self, directory=ROOT/'GAME'):
        self.profiles={}
        raw=(directory/'CURSOR.BMP').read_bytes()
        if hashlib.sha256(raw).hexdigest()!=CURSOR_SHA:raise ValueError('unsupported original cursor')
        self.cursor=decode_bitmaps(decode_resource(raw))[0]
        for name,values in PROFILES.items():
            ds,wrapper,ip,driver,driver_ip,fg,pin=values
            raw=(directory/(name+'.EXE')).read_bytes()
            if hashlib.sha256(raw).hexdigest()!=pin: raise ValueError('unsupported original '+name)
            decoded,meta=unpack(raw)
            relocations={r['load_offset'] for r in meta['relocations']}
            call=struct.pack('<BHH',0x9a,ip,wrapper)
            callers={at+2:'frontend' for at in relocations if decoded[at-3:at+2]==call}
            anchors=[]
            for at,length in [(wrapper*16+ip,80),(driver*16+driver_ip,709),(meta['entry']['ip'],10)]:
                if any(at<=r+delta<at+length for r in relocations for delta in (0,1)):
                    raise ValueError('frontend anchor contains relocation')
                anchors.append((at,decoded[at:at+length]))
            self.profiles[name]={'ds':ds,'wrapper':wrapper,'entry':ip,'driver':driver,
                'driver_ip':driver_ip,'foreground':fg,'callers':callers,'anchors':anchors}

    def match(self, ram, regs):
        program=active_program(ram)
        if not program or program['name'] not in self.profiles:return None
        p=self.profiles[program['name']];load=program['load_segment'];base=load*16
        if regs['ds']!=load+p['ds'] or regs['cs']!=load+p['wrapper']:return None
        if any(ram[base+at:base+at+len(code)]!=code for at,code in p['anchors']):return None
        stack=regs['ss']*16+regs['sp']
        if stack+10>len(ram):return None
        caller,cs=struct.unpack_from('<HH',ram,stack)
        if cs!=load or caller not in p['callers']:return None
        return program,p

    def visible_cursor(self,ram,raw,palette):
        program=active_program(ram)
        if not program or program['name']!='START' or not palette or len(raw)!=320*200*4:return None
        ds=(program['load_segment']+self.profiles['START']['ds'])*16
        if ds+0x9a66>len(ram):return None
        x,y=struct.unpack_from('<hh',ram,ds+0x04c4)
        if x<0 or y<0 or x+16>320 or y+15>200:return None
        descriptor=struct.unpack_from('<H',ram,ds+0x9a64)[0]
        try:loaded=read_ega_bitmap(ram,ds,descriptor)
        except (ValueError,struct.error):return None
        if any(loaded[k]!=self.cursor[k] for k in ('width','height','pixels')) or loaded['opaque']!=[bool(c) for c in self.cursor['pixels']]:return None
        for i,c in enumerate(self.cursor['pixels']):
            if not c:continue
            at=((y+i//16)*320+x+i%16)*4
            if [raw[at+2],raw[at+1],raw[at]]!=palette[c]:return None
        return {'rect':[x,y,16,15],'indices':base64.b64encode(bytes(self.cursor['pixels'])).decode(),'source_sha256':CURSOR_SHA}

class FrontendText:
    def __init__(self, sources=None):
        self.sources=sources or FrontendSources()
        self.text=None;self.program=None;self.pending=False;self.error=None
        self.scanout=None;self.buffers={};self.presented=None
        self.last_frame={}
        self.callback=CALLBACK(self.observe)
        self.counts=[]
        self.scene=FrontendScene(ROOT/'GAME')

    def observe(self,event,registers,data,offset,length):
        try:
            raw=C.string_at(data,length)
            if 49<=event<=55:
                regs=dict(zip(('ax','bx','cx','dx','si','di','bp','sp','cs','ds','es','ss'),registers[:12]))
                self.scene.observe(event,regs,raw,offset)
                return
            if event==26:
                regs=dict(zip(('ax','bx','cx','dx','si','di','bp','sp','cs','ds','es','ss'),registers[:12]))
                match=self.sources.match(raw,regs)
                self.pending=bool(match)
                if not match:return
                program,p=match
                if program!=self.program:
                    if self.text:self.counts.append(self.text.report())
                    self.program=program;self.text=TextRuns(ROOT/'GAME',p)
                    self.scanout=None;self.buffers.clear();self.presented=None
                    self.scene.clear()
                self.text.begin(raw,regs)
            elif event==27:
                if self.pending:self.text.finish(raw)
                self.pending=False
            elif event==10:
                # Original page copies can carry completed labels to the other
                # page. Every candidate still requires an exact full RGB match.
                candidates=tuple(self.text.pages.values()) if self.text else ()
                self.scanout={'page_offset':offset,'candidates':candidates,
                    'program':self.program,'palette_rgb':[list(raw[i:i+3]) for i in range(0,64,4)] if len(raw)==64 else None}
            elif event==11:
                if offset not in range(3):raise ValueError('invalid frontend framebuffer slot')
                self.buffers[offset]=self.scanout
            elif event==12:
                if offset not in range(3):raise ValueError('invalid frontend framebuffer slot')
                width,height=registers[0],registers[1]
                if length!=width*height*4:raise ValueError('invalid frontend framebuffer bytes')
                frame=self.buffers.get(offset) or {}
                self.last_frame=frame
                self.presented={'draw_pass':None,'reason':'original frontend text only',
                    'frontend_program':frame.get('program'),'palette_rgb':frame.get('palette_rgb'),
                    'width':width,'height':height,'video_sha256':hashlib.sha256(raw).hexdigest()}
        except Exception as error:self.error=error

    def paired_video(self,video,ram=None):
        if self.error:raise self.error
        if not self.presented:return {'draw_pass':None,'reason':'waiting for original frontend text'}
        raw,w,h,pitch=video
        if (w,h,pitch)!=(self.presented['width'],self.presented['height'],w*4) or hashlib.sha256(raw).hexdigest()!=self.presented['video_sha256']:
            raise ValueError('frontend metadata differs from presented video')
        # Classify only requested presentations, using their immutable scanout
        # candidates. Fast-forwarded capture frames never need host font meshes.
        cursor=self.sources.visible_cursor(ram,raw,self.last_frame.get('palette_rgb')) if ram is not None else None
        runs=visible_runs(self.last_frame.get('candidates',()),raw,w,h,self.last_frame.get('palette_rgb'),cursor)
        mask=Image.new('L',(320,200))
        is_start=(self.presented.get('frontend_program') or {}).get('name')=='START'
        drawing=self.scene.paired(raw,self.last_frame.get('palette_rgb'),runs,cursor) if is_start and w==320 and h==200 else None
        if drawing:
            mask.paste(255,(0,0,320,200))
            x,y,ww,hh=drawing['preview_rect']
            mask.paste(0,(x,y,x+ww,y+hh))
            for x,y in cursor_cells(cursor):mask.putpixel((x,y),255)
        for run in runs:
            x,y,ww,hh=run['rect'];mask.paste(255,(x,y,x+ww,y+hh))
        stream=io.BytesIO();mask.save(stream,format='PNG')
        return self.presented|{'draw_pass':drawing,'reason':'pixel-paired START scenery' if drawing else self.presented['reason'],
            'text_runs':runs,'original_cursor':cursor,
            'ui_overlay':{'width':320,'height':200,'mask_png':base64.b64encode(stream.getvalue()).decode()}}

    def attach(self,core):
        core.pause_at_frame_end()
        configure=core.core.abrams_frontend_text_configure
        configure.argtypes=[CALLBACK];configure.restype=None
        configure(self.callback)

    def detach(self,core):
        core.pause_at_frame_end()
        core.core.abrams_trace_configure.argtypes=[C.c_uint16,CALLBACK]
        core.core.abrams_trace_configure(0,CALLBACK())
