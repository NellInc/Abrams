import unittest
from tools.verify_pc_plate_ownership import verify


class PlateOwnershipTests(unittest.TestCase):
    def test_native_conservative_tags_against_per_bit_model(self):
        result = verify()
        self.assertEqual(result['operations'],4096)
        self.assertEqual(result['plane_bits_checked'],131072)
        self.assertEqual(result['explicit_page_plate_cases'],23)


if __name__ == '__main__': unittest.main()
