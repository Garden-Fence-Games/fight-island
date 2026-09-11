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

	if anim.animation_player != null:
		if not anim.animation_player.has_animation("walk"):
			_fail(
				(
					"the rig carries no clip named walk — has %s"
					% [anim.animation_player.get_animation_list()]
				)
			)

	var machine := player.get_node("StateMachine") as StateMachine
	await _check_move_walks(machine, anim)
	await _check_clipless_state_rests(machine, anim)
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


## Every clip but walk is still unexported, so this is the ordinary case rather than an edge one.
## The guard is that it stays silent: the import gate in CI fails on any WARNING line.
func _check_clipless_state_rests(machine: StateMachine, anim: AnimationComponent) -> void:
	var missing: Array[StringName] = []
	anim.clip_missing.connect(func(state: StringName, _clip: StringName) -> void:
		missing.append(state))
	machine.current.transition_to(&"Idle")
	await get_tree().physics_frame
	if anim.current_clip() != &"":
		_fail("Idle has no clip yet but the component reports %s" % [anim.current_clip()])
	if missing.is_empty():
		_fail("a state with no clip should emit clip_missing")


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	for _index: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	if _failures.is_empty():
		print("animation OK — rig found, walk on the rig, Move walks, clipless state rests")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
