extends Control
## Local-only visual review. Extracted and derivative art remains outside res://.
const ART := [
	{"name":"TITLE", "source":"title-original.png", "remaster":"title-v1.png"},
	{"name":"WILSON'S BRIEFING", "source":"office-background-original.png", "remaster":"office-background-v1.png"},
	{"name":"MOTOR POOL", "source":"motor-pool-original.png", "remaster":"motor-pool-v1.png"},
]
var page := 0
var original := false
var textures: Dictionary = {}
var font: Font = preload("res://assets/fonts/IBMPlexMono-Regular.ttf")
var heading: Font = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
var error_message := ""
var controls: Array[Dictionary] = []

func _ready() -> void:
	var root := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("local-art/genesis")
	for entry in ART:
		_load_art(root.path_join("source/"+entry.source),entry.source)
		_load_art(root.path_join("remastered/"+entry.remaster),entry.remaster)
	_load_art(root.path_join("source/wilson-original.png"),"wilson-original.png")
	_load_art(root.path_join("remastered/wilson-v1.png"),"wilson-v1.png")
	_add_button("PREVIOUS",Rect2(32,842,170,40),func(): _change(-1))
	_add_button("NEXT",Rect2(214,842,150,40),func(): _change(1))
	_add_button("ORIGINAL / REMASTER  [TAB]",Rect2(390,842,390,40),_toggle)
	_add_button("RETURN TO GARAGE  [ESC]",Rect2(1212,842,356,40),_back)
	resized.connect(_layout)
	_layout()
	if "--capture-art" in OS.get_cmdline_user_args():
		_capture.call_deferred()

func _load_art(filename: String, key: String) -> void:
	if not FileAccess.file_exists(filename):
		error_message = "Local artwork missing. See docs/genesis-art-workflow.md."
		return
	var image := Image.load_from_file(filename)
	if image == null or image.is_empty():
		error_message = "Cannot read artwork: " + filename.get_file()
		return
	textures[key] = ImageTexture.create_from_image(image)

func _add_button(label: String, area: Rect2, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.add_theme_font_override("font",font)
	button.pressed.connect(action)
	add_child(button)
	controls.append({"node":button,"area":area})

func _layout() -> void:
	var scale_factor := size/Vector2(1600,900)
	for item in controls:
		item.node.position = item.area.position*scale_factor
		item.node.size = item.area.size*scale_factor
		item.node.add_theme_font_size_override("font_size",maxi(12,int(16*scale_factor.y)))
	queue_redraw()

func _change(direction: int) -> void:
	page = posmod(page+direction,ART.size())
	queue_redraw()

func _toggle() -> void:
	original = not original
	queue_redraw()

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE: _back()
		KEY_LEFT: _change(-1)
		KEY_RIGHT: _change(1)

func _input(event: InputEvent) -> void:
	# Intercept Tab before Control uses it for focus traversal.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		_toggle()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("111413"))
	draw_set_transform(Vector2.ZERO,0,size/Vector2(1600,900))
	var label: String = ART[page].name
	draw_string(heading,Vector2(32,39),label,HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color("e1e4cd"))
	draw_string(font,Vector2(760,35),"PC GAMEPLAY  /  GENESIS VISUAL REFERENCE",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("a6b2a2"))
	var art_rect := Rect2(188,63,1224,765) # Native 8:5 framing retained.
	var key: String = ART[page].source if original else ART[page].remaster
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if original else CanvasItem.TEXTURE_FILTER_LINEAR
	if textures.has(key):
		draw_texture_rect(textures[key],art_rect,false)
		if page == 1:
			var portrait := "wilson-original.png" if original else "wilson-v1.png"
			if textures.has(portrait):
				var rect := Rect2(art_rect.position+Vector2(80,32)*(art_rect.size/Vector2(320,200)),Vector2(136,128)*(art_rect.size/Vector2(320,200)))
				draw_texture_rect(textures[portrait],rect,false)
	else:
		draw_string(font,Vector2(250,430),error_message,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("e7b566"))
	draw_string(font,Vector2(820,868),"ORIGINAL" if original else "REMASTER  v1",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("e7b566"))

func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--capture-art")
	if at+1 >= args.size() or not error_message.is_empty():
		push_error("Artwork capture needs an output path and all local source/remaster files.")
		get_tree().quit(1)
		return
	var output := args[at+1]
	DirAccess.make_dir_recursive_absolute(output)
	for p in range(ART.size()):
		page = p
		for mode in [false,true]:
			original = mode
			queue_redraw()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var result := get_viewport().get_texture().get_image().save_png(output.path_join("%02d-%s.png" % [page+1,"original" if original else "remaster"]))
			if result != OK:
				get_tree().quit(1)
				return
	print("ART_REVIEW_PASS: three scenes, original/remaster, external textures, source framing")
	get_tree().quit()
