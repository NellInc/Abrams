extends Control
## Resolution-independent instrument panel; actual buttons retain keyboard focus.
var main: Node3D
var heading_font: Font = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
var mono: Font = preload("res://assets/fonts/IBMPlexMono-Regular.ttf")
var cream := Color("e3e4cd")
var muted := Color("9aa592")
var amber := Color("e7b566")
var green := Color("c5e1ac")
var panel := Color(0.055,0.076,0.062,0.94)
var buttons: Array[Dictionary] = []
var gradient_texture: GradientTexture2D
var reload_seen := 0
var reload_span := 0
const STATIONS := ["GUNNER", "COMMANDER", "CUPOLA", "DRIVER"]
const WEAPONS := ["HEAT", "SABOT", "AX", "M240"]
const MISSIONS := [
	["NUREMBERG HIGHWAY", "Clear the highway and reopen the supply route."],
	["MASS DESTRUCTION", "Find and destroy three enemy bases."],
	["THE ROAD TO BONN", "Destroy the Mainz bridge. Eliminate the recon team."],
	["HANNOVER PUSH", "Strike the Soviet base and communications fort."],
	["CONVOY", "Bring five supply trucks safely to Weller base."],
	["THE MOSSEL INTERCEPT", "Reach the disabled Allied tanks and escort them home."],
	["THE MOSSEL DEFENSE", "Hold the defensive position against the attacking force."],
	["SIEGEN INFILTRATION", "Locate and destroy the concealed enemy base."],
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = Gradient.new()
	gradient_texture.gradient.colors = PackedColorArray([Color(0.018,0.032,0.023,0.90),Color(0.018,0.032,0.023,0)])
	gradient_texture.fill_from = Vector2(0,0)
	gradient_texture.fill_to = Vector2(1,0)
	resized.connect(_layout_buttons)

func text(at: Vector2, value: String, font_size := 18, color := Color("e3e4cd"), condensed := false) -> void:
	draw_string(heading_font if condensed else mono,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func line(a: Vector2, b: Vector2, color := Color("505c49"), width := 1.0) -> void:
	draw_line(a,b,color,width,true)

func rect(r: Rect2, color: Color, outline := false) -> void:
	if outline:
		draw_rect(r,color,false,1.0)
	else:
		draw_rect(r,color)

func rebuild_buttons() -> void:
	for entry in buttons:
		remove_child(entry.node)
		entry.node.queue_free()
	buttons.clear()
	if main.screen == "menu":
		button("01    ENTER THE RANGE",Rect2(90,515,420,54),main.start_range)
		button("02    FIELD MANUAL",Rect2(90,577,420,54),func(): main.set_screen("manual"))
		button("03    RECONSTRUCTION RECORD",Rect2(90,639,420,54),func(): main.set_screen("record"))
		button("04    ORIGINAL / REMASTER ART",Rect2(90,701,420,54),func(): get_tree().change_scene_to_file("res://scenes/art_review.tscn"))
	elif main.screen in ["manual","record"]:
		button("BACK TO GARAGE    [ESC]",Rect2(90,780,420,54),func(): main.set_screen("menu"))
	elif main.paused:
		button("RESUME",Rect2(588,263,424,52),func(): main.paused=false; rebuild_buttons())
		button("SAVE RANGE STATE",Rect2(588,325,424,52),main.save_range)
		button("RESTORE RANGE STATE",Rect2(588,387,424,52),main.load_range)
		button("VOICE   " + ("ON" if main.sound.voice_enabled else "OFF"),Rect2(588,449,204,48),func(): main.sound.voice_enabled = not main.sound.voice_enabled; main.sound.voice.stop(); rebuild_buttons())
		button("CAPTIONS   " + ("ON" if main.subtitles else "OFF"),Rect2(808,449,204,48),func(): main.subtitles = not main.subtitles; rebuild_buttons())
		button("CAMERA MOTION   " + ("OFF" if main.reduced_motion else "ON"),Rect2(588,507,424,48),func(): main.reduced_motion = not main.reduced_motion; rebuild_buttons())
		button("SOUND   " + ("OFF" if main.sound.muted else "ON"),Rect2(588,565,424,48),func(): main.sound.muted = not main.sound.muted; main.sound.stop_all(); rebuild_buttons())
		button("RETURN TO GARAGE",Rect2(588,638,424,52),func(): main.set_screen("menu"))
	elif main.sim.status != "active":
		button("RESTART RANGE",Rect2(580,540,440,58),main.start_range)
		button("RETURN TO GARAGE",Rect2(580,612,440,58),func(): main.set_screen("menu"))
	_layout_buttons()
	if not buttons.is_empty():
		buttons[0].node.grab_focus()

func button(label: String, area: Rect2, action: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font",mono)
	b.add_theme_font_size_override("font_size",18)
	b.add_theme_color_override("font_color",cream)
	b.add_theme_color_override("font_hover_color",Color("0c160e"))
	b.add_theme_color_override("font_focus_color",amber)
	for state in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.045,0.064,0.05,0.78)
		style.border_color = Color("65745a")
		style.border_width_bottom = 1
		style.content_margin_left = 18
		if state in ["hover","pressed"]:
			style.bg_color = amber
		elif state == "focus":
			style.bg_color = Color(0,0,0,0)
			style.border_color = amber
			style.set_border_width_all(1)
		b.add_theme_stylebox_override(state,style)
	b.pressed.connect(action)
	b.mouse_entered.connect(func(): main.sound.play("switch"))
	add_child(b)
	buttons.append({"node":b,"rect":area})

func _layout_buttons() -> void:
	var factor := size / Vector2(1600,900)
	for entry in buttons:
		entry.node.position = entry.rect.position*factor
		entry.node.size = entry.rect.size*factor
		entry.node.add_theme_font_size_override("font_size",maxi(12,int(18*factor.y)))

func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,size/Vector2(1600,900))
	match main.screen:
		"menu": _menu()
		"manual": _manual()
		"record": _record()
		"range": _instruments()
	if main.notice_time > 0:
		rect(Rect2(430,740,740,46),panel)
		text(Vector2(452,770),main.notice,16,amber)

func _page_header(kicker: String, title: String, description: String) -> void:
	rect(Rect2(0,0,1600,900),Color(0.034,0.051,0.04,0.96))
	text(Vector2(90,67),"ABRAMS  /  " + kicker,16,amber)
	line(Vector2(90,88),Vector2(1510,88))
	text(Vector2(86,173),title,68,cream,true)
	text(Vector2(90,213),description,16,muted)

func _menu() -> void:
	# A graduated legibility veil leaves the vehicle and sky as the cover artwork.
	draw_texture_rect(gradient_texture,Rect2(0,0,1150,900),false)
	rect(Rect2(0,810,1600,90),Color(0.025,0.045,0.03,0.78))
	rect(Rect2(0,0,1600,90),Color(0.025,0.045,0.03,0.65))
	text(Vector2(90,55),"DYNAMIX'S 1988 CLASSIC  /  RECONSTRUCTION PROJECT",15,cream)
	text(Vector2(1290,55),"LOCAL BUILD  001",14,amber)
	line(Vector2(90,90),Vector2(1510,90),Color(0.8,0.8,0.6,0.3))
	text(Vector2(90,212),"M1A1  /  MAIN BATTLE TANK",18,amber)
	text(Vector2(81,350),"ABRAMS",154,cream,true)
	text(Vector2(91,410),"B A T T L E   T A N K",32,cream,true)
	line(Vector2(92,441),Vector2(160,441),amber,3)
	text(Vector2(90,479),"BACK IN THE COMMANDER'S SEAT.",18,muted)
	text(Vector2(90,786),"PC gameplay. Genesis-inspired artwork.",14,muted)
	line(Vector2(90,822),Vector2(1510,822))
	text(Vector2(90,858),"GODOT 4  /  HIGH-RESOLUTION PRESENTATION",13,cream)
	text(Vector2(822,858),"CALIBRATION RANGE AVAILABLE  /  CAMPAIGN IN RECONSTRUCTION",13,amber)
	text(Vector2(1196,727),"120 MM",44,cream,true)
	text(Vector2(1347,727),"4 CREW",44,cream,true)
	text(Vector2(1197,754),"MAIN GUN",12,muted)
	text(Vector2(1348,754),"STATIONS",12,muted)

func _manual() -> void:
	_page_header("FIELD MANUAL","KNOW YOUR STATION","Original DOS key layout. The current exercise is an authored calibration range.")
	var columns := [90,580,1080]
	var labels := ["01   CREW STATIONS","02   GUNNERY","03   DRIVING & SYSTEMS"]
	for i in range(3):
		text(Vector2(columns[i],280),labels[i],20,amber,true)
		line(Vector2(columns[i],298),Vector2(columns[i]+410,298))
	var station_lines := [["F1","Gunner: sight, target and fire"],["F2","Commander: survey the field"],["F3","Cupola: elevated observation"],["F4","Driver: low hull view"],["F7-F10","Commander scan: 0 / 90 / 180 / 270"],["ESC","Pause and range settings"],["H","Show the controls overlay"]]
	var gun_lines := [["1 / 2 / 3","HEAT / SABOT / AX"],["M","Fire machine gun directly"],["ENTER","Select a target in the sight"],["L","Lock selected target"],["SPACE","Fire selected main round"],["A","Align turret with hull"],["Z / T","1x / 3x / 10x; thermal"]]
	var system_lines := [["ARROWS","Drive or rotate turret"],["C","Hull / turret control"],["R","Radio report"],["S","Deploy smoke"],["D","Damage panel"],["F5","Sound on / off"],["Q","Open pause / return menu"]]
	var groups := [station_lines,gun_lines,system_lines]
	for column in range(3):
		for row in range(groups[column].size()):
			var pair: Array = groups[column][row]
			var y := 344+row*49
			text(Vector2(columns[column],y),pair[0],16,cream)
			text(Vector2(columns[column],y+21),pair[1],13,muted)
	line(Vector2(90,710),Vector2(1510,710))
	text(Vector2(90,745),"RANGE DRILL: Enter, L, Space. Select the next target and choose the appropriate ammunition.",16,green)
	text(Vector2(580,814),"Manual-derived controls. Numerical behaviour still under comparison.",14,muted)

func _record() -> void:
	_page_header("RECONSTRUCTION RECORD","EIGHT MISSIONS. ONE STANDARD.","Original data recovered locally. Original campaign play remains unavailable until its rules are verified.")
	for i in range(MISSIONS.size()):
		var col := i/4
		var row := i%4
		var x := 90 + col*770
		var y := 295 + row*108
		text(Vector2(x,y),"%02d" % (i+1),25,amber,true)
		text(Vector2(x+56,y),MISSIONS[i][0],28,cream,true)
		text(Vector2(x+56,y+29),MISSIONS[i][1],13,muted)
		line(Vector2(x,y+53),Vector2(x+680,y+53))
	text(Vector2(90,745),"REFERENCE: DOS executable + eight scenario/world pairs + original manual.",16,green)
	text(Vector2(580,814),"Parity requires observed behaviour, repeatable traces and matching outcomes.",14,muted)

func _instruments() -> void:
	var sim = main.sim
	var optic: bool = sim.station <= 1
	var tint := Color("1b2a19") if not sim.thermal else Color("ecffe6")
	if sim.thermal and optic:
		rect(Rect2(0,0,1600,900),Color(0.1,0.23,0.08,0.24))
	# Periscope frame keeps the original instrument-centric character at any resolution.
	rect(Rect2(0,0,1600,88),panel)
	rect(Rect2(0,730,1600,170),panel)
	rect(Rect2(0,88,52,642),panel)
	rect(Rect2(1548,88,52,642),panel)
	line(Vector2(52,88),Vector2(1548,88),muted)
	line(Vector2(52,730),Vector2(1548,730),muted)
	text(Vector2(80,39),"M1A1  /  " + STATIONS[sim.station],23,cream,true)
	text(Vector2(80,66),"CALIBRATION RANGE",13,amber)
	text(Vector2(1260,39),"%02d:%02d" % [sim.elapsed_ticks/3600,(sim.elapsed_ticks/60)%60],24,cream)
	text(Vector2(1260,65),"H  CONTROLS   ESC  PAUSE",13,muted)
	_compass()
	if optic:
		_reticle(tint)
	elif sim.station == 3:
		# Driver sees through three narrow periscopes.
		rect(Rect2(52,88,1496,190),panel)
		rect(Rect2(52,575,1496,155),panel)
		rect(Rect2(490,278,26,298),panel)
		rect(Rect2(1084,278,26,298),panel)
		text(Vector2(80,689),"DRIVER PERISCOPE   /   HULL BEARING",17,muted)
	else:
		text(Vector2(85,122),"CUPOLA   /   OBSERVATION",15,muted)
		line(Vector2(785,450),Vector2(815,450),tint)
		line(Vector2(800,435),Vector2(800,465),tint)
	if sim.selected_target >= 0 and optic:
		var target: Dictionary = sim.targets[sim.selected_target]
		var at := Vector3(target.pos.x,1.8,target.pos.y)
		if not main.camera.is_position_behind(at):
			var p: Vector2 = main.camera.unproject_position(at)*Vector2(1600,900)/size
			if Rect2(72,100,1456,605).has_point(p):
				rect(Rect2(p-Vector2(26,21),Vector2(52,42)),tint,true)
				text(p+Vector2(34,-15),"LOCK" if sim.locked else "SELECT",13,tint)
				text(p+Vector2(34,8),"%04d M" % int(sim.pos.distance_to(target.pos)),13,tint)
	# Bottom instrument strip.
	for x in [334,642,1000,1288]:
		line(Vector2(x,752),Vector2(x,837))
	text(Vector2(82,766),"SPEED / KM/H",13,muted)
	text(Vector2(78,821),"%02d" % int(absf(sim.speed)*3.6),55,cream,true)
	text(Vector2(178,798),"HULL" if sim.control_hull else "TURRET",22,amber,true)
	text(Vector2(178,822),"C  SWITCH CONTROL",11,muted)
	text(Vector2(363,766),"READY ROUNDS",13,muted)
	for i in range(3):
		var color: Color = amber if sim.weapon == i else muted
		text(Vector2(363+i*86,797),WEAPONS[i],16,color,true)
		text(Vector2(363+i*86,827),"%02d" % int(sim.ammo[i]),26,color,true)
	text(Vector2(674,766),"WEAPON SYSTEM",13,muted)
	text(Vector2(674,808),WEAPONS[sim.weapon],36,cream,true)
	var ready: bool = (sim.mg_cooldown_ticks == 0) if sim.weapon == 3 else (sim.reload_ticks == 0)
	text(Vector2(804,803),"READY" if ready else "LOADING",22,green if ready else amber,true)
	var main_loaded := reload_fraction(sim.reload_ticks)
	var loaded := 1.0 - clampf(float(sim.mg_cooldown_ticks)/float(sim.rules.reload_ticks[3]),0,1) if sim.weapon == 3 else main_loaded
	rect(Rect2(805,816,153,3),Color("3b4536"))
	rect(Rect2(805,816,153*loaded,3),green)
	text(Vector2(1028,766),"SYSTEMS",13,muted)
	text(Vector2(1028,799),"FUEL   %03d GAL" % int(sim.fuel),16,cream)
	text(Vector2(1028,823),"HULL   %03d %%" % int(sim.hull),16,cream)
	text(Vector2(1318,766),"M240 / SMOKE",13,muted)
	text(Vector2(1318,814),"%02d / %d" % [sim.ammo[3],sim.smoke_count],36,cream,true)
	line(Vector2(80,846),Vector2(1520,846))
	text(Vector2(80,879),"F1 GUNNER    F2 COMMANDER    F3 CUPOLA    F4 DRIVER",13,muted)
	text(Vector2(929,879),"ENTER SELECT   L LOCK   SPACE FIRE   Z ZOOM",13,amber)
	if main.subtitles and main.subtitle_time > 0:
		rect(Rect2(280,663,1040,45),Color(0.025,0.04,0.025,0.88))
		text(Vector2(302,693),main.subtitle,17,cream)
	if main.show_damage:
		rect(Rect2(104,130,430,220),panel)
		text(Vector2(128,172),"VEHICLE STATUS",30,amber,true)
		text(Vector2(128,212),"HULL INTEGRITY   %03d %%" % int(sim.hull),16,cream)
		text(Vector2(128,244),"FUEL             %03d GAL" % int(sim.fuel),16,cream)
		text(Vector2(128,277),"Practice targets do not return fire.",13,muted)
		text(Vector2(128,310),"D  CLOSE",13,amber)
	if sim.station == 1:
		_commander_map()
	if main.show_help:
		rect(Rect2(980,115,535,302),panel)
		text(Vector2(1004,154),"RANGE CONTROLS",29,amber,true)
		var rows := ["ARROWS drive / turn    C hull / turret","1 HEAT   2 SABOT   3 AX   M machine gun","ENTER select   L lock   SPACE fire","A align   T thermal   Z zoom","S smoke   R radio   D damage","F1-F4 stations   F7-F10 scan   H close"]
		for i in range(rows.size()):
			text(Vector2(1004,195+i*34),rows[i],14,cream)
	if main.paused:
		_pause()
	elif sim.status != "active":
		_debrief()

# Loaded fraction of the main-gun reload in progress. A rise in reload ticks marks a new shot, whose length
# is the span; weapon changes mid-reload therefore cannot mix up divisors (AX reloads 300 ticks, HEAT/SABOT 240).
func reload_fraction(ticks: int) -> float:
	if ticks > reload_seen or reload_span < ticks:
		reload_span = ticks
	reload_seen = ticks
	return 1.0 - clampf(float(ticks)/float(maxi(reload_span,1)),0,1)

func _compass() -> void:
	var bearing: float = fposmod(-rad_to_deg(main.view_bearing()),360.0)
	for i in range(-4,5):
		var degrees := int(round(bearing/10.0))*10 + i*10
		var x := 800.0+(degrees-bearing)*7
		line(Vector2(x,48),Vector2(x,57),muted)
		text(Vector2(x-13,35),"%03d" % posmod(degrees,360),13,muted)
	draw_colored_polygon(PackedVector2Array([Vector2(793,66),Vector2(807,66),Vector2(800,56)]),amber)
	text(Vector2(772,81),"%03d" % int(bearing),16,amber)

func _reticle(tint: Color) -> void:
	var center := Vector2(800,450)
	# Horizontal stadia leave the target center unobstructed.
	line(center+Vector2(-230,0),center+Vector2(-28,0),tint)
	line(center+Vector2(28,0),center+Vector2(230,0),tint)
	line(center+Vector2(0,-110),center+Vector2(0,-26),tint)
	line(center+Vector2(0,24),center+Vector2(0,120),tint)
	for i in [-4,-3,-2,-1,1,2,3,4]:
		var x := float(i)*48
		line(center+Vector2(x,-7),center+Vector2(x,7),tint)
		text(center+Vector2(x-5,26),str(absi(i)*5),11,tint)
	for i in range(1,5):
		line(center+Vector2(-7,i*24),center+Vector2(7,i*24),tint)
	draw_circle(center,2,tint)
	text(Vector2(87,125),"GPS   /   " + ("THERMAL" if main.sim.thermal else "DAY OPTIC"),15,tint)
	text(Vector2(1390,125),["1X","3X","10X"][main.sim.zoom_level] if main.sim.station == 0 else "WIDE",15,tint)
	text(Vector2(88,637),"TADS  " + ("LOCKED" if main.sim.locked else "SEARCH"),15,tint)
	text(Vector2(1240,637),"%s  %02d" % [WEAPONS[main.sim.weapon], main.sim.ammo[main.sim.weapon]],18,tint)

func _commander_map() -> void:
	var area := Rect2(88,138,440,430) if not main.map_overview else Rect2(410,115,780,590)
	rect(area,panel)
	text(area.position+Vector2(24,36),"RANGE MAP  /  Z " + ("CLOSE" if main.map_overview else "OVERVIEW"),18,amber,true)
	var inner := Rect2(area.position+Vector2(24,65),area.size-Vector2(48,88))
	for i in range(9):
		line(inner.position+Vector2(inner.size.x*i/8,0),inner.position+Vector2(inner.size.x*i/8,inner.size.y),Color("35452e"))
		line(inner.position+Vector2(0,inner.size.y*i/8),inner.position+Vector2(inner.size.x,inner.size.y*i/8),Color("35452e"))
	# Overview shows the whole drivable range (padded bounds); close keeps the target-lane window.
	var b: Array = main.sim.range_data.bounds
	var extent := Rect2(b[0]-100,b[2]-100,b[1]-b[0]+200,b[3]-b[2]+200) if main.map_overview else Rect2(-450,-1400,900,1750)
	for target in main.sim.targets:
		var p: Vector2 = map_point(target.pos,inner,extent)
		draw_circle(p,5.0,amber if target.alive else muted)
		if extent.has_point(target.pos):
			text(p+Vector2(10,4),target.name,12,cream)
	var pos: Vector2 = main.sim.pos
	var p: Vector2 = map_point(pos,inner,extent)
	draw_circle(p,6.0,green)
	if extent.has_point(pos):
		line(p,p+Vector2(-sin(main.sim.heading),-cos(main.sim.heading))*22,green,2)
		text(p+Vector2(11,4),"M1",12,green)
	else:
		# Off-map: pin the marker to the edge and point it towards the tank.
		var outward: Vector2 = (pos-extent.get_center()).normalized()
		line(p,p+outward*16,green,2)
		text(p+Vector2(-16,-12) if p.y > inner.get_center().y else p+Vector2(-16,22),"M1",12,green)

# World x/z to map point, clamped onto the map edge when outside the shown extent.
static func map_point(world: Vector2, inner: Rect2, extent: Rect2) -> Vector2:
	var p: Vector2 = inner.position+(world-extent.position)/extent.size*inner.size
	return Vector2(clampf(p.x,inner.position.x,inner.end.x),clampf(p.y,inner.position.y,inner.end.y))

func _pause() -> void:
	rect(Rect2(0,0,1600,900),Color(0.01,0.018,0.012,0.80))
	rect(Rect2(550,150,500,572),panel)
	text(Vector2(588,224),"EXERCISE PAUSED",47,cream,true)
	line(Vector2(588,240),Vector2(1012,240),amber)

func _debrief() -> void:
	rect(Rect2(0,0,1600,900),Color(0.01,0.018,0.012,0.86))
	text(Vector2(580,250),"RANGE DEBRIEF",18,amber)
	text(Vector2(580,326),"EXERCISE COMPLETE" if main.sim.status == "won" else "EXERCISE ENDED",52,cream,true)
	line(Vector2(580,356),Vector2(1020,356))
	text(Vector2(580,399),"ROUNDS FIRED      %03d" % main.shots,19,cream)
	text(Vector2(580,438),"HITS REGISTERED   %03d" % main.hit_count,19,cream)
	text(Vector2(580,484),"Calibration results, not campaign scoring.",14,muted)
