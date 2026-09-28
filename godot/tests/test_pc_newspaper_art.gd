extends SceneTree
const Frame=preload("res://scripts/pc_tandem_frame.gd")
var checks:=0
var errors:=[]
var native:=false
var output:=""
var viewport:SubViewport
var frame:TextureRect
func check(ok:bool,reason:String)->void:
	checks+=1
	if not ok and errors.size()<30:errors.append(reason)
func _initialize()->void:
	create_timer(90).timeout.connect(func():printerr("PC_NEWSPAPERS: deadline exceeded");quit(2))
	run.call_deferred()
func snap()->Image:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return viewport.get_texture().get_image()
func bilinear(im:Image,p:Vector2)->Color:
	var at:=Vector2i(floori(p.x),floori(p.y));var f:=p-Vector2(at);var limit:=im.get_size()-Vector2i.ONE
	return im.get_pixelv(at.clamp(Vector2i.ZERO,limit)).lerp(im.get_pixelv((at+Vector2i.RIGHT).clamp(Vector2i.ZERO,limit)),f.x).lerp(im.get_pixelv((at+Vector2i.DOWN).clamp(Vector2i.ZERO,limit)).lerp(im.get_pixelv((at+Vector2i.ONE).clamp(Vector2i.ZERO,limit)),f.x),f.y)
func run()->void:
	var root_path:=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args:=OS.get_cmdline_user_args();native="--native" in args
	if "--output" in args:output=args[args.find("--output")+1]
	if native:DirAccess.make_dir_recursive_absolute(output)
	viewport=SubViewport.new();viewport.size=Vector2i(1280,800);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	frame=Frame.new();frame.size=viewport.size;viewport.add_child(frame)
	check(frame.load_genesis_art(root_path),"art bank loads")
	check(frame.load_graphics_sources(root_path),"native bank loads")
	var art=frame.frontend_art.newspaper_art
	check(art.entries.size()==3,"three exact source ending families")
	for entry in art.entries:
		var original:=Image.load_from_file(root_path.path_join("local-art/pc-newspapers-v1/"+entry.name+"-pc.png"))
		var immutable:=original.get_data()
		for prose in [false,true]:
			var source:Image=original.duplicate()
			if prose:source.fill_rect(Rect2i(0,72,320,128),Color.WHITE);source.set_pixel(24,80,Color.BLACK)
			frame.set_graphics_mode("upscaled");frame.set_frame(source,{},null,{"name":"END"});frame.present_frontend({"name":"END"})
			check(art.active.get("name")==entry.name and art.active.get("height")== (72 if prose else 200),"PC-selected full/header binding "+entry.name)
			if native:
				var im:=await snap();im.save_png(output.path_join(entry.name+("-prose" if prose else "-plate")+".png"))
				var donor:Image=art.images[entry.name].art.get_image()
				var changed:=0
				for y in range(0,800,3):
					for x in range(0,1280,3):
						if prose and y>=288:check(im.get_pixel(x,y)==source.get_pixel(x/4,y/4),"every sampled lower prose pixel preserved")
						else:
							var expected:=bilinear(donor,(Vector2(x,y)+Vector2(0.5,0.5))/Vector2(1280,800)*Vector2(donor.get_size())-Vector2(0.5,0.5))
							var actual:=im.get_pixel(x,y)
							check(absf(actual.r-expected.r)<=3.0/255 and absf(actual.g-expected.g)<=3.0/255 and absf(actual.b-expected.b)<=3.0/255,"authored donor exact bilinear sampling")
							if actual!=source.get_pixel(x/4,y/4):changed+=1
				check(changed>10000,"authored high resolution visible")
			check(frame.set_graphics_mode("ega"),"immediate EGA switch")
			check(not frame.frontend_art.visible and not frame.native_graphics.visible,"EGA hides all new art")
			check(frame.texture.get_image().get_data()==source.get_data(),"EGA bytes unchanged")
			check(frame.set_graphics_mode("genesis"),"immediate native switch")
			check(frame.native_graphics.newspaper_art.active.get("name")==entry.name,"Genesis source newspaper selected")
			if native:
				var im:=await snap();var donor:Image=frame.native_graphics.newspaper_art.images[entry.name].native.get_image()
				for y in range(0,200,2):
					for x in range(0,320,2):check(im.get_pixel(x*4+1,y*4+1)==(source.get_pixel(x,y) if prose and y>=72 else donor.get_pixel(x,y)),"native source pixel footprint")
			check(not frame.set_graphics_mode("modern"),"Modern remains deferred")
			frame.set_graphics_mode("upscaled")
			check(art.active.get("name")==entry.name,"cached instant return")
		check(original.get_data()==immutable,"source image immutable")
		var corrupt:Image=original.duplicate();corrupt.set_pixel(10,10,Color.MAGENTA)
		check(not art.set_frame(corrupt,{"name":"END"}) and art.active.is_empty(),"one header pixel mismatch clears art")
		check(not art.set_frame(original,{"name":"START"}),"wrong executable rejected")
		check(not art.set_frame(null,{"name":"END"}),"absent source rejected")
	check(not art.load_sources(root_path.path_join("missing-newspapers")) and art.entries.is_empty() and art.images.is_empty(),"missing assets fail closed")
	if native:
		var f:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"errors":errors,"scope":"Three isolated source fixtures, two display phases, three live presentation modes. No campaign completion claim."},"  "))
	print("PC_NEWSPAPERS: %d checks, %d errors"%[checks,errors.size()])
	for e in errors:printerr(e)
	quit(0 if errors.is_empty() else 1)
