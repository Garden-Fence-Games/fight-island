class_name PlayerDodge
extends PlayerState
## Committed: no steering once it starts, and the invulnerability opens a hair late so a dodge is
## an answer to a telegraph rather than a panic button.

const DURATION: float = 0.55
const DISTANCE: float = 3.2
const IFRAME_START: float = 0.05
const IFRAME_LENGTH: float = 0.30

var _elapsed: float = 0.0
var _direction: Vector3 = Vector3.ZERO
var _granted: bool = false


func enter(_message: Dictionary) -> void:
	_elapsed = 0.0
	_granted = false
	_direction = player.move_direction()
	if _direction.is_zero_approx():
		_direction = -player.global_transform.basis.z
	player.snap_to_face(_direction)


func physics_update(delta: float) -> void:
	_elapsed += delta
	if not _granted and _elapsed >= IFRAME_START:
		_granted = true
		if player.health != null:
			player.health.make_invulnerable(IFRAME_LENGTH)
	var speed := DISTANCE / DURATION
	player.apply_motion(_direction, speed, delta)
	if _elapsed >= DURATION:
		transition_to(&"Idle")
