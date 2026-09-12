extends RefCounted
## Which hollows in a height grid the sea can actually reach.
##
## Split out of the island generator because it is the one piece of it that knows nothing about
## islands: it takes a grid of heights and a waterline and answers a question about connectivity.


## How much to raise each cell of `heights` so that no water stands anywhere the sea cannot reach.
## Zero almost everywhere. The caller applies it, and keeps it, because everything placed on the
## island has to be able to ask how high the ground is after the drain.
##
## `crest` is the top of the swell — the height under which ground is ground the sea can cover.
## `target` is where a drained floor is put, just above it.
static func drain(
	heights: PackedFloat32Array, side: int, crest: float, target: float
) -> PackedFloat32Array:
	var sea := _sea_from_the_border(heights, side, crest)
	var lift := PackedFloat32Array()
	lift.resize(heights.size())
	for index: int in heights.size():
		if sea[index] == 1 or heights[index] >= crest:
			lift[index] = 0.0
			continue
		lift[index] = target - heights[index]
	return lift


static func drained_count(lift: PackedFloat32Array) -> int:
	var count := 0
	for amount: float in lift:
		if amount > 0.0:
			count += 1
	return count


## Flooded inward from the edge of the grid, which is open ocean on every side. What the flood does
## not reach is a hollow with no way out to the sea — a puddle. A pool joined to the open water by a
## channel is a lagoon, and it survives, which is the distinction a test on distance cannot make.
static func _sea_from_the_border(
	heights: PackedFloat32Array, side: int, crest: float
) -> PackedByteArray:
	var sea := PackedByteArray()
	sea.resize(heights.size())
	var open: Array[int] = []
	for index: int in heights.size():
		var row := index / side
		var column := index % side
		var edge := row == 0 or column == 0 or row == side - 1 or column == side - 1
		if edge and heights[index] < crest:
			sea[index] = 1
			open.append(index)

	var head := 0
	while head < open.size():
		var index: int = open[head]
		head += 1
		for neighbour: int in _neighbours(index, side):
			if sea[neighbour] == 1 or heights[neighbour] >= crest:
				continue
			sea[neighbour] = 1
			open.append(neighbour)
	return sea


static func _neighbours(index: int, side: int) -> Array[int]:
	var row := index / side
	var column := index % side
	var found: Array[int] = []
	if row > 0:
		found.append(index - side)
	if row < side - 1:
		found.append(index + side)
	if column > 0:
		found.append(index - 1)
	if column < side - 1:
		found.append(index + 1)
	return found


## The lift at a point, by nearest cell. A drained hollow is flat across its floor and the lift
## falls to nothing at its rim, so there is nothing between two cells for an interpolation to find.
static func lift_at(
	lift: PackedFloat32Array, side: int, spacing: float, x: float, z: float
) -> float:
	if lift.is_empty():
		return 0.0
	var half := float(side - 1) * 0.5 * spacing
	var column := int(roundf((x + half) / spacing))
	var row := int(roundf((z + half) / spacing))
	if row < 0 or column < 0 or row >= side or column >= side:
		return 0.0
	return lift[row * side + column]
