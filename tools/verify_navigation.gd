extends Node
## Headless proof that the island can be walked: there is a navigation mesh, it knows where nobody
## can stand, and a farmer who has a rock between him and the player goes around it.
##
## The last one is the whole point of the issue and the only check that could not be replaced by
## reading the scene file. Straight-line chasing passes every other test on this list.
## Run: godot --headless --path . res://tools/verify_navigation.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
const FARMHAND: String = "res://data/enemies/farmhand.tres"
## The first authored boulder, and its half-width once the collider's 0.7 scale is applied. The
## test needs a solid thing in a known place; this is the one the island guarantees.
const BOULDER: Vector3 = Vector3(-34.0, 0.0, -26.0)
const BOULDER_HALF_WIDTH: float = 1.75
## Where the two of them stand, either side of that boulder, so the straight line runs through it.
const STAND_OFF: float = 4.5
## A route that bends around something has to be meaningfully longer than the line it replaces.
const DETOUR_MARGIN: float = 1.1
## How long the farmer gets to cross nine metres he cannot cross in a straight line. At 3.4 m/s the
## detour is about four seconds of walking; ten is generous without being meaningless.
const CROSSING_SECONDS: float = 10.0
## Thirty agents is the wave-fifteen crowd. Measured as time actually spent inside the physics
## step, because headless still paces its main loop at the tick rate — wall-clock per frame would
## read 16.6 ms however little work there was, which is a test that can never fail.
##
## The ceiling is a blow-up detector, not a performance target: it runs on whatever machine CI
## hands out, so anything tight would fail for being on a slow runner rather than for being slow
## code. Two frames' worth of physics is a number no amount of runner variance reaches and no
## healthy island approaches. The real 60 fps measurement, with rendering and on real hardware,
## belongs to issue #31. The number is printed either way — that is what makes drift visible.
const CROWD: int = 30
const CROWD_BUDGET_MS: float = 33.0
## How long the navigation map gets to come up before that is the failure.
const MAP_SYNC_FRAMES: int = 120
const PERF_SAMPLES: int = 120

var _failures: PackedStringArray = []
var _arena: Node3D = null
var _player: Player = null
var _enemy: Enemy = null


func _ready() -> void:
	_run()


func _run() -> void:
	_arena = (load(ARENA) as PackedScene).instantiate() as Node3D
	add_child(_arena)
	# Wave 1 belongs to the tutorial now, and a lesson holding it open would leave this check
	# waiting for a parry nobody is going to throw. This one is not about the lesson.
	_stand_the_tutorial_down(_arena)
	await _wait_for_the_map()

	_player = _arena.get_node("Player") as Player
	var director := _arena.get_node("WaveDirector") as WaveDirector
	director.halt()
	_enemy = director.spawner.spawn_at(load(FARMHAND) as EnemyData, Vector3(0.0, 1.0, -8.0))
	if _player == null or _enemy == null:
		_fail("the arena does not hold a player and an enemy")
		_report()
		return

	_check_the_island_is_baked()
	_check_the_enemy_carries_an_agent()
	_check_where_nobody_can_stand()
	_check_the_route_bends_around_the_boulder()
	await _check_the_farmer_walks_around_it()
	await _check_a_crowd_fits_in_a_frame()
	_report()


## The navigation server builds its map on a physics step, and every query before that first
## iteration fails loudly and answers nonsense. Waiting on the iteration id is the documented way
## to know it is ready; counting frames is a guess that holds until the island gets bigger.
func _wait_for_the_map() -> void:
	var map := _arena.get_world_3d().navigation_map
	for _attempt: int in MAP_SYNC_FRAMES:
		await get_tree().physics_frame
		# The iteration id says the map has been rebuilt; a query that comes back with a route says
		# it can actually answer one, which is a frame or two later and is what the checks need.
		if NavigationServer3D.map_get_iteration_id(map) == 0:
			continue
		if not (
			NavigationServer3D
			. map_get_path(map, Vector3.ZERO, Vector3(4.0, 0.0, 4.0), false)
			. is_empty()
		):
			return
	_fail("the navigation map never answered a path query")


func _check_the_island_is_baked() -> void:
	var region := _arena.get_node_or_null(^"Island/Navigation") as NavigationRegion3D
	if region == null:
		_fail("the island has no navigation region")
		return
	if region.navigation_mesh == null or region.navigation_mesh.get_polygon_count() == 0:
		_fail("the navigation region carries no baked mesh")


func _check_the_enemy_carries_an_agent() -> void:
	if _enemy.agent == null:
		_fail("the farmhand has no navigation agent")


## The three answers that make a spawn point safe to use.
##
## The boulder is the interesting one. Recast leaves walkable ground inside it — floor with no way
## in — so a check that only asked "is there navigation mesh here" would approve spawning a farmer
## inside five metres of stone, and he would stand there for the whole wave.
func _check_where_nobody_can_stand() -> void:
	var world := _arena.get_world_3d()
	var fight := Vector3.ZERO
	if not Ground.is_spawnable(world, Vector3(6.0, 0.0, 6.0), fight):
		_fail("the ground beside the spawn pad should be spawnable")
	if Ground.is_spawnable(world, BOULDER, fight):
		_fail("the inside of a boulder should not be spawnable")
	if Ground.is_spawnable(world, Vector3(0.0, 0.0, 160.0), fight):
		_fail("open sea should not be spawnable")


## A straight line here runs through three and a half metres of stone. Anything the navigation mesh
## returns has to be longer than that line, or it is not going around anything.
func _check_the_route_bends_around_the_boulder() -> void:
	var world := _arena.get_world_3d()
	# Snapped first: a path query takes the points as given, and both of these are authored at y=0
	# on ground that rolls.
	var from := Ground.closest_point(world, BOULDER + Vector3(0.0, 0.0, STAND_OFF))
	var to := Ground.closest_point(world, BOULDER - Vector3(0.0, 0.0, STAND_OFF))
	var route := NavigationServer3D.map_get_path(world.navigation_map, from, to, true)
	if route.size() < 3:
		_fail("the route past the boulder is a straight line of %d points" % route.size())
		return
	var walked := 0.0
	for index: int in route.size() - 1:
		walked += route[index].distance_to(route[index + 1])
	var straight := from.distance_to(to)
	if walked < straight * DETOUR_MARGIN:
		_fail("the route past the boulder is %.1f m against %.1f m straight" % [walked, straight])
	for point: Vector3 in route:
		var flat := Vector2(point.x - BOULDER.x, point.z - BOULDER.z)
		if flat.length() < BOULDER_HALF_WIDTH:
			_fail("the route passes %.1f m from the middle of the boulder" % flat.length())
			return


## The end-to-end one, and the only proof that the agent is actually driving the legs.
func _check_the_farmer_walks_around_it() -> void:
	_player.machine.current.transition_to(&"Idle")
	_player.global_position = BOULDER + Vector3(0.0, 1.0, STAND_OFF)
	_enemy.health.current_health = _enemy.health.max_health
	_enemy.global_position = BOULDER + Vector3(0.0, 1.0, -STAND_OFF)
	_enemy.machine.current.transition_to(&"Chase")
	await _advance(CROSSING_SECONDS)
	var left := _enemy.distance_to_target()
	if left > _enemy.data.attack_range + 1.0:
		_fail("the farmhand stopped %.1f m away, the boulder still between them" % left)


## Thirty agents re-pathing is the cost that has to fit, and headless is where it is measurable
## without a GPU in the way. Printed either way — a number nobody reads is a number nobody notices
## drifting.
func _check_a_crowd_fits_in_a_frame() -> void:
	# Back on the open plateau: the previous check left the two of them wedged either side of a
	# boulder, which is not what a wave looks like.
	_player.global_position = Vector3(0.0, 1.0, 0.0)
	var director := _arena.get_node("WaveDirector") as WaveDirector
	var data := load(FARMHAND) as EnemyData
	for index: int in CROWD:
		var angle := TAU * float(index) / float(CROWD)
		var where := _player.global_position + Vector3(cos(angle), 1.0, sin(angle)) * 12.0
		director.spawner.spawn_at(data, where)
	# Long enough for the crowd to have landed, found their routes and spread out. Measuring while
	# thirty bodies are still falling into each other measures the fall.
	await _advance(2.0)

	var samples := 0
	var total := 0.0
	while samples < PERF_SAMPLES:
		await get_tree().physics_frame
		total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		samples += 1
	var per_step := total / float(samples) * 1000.0
	print("%d agents — %.2f ms of physics a step" % [CROWD + 1, per_step])
	if per_step > CROWD_BUDGET_MS:
		_fail(
			(
				"%d agents cost %.2f ms of physics a step, the budget is %.1f"
				% [CROWD + 1, per_step, CROWD_BUDGET_MS]
			)
		)


func _advance(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print("navigation OK — baked, spawn points checked, the farmhand walks around the rock")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)


func _stand_the_tutorial_down(arena: Node) -> void:
	var tutorial := arena.get_node_or_null(^"TutorialDirector") as TutorialDirector
	if tutorial != null:
		tutorial.stand_down()
