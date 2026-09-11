class_name EnemyIdle
extends EnemyState


func physics_update(delta: float) -> void:
	enemy.apply_motion(Vector3.ZERO, 0.0, delta)
	if enemy.data == null or enemy.target == null:
		return
	if enemy.distance_to_target() <= enemy.data.aggro_radius:
		transition_to(&"Chase")
