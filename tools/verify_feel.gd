extends Node
## Proof that one blow spends once, that nothing shouts over a telegraph, and that stopping the
## clock never costs the player an input.
##
## The effects themselves are checked elsewhere — `verify_vfx` for the bursts, `verify_camera` for
## the fade. This is about the **budget**: every one of these is individually an improvement and
## collectively a mess, so what matters is that the total on a single hit was decided rather than
## accumulated.
## Run: godot --headless --path . res://tools/verify_feel.tscn

## The whole game, not the arena. `HitFeedback` — the one thing that turns a hitstop request into a
## slowed clock — is a child of `main.tscn` and not of the arena, and a check that loaded the arena
## would emit into a bus nobody is listening on and pass by never testing anything. That mistake has
## already cost this project one wrong bug report.
const MAIN: String = "res://scenes/main/main.tscn"
const FARMHAND: String = "res://data/enemies/farmhand.tres"
const FARMHAND_SWING: String = "res://data/attacks/farmhand_swing.tres"
## The heaviest stop in the game, and the lightest. Written out rather than read off the `.tres`, so
## a rebalance that quietly puts a third of a second on one attack fails here.
const HEAVIEST_ATTACK: String = "res://data/attacks/gun_charged.tres"
const HEAVIEST_SECONDS: float = 0.18
## Far enough that a farmer stood here is plainly in shot at the default zoom, and near enough to be
## on the flat — `verify_view` measures 8.5 m on the blind bearing.
const IN_SHOT: float = 5.0
## And plainly off it. `verify_view` measures 8.5 m of ground staying in shot on the blind bearing,
## which is the direction this walks in.
const OUT_OF_SHOT: float = 20.0
## Comfortably longer than the buffer in real seconds. At the resting clock a press this old is
## gone; under a hitstop at a twentieth speed it has aged a tenth of that and is still good. One
## figure, both halves, so the two cannot quietly stop testing the same thing.

const OUTLIVES_THE_BUFFER: float = 0.25
## The ceiling this check was written against, in frames. Written out, not read — see
## `_check_no_blow_may_pass_the_ceiling`.
const EXPECTED_CEILING: int = 12
## How long the fiercest knock has to be over in, and what counts as over. At the shipped decay a
## full knock is down to a thousandth inside a second and a half; the bound is written out rather
## than derived from the decay, or moving the decay would move the bound with it.
const SETTLES_WITHIN: float = 1.5
const STILL_SHAKING: float = 0.01

var _failures: PackedStringArray = []
var _arena: Node3D = null
var _player: Player = null
var _rig: CameraRig = null


func _ready() -> void:
	_run()


func _run() -> void:
	GameState.begin_run()
	var main := (load(MAIN) as PackedScene).instantiate()
	add_child(main)
	_arena = main.get_node_or_null(^"Arena") as Node3D
	if _arena == null:
		_fail("the game has no arena")
		_report()
		return
	_stand_the_tutorial_down(_arena)
	await get_tree().physics_frame
	_player = _arena.get_node_or_null(^"Player") as Player
	_rig = _arena.get_node_or_null(^"CameraRig") as CameraRig
	var director := _arena.get_node_or_null(^"WaveDirector") as WaveDirector
	if director != null:
		director.halt()
	if _player == null or _rig == null:
		_fail("the arena has no player or no camera rig")
		_report()
		return

	_check_a_blow_spends_once_and_never_sums()
	_check_nothing_outshouts_a_perfect_parry()
	_check_no_blow_may_pass_the_ceiling()
	await _check_a_telegraph_in_shot_refuses_every_knock()
	await _check_a_telegraph_behind_the_player_refuses_nothing()
	await _check_a_stop_never_eats_a_press()
	await _check_taking_a_hit_is_the_loudest_thing_that_happens()
	await _check_a_knock_dies_away()
	_report()


## The rule the whole table exists for. A perfect finisher that kills is three things about one
## swing, and three emphatic answers to one swing is the noise this pass was opened to stop.
func _check_a_blow_spends_once_and_never_sums() -> void:
	var stop := (load(HEAVIEST_ATTACK) as AttackData).hitstop
	var everything := Emphasis.for_hit(true, true, true, stop)
	var loudest_stop := maxf(stop, float(Emphasis.KILL_FRAMES) * Emphasis.FRAME)
	if not is_equal_approx(float(everything["seconds"]), loudest_stop):
		_fail(
			(
				(
					"a perfect finisher that kills stops for %.3f s, and the loudest single reason to "
					+ "stop is %.3f s — the figures were added up"
				)
				% [float(everything["seconds"]), loudest_stop]
			)
		)
	var loudest_shake := maxf(Emphasis.FINISHER_SHAKE, Emphasis.KILL_SHAKE)
	if not is_equal_approx(float(everything["shake"]), loudest_shake):
		_fail(
			(
				"the same blow shakes %.2f and the loudest single reason is %.2f"
				% [float(everything["shake"]), loudest_shake]
			)
		)
	var plain := Emphasis.for_hit(false, false, false, stop)
	if float(plain["seconds"]) > 0.0 or float(plain["shake"]) > 0.0:
		_fail("a hit that is only a hit spent %s, and it is supposed to spend nothing" % plain)


## The parry is the most skilful input in the game and holds the longest stop in it. A table where
## something else quietly drew level would have stopped saying that.
func _check_nothing_outshouts_a_perfect_parry() -> void:
	var parry := float(Emphasis.for_parry()["seconds"])
	var heaviest := float(
		Emphasis.for_hit(true, true, true, (load(HEAVIEST_ATTACK) as AttackData).hitstop)["seconds"]
	)
	if parry < heaviest:
		_fail(
			(
				(
					"the perfect parry stops for %.3f s and the heaviest blow in the game stops for "
					+ "%.3f s — the parry is supposed to be the longest"
				)
				% [parry, heaviest]
			)
		)


## The ceiling, applied to the worst case that can be built out of the `.tres` files rather than to
## a figure this check invented.
##
## The frame count is **written out and asserted first**. Reading `MOST_FRAMES` to build the bound
## made this pass with the ceiling raised to a full second, because the expectation moved with the
## thing it was supposed to be holding — a check that takes its bound from the class it is checking
## agrees with whatever that class says.
func _check_no_blow_may_pass_the_ceiling() -> void:
	if Emphasis.MOST_FRAMES != EXPECTED_CEILING:
		_fail(
			(
				(
					"the ceiling is %d frames and this check was written for %d — move it deliberately "
					+ "or not at all"
				)
				% [Emphasis.MOST_FRAMES, EXPECTED_CEILING]
			)
		)
		return
	var ceiling := float(EXPECTED_CEILING) * Emphasis.FRAME
	var heaviest := 0.0
	for file_name: String in DirAccess.get_files_at("res://data/attacks"):
		var attack := load("res://data/attacks/%s" % file_name.trim_suffix(".remap")) as AttackData
		if attack == null:
			continue
		heaviest = maxf(heaviest, attack.hitstop)
		var spent := float(Emphasis.for_hit(true, true, true, attack.hitstop)["seconds"])
		if spent > ceiling + 0.001:
			_fail("%s spends %.3f s, past the %.3f s ceiling" % [file_name, spent, ceiling])
	if not is_equal_approx(heaviest, HEAVIEST_SECONDS):
		_fail(
			(
				"the heaviest attack stops for %.3f s and this check was written for %.3f s"
				% [heaviest, HEAVIEST_SECONDS]
			)
		)


## The constraint the issue calls non-negotiable. The camera is fixed so that a wind-up can never be
## hidden; a screen that jumps while a farmer commits hands that back.
func _check_a_telegraph_in_shot_refuses_every_knock() -> void:
	var farmer := await _a_farmer_winding_up_at(_in_front_of_the_player())
	if farmer == null:
		return
	_rig.shake_left()
	EventBus.shake_requested.emit(1.0)
	await get_tree().process_frame
	if _rig.shake_left() > 0.0:
		_fail(
			(
				"the camera took %.2f of a knock while a farmer in shot was winding up"
				% _rig.shake_left()
			)
		)
	farmer.retire()
	await get_tree().physics_frame


## And the other half, or the rule would be "never shake", which is not a budget — it is giving up.
##
## Well past the blind side rather than a few metres behind the player: `verify_view` measures the
## ground staying in shot 8.5 m down-screen at the resting zoom, and the first version of this stood
## a farmer at five and had him refuse a knock he could plainly be seen to deserve.
func _check_a_telegraph_behind_the_player_refuses_nothing() -> void:
	var away := _player.global_position - (_camera_offset() * OUT_OF_SHOT)
	var farmer := await _a_farmer_winding_up_at(away)
	if farmer == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.is_position_in_frustum(farmer.global_position + Vector3.UP):
		_fail("the farmer meant to be off screen is in shot, so this check tested nothing")
		farmer.retire()
		return
	EventBus.shake_requested.emit(1.0)
	await get_tree().process_frame
	if _rig.shake_left() <= 0.0:
		_fail("a farmer winding up off screen refused a knock it has no business refusing")
	farmer.retire()
	await get_tree().physics_frame


## A press swallowed by a freeze reads as a dropped input and the player is right to blame the game.
## The buffer ages on the same scaled clock the stop slows, so a stop leaves a press **younger** in
## real time — the opposite of eating it.
##
## The state machine is stood down for both halves. Left running, `Idle` picks the press up on the
## very next frame and turns it into a swing, and the buffer is then empty for the best possible
## reason — which is how the first version of this check reported a bug that was not there.
func _check_a_stop_never_eats_a_press() -> void:
	Settings.set_value(&"access_hitstop", true)
	_player.machine.process_mode = Node.PROCESS_MODE_DISABLED
	_player.press_attack()
	EventBus.hitstop_requested.emit(float(Emphasis.MOST_FRAMES) * Emphasis.FRAME)
	await get_tree().process_frame
	if is_equal_approx(Engine.time_scale, 1.0):
		_fail("the hitstop never slowed the clock, so nothing about it was tested")
		_player.machine.process_mode = Node.PROCESS_MODE_INHERIT
		return
	# Real seconds, not scaled: the question is what the player experiences.
	await get_tree().create_timer(OUTLIVES_THE_BUFFER, true, false, true).timeout
	if not _player.buffered_attack_press():
		_fail(
			(
				"a press was gone %.0f ms into a hitstop, and the buffer is %.0f ms of game time"
				% [OUTLIVES_THE_BUFFER * 1000.0, Player.INPUT_BUFFER * 1000.0]
			)
		)
	while not is_equal_approx(Engine.time_scale, 1.0):
		await get_tree().process_frame
	await _check_the_buffer_still_expires_without_one()
	_player.machine.process_mode = Node.PROCESS_MODE_INHERIT


## Or the check above would pass on a buffer that never expires at all, which is not a buffer.
func _check_the_buffer_still_expires_without_one() -> void:
	_player.press_attack()
	await get_tree().create_timer(OUTLIVES_THE_BUFFER, true, false, true).timeout
	if _player.buffered_attack_press():
		_fail(
			(
				"a press survived %.0f ms with the clock running normally, and the buffer is %.0f ms"
				% [OUTLIVES_THE_BUFFER * 1000.0, Player.INPUT_BUFFER * 1000.0]
			)
		)


## The comment beside the old shake call said "on the three finishers **and on taking damage**", and
## taking damage shook nothing at all — the code had been describing a design it did not implement.
## It is the loudest figure in the table now, and this is what stops it going quiet again.
func _check_taking_a_hit_is_the_loudest_thing_that_happens() -> void:
	_player.machine.current.transition_to(&"Idle")
	if _player.health != null:
		_player.health.make_invulnerable(0.0)
	await get_tree().physics_frame
	_rig.settle()
	var swing := load(FARMHAND_SWING) as AttackData
	_player.hurtbox.take_hit(HitInfo.new(swing, null, false, 1.0))
	await get_tree().process_frame
	if _rig.shake_left() <= 0.0:
		_fail("the player took a swing to the face and the camera did not move")


## A shake that never settles is a camera that never stops moving, and the whole argument for a
## fixed angle is that a silhouette reads the same way every time. `SHAKE_DECAY` set to a
## thousandth passed every check in the project.
func _check_a_knock_dies_away() -> void:
	_rig.settle()
	EventBus.shake_requested.emit(1.0)
	await get_tree().process_frame
	if _rig.shake_left() <= 0.0:
		_fail("the knock never landed, so nothing about it settling was tested")
		return
	await get_tree().create_timer(SETTLES_WITHIN, true, false, true).timeout
	if _rig.shake_left() > STILL_SHAKING:
		_fail(
			(
				"%.1f s after a knock the camera is still shaking at %.3f"
				% [SETTLES_WITHIN, _rig.shake_left()]
			)
		)


## A farmer stood at a spot and pushed into his wind-up, or null with a failure already recorded.
func _a_farmer_winding_up_at(where: Vector3) -> Enemy:
	var director := _arena.get_node_or_null(^"WaveDirector/SpawnDirector") as SpawnDirector
	var data := load(FARMHAND) as EnemyData
	if director == null or data == null:
		_fail("no farmer could be stood up")
		return null
	var farmer := director.spawn_at(data, where, 1.0, 1.0, 1.0, 1.0, null, false)
	if farmer == null or farmer.machine == null:
		_fail("no farmer could be stood up")
		return null
	farmer.machine.current.transition_to(&"WindUp")
	await get_tree().physics_frame
	if not farmer.machine.current is EnemyWindUp:
		_fail("the farmer would not wind up, so nothing about telegraphs was tested")
		farmer.retire()
		return null
	return farmer


## A point the camera is plainly looking at: along its own line of sight, on the far side of the
## player from the eye.
func _in_front_of_the_player() -> Vector3:
	return _player.global_position + _camera_offset() * IN_SHOT


func _camera_offset() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.FORWARD
	var away := _player.global_position - camera.global_position
	away.y = 0.0
	return away.normalized()


func _stand_the_tutorial_down(arena: Node) -> void:
	var tutorial := arena.get_node_or_null(^"TutorialDirector") as TutorialDirector
	if tutorial != null:
		tutorial.stand_down()


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print("feel OK — one blow spends once, no knock lands over a telegraph, no press is eaten")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
