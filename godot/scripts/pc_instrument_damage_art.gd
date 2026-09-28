extends Control
## Original visible STATUS pixels select one of 32 proved damage combinations.
## No RAM state or source image approximation can reveal a hidden condition.
const MANIFEST_SHA256 = "6ee3afc545bb75c91e8ff1e24f4410f238b337f98834905327e672be185d22d9"
const PATCH_SIZES = [[1122, 1402], [2172, 724], [2048, 768], [1161, 1355], [1774, 887]]
const SOURCE_HASHES = {"STATUS.BIN": "7d2abcfd40a79002087bd1534c9ac74ba846dd1cbf03b93f3f66314068b62166", "DAMAGE.BMP": "765a4b564fad3865e564427b957cbee2cb0b5695a878b63e3c07c141bbb68cdc", "SIM.EXE": "9ee5a5898ddcb8192d30b4083981419515eb3ca220e6cbcd214df628bb164099"}
const BOX = Rect2i(123,37,184,63)
const DRAW_BOX = Rect2(123,37,182,63)
const ORIGINS = [Vector2(176,32),Vector2(200,16),Vector2(208,56),Vector2(256,24),Vector2(136,40)]
const EXTENTS = [Vector2(32,40),Vector2(72,24),Vector2(64,24),Vector2(48,56),Vector2(32,16)]
var catalog: Array = []
var patches: Array[Texture2D] = []
var patch_nodes: Array[TextureRect] = []
var clipper := Control.new()
var caption_font: FontFile
var pristine: Texture2D
var state := -1

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(queue_redraw)
	resized.connect(_layout)
	clipper.clip_contents = true
	clipper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clipper)

func clear() -> void:
	state = -1
	_layout()
	queue_redraw()

func load_sources(root: String) -> bool:
	clear()
	catalog.clear()
	patches.clear()
	for node in patch_nodes: node.queue_free()
	patch_nodes.clear()
	pristine = null
	caption_font = null
	var directory := root.path_join("local-art/genesis/status-damage-v1")
	var manifest_path := directory.path_join("manifest.json")
	if not FileAccess.file_exists(manifest_path) or FileAccess.get_sha256(manifest_path)!=MANIFEST_SHA256: return false
	for name in SOURCE_HASHES:
		var path := root.path_join("GAME/"+name)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=SOURCE_HASHES[name]: return false
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary or manifest.get("states",[]).size()!=32: return false
	var states: Array = manifest.states
	var seen: Dictionary = {}
	for entry in states:
		if not entry is Dictionary or not entry.get("bits") is float: return false
		var bits := int(entry.bits)
		if bits<0 or bits>31 or bits!=entry.bits or seen.has(bits): return false
		for key in ["rgb_sha256","tags_sha256"]:
			if not entry.get(key) is String or entry[key].length()!=64 or not entry[key].is_valid_hex_number(false): return false
		seen[bits]=true
	if not manifest.get("assets") is Array or manifest.assets.size()!=5: return false
	for entry in manifest.assets:
		var path: String = directory.path_join(entry.file)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=entry.sha256: return false
		var img := Image.load_from_file(path)
		var dimensions: Array=PATCH_SIZES[patches.size()]
		if img==null or img.get_size()!=Vector2i(dimensions[0],dimensions[1]): return false
		patches.append(ImageTexture.create_from_image(img))
	if patches.size()!=5: return false
	var base := root.path_join("local-art/genesis/cockpit-v2/systems-status-genesis-v1.png")
	if FileAccess.get_sha256(base)!=manifest.pristine_sha256: return false
	pristine = ImageTexture.create_from_image(Image.load_from_file(base))
	if not manifest.get("masks") is Array or manifest.masks.size()!=5: return false
	for i in 5:
		var entry: Dictionary = manifest.masks[i]
		var path: String = directory.path_join(entry.file)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=entry.sha256: return false
		var mask := Image.load_from_file(path)
		if mask==null or mask.get_size()!=Vector2i(EXTENTS[i]): return false
		var node := TextureRect.new()
		node.texture = patches[i]
		node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader_material := ShaderMaterial.new()
		shader_material.shader = preload("res://scripts/pc_instrument_damage_art.gdshader")
		shader_material.set_shader_parameter("changed_pixels",ImageTexture.create_from_image(mask))
		node.material = shader_material
		clipper.add_child(node)
		patch_nodes.append(node)
	var font_path := root.path_join("local-art/genesis/remastered/information-completion-v1/overhead-m1a1-caption-v1.ttf")
	if not FileAccess.file_exists(font_path) or FileAccess.get_sha256(font_path)!="321aaa970f3255c1e232ba7c252aa1d0bcdd6dabf66ba07d4fd90cc47c2d1170": return false
	caption_font = FontFile.new()
	caption_font.data = FileAccess.get_file_as_bytes(font_path)
	caption_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	caption_font.hinting = TextServer.HINTING_NONE
	caption_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	catalog = manifest.states
	_layout()
	return true

func set_frame(source: Image, ui: Image, tags: Image) -> void:
	clear()
	if pristine==null or catalog.size()!=32: return
	for img in [source,ui,tags]:
		if img==null or img.get_size()!=Vector2i(320,200): return
	if ui.get_format() in [Image.FORMAT_L8,Image.FORMAT_R8]:
		if ui.get_region(BOX).get_data().count(255)!=BOX.size.x*BOX.size.y: return
	else:
		for y in range(BOX.position.y,BOX.end.y):
			for x in range(BOX.position.x,BOX.end.x):
				if ui.get_pixel(x,y).r!=1.0: return
	var rgb := source.get_region(BOX)
	rgb.convert(Image.FORMAT_RGB8)
	var tag := tags.get_region(BOX)
	tag.convert(Image.FORMAT_R8)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(rgb.get_data())
	var rgb_hash := context.finish().hex_encode()
	context.start(HashingContext.HASH_SHA256)
	context.update(tag.get_data())
	var tag_hash := context.finish().hex_encode()
	for entry in catalog:
		if entry.rgb_sha256==rgb_hash and entry.tags_sha256==tag_hash:
			state = int(entry.bits)
			break
	_layout()
	queue_redraw()

func _draw() -> void:
	if state<0 or pristine==null or caption_font==null: return
	var scale_xy := size/Vector2(320,200)
	if state>0:
		var target := Rect2(DRAW_BOX.position*scale_xy,DRAW_BOX.size*scale_xy)
		var source := Rect2(Vector2(119,16),Vector2(181,64.5))
		draw_texture_rect_region(pristine,target,Rect2(source.position*Vector2(pristine.get_size())/Vector2(320,200),source.size*Vector2(pristine.get_size())/Vector2(320,200)))
	# STATUS Genesis caption mask at123,19 is identical to the authenticated
	# information-page M1A1 mask. Reuse that single contour glyph (mapped to A).
	var ratio := Vector2(182/181.0,63/64.5)
	var clear_box := Rect2(Vector2(123,37)+(Vector2(121,17.5)-Vector2(119,16))*ratio,Vector2(32,9)*ratio)
	var empty_blue := Rect2(Vector2(151,17.5),Vector2(6,9))
	draw_texture_rect_region(pristine,Rect2(clear_box.position*scale_xy,clear_box.size*scale_xy),Rect2(empty_blue.position*Vector2(pristine.get_size())/Vector2(320,200),empty_blue.size*Vector2(pristine.get_size())/Vector2(320,200)))
	var label := Rect2(Vector2(123,37)+(Vector2(123,19)-Vector2(119,16))*ratio,Vector2(26,5)*ratio)
	preload("res://scripts/pc_outline_fonts.gd").draw_text(self,caption_font,"A",Rect2(label.position*scale_xy,label.size*scale_xy),Vector2(26,5),Color8(238,238,238))

func _layout() -> void:
	var factor := size/Vector2(320,200)
	clipper.position = DRAW_BOX.position*factor
	clipper.size = DRAW_BOX.size*factor
	for i in patch_nodes.size():
		var node := patch_nodes[i]
		node.visible = state>0 and (state & (1<<i))!=0
		node.position = (ORIGINS[i]-Vector2(119,16))*Vector2(182/181.0,63/64.5)*factor
		node.size = EXTENTS[i]*Vector2(182/181.0,63/64.5)*factor
