"""The nine original crew takes stay bound to the script they were performed from.

The six pc_*_provenance.json receipts pin their voice script by SHA-256; the
base provenance.json now does too. Each receipt row also records what was
performed (text, direction and voice), which must equal the current script, so a
script edit that leaves the installed takes stale fails here even when the
change is not audible in a caption.
"""
import hashlib
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools import generate_crew_voice as voice  # noqa: E402

SCRIPT_PATH = ROOT / 'godot/data/crew_voice_script.json'
RECEIPT_PATH = ROOT / 'godot/assets/audio/provenance.json'


class CrewVoiceProvenanceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.script = json.loads(SCRIPT_PATH.read_text())
        cls.receipt = json.loads(RECEIPT_PATH.read_text())

    def test_receipt_pins_the_script(self):
        self.assertEqual(self.receipt['script_sha256'], hashlib.sha256(SCRIPT_PATH.read_bytes()).hexdigest(),
                         'crew_voice_script.json changed after the installed takes were recorded')

    def test_every_take_matches_its_scripted_performance(self):
        self.assertEqual(self.receipt['voices'].keys(), self.script['cues'].keys())
        for name, entry in self.receipt['voices'].items():
            cue = self.script['cues'][name]
            role = self.script['roles'][cue['role']]
            with self.subTest(cue=name):
                self.assertEqual(entry['role'], cue['role'])
                self.assertEqual(entry['text'], cue['caption'])
                # The generator speaks the cue text with the preferred model and the
                # caption with the fallback, each with headings spelled out.
                spoken = cue['text'] if entry['generator'] == voice.PREFERRED else cue['caption']
                self.assertIn(entry['generator'], (voice.PREFERRED, voice.FALLBACK))
                self.assertEqual(entry['performed_text'], voice.pronounce_headings(spoken))
                self.assertEqual(entry['direction'], role['style'] + ' ' + cue['direction'])
                self.assertEqual(entry['voice'], role['voice'])

    def test_every_voice_receipt_pins_its_script(self):
        for path in sorted((ROOT / 'godot/assets/audio').glob('*provenance.json')):
            data = json.loads(path.read_text())
            if data.get('voices'):
                with self.subTest(receipt=path.name):
                    self.assertRegex(data.get('script_sha256', ''), r'^[0-9a-f]{64}$')


if __name__ == '__main__':
    unittest.main()
