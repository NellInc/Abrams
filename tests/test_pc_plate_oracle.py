import unittest
from tools.pc_plate_oracle import PlateVga


class PlateObserverTests(unittest.TestCase):
    def test_indexed_ports_and_plane_select(self):
        vga = PlateVga()
        before = [bytes(p) for p in vga.planes]
        vga.out(0x3CE, 2, 0x0005)
        vga.out(0x3C4, 1, 2)
        vga.out(0x3C5, 1, 4)
        vga.write(0xA2000, 1, 0xA5)
        self.assertEqual(vga.planes[2][8192], 0xA5)
        for p in (0, 1, 3): self.assertEqual(vga.planes[p], before[p])
        self.assertEqual(vga.planes[2][:8192], before[2][:8192])
        self.assertEqual(vga.planes[2][8193:], before[2][8193:])

    def test_latch_and_bit_mask(self):
        vga = PlateVga()
        vga.out(0x3CE, 2, 0x0005)
        vga.out(0x3CE, 2, 0x0204)
        latched = [p[0] for p in vga.planes]
        self.assertEqual(vga.read(0xA0000, 1), latched[2])
        vga.out(0x3CE, 2, 0x0F08)
        vga.write(0xA0001, 1, 0x05)
        self.assertEqual([p[1] for p in vga.planes], [(v & 0xF0) | 5 for v in latched])

    def test_unsupported_operations_fail_closed(self):
        vga = PlateVga()
        for port, size, value in ((0x3C5, 2, 1), (0x3CE, 2, 7), (0x3C4, 1, 1), (0x3C5, 1, 16)):
            with self.subTest(operation=(port,size,value)), self.assertRaises(ValueError):
                vga.out(port, size, value)
        for at, size in ((0x9FFFF,1), (0xB0000,1), (0xA0000,2)):
            with self.assertRaises(ValueError): vga.read(at,size)
            with self.assertRaises(ValueError): vga.write(at,size,0)
        with self.assertRaisesRegex(ValueError, 'pipeline'): vga.write(0xA0000,1,0)


if __name__ == '__main__': unittest.main()
