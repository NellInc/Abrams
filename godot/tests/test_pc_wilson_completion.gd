extends SceneTree
## Source-fixture binding and bounded donor/alpha rendering, no emulator needed.
const Frontend=preload("res://scripts/pc_frontend_art.gd")
var checks:=0
var errors:Array[String]=[]
var native:=false
var output:=""
var started:=Time.get_ticks_msec()
var finished:=false
var viewport:SubViewport
var original:TextureRect
var art:TextureRect
var samples:Array[Dictionary]=[]
var coverage:Dictionary={}

func check(ok:bool,reason:String)->void:
	checks+=1
	if not ok and errors.size()<20:errors.append(reason)

func _initialize()->void:
	create_timer(60.0).timeout.connect(deadline)
	run.call_deferred()

func deadline()->void:
	if finished:return
	check(false,"60 second Wilson test wall-clock deadline exceeded")
	finish()

func bilinear(image:Image,uv:Vector2)->Color:
	var p:=uv*Vector2(image.get_size())-Vector2(0.5,0.5)
	var at:=Vector2i(floori(p.x),floori(p.y));var f:=p-Vector2(at)
	var limit:=image.get_size()-Vector2i.ONE
	var a:=image.get_pixelv(at.clamp(Vector2i.ZERO,limit)).lerp(image.get_pixelv((at+Vector2i.RIGHT).clamp(Vector2i.ZERO,limit)),f.x)
	var b:=image.get_pixelv((at+Vector2i.DOWN).clamp(Vector2i.ZERO,limit)).lerp(image.get_pixelv((at+Vector2i.ONE).clamp(Vector2i.ZERO,limit)),f.x)
	return a.lerp(b,f.y)

func close_colour(a:Color,b:Color)->bool:
	return absf(a.r-b.r)<=3.0/255.0 and absf(a.g-b.g)<=3.0/255.0 and absf(a.b-b.b)<=3.0/255.0

func with_dialogue(source:Image,height:int)->Image:
	var result:Image=source.duplicate()
	if height==200:return result
	# Recognition permits any lower dialogue contents, with the exact complete
	# border. Distinct sentinel ink catches lower-region replacement/stretching.
	result.fill_rect(Rect2i(0,height,320,200-height),Color(0,0,0.66))
	result.fill_rect(Rect2i(0,height,320,1),Color.WHITE)
	result.set_pixel(1,height+1,Color8(85,85,255));result.set_pixel(318,height+1,Color8(85,85,255))
	for y in range(height+3,200,5):
		for x in range(3,317,7):result.set_pixel(x,y,Color8((x*3)%256,(y*5)%256,91))
	return result

func render(source:Image,label:String)->void:
	if Time.get_ticks_msec()-started>55000:deadline();return
	original.texture=ImageTexture.create_from_image(source)
	await process_frame
	# No indefinite frame_post_draw signal wait. A bounded number of explicit
	# draws is sufficient because textures and material values are already set.
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	var image:=viewport.get_texture().get_image()
	check(image!=null and image.get_size()==viewport.size,"render dimensions "+label)
	if image==null:return
	image.convert(Image.FORMAT_RGB8)
	var expanded:Image=source.duplicate();expanded.resize(640,400,Image.INTERPOLATE_NEAREST)
	var height:=int(art.active.get("height",0))
	var bytes:=image.get_data();var source_bytes:=expanded.get_data()
	check(bytes.slice(height*2*640*3)==source_bytes.slice(height*2*640*3),"every protected dialogue/fallback byte remains original "+label)
	var stats:Dictionary={"donor_samples":0,"transparent":0,"near_opaque":0,"mixed_alpha":0}
	if height>0:
		var office:Image=art.material.get_shader_parameter("office").get_image()
		var portrait:Image=art.portraits[int(art.active.pose)].get_image()
		var rect:Array=art.catalog.templates[int(art.active.pose)].portrait_rect
		var points:Array[Vector2i]=[]
		for y in range(3,height*2,19):
			for x in range(3,640,23):points.append(Vector2i(x,y))
		# Find one actual semi-transparent output sample on the donor silhouette.
		# At most 2*width*height candidates, no whole-scene bilinear mass loop.
		var mixed_found:=false
		for y in range(int(rect[1]*2),mini(int((rect[1]+rect[3])*2),height*2)):
			for x in range(int(rect[0]*2),int((rect[0]+rect[2])*2)):
				var q:=(Vector2(x,y)/2+Vector2(0.25,0.25)-Vector2(rect[0],rect[1]))/Vector2(rect[2],rect[3])
				var alpha:=bilinear(portrait,q).a
				if alpha>0.02 and alpha<0.98:
					points.append(Vector2i(x,y));mixed_found=true;break
			if mixed_found:break
		for point in points:
			var p:=(Vector2(point)+Vector2(0.5,0.5))/2
			var expected:=bilinear(office,p/Vector2(320,200))
			var q:=(p-Vector2(rect[0],rect[1]))/Vector2(rect[2],rect[3])
			if q.x>=0 and q.y>=0 and q.x<1 and q.y<1:
				var fg:=bilinear(portrait,q)
				if fg.a<0.001:stats.transparent+=1
				elif fg.a>=0.98:stats.near_opaque+=1
				else:stats.mixed_alpha+=1
				expected=expected.lerp(Color(fg.r,fg.g,fg.b,1),fg.a)
			check(close_colour(image.get_pixelv(point),expected),"exact authored donor/office bilinear alpha "+label+" "+str(point))
			stats.donor_samples+=1
		check(stats.transparent>0 and stats.near_opaque>0 and stats.mixed_alpha>0,"transparent/near-opaque/edge alpha samples covered "+label)
	check(image.save_png(output.path_join(label+".png"))==OK,"native image saved "+label)
	samples.append({"label":label,"active":art.active.duplicate(),"samples":stats})

func run()->void:
	var root_path:=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args:=OS.get_cmdline_user_args();native="--native" in args
	output=root_path.path_join("artifacts/finish-20260928/wilson-headless")
	if "--output" in args:
		var at:=args.find("--output")+1
		if at>=args.size():check(false,"missing output path");finish();return
		output=args[at]
	check(DirAccess.make_dir_recursive_absolute(output)==OK,"output directory")
	viewport=SubViewport.new();viewport.size=Vector2i(640,400)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	original=TextureRect.new();original.size=viewport.size;original.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	original.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;viewport.add_child(original)
	art=Frontend.new();art.text_enabled=false;art.size=viewport.size;viewport.add_child(art)
	check(art.load_sources(root_path),"pinned original and authored art load")
	check(art.catalog.get("templates",[]).size()==6 and art.portraits.size()==6,"all six portraits and templates integrated")
	if art.catalog.is_empty():finish();return
	for pose in [3,4,5]:
		var base:=Image.load_from_file(root_path.path_join("local-art/pc-wilson-completion-v1/source/office-co-%02d.png"%pose))
		check(base!=null and base.get_size()==Vector2i(320,200),"source fixture "+str(pose))
		if base==null:continue
		var immutable:=base.get_data()
		coverage[str(pose)]=[]
		for height in [200,187,177,167,157,147,137]:
			var source:=with_dialogue(base,height)
			for name in ["BRIEF","END"]:
				check(art.set_frame(source,{"name":name}),"original pose/height recognized %s/%d/%d"%[name,pose,height])
				check(art.active.get("pose")==pose and art.active.get("height")==height,"exact pose/height selected")
			coverage[str(pose)].append(height)
			if native and (height==200 or (pose==4 and height==137)):
				await render(source,"pose-%d-height-%d"%[pose,height])
				if finished:return
			var changed:Image=source.duplicate();changed.set_pixel(20,50,Color.MAGENTA)
			check(not art.set_frame(changed,{"name":"BRIEF"}),"one prefix pixel mismatch rejects")
			check(not art.visible and art.active.is_empty(),"mismatch clears previous art")
			if height<200:
				changed=source.duplicate();changed.set_pixel(0,height,Color.BLACK)
				check(not art.set_frame(changed,{"name":"END"}),"partial border rejects")
			check(not art.set_frame(source,{"name":"SIM"}),"wrong program rejects office")
		check(base.get_data()==immutable,"source fixture immutable")
		check(art.set_frame(base,{"name":"BRIEF"}),"positive before fallback")
		var changed:Image=base.duplicate();changed.set_pixel(20,50,Color.MAGENTA)
		check(not art.set_frame(changed,{"name":"BRIEF"}),"final mutation rejects")
		if native and pose==5:await render(changed,"mutation-fallback")
		check(not art.set_frame(null,{"name":"END"}),"null image rejects")
	check(not art.load_sources(root_path.path_join("missing-wilson-assets")),"missing asset root fails closed")
	check(art.catalog.is_empty() and art.portraits.is_empty() and not art.visible,"failed load clears catalog textures and visibility")
	finish()

func finish()->void:
	if finished:return
	finished=true
	var report:={"checks":checks,"errors":errors,"coverage":coverage,"samples":samples,
		"native":native,"elapsed_ms":Time.get_ticks_msec()-started,
		"scope":"Three exact source fixtures, seven original dialogue heights, both BRIEF/END bindings; bounded authored donor and alpha samples plus complete lower-dialogue bytes. No live script reachability or independent human art acceptance claim."}
	if not output.is_empty():
		var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
		if file:file.store_string(JSON.stringify(report,"  "))
	for error in errors:printerr("FAIL: "+error)
	print("PC_WILSON_COMPLETION: %d checks, %d errors, %d ms"%[checks,errors.size(),Time.get_ticks_msec()-started])
	quit(0 if errors.is_empty() else 1)
