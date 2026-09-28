extends Control
## Registered Genesis-style metalwork. Live PC windows remain untouched.
## Hardware is drawn in output pixels so the 4:3 correction cannot oval screws.
const CAMERA = Rect2i(32,13,256,97)
const CORNER_RUNS = [7,5,3,2,2,1,1]
const SCREWS = [Vector2(91,129),Vector2(224,131),Vector2(6,177),
	Vector2(98,177),Vector2(6,197),Vector2(98,197),Vector2(221,196),Vector2(314,196)]
var active := false
var corners_verified := false
var scale_xy := Vector2.ONE

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://scripts/pc_gunner_trim.gdshader")
	material = shader
	resized.connect(_layout)
	clear()

func _layout() -> void:
	scale_xy = size/Vector2(320,200)
	material.set_shader_parameter("frame_size",size)
	queue_redraw()

func clear() -> void:
	active = false
	corners_verified = false
	material.set_shader_parameter("corners_verified",false)
	hide()

static func corner_pixels() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in 7:
		for x in CORNER_RUNS[y]:
			for p in [Vector2i(32+x,13+y),Vector2i(287-x,13+y),Vector2i(32+x,109-y),Vector2i(287-x,109-y)]: result.append(p)
	return result

func set_frame(source: Image, ui: Image, tags: Image, camera: Rect2i, world: Texture2D = null) -> void:
	clear()
	if camera!=CAMERA or world==null: return
	for im in [source,ui,tags]:
		if im==null or im.get_size()!=Vector2i(320,200): return
	corners_verified = true
	for p in corner_pixels():
		if ui.get_pixelv(p).r!=1.0 or tags.get_pixelv(p).r!=0.0 or source.get_pixelv(p).to_rgba32()!=Color8(85,85,85).to_rgba32():
			corners_verified = false
			break
	material.set_shader_parameter("ui_mask",ImageTexture.create_from_image(ui))
	material.set_shader_parameter("plate_mask",ImageTexture.create_from_image(tags))
	material.set_shader_parameter("world_texture",world)
	material.set_shader_parameter("corners_verified",corners_verified)
	active = true
	_layout()
	show()

func _rect(box: Rect2, color: Color) -> void:
	draw_rect(Rect2(box.position*scale_xy,box.size*scale_xy),color)

func _poly(points: Array, color: Color) -> void:
	var vertices := PackedVector2Array()
	for p: Vector2 in points: vertices.append(p*scale_xy)
	draw_colored_polygon(vertices,color)

func _panel(box: Rect2) -> void:
	_rect(box,Color("3c4248"))
	_rect(box.grow(-0.6),Color("d9dad8"))
	var r := box.grow(-1.2)
	var points := PackedVector2Array([r.position*scale_xy,Vector2(r.end.x,r.position.y)*scale_xy,r.end*scale_xy,Vector2(r.position.x,r.end.y)*scale_xy])
	draw_polygon(points,PackedColorArray([Color("bfc0c0"),Color("afb0b2"),Color("9c9fa3"),Color("b1b3b5")]))

func _rounded(box: Rect2, color: Color, radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(roundi(radius*minf(scale_xy.x,scale_xy.y)))
	style.corner_detail = 16
	style.anti_aliasing = true
	draw_style_box(style,Rect2(box.position*scale_xy,box.size*scale_xy))

func screw_center(p: Vector2) -> Vector2: return p*scale_xy
func screw_radius() -> float: return 2.65*minf(scale_xy.x,scale_xy.y)

func _screw(p: Vector2) -> void:
	var c := screw_center(p)
	var r := screw_radius()
	draw_circle(c,r,Color("303438"),true,-1,true)
	draw_circle(c,r*0.84,Color("dedfdd"),true,-1,true)
	draw_circle(c,r*0.70,Color("8e9192"),true,-1,true)
	var w := r*0.28
	draw_line(c-Vector2(r*0.51,0),c+Vector2(r*0.51,0),Color("1b1e20"),w,true)
	draw_line(c-Vector2(0,r*0.51),c+Vector2(0,r*0.51),Color("1b1e20"),w,true)

func _draw() -> void:
	if not active: return
	# Enclose the old donor's rim; the shader clips all visible world pixels.
	# The dark inner lip absorbs the PC's coarse grey corner steps.
	_rounded(Rect2(29.5,11.0,261,101.8),Color("0c101a"),8)
	_rounded(Rect2(30.2,11.7,259.6,100.4),Color("ff1025"),7.3)
	_rounded(Rect2(32,13,256,97),Color("12141b"),7)
	# Three straight machined panels replace the rubber-sheeted donor margins.
	# The outline follows the existing outer metal diagonals at row 123.
	_poly([Vector2(24,123),Vector2(296,123),Vector2(320,148),Vector2(320,200),Vector2(0,200),Vector2(0,148)],Color("a7a8aa"))
	_rect(Rect2(25,123,270,0.7),Color("e0e0de"))
	_rect(Rect2(0,199,320,1),Color("62666c"))
	_panel(Rect2(0,123,103,15))
	_panel(Rect2(0,138,103,36.5))
	_panel(Rect2(0,174.5,103,25.5))
	_panel(Rect2(104,123,112,77))
	_panel(Rect2(217,123,103,77))
	for x in [102.5,215.5]:
		_rect(Rect2(x,123,1.3,77),Color("22272c"))
		_rect(Rect2(x+1.3,123,0.5,76),Color("e1e1df"))
	# The source-owned blue/green display frames remain in their original cells.
	for box in [Rect2(10,138,85,37),Rect2(10,175,85,20),Rect2(223,138,43,56),Rect2(268,138,43,56)]:
		_rect(box,Color("343a42"))
	_poly([Vector2(108,127),Vector2(211,127),Vector2(194,136),Vector2(125,136)],Color("272c30"))
	_poly([Vector2(108,127),Vector2(125,136),Vector2(125,183),Vector2(108,186)],Color("7e8286"))
	_poly([Vector2(211,127),Vector2(194,136),Vector2(194,183),Vector2(211,186)],Color("666c72"))
	_poly([Vector2(108,186),Vector2(125,183),Vector2(194,183),Vector2(211,186)],Color("d0d1d0"))
	_rect(Rect2(125,135,69,49),Color("121819"))
	_rect(Rect2(123,183.5,72,14.5),Color("30363a"))
	# Repaint only the two-pixel static rims. The shader protects every interior
	# and rejects any rim pixel that no longer belongs to the original plate.
	for box in [Rect2(11,139,83,35),Rect2(224,139,41,54),Rect2(269,139,41,54)]:
		_rect(box,Color8(85,85,255))
	for box in [Rect2(11,176,83,18),Rect2(126,136,67,47),Rect2(124,184,70,13)]:
		_rect(box,Color8(0,170,0))
	for p in SCREWS: _screw(p)
