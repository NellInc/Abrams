"""Promo tooling regressions: paid-call gates, recovery, fail-closed checks. No network."""
import hashlib
import importlib
import json
import sys
import tempfile
import types
import unittest
import wave
from pathlib import Path
from unittest import mock

PROMO = Path(__file__).resolve().parents[1] / 'tools/promo'
if str(PROMO) not in sys.path:
    sys.path.insert(0, str(PROMO))
try:
    import opentimelineio  # noqa: F401
except ImportError:  # revise.py imports it at module level; none of these paths use it
    sys.modules['opentimelineio'] = types.ModuleType('opentimelineio')

import burn_captions  # noqa: E402,F401  (import must stay valid)
import captions_critic  # noqa: E402
import compose  # noqa: E402
import generate  # noqa: E402
import revise  # noqa: E402
import v3_audio  # noqa: E402


class Response:
    def __init__(self, status, payload=None, content=b'', content_type='application/json'):
        self.status_code, self._payload, self.content = status, payload, content
        self.headers = {'content-type': content_type}
        self.text = json.dumps(payload) if payload is not None else ''

    def json(self):
        return self._payload


def silent_wav(path, seconds=.5, rate=16000):
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate); w.writeframes(b'\0\0' * int(seconds * rate))


def authorize(folder, approved=True, budget=5):
    (folder / 'authorization.json').write_text(json.dumps({'paid_generation_approved': approved, 'budget_usd': budget}))


class CaptionsAsrGate(unittest.TestCase):
    """F008: hosted whisper-1 captions go through budget() and leave a receipt."""

    def run_captions(self, out):
        media = out.parent / 'promo.wav'
        silent_wav(media)
        calls = []

        def fake(method, path, **kw):
            calls.append((method, path))
            return Response(200, {'text': 'Abrams', 'words': [{'word': ' Abrams', 'start': 0.0, 'end': 0.4}], 'usage': {'seconds': 1}})
        with mock.patch.object(generate, 'request', fake), mock.patch('builtins.print'):
            captions_critic.transcribe(media, out, 'openai/whisper-1')
        return calls

    def test_unapproved_run_never_calls_the_api(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / 'review'; out.mkdir(); authorize(out, approved=False)
            with mock.patch.object(generate, 'request', side_effect=AssertionError('paid call issued')):
                with self.assertRaisesRegex(RuntimeError, 'not been authorized'):
                    silent_wav(Path(d) / 'promo.wav')
                    captions_critic.transcribe(Path(d) / 'promo.wav', out, 'openai/whisper-1')
            self.assertFalse((out / 'paid-ledger.json').exists())

    def test_missing_authorization_refuses(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / 'review'; out.mkdir(); silent_wav(Path(d) / 'promo.wav')
            with mock.patch.object(generate, 'request', side_effect=AssertionError('paid call issued')):
                with self.assertRaises(FileNotFoundError):
                    captions_critic.transcribe(Path(d) / 'promo.wav', out, 'openai/whisper-1')

    def test_approved_run_is_ledgered_received_and_not_repeatable(self):
        with tempfile.TemporaryDirectory() as d:
            production = Path(d); out = production / 'final-review'; out.mkdir(); authorize(production)
            calls = self.run_captions(out)
            self.assertEqual(calls, [('POST', '/audio/transcriptions')])
            ledger = json.loads((production / 'paid-ledger.json').read_text())
            self.assertEqual([e['action'] for e in ledger], ['captions-asr'])
            proof = json.loads((production / 'captions-asr-receipt.json').read_text())
            self.assertEqual(proof['audio_sha256'], hashlib.sha256((out / 'asr-input.wav').read_bytes()).hexdigest())
            self.assertEqual(proof['source_sha256'], hashlib.sha256((production / 'promo.wav').read_bytes()).hexdigest())
            with self.assertRaisesRegex(RuntimeError, 'already has a ledger reservation'):
                self.run_captions(out)


class LoudnessFailsClosed(unittest.TestCase):
    """F088: an unmeasured loudness pass can never satisfy the acceptance gate."""
    SAMPLE = '[Parsed_loudnorm_0 @ 0x1]\n{\n\t"input_i" : "-16.20",\n\t"input_tp" : "-1.80",\n\t"input_lra" : "5.0"\n}\n'

    def test_missing_garbled_or_failed_measurements_are_false(self):
        for code, stderr in [(0, ''), (0, '{ "input_i" : nonsense }'), (1, self.SAMPLE), (0, '{"input_i" : "x", "input_tp": "-2"}')]:
            checks, _ = captions_critic.loudness_checks(code, stderr)
            self.assertEqual(set(checks), {'loudness_measured', 'true_peak_below_minus_1_db', 'integrated_loudness_in_delivery_range'})
            self.assertFalse(all(checks.values()), (code, stderr))

    def test_measured_values_are_judged(self):
        checks, metrics = captions_critic.loudness_checks(0, self.SAMPLE)
        self.assertTrue(all(checks.values()))
        self.assertEqual(metrics['input_i'], '-16.20')
        loud, _ = captions_critic.loudness_checks(0, self.SAMPLE.replace('-1.80', '-0.40'))
        self.assertFalse(loud['true_peak_below_minus_1_db'])


class VideoRecovery(unittest.TestCase):
    """F082: free status/content GETs retry transient faults; recovery never resubmits."""

    def setUp(self):
        self.dir = tempfile.TemporaryDirectory(); self.out = Path(self.dir.name)
        (self.out / 'motion/media').mkdir(parents=True)
        (self.out / 'paid-ledger.json').write_text(json.dumps([{'action': 'seedance-exterior', 'reserved_usd': 4, 'state': 'submitted_or_uncertain'}]))
        self.calls = []
        self.patches = [mock.patch.object(generate, 'secret', lambda *a: 'token'), mock.patch.object(generate.time, 'sleep', lambda s: None),
                        mock.patch('builtins.print')]
        for p in self.patches: p.start()

    def tearDown(self):
        for p in self.patches: p.stop()
        self.dir.cleanup()

    def script(self, *responses):
        queue = list(responses)

        def fake(method, url, **kw):
            self.calls.append((method, url))
            item = queue.pop(0)
            if isinstance(item, Exception): raise item
            return item
        return mock.patch.object(generate.requests, 'request', fake)

    def test_transient_poll_faults_still_finish(self):
        with self.script(Response(502, {}), generate.requests.ConnectionError('blip'), Response(200, {'id': 'job', 'status': 'completed'}),
                         Response(200, content=b'mp4', content_type='video/mp4')):
            generate.finish_video(self.out, 'seedance-exterior', 'm', 'p', {'id': 'job', 'status': 'queued'})
        self.assertEqual((self.out / 'motion/media/seedance-exterior.mp4').read_bytes(), b'mp4')
        self.assertEqual(json.loads((self.out / 'paid-ledger.json').read_text())[0]['state'], 'completed')
        self.assertEqual(json.loads((self.out / 'seedance-exterior-receipt.json').read_text())['job_id'], 'job')
        self.assertTrue(all(m == 'GET' for m, _ in self.calls))

    def test_client_errors_are_not_retried(self):
        with self.script(Response(404, {})):
            with self.assertRaisesRegex(RuntimeError, 'HTTP 404'):
                generate.free_get('/videos/job', generate.time.monotonic() + 60)
        self.assertEqual(len(self.calls), 1)

    def test_paid_post_is_never_retried(self):
        with self.script(Response(503, {})):
            with self.assertRaisesRegex(RuntimeError, 'No automatic paid retry'):
                generate.request('POST', '/videos', json={})
        self.assertEqual(len(self.calls), 1)

    def test_recover_uses_receipt_without_budget_or_post(self):
        generate.receipt(self.out, 'seedance-exterior', {'model': 'm', 'prompt': 'p', 'job_id': 'job', 'status': 'queued'})
        with mock.patch.object(generate, 'budget', side_effect=AssertionError('budget touched')), \
                self.script(Response(200, {'id': 'job', 'status': 'succeeded'}), Response(200, content=b'v', content_type='video/mp4')):
            generate.recover_video(self.out, 'seedance-exterior')
        self.assertEqual(self.calls, [('GET', generate.BASE + '/videos/job'), ('GET', generate.BASE + '/videos/job/content?index=0')])
        self.assertTrue((self.out / 'motion/media/seedance-exterior.mp4').exists())

    def test_same_paid_action_is_still_refused(self):
        authorize(self.out)
        with self.assertRaisesRegex(RuntimeError, 'already has a ledger reservation'):
            generate.budget(self.out, 'seedance-exterior', 4)


class AnimaticConcat(unittest.TestCase):
    """F083: --final --animatic concatenates only animatic cards that exist."""

    def test_final_receipt_swap_keeps_animatic_cards(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / 'promo'
            brief = {'shots': [{'id': 'opening', 'duration': 30}, {'id': 'closing', 'duration': 30}]}

            def swap(b, o, final):
                b['shots'] = [{'id': 'crew'}, {'id': 'reveal'}]
                return o / 'motion/index.html'
            listed = []

            def run(*args):
                concat = Path(args[list(map(str, args)).index('-i') + 1])
                listed.extend(line.split("'")[1] for line in concat.read_text().splitlines() if line.startswith('file'))
            with mock.patch.object(compose, 'prepare', lambda b, o: brief), mock.patch.object(compose, 'card', lambda s, p: p.write_bytes(b'png')), \
                    mock.patch.object(compose, 'make_html', swap), mock.patch.object(compose, 'timeline', lambda *a: None), \
                    mock.patch.object(compose, 'run', run), mock.patch.object(sys, 'argv', ['compose.py', '--output', str(out), '--final', '--animatic']), \
                    mock.patch('builtins.print'):
                compose.main()
            self.assertEqual([Path(p).name for p in listed], ['opening.png', 'closing.png', 'closing.png'])
            self.assertTrue(all(Path(p).exists() for p in listed))


class ReviseInputs(unittest.TestCase):
    """F085: revise.py refuses before replacing any media when its base is unusable."""

    def test_missing_or_self_base_changes_nothing(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d)
            for base in [out / 'gone/index.html', out / 'motion/index.html']:
                if base.parent.name == 'motion':
                    base.parent.mkdir(parents=True); base.write_text('<style>.logo-bug{}</style>')
                with self.assertRaises(SystemExit):
                    revise.make(out, 60, base_html=base)
                self.assertFalse((out / 'motion/media').exists())

    def test_base_already_carrying_v2_styles_is_refused(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d); base = out / 'v2.html'; base.write_text('<style>a{}.logo-bug{x}</style>')
            for mode in ['genesis', 'modern']:
                (out / 'colonel-stills').mkdir(exist_ok=True); (out / f'colonel-stills/colonel-{mode}.png').write_bytes(b'')
            (out / 'model-pairs').mkdir()
            for index in [125, 163, 161, 155, 156]: (out / f'model-pairs/pair-{index:03}.png').write_bytes(b'')
            with self.assertRaisesRegex(SystemExit, 'v2 styles'):
                revise.make(out, 60, picture_only=True, base_html=base)
            self.assertFalse((out / 'motion/media').exists())


class V3Sources(unittest.TestCase):
    """F087: dry-ASR attests the brief's narration_files, not fixed v3 names."""

    def test_sources_follow_narration_files(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d); media = out / 'motion/media'; media.mkdir(parents=True)
            files = ['narration-v4-part-0-dry.wav', 'narration-v3-part-1-dry.wav', 'narration-v4-part-2-dry.wav']
            chunks = ['Four crew.', 'One tank.', 'Your command.']
            for i, name in enumerate(files): (media / name).write_bytes(f'audio {i}'.encode())
            (media / 'narration-v3-part-0-dry.wav').write_bytes(b'stale v3 take')
            (out / 'approved-script.json').write_text(json.dumps({'narration_chunks': chunks, 'narration_files': files}))
            heard = []

            def asr(o, path, action, model='openai/whisper-1'):
                heard.append(path.name)
                return {'text': chunks[files.index(path.name)], 'words': [{'start': 0, 'end': 1}]}
            with mock.patch.object(v3_audio, 'asr', asr), mock.patch('builtins.print'):
                v3_audio.sources(out)
            self.assertEqual(sorted(heard), sorted(files))
            for i, name in enumerate(files):
                proof = json.loads((out / f'dry-word-check-{i}.json').read_text())
                self.assertEqual((proof['file'], proof['source_sha256']), (name, hashlib.sha256((media / name).read_bytes()).hexdigest()))


class CaptionOrdering(unittest.TestCase):
    """F089: producer output always satisfies the burner's strict ordering."""

    def test_sub_millisecond_overlap_is_absorbed(self):
        records = []
        for start, end in [(0.0, 1.0), (0.9995, 2.0), (2.0, 3.0)]:
            records.append(v3_audio.ordered_cue(records, {'start': start, 'end': end, 'text': 'x'}))
        self.assertEqual(records[1]['start'], 1.0)
        last = 0
        for cue in records:
            self.assertTrue(cue['start'] >= last and cue['end'] > cue['start']); last = cue['end']

    def test_real_overlap_is_not_hidden(self):
        records = [{'start': 0.0, 'end': 1.0}]
        self.assertEqual(v3_audio.ordered_cue(records, {'start': 0.9, 'end': 2.0})['start'], 0.9)


if __name__ == '__main__':
    unittest.main()
