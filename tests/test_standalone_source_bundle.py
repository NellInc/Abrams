import ast
import json
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch

from tools import build_pc_trace_core as builder
from tools.standalone import source_bundle as bundle

ROOT = Path(__file__).resolve().parents[1]


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
                          for name in builder.PATCHED_SOURCES | {'src/cpu/core_normal.cpp',
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
        for name in builder.PATCHED_SOURCES | {'src/cpu/core_normal.cpp'}:
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

    def test_explicit_native_targets_do_not_depend_on_archive_host(self):
        original=self.core/'abrams-trace.dylib'
        for suffix in ('.dll','.so'):
            target=self.core/('abrams-trace'+suffix)
            target.write_bytes(original.read_bytes())
            result=bundle.build(self.root,self.root/('native'+suffix+'.tar.gz'),suffix=suffix)
            self.assertEqual(result['core_sha256'],self.receipt['trace_sha256'])
        with self.assertRaisesRegex(ValueError,'suffix'):
            bundle.collect(self.root,suffix='../outside')

    def readme(self, suffix):
        (self.core / ('abrams-trace' + suffix)).write_bytes(b'synthetic core')
        output = self.root / ('readme' + suffix + str(len(list(self.root.glob('readme*')))) + '.tar.gz')
        bundle.build(self.root, output, suffix=suffix)
        with tarfile.open(output) as archive:
            return archive.extractfile(bundle.PREFIX + '/README.md').read().decode()

    def test_readme_build_section_follows_platform_and_recorded_command(self):
        self.receipt['build'] = ['make', '-C', '<source>', '-j4', builder.WINDOWS_LDFLAGS]
        self.write_receipt()
        text = self.readme('.dll')
        self.assertIn('## Build on Windows x86_64', text)
        self.assertIn('MINGW64', text)
        self.assertIn("    make -j4 '" + builder.WINDOWS_LDFLAGS + "'\n", text)
        self.assertIn('recorded in CORE-BUILD.json', text)
        self.assertIn('dosbox_pure_libretro.dll', text)
        self.assertIn('abrams-trace.dll', text)
        self.assertNotIn('.dylib', text)
        self.assertNotIn('<source>', text)
        self.receipt['build'] = ['make', '-C', '<source>', '-j4']
        self.write_receipt()
        text = self.readme('.so')
        self.assertIn('## Build on Linux x86_64', text)
        self.assertIn('    make -j4\n', text)
        self.assertIn('abrams-trace.so', text)
        self.assertNotIn('LDFLAGS', text)
        self.assertNotIn('.dylib', text)

    def test_readme_without_recorded_command_uses_builder_platform_command(self):
        self.receipt.pop('build', None)
        self.write_receipt()
        text = self.readme('.dll')
        self.assertIn("    make -j4 '" + builder.WINDOWS_LDFLAGS + "'\n", text)
        self.assertIn('records no build command', text)
        text = self.readme('.dylib')
        self.assertIn('## Build on macOS ARM64', text)
        self.assertIn('    make -j4\n', text)
        self.assertIn('abrams-trace.dylib', text)

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

    def test_default_source_is_the_tree_the_receipt_built(self):
        task = self.root / '.runtime/task-20261013/source'
        task.parent.mkdir(parents=True)
        self.source.rename(task)
        self.receipt['build'] = ['make', '-C', '.runtime/task-20261013/source', '-j4']
        self.write_receipt()
        self.assertEqual(self.build()['source_files'], len(self.originals) + len(bundle.HEADERS))
        # Receipts written before relative recording carry an absolute path.
        self.receipt['build'][2] = str(task)
        self.write_receipt()
        self.assertEqual(self.build('absolute.tar.gz')['source_files'],
                         len(self.originals) + len(bundle.HEADERS))

    def test_default_source_never_leaves_the_payload_root(self):
        default = self.root.resolve() / '.runtime/dosbox-pure-source'
        for recorded in (str(Path(tempfile.gettempdir()) / 'elsewhere'), '../outside', '<source>'):
            with self.subTest(recorded=recorded):
                self.assertEqual(bundle.built_source(self.root.resolve(),
                                 {'build': ['make', '-C', recorded, '-j4']}), default)
        self.assertEqual(bundle.built_source(self.root.resolve(), {}), default)

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


class PatchSetDriftTests(unittest.TestCase):
    def test_bundle_patch_set_is_the_builder_patch_set(self):
        self.assertIs(bundle.PATCHED, builder.PATCHED_SOURCES)
        self.assertTrue({'src/dbp_serialize.cpp', 'src/dos/dos.cpp'} <= bundle.PATCHED)

    def test_builder_patch_table_literal_matches_exported_set(self):
        # Guards against a patch reintroduced as a local table inside main().
        tree = ast.parse((ROOT / 'tools/build_pc_trace_core.py').read_text())
        names = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Assign):
                for target in node.targets:
                    if isinstance(target, ast.Name) and target.id in ('PATCHES', 'patches') \
                            and isinstance(node.value, ast.Dict):
                        names.update(k.value for k in node.value.keys)
                    elif isinstance(target, ast.Subscript) and getattr(target.value, 'id', None) in ('PATCHES', 'patches'):
                        names.add(target.slice.value)
        self.assertEqual(names, builder.PATCHED_SOURCES)

    @unittest.skipUnless((ROOT / '.runtime/pc-core/abrams-trace.json').is_file(), 'no local trace-core receipt')
    def test_active_receipt_patch_set_is_recognized(self):
        receipt = json.loads((ROOT / '.runtime/pc-core/abrams-trace.json').read_text())
        self.assertEqual(set(receipt['video_patch_hashes']), bundle.PATCHED)

    @unittest.skipUnless((ROOT / '.runtime/pc-core/abrams-trace.json').is_file()
                         and (ROOT / '.runtime/dosbox-pure-source/.git').exists(), 'no local source checkout')
    def test_builder_reproduces_receipt_patches_from_upstream(self):
        receipt = json.loads((ROOT / '.runtime/pc-core/abrams-trace.json').read_text())['video_patch_hashes']
        source = ROOT / '.runtime/dosbox-pure-source'
        for name, replacements in builder.PATCHES.items():
            with self.subTest(name=name):
                text = subprocess.check_output(['git', '-C', str(source), 'show', 'HEAD:' + name], text=True)
                self.assertEqual(bundle.digest(text.encode()), receipt[name]['original'])
                for old, new in replacements:
                    self.assertEqual(text.count(old), 1)
                    text = text.replace(old, new, 1)
                for old, new, count in builder.EXTRA.get(name, []):
                    self.assertEqual(text.count(old), count)
                    text = text.replace(old, new)
                if receipt[name]['patched'] not in builder.SUPERSEDED.get(name, ()):
                    self.assertEqual(bundle.digest(text.encode()), receipt[name]['patched'])
                if name == 'dosbox_pure_libretro.cpp':
                    # Event 12 is delivered before the emulation thread is woken.
                    present = text.index('AbramsTraceVideoPresent((Bit32u)')
                    self.assertLess(present, text.index('skip_emulate ? TCM_RESUME_FRAME : TCM_NEXT_FRAME);'))
                    self.assertEqual(text.count('AbramsTraceVideoPresent((Bit32u)'), 1)


class BuilderReceiptTests(unittest.TestCase):
    def test_recorded_source_never_leaks_an_absolute_path(self):
        self.assertEqual(builder.recorded_source(builder.ROOT / '.runtime/dosbox-pure-source'),
                         '.runtime/dosbox-pure-source')
        self.assertEqual(builder.recorded_source(Path(tempfile.gettempdir()) / 'dosbox-pure'), '<source>')

    def test_compiler_query_failure_is_recorded_not_raised(self):
        with patch.dict(os.environ, {'CXX': '/nonexistent/abrams-cxx'}):
            self.assertEqual(builder.compiler(Path(tempfile.gettempdir()) / 'no-such-source'),
                             'unknown (/nonexistent/abrams-cxx)')

    def test_receipt_is_complete_before_core_and_receipt_replace(self):
        text = (ROOT / 'tools/build_pc_trace_core.py').read_text()
        main = text[text.index('def main():'):]
        self.assertIn("'trace_sha256': sha(staged)", main)
        self.assertNotIn("'build': build_command", main)
        written = main.index('staged_manifest.write_text(')
        self.assertLess(main.index("'compiler': compiler(SOURCE)"), written)
        self.assertLess(written, main.index('staged.replace(output)'))
        self.assertLess(main.index('staged.replace(output)'), main.index("staged_manifest.replace(output.with_suffix('.json'))"))
        # The outgoing core/receipt pair is retained before either is replaced.
        self.assertLess(written, main.index('shutil.copyfile(output, retained / output.name)'))
        self.assertLess(main.index("retained / output.with_suffix('.json').name"), main.index('staged.replace(output)'))
        self.assertIn("args.output_dir / 'previous' / sha(output)", main)


if __name__ == '__main__':
    unittest.main()
