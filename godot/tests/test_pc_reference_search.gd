extends SceneTree
## UI-only reference regression fixture. No original game or runtime worker.
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	root.gui_embed_subwindows=true
	create_timer(30).timeout.connect(func(): printerr("FAIL: reference fixture deadline"); quit(1))
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks+=1
	if not ok:failures.append(description)

func _run() -> void:
	var reader := preload("res://scripts/pc_reference_library.gd").new()
	root.size=Vector2i(1024,800)
	root.add_child(reader)
	await process_frame
	var baseline_theme := reader.theme
	var baseline_spacing := reader.tabs.get_theme_constant("separation")
	reader.set_hud_style("tactical")
	reader.show()
	reader.section="Vehicles"
	reader.content={"vehicles":[{"name":"M1 Abrams","description":"Main battle tank","specs":{"primary_armament":"120 mm gun","hidden_stat":"secret"},"page_refs":[{"printed_page":12}]}]}
	reader.visuals={}
	reader.search.text="abrams primary weapon gun"
	reader._render()
	check(reader.result_count.text=="1 matching entry","all query words span visible name, label and specification")
	reader.search.text="manual pages 12"
	reader._render()
	check(reader.result_count.text=="1 matching entry","displayed manual page labels are searchable")
	reader.search.text="secret"
	reader._render()
	check(reader.result_count.text=="0 matching entries" and _has_text(reader.body,"No matching entries"),"unrendered specifications stay unsearchable")
	reader.search.text="abrams absent"
	reader._render()
	check(reader.result_count.text=="0 matching entries","every query token is required")
	reader.content={"vehicles":[]}
	reader._render()
	check(reader.result_count.text=="Guide data unavailable" and _has_text(reader.body,"missing or unreadable") and not _has_text(reader.body,"No matching entries"),"missing section differs from zero search matches")
	reader.section="Credits"
	reader.credits={"studio":"Dynamix","rows":[{"role":"Programming","names":["Example Person"]}]}
	reader.search.text="programming person"
	reader._render()
	check(reader.result_count.text=="1 matching entry","credit roles and displayed names search together")
	reader.search.text="original dynamix"
	reader._render()
	check(reader.result_count.text=="1 matching entry","visible provenance participates in result count")
	reader.credits={}
	reader._render()
	check(reader.result_count.text=="Guide data unavailable","missing credits have honest recovery")
	reader.content={"keyboard_controls":[{"name":"Ctrl + Shift + Long shortcut","description":"Switch the station and open the player reference."}],"vehicles":[{"name":"M1 Abrams","specs":{"primary_armament":"120 mm gun"}}]}
	for width in [320,480,640]:
		root.size=Vector2i(width+32,800)
		reader.show_section("Controls")
		reader._fit_tactical()
		await process_frame
		await process_frame
		check(reader.tabs is HFlowContainer,"Tactical tabs use native wrapping at %d"%width)
		check(reader.size.x<=width,"Tactical window fits %d"%width)
		check(reader.body.size.x<=reader.scroll.size.x+1,"Tactical controls fit %d"%width)
		for button in reader.tabs.get_children():
			check(button.position.x>=0 and button.position.x+button.size.x<=reader.tabs.size.x+1,"tab fits %d: %s"%[width,button.text])
		check(reader.heading.vertical==(width<480),"compact header only in narrow bucket")
	reader.scroll.scroll_vertical=50
	reader.search.text="long"
	reader.search.text_changed.emit("long")
	check(reader.scroll.scroll_vertical==0,"Tactical query resets scroll")
	reader.show_section("Vehicles")
	check(reader.search.text.is_empty() and reader.search.has_focus() and reader.scroll.scroll_vertical==0,"section clears query, focuses search and resets scroll")
	reader.set_hud_style("restored")
	check(reader.tabs is HBoxContainer and reader.tabs.get_theme_constant("separation")==baseline_spacing and not reader.tabs.has_theme_constant_override("separation"),"Restored tabs recover incumbent container and default spacing")
	check(not reader.heading.vertical and reader.column.get_theme_constant("separation")==16 and not reader.result_count.visible and not reader.search.clear_button_enabled,"Restored layout and affordances round-trip")
	check(reader.theme.get_color("font_color","Label")==baseline_theme.get_color("font_color","Label") and not reader.byline.has_theme_color_override("font_color"),"Restored theme and byline return exactly")
	reader.search.text="abrams gun"
	check(not reader._matches(reader.content.vehicles[0]),"Restored legacy whole-query matching remains unchanged")
	var transitions: Array[bool]=[]
	reader.reader_changed.connect(func(open: bool): transitions.append(open))
	var escape := InputEventKey.new()
	escape.keycode=KEY_ESCAPE
	escape.pressed=true
	reader._input(escape)
	check(not reader.visible and transitions==[false],"Escape closes and emits existing quarantine signal once")
	check(reader.is_input_handled(),"Escape is handled by the reader viewport")
	check(reader.body.get_child_count()==0 and reader._textures.is_empty() and reader.content.is_empty(),"Escape releases content and lazy textures")
	reader._input(escape)
	check(transitions==[false],"hidden reader does not handle or emit another dismissal")
	reader.queue_free()
	for error in failures:printerr("FAIL: "+error)
	print("PC_REFERENCE_SEARCH: %d checks, %d errors"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _has_text(node: Node, words: String) -> bool:
	if node is Label and node.text.contains(words):return true
	for child in node.get_children():
		if _has_text(child,words):return true
	return false
