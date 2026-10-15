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

## True if path is, or lies under, root/GAME or root/GENESIS, in any case (APFS is case-insensitive).
static func promo_output_inside_source(root: String, path: String) -> bool:
	var target := path.simplify_path().to_lower().trim_suffix("/")+"/"
	for name: String in ["game","genesis"]:
		if target.begins_with(root.simplify_path().to_lower().trim_suffix("/").path_join(name)+"/"): return true
	return false

## Checks never use assert(): it aborts only the function (leaving the watchdog to
## expire) and release builds strip it, side effects included.
func fail(message: String) -> void:
	printerr(message)
	quit(1)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var graphics := args.find("--graphics")
	var roster := args.find("--roster")
	if not ("--capture" in args and "--no-audio" in args and "--play" in args and "--trace" in args) or graphics<0 or graphics+1>=args.size() or args[graphics+1]!="modern" or roster<0 or roster+1>=args.size():
		printerr("MODERN_BATCH requires --capture --no-audio --play --trace --graphics modern --roster <file>")
		quit(2)
		return
	roster_path=args[roster+1]
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var requested := args.find("--output")
	if requested>=0 and requested+1<args.size() and promo_output_inside_source(directory,anchor_path(directory,args[requested+1])):
		printerr("MODERN_BATCH --output must be outside original sources")
		quit(2)
		return
	bridge=ReplayBridge.new()
	super._initialize()
	render_batch.call_deferred()

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec()-started>900000:
		printerr("MODERN_BATCH exceeded its finite 15-minute bound")
		quit(2)
	return false

func render_batch() -> void:
	if not (startup_ready and play_mode and not boot_mode):
		fail("MODERN_BATCH viewer did not reach trace Play startup");return
	if not (tandem_frame.modern_available and draw_view.modern_enabled):
		fail("MODERN_BATCH Modern graphics are unavailable");return
	await process_frame
	await process_frame
	var parsed_roster: Variant=JSON.parse_string(FileAccess.get_file_as_string(roster_path))
	if not parsed_roster is Array:
		fail("MODERN_BATCH cannot read roster %s"%roster_path);return
	var roster: Array=parsed_roster
	var results: Array=[]
	for clip: Dictionary in roster:
		if FileAccess.get_sha256(clip.packets)!=clip.sha256:
			fail("MODERN_BATCH %s: %s does not match the roster SHA-256"%[clip.name,clip.packets]);return
		var file:=FileAccess.open(clip.packets,FileAccess.READ)
		if file==null:
			fail("MODERN_BATCH %s: cannot open %s: %s"%[clip.name,clip.packets,error_string(FileAccess.get_open_error())]);return
		var destination: String=output.path_join(clip.name)
		if DirAccess.dir_exists_absolute(destination):
			fail("MODERN_BATCH %s: %s already exists"%[clip.name,destination]);return
		DirAccess.make_dir_recursive_absolute(destination)
		invalidate_presentation_cache()
		var index:=0
		var count:=0
		var records: Array=[]
		while not file.eof_reached():
			var line:=file.get_line()
			if line.is_empty(): continue
			# Number every packet, but parse only the clip's own window.
			if index<clip.begin:
				index+=1
				continue
			if index>=clip.end: break
			var where:="MODERN_BATCH %s frame %d: "%[clip.name,index]
			var parsed: Variant=JSON.parse_string(line)
			if not parsed is Dictionary:
				fail(where+"packet is not a JSON object");return
			var packet: Dictionary=parsed
			if not (packet.get("state") is Dictionary and packet.state.get("station")==clip.station):
				fail(where+"packet is not from station %s"%str(clip.station));return
			if not (packet.get("presentation") is Dictionary and packet.presentation.get("draw_pass") is Dictionary):
				fail(where+"packet carries no draw pass");return
			_apply_sample(packet)
			if not bridge.failure.is_empty():
				fail(where+bridge.failure);return
			if not (tandem_frame.graphics_mode=="modern" and draw_view.modern_enabled):
				fail(where+"left Modern graphics (%s)"%tandem_frame.graphics_mode);return
			if not draw_view._modern_active:
				fail(where+"Modern rejected this source frame (%s)"%draw_view.modern_frame_status);return
			if not (tandem_frame.world_enabled and tandem_frame.fallback_reason.is_empty()):
				fail(where+"world not paired (%s)"%tandem_frame.fallback_reason);return
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
			if image.get_width()*3!=image.get_height()*4:
				fail(where+"capture is %dx%d, not 4:3"%[image.get_width(),image.get_height()]);return
			var saved:=image.save_png(destination.path_join("frame_%05d.png"%count))
			if saved!=OK:
				fail(where+"cannot save PNG: %s"%error_string(saved));return
			records.append({"source_index":index,"sequence":packet.sequence,"mode":tandem_frame.graphics_mode,"world_enabled":tandem_frame.world_enabled,"modern_enabled":draw_view.modern_enabled,"modern_active":draw_view._modern_active,"modern_frame_status":draw_view.modern_frame_status,"size":[image.get_width(),image.get_height()]})
			count+=1
			index+=1
		file.close()
		if count!=clip.end-clip.begin:
			fail("MODERN_BATCH %s: captured %d frames, expected %d"%[clip.name,count,clip.end-clip.begin]);return
		results.append({"name":clip.name,"packets":clip.packets,"source_sha256":clip.sha256,"frames":records})
	var receipt:=FileAccess.open(output.path_join("modern-capture-receipt.json"),FileAccess.WRITE)
	if receipt==null:
		fail("MODERN_BATCH cannot write its receipt: %s"%error_string(FileAccess.get_open_error()));return
	receipt.store_string(JSON.stringify({"roster_sha256":FileAccess.get_sha256(roster_path),"clips":results,"scope":"Actual original packet replay through unmodified production Play/Modern renderer, isolated presentation only. All captured frames checked Modern, paired world, fixed station and complete 4:3."},"  "))
	receipt.close()
	print("MODERN_BATCH_COMPLETE clips=%d"%results.size())
	quit(0)
