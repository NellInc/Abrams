extends Control
## Genesis illustrations over complete verified original START information pages.
## Original contents, page order and navigation stay PC-owned. Full-page crew art
## additionally requires the complete frame, including its otherwise variable footer.
const CATALOG_SHA := "9a8881ef013cf4f2d7d2352a6c0e4d082ff302c58267219db24212bfd88884e0"
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
	clear(); catalog.clear(); textures.clear(); overlays.clear()
	var path := root_path.path_join("local-art/pc-information-v2/information.json")
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
	catalog = data; textures = loaded
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
		if hash.finish().hex_encode()!=matches[0].full_rgb_sha256: return false
	active = matches[0].duplicate(true)
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
