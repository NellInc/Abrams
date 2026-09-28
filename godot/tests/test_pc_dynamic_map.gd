extends SceneTree
const Art=preload("res://scripts/pc_dynamic_map_art.gd")
const Frame=preload("res://scripts/pc_tandem_frame.gd")
const Draw=preload("res://scripts/pc_draw_pass.gd")
const PcCamera=preload("res://scripts/pc_camera.gd")
var checks:=0
var errors:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:errors.append(label)
func run()->void:
	var art:=Art.new();root.add_child(art)
	var palette:Array=[]
	for i in 16:palette.append([i*16,i*8,i*4])
	for mode in [0,1]:
		var source:=Image.create(320,200,false,Image.FORMAT_RGB8);source.fill(Color8(32,16,8))
		var lines:Array=[[87,110,88,110,1],[87,111,88,111,1]] if mode==1 else [[16,63,18,63,4],[16,64,18,64,4],[80,90,80,90,5]]
		for line in lines:source.fill_rect(Rect2i(line[0],line[1],line[2]-line[0]+1,1),Color8(palette[line[4]][0],palette[line[4]][1],palette[line[4]][2]))
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(source.get_region(Art.MAP_RECT).get_data())
		var item:Dictionary={"schema":1,"source_sha256":Art.SIM_SHA,"rect":[16,63,144,96],"page_offset":0,"mode":mode,"background":2 if mode==0 else null,"lines":lines,"palette_rgb":palette,"pixel_sha256":hash.finish().hex_encode()}
		var presentation:Dictionary={"page_offset":0,"dynamic_map":item}
		check(art.set_frame(source,presentation),"exact source map accepted")
		var stale:=source.duplicate();stale.set_pixel(100,100,Color.MAGENTA)
		check(not art.set_frame(stale,presentation) and not art.visible,"whole map stale readback rejects")
		var bad:=presentation.duplicate(true);bad.dynamic_map.lines[0][4]=9
		check(not art.set_frame(source,bad),"invented primitive rejects raster reconstruction")
		bad=presentation.duplicate(true);bad.dynamic_map.page_offset=8192
		check(not art.set_frame(source,bad),"wrong page rejects")
		bad=presentation.duplicate(true);bad.dynamic_map.lines[0][0]=15
		check(not art.set_frame(source,bad),"outside source map rejects")
		if "--native" in OS.get_cmdline_user_args():
			root.remove_child(art)
			var view:=SubViewport.new();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
			var backdrop:=TextureRect.new();backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;backdrop.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;backdrop.texture=ImageTexture.create_from_image(source);view.add_child(backdrop);view.add_child(art)
			for scale in [1,4,6]:
				view.size=Vector2i(320,200)*scale;backdrop.size=view.size;art.size=view.size
				check(art.set_frame(source,presentation),"native map accepts")
				await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
				var image:=view.get_texture().get_image();var mismatch:=0
				for y in image.get_height():
					for x in image.get_width():
						if image.get_pixel(x,y).to_rgba32()!=source.get_pixel(x/scale,y/scale).to_rgba32():mismatch+=1
				check(mismatch==0,"complete exact original map geometry at "+str(scale)+"x")
			view.remove_child(art);root.add_child(art);view.queue_free()
	var folder:=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	for name in ["overview","local"]:
		var capture:= "live-integration" if "--integrated" in OS.get_cmdline_user_args() else "live-trace"
		var path:=folder.path_join("artifacts/finish-20260928/maps/"+capture+"/"+name)
		if not FileAccess.file_exists(path+".json"):
			check("--live" not in OS.get_cmdline_user_args(),"required live fixture available: "+name)
			continue
		var fixture=JSON.parse_string(FileAccess.get_file_as_string(path+".json"))
		var live:Dictionary=fixture.get("presentation",fixture)
		var original:=Image.load_from_file(path+".png")
		check(art.set_frame(original,live),"actual source map packet accepts: "+name)
		if "--integrated" in OS.get_cmdline_user_args():await integrated(folder,name,original,fixture)
		if "--native" in OS.get_cmdline_user_args():
			root.remove_child(art)
			var view:=SubViewport.new();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
			var backdrop:=TextureRect.new();backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;backdrop.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;backdrop.texture=ImageTexture.create_from_image(original);view.add_child(backdrop);view.add_child(art)
			for scale in [1,4,6]:
				view.size=Vector2i(320,200)*scale;backdrop.size=view.size;art.size=view.size
				check(art.set_frame(original,live),"actual native map accepts")
				await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
				var image:=view.get_texture().get_image();var mismatch:=0
				for y in image.get_height():
					for x in image.get_width():
						if image.get_pixel(x,y).to_rgba32()!=original.get_pixel(x/scale,y/scale).to_rgba32():mismatch+=1
				check(mismatch==0,"actual map + all protected pixels remain exact at "+str(scale)+"x")
				if scale==4:image.save_png(folder.path_join("artifacts/finish-20260928/maps/native/dynamic-"+name+"-4x.png"))
			view.remove_child(art);root.add_child(art);view.queue_free()
	art.queue_free()
	for error in errors:printerr("FAIL: "+error)
	print("PC_DYNAMIC_MAP: %d checks, %d errors"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)

func integrated(folder:String,label:String,source:Image,fixture:Dictionary)->void:
	var live=fixture.get("presentation")
	var program=fixture.get("program")
	check(live is Dictionary and program is Dictionary and program.get("name")=="SIM","captured original presentation and active program")
	if not live is Dictionary or not program is Dictionary:return
	check(live.get("draw_pass") is Dictionary and live.get("ui_overlay") is Dictionary and live.get("plate_overlay") is Dictionary,"actual paired world and masks retained")
	if not live.get("draw_pass") is Dictionary:return
	var before:=JSON.stringify(fixture)
	var original_bytes:=source.get_data()
	var view:=SubViewport.new();view.size=Vector2i(1280,800);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var world:=SubViewport.new();world.own_world_3d=true;world.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(world)
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current()
	var draw:=Draw.new();draw.solid_enabled=true;camera.add_child(draw)
	var drawing:Dictionary=live.draw_pass.duplicate(true);drawing.palette_rgb=live.palette_rgb
	var relative:Dictionary=drawing.camera.duplicate(true)
	relative.matrix_q14_columns=[16384,0,0,0,16384,0,0,0,16384];relative.world_position_raw=[0,0,0]
	world.size=PcCamera.apply(camera,relative,Vector3.ZERO)*4
	draw.apply_pass(drawing)
	check(draw.render_warnings.is_empty() and draw.polygon_count>0,"real paired original world replay succeeds: "+label)
	var frame:=Frame.new();frame.size=view.size;view.add_child(frame)
	check(frame.load_graphics_sources(folder),"native graphics sources available")
	check(frame.load_genesis_art(folder),"authored presentation sources available")
	check(frame.typography.load_sources(folder.path_join("GAME")),"source typography available")
	check(frame.set_frame(source,live,world.get_texture(),program) and frame.world_enabled,"real tandem accepts paired source/world/masks")
	check(frame.dynamic_map_art.visible and frame.dynamic_map_art.packet==live.dynamic_map,"integrated child has exact original map packet")
	var saved_map:=JSON.stringify(frame.dynamic_map_art.packet)
	var native:bool="--native" in OS.get_cmdline_user_args()
	var upscaled:Image=null
	if native:
		await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
		upscaled=view.get_texture().get_image()
		upscaled.save_png(folder.path_join("artifacts/finish-20260928/maps/native/integrated-"+label+"-upscaled.png"))
	for mode in ["ega","genesis"]:
		check(frame.set_graphics_mode(mode),"graphics switch accepts: "+mode)
		check(not frame.dynamic_map_art.visible and frame.dynamic_map_art.packet.is_empty(),"map child fully clears in "+mode)
		check(not frame.world_enabled and frame.material==null,"native mode excludes upscaled compositor")
		if native:
			await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
			var image:=view.get_texture().get_image()
			if mode=="ega":
				var expected:=source.duplicate();expected.resize(1280,800,Image.INTERPOLATE_NEAREST);expected.convert(image.get_format())
				check(image.get_data()==expected.get_data(),"integrated EGA all pixels remain original")
			image.save_png(folder.path_join("artifacts/finish-20260928/maps/native/integrated-"+label+"-"+mode+".png"))
		check(frame.set_graphics_mode("upscaled"),"return to Upscaled accepts")
		check(frame.dynamic_map_art.visible and JSON.stringify(frame.dynamic_map_art.packet)==saved_map,"Upscaled restores identical captured map packet")
		check(frame.world_enabled,"Upscaled restores paired world")
		if native:
			await process_frame;RenderingServer.force_draw(false);RenderingServer.force_sync()
			check(view.get_texture().get_image().get_data()==upscaled.get_data(),"Upscaled roundtrip native pixels exact after "+mode)
	check(JSON.stringify(fixture)==before and source.get_data()==original_bytes,"graphics switches do not mutate captured source or presentation")
	view.queue_free();world.queue_free()
