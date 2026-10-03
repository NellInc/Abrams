extends SceneTree
const DrawPass = preload("res://scripts/pc_draw_pass.gd")
const Geometry = preload("res://scripts/pc_surface_geometry.gd")
const PcCamera = preload("res://scripts/pc_camera.gd")
var failures: Array[String] = []
const PALETTE = ["000000","0000aa","00aa00","00aaaa","aa0000","aa00aa","aa5500","aaaaaa",
	"555555","5555ff","55ff55","55ffff","ff5555","ff55ff","ffff55","ffffff"]
var frame := {"clip": [32,13,287,109], "center": [159,61], "near_raw": 16, "focal_pixels": 128,
	"matrix_q14_columns": [16384,0,0,0,16384,0,0,0,16384], "world_position_raw": [0,0,0]}
var view: Node3D
var viewport: SubViewport

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func quad(x: float, y: float, w: float, h: float, depth: float, material: int) -> Dictionary:
	var points: Array = []
	for p in [Vector2(x,y), Vector2(x+w,y), Vector2(x+w,y+h), Vector2(x,y+h)]:
		points.append(Geometry.unproject(p, depth, frame))
	return {"camera_vertices": points, "colors": [material, material], "fill_mode": 1}

func fixture(polygons: Array) -> Dictionary:
	var palette: Array = []
	for hex in PALETTE:
		var c := Color(hex)
		palette.append([roundi(c.r * 255), roundi(c.g * 255), roundi(c.b * 255)])
	var materials: Array = []
	for i in 32: materials.append([i % 16, i % 16])
	materials[17] = [0x0700, 0x0007]
	return {"camera": frame, "palette_rgb": palette, "materials": materials,
		"background": {"kind": "solid", "color": 0}, "objects": [{"static_path": 1, "polygons": polygons}]}

func color_check(im: Image, x: int, y: int, index: int, context: String) -> void:
	var actual := im.get_pixel((x - 32) * 4 + 2, (y - 13) * 4 + 2)
	check(actual.to_rgba32() == Color(PALETTE[index]).to_rgba32(), "%s pixel %d,%d actual=%s expected=%s" % [context,x,y,actual.to_html(),PALETTE[index]])

func _initialize() -> void:
	# A runtime script error aborts _run before quit(); fail instead of idling.
	create_timer(600.0).timeout.connect(func(): printerr("FAIL: PC_SURFACES deadline"); quit(1))
	_run.call_deferred()

func _run() -> void:
	var clipped := Geometry.near_clip([[-64,8,0],[64,32,0],[0,32,64]], 16.0)
	check(clipped.size() == 4, "near plane must insert two intersections")
	for point: Array in clipped: check(point[1] >= 16, "vertex behind near plane")
	check(Geometry.triangle_vertices([[-64,8,0],[64,8,0],[0,8,64]], frame).is_empty(), "hidden polygon survived")
	check(Geometry.line_vertices([-64,128,0],[64,128,0],frame).size() == 6, "screen-width line needs two triangles")
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(1024,388)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	PcCamera.apply(camera, frame, Vector3.ZERO)
	camera.make_current()
	view = DrawPass.new()
	view.solid_enabled = true
	camera.add_child(view)
	var stripes: Array = []
	for i in 16: stripes.append(quad(32 + i * 16, 13, 16, 97, 1024, i))
	view.apply_pass(fixture(stripes))
	check(view.mesh_node.mesh != null and view.polygon_count == 16, "solid polygon stream missing")
	check(view.mesh_node.mesh != null and view.mesh_node.mesh.surface_get_array_len(0) == 102, "one background and sixteen ordered quads")
	check(view.render_warnings.is_empty(), "unexpected surface warning")
	if "--native" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		var im := viewport.get_texture().get_image()
		for i in 16: color_check(im, 40 + i * 16, 40, i, "palette")
		var path := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("artifacts/pc-surface-palette-01.png")
		im.save_png(path)
		view.apply_pass(fixture([quad(32,13,256,97,1024,17)]))
		await process_frame
		await RenderingServer.frame_post_draw
		im = viewport.get_texture().get_image()
		for y in range(13,21):
			for x in range(32,40): color_check(im,x,y,0 if (x+y)%2 == 0 else 7,"dither")
		view.apply_pass(fixture([quad(32,13,256,97,128,4),quad(32,13,256,97,1024,2)]))
		await process_frame
		await RenderingServer.frame_post_draw
		color_check(viewport.get_texture().get_image(),159,61,2,"later far face must cover earlier near face")
		view.apply_pass(fixture([quad(32,13,256,97,1024,2),quad(32,13,256,97,128,4)]))
		await process_frame
		await RenderingServer.frame_post_draw
		color_check(viewport.get_texture().get_image(),159,61,4,"reversed painter order")
		var horizon := fixture([])
		horizon.background = {"kind":"horizon", "line":[[32,61],[287,61]], "colors":[11,2]}
		view.apply_pass(horizon)
		await process_frame
		await RenderingServer.frame_post_draw
		im = viewport.get_texture().get_image()
		color_check(im,159,60,11,"sky")
		color_check(im,159,61,2,"ground")
	view.apply_pass({"objects": []})
	check(view.mesh_node.mesh == null, "unavailable pass must clear surfaces")
	for failure in failures: printerr("FAIL: " + failure)
	print("PC_SURFACES: %s; native=%s" % ["PASS" if failures.is_empty() else "FAIL", "--native" in OS.get_cmdline_user_args()])
	quit(0 if failures.is_empty() else 1)
