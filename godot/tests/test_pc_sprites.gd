extends SceneTree
const DrawPass = preload("res://scripts/pc_draw_pass.gd")
const Geometry = preload("res://scripts/pc_surface_geometry.gd")
const PcCamera = preload("res://scripts/pc_camera.gd")
var failures: Array[String] = []
var frame := {"clip": [32,13,287,109], "center": [159,61], "near_raw": 16, "focal_pixels": 128,
	"matrix_q14_columns": [16384,0,0,0,16384,0,0,0,16384], "world_position_raw": [0,0,0]}
var palette: Array = []
var viewport: SubViewport
var view: Node3D
var checked := 0

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func fixture(sprite: Dictionary) -> Dictionary:
	var materials: Array = []
	for i in 32: materials.append([i % 16, i % 16])
	materials[2] = [7, 7] # Bitmap index 2 must bypass polygon material remapping.
	return {"camera": frame, "palette_rgb": palette, "materials": materials,
		"background": {"kind": "solid", "color": 12},
		"objects": [{"kind": "sprite", "sprite": sprite, "polygons": []}]}

func snapshot() -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return viewport.get_texture().get_image()

func color_check(im: Image, x: int, y: int, index: int) -> void:
	var rgb: Array = palette[index]
	var expected := Color8(int(rgb[0]), int(rgb[1]), int(rgb[2])).to_rgba32()
	var actual := im.get_pixel((x-32)*4+2, (y-13)*4+2).to_rgba32()
	checked += 1
	if actual != expected and failures.size() < 10:
		failures.append("pixel %d,%d differs: %x != %x (index %d)" % [x,y,actual,expected,index])

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var sprite := {"width": 4, "height": 2, "pixels": [1,1,2,0,2,3,3,4],
		"opaque": [true,true,false,true,true,true,true,true], "origin": [31,13], "clip": [32,13,287,109]}
	var runs := Geometry.sprite_runs(sprite, frame)
	check(runs.size() == 4, "clipping, transparent gap, same-colour run and opaque zero")
	check(runs[1].color == 0, "explicitly opaque black must survive")
	check(runs[0].points[0] == Vector2(32,13), "left clip must retain source position")
	# Test the original EGA colour domain. A separate non-EGA dark-grey probe
	# exposed renderer colour-conversion differences; see pc-sprites-research.md.
	for hex in ["000000","ffffff","aaaaaa","555555","5555ff","55ffff","aa0000","aa5500",
		"00aa00","55ff55","ffff55","000000","ff5555","0000aa","55ffff","ffffff"]:
		var c := Color(hex)
		palette.append([roundi(c.r*255),roundi(c.g*255),roundi(c.b*255)])
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
	view.apply_pass(fixture(sprite))
	check(view.sprite_count == 1 and view.render_warnings.is_empty(), "sprite stream unavailable")
	if "--native" in OS.get_cmdline_user_args():
		var im := await snapshot()
		color_check(im,32,13,1)
		color_check(im,33,13,12)
		color_check(im,34,13,0)
		color_check(im,32,14,3)
		var args := OS.get_cmdline_user_args()
		if "--fixture" in args:
			var data = JSON.parse_string(FileAccess.get_file_as_string(args[args.find("--fixture") + 1]))
			palette = data.palette_rgb
			for source: Dictionary in data.images:
				for origin in [[128,50],[28,10]]:
					var bitmap := source.duplicate(false)
					bitmap.origin = origin
					bitmap.clip = frame.clip
					view.apply_pass(fixture(bitmap))
					im = await snapshot()
					for y in range(maxi(13,origin[1]-1), mini(110,origin[1]+int(bitmap.height)+1)):
						for x in range(maxi(32,origin[0]-1), mini(288,origin[0]+int(bitmap.width)+1)):
							var sx: int = x - origin[0]
							var sy: int = y - origin[1]
							var index := 12
							if sx >= 0 and sx < int(bitmap.width) and sy >= 0 and sy < int(bitmap.height):
								var at: int = sy * int(bitmap.width) + sx
								if bitmap.opaque[at]: index = int(bitmap.pixels[at])
							color_check(im,x,y,index)
		# A later original polygon must cover the sprite even when farther away.
		var pass_data := fixture(sprite)
		var points: Array = []
		for point in [Vector2(32,13),Vector2(40,13),Vector2(40,20),Vector2(32,20)]:
			points.append(Geometry.unproject(point, 2048.0, frame))
		pass_data.objects.append({"static_path": 1, "polygons": [{"camera_vertices": points, "colors": [9,9], "fill_mode": 1}]})
		view.apply_pass(pass_data)
		im = await snapshot()
		color_check(im,32,13,9)
		pass_data.objects.reverse()
		view.apply_pass(pass_data)
		im = await snapshot()
		color_check(im,32,13,1)
		color_check(im,33,13,9)
	view.apply_pass({"objects": []})
	check(view.sprite_count == 0 and view.mesh_node.mesh == null, "unavailable frame must clear sprites")
	for failure in failures: printerr("FAIL: " + failure)
	print("PC_SPRITES: %s; %d native pixel checks" % ["PASS" if failures.is_empty() else "FAIL", checked])
	quit(0 if failures.is_empty() else 1)
