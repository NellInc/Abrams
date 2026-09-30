extends "res://scripts/pc_bridge_viewer.gd"
## Ordinary non-capture startup, including the actual first painted cover.
var checks := 0
var errors: Array[String] = []
var mode := ""
var draw_seen := false
var loading_started := false
var finishing_test := false
var report_written := false
var observed_game := false
var timeout := Time.get_ticks_msec()+180000

class InvalidFrameBridge extends RefCounted:
	var pending := true
	var failure := ""
	var delivered := false
	func start(_python, _state, _saves, _log, _backend, _audit): return true
	func poll() -> Array[Dictionary]:
		if delivered: return []
		delivered=true;pending=false
		return [{"type":"ready","fps":59.9227,"png":"","sequence":0,"program":{"name":"START"}}]
	func close(): pass
	func has_exited(): return true
	func exit_code(): return 1

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: errors.append(reason)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not ["--play","--boot","--no-audio","--output","--startup-test"].all(func(flag):return flag in args) or "--capture" in args:
		printerr("Startup viewer test requires non-capture boot/play/no-audio/output/startup-test")
		quit(2)
		return
	mode=args[args.find("--startup-test")+1]
	if mode not in ["normal","early-close","invalid-frame"]:
		quit(2)
		return
	if mode=="invalid-frame": bridge=InvalidFrameBridge.new()
	RenderingServer.frame_post_draw.connect(_first_draw)
	super._initialize()
	check(not startup_ready and not loading_started,"startup yields before heavyweight loading")
	if mode=="early-close": _close.call_deferred()

func _first_draw() -> void:
	if draw_seen: return
	draw_seen=true

func _load_world_presentation(directory: String, args: Array) -> void:
	loading_started=true
	check(draw_seen,"splash actually drawn before asset preload")
	check(startup_splash.visible,"cover visible at preload entry")
	check(root.get_texture().get_image().save_png(output.path_join("before-preload.png"))==OK,"first native cover captured")
	super._load_world_presentation(directory,args)

func _apply_sample(message: Dictionary) -> void:
	super._apply_sample(message)
	if not bridge.failure.is_empty():
		check(startup_splash.visible and not startup_splash.finished,"invalid source pixels retain startup cover")
		return
	if observed_game: return
	observed_game=true
	check(not startup_splash.visible and startup_splash.finished,"first valid paired frame immediately replaces cover")
	check(not status.visible,"loading caption absent over original game")
	check(samples==1,"handoff needs no extra guest frame")
	finish_test.call_deferred()

func finish_test() -> void:
	if finishing_test: return
	finishing_test=true
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	check(root.get_texture().get_image().save_png(output.path_join("first-game-frame.png" if observed_game else "startup-error.png"))==OK,"native handoff/error photograph")
	if mode=="invalid-frame":
		check(startup_splash.visible and startup_splash.failed,"source failure remains visible")
		check(status.text.contains("invalid original framebuffer") and status.text.contains("Close this window"),"failure explains how to exit")
	_close()

func _close() -> void:
	if mode=="early-close":
		check(not loading_started and bridge.process.is_empty(),"early Close starts no presentation load or guest")
		write_report()
	super._close()

func write_report() -> void:
	if report_written: return
	report_written=true
	FileAccess.open(output.path_join("startup-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"mode":mode,"checks":checks,"errors":errors,"draw_seen":draw_seen,"loading_started":loading_started,"observed_game":observed_game,"source_samples":samples,"bridge_failure":bridge.failure,"child_exited":bridge.has_exited()},"  "))
	for error in errors: printerr("FAIL: "+error)
	print("PC_STARTUP_VIEWER: %s, %d checks, %d errors"%[mode,checks,errors.size()])

func _process(delta: float) -> bool:
	if closing and bridge.has_exited():
		write_report()
		if not errors.is_empty(): quit(3);return false
	if Time.get_ticks_msec()>timeout:
		check(false,"bounded startup deadline")
		write_report()
		_close()
	if startup_ready and mode=="invalid-frame" and not bridge.failure.is_empty() and not finishing_test:
		finish_test.call_deferred()
	return super._process(delta)
