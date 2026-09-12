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
	_check_the_cycles_loop(anim)
	await _check_move_walks(machine, anim)
	await _check_walking_outlasts_one_cycle(machine, anim)
	await _check_idle_plays_idle(machine, anim)
	await _check_clipless_state_rests(anim)
	_check_the_body_can_be_tinted(player)
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


## glTF carries no looping flag, so Godot imports every clip as a one-shot unless the `.import` says
## otherwise. A walk cycle imported that way plays once and freezes mid-stride while the machine
## still reports `Move` — no error, no warning, and `is_playing()` is true for the whole first
## cycle, which is why every other check here passed while the character stood still on screen.
##
## The setting lives in `_subresources` of `assets/models/char_player.glb.import`; a reimport that
## loses it brings the bug straight back, so it is asserted rather than trusted.
func _check_the_cycles_loop(anim: AnimationComponent) -> void:
	if anim.animation_player == null:
		return
	for clip: String in ["walk", "idle"]:
		var cycle := anim.animation_player.get_animation(clip)
		if cycle == null:
			continue
		if cycle.loop_mode == Animation.LOOP_NONE:
			_fail("%s does not loop — it plays once and the character freezes mid-cycle" % clip)
	var hurt := anim.animation_player.get_animation("hurt")
	if hurt != null and hurt.loop_mode != Animation.LOOP_NONE:
		_fail("hurt loops, but a reaction has to play once and end")


## The symptom itself rather than the setting behind it: keep walking for longer than the cycle
## lasts and the legs must still be moving.
func _check_walking_outlasts_one_cycle(machine: StateMachine, anim: AnimationComponent) -> void:
	var cycle := anim.animation_player.get_animation("walk")
	if cycle == null:
		return
	Input.action_press(&"move_forward")
	var elapsed := 0.0
	while elapsed < cycle.length + 0.5:
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
	var still_walking := anim.animation_player.is_playing()
	var where := anim.animation_player.current_animation_position
	Input.action_release(&"move_forward")
	await get_tree().physics_frame
	if machine.current_name != &"Move":
		return
	if not still_walking:
		_fail(
			(
				"the walk stopped after one %.2fs cycle, frozen at %.2fs, while the state was still Move"
				% [cycle.length, where]
			)
		)


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
	anim.clip_missing.connect(
		func(state: StringName, _clip: StringName) -> void: missing.append(state)
	)
	var played := anim.play_state(&"Sprint")
	await get_tree().physics_frame
	if played:
		_fail("Sprint reports a clip, so this check is no longer testing a clipless state")
	if anim.current_clip() != &"":
		_fail("Sprint has no clip yet but the component reports %s" % [anim.current_clip()])
	if missing.is_empty():
		_fail("a state with no clip should emit clip_missing")


## `HitFeedback` drains the body's colour while a chain is spent, and it lives in `main.tscn` — so
## nothing that loads only the arena instantiates it, and the day the capsule became a rig the
## property it reached through vanished with no test to notice. This is that test.
##
## Both halves matter. Empty means the feedback silently does nothing. Materials shared with the
## imported rig mean tinting the player drains every other character built on the same glTF.
func _check_the_body_can_be_tinted(player: Player) -> void:
	var materials := player.body_materials()
	if materials.is_empty():
		_fail("the body exposes no materials to tint — HitFeedback has nothing to drain")
		return
	var meshes: Array[MeshInstance3D] = []
	for node: Node in player.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	for mesh: MeshInstance3D in meshes:
		for surface: int in mesh.get_surface_override_material_count():
			var override := mesh.get_surface_override_material(surface)
			if override == null:
				continue
			if mesh.mesh.surface_get_material(surface) == override:
				_fail(
					"surface %d of %s is tinted in place, not through a copy" % [surface, mesh.name]
				)
	# Handing back a fresh set each call would leave the tween animating materials nothing draws.
	if player.body_materials() != materials:
		_fail("body_materials() hands back a different set each call")


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	for _index: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	if _failures.is_empty():
		print(
			(
				"animation OK — walk, idle and hurt on the rig, the cycles loop, Move walks "
				+ "past one cycle, Idle idles, Sprint rests, the body can be tinted"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
