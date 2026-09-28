extends Control
## Preserve the original arrow above refined menu letters, pixel for pixel.
const SOURCE_SHA="a7b6148ea54b389b1385c0932d8d9c6ae071cec5edbec75c8e13f1ae17bb6495"
const INDICES_SHA="947f6443abb63e2e99bc1ea731cc2ce95f3bc761ee981615821487ea5b80de3f"
var source_verified:=false
var mask:Image
var active:Array=[]
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
	active=points;mask=proof;queue_redraw()
func _draw()->void:
	var factor:=size/Vector2(320,200)
	for pixel in active:draw_rect(Rect2(pixel[0]*factor,factor),pixel[1])
