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
const MOTOR_CATALOG_SHA := "a34ebc4d9a81d48c58c34024845b03c2362555f2d818040578cceeed3e3f5c7e"
const MOTOR_ART_SHA := "3fb46798b867ca528f96e8bc0a70d6f3a9e7a1016ca87f3e8549562469019c76"
const MOTOR_PALETTE = [[0,0,0],[255,255,255],[170,170,170],[85,85,85],[85,85,255],[85,255,255],
	[170,0,0],[170,85,0],[0,170,0],[85,255,85],[255,255,85],[0,0,0],[255,85,85],[0,0,170],[85,255,255],[255,255,255]]
var motor_catalog: Dictionary = {}
var motor_indices := PackedByteArray()
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
	material.set_shader_parameter("motor_enabled",false)

func load_sources(root_path: String) -> bool:
	clear()
	catalog.clear()
	portraits.clear()
	_load_motor_pool(root_path)
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

func _load_motor_pool(root_path: String) -> void:
	motor_catalog.clear()
	motor_indices.clear()
	var path := root_path.path_join("local-art/pc-motor-pool-v1/motor-pool.json")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=MOTOR_CATALOG_SHA: return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	path=root_path.path_join("GAME/ATBASE.BIN")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=data.source_sha256: return
	path=root_path.path_join("local-art/genesis/remastered/motor-pool-v2.png")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=MOTOR_ART_SHA: return
	var image := Image.load_from_file(path)
	if image==null or image.get_size()!=Vector2i(1586,992): return
	material.set_shader_parameter("motor_pool",ImageTexture.create_from_image(image))
	var packed := Marshalls.base64_to_raw(data.packed_indices_base64)
	if packed.size()!=32000: return
	for byte in packed:
		motor_indices.append(byte>>4)
		motor_indices.append(byte&15)
	motor_catalog=data

func _set_motor_pool(source: Image, presentation: Dictionary) -> bool:
	if motor_catalog.is_empty(): return false
	var overlay = presentation.get("plate_overlay")
	var ui = presentation.get("ui_overlay")
	var palette = presentation.get("palette_rgb")
	if not overlay is Dictionary or not ui is Dictionary or not palette is Array or palette.size()!=16: return false
	for i in 16:
		if not palette[i] is Array or palette[i].size()!=3: return false
		for c in 3:
			if palette[i][c]!=MOTOR_PALETTE[i][c]: return false
	if overlay.get("width")!=320 or overlay.get("height")!=200: return false
	if ui.get("width")!=320 or ui.get("height")!=200: return false
	var plates = overlay.get("plates")
	if not plates is Dictionary: return false
	var donor = plates.get("8")
	if not donor is Dictionary or donor.get("source")!="ATBASE.BIN" or donor.get("source_sha256")!=motor_catalog.source_sha256: return false
	# Most SIM frames are combat, not this frontend. Avoid decoding two full
	# PNG masks and scanning 64,000 pixels when the background is absent.
	var claimed = donor.get("pixels")
	if not (claimed is int or claimed is float) or claimed<=0 or claimed>64000: return false
	var mask := Image.new()
	var original_ui := Image.new()
	if not overlay.get("mask_png") is String or not ui.get("mask_png") is String: return false
	if mask.load_png_from_buffer(Marshalls.base64_to_raw(overlay.mask_png))!=OK: return false
	if original_ui.load_png_from_buffer(Marshalls.base64_to_raw(ui.mask_png))!=OK: return false
	if mask.get_size()!=Vector2i(320,200) or original_ui.get_size()!=mask.get_size(): return false
	if mask.get_format()!=Image.FORMAT_L8 or original_ui.get_format()!=Image.FORMAT_L8: return false
	var tags := mask.get_data()
	var bits := original_ui.get_data()
	var rgb := source.get_data()
	var count := 0
	for at in 64000:
		if tags[at]>8 or (tags[at]!=0 and bits[at]!=255): return false
		if tags[at]!=8: continue
		var colour = palette[motor_indices[at]]
		if not colour is Array or colour.size()!=3: return false
		for c in 3:
			if rgb[at*3+c]!=colour[c]: return false
		count+=1
	if count==0 or donor.get("pixels")!=count: return false
	texture=ImageTexture.create_from_image(source)
	material.set_shader_parameter("motor_mask",ImageTexture.create_from_image(mask))
	material.set_shader_parameter("motor_enabled",true)
	active={"scene":"motor_pool","name":"Genesis motor pool","pixels":count}
	if text_enabled: typography.set_motor_pool_menu(source,original_ui,mask)
	visible=true
	return true

func set_frame(source: Image, program: Dictionary, presentation: Dictionary={}) -> bool:
	clear()
	if source==null or source.get_size()!=Vector2i(320,200): return false
	if source.get_format()!=Image.FORMAT_RGB8: return false
	if program.get("name")=="SIM": return _set_motor_pool(source,presentation)
	if catalog.is_empty() or program.get("name") not in ["BRIEF","END"]: return false
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
