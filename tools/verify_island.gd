extends Node
## Asserts the rules the island was composed under, so a rebuild with different constants cannot
## quietly produce an arena the combat does not survive.
## Run: godot --headless --path . res://tools/verify_island.tscn

const ISLAND: String = "res://scenes/world/island.tscn"
## Nothing may stand inside this radius. A prop in the fighting core is a prop the reaper's 160°
## sweep will eventually trap someone against.
const CLEAR_RADIUS: float = 22.0
const FLAT_TOLERANCE: float = 0.25
## Nothing on the island may rise higher than this. The camera is fixed, so a wall anywhere is a
## wall the player can never look around.
const CEILING: float = 2.8
## Only what stands at body height counts as an obstacle. Grass collides with nothing and palm
## fronds sit four metres up, so neither can block a dodge.
const HARMLESS: PackedStringArray = ["Grass", "PalmFronds"]

var _failures: PackedStringArray = []


func _ready() -> void:
	var island := (load(ISLAND) as PackedScene).instantiate()
	add_child(island)
	await get_tree().physics_frame

	_check_core_is_clear(island)
	_check_core_is_flat(island)
	_check_nothing_walls_the_camera(island)
	_check_boundary(island)

	if _failures.is_empty():
		print("island OK — clear core, flat core, nothing walls the camera, boundary in place")
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
			if where.length() < CLEAR_RADIUS:
				_failures.append(
					"%s has an instance %.1f m from the centre" % [instance.name, where.length()]
				)
				break
	for node: Node in island.get_node("RockFormations").get_children():
		var rock := node as MeshInstance3D
		if rock == null:
			continue
		var flat := Vector2(rock.position.x, rock.position.z)
		if flat.length() < CLEAR_RADIUS:
			_failures.append("a rock formation stands %.1f m from the centre" % flat.length())


func _check_core_is_flat(island: Node) -> void:
	var mesh := (island.get_node("Terrain") as MeshInstance3D).mesh
	var points: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var worst := 0.0
	for point: Vector3 in points:
		if Vector2(point.x, point.z).length() > CLEAR_RADIUS:
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
