"""Private candidate checks. All real children are synthetic short Python jobs."""
import contextlib
import importlib.util
import io
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / 'tools/standalone/portable_launcher.py'
spec = importlib.util.spec_from_file_location('private_portable_launcher', SOURCE)
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)


class PortableOutputTests(unittest.TestCase):
    def run_child(self, script, timeout=3):
        return launcher.invoke_runtime([sys.executable, '-c', script], timeout)

    def test_both_pipes_exceed_pipe_capacity_and_keep_only_tails(self):
        result = self.run_child("import os\nfor _ in range(128):\n os.write(1,b'o'*8192)\n os.write(2,b'e'*8192)\nos.write(1,b'OUT_END');os.write(2,b'ERR_END')")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(len(result.stdout), launcher.OUTPUT_TAIL_BYTES)
        self.assertEqual(len(result.stderr), launcher.OUTPUT_TAIL_BYTES)
        self.assertTrue(result.stdout.endswith('OUT_END'))
        self.assertTrue(result.stderr.endswith('ERR_END'))

    def test_utf8_and_nonzero_failure_output(self):
        result = self.run_child("import os,sys;os.write(1,'Ready: café 坦克\\n'.encode());os.write(2,'Failure: réessayer\\n'.encode());sys.exit(7)")
        self.assertEqual(result.returncode, 7)
        self.assertEqual(result.stdout, 'Ready: café 坦克\n')
        self.assertEqual(result.stderr, 'Failure: réessayer\n')
        with patch.object(launcher, 'verify'), patch.object(launcher, 'invoke_runtime', return_value=result), patch.object(sys, 'argv', ['launcher', '--bundle', '/synthetic', '--invoke', '--status']), contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(launcher.main(), 7)
            self.assertEqual(output.getvalue(), result.stderr)

    def test_timeout_reaps_only_owned_direct_child(self):
        children = []
        original = subprocess.Popen
        def spawn(*args, **kwargs):
            child = original(*args, **kwargs)
            children.append(child)
            return child
        with patch.object(launcher.subprocess, 'Popen', side_effect=spawn):
            with self.assertRaises(subprocess.TimeoutExpired):
                self.run_child('import time;time.sleep(5)', timeout=0.05)
        self.assertEqual(len(children), 1)
        self.assertIsNotNone(children[0].poll())
        self.assertNotEqual(children[0].returncode, 0)

    def test_drain_start_failure_reaps_owned_child(self):
        children = []
        original = subprocess.Popen
        def spawn(*args, **kwargs):
            child = original(*args, **kwargs)
            children.append(child)
            return child
        with patch.object(launcher.subprocess, 'Popen', side_effect=spawn), patch.object(launcher.threading.Thread, 'start', side_effect=RuntimeError('synthetic thread limit')):
            with self.assertRaisesRegex(subprocess.SubprocessError, 'could not start'):
                self.run_child('import time;time.sleep(5)')
        self.assertIsNotNone(children[0].poll())
        self.assertTrue(children[0].stdout.closed and children[0].stderr.closed)

    def test_setup_300_seconds_and_gameplay_no_timeout(self):
        for extra, expected in [(['--status'], 300), (['--play'], None)]:
            with self.subTest(extra=extra), patch.object(launcher, 'verify'), patch.object(launcher, 'invoke_runtime', return_value=subprocess.CompletedProcess([],0,'{}','')) as invoke, patch.object(sys, 'argv', ['launcher', '--bundle', '/synthetic', '--invoke', *extra]), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(launcher.main(), 0)
                self.assertEqual(invoke.call_args.kwargs['timeout'], expected)

    def test_owned_cleanup_is_graceful_first_with_bounded_kill_fallback(self):
        for startup_failure in (False, True):
            for ignores_terminate in (False, True):
                with self.subTest(startup_failure=startup_failure, ignores_terminate=ignores_terminate):
                    events = []
                    class FakeChild:
                        killed = False
                        stdout = io.BytesIO(b'out')
                        stderr = io.BytesIO(b'error')
                        def poll(self):
                            events.append(('poll',))
                            return None
                        def terminate(self):
                            events.append(('terminate',))
                        def kill(self):
                            events.append(('kill',))
                            self.killed = True
                        def wait(self, timeout=None):
                            events.append(('wait', timeout))
                            if timeout == 0.05 or (timeout == 1 and ignores_terminate and not self.killed):
                                raise subprocess.TimeoutExpired(['synthetic'], timeout)
                            return -15
                    child = FakeChild()
                    with patch.object(launcher.subprocess, 'Popen', return_value=child), contextlib.ExitStack() as stack:
                        if startup_failure:
                            stack.enter_context(patch.object(launcher.threading.Thread, 'start', side_effect=RuntimeError('synthetic startup failure')))
                        with self.assertRaises(subprocess.SubprocessError if startup_failure else subprocess.TimeoutExpired):
                            launcher.invoke_runtime(['synthetic'], 0.05)
                    cleanup = [('poll',), ('terminate',), ('wait', 1)]
                    if ignores_terminate: cleanup += [('kill',), ('wait', 1)]
                    self.assertEqual(events, cleanup if startup_failure else [('wait', 0.05)] + cleanup)

    def test_unreapable_child_surfaces_bounded_cleanup_failure(self):
        events = []
        class UnreapableChild:
            stdout = io.BytesIO(b'')
            stderr = io.BytesIO(b'')
            def poll(self): return None
            def terminate(self): events.append('terminate')
            def kill(self): events.append('kill')
            def wait(self, timeout=None):
                events.append(timeout)
                if timeout is None: raise AssertionError('Unbounded reap')
                raise subprocess.TimeoutExpired(['synthetic'], timeout)
        with patch.object(launcher.subprocess, 'Popen', return_value=UnreapableChild()):
            with self.assertRaisesRegex(subprocess.SubprocessError, 'did not exit'):
                launcher.invoke_runtime(['synthetic'], 0.05)
        self.assertEqual(events, [0.05, 'terminate', 1, 'kill', 1])


if __name__ == '__main__':
    unittest.main()
