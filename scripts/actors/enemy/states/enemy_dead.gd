class_name EnemyDead
extends EnemyState

const SINK_SPEED: float = 1.2
const SINK_DEPTH: float = 2.0

var _sunk: float = 0.0


func enter(_message: Dictionary) -> void:
	# Out of the group the moment he dies rather than when the body finishes sinking: a wave is
	# cleared when the last enemy dies, and the living should not steer around a corpse.
	enemy.remove_from_group(&"enemies")
	if enemy.hitbox != null:
		enemy.hitbox.disarm()
	if enemy.hurtbox != null:
		enemy.hurtbox.monitorable = false
	enemy.set_collision_layer_value(3, false)


func physics_update(delta: float) -> void:
	var step := SINK_SPEED * delta
	enemy.global_position.y -= step
	_sunk += step
	if _sunk >= SINK_DEPTH:
		enemy.finish_dying()
