"""Original vehicle drawing arithmetic, isolated from gameplay.

These helpers reproduce SIM's integer operations, including its register-
dependent fast matrix multiplication. They are research-only until the live
bridge captures that register at the actual drawing boundary.
"""
from __future__ import annotations
try:
    from tools.pc_render_state import signed16, transform
except ModuleNotFoundError:
    from pc_render_state import signed16, transform

IDENTITY = [16384, 0, 0, 0, 16384, 0, 0, 0, 16384]


def orientation_mode(angles):
    return 3 if angles[0] else 2 if angles[1] else 1 if angles[2] else 0


def object_matrix(angles, sine, cosine):
    """SIM 0b4d:0aa2, with the original tables supplied by the caller."""
    mode = orientation_mode(angles)
    if not mode:
        return IDENTITY.copy()
    sx, sy, sz = [sine[a] for a in angles]
    cx, cy, cz = [cosine[a] for a in angles]
    if mode == 1:
        return [cz, sz, 0, signed16(-sz), cz, 0, 0, 0, 16384]
    mul = lambda a, b: signed16(a * b >> 14)
    cc, cs, sc, ss = mul(cy, cz), mul(cy, sz), mul(sy, cz), mul(sy, sz)
    return list(map(signed16, [cc - mul(sx, ss), cs + mul(sx, sc), mul(-cx, sy),
                              mul(-cx, sz), mul(cx, cz), sx,
                              sc + mul(sx, cs), ss - mul(sx, cc), mul(cx, cy)]))


def compose(object_basis, object_mode, camera_basis, camera_mode, incoming_cx):
    """SIM 0b4d:0c6e. CX is required evidence, never silently assumed zero.

The yaw-specialized branches contain MOV AX,CX where the general branch stores
MOV CX,AX. Therefore they replace the first product's low word with incoming CX.
This is an observed original arithmetic quirk, not a corrected matrix product.
"""
    if object_mode == 0:
        return camera_basis.copy(), camera_mode
    if camera_mode == 0:
        return object_basis.copy(), object_mode
    result = []
    for col in range(3):
        for row in range(3):
            if object_mode == 1 and col == 2:
                result.append(camera_basis[6 + row])
            elif camera_mode == 1 and row == 2:
                result.append(object_basis[col * 3 + 2])
            else:
                products = [object_basis[col * 3 + k] * camera_basis[k * 3 + row] for k in range(3)]
                if object_mode == 1 or camera_mode == 1:
                    value = ((products[0] >> 16) << 16) + (incoming_cx & 65535) + products[1]
                else:
                    value = sum(products)
                result.append(signed16(value >> 14))
    return result, 1 if object_mode == camera_mode == 1 else 3


def packed_axis_table(coefficient):
    """SIM 0b4d:1e49's 17 entries, preserving staged arithmetic shifts."""
    eighth = coefficient >> 3
    sixteenth, thirty_second, sixty_fourth = eighth >> 1, eighth >> 2, eighth >> 3
    positive = [0, sixty_fourth, thirty_second, thirty_second + sixty_fourth,
                sixteenth, sixteenth + sixty_fourth, sixteenth + thirty_second,
                eighth - sixty_fourth, eighth]
    return [signed16(-v) for v in reversed(positive[1:])] + positive


def rotated_vector(raw_vector, packed, shift, matrix, mode):
    """Dynamic packed lookup path differs from an ordinary float rotation."""
    if not packed:
        return transform(raw_vector, matrix, mode)
    if any(not 0 <= v <= 16 for v in raw_vector):
        raise ValueError("packed dynamic coordinate exceeds verified lookup table")
    return [signed16(sum(packed_axis_table(matrix[j * 3 + i])[raw_vector[j]]
                         for j in range(3))) >> shift for i in range(3)]


def primitive_camera_vertices(shape, primitive, context):
    """Use an observed original drawing context, including the actual matrix."""
    try:
        from tools.inspect_shapes import primitive_vertices
    except ModuleNotFoundError:
        from inspect_shapes import primitive_vertices
    if context['static_path']:
        return [transform([signed16(a + b) for a, b in zip(vertex, context['world_delta'])],
                          context['matrix'], context['matrix_mode'])
                for vertex in primitive_vertices(shape, primitive)]
    result = []
    for encoded in primitive['encoded_indices']:
        rotated = rotated_vector(shape['vectors_i16le'][encoded & 127], bool(encoded & 128),
                                 context['packed_shift'], context['matrix'], context['matrix_mode'])
        result.append([signed16(a + b) for a, b in zip(rotated, context['view_origin'])])
    return result
