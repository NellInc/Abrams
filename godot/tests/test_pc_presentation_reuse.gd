extends "res://scripts/pc_bridge_viewer.gd"
## Exact-input cockpit reuse versus the uncached production compositor.
var errors: Array[String] = []
var checks := 0
var native := false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	native="--native" in args
	play_mode=true
	trace_mode=true
	cockpit_art_requested=true
	_build_ui()
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	_load_cockpit_presentation(directory)
	tandem_frame.typography.load_sources(directory.path_join("GAME"))
	tandem_frame.modern_available=true
	root.size=Vector2i(640,480)
	run.call_deferred()

func _process(_delta: float) -> bool: return false

func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok and errors.size()<30:errors.append(why)

func snapshot() -> PackedByteArray:
	if not native: return PackedByteArray()
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return tandem_viewport.get_texture().get_image().get_data()

func equivalent(source: Image, paired: Dictionary, world: Texture2D, program: Dictionary, label: String) -> void:
	var original := source.get_data()
	var metadata := JSON.stringify(paired)
	_present_tandem(source,paired,world,program)
	var actual := await snapshot()
	invalidate_presentation_cache()
	_present_tandem(source,paired,world,program)
	check(actual==(await snapshot()),label+": cached and uncached pixels")
	check(source.get_data()==original and JSON.stringify(paired)==metadata,label+": immutable input")

func run() -> void:
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var path := directory.path_join("artifacts/pc-live-type-cockpit-02/report.json")
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var program := {"name":"SIM"}
	for e in report.ui_presentations:
		var paired: Dictionary=report.presentations[int(e.frame_index)].duplicate(true)
		paired.draw_pass=report.render_passes.filter(func(p):return p.sequence==e.draw_sequence)[0].duplicate(true)
		for pair in [["ui_overlay",e.mask],["plate_overlay",e.plate_mask]]:
			var mask := Image.load_from_file(path.get_base_dir().path_join(pair[1]))
			paired[pair[0]].mask_png=Marshalls.raw_to_base64(mask.save_png_to_buffer())
		var source := Image.load_from_file(path.get_base_dir().path_join(e.image))
		var clip: Array=paired.draw_pass.camera.clip
		var world := ImageTexture.create_from_image(source.get_region(Rect2i(clip[0],clip[1],clip[2]-clip[0]+1,clip[3]-clip[1]+1)))
		for mode in ["upscaled","modern"]:
			tandem_frame.set_graphics_mode(mode)
			invalidate_presentation_cache()
			_present_tandem(source,paired,world,program)
			var builds := presentation_builds
			var hits := presentation_reuses
			var expected := await snapshot()
			var delivered := paired.duplicate(true)
			delivered.scanout_sequence=999999
			delivered.buffer_slot=9
			_present_tandem(source,delivered,world,program)
			check(presentation_reuses==hits+1 and presentation_builds==builds,"identical paired cockpit reused: "+str(e.stage)+"/"+mode)
			check(tandem_frame._cached_presentation==delivered,"mode replay remembers current delivery")
			check(expected==(await snapshot()),"reused native cockpit pixels: "+str(e.stage)+"/"+mode)
			if native:
				# Only the production-owned source viewport can retain the final
				# composite. Arbitrary mutable Texture2D inputs stay continuously live.
				_present_tandem(source,paired,world_viewport.get_texture(),program)
				var retained := await snapshot()
				tandem_frame.hide()
				_present_tandem(source,paired,world_viewport.get_texture(),program)
				check(retained==(await snapshot()),"source-owned composite does not redraw on cache hit")
				tandem_frame.show()
				invalidate_presentation_cache()
				_present_tandem(source,paired,world_viewport.get_texture(),program)
				check(retained==(await snapshot()),"source-owned composite restores on new composition")
				_present_tandem(source,paired,world,program)
			# In-place mutations cannot retroactively change the saved comparison.
			delivered.page_offset=-1
			await equivalent(source,delivered,world,program,"page provenance change")
			check(presentation_builds>=builds+2,"changed metadata rebuilt")
			await equivalent(source,paired,world,program,"restore original pair")
			var changed := source.duplicate()
			changed.set_pixel(160,60,Color.MAGENTA)
			await equivalent(changed,paired,world,program,"changed source with same metadata")
			var bad := paired.duplicate(true)
			bad.plate_overlay.plates={}
			await equivalent(source,bad,world,program,"lost asset provenance")
			bad=paired.duplicate(true)
			bad.ui_overlay.mask_png=Marshalls.raw_to_base64(Image.create_empty(320,200,false,Image.FORMAT_RGB8).save_png_to_buffer())
			await equivalent(source,bad,world,program,"malformed mask")
			check(not tandem_frame.world_enabled and _presentation_key.is_empty(),"failed composition never cached")
			await equivalent(source,paired,world,program,"recovery after fallback")
			var resized := presentation_builds
			tandem_frame.size+=Vector2(4,3)
			_present_tandem(source,paired,world,program)
			check(presentation_builds==resized+1,"resize cannot reuse old layout")
			await equivalent(source,paired,world,program,"resized layout")
			tandem_frame.size-=Vector2(4,3)
			world.update(Image.create_empty(world.get_width(),world.get_height(),false,Image.FORMAT_RGB8))
			await equivalent(source,paired,world,program,"live world texture updates beneath UI")
			tandem_frame.set_graphics_mode("ega")
			await equivalent(source,paired,world,program,"EGA switch")
			await equivalent(source,{},null,{"name":"START"},"frontend transition")
			tandem_frame.set_graphics_mode(mode)
			await equivalent(source,paired,world,program,"return from frontend")
	for error in errors: printerr("FAIL: "+error)
	print("PC_PRESENTATION_REUSE: %d checks, %d errors; native=%s; builds=%d, reuses=%d"%[checks,errors.size(),native,presentation_builds,presentation_reuses])
	quit(0 if errors.is_empty() else 1)
