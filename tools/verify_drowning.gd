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


## And it kills, through the same door every other death goes through.
func _check_it_drowns_him() -> void:
	_died = false
	await _health_after(_water - _tide.drowns_at, HELD_UNDER)
	if _player.health.is_alive():
		_fail(
			(
				"%.0f s under the surface left %.1f health"
				% [HELD_UNDER, _player.health.current_health]
			)
		)
	if not _died:
		_fail("the player drowned without the run being told — player_died never fired")


## Puts the body at a height, holds it there, and reports what is left of the bar. The health is put
## back first, so one reading cannot be the last one's leftovers.
func _health_after(height: float, seconds: float) -> float:
	_player.health.current_health = _player.health.max_health
	for _index: int in A_FEW_FRAMES:
		await get_tree().physics_frame
	var waited := 0.0
	while waited < seconds:
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
