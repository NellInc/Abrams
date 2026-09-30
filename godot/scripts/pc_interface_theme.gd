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

static func reference_path(name: String) -> String:
	if name not in ["keyboard-controls.html","field-guide.html"]: return ""
	return ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("docs/player-reference").path_join(name)

static func show_reference(host: Window, name: String) -> Window:
	var reader := host.get_node_or_null("PlayerReference") as Window
	if reader==null:
		reader=load("res://scripts/pc_reference_library.gd").new()
		reader.name="PlayerReference"
		host.add_child(reader)
	reader.call("open_reader","Controls" if name=="keyboard-controls.html" else "Credits" if name=="credits" else "Scenarios")
	return reader
