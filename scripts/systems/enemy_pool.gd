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
##
## **An archetype with a model of its own is pooled apart.** A leased body keeps the rig it was made
## with — the ragdoll fitted its capsules to those vertices and the animation found that skeleton —
## so swapping a pirate into a farmer's body at revive would mean rebuilding every component that
## ever looked at the rig. Two shelves is the cheaper answer, and the rarer body gets the smaller
## one.

const SIZE: int = 32
## And for a body only a fraction of a wave is made of. Twelve is what `max_alive` tops out at, so
## sixteen covers a wave that happened to roll nothing else and still has bodies going into the
## ground.
const RESERVE: int = 16

@export var enemy_scene: PackedScene = null
## The bodies that are not the shared one, by `EnemyData.id`. Everything absent from here is made
## from `enemy_scene`, which is how anything on the farmer rig is made.
@export var bodies: Dictionary[StringName, PackedScene] = {}

var _idle: Dictionary[PackedScene, Array] = {}
var _made: int = 0


func _ready() -> void:
	_fill(enemy_scene, SIZE)
	for id: StringName in bodies:
		_fill(bodies[id], RESERVE)


## A body ready to be revived, or null when there is no scene to make one from.
func lease(id: StringName = &"") -> Enemy:
	var scene: PackedScene = bodies.get(id, enemy_scene)
	var shelf: Array = _idle.get(scene, [])
	if shelf.is_empty():
		var grown := _make(scene)
		if grown == null:
			return null
		push_warning("Enemy pool ran out of one of its bodies — the wave formula outran it.")
		return grown
	return shelf.pop_back() as Enemy


func idle_count() -> int:
	var left := 0
	for scene: PackedScene in _idle:
		left += (_idle[scene] as Array).size()
	return left


## How many bodies exist at all. Watched by the headless check: a run that keeps making new ones is
## a pool in name only.
func made_count() -> int:
	return _made


func _fill(scene: PackedScene, how_many: int) -> void:
	if scene == null or _idle.has(scene):
		return
	var shelf: Array = []
	for _index: int in how_many:
		var made := _make(scene)
		if made != null:
			shelf.append(made)
	_idle[scene] = shelf


func _make(scene: PackedScene) -> Enemy:
	if scene == null:
		push_error("Enemy pool has no scene to pool.")
		return null
	var enemy := scene.instantiate() as Enemy
	if enemy == null:
		push_error("Enemy pool was given a scene that is not an Enemy.")
		return null
	# Set before the body enters the tree, or it wakes up fighting on the spot where it was made.
	enemy.pooled = true
	enemy.retired.connect(_on_retired.bind(scene))
	add_child(enemy)
	_made += 1
	return enemy


func _on_retired(enemy: Enemy, scene: PackedScene) -> void:
	var shelf: Array = _idle.get(scene, [])
	if shelf.has(enemy):
		return
	shelf.append(enemy)
	_idle[scene] = shelf
