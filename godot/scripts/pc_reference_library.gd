extends Window
## Offline native reader. No guest keys, clocks, audio, network, or eager textures.
signal reader_changed(open: bool)
const InterfaceTheme = preload("res://scripts/pc_interface_theme.gd")
const SPEC_LABELS := {"introduced_year":"Introduced","combat_weight_tons":"Weight (t)","length_m":"Length (m)","width_m":"Width (m)","height_m":"Height (m)","maximum_speed_kmh":"Maximum speed (km/h)","primary_armament":"Primary weapon","secondary_armament":"Secondary weapon","reload_seconds":"Reload (s)","range_m":"Range (m)","armor":"Armour","overall_threat":"Threat"}
const FIELD_LABELS := {"primary_objective":"Objective","secondary_objective":"Secondary objective","restriction":"Restriction","hazards":"Hazards","range_m":"Range (m)","scenario_score":"Scenario score","campaign_rating":"Campaign rating","rank_range":"Rank"}
var heading_font: Font
const SECTIONS := ["Controls","Scenarios","Vehicles","Weapons","Credits"]
var directory := ""
var content: Dictionary = {}
var visuals: Dictionary = {}
var credits: Dictionary = {}
var section := "Controls"
var search: LineEdit
var body: VBoxContainer
var tabs: HBoxContainer

func _ready() -> void:
	name="PlayerReference"
	title="Abrams · Player reference"
	transient=true
	exclusive=false
	min_size=Vector2i(640,480)
	size=Vector2i(960,720)
	theme=InterfaceTheme.build()
	var font_path := "res://assets/fonts/BarlowCondensed-SemiBold.ttf"
	if ResourceLoader.exists(font_path):heading_font=load(font_path)
	close_requested.connect(close_reader)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	panel.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title_label := _label(heading,"Player reference",28)
	title_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var back := Button.new()
	back.text="Back to Abrams"
	back.pressed.connect(close_reader)
	heading.add_child(back)
	_label(column,"Original game by Dynamix · Published by Electronic Arts",16)
	tabs=HBoxContainer.new()
	column.add_child(tabs)
	for tab in SECTIONS:
		var button := Button.new()
		button.text=tab
		button.toggle_mode=true
		button.pressed.connect(func(): show_section(tab))
		tabs.add_child(button)
	search=LineEdit.new()
	search.placeholder_text="Search this section"
	search.text_changed.connect(func(_text): _render())
	column.add_child(search)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	body=VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",16)
	scroll.add_child(body)

func _read_json(name: String) -> Dictionary:
	if name not in ["manual-content.json","visuals.json","credits.json"]: return {}
	var path := directory.path_join(name)
	if not FileAccess.file_exists(path): return {}
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func open_reader(tab: String="Controls") -> void:
	directory=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("docs/player-reference")
	content=_read_json("manual-content.json")
	visuals=_read_json("visuals.json")
	credits=_read_json("credits.json")
	show_section(tab)
	var host := get_parent() as Window
	var available := host.size-Vector2i(48,48) if host!=null else Vector2i(960,720)
	size=Vector2i(mini(960,maxi(640,available.x)),mini(720,maxi(480,available.y)))
	popup_centered()
	reader_changed.emit(true)
	search.grab_focus()

func close_reader() -> void:
	hide()
	# Remove textures when the reader closes. The game keeps its own budget.
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	content.clear(); visuals.clear(); credits.clear()
	reader_changed.emit(false)

func show_section(tab: String) -> void:
	section=tab if tab in SECTIONS else "Controls"
	if search==null:return
	search.text=""
	for button in tabs.get_children(): button.button_pressed=button.text==section
	_render()

func _label(parent: Node, text: String, font_size: int=17) -> Label:
	var label := Label.new()
	label.text=text
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size)
	if font_size>=21 and heading_font!=null:label.add_theme_font_override("font",heading_font)
	parent.add_child(label)
	return label

func _heading(text: String) -> void:
	var heading := _label(body,text,23)
	heading.add_theme_color_override("font_color",InterfaceTheme.ACCENT)

func _plain(value) -> String:
	if value==null:return "Not specified in the manual"
	if value is float and value==floor(value):return str(int(value))
	if value is Array:
		var parts: PackedStringArray=[]
		for item in value: parts.append(_plain(item))
		return "; ".join(parts)
	if value is Dictionary:
		var parts: PackedStringArray=[]
		for key in value:parts.append(_plain(value[key]))
		return " ".join(parts)
	return str(value)

func _matches(entry: Dictionary) -> bool:
	var query := search.text.strip_edges().to_lower()
	if query.is_empty():return true
	for field in ["name","names","description","allegiance","role","stations","specs","key"]+FIELD_LABELS.keys():
		if entry.has(field) and _plain(entry[field]).to_lower().contains(query):return true
	return false

func _entries(section_key: String, heading: String, keys: bool=false) -> int:
	var found := 0
	var entries = content.get(section_key,[])
	if entries is Dictionary:entries=[entries]
	if not entries is Array:return 0
	for entry in entries:
		if not entry is Dictionary or not _matches(entry):continue
		if found==0:_heading(heading)
		found+=1
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation",8)
		body.add_child(stack)
		if keys:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation",24)
			stack.add_child(row)
			var key := RichTextLabel.new()
			key.bbcode_enabled=true
			key.fit_content=true
			key.custom_minimum_size=Vector2(190,0)
			key.add_theme_font_size_override("normal_font_size",24)
			key.add_theme_font_size_override("bold_font_size",24)
			if heading_font!=null:key.add_theme_font_override("bold_font",heading_font)
			key.text="[b]"+str(entry.get("name","")).replace("[","[lb]")+"[/b]"
			row.add_child(key)
			var description := _label(row,str(entry.get("description","")))
			description.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			if entry.has("stations") and section_key!="remaster_controls":_label(stack,"Stations: "+_plain(entry.stations),15)
		else:
			_label(stack,str(entry.get("name",heading)),21)
			if entry.has("description"):_label(stack,str(entry.description))
			var identity: PackedStringArray=[]
			for field in ["allegiance","role"]:
				if entry.has(field):identity.append(str(entry[field]).capitalize())
			if not identity.is_empty():_label(stack," · ".join(identity),15)
			if section=="Vehicles":_visuals(stack,str(entry.get("name","")))
			for field in FIELD_LABELS:
				if entry.has(field) and entry[field]!=null:_spec_row(stack,FIELD_LABELS[field],entry[field])
			if entry.has("key") and entry.key!=null:_spec_row(stack,"Station key",entry.key)
			var specs = entry.get("specs",{})
			if specs is Dictionary:
				for field in SPEC_LABELS:
					if specs.has(field):_spec_row(stack,SPEC_LABELS[field],specs[field])
		if section!="Vehicles":_visuals(stack,str(entry.get("name","")))
		var pages: PackedStringArray=[]
		for page in entry.get("page_refs",[]):
			if page is Dictionary: pages.append(_plain(page.get("printed_page","")))
		if not pages.is_empty():_label(stack,"Manual pages: "+", ".join(pages),14)
		stack.add_child(HSeparator.new())
	return found

func _spec_row(parent: Node, caption: String, value) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",20)
	parent.add_child(row)
	var label := _label(row,caption,17)
	label.custom_minimum_size=Vector2(170,0)
	label.add_theme_color_override("font_color",InterfaceTheme.MUTED)
	var words := _label(row,_plain(value),17)
	words.size_flags_horizontal=Control.SIZE_EXPAND_FILL

func visual_path(file: String) -> String:
	# Only manifest-listed local basenames can reach the image decoder.
	if file.is_empty() or file!=file.get_file() or file.contains("..") or file.contains(":") or file.contains("\\"):return ""
	if file.get_extension().to_lower() not in ["png","svg"]:return ""
	var folder := DirAccess.open(directory)
	if folder==null or folder.is_link(file):return ""
	for group in ["maps","wireframes","models"]:
		for entry in visuals.get(group,[]):
			if entry is Dictionary and file in [entry.get("file"),entry.get("native_file")]:
				var path := directory.path_join(file)
				return path if FileAccess.file_exists(path) else ""
	return ""

func _visuals(parent: Node, entry_name: String) -> void:
	for group in ["maps","wireframes","models"]:
		for entry in visuals.get(group,[]):
			if not entry is Dictionary or str(entry.get("name",""))!=entry_name:continue
			var file = entry.get("native_file",entry.get("file"))
			var path := visual_path(str(file)) if file!=null else ""
			if not path.is_empty():
				var image := Image.load_from_file(path)
				if image!=null and not image.is_empty():
					var picture := TextureRect.new()
					picture.texture=ImageTexture.create_from_image(image)
					picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
					picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					picture.custom_minimum_size=Vector2(0,420 if group=="maps" else 240)
					parent.add_child(picture)
			_label(parent,str(entry.get("caption","")),15)

func _render() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	if content.is_empty() and section!="Credits":
		_label(body,"The offline guide is missing or unreadable. Reinstall the complete application.")
		return
	var count := 0
	match section:
		"Controls":
			count+=_entries("remaster_controls","Remaster shortcuts",true)
			count+=_entries("keyboard_controls","Keyboard controls",true)
			count+=_entries("stations","Crew stations")
			count+=_entries("joystick","Joystick")
		"Scenarios":
			count+=_entries("missions","Scenarios")
			count+=_entries("campaign","Campaign")
			count+=_entries("training","Training")
		"Vehicles":
			count+=_entries("vehicles","Vehicles")
			count+=_entries("other_units_and_objectives","Other units and objectives")
		"Weapons":
			count+=_entries("ammunition_and_armament","Ammunition and armament")
			count+=_entries("anti_tank_guided_weapons","Guided weapons")
		"Credits":
			_heading("Original game by "+str(credits.get("studio","Dynamix")))
			_label(body,"Published by "+str(credits.get("publisher","Electronic Arts")))
			for row in credits.get("rows",[]):
				if row is Dictionary and _matches(row):
					count+=1
					_label(body,str(row.get("role","")),21)
					_label(body,_plain(row.get("names",[])))
			_label(body,str(credits.get("copyright","Original game copyright 1988, 1989 Dynamix, Inc.")),15)
			if _matches({"name":"Remastered by Nell Watson Dedicated to David Ming Kenny"}):
				_heading("Fan remaster")
				_label(body,"Remastered by Nell Watson\nDedicated to David “Ming” Kenny")
				count+=1
	if count==0:_label(body,"No matching entries. Clear the search or choose another section.")
