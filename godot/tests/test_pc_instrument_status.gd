extends "res://tests/test_pc_gauges.gd"
## Original instruction oracle plus exact visible/provenance rejection checks.

func run() -> void:
	repo = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	instruments = Instruments.new()
	root.add_child(instruments)
	check(instruments.load_sources(repo,Image.load_from_file(repo.path_join("local-art/genesis/cockpit-v2/gunner-genesis-v1.png"))),"source art loaded")
	for spec in Instruments.system_lamps():
		for color in [Instruments.GREEN,Instruments.YELLOW,Instruments.RED]:
			bind(fixture(spec,0,color))
			check(instruments.gauges.size()==1 and instruments.gauges[0].name==spec.name and instruments.gauges[0].color==color,"source system state "+spec.name)
		reject_corruption(spec)
		for color in [Color.BLACK,Color.WHITE,Instruments.INACTIVE]:
			bind(fixture(spec,0,color))
			check(instruments.gauges.is_empty(),"no invented system off/unknown state "+spec.name)
	var args := OS.get_cmdline_user_args()
	if "--oracle" in args: system_oracle(args[args.find("--oracle")+1])
	if "--native" in args:
		var output: String = args[args.find("--output")+1]
		await native(args[args.find("--fixture")+1],output)
		var receipt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("report.json")))
		for spec in Instruments.system_lamps(): check(receipt.coverage.get(spec.name,0)>0,"recorded visible system placement "+spec.name)
		receipt.checks=checks
		receipt.errors=errors
		FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"  "))
	instruments.clear()
	check(instruments.gauges.is_empty(),"system lamps clear without cached state")
	for error in errors: printerr("FAIL: "+error)
	print("PC_INSTRUMENT_STATUS: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)

func system_oracle(path: String) -> void:
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(report.case_count==198,"complete systems CPU oracle")
	check(report.sim_sha256=="9ee5a5898ddcb8192d30b4083981419515eb3ca220e6cbcd214df628bb164099","original executable authority")
	var count := 0
	for item in report.cases:
		if item.mode!=16: continue
		var plate := 2 if item.kind=="commander_systems" else 5
		var spec: Dictionary = Instruments.system_lamps().filter(func(s):return s.plate==plate)[0]
		var images := fixture(spec,0,Color.BLACK)
		# Restore the first fixture lamp; the oracle alone defines overwritten ink.
		images[0]=instruments.plates[plate].duplicate()
		images[2].fill(Color(float(plate)/255.0,0,0))
		for rect in item.rectangles:
			var rgb: Array = Frame.ART_PALETTE[int(rect[4])]
			for y in range(rect[1],rect[1]+rect[3]):
				for x in range(rect[0],rect[0]+rect[2]):
					images[0].set_pixel(x,y,Color8(rgb[0],rgb[1],rgb[2]))
					images[2].set_pixel(x,y,Color.BLACK)
		bind(images)
		check(instruments.gauges.size()==item.rectangles.size(),"original CPU system rectangles accepted")
		count+=1
	check(count==99,"all default-palette systems oracle cases")

func synthetic_native(viewport: SubViewport, frame: TextureRect, output: String, scale: int) -> void:
	for plate in [2,5]:
		var specs: Array = Instruments.system_lamps().filter(func(s):return s.plate==plate)
		for color in [Instruments.GREEN,Instruments.YELLOW,Instruments.RED]:
			var images := fixture(specs[0],0,color)
			for spec in specs:
				for y in range(spec.source.position.y,spec.source.end.y):
					for x in range(spec.source.position.x,spec.source.end.x):
						images[0].set_pixel(x,y,color)
						images[2].set_pixel(x,y,Color.BLACK)
			var world := ImageTexture.create_from_image(images[0].get_region(Rect2i(0,0,320,136)))
			check(frame.set_frame(images[0],packet_for(images),world),"systems synthetic frame")
			check(frame.instrument_art.gauges.size()==12,"all twelve system lamps")
			var after := await capture(viewport)
			frame.instrument_art.gauges.clear()
			frame.instrument_art.queue_redraw()
			var before := await capture(viewport)
			for y in viewport.size.y:
				for x in viewport.size.x:
					if before.get_pixel(x,y)==after.get_pixel(x,y): continue
					check(specs.any(func(s):return s.source.has_point(Vector2i(x/scale,y/scale))),"system art stays in owned source cells")
			for spec in specs:
				var p := Vector2i((Vector2(spec.source.position)+Vector2(spec.source.size)*0.5)*scale)
				check(after.get_pixelv(p)==color,"native system color survives "+spec.name)
			if scale==6: after.save_png(output.path_join("systems-%d-%s.png"%[plate,color.to_html(false)]))
