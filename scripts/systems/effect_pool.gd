class_name EffectPool
extends Node
## Effects, leased and handed back — never made in the middle of a fight.
##
## Thirty enemies on screen is the budget, and effects are the easiest way to lose it: a burst
## instanced per hit means a `PackedScene` unpacked, nodes built and a particle system configured,
## all inside the frame the player is meant to be feeling. So each scene is warmed in one batch the
## first time it is asked for, and every instance after that is one that has already been used.
##
## Found by group rather than exported, because an effect is asked for from states, components and
## listeners alike, and none of them should hold a path to this.

## How many of a scene are built the first time it is wanted. Two melee attack tokens plus a ranged
## one means three bodies can be committing at once, and a hit can land while the last one is still
## fading — eight is that with room, and it is one allocation for the whole run.
const BATCH: int = 8

var _idle: Dictionary = {}
var _made: int = 0


func _ready() -> void:
	add_to_group(&"effects")


## An instance ready to be placed and played, or null when the scene cannot make one. The caller
## owns where it goes; the effect hands itself back when it is spent.
func lease(scene: PackedScene) -> Node3D:
	if scene == null:
		return null
	if not _idle.has(scene):
		_idle[scene] = []
		_warm(scene, BATCH)
	var waiting: Array = _idle[scene]
	if waiting.is_empty():
		# A wave that outruns the batch gets more rather than going quiet, and says so: an effect
		# that silently stops playing is a bug nobody would think to look for here.
		push_warning("Effect pool ran dry on %s — the batch of %d was not enough." % [scene, BATCH])
		_warm(scene, BATCH)
		waiting = _idle[scene]
	if waiting.is_empty():
		return null
	var effect: Node3D = waiting.pop_back()
	effect.process_mode = Node.PROCESS_MODE_INHERIT
	effect.visible = true
	return effect


## How many instances exist at all. Watched by the headless check: a fight that keeps making new
## ones is a pool in name only.
func made_count() -> int:
	return _made


func idle_count(scene: PackedScene) -> int:
	return (_idle.get(scene, []) as Array).size()


func _warm(scene: PackedScene, how_many: int) -> void:
	for _index: int in how_many:
		var effect := scene.instantiate() as Node3D
		if effect == null:
			push_error("Effect pool was given a scene that is not a Node3D.")
			return
		add_child(effect)
		effect.visible = false
		effect.process_mode = Node.PROCESS_MODE_DISABLED
		if effect.has_signal(&"spent"):
			effect.connect(&"spent", _on_spent.bind(scene, effect))
		(_idle[scene] as Array).append(effect)
		_made += 1


func _on_spent(scene: PackedScene, effect: Node3D) -> void:
	var waiting: Array = _idle.get(scene, [])
	if waiting.has(effect):
		return
	effect.visible = false
	effect.process_mode = Node.PROCESS_MODE_DISABLED
	waiting.append(effect)
