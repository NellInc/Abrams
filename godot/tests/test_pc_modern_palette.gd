extends "res://tests/test_pc_modern_environment_polish.gd"
## Historical palette comparison with matched metadata transport/tree filtering.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=="headless":printerr("FAIL: palette tests need native GPU");quit(2);return
	directory=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args:=OS.get_cmdline_user_args()
	output=args[args.find("--output")+1] if "--output" in args else directory.path_join("artifacts/modern-palette-balance-20260929/world")
	DirAccess.make_dir_recursive_absolute(output)
	viewport=SubViewport.new();viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	camera=Camera3D.new();viewport.add_child(camera);camera.make_current()
	draw=Draw.new();draw.solid_enabled=true;draw.modern_assets=art;camera.add_child(draw)
	draw.tactical_landscape=false
	check(draw.load_modern_assets(directory),"production models loaded")
	draw.terrain_style=preload("res://scripts/pc_terrain_style.gd").new()
	check(draw.terrain_style.load_assets(directory.path_join("local-art/pc-terrain-remastered/detail-v1")),"terrain loaded")
	check(draw.terrain_style.load_hills(directory),"hills loaded")
	var catalog:Dictionary=art.load_catalogue(directory)
	var baseline_path:=directory.path_join("artifacts/modern-palette-balance-20260929/before/godot/scripts/pc_surface.gdshader")
	var old_code:=FileAccess.get_file_as_string(baseline_path)
	# Decode today's material transport into the historical fragment kinds.
	# Keep every historical colour expression and the alpha cutoff unchanged.
	var kind_decode := """
    if (UV.y==20.01171875 || UV.y==20.3125) UV.y=20.0;
    else if (UV.y==20.3828125 || UV.y==20.34375 || UV.y==20.390625 || UV.y==20.359375) UV.y=20.375;
    else if (UV.y==20.4140625 || UV.y==20.421875) UV.y=20.4375;
    if (UV.y>=24.0 && UV.y<28.0) {
        float basis=floor(UV.y-24.0);
        UV.y=basis<0.5 ? 20.0 : basis<1.5 ? 20.375 : basis<2.5 ? 20.4375 : 20.46875;
    } else if (UV.y==20.0625) { UV2.x=floor(UV2.x);UV2.y=0.0; }
    else if (UV.y==20.25390625) UV.y=20.25;
"""
	var transport_anchor:="UV.y = mod(UV.y,32.0);"
	var sampler_anchor:="uniform sampler2D modern_tree : source_color, filter_linear_mipmap, repeat_disable;"
	check(old_code.count(transport_anchor)==1,"historical owner/material transport anchor")
	check(old_code.count(sampler_anchor)==1,"historical tree sampler anchor")
	if old_code.count(transport_anchor)!=1 or old_code.count(sampler_anchor)!=1:
		printerr("FAIL: missing or incompatible palette baseline: "+baseline_path)
		quit(1);return
	old_code=old_code.replace(transport_anchor,transport_anchor+"\n"+kind_decode)
	# Keep filtering matched so this comparison isolates palette changes.
	old_code=old_code.replace(sampler_anchor,"uniform sampler2D modern_tree : source_color, filter_linear_mipmap_anisotropic, repeat_disable;")
	var old:=Shader.new();old.code=old_code.replace("depth_test_disabled, depth_draw_never","depth_draw_opaque").replace("void fragment() {","void fragment() {\n DEPTH = UV.y > 19.5 && UV.y < 21.5 ? FRAGCOORD.z : 0.0;\n if (UV.y > 20.04 && UV.y < 20.08) DEPTH = 0.5 + min(UV2.x,1024.0)/4096.0;")
	var legacy_old:=Shader.new();legacy_old.code=old_code
	var specs:=[[49,"road",true],[48,"grass",true],[2,"grass-hill",true],[4,"earth-hill",false],[40,"water",false],[115,"tank",false],[163,"hind",false],[157,"farm",false],[103,"tree",false],[-1,"sky",true]]
	for spec in specs:
		var data:=model_packet(catalog,spec[0]) if spec[0]>=0 else packet()
		for index in [17,19,26,28]:data.materials[index]={17:[0x0700,0x0007],19:[0x0800,0x0008],26:[0x0703,0x0307],28:[0x0803,0x0308]}[index]
		if spec[0] in [48,49]:
			var points:Array=data.objects[0].polygons[0].camera_vertices
			var center:=Vector3.ZERO
			for p:Array in points:center+=Modern.vec(p)
			center/=points.size()
			for poly:Dictionary in data.objects[0].polygons:
				for i in poly.camera_vertices.size():
					var p:Vector3=Basis(Vector3.RIGHT,-0.6)*(Modern.vec(poly.camera_vertices[i])-center)+center
					poly.camera_vertices[i]=[p.x,p.y,p.z]
		if spec[0]==-1:
			data.camera.world_position_raw=[0,0,50]
			data.background={"kind":"horizon","line":[[0,100],[319,100]],"colors":[5,8]}
			data.objects[0].shape_index=-1;data.objects[0].polygons[0].colors=[9,9]
			data.objects[0].polygons[0].camera_vertices=[[-15,160,25],[15,160,25],[15,160,45],[-15,160,45]]
		var input:=JSON.stringify(data)
		var fresh:=await render(data,true)
		var material:ShaderMaterial=draw.mesh_node.mesh.surface_get_material(0)
		var current:Shader=material.shader
		var geometry:PackedVector3Array=draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
		material.shader=old
		var before:=await capture()
		material.shader=current
		check((await capture()).get_data()==fresh.get_data(),spec[1]+": exact shader restoration")
		check(draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==geometry,spec[1]+": geometry identical")
		check(JSON.stringify(data)==input,spec[1]+": source packet immutable")
		var changed:=0;var escaped:=0;var warm:=0;var green:=0;var shades:={}
		for y in fresh.get_height():
			for x in fresh.get_width():
				var a:=before.get_pixel(x,y);var b:=fresh.get_pixel(x,y)
				if a==b:continue
				changed+=1
				if a==Color.BLACK:escaped+=1
				if b.r>b.g and b.g>b.b:warm+=1
				if b.g/maxf(b.r,0.01)>a.g/maxf(a.r,0.01):green+=1
				shades[b.to_rgba32()]=true
		check(changed>100 if spec[2] else changed==0,spec[1]+": exact colour-change scope")
		check(escaped==0,spec[1]+": no silhouette expansion")
		if spec[1]=="road":
			check(warm==changed,"all changed road samples have warm charcoal balance")
			check(shades.size()>5,"road retains visible coarse tonal variation")
		if spec[1] in ["grass","grass-hill"]:check(green>changed*0.99,"grass becomes fresher green")
		if spec[1]=="sky":
			check(fresh.get_pixel(100,40).b>before.get_pixel(100,40).b,"upper sky becomes bluer")
			check(fresh.get_pixel(100,396)==before.get_pixel(100,396),"pale horizon retained")
			check(fresh.get_pixel(640,220)==before.get_pixel(640,220),"actor in sky unchanged")
		fresh.save_png(output.path_join(str(spec[1])+"-after.png"));before.save_png(output.path_join(str(spec[1])+"-before.png"))
		var legacy:=await render(data,false)
		draw.mesh_node.mesh.surface_get_material(0).shader=legacy_old
		check((await capture()).get_data()==legacy.get_data(),spec[1]+": non-Modern pixel identity")
		rows.append({"case":spec[1],"changed_pixels":changed,"outside":escaped,"shades":shades.size()})
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":failures,"cases":rows},"  "))
	for failure in failures:printerr("FAIL: "+failure)
	print("PC_MODERN_PALETTE: %d checks, %d errors"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
