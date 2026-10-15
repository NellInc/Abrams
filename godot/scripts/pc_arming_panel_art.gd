extends Control
## Scalable original PC clipboard, gated by its complete source art and text.
const CATALOG_SHA := "0189ac8eab74a8bfd9f1d267cebba18cba502df005faf4ae9c28408a5788fb03"
const GENESIS_SHA := "0382ce25fd1568643e762deac023c43944bcd5bbbd6af6f0efae34777146b8e7"
const CLIP_RECT := Rect2i(239,87,81,113)
const PANEL_RECT := Rect2(239,95,81,105)
const PAPER_RECT := Rect2(243,101,72,94)
const WHITE := Color(238.0/255,238.0/255,238.0/255)
const GREY := Color(98.0/255,101.0/255,98.0/255)
const FIELDS = [Rect2i(257,113,36,6),Rect2i(245,123,60,6),Rect2i(245,137,66,6),
	Rect2i(245,147,66,6),Rect2i(245,157,66,6),Rect2i(245,170,66,6),Rect2i(259,183,30,6)]
var catalog: Dictionary={}
var indices := PackedByteArray()
# Clip-local (81x113, row-major) proof layout, built once from CLIP.BMP's
# indices: the required plate tag of every checked pixel, the [start,end) runs
# whose tag is checked (all but the text fields and the bottom pixel) and the
# runs whose RGB is checked (indexed CLIP.BMP colours outside those cells).
var _tag_expected := PackedByteArray()
var _tag_runs := PackedInt32Array()
var _rgb_runs := PackedInt32Array()
var _rgb_palette: Array = []
var _rgb_expected := PackedByteArray()
var active := false
var backdrop: Texture2D
var preserved: Color

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(queue_redraw)
	clear()

func clear() -> void:
	active=false
	visible=false
	backdrop=null
	queue_redraw()

func load_sources(root_path: String) -> bool:
	clear();catalog.clear();indices.clear()
	var path := root_path.path_join("local-art/pc-arming-panel-v1/arming-panel.json")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=CATALOG_SHA: return false
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	path=root_path.path_join("GAME/CLIP.BMP")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=data.source_sha256: return false
	path=root_path.path_join("local-art/genesis/source/motor-pool-original.png")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=GENESIS_SHA: return false
	var source := Image.load_from_file(path)
	if source==null or source.get_size()!=Vector2i(320,200): return false
	if not source.get_pixel(208,112).is_equal_approx(WHITE) or not source.get_pixel(209,120).is_equal_approx(GREY) or not source.get_pixel(209,113).is_equal_approx(Color.BLACK): return false
	indices=Marshalls.base64_to_raw(data.indices_base64)
	if indices.size()!=9944: indices.clear(); return false
	_build_layout()
	catalog=data
	return true

func _build_layout() -> void:
	_tag_expected.resize(CLIP_RECT.size.x*CLIP_RECT.size.y)
	_tag_runs.clear();_rgb_runs.clear();_rgb_palette.clear();_rgb_expected.clear()
	for y in range(CLIP_RECT.position.y,CLIP_RECT.end.y):
		for x in range(CLIP_RECT.position.x,CLIP_RECT.end.x):
			var at := Vector2i(x,y)
			var local := (y-CLIP_RECT.position.y)*CLIP_RECT.size.x+x-CLIP_RECT.position.x
			var c := int(indices[(y-87)*88+x-239])
			_tag_expected[local]=8 if c==0 else 0
			if at==Vector2i(312,199) or FIELDS.any(func(box):return box.has_point(at)): continue
			_append_run(_tag_runs,local)
			if c!=0: _append_run(_rgb_runs,local)

static func _append_run(runs: PackedInt32Array, local: int) -> void:
	if not runs.is_empty() and runs[runs.size()-1]==local: runs[runs.size()-1]=local+1
	else: runs.append_array(PackedInt32Array([local,local+1]))

func _expected_rgb(palette: Array) -> PackedByteArray:
	if palette==_rgb_palette: return _rgb_expected
	var expected := PackedByteArray()
	expected.resize(CLIP_RECT.size.x*CLIP_RECT.size.y*3)
	for local in CLIP_RECT.size.x*CLIP_RECT.size.y:
		var c := int(indices[(local/CLIP_RECT.size.x)*88+local%CLIP_RECT.size.x])
		if c==0: continue
		for k in 3: expected[local*3+k]=int(palette[c][k])
	_rgb_palette=palette.duplicate(true)
	_rgb_expected=expected
	return expected

func set_frame(source: Image, ui: Image, tags: Image, runs: Array, palette: Array, background: Texture2D) -> bool:
	clear()
	if catalog.is_empty() or background==null or runs.size()!=7: return false
	var fields := FIELDS.duplicate()
	for run in runs:
		if not run is Dictionary or not run.get("rect") is Rect2: return false
		var box := Rect2i(run.rect)
		if Rect2(box)!=run.rect or run.get("kind")!="verified_motor_pool_menu" or box not in fields: return false
		fields.erase(box)
	if not fields.is_empty(): return false
	# All static pixels, including the transparent outside of the original
	# clip, must still be attributable. Text has its independent full-glyph
	# proof. The intermittently overwritten bottom pixel is copied unchanged.
	# The caller supplies L8 masks and the RGB8 source frame.
	if ui.get_format()!=Image.FORMAT_L8 or tags.get_format()!=Image.FORMAT_L8 or source.get_format()!=Image.FORMAT_RGB8: return false
	if ui.get_region(CLIP_RECT).get_data().count(255)!=CLIP_RECT.size.x*CLIP_RECT.size.y: return false
	# Transparent CLIP.BMP pixels must be ATBASE (tag 8; the parent proved
	# every ATBASE pixel's RGB); every indexed pixel must be untagged.
	var tag_bytes := tags.get_region(CLIP_RECT).get_data()
	for i in range(0,_tag_runs.size(),2):
		if tag_bytes.slice(_tag_runs[i],_tag_runs[i+1])!=_tag_expected.slice(_tag_runs[i],_tag_runs[i+1]): return false
	var rgb := source.get_region(CLIP_RECT).get_data()
	var expected := _expected_rgb(palette)
	for i in range(0,_rgb_runs.size(),2):
		if rgb.slice(_rgb_runs[i]*3,_rgb_runs[i+1]*3)!=expected.slice(_rgb_runs[i]*3,_rgb_runs[i+1]*3): return false
	preserved=source.get_pixel(312,199)
	backdrop=background
	active=true;visible=true
	queue_redraw()
	return true

func _draw() -> void:
	if not active or backdrop==null: return
	draw_set_transform(Vector2.ZERO,0,size/Vector2(320,200))
	# Clear only the completely verified sprite, including its old pixel edges.
	var ratio := Vector2(backdrop.get_size())/Vector2(320,200)
	draw_texture_rect_region(backdrop,Rect2(CLIP_RECT),Rect2(Vector2(CLIP_RECT.position)*ratio,Vector2(CLIP_RECT.size)*ratio))
	# CLIP.BMP's brown board, white sheet and silver spring clip. Keep the
	# source proportions and EGA colours; only the contours gain resolution.
	var board := StyleBoxFlat.new()
	board.bg_color=Color(170.0/255,85.0/255,0)
	board.border_color=Color.BLACK
	board.set_border_width_all(1)
	board.corner_radius_top_left=4;board.corner_radius_top_right=4
	board.corner_detail=12
	draw_style_box(board,PANEL_RECT)
	draw_rect(Rect2(PAPER_RECT.position+Vector2.ONE,PAPER_RECT.size),Color(170.0/255,170.0/255,170.0/255))
	draw_rect(PAPER_RECT,Color.WHITE)
	draw_set_transform(Vector2(239,87)*size/Vector2(320,200),0,size/Vector2(320,200))
	var silver := Color(170.0/255,170.0/255,170.0/255)
	var shadow := Color(85.0/255,85.0/255,85.0/255)
	# Lower jaw, bevel and the narrow upright handle, as in the source sprite.
	draw_colored_polygon(PackedVector2Array([Vector2(15,20),Vector2(61,20),Vector2(65,24),Vector2(15,24)]),silver)
	var jaw := PackedVector2Array([Vector2(16,19),Vector2(60,19),Vector2(64,22),Vector2(13,22),Vector2(16,19)])
	draw_colored_polygon(jaw,silver)
	draw_polyline(jaw,Color.BLACK,0.8,true)
	draw_polyline(PackedVector2Array([Vector2(14,21),Vector2(17,19.5),Vector2(60,19.5)]),Color.WHITE,0.8,true)
	draw_rect(Rect2(20,13,37,1),silver)
	draw_rect(Rect2(29,9,20,10),shadow)
	var handle := PackedVector2Array([Vector2(30,19),Vector2(30,7.5),Vector2(34,5.5),Vector2(35,2),Vector2(36.5,0.5),Vector2(40,0.5),Vector2(42,2),Vector2(43,5.5),Vector2(47,7.5),Vector2(47,19),Vector2(30,19)])
	# The handle's open eye reveals the donor scene through the same source hole.
	draw_colored_polygon(handle,silver)
	draw_polyline(handle,Color.BLACK,0.8,true)
	draw_polyline(PackedVector2Array([Vector2(31,18.5),Vector2(31,8),Vector2(35,6),Vector2(36,2),Vector2(40,1.5)]),Color.WHITE,1.0,true)
	draw_line(Vector2(38,8),Vector2(38,15),Color.WHITE,0.6,true)
	draw_line(Vector2(46,8),Vector2(46,18.5),Color.WHITE,0.6,true)
	var eye := Rect2(37,3,3,3)
	draw_texture_rect_region(backdrop,eye,Rect2((Vector2(239,87)+eye.position)*ratio,eye.size*ratio))
	draw_arc(Vector2(38.5,4.5),2.0,0,TAU,24,Color.BLACK,0.8,true)
	draw_set_transform(Vector2.ZERO,0,size/Vector2(320,200))
	draw_rect(Rect2(312,199,1,1),preserved)
