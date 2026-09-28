extends "res://tests/test_pc_effect_art.gd"
## Isolated all-bitmap fixtures in source-captured mode contexts, not live events.
const TandemFrame = preload("res://scripts/pc_tandem_frame.gd")

func run() -> void:
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args := OS.get_cmdline_user_args()
	output = directory.path_join("artifacts/finish-20260928/effects-modes-native")
	if "--output" in args: output = args[args.find("--output")+1]
	DirAccess.make_dir_recursive_absolute(output)
	var fixture := directory.path_join("artifacts/finish-20260928/effect-mode-fixtures.json")
	if "--fixture" in args: fixture = args[args.find("--fixture")+1]
	var evidence = JSON.parse_string(FileAccess.get_file_as_string(fixture))
	check(evidence is Dictionary and evidence.get("unique_palettes")==1,"source mode fixtures unavailable")
	if not evidence is Dictionary: finish(); return
	style = Art.new()
	check(style.load_assets(directory),"pinned effect assets unavailable")
	if style.atlas==null: finish(); return
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	camera = Camera3D.new()
	viewport.add_child(camera)
	camera.make_current()
	view = DrawPass.new()
	view.solid_enabled = true
	camera.add_child(view)
	for row: Dictionary in evidence.modes:
		check(FileAccess.get_sha256(directory.path_join(row.image))==row.image_sha256,"changed source mode image")
		check(FileAccess.get_sha256(directory.path_join(row.mask))==row.mask_sha256,"changed source mode mask")
		frame = row.camera.duplicate(true)
		viewport.size = Camera.apply(camera,frame,Vector3.ZERO)*2
		var data := {"camera":frame,"palette_rgb":row.palette_rgb,"materials":row.materials,"background":row.background,"objects":[]}
		var before := JSON.stringify(data)
		var background: Image
		if "--native" in args: background = await snapshot(data,false)
		for index: int in Art.DONORS:
			var object := object_for(index)
			var mapping: Dictionary = style.mapping(object,frame,row.palette_rgb)
			check(not mapping.is_empty(),"known mode rejected effect %s/%d" % [row.stage,index])
			if row.stage=="damage-settled" or not "--native" in args: continue
			data.objects = [object]
			var original := await snapshot(data,false)
			var remastered := await snapshot(data,true)
			check(view.effect_art_ids==[index],"known-mode donor absent")
			compare_outside(original,remastered,mapping.rect,"known-mode effect escaped original bound")
			check_authored_colors(remastered,mapping,background)
			if row.stage=="thermal" and index in [0,12,62]:
				remastered.save_png(output.path_join("thermal-effect-%02d.png" % index))
		data.objects = []
		check(JSON.stringify(data)==before,"mode fixture source mutated")
		if row.stage=="damage-settled" and "--native" in args:
			# STATUS owns every displayed pixel. A live-looking effect must never
			# leak through that original full UI ownership, regardless of its art.
			data.objects = [object_for(62)]
			await snapshot(data,true)
			var source := Image.load_from_file(directory.path_join(row.image))
			var mask := Image.load_from_file(directory.path_join(row.mask))
			var overlay_view := SubViewport.new()
			overlay_view.size = Vector2i(640,400)
			overlay_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(overlay_view)
			var overlay := TandemFrame.new()
			overlay.size = Vector2(640,400)
			overlay_view.add_child(overlay)
			var packet := {"draw_pass":data,"palette_rgb":row.palette_rgb,"ui_overlay":{"width":320,"height":200,"mask_png":Marshalls.raw_to_base64(mask.save_png_to_buffer())}}
			check(overlay.set_frame(source,packet,viewport.get_texture()),"STATUS source ownership refused")
			await process_frame
			RenderingServer.force_draw(false)
			RenderingServer.force_sync()
			var shown := overlay_view.get_texture().get_image()
			for y in 400:
				for x in 640:
					check(shown.get_pixel(x,y).to_rgba32()==source.get_pixel(x/2,y/2).to_rgba32(),"effect leaked through STATUS UI")
					native_pixels+=1
			shown.save_png(output.path_join("status-fully-occludes-effects.png"))
			overlay_view.queue_free()
	view.apply_pass({"objects":[]})
	check(view.effect_art_ids.is_empty(),"known-mode effect persisted after missing frame")
	finish()
