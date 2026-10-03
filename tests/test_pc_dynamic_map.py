import copy,json,re,struct,subprocess,sys,tempfile,unittest
from pathlib import Path
from tools.pc_dynamic_map import MapRuns,RECT
from tools.pc_pixel_bytes import indexed_rgb

class DynamicMapTests(unittest.TestCase):
 def fixture(self,mode=0,page=0):
  observer=MapRuns();pixels=bytearray([2])*(144*96)
  def line(caller,x1,y,x2,color):
   observer.line(struct.pack('<H4hBBHBB',caller,x1,y,x2,y,color,mode,page,1,mode))
   pixels[(y-63)*144+x1-16:(y-63)*144+x2-15]=bytes([color])*(x2-x1+1)
  def finish(caller):observer.finish(struct.pack('<5H',*RECT,page)+pixels,caller)
  if mode==0:
   observer.begin(struct.pack('<H4B',page,2,1,0,16))
   line(0x1011,16,63,18,4);line(0x102c,16,64,18,4);finish(0x1052)
   line(0x1197,80,90,80,5);finish(0x11ae)
  else:
   line(0x1263,87,110,88,1);line(0x1279,87,111,88,1);finish(0x1285)
  palette=[[i*16,i*8,i*4] for i in range(16)];rgb=indexed_rgb(pixels,palette);raw=bytearray(320*200*4)
  for y in range(96):
   for x in range(144):
    i=(y*144+x)*3;a=((y+63)*320+x+16)*4;raw[a:a+3]=rgb[i:i+3][::-1]
  return observer,bytes(raw),palette
 def test_both_modes_both_pages_and_whole_map_occlusion(self):
  for mode in (0,1):
   for page in (0,8192):
    o,raw,p=self.fixture(mode,page);candidate=o.scanout(page)
    self.assertEqual(o.present(candidate,raw,320,200,p)['mode'],mode)
    self.assertIsNone(o.scanout(8192-page))
    changed=bytearray(raw);changed[(100*320+100)*4]^=1
    self.assertEqual(o.present(candidate,changed,320,200,p),{})
 def test_mid_draw_attach_falls_back(self):
  o=MapRuns();o.line(struct.pack('<H4hBBHBB',0x1011,16,63,18,63,1,0,0,1,0));o.finish(struct.pack('<5H',*RECT,0)+bytes([1])*13824,0x1052)
  self.assertIsNone(o.scanout(0));self.assertEqual(o.counts['unobserved_entry'],2)
 def test_wrong_station_rejects(self):
  o=MapRuns();o.begin(struct.pack('<H4B',0,2,0,0,16));o.finish(struct.pack('<5H',*RECT,0)+bytes([2])*13824,0x1052)
  self.assertEqual(o.terrain,{})
 def test_new_refresh_invalidates(self):
  o,_,_=self.fixture();self.assertIsNotNone(o.scanout(0));o.begin(struct.pack('<H4B',0,2,1,0,16));self.assertIsNone(o.scanout(0))
 def local(self,*markers):
  o=MapRuns()
  for caller,x1,y1,x2,y2 in markers:o.line(struct.pack('<H4hBBHBB',caller,x1,y1,x2,y2,1,1,0,1,1))
  o.finish(struct.pack('<5H',*RECT,0)+bytes([1])*13824,0x1285);return o.scanout(0)
 def test_incomplete_local_marker_rejected(self):
  self.assertIsNone(self.local((0x1263,87,110,88,110)))
 def test_wrong_local_marker_coordinate_rejected(self):
  # Each fault is isolated on an otherwise complete pair; the correct pair is the control.
  self.assertIsNotNone(self.local((0x1263,87,110,88,110),(0x1279,87,111,88,111)))
  self.assertIsNone(self.local((0x1263,86,110,88,110),(0x1279,87,111,88,111)))
  self.assertIsNone(self.local((0x1263,87,110,88,110),(0x1279,87,110,88,110)))
 def test_map_begin_colour_comes_from_clear_colour_byte(self):
  # MapRuns.begin reads byte 2 as the clear colour. Its last write at 0x0f73 must be DS:777A;
  # the earlier DS:359E store is dead and is the one to drop at the next pinned core rebuild.
  header=(Path(__file__).resolve().parents[1]/'tools/pc_core/abrams_trace.h').read_text()
  block=header[header.index('if (ip == 0x0f73) {'):header.index('abrams_trace_callback(43,')]
  self.assertEqual(re.findall(r'abrams_trace_snapshot\[2\]=mem_readb\(base\+(0x[0-9a-f]+)\);',block)[-1],'0x777a')
 def test_trace_baseline_compare_fails_on_any_divergence(self):
  root=Path(__file__).resolve().parents[1];script=root/'tools/verify_pc_dynamic_map.py'
  steps=[('start',20),('commander-key',3),('commander',90),('map-toggle-key',3),('map-toggle',90),('map-return-key',3),('map-return',90),('driver-key',3),('driver',60),('commander-return-key',3),('commander-return',90)]
  frames=[[[],'%064x'%i,'%064x'%(i+1)] for i in range(sum(n for _,n in steps))];stages={k:{'station':1} for k,_ in steps}
  base={'mode':'baseline','core_sha256':'b'*64,'trace_header_sha256':'h'*64,'frames':frames,'stages':stages,'packets':[],'observer':{}}
  trace=dict(copy.deepcopy(base),mode='trace',core_sha256='t'*64,packets=[{'mode':0},{'mode':1}],observer={'presented':3,'frame_mismatch':1})
  with tempfile.TemporaryDirectory() as d:
   d=Path(d);(d/'m.json').write_text(json.dumps({'trace_sha256':'t'*64,'baseline_sha256':'b'*64,'trace_header_sha256':'h'*64}))
   def compare(t,b=base):
    (d/'t.json').write_text(json.dumps(t));(d/'b.json').write_text(json.dumps(b))
    return subprocess.run([sys.executable,str(script),'--compare',str(d/'t.json'),str(d/'b.json'),'--manifest',str(d/'m.json')],capture_output=True,text=True).returncode
   self.assertEqual(compare(trace),0)
   ram=copy.deepcopy(trace);ram['frames'][10][1]='f'*64;self.assertEqual(compare(ram),1)
   stage=copy.deepcopy(trace);stage['stages']['driver']={'station':2};self.assertEqual(compare(stage),1)
   self.assertEqual(compare(dict(trace,core_sha256='x'*64)),1)
   self.assertEqual(compare(dict(trace,packets=[{'mode':0}])),1)
if __name__=='__main__':unittest.main()
