extends "res://tests/test_pc_modern.gd"
## Native material studies using original model faces, not a gameplay route.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("FAIL: model studies require native rendering");quit(2);return
	directory=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args:=OS.get_cmdline_user_args()
	var ruin_pass:bool="--ruins-bases-baseline" in args
	var remodelled:=[146,148,150,152,153,154,155,156,158]
	if "--changed-shapes" in args:
		remodelled=[]
		for value:String in args[args.find("--changed-shapes")+1].split(","):remodelled.append(int(value))
	output=args[args.find("--output")+1] if "--output" in args else directory.path_join("artifacts/modern-environment")
	DirAccess.make_dir_recursive_absolute(output)
	viewport=SubViewport.new()
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	camera=Camera3D.new();viewport.add_child(camera);camera.make_current()
	draw=Draw.new();draw.solid_enabled=true;draw.modern_assets=art;camera.add_child(draw)
	check(draw.load_modern_assets(directory),"production models loaded")
	draw.terrain_style=preload("res://scripts/pc_terrain_style.gd").new()
	check(draw.terrain_style.load_assets(directory.path_join("local-art/pc-terrain-remastered/detail-v1")),"pinned detail textures loaded")
	check(draw.terrain_style.load_hills(directory),"pinned hill texture loaded")
	var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("local-art/pc-modern/catalog.json")))
	var baseline_art=Modern.new()
	var baseline_shader:=Shader.new()
	var baseline_legacy:=Shader.new()
	if "--baseline-catalog" in args:
		check(baseline_art.configure(JSON.parse_string(FileAccess.get_file_as_string(args[args.find("--baseline-catalog")+1]))),"baseline catalogue loaded")
		baseline_art.load_tree(directory)
		baseline_legacy.code=FileAccess.get_file_as_string(args[args.find("--baseline-shader")+1])
		baseline_shader.code=baseline_legacy.code.replace("depth_test_disabled, depth_draw_never","depth_draw_opaque").replace("void fragment() {","void fragment() {\n DEPTH = UV.y > 19.5 && UV.y < 21.5 ? FRAGCOORD.z : 0.0;\n if (UV.y > 20.04 && UV.y < 20.08) DEPTH = 0.5 + min(UV2.x,1024.0)/4096.0;")
	var rows:=[]
	var first_hind:=PackedByteArray()
	var specs:=[[2,"hill",7200.0],[4,"earth-hill",7200.0],[40,"water",6400.0],[48,"grass",6400.0],[49,"road",6400.0],[157,"farm-yard",700.0],[157,"farm-yard-distant",1200.0]]
	for model:Dictionary in catalog.models:
		if model.status in ["authored_mesh","conservative_refinement","partial_opaque"] and not model.triangles.is_empty():
			specs.append([int(model.shape_index),"model-%03d"%int(model.shape_index),160.0])
	check(specs.size()==64,"all 57 authored definitions plus grass/earth hills, water, grass, road and near/far farm yard are studied")
	for spec in specs:
		var model:Dictionary=catalog.models.filter(func(m):return int(m.shape_index)==spec[0])[0]
		var data:=packet()
		# Observed PC material words, rather than the synthetic i%16 palette
		# used by packet(). In particular, hill material 28 is not orange 12.
		for index in [17,19,26,28]:
			data.materials[index]={17:[0x0700,0x0007],19:[0x0800,0x0008],26:[0x0703,0x0307],28:[0x0803,0x0308]}[index]
		data.background={"kind":"solid","color":5}
		var object:Dictionary={"shape_index":spec[0],"root":int(model.roots[0].offset),"static_path":true,"dynamic_instance":false,"polygons":[]}
		var bounds:Dictionary=model.source_bounds if spec[0] in Modern.BRIDGE_SHAPES else model.bounds
		var center:Vector3=(Modern.vec(bounds.min)+Modern.vec(bounds.max))*0.5
		var dimensions:Vector3=Modern.vec(bounds.max)-Modern.vec(bounds.min)
		var depth:float=maxf(float(spec[2]),maxf(dimensions.x,maxf(dimensions.y,dimensions.z))*1.7)
		var pivot:float=center.z
		var rotation:=Basis(Vector3.RIGHT,0.25)*Basis(Vector3(0,0,1),2.65)
		if spec[1]=="water":rotation=Basis(Vector3.RIGHT,-0.6)
		if spec[1]=="farm-yard":
			depth=float(spec[2])
			rotation=Basis(Vector3.RIGHT,-0.65)*Basis(Vector3(0,0,1),2.65)
		var selected:={}
		for group:Dictionary in model.groups:
			if group.offset in model.roots[0].group_pointers:
				for pid in group.primitive_pointers:selected[int(pid)]=true
		for primitive:Dictionary in model.source_primitives:
			if primitive.vertices.size()<2 or primitive.vertices.size()==2 and spec[0] not in Modern.BRIDGE_SHAPES or int(primitive.id) not in selected:continue
			if str(spec[1]).begins_with("farm-yard") and int(primitive.id)!=28751:continue
			var points:=[]
			for raw:Array in primitive.vertices:
				var p:=rotation*(Modern.vec(raw)-center)
				points.append([p.x,p.y+depth,p.z])
			var colors:Array=primitive.prefix_bytes
			object.polygons.append({"primitive":int(primitive.id),"fill_mode":1 if points.size()>=3 else 0,"colors":[int(colors[1]),int(colors[2])],"camera_vertices":points})
		object.polygons.sort_custom(func(a,b):return Modern.vec(a.camera_vertices[0]).y>Modern.vec(b.camera_vertices[0]).y)
		data.objects=[object]
		data.camera.world_position_raw=[0,0,pivot]
		var styled:=await render(data,true)
		var modern_polygons:int=draw.modern_polygon_count
		var geometry:PackedVector3Array=draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
		var material:ShaderMaterial=draw.mesh_node.mesh.surface_get_material(0)
		material.set_shader_parameter("modern_surface_variation",false)
		await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
		var plain:=viewport.get_texture().get_image()
		material.set_shader_parameter("modern_surface_variation",true)
		await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
		var restored:=viewport.get_texture().get_image()
		var changed:=0
		var clay:=0
		var grass:=0
		var red:=0;var glazing:=0
		for y in styled.get_height():
			for x in styled.get_width():
				if styled.get_pixel(x,y)!=plain.get_pixel(x,y):changed+=1
				var c:=styled.get_pixel(x,y)
				if c.r>0.6 and c.r>c.g*3.0 and c.r>c.b*4.0:red+=1
				if c.b>0.4 and c.b>c.g*1.06 and c.g>c.r*1.2:glazing+=1
				if spec[0]==157:
					var p:=plain.get_pixel(x,y)
					if p.r>0.3 and p.r>p.g*1.35 and p.g>p.b*1.5:clay+=1
					if p.g>0.3 and p.g>p.r*1.5 and p.g>p.b*1.7:grass+=1
		if spec[0]==115:check(red>40,"T-62 original red flag is visibly restored")
		if spec[0] in Modern.BRIDGE_SHAPES and "--baseline-catalog" in args:
			var steel:=0
			for y in styled.get_height():
				for x in styled.get_width():
					if styled.get_pixel(x,y) in [Color8(133,157,171),Color8(101,127,140)]:steel+=1
			check(steel>20,"actual JSON catalogue bridge framework has visible calibrated steel colours: "+spec[1])
		if spec[0] in [147,149,159,163,164]:check(glazing>40,"blue-grey glazing remains visible: "+spec[1])
		if spec[0]==157 and not str(spec[1]).begins_with("farm-yard"):
			check(clay>1000,"farm roof retains warm clay with surface variation disabled")
			check(grass>1000,"farm courtyard retains green with surface variation disabled")
		check(styled.get_data()==restored.get_data(),"surface toggle restores exact pixels: "+spec[1])
		check(geometry==draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"surface detail preserves geometry: "+spec[1])
		var treated:bool=spec[0] in [0,1,45,46,47,108,114,145,147,149,151,153,155,157,2,4,40,48,49] and spec[1]!="farm-yard-distant"
		check(changed>0 if treated else changed==0,"surface treatment scope: "+spec[1])
		if spec[0] not in [2,4,40,48,49]:
			check(draw.modern_polygon_count>0,"refined model bound to runtime: "+spec[1])
			check(art.max_anchor_error<=0.25,"source anchors preserved: "+spec[1])
		if spec[1] in ["hill","earth-hill","grass","farm-yard","farm-yard-distant"]:
			var old_field=material.get_shader_parameter("field_detail")
			var old_hill=material.get_shader_parameter("hill_detail")
			var sentinel:=Image.create(4,4,false,Image.FORMAT_RGB8)
			sentinel.fill(Color.WHITE)
			var texture:=ImageTexture.create_from_image(sentinel)
			material.set_shader_parameter("field_detail",texture)
			material.set_shader_parameter("hill_detail",texture)
			await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
			check(viewport.get_texture().get_image().get_data()==styled.get_data(),"Modern grain ignores grass/hill image maps: "+spec[1])
			material.set_shader_parameter("field_detail",old_field)
			material.set_shader_parameter("hill_detail",old_hill)
			var origin:Vector3=material.get_shader_parameter("world_origin")
			material.set_shader_parameter("world_origin",origin+Vector3(137,83,0))
			await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
			var moved:=viewport.get_texture().get_image().get_data()
			if spec[1]=="farm-yard-distant":check(moved==styled.get_data(),"distant yard grain fades out without aliasing")
			else:check(moved!=styled.get_data(),"grain follows source coordinates: "+spec[1])
			material.set_shader_parameter("world_origin",origin)
			await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
			check(viewport.get_texture().get_image().get_data()==styled.get_data(),"source-coordinate restore restores grain exactly: "+spec[1])
		# Optional immutable earlier shader gives matched visual comparisons and
		# byte-exact scope checks without modifying any production resource.
		var hind_evidence:={}
		if "--baseline-catalog" not in args and "--baseline-shader" in args and ("--hind-livery-baseline" in args or spec[0] in [2,4,40,48,49,115,157]):
			var current:Shader=material.shader
			var earlier:=Shader.new()
			earlier.code=FileAccess.get_file_as_string(args[args.find("--baseline-shader")+1]).replace("depth_test_disabled, depth_draw_never","depth_draw_opaque").replace("void fragment() {","void fragment() {\n DEPTH = UV.y > 19.5 && UV.y < 21.5 ? FRAGCOORD.z : 0.0;\n if (UV.y > 20.04 && UV.y < 20.08) DEPTH = 0.5 + min(UV2.x,1024.0)/4096.0;")
			material.shader=earlier
			await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
			var before:=viewport.get_texture().get_image()
			before.save_png(output.path_join(spec[1]+"-before.png"))
			if "--hind-livery-baseline" in args:
				if spec[0] not in [163,164]:
					check(before.get_data()==styled.get_data(),"Hind shader leaves other model/terrain pixels unchanged: "+spec[1])
				else:
					var green:=0;var grey:=0;var blue:=0;var repainted:=0;var escaped:=0;var altered_details:=0;var clipped_white:=0
					for y in styled.get_height():
						for x in styled.get_width():
							var old:=before.get_pixel(x,y);var fresh:=styled.get_pixel(x,y)
							if old==fresh:continue
							repainted+=1
							if minf(fresh.r,minf(fresh.g,fresh.b))>0.95:clipped_white+=1
							if old==before.get_pixel(0,0):escaped+=1
							if old.b>old.g*1.06 and old.g>old.r*1.2 or old.r>old.g*3.0:altered_details+=1
							if fresh.g>fresh.r*1.06 and fresh.r>fresh.b*1.18:green+=1
							if fresh.g>fresh.r and fresh.g<fresh.r*1.1 and fresh.r>fresh.b and fresh.b>0.35:grey+=1
							if fresh.r<fresh.g*0.6 and fresh.b>fresh.g*1.08:blue+=1
					check(green>1000 and grey>1000 and blue>1000 and clipped_white==0,"Hind visibly has olive/grey patches and a blue underside without washed-out white: "+spec[1])
					check(escaped==0 and altered_details==0,"Hind paint preserves silhouette, glass and red accents: "+spec[1])
					if first_hind.is_empty():first_hind=styled.get_data()
					else:check(first_hind==styled.get_data(),"both Hind rotor states retain exactly matching body paint")
					hind_evidence={"repainted":repainted,"green":green,"grey":grey,"blue":blue,"outside_model":escaped,"altered_glass_or_red":altered_details,"clipped_white":clipped_white}
			if spec[0] in [40,49,115]:check(before.get_data()==styled.get_data(),"terrain shader leaves road, water and vehicle pixels unchanged: "+spec[1])
			if "--hill-colour-baseline" in args:
				if spec[0]==4:check(before.get_data()==styled.get_data(),"earth hill colours unchanged")
				if spec[0]==2:
					var lifted:=0;var unwanted:=0
					for y in styled.get_height():
						for x in styled.get_width():
							var old:=before.get_pixel(x,y);var fresh:=styled.get_pixel(x,y)
							if old==fresh:continue
							lifted+=1
							if fresh.g<=old.g or fresh.g<fresh.r*1.15:unwanted+=1
					check(lifted>1000 and unwanted==0,"only grass hill pixels lift towards green")
			material.shader=current
			if "--hind-livery-baseline" in args and spec[0] in [163,164]:
				var old_origin:Vector3=material.get_shader_parameter("world_origin")
				material.set_shader_parameter("world_origin",Vector3(30000,-30000,1500))
				await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
				check(styled.get_data()==viewport.get_texture().get_image().get_data(),"Hind paint is object-local under a world-origin rebase")
				material.set_shader_parameter("world_origin",old_origin)
				var legacy:=await render(data,false)
				var legacy_material:ShaderMaterial=draw.mesh_node.mesh.surface_get_material(0)
				var legacy_current:Shader=legacy_material.shader
				var legacy_before:=Shader.new()
				legacy_before.code=FileAccess.get_file_as_string(args[args.find("--baseline-shader")+1])
				legacy_material.shader=legacy_before
				await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
				check(legacy.get_data()==viewport.get_texture().get_image().get_data(),"legacy Hind pixels are unchanged")
				legacy_material.shader=legacy_current
		var highlight_evidence:={}
		if "--baseline-catalog" in args:
			var current_shader:Shader=draw._modern_shader
			draw.modern_assets=baseline_art;draw._modern_shader=baseline_shader;draw.clear_mesh_cache()
			var before:=await render(data,true)
			var same_geometry:bool=geometry==draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			check(not same_geometry if ruin_pass and spec[0] in remodelled else same_geometry,"geometry changes restricted to approved ruin/base models: "+spec[1])
			before.save_png(output.path_join(spec[1]+"-before.png"))
			draw.modern_assets=art;draw._modern_shader=current_shader;draw.clear_mesh_cache()
			var repaint:=0;var escaped:=0;var clipped_white:=0
			for y in styled.get_height():
				for x in styled.get_width():
					var a:=before.get_pixel(x,y);var b:=styled.get_pixel(x,y)
					if a==b:continue
					repaint+=1
					if a==before.get_pixel(0,0):escaped+=1
					if minf(b.r,minf(b.g,b.b))>0.95:clipped_white+=1
			var untouched:bool=spec[0] not in remodelled if ruin_pass else spec[0] in [2,4,40,48,49,123,163,164] or str(spec[1]).begins_with("farm-yard")
			check(repaint==0 if untouched else repaint>0,"highlight scope visible and selective: "+spec[1])
			check((escaped==0 or ruin_pass and spec[0] in remodelled) and clipped_white==0,"highlights preserve coverage and restrained brightness: "+spec[1])
			var restored_highlight:=await render(data,true)
			check(restored_highlight.get_data()==styled.get_data(),"highlight catalogue restore is byte-exact: "+spec[1])
			if ruin_pass and spec[0] in remodelled:
				var owner:Image=draw.ownership.get_texture().get_image()
				var escaped_source:=0
				for y in styled.get_height():
					for x in styled.get_width():
						if styled.get_pixel(x,y)!=styled.get_pixel(0,0) and owner.get_pixel(x,y).r<0.001:escaped_source+=1
				check(escaped_source==0,"ruins/insignia stay within original source coverage: "+spec[1])
			if spec[0] in Modern.TWO_TONE_SHAPES:
				var current_material:ShaderMaterial=draw.mesh_node.mesh.surface_get_material(0)
				current_material.set_shader_parameter("world_origin",Vector3(30000,-30000,800))
				await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
				check(viewport.get_texture().get_image().get_data()==styled.get_data(),"APC/truck paint cannot slide during world-origin rebase: "+spec[1])
			var legacy:=await render(data,false)
			var legacy_material:ShaderMaterial=draw.mesh_node.mesh.surface_get_material(0)
			var current_legacy:Shader=legacy_material.shader
			legacy_material.shader=baseline_legacy
			await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
			check(viewport.get_texture().get_image().get_data()==legacy.get_data(),"all legacy mode pixels unchanged: "+spec[1])
			legacy_material.shader=current_legacy
			highlight_evidence={"repainted":repaint,"outside_model":escaped,"clipped_white":clipped_white,"unchanged":untouched}
		styled.save_png(output.path_join(spec[1]+"-detail.png"))
		plain.save_png(output.path_join(spec[1]+"-plain.png"))
		rows.append({"name":spec[1],"changed_pixels":changed,"source_shape":spec[0],"modern_polygons":modern_polygons,"max_anchor_error":art.max_anchor_error,"root":object.root,"hind_livery":hind_evidence,"highlights":highlight_evidence})
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":failures,"cases":rows,"scope":"Presentation-only model studies, original local faces repositioned for inspection. Actual mission frames are tested separately."},"  "))
	for error in failures:printerr("FAIL: "+error)
	print("PC_MODERN_ENVIRONMENT: %d checks, %d errors"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
