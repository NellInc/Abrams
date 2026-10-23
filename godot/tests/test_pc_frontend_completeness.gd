extends SceneTree
## Regression for PC-only authored presentation, source proof and ending motion.
const Frontend=preload("res://scripts/pc_frontend_art.gd")
const Tandem=preload("res://scripts/pc_tandem_frame.gd")
var errors: Array[String]=[]
var checks:=0
var out: String
var native:=false
var display: SubViewport
var art: TextureRect
var original: TextureRect
func _initialize() -> void:
	create_timer(180).timeout.connect(func(): printerr("FAIL: frontend completeness deadline");quit(2))
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok and errors.size()<20: errors.append(label)
func snap(label: String) -> Image:
	await process_frame
	RenderingServer.force_draw(false);RenderingServer.force_sync()
	var image:=display.get_texture().get_image()
	image.save_png(out.path_join(label+".png"))
	return image
func run() -> void:
	var directory:=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args:=OS.get_cmdline_user_args()
	if not "--fixture" in args:
		printerr("Supply --fixture from tools.capture_pc_menu_text --mode trace --route lifecycle");quit(2);return
	var fixture: String=args[args.find("--fixture")+1]
	native="--native" in args
	out=args[args.find("--output")+1] if "--output" in args else fixture.get_base_dir().path_join("rendered")
	if native: DirAccess.make_dir_recursive_absolute(out)
	display=SubViewport.new();display.size=Vector2i(1280,800);display.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(display)
	original=TextureRect.new();original.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;original.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;original.size=display.size;display.add_child(original)
	art=Frontend.new();art.size=display.size;display.add_child(art)
	check(art.load_sources(directory),"PC-only frontend catalog loads")
	check(art.splash_aftermath_art.entries.size()==3 and not art.information_art.catalog.is_empty(),"ending and information families available")
	art.set_hud_style("tactical")
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture))
	var samples:=0
	for entry in data.samples:
		if entry.label not in ["second-title","second-briefing","debrief","second-motor-pool"]: continue
		var source:=Image.load_from_file(fixture.get_base_dir().path_join(entry.image));source.convert(Image.FORMAT_RGB8)
		var bytes:=source.get_data();var packet: Dictionary=entry.presentation.duplicate(true)
		original.texture=ImageTexture.create_from_image(source)
		check(art.set_frame(source,entry.program,entry.presentation),"source frontend restores: "+entry.label)
		if entry.label=="second-title":
			check(art.panels.active,"scalable title chrome")
			check(art.flow_typography.runs.size()==1 and art.flow_typography.runs[0].text=="THE MOSSEL DEFENSE","verified glyph fragments form one fitted heading")
			var changed:=source.duplicate();changed.set_pixel(56,76,Color.MAGENTA)
			check(not art.panels.set_frame(changed,entry.program),"overwritten title border rejected")
			art.panels.set_frame(source,entry.program)
			changed=source.duplicate();changed.set_pixel(112,98,Color.RED)
			var mask: Image=art._decode_l8("ui",entry.presentation.ui_overlay.mask_png)
			art.flow_typography.set_frame(changed,mask,entry.presentation)
			check(art.panels.title_mask(changed,mask,art.flow_typography.runs)==mask,"unknown interior mark cannot grant title spacing")
			art.set_frame(source,entry.program,entry.presentation)
		if entry.label=="debrief":
			check(not art.map_art.active.is_empty() and art.contours.visible,"FRAME and contents render independently")
			check(art.flow_typography.runs.size()>10 and art.flow_typography.labels[0].tactical,"Tactical mission summary typeface")
		if entry.label=="second-briefing":check(art.active.get("scene")=="office" and art.typography.labels[0].tactical,"Wilson and dialogue upgraded together")
		if entry.label=="second-motor-pool":check(art.active.get("scene")=="motor_pool","motor pool loads without ROM")
		check(source.get_data()==bytes and entry.presentation==packet,"source and observer remain untouched: "+entry.label)
		if native: await snap(entry.label)
		if entry.label=="debrief":
			art.text_enabled=false
			art.set_frame(source,entry.program,entry.presentation)
			check(art.flow_typography.runs.is_empty() and art.contours.visible,"original-text option keeps map upgrade and bitmap text")
			art.text_enabled=true
		samples+=1
	check(samples==4,"all screenshot-related frontend states exercised")
	# Surface ownership: a small unknown mark and an explicit text box survive.
	var map:=Image.create_empty(320,200,false,Image.FORMAT_RGB8);map.fill(Color8(170,170,170))
	for y in 166:
		for x in range(10,160+y/4):map.set_pixel(x,y+10,Color8(170,85,0))
	map.set_pixel(200,50,Color.RED)
	var box:=Rect2i(60,60,40,8)
	art.contours.set_frame(map,[box],null)
	var surface:Image=art.contours.surface
	check(surface.get_pixel(190,40).a==0.0,"unknown one-cell mark is protected")
	check(surface.get_pixel(50,50).a==0.0 and surface.get_pixel(20,20).a==1.0,"verified text box protected, map surfaces eligible")
	if native:
		art.clear();art._show(map);art.show();art.contours.set_frame(map,[box],null);art.contours.fit_to(display.size)
		original.texture=ImageTexture.create_from_image(map)
		var rendered:=await snap("source-map-contours")
		check(rendered.get_pixel(200*4+1,50*4+1).r>0.9 and rendered.get_pixel(200*4+1,50*4+1).g<0.1,"unknown red mark retains its exact footprint")

	# Native smoke must alter the accepted smoke while the tank and ground stay fixed.
	var ending=art.splash_aftermath_art
	for row in ending.entries.values():
		if row.name=="publisher":continue
		var source:=Image.load_from_file(directory.path_join(row.expected_path));source.convert(Image.FORMAT_RGB8)
		check(art.set_frame(source,{"name":row.program}),row.name+" PC ending dispatch")
		original.texture=ImageTexture.create_from_image(source)
		ending.reset_motion()
		var still: Image
		if native:still=await snap(row.name+"-still")
		for i in 30:check(ending.advance(0.1),row.name+" ambient phase advances")
		if native:
			var moving:=await snap(row.name+"-smoke")
			var changed:=0;var protected_changed:=0
			for y in moving.get_height():
				for x in moving.get_width():
					if moving.get_pixel(x,y)==still.get_pixel(x,y):continue
					changed+=1
					if y>=int(moving.get_height()*(0.57 if row.name=="scene1" else 0.66)):protected_changed+=1
			check(changed>100 and protected_changed==0,row.name+" smoke moves, hull/terrain remain exact")
		ending.motion_enabled=false
		var phase:float=ending.smoke_phase
		check(not ending.advance(1.0) and phase==ending.smoke_phase,row.name+" reduced-motion holds")
		ending.motion_enabled=true
		var changed:=source.duplicate();changed.set_pixel(0,0,Color.MAGENTA)
		check(not ending.set_frame(changed,{"name":row.program}) and not ending.advance(0.1),row.name+" unknown slide stops motion")
	var tandem:=Tandem.new();root.add_child(tandem)
	var black:=Image.create_empty(320,200,false,Image.FORMAT_RGB8)
	tandem.set_frame(black,{},null,{"name":"BRIEF"})
	for mode in ["ega","ega_upscaled","genesis"]:
		tandem.graphics_mode=mode
		check(not tandem.present_frontend({"name":"BRIEF"}),mode+" retains original frontend")
	tandem.queue_free()
	for error in errors:printerr("FAIL: "+error)
	print("PC_FRONTEND_COMPLETENESS: %d checks, %d errors"%[checks,errors.size()])
	var file:=FileAccess.open(out.path_join("report.json"),FileAccess.WRITE) if native else null
	if file:file.store_string(JSON.stringify({"checks":checks,"errors":errors},"  ")+"\n")
	quit(0 if errors.is_empty() else 1)
