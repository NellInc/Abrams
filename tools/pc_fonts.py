"""Original PC fixed-cell font storage and loaded-font identity.

Headers, not filenames, define cell width/height. 8X6.FNT actually declares an
8 by 8 cell; VM.FNT and 6X6.FNT contain identical bytes in the supplied package.
"""
import hashlib
import struct

FONT_NAMES = ('6X6.FNT','8X6.FNT','8X8.FNT','STENCIL.FNT','VM.FNT')


def decode_font(data):
    if len(data) < 4: raise ValueError('truncated font header')
    width,height,first,count = data[:4]
    if not 1 <= width <= 16 or not 1 <= height <= 32 or not count or first+count > 256:
        raise ValueError('unsupported font dimensions or character range')
    stride = (width+7)//8
    if len(data) != 4 + count*height*stride: raise ValueError('font payload length differs from header')
    glyphs = []
    for index in range(count):
        at = 4+index*height*stride
        glyphs.append([1 if data[at+y*stride+x//8] & (128>>(x&7)) else 0
                       for y in range(height) for x in range(width)])
    return {'width':width,'height':height,'first':first,'count':count,'stride':stride,
            'glyphs':glyphs,'sha256':hashlib.sha256(data).hexdigest()}


def loaded_font(ram, ds, catalog, fields=(0x364E,0x3662,0x3676,0x368A,0x369E)):
    width,height,first,count = (ram[ds+at] for at in fields[:4])
    segment, = struct.unpack_from('<H',ram,ds+fields[4])
    size = ((width+7)//8)*height*count
    at = segment*16
    if not segment or at+size > len(ram): raise ValueError('loaded font payload outside RAM')
    raw = bytes([width,height,first,count])+ram[at:at+size]
    font=decode_font(raw)
    matches=[name for name,data in catalog.items() if data==raw]
    if not matches: raise ValueError('loaded font differs from supplied native resources')
    return font | {'sources':sorted(matches),'segment':segment}


def rendered_glyph(font, code):
    if not 0 <= code <= 255: raise ValueError('character must be a byte')
    signed = lambda value: value if value < 128 else value-256
    index=(code-font['first'])&255
    # The original uses signed JL after both SUB AL,first and CMP AL,count.
    # In the supplied 8X8 font this rejects stored codes 128 through 136.
    if signed(code) < signed(font['first']) or signed(index) >= signed(font['count']): return None
    if index >= len(font['glyphs']): raise ValueError('unsupported signed font range')
    return font['glyphs'][index]


def text_pixels(font, text):
    if not isinstance(text,bytes) or not text or b'\0' in text: raise ValueError('nonempty unterminated font text required')
    width=font['width']*len(text)
    pixels=bytearray(width*font['height'])
    for i,code in enumerate(text):
        glyph=rendered_glyph(font,code)
        if glyph is None: raise ValueError('original font driver rejects character')
        for y in range(font['height']):
            start=y*width+i*font['width']
            pixels[start:start+font['width']]=bytes(glyph[y*font['width']:(y+1)*font['width']])
    return width,font['height'],bytes(pixels)
