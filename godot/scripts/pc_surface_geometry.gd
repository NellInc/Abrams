extends RefCounted
## Presentation-only geometry. Original clipping/raster integer rounding remains
## a separate parity question; these surfaces never feed gameplay decisions.
static func near_clip(points: Array, near_y: float) -> Array:
	var result: Array = []
	if points.is_empty(): return result
	var a: Array = points[-1]
	for b: Array in points:
		var a_in := float(a[1]) >= near_y
		var b_in := float(b[1]) >= near_y
		if a_in != b_in:
			var t := (near_y - float(a[1])) / (float(b[1]) - float(a[1]))
			var cut: Array=[lerpf(a[0], b[0], t), near_y, lerpf(a[2], b[2], t)]
			# Optional surface UVs follow the exact same clipping intersection.
			if a.size()==5 and b.size()==5:
				cut.append_array([lerpf(a[3],b[3],t),lerpf(a[4],b[4],t)])
			result.append(cut)
		if b_in: result.append(b)
		a = b
	return result

static func project(p: Array, camera: Dictionary) -> Vector2:
	return Vector2(float(camera.center[0]) + float(p[0]) * float(camera.focal_pixels) / float(p[1]),
		float(camera.center[1]) - float(p[2]) * float(camera.focal_pixels) / float(p[1]))

static func unproject(p: Vector2, depth: float, camera: Dictionary) -> Array:
	return [(p.x - float(camera.center[0])) * depth / float(camera.focal_pixels), depth,
		(float(camera.center[1]) - p.y) * depth / float(camera.focal_pixels)]

static func triangle_vertices(points: Array, camera: Dictionary) -> Array:
	var clipped := near_clip(points, float(camera.near_raw))
	if clipped.size() < 3: return []
	var screen := PackedVector2Array()
	for p: Array in clipped: screen.append(project(p, camera))
	var indices := Geometry2D.triangulate_polygon(screen)
	var output: Array = []
	for index in indices: output.append(clipped[index])
	return output

static func line_vertices(a: Array, b: Array, camera: Dictionary) -> Array:
	var near_y := float(camera.near_raw)
	if a[1] < near_y and b[1] < near_y: return []
	if a[1] < near_y:
		var t := (near_y - float(a[1])) / (float(b[1]) - float(a[1]))
		a = [lerpf(a[0], b[0], t), near_y, lerpf(a[2], b[2], t)]
	elif b[1] < near_y:
		var t := (near_y - float(b[1])) / (float(a[1]) - float(b[1]))
		b = [lerpf(b[0], a[0], t), near_y, lerpf(b[2], a[2], t)]
	var pa := project(a, camera)
	var pb := project(b, camera)
	if pa.is_equal_approx(pb): return []
	var perpendicular := (pb - pa).orthogonal().normalized() * 0.5
	var q := [unproject(pa + perpendicular, a[1], camera), unproject(pa - perpendicular, a[1], camera),
		unproject(pb - perpendicular, b[1], camera), unproject(pb + perpendicular, b[1], camera)]
	return [q[0], q[1], q[2], q[0], q[2], q[3]]

static func textured_triangles(points: Array, uv: Array, camera: Dictionary) -> Array:
	if points.size()!=uv.size(): return []
	var attributed: Array=[]
	for i in points.size():
		attributed.append([points[i][0],points[i][1],points[i][2],uv[i].x,uv[i].y])
	return triangle_vertices(attributed,camera)

static func background_polygons(background: Dictionary, camera: Dictionary) -> Array:
	var clip: Array = camera.clip
	var corners := [Vector2(clip[0], clip[1]), Vector2(clip[2] + 1, clip[1]),
		Vector2(clip[2] + 1, clip[3] + 1), Vector2(clip[0], clip[3] + 1)]
	if background.kind == "solid": return [{"points": corners, "material": background.color}]
	var a := Vector2(background.line[0][0], background.line[0][1])
	var b := Vector2(background.line[1][0], background.line[1][1])
	if a.x > b.x:
		var swap := a
		a = b
		b = swap
	if is_equal_approx(a.x, b.x): return [] # vertical split requires separate original evidence
	var result: Array = []
	for half in 2:
		var polygon: Array = []
		var p: Vector2 = corners[-1]
		var sign := 1.0 if half == 0 else -1.0
		for q: Vector2 in corners:
			var pd := (b - a).cross(p - a) * sign
			var qd := (b - a).cross(q - a) * sign
			if (pd <= 0.0) != (qd <= 0.0): polygon.append(p.lerp(q, pd / (pd - qd)))
			if qd <= 0.0: polygon.append(q)
			p = q
		result.append({"points": polygon, "material": background.colors[half]})
	return result

static func sprite_runs(sprite: Dictionary, camera: Dictionary) -> Array:
	# Original bitmap pixels, not a guessed billboard scale. Transparent pixels
	# emit no triangles, preserving earlier original surfaces in painter order.
	var result: Array = []
	var left: int = maxi(int(sprite.clip[0]), int(camera.clip[0]))
	var top: int = maxi(int(sprite.clip[1]), int(camera.clip[1]))
	var right: int = mini(int(sprite.clip[2]), int(camera.clip[2]))
	var bottom: int = mini(int(sprite.clip[3]), int(camera.clip[3]))
	for row in int(sprite.height):
		var y: int = int(sprite.origin[1]) + row
		if y < top or y > bottom: continue
		var col: int = maxi(0, left - int(sprite.origin[0]))
		var end: int = mini(int(sprite.width), right - int(sprite.origin[0]) + 1)
		while col < end:
			var at: int = row * int(sprite.width) + col
			if not sprite.opaque[at]:
				col += 1
				continue
			var color: int = int(sprite.pixels[at])
			var start := col
			col += 1
			while col < end and sprite.opaque[row * int(sprite.width) + col] and int(sprite.pixels[row * int(sprite.width) + col]) == color:
				col += 1
			var x: int = int(sprite.origin[0]) + start
			result.append({"points": [Vector2(x, y), Vector2(x + col - start, y),
				Vector2(x + col - start, y + 1), Vector2(x, y + 1)], "color": color})
	return result
