extends SceneTree
const Modern = preload("res://scripts/pc_modern_assets.gd")
const Draw = preload("res://scripts/pc_draw_pass.gd")
const Geometry = preload("res://scripts/pc_surface_geometry.gd")
const Camera = preload("res://scripts/pc_camera.gd")
var started := Time.get_ticks_msec()

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec()-started>120000:
		printerr("FAIL: modern verification wall-clock deadline")
		quit(2)
	return false

var failures: Array[String] = []
var checks := 0
var frame := {"clip":[0,0,319,199],"center":[160,100],"focal_pixels":192,"near_raw":16,
	"matrix_q14_columns":[16384,0,0,0,16384,0,0,0,16384],"world_position_raw":[0,0,0]}
var art = Modern.new()
var draw: Node3D
var viewport: SubViewport
var camera: Camera3D
var native := false
var directory: String
var output: String

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok and failures.size()<30: failures.append(message)

func fixture() -> Dictionary:
	var points := [[-40,0,-20],[40,0,-20],[40,0,20],[-40,0,20]]
	return {"schema":1,"models":[{"shape_index":115,"source_primitives":{"10":points},
		"roots":[{"offset":1,"group_pointers":[2]}],"groups":[{"offset":2,"primitive_pointers":[10]}],
		"triangles":[{"source_primitive":10,"vertices":[[-100,-4,-50],[100,-4,-50],[0,-4,80]],"color":[90,110,70]}]}]}

func packet(depth: float=160.0, slope: float=0.0) -> Dictionary:
	var data := {"camera":frame.duplicate(true),"palette_rgb":Modern.PC_PALETTE.duplicate(true),
		"materials":[],"background":{"kind":"solid","color":0},"objects":[]}
	for i in 32: data.materials.append([i%16,i%16])
	var points: Array = []
	for p: Array in fixture().models[0].source_primitives["10"]:
		points.append([p[0],depth+p[0]*slope,p[2]])
	data.objects.append({"shape_index":115,"root":1,"dynamic_instance":true,"static_path":0,
		"pointer":99,"polygons":[{"primitive":10,"fill_mode":1,"colors":[3,3],"camera_vertices":points}]})
	return data

func run() -> void:
	DisplayServer.window_set_title("Abrams Modern Renderer Verification")
	directory = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	output = directory.path_join("artifacts/pc-modern-renderer")
	var args := OS.get_cmdline_user_args()
	if "--output" in args: output=args[args.find("--output")+1]
	native = "--native" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(output)
	check(not art.load_assets(directory.path_join("missing")),"missing assets accepted")
	check(art.configure(fixture()),"valid synthetic catalogue rejected")
	running_gear_contract()
	hind_livery_contract()
	roof_grain_contract()
	bridge_line_contract()
	affine_invariant_contract()
	var malformed := fixture()
	malformed.models[0].triangles[0].vertices[0] = [NAN,0,0]
	check(not art.configure(malformed) and art.models.is_empty(),"malformed catalogue retained geometry")
	check(art.configure(fixture()),"valid catalogue after failed reload")
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	camera = Camera3D.new()
	viewport.add_child(camera)
	camera.make_current()
	draw = Draw.new()
	draw.solid_enabled = true
	draw.modern_assets = art
	camera.add_child(draw)
	for depth in [160.0,24.0]:
		for slope in [0.0,0.8,-0.8]:
			var data := packet(depth,slope)
			var original := JSON.stringify(data)
			var polygons: Array = art.mapping(data.objects[0],data.objects[0].polygons[0],data.camera,data.palette_rgb)
			check(not polygons.is_empty(),"valid/near-clipped mapping missing")
			check(art.max_anchor_error<=0.25,"source anchor tolerance exceeded")
			var near := Geometry.near_clip(data.objects[0].polygons[0].camera_vertices,16)
			var coverage := PackedVector2Array()
			for point: Array in near: coverage.append(Geometry.project(point,data.camera))
			for facet: Dictionary in polygons:
				for point: Array in facet.points:
					var p := Geometry.project(point,data.camera)
					var on_edge := false
					for edge in coverage.size():
						if Geometry2D.get_closest_point_to_segment(p,coverage[edge],coverage[(edge+1)%coverage.size()]).distance_to(p)<0.001: on_edge=true
					check(on_edge or Geometry2D.is_point_in_polygon(p,coverage),"refined facet escaped explicit source coverage")
			check(JSON.stringify(data)==original,"source packet mutated")
			if native: await compare_native(data,"near-%s-%s"%[depth,slope])
	var data := packet()
	var bad := data.duplicate(true)
	bad.objects[0].polygons[0].camera_vertices[3][0] += 4
	check(art.mapping(bad.objects[0],bad.objects[0].polygons[0],frame,bad.palette_rgb).is_empty(),"inexact source anchors accepted")
	bad = data.duplicate(true)
	bad.palette_rgb[3] = [1,2,3]
	check(art.mapping(bad.objects[0],bad.objects[0].polygons[0],frame,bad.palette_rgb).is_empty(),"unsupported sensor palette accepted")
	for field in ["shape_index","root"]:
		bad = data.duplicate(true)
		bad.objects[0][field] = -1
		check(art.mapping(bad.objects[0],bad.objects[0].polygons[0],frame,bad.palette_rgb).is_empty(),"unknown source identity accepted")
	# No world-space cache: rebasing changes bookkeeping, paired camera points
	# remain identical. Restoring older sequence/epoch reconstructs immediately.
	draw.modern_enabled = true
	draw.apply_pass(data)
	var original_vertices = draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	bad = data.duplicate(true)
	bad.sequence = 0; bad.epoch = 99; bad.camera.world_position_raw = [30000,-30000,0]
	draw.apply_pass(bad)
	check(draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==original_vertices,"streaming rebase/restore changed paired geometry")
	draw.apply_pass({"objects":[]})
	check(draw.mesh_node.mesh==null and draw.modern_polygon_count==0,"disappearance retained Modern actor")
	draw.apply_pass(data)
	check(draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==original_vertices,"restored actor did not reconstruct")
	draw.modern_enabled=true
	draw.apply_pass(data)
	check(draw.mesh_node.mesh.surface_get_material(0).get_shader_parameter("material_means")!=null,"Modern without recognized hills has no mean texture")
	mesh_reuse_contract(data)
	if native:
		await quiet_source_dither(data)
		await retained_owner_mask(data)
		await ownership_ids(data)
		await one_frame_rebuild(data)
		await sprite_occlusion(data)
		await round_forms(data)
		await crew_painter_layers()
		await occlusion(data)
		var old := await render(bad,false)
		var fresh := await render(bad,true)
		check(old.get_size()==fresh.get_size(),"restore dimensions changed")
	check(draw.load_modern_assets(directory),"production catalogue failed preload: "+art.status)
	if art.ready:
		if native: check(draw.modern_prewarmed,"Modern GPU programs not prewarmed")
		var io_before: int=art.disk_io_count
		material_variation_contract()
		await production_views()
		if native:
			await tree_cutouts()
			await observed_round_fixture()
			await crew_head_commands()
			await bridge_line_pixels()
		check(art.disk_io_count==io_before,"frame rendering or mode switching performed asset I/O")
	check(not art.load_assets(directory.path_join("missing")) and art.models.is_empty(),"failed reload kept assets")
	for failure in failures: printerr("FAIL: "+failure)
	print("PC_MODERN: %s; %d checks; native=%s"%["PASS" if failures.is_empty() else "FAIL",checks,native])
	quit(0 if failures.is_empty() else 1)

func render(data: Dictionary, enabled: bool) -> Image:
	var view: Dictionary = data.camera.duplicate(true)
	view.matrix_q14_columns = [16384,0,0,0,16384,0,0,0,16384]
	view.world_position_raw = [0,0,0]
	viewport.size = Camera.apply(camera,view,Vector3.ZERO)*4
	draw.modern_enabled = enabled
	draw.apply_pass(data)
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return viewport.get_texture().get_image()

func compare_native(data: Dictionary, label: String) -> void:
	var source := await render(data,false)
	var modern := await render(data,true)
	var outside := 0
	var visible := 0
	var changed := 0
	for y in source.get_height():
		for x in source.get_width():
			if source.get_pixel(x,y)!=modern.get_pixel(x,y):
				changed += 1
				if modern.get_pixel(x,y)!=Color.BLACK: visible += 1
				if source.get_pixel(x,y)==Color.BLACK: outside += 1
	check(changed>0,label+" had no refined pixels")
	check(visible>0,label+" lost all refined visible pixels")
	if label=="near-160.0-0.0":
		modern.save_png(output.path_join("synthetic-modern.png"))
		draw.ownership.get_texture().get_image().save_png(output.path_join("synthetic-owner.png"))
	check(outside==0,label+" revealed pixels outside source silhouette")

func occlusion(data: Dictionary) -> void:
	# This far-away primitive MUST occlude the nearer actor because the original
	# painter order says so; ordinary 3D depth testing would get it wrong.
	var cover := {"shape_index":-1,"root":0,"static_path":1,"polygons":[{"primitive":0,
		"fill_mode":1,"colors":[7,7],"camera_vertices":[[-100,600,-120],[0,600,-120],[0,600,120],[-100,600,120]]}]}
	var sample := data.duplicate(true)
	sample.objects.append(cover)
	var a := await render(sample,false)
	var b := await render(sample,true)
	var covered := 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x,y)==Color8(170,85,0):
				covered += 1
				check(b.get_pixel(x,y)==Color8(114,102,70),"later far terrain/actor occluder leaked Modern geometry")
	check(covered>0,"occlusion fixture had no coverage")
	sample.objects.reverse()
	await compare_native(sample,"reversed-painter-order")

func production_views() -> void:
	# Actual captured original draw calls exercise packed integer transforms.
	var path := directory.path_join("artifacts/pc-sprite-controls-02/report.json")
	if not FileAccess.file_exists(path): check(false,"paired source replay missing"); return
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var selected := 0
	var indices := [0,90,150,report.render_passes.size()-1]
	for index in indices:
		var sample: Dictionary = report.render_passes[index]
		draw.modern_enabled = true
		draw.apply_pass(sample)
		selected += draw.modern_polygon_count
		check(art.max_anchor_error<=0.25,"paired source projection drift")
		if native:
			var image := await render(sample,true)
			image.save_png(output.path_join("replay-%d-modern.png"%index))
			image = await render(sample,false)
			image.save_png(output.path_join("replay-%d-source.png"%index))
	check(selected>0,"production replay selected no Modern facets")
	if native:
		for index in [150,260]:
			var packet_data: Dictionary = report.render_passes[index]
			var targets: Array = packet_data.objects.filter(func(o):return int(o.get("shape_index",-1))==115)
			if targets.is_empty(): continue
			for depth in [450.0,1000.0]:
				var actor: Dictionary = targets[0].duplicate(true)
				var lo := Vector3(INF,INF,INF)
				var hi := Vector3(-INF,-INF,-INF)
				for polygon: Dictionary in actor.polygons:
					for p: Array in polygon.camera_vertices:
						lo=lo.min(Modern.vec(p)); hi=hi.max(Modern.vec(p))
				var center := (lo+hi)*0.5
				for polygon: Dictionary in actor.polygons:
					for p: Array in polygon.camera_vertices:
						p[0]-=center.x; p[1]+=depth-center.y; p[2]-=center.z
				var sample := packet()
				sample.background.color=8
				sample.objects=[actor]
				sample.world=packet_data.world.duplicate(true)
				var modern := await render(sample,true)
				if index==260 and depth==450.0: await running_gear_pixels(sample,modern)
				modern.save_png(output.path_join("t62-view-%d-depth-%d-modern.png"%[index,int(depth)]))
				var source := await render(sample,false)
				source.save_png(output.path_join("t62-view-%d-depth-%d-source.png"%[index,int(depth)]))

func ownership_ids(data: Dictionary) -> void:
	for id in [1,2,127,255,256,257,1025]:
		var sample := data.duplicate(true)
		var object: Dictionary = sample.objects[0]
		sample.objects.clear()
		for _index in id-1: sample.objects.append({"static_path":1,"polygons":[]})
		sample.objects.append(object)
		await render(sample,true)
		var mask: Image = draw.ownership.get_texture().get_image()
		var pixel: Color = mask.get_pixel(mask.get_width()/2,mask.get_height()/2)
		var actual := roundi(pixel.r*255)+256*roundi(pixel.g*255)
		check(actual==id,"GPU source ownership ID %d decoded %d"%[id,actual])

func tree_cutouts() -> void:
	check(art.tree_texture!=null,"illustrated tree failed preload")
	if art.tree_texture==null: return
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("local-art/pc-modern/catalog.json")))
	var model: Dictionary = catalog.models.filter(func(m):return int(m.shape_index)==103)[0]
	var sample := packet()
	sample.objects.clear()
	# A rear actor covers the tree's full bounding rectangle. The original
	# tree owns its triangle silhouette; modern leaf gaps must reveal only the
	# background, never this originally concealed red actor.
	var rear := {"shape_index":-1,"root":0,"static_path":0,"dynamic_instance":true,"polygons":[{"primitive":0,"fill_mode":1,"colors":[6,6],
		"camera_vertices":[[-160,700,-240],[160,700,-240],[160,700,240],[-160,700,240]]}]}
	sample.objects.append(rear)
	var tree := {"shape_index":103,"root":10523,"static_path":1,"dynamic_instance":false,"polygons":[]}
	for primitive: Dictionary in model.source_primitives:
		var points: Array = []
		for raw: Array in primitive.vertices: points.append([raw[0],raw[1]+700,raw[2]-240])
		tree.polygons.append({"primitive":int(primitive.id),"fill_mode":1,"colors":[int(primitive.prefix_bytes[1]),int(primitive.prefix_bytes[2])],"camera_vertices":points})
	sample.objects.append(tree)
	var image := await render(sample,true)
	image.save_png(output.path_join("tree-over-hidden-actor.png"))
	var mask: Image = draw.ownership.get_texture().get_image()
	mask.save_png(output.path_join("tree-ownership.png"))
	var gaps := 0
	var foliage := 0
	for y in image.get_height():
		for x in image.get_width():
			var owner: Color = mask.get_pixel(x,y)
			if roundi(owner.r*255)==2 and roundi(owner.g*255)==0:
				var color := image.get_pixel(x,y)
				if color==Color.BLACK: gaps += 1
				else: foliage += 1
				check(color!=Color8(146,50,34),"tree gap reveals originally hidden actor")
	check(gaps>20 and foliage>20,"tree cutout did not expose background alongside foliage")
	check(draw.modern_tree_count>=2,"tree source planes not bound")

func one_frame_rebuild(data: Dictionary) -> void:
	for offset in [-60.0,60.0,-60.0,60.0]:
		var sample := data.duplicate(true)
		sample.epoch = 1 if offset<0 else 2
		sample.sequence = 999 if offset<0 else 0
		for p: Array in sample.objects[0].polygons[0].camera_vertices: p[0]+=offset
		var image := await render(sample,true)
		var screen := Geometry.project([offset,160,0],sample.camera)
		check(image.get_pixel(roundi(screen.x*4),roundi(screen.y*4))==Color8(90,110,70),"same-frame moved/restored actor sampled stale ownership")
	var unsupported := data.duplicate(true)
	unsupported.palette_rgb[3]=[100,80,60]
	var a := await render(unsupported,false)
	var b := await render(unsupported,true)
	check(a.get_data()==b.get_data(),"unsupported sensor palette differs from exact source fallback")

func sprite_occlusion(data: Dictionary) -> void:
	var sample := data.duplicate(true)
	sample.objects.append({"kind":"sprite","polygons":[],"sprite":{"width":4,"height":2,
		"pixels":[6,6,0,6,6,6,6,6],"opaque":[true,true,false,true,true,true,true,true],
		"origin":[159,99],"clip":[0,0,319,199]}})
	var image := await render(sample,true)
	for p in [Vector2i(159,99),Vector2i(160,99),Vector2i(162,99),Vector2i(160,100)]:
		check(image.get_pixel(p.x*4+2,p.y*4+2)==Color8(146,50,34),"opaque original bitmap pixel failed to occlude Modern actor")
	check(image.get_pixel(161*4+2,99*4+2)==Color8(90,110,70),"transparent bitmap pixel incorrectly hid Modern actor")

func round_forms(data: Dictionary) -> void:
	var sample := data.duplicate(true)
	var form := {"status":"observed","spans":[{"y":100,"left":158,"right":162,"color":12}]}
	sample.objects[0].round_forms=[form]
	sample.objects[0].draw_order=[{"kind":"polygon","index":0},{"kind":"round_form","index":0}]
	var image := await render(sample,true)
	check(draw.source_round_count==1,"observed round-form counter missing")
	check(image.get_pixel(160*4+2,100*4+2)==Color8(205,111,70),"observed round span hidden by refined geometry")
	sample.objects[0].draw_order.reverse()
	image = await render(sample,true)
	check(image.get_pixel(160*4+2,100*4+2)==Color8(90,110,70),"earlier round span overrode later original polygon ownership")
	sample.objects[0].round_forms[0].status="rejected-before-raster"
	image = await render(sample,true)
	check(draw.source_round_count==0,"near-rejected round form persisted")
	draw.apply_pass({"objects":[]})
	check(draw.source_round_count==0 and draw.modern_fallback_polygon_count==0 and draw.modern_tree_count==0 and draw.ownership.mesh_node.mesh==null,"empty pass retained source-command/ownership state")

func crew_painter_layers() -> void:
	# Two exactly coplanar source sheets with distinct authored paint. Native
	# depth must never choose between them using rounding or triangle sort order.
	for shape in [161,162]:
		var catalog:=fixture()
		var model:Dictionary=catalog.models[0]
		model.shape_index=shape
		model.source_primitives["11"]=model.source_primitives["10"].duplicate(true)
		model.groups[0].primitive_pointers.append(11)
		var second:Dictionary=model.triangles[0].duplicate(true)
		second.source_primitive=11;second.color=[160,100,55]
		model.triangles.append(second)
		check(art.configure(catalog),"coplanar crew fixture loaded")
		var sample:=packet()
		sample.objects[0].shape_index=shape
		var p:Dictionary=sample.objects[0].polygons[0].duplicate(true)
		p.primitive=11
		sample.objects[0].polygons.append(p)
		sample.objects[0].draw_order=[{"kind":"polygon","index":0},{"kind":"polygon","index":1}]
		var front:=await render(sample,true)
		check(front.get_pixel(642,402)==Color8(160,100,55),"last observed crew sheet owns overlap")
		var repeat:=await render(sample,true)
		check(front.get_data()==repeat.get_data(),"crew coplanar paint stable across repeated frames")
		sample.objects[0].draw_order.reverse()
		var reversed:=await render(sample,true)
		check(reversed.get_pixel(642,402)==Color8(90,110,70),"crew depth follows changed original painter order")
		sample.objects[0].draw_order.reverse()
		var restored:=await render(sample,true)
		check(restored.get_data()==front.get_data(),"crew painter order restores exact pixels")
		# A later unrelated source object still masks the crew, regardless of
		# the deliberately elevated internal depth used by the planar sheets.
		var occluder:Dictionary=sample.objects[0].duplicate(true)
		occluder.shape_index=999;occluder.pointer=100
		for poly:Dictionary in occluder.polygons:poly.colors=[1,1]
		sample.objects.append(occluder)
		var hidden:=await render(sample,true)
		check(hidden.get_pixel(642,402)==Color8(236,236,220),"crew painter depth cannot cross source object ownership")
	check(art.configure(fixture()),"normal fixture restored after crew layers")

func running_gear_contract() -> void:
	var object := {"pointer":99,"shape_index":115,"dynamic_instance":true}
	var sample := {"world":{"window_origin":[0,0],"dynamic":[{"pointer":99,"shape_index":115,"world_position_raw":[100,200,5],"orientation_u8":[0,0,0]}]}}
	var a := Modern.running_gear_anchor(object,sample)
	check(a==100+sqrt(2.0)*200,"running gear not linked to paired absolute source position")
	sample.camera={"matrix_q14_columns":[0,16384,0,-16384,0,0,0,0,16384]}
	sample.world.dynamic[0].orientation_u8=[0,0,99]
	check(Modern.running_gear_anchor(object,sample)==a,"stationary camera/yaw changes spun running gear")
	sample.world.dynamic[0].world_position_raw[0]+=5
	check(Modern.running_gear_anchor(object,sample)==a+5,"source translation failed to change gear phase")
	sample.world.dynamic[0].world_position_raw[0]-=5
	check(Modern.running_gear_anchor(object,sample)==a,"source reversal failed to restore gear phase")
	for direction in [Vector2i(1,-1),Vector2i(-1,1)]:
		sample.world.dynamic[0].world_position_raw[0]+=direction.x
		sample.world.dynamic[0].world_position_raw[1]+=direction.y
		check(Modern.running_gear_anchor(object,sample)!=a,"integer diagonal source travel cancelled gear phase")
		sample.world.dynamic[0].world_position_raw[0]-=direction.x
		sample.world.dynamic[0].world_position_raw[1]-=direction.y
		check(Modern.running_gear_anchor(object,sample)==a,"diagonal reversal failed to restore gear phase")
	sample.world.window_origin=[20,-30]
	sample.world.dynamic[0].position_local_raw=[-123,456,5]
	check(Modern.running_gear_anchor(object,sample)==a,"streaming rebase changed world-anchored gear phase")
	sample=JSON.parse_string(JSON.stringify(sample))
	check(Modern.running_gear_anchor(object,sample)==a,"serialized source restore changed gear phase")
	object.dynamic_instance=false
	check(is_nan(Modern.running_gear_anchor(object,sample)),"static object acquired running-gear motion")
	object.dynamic_instance=true; object.shape_index=-1
	check(is_nan(Modern.running_gear_anchor(object,sample)),"unmatched reused slot acquired gear motion")
	var gear := fixture()
	gear.models[0].triangles[0].motion={"kind":"wheel","center":[0,0,0],"radius":40}
	var wheel = Modern.new()
	check(wheel.configure(gear),"wheel marking metadata rejected")
	var packet_data:=packet()
	var actor: Dictionary=packet_data.objects[0]
	var face: Dictionary=actor.polygons[0]
	var base:=wheel.mapping(actor,face,frame,packet_data.palette_rgb,false,a)
	var moved:=wheel.mapping(actor,face,frame,packet_data.palette_rgb,false,a+5)
	var restored:=wheel.mapping(actor,face,frame,packet_data.palette_rgb,false,a)
	check(JSON.stringify(base)==JSON.stringify(restored),"restored running gear differs byte-for-byte")
	check(JSON.stringify(base)!=JSON.stringify(moved),"displacement did not change wheel markings")
	for i in base.size():
		for j in base[i].points.size():
			check(base[i].points[j].slice(0,3)==moved[i].points[j].slice(0,3),"running gear moved source-aligned geometry")

func observed_round_fixture() -> void:
	var path:=directory.path_join("local-art/pc-modern/round-form-fixture.json")
	check(FileAccess.file_exists(path),"observed original ellipse fixture missing")
	if not FileAccess.file_exists(path): return
	var sample: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	sample.materials=packet().materials
	sample.background={"kind":"solid","color":15}
	var image:=await render(sample,false)
	image.save_png(output.path_join("observed-source-round-form.png"))
	var expected: Dictionary={}
	for object: Dictionary in sample.objects:
		for form: Dictionary in object.round_forms:
			for span: Dictionary in form.spans:
				for x in range(int(span.left),int(span.right)): expected[Vector2i(x,int(span.y))]=int(span.color)
	check(expected.size()==868,"observed CPU ellipse coverage changed")
	for y in range(int(sample.camera.clip[1]),int(sample.camera.clip[3])+1):
		for x in range(int(sample.camera.clip[0]),int(sample.camera.clip[2])+1):
			var index: int=expected.get(Vector2i(x,y),15)
			var rgb: Array=sample.palette_rgb[index]
			var actual:=image.get_pixel((x-int(sample.camera.clip[0]))*4+2,(y-int(sample.camera.clip[1]))*4+2)
			check(actual==Color8(int(rgb[0]),int(rgb[1]),int(rgb[2])),"original CPU round-form color/coverage differs at %d,%d"%[x,y])

func crew_head_commands() -> void:
	var path:=directory.path_join("local-art/pc-modern/round-span-proof.json")
	check(FileAccess.file_exists(path),"original CPU crew-head proof exists")
	if not FileAccess.file_exists(path):return
	var proof:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("local-art/pc-modern/catalog.json")))
	var exercised:=0
	for witness:Dictionary in proof.cases:
		if int(witness.shape_index) not in [161,162] or witness.center[0]!=160:continue
		exercised+=1
		var sample:=packet();sample.camera.clip=[0,0,319,199];sample.camera.center=[160,55];sample.camera.focal_pixels=256
		sample.background={"kind":"solid","color":15}
		var form:Dictionary=witness.form
		var object:Dictionary={"shape_index":witness.shape_index,"polygons":[],"round_forms":[form],"draw_order":[{"kind":"round_form","index":0}]}
		sample.objects=[object]
		check(preload("res://scripts/pc_modern_source_commands.gd").crew_head(object,form),"known captured crew head binds")
		var original:=await render(sample,false)
		var refined:=await render(sample,true)
		original.save_png(output.path_join("head-%d-source.png"%int(witness.shape_index)))
		refined.save_png(output.path_join("head-%d-modern.png"%int(witness.shape_index)))
		# Modern deliberately softens the original palette's white background.
		# Compare occupancy against each mode's background, not EGA RGB equality.
		var modern_background:=refined.get_pixel(0,0)
		var skin:=0;var helmet:=0;var coverage:=0;var escaped:=0;var lost:=0
		for y in 200:
			for x in 320:
				var a:=original.get_pixel(x*4+2,y*4+2);var b:=refined.get_pixel(x*4+2,y*4+2)
				if a==Color.WHITE:
					if b!=modern_background:escaped+=1
				else:
					coverage+=1
					if b==modern_background:lost+=1
					if b.r>b.g*1.12 and b.g>b.b*1.15:skin+=1
					if b.g>b.r*1.08 and b.g>b.b*1.2:helmet+=1
		check(coverage==int(witness.pixels_matched) and skin>30 and helmet>30,"both helmet and face visible within exact head coverage")
		check(escaped==0 and lost==0,"head coverage mismatch: %d outside, %d lost"%[escaped,lost])
		check((await render(sample,false)).get_data()==original.get_data(),"crew head EGA switch restores exact pixels")
		check((await render(sample,true)).get_data()==refined.get_data(),"crew head Modern switch restores exact pixels")
		var bad:=form.duplicate(true);bad.command_offset+=1
		check(not preload("res://scripts/pc_modern_source_commands.gd").crew_head(object,bad),"unknown head command rejected")
		bad=form.duplicate(true);bad.radius=0
		check(not preload("res://scripts/pc_modern_source_commands.gd").crew_head(object,bad),"empty source head not invented")
		bad=form.duplicate(true);bad.status="rejected-before-raster"
		check(not preload("res://scripts/pc_modern_source_commands.gd").crew_head(object,bad),"near rejected source head not invented")
		# Complete crew pose for visual inspection, using the existing source
		# polygons plus the independently witnessed original head raster.
		var model:Dictionary=catalog.models[int(witness.shape_index)]
		object.root=model.roots[0].offset;object.static_path=true;object.dynamic_instance=false
		object.draw_order=[]
		for p:Dictionary in model.source_primitives:
			if p.vertices.size()<3:continue
			var points:Array=[]
			for v:Array in p.vertices:points.append([v[0],float(v[1])+256,v[2]])
			object.draw_order.append({"kind":"polygon","index":object.polygons.size()})
			object.polygons.append({"primitive":p.id,"camera_vertices":points,"fill_mode":1,"colors":p.prefix_bytes.slice(1,3)})
		object.draw_order.append({"kind":"round_form","index":0})
		var full:=await render(sample,true)
		full.save_png(output.path_join("crew-%d-complete.png"%int(witness.shape_index)))
		check(draw.source_round_count==1 and draw.modern_polygon_count>5,"complete crew retains head and refined body")
	check(exercised==2,"both original Sagger and Spigot head witnesses exercised")

func running_gear_pixels(sample: Dictionary, original: Image) -> void:
	check(draw.modern_running_gear_triangles>0,"paired dynamic running gear had no native markings")
	var repeated:=await render(sample,true)
	check(original.get_data()==repeated.get_data(),"held original position changed running-gear pixels")
	var moved:=sample.duplicate(true)
	for actor: Dictionary in moved.world.dynamic:
		if int(actor.pointer)==int(moved.objects[0].pointer): actor.world_position_raw[0]+=5
	var translated:=await render(moved,true)
	var changed:=0
	var outside:=0
	var mask: Image=draw.ownership.get_texture().get_image()
	for y in original.get_height():
		for x in original.get_width():
			if original.get_pixel(x,y)!=translated.get_pixel(x,y):
				changed+=1
				if roundi(mask.get_pixel(x,y).r*255)!=1: outside+=1
	check(changed>0,"source displacement produced no visible running-gear change")
	check(outside==0,"running-gear markings escaped source actor ownership")
	var restored:=await render(sample,true)
	check(original.get_data()==restored.get_data(),"restored source position did not restore native running gear exactly")
	translated.save_png(output.path_join("t62-running-gear-translated-phase.png"))

func quiet_source_dither(data: Dictionary) -> void:
	var sample := data.duplicate(true)
	# Unsupported shape retains its source face, while Modern resolves dither.
	sample.objects[0].shape_index=-1
	sample.materials[3]=[0x0203,0x0302]
	var legacy := await render(sample,false)
	check(legacy.get_pixel(640,400)!=legacy.get_pixel(644,400),"legacy source dither unexpectedly flattened")
	var modern := await render(sample,true)
	var rgb: Array=preload("res://scripts/pc_terrain_style.gd").material_mean(Modern.DAY_PALETTE,sample.materials[3])
	var expected:=Color8(int(rgb[0]),int(rgb[1]),int(rgb[2]))
	for p in [Vector2i(640,400),Vector2i(644,400),Vector2i(640,404),Vector2i(644,404)]:
		check(modern.get_pixelv(p)==expected,"Modern source mean differs: actual %s expected %s"%[modern.get_pixelv(p),expected])
	sample.palette_rgb[3]=[100,80,60]
	legacy=await render(sample,false)
	modern=await render(sample,true)
	check(legacy.get_data()==modern.get_data(),"unsupported palette dither altered by Modern mean path")

func mesh_reuse_contract(data: Dictionary) -> void:
	draw.profile_builds=true
	draw.clear_mesh_cache()
	draw.modern_enabled=true
	draw.apply_pass(data)
	check(not draw.last_apply_timings_usec.reused and draw.last_apply_timings_usec.total>=draw.last_apply_timings_usec.ownership+draw.last_apply_timings_usec.mapping+draw.last_apply_timings_usec.upload,"build timing breakdown missing or overlapping")
	var built: int=draw.mesh_build_count
	var reused: int=draw.mesh_reuse_count
	var original_mesh=draw.mesh_node.mesh
	var owner_mesh=draw.ownership.mesh_node.mesh
	draw.apply_pass(data.duplicate(true))
	check(draw.mesh_build_count==built and draw.mesh_reuse_count==reused+1,"identical full packet did not reuse")
	check(draw.last_apply_timings_usec.reused and draw.last_apply_timings_usec.ownership==0 and draw.last_apply_timings_usec.mapping==0 and draw.last_apply_timings_usec.upload==0,"cache hit reported stale build timings")
	check(draw.mesh_node.mesh==original_mesh and draw.ownership.mesh_node.mesh==owner_mesh,"reuse replaced meshes")
	var redelivered := data.duplicate(true)
	redelivered.sequence=200
	redelivered.start_ram_sha256="different audit, same complete observed rendering"
	redelivered.page_offset=8192
	draw.apply_pass(redelivered)
	check(draw.mesh_build_count==built and draw.mesh_node.mesh==original_mesh,"delivery counters rebuilt identical render inputs")
	redelivered.world={"dynamic":[{"pointer":999,"shape_index":115,"world_position_raw":[10,20,30]}]}
	draw.apply_pass(redelivered)
	redelivered.world.dynamic[0].world_position_raw[0]+=30
	draw.apply_pass(redelivered)
	check(draw.mesh_build_count==built,"off-screen movement rebuilt unchanged visible geometry")
	redelivered.world.dynamic[0].pointer=99
	draw.apply_pass(redelivered)
	check(draw.mesh_build_count==built+1,"visible running-gear phase change incorrectly reused")
	draw.apply_pass(data)
	built=draw.mesh_build_count
	var altered:=data.duplicate(true)
	altered.objects[0].polygons[0].camera_vertices[0][0]+=1
	draw.apply_pass(altered)
	check(draw.mesh_build_count==built+1,"mutated same-identity packet incorrectly reused")
	altered.objects[0].polygons[0].camera_vertices[0][0]+=1
	draw.apply_pass(altered)
	check(draw.mesh_build_count==built+2,"in-place packet mutation changed cached snapshot")
	built+=1
	draw.apply_pass(data)
	check(draw.mesh_build_count==built+2,"restore reused later packet")
	check(draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==original_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"restore mesh differs")
	built=draw.mesh_build_count
	draw.presentation_palette=[[1,2,3]]
	draw.apply_pass(data)
	check(draw.mesh_build_count==built+1,"presentation palette change reused")
	draw.presentation_palette=[]
	draw.modern_enabled=false
	draw.apply_pass(data)
	check(draw.mesh_build_count==built+2,"mode change reused")
	draw.modern_enabled=true
	draw.apply_pass(data)
	built=draw.mesh_build_count
	var dimensions:=viewport.size
	viewport.size=dimensions+Vector2i(4,4)
	draw.apply_pass(data)
	check(draw.mesh_build_count==built+1,"viewport resize reused owner mesh")
	viewport.size=dimensions
	art.configure(fixture())
	built=draw.mesh_build_count
	draw.apply_pass(data)
	check(draw.mesh_build_count==built+1,"resource reload reused")
	draw.apply_pass({"objects":[]})
	check(draw._cached_pass.is_empty() and draw.mesh_node.mesh==null and draw.ownership.mesh_node.mesh==null,"empty pass retained cache")
	draw.apply_pass(data)
	var unsupported:=data.duplicate(true)
	unsupported.palette_rgb[3]=[1,2,3]
	draw.apply_pass(unsupported)
	check(draw._cached_pass.is_empty(),"unsupported Modern palette retained cache")
	draw.apply_pass(data)
	art.ready=false
	draw.apply_pass(data)
	check(draw._cached_pass.is_empty(),"unavailable resources retained cache")
	art.configure(fixture())
	draw.apply_pass(data)

func affine_invariant_contract() -> void:
	var source: Array=fixture().models[0].source_primitives["10"]
	var observed: Array=[]
	for p: Array in source: observed.append([p[0]*1.25+p[2]*0.5,160+p[0]*0.25,p[2]*0.75])
	var fit:=Modern.anchor_frame(source,observed,frame)
	check(not fit.is_empty() and not fit.get("piecewise",false),"affine invariant fixture did not fit")
	for x in [-100.0,-40.0,0.0,40.0,100.0]:
		for z in [-50.0,-20.0,0.0,20.0,80.0]:
			var point:=Vector3(x,-4,z)
			var d: Vector3=point-fit.origin
			var u: Vector3=fit.u
			var v: Vector3=fit.v
			var determinant:=u.length_squared()*v.length_squared()-pow(u.dot(v),2)
			var a: float=(d.dot(u)*v.length_squared()-d.dot(v)*u.dot(v))/determinant
			var b: float=(d.dot(v)*u.length_squared()-d.dot(u)*u.dot(v))/determinant
			var original: Vector3=fit.camera+fit.cu*a+fit.cv*b+fit.cn*d.dot(fit.n)
			check(Modern.transform_point(point,fit)==original,"precomputed affine scalar changed original operation result")

func retained_owner_mask(data: Dictionary) -> void:
	draw.retain_render_target=true
	draw.clear_mesh_cache()
	var initial:=await render(data,true)
	var owner: Image=draw.ownership.get_texture().get_image()
	var builds: int=draw.mesh_build_count
	var hits: int=draw.mesh_reuse_count
	# Deliberately hide owner geometry without requesting an update. If the
	# viewport redraws on a hit, its cleared mask will expose this sentinel.
	draw.ownership.mesh_node.visible=false
	draw.mesh_node.visible=false
	for i in 3:
		var repeated:=await render(data.duplicate(true),true)
		check(repeated.get_data()==initial.get_data(),"reused packet changed native scene pixels")
		check(draw.ownership.get_texture().get_image().get_data()==owner.get_data(),"one-shot owner mask lost pixels on cache hit")
	check(draw.mesh_build_count==builds and draw.mesh_reuse_count==hits+3,"retained-mask fixture did not hit mesh reuse")
	draw.ownership.mesh_node.visible=true
	draw.mesh_node.visible=true
	var moved:=data.duplicate(true)
	for p: Array in moved.objects[0].polygons[0].camera_vertices: p[0]+=50
	await render(moved,true)
	check(draw.ownership.get_texture().get_image().get_data()!=owner.get_data(),"new paired packet failed to update one-shot mask")
	var restored:=await render(data,true)
	check(restored.get_data()==initial.get_data() and draw.ownership.get_texture().get_image().get_data()==owner.get_data(),"restored packet failed to restore one-shot mask")
	viewport.size+=Vector2i(4,4)
	draw.apply_pass(data)
	await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
	var resized:=viewport.get_texture().get_image()
	check(resized.get_size()==Vector2i(1284,804) and resized.get_pixel(642,402)==initial.get_pixel(640,400),"retained viewport resize failed to redraw")
	restored=await render(data,true)
	check(restored.get_data()==initial.get_data(),"retained viewport size restoration changed pixels")
	draw.apply_pass({"objects":[]})
	await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
	check(viewport.get_texture().get_image().get_data()!=initial.get_data(),"empty pass retained the prior world image")
	draw.retain_render_target=false
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS

func material_variation_contract() -> void:
	var fixture_object := {"shape_index":34,"root":3567,"static_path":true,"dynamic_instance":false}
	var polygon := {"primitive":3581,"fill_mode":1,"colors":[4.0,4.0]}
	check(Modern.water_surface(fixture_object,polygon),"pinned river polygon accepts water detail")
	for field in ["shape_index","root","static_path","dynamic_instance"]:
		var bad := fixture_object.duplicate(true)
		bad[field] = true if field=="dynamic_instance" else false if field=="static_path" else -1
		check(not Modern.water_surface(bad,polygon),"unbound water identity rejected: "+field)
	for field in ["primitive","fill_mode","colors"]:
		var bad := polygon.duplicate(true)
		bad[field]=[5,5] if field=="colors" else -1
		check(not Modern.water_surface(fixture_object,bad),"unbound water polygon rejected: "+field)
	var walls := 0
	var roofs := 0
	var clay_roofs := 0
	for shape in art.models:
		for face: Dictionary in art.models[shape].faces.values():
			for triangle: Dictionary in face.triangles:
				var kind: float=triangle.structure_kind
				if int(shape)>=115 and int(shape)<=144: check(kind in [20.0,Modern.ARMOUR_PAINT],"vehicle cannot inherit building textures")
				if kind==20.375: walls+=1
				if kind==20.4375: roofs+=1
				if kind==20.46875: clay_roofs+=1
				if int(shape) in [147,149,155]: check(kind!=20.46875,"flat source roof and its bevels cannot inherit clay")
	check(walls>0 and roofs>0,"verified structures supply both wall and roof variants")
	check(clay_roofs>0,"civilian upper surfaces supply restrained clay roof colour")
	for shape in art.models:
		var painted:=0
		for face:Dictionary in art.models[shape].faces.values():
			for triangle:Dictionary in face.triangles:
				if triangle.structure_kind==Modern.HIND_PAINT:painted+=1
		check(painted>0 if shape in [163,164] else painted==0,"Hind livery scope: %d"%shape)

func hind_livery_contract() -> void:
	# Exercise the material classifier and interpolated UVs independently of the
	# paint shader, including camera rotation, clipping, rebase and restore.
	for shape in [115,129,131,133,135,137,139,141,143,159,163,164]:
		for material in ["olive","olive_edge","glass","cockpit","vent","signal_red","canvas","canvas_edge"]:
			var source:=fixture()
			source.models[0].shape_index=shape
			source.models[0].paint_style="two_tone_olive"
			source.models[0].triangles[0].material=material
			var paint:=Modern.new()
			check(paint.configure(source),"paint fixture accepted")
			var wanted:bool=(shape in [163,164] or shape in Modern.TWO_TONE_SHAPES) and material in ["olive","olive_edge"]
			var kind:float=paint.models[shape].faces[10].triangles[0].structure_kind
			check(kind==(Modern.HIND_PAINT if shape in [163,164] else Modern.ARMOUR_PAINT) if wanted else kind==20.0,"paint scope excludes tanks, glass, intakes, accents and canvas")
			for depth in [160.0,24.0]:
				var rotation:=Basis(Vector3.UP,0.4)*Basis(Vector3.FORWARD,0.3)
				var data:=packet()
				var actor:Dictionary=data.objects[0]
				actor.shape_index=shape
				var polygon:Dictionary=actor.polygons[0]
				polygon.camera_vertices=[]
				for raw:Array in source.models[0].source_primitives["10"]:
					var p:=rotation*Modern.vec(raw)+Vector3(0,depth,0)
					polygon.camera_vertices.append([p.x,p.y,p.z])
				var facets:=paint.mapping(actor,polygon,data.camera,data.palette_rgb,false)
				check(not facets.is_empty(),"rotated/near-clipped paint remains visible")
				for facet:Dictionary in facets:
					for point:Array in facet.points:
						check(point.size()==(5 if wanted else 3),"paint adds UVs only to tagged Hind facets")
						if wanted:
							var raw:=rotation.inverse()*(Modern.vec(point)-Vector3(0,depth,0))
							var expected:=Vector2(raw.y,raw.z) if shape in [163,164] else Vector2(raw.y+raw.x*.45,raw.z+raw.x*.25)
							check(Vector2(point[3],point[4]).distance_to(expected)<0.001,"local paint coordinates survive source transform and near clipping")
				data.camera.world_position_raw=[30000,-30000,50]
				data.epoch=99;data.sequence=0
				check(JSON.stringify(facets)==JSON.stringify(paint.mapping(actor,polygon,data.camera,data.palette_rgb,false)),"source rebase/restore cannot slide Hind paint")

func roof_grain_contract() -> void:
	# A roof whose normal leans along x (structure_axis 0) and one leaning along y
	# (axis 1) both carry (x,y) object-local grain, never a 1-D (y,y) line.
	for lean in [Vector2(0.2,0.0),Vector2(0.0,0.2)]:
		var source:=fixture()
		var model:Dictionary=source.models[0]
		model.shape_index=47
		model.source_primitives["10"]=[[-40,-20,0],[40,-20,0],[40,20,0],[-40,20,0]]
		var vertices:=[]
		for p:Array in [[-100,-50],[100,-50],[0,80]]: vertices.append([p[0],p[1],roundi(p[0]*lean.x+p[1]*lean.y)-4])
		model.triangles=[{"source_primitive":10,"vertices":vertices,"color":[150,90,70],"material":"roof"}]
		var roof:=Modern.new()
		check(roof.configure(source),"roof grain fixture accepted")
		if not roof.ready: continue
		var triangle:Dictionary=roof.models[47].faces[10].triangles[0]
		check(triangle.structure_kind==20.4375 and triangle.structure_axis==(0 if lean.x>0 else 1),"roof fixture covers structure axis %d"%(0 if lean.x>0 else 1))
		var data:=packet()
		var actor:Dictionary=data.objects[0]
		actor.shape_index=47
		var polygon:Dictionary=actor.polygons[0]
		polygon.camera_vertices=[]
		for raw:Array in model.source_primitives["10"]: polygon.camera_vertices.append([raw[0],raw[1]+160,raw[2]])
		var facets:=roof.mapping(actor,polygon,data.camera,data.palette_rgb,false)
		check(not facets.is_empty(),"roof grain fixture maps")
		for facet:Dictionary in facets:
			for point:Array in facet.points:
				check(point.size()==5,"roof facet carries surface coordinates")
				if point.size()!=5: continue
				var raw:=Modern.vec(point)-Vector3(0,160,0)
				check(Vector2(point[3],point[4]).distance_to(Vector2(raw.x,raw.y))<0.01,"roof grain uses both horizontal object-local axes")

func bridge_fixture() -> Dictionary:
	var source:=fixture();var model:Dictionary=source.models[0]
	model.shape_index=0
	model.source_primitives["20"]=[[-40,0,40],[40,0,40]]
	model.groups[0].primitive_pointers.append(20)
	model.source_lines=[{"source_primitive":20,"vertices":model.source_primitives["20"].duplicate(true),"prefix_bytes":[255,0,2],"color":[133,157,171]}]
	return source

func bridge_line_contract() -> void:
	var bridge:=Modern.new();check(bridge.configure(bridge_fixture()),"bridge line palette loads")
	var actor:={"shape_index":0,"root":1,"static_path":true,"dynamic_instance":false}
	var line:={"primitive":20,"colors":[0,2],"fill_mode":0,"camera_vertices":[[-40,160,40],[40,160,40]]}
	check(bridge.bridge_line_colour_index(actor,line,Modern.PC_PALETTE)>=0,"verified source bridge line receives steel colour")
	for serialized in [false,true]:
		check(bridge.configure(JSON.parse_string(JSON.stringify(bridge_fixture())) if serialized else bridge_fixture()),"integer/JSON bridge catalogue loads")
		for trace_json in [false,true]:
			var trace:Dictionary=JSON.parse_string(JSON.stringify(line)) if trace_json else line
			check(bridge.bridge_line_colour_index(actor,trace,Modern.PC_PALETTE)>=0,"bridge binding accepts mixed integer/JSON numeric representations")
	for field in ["shape_index","root","static_path","dynamic_instance"]:
		var bad:=actor.duplicate(true);bad[field]=true if field=="dynamic_instance" else false if field=="static_path" else -1
		check(bridge.bridge_line_colour_index(bad,line,Modern.PC_PALETTE)==-1,"unverified bridge identity retains original colour: "+field)
	for field in ["primitive","colors","camera_vertices"]:
		var bad:=line.duplicate(true);bad[field]=-1 if field=="primitive" else [3,2] if field=="colors" else [[0,160,0],[10,160,0],[0,160,10]]
		check(bridge.bridge_line_colour_index(actor,bad,Modern.PC_PALETTE)==-1,"unverified source line retains original colour: "+field)
	var palette:Array=Modern.PC_PALETTE.duplicate(true);palette[0]=[1,2,3]
	check(bridge.bridge_line_colour_index(actor,line,palette)==-1,"sensor/fallback palette cannot acquire bridge paint")
	for field in ["color","vertices","prefix_bytes"]:
		var bad:=bridge_fixture();bad.models[0].source_lines[0][field]=[256,0,0] if field=="color" else []
		check(not bridge.configure(bad),"malformed bridge metadata fails closed: "+field)

func bridge_line_pixels() -> void:
	var saved=art
	art=Modern.new();draw.modern_assets=art;draw.clear_mesh_cache()
	var source:Dictionary=JSON.parse_string(JSON.stringify(bridge_fixture()));check(art.configure(source),"native JSON bridge palette loads")
	var data:=packet();data.background={"kind":"solid","color":15}
	data.objects=[{"shape_index":0,"root":1,"static_path":true,"dynamic_instance":false,"polygons":[{"primitive":20,"colors":[0,2],"fill_mode":0,"camera_vertices":[[-40,160,40],[40,160,40]]}]}]
	var painted:=await render(data,true)
	var vertices:PackedVector3Array=draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
	source.models[0].source_lines[0].erase("color");check(art.configure(source),"old bridge catalogue remains supported")
	var before:=await render(data,true)
	check(vertices==draw.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"bridge recolour keeps exact source line geometry and width")
	var changed:=0;var outside:=0;var wrong:=0
	for y in painted.get_height():
		for x in painted.get_width():
			var c:=painted.get_pixel(x,y)
			if c==before.get_pixel(x,y):continue
			changed+=1
			if before.get_pixel(x,y)==before.get_pixel(0,0):outside+=1
			if c!=Color8(133,157,171):wrong+=1
	check(changed>100 and outside==0 and wrong==0,"bridge recolour changes only original line pixels to calibrated steel blue")
	check(art.configure(bridge_fixture()),"bridge palette restores")
	var restored:=await render(data,true)
	check(restored.get_data()==painted.get_data(),"bridge restore is byte-exact")
	painted.save_png(output.path_join("bridge-line-highlight.png"))
	art=saved;draw.modern_assets=art;draw.clear_mesh_cache()
