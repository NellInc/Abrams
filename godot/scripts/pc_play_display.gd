extends Control
## Native-pixel 4:3 presentation. Original camera space never changes on resize.
const TandemFrame = preload("res://scripts/pc_tandem_frame.gd")
var world_viewport := SubViewport.new()
var tandem_viewport := SubViewport.new()
var tandem_frame := TandemFrame.new()
var display := TextureRect.new()
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
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
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

func set_graphics_quality(mode: String, samples: int, anisotropy: int) -> bool:
	if mode not in ["ega","genesis","upscaled","modern"] or not MSAA_LEVELS.has(samples) or not ANISOTROPY_LEVELS.has(anisotropy): return false
	graphics_mode=mode
	msaa_samples=samples
	anisotropic_samples=anisotropy
	var active_msaa: int=MSAA_LEVELS[samples] if mode in ["upscaled","modern"] else Viewport.MSAA_DISABLED
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
	var rect := fitted_rect(Vector2i(size))
	if rect.size.x<4 or rect.size.y<3: return
	display.position = rect.position
	display.size = rect.size
	tandem_viewport.size = rect.size
	tandem_frame.size = rect.size
	world_viewport.size = source_dimensions*world_scale(rect.size)
	# A retained source-paired scene must still refresh after a native resize.
	if world_viewport.render_target_update_mode!=SubViewport.UPDATE_ALWAYS:
		world_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	if tandem_viewport.render_target_update_mode!=SubViewport.UPDATE_ALWAYS:
		tandem_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func description() -> Dictionary:
	var rect := fitted_rect(Vector2i(size))
	return {"mode":"play", "window_pixels":[int(size.x),int(size.y)],
		"game_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],
		"tandem_pixels":[tandem_viewport.size.x,tandem_viewport.size.y],
		"world_pixels":[world_viewport.size.x,world_viewport.size.y],
		"source_clip_pixels":[source_dimensions.x,source_dimensions.y],
		"msaa_samples":msaa_samples if graphics_mode in ["upscaled","modern"] else 0,
		"anisotropic_samples":anisotropic_samples,
		"world_scale":world_scale(rect.size), "display_aspect":"4:3"}
