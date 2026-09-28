import random
import unittest
from unittest.mock import patch
from tools.pc_live_state import SimStateReader
from tools.pc_render_trace import Collector, INVALID_DRIVER_HIGH


def original_driver_mask(raw, ui):
    low, high, mask = raw[0::3], raw[1::3], raw[2::3]
    if not Collector.binary_mask(mask) or high.translate(INVALID_DRIVER_HIGH).count(1):
        return False
    if Collector.outside_ui(mask, ui):
        return False
    offsets = int.from_bytes(low, 'little') | int.from_bytes(high, 'little')
    return not (offsets & ~int.from_bytes(mask, 'little'))


class PerformanceExactnessTests(unittest.TestCase):
    def reader(self):
        reader = SimStateReader.__new__(SimStateReader)
        reader.anchors = [(0, b'first-anchor'), (32, b'second-anchor'), (64, b'third-anchor')]
        reader._located_ram = reader._located_base = None
        return reader

    def snapshot(self, reader, bases=(4096,)):
        ram = bytearray(655360)
        for base in bases:
            for offset, anchor in reader.anchors:
                ram[base+offset:base+offset+len(anchor)] = anchor
        return bytes(ram)

    def test_only_same_exact_immutable_object_reuses_scan(self):
        reader = self.reader(); ram = self.snapshot(reader)
        with patch.object(reader, '_locate_snapshot', wraps=reader._locate_snapshot) as scan:
            self.assertEqual(reader.locate(ram), 4096)
            self.assertEqual(reader.locate(ram), 4096)
            self.assertEqual(scan.call_count, 1)
            equal_copy = bytes(bytearray(ram))
            self.assertIsNot(equal_copy, ram)
            self.assertEqual(reader.locate(equal_copy), 4096)
            self.assertEqual(scan.call_count, 2)

    def test_mutable_buffer_and_subclass_never_reuse(self):
        reader = self.reader(); raw = self.snapshot(reader)
        class CustomBytes(bytes): pass
        for ram in (bytearray(raw), CustomBytes(raw)):
            with patch.object(reader, '_locate_snapshot', wraps=reader._locate_snapshot) as scan:
                reader.locate(ram); reader.locate(ram)
                self.assertEqual(scan.call_count, 2)
        changed = bytearray(raw); reader.locate(changed); changed[4096] ^= 1
        self.assertIsNone(reader.locate(changed))

    def test_different_snapshot_rechecks_mutation_and_ambiguity(self):
        reader = self.reader(); raw = self.snapshot(reader)
        reader.locate(raw)
        altered = bytearray(raw); altered[4096+32] ^= 1
        self.assertIsNone(reader.locate(bytes(altered)))
        with self.assertRaisesRegex(ValueError, 'ambiguous'):
            reader.locate(self.snapshot(reader, (4096, 8192)))
        self.assertEqual(reader.locate(raw), 4096)
        with self.assertRaises(ValueError): reader.locate(raw[:-1])

    def test_empty_driver_exactness_for_every_ui_byte(self):
        raw = bytes(192000)
        for value in range(256):
            ui = bytes([value])*64000
            self.assertEqual(Collector.safe_driver_mask(raw, ui), original_driver_mask(raw, ui))
        with patch.object(Collector, 'outside_ui', side_effect=AssertionError('slow path')):
            self.assertTrue(Collector.safe_driver_mask(raw, bytes(64000)))

    def test_driver_mutations_and_dimensions_still_match_prior_predicate(self):
        randomizer = random.Random(20260928)
        for size in (0, 3, 191997, 192000, 192003):
            raw = bytearray(size)
            for iteration in range(30):
                if size: raw[randomizer.randrange(size)] = randomizer.randrange(256)
                ui = bytes([randomizer.choice((0, 1, 254, 255))])*((size+2)//3)
                self.assertEqual(Collector.safe_driver_mask(bytes(raw), ui), original_driver_mask(bytes(raw), ui))
        for channel in range(3):
            for value in range(1, 256):
                raw = bytearray(192000); raw[90000+channel] = value
                ui = bytes([255])*64000
                self.assertEqual(Collector.safe_driver_mask(bytes(raw), ui), original_driver_mask(bytes(raw), ui))


if __name__ == '__main__': unittest.main()
