extends RefCounted
## The PC redraws this fixed AA rail without plate tags. Exact source, station,
## position and UI proof permit only these pixels; one mismatch rejects it all.
const SOURCE_SHA256 = "64da0346689f54dd19be2d8dbcab4be1ef39cca8b53b57faae435f84180c1108"
const CAMERA = Rect2i(0,0,320,117)
const ROW_END = [183,206,230,242,264,286]
var expected: Image

func load_source(root_path: String) -> bool:
	var path := root_path.path_join("local-art/pc-ui-v2/aa-bin.png")
	if FileAccess.get_sha256(path)!=SOURCE_SHA256: return false
	expected = Image.load_from_file(path)
	return expected!=null and expected.get_size()==Vector2i(320,200)

static func pixels() -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for row in ROW_END.size():
		for x in range(159,ROW_END[row]): points.append(Vector2i(x,111+row))
	return points

func verify(source: Image, ui: Image, tags: Image, camera: Rect2i, cupola_active: bool) -> bool:
	if not cupola_active or camera!=CAMERA or expected==null: return false
	for im in [source,ui,tags]:
		if im==null or im.get_size()!=Vector2i(320,200): return false
	for p in pixels():
		if ui.get_pixelv(p).r!=1.0 or tags.get_pixelv(p).r!=0.0 or source.get_pixelv(p).to_rgba32()!=expected.get_pixelv(p).to_rgba32(): return false
	# Adjacent intact plate context prevents an isolated source-colour coincidence.
	for x in range(159,286):
		var p := Vector2i(x,117)
		if ui.get_pixelv(p).r!=1.0 or roundi(tags.get_pixelv(p).r*255)!=3 or source.get_pixelv(p).to_rgba32()!=expected.get_pixelv(p).to_rgba32(): return false
	return true
