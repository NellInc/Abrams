import contextlib
import io
import json
from pathlib import Path
import shutil
import struct
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import MagicMock, patch
import zipfile
from tools.pc_bridge_host import validate_command
from tools.pc_state_store import StateStore, atomic_write, sha, sync_parent
from tools import pc_state_host


class SaveStateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root/'core').write_bytes(b'core')
        (self.root/'game.zip').write_bytes(b'game')
        self.store = StateStore(self.root/'saves', self.root/'core', self.root/'game.zip', 'trace')
        self.capture = self.root/'capture'; self.capture.mkdir()
        (self.capture/'state.bin').write_bytes(b'native-state')
        (self.capture/'resume.json').write_text(json.dumps({'frame': 42, 'sequence': 1, 'keys': [],
            'packet': {'program': {'name': 'SIM'}}, 'ram_sha256': 'a'*64}))
        self.disk = io.BytesIO()
        with zipfile.ZipFile(self.disk, 'w') as z: z.writestr('ROSTER.DAT', b'campaign-A')
        (self.capture/'campaign.zip').write_bytes(self.disk.getvalue())

    def test_control_commands_are_strict(self):
        for op in ('save_state','load_state'):
            validate_command({'op': op, 'id': 0, 'slot': 1})
            for changes in ({'slot': True},{'slot':6},{'id': True},{'id':-1},{'extra': 1}):
                with self.assertRaises(ValueError): validate_command({'op':op,'id':1,'slot':1}|changes)
        validate_command({'op':'load_state','id':1,'slot':0})
        with self.assertRaises(ValueError): validate_command({'op':'save_state','id':1,'slot':0})

    def test_windows_parent_sync_does_not_open_a_directory(self):
        with patch('tools.pc_state_store.os.name', 'nt'), patch('tools.pc_state_store.os.open') as opened:
            sync_parent(self.root)
        opened.assert_not_called()

    def test_atomic_replace_failure_preserves_previous_and_cleans_temporary(self):
        target = self.root / 'checkpoint'
        target.write_bytes(b'previous')
        with patch('tools.pc_state_store.os.replace', side_effect=PermissionError('busy destination')):
            with self.assertRaisesRegex(PermissionError, 'busy destination'):
                atomic_write(target, b'new')
        self.assertEqual(target.read_bytes(), b'previous')
        self.assertEqual(list(self.root.glob('.checkpoint-*')), [])

    def test_complete_roundtrip_previous_and_fixed_slots(self):
        self.store.write(1,self.capture)
        previous = self.store.path(1).read_bytes()
        _,files = self.store.read(1)
        self.assertEqual(files['campaign.zip'],self.disk.getvalue())
        (self.capture/'state.bin').write_bytes(b'changed')
        self.store.write(1,self.capture)
        self.assertEqual(self.store.path(1).with_suffix('.previous.zip').read_bytes(),previous)
        self.assertEqual(len(self.store.slots()),6)
        self.assertTrue(self.store.slots()[1]['valid'])
        with self.assertRaises(ValueError): self.store.read(2)
        with self.assertRaises(ValueError): self.store.path('../oops')

    def rewrite(self, edit):
        with zipfile.ZipFile(self.store.path(1)) as z: files = {name:z.read(name) for name in z.namelist()}
        edit(files)
        with zipfile.ZipFile(self.store.path(1),'w') as z:
            for name,data in files.items(): z.writestr(name,data)

    def test_optional_observer_roundtrip_and_integrity(self):
        # Old schema-1 archives stay readable without an observer companion.
        self.store.write(1, self.capture)
        self.assertNotIn('observer.bin', self.store.read(1)[1])
        (self.capture/'observer.bin').write_bytes(b'host-only-observer')
        self.store.write(1, self.capture)
        self.assertEqual(self.store.read(1)[1]['observer.bin'], b'host-only-observer')
        self.rewrite(lambda files: files.update({'observer.bin': b'changed'}))
        with self.assertRaisesRegex(ValueError, 'integrity'): self.store.read(1)

    def test_observer_is_bounded(self):
        (self.capture/'observer.bin').write_bytes(bytes(2 * 1024 * 1024 + 1))
        with self.assertRaisesRegex(ValueError, 'size limit'): self.store.write(1, self.capture)
        self.assertFalse(self.store.path(1).exists())

    def test_corruption_rejected(self):
        self.store.write(1,self.capture)
        self.rewrite(lambda files: files.update({'state.bin': b'tampered'}))
        with self.assertRaisesRegex(ValueError,'integrity'): self.store.read(1)
        self.assertFalse(self.store.slots()[1]['valid'])

    def damage(self, member, edit):
        # Damage the stored bytes in place (no re-zip), as disk or sync faults do.
        raw = bytearray(self.store.path(1).read_bytes())
        with zipfile.ZipFile(io.BytesIO(bytes(raw))) as z: info = z.getinfo(member)
        edit(raw, info)
        self.store.path(1).write_bytes(bytes(raw))

    def test_damaged_deflate_stream_is_an_invalid_slot_not_a_crash(self):
        (self.capture/'state.bin').write_bytes(b'native-state' * 512)
        def flip(raw, info):
            name, extra = struct.unpack('<HH', raw[info.header_offset+26:info.header_offset+30])
            start = info.header_offset + 30 + name + extra
            for k in range(2): raw[start+k] ^= 0xFF  # zlib.error: invalid code lengths set
        for member in ('state.bin', 'manifest.json'):
            self.store.write(1, self.capture)
            self.damage(member, flip)
            with self.assertRaisesRegex(ValueError, 'damaged checkpoint'): self.store.read(1)
            row = self.store.slots()[1]
            self.assertEqual((row['exists'], row['valid']), (True, False))
            self.assertIn('damaged checkpoint', row['message'])

    def test_unknown_compression_method_is_an_invalid_slot(self):
        self.store.write(1, self.capture)
        def method(raw, info):
            at = raw.find(b'PK\x01\x02')
            while at >= 0:
                if raw[at+46:at+46+struct.unpack('<H', raw[at+28:at+30])[0]] == b'state.bin':
                    raw[at+10:at+12] = struct.pack('<H', 99)
                at = raw.find(b'PK\x01\x02', at + 4)
        self.damage('state.bin', method)
        with self.assertRaisesRegex(ValueError, 'damaged checkpoint'): self.store.read(1)
        self.assertFalse(self.store.slots()[1]['valid'])

    def test_incompatible_rejected(self):
        self.store.write(1,self.capture)
        (self.root/'core').write_bytes(b'new core')
        new = StateStore(self.root/'saves',self.root/'core',self.root/'game.zip','trace')
        with self.assertRaisesRegex(ValueError,'different core'): new.read(1)

    def resign(self, raw, receipt):
        # Re-signing rewrites the core's bytes; the build receipt pins them.
        (self.root/'core').write_bytes(raw)
        (self.root/'core.json').write_text(json.dumps(receipt))
        return StateStore(self.root/'saves',self.root/'core',self.root/'game.zip','trace')

    def test_resigned_unchanged_core_keeps_checkpoints(self):
        signed = self.resign(b'core-signed-1', {'trace_sha256': sha(b'core-signed-1'), 'unsigned_trace_sha256': 'c'*64})
        signed.write(1, self.capture)
        self.assertEqual(signed.read(1)[0]['compatibility']['core_sha256'], 'c'*64)
        again = self.resign(b'core-signed-2', {'trace_sha256': sha(b'core-signed-2'), 'unsigned_trace_sha256': 'c'*64})
        self.assertEqual(again.read(1)[1]['state.bin'], b'native-state')
        self.assertTrue(again.slots()[1]['valid'])
        changed = self.resign(b'core-signed-3', {'trace_sha256': sha(b'core-signed-3'), 'unsigned_trace_sha256': 'd'*64})
        with self.assertRaisesRegex(ValueError, 'different core'): changed.read(1)
        self.assertFalse(changed.slots()[1]['valid'])

    def test_unsigned_build_saves_load_in_its_signed_release(self):
        # The pre-signing identity is the unsigned build's own byte hash.
        self.store.write(1, self.capture)
        signed = self.resign(b'core-signed', {'trace_sha256': sha(b'core-signed'), 'unsigned_trace_sha256': sha(b'core')})
        self.assertTrue(signed.slots()[1]['valid'])

    def test_slots_keyed_on_signed_bytes_stay_readable(self):
        # Written by this same signed core before keys used the pre-signing identity.
        legacy = self.resign(b'core-signed', {'trace_sha256': sha(b'core-signed')})
        legacy.write(1, self.capture)
        self.assertEqual(legacy.read(1)[0]['compatibility']['core_sha256'], sha(b'core-signed'))
        current = self.resign(b'core-signed', {'trace_sha256': sha(b'core-signed'), 'unsigned_trace_sha256': 'c'*64})
        self.assertTrue(current.slots()[1]['valid'])
        other = self.resign(b'core-other', {'trace_sha256': sha(b'core-other'), 'unsigned_trace_sha256': 'c'*64})
        with self.assertRaisesRegex(ValueError, 'different core'): other.read(1)

    def test_unauthenticated_identity_is_ignored(self):
        self.resign(b'core-signed', {'trace_sha256': sha(b'core-signed'), 'unsigned_trace_sha256': 'c'*64}).write(1, self.capture)
        # A receipt that does not pin the shipped bytes, or a malformed identity, earns no compatibility.
        for raw, receipt in ((b'core-forged', {'trace_sha256': sha(b'core-signed'), 'unsigned_trace_sha256': 'c'*64}),
                             (b'core-forged', {'trace_sha256': sha(b'core-forged'), 'unsigned_trace_sha256': 'C'*64}),
                             (b'core-forged', {'trace_sha256': sha(b'core-forged'), 'unsigned_trace_sha256': ['c'*64]}),
                             (b'core-forged', ['not', 'a', 'receipt'])):
            store = self.resign(raw, receipt)
            self.assertEqual(store.compatibility['core_sha256'], sha(b'core-forged'))
            with self.assertRaisesRegex(ValueError, 'different core'): store.read(1)
        (self.root/'core.json').write_text('{damaged')
        store = StateStore(self.root/'saves',self.root/'core',self.root/'game.zip','trace')
        self.assertEqual(store.compatibility['core_sha256'], sha(b'core-forged'))

    def test_duplicate_and_unknown_members_rejected(self):
        self.store.write(1,self.capture)
        with zipfile.ZipFile(self.store.path(1),'a') as z: z.writestr('../bad',b'no')
        with self.assertRaisesRegex(ValueError,'members'): self.store.read(1)

    def test_disk_install_preserves_other_user_files(self):
        other = self.store.disk.with_name('other-game.pure.zip'); other.write_bytes(b'other')
        self.store.install_disk(self.disk.getvalue())
        self.assertEqual(self.store.disk.read_bytes(),self.disk.getvalue())
        self.store.install_disk(b'')
        self.assertFalse(self.store.disk.exists())
        self.assertEqual(other.read_bytes(),b'other')

    def test_symlink_slot_and_overlay_rejected(self):
        target = self.root/'original'; target.write_bytes(b'original')
        self.store.path(1).symlink_to(target)
        with self.assertRaisesRegex(ValueError,'symlink'): self.store.read(1)
        self.store.disk.symlink_to(target)
        with self.assertRaisesRegex(ValueError,'symlink'): self.store.install_disk(self.disk.getvalue())
        self.assertEqual(target.read_bytes(),b'original')

    def test_unsafe_disk_member_rejected_before_replace(self):
        self.store.disk.write_bytes(self.disk.getvalue())
        bad = io.BytesIO()
        with zipfile.ZipFile(bad,'w') as z: z.writestr('../outside',b'bad')
        with self.assertRaisesRegex(ValueError,'unsafe'): self.store.install_disk(bad.getvalue())
        self.assertEqual(self.store.disk.read_bytes(),self.disk.getvalue())


class FakeWorker:
    """Stands in for the native worker subprocess; no emulator or guest memory."""
    def __init__(self, argv, lock, resume=None):
        self.resume, self.closed = resume, False
        self.ready = {'type': 'ready', 'id': -1}
        type(self).made.append(self)
    def request(self, message):
        return type(self).reply(self, message)
    def close(self):
        self.closed = True
        if type(self).close_error and self is type(self).made[0]: raise type(self).close_error


class SupervisorCheckpointTests(unittest.TestCase):
    setUp = SaveStateTests.setUp

    def supervise(self, reply, close_error=None):
        worker = type('Worker', (FakeWorker,), {'made': [], 'reply': staticmethod(reply), 'close_error': close_error})
        commands = io.StringIO(json.dumps({'op': 'save_state', 'id': 7, 'slot': 1}) + '\n' + json.dumps({'op': 'quit'}) + '\n')
        args = SimpleNamespace(saves=self.root/'saves', core=self.root/'core', content=self.root/'game.zip', backend='trace')
        out, err = io.StringIO(), io.StringIO()
        with patch.object(pc_state_host, 'Worker', worker), patch.object(pc_state_host, 'StateStore', lambda *a: self.store), \
                patch.object(sys, 'stdin', commands), contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            pc_state_host.supervise(args, [], lambda saves: MagicMock(), validate_command)
        lines = [json.loads(line) for line in out.getvalue().splitlines()]
        self.assertEqual(lines[0]['type'], 'ready')
        return lines[1], worker.made, err.getvalue()

    def test_refused_capture_from_a_live_worker_leaves_no_workspace(self):
        reply = lambda worker, message: {'type': 'capture_error', 'message': 'The original game is not ready for a checkpoint yet'}
        result, made, _ = self.supervise(reply)
        self.assertEqual((result['type'], result['success'], result['message']), ('state_result', False, 'The original game is not ready for a checkpoint yet'))
        self.assertEqual(len(made), 1)  # the session carried on with the same live worker
        self.assertEqual(list(self.store.root.glob('.capture-*')), [])
        self.assertFalse(self.store.path(1).exists())

    def test_worker_death_during_capture_keeps_the_workspace(self):
        def reply(worker, message): raise RuntimeError('Original-game worker ended before replying')
        result, _, _ = self.supervise(reply)
        self.assertFalse(result['success'])
        self.assertEqual(len(list(self.store.root.glob('.capture-*'))), 1)

    def test_close_fault_after_captured_still_saves_and_resumes(self):
        def reply(worker, message):
            for name in ('state.bin', 'resume.json'): shutil.copy(self.capture/name, Path(message['directory'])/name)
            return {'type': 'captured'}
        result, made, err = self.supervise(reply, BrokenPipeError(32, 'Broken pipe'))
        self.assertTrue(result['success'], result)
        self.assertEqual(result['restored']['timeline_reset'], True)
        self.assertEqual(len(made), 2)
        self.assertIsNotNone(made[1].resume)
        self.assertTrue(self.store.slots()[1]['valid'])
        self.assertIn('Broken pipe', err)
        self.assertEqual(list(self.store.root.glob('.capture-*')), [])

    def test_worker_close_tolerates_a_pipe_the_worker_already_closed(self):
        def broken(*_): raise BrokenPipeError(32, 'Broken pipe')
        stdin = SimpleNamespace(write=broken, flush=broken, close=broken)
        process = SimpleNamespace(poll=lambda: None, stdin=stdin, wait=MagicMock(return_value=0), stdout=MagicMock())
        worker = object.__new__(pc_state_host.Worker); worker.process = process
        worker.close()
        process.wait.assert_called_once()
        process.stdout.close.assert_called_once()


if __name__ == '__main__': unittest.main()
