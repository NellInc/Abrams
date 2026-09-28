import io
import json
from pathlib import Path
import tempfile
import unittest
import zipfile
from tools.pc_bridge_host import validate_command
from tools.pc_state_store import StateStore, atomic_write


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

    def test_corruption_rejected(self):
        self.store.write(1,self.capture)
        self.rewrite(lambda files: files.update({'state.bin': b'tampered'}))
        with self.assertRaisesRegex(ValueError,'integrity'): self.store.read(1)
        self.assertFalse(self.store.slots()[1]['valid'])

    def test_incompatible_rejected(self):
        self.store.write(1,self.capture)
        (self.root/'core').write_bytes(b'new core')
        new = StateStore(self.root/'saves',self.root/'core',self.root/'game.zip','trace')
        with self.assertRaisesRegex(ValueError,'different core'): new.read(1)

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

if __name__ == '__main__': unittest.main()
