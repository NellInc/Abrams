extends SceneTree
const Art=preload("res://scripts/pc_vehicle_art.gd")
const Geometry=preload("res://scripts/pc_surface_geometry.gd")
const Draw=preload("res://scripts/pc_draw_pass.gd")
const Camera=preload("res://scripts/pc_camera.gd")
const Genesis=preload("res://scripts/pc_genesis_style.gd")
var checks:=0
var errors: Array[String]=[]
var outside:=0
var changed:=0
var pixels:=0
var passes:=0
var selected:=0
var art: RefCounted
var draw: Node3D
var viewport: SubViewport
var camera: Camera3D
var output: String
var directory: String
var cases: Array=[]

func _initialize() -> void: run.call_deferred()
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok and errors.size()<20: errors.append(why)

func run() -> void:
	directory=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args:=OS.get_cmdline_user_args()
	output=directory.path_join("artifacts/pc-vehicle-art-headless")
	if "--output" in args: output=args[args.find("--output")+1]
	DirAccess.make_dir_recursive_absolute(output)
	art=Art.new()
	check(not art.load_assets(directory.path_join("absent")) and art.atlas==null,"missing assets accepted")
	check(art.load_assets(directory),"pinned assets unavailable")
	if art.atlas==null: finish(); return
	var palette:=Genesis.new()
	check(palette.load_palette(directory.path_join("reference/genesis/extracted/gunner/palette.gpl")),"Genesis palette unavailable")
	viewport=SubViewport.new()
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	camera=Camera3D.new()
	viewport.add_child(camera)
	camera.make_current()
	draw=Draw.new()
	draw.solid_enabled=true
	draw.presentation_palette=palette.palette
	camera.add_child(draw)
	var fixture:=directory.path_join("artifacts/pc-sprite-controls-02/report.json")
	if "--fixture" in args: fixture=args[args.find("--fixture")+1]
	check(FileAccess.file_exists(fixture),"source replay unavailable")
	if not FileAccess.file_exists(fixture): finish(); return
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture))
	for packet: Dictionary in report.render_passes:
		geometry_invariant(packet)
		passes+=1
		selected+=draw.vehicle_polygon_count
	check(passes==report.render_passes.size() and passes>0 and selected>0,"replay vehicle coverage absent")
	for shape: int in Art.MODELS:
		for primitive: int in Art.MODELS[shape][2]:
			var data:=panel_case(report.render_passes[0],shape,primitive,192.0,0.0)
			var object: Dictionary=data.objects[0]
			var polygon: Dictionary=object.polygons[0]
			var bound: Dictionary=art.mapping(object,polygon,data.palette_rgb)
			check(not bound.is_empty(),"original face rejected")
			for field in ["root","shape_index"]:
				var bad:=object.duplicate(true)
				bad[field]=-1
				check(art.mapping(bad,polygon,data.palette_rgb).is_empty(),"unknown identity accepted")
			for field in ["primitive","fill_mode","colors","camera_vertices"]:
				var bad:=polygon.duplicate(true)
				bad[field]=[] if field in ["colors","camera_vertices"] else -1
				check(art.mapping(object,bad,data.palette_rgb).is_empty(),"unknown face accepted")
			var unknown: Array=data.palette_rgb.duplicate(true)
			unknown[7]=[1,2,3]
			check(art.mapping(object,polygon,unknown).is_empty(),"unknown/thermal palette accepted")
			uniform_fit(shape,primitive,bound.uv)
			for depth in [192.0,64.0]:
				for slope in [0.0,0.8,-0.8]: geometry_invariant(panel_case(data,shape,primitive,depth,slope))
			if "--native" in args:
				for scale in [4,5]:
					await native_case(data,scale,"%d-%d"%[shape,primitive],true)
				await native_case(panel_case(data,shape,primitive,64.0,0.8),4,"%d-%d-near"%[shape,primitive],true)
				await occlusion(data)
				await analytic_uv(data,shape,primitive)
	if "--native" in args:
		for index in [0,90,150]: await native_case(report.render_passes[index],4,"replay-%d"%index,false)
		if "--fixture" in args: await native_case(report.render_passes[-1],4,"replay-final",true)
		var unknown: Dictionary=report.render_passes[0].duplicate(true)
		unknown.palette_rgb[7]=[1,2,3]
		var old:=await render(unknown,false,4)
		var fresh:=await render(unknown,true,4)
		check(old.get_data()==fresh.get_data(),"unknown palette renderer changed")
		await native_colours(report.render_passes[0])
	draw.apply_pass({"objects":[]})
	check(draw.vehicle_polygon_count==0 and draw.mesh_node.mesh==null,"stale vehicle frame")
	check(not art.load_assets(directory.path_join("absent")) and art.atlas==null and art.regions.is_empty(),"stale assets after failed reload")
	finish()

func panel_case(template: Dictionary, shape: int, primitive: int, depth: float, slope: float) -> Dictionary:
	var packet:=template.duplicate(true)
	packet.camera={"clip":[0,0,319,199],"center":[160,100],"focal_pixels":192,"near_raw":16,
		"matrix_q14_columns":[16384,0,0,0,16384,0,0,0,16384],"world_position_raw":[0,0,0]}
	packet.background={"kind":"solid","color":5}
	var points: Array=[]
	for v: Array in Art.MODELS[shape][2][primitive]: points.append([v[1],depth+v[1]*slope,v[2]])
	packet.objects=[{"shape_index":shape,"root":Art.MODELS[shape][0],"dynamic_instance":true,"static_path":0,
		"polygons":[{"primitive":primitive,"fill_mode":1,"colors":[3,3],"camera_vertices":points}]}]
	return packet

func geometry_invariant(data: Dictionary) -> void:
	var packet:=JSON.stringify(data)
	draw.vehicle_art=null
	draw.apply_pass(data)
	var old: Array=draw.mesh_node.mesh.surface_get_arrays(0)
	draw.vehicle_art=art
	draw.apply_pass(data)
	var fresh: Array=draw.mesh_node.mesh.surface_get_arrays(0)
	check(old[Mesh.ARRAY_VERTEX]==fresh[Mesh.ARRAY_VERTEX],"geometry/clipping/painter order changed")
	var a: PackedVector2Array=old[Mesh.ARRAY_TEX_UV]
	var b: PackedVector2Array=fresh[Mesh.ARRAY_TEX_UV]
	check(a.size()==b.size(),"triangle count changed")
	for i in a.size():
		check(a[i].x==b[i].x,"source material changed")
		if b[i].y<10: check(old[Mesh.ARRAY_TEX_UV2][i]==fresh[Mesh.ARRAY_TEX_UV2][i],"unselected UV changed")
	check(packet==JSON.stringify(data),"source packet mutated")
	check(draw.render_warnings.is_empty(),"render warning")

func uniform_fit(shape: int, primitive: int, uv: Array) -> void:
	var source: Array=Art.MODELS[shape][2][primitive]
	var factor: float=-1
	var donor: int=Art.MODELS[shape][1]
	var texture_size:=Vector2(art.atlas.get_size())
	for i in source.size():
		for j in range(i+1,source.size()):
			var length:=Vector2(source[i][1]-source[j][1],source[i][2]-source[j][2]).length()
			var sampled: float=((uv[i]-uv[j])*texture_size).length()/length
			if factor<0: factor=sampled
			check(absf(factor-sampled)<0.0001,"track wheels stretched by nonuniform UV fit")
		var gutter:=Vector2(64,64)/texture_size
		var isolated:=Rect2(art.regions[donor].position-gutter,art.regions[donor].size+gutter*2.0)
		check(isolated.has_point(uv[i]),"UV leaves isolated atlas panel and transparent gutter")

func render(data: Dictionary, enabled: bool, scale: int) -> Image:
	var frame: Dictionary=data.camera.duplicate(true)
	frame.matrix_q14_columns=[16384,0,0,0,16384,0,0,0,16384]
	frame.world_position_raw=[0,0,0]
	viewport.size=Camera.apply(camera,frame,Vector3.ZERO)*scale
	draw.vehicle_art=art if enabled else null
	draw.apply_pass(data)
	return await capture()

func capture() -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return viewport.get_texture().get_image()

func native_case(data: Dictionary, scale: int, label: String, expect_visible: bool) -> void:
	var old:=await render(data,false,scale)
	var fresh:=await render(data,true,scale)
	var shader:=Shader.new()
	shader.code="shader_type spatial;render_mode unshaded,cull_disabled,depth_test_disabled,depth_draw_never,fog_disabled;void fragment(){ALBEDO=UV.y>9.5?vec3(1.0):vec3(0.0);}"
	var mask_material:=ShaderMaterial.new()
	mask_material.shader=shader
	draw.mesh_node.mesh.surface_set_material(0,mask_material)
	var mask:=await capture()
	var changes:=0
	var owned:=0
	for y in fresh.get_height():
		for x in fresh.get_width():
			pixels+=1
			var equal:=old.get_pixel(x,y).to_rgba32()==fresh.get_pixel(x,y).to_rgba32()
			if mask.get_pixel(x,y).r<0.5:
				outside+=1
				check(equal,"vehicle detail escaped original visibility: "+label)
			else:
				owned+=1
				if not equal: changes+=1
	changed+=changes
	if expect_visible: check(changes>100,"no visible vehicle detail: "+label)
	cases.append({"case":label,"scale":scale,"original_visible_pixels":owned,"changed":changes})
	old.save_png(output.path_join(label+"-%dx-original.png"%scale))
	fresh.save_png(output.path_join(label+"-%dx-remastered.png"%scale))
	mask.save_png(output.path_join(label+"-%dx-mask.png"%scale))

func occlusion(data: Dictionary) -> void:
	var packet:=data.duplicate(true)
	var cover: Dictionary=packet.objects[0].duplicate(true)
	cover.shape_index=-1
	cover.polygons[0].colors=[6,6]
	for point in cover.polygons[0].camera_vertices:
		for c in 3: point[c]*=2
	packet.objects.append(cover)
	var old:=await render(packet,false,4)
	var fresh:=await render(packet,true,4)
	check(old.get_data()==fresh.get_data(),"later farther polygon no longer covers vehicle")
	packet.objects.reverse()
	old=await render(packet,false,4)
	fresh=await render(packet,true,4)
	check(old.get_data()!=fresh.get_data(),"earlier source polygon hides later vehicle")

func analytic_uv(template: Dictionary, shape: int, primitive: int) -> void:
	# Independent ray/plane reconstruction from screen position. Green means the
	# GPU's perspective-interpolated UV matches the source-plane point, also after
	# clipping at y=16. No production clipping/UV function is used by the oracle.
	var source: Array=Art.MODELS[shape][2][primitive]
	var lo:=Vector2(INF,INF)
	var hi:=Vector2(-INF,-INF)
	for v: Array in source:
		lo=lo.min(Vector2(v[1],-v[2]))
		hi=hi.max(Vector2(v[1],-v[2]))
	var donor: int=Art.MODELS[shape][1]
	var box: Array=Art.ASSETS[donor][3]
	var fit: float=minf((hi.x-lo.x)/box[2],(hi.y-lo.y)/box[3])
	var origin: Vector2=Vector2(box[0],box[1])-(lo+((hi-lo)-Vector2(box[2],box[3])*fit)*0.5)/fit
	origin+=art.regions[donor].position*Vector2(art.atlas.get_size())
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
render_mode unshaded,cull_disabled,depth_test_disabled,depth_draw_never,fog_disabled;
uniform vec2 atlas_size; uniform vec2 origin; uniform float fit;
void fragment(){
  ALBEDO=vec3(0.0);
  if(UV.y>9.5){
    vec2 ray=(SCREEN_UV*vec2(320.0,200.0)-vec2(160.0,100.0))/192.0;
    float y=64.0/(1.0-0.8*ray.x);
    vec2 expected=(origin+ray*y/fit)/atlas_size;
    ALBEDO=length(expected-UV2)<0.00002?vec3(0.0,1.0,0.0):vec3(1.0,0.0,0.0);
  }
}"""
	var data:=panel_case(template,shape,primitive,64.0,0.8)
	await render(data,true,4)
	var material:=ShaderMaterial.new()
	material.shader=shader
	material.set_shader_parameter("atlas_size",Vector2(art.atlas.get_size()))
	material.set_shader_parameter("origin",origin)
	material.set_shader_parameter("fit",fit)
	draw.mesh_node.mesh.surface_set_material(0,material)
	var image:=await capture()
	var green:=0
	for y in range(0,image.get_height(),3):
		for x in range(0,image.get_width(),3):
			var value:=image.get_pixel(x,y)
			check(value.r<0.5,"perspective/near-clipped source UV drift")
			if value.g>0.5: green+=1
	check(green>100,"analytic near-plane samples missing")

func finish() -> void:
	for e in errors: printerr("FAIL: "+e)
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"checks":checks,"errors":errors,"replay_passes":passes,"selected_faces":selected,"pixels":pixels,
		"unchanged_outside_pixels":outside,"changed_vehicle_pixels":changed,"cases":cases},"  "))
	print("PC_VEHICLE_ART: %d checks, %d errors; %d native pixels"%[checks,errors.size(),pixels])
	quit(0 if errors.is_empty() else 1)

func native_colours(template: Dictionary) -> void:
	var sample:=panel_case(template,115,13323,192.0,0.0)
	var original: Array=draw.presentation_palette
	for shape: int in Art.PLAIN_FACES:
		for primitive: int in Art.PLAIN_FACES[shape]:
			sample.objects[0].shape_index=shape
			sample.objects[0].root=Art.MODELS[shape][0]
			sample.objects[0].polygons=[{"primitive":primitive,"fill_mode":1,
				"colors":[Art.PLAIN_FACES[shape][primitive][0],3],
				"camera_vertices":[[-64,192,-32],[64,192,-32],[64,192,32],[-64,192,32]]}]
			for pc in [false,true]:
				draw.presentation_palette=[] if pc else original
				var image:=await render(sample,true,4)
				var expected:=Color8(85,85,85) if pc else Color8(65,68,65)
				for y in range(350,450):
					for x in range(540,740): check(image.get_pixel(x,y).to_rgba32()==expected.to_rgba32(),"native model grey differs from Genesis/source PC")
				check(draw.vehicle_polygon_count==1,"plain source shade not selected")
	draw.presentation_palette=original
