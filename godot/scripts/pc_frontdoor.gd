extends Control
## Presentation-only cover and Extras. The viewer owns the guest and shutdown.
signal game_selected(destination: String)
signal quit_selected
signal original_selected
var menu: MenuBar
var main: Node3D
var stage: SubViewport
var stage_container: SubViewportContainer
var artwork: Control
var settings_page: Control
var settings_columns: GridContainer
var settings_error: Label
var route_panel: Control
var route_message: Label
var original_button: Button
var busy := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=preload("res://scripts/pc_interface_theme.gd").build()
	stage_container=SubViewportContainer.new()
	stage_container.stretch=true
	add_child(stage_container)
	stage_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage=SubViewport.new()
	stage.own_world_3d=true
	stage.gui_embed_subwindows=true
	stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	stage_container.add_child(stage)
	main=load("res://scenes/main.tscn").instantiate()
	main.embedded=true
	stage.add_child(main)
	main.game_selected.connect(func(choice):game_selected.emit(choice))
	main.settings_selected.connect(open_settings)
	main.artwork_selected.connect(open_artwork)
	main.quit_selected.connect(func():quit_selected.emit())
	menu.mix_changed.connect(_apply_mix)
	_apply_mix()
	resized.connect(_resize_settings)
	set_active(false)

func _apply_mix() -> void:
	main.sound.volume=0.65*float(menu.settings.master)/100.0
	main.sound.effects_volume=float(menu.settings.effects)/100.0
	main.sound.voice_volume=float(menu.settings.voice)/100.0
	main.sound.engine_volume=float(menu.settings.motors)/100.0
	for cue in main.sound.EFFECT_CUES:main.sound.cue_volumes[cue]=float(menu.settings[cue])/100.0
	main.sound.refresh_effect_gains()

func set_active(active: bool) -> void:
	visible=active
	process_mode=Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if not active:main.sound.stop_all()
	else:
		main.commands.clear()
		main.ui.rebuild_buttons()

func _panel() -> MarginContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color=Color("0d1712")
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,28)
	panel.add_child(margin)
	return margin

func _label(value: String, font_size := 20) -> Label:
	var label := Label.new()
	label.text=value
	label.add_theme_font_size_override("font_size",font_size)
	return label

func open_settings() -> void:
	main.ui.hide()
	var margin := _panel()
	settings_page=margin.get_parent()
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",18)
	margin.add_child(stack)
	stack.add_child(_label("SETTINGS",36))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	settings_columns=GridContainer.new()
	settings_columns.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	settings_columns.add_theme_constant_override("h_separation",48)
	settings_columns.add_theme_constant_override("v_separation",24)
	scroll.add_child(settings_columns)
	var display := _settings_group("DISPLAY")
	var modes: Array=menu.available_graphics_modes()
	var names: Array=[]
	for mode in modes:names.append({"ega":"EGA","ega_upscaled":"EGA Upscaled","genesis":"Genesis","upscaled":"Genesis Upscaled","modern":"Modern","tactical":"Tactical"}[mode])
	_choice(display,"Graphics",modes,names,menu.graphics_mode,menu.choose_graphics)
	_choice(display,"HUD style",menu.HUD_STYLES,["Restored","Tactical"],menu.hud_style,menu.choose_hud_style)
	_choice(display,"Antialiasing",menu.QUALITY_LEVELS.msaa,["Off","2x","4x","8x"],menu.quality.msaa,func(value):menu.choose_quality("msaa",value))
	_choice(display,"Texture filtering",menu.QUALITY_LEVELS.anisotropy,["Off","2x","4x","8x","16x"],menu.quality.anisotropy,func(value):menu.choose_quality("anisotropy",value))
	var audio := _settings_group("AUDIO")
	for channel in menu.audio_channels():
		var row := VBoxContainer.new()
		audio.add_child(row)
		var title := _label(menu.TITLES[channel]+": %d%%"%menu.settings[channel])
		row.add_child(title)
		var slider := HSlider.new()
		slider.min_value=0;slider.max_value=100;slider.step=1
		slider.value=menu.settings[channel]
		slider.custom_minimum_size.y=28
		row.add_child(slider)
		slider.value_changed.connect(func(value):
			menu.choose(channel,int(value))
			title.text=menu.TITLES[channel]+": %d%%"%menu.settings[channel]
			_show_settings_error())
	settings_error=_label("",16)
	settings_error.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(settings_error)
	var back := Button.new()
	back.text="MAIN MENU"
	back.custom_minimum_size.y=44
	stack.add_child(back)
	back.pressed.connect(close_settings)
	_resize_settings()
	_show_settings_error()
	back.grab_focus()

func _settings_group(title: String) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	group.add_theme_constant_override("separation",16)
	settings_columns.add_child(group)
	group.add_child(_label(title,24))
	return group

func _choice(parent: Control, title: String, values: Array, names: Array, current: Variant, action: Callable) -> void:
	parent.add_child(_label(title))
	var choice := OptionButton.new()
	choice.custom_minimum_size.y=40
	for name in names:choice.add_item(str(name))
	choice.select(values.find(current))
	parent.add_child(choice)
	choice.item_selected.connect(func(index):action.call(values[index]);_show_settings_error())

func _show_settings_error() -> void:
	if is_instance_valid(settings_error):settings_error.text="\n".join([menu.quality_error,menu.save_error]).strip_edges()

func _resize_settings() -> void:
	if is_instance_valid(settings_columns):settings_columns.columns=2 if size.x>=900 else 1

func close_settings() -> void:
	if is_instance_valid(settings_page):settings_page.queue_free()
	settings_page=null;settings_columns=null;settings_error=null
	main.ui.show();main.set_screen("menu")

func open_artwork() -> void:
	main.ui.hide();main.hide();main.process_mode=Node.PROCESS_MODE_DISABLED
	main.sound.stop_all()
	artwork=load("res://scenes/art_review.tscn").instantiate()
	artwork.embedded=true
	stage.add_child(artwork)
	artwork.return_requested.connect(func():
		artwork.queue_free();artwork=null
		main.show();main.process_mode=Node.PROCESS_MODE_INHERIT
		main.ui.show();main.set_screen("extras"))

func show_route(message: String, failed := false) -> void:
	busy=true;main.ui.hide()
	if not is_instance_valid(route_panel):
		var margin := _panel()
		route_panel=margin.get_parent()
		var stack := VBoxContainer.new()
		stack.alignment=BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation",24)
		margin.add_child(stack)
		route_message=_label("",24)
		route_message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(route_message)
		original_button=Button.new();original_button.text="CONTINUE ORIGINAL GAME"
		original_button.custom_minimum_size.y=48
		stack.add_child(original_button)
		original_button.pressed.connect(func():original_selected.emit())
		var quit := Button.new();quit.text="QUIT"
		quit.custom_minimum_size.y=48
		stack.add_child(quit)
		quit.pressed.connect(func():quit_selected.emit())
	route_message.text=message
	original_button.visible=failed
	if failed:original_button.grab_focus()

func clear_route() -> void:
	busy=false
	if is_instance_valid(route_panel):route_panel.queue_free()
	route_panel=null
	main.ui.show();main.set_screen("menu")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE and is_instance_valid(settings_page):
		close_settings();get_viewport().set_input_as_handled()

func drain_for_shutdown() -> bool:
	return await main.sound.drain_for_shutdown()
