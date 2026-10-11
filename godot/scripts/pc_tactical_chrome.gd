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
const MUTED := Color("a8b69f")
const AMBER := Color("e7b566")
const RULE := Color("61785b")

func _corners(box: Rect2, length: float=12.0) -> void:
	for x in [box.position.x,box.end.x]:
		for y in [box.position.y,box.end.y]:
			var at:=Vector2(x,y)
			draw_line(at,at+Vector2(length if x==box.position.x else -length,0),CREAM,1.2,true)
			draw_line(at,at+Vector2(0,length if y==box.position.y else -length),CREAM,1.2,true)

func _key(at: Vector2, key: String, label: String, selected: bool=false) -> float:
	var width:=mono.get_string_size(key,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x+10
	var box:=Rect2(at.x,at.y-16,width,22)
	draw_rect(box,Color("283a29") if selected else Color("101e16"))
	draw_rect(box,RULE,false,1,true)
	draw_string(mono,at+Vector2(5,0),key,HORIZONTAL_ALIGNMENT_LEFT,-1,13,AMBER if selected else CREAM)
	draw_string(mono,at+Vector2(width+8,0),label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,CREAM if selected else MUTED)
	return width+mono.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+26

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
	_corners(Rect2(72,19,1480,875),10)
	draw_string(heading_font,Vector2(90,42),"M1A1  /  "+STATIONS.get(wide_station,"CREW STATION"),HORIZONTAL_ALIGNMENT_LEFT,-1,27,CREAM)
	draw_string(mono,Vector2(90,63),ROLES.get(wide_station,"TACTICAL"),HORIZONTAL_ALIGNMENT_LEFT,-1,14,AMBER)
	draw_string(mono,Vector2(1200,44),"PC CAMPAIGN",HORIZONTAL_ALIGNMENT_LEFT,-1,15,MUTED)
	draw_string(mono,Vector2(1200,63),"TACTICAL",HORIZONTAL_ALIGNMENT_LEFT,-1,12,MUTED)
	if wide_station==1:
		draw_rect(Rect2(87,68,1426,603),RULE,false,2.0)
		_corners(Rect2(87,68,1426,603))
		draw_string(mono,Vector2(88,700),"TARGET  /  RANGE",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
		draw_string(mono,Vector2(445,700),"HULL  /  SPEED",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
		draw_string(mono,Vector2(800,700),"NAVIGATION",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
		draw_string(mono,Vector2(1094,700),"MAIN GUN",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
		draw_string(mono,Vector2(1336,700),"SYSTEMS",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
	elif wide_station==2:
		draw_rect(Rect2(87,75,1426,232),RULE,false,2.0)
		_corners(Rect2(87,75,1426,232))
		draw_string(mono,Vector2(88,348),"TACTICAL MAP",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
		draw_string(mono,Vector2(744,348),"NAVIGATION",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
		draw_string(mono,Vector2(1144,348),"SYSTEMS",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
		draw_string(mono,Vector2(744,735),"HULL  /  SPEED",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
		draw_string(mono,Vector2(1144,735),"FUEL",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
	elif wide_station==3:
		draw_rect(Rect2(87,75,1426,781),RULE,false,2.0)
		_corners(Rect2(87,75,1426,781))
	elif wide_station==4:
		draw_rect(Rect2(87,75,1426,709),RULE,false,2.0)
		_corners(Rect2(87,75,1426,709))
	elif wide_station==5:
		draw_string(mono,Vector2(1040,108),"STORES",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
		draw_string(mono,Vector2(88,451),"SYSTEMS & DAMAGE",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
	draw_line(Vector2(88,861),Vector2(1512,861),RULE,1.0,true)
	var x:=90.0
	for i in 4: x+=_key(Vector2(x,885),"F"+str(i+1),STATIONS[i+1],wide_station==i+1)
	var controls:Dictionary={1:"ENTER SELECT   L LOCK   SPACE FIRE",2:"Z MAP   F7-F10 SCAN   D STATUS",
		3:"A ALIGN TURRET   C HULL/TURRET",4:"KEYPAD DRIVE   KP5 STOP",5:"ANY KEY  RETURN TO COMMANDER"}
	var hint:String=controls.get(wide_station,"")
	var hint_width:=mono.get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
	draw_string(mono,Vector2(1512-hint_width,886),hint,HORIZONTAL_ALIGNMENT_LEFT,-1,14,AMBER)
