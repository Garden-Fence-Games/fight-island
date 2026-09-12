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
## it is this, rather than a big empty circle, that stops a pair of props trapping someone against
## the reaper's 160° sweep. The player is 0.7 m across.
const MIN_GAP: float = 1.3
const FLAT_TOLERANCE: float = 0.25
## Nothing on the island may rise higher than this. The camera is fixed, so a wall anywhere is a
## wall the player can never look around.
const CEILING: float = 2.8
## What cannot block a dodge, and so cannot form a trap. Grass and shoreline pebbles collide with
## nothing; palm fronds sit four metres up; and a palm trunk is thirty centimetres of wood you walk
## past — holding those four metres apart is what made them look planted rather than grown.
const HARMLESS: PackedStringArray = ["Grass", "PalmFronds", "Pebbles", "PalmTrunks"]
## Everything that grows, and so everything the wind must reach. What is left out matters as much:
## a swaying boulder is worse than a still palm.
const FOLIAGE: PackedStringArray = ["Grass", "PalmTrunks", "PalmFronds"]
const STILL: PackedStringArray = ["Rocks", "Pebbles"]
const FOLIAGE_SHADER: String = "res://assets/shaders/foliage.gdshader"
## The two figures a palm is allowed to set for itself. Every other figure falls through to the
## shader, which is what keeps a crown swinging with the trunk under it.
const PALM_OWN: PackedStringArray = ["tint", "flutter"]
## A millimetre. Anything looser and a crown could sit off the top of its trunk by a visible amount.
const WELD_TOLERANCE: float = 0.001
const GENERATOR: String = "res://tools/build_island.gd"
const WATER_SHADER: String = "res://assets/shaders/water.gdshader"
## The still waterline. Written out rather than read off the generator: a check that agrees with
## whatever the thing it checks happens to say is not a check.
const WATERLINE: float = -1.1

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
	_check_every_crown_sits_on_its_own_trunk(island)
	_check_no_water_stands_inland(island)
	_check_the_sand_clears_the_swell()

	if _failures.is_empty():
		print(
			(
				"island OK — clear core, no traps, flat core, nothing walls the camera, "
				+ "boundary in place, the wind reaches what grows, no water stands inland"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)


func _check_core_is_clear(island: Node) -> void:
	for node: Node in island.get_node("Props").get_children():
		var instance := node as MultiMeshInstance3D
		if instance == null or HARMLESS.has(String(instance.name)):
			continue
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
					"%s has an instance %.1f m from the centre" % [instance.name, where.length()]
				)
				break
	for node: Node in island.get_node("RockFormations").get_children():
		var rock := node as MeshInstance3D
		if rock == null:
			continue
		var flat := Vector2(rock.position.x, rock.position.z)
		if flat.length() < SPAWN_RADIUS:
			_failures.append("a rock formation stands %.1f m from the centre" % flat.length())


## Read from the colliders rather than from the visuals: what can trap the player is exactly what
## the player can walk into, with its real radius, and a prop with no collider cannot trap anyone.
func _check_obstacles_are_never_a_trap(island: Node) -> void:
	var blocking: Array = []
	for body: Node in [
		island.get_node_or_null("Props/PropColliders"), island.get_node_or_null("RockFormations")
	]:
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


func _instance_at(multi: MultiMesh, index: int) -> Transform3D:
	var buffer := multi.buffer
	var base := index * _stride(multi)
	return Transform3D(
		Vector3(buffer[base + 0], buffer[base + 4], buffer[base + 8]),
		Vector3(buffer[base + 1], buffer[base + 5], buffer[base + 9]),
		Vector3(buffer[base + 2], buffer[base + 6], buffer[base + 10]),
		Vector3(buffer[base + 3], buffer[base + 7], buffer[base + 11])
	)


## Where the plant behind an instance meets the ground, reconstructed from its anchor. An instance
## with no anchor stands on its own origin.
func _ground_under(multi: MultiMesh, index: int) -> Vector3:
	var at := _instance_at(multi, index).origin
	if not multi.use_custom_data:
		return at
	var buffer := multi.buffer
	var base := index * 16
	return Vector3(at.x + buffer[base + 13], at.y - buffer[base + 12], at.z + buffer[base + 14])


func _wind_on(island: Node, name: String) -> ShaderMaterial:
	var instance := island.get_node_or_null("Props/" + name) as MultiMeshInstance3D
	if instance == null:
		return null
	return instance.material_override as ShaderMaterial


func _check_only_what_grows_moves(island: Node) -> void:
	for name: String in FOLIAGE:
		var material := _wind_on(island, name)
		if material == null or material.shader == null:
			_failures.append("%s does not stand in the wind" % name)
			continue
		if material.shader.resource_path != FOLIAGE_SHADER:
			_failures.append("%s sways on some other shader than the island's" % name)
			continue
		# Below one, the base of a plant travels further than its top and it tears out of the sand.
		var power: Variant = material.get_shader_parameter("bend_power")
		if power != null and float(power) < 1.0:
			_failures.append("%s bends from its base, not its top" % name)
	for name: String in STILL:
		if _wind_on(island, name) != null:
			_failures.append("%s moves in the wind, and stone does not" % name)


## The trunk and the crown of a palm must be told the same wind, or the crown swings further than
## the trunk it is nailed to and floats off the top of it. Neither is allowed to set a wind figure
## at all: both take the shader's, so there is nothing for a tuning pass to change on only one.
func _check_the_palms_share_one_wind(island: Node) -> void:
	for name: String in ["PalmTrunks", "PalmFronds"]:
		var material := _wind_on(island, name)
		if material == null or material.shader == null:
			continue
		for uniform: Dictionary in material.shader.get_shader_uniform_list():
			var parameter: String = uniform["name"]
			if PALM_OWN.has(parameter):
				continue
			if material.get_shader_parameter(parameter) != null:
				_failures.append(
					(
						"%s sets %s for itself, so the palms no longer share one wind"
						% [name, parameter]
					)
				)


## Every frond names the palm it belongs to, and that palm's trunk must end exactly where the frond
## begins. Both then read the same height above the ground and bend by the same amount — which is
## the whole reason a crown stays on its trunk in the wind rather than drifting off it.
func _check_every_crown_sits_on_its_own_trunk(island: Node) -> void:
	var trunks := island.get_node_or_null("Props/PalmTrunks") as MultiMeshInstance3D
	var fronds := island.get_node_or_null("Props/PalmFronds") as MultiMeshInstance3D
	if trunks == null or fronds == null:
		_failures.append("the island has no palms")
		return
	if not fronds.multimesh.use_custom_data:
		_failures.append("the fronds do not say which trunk they belong to")
		return

	var tips := {}
	for index: int in trunks.multimesh.instance_count:
		var trunk := _instance_at(trunks.multimesh, index)
		# The trunk mesh runs from its origin to one unit up, scaled by the instance.
		tips[_key(trunk.origin)] = trunk * Vector3(0.0, 1.0, 0.0)

	for index: int in fronds.multimesh.instance_count:
		var ground := _ground_under(fronds.multimesh, index)
		var key := _key(ground)
		if not tips.has(key):
			_failures.append("a frond at %s names a palm that is not planted anywhere" % ground)
			return
		var origin := _instance_at(fronds.multimesh, index).origin
		var apart: float = origin.distance_to(tips[key])
		if apart > WELD_TOLERANCE:
			_failures.append(
				"a frond hangs %.3f m off the tip of its own trunk, at %s" % [apart, ground]
			)
			return


func _key(at: Vector3) -> String:
	return "%.3f %.3f %.3f" % [at.x, at.y, at.z]


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
