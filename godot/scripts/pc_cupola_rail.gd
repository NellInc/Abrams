extends RefCounted
## The PC redraws this fixed AA rail without plate tags. Exact source, station,
## position and UI proof permit only these pixels; one mismatch rejects it all.
# Decoded RGB8 pixels of the player's AA.BIN plate, independent of PNG encoder.
const SOURCE_SHA256 = "93d32ce6fa8b0515fbf27525093ec43bf3c9b9e61c4974f2c3bc70ba3c316d2f"
const CAMERA = Rect2i(0,0,320,117)
const ROW_END = [183,206,230,242,264,286]
const InstrumentArt = preload("res://scripts/pc_instrument_art.gd")
var expected: Image
static var _cached_pixels: Array[Vector2i] = []

func load_source(root_path: String) -> bool:
	expected = InstrumentArt.load_plate(root_path.path_join("local-art/pc-ui-v2/aa-bin.png"),SOURCE_SHA256)
	return expected!=null

static func pixels() -> Array[Vector2i]:
	if _cached_pixels.is_empty():
		for row in ROW_END.size():
			for x in range(159,ROW_END[row]): _cached_pixels.append(Vector2i(x,111+row))
	return _cached_pixels

func verify(source: Image, ui: Image, tags: Image, camera: Rect2i, cupola_active: bool) -> bool:
	if not cupola_active or camera!=CAMERA or expected==null: return false
	for im in [source,ui,tags]:
		if im==null or im.get_size()!=Vector2i(320,200): return false
	if ui.get_format()==Image.FORMAT_L8 and tags.get_format()==Image.FORMAT_L8 and source.get_format()==Image.FORMAT_RGB8 and expected.get_format()==Image.FORMAT_RGB8:
		for row in ROW_END.size():
			var w: int = ROW_END[row] - 159
			var strip := Rect2i(159, 111 + row, w, 1)
			if ui.get_region(strip).get_data().count(255) != w or tags.get_region(strip).get_data().count(0) != w: return false
			if source.get_region(strip).get_data() != expected.get_region(strip).get_data(): return false
		var ctx := Rect2i(159, 117, 127, 1)
		if ui.get_region(ctx).get_data().count(255) != 127 or tags.get_region(ctx).get_data().count(3) != 127: return false
		return source.get_region(ctx).get_data() == expected.get_region(ctx).get_data()
	for p in pixels():
		if ui.get_pixelv(p).r!=1.0 or tags.get_pixelv(p).r!=0.0 or source.get_pixelv(p).to_rgba32()!=expected.get_pixelv(p).to_rgba32(): return false
	# Adjacent intact plate context prevents an isolated source-colour coincidence.
	for x in range(159,286):
		var p := Vector2i(x,117)
		if ui.get_pixelv(p).r!=1.0 or roundi(tags.get_pixelv(p).r*255)!=3 or source.get_pixelv(p).to_rgba32()!=expected.get_pixelv(p).to_rgba32(): return false
	return true
