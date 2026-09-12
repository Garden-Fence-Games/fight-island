class_name PlayerReload
extends PlayerState
## The gun's whole rhythm, standing still for a second and a half.
##
## It is not a punishment and it is not a timer bolted on: the magazine decides how long a fight
## lasts and the reload decides what it costs to keep fighting, which is why the gun has no chain
## lockout. Two answers to the same question would be one too many.
##
## **Everything defensive stays available.** Dodge, parry and sprint all interrupt it — a window
## where every button is dead is a death sentence in a crowd, not a design — and interrupting means
## the rounds do not arrive.

var _elapsed: float = 0.0
var _seconds: float = 0.0


func enter(_message: Dictionary) -> void:
	_elapsed = 0.0
	var held := player.weapon
	_seconds = held.reload_time if held != null else 0.0
	if _seconds <= 0.0 or not GameState.loadout.can_reload(GameState.magazine_bonus()):
		transition_to(&"Idle")


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.halt(delta)
	# Reloading is not committing. Anything that keeps the player alive cancels it, and the rounds
	# simply do not arrive — which is the cost of having started it at the wrong moment.
	if try_common_transitions():
		return
	if _elapsed < _seconds:
		return
	GameState.loadout.reload(GameState.magazine_bonus())
	EventBus.weapon_reloaded.emit()
	transition_to(&"Idle")
