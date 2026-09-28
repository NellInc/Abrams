extends Control
## Only observed original map rectangles, with complete scanout readback custody.
const SIM_SHA="9ee5a5898ddcb8192d30b4083981419515eb3ca220e6cbcd214df628bb164099"
const MAP_RECT=Rect2i(16,63,144,96)
var packet:Dictionary={}
var rectangles:Array=[]
func _init()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	hide()
func clear()->void:
	packet.clear();rectangles.clear();hide();queue_redraw()
static func integer(v)->bool:return (v is int or v is float) and is_finite(float(v)) and float(v)==floor(float(v))
func set_frame(source:Image,presentation:Dictionary)->bool:
	clear()
	var item=presentation.get("dynamic_map")
	if not item is Dictionary or item.get("schema")!=1 or item.get("source_sha256")!=SIM_SHA:return false
	if not integer(item.get("mode")) or int(item.mode) not in [0,1]:return false
	if not integer(item.get("page_offset")) or int(item.page_offset) not in [0,8192] or item.page_offset!=presentation.get("page_offset"):return false
	if not item.get("rect") is Array or item.rect.size()!=4:return false
	for i in 4:
		if not integer(item.rect[i]) or int(item.rect[i])!=[16,63,144,96][i]:return false
	if source==null or source.get_size()!=Vector2i(320,200):return false
	var crop:=source.get_region(MAP_RECT);crop.convert(Image.FORMAT_RGB8)
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(crop.get_data())
	if hash.finish().hex_encode()!=item.get("pixel_sha256"):return false
	var palette=item.get("palette_rgb")
	if not palette is Array or palette.size()!=16:return false
	var colors:Array[Color]=[]
	for rgb in palette:
		if not rgb is Array or rgb.size()!=3:return false
		for c in rgb:
			if not integer(c) or c<0 or c>255:return false
		colors.append(Color8(int(rgb[0]),int(rgb[1]),int(rgb[2])))
	if not item.get("lines") is Array or item.lines.is_empty() or item.lines.size()>4609:return false
	var shapes:Array=[]
	if item.mode==0:
		if not integer(item.get("background")) or item.background<0 or item.background>15:return false
		shapes.append([Rect2(MAP_RECT),colors[int(item.background)]])
	elif item.lines.size()!=2 or item.get("background")!=null:return false
	for line in item.lines:
		if not line is Array or line.size()!=5:return false
		for value in line:
			if not integer(value):return false
		var x1:=int(line[0]);var y1:=int(line[1]);var x2:=int(line[2]);var y2:=int(line[3]);var c:=int(line[4])
		if x1<16 or x2>159 or x1>x2 or y1!=y2 or y1<63 or y1>158 or c<0 or c>15:return false
		if item.mode==1 and [x1,y1,x2,y2] not in [[87,110,88,110],[87,111,88,111]]:return false
		shapes.append([Rect2(x1,y1,x2-x1+1,1),colors[c]])
	# Reproduce the source raster independently before emitting any higher-res ink.
	var proof:=crop.duplicate()
	for shape in shapes:
		var r:=Rect2i(shape[0]);r.position-=MAP_RECT.position
		proof.fill_rect(r,shape[1])
	if proof.get_data()!=crop.get_data():return false
	packet=item.duplicate(true);rectangles=shapes;show();queue_redraw();return true
func _draw()->void:
	var factor:=size/Vector2(320,200)
	for shape in rectangles:
		var rect:Rect2=shape[0]
		draw_rect(Rect2(rect.position*factor,rect.size*factor),shape[1])
