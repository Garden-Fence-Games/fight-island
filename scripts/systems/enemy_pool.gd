class_name EnemyPool
extends Node
## Bodies created once and reused for the whole run.
##
## Thirty-two, because the wave formula never has more than twelve alive at once and a body still
## sinking into the ground has not been handed back yet. Allocating and freeing a CharacterBody3D
## with a state machine, two areas and a mesh is not free, and at thirty on screen it lands in the
## same frame as the fight.
##
## A pool that quietly runs dry is worse than one that grows, so it grows and says so — a wave that
## goes silent because nothing could be leased is a bug nobody would think to look for here.

const SIZE: int = 32

@export var enemy_scene: PackedScene = null

var _idle: Array[Enemy] = []
var _made: int = 0


func _ready() -> void:
	for _index: int in SIZE:
		_idle.append(_make())


## A body ready to be revived, or null when there is no scene to make one from.
func lease() -> Enemy:
	if _idle.is_empty():
		var grown := _make()
		if grown == null:
			return null
		push_warning("Enemy pool grew past %d — the wave formula outran it." % SIZE)
		return grown
	return _idle.pop_back()


func idle_count() -> int:
	return _idle.size()


## How many bodies exist at all. Watched by the headless check: a run that keeps making new ones is
## a pool in name only.
func made_count() -> int:
	return _made


func _make() -> Enemy:
	if enemy_scene == null:
		push_error("Enemy pool has no scene to pool.")
		return null
	var enemy := enemy_scene.instantiate() as Enemy
	if enemy == null:
		push_error("Enemy pool was given a scene that is not an Enemy.")
		return null
	# Set before the body enters the tree, or it wakes up fighting on the spot where it was made.
	enemy.pooled = true
	enemy.retired.connect(_on_retired)
	add_child(enemy)
	_made += 1
	return enemy


func _on_retired(enemy: Enemy) -> void:
	if _idle.has(enemy):
		return
	_idle.append(enemy)
