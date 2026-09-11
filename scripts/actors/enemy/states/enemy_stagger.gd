class_name EnemyStagger
extends EnemyState

var _remaining: float = 0.0


func enter(message: Dictionary) -> void:
	_remaining = float(message.get("duration", 0.5))
	if enemy.hitbox != null:
		enemy.hitbox.disarm()


func physics_update(delta: float) -> void:
	_remaining -= delta
	enemy.apply_motion(Vector3.ZERO, 0.0, delta)
	if _remaining <= 0.0:
		transition_to(&"Chase")
