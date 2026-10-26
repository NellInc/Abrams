extends RefCounted
## Private component proof. Never changes a production mesh, material or pixel.
## The caller owns pre/postdraw ordering and all transport/visibility gates.
const Colour = preload("res://scripts/pc_colour.gd")
const VehicleShader = preload("res://scripts/pc_tactical_vehicles.gdshader")
const QUALIFIED_ENGINE: String = "ed1daf0bf"
const MAX_OWNERS: int = 4
const MAX_GROUPS: int = 32
const MAX_TRIANGLES: int = 32768
const MAX_PIXELS: int = 2097152
const CAMERA_PROPERTIES: Array[String] = ["projection", "fov", "size", "frustum_offset", "near", "far", "keep_aspect", "h_offset", "v_offset", "cull_mask"]
const RASTER_PROPERTIES: Array[String] = ["size", "msaa_3d", "screen_space_aa", "scaling_3d_scale", "use_taa", "use_debanding", "mesh_lod_threshold", "texture_mipmap_bias", "anisotropic_filtering_level", "use_occlusion_culling"]
var host: Node
var target: SubViewport
var camera: Camera3D
var pending: Dictionary = {}
var armed: Dictionary = {}
var admitted: Array[int] = []
var reads: int = 0
var renders: int = 0
var cache_hits: int = 0
var last_read_usec: int = 0
var last_prepare_usec: int = 0
var last_before_usec: int = 0
var last_after_usec: int = 0
var last_classify_usec: int = 0
var failure: String = ""
var _nodes: Array[MeshInstance3D] = []
var _shader: Shader
var _shader_source: String = ""
var _proof_key: Array = []
var _proof_mask: Image
var _serial: int = 0
var _clone_uniform_names: Array[Array] = []

func setup(parent: Node) -> void:
	host = parent

func stop() -> void:
	_serial += 1
	pending.clear(); armed.clear(); admitted.clear()
	_proof_key.clear(); _proof_mask = null
	if is_instance_valid(target): target.render_target_update_mode = SubViewport.UPDATE_DISABLED

func begin_packet() -> void:
	# No successful preparation of this packet means no postdraw admission.
	pending = {"clear": true}
	armed.clear()
	admitted.clear()
	if is_instance_valid(target): target.render_target_update_mode = SubViewport.UPDATE_DISABLED

func release() -> void:
	stop()
	if is_instance_valid(target): target.queue_free()
	target = null; camera = null; _nodes.clear(); _clone_uniform_names.clear(); _shader = null

static func shader_variant(source: String) -> String:
	# Append after the entire production fragment, preserving every discard.
	# A changed semantic contract stays silent until deliberately reviewed.
	if source.count("void fragment() {") != 1 or source.count("void vertex() {") != 1 or source.contains("COLOR") or source.contains("ALPHA") or source.contains("DEPTH") or source.contains("TIME"):
		return ""
	if source.count("render_mode unshaded,cull_disabled,depth_draw_opaque,fog_disabled;") != 1:
		return ""
	var start: int = source.find("void fragment() {")
	var end: int = -1
	var depth: int = 0
	var in_comment: bool = false
	for index: int in range(source.find("{", start), source.length()):
		var character: String = source.substr(index, 1)
		if character == "\n": in_comment = false
		if source.substr(index, 2) == "//": in_comment = true
		if in_comment: continue
		# The reviewed shader has no block comments or string literals. A new
		# grammar shape needs review rather than guessed insertion placement.
		if source.substr(index, 2) == "/*" or character == '\"': return ""
		if character == "{": depth += 1
		elif character == "}":
			depth -= 1
			if depth == 0: end = index; break
	if end < 0 or not source.substr(end + 1).strip_edges().is_empty(): return ""
	var proof_fragment: String = source.substr(start, end - start)
	proof_fragment = proof_fragment.replace("void fragment() {", "void fragment() {\n    float cow_proof_z=FRAGCOORD.z;\n    float cow_proof_margin=2.0/65535.0+abs(dFdx(cow_proof_z))+abs(dFdy(cow_proof_z));")
	# Pinned Compatibility uses reversed GL_DEPTH24_STENCIL8 / GL_GEQUAL.
	# Move every cow sample away and every opaque noncow sample nearer. The
	# derivative allowance covers a full pixel, including all MSAA positions.
	proof_fragment += "    if(COLOR.r>0.5) {\n        if(cow_proof_z-cow_proof_margin<=0.0)discard;\n        DEPTH=cow_proof_z-cow_proof_margin;\n    } else DEPTH=min(cow_proof_z+cow_proof_margin,1.0);\n    ALBEDO=vec3(cow_proof_owner,COLOR.r);\n}"
	return (source.substr(0, start) + proof_fragment).replace("void vertex() {", "uniform vec2 cow_proof_owner;\n\nvoid vertex() {")

static func camera_key(live: Camera3D) -> Array:
	if not is_instance_valid(live) or not live.is_inside_tree(): return []
	var result: Array = [live, live.global_transform, live.get_camera_transform(), live.get_camera_projection(), live.current, live.attributes, live.compositor]
	for property: String in CAMERA_PROPERTIES: result.append(live.get(property))
	return result

static func raster_key(world: SubViewport) -> Array:
	if not is_instance_valid(world): return []
	var result: Array = [world]
	for property: String in RASTER_PROPERTIES: result.append(world.get(property))
	return result

static func mesh_key(mesh: ArrayMesh) -> Array:
	if not is_instance_valid(mesh): return []
	var result: Array = [mesh]
	for index: int in mesh.get_surface_count():
		result.append([mesh.surface_get_primitive_type(index), mesh.surface_get_arrays(index), mesh.surface_get_material(index)])
	return result

static func ownership_key(ownership: SubViewport) -> Array:
	if not is_instance_valid(ownership): return []
	var node: MeshInstance3D = ownership.get("mesh_node") as MeshInstance3D
	var source_camera: Camera3D = ownership.get("camera") as Camera3D
	if not is_instance_valid(node) or node.mesh == null or not node.is_visible_in_tree(): return []
	# prepare() publishes a fresh immutable owner mesh. Include its arrays too,
	# so a later in-place mutation cannot turn a cached proof into authority.
	return [ownership, ownership.size, ownership.get("object_count"), mesh_key(node.mesh as ArrayMesh), node.global_transform, node.layers,
		node.visible, node.material_override, camera_key(source_camera)]

static func snapshot_key(snapshot: Dictionary) -> Array:
	var result: Array = [snapshot.get("assets"), snapshot.get("revision"), snapshot.get("owners", []).duplicate(), snapshot.get("triangles")]
	for row: Dictionary in snapshot.get("groups", []):
		result.append([row.owner, row.group, mesh_key(row.mesh), mesh_key(row.proof_mesh), row.shader_code,
			row.uniforms.duplicate(true), row.global_transform, row.custom_aabb, row.layers, row.priority])
	return result

static func snapshot_supported(snapshot: Dictionary) -> bool:
	if not snapshot.get("ok", false) or not snapshot.get("owners") is Array or not snapshot.get("groups") is Array: return false
	if snapshot.owners.is_empty() or snapshot.owners.size() > MAX_OWNERS or snapshot.groups.is_empty() or snapshot.groups.size() > MAX_GROUPS: return false
	if int(snapshot.get("triangles", 0)) <= 0 or int(snapshot.triangles) > MAX_TRIANGLES: return false
	var seen_cow: Dictionary = {}
	var triangles: int = 0
	for row: Dictionary in snapshot.groups:
		if not row.get("owner") is int or row.owner not in snapshot.owners or row.owner < 1 or row.owner > 65534: return false
		if not row.get("uniforms") is Dictionary or not row.get("proof_mesh") is ArrayMesh or not row.get("mesh") is ArrayMesh: return false
		var uniforms: Dictionary = row.uniforms
		if uniforms.get("source_group") != true or uniforms.get("source_piecewise", false) or uniforms.get("source_round", false) or uniforms.get("strict_source_coverage") != true or uniforms.get("instance_owner") != float(row.owner): return false
		if not uniforms.get("source_group_basis") is Basis or not uniforms.get("source_group_origin") is Vector3 or not row.get("global_transform") is Transform3D: return false
		if int(row.get("priority", -1)) != 0 or int(row.get("triangles", 0)) <= 0: return false
		triangles += int(row.triangles)
		if int(row.get("group", -1)) == 28745 and int(row.get("cow_triangles", 0)) > 0: seen_cow[row.owner] = true
	return triangles == int(snapshot.triangles) and snapshot.owners.all(func(id: int) -> bool: return id in seen_cow)

func prepare(snapshot: Dictionary, world: SubViewport, live_camera: Camera3D, ownership: SubViewport, ui: Image, clip: Array, frame: int, epoch: int, current: Callable, guard: Callable = Callable()) -> bool:
	var started: int = Time.get_ticks_usec()
	pending.clear(); armed.clear(); admitted.clear()
	if is_instance_valid(target): target.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if not is_instance_valid(host) or not current.is_valid() or (guard.is_valid() and not guard.call()) or current.call() != [frame, epoch]: return _deny("closed source/transport gate")
	if (RenderingServer.get_current_rendering_method() != "gl_compatibility" or not str(Engine.get_version_info().get("hash", "")).begins_with(QUALIFIED_ENGINE)) or not snapshot_supported(snapshot): return _deny("unsupported component submission")
	var view: Node = snapshot.get("view") as Node
	if not is_instance_valid(view) or not view.has_method("cow_proof_snapshot_valid") or not view.cow_proof_snapshot_valid(snapshot): return _deny("stale actual submission")
	if not is_instance_valid(world) or not is_instance_valid(live_camera) or live_camera.get_viewport() != world or world.get_camera_3d() != live_camera: return _deny("unmatched world camera")
	if world.size.x < 1 or world.size.y < 1 or world.size.x * world.size.y > MAX_PIXELS or world.scaling_3d_scale != 1.0 or world.use_taa or world.use_debanding or world.use_occlusion_culling or live_camera.attributes != null or live_camera.compositor != null: return _deny("unsupported raster/camera")
	if not valid_ui(ui) or not valid_clip(clip): return _deny("missing original UI/clip")
	var owner_inputs: Array = ownership_key(ownership)
	if owner_inputs.is_empty() or ownership.size != world.size: return _deny("unmatched original ownership")
	var token: Dictionary = {"snapshot": snapshot.duplicate(true), "world": world, "camera": live_camera, "ownership": ownership, "ui": ui.get_data(), "ui_image": ui,
		"clip": clip.duplicate(), "size": world.size, "selected": snapshot.owners.duplicate(), "frame": frame, "epoch": epoch,
		"current": current, "guard": guard, "serial": _serial, "camera_key": camera_key(live_camera), "raster_key": raster_key(world),
		"owner_key": owner_inputs, "submission_key": snapshot_key(snapshot)}
	token.proof_key = [epoch, frame, token.camera_key, token.raster_key, token.owner_key, token.submission_key]
	if _proof_mask != null and token.proof_key == _proof_key:
		token.reuse_mask = _proof_mask
	else:
		if not _build(token): return _deny("unrecognized production shader/material")
		target.render_target_update_mode = SubViewport.UPDATE_ONCE
	token.private_key = _private_key()
	pending = token
	failure = ""
	last_prepare_usec = Time.get_ticks_usec() - started
	return true

func _deny(reason: String) -> bool:
	stop(); failure = reason
	return false

func valid_token(token: Dictionary) -> bool:
	if token.is_empty() or token.has("clear") or int(token.get("serial", -1)) != _serial: return false
	var current: Callable = token.current
	var guard: Callable = token.guard
	if not current.is_valid() or current.call() != [token.frame, token.epoch] or (guard.is_valid() and not guard.call()): return false
	var view: Node = token.snapshot.get("view") as Node
	if not is_instance_valid(view) or not view.cow_proof_snapshot_valid(token.snapshot) or not _canonical_nodes(token.snapshot): return false
	if not valid_ui(token.ui_image) or token.ui_image.get_data() != token.ui or _private_key() != token.private_key: return false
	return camera_key(token.camera) == token.camera_key and raster_key(token.world) == token.raster_key and ownership_key(token.ownership) == token.owner_key and snapshot_key(token.snapshot) == token.submission_key

func before_draw() -> void:
	if pending.is_empty(): return
	var started: int = Time.get_ticks_usec()
	if not valid_token(pending): stop(); return
	if not pending.has("reuse_mask") and (not is_instance_valid(target) or target.render_target_update_mode != SubViewport.UPDATE_ONCE): stop(); return
	armed = pending; pending = {}
	if not armed.has("reuse_mask"): renders += 1
	last_before_usec = Time.get_ticks_usec() - started

func after_draw() -> void:
	if armed.is_empty(): return
	var began: int = Time.get_ticks_usec()
	var token: Dictionary = armed
	armed = {}
	if not valid_token(token): stop(); return
	var mask: Image
	if token.has("reuse_mask"):
		if token.reuse_mask != _proof_mask or token.proof_key != _proof_key: stop(); return
		mask = _proof_mask; cache_hits += 1; last_read_usec = 0
	else:
		var started: int = Time.get_ticks_usec()
		mask = target.get_texture().get_image()
		reads += 1; last_read_usec = Time.get_ticks_usec() - started
	if not valid_token(token) or mask == null or mask.get_size() != token.size: stop(); return
	var classification: int = Time.get_ticks_usec()
	admitted = visible_owners(mask, token)
	last_classify_usec = Time.get_ticks_usec() - classification
	_proof_key = token.proof_key.duplicate(true)
	_proof_mask = mask
	last_after_usec = Time.get_ticks_usec() - began

static func _canonical_nodes(snapshot: Dictionary) -> bool:
	for row: Dictionary in snapshot.groups:
		var live: MeshInstance3D = row.node
		var material: ShaderMaterial = row.material
		if not is_instance_valid(live) or not is_instance_valid(material) or row.shader != VehicleShader or row.shader_code != VehicleShader.code: return false
		if material.next_pass != null or live.material_overlay != null or live.transparency != 0.0 or live.visibility_range_begin != 0.0 or live.visibility_range_end != 0.0 or live.sorting_offset != 0.0: return false
		for surface: int in live.get_surface_override_material_count():
			if live.get_surface_override_material(surface) != null: return false
	return true

func _private_key() -> Array:
	if not is_instance_valid(target) or not is_instance_valid(camera): return []
	var result: Array = [raster_key(target), camera_key(camera), target.own_world_3d, target.transparent_bg, target.render_target_clear_mode, _shader.code]
	for index: int in _nodes.size():
		var node: MeshInstance3D = _nodes[index]
		var material: ShaderMaterial = node.material_override as ShaderMaterial
		if not is_instance_valid(material): return []
		var uniforms: Dictionary = {}
		for uniform: String in _clone_uniform_names[index]: uniforms[uniform] = material.get_shader_parameter(uniform)
		result.append([node, node.mesh, node.global_transform, node.custom_aabb, node.layers, node.visible, material, material.shader, material.render_priority, material.next_pass, uniforms.duplicate(true)])
	return result

func _build(token: Dictionary) -> bool:
	var code: String = VehicleShader.code
	var variant: String = shader_variant(code)
	if variant.is_empty() or not _canonical_nodes(token.snapshot): return false
	if _shader == null or _shader_source != code:
		_shader = Shader.new(); _shader.code = variant; _shader_source = code
	if not is_instance_valid(target):
		target = SubViewport.new(); target.name = "PrivateCowComponentProof"
		target.own_world_3d = true; target.transparent_bg = true
		target.render_target_update_mode = SubViewport.UPDATE_DISABLED
		target.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		host.add_child(target)
		camera = Camera3D.new(); target.add_child(camera); camera.make_current()
		var neutral: Environment = Environment.new()
		neutral.background_mode = Environment.BG_COLOR
		neutral.background_color = Color(0, 0, 0, 0)
		camera.environment = neutral
	for property: String in RASTER_PROPERTIES: target.set(property, token.world.get(property))
	for property: String in CAMERA_PROPERTIES: camera.set(property, token.camera.get(property))
	camera.global_transform = token.camera.global_transform
	var index: int = 0
	for row: Dictionary in token.snapshot.groups:
		if index == _nodes.size():
			var node: MeshInstance3D = MeshInstance3D.new()
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			target.add_child(node); _nodes.append(node); _clone_uniform_names.append([])
		var node: MeshInstance3D = _nodes[index]
		node.mesh = row.proof_mesh; node.global_transform = row.global_transform
		node.custom_aabb = row.custom_aabb; node.layers = row.layers; node.visible = true
		var clone: ShaderMaterial = ShaderMaterial.new(); clone.shader = _shader
		clone.render_priority = row.priority
		for uniform: String in row.uniforms: clone.set_shader_parameter(uniform, row.uniforms[uniform])
		var owner_colour: Color = Colour.input_color([row.owner & 255, (row.owner >> 8) & 255, 0], true)
		clone.set_shader_parameter("cow_proof_owner", Vector2(owner_colour.r, owner_colour.g))
		node.material_override = clone
		_clone_uniform_names[index] = row.uniforms.keys()
		_clone_uniform_names[index].append("cow_proof_owner")
		index += 1
	for unused: int in range(index, _nodes.size()): _nodes[unused].visible = false
	return true

static func valid_ui(ui: Image) -> bool:
	if ui == null or ui.get_size() != Vector2i(320, 200) or ui.get_format() != Image.FORMAT_L8: return false
	var bits: PackedByteArray = ui.get_data()
	return bits.size() == 64000 and bits.count(0) + bits.count(255) == 64000

static func valid_clip(clip: Array) -> bool:
	if clip.size() != 4: return false
	for value: Variant in clip:
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)): return false
	return clip[0] >= 0 and clip[1] >= 0 and clip[2] < 320 and clip[3] < 200 and clip[2] >= clip[0] and clip[3] >= clip[1]

static func visible_owners(mask: Image, token: Dictionary) -> Array[int]:
	var found: Array[int] = []
	if mask == null or mask.get_format() != Image.FORMAT_RGBA8 or mask.get_size() != token.get("size", Vector2i.ZERO) or not valid_clip(token.get("clip", [])): return found
	var ui: PackedByteArray = token.get("ui", PackedByteArray())
	if ui.size() != 64000 or ui.count(0) + ui.count(255) != 64000 or not token.get("selected") is Array: return found
	var clip: Array = token.clip
	var extent: Vector2 = Vector2(clip[2] - clip[0] + 1, clip[3] - clip[1] + 1)
	var bytes: PackedByteArray = mask.get_data()
	var witnesses: Dictionary = {}
	# A native RGB conversion/search skips all noncow pixels without dropping
	# any eligible WORLD sample. Search only a private copy: owner byte255 is
	# merely a search hit and never a component witness. Original RGBA bytes
	# still decide exact owner, alpha and every 3x3 interior test.
	var dimensions: Vector2i = mask.get_size()
	var searchable: Image = mask.duplicate() as Image
	searchable.premultiply_alpha() # erase irrelevant transparent RGB before search
	searchable.convert(Image.FORMAT_RGB8)
	var rgb: PackedByteArray = searchable.get_data()
	var cursor: int = 0
	var search_hits: int = 0
	var base_bytes: int = dimensions.x * dimensions.y * 3
	while cursor < base_bytes:
		var hit: int = rgb.find(255, cursor)
		if hit < 0 or hit >= base_bytes: break
		search_hits += 1
		# Bounded fail-closed work even when owner bytes collide with tag255.
		if search_hits > 8192: return found
		cursor = hit + 1
		if hit % 3 != 2: continue
		var pixel: int = hit / 3
		var x: int = pixel % dimensions.x
		var y: int = pixel / dimensions.x
		var at: int = (y * dimensions.x + x) * 4
		if bytes[at + 2] != 255 or bytes[at + 3] != 255: continue
		var id: int = bytes[at] + (bytes[at + 1] << 8)
		if id == 0 or id not in token.selected or id in found or _interior_owner(bytes, dimensions, Vector2i(x, y)) != id: continue
		var source: Vector2i = Vector2i(int(clip[0]) + floori((x + 0.5) * extent.x / dimensions.x), int(clip[1]) + floori((y + 0.5) * extent.y / dimensions.y))
		# Never clamp an out-of-bounds source/UI neighbourhood into authority.
		if source.x < 1 or source.y < 1 or source.x > 318 or source.y > 198: continue
		var clear_ui: bool = true
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				if ui[(source.y + dy) * 320 + source.x + dx] != 0: clear_ui = false; break
			if not clear_ui: break
		if not clear_ui: continue
		if id not in witnesses: witnesses[id] = []
		for previous: Vector2i in witnesses[id]:
			if Vector2(previous).distance_squared_to(Vector2(x, y)) >= 16.0:
				found.append(id)
				if found.size() == token.selected.size(): return found
				break
		# Before success all witnesses lie within <4 pixels of one another,
		# bounding this retained set independently of target dimensions.
		if id not in found: witnesses[id].append(Vector2i(x, y))
	return found

static func _interior_owner(bytes: PackedByteArray, dimensions: Vector2i, pixel: Vector2i) -> int:
	if pixel.x < 1 or pixel.y < 1 or pixel.x >= dimensions.x - 1 or pixel.y >= dimensions.y - 1: return 0
	var at: int = (pixel.y * dimensions.x + pixel.x) * 4
	var id: int = bytes[at] + (bytes[at + 1] << 8)
	if id == 0: return 0
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var offset: int = ((pixel.y + dy) * dimensions.x + pixel.x + dx) * 4
			if bytes[offset] + (bytes[offset + 1] << 8) != id or bytes[offset + 2] != 255 or bytes[offset + 3] != 255: return 0
	return id
