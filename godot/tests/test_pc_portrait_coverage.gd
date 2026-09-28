extends SceneTree
## Finite four-role source fixtures and recorded first-frame/erasure replay.
const Portraits=preload("res://scripts/pc_portrait_art.gd")
const Information=preload("res://scripts/pc_information_art.gd")
const ROLES=["commander","gunner","driver","loader"]
var errors:Array[String]=[]
var checks:=0
var native:=false
var output:=""
var finished:=false
var started:=Time.get_ticks_msec()
var view:SubViewport
var background:TextureRect
var portraits:Control
var information:Control
var samples:Array[Dictionary]=[]

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok and errors.size()<20:errors.append(label)

func _initialize()->void:
	create_timer(60.0).timeout.connect(func():check(false,"portrait test 60s deadline");finish())
	run.call_deferred()

func bilinear(im:Image,uv:Vector2)->Color:
	var p:=uv*Vector2(im.get_size())-Vector2(0.5,0.5)
	var at:=Vector2i(floori(p.x),floori(p.y));var f:=p-Vector2(at);var limit:=im.get_size()-Vector2i.ONE
	return im.get_pixelv(at.clamp(Vector2i.ZERO,limit)).lerp(im.get_pixelv((at+Vector2i.RIGHT).clamp(Vector2i.ZERO,limit)),f.x).lerp(im.get_pixelv((at+Vector2i.DOWN).clamp(Vector2i.ZERO,limit)).lerp(im.get_pixelv((at+Vector2i.ONE).clamp(Vector2i.ZERO,limit)),f.x),f.y)

func near(a:Color,b:Color)->bool:
	return absf(a.r-b.r)<=3.0/255 and absf(a.g-b.g)<=3.0/255 and absf(a.b-b.b)<=3.0/255

func snapshot(source:Image)->Image:
	background.texture=ImageTexture.create_from_image(source)
	await process_frame
	RenderingServer.force_draw(false);RenderingServer.force_sync()
	var image:=view.get_texture().get_image();image.convert(Image.FORMAT_RGB8)
	return image

func render_portrait(source:Image,label:String)->void:
	var image:=await snapshot(source)
	var expanded:Image=source.duplicate();expanded.resize(640,400,Image.INTERPOLATE_NEAREST)
	var protected:=expanded.get_data();var actual:=image.get_data()
	var probes:=0
	if not portraits.active.is_empty():
		var item:Dictionary=portraits.templates[int(portraits.active.id)]
		var donor:Image=item.texture.get_image()
		for point in item.points:
			var base:Vector2i=(Vector2i(37,59)+point.at)*2
			# Exclude only the proven opaque source footprint from a whole-output
			# byte equality check. Transparency, text and world must all remain exact.
			for dy in 2:
				for dx in 2:
					var at:=((base.y+dy)*640+base.x+dx)*3
					for channel in 3:protected[at+channel]=actual[at+channel]
		for i in range(0,item.points.size(),37):
			var point:Vector2i=item.points[i].at
			var expected:=bilinear(donor,(Vector2(point)+Vector2(0.75,0.75))/Vector2(item.size))
			check(near(image.get_pixelv((Vector2i(37,59)+point)*2+Vector2i.ONE),expected),"actual selected portrait donor/filter "+label)
			probes+=1
	check(protected==actual,"every pixel outside original opaque coverage preserved "+label)
	check(image.save_png(output.path_join(label+".png"))==OK,"save native "+label)
	samples.append({"label":label,"id":portraits.active.get("id",-1),"donor_probes":probes})

func run()->void:
	var root_path:=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args:=OS.get_cmdline_user_args();native="--native" in args
	output=root_path.path_join("artifacts/finish-20260928/portrait-headless")
	if "--output" in args:output=args[args.find("--output")+1]
	check(DirAccess.make_dir_recursive_absolute(output)==OK,"output directory")
	view=SubViewport.new();view.size=Vector2i(640,400);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	background=TextureRect.new();background.size=view.size;background.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;view.add_child(background)
	portraits=Portraits.new();portraits.size=view.size;view.add_child(portraits)
	information=Information.new();information.size=view.size;view.add_child(information)
	check(portraits.load_sources(root_path),"four popup donor assets pinned and loaded")
	check(portraits.templates.size()==4,"popup denominator is four")
	check(information.load_sources(root_path),"crew page assets pinned and loaded")
	if portraits.templates.size()!=4 or information.catalog.is_empty():finish();return
	var source:=Image.create_empty(320,200,false,Image.FORMAT_RGB8)
	var mask:=Image.create_empty(320,200,false,Image.FORMAT_L8);mask.fill(Color.WHITE)
	for id in 4:
		var item:Dictionary=portraits.templates[id]
		check(item.name==ROLES[id],"source role mapping "+str(id))
		check(information.textures["crew-"+ROLES[id]].get_image().get_data()==item.texture.get_image().get_data(),"same authored role donor in crew and popup "+ROLES[id])
		source.fill(Color8(85,85,85))
		for point in item.points:source.set_pixelv(Vector2i(37,59)+point.at,Color.hex(point.rgb))
		portraits.set_frame(source,mask,{})
		check(portraits.active.get("id")==id,"first complete face binds before any caption "+ROLES[id])
		if native:await render_portrait(source,"fixture-"+ROLES[id])
		portraits.set_frame(source,mask,{"messages":[{"channel":"radio","speaker":(id+1)%4}],"text_runs":[{"kind":"crew_primary","speaker":(id+1)%4}]})
		check(portraits.active.get("id")==id,"radio/wrong speaker cannot override visible source")
		var at:Vector2i=Vector2i(37,59)+item.points[0].at
		var colour:=source.get_pixelv(at);source.set_pixelv(at,Color.MAGENTA)
		portraits.set_frame(source,mask,{})
		check(portraits.active.is_empty(),"partial/overwritten face rejects")
		source.set_pixelv(at,colour);mask.set_pixelv(at,Color.BLACK);portraits.set_frame(source,mask,{})
		check(portraits.active.is_empty(),"missing UI ownership rejects")
		mask.fill(Color.WHITE)
	var lifecycle:=root_path.path_join("artifacts/pc-portrait-lifecycle-trace-01")
	var visible:=0
	for frame in range(3570,3716):
		source=Image.load_from_file(lifecycle.path_join("text-%05d.png"%frame))
		mask=Image.load_from_file(lifecycle.path_join("text-%05d-mask.png"%frame))
		check(source!=null and mask!=null,"captured original lifecycle frame "+str(frame))
		if source==null or mask==null:continue
		portraits.set_frame(source,mask,{})
		var expected:=2 if frame>=3583 and frame<3690 else -1
		check(portraits.active.get("id",-1)==expected,"current renderer exact first-frame/clear lifecycle "+str(frame))
		if expected==2:visible+=1
		if native and frame in [3583,3600,3690]:await render_portrait(source,"driver-%d"%frame)
	check(visible==107,"107 consecutive complete driver frames, no caption-delay flash")
	portraits.clear()
	var crew:=Image.load_from_file(root_path.path_join("artifacts/pc-information-baseline-02/crew.png"))
	check(information.set_frame(crew,{"name":"START"}),"exact original crew page binds")
	var layers:Array=information.active.get("layers",[]).filter(func(layer):return layer.name in ["crew-commander","crew-gunner","crew-driver","crew-loader"])
	check(layers.size()==4,"crew page portrait denominator four, diagram separate")
	if native:
		var image:=await snapshot(crew)
		for layer in layers:
			var donor:Image=information.textures[layer.name].get_image()
			var r:Array=layer.rect
			for y in range(3,int(r[3]),9):
				for x in range(3,int(r[2]),9):
					var p:=Vector2i((int(r[0])+x)*2+1,(int(r[1])+y)*2+1)
					check(near(image.get_pixelv(p),bilinear(donor,Vector2(x+0.75,y+0.75)/Vector2(r[2],r[3]))),"actual crew role donor/filter "+layer.name)
		check(image.save_png(output.path_join("crew-all-four.png"))==OK,"save crew native")
		information.clear()
	check(not information.set_frame(crew,{"name":"SIM"}),"crew page wrong program fails closed")
	finish()

func finish()->void:
	if finished:return
	finished=true
	if not output.is_empty():
		var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
		if file:file.store_string(JSON.stringify({"checks":checks,"errors":errors,"native":native,"samples":samples,"elapsed_ms":Time.get_ticks_msec()-started,"scope":"Four exact popup fixtures, four source crew-page roles and 146 recorded driver frames. Fixture identity proof is separate from spontaneous in-game occurrence."},"  "))
	for error in errors:printerr("FAIL: "+error)
	print("PC_PORTRAIT_COVERAGE: %d checks, %d errors, %d ms"%[checks,errors.size(),Time.get_ticks_msec()-started])
	quit(0 if errors.is_empty() else 1)
