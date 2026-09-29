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
	catalog=data
	return true

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
	for y in range(CLIP_RECT.position.y,CLIP_RECT.end.y):
		for x in range(CLIP_RECT.position.x,CLIP_RECT.end.x):
			var at := Vector2i(x,y)
			if ui.get_pixelv(at).r!=1.0: return false
			if at==Vector2i(312,199): continue
			if FIELDS.any(func(box):return box.has_point(at)): continue
			var c := int(indices[(y-87)*88+x-239])
			var tag := roundi(tags.get_pixelv(at).r*255)
			if c==0:
				if tag!=8: return false # Parent proved every ATBASE pixel's RGB.
			else:
				if tag!=0: return false
				var expected := Color(palette[c][0]/255.0,palette[c][1]/255.0,palette[c][2]/255.0)
				if not source.get_pixelv(at).is_equal_approx(expected): return false
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
