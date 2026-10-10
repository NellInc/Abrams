extends Control
## Range-inspired framing only. All mission values remain source pixels.
var wide_gunner := false
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
			draw_string(heading_font,Vector2(22,frame_rect.position.y+38),"ABRAMS",HORIZONTAL_ALIGNMENT_LEFT,-1,26,CREAM)
			draw_string(mono,Vector2(22,frame_rect.position.y+61),"TACTICAL",HORIZONTAL_ALIGNMENT_LEFT,-1,13,AMBER)
			draw_string(mono,Vector2(frame_rect.end.x+28,frame_rect.position.y+42),"PC CAMPAIGN",HORIZONTAL_ALIGNMENT_LEFT,-1,12,MUTED)
			draw_string(mono,Vector2(frame_rect.end.x+28,frame_rect.position.y+62),"CREW STATION",HORIZONTAL_ALIGNMENT_LEFT,-1,12,MUTED)
		return
	if not wide_gunner: return
	draw_set_transform(Vector2.ZERO,0,size/Vector2(1600,900))
	draw_string(heading_font,Vector2(90,42),"M1A1  /  GUNNER",HORIZONTAL_ALIGNMENT_LEFT,-1,27,CREAM)
	draw_string(mono,Vector2(90,63),"TACTICAL OPTIC",HORIZONTAL_ALIGNMENT_LEFT,-1,14,AMBER)
	draw_string(mono,Vector2(1200,44),"PC CAMPAIGN",HORIZONTAL_ALIGNMENT_LEFT,-1,15,MUTED)
	draw_string(mono,Vector2(1200,63),"COMBAT OPTIC",HORIZONTAL_ALIGNMENT_LEFT,-1,12,MUTED)
	draw_rect(Rect2(87,68,1426,603),RULE,false,2.0)
	draw_string(mono,Vector2(88,710),"TARGET  /  RANGE",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
	draw_string(mono,Vector2(445,710),"HULL  /  SPEED",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
	draw_string(mono,Vector2(800,710),"NAVIGATION",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
	draw_string(mono,Vector2(1094,710),"MAIN GUN",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
	draw_string(mono,Vector2(1318,710),"SYSTEMS",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
	for x in [435.0,780.0,1070.0,1320.0]:
		draw_line(Vector2(x,705),Vector2(x,850),RULE,1.0,true)
	draw_line(Vector2(88,861),Vector2(1512,861),RULE,1.0,true)
	draw_string(mono,Vector2(90,886),"F1  GUNNER     F2  COMMANDER     F3  CUPOLA     F4  DRIVER",HORIZONTAL_ALIGNMENT_LEFT,-1,14,MUTED)
	draw_string(mono,Vector2(1075,886),"ENTER SELECT   L LOCK   SPACE FIRE",HORIZONTAL_ALIGNMENT_LEFT,-1,14,AMBER)
