class_name CorpseField
extends Node3D
## The bodies that stay where they fell.
##
## A wave is a fight you win by killing everybody in it, and until now the evidence sank into the
## sand. The pile is the record: by wave ten the island should look like what has happened on it.
##
## **A corpse is not an enemy.** The bodies are pooled — thirty-two of them, leased and handed back
## — and a run of fifteen waves kills several hundred. Keeping each one alive as a `CharacterBody3D`
## with a state machine, two areas, a navigation agent and a ragdoll would be several hundred of all
## of those, and the pool could never reclaim any of them. So what is kept is the **picture**: the
## visual, duplicated, with the pose it died in baked into it, and nothing else. No script, no
## collision, no physics, no navigation, no sound.
##
## **There is a ceiling, and it is measured rather than hoped for.** A duplicated rig is a skinned
## mesh, and a skinned mesh is not free even when nothing moves it. Past the ceiling the oldest
## corpse goes, which is the right one to lose: the pile near the player is what they just did, and
## the one at the far end is from a wave they have stopped thinking about.

## How many bodies may lie on the island at once. Measured with `tools/stress_corpses.tscn` rather
## than picked: see `docs/architecture.md`. Past this the oldest goes.
@export var most: int = 48
## How far a corpse may be pushed up out of the sand if it settled below it. The ragdoll lands on
## the world layer so it should not sink at all, but a limb that ends the tumble inside a slope is a
## body half-swallowed, and half-swallowed reads as a bug rather than as a corpse.
@export var clearance: float = 0.05

var _laid: Array[Node3D] = []


func _ready() -> void:
	add_to_group(&"corpses")


## Lays a body down where it fell, and returns the corpse. Null when there is nothing to copy, which
## is what a body with no rig gives — the capsule prototype did, and a check runs against a rig.
##
## The pose is read off the skeleton **now**, because the caller is about to hand the body back to
## the pool and the pool resets it.
func lay(body: Node3D) -> Node3D:
	var visual := body.get_node_or_null(^"Visual") as Node3D
	if visual == null:
		return null
	var corpse := visual.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
	if corpse == null:
		return null
	add_child(corpse)
	corpse.global_transform = visual.global_transform
	_freeze(corpse, _skeleton_in(visual))
	_settle(corpse)
	_strip(corpse)
	_laid.append(corpse)
	_make_room()
	return corpse


## How many are lying there. Read by the headless check, which cannot see a pile but can count one.
func count() -> int:
	return _laid.size()


## Everything goes. A new run starts on a clean island — the pile is this run's record, and
## inheriting the last one's would be the game telling the player about somebody else.
func clear_field() -> void:
	for corpse: Node3D in _laid:
		if is_instance_valid(corpse):
			corpse.queue_free()
	_laid.clear()


## Out of the ground if it ended up in it.
##
## **Measured on the mesh, not on the origin.** The origin of a rig is between its feet, and a body
## baked lying down has its geometry somewhere else entirely — lifting the origin to the sand left
## the shoulder buried, which is what "he sinks a little" looks like. What has to clear the ground
## is the lowest vertex there is.
func _settle(corpse: Node3D) -> void:
	var box := _box_of(corpse)
	if box.size == Vector3.ZERO:
		return
	var ground := Ground.closest_point(get_world_3d(), box.get_center())
	if ground == Vector3.INF:
		return
	var lift := (ground.y + clearance) - box.position.y
	if lift > 0.0:
		corpse.global_position.y += lift


## What the corpse actually occupies, in world metres, taken off the baked meshes. A corpse has no
## collision shape to ask, which is the whole point of it.
func _box_of(corpse: Node3D) -> AABB:
	var box := AABB()
	var found := false
	for node: Node in _everything_under(corpse):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		var here := mesh.global_transform * mesh.mesh.get_aabb()
		box = here if not found else box.merge(here)
		found = true
	return box if found else AABB()


## The pose baked into the vertices, and the skeleton thrown away.
##
## This is the whole reason a corpse is affordable. A `Skeleton3D` updates its bone transforms on an
## engine notification rather than in `_process`, so a stripped, disabled, physics-free duplicate
## still cost about 0.4 ms a frame — sixteen bodies came to 15 ms of a 16.7 ms frame. Frozen, a
## corpse is a static mesh: one draw call and nothing per frame at all.
func _freeze(corpse: Node3D, posed: Skeleton3D) -> void:
	var skeleton := _skeleton_in(corpse)
	if skeleton == null or posed == null:
		return
	# The whole corpse, not just the skeleton's children. A duplicated instanced scene does not
	# always keep the mesh where the original had it, and a bake that searched only under the
	# skeleton found nothing, baked nothing, and then freed the skeleton anyway — which is a rig
	# skinned to a bone that no longer exists, and draws standing to attention.
	var baked_any := false
	for node: Node in _everything_under(corpse):
		var skinned := node as MeshInstance3D
		if skinned == null or skinned.skin == null:
			continue
		# Baked against the **living** skeleton, not the copy. A duplicate carries the rest pose: a
		# `PhysicalBoneSimulator3D` writes global pose overrides into the skeleton it is driving, and
		# none of that is in the scene data being copied. Reading the copy gave twenty-two farmers
		# standing to attention around the player.
		var baked := PosedMesh.freeze(skinned, posed)
		if baked == null:
			continue
		# Out of the skeleton before it is freed, and standing where the skeleton had it.
		var stood := skinned.global_transform
		skinned.reparent(corpse, false)
		skinned.global_transform = stood
		skinned.mesh = baked
		skinned.skin = null
		skinned.skeleton = NodePath()
		baked_any = true
	# Only once something is standing on its own. A skeleton freed under a mesh that still needs it
	# is the standing-to-attention bug, and it is better to pay for a skeleton than to draw that.
	if baked_any:
		skeleton.queue_free()


## Everything that made it a body rather than a picture. A duplicated subtree brings whatever the
## original had, and a corpse that still owned a ragdoll would be several hundred rigid bodies the
## physics step has to look at.
func _strip(corpse: Node3D) -> void:
	corpse.process_mode = Node.PROCESS_MODE_DISABLED
	for node: Node in _everything_under(corpse):
		if node is PhysicalBoneSimulator3D or node is PhysicalBone3D:
			node.queue_free()
			continue
		node.set_script(null)
		var visible_part := node as GeometryInstance3D
		if visible_part != null:
			# A pile that casts shadows is a pile that costs a second pass over every one of them,
			# and a body lying flat on sand throws almost nothing worth having.
			visible_part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var collider := node as CollisionObject3D
		if collider != null:
			collider.process_mode = Node.PROCESS_MODE_DISABLED


func _make_room() -> void:
	while _laid.size() > most:
		var oldest: Node3D = _laid.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()


func _skeleton_in(node: Node) -> Skeleton3D:
	var found := node as Skeleton3D
	if found != null:
		return found
	for child: Node in node.get_children():
		var deeper := _skeleton_in(child)
		if deeper != null:
			return deeper
	return null


func _everything_under(node: Node) -> Array[Node]:
	var found: Array[Node] = [node]
	for child: Node in node.get_children():
		found.append_array(_everything_under(child))
	return found
