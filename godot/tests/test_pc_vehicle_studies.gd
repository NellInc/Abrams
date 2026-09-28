extends SceneTree
## Native import/render checks for local source-fitted vehicle authoring assets.
var errors: Array[String] = []
var checks := 0
var observations := []
func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok and errors.size()<20: errors.append(why)
func _initialize() -> void: run.call_deferred()
func meshes(node: Node) -> Array:
	var result := []
	if node is MeshInstance3D: result.append(node)
	for child in node.get_children(): result.append_array(meshes(child))
	return result
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var assets := args[args.find("--assets")+1]
	var output := args[args.find("--output")+1]
	var native := "--native" in args
	DirAccess.make_dir_recursive_absolute(output)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(assets.path_join("manifest.json")))
	var catalog_path := directory.path_join("reference/pc-vehicles/source-v1")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(catalog_path.path_join("catalog.json")))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,800)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new(); viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("192126")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .5
	world.add_child(environment)
	var light := DirectionalLight3D.new();world.add_child(light)
	light.rotation_degrees=Vector3(-35,-45,0);light.light_energy=1.2
	var camera := Camera3D.new();world.add_child(camera);camera.make_current()
	for entry in manifest.models:
		var path: String = assets.path_join(entry.glb)
		check(FileAccess.get_sha256(path)==entry.glb_sha256,"GLB fingerprint differs")
		var reference: Dictionary = catalog.models.filter(func(m):return m.shape_index==entry.shape_index)[0]
		var source_path := catalog_path.path_join(reference.json)
		check(FileAccess.get_sha256(source_path)==entry.source_json_sha256,"source model fingerprint differs")
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_path))
		var minimum := Vector3(INF,INF,INF);var maximum := Vector3(-INF,-INF,-INF)
		for primitive in source.primitives:
			for raw in primitive.vertices:
				var point := Vector3(raw[0],raw[2],-raw[1])/64.0
				minimum=minimum.min(point);maximum=maximum.max(point)
		var document := GLTFDocument.new();var state := GLTFState.new()
		var loaded := document.append_from_file(path,state)
		check(loaded==OK,"Godot could not import "+entry.glb)
		if loaded!=OK:continue
		var model := document.generate_scene(state)
		check(model!=null,"Godot could not instantiate "+entry.glb)
		if model==null:continue
		world.add_child(model)
		await process_frame
		var pieces := meshes(model)
		var total := 0;var overshoot := 0.0
		for piece in pieces:
			for local in piece.mesh.get_faces():
				var point: Vector3 = piece.global_transform*local
				check(point.is_finite(),"non-finite restored vertex")
				for axis in 3:overshoot=maxf(overshoot,maxf(minimum[axis]-point[axis],point[axis]-maximum[axis]))
				total+=1
		check(not pieces.is_empty() and total>100,"restored mesh geometry missing")
		check(pieces.size()<=10,"study requires excessive separate mesh objects")
		check(overshoot<=.65/64.0+.00001,"restored geometry escaped declared source envelope: "+str(overshoot*64))
		var centre := (minimum+maximum)*.5
		var extent := (maximum-minimum).length()
		camera.position=centre+Vector3(1,.7,-1.4).normalized()*extent*1.65
		camera.look_at(centre)
		if native:
			await process_frame
			RenderingServer.force_draw(false);RenderingServer.force_sync()
			var image := viewport.get_texture().get_image()
			var colors := {}
			for y in range(0,800,4):
				for x in range(0,1280,4):colors[image.get_pixel(x,y).to_rgba32()]=true
			check(colors.size()>100,"native vehicle render lacks visible shaded geometry")
			image.save_png(output.path_join(str(int(entry.shape_index))+".png"))
		observations.append({"shape_index":entry.shape_index,"name":entry.name,"mesh_objects":pieces.size(),"triangle_vertices":total,"max_axis_expansion_raw":overshoot*64})
		model.queue_free()
		await process_frame
	check(observations.size()==3,"expected three actual imported vehicle studies")
	var report := {"checks":checks,"errors":errors,"native":native,"models":observations,"scope":"Source envelope, GLB fingerprints, Godot import and actual native shading; no live visibility/animation/parity claim"}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PC_VEHICLE_STUDIES: ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
