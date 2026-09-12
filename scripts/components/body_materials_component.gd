class_name BodyMaterialsComponent
extends Node
## Per-instance copies of the materials a body is drawn with, for anything that wants to tint the
## whole silhouette — an archetype's colour, an elite's glow, the drain while a chain is spent, the
## flash when a hit lands.
##
## **Copies, not the originals.** A rig's materials come out of the imported glTF and are shared by
## every instance of it, so tinting one in place would recolour every other body built on the same
## model. A surface override is private to this mesh instance.
##
## **Tinting `albedo_color` rather than replacing the material with `material_override`.** Albedo is
## multiplied with the texture, so a painted character stays himself and merely goes the colour
## asked for. An override takes one material for the whole mesh and flattens a painted rig to a
## single block of paint — which is exactly what buying a painted rig was meant to stop.
##
## Built on first use, because the visual is an instanced scene and its meshes are not in the tree
## when the owner's own `_ready` runs.

var _materials: Array[StandardMaterial3D] = []


## Every material this body is drawn with. Empty only when the visual is not in the tree yet, and
## nothing is cached in that case — the next caller tries again.
func materials() -> Array[StandardMaterial3D]:
	if not _materials.is_empty():
		return _materials
	var host := get_parent()
	if host == null:
		return _materials
	for node: Node in host.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null:
			continue
		for surface: int in mesh.get_surface_override_material_count():
			var source := mesh.get_active_material(surface) as StandardMaterial3D
			if source == null:
				continue
			var copy := source.duplicate() as StandardMaterial3D
			mesh.set_surface_override_material(surface, copy)
			_materials.append(copy)
	return _materials


## Multiplies the whole body by `colour`. White leaves a painted rig exactly as it was painted.
func tint(colour: Color) -> void:
	for material: StandardMaterial3D in materials():
		material.albedo_color = colour


## The glow an elite carries over its colour. Zero energy turns it off rather than leaving a
## material emitting black, which is not the same thing to the renderer.
func glow(colour: Color, energy: float) -> void:
	for material: StandardMaterial3D in materials():
		material.emission_enabled = energy > 0.0
		material.emission = colour
		material.emission_energy_multiplier = energy
