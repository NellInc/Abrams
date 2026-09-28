import struct
import json
from pathlib import Path
import unittest
from types import SimpleNamespace
from tools.pc_live_state import active_program
from tools.pc_session import PresentationSession


def program_ram(name='SIM', psp=0x1DD):
    ram = bytearray(640*1024)
    struct.pack_into('<H',ram,0xB30,psp)
    at = (psp-1)*16
    ram[at] = ord('M')
    struct.pack_into('<H',ram,at+1,psp)
    ram[at+8:at+16] = name.encode().ljust(8,b'\0')
    ram[psp*16:psp*16+2] = b'\xcd\x20'
    ds = (psp+16)*16+0x19E00
    struct.pack_into('<HH',ram,ds+0x6D50,0,0x8000)
    ram[0x80000:0x80005] = b'shape'
    return ram


class SessionTests(unittest.TestCase):
    def test_combat_loss_route_waits_for_original_exit_without_quit(self):
        from tools.capture_pc_session import combat_loss_steps
        program='SIM'
        session=SimpleNamespace(sample=lambda:{'program':{'name':program}})
        route=[]
        for step in combat_loss_steps(session):
            route.append(step)
            if step['label']=='combat-001':program='END'
            if step['label']=='combat-review-1':program='START'
        self.assertFalse(any('q' in s['keys'] for s in route))
        waits=[s for s in route if s['label'][7:].isdigit() and s['label'].startswith('combat-')]
        self.assertEqual([(s['frames'],s['keys']) for s in waits],[(60,[]),(60,[])])
        self.assertEqual(route[-1]['label'],'second-mission')
        self.assertTrue(all(1<=s['frames']<=600 for s in route))

    def test_combat_loss_bound_cannot_substitute_quitting_or_fake_end(self):
        from tools.capture_pc_session import combat_loss_steps
        session=SimpleNamespace(sample=lambda:{'program':{'name':'SIM'}})
        with self.assertRaisesRegex(ValueError,'18000 frames'):
            list(combat_loss_steps(session))
        session=SimpleNamespace(sample=lambda:{'program':{'name':'START'}})
        with self.assertRaisesRegex(ValueError,'did not enter'):
            list(combat_loss_steps(session))

    def test_all_scenario_route_visits_eight_menus_without_guest_writes(self):
        from tools.capture_pc_session import scenario_steps
        route=list(scenario_steps())
        labels=[s['label'] for s in route]
        self.assertEqual(len(labels),len(set(labels)))
        for mission in range(8):
            prefix=f'scenario-{mission}'
            changes=[s for s in route if s['label'].startswith(prefix+'-next-') and s['label'].endswith('-press')]
            self.assertEqual(len(changes),mission)
            for station in ('gunner','commander','cupola','driver'):
                self.assertIn(prefix+'-'+station,labels)
            self.assertIn(prefix+'-debrief',labels)
            self.assertIn(prefix+'-main-menu',labels)
        from tools.pc_reference_core import KEYS
        for step in route:
            self.assertTrue(1<=step['frames']<=600)
            self.assertTrue(set(step['keys'])<=set(KEYS))

    def test_campaign_capture_routes_use_only_original_inputs(self):
        from tools.pc_reference_core import KEYS
        routes=json.loads((Path(__file__).resolve().parents[1]/'godot/tests/fixtures/pc_campaign_steps.json').read_text())
        self.assertEqual(set(routes),{'new','continue'})
        for route in routes.values():
            for frames,keys in route:
                self.assertTrue(1<=frames<=600)
                self.assertTrue(set(keys)<=set(KEYS))
        self.assertEqual(routes['new'][-2:],[[3,['return']],[600,[]]])

    def test_active_psp_not_resident_code_decides_program(self):
        ram = program_ram('START')
        before = bytes(ram)
        self.assertEqual(active_program(ram)['name'],'START')
        self.assertEqual(active_program(ram)['load_segment'],0x1ED)
        self.assertEqual(bytes(ram),before)
        for address, value in [(0xB30,0),(0x1DC0,0),(0x1DC1,0),(0x1DD0,0),(0x1DC8,255)]:
            damaged = bytearray(ram)
            damaged[address] = value
            self.assertIsNone(active_program(damaged))

    def make_session(self):
        core = SimpleNamespace(frame=0,ram=program_ram(),last_video_ram=None,last_video=('video',))
        core.conventional_memory = lambda: core.ram
        def run(frames,keys):
            self.assertEqual(frames,1)
            core.frame += frames
            core.last_video_ram = bytes(core.ram)
        core.run = run
        reader = SimpleNamespace(locate=lambda ram: 0x1ED0,
                                 read=lambda ram: {'load_segment':0x1ED})
        observations = []
        class FakeCollector:
            def __init__(self,*args,**kwargs):
                self.error=None
                self.audio=SimpleNamespace(drain=lambda: [])
            def attach(self,core,segment): observations.append(('attach',segment))
            def detach(self,core): observations.append(('detach',))
            def paired_video(self,video): return {'draw_pass':{'sequence':1}}
        session = PresentationSession(core,reader,b'shape',collector_factory=FakeCollector)
        return core,session,observations

    def test_program_exit_discards_geometry_and_reentry_gets_new_epoch(self):
        core,session,events = self.make_session()
        session.step(2)
        self.assertEqual(session.sample()['render_epoch'],1)
        self.assertEqual(len(events),1)
        core.ram = program_ram('END') # Fake reader still finds resident SIM.
        session.step(1)
        sample = session.sample()
        self.assertIsNone(sample['state'])
        self.assertIsNone(sample['presentation']['draw_pass'])
        self.assertIsNone(session.collector)
        core.ram = program_ram('SIM')
        session.step(1)
        self.assertEqual(session.sample()['render_epoch'],2)
        session.close()
        self.assertEqual(events,[('attach',0x1ED),('detach',),('attach',0x1ED),('detach',)])

    def test_wrong_shape_buffer_cannot_supply_observed_geometry(self):
        core,session,_ = self.make_session()
        core.ram[0x80000] = 0
        session.step(1)
        with self.assertRaisesRegex(ValueError,'SHAPE.TBL'): session.sample()
        session.close()

    def test_program_identity_must_agree_with_fingerprinted_load_address(self):
        core,session,events = self.make_session()
        session.reader.locate = lambda ram: 0x2ED0
        session.step(1)
        self.assertEqual(events,[])
        self.assertIsNone(session.sample()['state'])
        self.assertIsNone(session.sample()['presentation']['draw_pass'])

    def test_initialization_waits_for_resources_before_reporting_state(self):
        core,session,_ = self.make_session()
        core.ram[0x80000] = 0
        session.step(1)
        session.collector.paired_video = lambda video: {'draw_pass':None}
        self.assertIsNone(session.sample()['state'])
        core.ram[0x80000] = ord('s')
        session.step(1)
        self.assertIsNotNone(session.sample()['state'])
        session.close()

    def test_sample_uses_framebuffer_paired_program_not_newer_RAM(self):
        core,session,_ = self.make_session()
        core.ram = program_ram('START')
        session.step(1)
        core.ram = program_ram('SIM')
        session.before_frame()
        # The next SIM frame has not been submitted yet.
        sample = session.sample()
        self.assertEqual(sample['program']['name'],'START')
        self.assertIsNone(sample['state'])
        self.assertIsNone(sample['presentation']['draw_pass'])
        session.step(1)
        self.assertIsNotNone(session.sample()['presentation']['draw_pass'])
        session.close()


if __name__ == '__main__': unittest.main()
