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
##
## **A body, not a sock.** Every bone used to be a one-kilogram capsule a few centimetres across on
## the same loose cone, and the build-6 capture showed what that does: a farmer folded like cloth,
## his skin went a metre into the sand while the capsules inside it rested on top, and his corpse
## was baked from that. So, from `RagdollData`:
##
## - each bone weighs its anthropometric share of the body;
## - each capsule is **fitted to the vertices that bone actually carries**, so the body the physics
##   rests on the sand is the body the player sees;
## - each joint is a 6DOF limited in an anatomical frame — a knee folds back and not forward, a neck
##   does not turn the head round — with ranges that contain every pose the rig is animated in.
##
## **A joint's limits are measured from the pose the simulation starts in.** Measured, not assumed:
## a knee locked solid on a body knocked while sitting stayed bent at 31°. So the simulation starts
## with the skeleton at rest and every body is put straight back where the animation had it, which a
## locked joint was measured to pull back to its rest angle — the ranges then mean what they say.

## The physics has the body. Announced rather than left to be noticed, because whatever else was
## posing this skeleton has to let go of it in the same frame — a clip still running writes bone
## poses after the simulator does, and the tumble simply does not happen.
signal took_the_body
## Settled, and the body is ready to be handed back.
signal came_to_rest

## Capsules fitted per mesh, so a pool of thirty-two bodies on one model reads its vertices once.
static var _fitted: Dictionary[String, Dictionary] = {}

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
## What the body is made of: weights, joint ranges, damping, and how capsules are fitted.
@export var data: RagdollData = preload("res://data/combat/ragdoll_human.tres")
## How wide a limb is as a fraction of its own length, for a bone the mesh gives no vertices to fit.
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
## The bones a recoil runs through. The shooting arm and nothing above it: a kick that reached the
## spine would rock a body the player is still steering. The hand is left out on purpose: the gun
## hangs off it, and an animated hand is what keeps the revolver in the fist while the arm goes.
@export var kick_bones: Array[StringName] = [&"mixamorig_RightArm", &"mixamorig_RightForeArm"]

var _skeleton: Skeleton3D = null
var _simulator: PhysicalBoneSimulator3D = null
var _bodies: Array[PhysicalBone3D] = []
var _running: bool = false
var _still_for: float = 0.0
var _elapsed: float = 0.0
var _ceiling: float = 0.0
var _kick_left: float = 0.0
var _kick_lasts: float = 0.0


func _ready() -> void:
	_build.call_deferred()


## True once there is something to simulate. A rig whose bones did not resolve reports false rather
## than half-working, so a caller can fall back to the animation it had before.
func is_ready() -> bool:
	return _simulator != null and not _bodies.is_empty()


func is_running() -> bool:
	return _running


## The physics has an arm. Deliberately not `is_running`: a recoil is not a knockdown, the clip
## underneath it keeps playing, and whatever asks whether the body has been taken over has to go on
## getting no for the whole of a shot.
func is_kicking() -> bool:
	return _kick_left > 0.0


## A recoil. The shooting arm goes to the physics for `seconds`, thrown along `direction` at `push`
## metres per second, and the simulator's influence falls from one to nought across that window so
## the arm eases back onto the clip rather than snapping onto it.
##
## **Only the named bones simulate.** Everything else stays kinematic and goes on taking its pose
## from the AnimationPlayer, so the player keeps standing, walking and aiming through the shot — the
## arm is jointed to a shoulder that is still being animated, which is the shape a recoil has.
##
## **And the clip must not pose those bones.** An AnimationPlayer and a skeleton modifier both write
## bone poses and the clip wins: with the arm still in `aim_gun`, the physical body swung five
## centimetres and the skin moved two millimetres. `tools/build_clips.gd` leaves the two joints out
## of the clip entirely and `verify_clips` holds it there.
func kick(direction: Vector3, push: float, seconds: float) -> void:
	if not is_ready() or _running or is_kicking() or seconds <= 0.0:
		return
	_start_from_rest(kick_bones)
	var impulse := direction.normalized() * push
	for named: StringName in kick_bones:
		var body := body_of(named)
		if body == null:
			continue
		body.linear_velocity = impulse
		body.angular_velocity = Vector3.ZERO
	_kick_lasts = seconds
	_kick_left = seconds
	_simulator.influence = 1.0


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
	# **A recoil gives way to a knockdown.** The kick is two bones twitching for a tenth of a second
	# and it owns `_physics_process` while it lasts — so a knock started inside one is never
	# advanced, and the kick running out then fades the simulator to nothing and stops the
	# simulation this call is about to begin. Dying in the six frames after firing left the body
	# standing frozen instead of falling.
	_drop_the_kick()
	_begin(ceiling)
	_start_from_rest()
	took_the_body.emit()
	var flat := Vector3(direction.x, 0.0, direction.z)
	var impulse := flat.normalized() * push + Vector3.UP * push * lift
	for body: PhysicalBone3D in _bodies:
		body.linear_velocity = impulse
		body.angular_velocity = Vector3.ZERO


## Carries on the tumble another ragdoll is in: every body starts where that one's is, moving the
## way it moves. How a corpse takes a body over from the enemy going back to the pool, without the
## fall stopping or starting again.
func take_over(from: RagdollComponent, ceiling: float = 0.0) -> void:
	if _simulator == null:
		_build()
	if not is_ready() or from == null or not from.is_ready():
		return
	_begin(ceiling)
	_skeleton.reset_bone_poses()
	_simulator.physical_bones_start_simulation(bones)
	for body: PhysicalBone3D in _bodies:
		var source := from.body_of(StringName(body.bone_name))
		if source == null:
			continue
		body.global_transform = source.global_transform
		body.linear_velocity = source.linear_velocity
		body.angular_velocity = source.angular_velocity


## Starts the physics again from the pose the body is lying in, still. What wakes a corpse that was
## resting; `push_near` is what then moves it.
func wake(ceiling: float = 0.0) -> void:
	if not is_ready() or _running:
		return
	_begin(ceiling)
	_start_from_rest()
	for body: PhysicalBone3D in _bodies:
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO


## Moves the bodies within `reach` of `point` at `velocity`, the nearest most. Raises a body's speed
## along the push to it rather than adding to it, so a foot pressed against a body for twenty frames
## carries it along instead of launching it.
func push_near(point: Vector3, velocity: Vector3, reach: float) -> void:
	if not _running or velocity.is_zero_approx():
		return
	var heading := velocity.normalized()
	for body: PhysicalBone3D in _bodies:
		var apart := body.global_position.distance_to(point)
		if apart > reach:
			continue
		var wanted := velocity * clampf(1.0 - apart / reach, 0.35, 1.0)
		var already := body.linear_velocity.dot(heading)
		if already < wanted.length():
			body.linear_velocity += heading * (wanted.length() - already)


## Ends the simulation **keeping** the pose, where `stop` hands the bones back standing. What a
## corpse calls once it is still, before it bakes itself into a picture.
func rest_in_place() -> void:
	settle_pose()
	_running = false
	_still_for = 0.0
	if _simulator != null:
		_simulator.physical_bones_stop_simulation()


## The simulated body standing in for a bone, or null when that bone is not simulated.
func body_of(bone: StringName) -> PhysicalBone3D:
	for body: PhysicalBone3D in _bodies:
		if StringName(body.bone_name) == bone:
			return body
	return null


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
	var hips := body_of(bones[0] if not bones.is_empty() else &"")
	if hips == null:
		return true
	return (hips.global_basis * belly_axis).y >= 0.0


## Which way the head lies from the hips, flat along the ground, in world space. Zero when the rig
## has no head to ask. Same two rules as `lies_face_up`: the bodies, and before `stop()`.
func settled_heading() -> Vector3:
	var hips := body_of(bones[0] if not bones.is_empty() else &"")
	var head := body_of(head_bone)
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
	_kick_left = 0.0
	if _simulator != null:
		_simulator.influence = 1.0
		_simulator.physical_bones_stop_simulation()
	if _skeleton != null:
		_skeleton.reset_bone_poses()


func _physics_process(delta: float) -> void:
	if _kick_left > 0.0:
		_carry_the_kick(delta)
		return
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


## The recoil running out. The influence is what the arm comes back on: at nought the modifier
## writes nothing and the bone is the clip's again, so the last frame of the kick and the first
## frame after it are the same pose.
func _carry_the_kick(delta: float) -> void:
	_kick_left = maxf(_kick_left - delta, 0.0)
	if _simulator == null:
		return
	_simulator.influence = _kick_left / maxf(_kick_lasts, 0.001)
	if _kick_left > 0.0:
		return
	_simulator.physical_bones_stop_simulation()
	_simulator.influence = 1.0


func _begin(ceiling: float) -> void:
	_running = true
	_still_for = 0.0
	_elapsed = 0.0
	_ceiling = ceiling if ceiling > 0.0 else longest


## The simulation started with the skeleton at rest, then every body put back where the animation
## had it. See the class notes for why the joints need the rest pose to be their zero.
## **Every** body is put back where the animation had it, whatever subset is being simulated: the
## ones left kinematic are what the simulated ones are jointed to.
func _start_from_rest(which: Array[StringName] = bones) -> void:
	var into_world := _skeleton.global_transform
	var posed: Array[Transform3D] = []
	for body: PhysicalBone3D in _bodies:
		posed.append(into_world * _skeleton.get_bone_global_pose(body.get_bone_id()))
	_skeleton.reset_bone_poses()
	_simulator.physical_bones_start_simulation(which)
	for index: int in _bodies.size():
		_bodies[index].global_transform = posed[index]


func _build() -> void:
	var host := get_parent()
	if host == null or _simulator != null:
		return
	_skeleton = _find_skeleton(host)
	if _skeleton == null:
		return
	_simulator = PhysicalBoneSimulator3D.new()
	_simulator.name = "Ragdoll"
	_skeleton.add_child(_simulator)
	var fits := _fit_capsules(host)
	var share_total := 0.0
	if data != null:
		for bone: StringName in bones:
			share_total += data.shares.get(bone, 0.0)
	for bone: StringName in bones:
		var made := _make_bone(bone, fits.get(bone, Vector3.ZERO), share_total)
		if made != null:
			_bodies.append(made)


## One rigid body for one bone: its share of the body's weight, a capsule fitted to the mesh around
## it, and a joint to its parent limited in an anatomical frame.
func _make_bone(bone: StringName, fit: Vector3, share_total: float) -> PhysicalBone3D:
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
	if data != null:
		var share: float = data.shares.get(bone, 0.0)
		body.mass = maxf(data.body_mass * share / maxf(share_total, 0.001), 0.5)
		body.angular_damp = data.angular_damp
		body.linear_damp = data.linear_damp
		body.friction = data.friction
		body.bounce = data.bounce
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	# `fit` is the radius, then where the capsule starts and ends along the bone. Zero means the mesh
	# gave this bone nothing to fit to, and the old proportion stands in.
	if fit.x > 0.0:
		capsule.radius = fit.x
		capsule.height = maxf(fit.z - fit.y, capsule.radius * 2.0 + 0.01)
		shape.position = Vector3(0.0, (fit.y + fit.z) * 0.5, 0.0)
	else:
		capsule.radius = maxf(length * thickness, 0.03)
		capsule.height = maxf(length, capsule.radius * 2.0 + 0.01)
		shape.position = Vector3(0.0, length * 0.5, 0.0)
	shape.shape = capsule
	body.add_child(shape)
	_shape_the_joint(body, index)
	_simulator.add_child(body)
	return body


## The joint to the parent bone as a 6DOF, turned so its X is the axis the bone flexes about, its Y
## the bone itself and its Z across — then limited from `RagdollData`. A bone whose parent is not
## simulated is the root and has no joint.
func _shape_the_joint(body: PhysicalBone3D, index: int) -> void:
	# The nearest simulated ancestor, not the direct parent: an arm's parent is a shoulder nobody
	# simulates, and taking that as "no parent" cut both arms loose from the body.
	var ancestor := _skeleton.get_bone_parent(index)
	while ancestor >= 0 and not bones.has(StringName(_skeleton.get_bone_name(ancestor))):
		ancestor = _skeleton.get_bone_parent(ancestor)
	if ancestor < 0:
		body.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
		return
	# Keyed by StringName, and `bone_name` is a String: looked up as it is, every joint would miss and
	# quietly take the default range.
	var limits: JointLimits = (
		data.joints.get(StringName(body.bone_name), null) if data != null else null
	)
	if limits == null:
		limits = JointLimits.new()
	body.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
	body.joint_rotation = _anatomical_frame(index, limits.bends_back).get_euler()
	var ranges := {
		"x": limits.flex,
		"y": Vector2(-limits.twist, limits.twist),
		"z": limits.side,
	}
	for axis: String in ranges:
		var span: Vector2 = ranges[axis]
		body.set("joint_constraints/%s/angular_limit_enabled" % axis, true)
		body.set("joint_constraints/%s/angular_limit_lower" % axis, deg_to_rad(span.x))
		body.set("joint_constraints/%s/angular_limit_upper" % axis, deg_to_rad(span.y))


## A bone's anatomical frame, in its own local space. X is the axis that swings its tip towards the
## body's front — the back, for a knee — Y is the bone, Z is X across Y.
##
## The front is the hips' own +Z at rest, which is what `belly_axis` already says: measured on this
## rig, not assumed from a convention.
func _anatomical_frame(index: int, bends_back: bool) -> Basis:
	var hips := _skeleton.find_bone(String(bones[0]))
	var front := (_skeleton.get_bone_global_rest(hips).basis * belly_axis).normalized()
	var rest := _skeleton.get_bone_global_rest(index).basis.orthonormalized()
	var along := rest.y.normalized()
	var flex := along.cross(-front if bends_back else front)
	if flex.length() < 0.2:
		# A bone pointing straight at the front has no flexion axis to speak of; its own X will do.
		flex = rest.x
	var local_x := (rest.inverse() * flex.normalized()).normalized()
	local_x = (local_x - Vector3.UP * local_x.dot(Vector3.UP)).normalized()
	return Basis(local_x, Vector3.UP, local_x.cross(Vector3.UP).normalized())


## Each simulated bone's capsule fitted to the mesh: radius, then start and end along the bone, as a
## `Vector3`. Every skinned vertex is given to the simulated bone it hangs from most heavily — a
## hand's vertices to its forearm, a hat's to the head — and the capsule has to reach `fit_share` of
## them.
##
## Read in the rest pose, where a vertex is its bind pose undone, and cached per mesh.
func _fit_capsules(host: Node) -> Dictionary:
	var meshes: Array[MeshInstance3D] = []
	for node: Node in host.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh != null and mesh.skin != null and mesh.mesh != null:
			meshes.append(mesh)
	if meshes.is_empty() or data == null:
		return {}
	var key := (
		"%s|%d|%s" % [meshes[0].mesh.resource_path, _skeleton.get_bone_count(), ",".join(bones)]
	)
	if _fitted.has(key):
		return _fitted[key]
	var owners := _simulated_owners()
	var distances: Dictionary = {}
	var alongs: Dictionary = {}
	for mesh: MeshInstance3D in meshes:
		_gather(mesh, owners, distances, alongs)
	if distances.is_empty():
		# Not cached: an empty fit is a mesh that could not be read, and the thickness fallback
		# should not outlive whatever was wrong with it.
		return {}
	var fits: Dictionary = {}
	for bone: StringName in distances:
		var reach: Array[float] = distances[bone]
		var along: Array[float] = alongs[bone]
		# Not sorted in place: the two lists pair up vertex by vertex.
		if reach.size() < 8:
			continue
		var sorted := along.duplicate()
		sorted.sort()
		var start: float = sorted[int((sorted.size() - 1) * 0.03)]
		var end: float = sorted[int((sorted.size() - 1) * 0.97)]
		# The radius against the span the vertices actually cover, not against the bone: the farmer's
		# head bone is eight centimetres long under a head a metre tall, and measured from the bone
		# every vertex of it was far away.
		var off_span: Array[float] = []
		for vertex: int in reach.size():
			var beyond := maxf(maxf(start - along[vertex], along[vertex] - end), 0.0)
			off_span.append(Vector2(reach[vertex], beyond).length())
		off_span.sort()
		var radius := off_span[int((off_span.size() - 1) * data.fit_share)]
		fits[bone] = Vector3(maxf(radius, data.smallest_radius), start, end)
	_fitted[key] = fits
	return fits


## Every vertex of one mesh, given to its heaviest simulated bone: how far it sits off that bone's
## axis, and how far along it.
func _gather(
	mesh: MeshInstance3D, owners: PackedInt32Array, distances: Dictionary, alongs: Dictionary
) -> void:
	var skin := mesh.skin
	var bind_bones := PackedInt32Array()
	for bind: int in skin.get_bind_count():
		var bone := skin.get_bind_bone(bind)
		if bone < 0:
			bone = _skeleton.find_bone(skin.get_bind_name(bind))
		bind_bones.append(bone)
	for surface: int in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if vertices.is_empty() or indices.is_empty():
			continue
		var per_vertex := indices.size() / vertices.size()
		for vertex: int in vertices.size():
			var heaviest := 0
			for slot: int in per_vertex:
				if weights[vertex * per_vertex + slot] > weights[vertex * per_vertex + heaviest]:
					heaviest = slot
			var bind := indices[vertex * per_vertex + heaviest]
			if bind < 0 or bind >= bind_bones.size() or bind_bones[bind] < 0:
				continue
			var skeleton_bone := bind_bones[bind]
			var carrier := owners[skeleton_bone]
			if carrier < 0:
				continue
			var at := (
				_skeleton.get_bone_global_rest(skeleton_bone)
				* skin.get_bind_pose(bind)
				* vertices[vertex]
			)
			var rest := _skeleton.get_bone_global_rest(carrier)
			var axis := rest.basis.y.normalized()
			var along := (at - rest.origin).dot(axis)
			var nearest := rest.origin + axis * along
			var carried := StringName(_skeleton.get_bone_name(carrier))
			# Typed arrays, not packed ones. A packed array is a value: appending to the one read out
			# of the dictionary appended to a copy, and every bone came back with nothing to fit.
			if not distances.has(carried):
				distances[carried] = [] as Array[float]
				alongs[carried] = [] as Array[float]
			(distances[carried] as Array[float]).append(at.distance_to(nearest))
			(alongs[carried] as Array[float]).append(along)


## For every bone of the skeleton, the index of the simulated bone it belongs to — itself, or its
## nearest simulated ancestor — or -1 when there is none.
func _simulated_owners() -> PackedInt32Array:
	var owners := PackedInt32Array()
	owners.resize(_skeleton.get_bone_count())
	for bone: int in _skeleton.get_bone_count():
		var walk := bone
		while walk >= 0 and not bones.has(StringName(_skeleton.get_bone_name(walk))):
			walk = _skeleton.get_bone_parent(walk)
		owners[bone] = walk
	return owners


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


func _find_skeleton(root: Node) -> Skeleton3D:
	for child: Node in root.get_children():
		var found := child as Skeleton3D
		if found != null:
			return found
		var deeper := _find_skeleton(child)
		if deeper != null:
			return deeper
	return null


## Ends a recoil without letting it put the arm back, for a caller that is about to take the whole
## body. The influence goes back up rather than down: what follows wants the simulation, not the
## clip.
func _drop_the_kick() -> void:
	_kick_left = 0.0
	_kick_lasts = 0.0
	if _simulator != null:
		_simulator.influence = 1.0
