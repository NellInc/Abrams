extends Control
## Crisp original diagram geometry, paired to the completed visible PC draw.
## This child clips all antialiasing to its proven original rectangle.
const SIM_SHA = "9ee5a5898ddcb8192d30b4083981419515eb3ca220e6cbcd214df628bb164099"
const PALETTE = [Color8(0,0,0),Color8(255,255,255),Color8(170,170,170),Color8(85,85,85),
	Color8(85,85,255),Color8(85,255,255),Color8(170,0,0),Color8(170,85,0),Color8(0,170,0),
	Color8(85,255,85),Color8(255,255,85),Color8(0,0,0),Color8(255,85,85),Color8(0,0,170),
	Color8(85,255,255),Color8(255,255,255)]
var packet: Dictionary = {}
var source_rect := Rect2i()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)

func clear() -> void:
	packet.clear()
	source_rect = Rect2i()
	hide()
	queue_redraw()

func set_frame(source: Image, ui: Image, tags: Image, plates: Dictionary, item: Dictionary) -> bool:
	clear()
	if item.get("schema")!=1 or item.get("source_sha256")!=SIM_SHA: return false
	if item.get("page_offset")!=0 and item.get("page_offset")!=8192: return false
	if not _integers([item.get("station")],1): return false
	var station: int = int(item.station)
	if station not in [0,1]: return false
	var box := Rect2i(128,137,62,44) if station==0 else Rect2i(216,83,62,44)
	var guard := Rect2i(126,136,67,47) if station==0 else Rect2i(214,81,66,49)
	var plate := station+1
	if not _integers(item.get("rect"),4) or not plates.has(plate): return false
	if item.rect.map(func(n):return int(n))!=[box.position.x,box.position.y,62,44]: return false
	for image in [source,ui,tags]:
		if image==null or image.get_size()!=Vector2i(320,200): return false
	for y in range(guard.position.y,guard.end.y):
		for x in range(guard.position.x,guard.end.x):
			if ui.get_pixel(x,y).r!=1.0: return false
			if box.has_point(Vector2i(x,y)):
				if tags.get_pixel(x,y).r!=0.0: return false
			elif roundi(tags.get_pixel(x,y).r*255)!=plate or source.get_pixel(x,y).to_rgba32()!=plates[plate].get_pixel(x,y).to_rgba32(): return false
	var crop := source.get_region(box)
	crop.convert(Image.FORMAT_RGB8)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(crop.get_data())
	if hash.finish().hex_encode()!=item.get("pixel_sha256"): return false
	if not item.get("grid") is Array or item.grid.size()<5 or item.grid.size()>9: return false
	if not item.get("quads") is Array or item.quads.size()!=4: return false
	for line in item.grid:
		if not line is Dictionary or not _integers(line.get("points"),4) or line.get("color")!=8: return false
		var p: Array = line.points
		if p[0]==p[2]:
			if p[0]<box.position.x or p[0]>=box.end.x or p[1]!=box.position.y or p[3]!=box.end.y: return false
		elif p[1]==p[3]:
			if p[1]<box.position.y or p[1]>=box.end.y or p[0]!=box.position.x or p[2]!=box.end.x-1: return false
		else: return false
	for i in range(4):
		var quad = item.quads[i]
		if not quad is Dictionary or not quad.get("filled") is bool or quad.get("fill")!=0: return false
		if not _color(quad.get("border")) or not quad.get("edges") is Array: return false
		if not quad.edges.is_empty() and (i!=2 or quad.edges.size()!=4): return false
		for color in quad.edges:
			if not _color(color): return false
		if not quad.get("vertices_q14") is Array or quad.vertices_q14.size()!=4: return false
		if not quad.get("points") is Array or quad.points.size()!=4 or not _integers(quad.get("basis"),6): return false
		for j in range(4):
			if not _integers(quad.vertices_q14[j],2) or not _integers(quad.points[j],2): return false
			var signs := [Vector2i(1,1),Vector2i(-1,1),Vector2i(-1,-1),Vector2i(1,-1)]
			var basis: Array = quad.basis
			var exact := [int((box.position.x+32)*16384+signs[j].x*basis[0]+signs[j].y*basis[1]+basis[3]),
				int((box.position.y+21)*16384-signs[j].x*basis[2]-signs[j].y*basis[4]-basis[5])]
			if quad.vertices_q14[j].map(func(n):return int(n))!=exact: return false
			var p := Vector2(float(quad.vertices_q14[j][0]),float(quad.vertices_q14[j][1]))/16384.0
			if not Rect2(box).has_point(p): return false
			# X floors its fixed-point coordinate; Y subtracts a floored product.
			if quad.points[j].map(func(n):return int(n))!=[floori(p.x),ceili(p.y)]: return false
	packet = item.duplicate(true)
	source_rect = box
	show()
	queue_redraw()
	return true

func _integers(value: Variant, count: int) -> bool:
	if not value is Array or value.size()!=count: return false
	for n in value:
		if typeof(n) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(n)) or float(n)!=floor(float(n)): return false
	return true

func _color(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and value==int(value) and value>=0 and value<16

func _point(p: Array, divisor := 1.0) -> Vector2:
	return Vector2(float(p[0]),float(p[1]))/divisor-Vector2(source_rect.position)+Vector2(0.5,0.5)

func _draw() -> void:
	if packet.is_empty(): return
	# Scale geometry, not the antialiasing fringe. Godot then smooths over one
	# display pixel instead of stretching a source-pixel fringe into a halo.
	var factor := size/Vector2(source_rect.size)
	var stroke := minf(factor.x,factor.y)
	draw_rect(Rect2(Vector2.ZERO,size),Color.BLACK)
	for line in packet.grid:
		# Original axis rasterizer excludes its final endpoint.
		var p: Array = line.points
		var a := _point([p[0],p[1]])
		var b := _point([p[2],p[3]])
		var direction := (b-a).normalized()
		draw_line((a-direction*0.5)*factor,(b-direction*0.5)*factor,PALETTE[int(line.color)],stroke,true)
	for quad in packet.quads:
		var points := PackedVector2Array()
		for p in quad.vertices_q14: points.append(_point(p,16384.0)*factor)
		if quad.filled: draw_colored_polygon(points,PALETTE[int(quad.fill)])
		points.append(points[0])
		draw_polyline(points,PALETTE[int(quad.border)],stroke,true)
		for i in quad.edges.size(): draw_line(points[i],points[i+1],PALETTE[int(quad.edges[i])],stroke,true)
