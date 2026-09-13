class_name WaveDirector
extends Node
## Runs the waves off `WaveConfig` — every number from the resource, none from here.
##
## It drip-feeds rather than emptying the wave onto the island at once: the count is how many come
## in total, `max_alive` is how many the player faces at a time, and the gap between those two is
## what makes wave twelve pressure instead of a wall.
##
## The director owns no combat rules. It asks the config what to send, asks the spawn director
## where, and announces what happened on the bus — so the economy, the HUD and the tutorial can all
## listen without any of them being wired into the fight.
##
## **A wave is one turn of the day.** It opens in daylight, the sun goes down partway through, and
## the player finishes it in the dark; surviving the night is what passes it. The wave is therefore
## timed rather than counted — the roster is a budget the island draws on to stay populated, not a
## queue to be emptied. It still ends early if the budget runs out and nothing is left standing,
## which is what a player good enough to outpace it has earned.

@export var config: WaveConfig = null
## Off when something else is driving the island — the headless checks, and the tutorial later.
@export var autostart: bool = true
## A breath before the first wave, so the player is looking at the island rather than at a farmer.
@export var first_wave_delay: float = 2.0
## And between waves — the window the upgrade screen lives in.
@export var breather: float = 5.0
## How often a body may arrive while a wave is running.
@export var spawn_interval: float = 0.6

var wave: int = 0

var _running: bool = false
var _left_to_send: int = 0
var _next_wave_in: float = 0.0
var _next_spawn_in: float = 0.0
var _untouched: bool = true
var _first_of_wave: bool = true
var _elapsed: float = 0.0
var _rng := RandomNumberGenerator.new()
var _health_seen: float = -1.0

# A child, not an export: node exports do not resolve in a hand-written .tscn (ADR 0006).
@onready var spawner: SpawnDirector = $SpawnDirector


func _ready() -> void:
	_rng.seed = GameState.run_seed + 1
	# A resumed run comes back where it was, and the two cases are not the same wave: one that was
	# still being fought is fought again from its start, one that was cleared hands over to the
	# next. Reading the state's wave for both is what used to skip a wave when a player quit
	# halfway through one.
	wave = GameState.wave - 1 if GameState.wave_in_progress else GameState.wave
	# A resumed run comes back to daybreak, because a wave always starts at daybreak.
	_mark_the_hour()
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_damaged.connect(_on_player_damaged)
	if autostart:
		_next_wave_in = first_wave_delay


func _process(delta: float) -> void:
	if config == null or spawner == null:
		return
	if not _running:
		if _next_wave_in <= 0.0:
			return
		_next_wave_in -= delta
		if _next_wave_in <= 0.0:
			start_wave(wave + 1)
		return
	_elapsed += delta
	_mark_the_hour()
	var length := _wave_length()
	if length > 0.0 and _elapsed >= length:
		_finish_the_wave()
		return
	_next_spawn_in -= delta
	if _next_spawn_in > 0.0:
		return
	_next_spawn_in = spawn_interval
	_send_one()


func start_wave(index: int) -> void:
	if config == null or spawner == null:
		return
	wave = index
	_left_to_send = config.enemy_count(wave)
	_running = true
	_untouched = true
	_first_of_wave = true
	_next_spawn_in = 0.0
	_elapsed = 0.0
	_mark_the_hour()
	EventBus.wave_started.emit(wave, _left_to_send)


## Stops everything and takes the island back. The breather is cancelled too, or a halted director
## would start the next wave anyway a few seconds later.
func halt() -> void:
	_running = false
	_left_to_send = 0
	_next_wave_in = 0.0
	_elapsed = 0.0
	GameState.fighting = false
	if spawner != null:
		spawner.clear()


## The arena is going: a scene change, a restart, a quit to the title. The run clock stops here and
## nowhere else, because this is the one node that is present exactly while a fight can be.
##
## `wave_in_progress` deliberately survives this — a player who walked out mid-wave has to come back
## into that wave rather than past it — so it cannot also be what the clock reads. See
## `GameState.fighting`.
func _exit_tree() -> void:
	GameState.fighting = false


## Takes the island back from whatever drove a wave by hand — the tutorial today, scripted waves
## later. The breather runs as usual afterwards, so the next wave arrives exactly like every other.
func hand_over(after_wave: int) -> void:
	wave = after_wave
	_running = false
	_left_to_send = 0
	_next_wave_in = breather


func is_running() -> bool:
	return _running


func left_to_send() -> int:
	return _left_to_send


## How much of this wave is behind the player, nought to one — the share of its day that has run.
func progress() -> float:
	var length := _wave_length()
	if length <= 0.0 or not _running:
		return 0.0
	return clampf(_elapsed / length, 0.0, 1.0)


func _send_one() -> void:
	if _left_to_send <= 0:
		return
	if spawner.alive_count() >= config.max_alive(wave):
		return
	var band := config.band_for(wave)
	if band == null:
		return
	# No wave opens with a thrower: the player is never shot at before anything is on screen.
	var data := band.pick(_rng, _first_of_wave)
	if data == null:
		return
	# Read now rather than at the top of the wave: a farmer who walks on at dusk is a dusk farmer,
	# and one who arrived in daylight keeps the daylight he arrived with for the rest of his life.
	var phase := GameState.day_phase as DayPhase
	var sent := spawner.spawn(
		data,
		config.health_multiplier(wave),
		config.damage_multiplier(wave, phase),
		config.speed_multiplier(wave),
		config.windup_multiplier(wave, phase),
		_rolled_elite()
	)
	# Null means nowhere passed the rules this tick, not that the wave is short of a body. It stays
	# owed and the next tick tries again.
	if sent == null:
		return
	_left_to_send -= 1
	_first_of_wave = false


func _on_enemy_died(_enemy: Node3D, _archetype: StringName, _money: int) -> void:
	if not _running or _left_to_send > 0:
		return
	# The body that just died is still in the group for this frame, so the count is read after it.
	call_deferred("_check_wave_cleared")


func _check_wave_cleared() -> void:
	if not _running or _left_to_send > 0 or spawner.alive_count() > 0:
		return
	_finish_the_wave()


## Either the night is over or the island has run out of farmers. Standing bodies are sent home
## rather than killed: the wave is passed, and nobody is paid for a fight that did not happen.
func _finish_the_wave() -> void:
	_running = false
	_next_wave_in = breather
	if spawner != null:
		spawner.clear()
	EventBus.wave_cleared.emit(wave, config.reward_for(wave, _untouched))


## Flawless means untouched, and the bus only carries the health that resulted — so a drop is what
## a hit looks like from here. Healing between waves must not read as one, hence the comparison
## rather than a bare signal.
func _on_player_damaged(current: float, _maximum: float) -> void:
	if _health_seen >= 0.0 and current < _health_seen:
		_untouched = false
	_health_seen = current


## Whether this one comes up an elite. Rolled per body rather than per wave, so a wave is never
## uniformly worse — an elite is a moment inside a fight, not a different fight.
func _rolled_elite() -> EliteRank:
	if config.elite == null:
		return null
	return config.elite if _rng.randf() < config.elite_chance(wave) else null


## The hour and the rules of the day, together, because they are the same fact. Called every frame
## a wave is running: the sun comes down while the player is standing in the fight.
func _mark_the_hour() -> void:
	if config == null or config.cycle == null:
		return
	GameState.day_cycle = config.cycle
	GameState.day_elapsed = _elapsed
	GameState.hour = config.cycle.hour_at(_elapsed)
	GameState.set_day_phase(config.cycle.phase_at(_elapsed))


## A wave with no cycle behind it has no length, and the old rule takes over: it lasts until the
## roster is spent and the island is quiet.
func _wave_length() -> float:
	if config == null or config.cycle == null:
		return 0.0
	return config.cycle.wave_seconds()
