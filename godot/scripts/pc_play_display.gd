extends Control
## Native-pixel 4:3 presentation. Original camera space never changes on resize.
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
var _panel_mask_bytes := PackedByteArray()
var _hud_mask_data := PackedByteArray()
var _wide_gunner := false
var _wide_panel_mask_bytes := PackedByteArray()
var _wide_mask_safe := false
var source_dimensions := Vector2i(256,97)
var graphics_mode := "upscaled"
var msaa_samples := 4
var anisotropic_samples := 16
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
	background.color=Color("101a13") if style=="tactical" else Color.BLACK
	if style=="restored":
		_hud_mask_bytes=""
		_hud_mask_texture=null
		_hud_mask_data.clear()
		_panel_mask_bytes.clear()
		_panel_mask_texture=null
	_set_wide_gunner(false)
	_update_hud_material()
	return true

func set_hud_frame(presentation: Dictionary, program: Dictionary, verified_panel_mask: Image=null, verified_map: bool=false, verified_gunner: bool=false) -> void:
	# Program identity, paired binary UI mask and the compositor's verified
	# plate mask gate this treatment. Malformed provenance restores source.
	if verified_panel_mask==null:
		verified_panel_mask=_source_gunner_mask(presentation)
		verified_gunner=verified_panel_mask!=null
	if verified_panel_mask==null:
		_panel_mask_bytes.clear()
		_panel_mask_texture=null
	else:
		var panel_bytes:=verified_panel_mask.get_data()
		if panel_bytes!=_panel_mask_bytes or _panel_mask_texture==null:
			_panel_mask_texture=ImageTexture.create_from_image(verified_panel_mask)
			_panel_mask_bytes=panel_bytes
	var bounds:=Vector4.ZERO
	var drawing=presentation.get("draw_pass")
	if drawing is Dictionary and drawing.get("camera") is Dictionary:
		var clip=drawing.camera.get("clip")
		if clip is Array and clip.size()==4 and clip.all(func(value):
			return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value))):
			if clip[0]>=0 and clip[1]>=0 and clip[2]<320 and clip[3]<200 and clip[0]<=clip[2] and clip[1]<=clip[3]:
				bounds=Vector4(clip[0],clip[1],clip[2]+1,clip[3]+1)
	tactical_material.set_shader_parameter("camera_bounds",bounds)
	tactical_material.set_shader_parameter("camera_verified",bounds!=Vector4.ZERO)
	tactical_material.set_shader_parameter("map_verified",verified_map and program.get("name")=="SIM")
	if program.get("name")!="SIM":
		_hud_mask_bytes=""
		_hud_mask_texture=null
		_hud_mask_data.clear()
		_set_wide_gunner(false)
		_update_hud_material()
		return
	var overlay= presentation.get("ui_overlay")
	if not overlay is Dictionary or overlay.get("width")!=320 or overlay.get("height")!=200 or not overlay.get("mask_png") is String:
		_hud_mask_bytes=""
		_hud_mask_texture=null
		_hud_mask_data.clear()
		_set_wide_gunner(false)
		_update_hud_material()
		return
	var encoded: String=overlay.mask_png
	if encoded==_hud_mask_bytes and _hud_mask_texture!=null:
		_set_wide_gunner(_safe_wide_gunner(verified_gunner,bounds,verified_panel_mask))
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
	_set_wide_gunner(_safe_wide_gunner(verified_gunner,bounds,verified_panel_mask))
	_update_hud_material()

func _source_gunner_mask(presentation: Dictionary) -> Image:
	# PC-only imports have no optional Genesis donor art. Their exact original
	# plate identity is still in the paired source packet and can safely drive
	# the same presentation-only layout.
	var overlay=presentation.get("plate_overlay")
	if not overlay is Dictionary or overlay.get("width")!=320 or overlay.get("height")!=200: return null
	if not overlay.get("plates") is Dictionary or not overlay.get("mask_png") is String: return null
	var plate=overlay.plates.get("1")
	if not plate is Dictionary or plate.get("source")!="GPS.BIN" or plate.get("source_sha256")!=preload("res://scripts/pc_tandem_frame.gd").GUNNER_SOURCE_SHA256: return null
	var mask:=Image.new()
	if mask.load_png_from_buffer(Marshalls.base64_to_raw(overlay.mask_png))!=OK or mask.get_size()!=Vector2i(320,200) or mask.get_format()!=Image.FORMAT_L8: return null
	var bits:=mask.get_data()
	if bits.count(0)+bits.count(1)!=bits.size() or bits.count(1)<10000: return null
	return mask

func _safe_wide_gunner(verified_gunner: bool, bounds: Vector4, panel_mask: Image) -> bool:
	if not verified_gunner or bounds!=Vector4(32,13,288,110): return false
	if _hud_mask_data.size()!=64000 or _panel_mask_bytes.size()!=64000 or panel_mask==null: return false
	if _panel_mask_bytes==_wide_panel_mask_bytes: return _wide_mask_safe
	_wide_panel_mask_bytes=_panel_mask_bytes.duplicate()
	# Cover only the copied source regions, then prove every discarded pixel
	# belongs to the original static Gunner plate. Native Image operations keep
	# this per-frame proof cheap even while original UI cells change.
	var covered:=panel_mask.duplicate()
	for rect in [Rect2i(32,13,256,97),Rect2i(11,139,83,35),Rect2i(11,176,83,18),
		Rect2i(124,136,70,61),Rect2i(224,139,41,54),Rect2i(269,139,41,54),Rect2i(0,197,320,3)]:
		covered.fill_rect(rect,Color8(1,1,1))
	_wide_mask_safe=covered.get_data().count(1)==64000
	return _wide_mask_safe

func _set_wide_gunner(enabled: bool) -> void:
	if _wide_gunner==enabled: return
	_wide_gunner=enabled
	tactical_material.set_shader_parameter("wide_gunner",enabled)
	tactical_chrome.wide_gunner=enabled
	tactical_chrome.queue_redraw()
	_resize_targets()

func _update_hud_material() -> void:
	tactical_material.set_shader_parameter("hud_mask",_hud_mask_texture)
	tactical_material.set_shader_parameter("panel_mask",_panel_mask_texture)
	tactical_material.set_shader_parameter("panels_verified",_panel_mask_texture!=null)
	display.material=tactical_material if hud_style=="tactical" and _hud_mask_texture!=null else null
	if display.material==null: _set_wide_gunner(false)
	tactical_chrome.fallback_tactical=hud_style=="tactical" and display.material!=null and not _wide_gunner
	tactical_chrome.queue_redraw()
	if tandem_viewport.render_target_update_mode!=SubViewport.UPDATE_ALWAYS:
		tandem_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func set_graphics_quality(mode: String, samples: int, anisotropy: int) -> bool:
	if mode not in ["ega","genesis","upscaled","modern","tactical"] or not MSAA_LEVELS.has(samples) or not ANISOTROPY_LEVELS.has(anisotropy): return false
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
	var rect := wide_fitted_rect(Vector2i(size)) if _wide_gunner else fitted_rect(Vector2i(size))
	if rect.size.x<4 or rect.size.y<3: return
	display.position = rect.position
	display.size = rect.size
	tactical_chrome.position=rect.position if _wide_gunner else Vector2.ZERO
	tactical_chrome.size=rect.size if _wide_gunner else size
	tactical_chrome.frame_rect=Rect2i(Vector2i.ZERO,rect.size) if _wide_gunner else rect
	tactical_chrome.queue_redraw()
	# Wide mode only changes presentation. Keep the source composition at its
	# former width and 4:3 pixel aspect; never widen the camera or ownership pass.
	var source_extent:=Vector2i(rect.size.x,rect.size.x*3/4) if _wide_gunner else rect.size
	tandem_viewport.size = source_extent
	tandem_frame.size = source_extent
	world_viewport.size = source_dimensions*world_scale(source_extent)
	# A retained source-paired scene must still refresh after a native resize.
	if world_viewport.render_target_update_mode!=SubViewport.UPDATE_ALWAYS:
		world_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	if tandem_viewport.render_target_update_mode!=SubViewport.UPDATE_ALWAYS:
		tandem_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func description() -> Dictionary:
	var rect := wide_fitted_rect(Vector2i(size)) if _wide_gunner else fitted_rect(Vector2i(size))
	return {"mode":"play", "window_pixels":[int(size.x),int(size.y)],
		"game_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],
		"tandem_pixels":[tandem_viewport.size.x,tandem_viewport.size.y],
		"world_pixels":[world_viewport.size.x,world_viewport.size.y],
		"source_clip_pixels":[source_dimensions.x,source_dimensions.y],
		"msaa_samples":msaa_samples if graphics_mode in ["upscaled","modern","tactical"] else 0,
		"anisotropic_samples":anisotropic_samples,
		"world_scale":world_scale(tandem_viewport.size), "display_aspect":"16:9" if _wide_gunner else "4:3"}
