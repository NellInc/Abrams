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
