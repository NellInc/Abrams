extends SceneTree
const Cursor=preload("res://scripts/pc_original_cursor.gd")
const Frame=preload("res://scripts/pc_tandem_frame.gd")
var errors:Array[String]=[]
var checks:=0
var native:=false
var output:String
var view:SubViewport

func check(value:bool,label:String)->void:
	checks+=1
	if not value and errors.size()<20:errors.append(label)

func _initialize()->void:run.call_deferred()
func snap()->Image:
	await process_frame
	RenderingServer.force_draw(false);RenderingServer.force_sync()
	return view.get_texture().get_image()

func run()->void:
	var started:=Time.get_ticks_msec()
	var root_path:=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	native="--native" in OS.get_cmdline_user_args()
	output=root_path.path_join("artifacts/finish-20260928/cursor-struts/native")
	if native:DirAccess.make_dir_recursive_absolute(output)
	view=SubViewport.new();view.size=Vector2i(1280,800);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var background:=TextureRect.new();background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;background.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;background.size=view.size;view.add_child(background)
	var cursor=Cursor.new();cursor.size=view.size;view.add_child(cursor);cursor.load_sources(root_path)
	var menu_path:=root_path.path_join("artifacts/pc-menu-text-trace-04/report.json")
	var menu:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(menu_path))
	var entry:Dictionary=menu.samples.filter(func(row):return row.label=="joystick")[0]
	var source:=Image.load_from_file(menu_path.get_base_dir().path_join(entry.image));source.convert(Image.FORMAT_RGB8)
	background.texture=ImageTexture.create_from_image(source)
	cursor.set_frame(source,entry.presentation)
	check(cursor.active.size()==79,"all79 original opaque cursor pixels verified")
	check(cursor.mask!=null,"original verification mask retained")
	# Every original ink-square corner lies inside the authored polygon or its
	# half-source-pixel stroke. This catches residual bitmap teeth at any scale.
	var polygon:=PackedVector2Array(Cursor.OUTLINE)
	for item in cursor.active:
		var local:Vector2=item[0]-cursor.origin
		for delta in [Vector2.ZERO,Vector2(1,0),Vector2(0,1),Vector2.ONE]:
			var point:Vector2=local+delta
			var covered:=Geometry2D.is_point_in_polygon(point,polygon)
			for i in polygon.size():
				var nearest:=Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()])
				covered=covered or point.distance_to(nearest)<=0.500001
			check(covered,"old cursor ink is entirely covered by vector outline")
	if native:
		var rendered:=await snap();rendered.save_png(output.path_join("cursor-menu.png"))
		var bounds:Rect2i=Rect2i(entry.presentation.original_cursor.rect[0]*4,entry.presentation.original_cursor.rect[1]*4,64,60)
		rendered.get_region(bounds.grow(8)).save_png(output.path_join("cursor-detail.png"))
		var changed:=0;var shades:Dictionary={}
		for y in 800:
			for x in 1280:
				var same:=rendered.get_pixel(x,y).to_rgba32()==source.get_pixel(x/4,y/4).to_rgba32()
				if not bounds.grow(1).has_point(Vector2i(x,y)):check(same,"cursor cannot alter surrounding menu")
				elif not same:changed+=1;shades[rendered.get_pixel(x,y).to_rgba32()]=true
		check(changed>100 and shades.size()>3,"cursor has actual scalable antialiased contours")
	for kind in ["pixel","hash","rect","palette"]:
		var image:=source.duplicate();var packet:Dictionary=entry.presentation.duplicate(true)
		if kind=="pixel":image.set_pixelv(Vector2i(cursor.active[0][0]),Color.MAGENTA)
		elif kind=="hash":packet.original_cursor.indices="A".repeat(320)
		elif kind=="rect":packet.original_cursor.rect[2]=15
		else:packet.palette_rgb[15]=[0,0,0]
		cursor.set_frame(image,packet);check(cursor.mask==null and cursor.active.is_empty(),"cursor fails closed:"+kind)
		cursor.set_frame(source,entry.presentation)
	cursor.set_frame(null,entry.presentation);check(cursor.active.is_empty(),"null clears cursor")
	cursor.queue_free();background.queue_free()
	await process_frame
	var frame=Frame.new();frame.size=view.size;view.add_child(frame)
	check(frame.load_genesis_art(root_path),"pinned cockpit donor set loads")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(root_path.path_join("artifacts/finish-20260928/cursor-struts/coverage-fixtures.json")))
	var samples:=[]
	for row in fixture.samples:
		check(Time.get_ticks_msec()-started<60000,"finite60second renderer deadline")
		var image:=Image.load_from_file(root_path.path_join(row.source_path));image.convert(Image.FORMAT_RGB8)
		var packet:Dictionary=row.packet
		var c:Array=packet.draw_pass.camera.clip
		var world:=ImageTexture.create_from_image(image.get_region(Rect2i(c[0],c[1],c[2]-c[0]+1,c[3]-c[1]+1)))
		check(frame.set_frame(image,packet,world,{"name":"SIM"}),row.name+" valid frame")
		if row.donor==4:check(frame.driver_assembly_enabled,row.name+" original moving assembly active")
		else:check(3 in frame.cockpit_art_ids,row.name+" clipped cupola material active")
		if not native:continue
		var rendered:=await snap();var donor:Image=frame.cockpit_art_textures[int(row.donor)].get_image()
		var points:Dictionary={}
		for p in row.points:points[Vector2i(p[0],p[1])]=true
		var changed:=0
		for p in row.points:
			for dy in 4:
				for dx in 4:
					var x:int=p[0]*4+dx;var y:int=p[1]*4+dy
					var donor_x:=floori((x+0.5)/4.0*1586.0/320.0)
					var donor_y:=floori(((y+0.5)/4.0-(15.0 if row.donor==4 else 0.0))*992.0/200.0)
					var expected:=donor.get_pixel(donor_x,donor_y)
					check(rendered.get_pixel(x,y).to_rgba32()==expected.to_rgba32(),row.name+" actual highres donor sampling")
					if rendered.get_pixel(x,y).to_rgba32()!=image.get_pixel(p[0],p[1]).to_rgba32():changed+=1
		if row.donor==3:
			for y in 800:
				for x in 1280:
					if not points.has(Vector2i(x/4,y/4)):
						check(rendered.get_pixel(x,y).to_rgba32()==image.get_pixel(x/4,y/4).to_rgba32(),"clipped/transparent neighbours untouched")
		check(changed>100,row.name+" remaster actually visible")
		rendered.save_png(output.path_join(row.name+".png"))
		samples.append({"name":row.name,"source_pixels":row.points.size(),"changed_output_pixels":changed})
	if native:
		var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"errors":errors,"samples":samples,"elapsed_ms":Time.get_ticks_msec()-started},"  "))
	for error in errors:printerr(error)
	print("CURSOR_STRUTS: ",checks," checks, ",errors.size()," errors")
	quit(0 if errors.is_empty() else 1)
