extends SceneTree
const MapArt=preload("res://scripts/pc_map_art.gd")
var errors:Array[String]=[]
var checks:=0
func _initialize()->void: run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok and errors.size()<20:errors.append(label)
func run()->void:
	var folder:=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var source:=Image.load_from_file(folder.path_join("artifacts/pc-motor-pool-baseline-01/mission-summary.png"))
	check(source!=null,"original mission summary capture available")
	if source==null:finish();return
	source.convert(Image.FORMAT_RGB8)
	var art:=MapArt.new();root.add_child(art)
	check(art.load_sources(folder),"source and Genesis shared-motif custody")
	check(art.set_frame(source,{"name":"END"}),"original mission summary FRAME accepted")
	check(art.active.rivets==12,"all twelve fasteners covered")
	check(art.set_frame(source,{"name":"START"}),"same source FRAME in original START accepted")
	for name in ["SIM","BRIEF","OTHER"]:
		check(not art.set_frame(source,{"name":name}) and not art.visible,"unsupported program fails closed: "+name)
	check(not art.set_frame(source,{"name":"END"},{"frontend_program":{"name":"START"}}),"stale program provenance rejected")
	var changed:=source.duplicate()
	changed.set_pixel(50,50,Color.WHITE)
	check(art.set_frame(changed,{"name":"END"}),"interior content does not select tactical state")
	for point in [Vector2i(0,0),Vector2i(5,5),Vector2i(9,100),Vector2i(315,100),Vector2i(20,180),Vector2i(20,195)]:
		changed=source.duplicate();changed.set_pixelv(point,Color.MAGENTA)
		check(not art.set_frame(changed,{"name":"END"}) and art.active.is_empty(),"partial/overwritten surround rejects atomically")
	var wrong:=source.duplicate();wrong.convert(Image.FORMAT_RGBA8)
	check(not art.set_frame(wrong,{"name":"END"}),"unsupported pixel format stays original")
	if "--native" in OS.get_cmdline_user_args():
		root.remove_child(art)
		var view:=SubViewport.new();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
		var image:=TextureRect.new();image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		image.texture=ImageTexture.create_from_image(source);view.add_child(image);view.add_child(art)
		var out:=folder.path_join("artifacts/finish-20260928/maps/native")
		DirAccess.make_dir_recursive_absolute(out)
		for scale in [4,6]:
			view.size=Vector2i(320,200)*scale;image.size=view.size;art.size=view.size
			check(art.set_frame(source,{"name":"END"}),"native FRAME accepted")
			await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
			var rendered:=view.get_texture().get_image();var changed_pixels:=0;var protected_pixels:=0;var footer_pixels:=0
			for y in view.size.y:
				for x in view.size.x:
					var p:=Vector2i(x/scale,y/scale)
					var same:=rendered.get_pixel(x,y).to_rgba32()==source.get_pixelv(p).to_rgba32()
					if p.y>=187 and not same:footer_pixels+=1
					if Rect2i(10,10,300,166).has_point(p):
						if not same:protected_pixels+=1
					elif not same:changed_pixels+=1
			check(protected_pixels==0,"all content pixels remain exact at "+str(scale)+"x")
			check(footer_pixels>1000,"pixel-verified footer rebuilt without enlarged dithering")
			check(changed_pixels>1000,"analytic surround visibly rendered at "+str(scale)+"x")
			check(rendered.save_png(out.path_join("mission-summary-"+str(scale)+"x.png"))==OK,"native image saved")
	art.clear();check(not art.visible and art.active.is_empty(),"clear removes previous frame")
	finish()
func finish()->void:
	for error in errors:printerr("FAIL: "+error)
	print("PC_MAP_ART: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
