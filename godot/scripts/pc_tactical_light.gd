extends Node3D
## Tactical screen-space light: sun shadow, attached shadow and contact
## occlusion and static cloud shadow on source terrain, cast by the same-frame
## visible original scenery and actors. Presentation only. The source-depth
## target redraws the ownership mesh in its original painter order, so only
## the visible original surface at each pixel can occlude the sun: an actor
## the original hid casts nothing. Actors cast (Nell, 2 November 2026) but
## never receive. No clock is used.
const Camera = preload("res://scripts/pc_camera.gd")
const DepthShader = preload("res://scripts/pc_tactical_depth.gdshader")
const LightShader = preload("res://scripts/pc_tactical_light.gdshader")
# Light classes carried in the ownership mesh's UV2.y.
const STATIC_CASTER := 0.0
const TERRAIN := 1.0
const NO_LIGHT := 2.0
const ACTOR := 3.0
var depth_view := SubViewport.new()
var depth_camera := Camera3D.new()
var depth_mesh := MeshInstance3D.new()
var depth_material := ShaderMaterial.new()
var shade := MeshInstance3D.new()
var shade_material := ShaderMaterial.new()
var active := false

func _init() -> void:
	depth_view.own_world_3d = true
	depth_view.transparent_bg = true
	depth_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	depth_view.msaa_3d = Viewport.MSAA_DISABLED
	depth_view.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	depth_view.add_child(depth_camera)
	depth_camera.make_current()
	depth_material.shader = DepthShader
	depth_mesh.material_override = depth_material
	depth_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	depth_camera.add_child(depth_mesh)
	add_child(depth_view)
	var quad := QuadMesh.new()
	quad.size = Vector2(2,2)
	shade.mesh = quad
	shade_material.shader = LightShader
	# Alpha-pass order: after foliage (priority 1, nearer) and before the
	# particle batch (priority 2). A large sorting offset makes this quad the
	# last priority-1 item; its vertex shader ignores the transform.
	shade_material.render_priority = 1
	shade.sorting_offset = 1.0e9
	shade.material_override = shade_material
	shade.custom_aabb = AABB(Vector3(-1.0e6,-1.0e6,-1.0e6),Vector3(2.0e6,2.0e6,2.0e6))
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shade.visible = false
	add_child(shade)

func clear() -> void:
	active = false
	shade.visible = false
	depth_mesh.mesh = null
	depth_view.render_target_update_mode = SubViewport.UPDATE_DISABLED

## Per-object light classes for ModernOwnership.prepare, by owner ID.
static func classes(data: Dictionary, assets: RefCounted) -> Dictionary:
	var result := {}
	var objects: Array = data.get("objects",[])
	for index in objects.size():
		var object: Dictionary = objects[index]
		if bool(object.get("dynamic_instance", not bool(object.get("static_path",false)))):
			# Only its polygon fills carry depth; sprites and round commands of
			# the same object stay NO_LIGHT in the ownership mesh.
			result[index+1] = ACTOR
		else:
			result[index+1] = TERRAIN if assets.is_terrain(object) else STATIC_CASTER
	return result

## Daylight is the observed blue-sky/green-ground horizon; thermal and other
## palettes keep their preceding Tactical rendering.
static func daylight(data: Dictionary) -> bool:
	var background = data.get("background")
	if not background is Dictionary or background.get("kind","")!="horizon": return false
	var colours = background.get("colors")
	return colours is Array and colours.size()==2 and int(colours[0])==5 and int(colours[1])==8

func prepare(ownership: SubViewport, frame: Dictionary, basis: Dictionary) -> bool:
	clear()
	if ownership.mesh_node.mesh==null or basis.is_empty() or ownership.size.x<1 or ownership.size.y<1: return false
	var position = basis.get("origin")
	if not position is Vector3 or not is_finite(position.z) or position.z<=0.0: return false
	var local: Dictionary = frame.duplicate(true)
	local.matrix_q14_columns = [16384,0,0,0,16384,0,0,0,16384]
	local.world_position_raw = [0,0,0]
	Camera.apply(depth_camera,local,Vector3.ZERO)
	depth_view.size = ownership.size
	depth_mesh.mesh = ownership.mesh_node.mesh
	shade_material.set_shader_parameter("source_depth",depth_view.get_texture())
	shade_material.set_shader_parameter("source_origin",Vector2(frame.clip[0],frame.clip[1]))
	shade_material.set_shader_parameter("source_dimensions",Vector2(frame.clip[2]-frame.clip[0]+1,frame.clip[3]-frame.clip[1]+1))
	shade_material.set_shader_parameter("source_center",Vector2(float(frame.center[0]),float(frame.center[1])))
	shade_material.set_shader_parameter("source_focal_pixels",float(frame.focal_pixels))
	shade_material.set_shader_parameter("camera_to_local",basis.inverse)
	shade_material.set_shader_parameter("eye_height",float(position.z))
	shade_material.set_shader_parameter("world_origin",position)
	# Immutable until the next paired prepare, exactly like the ownership mask.
	depth_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	shade.visible = true
	active = true
	return true
