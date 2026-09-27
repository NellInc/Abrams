extends RefCounted
## Independent geometric oracle, without using FontFile rasterization or meshes.
var faces := {}
var cache := {}

func load_sources(root_path: String) -> void:
	faces.clear();cache.clear()
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(root_path.path_join("local-art/pc-outline-fonts-v1/manifest.json")))
	for face in data.faces:
		faces[face.source_sha256]=face

func classification(sha: String, code: int, p: Vector2, scale: Vector2) -> int:
	var key:="%s:%d:%s:%s"%[sha,code,str(p),str(scale)]
	if cache.has(key): return cache[key]
	var polygons: Array=faces[sha].glyphs[code-32].contours
	var inside:=false
	var distance:=INF
	for polygon in polygons:
		for i in polygon.size():
			var av: Array=polygon[i];var bv: Array=polygon[(i+1)%polygon.size()]
			var a:=Vector2(av[0],av[1]);var b:=Vector2(bv[0],bv[1])
			var edge:=(b-a)*scale
			var delta:=(p-a)*scale
			var amount:=clampf(delta.dot(edge)/maxf(edge.length_squared(),0.00001),0,1)
			distance=minf(distance,(delta-edge*amount).length())
			if (a.y>p.y)!=(b.y>p.y) and p.x<(b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x: inside=not inside
	var result:= -1 if distance<0.8 else int(inside)
	cache[key]=result
	return result

func matches(actual: Color, run: Dictionary, source_point: Vector2, scale: Vector2) -> bool:
	var point: Vector2=source_point-run.rect.position
	var cell: Vector2=run.cell_size
	var column:=floori(point.x/cell.x)
	if column<0 or column>=run.text.length(): return false
	point.x-=column*cell.x
	var state:=classification(run.font_sha256,run.text.unicode_at(column),point,scale)
	var fg: Color=run.foreground
	var bg: Color=run.background
	if state>=0:
		var expected:=fg if state==1 else bg
		return absf(actual.r-expected.r)<=2.0/255 and absf(actual.g-expected.g)<=2.0/255 and absf(actual.b-expected.b)<=2.0/255
	# The subpixel edge band must contain only antialias mixtures of the two
	# declared colours. Interior/exterior pixels above are checked exactly.
	var a:=Vector3(actual.r,actual.g,actual.b);var low:=Vector3(bg.r,bg.g,bg.b);var high:=Vector3(fg.r,fg.g,fg.b)
	var d:=high-low
	var t:=clampf((a-low).dot(d)/maxf(d.length_squared(),0.00001),0,1)
	return a.distance_to(low+d*t)<0.02
