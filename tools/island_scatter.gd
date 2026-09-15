class_name IslandScatter
extends RefCounted
## Scattered decoration, turned into something a camera can throw away.
##
## A `MultiMesh` is culled as one object against one bounding box. A population that spans the
## island therefore has a box that spans the island, and something in it is always on screen — so
## **none of it is ever discarded**. Twelve thousand tufts of grass were being submitted every frame
## to draw the handful actually in shot.
##
## Split across a grid, the camera keeps the cells it can see and drops the rest. The cost is a few
## dozen draw calls instead of four, which is the cheap side of that trade by a wide margin.
##
## It knows nothing about islands: transforms in, chunked batches out.

## How far into its own range a faded population takes to go. Without it a cell winks out in a
## single frame, which is far more visible than the grass ever was.
const FADE_SHARE: float = 0.25


## One population, as a parent named for it with one batch per occupied cell underneath. The mesh is
## shared between every chunk rather than copied — same geometry, same material, and duplicating it
## would multiply both.
##
## `fades_at` of nought keeps the population at every distance; anything else is where it begins to
## go. Only scatter small enough to be a few pixels should ever be given one: a silhouette that
## vanishes is a hole in the island. The same judgement decides `casts_shadow`.
static func populate(
	name: String,
	mesh: ArrayMesh,
	transforms: Array[Transform3D],
	chunk: float,
	fades_at: float = 0.0,
	casts_shadow: bool = true
) -> Node3D:
	var population := Node3D.new()
	population.name = name
	var cells := by_cell(transforms, chunk)
	for cell: Vector2i in cells:
		var batch := MultiMeshInstance3D.new()
		batch.name = "%s_%d_%d" % [name, cell.x, cell.y]
		batch.multimesh = _batch(mesh, cells[cell])
		if not casts_shadow:
			# The shadow pass draws the whole island, frustum or not, so a population that is
			# invisible in shadow is paid for twice for nothing. A tuft of grass from seventeen
			# metres up casts about a pixel.
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if fades_at > 0.0:
			batch.visibility_range_end = fades_at
			batch.visibility_range_end_margin = fades_at * FADE_SHARE
			batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		population.add_child(batch)
	return population


## One population of several models — the sizes of one cluster — as a single parent holding every
## size's batches, so the island still has one `Grass`, one `Bushes`, one `Palms`. `by_size` holds
## one transform list per mesh. With `share_materials`, every mesh after the first wears the first
## one's materials.
static func populate_family(
	name: String,
	meshes: Array[ArrayMesh],
	by_size: Array,
	chunk: float,
	fades_at: float = 0.0,
	casts_shadow: bool = true,
	share_materials: bool = true
) -> Node3D:
	var family := Node3D.new()
	family.name = name
	var worn := meshes[0]
	for size: int in meshes.size():
		var mesh := meshes[size]
		if size > 0 and share_materials:
			for surface: int in mesh.get_surface_count():
				var own := mini(surface, worn.get_surface_count() - 1)
				mesh.surface_set_material(surface, worn.surface_get_material(own))
		var label := "%s%d" % [name, size + 1]
		var population := populate(label, mesh, by_size[size], chunk, fades_at, casts_shadow)
		for batch: Node in population.get_children():
			population.remove_child(batch)
			family.add_child(batch)
		population.free()
	return family


## The transforms bucketed by the grid cell they stand in.
static func by_cell(transforms: Array[Transform3D], chunk: float) -> Dictionary:
	var cells: Dictionary = {}
	var side := maxf(chunk, 0.001)
	for placed: Transform3D in transforms:
		var at := placed.origin
		var cell := Vector2i(int(floorf(at.x / side)), int(floorf(at.z / side)))
		if not cells.has(cell):
			cells[cell] = ([] as Array[Transform3D])
		(cells[cell] as Array[Transform3D]).append(placed)
	return cells


static func _batch(mesh: ArrayMesh, transforms: Array[Transform3D]) -> MultiMesh:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	# The buffer is written directly rather than through set_instance_transform: headless runs on a
	# dummy renderer, where the setter writes to a server that discards it and the buffer saves
	# empty.
	multi.buffer = _pack(transforms)
	return multi


## Twelve floats per instance: the three rows of the 3x4 transform, origin last on each row.
static func _pack(transforms: Array[Transform3D]) -> PackedFloat32Array:
	var stride := 12
	var data := PackedFloat32Array()
	data.resize(transforms.size() * stride)
	for index: int in transforms.size():
		var at := transforms[index]
		var basis := at.basis
		var origin := at.origin
		var base := index * stride
		data[base + 0] = basis.x.x
		data[base + 1] = basis.y.x
		data[base + 2] = basis.z.x
		data[base + 3] = origin.x
		data[base + 4] = basis.x.y
		data[base + 5] = basis.y.y
		data[base + 6] = basis.z.y
		data[base + 7] = origin.y
		data[base + 8] = basis.x.z
		data[base + 9] = basis.y.z
		data[base + 10] = basis.z.z
		data[base + 11] = origin.z
	return data
