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
## Where a body is stood for the assist checks: half the cone off the aim, which is inside it by a
## margin no rounding closes and far enough out that half of it is plainly not all of it.
const HALF_A_CONE: float = deg_to_rad(AimComponent.ASSIST_CONE * 0.5)
## The cone this check was written against, and a bearing plainly beyond it. Both written out: see
## `_check_the_assist_ignores_what_the_player_is_not_aiming_at`.
const EXPECTED_CONE: float = 12.0
const OUTSIDE_CONE: float = deg_to_rad(20.0)
## The share `soft` is expected to take off the error. Written out, not read — see
## `_check_soft_pulls_halfway_and_strong_goes_all_the_way`.
const EXPECTED_SOFT_PULL: float = 0.5
## The turn rate this check was written against. Written out, not read — see
## `_check_a_body_turns_rather_than_snaps`.
const EXPECTED_TURN_RATE: float = 720.0
## Inside the fists' 1.4 m, and well outside it. The weapon in hand decides how far the assist
## looks, and the fists are what a fresh run starts with.
const IN_REACH: float = 1.2
const OUT_OF_REACH: float = 8.0
const FARMHAND: String = "res://data/enemies/farmhand.tres"
## Any attack will do — it is scaled far past a farmer's health, and what is being checked is that
## the assist stops looking at him once he is down.
const KILLING_BLOW: String = "res://data/attacks/fist_uppercut.tres"

var _failures: PackedStringArray = []
var _arena: Node3D = null
var _player: Player = null
var _kept_run: Dictionary = {}


func _ready() -> void:
	_run()


func _run() -> void:
	_arena = (load(ARENA) as PackedScene).instantiate() as Node3D
	# From a fresh run, and the machine's own run put back at the end. `GameState` restores a
	# saved run at boot, so a developer who has picked the gun up would start this check holding
	# it — and every damage figure below is the fists'.
	_kept_run = SaveManager.read_json(SaveManager.RUN_PATH)
	GameState.begin_run()
	add_child(_arena)
	# Wave 1 belongs to the tutorial now, and a lesson holding it open would leave this check
	# waiting for a parry nobody is going to throw. This one is not about the lesson.
	_stand_the_tutorial_down(_arena)
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
	await _check_the_assist_is_off_when_it_is_off()
	await _check_soft_pulls_halfway_and_strong_goes_all_the_way()
	await _check_the_assist_ignores_what_the_player_is_not_aiming_at()
	await _check_the_assist_cannot_reach_past_what_is_in_hand()
	await _check_a_dead_body_stops_being_a_target()
	_put_the_run_back()
	_report()


## The state at launch, and the one that matters most: a pad player must not spend the game facing
## wherever the desktop cursor happens to be parked.
func _check_nothing_aims_until_something_is_touched() -> void:
	if not _player.aim.direction().is_zero_approx():
		_fail("the player is aiming before any device has been touched")
	await get_tree().physics_frame


## The keys move the body and the cursor must never steer where it travels — backing away from
## something while still pointing at it is the one thing this feature was for.
##
## What changed with the rig is *which part* does the pointing. The body now faces where it walks,
## because a body pointing anywhere else plays a forward stride sideways; the head carries the aim
## instead, and `tools/verify_head_look.tscn` owns that half.
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
	# The moonwalk guard, and the inversion of what this line used to assert: the stride is authored
	# going forward, so the body has to be pointing where it travels for it to read as walking.
	if travelled.normalized().dot(facing) < 0.9:
		_fail("walking should face where it travels, or the forward stride plays sideways")
	await get_tree().physics_frame


## The division of labour changed when the rig got a head: **the body no longer points at the aim,
## the head does**, up to the neck's limit. A body that turned to the cursor while walking elsewhere
## played a forward stride sideways, and with one `walk` clip that is a moonwalk.
##
## What the body still owes is the remainder. Standing still, it turns until the aim is back inside
## the head's reach — so a player can face anything — and stops there. `verify_head_look.tscn` owns
## the other half of the promise.
func _check_the_stick_turns_the_body() -> void:
	_reset()
	_player.snap_to_face(_screen_forward())
	# The stick is camera-relative, so "right on the stick" is the camera's right, not world +X.
	_push_stick(Vector2(1.0, 0.0))
	await _advance(SETTLE)
	var limit := 0.0
	if _player.head_look != null:
		limit = deg_to_rad(_player.head_look.limit_degrees)
	var facing := -_player.global_transform.basis.z
	var off := absf(facing.signed_angle_to(_screen_right(), Vector3.UP))
	if off > limit + CLOSE_ENOUGH:
		_fail(
			(
				"the stick should bring the aim inside the head's %.0f° reach, it is %.0f° away"
				% [rad_to_deg(limit), rad_to_deg(off)]
			)
		)
	if off < deg_to_rad(5.0):
		_fail("the body turned the whole way to the aim — that is the head's share now")


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
##
## The rate is **written out and asserted first**. Building the bound from `TURN_SPEED_DEGREES` made
## this pass at ten times the speed — two whole revolutions in a single frame — because the
## expectation moved with the thing it was meant to hold.
func _check_a_body_turns_rather_than_snaps() -> void:
	if not is_equal_approx(Player.TURN_SPEED_DEGREES, EXPECTED_TURN_RATE):
		_fail(
			(
				(
					"the body turns at %.0f°/s and this check was written for %.0f°/s — move it "
					+ "deliberately or not at all"
				)
				% [Player.TURN_SPEED_DEGREES, EXPECTED_TURN_RATE]
			)
		)
		return
	_reset()
	_player.rotation.y = 0.0
	_push_stick(Vector2(1.0, 0.0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var turned := absf(_player.rotation.y)
	var most := deg_to_rad(EXPECTED_TURN_RATE) * (3.0 / 60.0)
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
	_player.machine.current.transition_to(&"Attack", {"index": 0, "perfect": false})
	await get_tree().physics_frame
	# Read after the swing has entered, not before: entering is exactly when an attack takes the aim
	# in full, which is a bigger turn than before now that walking around leaves the body short of it.
	# The guarantee is that nothing steers the swing *after* that, which is what the rest measures.
	var committed := _player.rotation.y
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


## The assist, from `off` through to `strong`. It was a row in the options screen, a key in
## `Settings.DEFAULTS` and a value that persisted, and **nothing read it** — the failure the project
## calls worse than a missing setting, because a player who needs it sets it and believes they are
## covered.
##
## Every check below drives `AimComponent.direction()` with a real body on the island and a real
## stick push, and measures the angle that comes out.
func _check_the_assist_is_off_when_it_is_off() -> void:
	Settings.set_value(&"gameplay_aim_assist", "off")
	var off := await _aim_with_a_body_at(HALF_A_CONE)
	if absf(off) > deg_to_rad(1.0):
		_fail("with the assist off the aim moved %.1f° towards the body" % rad_to_deg(off))


## Halfway is the whole of what `soft` means: a player who was nearly lined up connects, and one who
## was not still misses. A setting that quietly snapped would be `strong` under another name.
##
## The share is written out for the same reason the cone is: reading `ASSIST_PULL` here meant that
## setting soft to 1.0 moved the expectation with it and the check went on passing.
func _check_soft_pulls_halfway_and_strong_goes_all_the_way() -> void:
	if not is_equal_approx(float(AimComponent.ASSIST_PULL["soft"]), EXPECTED_SOFT_PULL):
		_fail(
			(
				"soft pulls %.2f of the error and this check was written for %.2f"
				% [float(AimComponent.ASSIST_PULL["soft"]), EXPECTED_SOFT_PULL]
			)
		)
		return
	Settings.set_value(&"gameplay_aim_assist", "soft")
	var soft := await _aim_with_a_body_at(HALF_A_CONE)
	var wanted := HALF_A_CONE * EXPECTED_SOFT_PULL
	if absf(absf(soft) - wanted) > deg_to_rad(1.0):
		_fail(
			(
				"soft should pull %.1f° of the %.1f° error, it pulled %.1f°"
				% [rad_to_deg(wanted), rad_to_deg(HALF_A_CONE), rad_to_deg(absf(soft))]
			)
		)
	Settings.set_value(&"gameplay_aim_assist", "strong")
	var strong := await _aim_with_a_body_at(HALF_A_CONE)
	if absf(absf(strong) - HALF_A_CONE) > deg_to_rad(1.0):
		_fail(
			(
				"strong should land on the body %.1f° away, it pulled %.1f°"
				% [rad_to_deg(HALF_A_CONE), rad_to_deg(absf(strong))]
			)
		)


## Outside the cone the player was pointing somewhere else, and an assist that reached anyway would
## be choosing targets rather than steadying a hand.
##
## The angle is **written out rather than read off `AimComponent`**. A check that takes its bound
## from the thing it is checking agrees with whatever that thing says: opening the cone to forty
## degrees moved this test out to forty-six and it went on passing, which is a check that cannot
## fail. So the constant is asserted first, and the body stands at a fixed angle beyond it.
func _check_the_assist_ignores_what_the_player_is_not_aiming_at() -> void:
	if not is_equal_approx(AimComponent.ASSIST_CONE, EXPECTED_CONE):
		_fail(
			(
				(
					"the assist cone is %.0f° and this check was written for %.0f° — widen OUTSIDE_CONE "
					+ "deliberately or not at all"
				)
				% [AimComponent.ASSIST_CONE, EXPECTED_CONE]
			)
		)
		return
	Settings.set_value(&"gameplay_aim_assist", "strong")
	var pulled := await _aim_with_a_body_at(OUTSIDE_CONE)
	if absf(pulled) > deg_to_rad(1.0):
		_fail(
			(
				"a body %.0f° away is outside the %.0f° cone and the aim still moved %.1f°"
				% [rad_to_deg(OUTSIDE_CONE), EXPECTED_CONE, rad_to_deg(absf(pulled))]
			)
		)


## The fists reach 1.4 m. Being dragged round towards somebody eight metres off is the aim lying
## about what the player can do from here.
func _check_the_assist_cannot_reach_past_what_is_in_hand() -> void:
	Settings.set_value(&"gameplay_aim_assist", "strong")
	var pulled := await _aim_with_a_body_at(HALF_A_CONE, OUT_OF_REACH)
	if absf(pulled) > deg_to_rad(1.0):
		_fail(
			(
				"a body %.0f m away is past the fists' reach and the aim still moved %.1f°"
				% [OUT_OF_REACH, rad_to_deg(absf(pulled))]
			)
		)


## `EnemyDead` takes the body out of the `enemies` group the moment it dies, and that is the only
## thing standing between the assist and a corpse. Held here rather than assumed.
func _check_a_dead_body_stops_being_a_target() -> void:
	Settings.set_value(&"gameplay_aim_assist", "strong")
	var pulled := await _aim_with_a_body_at(HALF_A_CONE, IN_REACH, true)
	if absf(pulled) > deg_to_rad(1.0):
		_fail("the aim was pulled %.1f° onto a body that is dead" % rad_to_deg(absf(pulled)))


## Pushes the stick one way, stands a farmer that many radians off it, and returns how far the aim
## that comes back has moved towards him. Signed, so a pull the wrong way reads as a pull.
func _aim_with_a_body_at(offset: float, reach: float = IN_REACH, kill: bool = false) -> float:
	_reset()
	_push_stick(Vector2(1.0, 0.0))
	await get_tree().physics_frame
	var pointed := _screen_right()
	var standing := _player.global_position + pointed.rotated(Vector3.UP, offset) * reach
	var farmer := _stand_a_farmer_at(standing)
	if farmer == null:
		_fail("no farmer could be stood up for the assist checks")
		return 0.0
	if kill:
		# Through the real path: `is_alive` reads the health component, and a body killed any other
		# way would be a body this check invented a way of being dead for.
		farmer.hurtbox.take_hit(HitInfo.new(load(KILLING_BLOW) as AttackData, _player, false, 99.0))
	await get_tree().physics_frame
	var aimed := _player.aim.direction()
	farmer.retire()
	_push_stick(Vector2.ZERO)
	await get_tree().physics_frame
	return pointed.signed_angle_to(aimed, Vector3.UP)


## Placed rather than spawned: the spawn rules refuse anything this close to the player, and this is
## about the aim rather than about where a wave may arrive.
func _stand_a_farmer_at(where: Vector3) -> Enemy:
	var director := _arena.get_node_or_null(^"WaveDirector/SpawnDirector") as SpawnDirector
	var data := load(FARMHAND) as EnemyData
	if director == null or data == null:
		return null
	return director.spawn_at(data, where, 1.0, 1.0, 1.0, 1.0, null, true)


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
		print(
			(
				"aim OK — keys still walk, stick turns, cursor lands on the ground, attack commits, "
				+ "and the assist steadies a hand without choosing the target"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)


func _stand_the_tutorial_down(arena: Node) -> void:
	var tutorial := arena.get_node_or_null(^"TutorialDirector") as TutorialDirector
	if tutorial != null:
		tutorial.stand_down()


func _put_the_run_back() -> void:
	if _kept_run.is_empty():
		SaveManager.clear_run()
		return
	SaveManager.write_json(SaveManager.RUN_PATH, _kept_run)
