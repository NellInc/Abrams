extends Control
## Genesis illustrations over complete verified original START information pages.
## Original contents, page order and navigation stay PC-owned. Full-page crew art
## additionally requires the complete frame, including its otherwise variable footer.
const CATALOG_SHA := "835ef4cc94a560f35a3ba74a928e39a533833300866c6b8692ffd12de8d0b203"
const COMPLETION_SHA := "65da8be43af5d62ff6fd77e374393c6621effacea556ad02e120a4f80e35c769"
var caption_text_enabled := true
var caption_fonts: Dictionary = {}
var catalog: Dictionary = {}
var textures: Dictionary = {}
var active: Dictionary = {}
var overlays: Dictionary = {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(queue_redraw)
	clear()

func clear() -> void:
	active.clear()
	visible = false
	queue_redraw()

func load_sources(root_path: String) -> bool:
	clear(); catalog.clear(); textures.clear(); overlays.clear(); caption_fonts.clear()
	var path := root_path.path_join("local-art/pc-information-v3/information.json")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=CATALOG_SHA: return false
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for name in data.sources:
		path = root_path.path_join("GAME/"+name)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=data.sources[name]: return false
	var loaded := {}
	for entry in data.entries:
		for item in entry.get("layers",[entry]):
			path = root_path.path_join("local-art/genesis/remastered/"+item.art)
			if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=item.art_sha256: return false
			var image := Image.load_from_file(path)
			if image==null or image.get_size()!=Vector2i(item.size[0],item.size[1]): return false
			loaded[item.name] = ImageTexture.create_from_image(image)
		var items := []
		for overlay in entry.get("overlays",[]):
			items.append({"mesh":span_mesh(overlay.rects),"colour":Color8(overlay.rgb[0],overlay.rgb[1],overlay.rgb[2])})
		overlays[entry.name]=items
	if not load_completion(root_path,data,loaded):
		overlays.clear()
		return false
	catalog = data; textures = loaded
	return true

func load_completion(root_path: String, data: Dictionary, loaded: Dictionary) -> bool:
	# The supplement adds only independently source-checked diagram rectangles.
	# It cannot introduce another page identity or broaden the recognition gate.
	var path := root_path.path_join("local-art/pc-information-completion-v1/information.json")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=COMPLETION_SHA: return false
	var supplement: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	for item in supplement.entries:
		var matches: Array=data.entries.filter(func(e):return e.name==item.name and e.rgb_sha256==item.rgb_sha256)
		if matches.size()!=1: return false
		var layer: Dictionary=item.layer
		path=root_path.path_join("local-art/genesis/remastered/"+layer.art)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=layer.art_sha256: return false
		var image:=Image.load_from_file(path)
		if image==null or image.get_size()!=Vector2i(layer.size[0],layer.size[1]): return false
		loaded[layer.name]=ImageTexture.create_from_image(image)
		matches[0].layers=[matches[0].duplicate(true),layer]
	for frame in supplement.frames:
		var matches: Array=data.entries.filter(func(e):return e.name==frame.name and e.rgb_sha256==frame.rgb_sha256)
		if matches.size()!=1: return false
		matches[0].page_frame=frame
	for caption in supplement.crew_captions+supplement.overhead_captions:
		path=root_path.path_join("local-art/genesis/remastered/"+caption.art)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=caption.art_sha256: return false
		var font:=FontFile.new()
		font.data=FileAccess.get_file_as_bytes(path)
		font.antialiasing=TextServer.FONT_ANTIALIASING_GRAY
		font.hinting=TextServer.HINTING_NONE
		font.subpixel_positioning=TextServer.SUBPIXEL_POSITIONING_DISABLED
		caption_fonts[caption.art_sha256]=font
	for entry in data.entries:
		if entry.name=="crew":
			entry.captions=supplement.crew_captions
			entry.observed_full_rgb_sha256=supplement.crew_frames.full_rgb_sha256
		else: entry.captions=supplement.overhead_captions.filter(func(c):return c.page==entry.name)
	return true

func set_frame(source: Image, program: Dictionary) -> bool:
	clear()
	if catalog.is_empty() or program.get("name")!="START": return false
	if source==null or source.get_size()!=Vector2i(320,200) or source.get_format()!=Image.FORMAT_RGB8: return false
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(source.get_data().slice(0,320*int(catalog.recognition_height)*3))
	var fingerprint := hash.finish().hex_encode()
	var matches: Array = catalog.entries.filter(func(e):return e.rgb_sha256==fingerprint)
	if matches.size()!=1: return false
	if matches[0].has("full_rgb_sha256"):
		hash.start(HashingContext.HASH_SHA256); hash.update(source.get_data())
		if hash.finish().hex_encode() not in matches[0].get("observed_full_rgb_sha256",[matches[0].full_rgb_sha256]): return false
	active = matches[0].duplicate(true)
	if active.has("page_frame"):
		active.frame_rects=active.page_frame.rects.duplicate(true)
		hash.start(HashingContext.HASH_SHA256)
		hash.update(source.get_data().slice(320*175*3))
		if hash.finish().hex_encode() in active.page_frame.footer_sha256:
			active.frame_rects.append(active.page_frame.footer_rect)
	visible = true
	queue_redraw()
	return true

func art_rect() -> Rect2:
	if active.is_empty(): return Rect2()
	var r: Array = active.rect
	return Rect2(r[0],r[1],r[2],r[3])

func layer_rect(item: Dictionary) -> Rect2:
	var r: Array=item.rect
	return Rect2(r[0],r[1],r[2],r[3])

func donor_rect(item: Dictionary={}) -> Rect2:
	if item.is_empty(): item=active
	if item.is_empty(): return Rect2()
	if item.has("source_rect"):
		var r: Array=item.source_rect
		return Rect2(r[0],r[1],r[2],r[3])
	var dimensions: Vector2 = textures[item.name].get_size()
	if item.get("fit")=="stretch": return Rect2(Vector2.ZERO,dimensions)
	var destination := layer_rect(item).grow(-1)
	var height := dimensions.x*destination.size.y/destination.size.x
	if height<=dimensions.y:
		return Rect2(0,(dimensions.y-height)/2,dimensions.x,height)
	var width := dimensions.y*destination.size.x/destination.size.y
	return Rect2((dimensions.x-width)/2,0,width,dimensions.y)

static func span_mesh(rectangles: Array) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for r in rectangles:
		var x:=float(r[0]); var y:=float(r[1]); var right:=x+float(r[2]); var bottom:=y+float(r[3])
		var start:=vertices.size()
		vertices.append_array(PackedVector3Array([Vector3(x,y,0),Vector3(right,y,0),Vector3(right,bottom,0),Vector3(x,bottom,0)]))
		indices.append_array(PackedInt32Array([start,start+1,start+2,start,start+2,start+3]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func _draw() -> void:
	if active.is_empty(): return
	draw_set_transform(Vector2.ZERO,0,size/Vector2(320,200))
	for r in active.get("frame_rects",[]):
		draw_rect(Rect2(r[0],r[1],r[2],r[3]),Color.BLACK)
	if active.has("background_rgb"):
		var rgb: Array=active.background_rgb
		draw_rect(art_rect(),Color8(rgb[0],rgb[1],rgb[2]))
	for item in active.get("layers",[active]):
		var target:=layer_rect(item)
		var rgb=item.get("frame_rgb",[238,68,65])
		if rgb!=null:
			draw_rect(target,Color8(rgb[0],rgb[1],rgb[2]));target=target.grow(-1)
		draw_texture_rect_region(textures[item.name],target,donor_rect(item))
	for overlay in overlays[active.name]:
		draw_mesh(overlay.mesh,null,Transform2D.IDENTITY,overlay.colour)
	for caption in active.get("captions",[]):
		if not caption_text_enabled and not caption.has("original_mask"): continue
		var r: Array=caption.rect
		var c: Array=caption.get("clear_rect",r)
		var fg: Array=caption.foreground; var bg: Array=caption.background
		draw_set_transform(Vector2.ZERO,0,size/Vector2(320,200))
		draw_rect(Rect2(c[0],c[1],c[2],c[3]),Color8(bg[0],bg[1],bg[2]))
		if not caption_text_enabled:
			# Original mode deliberately retains each PC source caption cell.
			var original: Array=caption.original_rect
			for i in caption.original_mask.size():
				if caption.original_mask[i]:
					draw_rect(Rect2(original[0]+i%int(original[2]),original[1]+i/int(original[2]),1,1),Color8(fg[0],fg[1],fg[2]))
			continue
		# Native vector contours follow the source caption, not a substitute face.
		var box:=Rect2(Vector2(r[0],r[1])*size/Vector2(320,200),Vector2(r[2],r[3])*size/Vector2(320,200))
		draw_set_transform(Vector2.ZERO)
		preload("res://scripts/pc_outline_fonts.gd").draw_text(self,caption_fonts[caption.art_sha256],caption.glyph,box,Vector2(r[2],r[3]),Color8(fg[0],fg[1],fg[2]))
