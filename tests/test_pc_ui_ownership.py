import unittest
from tools.verify_pc_ui_ownership import verify


class UiOwnershipTests(unittest.TestCase):
    def test_native_observer_against_bitwise_reference(self):
        result = verify()
        self.assertEqual(result['operations'], 4096)
        self.assertEqual(result['plane_bits_checked'], 131072)
        self.assertEqual(result['pixel_unions_checked'], 32768)
        self.assertEqual(result['bitmap_cases'], 16)
        self.assertEqual(result['bitmap_pixels_checked'], 2048000)


if __name__ == '__main__': unittest.main()
