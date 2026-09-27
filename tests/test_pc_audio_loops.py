import hashlib
import json
from pathlib import Path
import struct
import unittest
import wave
from tools.pc_audio_loops import LAYOUTS, read_loops
from tools.build_audio import effect, RATE

ROOT = Path(__file__).resolve().parents[1]


class LoopTests(unittest.TestCase):
    def test_loop_requires_live_owned_tone_not_occupied_channel(self):
        for backend,(table,layout) in LAYOUTS.items():
            ram=bytearray(640*1024)
            for name,(channel,begin,end,idle) in layout.items():
                at=0x18B50+table+48*channel
                for ticks,pc,period,amplitude,want in [(1,begin,idle,3,True),
                    (1,end-1,idle,3,True),(1,end,idle,3,False),
                    (1,begin-1,idle,3,False),(0,begin,idle,3,False),
                    (1,begin,0,3,False),(1,begin,idle,0,False)]:
                    struct.pack_into('<6H',ram,at,ticks,pc,period,0,period,amplitude)
                    result=read_loops(ram,0,backend)[name]
                    self.assertEqual(result['active'],want,(backend,name,ticks,pc,period,amplitude))
                    self.assertEqual(result['idle_period'],idle)
        self.assertEqual(read_loops(b'',0,255),{})

    def test_turret_sample_is_authored_deterministic_and_loop_continuous(self):
        a=effect('turret',2,1995)
        b=effect('turret',2,1995)
        self.assertEqual(a,b)
        self.assertEqual(len(a),2*RATE)
        # Periodic boundary has the same discrete slope as the first sample.
        self.assertLess(abs((a[0]-a[-1])-(a[1]-a[0])),0.00002)
        self.assertGreater(max(a)-min(a),0.1)
        self.assertLess(max(abs(x) for x in a),0.9)

    def test_installed_effect_hashes_match_provenance(self):
        folder=ROOT/'godot/assets/audio'
        receipt=json.loads((folder/'provenance.json').read_text())
        for name,item in receipt['effects'].items():
            self.assertEqual(hashlib.sha256((folder/f'{name}.wav').read_bytes()).hexdigest(),item['sha256'])
        with wave.open(str(folder/'turret.wav')) as audio:
            self.assertEqual((audio.getnchannels(),audio.getsampwidth(),audio.getframerate(),audio.getnframes()),
                             (1,2,RATE,2*RATE))


if __name__=='__main__': unittest.main()
