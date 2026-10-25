extends SceneTree
const Dynamics=preload("res://scripts/pc_tactical_dynamics.gd")
const Frame=preload("res://scripts/pc_tandem_frame.gd")
const Effects=preload("res://scripts/pc_tactical_effects.gd")
const Modern=preload("res://scripts/pc_modern_assets.gd")
const Camera=preload("res://scripts/pc_camera.gd")
var checks:=0
var errors:Array[String]=[]
var output:="user://tactical-dynamics"
var images:Dictionary={}
var baseline_shader:Shader

class ImpactArt extends RefCounted:
	func mapping(object:Dictionary,_frame:Dictionary,_palette:Array) -> Dictionary:
		return {"donor":object.donor,"index":15,"target":Rect2(120,70,80,60),"rect":Rect2(120,70,80,60)}

func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:errors.append(label);printerr("FAIL: "+label)

func shot(id:int,frame:int,enabled:bool=true) -> Dictionary:
	return {"id":id,"frame":frame,"epoch":1,"kind":"sound","sample":"cannon","ip":0x9107,"return_ip":0x33c4,"value":1,"enabled":enabled}

func sample(frame:int,id:int=0,events:Array=[]) -> Dictionary:
	return {"program":{"name":"SIM"},"render_epoch":1,"state":{"station":"driver","speed_display":0,"world_position_raw":[1000,2000,0]},
		"audio":{"schema":3,"epoch":1,"frame":frame,"last_id":id,"active":true,"enabled":true,"events":events}}

func contracts() -> void:
	var d:=Dynamics.new();var initial:=sample(10)
	var original:=JSON.stringify(initial);d.observe(initial,true)
	check(d.shift==Vector2.ZERO and d.shots==0,"neutral first sample")
	var muted:=sample(11,1,[shot(1,11,false)]);muted.audio.enabled=false
	var source:=JSON.stringify(muted);d.observe(muted,true)
	check(d.shots==1 and d.advance(1.0/60.0) and d.shift.y>0.0,"muted accepted shot produces recoil")
	check(JSON.stringify(muted)==source and JSON.stringify(initial)==original,"source packets unchanged")
	var maximum:=0.0
	for i in 150:
		d.advance(1.0/60.0);maximum=maxf(maximum,absf(d.shift.y))
		check(d.shift.is_finite() and absf(d.shift.y)<=Dynamics.MAX_SHIFT.y and absf(d.shift.x)<=Dynamics.MAX_SHIFT.x,"bounded finite spring")
	check(maximum>0.3 and d.shift==Vector2.ZERO,"visible kick settles to exact neutral")
	d.observe(sample(12,1,[shot(1,11)]),true)
	check(d.shots==1 and d.velocity==Vector2.ZERO,"duplicate event never repeats")
	var rejected:=shot(2,13);rejected.return_ip=0x9999
	d.observe(sample(13,2,[rejected]),true)
	d.observe(sample(30,3,[shot(3,14)]),true)
	check(d.shots==1,"unqualified and stale events cannot produce recoil")
	var driven:=sample(31,3);driven.state.speed_display=15;driven.state.world_position_raw[0]+=20
	d.observe(driven,true);d.advance(0.016)
	check(d.shift!=Vector2.ZERO and d.target!=Vector2.ZERO,"source driving excites own suspension response")
	var held:=d.shift
	check(not d.advance(0.05,false) and d.shift==held,"focus and menu freeze without clock catch-up")
	var gate:={"id":4,"frame":32,"epoch":1,"kind":"gate","return_ip":0x4080,"enabled":false}
	d.observe(sample(32,4,[gate]),true);held=d.shift
	check(d.paused and not d.advance(0.05) and d.shift==held,"original pause freezes response")
	gate=gate.duplicate();gate.id=5;gate.frame=33;gate.return_ip=0x4092;gate.enabled=true
	d.observe(sample(33,5,[gate]),true)
	check(not d.paused,"original resume releases freeze")
	var restored:=sample(34,5,[shot(5,34)]);restored.timeline_reset=true
	d.observe(restored,true)
	check(d.shift==Vector2.ZERO and d.shots==1,"load/save timeline reset cannot replay recoil")
	d.observe(sample(35,6,[shot(6,35)]),false)
	d.observe(sample(36,6,[shot(6,35)]),true)
	check(d.shots==1 and d.shift==Vector2.ZERO,"mode re-entry cannot replay a disabled-mode shot")
	d.observe(sample(37,7,[shot(7,37)]),true);d.advance(0.016)
	var changed_station:=sample(38,7);changed_station.state.station="cupola"
	d.observe(changed_station,true)
	check(d.shift==Vector2.ZERO,"station switch discards old impulse")
	var teleport:=sample(39,7);teleport.state.station="cupola";teleport.state.world_position_raw=[8000,9000,0]
	d.observe(teleport,true)
	check(d.target==Vector2.ZERO and d.shift==Vector2.ZERO,"teleport creates no suspension impulse")
	check(not d.advance(NAN) and not d.advance(INF) and not d.advance(-1.0),"invalid deltas cannot advance")
	d.reduced_motion=true;d.observe(sample(40,8,[shot(8,40)]),true)
	check(not d.enabled and d.shift==Vector2.ZERO,"reduced motion retains static presentation")
	d.reset();d.reduced_motion=false;d.observe(sample(50),true)
	var turn:=sample(51);turn.state.heading_degrees=180;d.observe(turn,true)
	check(not d.advance(0.05) and d.shift==Vector2.ZERO,"camera/heading alone cannot excite suspension")

func snapshot(view:SubViewport) -> Image:
	await process_frame
	RenderingServer.force_draw(false);RenderingServer.force_sync()
	return view.get_texture().get_image()

func save_image(label:String,image:Image) -> void:
	image.save_png(output.path_join(label+".png"))
	images[label]=Marshalls.raw_to_base64(image.save_png_to_buffer())

func armour_gpu() -> void:
	var view:=SubViewport.new();view.size=Vector2i(640,400);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var frame:=Frame.new();frame.size=Vector2(640,400);view.add_child(frame)
	frame.graphics_mode="tactical";frame.world_enabled=true
	var ui:=Image.create(320,200,false,Image.FORMAT_L8);ui.fill(Color.BLACK);ui.fill_rect(Rect2i(0,108,320,92),Color.WHITE)
	var plates:=Image.create(320,200,false,Image.FORMAT_L8);plates.fill(Color.BLACK);plates.fill_rect(Rect2i(0,108,320,92),Color(3.0/255.0,0,0))
	plates.fill_rect(Rect2i(100,150,80,40),Color.BLACK)
	var assembly:=Image.create(320,200,false,Image.FORMAT_RGB8);assembly.fill(Color.BLACK)
	var donor:=Image.create(1600,1000,false,Image.FORMAT_RGBA8)
	for y in donor.get_height():
		for x in donor.get_width():donor.set_pixel(x,y,Color(0.25+float(x%17)/34.0,0.3+float(y%19)/38.0,0.22,1))
	var src:=Image.create(320,200,false,Image.FORMAT_RGB8);src.fill(Color(0.12,0.22,0.33));frame.texture=ImageTexture.create_from_image(src)
	var material:ShaderMaterial=frame._upscaled_material
	for pair in [["ui_mask",ImageTexture.create_from_image(ui)],["plate_mask",ImageTexture.create_from_image(plates)],["driver_assembly_mask",ImageTexture.create_from_image(assembly)],["cupola_art",ImageTexture.create_from_image(donor)],["driver_art",ImageTexture.create_from_image(donor)],["world_texture",frame.texture],["camera_rect",Vector4(0,0,320,108)],["station_art_enabled",Vector3(0,1,0)],["genesis_art",true],["world_enabled",true],["modern_armour_palette",true],["tactical_armour",true]]:
		material.set_shader_parameter(pair[0],pair[1])
	var neutral:=await snapshot(view)
	if baseline_shader:
		var candidate:Shader=material.shader;material.shader=baseline_shader
		check((await snapshot(view)).get_data()==neutral.get_data(),"neutral cupola matches predecessor shader exactly")
		material.shader=candidate
	view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	frame.set_tactical_dynamics(Vector2(0.2,0.9))
	check(view.render_target_update_mode==SubViewport.UPDATE_ONCE,"armour uniform wakes the retained compositor")
	var moving:=await snapshot(view)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	var changed:=0;var outside:=0
	for y in neutral.get_height():
		for x in neutral.get_width():
			if neutral.get_pixel(x,y)!=moving.get_pixel(x,y):
				changed+=1
				if roundi(plates.get_pixel(x/2,y/2).r*255.0)!=3:outside+=1
	check(changed>100 and outside==0,"native/Web rendered recoil is confined to armour, world and instruments exact")
	frame.set_tactical_dynamics(Vector2.ZERO)
	check(view.render_target_update_mode==SubViewport.UPDATE_ALWAYS,"continuous compositor retains its rendering policy")
	check((await snapshot(view)).get_data()==neutral.get_data(),"exact neutral restoration")
	# Real cannon fire is accepted at Gunner. Animate its upper housing only.
	plates.fill(Color(1.0/255.0,0,0));material.set_shader_parameter("plate_mask",ImageTexture.create_from_image(plates))
	ui.fill(Color.WHITE);material.set_shader_parameter("ui_mask",ImageTexture.create_from_image(ui))
	material.set_shader_parameter("gunner_art_enabled",true);material.set_shader_parameter("gunner_art",ImageTexture.create_from_image(donor))
	material.set_shader_parameter("station_art_enabled",Vector3.ZERO);material.set_shader_parameter("camera_rect",Vector4(32,13,256,97))
	frame.set_tactical_dynamics(Vector2.ZERO);var gunner_neutral:=await snapshot(view)
	if baseline_shader:
		var candidate:Shader=material.shader;material.shader=baseline_shader
		check((await snapshot(view)).get_data()==gunner_neutral.get_data(),"neutral gunner matches predecessor exactly")
		material.shader=candidate
	frame.set_tactical_dynamics(Vector2(0.2,0.9));var gunner_moving:=await snapshot(view)
	check(gunner_neutral.get_data()!=gunner_moving.get_data(),"accepted-shot Gunner housing response renders")
	check(gunner_neutral.get_region(Rect2i(64,26,512,194)).get_data()==gunner_moving.get_region(Rect2i(64,26,512,194)).get_data(),"gunner world aperture and sight exact")
	check(gunner_neutral.get_region(Rect2i(0,246,640,154)).get_data()==gunner_moving.get_region(Rect2i(0,246,640,154)).get_data(),"entire lower gunner instrument panel exact")
	var screws_exact:=true
	for centre:Vector2 in [Vector2(85,27),Vector2(1500,27),Vector2(18,392),Vector2(1567,392),Vector2(98,560),Vector2(1487,560)]:
		var c:=centre/Vector2(1586,992)*Vector2(320,200)
		var y:float=c.y*13.0/15.0 if c.y<15.0 else (13.0+(c.y-15.0)*97.0/96.0 if c.y<111.0 else 110.0+(c.y-111.0)*13.0/7.0)
		var box:=Rect2i(Vector2i(c.x*2-1,y*2-1),Vector2i(2,2))
		screws_exact=screws_exact and gunner_neutral.get_region(box).get_data()==gunner_moving.get_region(box).get_data()
	check(screws_exact,"gunner fastener cores remain destination-registered")
	save_image("gunner-neutral",gunner_neutral);save_image("gunner-response",gunner_moving)
	frame.set_tactical_dynamics(Vector2.ZERO)
	for mode in ["ega","ega_upscaled","genesis","upscaled","modern"]:
		frame.graphics_mode=mode;material.set_shader_parameter("tactical_armour",false)
		material.set_shader_parameter("modern_armour_palette",mode=="modern")
		material.set_shader_parameter("ega_upscaled",mode=="ega_upscaled")
		frame.set_tactical_dynamics(Vector2(0.3,1.25))
		check(material.get_shader_parameter("tactical_armour_shift")==Vector2.ZERO,mode+": dynamics forces neutral uniform")
		if baseline_shader:
			var mode_image:=await snapshot(view);var candidate:Shader=material.shader;material.shader=baseline_shader
			check((await snapshot(view)).get_data()==mode_image.get_data(),mode+": compositor predecessor pixels exact")
			material.shader=candidate
	material.set_shader_parameter("ega_upscaled",false);material.set_shader_parameter("modern_armour_palette",true)
	material.set_shader_parameter("gunner_art_enabled",false);material.set_shader_parameter("camera_rect",Vector4(0,0,320,108))
	material.set_shader_parameter("station_art_enabled",Vector3(0,0,1))
	# Driver assembly seams and original instruments must remain fixed too.
	plates.fill_rect(Rect2i(0,108,320,92),Color(4.0/255.0,0,0));plates.fill_rect(Rect2i(100,150,80,40),Color.BLACK)
	assembly.fill_rect(Rect2i(140,108,40,35),Color(1.0/255.0,64.0/255.0,1.0))
	material.set_shader_parameter("plate_mask",ImageTexture.create_from_image(plates));material.set_shader_parameter("driver_assembly_mask",ImageTexture.create_from_image(assembly))
	material.set_shader_parameter("driver_assembly_enabled",true);material.set_shader_parameter("station_art_enabled",Vector3(0,0,1));material.set_shader_parameter("tactical_armour",true)
	frame.graphics_mode="tactical";frame.set_tactical_dynamics(Vector2.ZERO)
	var driver_neutral:=await snapshot(view)
	if baseline_shader:
		var candidate:Shader=material.shader;material.shader=baseline_shader
		check((await snapshot(view)).get_data()==driver_neutral.get_data(),"neutral driver matches predecessor shader exactly")
		material.shader=candidate
	frame.set_tactical_dynamics(Vector2(0.2,0.9));var driver_moving:=await snapshot(view)
	check(driver_neutral.get_data()!=driver_moving.get_data(),"driver response renders")
	check(driver_neutral.get_region(Rect2i(106,374,428,26)).get_data()==driver_moving.get_region(Rect2i(106,374,428,26)).get_data(),"driver instrument strip exact")
	save_image("cupola-neutral",neutral);save_image("cupola-response",moving);save_image("driver-neutral",driver_neutral);save_image("driver-response",driver_moving)
	view.queue_free();await process_frame

func impacts_gpu() -> void:
	var view:=SubViewport.new();view.own_world_3d=true;view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var camera:=Camera3D.new();view.add_child(camera);camera.make_current()
	var frame:={"clip":[0,0,319,199],"center":[160,100],"focal_pixels":192,"near_raw":16,"matrix_q14_columns":[16384,0,0,0,16384,0,0,0,16384],"world_position_raw":[0,0,0]}
	view.size=Camera.apply(camera,frame,Vector3.ZERO)*2
	var effects:=Effects.new();camera.add_child(effects)
	var mask:=Image.create(view.size.x,view.size.y,false,Image.FORMAT_RGB8);mask.fill(Color(1.0/255.0,0,0));mask.fill_rect(Rect2i(300,145,10,75),Color(2.0/255.0,0,0))
	var ownership:=ImageTexture.create_from_image(mask)
	var packet:={"camera":frame,"palette_rgb":Modern.PC_PALETTE.duplicate(),"objects":[{"donor":0,"pointer":99,"polygons":[]}],"world":{}}
	for donor in [0,1,3,18]:
		packet.objects[0].donor=donor;effects.reset_dynamics()
		effects.prepare(packet,{"origin":Vector3.ZERO,"inverse":Basis.IDENTITY},ownership,Modern.new(),ImpactArt.new())
		var before:=await snapshot(view)
		var animated:=effects.advance_dynamics(0.05)
		var after:=await snapshot(view)
		if donor in [0,1]:
			effects.clear();effects.prepare(packet,{"origin":Vector3.ZERO,"inverse":Basis.IDENTITY},ownership,Modern.new(),ImpactArt.new())
			check(effects._impact_births.values()[0]==0.0,"moving-camera mesh rebuild cannot restart an impact burst")
		check(animated==(donor in [0,1]),"only registered impact donors animate")
		check((before.get_data()!=after.get_data())==(donor in [0,1]),"impact colour motion visible, other effects exact")
		var alpha_exact:=true
		for y in after.get_height():
			for x in after.get_width():
				if before.get_pixel(x,y).a!=after.get_pixel(x,y).a:alpha_exact=false
		check(alpha_exact,"ballistic spark alpha/coverage exact")
		check(before.get_region(Rect2i(300,145,10,75)).get_data()==after.get_region(Rect2i(300,145,10,75)).get_data(),"protected occluder exact")
		if donor==0:save_image("impact-neutral",before);save_image("impact-response",after)
		for tick in 14:effects.advance_dynamics(0.05)
		check(not effects.advance_dynamics(0.05),"spark burst terminates")
		packet.objects=[];effects.prepare(packet,{"origin":Vector3.ZERO,"inverse":Basis.IDENTITY},ownership,Modern.new(),ImpactArt.new())
		check(not effects.visible and not effects.advance_dynamics(0.05),"source disappearance removes impact immediately")
		packet.objects=[{"donor":0,"pointer":99,"polygons":[]}]
	view.queue_free();await process_frame

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if "--output" in args:output=args[args.find("--output")+1]
	DirAccess.make_dir_recursive_absolute(output)
	if "--baseline-shader" in args:
		baseline_shader=Shader.new();baseline_shader.code=FileAccess.get_file_as_string(args[args.find("--baseline-shader")+1])
	contracts()
	if "--gpu" in args or OS.has_feature("web"):
		var gpu:bool=DisplayServer.get_name()!="headless" and RenderingServer.get_current_rendering_method()=="gl_compatibility" and not RenderingServer.get_video_adapter_name().is_empty()
		check(gpu,"GPU verification requires real OpenGL/WebGL, never dummy rendering")
		if gpu:await armour_gpu();await impacts_gpu()
	print("PC_TACTICAL_DYNAMICS: %d checks, %d errors"%[checks,errors.size()])
	var report:={"checks":checks,"errors":errors,"backend":DisplayServer.get_name(),"web":OS.has_feature("web"),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"arguments":OS.get_cmdline_args()}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.dynamicsReport="+JSON.stringify(report)+";window.dynamicsImages="+JSON.stringify(images)+";window.dynamicsResult="+str(0 if errors.is_empty() else 1))
	quit(0 if errors.is_empty() else 1)
