extends Control
## Source-shaped mission/strategic FRAME surround only, never tactical contents.
const CATALOG_SHA:="8f8bb4ddb362a518ad51ab80975249649e42d1f047f43eb0a70f4e00ac99fa15"
var catalog:Dictionary={}
var active:Dictionary={}
func _init()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	clip_contents=true
	resized.connect(queue_redraw)
	hide()
func clear()->void:
	active.clear();hide();queue_redraw()
func load_sources(root_path:String)->bool:
	clear();catalog.clear()
	var path:=root_path.path_join("local-art/pc-map-frame-v1/frame.json")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=CATALOG_SHA:return false
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("schema")!=1:return false
	for name in data.sources:
		path=root_path.path_join("GAME/"+name)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=data.sources[name]:return false
	path=root_path.path_join(data.donor.path)
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=data.donor.sha256:return false
	catalog=data
	return true
func set_frame(source:Image,program:Dictionary,presentation:Dictionary={})->bool:
	clear()
	if catalog.is_empty() or program.get("name") not in ["START","END"]:return false
	if source==null or source.get_size()!=Vector2i(320,200) or source.get_format()!=Image.FORMAT_RGB8:return false
	if presentation.has("frontend_program") and presentation.frontend_program!=program:return false
	var hash:=HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for r in catalog.guard_rects:
		hash.update(source.get_region(Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3]))).get_data())
	if hash.finish().hex_encode()!=catalog.border_rgb_sha256:return false
	active={"scene":"map_frame","name":"Original FRAME vector surround","program":program.name,
		"rivets":catalog.rivets.size(),"content_preserved":[10,10,300,166],"footer_rebuilt":[0,187,320,13]}
	show();queue_redraw();return true
func _fill(rect:Rect2,color:Color,factor:Vector2)->void:
	draw_rect(Rect2(rect.position*factor,rect.size*factor),color)
func _metal(rect:Rect2,factor:Vector2,top:Color,bottom:Color)->void:
	var a:=rect.position*factor;var b:=rect.end*factor
	draw_polygon(PackedVector2Array([a,Vector2(b.x,a.y),b,Vector2(a.x,b.y)]),PackedColorArray([top,top,bottom,bottom]))
func _draw()->void:
	if active.is_empty():return
	var factor:=size/Vector2(320,200)
	var shade:=Color8(65,68,65)
	var light:=Color8(238,238,238)
	# Axis-aligned filled strips cannot antialias into the original content.
	for r in [Rect2(0,0,320,10),Rect2(0,10,10,166),Rect2(310,10,10,166),Rect2(0,176,320,11)]:
		_metal(r,factor,Color8(188,187,188),Color8(158,158,160))
	# The complete footer is in the source fingerprint above. An overwritten
	# footer rejects the whole frame, so no message can be covered by this fill.
	_metal(Rect2(0,187,320,13),factor,Color8(145,147,150),Color8(110,114,119))
	_fill(Rect2(0,187,320,0.35),light,factor)
	for r in [Rect2(0,0,320,1),Rect2(0,0,1,187),Rect2(319,0,1,187),Rect2(0,185,320,2),
		Rect2(8,8,304,1),Rect2(8,177,304,1),Rect2(8,9,1,168),Rect2(311,9,1,168)]:_fill(r,shade,factor)
	for r in [Rect2(1,1,318,1),Rect2(318,2,1,183)]:_fill(r,light,factor)
	for r in [Rect2(9,9,302,1),Rect2(9,176,302,1),Rect2(9,10,1,166),Rect2(310,10,1,166)]:_fill(r,Color8(0,170,0),factor)
	for rivet in catalog.rivets:
		var c:=Vector2(rivet.center[0],rivet.center[1])
		var edge:=PackedVector2Array()
		for i in 64:edge.append((c+Vector2.from_angle(TAU*i/64.0)*2.3)*factor)
		draw_colored_polygon(edge,shade)
		var highlight:=PackedVector2Array()
		var rotation:=-float(rivet.quarter_turns)*PI/2.0
		for i in 17:highlight.append((c+Vector2.from_angle(PI+PI*i/16.0+rotation)*1.25)*factor)
		draw_polyline(highlight,light,minf(factor.x,factor.y)*0.8,true)
		var stroke:=minf(factor.x,factor.y)*0.85
		draw_line((c-Vector2(1.15,0))*factor,(c+Vector2(1.15,0))*factor,Color.BLACK,stroke,true)
		draw_line((c-Vector2(0,1.15))*factor,(c+Vector2(0,1.15))*factor,Color.BLACK,stroke,true)
