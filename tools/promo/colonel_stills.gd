extends SceneTree
## Replay one genuine BRIEF frame through both production graphics modes.
var started := Time.get_ticks_msec()
func _initialize() -> void: render.call_deferred()
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec()-started>60000: printerr("COLONEL_RENDER timeout");quit(2)
	return false
func render() -> void:
	var args := OS.get_cmdline_user_args()
	var output: String=args[args.find("--output")+1]
	var root_path:=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var fixture:=root_path.path_join("artifacts/pc-live-type-lifecycle-01/report.json")
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture))
	var entry:Dictionary={}
	for item:Dictionary in data.samples:
		if item.label=="boot-17":entry=item;break
	assert(not entry.is_empty())
	assert(entry.program.name=="BRIEF")
	var source:=Image.load_from_file(fixture.get_base_dir().path_join(entry.image))
	assert(source!=null)
	var view:=SubViewport.new();view.size=Vector2i(1280,960);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var frame:=preload("res://scripts/pc_tandem_frame.gd").new();frame.size=view.size;view.add_child(frame)
	assert(frame.load_genesis_art(root_path));assert(frame.load_graphics_sources(root_path))
	frame.modern_available=true
	DirAccess.make_dir_recursive_absolute(output)
	var receipts:Array=[]
	for mode:String in ["genesis","modern"]:
		assert(frame.set_graphics_mode(mode))
		# set_frame's result describes the 3D world. BRIEF has no such world;
		# its independently verified frontend is presented in the next call.
		frame.set_frame(source,entry.presentation,null,entry.program)
		var restored:=frame.present_frontend(entry.program)
		if mode=="modern":assert(restored and not frame.frontend_art.active.is_empty())
		await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
		var result:=view.get_texture().get_image()
		assert(result.save_png(output.path_join("colonel-"+mode+".png"))==OK)
		receipts.append({"mode":mode,"source_label":entry.label,"source_image_sha256":FileAccess.get_sha256(fixture.get_base_dir().path_join(entry.image)),"framebuffer_size":[1280,960]})
	var receipt:=FileAccess.open(output.path_join("colonel-render-receipt.json"),FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"fixture":fixture,"samples":receipts,"scope":"Actual BRIEF source frame, unchanged production Genesis and Modern compositors."},"  "))
	print("COLONEL_RENDER_COMPLETE");quit(0)
