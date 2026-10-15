extends SceneTree
const DrawPass = preload("res://scripts/pc_draw_pass.gd")
const PcCamera = preload("res://scripts/pc_camera.gd")
var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _initialize() -> void:
	create_timer(120).timeout.connect(func(): printerr("FAIL: draw-pass deadline"); quit(2))
	_run.call_deferred()

func _run() -> void:
	var view = DrawPass.new()
	root.add_child(view)
	check(DrawPass.camera_point([64,128,192]) == Vector3(1,3,-2), "original camera axes changed")
	view.apply_pass({"objects": [{"static_path": 1, "dynamic_instance": true, "polygons": [
		{"camera_vertices": [[0,128,0], [64,128,0], [0,128,64]]}]}]})
	check(view.polygon_count == 1 and view.dynamic_polygon_count == 1, "dynamic polygon count")
	check(view.mesh_node.mesh.surface_get_array_len(0) == 6, "original triangle wire has three edges")
	view.apply_pass({"objects": []})
	check(view.mesh_node.mesh == null and view.source_points.is_empty(), "empty pass must clear previous geometry")
	# Regression: Tactical must contain real range-style mesh instances, with
	# stable world placement and fail-closed source ownership eligibility.
	var foliage = view.tactical_foliage
	var field := {"shape_index":48,"root":5109,"static_path":true,"dynamic_instance":false,
		"polygons":[{"primitive":5123,"colors":[8,8],"fill_mode":1,
		"camera_vertices":[[-400,400,-50],[400,400,-50],[400,800,-50]]}]}
	var data := {"camera":{"clip":[0,0,255,95],"center":[128,48],"near_raw":16,"focal_pixels":128},
		"background":{"kind":"horizon","line":[[0,48],[255,48]],"colors":[5,8]},"objects":[field]}
	var mapping := {"inverse":Basis.IDENTITY,"origin":Vector3(79872,141312,50)}
	var blank := ImageTexture.create_from_image(Image.create(256,96,false,Image.FORMAT_RGBA8))
	foliage.prepare(data,mapping,blank)
	check(foliage.visible and foliage.instance_count>0 and foliage.instance_count<2000,"bounded real Tactical foliage missing")
	var shrubs: MultiMesh = foliage.plants[0].multimesh
	check(shrubs.mesh.get_surface_count()==1 and shrubs.instance_count>0,"actual shrub mesh missing")
	var mesh_arrays: Array=shrubs.mesh.surface_get_arrays(0)
	var materials: PackedVector2Array=mesh_arrays[Mesh.ARRAY_TEX_UV2]
	var canopy_low:=INF
	var canopy_high:=-INF
	var rooted_stems:=0
	var shrub_vertices: PackedVector3Array=mesh_arrays[Mesh.ARRAY_VERTEX]
	for i in shrub_vertices.size():
		if materials[i].x<0.25:
			canopy_low=minf(canopy_low,shrub_vertices[i].y)
			canopy_high=maxf(canopy_high,shrub_vertices[i].y)
		elif materials[i].x<0.75 and shrub_vertices[i].y==0.0: rooted_stems+=1
	check(canopy_low>=0.0 and canopy_high<=12.5,"shrub crown must remain above ground and below half-height")
	check(rooted_stems==50,"shorter shrub stems must still meet the ground")
	var has_ground:=false
	var has_stem:=false
	var lit_tones:=not materials.is_empty()
	for encoded: Vector2 in materials:
		has_ground=has_ground or encoded.x>0.75
		has_stem=has_stem or (encoded.x>0.25 and encoded.x<0.75)
		lit_tones=lit_tones and encoded.y>=0.8
	check(has_ground,"soft contact footprint missing")
	check(has_stem,"visible shrub stems missing")
	check(lit_tones,"foliage material UV2 lost its lighting tones")
	check(mesh_arrays[Mesh.ARRAY_VERTEX].size()<600,"shrub geometry exceeded bounded triangle budget")
	var normals: PackedVector3Array=mesh_arrays[Mesh.ARRAY_NORMAL]
	var soft_leaf_normals:=false
	var valid_normals:=true
	for i in normals.size():
		valid_normals=valid_normals and normals[i].is_finite() and absf(normals[i].length()-1.0)<0.001
		if i%3==0 and materials[i].x<0.25:
			soft_leaf_normals=soft_leaf_normals or not normals[i].is_equal_approx(normals[i+1])
	check(valid_normals and soft_leaf_normals,"rounded shrub normals must remain finite and unit length")
	check(mesh_arrays[Mesh.ARRAY_VERTEX].size()==441,"rounded shrub exceeded its 147-triangle design")
	check(foliage.plants.size()==2,"vegetation added a rendering batch")
	check(foliage.plants[1].multimesh.mesh.surface_get_array_len(0)==96,"grass changed its 32-triangle budget")
	var source_before:=JSON.stringify(data)
	var buffer_before: PackedFloat32Array=shrubs.buffer.duplicate()
	var position := shrubs.get_instance_transform(0)
	var count: int = foliage.instance_count
	var builds: int=foliage._grid_build_count
	foliage.prepare(data,mapping,blank)
	check(foliage.instance_count==count and shrubs.get_instance_transform(0)==position,"stationary foliage drift")
	check(shrubs.buffer==buffer_before,"stationary plant proportions or colours drifted")
	check(JSON.stringify(data)==source_before,"vegetation changed the source packet")
	check(foliage._grid_build_count==builds,"stationary planting grid rebuilt")
	var moved: Dictionary=mapping.duplicate()
	moved.origin=mapping.origin+Vector3(0.1,0.1,0)
	foliage.prepare(data,moved,blank)
	check(foliage._grid_build_count==builds,"same-cell camera motion rebuilt planting grid")
	moved.origin=mapping.origin+Vector3(220,220,0)
	foliage.prepare(data,moved,blank)
	check(foliage._grid_build_count==builds+2,"cross-cell camera motion did not refresh both grids")
	foliage.prepare(data,mapping,blank)
	check(foliage.instance_count==count and shrubs.get_instance_transform(0)==position,"returning camera changed deterministic planting")
	var rotated: Dictionary=mapping.duplicate()
	rotated.inverse=Basis(Vector3(0,0,1),0.4)
	foliage.prepare(data,rotated,blank)
	check(shrubs.instance_count>0,"rotated view lost every shrub")
	var proportions_stable:=true
	for i in shrubs.instance_count:
		var basis: Basis=shrubs.get_instance_transform(i).basis
		var seed: float=shrubs.get_instance_custom_data(i).b
		proportions_stable=proportions_stable and absf(basis.x.length()/basis.y.length()-(0.86+seed*0.28)/(0.90+seed*0.20))<0.0001
	check(proportions_stable,"camera rotation changed plant-local proportions")
	foliage.prepare(data,mapping,blank)
	var mask: Texture2D = foliage.material.get_shader_parameter("allowed_ground")
	check(mask.get_image().get_pixel(1,0).r>0.5,"verified flat field rejected")
	field.polygons.append({"primitive":999,"colors":[8,8],"fill_mode":1,"camera_vertices":[[-400,400,-50],[400,400,-50],[400,800,-50]]})
	foliage.prepare(data,mapping,blank)
	mask=foliage.material.get_shader_parameter("allowed_ground")
	check(mask.get_image().get_pixel(1,0).r<0.5,"one field face must not whitelist other object commands")
	view.tactical_landscape=false
	check(not foliage.visible and foliage.instance_count==0,"Modernized retained decorative foliage")
	data.background={"kind":"solid","color":8}
	foliage.prepare(data,mapping,blank)
	check(not foliage.visible,"unsupported background retained foliage")
	view.queue_free()
	await process_frame
	var args := OS.get_cmdline_user_args()
	var projected := 0
	var pass_count := 0
	var maximum_error := 0.0
	var capture_path := ""
	var sprites := 0
	if args.size() >= 2 and args[0] == "--fixture":
		var fixture = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
		if not fixture is Dictionary or fixture.get("render_passes", []).is_empty():
			printerr("FAIL: recorded original draw passes unavailable")
			quit(1)
			return
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var display := TextureRect.new()
		display.texture = viewport.get_texture()
		display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		root.add_child(display)
		display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("293338")
		viewport.add_child(environment)
		var camera := Camera3D.new()
		viewport.add_child(camera)
		camera.make_current()
		var drawn = DrawPass.new()
		drawn.solid_enabled = "--solid" in args
		camera.add_child(drawn)
		for pass_data in fixture.render_passes:
			var frame: Dictionary = pass_data.camera.duplicate(true)
			# Captured vertices already include the original composed camera
			# transform. Applying it twice would rotate the drawing incorrectly.
			frame.matrix_q14_columns = [16384,0,0,0,16384,0,0,0,16384]
			frame.world_position_raw = [0,0,0]
			var dimensions := PcCamera.apply(camera, frame, Vector3.ZERO)
			viewport.size = dimensions * 4
			drawn.apply_pass(pass_data)
			if drawn.solid_enabled:
				var expected_sprites := 0
				for object: Dictionary in pass_data.objects:
					if object.get("sprite") is Dictionary: expected_sprites += 1
				check(drawn.sprite_count == expected_sprites, "observed sprite count differs")
				sprites += drawn.sprite_count
			check(drawn.render_warnings.is_empty(), "surface warnings in draw pass %s: %s" % [str(pass_data.sequence), str(drawn.render_warnings)])
			await process_frame
			pass_count += 1
			for point in drawn.source_points:
				if float(point[1]) < float(frame.near_raw): continue
				var expected := Vector2(float(frame.center[0]) + float(point[0]) * float(frame.focal_pixels) / float(point[1]) - float(frame.clip[0]),
					float(frame.center[1]) - float(point[2]) * float(frame.focal_pixels) / float(point[1]) - float(frame.clip[1]))
				var actual := camera.unproject_position(DrawPass.camera_point(point)) / 4.0
				var error := actual.distance_to(expected)
				maximum_error = maxf(maximum_error, error)
				if error >= 0.01 and failures.size() < 5:
					failures.append("point=%s actual=%s expected=%s viewport=%s" % [str(point), str(actual), str(expected), str(viewport.size)])
				projected += 1
		check(projected > 0 and drawn.dynamic_polygon_count > 0, "fixture must include projected vehicle geometry")
		if "--capture" in args:
			var at := args.find("--capture") + 1
			capture_path = args[at] if at < args.size() and not args[at].begins_with("--") else ""
			if capture_path.is_empty():
				check(false, "missing value for --capture")
			elif DisplayServer.get_name() == "headless":
				check(false, "native capture requires a windowed run (omit --headless)")
			else:
				await process_frame
				# An occluded macOS window can stop emitting frame_post_draw indefinitely.
				RenderingServer.force_draw(false)
				RenderingServer.force_sync()
				var image := viewport.get_texture().get_image()
				check(image != null and not image.is_empty() and image.save_png(capture_path) == OK, "native capture failed")
		print("PC_DRAW_PASS_FIXTURE: %d passes, %d projections, maximum error %.6f source pixels; %d dynamic polygons in final pass" % [pass_count, projected, maximum_error, drawn.dynamic_polygon_count])
		print("PC_DRAW_PASS_SPRITES: %d" % sprites)
	if "--foliage-lighting" in args:
		await foliage_lighting(args[args.find("--foliage-lighting")+1])
	print("PC_DRAW_PASS: %d checks, %d errors" % [checks, failures.size()])
	for message in failures: printerr("FAIL: " + message)
	quit(0 if failures.is_empty() else 1)

# Optional rendered material regression: production meshes and ownership shader,
# staged close for inspection. These images are studies, not mission captures.
func foliage_capture(viewport: SubViewport) -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return viewport.get_texture().get_image()

func foliage_lighting(baseline_path: String) -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(384,384)
	viewport.own_world_3d=true
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=1.5
	viewport.add_child(camera)
	camera.make_current()
	var plants := preload("res://scripts/pc_tactical_foliage.gd").new()
	viewport.add_child(plants)
	plants.visible=true
	var realism:bool="--foliage-textures" in OS.get_cmdline_user_args()
	if realism:
		var textures:=preload("res://scripts/pc_modern_assets.gd").new()
		check(textures.load_material_textures("res://tests/fixture-root"),"foliage prior material textures")
		check(textures.load_realism_atlas("res://tests/fixture-root"),"foliage verified material atlas")
		plants.set_material_atlas(textures.material_atlas)
	var aerial:bool="--foliage-aerial" in OS.get_cmdline_user_args()
	var radiance:bool="--foliage-radiance" in OS.get_cmdline_user_args()
	var filtered:bool="--foliage-highlight-filter" in OS.get_cmdline_user_args()
	if filtered:viewport.size=Vector2i(96,96)
	var layer_changes: Array[int]=[0,0]
	var old := Shader.new()
	old.code=FileAccess.get_file_as_string(baseline_path)
	var current: Shader=plants.material.shader
	var owner := Image.create(1,1,false,Image.FORMAT_RGBA8)
	owner.fill(Color.BLACK)
	var allowed := Image.create(1,1,false,Image.FORMAT_RGBA8)
	allowed.fill(Color.WHITE)
	var uniforms := {"source_ownership":ImageTexture.create_from_image(owner),"allowed_ground":ImageTexture.create_from_image(allowed),"owner_count":1.0,"source_origin":Vector2.ZERO,"source_dimensions":Vector2(viewport.size),"source_center":Vector2(viewport.size.x/2,0),"source_focal":float(viewport.size.x/2),"camera_to_local":Basis.IDENTITY,"horizon":Vector3(0,0,1),"source_eye_height":50.0 if aerial else 0.0}
	for key: String in uniforms: plants.material.set_shader_parameter(key,uniforms[key])
	for layer in 2:
		var mesh: MultiMesh=plants.plants[layer].multimesh
		mesh.instance_count=1
		mesh.set_instance_custom_data(0,Color(0.5,0.8,0.6,float(layer)))
		for angle in [0.0,PI*0.5,PI]:
			plants.material.set_shader_parameter("camera_to_local",Basis(Vector3(0,0,1),-angle))
			mesh.set_instance_transform(0,Transform3D(Basis(Vector3.UP,angle).scaled(Vector3.ONE*0.05),Vector3(0,-0.55,-48 if aerial else -3)))
			var before_buffer: PackedFloat32Array=mesh.buffer.duplicate()
			plants.material.shader=old
			var before := await foliage_capture(viewport)
			plants.material.shader=current
			var after := await foliage_capture(viewport)
			var changed:=0
			var coverage:=0
			var max_channel:=0.0
			for y in after.get_height():
				for x in after.get_width():
					var a:=before.get_pixel(x,y);var b:=after.get_pixel(x,y)
					if a!=b: changed+=1
					if a.a!=b.a: coverage+=1
					max_channel=maxf(max_channel,maxf(b.r,maxf(b.g,b.b)))
			var label:="foliage-%d-%d" % [layer,roundi(rad_to_deg(angle))]
			layer_changes[layer]+=changed
			if filtered:check(changed>0,label+": resolution-aware sheen is observable")
			else:check(changed>100,label+": visible leaf lighting")
			check(coverage==0,label+": exact coverage")
			check(max_channel<0.8,label+": restrained highlights")
			check(mesh.buffer==before_buffer,label+": unchanged instances")
			check(after.get_data()==(await foliage_capture(viewport)).get_data(),label+": static between frames")
			if (filtered or aerial) and OS.has_feature("web"):
				JavaScriptBridge.eval("window.foliageImages=window.foliageImages||{};window.foliageImages["+JSON.stringify(label)+"]="+JSON.stringify([Marshalls.raw_to_base64(before.save_png_to_buffer()),Marshalls.raw_to_base64(after.save_png_to_buffer())]))
			if OS.has_feature("web"):
				print("FOLIAGE_IMAGE "+label+" "+Marshalls.raw_to_base64(after.save_png_to_buffer()))
		if aerial:
			mesh.set_instance_transform(0,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*0.05),Vector3(0,-0.55,-3)))
			plants.material.set_shader_parameter("camera_to_local",Basis.IDENTITY)
			plants.material.shader=old
			var near_before:Image=await foliage_capture(viewport)
			plants.material.shader=current
			var near_after:Image=await foliage_capture(viewport)
			if radiance:
				var coverage:=0;var changed:=0
				for y in near_after.get_height():
					for x in near_after.get_width():
						if near_before.get_pixel(x,y)!=near_after.get_pixel(x,y):changed+=1
						if near_before.get_pixel(x,y).a!=near_after.get_pixel(x,y).a:coverage+=1
				check(changed>100,"near foliage receives coherent fill for layer "+str(layer))
				check(coverage==0,"near foliage coverage remains exact for layer "+str(layer))
				if OS.has_feature("web"):
					JavaScriptBridge.eval("window.foliageImages["+JSON.stringify("foliage-near-"+str(layer))+"]="+JSON.stringify([Marshalls.raw_to_base64(near_before.save_png_to_buffer()),Marshalls.raw_to_base64(near_after.save_png_to_buffer())]))
			else:check(near_before.get_data()==near_after.get_data(),"near foliage retains preceding colour for layer "+str(layer))
		if filtered:check(layer_changes[layer]>0,"compact leaf sheen filtering is visible for layer "+str(layer))
		mesh.instance_count=0
	# Force the existing bark and footprint branches independently: lighting
	# changes must leave these non-leaf materials byte-identical.
	plants.plants[0].multimesh.instance_count=1
	plants.plants[0].multimesh.set_instance_transform(0,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*0.05),Vector3(0,-0.55,-48 if aerial else -3)))
	plants.plants[0].multimesh.set_instance_custom_data(0,Color(0.5,0.8,0.6,0))
	for kind in ["0.5","1.0"]:
		var a := Shader.new();a.code=old.code.replace("material_kind=UV2.x;","material_kind="+kind+";")
		var b := Shader.new();b.code=current.code.replace("material_kind=UV2.x;","material_kind="+kind+";")
		plants.material.shader=a
		var before := await foliage_capture(viewport)
		plants.material.shader=b
		var after:=await foliage_capture(viewport)
		if (realism and not filtered or aerial) and kind=="0.5":
			check(before.get_data()!=after.get_data(),"bark receives coherent daylight colour" if radiance else "textured bark has visible relief")
			var coverage:int=0
			for y in after.get_height():
				for x in after.get_width():
					if before.get_pixel(x,y).a!=after.get_pixel(x,y).a:coverage+=1
			check(coverage==0,"textured bark coverage")
		else:check(before.get_data()==after.get_data(),"unchanged non-leaf branch "+kind)
	plants.material.shader=current
	allowed.fill(Color.BLACK)
	plants.material.set_shader_parameter("allowed_ground",ImageTexture.create_from_image(allowed))
	var rejected := await foliage_capture(viewport)
	check(rejected.is_invisible(),"foliage lighting still rejects disallowed source ownership")
	viewport.queue_free()
	await process_frame
