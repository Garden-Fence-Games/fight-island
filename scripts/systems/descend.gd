class_name Descend
extends RefCounted
## Finding a node by what it **is**, rather than by where somebody put it.
##
## Written seven times before this existed — in the head look, the animation component, the corpse,
## and twice more as a mesh collector under two names. Every copy was the same recursive walk, so
## every copy was a place the walk could be fixed in and the others left behind.
##
## **Not a replacement for `@onready`.** A node's own children have a known path and
## `get_node_or_null(^"Health")` says so; this is for the shape a rig arrives in, which an importer
## decides and a scene file does not promise. `verify_lookups` holds the line between the two: none
## of this may run in a body that ticks every frame.
##
## Static for the same reason `Devices` and `Settings` are — ADR 0004 allows three autoloads and
## this is not one of them.


## The first node of a type anywhere below `root`, depth first, or null.
static func first(root: Node, type: Variant) -> Node:
	if root == null:
		return null
	for child: Node in root.get_children():
		if is_instance_of(child, type):
			return child
		var deeper := first(child, type)
		if deeper != null:
			return deeper
	return null


## The first node of a type among `root`'s **own** children, or null. For the cases that mean "the
## component beside me" rather than "somewhere in this rig".
static func child(root: Node, type: Variant) -> Node:
	if root == null:
		return null
	for candidate: Node in root.get_children():
		if is_instance_of(candidate, type):
			return candidate
	return null


## Every mesh below `root`, in tree order. The two callers that wanted this had it written out in
## full, identically, under two different names.
static func meshes(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if root == null:
		return found
	for node: Node in root.get_children():
		var mesh := node as MeshInstance3D
		if mesh != null:
			found.append(mesh)
		found.append_array(meshes(node))
	return found
