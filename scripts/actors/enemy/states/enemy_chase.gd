class_name EnemyChase
extends EnemyState


func physics_update(delta: float) -> void:
	if enemy.data == null or enemy.target == null:
		enemy.apply_motion(Vector3.ZERO, 0.0, delta)
		return
	enemy.apply_motion(enemy.direction_to_target(), enemy.data.move_speed, delta)
	enemy.face_target(delta)
	if enemy.distance_to_target() > enemy.data.aggro_radius:
		transition_to(&"Idle")
		return
	if enemy.distance_to_target() > enemy.data.attack_range:
		return
	transition_to(&"WindUp" if enemy.claim_token() else &"Strafe")
