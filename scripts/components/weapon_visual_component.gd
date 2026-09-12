class_name WeaponVisualComponent
extends Node
## Shows or hides the weapon meshes the rig already carries.
##
## The gun is modelled into the skeleton, parented to the hand bone, because that is how the clips
## were authored — `idle_gun` and `walk_gun` move a gun that is part of the rig. So nothing is
## spawned or attached at runtime and no bone attachment is needed: the mesh is simply hidden until
## the weapon is in hand. Hidden is the default, which is what fists look like.
##
## **It takes a flag, not a `WeaponData`.** The component neither knows what a weapon is nor who
## owns it; whoever hands the gun over sets `armed`. That is also what lets the pickup, the wheel
## and a headless check all drive it the same way.

signal armed_changed(is_armed: bool)

## Meshes under the owner whose name matches are the weapon. Exported because the farmer rig will
## not necessarily agree, and because a second weapon is another name rather than another component.
@export var weapon_mesh_names: Array[StringName] = [&"Gun"]

@export var armed: bool = false:
	set = set_armed

var _meshes: Array[MeshInstance3D] = []


## Deferred for the same reason the head-look is: the visual is an instanced scene, and reaching
## into it while the parent is still building its children finds nothing.
func _ready() -> void:
	_collect.call_deferred()


## True when at least one weapon mesh was found, so a check can tell "hidden" from "not there".
func has_weapon_mesh() -> bool:
	return not _meshes.is_empty()


func set_armed(value: bool) -> void:
	armed = value
	_apply()
	armed_changed.emit(armed)


func _collect() -> void:
	_meshes.clear()
	var host := get_parent()
	if host == null:
		return
	for node: Node in host.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh != null and weapon_mesh_names.has(StringName(mesh.name)):
			_meshes.append(mesh)
	_apply()


func _apply() -> void:
	for mesh: MeshInstance3D in _meshes:
		mesh.visible = armed
