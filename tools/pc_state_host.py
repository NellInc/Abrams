"""Save-state supervisor: one native lifetime per subprocess, one overlay lock.

The worker is closed before taking a disk snapshot. Candidate restores are
validated before any active disk replacement; failed restores roll back to the
freshly captured recovery image. No guest frames are spent priming a restore.
"""
from __future__ import annotations
import contextlib
import json
import os
from pathlib import Path
import queue
import shutil
import subprocess
import sys
import tempfile
import threading
import time
try:
    from tools.pc_state_store import StateStore, atomic_write, read_bounded, MAX_DISK
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from pc_state_store import StateStore, atomic_write, read_bounded, MAX_DISK

WORKER = Path(__file__).with_name('pc_bridge_host.py')
# After the client's stdin closes, an outstanding reply gets this long before the
# owned worker is killed; a reply in time keeps the graceful quit and final flush.
ORPHAN_GRACE = 5.0


def _pump(read, lines):
    # EOF ('') and read errors are queued too, so the consumer always wakes.
    while True:
        try: line = read()
        except Exception as error:
            lines.put(error)
            return
        lines.put(line)
        if not line: return


class Worker:
    client_closed = None  # supervise() binds its stdin-EOF event on a subclass
    killed = False

    def __init__(self, argv, lock, resume=None):
        command = [sys.executable, str(WORKER), *argv, '--state-worker']
        if resume: command += ['--local-resume', str(resume)]
        self.process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            text=True, bufsize=1, **({"pass_fds": (lock.fileno(),)} if os.name != "nt" else {}))
        # A thread, not select(): a worker wedged mid-line must still be observable.
        self.lines = queue.Queue()
        threading.Thread(target=_pump, args=(lambda: self.process.stdout.readline(40 * 1024 * 1024), self.lines), daemon=True).start()
        try:
            self.ready = self.read()
        except Exception:
            # Closing stdin lets the owned worker finish its own shutdown. Never
            # reinitialize its dylib or signal unrelated native processes.
            try: self.close()
            except Exception: pass
            raise

    def read(self):
        deadline = None
        while True:
            try:
                line = self.lines.get(timeout=0.25)
                break
            except queue.Empty:
                if self.client_closed is None or not self.client_closed.is_set(): continue
                if deadline is None: deadline = time.monotonic() + ORPHAN_GRACE
                if time.monotonic() < deadline: continue
                # The client is gone and the owned worker is unresponsive: kill only
                # this child, which also drops its inherited save-lock descriptor.
                self.killed = True
                self.process.kill()
                self.process.wait()
                for pipe in (self.process.stdin, self.process.stdout):
                    try: pipe.close()
                    except OSError: pass
                raise RuntimeError('Bridge client closed while the original-game worker was unresponsive; worker stopped')
        if isinstance(line, Exception): raise line
        if not line or not line.endswith('\n'):
            raise RuntimeError('Original-game worker ended before replying')
        message = json.loads(line)
        if message.get('type') == 'error': raise RuntimeError(message.get('message', 'Original-game worker failed'))
        return message

    def request(self, message):
        self.process.stdin.write(json.dumps(message, separators=(',', ':')) + '\n')
        self.process.stdin.flush()
        return self.read()

    def close(self):
        if self.killed: return
        if self.process.poll() is None:
            try:
                self.process.stdin.write('{"op":"quit"}\n')
                self.process.stdin.flush()
            except BrokenPipeError: pass
        # A worker that exits on its own (after 'captured') can leave unflushed
        # buffered bytes; close() then hits the same broken pipe.
        try: self.process.stdin.close()
        except BrokenPipeError: pass
        code = self.process.wait()
        self.process.stdout.close()
        if code: raise RuntimeError(f'Original-game worker failed with exit {code}')


@contextlib.contextmanager
def capture_workspace(root):
    # Preserve a recoverable native state even if a second restore fails.
    path = Path(tempfile.mkdtemp(prefix='.capture-', dir=root))
    try:
        yield path
    except Exception:
        raise
    else:
        shutil.rmtree(path)


def supervise(args, argv, lock_saves, validate_command):
    try:
        from tools.pc_reference_core import core_suffix
    except ModuleNotFoundError as error:
        if error.name != 'tools': raise
        from pc_reference_core import core_suffix
    core_path = args.core
    if args.backend == 'trace': core_path = Path(__file__).resolve().parents[1] / ('.runtime/pc-core/abrams-trace' + core_suffix())
    lock = worker = None
    def send(message):
        print(json.dumps(message, separators=(',', ':')), flush=True)
    # stdin is read on a thread so EOF is seen while a worker reply is outstanding.
    commands, client_closed = queue.Queue(), threading.Event()
    def read_stdin():
        try: _pump(lambda: sys.stdin.readline(8193), commands)
        finally: client_closed.set()
    try:
        # Inside the try so 'already open in another window' reaches the player.
        lock = lock_saves(args.saves)
        store = StateStore(args.saves, core_path, args.content, args.backend)
        threading.Thread(target=read_stdin, daemon=True).start()
        OwnedWorker = type('Worker', (Worker,), {'client_closed': client_closed})
        worker = OwnedWorker(argv, lock)
        ready = worker.ready
        ready.update(slots=store.slots(), save_states=args.backend == 'trace')
        send(ready)
        while True:
            line = commands.get()
            if isinstance(line, Exception): raise line
            if not line: break
            if len(line) > 8192: raise ValueError('oversized bridge command')
            command = json.loads(line)
            validate_command(command)
            if command['op'] == 'quit': break
            if command['op'] == 'step':
                send(worker.request(command))
                continue
            operation, slot = command['op'], command['slot']
            response = {'type': 'state_result', 'id': command['id'], 'success': False}
            try:
                if args.backend != 'trace': raise ValueError('Complete checkpoints require the trace backend')
                # All size, integrity and compatibility checks precede capture.
                selected = store.read(slot)[1] if operation == 'load_state' else None
                with capture_workspace(store.root) as directory:
                    capture = Path(directory)
                    result = worker.request({'op': '_capture', 'directory': str(capture)})
                    if result.get('type') != 'captured':
                        # The worker replied and is still live: nothing here needs recovery.
                        shutil.rmtree(capture, ignore_errors=True)
                        raise ValueError(result.get('message', 'Checkpoint capture failed'))
                    # The capture is complete once 'captured' arrives; a close fault must
                    # not strand a dead worker or skip recovery.
                    closing, worker = worker, None
                    try: closing.close()
                    except Exception as error: print(f'Checkpoint worker close: {error}', file=sys.stderr, flush=True)
                    disk = read_bounded(store.disk, MAX_DISK) if store.disk.exists() else b''
                    atomic_write(capture / 'campaign.zip', disk)
                    # Once the native worker has closed, always recover it even
                    # if a slot write fails (disk full, permissions, etc.).
                    try:
                        store.write(slot if operation == 'save_state' else 0, capture)
                        if selected:
                            with tempfile.TemporaryDirectory(prefix='.restore-', dir=store.root) as restore_dir:
                                restore = Path(restore_dir)
                                for name, raw in selected.items(): atomic_write(restore / name, raw)
                                store.install_disk(selected['campaign.zip'])
                                worker = OwnedWorker(argv, lock, restore)
                        else:
                            worker = OwnedWorker(argv, lock, capture)
                        response.update(success=True, message=f'Slot {slot} saved' if operation == 'save_state' else f'Slot {slot} loaded; previous session kept in recovery slot',
                                        restored=worker.ready | {'type': 'sample', 'id': command['id'], 'timeline_reset': True})
                    except Exception:
                        if worker is not None:
                            try: worker.close()
                            except Exception: pass
                            worker = None
                        store.install_disk(disk)
                        worker = OwnedWorker(argv, lock, capture)
                        response['restored'] = worker.ready | {'type': 'sample', 'id': command['id'], 'timeline_reset': True}
                        shutil.rmtree(capture)  # rollback succeeded; slot 0 remains the durable recovery
                        raise
            except Exception as error:
                response['message'] = str(error)
                if worker is None: raise RuntimeError('Checkpoint recovery failed; recovery files remain under states') from error
            response['slots'] = store.slots()
            send(response)
    except BrokenPipeError:
        pass
    except Exception as error:
        # The client may already be gone; keep the real error for the host log.
        try: send({'type': 'error', 'message': str(error)})
        except BrokenPipeError: pass
        raise
    finally:
        try:
            if worker: worker.close()
        finally:
            if lock is not None: lock.close()
