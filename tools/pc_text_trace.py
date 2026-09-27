"""Read-only, source-verified PC text runs paired with actual presented pixels.

This supplies visible text metadata only. It is not a message-occurrence detector,
voice scheduler or permission to expose queued messages from current guest RAM.
"""
from collections import Counter
import hashlib
import struct
try:
    from tools.pc_fonts import FONT_NAMES, loaded_font, text_pixels
    from tools.pc_message_events import MessageAssignments
except ModuleNotFoundError:
    from pc_fonts import FONT_NAMES, loaded_font, text_pixels
    from pc_message_events import MessageAssignments

CALLERS = {0x3F1D: 'crew_primary', 0x3F58: 'crew_secondary',
           0x400D: 'radio', 0x55DF: 'weapon_status'}


class TextRuns:
    def __init__(self, source):
        self.catalog = {name: (source/name).read_bytes() for name in FONT_NAMES}
        self.pages = {}
        self.pending = None
        self.sequence = 0
        self.messages = MessageAssignments()
        self.counts = Counter()

    def begin(self, ram, regs):
        if len(ram) != 640*1024: raise ValueError('invalid native text entry snapshot')
        if self.pending is not None: raise ValueError('nested native text observation')
        ds, stack = regs['ds']*16, regs['ss']*16+regs['sp']
        if ds+65536 > len(ram) or stack+10 > len(ram): raise ValueError('invalid native text segments')
        caller, cs, pointer, x, y = struct.unpack_from('<5H',ram,stack)
        if caller not in CALLERS or regs['ds'] != cs+0x19E0 or regs['cs'] != cs+0x0F8D:
            raise ValueError('unknown original text caller')
        page = (struct.unpack_from('<H',ram,ds+0x35A8)[0]-0xA000)*16
        key = (page, caller)
        self.pages.pop(key,None)
        self.pending = (key,None)
        self.counts['entries'] += 1
        self.sequence += 1
        # Unsupported legitimate source text stays original-only. Never invent
        # glyphs, clip a label, or reuse the previous label after a failed draw.
        try:
            font = loaded_font(ram,ds,self.catalog)
            if struct.unpack_from('<HH',ram,ds+0x35B4) != (0x68,cs+0x1388):
                raise ValueError('unsupported character driver')
            end = ram.find(b'\0',ds+pointer,min(ds+65536,ds+pointer+321))
            if end < 0: raise ValueError('unterminated original text')
            text = ram[ds+pointer:end]
            width,height,ink = text_pixels(font,text)
            if page not in (0,8192) or x+width>320 or y+height>200:
                raise ValueError('unsupported text rectangle')
            foreground,background = [struct.unpack_from('<H',ram,ds+0x48A6+2*ram[ds+at])[0]&255
                                     for at in (0x3590,0x3591)]
            mode = ram[ds+0x3592]
            if foreground>15 or background>15 or mode not in (0,1) or not any(ink):
                raise ValueError('unsupported text colors or blank run')
            item = {'kind':CALLERS[caller], 'return_ip':caller,'source_pointer':pointer,
                    'text':text.decode('cp437'), 'draw_sequence':self.sequence, 'rect':[x,y,width,height], 'page_offset':page,
                    'font_sha256':font['sha256'],'font_sources':font['sources'],
                    'foreground':foreground,'background':background,'transparent':bool(mode),
                    'speaker':ram[ds+0x6464] if caller in (0x3F1D,0x3F58) else None}
            self.messages.bind(item,text)
            self.pending = (key,(item,ink))
        except ValueError as error:
            self.counts['unsupported_entries'] += 1
            self.counts['unsupported: '+str(error)] += 1

    def finish(self, raw):
        if self.pending is None: raise ValueError('native text return without entry')
        key, candidate = self.pending
        self.pending = None
        if not raw:
            self.counts['unsupported_returns'] += 1
            return
        if len(raw)<12: raise ValueError('invalid native text rectangle')
        x,y,width,height,page,caller = struct.unpack_from('<6H',raw)
        pixels = raw[12:]
        if len(pixels)!=width*height or any(p>15 for p in pixels):
            raise ValueError('invalid native text pixels')
        if candidate is None: return
        item,ink = candidate
        if [x,y,width,height]!=item['rect'] or (page,caller)!=key:
            raise ValueError('native text entry/return differ')
        if any((bit and pixel!=item['foreground']) or
               (not bit and not item['transparent'] and pixel!=item['background'])
               for bit,pixel in zip(ink,pixels)):
            self.counts['glyph_mismatches'] += 1
            return
        self.pages[key] = (item,pixels,ink)
        self.counts['glyph_verified'] += 1

    def scanout(self,page):
        # Copy references to immutable completed candidates. A later draw cannot
        # change the evidence assigned to a triple-buffer scanout slot.
        return tuple(value for key,value in self.pages.items() if key[0]==page)

    def present(self,candidates,raw,width,height,palette):
        if (width,height)!=(320,200) or not palette or len(palette)!=16: return []
        result=[]
        for item,pixels,ink in candidates:
            x,y,w,h=item['rect']
            rgb=bytes(channel for pixel in pixels for channel in palette[pixel])
            # Native libretro framebuffer is BGRX, palette records are RGB.
            actual=bytes(raw[((y+dy)*320+x+dx)*4+c] for dy in range(h) for dx in range(w) for c in (2,1,0))
            if rgb!=actual:
                self.counts['frame_mismatches'] += 1
                continue
            # Invisible same-colour ink cannot justify semantic disclosure.
            foreground=palette[item['foreground']]
            if not any(not bit and palette[pixel]!=foreground for bit,pixel in zip(ink,pixels)):
                self.counts['no_contrast'] += 1
                continue
            result.append(item | {'pixel_sha256':hashlib.sha256(actual).hexdigest(),
                'basis':'source glyphs and complete RGB rectangle match the presented original framebuffer'})
            self.counts['presented_runs'] += 1
        return result

    def report(self):
        return dict(self.counts)
