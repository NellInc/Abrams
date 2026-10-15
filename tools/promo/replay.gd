extends "res://scripts/pc_bridge_viewer.gd"
## Replay recorded original packets through the unchanged production viewer.
var promo_source: String

class ReplayBridge extends RefCounted:
	var pending := true
	var failure := ""
	func start(_python, _state, _saves, _log, _backend, _audit): return true
	func close(): pass
	func has_exited(): return true
	func exit_code(): return 0

## True if path is, or lies under, root/GAME or root/GENESIS, in any case (APFS is case-insensitive).
static func promo_output_inside_source(root: String, path: String) -> bool:
	var target := path.simplify_path().to_lower().trim_suffix("/")+"/"
	for name: String in ["game","genesis"]:
		if target.begins_with(root.simplify_path().to_lower().trim_suffix("/").path_join(name)+"/"): return true
	return false

func fail(message: String) -> void:
	printerr(message)
	quit(1)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var packets := args.find("--packets")
	if not ("--capture" in args and "--no-audio" in args and "--play" in args and "--trace" in args) or packets<0 or packets+1>=args.size():
		printerr("PROMO_REPLAY requires --packets <file> --capture --no-audio --play --trace")
		quit(2)
		return
	promo_source=args[packets+1]
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var requested := args.find("--output")
	if requested>=0 and requested+1<args.size() and promo_output_inside_source(directory,anchor_path(directory,args[requested+1])):
		printerr("PROMO_REPLAY --output must be outside original sources")
		quit(2)
		return
	bridge=ReplayBridge.new()
	super._initialize()
	run_promo.call_deferred()

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec()-started>900000:
		printerr("PROMO_REPLAY exceeded its finite 15-minute bound")
		quit(2)
	return false

func run_promo() -> void:
	if not (startup_ready and play_mode and not boot_mode):
		fail("PROMO_REPLAY viewer did not reach trace Play startup");return
	var file := FileAccess.open(promo_source,FileAccess.READ)
	if file == null:
		fail("PROMO_REPLAY cannot open %s: %s"%[promo_source,error_string(FileAccess.get_open_error())]);return
	var index := 0
	var records: Array=[]
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty(): continue
		var parsed: Variant=JSON.parse_string(line)
		if not parsed is Dictionary:
			fail("PROMO_REPLAY bad packet after frame %d in %s"%[index,promo_source]);return
		var packet: Dictionary=parsed
		_apply_sample(packet)
		if not bridge.failure.is_empty():
			fail(bridge.failure);return
		# Only a SIM packet whose draw pass carries a scanout-paired camera must
		# pair the world; there a source fallback is transient and never recorded.
		# Camera-less packets (frontends, motor pool, debrief, map) and EGA/Genesis
		# keep their declared fallback, which the receipt lists per frame.
		var program: Variant=packet.get("program")
		var presentation: Variant=packet.get("presentation")
		var scanout_camera: bool = program is Dictionary and program.get("name")=="SIM" and presentation is Dictionary \
			and presentation.get("draw_pass") is Dictionary and presentation.draw_pass.get("camera") is Dictionary
		if scanout_camera and tandem_frame.graphics_mode in ["upscaled","modern","tactical"] and not tandem_frame.world_enabled:
			fail("PROMO_REPLAY frame %d: %s did not pair a camera-carrying SIM packet (%s)"%[index,tandem_frame.graphics_mode,tandem_frame.fallback_reason]);return
		# Same readback as modern_batch.gd: pair the world and composition first,
		# and read the tandem composition, never the diagnostic root window.
		world_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		tandem_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		await process_frame
		RenderingServer.force_draw(false)
		RenderingServer.force_sync()
		await process_frame
		RenderingServer.force_draw(false)
		RenderingServer.force_sync()
		var image := tandem_viewport.get_texture().get_image()
		if image.get_width()*3!=image.get_height()*4:
			fail("PROMO_REPLAY frame %d: capture is %dx%d, not 4:3"%[index,image.get_width(),image.get_height()]);return
		var saved := image.save_png(output.path_join("frame_%05d.png"%index))
		if saved!=OK:
			fail("PROMO_REPLAY frame %d: cannot save PNG: %s"%[index,error_string(saved)]);return
		records.append({"source_index":index,"sequence":packet.get("sequence"),"mode":tandem_frame.graphics_mode,"scanout_camera":scanout_camera,"world_enabled":tandem_frame.world_enabled,"fallback_reason":tandem_frame.fallback_reason,"size":[image.get_width(),image.get_height()]})
		index+=1
	file.close()
	var receipt := FileAccess.open(output.path_join("promo-replay-receipt.json"),FileAccess.WRITE)
	if receipt==null:
		fail("PROMO_REPLAY cannot write its receipt: %s"%error_string(FileAccess.get_open_error()));return
	receipt.store_string(JSON.stringify({"packets":promo_source,"packets_sha256":FileAccess.get_sha256(promo_source),"frames":records,"scope":"Recorded original packets through the unchanged production Play viewer; tandem composition only, never the diagnostic window."},"  "))
	receipt.close()
	print("PROMO_REPLAY_COMPLETE %d frames, %s"%[index,tandem_frame.graphics_mode])
	quit(0)
