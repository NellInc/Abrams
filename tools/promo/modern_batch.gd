extends "res://scripts/pc_bridge_viewer.gd"
## Finite promo-only replay. Production presentation, no guest or keyboard input.
var roster_path: String
class ReplayBridge extends RefCounted:
	var pending := true
	var failure := ""
	func start(_python, _state, _saves, _log, _backend, _audit): return true
	func close(): pass
	func has_exited(): return true
	func exit_code(): return 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	assert("--capture" in args and "--no-audio" in args and "--play" in args)
	assert("--trace" in args and args[args.find("--graphics")+1]=="modern")
	roster_path=args[args.find("--roster")+1]
	bridge=ReplayBridge.new()
	super._initialize()
	render_batch.call_deferred()

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec()-started>900000:
		printerr("MODERN_BATCH exceeded its finite 15-minute bound")
		quit(2)
	return false

func render_batch() -> void:
	assert(startup_ready and play_mode and not boot_mode)
	assert(tandem_frame.modern_available and draw_view.modern_enabled)
	await process_frame
	await process_frame
	var roster: Array=JSON.parse_string(FileAccess.get_file_as_string(roster_path))
	var results: Array=[]
	for clip: Dictionary in roster:
		assert(FileAccess.get_sha256(clip.packets)==clip.sha256)
		var file:=FileAccess.open(clip.packets,FileAccess.READ)
		var destination: String=output.path_join(clip.name)
		assert(not DirAccess.dir_exists_absolute(destination))
		DirAccess.make_dir_recursive_absolute(destination)
		invalidate_presentation_cache()
		var index:=0
		var count:=0
		var records: Array=[]
		while not file.eof_reached():
			var line:=file.get_line()
			if line.is_empty(): continue
			var packet: Dictionary=JSON.parse_string(line)
			if index<clip.begin or index>=clip.end:
				index+=1
				continue
			assert(packet.state.station==clip.station)
			assert(packet.presentation.draw_pass is Dictionary)
			_apply_sample(packet)
			assert(bridge.failure.is_empty())
			assert(tandem_frame.graphics_mode=="modern" and draw_view.modern_enabled)
			assert(draw_view._modern_active, "Modern palette/ownership rejected this source frame")
			assert(tandem_frame.world_enabled and tandem_frame.fallback_reason.is_empty())
			# Pair the world and composition before readback. Never capture the
			# diagnostic root, transient source fallback, or previous GPU pass.
			world_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			tandem_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			await process_frame
			RenderingServer.force_draw(false)
			RenderingServer.force_sync()
			await process_frame
			RenderingServer.force_draw(false)
			RenderingServer.force_sync()
			var image:=tandem_viewport.get_texture().get_image()
			assert(image.get_width()*3==image.get_height()*4)
			assert(image.save_png(destination.path_join("frame_%05d.png"%count))==OK)
			records.append({"source_index":index,"sequence":packet.sequence,"mode":tandem_frame.graphics_mode,"world_enabled":tandem_frame.world_enabled,"modern_enabled":draw_view.modern_enabled,"modern_active":draw_view._modern_active,"modern_frame_status":draw_view.modern_frame_status,"size":[image.get_width(),image.get_height()]})
			count+=1
			index+=1
		assert(count==clip.end-clip.begin)
		results.append({"name":clip.name,"packets":clip.packets,"source_sha256":clip.sha256,"frames":records})
	var receipt:=FileAccess.open(output.path_join("modern-capture-receipt.json"),FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"roster_sha256":FileAccess.get_sha256(roster_path),"clips":results,"scope":"Actual original packet replay through unmodified production Play/Modern renderer, isolated presentation only. All captured frames assert Modern, paired world, fixed station and complete 4:3."},"  "))
	print("MODERN_BATCH_COMPLETE clips=%d"%results.size())
	quit(0)
