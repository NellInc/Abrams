import unittest
from tools.pc_materials import material_pattern, material_pixel


class MaterialTests(unittest.TestCase):
    def test_solid_span_uses_low_byte_without_unintended_black_dither(self):
        self.assertEqual(material_pattern([7, 7]), [7, 7, 7, 7])
        self.assertEqual(material_pattern([0x0102, 0x0102]), [2, 2, 2, 2])

    def test_original_parity_is_in_framebuffer_coordinates(self):
        self.assertEqual(material_pattern([0x0700, 0x0007]), [0, 7, 7, 0])
        self.assertEqual(material_pattern([0x0807, 0x0708]), [7, 8, 8, 7])
        self.assertEqual(material_pixel([0x0700, 0x0007], 32, 13), 7)
        self.assertEqual(material_pixel([0x0700, 0x0007], 33, 13), 0)


if __name__ == '__main__': unittest.main()
