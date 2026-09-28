extends TextureRect
## Original UI pixels over scanout-paired Godot scenery. No inferred colour key.
## Missing attribution shows the actual source frame, never stale scenery.
const COMPOSITOR = preload("res://scripts/pc_tandem_frame.gdshader")
var typography = preload("res://scripts/pc_typography.gd").new()
var damage_art = preload("res://scripts/pc_instrument_damage_art.gd").new()
var dynamic_map_art = preload("res://scripts/pc_dynamic_map_art.gd").new()
var gunner_trim = preload("res://scripts/pc_gunner_trim.gd").new()
var cupola_rail = preload("res://scripts/pc_cupola_rail.gd").new()
var instrument_art = preload("res://scripts/pc_instrument_art.gd").new()
var target_box_art = preload("res://scripts/pc_reticle_target_art.gd").new()
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
var graphics_mode := "upscaled"
var native_graphics = preload("res://scripts/pc_native_graphics.gd").new()
var _cached_source: Image
var _cached_presentation: Dictionary = {}
var _cached_world: Texture2D
var _cached_program: Dictionary = {}
var _upscaled_material: Material
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
# This frame's already decoded and validated mask, never carried across frames.
var _current_plate_mask: Image
var _driver_bits := PackedByteArray()
var _driver_ui := PackedByteArray()
var _driver_nonempty := false

func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shader_material := ShaderMaterial.new()
	shader_material.shader = COMPOSITOR
	material = shader_material
	_upscaled_material = shader_material
	add_child(damage_art)
	damage_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dynamic_map_art)
	dynamic_map_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(gunner_trim)
	gunner_trim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout_gunner)
	add_child(instrument_art)
	instrument_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(reticle_art)
	reticle_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(target_box_art)
	target_box_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(portrait_art)
	portrait_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(typography)
	typography.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frontend_art)
	frontend_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(native_graphics)
	native_graphics.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _layout_gunner() -> void:
	_upscaled_material.set_shader_parameter("gunner_pixel_aspect",size.y*320.0/maxf(size.x*200.0,1.0))

func _fallback(reason: String) -> bool:
	damage_art.clear()
	dynamic_map_art.clear()
	reticle_art.clear()
	target_box_art.clear()
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
	if not cupola_rail.load_source(root): return false
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
	damage_art.load_sources(root)
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
	_current_plate_mask = null
	gunner_trim.clear()
	instrument_art.clear()
	portrait_art.clear()
	status_diagram_verified = false
	material.set_shader_parameter("status_art_enabled",false)
	material.set_shader_parameter("status_diagram_verified",false)
	material.set_shader_parameter("cupola_rail_verified",false)
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
	_current_plate_mask = mask
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

func load_graphics_sources(root: String) -> bool:
	return native_graphics.load_sources(root)

func set_graphics_mode(mode: String) -> bool:
	if mode not in ["ega","genesis","upscaled"]: return false
	if mode=="genesis" and not native_graphics.loaded: return false
	graphics_mode=mode
	if _cached_source!=null:
		set_frame(_cached_source,_cached_presentation,_cached_world,_cached_program)
		present_frontend(_cached_program)
	return true

func present_frontend(program: Dictionary) -> bool:
	var changed:=program!=_cached_program
	_cached_program=program
	if graphics_mode!="upscaled":
		frontend_art.clear()
		if graphics_mode=="genesis" and changed and _cached_source!=null:
			native_graphics.set_frame(_cached_source,_cached_presentation,program)
		return false
	return frontend_art.set_frame(_cached_source,program,_cached_presentation)

func set_frame(source: Image, presentation: Dictionary, world: Texture2D, program: Dictionary={}) -> bool:
	_cached_source=source
	_cached_presentation=presentation
	_cached_world=world
	_cached_program=program
	material=_upscaled_material
	for child in [damage_art,dynamic_map_art,gunner_trim,instrument_art,reticle_art,target_box_art,portrait_art,typography]:child.visible=graphics_mode=="upscaled"
	native_graphics.visible=graphics_mode=="genesis"
	if graphics_mode!="upscaled":
		_fallback("Untouched original EGA" if graphics_mode=="ega" else "Native Genesis donors with original PC fallback")
		material=null
		texture=ImageTexture.create_from_image(source) if source!=null and not source.is_empty() else null
		if graphics_mode=="genesis":native_graphics.set_frame(source,presentation,program)
		return texture!=null
	frontend_art.clear()
	damage_art.clear()
	dynamic_map_art.clear()
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
		var tags := _current_plate_mask
		if tags!=null:
			material.set_shader_parameter("cupola_rail_verified",cupola_rail.verify(source,mask,tags,Rect2i(clip[0],clip[1],clip[2]-clip[0]+1,clip[3]-clip[1]+1),3 in cockpit_art_ids))
			if 1 in cockpit_art_ids:
				gunner_trim.set_frame(source,mask,tags,Rect2i(clip[0],clip[1],clip[2]-clip[0]+1,clip[3]-clip[1]+1),world)
			instrument_art.set_frame(source,mask,tags,presentation.get("orientation",{}))
			damage_art.set_frame(source,mask,tags)
	if genesis_art_enabled: portrait_art.set_frame(source,mask,presentation)
	dynamic_map_art.set_frame(source,presentation)
	typography.set_frame(source,mask,presentation,null,Rect2i(clip[0],clip[1],clip[2]-clip[0]+1,clip[3]-clip[1]+1))
	reticle_art.clear()
	target_box_art.clear()
	if _art_palette_matches(presentation.get("palette_rgb")):
		reticle_art.set_frame(source,mask,presentation)
		target_box_art.set_frame(source,mask,presentation)
	if not typography.world_ink.is_empty() or not reticle_art.ink.is_empty() or not target_box_art.ink.is_empty():
		# Retain the unmodified provenance mask for all art checks above. Only
		# proven bearing and sight ink yield to this same frame's underlying world.
		var composed_mask: Image = mask.duplicate()
		for pixel in typography.world_ink: composed_mask.set_pixelv(pixel,Color.BLACK)
		for pixel in reticle_art.ink: composed_mask.set_pixelv(pixel,Color.BLACK)
		for pixel in target_box_art.ink: composed_mask.set_pixelv(pixel,Color.BLACK)
		material.set_shader_parameter("ui_mask",ImageTexture.create_from_image(composed_mask))
	return true
