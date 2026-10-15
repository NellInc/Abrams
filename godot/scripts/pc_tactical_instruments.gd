extends Control
## Output-resolution Tactical instruments. Only current, source-proven cells
## may replace a panel; unknown ink keeps the complete original panel visible.
const Ink = preload("res://scripts/pc_instrument_art.gd")
const CREAM = Color("e3e4cd")
const MUTED = Color("c1ccba")
const RULE = Color("526b58")
const FIELD = Color("101e19")
const GREEN = Color("a6cf8b")
const AMBER = Color("e7b566")
const RED = Color("ed9271")
const DIAGRAM_EDGE = Color("99b288")
const NAVIGATION_FILLS = [Color("203529"),Color("324b33"),Color("425e3d"),Color("283f2d")]
const DAMAGE_ZONES: Array[Rect2] = [Rect2(176,52,70,69),Rect2(211,7,102,28),Rect2(204,124,112,24),Rect2(310,34,60,84),Rect2(33,66,98,24)]
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
var canvas_size := Vector2(1600,900)
var in_place := false
var _clips: Array[Control] = []
var _ink: CanvasItem = self
var _paint_state: Array = []

class PanelInk extends Control:
	var renderer: Control
	var panel: Dictionary
	func _draw() -> void: renderer._paint_panel(panel,self)

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(_place_panels)
	font.changed.connect(_invalidate_paint)
	title.changed.connect(_invalidate_paint)
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

func _reset_frame() -> void:
	panels.clear(); runs.clear(); gauges.clear(); orientation={}; damage=-1; station=0
	rejected.clear()
	in_place=false

func clear() -> void:
	_reset_frame()
	_paint_state.clear()
	for clip in _clips: clip.hide()
	queue_redraw()

func set_frame(frame: Control, id: int, layout: Dictionary, tags: Image, ui: PackedByteArray) -> void:
	if id not in [1,2,4,5] or not frame.world_enabled or tags==null or frame._cached_source==null:
		clear(); return
	if tags.get_size()!=Vector2i(320,200) or tags.get_format()!=Image.FORMAT_L8 or ui.size()!=64000:
		clear(); return
	_reset_frame()
	station=id
	in_place=layout.get("in_place",false)
	canvas_size=Vector2(1600,1200) if in_place else Vector2(1600,900)
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
			panels.append({"index":index,"source":box,"rect":Rect2(Vector2(d.x,d.y)*canvas_size,Vector2(d.z-d.x,d.w-d.y)*canvas_size)})
		else: rejected.append(index)
	_place_panels()

func _invalidate_paint() -> void:
	_paint_state.clear()
	_place_panels()

func _drawing_state() -> Array:
	# Select exactly what the painters consume. Frame/page provenance and font
	# proof geometry can advance without changing a single displayed instrument.
	var readings: Array=[]
	for run in runs: readings.append([run.rect,run.text,run.foreground,run.background])
	var indicators: Array=[]
	for gauge in gauges:
		indicators.append([gauge.name,gauge.get("color",Color.BLACK),gauge.get("colors",[]),
			gauge.get("count",0),gauge.get("lit",0),gauge.get("lock",false)])
	var navigation: Array=[]
	if not orientation.is_empty():
		navigation=[orientation.rect,orientation.grid.map(func(line):return line.points),
			orientation.quads.map(func(quad):return [quad.vertices_q14,quad.filled,quad.edges])]
	return [size,canvas_size,in_place,station,damage,panels,readings,indicators,navigation,font,title]

func _place_panels() -> void:
	# Reuse drawing commands only AFTER this frame's complete source proof.
	# One detached snapshot includes every drawing input, not framebuffer data,
	# ownership or a previous acceptance decision. Nested mutations cannot alias it.
	var current:=_drawing_state()
	if current==_paint_state: return
	_paint_state=current.duplicate(true)
	for clip in _clips: clip.hide()
	# Clip children to each individually accepted source rectangle. Text and
	# antialiased linework cannot spill into an unknown neighbouring overlay.
	for i in panels.size():
		if i>=_clips.size():
			var clip:=Control.new()
			clip.mouse_filter=Control.MOUSE_FILTER_IGNORE
			clip.clip_contents=true
			var painter:=PanelInk.new()
			painter.mouse_filter=Control.MOUSE_FILTER_IGNORE
			painter.renderer=self
			clip.add_child(painter)
			add_child(clip)
			_clips.append(clip)
		var box: Rect2=panels[i].rect
		# Keep only whole output pixels inside the proven rectangle, including
		# at fractional source-pixel scales after a window resize.
		_clips[i].position=(box.position*size/canvas_size).ceil()
		_clips[i].size=(box.end*size/canvas_size).floor()-_clips[i].position
		var painter: PanelInk=_clips[i].get_child(0)
		painter.size=_clips[i].size
		painter.panel=panels[i]
		painter.queue_redraw()
		_clips[i].show()

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

func _output_scale() -> float:
	return maxf(0.01,minf(size.x/canvas_size.x,size.y/canvas_size.y))

func _text_point(height: int, heading: bool=false) -> int:
	var base:=roundi(height*1.3) if in_place else height
	return maxi(base,ceili((12.0 if heading else 13.0)/_output_scale()))

func _text_layout(words: String, box: Rect2, height: int=19, right: bool=false, heading: bool=false, centred: bool=false) -> Dictionary:
	var face: Font=title if heading else font
	var point:=_text_point(height,heading)
	while point>1 and (face.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,point).x>box.size.x or face.get_height(point)>box.size.y): point-=1
	var width:=face.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,point).x
	var x:=box.end.x-width if right else box.position.x
	if centred: x=box.position.x+(box.size.x-width)*0.5
	var y:=box.position.y+(box.size.y-face.get_height(point))*0.5+face.get_ascent(point)
	return {"point":point,"at":Vector2(x,y),"width":width}

func _text(words: String, box: Rect2, height: int=19, colour: Color=CREAM, right: bool=false, heading: bool=false, centred: bool=false) -> void:
	var face: Font=title if heading else font
	var layout:=_text_layout(words,box,height,right,heading,centred)
	_ink.draw_string(face,layout.at,words,HORIZONTAL_ALIGNMENT_LEFT,-1,layout.point,colour)

func _row_layout(box: Rect2, value: String, selected: bool=false, important: bool=false) -> Array[Rect2]:
	# Allocate from the exact visible value. Long readings receive space before
	# fitting the label; neither column can reach the other or the panel edge.
	var point:=_text_point(27 if important else 23)
	while point>1 and font.get_height(point)>box.size.y: point-=1
	var width:=clampf(font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,point).x+2,box.size.x*0.22,box.size.x*0.58)
	var left:=18.0 if selected else 10.0
	var right:=box.end.x-10
	return [Rect2(box.position+Vector2(left,0),Vector2(maxf(1,right-width-10-box.position.x-left),box.size.y)),Rect2(right-width,box.position.y,width,box.size.y)]

func _row(box: Rect2, label: String, value: String, colour: Color=CREAM, selected: bool=false, important: bool=false) -> void:
	var warning: bool=colour in [RED,AMBER] and not selected
	if warning:
		_ink.draw_rect(box.grow(-2),Color("3c241d") if colour==RED else Color("342d1b"))
		_ink.draw_line(box.position+Vector2(3,4),Vector2(box.position.x+3,box.end.y-4),colour,_diagram_stroke(2),true)
	if selected:
		_ink.draw_rect(box.grow(-2),Color("304332"))
		_ink.draw_rect(box.grow(-2),Color("6c7950"),false,_diagram_stroke(1),true)
		var at:=Vector2(box.position.x+6,box.get_center().y)
		var marker:=Vector2(maxf(6,4.0/_output_scale()),maxf(4,3.0/_output_scale()))
		_ink.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-marker.y),at+Vector2(marker.x,0),at+Vector2(0,marker.y)]),AMBER)
	var cells:=_row_layout(box,value,selected,important or warning or selected)
	_text(label,cells[0],20,AMBER if selected else colour if warning else MUTED,false,true)
	_text(value,cells[1],27 if important or warning or selected else 23,AMBER if selected else colour,true)
	_ink.draw_line(Vector2(box.position.x+8,box.end.y-1),Vector2(box.end.x-8,box.end.y-1),Color("354c3d"),_diagram_stroke(1),true)

func _reading_colour(run: Dictionary) -> Color:
	var colour: Color=run.get("foreground",Color.WHITE)
	return _state_colour(colour) if colour in [Ink.RED,Ink.YELLOW,Ink.GREEN] else CREAM

func _state_colour(colour: Color) -> Color:
	if colour.to_rgba32()==Ink.RED.to_rgba32(): return RED
	if colour.to_rgba32()==Ink.YELLOW.to_rgba32(): return AMBER
	if colour.to_rgba32()==Ink.GREEN.to_rgba32(): return GREEN
	return Color("26352a")

static func _lamp_shape(colour: Color, target_lock: bool=false) -> String:
	if colour.to_rgba32()==Ink.RED.to_rgba32(): return "target" if target_lock else "cross"
	if colour.to_rgba32()==Ink.YELLOW.to_rgba32(): return "dash"
	if colour.to_rgba32()==Ink.GREEN.to_rgba32(): return "filled"
	return "outline"

func _lamp_layout(box: Rect2, miniature: bool=false) -> Dictionary:
	var padding:=8.0 if miniature else 10.0
	var width:=minf(box.size.x*0.25,maxf(12 if miniature else 18,(7.0 if miniature else 9.0)/_output_scale()))
	var height:=minf(box.size.y-8,maxf(8,5.0/_output_scale()))
	var lamp:=Rect2(box.end.x-width-padding,box.position.y+(box.size.y-height)*0.5,width,height)
	var label:=Rect2(box.position+Vector2(padding,0),Vector2(maxf(1,lamp.position.x-6-box.position.x-padding),box.size.y))
	return {"lamp":lamp,"label":label}

func _lamp(box: Rect2, label: String, gauge: Dictionary, miniature: bool=false) -> void:
	var active: Color=_state_colour(gauge.color)
	var target_lock: bool=gauge.get("lock",false)
	# The original lock indicator uses red for active, unlike red system lamps.
	var warning: bool=active in [RED,AMBER] and not target_lock
	if warning:
		_ink.draw_rect(box.grow(-2),Color("3c241d") if active==RED else Color("342d1b"))
	var layout:=_lamp_layout(box,miniature)
	_text(label,layout.label,21 if miniature else 19,active if warning else MUTED,false,true)
	var b: Rect2=layout.lamp
	_ink.draw_rect(b.grow(2 if miniature else 3),Color("09130f"))
	# Shape repeats the already-proven source colour; no new status inference.
	var shape:=_lamp_shape(gauge.color,target_lock)
	if shape=="filled":
		_ink.draw_rect(b,active)
		_ink.draw_line(b.position,b.position+Vector2(b.size.x,0),active.lightened(0.18),_diagram_stroke(1),true)
	elif shape=="target":
		for x in [b.position.x,b.end.x]:
			for y in [b.position.y,b.end.y]:
				var corner:=Vector2(x,y)
				_ink.draw_line(corner,corner+Vector2(3 if x==b.position.x else -3,0),active,_diagram_stroke(1.2),true)
				_ink.draw_line(corner,corner+Vector2(0,2 if y==b.position.y else -2),active,_diagram_stroke(1.2),true)
	else:
		_ink.draw_rect(b,active if warning else Color("71846b"),false,_diagram_stroke(1),true)
		var inset:=b.grow(-2)
		if shape=="cross":
			_ink.draw_line(inset.position,inset.end,active,_diagram_stroke(1.4),true)
			_ink.draw_line(Vector2(inset.end.x,inset.position.y),Vector2(inset.position.x,inset.end.y),active,_diagram_stroke(1.4),true)
		elif shape=="dash":
			_ink.draw_line(Vector2(inset.position.x,b.get_center().y),Vector2(inset.end.x,b.get_center().y),active,_diagram_stroke(1.4),true)

static func _scale_layout(box: Rect2, count: int) -> Dictionary:
	var inner:=Rect2(box.position+Vector2(10,0),Vector2(box.size.x-20,box.size.y))
	var rail:=Rect2(inner.position.x,box.position.y+box.size.y*0.64,inner.size.x,minf(18,box.size.y*0.22))
	var cells: Array[Rect2]=[]
	var ticks: Array[Vector2]=[]
	var width:=minf(34,inner.size.x/float(count))
	for i in count:
		var x:=inner.position.x+inner.size.x*float(i)/float(count-1)
		cells.append(Rect2(clampf(x-width*0.5,inner.position.x,inner.end.x-width),box.position.y+box.size.y*0.08,width,box.size.y*0.38))
		ticks.append(Vector2(x,rail.position.y-4))
	return {"rail":rail,"labels":cells,"ticks":ticks}

func _bar_segments(rail: Rect2, count: int) -> Array[Rect2]:
	var result: Array[Rect2]=[]
	var pitch:=rail.size.x/count
	var gap:=maxf(2,1.0/_output_scale())
	for i in count: result.append(Rect2(rail.position+Vector2(i*pitch,0),Vector2(maxf(0,pitch-gap),rail.size.y)))
	return result

func _minor_ticks(rail: Rect2, count: int) -> Array[Vector2]:
	var ticks: Array[Vector2]=[]
	# Omit secondary engraving when original segment pitch is too dense.
	if count<=0 or rail.size.x/count*_output_scale()<5.0: return ticks
	for i in range(1,count):
		ticks.append(Vector2(rail.position.x+i*rail.size.x/count,rail.position.y-_diagram_stroke(2)))
	return ticks

func _bar(box: Rect2, gauge: Dictionary) -> void:
	var fuel: bool=gauge.name=="commander_fuel"
	var labels: Array=["E","F"] if fuel else ["0","30","60","90"]
	var layout:=_scale_layout(box,labels.size())
	var rail: Rect2=layout.rail
	for i in labels.size():
		_text(labels[i],layout.labels[i],19,MUTED,i==labels.size()-1,false,i>0 and i<labels.size()-1)
		var at:=Vector2(layout.ticks[i].x,rail.position.y-_diagram_stroke(2))
		_ink.draw_line(at-Vector2(0,maxf(5,4.0/_output_scale())),at,MUTED,_diagram_stroke(1),true)
	var segments:=_bar_segments(rail,gauge.count)
	# Minor ticks register to original bar cells, never a derived numeric reading.
	for at in _minor_ticks(rail,gauge.count):
		_ink.draw_line(at-Vector2(0,_diagram_stroke(2)),at,RULE,_diagram_stroke(1),true)
	for i in gauge.count:
		var colour: Color=_state_colour(gauge.colors[i]) if i<gauge.lit else Color("263b2d")
		var segment: Rect2=segments[i]
		_ink.draw_rect(segment,colour)
		if i<gauge.lit: _ink.draw_line(segment.position,segment.position+Vector2(segment.size.x,0),colour.lightened(0.16),_diagram_stroke(1),true)

func _navigation_layout(box: Rect2, source_size: Vector2) -> Dictionary:
	var target:=Rect2(box.position+Vector2(12,8),Vector2(box.size.x-24,box.size.y-40))
	# The original 320x200 screen occupies 4:3, so its pixels are 1.2x tall.
	# Fit the complete verified grid uniformly in physical display space.
	var pixel_aspect:=Vector2(1,1.2)
	var physical_size:=source_size*pixel_aspect
	var fit:=minf(target.size.x/physical_size.x,target.size.y/physical_size.y)
	var scale_xy:=pixel_aspect*fit
	var fitted:=Rect2(target.get_center()-source_size*scale_xy*0.5,source_size*scale_xy)
	return {"rect":fitted,"scale":scale_xy,"target":target}

func _diagram_stroke(width: float) -> float:
	# Panel drawing uses logical coordinates. Retain at least one output pixel
	# in wide and source-footprint layouts without changing any geometry.
	return maxf(width,1.0/_output_scale())

func _navigation(box: Rect2) -> void:
	var r: Array=orientation.rect
	var layout:=_navigation_layout(box,Vector2(r[2],r[3]))
	var scale_xy: Vector2=layout.scale
	var at: Vector2=layout.rect.position
	var origin:=Vector2(r[0],r[1])
	for line in orientation.grid:
		var p: Array=line.points
		var a: Vector2=(Vector2(p[0],p[1])-origin)*scale_xy+at
		var b: Vector2=(Vector2(p[2],p[3])-origin)*scale_xy+at
		_ink.draw_line(a,b,Color("304737"),_diagram_stroke(1),true)
	for index in orientation.quads.size():
		var quad: Dictionary=orientation.quads[index]
		var points:=PackedVector2Array()
		for p in quad.vertices_q14: points.append((Vector2(p[0],p[1])/16384.0-origin)*scale_xy+at)
		if quad.filled: _ink.draw_colored_polygon(points,NAVIGATION_FILLS[index])
		points.append(points[0]);_ink.draw_polyline(points,DIAGRAM_EDGE,_diagram_stroke(1.7),true)
		for i in quad.edges.size():
			var c: Color=preload("res://scripts/pc_orientation_art.gd").PALETTE[int(quad.edges[i])]
			_ink.draw_line(points[i],points[i+1],_state_colour(c) if c in [Ink.RED,Ink.GREEN,Ink.YELLOW] else CREAM,_diagram_stroke(2),true)
	_ink.draw_line(Vector2(box.position.x+10,box.end.y-32),Vector2(box.end.x-10,box.end.y-32),RULE,1,true)
	_row(Rect2(box.position.x,box.end.y-30,box.size.x,30),"HEADING",_value(173,188) if station==1 else _value(261,134))

func _systems(box: Rect2, miniature: bool) -> void:
	var row_height: float=box.size.y/6.0
	for i in 12:
		var right:=i>=6
		var row:=Rect2(box.position+Vector2(box.size.x*0.5 if right else 0,(i%6)*row_height),Vector2(box.size.x*0.5-8,row_height-3))
		var gauge:=_gauge(("commander_" if miniature else "status_")+Ink.SYSTEM_NAMES[i])
		_lamp(row,SYSTEMS[i],gauge,miniature)
		if not miniature: _ink.draw_line(Vector2(row.position.x+10,row.end.y),Vector2(row.end.x-10,row.end.y),Color("354c3d"),_diagram_stroke(1),true)

# Technical plan-view schematic. Geometry is authored; damage overlays use only
# the five already-proven visible source bits, at their original diagram zones.
func _tank_layout(box: Rect2) -> Dictionary:
	var fit:=minf(box.size.x/400.0,box.size.y/155.0)
	return {"at":box.get_center()-Vector2(400,155)*fit*0.5,"scale":Vector2.ONE*fit,
		"detail":400*fit*_output_scale()>=300}

func _mechanical_pitch(authored: int, fit: float) -> int:
	# Repeated shoes and louvers are illustration detail, never a state count.
	return authored*maxi(1,ceili(4.0/(authored*fit*_output_scale())))

func _damage_layout(zone: Rect2, at: Vector2, scale_xy: Vector2) -> Dictionary:
	var box:=Rect2(at+zone.position*scale_xy,zone.size*scale_xy)
	var inner:=box.grow(-_diagram_stroke(2.5))
	var pitch:=maxf(10*scale_xy.x,7.0/_output_scale())
	var lines: Array[PackedVector2Array]=[]
	var offset: float=-inner.size.y+pitch
	while offset<inner.size.x:
		var a:=Vector2(maxf(0,offset),maxf(0,-offset))
		var b:=Vector2(minf(inner.size.x,offset+inner.size.y),minf(inner.size.y,inner.size.x-offset))
		if a.distance_to(b)*_output_scale()>=2:
			lines.append(PackedVector2Array([inner.position+a,inner.position+b]))
		offset+=pitch
	return {"rect":box,"inner":inner,"lines":lines,"pitch":pitch,
		"corner":minf(minf(box.size.x,box.size.y)*0.24,maxf(10,6.0/_output_scale()))}

func _tank(box: Rect2, bits: int) -> void:
	var layout:=_tank_layout(box)
	var scale_xy: Vector2=layout.scale
	var at: Vector2=layout.at
	var hull:=PackedVector2Array([Vector2(112,19),Vector2(364,19),Vector2(382,35),Vector2(382,121),Vector2(364,136),Vector2(112,136),Vector2(92,114),Vector2(92,43)])
	_poly(hull,at,scale_xy,Color("243a29"),DIAGRAM_EDGE)
	for y in [7,124]:
		_rect(Rect2(112,y,264,24),at,scale_xy,Color("1a2c22"),DIAGRAM_EDGE)
		var pitch:=_mechanical_pitch(9,scale_xy.x)
		for x in range(117,374,pitch):
			_line(Vector2(x,y+3),Vector2(x,y+21),at,scale_xy,Color("789568"))
		if layout.detail:
			for rail in [y+6,y+18]: _line(Vector2(115,rail),Vector2(373,rail),at,scale_xy,Color("4d684c"))
	_rect(Rect2(308,37,56,79),at,scale_xy,FIELD,DIAGRAM_EDGE)
	for y in range(43,115,_mechanical_pitch(7,scale_xy.x)):
		_line(Vector2(314,y),Vector2(358,y),at,scale_xy,Color("789568"))
	if layout.detail:
		_line(Vector2(336,41),Vector2(336,112),at,scale_xy,Color("4d684c"))
		for y in [43,112]: _line(Vector2(99,y),Vector2(121,y),at,scale_xy,DIAGRAM_EDGE)
	_poly(PackedVector2Array([Vector2(145,41),Vector2(205,30),Vector2(282,43),Vector2(301,61),Vector2(294,106),Vector2(218,125),Vector2(145,108),Vector2(129,91),Vector2(129,59)]),at,scale_xy,Color("3e5838"),CREAM)
	# Inset deck faces leave the original outer silhouette and registration intact.
	_poly(PackedVector2Array([Vector2(145,45),Vector2(176,39),Vector2(176,111),Vector2(147,104),Vector2(134,88),Vector2(134,61)]),at,scale_xy,Color("30482f"),DIAGRAM_EDGE)
	if layout.detail:
		_poly(PackedVector2Array([Vector2(277,48),Vector2(295,64),Vector2(288,101),Vector2(269,106)]),at,scale_xy,Color("30482f"),DIAGRAM_EDGE)
	_rect(Rect2(130,64,51,28),at,scale_xy,Color("233628"),CREAM)
	_rect(Rect2(12,73,128,10),at,scale_xy,Color("526747"),CREAM)
	_rect(Rect2(9,70,14,16),at,scale_xy,Color("233628"),CREAM)
	if layout.detail:
		for x in [72,108]: _line(Vector2(x,73),Vector2(x,83),at,scale_xy,CREAM)
	for c in [Vector2(222,65),Vector2(254,94)]:
		_ink.draw_circle(at+c*scale_xy,13*scale_xy.x,Color("2a402d"),true,-1,true)
		_ink.draw_arc(at+c*scale_xy,13*scale_xy.x,0,TAU,40,CREAM,_diagram_stroke(1.3),true)
		if layout.detail: _ink.draw_arc(at+c*scale_xy,9*scale_xy.x,0,TAU,32,DIAGRAM_EDGE,_diagram_stroke(1),true)
		_line(c-Vector2(8,0),c+Vector2(8,0),at,scale_xy,DIAGRAM_EDGE)
	_line(Vector2(180,47),Vector2(180,108),at,scale_xy,DIAGRAM_EDGE)
	_line(Vector2(197,40),Vector2(271,48),at,scale_xy,DIAGRAM_EDGE)
	if bits<=0: return
	# Translucent alerts retain the anatomy beneath the exact PC damage zones.
	for i in 5:
		if (bits&(1<<i))==0: continue
		var alert:=_damage_layout(DAMAGE_ZONES[i],at,scale_xy)
		var r: Rect2=alert.rect
		_ink.draw_rect(r,Color(RED,0.18))
		_ink.draw_rect(r,Color(RED,0.65),false,_diagram_stroke(1),true)
		for line in alert.lines: _ink.draw_polyline(line,Color(RED,0.6),_diagram_stroke(1),true)
		for x in [r.position.x,r.end.x]:
			for y in [r.position.y,r.end.y]:
				var corner:=Vector2(x,y)
				_ink.draw_line(corner,corner+Vector2(alert.corner if x==r.position.x else -alert.corner,0),RED,_diagram_stroke(1.8),true)
				_ink.draw_line(corner,corner+Vector2(0,alert.corner if y==r.position.y else -alert.corner),RED,_diagram_stroke(1.8),true)

func _poly(points: PackedVector2Array, at: Vector2, scale_xy: Vector2, fill: Color, stroke: Color) -> void:
	var transformed:=PackedVector2Array()
	for p in points: transformed.append(at+p*scale_xy)
	_ink.draw_colored_polygon(transformed,fill);transformed.append(transformed[0]);_ink.draw_polyline(transformed,stroke,_diagram_stroke(1.4),true)
func _rect(box: Rect2, at: Vector2, scale_xy: Vector2, fill: Color, stroke: Color) -> void:
	var r:=Rect2(at+box.position*scale_xy,box.size*scale_xy)
	_ink.draw_rect(r,fill);_ink.draw_rect(r,stroke,false,_diagram_stroke(1.2),true)
func _line(a: Vector2,b: Vector2,at: Vector2,scale_xy: Vector2,colour: Color) -> void:
	_ink.draw_line(at+a*scale_xy,at+b*scale_xy,colour,_diagram_stroke(1),true)

func _paint_panel(panel: Dictionary, painter: CanvasItem) -> void:
	_ink=painter
	var factor:=size/canvas_size
	_ink.draw_set_transform(-painter.get_parent().position,0,factor)
	var box: Rect2=panel.rect
	var index: int=panel.index
	_ink.draw_rect(box,FIELD)
	_ink.draw_rect(box.grow(-1),Color("354c3d"),false,1,true)
	_ink.draw_line(box.position+Vector2(2,2),Vector2(box.end.x-2,box.position.y+2),Color("4a6250"),1,true)
	_ink.draw_line(Vector2(box.position.x+2,box.end.y-2),box.end-Vector2(2,2),Color("07130e"),2,true)
	if station==1:
		if index==1:
			var height:=box.size.y/3
			for i in 3:
				var label: String=["ID","RANGE",_value(16,165)][i]
				_row(Rect2(box.position+Vector2(0,i*height),Vector2(box.size.x,height)),label,_value(52,143+i*11),_reading_colour(_run(Vector2(52,143+i*11))),false,i>0)
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
	_ink=self
