import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
import wave

from tools.extract_genesis_samples import ROM_HASH, WAV_RATE, extract, fm_patch, sample_bytes, take

ROOT = Path(__file__).resolve().parents[1]
ROM = ROOT / "GENESIS/M-1 Abrams Battle Tank (USA, Europe).md"


class NativeSampleTests(unittest.TestCase):
    def test_sample_header_not_in_waveform(self):
        self.assertEqual(sample_bytes(struct.pack(">I", 4) + b"\x80\x90\x70\x80", 0), b"\x80\x90\x70\x80")

    def test_bad_lengths_and_banks_fail_closed(self):
        for length in (0, 65536, 999999):
            with self.subTest(length=length), self.assertRaises(ValueError):
                sample_bytes(struct.pack(">I", length), 0)
        with self.assertRaises(ValueError):
            sample_bytes(bytes(0x7FFA) + struct.pack(">I", 4) + bytes(4), 0x7FFA)
        with self.assertRaises(ValueError):
            sample_bytes(struct.pack(">I", 4) + bytes(3), 0)

    def test_bounds(self):
        for offset, size in ((-1, 1), (0, -1), (2, 3)):
            with self.subTest(offset=offset, size=size), self.assertRaises(ValueError):
                take(bytes(4), offset, size)

    def test_fm_register_mapping(self):
        patch = fm_patch(bytes(range(38)))
        registers = patch["channel_relative_registers"]
        self.assertEqual(registers["B0"], 2)
        self.assertEqual(registers["30"], 4)
        self.assertEqual(registers["40"], 5)
        self.assertEqual(registers["3C"], 22)
        self.assertEqual(registers["8C"], 27)
        self.assertEqual(registers["9C"], 0)
        self.assertEqual(patch["key_on_operator_mask"], 36)
        with self.assertRaises(ValueError):
            fm_patch(bytes(37))

    def test_wrong_rom_creates_no_output(self):
        with tempfile.TemporaryDirectory() as temp:
            source, output = Path(temp) / "wrong.bin", Path(temp) / "output"
            source.write_bytes(bytes(32))
            with self.assertRaisesRegex(ValueError, "Unsupported ROM"):
                extract(source, output)
            self.assertFalse(output.exists())

    @unittest.skipUnless(ROM.exists(), "Requires supplied local ROM")
    def test_all_native_assets_and_wav_payloads_equal_rom(self):
        source = ROM.read_bytes()
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "assets"
            manifest = extract(ROM, output)
            self.assertEqual(len(manifest["samples"]), 11)
            self.assertEqual(sum(b["patch_count"] for b in manifest["fm_banks"]), 25)
            self.assertEqual([len(s["tracks"]) for s in manifest["songs"]], [6, 4, 5, 5])
            self.assertEqual(len(manifest["effects"]), 19)
            for name, receipt in manifest["files"].items():
                raw = (output / name).read_bytes()
                self.assertEqual(hashlib.sha256(raw).hexdigest(), receipt["sha256"])
                if "rom_offset" in receipt:
                    self.assertEqual(raw, source[receipt["rom_offset"]:receipt["rom_offset"] + receipt["bytes"]])
            for sample in manifest["samples"]:
                with wave.open(str(output / "samples" / (sample["name"] + ".wav")), "rb") as reader:
                    self.assertEqual(reader.getparams()[:4], (1, 1, WAV_RATE, sample["sample_count"]))
                    self.assertEqual(reader.readframes(reader.getnframes()), sample_bytes(source, sample["header_offset"]))
            self.assertEqual(json.loads((output / "manifest.json").read_text()), manifest)
            with self.assertRaises(FileExistsError):
                extract(ROM, output)
        self.assertEqual(hashlib.sha256(ROM.read_bytes()).hexdigest(), ROM_HASH)
