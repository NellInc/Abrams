"""Original EGA span colours, derived from SIM's material lookup words.

This models colour choice only, not polygon coverage, clipping or VGA timing.
"""
import struct


def read_materials(ram, ds):
    return [list(pair) for pair in zip(struct.unpack_from('<32H', ram, ds + 0x43A6),
                                      struct.unpack_from('<32H', ram, ds + 0x4626))]


def material_pixel(words, x, y):
    first, second = words
    if first == second:  # original solid-span dispatch uses AL only
        return first & 15
    word = first if y & 1 else second  # 59fd toggles the initial y parity
    return (word >> (0 if x & 1 else 8)) & 15


def material_pattern(words):
    return [material_pixel(words, x, y) for y in range(2) for x in range(2)]
