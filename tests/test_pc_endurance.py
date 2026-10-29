from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch, call
from tests._inputs import requires

from tools.verify_pc_endurance import BoundedClient, campaign_record, percentile, native_rss_kib, source_hashes, rnr_choice


class EnduranceGateTests(unittest.TestCase):
    @staticmethod
    def rnr_packet(choice):
        import base64, hashlib, io
        from PIL import Image
        program = {'name': 'END', 'load_segment': 493}
        from tools.pc_fonts import decode_font, text_pixels
        font = decode_font((Path(__file__).resolve().parents[1]/'GAME/STENCIL.FNT').read_bytes())
        palette = [[i*13, i*11, i*7] for i in range(16)]
        image = Image.new('RGB', (320, 200))
        specs = [('NOW WHAT SOLDIER?', 0xa1c, [92, 90, 136, 8], 0xc71, (1, 4)),
                 ('TAKE R&R', 0xa2e, [92, 102, 64, 8], 0xe10, (4, 1) if choice == 'rest' else (1, 4)),
                 ('CONTINUE', 0xa37, [164, 102, 64, 8], 0xe10, (1, 4) if choice == 'rest' else (4, 1))]
        rows = []
        for text, pointer, rect, ip, colours in specs:
            x, y, width, height = rect
            w, h, ink = text_pixels(font, text.encode('ascii'))
            self_rgb = b''.join(bytes(palette[colours[0] if bit else colours[1]]) for bit in ink)
            image.paste(Image.frombytes('RGB', (w, h), self_rgb), (x, y))
            rows.append({'text': text, 'source_pointer': pointer, 'rect': rect, 'return_ip': ip,
                         'foreground': colours[0], 'background': colours[1],
                         'font_sha256': '3f92e8c7488278d86aeaa978d87d980d6a688fc9c8dbf87befaf4e6bbc9f4181',
                         'basis': 'completed original string and exact full current glyph cell; original highlight colours retained',
                         'pixel_sha256': hashlib.sha256(image.crop((x, y, x+width, y+height)).tobytes()).hexdigest()})
        png = io.BytesIO(); image.save(png, format='PNG')
        return {'program': program, 'presentation': {'frontend_program': program.copy(), 'text_runs': rows, 'palette_rgb': palette},
                'png': base64.b64encode(png.getvalue()).decode()}

    @requires('GAME')
    def test_rnr_both_valid_highlight_roles_classify_and_rest_admission_is_separate(self):
        for choice in ('continue', 'rest'):
            with self.subTest(choice=choice):
                classified = rnr_choice(self.rnr_packet(choice))
                self.assertEqual(classified, choice)
                self.assertEqual(classified == 'rest', choice == 'rest')
        self.assertIsNone(rnr_choice({'program': {'name': 'END'}, 'presentation': {'text_runs': []}}))

    @requires('GAME')
    def test_rnr_partial_stale_or_inconsistent_source_cells_fail_closed(self):
        import copy
        packet = self.rnr_packet('rest')
        changes = [('source_pointer', 0), ('rect', [91, 102, 64, 8]), ('return_ip', 0),
                   ('font_sha256', 'stale'), ('basis', 'partial'), ('pixel_sha256', 'unpaired'),
                   ('foreground', 1)]
        for key, value in changes:
            with self.subTest(key=key), self.assertRaises(ValueError):
                bad = copy.deepcopy(packet); bad['presentation']['text_runs'][1][key] = value; rnr_choice(bad)
        for kind in ('missing', 'duplicate', 'program', 'frontend', 'png', 'metadata'):
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                bad = copy.deepcopy(packet)
                if kind == 'missing': bad['presentation']['text_runs'].pop()
                if kind == 'duplicate': bad['presentation']['text_runs'].append(bad['presentation']['text_runs'][0].copy())
                if kind == 'program': bad['program'] = {'name': 'START'}
                if kind == 'frontend': bad['presentation']['frontend_program'] = {'name': 'END', 'load_segment': 999}
                if kind == 'png': bad.pop('png')
                if kind == 'metadata': bad['presentation']['text_runs'][1].pop('foreground')
                rnr_choice(bad)

    @requires('GAME')
    def test_rnr_current_glyph_pixels_are_required_but_whole_frame_hash_is_not(self):
        import base64, io
        from PIL import Image
        packet = self.rnr_packet('continue')
        image = Image.open(io.BytesIO(base64.b64decode(packet['png']))).convert('RGB')
        image.putpixel((0, 0), (1, 2, 3))
        png = io.BytesIO(); image.save(png, format='PNG'); packet['png'] = base64.b64encode(png.getvalue()).decode()
        self.assertEqual(rnr_choice(packet), 'continue')
        image.putpixel((164, 102), (255, 255, 255))
        png = io.BytesIO(); image.save(png, format='PNG'); packet['png'] = base64.b64encode(png.getvalue()).decode()
        with self.assertRaises(ValueError): rnr_choice(packet)

    @requires('GAME')
    def test_rnr_colours_only_swap_with_unchanged_png_and_hashes_is_rejected(self):
        import copy
        packet = self.rnr_packet('continue')
        original_png = packet['png']
        original_hashes = [r['pixel_sha256'] for r in packet['presentation']['text_runs']]
        for row in packet['presentation']['text_runs'][1:]:
            row['foreground'], row['background'] = row['background'], row['foreground']
        self.assertEqual(packet['png'], original_png)
        self.assertEqual([r['pixel_sha256'] for r in packet['presentation']['text_runs']], original_hashes)
        with self.assertRaises(ValueError): rnr_choice(packet)
        ambiguous = self.rnr_packet('rest')
        ambiguous['presentation']['palette_rgb'][4] = ambiguous['presentation']['palette_rgb'][1]
        with self.assertRaises(ValueError): rnr_choice(ambiguous)
        # Fully swapped source pixels AND metadata are the legitimate other choice.
        self.assertEqual(rnr_choice(self.rnr_packet('rest')), 'rest')

    def test_campaign_record_keeps_played_markers_separate_from_victory(self):
        import hashlib, struct
        raw = struct.pack('<HBB', 55, 1, 0) + bytes([0, 0, 1, 0, 0, 0, 0, 0]) + bytes(38)
        record = campaign_record(raw)
        self.assertEqual(record['mission_count'], 1)
        self.assertEqual(record['career_status'], 0)
        self.assertEqual(record['played_markers'], [0, 0, 1, 0, 0, 0, 0, 0])
        self.assertEqual(record['sha256'], hashlib.sha256(raw).hexdigest())
        self.assertNotIn('victory', record)

    def test_campaign_terminal_status_is_not_an_objective_verdict(self):
        import struct
        raw = struct.pack('<HBB', 0, 8, 3) + bytes([1]*8) + bytes(38)
        record = campaign_record(raw)
        self.assertEqual(record['mission_count'], 8)
        self.assertEqual(record['career_status'], 3)
        self.assertEqual(record['score_raw_u16'], 0)
        self.assertNotIn('victory', record)

    def test_campaign_record_refuses_incomplete_and_invalid_fields(self):
        import struct
        malformed = [bytes(49), bytes(51), struct.pack('<HBB', 0, 9, 0) + bytes(46),
                     struct.pack('<HBB', 0, 1, 4) + bytes(46),
                     struct.pack('<HBB', 0, 1, 0) + bytes([2]) + bytes(45)]
        for raw in malformed:
            with self.subTest(raw=raw.hex()), self.assertRaises(ValueError):
                campaign_record(raw)

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
        # The receipt is under test here, not how the gate raises a refusal.
        refused = (AssertionError, RuntimeError)
        for fail, close_error, raised in [('save', None, refused), ('crash', 'host exited 1', RuntimeError)]:
            with self.subTest(fail=fail), tempfile.TemporaryDirectory() as directory:
                Fake.fail, Fake.close_error = fail, close_error
                output = Path(directory)/'out'
                with patch.object(gate, 'Client', Fake), patch.object(sys, 'argv', ['gate', '--output', str(output)]), \
                        patch('sys.stdout', io.StringIO()):
                    with self.assertRaises(raised) as caught:
                        gate.main()
                self.assertIn('native worker crashed' if fail == 'crash' else "'success': False", str(caught.exception))
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
