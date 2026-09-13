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
const FARMHAND: String = "res://data/enemies/farmhand.tres"
## Far enough apart that neither shoves the other while they are being measured.
const SHOULDER_TO_SHOULDER: float = 4.0
## Long enough for a flash to settle all the way back.
const FLASH_PATIENCE: float = 0.6
## How much brighter an elite has to be than the archetype it came from, in Rec. 709 luma. Written
## out rather than read off the resource, which would make it agree with any glow anybody sets.
const TELLS_APART: float = 0.35
## Enough rolls that a one-in-ten chance coming up nought would be a real result, not luck.
const ELITE_ROLLS: int = 400
## How finely the ring a body can arrive on is sampled.
const RING_STEPS: int = 360
## A body is taller than the point it stands on, and the camera looks down.
const HEAD_HEIGHT: float = 1.8
## How much of that ring the shot may cover before a wave has nowhere left to come from but behind
## the player. Written out rather than derived from the zoom being checked, which would make it
## agree with any camera anybody sets. At the shipped seventeen metres it is a quarter.
const MOST_OF_THE_RING_IN_SHOT: float = 0.40

var _failures: PackedStringArray = []
var _arena: Node3D = null
var _player: Player = null
var _director: WaveDirector = null
var _spawns: Array[Vector3] = []
## Where a body was standing the moment it arrived, if the camera could see it then.
var _seen_arriving: Array[Vector3] = []
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
	_check_the_camera_leaves_room_to_arrive_from()
	await _check_a_wave_arrives_and_clears()
	_check_nothing_spawned_in_shot_or_underfoot()
	_check_the_bodies_were_reused()
	await _check_an_elite_is_worse_and_obviously_so()
	_check_elites_keep_away_from_the_first_waves()
	_put_the_run_back()
	_report()


## Two claims, checked on a body rather than on a table: an elite is worth the trouble, and it is
## recognisable in under a second. The second one is the hard half — a hue alone would satisfy any
## check that only compared colours, and would vanish for a colourblind player or a greyscale
## screenshot, so what is asserted is **luminance**.
func _check_an_elite_is_worse_and_obviously_so() -> void:
	var config := _director.config
	var data := load(FARMHAND) as EnemyData
	if config == null or config.elite == null or data == null:
		_fail("there is no elite to check")
		return
	var plain := _director.spawner.spawn_at(data, Vector3.ZERO)
	var elite := _director.spawner.spawn_at(
		data, Vector3(SHOULDER_TO_SHOULDER, 0.0, 0.0), 1.0, 1.0, 1.0, 1.0, config.elite
	)
	if plain == null or elite == null:
		_fail("the pool would not lease two farmhands")
		return
	_same("an elite's health", elite.health.max_health, plain.health.max_health * 2.0)
	_same("an elite's damage", elite.damage_scale, plain.damage_scale * 1.4)
	_same("an elite's size", elite.visual.scale.x, 1.15)
	_check_the_elite_reads_in_greyscale(plain, elite)
	await _check_the_elite_still_reads_after_being_hit(plain, elite)
	_check_the_elite_pays_triple(plain, elite)
	plain.retire()
	elite.retire()


## The one cue that survives a greyscale screenshot and a colourblind player. Emission is what makes
## it work: it reads as brighter, not merely different.
func _check_the_elite_reads_in_greyscale(plain: Enemy, elite: Enemy) -> void:
	var apart := _brightness(elite) - _brightness(plain)
	if apart < TELLS_APART:
		_fail(
			(
				"an elite is %.2f brighter than a farmhand, and %.2f is the least that reads"
				% [apart, TELLS_APART]
			)
		)


## Rec. 709 luma of what the body actually puts out, emission included — which is what a greyscale
## screenshot would show.
##
## **Averaged over every surface the rig is drawn with, not read off one.** A painted character has
## several, and the rank's glow is applied to all of them; measuring only the first would grade the
## farmer on his shirt.
func _brightness(enemy: Enemy) -> float:
	var surfaces := enemy.body_materials.materials() if enemy.body_materials != null else []
	if surfaces.is_empty():
		return 0.0
	var total := 0.0
	for surface: StandardMaterial3D in surfaces:
		var out := surface.albedo_color
		if surface.emission_enabled:
			out += surface.emission * surface.emission_energy_multiplier
		total += 0.2126 * out.r + 0.7152 * out.g + 0.0722 * out.b
	return total / float(surfaces.size())


## An elite wears its rank in the emission slot, and so does the hit flash. Flashing to nought took
## the rank away with it — one hit and the only cue that reads at a glance was gone for the rest of
## that body's life.
##
## **`HitFeedback` is built here rather than found.** It lives in `main.tscn` and every check in
## this folder loads `arena.tscn`, so the two never met and nothing noticed. That is the whole
## reason the bug survived a check that measures this exact material.
func _check_the_elite_still_reads_after_being_hit(plain: Enemy, elite: Enemy) -> void:
	var feedback := HitFeedback.new()
	add_child(feedback)
	var before := _brightness(elite)
	EventBus.attack_landed.emit(elite, 10.0, true, null)
	EventBus.attack_landed.emit(plain, 10.0, true, null)
	await _let_the_flash_finish()
	var after := _brightness(elite)
	if after < before - 0.001:
		_fail(
			(
				(
					"an elite reads %.2f bright after one hit against %.2f before it — the flash took"
					+ " its rank away"
				)
				% [after, before]
			)
		)
	# And the flash still has to leave an ordinary farmer where it found him, or this "fix" is a
	# farmhand that glows.
	_check_the_elite_reads_in_greyscale(plain, elite)


func _let_the_flash_finish() -> void:
	var waited := 0.0
	while waited < FLASH_PATIENCE:
		await get_tree().process_frame
		waited += 1.0 / 60.0


func _check_the_elite_pays_triple(plain: Enemy, elite: Enemy) -> void:
	var paid: Array[int] = []
	var purse := func(_enemy: Node3D, _archetype: StringName, money: int) -> void:
		paid.append(money)
	EventBus.enemy_died.connect(purse)
	for body: Enemy in [plain, elite]:
		var killing := HitInfo.new()
		killing.damage = body.health.max_health * 2.0
		body.health.apply(killing)
	EventBus.enemy_died.disconnect(purse)
	if paid.size() != 2:
		_fail("two dead farmhands should pay twice, paid %d times" % paid.size())
		return
	if paid[1] != paid[0] * 3:
		_fail("an elite should pay %d, paid %d" % [paid[0] * 3, paid[1]])


## Wave four is where they start, and the roll is a coin toss the check would pass by luck a great
## deal of the time — so it is rolled until the odds of a false pass are nil.
func _check_elites_keep_away_from_the_first_waves() -> void:
	var config := _director.config
	if config == null:
		return
	for wave_index: int in range(1, config.elite_first_wave):
		if config.elite_chance(wave_index) > 0.0:
			_fail("wave %d can roll an elite, and elites start at %d" % [wave_index, 4])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rolled := 0
	for _attempt: int in ELITE_ROLLS:
		if rng.randf() < config.elite_chance(config.elite_first_wave):
			rolled += 1
	if rolled == 0:
		_fail("no elite came up in %d rolls at wave %d" % [ELITE_ROLLS, config.elite_first_wave])


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


## The camera decides where a wave can come from, which is not obvious from either file. A spawn
## point inside the shot is refused — a farmer fading into existence in frame tells the player the
## world is a spawner rather than a place — so pulling the camera back takes arrival directions
## away. The search has thirty-two attempts and keeps finding one long past the point where bodies
## only ever walk in from behind the player, so a check on whether it succeeds would never fail.
## This measures the ring instead.
func _check_the_camera_leaves_room_to_arrive_from() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _player == null:
		_fail("there is no camera to measure the shot with")
		return
	var in_shot := 0
	var tried := 0
	for step: int in RING_STEPS:
		for reach: float in [12.0, 17.0, 22.0, 26.0]:
			var angle := TAU * float(step) / float(RING_STEPS)
			var where := _player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * reach
			tried += 1
			if camera.is_position_in_frustum(where + Vector3.UP * HEAD_HEIGHT):
				in_shot += 1
	var share := float(in_shot) / float(tried)
	if share > MOST_OF_THE_RING_IN_SHOT:
		_fail(
			(
				(
					"the camera has %.0f%% of the spawn ring in shot, and %.0f%% is the most that"
					+ " leaves a wave somewhere to come from"
				)
				% [share * 100.0, MOST_OF_THE_RING_IN_SHOT * 100.0]
			)
		)


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


## Feet and head both, the way the spawn director tests it: a body is taller than the point it
## stands on, and a camera looking down catches the head first.
func _in_shot(camera: Camera3D, where: Vector3) -> bool:
	if camera == null:
		return false
	return (
		camera.is_position_in_frustum(where)
		or camera.is_position_in_frustum(where + Vector3.UP * HEAD_HEIGHT)
	)


func _passes(camera: Camera3D, world: World3D, where: Vector3) -> bool:
	var apart := Vector2(where.x - _player.global_position.x, where.z - _player.global_position.z)
	if apart.length() < NEAREST_SPAWN:
		_fail("the search offered a point %.1f m from the player" % apart.length())
		return false
	if _in_shot(camera, where):
		_fail("the search offered a point in shot at %s" % where)
		return false
	if not Ground.is_spawnable(world, where, _player.global_position):
		_fail("the search offered a point nobody can walk out of, at %s" % where)
		return false
	return true


## The same rules against the points the wave actually used.
func _check_nothing_spawned_in_shot_or_underfoot() -> void:
	var world := _player.get_world_3d()
	if not _seen_arriving.is_empty():
		_fail("something arrived inside the camera's view at %s" % _seen_arriving[0])
		return
	for where: Vector3 in _spawns:
		# The distance half survives being measured late: the player is shoved by a fraction of a
		# metre and the rule is twelve.
		var apart := Vector2(
			where.x - _player.global_position.x, where.z - _player.global_position.z
		)
		if apart.length() < NEAREST_SPAWN:
			_fail("something spawned %.1f m from the player" % apart.length())
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
	# Judged now, because the rule is about now. Arriving farmers shove the player, the camera
	# follows, and a point that was legitimately out of frame when a body walked on is inside it a
	# second later — which is how this check used to fail for a reason that was not the rule, and
	# could equally have passed while the rule was broken.
	var eye := get_viewport().get_camera_3d()
	if eye != null and _in_shot(eye, enemy.global_position):
		_seen_arriving.append(enemy.global_position)


func _on_wave_cleared(wave: int, reward: int) -> void:
	_cleared.append([wave, reward])


func _same(what: String, got: float, wanted: float) -> void:
	if absf(got - wanted) > 0.001:
		_fail("%s is %.3f, should be %.3f" % [what, got, wanted])


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				"waves OK — the table holds, a wave arrives out of shot, clears, pays, "
				+ "an elite is worse and looks it, and the purse keeps its shape"
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
