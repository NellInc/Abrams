extends SceneTree
const Display=preload("res://scripts/pc_play_display.gd")
const Menu=preload("res://scripts/pc_play_menu.gd")
const Map=preload("res://scripts/pc_tactical_map.gd")
var errors: Array[String]=[]
var checks:=0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: errors.append(label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	map_surfaces()
	var display:=Display.new()
	root.add_child(display)
	display.size=Vector2i(640,480)
	var menu:=Menu.new()
	menu.config_path=""
	menu.quality_config_path=""
	root.add_child(menu)
	check(menu.hud_style=="restored" and display.hud_style=="restored","Restored defaults")
	check(not menu.choose_hud_style("unknown") and menu.hud_style=="restored","unknown HUD style rejected")
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
	menu.free()
	display.free()
	print("PC_TACTICAL_HUD: %d checks, %d errors"%[checks,errors.size()])
	for error in errors: printerr(error)
	quit(0 if errors.is_empty() else 1)

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
		display.set_hud_frame(packet,{"name":"SIM"},frame._current_plate_mask)
		check(not map.packet.is_empty() and map.picture.visible,"Tactical map active: "+name)
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
			check(map.set_frame(frame,Display.TACTICAL_LAYOUTS[2]),"source-selected marker colour accepted %d/%d"%[mode,colour])
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
	var components:=Map._components(joined,4)
	var total:=0
	for cells in components: total+=cells.size()
	check(components.size()==5 and total==10,"unique cardinal components keep diagonally touching classes separate")
