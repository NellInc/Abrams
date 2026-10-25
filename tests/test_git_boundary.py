"""Synthetic index/history violations; no real credentials or owned originals."""
import hashlib
from io import BytesIO
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from zipfile import ZipFile
from tools.package import git_boundary as boundary

ROOT = Path(__file__).resolve().parents[1]
PREFIX = 'website/dist/play/.generated/'


def archive(*entries):
    stream = BytesIO()
    with ZipFile(stream, 'w') as package:
        for name, contents in entries:
            package.writestr(name, contents)
    return stream.getvalue()


def sha(data):
    return hashlib.sha256(data).hexdigest()


def publication(files=(), decoded=(), exceptions=(), historical=()):
    return {'schema': 1, 'files': {name: {'set': 'common', 'sha256': sha(data)} for name, data in files},
            'decoded_denylist': {sha(data): name for name, data in decoded},
            'exceptions': {name: 'reviewed' for name in exceptions},
            'historical_publications': {oid: {'path': 'x'} for oid in historical}}


class GitBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='abrams git boundary ')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git('init', '-q')
        self.git('config', 'user.name', 'Boundary Test')
        self.git('config', 'user.email', 'boundary@example.invalid')
        self.git('config', 'commit.gpgsign', 'false')
        self.publication = publication()

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.root), *args], stderr=subprocess.STDOUT)

    def add(self, name, data=b'clean source'):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        self.git('add', '-f', '--', name)

    def check(self, history=False, known_hashes=frozenset(), publication=None):
        return boundary.check(self.root, history=history, known_hashes=set(known_hashes),
                              publication=self.publication if publication is None else publication)

    def test_clean_index(self):
        self.add('tools/test.py')
        self.assertEqual(self.check(), [])

    def test_originals_roms_private_directories_and_secrets(self):
        names = ['GAME/SIM.EXE', 'nested/gEnEsIs/game.md', 'input.ROM', 'other/SIM.exe',
                 'saves/slot.json', 'states/slot.json', '.runtime/core.txt', 'local-art/a.png',
                 'artifacts/report.json', 'config.env', '.env.local', 'nested/.ssh/config',
                 'notes/SCENARIO.DAT.decoded']
        for name in names:
            self.add(name)
        self.assertEqual({name for name, _ in self.check()}, set(names))

    def test_manual_scans_and_box_art_working_copies_rejected(self):
        for name in ['docs/manual.pdf', 'branding/abrams-icon.png', 'docs/player-reference/field-guide.pdf',
                     'docs/images/abrams-cover-remastered.png', 'branding/README.md']:
            self.add(name)
        failures = dict(self.check())
        self.assertEqual(failures['docs/manual.pdf'], 'unreviewed PDF; manual scans stay local')
        self.assertIn('box-art working copy', failures['branding/abrams-icon.png'])
        self.assertEqual(set(failures), {'docs/manual.pdf', 'branding/abrams-icon.png'})

    def test_index_bytes_override_clean_worktree(self):
        secret = b'gh' + b'p_' + b'A' * 36
        self.add('innocent.txt', secret)
        (self.root / 'innocent.txt').write_bytes(b'now clean but not staged')
        self.assertIn(('innocent.txt', 'credential signature'), self.check())

    def test_secret_word_boundary_matches_previous_regex(self):
        token = b'A' * 36
        self.assertTrue(boundary.secret_match(b' ghp_' + token))
        self.assertTrue(boundary.secret_match(b'ghp_' + token))
        self.assertFalse(boundary.secret_match(b'xghp_' + token))
        self.assertFalse(boundary.secret_match(b'_AKIA' + b'B' * 16))
        # A rejected candidate must not hide a later boundary-aligned key.
        self.assertTrue(boundary.secret_match(b'xsk-' + b'a' * 10 + b'-sk-' + b'b' * 40))
        old = [re.compile(rb'\bgh[pousr]_[A-Za-z0-9]{36,}\b'), re.compile(rb'\bsk-(?:proj-)?[A-Za-z0-9_-]{32,}\b')]
        for sample in [b'.ghp_' + token, b'9ghp_' + token, b'(sk-' + b'z' * 33 + b')', b'sk-short']:
            self.assertEqual(boundary.secret_match(sample), any(p.search(sample) for p in old), sample)

    def test_renamed_original_is_detected_by_fingerprint(self):
        data = b'synthetic original content'
        self.add('notes.txt', data)
        self.assertIn(('notes.txt', 'fingerprinted original game/ROM/content archive'),
                      self.check(known_hashes={sha(data)}))

    def test_renamed_decode_is_rejected_anywhere_in_git(self):
        decoded = b'synthetic decoded plate pixels'
        self.add('docs/images/plate.png', decoded)
        self.assertIn(('docs/images/plate.png', 'decoded original data'),
                      self.check(publication=publication(decoded=[('local-art/pc-ui-v2/x.png', decoded)])))
        # Private kits legitimately carry decodes; only Git/Pages context applies the list.
        self.assertIsNone(boundary.inspect_blob(decoded, set(), publication=publication(decoded=[('x', decoded)])))

    def test_empty_marker_does_not_impersonate_original_content(self):
        self.add('tools/__init__.py', b'')
        self.assertEqual(self.check(known_hashes={sha(b'')}), [])

    def test_oversized_blob(self):
        self.add('large.txt', b'x' * 33)
        self.assertEqual(boundary.limit_text(), '100 MB')
        self.assertEqual(boundary.MAX_BYTES, 100_000_000)
        with patch.object(boundary, 'MAX_BYTES', 32):
            self.assertIn(('large.txt', 'file exceeds 32 bytes'), self.check())
        # Files between 50 MB and 100 MB are ordinary Git objects.
        self.assertEqual(boundary.inspect_blob(b'x' * 33, set()), None)

    def test_lfs_pointers_and_attributes_rejected(self):
        original = b'synthetic original'
        pointer = (b'version https://git-lfs.github.com/spec/v1\noid sha256:' + sha(original).encode() +
                   b'\nsize 18\n')
        self.add('godot/data/shape.dat', pointer)
        self.add('godot/data/other.dat', pointer.replace(sha(original).encode(), b'0' * 64))
        failures = dict(self.check(known_hashes={sha(original)}))
        self.assertEqual(failures['godot/data/shape.dat'], 'Git LFS pointer to a fingerprinted original')
        self.assertEqual(failures['godot/data/other.dat'], 'Git LFS pointer; real bytes are not inspectable')
        self.add('.gitattributes', b'*.dat filter=lfs diff=lfs merge=lfs -text\n')
        # With git-lfs installed, staging may already convert this to a pointer.
        self.add('notes.dat', b'plain text, not yet a pointer')
        reasons = {}
        for name, reason in self.check():
            reasons.setdefault(name, set()).add(reason)
        self.assertIn('Git LFS attribute; real bytes would bypass inspection', reasons['.gitattributes'])
        self.assertIn('Git LFS attribute; real bytes would bypass inspection', reasons['notes.dat'])

    def test_bulk_git_input_exceeds_pipe_capacity_without_losing_results(self):
        self.add('.gitattributes', b'*.lfs filter=lfs\n')
        # Effective attributes must come from the staged tree, not this edit.
        (self.root / '.gitattributes').write_text('*.lfs filter=clean\n')
        names={f'nested/{"path-"*12}{i:04d}'+('.lfs' if i%127==0 else '.txt')
               for i in range(2048)} | {'space and ünicode/positive.lfs'}
        self.assertGreater(len('\0'.join(names).encode()),131072)
        self.add('first.txt',b'first')
        self.add('last.txt',b'last sentinel')
        first=self.git('rev-parse',':first.txt').decode().strip()
        last=self.git('rev-parse',':last.txt').decode().strip()
        inventory={'paths':sorted(names),'oids':[first]*4096+[last]}
        (self.root/'bulk-inputs.json').write_text(json.dumps(inventory))
        # Bound the caller itself: a blocked pipe write can prevent its own
        # subprocess timeout from running.
        code=('import json,sys;from pathlib import Path;'
              'from tools.package.git_boundary import lfs_attributes,git_sizes;'
              'root=Path(sys.argv[1]);'
              'data=json.loads((root/"bulk-inputs.json").read_text());'
              'print(json.dumps({"lfs":sorted(lfs_attributes(root,data["paths"])),"sizes":git_sizes(root,data["oids"])}))')
        result=subprocess.run([sys.executable,'-c',code,str(self.root)],cwd=ROOT,
                              capture_output=True,check=True,timeout=10)
        actual=json.loads(result.stdout)
        self.assertEqual(set(actual['lfs']),{name for name in names if name.endswith('.lfs')})
        self.assertEqual(actual['sizes'],{first:5,last:13})

    def test_deleted_historical_violation_is_still_rejected(self):
        self.add('GENESIS/old.md')
        self.git('commit', '-qm', 'synthetic original')
        self.git('rm', '-q', 'GENESIS/old.md')
        self.git('commit', '-qm', 'remove synthetic original')
        self.assertEqual(self.check(), [])
        self.assertTrue(self.check(history=True))

    def test_symlink_rejected_without_reading_target(self):
        (self.root / 'link.txt').symlink_to('/nonexistent/sensitive')
        self.git('add', 'link.txt')
        self.assertIn(('link.txt', 'symlink, submodule or nonregular entry'), self.check())

    def test_shallow_history_is_not_reported_clean(self):
        self.add('source.py'); self.git('commit', '-qm', 'clean')
        (self.root / '.git/shallow').write_bytes(self.git('rev-parse', 'HEAD'))
        with self.assertRaisesRegex(ValueError, 'Full history'):
            self.check(history=True)

    def test_canonical_pins_are_available_without_originals(self):
        self.assertGreaterEqual(len(boundary.known_inputs()), 68)

    def test_published_browser_archives_are_inspected_not_blanket_rejected(self):
        art = ('local-art/pc-modern/tree.png', b'authored art')
        self.publication = publication(files=[art])
        self.add(PREFIX + 'python-source.zip', archive(('tools/bridge.py', b'clean source')))
        self.add(PREFIX + 'remaster-assets-00.zip', archive(art))
        wasm = b'\x00asm\x01\x00\x00\x00' + b'ghp_' + b'A' * 36
        self.add(PREFIX + 'godot/index.wasm', wasm)
        with patch.object(boundary, 'WEB_WASM_SHA256', sha(wasm)):
            self.assertEqual(self.check(), [])
        self.assertIn((PREFIX + 'godot/index.wasm', 'credential signature'), self.check())
        self.add(PREFIX + 'remaster-assets-01.zip', archive(('local-art/../../GAME/SIM.EXE', b'private')))
        self.assertIn((PREFIX + 'remaster-assets-01.zip', 'unsafe browser archive member'), self.check())

    def test_browser_archives_publish_only_exact_reviewed_bytes(self):
        art = ('local-art/pc-modern/tree.png', b'authored art')
        name = PREFIX + 'remaster-assets-00.zip'
        self.publication = publication(files=[art])
        cases = {
            'unreviewed browser asset path': archive(art, ('local-art/genesis/source/title-original.png', b'x')),
            'browser asset differs from its reviewed publication entry': archive((art[0], b'edited art')),
            'unsafe browser archive member': archive(('local-art/saves/slot.json', b'{}')),
        }
        for reason, data in cases.items():
            with self.subTest(reason=reason):
                self.add(name, data)
                self.assertIn((name, reason), self.check())
        # Reviewed exact members pass, including the approved cover inside a part.
        cover = ('branding/abrams-cover-remastered.png', b'approved cover')
        self.publication = publication(files=[art, cover])
        self.add(name, archive(art, cover))
        self.assertEqual(self.check(), [])

    def test_decoded_members_rejected_by_hash_and_structure(self):
        name = PREFIX + 'remaster-assets-00.zip'
        plate = ('local-art/pc-ui-v2/gps-bin.png', b'decoded plate')
        faces = ('local-art/pc-portraits-v1/faces.json', json.dumps({'source': 'FACES.BMP', 'images': [{'pixels': [1, 2]}]}).encode())
        modern = ('local-art/pc-modern/catalog.json', json.dumps({'models': [{'source_primitives': []}]}).encode())
        self.publication = publication(files=[plate, faces, modern], exceptions=[modern[0]])
        self.publication['decoded_denylist'][sha(plate[1])] = plate[0]
        self.add(name, archive(plate))
        self.assertIn((name, 'browser archive member: decoded original data'), self.check())
        self.publication = publication(files=[faces, modern], exceptions=[modern[0]])
        self.add(name, archive(faces))
        self.assertIn((name, 'browser archive member: decoded original pixels'), self.check())
        # An explicit, documented exception is the only way decoded keys publish.
        self.add(name, archive(modern))
        self.assertEqual(self.check(), [])

    def test_browser_archive_member_secret_and_original_fingerprint_rejected(self):
        name = PREFIX + 'remaster-assets-00.zip'
        original = ('local-art/pc-modern/tree.png', b'known synthetic original')
        self.publication = publication(files=[original])
        self.add(name, archive(original))
        self.assertIn((name, 'browser archive member: fingerprinted original game/ROM/content archive'),
                      self.check(known_hashes={sha(original[1])}))
        secret = ('local-art/pc-modern/tree.png', b'ghp_' + b'A' * 36)
        self.publication = publication(files=[secret])
        self.add(name, archive(secret))
        self.assertIn((name, 'browser archive member: credential signature'), self.check())

    def test_reviewed_historical_publication_is_history_only(self):
        name = PREFIX + 'remaster-assets-00.zip'
        old = archive(('local-art/pc-ui-v2/gps-bin.png', b'previously published decode'))
        self.add(name, old)
        oid = self.git('rev-parse', ':' + name).decode().strip()
        self.publication = publication(historical=[oid])
        self.git('commit', '-qm', 'published before the list')
        # Still in the index: the exemption never applies to current content.
        self.assertIn((name, 'unreviewed browser asset path'), self.check(history=True))
        self.add(name, archive(('local-art/pc-modern/tree.png', b'clean')))
        self.publication = publication(files=[('local-art/pc-modern/tree.png', b'clean')], historical=[oid])
        self.git('commit', '-qm', 'replace')
        self.assertEqual(self.check(history=True), [])
        # Historical archives remain scanned for credentials and originals.
        self.publication = publication(files=[('local-art/pc-modern/tree.png', b'clean')], historical=[oid])
        self.assertIn((name, 'browser archive member: fingerprinted original game/ROM/content archive'),
                      self.check(history=True, known_hashes={sha(b'previously published decode')}))
        # Without the exemption a superseded part is held to the decode rules.
        self.publication = publication(files=[('local-art/pc-modern/tree.png', b'clean')],
                                       decoded=[('gps', b'previously published decode')])
        self.assertIn((name, 'browser archive member: decoded original data'), self.check(history=True))

    def test_superseded_reviewed_part_passes_history(self):
        name = PREFIX + 'remaster-assets-00.zip'
        self.add(name, archive(('local-art/a.png', b'v1'), ('local-art/b.png', b'dropped later')))
        self.publication = publication(files=[('local-art/a.png', b'v1'), ('local-art/b.png', b'dropped later')])
        self.git('commit', '-qm', 'v1 deploy')
        self.assertEqual(self.check(history=True), [])
        # Re-pin a.png, drop b.png and rebuild: v1 now lives only in history.
        self.add(name, archive(('local-art/a.png', b'v2')))
        self.publication = publication(files=[('local-art/a.png', b'v2')])
        self.git('commit', '-qm', 'v2 deploy')
        self.assertEqual(self.check(), [])
        self.assertEqual(self.check(history=True), [])
        # Exact membership still governs the index.
        self.add(name, archive(('local-art/a.png', b'v1')))
        self.assertIn((name, 'browser asset differs from its reviewed publication entry'), self.check())

    def test_superseded_part_still_rejects_decodes_and_unsafe_members(self):
        name = PREFIX + 'remaster-assets-00.zip'
        decoded = ('local-art/pc-ui-v2/gps-bin.png', b'synthetic decode')
        payload = ('local-art/x/faces.json', b'{"faces": [{"pixels": "AAAA"}]}')
        self.add(name, archive(('local-art/saves/slot.png', b'state')))
        self.git('commit', '-qm', 'bad part')
        self.add(name, archive(('local-art/a.png', b'clean')))
        self.git('commit', '-qm', 'clean part')
        current = [('local-art/a.png', b'clean')]
        self.publication = publication(files=current)
        self.assertEqual(self.check(), [])
        self.assertIn((name, 'unsafe browser archive member'), self.check(history=True))
        bad = archive(decoded, payload)
        self.add(name, bad); self.git('commit', '-qm', 'second bad part')
        self.add(name, archive(*current)); self.git('commit', '-qm', 'clean again')
        failures = self.check(history=True, publication=publication(files=current, decoded=[decoded]))
        self.assertIn((name, 'browser archive member: decoded original data'), failures)
        only_payload = archive(payload)
        self.add(name, only_payload); oid = self.git('rev-parse', ':' + name).decode().strip()
        self.git('commit', '-qm', 'payload part')
        self.add(name, archive(*current)); self.git('commit', '-qm', 'clean once more')
        self.publication = publication(files=current, decoded=[decoded], exceptions=['local-art/x/faces.json'])
        self.assertNotIn((name, 'browser archive member: decoded original pixels'), self.check(history=True))
        self.publication = publication(files=current, decoded=[decoded])
        self.assertIn((name, 'browser archive member: decoded original pixels'), self.check(history=True))
        # A recorded historical publication is exempt from the decode rules.
        self.publication = publication(files=current, decoded=[decoded], historical=[oid])
        self.assertNotIn((name, 'browser archive member: decoded original pixels'), self.check(history=True))

    def test_history_inspects_each_blob_once_per_name_class(self):
        for index in range(4):
            self.add(f'docs/copy-{index}.txt', b'same bytes')
            self.git('commit', '-qm', f'copy {index}')
        calls = []
        original = boundary.inspect_blob
        def counted(*args, **kwargs):
            calls.append(args[2] if len(args) > 2 else kwargs.get('name'))
            return original(*args, **kwargs)
        with patch.object(boundary, 'inspect_blob', counted):
            self.assertEqual(self.check(history=True), [])
        self.assertEqual(len(calls), 1)

    def test_unpushed_generated_bundle_growth_is_measured(self):
        self.add('tools/a.py'); self.git('commit', '-qm', 'source')
        self.git('update-ref', 'refs/remotes/origin/main', 'HEAD')
        self.assertEqual(boundary.generated_growth(self.root), 0)
        self.add(PREFIX + 'godot/index.pck', b'p' * 1000)
        self.add('docs/notes.md', b'n' * 500)
        self.git('commit', '-qm', 'bundle')
        self.assertEqual(boundary.generated_growth(self.root), 1000)

    def test_web_exceptions_do_not_extend_to_other_paths(self):
        self.add('other/remaster-assets-00.zip', b'archive')
        self.add(PREFIX + 'godot/other.wasm', b'\x00asm\x00ghp_' + b'A' * 36)
        failures = self.check()
        self.assertIn(('other/remaster-assets-00.zip', 'original/runtime/archive/credential format'), failures)
        self.assertIn((PREFIX + 'godot/other.wasm', 'credential signature'), failures)


class RealPublicationListTests(unittest.TestCase):
    def setUp(self):
        self.data = boundary.load_publication(ROOT)

    def test_runtime_derivations_are_never_published(self):
        derived = {name for names in self.data['runtime_derived'].values() for name in names}
        self.assertTrue(derived)
        self.assertFalse(derived & set(self.data['files']))
        self.assertFalse(set(self.data['decoded_denylist'].values()) & set(self.data['files']))
        self.assertFalse(any(name.startswith(('local-art/genesis/source/', 'reference/', 'local-art/pc-ui-v2/'))
                             for name in self.data['files']))
        self.assertTrue(set(self.data['exceptions']) <= set(self.data['files']))

    def test_modern_source_registry_is_browser_derived_and_never_published(self):
        registry = 'local-art/pc-modern/source-shapes.json'
        self.assertIn(registry, self.data['runtime_derived']['pc'])
        self.assertNotIn(registry, self.data['files'])
        self.assertIn('local-art/pc-modern/catalog.json', self.data['files'])
        catalog = ROOT / 'local-art/pc-modern/catalog.json'
        if not catalog.is_file():
            self.skipTest('requires the local Modern catalogue')
        pin = json.loads(catalog.read_text())['source_registry']
        # The pinned registry bytes are rejected in any Web part or Git blob.
        self.assertEqual(self.data['decoded_denylist'].get(pin['sha256']), registry)

    def test_browser_derivation_module_agrees_with_the_list(self):
        module = ROOT / 'web-prototype/derived_art.mjs'
        if not module.is_file():
            self.skipTest('the source kit carries no browser modules')
        source = module.read_text()
        ui = re.findall(r"\['[A-Z.]+', '([a-z-]+)'\]", source.split('const UI_PLATES')[1].split(';')[0])
        listed = [f'local-art/pc-ui-v2/{name}.png' for name in ui] + re.findall(
            r"'(local-art/[^']+\.(?:png|json))',?\n", source.split('export const PC_DERIVED')[1].split(']);')[0])
        self.assertEqual(listed, self.data['runtime_derived']['pc'])
        self.assertIn(self.data['runtime_derived']['genesis'][0], source)

    def test_local_publication_bytes_match_when_present(self):
        present = [name for name in self.data['files'] if (ROOT / name).is_file()]
        if not present:
            self.skipTest('requires local authored assets')
        for name in present:
            with self.subTest(name=name):
                self.assertEqual(sha((ROOT / name).read_bytes()), self.data['files'][name]['sha256'])


if __name__ == '__main__':
    unittest.main()
