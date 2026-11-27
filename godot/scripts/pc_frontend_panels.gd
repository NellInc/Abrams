extends Control
## Only the complete source-owned mission-title surround is replaced.
const GUARDS = [[56, 76, 208, 9], [56, 115, 208, 9], [56, 85, 9, 30], [255, 85, 9, 30]]
const BORDER_SHA = "f405f18570187101d0a7072f30ac249edc202a24e85df3336459ad343a93a9c5"
var active := false
var _last_guard_bytes := PackedByteArray()
var _last_guard_ok := false
static var _blue_panel_bytes := PackedByteArray()
static var _screw_circle_40 := PackedVector2Array()
func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	clear()
func clear() -> void:
	active=false;hide();queue_redraw()
func set_frame(source: Image,program: Dictionary) -> bool:
	clear()
	if program.get("name")!="BRIEF" or source==null or source.get_size()!=Vector2i(320,200) or source.get_format()!=Image.FORMAT_RGB8: return false
	var combined:=PackedByteArray()
	for r in GUARDS: combined.append_array(source.get_region(Rect2i(r[0],r[1],r[2],r[3])).get_data())
	if combined==_last_guard_bytes:
		if not _last_guard_ok: return false
	else:
		var hash:=HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(combined)
		_last_guard_bytes=combined
		_last_guard_ok=hash.finish().hex_encode()==BORDER_SHA
		if not _last_guard_ok: return false
	active=true;show();queue_redraw();return true
func title_mask(source: Image, ui: Image, runs: Array) -> Image:
	if not active: return ui
	var panel:=Rect2i(65,85,190,30)
	var blue:=Color8(85,85,255)
	var blue_runs: Array = runs.filter(func(r): return r.kind=="frontend" and r.background==blue)
	# The text observer marks glyph cells only. The complete matched chrome
	# plus every interior texel proves the remaining uniformly blue cells;
	# no unobserved mark or world pixel is admitted as a word space.
	var integer_rects := source.get_format()==Image.FORMAT_RGB8
	for run in blue_runs:
		if Rect2(Rect2i(run.rect))!=run.rect:
			integer_rects=false
			break
	if integer_rects:
		if _blue_panel_bytes.is_empty():
			var solid:=Image.create_empty(panel.size.x,panel.size.y,false,Image.FORMAT_RGB8)
			solid.fill(blue)
			_blue_panel_bytes=solid.get_data()
		var crop:=source.get_region(panel)
		for run in blue_runs:
			var clipped:=Rect2i(run.rect).intersection(panel)
			if clipped.has_area():
				crop.fill_rect(Rect2i(clipped.position-panel.position,clipped.size),blue)
		if crop.get_data()!=_blue_panel_bytes: return ui
	else:
		for y in range(panel.position.y,panel.end.y):
			for x in range(panel.position.x,panel.end.x):
				if source.get_pixel(x,y)==blue:continue
				var known:=false
				for run in blue_runs:
					if run.rect.has_point(Vector2(x,y)):known=true;break
				if not known:return ui
	var proof:=ui.duplicate()
	proof.fill_rect(panel,Color.WHITE)
	return proof
func _draw() -> void:
	if not active: return
	if _screw_circle_40.is_empty():
		for i in 40: _screw_circle_40.append(Vector2.from_angle(TAU*i/40.0)*1.45)
	var scale:=size/Vector2(320,200)
	for r in GUARDS: draw_rect(Rect2(Vector2(r[0],r[1])*scale,Vector2(r[2],r[3])*scale),Color8(170,170,170))
	for r in [Rect2(56,76,208,0.9),Rect2(56,76,0.9,48),Rect2(263,77,0.7,46)]: draw_rect(Rect2(r.position*scale,r.size*scale),Color8(240,240,240))
	for r in [Rect2(56,123,208,1),Rect2(56,76,1,48),Rect2(64,84,192,0.8),Rect2(64,84,0.8,32),Rect2(255,84,0.8,32),Rect2(64,115,192,0.8)]: draw_rect(Rect2(r.position*scale,r.size*scale),Color8(75,75,75))
	for c in [Vector2(60,81),Vector2(160,80),Vector2(260,81),Vector2(60,118),Vector2(160,119),Vector2(260,118)]:
		var ring:=PackedVector2Array()
		for v in _screw_circle_40: ring.append((c+v)*scale)
		draw_colored_polygon(ring,Color8(74,74,74))
		draw_line((c-Vector2(0.9,0))*scale,(c+Vector2(0.9,0))*scale,Color.WHITE,maxf(1.0,scale.y*0.45),true)
		draw_line((c-Vector2(0,0.9))*scale,(c+Vector2(0,0.9))*scale,Color.BLACK,maxf(1.0,scale.x*0.45),true)
