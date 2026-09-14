extends Node
## Asserts the rules the island was composed under, so a rebuild with different constants cannot
## quietly produce an arena the combat does not survive.
## Run: godot --headless --path . res://tools/verify_island.tscn

const ISLAND: String = "res://scenes/world/island.tscn"
## No single collider may be wider than this. A prop the player is stopped by from well outside the
## thing they can see is the most disorienting bug a world can have, and it is invisible by
## definition — so it is checked rather than looked for.
const WIDEST_COLLIDER: float = 4.0

## The spawn pad: flat, and clear of obstacles. Deliberately small — a large clearing in the middle
## of an island is the surest sign a world was composed rather than grown.
const SPAWN_RADIUS: float = 7.0
## Clear space between the surfaces of two blocking props. Measured as a gap rather than as a
## distance between centres, because that is the same question for a palm and for a boulder — and
## it is this, rather than a big empty circle, that stops a pair of props pinning someone inside a
## swing they cannot step out of. The player is 0.7 m across.
const MIN_GAP: float = 1.3
const FLAT_TOLERANCE: float = 0.25
## Nothing on the island may rise higher than this. The camera is fixed, so a wall anywhere is a
## wall the player can never look around.
const CEILING: float = 2.8
## What cannot block a dodge, and so cannot form a trap. Grass and shoreline pebbles collide with
## nothing; palm fronds sit four metres up; and a palm trunk is thirty centimetres of wood you walk
## past — holding those four metres apart is what made them look planted rather than grown.
## Bushes are here by decision, not by omission: they are waist-high cover the player walks straight
## through. A bush that collided would be a dodge-sized obstacle scattered ninety times across the
## arena, and the fight is the one thing on this island allowed to stop you.
const HARMLESS: PackedStringArray = ["Grass", "Pebbles", "Palms", "Bushes", "Bottles"]
## What is placed rather than scattered, and so what the generator is trusted to have put in the
## right spot. Every rule the scatter obeys is checked against these too — a hut dropped by hand
## into the spawn pad traps the player exactly as surely as a boulder scattered into it.
const PLACED: PackedStringArray = ["RockFormations", "Huts"]
## Everything that grows, and so everything the wind must reach. What is left out matters as much:
## a swaying boulder is worse than a still palm.
const FOLIAGE: PackedStringArray = ["Grass", "Palms", "Bushes"]
const STILL: PackedStringArray = ["Rocks", "Pebbles", "Bottles"]
## Every scattered population, all of which have to be splittable.
const SCATTERED: PackedStringArray = ["Grass", "Pebbles", "Palms", "Rocks", "Bushes", "Bottles"]
## How wide a chunk may be. The generator cuts on a 12 m grid and a model hangs over the edge of its
## own cell, so this is that grid with room for the widest thing standing in it — a palm, at 7.4 m
## across. Written out rather than read off the generator, which would make this agree with any grid
## anybody sets — and **the grid is what the island's cost turns on**: a chunk is the unit the
## camera keeps or drops, so a grid that crept back to 24 m would put 190,000 triangles a frame back
## without failing anything else here.
const WIDEST_CHUNK: float = 20.0
const FOLIAGE_SHADER: String = "res://assets/shaders/foliage.gdshader"
## The figures a palm's surfaces are allowed to set for themselves — how it is coloured, whether by
## a tint or by its own painted texture, and how far a leaf flexes. **Every wind figure falls
## through to the shader**, so no part of a palm bends differently from the rest of the same
## tree, which is the whole of what this list guards. Colour is not wind.
const PALM_OWN: PackedStringArray = ["tint", "albedo_texture", "flutter"]
## What a palm should measure, in metres. A wrong figure for the model's shipped height is silent:
## the island simply comes back with palms at three times the size of the fight.
const PALM_SHORTEST: float = 3.0
const PALM_TALLEST: float = 5.6
const GENERATOR: String = "res://tools/build_island.gd"
const WATER_SHADER: String = "res://assets/shaders/water.gdshader"
## The still waterline. Written out rather than read off the generator: a check that agrees with
## whatever the thing it checks happens to say is not a check.
const WATERLINE: float = -1.1
## How far above the waterline a hut has to stand. Written out rather than read off the generator,
## like the waterline above it: a hut left in the surf by a shape constant that moved is not
## something any other check on this island would notice.
const HUT_DRY_GROUND: float = 0.6
## What the camera fades, by group. Named here so the check below can ask the tree for it without
## knowing which of the island's nodes happen to be in it.
const OCCLUDER_GROUP: StringName = &"occluder"

var _failures: PackedStringArray = []


func _ready() -> void:
	var island := (load(ISLAND) as PackedScene).instantiate()
	add_child(island)
	await get_tree().physics_frame

	_check_core_is_clear(island)
	_check_core_is_flat(island)
	_check_obstacles_are_never_a_trap(island)
	_check_nothing_walls_the_camera(island)
	_check_boundary(island)
	_check_only_what_grows_moves(island)
	_check_the_palms_share_one_wind(island)
	_check_a_palm_is_still_two_colours(island)
	_check_the_palms_are_the_size_of_palms(island)
	_check_the_scatter_is_split_so_it_can_be_culled(island)
	_check_no_water_stands_inland(island)
	_check_the_sand_clears_the_swell()
	_check_the_huts_are_out_of_the_sea(island)
	_check_every_occluder_can_fade()

	if _failures.is_empty():
		print(
			(
				"island OK — clear core, no traps, flat core, nothing walls the camera, "
				+ "boundary in place, the wind reaches what grows, no water stands inland, "
				+ "the huts are on dry land, the scatter is split so it can be culled, and "
				+ "everything the camera fades can fade"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)


func _check_core_is_clear(island: Node) -> void:
	for node: Node in island.get_node("Props").get_children():
		if HARMLESS.has(String(node.name)):
			continue
		for instance: MultiMeshInstance3D in _batches(island, String(node.name)):
			# Read the buffer rather than get_instance_transform: on the dummy renderer the getter
			# returns identity for every instance, which would make this check silently pass.
			var buffer := instance.multimesh.buffer
			var stride := _stride(instance.multimesh)
			if buffer.size() != instance.multimesh.instance_count * stride:
				_failures.append("%s has no instance data" % instance.name)
				continue
			for index: int in instance.multimesh.instance_count:
				var where := Vector2(buffer[index * stride + 3], buffer[index * stride + 11])
				if where.length() < SPAWN_RADIUS:
					_failures.append(
						(
							"%s has an instance %.1f m from the centre"
							% [instance.name, where.length()]
						)
					)
					break
	for placed: String in PLACED:
		for node: Node in island.get_node(placed).get_children():
			var visual := node as MeshInstance3D
			if visual == null:
				continue
			var flat := Vector2(visual.position.x, visual.position.z)
			if flat.length() < SPAWN_RADIUS:
				_failures.append("%s has a piece %.1f m from the centre" % [placed, flat.length()])


## Read from the colliders rather than from the visuals: what can trap the player is exactly what
## the player can walk into, with its real radius, and a prop with no collider cannot trap anyone.
func _check_obstacles_are_never_a_trap(island: Node) -> void:
	var blocking: Array = []
	var bodies: Array[Node] = [island.get_node_or_null("Props/PropColliders")]
	for placed: String in PLACED:
		bodies.append(island.get_node_or_null(placed))
	for body: Node in bodies:
		if body == null:
			continue
		for node: Node in body.get_children():
			var collision := node as CollisionShape3D
			if collision == null:
				continue
			# The node's scale multiplies the shape, and missing that is how a boulder once carried a
			# twenty-five metre collider while this check read five.
			var scale := collision.global_transform.basis.get_scale()
			var spread := maxf(absf(scale.x), absf(scale.z))
			var cylinder := collision.shape as CylinderShape3D
			var box := collision.shape as BoxShape3D
			var radius := 0.0
			if cylinder != null:
				radius = cylinder.radius * spread
			elif box != null:
				radius = maxf(box.size.x, box.size.z) * 0.5 * spread
			else:
				continue
			var at := (
				collision.global_position if collision.is_inside_tree() else collision.position
			)
			if radius > WIDEST_COLLIDER:
				_failures.append(
					(
						"a collider at %s has a %.1f m radius, the most is %.1f"
						% [at, radius, WIDEST_COLLIDER]
					)
				)
				return
			blocking.append([Vector2(at.x, at.z), radius])

	for first: int in blocking.size():
		for second: int in range(first + 1, blocking.size()):
			var here: Vector2 = blocking[first][0]
			var there: Vector2 = blocking[second][0]
			var gap: float = here.distance_to(there) - blocking[first][1] - blocking[second][1]
			if gap < MIN_GAP:
				_failures.append(
					(
						"two blocking props leave a %.1f m gap at %s, the least is %.1f"
						% [gap, here, MIN_GAP]
					)
				)
				return


func _check_core_is_flat(island: Node) -> void:
	var mesh := (island.get_node("Terrain") as MeshInstance3D).mesh
	var points: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var worst := 0.0
	for point: Vector3 in points:
		if Vector2(point.x, point.z).length() > SPAWN_RADIUS:
			continue
		worst = maxf(worst, absf(point.y))
	if worst > FLAT_TOLERANCE:
		_failures.append(
			"the fighting core rises %.2f m, the most is %.2f" % [worst, FLAT_TOLERANCE]
		)


func _check_nothing_walls_the_camera(island: Node) -> void:
	var mesh := (island.get_node("Terrain") as MeshInstance3D).mesh
	var points: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var worst := 0.0
	for point: Vector3 in points:
		worst = maxf(worst, point.y)
	if worst > CEILING:
		_failures.append("the island rises %.1f m, the most is %.1f" % [worst, CEILING])


func _check_boundary(island: Node) -> void:
	var area := island.get_node_or_null("PlayableArea") as PlayableArea
	if area == null:
		_failures.append("the island has no playable area")
		return
	if area.wade_depth <= 0.0:
		_failures.append("the playable area does not let the player reach the water")


## Twelve floats of transform per instance, and four more when the instance carries an anchor.
func _stride(multi: MultiMesh) -> int:
	return 16 if multi.use_custom_data else 12


## Every batch of one population. The scatter is chunked so a camera can throw most of it away —
## see `IslandScatter` — so a population is a parent with one `MultiMeshInstance3D` per occupied
## grid cell, and a check that read only the first would be checking a corner of the island.
func _batches(island: Node, name: String) -> Array[MultiMeshInstance3D]:
	var found: Array[MultiMeshInstance3D] = []
	var population := island.get_node_or_null("Props/" + name)
	if population == null:
		return found
	for child: Node in population.get_children():
		var batch := child as MultiMeshInstance3D
		if batch != null and batch.multimesh != null:
			found.append(batch)
	return found


## The shape that lets the camera discard anything at all. A `MultiMesh` is culled as one object
## against one bounding box, so a population shipped as a single batch has a box the size of the
## island — something in it is always on screen, and **none of it is ever discarded**. That was the
## state of things at close to four million primitives a frame.
##
## Measured as the widest box rather than as a batch count, because the count is not the point: one
## population split into four strips would pass a count and cull nothing.
func _check_the_scatter_is_split_so_it_can_be_culled(island: Node) -> void:
	for name: String in SCATTERED:
		var batches := _batches(island, name)
		if batches.size() < 2:
			_failures.append("%s ships as one batch, so none of it can ever be culled" % name)
			continue
		var widest := 0.0
		for batch: MultiMeshInstance3D in batches:
			widest = maxf(widest, _footprint(batch))
		if widest > WIDEST_CHUNK:
			_failures.append(
				(
					"a chunk of %s is %.0f m across, and %.0f is the most that culls"
					% [name, widest, WIDEST_CHUNK]
				)
			)


## How far apart the instances of one batch stand, on the flat — read from the buffer rather than
## from `get_aabb()`, which the dummy renderer answers with nothing at all. A check that measured
## the bounding box here would read nought for every chunk and pass whatever the generator did,
## which is what it did until this was written.
func _footprint(batch: MultiMeshInstance3D) -> float:
	var buffer := batch.multimesh.buffer
	var stride := _stride(batch.multimesh)
	if batch.multimesh.instance_count == 0 or buffer.size() < stride:
		return 0.0
	var least := Vector2(INF, INF)
	var most := Vector2(-INF, -INF)
	for index: int in batch.multimesh.instance_count:
		var where := Vector2(buffer[index * stride + 3], buffer[index * stride + 11])
		least = least.min(where)
		most = most.max(where)
	var span := most - least
	return maxf(span.x, span.y)


## Every wind material on one population — one per surface of its model, because a MultiMesh takes
## one mesh and that mesh may be a trunk and a crown in the same breath.
func _wind_on(island: Node, name: String) -> Array[ShaderMaterial]:
	var found: Array[ShaderMaterial] = []
	var batches := _batches(island, name)
	if batches.is_empty():
		return found
	# Every chunk of a population shares one mesh and one set of materials, so the first answers for
	# all of them — but an override is per node, and one chunk overridden would be one patch of the
	# island flattened to a single colour. Checked on all of them.
	for batch: MultiMeshInstance3D in batches:
		if batch.material_override != null:
			_failures.append("%s is overridden with one material for every surface" % name)
			return found
	var instance := batches[0]
	if instance.multimesh == null or instance.multimesh.mesh == null:
		return found
	var mesh := instance.multimesh.mesh
	for surface: int in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface) as ShaderMaterial
		if material != null:
			found.append(material)
	return found


func _check_only_what_grows_moves(island: Node) -> void:
	for name: String in FOLIAGE:
		var materials := _wind_on(island, name)
		if materials.is_empty():
			_failures.append("%s does not stand in the wind" % name)
			continue
		for material: ShaderMaterial in materials:
			if material.shader == null or material.shader.resource_path != FOLIAGE_SHADER:
				_failures.append("%s sways on some other shader than the island's" % name)
				continue
			# Below one, the base of a plant travels further than its top and it tears out of the sand.
			var power: Variant = material.get_shader_parameter("bend_power")
			if power != null and float(power) < 1.0:
				_failures.append("%s bends from its base, not its top" % name)
	for name: String in STILL:
		if not _wind_on(island, name).is_empty():
			_failures.append("%s moves in the wind, and stone does not" % name)


## A palm arrives as one mesh of two parts, and every part of it must be told the same wind. Nothing
## but its colour and its leaf flex may be set per surface — there is then nothing a tuning pass can
## change on the crown without changing it on the wood underneath.
func _check_the_palms_share_one_wind(island: Node) -> void:
	for material: ShaderMaterial in _wind_on(island, "Palms"):
		if material.shader == null:
			continue
		for uniform: Dictionary in material.shader.get_shader_uniform_list():
			var parameter: String = uniform["name"]
			if PALM_OWN.has(parameter):
				continue
			if material.get_shader_parameter(parameter) != null:
				_failures.append(
					"a palm surface sets %s for itself, so one palm holds two winds" % parameter
				)


## Trunk and leaves keep their own colours. A model bought for its two-tone palm that renders in one
## flat colour has bought nothing, and nothing else here would notice.
func _check_a_palm_is_still_two_colours(island: Node) -> void:
	var materials := _wind_on(island, "Palms")
	# A painted palm answers the same question with a texture instead of with surfaces: its trunk and
	# its leaves differ because they were drawn differing, on one material. What this check is really
	# about is a palm that came out as one flat colour, and that is still caught below.
	for material: ShaderMaterial in materials:
		if material.get_shader_parameter("albedo_texture") != null:
			return
	if materials.size() < 2:
		_failures.append(
			(
				"a palm should render as trunk and leaves, has %d surfaces and no texture"
				% materials.size()
			)
		)
		return
	var colours := {}
	for material: ShaderMaterial in materials:
		colours[str(material.get_shader_parameter("tint"))] = true
	if colours.size() < 2:
		_failures.append("a palm's trunk and leaves came out the same colour")


## The models ship at about a metre and a half and are scaled to metres here. Getting that shipped
## figure wrong is silent — the island simply comes back with palms three times the size of the
## fight — so the size they end up is measured rather than trusted.
func _check_the_palms_are_the_size_of_palms(island: Node) -> void:
	var batches := _batches(island, "Palms")
	if batches.is_empty():
		_failures.append("the island has no palms")
		return
	var shortest := INF
	var tallest := 0.0
	# Every chunk, not the first: the scatter is split across a grid, and one cell is a corner of
	# the island. A palm three times the size of the fight standing anywhere else would pass.
	for instance: MultiMeshInstance3D in batches:
		# Each batch's own model, measured to its crown: a pair of palms is a different mesh from a
		# single one, and its smaller tree does not make the cluster taller.
		var model := instance.multimesh.mesh.get_aabb().end.y
		var buffer := instance.multimesh.buffer
		var stride := _stride(instance.multimesh)
		for index: int in instance.multimesh.instance_count:
			var up := Vector3(
				buffer[index * stride + 1], buffer[index * stride + 5], buffer[index * stride + 9]
			)
			var height := up.length() * model
			shortest = minf(shortest, height)
			tallest = maxf(tallest, height)
	if shortest < PALM_SHORTEST or tallest > PALM_TALLEST:
		_failures.append(
			(
				"palms come out %.1f m to %.1f m, they should be %.1f to %.1f"
				% [shortest, tallest, PALM_SHORTEST, PALM_TALLEST]
			)
		)


## No hollow anywhere on the island holds water the open sea cannot reach. Read off the terrain's
## own collision heights, so it is the island as shipped that is checked rather than a field
## recomputed here — and flooded independently of the generator, because a check that borrows the
## code it is checking only proves the code agrees with itself.
##
## A pool joined to the sea by a channel is a lagoon and is allowed. The whole question is whether
## the water joins up, which is why this floods rather than measuring a distance from the coast.
func _check_no_water_stands_inland(island: Node) -> void:
	var collision := island.get_node_or_null("TerrainBody/Collision") as CollisionShape3D
	var terrain := collision.shape as HeightMapShape3D if collision != null else null
	if terrain == null:
		_failures.append("the island has no terrain to read heights off")
		return
	var side := terrain.map_width
	var heights := terrain.map_data
	var crest := WATERLINE + _swell_height()

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
		for neighbour: int in _grid_neighbours(index, side):
			if sea[neighbour] == 1 or heights[neighbour] >= crest:
				continue
			sea[neighbour] = 1
			open.append(neighbour)

	var stranded := 0
	var worst := Vector2.ZERO
	for index: int in heights.size():
		if sea[index] == 1 or heights[index] >= crest:
			continue
		stranded += 1
		var half := float(side - 1) * 0.5
		worst = Vector2(float(index % side) - half, float(index / side) - half)
	if stranded > 0:
		_failures.append(
			"%d cells hold water the sea cannot reach, one of them at %s" % [stranded, worst]
		)


## The generator lifts drained ground to clear the swell, and the swell's height lives in the water
## shader. Two files, one number: if the shader's waves grow past what the sand was lifted by, the
## sea washes back over ground that was raised out of it and the puddles come back.
func _check_the_sand_clears_the_swell() -> void:
	var generator := load(GENERATOR) as GDScript
	if generator == null:
		_failures.append("there is no island generator to check against the water")
		return
	var constants := generator.get_script_constant_map()
	var lifted: float = constants.get("POND_CLEARANCE", 0.0)
	var assumed: float = constants.get("WAVE_CREST", 0.0)
	var actual := _swell_height()
	if assumed < actual:
		_failures.append(
			"the generator drains against a %.2f m swell, the shader makes %.2f" % [assumed, actual]
		)
	if lifted <= actual:
		_failures.append("drained sand is lifted %.2f m, under a %.2f m swell" % [lifted, actual])


## No hut stands in the surf. The huts are placed by hand against a coastline the noise decides, so
## the two drift apart silently: the first anyone hears of it is a shack up to its deck in the sea
## on a part of the island nobody framed a screenshot of.
func _check_the_huts_are_out_of_the_sea(island: Node) -> void:
	var huts := island.get_node_or_null("Huts")
	if huts == null:
		_failures.append("the island has no huts")
		return
	for node: Node in huts.get_children():
		var visual := node as MeshInstance3D
		if visual == null:
			continue
		if visual.position.y >= WATERLINE + HUT_DRY_GROUND:
			continue
		_failures.append(
			"a hut piece stands at %.1f m, the waterline is %.1f" % [visual.position.y, WATERLINE]
		)
		return


## Everything in the fade group can actually fade. `OcclusionFader` writes `faded` on a
## ShaderMaterial and skips anything else without a word, so a piece added to the group wearing a
## plain material is an occluder that never disappears — and the symptom is a player behind a solid
## prop, which is the exact bug the fader exists to prevent.
func _check_every_occluder_can_fade() -> void:
	for node: Node in get_tree().get_nodes_in_group(OCCLUDER_GROUP):
		var visual := node as MeshInstance3D
		if visual == null:
			_failures.append("a %s is in the fade group but has no mesh to fade" % node.get_class())
			return
		for surface: int in visual.mesh.get_surface_count():
			if visual.get_surface_override_material(surface) as ShaderMaterial != null:
				continue
			_failures.append("%s is in the fade group wearing a material that cannot" % visual.name)
			return


## The shader's own default, read out of its source. Its compiled defaults are not reachable from a
## headless run, and the source is the thing that ships anyway.
func _swell_height() -> float:
	var text := FileAccess.get_file_as_string(WATER_SHADER)
	var found := RegEx.create_from_string("wave_height[^=]*=\\s*([0-9.]+)").search(text)
	if found == null:
		_failures.append("the water shader no longer declares a wave height")
		return 0.0
	return found.get_string(1).to_float()


func _grid_neighbours(index: int, side: int) -> Array[int]:
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
