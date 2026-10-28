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
var modern := false
var backdrop: Image
var modern_contour_pixels := 0
var retained_source_pixels := 0
var particle_material_polish := false
var plume_refinement := false
var source_material_polish := false
var surface_baseline := "res://scripts/pc_surface.gdshader"
var particle_baseline := "res://scripts/pc_tactical_effects.gdshader"
var frame := {"clip":[32,13,287,109],"center":[159,61],"near_raw":16,"focal_pixels":128,
	"matrix_q14_columns":[16384,0,0,0,16384,0,0,0,16384],"world_position_raw":[0,0,0]}

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok and errors.size()<20: errors.append(message)

func object_for(index: int, origin: Array = [128,50]) -> Dictionary:
	var sprite: Dictionary = style.sources[index].duplicate(true)
	sprite.flags = 16 if index==63 else 8
	sprite.origin = origin
	sprite.clip = frame.clip.duplicate()
	return {"kind":"sprite","sprite_status":"observed","bitmap_index":index,"root":Art.ROOTS[index],
		"shape_index":Art.SHAPES[index],"dynamic_instance":true,"sprite":sprite,"polygons":[]}

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

func check_authored_colors(image: Image, mapping: Dictionary, background: Image = null) -> void:
	var source: Image = style.atlas.get_image()
	var box: Rect2 = mapping.rect
	var target: Rect2 = mapping.target
	var source_uv: Rect2 = mapping.source_uv
	var source_sprite: Dictionary=style.sources[int(mapping.index)]
	var sprite_origin: Vector2=target.position-style.bounds[int(mapping.index)].position
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
			var pixel_base: Color=background.get_pixel(x,y) if background else backdrop.get_pixel(x,y)
			var source_at: Vector2i=Vector2i((point-sprite_origin).floor())
			# Modern's original owner mask overrides authored donor alpha. Predict
			# the untouched source/background at unowned pixels, not rectangle art.
			# Working if: transparent source cells stay exact while owned RGB keeps
			# the same one-byte sampler tolerance and source-alpha confinement check.
			var source_owned: bool=source_at.x>=0 and source_at.y>=0 and source_at.x<int(source_sprite.width) and source_at.y<int(source_sprite.height) and source_sprite.opaque[source_at.y*int(source_sprite.width)+source_at.x]
			# The authored quad replaces the original sprite runs. An alpha
			# discard reveals backdrop, while ownership still excludes other owners.
			if (not modern or source_owned) and expected.a>0.49 and expected.a<0.51: continue
			if expected.a<0.5 or (modern and not source_owned): expected=pixel_base
			var actual := image.get_pixel(x,y)
			for c in 3:
				var error := absi(roundi(actual[c]*255)-roundi(expected[c]*255))
				max_color_error = maxi(max_color_error,error)
				check(error<=1,"authored RGB/transparent cutout differs from independent sampler")
			color_samples += 1

func run() -> void:
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	output = directory.path_join("artifacts/pc-effect-art-test")
	var args := OS.get_cmdline_user_args()
	if "--output" in args: output = args[args.find("--output")+1]
	DirAccess.make_dir_recursive_absolute(output)
	style = Art.new()
	check(not style.load_assets(directory.path_join("absent")),"missing assets accepted")
	check(not style.loaded and style.atlas==null and style.sources.is_empty(),"failed load retained textures")
	check(style.load_assets(directory),"pinned source/art unavailable")
	if not style.loaded: finish(); return
	if "--tactical-particles" in args:
		if "--baseline-surface" in args:surface_baseline=args[args.find("--baseline-surface")+1]
		if "--baseline-particles" in args:particle_baseline=args[args.find("--baseline-particles")+1]
		particle_material_polish = "--particle-materials" in args
		plume_refinement = "--plume-refinement" in args
		source_material_polish = "--source-materials" in args
		await tactical_particles(directory)
		finish()
		return
	var packed: Image = style.atlas.get_image()
	check(not packed.has_mipmaps(),"effect atlas unexpectedly has mipmaps")
	for donor in Art.ASSETS.size():
		var start := Vector2i((donor%Art.COLUMNS)*Art.STRIDE,(donor/Art.COLUMNS)*Art.STRIDE)
		var interior := Rect2i(start+Vector2i(Art.PAD,Art.PAD),Vector2i(Art.TILE,Art.TILE))
		# Independent reload: the atlas tile must equal the pinned donor resized alone.
		var source := Image.load_from_file(directory.path_join("local-art/genesis/remastered/"+Art.ASSETS[donor][0]))
		source.convert(Image.FORMAT_RGBA8)
		source.resize(Art.TILE,Art.TILE,Image.INTERPOLATE_LANCZOS)
		check(packed.get_region(interior).get_data()==source.get_data(),"atlas donor bytes changed")
		for y in Art.STRIDE:
			for x in Art.STRIDE:
				if x>=Art.PAD and x<Art.PAD+Art.TILE and y>=Art.PAD and y<Art.PAD+Art.TILE: continue
				check(packed.get_pixelv(start+Vector2i(x,y)).a==0.0,"atlas transparent gutter contaminated")
	for index: int in Art.DONORS:
		var object := object_for(index)
		var mapping: Dictionary = style.mapping(object,frame,Art.PC_PALETTE)
		check(not mapping.is_empty(),"verified source rejected: %d" % index)
		check(mapping.donor==Art.DONORS[index],"original detail-level donor mismatch")
		var uv: Rect2 = mapping.source_uv
		var donor: int = mapping.donor
		var slot := Rect2(Vector2((donor%Art.COLUMNS)*Art.STRIDE+Art.PAD,(donor/Art.COLUMNS)*Art.STRIDE+Art.PAD),Vector2(Art.TILE,Art.TILE))
		var texel_uv := Rect2(uv.position*Vector2(packed.get_size()),uv.size*Vector2(packed.get_size()))
		check(slot.grow(0.001).encloses(texel_uv),"effect UV escapes isolated donor slot")
		var alternate := Art.PC_PALETTE.duplicate(true)
		alternate[2] = [1,2,3]
		check(style.mapping(object,frame,alternate).is_empty(),"unknown palette accepted for bitmap %d" % index)
		check(mapping.rect==Rect2(Vector2(128,50)+style.bounds[index].position,style.bounds[index].size),"source anchor or padding changed")
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
	check(style.mapping(object_for(51),frame,unknown).is_empty(),"unknown palette accepted")
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
	check(native_scale in [1,4,5],"unsupported native test scale")
	if native_scale not in [1,4,5]: finish(); return
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
	modern = "--modern" in args
	if modern:
		check(view.modern_assets.load_assets(directory),"Modern assets unavailable for ownership regression")
		if not view.modern_assets.ready: finish(); return
		view.modern_enabled = true
	# Ordered source replay checks selection and disappearance without inventing a
	# playback timer. Native screenshots are separate from this metadata check.
	var replay_path := directory.path_join("artifacts/pc-sprite-controls-02/report.json")
	check(FileAccess.file_exists(replay_path),"original replay fixture missing")
	var replay = JSON.parse_string(FileAccess.get_file_as_string(replay_path)) if FileAccess.file_exists(replay_path) else null
	if FileAccess.file_exists(replay_path): check(replay is Dictionary and replay.get("render_passes") is Array,"replay fixture unreadable")
	if replay is Dictionary and replay.get("render_passes") is Array:
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
		var empty := sample(object_for(0))
		empty.objects = []
		backdrop = await snapshot(empty,true)
		for index: int in Art.DONORS:
			var data := sample(object_for(index))
			var original := await snapshot(data,false)
			var remaster := await snapshot(data,true)
			var mapping: Dictionary = style.mapping(data.objects[0],frame,Art.PC_PALETTE)
			check(view.effect_art_ids==[index],"native effect not active")
			check(compare_outside(original,remaster,mapping.rect,"effect escaped original bounds")>0,"art made no visible change")
			check_authored_colors(remaster,mapping)
			var visible_pixels := 0
			for y in remaster.get_height():
				for x in remaster.get_width():
					if remaster.get_pixel(x,y).to_rgba32()!=backdrop.get_pixel(x,y).to_rgba32(): visible_pixels+=1
			if modern:
				var owners: Image = view.ownership.get_texture().get_image()
				var sprite: Dictionary = data.objects[0].sprite
				for y in remaster.get_height():
					for x in remaster.get_width():
						var p := Vector2i(floori(float(x)/native_scale)+32-128,floori(float(y)/native_scale)+13-50)
						if p.x<0 or p.y<0 or p.x>=int(sprite.width) or p.y>=int(sprite.height): continue
						var original_opaque: bool = sprite.opaque[p.y*int(sprite.width)+p.x]
						if original_opaque:
							check(roundi(owners.get_pixel(x,y).r*255)==1,"authored alpha hole lost original sprite ownership")
							retained_source_pixels += 1
						elif remaster.get_pixel(x,y).to_rgba32()!=backdrop.get_pixel(x,y).to_rgba32():
							modern_contour_pixels += 1
			check(visible_pixels>0,"authored effect became wholly invisible: %d" % index)
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
		for index: int in Art.BASES:
			for origin in [[29,12],[283,107]]:
				data = sample(object_for(index,origin))
				var a := await snapshot(data,false)
				var b := await snapshot(data,true)
				var mapping: Dictionary = style.mapping(data.objects[0],frame,Art.PC_PALETTE)
				if mapping.is_empty():
					check(a.get_data()==b.get_data(),"fully clipped source changed")
				else:
					compare_outside(a,b,mapping.rect,"clipped donor leaked outside source rectangle")

	if modern and "--native" in args and native_scale>1:
		check(modern_contour_pixels==0,"Modern effect changed pixels outside the original opaque sprite pixels")
	view.apply_pass({"objects":[]})
	check(view.effect_art_ids.is_empty() and view.mesh_node.mesh==null,"stale effect survived missing original frame")
	finish()

func finish() -> void:
	for error in errors: printerr("FAIL: "+error)
	var report := {"checks":checks,"errors":errors,"native_pixels":native_pixels,"changed_pixels":changed_pixels,
		"color_samples":color_samples,"max_color_error":max_color_error,"modern":modern,"modern_contour_pixels":modern_contour_pixels,"retained_source_pixels":retained_source_pixels}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PC_EFFECT_ART: %d checks, %d errors; %d native pixels" % [checks,errors.size(),native_pixels])
	quit(0 if errors.is_empty() else 1)

# Finite Tactical particle controls reuse the real effects and Modern catalogues.
var particle_rows: Array=[]
var particle_material_rows: Array=[]
var source_material_rows: Array=[]

func particle_shader_capture(code: String) -> Image:
	var shader := Shader.new()
	shader.code = code
	view.tactical_effects.material.shader = shader
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return viewport.get_texture().get_image()

func particle_material_pair(name: String, after: Image, kind: int = -1) -> void:
	# Same production puff mesh and ownership textures, only the finish differs.
	var material: ShaderMaterial = view.tactical_effects.material
	var current: Shader = material.shader
	var before_code := FileAccess.get_file_as_string(particle_baseline)
	var after_code := current.code
	var colour := "ALBEDO=OUTPUT_IS_SRGB ? colour : pow(colour,vec3(2.2));"
	if kind>=0:
		var isolate := "if(abs(emitter.y-%s)>0.25) discard;\n" % str(float(kind))
		before_code=before_code.replace(colour,isolate+colour)
		after_code=after_code.replace(colour,isolate+colour)
		after=await particle_shader_capture(after_code)
	check(not before_code.is_empty(), name+": preceding particle material available")
	var before := await particle_shader_capture(before_code)
	var changed := image_difference(before,after)
	var visible_finish := name != "effect-17"
	if plume_refinement and name=="effect-15":visible_finish=false
	check(changed>10 if visible_finish else changed==0, name+": expected colour change or exact unchanged-source control")
	# Rendering both actual shaders in white exposes their composited opacity.
	# Identity protects density, feathering, overlap, clipping and ownership.
	check(before_code.contains(colour) and after_code.contains(colour), name+": opacity diagnostic targets production output")
	var before_mask := await particle_shader_capture(before_code.replace(colour,"ALBEDO=vec3(1.0);"))
	var after_mask := await particle_shader_capture(after_code.replace(colour,"ALBEDO=vec3(1.0);"))
	check(before_mask.get_data()==after_mask.get_data(), name+": particle opacity and coverage exact")
	if name=="effect-17":
		view.tactical_effects.visible=false
		await process_frame
		RenderingServer.force_draw(false)
		RenderingServer.force_sync()
		check(after_mask.get_data()==viewport.get_texture().get_image().get_data(), name+": hollow source actually hides all puff coverage")
		view.tactical_effects.visible=true
	await particle_shader_capture(after_code)
	check(after.get_data()==viewport.get_texture().get_image().get_data(), name+": finish restoration exact")
	material.shader=current
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	particle_material_rows.append({"case":name,"changed_pixels":changed,"visible_finish":visible_finish,"opacity_and_coverage_exact":true})
	before.save_png(output.path_join(name+"-particles-before.png"))
	after.save_png(output.path_join(name+"-particles-after.png"))
	JavaScriptBridge.eval("window.particleMaterialImages=window.particleMaterialImages||{};window.particleMaterialImages["+JSON.stringify(name)+"]="+JSON.stringify([Marshalls.raw_to_base64(before.save_png_to_buffer()),Marshalls.raw_to_base64(after.save_png_to_buffer())]))

func source_material_pair(name: String) -> void:
	# Both actual Tactical surface shaders, with identical puffs disabled.
	var material: ShaderMaterial=view.mesh_node.mesh.surface_get_material(0)
	var current: Shader=material.shader
	var old_code := FileAccess.get_file_as_string(surface_baseline).replace("depth_test_disabled, depth_draw_never","depth_draw_opaque").replace("void fragment() {","void fragment() {\n DEPTH = UV.y > 19.5 && UV.y < 21.5 ? FRAGCOORD.z : 0.0;\n if (UV.y > 20.04 && UV.y < 20.08) DEPTH = 0.5 + min(UV2.x,1024.0)/4096.0;")
	var images: Array[Image]=[]
	var masks: Array[Image]=[]
	var puff_visible: bool=view.tactical_effects.visible
	view.tactical_effects.visible=false
	var output_line := "ALBEDO=OUTPUT_IS_SRGB ? result : pow(result,vec3(2.2));"
	for code: String in [old_code,current.code]:
		check(code.contains(output_line),name+": diagnostic targets source effect output")
		for white in [false,true]:
			var shader := Shader.new()
			shader.code=code.replace(output_line,"ALBEDO=vec3(1.0);") if white else code
			material.shader=shader
			await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
			var image:=viewport.get_texture().get_image()
			if white:masks.append(image)
			else:images.append(image)
	check(masks[0].get_data()==masks[1].get_data(),name+": source cutout, owner and outside effect exact")
	var changed:=image_difference(images[0],images[1])
	var changed_expected:=not plume_refinement and name in ["effect-15","effect-16"]
	check(changed>10 if changed_expected else changed==0,name+": registered impact phase refined, unrelated source effects exact")
	if name in ["effect-15","effect-16"]:
		images[0].save_png(output.path_join(name+"-before.png"));images[1].save_png(output.path_join(name+"-after.png"))
	material.shader=current
	await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
	check(images[1].get_data()==viewport.get_texture().get_image().get_data(),name+": source shader restoration exact")
	view.tactical_effects.visible=puff_visible
	source_material_rows.append({"case":name,"changed_pixels":changed,"source_cutout_and_outside_exact":true})
	if name in ["effect-15","effect-17","effect-62"]:
		JavaScriptBridge.eval("window.sourceMaterialImages=window.sourceMaterialImages||{};window.sourceMaterialImages["+JSON.stringify(name)+"]="+JSON.stringify([Marshalls.raw_to_base64(images[0].save_png_to_buffer()),Marshalls.raw_to_base64(images[1].save_png_to_buffer())]))

func particle_capture(data: Dictionary, tactical: bool) -> Image:
	view.tactical_landscape=tactical
	return await snapshot(data,true)

func image_difference(a: Image,b: Image) -> int:
	var changed:=0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x,y)!=b.get_pixel(x,y):changed+=1
	return changed

func particle_pair(data: Dictionary,name: String,positive: bool) -> void:
	var source:=JSON.stringify(data)
	var modern_image:=await particle_capture(data,false)
	var material: ShaderMaterial=view.mesh_node.mesh.surface_get_material(0)
	var current: Shader=material.shader
	var old:=Shader.new()
	old.code=FileAccess.get_file_as_string(surface_baseline).replace("depth_test_disabled, depth_draw_never","depth_draw_opaque").replace("void fragment() {","void fragment() {\n DEPTH = UV.y > 19.5 && UV.y < 21.5 ? FRAGCOORD.z : 0.0;\n if (UV.y > 20.04 && UV.y < 20.08) DEPTH = 0.5 + min(UV2.x,1024.0)/4096.0;")
	material.shader=old
	await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
	check(modern_image.get_data()==viewport.get_texture().get_image().get_data(),name+": Modernized pixel identity")
	material.shader=current
	var tactical_image:=await particle_capture(data,true)
	if source_material_polish and name.begins_with("effect-"):
		await source_material_pair(name)
	var queued: Dictionary=view.tactical_effects.counts.duplicate()
	if particle_material_polish and name in ["smoke-deployment","missile","effect-15","effect-17"]:
		await particle_material_pair(name,tactical_image)
	var changed:=image_difference(modern_image,tactical_image)
	check(changed>20 if positive else changed==0,name+": scoped visible effect")
	check(tactical_image.get_data()==(await particle_capture(data,true)).get_data(),name+": repeated packet exact")
	await create_timer(0.10).timeout
	check(tactical_image.get_data()==(await particle_capture(data,true)).get_data(),name+": paused particle image exact")
	check((await particle_capture(data,false)).get_data()==modern_image.get_data(),name+": switch back exact")
	check(JSON.stringify(data)==source,name+": original snapshot immutable")
	particle_rows.append({"case":name,"changed_pixels":changed,"queued_puffs":queued})
	# Bounded visual evidence; the test is not an original mission capture.
	if name in ["smoke-deployment","missile","idle-m113","effect-15","effect-17"]:
		JavaScriptBridge.eval("window.effectImages=window.effectImages||{};window.effectImages["+JSON.stringify(name)+"]="+JSON.stringify([Marshalls.raw_to_base64(modern_image.save_png_to_buffer()),Marshalls.raw_to_base64(tactical_image.save_png_to_buffer())]))

func tactical_particles(directory: String) -> void:
	viewport=SubViewport.new();viewport.own_world_3d=true;viewport.size=Vector2i(1024,388)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	camera=Camera3D.new();viewport.add_child(camera);Camera.apply(camera,frame,Vector3.ZERO);camera.make_current()
	view=DrawPass.new();view.solid_enabled=true;camera.add_child(view)
	check(view.modern_assets.load_assets(directory),"Tactical effects catalogue available")
	if not view.modern_assets.ready:return
	view.modern_enabled=true
	var terrain:=preload("res://scripts/pc_terrain_style.gd").new()
	check(terrain.load_assets(directory.path_join("local-art/pc-terrain-remastered/detail-v1")),"Tactical effects terrain available")
	view.terrain_style=terrain
	view.effect_art=style
	for index: int in Art.BASES:
		await particle_pair(sample(object_for(index)),"effect-%d"%index,true)
	var missile:=sample(object_for(62,[152,60]))
	missile.objects[0].pointer=99
	var missile_box: Rect2=style.mapping(missile.objects[0],frame,Art.PC_PALETTE).target
	var missile_raw: Array=Geometry.unproject(missile_box.get_center(),600.0,frame)
	missile.world={"dynamic":[{"pointer":99,"shape_index":186,"shape_header_word":100,"world_position_raw":[missile_raw[0],-missile_raw[1],missile_raw[2]],"orientation_u8":[0,0,64],"speed_raw":250}],"presentation_effects":{"schema":1,"shape_base":115}}
	await particle_pair(missile,"missile",true)
	view.tactical_landscape=true;view.apply_pass(missile)
	check(view.tactical_effects.counts.missile==9,"original guided projectile admits motor trail")
	# The glow stays on the drawn flare: RAM heading and speed lay no wake.
	var turned:=missile.duplicate(true)
	turned.world.dynamic[0].orientation_u8=[0,0,192];turned.world.dynamic[0].speed_raw=-250
	var puffs_before: Array=view.tactical_effects.puffs.duplicate(true)
	view.apply_pass(turned)
	check(view.tactical_effects.puffs==puffs_before,"missile glow ignores RAM heading and speed")
	check(view.tactical_effects.world_position_ok([79872,141312,50]),"streamed original positions exceed local model bounds")
	check(not view.tactical_effects.world_position_ok([INF,0,0]),"nonfinite world position rejected")
	var motor_image:=await particle_capture(missile,true)
	view.tactical_effects.visible=false
	await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
	check(image_difference(motor_image,viewport.get_texture().get_image())>10,"guided motor trail actually visible")
	view.tactical_effects.visible=true
	var alternate:=missile.duplicate(true)
	alternate.objects[0]=object_for(63,[152,60]);alternate.objects[0].pointer=99
	alternate.world.dynamic[0].shape_index=187
	await particle_pair(alternate,"missile-alternate",true)
	view.tactical_landscape=true;view.apply_pass(alternate)
	check(view.tactical_effects.counts.missile==9,"alternate original missile flare retains motor trail")
	var invalid:=missile.duplicate(true);invalid.world.dynamic[0].pointer=100
	view.apply_pass(invalid);check(view.tactical_effects.counts.missile==0,"pointer mismatch has no missile trail")
	invalid=missile.duplicate(true);invalid.world.dynamic.append(invalid.world.dynamic[0].duplicate(true))
	view.apply_pass(invalid);check(view.tactical_effects.counts.missile==0,"ambiguous actor has no missile trail")
	invalid=missile.duplicate(true);invalid.world.dynamic[0].shape_header_word=2
	view.apply_pass(invalid);check(view.tactical_effects.counts.missile==0,"impact starburst cannot become missile")
	var smoke:=sample(cover(Rect2(32,13,1,1)))
	smoke.world={"dynamic":[],"presentation_effects":{"schema":1,"shape_base":115,"smoke":{"active":true,"remaining_raw":24,"world_position_raw":[0,-500,-80]}}}
	await particle_pair(smoke,"smoke-deployment",true)
	var fresh:=await particle_capture(smoke,true)
	var smoke_build_count: int=view.mesh_build_count
	invalid=smoke.duplicate(true);invalid.world.presentation_effects.smoke.remaining_raw=8
	check(image_difference(fresh,await particle_capture(invalid,true))>20,"source smoke timer drives expansion")
	check(view.mesh_build_count==smoke_build_count,"smoke timer updates particles without rebuilding terrain/actors")
	check(fresh.get_data()==(await particle_capture(smoke,true)).get_data(),"restoring smoke snapshot exact")
	invalid=smoke.duplicate(true);invalid.world.presentation_effects.smoke.active=false
	await particle_pair(invalid,"smoke-inactive",false)
	invalid=smoke.duplicate(true);invalid.world.presentation_effects.smoke.remaining_raw=0
	await particle_pair(invalid,"smoke-expired",false)
	invalid=smoke.duplicate(true);invalid.objects=[cover(Rect2(32,13,256,97))]
	await particle_pair(invalid,"smoke-behind-actor",false)
	invalid=smoke.duplicate(true);invalid.palette_rgb[6]=[1,2,3]
	await particle_pair(invalid,"unknown-palette",false)
	invalid=smoke.duplicate(true)
	invalid.world.presentation_effects.smoke.world_position_raw=[0,0,0]
	invalid.background={"kind":"horizon","line":[[32,61],[287,61]],"colors":[2,2]}
	await particle_pair(invalid,"smoke-immersed",true)
	check(view.tactical_effects.counts.smoke==0,"Modernized switchback clears immersed smoke")
	# Real catalogued M113 source anchors, repositioned only for GPU inspection.
	var catalog: Dictionary=view.modern_assets.load_catalogue(directory)
	var model: Dictionary=catalog.models[129]
	var vehicle:=sample(cover(Rect2(32,13,1,1)))
	var object: Dictionary={"shape_index":129,"root":int(model.roots[0].offset),"dynamic_instance":true,"static_path":false,"pointer":99,"polygons":[]}
	var rotation:=Basis(Vector3.RIGHT,0.65)*Basis(Vector3(0,0,1),0.4)
	var selected: Dictionary={}
	for group: Dictionary in model.groups:
		if group.offset in model.roots[0].group_pointers:
			for pid in group.primitive_pointers:selected[int(pid)]=true
	for primitive: Dictionary in model.source_primitives:
		if primitive.vertices.size()<3 or int(primitive.id) not in selected:continue
		var points: Array=[]
		for raw: Array in primitive.vertices:
			var point: Vector3=rotation*Vector3(raw[0],raw[1],raw[2]);points.append([point.x,point.y+300,point.z])
		object.polygons.append({"primitive":int(primitive.id),"fill_mode":1,"colors":[int(primitive.prefix_bytes[1]),int(primitive.prefix_bytes[2])],"camera_vertices":points})
	vehicle.objects=[object]
	vehicle.world={"dynamic":[{"pointer":99,"shape_index":129,"world_position_raw":[0,-300,0],"orientation_u8":[0,0,0],"speed_raw":30,"shape_header_word":100}],"presentation_effects":{"schema":1,"shape_base":115}}
	# Compare Tactical with the exact same Tactical surface, particles disabled.
	view.tactical_landscape=true;view.apply_pass(vehicle)
	check(view.tactical_effects.counts.exhaust==7 and not view.tactical_effects.counts.has("dust"),"visible vehicle queues anchored idle fumes without motion dust")
	var with_particles:=await particle_capture(vehicle,true)
	if particle_material_polish: await particle_material_pair("idle-m113",with_particles)
	if source_material_polish:
		await particle_material_pair("diesel-exhaust",with_particles,1)
	view.tactical_effects.visible=false
	await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
	var without_particles:=viewport.get_texture().get_image()
	var vehicle_changed:=image_difference(with_particles,without_particles)
	check(vehicle_changed>20,"idle M113 particles actually visible")
	# Clip [32,13,287,109] fills the 1024x388 viewport: four pixels per unit.
	var hull: Rect2=view.tactical_effects.drawn_rect(vehicle.objects[0],frame)
	var hull_pixels:=Rect2((hull.position-Vector2(32,13))*4.0,hull.size*4.0).grow(1.0)
	var escaped:=0
	for y in with_particles.get_height():
		for x in with_particles.get_width():
			if with_particles.get_pixel(x,y)!=without_particles.get_pixel(x,y) and not hull_pixels.has_point(Vector2(x,y)+Vector2(0.5,0.5)):escaped+=1
	check(hull.has_area() and escaped==0,"idle fumes stay inside the vehicle's drawn silhouette: %d escaped"%escaped)
	particle_rows.append({"case":"idle-m113","changed_pixels":vehicle_changed,"escaped_pixels":escaped,"queued_puffs":view.tactical_effects.counts.duplicate()})
	JavaScriptBridge.eval("window.effectImages=window.effectImages||{};window.effectImages['idle-m113']="+JSON.stringify([Marshalls.raw_to_base64(without_particles.save_png_to_buffer()),Marshalls.raw_to_base64(with_particles.save_png_to_buffer())]))
	view.tactical_effects.visible=true
	var count: int=view.mesh_build_count
	view.apply_pass(vehicle);check(view.mesh_build_count==count,"same source particle mesh reused")
	var moving_puffs: Array=view.tactical_effects.puffs.duplicate(true)
	invalid=vehicle.duplicate(true);invalid.world.dynamic[0].speed_raw=0
	view.apply_pass(invalid);check(view.tactical_effects.counts.exhaust==7 and view.tactical_effects.puffs==moving_puffs,"parked vehicle fumes match a moving one")
	# Terrain the original painted over the vent hides every fume.
	var vent: Dictionary=view.tactical_effects.engine_anchor(vehicle.objects[0],view.modern_assets,frame)
	check(not vent.is_empty() and not view.modern_assets.terrain_shapes.is_empty(),"vent anchor and terrain shape available")
	if not vent.is_empty() and not view.modern_assets.terrain_shapes.is_empty():
		var vent_at:=Geometry.project([vent.engine.x,vent.engine.y,vent.engine.z],frame)
		var crest:=cover(Rect2(vent_at-Vector2(6,6),Vector2(12,12)))
		crest.shape_index=int(view.modern_assets.terrain_shapes.keys()[0])
		invalid=vehicle.duplicate(true);invalid.objects.append(crest)
		var crest_particles:=await particle_capture(invalid,true)
		view.tactical_effects.visible=false
		await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
		check(crest_particles.get_data()==viewport.get_texture().get_image().get_data(),"terrain painted over the vent hides every fume")
		view.tactical_effects.visible=true
	invalid=vehicle.duplicate(true);invalid.objects.append(cover(Rect2(32,13,256,97)))
	await particle_capture(invalid,true);view.tactical_effects.visible=false
	await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
	var hidden_baseline:=viewport.get_texture().get_image()
	view.tactical_effects.visible=true
	await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
	check(hidden_baseline.get_data()==viewport.get_texture().get_image().get_data(),"hidden engine cannot emit through actor")
	# Both painter orders: later opaque geometry hides all burst embellishment.
	invalid=sample(object_for(15));invalid.objects.append(cover(Rect2(120,42,70,55)))
	await particle_pair(invalid,"later-cover",false)
	invalid.objects.reverse();await particle_pair(invalid,"earlier-cover",true)
	invalid=sample(object_for(15,[300,120]));await particle_pair(invalid,"outside-clip",false)
	view.apply_pass({"objects":[]});check(view.tactical_effects.puffs.is_empty() and not view.tactical_effects.visible,"empty frame clears all particles")
	JavaScriptBridge.eval("window.effectReport="+JSON.stringify(particle_rows))
	FileAccess.open(output.path_join("particle-studies.json"),FileAccess.WRITE).store_string(JSON.stringify({"effects":particle_rows,"particle_materials":particle_material_rows,"source_materials":source_material_rows},"  "))
	if particle_material_polish:
		check(particle_material_rows.size()==(6 if source_material_polish else 5),"all particle material studies completed")
		JavaScriptBridge.eval("window.particleMaterialReport="+JSON.stringify(particle_material_rows))
	if source_material_polish:
		check(source_material_rows.size()==Art.BASES.size(),"every source donor material studied")
		JavaScriptBridge.eval("window.sourceMaterialReport="+JSON.stringify(source_material_rows))
