extends Node
## Headless proof that the sea costs health, that it kills, and that it does neither on the beach.
##
## Drowning is the one thing in the game that can end a run **without a fight** — nothing swung, no
## telegraph, no parry to miss. So the two halves worth holding are opposite: it has to happen at
## the depth `data/combat/tide.tres` says, and it must not happen anywhere shallower.
##
## Driven by putting the body at a height rather than by walking it into the sea. Walking is the
## player's problem and it is `PlayableArea`'s push that decides how far they get; what is asserted
## here is what the water does to whoever is standing in it.
## Run: godot --headless --path . res://tools/verify_drowning.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
const TIDE: String = "res://data/combat/tide.tres"
## How long the body is held under before the bar is read. Longer than the five seconds a full bar
## takes at the deepest, so the death has happened by the end of it whatever the figures say.
const HELD_UNDER: float = 7.0
## Frames given to a reading, so a drain that runs per physics frame has run.
const A_FEW_FRAMES: int = 8
## How far under the wading limit "on the beach" is. Ankle deep, where the sea costs speed and
## nothing else.
const ANKLE_DEEP: float = 0.2
## How long the forcing comparison holds each way, and how much more forcing must cost by the end
## of it. At one doubling a second, a second and a half of forcing costs about 2.6 times the still
## rate, so 1.5 is a margin rather than the curve.
const FORCING_FOR: float = 1.5
const FORCING_AT_LEAST: float = 1.5

var _failures: PackedStringArray = []
var _died: bool = false
var _player: Player = null
var _tide: TideData = null
var _water: float = -1.1


func _ready() -> void:
	_run()


func _run() -> void:
	var arena := (load(ARENA) as PackedScene).instantiate()
	add_child(arena)
	var tutorial := arena.get_node_or_null(^"TutorialDirector") as TutorialDirector
	if tutorial != null:
		tutorial.stand_down()
	var waves := arena.get_node_or_null(^"WaveDirector") as WaveDirector
	if waves != null:
		waves.halt()
	await get_tree().physics_frame
	_player = arena.get_node_or_null(^"Player") as Player
	_tide = load(TIDE) as TideData
	if _player == null or _player.health == null or _tide == null:
		_fail("the arena holds no player with health, or there is no tide to read")
		_report()
		return
	_water = Water.level
	EventBus.player_died.connect(func() -> void: _died = true)

	_check_the_figures_are_sane()
	await _check_wading_costs_nothing()
	await _check_the_deep_takes_health()
	await _check_forcing_takes_it_faster(arena.get_node_or_null(^"Island/PlayableArea") as Node3D)
	await _check_it_drowns_him()
	_report()


## The two depths and the rate, held against each other rather than against numbers written twice.
## A tide that drained from deeper than it drowns at would drain nowhere, and nothing else here
## would notice: every check below would pass on a sea that does nothing.
func _check_the_figures_are_sane() -> void:
	if _tide.drains <= 0.0:
		_fail("the sea drains %.1f health a second, so it costs nothing" % _tide.drains)
	if _tide.drowns_at <= _tide.drains_from:
		_fail(
			(
				"the sea drains from %.2f m and is at full rate by %.2f — the ramp runs backwards"
				% [_tide.drains_from, _tide.drowns_at]
			)
		)
	if _tide.drains_from < PlayableArea.WADE_DEPTH:
		_fail(
			(
				(
					"the bar comes down at %.2f m and the sea only pushes back at %.2f — it costs "
					% [_tide.drains_from, PlayableArea.WADE_DEPTH]
				)
				+ "health before it warns"
			)
		)


## Ankle deep, it costs speed and nothing else. This is the half that stops the feature becoming a
## sea nobody may touch: the beach is a place the fight happens in.
func _check_wading_costs_nothing() -> void:
	var before := await _health_after(_water - PlayableArea.WADE_DEPTH + ANKLE_DEEP, 1.0)
	if before < _player.health.max_health:
		_fail("standing ankle deep cost %.1f health" % (_player.health.max_health - before))


## Past the limit, the bar comes down.
func _check_the_deep_takes_health() -> void:
	var left := await _health_after(_water - _tide.drowns_at, 1.0)
	var taken := _player.health.max_health - left
	if taken <= 0.0:
		_fail("a second under cost nothing")
		return
	# Within a frame or two of a second's worth, which is the figure doing the work rather than a
	# rate this check invented.
	if absf(taken - _tide.drains) > _tide.drains * 0.25:
		_fail("a second under took %.1f health, and the tide asks for %.1f" % [taken, _tide.drains])


## Walking out against the push drains the bar faster the longer it lasts, and only that: the same
## seconds at the same depth, standing still, cost the ordinary rate.
func _check_forcing_takes_it_faster(area: Node3D) -> void:
	if area == null:
		_fail("the island has no PlayableArea to read the forcing from")
		return
	var out_at_sea := area.global_position + Vector3(40.0, 0.0, 0.0)
	out_at_sea.y = _water - (_tide.drains_from + _tide.drowns_at) / 2.0
	var still := await _health_lost_out_at(out_at_sea, &"", FORCING_FOR)
	var outward := _action_heading_out_to_sea()
	if outward == &"":
		_fail("no movement action heads out to sea, so forcing cannot be driven")
		return
	var forcing := await _health_lost_out_at(out_at_sea, outward, FORCING_FOR)
	if still <= 0.0:
		_fail("standing still out of depth cost nothing")
		return
	if forcing < still * FORCING_AT_LEAST:
		_fail(
			(
				"%.1f s of forcing cost %.1f health against %.1f standing still — it is not taking it faster"
				% [FORCING_FOR, forcing, still]
			)
		)
	if not is_zero_approx(area.call("forcing_seconds")):
		_fail("the forcing clock did not reset once the player stopped heading out")


## The movement action that points most squarely out to sea from where the camera is.
func _action_heading_out_to_sea() -> StringName:
	var best := &""
	var best_dot := 0.5
	for action: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
		Input.action_press(action)
		var heading := _player.move_direction()
		Input.action_release(action)
		if heading.x > best_dot:
			best = action
			best_dot = heading.x
	return best


## Health lost over `seconds` at `where`, holding `action` down the whole time (none for &"").
func _health_lost_out_at(where: Vector3, action: StringName, seconds: float) -> float:
	_player.health.current_health = _player.health.max_health
	if action != &"":
		Input.action_press(action)
	var waited := 0.0
	while waited < seconds:
		_player.global_position = where
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	if action != &"":
		Input.action_release(action)
	# A frame with nothing held, so the clock has seen the push stop.
	_player.global_position = where
	await get_tree().physics_frame
	return _player.health.max_health - _player.health.current_health


## And it kills, through the same door every other death goes through.
func _check_it_drowns_him() -> void:
	_died = false
	await _health_after(_water - _tide.drowns_at, HELD_UNDER, true)
	if _player.health.is_alive():
		_fail(
			(
				"%.0f s under the surface left %.1f health"
				% [HELD_UNDER, _player.health.current_health]
			)
		)
	if not _died:
		_fail("the player drowned without the run being told — player_died never fired")
	await _check_he_struggles_rather_than_falls()


## A drowned player plays the `drowning` loop, and the ragdoll stays out of it: there is no blow to
## be thrown by and nothing to fall against in the sea. Whether a death counts as drowned is the
## tide's own depth, asked of both sides of it.
func _check_he_struggles_rather_than_falls() -> void:
	if not PlayerDead.is_out_of_depth(_water - _tide.drowns_at):
		_fail("a body at the depth the sea drowns at does not count as out of its depth")
	if PlayerDead.is_out_of_depth(_water - PlayableArea.WADE_DEPTH + ANKLE_DEEP):
		_fail("a body ankle deep counts as drowned, so a blow on the beach would play the struggle")
	for _index: int in A_FEW_FRAMES:
		await get_tree().physics_frame
	if _player.machine == null or _player.machine.current_name != &"Dead":
		_fail("the drowned player is not in the Dead state")
		return
	if _player.ragdoll != null and _player.ragdoll.is_running():
		_fail("the drowned player was handed to the ragdoll instead of struggling")
	var anim := _player.animation
	if anim == null or anim.current_clip() != PlayerDead.DROWNING_CLIP:
		_fail(
			(
				"the drowned player plays %s, expected %s"
				% [anim.current_clip() if anim != null else &"nothing", PlayerDead.DROWNING_CLIP]
			)
		)
		return
	var clip := anim.animation_player.get_animation(String(PlayerDead.DROWNING_CLIP))
	if clip.loop_mode == Animation.LOOP_NONE:
		_fail("the drowning clip does not loop, so he stops struggling before the summary arrives")
	await _check_he_goes_under_while_struggling()


## The loop keeps turning while he sinks, and only stops once he has gone all the way under — and
## `RunFlow` has to be able to see that he is still on his way, or the summary freezes him half out.
func _check_he_goes_under_while_struggling() -> void:
	var dead := _player.machine.current as PlayerDead
	var model := _player.get_node_or_null(PlayerDead.MODEL) as Node3D
	if dead == null or model == null:
		_fail("the drowned player has no dead state or no model to sink")
		return
	var start := model.position.y + dead.sunk()
	await _hold_under(_tide.sink_seconds() * 0.5)
	if not dead.is_sinking() or dead.sunk() <= 0.0:
		_fail("halfway through going under he is not sinking (%.2f m down)" % dead.sunk())
	if not _player.animation.animation_player.is_playing():
		_fail("he stopped struggling before he was under")
	await _hold_under(_tide.sink_seconds() * 0.5 + 0.5)
	if dead.is_sinking():
		_fail("%.1f s after drowning he is still going under" % (_tide.sink_seconds() + 0.5))
	if absf(start - model.position.y - _tide.sink_depth) > 0.01:
		_fail(
			(
				"he went %.2f m under, and the tide asks for %.2f"
				% [start - model.position.y, _tide.sink_depth]
			)
		)
	if model.visible:
		_fail("all the way under and still drawn")


## Time passing with the body kept at the depth it drowned at: this check put it there by hand, and
## is about the model sinking rather than about the capsule falling to the sea floor.
func _hold_under(seconds: float) -> void:
	var waited := 0.0
	var height := _player.global_position.y
	while waited < seconds:
		_player.global_position.y = height
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()


## Puts the body at a height, holds it there, and reports what is left of the bar. The health is put
## back first, so one reading cannot be the last one's leftovers. `until_dead` stops the hold at the
## death, so what comes after it is still there to be watched.
func _health_after(height: float, seconds: float, until_dead: bool = false) -> float:
	_player.health.current_health = _player.health.max_health
	for _index: int in A_FEW_FRAMES:
		await get_tree().physics_frame
	var waited := 0.0
	while waited < seconds and not (until_dead and _died):
		_player.global_position.y = height
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	return _player.health.current_health


func _fail(what: String) -> void:
	_failures.append("drowning FAILED — " + what)


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				"drowning OK — the beach is free, the deep takes the bar down at the rate the tide "
				+ "asks for, and a player who insists drowns through the same door as every other "
				+ "death"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
