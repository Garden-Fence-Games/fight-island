extends Node
## Proof that a coconut comes out of a real tree, is worth what the table says, and does not linger.
##
## **The grove is the half worth checking hardest.** The palms are baked into `MultiMesh` batches,
## and the accessor for reading an instance back — `get_instance_transform` — answers with the
## identity matrix under the headless renderer. A check written against it would find three hundred
## and eighty palms standing in a neat pile at the origin and pass, because every coconut would fall
## somewhere and every assertion about "near its own tree" would be trivially true. So what is
## asserted is that the palms are **spread out and off the origin**, which is the thing that goes
## silently wrong.
## Run: godot --headless --path . res://tools/verify_coconut.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
## What the island scatters. A handful either way is fine; an order of magnitude is a grove that was
## not read — which is the only thing this is for, so it sits well under the ninety-five the island
## actually lays down rather than beside it.
const PALMS_AT_LEAST: int = 40
## How far apart the two furthest palms have to be before the grove counts as a grove rather than a
## pile at the origin. The island is eighty-eight metres across.
const GROVE_SPANS: float = 20.0
## How far a coconut may land from the foot of its own palm, over what the table allows. The landing
## spot is snapped to walkable ground, which can move it a little further out than `lands_within`.
const SNAP_SLACK: float = 2.0
## Frames given to a fall before it is called stuck, at a fall of well under a second.
const FALL_FRAMES: int = 120
## Damage dealt before the heal is measured, chosen so a full coconut fits inside it and the clamp
## is not what is being tested here.
const HURT_BY: float = 60.0
## How long the navigation map gets to come up. Every landing spot is snapped to walkable ground, so
## a coconut dropped before the map answers is not a coconut that failed to fall — it is a check
## that ran too early.
const MAP_SYNC_FRAMES: int = 240

var _failures: PackedStringArray = []
var _arena: Node3D = null
var _director: CoconutDirector = null
var _player: Node3D = null
var _health: HealthComponent = null


func _ready() -> void:
	_run()


func _run() -> void:
	await _open_the_island()
	if _director == null or _health == null:
		_report()
		return
	_check_the_grove_is_a_grove()
	_check_the_table_is_read()
	await _check_one_falls_by_its_own_palm()
	await _check_it_heals_by_what_the_table_says()
	await _check_it_cannot_overfill()
	await _check_it_does_not_lie_there_for_ever()
	_report()


func _open_the_island() -> void:
	_arena = (load(ARENA) as PackedScene).instantiate() as Node3D
	add_child(_arena)
	# The wave director would start sending enemies, and a check about coconuts should not be
	# measuring a fight it did not ask for.
	var waves := _arena.get_node_or_null("WaveDirector") as WaveDirector
	if waves != null:
		waves.halt()
		waves.process_mode = Node.PROCESS_MODE_DISABLED
	var tutorial := _arena.get_node_or_null("TutorialDirector")
	if tutorial != null:
		tutorial.process_mode = Node.PROCESS_MODE_DISABLED
	await _wait_for_the_map()
	_director = _arena.get_node_or_null("CoconutDirector") as CoconutDirector
	_player = _arena.get_node_or_null("Player") as Node3D
	if _director == null:
		_fail("the arena has no CoconutDirector — nothing drops coconuts")
		return
	if _player == null:
		_fail("the arena has no Player to heal")
		return
	_health = _player.get("health") as HealthComponent
	if _health == null:
		_fail("the player has no HealthComponent — a coconut has nothing to give back to")


## The navigation server builds its map on a physics step, and `Ground.closest_point` fails loudly
## before the first iteration. Waiting on the iteration id is the documented way to know it is
## ready; counting frames is a guess that holds until the island gets bigger.
func _wait_for_the_map() -> void:
	var map := _arena.get_world_3d().navigation_map
	for _attempt: int in MAP_SYNC_FRAMES:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(map) == 0:
			continue
		if not (
			NavigationServer3D
			. map_get_path(map, Vector3.ZERO, Vector3(4.0, 0.0, 4.0), false)
			. is_empty()
		):
			return
	_fail("the navigation map never answered a path query")


## **The grove was read, and it was read from the buffer rather than from the renderer.** Both
## halves fail the same way if the accessor is ever reached for again: a full count of palms, all
## identical, all at the origin.
func _check_the_grove_is_a_grove() -> void:
	if _director.grove_size() < PALMS_AT_LEAST:
		_fail(
			"the grove came back with %d palms — the scatter was not read" % _director.grove_size()
		)
		return
	var palms := PalmGrove.every(_arena)
	var lowest := Vector3.INF
	var highest := -Vector3.INF
	for palm: Transform3D in palms:
		lowest = lowest.min(palm.origin)
		highest = highest.max(palm.origin)
	var spread := highest - lowest
	if maxf(spread.x, spread.z) < GROVE_SPANS:
		_fail(
			(
				(
					"%d palms span only %.1f m — they are stacked, which is what a renderer that "
					+ "refuses to answer looks like"
				)
				% [palms.size(), maxf(spread.x, spread.z)]
			)
		)


## The numbers come off the resource rather than out of the script, and the two curves behave the
## way the design says: the ceiling climbs, and it climbs slowly.
func _check_the_table_is_read() -> void:
	var data := _director.data
	if data == null:
		_fail("the director has no CoconutData — every number would be a default in a script")
		return
	if data.at_once(1) > data.at_once(15):
		_fail("the ceiling falls over a run — it is meant to rise")
	if data.at_once(1) >= data.owed(60):
		_fail(
			(
				(
					"the ceiling at wave 1 is %d and a sixty-body wave is owed %d — a ceiling that is "
					+ "never below the supply brakes nothing"
				)
				% [data.at_once(1), data.owed(60)]
			)
		)
	if data.heals <= 0.0:
		_fail("a coconut heals %.1f — it is not worth walking to" % data.heals)


func _check_one_falls_by_its_own_palm() -> void:
	var coconut := await _a_landed_coconut()
	if coconut == null:
		return
	# **Its own palm, not the nearest one.** The island carries three hundred and eighty of them, so
	# wherever a coconut lands something is a metre or two away and a check against the nearest palm
	# passes for any landing spot at all — including one picked next to the player. This assertion
	# was written that way first and a mutant that dropped coconuts at the player's feet walked
	# straight through it.
	var away := coconut.fell_from - coconut.global_position
	away.y = 0.0
	var allowed := _director.data.lands_within + SNAP_SLACK
	if away.length() > allowed:
		_fail(
			(
				(
					"a coconut landed %.1f m from the palm it fell out of, and the table allows "
					+ "%.1f — it did not come out of that tree"
				)
				% [away.length(), allowed]
			)
		)
	coconut.queue_free()
	await get_tree().physics_frame


func _check_it_heals_by_what_the_table_says() -> void:
	var coconut := await _a_landed_coconut()
	if coconut == null:
		return
	_hurt(HURT_BY)
	var before := _health.current_health
	var taken := await _walk_onto(coconut)
	if not taken:
		_fail("the player stood on a coconut and it was not taken")
		return
	var given := _health.current_health - before
	if not is_equal_approx(given, _director.data.heals):
		_fail("a coconut gave back %.1f and the table says %.1f" % [given, _director.data.heals])


## The clamp, which is the one rule that keeps this from being a quieter Health track: at full
## health the coconut is left where it is rather than spent for nothing.
func _check_it_cannot_overfill() -> void:
	var coconut := await _a_landed_coconut()
	if coconut == null:
		return
	_health.heal(_health.max_health)
	var taken := await _walk_onto(coconut)
	if taken:
		_fail("a coconut was taken at full health — it was spent for nothing")
	if _health.current_health > _health.max_health:
		_fail("the player is on %.1f of %.1f health" % [_health.current_health, _health.max_health])
	if is_instance_valid(coconut):
		coconut.queue_free()
		await get_tree().physics_frame


## It rots. A wave that could bank its supply for the next one is a ceiling that means nothing, and
## the only thing standing between those two is this.
func _check_it_does_not_lie_there_for_ever() -> void:
	var coconut := await _a_landed_coconut()
	if coconut == null:
		return
	# Walked forward rather than waited out: `lies_for` is twenty seconds and a check should not be.
	var lies_for := _director.data.lies_for
	var step := 1.0 / Engine.physics_ticks_per_second
	var frames := int(lies_for / step) + 4
	for _frame: int in frames:
		if not is_instance_valid(coconut) or coconut.is_queued_for_deletion():
			return
		coconut._physics_process(step)
	_fail("a coconut was still lying there after %.0f s, which is its whole life" % lies_for)


func _a_landed_coconut() -> Coconut:
	var coconut := _director.drop()
	if coconut == null:
		_fail("the director could not drop a coconut at all")
		return null
	for _frame: int in FALL_FRAMES:
		await get_tree().physics_frame
		if coconut.monitoring:
			return coconut
	_fail("a coconut never finished falling")
	return null


## The player put on top of it, and physics given a chance to notice. Returns whether it was taken.
func _walk_onto(coconut: Coconut) -> bool:
	var where := coconut.global_position
	_player.global_position = Vector3(where.x, _player.global_position.y, where.z)
	for _frame: int in 12:
		await get_tree().physics_frame
		if not is_instance_valid(coconut) or coconut.is_queued_for_deletion():
			return true
	return false


func _hurt(amount: float) -> void:
	var info := HitInfo.new()
	info.damage = amount
	_health.apply(info)


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				"coconut OK — the grove is read from the buffer and spread over the island, one "
				+ "falls by the foot of its own palm, it gives back what the table says, it is "
				+ "left alone at full health, and it rots"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
