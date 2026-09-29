extends SceneTree
## Native-only offline authoring contact sheets. Runtime ownership is tested separately.
var started := Time.get_ticks_msec()
var output := ""

func _initialize() -> void:
	call_deferred("render")

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec()-started>180000:
		printerr("MODEL_PREVIEW: deadline exceeded")
		quit(2)
	return false

func render() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("MODEL_PREVIEW: a native renderer is required")
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	var paths: Array[String] = []
	for key in ["--before","--after"]:
		var i := args.find(key)
		if i<0 or i+1>=args.size():
			quit(2)
			return
		paths.append(args[i+1])
	var oi := args.find("--output")
	if oi<0 or oi+1>=args.size():
		quit(2)
		return
	output=args[oi+1]
	DirAccess.make_dir_recursive_absolute(output)
	var original_comparison := "--original-comparison" in args
	var all_shapes := "--all-shapes" in args
	var selected:PackedStringArray=args[args.find("--shapes")+1].split(",") if "--shapes" in args else PackedStringArray()
	var catalogs: Array = []
	for path in paths:
		var catalog=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not catalog is Dictionary or not catalog.get("models") is Array:
			printerr("MODEL_PREVIEW: invalid catalogue: "+path);quit(2);return
		catalogs.append(catalog)
	var vp := SubViewport.new()
	vp.size=Vector2i(700,480)
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	vp.own_world_3d=true
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("252c30")
	vp.add_child(env)
	var title := Label.new()
	title.position=Vector2(22,18)
	title.add_theme_font_size_override("font_size",22)
	vp.add_child(title)
	var camera := Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	cam_setup(camera,vp)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo=true
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	# Offline original meshes contain intentional coplanar overlaps. A tiny
	# source-order raster bias removes depth fighting without editing vertices.
	var original_mat:=ShaderMaterial.new()
	var original_shader:=Shader.new()
	original_shader.code="shader_type spatial; render_mode unshaded,cull_disabled; void vertex(){POSITION=PROJECTION_MATRIX*MODELVIEW_MATRIX*vec4(VERTEX,1.0);POSITION.z-=UV.x*0.0000005*POSITION.w;} void fragment(){ALBEDO=COLOR.rgb;}"
	original_mat.shader=original_shader
	var tree_mat := StandardMaterial3D.new()
	tree_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	tree_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	tree_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	tree_mat.alpha_scissor_threshold=0.85
	var tree_path:=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("local-art/pc-modern/tree.png")
	if FileAccess.file_exists(tree_path):
		var tree_image:=Image.load_from_file(tree_path)
		tree_image.generate_mipmaps()
		tree_mat.albedo_texture=ImageTexture.create_from_image(tree_image)
	var empty_label:=Label.new()
	empty_label.position=Vector2(22,210)
	empty_label.add_theme_font_size_override("font_size",20)
	vp.add_child(empty_label)
	var count := 0
	var page := Image.create(1600,1100,false,Image.FORMAT_RGBA8) if original_comparison else Image.create(1050,960,false,Image.FORMAT_RGBA8)
	var indices: Array = []
	for model: Dictionary in catalogs[1].models:
		if not selected.is_empty() and str(int(model.shape_index)) not in selected:continue
		if all_shapes or model.status in ["authored_mesh","conservative_refinement","partial_opaque"] and not model.triangles.is_empty():
			indices.append(int(model.shape_index))
	for index in indices:
		var sheet := Image.create(1400,960,false,Image.FORMAT_RGBA8)
		var pair := Image.create(1400,480,false,Image.FORMAT_RGBA8)
		for column in range(2):
			var model: Dictionary=catalogs[column].models[index]
			# Use the production livery function for offline model studies, so
			# previews cannot silently retain the catalogue's olive base paint.
			var paint_source:String=FileAccess.get_file_as_string(args[args.find("--before-shader")+1]) if column==0 and "--before-shader" in args else preload("res://scripts/pc_surface.gdshader").code
			var hind:bool=index in [163,164] and not (original_comparison and column==0)
			var armour:bool=model.get("paint_style","")=="two_tone_olive" and not (original_comparison and column==0)
			var livery:bool=hind or armour
			var hind_mat:=ShaderMaterial.new()
			var hind_palette:=preload("res://scripts/pc_modern_assets.gd").new()
			if livery:
				if not hind_palette.configure(catalogs[column]):quit(2);return
				var paint_shader:=Shader.new()
				var helpers:=paint_source.substr(paint_source.find("float ground_hash("),paint_source.find("void vertex()")-paint_source.find("float ground_hash("))
				# Use the actual production colour texture, avoiding vertex-colour
				# transfer differences between Compatibility and Forward renderers.
				var paint_expression:="hind_livery(c,UV2,fwidth(UV2))" if "vec3 hind_livery(" in paint_source else "c"
				if armour:paint_expression="armour_livery(c,UV2,fwidth(UV2))" if "vec3 armour_livery(" in paint_source else "c"
				paint_shader.code="shader_type spatial; render_mode unshaded,cull_disabled; uniform sampler2D colours:source_color,filter_nearest,repeat_disable;uniform float colour_count;\n"+helpers+"void fragment(){vec3 c=texture(colours,vec2((UV.x+0.5)/colour_count,0.5)).rgb;ALBEDO=UV.y>0.5 ? "+paint_expression+" : c;}"
				hind_mat.shader=paint_shader
				hind_mat.set_shader_parameter("colours",hind_palette.colour_texture)
				hind_mat.set_shader_parameter("colour_count",float(hind_palette.colour_indices.size()))
			var meshes: Array[MeshInstance3D] = []
			var crew:bool=index in [161,162]
			var crew_mat:=ShaderMaterial.new()
			var crew_shader:=Shader.new()
			crew_shader.code="shader_type spatial; render_mode unshaded,cull_disabled; void fragment(){ALBEDO=COLOR.rgb; DEPTH=0.5+UV.x/4096.0;}"
			crew_mat.shader=crew_shader
			var textured_tree:bool=original_comparison and column==1 and index==103 and tree_mat.albedo_texture!=null
			for lines in [false,true]:
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_LINES if lines else Mesh.PRIMITIVE_TRIANGLES)
				var records: Array=model.source_lines if lines else model.triangles
				if records.is_empty(): continue
				for tri: Dictionary in records:
					var rgb:Array=tri.get("color",[52,60,45])
					if lines and not tri.has("color") and tri.get("prefix_bytes",[])==[255,6,6]:
						rgb=preload("res://scripts/pc_modern_assets.gd").DAY_PALETTE[6]
					st.set_color(Color(rgb[0]/255.0,rgb[1]/255.0,rgb[2]/255.0))
					var rank:float=float(tri.get("source_rank",0))
					if crew:
						for pi in model.source_primitives.size():
							if int(model.source_primitives[pi].id)==int(tri.get("source_primitive",-1)):rank=pi+1;break
					st.set_uv(Vector2(rank,0))
					if livery and not lines:st.set_uv(Vector2(hind_palette.colour_indices[hind_palette.colour_key(rgb)],1.0 if tri.get("material","") in ["olive","olive_edge"] else 0.0))
					var vs: Array=tri.vertices
					if lines:
						for i in range(vs.size()-1):
							st.add_vertex(point(vs[i])); st.add_vertex(point(vs[i+1]))
					else:
						for v: Array in vs:
							if hind:st.set_uv2(Vector2(float(v[1]),float(v[2])))
							elif armour:st.set_uv2(Vector2(float(v[1])+float(v[0])*.45,float(v[2])+float(v[0])*.25))
							if textured_tree:
								var horizontal:float=v[0] if int(tri.source_primitive) in [10549,10541] else v[1]
								var crown:bool=int(tri.source_primitive) in [10549,10564]
								st.set_uv(Vector2(horizontal/320.0+0.5,lerpf(0.805,0.005,(float(v[2])-128.0)/352.0) if crown else lerpf(0.995,0.805,float(v[2])/128.0)))
							st.add_vertex(point(v))
				var mesh := MeshInstance3D.new()
				mesh.mesh=st.commit()
				mesh.material_override=hind_mat if livery and not lines else crew_mat if crew and not lines else original_mat if original_comparison and column==0 else tree_mat if textured_tree and not lines else mat
				vp.add_child(mesh)
				meshes.append(mesh)
			var visible_model:bool=model.source_bounds is Dictionary and model.status!="source_control_invisible"
			var heads:Array[MeshInstance3D]=[]
			# The crew heads are source round commands, absent from polygon GLBs.
			# Offline authoring uses a camera-facing approximation of that command;
			# runtime tests separately require the exact original CPU span coverage.
			if crew and (original_comparison or int(catalogs[column].get("authoring_revision",0))>=8):
				for command:Dictionary in model.get("visual_commands",[]):
					if int(command.radius_raw)!=15:continue
					var head:=MeshInstance3D.new()
					var hs:=SurfaceTool.new();hs.begin(Mesh.PRIMITIVE_TRIANGLES)
					for segment in 48:
						for angle in [-1.0,float(segment)*TAU/48,float(segment+1)*TAU/48]:
							var p:=Vector2.ZERO if angle<0 else Vector2(cos(angle),sin(angle))
							hs.set_uv2(Vector2(p.x,-p.y));hs.add_vertex(Vector3(p.x*18.0,p.y*15.0,0)/64.0)
					head.mesh=hs.commit()
					var hm:=ShaderMaterial.new();var hshader:=Shader.new()
					var modern_head:bool=not (original_comparison and column==0)
					var helpers:=paint_source.substr(paint_source.find("float ground_hash("),paint_source.find("void vertex()")-paint_source.find("float ground_hash("))
					hshader.code="shader_type spatial;render_mode unshaded,cull_disabled;"+helpers+"void fragment(){ALBEDO="+("crew_head_paint(UV2)" if modern_head else "vec3(0.0,0.666667,0.0)")+";DEPTH=0.5;}"
					hm.shader=hshader;head.material_override=hm
					head.position=point(command.center_raw);vp.add_child(head)
					heads.append(head);meshes.append(head)
			var lo:=point(model.source_bounds.min) if visible_model else Vector3(-1,-1,-1)
			var hi:=point(model.source_bounds.max) if visible_model else Vector3(1,1,1)
			empty_label.text="No standalone polygon mesh" if model.triangles.is_empty() else ""
			if model.status=="source_control_invisible":empty_label.text="Invisible source-control marker"
			for mesh in meshes:mesh.visible=visible_model
			var target: Vector3=(lo+hi)*.5
			var span:=maxf(lo.distance_to(hi),0.1)
			camera.size=span*1.04
			if original_comparison:
				camera.near=span*0.001;camera.far=span*6.0
			for row in range(2):
				camera.position=target+Vector3(1.5,.95,-1.8 if row==0 else 1.8).normalized()*span*2
				camera.look_at(target)
				for head in heads:head.basis=camera.basis
				var label:String=("ORIGINAL PC" if column==0 else "MODERN") if original_comparison else ("BEFORE" if column==0 else "AFTER")
				title.text=label+" / "+str(model.get("comparison_name",model.name))+" / #"+str(index)+(" / FRONT" if row==0 else " / REAR")
				await process_frame
				RenderingServer.force_draw(false)
				RenderingServer.force_sync()
				var picture := vp.get_texture().get_image()
				sheet.blit_rect(picture,Rect2i(Vector2i.ZERO,vp.size),Vector2i(column*700,row*480))
				if row==0:pair.blit_rect(picture,Rect2i(Vector2i.ZERO,vp.size),Vector2i(column*700,0))
				if not original_comparison and column==1 and row==0:
					picture.resize(350,240,Image.INTERPOLATE_LANCZOS)
					page.blit_rect(picture,Rect2i(0,0,350,240),Vector2i((count%3)*350,((count%12)/3)*240))
			for mesh in meshes: mesh.free()
		if sheet.save_png(output.path_join("model-%03d.png"%index))!=OK:
			quit(1)
			return
		if original_comparison:
			if pair.save_png(output.path_join("pair-%03d.png"%index))!=OK:quit(1);return
			pair.resize(800,275,Image.INTERPOLATE_LANCZOS)
			page.blit_rect(pair,Rect2i(0,0,800,275),Vector2i((count%2)*800,((count%8)/2)*275))
		count+=1
		var per_page:=8 if original_comparison else 12
		if count%per_page==0 or count==indices.size():
			if page.save_png(output.path_join("roster-%02d.png"%ceili(float(count)/per_page)))!=OK:
				quit(1)
				return
			page.fill(Color("252c30"))
	print("MODEL_PREVIEW: PASS; %d native before/after contact sheets"%count)
	quit(0)

func point(v: Array) -> Vector3:
	return Vector3(v[0],v[2],-v[1])/64.0

func cam_setup(camera: Camera3D, vp: SubViewport) -> void:
	vp.add_child(camera)
	camera.current=true
