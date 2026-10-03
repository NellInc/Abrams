import copy
import shutil
import tempfile
from unittest.mock import patch
import hashlib
import json
from pathlib import Path
import unittest
from tools.pc_crew_voice import RadioBarks,CrewBarks,RADIO
from tools.install_pc_crew_voice import check_take,prepare
from tools.generate_crew_voice import validate_wav
from tools.inspect_scenarios import decode_resource,parse_scenario
from tests import test_pc_session
from tools.verify_pc_dialogue import verify

ROOT=Path(__file__).resolve().parents[1]


def message(identity=1,**changes):
    return {'id':identity,'channel':'radio','speaker':None,'assignment_ip':0x3f73,
        'text':'M1, hind spotted your sector!','parts':[{'source_pointer':0xb000,
            'rect':[46,112,174,6],'draw_sequence':1,'pixel_sha256':'a'*64}],**changes}


class RadioTests(unittest.TestCase):
    status={'active':True,'enabled':True,'backend':0}

    def test_original_source_cases_and_catalogue_coverage(self):
        fixture=json.loads((ROOT/'godot/tests/fixtures/pc_radio_voice_oracle.json').read_text())
        self.assertEqual(fixture['source_sha256'],hashlib.sha256((ROOT/'GAME/SIM.EXE').read_bytes()).hexdigest())
        self.assertEqual(len(fixture['rows']),30)
        self.assertEqual(fixture['no_message_sentinel'],'silent')
        captions=set()
        for name,pin in fixture['resources'].items():
            raw=(ROOT/'GAME'/name).read_bytes();self.assertEqual(hashlib.sha256(raw).hexdigest(),pin['sha256'])
            for row in parse_scenario(decode_resource(raw))['messages']:
                if row['flag_byte']==4:captions.add(row['text'])
        captions|={'Abort mission.','The mission is complete!'}
        cues=json.loads(RADIO.read_text())['cues'];self.assertEqual(len(cues),7)
        self.assertEqual({c['caption'] for c in cues.values()},captions)
        gate=RadioBarks()
        for row in fixture['rows']:
            self.assertEqual(row['queued'],row['health']!=2)
            self.assertEqual(row['retrieved'],row['queued'])
            if not row['queued']:
                self.assertEqual(row['events'],[]);continue
            for ip in (row['assignment_ip'],0x3f73):
                item=message(text=row['caption'],assignment_ip=ip,parts=[{'source_pointer':row['pointer']}])
                event,=RadioBarks().advance({'messages':[item]},self.status)
                self.assertEqual(event['kind'],'radio_visible');self.assertEqual(cues[event['voice']]['caption'],row['caption'])
                self.assertEqual(CrewBarks().advance({'messages':[item]},self.status),[])

    def test_queued_partial_unknown_or_wrong_channel_cannot_speak(self):
        for changes in ({'channel':'crew'},{'speaker':0},{'assignment_ip':0x3d8e},
                        {'text':'a queued report'},{'parts':[]}):
            self.assertEqual(RadioBarks().advance({'messages':[message(**changes)]},self.status),[])
        gate=RadioBarks()
        self.assertEqual(gate.advance({'queued_radio':message(),'messages':[]},self.status),[])
        event,=gate.advance({'messages':[message()]},self.status);self.assertEqual(event['voice'],'pc_radio_hind')
        self.assertEqual(gate.advance({'messages':[message()]},self.status),[])
        reopened,=gate.advance({'messages':[message(2)]},self.status);self.assertEqual(reopened['message_id'],2)

    def test_mute_consumes_radio_and_channels_have_independent_lifetimes(self):
        gate=RadioBarks();item=message()
        event,=gate.advance({'messages':[item]},self.status|{'enabled':False});self.assertFalse(event['enabled'])
        self.assertEqual(gate.advance({'messages':[item]},self.status),[])
        self.assertEqual(gate.advance({'messages':[message(3)]},self.status|{'active':False}),[])
        self.assertEqual(gate.advance({'messages':[message(3)]},self.status)[0]['message_id'],3)
        self.assertEqual(gate.advance({'messages':[message(2)]},self.status),[])
        core,session,_=test_pc_session.SessionTests().make_session()
        session.crew.last_message=100;session.radio.last_message=200
        session.close();self.assertEqual((session.crew.last_message,session.radio.last_message),(0,0))

    def test_static_radio_strings_require_their_actual_pointer(self):
        item=message(text='Abort mission.',parts=[{'source_pointer':0x211}])
        self.assertEqual(RadioBarks().advance({'messages':[item]},self.status)[0]['voice'],'pc_radio_abort')
        item['parts'][0]['source_pointer']+=1
        self.assertEqual(RadioBarks().advance({'messages':[item]},self.status),[])

    def test_generated_radio_masters_and_blind_wording_custody(self):
        script=json.loads(RADIO.read_text());folder=ROOT/'godot/assets/audio'
        receipt=json.loads((folder/'pc_radio_provenance.json').read_text())
        self.assertEqual(receipt['script_sha256'],hashlib.sha256(RADIO.read_bytes()).hexdigest())
        self.assertEqual(receipt['voices'].keys(),script['cues'].keys())
        for name,voice in receipt['voices'].items():
            self.assertEqual(voice['generator'],'gemini-3.8-flash-tts')
            self.assertEqual(voice['text'],script['cues'][name]['caption'])
            for key,value in validate_wav((folder/f'voice_{name}.wav').read_bytes()).items():self.assertEqual(voice[key],value)
            check_take(voice,voice['transcript_qa'])

    def test_radio_parity_rejects_changed_timeline_provenance_or_hidden_speech(self):
        changes=[];barks=[];assignments=[]
        text='M1, object airborne your sector!'
        for index,identity,enabled in [(2868,4,True),(3145,5,False),(3482,6,True)]:
            item=message(identity,text=text,parts=[{'source_pointer':48334}])
            changes.append({'frame_index':index,'messages':[item]})
            event,=RadioBarks().advance({'messages':[item]},self.status|{'enabled':enabled})
            barks.append(event|{'frame_index':index})
        for identity,ip in [(3,0x3c90),(4,0x3f73),(5,0x3f73),(6,0x3f73)]:
            assignments.append({'id':identity,'ip':ip,'channel':'radio','speaker':None,'parts':[{'pointer':48334,'text':text}]})
        alert={'kind':'sound','sample':'radio','frame_index':2614,'ip':0x9107,'return_ip':0x3c97,'value':11,'voice':None,'enabled':True}
        steps=json.loads((ROOT/'godot/tests/fixtures/pc_radio_steps.json').read_text())
        keys=[held for count,held in steps for _ in range(count)]
        self.assertEqual(len(keys),3716)
        trace={'profile':'radio-retrieval','changes':changes,'audio_events':[alert]+barks,
            'state_sha256':'same-state','state_core_sha256':'baseline',
            'frames':[{'index':i,'keys':held,'ram_sha256':str(i),'video_sha256':str(i)} for i,held in enumerate(keys)],
            'final_state':{},'final_program':{'name':'SIM'},'text_epochs':[],
            'message_epochs':[{'assignments':assignments}]}
        baseline=copy.deepcopy(trace)|{'core_sha256':'baseline'}
        self.assertTrue(all(verify(trace,baseline)['checks'].values()))
        for fault in ('ram','video','keys','frame','mute','duplicate','missing','pointer','speaker','caption','snapshot','epoch','early','alert','queue'):
            bad=copy.deepcopy(trace)
            if fault in ('ram','video'):bad['frames'][700][fault+'_sha256']='changed'
            elif fault=='keys':bad['frames'][700]['keys']=['escape']
            elif fault=='frame':bad['audio_events'][1]['frame_index']+=1
            elif fault=='mute':bad['audio_events'][2]['enabled']=True
            elif fault=='duplicate':bad['audio_events'].append(bad['audio_events'][1])
            elif fault=='missing':bad['audio_events']=[]
            elif fault=='pointer':bad['audio_events'][1]['parts'][0]['source_pointer']+=1
            elif fault=='speaker':bad['audio_events'][1]['speaker']=2
            elif fault=='caption':bad['audio_events'][1]['text']='Invented radio'
            elif fault=='snapshot':bad['state_sha256']='changed'
            elif fault=='epoch':bad['message_epochs']=[]
            elif fault=='early':bad['changes'][0]['messages'][0]['id']=3
            elif fault=='alert':bad['audio_events'][0]['voice']='pc_radio_airborne'
            elif fault=='queue':bad['message_epochs'][0]['assignments'][0]['ip']+=1
            self.assertFalse(all(verify(bad,baseline)['checks'].values()),fault)

    def test_selected_takes_retain_independent_scripts_and_qa(self):
        installed=json.loads((ROOT/'godot/assets/audio/pc_radio_provenance.json').read_text())['voices']
        script=json.loads(RADIO.read_text());names=['pc_radio_hind','pc_radio_airborne'];fixed=names[1]
        script['cues']={n:script['cues'][n] for n in names}
        original=copy.deepcopy(script);original['cues'][fixed]['text']='M1, object airborne your sector!'
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);base=root/'base';repair=root/'repair';base.mkdir();repair.mkdir()
            current=root/'current.json';current.write_text(json.dumps(script));old=root/'old.json';old.write_text(json.dumps(original))
            for folder,source_script,selected in [(base,old,names),(repair,current,[fixed])]:
                voices={n:copy.deepcopy(installed[n]) for n in selected}
                qa={n:voices[n]['transcript_qa'] for n in selected}
                if folder==base:
                    voices[fixed]['performed_text']=original['cues'][fixed]['text']
                    qa[fixed]={'transcript':'Mark one, object airborne your sector!','expected':voices[fixed]['performed_text'],'normalized_match':False,'audio_sha256':voices[fixed]['sha256']}
                for n in selected:(folder/f'voice_{n}.wav').write_bytes((ROOT/'godot/assets/audio'/f'voice_{n}.wav').read_bytes())
                (folder/'manifest.json').write_text(json.dumps({'script_sha256':hashlib.sha256(source_script.read_bytes()).hexdigest(),'voices':voices}))
                (folder/'qa-first').mkdir();(folder/'qa-first/transcription-check.json').write_text(json.dumps({'results':qa}))
            with patch('tools.install_pc_crew_voice.ROOT',root):
                payloads,receipt=prepare(base,current,source_script=old,repair=repair)
                self.assertEqual(len(payloads),2)
                self.assertEqual(receipt['voices'][fixed]['source_master'],'repair/voice_pc_radio_airborne.wav')
                self.assertNotEqual(receipt['voices'][names[0]]['generation_script_sha256'],receipt['voices'][fixed]['generation_script_sha256'])
                self.assertEqual({q['path'] for q in receipt['qa_inputs']},{'base/manifest.json','old.json','base/qa-first/transcription-check.json',
                    'repair/manifest.json','current.json','repair/qa-first/transcription-check.json'})
                with tempfile.TemporaryDirectory() as outside, self.assertRaisesRegex(ValueError,'outside repository'):
                    shutil.copytree(base,Path(outside)/'base');prepare(Path(outside)/'base',current,source_script=old)
                with self.assertRaisesRegex(ValueError,'generation script changed'):prepare(base,current,repair=repair)
                with self.assertRaisesRegex(ValueError,'selected generation cue'):prepare(base,current,source_script=old)
                path=repair/'qa-first/transcription-check.json';bad=json.loads(path.read_text())
                bad['results'][fixed]['transcript']='Mike one, object airborne your sector!';path.write_text(json.dumps(bad))
                with self.assertRaisesRegex(ValueError,'wording'):prepare(base,current,source_script=old,repair=repair)


if __name__=='__main__':unittest.main()
