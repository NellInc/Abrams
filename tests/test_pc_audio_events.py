import struct
import unittest
from tools.pc_audio_events import AudioEvents, audio_status, SAMPLES
from tests import test_pc_session
from tests.test_pc_session import program_ram


class AudioTests(unittest.TestCase):
    def event(self, ip=0x9107, caller=0x33C4, value=1, backend=0, gate=1, reload=0):
        return struct.pack('<6H',ip,caller,value,backend,gate,reload)

    def test_original_dispatch_is_required_not_sound_id_alone(self):
        audio = AudioEvents()
        for (value,caller),(sample,voice) in SAMPLES.items():
            audio.observe(self.event(caller=caller,value=value))
            event, = audio.drain()
            self.assertEqual((event['sample'],event['voice']),(sample,voice))
            self.assertTrue(event['enabled'])
        audio.observe(self.event(caller=0))
        event, = audio.drain()
        self.assertIsNone(event['sample'])
        self.assertIsNone(event['voice'])
        self.assertEqual(audio.drain(),[])

    def test_sound_gate_and_unknown_backend_fail_closed(self):
        audio = AudioEvents()
        for backend,gate in [(0,0),(1,0),(2,1),(255,1),(0,2)]:
            audio.observe(self.event(backend=backend,gate=gate))
            self.assertFalse(audio.drain()[0]['enabled'])
        audio.observe(self.event(ip=0x8DA3, value=0))
        self.assertEqual(audio.drain()[0]['kind'],'gate')
        audio.observe(self.event(ip=0x8DA3, value=1, gate=0))
        self.assertTrue(audio.drain()[0]['enabled'])

    def test_reload_is_evidence_only_and_invalid_state_rejected(self):
        audio = AudioEvents()
        audio.observe(self.event(ip=0x35EE, reload=2))
        event, = audio.drain()
        self.assertEqual(event['kind'],'reload_complete')
        self.assertNotIn('voice',event)
        with self.assertRaisesRegex(ValueError,'loading state'): audio.observe(self.event(ip=0x35EE))
        with self.assertRaisesRegex(ValueError,'boundary'): audio.observe(b'')
        with self.assertRaisesRegex(ValueError,'boundary'): audio.observe(self.event(ip=123))

    def test_queue_overflow_never_silently_drops_requests(self):
        audio = AudioEvents(limit=2)
        audio.observe(self.event()); audio.observe(self.event())
        with self.assertRaisesRegex(ValueError,'overflow'): audio.observe(self.event())
        self.assertEqual(len(audio.drain()),2)
        audio.observe(self.event())
        self.assertEqual(len(audio.drain()),1)

    def test_audio_status_is_original_gate_and_program_bound(self):
        ram = program_ram()
        program = {'name':'SIM','load_segment':0x1ED}
        at = 0x1ED0+0x18B50+0xF48
        ram[at]=1
        self.assertTrue(audio_status(ram,program)['enabled'])
        ram[at]=0
        self.assertFalse(audio_status(ram,program)['enabled'])
        self.assertFalse(audio_status(ram,{'name':'END'})['active'])
        self.assertFalse(audio_status(ram,None)['active'])

    def test_session_batch_drain_has_monotone_ids_and_epoch_custody(self):
        core,session,_ = test_pc_session.SessionTests().make_session()
        session.before_frame()
        session.collector.audio = AudioEvents()
        run = core.run
        def emit(frames, keys):
            run(frames,keys)
            if session.collector: session.collector.audio.observe(self.event())
        core.run = emit
        session.step(3)
        self.assertEqual([e['id'] for e in session.audio_pending],[1,2,3])
        # Sampling graphics must not drain sound or cause it to repeat.
        session.sample(); session.sample()
        first = session.drain_audio()
        self.assertEqual([e['frame'] for e in first['events']],[1,2,3])
        self.assertEqual(session.drain_audio()['events'],[])
        session.step(1)
        core.ram = program_ram('END')
        session.step(1)
        end = session.drain_audio()
        self.assertEqual([e['id'] for e in end['events']],[4])
        self.assertFalse(end['active'])
        core.ram = program_ram('SIM')
        session.before_frame()
        session.collector.audio = AudioEvents()
        session.step(1)
        reentry = session.drain_audio()
        self.assertEqual(reentry['epoch'],2)
        self.assertEqual(reentry['events'][0]['id'],5)
        self.assertEqual(reentry['events'][0]['epoch'],2)
        session.close()


if __name__ == '__main__': unittest.main()
