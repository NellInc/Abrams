"""Source contracts for the native launcher; visual/runtime QA is separate."""
import configparser
from pathlib import Path
import unittest

SOURCE = (Path(__file__).resolve().parents[1] / 'tools/standalone/Launcher.swift').read_text()


class LauncherReleaseUI(unittest.TestCase):
    def test_formal_name_and_logo_free_startup_keep_save_location(self):
        from tools.standalone.build import APP_NAME, VERSION
        root = Path(__file__).resolve().parents[1]
        config = configparser.ConfigParser()
        config.read_string('[godot]\n' + (root / 'godot/project.godot').read_text(encoding='utf-8'))
        application = config['application']
        self.assertEqual(APP_NAME, 'M1 Abrams Battle Tank Fan Remaster')
        self.assertIn(f'?? "{APP_NAME}"', SOURCE)
        windows = (root / 'tools/standalone/portable_launcher.c').read_text(encoding='utf-8')
        self.assertEqual(windows.count(f'L"{APP_NAME}"'), 2)
        self.assertEqual(application['config/name'].strip('"'), APP_NAME)
        self.assertEqual(application['config/version'].strip('"'), VERSION)
        self.assertFalse(application.getboolean('boot_splash/show_image'))
        self.assertEqual(application.getint('boot_splash/minimum_display_time'), 0)
        self.assertEqual(application['boot_splash/bg_color'], 'Color(0, 0, 0, 1)')
        self.assertTrue(application.getboolean('config/use_custom_user_dir'))
        self.assertEqual(application['config/custom_user_dir_name'].strip('"'),
                         'Godot/app_userdata/Abrams - Reconstruction')
        self.assertIn('window.title = appName', SOURCE)
        self.assertIn('panel.title = "About \\(appName)"', SOURCE)
        self.assertIn('CFBundleDisplayName', SOURCE)
        for name in ('pc_bridge_viewer.gd', 'portable_setup.gd'):
            script = (root / 'godot/scripts' / name).read_text(encoding='utf-8')
            self.assertIn('ProjectSettings.get_setting("application/config/name")', script)
        builder = (root / 'tools/standalone/build.py').read_text(encoding='utf-8')
        self.assertIn("'CFBundleDisplayName':APP_NAME", builder)
        self.assertIn("'CFBundleName':APP_NAME", builder)

    def test_native_clone_preserves_pinned_source_bytes(self):
        root = Path(__file__).resolve().parents[1]
        path = root / '.github/workflows/portable-alpha.yml'
        if not path.is_file():
            self.skipTest('Repository workflow is outside the isolated player source kit')
        workflow = path.read_text(encoding='utf-8')
        self.assertIn('git clone --config core.autocrlf=false --config core.eol=lf', workflow)
        self.assertNotIn('git -c core.autocrlf=false clone', workflow)

    def test_portable_alpha_gates_original_bytes_and_setup_parse_errors(self):
        path = Path(__file__).resolve().parents[1] / '.github/workflows/portable-alpha.yml'
        if not path.is_file():
            self.skipTest('Repository workflow is outside the isolated player source kit')
        workflow = path.read_text(encoding='utf-8')
        # The denylist comes from the checkout, never from the ZIP being vetted.
        trusted = workflow.index("(root/'tools/package/game-inputs.json').read_bytes()")
        self.assertLess(trusted, workflow.index('with zipfile.ZipFile(archive) as z:'))
        self.assertNotIn("z.read('tools/package/game-inputs.json'))['files']", workflow)
        self.assertIn("'Input inventory differs from checkout'", workflow)
        self.assertLess(workflow.index("'Input inventory differs from checkout'"), workflow.index('z.extractall(root)'))
        # Godot exits 0 on parse errors, so the setup smoke must read its logs.
        self.assertIn("grep -Eq 'SCRIPT ERROR:|Parse Error:|^ERROR:' \"$CHECK_LOG\" \"$SMOKE_LOG\"", workflow)
        self.assertIn("grep -q 'PORTABLE_SETUP_SMOKE: PASS' \"$SMOKE_LOG\"", workflow)
        self.assertNotIn('ABRAMS_BUNDLE', workflow)

    def test_box_cover_loading_screen_is_packaged_without_a_logo_or_hold(self):
        import json
        root = Path(__file__).resolve().parents[1]
        manifest = json.loads((root / 'tools/package/allowlist.json').read_text())
        component = 'godot/scripts/pc_startup_splash.gd'
        viewer = (root / 'godot/scripts/pc_bridge_viewer.gd').read_text()
        splash = (root / component).read_text()
        self.assertIn(component, manifest['source'])
        self.assertIn('branding/abrams-cover-remastered.png', manifest['private'])
        self.assertNotIn('branding/abrams-cover-remastered.png', manifest['source'])
        self.assertIn('COVER_PATH := "branding/abrams-cover-remastered.png"', splash)
        self.assertIn('TextureRect.STRETCH_KEEP_ASPECT_CENTERED', splash)
        self.assertIn('Control.MOUSE_FILTER_IGNORE', splash)
        self.assertNotIn('create_timer(', splash)
        self.assertNotIn('create_tween(', splash)
        self.assertIn('if paint_first:\n\t\tawait RenderingServer.frame_post_draw', viewer)
        self.assertIn('await RenderingServer.frame_post_draw\n\t\tif closing: return', viewer)
        self.assertIn('if closing: return\n\t_load_world_presentation', viewer)
        self.assertIn('startup_splash.show_error(status.text)', viewer)
        apply = viewer.split('func _apply_sample(', 1)[1].split('func _capture(', 1)[0]
        self.assertLess(apply.index('invalid original framebuffer'), apply.index('_finish_startup_display()'))
        self.assertLess(apply.index('_present_tandem('), apply.index('_finish_startup_display()'))

    def test_about_and_user_initiated_project_link(self):
        self.assertIn('withTitle: "About \\(appName)", action: #selector(showAbout)', SOURCE)
        self.assertIn('https://github.com/NellInc/Abrams', SOURCE)
        self.assertEqual(SOURCE.count('NSWorkspace.shared.open('), 2)
        self.assertIn('@objc func openGitHub() { NSWorkspace.shared.open(githubURL) }', SOURCE)
        self.assertIn('Dedicated to David “Ming” Kenny', SOURCE)
        self.assertIn('Original game by Dynamix.', SOURCE)
        self.assertIn('label("Fan Remastered by Nell Watson",', SOURCE)
        self.assertIn('Independent, unofficial fan remaster', SOURCE)

    def test_embedded_reference_navigation_and_credits(self):
        self.assertIn('import WebKit', SOURCE)
        self.assertIn('web.loadFileURL(url, allowingReadAccessTo: navigation.directory)', SOURCE)
        self.assertIn('configuration.websiteDataStore = .nonPersistent()', SOURCE)
        self.assertIn('resolvingSymlinksInPath().standardizedFileURL', SOURCE)
        self.assertIn('resolved.deletingLastPathComponent() == directory', SOURCE)
        self.assertIn('action.navigationType == .linkActivated', SOURCE)
        self.assertIn('["keyboard-controls.pdf", "field-guide.pdf"]', SOURCE)
        self.assertIn('decisionHandler(.cancel)', SOURCE)
        self.assertIn('Back to setup', SOURCE)
        self.assertIn('originalCredits() + "\\n\\nGame content & licensing\\n\\n" + rights', SOURCE)
        root = Path(__file__).resolve().parents[1]
        reader = (root/'godot/scripts/pc_reference_library.gd').read_text()
        for section in ('Controls', 'Scenarios', 'Vehicles', 'Weapons', 'Credits'):
            self.assertIn('"'+section+'"', reader)
        self.assertIn('key.add_theme_font_size_override("normal_font_size",24)', reader)
        self.assertIn('key.text="[b]"', reader)
        self.assertIn('file!=file.get_file()', reader)
        self.assertIn('file.contains("..")', reader)
        self.assertNotIn('OS.shell_open', reader)
        self.assertNotIn('create_timer', reader)
        self.assertIn('body.remove_child(child)', reader)
        self.assertIn('["manual_maps","maps","wireframes","models"]', reader)
        self.assertIn('_entries("remaster_controls","Remaster shortcuts",true)', reader)
        self.assertIn('BarlowCondensed-SemiBold.ttf', reader)
        self.assertIn('host.size-Vector2i(48,48)', reader)
        self.assertNotIn('_entries("uncertainties"', reader)
        self.assertIn('_spec_row(stack,SPEC_LABELS[field],specs[field])', reader)
        menu = (root/'godot/scripts/pc_play_menu.gd').read_text()
        self.assertIn('release_keys=true', menu.split('func _reader_changed',1)[1])
        self.assertIn('open_menus["reference"]=true', menu)
        self.assertIn('open_menus.erase("reference")', menu)

    def test_rights_and_original_game_requirements(self):
        for text in (
            'asserts no ownership, moral rights or other rights over the original game content',
            'Original copyrights and trademarks remain with their respective rights holders',
            'free under the licences included with this release',
            'A separate, supported copy of the original PC game is required',
            'An original Genesis ROM is optional',
            'Neither is bundled with this application',
        ):
            self.assertIn(text, SOURCE)
        self.assertNotIn('Modern graphics are deferred', SOURCE)

    def test_play_and_import_guards(self):
        self.assertIn('guard pcReady, !busy, running == nil else { return }', SOURCE)
        self.assertIn('playButton.isEnabled = enabled && pcReady', SOURCE)
        self.assertIn('genesisButton.isEnabled = enabled && pcReady', SOURCE)
        self.assertIn('guard !busy, running == nil, folder || pcReady else { return }', SOURCE)
        self.assertIn('Your source folder will stay unchanged.', SOURCE)

    def test_bounded_async_output_and_safe_close(self):
        self.assertEqual(SOURCE.count('DispatchQueue.global().async'), 2)
        self.assertIn('Self.readOutput(pipe, limit: 65536)', SOURCE)
        self.assertIn('Self.readOutput(pipe, limit: 16384)', SOURCE)
        self.assertIn('if tail.count > limit { tail = Data(tail.suffix(limit)) }', SOURCE)
        self.assertIn('func windowShouldClose(_ sender: NSWindow) -> Bool { canCloseLauncher() }', SOURCE)
        self.assertIn('if running != nil || busy {', SOURCE)
        self.assertNotIn('process.terminate(', SOURCE)

    def test_play_failure_shows_runtime_error_or_newest_log_lines(self):
        play = SOURCE[SOURCE.index('@objc func play()'):SOURCE.index('@objc func openGitHub()')]
        self.assertIn('String(decoding: tail, as: UTF8.self)', play)
        self.assertIn('JSONSerialization.jsonObject(with: $0)', play)
        self.assertIn('String(text.suffix(1799))', play)
        self.assertNotIn('prefix(', play)

    def test_portable_setup_smoke_receipt_only_on_success(self):
        setup = (Path(__file__).resolve().parents[1] / 'godot/scripts/portable_setup.gd').read_text()
        smoke = setup[setup.index('if "--setup-smoke" in OS.get_cmdline_user_args():'):setup.index('play.disabled = not installed')]
        self.assertEqual(setup.count('PORTABLE_SETUP_SMOKE: PASS'), 1)
        self.assertLess(smoke.index('quit(1)'), smoke.index('else:'))
        self.assertGreater(smoke.index('PORTABLE_SETUP_SMOKE: PASS'), smoke.index('else:'))

    def test_accessibility_keyboard_and_release_version(self):
        self.assertIn('setAccessibilityLabel("Installation status")', SOURCE)
        self.assertIn('setAccessibilityLabel("Open Abrams on GitHub in your browser")', SOURCE)
        self.assertIn('playButton.keyEquivalent = "\\r"', SOURCE)
        self.assertIn('pcButton.keyEquivalent = "i"', SOURCE)
        self.assertIn('info["AbramsReleaseVersion"]', SOURCE)
        self.assertIn('info["CFBundleVersion"]', SOURCE)


if __name__ == '__main__':
    unittest.main()
