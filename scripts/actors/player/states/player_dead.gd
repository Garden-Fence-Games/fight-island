class_name PlayerDead
extends PlayerState


func enter(_message: Dictionary) -> void:
	player.close_chain()
	if player.hitbox != null:
		player.hitbox.disarm()


func physics_update(delta: float) -> void:
	player.halt(delta)
