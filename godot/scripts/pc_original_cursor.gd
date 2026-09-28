extends Control
## Scalable arrow restoration, selected only by the complete original cursor.
## The original16x15 receipt and79 opaque pixels still govern position/visibility.
const SOURCE_SHA="a7b6148ea54b389b1385c0932d8d9c6ae071cec5edbec75c8e13f1ae17bb6495"
const INDICES_SHA="947f6443abb63e2e99bc1ea731cc2ce95f3bc761ee981615821487ea5b80de3f"
var source_verified:=false
var mask:Image
var active:Array=[]
var origin:=Vector2.ZERO
var outline_colour:=Color.WHITE
var fill_colour:=Color.WHITE
# Authored straight edges replace bitmap stair steps inside the source16x15
# cursor allocation. The tip, upper-left orientation and bent stem stay fixed.
const OUTLINE= [Vector2(0.5,0.5),Vector2(2,0.5),Vector2(10,8.5),Vector2(10,9),
	Vector2(7,9),Vector2(8.5,14),Vector2(8.5,14.5),Vector2(5,14.5),Vector2(3.5,10.7),Vector2(0.5,13.5)]
const FILL= [Vector2(1,0.7),Vector2(8.5,7.7),Vector2(5.2,7.7),
	Vector2(7.8,13.8),Vector2(6.2,14),Vector2(3.1,8.4),Vector2(1,11.3)]
func _init()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func load_sources(root_path:String)->void:
	var path:=root_path.path_join("GAME/CURSOR.BMP")
	source_verified=FileAccess.file_exists(path) and FileAccess.get_sha256(path)==SOURCE_SHA
	clear()
func clear()->void:
	active.clear();mask=null;queue_redraw()
func set_frame(source:Image,presentation:Dictionary)->void:
	clear()
	if source==null or source.get_size()!=Vector2i(320,200) or source.get_format()!=Image.FORMAT_RGB8:return
	var item=presentation.get("original_cursor")
	var palette=presentation.get("palette_rgb")
	if not source_verified or not item is Dictionary or item.get("source_sha256")!=SOURCE_SHA or not palette is Array or palette.size()!=16:return
	if not preload("res://scripts/pc_typography.gd").integers(item.get("rect"),4,0,320) or not item.get("indices") is String:return
	var box:=Rect2i(item.rect[0],item.rect[1],item.rect[2],item.rect[3])
	if box.size!=Vector2i(16,15) or box.end.x>320 or box.end.y>200:return
	# Exactly 240 bytes encode to 320 unpadded characters. Reject malformed
	# metadata before Godot's decoder can emit an engine error.
	if item.indices.length()!=320:return
	for character in item.indices:
		if not character in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/":return
	var bytes:=Marshalls.base64_to_raw(item.indices)
	if bytes.size()!=240:return
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
	if hash.finish().hex_encode()!=INDICES_SHA:return
	var points:Array=[]
	var proof:=Image.create_empty(320,200,false,Image.FORMAT_L8)
	for i in bytes.size():
		var c:=int(bytes[i])
		if c==0:continue
		if not preload("res://scripts/pc_typography.gd").integers(palette[c],3,0,255):return
		var point:=box.position+Vector2i(i%16,i/16)
		var colour:=Color8(palette[c][0],palette[c][1],palette[c][2])
		if source.get_pixelv(point).to_rgba32()!=colour.to_rgba32():return
		proof.set_pixelv(point,Color.WHITE);points.append([Vector2(point),colour])
	active=points;mask=proof;origin=Vector2(box.position)
	outline_colour=Color8(palette[2][0],palette[2][1],palette[2][2])
	fill_colour=Color8(palette[15][0],palette[15][1],palette[15][2])
	queue_redraw()
func _draw()->void:
	if active.is_empty():return
	var factor:=size/Vector2(320,200)
	var outer:=PackedVector2Array();var inner:=PackedVector2Array()
	for point in OUTLINE:outer.append((origin+point)*factor)
	for point in FILL:inner.append((origin+point)*factor)
	draw_colored_polygon(outer,outline_colour)
	outer.append(outer[0])
	draw_polyline(outer,outline_colour,minf(factor.x,factor.y),true)
	draw_colored_polygon(inner,fill_colour)
	# One output-pixel antialiasing stroke, independent of display scale.
	inner.append(inner[0])
	draw_polyline(inner,fill_colour,1.0,true)
