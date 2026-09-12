class_name AttackTokens
extends Node
## Only so many enemies may commit at once; the rest circle. Without this a crowd stops being a
## fight and becomes an unreadable pile. Ranged archetypes queue on their own pool so they cannot
## starve the melee one and leave a wave passive.
##
## Night widens the melee pool, and that is the change a player feels rather than reads: two farmers
## committing at once is a fight you can answer, three is one you have to give ground to. Shrinking
## it back at dawn needs no unwinding — a body already holding a token keeps it, and the pool simply
## refuses the next claim until enough of them have let go.

@export var melee_tokens: int = 2
@export var ranged_tokens: int = 1

## What the pool is worth by day. Kept because the phase sets the size and there has to be
## something to go back to when a run has no cycle at all.
var _by_day: int = 0
var _melee: Array[int] = []
var _ranged: Array[int] = []


func _ready() -> void:
	add_to_group(&"attack_tokens")
	_by_day = melee_tokens
	GameState.day_phase_changed.connect(_on_day_phase_changed)
	_on_day_phase_changed(GameState.day_phase)


func claim(holder: Node, ranged: bool) -> bool:
	var pool := _ranged if ranged else _melee
	var limit := ranged_tokens if ranged else melee_tokens
	var id := holder.get_instance_id()
	if pool.has(id):
		return true
	if pool.size() >= limit:
		return false
	pool.append(id)
	return true


func release(holder: Node, ranged: bool) -> void:
	var pool := _ranged if ranged else _melee
	pool.erase(holder.get_instance_id())


func holds(holder: Node, ranged: bool) -> bool:
	var pool := _ranged if ranged else _melee
	return pool.has(holder.get_instance_id())


func _on_day_phase_changed(phase: DayPhase) -> void:
	melee_tokens = phase.melee_tokens if phase != null else _by_day
