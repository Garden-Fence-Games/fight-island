extends Node
## Headless proof that a wave is what the design says it is: the tabled count, never more than the
## tabled number alive at once, nothing spawning in shot or on top of the player, a clear that pays
## the tabled reward, and bodies that are reused rather than made.
##
## The formula checks are the cheap half and the valuable half: they are the only thing stopping
## `docs/game-design.md` and `data/waves/standard.tres` from drifting apart, and nothing about that
## drift is visible until a wave feels wrong six months later.
## Run: godot --headless --path . res://tools/verify_waves.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
const CONFIG: String = "res://data/waves/standard.tres"
## Long enough for a four-body wave at one every 0.6 s, with room for a few refused points.
const WAVE_PATIENCE: float = 12.0
## How many points the spawn search is asked for. Not a sample — the search.
const POINTS: int = 200
## The rule, written out rather than read off the class being checked. Reading SpawnDirector's own
## constant would make this assertion agree with any value someone puts there, which is not a test.
const NEAREST_SPAWN: float = 12.0
## The navigation map is built on a physics step, and until it answers, every point is refused.
## This is also why the first wave is not instant in the game.
const MAP_SYNC_FRAMES: int = 120

var _failures: PackedStringArray = []
var _arena: Node3D = null
var _player: Player = null
var _director: WaveDirector = null
var _spawns: Array[Vector3] = []
var _cleared: Array = []


func _ready() -> void:
	_run()


func _run() -> void:
	_check_the_formulas_match_the_table()

	_arena = (load(ARENA) as PackedScene).instantiate() as Node3D
	add_child(_arena)
	_director = _arena.get_node("WaveDirector") as WaveDirector
	_director.halt()
	await _wait_for_the_map()
	_player = _arena.get_node("Player") as Player
	if _player == null or _director == null or _director.spawner == null:
		_fail("the arena is missing a player or a wave director")
		_report()
		return

	EventBus.enemy_spawned.connect(_on_enemy_spawned)
	EventBus.wave_cleared.connect(_on_wave_cleared)

	_check_every_point_the_search_offers()
	await _check_a_wave_arrives_and_clears()
	_check_nothing_spawned_in_shot_or_underfoot()
	_check_the_bodies_were_reused()
	_report()


## Nothing can be spawned before the navigation map answers, so waiting for it is part of the
## setup rather than something to assert.
func _wait_for_the_map() -> void:
	var map := _arena.get_world_3d().navigation_map
	for _attempt: int in MAP_SYNC_FRAMES:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(map) == 0:
			continue
		var probe := NavigationServer3D.map_get_path(
			map, Vector3.ZERO, Vector3(4.0, 0.0, 4.0), false
		)
		if not probe.is_empty():
			return
	_fail("the navigation map never came up, so nothing could ever spawn")


## The table in docs/game-design.md, asserted against the resource that actually drives the game.
func _check_the_formulas_match_the_table() -> void:
	var config := load(CONFIG) as WaveConfig
	if config == null:
		_fail("there is no wave configuration to check")
		return
	for pair: Array in [[1, 4], [5, 11], [10, 19], [15, 27]]:
		var got := config.enemy_count(int(pair[0]))
		if got != int(pair[1]):
			_fail("wave %d should send %d enemies, sends %d" % [pair[0], pair[1], got])
	if config.max_alive(1) != 4:
		_fail("wave 1 should hold 4 alive, holds %d" % config.max_alive(1))
	if config.max_alive(15) != 12:
		_fail("max_alive should cap at 12, wave 15 holds %d" % config.max_alive(15))
	if not is_equal_approx(config.health_multiplier(15), 3.52):
		_fail("wave 15 health should be x3.52, is x%.2f" % config.health_multiplier(15))
	if not is_equal_approx(config.damage_multiplier(15), 2.40):
		_fail("wave 15 damage should be x2.40, is x%.2f" % config.damage_multiplier(15))
	# Floors and ceilings, which are the part a tuning pass is most likely to break.
	if not is_equal_approx(config.speed_multiplier(30), config.speed_ceiling):
		_fail("speed should stop at its ceiling")
	if not is_equal_approx(config.windup_multiplier(30), config.windup_floor):
		_fail("the telegraph should stop shortening at its floor")
	if not is_zero_approx(config.elite_chance(3)):
		_fail("elites should not appear before wave %d" % config.elite_first_wave)
	if not is_equal_approx(config.elite_chance(30), config.elite_chance_ceiling):
		_fail("the elite chance should cap")
	if config.reward_for(1, false) != 50 or config.reward_for(5, false) != 98:
		_fail("the wave reward does not match the table")
	if config.reward_for(1, true) != 65:
		_fail("a flawless wave 1 should pay 65, pays %d" % config.reward_for(1, true))
	# A band that names archetypes which do not exist yet must still answer.
	var band := config.band_for(12)
	if band == null or band.first_wave != 12:
		_fail("wave 12 should use the last composition band")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	if band != null and band.pick(rng) == null:
		_fail("a band should still pick an archetype when only some of them exist")


## The whole loop, once: the wave arrives a body at a time, never overcrowds, and pays out when the
## last one goes down.
func _check_a_wave_arrives_and_clears() -> void:
	var config := _director.config
	var wanted := config.enemy_count(1)
	var ceiling := config.max_alive(1)
	_director.start_wave(1)

	var waited := 0.0
	while _spawns.size() < wanted and waited < WAVE_PATIENCE:
		await get_tree().physics_frame
		waited += 1.0 / 60.0
		if _director.spawner.alive_count() > ceiling:
			_fail(
				"wave 1 had %d alive, the most is %d" % [_director.spawner.alive_count(), ceiling]
			)
			return
	if _spawns.size() != wanted:
		_fail("wave 1 should send %d, sent %d in %.0f s" % [wanted, _spawns.size(), WAVE_PATIENCE])
		return

	_kill_everything()
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _cleared.is_empty():
		_fail("killing the last enemy should clear the wave")
		return
	var paid: int = _cleared[0][1]
	var due := config.reward_for(1, true)
	if paid != due:
		_fail("an untouched wave 1 should pay %d, paid %d" % [due, paid])
	if not _director.is_running() and _director.wave != 1:
		_fail("the director should still be on wave 1 until the breather ends")


## The rules, asserted against the search itself rather than against the handful of points one wave
## happened to use. Four spawns is too small a sample to catch a missing rule — with the guard for
## "never in shot" deleted, a four-body wave still passed, which makes that check decorative on its
## own. Two hundred points is not a sample, it is the search.
func _check_every_point_the_search_offers() -> void:
	var camera := get_viewport().get_camera_3d()
	var world := _player.get_world_3d()
	var refused := 0
	for _index: int in POINTS:
		var where := _director.spawner.find_point()
		if where == Vector3.INF:
			refused += 1
			continue
		if not _passes(camera, world, where):
			return
	# A search that answers INF every time would pass every rule above by never offering anything.
	if refused > POINTS / 4:
		_fail("the spawn search refused %d of %d points" % [refused, POINTS])


func _passes(camera: Camera3D, world: World3D, where: Vector3) -> bool:
	var apart := Vector2(where.x - _player.global_position.x, where.z - _player.global_position.z)
	if apart.length() < NEAREST_SPAWN:
		_fail("the search offered a point %.1f m from the player" % apart.length())
		return false
	if camera != null and camera.is_position_in_frustum(where):
		_fail("the search offered a point inside the camera's view at %s" % where)
		return false
	if camera != null and camera.is_position_in_frustum(where + Vector3.UP * 1.8):
		_fail("the search offered a point whose head is in shot at %s" % where)
		return false
	if not Ground.is_spawnable(world, where, _player.global_position):
		_fail("the search offered a point nobody can walk out of, at %s" % where)
		return false
	return true


## The same rules against the points the wave actually used.
func _check_nothing_spawned_in_shot_or_underfoot() -> void:
	var camera := get_viewport().get_camera_3d()
	var world := _player.get_world_3d()
	for where: Vector3 in _spawns:
		var apart := Vector2(
			where.x - _player.global_position.x, where.z - _player.global_position.z
		)
		if apart.length() < NEAREST_SPAWN:
			_fail("something spawned %.1f m from the player" % apart.length())
			return
		if camera != null and camera.is_position_in_frustum(where):
			_fail("something spawned inside the camera's view at %s" % where)
			return
		if not Ground.is_spawnable(world, where, _player.global_position):
			_fail("something spawned where it cannot walk out of, at %s" % where)
			return


## A pool that quietly makes a new body per spawn is a pool in name only, and nothing about it is
## visible until a long run starts stuttering.
func _check_the_bodies_were_reused() -> void:
	var pool := _director.spawner.pool
	if pool == null:
		_fail("the spawn director has no pool")
		return
	if pool.made_count() != EnemyPool.SIZE:
		_fail("the pool made %d bodies for a four-enemy wave" % pool.made_count())


func _kill_everything() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.health == null:
			continue
		var killing := HitInfo.new()
		killing.damage = enemy.health.max_health * 2.0
		enemy.health.apply(killing)


func _on_enemy_spawned(enemy: Node3D) -> void:
	_spawns.append(enemy.global_position)


func _on_wave_cleared(wave: int, reward: int) -> void:
	_cleared.append([wave, reward])


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print("waves OK — the table holds, a wave arrives out of shot, clears, and pays")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
