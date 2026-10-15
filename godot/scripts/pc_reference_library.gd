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
var _textures := {} # Decoded illustrations for the current section, keyed by path.
var section := "Controls"
var search: LineEdit
var body: VBoxContainer
var tabs: Container
var tactical := false
var column: VBoxContainer
var byline: Label
var scroll: ScrollContainer
var _restore_on_resize := false
var result_count: Label
var heading: BoxContainer
var _narrow := false

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
	column=VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	panel.add_child(column)
	heading=HBoxContainer.new()
	column.add_child(heading)
	var title_label := _label(heading,"Player reference",28)
	title_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var back := Button.new()
	back.text="Back to Abrams"
	back.pressed.connect(close_reader)
	heading.add_child(back)
	byline=_label(column,"Original game by Dynamix · Published by Electronic Arts",16)
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
	search.text_changed.connect(func(_text):
		_render()
		if tactical:scroll.scroll_vertical=0)
	column.add_child(search)
	result_count=_label(column,"",15)
	result_count.hide()
	scroll=ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	body=VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",16)
	scroll.add_child(body)
	var host := get_parent() as Window
	if host!=null:host.size_changed.connect(_fit_to_host)

func set_hud_style(style: String) -> void:
	var next := style=="tactical"
	if next==tactical:return
	tactical=next
	_restore_on_resize=not tactical and visible
	theme=InterfaceTheme.reference_theme(tactical)
	min_size=Vector2i(0,0) if tactical else Vector2i(640,480)
	column.add_theme_constant_override("separation",12 if tactical else 16)
	_replace_tabs()
	result_count.visible=tactical
	search.clear_button_enabled=tactical
	if tactical:byline.add_theme_color_override("font_color",Color("a7b09a"))
	else:byline.remove_theme_color_override("font_color")
	_update_narrow_layout()
	if visible:
		var previous_scroll := scroll.scroll_vertical
		_render()
		scroll.set_deferred("scroll_vertical",previous_scroll)
		if tactical:_fit_tactical()
		else:
			_fit_restored()
			var host := get_parent() as Window
			if host!=null:position=(host.size-size)/2

func _replace_tabs() -> void:
	var replacement: Container = HFlowContainer.new() if tactical else HBoxContainer.new()
	if tactical:
		replacement.add_theme_constant_override("h_separation",6)
		replacement.add_theme_constant_override("v_separation",6)
	var index := tabs.get_index()
	for button in tabs.get_children():
		tabs.remove_child(button)
		replacement.add_child(button)
	column.remove_child(tabs)
	tabs.queue_free()
	tabs=replacement
	column.add_child(tabs)
	column.move_child(tabs,index)

func _update_narrow_layout() -> bool:
	var next := tactical and size.x<480
	if next==_narrow:return false
	_narrow=next
	# HBox/VBox orientations are fixed. Replace the container at the width
	# bucket boundary, keeping its actual children and original row on return.
	var replacement: BoxContainer = VBoxContainer.new() if _narrow else HBoxContainer.new()
	var index := heading.get_index()
	for child in heading.get_children():
		heading.remove_child(child)
		replacement.add_child(child)
	column.remove_child(heading)
	heading.queue_free()
	heading=replacement
	column.add_child(heading)
	column.move_child(heading,index)
	return true

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		# Consume dismissal before the original-input bridge observes the key.
		get_viewport().set_input_as_handled()
		close_reader()

func _fit_to_host() -> void:
	if tactical:_fit_tactical()
	elif _restore_on_resize and visible:
		# Web changes its canvas aspect after the HUD selection is delivered.
		# Follow that transition only until this reader is closed or reopened.
		_fit_restored()
		position=((get_parent() as Window).size-size)/2

func _fit_tactical() -> void:
	if not tactical or not visible:return
	var host := get_parent() as Window
	if host==null:return
	# Reserve the embedded title bar as well as a clear margin on short canvases.
	var available := host.size-Vector2i(32,64)
	size=Vector2i(mini(960,maxi(320,available.x)),mini(720,maxi(240,available.y)))
	column.add_theme_constant_override("separation",8 if size.y<360 else 12)
	position=(host.size-size)/2
	if _update_narrow_layout():
		var previous_scroll := scroll.scroll_vertical
		_render()
		scroll.set_deferred("scroll_vertical",previous_scroll)

func _fit_restored() -> void:
	var host := get_parent() as Window
	var available := host.size-Vector2i(48,48) if host!=null else Vector2i(960,720)
	size=Vector2i(mini(960,maxi(640,available.x)),mini(720,maxi(480,available.y)))

func _read_json(name: String) -> Dictionary:
	if name not in ["manual-content.json","visuals.json","credits.json"]: return {}
	var path := directory.path_join(name)
	if not FileAccess.file_exists(path): return {}
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func open_reader(tab: String="Controls") -> void:
	_restore_on_resize=false
	directory=("/" if OS.has_feature("web") else ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()).path_join("docs/player-reference")
	content=_read_json("manual-content.json")
	visuals=_read_json("visuals.json")
	credits=_read_json("credits.json")
	show_section(tab)
	if not tactical:_fit_restored()
	popup_centered()
	if tactical:_fit_tactical()
	reader_changed.emit(true)
	search.grab_focus()

func close_reader() -> void:
	_restore_on_resize=false
	hide()
	# Remove textures when the reader closes. The game keeps its own budget.
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	content.clear(); visuals.clear(); credits.clear(); _textures.clear()
	reader_changed.emit(false)

func show_section(tab: String) -> void:
	if tab!=section: _textures.clear() # Hold one section's illustrations at a time.
	section=tab if tab in SECTIONS else "Controls"
	if search==null:return
	search.text=""
	for button in tabs.get_children(): button.button_pressed=button.text==section
	_render()
	if tactical:
		scroll.scroll_vertical=0
		search.grab_focus()

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
	heading.add_theme_color_override("font_color",Color("e7b566") if tactical else InterfaceTheme.ACCENT)

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

func _displayed_text(entry: Dictionary, heading_text: String, keys: bool) -> String:
	# Mirror only the fields, labels and captions rendered by _entries.
	var words: PackedStringArray=[heading_text]
	words.append(str(entry.get("name","" if keys else heading_text)))
	if entry.has("description"):words.append(str(entry.description))
	if keys:
		if entry.has("stations") and heading_text!="Remaster shortcuts":words.append("Stations: "+_plain(entry.stations))
	else:
		for field in ["allegiance","role"]:
			if entry.has(field):words.append(str(entry[field]).capitalize())
		for field in FIELD_LABELS:
			if entry.has(field) and entry[field]!=null:words.append(FIELD_LABELS[field]+" "+_plain(entry[field]))
		if entry.has("key") and entry.key!=null:words.append("Station key "+_plain(entry.key))
		var specs = entry.get("specs",{})
		if specs is Dictionary:
			for field in SPEC_LABELS:
				if specs.has(field):words.append(SPEC_LABELS[field]+" "+_plain(specs[field]))
	for group in ["manual_maps","maps","wireframes","models"]:
		for visual in visuals.get(group,[]):
			if visual is Dictionary and str(visual.get("name",""))==str(entry.get("name","")):
				var path := visual_path(str(visual.get("native_file",visual.get("file",""))))
				# Initial unfiltered render decodes this section only. A caption is
				# searchable after its illustration actually rendered successfully.
				if _textures.has(path):words.append(str(visual.get("caption","")))
	var pages: PackedStringArray=[]
	for page in entry.get("page_refs",[]):
		if page is Dictionary:pages.append(_plain(page.get("printed_page","")))
	if not pages.is_empty():words.append("Manual pages: "+", ".join(pages))
	return " ".join(words)

func _matches_text(words: String) -> bool:
	var haystack := words.to_lower()
	var query := search.text.strip_edges().to_lower().replace("\t"," ").replace("\n"," ").replace("\r"," ")
	for token in query.split(" ",false):
		if not haystack.contains(token):return false
	return true

func _matches(entry: Dictionary, heading_text: String="", keys: bool=false) -> bool:
	if tactical:
		if search.text.strip_edges().is_empty():return true
		return _matches_text(_displayed_text(entry,heading_text,keys))
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
		if not entry is Dictionary or not _matches(entry,heading,keys):continue
		if found==0:_heading(heading)
		found+=1
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation",8)
		body.add_child(stack)
		if keys:
			var row: BoxContainer = VBoxContainer.new() if _narrow else HBoxContainer.new()
			row.add_theme_constant_override("separation",24)
			stack.add_child(row)
			var key := RichTextLabel.new()
			key.bbcode_enabled=true
			key.fit_content=true
			key.custom_minimum_size=Vector2(190,0)
			key.add_theme_font_size_override("normal_font_size",24)
			key.add_theme_font_size_override("bold_font_size",24)
			if heading_font!=null:key.add_theme_font_override("bold_font",heading_font)
			if tactical:
				key.add_theme_color_override("default_color",Color("e7b566"))
				key.add_theme_font_size_override("normal_font_size",20)
				key.add_theme_font_size_override("bold_font_size",20)
				key.custom_minimum_size.x=170
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
	var row: BoxContainer = VBoxContainer.new() if _narrow else HBoxContainer.new()
	row.add_theme_constant_override("separation",20)
	parent.add_child(row)
	var label := _label(row,caption,17)
	label.custom_minimum_size=Vector2(170,0)
	label.add_theme_color_override("font_color",Color("a7b09a") if tactical else InterfaceTheme.MUTED)
	var words := _label(row,_plain(value),17)
	words.size_flags_horizontal=Control.SIZE_EXPAND_FILL

func visual_path(file: String) -> String:
	# Only manifest-listed local basenames can reach the image decoder.
	if file.is_empty() or file!=file.get_file() or file.contains("..") or file.contains(":") or file.contains("\\"):return ""
	if file.get_extension().to_lower() not in ["png","svg"]:return ""
	var folder := DirAccess.open(directory)
	if folder==null or folder.is_link(file):return ""
	for group in ["manual_maps","maps","wireframes","models"]:
		for entry in visuals.get(group,[]):
			if entry is Dictionary and file in [entry.get("file"),entry.get("native_file")]:
				var path := directory.path_join(file)
				return path if FileAccess.file_exists(path) else ""
	return ""

func _visuals(parent: Node, entry_name: String) -> void:
	for group in ["manual_maps","maps","wireframes","models"]:
		for entry in visuals.get(group,[]):
			if not entry is Dictionary or str(entry.get("name",""))!=entry_name:continue
			var file = entry.get("native_file",entry.get("file"))
			var path := visual_path(str(file)) if file!=null else ""
			if not path.is_empty():
				var texture: Texture2D = _textures.get(path)
				if texture==null:
					var image := Image.load_from_file(path)
					if image!=null and not image.is_empty():
						texture=ImageTexture.create_from_image(image)
						_textures[path]=texture
				if texture!=null:
					var picture := TextureRect.new()
					picture.texture=texture
					picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
					picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					picture.custom_minimum_size=Vector2(0,420 if group in ["manual_maps","maps"] else 240)
					parent.add_child(picture)
					var caption := str(entry.get("caption",""))
					if not caption.is_empty():_label(parent,caption,15)

func _section_has_entries() -> bool:
	var section_keys := {
		"Controls":["remaster_controls","keyboard_controls","stations","joystick"],
		"Scenarios":["missions","campaign","training"],
		"Vehicles":["vehicles","other_units_and_objectives"],
		"Weapons":["ammunition_and_armament","anti_tank_guided_weapons"]}
	for key in section_keys.get(section,[]):
		var entries = content.get(key,[])
		if entries is Dictionary:return true
		if entries is Array:
			for entry in entries:
				if entry is Dictionary:return true
	return false

func _render() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	if (section!="Credits" and (content.is_empty() or (tactical and not _section_has_entries()))) or (tactical and section=="Credits" and credits.is_empty()):
		result_count.text="Guide data unavailable"
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
			var provenance := "Original game by "+str(credits.get("studio","Dynamix"))+"\nPublished by "+str(credits.get("publisher","Electronic Arts"))
			var copyright_text := str(credits.get("copyright","Original game copyright 1988, 1989 Dynamix, Inc."))
			if not tactical or _matches_text(provenance+" "+copyright_text):
				_heading(provenance.get_slice("\n",0))
				_label(body,provenance.get_slice("\n",1))
				if tactical:
					_label(body,copyright_text,15)
					count+=1
			for row in credits.get("rows",[]):
				if row is Dictionary and (_matches_text(str(row.get("role",""))+" "+_plain(row.get("names",[]))) if tactical else _matches(row)):
					count+=1
					_label(body,str(row.get("role","")),21)
					_label(body,_plain(row.get("names",[])))
			if not tactical:_label(body,copyright_text,15)
			if (_matches_text("Fan remaster Fan Remastered by Nell Watson Dedicated to David “Ming” Kenny") if tactical else _matches({"name":"Fan Remastered by Nell Watson Dedicated to David Ming Kenny"})):
				_heading("Fan remaster")
				_label(body,"Fan Remastered by Nell Watson\nDedicated to David “Ming” Kenny")
				count+=1
	if tactical:result_count.text="%d matching %s"%[count,"entry" if count==1 else "entries"]
	if count==0:_label(body,"No matching entries. Clear the search or choose another section.")
