import subprocess
import json
import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch
from tools.standalone.sign_macos import signing_targets, signature_details, refresh_payload


class MacSigningContracts(unittest.TestCase):
    def bundle(self, root):
        app=root.resolve()/'Abrams.app';(app/'Contents').mkdir(parents=True)
        (app/'Contents/Info.plist').write_text('synthetic')
        return app

    def test_native_code_before_nested_envelopes_and_outer_app(self):
        with tempfile.TemporaryDirectory() as temp:
            app=self.bundle(Path(temp))
            paths=[app/'Contents/Helpers/Renderer.app/Contents/MacOS/Renderer',
                   app/'Contents/Resources/Python.framework/Versions/A/Python',
                   app/'Contents/MacOS/Abrams']
            for path in paths:
                path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(b'\xcf\xfa\xed\xfesynthetic')
            targets=signing_targets(app)
            self.assertEqual(targets[-1],app)
            for container in [app/'Contents/Helpers/Renderer.app',app/'Contents/Resources/Python.framework']:
                for native in paths:
                    if native.is_relative_to(container):self.assertLess(targets.index(native),targets.index(container))

    def test_internal_framework_links_not_signed_twice(self):
        with tempfile.TemporaryDirectory() as temp:
            app=self.bundle(Path(temp));native=app/'Contents/Python'
            native.write_bytes(b'\xcf\xfa\xed\xfe')
            (app/'Contents/Alias').symlink_to('Python')
            self.assertEqual(signing_targets(app),[native,app])

    def test_external_link_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);app=self.bundle(root)
            (root/'outside').write_text('private')
            (app/'Contents/link').symlink_to(root/'outside')
            with self.assertRaisesRegex(ValueError,'External'):signing_targets(app)

    def test_empty_bundle_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaisesRegex(ValueError,'no native'):signing_targets(self.bundle(Path(temp)))

    def test_signed_core_receipt_and_payload_pin_shipped_bytes(self):
        from tools.standalone.runtime import sha, valid_payload
        with tempfile.TemporaryDirectory() as temp:
            app=self.bundle(Path(temp));resources=app/'Contents/Resources'
            core=resources/'kit/.runtime/pc-core/abrams-trace.dylib'
            core.parent.mkdir(parents=True)
            core.write_bytes(b'signed native code')
            receipt=core.with_suffix('.json')
            receipt.write_text(json.dumps({'trace_sha256':'unsigned-core'}))
            files=[{'path':p.relative_to(resources/'kit').as_posix(),'sha256':'old','size':0} for p in [core,receipt]]
            manifest={'schema':1,'build_id':'unsigned-build','originals_included':False,'files':files}
            (resources/'RUNTIME.json').write_text(json.dumps(manifest))
            refresh_payload(app,manifest,'TEAM')
            updated=json.loads((resources/'RUNTIME.json').read_text())
            valid_payload(resources,updated)
            details=json.loads(receipt.read_text())
            self.assertEqual(details['trace_sha256'],sha(core))
            self.assertEqual(details['unsigned_trace_sha256'],'unsigned-core')
            self.assertNotEqual(updated['build_id'],'unsigned-build')
            # A repeat signing (notarization retry) keeps the pre-signing identity.
            core.write_bytes(b'signed twice')
            refresh_payload(app,updated,'TEAM')
            again=json.loads(receipt.read_text())
            self.assertEqual(again['trace_sha256'],sha(core))
            self.assertEqual(again['unsigned_trace_sha256'],'unsigned-core')

    def test_signature_metadata_requires_developer_id_and_runtime(self):
        text='CodeDirectory flags=0x10000(runtime)\nAuthority=Developer ID Application: Example (TEAM)\nTeamIdentifier=TEAM\nTimestamp=29 Sep 2026\n'
        with patch('tools.standalone.sign_macos.subprocess.run',return_value=subprocess.CompletedProcess([],0,'',text)):
            details=signature_details(Path('/synthetic.app'))
        self.assertTrue(details['developer_id']);self.assertTrue(details['hardened_runtime'])
        self.assertEqual(details['team_id'],'TEAM');self.assertTrue(details['secure_timestamp'])

if __name__ == '__main__':unittest.main()
