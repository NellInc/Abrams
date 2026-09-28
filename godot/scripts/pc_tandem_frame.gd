extends TextureRect
## Original UI pixels over scanout-paired Godot scenery. No inferred colour key.
## Missing attribution shows the actual source frame, never stale scenery.
const COMPOSITOR = preload("res://scripts/pc_tandem_frame.gdshader")
var typography = preload("res://scripts/pc_typography.gd").new()
var instrument_art = preload("res://scripts/pc_instrument_art.gd").new()
var reticle_art = preload("res://scripts/pc_reticle_art.gd").new()
var portrait_art = preload("res://scripts/pc_portrait_art.gd").new()
var frontend_art = preload("res://scripts/pc_frontend_art.gd").new()
var genesis_art_enabled := false
const GENESIS_ART = {
	1:["gunner","f396cd9ade02fb6a6e6aeb7d13cd2e72dde0eabb79bf1a77f218c979d507f41a"],
	2:["commander","4182083afd976950281f1bb3d303311b783e3ee68148858c7fb5b2a19227e180"],
	3:["cupola","6daec85d79914aedbb28233c021beeaa2f478ea0db643b71625dc6bc3314ab0b"],
	4:["driver","7429042e9b42eb89e340cf87e80632894d6d9f7a83a37c1bde99041190ecf1b2"],
	5:["systems-status","b14de0de38209c593f2fcb59463428729ccd51f4af8ba9ccfd5c288307f93d83"]}
var world_enabled := false
var fallback_reason := "awaiting original framebuffer"
const ART_PALETTE = [[0,0,0],[255,255,255],[170,170,170],[85,85,85],[85,85,255],[85,255,255],
	[170,0,0],[170,85,0],[0,170,0],[85,255,85],[255,255,85],[0,0,0],[255,85,85],[0,0,170],[85,255,255],[255,255,255]]
const GUNNER_SOURCE_SHA256 = "359b4c55240fbfda8e1bbb36d71e6b8ebf4c1aa48ea7394c26764cbf69e5795b"
const COCKPIT_SOURCES = {
	1: ["GPS.BIN", GUNNER_SOURCE_SHA256],
	2: ["TC.BIN", "493e8867dca57f6c6588e0288a5e7e3b5d83b2e96a041a85dfedfecd8db94884"],
	3: ["AA.BIN", "d047d71587940c6cf0b7e7072edda8e0b383b179cdf2d238e41a38f4a15d316a"],
	4: ["DRIVER.BIN", "4644f41a098323bf2ea85d2a989725594a0591c6e221a1a91b863cfc216b4b9b"],
	5: ["STATUS.BIN", "7d2abcfd40a79002087bd1534c9ac74ba846dd1cbf03b93f3f66314068b62166"]}
var status_art_texture: Texture2D
var commander_status_atlas: Texture2D
var status_diagram_verified := false
var cockpit_art_textures: Dictionary = {}
var cockpit_art_ids: Array[int] = []
var driver_assembly_enabled := false
var gunner_art_texture: Texture2D
var gunner_art_enabled := false
var gunner_art_reason := "material pilot disabled"
# One successful exact byte-pair cache per predicate. Only provenance is cached;
# current source fingerprints, asset availability and every live cell still run.
var _plate_tags := PackedByteArray()
var _plate_ui := PackedByteArray()
var _plate_ids: Dictionary = {}
var _driver_bits := PackedByteArray()
var _driver_ui := PackedByteArray()
var _driver_nonempty := false

func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shader_material := ShaderMaterial.new()
	shader_material.shader = COMPOSITOR
	material = shader_material
	add_child(instrument_art)
	instrument_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(reticle_art)
	reticle_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(portrait_art)
	portrait_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(typography)
	typography.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frontend_art)
	frontend_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _fallback(reason: String) -> bool:
	reticle_art.clear()
	frontend_art.clear()
	world_enabled = false
	typography.clear_runs()
	fallback_reason = reason
	material.set_shader_parameter("world_enabled", false)
	material.set_shader_parameter("world_texture", null)
	material.set_shader_parameter("ui_mask", null)
	_disable_art("original frame fallback")
	return false

func load_genesis_art(root: String) -> bool:
	# Validate the complete set before replacing any existing textures.
	var images := {}
	for id in GENESIS_ART:
		var entry: Array = GENESIS_ART[id]
		var path := root.path_join("local-art/genesis/cockpit-v2/"+entry[0]+"-genesis-v1.png")
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=entry[1]: return false
		var image := Image.load_from_file(path)
		if image==null or image.get_size()!=Vector2i(1586,992): return false
		images[id] = image
	set_gunner_art(images[1])
	for id in [2,3,4]: set_cockpit_art(id,images[id])
	status_art_texture = ImageTexture.create_from_image(images[5])
	# Keep the compositor within its working Compatibility sampler budget.
	# This lossless two-image atlas also supports mixed commander/STATUS frames.
	var atlas := Image.create_empty(1586,1984,false,Image.FORMAT_RGBA8)
	for id in [2,5]:
		var part: Image = images[id].duplicate()
		part.convert(Image.FORMAT_RGBA8)
		atlas.blit_rect(part,Rect2i(0,0,1586,992),Vector2i(0,0 if id==2 else 992))
	commander_status_atlas = ImageTexture.create_from_image(atlas)
	genesis_art_enabled = true
	material.set_shader_parameter("genesis_art",true)
	typography.fixed_labels_enabled = true
	instrument_art.load_sources(root,images[1])
	portrait_art.load_sources(root)
	frontend_art.load_sources(root)
	return true

func set_gunner_art(image: Image) -> bool:
	gunner_art_texture = null
	_disable_art("material image unavailable")
	if image == null or image.is_empty() or image.get_width() < 640 or image.get_height() < 400:
		return false
	if absf(float(image.get_width()) / image.get_height() - 1.6) > 0.02: return false
	gunner_art_texture = ImageTexture.create_from_image(image)
	return true

func set_cockpit_art(plate_id: int, image: Image) -> bool:
	if plate_id not in [2,3,4]: return false
	cockpit_art_textures.erase(plate_id)
	_disable_art("material image unavailable")
	if image == null or image.is_empty() or image.get_width() < 640 or image.get_height() < 400:
		return false
	if absf(float(image.get_width()) / image.get_height() - 1.6) > 0.02: return false
	cockpit_art_textures[plate_id] = ImageTexture.create_from_image(image)
	return true

func _disable_art(reason: String) -> void:
	instrument_art.clear()
	portrait_art.clear()
	status_diagram_verified = false
	material.set_shader_parameter("status_art_enabled",false)
	material.set_shader_parameter("status_diagram_verified",false)
	gunner_art_enabled = false
	driver_assembly_enabled = false
	material.set_shader_parameter("driver_assembly_enabled", false)
	material.set_shader_parameter("driver_assembly_mask", null)
	cockpit_art_ids.clear()
	material.set_shader_parameter("station_art_enabled", Vector3.ZERO)
	gunner_art_reason = reason
	material.set_shader_parameter("gunner_art_enabled", false)
	material.set_shader_parameter("gunner_art", null)
	material.set_shader_parameter("plate_mask", null)

func _art_palette_matches(palette: Variant) -> bool:
	# Godot JSON numbers are floats. Nested Array equality distinguishes 0.0
	# from 0, although scalar numeric equality does not. Compare components.
	if not palette is Array or palette.size() != 16: return false
	for i in 16:
		if not palette[i] is Array or palette[i].size() != 3: return false
		for channel in 3:
			var value = palette[i][channel]
			if not (value is int or value is float) or value != ART_PALETTE[i][channel]: return false
	return true

func _set_art(presentation: Dictionary, ui: Image) -> void:
	_disable_art("material pilot disabled")
	if gunner_art_texture == null and cockpit_art_textures.is_empty() and status_art_texture==null: return
	gunner_art_reason = "no supported plate provenance"
	if not _art_palette_matches(presentation.get("palette_rgb")):
		gunner_art_reason = "palette differs from material study"
		return
	var overlay = presentation.get("plate_overlay")
	if not overlay is Dictionary or overlay.get("width") != 320 or overlay.get("height") != 200: return
	var plates = overlay.get("plates")
	if not plates is Dictionary: return
	var encoded = overlay.get("mask_png")
	if not encoded is String: return
	var mask := Image.new()
	if mask.load_png_from_buffer(Marshalls.base64_to_raw(encoded)) != OK or mask.get_size() != Vector2i(320,200): return
	if mask.get_format() != Image.FORMAT_L8: return
	var tags := mask.get_data()
	var ui_bits := ui.get_data()
	var present: Dictionary
	if tags==_plate_tags and ui_bits==_plate_ui:
		present=_plate_ids
	else:
		present={}
		for at in tags.size():
			if tags[at]>8 or (tags[at]!=0 and ui_bits[at]!=255): return
			if tags[at]!=0: present[int(tags[at])]=true
		_plate_tags=tags
		_plate_ui=ui_bits
		_plate_ids=present
	var available := cockpit_art_textures.duplicate()
	if gunner_art_texture != null: available[1] = gunner_art_texture
	if status_art_texture != null: available[5] = status_art_texture
	for id in available:
		if not present.has(id): continue
		var source = plates.get(str(id))
		if not source is Dictionary or source.get("source") != COCKPIT_SOURCES[id][0] or source.get("source_sha256") != COCKPIT_SOURCES[id][1]:
			_disable_art("unsupported cockpit source fingerprint")
			return
		cockpit_art_ids.append(id)
	if cockpit_art_ids.is_empty():
		gunner_art_reason = "no surviving supported cockpit plate pixels"
		return
	for id in [2,3,4]:
		var donor = commander_status_atlas if id==2 and genesis_art_enabled else available.get(id)
		material.set_shader_parameter(["commander_art","cupola_art","driver_art"][id-2], donor)
	material.set_shader_parameter("station_art_enabled", Vector3(1 if 2 in cockpit_art_ids else 0, 1 if 3 in cockpit_art_ids else 0, 1 if 4 in cockpit_art_ids else 0))
	material.set_shader_parameter("gunner_art", gunner_art_texture)
	material.set_shader_parameter("plate_mask", ImageTexture.create_from_image(mask))
	gunner_art_enabled = 1 in cockpit_art_ids
	material.set_shader_parameter("gunner_art_enabled", gunner_art_enabled)
	material.set_shader_parameter("status_art_enabled",5 in cockpit_art_ids)
	if 5 in cockpit_art_ids:
		status_diagram_verified = true
		for y in range(37,100):
			for x in range(123,305):
				if tags[y*320+x]!=5:
					status_diagram_verified = false
					break
			if not status_diagram_verified: break
	material.set_shader_parameter("status_diagram_verified",status_diagram_verified)
	gunner_art_reason = "" if gunner_art_enabled else "no surviving gunner plate pixels"

func _set_driver_assembly(presentation: Dictionary, ui: Image) -> void:
	if not cockpit_art_textures.has(4) or not _art_palette_matches(presentation.get("palette_rgb")): return
	var overlay = presentation.get("driver_overlay")
	if not overlay is Dictionary or overlay.get("width") != 320 or overlay.get("height") != 200: return
	if overlay.get("source") != "SIM.EXE:5ba1..5da3" or overlay.get("source_sha256") != "9ee5a5898ddcb8192d30b4083981419515eb3ca220e6cbcd214df628bb164099": return
	if not overlay.get("mask_png") is String: return
	var mask := Image.new()
	if mask.load_png_from_buffer(Marshalls.base64_to_raw(overlay.mask_png)) != OK or mask.get_size() != Vector2i(320,200) or mask.get_format() != Image.FORMAT_RGB8: return
	var values := mask.get_data()
	var ui_bits := ui.get_data()
	var any := _driver_nonempty
	if values!=_driver_bits or ui_bits!=_driver_ui:
		any=false
		for at in 64000:
			var i := at*3
			if values[i+2] not in [0,255] or values[i+1] > 127: return
			if values[i+2] == 0:
				if values[i] != 0 or values[i+1] != 0: return
			elif ui_bits[at] != 255: return
			else: any = true
		_driver_bits=values
		_driver_ui=ui_bits
		_driver_nonempty=any
	if not any: return
	material.set_shader_parameter("driver_art", cockpit_art_textures[4])
	material.set_shader_parameter("driver_assembly_mask", ImageTexture.create_from_image(mask))
	material.set_shader_parameter("driver_assembly_enabled", true)
	driver_assembly_enabled = true

func set_frame(source: Image, presentation: Dictionary, world: Texture2D) -> bool:
	frontend_art.clear()
	texture = ImageTexture.create_from_image(source) if source != null and not source.is_empty() else null
	if texture == null or source.get_size() != Vector2i(320, 200):
		return _fallback("unsupported original framebuffer")
	var drawing = presentation.get("draw_pass")
	if not drawing is Dictionary or not drawing.get("camera") is Dictionary:
		return _fallback("no scanout-paired camera")
	var clip = drawing.camera.get("clip")
	if not clip is Array or clip.size() != 4:
		return _fallback("invalid camera bounds")
	for value in clip:
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)):
			return _fallback("invalid camera bounds")
	if clip[0] < 0 or clip[1] < 0 or clip[2] >= 320 or clip[3] >= 200 or clip[0] > clip[2] or clip[1] > clip[3]:
		return _fallback("invalid camera bounds")
	var overlay = presentation.get("ui_overlay")
	if not overlay is Dictionary or overlay.get("width") != 320 or overlay.get("height") != 200:
		return _fallback("no scanout-paired UI mask")
	var encoded = overlay.get("mask_png")
	if not encoded is String:
		return _fallback("missing UI mask")
	var mask := Image.new()
	if mask.load_png_from_buffer(Marshalls.base64_to_raw(encoded)) != OK or mask.get_size() != Vector2i(320, 200):
		return _fallback("invalid UI mask image")
	# The host emits an L8 mask. Refuse colour/alpha conversions which could hide
	# malformed provenance, and keep explicitly opaque black UI intact.
	if mask.get_format() != Image.FORMAT_L8:
		return _fallback("unsupported UI mask format")
	var mask_bytes := mask.get_data()
	if mask_bytes.count(0)+mask_bytes.count(255)!=mask_bytes.size(): return _fallback("nonbinary UI mask")
	if world == null: return _fallback("world texture unavailable")
	material.set_shader_parameter("camera_rect", Vector4(clip[0], clip[1], clip[2]-clip[0]+1, clip[3]-clip[1]+1))
	material.set_shader_parameter("world_texture", world)
	material.set_shader_parameter("ui_mask", ImageTexture.create_from_image(mask))
	material.set_shader_parameter("world_enabled", true)
	world_enabled = true
	fallback_reason = ""
	_set_art(presentation,mask)
	_set_driver_assembly(presentation,mask)
	typography.status_numbers_enabled = genesis_art_enabled and 5 in cockpit_art_ids
	if genesis_art_enabled and not cockpit_art_ids.is_empty():
		var tags := Image.new()
		if tags.load_png_from_buffer(Marshalls.base64_to_raw(presentation.plate_overlay.mask_png))==OK:
			instrument_art.set_frame(source,mask,tags,presentation.get("orientation",{}))
	if genesis_art_enabled: portrait_art.set_frame(source,mask,presentation)
	typography.set_frame(source,mask,presentation,null,Rect2i(clip[0],clip[1],clip[2]-clip[0]+1,clip[3]-clip[1]+1))
	reticle_art.clear()
	if _art_palette_matches(presentation.get("palette_rgb")): reticle_art.set_frame(source,mask,presentation)
	if not typography.world_ink.is_empty() or not reticle_art.ink.is_empty():
		# Retain the unmodified provenance mask for all art checks above. Only
		# proven bearing and sight ink yield to this same frame's underlying world.
		var composed_mask: Image = mask.duplicate()
		for pixel in typography.world_ink: composed_mask.set_pixelv(pixel,Color.BLACK)
		for pixel in reticle_art.ink: composed_mask.set_pixelv(pixel,Color.BLACK)
		material.set_shader_parameter("ui_mask",ImageTexture.create_from_image(composed_mask))
	return true
