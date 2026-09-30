extends Control
## Restored box cover during local startup. No input, clock or guest-frame logic.
signal reference_selected(name: String)
var references := HBoxContainer.new()
var attribution := Label.new()
const COVER_PATH := "branding/abrams-cover-remastered.png"
var cover := TextureRect.new()
var message := Label.new()
var fallback := Label.new()
var artwork_rect := Rect2()
var finished := false
var failed := false
var frame := StyleBoxFlat.new()
var backdrop := GradientTexture2D.new()

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	focus_mode=Control.FOCUS_NONE
	backdrop.width=256;backdrop.height=256
	backdrop.fill=GradientTexture2D.FILL_RADIAL
	backdrop.fill_from=Vector2(0.5,0.4);backdrop.fill_to=Vector2(1.0,1.0)
	backdrop.gradient=Gradient.new()
	backdrop.gradient.colors=PackedColorArray([Color("451811"),Color("090a0a")])
	frame.bg_color=Color("130b08")
	frame.border_color=Color(0.74,0.49,0.22,0.35)
	frame.set_border_width_all(1)
	frame.shadow_color=Color(0,0,0,0.65)
	frame.shadow_size=18
	cover.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	cover.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(cover)
	fallback.text="M1 ABRAMS\nBATTLE TANK\n\nFAN REMASTER\n\nOriginal game by Dynamix"
	fallback.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	fallback.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	fallback.add_theme_color_override("font_color",Color("ffeed6"))
	fallback.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(fallback)
	message.text="Starting the original PC game…"
	message.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_color_override("font_color",Color("e5d2b5"))
	message.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(message)
	attribution.text="Original game by Dynamix · Published by Electronic Arts · Version "+str(ProjectSettings.get_setting("application/config/version","development"))
	attribution.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	attribution.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	attribution.add_theme_font_size_override("font_size",14)
	attribution.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(attribution)
	references.theme=preload("res://scripts/pc_interface_theme.gd").build()
	references.alignment=BoxContainer.ALIGNMENT_CENTER
	for title in ["Keyboard controls","Field guide","Original credits"]:
		var button := Button.new()
		button.text=title
		button.pressed.connect(func():reference_selected.emit("keyboard-controls.html" if title=="Keyboard controls" else "credits" if title=="Original credits" else "field-guide.html"))
		references.add_child(button)
	add_child(references)
	resized.connect(_layout)

func load_cover(directory: String) -> bool:
	var path := directory.path_join(COVER_PATH)
	if not FileAccess.file_exists(path): return false
	var image := Image.load_from_file(path)
	if image==null or image.is_empty(): return false
	cover.texture=ImageTexture.create_from_image(image)
	fallback.hide()
	_layout()
	return true

func _ready() -> void: _layout()

func _layout() -> void:
	if size.x<1 or size.y<1: return
	var margin := clampf(minf(size.x,size.y)*0.032,14.0,42.0)
	var font_size := clampi(roundi(size.y/44.0),14,22)
	message.add_theme_font_size_override("font_size",font_size)
	message.size=Vector2(maxf(1,size.x-margin*2),0)
	# Calculate wrapped height after assigning the actual window width. Errors
	# retain their complete message and Close instruction at the minimum size.
	var message_height := maxf(message.get_minimum_size().y,font_size*1.5)
	references.position=Vector2(margin,size.y-margin-44)
	references.size=Vector2(size.x-margin*2,40)
	attribution.position=Vector2(margin,references.position.y-42)
	attribution.size=Vector2(size.x-margin*2,38)
	message.position=Vector2(margin,attribution.position.y-14-message_height)
	message.size.y=message_height
	var available := Vector2(maxf(1,size.x-margin*2),maxf(1,message.position.y-margin*2-14))
	var extent := available
	if cover.texture:
		var source := cover.texture.get_size()
		extent=source*minf(available.x/source.x,available.y/source.y)
	artwork_rect=Rect2(Vector2((size.x-extent.x)*0.5,margin),extent)
	cover.position=artwork_rect.position;cover.size=artwork_rect.size
	fallback.position=Vector2(margin,margin);fallback.size=available
	fallback.add_theme_font_size_override("font_size",clampi(roundi(size.y/22.0),20,42))
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(backdrop,Rect2(Vector2.ZERO,size),false)
	if cover.texture: draw_style_box(frame,artwork_rect.grow(1))
	var y := message.position.y-12
	var width := minf(160,size.x*0.22)
	draw_line(Vector2((size.x-width)*0.5,y),Vector2((size.x+width)*0.5,y),Color("a97b40"),1,true)

func finish() -> void:
	if finished or failed: return
	finished=true
	hide()

func show_error(text: String) -> void:
	failed=true
	message.text=text
	message.show()
	show()
	_layout()
