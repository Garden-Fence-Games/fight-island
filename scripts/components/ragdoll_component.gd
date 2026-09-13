class_name RagdollComponent
extends Node
## Hands a body over to the physics engine when it is knocked down, and takes it back when it stops
## moving.
##
## **The bones are built here rather than saved in the scene.** They have to be children of the
## `Skeleton3D`, and that skeleton lives inside the imported glTF — putting them in the scene file
## would mean editable children and the importer's node names pinned into it. Same reason the
## head-look builds its modifier in code, and the same benefit: the rig stays replaceable.
##
## **Sixteen bones, not thirty-three.** A Mixamo rig carries eight finger bones and four toe bones
## that no ragdoll has ever needed, and every one of them is a rigid body and a joint that Jolt has
## to solve. Dropping them halves the cost for a result nobody can tell apart from a fixed camera
## seventeen metres up.
##
## **Nothing animates while the physics has the body.** The simulator writes bone poses and so does
## an AnimationPlayer; the state is expected to stop naming a clip for the duration, which is what
## `EnemyStagger` does.

## Settled, and the body is ready to be handed back.
signal came_to_rest

## The bones worth simulating, hips first. Names are Mixamo's, with the colon the importer rewrites.
## Exported because a rig that is not Mixamo's will not agree, and because dropping a bone is a
## performance dial anyone can turn without reading this file.
@export var bones: Array[StringName] = [
	&"mixamorig_Hips",
	&"mixamorig_Spine",
	&"mixamorig_Spine1",
	&"mixamorig_Spine2",
	&"mixamorig_Neck",
	&"mixamorig_Head",
	&"mixamorig_LeftArm",
	&"mixamorig_LeftForeArm",
	&"mixamorig_RightArm",
	&"mixamorig_RightForeArm",
	&"mixamorig_LeftUpLeg",
	&"mixamorig_LeftLeg",
	&"mixamorig_LeftFoot",
	&"mixamorig_RightUpLeg",
	&"mixamorig_RightLeg",
	&"mixamorig_RightFoot",
]
## How wide a limb is, as a fraction of its own length. A capsule much fatter than this catches on
## its neighbours and the body jitters instead of falling.
@export var thickness: float = 0.28
## What the body collides with while it tumbles: the world, and nothing else. A ragdoll that pushed
## the player or the living would turn a knockdown into a shove nobody asked for.
@export_flags_3d_physics var collision_mask: int = PhysicsLayers.BIT_WORLD
## How much of the push goes upward. A blow travels flat, and a body shoved flat has its feet on the
## ground: the impulse goes straight into friction and a man who should have been sent sprawling
## shuffles four centimetres. Lifting him clear is what turns a shove into a knockdown.
@export_range(0.0, 1.5, 0.05) var lift: float = 0.55
## Under this speed for `stillness` seconds, the tumble is over.
@export var rest_speed: float = 0.35
@export var stillness: float = 0.35
## However heavy the hit, a body that never settles has to be taken back eventually — a corpse
## wedged against a rock would otherwise wait for ever. A backstop for a tumble that was given no
## ceiling of its own, not the figure a knockdown is meant to run to.
@export var longest: float = 3.0
## Which way a body lies once it has settled, so the right get-up can be played: the axis of the
## hips bone that points out of the belly, and the bone the head is. Measured on the farmer's rig
## standing, where the hips' own +Z faces the way he faces. A rig that is not Mixamo's will not
## agree, which is why they are exported rather than written into the reading.
@export var belly_axis: Vector3 = Vector3(0.0, 0.0, 1.0)
@export var head_bone: StringName = &"mixamorig_Head"

var _skeleton: Skeleton3D = null
var _simulator: PhysicalBoneSimulator3D = null
var _bodies: Array[PhysicalBone3D] = []
var _running: bool = false
var _still_for: float = 0.0
var _elapsed: float = 0.0
var _ceiling: float = 0.0


func _ready() -> void:
	_build.call_deferred()


## True once there is something to simulate. A rig whose bones did not resolve reports false rather
## than half-working, so a caller can fall back to the animation it had before.
func is_ready() -> bool:
	return _simulator != null and not _bodies.is_empty()


func is_running() -> bool:
	return _running


## Knocks the body down. `push` is in metres per second, applied along `direction` and shared by
## every bone so the whole body leaves together rather than tearing at the waist.
##
## `ceiling` is how long this particular tumble may run before the body is taken back whether it has
## settled or not. It is passed per knock rather than read off `longest` because **how long a man
## stays down is the blow's figure, not the ragdoll's** — a jab that tips him over and an uppercut
## that lifts him are not the same knockdown, and the difference is already tabled in the attack.
## Zero falls back to `longest`, which is what a caller with nothing to say should send.
func knock(direction: Vector3, push: float, ceiling: float = 0.0) -> void:
	if not is_ready() or _running:
		return
	_running = true
	_still_for = 0.0
	_elapsed = 0.0
	_ceiling = ceiling if ceiling > 0.0 else longest
	_simulator.physical_bones_start_simulation(bones)
	var flat := Vector3(direction.x, 0.0, direction.z)
	var impulse := flat.normalized() * push + Vector3.UP * push * lift
	for body: PhysicalBone3D in _bodies:
		body.linear_velocity = impulse
		body.angular_velocity = Vector3.ZERO


## Where the body ended up, taken from the hips rather than from the node that is no longer driving
## them. Returns the owner's own position when nothing is simulating, so a caller never has to ask.
func settled_position() -> Vector3:
	if _bodies.is_empty():
		var host := get_parent() as Node3D
		return host.global_position if host != null else Vector3.ZERO
	return _bodies[0].global_position


## Writes where the physics actually put the bones into the skeleton, so the pose survives the
## simulation ending.
##
## Needed because the simulator is a `SkeletonModifier3D`: its output reaches the skin, but the
## skeleton's own pose is only the animation's, and the moment it stops contributing the body snaps
## back upright. Anything that wants to keep the pose — a corpse, a screenshot — has to ask for it
## while the bodies are still where they landed, and the bodies are the only thing that knows.
func settle_pose() -> void:
	if _skeleton == null or _bodies.is_empty():
		return
	var into_skeleton := _skeleton.global_transform.affine_inverse()
	for body: PhysicalBone3D in _bodies:
		var bone := body.get_bone_id()
		if bone < 0:
			continue
		_skeleton.set_bone_global_pose(bone, into_skeleton * body.global_transform)


## Whether the body came to rest on its back rather than on its front.
##
## **Read off the physical bodies, not off the skeleton.** The simulator moves the bodies and the
## skeleton's own pose query goes on reporting the pose underneath — which, with no clip playing
## during a tumble, is a man standing to attention. Read that way every farmer in the game lay on
## his back. And it has to be asked **before** `stop()`, which hands the bones back standing.
func lies_face_up() -> bool:
	var hips := _body_of(bones[0] if not bones.is_empty() else &"")
	if hips == null:
		return true
	return (hips.global_basis * belly_axis).y >= 0.0


## Which way the head lies from the hips, flat along the ground, in world space. Zero when the rig
## has no head to ask. Same two rules as `lies_face_up`: the bodies, and before `stop()`.
func settled_heading() -> Vector3:
	var hips := _body_of(bones[0] if not bones.is_empty() else &"")
	var head := _body_of(head_bone)
	if hips == null or head == null:
		return Vector3.ZERO
	var flat := head.global_position - hips.global_position
	flat.y = 0.0
	return flat.normalized() if not flat.is_zero_approx() else Vector3.ZERO


## Takes the body back. Safe to call when nothing is running, which is what makes it the right thing
## for a pooled body to call on its way back into the world.
func stop() -> void:
	_running = false
	_still_for = 0.0
	_elapsed = 0.0
	if _simulator != null:
		_simulator.physical_bones_stop_simulation()
	if _skeleton != null:
		_skeleton.reset_bone_poses()


func _physics_process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	var fastest := 0.0
	for body: PhysicalBone3D in _bodies:
		fastest = maxf(fastest, body.linear_velocity.length())
	_still_for = _still_for + delta if fastest < rest_speed else 0.0
	if _still_for < stillness and _elapsed < _ceiling:
		return
	_running = false
	came_to_rest.emit()


func _build() -> void:
	var host := get_parent()
	if host == null:
		return
	_skeleton = _find_skeleton(host)
	if _skeleton == null:
		return
	_simulator = PhysicalBoneSimulator3D.new()
	_simulator.name = "Ragdoll"
	_skeleton.add_child(_simulator)
	for bone: StringName in bones:
		var made := _make_bone(bone)
		if made != null:
			_bodies.append(made)


## One rigid body for one bone, sized from the rest pose rather than from a table: a capsule whose
## length is guessed is a limb that either floats away from the mesh or spears through it.
func _make_bone(bone: StringName) -> PhysicalBone3D:
	var index := _skeleton.find_bone(String(bone))
	if index < 0:
		return null
	var length := _bone_length(index)
	if length <= 0.0:
		return null
	var body := PhysicalBone3D.new()
	body.name = String(bone)
	body.bone_name = String(bone)
	body.collision_layer = 0
	body.collision_mask = collision_mask
	body.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = maxf(length * thickness, 0.03)
	capsule.height = maxf(length, capsule.radius * 2.0 + 0.01)
	shape.shape = capsule
	# The capsule stands along the bone, and the bone's own axis is Y — so the shape is slid half a
	# length down it to sit between this joint and the next rather than straddling the joint.
	shape.position = Vector3(0.0, length * 0.5, 0.0)
	body.add_child(shape)
	_simulator.add_child(body)
	return body


## The distance to the first child that is also being simulated, which is what the capsule has to
## span. A bone at the end of a chain — a foot, the head — has none, so it takes its parent's length
## scaled down rather than a number invented here.
func _bone_length(index: int) -> float:
	var here := _skeleton.get_bone_global_rest(index).origin
	var longest_child := 0.0
	for child: int in _skeleton.get_bone_children(index):
		if not bones.has(StringName(_skeleton.get_bone_name(child))):
			continue
		var reach := (_skeleton.get_bone_global_rest(child).origin - here).length()
		longest_child = maxf(longest_child, reach)
	if longest_child > 0.0:
		return longest_child
	var parent := _skeleton.get_bone_parent(index)
	if parent < 0:
		return 0.2
	var from_parent := (here - _skeleton.get_bone_global_rest(parent).origin).length()
	return maxf(from_parent * 0.6, 0.08)


## The simulated body standing in for a bone, or null when that bone is not simulated.
func _body_of(bone: StringName) -> PhysicalBone3D:
	for body: PhysicalBone3D in _bodies:
		if StringName(body.bone_name) == bone:
			return body
	return null


func _find_skeleton(root: Node) -> Skeleton3D:
	for child: Node in root.get_children():
		var found := child as Skeleton3D
		if found != null:
			return found
		var deeper := _find_skeleton(child)
		if deeper != null:
			return deeper
	return null
