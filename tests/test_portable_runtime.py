"""Portable layout, native core selection and platform storage contracts."""
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from tools.standalone import runtime
from tools.standalone.portable_launcher import verify
from tools.pc_reference_core import core_suffix
from tools.pc_bridge_host import lock_saves


class PortableContracts(unittest.TestCase):
    def test_frozen_macos_discovery_skips_inner_resources_manifest(self):
        from tools.standalone.entry import bundle_path
        with tempfile.TemporaryDirectory() as temporary:
            app=Path(temporary).resolve()/'Abrams.app'
            resources=app/'Contents/Resources'
            executable=resources/'runtime/AbramsRuntime/AbramsRuntime'
            executable.parent.mkdir(parents=True)
            executable.write_text('synthetic runtime')
            (resources/'RUNTIME.json').write_text('{}')
            with patch('tools.standalone.entry.sys.executable',str(executable)):
                self.assertEqual(bundle_path(),app)

    def test_frozen_portable_discovery_finds_folder_manifest(self):
        from tools.standalone.entry import bundle_path
        with tempfile.TemporaryDirectory() as temporary:
            bundle=Path(temporary).resolve()/'Abrams portable'
            executable=bundle/'runtime/AbramsRuntime/AbramsRuntime'
            executable.parent.mkdir(parents=True)
            executable.write_text('synthetic runtime')
            (bundle/'RUNTIME.json').write_text('{}')
            with patch('tools.standalone.entry.sys.executable',str(executable)):
                self.assertEqual(bundle_path(),bundle)

    def test_platform_default_homes_are_outside_install(self):
        with tempfile.TemporaryDirectory() as temporary:
            bundle=Path(temporary)/'installation/Abrams'
            with patch.dict(os.environ,{'LOCALAPPDATA':temporary,'XDG_DATA_HOME':temporary},clear=True):
                for platform,name in [('win32','Abrams'),('linux','abrams')]:
                    with patch.object(runtime.sys,'platform',platform):
                        self.assertEqual(runtime.profile_home(bundle),Path(temporary).resolve()/name)

    def test_core_extension_matches_native_loader(self):
        for platform,suffix in [('win32','.dll'),('linux','.so'),('darwin','.dylib')]:
            with patch('tools.pc_reference_core.sys.platform',platform):
                self.assertEqual(core_suffix(),suffix)

    def test_portable_resources_and_integrity(self):
        with tempfile.TemporaryDirectory() as temporary:
            bundle=Path(temporary)/'portable app with spaces';bundle.mkdir()
            (bundle/'kit').mkdir()
            binary=bundle/'renderer';binary.write_bytes(b'fake renderer')
            manifest={'schema':1,'originals_included':False,'build_id':'test-build','files':[],
                      'portable_files':[{'path':'renderer','sha256':runtime.sha(binary)}]}
            (bundle/'RUNTIME.json').write_text(json.dumps(manifest))
            self.assertEqual(runtime.app_resources(bundle),(bundle.resolve(),manifest))
            self.assertEqual(verify(bundle),manifest)
            binary.write_bytes(b'changed')
            with self.assertRaisesRegex(ValueError,'runtime changed'):verify(bundle)

    def test_portable_manifest_rejects_traversal(self):
        with tempfile.TemporaryDirectory() as temporary:
            bundle=Path(temporary)
            manifest={'schema':1,'originals_included':False,'build_id':'test-build','files':[],
                      'portable_files':[{'path':'../outside','sha256':'0'*64}]}
            (bundle/'RUNTIME.json').write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError,'Unsafe portable'):verify(bundle)

    def test_portable_payload_requires_no_original_files(self):
        from tools.standalone.portable_build import payload
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            records=[{'name':'ABRAMS.COM','sha256':'0'*64}]
            files={'tools/package/game-inputs.json':json.dumps({'files':records}),
                   'godot/project.godot':'config_version=5',
                   '.runtime/pc-core/abrams-trace.json':'{}',
                   '.runtime/pc-core/abrams-trace.so':'synthetic native core'}
            for name,data in files.items():
                path=root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(data)
            allow={'schema':1,'source':['tools/package/game-inputs.json','godot/project.godot'],
                   'private':['GAME/ABRAMS.COM','.runtime/pc-core/abrams-ref.zip',
                              '.runtime/pc-core/abrams-trace.dylib','.runtime/pc-core/abrams-trace.json']}
            (root/'tools/package/allowlist.json').write_text(json.dumps(allow))
            with patch('tools.pc_reference_core.sys.platform','linux'):
                rows=payload(root)
            names={row['path'] for row in rows}
            self.assertIn('.runtime/pc-core/abrams-trace.so',names)
            self.assertFalse(any(name.startswith('GAME/') for name in names))
            self.assertNotIn('.runtime/pc-core/abrams-ref.zip',names)

    def test_exclusive_save_lock_released_on_close(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory=Path(temporary)/'save folder'
            first=lock_saves(directory)
            try:
                with self.assertRaisesRegex(ValueError,'already open'):lock_saves(directory)
            finally:first.close()
            second=lock_saves(directory);second.close()

@unittest.skipUnless(os.environ.get('ABRAMS_PORTABLE_SMOKE'), 'Native portable core smoke opt-in')
class NativePortableCoreSmoke(unittest.TestCase):
    def test_native_observer_exports_and_original_free_boot(self):
        import ctypes
        import zipfile
        from tools.pc_reference_core import PcReferenceCore
        root=Path(__file__).resolve().parents[1]
        library=root/('.runtime/pc-core/abrams-trace'+core_suffix())
        manifest=json.loads((root/'.runtime/pc-core/abrams-trace.json').read_text())
        native=ctypes.CDLL(str(library.resolve()))
        for symbol in ('abrams_trace_configure','abrams_observer_checkpoint_size',
                       'abrams_state_flush_overlay','abrams_state_reload_overlay'):
            self.assertTrue(hasattr(native,symbol),symbol)
        with tempfile.TemporaryDirectory(prefix='Abrams native smoke ') as temporary:
            content=Path(temporary)/'synthetic.zip'
            with zipfile.ZipFile(content,'w') as archive:
                archive.writestr('ABRAMS.COM',b'\xeb\xfe')
                archive.writestr('DOSBOX.CONF','[autoexec]\nABRAMS.COM\n')
            core=PcReferenceCore(library,content,Path(temporary)/'saves',expected_sha256=manifest['trace_sha256'])
            try:
                core.run(240)
                self.assertEqual(core.frame,240)
                self.assertIsNotNone(core.last_video)
                self.assertEqual(len(core.conventional_memory()),640*1024)
            finally:core.close()

if __name__=='__main__':unittest.main()
