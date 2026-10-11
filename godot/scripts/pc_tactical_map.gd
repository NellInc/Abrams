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
var surface_texture: ImageTexture
var surface_hash := ""
# Two exact original material recipes, not inferred hill/object identities.
# RGB labels with a 43 channel cannot collide with the standard EGA palette.
const EARTH_DARK := 0x552b00
const EARTH_LIGHT := 0x80552b
const SURFACES := [0x00aa00,0xaaaaaa,0x555555,0x5555ff,0xaa5500]
var font: Font = preload("res://assets/fonts/IBMPlexMono-Regular.ttf")

static func _rgb_code(bytes: PackedByteArray, at: int) -> int:
	return (int(bytes[at])<<16)|(int(bytes[at+1])<<8)|int(bytes[at+2])

static func _components(codes: PackedInt32Array, width: int) -> Array:
	var seen:=PackedByteArray();seen.resize(codes.size())
	var result: Array=[]
	for start in codes.size():
		if seen[start] or codes[start]<0: continue
		var cells:=PackedInt32Array([start]);seen[start]=1
		var cursor:=0
		while cursor<cells.size():
			var at:=cells[cursor];cursor+=1
			for next in [at-1 if at%width>0 else -1,at+1 if at%width<width-1 else -1,at-width,at+width]:
				if next<0 or next>=codes.size() or seen[next] or codes[next]!=codes[start]: continue
				seen[next]=1;cells.append(next)
		result.append(cells)
	return result

static func surface_image(terrain: Image, local: bool) -> Image:
	var width:=terrain.get_width()
	var height:=terrain.get_height()
	var data:=terrain.get_data()
	var codes:=PackedInt32Array();codes.resize(width*height)
	var pattern:=PackedInt32Array();pattern.resize(codes.size());pattern.fill(-1)
	for i in codes.size(): codes[i]=_rgb_code(data,i*4)
	if local:
		# Match complete 2x2 periods at the original screen phase (origin16,63).
		# A whole recognition window must avoid the protected player stencil.
		for y in height-1:
			for x in width-1:
				var cells: Array=[y*width+x,y*width+x+1,(y+1)*width+x,(y+1)*width+x+1]
				var alternate: int=codes[cells[0 if (x+y+63)%2==0 else 1]]
				if alternate not in [0x000000,0x555555]: continue
				var matches:=true
				for j in 4:
					var expected:=0xaa5500 if (x+j%2+y+j/2+63)%2==1 else alternate
					if data[cells[j]*4+3]==0 or codes[cells[j]]!=expected: matches=false;break
				if matches:
					var recipe:=EARTH_DARK if alternate==0 else EARTH_LIGHT
					for at in cells:
						if pattern[at]==-1: pattern[at]=recipe
						elif pattern[at]!=recipe: pattern[at]=-2 # Ambiguous overlap keeps source ink.
		# Unique cardinally connected coverage, never a count of overlapping tiles.
		# Tiny or incomplete patterned marks keep their original source ink.
		for cells in _components(pattern,width):
			if cells.size()<16: continue
			for at in cells:
				codes[at]=pattern[at]
				data[at*4]=(codes[at]>>16)&255;data[at*4+1]=(codes[at]>>8)&255;data[at*4+2]=codes[at]&255
	# Unknown colours and small components are exact nearest-source patches.
	# Large regions retain a finite source-cell core in the contour shader.
	for cells in _components(codes,width):
		var supported: bool=codes[cells[0]] in SURFACES or (local and pattern[cells[0]]==codes[cells[0]])
		if supported and cells.size()>=8: continue
		for at in cells: data[at*4+3]=0
	return Image.create_from_data(width,height,false,Image.FORMAT_RGBA8,data)

static func terrain_image(source: Image, item: Dictionary) -> Image:
	if int(item.mode)==0:
		# Rebuild the observed cells, excluding the final player dot completely.
		var result:=Image.create(48,48,false,Image.FORMAT_RGBA8)
		var rgb: Array=item.palette_rgb[int(item.background)]
		result.fill(Color8(rgb[0],rgb[1],rgb[2]))
		for i in range(0,item.lines.size()-1,2):
			var row: Array=item.lines[i];rgb=item.palette_rgb[int(row[4])]
			result.set_pixel((int(row[0])-16)/3,(int(row[1])-63)/2,Color8(rgb[0],rgb[1],rgb[2]))
		return result
	var result:=source.get_region(Proof.MAP_RECT);result.convert(Image.FORMAT_RGBA8)
	# LOCAL has no evidence for terrain beneath its marker. Keep a full stencil
	# around it untouched, and make cache identity independent of marker blinking.
	result.fill_rect(Rect2i(69,45,6,6),Color(0,0,0,0))
	return result

func _surface(source: Image, item: Dictionary) -> void:
	var terrain:=terrain_image(source,item)
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(terrain.get_data())
	var key:=str(item.mode)+hash.finish().hex_encode()
	if key!=surface_hash or surface_texture==null:
		var styled:=surface_image(terrain,int(item.mode)==1)
		if surface_texture==null or surface_texture.get_size()!=Vector2(styled.get_size()): surface_texture=ImageTexture.create_from_image(styled)
		else: surface_texture.update(styled)
		surface_hash=key
	ink.set_shader_parameter("surface_pixels",surface_texture)
	ink.set_shader_parameter("grid_size",Vector2(terrain.get_size()))
	ink.set_shader_parameter("local_map",int(item.mode)==1)

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
	_surface(frame._cached_source,item)
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
