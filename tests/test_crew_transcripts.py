import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import wave
from tools.check_crew_transcripts import prepare,evaluate,normalized,wording_matches


class TranscriptTests(unittest.TestCase):
    def test_M1_designation_accepts_literal_M_one_only_in_designation_scripts(self):
        expected='Sir, the M1 is not amphibious.'
        self.assertTrue(wording_matches('Sir, the M one is not amphibious.',expected))
        self.assertTrue(wording_matches(expected,expected))
        for wrong in ('M two','M eleven','M won','one','M','M1A1'):
            self.assertFalse(wording_matches('Sir, the '+wrong+' is not amphibious.',expected))
        self.assertFalse(wording_matches('Bearing 043','Bearing zero four three'))
        self.assertFalse(wording_matches('M one','M2'))

    def test_number_words_never_accept_whole_number_or_numeric_transcript(self):
        expected="We've been hit! Bearing zero four three"
        self.assertEqual(normalized(expected),normalized("WE'VE been hit, bearing zero, four, three."))
        self.assertNotEqual(normalized(expected),normalized("We've been hit bearing forty three"))
        self.assertNotEqual(normalized(expected),normalized("We've been hit bearing 043"))
        self.assertNotEqual(normalized(expected),normalized("We've been hit bearing four three"))

    def test_prepare_withholds_cue_identity_expected_words_and_paths(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);name='private_expected_cue'
            with wave.open(str(root/f'voice_{name}.wav'),'wb') as w:
                w.setparams((1,2,24000,0,'NONE','not compressed'));w.writeframes(b'\1\0'*4800)
            raw=(root/f'voice_{name}.wav').read_bytes()
            voice={'performed_text':'Expected words stay private','sha256':hashlib.sha256(raw).hexdigest()}
            (root/'manifest.json').write_text(json.dumps({'voices':{name:voice}}))
            request,inputs=prepare(root)
            serialized=json.dumps(request)
            for value in (name,str(root),voice['performed_text']):self.assertNotIn(value,serialized)
            self.assertEqual(inputs[0]['expected'],voice['performed_text'])
            self.assertEqual(request['response_format']['required'],['clip_00'])
            (root/f'voice_{name}.wav').write_bytes(raw[:-2]+b'\2\0')
            with self.assertRaisesRegex(ValueError,'differs'):prepare(root)

    def test_response_requires_complete_exact_neutral_ID_set(self):
        inputs=[{'id':'clip_00','cue':'hit','expected':'Bearing zero four three','sha256':'a'*64}]
        response={'status':'completed','steps':[{'type':'model_output','content':[{'type':'text','text':json.dumps({'clip_00':'Bearing zero four three.'})}]}]}
        self.assertTrue(evaluate(response,inputs)['hit']['normalized_match'])
        self.assertFalse(evaluate({'output_text':json.dumps({'clip_00':'Bearing forty three'})},inputs)['hit']['normalized_match'])
        with self.assertRaisesRegex(ValueError,'incomplete'):evaluate({'status':'in_progress'},inputs)
        with self.assertRaisesRegex(ValueError,'IDs'):evaluate({'output_text':json.dumps({'hit':'Bearing zero four three'})},inputs)

    def test_spoken_number_probe_requires_three_literal_digits(self):
        inputs=[{'id':'clip_00','cue':'hit','expected':'Bearing zero four three','sha256':'a'*64}]
        value={'number_delivery':'individual_digits','spoken_number_words':['zero','four','three']}
        def response(v):return {'status':'completed','output_text':json.dumps({'clip_00':v})}
        self.assertTrue(evaluate(response(value),inputs,number_delivery=True)['hit']['match'])
        for change in ({'number_delivery':'whole_number'},{'number_delivery':'uncertain'},
                       {'spoken_number_words':['four','three']},{'spoken_number_words':['043']}):
            self.assertFalse(evaluate(response(value|change),inputs,number_delivery=True)['hit']['match'])
        with self.assertRaises(ValueError):evaluate(response('043'),inputs,number_delivery=True)


if __name__=='__main__':unittest.main()
