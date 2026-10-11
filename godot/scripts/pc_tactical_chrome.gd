extends Control
## Range-inspired framing only. All mission values remain source pixels.
var wide_station := 0
var station := 0
var instruments = preload("res://scripts/pc_tactical_instruments.gd").new()

func _init() -> void:
	add_child(instruments)
	instruments.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
const STATIONS := {1:"GUNNER",2:"COMMANDER",3:"CUPOLA",4:"DRIVER",5:"SYSTEMS STATUS"}
const ROLES := {1:"TACTICAL OPTIC",2:"COMMAND & NAVIGATION",3:"CUPOLA VIEW",4:"DRIVER VIEW",5:"VEHICLE SYSTEMS"}
var fallback_tactical := false
var frame_rect := Rect2i()
var heading_font: Font = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
var mono: Font = preload("res://assets/fonts/IBMPlexMono-Regular.ttf")
const CREAM := Color("e3e4cd")
const MUTED := Color("a8b69f")
const AMBER := Color("e7b566")
const RULE := Color("61785b")

func _draw() -> void:
	if fallback_tactical:
		# The untouched 4:3 station remains complete. The spare width belongs to
		# the frame, never to an invented map, instrument or broader camera.
		var margin:=float(frame_rect.position.x)
		if margin>=160.0:
			draw_line(Vector2(margin-12,frame_rect.position.y),Vector2(margin-12,frame_rect.end.y),RULE,1.0,true)
			draw_line(Vector2(frame_rect.end.x+12,frame_rect.position.y),Vector2(frame_rect.end.x+12,frame_rect.end.y),RULE,1.0,true)
			draw_string(heading_font,Vector2(22,frame_rect.position.y+38),STATIONS.get(station,"ABRAMS").replace("SYSTEMS STATUS","SYSTEMS"),HORIZONTAL_ALIGNMENT_LEFT,-1,26,CREAM)
			draw_string(mono,Vector2(22,frame_rect.position.y+61),"TACTICAL",HORIZONTAL_ALIGNMENT_LEFT,-1,13,AMBER)
			draw_string(mono,Vector2(frame_rect.end.x+28,frame_rect.position.y+42),"PC CAMPAIGN",HORIZONTAL_ALIGNMENT_LEFT,-1,12,MUTED)
			draw_string(mono,Vector2(frame_rect.end.x+28,frame_rect.position.y+62),ROLES.get(station,"CREW STATION"),HORIZONTAL_ALIGNMENT_LEFT,-1,12,MUTED)
		return
	if wide_station==0: return
	draw_set_transform(Vector2.ZERO,0,size/Vector2(1600,900))
	draw_string(heading_font,Vector2(90,42),"M1A1  /  "+STATIONS.get(wide_station,"CREW STATION"),HORIZONTAL_ALIGNMENT_LEFT,-1,27,CREAM)
	draw_string(mono,Vector2(90,63),ROLES.get(wide_station,"TACTICAL"),HORIZONTAL_ALIGNMENT_LEFT,-1,14,AMBER)
	draw_string(mono,Vector2(1200,44),"PC CAMPAIGN",HORIZONTAL_ALIGNMENT_LEFT,-1,15,MUTED)
	draw_string(mono,Vector2(1200,63),"TACTICAL",HORIZONTAL_ALIGNMENT_LEFT,-1,12,MUTED)
	if wide_station==1:
		draw_rect(Rect2(87,68,1426,603),RULE,false,2.0)
		draw_string(mono,Vector2(88,710),"TARGET  /  RANGE",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
		draw_string(mono,Vector2(445,710),"HULL  /  SPEED",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
		draw_string(mono,Vector2(800,697),"NAVIGATION",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
		draw_string(mono,Vector2(1094,700),"MAIN GUN",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
		draw_string(mono,Vector2(1336,700),"SYSTEMS",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
		for x in [435.0,780.0,1070.0,1320.0]:
			draw_line(Vector2(x,705),Vector2(x,850),RULE,1.0,true)
	elif wide_station==2:
		draw_rect(Rect2(87,75,1426,232),RULE,false,2.0)
		draw_string(mono,Vector2(88,348),"TACTICAL MAP",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
		draw_string(mono,Vector2(704,348),"NAVIGATION",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
		draw_string(mono,Vector2(1120,402),"SYSTEMS",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
		draw_string(mono,Vector2(704,747),"HULL  /  SPEED",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
		draw_string(mono,Vector2(1152,747),"FUEL",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
	elif wide_station==3:
		draw_rect(Rect2(87,75,1426,781),RULE,false,2.0)
	elif wide_station==4:
		draw_rect(Rect2(87,75,1426,709),RULE,false,2.0)
	elif wide_station==5:
		draw_string(mono,Vector2(1040,108),"STORES",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
		draw_string(mono,Vector2(88,451),"SYSTEMS & DAMAGE",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
	draw_line(Vector2(88,861),Vector2(1512,861),RULE,1.0,true)
	draw_string(mono,Vector2(90,886),"F1  GUNNER     F2  COMMANDER     F3  CUPOLA     F4  DRIVER",HORIZONTAL_ALIGNMENT_LEFT,-1,14,MUTED)
	var controls:Dictionary={1:"ENTER SELECT   L LOCK   SPACE FIRE",2:"Z MAP   F7-F10 SCAN   D STATUS",
		3:"A ALIGN TURRET   C HULL/TURRET",4:"KEYPAD DRIVE   KP5 STOP",5:"ANY KEY  RETURN TO COMMANDER"}
	var hint:String=controls.get(wide_station,"")
	var hint_width:=mono.get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
	draw_string(mono,Vector2(1512-hint_width,886),hint,HORIZONTAL_ALIGNMENT_LEFT,-1,14,AMBER)
