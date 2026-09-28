extends SceneTree
## Import/render proof for local Genesis-source authoring studies, never live parity.
var errors: Array[String] = []
var checks := 0

func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok and errors.size()<20: errors.append(why)

func _initialize() -> void: run.call_deferred()

func pieces(node: Node) -> Array:
	var result := []
	if node is MeshInstance3D: result.append(node)
	for child in node.get_children(): result.append_array(pieces(child))
	return result

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var assets := directory.path_join("local-art/genesis/vehicles-source-fitted-v1")
	var output := directory.path_join("artifacts/genesis-vehicle-studies-check")
	for option in ["--assets","--output"]:
		if option in args:
			var index := args.find(option)+1
			if index>=args.size():
				printerr("Missing path for "+option)
				quit(2)
				return
			if option=="--assets": assets=args[index]
			else: output=args[index]
	var native := "--native" in args
	var manifest_path := assets.path_join("manifest.json")
	if not FileAccess.file_exists(manifest_path):
		printerr("Missing local Genesis authoring study manifest: "+manifest_path)
		quit(1)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary or not parsed.get("models") is Array:
		printerr("Invalid Genesis authoring study manifest")
		quit(1)
		return
	var manifest: Dictionary = parsed
	check(manifest.rom_sha256=="ff83dc53b33252d42ac624e11a2ce717428b75f48f2e56a20b3d38f78e6ca4ea","Genesis source fingerprint")
	check(FileAccess.get_sha256(manifest.source.path_join("catalog.json"))==manifest.source_catalog_sha256,"source catalog unchanged")
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1280,800)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("24313a")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=.65
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees=Vector3(-35,-45,0)
	light.light_energy=.8
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.make_current()
	var observations := []
	var indices := []
	for entry in manifest.models:
		indices.append(int(entry.index))
		var path: String = assets.path_join(entry.glb)
		check(FileAccess.get_sha256(path)==entry.glb_sha256,"GLB hash: "+entry.glb)
		var source_path: String = manifest.source.path_join("shape-%03d.json"%int(entry.index))
		check(FileAccess.get_sha256(source_path)==entry.source_model_sha256,"model source unchanged")
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_path))
		var minimum := Vector3(INF,INF,INF)
		var maximum := Vector3(-INF,-INF,-INF)
		for primitive in source.poses[0].polygons+source.poses[0].lines:
			for index in primitive.indices:
				var raw: Array = source.poses[0].vertices[str(int(index))]
				var point := Vector3(raw[0],raw[1],-raw[2])/64.0
				minimum=minimum.min(point)
				maximum=maximum.max(point)
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var loaded := document.append_from_file(path,state)
		check(loaded==OK,"Godot GLB import: "+entry.glb)
		if loaded!=OK: continue
		var model := document.generate_scene(state)
		check(model!=null,"Godot scene exists")
		if model==null: continue
		world.add_child(model)
		await process_frame
		var meshes := pieces(model)
		var vertices := 0
		var overshoot := 0.0
		for mesh in meshes:
			for surface in mesh.mesh.get_surface_count():
				var material: Material = mesh.get_active_material(surface)
				check(material is StandardMaterial3D and material.cull_mode==BaseMaterial3D.CULL_DISABLED,"source-union study uses declared double-sided materials")
			for local in mesh.mesh.get_faces():
				var point: Vector3 = mesh.global_transform*local
				check(point.is_finite(),"finite study vertex")
				for axis in 3: overshoot=maxf(overshoot,maxf(minimum[axis]-point[axis],point[axis]-maximum[axis]))
				vertices+=1
		check(meshes.size()>=3 and meshes.size()<=8,"source blocks remain bounded separate components")
		check(vertices>100,"actual refined geometry exists")
		check(overshoot<=.45/64.0+.00001,"study escaped declared source envelope")
		var center := (minimum+maximum)*.5
		var extent := (maximum-minimum).length()
		camera.size=extent*1.15
		var views := []
		if native:
			for direction in [Vector3(1,.6,-1.4),Vector3(1,.12,0),Vector3(-1,.4,1.4)]:
				camera.position=center+direction.normalized()*extent*2
				camera.look_at(center)
				await process_frame
				RenderingServer.force_draw(false)
				RenderingServer.force_sync()
				var image := viewport.get_texture().get_image()
				var colours := {}
				# The source intentionally has few flat colours. A colour-count
				# quota rejects faithful art; compare actual geometry ownership.
				var ownership := StandardMaterial3D.new()
				ownership.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
				ownership.cull_mode=BaseMaterial3D.CULL_DISABLED
				ownership.albedo_color=Color.MAGENTA
				for mesh in meshes: mesh.material_override=ownership
				await process_frame
				RenderingServer.force_draw(false)
				RenderingServer.force_sync()
				var mask := viewport.get_texture().get_image()
				for mesh in meshes: mesh.material_override=null
				var visible := 0
				var outside := 0
				var background := mask.get_pixel(0,0).to_rgba32()
				for y in range(0,800,4):
					for x in range(0,1280,4):
						var actual := image.get_pixel(x,y).to_rgba32()
						var owned := mask.get_pixel(x,y).to_rgba32()
						colours[actual]=true
						if owned==Color.MAGENTA.to_rgba32():
							visible+=1
							check(actual!=background and actual!=owned,"source material appears on rendered geometry")
						else:
							outside+=1
							check(owned==background and actual==background,"outside geometry retains the empty background")
				check(visible>1000 and outside>1000,"model and surrounding background both visible")
				var filename := "%d-view-%d.png"%[int(entry.index),views.size()]
				image.save_png(output.path_join(filename))
				mask.save_png(output.path_join(filename.trim_suffix(".png")+"-ownership.png"))
				views.append({"image":filename,"sampled_colours":colours.size(),"visible_samples":visible,"outside_samples":outside})
		observations.append({"index":entry.index,"mesh_objects":meshes.size(),"triangle_vertices":vertices,"axis_expansion_raw":overshoot*64,"views":views})
		model.queue_free()
		await process_frame
	check(indices==[115,125,129] and observations.size()==3,"all three selected Genesis studies imported")
	var report := {"checks":checks,"errors":errors,"native":native,"models":observations,
		"scope":"Source hashes, actual GLB import, finite geometry, declared envelope and three native views. No original visibility, animation, tactical-readability or final-art claim."}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	for error in errors: printerr("FAIL: "+error)
	print("GENESIS_VEHICLE_STUDIES: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
