from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch, call

from tools.verify_pc_endurance import BoundedClient, percentile, native_rss_kib, source_hashes


class EnduranceGateTests(unittest.TestCase):
    def test_percentiles_are_defined_for_empty_and_small_sets(self):
        self.assertIsNone(percentile([], .95))
        self.assertEqual(percentile([3], .95), 3)
        self.assertEqual(percentile([3, 1, 2], .5), 2)

    def test_memory_sample_excludes_unrelated_processes(self):
        rows = '1 0 999\n10 1 100\n11 10 200\n12 11 300\n20 1 9999\n'
        with patch('tools.verify_pc_endurance.subprocess.check_output', return_value=rows):
            self.assertEqual(native_rss_kib(10), 600)

    def test_sources_detect_added_and_modified_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'GAME').mkdir(); (root/'GENESIS').mkdir()
            (root/'GAME/TEST').write_bytes(b'first')
            with patch('tools.verify_pc_endurance.ROOT', root):
                first = source_hashes()
                (root/'GAME/TEST').write_bytes(b'second')
                self.assertNotEqual(source_hashes(), first)
                first = source_hashes()
                (root/'GENESIS/NEW').write_bytes(b'added')
                self.assertNotEqual(source_hashes(), first)

    def test_long_fixture_steps_keep_inputs_and_respect_transport_limit(self):
        client = BoundedClient.__new__(BoundedClient)
        with patch('tools.verify_pc_endurance.Client.step', side_effect=[{'sequence': 600}, {'sequence': 1200}, {'sequence': 1201}]) as step:
            self.assertEqual(client.step(1201, ['return'])['sequence'], 1201)
            self.assertEqual(step.call_args_list, [call(600, ['return']), call(600, ['return']), call(1, ['return'])])
        with self.assertRaises(ValueError):
            client.step(0)

    def test_stale_simulation_check_allows_only_START_scenery(self):
        from tools.verify_pc_endurance import no_sim_geometry
        scene = {'frontend_scene': 'START/ANIM'}
        packet = lambda name, draw, state=None: {'program': {'name': name}, 'state': state, 'presentation': {'draw_pass': draw}}
        self.assertTrue(no_sim_geometry(packet('START', scene)))
        self.assertTrue(no_sim_geometry(packet('END', None)))
        self.assertTrue(no_sim_geometry({'program': None, 'state': None}))
        self.assertFalse(no_sim_geometry(packet('START', {'objects': []})))
        for name in ('END', 'BRIEF'):
            self.assertFalse(no_sim_geometry(packet(name, scene)))
        self.assertFalse(no_sim_geometry(packet('START', scene, {'station': 'driver'})))

    def test_save_state_receipt_is_truthful_when_a_run_aborts(self):
        import io, json, sys
        import tools.verify_pc_save_states as gate
        class Fake:
            close_error = None
            def __init__(self, directory, log):
                self.ready = {'protocol': 4, 'slots': [None]*6}
            def step(self, frames, keys=()):
                return {'type': 'sample', 'program': {'name': 'SIM'}, 'frame_audit': {},
                        'presentation': {'plate_overlay': {'mask_sha256': 'm', 'plates': {'a': {'pixels': 1}}}}}
            def request(self, op, **kwargs):
                if op == 'save_state' and Fake.fail == 'crash':
                    self.crashed = True; raise RuntimeError('native worker crashed')
                return {'success': False}
            def close(self):
                if getattr(self, 'crashed', False) and Fake.close_error: raise RuntimeError(Fake.close_error)
        for fail, close_error, raised in [('save', None, AssertionError), ('crash', 'host exited 1', RuntimeError)]:
            with self.subTest(fail=fail), tempfile.TemporaryDirectory() as directory:
                Fake.fail, Fake.close_error = fail, close_error
                output = Path(directory)/'out'
                with patch.object(gate, 'Client', Fake), patch.object(sys, 'argv', ['gate', '--output', str(output)]), \
                        patch('sys.stdout', io.StringIO()):
                    with self.assertRaises(raised) as caught:
                        gate.main()
                if fail == 'crash': self.assertIn('native worker crashed', str(caught.exception))
                report = json.loads((output/'report.json').read_text())
                self.assertIs(report['passed'], False)
                self.assertIs(report['completed'], False)
                self.assertTrue(report['error'])
                self.assertTrue(report['checks']['protocol4_preserved'])

    def test_save_state_client_close_reports_failed_host_and_releases_pipes(self):
        from tools.verify_pc_save_states import Client
        class Stream:
            closed = False
            def write(self, _): raise BrokenPipeError
            def flush(self): pass
            def close(self): self.closed = True
        client = Client.__new__(Client)
        client.process = type('P', (), {'poll': lambda self: None, 'wait': lambda self: 1})()
        client.process.stdin, client.process.stdout = Stream(), Stream()
        with self.assertRaisesRegex(RuntimeError, 'host exited 1'):
            client.close()
        self.assertTrue(client.process.stdin.closed and client.process.stdout.closed)

    def test_native_reply_buffer_preserves_multiple_packets(self):
        client = BoundedClient.__new__(BoundedClient)
        client.buffer = b'{"type":"sample","id":1}\n{"type":"sample","id":2}\n'
        self.assertEqual(client.read()['id'], 1)
        self.assertEqual(client.read()['id'], 2)

    def test_native_error_is_not_reported_as_completion(self):
        client = BoundedClient.__new__(BoundedClient)
        client.buffer = b'{"type":"error","message":"core failed"}\n'
        with self.assertRaisesRegex(RuntimeError, 'core failed'):
            client.read()


if __name__ == '__main__':
    unittest.main()
