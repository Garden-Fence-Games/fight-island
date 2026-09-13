extends GdUnitTestSuite
## The clumping contract, and the gradient the grass reads.
##
## These live here rather than in `verify_island.tscn` for one blunt reason: **a headless MultiMesh
## hands back neither an AABB nor its instance transforms**, so no check that loads the built island
## can see where a single bush or tuft actually stands. `IslandFoliage` is pure arithmetic over two
## injected field queries, so it can be asked directly — and that is the only place the answer is
## readable at all.

## A flat island with a hole in the middle, standing in for the real fields. Land rises with the
## distance from the centre so "inland" has a direction; height is constant and clear of the water.
const REACH: float = 60.0
const CORE: float = 8.0
const WATERLINE: float = -1.1
const SHORE: float = 0.55
const GAP: float = 1.3
const MODEL_HEIGHT: float = 1.2435
## Where the trunks stand in these tests: a ring, far enough apart that clumps never merge.
const TRUNK_RING: float = 30.0
const TRUNKS: int = 24


func _land(x: float, z: float) -> float:
	# Nought at the rim, rising inland, so a point near the centre reads as well inland. The real
	# field is noise over a radial falloff; what matters here is only that it has a gradient.
	return clampf(1.0 - Vector2(x, z).length() / REACH, 0.0, 1.0) * 3.0


func _height(_x: float, _z: float) -> float:
	return 0.4


func _trunks() -> Array[Vector3]:
	var made: Array[Vector3] = []
	for index: int in TRUNKS:
		var angle := TAU * float(index) / float(TRUNKS)
		made.append(Vector3(cos(angle) * TRUNK_RING, 0.4, sin(angle) * TRUNK_RING))
	return made


## How many separate groups the bushes fall into, by single linkage at `reach`. Two bushes closer
## than that are the same group, and so is anything chained to either of them.
func _groups(bushes: Array[Transform3D], reach: float) -> int:
	var seen: Array[bool] = []
	for _bush: Transform3D in bushes:
		seen.append(false)
	var groups := 0
	for start: int in bushes.size():
		if seen[start]:
			continue
		groups += 1
		var queue: Array[int] = [start]
		seen[start] = true
		while not queue.is_empty():
			var here: int = queue.pop_back()
			for other: int in bushes.size():
				if seen[other]:
					continue
				if bushes[here].origin.distance_to(bushes[other].origin) <= reach:
					seen[other] = true
					queue.append(other)
	return groups


func _bushes(avoid: Array) -> Array[Transform3D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260912
	return IslandFoliage.flattened(
		IslandFoliage.bushes(
			_trunks(), avoid, rng, _land, _height, CORE, REACH, WATERLINE, SHORE, GAP
		)
	)


func test_the_bushes_form_a_few_clumps_and_not_ninety_spots() -> void:
	# The whole point of the file, stated as the thing that is actually observable from outside: the
	# bushes fall into a handful of groups. Not "every bush is near a trunk" — a third of the clumps
	# anchor in the shore band on purpose, and those are tens of metres from the nearest palm.
	var bushes := _bushes([])
	assert_int(bushes.size()).is_greater(0)
	var groups := _groups(bushes, IslandFoliage.SPREAD.y * 2.0)
	assert_int(groups).is_less_equal(IslandFoliage.TRUNK_CLUMPS + IslandFoliage.SHORE_CLUMPS)
	# And genuinely clumped rather than nominally: a hundred bushes in fifty groups is pairs.
	assert_int(groups).is_less(bushes.size() / 2)


func test_most_bushes_sit_at_the_foot_of_a_palm() -> void:
	# Sixteen of the twenty-four clumps anchor on a trunk, so most bushes should be under one. This
	# is the guard on that split: a change that quietly made every clump a shore clump would leave
	# the trunks bare, which is the arrangement the file was written to add.
	var bushes := _bushes([])
	var at_a_trunk := 0
	for bush: Transform3D in bushes:
		for trunk: Vector3 in _trunks():
			if bush.origin.distance_to(trunk) <= IslandFoliage.SPREAD.y + 0.001:
				at_a_trunk += 1
				break
	assert_int(at_a_trunk).is_greater(bushes.size() / 2)


func test_no_bush_grows_through_the_trunk_it_sits_under() -> void:
	for bush: Transform3D in _bushes([]):
		for trunk: Vector3 in _trunks():
			assert_float(bush.origin.distance_to(trunk)).is_greater_equal(
				IslandFoliage.OFF_THE_TRUNK - 0.001
			)


func test_bushes_never_stack_on_each_other() -> void:
	var bushes := _bushes([])
	for first: int in bushes.size():
		for second: int in range(first + 1, bushes.size()):
			var apart := bushes[first].origin.distance_to(bushes[second].origin)
			assert_float(apart).is_greater_equal(GAP - 0.001)


func test_the_fighting_core_stays_clear() -> void:
	for bush: Transform3D in _bushes([]):
		var from_centre := Vector2(bush.origin.x, bush.origin.z).length()
		assert_float(from_centre).is_greater_equal(CORE)


func test_a_bush_keeps_out_of_what_it_was_told_to_avoid() -> void:
	# A hut dropped on top of a clump. The bushes have to go round it, not through it — this is the
	# list the palms are deliberately absent from, so it has to work for everything that is in it.
	var hut := Vector3(TRUNK_RING, 0.4, 0.0)
	var blocked: Array = [[hut, 3.0]]
	for bush: Transform3D in _bushes(blocked):
		assert_float(bush.origin.distance_to(hut)).is_greater_equal(3.0 + GAP - 0.001)


func test_grass_grows_longer_and_thicker_away_from_the_water() -> void:
	# Both halves of the gradient in one statement, because they are one gradient: the tuft at the
	# rim is shorter than the tuft inland, and there is less of it.
	var at_the_rim := _land(REACH - 1.0, 0.0)
	var well_inland := _land(2.0, 0.0)
	assert_float(IslandFoliage.lushness(at_the_rim)).is_less(IslandFoliage.lushness(well_inland))
	assert_float(IslandFoliage.thinning(at_the_rim)).is_less(IslandFoliage.thinning(well_inland))


func test_the_shore_keeps_some_grass_rather_than_none() -> void:
	# The bug this floor exists for: the colour field already thins grass toward the sand, so a
	# gradient that also reached zero multiplied two zeroes together and left a bare ring right
	# round the island. Sparse was asked for; absent is a different island.
	assert_float(IslandFoliage.thinning(0.0)).is_greater(0.0)
	assert_float(IslandFoliage.lushness(0.0)).is_equal_approx(0.0, 0.0001)


func test_a_tuft_by_the_water_is_shorter_than_one_inland() -> void:
	# Measured over many draws rather than one, because the length is random inside a band and the
	# gradient moves the band: a single pair can come back either way round and prove nothing.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var by_the_water := 0.0
	var inland := 0.0
	for _draw: int in 200:
		by_the_water += IslandFoliage.tuft(Vector3.ZERO, 0.0, rng, MODEL_HEIGHT).basis.get_scale().y
		inland += IslandFoliage.tuft(Vector3.ZERO, 3.0, rng, MODEL_HEIGHT).basis.get_scale().y
	assert_float(by_the_water).is_less(inland)


func test_thickets_grow_inland_and_singles_by_the_water() -> void:
	# The gradient the clusters follow, over many draws: well inland the largest size is drawn far
	# more often than at the rim, and the smallest far less.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var drawn := {"rim": [0, 0, 0], "inland": [0, 0, 0]}
	for _draw: int in 2000:
		(drawn["rim"] as Array)[IslandFoliage.cluster_size(0.0, rng, 3)] += 1
		(drawn["inland"] as Array)[IslandFoliage.cluster_size(3.0, rng, 3)] += 1
	assert_int(int(drawn["inland"][2])).is_greater(int(drawn["rim"][2]) * 3)
	assert_int(int(drawn["rim"][0])).is_greater(int(drawn["inland"][0]) * 2)


func test_every_size_still_turns_up_at_both_ends() -> void:
	# Variety, stated: a gradient that zoned the island — only singles by the sea, only thickets
	# inland — would pass the test above and read as planting.
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for inland: float in [0.0, 3.0]:
		var seen := [false, false, false]
		for _draw: int in 2000:
			seen[IslandFoliage.cluster_size(inland, rng, 3)] = true
		assert_bool(seen[0] and seen[1] and seen[2]).is_true()


func test_grass_is_not_laid_on_a_grid() -> void:
	# The rhythm the grass had: a minimum spacing, saturated, spaces every cluster almost exactly
	# the same distance from its nearest neighbour. Grown rather than planted, those distances spread.
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var always := func(_x: float, _z: float) -> float: return 1.0
	var by_size := IslandFoliage.grass(
		rng, _land, _height, always, always, REACH, WATERLINE, Vector2(0.0, 3.0)
	)
	# Every cluster in one patch of ground, all sizes together: a subset drawn across the island would
	# be random whatever the scatter did.
	var spots: Array[Vector2] = []
	for placed: Transform3D in IslandFoliage.flattened(by_size):
		if absf(placed.origin.x - 30.0) < 10.0 and absf(placed.origin.z) < 10.0:
			spots.append(Vector2(placed.origin.x, placed.origin.z))
	assert_int(spots.size()).is_greater(30)
	var nearest: Array[float] = []
	for here: Vector2 in spots:
		var best := INF
		for there: Vector2 in spots:
			if there != here:
				best = minf(best, here.distance_to(there))
		nearest.append(best)
	var mean := 0.0
	for gap: float in nearest:
		mean += gap / nearest.size()
	# A minimum spacing leaves no cluster much closer to its neighbour than the typical distance.
	# Ground that grew rather than was planted has plenty: clusters leaning into each other.
	var close := 0
	for gap: float in nearest:
		if gap < mean * 0.5:
			close += 1
	# Measured: about 9 % as shipped, about 2 % with the overlap raised until clusters keep their
	# distance, whatever figure it is raised to.
	assert_float(float(close) / nearest.size()).is_greater(0.05)
