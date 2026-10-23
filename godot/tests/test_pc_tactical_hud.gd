extends SceneTree
const Display=preload("res://scripts/pc_play_display.gd")
const Menu=preload("res://scripts/pc_play_menu.gd")
const Map=preload("res://scripts/pc_tactical_map.gd")
const Instruments=preload("res://scripts/pc_tactical_instruments.gd")
var errors: Array[String]=[]
var checks:=0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: errors.append(label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	map_surfaces()
	map_labelling()
	map_surface_cache()
	hud_ink_separation()
	gunner_corner_finish()
	uncovered_panel_pixels()
	crew_panels()
	var display:=Display.new()
	root.add_child(display)
	display.size=Vector2i(640,480)
	instrument_legibility(display.tactical_chrome.instruments)
	instrument_detail(display.tactical_chrome.instruments)
	schematic_layout(display.tactical_chrome.instruments)
	diagnostic_detail(display.tactical_chrome.instruments)
	control_legends(display.tactical_chrome)
	section_legibility(display.tactical_chrome)
	for scale in [0.35,0.49,0.56,0.85,1.2]:
		check(display.tactical_chrome.map_art._border_stroke(scale)*scale>=0.999,"compact map border retains one output pixel without changing map registration")
	var menu:=Menu.new()
	menu.config_path=""
	menu.quality_config_path=""
	root.add_child(menu)
	# The menu defaults to the Tactical HUD (Nell, 15 October 2026); an unconfigured display
	# stays Restored until the viewer applies the menu's choice.
	check(menu.hud_style=="tactical" and menu.hud_style==Menu.DEFAULT_HUD_STYLE and display.hud_style=="restored","Tactical menu default, Restored unconfigured display")
	check(not menu.choose_hud_style("unknown") and menu.hud_style=="tactical","unknown HUD style rejected")
	check(menu.choose_hud_style("tactical") and menu.hud_style=="tactical","Tactical control accepted")
	check(menu._tactical_bar.visible and menu.theme.has_stylebox("normal","MenuBar"),"Tactical menu uses matching field theme")
	menu.choose_hud_style("restored")
	check(not menu._tactical_bar.visible and not menu.theme.has_stylebox("normal","MenuBar"),"Restored menu keeps original theme")
	var settings:=OS.get_temp_dir().path_join("abrams-tactical-hud-%d.cfg"%OS.get_process_id())
	DirAccess.remove_absolute(settings)
	menu.quality_config_path=settings
	check(menu.choose_hud_style("tactical") and FileAccess.file_exists(settings),"HUD preference saved")
	var loaded:=Menu.new()
	loaded.quality_config_path=settings
	check(loaded.load_quality_settings() and loaded.hud_style=="tactical","HUD preference restored")
	DirAccess.remove_absolute(settings)
	loaded.free()
	check(display.set_hud_style("tactical"),"Tactical renderer accepted")
	check(not display.set_hud_style("unknown") and display.hud_style=="tactical","renderer keeps state on unknown style")
	var mask:=Image.create_empty(320,200,false,Image.FORMAT_L8)
	mask.fill(Color.WHITE)
	var packet: Dictionary={"ui_overlay":{"width":320,"height":200,
		"mask_png":Marshalls.raw_to_base64(mask.save_png_to_buffer())},
		"draw_pass":{"camera":{"clip":[32,13,287,109]}}}
	display.set_hud_frame(packet,{"name":"SIM"})
	check(display.display.material==display.tactical_material,"paired SIM mask enables Tactical")
	check(display.tactical_material.get_shader_parameter("camera_verified"),"camera aperture proven")
	check(not display.tactical_material.get_shader_parameter("panels_verified"),"unverified panel absent")
	display.set_hud_frame(packet,{"name":"START"})
	check(display.display.material==null,"non-SIM screen restores source")
	display.set_hud_frame(packet,{"name":"SIM"})
	check(display.display.material==display.tactical_material,"Tactical resumes on paired SIM frame")
	var wrong_size:=Image.create_empty(1,1,false,Image.FORMAT_L8)
	packet.ui_overlay.mask_png=Marshalls.raw_to_base64(wrong_size.save_png_to_buffer())
	display.set_hud_frame(packet,{"name":"SIM"})
	check(display.display.material==null,"malformed mask restores source immediately")
	packet.ui_overlay.mask_png=Marshalls.raw_to_base64(mask.save_png_to_buffer())
	var plate:=Image.create_empty(320,200,false,Image.FORMAT_L8)
	plate.fill(Color8(1,1,1))
	var plate_packet:=packet.duplicate(true)
	plate_packet.plate_overlay={"width":320,"height":200,"mask_png":Marshalls.raw_to_base64(plate.save_png_to_buffer()),
		"plates":{"1":{"source":"GPS.BIN","source_sha256":preload("res://scripts/pc_tandem_frame.gd").GUNNER_SOURCE_SHA256}}}
	display.set_hud_frame(plate_packet,{"name":"SIM"})
	check(display.description().display_aspect=="16:9" and display._wide_station==1,"PC-only Gunner expands only with source-proven plate")
	check(display.tandem_viewport.size.x*3==display.tandem_viewport.size.y*4,"wide display keeps 4:3 source composition")
	plate.set_pixel(312,199,Color.BLACK)
	plate_packet.plate_overlay.mask_png=Marshalls.raw_to_base64(plate.save_png_to_buffer())
	display.set_hud_frame(plate_packet,{"name":"SIM"})
	check(display._wide_station==1,"live source border remains visible in the reflow")
	plate.set_pixel(0,0,Color.BLACK)
	plate_packet.plate_overlay.mask_png=Marshalls.raw_to_base64(plate.save_png_to_buffer())
	display.set_hud_frame(plate_packet,{"name":"SIM"})
	check(display.description().display_aspect=="4:3" and display._wide_station==0,"unmapped live UI restores full layout")
	for station in range(2,6):
		var original:Array=preload("res://scripts/pc_tandem_frame.gd").COCKPIT_SOURCES[station]
		plate.fill(Color8(station,station,station))
		var bounds:Vector4=Display.TACTICAL_LAYOUTS[station].camera
		var frame:=packet.duplicate(true)
		frame.draw_pass.camera.clip=[bounds.x,bounds.y,bounds.z-1,bounds.w-1] if station!=5 else [0,10,319,52]
		frame.plate_overlay={"width":320,"height":200,"mask_png":Marshalls.raw_to_base64(plate.save_png_to_buffer()),
			"plates":{str(station):{"source":original[0],"source_sha256":original[1]}}}
		# Real browser packets contain floating-point JSON numbers.
		frame=JSON.parse_string(JSON.stringify(frame))
		display.set_hud_frame(frame,{"name":"SIM"})
		check(display._wide_station==station,"station %d: source-proven wide layout without optional ROM"%station)
		check(display.description().display_aspect=="16:9","station %d: matching wide canvas"%station)
		check(display.tactical_chrome.wide_station==station,"station %d: matching frame labels"%station)
		check(display.tandem_viewport.size.x*3==display.tandem_viewport.size.y*4,"station %d: original source aspect retained"%station)
		check(display.tactical_material.get_shader_parameter("layout_count")==Display.TACTICAL_LAYOUTS[station].source.size(),"station %d: shader and proof share source regions"%station)
		if station==5:
			check(not display.tactical_material.get_shader_parameter("camera_verified"),"STATUS has no stale Commander camera exclusion")
		# A live pixel beyond every copied region must disable this station's reflow.
		plate.set_pixel(0,196,Color.BLACK)
		frame.plate_overlay.mask_png=Marshalls.raw_to_base64(plate.save_png_to_buffer())
		display.set_hud_frame(frame,{"name":"SIM"})
		check(display._wide_station==0,"station %d: uncopied live overlay restores complete source"%station)
		frame.plate_overlay.plates[str(station)].source_sha256="unverified"
		display.set_hud_frame(frame,{"name":"SIM"})
		check(display._panel_mask_texture==null and display._wide_station==0,"station %d: unproven source rejected"%station)
	display.set_hud_frame(plate_packet,{"name":"START"})
	check(display._wide_station==0,"program transition clears wide layout")
	check(display.set_hud_style("restored") and display.display.material==null,"Restored removes shader")
	var args:=OS.get_cmdline_user_args()
	if "--station-fixtures" in args:
		station_instruments(display,args[args.find("--station-fixtures")+1])
		station_maps(display,args[args.find("--station-fixtures")+1])
	if "--fallback-fixtures" in args and "--fixture-root" in args:
		fallback_instruments(display,args[args.find("--fallback-fixtures")+1],args[args.find("--fixture-root")+1])
		if "--station-fixtures" not in args:
			station_maps(display,args[args.find("--fallback-fixtures")+1])
		await retained_instruments(display,args[args.find("--fallback-fixtures")+1],"--redraw-baseline" not in args)
	menu.free()
	display.free()
	print("PC_TACTICAL_HUD: %d checks, %d errors"%[checks,errors.size()])
	for error in errors: printerr(error)
	quit(0 if errors.is_empty() else 1)

func instrument_legibility(renderer: Control) -> void:
	for fallback in [false,true]:
		renderer.in_place=fallback
		for width in [198.0,266.0,320.0]:
			var box:=Rect2(70,110,width,42)
			for value in ["0","100","READY","-----"]:
				var cells: Array[Rect2]=renderer._row_layout(box,value)
				check(box.encloses(cells[0]) and box.encloses(cells[1]) and cells[0].end.x+9<=cells[1].position.x,"measured readout columns never overlap: "+value)
			var ordinary: Array[Rect2]=renderer._row_layout(box,"10")
			var long_value: Array[Rect2]=renderer._row_layout(box,"READY")
			check(long_value[1].size.x>=ordinary[1].size.x,"long verified reading receives space before font reduction")
			var selected: Array[Rect2]=renderer._row_layout(box,"10",true)
			check(selected[0].position.x>=box.position.x+18 and selected[1]==ordinary[1],"selection marker has inset space without shifting value")
	for box in [Rect2(10,20,200,70),Rect2(10,20,320,139),Rect2(10,20,305,108)]:
		for count in [2,4]:
			var layout: Dictionary=renderer._scale_layout(box,count)
			check(box.encloses(layout.rail) and layout.labels.all(func(r):return box.encloses(r)),"scale labels and rail remain inside panel")
			check(layout.ticks[0].x==layout.rail.position.x and layout.ticks[-1].x==layout.rail.end.x,"endpoint ticks register to complete rail")
	check(renderer._lamp_shape(renderer.Ink.GREEN)=="filled","verified green lamp retains fill")
	check(renderer._lamp_shape(renderer.Ink.RED)=="cross","verified red lamp repeats colour as cross")
	check(renderer._lamp_shape(renderer.Ink.RED,true)=="target","active original red lock uses target brackets instead of fault cross")
	check(renderer._lamp_shape(renderer.Ink.YELLOW)=="dash","verified yellow lamp repeats colour as dash")
	check(renderer._lamp_shape(renderer.Ink.INACTIVE)=="outline","inactive lamp is visibly outlined")
	check(renderer._lamp_shape(Color.BLACK,true)=="outline","unlocked original black lock remains outlined")
	renderer.in_place=false

func instrument_detail(renderer: Control) -> void:
	var original_size: Vector2=renderer.size
	var original_canvas: Vector2=renderer.canvas_size
	var original_in_place: bool=renderer.in_place
	for fallback in [false,true]:
		renderer.in_place=fallback
		renderer.canvas_size=Vector2(1600,1200) if fallback else Vector2(1600,900)
		for factor in [0.49,0.56,0.85,1.2]:
			renderer.size=renderer.canvas_size*factor
			for heading in [false,true]:
				var cell:=Rect2(10,20,500,70)
				var text: Dictionary=renderer._text_layout("BALLISTIC COMPUTER" if heading else "READY",cell,20,false,heading)
				var face: Font=renderer.title if heading else renderer.font
				check(text.point*factor>=(12.0 if heading else 13.0),"roomy compact label/readout retains output-point hierarchy")
				check(text.width<=cell.size.x and face.get_height(text.point)<=cell.size.y,"responsive text fits both measured cell dimensions")
			for value in ["100","READY","-----"]:
				var row:=Rect2(10,20,200,42)
				var cells: Array[Rect2]=renderer._row_layout(row,value)
				var text: Dictionary=renderer._text_layout(value,cells[1],23,true)
				check(row.encloses(cells[0]) and row.encloses(cells[1]) and cells[0].end.x+9<=cells[1].position.x,"larger values retain separated label/value cells")
				check(text.at.x>=cells[1].position.x and is_equal_approx(text.at.x+text.width,cells[1].end.x),"live readout fits and remains right-aligned")
			for miniature in [false,true]:
				var row:=Rect2(10,20,200,42)
				var layout: Dictionary=renderer._lamp_layout(row,miniature)
				var lamp: Rect2=layout.lamp
				var label: Rect2=layout.label
				check(row.encloses(lamp) and row.encloses(label) and label.end.x+6<=lamp.position.x,"responsive lamps stay clear of complete labels")
				check(lamp.size.x*factor>=(7.0 if miniature else 9.0)-0.001 and lamp.size.y*factor>=4.999,"compact lamp silhouettes retain readable output dimensions")
			for count in [28,39]:
				var rail:=Rect2(10,20,300,14)
				var segments: Array[Rect2]=renderer._bar_segments(rail,count)
				check(segments.size()==count and segments.all(func(box):return rail.grow(0.001).encloses(box) and box.size.x>0),"gauge retains every source segment within its rail")
				check((segments[1].position.x-segments[0].end.x)*factor>=0.999,"compact gauge segments retain at least one output-pixel gap")
			check(renderer._diagram_stroke(1)*factor>=0.999,"lamp outlines, separators and selection borders retain an output pixel")
	renderer.in_place=original_in_place
	renderer.canvas_size=original_canvas
	renderer.size=original_size

func schematic_layout(renderer: Control) -> void:
	var original_size: Vector2=renderer.size
	var original_canvas: Vector2=renderer.canvas_size
	for box in [Rect2(800,710,276,139),Rect2(744,357,385,363),Rect2(1080,498,310,270)]:
		var layout: Dictionary=renderer._navigation_layout(box,Vector2(62,44))
		var fitted: Rect2=layout.rect
		var target: Rect2=layout.target
		var scale_xy: Vector2=layout.scale
		check(target.grow(0.001).encloses(fitted),"complete orientation grid fits its navigation well")
		check(fitted.get_center().is_equal_approx(target.get_center()),"navigation grid centred above heading")
		check(is_equal_approx(scale_xy.y/scale_xy.x,1.2),"orientation retains original 4:3 pixel aspect")
		check(fitted.end.y<=box.end.y-32,"navigation never enters heading row")
	for canvas in [Vector2(1600,900),Vector2(1600,1200)]:
		renderer.canvas_size=canvas
		for extent in [Vector2(1440,810),Vector2(960,540),Vector2(853,509)]:
			renderer.size=extent
			var factor:=minf(extent.x/canvas.x,extent.y/canvas.y)
			for width in [1.0,1.2,1.3,1.4,1.7,2.0]:
				var stroke: float=renderer._diagram_stroke(width)
				check(stroke*factor>=0.999 and stroke>=width,"schematic linework retains at least one physical pixel")
	check(renderer.DAMAGE_ZONES==[Rect2(176,52,70,69),Rect2(211,7,102,28),Rect2(204,124,112,24),Rect2(310,34,60,84),Rect2(33,66,98,24)],"five damage zones retain exact existing registration and bit order")
	renderer.canvas_size=original_canvas
	renderer.size=original_size

func diagnostic_detail(renderer: Control) -> void:
	var old_size: Vector2=renderer.size
	var old_canvas: Vector2=renderer.canvas_size
	renderer.canvas_size=Vector2(1600,900)
	for factor in [0.49,0.56,0.85]:
		renderer.size=renderer.canvas_size*factor
		for box in [Rect2(10,40,780,282),Rect2(1140,340,360,96)]:
			var layout: Dictionary=renderer._tank_layout(box)
			var fit: float=minf(box.size.x/400.0,box.size.y/155.0)
			check(layout.at.is_equal_approx(box.get_center()-Vector2(400,155)*fit*0.5) and layout.scale.is_equal_approx(Vector2.ONE*fit),"diagnostic detail retains the complete incumbent schematic fit")
			check(layout.detail==(400*fit*factor>=300),"miniature schematic omits secondary engraving below 300 output pixels")
			for pitch in [7,9]:
				var step: int=renderer._mechanical_pitch(pitch,fit)
				check(step%pitch==0 and step*fit*factor>=3.999,"mechanical repeats retain authored cadence with at least four output pixels")
			for zone in renderer.DAMAGE_ZONES:
				var alert: Dictionary=renderer._damage_layout(zone,layout.at,layout.scale)
				check(alert.rect==Rect2(layout.at+zone.position*layout.scale,zone.size*layout.scale),"damage frame retains exact source-zone registration")
				var contained: bool=alert.lines.size()>0
				for line in alert.lines:
					for point in line: contained=contained and alert.inner.grow(0.001).has_point(point)
				check(contained and alert.rect.encloses(alert.inner),"every damage hatch is clipped inside its own zone")
				check(alert.pitch*factor>=6.999 and alert.corner<=minf(alert.rect.size.x,alert.rect.size.y)*0.24,"warning hatching and corner marks remain separated at compact sizes")
	renderer.canvas_size=old_canvas
	renderer.size=old_size

func control_legends(chrome: Control) -> void:
	var expected: Dictionary={1:[["ENTER","SELECT"],["L","LOCK"],["SPACE","FIRE"]],
		2:[["Z","MAP"],["F7-F10","SCAN"],["D","STATUS"]],3:[["A","ALIGN TURRET"],["C","HULL/TURRET"]],
		4:[["KEYPAD","DRIVE"],["KP5","STOP"]],5:[["ANY KEY","RETURN TO COMMANDER"]]}
	check(chrome.COMMANDS==expected,"Tactical keycaps retain exact incumbent keys and actions")
	var map: Control=chrome.map_art
	var old_box: Rect2=map.map_box
	map.map_box=Rect2(88,364.5,592,490.5)
	for scale in [0.49,0.56,0.85,1.2]:
		for id in range(1,6):
			var footer: Dictionary=chrome._footer_layout(id,scale)
			check(90+footer.station_width+40<=footer.command_x,"measured command group never overlaps station keys")
			check(footer.command_x>=90 and is_equal_approx(footer.command_x+footer.command_width-18,1512),"footer command label ends at established right inset")
			check(footer.station_point<=22 and footer.command_point<=22,"keycaps fit established footer height")
			check(footer.baseline-maxi(footer.station_point,footer.command_point)-1>=851 and footer.baseline+4<=899,"enlarged keycaps retain antialias clearance below crew strip and stay inside canvas")
			check(footer.station_point*scale>=10.5 and footer.command_point*scale>=10.5,"compact footer retains readable point sizes")
			check((footer.station_width==0)==(id==5),"Status has return action without station-switch hints")
			var header: Dictionary=chrome._header_layout(id,scale)
			check(header.name=="M1A1  /  "+chrome.STATIONS[id],"responsive header preserves station identity")
			var title_end: float=header.title_at.x+chrome.heading_font.get_string_size(header.name,HORIZONTAL_ALIGNMENT_LEFT,-1,header.title_point).x
			check(title_end<1512 and header.title_at.y+5<69,"nameplate remains outside the protected sight aperture")
			check(header.title_point*scale>=18,"compact nameplate remains readable")
		for mode in ["LOCAL","OVERVIEW"]:
			var label: Dictionary=map._mode_layout(mode,scale)
			var key: Rect2=label.key
			check(key.end.y<map.map_box.position.y and label.label_at.y<map.map_box.position.y,"map mode keycap remains outside protected map pixels")
			check(label.label_at.x>=key.end.x+8 and is_equal_approx(label.label_at.x+label.label_width,map.map_box.end.x),"map mode tag has measured spacing and right alignment")
			check(key.position.x>map.map_box.position.x+200 and label.point*scale>=11,"map mode remains readable and clear of map heading")
	map.map_box=old_box

func section_legibility(chrome: Control) -> void:
	var previous_size: Vector2=chrome.size
	for scale in [0.49,0.56,0.86,1.2]:
		chrome.size=Vector2(1600,900)*scale
		for id in [1,2,5]:
			for item in chrome.SECTIONS[id]:
				var at: Vector2=item[1]
				var layout: Dictionary=chrome._section_layout(at,item[0],item[2],scale)
				check(layout.point*scale>=11.99 and layout.point<=26,"complete section titles retain readable compact point sizes")
				check(layout.label_width<=item[2],"section title fits its existing column")
				check(layout.rule_from.x>=at.x+layout.label_width+16 and layout.rule_to.x==at.x+item[2],"section rule measures exact title clearance and column end")
				check(layout.rule_from.y==layout.rule_to.y and layout.rule_from.y<at.y,"section rule remains above the original baseline and live panel")
				check(chrome._stroke(1)*scale>=0.999,"section rules retain one output pixel")
		for mode in ["LOCAL","OVERVIEW"]:
			# Use the existing map box, without changing any map registration.
			var old_box: Rect2=chrome.map_art.map_box
			chrome.map_art.map_box=Rect2(88,364.5,592,490.5)
			var map_label: Dictionary=chrome.map_art._mode_layout(mode,scale)
			check(chrome.SECTIONS[2][0][1].x+chrome.SECTIONS[2][0][2]+16<=map_label.key.position.x,"map section rule stays clear of original mode keycap")
			chrome.map_art.map_box=old_box
	for width in [56.0,98.0,158.0,236.0]:
		for id in range(1,6):
			for action in chrome.FALLBACK_ACTIONS[id]:
				var point: int=chrome._gutter_command_point(action[0],action[1],width)
				if point>0:
					check(point>=9 and point<=13 and chrome._key_width(action[0],action[1],point)-18<=width,"fallback action keycap and complete label fit spare gutter")
				else:
					check(chrome._key_width(action[0],action[1],9)-18>width,"fallback action suppresses only an unfittable complete hint")
	var expected: Dictionary=chrome.COMMANDS.duplicate(true)
	expected[5]=[["ANY KEY","RETURN"]]
	check(chrome.FALLBACK_ACTIONS==expected,"fallback keycaps retain exact incumbent commands and return label")
	chrome.size=previous_size

func _present_fixture(display: Control, source: Image, packet: Dictionary) -> void:
	display.tandem_frame.set_frame(source,packet,ImageTexture.create_from_image(source),{"name":"SIM"})
	display.set_hud_frame(packet,{"name":"SIM"})

func retained_instruments(display: Control, prefix: String, retained: bool=true) -> void:
	var renderer: Control=display.tactical_chrome.instruments
	display.size=Vector2(960,540)
	display.set_hud_style("tactical")
	for name in ["gunner","commander","driver","status"]:
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(prefix+"-"+name+".json"))
		var source:=Image.create_from_data(320,200,false,Image.FORMAT_RGB8,PackedByteArray(data.rgb))
		var packet: Dictionary=data.packet.presentation
		_present_fixture(display,source,packet)
		await process_frame; await process_frame
		var draws: Array[int]=[0]
		var painted:=func(): draws[0]+=1
		var painters: Array[CanvasItem]=[]
		for i in renderer.panels.size():
			var painter: CanvasItem=renderer._clips[i].get_child(0)
			painter.draw.connect(painted);painters.append(painter)
		var panel_count: int=renderer.panels.size()
		check(panel_count>0,"retained drawing has accepted panels "+name)
		for repeat in 6:
			_present_fixture(display,source,packet)
			await process_frame; await process_frame
		print("TACTICAL_REDRAW ",name," panels=",panel_count," repeated_frames=6 draw_calls=",draws[0]," retained=",retained)
		check(draws[0]==0 if retained else draws[0]==6*panel_count,"unchanged verified panels retain drawing commands "+name)
		if retained:
			# Fresh provenance is still verified each frame, but is not painted.
			draws[0]=0
			for run in renderer.runs: run.draw_sequence=int(run.get("draw_sequence",0))+1
			if not renderer.orientation.is_empty(): renderer.orientation.page_offset=8192-int(renderer.orientation.page_offset)
			renderer._place_panels()
			await process_frame; await process_frame
			check(draws[0]==0,"advancing sequence and page metadata does not repaint unchanged ink "+name)
			# Mutate drawing inputs after proof only in this unit test. Every
			# nested value must invalidate a detached snapshot, never alias it.
			draws[0]=0
			renderer.runs[0].text+=" "
			renderer._place_panels()
			await process_frame; await process_frame
			check(draws[0]>0,"nested reading change invalidates retained drawings "+name)
			_present_fixture(display,source,packet)
			await process_frame; await process_frame
			draws[0]=0
			if name=="status": renderer.damage=31
			elif name=="commander": renderer.orientation.grid[0].points[0]+=1
			else:
				var gauge: Dictionary=renderer.gauges[0]
				if gauge.kind=="bar": gauge.lit=0 if gauge.lit>0 else 1
				else: gauge.color=Color.RED
			renderer._place_panels()
			await process_frame; await process_frame
			check(draws[0]>0,"damage, orientation or gauge change invalidates retained drawings "+name)
			_present_fixture(display,source,packet)
			await process_frame; await process_frame
			draws[0]=0
			renderer.font.emit_changed()
			await process_frame; await process_frame
			check(draws[0]>0,"font resource changes invalidate retained drawing "+name)
			draws[0]=0
			renderer.size+=Vector2(1,1)
			await process_frame; await process_frame
			check(draws[0]>0,"resize invalidates retained drawing "+name)
			# Proof still runs before reuse: a changed glyph/tag immediately drops
			# its complete panel while the other accepted panels stay visible.
			var rejected_index: int=renderer.panels[0].index
			var at: Vector2i=renderer.panels[0].source.position+Vector2i.ONE
			var bad:=source.duplicate();bad.set_pixelv(at,Color.MAGENTA)
			var bad_packet:=packet.duplicate(true)
			var tags:=Image.new()
			tags.load_png_from_buffer(Marshalls.base64_to_raw(packet.plate_overlay.mask_png))
			tags.set_pixelv(at,Color.BLACK)
			bad_packet.plate_overlay.mask_png=Marshalls.raw_to_base64(tags.save_png_to_buffer())
			_present_fixture(display,bad,bad_packet)
			check(not renderer.panels.any(func(p):return p.index==rejected_index),"fresh source rejection precedes drawing reuse "+name)
			check(renderer._clips.filter(func(clip):return clip.visible).size()==renderer.panels.size(),"rejected cached panels hidden immediately "+name)
			_present_fixture(display,source,packet)
			check(renderer.panels.size()==panel_count,"valid source recovers after retained-panel rejection "+name)
			renderer.clear()
			check(renderer._paint_state.is_empty() and not renderer._clips.any(func(clip):return clip.visible),"clear releases sole retained snapshot and hides all panels "+name)
		for painter in painters: painter.draw.disconnect(painted)

func fallback_instruments(display: Control, prefix: String, repo: String) -> void:
	var frame: Control=display.tandem_frame
	var renderer: Control=display.tactical_chrome.instruments
	var map: Control=display.tactical_chrome.map_art
	renderer.load_sources(repo)
	check(frame.typography.load_sources(repo.path_join("GAME")),"fallback fixture original fonts loaded")
	display.set_hud_style("tactical")
	for item in [["gunner",1,5],["commander",2,4],["commander-map",2,4],["driver",4,1],["status",5,3]]:
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(prefix+"-"+item[0]+".json"))
		var source:=Image.create_from_data(320,200,false,Image.FORMAT_RGB8,PackedByteArray(data.rgb))
		var packet: Dictionary=data.packet.presentation.duplicate(true)
		_present_fixture(display,source,packet)
		check(display._wide_station==item[1] and renderer.panels.size()==item[2],"wide station remains eligible "+item[0])
		# Synthetic negative fixture: one unknown pixel outside every reflowed
		# region forces 4:3 while the recorded panel/map evidence stays exact.
		var tags:=Image.new()
		tags.load_png_from_buffer(Marshalls.base64_to_raw(packet.plate_overlay.mask_png))
		tags.set_pixel(0,196,Color.BLACK)
		packet.plate_overlay.mask_png=Marshalls.raw_to_base64(tags.save_png_to_buffer())
		source.set_pixel(0,196,Color.MAGENTA)
		_present_fixture(display,source,packet)
		check(display._wide_station==0 and renderer.in_place and renderer.panels.size()==item[2],"verified fallback panels retained "+item[0])
		check(display.description().display_aspect=="4:3","fallback never widens source "+item[0])
		for window in [Vector2(1440,810),Vector2(960,540),Vector2(853,509)]:
			display.size=window
			display._resize_targets()
			var fit: Rect2i=Display.fitted_rect(Vector2i(window))
			check(renderer.position==Vector2(fit.position) and renderer.size==Vector2(fit.size),"fallback canvas follows fitted frame "+str(window))
			for i in renderer.panels.size():
				var panel: Dictionary=renderer.panels[i]
				var expected:=Rect2(Vector2(panel.source.position)/Vector2(320,200)*renderer.size,Vector2(panel.source.size)/Vector2(320,200)*renderer.size)
				var clip: Control=renderer._clips[i]
				check(clip.clip_contents and expected.encloses(Rect2(clip.position,clip.size)),"panel pixels clipped to original footprint "+str(panel.index))
			if item[1]==2:
				check(map.position==Vector2(fit.position) and map.size==Vector2(fit.size),"map canvas follows fitted frame")
				if item[0]=="commander-map":
					check(map.in_place and map.picture.visible,"UI-owned OVERVIEW fallback map active")
					check(map.picture.position.is_equal_approx(Vector2(16,63)/Vector2(320,200)*map.size) and map.picture.size.is_equal_approx(Vector2(144,96)/Vector2(320,200)*map.size),"map stays in exact crop without surround/caption")
				else:
					check(map.packet.is_empty() and not map.picture.visible,"world-owned LOCAL terrain remains original in fallback")
		var first: Dictionary=renderer.panels[0]
		var bad_source:=source.duplicate()
		var bad_packet:=packet.duplicate(true)
		var at:=Vector2i(first.source.position)+Vector2i.ONE
		bad_source.set_pixelv(at,Color.MAGENTA)
		var bad_tags: Image=tags.duplicate()
		bad_tags.set_pixelv(at,Color.BLACK)
		bad_packet.plate_overlay.mask_png=Marshalls.raw_to_base64(bad_tags.save_png_to_buffer())
		_present_fixture(display,bad_source,bad_packet)
		check(renderer.panels.size()==item[2]-1 and not renderer.panels.any(func(p):return p.index==first.index),"one unknown panel leaves other verified panels active "+item[0])
		if item[1]==1:
			bad_source=source.duplicate()
			bad_source.set_pixel(52,143,Color.MAGENTA)
			_present_fixture(display,bad_source,packet)
			check(not renderer.panels.any(func(p):return p.index==1),"corrupted original glyph retains complete readout panel")
		_present_fixture(display,source,packet)
		var stale: Dictionary=packet.duplicate(true)
		stale.scanout_sequence+=1
		display.set_hud_frame(stale,{"name":"SIM"})
		check(renderer.panels.is_empty() and map.packet.is_empty(),"unpaired fallback metadata clears overlay "+item[0])
		_present_fixture(display,source,packet)
		display.set_hud_frame(packet,{"name":"SIM"},bad_tags)
		check(renderer.panels.is_empty(),"unpaired explicit plate mask rejected "+item[0])
		_present_fixture(display,source,packet)
		var nonbinary: Dictionary=packet.duplicate(true)
		var ui:=Image.new()
		ui.load_png_from_buffer(Marshalls.base64_to_raw(packet.ui_overlay.mask_png))
		ui.set_pixel(0,0,Color8(128,128,128))
		nonbinary.ui_overlay.mask_png=Marshalls.raw_to_base64(ui.save_png_to_buffer())
		display.set_hud_frame(nonbinary,{"name":"SIM"})
		check(renderer.panels.is_empty() and not map.picture.visible,"nonbinary UI clears all fallback overlays "+item[0])
		if item[1]==2:
			var missing_ui: Dictionary=packet.duplicate(true)
			ui.load_png_from_buffer(Marshalls.base64_to_raw(packet.ui_overlay.mask_png))
			ui.set_pixel(20,70,Color.BLACK)
			missing_ui.ui_overlay.mask_png=Marshalls.raw_to_base64(ui.save_png_to_buffer())
			_present_fixture(display,source,missing_ui)
			check(map.packet.is_empty() and not map.picture.visible,"one unowned map pixel restores complete original map")
			var stale_map: Dictionary=packet.duplicate(true)
			stale_map.dynamic_map.pixel_sha256="unverified"
			_present_fixture(display,source,stale_map)
			check(map.packet.is_empty() and not map.picture.visible,"unverified map readback clears fallback cartography")
		_present_fixture(display,source,packet)
		display.set_hud_style("restored")
		check(renderer.panels.is_empty() and not renderer._clips.any(func(c):return c.visible) and not map.picture.visible,"Restored clears retained fallback children "+item[0])
		display.set_hud_style("tactical")
		_present_fixture(display,source,packet)
		display.set_hud_frame(packet,{"name":"START"})
		check(renderer.panels.is_empty() and not map.picture.visible,"non-SIM clears fallback children "+item[0])
		for mode in ["ega","genesis"]:
			frame.set_graphics_mode(mode)
			_present_fixture(display,source,packet)
			check(renderer.panels.is_empty() and not map.picture.visible,"native graphics exclude fallback vector overlays "+mode)
			check(display.display.material==null and display._wide_station==0,"native graphics bypass Tactical HUD restyle and reflow "+mode)
		frame.set_graphics_mode("upscaled")
		# A wide packet must reset child coordinates after all fallback resizes.
		_present_fixture(display,Image.create_from_data(320,200,false,Image.FORMAT_RGB8,PackedByteArray(data.rgb)),data.packet.presentation)
		check(display._wide_station==item[1] and renderer.position==Vector2.ZERO and not renderer.in_place,"wide layout recovers original coordinates "+item[0])

func crew_panels() -> void:
	const Typography=preload("res://scripts/pc_typography.gd")
	var source:=Image.create_empty(320,200,false,Image.FORMAT_RGB8)
	source.fill(Color.BLACK)
	source.fill_rect(Rect2i(30,2,240,10),Color.WHITE)
	source.fill_rect(Rect2i(31,3,238,8),Color8(170,170,170))
	source.set_pixel(36,4,Color.BLACK)
	source.set_pixel(72,4,Color.BLACK)
	var ui:=Image.create_empty(320,200,false,Image.FORMAT_L8)
	ui.fill(Color.WHITE)
	# This helper consumes only the output of verified_run. Glyph/hash tests
	# live in the established typography suite; these test the complete panel.
	var parts: Array=[]
	for item in [["crew_primary",36,36],["crew_secondary",72,90]]:
		parts.append({"kind":item[0],"rect":Rect2(item[1],4,item[2],6),"font_sha256":Typography.FONT_SOURCES["6X6.FNT"],
			"cell_size":Vector2i(6,6),"foreground":Color.BLACK,"background":Color8(170,170,170)})
	var before:=source.get_data()
	check(Typography.verified_crew_panel(source,ui,parts)==Rect2i(30,2,240,10),"whole verified crew panel accepted")
	check(source.get_data()==before,"crew proof never mutates source pixels")
	source.set_pixel(200,5,Color.BLACK)
	check(Typography.verified_crew_panel(source,ui,parts).size==Vector2i.ZERO,"unknown crew write retains complete source")
	source.set_pixel(200,5,Color8(170,170,170))
	source.set_pixel(30,2,Color.BLACK)
	check(Typography.verified_crew_panel(source,ui,parts).size==Vector2i.ZERO,"unknown crew border rejected")
	source.set_pixel(30,2,Color.WHITE)
	ui.set_pixel(200,5,Color.BLACK)
	check(Typography.verified_crew_panel(source,ui,parts).size==Vector2i.ZERO,"crew ownership checked every frame")
	ui.set_pixel(200,5,Color.WHITE)
	check(Typography.verified_crew_panel(source,ui,[parts[0]]).size==Vector2i.ZERO,"partial crew message cannot theme panel")
	parts[1].rect.position.x+=1
	check(Typography.verified_crew_panel(source,ui,parts).size==Vector2i.ZERO,"nonadjacent crew message rejected")

func station_instruments(display: Control, prefix: String) -> void:
	var repo:=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var frame: Control=display.tandem_frame
	display.tactical_chrome.instruments.load_sources(repo)
	check(frame.load_genesis_art(repo),"instrument fixture art loaded")
	check(frame.typography.load_sources(repo.path_join("GAME")),"instrument fixture fonts loaded")
	display.set_hud_style("tactical")
	for item in [["gunner",1,5],["commander",2,4],["driver",4,1],["status",5,3]]:
		var path: String=prefix+"-"+item[0]+".json"
		check(FileAccess.file_exists(path),"recorded station fixture present "+item[0])
		if not FileAccess.file_exists(path): continue
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		var source:=Image.create_from_data(320,200,false,Image.FORMAT_RGB8,PackedByteArray(data.rgb))
		var packet: Dictionary=data.packet.presentation
		var world:=ImageTexture.create_from_image(source)
		check(frame.set_frame(source,packet,world),"paired station fixture "+item[0])
		display.set_hud_frame(packet,{"name":"SIM"},frame._current_plate_mask)
		var renderer: Control=display.tactical_chrome.instruments
		print("TACTICAL_PANELS ",item[0]," active=",renderer.panels.map(func(p):return p.index)," rejected=",renderer.rejected)
		check(renderer.panels.size()==item[2],"all source-proven instrument panels "+item[0])
		if renderer.panels.is_empty(): continue
		var panel: Dictionary=renderer.panels[0]
		var at: Vector2i=panel.source.position
		var tags: Image=frame._current_plate_mask.duplicate()
		tags.set_pixelv(at,Color.BLACK)
		frame._cached_source=source.duplicate()
		frame._cached_source.set_pixelv(at,Color.MAGENTA)
		renderer.set_frame(frame,item[1],Display.TACTICAL_LAYOUTS[item[1]],tags,display._hud_mask_data)
		check(not renderer.panels.any(func(p):return p.index==panel.index),"unknown live pixel retains source panel "+item[0])
		display.set_hud_style("restored")
		check(renderer.panels.is_empty(),"Restored removes instrument overlay "+item[0])
		display.set_hud_style("tactical")

	# All 32 visible damage combinations use the same original RGB/tag catalog.
	var renderer: Control=display.tactical_chrome.instruments
	var mask:=Image.create_empty(320,200,false,Image.FORMAT_L8)
	mask.fill(Color.WHITE)
	for bits in 32:
		var directory:=repo.path_join("artifacts/finish-20260928/status-damage-oracle-02")
		var source:=Image.load_from_file(directory.path_join("state-%02d.png"%bits))
		var tags:=Image.load_from_file(directory.path_join("tags-%02d.png"%bits))
		if source==null or tags==null: check(false,"damage fixture available"); break
		check(renderer._damage_state(source,mask,tags)==bits,"Tactical exact visible damage combination %d"%bits)
		source.set_pixel(125,40,Color.MAGENTA)
		check(renderer._damage_state(source,mask,tags)==-1,"unknown diagram retains original %d"%bits)
	# PC-only operation reads no Genesis artwork and uses the same PC evidence.
	var pc_display:=Display.new()
	root.add_child(pc_display)
	pc_display.tactical_chrome.instruments.load_sources(repo)
	pc_display.tandem_frame.typography.load_sources(repo.path_join("GAME"))
	pc_display.set_hud_style("tactical")
	for item in [["gunner",5],["commander",4],["driver",1],["status",3]]:
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(prefix+"-"+item[0]+".json"))
		var source:=Image.create_from_data(320,200,false,Image.FORMAT_RGB8,PackedByteArray(data.rgb))
		var packet: Dictionary=data.packet.presentation
		pc_display.tandem_frame.set_frame(source,packet,ImageTexture.create_from_image(source))
		pc_display.set_hud_frame(packet,{"name":"SIM"})
		check(pc_display.tactical_chrome.instruments.panels.size()==item[1],"PC-only vector instruments "+item[0])
	pc_display.free()

func station_maps(display: Control, prefix: String) -> void:
	var frame: Control=display.tandem_frame
	var map: Control=display.tactical_chrome.map_art
	for name in ["commander","commander-map"]:
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(prefix+"-"+name+".json"))
		var source:=Image.create_from_data(320,200,false,Image.FORMAT_RGB8,PackedByteArray(data.rgb))
		var packet: Dictionary=data.packet.presentation
		var before:=JSON.stringify(packet)
		display.set_hud_style("tactical")
		# Dummy storage preserves initial images but texture_2d_update is a no-op.
		# Check byte custody on a fresh texture; GPU updates are exercised by the
		# browser route switching LOCAL/OVERVIEW on this same live renderer.
		map.crop_texture=null
		frame.set_frame(source,packet,ImageTexture.create_from_image(source))
		var reused: int=map.proof_reuse_count
		display.set_hud_frame(packet,{"name":"SIM"},frame._current_plate_mask)
		check(not map.packet.is_empty() and map.picture.visible,"Tactical map active: "+name)
		check(map.proof_reuse_count==reused+1,"Tactical map reuses the tandem frame's identical map proof: "+name)
		check(map.crop_texture.get_image().get_data()==source.get_region(Rect2i(16,63,144,96)).get_data(),"initial map texture retains every source feature: "+name)
		check(JSON.stringify(packet)==before and source.get_data()==PackedByteArray(data.rgb),"map style never mutates source: "+name)
		var mode:=int(packet.dynamic_map.mode)
		check(map.ink.get_shader_parameter("local_map")==bool(mode),"raw source stencil is limited to LOCAL player footprint")
		var terrain:=Map.terrain_image(source,packet.dynamic_map)
		check(terrain.get_size()==(Vector2i(48,48) if mode==0 else Vector2i(144,96)),"original overview cell grid and full local raster retained")
		if mode==0:
			var exact:=true
			var marker: Array=packet.dynamic_map.lines[-1]
			for y in 96:
				for x in 144:
					if x+16==marker[0] and y+63==marker[1]: continue
					if terrain.get_pixel(x/3,y/2)!=source.get_pixel(x+16,y+63): exact=false
			check(exact,"overview terrain reconstruction retains all visible source cells and excludes player dot")
		else:
			var styled:=Map.surface_image(terrain,true)
			var dark:=0;var light:=0;var protected_contact:=0
			for y in 96:
				for x in 144:
					var pixel:=styled.get_pixel(x,y)
					if pixel==Color8(85,43,0): dark+=1
					if pixel==Color8(128,85,43): light+=1
					if source.get_pixel(x+16,y+63)==Color8(85,255,85) and pixel.a==0: protected_contact+=1
			check(dark>100 and light>20,"real local checker terrain receives continuous derived materials")
			check(protected_contact==6,"all six source contact pixels remain protected")
		var stable_surface_hash: String=map.surface_hash
		for colour in ([0,1,13] if mode==1 else [0,5,6]):
			var changed:=source.duplicate()
			var live:=packet.duplicate(true)
			var count:=2 if mode==1 else 1
			for i in range(live.dynamic_map.lines.size()-count,live.dynamic_map.lines.size()):
				var row: Array=live.dynamic_map.lines[i]
				row[4]=colour
				var rgb: Array=live.dynamic_map.palette_rgb[colour]
				changed.fill_rect(Rect2i(row[0],row[1],row[2]-row[0]+1,1),Color8(rgb[0],rgb[1],rgb[2]))
			var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
			hash.update(changed.get_region(Rect2i(16,63,144,96)).get_data())
			live.dynamic_map.pixel_sha256=hash.finish().hex_encode()
			frame._cached_source=changed;frame._cached_presentation=live
			reused=map.proof_reuse_count
			check(map.set_frame(frame,Display.TACTICAL_LAYOUTS[2]),"source-selected marker colour accepted %d/%d"%[mode,colour])
			check(map.proof_reuse_count==reused,"a packet the tandem frame did not prove is proven independently")
			check(map.crop_hash==live.dynamic_map.pixel_sha256,"texture update cache follows current whole-map proof")
			check(map.surface_hash==stable_surface_hash,"player blinking never rebuilds terrain or pollutes surface classes")
			var rgb: Array=live.dynamic_map.palette_rgb[colour]
			check(map.ink.get_shader_parameter("marker_colour_0")==Color8(rgb[0],rgb[1],rgb[2]),"marker colour unchanged, including black")
		frame._cached_source=source.duplicate();frame._cached_presentation=packet
		frame._cached_source.set_pixel(20,70,Color.MAGENTA)
		check(not map.set_frame(frame,Display.TACTICAL_LAYOUTS[2]) and not map.picture.visible,"stale full-map readback clears overlay")
		frame._cached_source=source
		check(map.set_frame(frame,Display.TACTICAL_LAYOUTS[2]),"valid map recovers")
		display.set_hud_style("restored")
		check(map.packet.is_empty() and not map.picture.visible,"Restored/Modernized excludes Tactical map")
		check(frame.dynamic_map_art.packet==packet.dynamic_map,"original map renderer remains untouched")

func map_surfaces() -> void:
	for alternate in [0,85]:
		var source:=Image.create(8,8,false,Image.FORMAT_RGBA8)
		for y in 8:
			for x in 8:
				source.set_pixel(x,y,Color8(170,85,0) if (x+y+63)%2==1 else Color8(alternate,alternate,alternate))
		var before:=source.get_data()
		var derived:=Map.surface_image(source,true)
		var expected:=Color8(85,43,0) if alternate==0 else Color8(128,85,43)
		var exact:=true
		for y in 8:
			for x in 8:
				if derived.get_pixel(x,y)!=expected: exact=false
		check(exact,"complete source-phased checker is reconstructed, recipe "+str(alternate))
		check(source.get_data()==before,"surface processing leaves original image immutable")
		var wrong_phase:=source.duplicate();wrong_phase.flip_x()
		check(Map.surface_image(wrong_phase,true).get_pixel(3,3)!=expected,"wrong screen phase cannot claim original material recipe")
		var tiny:=source.get_region(Rect2i(0,0,2,2))
		check(Map.surface_image(tiny,true).get_pixel(0,0).a==0,"tiny checker mark is protected")
		check(Map.surface_image(source,false).get_pixel(3,3)!=expected,"overview never dedithers arbitrary cell patterns")
		var ink:=source.duplicate();ink.set_pixel(3,3,Color8(85,255,85))
		var protected:=Map.surface_image(ink,true).get_pixel(3,3)
		check(protected==Color8(85,255,85,0),"unknown ink retains exact RGB and protection mask")
		ink=source.duplicate();ink.set_pixel(3,3,Color(0,0,0,0))
		check(Map.surface_image(ink,true).get_pixel(3,3).a==0,"player stencil cannot enter pattern recognition")
	var joined:=PackedInt32Array([1,1,-1,2,1,-1,2,2,-1,1,1,-1,2,-1,-1,1])
	var classed:=PackedInt32Array()
	for i in joined.size():
		if joined[i]>=0: classed.append(i)
	var components:=Map._components(joined,4,classed)
	var total:=0
	for cells in components: total+=cells.size()
	check(components.size()==5 and total==10,"unique cardinal components keep diagonally touching classes separate")

# Run labelling must equal the cell flood fill it replaced, component for
# component, including diagonal contacts, wrapped rows and single columns.
func map_labelling() -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=20261015
	var exact:=true
	for trial in 120:
		var width:=rng.randi_range(1,24);var height:=rng.randi_range(1,18)
		var codes:=PackedInt32Array();codes.resize(width*height)
		for i in codes.size(): codes[i]=rng.randi_range(-3,-1) if trial%2==0 else (-1 if (i%width+i/width+trial)%3==0 else -2)
		var every:=PackedInt32Array()
		for i in codes.size(): every.append(i)
		var expected: Dictionary={}
		for cells: PackedInt32Array in Map._components(codes,width,every):
			var first: int=cells[0]
			for at in cells: first=mini(first,at)
			for at in cells: expected[at]=[first,cells.size()]
		var labelled:=Map._run_components(codes,width)
		for run in labelled.starts.size():
			var root: int=labelled.roots[run]
			for at in range(labelled.starts[run],labelled.starts[run]+labelled.lengths[run]):
				exact=exact and expected[at]==[labelled.starts[root],labelled.sizes[root]]
	check(exact,"run labelling reproduces every cardinal component, size and first cell")
	# A recorded-scale LOCAL crop: report the rebuild cost against a 60 Hz frame.
	var local:=Image.create(144,96,false,Image.FORMAT_RGBA8)
	local.fill(Color8(0,170,0))
	for y in 96:
		for x in 144:
			if (x/24+y/16)%3==0: local.set_pixel(x,y,Color8(170,85,0) if (x+y+63)%2==1 else Color8(0 if x<72 else 85,0 if x<72 else 85,0 if x<72 else 85))
			elif (x*7+y*3)%53==0: local.set_pixel(x,y,Color8(85,85,85))
	local.fill_rect(Rect2i(69,45,6,6),Color(0,0,0,0))
	var started:=Time.get_ticks_usec()
	var styled:=Map.surface_image(local,true)
	var elapsed:=Time.get_ticks_usec()-started
	print("TACTICAL_MAP_SURFACE usec=",elapsed," cells=",144*96)
	check(styled.get_pixel(5,5)==Color8(85,43,0) and styled.get_pixel(80,5)==Color8(128,85,43),"recorded-scale checker terrain receives both material recipes")
	check(styled.get_pixel(71,47).a==0 and styled.get_pixel(30,30)==Color8(0,170,0),"stencil stays protected and field ink retained")
	var white:=Image.create(8,8,false,Image.FORMAT_RGBA8);white.fill(Color.WHITE)
	check(Map.surface_image(white,true).get_pixel(3,3).a==0,"unsupported white region cannot alias an unmarked pattern sentinel")

# Blinking contacts alternate crops; an exact-content cache rebuilds each once.
func map_surface_cache() -> void:
	var map:=Map.new()
	var sources: Array[Image]=[]
	for blink in 2:
		var source:=Image.create(320,200,false,Image.FORMAT_RGB8)
		source.fill(Color8(0,170,0))
		source.fill_rect(Rect2i(40,80,6,4),Color8(170,170,170) if blink==0 else Color8(0,170,0))
		sources.append(source)
	for repeat in 3:
		for source in sources: map._surface(source,{"mode":1})
	check(map.surface_build_count==2,"alternating crops rebuild their styled surfaces once each")
	var expected:=Map.surface_image(Map.terrain_image(sources[1],{"mode":1}),true)
	check(map._surface_cache[map.surface_hash].get_data()==expected.get_data(),"cached surface is the exact current crop's restyle")
	for n in Map.SURFACE_CACHE_SIZE+2:
		var source:=Image.create(320,200,false,Image.FORMAT_RGB8)
		source.fill(Color8(0,170,0));source.set_pixel(30+n,80,Color8(85,85,255))
		map._surface(source,{"mode":1})
	check(map._surface_cache.size()==Map.SURFACE_CACHE_SIZE and map._surface_order.size()==Map.SURFACE_CACHE_SIZE,"surface cache stays bounded")
	map.free()

# CPU mirror of pc_tactical_hud.gdshader's neutral and chromatic ink ramps.
# Every literal (segment ends, thresholds, chroma gate, branch conditions and
# accent ramps) is read back from the shader so the mirror cannot drift.
static func _vec3(text: String) -> Color:
	var c:=text.split(",")
	return Color(float(c[0]),float(c[1]),float(c[2]))

# A condition is a conjunction of "source.x > source.y * k" or "source.x > k".
static func _condition(text: String) -> Array:
	var term:=RegEx.create_from_string("^source\\.([rgb]) > (?:source\\.([rgb]) \\* )?([0-9.]+)$")
	var terms: Array=[]
	for part in text.split("&&"):
		var found:=term.search(part.strip_edges())
		if found==null: return []
		terms.append([found.get_string(1),found.get_string(2),float(found.get_string(3))])
	return terms

static func _holds(rgb: Color, terms: Array) -> bool:
	var channel:={"r":rgb.r,"g":rgb.g,"b":rgb.b}
	for t: Array in terms:
		if not float(channel[t[0]])>(float(channel[t[1]])*float(t[2]) if t[1]!="" else float(t[2])): return false
	return true

static func hud_ramp_model(code: String) -> Dictionary:
	var neutral_body:=code.substr(code.find("vec3 neutral_ink(float luma)"),code.find("void fragment()")-code.find("vec3 neutral_ink(float luma)"))
	var segments: Array=[]
	for found in RegEx.create_from_string("mix\\(vec3\\(([^)]*)\\), vec3\\(([^)]*)\\), \\(?luma(?: - ([0-9.]+)\\))? / ([0-9.]+)\\)").search_all(neutral_body):
		segments.append([_vec3(found.get_string(1)),_vec3(found.get_string(2)),float(found.get_string(3)) if found.get_string(3)!="" else 0.0,float(found.get_string(4))])
	var limits: Array=[]
	for found in RegEx.create_from_string("luma < ([0-9.]+)").search_all(neutral_body): limits.append(float(found.get_string(1)))
	var gate:=RegEx.create_from_string("if \\(chroma > ([0-9.]+)\\)").search(code)
	var weight:=RegEx.create_from_string("clamp\\(\\(chroma - ([0-9.]+)\\) \\* ([0-9.]+), 0\\.0, 1\\.0\\)").search(code)
	var body:=code.substr(code.find("vec3 accent;"),code.find("colour = mix(colour, accent, weight);")-code.find("vec3 accent;"))
	var ramps: Array=[]
	for found in RegEx.create_from_string("accent = mix\\(vec3\\(([^)]*)\\), vec3\\(([^)]*)\\), luma\\)").search_all(body):
		ramps.append([_vec3(found.get_string(1)),_vec3(found.get_string(2))])
	var conditions: Array=[]
	for found in RegEx.create_from_string("if \\((source[^{\\n]*?)\\)(?: \\{| accent)").search_all(body): conditions.append(_condition(found.get_string(1)))
	# Mirrored structure: if C0 { if C1 r0 else r1 } else if C2 r2 else if C3 r3
	# else if C4 r4 else r5. Any other shape fails the model check below.
	var shaped:=body.count("} else if (")==3 and body.count("else accent")==1 and body.count("} else {")==1
	var ok:=segments.size()==4 and limits.size()==3 and gate!=null and weight!=null and ramps.size()==6 and conditions.size()==5 and shaped
	for terms in conditions: ok=ok and not terms.is_empty()
	return {"ok":ok,"segments":segments,"limits":limits,"gate":float(gate.get_string(1)) if gate else 0.0,
		"offset":float(weight.get_string(1)) if weight else 0.0,"gain":float(weight.get_string(2)) if weight else 0.0,"ramps":ramps,"conditions":conditions}

static func hud_ink(rgb: Color, model: Dictionary) -> Color:
	var luma:=rgb.r*0.2126+rgb.g*0.7152+rgb.b*0.0722
	var segment: int=model.limits.size()
	for i in model.limits.size():
		if luma<float(model.limits[i]): segment=i;break
	var s: Array=model.segments[segment]
	var neutral: Color=Color(s[0]).lerp(Color(s[1]),(luma-float(s[2]))/float(s[3]))
	var chroma:=maxf(rgb.r,maxf(rgb.g,rgb.b))-minf(rgb.r,minf(rgb.g,rgb.b))
	if not chroma>float(model.gate): return neutral
	var c: Array=model.conditions
	var ramp: int
	if _holds(rgb,c[0]): ramp=0 if _holds(rgb,c[1]) else 1
	elif _holds(rgb,c[2]): ramp=2
	elif _holds(rgb,c[3]): ramp=3
	elif _holds(rgb,c[4]): ramp=4
	else: ramp=5
	var accent: Color=Color(model.ramps[ramp][0]).lerp(Color(model.ramps[ramp][1]),luma)
	return neutral.lerp(accent,clampf((chroma-float(model.offset))*float(model.gain),0.0,1.0))

func hud_ink_separation() -> void:
	var code:=FileAccess.get_file_as_string("res://scripts/pc_tactical_hud.gdshader")
	var model:=hud_ramp_model(code)
	check(model.ok,"HUD shader exposes the mirrored neutral ramp, chroma gate, five branch conditions and six accent ramps")
	if not model.ok: return
	# The parser reads what the shader evaluates: a perturbed branch literal or
	# neutral segment end must change the mirrored model.
	check(hud_ramp_model(code.replace("source.g * 1.30","source.g * 1.90")).conditions!=model.conditions \
		and hud_ramp_model(code.replace("vec3(0.320, 0.398, 0.310), vec3(0.665","vec3(0.320, 0.398, 0.310), vec3(0.965")).segments!=model.segments,"HUD ramp mirror tracks shader literals")
	# Every distinct SIM palette entry stays distinguishable after the finish.
	var palette: Array=preload("res://scripts/pc_orientation_art.gd").PALETTE
	var closest:=INF
	for i in palette.size():
		for j in range(i+1,palette.size()):
			if palette[i]==palette[j]: continue
			var a:=hud_ink(palette[i],model);var b:=hud_ink(palette[j],model)
			closest=minf(closest,Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length())
	check(closest>=0.15,"Tactical HUD keeps every SIM palette pair apart (closest %.3f)"%closest)
	var brown:=hud_ink(Color8(170,85,0),model);var salmon:=hud_ink(Color8(255,85,85),model)
	check(Vector3(brown.r-salmon.r,brown.g-salmon.g,brown.b-salmon.b).length()>0.25,"light red stays bright against brown")
	var blue:=hud_ink(Color8(0,0,170),model)
	check(blue.b>0.35 and blue.b>blue.g,"blue ink stays blue rather than near-black teal")

# The native panel test must accept and reject exactly the pixels the earlier
# per-pixel predicate did, including the driver border blue exception.
func uncovered_panel_pixels() -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=1015
	var exact:=true
	var accepted:=0
	for trial in 160:
		var id: int=[1,2,4,5][trial%4]
		var box:=Rect2i(60,186,198,12) if id==4 else Rect2i(rng.randi_range(0,40),rng.randi_range(0,40),rng.randi_range(1,30),rng.randi_range(1,20))
		var source:=Image.create(320,200,false,Image.FORMAT_RGB8)
		var tags:=Image.create(320,200,false,Image.FORMAT_L8)
		tags.fill(Color8(id,id,id))
		var holes:=rng.randi_range(0,6)
		for n in holes:
			var at:=box.position+Vector2i(rng.randi_range(0,box.size.x-1),rng.randi_range(0,box.size.y-1))
			tags.set_pixelv(at,Color8(0,0,0) if trial%5!=0 else Color8(3,3,3))
			var ink:=rng.randi_range(0,3)
			if ink==1: source.set_pixelv(at,Color8(170,170,170))
			elif ink==2: source.set_pixelv(at,Color8(85,85,255))
			elif ink==3: source.set_pixelv(at,Color8(0,0,1))
		if id==4 and trial%8==0:
			tags.fill_rect(Rect2i(64,189,45,9),Color8(0,0,0));source.fill_rect(Rect2i(64,189,45,1),Color8(85,85,255))
		var reference:=true
		for y in range(box.position.y,box.end.y):
			for x in range(box.position.x,box.end.x):
				if tags.get_pixel(x,y).r8==id: continue
				var c:=source.get_pixel(x,y)
				if c==Color.BLACK: continue
				var border:=false
				for rect in [Rect2i(64,189,45,9),Rect2i(112,189,39,9),Rect2i(154,189,51,9),Rect2i(208,189,45,9)]:
					border=border or (rect.has_point(Vector2i(x,y)) and (x==rect.position.x or x==rect.end.x-1 or y==rect.position.y or y==rect.end.y-1))
				if id==4 and c==Color8(85,85,255) and border: continue
				reference=false
		var native:=Instruments._uncovered_black(source,tags.get_region(box),box,id)
		exact=exact and native==reference
		if native: accepted+=1
	check(exact and accepted>10 and accepted<150,"native uncovered-pixel test matches the per-pixel predicate")


func gunner_corner_finish() -> void:
	var source:=Image.create_empty(320,200,false,Image.FORMAT_RGB8)
	source.fill(Color8(85,85,85))
	var ui:=PackedByteArray();ui.resize(64000);ui.fill(255)
	var tags:=PackedByteArray();tags.resize(64000)
	check(Display.source_gunner_corners(source,ui,tags),"PC-only source-grey sight corners are proven without optional art")
	var at:=Vector2i(32,13)
	source.set_pixelv(at,Color.MAGENTA)
	check(not Display.source_gunner_corners(source,ui,tags),"unknown corner ink rejects the complete finish")
	source.set_pixelv(at,Color8(85,85,85));ui[13*320+32]=0
	check(not Display.source_gunner_corners(source,ui,tags),"visible world never becomes rubber")
	ui[13*320+32]=255;tags[13*320+32]=1
	check(not Display.source_gunner_corners(source,ui,tags),"changed corner provenance rejects finish")
