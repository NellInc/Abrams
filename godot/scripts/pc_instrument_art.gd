extends Control
## Genesis illustrations registered into verified original-PC instrument cells.
## No values, states or visibility are inferred from the remastered artwork.
const SOURCE_HASH = "83e46895044a85a4e3abdd8daf836605a40cbb475c02fe2c8b3fe0664da9e036"
# Source rectangles are PC coordinates. Donor rectangles are measured pixels
# in the Genesis-derived 1586x992 illustration, never guessed gameplay values.
const CELLS = [
	{"name":"heat_icon","source":Rect2i(240,141,23,12),"donor":Rect2(1182,652,126,44),
		"outline":[Vector2(0,0),Vector2(20,0),Vector2(20,3),Vector2(82,3),Vector2(82,7),Vector2(91,7),Vector2(118,17),Vector2(126,22),Vector2(118,28),Vector2(91,37),Vector2(82,37),Vector2(82,41),Vector2(20,41),Vector2(20,44),Vector2(0,44)]},
	{"name":"sabot_icon","source":Rect2i(240,154,23,11),"donor":Rect2(1182,736,116,40),
		"outline":[Vector2(0,0),Vector2(19,0),Vector2(19,3),Vector2(70,3),Vector2(70,6),Vector2(81,8),Vector2(116,20),Vector2(81,32),Vector2(70,34),Vector2(70,37),Vector2(19,37),Vector2(19,40),Vector2(0,40)]},
	{"name":"ax_icon","source":Rect2i(240,167,23,11),"donor":Rect2(1182,812,119,43),
		"outline":[Vector2(0,0),Vector2(20,0),Vector2(20,3),Vector2(81,3),Vector2(81,8),Vector2(90,8),Vector2(119,21),Vector2(90,35),Vector2(81,35),Vector2(81,40),Vector2(20,40),Vector2(20,43),Vector2(0,43)]},
	{"name":"coax_icon","source":Rect2i(240,180,23,11),"donor":Rect2(1182,893,124,48),
		"outline":[Vector2(0,48),Vector2(0,13),Vector2(6,1),Vector2(12,12),Vector2(19,1),Vector2(25,12),Vector2(32,1),Vector2(39,12),Vector2(45,1),Vector2(52,12),Vector2(59,1),Vector2(65,12),Vector2(72,1),Vector2(79,12),Vector2(85,1),Vector2(92,12),Vector2(99,1),Vector2(106,13),Vector2(109,4),Vector2(118,1),Vector2(124,8),Vector2(124,48)]},
	{"name":"smoke_icon","source":Rect2i(285,141,23,12),"donor":Rect2(1461,651,58,44)},
	{"name":"temperature_label","source":Rect2i(285,154,23,11),"donor":Rect2(1451,739,85,32)},
	{"name":"display_icon","source":Rect2i(285,167,23,11),"donor":Rect2(1440,817,102,38)},
	{"name":"target_icon","source":Rect2i(285,180,23,11),"donor":Rect2(1438,892,98,52)},
	{"name":"speed_scale","source":Rect2i(13,178,78,7),"donor":Rect2(76,868,357,29)},
]
var source_plate: Image
var donor: Texture2D
var active: Array[Dictionary] = []
var gauges: Array[Dictionary] = []
var plates: Dictionary = {}
var orientation = preload("res://scripts/pc_orientation_art.gd").new()
const PLATES = {
	1:["gps-bin","83e46895044a85a4e3abdd8daf836605a40cbb475c02fe2c8b3fe0664da9e036"],
	2:["tc-bin","c6c3691fc37cb6e7856e7f8f15ea1997facce823ecd724a89176226ee0b26b98"],
	4:["driver-bin","914d1605f7afa79f293e666a29e81d6c001cac41e0f89d14897c3ec61fecf32b"]}
# Six-row strips are proved by the original line rasterizer, not an inclusive
# interpretation of its (y,y+6) arguments. All rectangles are source pixels.
const BARS = [
	{"name":"gunner_speed","plate":1,"source":Rect2i(13,186,77,6),"guard":Rect2i(12,177,80,16),"count":39,"red":0},
	{"name":"commander_speed","plate":2,"source":Rect2i(16,186,77,6),"guard":Rect2i(14,176,80,18),"count":39,"red":0},
	{"name":"commander_fuel","plate":2,"source":Rect2i(103,186,55,6),"guard":Rect2i(101,176,61,18),"count":28,"red":4}]
const LAMPS = [
	{"name":"gunner_temperature","plate":1,"source":Rect2i(271,154,13,11),"guard":Rect2i(269,153,16,13)},
	{"name":"driver_temperature","plate":4,"source":Rect2i(233,190,19,7),"guard":Rect2i(233,187,20,1)}]
const INACTIVE = Color8(85,85,85)
const GREEN = Color8(0,170,0)
const RED = Color8(170,0,0)
const YELLOW = Color8(255,255,85)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(queue_redraw)
	resized.connect(_layout_orientation)
	add_child(orientation)
	orientation.clear()

func load_sources(root: String, art: Image) -> bool:
	clear()
	source_plate = null
	donor = null
	plates.clear()
	var path := root.path_join("local-art/pc-ui-v2/gps-bin.png")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=SOURCE_HASH: return false
	if art==null or art.get_size()!=Vector2i(1586,992): return false
	source_plate = Image.load_from_file(path)
	donor = ImageTexture.create_from_image(art)
	# A missing station source disables just its dynamic instruments.
	for id in PLATES:
		var entry: Array = PLATES[id]
		var plate_path := root.path_join("local-art/pc-ui-v2/"+entry[0]+".png")
		if FileAccess.file_exists(plate_path) and FileAccess.get_sha256(plate_path)==entry[1]:
			plates[id] = Image.load_from_file(plate_path)
	return true

func clear() -> void:
	active.clear()
	gauges.clear()
	orientation.clear()
	queue_redraw()

func set_frame(source: Image, ui: Image, tags: Image, diagram: Dictionary = {}) -> void:
	clear()
	if source_plate==null or donor==null: return
	for image in [source,ui,tags]:
		if image==null or image.get_size()!=Vector2i(320,200): return
	orientation.set_frame(source,ui,tags,plates,diagram)
	_layout_orientation()
	for item in CELLS:
		var box: Rect2i = item.source
		var valid := true
		for y in range(box.position.y,box.end.y):
			for x in range(box.position.x,box.end.x):
				if ui.get_pixel(x,y).r!=1.0 or roundi(tags.get_pixel(x,y).r*255)!=1 or source.get_pixel(x,y).to_rgba32()!=source_plate.get_pixel(x,y).to_rgba32():
					valid = false
					break
			if not valid: break
		if valid: active.append(item)
	for spec in BARS:
		if not _guard_matches(spec,source,ui,tags): continue
		var colors: Array[Color] = []
		var valid := true
		var inactive := false
		var lit := 0
		for i in spec.count:
			var x: int = spec.source.position.x+i*2
			var color := source.get_pixel(x,186)
			var expected: Color = RED if i<spec.red else GREEN
			if color.to_rgba32()==INACTIVE.to_rgba32(): inactive = true
			elif inactive or color.to_rgba32()!=expected.to_rgba32(): valid = false
			else: lit += 1
			# Every strip must come from a subsequent original draw. Gaps must
			# remain the source plate's black, with no text/overlay corruption.
			for y in range(186,192):
				if not _dynamic_pixel(source,ui,tags,Vector2i(x,y),color): valid = false
				if i<spec.count-1:
					if source.get_pixel(x+1,y).to_rgba32()!=Color.BLACK.to_rgba32() or ui.get_pixel(x+1,y).r!=1.0 or roundi(tags.get_pixel(x+1,y).r*255)!=spec.plate: valid = false
			colors.append(color)
		if valid: gauges.append(spec.merged({"kind":"bar","colors":colors,"lit":lit}))
	for spec in LAMPS:
		if not _guard_matches(spec,source,ui,tags): continue
		var color := source.get_pixelv(spec.source.position)
		if color.to_rgba32() not in [GREEN.to_rgba32(),RED.to_rgba32(),YELLOW.to_rgba32(),Color.BLACK.to_rgba32()]: continue
		var valid := true
		for y in range(spec.source.position.y,spec.source.end.y):
			for x in range(spec.source.position.x,spec.source.end.x):
				if not _dynamic_pixel(source,ui,tags,Vector2i(x,y),color): valid = false
		if spec.plate==4:
			# The driver readout frame is drawn after DRIVER.BIN. Its exact
			# blue top, bottom and right edges are context, never repainted.
			for y in range(189,198):
				for x in range(233,253):
					if spec.source.has_point(Vector2i(x,y)): continue
					if not _dynamic_pixel(source,ui,tags,Vector2i(x,y),Color8(85,85,255)): valid = false
		if valid: gauges.append(spec.merged({"kind":"lamp","color":color}))
	queue_redraw()

func _guard_matches(spec: Dictionary, source: Image, ui: Image, tags: Image) -> bool:
	if not plates.has(spec.plate): return false
	for y in range(spec.guard.position.y,spec.guard.end.y):
		for x in range(spec.guard.position.x,spec.guard.end.x):
			var p := Vector2i(x,y)
			if spec.source.has_point(p): continue
			if ui.get_pixelv(p).r!=1.0 or roundi(tags.get_pixelv(p).r*255)!=spec.plate: return false
			if source.get_pixelv(p).to_rgba32()!=plates[spec.plate].get_pixelv(p).to_rgba32(): return false
	return true

func _dynamic_pixel(source: Image, ui: Image, tags: Image, p: Vector2i, color: Color) -> bool:
	return ui.get_pixelv(p).r==1.0 and tags.get_pixelv(p).r==0.0 and source.get_pixelv(p).to_rgba32()==color.to_rgba32()

func _beveled_cell(box: Rect2, color: Color, bevel: float) -> void:
	# Same flat colour field and clipped, machined edges as the Genesis donor.
	# No glow outside the proven rectangle, interpolation or hidden values.
	draw_rect(box,Color.BLACK)
	if color.to_rgba32()==Color.BLACK.to_rgba32(): return
	var a := box.position
	var b := box.end
	draw_colored_polygon(PackedVector2Array([a+Vector2(bevel,0),Vector2(b.x-bevel,a.y),
		Vector2(b.x,a.y+bevel),b-Vector2(0,bevel),b-Vector2(bevel,0),
		Vector2(a.x+bevel,b.y),Vector2(a.x,b.y-bevel),a+Vector2(0,bevel)]),color)
	draw_colored_polygon(PackedVector2Array([a+Vector2(bevel,0),Vector2(b.x-bevel,a.y),
		Vector2(b.x-bevel,a.y+bevel),a+Vector2(bevel,bevel)]),color.lightened(0.16))
	draw_rect(Rect2(Vector2(a.x+bevel,b.y-bevel),Vector2(box.size.x-2*bevel,bevel)),color.darkened(0.24))

func _draw() -> void:
	if donor==null: return
	draw_set_transform(Vector2.ZERO,0,size/Vector2(320,200))
	for item in active:
		if item.name=="speed_scale":
			draw_texture_rect_region(donor,Rect2(item.source),item.donor)
			continue
		# The illustration contains blank space for a count to its left. That
		# space is NOT part of the icon. Fit the tight artwork crop uniformly,
		# centred in the proven cell, over the original well's flat background.
		var box := fitted_icon_rect(item)
		draw_rect(Rect2(item.source),source_plate.get_pixelv(item.source.position))
		if item.has("outline"):
			var points := PackedVector2Array()
			var uv := PackedVector2Array()
			for point: Vector2 in item.outline:
				points.append(box.position+point*box.size/item.donor.size)
				uv.append((item.donor.position+point)/Vector2(donor.get_size()))
			# Textured silhouettes avoid importing the generated well colours.
			draw_polygon(points,PackedColorArray([Color.WHITE]),uv,donor)
		else: draw_texture_rect_region(donor,box,item.donor)
	for gauge in gauges:
		if gauge.kind=="lamp": _beveled_cell(Rect2(gauge.source),gauge.color,0.4)
		else:
			for i in gauge.count:
				_beveled_cell(Rect2(gauge.source.position+Vector2i(i*2,0),Vector2(1,6)),gauge.colors[i],0.18)

static func fitted_icon_rect(item: Dictionary) -> Rect2:
	var cell := Rect2(item.source).grow(-1.0)
	var factor: float = minf(cell.size.x/item.donor.size.x,cell.size.y/item.donor.size.y)
	var extent: Vector2 = item.donor.size*factor
	return Rect2(cell.get_center()-extent/2.0,extent)

func _layout_orientation() -> void:
	if orientation.source_rect.size==Vector2i.ZERO: return
	var factor := size/Vector2(320,200)
	orientation.position = Vector2(orientation.source_rect.position)*factor
	orientation.size = Vector2(orientation.source_rect.size)*factor
