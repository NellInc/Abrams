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

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	assert("--packets" in args and "--capture" in args and "--no-audio" in args)
	promo_source=args[args.find("--packets")+1]
	bridge=ReplayBridge.new()
	super._initialize()
	run_promo.call_deferred()

func _process(_delta: float) -> bool: return false

func run_promo() -> void:
	var file := FileAccess.open(promo_source,FileAccess.READ)
	var index := 0
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty(): continue
		var packet: Dictionary=JSON.parse_string(line)
		_apply_sample(packet)
		await process_frame
		RenderingServer.force_draw(false)
		RenderingServer.force_sync()
		if not bridge.failure.is_empty():
			printerr(bridge.failure);quit(1);return
		root.get_texture().get_image().save_png(output.path_join("frame_%05d.png"%index))
		index+=1
	print("PROMO_REPLAY_COMPLETE %d frames, %s"%[index,tandem_frame.graphics_mode])
	quit(0)
