"""Independent scalar equivalence for the bulk observer byte operations."""
import random
import unittest
from tools.pc_pixel_bytes import BgrxRectProof, bgrx_rect_rgb, indexed_rgb


class PixelBytesTests(unittest.TestCase):
    def test_every_rectangle_of_small_frame_including_empty_edges(self):
        w, h = 9, 7
        raw = bytes((i*73+19)%256 for i in range(w*h*4))
        for x in range(w+1):
            for y in range(h+1):
                for width in range(w-x+1):
                    for height in range(h-y+1):
                        expected = bytes(raw[((y+dy)*w+x+dx)*4+c]
                                         for dy in range(height) for dx in range(width) for c in (2,1,0))
                        self.assertEqual(bgrx_rect_rgb(raw,w,h,(x,y,width,height)),expected)
                        self.assertTrue(BgrxRectProof(expected,w,h,(x,y,width,height)).matches(raw))

    def test_native_boundaries_random_rectangles_and_nonzero_x_byte(self):
        rng = random.Random(1701)
        raw = rng.randbytes(320*200*4)
        cases = [(0,0,320,200),(319,199,1,1),(134,13,51,97),(128,137,62,44)]
        for _ in range(100):
            x,y=rng.randrange(320),rng.randrange(200)
            cases.append((x,y,rng.randrange(321-x),rng.randrange(201-y)))
        for x,y,w,h in cases:
            expected = bytes(raw[((y+dy)*320+x+dx)*4+c] for dy in range(h) for dx in range(w) for c in (2,1,0))
            self.assertEqual(bgrx_rect_rgb(raw,320,200,(x,y,w,h)),expected)
            proof=BgrxRectProof(expected,320,200,(x,y,w,h))
            self.assertTrue(proof.matches(raw))
            if w*h:
                changed=bytearray(raw);changed[(y*320+x)*4]^=1
                self.assertFalse(proof.matches(changed))

    def test_every_palette_channel_value_with_duplicate_and_shuffled_indices(self):
        pixels = bytes(range(16))*13+bytes(reversed(range(16)))
        for value in range(256):
            palette = [[(value+i)%256,(value*17+i*3)%256,(value*51+i*7)%256] for i in range(16)]
            self.assertEqual(indexed_rgb(pixels,palette),bytes(c for pixel in pixels for c in palette[pixel]))
        self.assertEqual(indexed_rgb(b'',[[0,0,0]]*16),b'')
        self.assertEqual(indexed_rgb(bytes(40),[[255,128,64]]*16),bytes([255,128,64])*40)

    def test_malformed_input_never_becomes_partial_or_padded_evidence(self):
        for rect in [(-1,0,1,1),(0,-1,1,1),(0,0,-1,1),(0,0,1,-1),(1,0,1,1),(0,1,1,1),(0.0,0,1,1)]:
            with self.assertRaises(ValueError): bgrx_rect_rgb(bytes(4),1,1,rect)
        for raw in [bytes(3),bytes(5)]:
            with self.assertRaises(ValueError): bgrx_rect_rgb(raw,1,1,(0,0,1,1))
        for pixels,palette in [(bytes([16]),[[0,0,0]]*16),(b'\0',[[0,0,0]]*15),(b'\0',[[0,0]]*16)]:
            with self.assertRaises(ValueError): indexed_rgb(pixels,palette)


    def test_compiled_proof_requires_full_current_RGB_and_keeps_X_padding_ignored(self):
        raw=bytes((i*17)%256 for i in range(9*7*4));rect=(2,1,5,4)
        rgb=bgrx_rect_rgb(raw,9,7,rect);proof=BgrxRectProof(rgb,9,7,rect)
        for y in range(1,5):
            for x in range(2,7):
                for channel in range(4):
                    changed=bytearray(raw);changed[(y*9+x)*4+channel]^=1
                    self.assertEqual(proof.matches(changed),channel==3)
        for incomplete in (rgb[:-1],rgb+b'0',b''):
            self.assertFalse(BgrxRectProof(incomplete,9,7,rect).matches(raw))
        for malformed in (raw[:-1],raw+b'0'):
            with self.assertRaises(ValueError):proof.matches(malformed)
        for invalid in ((-1,1,5,4),(2,1,8,4),(2.0,1,5,4),(2,1,-1,4)):
            with self.assertRaises(ValueError):BgrxRectProof(rgb,9,7,invalid)
        changed=bytearray(raw);changed[0]^=1
        self.assertTrue(proof.matches(changed))  # Pixels outside the source run are irrelevant.
