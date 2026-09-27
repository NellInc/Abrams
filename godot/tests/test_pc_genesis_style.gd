extends SceneTree
const Style = preload("res://scripts/pc_genesis_style.gd")
const DrawPass = preload("res://scripts/pc_draw_pass.gd")
const Camera = preload("res://scripts/pc_camera.gd")
var errors: Array[String] = []
func check(ok: bool, why: String) -> void:
	if not ok: errors.append(why)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var style := Style.new()
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	check(not style.load_palette(directory.path_join("README.md")),"unverified palette accepted")
	check(style.load_palette(directory.path_join("reference/genesis/extracted/gunner/palette.gpl")),"verified Genesis source palette unavailable")
	var original := Style.PC_PALETTE.duplicate(true)
	var before := JSON.stringify(original)
	var mapped := style.for_original(JSON.parse_string(before))
	check(mapped[3] == [32,32,32] and mapped[5] == [65,238,238],"road/sky differ from Genesis swatches")
	check(JSON.stringify(original) == before,"source PC palette mutated")
	var unknown := original.duplicate(true)
	unknown[3] = [1,2,3]
	check(style.for_original(unknown) == unknown,"unknown PC palette should retain original")
	var pass_data := {"camera":{"clip":[0,0,319,199],"center":[159,99],"focal_pixels":128,"near_raw":16,"matrix_q14_columns":[16384,0,0,0,16384,0,0,0,16384],"world_position_raw":[0,0,0]},
		"materials":[],"palette_rgb":original,"objects":[],"background":{"kind":"solid","color":3}}
	for i in 16: pass_data.materials.append([i,i])
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(1280,800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	Camera.apply(camera,pass_data.camera,Vector3.ZERO)
	camera.make_current()
	var draw := DrawPass.new()
	draw.solid_enabled = true
	camera.add_child(draw)
	draw.apply_pass(pass_data)
	var vertices: PackedVector3Array = draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	draw.presentation_palette = mapped
	draw.apply_pass(pass_data)
	check(vertices == draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"palette changed geometry")
	check(JSON.stringify(pass_data.palette_rgb) == before,"draw mutated original palette")
	if "--native" in OS.get_cmdline_user_args():
		await process_frame
		RenderingServer.force_draw(false)
		RenderingServer.force_sync()
		var actual := viewport.get_texture().get_image().get_pixel(640,400)
		check(actual.to_rgba32() == Color8(32,32,32).to_rgba32(),"native Genesis road swatch differs: "+actual.to_html())
	for error in errors: printerr(error)
	print("PC_GENESIS_STYLE: %d failures; native=%s"%[errors.size(),"--native" in OS.get_cmdline_user_args()])
	quit(0 if errors.is_empty() else 1)
