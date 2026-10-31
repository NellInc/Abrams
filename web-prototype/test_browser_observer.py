"""Browser observer frame admission, without original game files or Pyodide."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT), str(Path(__file__).parent)]
from browser_observer import BrowserObserver
from tools.pc_crew_voice import CrewBarks, RadioBarks
from tools.pc_readiness import ReadinessBark
from tests.test_pc_session import program_ram


class StubFrontend:
    error = None

    def observe_packet(self, *_):
        raise AssertionError('no original events in this fixture')

    def paired_video(self, video, ram):
        return {'draw_pass': None, 'reason': 'fixture', 'frontend_program': None}


def observer():
    # The frame checks under test run before any original-file reader is used.
    instance = BrowserObserver.__new__(BrowserObserver)
    instance.mode, instance.frontend, instance.collector, instance.identity = 'frontend', StubFrontend(), None, None
    instance.frame = instance.epoch = instance.audio_sequence = 0
    instance.audio_pending = []
    instance.readiness, instance.crew, instance.radio = ReadinessBark(), CrewBarks(), RadioBarks()
    return instance


class OriginalExitTests(unittest.TestCase):
    # pc-menu-text-trace-04: the first frame after EXIT is still 320x200 with
    # no program; the DOS prompt that follows is 640x350 text.
    def frame(self, ram, width, height, pitch, final=True):
        return observer().after_frame(b'', b'', bytes(ram), bytes(ram), bytes(pitch * height),
                                      width, height, pitch, final)

    def test_dos_prompt_without_a_program_is_flagged(self):
        sample = self.frame(bytearray(640 * 1024), 640, 350, 2560)
        self.assertIs(sample['original_exited'], True)
        self.assertIsNone(sample['program'])
        self.assertEqual(sample['audio']['schema'], 3)
        self.assertIsNone(self.frame(bytearray(640 * 1024), 640, 350, 2560, final=False))

    def test_game_frames_are_never_flagged(self):
        self.assertNotIn('original_exited', self.frame(bytearray(640 * 1024), 320, 200, 1280))
        self.assertNotIn('original_exited', self.frame(program_ram('START'), 320, 200, 1280))

    def test_other_displays_still_fail_closed(self):
        with self.assertRaisesRegex(ValueError, 'invalid paired browser frame'):
            self.frame(program_ram('START'), 640, 350, 2560)
        with self.assertRaisesRegex(ValueError, 'invalid paired browser frame'):
            observer().after_frame(b'', b'', bytes(640 * 1024), bytes(640 * 1024), bytes(100), 640, 350, 2560)


if __name__ == '__main__':
    unittest.main()
