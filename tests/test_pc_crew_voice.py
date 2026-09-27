import copy
import hashlib
import json
from pathlib import Path
import unittest
from tools.pc_crew_voice import CrewBarks,SCRIPT
from tools.install_pc_crew_voice import check_take
from tools.generate_crew_voice import validate_wav
from tests import test_pc_session

ROOT=Path(__file__).resolve().parents[1]


def message(identity=1,**changes):
    return {'id':identity,'channel':'crew','speaker':3,'assignment_ip':0x3D6A,
        'text':"We've been hit! Bearing 043",'parts':[
            {'rect':[46,112,144,6],'draw_sequence':1,'source_pointer':0x95D,'pixel_sha256':'a'*64},
            {'rect':[190,112,18,6],'draw_sequence':2,'source_pointer':0x6472,'pixel_sha256':'b'*64}],**changes}


class CrewTests(unittest.TestCase):
    def setUp(self):
        self.gate=CrewBarks();self.status={'active':True,'enabled':True,'backend':0}

    def step(self,messages,status=None):
        return self.gate.advance({'messages':messages},status or self.status)

    def test_visible_assignment_once_repeated_words_distinct_and_old_pages_silent(self):
        first,=self.step([message()]);self.assertEqual(first['voice'],'pc_hit_zero_four_three')
        self.assertIsNone(first['sample'])
        self.assertEqual(self.step([]),[])
        self.assertEqual(self.step([message()]),[])
        second,=self.step([message(2)]);self.assertEqual(second['message_id'],2)
        self.assertEqual(self.step([message()]),[])

    def test_unknown_wrong_source_radio_and_partial_remain_silent(self):
        for change in ({'text':'Good hit!'}, {'speaker':1}, {'assignment_ip':0x3D0C},
                       {'channel':'radio'}, {'parts':[]}):
            self.gate=CrewBarks();self.assertEqual(self.step([message(**change)]),[])
        self.assertEqual(self.step([message(10,text='unmapped')]),[])
        self.assertEqual(self.step([message(9)]),[])

    def test_muted_visible_message_consumed_without_later_catchup(self):
        event,=self.step([message()],self.status|{'enabled':False})
        self.assertFalse(event['enabled'])
        self.assertEqual(self.step([message()]),[])
        self.assertEqual(self.step([message(2)],self.status|{'active':False}),[])

    def test_original_session_owns_frame_sequence_and_new_epoch(self):
        core,session,_=test_pc_session.SessionTests().make_session()
        core.ram[0x1ED0+0x18B50+0xF48]=1
        session.before_frame()
        session.collector.paired_video=lambda _: {'messages':[message()]}
        session.step(3);packet=session.drain_audio();event,=packet['events']
        self.assertEqual((packet['schema'],event['frame'],event['epoch'],event['id']),(3,1,1,1))
        session.sample();session.step(2);self.assertEqual(session.drain_audio()['events'],[])
        session.close();self.assertEqual(session.crew.last_message,0)
        session.before_frame();session.collector.paired_video=lambda _: {'messages':[message()]}
        session.step(1);event,=session.drain_audio()['events']
        self.assertEqual((event['epoch'],event['id']),(2,2))
        session.close()

    def test_numeric_transcript_requires_independent_matching_digit_delivery(self):
        voice={'sha256':'a'*64,'performed_text':"We've been hit! Bearing zero four three"}
        transcript={'audio_sha256':'a'*64,'expected':voice['performed_text'],
                    'transcript':"We've been hit, bearing 0 4 3."}
        delivery={'audio_sha256':'a'*64,'number_delivery':'individual_digits','spoken_number_words':['zero','four','three']}
        check_take(voice,transcript,delivery)
        for changed in (None,delivery|{'number_delivery':'whole_number'},
                        delivery|{'spoken_number_words':['four','three']},delivery|{'audio_sha256':'b'*64}):
            with self.assertRaises(ValueError):check_take(voice,transcript,changed)
        for text in ("We've been hit bearing 043", "We've been hit bearing forty three", "We have been hit bearing 0 4 3"):
            with self.assertRaises(ValueError):check_take(voice,transcript|{'transcript':text},delivery)
        with self.assertRaises(ValueError):check_take(voice,transcript|{'audio_sha256':'b'*64},delivery)

    def test_installed_pc_catalogue_format_caption_fingerprint_and_qa(self):
        folder=ROOT/'godot/assets/audio';receipt=json.loads((folder/'pc_crew_provenance.json').read_text())
        script=json.loads(SCRIPT.read_text())
        self.assertEqual(receipt['script_sha256'],hashlib.sha256(SCRIPT.read_bytes()).hexdigest())
        self.assertEqual(receipt['voices'].keys(),script['cues'].keys())
        for cue,entry in receipt['voices'].items():
            self.assertEqual(entry['generator'],'gemini-3.8-flash-tts')
            self.assertEqual(entry['text'],script['cues'][cue]['caption'])
            actual=validate_wav((folder/f'voice_{cue}.wav').read_bytes())
            for key,value in actual.items():self.assertEqual(entry[key],value)
            check_take(entry,entry['transcript_qa'],entry['number_delivery_qa'])


if __name__=='__main__':unittest.main()
