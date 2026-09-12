class_name IslandFoliage
extends RefCounted
## How the things that grow are shaped, graded and clumped. The generator decides where the island
## is; this decides what grows on it and how thickly.
##
## Two ideas, and they share one gradient.
##
## **Grass is graded from the water inland.** Density was already keyed to the ground's colour, and
## that stops climbing half a band from the shore and is flat everywhere after — so the island had
## one density across all of its inland and a hard edge near the sand. Length was a coin flip,
## unrelated to position, so a sparse tuft at the water's edge was as likely to be long as a thick
## one in the middle. Both now read the same `lushness`: at the sea grass is sparse and short, well
## inland it is thick and long, and the two can no longer disagree.
##
## **Bushes clump, because ninety of anything cannot be scattered.** Noise density is the right
## answer for thousands of small props and the wrong one here: at ninety samples it is not clumping,
## it is ninety lonely shrubs at irregular intervals, and irregular intervals still read as spacing
## rather than as growth. So clumps start from two places and nowhere else:
##
## - **At the foot of a palm.** The one prop on this island a bush may crowd. Everything else keeps
##   a dodge-width gap from everything, because everything else can be walked into; a bush has no
##   collider at all, so a ring of them round a trunk costs the player nothing and gives the trunk a
##   base instead of a seam where the mesh meets the sand.
## - **In the band where trees do not take**, between the last grass and the open sand. Palms thin
##   out there and nothing else reaches it, so without bushes the island's green stops at a line.
##   With them it feathers out, which is the whole of what that band is for.
##
## Clumps are deliberately few — ninety bushes over twenty-four clumps is about four each, and four
## is the smallest number that reads as one thing rather than as four things.

## How tall a tuft stands. Two bands, because what read as a green carpet was not the amount of
## grass — it was that every blade was the same length. Cover with two lengths has a near and a far.
##
## The tall band stops under 1.1 m on purpose: that is the height `OcclusionFader` draws its line
## to, which makes it the height at which the island stops dressing a body and starts hiding one.
const GRASS_SHORT: Vector2 = Vector2(0.16, 0.34)
const GRASS_TALL: Vector2 = Vector2(0.5, 0.85)
## The share of tufts drawn from the tall band **well inland**. Near the water it falls away with
## the gradient, so the long grass stops before the sand rather than at it.
const TALL_SHARE: float = 0.6
## What a tuft's length is multiplied by at the very edge of the water, where nothing grows well.
const BY_THE_SEA: float = 0.42
## How hard the noise clumps the grass: an exponent on a density in 0..1, so raising it pushes the
## middle of the field toward bare and leaves the peaks alone, which is what turns an even spread
## into patches. 1.4 was a lawn with thin spots; this is ground cover with clearings in it.
const CLUMPING: float = 2.3
## How wide a tuft is, drawn independently of how tall it is. Tying the two together would give back
## the uniformity the two bands were for, one step removed: every tall tuft equally broad.
const GRASS_WIDTH: Vector2 = Vector2(0.24, 0.46)

## Where grass counts as fully inland, and where it is still on the shore, in land-field units.
const LUSH_FROM: float = 0.30
const LUSH_TO: float = 1.45
## What the gradient multiplies density by at the water's edge, rather than nought. **Not nought on
## purpose**: the colour field already thins grass toward the sand, so a gradient that also ran to
## zero ran it to zero twice and left a bare ring twenty-four metres wide around the whole island.
## Sparse is what was asked for; absent is a different island. Length keeps the ungoverned gradient,
## so the grass by the water is thin *and* short rather than thin and oddly long.
const SHORE_THIN: float = 0.4

## How many bushes, and how big. A bush is ten times a tuft in triangles, so it is counted in dozens
## rather than thousands. It never blocks: getting stuck on a shrub is worse than the realism in it.
const COUNT: int = 90
const SIZE: Vector2 = Vector2(0.7, 1.5)
## How many clumps, and of which kind. The split is the look: mostly skirting trunks, with enough
## along the sand to carry the transition.
const TRUNK_CLUMPS: int = 16
const SHORE_CLUMPS: int = 8
## How far from its anchor a bush may land. The near end keeps a clump a clump; the far end is about
## a palm's crown, so a trunk clump sits under the shade that justifies it.
const SPREAD: Vector2 = Vector2(0.9, 3.4)
## And how close it may get to the anchor itself. A bush centred on a trunk grows through it.
const OFF_THE_TRUNK: float = 0.7
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


## One tuft of grass, shaped for where it stands. `inland` is the generator's land-field value at
## the spot, and `model` is the shipped mesh's width and height, which the scale divides out.
static func tuft(
	spot: Vector3, inland: float, rng: RandomNumberGenerator, model: Vector2
) -> Transform3D:
	var turn := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
	var lean := Basis(Vector3.RIGHT, rng.randf_range(-0.18, 0.18))
	# Length off the same gradient as density, so the two can never disagree: at the water's edge
	# grass is sparse *and* short, and well inland it is thick *and* long. A tuft that was short
	# because it was sparse and tall because a coin said so read as two unrelated decisions.
	var lush := lushness(inland)
	var band := GRASS_TALL if rng.randf() < TALL_SHARE * lush else GRASS_SHORT
	var height := rng.randf_range(band.x, band.y) * lerpf(BY_THE_SEA, 1.0, lush)
	var width := rng.randf_range(GRASS_WIDTH.x, GRASS_WIDTH.y)
	var grown := Vector3(width / model.x, height / model.y, width / model.x)
	# Rotated, then scaled in its own axes — not `.scaled()`, which scales along the world's.
	# Stretching a leaning tuft up the world's Y shears it, and at six times the model's height
	# that is not a lean any more, it is a smear.
	return Transform3D(turn * lean * Basis.from_scale(grown), spot)


## The bushes, already turned into transforms.
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
	gap: float,
	model_height: float
) -> Array[Transform3D]:
	var anchors := _anchors(trunks, rng, land, height, core, reach, waterline, shore)
	if anchors.is_empty():
		return []
	var kept: Array[Vector3] = []
	for index: int in COUNT:
		# Round-robin rather than at random, so every clump fills before any is crowded. Choosing
		# an anchor by chance at ninety samples leaves some clumps empty and others a thicket.
		var anchor: Vector3 = anchors[index % anchors.size()]
		var spot := _near(
			anchor, kept, avoid, rng, land, height, core, reach, waterline, shore, gap
		)
		if spot != Vector3.INF:
			kept.append(spot)
	var made: Array[Transform3D] = []
	for spot: Vector3 in kept:
		var size := rng.randf_range(SIZE.x, SIZE.y)
		var turn := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		var grown := Vector3.ONE * (size / model_height)
		made.append(Transform3D(turn * Basis.from_scale(grown), spot))
	return made


## One bush somewhere around an anchor, or `Vector3.INF` when that ring has no room left.
static func _near(
	anchor: Vector3,
	kept: Array[Vector3],
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
		for other: Vector3 in kept:
			if spot.distance_to(other) < gap:
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
