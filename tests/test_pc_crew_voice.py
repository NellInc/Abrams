import copy
import hashlib
import json
from pathlib import Path
import unittest
from tools.pc_crew_voice import CrewBarks,SCRIPT,BEARINGS,DAMAGE,WARNINGS
from tools.install_pc_crew_voice import check_take
from tools.generate_crew_voice import validate_wav
from tools.verify_pc_dialogue import verify
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

    def test_warning_blocks_and_every_pointer_variant_match_visible_gate(self):
        fixture=json.loads((ROOT/'godot/tests/fixtures/pc_warning_voice_oracle.json').read_text())
        self.assertEqual(fixture['source_sha256'],hashlib.sha256((ROOT/'GAME/SIM.EXE').read_bytes()).hexdigest())
        self.assertEqual(len(fixture['rows']),9)
        cues=json.loads(WARNINGS.read_text())['cues']
        self.assertEqual(len(cues),8)
        self.assertFalse(cues.keys() & (json.loads(SCRIPT.read_text())['cues'].keys()|json.loads(BEARINGS.read_text())['cues'].keys()|json.loads(DAMAGE.read_text())['cues'].keys()))
        for index,row in enumerate(fixture['rows'],1):
            cue=cues['pc_'+row['name']]
            self.assertEqual((cue['caption'],cue['speaker'],cue['assignment_ip']),(row['caption'],row['speaker'],row['assignment_ip']))
            self.assertIn(row['pointers'],cue['source_variants'])
            parts=[];x=46
            for pointer,text in zip(row['pointers'],row['parts']):
                parts.append({'rect':[x,112,len(text)*6,6],'source_pointer':pointer,'draw_sequence':index,'pixel_sha256':'a'*64})
                x+=len(text)*6
            item=message(index,text=row['caption'],speaker=row['speaker'],assignment_ip=row['assignment_ip'],parts=parts)
            event,=self.step([item]);self.assertEqual(event['voice'],'pc_'+row['name'])
            self.assertEqual(self.step([item]),[])
            wrong=copy.deepcopy(parts);wrong[0]['source_pointer']+=1
            for change in ({'speaker':3},{'assignment_ip':0x3d6a},{'channel':'radio'},{'parts':[]},{'parts':wrong}):
                self.assertEqual(CrewBarks().advance({'messages':[item|change]},self.status),[])
            gate=CrewBarks()
            muted,=gate.advance({'messages':[item]},self.status|{'enabled':False})
            self.assertFalse(muted['enabled'])
            self.assertEqual(gate.advance({'messages':[item]},self.status),[])

    def test_warning_masters_match_script_generated_bytes_and_blind_qa(self):
        script=json.loads(WARNINGS.read_text());folder=ROOT/'godot/assets/audio'
        receipt=json.loads((folder/'pc_warning_provenance.json').read_text())
        self.assertEqual(receipt['script_sha256'],hashlib.sha256(WARNINGS.read_bytes()).hexdigest())
        self.assertEqual(receipt['voices'].keys(),script['cues'].keys())
        for name,voice in receipt['voices'].items():
            self.assertEqual(voice['generator'],'gemini-3.8-flash-tts')
            self.assertEqual(voice['text'],script['cues'][name]['caption'])
            for key,value in validate_wav((folder/f'voice_{name}.wav').read_bytes()).items():self.assertEqual(voice[key],value)
            check_take(voice,voice['transcript_qa'],voice['number_delivery_qa'])

    def test_warning_parity_gate_rejects_changed_source_or_warning_timeline(self):
        changes=[];barks=[]
        for index,identity,enabled in [(631,1,True),(759,2,False),(944,3,True)]:
            item=message(identity,text='No smoke mortars left',speaker=1,assignment_ip=0x3d8e,
                parts=[{'source_pointer':0xf94}])
            changes.append({'frame_index':index,'messages':[item]})
            event,=CrewBarks().advance({'messages':[item]},self.status|{'enabled':enabled})
            barks.append(event|{'frame_index':index})
        steps=json.loads((ROOT/'godot/tests/fixtures/pc_warning_steps.json').read_text())
        keys=[held for count,held in steps for _ in range(count)]
        self.assertEqual(len(keys),1060)
        trace={'profile':'smoke-warnings','changes':changes,'audio_events':barks,
            'state_sha256':'same-state','state_core_sha256':'baseline',
            'frames':[{'index':i,'keys':keys[i],'ram_sha256':str(i),'video_sha256':str(i)} for i in range(1060)],
            'final_state':{},'final_program':{'name':'SIM'},'text_epochs':[],
            'message_epochs':[{'assignments':[{'id':i} for i in [1,2,3]]}]}
        baseline=copy.deepcopy(trace)|{'core_sha256':'baseline'}
        self.assertTrue(all(verify(trace,baseline)['checks'].values()))
        for fault in ('ram','video','keys','frame','mute','duplicate','missing','pointer','speaker','caption','snapshot','epoch'):
            bad=copy.deepcopy(trace)
            if fault in ('ram','video'):bad['frames'][700][fault+'_sha256']='changed'
            elif fault=='keys':bad['frames'][700]['keys']=['escape']
            elif fault=='frame':bad['audio_events'][1]['frame_index']+=1
            elif fault=='mute':bad['audio_events'][1]['enabled']=True
            elif fault=='duplicate':bad['audio_events'].append(bad['audio_events'][0])
            elif fault=='missing':bad['audio_events']=[]
            elif fault=='pointer':bad['audio_events'][0]['parts'][0]['source_pointer']+=1
            elif fault=='speaker':bad['audio_events'][0]['speaker']=2
            elif fault=='caption':bad['audio_events'][0]['text']='Invented warning'
            elif fault=='snapshot':bad['state_sha256']='changed'
            elif fault=='epoch':bad['message_epochs']=[]
            self.assertFalse(all(verify(bad,baseline)['checks'].values()),fault)

    def test_damage_gate_reports_missing_or_short_epochs_instead_of_crashing(self):
        base={'changes':[],'audio_events':[],'state_sha256':'s','state_core_sha256':'c','frames':[],
            'final_state':{},'final_program':{'name':'SIM'},'text_epochs':[]}
        baseline={'state_sha256':'s','core_sha256':'c','frames':[],'final_state':{},'final_program':{'name':'SIM'}}
        for epochs in ([],[{'assignments':[{'id':i,'parts':[]} for i in range(1,11)],'counts':{}},
                           {'assignments':[],'counts':{}}]):
            checks=verify(base|{'message_epochs':epochs},baseline)['checks']
            self.assertFalse(checks['one_SIM_message_epoch'])
            self.assertFalse(checks['all_17_original_assignments_observed'])
            self.assertFalse(checks['unseen_COAX_destroyed_stays_silent'])

    def test_visible_assignment_once_repeated_words_distinct_and_old_pages_silent(self):
        first,=self.step([message()]);self.assertEqual(first['voice'],'pc_hit_zero_four_three')
        self.assertIsNone(first['sample'])
        self.assertEqual(self.step([]),[])
        self.assertEqual(self.step([message()]),[])
        second,=self.step([message(2)]);self.assertEqual(second['message_id'],2)
        self.assertEqual(self.step([message()]),[])

    def test_every_displayed_three_digit_bearing_has_a_full_sentence(self):
        words='zero one two three four five six seven eight nine'.split()
        for bearing in range(360):
            number=f'{bearing:03d}'
            item=message(bearing+1,text="We've been hit! Bearing "+number)
            event,=self.step([item])
            self.assertEqual(event['voice'],'pc_hit_'+'_'.join(words[int(d)] for d in number))
            self.assertEqual(event['text'],item['text'])
        for invalid in ('360','-01','58','０５８','058 trailing text'):
            self.gate=CrewBarks()
            self.assertEqual(self.step([message(text="We've been hit! Bearing "+invalid)]),[])

    def test_bearing_additions_are_disjoint_and_all_installed_takes_verified(self):
        folder=ROOT/'godot/assets/audio'
        old=json.loads(SCRIPT.read_text())['cues']
        new=json.loads(BEARINGS.read_text())['cues']
        self.assertFalse(old.keys() & new.keys())
        self.assertEqual(len(new),355)
        receipt=json.loads((folder/'pc_bearing_provenance.json').read_text())
        self.assertEqual(receipt['script_sha256'],hashlib.sha256(BEARINGS.read_bytes()).hexdigest())
        self.assertEqual(receipt['voices'].keys(),new.keys())
        for cue,entry in receipt['voices'].items():
            self.assertEqual(entry['generator'],'gemini-3.8-flash-tts')
            self.assertEqual(entry['text'],new[cue]['caption'])
            actual=validate_wav((folder/f'voice_{cue}.wav').read_bytes())
            for key,value in actual.items():self.assertEqual(entry[key],value)
            check_take(entry,entry['transcript_qa'],entry['number_delivery_qa'])

    def test_all_damage_paths_match_original_oracle_and_once_only_visible_gate(self):
        fixture=json.loads((ROOT/'godot/tests/fixtures/pc_damage_voice_oracle.json').read_text())
        self.assertEqual(fixture['source_sha256'],hashlib.sha256((ROOT/'GAME/SIM.EXE').read_bytes()).hexdigest())
        self.assertEqual(len(fixture['rows']),36)
        rows=[row for row in fixture['rows'] if row['caption']]
        self.assertEqual(len(rows),24)
        old=json.loads(SCRIPT.read_text())['cues']
        new=json.loads(DAMAGE.read_text())['cues']
        self.assertEqual(len(new),15)
        self.assertFalse(new.keys() & (old.keys() | json.loads(BEARINGS.read_text())['cues'].keys()))
        captions={c['caption'] for n,c in (old|new).items() if not n.startswith('pc_hit_')}
        self.assertEqual(captions,{row['caption'] for row in rows})
        by_caption={c['caption']:c for c in new.values()}
        for index,row in enumerate(rows,1):
            self.assertEqual((row['speaker'],row['assignment_ip'],len(row['parts'])),(3,0x3dd2,2))
            self.assertEqual(row['condition_after'],row['condition_before']+1)
            if row['caption'] in by_caption:
                self.assertEqual(by_caption[row['caption']]['source_pointers'],row['pointers'])
            item=message(index,text=row['caption'],assignment_ip=row['assignment_ip'])
            event,=self.step([item])
            self.assertEqual(event['text'],row['caption'])
            self.assertEqual(self.step([item]),[])
            for change in ({'speaker':2},{'assignment_ip':0x3d6a},{'parts':[]},{'channel':'radio'}):
                gate=CrewBarks()
                self.assertEqual(gate.advance({'messages':[item|change]},self.status),[])
        for row in fixture['rows']:
            if not row['caption']:
                self.assertEqual(row['condition_before'],2)
                self.assertEqual((row['parts'],row['pointers']),([],[0,0]))

    def test_damage_additions_installed_with_matching_source_script_and_wording_qa(self):
        folder=ROOT/'godot/assets/audio'
        script=json.loads(DAMAGE.read_text())
        receipt=json.loads((folder/'pc_damage_provenance.json').read_text())
        self.assertEqual(receipt['script_sha256'],hashlib.sha256(DAMAGE.read_bytes()).hexdigest())
        self.assertEqual(receipt['voices'].keys(),script['cues'].keys())
        for name,voice in receipt['voices'].items():
            self.assertEqual(voice['generator'],'gemini-3.8-flash-tts')
            self.assertEqual(voice['text'],script['cues'][name]['caption'])
            for key,value in validate_wav((folder/f'voice_{name}.wav').read_bytes()).items():
                self.assertEqual(voice[key],value)
            check_take(voice,voice['transcript_qa'],voice['number_delivery_qa'])

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

    def test_niner_is_accepted_as_an_individual_nine_digit(self):
        voice={'sha256':'a'*64,'performed_text':"We've been hit! Bearing two nine three"}
        text={'audio_sha256':'a'*64,'expected':voice['performed_text'],
              'transcript':"We've been hit, bearing two niner three."}
        check_take(voice,text)
        for wrong in ('two ninety three','two nine','two niner four','two ninety-three'):
            with self.assertRaises(ValueError):
                check_take(voice,text|{'transcript':"We've been hit, bearing "+wrong})

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
