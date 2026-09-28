import hashlib,json,unittest
from tools.build_pc_map_frame_catalog import ROOT,build,border_bytes
from PIL import Image
class MapFrameTests(unittest.TestCase):
 def test_catalog_is_source_reproducible_with_complete_rivet_domain(self):
  actual=build();saved=json.loads((ROOT/'local-art/pc-map-frame-v1/frame.json').read_text())
  self.assertEqual(actual,saved);self.assertEqual(len(actual['rivets']),12)
  self.assertEqual(len(actual['donor']['matched_motif_rects']),10)
  self.assertEqual({r['quarter_turns'] for r in actual['rivets']},{0,1,2,3})
 def test_real_original_mission_summary_matches_surround_and_keeps_content_independent(self):
  path=ROOT/'artifacts/pc-motor-pool-baseline-01/mission-summary.png'
  image=Image.open(path).convert('RGB');catalog=json.loads((ROOT/'local-art/pc-map-frame-v1/frame.json').read_text())
  expected=catalog['border_rgb_sha256']
  self.assertEqual(hashlib.sha256(border_bytes(image)).hexdigest(),expected)
  image.putpixel((50,50),(255,255,255))
  self.assertEqual(hashlib.sha256(border_bytes(image)).hexdigest(),expected)
  image.putpixel((5,5),(255,255,255))
  self.assertNotEqual(hashlib.sha256(border_bytes(image)).hexdigest(),expected)
