extends RefCounted
## Recovered PC rules only. The provisional range still uses its own angle basis.

static func bearing_degrees(internal_byte: int) -> int:
	assert(internal_byte >= 0 and internal_byte <= 255, "PC bearing requires an unsigned byte")
	# SIM 0000:56ea. Its multiply/shift truncates before reversing direction.
	return (360 - ((internal_byte * 360) >> 8)) % 360

static func bearing_digits(internal_byte: int) -> String:
	# SIM 0000:3d0e calls the zero-padded, width-three formatter at 0000:527c.
	return "%03d" % bearing_degrees(internal_byte)
