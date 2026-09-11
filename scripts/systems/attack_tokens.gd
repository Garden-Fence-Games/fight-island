class_name AttackTokens
extends Node
## Only so many enemies may commit at once; the rest circle. Without this a crowd stops being a
## fight and becomes an unreadable pile. Ranged archetypes queue on their own pool so they cannot
## starve the melee one and leave a wave passive.

@export var melee_tokens: int = 2
@export var ranged_tokens: int = 1

var _melee: Array[int] = []
var _ranged: Array[int] = []


func _ready() -> void:
	add_to_group(&"attack_tokens")


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
