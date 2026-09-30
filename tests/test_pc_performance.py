import random
import hashlib
import struct
from collections import Counter, OrderedDict
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from tools.pc_live_state import SimStateReader
from tools.pc_bitmaps import read_ega_bitmap
from tools.pc_text_trace import TextRuns, MAX_RGB_PROOFS
from tools.pc_pixel_bytes import indexed_rgb, bgrx_rect_rgb
from tools.pc_render_trace import Collector, INVALID_DRIVER_HIGH


def original_ega_bitmap(ram, ds, descriptor):
    at = ds + descriptor
    if at < 0 or at + 10 > len(ram): raise ValueError('bitmap descriptor outside RAM')
    segment, offset, mask, width, height, flags = struct.unpack_from('<HHHBBH', ram, at)
    if not width or width % 8 or not height:
        raise ValueError('unsupported loaded EGA bitmap dimensions')
    stride = width // 8
    plane_size = stride * height
    start = segment * 16 + offset
    mask_start = segment * 16 + mask
    if mask_start != start + plane_size * 4 or mask_start + plane_size > len(ram):
        raise ValueError('unsupported loaded EGA bitmap layout')
    pixels, opaque = [], []
    for y in range(height):
        for x in range(width):
            byte, bit = y * stride + x // 8, 128 >> (x & 7)
            pixels.append(sum((1 << plane) if ram[start + plane * plane_size + byte] & bit else 0
                              for plane in range(4)))
            opaque.append(not bool(ram[mask_start + byte] & bit))
    return {'width': width, 'height': height, 'pixels': pixels, 'opaque': opaque, 'flags': flags}

def original_driver_mask(raw, ui):
    low, high, mask = raw[0::3], raw[1::3], raw[2::3]
    if not Collector.binary_mask(mask) or high.translate(INVALID_DRIVER_HIGH).count(1):
        return False
    if Collector.outside_ui(mask, ui):
        return False
    offsets = int.from_bytes(low, 'little') | int.from_bytes(high, 'little')
    return not (offsets & ~int.from_bytes(mask, 'little'))


class PerformanceExactnessTests(unittest.TestCase):
    def reader(self):
        reader = SimStateReader.__new__(SimStateReader)
        reader.anchors = [(0, b'first-anchor'), (32, b'second-anchor'), (64, b'third-anchor')]
        reader._located_ram = reader._located_base = None
        return reader

    def snapshot(self, reader, bases=(4096,)):
        ram = bytearray(655360)
        for base in bases:
            for offset, anchor in reader.anchors:
                ram[base+offset:base+offset+len(anchor)] = anchor
        return bytes(ram)

    def test_only_same_exact_immutable_object_reuses_scan(self):
        reader = self.reader(); ram = self.snapshot(reader)
        with patch.object(reader, '_locate_snapshot', wraps=reader._locate_snapshot) as scan:
            self.assertEqual(reader.locate(ram), 4096)
            self.assertEqual(reader.locate(ram), 4096)
            self.assertEqual(scan.call_count, 1)
            equal_copy = bytes(bytearray(ram))
            self.assertIsNot(equal_copy, ram)
            self.assertEqual(reader.locate(equal_copy), 4096)
            self.assertEqual(scan.call_count, 2)

    def test_mutable_buffer_and_subclass_never_reuse(self):
        reader = self.reader(); raw = self.snapshot(reader)
        class CustomBytes(bytes): pass
        for ram in (bytearray(raw), CustomBytes(raw)):
            with patch.object(reader, '_locate_snapshot', wraps=reader._locate_snapshot) as scan:
                reader.locate(ram); reader.locate(ram)
                self.assertEqual(scan.call_count, 2)
        changed = bytearray(raw); reader.locate(changed); changed[4096] ^= 1
        self.assertIsNone(reader.locate(changed))

    def test_different_snapshot_rechecks_mutation_and_ambiguity(self):
        reader = self.reader(); raw = self.snapshot(reader)
        reader.locate(raw)
        altered = bytearray(raw); altered[4096+32] ^= 1
        self.assertIsNone(reader.locate(bytes(altered)))
        with self.assertRaisesRegex(ValueError, 'ambiguous'):
            reader.locate(self.snapshot(reader, (4096, 8192)))
        self.assertEqual(reader.locate(raw), 4096)
        with self.assertRaises(ValueError): reader.locate(raw[:-1])

    def test_empty_driver_exactness_for_every_ui_byte(self):
        raw = bytes(192000)
        for value in range(256):
            ui = bytes([value])*64000
            self.assertEqual(Collector.safe_driver_mask(raw, ui), original_driver_mask(raw, ui))
        with patch.object(Collector, 'outside_ui', side_effect=AssertionError('slow path')):
            self.assertTrue(Collector.safe_driver_mask(raw, bytes(64000)))

    def test_driver_mutations_and_dimensions_still_match_prior_predicate(self):
        randomizer = random.Random(20260928)
        for size in (0, 3, 191997, 192000, 192003):
            raw = bytearray(size)
            for iteration in range(30):
                if size: raw[randomizer.randrange(size)] = randomizer.randrange(256)
                ui = bytes([randomizer.choice((0, 1, 254, 255))])*((size+2)//3)
                self.assertEqual(Collector.safe_driver_mask(bytes(raw), ui), original_driver_mask(bytes(raw), ui))
        for channel in range(3):
            for value in range(1, 256):
                raw = bytearray(192000); raw[90000+channel] = value
                ui = bytes([255])*64000
                self.assertEqual(Collector.safe_driver_mask(bytes(raw), ui), original_driver_mask(bytes(raw), ui))


class TextRGBProofTests(unittest.TestCase):
    """Compare with the previous uncached observer, including every RGB byte."""
    @staticmethod
    def original_present(observer, candidates, raw, width, height, palette):
        if (width,height)!=(320,200) or not palette or len(palette)!=16: return []
        result=[]
        for item,pixels,ink in candidates:
            x,y,w,h=item['rect']
            rgb=indexed_rgb(pixels,palette)
            actual=bgrx_rect_rgb(raw,width,height,(x,y,w,h))
            if rgb!=actual:
                observer.counts['frame_mismatches'] += 1
                continue
            foreground=palette[item['foreground']]
            if not any(not bit and palette[pixel]!=foreground for bit,pixel in zip(ink,pixels)):
                observer.counts['no_contrast'] += 1
                continue
            backgrounds={tuple(palette[pixel]) for bit,pixel in zip(ink,pixels) if not bit}
            uniform=list(next(iter(backgrounds))) if len(backgrounds)==1 else None
            result.append(item | {'uniform_background_rgb':uniform, 'pixel_sha256':hashlib.sha256(actual).hexdigest(),
                'basis':'source glyphs and complete RGB rectangle match the presented original framebuffer'})
            observer.counts['presented_runs'] += 1
        return result

    def setUp(self):
        self.observer=TextRuns.__new__(TextRuns)
        self.observer.counts=Counter();self.observer.rgb_proofs=OrderedDict()
        self.oracle=SimpleNamespace(counts=Counter())
        self.palette=[[i*7,i*11,i*13] for i in range(16)]
        self.item={'rect':[19,11,8,6],'foreground':14,'text':'READY','draw_sequence':1,'kind':'instrument'}
        self.ink=bytes(i%3!=0 for i in range(48))
        self.pixels=bytes(14 if bit else 3 for bit in self.ink)

    def frame(self, pixels=None):
        pixels=self.pixels if pixels is None else pixels
        raw=bytearray(320*200*4);x,y,w,h=self.item['rect']
        for i,pixel in enumerate(pixels):
            at=((y+i//w)*320+x+i%w)*4
            raw[at:at+4]=bytes([*reversed(self.palette[pixel]),255])
        return bytes(raw)

    def compare(self, raw=None, pixels=None, ink=None, item=None, palette=None):
        candidates=[(self.item if item is None else item,self.pixels if pixels is None else pixels,self.ink if ink is None else ink)]
        raw=self.frame() if raw is None else raw;palette=self.palette if palette is None else palette
        expected=self.original_present(self.oracle,candidates,raw,320,200,palette)
        actual=self.observer.present(candidates,raw,320,200,palette)
        self.assertEqual(actual,expected);self.assertEqual(self.observer.counts,self.oracle.counts)
        self.assertLessEqual(len(self.observer.rgb_proofs),MAX_RGB_PROOFS)
        return actual

    def test_warm_proof_checks_every_current_pixel_and_channel(self):
        self.compare();raw=self.frame()
        for i in range(48):
            at=((11+i//8)*320+19+i%8)*4
            for channel in range(3):
                altered=bytearray(raw);altered[at+channel]^=1
                self.assertEqual(self.compare(bytes(altered)),[])
                self.compare(raw)
        altered=bytearray(raw);altered[((11*320+19)*4)+3]^=1
        self.assertTrue(self.compare(bytes(altered)))  # BGRX padding remains ignored.

    def test_palette_pixels_ink_and_foreground_are_exact_inputs(self):
        self.compare()
        for value in range(256):
            self.palette[3][0]=value
            self.compare(self.frame())
            self.compare(self.frame(),ink=bytes(48))
        for i in range(48):
            pixels=bytearray(self.pixels);pixels[i]=4
            self.compare(self.frame(pixels),pixels=pixels)
            pixels[i]=3
            self.compare(self.frame(pixels),pixels=pixels)
        self.item['foreground']=3
        self.compare(self.frame())
        self.palette=[[0,0,0] for _ in range(16)]
        self.assertEqual(self.compare(self.frame()),[])

    def test_current_semantics_fresh_public_lists_and_malformed_frames(self):
        result=self.compare();result[0]['uniform_background_rgb'][0]=255
        self.item.update(text='NEW EVENT',draw_sequence=999,source_pointer=123)
        result=self.compare();self.assertEqual(result[0]['text'],'NEW EVENT')
        self.assertEqual(result[0]['draw_sequence'],999)
        for dims in [(640,100),(0,0)]:
            self.assertEqual(self.observer.present([(self.item,self.pixels,self.ink)],self.frame(),*dims,self.palette),[])
        for raw in [self.frame()[:-1],self.frame()+b'0']:
            with self.assertRaises(ValueError):self.observer.present([(self.item,self.pixels,self.ink)],raw,320,200,self.palette)
        self.item['rect'][0]=319
        with self.assertRaises(ValueError):self.observer.present([(self.item,self.pixels,self.ink)],self.frame(),320,200,self.palette)

    def test_bounded_lru_and_warm_encoding_reuse(self):
        with patch('tools.pc_text_trace.indexed_rgb',wraps=indexed_rgb) as encode:
            self.compare();self.compare();self.assertEqual(encode.call_count,1)
            for i in range(MAX_RGB_PROOFS+1):
                self.palette[3][0]=i
                self.compare(self.frame())
            self.palette[3][0]=0
            before=encode.call_count;self.compare(self.frame())
            self.assertEqual(encode.call_count,before+1)  # Original proof was evicted.
        self.assertEqual(len(self.observer.rgb_proofs),MAX_RGB_PROOFS)


class PlanarBulkTests(unittest.TestCase):
    @staticmethod
    def fixture(width=8, height=1, flags=0, ds=0, descriptor=100):
        size=width//8*height
        ram=bytearray(640*1024)
        struct.pack_into('<HHHBBH',ram,ds+descriptor,4096,0,size*4,width,height,flags)
        return ram,65536,size

    def test_every_plane_and_opacity_byte_preserves_all_eight_pixels(self):
        for plane in range(5):
            for value in range(256):
                ram,start,size=self.fixture(flags=value)
                ram[start+plane*size]=value
                self.assertEqual(read_ega_bitmap(ram,0,100),original_ega_bitmap(ram,0,100))

    def test_random_rows_native_bounds_and_relocated_descriptors(self):
        rng=random.Random(20260930)
        for width,height in [(8,1),(16,7),(96,12),(168,7),(248,199)]:
            ram,start,size=self.fixture(width,height,65535,ds=160,descriptor=200)
            ram[start:start+size*5]=rng.randbytes(size*5)
            expected=original_ega_bitmap(ram,160,200)
            self.assertEqual(read_ega_bitmap(ram,160,200),expected)
            self.assertEqual(read_ega_bitmap(bytes(ram),160,200),expected)
            for index in [0,size//2,size*5-1]:
                ram[start+index]^=128
                self.assertEqual(read_ega_bitmap(ram,160,200),original_ega_bitmap(ram,160,200))

    def test_malformed_dimensions_layout_and_truncation_fail_equally(self):
        ram,start,size=self.fixture()
        cases=[(bytes(109),0,100),(bytes(ram),-200,100),(bytes(ram),0,len(ram))]
        for offset,value in [(106,0),(106,7),(107,0),(104,5)]:
            bad=bytearray(ram);bad[offset]=value;cases.append((bytes(bad),0,100))
        cases.append((bytes(ram[:start+size*5-1]),0,100))
        for raw,ds,descriptor in cases:
            with self.assertRaises(ValueError):original_ega_bitmap(raw,ds,descriptor)
            with self.assertRaises(ValueError):read_ega_bitmap(raw,ds,descriptor)


if __name__ == '__main__': unittest.main()
