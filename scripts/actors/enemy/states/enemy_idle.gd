class_name EnemyIdle
extends EnemyState
## Standing where he was put, until the fight comes to him.
##
## A wave whose every body is closing from the moment it appears reads as one flat press. What makes
## it a fight is that some of it is still waiting — so the player can see a farmer before the farmer
## sees them, and distance carries information again.


func physics_update(delta: float) -> void:
	enemy.apply_motion(Vector3.ZERO, 0.0, delta)
	if enemy.roused:
		transition_to(&"Chase")
		return
	if enemy.notices_target():
		# Through rouse() rather than straight to Chase, so the farmers beside him come too.
		enemy.rouse()
		transition_to(&"Chase")
