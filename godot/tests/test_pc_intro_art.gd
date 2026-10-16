extends SceneTree
const Frontend = preload("res://scripts/pc_frontend_art.gd")
# Record indices of the thirteen intro poses in pc-intro-trace-01, pinned from
# the original capture rather than read back from the catalogue under test.
const INTRO_RECORDS := [403,404,405,408,411,514,754,995,1235,1475,1712,1952,2193]
const REPLAY_SELECTED := {"pc-intro-trace-01":2657,"pc-intro-skip-trace-01":1397}
var errors: Array[String] = []
var checks := 0
var viewport: SubViewport
var backdrop: TextureRect
var tandem: TextureRect
var art: TextureRect
var native := false
var output: String
var samples := []
var replay_counts := {}
var memorial_fonts := {}
var outlines = preload("res://tests/pc_outline_oracle.gd").new()

func text_run_at(entry: Dictionary, p: Vector2) -> Dictionary:
	if not art.intro_art.outline_text_enabled: return {}
	for run in entry.get("text_runs",[]):
		var r: Array=run.rect
		var box:=Rect2(r[0],r[1],r[2],r[3])
		if box.has_point(p):
			return {"text":run.text,"rect":box,"cell_size":Vector2(run.cell[0],run.cell[1]),"font_sha256":run.font_sha256,"foreground":Color8(run.foreground[0],run.foreground[1],run.foreground[2]),"background":Color.BLACK}
	if entry.get("name")=="credit-8":
		for line in [["Dedicated to the memory of","6X6.FNT",12,168,Color8(170,170,170)],
			["David \"Ming\" Kenny","8X8.FNT",18,180,Color.WHITE]]:
			var font: PackedByteArray=memorial_fonts[line[1]]
			var box:=Rect2(line[2],line[3],line[0].length()*font[0],font[1])
			if box.has_point(p):
				var sha: String=preload("res://scripts/pc_typography.gd").FONT_SOURCES[line[1]]
				return {"text":line[0],"rect":box,"cell_size":Vector2(font[0],font[1]),"font_sha256":sha,"foreground":line[4],"background":Color.BLACK}
	return {}

func memorial_pixel(p: Vector2i) -> Color:
	# Independent source-font byte decoder for the user-authored dedication.
	if p.x==8 or p.x==171 or p.y==164 or p.y==193: return Color8(255,85,85)
	for line in [["Dedicated to the memory of","6X6.FNT",12,168,Color8(170,170,170)],
		["David \"Ming\" Kenny","8X8.FNT",18,180,Color.WHITE]]:
		var font: PackedByteArray=memorial_fonts[line[1]]
		var dx:=p.x-int(line[2]);var dy:=p.y-int(line[3])
		if dx<0 or dy<0 or dy>=font[1] or dx>=line[0].length()*font[0]: continue
		var code: int=line[0].unicode_at(dx/font[0])
		var bits:=int(font[4+(code-int(font[2]))*int(font[1])+dy])
		if bits & (128>>(dx%int(font[0]))): return line[4]
	return Color.BLACK

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok and errors.size()<20: errors.append(reason)

func _initialize() -> void: run.call_deferred()

func sample_bilinear(image: Image, p: Vector2) -> Color:
	var at:=Vector2i(floori(p.x),floori(p.y))
	var f:=p-Vector2(at)
	var limit:=image.get_size()-Vector2i.ONE
	return image.get_pixelv(at.clamp(Vector2i.ZERO,limit)).lerp(image.get_pixelv((at+Vector2i.RIGHT).clamp(Vector2i.ZERO,limit)),f.x).lerp(image.get_pixelv((at+Vector2i.DOWN).clamp(Vector2i.ZERO,limit)).lerp(image.get_pixelv((at+Vector2i.ONE).clamp(Vector2i.ZERO,limit)),f.x),f.y)

func apply_frame(source: Image, program: Dictionary) -> bool:
	tandem.set_frame(source,{},null)
	return art.set_frame(source,program)

func render(source: Image, label: String) -> void:
	backdrop.texture=ImageTexture.create_from_image(source)
	await process_frame
	RenderingServer.force_draw(false); RenderingServer.force_sync()
	var image:=viewport.get_texture().get_image()
	var entry: Dictionary=art.intro_art.active
	var title: Image=art.intro_art.textures.title.get_image()
	var flash_image: Image=art.intro_art.textures.flash.get_image()
	var changed:=0
	# Independent pixel oracle samples the actual donor images, then checks every
	# original credit pixel at 4x. It does not reuse the renderer's overlay mesh.
	for y in range(0,800,3):
		for x in range(0,1280,3):
			var p:=(Vector2(x,y)+Vector2(0.5,0.5))/4
			var expected:=source.get_pixel(int(p.x),int(p.y))
			if not entry.is_empty():
				expected=sample_bilinear(title,p/Vector2(320,200)*Vector2(title.get_size())-Vector2(0.5,0.5))
				if int(entry.flash)>0:
					var effect: Dictionary=art.intro_art.catalog.flashes[int(entry.flash)-1]
					var box:=Rect2(effect.rect[0],effect.rect[1],effect.rect[2],effect.rect[3])
					if box.has_point(p):
						var donor: Array=effect.source_rect
						var fg:=sample_bilinear(flash_image,Vector2(donor[0],donor[1])+(p-box.position)/box.size*Vector2(donor[2],donor[3])-Vector2(0.5,0.5))
						expected=expected.lerp(Color(fg.r,fg.g,fg.b,1),fg.a)
				if entry.has("credit_rect"):
					var r: Array=entry.credit_rect
					if Rect2(r[0],r[1],r[2],r[3]).has_point(p): expected=source.get_pixel(int(p.x),int(p.y))
				if entry.name=="credit-8" and Rect2(8,164,164,30).has_point(p): expected=memorial_pixel(Vector2i(p))
			var actual:=image.get_pixel(x,y)
			var run:=text_run_at(entry,p)
			if run.is_empty(): check(absf(actual.r-expected.r)<=3.0/255 and absf(actual.g-expected.g)<=3.0/255 and absf(actual.b-expected.b)<=3.0/255,"native title/flash/card composition: "+label)
			else: check(outlines.matches(actual,run,p,Vector2(4,4)),"native credit/dedication contours: "+label)
			if actual!=source.get_pixel(int(p.x),int(p.y)): changed+=1
	if entry.has("credit_rect"):
		var r: Array=entry.credit_rect
		for y in range(int(r[1])*4,int(r[1]+r[3])*4):
			for x in range(int(r[0])*4,int(r[0]+r[2])*4):
				var p:=Vector2(x+0.5,y+0.5)/4
				var run:=text_run_at(entry,p)
				if run.is_empty(): check(image.get_pixel(x,y)==source.get_pixel(x/4,y/4),"every protected credit pixel: "+label)
				else: check(outlines.matches(image.get_pixel(x,y),run,p,Vector2(4,4)),"every credit contour pixel: "+label)
	if entry.get("name")=="credit-8":
		for y in range(164*4,194*4):
			for x in range(8*4,172*4):
				var p:=Vector2(x+0.5,y+0.5)/4
				var run:=text_run_at(entry,p)
				if run.is_empty(): check(image.get_pixel(x,y)==memorial_pixel(Vector2i(x/4,y/4)),"every protected dedication panel pixel")
				else: check(outlines.matches(image.get_pixel(x,y),run,p,Vector2(4,4)),"every dedication contour pixel")
	check(changed>10000 if not entry.is_empty() else changed==0,"restoration visible or exact fallback: "+label)
	check(image.save_png(output.path_join(label+".png"))==OK,"save native intro frame")
	samples.append({"label":label,"active":entry.get("name",""),"changed_samples":changed})

func run() -> void:
	var root_path:=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	outlines.load_sources(root_path)
	var args:=OS.get_cmdline_user_args()
	native="--native" in args
	output=root_path.path_join("artifacts/pc-intro-native")
	if "--output" in args: output=args[args.find("--output")+1]
	viewport=SubViewport.new();viewport.size=Vector2i(1280,800)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	backdrop=TextureRect.new();backdrop.size=viewport.size;backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	backdrop.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;viewport.add_child(backdrop)
	tandem=preload("res://scripts/pc_tandem_frame.gd").new();tandem.size=viewport.size;viewport.add_child(tandem)
	check(tandem.load_genesis_art(root_path),"full tandem materials loaded")
	art=tandem.frontend_art
	check(not art.intro_art.catalog.is_empty(),"pinned intro sources loaded")
	check(art.intro_art.outline_fonts.fonts.size()==4,"pinned outline faces loaded")
	if art.intro_art.catalog.is_empty(): finish();return
	for font in ["6X6.FNT","8X8.FNT"]: memorial_fonts[font]=FileAccess.get_file_as_bytes(root_path.path_join("GAME/"+font))
	check(art.intro_art.DEDICATION_LINES[0][0]=="Dedicated to the memory of" and art.intro_art.DEDICATION_LINES[1][0]=="David \"Ming\" Kenny","Nell's exact dedication and name")
	if native: check(DirAccess.make_dir_recursive_absolute(output)==OK,"native output directory")
	var fixture:=root_path.path_join("artifacts/pc-intro-trace-01")
	for entry in art.intro_art.catalog.entries:
		var source:=Image.load_from_file(fixture.path_join(entry.capture_image))
		check(apply_frame(source,{"name":"START"}),"complete frame recognized: "+entry.name)
		check(art.active.get("scene")=="intro" and art.intro_art.active.name==entry.name,"correct PC-selected pose/card")
		check(art.intro_art.active.dedication==(entry.name=="credit-8"),"dedication only accompanies final credit")
		if native: await render(source,entry.name)
		if native and entry.name in ["credit-1","credit-8"]:
			art.text_enabled=false
			check(apply_frame(source,{"name":"START"}),"original-text fallback retains intro art")
			await render(source,entry.name+"-original-text")
			art.text_enabled=true
		for at in [Vector2i(0,0),Vector2i(195,117),Vector2i(270,190)]:
			var changed:=source.duplicate();changed.set_pixelv(at,Color.MAGENTA)
			check(not apply_frame(changed,{"name":"START"}),"one changed pixel rejects complete binding")
			check(not art.visible and not art.intro_art.visible and art.intro_art.active.is_empty(),"rejection clears previous art")
		check(not apply_frame(source,{"name":"SIM"}),"wrong executable rejects intro")
		if native and entry.name=="flash-4": await render(source,"wrong-program-fallback")
	# Replay every captured boundary with its actual program. Changing input
	# changes native timing, but identical source frames select identical art.
	# The expected set comes from the pinned original records, so an extra or
	# wrong catalogue hash cannot vouch for itself.
	var intro_hashes:={}
	var intro_report=JSON.parse_string(FileAccess.get_file_as_string(fixture.path_join("report.json")))
	check(intro_report is Dictionary and intro_report.get("records") is Array,"pinned intro trace report readable")
	if intro_report is Dictionary and intro_report.get("records") is Array:
		for record in intro_report.records:
			if int(record.index) in INTRO_RECORDS: intro_hashes[record.rgb_sha256]=true
	var catalogue_hashes:={}
	for entry in art.intro_art.catalog.entries: catalogue_hashes[entry.rgb_sha256]=true
	check(intro_hashes.size()==INTRO_RECORDS.size() and intro_hashes.keys().all(func(h):return catalogue_hashes.has(h)) and catalogue_hashes.size()==intro_hashes.size(),"catalogue binds exactly the pinned original intro frames")
	for route in ["pc-intro-trace-01","pc-intro-skip-trace-01"]:
		var folder:=root_path.path_join("artifacts/"+route)
		var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("report.json")))
		var images: Dictionary={}
		for hash in report.images: images[hash]=Image.load_from_file(folder.path_join(report.images[hash].image))
		var selected:=0
		var program_checked:=false
		for record in report.records:
			var recognized: bool=art.intro_art.set_frame(images[record.rgb_sha256],record.program)
			var expected: bool=record.program.get("name")=="START" and intro_hashes.has(record.rgb_sha256)
			check(recognized==expected,"original timing and fallback at every boundary: "+route)
			if recognized: selected+=1
			if recognized and not program_checked:
				# Every record is START, so exercise the program filter explicitly.
				check(not art.intro_art.set_frame(images[record.rgb_sha256],{"name":"SIM"}),"intro frame under another program falls back: "+route)
				program_checked=true
		check(selected==REPLAY_SELECTED[route],"pinned selected intro boundaries: %s %d"%[route,selected])
		replay_counts[route]={"frames":report.records.size(),"selected":selected}
	await check_shot(fixture)
	check(not art.intro_art.load_sources(root_path.path_join("artifacts/missing-intro")),"missing source rejected")
	check(art.intro_art.active.is_empty() and art.intro_art.catalog.is_empty(),"missing source clears stale animation")
	if native:
		var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"errors":errors,"samples":samples,"replays":replay_counts},"  "))
	finish()

# The authored shot (Nell, 16 October 2026) is timed only by original frames.
func check_shot(fixture: String) -> void:
	var intro=art.intro_art
	var Intro=preload("res://scripts/pc_intro_art.gd")
	var last_pose:=0
	for f in 130:
		var state: Dictionary=Intro.shot_state(f)
		check(int(state.pose)>=last_pose and int(state.next)-int(state.pose) in [0,1],"shot poses only advance: %d"%f)
		last_pose=int(state.pose)
		check(float(state.blend)>=0.0 and float(state.blend)<=1.0 and float(state.alpha)>=0.0 and float(state.alpha)<=1.0,"shot weights bounded: %d"%f)
		check(Intro.shot_state(f)==state,"shot is a pure function of the frame: %d"%f)
	check(Intro.shot_state(0).pose==0 and Intro.shot_state(0).blend==0.0 and Intro.shot_state(0).glow>0.8,"shot opens on the first original pose with muzzle light")
	check(Intro.shot_state(6).pose==1 and Intro.shot_state(12).pose==2 and Intro.shot_state(19).pose==3,"four original poses at the Genesis cadence")
	check(Intro.shot_state(16).glow==0.0 and Intro.shot_state(12).shake==0.0,"light and shake are brief")
	check(Intro.shot_state(55).alpha==1.0 and Intro.shot_state(Intro.SHOT_CLEAR).alpha==0.0,"fireball holds, then clears before the first credit")
	var images:={}
	for entry in intro.catalog.entries: images[entry.name]=Image.load_from_file(fixture.path_join(entry.capture_image))
	var start := {"name":"START"}
	for row in [[1000,"title",-1],[1001,"flash-1",1001],[1008,"flash-4",1001],[1110,"credit-1",1001],
			[900,"flash-4",893],[950,"title",-1],[2000,"flash-4",1993],[2001,"title",-1],[3000,"credit-1",3000-Intro.SHOT_CLEAR],
			[-1,"title",-1],[-1,"flash-1",-1]]:
		intro.source_frame=row[0]
		check(intro.set_frame(images[row[1]],start) and intro.shot_start==row[2],"shot start from original frames: %s"%str(row))
	if native:
		for f in [0,3,6,9,12,19,30,45,60,70,80,90,100]:
			intro.source_frame=4999;apply_frame(images.title,start)
			intro.source_frame=5000;apply_frame(images["flash-1"],start)
			intro.source_frame=5000+f
			check(apply_frame(images["flash-4"],start) and intro.shot_start==5000,"shot frame bound through the frontend: %d"%f)
			backdrop.texture=ImageTexture.create_from_image(images["flash-4"])
			await process_frame
			RenderingServer.force_draw(false); RenderingServer.force_sync()
			check(viewport.get_texture().get_image().save_png(output.path_join("shot-f%03d.png"%f))==OK,"save shot frame")
	intro.source_frame=-1

func finish() -> void:
	for error in errors: printerr("FAIL: "+error)
	print("PC_INTRO_ART: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
