extends SceneTree
const Frontend=preload("res://scripts/pc_frontend_art.gd")
var errors: Array[String]=[]
var checks:=0
var native:=false
var output:String
var view:SubViewport
var original:TextureRect
var art:TextureRect
var oracle=preload("res://tests/pc_outline_oracle.gd").new()
var samples:Array=[]
func check(ok:bool,why:String)->void:
	checks+=1
	if not ok and errors.size()<20:errors.append(why)
func _initialize()->void:run.call_deferred()
func snap()->Image:
	await process_frame
	RenderingServer.force_draw(false);RenderingServer.force_sync()
	return view.get_texture().get_image()
func run()->void:
	var root_path:=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args:=OS.get_cmdline_user_args()
	native="--native" in args
	output=root_path.path_join("artifacts/pc-menu-text-native")
	var fixture:=root_path.path_join("artifacts/pc-menu-text-trace-04/report.json")
	for flag in ["--output","--fixture"]:
		if flag in args:
			if flag=="--output":output=args[args.find(flag)+1]
			else:fixture=args[args.find(flag)+1]
	if native:check(DirAccess.make_dir_recursive_absolute(output)==OK,"output directory")
	oracle.load_sources(root_path)
	view=SubViewport.new();view.size=Vector2i(1280,800);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	original=TextureRect.new();original.size=view.size;original.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;original.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;view.add_child(original)
	art=Frontend.new();art.size=view.size;view.add_child(art)
	# Current art/fonts with the frozen previous pixel verifier, for exact
	# same-version native A/B checks. Historical screenshots may predate art edits.
	if "--pixel-oracle" in args:
		for field in ["typography","flow_typography"]:
			var prior: Control=art.get(field)
			var index := prior.get_index()
			art.remove_child(prior)
			prior.free()
			var replacement := preload("res://tests/pc_typography_pixel_oracle.gd").new()
			art.add_child(replacement)
			art.move_child(replacement,index)
			replacement.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			art.set(field,replacement)
	check(art.load_sources(root_path),"source art/fonts load")
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture))
	var labels:=0
	for entry in data.samples:
		if entry.label.ends_with("-press"):continue
		if not entry.program is Dictionary:
			art.set_frame(Image.load_from_file(fixture.get_base_dir().path_join(entry.image)),{},entry.presentation)
			check(not art.visible and art.flow_typography.runs.is_empty(),"original exit clears game text")
			continue
		if entry.program.get("name") not in ["START","BRIEF","END"]:continue
		var source:=Image.load_from_file(fixture.get_base_dir().path_join(entry.image))
		original.texture=ImageTexture.create_from_image(source)
		art.set_frame(source,entry.program,entry.presentation)
		var runs:Array=art.flow_typography.runs.duplicate(true)
		labels+=runs.size()
		if entry.label=="joystick":check(runs.any(func(r):return r.text=="DO YOU WANT TO USE A JOYSTICK?"),"original joystick prompt restored")
		if entry.label=="scenario":check(runs.any(func(r):return r.text.contains("MOSSEL")),"scenario words restored")
		if entry.label=="name-5":check(runs.any(func(r):return r.text.contains("NELL")),"edited name stays original")
		for r in runs:check(not art.typography.runs.any(func(old):return old.rect.intersects(r.rect)),"no overlap with existing restored typography")
		if native:
			# Test glyphs independently of the restored vector cursor. Its
			# antialiased footprint differs from the original bitmap mask.
			art.original_cursor.hide()
			art.flow_typography.hide()
			var baseline:=await snap()
			art.flow_typography.show()
			var result:=await snap()
			var changed:=0
			for y in 800:
				for x in 1280:
					var inside:Dictionary={}
					for r in runs:
						if r.rect.has_point(Vector2(x+0.5,y+0.5)/4):inside=r;break
					var same:=result.get_pixel(x,y).to_rgba32()==baseline.get_pixel(x,y).to_rgba32()
					if inside.is_empty():check(same,"nontext pixel changed: "+entry.label+("" if same else " at "+str(Vector2i(x,y))))
					else:
						var glyph_matches:bool=oracle.matches(result.get_pixel(x,y),inside,Vector2(x+0.5,y+0.5)/4,Vector2(4,4))
						check(glyph_matches,"outline glyph/colour differs: "+entry.label+("" if glyph_matches else " at "+str(Vector2i(x,y))))
						if not same:changed+=1
			# Also verify the final composite, without exempting cursor pixels
			# from font acceptance. The arrow may only affect its verified
			# allocation plus the existing one-output-pixel antialias stroke.
			art.original_cursor.show()
			var composite:=await snap()
			if art.original_cursor.active.is_empty():
				check(composite.get_data()==result.get_data(),"absent cursor changes nothing: "+entry.label)
			else:
				var origin:Vector2=art.original_cursor.origin*4
				var cursor_bounds:=Rect2i(Vector2i(origin),Vector2i(64,60)).grow(1)
				cursor_bounds=cursor_bounds.intersection(Rect2i(Vector2i.ZERO,view.size))
				var strips:=[Rect2i(0,0,1280,cursor_bounds.position.y),
					Rect2i(0,cursor_bounds.end.y,1280,800-cursor_bounds.end.y),
					Rect2i(0,cursor_bounds.position.y,cursor_bounds.position.x,cursor_bounds.size.y),
					Rect2i(cursor_bounds.end.x,cursor_bounds.position.y,1280-cursor_bounds.end.x,cursor_bounds.size.y)]
				for strip in strips:
					if strip.has_area():check(composite.get_region(strip).get_data()==result.get_region(strip).get_data(),"cursor alters surrounding text: "+entry.label)
			check(composite.save_png(output.path_join(entry.label+".png"))==OK,"save menu frame")
			if entry.label=="joystick":check(result.save_png(output.path_join("joystick-font-underlay.png"))==OK,"save font-under-cursor proof")
			samples.append({"label":entry.label,"runs":runs.map(func(r):return r.text),"changed_pixels":changed})
		# These are source proof checks; a forged hash or changed cell never draws.
		if entry.label=="joystick":
			var bad_cursor:Dictionary=entry.presentation.duplicate(true)
			bad_cursor.original_cursor.indices="bad"
			art.set_frame(source,entry.program,bad_cursor)
			check(art.original_cursor.mask==null,"forged cursor cannot exempt source glyph pixels")
			bad_cursor.original_cursor.indices="A".repeat(320)
			art.set_frame(source,entry.program,bad_cursor)
			check(art.original_cursor.mask==null,"decoded cursor hash must match the original")
			var bad:Dictionary=entry.presentation.duplicate(true)
			for r in bad.text_runs:r.pixel_sha256="bad"
			art.set_frame(source,entry.program,bad)
			check(art.flow_typography.runs.is_empty(),"bad rectangle hashes reject all menu runs")
			art.set_frame(source,{"name":"OTHER"},entry.presentation)
			check(not art.visible and art.flow_typography.runs.is_empty(),"program change clears labels")
			art.text_enabled=false;art.set_frame(source,entry.program,entry.presentation)
			check(art.flow_typography.runs.is_empty(),"original-text option")
			art.text_enabled=true
	check(labels>20,"nonempty original menu coverage")
	if native:
		var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"errors":errors,"runs":labels,"samples":samples,"fixture":fixture},"  "))
	for e in errors:printerr("FAIL: "+e)
	print("PC_MENU_TEXT: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
