"""Source contracts for the native launcher; visual/runtime QA is separate."""
import configparser
from pathlib import Path
import unittest

SOURCE = (Path(__file__).resolve().parents[1] / 'tools/standalone/Launcher.swift').read_text()


class LauncherReleaseUI(unittest.TestCase):
    def test_formal_name_and_logo_free_startup_keep_save_location(self):
        from tools.standalone.build import APP_NAME
        root = Path(__file__).resolve().parents[1]
        config = configparser.ConfigParser()
        config.read_string('[godot]\n' + (root / 'godot/project.godot').read_text(encoding='utf-8'))
        application = config['application']
        self.assertEqual(application['config/name'].strip('"'), APP_NAME)
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

    def test_about_and_user_initiated_project_link(self):
        self.assertIn('withTitle: "About \\(appName)", action: #selector(showAbout)', SOURCE)
        self.assertIn('https://github.com/NellInc/Abrams', SOURCE)
        self.assertEqual(SOURCE.count('NSWorkspace.shared.open('), 1)
        self.assertIn('@objc func openGitHub() { NSWorkspace.shared.open(githubURL) }', SOURCE)
        self.assertIn('Dedicated to David “Ming” Kenny', SOURCE)
        self.assertIn('Original game by Dynamix.', SOURCE)
        self.assertIn('label("Remastered by Nell Watson",', SOURCE)
        self.assertIn('Independent, unofficial fan remaster', SOURCE)

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

    def test_accessibility_keyboard_and_release_version(self):
        self.assertIn('setAccessibilityLabel("Installation status")', SOURCE)
        self.assertIn('setAccessibilityLabel("Open Abrams on GitHub in your browser")', SOURCE)
        self.assertIn('playButton.keyEquivalent = "\\r"', SOURCE)
        self.assertIn('pcButton.keyEquivalent = "i"', SOURCE)
        self.assertIn('info["AbramsReleaseVersion"]', SOURCE)
        self.assertIn('info["CFBundleVersion"]', SOURCE)


if __name__ == '__main__':
    unittest.main()
