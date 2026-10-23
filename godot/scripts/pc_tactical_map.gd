extends Control
## A cartographic finish over the complete verified map, never a new map model.
const FieldPanel = preload("res://scripts/pc_tactical_panel.gd")
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
var surface_build_count := 0
var proof_reuse_count := 0
# Styled surfaces for the last few exact terrain crops. Blinking contacts and
# marker phases alternate between crops; each key is a complete content hash.
const SURFACE_CACHE_SIZE := 4
var _surface_cache: Dictionary = {}
var _surface_order: Array[String] = []
var in_place := false
# Two exact original material recipes, not inferred hill/object identities.
# RGB labels with a 43 channel cannot collide with the standard EGA palette.
const EARTH_DARK := 0x552b00
const EARTH_LIGHT := 0x80552b
const SURFACES := [0x00aa00,0xaaaaaa,0x555555,0x5555ff,0xaa5500]
var font: Font = preload("res://assets/fonts/IBMPlexMono-Regular.ttf")

# Opaque RGBA8 words: one native pass replaces per-cell byte reads. Words only
# ever compare for equality, so their byte order is irrelevant. Their alpha
# byte is 255, so every word is negative and 0/1 are free as pattern marks.
const UNMARKED := 0
const AMBIGUOUS := 1

static func _word(rgb: int) -> int:
	return PackedByteArray([(rgb>>16)&255,(rgb>>8)&255,rgb&255,255]).to_int32_array()[0]

static func _words(terrain: Image) -> PackedInt32Array:
	# RGB alone defines a class; the protected stencil's zero alpha does not.
	var opaque:=terrain.duplicate()
	opaque.convert(Image.FORMAT_RGB8);opaque.convert(Image.FORMAT_RGBA8)
	return opaque.get_data().to_int32_array()

# Cardinal same-class flood fill from each listed start cell not yet reached.
static func _components(codes: PackedInt32Array, width: int, starts: PackedInt32Array) -> Array:
	var count:=codes.size()
	var seen:=PackedByteArray();seen.resize(count)
	var result: Array=[]
	for start in starts:
		if seen[start]: continue
		var code:=codes[start]
		var cells:=PackedInt32Array([start]);seen[start]=1
		var cursor:=0
		while cursor<cells.size():
			var at:=cells[cursor];cursor+=1
			var column:=at%width
			if column>0 and not seen[at-1] and codes[at-1]==code: seen[at-1]=1;cells.append(at-1)
			if column<width-1 and not seen[at+1] and codes[at+1]==code: seen[at+1]=1;cells.append(at+1)
			if at>=width and not seen[at-width] and codes[at-width]==code: seen[at-width]=1;cells.append(at-width)
			if at+width<count and not seen[at+width] and codes[at+width]==code: seen[at+width]=1;cells.append(at+width)
		result.append(cells)
	return result

# The same unique cardinal components as _components, labelled once per
# horizontal run. Each run's root is its component's first run in scan order.
static func _run_components(codes: PackedInt32Array, width: int) -> Dictionary:
	var starts:=PackedInt32Array();var lengths:=PackedInt32Array();var parent:=PackedInt32Array()
	var above:=0
	for row in range(0,codes.size(),width):
		var first:=starts.size()
		var x:=0
		while x<width:
			var code:=codes[row+x]
			var end:=x+1
			while end<width and codes[row+end]==code: end+=1
			var run:=starts.size()
			starts.append(row+x);lengths.append(end-x);parent.append(run)
			# Join every same-class run of the row above that shares a column.
			while above<first and starts[above]-row+width+lengths[above]<=x: above+=1
			var q:=above
			while q<first and starts[q]-row+width<end:
				if codes[starts[q]]==code:
					var a:=q
					while parent[a]!=a: parent[a]=parent[parent[a]];a=parent[a]
					var b:=run
					while parent[b]!=b: parent[b]=parent[parent[b]];b=parent[b]
					if a<b: parent[b]=a
					elif b<a: parent[a]=b
				q+=1
			x=end
		above=first
	var sizes:=PackedInt32Array();sizes.resize(starts.size())
	for run in starts.size():
		var a:=run
		while parent[a]!=a: a=parent[a]
		parent[run]=a
		sizes[a]+=lengths[run]
	return {"starts":starts,"lengths":lengths,"roots":parent,"sizes":sizes}

static func surface_image(terrain: Image, local: bool) -> Image:
	var width:=terrain.get_width()
	var height:=terrain.get_height()
	var data:=terrain.get_data()
	var codes:=_words(terrain)
	var pattern:=PackedInt32Array();pattern.resize(codes.size());pattern.fill(UNMARKED)
	var recipes:={_word(EARTH_DARK):EARTH_DARK,_word(EARTH_LIGHT):EARTH_LIGHT}
	if local:
		# Match complete 2x2 periods at the original screen phase (origin16,63).
		# A whole recognition window must avoid the protected player stencil.
		# Every period holds one brown cell per row at odd phase, so only windows
		# beside such a top-row cell are candidates.
		var brown:=_word(0xaa5500)
		var black:=_word(0x000000)
		var gray:=_word(0x555555)
		var marked:=PackedInt32Array()
		for y in height-1:
			var row:=y*width
			var at:=codes.find(brown,row)
			while at>=0 and at<row+width:
				var bx:=at-row
				at=codes.find(brown,at+1)
				if (bx+y+63)%2==0: continue
				for x in range(maxi(bx-1,0),mini(bx,width-2)+1):
					var i0:=row+x
					var i1:=i0+1
					var i2:=i0+width
					var i3:=i2+1
					var odd:=(x+y+63)%2==1
					var alternate:=codes[i1 if odd else i0]
					if alternate!=black and alternate!=gray: continue
					var top:=(codes[i0]==brown) if odd else (codes[i1]==brown)
					if not top or codes[i2]!=(alternate if odd else brown) or codes[i3]!=(brown if odd else alternate): continue
					if data[i0*4+3]==0 or data[i1*4+3]==0 or data[i2*4+3]==0 or data[i3*4+3]==0: continue
					var recipe:=_word(EARTH_DARK) if alternate==black else _word(EARTH_LIGHT)
					for cell in [i0,i1,i2,i3]:
						if pattern[cell]==UNMARKED: pattern[cell]=recipe;marked.append(cell)
						elif pattern[cell]!=recipe: pattern[cell]=AMBIGUOUS # Overlap keeps source ink.
		# Unique cardinally connected coverage, never a count of overlapping tiles.
		# Tiny or incomplete patterned marks keep their original source ink.
		var seeds:=PackedInt32Array()
		for cell in marked:
			if pattern[cell]!=AMBIGUOUS: seeds.append(cell)
		if not seeds.is_empty():
			for cells in _components(pattern,width,seeds):
				if cells.size()<16: continue
				var rgb: int=recipes[pattern[cells[0]]]
				for at in cells:
					codes[at]=pattern[at]
					data[at*4]=(rgb>>16)&255;data[at*4+1]=(rgb>>8)&255;data[at*4+2]=rgb&255
	# Unknown colours and small components are exact nearest-source patches.
	# Large regions retain a finite source-cell core in the contour shader.
	var surfaces: Array=[]
	for surface in SURFACES: surfaces.append(_word(surface))
	var labelled:=_run_components(codes,width)
	var starts: PackedInt32Array=labelled.starts
	var lengths: PackedInt32Array=labelled.lengths
	var roots: PackedInt32Array=labelled.roots
	var sizes: PackedInt32Array=labelled.sizes
	for run in starts.size():
		var root:=roots[run]
		var first:=starts[root]
		var supported: bool=codes[first] in surfaces or (local and pattern[first]==codes[first])
		if supported and sizes[root]>=8: continue
		for at in range(starts[run],starts[run]+lengths[run]): data[at*4+3]=0
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
		var styled: Image=_surface_cache.get(key)
		if styled==null:
			styled=surface_image(terrain,int(item.mode)==1)
			surface_build_count+=1
			_surface_cache[key]=styled
			if _surface_order.size()>=SURFACE_CACHE_SIZE: _surface_cache.erase(_surface_order.pop_front())
		else: _surface_order.erase(key)
		_surface_order.append(key)
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
	in_place=false
	picture.hide()
	proof.clear()
	queue_redraw()

# The tandem frame proves the same map for its own restored layer. Reuse that
# proof only for this exact packet, page and source crop; otherwise prove here.
func _proved_map(frame: Control) -> Dictionary:
	var source: Image=frame._cached_source
	var item=frame._cached_presentation.get("dynamic_map")
	var shared: Dictionary=frame.dynamic_map_art.packet
	if not shared.is_empty() and item is Dictionary and source!=null and source.get_size()==Vector2i(320,200) \
			and shared.recursive_equal(item,8) and shared.get("page_offset")==frame._cached_presentation.get("page_offset"):
		var crop:=source.get_region(Proof.MAP_RECT);crop.convert(Image.FORMAT_RGB8)
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(crop.get_data())
		if hash.finish().hex_encode()==shared.get("pixel_sha256"):
			proof_reuse_count+=1
			return shared
	if not proof.set_frame(source,frame._cached_presentation): return {}
	proof.hide()
	return proof.packet

func set_frame(frame: Control, layout: Dictionary, ui: PackedByteArray=PackedByteArray()) -> bool:
	clear()
	if not frame.world_enabled: return false
	var item: Dictionary=_proved_map(frame)
	if item.is_empty(): return false
	if layout.get("in_place",false):
		if ui.size()!=64000: return false
		var mask:=Image.create_from_data(320,200,false,Image.FORMAT_L8,ui)
		if mask.get_region(Proof.MAP_RECT).get_data().count(255)!=144*96: return false
		in_place=true
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
	if in_place: map_box=Rect2(Vector2(16,63)/Vector2(320,200)*Vector2(1600,900),Vector2(144,96)/Vector2(320,200)*Vector2(1600,900))
	packet=item.duplicate(true)
	_place()
	picture.show()
	queue_redraw()
	return true

func _place() -> void:
	# The existing reflow includes a one-source-pixel surround on every side.
	var factor:=size/Vector2(1600,900)
	var inset:=Vector2.ZERO if in_place else map_box.size/Vector2(146,98)
	picture.position=(map_box.position+inset)*factor
	picture.size=(map_box.size-inset*2)*factor
	queue_redraw()

func _mode_layout(mode: String, scale: float) -> Dictionary:
	var point:=clampi(ceili(11.0/maxf(scale,0.01)),16,23)
	var key_point:=maxi(9,point-2)
	var key_width:=font.get_string_size("Z",HORIZONTAL_ALIGNMENT_LEFT,-1,key_point).x+10
	var label_width:=font.get_string_size(mode,HORIZONTAL_ALIGNMENT_LEFT,-1,point).x
	var at:=Vector2(map_box.end.x-key_width-8-label_width,map_box.position.y-16)
	return {"point":point,"key_point":key_point,"key":Rect2(at.x,at.y-point-1,key_width,point+5),
		"key_at":at+Vector2(5,0),"label_at":at+Vector2(key_width+8,0),"label_width":label_width}

func _border_stroke(scale: float) -> float:
	return maxf(1,1.0/maxf(scale,0.01))

func _draw() -> void:
	if packet.is_empty() or in_place: return
	draw_set_transform(Vector2.ZERO,0,size/Vector2(1600,900))
	var scale:=maxf(0.01,minf(size.x/1600.0,size.y/900.0))
	FieldPanel.recess(self,map_box,scale)
	var mode: String="LOCAL" if int(packet.mode)==1 else "OVERVIEW"
	var label:=_mode_layout(mode,scale)
	draw_rect(Rect2(label.key.position-Vector2(4,0),Vector2(map_box.end.x-label.key.position.x+8,label.key.size.y)),Color("101510"))
	draw_rect(label.key,Color("101e16"))
	draw_rect(label.key,Color("61785b"),false,maxf(1,1.0/scale),true)
	draw_string(font,label.key_at,"Z",HORIZONTAL_ALIGNMENT_LEFT,-1,label.key_point,Color("e7b566"))
	draw_string(font,label.label_at,mode,HORIZONTAL_ALIGNMENT_LEFT,-1,label.point,Color("c1ccba"))
