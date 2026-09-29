extends "res://tests/test_pc_modern.gd"
## Static sky/water/foliage regression and bounded native GPU comparisons.
var rows:=[]
func _initialize() -> void: run.call_deferred()

func capture() -> Image:
	await process_frame
	RenderingServer.force_draw(false);RenderingServer.force_sync()
	return viewport.get_texture().get_image()

func setting(enabled:bool) -> Image:
	draw.mesh_node.mesh.surface_get_material(0).set_shader_parameter("modern_environment_polish",enabled)
	return await capture()

func study(data:Dictionary,name:String,changed_expected:bool) -> void:
	var input:=JSON.stringify(data)
	var fresh:=await render(data,true)
	var geometry:PackedVector3Array=draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
	var original:=await setting(false)
	var restored:=await setting(true)
	check(fresh.get_data()==restored.get_data(),name+": exact restoration")
	check(fresh.get_data()==(await capture()).get_data(),name+": no wall-clock animation")
	check(geometry==draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],name+": immutable geometry")
	check(JSON.stringify(data)==input,name+": immutable source packet")
	var changed:=0;var outside:=0
	var black:=Color.BLACK
	for y in fresh.get_height():
		for x in fresh.get_width():
			var a:=original.get_pixel(x,y);var b:=fresh.get_pixel(x,y)
			if a!=b:
				changed+=1
				if name!="sky" and a==black:outside+=1
	check((changed>100 if changed_expected else changed==0),name+": scoped visible change")
	check(outside==0,name+": alpha/geometry coverage retained")
	fresh.save_png(output.path_join(name+"-after.png"));original.save_png(output.path_join(name+"-before.png"))
	var build_count:int=draw.mesh_build_count
	draw.apply_pass(data)
	if draw._modern_active: check(draw.mesh_build_count==build_count,name+": same-frame mesh cache retained")
	if name=="sky":
		var material:ShaderMaterial=draw.mesh_node.mesh.surface_get_material(0)
		var origin:Vector3=material.get_shader_parameter("world_origin")
		material.set_shader_parameter("world_origin",origin+Vector3(5000,8000,0))
		# A source sky is infinitely distant; translation cannot shift clouds.
		var moved:=await capture()
		check(moved.get_pixel(100,50)==fresh.get_pixel(100,50),"sky: independent of camera translation")
		material.set_shader_parameter("world_origin",origin)
		var before_basis:Basis=material.get_shader_parameter("camera_to_local")
		material.set_shader_parameter("camera_to_local",Basis(Vector3(0,0,1),0.8)*before_basis)
		check((await capture()).get_region(Rect2i(0,0,1280,170)).get_data()!=fresh.get_region(Rect2i(0,0,1280,170)).get_data(),"sky: clouds follow original view orientation")
		material.set_shader_parameter("camera_to_local",before_basis)
		check((await capture()).get_data()==fresh.get_data(),"sky: camera restore exact")
		# Ground and the source actor in the sky cannot receive cloud shading.
		check(fresh.get_pixel(500,600)==original.get_pixel(500,600),"sky: unchanged ground")
		check(fresh.get_pixel(640,220)==original.get_pixel(640,220),"sky: actor remains unobscured")
		check(fresh.get_pixel(100,40).b>fresh.get_pixel(100,40).r,"sky: blue upper sky")
		check(fresh.get_pixel(100,360).r>fresh.get_pixel(100,40).r,"sky: paler horizon")
		var timings:=[]
		for iteration in 4:
			material.set_shader_parameter("modern_environment_polish",iteration%2==1)
			await capture()
			var begin:=Time.get_ticks_usec()
			for tick in 40:
				RenderingServer.force_draw(false);RenderingServer.force_sync()
			timings.append(float(Time.get_ticks_usec()-begin)/40000.0)
		rows.append({"case":name,"changed_pixels":changed,"gpu_sync_ms_alternating_before_after":timings})
	else:rows.append({"case":name,"changed_pixels":changed,"outside":outside})
	var legacy:=await render(data,false)
	var old:=Shader.new()
	old.code=FileAccess.get_file_as_string(directory.path_join("artifacts/modern-environment-polish-20260929/before/godot/scripts/pc_surface.gdshader"))
	draw.mesh_node.mesh.surface_get_material(0).shader=old
	check((await capture()).get_data()==legacy.get_data(),name+": legacy pixel identity")

func model_packet(catalog:Dictionary,shape:int) -> Dictionary:
	var model:Dictionary=catalog.models[shape]
	var data:=packet();data.objects=[];data.background={"kind":"solid","color":0}
	var object:={"shape_index":shape,"root":int(model.roots[0].offset),"static_path":true,"dynamic_instance":false,"polygons":[],"world_delta":[1200,2400,0]}
	var center:Vector3=(Modern.vec(model.source_bounds.min)+Modern.vec(model.source_bounds.max))*0.5
	var dim:Vector3=Modern.vec(model.source_bounds.max)-Modern.vec(model.source_bounds.min)
	var depth:=maxf(160.0,maxf(dim.x,maxf(dim.y,dim.z))*1.7)
	var rotation:=Basis(Vector3.RIGHT,-0.6) if shape==40 else Basis(Vector3(0,0,1),0.4)
	var selected:={}
	for group:Dictionary in model.groups:
		if group.offset in model.roots[0].group_pointers:
			for pid in group.primitive_pointers:selected[int(pid)]=true
	for primitive:Dictionary in model.source_primitives:
		if primitive.vertices.size()<3 or int(primitive.id) not in selected:continue
		var points:=[]
		for raw:Array in primitive.vertices:
			var p:=rotation*(Modern.vec(raw)-center);points.append([p.x,p.y+depth,p.z])
		object.polygons.append({"primitive":int(primitive.id),"fill_mode":1,"colors":[int(primitive.prefix_bytes[1]),int(primitive.prefix_bytes[2])],"camera_vertices":points})
	data.objects=[object];data.camera.world_position_raw=[0,0,50]
	return data

func run() -> void:
	if DisplayServer.get_name()=="headless":printerr("FAIL: native GPU required");quit(2);return
	directory=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args:=OS.get_cmdline_user_args()
	output=args[args.find("--output")+1] if "--output" in args else directory.path_join("artifacts/modern-environment-polish-20260929/environment")
	DirAccess.make_dir_recursive_absolute(output)
	viewport=SubViewport.new();viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	camera=Camera3D.new();viewport.add_child(camera);camera.make_current()
	draw=Draw.new();draw.solid_enabled=true;draw.modern_assets=art;camera.add_child(draw)
	check(draw.load_modern_assets(directory),"production models loaded")
	draw.terrain_style=preload("res://scripts/pc_terrain_style.gd").new()
	check(draw.terrain_style.load_assets(directory.path_join("local-art/pc-terrain-remastered/detail-v1")),"terrain loaded")
	check(draw.terrain_style.load_hills(directory),"hills loaded")
	var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("local-art/pc-modern/catalog.json")))
	var data:=packet()
	data.camera.world_position_raw=[0,0,50]
	data.background={"kind":"horizon","line":[[0,100],[319,100]],"colors":[5,8]}
	data.objects[0].shape_index=-1
	data.objects[0].polygons[0].colors=[9,9]
	data.objects[0].polygons[0].camera_vertices=[[-15,160,25],[15,160,25],[15,160,45],[-15,160,45]]
	await study(data,"sky",true)
	await study(model_packet(catalog,40),"water",true)
	await study(model_packet(catalog,103),"tree",true)
	await study(model_packet(catalog,49),"road",false)
	var variant:=Modern.tree_colour_variant({"world_delta":[1200,2400,0]},{"world_position_raw":[10000,20000,50]})
	check(variant==Modern.tree_colour_variant({"world_delta":[1100,2450,0]},{"world_position_raw":[10100,20050,50]}),"tree hue stays at source placement under camera movement")
	check(variant!=Modern.tree_colour_variant({"world_delta":[1350,2300,0]},{"world_position_raw":[10000,20000,50]}),"tree placements receive restrained variation")
	data.palette_rgb[5]=[12,13,14]
	await study(data,"unsupported-palette",false)
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":failures,"cases":rows},"  "))
	for failure in failures:printerr("FAIL: "+failure)
	print("PC_ENVIRONMENT_POLISH: %d checks, %d errors"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
