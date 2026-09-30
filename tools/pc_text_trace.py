"""Read-only, source-verified PC text runs paired with actual presented pixels.

This supplies visible text metadata only. It is not a message-occurrence detector,
voice scheduler or permission to expose queued messages from current guest RAM.
"""
from collections import Counter, OrderedDict
import hashlib
import struct
try:
    from tools.pc_pixel_bytes import BgrxRectProof, indexed_rgb
    from tools.pc_fonts import FONT_NAMES, loaded_font, text_pixels
    from tools.pc_message_events import MessageAssignments
except ModuleNotFoundError:
    from pc_pixel_bytes import BgrxRectProof, indexed_rgb
    from pc_fonts import FONT_NAMES, loaded_font, text_pixels
    from pc_message_events import MessageAssignments

# Every source main-CS far CALL to the original string wrapper.
TEXT_CALLS = (0x144b,0x3f1d,0x3f58,0x400d,0x4053,0x5345,0x5359,0x5379,0x538d,0x5456,0x546a,0x5483,0x54a0,0x551c,0x55b9,0x55df,0x5764,0x57a2,0x58cd,0x595a,0x59a8,0x59d4,0x62ed,0x6333,0x6347,0x635b,0x63f5,0x6409,0x641d,0x67c4,0x680d,0x6836,0x6dfe,0x6e70,0x6e93,0x6eb6,0x6ed9,0x6efc,0x6f1f,0x7f01,0x7f50,0x7fa7,0x809e,0x80b2,0x831c,0x8330,0x8349,0x88cf,0x88e2)
MAX_CANDIDATES = 256
MAX_RGB_PROOFS = 128
CALLERS = {0x3F1D: 'crew_primary', 0x3F58: 'crew_secondary',
           0x400D: 'radio', 0x55DF: 'weapon_status'}
CALLERS = {caller: CALLERS.get(caller,'instrument') for caller in TEXT_CALLS}


class TextRuns:
    def __init__(self, source, profile=None):
        self.catalog = {name: (source/name).read_bytes() for name in FONT_NAMES}
        self.profile = profile
        self.pages = {}
        self.pending = None
        self.sequence = 0
        self.messages = MessageAssignments()
        self.counts = Counter()
        # Expected pixels only. Every presented rectangle is still read and
        # compared in full, including on a warm hit. No event/item is retained.
        self.rgb_proofs = OrderedDict()

    def begin(self, ram, regs):
        if len(ram) != 640*1024: raise ValueError('invalid native text entry snapshot')
        if self.pending is not None: raise ValueError('nested native text observation')
        ds, stack = regs['ds']*16, regs['ss']*16+regs['sp']
        if ds+65536 > len(ram) or stack+10 > len(ram): raise ValueError('invalid native text segments')
        caller, cs, pointer, x, y = struct.unpack_from('<5H',ram,stack)
        p = self.profile or {'ds':0x19E0,'wrapper':0xF8D,'driver':0x1388,
                            'driver_ip':0x68,'foreground':0x3590,'callers':CALLERS}
        fg = p['foreground']
        if caller not in p['callers'] or regs['ds'] != cs+p['ds'] or regs['cs'] != cs+p['wrapper']:
            raise ValueError('unknown original text caller')
        page = (struct.unpack_from('<H',ram,ds+fg+0x18)[0]-0xA000)*16
        key = (page, caller, x, y)
        self.pages.pop(key,None)
        self.pending = (key,None)
        self.counts['entries'] += 1
        self.sequence += 1
        # Unsupported legitimate source text stays original-only. Never invent
        # glyphs, clip a label, or reuse the previous label after a failed draw.
        try:
            font = loaded_font(ram,ds,self.catalog,tuple(fg+v for v in (0xBE,0xD2,0xE6,0xFA,0x10E)))
            if struct.unpack_from('<HH',ram,ds+fg+0x24) != (p['driver_ip'],cs+p['driver']):
                raise ValueError('unsupported character driver')
            end = ram.find(b'\0',ds+pointer,min(ds+65536,ds+pointer+321))
            if end < 0: raise ValueError('unterminated original text')
            text = ram[ds+pointer:end]
            width,height,ink = text_pixels(font,text)
            if page not in (0,8192) or x+width>320 or y+height>200:
                raise ValueError('unsupported text rectangle')
            foreground,background = [struct.unpack_from('<H',ram,ds+fg+0x1316+2*ram[ds+at])[0]&255
                                     for at in (fg,fg+1)]
            mode = ram[ds+fg+2]
            if foreground>15 or background>15 or mode not in (0,1):
                raise ValueError('unsupported text colors')
            item = {'kind':p['callers'][caller], 'return_ip':caller,'source_pointer':pointer,
                    'text':text.decode('cp437'), 'draw_sequence':self.sequence, 'rect':[x,y,width,height], 'page_offset':page,
                    'font_sha256':font['sha256'],'font_sources':font['sources'],
                    'cell_size':[font['width'],font['height']],
                    'foreground':foreground,'background':background,'transparent':bool(mode),
                    'speaker':ram[ds+0x6464] if self.profile is None and caller in (0x3F1D,0x3F58) else None}
            if self.profile is None: self.messages.bind(item,text)
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
        if [x,y,width,height]!=item['rect'] or (page,caller)!=key[:2]:
            raise ValueError('native text entry/return differ')
        if any((bit and pixel!=item['foreground']) or
               (not bit and not item['transparent'] and pixel!=item['background'])
               for bit,pixel in zip(ink,pixels)):
            self.counts['glyph_mismatches'] += 1
            return
        self.counts['glyph_verified'] += 1
        if not any(ink):
            self.counts['blank_glyph_verified'] += 1
            return  # Actual clearing draw, never a visible replacement label.
        self.pages[key] = (item,pixels,ink)
        while len(self.pages)>MAX_CANDIDATES:
            del self.pages[next(iter(self.pages))]
            self.counts['candidate_evictions'] += 1

    def scanout(self,page):
        # Copy references to immutable completed candidates. A later draw cannot
        # change the evidence assigned to a triple-buffer scanout slot.
        return tuple(value for key,value in self.pages.items() if key[0]==page)

    def present(self,candidates,raw,width,height,palette):
        if (width,height)!=(320,200) or not palette or len(palette)!=16: return []
        result=[]
        palette_key = None
        for item,pixels,ink in candidates:
            x,y,w,h=item['rect']
            if palette_key is None: palette_key = tuple(tuple(color) for color in palette)
            key = (bytes(pixels), bytes(ink), item['foreground'], palette_key, tuple(item['rect']))
            proof = self.rgb_proofs.get(key)
            if proof is None:
                rgb = indexed_rgb(pixels,palette)
                proof = [rgb, None, BgrxRectProof(rgb,width,height,(x,y,w,h))]
                self.rgb_proofs[key] = proof
                if len(self.rgb_proofs) > MAX_RGB_PROOFS: self.rgb_proofs.popitem(last=False)
            else: self.rgb_proofs.move_to_end(key)
            rgb = proof[0]
            # Native libretro framebuffer is BGRX, palette records are RGB.
            if not proof[2].matches(raw):
                self.counts['frame_mismatches'] += 1
                continue
            # Invisible same-colour ink cannot justify semantic disclosure.
            if proof[1] is None:
                foreground=palette[item['foreground']]
                contrast=any(not bit and palette[pixel]!=foreground for bit,pixel in zip(ink,pixels))
                backgrounds={tuple(palette[pixel]) for bit,pixel in zip(ink,pixels) if not bit}
                uniform=next(iter(backgrounds)) if len(backgrounds)==1 else None
                proof[1] = (contrast, uniform, hashlib.sha256(rgb).hexdigest())
            contrast, uniform, digest = proof[1]
            if not contrast:
                self.counts['no_contrast'] += 1
                continue
            # Fresh public lists keep caller mutation out of the immutable proof.
            result.append(item | {'uniform_background_rgb':list(uniform) if uniform is not None else None, 'pixel_sha256':digest,
                'basis':'source glyphs and complete RGB rectangle match the presented original framebuffer'})
            self.counts['presented_runs'] += 1
        return result

    def report(self):
        return dict(self.counts)
