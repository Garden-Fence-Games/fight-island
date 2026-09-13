class_name IslandRocks
extends RefCounted
## The scattered stone: Purple-Sigil's seven rocks, bare and mossy, single and clustered.
##
## **Moss follows the same gradient the grass does.** Stone by the water is bare — salt and sand
## scour it — and stone inland is mostly mossed over. It is a draw that slides with `lushness`, not
## a rule, so a bare rock still turns up in a meadow and a mossy one now and then on the beach.
##
## **Nothing scattered stands taller than a body can be seen over.** Two of the rocks are pillars
## modelled at four metres. The camera never turns, so a pillar that tall is a wall the player
## cannot look round; they are scaled to the height a farmer stands and no taller. The six authored
## rock formations are what the island is allowed to be tall with.
##
## Everything is spaced by the generator for a collider of `SPACED_FOR`, so no rock's collider is
## ever wider than that: the gap between blocking props is what keeps a dodge open, and a collider
## wider than it was spaced for would quietly close one.

## The models, and what each measures as it ships: how far it spreads from its origin on the flat,
## and how tall it stands. Read off the exported models.
const MODELS: Array[String] = [
	"res://assets/models/nature/rock_1.glb",
	"res://assets/models/nature/rock_2.glb",
	"res://assets/models/nature/rock_3.glb",
	"res://assets/models/nature/rock_4.glb",
	"res://assets/models/nature/rock_5.glb",
	"res://assets/models/nature/rock_6.glb",
	"res://assets/models/nature/rock_7.glb",
]
const SPREADS: Array[float] = [1.47, 0.54, 1.47, 1.37, 0.65, 1.15, 0.99]
const HEIGHTS: Array[float] = [4.33, 0.47, 4.33, 1.98, 0.71, 0.62, 0.98]
## How large each rock may be drawn, as a range of scale on the model.
const SCALES: Array[Vector2] = [
	Vector2(0.35, 0.52),
	Vector2(0.6, 1.6),
	Vector2(0.35, 0.52),
	Vector2(0.45, 0.85),
	Vector2(0.6, 1.4),
	Vector2(0.5, 1.0),
	Vector2(0.5, 1.0),
]
## Which rocks are bare and which are mossy, and how often each is drawn within its kind: the small
## ones most, the pillars and clusters less.
const BARE: Array[int] = [0, 1, 6]
const BARE_WEIGHTS: Array[float] = [0.2, 0.55, 0.25]
const MOSSY: Array[int] = [2, 4, 3, 5]
const MOSSY_WEIGHTS: Array[float] = [0.15, 0.4, 0.2, 0.25]
## The chance a rock is mossy, by the water and well inland.
const MOSS_BY_THE_SEA: float = 0.12
const MOSS_INLAND: float = 0.8
## Tallest a scattered rock may stand, in metres.
const TALLEST: float = 2.2
## A rock narrower than this, in metres of spread, is stepped over rather than walked round.
const BLOCKS_FROM: float = 0.45
## The collider's share of the rock's spread. Stone is narrower at the height a body walks through
## than across its bounding box, so a collider at the full spread stops the player well short of it.
const COLLIDER_SHARE: float = 0.68
## The collider radius the generator spaces rocks for.
const SPACED_FOR: float = 0.9


## One transform list per model, and the colliders as `[centre, radius]`. `inland` reads the
## generator's land field at a spot.
static func scatter(spots: Array[Vector3], rng: RandomNumberGenerator, inland: Callable) -> Array:
	var made: Array = []
	for _model: String in MODELS:
		made.append([] as Array[Transform3D])
	var colliders: Array = []
	for spot: Vector3 in spots:
		var lush := IslandFoliage.lushness(float(inland.call(spot.x, spot.z)))
		var mossy := rng.randf() < lerpf(MOSS_BY_THE_SEA, MOSS_INLAND, lush)
		var model := _pick(MOSSY if mossy else BARE, MOSSY_WEIGHTS if mossy else BARE_WEIGHTS, rng)
		var scale := rng.randf_range(SCALES[model].x, SCALES[model].y)
		scale = minf(scale, TALLEST / HEIGHTS[model])
		var turn := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		var tilt := Basis(Vector3.RIGHT, rng.randf_range(-0.08, 0.08))
		var stretch := Vector3(1.0, rng.randf_range(0.85, 1.1), rng.randf_range(0.85, 1.15))
		var basis := turn * tilt * Basis.from_scale(stretch * scale)
		(made[model] as Array[Transform3D]).append(Transform3D(basis, spot))
		var spread := SPREADS[model] * scale
		if spread >= BLOCKS_FROM:
			colliders.append([spot, minf(spread * COLLIDER_SHARE, SPACED_FOR)])
	return [made, colliders]


static func _pick(choices: Array[int], weights: Array[float], rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for weight: float in weights:
		total += weight
	var draw := rng.randf() * total
	for index: int in choices.size():
		draw -= weights[index]
		if draw <= 0.0:
			return choices[index]
	return choices[choices.size() - 1]
