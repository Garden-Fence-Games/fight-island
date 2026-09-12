extends Node
## Headless proof of the **thrower test** from #39: that a ranged enemy is a real threat on this
## island, and that closing on one is possible.
##
## The camera is fixed, so the island is composed for one viewpoint and every composition rule has
## to be checked rather than eyeballed from an angle nobody plays at. `verify_playfield` walks the
## reaper's half of that — no corner where a 160° sweep is unanswerable. This is the thrower's half,
## and it is two failures rather than one, in opposite directions:
##
## - **An island with no open ground** makes the thrower decoration. He stands at ten metres, throws
##   into a boulder every time, and the archetype that is supposed to make the player move never
##   asks them to.
## - **An island with no cover at all** makes him a tax. There is no way to break his line while
##   closing the ten metres, so the stone is something the player eats rather than something they
##   answer — and the design's own promise is that a stone can be *seen coming* and dealt with.
##
## So the assertion is a band, not a floor. Both ends are failures and the island has to sit between
## them.
##
## **It casts the ray the stone actually flies.** Not a navigation query and not the walkability
## grid `verify_playfield` rasterises: the stone is an `Area3D` on mask 33, so what stops it is
## the `world` layer at the height it travels — chest to chest, flat, which is why a wreck a metre
## high is cover and a walkable dip is not. Asking the physics server the same question the stone
## asks is the only way this cannot drift from it.
## Run: godot --headless --path . res://tools/verify_sightlines.tscn

const ISLAND: String = "res://scenes/world/island.tscn"
const THROWER: String = "res://data/enemies/thrower.tres"
## Where a stone leaves the hand and what it is aimed at, both written out rather than read off
## `Enemy` — a check that agrees with whatever it is checking is not a check. They are asserted
## against the shipped constants below, so a retune cannot leave this testing a trajectory the
## thrower no longer throws.
const THROW_HEIGHT: float = 1.1
const CHEST_HEIGHT: float = 1.0
## The still waterline, and how deep the navigation mesh follows the player in. The fight happens
## where a thrower can stand, and out past this he does not come — the same reason
## `verify_playfield` stops there rather than walking every sandbank the player can paddle to.
const WATERLINE: float = -1.1
const FIGHT_DEPTH: float = 0.5
## How far out the fighting ground is sampled, and how coarsely. The island runs to 88 m; a fight
## happens where the waves put bodies, which is within a couple of dozen metres of the player.
const REACH: float = 40.0
const STEP: float = 2.0
## Bearings tried from each stance. Ten degrees apart, so a formation that blocks one approach is
## never mistaken for one that blocks the island.
const BEARINGS: int = 36
## Headroom a stance needs before it counts as somewhere a body stands. A point inside a boulder is
## not a place the fight happens, and counting it would make the island look like solid cover.
const STANDING_ROOM: float = 1.4

## The band. **The shipped island measures 79.3% clear and 20.7% blocked**, over sixty thousand
## lines from sixteen hundred stances, and both floors were written down before that was run — a
## bound fitted to the number it is supposed to judge is not a bound. They are kept well clear of
## the reading so a scatter reseed can move the island without moving the design, and close enough
## that losing a third of the cover or a third of the open ground is still caught.
##
## Proven to respond to the world rather than to arithmetic: flown at ankle height the same walk
## reports 39.3% clear and trips the threat floor, flown above everything it reports 100% clear and
## trips the cover floor.
const THREAT_FLOOR: float = 0.55
const COVER_FLOOR: float = 0.05

var _failures: PackedStringArray = []
var _space: PhysicsDirectSpaceState3D = null


func _ready() -> void:
	_run()


func _run() -> void:
	var island := (load(ISLAND) as PackedScene).instantiate() as Node3D
	add_child(island)
	# Two frames: one for the bodies to enter the tree, one for the server to have them.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_space = island.get_world_3d().direct_space_state

	_check_the_trajectory_is_the_one_the_thrower_throws()
	_check_the_thrower_can_see_you_and_you_can_break_his_line()
	_report()


## The heights above are the whole measurement, so they are held to the body that throws. A stone
## that starts travelling at head height would be a different question entirely and this check would
## keep answering the old one.
func _check_the_trajectory_is_the_one_the_thrower_throws() -> void:
	if not is_equal_approx(THROW_HEIGHT, Enemy.THROW_HEIGHT):
		_fail(
			(
				"a stone leaves the hand at %.2f m and this measures %.2f"
				% [Enemy.THROW_HEIGHT, THROW_HEIGHT]
			)
		)
	if not is_equal_approx(CHEST_HEIGHT, Enemy.CHEST_HEIGHT):
		_fail(
			"a stone is aimed at %.2f m and this measures %.2f" % [Enemy.CHEST_HEIGHT, CHEST_HEIGHT]
		)


## The walk. Every stance a fight can happen on, against a thrower standing where he prefers to
## stand, on thirty-six bearings.
func _check_the_thrower_can_see_you_and_you_can_break_his_line() -> void:
	var data := load(THROWER) as EnemyData
	if data == null:
		_fail("there is no thrower to place")
		return
	var stances := _fighting_ground()
	if stances.size() < 200:
		_fail("only %d places to stand were found — the sampling is broken" % stances.size())
		return

	var clear := 0
	var blocked := 0
	for here: Vector3 in stances:
		for step: int in BEARINGS:
			var angle := TAU * float(step) / float(BEARINGS)
			var offset := Vector3(cos(angle), 0.0, sin(angle)) * data.preferred_range
			var there := _stance_at(here.x + offset.x, here.z + offset.z)
			if there == Vector3.INF:
				continue
			if _can_see(there, here):
				clear += 1
			else:
				blocked += 1

	var pairs := clear + blocked
	if pairs < 1000:
		_fail("only %d thrower positions were reachable at all — the sampling is broken" % pairs)
		return
	var sees := float(clear) / float(pairs)
	var hidden := float(blocked) / float(pairs)
	print(
		(
			"sightlines — %d pairs from %d stances: %.1f%% clear, %.1f%% blocked"
			% [pairs, stances.size(), sees * 100.0, hidden * 100.0]
		)
	)
	if sees < THREAT_FLOOR:
		_fail(
			(
				(
					"a thrower has a clear line only %.1f%% of the time, against a floor of %.0f%% — "
					+ "he throws into rock and the archetype is decoration"
				)
				% [sees * 100.0, THREAT_FLOOR * 100.0]
			)
		)
	if hidden < COVER_FLOOR:
		_fail(
			(
				(
					"only %.1f%% of lines are blocked, against a floor of %.0f%% — there is nowhere to "
					+ "break his line while closing, so a stone is a tax rather than something answered"
				)
				% [hidden * 100.0, COVER_FLOOR * 100.0]
			)
		)


## Every point on the sampled grid where a body could be standing in a fight.
func _fighting_ground() -> Array[Vector3]:
	var found: Array[Vector3] = []
	var reach := int(REACH / STEP)
	for row: int in range(-reach, reach + 1):
		for column: int in range(-reach, reach + 1):
			var where := _stance_at(float(column) * STEP, float(row) * STEP)
			if where != Vector3.INF:
				found.append(where)
	return found


## Where a body would stand at this point, or `INF` for anywhere it could not: off the ground, out
## past where the fight goes, or inside something.
func _stance_at(x: float, z: float) -> Vector3:
	var ground := _ground_under(x, z)
	if ground == Vector3.INF:
		return Vector3.INF
	if ground.y < WATERLINE - FIGHT_DEPTH:
		return Vector3.INF
	# Standing room, asked as a ray through where the body would be. A point under a rock overhang
	# or inside a hut post is not a stance, and counting it would fill the island with cover that
	# nobody can be shot through anyway.
	if _blocked(ground + Vector3.UP * 0.1, ground + Vector3.UP * STANDING_ROOM):
		return Vector3.INF
	return ground


func _ground_under(x: float, z: float) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, 40.0, z), Vector3(x, -20.0, z), 1)
	query.collide_with_areas = false
	var hit := _space.intersect_ray(query)
	return hit.get("position", Vector3.INF) if not hit.is_empty() else Vector3.INF


## Whether a stone thrown from `from` would reach `to` without meeting the island on the way.
func _can_see(from: Vector3, to: Vector3) -> bool:
	return not _blocked(from + Vector3.UP * THROW_HEIGHT, to + Vector3.UP * CHEST_HEIGHT)


func _blocked(from: Vector3, to: Vector3) -> bool:
	# Mask 1 alone: the `world` layer, which is the half of the stone's own mask 33 that is not the
	# player's hurtbox. What stops a stone is the island.
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.collide_with_areas = false
	return not _space.intersect_ray(query).is_empty()


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				"sightlines OK — a thrower can see the player often enough to be a threat, and the "
				+ "island gives enough cover to break his line while closing on him"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr("sightlines FAILED — %s" % failure)
	get_tree().quit(1)
