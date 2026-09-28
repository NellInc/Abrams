extends ColorRect
## Genesis-style square-ended gunner graticule, from the completed PC draw.
## Identical integer-scale ink footprint; analytic edges at fractional scales.
const SIM_SHA = "9ee5a5898ddcb8192d30b4083981419515eb3ca220e6cbcd214df628bb164099"
const TABLE_SHA = "b7cba01774ea26a79711b547634c0b0c46abebe9f9b214f110b37db594316a9c"
const OFFSETS = [Vector4i(-4,20,4,20),Vector4i(0,20,0,3),Vector4i(25,3,25,-4),Vector4i(25,0,4,0),
	Vector4i(-4,-20,4,-20),Vector4i(0,-20,0,-3),Vector4i(-25,3,-25,-4),Vector4i(-25,0,-4,0)]
const BOX = Rect2i(134,13,51,97)
var packet: Dictionary = {}
var ink: Array[Vector2i] = []
var rectangles: Array[Rect2i] = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = preload("res://scripts/pc_reticle_art.gdshader")
	material = shader_material
	clear()

func clear() -> void:
	packet.clear()
	ink.clear()
	rectangles.clear()
	hide()
	material.set_shader_parameter("stroke_count",0)

static func integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floor(float(value))

static func geometry(center: int) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	for p in OFFSETS:
		var x1: int = 159+p.x
		var x2: int = 159+p.z
		var y1: int = center+p.y
		var y2: int = center+p.w
		if y1==y2:
			if y1>=13 and y1<=109: result.append(Rect2i(mini(x1,x2),y1,absi(x2-x1)+1,1))
			continue
		if y1<13:
			if y2<13: continue
			y1=13
		elif y2<13: y2=y1; y1=13
		if y1>109:
			if y2>109: continue
			y1=109
		elif y2>109: y2=y1; y1=109
		result.append(Rect2i(x1,y1 if y2>=y1 else y2+1,1,maxi(absi(y2-y1),1)))
	return result

func set_frame(source: Image, ui: Image, presentation: Dictionary) -> bool:
	clear()
	var item = presentation.get("reticle")
	if not item is Dictionary or item.get("schema")!=1 or item.get("source_sha256")!=SIM_SHA or item.get("table_sha256")!=TABLE_SHA: return false
	if not integer(item.get("center_y")) or item.center_y < -32768 or item.center_y > 32767: return false
	if not integer(item.get("color")) or int(item.color) not in [0,1]: return false
	if not integer(item.get("page_offset")) or int(item.page_offset) not in [0,8192] or item.page_offset!=presentation.get("page_offset"): return false
	if item.get("rect")!=[134,13,51,97]:
		# JSON transports integers as floats; compare components explicitly.
		if not item.get("rect") is Array or item.rect.size()!=4: return false
		for i in 4:
			if not integer(item.rect[i]) or int(item.rect[i])!=[134,13,51,97][i]: return false
	if not item.get("lines") is Array or item.lines.size()!=8: return false
	for i in 8:
		var line = item.lines[i]
		if not line is Array or line.size()!=4: return false
		var p: Vector4i = OFFSETS[i]
		var expected := [159+p.x,int(item.center_y)+p.y,159+p.z,int(item.center_y)+p.w]
		for j in 4:
			if not integer(line[j]) or int(line[j])!=expected[j]: return false
	for image in [source,ui]:
		if image==null or image.get_size()!=Vector2i(320,200): return false
	var clip = presentation.get("draw_pass",{}).get("camera",{}).get("clip")
	if not clip is Array or clip.size()!=4: return false
	for i in 4:
		if not integer(clip[i]) or int(clip[i])!=[32,13,287,109][i]: return false
	var crop := source.get_region(BOX)
	crop.convert(Image.FORMAT_RGB8)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(crop.get_data())
	if hash.finish().hex_encode()!=item.get("pixel_sha256"): return false
	var shape := geometry(int(item.center_y))
	if shape.is_empty(): return false
	var points := {}
	var color := Color.BLACK if item.color==0 else Color.WHITE
	for rect in shape:
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):
				if ui.get_pixel(x,y).r!=1.0 or source.get_pixel(x,y).to_rgba32()!=color.to_rgba32(): return false
				points[Vector2i(x,y)]=true
	ink.assign(points.keys())
	rectangles=shape
	var strokes := PackedVector4Array()
	for rect in shape: strokes.append(Vector4(rect.position.x,rect.position.y,rect.end.x,rect.end.y))
	strokes.resize(8)
	material.set_shader_parameter("strokes",strokes)
	material.set_shader_parameter("stroke_count",shape.size())
	material.set_shader_parameter("ink_color",color)
	packet=item.duplicate(true)
	show()
	return true
