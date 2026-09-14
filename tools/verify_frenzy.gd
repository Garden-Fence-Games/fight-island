extends Node
## Headless proof of the rainbow bird: it is rolled one wave in three and never on the first, it
## lands where the camera is pointing and shines, and walking over it hands over exactly the power
## the table promises — nothing hurts, the feet are twice as fast, the hands hold fists and nothing
## else, and every punch throws a body the way the finisher does and kills it. It does not stack, it
## runs out, the wave takes it back, and afterwards the bag is what it was.
##
## Whatever run is on this machine is put back at the end.
## Run: godot --headless --path . res://tools/verify_frenzy.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
const FARMHAND: String = "res://data/enemies/farmhand.tres"
const MAP_SYNC_FRAMES: int = 240
const SETTLE_FRAMES: int = 8
## Waves rolled to judge the chance. Wide bounds: the claim is "about one in three", not a figure.
const ROLLS: int = 300
const FEWEST_SHARE: float = 0.22
const MOST_SHARE: float = 0.45
## How much health the target is given, so the one punch that kills it cannot be an ordinary one.
const TOUGH: float = 20.0
const AHEAD: float = 1.0
## Fixed so a failure reproduces. `FrenzyDirector` seeds its own generator off this, and a run that
## rolls its seed turns a broken placement into a coin toss nobody can repeat.
const SEED: int = 20260914

var _failures: PackedStringArray = []
var _arena: Node3D = null
var _player: Player = null
var _frenzy: FrenzyComponent = null
var _director: FrenzyDirector = null
var _waves: WaveDirector = null
var _kept_run: Dictionary = {}
## Where the player starts. Every placement returns it here first: a bird lands a few metres away
## and these checks walk the player onto it, so left alone the player crosses the island a bird at
## a time and the last placement finds nothing but sea within reach.
var _home := Vector3.ZERO


func _ready() -> void:
	_run()


func _run() -> void:
	_kept_run = SaveManager.read_json(SaveManager.RUN_PATH)
	await _open_the_arena()
	if _player == null or _frenzy == null or _director == null:
		_put_the_run_back()
		_report()
		return
	_check_the_table()
	_check_one_wave_in_three_and_never_the_first()
	await _check_the_bird_lands_in_view_and_shines()
	await _check_walking_over_it_gives_the_power()
	await _check_the_hands_hold_fists()
	await _check_it_does_not_stack()
	await _check_a_punch_throws_and_kills()
	await _check_it_runs_out()
	await _check_the_wave_takes_it_back()
	_put_the_run_back()
	_report()


func _open_the_arena() -> void:
	GameState.begin_run()
	# Before the arena is built: FrenzyDirector reads this in its own `_ready`.
	GameState.run_seed = SEED
	_arena = (load(ARENA) as PackedScene).instantiate() as Node3D
	add_child(_arena)
	await get_tree().physics_frame
	_player = _arena.get_node_or_null("Player") as Player
	_waves = _arena.get_node_or_null("WaveDirector") as WaveDirector
	_director = _arena.get_node_or_null("FrenzyDirector") as FrenzyDirector
	var tutorial := _arena.get_node_or_null("TutorialDirector") as TutorialDirector
	if tutorial != null:
		tutorial.stand_down()
	if _waves != null:
		_waves.halt()
	if _player == null:
		_fail("the arena holds no player")
		return
	_home = _player.global_position
	_frenzy = _player.frenzy
	if _frenzy == null:
		_fail("the player carries no Frenzy component — the bird has nothing to hand its power to")
	if _director == null:
		_fail("the arena has no FrenzyDirector — nothing puts the rainbow bird on the island")
	await _wait_for_the_map()


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


## Written out rather than read back, so the resource and `docs/game-design.md` cannot drift
## together.
func _check_the_table() -> void:
	var data := _director.data
	if data == null:
		_fail("the director has no FrenzyData")
		return
	_expect(data.lasts, 15.0, "the power's length")
	_expect(data.speed_multiplier, 2.0, "the speed multiplier")
	if absf(data.chance_per_wave - 1.0 / 3.0) > 0.001:
		_fail("a wave rolls a bird %.3f of the time, expected one in three" % data.chance_per_wave)
	if data.first_wave != 2:
		_fail("the first wave that may have a bird is %d, expected 2" % data.first_wave)
	var fists := Arsenal.find(Arsenal.STARTING)
	var finisher := fists.attack_at(fists.chain_length() - 1) if fists != null else null
	if data.launches_like == null or data.launches_like != finisher:
		_fail("a punch during the power is not thrown like the fists' finisher")


func _check_one_wave_in_three_and_never_the_first() -> void:
	for _roll: int in ROLLS:
		_director._on_wave_started(1, 20)
		if _director.owes_a_bird():
			_fail("the first wave rolled a rainbow bird")
			break
	var landed := 0
	for _roll: int in ROLLS:
		_director._on_wave_started(4, 20)
		if _director.owes_a_bird():
			landed += 1
	var share := float(landed) / float(ROLLS)
	if share < FEWEST_SHARE or share > MOST_SHARE:
		_fail("%.0f%% of waves rolled a bird, expected about one in three" % (share * 100.0))
	_director._on_wave_cleared(4, 0)


func _check_the_bird_lands_in_view_and_shines() -> void:
	var bird := await _a_bird()
	if bird == null:
		_fail("the director could not land a rainbow bird anywhere")
		return
	await get_tree().physics_frame
	var camera := get_viewport().get_camera_3d()
	if camera != null and not camera.is_position_in_frustum(bird.global_position):
		_fail("the rainbow bird landed where the camera is not pointing")
	var dressed := 0
	for mesh: MeshInstance3D in _meshes(bird):
		if mesh.material_overlay == bird.overlay() and bird.overlay() != null:
			dressed += 1
	if dressed == 0:
		_fail("the rainbow bird does not wear the rainbow")
	if bird.get_node_or_null(^"Glow") as OmniLight3D == null:
		_fail("the rainbow bird throws no light on the sand")
	var flock := _arena.get_node_or_null("BirdFlock")
	if flock != null and bird.get_parent() == flock:
		_fail("the rainbow bird belongs to the flock — it would fly off when approached")
	var stood := bird.global_position
	for _frame: int in 30:
		await get_tree().physics_frame
	if bird.global_position.distance_to(stood) > 0.01:
		_fail("the rainbow bird moved from where it landed")


func _check_walking_over_it_gives_the_power() -> void:
	var bag := GameState.loadout
	bag.find_weapon(&"gun")
	bag.equip(&"gun")
	var bird := _director.bird()
	if bird == null:
		bird = await _a_bird()
	if bird == null:
		_fail("no rainbow bird to walk over")
		return
	var heard: Array[float] = []
	var listener := func(seconds: float) -> void: heard.append(seconds)
	EventBus.rainbow_bird_taken.connect(listener)
	var taken := await _walk_onto(bird)
	EventBus.rainbow_bird_taken.disconnect(listener)
	if not taken or not _frenzy.is_active():
		_fail("the player walked over the rainbow bird and nothing happened")
		return
	if heard.is_empty() or not is_equal_approx(heard[0], _director.data.lasts):
		_fail("taking the bird was not announced with its length")
	if bag.equipped != Arsenal.STARTING:
		_fail("the power began with %s in hand rather than fists" % bag.equipped)
	_expect(_player.speed_multiplier, _director.data.speed_multiplier, "the player's speed")
	if _player.animation != null:
		_expect(_player.animation.pace, _director.data.speed_multiplier, "the walk's pace")
	var blow := HitInfo.new()
	blow.damage = 50.0
	blow.stagger = 1.0
	var before := _player.health.current_health
	_player.hurtbox.take_hit(blow)
	if _player.health.current_health < before:
		_fail("the player was hurt while the power was on")
	await _wait(FrenzyComponent.FADE + 0.05)
	var dressed := false
	for mesh: MeshInstance3D in _meshes(_player.get_node(^"Visual")):
		dressed = dressed or mesh.material_overlay == _frenzy.overlay()
	if not dressed:
		_fail("the player does not wear the rainbow while the power is on")
	if float(_frenzy.overlay().get_shader_parameter(&"strength")) <= 0.5:
		_fail("the rainbow on the player never came on")


func _check_the_hands_hold_fists() -> void:
	var next := InputEventAction.new()
	next.action = &"weapon_next"
	next.pressed = true
	_player._unhandled_input(next)
	var gun := InputEventAction.new()
	gun.action = &"weapon_gun"
	gun.pressed = true
	_player._unhandled_input(gun)
	if GameState.loadout.equipped != Arsenal.STARTING:
		_fail("the weapon could be switched while the power was on")
	GameState.loadout.equip(&"gun")
	for _frame: int in 3:
		await get_tree().process_frame
	if GameState.loadout.equipped != Arsenal.STARTING:
		_fail("a weapon put in hand during the power stayed there")


func _check_it_does_not_stack() -> void:
	_frenzy._process(1.0)
	var left := _frenzy.time_left()
	var second := await _a_bird()
	if second == null:
		_fail("could not land a second bird")
		return
	var taken := await _walk_onto(second)
	if taken:
		_fail("a second rainbow bird was taken while the power was on — it stacks")
	if _frenzy.time_left() > left + 0.001:
		_fail("a second bird put the clock back up")
	_director.take_away()
	await get_tree().physics_frame


func _check_a_punch_throws_and_kills() -> void:
	var data := load(FARMHAND) as EnemyData
	var ahead := -_player.global_transform.basis.z * AHEAD
	var target := _waves.spawner.spawn_at(
		data, _player.global_position + ahead, TOUGH, 1.0, 1.0, 1.0, null, true
	)
	if target == null:
		_fail("could not stand a farmer in front of the player")
		return
	await get_tree().physics_frame
	var jab := _player.weapon.attack_at(0)
	_player.hitbox.arm(jab, _player, false, 1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_player.hitbox.disarm()
	if target.health.is_alive():
		_fail(
			(
				"a jab during the power left a farmer on %.0f of %.0f health — it should one-shot"
				% [target.health.current_health, target.health.max_health]
			)
		)
	if target.last_hit_push < _director.data.launches_like.stagger - 0.001:
		_fail(
			(
				"a jab during the power threw the body with %.2f, and the finisher throws with %.2f"
				% [target.last_hit_push, _director.data.launches_like.stagger]
			)
		)


func _check_it_runs_out() -> void:
	var step := 1.0 / 60.0
	var frames := int(_director.data.lasts / step) + 4
	for _frame: int in frames:
		if not _frenzy.is_active():
			break
		_frenzy._process(step)
	if _frenzy.is_active():
		_fail("the power was still on after its whole %.0f s" % _director.data.lasts)
		return
	_check_the_power_is_gone("ran out")
	await _wait(FrenzyComponent.FADE + 0.1)
	for mesh: MeshInstance3D in _meshes(_player.get_node(^"Visual")):
		if mesh.material_overlay != null:
			_fail("the rainbow was still on the player after the power ran out")
			break


func _check_the_wave_takes_it_back() -> void:
	var bird := await _a_bird()
	if bird == null or not await _walk_onto(bird):
		_fail("could not take a bird for the end-of-wave check")
		return
	var lying := await _a_bird()
	_director._on_wave_cleared(3, 0)
	await get_tree().physics_frame
	if _frenzy.is_active():
		_fail("the power outlived the wave")
	if lying != null and is_instance_valid(lying) and not lying.is_queued_for_deletion():
		_fail("a bird nobody took was still on the island after the wave")
	_check_the_power_is_gone("the wave ended")


func _check_the_power_is_gone(why: String) -> void:
	if GameState.loadout.equipped != &"gun":
		_fail("when the power %s the gun was not back in hand" % why)
	_expect(_player.speed_multiplier, 1.0, "the player's speed after the power " + why)
	if _player.health.is_invulnerable() and _player.health.shielded:
		_fail("the player was still shielded after the power %s" % why)
	if _player.hitbox.overwhelm != null:
		_fail("punches still overwhelm after the power %s" % why)


## A bird placed with the player back at its spawn, so one check's walk cannot strand the next.
func _a_bird() -> RainbowBird:
	_player.global_position = _home
	for _frame: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	return _director.place()


func _walk_onto(bird: RainbowBird) -> bool:
	var where := bird.global_position
	_player.global_position = Vector3(where.x, _player.global_position.y, where.z)
	for _frame: int in 12:
		await get_tree().physics_frame
		if not is_instance_valid(bird) or bird.is_queued_for_deletion():
			return true
	return false


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child: Node in root.get_children():
		var mesh := child as MeshInstance3D
		if mesh != null:
			found.append(mesh)
		found.append_array(_meshes(child))
	return found


func _wait(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0


func _expect(got: float, wanted: float, what: String) -> void:
	if not is_equal_approx(got, wanted):
		_fail("%s is %.2f, the table says %.2f" % [what, got, wanted])


func _put_the_run_back() -> void:
	if _kept_run.is_empty():
		SaveManager.clear_run()
		return
	SaveManager.write_json(SaveManager.RUN_PATH, _kept_run)


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	for _index: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	if _failures.is_empty():
		print(
			(
				"frenzy OK — one wave in three and never the first, the bird lands in view and "
				+ "shines, it shields, doubles the pace and holds the hands to fists, a jab kills "
				+ "and throws like the finisher, it does not stack, and it ends on time and with "
				+ "the wave"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
