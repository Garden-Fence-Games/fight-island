class_name PalmGrove
extends Object
## Where the palms are, read back out of the batches they were packed into.
##
## **The transforms were never lost.** The island's scatter is baked into the scene as `MultiMesh`
## batches — three hundred and eighty palms in ninety-nine of them — and the obvious reading of that
## is that the trees stopped being things and became a buffer, so anything wanting to know where a
## tree stands would have to be handed a second list kept beside it.
##
## It does not. The buffer **is** the list: twelve floats an instance, written by
## `IslandScatter._pack`, and still there at runtime. Nothing has to change about how the island is
## built for a coconut to fall out of a specific tree.
##
## **Read out of `buffer` rather than through `get_instance_transform`.** The accessor goes to the
## rendering server, and under the headless dummy renderer it answers with the identity matrix for
## every instance — three hundred and eighty palms all standing at the origin, which is a check that
## passes for the wrong reason rather than a check that fails. The property is the stored data and
## reads the same everywhere. `IslandScatter` writes the buffer directly for the mirror image of
## this reason, and says so.

## Where the scatter puts them, from the arena.
const PALMS_AT: NodePath = ^"Island/Props/Palms"
## Twelve floats an instance: three rows of a 3x4, each ending in its own origin component.
const STRIDE: int = 12
## How tall a palm's crown sits above its own foot, at unit scale. The model is about this, and what
## it is for is the height a coconut starts falling from — a figure a metre out reads as a coconut
## appearing out of the air above the tree rather than leaving it.
const CROWN_HEIGHT: float = 5.4


## Every palm on the island, in world space, scale included. Empty when the island has no scatter —
## which is a menu, or a test scene, and is not an error.
static func every(arena: Node) -> Array[Transform3D]:
	var found: Array[Transform3D] = []
	var palms := arena.get_node_or_null(PALMS_AT) as Node3D
	if palms == null:
		return found
	for child: Node in palms.get_children():
		var batch := child as MultiMeshInstance3D
		if batch == null or batch.multimesh == null:
			continue
		var raw := batch.multimesh.buffer
		for index: int in batch.multimesh.instance_count:
			var at := index * STRIDE
			if at + STRIDE > raw.size():
				break
			found.append(batch.global_transform * _unpack(raw, at))
	return found


## Where a coconut leaves this palm: the middle of its crown, at the tree's own scale. A palm that
## was scattered small carries its crown lower, and a fixed height would have the small ones
## dropping fruit out of thin air above themselves.
static func crown_of(palm: Transform3D) -> Vector3:
	return palm.origin + Vector3.UP * CROWN_HEIGHT * palm.basis.get_scale().y


static func _unpack(raw: PackedFloat32Array, at: int) -> Transform3D:
	return Transform3D(
		Vector3(raw[at + 0], raw[at + 4], raw[at + 8]),
		Vector3(raw[at + 1], raw[at + 5], raw[at + 9]),
		Vector3(raw[at + 2], raw[at + 6], raw[at + 10]),
		Vector3(raw[at + 3], raw[at + 7], raw[at + 11])
	)
