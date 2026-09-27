import unittest
from tools.pc_readiness import ReadinessBark
from tools.pc_audio_events import AudioEvents
from tests import test_pc_session, test_pc_audio_events


def completion(enabled=True):
    return {'kind':'reload_complete','ip':0x35EE,'return_ip':0,'value':0,'backend':0,
            'text_sequence':10,'enabled':enabled}


def visible(sequence=11,**changes):
    return {'text_runs':[{'kind':'weapon_status','text':'READY ','return_ip':0x55DF,
        'source_pointer':0x0ACA,'draw_sequence':sequence,'pixel_sha256':'a'*64,**changes}]}


class ReadinessTests(unittest.TestCase):
    def setUp(self):
        self.gate=ReadinessBark();self.status={'active':True,'enabled':True}

    def step(self,frame,events=(),view=None,status=None):
        return self.gate.advance(frame,events,view or {},self.status if status is None else status)

    def test_original_completion_and_strictly_newer_visible_draw_required_once(self):
        self.assertEqual(self.step(1,view=visible()),[])
        self.assertEqual(self.step(2,[completion()],visible(10)),[])
        self.assertEqual(self.step(3,view=visible(text='LOAD  ')),[])
        event,=self.step(5,view=visible())
        self.assertEqual((event['kind'],event['completion_frame'],event['voice']),('readiness_visible',2,'loaded'))
        self.assertIsNone(event['sample'])
        self.assertTrue(event['enabled'])
        self.assertEqual(self.step(6,view=visible()),[])

    def test_new_accepted_shot_cancels_previous_completion(self):
        self.step(1,[completion()])
        self.assertEqual(self.step(2,[{'kind':'sound','sample':'cannon'}],visible()),[])
        self.assertIsNone(self.gate.pending)
        self.assertEqual(self.step(3,[completion(),{'kind':'sound','sample':'cannon'}],visible()),[])

    def test_freshness_boundary_and_station_return_never_replay_old_completion(self):
        self.step(1,[completion()])
        self.assertEqual(len(self.step(7,view=visible())),1)
        self.step(10,[completion()])
        self.assertEqual(self.step(17,view=visible()),[])
        self.assertIsNone(self.gate.pending)
        self.assertEqual(self.step(100,view=visible()),[])

    def test_original_gate_at_completion_and_presentation_both_respected(self):
        for completed,shown in [(False,True),(True,False),(False,False)]:
            self.step(1,[completion(completed)])
            event,=self.step(4,view=visible(),status={'active':True,'enabled':shown})
            self.assertFalse(event['enabled'])
            self.assertEqual(self.step(5,view=visible()),[])

    def test_leaving_original_SIM_clears_pending(self):
        self.step(1,[completion()])
        self.assertEqual(self.step(2,view=visible(),status={'active':False,'enabled':False}),[])
        self.assertEqual(self.step(3,view=visible()),[])

    def test_wrong_callsite_pointer_text_and_unobserved_completion_fail_closed(self):
        self.step(1,[completion()])
        for change in ({'return_ip':0x3F1D},{'source_pointer':0xAD8},{'kind':'crew_primary'},{'text':'LOCKED'}):
            self.assertEqual(self.step(2,view=visible(**change)),[])
        event=completion();event.pop('text_sequence')
        self.assertEqual(self.step(3,[event],visible()),[])

    def test_session_emits_after_visible_boundary_with_monotone_ids(self):
        core,session,_=test_pc_session.SessionTests().make_session()
        core.ram[0x1ED0+0x18B50+0xF48]=1
        session.before_frame();session.collector.audio=AudioEvents()
        run=core.run
        def emit(frames,keys):
            run(frames,keys)
            if core.frame==1:
                session.collector.audio.observe(test_pc_audio_events.AudioTests().event(ip=0x35EE,value=0,reload=2),text_sequence=10)
        core.run=emit
        session.collector.paired_video=lambda _video: visible(10 if core.frame<3 else 11)
        session.step(3)
        packet=session.drain_audio();events=packet['events']
        self.assertEqual(packet['schema'],2)
        self.assertEqual([(e['id'],e['frame'],e['kind']) for e in events],
                         [(1,1,'reload_complete'),(2,3,'readiness_visible')])
        self.assertEqual(events[1]['completion_frame'],1)
        session.sample();session.sample();session.step(1)
        self.assertEqual(session.drain_audio()['events'],[])
        session.readiness.pending=(4,completion());session.close()
        self.assertIsNone(session.readiness.pending)


if __name__=='__main__': unittest.main()
