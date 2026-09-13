class_name IslandFoliage
extends RefCounted
## How the things that grow are shaped, graded and clumped. The generator decides where the island
## is; this decides what grows on it and how thickly.
##
## Three ideas, and they share one gradient.
##
## **Everything that grows comes in three sizes of cluster, and the inland gets the big ones.**
## Purple-Sigil authored grass, bushes and palms as ready-made clusters: `_1` is one plant, `_2` a
## few, `_3` a thicket (the palms stop at two). Which one stands at a spot is drawn from a mix that
## slides with `lushness` — mostly singles by the water, mostly thickets well inland — but it is a
## draw, never a rule, so a lone tuft still turns up in the middle and a thicket now and then on the
## shore. Variety is what keeps a gradient from reading as zoning.
##
## **Grass is graded from the water inland, and it is not spaced.** Density follows the ground's
## colour and the same gradient, and a second, patchy noise cuts clearings into it. It used to keep
## every tuft sixty centimetres from every other: at eight thousand tufts that saturated the island,
## and a saturated minimum distance is the most regular arrangement there is — the grass read as a
## planted grid. Now clusters only refuse to sit squarely on each other, and they may overlap.
##
## **Bushes clump, because a hundred of anything cannot be scattered.** Noise density is the right
## answer for thousands of small props and the wrong one here: at a hundred samples it is not
## clumping, it is a hundred lonely shrubs at irregular intervals, and irregular intervals still
## read as spacing rather than as growth. So clumps start from two places and nowhere else:
##
## - **At the foot of a palm.** The one prop on this island a bush may crowd. Everything else keeps
##   a dodge-width gap from everything, because everything else can be walked into; a bush has no
##   collider at all, so a ring of them round a trunk costs the player nothing and gives the trunk a
##   base instead of a seam where the mesh meets the sand.
## - **In the band where trees do not take**, between the last grass and the open sand. Palms thin
##   out there and nothing else reaches it, so without bushes the island's green stops at a line.
##   With them it feathers out, which is the whole of what that band is for.

## Grass is short and quick: it ripples every few metres, and a lawn does not sway on the same clock
## as a five-metre palm, so it overrides the palm-scale wind the shader ships with.
##
## `bend_height` is the tall band's own height rather than a figure of its own, and that is what
## makes one wind serve grass of two lengths: bend is the fraction of that height a vertex stands
## at, so a long blade leans over and a short tuft beside it barely stirs — from the same numbers,
## with nothing to keep in step.
const WIND: Dictionary = {
	"wind_strength": 0.2,
	"wind_speed": 2.6,
	"wave_length": 9.0,
	"bend_height": GRASS_TALL.y,
	"bend_power": 1.4,
	"gust_length": 42.0,
}

## The clusters, smallest first, and what each measures as it ships: its height, and how far it
## spreads from its origin on the flat. Measured off the exported models, so the scatter can go on
## thinking in metres.
const GRASS_MODELS: Array[String] = [
	"res://assets/models/nature/grass_1.glb",
	"res://assets/models/nature/grass_2.glb",
	"res://assets/models/nature/grass_3.glb",
]
const GRASS_HEIGHTS: Array[float] = [1.164, 1.83, 1.83]
const GRASS_SPREADS: Array[float] = [0.47, 0.9, 1.35]
const BUSH_MODELS: Array[String] = [
	"res://assets/models/nature/bush_1.glb",
	"res://assets/models/nature/bush_2.glb",
	"res://assets/models/nature/bush_3.glb",
]
const BUSH_HEIGHTS: Array[float] = [1.016, 1.289, 1.38]
const BUSH_SPREADS: Array[float] = [1.21, 1.88, 2.61]
const PALM_MODELS: Array[String] = [
	"res://assets/models/nature/palm_tree_1.glb",
	"res://assets/models/nature/palm_tree_2.glb",
]
## The tallest trunk of each palm cluster, which is what a palm's height is measured on.
const PALM_HEIGHTS: Array[float] = [5.295, 5.445]
## Where the second, smaller trunk of `palm_tree_2` stands, in the model's own space. It blocks like
## the first, so the pair gets one collider spanning both.
const SECOND_TRUNK: Vector3 = Vector3(-0.67, 0.0, -0.37)

## The share of each cluster size by the water and well inland: singles, groups, thickets. Neither
## end is pure on purpose — see the class notes.
const SHORE_MIX: Vector3 = Vector3(0.72, 0.23, 0.05)
const INLAND_MIX: Vector3 = Vector3(0.18, 0.34, 0.48)

## How many grass clusters are asked for. A target, not a promise: the scatter gives up after so
## many throws, so the island lays down rather fewer.
const GRASS_COUNT: int = 1600
## What the painted grass is multiplied by: warmer, toward yellow-green. Painted as it is, it read a
## shade too vivid against the sand. Above one in red on purpose — a multiply can only darken a
## channel, and yellow is red that was not taken away.
const GRASS_TINT: Color = Color(1.25, 0.95, 0.5)
## Past this a tuft is a few pixels.
const GRASS_FADE: float = 55.0
## A bush carries the same range as the grass it stands in — a waist-high shrub winking out at
## conversational distance is the most visible pop there is, where a tuft at the same distance is a
## few pixels.
const BUSH_FADE: float = GRASS_FADE

## How tall a grass cluster stands. Two bands, because what read as a green carpet was not the
## amount of grass — it was that every blade was the same length. Cover with two lengths has a near
## and a far.
##
## The tall band stops under 1.1 m on purpose: that is the height `OcclusionFader` draws its line
## to, which makes it the height at which the island stops dressing a body and starts hiding one.
const GRASS_SHORT: Vector2 = Vector2(0.16, 0.34)
const GRASS_TALL: Vector2 = Vector2(0.5, 0.85)
## The share of clusters drawn from the tall band **well inland**. Near the water it falls away with
## the gradient, so the long grass stops before the sand rather than at it.
const TALL_SHARE: float = 0.6
## What a cluster's height is multiplied by at the very edge of the water, where nothing grows well.
const BY_THE_SEA: float = 0.42
## How hard density is sharpened into patches: an exponent on a density in 0..1, so raising it
## pushes the middle of the field toward bare and leaves the peaks alone.
const CLUMPING: float = 2.3
## How far a cluster may spread beyond its height's share, either way, so two of the same model at
## the same height are not the same footprint.
const GRASS_STRETCH: Vector2 = Vector2(0.85, 1.2)
## How much of their two spreads two grass clusters must keep apart. Well under one: they overlap,
## which is how grass grows. The only thing refused is one planted squarely on another.
const GRASS_OVERLAP: float = 0.45
## How long the grass scatter keeps throwing, per cluster asked for.
const GRASS_THROWS: int = 60

## Where grass counts as fully inland, and where it is still on the shore, in land-field units.
const LUSH_FROM: float = 0.30
const LUSH_TO: float = 1.45
## What the gradient multiplies density by at the water's edge, rather than nought. **Not nought on
## purpose**: the colour field already thins grass toward the sand, so a gradient that also ran to
## zero ran it to zero twice and left a bare ring twenty-four metres wide around the whole island.
const SHORE_THIN: float = 0.4

## How many bushes, and how tall. A bush has no collider: getting stuck on a shrub is worse than the
## realism in it.
const COUNT: int = 30
const SIZE: Vector2 = Vector2(0.7, 1.5)
## How many clumps, and of which kind. The split is the look: mostly skirting trunks, with enough
## along the sand to carry the transition. Quartered with the island alongside `COUNT`, so a clump
## still holds about five bushes — twenty-four clumps for thirty bushes is not a clump, it is a
## bush with a name.
const TRUNK_CLUMPS: int = 4
const SHORE_CLUMPS: int = 2
## How far from its anchor a bush may land. The near end keeps a clump a clump; the far end is about
## a palm's crown, so a trunk clump sits under the shade that justifies it.
const SPREAD: Vector2 = Vector2(0.9, 3.4)
## And how close it may get to the anchor itself. A bush centred on a trunk grows through it.
const OFF_THE_TRUNK: float = 0.7
## How much of their two spreads two bushes keep apart, on top of the plain gap. A thicket is five
## metres across, and two of them a gap apart would still be one planted inside the other.
const BUSH_OVERLAP: float = 0.55
## Tries before a clump is taken as full. Generous: a clump against the fighting core or out over
## the water has most of its ring unavailable and should still fill the half it has.
const PATIENCE: int = 60
## The band a shore clump may anchor in, as a share of the shoreline band — inside the grass's own
## lower edge and outside the wet sand, which is exactly the strip nothing else populates.
const SHORE_LOW: float = 0.30
const SHORE_HIGH: float = 0.95


## Nought at the water's edge, one well inland, smooth between. Takes the land-field value rather
## than a position, so what "inland" means on this island stays the generator's business.
static func lushness(inland: float) -> float:
	return smoothstep(LUSH_FROM, LUSH_TO, inland)


## How much of the grass stands at a point: the gradient, floored so the shore keeps a thin cover.
static func thinning(inland: float) -> float:
	return lerpf(SHORE_THIN, 1.0, lushness(inland))


## Which size of cluster grows at a point: 0 for one plant, up to `sizes - 1` for the thicket. With
## two sizes the groups and thickets of the mix fold into the larger one.
static func cluster_size(inland: float, rng: RandomNumberGenerator, sizes: int) -> int:
	var mix := SHORE_MIX.lerp(INLAND_MIX, lushness(inland))
	var draw := rng.randf() * (mix.x + mix.y + mix.z)
	if draw < mix.x or sizes < 2:
		return 0
	if draw < mix.x + mix.y or sizes < 3:
		return 1
	return 2


## One grass cluster, shaped for where it stands. `model_height` is what the model measures as it
## ships, which the scale divides out.
static func tuft(
	spot: Vector3, inland: float, rng: RandomNumberGenerator, model_height: float
) -> Transform3D:
	var turn := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
	var lean := Basis(Vector3.RIGHT, rng.randf_range(-0.18, 0.18))
	# Height off the same gradient as density, so the two can never disagree: at the water's edge
	# grass is sparse *and* short, and well inland it is thick *and* long.
	var lush := lushness(inland)
	var band := GRASS_TALL if rng.randf() < TALL_SHARE * lush else GRASS_SHORT
	var height := rng.randf_range(band.x, band.y) * lerpf(BY_THE_SEA, 1.0, lush)
	var tall := height / model_height
	var grown := Vector3(
		tall * rng.randf_range(GRASS_STRETCH.x, GRASS_STRETCH.y),
		tall,
		tall * rng.randf_range(GRASS_STRETCH.x, GRASS_STRETCH.y)
	)
	# Rotated, then scaled in its own axes — not `.scaled()`, which scales along the world's.
	return Transform3D(turn * lean * Basis.from_scale(grown), spot)


## The grass, as one list of transforms per cluster size.
##
## `land`, `height` and `cover` are the generator's field queries, `(x, z) -> float`: where the land
## is, how high it stands, and how much grass the ground's colour allows. `patches` is a noise in
## 0..1 that cuts clearings. `band` is how far inland grass belongs, in land-field units.
static func grass(
	rng: RandomNumberGenerator,
	land: Callable,
	height: Callable,
	cover: Callable,
	patches: Callable,
	reach: float,
	waterline: float,
	band: Vector2
) -> Array:
	var made: Array = [[] as Array[Transform3D], [] as Array[Transform3D], [] as Array[Transform3D]]
	# A coarse grid of what is already down, so the overlap test looks at neighbours and not at
	# three thousand clusters every throw.
	var cells: Dictionary = {}
	var placed := 0
	var throws := 0
	while placed < GRASS_COUNT and throws < GRASS_COUNT * GRASS_THROWS:
		throws += 1
		var angle := rng.randf_range(0.0, TAU)
		var radius := sqrt(rng.randf_range(1.0, reach * reach))
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		var inland := float(land.call(x, z))
		if inland < band.x or inland > band.y:
			continue
		var density := float(cover.call(x, z)) * float(patches.call(x, z))
		if rng.randf() > pow(density, CLUMPING):
			continue
		var y := float(height.call(x, z))
		if y < waterline + 0.25:
			continue
		var size := cluster_size(inland, rng, GRASS_MODELS.size())
		var placed_at := tuft(Vector3(x, y, z), inland, rng, GRASS_HEIGHTS[size])
		var spread := GRASS_SPREADS[size] * placed_at.basis.get_scale().x
		var cell := Vector2i(int(floorf(x / 2.0)), int(floorf(z / 2.0)))
		if _crowded(cells, cell, Vector2(x, z), spread):
			continue
		if not cells.has(cell):
			cells[cell] = []
		(cells[cell] as Array).append(Vector3(x, z, spread))
		(made[size] as Array[Transform3D]).append(placed_at)
		placed += 1
	return made


## The palms, as one list of transforms per cluster size, and the colliders they need as
## `[centre, radius]`. `spots` are where trunks may stand, already clear of everything by the gap a
## single trunk needs; a pair only grows where its wider collider keeps that gap too.
static func palms(
	spots: Array[Vector3],
	rng: RandomNumberGenerator,
	land: Callable,
	taken: Array,
	trunk_radius: float,
	gap: float
) -> Array:
	var made: Array = [[] as Array[Transform3D], [] as Array[Transform3D]]
	var colliders: Array = []
	for spot: Vector3 in spots:
		colliders.append([spot, trunk_radius])
	for index: int in spots.size():
		var spot := spots[index]
		var lean := Basis(Vector3.FORWARD, rng.randf_range(-0.12, 0.12))
		var turn := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		var tall := rng.randf_range(3.4, 5.2)
		var size := cluster_size(float(land.call(spot.x, spot.z)), rng, PALM_MODELS.size())
		var basis := (lean * turn).scaled(Vector3.ONE * (tall / PALM_HEIGHTS[size]))
		if size == 1:
			var second := spot + basis * SECOND_TRUNK
			var centre := (spot + second) * 0.5
			var wide := spot.distance_to(second) * 0.5 + trunk_radius
			if _pair_fits(centre, wide, index, colliders, taken, gap):
				colliders[index] = [centre, wide]
			else:
				size = 0
				basis = (lean * turn).scaled(Vector3.ONE * (tall / PALM_HEIGHTS[0]))
		(made[size] as Array[Transform3D]).append(Transform3D(basis, spot))
	return [made, colliders]


## The bushes, already turned into transforms, one list per cluster size.
##
## `land` and `height` are the generator's own field queries, `(x, z) -> float`, so the shape of the
## island stays its business and the clumping stays ours. `avoid` is `[[centre, radius], ...]` of
## what a bush keeps clear of, and **the palms are deliberately not in it**: they are the anchors.
static func bushes(
	trunks: Array[Vector3],
	avoid: Array,
	rng: RandomNumberGenerator,
	land: Callable,
	height: Callable,
	core: float,
	reach: float,
	waterline: float,
	shore: float,
	gap: float
) -> Array:
	var made: Array = [[] as Array[Transform3D], [] as Array[Transform3D], [] as Array[Transform3D]]
	var anchors := _anchors(trunks, rng, land, height, core, reach, waterline, shore)
	if anchors.is_empty():
		return made
	var kept: Array = []
	for index: int in COUNT:
		# Round-robin rather than at random, so every clump fills before any is crowded.
		var anchor: Vector3 = anchors[index % anchors.size()]
		var size := cluster_size(float(land.call(anchor.x, anchor.z)), rng, BUSH_MODELS.size())
		var tall := rng.randf_range(SIZE.x, SIZE.y)
		var scale := tall / BUSH_HEIGHTS[size]
		var spread := BUSH_SPREADS[size] * scale
		var spot := _near(
			anchor, spread, kept, avoid, rng, land, height, core, reach, waterline, shore, gap
		)
		if spot == Vector3.INF:
			continue
		kept.append([spot, spread])
		var turn := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		var placed_at := Transform3D(turn * Basis.from_scale(Vector3.ONE * scale), spot)
		(made[size] as Array[Transform3D]).append(placed_at)
	return made


## Every transform of a per-size list, in one list. For the counts and the checks.
static func flattened(by_size: Array) -> Array[Transform3D]:
	var all: Array[Transform3D] = []
	for group: Array[Transform3D] in by_size:
		all.append_array(group)
	return all


## Whether a grass cluster of this spread would sit squarely on one already down.
static func _crowded(cells: Dictionary, cell: Vector2i, at: Vector2, spread: float) -> bool:
	for dx: int in range(-1, 2):
		for dz: int in range(-1, 2):
			for other: Vector3 in cells.get(cell + Vector2i(dx, dz), []):
				var apart := at.distance_to(Vector2(other.x, other.y))
				if apart < (spread + other.z) * GRASS_OVERLAP:
					return true
	return false


## Whether a palm pair's collider keeps the gap from every other trunk and everything placed.
static func _pair_fits(
	centre: Vector3, wide: float, index: int, colliders: Array, taken: Array, gap: float
) -> bool:
	for other: int in colliders.size():
		if other == index:
			continue
		var there: Vector3 = colliders[other][0]
		var radius: float = colliders[other][1]
		if Vector2(centre.x - there.x, centre.z - there.z).length() < wide + radius + gap:
			return false
	for entry: Array in taken:
		var there: Vector3 = entry[0]
		var radius: float = entry[1]
		if Vector2(centre.x - there.x, centre.z - there.z).length() < wide + radius + gap:
			return false
	return true


## One bush somewhere around an anchor, or `Vector3.INF` when that ring has no room left.
static func _near(
	anchor: Vector3,
	spread: float,
	kept: Array,
	avoid: Array,
	rng: RandomNumberGenerator,
	land: Callable,
	height: Callable,
	core: float,
	reach: float,
	waterline: float,
	shore: float,
	gap: float
) -> Vector3:
	for _try: int in PATIENCE:
		var angle := rng.randf_range(0.0, TAU)
		var out := rng.randf_range(SPREAD.x, SPREAD.y)
		var x := anchor.x + cos(angle) * out
		var z := anchor.z + sin(angle) * out
		if not _is_ground(x, z, land, height, core, reach, waterline, shore):
			continue
		var spot := Vector3(x, float(height.call(x, z)), z)
		if spot.distance_to(anchor) < OFF_THE_TRUNK:
			continue
		var clear := true
		for other: Array in kept:
			var there: Vector3 = other[0]
			var other_spread: float = other[1]
			if spot.distance_to(there) < maxf(gap, (spread + other_spread) * BUSH_OVERLAP):
				clear = false
				break
		if clear:
			for entry: Array in avoid:
				var centre: Vector3 = entry[0]
				var radius: float = entry[1]
				if spot.distance_to(centre) < radius + gap:
					clear = false
					break
		if clear:
			return spot
	return Vector3.INF


## The clumps: a spread of trunks, then a handful of spots in the band trees do not reach.
static func _anchors(
	trunks: Array[Vector3],
	rng: RandomNumberGenerator,
	land: Callable,
	height: Callable,
	core: float,
	reach: float,
	waterline: float,
	shore: float
) -> Array[Vector3]:
	var found: Array[Vector3] = []
	# Strided rather than drawn at random: taking sixteen trunks out of hundreds by chance clusters
	# the clumps themselves, and bushy groves down one side of the island with none on the other is
	# the arrangement this whole file exists to avoid, one level up.
	if not trunks.is_empty():
		var stride := maxf(float(trunks.size()) / float(TRUNK_CLUMPS), 1.0)
		var offset := rng.randf()
		for step: int in TRUNK_CLUMPS:
			var at := int(floorf((float(step) + offset) * stride)) % trunks.size()
			found.append(trunks[at])
	for _clump: int in SHORE_CLUMPS:
		for _try: int in PATIENCE:
			var angle := rng.randf_range(0.0, TAU)
			var radius := sqrt(rng.randf_range(1.0, reach * reach))
			var x := cos(angle) * radius
			var z := sin(angle) * radius
			var inland := float(land.call(x, z))
			if inland < shore * SHORE_LOW or inland > shore * SHORE_HIGH:
				continue
			if not _is_ground(x, z, land, height, core, reach, waterline, shore):
				continue
			found.append(Vector3(x, float(height.call(x, z)), z))
			break
	return found


## Ground a bush may stand on: on the island, out of the fight, out of the sea, and inland of the
## wet sand. Wider than a shore clump's band, because a trunk clump sits wherever a palm does.
static func _is_ground(
	x: float,
	z: float,
	land: Callable,
	height: Callable,
	core: float,
	reach: float,
	waterline: float,
	shore: float
) -> bool:
	var from_centre := Vector2(x, z).length()
	if from_centre < core or from_centre > reach:
		return false
	if float(land.call(x, z)) < shore * SHORE_LOW:
		return false
	return float(height.call(x, z)) >= waterline + 0.25
