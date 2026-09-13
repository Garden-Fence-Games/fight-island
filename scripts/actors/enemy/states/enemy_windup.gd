class_name EnemyWindUp
extends EnemyState
## The telegraph. It shortens as waves go on but never past its floor, because a wind-up nobody
## can read is noise, not difficulty.
##
## **He rears back.** The ring that used to fill on the ground is gone (#122), and the farmhand now
## has a rig but no wind-up clip on it yet — so the tell is the body itself: it tips backwards over
## the wind-up and snaps forward on the swing.
##
## That is not a placeholder for the clip so much as the same thing done with what exists. What the
## ring had to satisfy, this satisfies:
##
## - **A shape, not a colour.** It is geometry, so it survives greyscale, a colourblind player and a
##   camera twenty metres up — and it needs no accessibility switch to do it.
## - **The same tell for every archetype.** One lean, whoever is throwing it. A signal per farmer is
##   one more thing to learn in the half second there is to read it.
## - **Driven by the wind-up's own duration**, which is not a constant: the waves shorten it and the
##   hour shortens it again. The lean is a share of `enemy.windup()` rather than a clip playing at
##   its own rate, so the picture and the timing cannot drift apart. When the rig lands, the same
##   share hands straight to `AnimationComponent.play_clip(clip, seconds)`.
##
## Which leaves the sound as the other half of the telegraph rather than the whole of it. It is
## announced from here because this is the one place that knows a body has committed and where it is
## standing, and it is announced on the bus rather than played here because a state machine has no
## business knowing the game has audio in it.

## How far the body tips back, in degrees, at the moment the swing begins. What has to carry at
## twenty metres is the silhouette swinging about half a metre — against a body 0.7 m wide, the
## difference between "standing" and "loaded".
##
## **The angle follows the pivot, the half metre does not.** It was 35° on the capsule, which tipped
## about its middle with its top 0.85 m up. The rig tips at its feet with its head about 2.3 m up,
## so the same 35° would throw the head back 1.3 m and read as a man falling over. 14° is the same
## half metre on the taller lever.
const LEAN_DEGREES: float = 14.0

var _elapsed: float = 0.0


func enter(_message: Dictionary) -> void:
	_elapsed = 0.0
	EventBus.telegraph_began.emit(enemy.global_position, enemy.data)


## Whatever ends the wind-up — the swing, a stagger, a death — stands the body back up. A farmer
## left leaning is the same lie the ring told when it outlived the commit it was drawn for.
func exit() -> void:
	_tip(0.0)


func physics_update(delta: float) -> void:
	_elapsed += delta
	enemy.apply_motion(Vector3.ZERO, 0.0, delta)
	enemy.face_target(delta * 0.4)
	var attack := enemy.data.attack if enemy.data != null else null
	if attack == null:
		transition_to(&"Idle")
		return
	_lean(_elapsed / maxf(enemy.windup(), 0.001))
	if _elapsed >= enemy.windup():
		transition_to(&"Attack")


## Straight in, not eased. The whole use of the picture is telling the player *when*, so how far the
## body has tipped has to map to how much time is left — an ease would hold it upright and then rush
## it, which reads as a shorter wind-up than the one being fought.
##
func _lean(through: float) -> void:
	_tip(deg_to_rad(LEAN_DEGREES) * clampf(through, 0.0, 1.0))


## Tips the whole body back to `radians`, pivoting at the feet, away from whatever it faces.
##
## **Composed in the body's own frame rather than written to `visual.rotation.x`.** The rig is
## turned half a circle to face the way Godot faces, and a basis turned that way reads back as more
## than one set of Euler angles — so writing one of them can land on the other reading and stand the
## farmer on his head. Pre-multiplying means "back" is +Z in the body's frame however the model was
## imported.
##
## The authored basis is not stored: it is the current one with the current lean taken back out,
## which leaves nothing on the body a pooled life could inherit. The scale is put back afterwards
## because it belongs to the elite rank, and a tell that fought it would shrink every elite that
## wound up.
func _tip(radians: float) -> void:
	var visual := enemy.visual
	if visual != null:
		var size := visual.scale
		var upright := Basis(Vector3.RIGHT, -enemy.leaning) * visual.basis.orthonormalized()
		visual.basis = Basis(Vector3.RIGHT, radians) * upright
		visual.scale = size
	enemy.leaning = radians
