"""Promo tooling regressions: paid-call gates, recovery, fail-closed checks. No network."""
import hashlib
import importlib
import json
import re
import runpy
import shutil
import subprocess
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
import output_guard  # noqa: E402
import revise  # noqa: E402
import revise_v3  # noqa: E402
import v3_audio  # noqa: E402

REPO = PROMO.parents[1]


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


def authorize(folder, approved=True, budget=5, script='approved'):
    (folder / 'authorization.json').write_text(json.dumps({'paid_generation_approved': approved, 'budget_usd': budget}))
    if script is not None:
        (folder / 'production-state.json').write_text(json.dumps({'script_status': script}))


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


class OutputGuard(unittest.TestCase):
    """#72: every promo writer refuses a (miscased) output inside the original sources before writing."""
    WRITERS = [('assemble.py', ['mix']), ('av_review.py', ['--video', 'v.mp4']), ('burn_captions.py', []),
               ('captions_critic.py', ['captions', '--video', 'v.mp4']), ('capture.py', []), ('capture_combat.py', []),
               ('compose.py', []), ('generate.py', ['narration']), ('revise.py', []), ('revise_v3.py', []),
               ('revision_captions.py', []), ('v3_audio.py', ['sources']), ('v3_export.py', ['encode'])]

    def test_writers_reject_source_paths(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d).resolve(); (root / 'GAME').mkdir(); (root / 'GENESIS').mkdir()
            for script, args in self.WRITERS:
                for target in [root / 'game/promo', root / 'Genesis/x/promo']:
                    with self.subTest(script=script, target=target), mock.patch.object(output_guard, 'ROOT', root), \
                            mock.patch.object(sys, 'argv', [script, *args, '--output', str(target)]), \
                            mock.patch('sys.stderr'), self.assertRaises(SystemExit) as raised:
                        runpy.run_path(str(PROMO / script), run_name='__main__')
                    self.assertEqual(raised.exception.code, 2)
            self.assertEqual(sorted(p.name for p in root.rglob('*')), ['GAME', 'GENESIS'])

    def test_outside_path_is_returned_resolved(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d).resolve(); (root / 'GAME').mkdir()
            with mock.patch.object(output_guard, 'ROOT', root):
                self.assertEqual(output_guard.guarded_output(None, root / 'artifacts/../promo'), root / 'promo')


class ScriptApprovalGate(unittest.TestCase):
    """#177: paid calls fail closed unless the production records an approved script."""

    def test_absent_or_draft_state_refuses_and_approved_proceeds(self):
        for script in [None, 'draft']:
            with tempfile.TemporaryDirectory() as d, self.subTest(script=script):
                out = Path(d); authorize(out, script=script)
                with self.assertRaisesRegex(RuntimeError, 'on hold until Nell approves'):
                    generate.budget(out, 'narration', 1)
                self.assertFalse((out / 'paid-ledger.json').exists())
        with tempfile.TemporaryDirectory() as d:
            out = Path(d); authorize(out)
            generate.budget(out, 'narration', 1)
            self.assertEqual(json.loads((out / 'paid-ledger.json').read_text())[0]['action'], 'narration')

    def test_superseded_brief_is_not_voiced_over_a_production_script(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d); authorize(out)
            (out / 'approved-script.json').write_text(json.dumps({'narration': 'Four crew. One tank. Now, it is back!'}))
            with mock.patch.object(generate, 'budget', side_effect=AssertionError('budget touched')), \
                    mock.patch.object(sys, 'argv', ['generate.py', 'narration', '--output', str(out)]):
                with self.assertRaisesRegex(RuntimeError, 'superseded v1 template'):
                    generate.main()

    def test_superseded_brief_needs_the_production_script(self):
        template = json.loads((PROMO / 'brief.json').read_text())['narration']
        for script, error in [(None, 'approved-script.json does not exist'), ({'title': 'no lines'}, 'no narration string'),
                              ({'narration': template}, None)]:
            with tempfile.TemporaryDirectory() as d, self.subTest(script=script):
                out = Path(d); authorize(out)
                if script is not None:
                    (out / 'production-brief.json').write_text(json.dumps(script))
                with mock.patch.object(generate, 'budget', side_effect=AssertionError('budget touched')), \
                        mock.patch.object(generate, 'speech') as speech, \
                        mock.patch.object(sys, 'argv', ['generate.py', 'narration', '--output', str(out)]):
                    if error:
                        with self.assertRaisesRegex(RuntimeError, error):
                            generate.main()
                        speech.assert_not_called()
                    else:  # a v1 production whose own script is the template still voices it
                        generate.main()
                        self.assertEqual(speech.call_args.args[0]['narration'], template)


class PaidResultsKept(unittest.TestCase):
    """#73: a paid result is written even when motion/media does not exist yet, and an odd shape keeps its body."""
    BRIEF = {'speech_model': 'm', 'voice': 'Orus', 'narration': 'Abrams.', 'narration_direction': 'd', 'image_model': 'i'}

    def test_speech_creates_media_before_spending(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d); authorize(out)
            pcm = Response(200, content=b'\1\0' * 240, content_type='audio/pcm; rate=24000; channels=1')
            with mock.patch.object(generate, 'request', return_value=pcm), mock.patch('builtins.print'):
                generate.speech(dict(self.BRIEF), out, 'narration-pronunciation-v2-syllables')
            with wave.open(str(out / 'motion/media/narration-pronunciation-v2-syllables-dry.wav')) as w:
                self.assertEqual((w.getframerate(), w.getnframes()), (24000, 240))

    def test_unexpected_image_shape_keeps_raw_body_and_receipt(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d); authorize(out)
            body = {'data': [{'url': 'https://example.invalid/x.png'}]}
            reply = Response(200, body, content=json.dumps(body).encode())
            with mock.patch.object(generate, 'request', return_value=reply), mock.patch.object(generate, 'data_url', lambda p: 'data:'):
                with self.assertRaisesRegex(RuntimeError, 'raw body retained'):
                    generate.image(dict(self.BRIEF), out)
            raw = out / 'motion/media/tank-keyframe-response.json'
            self.assertEqual(json.loads(raw.read_text()), body)
            proof = json.loads((out / 'keyframe-receipt.json').read_text())
            self.assertEqual((proof['status'], proof['media_path']), ('response_unparsed', str(raw)))

    def test_image_success_writes_picture(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d); authorize(out)
            body = {'data': [{'b64_json': 'iVBORw=='}], 'created': 1}
            with mock.patch.object(generate, 'request', return_value=Response(200, body, content=json.dumps(body).encode())), \
                    mock.patch.object(generate, 'data_url', lambda p: 'data:'), mock.patch('builtins.print'):
                generate.image(dict(self.BRIEF), out)
            self.assertEqual((out / 'motion/media/tank-keyframe.png').read_bytes(), b'\x89PNG')
            self.assertNotIn('status', json.loads((out / 'keyframe-receipt.json').read_text()))


class ReviseV3Base(unittest.TestCase):
    """#175: revise_v3 takes --base-html and refuses an unusable base before any write."""

    def test_missing_self_or_wrong_base_changes_nothing(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d); (out / 'motion').mkdir()
            (out / 'motion/index.html').write_text('<style>.logo-bug{}.speed-options{}</style>')
            v1 = out / 'v1.html'; v1.write_text('<style>a{}</style>')
            for base, message in [(out / 'gone.html', 'missing'), (out / 'motion/index.html', 'not this revision output'), (v1, 'v2 styles')]:
                with self.assertRaisesRegex(SystemExit, message):
                    revise_v3.make(out, base)
            self.assertEqual(sorted(p.name for p in out.rglob('*')), ['index.html', 'motion', 'v1.html'])


@unittest.skipUnless(shutil.which('ffmpeg'), 'ffmpeg required')
class AhOnlySplice(unittest.TestCase):
    """#176: the ah-only take is rebuilt offline from the recorded splice, and its derivation is named."""

    def tone(self, path, seconds):
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'lavfi', '-i', f'sine=frequency=220:duration={seconds}:sample_rate=24000',
                        '-ac', '1', '-c:a', 'pcm_s16le', str(path)], check=True)

    def test_build_from_takes_and_refuse_to_replace(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d); media = out / 'motion/media'; media.mkdir(parents=True)
            with self.assertRaisesRegex(SystemExit, 'narration-pronunciation-v2-syllables'):
                revise.ah_only(out)
            self.tone(media / revise.AH_ONLY['sentence'], 3.9); self.tone(media / revise.AH_ONLY['syllables'], 3.0)
            with mock.patch('builtins.print'):
                revise.ah_only(out)
            target = media / 'narration-pronunciation-v2-ah-only-dry.wav'
            proof = json.loads((out / 'pronunciation-ah-only-edit-receipt.json').read_text())
            self.assertEqual((proof['recorded_inputs'], proof['matches_recorded_edit']), (False, False))
            self.assertEqual(proof['edited_sentence_sha256'], hashlib.sha256(target.read_bytes()).hexdigest())
            with wave.open(str(target)) as w:  # 3.9 s less 0.14 s, plus 0.43/1.8 s pickup, less two 20 ms fades
                self.assertAlmostEqual(w.getnframes() / w.getframerate(), 3.9 - .14 + .43 / 1.8 - .04, delta=.01)
            with self.assertRaisesRegex(SystemExit, 'already exists'):
                revise.ah_only(out)
            self.assertFalse((media / 'narration-pronunciation-v2-ah-pickup.wav').exists())

    def test_recorded_receipt_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d); media = out / 'motion/media'; media.mkdir(parents=True)
            self.tone(media / revise.AH_ONLY['sentence'], 3.9); self.tone(media / revise.AH_ONLY['syllables'], 3.0)
            proof = out / 'pronunciation-ah-only-edit-receipt.json'; proof.write_text('{"recorded": true}')
            with self.assertRaisesRegex(SystemExit, 'pronunciation-ah-only-edit-receipt.json already exists'):
                revise.ah_only(out)
            self.assertEqual(proof.read_text(), '{"recorded": true}')
            self.assertEqual(sorted(p.name for p in media.iterdir()), sorted([revise.AH_ONLY['sentence'], revise.AH_ONLY['syllables']]))

    def test_recorded_inputs_that_miss_the_recorded_edit_keep_the_candidate(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d); media = out / 'motion/media'; media.mkdir(parents=True)
            sentence, syllables = media / revise.AH_ONLY['sentence'], media / revise.AH_ONLY['syllables']
            self.tone(sentence, 3.9); self.tone(syllables, 3.0)
            digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()  # noqa: E731
            recorded = {**revise.AH_ONLY, 'sentence_sha256': digest(sentence), 'syllables_sha256': digest(syllables)}
            with mock.patch.dict(revise.AH_ONLY, recorded):
                with self.assertRaisesRegex(SystemExit, 'did not reproduce the recorded edit'):
                    revise.ah_only(out)
            self.assertTrue((media / 'narration-pronunciation-v2-ah-only-candidate.wav').stat().st_size > 0)
            self.assertFalse((media / 'narration-pronunciation-v2-ah-only-dry.wav').exists())
            self.assertFalse((media / 'narration-pronunciation-v2-ah-pickup.wav').exists())
            self.assertFalse((out / 'pronunciation-ah-only-edit-receipt.json').exists())

    def test_missing_input_error_names_the_derivation(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d); base = out / 'v1.html'; base.write_text('<style>a{}</style>')
            with self.assertRaisesRegex(SystemExit, 'pronunciation-ah-only-edit-receipt.json'):
                revise.make(out, 60, base_html=base)


class ProductionBrief(unittest.TestCase):
    """#179: captions check against the production's own script, never silently the v1 template."""

    def test_review_folder_prefers_production_brief(self):
        with tempfile.TemporaryDirectory() as d:
            production = Path(d); review = production / 'final-review'; review.mkdir()
            self.assertEqual(captions_critic.production_brief(review)['narration_status'], 'superseded')
            (production / 'production-brief.json').write_text(json.dumps({'narration': 'parent'}))
            self.assertEqual(captions_critic.production_brief(review)['narration'], 'parent')
            (review / 'production-brief.json').write_text(json.dumps({'narration': 'own'}))
            self.assertEqual(captions_critic.production_brief(review)['narration'], 'own')

    def test_skills_no_longer_claim_the_v1_script(self):
        for skill in ['abrams-promo-planning', 'abrams-emotive-speech']:
            text = (REPO / f'.agents/skills/{skill}/SKILL.md').read_text()
            self.assertNotIn('149-word', text)
            self.assertIn('approved-script.json', text)


class PromoGodotContract(unittest.TestCase):
    """#74/#181/#182: the promo Godot scripts never use assert(), parse only their clip window,
    and every viewer/frame/draw member they reach into still exists."""
    SCRIPTS = ['modern_batch.gd', 'replay.gd', 'colonel_stills.gd']
    SOURCES = {'viewer': 'godot/scripts/pc_bridge_viewer.gd', 'frame': 'godot/scripts/pc_tandem_frame.gd',
               'draw': 'godot/scripts/pc_draw_pass.gd'}
    MEMBERS = {'viewer': ['_apply_sample', 'invalidate_presentation_cache', 'anchor_path', 'startup_ready', 'play_mode', 'boot_mode',
                          'tandem_viewport', 'world_viewport', 'tandem_frame', 'draw_view', 'bridge', 'output', 'started'],
               'frame': ['modern_available', 'world_enabled', 'fallback_reason', 'graphics_mode', 'frontend_art', 'load_genesis_art',
                         'load_graphics_sources', 'set_graphics_mode', 'set_frame', 'present_frontend'],
               'draw': ['_modern_active', 'modern_enabled', 'modern_frame_status']}

    def test_no_assert_control_flow(self):
        for name in self.SCRIPTS:
            code = [line for line in (PROMO / name).read_text().splitlines() if not line.lstrip().startswith('#')]
            self.assertEqual([line for line in code if re.search(r'\bassert\s*\(', line)], [], name)

    def test_members_still_declared(self):
        text = {key: (REPO / path).read_text() for key, path in self.SOURCES.items()}
        used = ''.join((PROMO / name).read_text() for name in self.SCRIPTS)
        for key, names in self.MEMBERS.items():
            for member in names:
                self.assertIn(member, used, f'{member} no longer used; drop it from this contract')
                self.assertRegex(text[key], rf'(?m)^(?:static )?(?:func|var) {re.escape(member)}\b', f'{self.SOURCES[key]} lost {member}')

    def test_batch_skips_before_parsing(self):
        loop = (PROMO / 'modern_batch.gd').read_text().split('while not file.eof_reached():', 1)[1]
        self.assertLess(loop.index('if index>=clip.end: break'), loop.index('JSON.parse_string(line)'))
        self.assertLess(loop.index('if line.is_empty(): continue'), loop.index('if index<clip.begin:'))

    def test_replay_keeps_camera_less_fallbacks(self):
        # set_frame declares this fallback for every packet without a camera (frontends,
        # motor pool, debrief, map); replay may only fail pairing for camera-carrying SIM packets.
        self.assertIn('_fallback("no scanout-paired camera")', (REPO / self.SOURCES['frame']).read_text())
        replay = (PROMO / 'replay.gd').read_text()
        self.assertIn('program.get("name")=="SIM"', replay)
        self.assertIn('presentation.draw_pass.get("camera") is Dictionary', replay)
        pairing = [line for line in replay.splitlines() if 'not tandem_frame.world_enabled' in line]
        self.assertEqual(len(pairing), 1)
        self.assertTrue(pairing[0].lstrip().startswith('if scanout_camera and'), pairing[0])
        self.assertNotIn('paired=true', replay)


@unittest.skipUnless(shutil.which('node'), 'node required')
class MotionCanvasCompletion(unittest.TestCase):
    """#180: only a numeric 0 result with a fresh, non-empty MP4 is a successful render."""
    SCRIPT = '''import {verdict} from %s;
const [video, started] = [process.argv[1], Number(process.argv[2])];
const out = [];
for (const body of ['ok', '{"result":"0"}', '{"result":1}', '{"result":0}']) out.push(await verdict(body, video, started));
console.log(JSON.stringify(out));'''

    def run_verdicts(self, video, started):
        module = json.dumps((PROMO / 'motion-canvas/completion.mjs').as_uri())
        result = subprocess.run(['node', '--input-type=module', '-e', self.SCRIPT % module, str(video), str(started)],
                                capture_output=True, text=True, check=True)
        return json.loads(result.stdout)

    def test_verdicts(self):
        with tempfile.TemporaryDirectory() as d:
            video = Path(d) / 'checkpoint-marker.mp4'
            bad_json, bad_type, failed, missing = self.run_verdicts(video, 0)
            self.assertEqual((bad_json['status'], bad_type['status']), (400, 400))
            self.assertNotIn('result', bad_json)
            self.assertEqual((failed['result'], failed['receipt']), ({'result': 1}, False))
            self.assertEqual((missing['result']['result'], missing['receipt']), ('missing-output', False))
            video.write_bytes(b'mp4')
            ok = self.run_verdicts(video, 0)[3]
            self.assertEqual((ok['result']['result'], ok['result']['video_bytes'], ok['receipt']), (0, 3, True))
            stale = self.run_verdicts(video, (video.stat().st_mtime + 60) * 1000)[3]
            self.assertEqual(stale['result']['result'], 'missing-output')


if __name__ == '__main__':
    unittest.main()
