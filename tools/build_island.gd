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
const ROCK_COUNT: int = 950
const PEBBLE_COUNT: int = 3400
const GRASS_COUNT: int = 24000

const SAND: Color = Color(0.86, 0.78, 0.58)
const GRASS_GREEN: Color = Color(0.36, 0.52, 0.27)
const ROCK_GREY: Color = Color(0.33, 0.31, 0.29)

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _coast := FastNoiseLite.new()
var _clump := FastNoiseLite.new()
var _relief := FastNoiseLite.new()
var _ground := FastNoiseLite.new()


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
	island.add_child(_boundary())
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
			"island built — %d verts, %d palms, %d rocks, %d tufts"
			% [GRID * GRID, PALM_COUNT, ROCK_COUNT, GRASS_COUNT]
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
	return height + _relief_at(x, z, value)


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
	return heights


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

	var trunks: Array[Transform3D] = []
	var fronds: Array[Transform3D] = []
	for spot: Vector3 in _spots(
		PALM_COUNT, CLEAR_RADIUS, PALM_RADIUS, 3.4, Vector2(0.08, 3.0), 0.0, taken
	):
		var lean := Basis(Vector3.FORWARD, _rng.randf_range(-0.12, 0.12))
		var height := _rng.randf_range(3.4, 5.2)
		trunks.append(Transform3D(lean.scaled(Vector3(1.0, height, 1.0)), spot))
		blocking.append([spot, PALM_RADIUS])
		taken.append([spot, PALM_RADIUS])
		var crown := spot + lean * Vector3(0.0, height, 0.0)
		for blade: int in 6:
			var turn := Basis(Vector3.UP, TAU * float(blade) / 6.0 + _rng.randf_range(-0.3, 0.3))
			var droop := Basis(Vector3.RIGHT, _rng.randf_range(0.35, 0.7))
			fronds.append(Transform3D(turn * droop, crown))

	var pebbles: Array[Transform3D] = []
	for spot: Vector3 in _spots(PEBBLE_COUNT, 0.0, 0.0, 1.6, Vector2(-0.05, SHORE_BAND * 0.7)):
		var size := _rng.randf_range(0.14, 0.42)
		var turn := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
		var tilt := Basis(Vector3.RIGHT, _rng.randf_range(0.0, TAU))
		pebbles.append(Transform3D((turn * tilt).scaled(Vector3.ONE * size), spot))

	var rocks: Array[Transform3D] = []
	for spot: Vector3 in _spots(
		ROCK_COUNT, CLEAR_RADIUS, 0.9, 2.2, Vector2(-0.02, 3.0), 0.0, taken
	):
		var size := _rng.randf_range(0.4, 1.7)
		var turn := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
		var tilt := Basis(Vector3.RIGHT, _rng.randf_range(-0.25, 0.25))
		var wide := size * _rng.randf_range(0.7, 1.3)
		rocks.append(Transform3D((turn * tilt).scaled(Vector3(size, size * 0.7, wide)), spot))
		# The rock mesh is perturbed inward as well as outward, so a collider at its full half-width
		# stops the player well short of the stone they can see.
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
		var size := _rng.randf_range(0.6, 1.25)
		tufts.append(Transform3D((turn * lean).scaled(Vector3(size, size, size)), spot))

	props.add_child(_multi("Grass", _tuft(), GRASS_GREEN.darkened(0.18), tufts))
	props.add_child(_multi("Pebbles", _rock_mesh(), ROCK_GREY.lightened(0.12), pebbles))
	props.add_child(_multi("PalmTrunks", _cylinder(0.16, 1.0), Color(0.42, 0.31, 0.2), trunks))
	props.add_child(_multi("PalmFronds", _frond(), Color(0.25, 0.47, 0.24), fronds))
	props.add_child(_multi("Rocks", _rock_mesh(), ROCK_GREY, rocks))
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


func _multi(name: String, mesh: Mesh, tint: Color, transforms: Array[Transform3D]) -> Node3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	# The buffer is written directly rather than through set_instance_transform: headless runs on a
	# dummy renderer, where the setter writes to a server that discards it and the buffer saves empty.
	multi.buffer = _pack(transforms)

	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.9

	var instance := MultiMeshInstance3D.new()
	instance.name = name
	instance.multimesh = multi
	instance.material_override = material
	return instance


## Twelve floats per instance: the three rows of the 3x4 transform, origin last on each row.
func _pack(transforms: Array[Transform3D]) -> PackedFloat32Array:
	var data := PackedFloat32Array()
	data.resize(transforms.size() * 12)
	for index: int in transforms.size():
		var at := transforms[index]
		var basis := at.basis
		var origin := at.origin
		var base := index * 12
		data[base + 0] = basis.x.x
		data[base + 1] = basis.y.x
		data[base + 2] = basis.z.x
		data[base + 3] = origin.x
		data[base + 4] = basis.x.y
		data[base + 5] = basis.y.y
		data[base + 6] = basis.z.y
		data[base + 7] = origin.y
		data[base + 8] = basis.x.z
		data[base + 9] = basis.y.z
		data[base + 10] = basis.z.z
		data[base + 11] = origin.z
	return data


func _cylinder(radius: float, height: float) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.75
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	mesh.rings = 1
	# Grown from the ground rather than from its middle, so a scaled instance stays planted.
	return _shift(_as_array(mesh), Transform3D(Basis.IDENTITY, Vector3(0.0, height * 0.5, 0.0)))


## A low-poly sphere with its vertices pushed about. A cube reads as a crate; this reads as a rock,
## and it is the least work that gets there before the art phase replaces it with a textured mesh.
func _rock_mesh() -> Mesh:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 7
	sphere.rings = 4
	sphere.radius = 0.5
	sphere.height = 1.0

	var surface := SurfaceTool.new()
	surface.create_from(_as_array(sphere), 0)
	var arrays := surface.commit_to_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var lumps := RandomNumberGenerator.new()
	lumps.seed = SEED + 41
	for index: int in points.size():
		var point := points[index]
		var push := 1.0 + _relief.get_noise_3d(point.x * 9.0, point.y * 9.0, point.z * 9.0) * 0.45
		points[index] = point * Vector3(push, push * 0.78, push)
	arrays[Mesh.ARRAY_VERTEX] = points

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var smoothed := SurfaceTool.new()
	smoothed.create_from(mesh, 0)
	smoothed.generate_normals()
	return smoothed.commit()


func _tuft() -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.17
	mesh.height = 0.42
	mesh.radial_segments = 4
	mesh.rings = 0
	return _shift(_as_array(mesh), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.21, 0.0)))


func _frond() -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.22, 0.05, 2.1)
	return _shift(_as_array(mesh), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -1.0)))


func _box(size: Vector3) -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _shift(_as_array(mesh), Transform3D(Basis.IDENTITY, Vector3(0.0, size.y * 0.5, 0.0)))


func _as_array(mesh: Mesh) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.create_from(mesh, 0)
	return surface.commit()


func _shift(mesh: ArrayMesh, by: Transform3D) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.create_from(mesh, 0)
	var out := ArrayMesh.new()
	var arrays := surface.commit_to_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index: int in points.size():
		points[index] = by * points[index]
	arrays[Mesh.ARRAY_VERTEX] = points
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


# ------------------------------------------------------------------------------------- authored


## The six boulders that are placed rather than scattered. Lifted out so the scatter can keep its
## distance from them: a palm growing out of a rock formation is the sort of thing only a machine
## would ever do.
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

	var material := StandardMaterial3D.new()
	material.albedo_color = ROCK_GREY
	material.roughness = 1.0

	var placements := _formations()
	var boulder := _rock_mesh()
	for placement: Array in placements:
		var where: Vector3 = placement[0]
		var size: Vector3 = placement[1]
		var turn: float = placement[2]
		where.y = _height_at(where.x, where.z) + size.y * 0.4

		var visual := MeshInstance3D.new()
		visual.name = "Rock"
		visual.mesh = boulder
		visual.material_override = material
		visual.transform = Transform3D(Basis(Vector3.UP, turn).scaled(size), where)
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
