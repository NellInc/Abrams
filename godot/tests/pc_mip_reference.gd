extends RefCounted
## Native-capture reference for mipmapped, linearly filtered donors. Trilinear
## sampling is a convex blend of bilinear samples from the two mip levels
## around the minification level, so every output channel must lie inside the
## range of those samples. Test helper only; production never loads it.

static func level(image: Image, index: int) -> Image:
	if index<=0 or not image.has_mipmaps(): return image
	index=mini(index,image.get_mipmap_count())
	var size:=Vector2i(maxi(1,image.get_width()>>index),maxi(1,image.get_height()>>index))
	var start:=image.get_mipmap_offset(index)
	var end:=image.get_mipmap_offset(index+1) if index<image.get_mipmap_count() else image.get_data_size()
	return Image.create_from_data(size.x,size.y,false,image.get_format(),image.get_data().slice(start,end))

static func bilinear(image: Image, uv: Vector2) -> Color:
	var p:=uv*Vector2(image.get_size())-Vector2(0.5,0.5)
	var at:=Vector2i(floori(p.x),floori(p.y))
	var f:=p-Vector2(at)
	var limit:=image.get_size()-Vector2i.ONE
	var c00:=image.get_pixelv(at.clamp(Vector2i.ZERO,limit))
	var c10:=image.get_pixelv((at+Vector2i.RIGHT).clamp(Vector2i.ZERO,limit))
	var c01:=image.get_pixelv((at+Vector2i.DOWN).clamp(Vector2i.ZERO,limit))
	var c11:=image.get_pixelv((at+Vector2i.ONE).clamp(Vector2i.ZERO,limit))
	return c00.lerp(c10,f.x).lerp(c01.lerp(c11,f.x),f.y)

## texels_per_pixel: donor texels covered by one output pixel along the more
## minified axis. Returns one bilinear sample per candidate mip level; levels
## within 0.1 of the computed LOD boundary are all included. cache holds this
## image's decoded levels and must not be shared between images.
static func samples(image: Image, uv: Vector2, texels_per_pixel: float, cache: Dictionary) -> Array[Color]:
	var lod:=log(maxf(texels_per_pixel,1.0))/log(2.0)
	var top:=image.get_mipmap_count() if image.has_mipmaps() else 0
	var result: Array[Color]=[]
	var last:=0 if lod<=0.0 else clampi(ceili(lod+0.1),0,top) # magnified: level 0 only
	for index in range(clampi(floori(lod-0.1),0,top),last+1):
		if not cache.has(index): cache[index]=level(image,index)
		result.append(bilinear(cache[index],uv))
	return result

static func inside(actual: Color, candidates: Array, tolerance: float) -> bool:
	for channel in 3:
		var low:=INF
		var high:=-INF
		for c: Color in candidates:
			low=minf(low,c[channel])
			high=maxf(high,c[channel])
		if actual[channel]<low-tolerance or actual[channel]>high+tolerance: return false
	return true
