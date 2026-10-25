extends Control
## Tactical framing. Live instruments and map remain source-verified.
const FieldPanel = preload("res://scripts/pc_tactical_panel.gd")
var wide_station := 0
var station := 0
var instruments = preload("res://scripts/pc_tactical_instruments.gd").new()
var map_art = preload("res://scripts/pc_tactical_map.gd").new()

func _init() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(instruments)
	instruments.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(map_art)
	map_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
const STATIONS := {1:"GUNNER",2:"COMMANDER",3:"CUPOLA",4:"DRIVER",5:"SYSTEMS STATUS"}
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
	["TARGET  /  RANGE",Vector2(113,672),272.0],["HULL  /  SPEED",Vector2(451,672),278.0],
	["NAVIGATION",Vector2(791,672),235.0],["MAIN GUN",Vector2(1087,672),203.0],
	["SYSTEMS",Vector2(1351,672),163.0]],
	2:[["TACTICAL MAP",Vector2(113,352),362.0],["NAVIGATION",Vector2(753,352),334.0],
	["SYSTEMS",Vector2(1153,352),350.0],["HULL  /  SPEED",Vector2(753,726),334.0],
	["FUEL",Vector2(1153,726),350.0]],
	5:[["STORES",Vector2(1049,105),302.0],["SYSTEMS & DAMAGE",Vector2(97,456),1406.0]]}

func _frame_scale() -> float:
	return maxf(0.01,minf(size.x/1600.0,size.y/900.0))

func _stroke(width: float) -> float:
	return maxf(width,1.0/(_frame_scale() if not fallback_tactical else 1.0))

func _key_width(key: String, label: String, point: int) -> float:
	return mono.get_string_size(key,HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(9,point-2)).x+10+mono.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,point).x+26

func _key(at: Vector2, key: String, label: String, selected: bool=false, point: int=15, command: bool=false) -> float:
	var key_point:=maxi(9,point-2)
	var width:=mono.get_string_size(key,HORIZONTAL_ALIGNMENT_LEFT,-1,key_point).x+10
	var box:=Rect2(at.x,at.y-point-1,width,point+5)
	FieldPanel.recess(self,box,_frame_scale() if not fallback_tactical else 1.0)
	if selected:
		draw_rect(box.grow(-2),Color("393626"))
		draw_rect(box.grow(1),Color(AMBER,0.22),false,_stroke(2),true)
	draw_rect(box,AMBER if selected else RULE,false,_stroke(1),true)
	draw_string(mono,at+Vector2(5,0),key,HORIZONTAL_ALIGNMENT_LEFT,-1,key_point,AMBER if selected or command else CREAM)
	draw_string(mono,at+Vector2(width+8,0),label,HORIZONTAL_ALIGNMENT_LEFT,-1,point,AMBER if selected else MUTED)
	return _key_width(key,label,point)

func _footer_width(id: int, station_point: int, command_point: int) -> Vector2:
	var measured:=Vector2.ZERO
	if id!=5:
		for i in 4: measured.x+=_key_width("F"+str(i+1),STATIONS[i+1],station_point)
	for item in COMMANDS.get(id,[]): measured.y+=_key_width(item[0],item[1],command_point)
	return measured

func _footer_layout(id: int, scale: float) -> Dictionary:
	var station_point:=clampi(ceili(12.0/maxf(scale,0.01)),20,22)
	var command_point:=clampi(ceili(11.0/maxf(scale,0.01)),19,22)
	var measured:=_footer_width(id,station_point,command_point)
	# A measured gap separates station switching from current-station actions.
	while measured.x+measured.y+40>1422 and maxi(station_point,command_point)>9:
		if station_point>=command_point: station_point-=1
		else: command_point-=1
		measured=_footer_width(id,station_point,command_point)
	return {"station_point":station_point,"command_point":command_point,
		"station_width":measured.x,"command_width":measured.y,"command_x":1512-measured.y+18,
		"baseline":862+maxi(station_point,command_point)}

func _header_layout(id: int, scale: float) -> Dictionary:
	var compact:=scale<0.7
	return {"name":"M1A1  /  "+STATIONS.get(id,"CREW STATION"),
		"title_point":clampi(ceili(18.0/maxf(scale,0.01)),36,37) if compact else 36,
		"title_at":Vector2(72 if id==3 else 142,48)}

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
	# A dark title ledge sits inside the physical equipment module.
	draw_rect(Rect2(at.x-3,at.y-layout.point,layout.label_width+10,layout.point+4),Color("101510"))
	draw_string(heading_font,at+Vector2(0,1),words,HORIZONTAL_ALIGNMENT_LEFT,-1,layout.point,Color("020603"))
	draw_string(heading_font,at,words,HORIZONTAL_ALIGNMENT_LEFT,-1,layout.point,CREAM)

func _gutter_command_point(key: String, label: String, width: float) -> int:
	for point in range(13,8,-1):
		# _key_width includes an 18px inter-command advance, not painted ink.
		if _key_width(key,label,point)-18<=width: return point
	return 0

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
			# Leave the complete fallback frame and its unknown overlays untouched.
			FieldPanel.fastener(self,Vector2(margin-22,frame_rect.position.y+12))
			FieldPanel.fastener(self,Vector2(frame_rect.end.x+22,frame_rect.position.y+12))
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
	var scale:=_frame_scale()
	# All physical skin slices are outside the complete mapped source rectangles.
	# Cupola deliberately has no enclosing viewfinder or vertical side rails.
	var apertures:={1:Rect2(91.2,94.5,1417.6,508.5),2:Rect2(91.2,94.5,1417.6,202.5)}
	if apertures.has(wide_station):
		FieldPanel.optic(self,apertures[wide_station])
	elif wide_station==3:
		if not FieldPanel.region(self,"cupola",Rect2(0,0,1600,60.3),Rect2(0,34,1672,77)):
			FieldPanel.plate(self,Rect2(0,0,1600,60.3),scale)
		FieldPanel.region(self,"cupola",Rect2(0,810,1600,33.3),Rect2(0,843,1672,51))
	elif wide_station==4:
		FieldPanel.region(self,"driver",Rect2(0,0,52.8,60.3),Rect2(0,35,58,86))
		FieldPanel.region(self,"driver",Rect2(1547.2,0,52.8,60.3),Rect2(1614,35,58,86))
		FieldPanel.region(self,"driver",Rect2(52.8,0,1494.4,60.3),Rect2(0,35,1672,86))
		FieldPanel.region(self,"driver",Rect2(0,60.3,52.8,697.5),Rect2(0,156,58,566))
		FieldPanel.region(self,"driver",Rect2(1547.2,60.3,52.8,697.5),Rect2(1614,156,58,566))
		FieldPanel.region(self,"driver",Rect2(0,757.8,1600,85.5),Rect2(0,760,1672,134))
	else:
		FieldPanel.plate(self,Rect2(0,0,1600,64),scale)
	var header:=_header_layout(wide_station,scale)
	draw_string(heading_font,header.title_at+Vector2(0,1),header.name,HORIZONTAL_ALIGNMENT_LEFT,-1,header.title_point,Color("050905"))
	draw_string(heading_font,header.title_at,header.name,HORIZONTAL_ALIGNMENT_LEFT,-1,header.title_point,CREAM)
	for panel in instruments.panels:
		if wide_station!=4: FieldPanel.mount(self,panel.rect,scale)
	if wide_station==2 and not map_art.packet.is_empty():
		FieldPanel.mount(self,map_art.map_box,scale)
	# Side reinforcement below the optical housing is static plate, not scenery.
	if wide_station in [1,2,5]:
		for x in [0,1555]: FieldPanel.side_rail(self,Rect2(x,640 if wide_station==1 else 340,45,203 if wide_station==1 else 503))
	FieldPanel.footer(self,wide_station)
	for item in SECTIONS.get(wide_station,[]): _section_title(item[1],item[0],item[2])
	# The complete crew-report strip at y843.3..850.5 stays unobscured.
	var footer:=_footer_layout(wide_station,_frame_scale())
	var x:=90.0
	if wide_station!=5:
		for i in 4: x+=_key(Vector2(x,footer.baseline),"F"+str(i+1),STATIONS[i+1],wide_station==i+1,footer.station_point)
	x=footer.command_x
	for item in COMMANDS.get(wide_station,[]): x+=_key(Vector2(x,footer.baseline),item[0],item[1],false,footer.command_point,true)
