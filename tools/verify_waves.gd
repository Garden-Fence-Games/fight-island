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
## Long enough for a shortened wave to run its day and its night, with room for refused points.
const WAVE_PATIENCE: float = 12.0
## A wave is six minutes of real time, which is not a thing a headless check can sit through. The
## cycle is shrunk to this and the proportions of its phases are kept, so what is checked is the
## rule — the wave ends when its night does — and not the number.
const A_QUICK_WAVE: float = 2.4
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
var _kept_run: Dictionary = {}


func _ready() -> void:
	_run()


func _run() -> void:
	# Passing a wave writes a save. Whatever this machine already had goes back at the end: a check
	# that eats the developer's run is worse than no check.
	_kept_run = SaveManager.read_json(SaveManager.RUN_PATH)
	_check_the_formulas_match_the_table()
	_check_the_cost_curve()
	_check_a_run_affords_about_two_tracks()
	_check_a_wave_never_opens_with_a_thrower()

	_arena = (load(ARENA) as PackedScene).instantiate() as Node3D
	add_child(_arena)
	# Wave 1 belongs to the tutorial now, and a lesson holding it open would leave this check
	# waiting for a parry nobody is going to throw. This one is not about the lesson.
	_stand_the_tutorial_down(_arena)
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
	_put_the_run_back()
	_report()


func _put_the_run_back() -> void:
	if _kept_run.is_empty():
		SaveManager.clear_run()
		return
	SaveManager.write_json(SaveManager.RUN_PATH, _kept_run)


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
	for pair: Array in [[1, 18], [5, 42], [10, 72], [15, 102]]:
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


## The whole loop, once: bodies arrive to fill the island, never more than the table allows at a
## time, and the wave pays out when its night is over rather than when the last body falls.
func _check_a_wave_arrives_and_clears() -> void:
	var config := _director.config
	var ceiling := config.max_alive(1)
	_director.config = _shortened(config, A_QUICK_WAVE)
	var purse := GameState.money
	_director.start_wave(1)

	var waited := 0.0
	while _cleared.is_empty() and waited < WAVE_PATIENCE:
		await get_tree().physics_frame
		waited += 1.0 / 60.0
		if _director.spawner.alive_count() > ceiling:
			_fail(
				"wave 1 had %d alive, the most is %d" % [_director.spawner.alive_count(), ceiling]
			)
			return
	if _cleared.is_empty():
		_fail("a wave should end when its night does, %.1f s passed" % WAVE_PATIENCE)
		return
	if _spawns.is_empty():
		_fail("a wave should put somebody on the island")
		return
	# Nobody was killed, so the wave was passed on time. Bodies still standing are sent home.
	if _director.spawner.alive_count() > 0:
		_fail(
			"a passed wave should leave nobody standing, left %d" % _director.spawner.alive_count()
		)
	var paid: int = _cleared[0][1]
	var due := config.reward_for(1, true)
	if paid != due:
		_fail("an untouched wave 1 should pay %d, paid %d" % [due, paid])
	_check_the_money_reached_the_wallet(purse, paid, 0)
	if not _director.is_running() and _director.wave != 1:
		_fail("the director should still be on wave 1 until the breather ends")


## The same wave, with its day and its night squeezed into a couple of seconds. The proportions are
## kept, so a phase that is half the wave is still half of it.
func _shortened(config: WaveConfig, seconds: float) -> WaveConfig:
	var quick := config.duplicate() as WaveConfig
	if config.cycle == null or config.cycle.wave_seconds() <= 0.0:
		return quick
	var whole := config.cycle.wave_seconds()
	var cycle := DayCycle.new()
	var phases: Array[DayPhase] = []
	for phase: DayPhase in config.cycle.phases:
		var brief := phase.duplicate() as DayPhase
		brief.seconds = seconds * phase.seconds / whole
		phases.append(brief)
	cycle.phases = phases
	quick.cycle = cycle
	return quick


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
		_fail("the pool made %d bodies rather than leasing them" % pool.made_count())


func _on_enemy_spawned(enemy: Node3D) -> void:
	_spawns.append(enemy.global_position)


func _on_wave_cleared(wave: int, reward: int) -> void:
	_cleared.append([wave, reward])


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				"waves OK — the table holds, a wave arrives out of shot, clears, pays, "
				+ "and the purse and the cost curve keep their shape"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)


## The cost curve, written out. It is the one table in the game that is never read from a resource,
## because it is not a tuning knob — it is the shape the whole run is balanced against.
func _check_the_cost_curve() -> void:
	var wanted: Array[int] = [50, 80, 130, 205, 330]
	for owned: int in wanted.size():
		var cost := Economy.upgrade_cost(owned)
		if cost != wanted[owned]:
			_fail("upgrade %d should cost %d, costs %d" % [owned + 1, wanted[owned], cost])
	if Economy.upgrade_cost(Economy.LEVEL_CAP) != 0:
		_fail("there should be nothing to buy past the level cap")
	if Economy.track_cost() != 795:
		_fail("maxing one track should cost 795, costs %d" % Economy.track_cost())


## The design statement, not a number: rewards rise by a flat amount each wave while costs rise
## geometrically, so a full run buys about two tracks out of five. Asserted as a band, so a tuning
## pass that keeps the shape passes and one that flattens the choice does not.
func _check_a_run_affords_about_two_tracks() -> void:
	var config := load(CONFIG) as WaveConfig
	if config == null:
		return
	var earned := 0
	for wave_index: int in range(1, 16):
		earned += config.reward_for(wave_index, false)
	var track := Economy.track_cost()
	if earned < track * 2 or earned > track * 3:
		_fail(
			(
				"a fifteen-wave run earns %d against %d a track — it should buy two and change"
				% [earned, track]
			)
		)


## The wallet is a listener: the director pays out on the bus and each body pays out as it dies,
## and neither knows a wallet exists. This is the only place that is proven.
func _check_the_money_reached_the_wallet(before: int, paid: int, bodies: int) -> void:
	var per_kill := 0
	var band := _director.config.band_for(1)
	if band != null:
		var archetype := band.pick(RandomNumberGenerator.new(), true)
		per_kill = archetype.money if archetype != null else 0
	var due := paid + bodies * per_kill
	var earned := GameState.money - before
	if earned != due:
		_fail("clearing wave 1 should be worth %d in the purse, was worth %d" % [due, earned])


## Nobody is shot at before there is anything on screen to explain it. `WaveBand.pick` has carried
## the rule since the wave work and has never had a ranged archetype to filter — this is the first
## time it has anything to do, so it is the first time the rule is worth anything.
##
## Rolled many times rather than once: a rule that holds for one seed and not the next is not a
## rule, and a single roll of a table where the thrower is a fifth of the mix passes four times in
## five by luck alone.
func _check_a_wave_never_opens_with_a_thrower() -> void:
	var config := load(CONFIG) as WaveConfig
	if config == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260912
	for wave_index: int in [5, 8, 12, 20]:
		var band := config.band_for(wave_index)
		if band == null:
			_fail("wave %d has no composition band" % wave_index)
			continue
		var ranged_seen := false
		var opened := 0
		for _roll: int in 400:
			var first := band.pick(rng, true)
			if first == null:
				continue
			opened += 1
			if first.is_ranged:
				ranged_seen = true
		if opened == 0:
			_fail("wave %d cannot open with anybody at all" % wave_index)
		if ranged_seen:
			_fail("a wave %d opened with a thrower" % wave_index)
		# And the other half of it: the archetype has to be reachable once the wave is under way,
		# or "never opens with one" would be satisfied by never sending one.
		var ever_ranged := false
		for _roll: int in 400:
			var later := band.pick(rng, false)
			if later != null and later.is_ranged:
				ever_ranged = true
				break
		if wave_index >= 5 and not ever_ranged:
			_fail("no thrower ever appears at wave %d, where the table says they do" % wave_index)


func _stand_the_tutorial_down(arena: Node) -> void:
	var tutorial := arena.get_node_or_null(^"TutorialDirector") as TutorialDirector
	if tutorial != null:
		tutorial.stand_down()
