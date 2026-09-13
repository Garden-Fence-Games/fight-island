class_name PosedMesh
extends RefCounted
## Freezes a skinned mesh into the pose it is standing in, as a plain mesh with no skeleton.
##
## **A corpse must not keep a skeleton.** Measured on this island: a duplicated rig costs about
## 0.4 ms a frame even with its scripts stripped, its physics freed and its `process_mode` disabled,
## because a `Skeleton3D` updates its own bone transforms on an engine notification rather than in
## `_process`. Sixteen bodies came to 15 ms of a 16.7 ms frame, and a fifteen-wave run kills several
## hundred.
##
## So the skinning is done once, on the processor, and thrown away: every vertex is moved to where
## the bones had put it, the bone and weight arrays are dropped, and what is left is a static mesh
## that costs a draw call and nothing else.
##
## The arithmetic is the standard one. A skin binds each of its own indices to a skeleton bone and a
## bind pose; a vertex is the weighted sum of itself through each of those, and the weights sum to
## one. Normals go through the same transforms without the translation, which is close enough for a
## body lying on sand and far cheaper than an inverse transpose per bone.


## The frozen mesh, or null when there is nothing to freeze — an unskinned mesh is already static
## and its caller should keep what it has.
static func freeze(source: MeshInstance3D, skeleton: Skeleton3D) -> ArrayMesh:
	if source == null or skeleton == null or source.mesh == null or source.skin == null:
		return null
	var bones := _bone_transforms(source, skeleton)
	if bones.is_empty():
		return null
	var baked := ArrayMesh.new()
	for surface: int in source.mesh.get_surface_count():
		var arrays := source.mesh.surface_get_arrays(surface)
		_move_the_vertices(arrays, bones)
		baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		baked.surface_set_material(surface, source.get_active_material(surface))
	return baked


## One transform per skin bind: where that bone has ended up, times the pose it was bound in.
static func _bone_transforms(source: MeshInstance3D, skeleton: Skeleton3D) -> Array[Transform3D]:
	var skin := source.skin
	var found: Array[Transform3D] = []
	for bind: int in skin.get_bind_count():
		var bone := skin.get_bind_bone(bind)
		if bone < 0:
			# Bound by name rather than by index, which is what a glTF importer writes.
			bone = skeleton.find_bone(skin.get_bind_name(bind))
		if bone < 0 or bone >= skeleton.get_bone_count():
			found.append(Transform3D.IDENTITY)
			continue
		found.append(skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(bind))
	return found


## Every vertex moved to where its bones had it, in place, and the bone and weight arrays dropped —
## a mesh that still carried them would be handed back to the skinning pass by whatever draws it.
static func _move_the_vertices(arrays: Array, bones: Array[Transform3D]) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	if vertices.is_empty() or indices.is_empty() or weights.is_empty():
		return
	var per_vertex := indices.size() / maxi(vertices.size(), 1)
	for vertex: int in vertices.size():
		var moved := Vector3.ZERO
		var turned := Vector3.ZERO
		var has_normal := vertex < normals.size()
		for slot: int in per_vertex:
			var at := vertex * per_vertex + slot
			var weight := weights[at]
			if weight <= 0.0:
				continue
			var bone := indices[at]
			if bone < 0 or bone >= bones.size():
				continue
			moved += bones[bone] * vertices[vertex] * weight
			if has_normal:
				turned += (bones[bone].basis * normals[vertex]) * weight
		vertices[vertex] = moved
		if has_normal:
			normals[vertex] = (
				turned.normalized() if not turned.is_zero_approx() else normals[vertex]
			)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	if not normals.is_empty():
		arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_BONES] = null
	arrays[Mesh.ARRAY_WEIGHTS] = null
