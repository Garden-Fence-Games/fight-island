extends Node
## Headless proof of the three assumptions the head-look rests on, each of which breaks silently.
##
## The rig faces -Z: the glTF convention puts a character's front at +Z and Godot's forward is -Z,
## the importer does not reconcile them, and the symptom is a character who aims out of his back.
## The head bone's forward is its own +Z: measured once, and a reimport is free to change it.
## The modifier is attached and clamped: a neck with no limit twists through 180 degrees.
## Run: godot --headless --path . res://tools/verify_head_look.tscn

const PLAYER: String = "res://scenes/actors/player.tscn"
const SETTLE_FRAMES: int = 8
const STICK_X: int = JOY_AXIS_RIGHT_X
const STICK_Y: int = JOY_AXIS_RIGHT_Y

var _failures: PackedStringArray = []


func _ready() -> void:
	_run()


func _run() -> void:
	var player := (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(player)
	# The head-look builds itself deferred — a parent mid-instantiation refuses add_child — so the
	# rig is not wired on the frame the player appears.
	for _index: int in 4:
		await get_tree().process_frame
		await get_tree().physics_frame

	var skel := _find_skeleton(player)
	if skel == null:
		_fail("no Skeleton3D under the player")
		_report()
		return

	_check_body_faces_minus_z(player, skel)
	_check_head_forward_is_plus_z(skel)
	var modifier := _check_modifier_attached(skel)
	if modifier != null:
		await _check_the_head_turns_and_stops(player, skel, modifier)
	_report()


## The bug this whole file exists for. Measured from the shoulders, in the player's own space.
func _check_body_faces_minus_z(player: Player, skel: Skeleton3D) -> void:
	var forward := _body_forward(player, skel)
	if forward.z > -0.5:
		_fail(
			(
				"the rig does not face -Z — forward is (%.2f, %.2f, %.2f). It aims out of its back."
				% [forward.x, forward.y, forward.z]
			)
		)


func _check_head_forward_is_plus_z(skel: Skeleton3D) -> void:
	var head := skel.find_bone("mixamorig_Head")
	if head < 0:
		_fail("no bone named mixamorig_Head — the importer renamed it")
		return
	# The model faces +Z inside the skeleton; the 180 that corrects it lives on the Visual node
	# above. So the head bone's forward has to agree with +Z there, not with the player's -Z.
	var rest := skel.get_bone_global_rest(head)
	if rest.basis.z.normalized().dot(Vector3(0.0, 0.0, 1.0)) < 0.9:
		_fail(
			(
				(
					"the head bone's +Z is no longer its forward — it is %s. LookAtModifier3D's"
					+ " forward_axis in head_look_component.gd needs to change with it."
				)
				% [rest.basis.z]
			)
		)


func _check_modifier_attached(skel: Skeleton3D) -> LookAtModifier3D:
	var modifier: LookAtModifier3D = null
	for child: Node in skel.get_children():
		var found := child as LookAtModifier3D
		if found != null:
			modifier = found
			break
	if modifier == null:
		_fail("the component built no LookAtModifier3D under the skeleton")
		return null
	if not modifier.use_angle_limitation:
		_fail("the head-look is unclamped — a neck that can reach 180 degrees is the Exorcist")
	if modifier.target_node.is_empty():
		_fail("the modifier has no target node")
	return modifier


## Aimed hard to each side with the body held still, the head must turn that way, and must stop
## before the limit. All three halves matter: no turn means the wiring is dead, a turn the wrong way
## means an axis is flipped, an unbounded one means the clamp is gone.
func _check_the_head_turns_and_stops(
	player: Player, skel: Skeleton3D, modifier: LookAtModifier3D
) -> void:
	# Read through a BoneAttachment3D, because `get_bone_global_pose` returns the animated pose
	# *before* skeleton modifiers run — it reports a perfectly still head no matter where the
	# modifier is actually pointing it. The attachment reports what the renderer draws.
	var probe := BoneAttachment3D.new()
	probe.name = "HeadProbe"
	skel.add_child(probe)
	probe.bone_name = "mixamorig_Head"

	var limit := modifier.primary_limit_angle
	var right := await _settled_yaw(player, probe, Vector2(1.0, 0.0))
	var left := await _settled_yaw(player, probe, Vector2(-1.0, 0.0))
	var centred := await _settled_yaw(player, probe, Vector2.ZERO)

	if right <= deg_to_rad(5.0):
		_fail(
			"aiming right turned the head %.1f° — it is not following the aim" % [rad_to_deg(right)]
		)
	if left >= deg_to_rad(-5.0):
		_fail("aiming left turned the head %.1f° — the yaw axis is flipped" % [rad_to_deg(left)])
	for yaw: float in [right, left]:
		if absf(yaw) > limit + deg_to_rad(5.0):
			_fail(
				(
					"the head turned %.1f°, past its %.1f° limit"
					% [rad_to_deg(absf(yaw)), rad_to_deg(limit)]
				)
			)
	# Not aiming has to cost the head nothing, or a pad player who never touches the right stick
	# spends the game with a crooked neck.
	if absf(centred) > deg_to_rad(5.0):
		_fail("with nothing aimed the head sits %.1f° off centre" % [rad_to_deg(centred)])

	probe.queue_free()


## Holds the stick and the body still until the modifier has settled, then reports the head's yaw
## relative to the body. Pinned every frame because the body chases the aim too, and a body that
## catches up leaves the head pointing straight ahead with nothing to measure.
func _settled_yaw(player: Player, probe: BoneAttachment3D, stick: Vector2) -> float:
	_push_stick(stick)
	for _index: int in 30:
		await get_tree().process_frame
		await get_tree().physics_frame
		player.rotation.y = 0.0
		player.global_position = Vector3.ZERO
		player.velocity = Vector3.ZERO
	var looking := (player.global_transform.affine_inverse() * probe.global_transform).basis.z
	looking = Vector3(looking.x, 0.0, looking.z).normalized()
	# The body's own forward in its own space is -Z by definition, so this is the offset from it.
	return angle_difference(atan2(-looking.x, -looking.z), 0.0)


func _body_forward(player: Player, skel: Skeleton3D) -> Vector3:
	var left := skel.find_bone("mixamorig_LeftShoulder")
	var right := skel.find_bone("mixamorig_RightShoulder")
	if left < 0 or right < 0:
		_fail("the shoulder bones are gone — the rig was replaced")
		return Vector3.ZERO
	var to_player := player.global_transform.affine_inverse() * skel.global_transform
	var l: Vector3 = to_player * skel.get_bone_global_pose(left).origin
	var r: Vector3 = to_player * skel.get_bone_global_pose(right).origin
	return (l - r).normalized().cross(Vector3.UP).normalized()


## Through the engine's own input path, like verify_aim: what breaks is the binding.
func _push_stick(stick: Vector2) -> void:
	for axis: int in [STICK_X, STICK_Y]:
		var event := InputEventJoypadMotion.new()
		event.device = 0
		event.axis = axis
		event.axis_value = stick.x if axis == STICK_X else stick.y
		Input.parse_input_event(event)


func _find_skeleton(root: Node) -> Skeleton3D:
	for child: Node in root.get_children():
		var found := child as Skeleton3D
		if found != null:
			return found
		var deeper := _find_skeleton(child)
		if deeper != null:
			return deeper
	return null


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	for _index: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	if _failures.is_empty():
		print("head look OK — rig faces -Z, head forward is +Z, modifier attached, turn clamped")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
