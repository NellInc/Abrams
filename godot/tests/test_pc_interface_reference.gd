extends "res://scripts/portable_setup.gd"
## UI-only fixture: no original game, host, import, profile or audio backend.
var checks := 0
var failures: Array[String] = []

func _request(_arguments: Array) -> void:
	installed=false
	play.disabled=true
	genesis.disabled=true
	pc.disabled=false
	message.text="Choose the supported original PC game folder to begin."

func _initialize() -> void:
	root.gui_embed_subwindows=true
	super._initialize()
	create_timer(60).timeout.connect(func(): printerr("FAIL: UI fixture deadline"); quit(1))
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks+=1
	if not ok: failures.append(description)

func _inspect(node: Node) -> void:
	if node is Window and node!=root and not node.visible: return
	if node is Control and node.is_visible_in_tree() and node is not ColorRect and node is not TextureRect:
		var rect: Rect2 = node.get_global_rect()
		check(rect.position.x>=-1 and rect.position.y>=-1 and rect.end.x<=root.size.x+1 and rect.end.y<=root.size.y+1,"within viewport: "+str(node.get_path()))
	for child in node.get_children():_inspect(child)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := ""
	for i in args.size():
		if args[i]=="--output" and i+1<args.size(): output=args[i+1]
	check(InterfaceTheme.reference_path("../elsewhere").is_empty(),"reference path rejects traversal")
	check(InterfaceTheme.open_reference("missing.html")==ERR_FILE_NOT_FOUND,"unknown reference never launches")
	check(InterfaceTheme.reference_path("field-guide.html").ends_with("docs/player-reference/field-guide.html"),"reference path uses installed sibling payload")
	check(not installed and play.disabled and genesis.disabled and not pc.disabled,"original-required controls")
	check(thread==null and not busy,"fixture starts no host worker")
	for size in [Vector2i(820,700),Vector2i(760,660),Vector2i(1024,800)]:
		root.size=size
		await process_frame
		await process_frame
		_inspect(root)
		if not output.is_empty():
			await RenderingServer.frame_post_draw
			var view := root.get_texture().get_image()
			check(view.save_png(output.path_join("setup-%dx%d.png"%[size.x,size.y]))==OK,"setup screenshot")
	_about()
	await process_frame
	check(root.get_child(root.get_child_count()-1) is AcceptDialog,"About opens without the runtime")
	if not output.is_empty():
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("setup-about.png"))==OK,"About screenshot")
	for error in failures:printerr("FAIL: "+error)
	print("PC_INTERFACE_REFERENCE: %d checks, %d errors"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
