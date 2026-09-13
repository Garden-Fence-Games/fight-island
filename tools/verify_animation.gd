extends Node
## Headless proof that the player's rig is wired to its states: the component finds the
## AnimationPlayer the importer produced, the walk cycle is on the rig under the name the pipeline
## promises, entering Move plays it, and a state with no clip falls back to rest instead of holding
## the last frame.
## Runs as a scene rather than with --script, because --script starts no autoloads and the player
## talks to the EventBus.
## Run: godot --headless --path . res://tools/verify_animation.tscn

const PLAYER: String = "res://scenes/actors/player.tscn"
const ENEMY: String = "res://scenes/actors/enemy.tscn"
const SETTLE_FRAMES: int = 8
## How far the footfall rate may sit from the cycle's own, in steps per second. A tenth of a step
## is inaudible; half a step is the difference between a walk and a jog.
const FOOTFALL_SLACK: float = 0.12

var _failures: PackedStringArray = []
var _kept_run: Dictionary = {}


func _ready() -> void:
	_run()


func _run() -> void:
	# From a fresh run, and the machine's own run put back at the end. `GameState` restores a saved
	# run at boot, so a developer who has picked the gun up would start this check holding it — and
	# then every punch is a shot with an empty magazine, and the gun mesh is visible on purpose.
	_kept_run = SaveManager.read_json(SaveManager.RUN_PATH)
	GameState.begin_run()
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
	await _check_sprint_runs_the_walk_faster(anim)
	await _check_a_gun_in_hand_changes_the_cycle(machine, anim)
	_check_the_body_can_be_tinted(player)
	await _check_the_fist_combo_animates(player, machine, anim)
	await _check_the_dodge_rolls(machine, anim)
	_check_the_gun_starts_hidden(player)
	_check_the_footsteps_keep_the_cycles_time(anim)
	await _check_the_farmer_animates()
	_report()


## **The sound of walking has to be the walk you are watching.** The footfall is emitted per metre
## of ground covered, which is a figure that cannot see the clip — so it drifted: 0.95 m of stride
## against a 1.017 s cycle is 202 footfalls a minute under an animation putting down 118, and what
## the player hears is somebody jogging while the character strolls.
##
## Asserted against the clip rather than against a number, so re-exporting the cycle at a different
## length fails here instead of quietly running the sound fast again.
func _check_the_footsteps_keep_the_cycles_time(anim: AnimationComponent) -> void:
	if anim.animation_player == null or not anim.animation_player.has_animation("walk"):
		_fail("there is no walk cycle to time the footsteps against")
		return
	var cycle := anim.animation_player.get_animation("walk").length
	if cycle <= 0.0:
		_fail("the walk cycle has no length")
		return
	var the_clip := Player.FOOTFALLS_PER_CYCLE / cycle
	var the_sound := Player.MOVE_SPEED / Player.STRIDE
	if absf(the_sound - the_clip) > FOOTFALL_SLACK:
		_fail(
			(
				(
					"the legs put down %.0f steps a minute and the sound plays %.0f — a stride of "
					+ "%.2f m against a %.3f s cycle"
				)
				% [the_clip * 60.0, the_sound * 60.0, Player.STRIDE, cycle]
			)
		)


## The states a farmer is actually in while a wave is running have to name a clip the rig carries.
##
## This exists because a missing clip is deliberately silent — the rig arrives one animation at a
## time and a component that complained would turn main red for it. The cost of that silence is that
## a **typo** in the map looks exactly like a clip nobody has authored yet: `Chase` pointed at
## `walk_attack` for a rig whose clip is called `chase`, and the farmer walked at you without moving
## a leg, with nothing in the log.
##
## Only Idle and Chase, on purpose. The attack, stagger and death clips are genuinely unwritten, and
## asserting those would be asserting the calendar rather than the wiring.
func _check_the_farmer_animates() -> void:
	var farmer := (load(ENEMY) as PackedScene).instantiate() as Enemy
	add_child(farmer)
	await get_tree().physics_frame
	var anim := farmer.get_node_or_null("Animation") as AnimationComponent
	if anim == null:
		_fail("the farmer carries no AnimationComponent")
		farmer.queue_free()
		return
	if anim.animation_player == null:
		_fail("the farmer's component found no AnimationPlayer")
		farmer.queue_free()
		return
	for state: StringName in [&"Idle", &"Chase"]:
		farmer.machine.current.transition_to(state)
		await get_tree().physics_frame
		if anim.current_clip() == &"":
			_fail(
				(
					"the farmer plays nothing in %s — the map names %s and the rig carries %s"
					% [
						state,
						anim.clips.get(state, &""),
						anim.animation_player.get_animation_list()
					]
				)
			)
	farmer.queue_free()


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


## Dodge, Parry and Dead have no clip yet, which is the ordinary state of a rig that arrives one
## animation at a time rather than an edge case. Driven through `play_state` rather than a real
## transition so the check does not depend on which clips happen to exist this week.
## The guard is that it stays silent: the gate in CI fails on any WARNING line.
func _check_clipless_state_rests(anim: AnimationComponent) -> void:
	var missing: Array[StringName] = []
	anim.clip_missing.connect(
		func(state: StringName, _clip: StringName) -> void: missing.append(state)
	)
	# Parry, since the dodge got its roll. When `parry` lands on the rig this fails on purpose, and the
	# next state still waiting for its clip takes the job.
	var played := anim.play_state(&"Parry")
	await get_tree().physics_frame
	if played:
		_fail("Parry reports a clip, so this check is no longer testing a clipless state")
	if anim.current_clip() != &"":
		_fail("Parry has no clip yet but the component reports %s" % [anim.current_clip()])
	if missing.is_empty():
		_fail("a state with no clip should emit clip_missing")


## Sprint borrows the walk cycle played faster, so the two states share a clip and differ only by
## speed. That is exactly the case a "has the clip changed?" check would miss, leaving a sprinting
## player strolling — so this asserts the speed, not just the name.
func _check_sprint_runs_the_walk_faster(anim: AnimationComponent) -> void:
	var walk: StringName = anim.clips.get(&"Move", &"")
	var sprint: StringName = anim.clips.get(&"Sprint", &"")
	if sprint != walk:
		_fail(
			(
				"Sprint plays %s and Move plays %s — this check assumes they share a clip"
				% [sprint, walk]
			)
		)
		return
	anim.play_state(&"Move")
	await get_tree().physics_frame
	var walking := anim.animation_player.get_playing_speed()
	anim.play_state(&"Sprint")
	await get_tree().physics_frame
	var running := anim.animation_player.get_playing_speed()
	if anim.current_clip() != sprint:
		_fail("Sprint plays %s, expected %s" % [anim.current_clip(), sprint])
		return
	var wanted: float = anim.clip_speeds.get(&"Sprint", 1.0)
	if not is_equal_approx(running, walking * wanted):
		_fail(
			(
				"sprinting runs the cycle at %.2f, walking at %.2f — expected %.1f times faster"
				% [running, walking, wanted]
			)
		)


## The gun is modelled into the skeleton, so `walk_gun` and `idle_gun` are the same body carrying
## it. Four claims, and the last two are the ones that would rot quietly:
##
## The swap lands **while the player is already walking**, without waiting for a transition. And a
## variant the rig does not carry falls back to the plain clip rather than to nothing — the stick
## has no cycles of its own, and a weapon with a walk authored and no idle must still have an idle.
func _check_a_gun_in_hand_changes_the_cycle(
	machine: StateMachine, anim: AnimationComponent
) -> void:
	var gun := load("res://data/weapons/gun.tres") as WeaponData
	if gun == null or gun.clip_suffix == &"":
		_fail("the gun should name a locomotion suffix")
		return
	for clip: String in ["walk_gun", "idle_gun"]:
		if not anim.animation_player.has_animation(clip):
			_fail("the rig carries no clip named %s" % clip)
			return

	Input.action_press(&"move_forward")
	await get_tree().physics_frame
	await get_tree().physics_frame
	if anim.current_clip() != &"walk":
		_fail("empty-handed walking plays %s, expected walk" % anim.current_clip())

	# Equipped mid-stride: the stride has to change here, not at the next transition.
	EventBus.weapon_equipped.emit(gun)
	await get_tree().physics_frame
	if machine.current_name != &"Move":
		_fail("picking a gun up should not have left Move, went to %s" % machine.current_name)
	if anim.current_clip() != &"walk_gun":
		_fail("walking with a gun plays %s, expected walk_gun" % anim.current_clip())

	Input.action_release(&"move_forward")
	for _frame: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	if anim.current_clip() != &"idle_gun":
		_fail("standing with a gun plays %s, expected idle_gun" % anim.current_clip())

	# A suffix the rig knows nothing about must not silence the body.
	anim.clip_suffix = &"_hoe"
	await get_tree().physics_frame
	if anim.current_clip() != &"idle":
		_fail("an unauthored variant plays %s, expected a fallback to idle" % anim.current_clip())

	var fists := load("res://data/weapons/fists.tres") as WeaponData
	EventBus.weapon_equipped.emit(fists)
	await get_tree().physics_frame
	if anim.current_clip() != &"idle":
		_fail("back to fists plays %s, expected idle" % anim.current_clip())


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


## The three punches are one state driven by three `AttackData`, so no table maps `Attack` to a
## clip — the state names its own. This drives each index and reads back which clip started.
##
## It also checks the stretch. The windows in the `.tres` are balance and the clip bends to them, so
## a jab whose clip runs at its authored speed would have the fist out a frame late for ever.
func _check_the_fist_combo_animates(
	player: Player, machine: StateMachine, anim: AnimationComponent
) -> void:
	var weapon := player.weapon
	if weapon == null:
		_fail("the player carries no weapon, so the combo cannot be checked")
		return
	for index: int in 3:
		var attack := weapon.attack_at(index)
		if attack == null:
			_fail("the fists have no attack at index %d" % index)
			continue
		machine.current.transition_to(&"Attack", {"index": index, "perfect": false})
		await get_tree().physics_frame
		if machine.current_name != &"Attack":
			_fail("attack %d left the machine in %s" % [index, machine.current_name])
			continue
		if anim.current_clip() != attack.animation:
			_fail(
				(
					"attack %d (%s) plays %s, its AttackData names %s"
					% [index, attack.id, anim.current_clip(), attack.animation]
				)
			)
			continue
		var clip := anim.animation_player.get_animation(String(attack.animation))
		var wanted := clip.length / attack.total_duration()
		if not is_equal_approx(anim.animation_player.get_playing_speed(), wanted):
			_fail(
				(
					"%s runs at %.3f, it has to run at %.3f to last the attack's %.3fs"
					% [
						attack.animation,
						anim.animation_player.get_playing_speed(),
						wanted,
						attack.total_duration()
					]
				)
			)
		machine.current.transition_to(&"Idle")
		await get_tree().physics_frame


## The dodge rolls, over exactly the dodge. The clip is authored longer than the state lasts, so at
## its own rate the body would still be mid-roll when control comes back; and a roll that looped
## would start a second one on the last frame of a dodge nobody asked to repeat.
func _check_the_dodge_rolls(machine: StateMachine, anim: AnimationComponent) -> void:
	if not anim.animation_player.has_animation("dodge_roll"):
		_fail("the rig has no dodge_roll clip")
		return
	machine.current.transition_to(&"Dodge")
	await get_tree().physics_frame
	if machine.current_name != &"Dodge":
		_fail("a dodge left the machine in %s" % machine.current_name)
		return
	if anim.current_clip() != &"dodge_roll":
		_fail("the dodge plays %s, expected dodge_roll" % anim.current_clip())
	var clip := anim.animation_player.get_animation("dodge_roll")
	if clip.loop_mode != Animation.LOOP_NONE:
		_fail("dodge_roll loops, so a held dodge would roll twice")
	var wanted := clip.length / PlayerDodge.DURATION
	if not is_equal_approx(anim.animation_player.get_playing_speed(), wanted):
		_fail(
			(
				"dodge_roll runs at %.3f, it has to run at %.3f to last the dodge's %.2fs"
				% [anim.animation_player.get_playing_speed(), wanted, PlayerDodge.DURATION]
			)
		)
	# Let the roll finish on its own rather than cutting it: entering a dodge plays the roll sound,
	# and a check that quits while it is still sounding leaks the playback at exit.
	var waited := 0
	while machine.current_name == &"Dodge" and waited < 120:
		await get_tree().physics_frame
		waited += 1
	for _index: int in 30:
		await get_tree().physics_frame


## The gun is modelled into the rig rather than attached at runtime, so it is in the character's
## hand from the first frame unless something hides it — including through all three punches.
func _check_the_gun_starts_hidden(player: Player) -> void:
	var visuals := player.get_node_or_null("WeaponVisual") as WeaponVisualComponent
	if visuals == null:
		_fail("the player carries no WeaponVisualComponent")
		return
	if not visuals.has_weapon_mesh():
		_fail("no weapon mesh was found on the rig — the name in weapon_mesh_names has drifted")
		return
	for node: Node in player.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh != null and visuals.weapon_mesh_names.has(StringName(mesh.name)) and mesh.visible:
			_fail("%s is visible while the player is unarmed" % mesh.name)


func _fail(message: String) -> void:
	_failures.append(message)


func _put_the_run_back() -> void:
	if _kept_run.is_empty():
		SaveManager.clear_run()
		return
	SaveManager.write_json(SaveManager.RUN_PATH, _kept_run)


func _report() -> void:
	_put_the_run_back()
	for _index: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	if _failures.is_empty():
		print(
			(
				"animation OK — the cycles loop, Move walks past one cycle, Idle idles, "
				+ "Sprint runs the same cycle faster, "
				+ "the three punches play their own clip at the attack's speed, "
				+ "the dodge rolls over exactly the dodge, "
				+ "a gun in hand carries the body differently, "
				+ "the gun stays hidden, the body can be tinted, the footsteps keep the cycle's "
				+ "time, the farmer walks and idles"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
