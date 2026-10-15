extends RefCounted
## Presentation-only glass surfaces. No blur passes or per-frame processing.
const INK := Color("111a21")
const TEXT := Color("f4ead4")
const MUTED := Color("c0c6c6")
const ACCENT := Color("df8b66")

static func surface(opacity: float = 0.94) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=Color(INK,opacity)
	style.set_corner_radius_all(12)
	style.set_border_width_all(1)
	style.border_color=Color(0.9,0.92,0.94,0.22)
	style.content_margin_left=18; style.content_margin_right=18
	style.content_margin_top=14; style.content_margin_bottom=14
	style.shadow_color=Color(0,0,0,0.28)
	style.shadow_size=8; style.shadow_offset=Vector2(0,4)
	return style

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size=16
	for type in ["Label","Button","LinkButton","PopupMenu","LineEdit"]:
		theme.set_color("font_color",type,TEXT)
		theme.set_color("font_hover_color",type,TEXT)
		theme.set_color("font_focus_color",type,TEXT)
	theme.set_color("font_disabled_color","Button",Color("8e979b"))
	theme.set_color("font_disabled_color","PopupMenu",Color("8e979b"))
	theme.set_color("font_color","LinkButton",ACCENT)
	theme.set_stylebox("panel","PopupMenu",surface())
	theme.set_stylebox("panel","AcceptDialog",surface())
	theme.set_stylebox("panel","PanelContainer",surface(0.87))
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style := surface()
		style.set_corner_radius_all(8)
		style.content_margin_top=9; style.content_margin_bottom=9
		style.shadow_size=0
		if state=="hover":style.bg_color=Color("30404b")
		if state=="pressed":style.bg_color=Color("172229")
		if state=="disabled":style.bg_color=Color("19232b")
		if state=="focus":
			style.bg_color=Color.TRANSPARENT
			style.border_color=ACCENT
			style.set_border_width_all(2)
		theme.set_stylebox(state,"Button",style)
	return theme

static func reference_theme(tactical: bool) -> Theme:
	var result := build()
	if not tactical:return result
	var cream := Color("e3e4cd")
	var amber := Color("e7b566")
	var muted := Color("a7b09a")
	var heading := preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
	for type in ["Label","Button","LineEdit"]:
		result.set_color("font_color",type,cream)
	result.set_color("default_color","RichTextLabel",cream)
	for type in ["Button","LineEdit"]:
		result.set_font_size("font_size",type,18)
		result.set_color("font_selected_color",type,cream)
	result.set_font("font","Button",heading)
	result.set_font_size("font_size","Button",20)
	for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color=Color("253827") if state in ["hover","pressed","hover_pressed"] else Color("101e16")
		box.border_color=amber if state in ["pressed","hover_pressed","focus"] else Color("526b58")
		box.set_border_width_all(1);box.set_corner_radius_all(4)
		box.content_margin_left=14;box.content_margin_right=14
		box.content_margin_top=8;box.content_margin_bottom=8
		if state=="focus":
			box.bg_color=Color.TRANSPARENT
			box.set_border_width_all(2)
		result.set_stylebox(state,"Button",box)
		if state in ["normal","focus"]:result.set_stylebox(state,"LineEdit",box.duplicate())
	for state in ["hover","pressed","hover_pressed","focus"]:
		result.set_color("font_"+state+"_color","Button",amber)
	result.set_color("font_disabled_color","Button",muted)
	result.set_color("font_placeholder_color","LineEdit",muted)
	result.set_color("caret_color","LineEdit",amber)
	result.set_color("selection_color","LineEdit",Color("3c5237"))
	result.set_color("clear_button_color","LineEdit",muted)
	result.set_color("clear_button_color_pressed","LineEdit",amber)
	var panel := surface(1.0)
	panel.bg_color=Color("101e16");panel.border_color=Color("526b58")
	panel.shadow_size=0;panel.set_corner_radius_all(6)
	result.set_stylebox("panel","PanelContainer",panel)
	var border := ThemeDB.get_default_theme().get_stylebox("embedded_border","Window").duplicate() as StyleBoxFlat
	if border!=null:
		border.bg_color=Color("101e16");border.border_color=Color("253827")
		result.set_stylebox("embedded_border","Window",border)
	result.set_color("title_color","Window",cream)
	result.set_font("title_font","Window",heading)
	var rule := StyleBoxLine.new()
	rule.color=Color("344733");rule.thickness=1
	rule.content_margin_top=6;rule.content_margin_bottom=6
	result.set_stylebox("separator","HSeparator",rule)
	for state in ["scroll","grabber","grabber_highlight","grabber_pressed"]:
		var bar := StyleBoxFlat.new()
		bar.bg_color=Color("e7b566") if state=="grabber_pressed" else Color("728466") if state.begins_with("grabber") else Color("0c1812")
		bar.set_corner_radius_all(3)
		bar.content_margin_left=6;bar.content_margin_right=6
		bar.content_margin_top=8;bar.content_margin_bottom=8
		result.set_stylebox(state,"VScrollBar",bar)
	return result

static func show_reference(host: Window, name: String, hud_style: String="restored") -> Window:
	var reader := host.get_node_or_null("PlayerReference") as Window
	if reader==null:
		reader=load("res://scripts/pc_reference_library.gd").new()
		reader.name="PlayerReference"
		host.add_child(reader)
	reader.call("set_hud_style",hud_style)
	reader.call("open_reader","Controls" if name=="keyboard-controls.html" else "Credits" if name=="credits" else "Scenarios")
	return reader
