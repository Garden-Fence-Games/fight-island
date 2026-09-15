class_name PlayerDodge
extends PlayerState
## Committed: no steering once it starts, and the invulnerability opens a hair late so a dodge is
## an answer to a telegraph rather than a panic button.
##
## The roll goes where the stick or the keys say, never where the aim points — otherwise every
## dodge with a gun in hand would be a dodge into the thing being shot at. Standing still, it rolls
## *away* from what is being aimed at, which is what the input means when the only thing the player
## is saying is "not here". And it does not turn the body while aiming: tracking a target through a
## roll is the whole reason to have an aim in the first place.

const DURATION: float = 0.55
const DISTANCE: float = 3.2
const IFRAME_START: float = 0.05
const IFRAME_LENGTH: float = 0.30
## The beat after the roll in which another cannot start. Long enough, with the roll's own
## vulnerable tail, to be about as long as a farmhand's committed swing — so a player who answers
## everything with a roll can actually be caught.
const COOLDOWN: float = 0.15

var _elapsed: float = 0.0
var _direction: Vector3 = Vector3.ZERO
var _granted: bool = false


func enter(_message: Dictionary) -> void:
	_elapsed = 0.0
	_granted = false
	_direction = player.move_direction()
	var aimed := player.aim.direction() if player.aim != null else Vector3.ZERO
	if _direction.is_zero_approx():
		_direction = -aimed if not aimed.is_zero_approx() else -player.global_transform.basis.z
	if aimed.is_zero_approx():
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
		player.roll_cooldown = COOLDOWN
		transition_to(&"Idle")


func clip_name() -> StringName:
	return &"dodge_roll"


## The roll plays over exactly the time the dodge takes, not at the clip's own rate. The clip is
## authored a little longer than the dodge, and at its own rate the body would still be mid-roll on
## the frame the player is handed back control — a picture that promises the dodge is not over yet.
func clip_duration() -> float:
	return DURATION
