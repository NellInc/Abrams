import ctypes as C
import hashlib
import json
import math
from pathlib import Path
import struct
import tempfile
import unittest
import wave

from tools.extract_genesis_audio import WaveSink, audio_metrics, parse_sequence
from tools.genesis_capture import ReferenceCore

ROOT = Path(__file__).resolve().parents[1]


class AudioSequenceTests(unittest.TestCase):
    def test_timed_inputs(self):
        self.assertEqual(parse_sequence("30,10+a+up,320"),
                         [(30, []), (10, ["a", "up"]), (320, [])])

    def test_invalid_inputs_and_duration_limit(self):
        for value in ("", "0", "-1", "36001", "36000,1", "1+fire", "1+", "2.5"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                parse_sequence(value)


class WaveSinkTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / "capture.wav"

    def tearDown(self):
        self.temp.cleanup()

    def test_exact_samples_channels_and_rate(self):
        sink = WaveSink(self.path, 44100)
        sink.write(struct.pack("=hhhh", -32768, 32767, -1234, 5678))
        sink.write(struct.pack("=hh", 0, 1))
        self.assertEqual(sink.frames, 3)
        sink.close()
        with wave.open(str(self.path), "rb") as reader:
            self.assertEqual(reader.getparams()[:4], (2, 2, 44100, 3))
            self.assertEqual(reader.readframes(3),
                             struct.pack("<hhhhhh", -32768, 32767, -1234, 5678, 0, 1))

    def test_incomplete_stereo_frame_rejected(self):
        sink = WaveSink(self.path, 44100)
        try:
            with self.assertRaises(ValueError):
                sink.write(b"\x00\x01")
            self.assertEqual(sink.frames, 0)
        finally:
            sink.close()

    def test_no_overwrite(self):
        self.path.write_bytes(b"original")
        with self.assertRaises(FileExistsError):
            WaveSink(self.path, 44100)
        self.assertEqual(self.path.read_bytes(), b"original")

    def test_invalid_sample_rates_do_not_create_file(self):
        for value in (0, 7999, 192001, 44100.5, math.nan, math.inf):
            with self.subTest(rate=value), self.assertRaises(ValueError):
                WaveSink(self.path, value)
            self.assertFalse(self.path.exists())

    def test_metrics_and_saturation_count(self):
        sink = WaveSink(self.path, 48000)
        sink.write(struct.pack("=hhhh", -32768, 32767, 0, 0))
        sink.close()
        metrics = audio_metrics(self.path)
        self.assertEqual(metrics["sample_frames"], 2)
        self.assertEqual(metrics["nonzero_samples"], 2)
        self.assertEqual(metrics["samples_at_integer_limits"], 2)
        self.assertEqual(metrics["peak_integer"], 32768)
        self.assertEqual(metrics["peak_dbfs"], 0)
        self.assertAlmostEqual(metrics["duration_seconds"], 2 / 48000)
        self.assertEqual(metrics["sha256"], hashlib.sha256(self.path.read_bytes()).hexdigest())

    def test_silence_is_reported_without_invalid_decibels(self):
        sink = WaveSink(self.path, 44100)
        sink.write(bytes(8))
        sink.close()
        metrics = audio_metrics(self.path)
        self.assertEqual(metrics["nonzero_samples"], 0)
        self.assertIsNone(metrics["peak_dbfs"])
        self.assertIsNone(metrics["rms_dbfs"])

    def test_empty_and_truncated_recordings_rejected(self):
        sink = WaveSink(self.path, 44100)
        sink.close()
        with self.assertRaisesRegex(ValueError, "Empty or truncated"):
            audio_metrics(self.path)
        self.path.unlink()
        sink = WaveSink(self.path, 44100)
        sink.write(bytes(40))
        sink.close()
        self.path.write_bytes(self.path.read_bytes()[:-4])
        with self.assertRaisesRegex(ValueError, "Empty or truncated"):
            audio_metrics(self.path)


class AudioCallbackTests(unittest.TestCase):
    def setUp(self):
        # Test the callback boundary without requiring a native emulator library.
        self.core = ReferenceCore.__new__(ReferenceCore)
        self.core.audio_error = None
        self.received = []
        self.core.audio_sink = self.received.append

    def test_single_stereo_sample(self):
        self.core._audio_sample(-12, 34)
        self.assertEqual(self.received, [struct.pack("=hh", -12, 34)])

    def test_batch_frames_are_stereo_pairs(self):
        raw = struct.pack("=hhhh", -12, 34, 56, -78)
        buffer = C.create_string_buffer(raw)
        self.assertEqual(self.core._audio_batch(buffer, 2), 2)
        self.assertEqual(self.received, [raw])

    def test_disabled_sink_does_not_dereference_audio(self):
        self.core.audio_sink = None
        self.assertEqual(self.core._audio_batch(None, 123), 123)
        self.assertEqual(self.received, [])

    def test_sink_error_surfaces_outside_c_callback(self):
        error = OSError("test disk write failure")

        def fail(raw):
            raise error

        self.core.audio_sink = fail
        self.core._audio_sample(0, 0)
        self.assertIs(self.core.audio_error, error)
        self.core.audio_sink = self.received.append
        self.core._audio_sample(0, 0)
        self.assertEqual(self.received, [])
        self.core.core = type("FakeCore", (), {"retro_run": lambda _: None})()
        self.core.frame = 0
        with self.assertRaisesRegex(RuntimeError, "audio capture failed") as raised:
            self.core.run(1)
        self.assertIs(raised.exception.__cause__, error)


class LocalOriginalAudioTests(unittest.TestCase):
    @unittest.skipUnless((ROOT / "local-audio/genesis/boot-and-title/receipt.json").exists(),
                         "Requires local original audio captures")
    def test_captured_wavs_match_receipts_and_timing(self):
        for receipt in sorted((ROOT / "local-audio/genesis").glob("*/receipt.json")):
            with self.subTest(recording=receipt.parent.name):
                data = json.loads(receipt.read_text())
                metrics = audio_metrics(receipt.with_name("original.wav"))
                self.assertEqual(metrics, data["audio"])
                self.assertEqual(data["rom_sha256"],
                                 "ff83dc53b33252d42ac624e11a2ce717428b75f48f2e56a20b3d38f78e6ca4ea")
                self.assertLess(abs(metrics["duration_seconds"] - data["emulated_frames"] / data["video_fps"]),
                                2 / data["video_fps"])
                self.assertEqual(data["timeline"][0]["audio_frame_start"], 0)
                self.assertEqual(data["timeline"][-1]["audio_frame_end"], metrics["sample_frames"])
                for previous, current in zip(data["timeline"], data["timeline"][1:]):
                    self.assertEqual(previous["audio_frame_end"], current["audio_frame_start"])


if __name__ == "__main__":
    unittest.main()
