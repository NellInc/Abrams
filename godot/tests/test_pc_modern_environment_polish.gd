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

func model_packet(catalog:Dictionary,shape:int,terrain_tilt:float=-0.6,facing:float=0.4,pitch:float=0.0) -> Dictionary:
	var model:Dictionary=catalog.models[shape]
	var data:=packet();data.objects=[];data.background={"kind":"solid","color":0}
	var object:={"shape_index":shape,"root":int(model.roots[0].offset),"static_path":true,"dynamic_instance":false,"polygons":[],"world_delta":[1200,2400,0]}
	var center:Vector3=(Modern.vec(model.source_bounds.min)+Modern.vec(model.source_bounds.max))*0.5
	var dim:Vector3=Modern.vec(model.source_bounds.max)-Modern.vec(model.source_bounds.min)
	var depth:=maxf(160.0,maxf(dim.x,maxf(dim.y,dim.z))*1.7)
	var rotation:=Basis(Vector3.RIGHT,terrain_tilt) if shape in [40,49] else Basis(Vector3(0,0,1),facing)
	if pitch!=0.0: rotation=Basis(Vector3.RIGHT,pitch)*rotation
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

func tactical_materials(catalog: Dictionary, baseline_path: String) -> void:
	# Reuse production mapping and ownership with source faces repositioned for
	# close inspection. These are material studies, not captured mission frames.
	var old := Shader.new()
	old.code=FileAccess.get_file_as_string(baseline_path).replace("depth_test_disabled, depth_draw_never", "depth_draw_opaque").replace("void fragment() {", "void fragment() {\n DEPTH = UV.y > 19.5 && UV.y < 21.5 ? FRAGCOORD.z : 0.0;\n if (UV.y > 20.04 && UV.y < 20.08) DEPTH = 0.5 + min(UV2.x,1024.0)/4096.0;")
	var finish: bool="--surface-finish" in OS.get_cmdline_user_args()
	var canopy: bool="--canopy-finish" in OS.get_cmdline_user_args()
	var terrain: bool="--terrain-finish" in OS.get_cmdline_user_args()
	var slopes: bool="--slope-finish" in OS.get_cmdline_user_args()
	var glazing: bool="--glazing-finish" in OS.get_cmdline_user_args()
	var equipment: bool="--equipment-finish" in OS.get_cmdline_user_args()
	var architecture: bool="--architecture-finish" in OS.get_cmdline_user_args()
	var textures:bool="--material-textures" in OS.get_cmdline_user_args()
	var realism:bool="--realism-materials" in OS.get_cmdline_user_args()
	var paired:bool=architecture or textures or realism
	var previous_assets: RefCounted
	if architecture:architecture_contract()
	if textures:texture_contract()
	if realism:realism_contract()
	if paired:
		var baseline_args:=OS.get_cmdline_user_args()
		previous_assets=load(baseline_args[baseline_args.find("--architecture-before")+1]).new()
		check(previous_assets.load_assets(directory),"previous architectural renderer available")
	if glazing: glazing_contract()
	if equipment: equipment_contract()
	var specs: Array=[[2,"grass-hill",true],[4,"earth-hill",true],[40,"river",true],[49,"road",true],[115,"t62",true],[129,"m113",true],[147,"building",true],[157,"farm",true],[159,"truck",true],[163,"hind",true],[103,"tree",false],[161,"crew",false]]
	if canopy: specs.append_array([[103,"tree-distant",true],[103,"tree-cool",true],[103,"tree-warm",true],[-1,"horizon",true]])
	if slopes: specs.append_array([[8,"earth-vertical",true],[6,"grass-slope",true],[2,"grass-distant",true],[4,"earth-distant",true]])
	if terrain: specs.append_array([[40,"river-distant",true],[49,"road-distant",true],[40,"river-grazing",true]])
	if glazing: specs.append_array([[159,"truck-front",true],[163,"hind-oblique",true],[147,"building-distant",true],[156,"wreck-building",false]])
	if equipment: specs.append_array([[115,"t62-roof",true],[129,"m113-roof",true],[159,"truck-front",true],[159,"truck-distant",true],[156,"wreck-building",false]])
	if paired: specs.append_array([[145,"command-building",true],[149,"long-building",true],[151,"pitched-building",true],[153,"soviet-building",true],[155,"us-building",true],[156,"wreck-building",false],[147,"building-distant",true],[147,"building-oblique",true]])
	if textures:specs.append_array([[115,"t62-roof",true],[129,"m113-roof",true],[159,"truck-front",true],[163,"hind-oblique",true],[115,"t62-distant",true]])
	if realism:specs.append_array([[0,"bridge",true],[47,"hangar",true],[116,"wreck-tank",true],[146,"ruins",true],[2,"grass-close",true],[4,"soil-close",true],[40,"water-close",true],[49,"road-close",true],[0,"bridge-close",true],[47,"hangar-close",true],[153,"soviet-close",true],[156,"flag-building-close",true]])
	for spec in specs:
		var tilt: float=-0.16 if spec[1]=="river-grazing" else -0.6
		var facing:float=PI-0.4 if (glazing or equipment or paired) and spec[1] in ["truck-front","hind-oblique","building-oblique"] else 0.4
		var pitch:float=0.65 if (equipment or textures) and str(spec[1]).ends_with("-roof") else 0.0
		if realism and spec[1]=="bridge-close":pitch=0.85
		var data:=model_packet(catalog,int(spec[0]),tilt,facing,pitch) if int(spec[0])>=0 else packet()
		if realism and str(spec[1]).ends_with("-close"):
			# Full-object studies can legitimately filter microscopic detail away.
			# Translate the original camera points for a near-face inspection.
			var nearest:float=INF
			for polygon:Dictionary in data.objects[0].polygons:
				for point:Array in polygon.camera_vertices:nearest=minf(nearest,float(point[1]))
			for polygon:Dictionary in data.objects[0].polygons:
				for point:Array in polygon.camera_vertices:point[1]-=nearest-420.0
		if (terrain or slopes or glazing or equipment or paired) and str(spec[1]).ends_with("-distant"):
			for polygon: Dictionary in data.objects[0].polygons:
				for point: Array in polygon.camera_vertices: point[1]+=1800.0
		if canopy:
			if spec[1]=="tree-distant":
				for polygon: Dictionary in data.objects[0].polygons:
					for point: Array in polygon.camera_vertices: point[1]+=3000.0
			if spec[1] in ["tree-cool","tree-warm"]: data.objects[0].world_delta=[0 if spec[1]=="tree-cool" else 8,0,0]
			if spec[1]=="horizon":
				data.camera.world_position_raw=[0,0,50]
				data.background={"kind":"horizon","line":[[0,100],[319,100]],"colors":[5,8]}
				data.objects[0].shape_index=-1
				data.objects[0].polygons[0].colors=[9,9]
				data.objects[0].polygons[0].camera_vertices=[[-15,160,25],[15,160,25],[15,160,45],[-15,160,45]]
		var running_gear: bool=(finish or canopy or terrain or slopes or glazing or equipment or textures) and int(spec[0]) in [115,129]
		if running_gear:
			# Explicit source-matched dynamic metadata enables the production
			# wheel/track coordinates. Static studies never imply motion.
			data.objects[0].dynamic_instance=true
			data.objects[0].static_path=false
			data.objects[0].pointer=99
			data.world={"dynamic":[{"pointer":99,"shape_index":int(spec[0]),"world_position_raw":[0,0,0]}]}
		for index in [17,19,26,28]:data.materials[index]={17:[0x0700,0x0007],19:[0x0800,0x0008],26:[0x0703,0x0307],28:[0x0803,0x0308]}[index]
		data=JSON.parse_string(JSON.stringify(data))
		var source:=JSON.stringify(data)
		draw.tactical_landscape=false
		var modern:=await render(data,true)
		if running_gear: check(draw.modern_running_gear_triangles>0,str(spec[1])+": actual running-gear material required")
		var material:ShaderMaterial=draw.mesh_node.mesh.surface_get_material(0)
		var current:Shader=material.shader
		var geometry:PackedVector3Array=draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
		var before: Image
		var baseline_plain: Image
		if paired:
			# Compare actual previous models and shader, not new material tags
			# interpreted by an old shader. Positions and ownership stay equal.
			var current_assets: RefCounted=draw.modern_assets
			draw.modern_assets=previous_assets
			await render(data,true)
			var prior_material: ShaderMaterial=draw.mesh_node.mesh.surface_get_material(0)
			prior_material.shader=old
			check((await capture()).get_data()==modern.get_data(),str(spec[1])+": previous Modernized renderer exact")
			draw.tactical_landscape=true
			before=await capture()
			prior_material.set_shader_parameter("modern_surface_variation",false)
			baseline_plain=await capture()
			draw.modern_assets=current_assets
			await render(data,true)
			material=draw.mesh_node.mesh.surface_get_material(0)
			current=material.shader
		else:
			material.shader=old
			check((await capture()).get_data()==modern.get_data(),str(spec[1])+": Modernized pixel identity")
			draw.tactical_landscape=true
			before=await capture()
			material.shader=current
		var after:=await capture()
		var changed:=0;var escaped:=0;var visible_pixels:=0
		for y in after.get_height():
			for x in after.get_width():
				var a:=before.get_pixel(x,y);var b:=after.get_pixel(x,y)
				if a!=Color.BLACK:visible_pixels+=1
				if a!=b:
					changed+=1
					if a==Color.BLACK or b==Color.BLACK:escaped+=1
		var expected: bool=int(spec[0]) in [115,129,147,157] if finish else bool(spec[2])
		if canopy: expected=int(spec[0]) in [103,-1]
		if terrain: expected=int(spec[0]) in [40,49]
		if slopes: expected=int(spec[0]) in [2,4,6,8]
		if glazing: expected=int(spec[0]) in Modern.GLAZING_SHAPES
		if equipment: expected=int(spec[0]) in [159,163] or str(spec[1]).ends_with("-roof")
		if architecture: expected=int(spec[0]) in Modern.ARCHITECTURE_SHAPES
		if textures:expected=int(spec[0]) in Modern.ARCHITECTURE_SHAPES+[115,129,159,163]
		if realism:expected=str(spec[1]) not in ["grass-hill","earth-hill","road","bridge","t62-distant"]
		check((changed>0 if realism and str(spec[1]) in ["soviet-building","wreck-building","hangar"] else changed>100) if expected else changed==0,str(spec[1])+": expected Tactical-only material scope")
		check(visible_pixels>100,str(spec[1])+": study must actually show the surface")
		check(escaped==0,str(spec[1])+": unchanged coverage")
		check((await capture()).get_data()==after.get_data(),str(spec[1])+": stable between source frames")
		check(geometry==draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],str(spec[1])+": unchanged geometry")
		check(source==JSON.stringify(data),str(spec[1])+": unchanged source packet")
		if (glazing or equipment or paired) and expected:
			# Retain the production shader's source/depth coverage, replacing
			# only its final colour with an exact semantic glazing mask.
			var mask_shader:=Shader.new()
			var end:int=current.code.rfind("}")
			var condition:String="family>0.5" if realism else "material_finish>0.5" if textures else "architecture_finish>0.5" if architecture else "UV.y>19.55 && UV.y<19.95" if equipment else "UV.y>20.006 && UV.y<20.010"
			mask_shader.code=current.code.substr(0,end)+"\n ALBEDO = "+condition+" ? vec3(1.0) : vec3(0.0);\n}\n"
			material.shader=mask_shader
			var mask:=await capture()
			material.shader=current
			var outside:=0;var pane_pixels:=0
			for y in after.get_height():
				for x in after.get_width():
					if mask.get_pixel(x,y)==Color.WHITE:pane_pixels+=1
					elif before.get_pixel(x,y)!=after.get_pixel(x,y):outside+=1
			check(pane_pixels>100,str(spec[1])+": visible tagged material required")
			check(outside==0,str(spec[1])+": all untagged surfaces unchanged")
		if (finish or canopy or terrain or slopes or glazing or equipment or paired) and expected:
			material.set_shader_parameter("modern_surface_variation",false)
			var plain:=await capture()
			if paired:
				check(baseline_plain.get_data()==plain.get_data(),str(spec[1])+": detail-off retains previous renderer")
			else:
				material.shader=old
				check((await capture()).get_data()==plain.get_data(),str(spec[1])+": detail-off retains baseline materials")
				material.shader=current
			material.set_shader_parameter("modern_surface_variation",true)
		if realism and spec[1]=="crew":await crew_owner_contract(modern,after)
		if textures and expected:
			material.set_shader_parameter("tactical_realism_ready" if realism else "tactical_material_ready",false)
			check((await capture()).get_data()==before.get_data(),str(spec[1])+": missing detail textures retain prior Tactical material")
			material.set_shader_parameter("tactical_realism_ready" if realism else "tactical_material_ready",true)
			check((await capture()).get_data()==after.get_data(),str(spec[1])+": texture restore exact")
		if (terrain or slopes) and expected:
			var origin:Vector3=material.get_shader_parameter("world_origin")
			material.set_shader_parameter("world_origin",origin+Vector3(571,347,0))
			check((await capture()).get_data()!=after.get_data(),str(spec[1])+": material follows world coordinates")
			material.set_shader_parameter("world_origin",origin)
			check((await capture()).get_data()==after.get_data(),str(spec[1])+": world-origin restore exact")
		if ((paired and int(spec[0]) in Modern.ARCHITECTURE_SHAPES) or int(spec[0]) in [103,115,129,147,159,163,-1]) and not (realism and int(spec[0])==157):
			var origin:Vector3=material.get_shader_parameter("world_origin")
			material.set_shader_parameter("world_origin",origin+Vector3(10000,-12000,800))
			var rebased:=await capture()
			# Horizon vegetation is angular; ground detail is world-anchored and
			# legitimately changes if only the world-origin uniform is replaced.
			var region:=Rect2i(0,0,1280,400) if int(spec[0])==-1 else Rect2i(Vector2i.ZERO,after.get_size())
			check(rebased.get_region(region).get_data()==after.get_region(region).get_data(),str(spec[1])+": rebasing cannot slide material detail")
			material.set_shader_parameter("world_origin",origin)
		if canopy and spec[1]=="horizon":
			# The declared horizon band is elevation < 0.14: at focal length
			# 192 and 4x output its upper boundary is (100-0.14*192)*4=292.48.
			for area in [Rect2i(0,0,1280,292),Rect2i(0,400,1280,400)]:
				check(before.get_region(area).get_data()==after.get_region(area).get_data(),"horizon: upper sky, source actor and ground unchanged")
		before.save_png(output.path_join(str(spec[1])+"-before.png"))
		after.save_png(output.path_join(str(spec[1])+"-after.png"))
		draw.tactical_landscape=false
		check((await capture()).get_data()==modern.get_data(),str(spec[1])+": exact Modernized switchback")
		rows.append({"case":spec[1],"changed_pixels":changed,"coverage_changes":escaped})
	var rejected:=model_packet(catalog,115)
	rejected.palette_rgb[5]=[12,13,14]
	var fallback:=await render(rejected,true)
	draw.tactical_landscape=true
	check((await capture()).get_data()==fallback.get_data(),"unsupported sensor palette retains source rendering")
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":failures,"cases":rows},"  "))
	for failure in failures:printerr("FAIL: "+failure)
	print("PC_TACTICAL_MATERIALS: %d checks, %d errors"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func texture_contract() -> void:
	var optional:=Modern.new()
	check(not optional.load_material_textures("user://missing-textures") and optional.material_textures.is_empty(),"missing textures fail closed without partial material set")
	check(optional.load_material_textures(directory),"pinned material PNGs load")
	for name in Modern.MATERIAL_TEXTURES:
		var texture:Texture2D=optional.material_textures[name]
		check(texture.get_size()==Vector2(512,512),"bounded material texture GPU dimensions")
		check(texture.get_image().has_mipmaps(),"material texture mipmaps present")
	var corrupt:="user://material-texture-corrupt"
	DirAccess.make_dir_recursive_absolute(corrupt.path_join("local-art/pc-tactical-materials-v1"))
	for name in Modern.MATERIAL_TEXTURES:
		var raw:=FileAccess.get_file_as_bytes(directory.path_join("local-art/pc-tactical-materials-v1/"+str(name)+".png"))
		if name=="stone":raw[20]=raw[20]^1
		FileAccess.open(corrupt.path_join("local-art/pc-tactical-materials-v1/"+str(name)+".png"),FileAccess.WRITE).store_buffer(raw)
	check(not optional.load_material_textures(corrupt) and optional.material_textures.is_empty(),"corrupt or partial set cannot keep stale textures")
	for spec in [[115,"olive","panel",20.0,Modern.TEXTURE_PAINT],[115,"signal_red","panel",20.0,20.0],[115,"vent","barrel_bore",20.0,20.0],[159,"canvas","panel",Modern.EQUIPMENT_CANVAS,Modern.EQUIPMENT_CANVAS],[145,"plaster","panel",20.375,Modern.TEXTURE_PLASTER],[145,"plaster","bevel",20.375,20.375],[156,"plaster","panel",20.375,20.375],[47,"plaster","panel",20.375,20.375],[115,"glass","panel",20.0,20.0]]:
		var kind:=Modern.material_detail_kind(int(spec[0]),str(spec[1]),str(spec[2]),float(spec[3]))
		check(kind==float(spec[4]),"texture requires exact authored material admission")
		check(Modern.architecture_base_kind(kind)==float(spec[3]),"texture tag preserves incumbent dispatch")

func crew_owner_contract(modern:Image,tactical:Image) -> void:
	var original_mesh:ArrayMesh=draw.mesh_node.mesh
	var original_material:ShaderMaterial=original_mesh.surface_get_material(0)
	var old_owner:Texture2D=original_material.get_shader_parameter("source_ownership")
	for offset in [512,4096,32768]:
		var arrays:Array=original_mesh.surface_get_arrays(0)
		var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV].duplicate()
		for i in uv.size():
			if floorf(uv[i].y/32.0)>0.5:uv[i].y+=float(offset)*32.0
		arrays[Mesh.ARRAY_TEX_UV]=uv
		var owner:Image=old_owner.get_image()
		for y in owner.get_height():
			for x in owner.get_width():
				var pixel:Color=owner.get_pixel(x,y)
				var id:int=roundi(pixel.r*255.0)+roundi(pixel.g*255.0)*256
				if id>0:
					id+=offset
					owner.set_pixel(x,y,Color(float(id%256)/255.0,float(id/256)/255.0,pixel.b,pixel.a))
		var material:ShaderMaterial=original_material.duplicate()
		material.set_shader_parameter("source_ownership",ImageTexture.create_from_image(owner))
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.surface_set_material(0,material)
		draw.mesh_node.mesh=mesh
		material.set_shader_parameter("tactical_landscape",false)
		if offset<32768:check((await capture()).get_data()==modern.get_data(),"crew owner %d: Modernized bytes unchanged"%offset)
		else:
			# Incumbent kind20.0625 itself loses precision here. Compare with
			# canonical old painter inputs, exposing rather than repairing it.
			var incumbent:Array=arrays.duplicate(true)
			var old_uv:PackedVector2Array=incumbent[Mesh.ARRAY_TEX_UV2].duplicate()
			for i in old_uv.size():
				if fposmod(uv[i].y,32.0)==20.0:old_uv[i]=Vector2(floorf(old_uv[i].x),0)
			incumbent[Mesh.ARRAY_TEX_UV2]=old_uv
			var reference:=ArrayMesh.new();reference.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,incumbent);reference.surface_set_material(0,material)
			var actual:=await capture();draw.mesh_node.mesh=reference
			check((await capture()).get_data()==actual.get_data(),"crew owner32768: retains incumbent precision limit")
			draw.mesh_node.mesh=mesh
		material.set_shader_parameter("tactical_landscape",true)
		if offset<32768:check((await capture()).get_data()==tactical.get_data(),"crew owner %d: texture family and painter order unchanged"%offset)
	draw.mesh_node.mesh=original_mesh

func realism_contract() -> void:
	check(art.material_atlas!=null,"complete realism atlas loaded")
	check(art.material_atlas.get_size()==Vector2(1152,1152),"bounded padded atlas dimensions")
	check(art.material_atlas.get_image().has_mipmaps(),"realism atlas mipmaps")
	check(Modern.REALISM_ORDER.size()==13,"thirteen material tiles")
	for legacy in [20.0,20.375,20.4375,20.46875]:
		for name in ["steel","plaster","stone_edge","timber","canvas","tyre","roof","grass","tree_crown","earth","road","water","glass","skin"]:
			var kind:float=Modern.realism_kind(name,legacy)
			check(kind>=24.0 && kind<28.0,"explicit authored family admitted")
			check(Modern.architecture_base_kind(kind)==legacy,"realism tag restores exact legacy branch")
	check(Modern.realism_kind("unknown",20.0)==20.0,"unknown surfaces unchanged")
	check(Modern.realism_kind("ruin_void",20.0)==20.0,"void remains void")
	var optional:=Modern.new()
	check(optional.load_material_textures(directory),"preceding textures available independently")
	check(not optional.load_realism_atlas("user://missing-realism"),"missing extended set rejects atlas")
	check(optional.material_atlas==null && optional.material_textures.size()==3,"extended failure retains preceding Tactical textures")
	check(optional.load_realism_atlas(directory),"extended texture restore")
	var before_io:int=art.disk_io_count
	for n in 4:
		draw.tactical_landscape=not draw.tactical_landscape
	check(art.disk_io_count==before_io,"Tactical switches never reload textures")
	draw.tactical_landscape=false

func architecture_contract() -> void:
	for spec in [[145,"door","door",20.0,Modern.ARCH_DOOR],
		[157,"timber","panel",20.375,Modern.ARCH_TIMBER],
		[147,"stone_edge","window_0",20.375,Modern.ARCH_STONE_WALL],
		[147,"stone_edge","window_3",20.4375,Modern.ARCH_STONE_TOP],
		[151,"stone_edge","plinth",20.375,Modern.ARCH_BASE_WALL],
		[151,"stone_edge","plinth_right",20.4375,Modern.ARCH_BASE_TOP],
		[156,"door","door",20.0,20.0],[159,"door","door",20.0,20.0],
		[47,"door","panel",20.0,20.0],[147,"timber","panel",20.375,20.375],
		[157,"plaster","panel",20.375,20.375],
		[147,"stone_edge","window_unknown",20.375,20.375],
		[147,"stone_edge","bevel",20.375,20.375],
		[147,"stone_edge","eave",20.4375,20.4375],
		[147,"stone_edge","window_0",20.46875,20.46875]]:
		var kind:=Modern.architecture_kind(int(spec[0]),str(spec[1]),str(spec[2]),float(spec[3]))
		check(kind==float(spec[4]),"architecture requires explicit shape/material/component/base-kind")
		check(Modern.architecture_base_kind(kind)==float(spec[3]),"architecture tags preserve incumbent material dispatch")

func equipment_contract() -> void:
	for spec in [[115,"vent","engine_louvre_0",Modern.EQUIPMENT_VENT],
		[115,"vent","barrel_bore",20.0],[115,"olive","engine_louvre_0",20.0],
		[115,"vent","unknown",20.0],[147,"vent","engine_louvre_0",20.0],
		[159,"vent","truck_grille_0",Modern.EQUIPMENT_VENT],
		[163,"vent","engine_side_vent",Modern.EQUIPMENT_VENT],
		[159,"canvas","panel",Modern.EQUIPMENT_CANVAS],
		[159,"canvas_edge","bevel",Modern.EQUIPMENT_CANVAS],
		[115,"canvas","panel",20.0],[159,"tyre","bevel",Modern.EQUIPMENT_RUBBER],
		[141,"tyre","bevel",Modern.EQUIPMENT_RUBBER],[115,"tyre","bevel",20.0]]:
		var source:=fixture()
		source.models[0].shape_index=int(spec[0])
		source.models[0].triangles[0].material=str(spec[1])
		source.models[0].triangles[0].component=str(spec[2])
		var before:=JSON.stringify(source)
		var model:=Modern.new()
		check(model.configure(source),"equipment fixture accepted")
		check(model.models[int(spec[0])].faces[10].triangles[0].structure_kind==float(spec[3]),"equipment requires explicit shape/material/component identity")
		check(JSON.stringify(source)==before,"equipment classification never mutates catalogue")
		var data:=packet();data.objects[0].shape_index=int(spec[0])
		var facets:=model.mapping(data.objects[0],data.objects[0].polygons[0],data.camera,data.palette_rgb,false)
		check(not facets.is_empty(),"equipment mapping retains source coverage")
		var wanted:bool=float(spec[3])!=20.0
		for facet:Dictionary in facets:
			for point:Array in facet.points:
				check(point.size()==(5 if wanted else 3),"equipment adds only local material coordinates")

func anisotropic_footprint_contract() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(16,16)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var face:=ColorRect.new();face.size=Vector2(16,16);viewport.add_child(face)
	var material:=ShaderMaterial.new();face.material=material
	# GPU checks for the observed grazing-road fade, including rotated/sheared
	# footprints. Hardware mip filtering and gradients remain unchanged.
	var cases:Array=[
		[Vector2.ZERO,Vector2.ZERO,11.0,0.0],
		[Vector2(32,0),Vector2(0,1),11.0,2.0],
		[Vector2(32,0).rotated(0.7),Vector2(0,1).rotated(0.7),11.0,2.0],
		[(Vector2(32,0)+Vector2(0,1))/sqrt(2.0),(Vector2(32,0)-Vector2(0,1))/sqrt(2.0),11.0,2.0],
		[Vector2(8,0),Vector2(0,8),11.0,8.0],
		[Vector2(512,0),Vector2(0,0.5),11.0,32.0],
		[Vector2(32,0),Vector2(0,1),8.0,2.0],
		[Vector2(32,0),Vector2(0,1),10.0,2.0],
		[Vector2(32,0),Vector2(0,1),9.0,32.0],
		[Vector2(32,0),Vector2(0,1),5.0,32.0]]
	for row:Array in cases:
		var shader:=Shader.new()
		shader.code="shader_type canvas_item; render_mode unshaded;\n#include \"res://scripts/pc_tactical_materials.gdshaderinc\"\nvoid fragment(){COLOR=vec4(vec3(realism_footprint(vec2(%f,%f)/512.0,vec2(%f,%f)/512.0,%f)/64.0),1.0);}"%[row[0].x,row[0].y,row[1].x,row[1].y,row[2]]
		material.shader=shader
		check(absf((await capture()).get_pixel(8,8).r-float(row[3])/64.0)<0.005,"anisotropic footprint GPU case %d"%checks)
	if "--naturalism-gpu" in OS.get_cmdline_user_args():
		for point:Vector2 in [Vector2.ZERO,Vector2(7,-3),Vector2(1024,-512),Vector2(-81,214)]:
			var phase:=Vector2(point.dot(Vector2(0.41,0.19)),point.dot(Vector2(-0.17,0.37)))
			var delta:=Vector2(sin(phase.x),sin(phase.y))*0.22
			var dx:=Vector2(0.7,-0.3);var dy:=Vector2(-0.2,0.8)
			var rate:=Vector2(cos(phase.x),cos(phase.y))*0.22
			var gx:=dx+rate*Vector2(dx.dot(Vector2(0.41,0.19)),dx.dot(Vector2(-0.17,0.37)))
			var gy:=dy+rate*Vector2(dy.dot(Vector2(0.41,0.19)),dy.dot(Vector2(-0.17,0.37)))
			var shader:=Shader.new()
			var setup:="vec2 uv=vec2(%f,%f);vec2 origin=uv;vec2 dx=vec2(0.7,-0.3);vec2 dy=vec2(-0.2,0.8);realism_ground_coordinates(uv,dx,dy);"%[point.x,point.y]
			var prefix:="shader_type canvas_item; render_mode unshaded;\n#include \"res://scripts/pc_tactical_materials.gdshaderinc\"\nvoid fragment(){"+setup
			shader.code=prefix+"COLOR=vec4((uv-origin)*0.5+0.5,0.0,1.0);}"
			material.shader=shader
			var colour:=(await capture()).get_pixel(8,8)
			check(Vector2(colour.r,colour.g).distance_to(delta*0.5+Vector2.ONE*0.5)<0.005,"terrain variation remains continuous and source-coordinate anchored")
			for gradient:Array in [["dx",gx],["dy",gy]]:
				shader=Shader.new();shader.code=prefix+"COLOR=vec4("+str(gradient[0])+"*0.25+0.5,0.0,1.0);}"
				material.shader=shader
				colour=(await capture()).get_pixel(8,8)
				check(Vector2(colour.r,colour.g).distance_to(gradient[1]*0.25+Vector2.ONE*0.5)<0.005,"terrain textureGrad carries the exact warp Jacobian")
		var responses:=[Vector2(0.70,0.65),Vector2(0.62,0.55),Vector2(0.85,1.0),Vector2(0.72,0.70),Vector2(0.45,0.40),Vector2(0.38,0.35),Vector2(0.70,0.75),Vector2(0.55,0.45),Vector2(0.58,0.40),Vector2(0.66,0.65),Vector2(0.58,0.50),Vector2(0.38,1.0),Vector2(0.18,0.15),Vector2(0.06,0.15)]
		for i in responses.size():
			var shader:=Shader.new()
			shader.code="shader_type canvas_item; render_mode unshaded;\n#include \"res://scripts/pc_tactical_materials.gdshaderinc\"\nvoid fragment(){COLOR=vec4(realism_response(%f),0.0,1.0);}"%float(i+1)
			material.shader=shader
			var colour:=(await capture()).get_pixel(8,8)
			check(Vector2(colour.r,colour.g).distance_to(responses[i])<0.005,"material-specific contrast and relief family %d"%(i+1))
	for failure:String in failures:printerr("FAIL: "+failure)
	print(("PC_TACTICAL_NATURALISM_GPU" if "--naturalism-gpu" in OS.get_cmdline_user_args() else "PC_ANISOTROPIC_FOOTPRINT")+": %d checks, %d errors"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func finishgrain_expected(uv:Vector2,family:int) -> Dictionary:
	var profiles:Dictionary={1:Vector2(0.035,0.025),2:Vector2(0.150,0.100),3:Vector2(0.100,0.080),4:Vector2(0.035,0.055),5:Vector2(0.018,0.018),6:Vector2(0.025,0.020),7:Vector2(0.045,0.028)}
	var amplitude:Vector2=profiles.get(family,Vector2.ZERO)
	var u:=Vector2(0.47,0.21);var v:=Vector2(-0.19,0.43)
	var phase:=Vector2(uv.dot(u),uv.dot(v))
	var rate:=amplitude*Vector2(cos(phase.x),cos(phase.y))
	var x:=Vector2(1.0+rate.x*u.x,rate.y*v.x);var y:=Vector2(rate.x*u.y,1.0+rate.y*v.y)
	var dx:=x*0.031-y*0.017;var dy:=-x*0.011+y*0.043
	var slope:=Vector2(0.24,-0.17)
	return {"amplitude":amplitude,"delta":amplitude*Vector2(sin(phase.x),sin(phase.y)),"determinant":x.x*y.y-x.y*y.x,"gradient":Vector2(x.dot(slope),y.dot(slope)),"dx":dx,"dy":dy}

func finishgrain_gpu_contract() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(16,16)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var face:=ColorRect.new();face.size=Vector2(16,16);viewport.add_child(face)
	var material:=ShaderMaterial.new();face.material=material
	var prefix:="shader_type canvas_item; render_mode unshaded;\nvec3 realism_sample(vec2 uv,vec2 dx,vec2 dy,float family,float distance){return vec3(1.0,0.24,-0.17);}\n"+FileAccess.get_file_as_string("res://scripts/pc_tactical_finishgrain.gdshaderinc")
	var cases:Array=[]
	for family:int in range(15):
		var profile:Vector2=finishgrain_expected(Vector2.ZERO,family).amplitude
		cases.append(["COLOR=vec4(vec3(tactical_finish_grain_profile(%f),0.0),1.0);"%float(family),Vector3(profile.x,profile.y,0),"seven grain profiles and exact protected families"])
	for family:int in [1,2,3,4,5,6,7,0,8,9,10,11,12,13,14]:
		var positions:Array=[Vector2(-5.1,3.7),Vector2.ZERO,Vector2(0.5,0.5),Vector2(14.4,-9.8)] if family>0 and family<8 else [Vector2(-5.1,3.7)]
		for uv:Vector2 in positions:
			var cpu:=finishgrain_expected(uv,family)
			var pre:="vec2 origin=vec2(%f,%f);vec2 uv=origin,dx=vec2(0.031,-0.017),dy=vec2(-0.011,0.043);mat2 j=tactical_finish_grain_coordinates(uv,dx,dy,%f);"%[uv.x,uv.y,float(family)]
			var delta:Vector2=cpu.delta*2.0+Vector2.ONE*0.5
			cases.append([pre+"COLOR=vec4(vec3((uv-origin)*2.0+vec2(0.5),determinant(j)/1.2),1.0);",Vector3(delta.x,delta.y,cpu.determinant/1.2),"continuous placement and positive determinant"])
			var slope:Vector2=cpu.gradient*0.8+Vector2.ONE*0.5
			cases.append([pre+"vec3 sampled=tactical_finish_grain_sample(origin,vec2(0.031,-0.017),vec2(-0.011,0.043),%f,420.0);COLOR=vec4(vec3(sampled.yz*0.8+vec2(0.5),(dx.x+dy.y)*2.0+0.5),1.0);"%float(family),Vector3(slope.x,slope.y,(cpu.dx.x+cpu.dy.y)*2.0+0.5),"exact transformed derivatives and pulled-back relief"])
	for row:Array in cases:
		var shader:=Shader.new();shader.code=prefix+"void fragment(){"+str(row[0])+"}"
		material.shader=shader
		var colour:Color=(await capture()).get_pixel(8,8)
		check(Vector3(colour.r,colour.g,colour.b).distance_to(row[1])<0.007,str(row[2]))
	for failure:String in failures:printerr("FAIL: "+failure)
	print("PC_TACTICAL_FINISHGRAIN_GPU: %d checks, %d errors"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func diffusion_expected(normal:Vector3,eye:Vector3,family:float,gain:float,distance:float,pixel:float) -> float:
	var profiles:Dictionary={1:Vector3(0.12,0.18,0.035),2:Vector3(0.44,0.24,0.065),3:Vector3(0.65,0.28,0.080),4:Vector3(0.32,0.22,0.045),5:Vector3(0.40,0.20,0.035),6:Vector3(0.22,0.17,0.045),7:Vector3(0.35,0.23,0.055),8:Vector3(0.26,0.18,0.025),10:Vector3(0.56,0.26,0.055),11:Vector3(0.18,0.18,0.040)}
	var profile:Vector3=profiles.get(roundi(family),Vector3.ZERO)
	if profile==Vector3.ZERO or normal.length_squared()<0.00000001 or eye.length_squared()<0.00000001:return 1.0
	var n:=normal.normalized();var v:=eye.normalized();var sun:=Vector3(-0.58,0.34,0.74).normalized()
	var nl:float=clampf(n.dot(sun),0,1);var nv:float=clampf(n.dot(v),0,1)
	var sl:float=sqrt(maxf(1-nl*nl,0));var sv:float=sqrt(maxf(1-nv*nv,0));var azimuth:=0.0
	if sl>0.0001 and sv>0.0001:azimuth=clampf((sun.dot(v)-nl*nv)/(sl*sv),0,1)
	var a:float=1.0-0.5*profile.x/(profile.x+0.33);var b:float=0.45*profile.x/(profile.x+0.09)
	var rough:float=nl*(a+b*azimuth*maxf(sl,sv)*minf(sl,sv)/maxf(maxf(nl,nv),0.05))
	var cavity:float=clampf((1-gain)/0.18,0,1)*profile.z
	var ratio:float=clampf(1+(rough-nl)*profile.y-cavity,0.88,1.065)
	var resolved:float=1.0/(1+pow(maxf(distance,0)/16000,2)+pow(maxf(pixel,0)*8,2))
	return lerpf(1,ratio,resolved)

func diffusion_gpu_contract() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(16,16)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var face:=ColorRect.new();face.size=Vector2(16,16);viewport.add_child(face)
	var material:=ShaderMaterial.new();face.material=material
	var prefix:="shader_type canvas_item; render_mode unshaded;\n"+FileAccess.get_file_as_string("res://scripts/pc_tactical_diffusion.gdshaderinc")
	var cases:Array=[]
	var profiles:Dictionary={1:Vector3(0.12,0.18,0.035),2:Vector3(0.44,0.24,0.065),3:Vector3(0.65,0.28,0.080),4:Vector3(0.32,0.22,0.045),5:Vector3(0.40,0.20,0.035),6:Vector3(0.22,0.17,0.045),7:Vector3(0.35,0.23,0.055),8:Vector3(0.26,0.18,0.025),10:Vector3(0.56,0.26,0.055),11:Vector3(0.18,0.18,0.040)}
	for family:int in [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14]:
		cases.append(["tactical_rough_profile(%f)"%float(family),profiles.get(family,Vector3.ZERO),"family-specific roughness and exact excluded materials"])
	var sun:=Vector3(-0.58,0.34,0.74).normalized()
	for family:int in profiles:
		for pose:Array in [[Vector3.BACK,Vector3.BACK],[sun,sun],[Vector3(1,0,0.02).normalized(),Vector3(1,0,0.02).normalized()],[-sun,Vector3.BACK]]:
			for gain:float in [0.82,1.12]:
				var n:Vector3=pose[0];var eye:Vector3=pose[1]
				cases.append(["vec3(tactical_rough_gain(vec3(%f,%f,%f),vec3(%f,%f,%f),%f,%f,420.0,0.01)/1.1)"%[n.x,n.y,n.z,eye.x,eye.y,eye.z,float(family),gain],Vector3.ONE*diffusion_expected(n,eye,float(family),gain,420,0.01)/1.1,"bounded rough diffuse, cavities and grazing stability"])
	for row:Array in [[Vector3.ZERO,Vector3.BACK,3.0,0.82,420.0,0.01],[Vector3.BACK,Vector3.ZERO,3.0,0.82,420.0,0.01],[Vector3.BACK,Vector3.BACK,3.0,0.82,64000.0,0.01],[Vector3.BACK,Vector3.BACK,3.0,0.82,420.0,2.0],[Vector3.BACK,Vector3.BACK,3.0,1.0,-10.0,-1.0],[Vector3.BACK,Vector3.BACK,13.0,0.82,420.0,0.01]]:
		var n:Vector3=row[0];var eye:Vector3=row[1]
		cases.append(["vec3(tactical_rough_gain(vec3(%f,%f,%f),vec3(%f,%f,%f),%f,%f,%f,%f)/1.1)"%[n.x,n.y,n.z,eye.x,eye.y,eye.z,row[2],row[3],row[4],row[5]],Vector3.ONE*diffusion_expected(n,eye,row[2],row[3],row[4],row[5])/1.1,"degenerate/excluded states and smooth distance/pixel convergence"])
	for row:Array in cases:
		var shader:=Shader.new();shader.code=prefix+"void fragment(){COLOR=vec4("+str(row[0])+",1.0);}"
		material.shader=shader
		var colour:Color=(await capture()).get_pixel(8,8)
		check(Vector3(colour.r,colour.g,colour.b).distance_to(row[1])<0.007,str(row[2]))
	for failure:String in failures:printerr("FAIL: "+failure)
	print("PC_TACTICAL_DIFFUSION_GPU: %d checks, %d errors"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func groundlight_gpu_contract() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(16,16)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var face:=ColorRect.new();face.size=Vector2(16,16);viewport.add_child(face)
	var material:=ShaderMaterial.new();face.material=material
	var functions:=FileAccess.get_file_as_string("res://scripts/pc_tactical_groundlight.gdshaderinc")
	var begin:=0
	var shared:=FileAccess.get_file_as_string("res://scripts/pc_tactical_materials.gdshaderinc")
	begin=shared.find("void realism_ground_coordinates(")
	var coordinates:=shared.substr(begin,shared.find("// Match detail contrast",begin)-begin)
	var period_begin:=shared.find("float realism_period(")
	var periods:=shared.substr(period_begin,shared.find("// Analytic",period_begin)-period_begin)
	var prefix:="shader_type canvas_item; render_mode unshaded;\n"+coordinates+periods+functions
	var cases:Array=[]
	# Brown-hill colour must be continuous, world anchored and filtered. These
	# use the production material function, independent of old palette steps.
	for row:Array in [
		[Vector3.BACK,Vector3.ZERO,Vector3.ONE*0.46,Vector2.ONE,1.0],
		[Vector3.RIGHT,Vector3(240,380,160),Vector3(0.25,0.5,0.65),Vector2.ONE,1.15],
		[Vector3.UP,Vector3(240,380,160),Vector3(0.25,0.5,0.65),Vector2.ONE,1.15],
		[Vector3.RIGHT,Vector3(240,380,160),Vector3(0.25,0.5,0.65),Vector2.ZERO,1.0],
		[Vector3(0.8,0,0.6),Vector3(3500,-4200,390),Vector3(0.5,0.4,0.6),Vector2(0.3,0.7),1.08],
		[Vector3.RIGHT,Vector3.ZERO,Vector3.ZERO,Vector2.ONE,0.82],
		[Vector3.RIGHT,Vector3.ZERO,Vector3.ONE,Vector2.ONE,1.18],
		[Vector3.RIGHT,Vector3.ZERO,Vector3.ONE*0.46,Vector2(9,-2),1.0]]:
		var face_value:Vector3=row[0];var point_value:Vector3=row[1];var samples:Vector3=row[2]
		var filters:Vector2=row[3].clamp(Vector2.ZERO,Vector2.ONE);var gain:float=row[4]
		var steep:float=1.0-smoothstep(0.25,0.82,absf(face_value.z))
		var patch:float=clampf(0.5+(samples.x-0.46)*1.35+(samples.y-0.46)*0.70*filters.x,0,1)
		var earth:=Vector3(0.30,0.248,0.177).lerp(Vector3(0.50,0.416,0.296),patch)
		var rock:=Vector3(0.36,0.335,0.28).lerp(Vector3(0.55,0.52,0.435),patch)
		earth=earth.lerp(rock,smoothstep(0.015,0.12,maxf(gain-1.0,0))*(0.16+0.58*steep))
		var strata:float=sin(point_value.z/52.0+sin(point_value.x/360.0+point_value.y/430.0)*1.2+(samples.x-0.46)*2.0)
		earth*=1.0+strata*0.09*steep*filters.y
		earth*=1.0+(samples.z-0.46)*0.18*filters.x
		earth=earth.clamp(Vector3.ONE*0.08,Vector3.ONE*0.72)
		cases.append(["tactical_hill_earth(vec3(%f,%f,%f),vec3(%f,%f,%f),vec3(%f,%f,%f),vec2(%f,%f),%f,0.46)"%[face_value.x,face_value.y,face_value.z,point_value.x,point_value.y,point_value.z,samples.x,samples.y,samples.z,row[3].x,row[3].y,gain],earth,"continuous brown-hill earth, filtered minerals and world-height strata"])
	for row:Array in [[8.0,Vector3(1.2,0.16,0)],[10.0,Vector3(1.65,0.22,0)],[11.0,Vector3(0.65,0.09,0.018)],[0.0,Vector3.ZERO],[9.0,Vector3.ZERO],[12.0,Vector3.ZERO]]:
		cases.append(["tactical_terrain_profile(%f)/2.0"%row[0],row[1]/2.0,"ground material profile"])
	var uv:=Vector2(0.3,0.7);var gradient:=Vector2(0.2,-0.1)
	var rate:=Vector2(cos(uv.dot(Vector2(0.41,0.19))),cos(uv.dot(Vector2(-0.17,0.37))))*0.22
	var g:=Vector2(gradient.x*(1.0+rate.x*0.41)+gradient.y*rate.y*(-0.17),gradient.x*rate.x*0.19+gradient.y*(1.0+rate.y*0.37))
	for row:Array in [[8.0,1.2,160.0],[10.0,1.65,128.0],[11.0,0.65,144.0]]:
		for axes:Array in [[Vector3.RIGHT,Vector3.UP,Vector3.BACK,1.0],[Vector3.UP,Vector3.BACK,Vector3.RIGHT,8.0],[Vector3.RIGHT,Vector3.BACK,Vector3.DOWN,9.0],[Vector3.RIGHT,Vector3.UP,Vector3(-0.4,0.2,1).normalized(),1.0]]:
			var x:Vector3=axes[0];var y:Vector3=axes[1];var n:Vector3=axes[2]
			var expected:Vector3=(x*g.x+y*g.y)*float(row[1])/float(row[2])
			expected-=n*expected.dot(n)
			cases.append(["tactical_terrain_slope(vec3(%f,%f,%f),vec2(0.2,-0.1),vec2(0.3,0.7),%f,%f)*16.0+0.5"%[n.x,n.y,n.z,axes[3],row[0]],expected*16.0+Vector3.ONE*0.5,"atlas warp and original world-plane gradient projection"])
		for slope:Vector3 in [Vector3.ZERO,Vector3(0.02,-0.01,0),Vector3(10,-20,0)]:
			var broad:=Vector3(0.03,0.02,1).normalized()
			var tangent:=Vector3(0.03,0.02,0)-slope
			var limit:float={8.0:0.16,10.0:0.22,11.0:0.09}[row[0]]
			if tangent.length()>limit:tangent=tangent.normalized()*limit
			var expected:Vector3=broad if slope==Vector3.ZERO else (Vector3.BACK+tangent).normalized()
			cases.append(["tactical_terrain_normal(vec3(0,0,1),normalize(vec3(0.03,0.02,1)),vec3(%f,%f,%f),%f)*0.5+0.5"%[slope.x,slope.y,slope.z,row[0]],expected*0.5+Vector3.ONE*0.5,"single slope limit and exact zero-gradient fallback"])
	for row:Array in [[Vector2.ZERO,1.0,8.0],[Vector2(0.2,-0.1),1.0,9.0],[Vector2(0.2,-0.1),0.0,8.0]]:
		var gradient_value:Vector2=row[0]
		cases.append(["tactical_terrain_slope(vec3(0,0,1),vec2(%f,%f),vec2(0.3,0.7),%f,%f)+0.5"%[gradient_value.x,gradient_value.y,row[1],row[2]],Vector3.ONE*0.5,"zero-gradient, unclassified family or unclassified plane remains neutral"])
	var sun:=Vector3(-0.58,0.34,0.74).normalized()
	for eye:Vector3 in [Vector3.BACK,Vector3(1,0,0.05).normalized(),sun,-sun]:
		for gain:float in [0.82,1.18]:
			var half_vector:Vector3=sun+eye
			var light:=0.0
			if half_vector.length_squared()>0.000001:
				var roughness:=clampf(0.82-(gain-1.0)*1.6,0.58,0.96)
				var power:=lerpf(8,20,1.0-roughness)
				light=pow(maxf(half_vector.normalized().z,0.0),power)*sun.z*(0.35+0.65*pow(1.0-absf(eye.z),3))*0.018/(1.0+pow(0.01*power*0.5,2))/(1.0+pow(420.0/8000.0,2))
			cases.append(["tactical_asphalt_light(vec3(0.3),vec3(0,0,1),vec3(%f,%f,%f),%f,420.0,0.01)"%[eye.x,eye.y,eye.z,gain],Vector3.ONE*0.3+Vector3(0.89,0.87,0.79)*light,"bounded dry aggregate light and opposite-sun stability"])
	for row:Array in cases:
		var shader:=Shader.new();shader.code=prefix+"void fragment(){COLOR=vec4("+str(row[0])+",1.0);}"
		material.shader=shader
		var colour:Color=(await capture()).get_pixel(8,8)
		check(Vector3(colour.r,colour.g,colour.b).distance_to(row[1])<0.007,str(row[2]))
	for failure:String in failures:printerr("FAIL: "+failure)
	print("PC_TACTICAL_GROUNDLIGHT_GPU: %d checks, %d errors"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func optics_gpu_contract() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(16,16)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var face:=ColorRect.new();face.size=Vector2(16,16);viewport.add_child(face)
	var material:=ShaderMaterial.new();face.material=material
	var source:=FileAccess.get_file_as_string("res://scripts/pc_surface.gdshader")
	var begin:=source.find("float tactical_optical_fresnel(")
	var functions:=source.substr(begin,source.find("vec3 tactical_textured_water(",begin)-begin)
	var shared:=FileAccess.get_file_as_string("res://scripts/pc_tactical_materials.gdshaderinc")
	begin=shared.find("vec3 tactical_horizon_palette(")
	var palette:=shared.substr(begin,shared.find("vec3 tactical_sky_finish(",begin)-begin)
	var prefix:="shader_type canvas_item; render_mode unshaded;\n"+palette+functions
	var cases:Array=[]
	for bounds:Vector2 in [Vector2(0.065,0.62),Vector2(0.065,0.48)]:
		for facing:float in [-1.0,0.0,0.1,0.5,0.9,1.0,2.0]:
			var expected:float=lerpf(bounds.x,bounds.y,pow(1.0-clampf(facing,0.0,1.0),5.0))
			cases.append(["vec3(tactical_optical_fresnel(%f,%f,%f))"%[facing,bounds.x,bounds.y],Vector3.ONE*expected,"clamped head-on/grazing reflectance"])
	for power:float in [24.0,48.0]:
		for gain:float in [0.82,1.0,1.18]:
			for pixel:float in [0.0,0.01,0.05]:
				var width:float=maxf(power*pow(2.0,-0.55*clampf((1.0-gain)/0.18,-1.0,1.0))/(1.0+power*pixel*pixel*160.0),power*0.22)
				cases.append(["vec3(tactical_optical_response(%f,%f,%f)/vec2(1.0,96.0),0.0)"%[gain,power,pixel],Vector3(minf(1.0,width/power),width/96.0,0),"roughness and footprint broaden lobes with bounded peaks"])
	cases.append(["tactical_optical_environment(vec3(0.8),vec3(0.0,0.0,-1.0),0.5)",Vector3(0.16,0.23,0.16),"downward reflection uses a subdued analytic earth tint"])
	cases.append(["vec3(0.5)+(tactical_optical_environment(vec3(0.8),normalize(vec3(1.0,0.0,0.0001)),0.5)-tactical_optical_environment(vec3(0.8),normalize(vec3(1.0,0.0,-0.0001)),0.5))",Vector3.ONE*0.5,"reflection crosses the horizon continuously"])
	for row:Array in cases:
		var shader:=Shader.new();shader.code=prefix+"\nvoid fragment(){COLOR=vec4("+str(row[0])+",1.0);}"
		material.shader=shader
		var colour:=(await capture()).get_pixel(8,8)
		check(Vector3(colour.r,colour.g,colour.b).distance_to(row[1])<0.007,str(row[2]))
	for failure:String in failures:printerr("FAIL: "+failure)
	print("PC_TACTICAL_OPTICS_GPU: %d checks, %d errors"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func lighting_gpu_contract() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(16,16)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var face:=ColorRect.new();face.size=Vector2(16,16);viewport.add_child(face)
	var material:=ShaderMaterial.new();face.material=material
	# Compile the actual pure lighting functions. Canvas diagnostics use the
	# Compatibility renderer's display-colour branch, without texture fixtures.
	var source:=FileAccess.get_file_as_string("res://scripts/pc_surface.gdshader")
	var begin:=source.find("vec3 tactical_daylight(")
	var light:=source.substr(begin,source.find("// Existing opaque glass facets",begin)-begin)
	begin=source.find("bool tactical_daylight_observed(")
	var fade:=source.substr(begin,source.find("vec3 tactical_water(",begin)-begin)
	var prefix:="shader_type canvas_item; render_mode unshaded;\nuniform vec3 source_horizon_line=vec3(0.0,1.0,0.0);\n"+(fade+light).replace("OUTPUT_IS_SRGB","true")
	var cases:Array=[]
	for row:Array in [[0.0,0.001,1.0],[800.0,0.003,1.0],[6000.0,0.001,0.0],[0.0,0.05,0.0],[3400.0,0.0265,0.25]]:
		cases.append(["vec3(tactical_glint_fade(%f,%f))"%[row[0],row[1]],Vector3.ONE*float(row[2]),"bounded distance/footprint glint fade"])
	var responses:Array=[Vector2(0.028,22),Vector2(0,8),Vector2(0,8),Vector2(0.004,10),Vector2(0.0025,7),Vector2(0.006,9),Vector2(0.007,12),Vector2(0,18)]
	for i in responses.size():
		cases.append(["vec3(tactical_highlight_response(%f)/vec2(0.03,32.0),0.0)"%float(i+1),Vector3(responses[i].x/0.03,responses[i].y/32.0,0),"material-specific highlight family %d"%(i+1)])
	var sun:="normalize(vec3(-0.58,0.34,0.74))"
	for row:Array in [[sun,sun,200.0,0.001,true],[sun,"-"+sun,200.0,0.001,false],["-"+sun,sun,200.0,0.001,false],[sun,sun,6000.0,0.001,false],[sun,sun,200.0,0.05,false]]:
		var extra:="(tactical_finish_light(vec3(0.2),%s,%s,0.028,1.0,%f,%f)-tactical_daylight(vec3(0.2),%s,%s,0.0))*10.0"%[row[0],row[1],row[2],row[3],row[0],row[1]]
		cases.append([extra,Vector3(1,0.97,0.88)*0.28 if row[4] else Vector3.ZERO,"finite, sun-facing, filtered paint lobe"])
	if "--sheen-gpu" in OS.get_cmdline_user_args():
		for i in 8:
			for gain:float in [0.82,1.0,1.18]:
				var original:Vector2=responses[i]
				var power:float=original.y*pow(2.0,-0.45*clampf((1.0-gain)/0.18,-1.0,1.0)) if i not in [1,2,7] else original.y
				var peak:float=original.x*minf(1.0,power/original.y)
				cases.append(["vec3(tactical_textured_response(%f,%f)/vec2(0.03,32.0),0.0)"%[float(i+1),gain],Vector3(peak/0.03,power/32.0,0),"filtered texture cue respects material width and peak cap"])
		for row:Array in [[0.0,0.82],[13.0,1.18],[1.0,-9.0],[1.0,9.0]]:
			var family:float=row[0];var gain:float=row[1]
			var original:Vector2=responses[0] if family<1.5 else Vector2(0,18)
			var power:float=original.y*pow(2.0,-0.45*clampf((1.0-gain)/0.18,-1.0,1.0)) if family==1.0 else original.y
			cases.append(["vec3(tactical_textured_response(%f,%f)/vec2(0.03,32.0),0.0)"%[family,gain],Vector3(original.x*minf(1.0,power/original.y)/0.03,power/32.0,0),"unknown families exact and extreme cues clamped"])
		for family:float in [1.0,2.0,3.0,4.0,5.0,6.0,7.0]:
			var extra:="(tactical_textured_finish_light(vec3(0.2),%s,%s,0.028,%f,200.0,0.001,0.82)-tactical_daylight(vec3(0.2),%s,%s,0.0))*10.0"%[sun,sun,family,sun,sun]
			var original:Vector2=responses[int(family)-1]
			cases.append([extra,Vector3(1,0.97,0.88)*original.x*pow(2.0,-0.45)*10.0,"actual textured lobe is sun-facing and bounded"])
		for row:Array in [[sun,"-"+sun,200.0,0.001],["-"+sun,sun,200.0,0.001],[sun,sun,6000.0,0.001],[sun,sun,200.0,0.05]]:
			var extra:="(tactical_textured_finish_light(vec3(0.2),%s,%s,0.028,1.0,%f,%f,0.82)-tactical_daylight(vec3(0.2),%s,%s,0.0))*10.0"%[row[0],row[1],row[2],row[3],row[0],row[1]]
			cases.append([extra,Vector3.ZERO,"textured lobe respects opposing eye/sun and unresolved/distant controls"])
	for row:Array in cases:
		var shader:=Shader.new();shader.code=prefix+"\nvoid fragment(){COLOR=vec4("+str(row[0])+",1.0);}"
		material.shader=shader
		var colour:=(await capture()).get_pixel(8,8)
		check(Vector3(colour.r,colour.g,colour.b).distance_to(row[1])<0.007,str(row[2]))
	var fallback:=Shader.new()
	fallback.code=prefix+"\nvoid fragment(){vec3 sun=normalize(vec3(-0.58,0.34,0.74));COLOR=vec4(vec3(0.5)+(tactical_finish_light(vec3(0.2),sun,sun,0.028,1.0,200.0,0.001)-tactical_daylight(vec3(0.2),sun,sun,0.028))*10.0,1.0);}"
	material.shader=fallback;material.set_shader_parameter("source_horizon_line",Vector3.ZERO)
	var colour:=(await capture()).get_pixel(8,8)
	check(Vector3(colour.r,colour.g,colour.b).distance_to(Vector3.ONE*0.5)<0.007,"unverified daylight retains the exact preceding lobe")
	for failure:String in failures:printerr("FAIL: "+failure)
	print(("PC_TACTICAL_SHEEN_GPU" if "--sheen-gpu" in OS.get_cmdline_user_args() else "PC_TACTICAL_LIGHTING_GPU")+": %d checks, %d errors"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func horizon_gpu_contract() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(16,16)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var face:=ColorRect.new();face.size=Vector2(16,16);viewport.add_child(face)
	var material:=ShaderMaterial.new();face.material=material
	var source:=FileAccess.get_file_as_string("res://scripts/pc_surface.gdshader")
	var begin:=source.find("vec2 tactical_horizon_gradient(")
	var functions:=source.substr(begin,source.find("vec3 horizon_vegetation(",begin)-begin)
	var prefix:="shader_type canvas_item; render_mode unshaded;\n"+functions
	for angle:float in [0.0,1.0,PI-0.0001,PI,-PI,-PI+0.0001]:
		var direction:=Vector3(sin(angle),cos(angle),0.0)
		var tangent:=Vector3(cos(angle),-sin(angle),0.0)
		var shader:=Shader.new()
		shader.code=prefix+"void fragment(){vec3 d=vec3(%f,%f,0.0);vec3 t=vec3(%f,%f,0.0);COLOR=vec4(tactical_horizon_gradient(d,t*0.001,t*(-0.0005))*8.0+0.5,0.0,1.0);}"%[direction.x,direction.y,tangent.x,tangent.y]
		material.shader=shader
		var colour:=(await capture()).get_pixel(8,8)
		var expected:=Vector2(0.001,-0.0005)*(96.0/TAU)*8.0+Vector2.ONE*0.5
		check(Vector2(colour.r,colour.g).distance_to(expected)<0.007,"continuous signed angular footprint, including both wrap sides")
	var zenith:=Shader.new()
	zenith.code=prefix+"void fragment(){COLOR=vec4(tactical_horizon_gradient(vec3(0.0,0.0,1.0),vec3(0.001,0.0,0.0),vec3(0.0,0.001,0.0))+0.5,0.0,1.0);}"
	material.shader=zenith
	var colour:=(await capture()).get_pixel(8,8)
	check(Vector2(colour.r,colour.g).distance_to(Vector2.ONE*0.5)<0.007,"zenith footprint remains finite")
	for row:Array in [[0.0,1.0],[0.25,1.0],[0.525,0.5],[0.8,0.0],[3.0,0.0]]:
		var shader:=Shader.new()
		shader.code=prefix+"void fragment(){COLOR=vec4(vec3(tactical_horizon_detail(%f)),1.0);}"%row[0]
		material.shader=shader
		colour=(await capture()).get_pixel(8,8)
		check(absf(colour.r-float(row[1]))<0.007,"bounded unresolved-detail fade")
	for failure:String in failures:printerr("FAIL: "+failure)
	print("PC_TACTICAL_HORIZON_GPU: %d checks, %d errors"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func grounding_gpu_contract() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(16,16)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var face:=ColorRect.new();face.size=Vector2(16,16);viewport.add_child(face)
	var material:=ShaderMaterial.new();face.material=material
	var source:=FileAccess.get_file_as_string("res://scripts/pc_surface.gdshader")
	var begin:=source.find("float tactical_ground_detail(")
	var functions:=source.substr(begin,source.find("vec3 tactical_meadow(",begin)-begin)
	begin=source.find("vec3 tactical_slope_normal(")
	functions+=source.substr(begin,source.find("vec3 tactical_soil(",begin)-begin)
	var shared:=FileAccess.get_file_as_string("res://scripts/pc_tactical_materials.gdshaderinc")
	var footprint_begin:=shared.find("bool realism_ground(")
	var footprint_functions:=shared.substr(footprint_begin,shared.find("// Gentle continuous",footprint_begin)-footprint_begin)
	var prefix:="shader_type canvas_item; render_mode unshaded;\n"+footprint_functions+functions
	for row:Array in [[0.0,1.0],[0.14,1.0],[0.32,0.5],[0.5,0.0],[1000.0,0.0]]:
		var shader:=Shader.new()
		shader.code=prefix+"void fragment(){COLOR=vec4(vec3(tactical_ground_detail(vec2(%f,0.0),1.0)),1.0);}"%row[0]
		material.shader=shader
		check(absf((await capture()).get_pixel(8,8).r-float(row[1]))<0.007,"ground detail smoothly converges to its mean")
	if "--distance-blending" in OS.get_cmdline_user_args():
		var preceding:=1.0
		for footprint in [0.0,0.07,0.14,0.22,0.32,0.5,1.0,4.0]:
			var shader:=Shader.new()
			shader.code=prefix+"void fragment(){COLOR=vec4(vec3(tactical_ground_colour_fade(vec2(%f,0.0),vec2(0.0,%f),1.0)),1.0);}"%[footprint,footprint]
			material.shader=shader
			var value:float=(await capture()).get_pixel(8,8).r
			var expected:float=1.0/(1.0+pow(float(footprint)/0.22,2.0))
			check(absf(value-expected)<0.007,"prefiltered colour has a continuous distance tail")
			check(value<=preceding+0.005,"colour fade is monotonic")
			preceding=value
		for axes in [[Vector2(0.5,0),Vector2(0,0.02)],[Vector2(0,0.5),Vector2(-0.02,0)]]:
			var shader:=Shader.new()
			shader.code=prefix+"void fragment(){COLOR=vec4(vec3(tactical_ground_colour_fade(vec2(%f,%f),vec2(%f,%f),1.0)),1.0);}"%[axes[0].x,axes[0].y,axes[1].x,axes[1].y]
			material.shader=shader
			check(absf((await capture()).get_pixel(8,8).r-0.98022152)<0.007,"grazing colour respects 16x filtering and rotation")
	for row:Array in [[0.0,3.0],[16.0,3.0],[64.0,5.0],[2048.0,10.0]]:
		var shader:=Shader.new()
		shader.code=prefix+"void fragment(){COLOR=vec4(vec3(tactical_ground_broad_lod(vec2(%f,0.0),2048.0,vec2(1024.0))/16.0),1.0);}"%row[0]
		material.shader=shader
		check(absf((await capture()).get_pixel(8,8).r-float(row[1])/16.0)<0.007,"broad mip keeps its floor and resolves large footprints")
	for row:Array in [[Vector3(0,0,1),7.0],[Vector3(1,0,0),8.0],[Vector3(0,1,0),9.0],[Vector3(0.6,0,0.8),7.0]]:
		var normal:Vector3=row[0]
		var relief:=Vector3(-0.4,0.25,0.0)
		if row[1]>8.5:relief=Vector3(-0.4,0.0,0.25)
		elif row[1]>7.5:relief=Vector3(0.0,-0.4,0.25)
		relief-=normal*normal.dot(relief)
		var expected:Vector3=(normal+relief*0.8).normalized()*0.5+Vector3.ONE*0.5
		var shader:=Shader.new()
		shader.code=prefix+"void fragment(){COLOR=vec4(tactical_slope_normal(vec3(%f,%f,%f),vec2(0.4,-0.25),%f)*0.5+0.5,1.0);}"%[normal.x,normal.y,normal.z,row[1]]
		material.shader=shader
		var colour:Color=(await capture()).get_pixel(8,8)
		check(Vector3(colour.r,colour.g,colour.b).distance_to(expected)<0.008,"XY/XZ/YZ and oblique relief stay in the source tangent plane")
	for failure:String in failures:printerr("FAIL: "+failure)
	print("PC_TACTICAL_GROUNDING_GPU: %d checks, %d errors"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func arbor_gpu_contract() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(16,16)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var face:=ColorRect.new();face.size=Vector2(16,16);viewport.add_child(face)
	var material:=ShaderMaterial.new();face.material=material
	var source:=FileAccess.get_file_as_string("res://scripts/pc_surface.gdshader")
	var begin:=source.find("vec3 tactical_tree_normal(")
	var functions:=source.substr(begin,source.find("vec3 tactical_bark(",begin)-begin)
	source=FileAccess.get_file_as_string("res://scripts/pc_tactical_foliage.gdshader")
	begin=source.find("float tactical_leaf_highlight(")
	functions+=source.substr(begin,source.find("void vertex()",begin)-begin)
	var shared:=FileAccess.get_file_as_string("res://scripts/pc_tactical_materials.gdshaderinc")
	var shared_begin:=shared.find("vec3 tactical_environment_tint(")
	shared=shared.substr(shared_begin,shared.find("vec3 tactical_horizon_palette(",shared_begin)-shared_begin)
	var prefix:="shader_type canvas_item; render_mode unshaded; uniform mat3 camera_to_local;uniform bool modern_environment_polish=true;\n"+shared+functions
	var shader:=Shader.new()
	shader.code=prefix+"uniform vec3 eye;uniform float pixel;uniform float distance_raw;void fragment(){COLOR=vec4(tactical_tree_light(vec3(0.3,0.4,0.2),vec2(0.4,0.1),vec2(pixel),eye,distance_raw),1.0);}"
	material.shader=shader;material.set_shader_parameter("camera_to_local",Basis.IDENTITY)
	material.set_shader_parameter("pixel",0.0);material.set_shader_parameter("distance_raw",100.0)
	var sun:=Vector3(-0.58,0.34,0.74).normalized()
	material.set_shader_parameter("eye",sun)
	var front:Color=(await capture()).get_pixel(8,8)
	material.set_shader_parameter("eye",-sun)
	var back:Color=(await capture()).get_pixel(8,8)
	check(back.r>front.r+0.02 and back.b<front.b+0.009,"restrained warm upper-crown transmission")
	check(back.r<0.35*1.06 and back.g<0.46*1.06 and back.b<0.23*1.06,"bounded crown gain")
	for basis:Basis in [Basis(Vector3(0,0,1),PI/2.0),Basis(Vector3(0,0,1),PI)]:
		material.set_shader_parameter("camera_to_local",basis)
		check((await capture()).get_pixel(8,8)!=back,"volume light follows captured world orientation")
	material.set_shader_parameter("camera_to_local",Basis.IDENTITY)
	check((await capture()).get_pixel(8,8)==back,"world orientation restore exact")
	material.set_shader_parameter("pixel",0.09)
	var unresolved:Color=(await capture()).get_pixel(8,8)
	check(Vector3(unresolved.r,unresolved.g,unresolved.b).distance_to(Vector3(0.3,0.4,0.2))<0.008,"unresolved tree volume converges to preceding colour")
	material.set_shader_parameter("pixel",0.0);material.set_shader_parameter("distance_raw",10000.0)
	var distant:Color=(await capture()).get_pixel(8,8)
	check(Vector3(distant.r,distant.g,distant.b).distance_to(Vector3(0.3,0.4,0.2))<0.008,"distant tree volume converges to preceding colour")
	for row:Array in [[0.0,1.0],[0.02,1.0],[0.055,0.5],[0.09,0.0],[1.0,0.0]]:
		shader=Shader.new();shader.code=prefix+"void fragment(){COLOR=vec4(vec3(tactical_leaf_highlight(%f)),1.0);}"%row[0]
		material.shader=shader
		check(absf((await capture()).get_pixel(8,8).r-float(row[1]))<0.007,"bounded resolution-aware leaf sheen")
	for failure:String in failures:printerr("FAIL: "+failure)
	print("PC_TACTICAL_ARBOR_GPU: %d checks, %d errors"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func microfinish_gpu_contract() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(16,16)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var face:=ColorRect.new();face.size=Vector2(16,16);viewport.add_child(face)
	var material:=ShaderMaterial.new();face.material=material
	var include:=FileAccess.get_file_as_string("res://scripts/pc_tactical_materials.gdshaderinc")
	var before:=FileAccess.get_file_as_string("res://tests/microfinish-before.gdshaderinc")
	before=before.substr(before.find("float realism_mean("))
	before=before.replace("realism_","before_realism_").replace("tactical_before_realism_atlas","tactical_realism_atlas")
	var source:=FileAccess.get_file_as_string("res://scripts/pc_surface.gdshader")
	var begin:=source.find("vec2 tactical_relief_profile(")
	var helpers:=source.substr(begin,source.find("void vertex()",begin)-begin)
	var prefix:="shader_type canvas_item;render_mode unshaded;\n"+include+before+helpers
	# A deterministic test-only ramp supplies nonzero height differences while
	# comparing the actual preceding and new colour functions on the same GPU.
	var image:=Image.create(32,32,false,Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:image.set_pixel(x,y,Color(float(x+y)/64.0,float(x+y)/64.0,float(x+y)/64.0,1))
	image.generate_mipmaps()
	material.set_shader_parameter("tactical_realism_atlas",ImageTexture.create_from_image(image))
	for family in range(1,15):
		var shader:=Shader.new()
		shader.code=prefix+"void fragment(){vec2 uv=vec2(0.23,0.31);vec2 dx=vec2(0.002,0.0);vec2 dy=vec2(0.0,0.003);float delta=realism_sample(uv,dx,dy,%f,100.0).x-before_realism_gain(uv,dx,dy,%f,100.0);COLOR=vec4(vec3(0.5+delta*8.0),1.0);}"%[float(family),float(family)]
		material.shader=shader
		check(absf((await capture()).get_pixel(8,8).r-0.5)<0.007,"preceding atlas colour gain exact for family "+str(family))
	for args:String in ["vec2(0.23,0.31),vec2(0.05,0.0),vec2(0.0,0.05),1.0,100.0","vec2(0.23,0.31),vec2(0.001,0.0),vec2(0.0,0.001),1.0,9000.0"]:
		var shader:=Shader.new();shader.code=prefix+"void fragment(){vec3 value=realism_sample("+args+");COLOR=vec4(vec3(value.x-0.5,0.5+value.y*0.1,0.5+value.z*0.1),1.0);}"
		material.shader=shader
		var colour:Color=(await capture()).get_pixel(8,8)
		check(Vector3(colour.r,colour.g,colour.b).distance_to(Vector3.ONE*0.5)<0.007,"unresolved or distant height converges to flat preceding gain")
	for uv:String in ["vec2(0.0,0.31)","vec2(0.5,0.31)","vec2(1.0,0.31)"]:
		var shader:=Shader.new();shader.code=prefix+"void fragment(){COLOR=vec4(vec3(0.5+realism_sample("+uv+",vec2(0.002,0.0),vec2(0.0,0.002),1.0,100.0).y*0.1),1.0);}"
		material.shader=shader
		check(absf((await capture()).get_pixel(8,8).r-0.5)<0.007,"mirrored fold has no discontinuous height slope")
	var flat:=Vector3(0,0,1)
	var expected:=(flat-Vector3(0.045,0.045,0)).normalized()
	var cases:Array=[
		["vec3(0,0,1),vec2(10,5),vec3(1,0,0),vec3(0,1,0),vec2(0.01,0),vec2(0,0.02),1.0",expected,"horizontal face"],
		["vec3(0,-1,0),vec2(10,5),vec3(1,0,0),vec3(0,0,1),vec2(0.01,0),vec2(0,0.02),1.0",(Vector3(0,-1,0)-Vector3(0.045,0,0.045)).normalized(),"vertical face"],
		["vec3(0,-0.6,0.8),vec2(10,5),vec3(1,0,0),vec3(0,0.8,0.6),vec2(0.01,0),vec2(0,0.02),1.0",(Vector3(0,-0.6,0.8)-Vector3(0.045,0.036,0.027)).normalized(),"oblique face"],
		["vec3(0,0,1),vec2(-10,5),vec3(1,0,0),vec3(0,1,0),vec2(-0.01,0),vec2(0,0.02),1.0",expected,"mirrored coordinate sign"],
		["vec3(0,0,1),vec2(10,5),vec3(1,0,0),vec3(1,0,0),vec2(0.01,0),vec2(0,0.02),1.0",flat,"degenerate frame fallback"],
		["vec3(0,0,1),vec2(0),vec3(1,0,0),vec3(0,1,0),vec2(0.01,0),vec2(0,0.02),1.0",flat,"zero gradient exact"],
		["vec3(0,0,1),vec2(10,5),vec3(1,0,0),vec3(0,1,0),vec2(0.01,0),vec2(0,0.02),8.0",flat,"unadmitted family exact"]]
	for row:Array in cases:
		var shader:=Shader.new();shader.code=prefix+"void fragment(){COLOR=vec4(tactical_relief_normal("+str(row[0])+")*0.5+0.5,1.0);}"
		material.shader=shader
		var colour:Color=(await capture()).get_pixel(8,8)
		check((Vector3(colour.r,colour.g,colour.b)*2.0-Vector3.ONE).distance_to(row[1])<0.012,str(row[2])+": source-face tangent conversion")
	for family in range(1,8):
		var shader:=Shader.new();shader.code=prefix+"void fragment(){vec3 n=tactical_relief_normal(vec3(0,0,1),vec2(100000),vec3(1,0,0),vec3(0,1,0),vec2(1,0),vec2(0,1),%f);COLOR=vec4(n*0.5+0.5,1.0);}"%float(family)
		material.shader=shader
		var colour:Color=(await capture()).get_pixel(8,8)
		var normal:=Vector3(colour.r,colour.g,colour.b)*2.0-Vector3.ONE
		var limit:float=[0.15,0.18,0.28,0.22,0.08,0.06,0.22][family-1]
		check(is_finite(normal.x) and normal.z>0.95 and Vector2(normal.x,normal.y).length()/normal.z<limit+0.012,"bounded material relief family "+str(family))
	for failure:String in failures:printerr("FAIL: "+failure)
	print("PC_TACTICAL_MICROFINISH_GPU: %d checks, %d errors"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func aerial_gpu_contract() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(16,16)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var face:=ColorRect.new();face.size=Vector2(16,16);viewport.add_child(face)
	var material:=ShaderMaterial.new();face.material=material
	var source:=FileAccess.get_file_as_string("res://scripts/pc_tactical_materials.gdshaderinc")
	var functions:=source.substr(source.find("float tactical_air_weight(")).replace("OUTPUT_IS_SRGB","true")
	var prefix:="shader_type canvas_item;render_mode unshaded;\n"+functions
	var cases:Array=[[Vector3(0,0,0),50.0,0.1],[Vector3(0,600,0),50.0,0.1],[Vector3(0,601,0),50.0,0.1],[Vector3(0,2000,-50),50.0,0.1],[Vector3(0,10000,-50),50.0,0.1],[Vector3(0,100000,-50),50.0,0.1],[Vector3(0,100000,-50),50.0,0.16],[Vector3(0,10000,0),2000.0,0.16],[Vector3(0,10000,4000),50.0,0.16],[Vector3(0,10000,-2000),2000.0,0.16],[Vector3(0,10000,-0.5),50.0,0.16],[Vector3(0,10000,-1000),50.0,0.16]]
	for row:Array in cases:
		var relative:Vector3=row[0];var eye:float=row[1];var ceiling:float=row[2]
		var start:=maxf(eye,0.0);var end:=maxf(eye+relative.z,0.0)
		var a:=pow(2.0,-start/512.0);var b:=pow(2.0,-end/512.0);var delta:float=(end-start)/512.0
		var density:float=(a+b)*0.5 if absf(delta)<0.002 else (a-b)/(delta*log(2.0))
		var expected:float=(1.0-pow(2.0,-maxf(relative.length()-600.0,0.0)/9000.0))*(0.35+0.65*clampf(density,0.0,1.0))
		var args:="vec3(%f,%f,%f),%f,%f"%[relative.x,relative.y,relative.z,eye,ceiling]
		var shader:=Shader.new();shader.code=prefix+"void fragment(){COLOR=vec4(vec3(tactical_air_weight("+args+")/%f),1.0);}"%ceiling
		material.shader=shader
		check(absf((await capture()).get_pixel(8,8).r-expected)<0.006,"bounded source-unit air path case "+str(checks))
	for relative:String in ["vec3(0)","vec3(0,600,0)","vec3(400,300,0)"]:
		var shader:=Shader.new();shader.code=prefix+"void fragment(){COLOR=vec4(vec3(0.5)+(tactical_air_colour(vec3(0.24,0.33,0.15),"+relative+",50.0,0.1)-vec3(0.24,0.33,0.15))*10.0,1.0);}"
		material.shader=shader
		check(absf((await capture()).get_pixel(8,8).r-0.5)<0.006,"near-field colour exact")
	for limit:float in [0.10,0.16]:
		var shader:=Shader.new();shader.code=prefix+"void fragment(){vec3 p=vec3(0,100000,-50);vec3 a=tactical_air_colour(vec3(0.2,0.3,0.1),p,50.0,%f);vec3 b=tactical_air_colour(vec3(0.3,0.4,0.2),p,50.0,%f);COLOR=vec4((b-a)*5.0,1.0);}"%[limit,limit]
		material.shader=shader
		var colour:Color=(await capture()).get_pixel(8,8)
		check(colour.r>=0.5*(1.0-limit)-0.006 and colour.r<=0.506,"source contrast floor for ceiling "+str(limit))
	var shader:=Shader.new();shader.code=prefix+"uniform vec3 relative;void fragment(){COLOR=vec4(tactical_air_colour(vec3(0.25,0.35,0.18),relative,50.0,0.1),1.0);}"
	material.shader=shader
	var sun:=Vector3(-0.58,0.34,0.0).normalized()*50000.0
	material.set_shader_parameter("relative",sun)
	var warm:Color=(await capture()).get_pixel(8,8)
	material.set_shader_parameter("relative",-sun)
	var cool:Color=(await capture()).get_pixel(8,8)
	check(warm!=cool,"air tint follows source-world sun direction")
	material.set_shader_parameter("relative",sun)
	check((await capture()).get_pixel(8,8)==warm,"source-world direction restore exact")
	for failure:String in failures:printerr("FAIL: "+failure)
	print("PC_TACTICAL_AERIAL_GPU: %d checks, %d errors"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func radiance_gpu_contract() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(16,16)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var face:=ColorRect.new();face.size=Vector2(16,16);viewport.add_child(face)
	var material:=ShaderMaterial.new();face.material=material
	var include:=FileAccess.get_file_as_string("res://scripts/pc_tactical_materials.gdshaderinc").replace("OUTPUT_IS_SRGB","true")
	var source:=FileAccess.get_file_as_string("res://scripts/pc_surface.gdshader")
	var before:=FileAccess.get_file_as_string("res://tests/radiance-before.gdshader")
	var a:=source.find("float ground_hash(");var helpers:=source.substr(a,source.find("float ground_grain(",a)-a)
	a=source.find("vec3 tactical_coherent_sky(");helpers+=source.substr(a,source.find("bool tactical_daylight_observed(",a)-a)
	a=before.find("vec3 tactical_sky_colour(");helpers+=before.substr(a,before.find("bool tactical_daylight_observed(",a)-a).replace("tactical_sky_colour","preceding_sky_colour")
	a=source.find("vec3 tactical_trunk_fill(");helpers+=source.substr(a,source.find("// Differentiate",a)-a)
	var prefix:="shader_type canvas_item;render_mode unshaded;uniform bool modern_environment_polish=true;uniform vec3 source_horizon_line=vec3(0,1,0);uniform mat3 camera_to_local;\n"+include+helpers
	var shader:=Shader.new();shader.code=prefix+"uniform vec3 direction;uniform float strength;void fragment(){COLOR=vec4(tactical_environment_tint(direction,strength)*0.5,1.0);}"
	material.shader=shader
	for normal:Vector3 in [Vector3.ZERO,Vector3.RIGHT,Vector3.LEFT,Vector3(0,1,0),Vector3(0,-1,0),Vector3(0,0,1),Vector3(0,0,-1),Vector3(-0.58,0.34,0.74),Vector3(0.58,-0.34,-0.74)]:
		for strength:float in [0.0,0.4,1.0]:
			material.set_shader_parameter("direction",normal);material.set_shader_parameter("strength",strength)
			var c:Color=(await capture()).get_pixel(8,8);var tint:=Vector3(c.r,c.g,c.b)*2.0
			check(is_finite(tint.x) and tint.min_axis_index()>=0 and minf(tint.x,minf(tint.y,tint.z))>=0.932 and maxf(tint.x,maxf(tint.y,tint.z))<=1.068,"hemisphere fill finite and component-bounded, including zero normal")
			if strength==0.0:check(tint.distance_to(Vector3.ONE)<0.008,"disabled environment strength exact")
	shader=Shader.new();shader.code=prefix+"uniform vec3 direction;void fragment(){COLOR=vec4(tactical_horizon_palette(direction),1.0);}"
	material.shader=shader
	for direction:Vector3 in [Vector3.ZERO,Vector3(-0.58,0.34,0.74),Vector3(0.58,-0.34,-0.74),Vector3(0.0001,-1,0),Vector3(-0.0001,-1,0),Vector3(0,0,1)]:
		material.set_shader_parameter("direction",direction)
		var c:Color=(await capture()).get_pixel(8,8)
		check(is_finite(c.r) and c.r>0.69 and c.r<0.84 and c.g>0.69 and c.g<0.84 and c.b>0.69 and c.b<0.84,"directional horizon palette finite and restrained")
	for height:float in [0.0,0.1,0.4,0.74,1.0]:
		shader=Shader.new();shader.code=prefix+"void fragment(){vec3 a=tactical_sky_finish(vec3(0.6,0.7,0.7),vec3(-0.58,0.34,0.74),%f);COLOR=vec4(a,1.0);}"%height
		material.shader=shader;var c:Color=(await capture()).get_pixel(8,8)
		check(is_finite(c.r) and c.r>=0.0 and c.r<=1.0 and c.g<=1.0 and c.b<=1.0,"sky aureole/height blend bounded through horizon and zenith")
	for shape:float in [0.57,0.68,0.79]:
		shader=Shader.new();shader.code=prefix+"void fragment(){COLOR=vec4(tactical_cloud_finish(vec3(0.8),vec3(-0.58,0.34,0.74),%f),1.0);}"%shape
		material.shader=shader;var warm:Color=(await capture()).get_pixel(8,8)
		shader=Shader.new();shader.code=prefix+"void fragment(){COLOR=vec4(tactical_cloud_finish(vec3(0.8),vec3(0.58,-0.34,-0.74),%f),1.0);}"%shape
		material.shader=shader;var cool:Color=(await capture()).get_pixel(8,8)
		check(warm.r>cool.r and warm.b<cool.b and warm.r<0.86 and cool.b<0.86,"cloud sunward edges and cool interiors remain bounded")
	for direction:Vector3 in [Vector3(0,1,0),Vector3(0.3,1,0.4),Vector3(-0.3,-1,0.4)]:
		shader=Shader.new();shader.code=prefix+"void fragment(){vec3 d=vec3(%f,%f,%f);COLOR=vec4(vec3(0.5)+(tactical_sky_colour(d)-tactical_coherent_sky(d,d))*8.0,1.0);}"%[direction.x,direction.y,direction.z]
		material.shader=shader;var c:Color=(await capture()).get_pixel(8,8)
		check(Vector3(c.r,c.g,c.b).distance_to(Vector3.ONE*0.5)<0.008,"water/glass wrapper shares the same world-ray sky")
		material.set_shader_parameter("modern_environment_polish",false)
		shader=Shader.new();shader.code=prefix+"void fragment(){vec3 d=vec3(%f,%f,%f);COLOR=vec4(vec3(0.5)+(tactical_coherent_sky(d,vec3(d.x,-d.y,d.z))-preceding_sky_colour(d))*8.0,1.0);}"%[direction.x,direction.y,direction.z]
		material.shader=shader;material.set_shader_parameter("modern_environment_polish",false);c=(await capture()).get_pixel(8,8)
		check(Vector3(c.r,c.g,c.b).distance_to(Vector3.ONE*0.5)<0.008,"disabled environment retains preceding cloud shape and colour")
		material.set_shader_parameter("modern_environment_polish",true)
	for pixel:float in [0.0,0.01,0.1]:
		shader=Shader.new();shader.code=prefix+"void fragment(){COLOR=vec4(tactical_trunk_fill(vec2(0.53,0.9),vec2(%f),0.05)*0.5,1.0);}"%pixel
		material.shader=shader;material.set_shader_parameter("camera_to_local",Basis.IDENTITY)
		var c:Color=(await capture()).get_pixel(8,8)
		check(c.r>0.465 and c.r<0.535 and c.g>0.465 and c.g<0.535 and c.b>0.465 and c.b<0.535,"trunk fill uses finite supplied footprint and bounded source-world response")
		if pixel==0.1:check(Vector3(c.r,c.g,c.b).distance_to(Vector3.ONE*0.5)<0.008,"unresolved trunk fill returns neutral")
	for failure:String in failures:printerr("FAIL: "+failure)
	print("PC_TACTICAL_RADIANCE_GPU: %d checks, %d errors"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func bevel_gpu_contract() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(16,16)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var face:=ColorRect.new();face.size=Vector2(16,16);viewport.add_child(face)
	var material:=ShaderMaterial.new();face.material=material
	var source:=FileAccess.get_file_as_string("res://scripts/pc_surface.gdshader")
	var begin:=source.find("float tactical_bevel_slope(")
	var functions:=source.substr(begin,source.find("void vertex()",begin)-begin)
	var prefix:="shader_type canvas_item;render_mode unshaded;\n"+functions
	# The sign/period derivative comes from the actual preceding smooth seam.
	for row:Array in [[0.0,0.02,0.065,-0.09],[0.0715,0.02,0.065,-0.09],[-0.0715,0.02,0.065,-0.09],[1.0715,0.02,0.065,-0.09],[0.0715,0.5,0.065,-0.09]]:
		var x:float=fposmod(float(row[0])+0.5,1.0)-0.5;var pixel:float=row[1];var edge:float=maxf(pixel*0.65,0.008)
		var t:float=clampf((absf(x)-float(row[2]))/edge,0.0,1.0)
		var expected:float=-float(row[3])*signf(x)*6.0*t*(1.0-t)/edge*(1.0-smoothstep(0.2,0.5,pixel))
		var shader:=Shader.new();shader.code=prefix+"void fragment(){COLOR=vec4(vec3(0.5+tactical_bevel_slope(%f,%f,%f,%f)/32.0),1.0);}"%[row[0],row[1],row[2],row[3]]
		material.shader=shader
		check(absf((await capture()).get_pixel(8,8).r-(0.5+expected/32.0))<0.006,"finite signed periodic bevel derivative")
	var cases:Array=[
		["vec2(0),vec2(0.001),20.25,100.0,1.0",false,"wheel centre finite"],
		["vec2(0.3,0.2),vec2(0.01),20.25,100.0,1.0",true,"wheel dish and spoke"],
		["vec2(0.3,0.2),vec2(0.3),20.25,100.0,1.0",false,"unresolved wheel"],
		["vec2(0.3,0.2),vec2(0.01),20.25,8000.0,1.0",false,"distant wheel"],
		["vec2(0.0715,0),vec2(0.02),20.125,100.0,1.0",true,"track groove"],
		["vec2(0.0715,0),vec2(0.5),20.125,100.0,1.0",false,"unresolved link"],
		["vec2(0.0715,0),vec2(0.02),20.125,8000.0,1.0",false,"distant link"],
		["vec2(1.5,0.56),vec2(0.14),20.46875,100.0,7.0",true,"tile course"],
		["vec2(1.0,1.2),vec2(1.0),20.4375,100.0,7.0",true,"flat roof seam"],
		["vec2(1.5,0.56),vec2(0.14),20.46875,100.0,3.0",false,"stone trim never a roof"],
		["vec2(1.5,0.56),vec2(100),20.46875,100.0,7.0",false,"unresolved tile"],
		["vec2(1.5,0.56),vec2(0.14),20.46875,8000.0,7.0",false,"distant tile"],
		["vec2(1.5,0.56),vec2(0.14),20.375,100.0,2.0",false,"wall remains exact"],
		["vec2(1.5,0.56),vec2(0.14),20.0078125,100.0,13.0",false,"glass remains exact"]]
	for row:Array in cases:
		var shader:=Shader.new();shader.code=prefix+"void fragment(){vec2 g=tactical_form_gradient("+str(row[0])+");COLOR=vec4(vec3(0.5)+vec3(g/(vec2(1.0)+abs(g))*0.4,0.0),1.0);}"
		material.shader=shader
		var colour:Color=(await capture()).get_pixel(8,8)
		var difference:float=Vector2(colour.r-0.5,colour.g-0.5).length()
		check(difference>0.007 if row[1] else difference<0.007,str(row[2])+": intended macrorelief scope")
	for pair:Array in [["vec2(0.0715,0)","vec2(1.0715,0)","vec2(0.02)",20.125,1.0],["vec2(-0.5,0.0001)","vec2(-0.5,-0.0001)","vec2(0.01)",20.25,1.0]]:
		var shader:=Shader.new();shader.code=prefix+"void fragment(){vec2 a=tactical_form_gradient(%s,%s,%f,100.0,%f);vec2 b=tactical_form_gradient(%s,%s,%f,100.0,%f);COLOR=vec4(vec3(0.5)+vec3(a-b,0.0)/64.0,1.0);}"%[pair[0],pair[2],pair[3],pair[4],pair[1],pair[2],pair[3],pair[4]]
		material.shader=shader
		var colour:Color=(await capture()).get_pixel(8,8)
		check(Vector3(colour.r,colour.g,colour.b).distance_to(Vector3.ONE*0.5)<0.007,"track period or polar wrap continuous")
	# Combine texture and form derivatives before the existing family cap once.
	var shader:=Shader.new();shader.code=prefix+"void fragment(){vec2 form=vec2(80,40);vec2 atlas=vec2(70,20);vec2 h=form+atlas;vec3 n=tactical_relief_normal(vec3(0,0,1),vec2(1,0),vec3(1,0,0),vec3(0,1,0),vec2(h.x,0),vec2(h.y,0),7.0);COLOR=vec4(n*0.5+0.5,1.0);}"
	material.shader=shader
	var colour:Color=(await capture()).get_pixel(8,8);var normal:=Vector3(colour.r,colour.g,colour.b)*2.0-Vector3.ONE
	check(is_finite(normal.x) and normal.z>0.97 and Vector2(normal.x,normal.y).length()/normal.z<0.232,"combined texture/form relief retains one roof slope cap")
	for failure:String in failures:printerr("FAIL: "+failure)
	print("PC_TACTICAL_BEVEL_GPU: %d checks, %d errors"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func naturalism_materials(catalog:Dictionary,baseline_path:String) -> void:
	var old:=Shader.new()
	var lighting:bool="--lighting-materials" in OS.get_cmdline_user_args()
	var horizon:bool="--horizon-materials" in OS.get_cmdline_user_args()
	var grounding:bool="--grounding-materials" in OS.get_cmdline_user_args()
	var arbor:bool="--arbor-materials" in OS.get_cmdline_user_args()
	var microfinish:bool="--microfinish-materials" in OS.get_cmdline_user_args()
	var aerial:bool="--aerial-materials" in OS.get_cmdline_user_args()
	var bevel:bool="--bevel-materials" in OS.get_cmdline_user_args()
	var sheen:bool="--sheen-materials" in OS.get_cmdline_user_args()
	var radiance:bool="--radiance-materials" in OS.get_cmdline_user_args()
	var finishgrain:bool="--finishgrain-materials" in OS.get_cmdline_user_args()
	var diffusion:bool="--diffusion-materials" in OS.get_cmdline_user_args()
	var groundlight:bool="--groundlight-materials" in OS.get_cmdline_user_args() or diffusion or finishgrain
	var optics:bool="--optics-materials" in OS.get_cmdline_user_args()
	# Preserve the production shader's injected painter/depth setup as well as
	# its source code. Only the shared material include differs in this pair.
	if lighting or horizon or grounding or arbor or microfinish or aerial or bevel or sheen or radiance or optics or groundlight:
		old.code=FileAccess.get_file_as_string(baseline_path).replace("depth_test_disabled, depth_draw_never", "depth_draw_opaque").replace("void fragment() {", "void fragment() {\n    DEPTH = UV.y > 19.5 && UV.y < 21.5 ? FRAGCOORD.z : 0.0;\n    if (UV.y > 20.04 && UV.y < 20.08) DEPTH = 0.5 + min(UV2.x,1024.0)/4096.0;")
	else:old.code=draw._modern_shader.code.replace("#include \"res://scripts/pc_tactical_materials.gdshaderinc\"",FileAccess.get_file_as_string(baseline_path))
	check(art.material_atlas!=null,"naturalism uses the verified existing atlas")
	var preceding_variant:Shader
	if diffusion or finishgrain:
		preceding_variant=Shader.new()
		preceding_variant.code=FileAccess.get_file_as_string("res://tests/finishgrain-before-variant.gdshader" if finishgrain else "res://tests/diffusion-before-variant.gdshader").replace("depth_test_disabled, depth_draw_never", "depth_draw_opaque").replace("void fragment() {", "void fragment() {\n    DEPTH = UV.y > 19.5 && UV.y < 21.5 ? FRAGCOORD.z : 0.0;\n    if (UV.y > 20.04 && UV.y < 20.08) DEPTH = 0.5 + min(UV2.x,1024.0)/4096.0;")
	var specs:Array=[[2,"meadow",true],[4,"soil",true],[49,"asphalt",true],[159,"truck",true],[147,"masonry",true],[157,"timber",true],[161,"crew",true],[103,"tree",true]]
	if lighting:specs=[[115,"t62",true],[129,"m113",true],[159,"truck",true],[147,"building",true],[157,"timber",true],[163,"hind",true],[40,"river",true],[40,"river-grazing",true],[49,"asphalt",false],[2,"meadow",false],[4,"soil",false],[103,"tree",false],[161,"crew",false],[-1,"sky",true]]
	if horizon:specs=[[115,"t62",false],[129,"m113",false],[159,"truck",false],[147,"building",false],[157,"timber",false],[163,"hind",false],[40,"river",false],[40,"river-grazing",false],[49,"asphalt",false],[2,"meadow",false],[4,"soil",false],[103,"tree",false],[161,"crew",false],[-1,"sky",true],[-1,"sky-wrap",true],[-1,"sky-compact",true]]
	if grounding:specs=[[2,"meadow",true],[2,"meadow-oblique",true],[4,"soil",true],[4,"soil-angle",true],[49,"asphalt",true],[49,"asphalt-grazing",true],[-1,"sky-ground",true],[115,"t62",false],[40,"river",false],[103,"tree",false],[161,"crew",false]]
	if arbor:specs=[[103,"tree-lit",true],[103,"tree-backlit",true],[103,"tree-compact",true],[103,"tree-overlap",true],[-1,"sky",false],[49,"asphalt",false],[115,"t62",false],[161,"crew",false]]
	if microfinish:specs=[[115,"t62",true],[129,"m113",true],[159,"truck",true],[163,"hind",true],[147,"building",true],[157,"farm",true],[147,"building-oblique",true],[147,"building-overlap",true],[40,"river",false],[49,"asphalt",false],[103,"tree",false],[161,"crew",false],[-1,"sky",false]]
	if aerial:specs=[[2,"meadow",true],[4,"soil",true],[49,"asphalt",true],[40,"river",true],[115,"t62",true],[159,"truck",true],[147,"building",true],[103,"tree",true],[-1,"sky-ground",true],[147,"building-overlap",true],[115,"t62-near",false],[161,"crew",false],[-1,"unclassified-source",false]]
	if bevel:specs=[[115,"t62-gear",true],[129,"m113-gear",true],[137,"btr70-gear",true],[159,"truck-no-wheel-tags",false],[147,"flat-roof",true],[151,"pitched-roof",true],[157,"farm-roof",true],[147,"roof-overlap",true],[147,"roof-distant",false],[40,"river",false],[49,"asphalt",false],[103,"tree",false],[161,"crew",false],[-1,"sky",false]]
	if optics:specs=[[40,"river",true],[40,"river-grazing",true],[40,"river-distant",true],[40,"river-compact",true],[159,"truck",true],[159,"truck-front",true],[163,"hind",true],[163,"hind-front",true],[147,"building-oblique",true],[147,"building-overlap",true],[157,"farm-glass",true],[115,"t62",false],[49,"asphalt",false],[2,"meadow",false],[103,"tree",false],[161,"crew",false],[-1,"sky",false]]
	if groundlight:specs=[[2,"meadow",true],[2,"meadow-oblique",true],[4,"soil",true],[4,"soil-angle",true],[49,"asphalt",true],[49,"asphalt-grazing",true],[49,"asphalt-compact",true],[-1,"sky-ground",true],[115,"t62",false],[40,"river",false],[103,"tree",false],[161,"crew",false],[-1,"unclassified-source",false]]
	if diffusion:specs=[[115,"t62",true],[129,"m113",true],[159,"truck",true],[163,"hind",true],[147,"building-oblique",true],[147,"building-overlap",true],[151,"roof",true],[157,"farm-roof",true],[2,"meadow",true],[2,"meadow-oblique",true],[4,"soil",true],[4,"soil-angle",true],[49,"asphalt",true],[49,"asphalt-grazing",true],[49,"asphalt-compact",true],[-1,"sky-ground",true],[40,"river",false],[103,"tree",false],[161,"crew",false],[-1,"unclassified-source",false]]
	if finishgrain:specs=[[115,"t62",true],[129,"m113",true],[159,"truck",true],[163,"hind",true],[147,"building-oblique",true],[147,"building-overlap",true],[151,"roof",true],[157,"farm-roof",true],[2,"meadow",false],[2,"meadow-oblique",false],[4,"soil",false],[4,"soil-angle",false],[49,"asphalt",false],[49,"asphalt-grazing",false],[49,"asphalt-compact",false],[-1,"sky-ground",false],[40,"river",false],[103,"tree",false],[161,"crew",false],[-1,"unclassified-source",false]]
	if sheen:specs=[[115,"t62",true],[129,"m113",true],[159,"truck",true],[163,"hind",true],[151,"pitched-roof",true],[157,"farm-roof",true],[147,"building-oblique",true],[147,"building-overlap",true],[115,"t62-distant",false],[40,"river",false],[49,"asphalt",false],[103,"tree",false],[161,"crew",false],[-1,"sky",false]]
	if radiance:specs=[[2,"meadow",true],[4,"soil",true],[49,"asphalt",true],[40,"river",true],[115,"t62",true],[129,"m113",true],[159,"truck",true],[163,"hind",true],[147,"building",true],[151,"roof",true],[103,"tree-lit",true],[103,"tree-backlit",true],[103,"tree-overlap",true],[-1,"sky",true],[-1,"sky-wrap",true],[-1,"sky-opposite",true],[-1,"sky-compact",true],[161,"crew",false],[-1,"unclassified-source",false]]
	if horizon and "--horizon-occlusion-only" in OS.get_cmdline_user_args():specs=[[-1,"sky-overlap",true]]
	if groundlight and "--groundlight-debug" in OS.get_cmdline_user_args():specs=[[2,"meadow",true]]
	for spec:Array in specs:
		var sky_case:bool=str(spec[1]).begins_with("sky")
		var data:=model_packet(catalog,int(spec[0]),-0.16 if spec[1]=="river-grazing" else -0.6,PI-0.4 if spec[1] in ["truck","hind","building-oblique"] else 0.4,0.55 if (bevel and "roof" in str(spec[1])) or ((sheen or radiance) and ("roof" in str(spec[1]) or str(spec[1]).begins_with("building"))) else 0.0) if int(spec[0])>=0 else packet()
		if bevel and str(spec[1]).ends_with("-gear"):
			data.objects[0].dynamic_instance=true;data.objects[0].static_path=false;data.objects[0].pointer=1234
			data.world={"dynamic":[{"pointer":1234,"shape_index":int(spec[0]),"world_position_raw":[100,200,0]}]}
		if bevel and spec[1]=="roof-distant":
			for polygon:Dictionary in data.objects[0].polygons:
				for point:Array in polygon.camera_vertices:point[1]+=16000.0
		if optics and spec[1]=="river-distant":
			for polygon:Dictionary in data.objects[0].polygons:
				for point:Array in polygon.camera_vertices:point[1]+=5000.0
		if sheen and spec[1]=="t62-distant":
			for polygon:Dictionary in data.objects[0].polygons:
				for point:Array in polygon.camera_vertices:point[1]+=16000.0
		if grounding or aerial or radiance or groundlight:
			# Captured PC terrain words, matching the established terrain studies.
			for index:int in [17,19,26,28]:data.materials[index]={17:[0x0700,0x0007],19:[0x0800,0x0008],26:[0x0703,0x0307],28:[0x0803,0x0308]}[index]
			if int(spec[0])==2:data=model_packet(catalog,2,-0.6,0.4,-0.6);data.materials[19]=[0x0800,0x0008];data.materials[28]=[0x0803,0x0308]
		if sky_case:
			data.camera.world_position_raw=[0,0,50]
			data.background={"kind":"horizon","line":[[0,100],[319,100]],"colors":[5,8]}
			data.objects[0].shape_index=-1
			data.objects[0].polygons[0].colors=[9,9]
			data.objects[0].polygons[0].camera_vertices=[[-15,160,25],[15,160,25],[15,160,45],[-15,160,45]]
			if spec[1]=="sky-overlap":
				# Put opaque source geometry across the actual changed horizon band.
				data.objects[0].polygons[0].camera_vertices=[[-15,160,-4],[15,160,-4],[15,160,20],[-15,160,20]]
		if int(spec[0]) in [2,4,49,157]:
			var nearest:float=INF
			for polygon:Dictionary in data.objects[0].polygons:
				for point:Array in polygon.camera_vertices:nearest=minf(nearest,float(point[1]))
			for polygon:Dictionary in data.objects[0].polygons:
				for point:Array in polygon.camera_vertices:point[1]-=nearest-420.0
		if aerial and int(spec[0])>=0 and spec[2]:
			var nearest:float=INF
			for polygon:Dictionary in data.objects[0].polygons:
				for point:Array in polygon.camera_vertices:nearest=minf(nearest,float(point[1]))
			for polygon:Dictionary in data.objects[0].polygons:
				for point:Array in polygon.camera_vertices:point[1]+=1800.0-nearest
		if aerial and spec[1]=="t62-near":
			var bound:Dictionary=catalog.models[115].source_bounds
			var dimension:Vector3=Modern.vec(bound.max)-Modern.vec(bound.min)
			var offset:float=maxf(160.0,maxf(dimension.x,maxf(dimension.y,dimension.z))*1.7)-300.0
			for polygon:Dictionary in data.objects[0].polygons:
				for point:Array in polygon.camera_vertices:point[1]-=offset
		if (grounding or groundlight) and spec[1] in ["meadow-oblique","soil-angle","asphalt-grazing"]:
			# Exercise actual classified terrain facets at a second view angle.
			var rotation:=Basis(Vector3(0,0,1),0.7) if spec[1]=="soil-angle" else Basis(Vector3.RIGHT,0.35)
			for polygon:Dictionary in data.objects[0].polygons:
				for index:int in polygon.camera_vertices.size():
					var v:Array=polygon.camera_vertices[index]
					var point:Vector3=rotation*Vector3(float(v[0]),float(v[1])-420.0,float(v[2]))
					polygon.camera_vertices[index]=[point.x,point.y+420.0,point.z]
		if (grounding or aerial or groundlight) and sky_case:
			# The original opaque source actor overlaps the changed ground.
			data.objects[0].polygons[0].camera_vertices=[[-15,160,-45],[15,160,-45],[15,160,-25],[-15,160,-25]]
		if radiance and sky_case:
			data.background={"kind":"horizon","line":[[0,100],[319,100]],"colors":[5,8]}
			data.objects[0].shape_index=-1
		if ((arbor or radiance) and spec[1]=="tree-overlap") or ((microfinish or aerial or sheen or optics or groundlight) and spec[1]=="building-overlap") or (bevel and spec[1]=="roof-overlap"):
			var blocker:Dictionary=packet().objects[0].duplicate(true)
			blocker.shape_index=-1;blocker.polygons[0].colors=[9,9]
			blocker.polygons[0].camera_vertices=[[-20,160,-30],[20,160,-30],[20,160,30],[-20,160,30]]
			if aerial:blocker.polygons[0].camera_vertices=[[-3,160,-4],[3,160,-4],[3,160,4],[-3,160,4]]
			data.objects.append(blocker)
		data=JSON.parse_string(JSON.stringify(data))
		var source:=JSON.stringify(data)
		draw.tactical_landscape=false
		var modern:=await render(data,true)
		var material:ShaderMaterial=draw.mesh_node.mesh.surface_get_material(0)
		if (horizon or radiance) and spec[1]=="sky-compact":
			viewport.size=Vector2i(640,400);draw.apply_pass(data)
			material=draw.mesh_node.mesh.surface_get_material(0)
		if (horizon or radiance) and spec[1]=="sky-wrap":
			material.set_shader_parameter("camera_to_local",Basis(Vector3(0,0,1),PI)*material.get_shader_parameter("camera_to_local"))
		if (optics and spec[1]=="river-compact") or (groundlight and spec[1]=="asphalt-compact"):
			viewport.size=Vector2i(640,400);draw.apply_pass(data)
			material=draw.mesh_node.mesh.surface_get_material(0)
			# The mode-preservation baseline must use this compact viewport too.
			modern=await capture()
		if arbor and spec[1]=="tree-compact":
			viewport.size=Vector2i(320,200);draw.apply_pass(data)
			material=draw.mesh_node.mesh.surface_get_material(0)
		if (arbor or radiance) and int(spec[0])==103:
			material.set_shader_parameter("source_horizon_line",Vector3(0,1,-100))
		if (arbor or radiance) and spec[1]=="tree-backlit":
			var forward:=Vector3(-0.58,-0.34,0.74).normalized()
			var right:=forward.cross(Vector3(0,0,1)).normalized()
			material.set_shader_parameter("camera_to_local",Basis(right,forward,right.cross(forward)))
		if arbor:modern=await capture()
		if horizon:modern=await capture()
		if radiance and spec[1]=="sky-opposite":material.set_shader_parameter("camera_to_local",Basis(Vector3(0,0,1),PI))
		if radiance:modern=await capture()
		if sheen and not sky_case:
			# Inspect existing facets from the sunward viewing direction. The old
			# low, backlit pose contains almost no resolved reflected highlight.
			var forward:=Vector3(0.58,0.34,-0.74).normalized()
			var right:=forward.cross(Vector3(0,0,1)).normalized()
			var basis:=Basis(right,forward,right.cross(forward))
			if spec[1]=="t62":
				var eye:=-Vector3(forward.x,-forward.y,forward.z)
				check(absf(basis.determinant()-1.0)<0.0001 and absf(right.dot(forward))<0.0001 and eye.dot(Vector3(-0.58,0.34,0.74).normalized())>0.9999,"sunward study basis includes shader source-Y inversion and is orthonormal")
			material.set_shader_parameter("camera_to_local",basis)
			modern=await capture()
		var current:Shader=draw._groundlight_shader if groundlight else material.shader
		if (lighting or microfinish or aerial or bevel or sheen or radiance or optics or groundlight) and not sky_case:
			# Isolated material studies keep a black background for coverage checks;
			# explicitly supply the production marker for verified daylight.
			material.set_shader_parameter("source_horizon_line",Vector3(0,1,-100))
		var geometry:PackedVector3Array=draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
		if aerial and spec[1]=="t62-near":
			var farthest:=0.0;var model_vertices:=0
			var tags:PackedVector2Array=draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
			for index in geometry.size():
				var kind:float=fmod(tags[index].y,32.0)
				if floori(tags[index].y/32.0)!=1 or not ((kind>19.5 and kind<21.5) or (kind>=24.0 and kind<28.0)):continue
				model_vertices+=1;farthest=maxf(farthest,geometry[index].length()*64.0)
			print("AERIAL_NEAR_MODEL_VERTICES: %d, farthest raw distance %.3f"%[model_vertices,farthest])
			check(model_vertices>0 and farthest<=600.0,"near fixture rendered model vertices stay within the exact-colour boundary")
		material.shader=old
		check((await capture()).get_data()==modern.get_data(),str(spec[1])+": preceding Modernized is exact")
		draw.tactical_landscape=true
		if groundlight:material.shader=preceding_variant if diffusion or finishgrain else old
		var before:=await capture()
		material.shader=current
		if groundlight:
			draw.refresh_surface_shader(material)
			check(material.shader==current,str(spec[1])+": verified Tactical frame selects terrain variant")
		var after:=await capture()
		var changed:=0;var coverage:=0;var escaped:=0;var occluder_changes:=0
		var owners:Image=draw.ownership.get_texture().get_image() if ((arbor or radiance) and int(spec[0])==103) or ((microfinish or aerial or bevel or sheen or radiance or optics or groundlight) and not sky_case) else null
		for y in after.get_height():
			for x in after.get_width():
				var a:=before.get_pixel(x,y);var b:=after.get_pixel(x,y)
				if a!=b:
					changed+=1
					if owners!=null:
						var owner:Color=owners.get_pixel(x,y)
						var id:int=roundi(owner.r*255.0)+256*roundi(owner.g*255.0)
						if id!=1:escaped+=1
						if id==2:occluder_changes+=1
				if (a==Color.BLACK)!=(b==Color.BLACK) or a.a!=b.a:coverage+=1
		# Sheen admission is area-independent: low-peak material and oblique
		# probes can change fewer than 100 pixels. Separate large-area examples
		# retain the strong visibility criterion; every preservation check stays.
		check(changed>(0 if sheen or optics or groundlight else 100) if spec[2] else changed==0,str(spec[1])+": intended production lighting scope")
		if sheen and spec[1] in ["t62","m113","truck","pitched-roof","farm-roof"]:
			check(changed>100,str(spec[1])+": representative visible sheen demonstration")
		if microfinish or aerial or bevel or sheen or radiance or optics or groundlight:
			check(coverage==0,str(spec[1])+": exact original coverage")
			check(escaped==0,str(spec[1])+": relief stays inside original model ownership")
			check(occluder_changes==0,str(spec[1])+": overlapping opaque actor remains exact")
		elif (arbor or radiance) and int(spec[0])==103:
			check(escaped==0,str(spec[1])+": tree changes stay inside original source ownership")
			check(occluder_changes==0,str(spec[1])+": overlapping opaque actor remains exact")
		else:check(coverage==0,str(spec[1])+": exact original coverage")
		if optics or groundlight:
			var mask_shader:=Shader.new()
			var mask_code:=current.code
			var end:int=mask_code.rfind("}")
			var eligible_code:="((UV.y>0.5&&UV.y<3.5)||(UV.y>6.5&&UV.y<9.5))" if groundlight else "((UV.y>13.5&&UV.y<14.5)||(UV.y>20.006&&UV.y<20.010))"
			if diffusion:eligible_code="(((UV.y>19.5&&UV.y<20.51)&&!(UV.y>20.04&&UV.y<20.08)&&family>0.5&&family<7.5)||(((UV.y>0.5&&UV.y<3.5)||(UV.y>6.5&&UV.y<9.5))&&((family>7.5&&family<8.5)||(family>9.5&&family<11.5))))"
			if finishgrain:eligible_code="((UV.y>19.5&&UV.y<20.51)&&!(UV.y>20.04&&UV.y<20.08)&&family>0.5&&family<7.5)"
			mask_shader.code=mask_code.substr(0,end)+"ALBEDO=vec3("+eligible_code+"?1.0:0.0);\n"+mask_code.substr(end)
			material.shader=mask_shader
			var mask:=await capture();var outside_optics:=0;var admitted:=0
			for y in after.get_height():
				for x in after.get_width():
					var eligible:bool=mask.get_pixel(x,y).r>0.5
					if eligible:admitted+=1
					if before.get_pixel(x,y)!=after.get_pixel(x,y) and not eligible:outside_optics+=1
			check(outside_optics==0,str(spec[1])+": only admitted original material facets change")
			check(admitted>0 if spec[2] else true,str(spec[1])+": positive study contains real eligible facets")
			material.shader=current
			check((await capture()).get_data()==after.get_data(),str(spec[1])+": facet diagnostic restores exact production render")
		check((await capture()).get_data()==after.get_data(),str(spec[1])+": stable between original frames")
		var canvas_changed:=0;var canvas_mask_pixels:=0;var canvas_escaped:=0
		if sheen and spec[1]=="truck":
			# Isolate the gain cue on existing family-5 facets only. Atlas colour,
			# normals, other families and geometry stay identical to the candidate.
			var neutral:=Shader.new()
			neutral.code=current.code.replace(",finish_sample.x);",",family==5.0 ? 1.0 : finish_sample.x);")
			material.shader=neutral;var without:Image=await capture()
			var mask_shader:=Shader.new()
			mask_shader.code=current.code.insert(current.code.rfind("}"),"\n    ALBEDO=vec3(family==5.0 ? 1.0 : 0.0);\n")
			material.shader=mask_shader;var family_mask:Image=await capture()
			for y in after.get_height():
				for x in after.get_width():
					var admitted:bool=family_mask.get_pixel(x,y).r>0.5
					if admitted:canvas_mask_pixels+=1
					if after.get_pixel(x,y)!=without.get_pixel(x,y):
						canvas_changed+=1
						if not admitted:canvas_escaped+=1
			check(canvas_mask_pixels>100 and canvas_changed>0 and canvas_escaped==0,"truck: actual canvas gain cue changes only visible canvas facets")
			material.shader=current
			check((await capture()).get_data()==after.get_data(),"truck: family-isolated study restores exact candidate")
		if bevel and str(spec[1]).ends_with("-gear"):
			check(draw.modern_running_gear_triangles>0,str(spec[1])+": actual admitted wheel/track triangles")
			data.world.dynamic[0].world_position_raw[0]+=5
			draw.apply_pass(data)
			draw.mesh_node.mesh.surface_get_material(0).set_shader_parameter("source_horizon_line",Vector3(0,1,-100))
			check((await capture()).get_data()!=after.get_data(),str(spec[1])+": original source-position phase changes the moving marks")
			data.world.dynamic[0].world_position_raw[0]-=5
			draw.apply_pass(data)
			draw.mesh_node.mesh.surface_get_material(0).set_shader_parameter("source_horizon_line",Vector3(0,1,-100))
			check((await capture()).get_data()==after.get_data(),str(spec[1])+": source phase restore is exact")
			material=draw.mesh_node.mesh.surface_get_material(0)
			material.set_shader_parameter("source_horizon_line",Vector3(0,1,-100))

		if (grounding or aerial or groundlight) and sky_case:
			check(after.get_region(Rect2i(0,0,viewport.size.x,viewport.size.y/2)).get_data()==before.get_region(Rect2i(0,0,viewport.size.x,viewport.size.y/2)).get_data(),"ground pass leaves all sky and woodland exact")
			var box:=Rect2(Vector2(1e9,1e9),Vector2.ZERO)
			for point:Array in data.objects[0].polygons[0].camera_vertices:
				var pixel:Vector2=Geometry.project(point,data.camera)*Vector2(viewport.size)/Vector2(320,200)
				box=Rect2(pixel,Vector2.ZERO) if box.position.x==1e9 else box.expand(pixel)
			var interior:=Rect2i(box.grow(-2.0))
			check(interior.has_area() and after.get_region(interior).get_data()==before.get_region(interior).get_data(),"filtered ground cannot change any overlapping source-actor interior")
		if horizon and sky_case:
			var source_horizon:int=viewport.size.y/2
			var band_top:int=floori((100.0-0.14*float(data.camera.focal_pixels))*float(viewport.size.y)/200.0)-2
			check(after.get_region(Rect2i(0,0,viewport.size.x,band_top)).get_data()==before.get_region(Rect2i(0,0,viewport.size.x,band_top)).get_data(),str(spec[1])+": upper sky and clouds exact")
			check(after.get_region(Rect2i(0,source_horizon+1,viewport.size.x,viewport.size.y-source_horizon-1)).get_data()==before.get_region(Rect2i(0,source_horizon+1,viewport.size.x,viewport.size.y-source_horizon-1)).get_data(),str(spec[1])+": original ground exact")
			var actor_at:=Vector2i(viewport.size.x/2,roundi(viewport.size.y*(0.45 if spec[1]=="sky-overlap" else 0.275)))
			check(after.get_pixelv(actor_at)==before.get_pixelv(actor_at),str(spec[1])+": original actor exact")
			if spec[1]=="sky-overlap":
				var box:=Rect2(Vector2(1e9,1e9),Vector2.ZERO)
				for point:Array in data.objects[0].polygons[0].camera_vertices:
					var pixel:Vector2=preload("res://scripts/pc_surface_geometry.gd").project(point,data.camera)*Vector2(viewport.size)/Vector2(320,200)
					box=Rect2(pixel,Vector2.ZERO) if box.position.x==1e9 else box.expand(pixel)
				var interior:=Rect2i(box.grow(-2.0))
				check(interior.has_area() and after.get_region(interior).get_data()==before.get_region(interior).get_data(),"woodland cannot change any opaque source-actor interior")
			var basis:Basis=material.get_shader_parameter("camera_to_local")
			material.set_shader_parameter("camera_to_local",Basis(Vector3(0,0,1),0.4)*basis)
			var band:=Rect2i(0,band_top,viewport.size.x,source_horizon-band_top)
			check((await capture()).get_region(band).get_data()!=after.get_region(band).get_data(),str(spec[1])+": woodland remains world-angular")
			material.set_shader_parameter("camera_to_local",basis)
			check((await capture()).get_data()==after.get_data(),str(spec[1])+": angular restore exact")
		if (lighting or microfinish or aerial or bevel or sheen or radiance or optics or groundlight) and not sky_case:
			material.set_shader_parameter("source_horizon_line",Vector3.ZERO)
			var unlit_before:Image=before
			if microfinish or aerial or bevel or sheen or radiance or optics or groundlight:
				material.shader=old
				unlit_before=await capture()
				material.shader=current
			if groundlight and spec[1]=="meadow" and "--groundlight-debug" in OS.get_cmdline_user_args():
				var old_copy:=Shader.new();old_copy.code=old.code;material.shader=old_copy
				var same_old:Image=await capture()
				check(same_old.get_data()==unlit_before.get_data(),"meadow diagnostic: old-to-old program swap is exact")
				JavaScriptBridge.eval("window.materialImages=window.materialImages||{};window.materialImages[\"old-repeat\"]="+JSON.stringify([Marshalls.raw_to_base64(unlit_before.save_png_to_buffer()),Marshalls.raw_to_base64(same_old.save_png_to_buffer())]))
				var failed_shader:=Shader.new()
				failed_shader.code=FileAccess.get_file_as_string("res://tests/groundlight-first-failed.gdshader").replace("depth_test_disabled, depth_draw_never", "depth_draw_opaque").replace("void fragment() {", "void fragment() {\n    DEPTH = UV.y > 19.5 && UV.y < 21.5 ? FRAGCOORD.z : 0.0;\n    if (UV.y > 20.04 && UV.y < 20.08) DEPTH = 0.5 + min(UV2.x,1024.0)/4096.0;")
				material.shader=failed_shader
				var failed_frame:Image=await capture()
				JavaScriptBridge.eval("window.materialImages[\"failed-unlit\"]="+JSON.stringify([Marshalls.raw_to_base64(unlit_before.save_png_to_buffer()),Marshalls.raw_to_base64(failed_frame.save_png_to_buffer())]))
				material.shader=current
			if groundlight:
				draw.refresh_surface_shader(material)
				check(material.shader==draw._modern_shader,str(spec[1])+": unverified light selects exact incumbent program")
			var unlit_after:Image=await capture()
			if groundlight and spec[1]=="meadow" and OS.has_feature("web"):JavaScriptBridge.eval("window.materialImages=window.materialImages||{};window.materialImages[\"unlit\"]="+JSON.stringify([Marshalls.raw_to_base64(unlit_before.save_png_to_buffer()),Marshalls.raw_to_base64(unlit_after.save_png_to_buffer())]))
			check(unlit_after.get_data()==unlit_before.get_data(),str(spec[1])+": thermal/unverified daylight retains preceding materials")
			material.set_shader_parameter("source_horizon_line",Vector3(0,1,-100))
			if groundlight:draw.refresh_surface_shader(material)
			check((await capture()).get_data()==after.get_data(),str(spec[1])+": verified daylight restore exact")
		if ((microfinish or sheen) and spec[1] in ["t62","building"]) or (optics and spec[1] in ["river","truck"]) or (groundlight and spec[1] in ["meadow","soil","asphalt"]):
			material.set_shader_parameter("tactical_realism_ready",false)
			material.shader=old
			var missing_before:Image=await capture()
			material.shader=current
			if groundlight:
				draw.refresh_surface_shader(material)
				check(material.shader==draw._modern_shader,str(spec[1])+": missing atlas selects exact incumbent program")
			var missing_after:Image=await capture()
			if groundlight and spec[1]=="meadow" and OS.has_feature("web"):JavaScriptBridge.eval("window.materialImages=window.materialImages||{};window.materialImages[\"missing\"]="+JSON.stringify([Marshalls.raw_to_base64(missing_before.save_png_to_buffer()),Marshalls.raw_to_base64(missing_after.save_png_to_buffer())]))
			check(missing_after.get_data()==missing_before.get_data(),str(spec[1])+": unavailable atlas retains preceding finish")
			material.set_shader_parameter("tactical_realism_ready",true)
			if groundlight:draw.refresh_surface_shader(material)
			check((await capture()).get_data()==after.get_data(),str(spec[1])+": restored atlas is exact")
		if groundlight and spec[1] in ["meadow","soil","asphalt"]:
			for control:String in ["modern_surface_variation","modern_environment_polish"]:
				material.set_shader_parameter(control,false);material.shader=old
				var control_before:Image=await capture();material.shader=current
				draw.refresh_surface_shader(material)
				check(material.shader==draw._modern_shader,str(spec[1])+": disabled control selects exact incumbent program")
				var control_after:Image=await capture()
				if spec[1]=="meadow" and OS.has_feature("web"):JavaScriptBridge.eval("window.materialImages=window.materialImages||{};window.materialImages["+JSON.stringify(control)+"]="+JSON.stringify([Marshalls.raw_to_base64(control_before.save_png_to_buffer()),Marshalls.raw_to_base64(control_after.save_png_to_buffer())]))
				check(control_after.get_data()==control_before.get_data(),str(spec[1])+": "+control+" off keeps preceding render")
				material.set_shader_parameter(control,true)
				draw.refresh_surface_shader(material)
				check((await capture()).get_data()==after.get_data(),str(spec[1])+": "+control+" restore exact")
			var detail_before:float=material.get_shader_parameter("detail_levels")
			material.set_shader_parameter("detail_levels",1.0);material.shader=old
			var simple_before:Image=await capture();material.shader=current
			draw.refresh_surface_shader(material)
			check(material.shader==draw._modern_shader,str(spec[1])+": detail-off selects exact incumbent program")
			check((await capture()).get_data()==simple_before.get_data(),str(spec[1])+": detail-off keeps preceding render")
			material.set_shader_parameter("detail_levels",detail_before)
			draw.refresh_surface_shader(material)
			check((await capture()).get_data()==after.get_data(),str(spec[1])+": detail restore exact")
		check(JSON.stringify(data)==source and draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==geometry,str(spec[1])+": original packet and geometry unchanged")
		if int(spec[0]) in [2,4,49]:
			var origin:Vector3=material.get_shader_parameter("world_origin")
			material.set_shader_parameter("world_origin",origin+Vector3(571,347,0))
			check((await capture()).get_data()!=after.get_data(),str(spec[1])+": grain anchored to observed world position")
			material.set_shader_parameter("world_origin",origin)
			check((await capture()).get_data()==after.get_data(),str(spec[1])+": source-coordinate restore exact")
		if (lighting or radiance) and spec[1]=="sky":
			check(after.get_pixel(640,220)==before.get_pixel(640,220),"cloud light cannot change the original actor")
			if not radiance:check(after.get_pixel(500,600)==before.get_pixel(500,600),"cloud light cannot change original ground")
			var region:=Rect2i(0,0,1280,170)
			var basis:Basis=material.get_shader_parameter("camera_to_local")
			material.set_shader_parameter("camera_to_local",Basis(Vector3(0,0,1),0.4)*basis)
			check((await capture()).get_region(region).get_data()!=after.get_region(region).get_data(),"cloud light follows the observed world view")
			material.set_shader_parameter("camera_to_local",basis)
			check((await capture()).get_data()==after.get_data(),"cloud orientation restore exact")
		draw.tactical_landscape=false
		check((await capture()).get_data()==modern.get_data(),str(spec[1])+": Modernized switchback exact")
		if groundlight and spec[1] in ["meadow","soil","asphalt"]:
			check(material.shader==draw._modern_shader,str(spec[1])+": Modernized selects original compiled program")
			var builds:int=draw.mesh_build_count
			draw.tactical_landscape=true
			check(material.shader==current and (await capture()).get_data()==after.get_data(),str(spec[1])+": mode-only Tactical return restores candidate")
			check(draw.mesh_build_count==builds,str(spec[1])+": shader switch does not rebuild source geometry")
			check(material.get_shader_parameter("tactical_realism_atlas")==art.material_atlas,str(spec[1])+": shader switch retains atlas binding")
			if spec[1]=="meadow":
				material.set_shader_parameter("modern_environment_polish",false)
				draw.apply_pass(data)
				check(draw.mesh_build_count==builds and material.shader==draw._modern_shader,"cached frame synchronizes admission-off without geometry rebuild")
				material.set_shader_parameter("modern_environment_polish",true)
				draw.apply_pass(data)
				check(draw.mesh_build_count==builds and material.shader==current and (await capture()).get_data()==after.get_data(),"cached frame restores Tactical program and pixels")
			draw.tactical_landscape=false

		if groundlight and spec[1]=="sky-ground":
			draw.clear_mesh_cache()
			draw.tactical_landscape=true
			draw.apply_pass(data)
			var fresh:ShaderMaterial=draw.mesh_node.mesh.surface_get_material(0)
			check(fresh.shader==current,"new verified Tactical frame immediately selects terrain program")
			check((await capture()).get_data()==after.get_data(),"new Tactical material preserves accepted pixels")
			check(draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==geometry,"new Tactical material retains source geometry")
			draw.tactical_landscape=false

		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.materialImages=window.materialImages||{};window.materialImages["+JSON.stringify(str(spec[1]))+"]="+JSON.stringify([Marshalls.raw_to_base64(before.save_png_to_buffer()),Marshalls.raw_to_base64(after.save_png_to_buffer())]))
		rows.append({"case":spec[1],"changed_pixels":changed,"coverage_changes":coverage,"outside_tree_owner":escaped,"outside_model_owner":escaped if microfinish or aerial or bevel or sheen or radiance or optics or groundlight else 0,"occluder_changes":occluder_changes,"canvas_gain_only_pixels":canvas_changed,"canvas_mask_pixels":canvas_mask_pixels,"canvas_gain_escaped":canvas_escaped})
	for failure:String in failures:printerr("FAIL: "+failure)
	print(("PC_TACTICAL_FINISHGRAIN_MATERIALS" if finishgrain else "PC_TACTICAL_DIFFUSION_MATERIALS" if diffusion else "PC_TACTICAL_GROUNDLIGHT_MATERIALS" if groundlight else "PC_TACTICAL_OPTICS_MATERIALS" if optics else "PC_TACTICAL_RADIANCE_MATERIALS" if radiance else "PC_TACTICAL_SHEEN_MATERIALS" if sheen else "PC_TACTICAL_BEVEL_MATERIALS" if bevel else "PC_TACTICAL_AERIAL_MATERIALS" if aerial else "PC_TACTICAL_MICROFINISH_MATERIALS" if microfinish else "PC_TACTICAL_ARBOR_MATERIALS" if arbor else "PC_TACTICAL_GROUNDING_MATERIALS" if grounding else "PC_TACTICAL_HORIZON_MATERIALS" if horizon else "PC_TACTICAL_LIGHTING_MATERIALS" if lighting else "PC_TACTICAL_NATURALISM_MATERIALS")+": %d checks, %d errors"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	if "--finishgrain-gpu" in OS.get_cmdline_user_args():
		await finishgrain_gpu_contract()
		return
	if "--diffusion-gpu" in OS.get_cmdline_user_args():
		await diffusion_gpu_contract()
		return
	if "--groundlight-gpu" in OS.get_cmdline_user_args():
		await groundlight_gpu_contract()
		return
	if "--optics-gpu" in OS.get_cmdline_user_args():
		await optics_gpu_contract()
		return
	if "--radiance-gpu" in OS.get_cmdline_user_args():
		await radiance_gpu_contract()
		return
	if "--sheen-gpu" in OS.get_cmdline_user_args():
		await lighting_gpu_contract()
		return
	if "--bevel-gpu" in OS.get_cmdline_user_args():
		await bevel_gpu_contract()
		return
	if "--aerial-gpu" in OS.get_cmdline_user_args():
		await aerial_gpu_contract()
		return
	if "--microfinish-gpu" in OS.get_cmdline_user_args():
		await microfinish_gpu_contract()
		return
	if "--arbor-gpu" in OS.get_cmdline_user_args():
		await arbor_gpu_contract()
		return
	if "--grounding-gpu" in OS.get_cmdline_user_args():
		await grounding_gpu_contract()
		return
	if "--horizon-gpu" in OS.get_cmdline_user_args():
		await horizon_gpu_contract()
		return
	if "--lighting-gpu" in OS.get_cmdline_user_args():
		await lighting_gpu_contract()
		return
	if "--anisotropic-footprint" in OS.get_cmdline_user_args() or "--naturalism-gpu" in OS.get_cmdline_user_args():
		await anisotropic_footprint_contract()
		return
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
	if "--finishgrain-materials" in args:
		await naturalism_materials(catalog,args[args.find("--finishgrain-materials")+1])
		return
	if "--diffusion-materials" in args:
		await naturalism_materials(catalog,args[args.find("--diffusion-materials")+1])
		return
	if "--groundlight-materials" in args:
		await naturalism_materials(catalog,args[args.find("--groundlight-materials")+1])
		return
	if "--optics-materials" in args:
		await naturalism_materials(catalog,args[args.find("--optics-materials")+1])
		return
	if "--radiance-materials" in args:
		await naturalism_materials(catalog,args[args.find("--radiance-materials")+1])
		return
	if "--sheen-materials" in args:
		await naturalism_materials(catalog,args[args.find("--sheen-materials")+1])
		return
	if "--bevel-materials" in args:
		await naturalism_materials(catalog,args[args.find("--bevel-materials")+1])
		return
	if "--aerial-materials" in args:
		await naturalism_materials(catalog,args[args.find("--aerial-materials")+1])
		return
	if "--microfinish-materials" in args:
		await naturalism_materials(catalog,args[args.find("--microfinish-materials")+1])
		return
	if "--arbor-materials" in args:
		await naturalism_materials(catalog,args[args.find("--arbor-materials")+1])
		return
	if "--grounding-materials" in args:
		await naturalism_materials(catalog,args[args.find("--grounding-materials")+1])
		return
	if "--horizon-materials" in args:
		await naturalism_materials(catalog,args[args.find("--horizon-materials")+1])
		return
	if "--lighting-materials" in args:
		await naturalism_materials(catalog,args[args.find("--lighting-materials")+1])
		return
	if "--naturalism-materials" in args:
		await naturalism_materials(catalog,args[args.find("--naturalism-materials")+1])
		return
	if "--tactical-materials" in args:
		await tactical_materials(catalog,args[args.find("--tactical-materials")+1])
		return
	var data:=packet()
	data.camera.world_position_raw=[0,0,50]
	data.background={"kind":"horizon","line":[[0,100],[319,100]],"colors":[5,8]}
	data.objects[0].shape_index=-1
	data.objects[0].polygons[0].colors=[9,9]
	data.objects[0].polygons[0].camera_vertices=[[-15,160,25],[15,160,25],[15,160,45],[-15,160,45]]
	# Match the JSON transport, whose numeric arrays differ from GDScript literals.
	data=JSON.parse_string(JSON.stringify(data))
	await study(data,"sky",true)
	var modern:Image=await render(data,true)
	var vertices:PackedVector3Array=draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
	draw.tactical_landscape=true
	var tactical:Image=await capture()
	check(tactical.get_pixel(100,40)!=modern.get_pixel(100,40),"Tactical: Range sky differs from Modern")
	check(tactical.get_pixel(500,600)!=modern.get_pixel(500,600),"Tactical: Range ground differs from Modern")
	var grove_pixels:=0
	for y in range(370,400):
		for x in range(0,500):
			if tactical.get_pixel(x,y).g<modern.get_pixel(x,y).g*0.7: grove_pixels+=1
	check(grove_pixels>100,"Tactical: distant vegetation is visible in source sky")
	var hedge_pixels:=0;var bark_pixels:=0
	for x in range(0,500):
		var colour:=tactical.get_pixel(x,398)
		if colour.g<0.55 && colour.g>colour.b*1.1: hedge_pixels+=1
	for y in range(350,400):
		for x in range(0,500):
			var colour:=tactical.get_pixel(x,y)
			if colour.r>colour.g*1.08 && colour.b<colour.g*0.85: bark_pixels+=1
	check(hedge_pixels>350,"Tactical: hedgerows meet the source horizon across the field")
	check(bark_pixels>40,"Tactical: distant tree stems retain visible bark")
	check(tactical.get_pixel(640,220)==modern.get_pixel(640,220),"Tactical: source actor unchanged")
	check(draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==vertices,"Tactical: source geometry unchanged")
	tactical.save_png(output.path_join("tactical-range.png"))
	draw.tactical_landscape=false
	check((await capture()).get_data()==modern.get_data(),"Tactical: Modern restores exactly")
	await study(model_packet(catalog,40),"water",true)
	await study(model_packet(catalog,103),"tree",true)
	var tree_data:=model_packet(catalog,103)
	var modern_tree:=await render(tree_data,true)
	var tree_vertices:PackedVector3Array=draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
	draw.tactical_landscape=true
	var tactical_tree:=await capture()
	var owners:Image=draw.ownership.get_texture().get_image()
	var recovered:=0;var escaped:=0
	for y in tactical_tree.get_height():
		for x in tactical_tree.get_width():
			if modern_tree.get_pixel(x,y)==Color.BLACK && tactical_tree.get_pixel(x,y)!=Color.BLACK:
				recovered+=1
				var owner:=owners.get_pixel(x,y)
				if owner.r+owner.g==0.0:escaped+=1
	check(recovered>100,"Tactical: original trunk coverage survives texture alpha")
	check(escaped==0,"Tactical: recovered trunks remain inside original ownership")
	check(draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==tree_vertices,"Tactical: tree geometry unchanged")
	tactical_tree.save_png(output.path_join("tactical-tree.png"))
	draw.tactical_landscape=false
	check((await capture()).get_data()==modern_tree.get_data(),"Tactical: Modern tree restores exactly")
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
