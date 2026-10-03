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
    def test_native_freezer_pins_utf8_in_bootloader_and_cache(self):
        from tools.standalone.build import freeze
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)/'source';entry=root/'tools/standalone/entry.py'
            entry.parent.mkdir(parents=True);entry.write_text('import sys\n',encoding='utf-8')
            cache=Path(temporary)/'cache'
            with patch('tools.standalone.build.ROOT',root), patch('tools.standalone.build.subprocess.check_output',return_value='6.22.3 12.0.0'), patch('tools.standalone.build.subprocess.run') as run:
                freeze(cache,Path('synthetic-python'),target='win32')
            command=run.call_args.args[0]
            self.assertEqual(command[command.index('--python-option')+1],'X utf8')
            self.assertEqual(json.loads((cache/'frozen.json').read_text())['python_options'],['X utf8'])

    def test_windows_launcher_rejects_a_non_utf8_frozen_runtime(self):
        from types import SimpleNamespace
        from tools.standalone.portable_launcher import main
        with patch('tools.standalone.portable_launcher.sys.platform','win32'), patch('tools.standalone.portable_launcher.sys.flags',SimpleNamespace(utf8_mode=0)):
            with self.assertRaisesRegex(RuntimeError,'UTF-8 mode'):main()

    @unittest.skipIf(os.name == 'nt', 'POSIX executable mode contract')
    def test_fallback_runtime_copy_preserves_executable_mode(self):
        from tools.standalone.build import clone_file
        with tempfile.TemporaryDirectory() as temporary:
            source=Path(temporary)/'runtime';source.write_bytes(b'synthetic executable');source.chmod(0o755)
            target=Path(temporary)/'copied'
            with patch('tools.standalone.build.sys.platform','linux'):
                clone_file(source,target)
            self.assertEqual(target.read_bytes(),source.read_bytes())
            self.assertEqual(target.stat().st_mode & 0o777,0o755)

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

    def test_invoke_forwards_failure_stderr_and_success_json_only(self):
        import contextlib,io,subprocess,sys
        from tools.standalone import portable_launcher
        error='{"error": "PC_VIEW_FAILED: synthetic"}\n'
        for code,out,err,expected in [(2,'Godot Engine v4.7.2 banner\n',error,error),
                                      (1,'Godot Engine banner only\n','','Godot Engine banner only\n'),
                                      (0,'{"pc_installed": true}','renderer warning\n','{"pc_installed": true}')]:
            with self.subTest(code=code,err=err), tempfile.TemporaryDirectory() as temporary:
                stream=io.StringIO()
                with patch.object(portable_launcher,'verify'), patch.object(portable_launcher.sys,'platform','linux'), \
                     patch.object(portable_launcher.subprocess,'run',return_value=subprocess.CompletedProcess([],code,out,err)), \
                     patch.object(sys,'argv',['launcher','--bundle',temporary,'--invoke','--play']), contextlib.redirect_stdout(stream):
                    self.assertEqual(portable_launcher.main(),code)
                self.assertEqual(stream.getvalue(),expected)

    def test_portable_game_output_goes_to_profile_log_and_failure_is_json(self):
        import contextlib,io,subprocess,sys
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary).resolve();bundle=root/'portable app';home=root/'player data';home.mkdir()
            for name in ['renderer/AbramsRenderer.exe' if sys.platform=='win32' else 'renderer/AbramsRenderer',
                         'runtime/AbramsRuntime/'+('AbramsRuntime.exe' if sys.platform=='win32' else 'AbramsRuntime')]:
                path=bundle/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(b'synthetic');path.chmod(0o755)
            def game(arguments,env,stdout,stderr):
                self.assertEqual(stderr,subprocess.STDOUT)
                stdout.write(b'Godot Engine banner\nPC_VIEW_FAILED: synthetic\n');return game.code
            for game.code in (3,0):
                stream=io.StringIO()
                with self.subTest(code=game.code), patch.object(runtime,'app_resources',return_value=(bundle,{})), \
                     patch.object(runtime,'prepare_install',return_value=root/'install'), patch.object(runtime,'genesis_enabled',return_value=False), \
                     patch.object(runtime.subprocess,'run'), patch.object(runtime.subprocess,'call',side_effect=game), contextlib.redirect_stderr(stream):
                    self.assertEqual(runtime.launch(bundle,home,[]),game.code)
                if game.code:
                    message=json.loads(stream.getvalue())['error']
                    self.assertIn('exited with code 3',message);self.assertIn('game.log',message);self.assertIn('PC_VIEW_FAILED: synthetic',message)
                else:self.assertEqual(stream.getvalue(),'')
            self.assertEqual((home/'logs/game.log').read_bytes().count(b'PC_VIEW_FAILED: synthetic'),2)

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
