import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch
import wave

from tools import audit_pc_audio as audit


class AudioAuditTests(unittest.TestCase):
    def test_entire_finite_source_denominator_is_covered(self):
        result=audit.source_inventory()
        self.assertEqual(len(result['sound_calls']),30)
        self.assertEqual(len(result['message_calls']),21)
        self.assertEqual(result['caption_counts'],dict(damage=24,warning=8,remaining=50,radio=7,bearing=256))
        self.assertEqual(result['source_caption_total'],345)
        self.assertEqual(result['installed_pc_caption_total'],449)
        self.assertEqual(result['supplemental_bearing_takes'],104)
        self.assertEqual(result['missing_source_captions'],[])

    def test_missing_sound_callsite_fails_denominator(self):
        with patch.dict(audit.SAMPLES,{},clear=True):
            with self.assertRaisesRegex(ValueError,'Unclassified'):
                audit.source_inventory()

    def test_pcm_metrics_detect_both_rails_and_silence(self):
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'test.wav'
            with wave.open(str(path),'wb') as wav:
                wav.setparams((1,2,1000,0,'NONE','not compressed'))
                wav.writeframes(struct.pack('<8h',0,0,32767,-32768,100,-100,0,0))
            result=audit.pcm_metrics(path)
            self.assertEqual(result['full_scale_samples'],2)
            self.assertEqual(result['leading_silence_seconds'],.002)
            self.assertEqual(result['trailing_silence_seconds'],.002)
            self.assertEqual(result['peak_dbfs'],0)

    def test_repaired_bearing_has_headroom_and_independent_digit_qa(self):
        name='pc_hit_one_eight_two'
        folder=audit.ROOT/'godot/assets/audio'
        result=audit.pcm_metrics(folder/f'voice_{name}.wav')
        self.assertEqual(result['full_scale_samples'],0)
        self.assertLess(result['peak_dbfs'],-1)
        entry=json.loads((folder/'pc_bearing_provenance.json').read_text())['voices'][name]
        self.assertEqual(entry['sha256'],result['sha256'])
        self.assertEqual(entry['number_delivery_qa']['spoken_number_words'],['one','eight','two'])
        self.assertTrue(entry['number_delivery_qa']['match'])
        self.assertEqual(entry['number_delivery_qa']['audio_sha256'],result['sha256'])

    def test_godot_dispatcher_mirrors_python_callsite_catalogue(self):
        # Extract only literal constant maps, then compare every request/caller.
        import re
        text=(audit.ROOT/'godot/scripts/pc_audio.gd').read_text()
        calls=re.search(r'const REQUEST_CALLS := (\{.*?\})',text,re.S)[1]
        samples=re.search(r'const REQUEST_SAMPLES := (\{.*?\})',text,re.S)[1]
        import ast
        calls=ast.literal_eval(calls);samples=ast.literal_eval(samples)
        mapped={(request,ip):samples[request] for request,ips in calls.items() for ip in ips}
        self.assertEqual(mapped,{key:value[0] for key,value in audit.SAMPLES.items()})
