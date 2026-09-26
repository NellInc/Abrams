extends SceneTree
const PC = preload("res://scripts/pc_rules.gd")

func _initialize() -> void:
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pc_bearings.json"))
	if not fixture is Dictionary or not fixture.get("rows") is Array or fixture.rows.size() != 256:
		printerr("FAIL: missing or malformed original CPU bearing fixture")
		quit(1)
		return
	var failures: Array[String] = []
	for i in 256:
		var row: Array = fixture.rows[i]
		if int(row[0]) != i or PC.bearing_degrees(i) != int(row[1]) or PC.bearing_digits(i) != row[2]:
			failures.append("original bearing/bark mismatch at input %d" % i)
	if failures.is_empty():
		print("PC_RULES: 256 degree values and 256 hit-bark strings match original CPU fixture")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)
