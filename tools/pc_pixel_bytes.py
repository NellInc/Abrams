"""Bulk equivalents of the original presentation observers' byte comparisons.

No tolerance, colour key, skipped pixels or guest memory access is introduced.
"""


def bgrx_rect_rgb(raw, width, height, rect):
    x, y, w, h = rect
    if (any(type(n) is not int for n in (width, height, x, y, w, h))
            or width <= 0 or height <= 0 or min(x, y, w, h) < 0
            or x+w > width or y+h > height or len(raw) != width*height*4):
        raise ValueError('invalid packed BGRX crop')
    rows = b''.join(raw[((y+row)*width+x)*4:((y+row)*width+x+w)*4]
                    for row in range(h))
    rgb = bytearray(w*h*3)
    rgb[0::3], rgb[1::3], rgb[2::3] = rows[2::4], rows[1::4], rows[0::4]
    return bytes(rgb)


def indexed_rgb(pixels, palette):
    if len(palette) != 16 or any(len(color) != 3 for color in palette) or max(pixels, default=0) > 15:
        raise ValueError('invalid EGA indexed RGB data')
    rgb = bytearray(len(pixels)*3)
    for channel in range(3):
        table = bytes(color[channel] for color in palette) + bytes(240)
        rgb[channel::3] = pixels.translate(table)
    return bytes(rgb)


class BgrxRectProof:
    """Exact RGB target with compiled row ranges and independent BGR bit lanes.

    Every match reads all current RGB bits. The fourth native byte is padding,
    exactly as in bgrx_rect_rgb. No digest or prior match grants a hit.
    """
    def __init__(self, rgb, width, height, rect):
        x, y, w, h = rect
        if (any(type(n) is not int for n in (width, height, x, y, w, h))
                or width <= 0 or height <= 0 or min(x, y, w, h) < 0
                or x+w > width or y+h > height):
            raise ValueError('invalid packed BGRX crop')
        self.length = width*height*4
        self.complete = len(rgb) == w*h*3
        self.rows = tuple((((y+row)*width+x)*4, ((y+row)*width+x+w)*4) for row in range(h))
        if self.complete:
            encoded = bytearray(w*h*4)
            encoded[0::4], encoded[1::4], encoded[2::4] = rgb[2::3], rgb[1::3], rgb[0::3]
            self.value = int.from_bytes(encoded, 'little')
            self.mask = int.from_bytes(b'\xff\xff\xff\x00'*(w*h), 'little')

    def matches(self, raw):
        if len(raw) != self.length:
            raise ValueError('invalid packed BGRX crop')
        if not self.complete:
            return False
        cropped = b''.join(raw[a:b] for a,b in self.rows)
        return int.from_bytes(cropped, 'little') & self.mask == self.value
