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
