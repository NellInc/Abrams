import json
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch

from tools.standalone import source_bundle as bundle


class SourceBundleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / '.runtime/dosbox-pure-source'
        self.source.mkdir(parents=True)
        self.core = self.root / '.runtime/pc-core'
        self.core.mkdir()
        (self.root / 'tools/package').mkdir(parents=True)
        (self.root / 'tools/pc_core').mkdir()
        (self.root / 'tools/package/game-inputs.json').write_text('{"files": []}')
        self.originals = {name: ('upstream ' + name + '\n').encode()
                          for name in bundle.PATCHED | {'src/cpu/core_normal.cpp',
                              'LICENSE', 'README.md', 'Makefile', 'src/vendor/legal.txt',
                              'images/resource.png', '.gitignore'}}
        self.originals['.gitignore'] = b'build/\n*.dylib\n*.cfg\n'
        for name, content in self.originals.items():
            path = self.source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
        self.git('init', '-q')
        self.git('add', '.')
        self.git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                 'commit', '-qm', 'Synthetic fixture')
        revision = self.git('rev-parse', 'HEAD').decode().strip()
        self.pin = patch.object(bundle, 'UPSTREAM', revision)
        self.pin.start()
        self.addCleanup(self.pin.stop)
        self.receipt = {'commit': revision, 'upstream': bundle.UPSTREAM_URL,
                        'compiler': 'synthetic compiler', 'video_patch_hashes': {}}
        for name in bundle.PATCHED | {'src/cpu/core_normal.cpp'}:
            changed = self.originals[name] + b'local patch\n'
            (self.source / name).write_bytes(changed)
            hashes = {'original': bundle.digest(self.originals[name]),
                      'patched': bundle.digest(changed)}
            if name == 'src/cpu/core_normal.cpp':
                self.receipt['source_core_normal_sha256'] = hashes['original']
                self.receipt['patched_core_normal_sha256'] = hashes['patched']
            else:
                self.receipt['video_patch_hashes'][name] = hashes
        for name, key in bundle.HEADERS.items():
            content = ('header ' + name).encode()
            (self.source / name).write_bytes(content)
            (self.root / 'tools/pc_core' / Path(name).name).write_bytes(content)
            self.receipt[key] = bundle.digest(content)
        (self.core / 'abrams-trace.dylib').write_bytes(b'synthetic core')
        self.receipt['trace_sha256'] = bundle.digest(b'synthetic core')
        self.write_receipt()

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.source), *args],
                                       stderr=subprocess.PIPE)

    def write_receipt(self):
        (self.core / 'abrams-trace.json').write_text(json.dumps(self.receipt))

    def build(self, name='source.tar.gz'):
        return bundle.build(self.root, self.root / name)

    def test_complete_deterministic_source_and_normalized_metadata(self):
        first = self.build()
        os.utime(self.source / 'LICENSE', (777, 777))
        second = self.build('second.tar.gz')
        self.assertEqual(first, second)
        self.assertEqual((self.root / 'source.tar.gz').read_bytes(),
                         (self.root / 'second.tar.gz').read_bytes())
        with tarfile.open(self.root / 'source.tar.gz') as archive:
            names = set(archive.getnames())
            for name in self.originals.keys() | bundle.HEADERS.keys():
                self.assertIn(bundle.PREFIX + '/source/' + name, names)
            inventory = json.load(archive.extractfile(bundle.PREFIX + '/SOURCE-FILES.json'))
            for row in inventory['files']:
                self.assertEqual(bundle.digest(archive.extractfile(
                    bundle.PREFIX + '/' + row['path']).read()), row['sha256'])
            for item in archive.getmembers():
                self.assertTrue(item.isfile())
                self.assertEqual((item.uid, item.gid, item.mtime), (0, 0, 0))
                self.assertEqual((item.uname, item.gname), ('', ''))

    def test_no_overwrite(self):
        self.build()
        before = (self.root / 'source.tar.gz').read_bytes()
        with self.assertRaisesRegex(ValueError, 'exclusive'):
            self.build()
        self.assertEqual(before, (self.root / 'source.tar.gz').read_bytes())

    def test_unsafe_names(self):
        for name in ['../file', '/file', 'a//b', 'a/./b', 'a\\b', '.git/config',
                     'GAME/SIM.EXE', 'rom/game.md', 'saves/slot', 'a/secret.env',
                     '.runtime/core', 'build/file.cpp', 'a\nfile', 'x.dylib']:
            with self.subTest(name=name), self.assertRaises(ValueError):
                bundle.validate_name(name)

    def test_core_fingerprint_mismatch(self):
        (self.core / 'abrams-trace.dylib').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'Core fingerprint'):
            self.build()
        self.assertFalse((self.root / 'source.tar.gz').exists())

    def test_patch_fingerprint_mismatch(self):
        (self.source / 'src/cpu/core_normal.cpp').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'Patched source fingerprint'):
            self.build()

    def test_original_patch_fingerprint_mismatch(self):
        self.receipt['video_patch_hashes']['src/dos/drives.h']['original'] = 'bad'
        self.write_receipt()
        with self.assertRaisesRegex(ValueError, 'Patched source fingerprint'):
            self.build()

    def test_header_mismatch(self):
        (self.root / 'tools/pc_core/abrams_trace.h').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'Header fingerprint'):
            self.build()

    def test_unrecognized_tracked_and_untracked_changes(self):
        (self.source / 'LICENSE').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'Unrecognized tracked'):
            self.build()
        (self.source / 'LICENSE').write_bytes(self.originals['LICENSE'])
        (self.source / 'secret.txt').write_bytes(b'private')
        with self.assertRaisesRegex(ValueError, 'Unrecognized untracked'):
            self.build()

    def test_symlink_refused(self):
        path = self.source / 'LICENSE'
        path.unlink()
        path.symlink_to(self.source / 'README.md')
        with self.assertRaisesRegex(ValueError, 'Symlink'):
            self.build()

    def test_missing_tracked_resource_refused(self):
        (self.source / 'images/resource.png').unlink()
        with self.assertRaisesRegex(ValueError, 'Missing regular'):
            self.build()

    def test_originals_and_build_products_excluded(self):
        (self.source / 'build').mkdir()
        (self.source / 'build/original.exe').write_bytes(b'original')
        (self.source / 'build/private.env').write_bytes(b'private')
        (self.source / 'built.dylib').write_bytes(b'compiled')
        self.build()
        with tarfile.open(self.root / 'source.tar.gz') as archive:
            self.assertFalse(any('/build/' in n or n.endswith('.dylib')
                                 or '/.git/' in n for n in archive.getnames()))

    def test_original_content_fingerprint_refused_even_under_safe_name(self):
        forbidden = bundle.digest(self.originals['images/resource.png'])
        (self.root / 'tools/package/game-inputs.json').write_text(
            json.dumps({'files': [{'sha256': forbidden}]}))
        with self.assertRaisesRegex(ValueError, 'Original game input'):
            self.build()


if __name__ == '__main__':
    unittest.main()
