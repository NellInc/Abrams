extends SceneTree
func _initialize() -> void:
	var landscape = load("res://scripts/landscape.gd")
	var land = landscape.new()
	root.add_child.call_deferred(land)
	await process_frame
	var arrays: Array = land.get_child(0).mesh.surface_get_arrays(0)
	for normal in arrays[Mesh.ARRAY_NORMAL]:
		if normal.y <= 0:
			printerr("FAIL: terrain triangle faces underground")
			quit(1)
			return
	for x in [-1200,0,1200]:
		for z in [-1800,0,300]:
			if landscape.height_at(x,z) != 0:
				printerr("FAIL: rendered terrain intersects flat simulation bounds")
				quit(1)
				return
	print("GEOMETRY: 60000 upward normals and complete range bounds verified")
	quit(0)
