extends RefCounted
## Original command order and captured ellipse spans, no inferred silhouette.
static func ordered(object: Dictionary) -> Array:
	var result: Array = []
	if object.get("draw_order") is Array:
		for entry in object.draw_order:
			if not entry is Dictionary: continue
			var kind := str(entry.get("kind",""))
			var index := int(entry.get("index",-1))
			var items: Array = object.get("polygons",[]) if kind=="polygon" else object.get("round_forms",[]) if kind=="round_form" else []
			if index>=0 and index<items.size(): result.append({"kind":kind,"data":items[index]})
	else:
		for polygon: Dictionary in object.get("polygons",[]): result.append({"kind":"polygon","data":polygon})
	return result

static func round_runs(form: Dictionary, frame: Dictionary) -> Array:
	var result: Array = []
	if form.get("status","")!="observed" or not form.get("spans") is Array: return result
	for span in form.spans:
		if not span is Dictionary: continue
		var y := int(span.get("y",-32768))
		var left := maxi(int(span.get("left",0)),int(frame.clip[0]))
		var right := mini(int(span.get("right",0)),int(frame.clip[2])+1)
		var color := int(span.get("color",-1))
		if y<int(frame.clip[1]) or y>int(frame.clip[3]) or right<=left or color<0 or color>15: continue
		result.append({"points":[Vector2(left,y),Vector2(right,y),Vector2(right,y+1),Vector2(left,y+1)],"color":color})
	return result

static func crew_head(object: Dictionary, form: Dictionary) -> bool:
	# This paints only a witnessed source head. It never invents a missing
	# command, ellipse, pose or radius, and does not affect radar/dish commands.
	var shape:=int(object.get("shape_index",-1))
	if shape not in [161,162] or form.get("status","")!="observed":return false
	if int(form.get("command_offset",-1))!=(30996 if shape==161 else 31422):return false
	var command=form.get("command",[])
	if not command is Array or command.size()!=4:return false
	for i in 4:
		if command[i]!=[170,15,2,171][i]:return false
	if int(form.get("fill_mode",0))!=1:return false
	for key in ["radius","horizontal_radius"]:
		var value=form.get(key,0)
		if not (value is int or value is float) or not is_finite(float(value)) or value<1 or value>128:return false
	var center=form.get("center",[])
	if not center is Array or center.size()!=2:return false
	for value in center:
		if not (value is int or value is float) or not is_finite(float(value)):return false
	return true
