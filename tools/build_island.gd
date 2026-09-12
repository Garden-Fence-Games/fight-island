extends SceneTree
## Builds scenes/world/island.tscn and bakes it to disk.
##
## The playfield is authored: the flat fighting plateau, the beach ring, the cliff wall and the
## rock formations are all placed by the constants below, chosen for one fixed camera angle. Only
## the decoration is scattered, and it is scattered from a seed and **baked into the scene** — so
## the island is identical every run, reviewable in a diff, and free at load time.
##
## Run: godot --headless --path . --script tools/build_island.gd

const OUTPUT: String = "res://scenes/world/island.tscn"
## The terrain mesh is saved beside the scene rather than embedded in it: 6561 vertices as base64
## inside a .tscn is a megabyte of unreadable text and a new blob on every rebuild.
const TERRAIN_MESH: String = "res://assets/models/island_terrain.res"
const SEED: int = 20260911
## Wind, for everything that grows. One shader: a MultiMesh takes one material, and a palm
## that swayed on a different program from the grass beside it would be two winds on one island.
const FOLIAGE_SHADER: String = "res://assets/shaders/foliage.gdshader"
## Stone that gets out of the camera's way. It carries the same fade as the plants and none of the
## wind, because a boulder that swayed would be worse than one that hid the player.
const FADEABLE_SHADER: String = "res://assets/shaders/fadeable.gdshader"
## What the camera fades when it comes between itself and the player — the authored formations, and
## only those. Found by group rather than by path: a node export written into a generated .tscn does
## not resolve (ADR 0006), and the fader has no business knowing the shape of the island's tree.
##
## **The palms are deliberately not in it.** A thinned-out tree is more distracting than the tree
## was, and a grove of them flickering as the body walks through is worse still. What hides the
## player outright is a five-metre boulder, and there are six of those.
const OCCLUDER_GROUP: StringName = &"occluder"
## How wide a chunk of scatter is. Small enough that the camera discards most of the island, wide
## enough that it stays a few dozen batches rather than a few hundred: a draw call is cheap and a
## million submitted vertices is not.
const CHUNK: float = 24.0
## Past these, a tuft and a pebble are a few pixels each. Palms and rocks get no range: they are
## silhouettes, and the island reading as an island depends on them.
const GRASS_FADE: float = 55.0
const PEBBLE_FADE: float = 70.0
## The scattered decoration, each with its origin at its base. **The palm is ours and painted**, so
## it brings its own colours and the palette steps aside — see `_part_material`. The rest are
## Kenney's CC0 Nature Kit: untextured, cut into named parts, coloured by the island.
const PALM_MODEL: String = "res://assets/models/nature/palm_tree.glb"
const ROCK_MODEL: String = "res://assets/models/nature/stone_largeD.glb"
const PEBBLE_MODEL: String = "res://assets/models/nature/stone_smallA.glb"
const GRASS_MODEL: String = "res://assets/models/nature/grass_leafs.glb"
## What each model measures as it ships, so the scatter can go on thinking in metres. A palm is
## scaled by its height and the rest by their width, because that is the dimension each was drawn
## around.
const PALM_MODEL_HEIGHT: float = 5.29
const ROCK_MODEL_WIDTH: float = 1.07
const ROCK_MODEL_HEIGHT: float = 0.57
const ROCK_MODEL_DEPTH: float = 1.03
const PEBBLE_MODEL_WIDTH: float = 0.36
## A tuft of grass is a splay of flat leaves, and it ships four times wider than it is high — so it
## takes both figures. Scaled as one piece, tall grass would be a bush.
const GRASS_MODEL_WIDTH: float = 0.26
const GRASS_MODEL_HEIGHT: float = 0.14
## The huts, from Kenney's CC0 Survival Kit — the Nature Kit's companion, drawn by the same hand on
## the same half-metre tile, and shipping the same untextured, named parts the palette maps colours
## onto. Four pieces: the posts a hut stands on, the deck they carry, the roof over it, and the
## planks of a hut that no longer has either.
const HUT_FRAME_MODEL: String = "res://assets/models/camp/structure.glb"
const HUT_DECK_MODEL: String = "res://assets/models/camp/structure_base.glb"
const HUT_ROOF_MODEL: String = "res://assets/models/camp/structure_roof.glb"
const HUT_PLANK_MODEL: String = "res://assets/models/camp/floor.glb"
## What the hut pieces measure as they ship. They share one square tile and each stands on its own
## base, so the only figure that differs between them is height.
const HUT_TILE: float = 0.5
const HUT_FRAME_HEIGHT: float = 0.517
const HUT_DECK_HEIGHT: float = 0.537
const HUT_ROOF_HEIGHT: float = 0.684
## The plank tile across, as it ships. It is a hut's one wall when it stands on edge and the
## wreckage of a hut when it lies flat, and both need to know how wide it was drawn.
const HUT_PLANK_WIDTH: float = 0.49
const IslandWater := preload("res://tools/island_water.gd")
const IslandNavigation := preload("res://tools/island_navigation.gd")
## How deep the enemies may follow the player in. The navigation mesh stops here, a little under the
## waterline: wading the shallows is allowed, and everything past it is rejected for free.
const NAV_WADE_LIMIT: float = WATER_LEVEL - 0.5

# --- Shape -------------------------------------------------------------------------------------
## Flat land where the player starts, and nothing more. It used to be a thirty-metre clearing in
## the middle of the island, which is exactly what made the island look composed: a bare disc dead
## centre is not something that happens. Clearings now come from the scatter's own noise, so they
## fall where they fall.
const CORE_RADIUS: float = 9.0
## No land past here, whatever the noise says.
const MAX_RADIUS: float = 88.0
const BEACH_DEPTH: float = -2.4
const GRID: int = 221
const SPACING: float = 1.0
const WATER_LEVEL: float = -1.1
## How far below the waterline the sea floor keeps falling, once past the shelf.
const SEA_DROP: float = 9.0
## Width of the beach, in land-field units. The ground meets the water exactly at the shoreline and
## climbs to the plateau over this band, so there is no step at the edge of the island.
const SHORE_BAND: float = 0.55
## The top of the swell, above the still waterline. Ground under this is ground the sea can cover,
## and it is the only threshold at which the puddles are still separate bodies of water: raise it by
## five centimetres and the damp band along the shore joins them to the ocean, after which no test
## for connectivity can tell a puddle from a bay.
##
## It must stay at or above `wave_height` in `water.gdshader`. `verify_island` fails if it drifts.
const WAVE_CREST: float = 0.11
## Where a drained hollow's floor is put. Just clear of the crest — the gap between this and the
## crest is the only step the drain leaves at a hollow's rim, and at five centimetres across a metre
## of sand there is nothing to see.
const POND_CLEARANCE: float = 0.16

# --- Relief ------------------------------------------------------------------------------------
## Inland only, and gentle. The island rolls; it never walls. A cliff along the water would put a
## fixed camera behind a wall, and there would be nothing the player could do about it.
const RELIEF_HEIGHT: float = 1.8
## Nothing on the island may rise higher than this, or it could hide a fight.
const RELIEF_CEILING: float = 2.6

# --- Scatter -----------------------------------------------------------------------------------
## Obstacles keep out of the spawn pad and nothing else. What actually stops a pair of props
## trapping someone against the reaper's 160° sweep is OBSTACLE_SPACING, everywhere on the island —
## not one big empty circle in a place the player will leave in ten seconds.
const CLEAR_RADIUS: float = 7.0
## Clear space between the surfaces of two blocking props, anywhere on the island. Measuring the
## gap rather than the distance between centres is the honest form of the rule: it is the same
## question for a palm and for a boulder, and it scales with whatever the prop happens to be.
##
## The player is 0.7 m across. Twice that leaves room to dodge through rather than merely squeeze.
const MIN_GAP: float = 1.5
## The trunk mesh is 0.16 m across. A collider much wider than that is felt as an invisible ring
## around every tree, which is exactly what "it blocks far too early" means.
const PALM_RADIUS: float = 0.2
## Rocks smaller than this are stepped over, not walked around, so they neither collide nor count.
const BLOCKING_ROCK: float = 0.9
const PALM_COUNT: int = 380
## Stone is scattered thinly on purpose. A rock the player never has to think about is not scenery,
## it is litter in front of the fight — and the island already says "stone" with the six authored
## formations, which is where a boulder is supposed to be noticed.
##
## Every count here is a **target, not a promise**: `_spots` gives up after `count * 120` throws, so
## a figure past what the gap rule can fit on the island is simply never reached. Rocks sat at 950
## and placed 424 — which is why the build line reports what was laid down rather than what was
## asked for, and why lowering a saturated figure does nothing until it drops below the ceiling.
const ROCK_COUNT: int = 200
const PEBBLE_COUNT: int = 1200
const GRASS_COUNT: int = 24000
## How tall a tuft stands. Two bands, and an even share out of each, because the thing that read as
## a green carpet was not the amount of grass — it was that every blade of it was the same length.
## Ground cover with two lengths in it has a near and a far; ground cover with one is a texture.
##
## The tall band stops under 1.1 m on purpose. That is the height `OcclusionFader` draws its line
## to, which makes it the height at which the island stops dressing a body and starts hiding one.
const GRASS_SHORT: Vector2 = Vector2(0.16, 0.34)
const GRASS_TALL: Vector2 = Vector2(0.5, 0.85)
const GRASS_TALL_SHARE: float = 0.5
## How wide a tuft is, drawn independently of how tall it is. Tying the two together would give
## back the uniformity the two bands were for, one step removed: every tall tuft equally broad.
const GRASS_WIDTH: Vector2 = Vector2(0.24, 0.46)

# --- Huts --------------------------------------------------------------------------------------
## The kit's pieces are furniture — half a metre of drying rack. A hut is one of them widened and
## stretched until a body fits under it, and the two figures differ on purpose: a stand made square
## has to become a room made tall. Only the posts notice, and thicker posts suit driftwood.
const HUT_SPREAD: float = 4.0
const HUT_RISE: float = 1.9
## How far a wreck leans before the planks it dropped stop being its problem.
const HUT_LEAN: float = 0.09
## How much of its own footprint a hut collides over. The posts stand at the corners, so unlike a
## boulder a hut really is as wide as its box — this only keeps a shoulder from catching on air.
const HUT_COLLIDER_INSET: float = 0.9
## Where a wreck's fallen planks lie, in tiles from the frame they came off. Fixed rather than
## scattered: the whole island is scattered, and two huts that fell the same way read as one prop
## used twice — which is what turning them by the site's own heading is for.
const HUT_DEBRIS: Array[Vector2] = [Vector2(1.05, 0.3), Vector2(-0.8, -1.0)]
## Clear ground around a hut, standing or fallen, that nothing may grow through. It has to reach
## past the debris as well as the hut, because a palm through a fallen roof is the same mistake.
const HUT_KEEP_OUT: float = 3.6
## How far above the waterline a hut has to stand. A hut in the surf is a placement that drifted
## when a shape constant moved, and it is silent until someone looks at that part of the coast.
const HUT_DRY_GROUND: float = 0.6

# --- Navigation --------------------------------------------------------------------------------

const SAND: Color = Color(0.86, 0.78, 0.58)
const GRASS_GREEN: Color = Color(0.36, 0.52, 0.27)
## The island's palette, mapped onto the parts the models name.
##
## The pack's own colours are not used: its leaves ship as turquoise and its stone as a pale blue
## white, which is a palette from another island. Taking the shapes and keeping the colours also
## puts the art direction in one place — this one — instead of spreading it across whatever files
## happen to have been downloaded.
##
## Keyed by the model's material name, so a pack that renames a part says so at build time rather
## than rendering it in whatever colour a missing entry defaults to.
const NATURE_PALETTE: Dictionary = {
	"woodBark": Color(0.42, 0.31, 0.2),
	"leafsGreen": Color(0.25, 0.47, 0.24),
	"grass": Color(0.38, 0.53, 0.3),
	"stone": Color(0.33, 0.31, 0.29),
	"_defaultMat": Color(0.29, 0.27, 0.26),
	# Cut timber, not living wood: bleached a shade past the palm bark it stands among, so a hut
	# reads as something someone built out of the island rather than as another tree.
	"wood": Color(0.56, 0.44, 0.31),
	"woodDark": Color(0.36, 0.27, 0.19),
}

## Grass is short and quick: it ripples every few metres, and a lawn does not sway on the same clock
## as a five-metre palm, so it overrides the palm-scale wind the shader ships with.
##
## `bend_height` is the tall band's own height rather than a figure of its own, and that is what
## makes one wind serve grass of two lengths: bend is the fraction of that height a vertex stands
## at, so a long blade leans over and a short tuft beside it barely stirs — from the same numbers,
## with nothing to keep in step.
const GRASS_WIND: Dictionary = {
	"wind_strength": 0.2,
	"wind_speed": 2.6,
	"wave_length": 9.0,
	"bend_height": GRASS_TALL.y,
	"bend_power": 1.4,
	"gust_length": 42.0,
}
## How far a palm's leaves flex along their own length, on top of the swing of the whole tree.
## Measured from the trunk outward, so the wood itself barely moves and the fronds do.
const LEAF_FLUTTER: float = 0.055

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _coast := FastNoiseLite.new()
var _clump := FastNoiseLite.new()
var _relief := FastNoiseLite.new()
var _ground := FastNoiseLite.new()
## How much each cell of the height grid was lifted to drain a landlocked hollow. Empty until the
## grid has been built and drained, which is what lets `_height_at` add it without chasing its tail.
var _lift := PackedFloat32Array()
var _drained: int = 0
## What the scatter actually laid down, as opposed to what it was asked for.
var _placed: Dictionary = {}


func _initialize() -> void:
	_rng.seed = SEED
	_noise.seed = SEED
	_noise.frequency = 0.06
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_coast.seed = SEED + 7
	_coast.frequency = 0.013
	_coast.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_coast.fractal_type = FastNoiseLite.FRACTAL_FBM
	_coast.fractal_octaves = 4
	_coast.fractal_gain = 0.55
	_clump.seed = SEED + 13
	_clump.frequency = 0.11
	_clump.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_relief.seed = SEED + 23
	_relief.frequency = 0.022
	_relief.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	# Vegetation patches want features of thirty or forty metres on an island this size. Borrowing
	# the relief noise gave one blob the width of the whole island.
	_ground.seed = SEED + 29
	_ground.frequency = 0.032
	_ground.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ground.fractal_type = FastNoiseLite.FRACTAL_FBM
	_ground.fractal_octaves = 2

	var island := Node3D.new()
	island.name = "Island"

	var heights := _build_heights()
	island.add_child(_terrain(heights))
	island.add_child(_terrain_body(heights))
	island.add_child(_water())
	island.add_child(_scatter())
	island.add_child(_landmark())
	var huts := _huts()
	if huts == null:
		quit(1)
		return
	island.add_child(huts)
	island.add_child(_boundary())
	# Last, because it reads the colliders the two calls above just placed.
	var navigation := IslandNavigation.bake(island, heights, GRID, SPACING, NAV_WADE_LIMIT)
	if navigation == null:
		quit(1)
		return
	island.add_child(navigation)
	_own(island, island)

	var packed := PackedScene.new()
	if packed.pack(island) != OK:
		printerr("could not pack the island")
		quit(1)
		return
	if ResourceSaver.save(packed, OUTPUT) != OK:
		printerr("could not save " + OUTPUT)
		quit(1)
		return
	print(
		(
			(
				"island built — %d verts, %d palms, %d rocks, %d pebbles, %d tufts, %d huts, "
				+ "%d nav polys, %d cells drained"
			)
			% [
				GRID * GRID,
				_placed.get("palms", 0),
				_placed.get("rocks", 0),
				_placed.get("pebbles", 0),
				_placed.get("tufts", 0),
				_hut_sites().size(),
				navigation.navigation_mesh.get_polygon_count(),
				_drained
			]
		)
	)
	quit(0)


# -------------------------------------------------------------------------------------- terrain


## Land where this is positive, sea where it is negative, and the coastline is exactly zero.
##
## A radial function — any radius(angle) — can only ever draw a star-shaped blob, which is why the
## island kept reading as a disc no matter how much the edge wobbled. A noise field thresholded
## against a falloff gives bays that cut inward and headlands that reach out, because the shape is
## not tied to the centre at all.
func _land(x: float, z: float) -> float:
	var radius := Vector2(x, z).length()
	var falloff := 1.0 - pow(clampf(radius / MAX_RADIUS, 0.0, 1.0), 2.1)
	var shape := _coast.get_noise_2d(x, z) * 0.62
	# The core is guaranteed land, or a bay could cut the arena in half.
	var guaranteed := (1.0 - smoothstep(CORE_RADIUS, CORE_RADIUS + 20.0, radius)) * 0.85
	return falloff * 1.05 + shape - 0.40 + guaranteed


## Metres above the water plane at a point. One function, so the mesh and the collision can never
## disagree about where the ground is.
##
## The ground meets the sea exactly at the shoreline and rises to the plateau over SHORE_BAND. The
## first version kept the land flat at plateau height right up to the coast, which put a 1.1 m step
## around the whole island — a miniature cliff, and the reason the edge read as abrupt.
func _height_at(x: float, z: float) -> float:
	var value := _land(x, z)
	var height := 0.0
	if value >= 0.0:
		height = lerpf(WATER_LEVEL, 0.0, smoothstep(0.0, SHORE_BAND, value))
	else:
		var shelf := lerpf(WATER_LEVEL, BEACH_DEPTH, smoothstep(0.0, -SHORE_BAND, value))
		height = shelf + minf(value + SHORE_BAND, 0.0) * SEA_DROP

	# Whatever the field says, the fighting core is flat land.
	var core := 1.0 - smoothstep(CORE_RADIUS - 2.0, CORE_RADIUS + 5.0, Vector2(x, z).length())
	height = lerpf(height, 0.0, core)
	return height + _relief_at(x, z, value) + _lift_at(x, z)


## Rolling ground away from the fight, fading out toward both the core and the shore: the arena
## stays flat and the beach stays walkable, and in between the island has some shape.
func _relief_at(x: float, z: float, value: float) -> float:
	var radius := Vector2(x, z).length()
	var away_from_core := smoothstep(CORE_RADIUS - 2.0, CORE_RADIUS + 14.0, radius)
	var inland := smoothstep(0.12, 0.55, value)
	var rise := (_relief.get_noise_2d(x, z) * 0.5 + 0.5) * RELIEF_HEIGHT
	return minf(rise * away_from_core * inland, RELIEF_CEILING)


func _build_heights() -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	heights.resize(GRID * GRID)
	var half := float(GRID - 1) * 0.5 * SPACING
	for row: int in GRID:
		for column: int in GRID:
			var x := float(column) * SPACING - half
			var z := float(row) * SPACING - half
			heights[row * GRID + column] = _height_at(x, z)
	_drain(heights)
	return heights


## Water the sea cannot reach is not water — see `island_water.gd` for which hollows those are and
## why the threshold decides it. The lift is kept so `_height_at` can add it afterwards: everything
## placed on the island goes through that one function, and a drain applied to the grid alone would
## leave props, colliders and the navigation mesh all standing under the sand.
func _drain(heights: PackedFloat32Array) -> void:
	_lift = IslandWater.drain(heights, GRID, WATER_LEVEL + WAVE_CREST, WATER_LEVEL + POND_CLEARANCE)
	_drained = IslandWater.drained_count(_lift)
	for index: int in heights.size():
		heights[index] += _lift[index]


func _lift_at(x: float, z: float) -> float:
	return IslandWater.lift_at(_lift, GRID, SPACING, x, z)


## How green the ground is here, 0 for bare sand and 1 for full grass. The colour and the grass
## tufts both read it, so a tuft can never stand on a patch of sand.
##
## Inland is grass with sand showing through it rather than the reverse: the patch noise only takes
## green away, so away from the shore the default is green.
func _greenness(x: float, z: float) -> float:
	var inland := _land(x, z)
	var ashore := smoothstep(SHORE_BAND * 0.5, SHORE_BAND * 1.0, inland)
	var patchiness := _ground.get_noise_2d(x, z) * 0.5 + 0.5
	var bare := smoothstep(0.48, 0.72, patchiness)
	return ashore * (1.0 - bare)


## Sand wherever the sea can reach, and inland a mix of grass and bare sand rather than one flat
## green. The mix is keyed to how far inland a point is, never to its distance from the centre.
func _colour_at(x: float, z: float, height: float) -> Color:
	if height < WATER_LEVEL + 0.05:
		return SAND.darkened(0.4).lerp(Color(0.2, 0.35, 0.4), 0.45)
	var inland := _land(x, z)
	# The whole shoreline is sand, always. Grass only starts once the sea is well behind.
	if inland < SHORE_BAND * 0.55:
		return SAND
	return SAND.lerp(GRASS_GREEN, _greenness(x, z))


func _terrain(heights: PackedFloat32Array) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := float(GRID - 1) * 0.5 * SPACING
	for row: int in GRID - 1:
		for column: int in GRID - 1:
			var centre_x := (float(column) + 0.5) * SPACING - half
			var centre_z := (float(row) + 0.5) * SPACING - half
			var corners: Array[Vector3] = []
			for offset: Vector2i in [
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)
			]:
				var c := column + offset.x
				var r := row + offset.y
				corners.append(
					Vector3(
						float(c) * SPACING - half, heights[r * GRID + c], float(r) * SPACING - half
					)
				)
			_triangle(surface, corners[0], corners[1], corners[2])
			_triangle(surface, corners[0], corners[2], corners[3])
	surface.generate_normals()

	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95

	var mesh := surface.commit()
	if ResourceSaver.save(mesh, TERRAIN_MESH) != OK:
		printerr("could not save " + TERRAIN_MESH)
	var instance := MeshInstance3D.new()
	instance.name = "Terrain"
	instance.mesh = load(TERRAIN_MESH)
	instance.material_override = material
	return instance


func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for point: Vector3 in [a, b, c]:
		surface.set_color(_colour_at(point.x, point.z, point.y))
		surface.add_vertex(point)


## HeightMapShape3D rather than a trimesh of the render mesh: exact, cheap, and it cannot drift
## from the visual because both come from _height_at().
func _terrain_body(heights: PackedFloat32Array) -> StaticBody3D:
	var shape := HeightMapShape3D.new()
	shape.map_width = GRID
	shape.map_depth = GRID
	shape.map_data = heights

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape

	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_child(collision)
	return body


func _water() -> MeshInstance3D:
	# Subdivided, because the shader moves vertices and a two-triangle plane has none to move.
	var plane := PlaneMesh.new()
	plane.size = Vector2(2000.0, 2000.0)
	plane.subdivide_width = 220
	plane.subdivide_depth = 220

	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/water.gdshader")

	var instance := MeshInstance3D.new()
	instance.name = "Water"
	instance.mesh = plane
	instance.material_override = material
	instance.position = Vector3(0.0, WATER_LEVEL, 0.0)
	# The waves push vertices past the mesh's own bounds, so it must not be culled on them.
	instance.extra_cull_margin = 16384.0
	return instance


# -------------------------------------------------------------------------------------- scatter


## Every prop is decoration and none of it collides. Getting stuck on a bush is worse than any
## realism it would buy, and it keeps the navigation problem to the authored rock formations.
func _scatter() -> Node3D:
	var props := Node3D.new()
	props.name = "Props"

	# Everything that blocks, as (position, radius), so the gap rule sees palms and boulders alike.
	# `blocking` is what this function places and must build colliders for; `taken` also holds the
	# authored formations, which are already placed and already have colliders of their own.
	var blocking: Array = []
	var taken: Array = []
	for placement: Array in _formations():
		var where: Vector3 = placement[0]
		var size: Vector3 = placement[1]
		where.y = _height_at(where.x, where.z)
		taken.append([where, maxf(size.x, size.z) * 0.5])
	for site: Array in _hut_sites():
		var stood: Vector3 = site[0]
		stood.y = _height_at(stood.x, stood.z)
		taken.append([stood, HUT_KEEP_OUT])

	var palms: Array[Transform3D] = []
	for spot: Vector3 in _spots(
		PALM_COUNT, CLEAR_RADIUS, PALM_RADIUS, 3.4, Vector2(0.08, 3.0), 0.0, taken
	):
		var lean := Basis(Vector3.FORWARD, _rng.randf_range(-0.12, 0.12))
		var turn := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
		var height := _rng.randf_range(3.4, 5.2)
		# Uniformly. A palm stretched only upward grows a crown that reads as a squashed umbrella,
		# and the model already has the proportions of a palm.
		var grown := Vector3.ONE * (height / PALM_MODEL_HEIGHT)
		palms.append(Transform3D((lean * turn).scaled(grown), spot))
		blocking.append([spot, PALM_RADIUS])
		taken.append([spot, PALM_RADIUS])

	var pebbles: Array[Transform3D] = []
	for spot: Vector3 in _spots(PEBBLE_COUNT, 0.0, 0.0, 1.6, Vector2(-0.05, SHORE_BAND * 0.7)):
		var size := _rng.randf_range(0.14, 0.42)
		var turn := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
		var tilt := Basis(Vector3.RIGHT, _rng.randf_range(-0.3, 0.3))
		var grown := Vector3.ONE * (size / PEBBLE_MODEL_WIDTH)
		pebbles.append(Transform3D((turn * tilt).scaled(grown), spot))

	var rocks: Array[Transform3D] = []
	for spot: Vector3 in _spots(
		ROCK_COUNT, CLEAR_RADIUS, 0.9, 2.2, Vector2(-0.02, 3.0), 0.0, taken
	):
		var size := _rng.randf_range(0.4, 1.7)
		var turn := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
		var tilt := Basis(Vector3.RIGHT, _rng.randf_range(-0.12, 0.12))
		var wide := size * _rng.randf_range(0.8, 1.2)
		var grown := Vector3(size, size, wide) / ROCK_MODEL_WIDTH
		rocks.append(Transform3D((turn * tilt).scaled(grown), spot))
		# The boulder is narrower than its bounding box at the height a body walks through, so a
		# collider at its full half-width stops the player well short of the stone they can see.
		if maxf(size, wide) >= BLOCKING_ROCK:
			var here := maxf(size, wide) * 0.34
			blocking.append([spot, here])
			taken.append([spot, here])

	var tufts: Array[Transform3D] = []
	for spot: Vector3 in _spots(
		GRASS_COUNT, 0.0, 0.0, 1.4, Vector2(SHORE_BAND * 0.4, 3.0), 0.0, [], true
	):
		var turn := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
		var lean := Basis(Vector3.RIGHT, _rng.randf_range(-0.18, 0.18))
		var band := GRASS_TALL if _rng.randf() < GRASS_TALL_SHARE else GRASS_SHORT
		var height := _rng.randf_range(band.x, band.y)
		var width := _rng.randf_range(GRASS_WIDTH.x, GRASS_WIDTH.y)
		var grown := Vector3(
			width / GRASS_MODEL_WIDTH, height / GRASS_MODEL_HEIGHT, width / GRASS_MODEL_WIDTH
		)
		# Rotated, then scaled in its own axes — not `.scaled()`, which scales along the world's.
		# Stretching a leaning tuft up the world's Y shears it, and at six times the model's height
		# that is not a lean any more, it is a smear.
		tufts.append(Transform3D(turn * lean * Basis.from_scale(grown), spot))

	# The models carry their own colours, one material per part, so nothing here tints them. What the
	# wind material replaces is the shading, not the palette.
	_placed = {
		"palms": palms.size(),
		"rocks": rocks.size(),
		"pebbles": pebbles.size(),
		"tufts": tufts.size(),
	}
	props.add_child(_multi("Grass", _nature(GRASS_MODEL), tufts, _grass_wind(), GRASS_FADE, false))
	props.add_child(_multi("Pebbles", _nature(PEBBLE_MODEL), pebbles, {}, PEBBLE_FADE, false))
	props.add_child(_multi("Palms", _nature(PALM_MODEL), palms, _palm_wind()))
	props.add_child(_multi("Rocks", _nature(ROCK_MODEL), rocks))
	props.add_child(_colliders(blocking))
	return props


## One static body for everything that blocks. A palm you can walk through is not a palm.
func _colliders(blocking: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "PropColliders"
	body.collision_layer = 1
	body.collision_mask = 0
	for entry: Array in blocking:
		var where: Vector3 = entry[0]
		var radius: float = entry[1]
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = 4.0
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = where + Vector3(0.0, 1.6, 0.0)
		body.add_child(collision)
	return body


## Scatter that reads as nature rather than as planting.
##
## An even minimum-distance spread is the most regular arrangement there is, which is exactly why
## it looks deliberate. Density comes from noise instead: clumps where the field is high, bare
## ground where it is low, and only a small spacing to stop props intersecting.
##
## `keep_out` is the radius obstacles may not enter, pushed outward by noise but never inward, so
## the edge of the fighting core is irregular without ever shrinking. `band` is how far inland the
## prop belongs, in land-field units — which is what puts palms along the shore wherever the shore
## happens to be, instead of on a circle. `centre_fade` thins a prop toward the middle without a
## boundary, which is how grass stays off the fighting space without leaving a mown circle.
func _spots(
	count: int,
	keep_out: float,
	radius_of_prop: float,
	clumping: float,
	band: Vector2,
	centre_fade: float = 0.0,
	avoid: Array = [],
	follow_green: bool = false
) -> Array[Vector3]:
	var kept: Array[Vector3] = []
	var attempts := 0
	while kept.size() < count and attempts < count * 120:
		attempts += 1
		var angle := _rng.randf_range(0.0, TAU)
		var radius := sqrt(_rng.randf_range(1.0, MAX_RADIUS * MAX_RADIUS))
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		var direction := Vector2(cos(angle), sin(angle))

		if keep_out > 0.0:
			var pushed := maxf(
				keep_out + 0.5,
				(
					keep_out
					* (
						1.0
						+ (
							0.35
							* maxf(_clump.get_noise_2d(direction.x * 40.0, direction.y * 40.0), 0.0)
						)
					)
				)
			)
			if radius < pushed:
				continue

		var inland := _land(x, z)
		if inland < band.x or inland > band.y:
			continue
		var density := (_clump.get_noise_2d(x, z) + 1.0) * 0.5
		if follow_green:
			density = _greenness(x, z)
		if centre_fade > 0.0:
			density *= smoothstep(centre_fade * 0.25, centre_fade, radius)
		if _rng.randf() > pow(density, clumping):
			continue

		var y := _height_at(x, z)
		# Nothing below the waterline, and nothing clinging to a steep slope.
		if y < WATER_LEVEL + 0.25:
			continue

		var spot := Vector3(x, y, z)
		var clear := true
		# Props that do not block only need to not interpenetrate; props that do must leave a gap
		# the player fits through, and they must leave it from everything already placed — a palm
		# and a boulder a metre apart is as much a trap as two boulders.
		var own_gap := MIN_GAP if radius_of_prop > 0.0 else 0.6
		for other: Vector3 in kept:
			if spot.distance_to(other) < radius_of_prop * 2.0 + own_gap:
				clear = false
				break
		if clear:
			for entry: Array in avoid:
				var other: Vector3 = entry[0]
				var other_radius: float = entry[1]
				if spot.distance_to(other) < radius_of_prop + other_radius + MIN_GAP:
					clear = false
					break
		if clear:
			kept.append(spot)
	return kept


## One population of one model, split across a grid so the camera can throw most of it away — see
## `IslandScatter`. `wind` names the uniforms the foliage shader should take; leave it out and the
## model keeps the flat materials it shipped with, which is what stone wants.
func _multi(
	name: String,
	mesh: ArrayMesh,
	transforms: Array[Transform3D],
	wind: Dictionary = {},
	fades_at: float = 0.0,
	casts_shadow: bool = true
) -> Node3D:
	_dress(mesh, FOLIAGE_SHADER if not wind.is_empty() else "", wind)
	return IslandScatter.populate(name, mesh, transforms, CHUNK, fades_at, casts_shadow)


## The mesh out of a packaged model, rebuilt as a plain ArrayMesh.
##
## Rebuilt rather than referenced so the built scene owns its geometry outright: it does not depend
## on a .glb's import settings at load time, and hanging a wind material on it writes into the
## island rather than into a shared imported resource that every other user of the model would see.
func _nature(path: String) -> ArrayMesh:
	var packed := load(path) as PackedScene
	if packed == null:
		printerr("no model at " + path)
		return ArrayMesh.new()
	var source := _find_mesh(packed.instantiate())
	if source == null:
		printerr("no mesh inside " + path)
		return ArrayMesh.new()
	var out := ArrayMesh.new()
	for surface: int in source.get_surface_count():
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(surface))
		out.surface_set_material(surface, source.surface_get_material(surface))
	return out


func _find_mesh(node: Node) -> Mesh:
	var instance := node as MeshInstance3D
	if instance != null and instance.mesh != null:
		return instance.mesh
	for child: Node in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null


## Dresses every surface of a model in the island's palette, and puts it in the wind if asked.
##
## Per surface rather than through material_override, which takes one material for the whole mesh:
## a palm is trunk and leaves in one piece, and flattening both to a single colour is exactly what
## buying a modelled palm was meant to stop.
func _dress(mesh: ArrayMesh, shader: String, uniforms: Dictionary) -> void:
	for surface: int in mesh.get_surface_count():
		mesh.surface_set_material(surface, _part_material(mesh, surface, shader, uniforms))


## One part of a model, in the island's colour — or its own, if painted. See asset-pipeline.md.
func _part_material(
	mesh: ArrayMesh, surface: int, shader: String, uniforms: Dictionary
) -> Material:
	var shipped := mesh.surface_get_material(surface) as BaseMaterial3D
	var painted := shipped.albedo_texture if shipped != null else null
	var part := shipped.resource_name if shipped != null else ""
	var colour: Color = NATURE_PALETTE.get(part, Color.WHITE)
	if painted == null and not NATURE_PALETTE.has(part):
		printerr("no colour for the part a model calls '%s'" % part)
		return shipped
	if shader.is_empty():
		var matte := StandardMaterial3D.new()
		matte.albedo_color = colour
		matte.albedo_texture = painted
		matte.roughness = 0.9
		return matte
	var material := ShaderMaterial.new()
	material.shader = load(shader)
	material.set_shader_parameter("tint", colour)
	material.set_shader_parameter("albedo_texture", painted)
	for parameter: String in uniforms:
		material.set_shader_parameter(parameter, uniforms[parameter])
	return material


## The palms stand in the wind the shader ships with. Nothing is set here, and that is the point:
## every surface of every palm reads the same figures, so no part of one can bend differently from
## another and pull away from it.
func _palm_wind() -> Dictionary:
	return {"flutter": LEAF_FLUTTER}


func _grass_wind() -> Dictionary:
	return GRASS_WIND


func _formations() -> Array:
	return [
		[Vector3(-34.0, 0.0, -26.0), Vector3(5.0, 5.4, 4.4), 0.4],
		[Vector3(-44.0, 0.0, -14.0), Vector3(3.4, 3.6, 3.4), 1.1],
		[Vector3(36.0, 0.0, 30.0), Vector3(4.2, 3.2, 3.8), 2.2],
		[Vector3(46.0, 0.0, 16.0), Vector3(3.0, 2.4, 3.0), 0.8],
		[Vector3(-12.0, 0.0, 44.0), Vector3(3.8, 2.8, 3.4), 1.7],
		[Vector3(20.0, 0.0, -42.0), Vector3(4.4, 4.4, 4.0), 0.2],
	]


## The handful of things that do collide, placed rather than scattered. They sit at the edge of the
## plateau so the fighting core stays clear, which is also why enemies can cross it in a straight
## line until the navigation mesh lands.
func _landmark() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "RockFormations"
	body.collision_layer = 1 | 256  # world | camera_occluder
	body.collision_mask = 0

	var placements := _formations()
	var boulder := _nature(ROCK_MODEL)
	# The model stands on its origin, where the old sphere was centred on it — so the formations sit
	# on the ground rather than being lifted by a share of their own height.
	var shipped := Vector3(ROCK_MODEL_WIDTH, ROCK_MODEL_HEIGHT, ROCK_MODEL_DEPTH)
	for placement: Array in placements:
		var where: Vector3 = placement[0]
		var size: Vector3 = placement[1]
		var turn: float = placement[2]
		where.y = _height_at(where.x, where.z)

		var visual := MeshInstance3D.new()
		visual.name = "Rock"
		visual.mesh = boulder
		visual.transform = Transform3D(Basis(Vector3.UP, turn).scaled(size / shipped), where)
		# Per surface on the node rather than on the mesh: the six formations share one mesh, so a
		# material hung there would fade all of them the moment one of them stood in the way.
		for surface: int in boulder.get_surface_count():
			visual.set_surface_override_material(
				surface, _part_material(boulder, surface, FADEABLE_SHADER, {})
			)
		visual.add_to_group(OCCLUDER_GROUP, true)
		body.add_child(visual)

		# The shape is already in metres, so the collider must NOT inherit the visual's scale — doing
		# that squared it, and the largest boulder grew a twenty-five metre invisible wall.
		var shape := BoxShape3D.new()
		shape.size = size * 0.7
		var collision := CollisionShape3D.new()
		collision.name = "RockCollision"
		collision.shape = shape
		collision.transform = Transform3D(Basis(Vector3.UP, turn), where)
		body.add_child(collision)
	return body


## Where somebody lived before the island was an arena: five huts, three of them still standing.
##
## They are placed rather than scattered for the same reason the formations are. A hut is something
## to fight around, so it belongs where the player will actually reach it — well out of the spawn
## pad, well clear of the boulders, and never close enough to another hut to make a corridor.
func _hut_sites() -> Array:
	return [
		[Vector3(16.0, 0.0, -18.0), 0.6, true],
		[Vector3(-20.0, 0.0, 14.0), 2.3, false],
		[Vector3(-6.0, 0.0, 26.0), -1.2, true],
		[Vector3(26.0, 0.0, 10.0), 1.9, false],
		[Vector3(-24.0, 0.0, -8.0), 2.9, true],
	]


## The huts, standing and fallen, under one static body.
##
## **A standing hut fades and a wreck does not.** The standing one is a deck with a roof over it,
## two and a half metres of solid planking, and that is enough to hide a fight — the same reason
## the formations fade. A wreck is four posts and the planks that came off them: a metre of
## see-through frame that never hid anyone, and thinning something the player can already see past
## reads as a glitch. It is the rule the palms are left out under, applied the other way up.
func _huts() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Huts"
	# The fader finds what it fades by group, not by layer — see `OcclusionFader`. The layer is
	# here for the reason it is on the formations: it names what the camera has to reckon with.
	body.collision_layer = 1 | 256  # world | camera_occluder
	body.collision_mask = 0

	var frame := _nature(HUT_FRAME_MODEL)
	var deck := _nature(HUT_DECK_MODEL)
	var roof := _nature(HUT_ROOF_MODEL)
	var planks := _nature(HUT_PLANK_MODEL)
	var tile := HUT_TILE * HUT_SPREAD

	for site: Array in _hut_sites():
		var where: Vector3 = site[0]
		var turn: float = site[1]
		var standing: bool = site[2]
		where.y = _height_at(where.x, where.z)
		if where.y < WATER_LEVEL + HUT_DRY_GROUND:
			printerr("a hut at %.0f, %.0f stands in the sea" % [where.x, where.z])
			return null
		var facing := Basis(Vector3.UP, turn)
		var grown := Basis.from_scale(Vector3(HUT_SPREAD, HUT_RISE, HUT_SPREAD))

		if standing:
			_hut_piece(body, "HutDeck", deck, Transform3D(facing * grown, where), true)
			var over := where + Vector3.UP * HUT_DECK_HEIGHT * HUT_RISE
			_hut_piece(body, "HutRoof", roof, Transform3D(facing * grown, over), true)
			_hut_wall(body, planks, facing, where, tile)
			_hut_collider(body, where, turn, tile, (HUT_DECK_HEIGHT + HUT_ROOF_HEIGHT) * HUT_RISE)
			continue

		var leaning := facing * Basis(Vector3.FORWARD, HUT_LEAN) * grown
		_hut_piece(body, "HutWreck", frame, Transform3D(leaning, where), false)
		for index: int in HUT_DEBRIS.size():
			var offset: Vector2 = HUT_DEBRIS[index]
			var fallen := where + facing * Vector3(offset.x * tile, 0.0, offset.y * tile)
			fallen.y = _height_at(fallen.x, fallen.z)
			# Turned off the hut's own heading so no two wrecks drop their planks the same way.
			var dropped := Basis(Vector3.UP, turn + float(index) + 1.0)
			var flat := dropped * Basis.from_scale(Vector3.ONE * HUT_SPREAD)
			_hut_piece(body, "HutPlanks", planks, Transform3D(flat, fallen), false)
		_hut_collider(body, where, turn, tile, HUT_FRAME_HEIGHT * HUT_RISE)
	return body


## A hut has exactly one wall, at the back of its bay: the deck's own planking stood on edge and
## run from the deck up to where the roof sits.
##
## One wall, not four, and not for want of pieces. The camera is fixed — a player who steps behind
## the fourth wall of a closed hut is a player nobody can see, and there is nothing they could do
## about it. Three open sides is the same bargain the island makes everywhere else.
func _hut_wall(
	body: StaticBody3D, mesh: ArrayMesh, facing: Basis, where: Vector3, tile: float
) -> void:
	var height := HUT_FRAME_HEIGHT * HUT_RISE
	var edgewise := Basis(Vector3.RIGHT, PI * 0.5)
	var stretched := Vector3(tile, HUT_RISE * HUT_PLANK_WIDTH, height) / HUT_PLANK_WIDTH
	var back := Vector3(0.0, HUT_DECK_HEIGHT * HUT_RISE + height * 0.5, -tile * 0.45)
	_hut_piece(
		body,
		"HutWall",
		mesh,
		Transform3D(facing * edgewise * Basis.from_scale(stretched), where + facing * back),
		true
	)


## One piece of one hut. The material goes on the node rather than on the mesh because the five
## huts share four meshes between them, and a material hung on the mesh would fade every hut on
## the island the moment one of them stood in the way.
func _hut_piece(
	body: StaticBody3D, name: String, mesh: ArrayMesh, at: Transform3D, fades: bool
) -> void:
	var visual := MeshInstance3D.new()
	visual.name = name
	visual.mesh = mesh
	visual.transform = at
	for surface: int in mesh.get_surface_count():
		visual.set_surface_override_material(
			surface, _part_material(mesh, surface, FADEABLE_SHADER if fades else "", {})
		)
	if fades:
		visual.add_to_group(OCCLUDER_GROUP, true)
	body.add_child(visual)


## One box per hut, never one per piece: two boxes sharing a wall would read to the trap check as
## two props with no gap between them, which is exactly the shape it exists to refuse.
func _hut_collider(
	body: StaticBody3D, where: Vector3, turn: float, width: float, height: float
) -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, width) * HUT_COLLIDER_INSET
	var collision := CollisionShape3D.new()
	collision.name = "HutCollision"
	collision.shape = shape
	collision.transform = Transform3D(
		Basis(Vector3.UP, turn), where + Vector3.UP * shape.size.y * 0.5
	)
	body.add_child(collision)


## The island already says no by its shape — the beach falls away into water. This only stops the
## player swimming off, and it does it by depth so it fits a coastline that is not a circle.
func _boundary() -> PlayableArea:
	var area := PlayableArea.new()
	area.name = "PlayableArea"
	return area


func _own(node: Node, root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root
		_own(child, root)
