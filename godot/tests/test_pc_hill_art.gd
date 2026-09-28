extends SceneTree
const Terrain = preload("res://scripts/pc_terrain_style.gd")
const Genesis = preload("res://scripts/pc_genesis_style.gd")
const Draw = preload("res://scripts/pc_draw_pass.gd")
const Camera = preload("res://scripts/pc_camera.gd")
var checks := 0
var errors: Array[String] = []
var pixels := 0
var changed := 0
var outside := 0
var anchor_samples := 0
var visible_cases := 0
var fully_occluded_cases := 0
var vertical_samples := 0
var style: RefCounted
var genesis: RefCounted
var viewport: SubViewport
var camera: Camera3D
var draw: Node3D
var directory: String
var output: String

func _initialize() -> void: run.call_deferred()
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok and errors.size()<20: errors.append(why)

func setup(frame: Dictionary, scale: int) -> void:
	var displayed := frame.duplicate(true)
	displayed.matrix_q14_columns=[16384,0,0,0,16384,0,0,0,16384]
	displayed.world_position_raw=[0,0,0]
	viewport.size=Camera.apply(camera,displayed,Vector3.ZERO)*scale

func capture() -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return viewport.get_texture().get_image()

func render(data: Dictionary, enabled: bool, scale: int) -> Image:
	setup(data.camera,scale)
	var texture: Texture2D=style.hill_texture
	if not enabled: style.hill_texture=null
	draw.apply_pass(data)
	style.hill_texture=texture
	return await capture()

func run() -> void:
	directory=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args:=OS.get_cmdline_user_args()
	output=directory.path_join("artifacts/pc-hill-art-test")
	if "--output" in args: output=args[args.find("--output")+1]
	DirAccess.make_dir_recursive_absolute(output)
	style=Terrain.new()
	check(style.load_assets(directory.path_join("local-art/pc-terrain-remastered/detail-v1")),"flat terrain assets unavailable")
	check(not style.load_hills(directory.path_join("absent")),"missing hill assets accepted")
	check(style.hill_texture==null,"missing hills retained texture")
	check(style.load_hills(directory),"pinned hill asset/source missing")
	genesis=Genesis.new()
	check(genesis.load_palette(directory.path_join("reference/genesis/extracted/gunner/palette.gpl")),"Genesis palette unavailable")
	if style.hill_texture==null or genesis.palette.size()!=16: finish(); return
	for shape: int in Terrain.HILLS:
		for primitive: int in Terrain.HILLS[shape][1]:
			var value: int=Terrain.HILLS[shape][1][primitive]
			var object: Dictionary={"shape_index":shape,"root":Terrain.HILLS[shape][0],"static_path":1,"dynamic_instance":false}
			var polygon: Dictionary={"primitive":primitive,"colors":[value,value],"fill_mode":1,"camera_vertices":[[0,128,0],[32,128,0],[0,256,0]]}
			check(Terrain.surface_kind(object,polygon,true)==Terrain.HILL_VERTICAL.get(primitive,7),"original hill face rejected")
			check(Terrain.surface_kind(object,polygon)==0,"hill selected without opt-in")
			for field in ["root","shape_index"]:
				var invalid:=object.duplicate(true)
				invalid[field]=-1
				check(Terrain.surface_kind(invalid,polygon,true)==0,"unknown hill identity accepted")
			object.dynamic_instance=true
			check(Terrain.surface_kind(object,polygon,true)==0,"hill art applied to actor")
			object.dynamic_instance=false
			for field in ["primitive","fill_mode","colors"]:
				var invalid:=polygon.duplicate(true)
				invalid[field]=[-1,-1] if field=="colors" else 0
				check(Terrain.surface_kind(object,invalid,true)==0,"unknown hill draw accepted")
	check(Terrain.material_mean(genesis.palette,[1792,7])==[86.0,85.0,0.0],"olive mean differs from Genesis black/olive swatches")
	check(Terrain.material_mean(genesis.palette,[1795,775])==[102.0,101.0,16.0],"light olive mean differs")
	check(Terrain.material_mean(genesis.palette,[2048,8])==[0.0,85.0,0.0],"green mean differs")
	viewport=SubViewport.new()
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	camera=Camera3D.new()
	viewport.add_child(camera)
	camera.make_current()
	draw=Draw.new()
	draw.solid_enabled=true
	draw.terrain_style=style
	draw.presentation_palette=genesis.palette
	camera.add_child(draw)
	var source_path:=directory.path_join("artifacts/pc-sprite-controls-02/report.json")
	check(FileAccess.file_exists(source_path),"original replay fixture missing")
	if not FileAccess.file_exists(source_path): finish(); return
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source_path))
	var native_cases: Array=[]
	for data: Dictionary in report.render_passes:
		var before:=JSON.stringify(data)
		var saved: Texture2D=style.hill_texture
		style.hill_texture=null
		draw.apply_pass(data)
		var old: Array=draw.mesh_node.mesh.surface_get_arrays(0)
		style.hill_texture=saved
		draw.apply_pass(data)
		var fresh: Array=draw.mesh_node.mesh.surface_get_arrays(0)
		check(old[Mesh.ARRAY_VERTEX]==fresh[Mesh.ARRAY_VERTEX],"hill geometry/order changed")
		check(old[Mesh.ARRAY_TEX_UV2]==fresh[Mesh.ARRAY_TEX_UV2],"effect UVs changed")
		var a: PackedVector2Array=old[Mesh.ARRAY_TEX_UV]
		var b: PackedVector2Array=fresh[Mesh.ARRAY_TEX_UV]
		check(a.size()==b.size(),"triangle count changed")
		for i in a.size(): check(a[i].x==b[i].x,"source material ID changed")
		check(JSON.stringify(data)==before,"source packet mutated")
		check(draw.render_warnings.is_empty(),"unexpected source warning")
		if int(data.sequence) in [90,150,168,210] and draw.hill_polygon_count>0: native_cases.append(data)
	check(native_cases.size()>=3,"missing native terrain viewpoints")
	if "--native" in args:
		for scale in [4,5]:
			for data: Dictionary in native_cases: await native_case(data,scale)
		check(visible_cases==6 and fully_occluded_cases==2,"unexpected original hill visibility coverage")
		await fallbacks(native_cases[0])
		await mean_and_anchor(native_cases[0])
		await vertical_anchor(native_cases[0])
	draw.apply_pass({"objects":[]})
	check(draw.hill_polygon_count==0 and draw.mesh_node.mesh==null,"stale hills on missing frame")
	finish()

func native_case(data: Dictionary, scale: int) -> void:
	var old:=await render(data,false,scale)
	var fresh:=await render(data,true,scale)
	check(draw.hill_polygon_count>0,"native hill not selected")
	var mesh: ArrayMesh=draw.mesh_node.mesh
	var material: Material=mesh.surface_get_material(0)
	var classifier:=ShaderMaterial.new()
	var shader:=Shader.new()
	shader.code="shader_type spatial;render_mode unshaded,cull_disabled,depth_test_disabled,depth_draw_never,fog_disabled;void fragment(){ALBEDO=UV.y>6.5?vec3(1.0):vec3(0.0);}"
	classifier.shader=shader
	mesh.surface_set_material(0,classifier)
	var mask:=await capture()
	mesh.surface_set_material(0,material)
	var local_changes:=0
	var visible_pixels:=0
	for y in fresh.get_height():
		for x in fresh.get_width():
			pixels+=1
			var equal:=old.get_pixel(x,y).to_rgba32()==fresh.get_pixel(x,y).to_rgba32()
			if mask.get_pixel(x,y).r<0.5:
				outside+=1
				check(equal,"hill art changed scenery/vehicle/effect outside original faces")
			else:
				visible_pixels+=1
				if not equal: local_changes+=1
	changed+=local_changes
	if visible_pixels>0:
		visible_cases+=1
		check(local_changes>100,"visible hill art has no native effect")
	else:
		fully_occluded_cases+=1
		check(local_changes==0,"fully occluded source hills became visible")
	var prefix: String="%d-%dx"%[data.sequence,scale]
	old.save_png(output.path_join(prefix+"-original.png"))
	fresh.save_png(output.path_join(prefix+"-remastered.png"))
	mask.save_png(output.path_join(prefix+"-ownership.png"))

func fallbacks(data: Dictionary) -> void:
	var unknown:=data.duplicate(true)
	unknown.palette_rgb[7]=[1,2,3]
	draw.presentation_palette=[]
	var old:=await render(unknown,false,4)
	var fresh:=await render(unknown,true,4)
	check(draw.hill_polygon_count==0 and old.get_data()==fresh.get_data(),"unknown/thermal palette changed")
	draw.presentation_palette=genesis.palette

func mean_and_anchor(data: Dictionary) -> void:
	# Known ramp, sloped source plane and analytic ray intersection. This checks
	# GPU perspective interpolation independently of the production UV helper.
	var ramp:=Image.create(256,256,false,Image.FORMAT_RGB8)
	for y in 256:
		for x in 256: ramp.set_pixel(x,y,Color8(x,x,x))
	ramp.generate_mipmaps()
	var saved: Texture2D=style.hill_texture
	style.hill_texture=ImageTexture.create_from_image(ramp)
	var sample:=data.duplicate(true)
	sample.camera={"clip":[32,13,287,109],"center":[159,61],"near_raw":16,"focal_pixels":128,
		"matrix_q14_columns":[16384,0,0,0,16384,0,0,0,16384],"world_position_raw":[0,0,50]}
	# z = 0.5*y - 768; every sampled intersection lies within these bounds.
	sample.objects=[{"shape_index":29,"root":3208,"static_path":1,"dynamic_instance":false,
		"polygons":[{"primitive":3222,"fill_mode":1,"colors":[17,17],
		"camera_vertices":[[-1024,1024,-256],[1024,1024,-256],[1024,4096,1280],[-1024,4096,1280]]}]}]
	sample.background={"kind":"solid","color":5}
	for rotated in [false,true]:
		for shift in [0,192,6144]:
			sample.camera.world_position_raw[0]=shift
			sample.camera.matrix_q14_columns=[0,16384,0,-16384,0,0,0,0,16384] if rotated else [16384,0,0,0,16384,0,0,0,16384]
			var im:=await render(sample,true,4)
			for y in [220,260,300]:
				for x in range(380,640,19):
					var source: Vector2=Vector2(32,13)+(Vector2(x,y)+Vector2(0.5,0.5))/4.0
					var forward:=768.0/(0.5-(61.0-source.y)/128.0)
					var horizontal: float=(source.x-159.0)*forward/128.0
					var east: float=shift+(forward if rotated else horizontal)
					var u:=fposmod(east/768.0,1.0)
					if u<0.02 or u>0.98: continue
					var level:=clampi(roundi(16.0+((u*256.0-0.5)/255.0-Terrain.HILL_MEAN)*64.0),0,32)
					var rgb:=Terrain.detail_rgb([86.0,85.0,0.0],level)
					check(im.get_pixel(x,y).to_rgba32()==Color8(rgb[0],rgb[1],rgb[2]).to_rgba32(),"hill texture slides or original mean RGB differs")
					anchor_samples+=1
	check(anchor_samples>150,"too few analytic slope samples")
	# A neutral ramp level must completely remove the 2x2 checker, without
	# introducing even one source-pixel-phase-dependent variation.
	var grey:=Image.create(8,8,false,Image.FORMAT_RGB8)
	grey.fill(Color(Terrain.HILL_MEAN,Terrain.HILL_MEAN,Terrain.HILL_MEAN))
	grey.generate_mipmaps()
	style.hill_texture=ImageTexture.create_from_image(grey)
	var mean_image:=await render(sample,true,5)
	for y in range(250,350):
		for x in range(500,700): check(mean_image.get_pixel(x,y).to_rgba32()==Color8(86,85,0).to_rgba32(),"resolved dither is not the exact neutral Genesis mean")
	# Later source polygons must still cover a hill regardless of physical depth.
	var cover: Dictionary=sample.objects[0].duplicate(true)
	cover.shape_index=-1
	cover.polygons[0].colors=[6,6]
	for p in cover.polygons[0].camera_vertices:
		for c in 3: p[c]*=2
	sample.objects.append(cover)
	var old:=await render(sample,false,4)
	var fresh:=await render(sample,true,4)
	check(old.get_data()==fresh.get_data(),"later farther polygon fails to cover hills")
	sample.objects.reverse()
	old=await render(sample,false,4)
	fresh=await render(sample,true,4)
	check(old.get_data()!=fresh.get_data(),"earlier polygon hides later hill")
	style.hill_texture=saved

func vertical_anchor(data: Dictionary) -> void:
	var saved: Texture2D=style.hill_texture
	var sample:=data.duplicate(true)
	sample.camera={"clip":[32,13,287,109],"center":[159,61],"near_raw":16,"focal_pixels":128,
		"matrix_q14_columns":[16384,0,0,0,16384,0,0,0,16384],"world_position_raw":[0,0,50]}
	sample.background={"kind":"solid","color":5}
	for axis in [8,9]:
		sample.objects=[{"shape_index":24 if axis==8 else 2,"root":2712 if axis==8 else 828,
			"static_path":1,"dynamic_instance":false,"polygons":[{"primitive":2742 if axis==8 else 854,
			"fill_mode":1,"colors":[19,19] if axis==8 else [28,28],
			"camera_vertices":[[256,512,-512],[256,2048,-512],[256,2048,512],[256,512,512]] if axis==8 else [[-1024,1024,-512],[1024,1024,-512],[1024,1024,512],[-1024,1024,512]]}]}]
		for component in [0,1]:
			var ramp:=Image.create(256,256,false,Image.FORMAT_RGB8)
			for y in 256:
				for x in 256:
					var v: int=x if component==0 else y
					ramp.set_pixel(x,y,Color8(v,v,v))
			ramp.generate_mipmaps()
			style.hill_texture=ImageTexture.create_from_image(ramp)
			for shift in [0,192,6144]:
				sample.camera.world_position_raw=[shift,shift,50+shift]
				var im:=await render(sample,true,4)
				for y in [180,200,220,240]:
					for x in ([690,710,730] if axis==8 else [430,490,550,610]):
						var source:=Vector2(32,13)+(Vector2(x,y)+Vector2(0.5,0.5))/4.0
						var forward: float=256.0*128.0/(source.x-159.0) if axis==8 else 1024.0
						var horizontal: float=(source.x-159.0)*forward/128.0
						var height: float=(61.0-source.y)*forward/128.0
						var uv:=Vector2(shift-forward if axis==8 else shift+horizontal,50+shift+height)/768.0
						var u:=fposmod(uv[component],1.0)
						if u<0.02 or u>0.98: continue
						var level:=clampi(roundi(16.0+((u*256.0-0.5)/255.0-Terrain.HILL_MEAN)*64.0),0,32)
						var rgb:=Terrain.detail_rgb([0.0,85.0,0.0] if axis==8 else [16.0,101.0,16.0],level)
						check(im.get_pixel(x,y).to_rgba32()==Color8(rgb[0],rgb[1],rgb[2]).to_rgba32(),"vertical hill texture anchor/stretch differs")
						vertical_samples+=1
	check(vertical_samples>100,"too few vertical surface probes")
	style.hill_texture=saved

func finish() -> void:
	for e in errors: printerr("FAIL: "+e)
	var report: Dictionary={"checks":checks,"errors":errors,"pixels":pixels,"changed_hill_pixels":changed,"unchanged_outside_pixels":outside,"analytic_anchor_samples":anchor_samples,"vertical_anchor_samples":vertical_samples,"visible_cases":visible_cases,"fully_occluded_cases":fully_occluded_cases}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PC_HILL_ART: %d checks, %d errors; %d native pixels"%[checks,errors.size(),pixels])
	quit(0 if errors.is_empty() else 1)
