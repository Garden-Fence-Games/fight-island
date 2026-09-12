extends Node
## Headless proof that the player's rig is wired to its states: the component finds the
## AnimationPlayer the importer produced, the walk cycle is on the rig under the name the pipeline
## promises, entering Move plays it, and a state with no clip falls back to rest instead of holding
## the last frame.
## Runs as a scene rather than with --script, because --script starts no autoloads and the player
## talks to the EventBus.
## Run: godot --headless --path . res://tools/verify_animation.tscn

const PLAYER: String = "res://scenes/actors/player.tscn"
const SETTLE_FRAMES: int = 8

var _failures: PackedStringArray = []


func _ready() -> void:
	_run()


func _run() -> void:
	var player := (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(player)
	await get_tree().physics_frame

	var anim := player.get_node_or_null("Animation") as AnimationComponent
	if anim == null:
		_fail("the player carries no AnimationComponent")
		_report()
		return

	# Left null in the scene on purpose: the component looks them up, so a reimport that renames the
	# glTF nodes does not silently unwire the rig. That lookup is the thing worth guarding.
	if anim.animation_player == null:
		_fail("the component did not find an AnimationPlayer under the player")
	if anim.state_machine == null:
		_fail("the component did not find a StateMachine under the player")

	# The clips exported so far. Each is named by the contract in docs/asset-pipeline.md, and the
	# usual way one goes missing is an action still called "mixamo.com" in the .blend.
	if anim.animation_player != null:
		for clip: String in ["walk", "idle", "hurt"]:
			if not anim.animation_player.has_animation(clip):
				_fail(
					(
						"the rig carries no clip named %s — it has %s"
						% [clip, anim.animation_player.get_animation_list()]
					)
				)

	var machine := player.get_node("StateMachine") as StateMachine
	await _check_move_walks(machine, anim)
	await _check_idle_plays_idle(machine, anim)
	await _check_clipless_state_rests(anim)
	_report()


## Driven by a real press rather than by calling `transition_to`, because `Move` sends itself back
## to `Idle` the instant the stick is centred — a test that only transitions measures `Idle` one
## frame later and blames the rig for it.
func _check_move_walks(machine: StateMachine, anim: AnimationComponent) -> void:
	Input.action_press(&"move_forward")
	await get_tree().physics_frame
	await get_tree().physics_frame
	if machine.current_name != &"Move":
		_fail("holding move_forward left the machine in %s" % [machine.current_name])
	elif anim.current_clip() != &"walk":
		_fail("Move plays %s, expected walk" % [anim.current_clip()])
	elif not anim.animation_player.is_playing():
		_fail("Move selected walk but the AnimationPlayer is not playing")
	Input.action_release(&"move_forward")
	await get_tree().physics_frame


## Letting go has to land back on the idle cycle rather than freezing on the last stride.
func _check_idle_plays_idle(machine: StateMachine, anim: AnimationComponent) -> void:
	for _index: int in 4:
		await get_tree().physics_frame
	if machine.current_name != &"Idle":
		_fail("releasing the keys left the machine in %s" % [machine.current_name])
	elif anim.current_clip() != &"idle":
		_fail("Idle plays %s, expected idle" % [anim.current_clip()])


## Sprint, Dodge, Parry and Dead have no clip yet, which is the ordinary state of a rig that arrives
## one animation at a time rather than an edge case. Driven through `play_state` rather than a real
## transition so the check does not depend on which clips happen to exist this week.
## The guard is that it stays silent: the gate in CI fails on any WARNING line.
func _check_clipless_state_rests(anim: AnimationComponent) -> void:
	var missing: Array[StringName] = []
	anim.clip_missing.connect(func(state: StringName, _clip: StringName) -> void:
		missing.append(state))
	var played := anim.play_state(&"Sprint")
	await get_tree().physics_frame
	if played:
		_fail("Sprint reports a clip, so this check is no longer testing a clipless state")
	if anim.current_clip() != &"":
		_fail("Sprint has no clip yet but the component reports %s" % [anim.current_clip()])
	if missing.is_empty():
		_fail("a state with no clip should emit clip_missing")


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	for _index: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	if _failures.is_empty():
		print("animation OK — walk, idle and hurt on the rig, Move walks, Idle idles, Sprint rests")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
