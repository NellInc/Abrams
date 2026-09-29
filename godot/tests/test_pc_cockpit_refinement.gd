extends SceneTree
const Frame = preload("res://scripts/pc_tandem_frame.gd")
const Edges = preload("res://scripts/pc_cockpit_edges.gd")
const Instruments = preload("res://scripts/pc_instrument_art.gd")
var checks := 0
var errors: Array[String] = []
var view: SubViewport
var deadline := 0
func check(ok:bool,why:String)->void:
	checks+=1
	if not ok and errors.size()<20:errors.append(why)
func _initialize()->void:
	deadline=Time.get_ticks_msec()+180000
	run.call_deferred()
func _process(_delta:float)->bool:
	if Time.get_ticks_msec()>deadline:printerr("FAIL: cockpit refinement deadline");quit(2)
	return false
func snap()->Image:
	await process_frame
	RenderingServer.force_draw(false);RenderingServer.force_sync()
	return view.get_texture().get_image()
func run()->void:
	var repo:=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args:=OS.get_cmdline_user_args()
	var native:= "--native" in args
	var output:=repo.path_join("artifacts/cockpit-refinement-20260929/refinement")
	if "--output" in args:output=args[args.find("--output")+1]
	DirAccess.make_dir_recursive_absolute(output)
	var base:=repo.path_join("artifacts/pc-live-type-cockpit-02")
	var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base.path_join("report.json")))
	view=SubViewport.new();view.size=Vector2i(1280,960);view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var frame=Frame.new();view.add_child(frame);frame.size=view.size
	check(frame.load_genesis_art(repo),"pinned donors load")
	check(frame.load_graphics_sources(repo),"mode sources load")
	check(frame.typography.load_sources(repo.path_join("GAME")),"original outline fonts load")
	# Commander static illustrations, with per-cell rejection of one changed bit.
	var original:Image=frame.instrument_art.plates[2]
	var owned:=Image.create_empty(320,200,false,Image.FORMAT_L8);owned.fill(Color.WHITE)
	var ids:=Image.create_empty(320,200,false,Image.FORMAT_L8);ids.fill(Color(2.0/255,0,0))
	frame.instrument_art.set_frame(original,owned,ids)
	check(frame.instrument_art.active.size()==5,"all five static commander cells qualify")
	for cell in Instruments.COMMANDER_CELLS:
		for fault in ["rgb","ui","tag"]:
			var source:=original.duplicate();var ui:=owned.duplicate();var tags:=ids.duplicate()
			if fault=="rgb":source.set_pixelv(cell.source.position,Color.MAGENTA)
			elif fault=="ui":ui.set_pixelv(cell.source.position,Color.BLACK)
			else:tags.set_pixelv(cell.source.position,Color.BLACK)
			frame.instrument_art.set_frame(source,ui,tags)
			check(frame.instrument_art.active.size()==4 and not frame.instrument_art.active.any(func(c):return c.name==cell.name),"whole static cell rejects "+cell.name+" "+fault)
	var driver:Image=frame.instrument_art.plates[4]
	ids.fill(Color(4.0/255,0,0))
	frame.instrument_art.set_frame(driver,owned,ids)
	check(frame.instrument_art.active.size()==2,"both original driver fasteners qualify")
	for cell in Instruments.DRIVER_FASTENERS:
		var changed:=driver.duplicate();changed.set_pixelv(cell.source.position,Color.MAGENTA)
		frame.instrument_art.set_frame(changed,owned,ids)
		check(frame.instrument_art.active.size()==1,"changed driver screw stays original")
	var timings:=[]
	for entry:Dictionary in report.ui_presentations:
		var source:=Image.load_from_file(base.path_join(entry.image))
		var ui:=Image.load_from_file(base.path_join(entry.mask))
		var tags:=Image.load_from_file(base.path_join(entry.plate_mask))
		var packet:Dictionary=report.presentations[int(entry.frame_index)].duplicate(true)
		packet.draw_pass=report.render_passes.filter(func(p):return p.sequence==entry.draw_sequence)[0]
		packet.ui_overlay.mask_png=Marshalls.raw_to_base64(ui.save_png_to_buffer())
		packet.plate_overlay.mask_png=Marshalls.raw_to_base64(tags.save_png_to_buffer())
		var c:Array=packet.draw_pass.camera.clip
		var camera:=Rect2i(c[0],c[1],c[2]-c[0]+1,c[3]-c[1]+1)
		var world:=ImageTexture.create_from_image(source.get_region(camera))
		frame.graphics_mode="modern"
		check(frame.set_frame(source,packet,world),"paired transition "+entry.stage)
		if entry.stage not in ["cupola-settled","driver-settled","commander-settled","gunner-settled","damage-settled"]:continue
		if native:(await snap()).save_png(output.path_join(entry.stage+".png"))
		if entry.stage not in ["cupola-settled","driver-settled"]:
			check(not frame.cockpit_edges.active,"no stale edges on "+entry.stage);continue
		var edge=frame.cockpit_edges
		check(edge.active,"settled outline active "+entry.stage)
		var station:=3 if entry.stage=="cupola-settled" else 4
		var assembly:Image=frame._current_driver_mask
		var donor:Texture2D=frame.cockpit_art_textures[station]
		var rail:bool=frame.material.get_shader_parameter("cupola_rail_verified")
		var builds:int=edge.build_count
		var start:=Time.get_ticks_usec()
		for i in 30:edge.set_frame(ui,tags,camera,donor,assembly,station,true,rail,world)
		var cost:float=(Time.get_ticks_usec()-start)/30000.0
		timings.append({"station":station,"cached_ms":cost,"profiles":edge.profiles.duplicate(true)})
		check(edge.build_count==builds,"station mesh reused on stable frames")
		check(cost<30,"bounded cached outline CPU time")
		if native:
			var result:=await snap();edge.hide();var before:=await snap();edge.show()
			before.save_png(output.path_join(entry.stage+"-before.png"))
			var changed:=0;var escaped:=0;var unowned:=0
			for y in view.size.y:
				for x in view.size.x:
					if result.get_pixel(x,y)==before.get_pixel(x,y):continue
					changed+=1
					var p:=Vector2((x+0.5)/4.0,(y+0.5)/4.8)
					var near:=false
					for profile:Dictionary in edge.profiles:
						var points:PackedVector2Array=profile.points
						for i in range(points.size()-1):
							if p.x<points[i].x or p.x>points[i+1].x:continue
							var line:=lerpf(points[i].y,points[i+1].y,(p.x-points[i].x)/(points[i+1].x-points[i].x))
							if absf(p.y-line)<=1.66:near=true
					if not near or not camera.has_point(Vector2i(p)):escaped+=1
					var q:=Vector2i(p)
					if ui.get_pixelv(q).r>0.5 and roundi(tags.get_pixelv(q).r*255)!=station:
						var owned_rail:bool=station==3 and rail and q.y>=111 and q.y<117 and q.x>=159 and q.x<[183,206,230,242,264,286][q.y-111]
						var owned_roof:bool=assembly!=null and assembly.get_pixelv(q).b==1.0
						if not owned_rail and not owned_roof:unowned+=1
			check(changed>100,"actual contour refinement "+entry.stage)
			check(escaped==0 and unowned==0,"every change confined to verified narrow silhouette")
			# Isolate this layer and poison all world texels under original UI.
			# Any hidden scenery sampling would now alter its rendered bytes.
			frame.hide()
			var isolated=Edges.new();isolated.size=view.size;view.add_child(isolated)
			isolated.set_frame(ui,tags,camera,donor,assembly,station,true,rail,world)
			var clean:=await snap()
			var poison:=source.get_region(camera)
			for y in camera.size.y:
				for x in camera.size.x:
					if ui.get_pixel(x+camera.position.x,y+camera.position.y).r>0.5:poison.set_pixel(x,y,Color.MAGENTA)
			isolated.set_frame(ui,tags,camera,donor,assembly,station,true,rail,ImageTexture.create_from_image(poison))
			var guarded:=await snap()
			check(clean.get_data()==guarded.get_data(),"hidden scenery sentinel cannot affect any edge fragment")
			isolated.queue_free();await process_frame;frame.show()
		for fault in ["mixed","unknown","partial","camera","world","assembly"]:
			var bad:=tags.duplicate();var cam:=camera;var scene:=world;var roof:=assembly
			if fault=="mixed":bad.set_pixel(0,199,Color(1.0/255,0,0))
			elif fault=="unknown":bad.set_pixel(180,180,Color(99.0/255,0,0))
			elif fault=="partial":bad.set_pixel(319,199,Color.BLACK)
			elif fault=="camera":cam.size.y-=1
			elif fault=="world":scene=null
			else:roof=Image.create_empty(10,10,false,Image.FORMAT_RGB8)
			edge.set_frame(ui,bad,cam,donor,roof,station,true,rail,scene)
			check(not edge.active and not edge.visible,"outline rejects "+fault)
		check(frame.set_frame(source,packet,world) and edge.active,"valid outline restores")
		frame.graphics_mode="upscaled";frame.set_frame(source,packet,world)
		check(edge.active and not edge.material.get_shader_parameter("modern"),"Upscaled restores original donor palette")
		for mode in ["ega","genesis"]:
			frame.graphics_mode=mode;frame.set_frame(source,packet,world)
			check(not edge.active and not edge.visible and not frame.commander_trim.active,"original mode clears all new trim "+mode)
	await moving_roofs(frame,repo,native,output)
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors,"native":native,"timings":timings},"  "))
	for e in errors:printerr("FAIL: "+e)
	print("PC_COCKPIT_REFINEMENT: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)

func moving_roofs(frame:TextureRect,repo:String,native:bool,output:String)->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(repo.path_join("artifacts/finish-20260928/cursor-struts/coverage-fixtures.json")))
	frame.graphics_mode="modern"
	for row:Dictionary in fixture.samples:
		if row.donor!=4:continue
		var source:=Image.load_from_file(repo.path_join(row.source_path))
		var packet:Dictionary=row.packet
		var world:=ImageTexture.create_from_image(source.get_region(Rect2i(0,0,320,136)))
		check(frame.set_frame(source,packet,world),"moving original roof accepted "+row.name)
		var edge:Control=frame.cockpit_edges
		check(edge.active and edge.profiles.size()==2,"both driver contours active "+row.name)
		if not edge.active:continue
		var expected:=Image.new();expected.load_png_from_buffer(Marshalls.base64_to_raw(packet.driver_overlay.mask_png))
		check(edge.material.get_shader_parameter("driver_mask").get_image().get_data()==expected.get_data(),"signed original offsets passed unchanged "+row.name)
		var tags:Image=frame._current_plate_mask
		var registered:=true
		var top:PackedVector2Array=edge.profiles[0].points
		for x in 320:
			var height:=0.0
			for y in 77:
				if roundi(tags.get_pixel(x,y).r*255)==4 or expected.get_pixel(x,y).b==1.0:height=y+1
			for i in range(top.size()-1):
				if x+0.5<top[i].x or x+0.5>top[i+1].x:continue
				var value:=lerpf(top[i].y,top[i+1].y,(x+0.5-top[i].x)/(top[i+1].x-top[i].x))
				if absf(value-height)>0.98001:registered=false
		check(registered,"every column follows source moving silhouette "+row.name)
		if native:(await snap()).save_png(output.path_join(row.name+".png"))
