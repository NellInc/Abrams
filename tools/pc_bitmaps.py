"""Original packed PC bitmap resources and loaded EGA planar descriptors.

Pixel storage only. Bitmap selection, positioning and timing remain original.
"""
import struct


def decode_bitmaps(data):
    if len(data) < 2: raise ValueError('truncated bitmap directory')
    count, = struct.unpack_from('<H', data)
    if not 1 <= count <= 256 or len(data) < 2 + count * 4:
        raise ValueError('invalid bitmap directory')
    widths = struct.unpack_from(f'<{count}H', data, 2)
    heights = struct.unpack_from(f'<{count}H', data, 2 + count * 2)
    result, at = [], 2 + count * 4
    for index, (half_width, height) in enumerate(zip(widths, heights)):
        if not 1 <= half_width <= 160 or not 1 <= height <= 200:
            raise ValueError('unsupported bitmap dimensions')
        end = at + half_width * height
        if end > len(data): raise ValueError('truncated bitmap pixels')
        pixels = [color for byte in data[at:end] for color in (byte >> 4, byte & 15)]
        result.append({'index': index, 'width': half_width * 2, 'height': height,
                       'pixels': pixels, 'offset': at})
        at = end
    if at != len(data): raise ValueError('unparsed bitmap tail')
    return result


def read_ega_bitmap(ram, ds, descriptor):
    at = ds + descriptor
    if at < 0 or at + 10 > len(ram): raise ValueError('bitmap descriptor outside RAM')
    segment, offset, mask, width, height, flags = struct.unpack_from('<HHHBBH', ram, at)
    if not width or width % 8 or not height:
        raise ValueError('unsupported loaded EGA bitmap dimensions')
    stride = width // 8
    plane_size = stride * height
    start = segment * 16 + offset
    mask_start = segment * 16 + mask
    if mask_start != start + plane_size * 4 or mask_start + plane_size > len(ram):
        raise ValueError('unsupported loaded EGA bitmap layout')
    pixels, opaque = [], []
    for y in range(height):
        for x in range(width):
            byte, bit = y * stride + x // 8, 128 >> (x & 7)
            pixels.append(sum((1 << plane) if ram[start + plane * plane_size + byte] & bit else 0
                              for plane in range(4)))
            opaque.append(not bool(ram[mask_start + byte] & bit))
    return {'width': width, 'height': height, 'pixels': pixels, 'opaque': opaque, 'flags': flags}


def verify_loaded_effects(ram, ds, images):
    table, = struct.unpack_from('<H', ram, ds + 0x358E)
    if not table: raise ValueError('original effects table is not loaded')
    result = []
    for source in images:
        descriptor, = struct.unpack_from('<H', ram, ds + table + source['index'] * 2)
        loaded = read_ega_bitmap(ram, ds, descriptor)
        if any(loaded[k] != source[k] for k in ('width', 'height', 'pixels')):
            raise ValueError(f'original loaded effect differs: {source["index"]}')
        if loaded['opaque'] != [p != 0 for p in source['pixels']]:
            raise ValueError(f'original effect transparency differs: {source["index"]}')
        result.append(loaded | {'index': source['index'], 'descriptor': descriptor})
    return result
