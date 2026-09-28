extends "res://scripts/pc_reticle_art.gd"
## The original selected-target box. Same source-owned analytic ink as the sight.
const TARGET_BOX = Rect2i(32,13,256,97)

static func target_lines(x: int,y: int) -> Array:
	return [[x-5,y-5,x+5,y-5],[x-5,y+5,x+5,y+5],[x-5,y-5,x-5,y+5],[x+5,y-5,x+5,y+5]]

static func target_geometry(cx: int,cy: int) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	for p in target_lines(cx,cy):
		var x1: int=p[0]
		var y1: int=p[1]
		var x2: int=p[2]
		var y2: int=p[3]
		if y1==y2:
			var left := maxi(x1,32)
			var right := mini(x2,287)
			if y1>=13 and y1<=109 and right>=left: result.append(Rect2i(left,y1,right-left+1,1))
		elif x1>=32 and x1<=287:
			if y1<13:
				if y2<13: continue
				y1=13
			if y2>109:
				if y1>109: continue
				y2=y1
				y1=109
			result.append(Rect2i(x1,y1 if y2>=y1 else y2+1,1,maxi(absi(y2-y1),1)))
	return result

func set_frame(source: Image, ui: Image, presentation: Dictionary) -> bool:
	clear()
	var item = presentation.get("target_box")
	if not item is Dictionary or item.get("schema")!=1 or item.get("source_sha256")!=SIM_SHA: return false
	if not item.get("center") is Array or item.center.size()!=2: return false
	for value in item.center:
		if not integer(value) or value< -32763 or value>32762: return false
	if not integer(item.get("color")) or int(item.color) not in [0,1]: return false
	if not integer(item.get("page_offset")) or int(item.page_offset) not in [0,8192] or item.page_offset!=presentation.get("page_offset"): return false
	if not item.get("rect") is Array or item.rect.size()!=4: return false
	for i in 4:
		if not integer(item.rect[i]) or int(item.rect[i])!=[32,13,256,97][i]: return false
	var expected := target_lines(int(item.center[0]),int(item.center[1]))
	if not item.get("lines") is Array or item.lines.size()!=4: return false
	for i in 4:
		if not item.lines[i] is Array or item.lines[i].size()!=4: return false
		for j in 4:
			if not integer(item.lines[i][j]) or int(item.lines[i][j])!=expected[i][j]: return false
	for image in [source,ui]:
		if image==null or image.get_size()!=Vector2i(320,200): return false
	var clip = presentation.get("draw_pass",{}).get("camera",{}).get("clip")
	if not clip is Array or clip.size()!=4: return false
	for i in 4:
		if not integer(clip[i]) or int(clip[i])!=[32,13,287,109][i]: return false
	var crop := source.get_region(TARGET_BOX)
	crop.convert(Image.FORMAT_RGB8)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(crop.get_data())
	if hash.finish().hex_encode()!=item.get("pixel_sha256"): return false
	var shape := target_geometry(int(item.center[0]),int(item.center[1]))
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
