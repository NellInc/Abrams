extends Node3D
## Camera-relative replay of observed original draw calls. Presentation only.
## Wire outlines do not establish filled-surface occlusion or material parity.
const SurfaceGeometry = preload("res://scripts/pc_surface_geometry.gd")
const SourceCommands = preload("res://scripts/pc_modern_source_commands.gd")
const ModernOwnership = preload("res://scripts/pc_modern_ownership.gd")
const ModernAssets = preload("res://scripts/pc_modern_assets.gd")
const SurfaceShader = preload("res://scripts/pc_surface.gdshader")
const Colour = preload("res://scripts/pc_colour.gd")
const TerrainStyle = preload("res://scripts/pc_terrain_style.gd")
const TacticalFoliage = preload("res://scripts/pc_tactical_foliage.gd")
const TacticalEffects = preload("res://scripts/pc_tactical_effects.gd")
var tactical_effects = TacticalEffects.new()
var tactical_foliage = TacticalFoliage.new()
var _foliage_pass: Dictionary = {}
var _foliage_mapping: Dictionary = {}
var _effects_inputs: Dictionary = {}
# Per-object running-gear anchors of the current pass (null where none), built
# once from one pass-wide actor index and shared by the mesh key and mapping.
var _motion_anchors: Array = []
var profile_builds := false
var last_apply_timings_usec: Dictionary = {}
var mesh_build_count := 0
var mesh_reuse_count := 0
# Only the source-paired Play viewport opts in. Its shader has no wall-clock
# animation; camera, ownership and material changes are in the mesh key.
var retain_render_target := false
var _cached_pass: Dictionary = {}
var _cached_config: Array = []
# Sustained camera motion misses every frame, so its full deep snapshot is never
# consulted. After this many consecutive camera-changing misses only the cheap
# camera/object-count pre-key is kept; the first unchanged camera snapshots
# again. A hit still always requires full equality with an independent copy.
const MOTION_SNAPSHOT_SKIP := 4
var _previous_prekey: Array = []
var _motion_misses := 0
var solid_enabled := false:
	set(value):
		if solid_enabled!=value: clear_mesh_cache()
		solid_enabled=value
var modern_enabled := false:
	set(value):
		if modern_enabled!=value: clear_mesh_cache()
		modern_enabled=value
var tactical_landscape := false:
	set(value):
		tactical_landscape=value
		if value and _modern_active:
			tactical_foliage.prepare(_foliage_pass,_foliage_mapping,ownership.get_texture())
			tactical_effects.prepare(_foliage_pass,_foliage_mapping,ownership.get_texture(),modern_assets,effect_art)
			_effects_inputs={"rows":TacticalEffects.inputs(_foliage_pass).duplicate(true)}
		else:
			tactical_foliage.clear()
			tactical_effects.clear()
		# Switching reuses the paired source data, never requests a guest tick.
		if mesh_node!=null and mesh_node.mesh!=null and mesh_node.mesh.get_surface_count()>0:
			var active: Material=mesh_node.mesh.surface_get_material(0)
			if active is ShaderMaterial:
				active.set_shader_parameter("tactical_landscape",value)
				refresh_surface_shader(active)
				if retain_render_target and get_viewport() is SubViewport:
					get_viewport().render_target_update_mode=SubViewport.UPDATE_ONCE
var modern_assets = ModernAssets.new()
var tactical_material_textures: Dictionary = {}
var tactical_material_atlas: Texture2D
var modern_prewarmed := false
var modern_status := "Modern assets unavailable"
var modern_polygon_count := 0
var modern_triangle_count := 0
var modern_tree_count := 0
var modern_running_gear_triangles := 0
var modern_fallback_polygon_count := 0
var source_round_count := 0
var modern_frame_status := "No paired Modern frame"
var ownership = ModernOwnership.new()
var _owner := 0
var _modern_active := false
var _modern_shader: Shader
var _groundlight_shader: Shader
var presentation_palette: Array = []
var terrain_style: RefCounted
var effect_art: RefCounted
var vehicle_art: RefCounted
var vehicle_polygon_count := 0
var effect_art_ids: Array[int] = []
var _effect_uvs := PackedVector2Array()
var terrain_active := false
var camera_basis_ready := false
var terrain_polygon_count := 0
var hill_polygon_count := 0
var _pattern_key := ""
var _pattern_texture: Texture2D
var _mean_texture: Texture2D
var render_warnings: Array[String] = []
const DISPLAY_SCALE := 64.0
var mesh_node: MeshInstance3D
var polygon_count := 0
var dynamic_polygon_count := 0
var sprite_count := 0
var source_points: Array = []

func _init() -> void:
	_modern_shader = Shader.new()
	_modern_shader.code = SurfaceShader.code.replace("depth_test_disabled, depth_draw_never", "depth_draw_opaque").replace("void fragment() {", "void fragment() {\n    DEPTH = UV.y > 19.5 && UV.y < 21.5 ? FRAGCOORD.z : 0.0;\n    if (UV.y > 20.04 && UV.y < 20.08) DEPTH = 0.5 + min(UV2.x,1024.0)/4096.0;")
	_groundlight_shader=Shader.new()
	var groundlight_code:=_groundlight_source()
	if groundlight_code.is_empty():_groundlight_shader=null
	else:_groundlight_shader.code=groundlight_code.replace("depth_test_disabled, depth_draw_never", "depth_draw_opaque").replace("void fragment() {", "void fragment() {\n    DEPTH = UV.y > 19.5 && UV.y < 21.5 ? FRAGCOORD.z : 0.0;\n    if (UV.y > 20.04 && UV.y < 20.08) DEPTH = 0.5 + min(UV2.x,1024.0)/4096.0;")
	mesh_node = MeshInstance3D.new()
	add_child(mesh_node)
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ownership)
	add_child(tactical_foliage)
	add_child(tactical_effects)


func _groundlight_source() -> String:
	# Extend the existing source template; no duplicate baseline shader to drift.
	var code:=SurfaceShader.code
	var edits:Dictionary={
		"#include \"res://scripts/pc_tactical_effect_finish.gdshaderinc\"":"#include \"res://scripts/pc_tactical_effect_finish.gdshaderinc\"\n#include \"res://scripts/pc_tactical_polish.gdshaderinc\"",
		"                    crown=tactical_crown(tree.rgb,UV2,UV.x);":"                    crown=tactical_polish_crown(tactical_crown(tree.rgb,UV2,UV.x),UV2,UV.x,bark_footprint);",
		"                foliage=mix(tactical_crown(tree.rgb,tree_uv,seed),vec3(0.52,0.60,0.50),0.22);":"                foliage=mix(tactical_polish_crown(tactical_crown(tree.rgb,tree_uv,seed),tree_uv,seed,abs(tree_dx)+abs(tree_dy)),vec3(0.52,0.60,0.50),0.22);",
		"            ALBEDO=OUTPUT_IS_SRGB ? bark : pow(bark,vec3(2.2));":"            if(modern_environment_polish && modern_surface_variation && tactical_daylight_observed())bark=tactical_polish_collar(bark,UV2,bark_footprint);\n            ALBEDO=OUTPUT_IS_SRGB ? bark : pow(bark,vec3(2.2));",
		"        ALBEDO*=OUTPUT_IS_SRGB ? tint : pow(tint,vec3(2.2));":"        ALBEDO*=OUTPUT_IS_SRGB ? tint : pow(tint,vec3(2.2));\n        ALBEDO=tactical_polish_finish_colour(ALBEDO,tactical_normal,family,finish_sample.x,realism_dx,realism_dy,tactical_position_dx,tactical_position_dy,length(realism_local),tactical_eye_pixel,tactical_realism_ready && realism_usable && finish_sampled);",
		"        finish_sample=realism_sample(realism_uv,realism_dx,realism_dy,family,length(realism_local));\n        finish_sampled=true;\n        finish_normal=tactical_relief_normal":"        finish_sample=tactical_finish_grain_sample(realism_uv,realism_dx,realism_dy,family,length(realism_local));\n        finish_sampled=true;\n        finish_normal=tactical_relief_normal",
		"vec3 tactical_textured_finish_light(vec3 base,vec3 normal,vec3 eye,float legacy_sheen,float family,float distance,float eye_pixel,float texture_gain) {":"#include \"res://scripts/pc_tactical_finishgrain.gdshaderinc\"\n#include \"res://scripts/pc_tactical_diffusion.gdshaderinc\"\n\nvec3 tactical_textured_finish_light(vec3 base,vec3 normal,vec3 eye,float legacy_sheen,float family,float distance,float eye_pixel,float texture_gain) {",
		"    vec3 result=tactical_daylight(base,normal,eye,0.0);":"    vec3 result=tactical_daylight(base,normal,eye,0.0);\n    float rough_gain=tactical_rough_gain(normal,eye,family,texture_gain,distance,eye_pixel);\n    result*=OUTPUT_IS_SRGB ? vec3(rough_gain) : vec3(pow(rough_gain,2.2));",
		"vec3 tactical_soil(vec3 base, vec2 surface, vec2 dx, vec2 dy, vec3 face, vec3 eye, float kind, float distance) {":"#include \"res://scripts/pc_tactical_groundlight.gdshaderinc\"\n\nvec3 tactical_soil(vec3 base, vec2 surface, vec2 dx, vec2 dy, vec3 face, vec3 eye, float kind, float distance,vec3 atlas_slope,float atlas_gain,bool brown,vec3 world_point,float eye_pixel) {",
		"    vec3 normal=tactical_slope_normal(face,vec2(sx,sy)*fine_fade,kind);":"    vec3 normal=tactical_slope_normal(face,vec2(sx,sy)*fine_fade,kind);\n    normal=tactical_terrain_normal(face,normal,atlas_slope,10.0);",
		"    base*=OUTPUT_IS_SRGB ? tint : pow(tint,vec3(2.2));\n    vec3 lit=tactical_daylight(base,normal,eye,0.0);":"    if(brown) {\n        vec2 colour_filters=vec2(tactical_ground_colour_fade(dx,dy,96.0),tactical_ground_detail(footprint,256.0)/(1.0+pow(distance/24000.0,2.0)));\n        vec3 earth=tactical_hill_earth(face,world_point,vec3(broad,middle,fine),colour_filters,atlas_gain,hill_mean);\n        base=OUTPUT_IS_SRGB ? earth : pow(earth,vec3(2.2));\n    } else base*=OUTPUT_IS_SRGB ? tint : pow(tint,vec3(2.2));\n    vec3 lit=tactical_daylight(base,normal,eye,0.0);\n    float rough_near=tactical_rough_gain(normal,eye,10.0,atlas_gain,distance,eye_pixel);\n    lit*=OUTPUT_IS_SRGB ? vec3(rough_near) : vec3(pow(rough_near,2.2));",
		"    vec3 distant=tactical_daylight(base,face,eye,0.0);":"    vec3 distant=tactical_daylight(base,face,eye,0.0);\n    float rough_far=tactical_rough_gain(face,eye,10.0,atlas_gain,distance,eye_pixel);\n    distant*=OUTPUT_IS_SRGB ? vec3(rough_far) : vec3(pow(rough_far,2.2));",
		"    vec3 finish_normal=tactical_normal;":"    vec3 terrain_atlas_slope=vec3(0.0);\n    bool terrain_finish=tactical_landscape && modern_active && modern_environment_polish && modern_surface_variation &&\n        tactical_realism_ready && detail_levels>1.0 && tactical_daylight_observed() && realism_usable && realism_ground(family) &&\n        ((UV.y>0.5 && UV.y<3.5) || (UV.y>6.5 && UV.y<9.5));\n    if(terrain_finish) {\n        finish_sample=realism_sample(realism_uv,realism_dx,realism_dy,family,length(realism_local));\n        finish_sampled=true;\n        vec3 face=UV.y>2.5 && UV.y<3.5 ? vec3(0.0,0.0,1.0) : tactical_normal;\n        terrain_atlas_slope=tactical_terrain_slope(face,finish_sample.yz,realism_uv,UV.y,family);\n    }\n    vec3 finish_normal=tactical_normal;",
		"                    vec3 normal=tactical_slope_normal(face,vec2(slope_x,slope_y)*fine_fade,UV.y);":"                    vec3 normal=tactical_slope_normal(face,vec2(slope_x,slope_y)*fine_fade,UV.y);\n                    if(terrain_finish)normal=tactical_terrain_normal(face,normal,terrain_atlas_slope,family);",
		"                    base=mix(base,distant,(1.0-distance_fade)*0.35);":"                    base=mix(base,distant,(1.0-distance_fade)*0.35);\n                    if(terrain_finish)base*=tactical_rough_gain(normal,tactical_to_eye,family,finish_sample.x,length(realism_local),tactical_eye_pixel);\n                    if(road && terrain_finish)base=tactical_asphalt_light(base,normal,tactical_to_eye,finish_sample.x,length(realism_local),tactical_eye_pixel);\n                    if(road && terrain_finish)base=tactical_polish_road_edge(base,UV2,terrain_dx,terrain_dy,length(realism_local));",
		"                ALBEDO=tactical_soil(ALBEDO,surface,terrain_dx,terrain_dy,tactical_normal,tactical_to_eye,UV.y,length(local.xy));":"                ALBEDO=tactical_soil(ALBEDO,surface,terrain_dx,terrain_dy,tactical_normal,tactical_to_eye,UV.y,length(local.xy),terrain_atlas_slope,finish_sample.x,terrain_finish && (abs(UV.x-17.0)<0.25 || abs(UV.x-26.0)<0.25),position,tactical_eye_pixel);"
	}
	for anchor:String in edits:
		if code.count(anchor)!=1:
			push_error("Tactical terrain shader anchor is missing or ambiguous")
			return ""
		code=code.replace(anchor,str(edits[anchor]))
	return code

func refresh_surface_shader(active:Material) -> void:
	if not active is ShaderMaterial:return
	var material:ShaderMaterial=active
	# Shader-default controls are explicitly initialized at material creation.
	# Unknown states retain the exact incumbent program. Call after controls.
	var eligible:bool=_modern_active and tactical_landscape and _groundlight_shader!=null
	eligible=eligible and material.get_shader_parameter("modern_active")==true and material.get_shader_parameter("tactical_landscape")==true
	eligible=eligible and material.get_shader_parameter("tactical_realism_ready")==true and material.get_shader_parameter("tactical_realism_atlas") is Texture2D
	eligible=eligible and material.get_shader_parameter("modern_surface_variation")==true and material.get_shader_parameter("modern_environment_polish")==true
	var levels:Variant=material.get_shader_parameter("detail_levels")
	eligible=eligible and (levels is int or levels is float) and is_finite(float(levels)) and float(levels)>1.0
	var horizon:Variant=material.get_shader_parameter("source_horizon_line")
	eligible=eligible and horizon is Vector3 and horizon.is_finite() and Vector2(horizon.x,horizon.y).length_squared()>0.5
	var selected:Shader=(_groundlight_shader if eligible else _modern_shader) if _modern_active else SurfaceShader
	if material.shader==selected:return
	material.shader=selected
	if retain_render_target and get_viewport() is SubViewport:
		get_viewport().render_target_update_mode=SubViewport.UPDATE_ONCE

func load_modern_assets(root: String) -> bool:
	clear_mesh_cache()
	var loaded: bool = modern_assets.load_assets(root)
	tactical_material_textures = modern_assets.material_textures.duplicate()
	tactical_material_atlas=modern_assets.material_atlas
	tactical_foliage.set_material_atlas(tactical_material_atlas)
	modern_status = modern_assets.status
	modern_prewarmed = false
	if loaded and DisplayServer.get_name()!="headless":
		modern_prewarmed = _prewarm_modern()
		if not modern_prewarmed:
			modern_status="Modern GPU warmup unavailable"
			return false
	return loaded

static func camera_point(raw: Array) -> Vector3:
	return Vector3(float(raw[0]), float(raw[2]), -float(raw[1])) / DISPLAY_SCALE

func clear_mesh_cache() -> void:
	_cached_pass.clear()
	_cached_config.clear()

func _mesh_config() -> Array:
	# Loaded presentation assets are immutable between loader revisions. Include
	# the small mutable configuration arrays and texture references explicitly.
	return [solid_enabled,modern_enabled,presentation_palette,
		get_viewport().get_visible_rect().size,RenderingServer.get_current_rendering_method(),
		tactical_material_atlas,tactical_material_textures,modern_assets,modern_assets.revision,modern_assets.ready,modern_assets.colour_texture,modern_assets.tree_texture,
		terrain_style,terrain_style.textures if terrain_style else {},terrain_style.hill_texture if terrain_style else null,
		effect_art,effect_art.atlas if effect_art else null,effect_art.correction if effect_art else null,
		effect_art.sources if effect_art else {},effect_art.bounds if effect_art else {},
		vehicle_art,vehicle_art.atlas if vehicle_art else null,vehicle_art.regions if vehicle_art else [],
		vehicle_art.genesis_palette if vehicle_art else []]

func apply_pass(pass_data: Dictionary) -> void:
	var started: int=Time.get_ticks_usec() if profile_builds else 0
	last_apply_timings_usec={"reused":false,"ownership":0,"mapping":0,"tree_mapping":0,"upload":0,"foliage":0,"effects":0} if profile_builds else {}
	var cacheable: bool = solid_enabled and pass_data.get("camera") is Dictionary and pass_data.get("materials") is Array and pass_data.get("palette_rgb") is Array and pass_data.get("objects") is Array and not pass_data.objects.is_empty()
	if modern_enabled and not modern_assets.ready: cacheable=false
	var config: Array = _mesh_config() if cacheable else []
	var render_input := pass_data.duplicate(false)
	# Delivery/audit fields do not enter geometry, colour, ownership or motion.
	# Retain every camera, object, command, palette and world-position value.
	for field in ["sequence","start_ram_sha256","page_offset"]: render_input.erase(field)
	# The world snapshot is consumed solely for visible running-gear phase.
	# Off-screen actors must still simulate, but cannot dirty this visible mesh.
	var motion_inputs: Array = []
	if modern_enabled and pass_data.get("objects") is Array:
		var actors: Dictionary=ModernAssets.dynamic_index(pass_data)
		for object: Dictionary in pass_data.objects:
			var anchor: float=modern_assets.running_gear_anchor(object,pass_data,actors)
			motion_inputs.append(anchor if is_finite(anchor) else null)
	_motion_anchors=motion_inputs
	render_input["world"]=motion_inputs
	var effects_input: Dictionary={"rows":TacticalEffects.inputs(pass_data)} if modern_enabled and tactical_landscape else {}
	# Full recursive content equality against an independent snapshot, never a
	# sequence/hash-only identity. In-place edits and restored slot reuse miss.
	if cacheable and not _cached_pass.is_empty() and mesh_node.mesh!=null and _cached_config==config and _cached_pass.recursive_equal(render_input,64):
		if _modern_active:
			_foliage_pass=pass_data
			# A source smoke-clock or actor-identity change updates only the small
			# particle batch; actor speed, heading and position never dirty it.
			# Preserve the existing terrain/actor mesh cache.
			if tactical_landscape and not _effects_inputs.recursive_equal(effects_input,64):
				var effects_started: int=Time.get_ticks_usec() if profile_builds else 0
				tactical_effects.prepare(pass_data,_foliage_mapping,ownership.get_texture(),modern_assets,effect_art)
				if profile_builds: last_apply_timings_usec.effects=Time.get_ticks_usec()-effects_started
				_effects_inputs=effects_input.duplicate(true)
				if retain_render_target and get_viewport() is SubViewport:
					get_viewport().render_target_update_mode=SubViewport.UPDATE_ONCE
		if mesh_node.mesh!=null and mesh_node.mesh.get_surface_count()>0:
			refresh_surface_shader(mesh_node.mesh.surface_get_material(0))
		mesh_reuse_count += 1
		_motion_misses=0
		_previous_prekey=[pass_data.camera.duplicate(true),pass_data.objects.size()]
		if profile_builds:
			last_apply_timings_usec.reused=true
			last_apply_timings_usec.total=Time.get_ticks_usec()-started
			last_apply_timings_usec.cache_check=last_apply_timings_usec.total
		return
	if profile_builds: last_apply_timings_usec.cache_check=Time.get_ticks_usec()-started
	clear_mesh_cache()
	if cacheable:
		var prekey: Array=[pass_data.camera.duplicate(true),pass_data.objects.size()]
		_motion_misses=0 if prekey==_previous_prekey else _motion_misses+1
		_previous_prekey=prekey
	mesh_build_count += 1
	if retain_render_target and get_viewport() is SubViewport:
		get_viewport().render_target_update_mode=SubViewport.UPDATE_ONCE
	render_warnings.clear()
	ownership.clear()
	tactical_foliage.clear()
	tactical_effects.clear()
	# Release borrowed snapshots without clearing the caller's dictionary.
	_foliage_pass={}
	_foliage_mapping={}
	_effects_inputs={}
	_owner = 0
	_modern_active = false
	modern_tree_count = 0
	modern_running_gear_triangles = 0
	modern_fallback_polygon_count = 0
	source_round_count = 0
	modern_frame_status = "No paired Modern frame"
	modern_polygon_count = 0
	modern_triangle_count = 0
	modern_assets.max_anchor_error = 0.0
	sprite_count = 0
	effect_art_ids.clear()
	terrain_active = false
	camera_basis_ready = false
	terrain_polygon_count = 0
	hill_polygon_count = 0
	vehicle_polygon_count = 0
	if solid_enabled:
		_apply_surfaces(pass_data,effects_input)
		if _modern_active:
			modern_frame_status="%d refined faces, %d tree planes, %d source fallbacks, %d observed round forms"%[modern_polygon_count,modern_tree_count,modern_fallback_polygon_count,source_round_count]
		elif modern_enabled and pass_data.get("camera") is Dictionary:
			modern_frame_status="Source fallback: Modern assets unavailable" if not modern_assets.ready else "Source fallback: unsupported palette or ownership"
		if cacheable and mesh_node.mesh!=null and (not modern_enabled or _modern_active) and _motion_misses<MOTION_SNAPSHOT_SKIP:
			_cached_pass=render_input.duplicate(true)
			_cached_config=config.duplicate(true)
		if profile_builds: last_apply_timings_usec.total=Time.get_ticks_usec()-started
		return
	var vertices := PackedVector3Array()
	polygon_count = 0
	dynamic_polygon_count = 0
	source_points.clear()
	for object in pass_data.objects:
		for polygon in object.polygons:
			var points: Array = polygon.camera_vertices
			if points.size() < 2: continue
			polygon_count += 1
			# A zero-angle dynamic actor can use the original static arithmetic
			# shortcut. Allocation identity and transform path are distinct.
			if bool(object.get("dynamic_instance", not bool(object.static_path))): dynamic_polygon_count += 1
			source_points.append_array(points)
			var edges: int = points.size() if points.size() > 2 else 1
			for i in edges:
				vertices.append(camera_point(points[i]))
				vertices.append(camera_point(points[(i + 1) % points.size()]))
	if vertices.is_empty():
		mesh_node.mesh = null
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("82a7a0")
	mesh.surface_set_material(0, material)
	mesh_node.mesh = mesh

func _apply_surfaces(pass_data: Dictionary, effects_input: Dictionary) -> void:
	mesh_node.mesh = null
	polygon_count = 0
	dynamic_polygon_count = 0
	source_points.clear()
	if not pass_data.get("camera") is Dictionary: return
	if not pass_data.get("materials") is Array or not pass_data.get("palette_rgb") is Array:
		render_warnings.append("Original material/palette observation unavailable")
		return
	var frame: Dictionary = pass_data.camera
	_modern_active = modern_enabled and modern_assets.ready and modern_assets.supported_palette(pass_data.palette_rgb)
	if _modern_active:
		var owner_started: int=Time.get_ticks_usec() if profile_builds else 0
		_modern_active = ownership.prepare(pass_data,Vector2i(get_viewport().get_visible_rect().size))
		if profile_builds: last_apply_timings_usec.ownership=Time.get_ticks_usec()-owner_started
	var palette: Array = presentation_palette if presentation_palette.size() == 16 else pass_data.palette_rgb
	if modern_enabled: palette = ModernAssets.DAY_PALETTE if _modern_active else pass_data.palette_rgb
	var vertices := PackedVector3Array()
	var materials := PackedVector2Array()
	_effect_uvs.clear()
	var material_count: int = pass_data.materials.size()
	var mapping: Dictionary = terrain_style.mapping(frame,pass_data.palette_rgb) if terrain_style else {}
	terrain_active = not mapping.is_empty()
	var levels: int = TerrainStyle.LEVELS if terrain_active else 1
	var hills: bool = terrain_active and terrain_style.hill_texture!=null
	# Cache the compensated RGB ramps; the original palette/patterns never change.
	var key := JSON.stringify([palette,pass_data.materials,levels])
	if key != _pattern_key:
		var compatibility := RenderingServer.get_current_rendering_method() == "gl_compatibility"
		var texture := Image.create((material_count+16)*2,levels*2,false,Image.FORMAT_RGBAF if compatibility else Image.FORMAT_RGBA8)
		var means := Image.create(material_count+16,levels,false,Image.FORMAT_RGBAF if compatibility else Image.FORMAT_RGBA8)
		for level in levels:
			for index in material_count+16:
				var words: Array = pass_data.materials[index] if index < material_count else [index-material_count,index-material_count]
				var mean_rgb := TerrainStyle.material_mean(palette,words)
				means.set_pixel(index,level,Colour.input_color(TerrainStyle.detail_rgb(mean_rgb,level) if terrain_active else mean_rgb,compatibility))
				for y in 2:
					for x in 2:
						var word: int = int(words[0]) if y == 1 else int(words[1])
						var value := int(words[0]) & 15 if words[0] == words[1] else (word >> (8 if x == 0 else 0)) & 15
						var rgb: Array = TerrainStyle.detail_rgb(palette[value],level) if terrain_active else palette[value]
						texture.set_pixel(index*2+x,level*2+y,Colour.input_color(rgb,compatibility))
		_pattern_texture = ImageTexture.create_from_image(texture)
		_mean_texture = ImageTexture.create_from_image(means)
		_pattern_key = key
	if pass_data.get("background") is Dictionary:
		var backgrounds: Array = SurfaceGeometry.background_polygons(pass_data.background, frame)
		if backgrounds.is_empty(): render_warnings.append("Unsupported vertical horizon")
		for background: Dictionary in backgrounds:
			var points: Array = []
			for point: Vector2 in background.points: points.append(SurfaceGeometry.unproject(point, 1024.0, frame))
			var kind := 3 if terrain_active and pass_data.background.kind == "horizon" and int(background.material) == 8 else 0
			# Only the observed daylight sky, never a blue actor or ground face.
			if _modern_active and terrain_active and int(background.material)==5: kind=16
			_add_triangles(vertices, materials, SurfaceGeometry.triangle_vertices(points, frame), int(background.material), pass_data.materials.size(),kind)
	else:
		render_warnings.append("Original background observation unavailable")
	# Original terrain is the underpaint. Every actor, including a fallback,
	# subsequently obeys the final same-frame original ownership texture.
	var ordered_objects: Array = []
	# Per-object effect-art results, reused by the Tactical effect batch.
	var effect_mappings: Array = []
	effect_mappings.resize(pass_data.objects.size())
	effect_mappings.fill({})
	for index in pass_data.objects.size():
		if _modern_active and modern_assets.is_terrain(pass_data.objects[index]): ordered_objects.append(index)
	for index in pass_data.objects.size():
		if not _modern_active or not modern_assets.is_terrain(pass_data.objects[index]): ordered_objects.append(index)
	for index: int in ordered_objects:
		var object: Dictionary = pass_data.objects[index]
		_owner = index+1 if _modern_active and not modern_assets.is_terrain(object) else 0
		if object.get("sprite") is Dictionary:
			sprite_count += 1
			var effect: Dictionary = effect_art.mapping(object,frame,pass_data.palette_rgb) if effect_art else {}
			effect_mappings[index]=effect
			if not effect.is_empty():
				effect_art_ids.append(effect.index)
				_add_effect(vertices,materials,effect,frame)
			else:
				for run: Dictionary in SurfaceGeometry.sprite_runs(object.sprite, frame):
					var points: Array = []
					for point: Vector2 in run.points: points.append(SurfaceGeometry.unproject(point, 1024.0, frame))
					_add_triangles(vertices, materials, SurfaceGeometry.triangle_vertices(points, frame), material_count + int(run.color), material_count + 16)
		var object_facets: Array = []
		var source_layer := 0
		var gear_anchor: float = float(_motion_anchors[index]) if _modern_active and index<_motion_anchors.size() and _motion_anchors[index]!=null else NAN
		for item: Dictionary in SourceCommands.ordered(object):
			source_layer += 1
			if item.kind=="round_form":
				var runs := SourceCommands.round_runs(item.data,frame)
				var head:bool=_modern_active and modern_assets.supported_palette(pass_data.palette_rgb) and SourceCommands.crew_head(object,item.data)
				if not runs.is_empty(): source_round_count += 1
				for run: Dictionary in runs:
					var points: Array=[]
					for point: Vector2 in run.points: points.append(SurfaceGeometry.unproject(point,1024.0,frame))
					var triangles:Array
					if head:
						var uv:Array=[]
						for point:Vector2 in run.points:uv.append((point-Vector2(item.data.center[0],item.data.center[1]))/Vector2(item.data.horizontal_radius,item.data.radius))
						triangles=SurfaceGeometry.textured_triangles(points,uv,frame)
					else:triangles=SurfaceGeometry.triangle_vertices(points,frame)
					_add_triangles(vertices,materials,triangles,material_count+int(run.color),material_count+16,23 if head else 22)
				continue
			var polygon: Dictionary=item.data
			var points: Array = polygon.camera_vertices
			if points.size() < 2: continue
			polygon_count += 1
			if bool(object.get("dynamic_instance", not bool(object.static_path))): dynamic_polygon_count += 1
			source_points.append_array(points)
			var fill := int(polygon.get("fill_mode", 0)) != 0 and points.size() >= 3
			var mapping_started: int=Time.get_ticks_usec() if profile_builds else 0
			# The object sort below breaks depth ties by painter_order, so the
			# per-face presort would be redundant work.
			var facets: Array = modern_assets.mapping(object,polygon,frame,pass_data.palette_rgb,false,gear_anchor,false) if fill and _modern_active else []
			if profile_builds:
				last_apply_timings_usec.mapping+=Time.get_ticks_usec()-mapping_started
				mapping_started=Time.get_ticks_usec()
			var tree: Array = modern_assets.tree_mapping(object,polygon,frame,pass_data.palette_rgb) if fill and _modern_active else []
			if profile_builds: last_apply_timings_usec.tree_mapping+=Time.get_ticks_usec()-mapping_started
			if not facets.is_empty():
				modern_polygon_count += 1
				# Weapon crews are overlapping, coplanar two-sided source sheets.
				# Use the observed primitive painter slots within their ownership
				# mask. Invented thickness or depth ties would corrupt the pose.
				if int(object.get("shape_index",-1)) in [161,162]:
					for facet: Dictionary in facets:
						facet.realism_family=roundi(fmod(float(facet.kind),1.0)*64.0) if float(facet.kind)>=24.0 else 0
						facet.kind=20.0625
						facet.flat_source_layer=source_layer
				for facet: Dictionary in facets:
					facet.painter_order=object_facets.size()
					object_facets.append(facet)
			if not tree.is_empty():
				modern_tree_count += 1
				_add_tree(vertices,materials,tree,modern_assets.tree_colour_variant(object,frame))
			if fill and facets.is_empty() and tree.is_empty():
				if _modern_active and not modern_assets.is_terrain(object): modern_fallback_polygon_count += 1
				var triangles: Array = SurfaceGeometry.triangle_vertices(points, frame)
				var kind: int = TerrainStyle.surface_kind(object,polygon,hills) if terrain_active else 0
				if terrain_active and _modern_active and modern_assets.water_surface(object,polygon): kind=14
				if kind != 0: terrain_polygon_count += 1
				if kind >= 7 and kind <= 9: hill_polygon_count += 1
				var panel: Dictionary=vehicle_art.mapping(object,polygon,pass_data.palette_rgb) if vehicle_art else {}
				if not panel.is_empty():
					if not panel.uv.is_empty(): triangles=SurfaceGeometry.textured_triangles(points,panel.uv,frame)
					kind=panel.kind
					vehicle_polygon_count+=1
				var road_edges:Array=_road_edge_coordinates(points,triangles) if _modern_active and kind==2 and int(object.get("shape_index",-1)) in [50,51] else []
				_add_triangles(vertices, materials, triangles, int(polygon.colors[1]), pass_data.materials.size(),kind,road_edges)
			if (not fill or polygon.colors[0] != polygon.colors[1]) and tree.is_empty() and facets.is_empty():
				var edges: int = points.size() if points.size() > 2 else 1
				var bridge_colour:int=modern_assets.bridge_line_colour_index(object,polygon,pass_data.palette_rgb) if _modern_active else -1
				for i in edges:
					var line_points:=SurfaceGeometry.line_vertices(points[i],points[(i+1)%points.size()],frame)
					if bridge_colour>=0:_add_triangles(vertices,materials,line_points,bridge_colour,modern_assets.colour_indices.size(),15)
					else:_add_triangles(vertices,materials,line_points,int(polygon.colors[0]),pass_data.materials.size())
		# Sort the refined geometry across the whole original object rather than
		# keeping bevels/wheels trapped in separate source primitive slots.
		# sort_custom is unstable: equal depths keep source face order, then
		# catalogue triangle order, explicitly.
		object_facets.sort_custom(func(a,b): return a.depth>b.depth or (a.depth==b.depth and a.painter_order<b.painter_order))
		for facet: Dictionary in object_facets: _add_modern(vertices,materials,facet)
	if vertices.is_empty(): return
	var upload_started: int=Time.get_ticks_usec() if profile_builds else 0
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = materials
	arrays[Mesh.ARRAY_TEX_UV2] = _effect_uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = _modern_shader if _modern_active else SurfaceShader
	material.set_shader_parameter("modern_active",_modern_active)
	material.set_shader_parameter("tactical_landscape",_modern_active and tactical_landscape)
	material.set_shader_parameter("modern_surface_variation",true)
	material.set_shader_parameter("modern_environment_polish",true)
	if _modern_active:
		material.set_shader_parameter("source_ownership",ownership.get_texture())
		material.set_shader_parameter("modern_colours",modern_assets.colour_texture)
		material.set_shader_parameter("modern_colour_count",float(modern_assets.colour_indices.size()))
		if modern_assets.tree_texture!=null: material.set_shader_parameter("modern_tree",modern_assets.tree_texture)
		material.set_shader_parameter("tactical_realism_ready",tactical_material_atlas!=null)
		if tactical_material_atlas!=null:material.set_shader_parameter("tactical_realism_atlas",tactical_material_atlas)
		material.set_shader_parameter("tactical_material_ready",tactical_material_textures.size()==3)
		for name in tactical_material_textures:material.set_shader_parameter("tactical_"+str(name)+"_detail",tactical_material_textures[name])
	material.set_shader_parameter("material_patterns",_pattern_texture)
	material.set_shader_parameter("pattern_width",float(_pattern_texture.get_width()))
	material.set_shader_parameter("detail_levels",float(levels))
	if vehicle_polygon_count>0:
		material.set_shader_parameter("vehicle_panels",vehicle_art.atlas)
		material.set_shader_parameter("vehicle_colours",vehicle_art.colours(palette,pass_data.materials))
		material.set_shader_parameter("vehicle_materials",float(material_count))
	if hill_polygon_count>0:
		material.set_shader_parameter("hill_detail",terrain_style.hill_texture)
		material.set_shader_parameter("hill_mean",TerrainStyle.HILL_MEAN)
	if _modern_active or hill_polygon_count>0:
		material.set_shader_parameter("material_means",_mean_texture)
	if not effect_art_ids.is_empty():
		material.set_shader_parameter("impact_burst",effect_art.atlas)
		material.set_shader_parameter("effect_correction",effect_art.correction)
	if terrain_active:
		material.set_shader_parameter("field_detail",terrain_style.textures.field)
		material.set_shader_parameter("road_detail",terrain_style.textures.road)
	# The camera basis is a property of the observed frame, not of terrain art.
	# Without it every world-anchored normal would be a zero vector (NaN).
	var basis: Dictionary=mapping if terrain_active else TerrainStyle.camera_basis(frame)
	camera_basis_ready=not basis.is_empty()
	material.set_shader_parameter("camera_basis_ready",camera_basis_ready)
	if camera_basis_ready:
		material.set_shader_parameter("camera_to_local",basis.inverse)
		material.set_shader_parameter("world_origin",basis.origin)
	material.set_shader_parameter("source_origin", Vector2(frame.clip[0], frame.clip[1]))
	material.set_shader_parameter("source_dimensions", Vector2(frame.clip[2] - frame.clip[0] + 1, frame.clip[3] - frame.clip[1] + 1))
	material.set_shader_parameter("source_focal_pixels",float(frame.focal_pixels))
	# The host sends background null for a page whose background event has not
	# arrived; that pass is warned above and has no horizon to classify.
	var background:Dictionary=pass_data.background if pass_data.get("background") is Dictionary else {}
	var background_colours:Array=background.colors if background.get("colors") is Array else []
	# Browser JSON decodes numbers as floats; Array equality is type-sensitive.
	if background.get("kind","")=="horizon" and background_colours.size()==2 and int(background_colours[0])==5 and int(background_colours[1])==8:
		var a:=Vector2(background.line[0][0],background.line[0][1])
		var b:=Vector2(background.line[1][0],background.line[1][1])
		if a.x>b.x:
			var swap:=a;a=b;b=swap
		var delta:=b-a
		if delta.length()>0.0:
			material.set_shader_parameter("source_horizon_line",Vector3(-delta.y,delta.x,delta.y*a.x-delta.x*a.y)/delta.length())
	refresh_surface_shader(material)
	mesh.surface_set_material(0, material)
	mesh_node.mesh = mesh
	if profile_builds: last_apply_timings_usec.upload=Time.get_ticks_usec()-upload_started
	if _modern_active:
		_foliage_pass=pass_data
		_foliage_mapping=mapping
		if tactical_landscape:
			var prepare_started: int=Time.get_ticks_usec() if profile_builds else 0
			tactical_foliage.prepare(pass_data,mapping,ownership.get_texture())
			if profile_builds:
				last_apply_timings_usec.foliage=Time.get_ticks_usec()-prepare_started
				prepare_started=Time.get_ticks_usec()
			tactical_effects.prepare(pass_data,mapping,ownership.get_texture(),modern_assets,effect_art,effect_mappings)
			if profile_builds: last_apply_timings_usec.effects=Time.get_ticks_usec()-prepare_started
			# apply_pass already walked these inputs for its cache check.
			_effects_inputs=effects_input.duplicate(true)


static func _road_edge_coordinates(original:Array,triangles:Array) -> Array:
	# Original unclipped straight-road quad only. Supporting-line distances
	# are inward-positive in raw source units; no near-plane/endcap seam.
	# This is road-face edge finish, not a claim about adjoining soil/cover.
	if original.size()!=4 or triangles.is_empty():return []
	var p:Array[Vector3]=[]
	for raw:Variant in original:
		if not raw is Array or raw.size()!=3:return []
		for value:Variant in raw:
			if not (value is int or value is float) or not is_finite(float(value)):return []
		p.append(Vector3(raw[0],raw[1],raw[2]))
	var e:Array[Vector3]=[p[1]-p[0],p[2]-p[1],p[3]-p[2],p[0]-p[3]]
	for edge:Vector3 in e:
		if edge.length()<8.0:return []
	# Rounded source-camera transforms permit at most two raw units of error.
	if (e[0]+e[2]).length()>2.0 or (e[1]+e[3]).length()>2.0:return []
	var corner:Vector3=e[0].cross(e[1])
	if corner.length()<1.0:return []
	var normal:Vector3=corner.normalized()
	if absf((p[3]-p[0]).dot(normal))>2.0:return []
	var start:int=0 if e[0].length()>=e[1].length() else 1
	var axis:Vector3=e[start].normalized()
	var side:Vector3=normal.cross(axis).normalized()
	var origin:Vector3=p[start]
	var opposite:Vector3=p[(start+3)%4]
	if (opposite-origin).dot(side)<0.0:side=-side
	var width:float=(opposite-origin).dot(side)
	if not is_finite(width) or width<8.0 or e[start].length()<width*2.0:return []
	# Reject skew/trapezoid/self-crossing/ambiguous strips rather than drawing
	# an invented shoulder. Square junctions and curved primitives never call.
	if absf(axis.dot(e[(start+1)%4].normalized()))>0.005:return []
	if absf((p[(start+2)%4]-origin).dot(side)-width)>2.0:return []
	var result:Array[Vector2]=[]
	for raw:Variant in triangles:
		if not raw is Array or raw.size()<3:return []
		var point:=Vector3(float(raw[0]),float(raw[1]),float(raw[2]))
		if not point.is_finite():return []
		var d:float=(point-origin).dot(side)
		if d < -2.0 or d>width+2.0:return []
		d=clampf(d,0.0,width)
		result.append(Vector2(d,width-d))
	return result

func _add_triangles(vertices: PackedVector3Array, materials: PackedVector2Array, points: Array, material: int, count: int, kind: int = 0, road_edges: Array = []) -> void:
	if material < 0 or material >= count:
		render_warnings.append("Unsupported original material %d" % material)
		return
	for i in points.size():
		var point:Array=points[i]
		vertices.append(camera_point(point))
		materials.append(Vector2(material,kind+_owner*32))
		_effect_uvs.append(road_edges[i] if kind==2 and road_edges.size()==points.size() else (Vector2(point[3],point[4]) if kind>=10 and point.size()==5 else Vector2.ZERO))

func _add_effect(vertices: PackedVector3Array, materials: PackedVector2Array, effect: Dictionary, frame: Dictionary) -> void:
	var rect: Rect2 = effect.rect
	var target: Rect2 = effect.target
	var uv: Rect2 = effect.source_uv
	var points := [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
	for index in [0,1,2,0,2,3]:
		var point: Vector2 = points[index]
		vertices.append(camera_point(SurfaceGeometry.unproject(point,1024.0,frame)))
		materials.append(Vector2(float(effect.donor)+1.0,4+_owner*32))
		_effect_uvs.append(uv.position+(point-target.position)/target.size*uv.size)

func _add_modern(vertices: PackedVector3Array, materials: PackedVector2Array, facet: Dictionary) -> void:
	var material_uv:=Vector2(modern_assets.colour_indices[modern_assets.colour_key(facet.color)],float(facet.get("kind",20))+_owner*32)
	for point: Array in facet.points:
		vertices.append(camera_point(point))
		materials.append(material_uv)
		# Verified crew U is -30..45 and V is -90..25. A 512-wide band
		# carries the family independently of owner-packed kind precision.
		# The vertex shader restores integer painter depth before interpolation.
		_effect_uvs.append(Vector2(float(facet.flat_source_layer)+clampf((float(point[3])+512.0)/1024.0,0.001,0.999),float(point[4])+128.0+float(facet.realism_family)*512.0) if facet.has("flat_source_layer") and int(facet.get("realism_family",0))>0 and point.size()==5 else Vector2(float(facet.flat_source_layer),0) if facet.has("flat_source_layer") else Vector2(point[3],point[4]) if point.size()==5 else Vector2.ZERO)
	modern_triangle_count += facet.points.size()/3
	if float(facet.get("kind",20))>20.1 and float(facet.get("kind",20))<20.3: modern_running_gear_triangles += facet.points.size()/3

func _add_tree(vertices: PackedVector3Array, materials: PackedVector2Array, points: Array, variant: float = 0.5) -> void:
	for point: Array in points:
		vertices.append(camera_point(point))
		materials.append(Vector2(variant,21+_owner*32))
		_effect_uvs.append(Vector2(point[3],point[4]))

func _prewarm_modern() -> bool:
	if _groundlight_shader==null:return false
	# SceneTree._initialize invokes this before its nodes enter the tree.
	# A rendering-server-only target therefore warms production cold startup
	# as well as deferred tests, without modifying the active source scene.
	var warm := RenderingServer.viewport_create()
	var scenario := RenderingServer.scenario_create()
	var warm_camera := RenderingServer.camera_create()
	RenderingServer.viewport_set_size(warm,4,4)
	RenderingServer.viewport_set_scenario(warm,scenario)
	RenderingServer.viewport_attach_camera(warm,warm_camera)
	RenderingServer.camera_set_perspective(warm_camera,75.0,0.05,16.0)
	RenderingServer.viewport_set_update_mode(warm,RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	RenderingServer.viewport_set_active(warm,true)
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-1,-1,-2),Vector3(1,-1,-2),Vector3(0,1,-2)])
	arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(0,20),Vector2(0,20),Vector2(0,20)])
	arrays[Mesh.ARRAY_TEX_UV2]=PackedVector2Array([Vector2.ZERO,Vector2.ZERO,Vector2.ZERO])
	var mesh:=ArrayMesh.new()
	for shader in [_modern_shader,_groundlight_shader,ModernOwnership.ShaderSource]:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var material:=ShaderMaterial.new()
		material.shader=shader
		if shader==_modern_shader or shader==_groundlight_shader:
			material.set_shader_parameter("modern_colours",modern_assets.colour_texture)
			material.set_shader_parameter("modern_colour_count",float(modern_assets.colour_indices.size()))
		mesh.surface_set_material(mesh.get_surface_count()-1,material)
	var instance:=RenderingServer.instance_create()
	RenderingServer.instance_set_base(instance,mesh.get_rid())
	RenderingServer.instance_set_scenario(instance,scenario)
	RenderingServer.instance_set_transform(instance,Transform3D.IDENTITY)
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	var image:=RenderingServer.texture_2d_get(RenderingServer.viewport_get_texture(warm))
	var complete:=image!=null and image.get_size()==Vector2i(4,4)
	RenderingServer.viewport_set_active(warm,false)
	RenderingServer.free_rid(instance)
	RenderingServer.free_rid(warm_camera)
	RenderingServer.free_rid(warm)
	RenderingServer.free_rid(scenario)
	return complete
