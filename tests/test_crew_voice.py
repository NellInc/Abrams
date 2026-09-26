import base64
import hashlib
import io
import json
from pathlib import Path
import unittest
from unittest.mock import patch
import tempfile
import wave

from tools.generate_crew_voice import PREFERRED, FALLBACK, decode_audio, pronounce_headings, request_for, validate_wav
from tools.build_audio import LINES
from tools import build_audio

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = json.loads((ROOT / "godot/data/crew_voice_script.json").read_text())


def example_wav():
    output = io.BytesIO()
    with wave.open(output, "wb") as writer:
        writer.setparams((1, 2, 24000, 0, "NONE", "not compressed"))
        writer.writeframes(b"\x01\x00" * 12000)
    return output.getvalue()


class CrewVoiceTests(unittest.TestCase):
    def test_heading_barks_read_each_digit_and_pad_zeroes(self):
        self.assertEqual(pronounce_headings("We've been hit on heading 280."), "We've been hit on heading two eight zero.")
        self.assertEqual(pronounce_headings("Bearing 045. Heading is 5."), "Bearing zero four five. Heading is zero zero five.")
        self.assertEqual(pronounce_headings("heading 0; bearing 360"), "heading zero zero zero; bearing three six zero")
        self.assertEqual(pronounce_headings("20 rounds at 1200 metres."), "20 rounds at 1200 metres.")
        for value in ("-1", "361", "280.5", "2800"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                pronounce_headings("heading " + value)

    def test_heading_pronunciation_applies_to_both_providers(self):
        cue = {"text": "Hit on heading 280.", "caption": "Hit on heading 280.", "direction": "Urgent and clear."}
        for model in (PREFERRED, FALLBACK):
            _, body = request_for(model, SCRIPT["roles"]["Commander"], cue)
            self.assertIn("heading two eight zero", json.dumps(body))
            self.assertNotIn("heading 280", json.dumps(body))

    def test_all_original_pc_bearing_strings_are_spoken_digit_by_digit(self):
        fixture = json.loads((ROOT / "godot/tests/fixtures/pc_bearings.json").read_text())
        words = ("zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine")
        self.assertEqual(len(fixture["rows"]), 256)
        for internal, degrees, digits in fixture["rows"]:
            caption = "We've been hit! Bearing " + digits
            expected = "We've been hit! Bearing " + " ".join(words[int(d)] for d in digits)
            with self.subTest(internal=internal):
                self.assertEqual(digits, f"{degrees:03d}")
                self.assertEqual(pronounce_headings(caption), expected)

    def test_existing_captions_and_identifiers_preserved(self):
        self.assertEqual(SCRIPT["cues"].keys(), LINES.keys())
        for cue, (role, caption, _) in LINES.items():
            self.assertEqual(SCRIPT["cues"][cue]["role"], role)
            self.assertEqual(SCRIPT["cues"][cue]["caption"], caption)

    def test_legacy_scratch_generator_cannot_replace_generative_voice(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            receipt = {"voices": {"ready": {"generator": PREFERRED}}}
            (folder / "provenance.json").write_text(json.dumps(receipt))
            with patch.object(build_audio, "OUT", folder), patch("sys.argv", ["build_audio.py", "--scratch-voices"]):
                with self.assertRaisesRegex(SystemExit, "protected"):
                    build_audio.main()
            self.assertEqual(json.loads((folder / "provenance.json").read_text()), receipt)

    def test_38_separates_direction_and_performance_text(self):
        cue = SCRIPT["cues"]["cease_fire"]
        url, body = request_for(PREFERRED, SCRIPT["roles"]["Commander"], cue)
        self.assertTrue(url.endswith("/interactions"))
        content = body["input"][0]["content"][0]
        self.assertEqual(content["text"], cue["text"])
        self.assertIn("<short pause>", content["text"])
        self.assertIn(cue["direction"], content["annotations"][0]["style"])
        self.assertNotIn(cue["direction"], content["text"])

    def test_31_fallback_uses_legacy_schema(self):
        cue = SCRIPT["cues"]["loaded"]
        url, body = request_for(FALLBACK, SCRIPT["roles"]["Loader"], cue)
        self.assertTrue(url.endswith(":generateContent"))
        self.assertNotIn("speech_metadata", json.dumps(body))
        self.assertNotIn("<exhales>", json.dumps(body))
        self.assertIn(cue["caption"], body["contents"][0]["parts"][0]["text"])

    def test_38_wav_is_not_double_wrapped(self):
        raw = example_wav()
        response = {"steps": [{"type": "model_output", "content": [
            {"type": "audio", "data": base64.b64encode(raw).decode()}]}]}
        self.assertEqual(decode_audio(response, PREFERRED), raw)
        self.assertEqual(validate_wav(raw)["duration_seconds"], 0.5)

    def test_31_pcm_wrap_preserves_every_sample(self):
        pcm = b"\x01\x00" * 12000
        response = {"candidates": [{"finishReason": "STOP", "content": {"parts": [
            {"inlineData": {"mimeType": "audio/L16;codec=pcm;rate=24000",
                            "data": base64.b64encode(pcm).decode()}}]}}]}
        raw = decode_audio(response, FALLBACK)
        with wave.open(io.BytesIO(raw), "rb") as reader:
            self.assertEqual(reader.readframes(reader.getnframes()), pcm)

    def test_empty_and_incomplete_responses_rejected(self):
        for model in (PREFERRED, FALLBACK):
            with self.subTest(model=model), self.assertRaises(ValueError):
                decode_audio({}, model)
        with self.assertRaises(ValueError):
            decode_audio({"candidates": [{"finishReason": "MAX_TOKENS"}]}, FALLBACK)
        with self.assertRaises(ValueError):
            validate_wav(example_wav()[:-2])

    @unittest.skipUnless((ROOT / "local-audio/crew-gemini-3.8-v1/manifest.json").exists(), "Requires generated local crew samples")
    def test_generated_masters_match_source_receipt(self):
        folder = ROOT / "local-audio/crew-gemini-3.8-v1"
        manifest = json.loads((folder / "manifest.json").read_text())
        self.assertEqual(manifest["model"], PREFERRED)
        self.assertEqual(manifest["voices"].keys(), SCRIPT["cues"].keys())
        for cue, entry in manifest["voices"].items():
            actual = validate_wav((folder / f"voice_{cue}.wav").read_bytes())
            for field, value in actual.items():
                self.assertEqual(entry[field], value)

    def test_installed_samples_match_receipt_and_script(self):
        folder = ROOT / "godot/assets/audio"
        manifest = json.loads((folder / "provenance.json").read_text())
        self.assertEqual(manifest["voices"].keys(), SCRIPT["cues"].keys())
        for cue, entry in manifest["voices"].items():
            self.assertIn(entry["generator"], (PREFERRED, FALLBACK))
            self.assertEqual(entry["text"], SCRIPT["cues"][cue]["caption"])
            self.assertEqual(hashlib.sha256((folder / f"voice_{cue}.wav").read_bytes()).hexdigest(), entry["sha256"])
