extends SceneTree
const TandemFrame = preload("res://scripts/pc_tandem_frame.gd")
const DrawPass = preload("res://scripts/pc_draw_pass.gd")
const PcCamera = preload("res://scripts/pc_camera.gd")
var failures: Array[String] = []
var viewport: SubViewport
var composite: TextureRect
var pixels_checked := 0
var ui_pixels_checked := 0
var world_pixels_checked := 0
var reticle_pixels_checked := 0

# Records frontend loads without needing the optional art bank.
class FrontendSpy extends Control:
	var roots: Array[String] = []
	func load_sources(root_path: String) -> bool:
		roots.append(root_path)
		return false
	func clear() -> void: pass

func check(ok: bool, message: String) -> void:
	if not ok and failures.size() < 12: failures.append(message)

func packet(mask: Image, clip: Array) -> Dictionary:
	return {"draw_pass": {"camera": {"clip": clip}}, "ui_overlay": {
		"width": 320, "height": 200, "mask_png": Marshalls.raw_to_base64(mask.save_png_to_buffer())}}

func snapshot() -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return viewport.get_texture().get_image()

func matches(image: Image, source: Image, x: int, y: int, scale: int, label: String) -> void:
	pixels_checked += 1
	var actual := image.get_pixel(x*scale + scale/2, y*scale + scale/2).to_rgba32()
	var expected := source.get_pixel(x, y).to_rgba32()
	check(actual == expected, "%s pixel %d,%d: %x != %x" % [label,x,y,actual,expected])

func _initialize() -> void:
	# A runtime script error aborts _run before quit(); fail instead of idling.
	# Manual --fixture runs are untimed unless --deadline SECONDS is given.
	var args := OS.get_cmdline_user_args()
	var deadline := float(args[args.find("--deadline")+1]) if "--deadline" in args and args.find("--deadline")+1<args.size() else (0.0 if "--fixture" in args else 600.0)
	if deadline>0.0: create_timer(deadline).timeout.connect(func(): printerr("FAIL: PC_TANDEM_FRAME deadline"); quit(1))
	_run.call_deferred()

func _run() -> void:
	var source := Image.create_empty(320,200,false,Image.FORMAT_RGB8)
	var mask := Image.create_empty(320,200,false,Image.FORMAT_L8)
	for y in 200:
		for x in 320:
			source.set_pixel(x,y,Color8(x % 256,y % 256,(x+y) % 256))
			mask.set_pixel(x,y,Color.WHITE if x % 7 == 0 else Color.BLACK)
	# Explicit opaque black, and an opaque pixel identical to the old world.
	source.set_pixel(42,40,Color.BLACK)
	source.set_pixel(49,40,Color.MAGENTA)
	var replacement := Image.create_empty(256,97,false,Image.FORMAT_RGB8)
	replacement.fill(Color.CYAN)
	var world := ImageTexture.create_from_image(replacement)
	viewport = SubViewport.new()
	viewport.size = Vector2i(320,200)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	composite = TandemFrame.new()
	composite.size = Vector2(320,200)
	viewport.add_child(composite)
	var clip := [32,13,287,109]
	var presentation := packet(mask,clip)
	check(composite.set_frame(source,presentation,world), "valid paired UI refused")
	var native := "--native" in OS.get_cmdline_user_args()
	if native:
		var im := await snapshot()
		for y in 200:
			for x in 320:
				var retained: bool = x < 32 or x > 287 or y < 13 or y > 109 or x % 7 == 0
				if retained: matches(im,source,x,y,1,"synthetic retained")
				else:
					pixels_checked += 1
					check(im.get_pixel(x,y).to_rgba32() == Color.CYAN.to_rgba32(), "synthetic world replacement")
	for broken in [{}, {"draw_pass": {}}, packet(mask,[32,13,320,109]), packet(mask,[32.5,13,287,109])]:
		check(not composite.set_frame(source,broken,world) and not composite.world_enabled, "invalid attribution must fall back")
		if native:
			var im := await snapshot()
			for y in 200:
				for x in 320: matches(im,source,x,y,1,"fallback")
	mask.set_pixel(0,0,Color(0.5,0.5,0.5))
	check(not composite.set_frame(source,packet(mask,clip),world), "nonbinary mask accepted")
	mask.set_pixel(0,0,Color.WHITE)
	check(not composite.set_frame(source,packet(mask,clip),null), "missing world texture accepted")
	var color_mask := Image.create_empty(320,200,false,Image.FORMAT_RGB8)
	color_mask.fill(Color.WHITE)
	check(not composite.set_frame(source,packet(color_mask,clip),world), "colour mask accepted")
	await _replay_gaps(source,mask,clip,world,native)
	_recorded_replay()
	_mask_reuse(source,mask,clip,world)
	_genesis_load_reason()
	var args := OS.get_cmdline_user_args()
	if native and "--ega-upscale" in args: await _ega_upscale_contract(args)
	if native and "--fixture" in args:
		await _fixtures(args[args.find("--fixture")+1], args[args.find("--output")+1] if "--output" in args else "")
	for failure in failures: printerr("FAIL: " + failure)
	print("PC_TANDEM_FRAME: %s; %d exact RGB checks; %d live UI pixels; %d composited world pixels; %d original reticle-over-sprite pixels" % [
		"PASS" if failures.is_empty() else "FAIL", pixels_checked, ui_pixels_checked, world_pixels_checked, reticle_pixels_checked])
	quit(0 if failures.is_empty() else 1)

# Unattributed original writes and primitives the replay dropped have no
# Godot geometry; the frame must show the exact source instead of a gap.
func _replay_gaps(source: Image, mask: Image, clip: Array, world: Texture2D, native: bool) -> void:
	for kind in ["unattributed_bitmap","unattributed_polygon","opaque_command","unattributed_round_form","bitmap_plane_mask","incomplete_sprite","incomplete_round_form"]:
		var presentation := packet(mask,clip)
		presentation.draw_pass["unsupported"]=[{"kind":kind}]
		check(not composite.set_frame(source,presentation,world) and not composite.world_enabled and composite.fallback_reason=="unsupported original draw commands","unsupported %s replaced original pixels" % kind)
		if native and kind=="unattributed_bitmap":
			var im := await snapshot()
			for y in 200:
				for x in 320: matches(im,source,x,y,1,"unsupported-command fallback")
	var malformed := packet(mask,clip)
	malformed.draw_pass["unsupported"]="unknown"
	check(not composite.set_frame(source,malformed,world),"malformed unsupported list accepted")
	var empty := packet(mask,clip)
	empty.draw_pass["unsupported"]=[]
	check(composite.set_frame(source,empty,world) and composite.world_enabled,"empty unsupported list refused")
	var replay := DrawPass.new()
	composite.world_replay=replay
	replay.render_warnings.append("Unsupported original material 99")
	check(not composite.set_frame(source,empty,world) and not composite.world_enabled and composite.fallback_reason.begins_with("world replay incomplete"),"dropped replay primitive replaced original pixels")
	replay.render_warnings.clear()
	check(composite.set_frame(source,empty,world) and composite.world_enabled,"complete replay refused")
	composite.world_replay=null
	replay.free()

# Recorded SIM passes replayed through a real DrawPass: ordinary frames carry
# no replay warning, so wiring world_replay cannot flicker to the source frame.
func _recorded_replay() -> void:
	var path := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("artifacts/pc-live-type-cockpit-02/report.json")
	var report = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(report is Dictionary and report.get("ui_presentations",[]).size()>=20,"recorded replay fixture unavailable")
	if not report is Dictionary or not report.has("ui_presentations"): return
	var world_viewport := SubViewport.new()
	world_viewport.own_world_3d = true
	viewport.add_child(world_viewport)
	var camera := Camera3D.new()
	world_viewport.add_child(camera)
	camera.make_current()
	var draw = DrawPass.new()
	draw.solid_enabled = true
	camera.add_child(draw)
	composite.world_replay = draw
	var replayed := 0
	var last: Dictionary = {}
	for entry: Dictionary in report.ui_presentations:
		var drawing: Dictionary = report.render_passes.filter(func(p): return p.sequence == entry.draw_sequence)[0].duplicate(true)
		drawing.palette_rgb = report.presentations[int(entry.frame_index)].palette_rgb
		var frame: Dictionary = drawing.camera.duplicate(true)
		frame.matrix_q14_columns = [16384,0,0,0,16384,0,0,0,16384]
		frame.world_position_raw = [0,0,0]
		world_viewport.size = PcCamera.apply(camera,frame,Vector3.ZERO)*4
		draw.apply_pass(drawing)
		var source := Image.load_from_file(path.get_base_dir().path_join(entry.image))
		var presentation := packet(Image.load_from_file(path.get_base_dir().path_join(entry.mask)),drawing.camera.clip)
		presentation.draw_pass = drawing
		check(draw.render_warnings.is_empty(),"recorded pass reported a replay warning: "+entry.stage+" "+str(draw.render_warnings))
		check(composite.set_frame(source,presentation,world_viewport.get_texture()) and composite.world_enabled,"recorded replay fell back: "+entry.stage+" "+composite.fallback_reason)
		replayed+=1
		last = {"source":source,"presentation":presentation}
	check(replayed>=20,"recorded replay covered too few passes")
	# A page whose background event has not arrived replays without its sky.
	var missing: Dictionary = last.presentation.duplicate(true)
	missing.draw_pass.background = null
	draw.apply_pass(missing.draw_pass)
	check("Original background observation unavailable" in draw.render_warnings,"null background replayed without a warning")
	check(not composite.set_frame(last.source,missing,world_viewport.get_texture()) and not composite.world_enabled and composite.fallback_reason=="world replay incomplete: Original background observation unavailable","missing background replaced original pixels")
	draw.apply_pass(last.presentation.draw_pass)
	check(composite.set_frame(last.source,last.presentation,world_viewport.get_texture()) and composite.world_enabled,"recovered background still fell back")
	composite.world_replay = null
	world_viewport.queue_free()

func _mask_reuse(source: Image, mask: Image, clip: Array, world: Texture2D) -> void:
	var presentation := packet(mask,clip)
	check(composite.set_frame(source,presentation,world),"reuse fixture refused")
	var ui_texture = composite.material.get_shader_parameter("ui_mask")
	var frame_texture: Texture2D = composite.texture
	check(composite.set_frame(source,packet(mask,clip),world),"identical mask refused")
	check(composite.material.get_shader_parameter("ui_mask")==ui_texture and composite.texture==frame_texture,"identical encoded mask or frame re-uploaded")
	var changed: Image = mask.duplicate()
	changed.set_pixel(100,50,Color.WHITE if mask.get_pixel(100,50).r<0.5 else Color.BLACK)
	check(composite.set_frame(source,packet(changed,clip),world),"changed mask refused")
	var shader_mask: Image = composite.material.get_shader_parameter("ui_mask").get_image()
	check(composite.material.get_shader_parameter("ui_mask")!=ui_texture and shader_mask.get_data()==changed.get_data(),"changed encoded mask kept a stale texture")
	var edited: Image = source.duplicate()
	edited.set_pixel(1,1,Color.RED)
	# An in-place update() keeps the texture object; recreation replaces it.
	check(composite.set_frame(edited,packet(changed,clip),world) and (TandemFrame._update_round_trips==1 or composite.texture!=frame_texture) and composite.texture.get_image().get_pixel(1,1)==Color.RED,"changed source frame kept a stale texture")
	check(composite.set_frame(source,presentation,world) and composite.material.get_shader_parameter("ui_mask").get_image().get_data()==mask.get_data(),"restored mask differs")
	# Where update() round-trips (any GPU renderer), changed content of the same
	# shape stays in the one persistent texture. The dummy renderer cannot read an
	# update back, so here the retained upload bytes stand in for the texture.
	var probed: int = TandemFrame._update_round_trips
	check(probed in [0,1],"texture update capability not probed")
	if "--native" in OS.get_cmdline_user_args(): check(probed==1,"update() does not round-trip on this renderer")
	TandemFrame._update_round_trips=1
	var held: Texture2D=composite.texture
	check(composite.set_frame(edited,presentation,world) and composite.texture==held and composite._source_bytes==edited.get_data(),"update path replaced the persistent source texture")
	var resized: Image=edited.duplicate();resized.convert(Image.FORMAT_RGBA8)
	composite._source_frame_texture(resized)
	check(composite._source_texture!=held and composite._source_texture.get_format()==Image.FORMAT_RGBA8,"changed source shape reused an incompatible texture")
	TandemFrame._update_round_trips=probed
	check(composite.set_frame(source,presentation,world) and composite.texture.get_image().get_data()==source.get_data(),"source restored after update path")

func _genesis_load_reason() -> void:
	var probe = TandemFrame.new()
	var spy := FrontendSpy.new()
	probe.frontend_art=spy
	var root_path := OS.get_user_data_dir().path_join("tandem-genesis-reason")
	DirAccess.make_dir_recursive_absolute(root_path.path_join("local-art/genesis/cockpit-v2"))
	for file in DirAccess.get_files_at(root_path.path_join("local-art/genesis/cockpit-v2")): DirAccess.remove_absolute(root_path.path_join("local-art/genesis/cockpit-v2").path_join(file))
	check(not probe.load_genesis_art(root_path) and probe.genesis_art_reason=="Genesis cockpit donors not imported","absent donor set not reported as absent")
	var corrupt := Image.create(4,4,false,Image.FORMAT_RGB8)
	corrupt.save_png(root_path.path_join("local-art/genesis/cockpit-v2/systems-status-genesis-v1.png"))
	check(not probe.load_genesis_art(root_path) and probe.genesis_art_reason=="cockpit-v2 gunner-genesis-v1.png missing","partial donor set not named")
	for name in ["gunner","commander","cupola","driver"]: corrupt.save_png(root_path.path_join("local-art/genesis/cockpit-v2/"+name+"-genesis-v1.png"))
	check(not probe.load_genesis_art(root_path) and probe.genesis_art_reason=="cockpit-v2 gunner-genesis-v1.png hash mismatch","damaged donor not named")
	check(not probe.genesis_art_enabled,"damaged donor enabled cockpit art")
	check(spy.roots.size()==3,"cockpit donor failure skipped independently pinned frontend restorations")
	# Portraits validate their own pins: with the damaged cockpit set above and
	# the installed crew art, a source crew face still gets its restoration.
	var repo := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	check(probe.portrait_art.load_sources(repo) and probe.portrait_art.templates.size()==4,"installed portrait sources unavailable")
	if probe.portrait_art.templates.size()==4:
		var item: Dictionary=probe.portrait_art.templates[0]
		var face := Image.create_empty(320,200,false,Image.FORMAT_RGB8)
		face.fill(Color8(85,85,85))
		for point in item.points: face.set_pixelv(probe.portrait_art.SOURCE_AT+point.at,Color.hex(point.rgb))
		var owned := Image.create_empty(320,200,false,Image.FORMAT_L8)
		owned.fill(Color.WHITE)
		var flat := ImageTexture.create_from_image(Image.create_empty(256,97,false,Image.FORMAT_RGB8))
		check(probe.set_frame(face,packet(owned,[32,13,287,109]),flat) and not probe.genesis_art_enabled,"portrait fixture refused")
		check(probe.portrait_art.active.get("id")==0,"cockpit donor failure suppressed an independently pinned portrait")
	spy.free()
	probe.free()

func _scale3x_pixel(source: Image, at: Vector2i, part: Vector2i) -> Color:
	var around: Array[Color]=[]
	for y in range(-1,2):
		for x in range(-1,2): around.append(source.get_pixel(clampi(at.x+x,0,source.get_width()-1),clampi(at.y+y,0,source.get_height()-1)))
	var a:=around[0];var b:=around[1];var c:=around[2]
	var d:=around[3];var e:=around[4];var f:=around[5]
	var g:=around[6];var h:=around[7];var i:=around[8]
	if b==h or d==f or part==Vector2i(1,1): return e
	match part.y*3+part.x:
		0: return d if d==b else e
		1: return b if (d==b and e!=c) or (b==f and e!=a) else e
		2: return f if b==f else e
		3: return d if (d==b and e!=g) or (d==h and e!=a) else e
		5: return f if (b==f and e!=i) or (h==f and e!=c) else e
		6: return d if d==h else e
		7: return h if (d==h and e!=i) or (h==f and e!=g) else e
		8: return f if h==f else e
	return e

func _ega_upscale_contract(args: Array) -> void:
	viewport.size=Vector2i(960,600)
	composite.size=viewport.size
	var source:=Image.create(320,200,false,Image.FORMAT_RGB8)
	source.fill(Color8(170,85,0))
	var colours: Array[Color]=[Color.BLACK,Color.WHITE,Color8(85,85,85),Color8(170,170,170),Color8(170,85,0),Color8(0,170,0)]
	for y in 16:
		for x in 16: source.set_pixel(x,y,colours[(x*7+y*3+x*y)%colours.size()])
	source.set_pixel(319,199,Color.BLACK)
	var original:=source.get_data()
	check(composite.set_graphics_mode("ega_upscaled"),"original-palette upscale requires no donor or modern assets")
	check(composite.set_frame(source,{},null),"EGA upscale works without a paired camera or UI attribution")
	var scaled:=await snapshot()
	var changed:=0
	for y in 48:
		for x in 48:
			pixels_checked+=1
			var at:=Vector2i(x/3,y/3);var part:=Vector2i(x%3,y%3)
			var actual:=scaled.get_pixel(x,y)
			check(actual==_scale3x_pixel(source,at,part),"Scale3x neighbourhood oracle")
			if actual!=source.get_pixelv(at): changed+=1
	check(changed>50,"edge-aware upscaling must visibly refine pixel corners")
	check(scaled.get_pixel(500,400)==Color8(170,85,0),"original dark brown colour remains exact")
	check(scaled.get_pixel(959,599)==Color.BLACK,"source border is clamped rather than repeated")
	check(not composite.world_enabled and not composite.frontend_art.visible and not composite.instrument_art.visible,"EGA upscale excludes generated art, instruments and world replacement")
	check(composite.set_graphics_mode("ega"),"plain EGA restores")
	var ega:=await snapshot()
	var expected:=source.duplicate();expected.resize(960,600,Image.INTERPOLATE_NEAREST);expected.convert(ega.get_format())
	check(ega.get_data()==expected.get_data(),"plain EGA retains exact nearest output")
	check(composite.set_graphics_mode("ega_upscaled"),"EGA upscale returns")
	check((await snapshot()).get_data()==scaled.get_data(),"EGA upscale returns without stale overlays")
	check(source.get_data()==original,"upscaling never changes original frame bytes")
	if "--pc-round-source" not in args: return
	var pc:=Image.load_from_file(args[args.find("--pc-round-source")+1])
	check(pc!=null,"PC ammunition source available")
	if pc==null: return
	var art=composite.instrument_art
	art.source_plate=pc
	art.donor=ImageTexture.create_from_image(Image.create(1586,992,false,Image.FORMAT_RGB8))
	art._load_pc_rounds()
	if "--pc-round-white-fallback" in args:
		# Make a backend's white unbound-sampler fallback deterministic. Each
		# shader is test-local; the production material must bind its crop.
		var white:=Image.create(1,1,false,Image.FORMAT_RGB8)
		white.fill(Color.WHITE)
		for icon: TextureRect in art.pc_rounds.values():
			var isolated: Shader=icon.material.shader.duplicate()
			isolated.set_default_texture_parameter("ega_source",ImageTexture.create_from_image(white))
			icon.material.shader=isolated
	var ui:=Image.create(320,200,false,Image.FORMAT_L8);ui.fill(Color.WHITE)
	var tags:=Image.create(320,200,false,Image.FORMAT_L8);tags.fill(Color8(1,1,1))
	composite.texture=ImageTexture.create_from_image(pc)
	composite.material=null
	art.show();art.set_frame(pc,ui,tags)
	var rounds:=await snapshot()
	for item in art.CELLS.slice(0,3):
		check(art.pc_rounds[item.name].visible,"verified PC round is visible: "+item.name)
		check(art.pc_rounds[item.name].material.get_shader_parameter("ega_source")==art.pc_rounds[item.name].texture,"round's explicit source sampler matches its crop: "+item.name)
		var crop:=pc.get_region(item.source)
		for y in item.source.size.y*3:
			for x in item.source.size.x*3:
				pixels_checked+=1
				check(rounds.get_pixel(item.source.position.x*3+x,item.source.position.y*3+y)==_scale3x_pixel(crop,Vector2i(x/3,y/3),Vector2i(x%3,y%3)),"thin PC round matches source contour and palette")
	var preceding: Texture2D=art.pc_rounds.heat_icon.texture
	art._load_pc_rounds()
	check(art.pc_rounds.heat_icon.texture!=preceding,"reloading creates a fresh original crop")
	for icon: TextureRect in art.pc_rounds.values():
		check(icon.material.get_shader_parameter("ega_source")==icon.texture,"reused round control binds its freshly loaded crop")
	art.set_frame(pc,ui,tags)
	check(rounds.get_data()==(await snapshot()).get_data(),"reloaded PC rounds render identically")
	art.pc_rounds_enabled=false;art.set_frame(pc,ui,tags)
	check(art.pc_rounds.values().all(func(icon):return not icon.visible),"Tactical keeps its previous donor path")
	art.pc_rounds_enabled=true
	var damaged:=pc.duplicate();damaged.set_pixel(241,145,Color.MAGENTA)
	art.set_frame(damaged,ui,tags)
	check(not art.pc_rounds.heat_icon.visible,"changed original cell cannot authorize a replacement")
	tags.fill(Color.BLACK);art.set_frame(pc,ui,tags)
	check(art.pc_rounds.values().all(func(icon):return not icon.visible),"unowned rounds remain original")
	print("PC_EGA_UPSCALE: palette, contours, borders, switchback and PC ammunition guards "+("passed" if failures.is_empty() else "failed"))

func _fixtures(path: String, output: String) -> void:
	var report = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(report is Dictionary and report.get("ui_presentations", []).size() >= 23, "UI fixture unavailable")
	if not report is Dictionary or not report.has("ui_presentations"): return
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	var world_viewport := SubViewport.new()
	world_viewport.own_world_3d = true
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.add_child(world_viewport)
	var camera := Camera3D.new()
	world_viewport.add_child(camera)
	camera.make_current()
	var draw = DrawPass.new()
	draw.solid_enabled = true
	camera.add_child(draw)
	var summaries: Array = []
	for entry: Dictionary in report.ui_presentations:
		var drawing: Dictionary = report.render_passes.filter(func(p): return p.sequence == entry.draw_sequence)[0].duplicate(true)
		drawing.palette_rgb = report.presentations[int(entry.frame_index)].palette_rgb
		var clip: Array = drawing.camera.clip
		var source := Image.load_from_file(path.get_base_dir().path_join(entry.image))
		var mask := Image.load_from_file(path.get_base_dir().path_join(entry.mask))
		var presentation := packet(mask,clip)
		presentation.draw_pass = drawing
		# Using source scenery must reconstruct the entire original framebuffer.
		var region := Rect2i(clip[0],clip[1],clip[2]-clip[0]+1,clip[3]-clip[1]+1)
		viewport.size = Vector2i(320,200)
		composite.size = Vector2(320,200)
		check(composite.set_frame(source,presentation,ImageTexture.create_from_image(source.get_region(region))), "recorded mask refused")
		var im := await snapshot()
		for y in 200:
			for x in 320: matches(im,source,x,y,1,"source reconstruction " + entry.stage)
		var frame: Dictionary = drawing.camera.duplicate(true)
		frame.matrix_q14_columns = [16384,0,0,0,16384,0,0,0,16384]
		frame.world_position_raw = [0,0,0]
		world_viewport.size = PcCamera.apply(camera,frame,Vector3.ZERO)*4
		draw.apply_pass(drawing)
		check(draw.render_warnings.is_empty(), "recorded draw warnings")
		viewport.size = Vector2i(1280,800)
		composite.size = Vector2(1280,800)
		check(composite.set_frame(source,presentation,world_viewport.get_texture()), "native world refused")
		im = await snapshot()
		var world_image := world_viewport.get_texture().get_image()
		for y in 200:
			for x in 320:
				if not region.has_point(Vector2i(x,y)) or mask.get_pixel(x,y).r > 0.5:
					matches(im,source,x,y,4,"native retained " + entry.stage)
					ui_pixels_checked += 1
				else:
					var expected := world_image.get_pixel((x-region.position.x)*4+2,(y-region.position.y)*4+2).to_rgba32()
					var actual := im.get_pixel(x*4+2,y*4+2).to_rgba32()
					check(actual == expected,"native world composite %s pixel %d,%d: %x != %x" % [entry.stage,x,y,actual,expected])
					world_pixels_checked += 1
					pixels_checked += 1
		for object: Dictionary in drawing.objects:
			if not object.get("sprite") is Dictionary: continue
			var sprite: Dictionary = object.sprite
			for y in int(sprite.height):
				for x in int(sprite.width):
					var px: int = sprite.origin[0]+x
					var py: int = sprite.origin[1]+y
					if region.has_point(Vector2i(px,py)) and sprite.opaque[y*int(sprite.width)+x] and mask.get_pixel(px,py).r > 0.5:
						matches(im,source,px,py,4,"reticle over original sprite")
						reticle_pixels_checked += 1
		if not output.is_empty() and (entry.stage in ["driver","gunner","commander","cupola"] or entry.stage.begins_with("sprite-")):
			check(im.save_png(output.path_join(entry.stage+"-tandem.png")) == OK, "capture failed")
			check(world_viewport.get_texture().get_image().save_png(output.path_join(entry.stage+"-world.png")) == OK, "world capture failed")
		summaries.append({"stage": entry.stage, "draw_sequence": entry.draw_sequence, "frame_index": entry.frame_index,
			"clip": clip, "source_reconstruction_pixels": 64000})
	check(reticle_pixels_checked > 0, "fixture never tested an original UI-over-effect overlap")
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"cases": summaries, "rgb_checks": pixels_checked,
			"ui_pixel_checks": ui_pixels_checked, "reticle_pixels": reticle_pixels_checked,
			"world_pixel_checks": world_pixels_checked,
			"failures": failures, "scope": "source reconstruction and original UI RGB retention; world raster parity remains separate"},"  "))
