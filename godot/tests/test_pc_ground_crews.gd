extends "res://tests/test_pc_tactical_vehicles.gd"
## R13 optional firing-pose schema, atomic admission and same-geometry coverage.
const CrewPose=preload("res://scripts/pc_tactical_crew_pose.gd")
var pose_rows:Array=[]

func run() -> void:
	directory=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	output=directory.path_join("artifacts/tactical-crew-refinement-20261021-r13/runtime-pose")
	var args:=OS.get_cmdline_user_args()
	if "--output" in args:output=directory.path_join(args[args.find("--output")+1]) if not args[args.find("--output")+1].is_absolute_path() else args[args.find("--output")+1]
	DirAccess.make_dir_recursive_absolute(output)
	var catalog:=art.load_catalogue(directory)
	print("PC_CREW_PHASE: raw-schema begin ",Time.get_ticks_msec()-started)
	# End the large raw catalogue's scope before loading compiled assets.
	# Working if unchanged schema/pixel checks stay below the existing RSS cap.
	var source_models:=check_pose_sources(catalog,"--schema-only" in args)
	print("PC_CREW_PHASE: raw-schema complete ",Time.get_ticks_msec()-started)
	var vehicles:VehicleAssets
	print("PC_CREW_PHASE: production-load begin ",Time.get_ticks_msec()-started)
	if DisplayServer.get_name()=="headless":
		vehicles=VehicleAssets.new()
		check(vehicles.load_detail(directory),"pose gate production assets load")
	else:
		viewport=SubViewport.new();viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
		camera=Camera3D.new();viewport.add_child(camera);camera.make_current()
		draw=Draw.new();draw.solid_enabled=true;draw.modern_assets=art;camera.add_child(draw)
		check(draw.load_modern_assets(directory),"native production assets load")
		vehicles=draw.tactical_vehicle_assets
		check(vehicles.ready,"pose gate production assets load")
	if not vehicles.ready:finish();return
	print("PC_CREW_PHASE: production-load complete ",Time.get_ticks_msec()-started)
	var published_poses:Dictionary={}
	if "--schema-only" in args:
		# The pre-art smoke temporarily uses synthetic poses for admission only.
		# Restore the exact published pose set before any native pixel checks.
		published_poses=vehicles.gpu_poses.duplicate()
		vehicles.compile_gpu_poses({"models":source_models.values()})
	source_models.clear()
	check(vehicles.gpu_poses.size()==2 and 161 in vehicles.gpu_poses and 162 in vehicles.gpu_poses,"only both approved firing-pose models present")
	if vehicles.gpu_poses.size()!=2:finish();return
	_posed_shapes=vehicles.gpu_poses.keys()
	var subject:=VehicleView.new()
	for shape in _posed_shapes:
		var data:=model_packet(catalog,shape,-.6,.65,.3)
		check(not subject.admit_poses(vehicles,data).is_empty(),"complete witnessed pose admitted")
		for mutation in ["head","root","unknown","duplicate","order","shear","other-group","ambiguous-head","malformed-head","fractional-head"]:
			var bad:=data.duplicate(true);var object:Dictionary=bad.objects[0]
			match mutation:
				"head":object.round_forms[0].command[0]=0
				"root":object.root=-1
				"unknown":object.polygons[0].primitive=999999
				"duplicate":object.polygons.append(object.polygons[0].duplicate(true));object.draw_order.insert(0,{"kind":"polygon","index":object.polygons.size()-1})
				"order":object.draw_order[0].kind="unsupported"
				"shear":
					for polygon:Dictionary in object.polygons:
						for point:Array in polygon.camera_vertices:point[0]+=point[2]*.4
				"other-group":
					for point:Array in object.polygons[-1].camera_vertices:point[0]+=30
				"malformed-head":object.round_forms[0]=null
				"fractional-head":object.round_forms[0].command_offset+=.5
				"ambiguous-head":object.round_forms.append(object.round_forms[0].duplicate(true));object.draw_order.append({"kind":"round_form","index":1})
			check(subject.admit_poses(vehicles,bad).is_empty(),"complete atomic rejection "+mutation)
	subject.free()
	print("PC_CREW_PHASE: admission complete ",Time.get_ticks_msec()-started)
	if DisplayServer.get_name()=="headless":finish();return
	if "--schema-only" in args:vehicles.gpu_poses=published_poses
	print("PC_CREW_PHASE: pixels begin ",Time.get_ticks_msec()-started)
	draw.tactical_landscape=true
	for shape in _posed_shapes:
		for yaw in [0.0,PI*.5,PI]:
			for focal in [96.0,192.0]:
				var data:=model_packet(catalog,shape,-.6,yaw,.3)
				data.camera.clip=[0,0,159,99];data.camera.center=[80,50];data.camera.focal_pixels=focal;pose_head(data)
				await pose_pixels(data,"%d-%d-%d"%[shape,roundi(rad_to_deg(yaw)),int(focal)])
	if "--captured-packet" in args:
		var live_path:String=args[args.find("--captured-packet")+1]
		var live:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(live_path))
		var immutable:=JSON.stringify(live)
		draw.tactical_landscape=false
		await render(live,true)
		# Resize from the160x100 studies to the captured320x136 frame must
		# settle before sampling its one-shot dependent ownership viewport.
		await render(live,true)
		var original_mask:Image=draw.ownership.get_texture().get_image().duplicate() as Image
		draw.tactical_landscape=true
		var actual:=await render(live,true)
		var admitted:Dictionary=draw.tactical_vehicle_view.pose_admitted
		check(admitted.size()==1,"unmodified real gameplay packet admits exactly the witnessed-head Sagger")
		var mask:Image=draw.ownership.get_texture().get_image();var visible:=0
		for y in mask.get_height():
			for x in mask.get_width():
				if owner_id(mask.get_pixel(x,y)) in admitted:visible+=1
		# The crouched crew is behind the actual foreground. The old upright
		# head protruded above it, so those original crew pixels MUST vacate.
		var protected_changed:=0;var protected_samples:=0;var vacated:=0
		for y in mask.get_height():
			for x in mask.get_width():
				var original_owner:=owner_id(original_mask.get_pixel(x,y))
				if original_owner in admitted:
					if owner_id(mask.get_pixel(x,y))==0:vacated+=1
				else:
					protected_samples+=1
					if mask.get_pixel(x,y)!=original_mask.get_pixel(x,y):protected_changed+=1
		check(visible==0 and vacated>0 and protected_samples>0 and protected_changed==0,"actual lower pose is occluded, upright head pixels vacate, all noncrew coverage exact")
		check(JSON.stringify(live)==immutable,"actual gameplay packet remains immutable")
		actual.save_png(output.path_join("actual-gameplay.png"));mask.save_png(output.path_join("actual-gameplay-mask.png"));original_mask.save_png(output.path_join("actual-original-mask.png"))
		print("PC_ACTUAL_MASK: ",original_mask.get_size()," -> ",mask.get_size()," exact=",mask.get_data()==original_mask.get_data())
		pose_rows.append({"case":"actual-captured-gameplay","admitted":admitted.size(),"visible":visible,"original_foreground_mask_exact":protected_changed==0,"vacated_upright_pixels":vacated,"protected_samples":protected_samples,"packet":live_path})
	FileAccess.open(output.path_join("pose-report.json"),FileAccess.WRITE).store_string(JSON.stringify(pose_rows,"  "))
	finish()

func check_pose_sources(catalog:Dictionary,schema_only:bool) -> Dictionary:
	var raw:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("local-art/pc-tactical-roster-v1/catalog.json")))
	var contract:Dictionary={"schema":1,"kind":"ground-atgm-v1","head_basis":[[0,.6,0],[-.579555496,0,.155291427],[.155291427,0,.579555496]],"head_origin":[-3.427887,6,-48.042329]}
	var source_models:Dictionary={}
	for model:Dictionary in raw.models:
		if int(model.shape_index) not in [161,162]:continue
		var shape:=int(model.shape_index);var source:Dictionary=catalog.models[shape]
		if schema_only:source_models[shape]=model
		var pose:Dictionary=model.get("presentation_pose",contract)
		check(VehicleAssets.validate_command_head(model.command_head,source,model.triangles.size()),"original normalized command head unchanged")
		check(CrewPose.validate(pose,source,model.command_head),"bounded raw-coordinate head transform admitted")
		for field in ["schema","kind","head_basis","head_origin"]:
			var bad:=pose.duplicate(true);bad.erase(field)
			check(not CrewPose.validate(bad,source,model.command_head),"missing pose field rejected "+field)
		for mutation in ["foreign","shear","reflection","nan","bounds","zero"]:
			var bad:=pose.duplicate(true);var original:=source.duplicate(true)
			match mutation:
				"foreign":original.shape_index=115
				"shear":bad.head_basis[0][0]+=.3
				"reflection":bad.head_basis[0]=bad.head_basis[0].map(func(v):return -v)
				"nan":bad.head_origin[0]=NAN
				"bounds":bad.head_origin[0]=10000
				"zero":bad.head_basis[0]=[0,0,0]
			check(not CrewPose.validate(bad,original,model.command_head),"invalid pose rejected "+mutation)
	if schema_only:
		for shape in source_models:source_models[shape].presentation_pose=contract
	return source_models

func pose_pixels(data:Dictionary,label:String) -> void:
	var immutable:=JSON.stringify(data)
	draw.tactical_landscape=false
	var ordinary:=await render(data,true)
	var old_mask:=draw.ownership.get_texture().get_image().duplicate() as Image
	var classic:=await render(data,false)
	draw.tactical_landscape=true
	var detailed:=await render(data,true)
	check(draw.tactical_vehicle_view.active_count==1 and draw.tactical_vehicle_view.head_count==1,"one real-depth combined attached head/body "+label)
	var mask:Image=draw.ownership.get_texture().get_image().duplicate() as Image
	var coverage:=await vehicle_coverage(1,true)
	var masked:=await vehicle_coverage(1,false)
	var visible:=0;var forbidden:=0;var vacated:=0;var stale:=0;var unexplained:=0
	var boundary_gap:=0;var boundary_extra:=0;var leaks:=0;var missing:=0
	for y in detailed.get_height():
		for x in detailed.get_width():
			var value:=mask.get_pixel(x,y);var own:=owner_id(value)==1
			var covered:=coverage.get_pixel(x,y).r>.5
			var eligible:=own and roundi(value.b*255.0)==8
			var drawn:=masked.get_pixel(x,y).r>.5
			if drawn and not (covered and eligible):leaks+=1
			if covered and eligible and not drawn:missing+=1
			if own and not eligible:forbidden+=1
			if covered:
				visible+=1
				if not eligible:
					# Both paths rasterize the same mesh through distinct transforms.
					# Permit one background boundary pixel, never foreign ownership.
					# Working if exact masked coverage below has no leaks or omissions.
					if owner_id(value)==0 and roundi(value.b*255.0)==0 and pose_boundary(coverage,x,y,false) and pose_boundary(mask,x,y,true):boundary_gap+=1
					else:forbidden+=1
			if own and not covered:
				if pose_boundary(coverage,x,y,false) and pose_boundary(mask,x,y,true):boundary_extra+=1
				else:unexplained+=1
			if owner_id(old_mask.get_pixel(x,y))==1 and not own:
				vacated+=1
				if detailed.get_pixel(x,y)!=Color.BLACK:stale+=1
	check(visible>20 and forbidden==0 and unexplained==0 and boundary_gap<=1,"two-way posed triangle/mask coverage, bounded raster-edge allowance "+label)
	check(leaks==0 and missing==0,"masked coverage equals exact eligible triangle intersection "+label)
	check(vacated>0 and stale==0,"vacated upright silhouette reveals background "+label)
	check(detailed.get_data()==(await render(data,true)).get_data(),"same pose cache exact "+label)
	var reversed:=data.duplicate(true);reversed.objects[0].polygons.reverse()
	check(detailed.get_data()==(await render(reversed,true)).get_data(),"pose depth independent of source submission "+label)
	var bad:=data.duplicate(true);bad.objects[0].round_forms[0].command[0]=0
	var fallback:=await render(bad,true)
	check(draw.tactical_vehicle_view.active_count==0,"unsupported pose packet complete renderer fallback "+label)
	draw.tactical_vehicle_assets.ready=false
	check(fallback.get_data()==(await render(bad,true)).get_data(),"unsupported pose packet exact incumbent pixels "+label)
	draw.tactical_vehicle_assets.ready=true
	draw.tactical_landscape=false
	check(ordinary.get_data()==(await render(data,true)).get_data(),"ordinary Modern restored "+label)
	check(classic.get_data()==(await render(data,false)).get_data(),"Classic restored "+label)
	draw.tactical_landscape=true
	check(detailed.get_data()==(await render(data,true)).get_data(),"pose restored after mode changes "+label)
	check(JSON.stringify(data)==immutable,"pose input immutable "+label)
	if label.ends_with("-192"):
		await protected_pixels(data,label)
	if label.ends_with("-0-192"):
		await pose_depth_negative(data,detailed,label)
		await pose_near_plane(data,label)
	detailed.save_png(output.path_join(label+"-pose.png"));mask.save_png(output.path_join(label+"-mask.png"))
	pose_rows.append({"case":label,"visible":visible,"mask_mismatch":forbidden,"unexplained_mask":unexplained,"vacated":vacated,"stale":stale,"boundary_gap":boundary_gap,"boundary_extra":boundary_extra,"masked_leaks":leaks,"eligible_missing":missing})

func pose_boundary(pixels:Image,x:int,y:int,ownership_mask:bool) -> bool:
	var inside:=false;var outside:=false
	for dy in range(-1,2):
		for dx in range(-1,2):
			var value:=pixels.get_pixel(clampi(x+dx,0,pixels.get_width()-1),clampi(y+dy,0,pixels.get_height()-1))
			var filled:bool=(owner_id(value)==1 and roundi(value.b*255.0)==8) if ownership_mask else value.r>.5
			inside=inside or filled;outside=outside or not filled
	return inside and outside

func pose_depth_negative(data:Dictionary,reference:Image,label:String) -> void:
	await render(data,true)
	var node:MeshInstance3D=draw.tactical_vehicle_view.instances[0]
	var original:ShaderMaterial=node.material_override
	check(original.shader.code.contains("depth_draw_opaque") and not original.shader.code.contains("depth_test_disabled"),"posed combined mesh uses opaque real depth "+label)
	var disabled:=Shader.new();disabled.code=original.shader.code.replace("depth_draw_opaque","depth_test_disabled,depth_draw_never")
	var negative:ShaderMaterial=original.duplicate();negative.shader=disabled
	node.material_override=negative
	var image:=await capture();node.material_override=original
	var changed:=0
	for y in reference.get_height():
		for x in reference.get_width():
			if image.get_pixel(x,y)!=reference.get_pixel(x,y):changed+=1
	check(changed>20,"depth-disabled negative changes internal occlusion "+label)

func pose_near_plane(data:Dictionary,label:String) -> void:
	var crossed:=data.duplicate(true)
	var view:=VehicleView.new();var admitted:=view.admit_poses(draw.tactical_vehicle_assets,crossed)
	check(not admitted.is_empty(),"crossing seed admitted "+label)
	if admitted.is_empty():view.free();return
	var pose:Dictionary=admitted[1];var shape:=int(crossed.objects[0].shape_index)
	var lo:=INF;var hi:=-INF;var minx:=INF;var maxx:=-INF;var minz:=INF;var maxz:=-INF
	for point:Vector3 in draw.tactical_vehicle_assets.gpu_poses[shape].positions:
		var camera_point:Vector3=pose.basis*point+pose.origin
		var depth:float=camera_point.y;lo=minf(lo,depth);hi=maxf(hi,depth)
		minx=minf(minx,camera_point.x);maxx=maxf(maxx,camera_point.x);minz=minf(minz,camera_point.z);maxz=maxf(maxz,camera_point.z)
	var delta:=float(crossed.camera.near_raw)-(lo+hi)*.5
	# Center the actual low pose before pushing it through the near plane.
	# The old upright frame otherwise puts every surviving triangle offscreen.
	crossed.camera.focal_pixels=24.0
	for polygon:Dictionary in crossed.objects[0].polygons:
		for point:Array in polygon.camera_vertices:
			point[0]-=(minx+maxx)*.5;point[1]+=delta;point[2]-=(minz+maxz)*.5
	admitted=view.admit_poses(draw.tactical_vehicle_assets,crossed)
	check(lo+delta<float(crossed.camera.near_raw) and hi+delta>float(crossed.camera.near_raw) and not admitted.is_empty(),"actual posed geometry crosses near plane "+label)
	var clipped_ok:=not admitted.is_empty()
	if clipped_ok:
		for point:Array in admitted[1].camera_triangles:
			if point[1]<float(crossed.camera.near_raw)-.00001:clipped_ok=false
	check(clipped_ok,"near-clipped replacement mask contains no behind-plane vertices "+label)
	await render(crossed,true)
	check(draw.tactical_vehicle_view.active_count==1,"intersecting pose renders with real-depth near clipping "+label)
	var cover:=await vehicle_coverage(1,true);var visible:=0
	for y in cover.get_height():
		for x in cover.get_width():
			if cover.get_pixel(x,y).r>.5:visible+=1
	check(visible>0,"near-plane crossing retains visible geometry "+label)
	view.free()

func protected_pixels(data:Dictionary,label:String) -> void:
	for kind in ["actor","terrain","line","round"]:
		var test:=data.duplicate(true);var cover:=visibility_cover(data,kind=="terrain")
		if kind=="line":cover.polygons[0].fill_mode=0
		if kind=="round":
			cover.polygons=[];cover.round_forms=[{"status":"observed","spans":[{"y":50,"left":0,"right":80,"color":12}]}];cover.draw_order=[{"kind":"round_form","index":0}]
		test.objects.append(cover)
		var detailed:=await render(test,true);var mask:Image=draw.ownership.get_texture().get_image()
		draw.tactical_vehicle_assets.ready=false
		var incumbent:=await render(test,true)
		draw.tactical_vehicle_assets.ready=true
		var samples:=0;var changed:=0
		for y in mask.get_height():
			for x in mask.get_width():
				if owner_id(mask.get_pixel(x,y))==2:
					samples+=1
					if detailed.get_pixel(x,y)!=incumbent.get_pixel(x,y):changed+=1
		check(samples>0 and changed==0,"later "+kind+" original pixels protected "+label)

func finish() -> void:
	for failure in failures:printerr("FAIL: "+failure)
	print("PC_GROUND_CREWS: %d checks, %d errors"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
