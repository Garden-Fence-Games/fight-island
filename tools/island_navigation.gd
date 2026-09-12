extends RefCounted
## The mesh the enemies walk on, baked from the island's ground and from everything that blocks it.
##
## Split out of the generator because it is a self-contained job with its own vocabulary: it takes
## a height grid and a tree of colliders and produces one resource. Nothing else in the generator
## reads a single figure below.

## Baked here rather than at load. Recast takes a second on an island this size, and a navigation
## mesh rebuilt at every launch is one more thing that can differ between a run and a bug report.
const NAVIGATION_MESH: String = "res://assets/models/island_navmesh.res"
## The voxel the island is rasterised into, and with it the resolution of the whole navigation
## mesh. Coarse on purpose. Every polygon is scanned linearly on the queries an agent runs each
## frame, so the polygon count is a per-frame cost with thirty farmers on the island, and the mesh
## only has to answer "which way round this rock" — nothing about the fight is decided on it.
const NAV_CELL: float = 0.5
const NAV_CELL_HEIGHT: float = 0.2
## Far wider than the 0.35 m body. This is how much the navigation mesh is eroded away from
## anything solid, and a generous margin is what keeps routes off the edges — a farmer who clips a
## boulder because his path ran along its face reads as broken, and the metre costs nothing when
## nothing on the island is closer together than MIN_GAP. It must stay a whole number of cells:
## recast rounds it up to one and warns when that loses precision.
const NAV_AGENT_RADIUS: float = 1.0
const NAV_AGENT_HEIGHT: float = 1.8
const NAV_AGENT_MAX_CLIMB: float = 0.4
const NAV_AGENT_MAX_SLOPE: float = 50.0
## How steep an obstacle's cap is, as a multiple of its own width. Recast has no notion of "too
## high to be a floor": a flat-topped box is walkable ground four metres in the air, and the
## navigation mesh grows an unreachable island on every rock. Anything past the max slope is not a
## floor at all, so the caps are pitched well beyond it.
const NAV_CAP_PITCH: float = 1.6
## Only obstacles at least this wide are cut out of the navigation mesh. Everything narrower is a
## bump a body slides off, and cutting it out is not free: every hole adds contour, and the whole
## map is scanned linearly on the queries an agent runs each frame. Carving all thirteen hundred
## props cost twenty milliseconds a frame with thirty farmers on the island; carving only what is
## genuinely impassable costs a tenth of that and walks identically, because MIN_GAP already
## guarantees a body-and-a-half of clearance between any two of them.
const NAV_CARVE_RADIUS: float = 1.0
## How far a contour may stray from the voxels it was traced from, and how long one edge may run
## before it is split. Both loose, so the coastline comes back as a handful of long edges instead
## of a thousand half-metre steps.
const NAV_EDGE_ERROR: float = 4.0
const NAV_EDGE_LENGTH: float = 24.0
## Regions smaller than this are merged into their neighbour rather than kept as their own island.
const NAV_MERGE_SIZE: float = 60.0
## How many sides an obstacle is rasterised with. The navigation mesh only needs the footprint, and
## a palm is a 0.2 m post: eight sides already lands inside one voxel of a circle.
const NAV_OBSTACLE_SIDES: int = 8
## How far an obstacle is pushed into the ground before it is rasterised. Deeper than any relief a
## prop can be standing on, so its footprint is always rooted.
const NAV_OBSTACLE_SINK: float = 4.0


## The mesh the enemies walk on, baked from the ground and from every collider that blocks it.
##
## The obstacles are read back off the colliders that were just placed rather than from the list
## that produced them. It is one more step, and it buys the one guarantee that matters: what the
## navigation mesh avoids is exactly what the player bumps into. Two parallel lists of rocks would
## drift apart on the first change, and the symptom — an enemy walking into thin air, or standing
## in a tree — is nowhere near the cause.
static func bake(
	island: Node3D, heights: PackedFloat32Array, side: int, spacing: float, wade_limit: float
) -> NavigationRegion3D:
	var geometry := NavigationMeshSourceGeometryData3D.new()
	geometry.add_faces(walkable_faces(heights, side, spacing, wade_limit), Transform3D.IDENTITY)
	for path: String in ["Props/PropColliders", "RockFormations", "Huts"]:
		var body := island.get_node_or_null(NodePath(path))
		if body == null:
			printerr("no colliders at " + path + " to keep the navigation mesh out of")
			return null
		for node: Node in body.get_children():
			var collision := node as CollisionShape3D
			if collision == null:
				continue
			var solid := obstacle_faces(collision)
			if solid.is_empty():
				continue
			geometry.add_faces(solid, Transform3D.IDENTITY)

	var navmesh := NavigationMesh.new()
	navmesh.cell_size = NAV_CELL
	navmesh.cell_height = NAV_CELL_HEIGHT
	navmesh.agent_radius = NAV_AGENT_RADIUS
	navmesh.agent_height = NAV_AGENT_HEIGHT
	navmesh.agent_max_climb = NAV_AGENT_MAX_CLIMB
	navmesh.agent_max_slope = NAV_AGENT_MAX_SLOPE
	# Simplification, all of it for the same reason as NAV_CELL: fewer, larger polygons. The detail
	# mesh in particular buys height accuracy the agents never read — they walk on the terrain
	# collider, not on the navigation mesh.
	navmesh.detail_sample_distance = 0.0
	navmesh.edge_max_error = NAV_EDGE_ERROR
	navmesh.edge_max_length = NAV_EDGE_LENGTH
	navmesh.region_merge_size = NAV_MERGE_SIZE
	NavigationServer3D.bake_from_source_geometry_data(navmesh, geometry)
	if navmesh.get_polygon_count() == 0:
		printerr("the navigation mesh baked empty")
		return null
	if ResourceSaver.save(navmesh, NAVIGATION_MESH) != OK:
		printerr("could not save " + NAVIGATION_MESH)
		return null

	var region := NavigationRegion3D.new()
	region.name = "Navigation"
	# Loaded back rather than kept, so the scene points at the file instead of inlining six thousand
	# polygons of base64 into the .tscn.
	region.navigation_mesh = load(NAVIGATION_MESH)
	return region


## The ground, as triangles, cut off where the water gets too deep to wade.
##
## Winding is load-bearing and silent when wrong: recast decides what is walkable from the face
## normal, so a reversed quad is not a hole in the mesh — it is no mesh at all, with no error to
## read. Godot winds its front faces clockwise, and so must this.
## `wade_limit` is how deep the enemies may follow the player in: the mesh stops there, a little
## under the waterline, which is also what keeps the whole sea floor out of the bake for free.
static func walkable_faces(
	heights: PackedFloat32Array, side: int, spacing: float, wade_limit: float
) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var half := float(side - 1) * 0.5 * spacing
	for row: int in side - 1:
		for column: int in side - 1:
			var corners: Array[Vector3] = []
			var dry := true
			for offset: Vector2i in [
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)
			]:
				var c := column + offset.x
				var r := row + offset.y
				var height := heights[r * side + c]
				dry = dry and height > wade_limit
				corners.append(
					Vector3(float(c) * spacing - half, height, float(r) * spacing - half)
				)
			if not dry:
				continue
			(
				faces
				. append_array(
					[
						corners[0],
						corners[1],
						corners[2],
						corners[0],
						corners[2],
						corners[3],
					]
				)
			)
	return faces


## A collider as a shape recast will refuse to stand on: its own footprint, rooted well under the
## ground and capped with a pitched roof.
##
## Both halves are load-bearing. Sunk, because a collider floating even a few centimetres above the
## terrain leaves a sliver of walkable ground beneath it and the hole never appears. Pitched,
## because a flat top is a floor as far as recast is concerned, however high up it happens to be.
static func obstacle_faces(collision: CollisionShape3D) -> PackedVector3Array:
	var ring := footprint(collision.shape)
	if ring.is_empty():
		printerr("no navigation footprint for a " + collision.shape.get_class())
		return PackedVector3Array()
	var half := obstacle_half_height(collision.shape)
	var reach := 0.0
	for corner: Vector2 in ring:
		reach = maxf(reach, corner.length())
	if reach < NAV_CARVE_RADIUS:
		return PackedVector3Array()

	var faces := PackedVector3Array()
	var where := collision.transform
	var apex := where * Vector3(0.0, half + reach * NAV_CAP_PITCH, 0.0)
	for index: int in ring.size():
		var next := ring[(index + 1) % ring.size()]
		var here := ring[index]
		var base_a := where * Vector3(here.x, -half - NAV_OBSTACLE_SINK, here.y)
		var base_b := where * Vector3(next.x, -half - NAV_OBSTACLE_SINK, next.y)
		var top_a := where * Vector3(here.x, half, here.y)
		var top_b := where * Vector3(next.x, half, next.y)
		faces.append_array([base_a, base_b, top_b, base_a, top_b, top_a, top_a, top_b, apex])
	return faces


## The outline an obstacle occupies on the ground, in its own space. Only the two shapes the island
## actually uses; anything else would be a silent hole in the navigation mesh, so it is a loud one.
static func footprint(shape: Shape3D) -> PackedVector2Array:
	var ring := PackedVector2Array()
	var cylinder := shape as CylinderShape3D
	if cylinder != null:
		for step: int in NAV_OBSTACLE_SIDES:
			var angle := TAU * float(step) / float(NAV_OBSTACLE_SIDES)
			ring.append(Vector2(cos(angle), sin(angle)) * cylinder.radius)
		return ring
	var box := shape as BoxShape3D
	if box != null:
		var wide := box.size.x * 0.5
		var deep := box.size.z * 0.5
		(
			ring
			. append_array(
				[
					Vector2(-wide, -deep),
					Vector2(wide, -deep),
					Vector2(wide, deep),
					Vector2(-wide, deep),
				]
			)
		)
	return ring


static func obstacle_half_height(shape: Shape3D) -> float:
	var cylinder := shape as CylinderShape3D
	if cylinder != null:
		return cylinder.height * 0.5
	var box := shape as BoxShape3D
	if box != null:
		return box.size.y * 0.5
	return 0.0
