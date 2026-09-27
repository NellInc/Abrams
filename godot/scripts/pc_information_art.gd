extends Control
## Genesis illustrations over complete verified original START information pages.
## Text, values, page order, navigation and the variable bottom border stay PC-owned.
const CATALOG_SHA := "715ffe8b7b28e85ef83d50cf0254562f6fb6a2b0f9c83ef1a139ab0b10cc47ab"
var catalog: Dictionary = {}
var textures: Dictionary = {}
var active: Dictionary = {}

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
	clear(); catalog.clear(); textures.clear()
	var path := root_path.path_join("local-art/pc-information-v1/information.json")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=CATALOG_SHA: return false
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for name in data.sources:
		path = root_path.path_join("GAME/"+name)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=data.sources[name]: return false
	var loaded := {}
	for item in data.entries:
		path = root_path.path_join("local-art/genesis/remastered/"+item.art)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=item.art_sha256: return false
		var image := Image.load_from_file(path)
		if image==null or image.get_size()!=Vector2i(item.size[0],item.size[1]): return false
		loaded[item.name] = ImageTexture.create_from_image(image)
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
	active = matches[0].duplicate(true)
	visible = true
	queue_redraw()
	return true

func art_rect() -> Rect2:
	if active.is_empty(): return Rect2()
	var r: Array = active.rect
	return Rect2(r[0],r[1],r[2],r[3])

func donor_rect() -> Rect2:
	if active.is_empty(): return Rect2()
	var dimensions: Vector2 = textures[active.name].get_size()
	var destination := art_rect().grow(-1)
	var height := dimensions.x*destination.size.y/destination.size.x
	if height<=dimensions.y:
		return Rect2(0,(dimensions.y-height)/2,dimensions.x,height)
	var width := dimensions.y*destination.size.x/destination.size.y
	return Rect2((dimensions.x-width)/2,0,width,dimensions.y)

func _draw() -> void:
	if active.is_empty(): return
	draw_set_transform(Vector2.ZERO,0,size/Vector2(320,200))
	# Genesis page frame colour; original text outside the illustration is untouched.
	draw_rect(art_rect(),Color8(238,68,65))
	draw_texture_rect_region(textures[active.name],art_rect().grow(-1),donor_rect())
