import json,struct,unittest,wave,hashlib
from pathlib import Path
from tools.pc_audio_events import AudioEvents,SAMPLES
from tools.pc_crew_voice import CrewBarks
ROOT=Path(__file__).resolve().parents[1]
class RemainingAudioTests(unittest.TestCase):
 def test_every_source_call_is_exactly_mapped_without_speech(self):
  rows=json.loads((ROOT/'godot/tests/fixtures/pc_request_sound_oracle.json').read_text())['rows']
  self.assertEqual(len(rows),7)
  for row in rows:
   self.assertEqual(SAMPLES[(row['request'],row['return_ip'])],(row['sample'],None))
   event=AudioEvents();event.observe(struct.pack('<6H',0x9107,row['return_ip'],row['request'],0,1,0))
   self.assertEqual(event.drain()[0]['sample'],row['sample'])
   event.observe(struct.pack('<6H',0x9107,row['return_ip']+1,row['request'],0,1,0))
   self.assertIsNone(event.drain()[0]['sample'])
 def test_every_remaining_caption_matches_original_assignment(self):
  rows=json.loads((ROOT/'godot/tests/fixtures/pc_remaining_voice_oracle.json').read_text())['rows']
  script=json.loads((ROOT/'godot/data/pc_remaining_voice_script.json').read_text())['cues']
  self.assertEqual(len(rows),54);self.assertEqual(len(script),50)
  for row in rows:
   candidates=[(n,c) for n,c in script.items() if c['caption']==row['caption'] and c['speaker']==row['speaker']]
   self.assertEqual(len(candidates),1);name,cue=candidates[0]
   self.assertEqual(cue['assignment_ip'],row['assignment_ip'])
   self.assertEqual(cue['parts_count'],len(row['parts']))
   if 'source_variants' in cue:self.assertIn(row['pointers'],cue['source_variants'])
   parts=[{'source_pointer':p} for p in row['pointers']]
   message={'id':1,'channel':'crew','text':row['caption'],'speaker':row['speaker'],'assignment_ip':row['assignment_ip'],'parts':parts}
   bark=CrewBarks();events=bark.advance({'messages':[message]},{'active':True,'enabled':True,'backend':0})
   self.assertEqual([x['voice'] for x in events],[name])
   self.assertEqual(bark.advance({'messages':[message]},{'active':True,'enabled':True,'backend':0}),[])
   self.assertEqual(CrewBarks().advance({'messages':[]},{'active':True,'enabled':True,'backend':0}),[])
   wrong=message|{'parts':parts[:-1]}
   self.assertEqual(CrewBarks().advance({'messages':[wrong]},{'active':True,'enabled':True,'backend':0}),[])
 def test_request_samples_are_original_bounded_pcm(self):
  receipt=json.loads((ROOT/'godot/assets/audio/pc_request_provenance.json').read_text())
  for name,row in receipt['samples'].items():
   path=ROOT/'godot/assets/audio'/f'{name}.wav';self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),row['sha256'])
   with wave.open(str(path),'rb') as wav:
    self.assertEqual(wav.getparams()[:3],(1,2,48000));raw=wav.readframes(wav.getnframes())
   values=struct.unpack('<'+str(len(raw)//2)+'h',raw)
   self.assertLess(max(abs(x) for x in values),32767);self.assertGreater(max(abs(x) for x in values),1000)

class DesignationQATests(unittest.TestCase):
 def test_only_exact_model_designations_are_accepted(self):
  from tools.check_crew_transcripts import wording_matches
  self.assertTrue(wording_matches('Sir, base and comm station destroyed.','Sir, base and com station destroyed!'))
  self.assertFalse(wording_matches('Sir, base and comms station destroyed.','Sir, base and com station destroyed!'))
  for expected,spoken in [('M1-A1 destroyed.','M one A one destroyed.'),('M60a3 destroyed.','M sixty A three destroyed.'),('M113 destroyed.','M one one three destroyed.'),('BMP-1 destroyed.','BMP-one destroyed.'),('BRDM-3 destroyed.','BRDM three destroyed.'),('A10 destroyed.','A ten destroyed.')]:
   self.assertTrue(wording_matches(spoken,expected))
  for expected,spoken in [('M113 destroyed.','M one one two destroyed.'),('BMP-1 destroyed.','BMP two destroyed.'),('BRDM-3 destroyed.','BRDM two destroyed.'),('A10 destroyed.','A eleven destroyed.'),('M1 destroyed.','M one A one destroyed.'),("We've been hit! Bearing zero seven zero.","We've been hit! Bearing seventy.")]:
   self.assertFalse(wording_matches(spoken,expected))

class RemainingInstalledVoiceTests(unittest.TestCase):
 def test_installed_dry_masters_and_source_captions(self):
  from tools.generate_crew_voice import validate_wav,pronounce_headings
  from tools.install_pc_crew_voice import check_take
  folder=ROOT/'godot/assets/audio';script_path=ROOT/'godot/data/pc_remaining_voice_script.json'
  script=json.loads(script_path.read_text());receipt=json.loads((folder/'pc_remaining_provenance.json').read_text())
  self.assertEqual(receipt['script_sha256'],hashlib.sha256(script_path.read_bytes()).hexdigest())
  self.assertEqual(set(receipt['voices']),set(script['cues']))
  for name,voice in receipt['voices'].items():
   raw=(folder/f'voice_{name}.wav').read_bytes();metrics=validate_wav(raw)
   for field,value in metrics.items():self.assertEqual(voice[field],value)
   cue=script['cues'][name];self.assertEqual(voice['text'],cue['caption'])
   self.assertEqual(voice['performed_text'],pronounce_headings(cue['text'] if voice['generator']=='gemini-3.8-flash-tts' else cue['caption']))
   check_take(voice,voice['transcript_qa'],voice['number_delivery_qa'])
