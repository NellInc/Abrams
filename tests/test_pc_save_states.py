import contextlib
import errno
import io
import json
from pathlib import Path
import os
import shutil
import stat
import struct
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import MagicMock, patch
import zipfile
from tools.pc_bridge_host import validate_command
from tools.pc_state_store import StateStore, atomic_write, is_link, sha, sync_parent
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
        # An overwritten archive exists only for numbered slots.
        validate_command({'op':'load_previous','id':1,'slot':1})
        validate_command({'op':'load_previous','id':1,'slot':5})
        for changes in ({'slot':0},{'slot':6},{'slot':True},{'id':-1},{'extra':1}):
            with self.assertRaises(ValueError): validate_command({'op':'load_previous','id':1,'slot':1}|changes)

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

    def test_overwritten_archive_is_listed_and_readable(self):
        self.assertNotIn('previous_saved_at', self.store.slots()[1])
        with patch('tools.pc_state_store.time.strftime', return_value='2026-10-15 09:00:00'):
            self.store.write(1, self.capture)
        first = self.store.read(1)
        (self.capture/'state.bin').write_bytes(b'changed')
        with patch('tools.pc_state_store.time.strftime', return_value='2026-10-15 10:00:00'):
            self.store.write(1, self.capture)
        row = self.store.slots()[1]
        self.assertEqual((row['saved_at'], row['previous_saved_at']), ('2026-10-15 10:00:00', first[0]['saved_at']))
        self.assertEqual(self.store.read(1, previous=True)[1], first[1])
        self.assertEqual(self.store.read(1)[1]['state.bin'], b'changed')
        for slot in (0, 2):
            with self.assertRaises(ValueError): self.store.read(slot, previous=True)
        self.assertNotIn('previous_saved_at', self.store.slots()[0])
        # A damaged archive is unlisted; the live slot row and the listing are unaffected.
        self.store.path(1).with_suffix('.previous.zip').write_bytes(b'not an archive')
        rows = self.store.slots()
        self.assertEqual(len(rows), 6)
        self.assertNotIn('previous_saved_at', rows[1])
        self.assertTrue(rows[1]['valid'])
        self.assertNotIn('message', rows[1])
        with self.assertRaises(ValueError): self.store.read(1, previous=True)

    def test_overwritten_archive_lists_without_a_live_slot(self):
        self.store.write(1, self.capture)
        self.store.write(1, self.capture)
        self.store.path(1).unlink()
        row = self.store.slots()[1]
        self.assertEqual(row['exists'], False)
        self.assertIn('previous_saved_at', row)

    def test_symlinked_overwritten_archive_rejected(self):
        self.store.write(1, self.capture)
        self.store.path(1).with_suffix('.previous.zip').symlink_to(self.store.path(1))
        with self.assertRaisesRegex(ValueError, 'symlink'): self.store.read(1, previous=True)
        self.assertNotIn('previous_saved_at', self.store.slots()[1])

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

    def test_linked_saves_or_state_folder_rejected_before_resolve(self):
        real = self.root/'elsewhere'; (real/'states').mkdir(parents=True)
        (self.root/'linked').symlink_to(real, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'symlink or junction'):
            StateStore(self.root/'linked', self.root/'core', self.root/'game.zip', 'trace')
        (self.root/'plain').mkdir()
        (self.root/'plain'/'states').symlink_to(real/'states', target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'symlink or junction'):
            StateStore(self.root/'plain', self.root/'core', self.root/'game.zip', 'trace')
        with self.assertRaisesRegex(ValueError, 'symlink or junction'):
            StateStore(self.root/'saves', self.root/'core', self.root/'game.zip', 'trace', overlay=self.root/'linked')
        self.assertEqual(list((real/'states').iterdir()), [])

    def test_junction_counts_as_a_link_but_other_reparse_points_do_not(self):
        target = self.root/'folder'; target.mkdir()
        real = os.lstat(target)
        def fake(tag, attributes=stat.FILE_ATTRIBUTE_REPARSE_POINT):
            return SimpleNamespace(st_mode=real.st_mode, st_file_attributes=attributes, st_reparse_tag=tag)
        for tag, expected in ((0xA0000003, True), (0xA000000C, True), (0x9000001A, False), (0, False)):
            with self.subTest(tag=hex(tag)), patch('tools.pc_state_store.os.lstat', return_value=fake(tag)):
                self.assertIs(is_link(target), expected)
        with patch('tools.pc_state_store.os.lstat', return_value=fake(0xA0000003, 0)):
            self.assertFalse(is_link(target))  # the tag alone, without the reparse attribute
        self.assertFalse(is_link(self.root/'missing'))

    def test_unsafe_disk_member_rejected_before_replace(self):
        self.store.disk.write_bytes(self.disk.getvalue())
        bad = io.BytesIO()
        with zipfile.ZipFile(bad,'w') as z: z.writestr('../outside',b'bad')
        with self.assertRaisesRegex(ValueError,'unsafe'): self.store.install_disk(bad.getvalue())
        self.assertEqual(self.store.disk.read_bytes(),self.disk.getvalue())


class FakeWorker:
    """Stands in for the native worker subprocess; no emulator or guest memory."""
    killed = False
    def __init__(self, argv, lock, resume=None):
        self.argv, self.resume, self.closed = argv, resume, False
        # What a resume worker would find in its workspace when it starts.
        self.files = sorted(p.name for p in Path(resume).iterdir()) if resume else None
        self.state = (Path(resume)/'state.bin').read_bytes() if resume else None
        self.ready = {'type': 'ready', 'id': -1}
        type(self).made.append(self)
    def request(self, message):
        return type(self).reply(self, message)
    def close(self):
        self.closed = True
        if type(self).close_error and self is type(self).made[0]: raise type(self).close_error


class SupervisorCheckpointTests(unittest.TestCase):
    setUp = SaveStateTests.setUp

    SAVE = {'op': 'save_state', 'id': 7, 'slot': 1}
    STEP = {'op': 'step', 'id': 8, 'frames': 1, 'keys': []}
    QUIT = {'op': 'quit'}

    def session(self, reply, commands, close_error=None, args=None, store=None):
        worker = type('Worker', (FakeWorker,), {'made': [], 'reply': staticmethod(reply), 'close_error': close_error})
        stdin = io.StringIO(''.join(json.dumps(command) + '\n' for command in commands))
        args = args or SimpleNamespace(saves=self.root/'saves', core=self.root/'core', content=self.root/'game.zip', backend='trace')
        out, err, raised = io.StringIO(), io.StringIO(), None
        with patch.object(pc_state_host, 'Worker', worker), patch.object(pc_state_host, 'StateStore', store or (lambda *a, **k: self.store)), \
                patch.object(sys, 'stdin', stdin), contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try: pc_state_host.supervise(args, [], lambda saves: MagicMock(), validate_command)
            except Exception as error: raised = error
        lines = [json.loads(line) for line in out.getvalue().splitlines()]
        self.assertEqual(lines[0]['type'], 'ready')
        return lines, worker.made, err.getvalue(), raised

    def supervise(self, reply, close_error=None):
        lines, made, err, raised = self.session(reply, [self.SAVE, self.QUIT], close_error)
        self.assertIsNone(raised)
        return lines[1], made, err

    def captured(self, message):
        for name in ('state.bin', 'resume.json'): shutil.copy(self.capture/name, Path(message['directory'])/name)
        return {'type': 'captured'}

    def test_refused_capture_from_a_live_worker_leaves_no_workspace(self):
        reply = lambda worker, message: {'type': 'capture_error', 'message': 'The original game is not ready for a checkpoint yet'}
        result, made, _ = self.supervise(reply)
        self.assertEqual((result['type'], result['success'], result['message']), ('state_result', False, 'The original game is not ready for a checkpoint yet'))
        self.assertEqual(len(made), 1)  # the session carried on with the same live worker
        self.assertEqual(list(self.store.root.glob('.capture-*')), [])
        self.assertFalse(self.store.path(1).exists())

    def test_worker_death_during_capture_stops_visibly_and_keeps_the_workspace(self):
        def reply(worker, message):
            if message['op'] == '_capture': raise RuntimeError('Original-game worker ended before replying')
            raise BrokenPipeError(32, 'Broken pipe')  # a dead worker's stdin
        lines, made, _, raised = self.session(reply, [self.SAVE, self.STEP, self.QUIT])
        # The dead worker is never kept: no step reaches it, and the client is
        # told why instead of the host exiting silently.
        self.assertIsInstance(raised, RuntimeError)
        self.assertEqual([line['type'] for line in lines], ['ready', 'error'])
        self.assertIn('Checkpoint recovery failed', lines[-1]['message'])
        self.assertIn('ended before replying', lines[-1]['message'])
        self.assertEqual(len(made), 1)
        self.assertTrue(made[0].closed)
        self.assertEqual(len(list(self.store.root.glob('.capture-*'))), 1)
        self.assertFalse(self.store.path(1).exists())

    def test_worker_death_after_a_complete_capture_recovers_from_it(self):
        def reply(worker, message):
            if message['op'] == '_capture':
                self.captured(message)
                raise RuntimeError('detach failed after the capture was written')
            return {'type': 'sample', 'id': message['id']}
        lines, made, err, raised = self.session(reply, [self.SAVE, self.STEP, self.QUIT])
        self.assertIsNone(raised)
        self.assertEqual([line['type'] for line in lines], ['ready', 'state_result', 'sample'])
        self.assertTrue(lines[1]['success'], lines[1])
        self.assertEqual(len(made), 2)
        self.assertIn('campaign.zip', made[1].files)
        self.assertTrue(self.store.slots()[1]['valid'])
        self.assertIn('detach failed', err)
        self.assertEqual(list(self.store.root.glob('.capture-*')), [])

    def test_overlay_copy_failure_after_capture_resumes_the_untouched_overlay(self):
        self.store.disk.write_bytes(self.disk.getvalue())
        def fail(path, raw):
            if Path(path).name == 'campaign.zip': raise OSError(errno.ENOSPC, 'No space left on device')
        with patch.object(pc_state_host, 'atomic_write', side_effect=fail):
            result, made, _ = self.supervise(lambda worker, message: self.captured(message))
        self.assertFalse(result['success'])
        self.assertIn('No space left', result['message'])
        self.assertEqual(result['restored']['timeline_reset'], True)
        # The resume worker finds no overlay copy and so keeps the live one.
        self.assertEqual(len(made), 2)
        self.assertNotIn('campaign.zip', made[1].files)
        self.assertEqual(self.store.disk.read_bytes(), self.disk.getvalue())
        self.assertFalse(self.store.path(1).exists())

    def test_rollback_never_revalidates_the_live_overlay(self):
        # The capture flush leaves an overlay the store rejects, so the slot
        # write fails after the worker closed. Recovery must still succeed.
        def reply(worker, message):
            self.store.disk.write_bytes(b'not a campaign archive')
            return self.captured(message)
        result, made, _ = self.supervise(reply)
        self.assertFalse(result['success'])
        self.assertTrue(result['restored'])
        self.assertEqual(len(made), 2)
        self.assertIn('campaign.zip', made[1].files)
        self.assertFalse(self.store.path(1).exists())

    def test_unvalidatable_live_overlay_fails_before_capture(self):
        self.store.disk.write_bytes(b'not a campaign archive')
        requests = []
        result, made, _ = self.supervise(lambda worker, message: requests.append(message))
        self.assertFalse(result['success'])
        self.assertNotIn('restored', result)
        self.assertEqual((requests, len(made)), ([], 1))  # still the same live worker
        self.assertEqual(list(self.store.root.glob('.capture-*')), [])

    def test_snapshot_start_uses_a_fresh_overlay_and_removes_it(self):
        stale = self.store.disk; stale.write_bytes(b'written by an earlier diagnostic run')
        stores = []
        def store(*a, **k):
            stores.append(StateStore(*a, **k)); return stores[-1]
        args = SimpleNamespace(saves=self.root/'saves', core=self.root/'core', content=self.root/'game.zip',
                               backend='reference', state=self.root/'reference.state')
        lines, made, _, raised = self.session(lambda worker, message: None, [self.QUIT], args=args, store=store)
        self.assertIsNone(raised)
        flag, overlay = made[0].argv[-2:]
        self.assertEqual(flag, '--saves')
        overlay = Path(overlay)
        self.assertEqual(overlay.parent, (self.root/'saves').resolve())
        self.assertEqual(stores[0].disk.parent, overlay)
        self.assertEqual(stores[0].root, (self.root/'saves'/'states').resolve())  # slots persist
        self.assertFalse(overlay.exists())
        self.assertEqual(stale.read_bytes(), b'written by an earlier diagnostic run')

    def test_client_pipe_close_ends_quietly_but_worker_pipe_close_is_reported(self):
        for error in (BrokenPipeError(32, 'Broken pipe'), OSError(errno.EINVAL, 'Invalid argument')):
            with self.subTest(error=error):
                worker = type('Worker', (FakeWorker,), {'made': [], 'reply': None, 'close_error': None})
                stdout = SimpleNamespace(write=MagicMock(side_effect=error), flush=lambda: None)
                args = SimpleNamespace(saves=self.root/'saves', core=self.root/'core', content=self.root/'game.zip', backend='trace')
                with patch.object(pc_state_host, 'Worker', worker), patch.object(pc_state_host, 'StateStore', lambda *a, **k: self.store), \
                        patch.object(sys, 'stdin', io.StringIO('')), patch.object(sys, 'stdout', stdout):
                    self.assertIsNone(pc_state_host.supervise(args, [], lambda saves: MagicMock(), validate_command))
                self.assertTrue(worker.made[0].closed)
        lines, _, _, raised = self.session(lambda worker, message: (_ for _ in ()).throw(BrokenPipeError(32, 'Broken pipe')),
                                       [self.STEP, self.QUIT])
        self.assertIsInstance(raised, BrokenPipeError)
        self.assertEqual(lines[-1]['type'], 'error')

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

    def test_load_previous_installs_the_overwritten_archive_and_keeps_both_slots(self):
        self.store.write(1, self.capture)
        first = self.store.read(1)[1]
        (self.capture/'state.bin').write_bytes(b'changed')
        self.store.write(1, self.capture)
        live, previous = self.store.path(1).read_bytes(), self.store.path(1).with_suffix('.previous.zip').read_bytes()
        (self.capture/'state.bin').write_bytes(b'live-session')
        load = {'op': 'load_previous', 'id': 9, 'slot': 1}
        lines, made, _, raised = self.session(lambda worker, message: self.captured(message), [load, self.QUIT])
        self.assertIsNone(raised)
        result = lines[1]
        self.assertTrue(result['success'], result)
        self.assertEqual(result['message'], 'Overwritten slot 1 loaded; previous session kept in recovery slot')
        self.assertEqual(result['restored']['timeline_reset'], True)
        self.assertEqual(len(made), 2)
        self.assertEqual(made[1].files, sorted(first))  # the restore workspace held the archive
        self.assertEqual(made[1].state, b'native-state')
        self.assertEqual(self.store.read(0)[1]['state.bin'], b'live-session')
        self.assertEqual(self.store.path(1).read_bytes(), live)
        self.assertEqual(self.store.path(1).with_suffix('.previous.zip').read_bytes(), previous)
        self.assertEqual(self.store.disk.read_bytes(), first['campaign.zip'])
        self.assertIn('previous_saved_at', result['slots'][1])

    def test_load_previous_without_an_archive_keeps_the_live_worker(self):
        requests = []
        lines, made, _, raised = self.session(lambda worker, message: requests.append(message),
                                              [{'op': 'load_previous', 'id': 9, 'slot': 2}, self.QUIT])
        self.assertIsNone(raised)
        self.assertFalse(lines[1]['success'])
        self.assertIn('no overwritten archive', lines[1]['message'])
        self.assertEqual((requests, len(made)), ([], 1))
        self.assertFalse(self.store.path(0).exists())

    def fake_process(self, error):
        def broken(*_): raise error
        stdin = SimpleNamespace(write=broken, flush=broken, close=broken)
        process = SimpleNamespace(poll=lambda: None, stdin=stdin, wait=MagicMock(return_value=0), stdout=MagicMock())
        worker = object.__new__(pc_state_host.Worker); worker.process = process
        return worker, process

    def test_worker_close_tolerates_a_pipe_the_worker_already_closed(self):
        # Windows reports a write to an exited child's pipe as EINVAL.
        for error in (BrokenPipeError(32, 'Broken pipe'), OSError(errno.EINVAL, 'Invalid argument')):
            with self.subTest(error=error):
                worker, process = self.fake_process(error)
                worker.close()
                process.wait.assert_called_once()
                process.stdout.close.assert_called_once()

    def test_worker_close_always_reaps_even_on_an_unexpected_pipe_error(self):
        worker, process = self.fake_process(OSError(errno.EIO, 'I/O error'))
        with self.assertRaisesRegex(OSError, 'I/O error'): worker.close()
        process.wait.assert_called_once()
        process.stdout.close.assert_called_once()

    def hung_process(self):
        calls = []
        def wait(timeout=None):
            calls.append(timeout)
            if timeout is not None: raise subprocess.TimeoutExpired('worker', timeout)
            return -9
        stdin = SimpleNamespace(write=lambda _: None, flush=lambda: None, close=lambda: None)
        process = SimpleNamespace(poll=lambda: None, stdin=stdin, wait=wait, kill=MagicMock(), stdout=MagicMock())
        return process, calls

    def test_worker_hung_in_shutdown_is_killed_once_the_client_has_gone(self):
        process, calls = self.hung_process()
        gone = SimpleNamespace(is_set=lambda: True)
        worker = object.__new__(type('Worker', (pc_state_host.Worker,), {'client_closed': gone}))
        worker.process = process
        with patch.object(pc_state_host, 'ORPHAN_GRACE', 0.0):
            with self.assertRaisesRegex(RuntimeError, 'hung in shutdown'): worker.close()
        process.kill.assert_called_once()
        self.assertEqual(calls[-1], None)  # reaped after the kill
        process.stdout.close.assert_called_once()
        self.assertTrue(worker.killed)
        worker.close()  # already stopped: nothing more to reap
        process.kill.assert_called_once()

    def test_worker_shutdown_waits_without_limit_while_the_client_is_connected(self):
        process, calls = self.hung_process()
        connected = SimpleNamespace(is_set=lambda: len(calls) >= 8)  # the client leaves after eight bounded waits
        worker = object.__new__(type('Worker', (pc_state_host.Worker,), {'client_closed': connected}))
        worker.process = process
        with patch.object(pc_state_host, 'ORPHAN_GRACE', 0.0):
            with self.assertRaisesRegex(RuntimeError, 'hung in shutdown'): worker.close()
        self.assertGreaterEqual(len(calls), 9)
        self.assertTrue(all(timeout == 0.25 for timeout in calls[:8]))

    def test_worker_request_reports_its_own_closed_pipe(self):
        for error in (BrokenPipeError(32, 'Broken pipe'), OSError(errno.EINVAL, 'Invalid argument')):
            with self.subTest(error=error):
                worker, _ = self.fake_process(error)
                with self.assertRaisesRegex(RuntimeError, 'ended before accepting a command'):
                    worker.request({'op': 'step'})


if __name__ == '__main__': unittest.main()
