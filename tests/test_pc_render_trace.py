import ctypes as C
import unittest

from tools.pc_render_trace import Collector


class RenderTraceTests(unittest.TestCase):
    def collector(self):
        return Collector(None, history_limit=2)

    def event(self, c, event, offset=0, raw=b'', regs=None):
        registers = (C.c_uint16 * 12)(*(regs or [0] * 12))
        data = C.create_string_buffer(raw)
        c.observe(event, registers, C.addressof(data), offset, len(raw))
        if c.error: raise c.error

    def finish_pass(self, c, sequence, page):
        c.active = {'sequence': sequence, 'page_offset': page, 'unsupported': []}
        self.event(c, 4)

    def present(self, c, slot, pixels=b'\x00\x00\x00\x00'):
        self.event(c, 12, slot, pixels, [1, 1] + [0] * 10)
        return c.paired_video((pixels, 1, 1, 4))

    def test_scanout_uses_displayed_page_not_latest_complete_pass(self):
        c = self.collector()
        self.finish_pass(c, 1, 0)
        self.finish_pass(c, 2, 8192)
        self.event(c, 10, 0)
        self.event(c, 11, 1)
        # A newer offscreen pass can finish after this buffer was scanned.
        self.finish_pass(c, 3, 8192)
        self.assertEqual(self.present(c, 1)['draw_pass']['sequence'], 1)
        self.event(c, 10, 8192)
        self.event(c, 11, 2)
        self.assertEqual(self.present(c, 2)['draw_pass']['sequence'], 3)

    def test_triple_buffer_slot_is_preserved_while_next_scanout_runs(self):
        c = self.collector()
        self.finish_pass(c, 1, 0)
        self.event(c, 10, 0)
        self.event(c, 11, 2)
        self.finish_pass(c, 2, 8192)
        self.event(c, 10, 8192)
        self.assertEqual(self.present(c, 2)['draw_pass']['sequence'], 1)
        self.event(c, 11, 0)
        self.assertEqual(self.present(c, 0)['draw_pass']['sequence'], 2)

    def test_redrawing_displayed_page_invalidates_scanout_even_if_pass_finishes(self):
        c = self.collector()
        self.finish_pass(c, 1, 0)
        self.event(c, 10, 0)
        self.event(c, 13, 0x35A0, b'\0' * 8 + b'\x00\xa0')
        self.finish_pass(c, 2, 0)
        self.event(c, 11, 0)
        result = self.present(c, 0)
        self.assertIsNone(result['draw_pass'])
        self.assertEqual(result['reason'], 'displayed page redrawn during scanout')
        self.event(c, 10, 0)
        self.event(c, 11, 1)
        self.assertEqual(self.present(c, 1)['draw_pass']['sequence'], 2)

    def test_scanout_of_incomplete_or_unobserved_page_is_explicit(self):
        c = self.collector()
        self.event(c, 13, 0x35A0, b'\0' * 8 + b'\x00\xa2')
        self.event(c, 10, 8192)
        self.finish_pass(c, 1, 8192)
        self.event(c, 11, 0)
        self.assertIsNone(self.present(c, 0)['draw_pass'])
        self.assertIsNone(self.present(c, 2)['draw_pass'])

    def test_host_framebuffer_must_match_traced_bytes_and_dimensions(self):
        c = self.collector()
        self.present(c, 0)
        with self.assertRaisesRegex(ValueError, 'bytes differ'):
            c.paired_video((b'\x01\x00\x00\x00', 1, 1, 4))
        with self.assertRaisesRegex(ValueError, 'dimensions differ'):
            c.paired_video((b'\0' * 8, 1, 1, 8))

    def test_sprite_root_resets_stale_matrix_and_records_unsupported_commands(self):
        c = self.collector()
        c.active = {'unsupported': []}
        c.current, c.composition_cx = {'pointer': 123}, 4
        self.event(c, 7, 20, b'\x80\x05', [0, 123, 0, 0, 0, 20] + [0] * 6)
        self.assertIsNone(c.current)
        self.assertIsNone(c.composition_cx)
        self.assertEqual(c.active['unsupported'][0]['kind'], 'sprite_root')
        self.event(c, 8, 22, b'\0' * 4)
        self.event(c, 6)
        self.assertEqual([x['kind'] for x in c.active['unsupported']],
                         ['sprite_root', 'opaque_command', 'unattributed_polygon'])

    def test_live_history_is_bounded_and_count_is_total(self):
        c = self.collector()
        for i in range(10): self.finish_pass(c, i, (i % 2) * 8192)
        self.assertEqual([p['sequence'] for p in c.passes], [8, 9])
        self.assertEqual(c.completed_count, 10)
        self.assertEqual(len(c.pages), 2)

    def test_material_background_is_owned_by_original_drawing_page(self):
        c = self.collector()
        self.event(c, 13, 0x35A0, b'\0' * 8 + b'\x00\xa0')
        self.event(c, 15, 100, b'\x05\x00\x08\x00',
                   [0, 287, 61, 0, 32, 61] + [0] * 6)
        horizon = {'kind': 'horizon', 'line': [[32, 61], [287, 61]], 'colors': [5, 8]}
        self.assertEqual(c.backgrounds[0], horizon)
        self.event(c, 13, 0x35A0, b'\0' * 8 + b'\x00\xa2')
        self.event(c, 16, regs=[0, 0, 0, 8] + [0] * 8)
        self.assertEqual(c.backgrounds[8192], {'kind': 'solid', 'color': 8})
        self.assertEqual(c.backgrounds[0], horizon)
        self.event(c, 13, 0x35A0, b'\0' * 8 + b'\x00\xa0')
        self.assertIsNone(c.backgrounds[0])
        self.assertEqual(c.backgrounds[8192], {'kind': 'solid', 'color': 8})

    def test_palette_is_frozen_with_scanned_buffer_not_latest_draw_palette(self):
        c = self.collector()
        first = bytes(value for i in range(16) for value in (i, i + 16, i + 32, 0))
        second = bytes(value for i in range(16) for value in (255 - i, 0, i, 0))
        expected = [list(first[i:i + 3]) for i in range(0, 64, 4)]
        self.event(c, 14, raw=first)
        self.assertEqual(c.palette_rgb, expected)
        self.finish_pass(c, 1, 0)
        self.event(c, 10, 0, first)
        self.event(c, 11, 2)
        self.event(c, 14, raw=second)
        self.event(c, 10, 8192, second)
        self.assertEqual(self.present(c, 2)['palette_rgb'], expected)
        self.assertNotEqual(c.palette_rgb, expected)

    def test_invalid_draw_palette_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'unsupported palette snapshot'):
            self.event(self.collector(), 14, raw=b'\0' * 63)


if __name__ == '__main__': unittest.main()
