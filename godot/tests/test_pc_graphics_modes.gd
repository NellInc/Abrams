extends SceneTree
const Frame=preload("res://scripts/pc_tandem_frame.gd")
var errors:=[]
var checks:=0
var frame:TextureRect
var viewport:SubViewport
var samples:=[]
var output:String
var native:=false
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok and errors.size()<30:errors.append(message)
func _initialize()->void:run.call_deferred()
func snapshot()->Image:
	await process_frame
	RenderingServer.force_draw(false);RenderingServer.force_sync()
	return viewport.get_texture().get_image()
func run()->void:
	var root_path:=ProjectSettings.globalize_path("res://").get_base_dir().get_base_dir()
	var args:=OS.get_cmdline_user_args()
	native="--native" in args
	output=root_path.path_join("artifacts/graphics-modes-work/"+("native" if native else "headless"))
	if "--output" in args and args.find("--output")+1<args.size():output=args[args.find("--output")+1]
	DirAccess.make_dir_recursive_absolute(output)
	viewport=SubViewport.new();viewport.size=Vector2i(640,400);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	frame=Frame.new();frame.size=viewport.size;viewport.add_child(frame)
	check(not frame.set_graphics_mode("genesis") and frame.graphics_mode=="upscaled","unavailable whole native bank rejects switch and preserves current mode")
	check(frame.load_graphics_sources(root_path),"native donor pack prewarmed")
	check(frame.load_genesis_art(root_path),"remaster pack prewarmed")
	frame.typography.load_sources(root_path.path_join("GAME"))
	if not frame.native_graphics.loaded:finish();return
	# Independent donor-content contract: captured Genesis instruments may not
	# leak around the differently positioned PC wells. These checks fail on the
	# earlier atlas even though its sampling/provenance oracle passed.
	for region in [Rect2i(0,123,103,77),Rect2i(215,123,105,77)]:
		for y in range(region.position.y,region.end.y):
			for x in range(region.position.x,region.end.x):
				check(frame.native_graphics.images.plates.get_pixel(x,y).a==0.0,"gunner side-console donor suppression")
	var fixtures:=[]
	for folder in ["pc-live-type-lifecycle-01","pc-information-baseline-02"]:
		var path:=root_path.path_join("artifacts/"+folder+"/report.json")
		check(FileAccess.file_exists(path),"fixture: "+folder)
		var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		for e in report.samples:fixtures.append({"label":folder+"-"+e.label,"image":path.get_base_dir().path_join(e.image),"presentation":e.presentation,"program":e.program if e.program is Dictionary else {}})
	var intro:Dictionary=frame.native_graphics.catalogs.intro
	for e in intro.entries:fixtures.append({"label":"intro-"+e.name,"image":root_path.path_join("artifacts/pc-intro-trace-01/"+e.capture_image),"presentation":{},"program":{"name":"START"}})
	var path:=root_path.path_join("artifacts/pc-live-type-cockpit-02/report.json")
	var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	for e in report.ui_presentations:
		var packet:Dictionary=report.presentations[int(e.frame_index)].duplicate(true)
		packet.draw_pass=report.render_passes.filter(func(p):return p.sequence==e.draw_sequence)[0]
		for pair in [["ui_overlay",e.mask],["plate_overlay",e.plate_mask]]:
			var im:=Image.load_from_file(path.get_base_dir().path_join(pair[1]))
			packet[pair[0]].mask_png=Marshalls.raw_to_base64(im.save_png_to_buffer())
		fixtures.append({"label":"cockpit-"+e.stage+"-"+str(int(e.frame_index)),"image":path.get_base_dir().path_join(e.image),"presentation":packet,"program":{"name":"SIM"}})
	for e in fixtures:
		var source:=Image.load_from_file(e.image)
		check(source!=null,"source exists: "+e.label)
		if source==null:continue
		var original:=source.get_data()
		var metadata:=JSON.stringify(e.presentation)
		var world:Texture2D=null
		if e.presentation.get("draw_pass") is Dictionary:
			var clip:Array=e.presentation.draw_pass.camera.clip
			world=ImageTexture.create_from_image(source.get_region(Rect2i(clip[0],clip[1],clip[2]-clip[0]+1,clip[3]-clip[1]+1)))
		frame.set_graphics_mode("upscaled")
		frame.set_frame(source,e.presentation,world,e.program);frame.present_frontend(e.program)
		var upscaled:Image=await snapshot() if native else null
		check(frame.set_graphics_mode("ega"),"EGA switch")
		check(frame.material==null and not frame.frontend_art.visible and not frame.native_graphics.visible,"EGA has no presentation overlays")
		check(frame.texture.get_image().get_data()==original,"EGA original bytes")
		if native:
			var ega:=await snapshot()
			var expected:=source.duplicate();expected.resize(640,400,Image.INTERPOLATE_NEAREST);expected.convert(ega.get_format())
			check(ega.get_data()==expected.get_data(),"native EGA exact: "+e.label)
		check(frame.set_graphics_mode("genesis"),"Genesis switch")
		check(not frame.frontend_art.visible and frame.native_graphics.visible and frame.material==null,"Genesis excludes all remaster layers")
		if native:
			var genesis:=await snapshot()
			var donor:Image=frame.native_graphics.texture.get_image()
			var tags:=Image.new()
			if e.presentation.get("plate_overlay",{}).get("mask_png") is String:tags.load_png_from_buffer(Marshalls.base64_to_raw(e.presentation.plate_overlay.mask_png))
			var changes:=0
			var plate_bits:int=frame.native_graphics.active.get("plate_bits",0)
			for y in 200:
				for x in 320:
					var expected:=donor.get_pixel(x,y)
					if not tags.is_empty():
						var id:=roundi(tags.get_pixel(x,y).r*255)
						if id>0 and plate_bits & (1<<id):
							var slot:=6 if id==8 else id
							var native_pixel:Color=frame.native_graphics.images.plates.get_pixel(x,(slot-1)*200+y)
							var pc_pixel:Color=frame.native_graphics.images.expected.get_pixel(x,(slot-1)*200+y)
							if native_pixel.a==1.0 and expected==pc_pixel:expected=native_pixel
					check(genesis.get_pixel(x*2+1,y*2+1)==expected,"native donor pixel: "+e.label+" "+str(Vector2i(x,y)))
					if not tags.is_empty() and roundi(tags.get_pixel(x,y).r*255)==1 and y>=123 and (x<103 or x>=215):
						check(genesis.get_pixel(x*2+1,y*2+1)==source.get_pixel(x,y),"gunner complete side console retains source pixels: "+e.label)
					if expected!=source.get_pixel(x,y):changes+=1
			samples.append({"label":e.label,"changed_source_pixels":changes,"active":frame.native_graphics.active.duplicate(true)})
			if changes>0:genesis.save_png(output.path_join(e.label+"-genesis.png"))
		check(not frame.set_graphics_mode("modern") and frame.graphics_mode=="genesis","Modern remains unavailable")
		check(frame.set_graphics_mode("upscaled"),"Upscaled restores")
		if native:
			var restored:=await snapshot()
			check(restored.get_data()==upscaled.get_data(),"same cached Upscaled output restored: "+e.label)
		check(source.get_data()==original and JSON.stringify(e.presentation)==metadata,"switch leaves source and metadata immutable")
		check(frame.native_graphics.load_count==1,"switch does not load assets")
	# An untrusted/stale tag cannot authorize a pristine native damage diagram.
	var status:Dictionary=fixtures.filter(func(e):return e.label=="cockpit-damage-settled-1727")[0]
	var damaged:=Image.load_from_file(status.image)
	damaged.set_pixel(160,60,Color.RED)
	frame.set_graphics_mode("genesis")
	frame.set_frame(damaged,status.presentation,null,status.program)
	check((int(frame.native_graphics.active.get("plate_bits",0)) & (1<<5))==0,"one changed damage pixel rejects entire native schematic despite pristine tags")
	if native:
		var im:=await snapshot()
		for y in range(37,100):
			for x in range(123,305):check(im.get_pixel(x*2+1,y*2+1)==damaged.get_pixel(x,y),"whole damaged diagram remains original")
	var bad:Dictionary=status.presentation.duplicate(true)
	bad.ui_overlay.mask_png=Marshalls.raw_to_base64(Image.create_empty(320,200,false,Image.FORMAT_RGB8).save_png_to_buffer())
	frame.set_frame(damaged,bad,null,status.program)
	check(not frame.native_graphics.material.get_shader_parameter("plates_enabled"),"malformed mask disables native plates")
	var title:Dictionary=fixtures.filter(func(e):return e.label=="intro-title")[0]
	var changed:=Image.load_from_file(title.image);changed.set_pixel(0,0,Color.MAGENTA)
	frame.set_frame(changed,{},null,title.program)
	check(frame.native_graphics.active.donors.is_empty(),"one changed title pixel rejects complete donor")
	var expected:=changed.duplicate();expected.convert(Image.FORMAT_RGBA8)
	check(frame.native_graphics.texture.get_image().get_data()==expected.get_data(),"unknown transition falls back to current frame without stale art")
	frame.set_frame(null,{},null,{})
	check(frame.texture==null and frame.native_graphics.texture==null,"missing frame clears native texture instead of showing stale art")
	finish()
func finish()->void:
	var result:={"checks":checks,"errors":errors,"samples":samples,"native":native}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	for e in errors:printerr(e)
	print("PC_GRAPHICS_MODES: ","PASS" if errors.is_empty() else "FAIL","; ",checks," checks; ",samples.size()," native frames")
	quit(0 if errors.is_empty() else 1)
