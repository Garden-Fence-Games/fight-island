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
## The flat core. Combat happens here, it is always land, and nothing may stand in it.
const CORE_RADIUS: float = 24.0
## No land past here, whatever the noise says.
const MAX_RADIUS: float = 52.0
const BEACH_DEPTH: float = -2.4
const GRID: int = 141
const SPACING: float = 1.0
const WATER_LEVEL: float = -1.1
## How far below the waterline the sea floor keeps falling.
const SEA_DROP: float = 9.0

# --- Cliffs ------------------------------------------------------------------------------------
## Tall geometry only on the far side of the screen, so it reads as a backdrop and never stands
## between the camera and the fight. The camera looks from -X +Z toward +X -Z.
const CLIFF_DIRECTION: Vector2 = Vector2(0.707, -0.707)
const CLIFF_SPREAD: float = 0.45
const CLIFF_INNER: float = 33.0
const CLIFF_OUTER: float = 47.0
const CLIFF_HEIGHT: float = 12.0

# --- Scatter -----------------------------------------------------------------------------------
## No obstacle may stand inside this radius: a prop in the fighting core is a prop the reaper's
## 160° sweep will eventually trap someone against. Grass is exempt — it collides with nothing and
## a bare disc in the middle of an island reads as a mowed lawn.
const CLEAR_RADIUS: float = 22.0
const PALM_COUNT: int = 130
const ROCK_COUNT: int = 190
const GRASS_COUNT: int = 3200

const SAND: Color = Color(0.86, 0.78, 0.58)
const GRASS_GREEN: Color = Color(0.36, 0.52, 0.27)
const ROCK_GREY: Color = Color(0.33, 0.31, 0.29)

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _coast := FastNoiseLite.new()
var _clump := FastNoiseLite.new()


func _initialize() -> void:
	_rng.seed = SEED
	_noise.seed = SEED
	_noise.frequency = 0.06
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_coast.seed = SEED + 7
	_coast.frequency = 0.021
	_coast.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_coast.fractal_type = FastNoiseLite.FRACTAL_FBM
	_coast.fractal_octaves = 4
	_coast.fractal_gain = 0.55
	_clump.seed = SEED + 13
	_clump.frequency = 0.11
	_clump.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

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
	var guaranteed := (1.0 - smoothstep(CORE_RADIUS, CORE_RADIUS + 14.0, radius)) * 0.85
	return falloff * 1.05 + shape - 0.40 + guaranteed


## Metres above the water plane at a point. One function, so the mesh and the collision can never
## disagree about where the ground is.
func _height_at(x: float, z: float) -> float:
	var value := _land(x, z)
	var height := 0.0
	if value >= 0.0:
		height = _noise.get_noise_2d(x, z) * 0.3 * smoothstep(0.0, 0.35, value)
	else:
		height = BEACH_DEPTH * smoothstep(0.0, -0.22, value) + minf(value + 0.22, 0.0) * SEA_DROP

	# Whatever the field says, the fighting core is flat land.
	var core := 1.0 - smoothstep(CORE_RADIUS - 2.0, CORE_RADIUS + 5.0, Vector2(x, z).length())
	height = lerpf(height, 0.0, core)
	return height + _cliff_at(x, z)


## A wall on one side only. It is the backdrop, the orientation landmark, and the reason the player
## can tell which way they are facing without being able to turn the camera.
func _cliff_at(x: float, z: float) -> float:
	var flat := Vector2(x, z)
	var radius := flat.length()
	if radius < CLIFF_INNER or radius > CLIFF_OUTER:
		return 0.0
	var towards := flat.normalized().dot(CLIFF_DIRECTION)
	if towards < 1.0 - CLIFF_SPREAD:
		return 0.0
	var across := (towards - (1.0 - CLIFF_SPREAD)) / CLIFF_SPREAD
	var t := (radius - CLIFF_INNER) / (CLIFF_OUTER - CLIFF_INNER)
	var along := smoothstep(0.0, 0.28, t) * (1.0 - smoothstep(0.72, 1.0, t))
	# Never raise a cliff out of open water.
	var grounded := smoothstep(-0.1, 0.15, _land(x, z))
	return CLIFF_HEIGHT * smoothstep(0.0, 1.0, across) * along * grounded


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


## Vertex colour carries the beach-to-grass gradient, keyed to how far inland a point is rather
## than to its distance from the centre — which is what stops the green reading as a painted disc.
func _colour_at(x: float, z: float, height: float) -> Color:
	if height > 1.2:
		return ROCK_GREY.lerp(Color(0.45, 0.43, 0.4), clampf(height / 10.0, 0.0, 1.0))
	if height < WATER_LEVEL + 0.15:
		return SAND.darkened(0.42).lerp(Color(0.2, 0.35, 0.4), 0.45)
	var inland := _land(x, z)
	return SAND.lerp(GRASS_GREEN, smoothstep(0.18, 0.55, inland))


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
	var plane := PlaneMesh.new()
	plane.size = Vector2(1200.0, 1200.0)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.11, 0.33, 0.46, 0.88)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.08
	material.metallic = 0.35

	var instance := MeshInstance3D.new()
	instance.name = "Water"
	instance.mesh = plane
	instance.material_override = material
	instance.position = Vector3(0.0, WATER_LEVEL, 0.0)
	return instance


# -------------------------------------------------------------------------------------- scatter


## Every prop is decoration and none of it collides. Getting stuck on a bush is worse than any
## realism it would buy, and it keeps the navigation problem to the authored rock formations.
func _scatter() -> Node3D:
	var props := Node3D.new()
	props.name = "Props"

	var trunks: Array[Transform3D] = []
	var fronds: Array[Transform3D] = []
	for spot: Vector3 in _spots(PALM_COUNT, CLEAR_RADIUS, 2.4, 2.0, Vector2(0.05, 0.62)):
		var lean := Basis(Vector3.FORWARD, _rng.randf_range(-0.12, 0.12))
		var height := _rng.randf_range(3.4, 5.2)
		var trunk := Transform3D(lean.scaled(Vector3(1.0, height, 1.0)), spot)
		trunks.append(trunk)
		var crown := spot + lean * Vector3(0.0, height, 0.0)
		for blade: int in 6:
			var turn := Basis(Vector3.UP, TAU * float(blade) / 6.0 + _rng.randf_range(-0.3, 0.3))
			var droop := Basis(Vector3.RIGHT, _rng.randf_range(0.35, 0.7))
			fronds.append(Transform3D(turn * droop, crown))

	var rocks: Array[Transform3D] = []
	for spot: Vector3 in _spots(ROCK_COUNT, CLEAR_RADIUS, 1.2, 2.4, Vector2(-0.02, 0.9)):
		var size := _rng.randf_range(0.4, 1.3)
		var turn := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
		var tilt := Basis(Vector3.RIGHT, _rng.randf_range(-0.25, 0.25))
		rocks.append(
			Transform3D(
				(turn * tilt).scaled(Vector3(size, size * 0.7, size * _rng.randf_range(0.7, 1.3))),
				spot
			)
		)

	var tufts: Array[Transform3D] = []
	for spot: Vector3 in _spots(GRASS_COUNT, 0.0, 0.4, 2.4, Vector2(0.30, 2.0), 26.0):
		var turn := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
		var lean := Basis(Vector3.RIGHT, _rng.randf_range(-0.18, 0.18))
		var size := _rng.randf_range(0.6, 1.25)
		tufts.append(Transform3D((turn * lean).scaled(Vector3(size, size, size)), spot))

	props.add_child(_multi("PalmTrunks", _cylinder(0.16, 1.0), Color(0.42, 0.31, 0.2), trunks))
	props.add_child(_multi("PalmFronds", _frond(), Color(0.25, 0.47, 0.24), fronds))
	props.add_child(_multi("Rocks", _box(Vector3(1.0, 1.0, 1.0)), ROCK_GREY, rocks))
	props.add_child(_multi("Grass", _tuft(), GRASS_GREEN.darkened(0.18), tufts))
	return props


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
	spacing: float,
	clumping: float,
	band: Vector2,
	centre_fade: float = 0.0
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
		if centre_fade > 0.0:
			density *= smoothstep(centre_fade * 0.25, centre_fade, radius)
		if _rng.randf() > pow(density, clumping):
			continue

		var y := _height_at(x, z)
		# Nothing below the waterline, and nothing clinging to the cliff face.
		if y < WATER_LEVEL + 0.25 or _cliff_at(x, z) > 0.6:
			continue

		var spot := Vector3(x, y, z)
		var clear := true
		for other: Vector3 in kept:
			if spot.distance_to(other) < spacing:
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

	var placements: Array = [
		[Vector3(-26.0, 0.0, -19.0), Vector3(4.6, 6.0, 4.0), 0.4],
		[Vector3(-31.0, 0.0, -12.0), Vector3(3.2, 3.6, 3.2), 1.1],
		[Vector3(25.0, 0.0, 21.0), Vector3(3.8, 3.0, 3.4), 2.2],
		[Vector3(30.0, 0.0, 12.0), Vector3(2.8, 2.2, 2.8), 0.8],
		[Vector3(-9.0, 0.0, 30.0), Vector3(3.4, 2.6, 3.2), 1.7],
		[Vector3(14.0, 0.0, -29.0), Vector3(4.0, 4.6, 3.6), 0.2],
	]
	for placement: Array in placements:
		var where: Vector3 = placement[0]
		var size: Vector3 = placement[1]
		var turn: float = placement[2]
		where.y = _height_at(where.x, where.z) + size.y * 0.4

		var mesh := BoxMesh.new()
		mesh.size = size
		var visual := MeshInstance3D.new()
		visual.name = "Rock"
		visual.mesh = mesh
		visual.material_override = material
		visual.transform = Transform3D(Basis(Vector3.UP, turn), where)
		body.add_child(visual)

		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.name = "RockCollision"
		collision.shape = shape
		collision.transform = visual.transform
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
