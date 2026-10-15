extends Control
## Native-pixel source composition with verified Tactical station reflow.
const TandemFrame = preload("res://scripts/pc_tandem_frame.gd")
var world_viewport := SubViewport.new()
var tandem_viewport := SubViewport.new()
var tandem_frame := TandemFrame.new()
var display := TextureRect.new()
var background := ColorRect.new()
var tactical_chrome := preload("res://scripts/pc_tactical_chrome.gd").new()
var hud_style := "restored"
var tactical_material := ShaderMaterial.new()
var _hud_mask_bytes := ""
var _hud_mask_texture: Texture2D
var _panel_mask_texture: Texture2D
# Independent CPU snapshot paired with the uploaded mask, never authority.
var _panel_mask_image: Image
var _panel_mask_bytes := PackedByteArray()
var _hud_mask_data := PackedByteArray()
var _wide_station := 0
var _station := 0
var _wide_panel_mask_bytes := PackedByteArray()
var _wide_mask_safe := false
var _wide_mask_station := 0
var _fallback_pair_verified := false
# Last plate overlay verdict, keyed by the exact encoded mask and plate sources.
var _source_mask_key: Array = []
var _source_mask_bytes := PackedByteArray()
var source_dimensions := Vector2i(256,97)
var graphics_mode := "upscaled"
var msaa_samples := 4
var anisotropic_samples := 16
# Every destination samples a complete source rectangle. The very same source
# rectangles prove that a reflow discards only verified static cockpit pixels.
const TACTICAL_LAYOUTS := {
	1: {"camera":Vector4(32,13,288,110), "source":[
		Vector4(32,13,288,110),Vector4(11,139,94,174),Vector4(11,176,94,194),
		Vector4(124,136,194,197),Vector4(224,139,265,193),Vector4(269,139,310,193),Vector4(0,197,320,200)],
		"destination":[Vector4(0.055,0.077,0.945,0.742),Vector4(0.055,0.795,0.255,0.950),
		Vector4(0.277,0.795,0.477,0.950),Vector4(0.499,0.795,0.665,0.950),
		Vector4(0.690,0.795,0.815,0.950),Vector4(0.835,0.795,0.960,0.950),Vector4(0.055,0.957,0.945,0.965)]},
	2: {"camera":Vector4(0,10,320,53), "source":[
		Vector4(0,10,320,53),Vector4(15,62,161,160),Vector4(14,176,94,194),
		Vector4(102,176,163,194),Vector4(207,81,289,143),Vector4(207,143,289,187),Vector4(0,197,320,200)],
		"destination":[Vector4(0.055,0.085,0.945,0.340),Vector4(0.055,0.405,0.425,0.950),
		Vector4(0.465,0.837,0.685,0.950),Vector4(0.715,0.837,0.945,0.950),
		Vector4(0.465,0.405,0.685,0.735),Vector4(0.715,0.405,0.945,0.735),Vector4(0.055,0.957,0.945,0.965)]},
	3: {"camera":Vector4(0,0,320,117), "source":[Vector4(0,0,320,146),Vector4(0,197,320,200)],
		"destination":[Vector4(0.055,0.085,0.945,0.950),Vector4(0.055,0.957,0.945,0.965)]},
	4: {"camera":Vector4(0,0,320,136), "source":[Vector4(0,0,320,136),Vector4(60,187,258,198),Vector4(0,198,320,200)],
		"destination":[Vector4(0.055,0.085,0.945,0.870),Vector4(0.220,0.893,0.780,0.950),Vector4(0.055,0.957,0.945,0.965)]},
	5: {"camera":Vector4.ZERO, "source":[Vector4(18,37,105,100),Vector4(123,37,305,100),
		Vector4(9,107,313,184),Vector4(0,197,320,200)],
		"destination":[Vector4(0.650,0.130,0.850,0.440),Vector4(0.055,0.105,0.550,0.470),
		Vector4(0.055,0.520,0.945,0.950),Vector4(0.055,0.957,0.945,0.965)]}}
const MSAA_LEVELS := {0:Viewport.MSAA_DISABLED,2:Viewport.MSAA_2X,4:Viewport.MSAA_4X,8:Viewport.MSAA_8X}
const ANISOTROPY_LEVELS := {0:Viewport.ANISOTROPY_DISABLED,2:Viewport.ANISOTROPY_2X,4:Viewport.ANISOTROPY_4X,8:Viewport.ANISOTROPY_8X,16:Viewport.ANISOTROPY_16X}

static func fitted_rect(available: Vector2i) -> Rect2i:
	var unit := maxi(0,mini(available.x/4,available.y/3))
	var extent := Vector2i(unit*4,unit*3)
	return Rect2i((available-extent)/2,extent)

static func wide_fitted_rect(available: Vector2i) -> Rect2i:
	var unit := maxi(0,mini(available.x/16,available.y/9))
	var extent := Vector2i(unit*16,unit*9)
	return Rect2i((available-extent)/2,extent)

static func world_scale(extent: Vector2i) -> int:
	# Preserve the source clip's exact aspect. Supersample both axes sufficiently
	# for the final 4:3 display, which stretches the original rectangular pixels.
	return maxi(1,ceili(maxf(extent.x/320.0,extent.y/200.0)))

static func parse_extent(value: String) -> Vector2i:
	var parts := value.split("x")
	if parts.size()!=2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return Vector2i.ZERO
	var extent := Vector2i(int(parts[0]),int(parts[1]))
	return extent if extent.x>=640 and extent.y>=480 and extent.x<=16384 and extent.y<=16384 else Vector2i.ZERO

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tactical_material.shader=preload("res://scripts/pc_tactical_hud.gdshader")
	background.color = Color.BLACK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	tactical_chrome.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(tactical_chrome)
	tandem_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	display.add_child(tandem_viewport)
	# Explicit child-first rendering keeps resized scenery and UI in one frame.
	world_viewport.own_world_3d = true
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Project MSAA affects the root window, not this separate scenery viewport.
	# UI and the original source-ownership ID viewport must never be multisampled.
	world_viewport.msaa_3d = Viewport.MSAA_4X
	world_viewport.anisotropic_filtering_level = Viewport.ANISOTROPY_16X
	tandem_viewport.add_child(world_viewport)
	tandem_viewport.add_child(tandem_frame)
	display.texture = tandem_viewport.get_texture()
	resized.connect(_resize_targets)

func _ready() -> void:
	_resize_targets()

func set_camera_dimensions(dimensions: Vector2i) -> void:
	assert(dimensions.x>0 and dimensions.y>0)
	if dimensions==source_dimensions: return
	source_dimensions = dimensions
	_resize_targets()

func set_hud_style(style: String) -> bool:
	if style not in ["restored","tactical"]: return false
	hud_style=style
	if style=="restored":
		_hud_mask_bytes=""
		_hud_mask_texture=null
		_hud_mask_data.clear()
		_panel_mask_bytes.clear()
		_panel_mask_texture=null
		_panel_mask_image=null
	_set_wide_station(0)
	_update_hud_material()
	return true

func set_hud_frame(presentation: Dictionary, program: Dictionary, verified_panel_mask: Image=null, verified_map: bool=false, _verified_gunner: bool=false) -> void:
	# Program identity, paired binary UI mask and the compositor's verified
	# plate mask gate this treatment. Malformed provenance restores source.
	_fallback_pair_verified=program.get("name")=="SIM" and tandem_frame._cached_program.get("name")=="SIM" and tandem_frame.world_enabled and tandem_frame._cached_presentation==presentation
	if verified_panel_mask==null:
		verified_panel_mask=_source_cockpit_mask(presentation)
	if verified_panel_mask==null:
		_panel_mask_bytes.clear()
		_panel_mask_texture=null
		_panel_mask_image=null
	else:
		var panel_bytes:=verified_panel_mask.get_data()
		if panel_bytes!=_panel_mask_bytes or _panel_mask_texture==null:
			_panel_mask_texture=ImageTexture.create_from_image(verified_panel_mask)
			_panel_mask_image=verified_panel_mask.duplicate() if verified_panel_mask.get_size()==Vector2i(320,200) and verified_panel_mask.get_format()==Image.FORMAT_L8 and not verified_panel_mask.has_mipmaps() else null
			_panel_mask_bytes=panel_bytes
	if _fallback_pair_verified:
		var same_frame_tags:=_source_cockpit_mask(presentation)
		_fallback_pair_verified=same_frame_tags!=null and same_frame_tags.get_data()==_panel_mask_bytes
	_station=_source_station() if program.get("name")=="SIM" else 0
	tactical_chrome.station=_station
	var bounds:=Vector4.ZERO
	var drawing=presentation.get("draw_pass")
	if drawing is Dictionary and drawing.get("camera") is Dictionary:
		var clip=drawing.camera.get("clip")
		if clip is Array and clip.size()==4 and clip.all(func(value):
			return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value))):
			if clip[0]>=0 and clip[1]>=0 and clip[2]<320 and clip[3]<200 and clip[0]<=clip[2] and clip[1]<=clip[3]:
				bounds=Vector4(clip[0],clip[1],clip[2]+1,clip[3]+1)
	tactical_material.set_shader_parameter("camera_bounds",bounds)
	tactical_material.set_shader_parameter("camera_verified",bounds!=Vector4.ZERO and _station!=5)
	tactical_material.set_shader_parameter("map_verified",verified_map and program.get("name")=="SIM")
	if program.get("name")!="SIM":
		_hud_mask_bytes=""
		_hud_mask_texture=null
		_hud_mask_data.clear()
		_set_wide_station(0)
		_update_hud_material()
		return
	var overlay= presentation.get("ui_overlay")
	if not overlay is Dictionary or overlay.get("width")!=320 or overlay.get("height")!=200 or not overlay.get("mask_png") is String:
		_hud_mask_bytes=""
		_hud_mask_texture=null
		_hud_mask_data.clear()
		_set_wide_station(0)
		_update_hud_material()
		return
	var encoded: String=overlay.mask_png
	if encoded==_hud_mask_bytes and _hud_mask_texture!=null:
		_set_wide_station(_safe_wide_station(bounds,verified_panel_mask))
		_update_hud_material()
		return
	_hud_mask_bytes=""
	_hud_mask_texture=null
	_hud_mask_data.clear()
	var mask:=Image.new()
	if mask.load_png_from_buffer(Marshalls.base64_to_raw(encoded))==OK and mask.get_size()==Vector2i(320,200) and mask.get_format()==Image.FORMAT_L8:
		var bits:=mask.get_data()
		if bits.count(0)+bits.count(255)==bits.size():
			_hud_mask_texture=ImageTexture.create_from_image(mask)
			_hud_mask_bytes=encoded
			_hud_mask_data=bits
	_set_wide_station(_safe_wide_station(bounds,verified_panel_mask))
	_update_hud_material()

func _source_cockpit_mask(presentation: Dictionary) -> Image:
	# PC-only imports use the same verified original plate identity as donor
	# imports. No optional ROM is required for any Tactical station layout.
	var overlay=presentation.get("plate_overlay")
	if not overlay is Dictionary or overlay.get("width")!=320 or overlay.get("height")!=200: return null
	if not overlay.get("plates") is Dictionary or not overlay.get("mask_png") is String: return null
	# The verdict depends only on the exact encoded mask and its plate sources.
	var key:=[overlay.mask_png,overlay.plates]
	if key==_source_mask_key:
		return Image.create_from_data(320,200,false,Image.FORMAT_L8,_source_mask_bytes) if not _source_mask_bytes.is_empty() else null
	_source_mask_key=key.duplicate(true)
	_source_mask_bytes=PackedByteArray()
	var mask:=Image.new()
	if mask.load_png_from_buffer(Marshalls.base64_to_raw(overlay.mask_png))!=OK or mask.get_size()!=Vector2i(320,200) or mask.get_format()!=Image.FORMAT_L8: return null
	var bits:=mask.get_data()
	var recognised:=bits.count(0)
	for id in TandemFrame.COCKPIT_SOURCES:
		var count:=bits.count(id)
		if count==0: continue
		var plate=overlay.plates.get(str(id))
		var expected:Array=TandemFrame.COCKPIT_SOURCES[id]
		if not plate is Dictionary or plate.get("source")!=expected[0] or plate.get("source_sha256")!=expected[1]: return null
		recognised+=count
	if recognised!=64000 or bits.count(0)==64000: return null
	_source_mask_bytes=bits
	return mask

func _source_station() -> int:
	if _panel_mask_bytes.size()!=64000: return 0
	# STATUS can cover a surviving Commander plate during its original dissolve.
	if _panel_mask_bytes.count(5)>0: return 5
	for id in range(1,5):
		if _panel_mask_bytes.count(id)>0: return id
	return 0

func _safe_wide_station(bounds: Vector4, panel_mask: Image) -> int:
	if not TACTICAL_LAYOUTS.has(_station) or not _tactical_graphics(): return 0
	var layout:Dictionary=TACTICAL_LAYOUTS[_station]
	if _station!=5 and bounds!=layout.camera: return 0
	if _hud_mask_data.size()!=64000 or _panel_mask_bytes.size()!=64000 or panel_mask==null: return 0
	if _panel_mask_bytes==_wide_panel_mask_bytes and _wide_mask_station==_station:
		return _station if _wide_mask_safe else 0
	_wide_panel_mask_bytes=_panel_mask_bytes.duplicate()
	_wide_mask_station=_station
	var covered:Image=panel_mask.duplicate()
	for region:Vector4 in layout.source:
		covered.fill_rect(Rect2i(int(region.x),int(region.y),int(region.z-region.x),int(region.w-region.y)),Color8(_station,_station,_station))
	var bits:=covered.get_data()
	var count:=bits.count(_station)
	if _station==5: count+=bits.count(2)
	_wide_mask_safe=count==64000
	return _station if _wide_mask_safe else 0

func _set_wide_station(station: int) -> void:
	if _wide_station==station: return
	_wide_station=station
	tactical_material.set_shader_parameter("wide_station",station)
	if station!=0:
		var layout:Dictionary=TACTICAL_LAYOUTS[station]
		var sources:=PackedVector4Array(layout.source)
		var destinations:=PackedVector4Array(layout.destination)
		tactical_material.set_shader_parameter("layout_count",sources.size())
		sources.resize(8);destinations.resize(8)
		tactical_material.set_shader_parameter("source_regions",sources)
		tactical_material.set_shader_parameter("destination_regions",destinations)
	tactical_chrome.wide_station=station
	tactical_chrome.queue_redraw()
	_resize_targets()

func _update_hud_material() -> void:
	tactical_material.set_shader_parameter("hud_mask",_hud_mask_texture)
	tactical_material.set_shader_parameter("panel_mask",_panel_mask_texture)
	tactical_material.set_shader_parameter("panels_verified",_panel_mask_texture!=null)
	# EGA, upscaled EGA and Genesis are original-pixel modes: no HUD restyle,
	# plate replacement or 16:9 reflow may alter their framebuffer.
	background.color=Color("101a13") if hud_style=="tactical" and _tactical_graphics() else Color.BLACK
	display.material=tactical_material if hud_style=="tactical" and _hud_mask_texture!=null and _tactical_graphics() else null
	if display.material==null: _set_wide_station(0)
	tactical_chrome.fallback_tactical=hud_style=="tactical" and display.material!=null and _wide_station==0
	var station: int=_wide_station
	var layout: Dictionary=TACTICAL_LAYOUTS.get(station,{})
	if station==0 and tactical_chrome.fallback_tactical and _fallback_pair_verified and TACTICAL_LAYOUTS.has(_station):
		station=_station
		layout=original_tactical_layout(station)
	if station!=0 and display.material!=null and _panel_mask_texture!=null:
		tactical_chrome.instruments.set_frame(tandem_frame,station,layout,(_panel_mask_image.duplicate() if _panel_mask_image!=null else _panel_mask_texture.get_image()),_hud_mask_data)
	else:
		tactical_chrome.instruments.clear()
	var map_covered:=false
	if station==2 and display.material!=null:
		map_covered=tactical_chrome.map_art.set_frame(tandem_frame,layout,_hud_mask_data)
	else:
		tactical_chrome.map_art.clear()
	# The opaque Tactical map picture covers the restored map layer beneath it.
	# Skip that layer's per-cell redraw only while covered; a failed proof, a
	# non-map station or leaving Tactical restores it at once. Hidden before the
	# deferred redraw runs, the covered layer issues no draw calls this frame.
	tandem_frame.dynamic_map_art.visible=not map_covered and _tactical_graphics() and not tandem_frame.dynamic_map_art.packet.is_empty()
	tactical_chrome.queue_redraw()
	if tandem_viewport.render_target_update_mode!=SubViewport.UPDATE_ALWAYS:
		tandem_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func _tactical_graphics() -> bool:
	return tandem_frame.graphics_mode in ["upscaled","modern","tactical"]

static func original_tactical_layout(station: int) -> Dictionary:
	# Destinations are the same exclusive source endpoints. This never grants
	# permission to reflow, crop or discard any part of the original frame.
	var layout: Dictionary=TACTICAL_LAYOUTS[station].duplicate(true)
	var destinations: Array=[]
	for region: Vector4 in layout.source: destinations.append(region/Vector4(320,200,320,200))
	layout.destination=destinations
	layout.in_place=true
	return layout

func set_graphics_quality(mode: String, samples: int, anisotropy: int) -> bool:
	if mode not in ["ega","ega_upscaled","genesis","upscaled","modern","tactical"] or not MSAA_LEVELS.has(samples) or not ANISOTROPY_LEVELS.has(anisotropy): return false
	graphics_mode=mode
	msaa_samples=samples
	anisotropic_samples=anisotropy
	var active_msaa: int=MSAA_LEVELS[samples] if mode in ["upscaled","modern","tactical"] else Viewport.MSAA_DISABLED
	if world_viewport.msaa_3d==active_msaa and world_viewport.anisotropic_filtering_level==ANISOTROPY_LEVELS[anisotropy]: return true
	world_viewport.msaa_3d=active_msaa
	world_viewport.anisotropic_filtering_level=ANISOTROPY_LEVELS[anisotropy]
	# Redraw retained GPU targets immediately, including a stationary paired pass.
	# No guest frame, mesh rebuild, camera change or source input is needed.
	if world_viewport.render_target_update_mode!=SubViewport.UPDATE_ALWAYS:
		world_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	if tandem_viewport.render_target_update_mode!=SubViewport.UPDATE_ALWAYS:
		tandem_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	return true

func _resize_targets() -> void:
	var rect := wide_fitted_rect(Vector2i(size)) if _wide_station!=0 else fitted_rect(Vector2i(size))
	if rect.size.x<4 or rect.size.y<3: return
	display.position = rect.position
	display.size = rect.size
	tactical_chrome.position=rect.position if _wide_station!=0 else Vector2.ZERO
	tactical_chrome.size=rect.size if _wide_station!=0 else size
	tactical_chrome.frame_rect=Rect2i(Vector2i.ZERO,rect.size) if _wide_station!=0 else rect
	for content: Control in [tactical_chrome.instruments,tactical_chrome.map_art]:
		content.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		content.position=Vector2.ZERO if _wide_station!=0 else Vector2(rect.position)
		content.size=rect.size
	tactical_chrome.queue_redraw()
	# Wide mode only changes presentation. Keep the source composition at its
	# former width and 4:3 pixel aspect; never widen the camera or ownership pass.
	var source_extent:=Vector2i(rect.size.x,rect.size.x*3/4) if _wide_station!=0 else rect.size
	tandem_viewport.size = source_extent
	tandem_frame.size = source_extent
	world_viewport.size = source_dimensions*world_scale(source_extent)
	# A retained source-paired scene must still refresh after a native resize.
	if world_viewport.render_target_update_mode!=SubViewport.UPDATE_ALWAYS:
		world_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	if tandem_viewport.render_target_update_mode!=SubViewport.UPDATE_ALWAYS:
		tandem_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func description() -> Dictionary:
	var rect := wide_fitted_rect(Vector2i(size)) if _wide_station!=0 else fitted_rect(Vector2i(size))
	return {"mode":"play", "window_pixels":[int(size.x),int(size.y)],
		"game_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],
		"tandem_pixels":[tandem_viewport.size.x,tandem_viewport.size.y],
		"world_pixels":[world_viewport.size.x,world_viewport.size.y],
		"source_clip_pixels":[source_dimensions.x,source_dimensions.y],
		"msaa_samples":msaa_samples if graphics_mode in ["upscaled","modern","tactical"] else 0,
		"anisotropic_samples":anisotropic_samples,
		"world_scale":world_scale(tandem_viewport.size), "display_aspect":"16:9" if _wide_station!=0 else "4:3", "tactical_station":_wide_station}
