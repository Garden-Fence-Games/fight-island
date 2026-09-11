class_name AimComponent
extends Node
## Where the body is looking, which is no longer where it is going.
##
## Facing the way you walk is fine for fists and wrong for everything else: with a gun in hand,
## aiming and moving are two decisions, and a character who can only shoot where they run has lost
## the whole retreating-while-firing half of the game.
##
## **The mouse cursor is the aim.** Projected from the camera onto the ground the body is standing
## on, so it stays true on relief instead of drifting the further uphill the player walks. The
## camera is fixed, which is what makes this honest: one angle, one ray, no case where the cursor
## lands somewhere the player did not mean. With a free camera the same feature is a pile of edge
## cases.
##
## **The right stick aims directly**, and letting go hands the facing back to the movement — so a
## pad player who never touches it plays exactly the game that shipped before this.
##
## Returning ZERO is the vocabulary for "not aiming, face where you are going". Every caller
## already had that behaviour, so there is no path where a missing aim leaves the body pointing
## somewhere nobody chose — including the one before anyone has touched anything, which matters:
## a pad player would otherwise spend the whole game facing wherever the desktop cursor was parked.

## Which device is aiming, or neither. NOBODY is the state at launch and it is not a placeholder:
## nothing has been aimed yet, so nothing should be aimed at.
enum Device { NOBODY, MOUSE, STICK }

## Under this, the stick is at rest and the player is not aiming. Matches the deadzone on the
## actions themselves; a smaller one here would let a resting stick fight the movement facing.
const STICK_DEADZONE: float = 0.25
## How close the cursor may come to the body before the aim stops being a direction at all. Inside
## this the vector is a few pixels of noise pointing anywhere, and following it spins the character
## on the spot.
const MIN_REACH: float = 0.6

var _device: Device = Device.NOBODY
var _last_direction: Vector3 = Vector3.ZERO

@onready var _body: Node3D = get_parent() as Node3D


## Whichever device was touched last is the one aiming — the convention every game with both uses.
## It is also the answer issue #19 needs for its button glyphs, which is why it is readable from
## outside rather than private.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		_device = Device.STICK
	elif event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey:
		_device = Device.MOUSE


func device() -> Device:
	return _device


## Flat, normalised, and ZERO when the player is not aiming at anything.
func direction() -> Vector3:
	if _body == null:
		return Vector3.ZERO
	match _device:
		Device.STICK:
			return _stick_direction()
		Device.MOUSE:
			return _cursor_direction()
	return Vector3.ZERO


## Where a screen position lands on the ground the body is standing on, or the body itself when the
## ray never gets there — the cursor above the horizon, or no camera yet.
##
## Taking the screen position as an argument rather than reading the cursor is what lets the
## headless check drive the real projection.
func ground_under(screen: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null or _body == null:
		return _body.global_position if _body != null else Vector3.ZERO
	var ground := Plane(Vector3.UP, _body.global_position.y)
	var landed: Variant = ground.intersects_ray(
		camera.project_ray_origin(screen), camera.project_ray_normal(screen)
	)
	if landed == null:
		return _body.global_position
	return landed


func _cursor_direction() -> Vector3:
	var to_cursor := ground_under(get_viewport().get_mouse_position()) - _body.global_position
	to_cursor.y = 0.0
	# Held rather than cleared: a cursor over the sea, over the sky, or sitting on the character
	# means "keep looking where you were", never "spin".
	if to_cursor.length() < MIN_REACH:
		return _last_direction
	_last_direction = to_cursor.normalized()
	return _last_direction


## Camera-relative, exactly like movement, so up on the stick is away from the viewer on both.
func _stick_direction() -> Vector3:
	var stick := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")
	if stick.length() < STICK_DEADZONE:
		return Vector3.ZERO
	var camera := get_viewport().get_camera_3d()
	var basis := camera.global_transform.basis if camera != null else _body.global_transform.basis
	var forward := Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()
	var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
	_last_direction = (right * stick.x - forward * stick.y).normalized()
	return _last_direction
