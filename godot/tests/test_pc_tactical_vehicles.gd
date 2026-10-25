extends "res://tests/test_pc_modern_environment_polish.gd"
## Bespoke vehicle schema, source mapping, mode isolation and native appearance.
const VehicleAssets=preload("res://scripts/pc_tactical_vehicle_assets.gd")
const VehicleView=preload("res://scripts/pc_tactical_vehicle_view.gd")
var _crew_depth_reference:Dictionary={}
var _crew_negative_reference:Dictionary={}
var _native_phase:=""
var _posed_shapes:Array=[]

func run() -> void:
	directory=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	output=directory.path_join("artifacts/tactical-vehicles-20261017/runtime")
	var args:=OS.get_cmdline_user_args()
	if "--output" in args:
		output=args[args.find("--output")+1]
		if not output.is_absolute_path():output=directory.path_join(output)
	DirAccess.make_dir_recursive_absolute(output)
	var full_roster:=FileAccess.file_exists(directory.path_join("local-art/pc-tactical-roster-v1/manifest.json"))
	var scene_roster:bool=full_roster and JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("local-art/pc-tactical-roster-v1/manifest.json"))).get("schema")==3
	var format_shard:=-1
	var scene_kind:=""
	if "--format-shard" in args:
		var at:=args.find("--format-shard")+1
		if DisplayServer.get_name()!="headless" or at>=args.size() or args[at] not in ["0","1","2","3","4","5","6","7"]:
			check(false,"headless format shard must be 0 through 7");finish();return
		format_shard=int(args[at])
	if "--scene-format-kind" in args:
		var at:=args.find("--scene-format-kind")+1
		if DisplayServer.get_name()!="headless" or format_shard!=6 or not scene_roster or args.count("--format-shard")!=1 or args.count("--scene-format-kind")!=1 or at>=args.size() or args[at] not in ["passthrough","partial","scene_bank"]:
			check(false,"scene format kind requires one explicit headless schema-3 shard 6 and one approved case");finish();return
		scene_kind=args[at]
	var defer_scene:bool="--defer-scene-contracts" in args
	if defer_scene:
		var at:=args.find("--view-shard")+1
		if DisplayServer.get_name()=="headless" or not scene_roster or args.count("--view-shard")!=1 or at>=args.size() or args[at]!="0" or args.count("--defer-scene-contracts")!=1 or ["--scene-only","--visibility-only","--gpu-only","--bounds-only"].any(func(flag):return flag in args):
			check(false,"deferred scene contracts require one native schema-3 view shard 0 and the complete common/view phase");finish();return
		_native_phase="views"
	if format_shard>0:
		check(full_roster,"roster format shard requires complete bundle")
		if full_roster:
			var cases:Array=["missing","duplicate","unexpected","bank","maps","scene","compat"]
			reject_incomplete_roster(cases[format_shard-1],scene_kind)
			print("PC_TACTICAL_FORMAT_SHARD: ",format_shard," case=",cases[format_shard-1])
			if not scene_kind.is_empty():print("PC_TACTICAL_SCENE_FORMAT: %s; %d checks, %d errors"%[scene_kind,checks,failures.size()])
		finish();return
	var shapes:Array=(VehicleAssets.SCENE_SHAPES if scene_roster else VehicleAssets.ROSTER_SHAPES) if full_roster else [115,125]
	if DisplayServer.get_name()=="headless":
		var vehicles=VehicleAssets.new()
		check(vehicles.load_detail(directory),"complete Blender assets load")
		_posed_shapes=vehicles.gpu_poses.keys()
		check(vehicles.models.keys().size()==shapes.size() and shapes.all(func(id):return id in vehicles.models),"exact approved roster admitted")
		bank_binding(vehicles,catalogue_for_banks())
		grounding_encoding(vehicles)
		var catalog:=art.load_catalogue(directory)
		rigid_groups(vehicles,catalog)
		for shape in shapes:
			var data:=model_packet(catalog,shape)
			var found:=0
			for polygon:Dictionary in data.objects[0].polygons:
				var a:=vehicles.mapping(data.objects[0],polygon,data.camera,data.palette_rgb,false,NAN,false)
				var b:=vehicles.mapping(data.objects[0],polygon,data.camera,data.palette_rgb,false,123.0,false)
				check(a==b,"observed motion cannot overwrite authored UVs")
				for facet:Dictionary in a:
					found+=1
					check(facet.kind==28.0,"detail material dispatch")
					for point:Array in facet.points:
						check(point.size()==5 and point[1]>=data.camera.near_raw,"near-clipped full UV/depth")
			check(found>(100 if shape in VehicleAssets.ROSTER_SHAPES else 0),"visible attributed model triangles")
		var malformed:=fixture()
		malformed.models[0].triangles[0].uvs=[[0,0],[1,0],[0,1]]
		check(vehicles.configure(malformed),"optional full UV schema")
		var near_packet:=packet(24.0,0.8)
		var near_facets:=vehicles.mapping(near_packet.objects[0],near_packet.objects[0].polygons[0],near_packet.camera,near_packet.palette_rgb,false)
		check(not near_facets.is_empty(),"attributed near-plane crossing remains visible")
		for facet:Dictionary in near_facets:
			for point:Array in facet.points:
				check(point.size()==5 and point[1]>=16.0 and point[3]>=0.0 and point[3]<=1.0 and point[4]>=0.0 and point[4]<=1.0,"near-plane intersection interpolates UV and real depth")
		malformed.models[0].triangles[0].uvs[1]=[INF,0]
		check(not vehicles.configure(malformed),"non-finite UV rejected")
		malformed.models[0].triangles[0].uvs=[[0,0],[0,0],[0,0]]
		check(not vehicles.configure(malformed),"degenerate tangent UV rejected")
		check(not vehicles.load_detail(directory.path_join("missing")) and not vehicles.ready and vehicles.models.is_empty() and vehicles.albedo_atlas==null,"failed reload clears pair and maps")
		# File-format rejection fixtures are backend-independent. Run them once
		# in the required headless gate, keeping the native deadline for pixels.
		reject_incomplete_pair()
		if full_roster and format_shard==-1:reject_incomplete_roster()
		print("PC_TACTICAL_FORMAT_SHARD: ",format_shard," pair=true roster=",full_roster and format_shard==-1)
		finish()
		return
	# Six fixed partitions cover the identical complete native view inventory.
	# Backend-independent schema/mapping assertions run above in headless.
	# Production admission and common GPU proofs run in every native partition;
	# the inherited 120-second deadline remains unchanged.
	var catalog:=art.load_catalogue(directory)
	var view_shapes:Array=shapes
	if "--view-shard" in args:
		var at:=args.find("--view-shard")+1
		if at>=args.size() or args[at] not in ["0","1","2","3","4","5"]:
			check(false,"view shard must be 0 through 5");finish();return
		view_shapes=[]
		for i in shapes.size():
			if i%6==int(args[at]):view_shapes.append(shapes[i])
	viewport=SubViewport.new();viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	camera=Camera3D.new();viewport.add_child(camera);camera.make_current()
	draw=Draw.new();draw.solid_enabled=true;draw.modern_assets=art;camera.add_child(draw)
	check(draw.load_modern_assets(directory),"production asset integration")
	_posed_shapes=draw.tactical_vehicle_assets.gpu_poses.keys()
	check(draw.tactical_vehicle_assets.ready,"production detail assets available")
	check(draw.tactical_vehicle_assets.models.keys().size()==shapes.size() and shapes.all(func(id):return id in draw.tactical_vehicle_assets.models),"exact approved production roster admitted")
	FileAccess.open(output.path_join("allocation.json"),FileAccess.WRITE).store_string(JSON.stringify({"decoded_texture_bytes_with_mips":draw.tactical_vehicle_assets.decoded_texture_bytes,"driver_texture_bytes_total":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),"driver_video_bytes_total":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)},"  "))
	draw.profile_builds=true
	if scene_roster and not defer_scene and ("--view-shard" not in args or args[args.find("--view-shard")+1]=="0"):
		await grounding_pixels(catalog)
		await scene_contracts(catalog)
		if "--scene-only" in args:
			# Keep the original crew-populated pool -> grouped vehicle witness
			# when the required scene and common/view phases run separately.
			await ownership_occluder(catalog)
			_native_phase="scene"
		if not failures.is_empty():finish();return
	if "--scene-only" in args:
		finish();return
	if "--visibility-only" in args:
		await visibility_coverage(catalog)
		if full_roster:await original_rotors(catalog)
		finish();return
	# Keep this focused pixel matrix in the lighter fixed view partition.
	if "--view-shard" not in args or args[args.find("--view-shard")+1]=="1":await visibility_coverage(catalog)
	await gpu_position_contract()
	if "--gpu-only" in args:
		finish();return
	await ownership_overlap(catalog)
	if "--bounds-only" in args:
		finish();return
	await actual_source_groups()
	if full_roster:await original_rotors(catalog)
	await renderer_timing(catalog,[115,125,153,156,157,161] if "--view-shard" in args and args[args.find("--view-shard")+1]=="0" else [115,125])
	for shape in view_shapes:
		var specs:Array=[[0.0,192.0],[PI*.5,192.0],[PI,192.0],[PI*1.5,192.0],[0.65,336.0],[PI+0.65,336.0]]
		if shape in [115,125]:specs=[[0.0,192.0],[PI*.5,192.0],[PI,192.0],[PI*1.5,192.0],[0.65,192.0],[0.65,336.0],[0.65,96.0]]
		for spec in specs:
			var angle:float=spec[0]
			var data:=model_packet(catalog,shape,-0.6,angle,0.30)
			data.camera.focal_pixels=spec[1]
			var unchanged:=JSON.stringify(data)
			draw.tactical_landscape=false
			var modern:=await render(data,true)
			var modern_usec:int=draw.last_apply_timings_usec.get("total",0)
			check(draw.mesh_node.mesh.get_surface_count()==1 and draw.tactical_vehicle_view.active_count==0,"Modern keeps incumbent geometry")
			draw.tactical_landscape=true
			var detailed:=await render(data,true)
			var detail_usec:int=draw.last_apply_timings_usec.get("total",0)
			check(draw.tactical_vehicle_view.active_count>0,"Tactical uses persistent four-sampler face meshes")
			var selected_groups:=0
			for group:Dictionary in draw.tactical_vehicle_assets.gpu_groups[shape].values():
				if group.primitives.all(func(pid):return pid in draw.tactical_vehicle_assets.models[shape].roots[data.objects[0].root]):selected_groups+=1
			check(draw.tactical_vehicle_view.group_count==(1 if shape in _posed_shapes else selected_groups),"every selected independently observed filled group or atomic pose admitted")
			var owners:Image=draw.ownership.get_texture().get_image()
			var visible:=0;var outside:=0;var extensions:=0;var source_pixels:=0
			for y in detailed.get_height():
				for x in detailed.get_width():
					var colour:=detailed.get_pixel(x,y)
					if owner_id(owners.get_pixel(x,y))==1:source_pixels+=1
					if colour!=Color.BLACK:
						visible+=1
						var owner:Color=owners.get_pixel(x,y)
						if not coverage_allowed(owner,1,shape not in VehicleAssets.ROSTER_SHAPES) and roundi(owner.b*255.0)!=64:outside+=1
						if owner_id(owner)!=1:extensions+=1
			check(visible>100 if shape in VehicleAssets.ROSTER_SHAPES else (visible>0 or source_pixels==0),"model state retains source-admitted visibility")
			check(outside==0,"zero pixels over protected source coverage")
			check(modern.get_data()!=detailed.get_data() or source_pixels==0,"visible model replacement or original edge-on void")
			check(detailed.get_data()==(await render(data,true)).get_data(),"same-packet detail restore exact")
			draw.tactical_landscape=false
			check(modern.get_data()==(await render(data,true)).get_data(),"Modern exact after Tactical")
			check(JSON.stringify(data)==unchanged,"original packet unchanged")
			var name:="%d-%03d-%d"%[shape,roundi(rad_to_deg(angle)),int(spec[1])]
			modern.save_png(output.path_join(name+"-modern.png"));detailed.save_png(output.path_join(name+"-tactical.png"))
			rows.append({"shape":shape,"yaw":angle,"focal":spec[1],"visible_pixels":visible,"forbidden_pixels":outside,"extension_pixels":extensions,"modern_application_usec":modern_usec,"detail_application_usec":detail_usec})
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	finish()


func model_packet(catalog:Dictionary,shape:int,terrain_tilt:float=-0.6,facing:float=0.4,pitch:float=0.0) -> Dictionary:
	var data:=super.model_packet(catalog,shape,terrain_tilt,facing,pitch)
	if shape in _posed_shapes:pose_head(data)
	return data

func pose_head(data:Dictionary) -> void:
	# Synthetic witnessed source command for model studies, independent of the
	# posed head mesh. Exact production command bytes/offset/root still gate it.
	var object:Dictionary=data.objects[0];var spans:Array=[]
	var x:=int(data.camera.center[0]);var y:=int(data.camera.center[1])-15
	for row in range(y-7,y+8):spans.append({"y":row,"left":x-9,"right":x+10,"color":12})
	object.round_forms=[{"status":"observed","command_offset":30996 if int(object.shape_index)==161 else 31422,"command":[170,15,2,171],"fill_mode":1,"radius":7,"horizontal_radius":9,"center":[x,y],"spans":spans}]
	object.draw_order=[]
	for i in object.polygons.size():object.draw_order.append({"kind":"polygon","index":i})
	object.draw_order.append({"kind":"round_form","index":0})

func catalogue_for_banks() -> Dictionary:
	return art.load_catalogue(directory)

func bank_binding(vehicles:RefCounted,catalog:Dictionary) -> void:
	var subject:=VehicleView.new()
	for shape in vehicles.models:
		var data:=model_packet(catalog,shape,-0.6,0.65,0.30)
		var expected:Array=vehicles.bank_for_shape(shape)
		if shape in vehicles.gpu_poses:
			subject.clear();subject.admit_poses(vehicles,data)
			check(subject.submit_pose(vehicles,1,null,{})>0,"combined pose bank path bound")
			check_bound_maps(subject.instances[0],expected,false)
			continue
		subject.clear()
		var grouped:int=subject.prepare_object(vehicles,data.objects[0],data.camera,1,null,{})
		check(grouped>0 if not vehicles.gpu_groups[shape].is_empty() else grouped==0,"bank shape group path or flat painter path bound")
		for instance in subject.instances:
			if instance.visible:check_bound_maps(instance,expected,shape in vehicles.FLAT_SHAPES)
		subject.clear()
		if shape in vehicles.PER_FACE_SHAPES:subject.prepare_object(vehicles,data.objects[0],data.camera,1,null,{})
		for polygon:Dictionary in data.objects[0].polygons:
			if int(polygon.primitive) not in vehicles.protected_surfaces.get(shape,{}) and not vehicles.models[shape].faces[int(polygon.primitive)].triangles.is_empty():
				check(subject.submit(vehicles,data.objects[0],polygon,data.camera,1,null,{})>0,"bank forced face path bound")
				check_bound_maps(subject.instances[0],expected,shape in vehicles.FLAT_SHAPES)
				break
	subject.free()
	check(vehicles.decoded_texture_bytes>0,"decoded texture allocation measured")

func check_bound_maps(instance:MeshInstance3D,expected:Array,flat:bool) -> void:
	check(instance.material_override.shader.code.contains("depth_test_disabled")==flat,"pooled bridge/crew/vehicle depth shader rebound")
	for i in 3:
		check(instance.material_override.get_shader_parameter(["tactical_vehicle_albedo","tactical_vehicle_normal","tactical_vehicle_orm"][i])==expected[i],"pooled instance rebinds selected bank map")

func grounding_encoding(vehicles:RefCounted) -> void:
	for shape in vehicles.models:
		var excluded:bool=shape in vehicles.PER_FACE_SHAPES or shape in [163,164]
		for primitive in vehicles.gpu_faces[shape]:
			var face:Dictionary=vehicles.models[shape].faces[primitive]
			var meshes:Dictionary=vehicles.gpu_faces[shape][primitive]
			var affine:PackedVector2Array=meshes.affine.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
			var piecewise:PackedVector2Array=meshes.piecewise.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
			var error:=0.0
			for i in face.corners.size():
				var expected:float=vehicles.grounding_height(shape,Modern.vec(face.corners[i].raw))
				error=maxf(error,maxf(absf(affine[i].y-expected),absf(piecewise[i].y-expected)))
				if excluded:error=maxf(error,absf(affine[i].y-1.0))
			check(error<0.00001,"affine and piecewise meshes carry authored whole-model height; excluded shapes neutral")
		for group:Dictionary in vehicles.gpu_groups[shape].values():
			var arrays:Array=group.mesh.surface_get_arrays(0)
			var positions:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var heights:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
			var error:=0.0
			for i in positions.size():error=maxf(error,absf(heights[i].y-vehicles.grounding_height(shape,positions[i])))
			check(error<0.00001,"rigid group uses same whole-model height as fallback faces")
	check(vehicles.grounding_height(999,Vector3.ZERO)==1.0,"missing or zero-height bounds fail closed to neutral shade")

func grounding_pixels(catalog:Dictionary) -> void:
	var evidence:Array=[]
	# Consecutive submissions also exercise pooled ground/aircraft/flat reuse.
	for shape in [115,163,161,147,148,153]:
		var data:=model_packet(catalog,shape,-.6,.65,.30)
		data.camera.focal_pixels=144.0
		draw.tactical_landscape=true
		var shaded:=await render(data,true)
		var originals:Array=[]
		for node:MeshInstance3D in draw.tactical_vehicle_view.instances:
			if not node.visible:continue
			var material:ShaderMaterial=node.material_override
			var original:Shader=material.shader;originals.append([material,original])
			var neutral:=Shader.new();neutral.code=original.code.replace("0.06*(1.0-smoothstep","0.0*(1.0-smoothstep")
			material.shader=neutral
		var plain:=await capture()
		var changed:=0;var exterior:=0;var coverage:=0
		for y in shaded.get_height():
			for x in shaded.get_width():
				var a:Color=shaded.get_pixel(x,y);var b:Color=plain.get_pixel(x,y)
				if (a==Color.BLACK)!=(b==Color.BLACK):coverage+=1
				if a!=b:
					changed+=1
					if b==Color.BLACK:exterior+=1
		check(coverage==0 and exterior==0,"grounding shade preserves all coverage and exterior pixels")
		check(changed==0 if shape in [163,161] else changed>0,"grounding visible on footings and vehicles; absent for aircraft and flat crews")
		for pair:Array in originals:pair[0].shader=pair[1]
		check(shaded.get_data()==(await capture()).get_data(),"grounding material restore exact")
		shaded.save_png(output.path_join("grounding-%d-on.png"%shape));plain.save_png(output.path_join("grounding-%d-off.png"%shape))
		evidence.append({"shape":shape,"changed_pixels":changed,"coverage_changes":coverage,"exterior_changes":exterior})
	FileAccess.open(output.path_join("grounding.json"),FileAccess.WRITE).store_string(JSON.stringify(evidence,"  "))

func reject_incomplete_roster(case_name:String="all",scene_kind:String="") -> void:
	var temporary:=output.path_join("incomplete-roster")
	var relatives:Array=["local-art/pc-modern/catalog.json","local-art/pc-modern/source-shapes.json"]
	var source:=directory.path_join("local-art/pc-tactical-roster-v1")
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source.path_join("manifest.json")))
	for name:String in manifest.files:relatives.append("local-art/pc-tactical-roster-v1/"+name)
	relatives.append("local-art/pc-tactical-roster-v1/manifest.json")
	for name in ["catalog.json","manifest.json","albedo.png","normal.png","orm.png"]:relatives.append("local-art/pc-tactical-vehicles-v1/"+name)
	for relative:String in relatives:
		var destination:=temporary.path_join(relative)
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		check(DirAccess.copy_absolute(directory.path_join(relative),destination)==OK,"copy full-roster rejection fixture")
	var folder:=temporary.path_join("local-art/pc-tactical-roster-v1")
	if case_name in ["scene","compat"]:
		await_scene_format(temporary,folder,manifest,case_name,scene_kind)
		return
	var original:String="" if case_name=="maps" else FileAccess.get_file_as_string(folder.path_join("catalog.json"))
	var reload_assets=VehicleAssets.new()
	check(reload_assets.load_detail(directory) and reload_assets.models.size()==manifest.shapes.size(),"full roster admitted before failed reload")
	var old_revision:int=reload_assets.revision
	# Maps-only cases use independent subjects below; release this valid roster
	# after proving admission rather than overlapping another full asset load.
	if case_name=="maps":reload_assets=null
	for kind:String in ["missing","duplicate","unexpected","bank"]:
		if case_name!="all" and case_name!=kind:continue
		var broken:Dictionary=JSON.parse_string(original)
		if kind=="missing":broken.models.remove_at(0)
		elif kind=="duplicate":broken.models[-1]=broken.models[0].duplicate(true)
		elif kind=="unexpected":broken.models[-1].shape_index=165
		else:broken.models[-1].texture_bank="unknown"
		FileAccess.open(folder.path_join("catalog.json"),FileAccess.WRITE).store_string(JSON.stringify(broken))
		manifest.files["catalog.json"]=FileAccess.get_sha256(folder.path_join("catalog.json"))
		FileAccess.open(folder.path_join("manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(manifest))
		check(reload_assets.load_detail(temporary) and reload_assets.models.size()==2 and reload_assets.texture_banks.size()==1 and reload_assets.shape_banks.size()==2 and 163 not in reload_assets.gpu_groups and 163 not in reload_assets.protected_lines and reload_assets.revision>old_revision,"invalid "+kind+" roster reload atomically selects independently valid pair")
	if case_name not in ["all","maps"]:return
	if case_name=="all":FileAccess.open(folder.path_join("catalog.json"),FileAccess.WRITE).store_string(original)
	manifest.files["catalog.json"]=FileAccess.get_sha256(folder.path_join("catalog.json"))
	# Missing and corrupt maps both reject before any candidate is installed.
	for missing:bool in [false,true]:
		var map_path:=folder.path_join("wreck-normal.png")
		if missing:DirAccess.remove_absolute(map_path)
		else:FileAccess.open(map_path,FileAccess.WRITE).store_string("corrupt")
		FileAccess.open(folder.path_join("manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(manifest))
		var rejected=VehicleAssets.new()
		check(rejected.load_detail(temporary) and rejected.models.size()==2 and 163 not in rejected.gpu_groups,"bad map selects clean pair fallback")
	var oversized:=FileAccess.open(folder.path_join("catalog.json"),FileAccess.WRITE)
	oversized.seek(VehicleAssets.ROSTER_CATALOG_LIMIT);oversized.store_8(32);oversized.close()
	manifest.files["catalog.json"]=FileAccess.get_sha256(folder.path_join("catalog.json"))
	# Restore the map so the actual catalogue cap is the rejecting condition.
	DirAccess.copy_absolute(source.path_join("wreck-normal.png"),folder.path_join("wreck-normal.png"))
	FileAccess.open(folder.path_join("manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(manifest))
	var rejected=VehicleAssets.new()
	check(rejected.load_detail(temporary) and rejected.models.size()==2,"oversize roster catalogue keeps registry bound and pair fallback")

func await_scene_format(temporary:String,folder:String,manifest:Dictionary,case_name:String,scene_kind:String="") -> void:
	if manifest.schema!=3:return
	var kinds:Array=["passthrough","partial","scene_bank"] if case_name=="scene" else ["compat"]
	if not scene_kind.is_empty():kinds=[scene_kind]
	# Finish fixture serialization before admitting either large catalogue. The
	# same subject still performs every valid-scene -> rejection/legacy reload.
	prepare_scene_format(folder,manifest,kinds[0])
	var subject=VehicleAssets.new()
	check(subject.load_detail(directory) and subject.models.size()==57,"scene available before malformed reload sequence")
	for i in kinds.size():
		var kind:String=kinds[i]
		if i>0:prepare_scene_format(folder,manifest,kind)
		if kind=="compat":
			check(subject.load_detail(temporary) and subject.models.size()==34 and subject.texture_banks.size()==3 and subject.protected_surfaces.is_empty(),"schema-2 complete vehicle roster compatibility")
		else:
			# A selected partial case also retains the old pair -> pair reload
			# witness after its independent full-scene -> pair rejection.
			for repeat in (2 if scene_kind=="partial" else 1):
				var previous_revision:int=subject.revision
				check(subject.load_detail(temporary) and subject.models.size()==2 and subject.texture_banks.size()==1 and subject.protected_surfaces.is_empty() and 161 not in subject.gpu_faces and subject.revision>previous_revision,"invalid "+kind+" scene atomically clears into pair fallback")

func prepare_scene_format(folder:String,manifest:Dictionary,kind:String) -> void:
	var changed:Dictionary=manifest.duplicate(true)
	if not write_scene_fixture_catalogue(folder.path_join("catalog.json"),manifest,kind):return
	if kind=="scene_bank":changed.banks.erase("scene")
	elif kind=="compat":
		changed.schema=2;changed.shapes=VehicleAssets.ROSTER_SHAPES
		for bank:String in ["scene","bridge"]:
			changed.banks.erase(bank)
			for map_kind:String in ["albedo","normal","orm"]:changed.files.erase(bank+"-"+map_kind+".png")
	changed.files["catalog.json"]=FileAccess.get_sha256(folder.path_join("catalog.json"))
	FileAccess.open(folder.path_join("manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(changed))

func write_scene_fixture_catalogue(target:String,manifest:Dictionary,kind:String) -> bool:
	var source:=directory.path_join("local-art/pc-tactical-roster-v1/catalog.json")
	if kind=="scene_bank":
		var copied:=DirAccess.copy_absolute(source,target)==OK
		check(copied,"scene-bank fixture retains exact valid catalogue")
		return copied
	# The exporter emits compact JSON with shape_index first in each model.
	# Edit only a checked token or copy complete model slices. This keeps the
	# exact same malformed/legacy inputs without three huge parse/stringify
	# cycles competing with the valid subject's meshes. No production cap or
	# deadline is changed. Export-format drift fails this fixture explicitly.
	var raw:=FileAccess.get_file_as_string(source)
	var marker:="{\"shape_index\":"
	var begin:=raw.find("\"models\":[")+10
	var end:=raw.find("],\"texture_contract\":",begin)
	var layout_ok:bool=begin>=10 and end>begin and raw.substr(begin,marker.length())==marker and raw.count(marker)==manifest.shapes.size()
	check(layout_ok,"compact scene fixture model boundaries are unambiguous")
	if not layout_ok:return false
	var file:=FileAccess.open(target,FileAccess.WRITE)
	if kind=="compat":
		file.store_string(raw.substr(0,begin))
		for i in VehicleAssets.ROSTER_SHAPES.size():
			var model_marker:=marker+str(VehicleAssets.ROSTER_SHAPES[i])+","
			var at:=raw.find(model_marker,begin)
			var next:=raw.find("},"+marker,at)
			var stop:=next+1 if next>=0 else end
			var found:=at>=begin and at<end and stop>at and stop<=end and raw.count(model_marker)==1
			check(found,"legacy fixture copies one complete approved model")
			if not found:return false
			if i>0:file.store_string(",")
			file.store_string(raw.substr(at,stop-at))
		file.store_string(raw.substr(end))
	else:
		var shape:=153 if kind=="passthrough" else 161
		var model_start:=raw.find(marker+str(shape)+",",begin)
		var model_end:=raw.find("},"+marker,model_start)
		var token:="\"source_passthrough\":[27177]" if kind=="passthrough" else "\"status\":\"partial_opaque\""
		var replacement:="\"source_passthrough\":[99999]" if kind=="passthrough" else "\"status\":\"authored_mesh\""
		var at:=raw.find(token,model_start)
		var another:=raw.find(token,at+token.length())
		var found:=model_start>=begin and model_end>model_start and at>=model_start and at<model_end and (another<0 or another>=model_end)
		check(found,"scene fixture changes exactly the intended model token")
		if not found:return false
		file.store_string(raw.substr(0,at));file.store_string(replacement);file.store_string(raw.substr(at+token.length()))
	return true

func rigid_groups(vehicles:RefCounted,catalog:Dictionary) -> void:
	for shape in vehicles.models:
		var data:=model_packet(catalog,shape,-0.6,0.65,0.30)
		var object:Dictionary=data.objects[0]
		var subject:=VehicleView.new()
		if shape in vehicles.PER_FACE_SHAPES:subject.prepare_object(vehicles,object,data.camera,1,null,{})
		for polygon:Dictionary in object.polygons:
			var face:Dictionary=vehicles.models[shape].faces[int(polygon.primitive)]
			if face.triangles.is_empty() and int(polygon.primitive) not in vehicles.protected_surfaces.get(shape,{}):
				var result:=subject.submit(vehicles,object,polygon,data.camera,1,null,{})
				if shape in vehicles.gpu_poses:
					check(result==0 and subject.active_count==0,"atomic firing pose never admits an individual empty face")
				elif Modern.anchor_frame(face.source,polygon.camera_vertices,data.camera).is_empty():
					# Original Bradley/BTR gun end sheets contain just two repeated
					# points. They have no filled area or valid independent pose.
					check(result==0 and subject.active_count==0,"degenerate original sheet has no inferred mesh")
				else:check(result==-1,"authored empty source face cannot restore an old sheet")
		subject.free()
		for group:Dictionary in vehicles.gpu_groups[shape].values():
			var model:Dictionary=vehicles.models[shape]
			var fit:=VehicleView.rigid_group_fit(model,group,object,data.camera)
			check(not fit.is_empty(),"all observed group vertices agree on rigid pose")
			var swapped:=object.duplicate(true);swapped.polygons.reverse()
			check(fit==VehicleView.rigid_group_fit(model,group,swapped,data.camera),"queue order cannot change selected group anchor")
			var switched:=object.duplicate(true)
			switched.polygons=switched.polygons.filter(func(p):return int(p.primitive)!=int(fit.primitive))
			if switched.polygons.any(func(p):return int(p.primitive) in group.primitives):
				var next:=VehicleView.rigid_group_fit(model,group,switched,data.camera)
				check(not next.is_empty() and next.origin.distance_to(fit.origin)<.002 and next.basis.x.distance_to(fit.basis.x)<.001 and next.basis.y.distance_to(fit.basis.y)<.001 and next.basis.z.distance_to(fit.basis.z)<.001,"anchor switch preserves group pose")
			var missing:=object.duplicate(true)
			missing.polygons=missing.polygons.filter(func(p):return int(p.primitive) not in group.primitives)
			check(VehicleView.rigid_group_fit(model,group,missing,data.camera).is_empty(),"absent group has no inferred pose")
			var broken:=object.duplicate(true)
			for polygon:Dictionary in broken.polygons:
				if int(polygon.primitive) in group.primitives:
					polygon.camera_vertices[0][0]+=20.0;break
			check(VehicleView.rigid_group_fit(model,group,broken,data.camera).is_empty(),"one inconsistent observed anchor rejects whole group")
			var moved:=object.duplicate(true)
			for polygon:Dictionary in moved.polygons:
				if int(polygon.primitive) in group.primitives:
					for point:Array in polygon.camera_vertices:point[0]+=17.0;point[1]+=23.0;point[2]-=9.0
			var fitted:=VehicleView.rigid_group_fit(model,group,moved,data.camera)
			check(not fitted.is_empty() and fitted.origin.distance_to(fit.origin+Vector3(17,23,-9))<.001,"group uses its own observed translation")

func source_line_vertices() -> PackedVector3Array:
	var result:=PackedVector3Array()
	var arrays:Array=draw.mesh_node.mesh.surface_get_arrays(0)
	for i in arrays[Mesh.ARRAY_VERTEX].size():
		var tag:Vector2=arrays[Mesh.ARRAY_TEX_UV][i]
		if tag.x==0.0 and tag.y==32.0:result.append(arrays[Mesh.ARRAY_VERTEX][i])
	return result

func original_rotors(catalog:Dictionary) -> void:
	for shape in [163,164]:
		var model:Dictionary=catalog.models[shape]
		var data:=model_packet(catalog,shape,-0.6,0.65,0.30)
		data.background={"kind":"solid","color":15}
		var center:Vector3=(Modern.vec(model.source_bounds.min)+Modern.vec(model.source_bounds.max))*0.5
		var dim:Vector3=Modern.vec(model.source_bounds.max)-Modern.vec(model.source_bounds.min)
		var depth:=maxf(160.0,maxf(dim.x,maxf(dim.y,dim.z))*1.7)
		var rotation:=Basis(Vector3.RIGHT,0.30)*Basis(Vector3(0,0,1),0.65)
		var original:Dictionary=model.source_lines[0]
		var points:Array=[]
		for raw:Array in original.vertices:
			var point:Vector3=rotation*(Modern.vec(raw)-center)
			points.append([point.x,point.y+depth,point.z])
		data.objects[0].polygons.append({"primitive":original.source_primitive,"fill_mode":0,"colors":[0,0],"camera_vertices":points})
		var unchanged:=JSON.stringify(data)
		draw.tactical_landscape=false
		var before:=await render(data,true)
		var line:=source_line_vertices()
		draw.tactical_landscape=true
		var after:=await render(data,true)
		check(line.size()==6 and line==source_line_vertices(),"original Hind rotor line geometry and width unchanged")
		var quad:Array=Modern.Geometry.line_vertices(points[0],points[1],data.camera)
		var outline:=PackedVector2Array()
		for i in [0,1,2,5]:outline.append(Modern.Geometry.project(quad[i],data.camera))
		var black:=0;var lost:=0;var marked:=0
		var mask:Image=draw.ownership.get_texture().get_image()
		for y in before.get_height():
			for x in before.get_width():
				if before.get_pixel(x,y)==Color.BLACK and Geometry2D.is_point_in_polygon(Vector2((x+.5)/4.0,(y+.5)/4.0),outline):
					black+=1
					if roundi(mask.get_pixel(x,y).b*255.0)==64:marked+=1
					if after.get_pixel(x,y)!=Color.BLACK:lost+=1
		check(black>10 and lost==0 and marked==black,"original Hind rotor pixels retained with exact blue marker byte 64")
		FileAccess.open(output.path_join("rotor-%d.json"%shape),FileAccess.WRITE).store_string(JSON.stringify({"shape":shape,"rotor_black_pixels":black,"lost_pixels":lost,"marker64_pixels":marked},"  "))
		before.save_png(output.path_join("hind-%d-original-rotor-modern.png"%shape))
		check(JSON.stringify(data)==unchanged,"rotor-state input packet unchanged")
		after.save_png(output.path_join("hind-%d-original-rotor.png"%shape))
		if shape==164:await rotor_precedence(data,points,mask)
		draw.tactical_landscape=false
		check(before.get_data()==(await render(data,true)).get_data(),"Modern rotor/body restore exact after marker mode")

func rotor_precedence(data:Dictionary,points:Array,mask:Image) -> void:
	var middle:Vector2=Modern.Geometry.project([(points[0][0]+points[1][0])*.5,(points[0][1]+points[1][1])*.5,(points[0][2]+points[1][2])*.5],data.camera)*4.0
	var sample:=Vector2i(-1,-1)
	for y in range(int(middle.y)-4,int(middle.y)+5):
		for x in range(int(middle.x)-4,int(middle.x)+5):
			if roundi(mask.get_pixel(x,y).b*255.0)==64:sample=Vector2i(x,y)
	check(sample.x>=0,"sampled final-source rotor marker")
	if sample.x<0:return
	var pixel:Vector2=(Vector2(sample)+Vector2(.5,.5))/4.0
	var quad:Array=[]
	for p in [pixel+Vector2(-2,-2),pixel+Vector2(2,-2),pixel+Vector2(2,2),pixel+Vector2(-2,2)]:quad.append(Modern.Geometry.unproject(p,4000.0,data.camera))
	var cover:Dictionary={"primitive":99999,"fill_mode":1,"colors":[7,7],"camera_vertices":quad}
	for kind:String in ["same_owner","other_owner","round"]:
		var changed:=data.duplicate(true)
		if kind=="same_owner":changed.objects[0].polygons.append(cover)
		elif kind=="other_owner":changed.objects.append({"shape_index":999,"root":999,"static_path":true,"polygons":[cover]})
		else:
			var object:Dictionary=changed.objects[0];object.draw_order=[]
			for i in object.polygons.size():object.draw_order.append({"kind":"polygon","index":i})
			var spans:Array=[]
			for y in range(floori(pixel.y)-2,floori(pixel.y)+3):spans.append({"y":y,"left":floori(pixel.x)-2,"right":floori(pixel.x)+3,"color":12})
			object.round_forms=[{"status":"observed","spans":spans}]
			object.draw_order.append({"kind":"round_form","index":0})
		draw.tactical_landscape=true
		await render(changed,true)
		var value:Color=draw.ownership.get_texture().get_image().get_pixelv(sample)
		check(roundi(value.r*255.0)==(2 if kind=="other_owner" else 1) and roundi(value.b*255.0)==(255 if kind=="round" else 8),"later "+kind+" write overrides rotor marker in source order")

func actual_source_groups() -> void:
	var path:=directory.path_join("artifacts/tactical-vehicles-20261017/original-approach/capture.json")
	if not FileAccess.file_exists(path):return # Optional original-game receipt, never a synthetic replacement.
	var receipt:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var data:Dictionary=receipt.presentation.draw_pass
	var unchanged:=JSON.stringify(data)
	draw.tactical_landscape=true
	var view:=await render(data,true)
	view.save_png(output.path_join("captured-original-approach.png"))
	check(draw.tactical_vehicle_view.active_count>0,"actual integer source anchors retain upgraded vehicles")
	check(JSON.stringify(data)==unchanged,"actual source packet remains unchanged")
	FileAccess.open(output.path_join("captured-groups.json"),FileAccess.WRITE).store_string(JSON.stringify({"groups":draw.tactical_vehicle_view.group_count,"instances":draw.tactical_vehicle_view.active_count,"max_anchor_error":draw.tactical_vehicle_assets.max_anchor_error},"  "))

func reject_incomplete_pair() -> void:
	var temporary:=output.path_join("incomplete-pair")
	for relative in ["local-art/pc-modern/catalog.json","local-art/pc-modern/source-shapes.json","local-art/pc-tactical-vehicles-v1/catalog.json","local-art/pc-tactical-vehicles-v1/manifest.json","local-art/pc-tactical-vehicles-v1/albedo.png","local-art/pc-tactical-vehicles-v1/normal.png","local-art/pc-tactical-vehicles-v1/orm.png"]:
		var destination:=temporary.path_join(relative)
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		check(DirAccess.copy_absolute(directory.path_join(relative),destination)==OK,"copy rejection fixture")
	var folder:=temporary.path_join("local-art/pc-tactical-vehicles-v1")
	var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("catalog.json")))
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("manifest.json")))
	for kind in ["empty","unresolved"]:
		var broken:=original.duplicate(true)
		if kind=="empty":broken.models[0].triangles=[]
		else:broken.models[0].status="unresolved_placeholder"
		FileAccess.open(folder.path_join("catalog.json"),FileAccess.WRITE).store_string(JSON.stringify(broken))
		manifest.files["catalog.json"]=FileAccess.get_sha256(folder.path_join("catalog.json"))
		FileAccess.open(folder.path_join("manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(manifest))
		var rejected=VehicleAssets.new()
		check(not rejected.load_detail(temporary) and not rejected.ready and rejected.models.is_empty(),"rehash cannot admit "+kind+" half-pair")

func scene_contracts(catalog:Dictionary) -> void:
	var evidence:Array=[]
	for shape in [0,1,45,46,47,108,114]:
		var data:=model_packet(catalog,shape,-.6,.65,.30)
		var model:Dictionary=catalog.models[shape]
		var center:Vector3=(Modern.vec(model.source_bounds.min)+Modern.vec(model.source_bounds.max))*.5
		var dim:Vector3=Modern.vec(model.source_bounds.max)-Modern.vec(model.source_bounds.min)
		var depth:=maxf(160.0,maxf(dim.x,maxf(dim.y,dim.z))*1.7)
		var rotation:=Basis(Vector3.RIGHT,.30)*Basis(Vector3(0,0,1),.65)
		for primitive:Dictionary in model.source_primitives:
			if primitive.vertices.size()!=2:continue
			var points:Array=[]
			for raw:Array in primitive.vertices:
				var point:Vector3=rotation*(Modern.vec(raw)-center)
				points.append([point.x,point.y+depth,point.z])
			data.objects[0].polygons.append({"primitive":int(primitive.id),"fill_mode":0,"colors":[int(primitive.prefix_bytes[1]),int(primitive.prefix_bytes[2])],"camera_vertices":points})
		draw.tactical_landscape=false
		await render(data,true)
		var original_geometry:PackedVector3Array=draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		# Original line endpoints/widths are emitted by the same common path;
		# retain their exact isolated packet geometry across the material switch.
		var lines:=data.duplicate(true)
		lines.objects[0].polygons=lines.objects[0].polygons.filter(func(p):return p.fill_mode==0)
		if not lines.objects[0].polygons.is_empty():
			await render(lines,true)
			var before:PackedVector3Array=draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			draw.tactical_landscape=true
			await render(lines,true)
			check(before==draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"bridge original line geometry and width remain exact")
		draw.tactical_landscape=true
		await render(data,true)
		check(draw.tactical_vehicle_view.group_count==0,"coplanar bridge decks retain source primitive ordering")
		check(not original_geometry.is_empty(),"bridge source geometry exercised")
	for shape in [153,156]:
		for focal in [96.0,336.0]:
			var data:=model_packet(catalog,shape,-.6,.65,.30);data.camera.focal_pixels=focal
			draw.tactical_landscape=true;draw.tactical_vehicle_assets.ready=false
			var incumbent:=await render(data,true)
			draw.tactical_vehicle_assets.ready=true
			var detailed:=await render(data,true)
			var mask:Image=draw.ownership.get_texture().get_image()
			var protected:=0;var changed:=0
			for y in mask.get_height():
				for x in mask.get_width():
					if owner_id(mask.get_pixel(x,y))==1 and roundi(mask.get_pixel(x,y).b*255.0)==64:
						protected+=1
						if detailed.get_pixel(x,y)!=incumbent.get_pixel(x,y):changed+=1
			check(protected>0 and changed==0,"original authored flag colours and coverage exact at near/far scales")
			evidence.append({"shape":shape,"focal":focal,"protected_flag_pixels":protected,"changed_pixels":changed})
	for shape in [161,162]:
		var data:=model_packet(catalog,shape,-.6,0.0,0.0)
		if shape in _posed_shapes:
			# R13 pose has a separate native ground-crew gate. Keep a fail-closed
			# witness here; the absent-field relief contract below remains intact.
			data.objects[0].round_forms=[];data.objects[0].erase("draw_order")
			var fallback_image:=await render(data,true)
			check(draw.tactical_vehicle_view.active_count==0,"pose without witnessed head selects complete incumbent")
			draw.tactical_vehicle_assets.ready=false
			check(fallback_image.get_data()==(await render(data,true)).get_data(),"pose missing-head fallback exact")
			draw.tactical_vehicle_assets.ready=true
			continue
		data.camera.clip=[0,0,159,99];data.camera.center=[80,50];data.camera.focal_pixels=168.0
		for reverse:bool in [false,true]:
			if reverse:data.objects[0].polygons.reverse()
			await crew_layer_witness(data)
			if reverse:data.objects[0].polygons.reverse()
		var unknown:=data.duplicate(true)
		var fallback:Dictionary=unknown.objects[0].polygons[-1].duplicate(true)
		fallback.primitive=999999;fallback.colors=[7,7]
		unknown.objects[0].polygons.append(fallback)
		var fallback_image:=await render(unknown,true)
		check(draw.tactical_vehicle_view.active_count==0,"one unsupported flat primitive selects complete common painter fallback")
		draw.tactical_vehicle_assets.ready=false
		check(fallback_image.get_data()==(await render(unknown,true)).get_data(),"later fallback primitive cannot be overpainted by earlier HQ faces")
		draw.tactical_vehicle_assets.ready=true
		var repeated:=data.duplicate(true);repeated.objects[0].draw_order=[]
		for i in 128:repeated.objects[0].draw_order.append({"kind":"polygon","index":i%repeated.objects[0].polygons.size()})
		await render(repeated,true)
		check(draw.tactical_vehicle_view.active_count>0,"depth-tested crew does not inherit transparent painter priority limit")
		var body:=await render(data,true)
		check(draw.source_round_count==0 and draw.tactical_vehicle_view.group_count==0,"relief crew admits no invented head or grouped pose")
		var spans:Array=[]
		for y in range(37,44):spans.append({"y":y,"left":76,"right":85,"color":12})
		var object:Dictionary=data.objects[0];object.draw_order=[]
		for i in object.polygons.size():object.draw_order.append({"kind":"polygon","index":i})
		object.round_forms=[{"status":"observed","command_offset":30996 if shape==161 else 31422,"command":[170,15,2,171],"fill_mode":1,"radius":7,"horizontal_radius":9,"center":[80,40],"spans":spans}]
		object.draw_order.append({"kind":"round_form","index":0})
		var headed:=await render(data,true)
		check(draw.source_round_count==1,"observed original crew head remains independent")
		var modelled:bool=shape in draw.tactical_vehicle_assets.gpu_heads
		check(draw.tactical_vehicle_view.head_count==(1 if modelled else 0),"modelled head admitted only for the independent observed command")
		draw.tactical_vehicle_assets.ready=false
		var incumbent:=await render(data,true)
		var missing_head_pixels:=0
		for y in range(148,176):
			for x in range(304,340):
				if headed.get_pixel(x,y)==Color.BLACK and incumbent.get_pixel(x,y)!=Color.BLACK:missing_head_pixels+=1
		# A natural jaw/helmet can leave terrain-visible cutouts inside the
		# original ellipse. Ownership remains opaque to concealed actors.
		check(missing_head_pixels<504 if modelled else missing_head_pixels==0,"substantial modelled head or exact fallback occupancy inside the source head region")
		if modelled:check(headed.get_region(Rect2i(304,148,36,28)).get_data()!=incumbent.get_region(Rect2i(304,148,36,28)).get_data(),"real textured head replaces the incumbent flat head")
		draw.tactical_vehicle_assets.ready=true
		object.round_forms=[];object.erase("draw_order")
		check(body.get_data()==(await render(data,true)).get_data(),"removing original round restores exact textured body")
	FileAccess.open(output.path_join("scene-contracts.json"),FileAccess.WRITE).store_string(JSON.stringify(evidence,"  "))

func crew_layer_witness(data:Dictionary) -> void:
	# Native depth self-occlusion must be independent of primitive submission.
	# A depth-disabled negative control ensures this witness observes relief.
	await render(data,true)
	var common:bool=draw.mesh_node.visible;draw.mesh_node.visible=false
	var nodes:Array=[];var originals:Array=[]
	var colours:Array=[Vector3(1,0,0),Vector3(0,1,0),Vector3(0,0,1),Vector3(1,1,0),Vector3(1,0,1),Vector3(0,1,1),Vector3(1,1,1)]
	var shape:int=data.objects[0].shape_index
	for instance:MeshInstance3D in draw.tactical_vehicle_view.instances:
		if not instance.visible:continue
		var original:ShaderMaterial=instance.material_override;originals.append(original);nodes.append(instance)
		check(original.render_priority==0 and not original.shader.code.contains("depth_test_disabled"),"crew has opaque depth shader after pooled reuse")
		var primitive:=-1
		for pid in draw.tactical_vehicle_assets.gpu_faces[shape]:
			var meshes:Dictionary=draw.tactical_vehicle_assets.gpu_faces[shape][pid]
			if instance.mesh==meshes.affine or instance.mesh==meshes.piecewise:primitive=pid;break
		check(primitive>=0,"depth witness identifies original source primitive")
		var colour:Vector3=colours[posmod(primitive,7)]
		var code:String=original.shader.code;var stop:=code.find("    ALBEDO=camera_basis_ready")
		var shader:=Shader.new();shader.code=code.substr(0,stop)+"    ALBEDO=vec3(%f,%f,%f);\n}\n"%[colour.x,colour.y,colour.z]
		var witness:=ShaderMaterial.new();witness.shader=shader
		for uniform:Dictionary in original.shader.get_shader_uniform_list():witness.set_shader_parameter(uniform.name,original.get_shader_parameter(uniform.name))
		instance.material_override=witness
	var actual:=await capture()
	for node:MeshInstance3D in nodes:node.visible=false
	var empty:=await capture();var stack:Image=empty.duplicate()
	var interior_mismatch:=0;var interior_samples:=0
	if shape in _crew_depth_reference:
		var first:Image=_crew_depth_reference[shape]
		for y in range(1,actual.get_height()-1):
			for x in range(1,actual.get_width()-1):
				var a:Color=actual.get_pixel(x,y);var b:Color=first.get_pixel(x,y)
				# Compatibility's clear frame is grey, not Color.BLACK. The
				# captured empty frame excludes its actual background/alpha.
				if a==empty.get_pixel(x,y) and b==empty.get_pixel(x,y):continue
				if [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1)].all(func(v):return actual.get_pixel(x+v.x,y+v.y)==a and first.get_pixel(x+v.x,y+v.y)==b):
					interior_samples+=1
					if a!=b:interior_mismatch+=1
		check(interior_samples>100 and interior_mismatch==0,"opaque crew depth winners independent of source submission order")
	else:_crew_depth_reference[shape]=actual.duplicate()

	var overlap:=0;var filled:=0
	for node:MeshInstance3D in nodes:
		node.visible=true
		var isolated:=await capture();node.visible=false
		for y in isolated.get_height():
			for x in isolated.get_width():
				var colour:=isolated.get_pixel(x,y)
				if colour!=empty.get_pixel(x,y):
					filled+=1
					if stack.get_pixel(x,y)!=empty.get_pixel(x,y):overlap+=1
					stack.set_pixel(x,y,colour)
	for node:MeshInstance3D in nodes:
		node.visible=true
		var disabled:=Shader.new();disabled.code=node.material_override.shader.code.replace("depth_draw_opaque","depth_test_disabled,depth_draw_never")
		node.material_override.shader=disabled
	var depth_off:=await capture();var depth_effect:=0
	for y in actual.get_height():
		for x in actual.get_width():
			if actual.get_pixel(x,y)!=depth_off.get_pixel(x,y):depth_effect+=1
	# One painter order can already approximate the correct depth winners.
	# The paired depth-disabled orders must disagree, while actual depth above
	# must remain invariant. Keep the original >20 interior-pixel threshold.
	var negative_samples:=0;var negative_mismatch:=-1
	if shape in _crew_negative_reference:
		negative_mismatch=0
		var first_off:Image=_crew_negative_reference[shape]
		for y in range(1,depth_off.get_height()-1):
			for x in range(1,depth_off.get_width()-1):
				var a:Color=depth_off.get_pixel(x,y);var b:Color=first_off.get_pixel(x,y)
				if a==empty.get_pixel(x,y) and b==empty.get_pixel(x,y):continue
				if [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1)].all(func(v):return depth_off.get_pixel(x+v.x,y+v.y)==a and first_off.get_pixel(x+v.x,y+v.y)==b):
					negative_samples+=1
					if a!=b:negative_mismatch+=1
		check(negative_samples>100 and negative_mismatch>20,"depth-disabled crew control detects submission order dependence")
	else:_crew_negative_reference[shape]=depth_off.duplicate()
	var label:="crew-%d-%s"%[shape,str(data.objects[0].polygons[0].primitive)]
	actual.save_png(output.path_join(label+"-actual.png"));depth_off.save_png(output.path_join(label+"-depth-off.png"))
	FileAccess.open(output.path_join(label+".json"),FileAccess.WRITE).store_string(JSON.stringify({"instances":nodes.size(),"filled":filled,"overlap":overlap,"depth_effect_pixels":depth_effect,"opaque_priorities":originals.map(func(m):return m.render_priority),"interior_samples":interior_samples,"submission_order_mismatch":interior_mismatch,"negative_control_interior_samples":negative_samples,"negative_control_order_mismatch":negative_mismatch}))
	check(filled>100 and overlap>0,"native crew relief has observable overlapping surfaces")
	for i in nodes.size():nodes[i].material_override=originals[i];nodes[i].visible=true
	draw.mesh_node.visible=common

func owner_id(value:Color) -> int:
	return roundi(value.r*255.0)+256*roundi(value.g*255.0)

func coverage_allowed(value:Color,owner:int,strict:bool=false) -> bool:
	var id:=owner_id(value);var flag:=roundi(value.b*255.0)
	return (id==owner and flag==8) or (not strict and id<owner and flag==0)

func vehicle_coverage(owner:int,unmasked:bool) -> Image:
	# Same production vertex/fragment program, with explicit white coverage.
	# The reference removes only ownership rejection, never reconstructs meshes.
	var source:String=preload("res://scripts/pc_tactical_vehicles.gdshader").code
	var stop:=source.find("    // Original painter ownership") if unmasked else source.find("    ALBEDO=camera_basis_ready")
	check(stop>0,"coverage witness production anchor")
	var witness:=Shader.new();witness.code=source.substr(0,stop)+"    ALBEDO=vec3(1.0);\n}\n"
	var saved:Array=[]
	var common_visible:bool=draw.mesh_node.visible;draw.mesh_node.visible=false
	for instance:MeshInstance3D in draw.tactical_vehicle_view.instances:
		if not instance.visible:continue
		var original:ShaderMaterial=instance.material_override
		saved.append([instance,original])
		if int(original.get_shader_parameter("instance_owner"))!=owner:
			instance.visible=false;continue
		var replacement:=ShaderMaterial.new();replacement.shader=witness
		for uniform:Dictionary in original.shader.get_shader_uniform_list():replacement.set_shader_parameter(uniform.name,original.get_shader_parameter(uniform.name))
		instance.material_override=replacement
	var pixels:=await capture()
	for item:Array in saved:item[0].material_override=item[1];item[0].visible=true
	draw.mesh_node.visible=common_visible
	return pixels

func visibility_case(data:Dictionary,owner:int,name:String,extension_expected:bool=false,occlusion_expected:bool=false) -> Dictionary:
	var unchanged:=JSON.stringify(data)
	draw.tactical_landscape=true
	var appearance:=await render(data,true)
	var mask:Image=draw.ownership.get_texture().get_image()
	var actual:=await vehicle_coverage(owner,false)
	var reference:=await vehicle_coverage(owner,true)
	var strict:bool=int(data.objects[owner-1].get("shape_index",-1)) not in VehicleAssets.ROSTER_SHAPES
	var eligible:=0;var extensions:=0;var blocked:=0;var missing:=0;var leaks:=0
	for y in reference.get_height():
		for x in reference.get_width():
			var full:=reference.get_pixel(x,y).r>.5
			var drawn:=actual.get_pixel(x,y).r>.5
			var value:=mask.get_pixel(x,y)
			var allowed:=coverage_allowed(value,owner,strict)
			if full and allowed:
				eligible+=1
				if owner_id(value)!=owner:extensions+=1
				if not drawn:missing+=1
			if full and not allowed:blocked+=1
			if drawn and (not full or not allowed):leaks+=1
	check(eligible>100 and missing==0,name+": complete eligible authored silhouette")
	check(leaks==0,name+": no protected-source overpaint")
	if extension_expected:check(extensions>0,name+": restored extension coverage exercised")
	if occlusion_expected:check(blocked>0,name+": forbidden coverage exercised")
	check(JSON.stringify(data)==unchanged,name+": original packet unchanged")
	if name=="brdm-background":
		appearance.save_png(output.path_join("after-brdm.png"))
		actual.save_png(output.path_join("brdm-coverage.png"))
	return {"case":name,"owner":owner,"eligible_pixels":eligible,"extension_pixels":extensions,"blocked_pixels":blocked,"missing_pixels":missing,"forbidden_pixels":leaks}

func visibility_cover(data:Dictionary,terrain:bool) -> Dictionary:
	var points:Array=[]
	for pixel in [Vector2(0,0),Vector2(data.camera.center[0],0),Vector2(data.camera.center[0],200),Vector2(0,200)]:points.append(Geometry.unproject(pixel,4000.0,data.camera))
	return {"shape_index":int(art.terrain_shapes.keys()[0]) if terrain else 999,"root":999,"static_path":true,"polygons":[{"primitive":99999,"fill_mode":1,"colors":[7,7],"camera_vertices":points}]}

func visibility_coverage(catalog:Dictionary) -> void:
	var evidence:Array=[]
	var base:=model_packet(catalog,141 if 141 in draw.tactical_vehicle_assets.models else 125,-0.6,PI+.65,.30)
	base.camera.focal_pixels=336.0
	evidence.append(await visibility_case(base,1,"brdm-background",true))
	# Half-size studies keep the regression matrix within the existing deadline.
	base.camera.clip=[0,0,159,99];base.camera.center=[80,50];base.camera.focal_pixels=168.0
	for terrain:bool in [true,false]:
		for earlier:bool in [true,false]:
			var data:=base.duplicate(true);var cover:=visibility_cover(data,terrain)
			if earlier:data.objects.push_front(cover)
			else:data.objects.append(cover)
			evidence.append(await visibility_case(data,2 if earlier else 1,("terrain" if terrain else "target")+("-earlier" if earlier else "-later"),true,not (terrain and earlier)))
	var high:=base.duplicate(true)
	for i in 255:high.objects.push_front({"shape_index":999,"polygons":[]})
	evidence.append(await visibility_case(high,256,"owner-256",true))
	var other:Dictionary=base.objects[0].duplicate(true)
	for polygon:Dictionary in other.polygons:
		for point:Array in polygon.camera_vertices:point[0]+=50.0;point[1]+=80.0
	for reverse:bool in [false,true]:
		var both:=base.duplicate(true)
		if reverse:both.objects.push_front(other)
		else:both.objects.append(other)
		for owner in [1,2]:evidence.append(await visibility_case(both,owner,"same-shape-%s-owner-%d"%[reverse,owner],false,true))
	for near:bool in [false,true]:
		var edge:=model_packet(catalog,115,-0.6,.65,.30)
		edge.camera.clip=[0,0,159,99];edge.camera.center=[80,50];edge.camera.focal_pixels=96.0
		for polygon:Dictionary in edge.objects[0].polygons:
			for point:Array in polygon.camera_vertices:
				if near:point[1]-=480.0
				else:point[0]+=370.0
		evidence.append(await visibility_case(edge,1,"near-plane" if near else "viewport-edge"))
	for shape in [161,162]:
		var crew:=model_packet(catalog,shape,-.6,.65,.30)
		crew.camera.clip=[0,0,159,99];crew.camera.center=[80,50];crew.camera.focal_pixels=96.0
		for polygon:Dictionary in crew.objects[0].polygons:
			for point:Array in polygon.camera_vertices:point[1]-=170.0
		evidence.append(await visibility_case(crew,1,"crew-near-plane-%d"%shape))
	# Guard ordinary unknown-object edges and bitmap runs as well as fills.
	var commands:=base.duplicate(true)
	commands.objects.append({"shape_index":999,"static_path":true,"draw_order":[{"kind":"polygon","index":0},{"kind":"round_form","index":0}],"polygons":[{"primitive":9999,"fill_mode":0,"colors":[6,6],"camera_vertices":[Geometry.unproject(Vector2(10,10),4000.0,base.camera),Geometry.unproject(Vector2(30,10),4000.0,base.camera)]}],"sprite":{"width":2,"height":1,"pixels":[6,6],"opaque":[true,true],"origin":[10,12],"clip":[0,0,159,99]},"round_forms":[{"status":"observed","spans":[{"y":14,"left":10,"right":12,"color":12}]}]})
	await render(commands,true)
	var classification:Image=draw.ownership.get_texture().get_image()
	for sample:Vector3i in [Vector3i(20,10,8),Vector3i(10,12,8),Vector3i(10,14,255)]:
		var value:=classification.get_pixel(sample.x*4+1,sample.y*4+1)
		check(owner_id(value)==2 and roundi(value.b*255.0)==sample.z,"native edge/sprite/round classification "+str(sample))
	# Exact restoration covers mode switching, disabled-detail fallback, cache
	# hits and ownership render-target resize, including the mask's blue byte.
	draw.tactical_landscape=false
	var modern:=await render(base,true);var modern_mask:PackedByteArray=draw.ownership.get_texture().get_image().get_data()
	draw.tactical_landscape=true
	var detail:=await render(base,true);var detail_mask:PackedByteArray=draw.ownership.get_texture().get_image().get_data()
	var builds:int=draw.mesh_build_count
	check(detail.get_data()==(await render(base,true)).get_data() and builds==draw.mesh_build_count and detail_mask==draw.ownership.get_texture().get_image().get_data(),"same-packet cache retains exact Tactical image and mask")
	draw.tactical_vehicle_assets.ready=false
	var fallback:=await render(base,true);var fallback_mask:PackedByteArray=draw.ownership.get_texture().get_image().get_data()
	draw.tactical_vehicle_assets.ready=true
	var resized:=base.duplicate(true);resized.camera.clip=[0,0,319,199];resized.camera.center=[160,100];resized.camera.focal_pixels=336.0
	await render(resized,true)
	draw.tactical_vehicle_assets.ready=false
	check(fallback.get_data()==(await render(base,true)).get_data() and fallback_mask==draw.ownership.get_texture().get_image().get_data(),"readiness fallback restores exact image and unclassified mask after resize")
	draw.tactical_vehicle_assets.ready=true;draw.tactical_landscape=false
	check(modern.get_data()==(await render(base,true)).get_data() and modern_mask==draw.ownership.get_texture().get_image().get_data(),"Modern image and mask restore exactly after Tactical and resize")
	FileAccess.open(output.path_join("visibility.json"),FileAccess.WRITE).store_string(JSON.stringify(evidence,"  "))

func renderer_timing(catalog:Dictionary,shapes:Array=[115,125]) -> void:
	var timing:Array=[]
	for shape in shapes:
		var data:=model_packet(catalog,shape,-0.6,0.65,0.30);data.camera.focal_pixels=336.0
		for detail in [false,true,true,false]:
			draw.tactical_vehicle_assets.ready=detail;draw.tactical_landscape=true
			await render(data,true)
			var begin:=Time.get_ticks_usec()
			for tick in 12:RenderingServer.force_draw(false);RenderingServer.force_sync()
			timing.append({"shape":shape,"detail":detail,"synchronized_renderer_ms":float(Time.get_ticks_usec()-begin)/12000.0})
	draw.tactical_vehicle_assets.ready=true
	FileAccess.open(output.path_join("renderer-timing.json"),FileAccess.WRITE).store_string(JSON.stringify(timing,"  "))

func ownership_occluder(catalog:Dictionary) -> Dictionary:
	draw.tactical_landscape=true
	var data:=model_packet(catalog,125,-0.6,0.65,0.30)
	# A deliberately farther source-painter occluder must hide the complete pair.
	var points:Array=[]
	for pixel in [Vector2(0,0),Vector2(320,0),Vector2(320,200),Vector2(0,200)]:points.append(Geometry.unproject(pixel,4000.0,data.camera))
	data.objects.append({"shape_index":999,"root":999,"static_path":true,"polygons":[{"primitive":999,"fill_mode":1,"colors":[1,1],"camera_vertices":points}]})
	var concealed:=await render(data,true)
	draw.tactical_vehicle_assets.ready=false
	check(concealed.get_data()==(await render(data,true)).get_data(),"farther later source owner hides every detailed fragment")
	draw.tactical_vehicle_assets.ready=true
	data.objects.pop_back()
	return data

func ownership_overlap(catalog:Dictionary) -> void:
	var data:Dictionary=await ownership_occluder(catalog)
	var object:Dictionary=data.objects[0]
	object.draw_order=[]
	for i in object.polygons.size():object.draw_order.append({"kind":"polygon","index":i})
	var spans:Array=[]
	for y in range(90,106):spans.append({"y":y,"left":135,"right":185,"color":12})
	object.round_forms=[{"status":"observed","spans":spans}]
	object.draw_order.append({"kind":"round_form","index":0})
	var rounded:=await render(data,true)
	draw.tactical_vehicle_assets.ready=false
	var control:=await render(data,true)
	check(rounded.get_region(Rect2i(540,360,200,64)).get_data()==control.get_region(Rect2i(540,360,200,64)).get_data(),"observed round writes override GPU model depth")
	draw.tactical_vehicle_assets.ready=true
	data=model_packet(catalog,125,-0.6,0.65,0.30)
	var second:Dictionary=data.objects[0].duplicate(true)
	for polygon:Dictionary in second.polygons:
		for point:Array in polygon.camera_vertices:point[0]+=110;point[1]+=80
	data.objects.append(second)
	await render(data,true)
	var seen:Dictionary={}
	for instance in draw.tactical_vehicle_view.instances:
		if instance.visible:seen[int(instance.material_override.get_shader_parameter("instance_owner"))]=true
	check(seen.has(1) and seen.has(2),"same-shape actors retain independent fit and owner uniforms")
	data=model_packet(catalog,125,-0.6,0.65,0.30)
	var hull:Dictionary=draw.tactical_vehicle_assets.gpu_groups[125].values()[0]
	data.objects[0].polygons=data.objects[0].polygons.filter(func(p):return int(p.primitive) not in hull.primitives)
	await render(data,true)
	check(draw.tactical_vehicle_view.group_count==3 and not draw.tactical_vehicle_view.covers(1,hull.primitives[0]),"missing hull cannot borrow turret or gun pose")
	data=model_packet(catalog,125,-0.6,0.65,0.30)
	for polygon:Dictionary in data.objects[0].polygons:
		if int(polygon.primitive) in hull.primitives:
			polygon.camera_vertices[0][0]+=20.0;break
	await render(data,true)
	check(draw.tactical_vehicle_view.group_count==3 and not draw.tactical_vehicle_view.covers(1,hull.primitives[0]),"inconsistent hull uses face fallback without stale group suppression")
	draw.apply_pass({"objects":[]})
	check(draw.tactical_vehicle_view.active_count==0,"empty source pass clears all pooled faces")
	for near in [false,true]:
		data=model_packet(catalog,115,-0.6,0.65,0.30)
		for polygon:Dictionary in data.objects[0].polygons:
			for point:Array in polygon.camera_vertices:
				if near:point[1]-=480.0
				else:point[0]+=370.0
		var edge:=await render(data,true)
		var owners:Image=draw.ownership.get_texture().get_image()
		var visible:=0;var outside:=0
		for y in edge.get_height():
			for x in edge.get_width():
				if edge.get_pixel(x,y)!=Color.BLACK:
					visible+=1
					var owner:=owners.get_pixel(x,y)
					if not coverage_allowed(owner,1):outside+=1
		check(visible>100 and outside==0,"GPU near/viewport clipping retains permitted visible geometry")
	draw.apply_pass({"objects":[]})
	check(draw.tactical_vehicle_view.active_count==0,"clipped pass leaves no stale pooled faces")

func gpu_position_contract() -> void:
	# Run the actual production vertex program, then encode its camera position
	# into RGB24 point pixels. This checks GPU execution, not a CPU float emulation.
	var production:String=preload("res://scripts/pc_tactical_vehicles.gdshader").code
	var code:=production.substr(0,production.find("void fragment()"))
	code=code.replace("depth_draw_opaque","depth_test_disabled,depth_draw_never")
	code=code.replace("void vertex() {","uniform sampler2D test_byte_inputs:filter_nearest,repeat_disable;\nvarying float test_value;\nvoid vertex() {")
	code=code.replace("    VERTEX=vec3(raw.x,raw.z,-raw.y)/64.0;","    VERTEX=vec3(raw.x,raw.z,-raw.y)/64.0;\n    test_value=raw[int(round(COLOR.r*2.0))];\n    vec2 pixel=vec2(mod(UV2.y,512.0),floor(UV2.y/512.0))+vec2(0.5);\n    POSITION=vec4(pixel.x/256.0-1.0,1.0-pixel.y/512.0,0.0,1.0);\n    POINT_SIZE=1.0;")
	code+="void fragment(){float bits=floor(clamp((test_value+4096.0)/8192.0,0.0,1.0)*16777215.0+0.5);vec3 bytes=vec3(floor(bits/65536.0),mod(floor(bits/256.0),256.0),mod(bits,256.0));ALBEDO=vec3(texture(test_byte_inputs,vec2((bytes.r+0.5)/256.0,0.5)).r,texture(test_byte_inputs,vec2((bytes.g+0.5)/256.0,0.5)).r,texture(test_byte_inputs,vec2((bytes.b+0.5)/256.0,0.5)).r);}"
	var shader:=Shader.new();shader.code=code
	# Reuse the established inverse Compatibility colour round trip. Encoding
	# bytes directly through unshaded ALBEDO crushes low RGB values on this driver.
	var byte_inputs:=Image.create(256,1,false,Image.FORMAT_RGBAF)
	for value in 256:byte_inputs.set_pixel(value,0,ReferenceColour.input_color([value,value,value],true))
	var byte_texture:=ImageTexture.create_from_image(byte_inputs)
	var target:=SubViewport.new();target.size=Vector2i(512,1024);target.own_world_3d=true;target.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(target)
	var eye:=Camera3D.new();target.add_child(eye);eye.make_current()
	var evidence:Array=[]
	for distorted in [false,true]:
		var expected:Array[Vector3]=[];var nodes:Array[MeshInstance3D]=[];var piecewise_faces:=0;var group_corners:=0
		for shape in [115,125,161]:
			for primitive in draw.tactical_vehicle_assets.gpu_faces[shape]:
				var face:Dictionary=draw.tactical_vehicle_assets.models[shape].faces[primitive]
				var observed:Array=[]
				for raw:Array in face.source:observed.append([raw[0]*.8+raw[1]*.6,500.0-raw[0]*.6+raw[1]*.8,raw[2]])
				if distorted and observed.size()>3:observed[-1][0]+=1.0
				var fit:Dictionary=Modern.anchor_frame(face.source,observed,frame)
				check(not fit.is_empty(),"GPU proof fit accepted")
				if fit.is_empty():continue
				var piecewise:bool=fit.get("piecewise",false)
				if piecewise:piecewise_faces+=1
				var model:Dictionary=draw.tactical_vehicle_assets.gpu_faces[shape][primitive]
				var arrays:Array=(model.piecewise if piecewise else model.affine).surface_get_arrays(0)
				var points:=PackedVector3Array();var uv:=PackedVector2Array();var channels:=PackedColorArray()
				for i in face.corners.size():
					var reference:Vector3=Modern.transform_point(Modern.vec(face.corners[i].raw),fit)
					for channel in 3:
						points.append(arrays[Mesh.ARRAY_VERTEX][i]);uv.append(Vector2(arrays[Mesh.ARRAY_TEX_UV2][i].x,expected.size()*3+channel));channels.append(Color(float(channel)/2.0,0,0,1))
					expected.append(reference)
				var buffers:=[];buffers.resize(Mesh.ARRAY_MAX);buffers[Mesh.ARRAY_VERTEX]=points;buffers[Mesh.ARRAY_TEX_UV2]=uv;buffers[Mesh.ARRAY_COLOR]=channels
				var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS,buffers)
				var instance:=MeshInstance3D.new();instance.mesh=mesh;instance.custom_aabb=AABB(Vector3(-100000,-100000,-100000),Vector3(200000,200000,200000))
				var material:=ShaderMaterial.new();material.shader=shader
				material.set_shader_parameter("test_byte_inputs",byte_texture)
				material.set_shader_parameter("source_piecewise",piecewise);material.set_shader_parameter("source_camera",fit.camera);material.set_shader_parameter("source_cu",fit.cu);material.set_shader_parameter("source_cv",fit.cv);material.set_shader_parameter("source_cn",fit.cn)
				var anchors:=PackedVector3Array();anchors.resize(16)
				for i in observed.size():anchors[i]=Modern.vec(observed[i])
				material.set_shader_parameter("source_anchors",anchors);instance.material_override=material;target.add_child(instance);nodes.append(instance)
			# Exercise actual raw-position group meshes through the production
			# matrix branch, against the independent CPU face-fit equations.
			var asset:Dictionary=draw.tactical_vehicle_assets.models[shape]
			var object:Dictionary={"polygons":[]}
			for primitive in asset.faces:
				var face:Dictionary=asset.faces[primitive]
				var observed:Array=[]
				for raw:Array in face.source:observed.append([raw[0]*.8+raw[1]*.6,500.0-raw[0]*.6+raw[1]*.8,raw[2]])
				object.polygons.append({"primitive":primitive,"fill_mode":1,"camera_vertices":observed})
			for group:Dictionary in draw.tactical_vehicle_assets.gpu_groups[shape].values():
				var fit:=VehicleView.rigid_group_fit(asset,group,object,frame)
				check(not fit.is_empty(),"GPU group proof has independently admitted anchors")
				if fit.is_empty():continue
				var selected:Dictionary=object.polygons.filter(func(p):return p.primitive==fit.primitive)[0]
				var source_fit:=Modern.anchor_frame(asset.faces[fit.primitive].source,selected.camera_vertices,frame)
				var raw_points:PackedVector3Array=group.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				var points:=PackedVector3Array();var uv:=PackedVector2Array();var channels:=PackedColorArray()
				for raw:Vector3 in raw_points:
					for channel in 3:
						points.append(raw);uv.append(Vector2(0,expected.size()*3+channel));channels.append(Color(float(channel)/2.0,0,0,1))
					expected.append(Modern.transform_point(raw,source_fit));group_corners+=1
				var buffers:=[];buffers.resize(Mesh.ARRAY_MAX);buffers[Mesh.ARRAY_VERTEX]=points;buffers[Mesh.ARRAY_TEX_UV2]=uv;buffers[Mesh.ARRAY_COLOR]=channels
				var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS,buffers)
				var instance:=MeshInstance3D.new();instance.mesh=mesh;instance.custom_aabb=AABB(Vector3(-100000,-100000,-100000),Vector3(200000,200000,200000))
				var material:=ShaderMaterial.new();material.shader=shader
				material.set_shader_parameter("test_byte_inputs",byte_texture);material.set_shader_parameter("source_group",true)
				material.set_shader_parameter("source_group_basis",fit.basis);material.set_shader_parameter("source_group_origin",fit.origin)
				instance.material_override=material;target.add_child(instance);nodes.append(instance)
		check(expected.size()*3<=512*1024,"GPU proof viewport holds every authored corner")
		await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
		var pixels:=target.get_texture().get_image();var max_raw:=0.0;var max_pixel:=0.0;var samples:Array=[]
		pixels.save_png(output.path_join("gpu-position-"+str(distorted)+".png"))
		for i in expected.size():
			var actual:=Vector3.ZERO
			for channel in 3:
				var index:=i*3+channel
				# Compatibility's direct POSITION target is vertically flipped.
				var colour:=pixels.get_pixel(index%512,1023-index/512)
				var bits:=roundi(colour.r*255.0)*65536+roundi(colour.g*255.0)*256+roundi(colour.b*255.0)
				actual[channel]=float(bits)/16777215.0*8192.0-4096.0
			max_raw=maxf(max_raw,actual.distance_to(expected[i]))
			if i<8:samples.append({"actual":[actual.x,actual.y,actual.z],"expected":[expected[i].x,expected[i].y,expected[i].z]})
			var a:=Geometry.project([actual.x,actual.y,actual.z],frame);var b:=Geometry.project([expected[i].x,expected[i].y,expected[i].z],frame)
			max_pixel=maxf(max_pixel,a.distance_to(b))
		check(max_raw<0.01 and max_pixel<0.02,"actual GPU positions reproduce CPU fit within source pixel tolerance")
		if distorted:check(piecewise_faces>0,"actual GPU piecewise branch exercised")
		evidence.append({"distorted":distorted,"corners":expected.size(),"group_corners":group_corners,"piecewise_faces":piecewise_faces,"max_raw_error":max_raw,"max_source_pixel_error":max_pixel,"samples":samples})
		for instance in nodes:instance.queue_free()
		await process_frame
	FileAccess.open(output.path_join("gpu-positions.json"),FileAccess.WRITE).store_string(JSON.stringify(evidence,"  "))
	target.queue_free()

func finish() -> void:
	for failure in failures:printerr("FAIL: "+failure)
	if not _native_phase.is_empty():print("PC_TACTICAL_NATIVE_PHASE: %s; %d checks, %d errors"%[_native_phase,checks,failures.size()])
	print("PC_TACTICAL_VEHICLES: %d checks, %d errors"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
