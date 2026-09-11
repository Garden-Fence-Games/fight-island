class_name HeadLookComponent
extends Node
## The head follows the aim while the rest of the body does whatever its clip says.
##
## Mixamo hands over full-body clips and nothing else; the split between what the legs do and what
## the head does is made here, at runtime, on one skeleton. This is the cheapest half of that idea:
## a single bone driven by a `LookAtModifier3D`, no `AnimationTree`, no filtered blend, no second
## set of clips to author. The torso split is the same idea one layer up and can be added later
## without moving this.
##
## **The modifier is built in code rather than saved in the scene.** It has to be a child of the
## `Skeleton3D`, and that skeleton lives inside the imported glTF scene — putting it in `player.tscn`
## would mean enabling editable children and pinning the importer's node names into the scene file.
## Building it here keeps the rig replaceable.
##
## **The turn is clamped.** A player running north while aiming south would otherwise twist the neck
## through 180 degrees, which is the Exorcist and not a character. Past the limit the head simply
## stops and the body is what carries the rest of the turn.

## Mixamo's colon is not legal in a Godot bone name, so the importer rewrites `mixamorig:Head` as
## this. Exported because the farmer rig will not necessarily agree.
@export var bone_name: StringName = &"mixamorig_Head"
## How far past the body's own facing the head may turn before it gives up and waits for the body.
## Fifty-five degrees is inside what a neck does; past roughly sixty it reads as an injury.
@export_range(0.0, 90.0, 1.0, "degrees") var limit_degrees: float = 55.0
## Where the clamp starts easing rather than hitting a wall, as a fraction of the limit.
@export_range(0.0, 1.0, 0.05) var damp_threshold: float = 0.7
## Seconds the head takes to catch up. Zero snaps, which reads as a twitch on a fixed camera.
@export var duration: float = 0.12
## How far along the aim the look target is placed. Far enough that the direction dominates and the
## head does not converge on a point in front of its own face.
@export var reach: float = 12.0

var _skeleton: Skeleton3D = null
var _aim: AimComponent = null
var _modifier: LookAtModifier3D = null
var _target: Node3D = null
var _body: Node3D = null


## Deferred, and that is not a detail: a parent is still setting up its children while their
## `_ready` runs, so `add_child` on it fails outright and leaves the target adrift outside the tree
## with no transform. The symptom is a head that never moves.
func _ready() -> void:
	_build.call_deferred()


func _build() -> void:
	_body = get_parent() as Node3D
	if _body == null:
		return
	_skeleton = _find_skeleton(_body)
	_aim = _find_aim(_body)
	if _skeleton == null or _skeleton.find_bone(String(bone_name)) < 0:
		return

	var target := Node3D.new()
	target.name = "HeadLookTarget"
	# Under the owner rather than under the skeleton: a target parented to the bone it steers is a
	# feedback loop, and the head chases its own tail.
	_body.add_child(target)

	_modifier = LookAtModifier3D.new()
	_modifier.name = "HeadLook"
	_modifier.bone_name = String(bone_name)
	# The rig's head bone points along its own +Z, measured rather than assumed — see
	# tools/verify_head_look.tscn, which fails if a reimport changes it.
	_modifier.forward_axis = SkeletonModifier3D.BONE_AXIS_PLUS_Z
	# Yaw only, and no secondary rotation: the camera looks down from a fixed angle, so a head that
	# is free to pitch buys nothing and costs the face, which is the one thing worth seeing.
	_modifier.primary_rotation_axis = Vector3.AXIS_Y
	_modifier.use_secondary_rotation = false
	_modifier.origin_safe_margin = 0.01
	_modifier.duration = duration
	_modifier.use_angle_limitation = true
	_modifier.symmetry_limitation = true
	_modifier.primary_limit_angle = deg_to_rad(limit_degrees)
	_modifier.primary_damp_threshold = damp_threshold
	_skeleton.add_child(_modifier)
	_modifier.target_node = _modifier.get_path_to(target)
	# Assigned last: `_process` treats a null target as "not wired yet", so nothing reads a
	# half-built rig.
	_target = target


## Visuals, so `_process` rather than `_physics_process` — nothing about where the head points is
## read by hit registration.
func _process(_delta: float) -> void:
	if _target == null or _skeleton == null:
		return
	if not _target.is_inside_tree() or not _skeleton.is_inside_tree():
		return
	var head := _skeleton.find_bone(String(bone_name))
	if head < 0:
		return
	var origin := _skeleton.global_transform * _skeleton.get_bone_global_pose(head).origin
	_target.global_position = origin + _look_direction() * reach


## Flat on purpose. The aim is a ground direction and the camera is overhead: letting the head pitch
## towards a point on the floor would hide the face in the one view the game ever uses.
func _look_direction() -> Vector3:
	var aimed := _aim.direction() if _aim != null else Vector3.ZERO
	if not aimed.is_zero_approx():
		return Vector3(aimed.x, 0.0, aimed.z).normalized()
	# Not aiming means "look where the body looks", which costs the head no rotation at all.
	var forward := -_body.global_transform.basis.z
	return Vector3(forward.x, 0.0, forward.z).normalized()


func _find_skeleton(root: Node) -> Skeleton3D:
	for child: Node in root.get_children():
		var found := child as Skeleton3D
		if found != null:
			return found
		var deeper := _find_skeleton(child)
		if deeper != null:
			return deeper
	return null


func _find_aim(root: Node) -> AimComponent:
	for child: Node in root.get_children():
		var found := child as AimComponent
		if found != null:
			return found
	return null
