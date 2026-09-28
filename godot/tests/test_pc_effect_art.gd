extends SceneTree
const Art = preload("res://scripts/pc_effect_art.gd")
const DrawPass = preload("res://scripts/pc_draw_pass.gd")
const Camera = preload("res://scripts/pc_camera.gd")
const Geometry = preload("res://scripts/pc_surface_geometry.gd")
var errors: Array[String] = []
var checks := 0
var native_pixels := 0
var changed_pixels := 0
var color_samples := 0
var max_color_error := 0
var style: RefCounted
var view: Node3D
var viewport: SubViewport
var camera: Camera3D
var output: String
var frame := {"clip":[32,13,287,109],"center":[159,61],"near_raw":16,"focal_pixels":128,
	"matrix_q14_columns":[16384,0,0,0,16384,0,0,0,16384],"world_position_raw":[0,0,0]}

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok and errors.size()<20: errors.append(message)

func object_for(index: int, origin: Array = [128,50]) -> Dictionary:
	var sprite: Dictionary = style.sources[index].duplicate(true)
	sprite.flags = 8
	sprite.origin = origin
	sprite.clip = frame.clip.duplicate()
	return {"kind":"sprite","sprite_status":"observed","bitmap_index":index,"root":Art.ROOTS[index],
		"shape_index":183+int(Art.DONORS[index]),"dynamic_instance":true,"sprite":sprite,"polygons":[]}

func sample(object: Dictionary) -> Dictionary:
	var materials := []
	for i in 32: materials.append([i%16,i%16])
	return {"camera":frame,"palette_rgb":Art.PC_PALETTE,"materials":materials,
		"background":{"kind":"solid","color":8},"objects":[object]}

func snapshot(data: Dictionary, enabled: bool) -> Image:
	view.effect_art = style if enabled else null
	view.apply_pass(data)
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return viewport.get_texture().get_image()

func cover(box: Rect2, depth: float = 2048.0) -> Dictionary:
	var points := []
	for p in [box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]:
		points.append(Geometry.unproject(p,depth,frame))
	return {"static_path":1,"polygons":[{"camera_vertices":points,"colors":[9,9],"fill_mode":1}]}

func compare_outside(a: Image, b: Image, box: Rect2, message: String) -> int:
	var changed := 0
	var scale := Vector2(viewport.size)/Vector2(256,97)
	var origin := Vector2(frame.clip[0],frame.clip[1])
	for y in a.get_height():
		for x in a.get_width():
			var point := (Vector2(x,y)+Vector2(0.5,0.5))/scale+origin
			var equal := a.get_pixel(x,y).to_rgba32()==b.get_pixel(x,y).to_rgba32()
			if not box.has_point(point): check(equal,message)
			elif not equal: changed += 1
			native_pixels += 1
	changed_pixels += changed
	return changed

func check_authored_colors(image: Image, mapping: Dictionary) -> void:
	var source: Image = style.textures[int(mapping.donor)].get_image()
	var box: Rect2 = mapping.rect
	var target: Rect2 = mapping.target
	var source_uv: Rect2 = mapping.source_uv
	var scale := Vector2(viewport.size)/Vector2(256,97)
	var origin := Vector2(frame.clip[0],frame.clip[1])
	for y in range(floori((box.position.y-origin.y)*scale.y),ceili((box.end.y-origin.y)*scale.y)):
		for x in range(floori((box.position.x-origin.x)*scale.x),ceili((box.end.x-origin.x)*scale.x)):
			var point := (Vector2(x,y)+Vector2(0.5,0.5))/scale+origin
			if not box.has_point(point): continue
			var uv := source_uv.position+(point-target.position)/target.size*source_uv.size
			var texel := uv*Vector2(source.get_size())-Vector2(0.5,0.5)
			var lo := Vector2i(floori(texel.x),floori(texel.y))
			var fraction := texel-Vector2(lo)
			var colors: Array[Color] = []
			for offset in [Vector2i.ZERO,Vector2i(1,0),Vector2i(0,1),Vector2i.ONE]:
				var p: Vector2i = (lo+offset).clamp(Vector2i.ZERO,source.get_size()-Vector2i.ONE)
				colors.append(source.get_pixelv(p))
			var expected := colors[0].lerp(colors[1],fraction.x).lerp(colors[2].lerp(colors[3],fraction.x),fraction.y)
			if expected.a<0.99: continue # Edge-alpha threshold has a separate cutout check.
			var actual := image.get_pixel(x,y)
			for c in 3:
				var error := absi(roundi(actual[c]*255)-roundi(expected[c]*255))
				max_color_error = maxi(max_color_error,error)
				check(error<=1,"authored RGB differs from independently sampled texture")
			color_samples += 1

func run() -> void:
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	output = directory.path_join("artifacts/pc-effect-art-test")
	var args := OS.get_cmdline_user_args()
	if "--output" in args: output = args[args.find("--output")+1]
	DirAccess.make_dir_recursive_absolute(output)
	style = Art.new()
	check(not style.load_assets(directory.path_join("absent")),"missing assets accepted")
	check(style.textures.is_empty(),"failed load retained textures")
	check(style.load_assets(directory),"pinned source/art unavailable")
	if style.textures.size()!=3: finish(); return
	for index: int in Art.DONORS:
		var object := object_for(index)
		var mapping: Dictionary = style.mapping(object,frame,Art.PC_PALETTE)
		check(not mapping.is_empty(),"verified source rejected: %d" % index)
		check(mapping.donor==Art.DONORS[index],"original detail-level donor mismatch")
		check(mapping.rect==Rect2(Vector2(128,50),style.bounds[index].size),"source anchor or padding changed")
		var damaged := object.duplicate(true)
		damaged.sprite.pixels[0] = 15
		check(style.mapping(damaged,frame,Art.PC_PALETTE).is_empty(),"changed source pixel accepted")
		damaged = object.duplicate(true)
		damaged.sprite.opaque[0] = not damaged.sprite.opaque[0]
		check(style.mapping(damaged,frame,Art.PC_PALETTE).is_empty(),"changed preservation mask accepted")
		for key in ["root","shape_index","bitmap_index"]:
			damaged = object.duplicate(true)
			damaged[key] += 1
			check(style.mapping(damaged,frame,Art.PC_PALETTE).is_empty(),"unrecognized source identity accepted")
		for origin in [[29,12],[283,107],[300,50],[128,111],[-100,20]]:
			var clipped := object_for(index,origin)
			var actual: Dictionary = style.mapping(clipped,frame,Art.PC_PALETTE)
			var box: Rect2 = style.bounds[index]
			box.position += Vector2(origin[0],origin[1])
			var expected := box.intersection(Rect2(32,13,256,97))
			check(actual.is_empty() if not expected.has_area() else actual.rect==expected,"source clip changes registration")
	var unknown := Art.PC_PALETTE.duplicate(true)
	unknown[6] = [1,2,3]
	check(style.mapping(object_for(51),frame,unknown).is_empty(),"unknown/thermal palette accepted")
	var unsupported := object_for(51)
	unsupported.sprite.flags = 0
	check(style.mapping(unsupported,frame,Art.PC_PALETTE).is_empty(),"unknown native flags accepted")
	unsupported = object_for(51)
	unsupported.sprite.origin = [NAN,50]
	check(style.mapping(unsupported,frame,Art.PC_PALETTE).is_empty(),"nonfinite position accepted")
	unsupported = object_for(51)
	unsupported.sprite_status = "rejected-before-blit"
	check(style.mapping(unsupported,frame,Art.PC_PALETTE).is_empty(),"originally rejected effect was revealed")
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	var native_scale := 4
	if "--native-scale" in args: native_scale = int(args[args.find("--native-scale")+1])
	check(native_scale in [4,5],"unsupported native test scale")
	if native_scale not in [4,5]: finish(); return
	viewport.size = Vector2i(256,97)*native_scale
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	camera = Camera3D.new()
	viewport.add_child(camera)
	Camera.apply(camera,frame,Vector3.ZERO)
	camera.make_current()
	view = DrawPass.new()
	view.solid_enabled = true
	camera.add_child(view)
	# Ordered source replay checks selection and disappearance without inventing a
	# playback timer. Native screenshots are separate from this metadata check.
	var replay_path := directory.path_join("artifacts/pc-sprite-controls-02/report.json")
	if FileAccess.file_exists(replay_path):
		var replay = JSON.parse_string(FileAccess.get_file_as_string(replay_path))
		var sequence: Array = []
		view.effect_art = style
		for pass_data: Dictionary in replay.render_passes:
			var before := JSON.stringify(pass_data)
			view.apply_pass(pass_data)
			check(JSON.stringify(pass_data)==before,"presentation changed original source packet")
			check(view.render_warnings.is_empty(),"source pass warning")
			if not view.effect_art_ids.is_empty(): sequence.append([int(pass_data.sequence),view.effect_art_ids.duplicate()])
		check(sequence==[[165,[51]],[166,[51]],[167,[51]],[168,[52]],[169,[52]],[170,[53]],[171,[53]]],"source animation sequence changed")
		FileAccess.open(output.path_join("source-sequence.json"),FileAccess.WRITE).store_string(JSON.stringify(sequence))
	if "--native" in args:
		for index: int in Art.DONORS:
			var data := sample(object_for(index))
			var original := await snapshot(data,false)
			var remaster := await snapshot(data,true)
			var mapping: Dictionary = style.mapping(data.objects[0],frame,Art.PC_PALETTE)
			check(view.effect_art_ids==[index],"native effect not active")
			check(compare_outside(original,remaster,mapping.rect,"effect escaped original bounds")>0,"art made no visible change")
			check_authored_colors(remaster,mapping)
			original.save_png(output.path_join("effect-%02d-original.png" % index))
			remaster.save_png(output.path_join("effect-%02d-remastered.png" % index))
		# Both painter orders, even when a later polygon is farther away.
		var data := sample(object_for(15))
		var occluder := cover(Rect2(120,42,48,44))
		data.objects.append(occluder)
		var covered_original := await snapshot(data,false)
		var covered_remaster := await snapshot(data,true)
		check(covered_original.get_data()==covered_remaster.get_data(),"later geometry failed to cover the effect")
		data.objects.reverse()
		var prior_original := await snapshot(data,false)
		var prior_remaster := await snapshot(data,true)
		check(compare_outside(prior_original,prior_remaster,Rect2(128,50,31,26),"earlier geometry outside effect changed")>0,"earlier geometry covered later effect")
		# Unknown palette uses identical original pixels, not colored artwork.
		data = sample(object_for(52))
		data.palette_rgb = unknown
		var fallback_original := await snapshot(data,false)
		var fallback_styled := await snapshot(data,true)
		check(fallback_original.get_data()==fallback_styled.get_data() and view.effect_art_ids.is_empty(),"unknown palette did not preserve fallback")
		for origin in [[29,12],[283,107]]:
			data = sample(object_for(15,origin))
			var a := await snapshot(data,false)
			var b := await snapshot(data,true)
			var mapping: Dictionary = style.mapping(data.objects[0],frame,Art.PC_PALETTE)
			check(compare_outside(a,b,mapping.rect,"clipped art leaked outside source rectangle")>0,"clipped art missing")
	view.apply_pass({"objects":[]})
	check(view.effect_art_ids.is_empty() and view.mesh_node.mesh==null,"stale effect survived missing original frame")
	finish()

func finish() -> void:
	for error in errors: printerr("FAIL: "+error)
	var report := {"checks":checks,"errors":errors,"native_pixels":native_pixels,"changed_pixels":changed_pixels,
		"color_samples":color_samples,"max_color_error":max_color_error}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PC_EFFECT_ART: %d checks, %d errors; %d native pixels" % [checks,errors.size(),native_pixels])
	quit(0 if errors.is_empty() else 1)
