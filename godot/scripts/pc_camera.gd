extends RefCounted
## Original camera matrix and asymmetric projection. Display scaling is handled
## outside the 3D viewport so the original rectangular pixels stay consistent.
const WorldView = preload("res://scripts/pc_world_view.gd")

static func apply(camera: Camera3D, frame: Dictionary, anchor: Vector3) -> Vector2i:
	var values: Array = frame.matrix_q14_columns
	var matrix := Basis(Vector3(values[0], values[1], values[2]) / 16384.0,
		Vector3(values[3], values[4], values[5]) / 16384.0,
		Vector3(values[6], values[7], values[8]) / 16384.0)
	var axis := Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
	camera.basis = (axis * matrix * axis.inverse()).inverse()
	camera.position = WorldView.coordinates(frame.world_position_raw) - anchor
	var clip: Array = frame.clip
	var dimensions := Vector2i(int(clip[2] - clip[0] + 1), int(clip[3] - clip[1] + 1))
	var near_plane := float(frame.near_raw) / WorldView.DISPLAY_SCALE
	var factor := near_plane / float(frame.focal_pixels)
	var offset := Vector2((float(clip[0] + clip[2] + 1) * 0.5 - float(frame.center[0])) * factor,
		(float(frame.center[1]) - float(clip[1] + clip[3] + 1) * 0.5) * factor)
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.set_frustum(float(dimensions.y) * factor, offset, near_plane, 2048.0)
	return dimensions
