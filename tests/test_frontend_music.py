import hashlib,json,struct,unittest,wave
from pathlib import Path
from tools.build_frontend_music import CONTEXTS,RATE,score,instrument
ROOT=Path(__file__).resolve().parents[1]
class FrontendMusicTests(unittest.TestCase):
 def test_authored_scores_are_bounded(self):
  for context in CONTEXTS:
   bpm,events=score(context)
   self.assertTrue(60<=bpm<=120)
   for e in events:
    self.assertTrue(0<=e['beat']<64)
    self.assertTrue(0<e['gain']<=0.5)
    self.assertTrue(-1<=e['pan']<=1)
 def test_authored_instrument_is_deterministic_and_shaped(self):
  a=instrument('brass',62,0.5)
  self.assertEqual(a,instrument('brass',62,0.5));self.assertEqual(a[0],0)
  self.assertTrue(max(abs(x) for x in a)<1)
 @unittest.skipUnless((ROOT/'local-audio/suno-score-v1/manifest.json').exists(),'optional private Suno score')
 def test_polished_suno_custody_and_musical_edit_contract(self):
  folder=ROOT/'local-audio/suno-score-v1';manifest=json.loads((folder/'manifest.json').read_text())
  self.assertEqual(manifest['revision'],2)
  catalogue=json.loads((ROOT/'godot/data/pc_suno_score.json').read_text())
  self.assertEqual(set(manifest['tracks']),{t['id'] for t in catalogue['tracks']+catalogue['edits']})
  for key,row in manifest['tracks'].items():
   with self.subTest(cue=key):
    path=folder/row['file']
    self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),row['sha256'])
    master=folder/row['master_file']
    self.assertEqual(hashlib.sha256(master.read_bytes()).hexdigest(),row['master_sha256'])
    with wave.open(str(path),'rb') as wav:
     self.assertEqual((wav.getframerate(),wav.getnchannels(),wav.getsampwidth()),(24000,2,2))
     self.assertEqual(wav.getnframes(),row['frames'])
     if row['loop']:
      # Phrase duration is an exact multiple of the fitted musical bar.
      self.assertIn(row['loop_bars'],[8,16,24,32])
      duration=(row['frames']-row['loop_begin'])/24000
      self.assertAlmostEqual(duration,row['loop_bars']*4*60/row['estimated_bpm'],delta=2/24000)
      wav.setpos(row['loop_begin']);begin=wav.readframes(1)
      wav.setpos(wav.getnframes()-1);self.assertEqual(begin,wav.readframes(1))
     if key.startswith('stinger_'):
      self.assertFalse(row['loop']);self.assertTrue(2<=row['seconds']<=6)
    self.assertLess(row['peak'],.999)
  a,b=[manifest['tracks'][k] for k in ['battle_flank','battle_pressure']]
  self.assertLessEqual(a['source_end_seconds'],b['source_begin_seconds'])
 @unittest.skipUnless((ROOT/'local-audio/frontend-music-v1/manifest.json').exists(),'optional private music assets')
 def test_installed_music_custody_format_and_loop(self):
  folder=ROOT/'local-audio/frontend-music-v1';manifest=json.loads((folder/'manifest.json').read_text())
  self.assertEqual(set(manifest['tracks']),set(CONTEXTS))
  for context,track in manifest['tracks'].items():
   path=folder/track['file'];self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),track['sha256'])
   with wave.open(str(path),'rb') as wav:
    self.assertEqual((wav.getframerate(),wav.getnchannels(),wav.getsampwidth()),(RATE,2,2))
    raw=wav.readframes(wav.getnframes())
   values=struct.unpack('<'+str(len(raw)//2)+'h',raw)
   self.assertLess(max(abs(x) for x in values),32767)
   self.assertLessEqual(max(abs(values[0]-values[-2]),abs(values[1]-values[-1])),4)
   self.assertGreater(track['rms'],0.02)
