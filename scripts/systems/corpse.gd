class_name Corpse
extends Node3D
## One body lying where it fell, and still a body: walked into, it is shoved along; struck, it
## bleeds and moves.
##
## **Two states, and the difference is what a pile costs.** While it moves, a corpse is a skinned
## rig with a live ragdoll. Once it has been still for a moment it rests: the pose is baked into a
## static mesh with `PosedMesh`, and the skeleton — bodies, joints and all — is taken **out of the
## tree**, because a `Skeleton3D` in the tree costs about 0.4 ms a frame even when nothing moves it.
## A resting corpse is a picture and one area. Anything that touches it wakes it, and the skeleton
## goes back in exactly as it lay.
##
## **It lands on its own.** The corpse this replaced was a picture lifted onto the navigation mesh,
## which sits above the sand, so every body hovered and froze wherever the tumble's ceiling caught
## it. A corpse that keeps its physics until it is actually still has nothing to be lifted onto.

## What the tumble may run to before the body rests whether it is still or not: a body wedged
## against a rock would otherwise stay awake for ever.
const LONGEST_TUMBLE: float = 10.0

var ragdoll: RagdollComponent = null

var _skeleton: Skeleton3D = null
var _skeleton_home: Node = null
var _skinned: Array[MeshInstance3D] = []
var _pictures: Array[MeshInstance3D] = []
var _hurtbox: CorpseHurtbox = null
var _resting: bool = false
var _rested_at: Vector3 = Vector3.ZERO
## What the body occupies once it is still, in world metres. A man lying down is two metres of him
## and a third of a metre of hip, so a sphere about the hips is the wrong shape to ask "are you
## standing on this" with — it reaches over his head and stops short of his boots.
var _rested_box: AABB = AABB()
var _field: CorpseField = null


func _notification(what: int) -> void:
	# A resting corpse holds its skeleton out of the tree, where freeing the corpse does not reach it.
	if what == NOTIFICATION_PREDELETE and _resting and is_instance_valid(_skeleton):
		_skeleton.free()


func _physics_process(_delta: float) -> void:
	if _hurtbox != null and ragdoll != null:
		_hurtbox.global_position = ragdoll.settled_position()


## Builds the corpse around `copy`, a duplicate of the dying body's visual already stripped of
## everything that animated it, and takes over the tumble `living` is in.
func assemble(copy: Node3D, living: RagdollComponent, field: CorpseField) -> void:
	_field = field
	add_child(copy)
	copy.transform = Transform3D.IDENTITY
	_skeleton = Descend.first(copy, Skeleton3D) as Skeleton3D
	if _skeleton == null:
		return
	_skeleton_home = _skeleton.get_parent()
	for node: Node in _skeleton.find_children("*", "MeshInstance3D", true, false):
		var skinned := node as MeshInstance3D
		if skinned.skin != null:
			skinned.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_own_the_materials(skinned)
			_skinned.append(skinned)
	ragdoll = RagdollComponent.new()
	ragdoll.name = "Ragdoll"
	add_child(ragdoll)
	ragdoll.came_to_rest.connect(_on_ragdoll_came_to_rest)
	ragdoll.take_over(living, LONGEST_TUMBLE)
	_make_the_hurtbox()


func is_resting() -> bool:
	return _resting


## Where the body is: its hips, not this node, which stays where the body started falling.
func where() -> Vector3:
	if _resting or ragdoll == null:
		# Resting, the bodies are out of the tree and have no position to ask for.
		return _rested_at
	return ragdoll.settled_position()


## Whether feet at `feet` are near enough to this body to disturb it.
##
## **Asked before waking, which is the whole point.** Waking puts the skeleton back in the tree and
## restarts the tumble, and a body nobody can reach must not pay that to be pushed by nothing.
## Resting, the answer is its own bounds — the picture is exact and already built. Still moving, the
## bones are in the tree and `push_near` will sort out which of them are close, so the hips and a
## body's width are gate enough.
func reaches(feet: Vector3) -> bool:
	if _resting:
		return _rested_box.grow(_field.trample_reach).has_point(feet)
	var apart := where() - feet
	var near := _field.body_radius + _field.trample_reach
	return Vector2(apart.x, apart.z).length() < near and absf(apart.y) < near


## A foot at `feet` moving at `velocity` walks into the body.
func trample(feet: Vector3, velocity: Vector3) -> void:
	if ragdoll == null or not ragdoll.is_ready():
		return
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() < _field.trample_speed:
		return
	_wake()
	# The lift is a share of the shove rather than a figure of its own, so a body crossed slowly is
	# nudged and one crossed at a run is thrown. A constant lift meant the slowest contact the field
	# would admit still picked the body up as hard as a sprint did.
	var along := flat * _field.trample_share
	var shove := along + Vector3.UP * along.length() * _field.trample_lift
	ragdoll.push_near(feet + Vector3.UP * 0.3, shove, _field.trample_reach)


## A blow lands on the body. It is thrown along the blow, and it bleeds.
func strike(info: HitInfo) -> void:
	if ragdoll == null or not ragdoll.is_ready():
		return
	var at := where()
	var direction := info.direction
	if info.source != null and is_instance_valid(info.source):
		direction = at - info.source.global_position
	direction.y = 0.0
	direction = direction.normalized() if not direction.is_zero_approx() else Vector3.FORWARD
	_wake()
	var push := _field.struck_push * (_field.perfect_push_scale if info.perfect else 1.0)
	var shove := direction * push + Vector3.UP * push * _field.struck_lift
	ragdoll.push_near(at, shove, _field.struck_reach)
	EventBus.corpse_struck.emit(at, direction, info.perfect)


func _wake() -> void:
	if not _resting:
		return
	_resting = false
	_skeleton_home.add_child(_skeleton)
	for picture: MeshInstance3D in _pictures:
		picture.visible = false
	set_physics_process(true)
	ragdoll.wake(LONGEST_TUMBLE)


func _on_ragdoll_came_to_rest() -> void:
	ragdoll.rest_in_place()
	_rested_at = ragdoll.settled_position()
	_hurtbox.global_position = _rested_at
	_bake()
	_measure_the_picture()
	_skeleton_home.remove_child(_skeleton)
	set_physics_process(false)
	_resting = true


## The pose into static meshes, one per skinned mesh, reused from one rest to the next.
func _bake() -> void:
	for index: int in _skinned.size():
		var skinned := _skinned[index]
		var baked := PosedMesh.freeze(skinned, _skeleton)
		if baked == null:
			continue
		if index >= _pictures.size():
			var picture := MeshInstance3D.new()
			picture.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(picture)
			_pictures.append(picture)
		_pictures[index].mesh = baked
		_pictures[index].global_transform = skinned.global_transform
		_pictures[index].visible = true


## What the baked picture occupies, merged across its meshes. Read once, here, rather than every
## frame the player walks near: it is a still picture and it does not move again until something
## wakes it.
func _measure_the_picture() -> void:
	_rested_box = AABB()
	var found := false
	for picture: MeshInstance3D in _pictures:
		if picture.mesh == null or not picture.visible:
			continue
		var here := picture.global_transform * picture.mesh.get_aabb()
		_rested_box = here if not found else _rested_box.merge(here)
		found = true
	if not found:
		# Nothing baked, so fall back to something that is at least the right place: a body's width
		# about the hips, which is the gate this replaced.
		_rested_box = AABB(_rested_at, Vector3.ZERO).grow(_field.body_radius)


## The body's own copy of what it wears. The dying enemy's materials are per instance and that
## instance goes back to the pool: the next farmer out of it, tinted for his rank, would re-tint
## every corpse he was ever copied into.
func _own_the_materials(skinned: MeshInstance3D) -> void:
	for surface: int in skinned.get_surface_override_material_count():
		var worn := skinned.get_active_material(surface)
		if worn != null:
			skinned.set_surface_override_material(surface, worn.duplicate() as Material)


func _make_the_hurtbox() -> void:
	_hurtbox = CorpseHurtbox.new()
	_hurtbox.name = "Hurtbox"
	_hurtbox.corpse = self
	_hurtbox.collision_layer = PhysicsLayers.BIT_ENEMY_HURTBOX
	_hurtbox.collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = _field.body_radius
	shape.shape = sphere
	_hurtbox.add_child(shape)
	add_child(_hurtbox)
	_hurtbox.global_position = where()
