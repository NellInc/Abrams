extends TextureRect
## Original UI pixels over scanout-paired Godot scenery. No inferred colour key.
## Missing attribution shows the actual source frame, never stale scenery.
const COMPOSITOR = preload("res://scripts/pc_tandem_frame.gdshader")
var world_enabled := false
var fallback_reason := "awaiting original framebuffer"

func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shader_material := ShaderMaterial.new()
	shader_material.shader = COMPOSITOR
	material = shader_material

func _fallback(reason: String) -> bool:
	world_enabled = false
	fallback_reason = reason
	material.set_shader_parameter("world_enabled", false)
	material.set_shader_parameter("world_texture", null)
	material.set_shader_parameter("ui_mask", null)
	return false

func set_frame(source: Image, presentation: Dictionary, world: Texture2D) -> bool:
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
	for value in mask.get_data():
		if value != 0 and value != 255: return _fallback("nonbinary UI mask")
	if world == null: return _fallback("world texture unavailable")
	material.set_shader_parameter("camera_rect", Vector4(clip[0], clip[1], clip[2]-clip[0]+1, clip[3]-clip[1]+1))
	material.set_shader_parameter("world_texture", world)
	material.set_shader_parameter("ui_mask", ImageTexture.create_from_image(mask))
	material.set_shader_parameter("world_enabled", true)
	world_enabled = true
	fallback_reason = ""
	return true
