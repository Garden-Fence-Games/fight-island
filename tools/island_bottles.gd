class_name IslandBottles
extends RefCounted
## Bottles in the grass where the player wakes up: a ring of glass round the spawn and nowhere else.
##
## They are the island's first picture — the camera turns round the player while he gets up among
## them — and at midday the sun catches one and throws a flare across the screen; see `SunGlint`.
## All one size: they are litter, not a gradient.
##
## Scattered on the ground and never in the way. A bottle is stepped over, so it collides with
## nothing, blocks nothing and keeps no gap — the spawn pad's rules are about what can trap a dodge.

const MODELS: Array[String] = [
	"res://assets/models/nature/bottle_1.glb",
	"res://assets/models/nature/bottle_2.glb",
]
const GLASS: String = "res://assets/materials/bottle_glass.tres"
## How many, and how far from the spawn they may lie, in metres.
const COUNT: int = 70
const REACH: float = 10.0
## Standing bottles against bottles on their side.
const STANDING_SHARE: float = 0.35
## How far a standing bottle may lean, in radians: enough that a row of them does not look set out.
const LEAN: float = 0.25
## How much bigger than modelled they stand. Modelled at twenty-five centimetres they were a few
## pixels from the game camera, which is no picture and no glint.
const SIZE: float = 3.0
## Past this they are a few pixels.
const FADE: float = 45.0


## The population, built and ready to add under the island's props. `height` is the generator's
## `(x, z) -> float` ground query; `centre` is where the player wakes.
static func population(
	rng: RandomNumberGenerator, height: Callable, centre: Vector3, chunk: float
) -> Node3D:
	var by_model: Array = [[] as Array[Transform3D], [] as Array[Transform3D]]
	for _bottle: int in COUNT:
		# Uniform over the disc rather than bunched at its middle.
		var angle := rng.randf_range(0.0, TAU)
		var out := sqrt(rng.randf()) * REACH
		var x := centre.x + cos(angle) * out
		var z := centre.z + sin(angle) * out
		var spot := Vector3(x, float(height.call(x, z)), z)
		var standing := rng.randf() < STANDING_SHARE
		var turn := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * SIZE)
		if standing:
			var lean := Basis(Vector3.RIGHT, rng.randf_range(-LEAN, LEAN))
			(by_model[0] as Array[Transform3D]).append(Transform3D(turn * lean, spot))
		else:
			(by_model[1] as Array[Transform3D]).append(Transform3D(turn, spot))
	var glass := load(GLASS) as Material
	var meshes: Array[ArrayMesh] = []
	for model: String in MODELS:
		meshes.append(_glass_mesh(model, glass))
	return IslandScatter.populate_family("Bottles", meshes, by_model, chunk, FADE, false, false)


## The model's mesh rebuilt as a plain one, every surface in glass.
static func _glass_mesh(path: String, glass: Material) -> ArrayMesh:
	var out := ArrayMesh.new()
	var packed := load(path) as PackedScene
	if packed == null:
		return out
	var root := packed.instantiate()
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var source := (node as MeshInstance3D).mesh
		if source == null:
			continue
		for surface: int in source.get_surface_count():
			out.add_surface_from_arrays(
				Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(surface)
			)
			out.surface_set_material(out.get_surface_count() - 1, glass)
	root.free()
	return out
