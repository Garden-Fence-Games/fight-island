class_name PlayerHurt
extends PlayerState

var _remaining: float = 0.0


func enter(message: Dictionary) -> void:
	_remaining = float(message.get("stagger", 0.25))


func physics_update(delta: float) -> void:
	_remaining -= delta
	player.halt(delta)
	if _remaining <= 0.0:
		transition_to(&"Idle")
