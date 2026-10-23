extends RefCounted
## Optional source-bounded firing setup. Registry and normalized head stay intact.
const Modern=preload("res://scripts/pc_modern_assets.gd")

static func validate(value:Variant,source:Dictionary,head:Variant) -> bool:
	if int(source.get("shape_index",-1)) not in [161,162] or not head is Dictionary or not value is Dictionary:return false
	if value.size()!=4 or value.get("schema")!=1 or value.get("kind")!="ground-atgm-v1":return false
	var columns:Variant=value.get("head_basis")
	if not columns is Array or columns.size()!=3 or not Modern.vector_ok(value.get("head_origin")):return false
	for column in columns:
		if not Modern.vector_ok(column):return false
	var basis:=Basis(Modern.vec(columns[0]),Modern.vec(columns[1]),Modern.vec(columns[2]))
	var lengths:=Vector3(basis.x.length(),basis.y.length(),basis.z.length())
	if lengths[lengths.min_axis_index()]<0.00001 or lengths[lengths.max_axis_index()]>4.0:return false
	if lengths[lengths.max_axis_index()]/lengths[lengths.min_axis_index()]>1.00001 or basis.determinant()<=0:return false
	if absf(basis.x.dot(basis.y))>lengths.x*lengths.y*0.00001 or absf(basis.x.dot(basis.z))>lengths.x*lengths.z*0.00001 or absf(basis.y.dot(basis.z))>lengths.y*lengths.z*0.00001:return false
	for triangle:Dictionary in head.get("triangles",[]):
		for point:Array in triangle.vertices:
			if not bounded(head_point(value,point),source.source_bounds):return false
	return true

static func bounded(point:Vector3,bounds:Dictionary) -> bool:
	if not point.is_finite():return false
	for axis in 3:
		if point[axis]<float(bounds.min[axis])-0.00001 or point[axis]>float(bounds.max[axis])+0.00001:return false
	return true

static func head_point(pose:Dictionary,normalized:Array) -> Vector3:
	return Basis(Modern.vec(pose.head_basis[0]),Modern.vec(pose.head_basis[1]),Modern.vec(pose.head_basis[2]))*(Modern.vec(normalized)*Vector3(18,18,15))+Modern.vec(pose.head_origin)
