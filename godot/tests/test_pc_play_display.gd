extends SceneTree
const Display = preload("res://scripts/pc_play_display.gd")
const PcCamera = preload("res://scripts/pc_camera.gd")
const DrawPass = preload("res://scripts/pc_draw_pass.gd")
const WorldView = preload("res://scripts/pc_world_view.gd")
var errors: Array[String] = []
var checks := 0
var pixels := 0
var max_projection_error := 0.0
var samples: Array = []
var outer: SubViewport
var display: Control
var camera: Camera3D
var native := false
var output := ""

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok and errors.size()<20: errors.append(reason)

func _initialize() -> void: run.call_deferred()

func snapshot() -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return outer.get_texture().get_image()

func resize(extent: Vector2i, frame: Dictionary) -> void:
	outer.size=extent
	display.size=extent
	display.set_camera_dimensions(PcCamera.apply(camera,frame,Vector3.ZERO))
	var rect: Rect2i=Display.fitted_rect(extent)
	check(Vector2i(display.display.position)==rect.position and Vector2i(display.display.size)==rect.size,"integer centred game rect")
	check(display.tandem_viewport.size==rect.size and Vector2i(display.tandem_frame.size)==rect.size,"native UI render target")
	var expected_scale: int=Display.world_scale(rect.size)
	check(display.world_viewport.size==display.source_dimensions*expected_scale,"isotropic original-camera render target")
	check(display.world_viewport.get_parent()==display.tandem_viewport,"world renders before composite")

func projection_contracts() -> void:
	var extents := [Vector2i(640,480),Vector2i(1440,900),Vector2i(1920,1080),Vector2i(3840,2160),Vector2i(1080,1920),Vector2i(1279,721)]
	for extent in extents:
		var rect: Rect2i=Display.fitted_rect(extent)
		check(rect.size.x*3==rect.size.y*4,"4:3 without cropping")
		check(Rect2i(Vector2i.ZERO,extent).encloses(rect),"all content inside window")
		check(absi(rect.position.x-(extent.x-rect.end.x))<=1 and absi(rect.position.y-(extent.y-rect.end.y))<=1,"balanced letterboxing")
		check(rect.size.x+4>extent.x or rect.size.y+3>extent.y,"largest integral 4:3 rectangle")
		var scale: int=Display.world_scale(rect.size)
		check(scale*320>=rect.size.x and scale*200>=rect.size.y,"world never undersamples either axis")
		for clip in [[32,13,287,109],[0,10,319,52],[0,0,319,116],[0,0,319,135]]:
			for focal in [128,256,512]:
				var frame := {"matrix_q14_columns":[16384,0,0,0,16384,0,0,0,16384],"world_position_raw":[0,0,0],
					"clip":clip,"center":[159,60],"near_raw":16,"focal_pixels":focal}
				resize(extent,frame)
				await process_frame
				for delta in [[0,4096,0],[1024,4096,512],[-1024,4096,-512],[300,2048,-125],[-400,3072,250]]:
					var point := Vector3(delta[0],delta[2],-delta[1])/WorldView.DISPLAY_SCALE
					var actual := camera.unproject_position(point)/float(scale)
					var expected := Vector2(159+float(delta[0])*focal/delta[1]-clip[0],60-float(delta[2])*focal/delta[1]-clip[1])
					var error := actual.distance_to(expected)
					max_projection_error=maxf(max_projection_error,error)
					check(error<0.001,"unchanged projection %s clip=%s focal=%d error=%f"%[extent,clip,focal,error])
	for value in ["640x480","1440x900","1920x1080","3840x2160"]:
		check(Display.parse_extent(value)!=Vector2i.ZERO,"valid window size")
	for value in ["","1920","0x0","-1x1000","NaNx480","640x479","16385x480","1280x960x1"]:
		check(Display.parse_extent(value)==Vector2i.ZERO,"invalid window size rejected: "+value)

func boundary_contracts() -> void:
	var source := Image.create_empty(320,200,false,Image.FORMAT_RGB8)
	source.fill(Color.GREEN)
	source.set_pixel(1,0,Color.BLUE)
	var mask := Image.create_empty(320,200,false,Image.FORMAT_L8)
	mask.fill(Color.WHITE)
	# x=4 at 1440 pixels lands exactly on original x=1. Only x=0/1 qualify.
	var p := Vector2(1.0,0.5*200.0/1080.0)
	check(boundary_match(Color.GREEN,p,Vector2i(4,0),Vector2i(1440,1080),source,mask,Rect2i(),null),"boundary accepts lower adjacent texel")
	check(boundary_match(Color.BLUE,p,Vector2i(4,0),Vector2i(1440,1080),source,mask,Rect2i(),null),"boundary accepts upper adjacent texel")
	check(not boundary_match(Color.MAGENTA,p,Vector2i(4,0),Vector2i(1440,1080),source,mask,Rect2i(),null),"boundary rejects unrelated colour")
	check(not boundary_match(Color.BLUE,Vector2(0.5,0.5),Vector2i(0,0),Vector2i(320,200),source,mask,Rect2i(),null),"non-boundary rejects adjacent texel")

func boundary_match(actual: Color, p: Vector2, at: Vector2i, extent: Vector2i, source: Image, mask: Image, clip: Rect2i, world: Image) -> bool:
	# Exact rational boundary detection avoids float32 loss at wide textures.
	# Nearest sampling may choose either adjacent texel at a tie, but nothing
	# else: no colour tolerance or arbitrary nearby-pixel allowance is accepted.
	var nx := (2*at.x+1)*320
	var ny := (2*at.y+1)*200
	var bx := nx % (2*extent.x)==0
	var by := ny % (2*extent.y)==0
	if world!=null:
		bx=bx or ((nx-2*extent.x*clip.position.x)*world.get_width()) % (2*extent.x*clip.size.x)==0
		by=by or ((ny-2*extent.y*clip.position.y)*world.get_height()) % (2*extent.y*clip.size.y)==0
	if not bx and not by: return false
	var xs := [-0.0001,0.0001] if bx else [0.0]
	var ys := [-0.0001,0.0001] if by else [0.0]
	for dy in ys:
		for dx in xs:
			var q := p+Vector2(dx,dy)
			var original := Vector2i(q.floor())
			if not Rect2i(0,0,320,200).has_point(original): continue
			var expected := source.get_pixelv(original)
			if world!=null and clip.has_point(original) and mask.get_pixelv(original).r<0.5:
				var sample := Vector2i(((q-Vector2(clip.position))*Vector2(world.get_size())/Vector2(clip.size)).floor())
				expected=world.get_pixelv(sample)
			if actual.to_rgba32()==expected.to_rgba32(): return true
	return false

func compare(image: Image, source: Image, mask: Image, clip: Rect2i, world: Image, label: String) -> void:
	var rect: Rect2i=Display.fitted_rect(image.get_size())
	var mismatch := 0
	var bars := 0
	var tie_matches := 0
	for y in image.get_height():
		for x in image.get_width():
			var expected := Color.BLACK
			var p := Vector2.ZERO
			if rect.has_point(Vector2i(x,y)):
				p = (Vector2(x-rect.position.x,y-rect.position.y)+Vector2(0.5,0.5))*Vector2(320,200)/Vector2(rect.size)
				var original := Vector2i(p.floor())
				expected=source.get_pixelv(original)
				if world!=null and clip.has_point(original) and mask.get_pixelv(original).r<0.5:
					var uv := (p-Vector2(clip.position))/Vector2(clip.size)
					var w := Vector2i((uv*Vector2(world.get_size())).floor())
					expected=world.get_pixelv(w)
			else: bars+=1
			var actual := image.get_pixel(x,y)
			if expected.to_rgba32()!=actual.to_rgba32():
				if rect.has_point(Vector2i(x,y)) and boundary_match(actual,p,Vector2i(x,y)-rect.position,rect.size,source,mask,clip,world): tie_matches+=1
				else:
					if mismatch<4: print("PIXEL_MISMATCH %s at=%s p=%s actual=%s expected=%s"%[label,Vector2i(x,y),p,actual,expected])
					mismatch+=1
			pixels+=1
	check(mismatch==0,"first-render composition %s: %d wrong pixels"%[label,mismatch])
	samples.append({"name":label,"size":[image.get_width(),image.get_height()],"mismatches":mismatch,"letterbox_pixels":bars,"texel_boundary_alternatives":tie_matches,"display":display.description()})

func native_contracts(fixture: String) -> void:
	var source := Image.create_empty(320,200,false,Image.FORMAT_RGB8)
	var mask := Image.create_empty(320,200,false,Image.FORMAT_L8)
	for y in 200:
		for x in 320:
			source.set_pixel(x,y,Color8(x%256,y%256,(x+y)%256))
			mask.set_pixel(x,y,Color.WHITE if x%7==0 else Color.BLACK)
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	display.world_viewport.add_child(environment)
	var index := 0
	for extent in [Vector2i(1280,960),Vector2i(1920,1080),Vector2i(1279,721),Vector2i(960,1280),Vector2i(640,480)]:
		var clip: Array=[[32,13,287,109],[0,10,319,52],[0,0,319,116],[0,0,319,135],[32,13,287,109]][index]
		var camera_frame := {"matrix_q14_columns":[16384,0,0,0,16384,0,0,0,16384],"world_position_raw":[0,0,0],
			"clip":clip,"center":[159,60],"near_raw":16,"focal_pixels":128}
		var color: Color=[Color.RED,Color.GREEN,Color.BLUE,Color.CYAN,Color.MAGENTA][index]
		environment.environment.background_color=color
		resize(extent,camera_frame)
		var presentation := {"draw_pass":{"camera":camera_frame},"ui_overlay":{"width":320,"height":200,"mask_png":Marshalls.raw_to_base64(mask.save_png_to_buffer())}}
		check(display.tandem_frame.set_frame(source,presentation,display.world_viewport.get_texture()),"synthetic frame accepted")
		var image := await snapshot()
		var world: Image=display.world_viewport.get_texture().get_image()
		check(world.get_pixel(0,0).to_rgba32()==color.to_rgba32(),"first resized world is current colour")
		compare(image,source,mask,Rect2i(clip[0],clip[1],clip[2]-clip[0]+1,clip[3]-clip[1]+1),world,"resize-%d"%index)
		check(not display.tandem_frame.set_frame(source,{},null),"unsupported frame falls back")
		image=await snapshot()
		compare(image,source,mask,Rect2i(),null,"fallback-%d"%index)
		index+=1
	environment.queue_free()
	await process_frame
	if fixture.is_empty(): return
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture))
	var draw := DrawPass.new()
	draw.solid_enabled=true
	camera.add_child(draw)
	var captures := 0
	for entry: Dictionary in report.ui_presentations:
		if entry.stage not in ["commander-settled","driver-settled","cupola-settled","gunner-settled"]: continue
		var drawing: Dictionary=report.render_passes.filter(func(p):return p.sequence==entry.draw_sequence)[0].duplicate(true)
		drawing.palette_rgb=report.presentations[int(entry.frame_index)].palette_rgb
		var frame: Dictionary=drawing.camera.duplicate(true)
		frame.matrix_q14_columns=[16384,0,0,0,16384,0,0,0,16384];frame.world_position_raw=[0,0,0]
		var clip: Array=frame.clip
		source=Image.load_from_file(fixture.get_base_dir().path_join(entry.image))
		mask=Image.load_from_file(fixture.get_base_dir().path_join(entry.mask))
		for extent in [Vector2i(1440,900),Vector2i(1920,1080)]:
			resize(extent,frame)
			draw.apply_pass(drawing)
			check(draw.render_warnings.is_empty(),"original draw has no warnings")
			var presentation := {"draw_pass":drawing,"ui_overlay":{"width":320,"height":200,"mask_png":Marshalls.raw_to_base64(mask.save_png_to_buffer())}}
			check(display.tandem_frame.set_frame(source,presentation,display.world_viewport.get_texture()),"recorded frame accepted")
			var image := await snapshot()
			var world: Image=display.world_viewport.get_texture().get_image()
			compare(image,source,mask,Rect2i(clip[0],clip[1],clip[2]-clip[0]+1,clip[3]-clip[1]+1),world,"%s-%d"%[entry.stage,extent.x])
			if not output.is_empty():
				image.save_png(output.path_join("%s-%d.png"%[entry.stage,extent.x]))
				world.save_png(output.path_join("%s-%d-world.png"%[entry.stage,extent.x]))
			captures+=1
	check(captures==8,"all four recorded stations at two native window sizes")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	native="--native" in args
	if "--output" in args: output=args[args.find("--output")+1];DirAccess.make_dir_recursive_absolute(output)
	outer=SubViewport.new();outer.size=Vector2i(1280,960)
	outer.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(outer)
	display=Display.new();outer.add_child(display);display.size=outer.size
	camera=Camera3D.new();display.world_viewport.add_child(camera);camera.make_current()
	await projection_contracts()
	boundary_contracts()
	if native: await native_contracts(args[args.find("--fixture")+1] if "--fixture" in args else "")
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"errors":errors,"pixel_comparisons":pixels,"projection_max_error":max_projection_error,"samples":samples},"  "))
	for error in errors: printerr("FAIL: "+error)
	print("PC_PLAY_DISPLAY: %d checks, %d errors; %d pixels; projection error %.7f"%[checks,errors.size(),pixels,max_projection_error])
	quit(0 if errors.is_empty() else 1)
