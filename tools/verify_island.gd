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

	if _failures.is_empty():
		print(
			"island OK — clear core, no traps, flat core, nothing walls the camera, boundary in place"
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
		if buffer.size() != instance.multimesh.instance_count * 12:
			_failures.append("%s has no instance data" % instance.name)
			continue
		for index: int in instance.multimesh.instance_count:
			var where := Vector2(buffer[index * 12 + 3], buffer[index * 12 + 11])
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
