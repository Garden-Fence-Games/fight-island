extends Node
## What the fixed camera actually shows of the ground, and what is allowed to live where it does
## not.
##
## The camera cannot be turned, so the island is composed for one viewpoint (issue #39). That buys
## a lot and costs one thing: there is a **blind side**, and nothing the player has to find may sit
## in it. This measures where it is instead of asserting where it ought to be, then holds the one
## rule that depends on the answer — a weapon lying in the grass must be in shot.
##
## The spawn rule is the mirror image and is not re-checked here: `verify_waves` already proves a
## body never fades in inside the frame, and `SpawnDirector.MIN_PLAYER_DISTANCE` keeps one twelve
## metres away whatever the view does.
## Run: godot --headless --path . res://tools/verify_view.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
## Bearings sampled around the player. Ten degrees apart: finer than the blind wedge is wide, so it
## cannot be stepped over.
const BEARINGS: int = 36
## How far out the march looks, and in what steps. Past thirty metres nothing is readable anyway,
## and a quarter of a metre is a tenth of a body.
const HORIZON: float = 30.0
const MARCH: float = 0.25
## A body is taller than the ground it stands on and the camera looks down, so the ground being out
## of shot and the thing standing on it being out of shot are different questions. The pickup is
## the low one: its prompt floats at 1.3 m but the weapon itself lies in the grass.
const PICKUP_HEIGHT: float = 0.3
## Where the player is put for the sweep: the flat middle, clear of the rock formations, so the
## footprint measured is the camera's and not one boulder's shadow.
const CENTRE: Vector3 = Vector3(0.0, 0.0, 0.0)
## How many drops are rolled, and from how many places. Every one of them must land in shot: the
## fallback in `PickupDirector` exists so a weapon is never lost outright, and a weapon that is
## merely invisible is the failure it quietly trades down to.
const PLACES: int = 24
const DROPS_EACH: int = 8
## How far the player is moved around the island between drops.
const WANDER: float = 34.0
## How close the spring arm has to be to the distance it was wound to before it counts as settled.
const SETTLED: float = 0.1

var _failures: PackedStringArray = []
var _arena: Node3D = null
var _player: Player = null
var _camera: Camera3D = null
var _reach: PackedFloat32Array = []


func _ready() -> void:
	_run()


func _run() -> void:
	_arena = (load(ARENA) as PackedScene).instantiate() as Node3D
	add_child(_arena)
	_stand_the_tutorial_down(_arena)
	var director := _arena.get_node_or_null(^"WaveDirector") as WaveDirector
	if director != null:
		director.halt()
	_player = _arena.get_node_or_null(^"Player") as Player
	if _player == null:
		_fail("the arena has no player")
		_report()
		return
	_player.global_position = Ground.closest_point(_player.get_world_3d(), CENTRE)
	await _advance(0.6)
	_camera = get_viewport().get_camera_3d()
	if _camera == null:
		_fail("the arena has no camera")
		_report()
		return

	_measure_the_footprint()
	_report_the_blind_side("at rest")
	_check_the_pickup_ring_is_mostly_in_shot()
	await _check_every_weapon_lands_where_it_can_be_seen()
	await _check_the_swing_is_readable_at_every_zoom_the_wheel_reaches()
	_report()


## How far the ground stays in frame on each bearing, from the player outward. The first step that
## leaves the frame ends that bearing: a gap further out is a gap behind a boulder, not more view.
func _measure_the_footprint() -> void:
	_reach = PackedFloat32Array()
	_reach.resize(BEARINGS)
	var here := _player.global_position
	for index: int in BEARINGS:
		var angle := TAU * float(index) / float(BEARINGS)
		var step := Vector3(cos(angle), 0.0, sin(angle))
		var last := 0.0
		var distance := MARCH
		while distance <= HORIZON:
			if not _camera.is_position_in_frustum(
				here + step * distance + Vector3.UP * PICKUP_HEIGHT
			):
				break
			last = distance
			distance += MARCH
		_reach[index] = last


## The measurement, printed whether or not anything failed — this is the answer to "where is the
## blind side", and a number nobody prints is a number nobody checks against the next camera change.
func _report_the_blind_side(when: String) -> float:
	var shortest := HORIZON
	var longest := 0.0
	var blind := 0
	for index: int in BEARINGS:
		if _reach[index] < shortest:
			shortest = _reach[index]
			blind = index
		longest = maxf(longest, _reach[index])
	var bearing := 360.0 * float(blind) / float(BEARINGS)
	var line := "view %s — the ground stays in shot %.1f m at its shortest (bearing %.0f°, the "
	print((line + "blind side) and %.1f m at its longest") % [when, shortest, bearing, longest])
	return shortest


## The bound has to hold at the **closest** the wheel reaches, not at the distance the camera opens
## on. Zoom is the player's to spend, and a setting that puts the first frame of a swing off-screen
## is not a choice offered to them, it is a trap laid for them.
##
## The wheel is turned rather than the rig's own field written to: what is under test is what a
## player can actually select, and writing the field would let the check reach a distance the wheel
## clamps away from.
func _check_the_swing_is_readable_at_every_zoom_the_wheel_reaches() -> void:
	var rig := _arena.get_node_or_null(^"CameraRig") as CameraRig
	if rig == null:
		_fail("the arena has no camera rig")
		return
	var turns := int(ceilf((CameraRig.MAX_ZOOM - CameraRig.MIN_ZOOM) / CameraRig.ZOOM_STEP)) + 2
	for _turn: int in turns:
		var wheel := InputEventAction.new()
		wheel.action = &"camera_zoom_in"
		wheel.pressed = true
		Input.parse_input_event(wheel)
		await get_tree().process_frame
	await _advance(1.5)
	var arm := rig.spring.spring_length
	if absf(arm - CameraRig.MIN_ZOOM) > SETTLED:
		_fail(
			(
				"%d turns of the wheel left the arm at %.2f m rather than the %.2f m it clamps to"
				% [turns, arm, CameraRig.MIN_ZOOM]
			)
		)
		return
	_measure_the_footprint()
	var shortest := _report_the_blind_side("wound all the way in")
	var needed := _the_ground_a_swing_needs()
	if shortest < needed:
		_fail(
			(
				(
					"wound all the way in, the blind side shows %.1f m and a melee archetype needs "
					+ "%.1f m — his swing would begin off-screen"
				)
				% [shortest, needed]
			)
		)


## The ground a melee archetype has to be visible on for its telegraph to be readable: the range it
## strikes from, plus what it covers while winding up. Read off the `.tres` files rather than
## written down here, so a rebalance moves the bound with it instead of leaving it stale.
##
## The thrower is left out on purpose. He strikes from fourteen metres and answering him is the
## open half of issue #39 — a bound that quietly folded him in would be inventing the threshold
## that issue says nobody has earned yet.
func _the_ground_a_swing_needs() -> float:
	var needed := 0.0
	for data: EnemyData in _archetypes():
		if data.is_ranged or data.attack == null:
			continue
		needed = maxf(needed, data.attack_range + data.move_speed * data.attack.windup)
	if needed <= 0.0:
		_fail("no melee archetype offered a range and a wind-up to take the bound from")
	return needed


func _archetypes() -> Array[EnemyData]:
	var found: Array[EnemyData] = []
	for file_name: String in DirAccess.get_files_at("res://data/enemies"):
		var data := load("res://data/enemies/%s" % file_name.trim_suffix(".remap")) as EnemyData
		if data != null:
			found.append(data)
	return found


## The ring a weapon is dropped on has to be mostly visible, or `PickupDirector` is spending its
## forty-eight tries on ground the player cannot see and falling back far more often than the
## comment beside that fallback suggests.
func _check_the_pickup_ring_is_mostly_in_shot() -> void:
	var seen := 0
	var total := 0
	var here := _player.global_position
	for index: int in BEARINGS:
		var angle := TAU * float(index) / float(BEARINGS)
		var step := Vector3(cos(angle), 0.0, sin(angle))
		var distance := PickupDirector.NEAREST
		while distance <= PickupDirector.FURTHEST:
			total += 1
			if _camera.is_position_in_frustum(here + step * distance + Vector3.UP * PICKUP_HEIGHT):
				seen += 1
			distance += 1.0
	var share := 100.0 * float(seen) / maxf(float(total), 1.0)
	print("view — %.0f%% of the ring a weapon drops on is in shot" % share)
	if share < 25.0:
		_fail(
			(
				"only %.0f%% of the pickup ring is in shot — the drop is a coin toss, not a rule"
				% share
			)
		)


## The rule itself, rolled rather than reasoned about: drop a weapon again and again, from all over
## the island, and look at where it actually landed.
func _check_every_weapon_lands_where_it_can_be_seen() -> void:
	var director := _arena.get_node_or_null(^"PickupDirector") as PickupDirector
	if director == null:
		_fail("the arena has no pickup director")
		return
	var stick := Arsenal.find(&"stick")
	if stick == null:
		_fail("there is no stick to drop")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var world := _player.get_world_3d()
	var dropped := 0
	var unseen := 0
	var worst := Vector3.ZERO
	for _place: int in PLACES:
		var angle := rng.randf_range(0.0, TAU)
		var reach := rng.randf_range(0.0, WANDER)
		var stand := Ground.closest_point(world, Vector3(cos(angle), 0.0, sin(angle)) * reach)
		if stand == Vector3.INF:
			continue
		_player.global_position = stand
		await _advance(0.35)
		for _roll: int in DROPS_EACH:
			# The bag is what refuses a second stick, and this check wants a great many of them.
			GameState.loadout.found.clear()
			var pickup := director.drop(stick)
			if pickup == null:
				continue
			dropped += 1
			if not _camera.is_position_in_frustum(
				pickup.global_position + Vector3.UP * PICKUP_HEIGHT
			):
				unseen += 1
				worst = pickup.global_position
			pickup.queue_free()
	if dropped == 0:
		_fail("not one weapon was dropped, so nothing about where they land was tested")
		return
	print("view — %d weapons dropped, %d of them out of shot" % [dropped, unseen])
	if unseen > 0:
		_fail(
			(
				(
					"%d of %d weapons landed out of shot, the last at %s — a weapon the player has no "
					+ "reason to walk towards is a weapon they do not get"
				)
				% [unseen, dropped, worst]
			)
		)


func _advance(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().process_frame
		elapsed += 1.0 / 60.0


func _stand_the_tutorial_down(arena: Node) -> void:
	var tutorial := arena.get_node_or_null(^"TutorialDirector") as TutorialDirector
	if tutorial != null:
		tutorial.stand_down()


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print("view OK — the blind side is measured and no weapon is dropped into it")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
