from pathlib import Path
import struct
import unittest

from tools.unpack_pc_executables import decode_runs, unpack, compare_independent

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {
    "START": (115216, 575, "320403fc499f749bda64f325db2946983065bb881db008060b7e69dcac9e834a"),
    "BRIEF": (62896, 362, "d52b3dca7ee9d2cfd265b991ad08961139c4ed3bbeed932ba9701c882e2a8aee"),
    "SIM": (129712, 671, "33f5f41dd5f5579d29cccc7e2f6f6942a9463883afca0c3a838c1b6ccc321eea"),
    "END": (89008, 386, "88dc9bdd539c03212d16765b2dac4f38567892b84656823768b09654c913e64f"),
}


class PcExecutableTests(unittest.TestCase):
    def test_original_corpus_matches_independent_decoded_hashes(self):
        for name, (size, count, digest) in EXPECTED.items():
            with self.subTest(name=name):
                path = ROOT / f"GAME/{name}.EXE"
                original = path.read_bytes()
                decoded, report = unpack(original)
                self.assertEqual(len(decoded), size)
                self.assertEqual(len(report["relocations"]), count)
                self.assertEqual(report["decoded_sha256"], digest)
                self.assertEqual(path.read_bytes(), original)
                self.assertEqual(unpack(original), (decoded, report))

    def test_fill_copy_prefix_and_padding(self):
        # Terminal fill, then a literal copy, read from right to left.
        packed = b"PREFIX" + b"A\x20\x00\xb1" + b"xyz\x03\x00\xb2" + b"\xff" * 9
        decoded, report = decode_runs(packed, 41)
        self.assertEqual(decoded, b"PREFIX" + b"A" * 32 + b"xyz")
        self.assertEqual(report["prefix_bytes"], 6)
        self.assertEqual(report["padding_bytes"], 9)
        self.assertEqual([r["opcode"] for r in report["commands"]], [0xB2, 0xB1])

    def test_malformed_runs(self):
        cases = [
            (b"", 1), (b"abc", 2), (b"a\x01\x00\xb1", 2**21),
            (b"xx\x01\x00\xff", 5), (b"a\xff\xff\xb1", 8),
            (b"\xff\x00\xb3", 8), (b"a\x04\x00\xb0", 8),
            (b"a\x01\x00\xb1", 8), (b"abc\x01\x00\xb3", 6),
        ]
        for packed, size in cases:
            with self.subTest(packed=packed, size=size), self.assertRaises(ValueError):
                decode_runs(packed, size)

    def test_truncated_and_unsupported_executable(self):
        original = (ROOT / "GAME/SIM.EXE").read_bytes()
        for size in (0, 2, 27, 512, len(original) - 1):
            with self.subTest(size=size), self.assertRaises(ValueError):
                unpack(original[:size])
        for offset, value in ((0, 0), (6, 1), (20, 18), (26, 1), (0x1D300, 0x90)):
            bad = bytearray(original)
            bad[offset] = value
            with self.subTest(offset=offset), self.assertRaises(ValueError):
                unpack(bytes(bad))

    def test_bad_relocations_and_metadata(self):
        original = (ROOT / "GAME/BRIEF.EXE").read_bytes()
        for offset, value in ((0xDBE0 + 14, 0), (0xDBE0 + 6, 100),
                              (0xDBE0 + 0x125, 65535),
                              (0xDBE0 + 0x125 + 2, 65535)):
            bad = bytearray(original)
            struct.pack_into("<H", bad, offset, value)
            with self.subTest(offset=offset), self.assertRaises(ValueError):
                unpack(bytes(bad))

    def test_independent_comparison_checks_all_claims(self):
        decoded, report = unpack((ROOT / "GAME/BRIEF.EXE").read_bytes())
        relocs = b"".join(struct.pack("<HH", r["offset"], r["segment"])
                          for r in report["relocations"])
        header_size = (28 + len(relocs) + 15) // 16 * 16
        h = [0x5A4D, 0, 0, len(report["relocations"]), header_size // 16, 0, 0,
             report["stack"]["ss"], report["stack"]["sp"], 0,
             report["entry"]["ip"], report["entry"]["cs"], 28, 0]
        fixture = struct.pack("<14H", *h) + relocs
        fixture += bytes(header_size - len(fixture)) + decoded
        compare_independent(decoded, report, fixture)
        for offset in (14, 20, 28, header_size + 4):
            bad = bytearray(fixture)
            bad[offset] ^= 1
            with self.subTest(offset=offset), self.assertRaises(ValueError):
                compare_independent(decoded, report, bytes(bad))


if __name__ == "__main__":
    unittest.main()
