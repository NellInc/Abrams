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
	# Placement is seeded: these counts change if the RNG draw order before or during placement changes.
	# Children 1-4 are trunks, broadleaf crowns, grass clumps and conifer crowns; every tree has one trunk.
	var trunks: int = land.get_child(1).multimesh.instance_count
	var broadleaf: int = land.get_child(2).multimesh.instance_count
	var conifers: int = land.get_child(4).multimesh.instance_count
	if trunks != 828 or broadleaf != 539 or conifers != 289 or broadleaf + conifers != trunks or land.get_child(3).multimesh.instance_count != 28484:
		printerr("FAIL: seeded tree/grass placement changed")
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
