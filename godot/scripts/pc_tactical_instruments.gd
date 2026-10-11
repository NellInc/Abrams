extends Control
## Output-resolution Tactical instruments. Only current, source-proven cells
## may replace a panel; unknown ink keeps the complete original panel visible.
const Ink = preload("res://scripts/pc_instrument_art.gd")
const CREAM = Color("e3e4cd")
const MUTED = Color("a8b69f")
const RULE = Color("61785b")
const FIELD = Color("0c1812")
const GREEN = Color("a6cf8b")
const AMBER = Color("e7b566")
const RED = Color("ed9271")
const SYSTEMS = ["GPS","SMOKE DISCHARGERS","COAX","MAIN GUN","BALLISTIC COMPUTER","THERMAL",
	"RADIO","HALON","TURRET MOTORS","LEFT TREAD","RIGHT TREAD","ENGINE"]
var font: Font = preload("res://assets/fonts/IBMPlexMono-Regular.ttf")
var title: Font = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
var verifier = Ink.new()
var damage_catalog: Array = []
var panels: Array[Dictionary] = []
var runs: Array = []
var gauges: Array = []
var orientation: Dictionary = {}
var damage := -1
var station := 0
var rejected: Array[int] = []

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	add_child(verifier)
	verifier.hide()

func load_sources(root_path: String) -> void:
	verifier.load_pc_sources(root_path)
	damage_catalog.clear()
	var catalog=preload("res://scripts/pc_tactical_damage_states.gd")
	for name in catalog.SOURCE_HASHES:
		if FileAccess.get_sha256(root_path.path_join("GAME/"+name))!=catalog.SOURCE_HASHES[name]: return
	damage_catalog=catalog.STATES

func _damage_state(source: Image, mask: Image, tags: Image) -> int:
	var box:=Rect2i(123,37,184,63)
	if mask.get_region(box).get_data().count(255)!=184*63: return -1
	var crop:=source.get_region(box)
	crop.convert(Image.FORMAT_RGB8)
	var rgb:=HashingContext.new()
	rgb.start(HashingContext.HASH_SHA256);rgb.update(crop.get_data())
	var sha:=rgb.finish().hex_encode()
	var tag:=HashingContext.new()
	tag.start(HashingContext.HASH_SHA256);tag.update(tags.get_region(box).get_data())
	var tag_sha:=tag.finish().hex_encode()
	for entry in damage_catalog:
		if entry.rgb_sha256==sha and entry.tags_sha256==tag_sha: return int(entry.bits)
	return -1

func clear() -> void:
	panels.clear(); runs.clear(); gauges.clear(); orientation={}; damage=-1; station=0
	rejected.clear()
	queue_redraw()

func set_frame(frame: Control, id: int, layout: Dictionary, tags: Image, ui: PackedByteArray) -> void:
	clear()
	if id not in [1,2,4,5] or not frame.world_enabled or tags==null or frame._cached_source==null: return
	if tags.get_size()!=Vector2i(320,200) or tags.get_format()!=Image.FORMAT_L8 or ui.size()!=64000: return
	station=id
	var source: Image=frame._cached_source
	var mask:=Image.create_from_data(320,200,false,Image.FORMAT_L8,ui)
	runs=frame.typography.runs.filter(_represented)
	# Reuse the same visible-pixel predicates with PC-only sources. Existing
	# Restored/Modernized renderers and their optional artwork stay untouched.
	var proof: Control=frame.instrument_art
	if not frame.genesis_art_enabled or frame.graphics_mode not in ["upscaled","modern","tactical"]:
		verifier.set_frame(source,mask,tags,frame._cached_presentation.get("orientation",{}))
		proof=verifier
	gauges=proof.gauges.duplicate()
	orientation=proof.orientation.packet.duplicate(true)
	damage=_damage_state(source,mask,tags) if id==5 else -1
	if not frame.typography.fonts.is_empty():
		var candidates: Array=[]
		for entry in frame.typography.FIXED_LABELS:
			if _run(Vector2(entry[1],entry[2])).is_empty(): candidates.append(frame.typography._fixed_candidate(entry[0],Vector2i(entry[1],entry[2]),source))
		if id==5:
			for y in [52,60,68,76,84,92]:
				if _run(Vector2(83,y)).is_empty(): candidates.append(frame.typography._status_number(source,y))
		for candidate in candidates:
			var run: Dictionary=frame.typography.verified_run(candidate,source,mask,frame._cached_presentation.get("palette_rgb",[]))
			if not run.is_empty() and _represented(run): runs.append(run)
	var covered: Image=tags.duplicate()
	for run in runs:
		if not run.get("transparent_world",false): covered.fill_rect(Rect2i(run.rect),Color8(id,id,id))
	for gauge in gauges: covered.fill_rect(gauge.source,Color8(id,id,id))
	if not orientation.is_empty():
		var r: Array=orientation.rect
		covered.fill_rect(Rect2i(r[0],r[1],r[2],r[3]),Color8(id,id,id))
	if id==5 and damage>=0: covered.fill_rect(Rect2i(123,37,182,63),Color8(id,id,id))
	# Selection wells are larger than their verified number glyphs. Require the
	# entire extra margin to match that same glyph's exact background colour.
	if id==1:
		for x in [227,272]:
			for y in [144,157,170,183]:
				var value:=_run(Vector2(x,y))
				if value.is_empty(): continue
				var box:=Rect2i(x-1,y-3,13,11)
				var valid:=true
				for region in Ink._outside(box,Rect2i(value.rect)):
					for py in range(region.position.y,region.end.y):
						for px in range(region.position.x,region.end.x):
							if source.get_pixel(px,py).to_rgba32()!=value.background.to_rgba32(): valid=false
				if valid: covered.fill_rect(box,Color8(id,id,id))
	var indices: Array={1:[1,2,3,4,5],2:[2,3,4,5],4:[1],5:[0,1,2]}[id]
	for index in indices:
		var r: Vector4=layout.source[index]
		var box:=Rect2i(int(r.x),int(r.y),int(r.z-r.x),int(r.w-r.y))
		var safe:=_required(index) and mask.get_region(box).get_data().count(255)==box.size.x*box.size.y
		var uncovered:=covered.get_region(box).get_data()
		if uncovered.count(id)!=uncovered.size():
			# Work in packed bytes only for uncovered pixels; fully proven panels
			# avoid tens of thousands of per-pixel script calls each frame.
			var crop:=source.get_region(box)
			crop.convert(Image.FORMAT_RGB8)
			var rgb:=crop.get_data()
			for offset in uncovered.size():
				if uncovered[offset]==id: continue
				var at:=offset*3
				if rgb[at]==0 and rgb[at+1]==0 and rgb[at+2]==0: continue
				var p:=box.position+Vector2i(offset%box.size.x,offset/box.size.x)
				if id==4 and rgb[at]==85 and rgb[at+1]==85 and rgb[at+2]==255 and _driver_border(p): continue
				safe=false

		if safe:
			var d: Vector4=layout.destination[index]
			panels.append({"index":index,"source":box,"rect":Rect2(d.x*1600,d.y*900,(d.z-d.x)*1600,(d.w-d.y)*900)})
		else: rejected.append(index)
	queue_redraw()

static func _driver_border(p: Vector2i) -> bool:
	for rect in [Rect2i(64,189,45,9),Rect2i(112,189,39,9),Rect2i(154,189,51,9),Rect2i(208,189,45,9)]:
		if rect.has_point(p) and (p.x==rect.position.x or p.x==rect.end.x-1 or p.y==rect.position.y or p.y==rect.end.y-1): return true
	return false

func _represented(run: Dictionary) -> bool:
	# A verified string is still unsafe to erase unless this renderer displays
	# that exact field. Unexpected messages inside an instrument stay native.
	var at: Vector2=run.rect.position
	var values: Array=[]
	if station==1:
		values=[Vector2(52,143),Vector2(52,154),Vector2(16,165),Vector2(52,165),Vector2(173,188)]
		for y in [144,157,170,183]: values.append(Vector2(227,y))
		for y in [144,170]: values.append(Vector2(272,y))
	elif station==2: values=[Vector2(261,134)]
	elif station==4: values=[Vector2(90,191),Vector2(132,191),Vector2(186,191)]
	elif station==5:
		for y in [52,60,68,76,84,92]: values.append(Vector2(83,y))
	if at in values: return true
	for entry in preload("res://scripts/pc_typography.gd").FIXED_LABELS:
		if at==Vector2(entry[1],entry[2]) and run.text.strip_edges()==entry[0]: return true
	return false

func _run(at: Vector2) -> Dictionary:
	for run in runs:
		if run.rect.position==at: return run
	return {}

func _value(x: int, y: int) -> String:
	return str(_run(Vector2(x,y)).get("text","")).strip_edges()

func _gauge(name: String) -> Dictionary:
	for gauge in gauges:
		if gauge.name==name: return gauge
	return {}

func _required(index: int) -> bool:
	if station==1:
		if index==1: return not _run(Vector2(52,154)).is_empty() and not _run(Vector2(52,165)).is_empty()
		if index==2: return not _gauge("gunner_speed").is_empty()
		if index==3: return not orientation.is_empty() and not _run(Vector2(173,188)).is_empty()
		if index==4: return [144,157,170,183].all(func(y):return not _run(Vector2(227,y)).is_empty())
		if index==5: return not _gauge("gunner_temperature").is_empty() and not _gauge("gunner_target_lock").is_empty() and not _run(Vector2(272,144)).is_empty() and not _run(Vector2(272,170)).is_empty()
	if station==2:
		if index==2: return not _gauge("commander_speed").is_empty()
		if index==3: return not _gauge("commander_fuel").is_empty()
		if index==4: return not orientation.is_empty() and not _run(Vector2(261,134)).is_empty()
		if index==5: return Ink.SYSTEM_NAMES.all(func(n):return not _gauge("commander_"+n).is_empty())
	if station==4: return [90,132,186].all(func(x):return not _run(Vector2(x,191)).is_empty()) and not _gauge("driver_temperature").is_empty()
	if station==5:
		if index==0: return [52,60,68,76,84,92].all(func(y):return not _run(Vector2(83,y)).is_empty())
		if index==1: return damage>=0
		if index==2: return Ink.SYSTEM_NAMES.all(func(n):return not _gauge("status_"+n).is_empty())
	return false

func _text(words: String, box: Rect2, height: int=19, colour: Color=CREAM, right: bool=false, heading: bool=false) -> void:
	var face: Font=title if heading else font
	var point:=height
	while point>7 and (face.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,point).x>box.size.x or face.get_height(point)>box.size.y): point-=1
	var x:=box.end.x-face.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,point).x if right else box.position.x
	var y:=box.position.y+(box.size.y-face.get_height(point))*0.5+face.get_ascent(point)
	draw_string(face,Vector2(x,y),words,HORIZONTAL_ALIGNMENT_LEFT,-1,point,colour)

func _row(box: Rect2, label: String, value: String, colour: Color=CREAM, selected: bool=false) -> void:
	if selected: draw_rect(box,Color("293b26"))
	_text(label,Rect2(box.position+Vector2(10,0),Vector2(box.size.x*0.68-10,box.size.y)),17,AMBER if selected else MUTED)
	_text(value,Rect2(box.position+Vector2(box.size.x*0.67,0),Vector2(box.size.x*0.33-10,box.size.y)),23,colour,true)
	draw_line(Vector2(box.position.x+8,box.end.y),Vector2(box.end.x-8,box.end.y),Color("29392b"),1,true)

func _reading_colour(run: Dictionary) -> Color:
	var colour: Color=run.get("foreground",Color.WHITE)
	return _state_colour(colour) if colour in [Ink.RED,Ink.YELLOW,Ink.GREEN] else CREAM

func _state_colour(colour: Color) -> Color:
	if colour.to_rgba32()==Ink.RED.to_rgba32(): return RED
	if colour.to_rgba32()==Ink.YELLOW.to_rgba32(): return AMBER
	if colour.to_rgba32()==Ink.GREEN.to_rgba32(): return GREEN
	return Color("26352a")

func _lamp(box: Rect2, label: String, gauge: Dictionary) -> void:
	_text(label,Rect2(box.position+Vector2(10,0),Vector2(box.size.x-51,box.size.y)),16,MUTED)
	var b:=Rect2(box.end.x-30,box.position.y+(box.size.y-8)*0.5,18,8)
	draw_rect(b,_state_colour(gauge.color))
	draw_rect(b.grow(3),RULE,false,1,true)

func _bar(box: Rect2, gauge: Dictionary) -> void:
	var fuel: bool=gauge.name=="commander_fuel"
	var labels: Array=["E","F"] if fuel else ["0","30","60","90"]
	for i in labels.size():
		var x:=box.position.x+10+(box.size.x-44)*float(i)/(labels.size()-1)
		_text(labels[i],Rect2(x,box.position.y+box.size.y*0.24,34,28),19,MUTED,i==labels.size()-1)
	var pitch: float=(box.size.x-20)/gauge.count
	for i in gauge.count:
		var colour: Color=_state_colour(gauge.colors[i]) if i<gauge.lit else Color("263b2d")
		draw_rect(Rect2(box.position.x+10+i*pitch,box.position.y+box.size.y*0.62,maxf(1,pitch-2),22),colour)

func _navigation(box: Rect2) -> void:
	var target:=Rect2(box.position+Vector2(12,8),Vector2(box.size.x-24,box.size.y-40))
	var r: Array=orientation.rect
	var scale_xy:=target.size/Vector2(r[2],r[3])
	var origin:=Vector2(r[0],r[1])
	for line in orientation.grid:
		var p: Array=line.points
		var a: Vector2=(Vector2(p[0],p[1])-origin)*scale_xy+target.position
		var b: Vector2=(Vector2(p[2],p[3])-origin)*scale_xy+target.position
		draw_line(a,b,Color("304333"),1,true)
	for quad in orientation.quads:
		var points:=PackedVector2Array()
		for p in quad.vertices_q14: points.append((Vector2(p[0],p[1])/16384.0-origin)*scale_xy+target.position)
		if quad.filled: draw_colored_polygon(points,FIELD)
		points.append(points[0]);draw_polyline(points,CREAM,1.7,true)
		for i in quad.edges.size():
			var c: Color=preload("res://scripts/pc_orientation_art.gd").PALETTE[int(quad.edges[i])]
			draw_line(points[i],points[i+1],_state_colour(c) if c in [Ink.RED,Ink.GREEN,Ink.YELLOW] else CREAM,2,true)
	_row(Rect2(box.position.x,box.end.y-30,box.size.x,30),"HEADING",_value(173,188) if station==1 else _value(261,134))

func _systems(box: Rect2, miniature: bool) -> void:
	var row_height: float=box.size.y/6.0
	for i in 12:
		var right:=i>=6
		var row:=Rect2(box.position+Vector2(box.size.x*0.5 if right else 0,(i%6)*row_height),Vector2(box.size.x*0.5-8,row_height-3))
		var gauge:=_gauge(("commander_" if miniature else "status_")+Ink.SYSTEM_NAMES[i])
		_lamp(row,SYSTEMS[i],gauge)
		if not miniature: draw_line(Vector2(row.position.x+10,row.end.y),Vector2(row.end.x-10,row.end.y),Color("29392b"),1,true)

# Technical plan-view schematic. Geometry is authored; damage overlays use only
# the five already-proven visible source bits, at their original diagram zones.
func _tank(box: Rect2, bits: int) -> void:
	var scale_xy:=Vector2.ONE*minf(box.size.x/400.0,box.size.y/155.0)
	var at:=box.get_center()-Vector2(400,155)*scale_xy*0.5
	var hull:=PackedVector2Array([Vector2(112,19),Vector2(364,19),Vector2(382,35),Vector2(382,121),Vector2(364,136),Vector2(112,136),Vector2(92,114),Vector2(92,43)])
	_poly(hull,at,scale_xy,Color("1e3023"),RULE)
	for y in [7,124]:
		_rect(Rect2(112,y,264,24),at,scale_xy,Color("283d2d"),RULE)
		for x in range(117,374,9): _line(Vector2(x,y+2),Vector2(x,y+22),at,scale_xy,Color("52694b"))
	_rect(Rect2(308,37,56,79),at,scale_xy,FIELD,RULE)
	for y in range(43,115,7): _line(Vector2(314,y),Vector2(358,y),at,scale_xy,RULE)
	_poly(PackedVector2Array([Vector2(145,41),Vector2(205,30),Vector2(282,43),Vector2(301,61),Vector2(294,106),Vector2(218,125),Vector2(145,108),Vector2(129,91),Vector2(129,59)]),at,scale_xy,Color("344a32"),CREAM)
	_rect(Rect2(130,64,51,28),at,scale_xy,Color("233628"),CREAM)
	_rect(Rect2(12,73,128,10),at,scale_xy,Color("526747"),CREAM)
	_rect(Rect2(9,70,14,16),at,scale_xy,Color("233628"),CREAM)
	for c in [Vector2(222,65),Vector2(254,94)]:
		draw_arc(at+c*scale_xy,13*scale_xy.x,0,TAU,40,CREAM,1.3,true)
		_line(c-Vector2(8,0),c+Vector2(8,0),at,scale_xy,RULE)
	_line(Vector2(180,47),Vector2(180,108),at,scale_xy,RULE)
	_line(Vector2(197,40),Vector2(271,48),at,scale_xy,RULE)
	if bits<=0: return
	# Registration follows the PC source sprite origins, not hidden system RAM.
	var zones: Array[Rect2]=[Rect2(176,52,70,69),Rect2(211,7,102,28),Rect2(204,124,112,24),Rect2(310,34,60,84),Rect2(33,66,98,24)]
	for i in 5:
		if (bits&(1<<i))==0: continue
		var z: Rect2=zones[i]
		_rect(z,at,scale_xy,Color("5b3027"),RED)
		for x in range(int(z.position.x)+6,int(z.end.x)-3,10): _line(Vector2(x,z.position.y+4),Vector2(x-3,z.end.y-4),at,scale_xy,RED)

func _poly(points: PackedVector2Array, at: Vector2, scale_xy: Vector2, fill: Color, stroke: Color) -> void:
	var transformed:=PackedVector2Array()
	for p in points: transformed.append(at+p*scale_xy)
	draw_colored_polygon(transformed,fill);transformed.append(transformed[0]);draw_polyline(transformed,stroke,1.4,true)
func _rect(box: Rect2, at: Vector2, scale_xy: Vector2, fill: Color, stroke: Color) -> void:
	var r:=Rect2(at+box.position*scale_xy,box.size*scale_xy)
	draw_rect(r,fill);draw_rect(r,stroke,false,1.2,true)
func _line(a: Vector2,b: Vector2,at: Vector2,scale_xy: Vector2,colour: Color) -> void:
	draw_line(at+a*scale_xy,at+b*scale_xy,colour,1,true)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,size/Vector2(1600,900))
	for panel in panels:
		var box: Rect2=panel.rect
		var index: int=panel.index
		draw_rect(box,FIELD)
		draw_rect(box,Color("344733"),false,1,true)
		if station==1:
			if index==1:
				var height:=box.size.y/3
				for i in 3:
					var label: String=["ID","RANGE",_value(16,165)][i]
					_row(Rect2(box.position+Vector2(0,i*height),Vector2(box.size.x,height)),label,_value(52,143+i*11),_reading_colour(_run(Vector2(52,143+i*11))))
			elif index==2: _bar(box,_gauge("gunner_speed"))
			elif index==3: _navigation(box)
			elif index==4:
				for i in 4:
					var value:=_run(Vector2(227,144+i*13))
					_row(Rect2(box.position+Vector2(0,i*box.size.y/4),Vector2(box.size.x,box.size.y/4)),["HEAT","SABOT","AX","COAX"][i],str(value.text).strip_edges(),CREAM,value.background==Ink.RED)
			elif index==5:
				var h:=box.size.y/4
				_row(Rect2(box.position,Vector2(box.size.x,h)),"SMOKE",_value(272,144))
				_lamp(Rect2(box.position+Vector2(0,h),Vector2(box.size.x,h)),"TEMP",_gauge("gunner_temperature"))
				_row(Rect2(box.position+Vector2(0,h*2),Vector2(box.size.x,h)),"DISPLAY",_value(272,170))
				_lamp(Rect2(box.position+Vector2(0,h*3),Vector2(box.size.x,h)),"LOCK",_gauge("gunner_target_lock"))
		elif station==2:
			if index in [2,3]: _bar(box,_gauge("commander_speed" if index==2 else "commander_fuel"))
			elif index==4: _navigation(box)
			elif index==5:
				_tank(Rect2(box.position,Vector2(box.size.x,box.size.y*0.36)),0)
				_systems(Rect2(box.position+Vector2(0,box.size.y*0.39),Vector2(box.size.x,box.size.y*0.61)),true)
		elif station==4:
			for i in 4:
				var r:=Rect2(box.position+Vector2(i*box.size.x/4,0),Vector2(box.size.x/4,box.size.y))
				if i==3: _lamp(r,"TEMP",_gauge("driver_temperature"))
				else: _row(r,["HDG","SPD","FUEL"][i],_value([90,132,186][i],191))
		elif station==5:
			if index==0:
				for i in 6: _row(Rect2(box.position+Vector2(0,i*box.size.y/6),Vector2(box.size.x,box.size.y/6)),["HEAT","SABOT","AX","MG ROUNDS","SMOKE GRN","FUEL GALS"][i],_value(83,52+i*8))
			elif index==1:
				_text("M1A1",Rect2(box.position+Vector2(12,4),Vector2(box.size.x-24,32)),28,CREAM,false,true)
				_tank(Rect2(box.position+Vector2(10,40),box.size-Vector2(20,48)),damage)
			elif index==2: _systems(box,false)
