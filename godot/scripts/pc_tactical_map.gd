extends Control
## A cartographic finish over the complete verified map, never a new map model.
const Proof = preload("res://scripts/pc_dynamic_map_art.gd")
var proof = Proof.new()
var picture := TextureRect.new()
var ink := ShaderMaterial.new()
var packet: Dictionary = {}
var map_box := Rect2()
var crop_texture: ImageTexture
var crop_hash := ""
var font: Font = preload("res://assets/fonts/IBMPlexMono-Regular.ttf")

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	ink.shader=preload("res://scripts/pc_tactical_map.gdshader")
	picture.material=ink
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	add_child(proof)
	proof.hide()
	resized.connect(_place)
	clear()

func clear() -> void:
	packet.clear()
	picture.hide()
	proof.clear()
	queue_redraw()

func set_frame(frame: Control, layout: Dictionary) -> bool:
	clear()
	if not frame.world_enabled or not proof.set_frame(frame._cached_source,frame._cached_presentation): return false
	proof.hide()
	var item: Dictionary=proof.packet
	# The source observer distinguishes cell rows from the final player draw.
	# Enforce that shape here too before treating any line as player ink.
	var lines: Array=item.lines
	if int(item.mode)==0:
		if lines.size()%2!=1: return false
		for i in range(0,lines.size()-1,2):
			var a: Array=lines[i]
			var b: Array=lines[i+1]
			if int(a[0]-16)%3!=0 or int(a[1]-63)%2!=0 or a[2]-a[0]!=2: return false
			if b!=[a[0],a[1]+1,a[2],a[3]+1,a[4]]: return false
		var last: Array=lines[-1]
		if last[0]!=last[2]: return false
	else:
		for i in 2:
			for j in 4:
				if lines[i][j]!=[87,110+i,88,110+i][j]: return false
	# Palette classes stay distinct. Unrecognised RGB is passed through by the
	# shader; the exact, currently selected player colour is drawn last.
	var marker_count:=2 if int(item.mode)==1 else 1
	for i in 2:
		var row: Array=lines[lines.size()-marker_count+mini(i,marker_count-1)]
		var colour: Array=item.palette_rgb[int(row[4])]
		ink.set_shader_parameter("marker_"+str(i),Vector4(row[0]-16,row[1]-63,row[2]-15,row[3]-62))
		ink.set_shader_parameter("marker_colour_"+str(i),Color8(int(colour[0]),int(colour[1]),int(colour[2])))
	if crop_hash!=item.pixel_sha256 or crop_texture==null:
		var crop: Image=frame._cached_source.get_region(Proof.MAP_RECT)
		if crop_texture==null: crop_texture=ImageTexture.create_from_image(crop)
		else: crop_texture.update(crop)
		crop_hash=item.pixel_sha256
	picture.texture=crop_texture
	ink.set_shader_parameter("map_pixels",crop_texture)
	var d: Vector4=layout.destination[1]
	map_box=Rect2(d.x*1600,d.y*900,(d.z-d.x)*1600,(d.w-d.y)*900)
	packet=item.duplicate(true)
	_place()
	picture.show()
	queue_redraw()
	return true

func _place() -> void:
	# The existing reflow includes a one-source-pixel surround on every side.
	var factor:=size/Vector2(1600,900)
	var inset:=map_box.size/Vector2(146,98)
	picture.position=(map_box.position+inset)*factor
	picture.size=(map_box.size-inset*2)*factor
	queue_redraw()

func _draw() -> void:
	if packet.is_empty(): return
	draw_set_transform(Vector2.ZERO,0,size/Vector2(1600,900))
	draw_rect(map_box,Color("0c1812"))
	draw_rect(map_box,Color("61785b"),false,1,true)
	var mode: String="LOCAL" if int(packet.mode)==1 else "OVERVIEW"
	var label:="[Z]  "+mode
	var width:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
	draw_string(font,Vector2(map_box.end.x-width,map_box.position.y-17),label,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e7b566"))
