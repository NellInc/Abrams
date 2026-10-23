extends Control
## Full original-frame identity controls these static presentation plates.
## Original PC code retains scene selection, duration, transition and input.
const CATALOG_SHA := "7b5384a974959aded00990135682599c69e00f27ed629a0405c04f32211f6f6f"
var entries: Dictionary = {}
var textures: Dictionary = {}
var native_images: Dictionary = {}
var active: Dictionary = {}
var motion_enabled := true
var smoke_phase := 0.0
var _motion_scene := ""
var _smoke := ShaderMaterial.new()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(queue_redraw)
	_smoke.shader = preload("res://scripts/pc_ending_smoke.gdshader")
	material = _smoke
	clear()

func clear() -> void:
	active.clear()
	visible = false
	queue_redraw()

func load_sources(root: String) -> bool:
	clear(); reset_motion(); entries.clear(); textures.clear(); native_images.clear()
	var path := root.path_join("local-art/pc-splash-aftermath-v1/catalog.json")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != CATALOG_SHA: return false
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var found := {}; var art := {}; var native := {}
	for row in data.entries:
		path = root.path_join("GAME/" + row.source)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != row.source_sha256: return false
		for field in ["asset", "native_asset"]:
			if not row.has(field): continue
			var asset: Dictionary = row[field]
			path = root.path_join(asset.path)
			if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != asset.sha256:
				if field=="native_asset": continue
				return false
			var image := Image.load_from_file(path)
			if image == null or image.get_size() != Vector2i(asset.size[0],asset.size[1]):
				if field=="native_asset": continue
				return false
			if field == "asset": art[row.name] = ImageTexture.create_from_image(image)
			else:
				image.convert(Image.FORMAT_RGB8)
				native[row.name] = image
		found[row.rgb_sha256] = row
	entries = found; textures = art; native_images = native
	return not entries.is_empty()

func match_frame(source: Image, program: Dictionary) -> Dictionary:
	if source == null or source.get_size() != Vector2i(320,200) or source.get_format() != Image.FORMAT_RGB8: return {}
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256); hash.update(source.get_data())
	var key := hash.finish().hex_encode()
	if not entries.has(key) or entries[key].program != program.get("name", ""): return {}
	return entries[key]

func native_frame(source: Image, program: Dictionary) -> Image:
	var row := match_frame(source,program)
	if row.is_empty() or not native_images.has(row.name): return source
	return native_images[row.name]

func set_frame(source: Image, program: Dictionary) -> bool:
	clear()
	var row := match_frame(source,program)
	if row.is_empty():
		reset_motion()
		return false
	active = row.duplicate(true)
	if _motion_scene != row.name:
		reset_motion()
		_motion_scene = row.name
	_smoke.set_shader_parameter("scene_index",1 if row.name=="scene1" else (2 if row.name=="scene2" else 0))
	_smoke.set_shader_parameter("smoke_phase",smoke_phase if motion_enabled else 0.0)
	visible = true
	queue_redraw()
	return true

func reset_motion() -> void:
	smoke_phase = 0.0
	_motion_scene = ""
	_smoke.set_shader_parameter("smoke_phase",0.0)

func advance(delta: float) -> bool:
	if not motion_enabled or not visible or active.get("name","") not in ["scene1","scene2"]: return false
	smoke_phase = fmod(smoke_phase+clampf(delta,0.0,0.1)*0.8,TAU*10.0)
	_smoke.set_shader_parameter("smoke_phase",smoke_phase)
	queue_redraw()
	return true

static func rect(value: Array) -> Rect2:
	return Rect2(value[0],value[1],value[2],value[3])

func _draw() -> void:
	if active.is_empty(): return
	draw_set_transform(Vector2.ZERO,0,size/Vector2(320,200))
	draw_rect(Rect2(0,0,320,200),Color.BLACK)
	draw_texture_rect_region(textures[active.name],rect(active.rect),rect(active.source_rect))
