extends SceneTree
const Route=preload("res://scripts/pc_frontdoor_route.gd")
const Menu=preload("res://scripts/pc_play_menu.gd")
var checks:=0
var errors:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:errors.append(label)
func run(source:Image,text:String,rect:Array,foreground:=1)->Dictionary:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	hash.update(source.get_region(Rect2i(rect[0],rect[1],rect[2],rect[3])).get_data())
	return {"text":text,"rect":rect.map(func(value):return float(value)),"foreground":foreground,"pixel_sha256":hash.finish().hex_encode()}
func _initialize()->void:
	var source:=Image.create(320,200,false,Image.FORMAT_RGB8)
	source.fill(Color.BLUE)
	var program:={"name":"START","psp":477,"load_segment":493}
	var packet:={"frontend_program":program,"text_runs":[]}
	for i in 4:packet.text_runs.append(run(source,Route.ROOT_LABELS[i],Route.ROOT_RECTS[i],4 if i==0 else 1))
	var route:=Route.new()
	check(route.classify(source,program,packet).selected==0,"verified root highlight")
	var malformed:=packet.duplicate(true)
	malformed.text_runs[0].pixel_sha256="bad"
	check(route.classify(source,program,malformed).selected==-1,"pixel mismatch rejected")
	malformed=packet.duplicate(true);malformed.text_runs[0].rect=[21,12,64,8]
	check(route.classify(source,program,malformed).selected==-1,"wrong root position rejected")
	malformed=packet.duplicate(true);malformed.text_runs[1].foreground=4
	check(route.classify(source,program,malformed).selected==-1,"two highlights rejected")
	malformed=packet.duplicate(true);malformed.frontend_program={"name":"START","psp":999}
	check(route.classify(source,program,malformed).selected==-1,"unpaired program rejected")
	var campaign:=packet.duplicate(true)
	campaign.text_runs.append(run(source,"BEGIN",[116,24,40,8],4))
	check(route.classify(source,program,campaign)=={"selected":-1,"submenu":"campaign"},"Campaign dropdown never counts as root")
	campaign.text_runs[-1].pixel_sha256="bad"
	check(route.classify(source,program,campaign).selected==-1,"invalid extra modal run prevents root recognition")
	var name:=packet.duplicate(true);name.text_runs.append(run(source,"NAME:",[84,24,40,8]))
	check(route.classify(source,program,name).selected==-1,"campaign name input never counts as root")
	route.phase="playing"
	route.observe(source,program,packet,100)
	route.observe(source,program,packet,189)
	check(not route.return_ready,"transitional root remains original")
	route.observe(source,program,packet,190)
	check(route.return_ready,"settled source root may return to cover")
	route.rest()
	check(route.begin("campaign"),"campaign selection begins")
	check(route.next_step()==[3,["right"]],"moves toward observed selection")
	check(route.next_step()==[30,[]],"releases arrow before re-observation")
	packet.text_runs[0].foreground=1;packet.text_runs[1].foreground=4
	route.observe(source,program,packet,220)
	check(route.next_step()==[3,["return"]],"opens only verified selected Campaign")
	check(route.next_step()==[60,[]],"releases Enter without selecting Begin")
	campaign=packet.duplicate(true);campaign.text_runs.append(run(source,"BEGIN",[116,24,40,8],4))
	route.observe(source,program,campaign,283)
	check(route.next_step().is_empty() and route.phase=="playing","hands original Campaign dropdown to player")
	var boot:=Route.new();boot.begin("scenario")
	var canonical:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pc_boot_steps.json"))
	check(Route.BOOT_STEPS.size()==10,"runtime bootstrap has exactly the observed prefix")
	for i in 10:check(Route.BOOT_STEPS[i][0]==int(canonical[i][0]) and Route.BOOT_STEPS[i][1]==canonical[i][1],"runtime bootstrap matches observed fixture")
	while not boot.steps.is_empty():check(boot.next_step()[0]<=60,"bounded original-frame batch")
	boot.next_step()
	check(boot.phase=="fallback" and boot.steps.is_empty(),"boot mismatch stops keys without retry")
	var menu:=Menu.new()
	menu.config_path="";menu.quality_config_path="";menu.frontdoor_active=true
	var tab:=InputEventKey.new();tab.keycode=KEY_TAB;tab.pressed=true
	check(not menu.handle_shortcut(tab),"Tab belongs to cover keyboard focus")
	check(not menu.request_state("save_state",1) and not menu.busy,"cover blocks save mutations")
	check(not menu.request_state("load_state",0),"cover blocks hidden loads")
	check(not menu.choose_speed(8),"cover blocks hidden fast-forward")
	menu.free()
	print("PC_FRONTDOOR: %d checks, %d errors"%[checks,errors.size()])
	for error in errors:printerr("FAIL: "+error)
	quit(0 if errors.is_empty() else 1)
