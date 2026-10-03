extends SceneTree
const Terrain = preload("res://scripts/pc_terrain_style.gd")
const Genesis = preload("res://scripts/pc_genesis_style.gd")
const DrawPass = preload("res://scripts/pc_draw_pass.gd")
const PcCamera = preload("res://scripts/pc_camera.gd")
const Tandem = preload("res://scripts/pc_tandem_frame.gd")
var errors: Array[String] = []
var checks := 0
var native_pixels := 0
var changed_pixels := 0
var ui_pixels := 0
var draw: Node3D
var camera: Camera3D
var viewport: SubViewport
var composite_view: SubViewport
var composite: TextureRect
var directory: String
var style: RefCounted
var genesis: RefCounted

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok and errors.size() < 20: errors.append(message)

func _initialize() -> void:
	# A script error aborts run() before quit(); fail the headless gate instead of hanging it.
	if "--native" not in OS.get_cmdline_user_args(): create_timer(300).timeout.connect(func(): printerr("FAIL: terrain style deadline (%d checks)"%checks); quit(2))
	run.call_deferred()

func snapshot(target: SubViewport) -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return target.get_texture().get_image()

func setup_frame(frame: Dictionary) -> void:
	var displayed := frame.duplicate(true)
	displayed.matrix_q14_columns = [16384,0,0,0,16384,0,0,0,16384]
	displayed.world_position_raw = [0,0,0]
	viewport.size = PcCamera.apply(camera,displayed,Vector3.ZERO)*4

func run() -> void:
	directory = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	style = Terrain.new()
	check(not style.load_assets(directory.path_join("README.md")),"missing assets accepted")
	check(style.textures.is_empty(),"failed load retained partial texture set")
	check(style.load_assets(directory.path_join("local-art/pc-terrain-remastered/detail-v1")),"authored detail assets unavailable")
	genesis = Genesis.new()
	check(genesis.load_palette(directory.path_join("reference/genesis/extracted/gunner/palette.gpl")),"Genesis palette unavailable")
	var frame := {"clip":[32,13,287,109],"center":[159,61],"near_raw":16,"focal_pixels":128,
		"matrix_q14_columns":[16384,0,0,0,16384,0,0,0,16384],"world_position_raw":[0,0,128]}
	var mapping: Dictionary = style.mapping(frame,Terrain.PC_PALETTE)
	check(not mapping.is_empty(),"valid original camera rejected")
	check(Terrain.world_xy(Vector3(20,40,-128),mapping.inverse,mapping.origin)==Vector2(20,-40),"east/south axes")
	# Same physical point under translation, rotation and a streaming-window rebase.
	var point := Vector3(80123,141019,0)
	for degrees in [0,37,90,173,270]:
		var basis := Basis(Vector3.UP,deg_to_rad(degrees))
		for origin in [Vector3(79872,141312,50),Vector3(80000,141500,128)]:
			var relative := Vector3(point.x-origin.x,origin.y-point.y,point.z-origin.z)
			var restored := Terrain.world_xy(basis*relative,basis.inverse(),origin)
			check(restored.distance_to(Vector2(point.x,point.y)) < 0.02,"texture world anchor drifts")
	var invalid := frame.duplicate(true)
	invalid.matrix_q14_columns = [0,0,0,0,0,0,0,0,0]
	check(style.mapping(invalid,Terrain.PC_PALETTE).is_empty(),"singular matrix accepted")
	invalid.matrix_q14_columns = [NAN,0,0,0,1,0,0,0,1]
	check(style.mapping(invalid,Terrain.PC_PALETTE).is_empty(),"nonfinite camera accepted")
	var unknown := Terrain.PC_PALETTE.duplicate(true)
	unknown[3] = [1,2,3]
	check(style.mapping(frame,unknown).is_empty(),"unknown original palette accepted")
	for value in 256:
		check(Terrain.detail_rgb([value,value,value],16)==[value,value,value],"neutral ramp changes source RGB")
	for shape in range(48,55):
		var polygon := {"primitive":5123+(shape-48)*76,"colors":[8,8] if shape==48 else [3,3],"fill_mode":1,"camera_vertices":[[0,128,0],[32,128,0],[0,256,0]]}
		var object := {"dynamic_instance":false,"static_path":1,"shape_index":shape}
		check(Terrain.surface_kind(object,polygon)==(1 if shape==48 else 2),"explicit terrain identity rejected")
		object.dynamic_instance = true
		check(Terrain.surface_kind(object,polygon)==0,"dynamic actor receives terrain")
		object.dynamic_instance = false
		polygon.primitive += 1
		check(Terrain.surface_kind(object,polygon)==0,"unknown primitive receives terrain")
	composite_view = SubViewport.new()
	composite_view.size = Vector2i(1280,800)
	composite_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(composite_view)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	composite_view.add_child(viewport)
	camera = Camera3D.new()
	viewport.add_child(camera)
	camera.make_current()
	draw = DrawPass.new()
	draw.solid_enabled = true
	camera.add_child(draw)
	composite = Tandem.new()
	composite.size = Vector2(1280,800)
	composite_view.add_child(composite)
	setup_frame(frame)
	var materials := []
	for i in 32: materials.append([i%16,i%16])
	var ground := {"primitive":5275,"colors":[3,3],"fill_mode":1,
		"camera_vertices":[[-2048,128,-128],[2048,128,-128],[2048,8192,-128],[-2048,8192,-128]]}
	var sample := {"camera":frame,"palette_rgb":Terrain.PC_PALETTE,"materials":materials,
		"background":{"kind":"horizon","line":[[32,61],[287,61]],"colors":[5,8]},
		"objects":[{"shape_index":50,"dynamic_instance":false,"static_path":1,"polygons":[ground]}]}
	compare_geometry(sample,true)
	check(draw.terrain_active and draw.terrain_polygon_count==1,"synthetic ground not styled by draw pass")
	var args := OS.get_cmdline_user_args()
	var native := "--native" in args
	var output := directory.path_join("artifacts/pc-terrain-style-test")
	if "--output" in args: output = args[args.find("--output")+1]
	DirAccess.make_dir_recursive_absolute(output)
	if native:
		await compare_native(sample,output.path_join("synthetic"))
		await native_anchor(sample)
	if "--fixture" in args:
		var path: String = args[args.find("--fixture")+1]
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var passes := {}
		for pass_data: Dictionary in report.render_passes:
			passes[int(pass_data.sequence)] = pass_data
			compare_geometry(pass_data)
		if native:
			for entry: Dictionary in report.ui_presentations:
				if entry.stage not in ["baseline","driver-centered","driver-turned","driver-reversed","driver-aligned","gunner-settled"]: continue
				var pass_data: Dictionary = passes[int(entry.draw_sequence)]
				await compare_native(pass_data,output.path_join(entry.stage))
				var presentation: Dictionary = report.presentations[entry.frame_index].duplicate(true)
				presentation.draw_pass = pass_data
				var source := Image.load_from_file(path.get_base_dir().path_join(entry.image))
				var ui := Image.load_from_file(path.get_base_dir().path_join(entry.mask))
				presentation.ui_overlay.mask_png = Marshalls.raw_to_base64(ui.save_png_to_buffer())
				check(composite.set_frame(source,presentation,viewport.get_texture()),"paired original UI composition")
				var result := await snapshot(composite_view)
				for y in 200:
					for x in 320:
						if ui.get_pixel(x,y).r == 1.0:
							ui_pixels += 1
							check(result.get_pixel(x*4+2,y*4+2).to_rgba32()==source.get_pixel(x,y).to_rgba32(),"terrain overwrote original UI")
	var receipt := {"checks":checks,"errors":errors,"native":native,"native_pixels":native_pixels,
		"changed_terrain_pixels":changed_pixels,"protected_ui_pixels":ui_pixels,
		"scope":"unchanged triangle geometry/order and original data; bounded native terrain-only changes and source UI protection"}
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"  "))
	for error in errors: printerr(error)
	print("PC_TERRAIN_STYLE: ",JSON.stringify(receipt))
	quit(0 if errors.is_empty() else 1)

func compare_geometry(pass_data: Dictionary, require_terrain := false) -> void:
	var before := JSON.stringify(pass_data)
	draw.presentation_palette = genesis.for_original(pass_data.palette_rgb)
	draw.terrain_style = null
	draw.apply_pass(pass_data)
	var plain: Array = draw.mesh_node.mesh.surface_get_arrays(0) if draw.mesh_node.mesh else []
	draw.terrain_style = style
	draw.apply_pass(pass_data)
	var detailed: Array = draw.mesh_node.mesh.surface_get_arrays(0) if draw.mesh_node.mesh else []
	if plain.is_empty() or detailed.is_empty():
		check(plain.is_empty() and detailed.is_empty() and not require_terrain,"draw pass geometry missing or changed by terrain")
	else:
		check(plain[Mesh.ARRAY_VERTEX]==detailed[Mesh.ARRAY_VERTEX],"terrain changed original triangle geometry/order")
		var neutral: PackedVector2Array = plain[Mesh.ARRAY_TEX_UV]
		var tagged: PackedVector2Array = detailed[Mesh.ARRAY_TEX_UV]
		check(neutral.size()==tagged.size(),"terrain changed triangle count")
		for i in neutral.size(): check(neutral[i].x==tagged[i].x,"terrain changed original material identity")
		if require_terrain:
			var kinds := 0
			for i in mini(neutral.size(),tagged.size()): if tagged[i].y!=neutral[i].y: kinds+=1
			check(kinds>0,"terrain kind never tagged on styled ground")
	check(JSON.stringify(pass_data)==before,"terrain mutated original data")
	check(draw.render_warnings.is_empty(),"unexpected terrain surface warnings")

func compare_native(pass_data: Dictionary, prefix: String) -> void:
	setup_frame(pass_data.camera)
	draw.presentation_palette = genesis.for_original(pass_data.palette_rgb)
	draw.terrain_style = null
	draw.apply_pass(pass_data)
	var plain := await snapshot(viewport)
	draw.terrain_style = style
	draw.apply_pass(pass_data)
	var detailed := await snapshot(viewport)
	var mesh: ArrayMesh = draw.mesh_node.mesh
	var original: Material = mesh.surface_get_material(0)
	var classifier := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial;render_mode unshaded,cull_disabled,depth_test_disabled,depth_draw_never,fog_disabled;void fragment(){ALBEDO=UV.y>0.5?vec3(1.0):vec3(0.0);}"
	classifier.shader = shader
	mesh.surface_set_material(0,classifier)
	var mask := await snapshot(viewport)
	mesh.surface_set_material(0,original)
	var view_changes := 0
	for y in detailed.get_height():
		for x in detailed.get_width():
			native_pixels += 1
			var a := plain.get_pixel(x,y)
			var b := detailed.get_pixel(x,y)
			var changed := a.to_rgba32()!=b.to_rgba32()
			if mask.get_pixel(x,y).r < 0.5: check(not changed,"terrain changed sky/vehicle/effect or unclassified surface")
			elif changed:
				changed_pixels += 1
				view_changes += 1
				check(absf(a.r-b.r)<=0.251 and absf(a.g-b.g)<=0.251 and absf(a.b-b.b)<=0.251,"terrain exceeded authored RGB contrast bound")
	check(plain.save_png(prefix+"-flat.png")==OK,"save baseline view")
	check(detailed.save_png(prefix+"-detail.png")==OK,"save detail view")
	check(view_changes>100,"native view has no actual detail: "+prefix)

func native_anchor(sample: Dictionary) -> void:
	# Known continuous ramp gives an independent analytic shader-coordinate check.
	var ramp := Image.create_empty(256,256,false,Image.FORMAT_RGB8)
	for y in 256:
		for x in 256: ramp.set_pixel(x,y,Color8(x,x,x))
	ramp.generate_mipmaps()
	var saved: Dictionary = style.textures.duplicate()
	style.textures.road = ImageTexture.create_from_image(ramp)
	style.textures.field = style.textures.road
	for is_road in [true,false]:
		for rotated in [false,true]:
			for shift in [0,64,4096]:
				var moved := sample.duplicate(true)
				moved.camera.world_position_raw[0] = shift
				if rotated: moved.camera.matrix_q14_columns = [0,16384,0,-16384,0,0,0,0,16384]
				if not is_road: moved.objects = []
				setup_frame(moved.camera)
				draw.terrain_style = style
				draw.apply_pass(moved)
				var im := await snapshot(viewport)
				for x in range(600,800,17):
					var pixel := Vector2(32+(float(x)+0.5)/4,13+(float(320)+0.5)/4)
					var depth: float = 128.0*128.0/(pixel.y-61.0)
					var east: float = shift+(depth if rotated else (pixel.x-159.0)*depth/128.0)
					var u: float = fposmod(east/(256.0 if is_road else 512.0),1.0)
					if u < 0.02 or u > 0.98: continue
					var mean: float = 0.4546305661 if is_road else 0.4323640162
					var expected_level := clampi(roundi(16+((u*256.0-0.5)/255.0-mean)*64),0,32)
					var rgb := Terrain.detail_rgb(genesis.palette[3 if is_road else 8],expected_level)
					check(im.get_pixel(x,320).to_rgba32()==Color8(rgb[0],rgb[1],rgb[2]).to_rgba32(),"native world texture anchor differs, road="+str(is_road)+", shift="+str(shift))
	style.textures = saved
