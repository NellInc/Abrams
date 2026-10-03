extends "res://tests/test_pc_gauges.gd"
func run() -> void:
	repo = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	instruments = Instruments.new()
	root.add_child(instruments)
	var loaded: bool=instruments.load_sources(repo,Image.load_from_file(repo.path_join("local-art/genesis/cockpit-v2/gunner-genesis-v1.png")))
	check(loaded,"source loaded")
	var spec: Dictionary=Instruments.LAMPS.filter(func(s):return s.has("lock"))[0]
	check(instruments.plates.has(spec.plate),"lock plate %d available"%spec.plate)
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(repo.path_join("artifacts/finish-20260928/target-lock-oracle.json")))
	var oracle_ok: bool=parsed is Dictionary and parsed.get("cases") is Array
	check(oracle_ok and parsed.get("case_count")==8,"eight source instruction fixtures")
	# Missing local inputs must fail promptly, not abort run() before quit().
	if not loaded or not instruments.plates.has(spec.plate) or not oracle_ok: done(); return
	var report: Dictionary=parsed
	for item in report.cases:
		if item.mode!=16: continue
		var rgb: Array=Frame.ART_PALETTE[int(item.rectangles[0][4])]
		bind(fixture(spec,0,Color8(rgb[0],rgb[1],rgb[2])))
		check(instruments.gauges.size()==1 and instruments.gauges[0].name==spec.name,"original lock/off lamp")
	for color in [Instruments.GREEN,Instruments.YELLOW,Color.WHITE]:
		bind(fixture(spec,0,color))
		check(instruments.gauges.is_empty(),"unknown lock colour rejected")
	reject_corruption(spec)
	var args := OS.get_cmdline_user_args()
	if "--native" in args:
		var output: String=args[args.find("--output")+1]
		DirAccess.make_dir_recursive_absolute(output)
		var viewport := SubViewport.new()
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var frame := Frame.new()
		viewport.add_child(frame)
		check(frame.load_genesis_art(repo),"native tandem assets")
		for scale in [4,6]:
			viewport.size=Vector2i(320,200)*scale
			frame.size=Vector2(viewport.size)
			await synthetic_native(viewport,frame,output,scale)
		FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors,"scope":"all temperature and target-lock source states at4x6x; integrated palette rejection"},"  "))
		viewport.queue_free()
	done()
func done() -> void:
	for error in errors: printerr("FAIL: "+error)
	print("PC_INSTRUMENT_LOCK: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
