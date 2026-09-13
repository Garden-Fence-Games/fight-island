class_name VistaCamera
extends Camera3D
## The camera behind the title screen. It drifts rather than sits, because a still frame reads as a
## screenshot, and the whole point of putting the real island back there is that it is running.
##
## It swings through a **narrow arc** instead of orbiting. The island is composed for one angle —
## that is the fixed camera's bargain — so a full orbit would show it from the side nobody built,
## and the title would become the one place in the game that lies about what the island looks like.

## Degrees either side of the angle it was placed at.
const SWING: float = 7.0
## Seconds for one there-and-back. Slow enough that nobody catches it moving, long enough that a
## player left on the menu sees that it has.
const PERIOD: float = 48.0
## Metres it rises and falls over the same period, a quarter turn out of phase so the motion never
## resolves into a pendulum.
const RISE: float = 1.6

## Aimed rather than rotated: a hand-written transform matrix is three numbers nobody can read and
## one nobody can correct. Moving the camera in the editor is enough — it re-aims itself.
@export var looks_at: Vector3 = Vector3.ZERO

var _origin: Transform3D = Transform3D.IDENTITY
var _elapsed: float = 0.0


func _ready() -> void:
	if not is_equal_approx(global_position.distance_to(looks_at), 0.0):
		look_at(looks_at)
	_origin = transform
	current = true
	# The title shows the island the way the game will, pixels and all.
	PixelLook.attach(self)


func _process(delta: float) -> void:
	_elapsed += delta
	var phase := TAU * _elapsed / PERIOD
	var drifted := _origin.rotated_local(Vector3.UP, deg_to_rad(SWING) * sin(phase))
	drifted.origin.y += RISE * sin(phase + PI * 0.5)
	transform = drifted
