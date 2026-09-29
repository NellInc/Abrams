extends RefCounted
## Material selection for the pinned, opaque Genesis armour donors. Their black
## hardware outlines bound each scanline; the old oversized circles/rectangles
## left silver armour halos. RGB is never changed. Alpha carries metal coverage
## to the cupola shader, which restores opaque alpha before compositing.
const SIZE := Vector2i(1586,992)
# Tight donor-texel search windows, not painted/protected rectangles. Adjacent
# deck seams are excluded from each window; only spans between ink edges count.
const HARDWARE := [
	Rect2i(405,548,30,14),Rect2i(760,548,32,14),
	Rect2i(424,633,21,10),Rect2i(760,633,21,10),
	Rect2i(315,688,21,10),Rect2i(869,688,21,10),
	Rect2i(353,911,41,23),Rect2i(563,826,41,21),
	Rect2i(795,782,31,19),Rect2i(1249,808,35,21),
	Rect2i(1186,894,41,19),Rect2i(1530,911,41,23),
	Rect2i(526,954,39,24),Rect2i(1341,952,41,22),
	Rect2i(945,645,113,16),Rect2i(947,661,112,117),
	Rect2i(913,778,147,21)]

# Driver hinges, filler caps, deck bolts and instrument housing. These windows
# contain the individual ink contours, never a broad protected patch of deck.
const DRIVER_HARDWARE := [
	Rect2i(228,552,169,94),Rect2i(1188,552,171,94),
	# Cap bodies, side arms and front tabs are separate: a single bounding
	# window also catches diagonal deck seams beneath the projecting arms.
	Rect2i(89,717,159,71),Rect2i(34,747,64,29),Rect2i(129,768,60,31),
	Rect2i(1335,717,160,71),Rect2i(1486,747,63,29),Rect2i(1398,768,55,31),
	Rect2i(68,864,54,36),Rect2i(318,774,43,27),
	Rect2i(484,708,34,23),Rect2i(1065,708,36,23),
	Rect2i(1222,774,45,27),Rect2i(1459,864,59,36),
	Rect2i(264,839,1057,153)]

static func prepare(donor: Image) -> Image:
	return _prepare(donor,HARDWARE)

static func prepare_driver(donor: Image) -> Image:
	return _prepare(donor,DRIVER_HARDWARE)

static func _prepare(donor: Image, hardware: Array) -> Image:
	if donor==null or donor.get_size()!=SIZE: return null
	var rgba: Image = donor.duplicate()
	rgba.convert(Image.FORMAT_RGBA8)
	var bytes: PackedByteArray = rgba.get_data()
	# This channel is safe only for the verified all-opaque donor. Reject an
	# unexpected cutout instead of silently erasing its transparency contract.
	for at in range(3,bytes.size(),4):
		if bytes[at]!=255: return null
		bytes[at]=0
	for box: Rect2i in hardware:
		for y in range(box.position.y,box.end.y):
			var left := -1
			var right := -1
			for x in range(box.position.x,box.end.x):
				var at := (y*SIZE.x+x)*4
				if maxi(bytes[at],maxi(bytes[at+1],bytes[at+2]))>=65: continue
				if left<0: left=x
				right=x
			if right<=left: continue
			for x in range(left,right+1): bytes[(y*SIZE.x+x)*4+3]=255
	return Image.create_from_data(SIZE.x,SIZE.y,false,Image.FORMAT_RGBA8,bytes)
