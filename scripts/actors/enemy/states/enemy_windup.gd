class_name EnemyWindUp
extends EnemyState
## The telegraph. It shortens as waves go on but never past its floor, because a wind-up nobody
## can read is noise, not difficulty.

## The warning is one colour for every archetype on purpose. A ring that changed hue per farmer
## would be one more thing to learn in the half second there is to answer it, and the shape already
## carries everything the player needs.
const DANGER: Color = Color(0.92, 0.24, 0.18)

var _elapsed: float = 0.0
var _ring: Telegraph = null


func enter(_message: Dictionary) -> void:
	_elapsed = 0.0
	_show_the_telegraph()


## Whatever ends the wind-up — the swing, a stagger, a death — takes the ring with it. A ring left
## on the ground under a body that is no longer committing is worse than none: it is a lie about
## what is about to happen.
func exit() -> void:
	if _ring != null:
		_ring.finish()
		_ring = null


func physics_update(delta: float) -> void:
	_elapsed += delta
	enemy.apply_motion(Vector3.ZERO, 0.0, delta)
	enemy.face_target(delta * 0.4)
	var attack := enemy.data.attack if enemy.data != null else null
	if attack == null:
		transition_to(&"Idle")
		return
	if _ring != null:
		_ring.follows(enemy)
		_ring.fill(_elapsed / maxf(enemy.windup(), 0.001))
	if _elapsed >= enemy.windup():
		transition_to(&"Attack")


func _show_the_telegraph() -> void:
	var pool := enemy.get_tree().get_first_node_in_group(&"effects") as EffectPool
	if pool == null or enemy.telegraph_scene == null:
		return
	_ring = pool.lease(enemy.telegraph_scene) as Telegraph
	if _ring != null:
		_ring.begin(enemy, DANGER)
