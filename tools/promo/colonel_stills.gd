extends SceneTree
## Replay one genuine BRIEF frame through both production graphics modes.
var started := Time.get_ticks_msec()
func _initialize() -> void: render.call_deferred()
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec()-started>60000: printerr("COLONEL_RENDER timeout");quit(2)
	return false
## True if path is, or lies under, root/GAME or root/GENESIS, in any case (APFS is case-insensitive).
static func promo_output_inside_source(root: String, path: String) -> bool:
	var target := path.simplify_path().to_lower().trim_suffix("/")+"/"
	for name: String in ["game","genesis"]:
		if target.begins_with(root.simplify_path().to_lower().trim_suffix("/").path_join(name)+"/"): return true
	return false
## No assert(): a failed one leaves the watchdog to expire, and release builds strip
## it together with any side effect inside it.
func fail(message: String) -> void:
	printerr("COLONEL_RENDER "+message);quit(1)
func render() -> void:
	var args := OS.get_cmdline_user_args()
	var requested := args.find("--output")
	if requested<0 or requested+1>=args.size():
		fail("requires --output <directory>");return
	var root_path:=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var output: String=ProjectSettings.globalize_path(args[requested+1])
	if output.is_relative_path(): output=root_path.path_join(output)
	if promo_output_inside_source(root_path,output):
		fail("--output must be outside original sources");return
	var fixture:=root_path.path_join("artifacts/pc-live-type-lifecycle-01/report.json")
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(fixture))
	if not parsed is Dictionary:
		fail("cannot read "+fixture);return
	var data:Dictionary=parsed
	var entry:Dictionary={}
	for item:Dictionary in data.samples:
		if item.label=="boot-17":entry=item;break
	if entry.is_empty():
		fail("boot-17 is missing from "+fixture);return
	if entry.program.name!="BRIEF":
		fail("boot-17 is %s, not BRIEF"%entry.program.name);return
	var source:=Image.load_from_file(fixture.get_base_dir().path_join(entry.image))
	if source==null:
		fail("cannot load "+entry.image);return
	var view:=SubViewport.new();view.size=Vector2i(1280,960);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var frame:=preload("res://scripts/pc_tandem_frame.gd").new();frame.size=view.size;view.add_child(frame)
	var genesis_loaded:=frame.load_genesis_art(root_path)
	if not genesis_loaded:
		fail("Genesis art did not load");return
	var sources_loaded:=frame.load_graphics_sources(root_path)
	if not sources_loaded:
		fail("graphics sources did not load");return
	frame.modern_available=true
	DirAccess.make_dir_recursive_absolute(output)
	var receipts:Array=[]
	for mode:String in ["genesis","modern"]:
		var switched:=frame.set_graphics_mode(mode)
		if not switched:
			fail("cannot switch to "+mode);return
		# set_frame's result describes the 3D world. BRIEF has no such world;
		# its independently verified frontend is presented in the next call.
		frame.set_frame(source,entry.presentation,null,entry.program)
		var restored:=frame.present_frontend(entry.program)
		if mode=="modern" and not (restored and not frame.frontend_art.active.is_empty()):
			fail("Modern did not restore the BRIEF frontend");return
		await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
		var result:=view.get_texture().get_image()
		var saved:=result.save_png(output.path_join("colonel-"+mode+".png"))
		if saved!=OK:
			fail("cannot save colonel-%s.png: %s"%[mode,error_string(saved)]);return
		receipts.append({"mode":mode,"source_label":entry.label,"source_image_sha256":FileAccess.get_sha256(fixture.get_base_dir().path_join(entry.image)),"framebuffer_size":[1280,960]})
	var receipt:=FileAccess.open(output.path_join("colonel-render-receipt.json"),FileAccess.WRITE)
	if receipt==null:
		fail("cannot write its receipt: "+error_string(FileAccess.get_open_error()));return
	receipt.store_string(JSON.stringify({"fixture":fixture,"samples":receipts,"scope":"Actual BRIEF source frame, unchanged production Genesis and Modern compositors."},"  "))
	receipt.close()
	print("COLONEL_RENDER_COMPLETE");quit(0)
