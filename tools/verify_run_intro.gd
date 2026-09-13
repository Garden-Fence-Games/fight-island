extends Node
## Proof that a run begun from the title opens on the player waking up, whole, and hands the game
## back exactly where it would have started — and that no other run does.
## Run: godot --headless --path . res://tools/verify_run_intro.tscn

const RUN_SCENE: String = "res://scenes/main/main.tscn"
const CLIP: StringName = &"new_run_awakening"
## How close the turn's last point must land to the game camera, in metres. The whole point of the
## orbit ending there is that nothing is cut to.
const SAME_PLACE: float = 0.05

var _failures: PackedStringArray = []


func _ready() -> void:
	_run()


func _run() -> void:
	await _check_a_title_run_opens_and_gives_the_game_back()
	await _check_no_other_run_opens()
	_report()


func _check_a_title_run_opens_and_gives_the_game_back() -> void:
	GameState.begin_run(true)
	var main := (load(RUN_SCENE) as PackedScene).instantiate()
	add_child(main)
	for _i: int in 4:
		await get_tree().process_frame
	var opening := main.get_node_or_null(^"RunIntro") as RunIntro
	if opening == null:
		_fail("a run begun from the title did not open on the awakening")
		main.queue_free()
		return
	if GameState.intro_owed:
		_fail("the opening played and the run still owes one, so a reload would play it again")
	var player := main.get_node(^"Arena/Player") as Player
	var rig := main.get_node(^"Arena/CameraRig") as CameraRig
	var waves := main.get_node(^"Arena/WaveDirector")
	var hud := main.get_node_or_null(^"Hud") as CanvasLayer

	if player.machine.process_mode != Node.PROCESS_MODE_DISABLED:
		_fail("the player's state machine runs during the opening, so it can be skipped by moving")
	if player.head_look != null and not player.head_look.resting:
		_fail("the head follows the aim while the player is still waking up")
	if waves.process_mode != Node.PROCESS_MODE_DISABLED:
		_fail("the waves count down during the opening")
	if hud != null and hud.visible:
		_fail("the HUD is up during the opening")
	if player.animation != null and player.animation.current_clip() != CLIP:
		_fail("the opening plays %s rather than %s" % [player.animation.current_clip(), CLIP])
	if get_viewport().get_camera_3d() == rig.camera:
		_fail("the game camera is already current, so there is no turn")
	var ends_at: Vector3 = opening._orbit(1.0).origin
	if ends_at.distance_to(rig.camera.global_position) > SAME_PLACE:
		_fail(
			(
				"the turn ends %.2f m from the game camera, so the opening cuts instead of arriving"
				% ends_at.distance_to(rig.camera.global_position)
			)
		)

	var clip := player.animation.animation_player.get_animation(CLIP)
	var allowed := (clip.length if clip != null else 0.0) + opening.intro.settle_seconds + 2.0
	var waited := 0.0
	while is_instance_valid(opening) and waited < allowed:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if is_instance_valid(opening):
		_fail("the opening was still holding the player %.1f s in" % waited)
		main.queue_free()
		return
	if clip != null and waited < clip.length:
		_fail(
			(
				"the opening ended after %.2f s, before its %.2f s clip had played"
				% [waited, clip.length]
			)
		)
	if player.machine.process_mode == Node.PROCESS_MODE_DISABLED:
		_fail("the player never got the body back")
	if player.head_look != null and player.head_look.resting:
		_fail("the head stayed still after the opening")
	if waves.process_mode == Node.PROCESS_MODE_DISABLED:
		_fail("the waves never started after the opening")
	if hud != null and not hud.visible:
		_fail("the HUD never came back")
	if get_viewport().get_camera_3d() != rig.camera:
		_fail("the game camera is not the current one after the opening")
	main.queue_free()
	await get_tree().process_frame


## A retry, a restart, a resume and every check that begins a run: straight into the game.
func _check_no_other_run_opens() -> void:
	GameState.begin_run()
	var main := (load(RUN_SCENE) as PackedScene).instantiate()
	add_child(main)
	for _i: int in 4:
		await get_tree().process_frame
	if main.get_node_or_null(^"RunIntro") != null:
		_fail("a run not begun from the title opened on the awakening")
	var player := main.get_node(^"Arena/Player") as Player
	if player.machine.process_mode == Node.PROCESS_MODE_DISABLED:
		_fail("a run with no opening left the player without a body")
	main.queue_free()
	await get_tree().process_frame


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	GameState.end_run()
	if _failures.is_empty():
		print(
			(
				"run intro OK — a title run wakes the player up whole, turns once and lands on the "
				+ "game camera, and hands everything back; no other run opens"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr("run intro FAILED — %s" % failure)
	get_tree().quit(1)
