extends Control
## Only the complete source-owned mission-title surround is replaced.
const GUARDS = [[56, 76, 208, 9], [56, 115, 208, 9], [56, 85, 9, 30], [255, 85, 9, 30]]
const BORDER_SHA = "f405f18570187101d0a7072f30ac249edc202a24e85df3336459ad343a93a9c5"
var active := false
func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	clear()
func clear() -> void:
	active=false;hide();queue_redraw()
func set_frame(source: Image,program: Dictionary) -> bool:
	clear()
	if program.get("name")!="BRIEF" or source==null or source.get_size()!=Vector2i(320,200) or source.get_format()!=Image.FORMAT_RGB8: return false
	var hash:=HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for r in GUARDS: hash.update(source.get_region(Rect2i(r[0],r[1],r[2],r[3])).get_data())
	if hash.finish().hex_encode()!=BORDER_SHA: return false
	active=true;show();queue_redraw();return true
func title_mask(source: Image, ui: Image, runs: Array) -> Image:
	if not active: return ui
	var panel:=Rect2i(65,85,190,30)
	var blue:=Color8(85,85,255)
	# The text observer marks glyph cells only. The complete matched chrome
	# plus every interior texel proves the remaining uniformly blue cells;
	# no unobserved mark or world pixel is admitted as a word space.
	for y in range(panel.position.y,panel.end.y):
		for x in range(panel.position.x,panel.end.x):
			if source.get_pixel(x,y)==blue:continue
			var known:=false
			for run in runs:
				if run.kind=="frontend" and run.background==blue and run.rect.has_point(Vector2(x,y)):known=true;break
			if not known:return ui
	var proof:=ui.duplicate()
	proof.fill_rect(panel,Color.WHITE)
	return proof
func _draw() -> void:
	if not active: return
	var scale:=size/Vector2(320,200)
	for r in GUARDS: draw_rect(Rect2(Vector2(r[0],r[1])*scale,Vector2(r[2],r[3])*scale),Color8(170,170,170))
	for r in [Rect2(56,76,208,0.9),Rect2(56,76,0.9,48),Rect2(263,77,0.7,46)]: draw_rect(Rect2(r.position*scale,r.size*scale),Color8(240,240,240))
	for r in [Rect2(56,123,208,1),Rect2(56,76,1,48),Rect2(64,84,192,0.8),Rect2(64,84,0.8,32),Rect2(255,84,0.8,32),Rect2(64,115,192,0.8)]: draw_rect(Rect2(r.position*scale,r.size*scale),Color8(75,75,75))
	for c in [Vector2(60,81),Vector2(160,80),Vector2(260,81),Vector2(60,118),Vector2(160,119),Vector2(260,118)]:
		var ring:=PackedVector2Array()
		for i in 40: ring.append((c+Vector2.from_angle(TAU*i/40.0)*1.45)*scale)
		draw_colored_polygon(ring,Color8(74,74,74))
		draw_line((c-Vector2(0.9,0))*scale,(c+Vector2(0.9,0))*scale,Color.WHITE,maxf(1.0,scale.y*0.45),true)
		draw_line((c-Vector2(0,0.9))*scale,(c+Vector2(0,0.9))*scale,Color.BLACK,maxf(1.0,scale.x*0.45),true)
