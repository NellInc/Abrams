import unittest
from tools.pc_vehicle_math import IDENTITY, orientation_mode, object_matrix, compose, packed_axis_table, rotated_vector, primitive_camera_vertices


class VehicleMathTests(unittest.TestCase):
    def test_mode_depends_on_original_angle_priority(self):
        self.assertEqual([orientation_mode(x) for x in ([0,0,0], [0,0,1], [0,1,0], [1,0,0])], [0,1,2,3])

    def test_cardinal_yaw_preserves_original_axes(self):
        sine, cosine = [0] * 256, [0] * 256
        sine[64], cosine[0], cosine[128], sine[192] = 16384, 16384, -16384, -16384
        self.assertEqual(object_matrix([0,0,0], sine, cosine), IDENTITY)
        self.assertEqual(object_matrix([0,0,64], sine, cosine), [0,16384,0,-16384,0,0,0,0,16384])

    def test_composition_preserves_cx_quirk_in_yaw_branch(self):
        a, mode = compose(IDENTITY, 1, IDENTITY, 1, 0)
        b, _ = compose(IDENTITY, 1, IDENTITY, 1, 65535)
        self.assertEqual((a, mode), (IDENTITY, 1))
        self.assertEqual(b, [16387,3,0,3,16387,0,0,0,16384])
        self.assertEqual(compose(IDENTITY, 0, b, 3, 0), (b, 3))
        self.assertEqual(compose(IDENTITY, 3, IDENTITY, 3, 65535), (IDENTITY, 3))

    def test_packed_table_uses_staged_shift_and_symmetric_negation(self):
        table = packed_axis_table(-65)
        self.assertEqual(table[8], 0)
        self.assertEqual(table[16], -9)
        self.assertEqual(table[15], -7)
        self.assertEqual(table[7], 2)
        self.assertEqual(table[:8], [-x for x in reversed(table[9:])])

    def test_packed_rotated_vector_and_bounds(self):
        self.assertEqual(rotated_vector([0,8,16], True, 0, IDENTITY, 0), [-2048,0,2048])
        self.assertEqual(rotated_vector([0,8,16], True, 3, IDENTITY, 0), [-256,0,256])
        self.assertEqual(rotated_vector([123,-50,20], False, 0, IDENTITY, 0), [123,-50,20])
        with self.assertRaises(ValueError): rotated_vector([17,8,8], True, 0, IDENTITY, 0)

    def test_primitive_vertices_use_original_dynamic_and_static_translation_order(self):
        shape = {'vectors_i16le': [[0,8,16]], 'header_byte_2': 3}
        primitive = {'encoded_indices': [128]}
        context = {'static_path': 0, 'matrix': IDENTITY, 'matrix_mode': 0,
                   'packed_shift': 3, 'view_origin': [10,2000,30], 'world_delta': [10,2000,30]}
        self.assertEqual(primitive_camera_vertices(shape, primitive, context), [[-246,2000,286]])
        context['static_path'] = 1
        self.assertEqual(primitive_camera_vertices(shape, primitive, context), [[-246,2000,286]])


if __name__ == '__main__': unittest.main()
