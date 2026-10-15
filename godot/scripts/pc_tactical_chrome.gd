extends Control
## Tactical framing. Live instruments and map remain source-verified.
var wide_station := 0
var station := 0
var instruments = preload("res://scripts/pc_tactical_instruments.gd").new()
var map_art = preload("res://scripts/pc_tactical_map.gd").new()

func _init() -> void:
	add_child(instruments)
	instruments.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(map_art)
	map_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
const STATIONS := {1:"GUNNER",2:"COMMANDER",3:"CUPOLA",4:"DRIVER",5:"SYSTEMS STATUS"}
const ROLES := {1:"TACTICAL OPTIC",2:"COMMAND & NAVIGATION",3:"CUPOLA VIEW",4:"DRIVER VIEW",5:"VEHICLE SYSTEMS"}
var fallback_tactical := false
var frame_rect := Rect2i()
var heading_font: Font = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
var mono: Font = preload("res://assets/fonts/IBMPlexMono-Regular.ttf")
const CREAM := Color("e3e4cd")
const MUTED := Color("c1ccba")
const AMBER := Color("e7b566")
const RULE := Color("526b58")
const COMMANDS := {1:[["ENTER","SELECT"],["L","LOCK"],["SPACE","FIRE"]],
	2:[["Z","MAP"],["F7-F10","SCAN"],["D","STATUS"]],
	3:[["A","ALIGN TURRET"],["C","HULL/TURRET"]],
	4:[["KEYPAD","DRIVE"],["KP5","STOP"]],5:[["ANY KEY","RETURN TO COMMANDER"]]}
const FALLBACK_ACTIONS := {1:[["ENTER","SELECT"],["L","LOCK"],["SPACE","FIRE"]],
	2:[["Z","MAP"],["F7-F10","SCAN"],["D","STATUS"]],
	3:[["A","ALIGN TURRET"],["C","HULL/TURRET"]],
	4:[["KEYPAD","DRIVE"],["KP5","STOP"]],5:[["ANY KEY","RETURN"]]}
# Original heading baselines; rules stop inside their own column. The map
# heading reserves the right-hand LOCAL/OVERVIEW keycap's existing space.
const SECTIONS := {1:[
	["TARGET  /  RANGE",Vector2(88,700),320.0],["HULL  /  SPEED",Vector2(445,700),312.0],
	["NAVIGATION",Vector2(800,700),260.0],["MAIN GUN",Vector2(1094,700),210.0],
	["SYSTEMS",Vector2(1336,700),192.0]],
	2:[["TACTICAL MAP",Vector2(88,348),396.0],["NAVIGATION",Vector2(744,348),352.0],
	["SYSTEMS",Vector2(1144,348),368.0],["HULL  /  SPEED",Vector2(744,735),352.0],
	["FUEL",Vector2(1144,735),368.0]],
	5:[["STORES",Vector2(1040,108),320.0],["SYSTEMS & DAMAGE",Vector2(88,451),1424.0]]}

func _frame_scale() -> float:
	return maxf(0.01,minf(size.x/1600.0,size.y/900.0))

func _stroke(width: float) -> float:
	return maxf(width,1.0/(_frame_scale() if not fallback_tactical else 1.0))

func _corners(box: Rect2, length: float=12.0) -> void:
	for x in [box.position.x,box.end.x]:
		for y in [box.position.y,box.end.y]:
			var at:=Vector2(x,y)
			draw_line(at,at+Vector2(length if x==box.position.x else -length,0),CREAM,_stroke(1.2),true)
			draw_line(at,at+Vector2(0,length if y==box.position.y else -length),CREAM,_stroke(1.2),true)

func _key_width(key: String, label: String, point: int) -> float:
	return mono.get_string_size(key,HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(9,point-2)).x+10+mono.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,point).x+26

func _key(at: Vector2, key: String, label: String, selected: bool=false, point: int=15, command: bool=false) -> float:
	var key_point:=maxi(9,point-2)
	var width:=mono.get_string_size(key,HORIZONTAL_ALIGNMENT_LEFT,-1,key_point).x+10
	var box:=Rect2(at.x,at.y-point-1,width,point+5)
	draw_rect(box,Color("283a29") if selected else Color("101e16"))
	draw_rect(box,AMBER if selected else RULE,false,_stroke(1),true)
	draw_string(mono,at+Vector2(5,0),key,HORIZONTAL_ALIGNMENT_LEFT,-1,key_point,AMBER if selected or command else CREAM)
	draw_string(mono,at+Vector2(width+8,0),label,HORIZONTAL_ALIGNMENT_LEFT,-1,point,CREAM if selected else MUTED)
	return _key_width(key,label,point)

func _footer_width(id: int, station_point: int, command_point: int) -> Vector2:
	var measured:=Vector2.ZERO
	if id!=5:
		for i in 4: measured.x+=_key_width("F"+str(i+1),STATIONS[i+1],station_point)
	for item in COMMANDS.get(id,[]): measured.y+=_key_width(item[0],item[1],command_point)
	return measured

func _footer_layout(id: int, scale: float) -> Dictionary:
	var station_point:=clampi(ceili(12.0/maxf(scale,0.01)),15,22)
	var command_point:=clampi(ceili(11.0/maxf(scale,0.01)),14,22)
	var measured:=_footer_width(id,station_point,command_point)
	# A measured gap separates station switching from current-station actions.
	while measured.x+measured.y+40>1422 and maxi(station_point,command_point)>9:
		if station_point>=command_point: station_point-=1
		else: command_point-=1
		measured=_footer_width(id,station_point,command_point)
	return {"station_point":station_point,"command_point":command_point,
		"station_width":measured.x,"command_width":measured.y,"command_x":1512-measured.y+18,
		"baseline":872+maxi(station_point,command_point)}

func _header_layout(id: int, scale: float) -> Dictionary:
	var compact:=scale<0.7
	var name: String="M1A1  /  "+STATIONS.get(id,"CREW STATION")
	var role: String=ROLES.get(id,"TACTICAL")
	var title_point:=clampi(ceili(18.0/maxf(scale,0.01)),31,37) if compact else 31
	var role_point:=clampi(ceili(10.0/maxf(scale,0.01)),14,21) if compact else 14
	var title_width:=heading_font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,title_point).x
	var role_at:=Vector2(90+title_width+24,49) if compact else Vector2(90,63)
	while compact and role_point>9 and role_at.x+mono.get_string_size(role,HORIZONTAL_ALIGNMENT_LEFT,-1,role_point).x>1170: role_point-=1
	return {"name":name,"role":role,"title_point":title_point,"role_point":role_point,
		"title_at":Vector2(90,49 if compact else 44),"role_at":role_at,
		"meta_point":clampi(ceili(11.0/maxf(scale,0.01)),15,23) if compact else 15,
		"mode_point":clampi(ceili(11.0/maxf(scale,0.01)),13,23) if compact else 13,
		"meta_at":Vector2(1200,36 if compact else 44),"mode_at":Vector2(1200,62 if compact else 63)}

func gutter_font(words: String, width: float, desired: int, heading: bool=false) -> int:
	var face: Font=heading_font if heading else mono
	var point:=desired
	while point>9 and face.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,point).x>width: point-=1
	return point if face.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,point).x<=width else 0

func gutter_key_font(width: float) -> int:
	for point in range(15,8,-1):
		var key_width:=mono.get_string_size("F4",HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(9,point-2)).x+18
		if key_width+mono.get_string_size("COMMANDER",HORIZONTAL_ALIGNMENT_LEFT,-1,point).x<=width: return point
	return 0

func _gutter_text(at: Vector2, words: String, width: float, desired: int, colour: Color, heading: bool=false) -> void:
	var point:=gutter_font(words,width,desired,heading)
	if point>0: draw_string(heading_font if heading else mono,at,words,HORIZONTAL_ALIGNMENT_LEFT,-1,point,colour)

func _section_layout(at: Vector2, words: String, width: float, scale: float) -> Dictionary:
	var point:=clampi(ceili(12.0/maxf(scale,0.01)),22,26)
	while point>16 and heading_font.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,point).x>width: point-=1
	var label_width:=heading_font.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,point).x
	var y:=at.y-point*0.38
	return {"point":point,"label_width":label_width,
		"rule_from":Vector2(at.x+label_width+16,y),"rule_to":Vector2(at.x+width,y)}

func _section_title(at: Vector2, words: String, width: float) -> void:
	var layout:=_section_layout(at,words,width,_frame_scale())
	draw_string(heading_font,at,words,HORIZONTAL_ALIGNMENT_LEFT,-1,layout.point,MUTED)
	if layout.rule_to.x-layout.rule_from.x>=16:
		draw_line(layout.rule_from,layout.rule_to,RULE,_stroke(1),true)

func _gutter_command_point(key: String, label: String, width: float) -> int:
	for point in range(13,8,-1):
		# _key_width includes an 18px inter-command advance, not painted ink.
		if _key_width(key,label,point)-18<=width: return point
	return 0

func _gutter_role_layout(id: int, width: float) -> Dictionary:
	var role: String=ROLES.get(id,"CREW STATION")
	for point in range(12,8,-1):
		var lines: Array[String]=[]
		var line: String=""
		var fits:=true
		for word in role.split(" "):
			if mono.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,point).x>width: fits=false;break
			var candidate: String=word if line.is_empty() else line+" "+word
			if mono.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,point).x>width:
				lines.append(line);line=word
			else: line=candidate
		if not line.is_empty(): lines.append(line)
		if fits and lines.size()<=2: return {"point":point,"lines":lines}
	return {"point":0,"lines":[]}

func _draw() -> void:
	if fallback_tactical:
		# The untouched 4:3 station remains complete. The spare width belongs to
		# the frame, never to an invented map, instrument or broader camera.
		var margin:=float(frame_rect.position.x)
		if margin>=100.0:
			var available:=margin-44
			draw_line(Vector2(margin-12,frame_rect.position.y),Vector2(margin-12,frame_rect.end.y),RULE,1.0,true)
			draw_line(Vector2(frame_rect.end.x+12,frame_rect.position.y),Vector2(frame_rect.end.x+12,frame_rect.end.y),RULE,1.0,true)
			_gutter_text(Vector2(22,frame_rect.position.y+38),STATIONS.get(station,"ABRAMS").replace("SYSTEMS STATUS","SYSTEMS"),available,26,CREAM,true)
			_gutter_text(Vector2(22,frame_rect.position.y+61),"TACTICAL",available,13,AMBER)
			_gutter_text(Vector2(frame_rect.end.x+28,frame_rect.position.y+42),"PC CAMPAIGN",available,12,MUTED)
			var role:=_gutter_role_layout(station,available)
			for i in role.lines.size():
				draw_string(mono,Vector2(frame_rect.end.x+28,frame_rect.position.y+62+i*18),role.lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,role.point,MUTED)
			if frame_rect.size.y>=300 and STATIONS.has(station):
				# Only spare gutters: the full source frame, including unknown live
				# overlays, remains unobscured and keeps its original projection.
				var y: float=frame_rect.end.y-158
				var point:=gutter_key_font(available)
				if point>0 and station!=5:
					for i in 4: _key(Vector2(22,y+float(i)*34),"F"+str(i+1),STATIONS[i+1],station==i+1,point)
				var hints: Array=FALLBACK_ACTIONS.get(station,[])
				for i in hints.size():
					var command_point:=_gutter_command_point(hints[i][0],hints[i][1],available)
					if command_point>0: _key(Vector2(frame_rect.end.x+28,y+float(i)*28),hints[i][0],hints[i][1],false,command_point,true)
		return
	if wide_station==0: return
	draw_set_transform(Vector2.ZERO,0,size/Vector2(1600,900))
	_corners(Rect2(72,19,1480,875),10)
	var header:=_header_layout(wide_station,_frame_scale())
	draw_string(heading_font,header.title_at,header.name,HORIZONTAL_ALIGNMENT_LEFT,-1,header.title_point,CREAM)
	draw_string(mono,header.role_at,header.role,HORIZONTAL_ALIGNMENT_LEFT,-1,header.role_point,AMBER)
	draw_string(mono,header.meta_at,"PC CAMPAIGN",HORIZONTAL_ALIGNMENT_LEFT,-1,header.meta_point,MUTED)
	draw_string(mono,header.mode_at,"TACTICAL HUD",HORIZONTAL_ALIGNMENT_LEFT,-1,header.mode_point,MUTED)
	if wide_station==1:
		draw_rect(Rect2(87,68,1426,603),RULE,false,2.0)
		_corners(Rect2(87,68,1426,603))
	elif wide_station==2:
		draw_rect(Rect2(87,75,1426,232),RULE,false,2.0)
		_corners(Rect2(87,75,1426,232))
	elif wide_station==3:
		draw_rect(Rect2(87,75,1426,781),RULE,false,2.0)
		_corners(Rect2(87,75,1426,781))
	elif wide_station==4:
		draw_rect(Rect2(87,75,1426,709),RULE,false,2.0)
		_corners(Rect2(87,75,1426,709))
	for item in SECTIONS.get(wide_station,[]): _section_title(item[1],item[0],item[2])
	# Keep the source crew-report strip at y861.3..868.5 untouched. Larger
	# keycaps grow downwards from its existing lower boundary, never over it.
	draw_line(Vector2(88,861),Vector2(1512,861),RULE,1.0,true)
	var footer:=_footer_layout(wide_station,_frame_scale())
	var x:=90.0
	if wide_station!=5:
		for i in 4: x+=_key(Vector2(x,footer.baseline),"F"+str(i+1),STATIONS[i+1],wide_station==i+1,footer.station_point)
	x=footer.command_x
	for item in COMMANDS.get(wide_station,[]): x+=_key(Vector2(x,footer.baseline),item[0],item[1],false,footer.command_point,true)
