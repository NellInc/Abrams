"""Source contracts for the native launcher; visual/runtime QA is separate."""
from pathlib import Path
import unittest

SOURCE = (Path(__file__).resolve().parents[1] / 'tools/standalone/Launcher.swift').read_text()


class LauncherReleaseUI(unittest.TestCase):
    def test_about_and_user_initiated_project_link(self):
        self.assertIn('withTitle: "About Abrams", action: #selector(showAbout)', SOURCE)
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
