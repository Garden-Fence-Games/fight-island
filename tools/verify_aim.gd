extends Node
## Headless proof that the body looks where the player points and goes where the player pushes, and
## that the two never get confused.
##
## Every check drives the aim through the real input path — a joypad event parsed by the engine, or
## the real camera projection for the cursor — because the part that breaks is never the arithmetic,
## it is the wiring between a device and a yaw.
## Run: godot --headless --path . res://tools/verify_aim.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
## The right stick, as the engine numbers its axes.
const STICK_X: int = 2
const STICK_Y: int = 3
## Half a second is many times the turn the cap allows in one frame, and well under the time a
## 720°/s body needs to be somewhere it was not asked to be.
const SETTLE: float = 0.5
## How close a facing has to be to count as arrived. The turn is rate-capped and lands within a
## degree or two; anything tighter would be testing floating point.
const CLOSE_ENOUGH: float = 0.08

var _failures: PackedStringArray = []
var _arena: Node3D = null
var _player: Player = null


func _ready() -> void:
	_run()


func _run() -> void:
	_arena = (load(ARENA) as PackedScene).instantiate() as Node3D
	add_child(_arena)
	await get_tree().physics_frame
	_player = _arena.get_node("Player") as Player
	# Nothing else on the island while the facing is measured: a farmer landing a hit sends the
	# player to Hurt, which is not what any of these checks are about.
	(_arena.get_node("WaveDirector") as WaveDirector).halt()
	if _player == null or _player.aim == null:
		_fail("the player has no aim component")
		_report()
		return

	await _check_nothing_aims_until_something_is_touched()
	await _check_the_keys_still_move_the_body()
	await _check_the_stick_turns_the_body()
	await _check_letting_go_hands_the_facing_back()
	await _check_a_body_turns_rather_than_snaps()
	await _check_the_cursor_lands_on_the_ground()
	await _check_an_attack_commits_to_its_facing()
	await _check_a_dodge_goes_where_the_keys_say()
	_report()


## The state at launch, and the one that matters most: a pad player must not spend the game facing
## wherever the desktop cursor happens to be parked.
func _check_nothing_aims_until_something_is_touched() -> void:
	if not _player.aim.direction().is_zero_approx():
		_fail("the player is aiming before any device has been touched")
	await get_tree().physics_frame


## The whole point of splitting facing from movement is that the two stay split. The keys move the
## body; the aim only turns it. If walking ever starts following the cursor, the player loses the
## one thing this feature was for — backing away from something while still pointing at it.
func _check_the_keys_still_move_the_body() -> void:
	_reset()
	_player.rotation.y = 0.0
	_push_key(KEY_W, true)
	await _advance(SETTLE)
	var facing := -_player.global_transform.basis.z
	var from := _player.global_position
	await _advance(SETTLE)
	_push_key(KEY_W, false)
	var travelled := _player.global_position - from
	travelled.y = 0.0
	if travelled.length() < 0.5:
		_fail("holding W should walk the player, it moved %.2f m" % travelled.length())
		return
	# Camera-relative, exactly as it was before aiming existed: W is away from the viewer.
	if travelled.normalized().dot(_screen_forward()) < 0.9:
		_fail("holding W should walk away from the camera, walked %s" % travelled.normalized())
	if travelled.normalized().dot(facing) > 0.9:
		_fail("walking should not follow the facing — the two have to stay independent")
	await get_tree().physics_frame


func _check_the_stick_turns_the_body() -> void:
	_reset()
	_push_stick(Vector2(1.0, 0.0))
	await _advance(SETTLE)
	# The stick is camera-relative, so "right on the stick" is the camera's right, not world +X.
	_expect_facing(_screen_right(), "the stick should turn the body")


## A pad player who never touches the right stick has to get the game that shipped before aiming
## existed: facing wherever they are running.
func _check_letting_go_hands_the_facing_back() -> void:
	_reset()
	_push_stick(Vector2.ZERO)
	await get_tree().physics_frame
	if not _player.aim.direction().is_zero_approx():
		_fail("a stick at rest should not be aiming")
	_player.face(_screen_right(), 1.0)
	await get_tree().physics_frame
	if not _player.look_direction(Vector3.FORWARD).is_equal_approx(Vector3.FORWARD):
		_fail("with no aim the body should follow the movement")


## The cap is the difference between a character and a turret.
func _check_a_body_turns_rather_than_snaps() -> void:
	_reset()
	_player.rotation.y = 0.0
	_push_stick(Vector2(1.0, 0.0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var turned := absf(_player.rotation.y)
	var most := deg_to_rad(Player.TURN_SPEED_DEGREES) * (3.0 / 60.0)
	if turned > most:
		_fail("the body turned %.1f° in two frames, the cap allows %.1f°" % [turned, most])


## The projection itself, through the real camera. A cursor to the right of the character has to
## put a point to the character's right on the ground it is standing on — and a cursor above the
## horizon must not move anything.
func _check_the_cursor_lands_on_the_ground() -> void:
	_reset()
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_fail("the arena has no camera to project through")
		return
	var centre := camera.unproject_position(_player.global_position)
	var ground := _player.aim.ground_under(centre + Vector2(200.0, 0.0))
	if not is_equal_approx(ground.y, _player.global_position.y):
		_fail("the cursor should land on the ground the body stands on, landed at %.2f" % ground.y)
	var to_cursor := ground - _player.global_position
	if to_cursor.normalized().dot(_screen_right()) < 0.9:
		_fail("a cursor to the right of the body should aim to its right")
	# Straight up is sky. Nothing there, so the answer is the body itself and the facing is held.
	var missed := _player.aim.ground_under(Vector2(centre.x, -10000.0))
	if not missed.is_equal_approx(_player.global_position):
		_fail("a cursor above the horizon should aim at nothing, aimed at %s" % missed)
	await get_tree().physics_frame


## A swing that can be steered mid-animation is a swing with no commitment.
func _check_an_attack_commits_to_its_facing() -> void:
	_reset()
	_push_stick(Vector2(1.0, 0.0))
	await _advance(SETTLE)
	var committed := _player.rotation.y
	_player.machine.current.transition_to(&"Attack", {"index": 0, "perfect": false})
	await get_tree().physics_frame
	_push_stick(Vector2(-1.0, 0.0))
	await _advance(0.2)
	if _player.machine.current_name != &"Attack":
		_fail("the attack should still be running")
		return
	if absf(angle_difference(_player.rotation.y, committed)) > CLOSE_ENOUGH:
		_fail("the attack was steered after it started")


## Rolling into the thing you are shooting at is the failure this prevents.
func _check_a_dodge_goes_where_the_keys_say() -> void:
	_reset()
	_push_stick(Vector2(1.0, 0.0))
	await _advance(SETTLE)
	var aimed := _player.aim.direction()
	var from := _player.global_position
	_player.machine.current.transition_to(&"Dodge")
	await _advance(PlayerDodge.DURATION * 0.5)
	var travelled := _player.global_position - from
	travelled.y = 0.0
	if travelled.length() < 0.5:
		_fail("the dodge did not move the player")
		return
	if travelled.normalized().dot(aimed) > 0.0:
		_fail("with no movement input the dodge should roll away from the aim, not into it")


## The camera's right on the ground plane — what "right on the stick" and "right of the cursor"
## both have to mean, since movement is camera-relative too.
func _screen_right() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.RIGHT
	var basis := camera.global_transform.basis
	return Vector3(basis.x.x, 0.0, basis.x.z).normalized()


## The camera's forward on the ground plane — what W has always meant.
func _screen_forward() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.FORWARD
	var basis := camera.global_transform.basis
	return Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()


func _expect_facing(direction: Vector3, complaint: String) -> void:
	var wanted := atan2(-direction.x, -direction.z)
	var off := absf(angle_difference(_player.rotation.y, wanted))
	if off > CLOSE_ENOUGH:
		_fail("%s — off by %.1f°" % [complaint, rad_to_deg(off)])


## Through the engine's own input path rather than by setting a field: what breaks is the binding,
## and a field would not exercise it.
func _push_stick(stick: Vector2) -> void:
	for axis: int in [STICK_X, STICK_Y]:
		var event := InputEventJoypadMotion.new()
		event.device = 0
		event.axis = axis
		event.axis_value = stick.x if axis == STICK_X else stick.y
		Input.parse_input_event(event)


func _push_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)


func _reset() -> void:
	_player.machine.current.transition_to(&"Idle")
	_player.global_position = Vector3(0.0, 1.0, 0.0)
	if _player.stamina != null:
		_player.stamina.refund(999.0)


func _advance(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print("aim OK — keys still walk, stick turns, cursor lands on the ground, attack commits")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
