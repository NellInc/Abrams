extends Control
## Static registered commander metalwork. No live display is repainted.
## Call only after the compositor has validated the source/plate provenance.
const CAMERA = Rect2i(0,10,320,43)
const PROTECTED = [Rect2i(15,62,146,98),Rect2i(14,176,80,18),
	Rect2i(101,176,62,18),Rect2i(214,81,66,49),Rect2i(212,131,70,12),
	Rect2i(207,148,82,39)]
const SCREWS = [Vector2(190,66),Vector2(305,66),Vector2(196,149),
	Vector2(297,149),Vector2(196,187),Vector2(297,187)]
var active := false
var scale_xy := Vector2.ONE
var _verified_ui := PackedByteArray()
var _verified_tags := PackedByteArray()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://scripts/pc_commander_trim.gdshader")
	material = shader
	resized.connect(_layout)
	clear()

func clear() -> void:
	active = false
	hide()

func _layout() -> void:
	scale_xy = size/Vector2(320,200)
	material.set_shader_parameter("frame_size",size)
	queue_redraw()

func set_frame(source: Image, ui: Image, tags: Image, camera: Rect2i, world: Texture2D = null) -> void:
	clear()
	if camera!=CAMERA or world==null: return
	for im in [source,ui,tags]:
		if im==null or im.get_size()!=Vector2i(320,200): return
	if ui.get_format()!=Image.FORMAT_L8 or tags.get_format()!=Image.FORMAT_L8: return
	var bits := tags.get_data()
	var owners := ui.get_data()
	if bits!=_verified_tags or owners!=_verified_ui:
		# A mixed station transition cannot inherit an earlier settled housing.
		if bits.count(0)+bits.count(2)!=bits.size(): return
		for y in 200:
			var lo := y*320
			var hi := lo+320
			var row := bits.slice(lo,hi)
			var owned := owners.slice(lo,hi)
			if row==_verified_tags.slice(lo,hi) and owned==_verified_ui.slice(lo,hi): continue
			if row.count(0)==320 or owned.count(255)==320: continue
			for x in 320:
				if row[x]!=0 and owned[x]!=255: return
		# Demand the complete outer housing anchors, not an isolated plate pixel.
		for p in [Vector2i(187,63),Vector2i(307,63),Vector2i(187,192),Vector2i(307,192)]:
			if bits[p.y*320+p.x]!=2: return
		_verified_tags = bits
		_verified_ui = owners
	material.set_shader_parameter("ui_mask",ImageTexture.create_from_image(ui))
	material.set_shader_parameter("plate_mask",ImageTexture.create_from_image(tags))
	active = true
	_layout()
	show()

func _rect(box: Rect2, color: Color) -> void:
	draw_rect(Rect2(box.position*scale_xy,box.size*scale_xy),color)

func _poly(points: Array, color: Color) -> void:
	var vertices := PackedVector2Array()
	for p: Vector2 in points: vertices.append(p*scale_xy)
	draw_colored_polygon(vertices,color)
	vertices.append(vertices[0])
	draw_polyline(vertices,color,1.0,true)

func _panel(box: Rect2) -> void:
	_rect(box,Color("30363a"))
	_rect(box.grow(-0.5),Color("dedfdd"))
	var r := box.grow(-1.2)
	draw_polygon(PackedVector2Array([r.position*scale_xy,Vector2(r.end.x,r.position.y)*scale_xy,r.end*scale_xy,Vector2(r.position.x,r.end.y)*scale_xy]),
		PackedColorArray([Color("bfc0c0"),Color("afb0b2"),Color("9c9fa3"),Color("b1b3b5")]))

func screw_center(p: Vector2) -> Vector2: return p*scale_xy
func screw_radius() -> float: return 2.65*minf(scale_xy.x,scale_xy.y)

func _screw(p: Vector2) -> void:
	var c := screw_center(p)
	var r := screw_radius()
	draw_circle(c,r,Color("303438"),true,-1,true)
	draw_circle(c,r*0.84,Color("dedfdd"),true,-1,true)
	draw_circle(c,r*0.70,Color("8e9192"),true,-1,true)
	draw_line(c-Vector2(r*0.51,0),c+Vector2(r*0.51,0),Color("1b1e20"),r*0.28,true)
	draw_line(c-Vector2(0,r*0.51),c+Vector2(0,r*0.51),Color("1b1e20"),r*0.28,true)

func _draw() -> void:
	if not active: return
	# Continuous outer rails and planar bevels replace the donor's pinched,
	# row-dependent warp. Geometry stays registered to the original apertures.
	_panel(Rect2(187,63,121,130))
	_panel(Rect2(192,66,109,65))
	_poly([Vector2(198,67),Vector2(295,67),Vector2(280,80),Vector2(214,80)],Color("30363a"))
	_poly([Vector2(198,67),Vector2(214,80),Vector2(214,129),Vector2(198,129)],Color("81868a"))
	_poly([Vector2(295,67),Vector2(295,129),Vector2(280,129),Vector2(280,80)],Color("747a7e"))
	_rect(Rect2(214,80,66,50),Color("101718"))
	_rect(Rect2(198,129,97,1),Color("d0d1d0"))
	# One clean horizontal junction, without touching heading or compass ink.
	_rect(Rect2(211,130,72,14),Color("343a3e"))
	_rect(Rect2(211,144,72,0.6),Color("dedfdd"))
	_rect(Rect2(206,147,84,41),Color("343a3e"))
	_rect(Rect2(206,188,84,0.6),Color("dedfdd"))
	for p in SCREWS: _screw(p)
