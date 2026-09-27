extends TextureRect
## Whole-region source matches protect original dialogue and unknown transitions.
const CATALOG_SHA := "87cf126af7520262c54a2fd2e4d8b6ede201e9046e0554657beeec41c46cef5d"
const ART := [
	["office-background-v1.png","6aebd32959fca4eb45dca58bc16532b2df1e5d85634a997f46cff8b8695b628c",Vector2i(1586,992)],
	["wilson-v1.png","82d31f8db905605a772ff6aa564a20dc7dc385433e2abacfe92b506511a4e2a9",Vector2i(1293,1217)],
	["wilson-gesture-v2.png","9a433788ab13858718794eb8617d240f2e6a3b94887bb0cfb997f451f5889e81",Vector2i(1294,1216)],
	["wilson-facepalm-v1.png","11a3b80e2cd92d39c5c6193c4d8534d0f0274243c99dc3dbdb5a91fc8a7209c9",Vector2i(1293,1217)]
]
var catalog: Dictionary = {}
var portraits: Array[Texture2D] = []
var active: Dictionary = {}
var text_enabled := true
var typography = preload("res://scripts/pc_typography.gd").new()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var effect := ShaderMaterial.new()
	effect.shader = preload("res://scripts/pc_frontend_art.gdshader")
	material = effect
	add_child(typography)
	typography.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clear()

func clear() -> void:
	active.clear()
	typography.clear_runs()
	visible = false
	material.set_shader_parameter("restored_height",0.0)

func load_sources(root_path: String) -> bool:
	clear()
	catalog.clear()
	portraits.clear()
	var path := root_path.path_join("local-art/pc-frontend-v1/office.json")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=CATALOG_SHA: return false
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for source in data.sources:
		var original := root_path.path_join("GAME/"+source)
		if not FileAccess.file_exists(original) or FileAccess.get_sha256(original)!=data.sources[source]: return false
	var textures: Array[Texture2D] = []
	for entry in ART:
		path = root_path.path_join("local-art/genesis/remastered/"+entry[0])
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=entry[1]: return false
		var image := Image.load_from_file(path)
		if image==null or image.get_size()!=entry[2]: return false
		textures.append(ImageTexture.create_from_image(image))
	material.set_shader_parameter("office",textures[0])
	portraits.assign(textures.slice(1))
	catalog = data
	typography.load_sources(root_path.path_join("GAME"))
	return true

func panel_border(source: Image, y: int) -> bool:
	if y==200: return true
	# Complete white top border plus blue interior corners, as drawn by the
	# original dialogue box. The art shader preserves this row and all rows
	# below it; separately verified typography may redraw complete glyph lines.
	for x in 320:
		if source.get_pixel(x,y).to_rgba32()!=0xffffffff: return false
	return source.get_pixel(1,y+1).to_rgba32()==0x5555ffff and source.get_pixel(318,y+1).to_rgba32()==0x5555ffff

func set_frame(source: Image, program: Dictionary) -> bool:
	clear()
	if catalog.is_empty() or source==null or source.get_size()!=Vector2i(320,200): return false
	if program.get("name") not in ["BRIEF","END"]: return false
	if source.get_format()!=Image.FORMAT_RGB8: return false
	var bytes := source.get_data()
	for height in catalog.heights:
		var h := int(height)
		if not panel_border(source,h): continue
		var hasher := HashingContext.new()
		hasher.start(HashingContext.HASH_SHA256)
		hasher.update(bytes.slice(0,320*h*3))
		var hash := hasher.finish().hex_encode()
		var matches: Array = catalog.templates.filter(func(t):return t.hashes[str(h)]==hash)
		if matches.size()!=1: continue
		var item: Dictionary = matches[0]
		active = {"scene":"office","pose":int(item.pose),"name":item.name,"height":h}
		texture = ImageTexture.create_from_image(source)
		material.set_shader_parameter("portrait",portraits[int(item.pose)])
		var r: Array = item.portrait_rect
		material.set_shader_parameter("portrait_rect",Vector4(r[0],r[1],r[2],r[3]))
		material.set_shader_parameter("restored_height",float(h))
		if text_enabled: typography.set_office_dialogue(source,h)
		visible = true
		return true
	return false
