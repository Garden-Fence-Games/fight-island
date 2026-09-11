class_name Ground
extends Node
## Where an actor may legally stand, answered by the navigation mesh rather than by a rule.
##
## Spawning is the reason this exists. A wave that drops a farmer inside a boulder, in the sea, or
## on a sandbank across a bay he cannot walk out of is a wave that reads as a broken game, and no
## amount of hand-placed markers survives an island that gets rebuilt from a seed.
##
## The question is deliberately not "is there navigation mesh here". Recast leaves walkable ground
## inside solid things — the middle of a boulder is floor as far as it is concerned, it is simply
## floor with no way in or out — so proximity alone would happily approve a spawn point in the
## middle of a rock. The honest question is whether an actor put here could **walk to the fight**,
## and that is the one asked below.
##
## With no navigation mesh under the level nothing is spawnable. That is the safe way round: a
## level that forgot to bake gets no enemies instead of enemies in the sea.

## How far a point may sit from walkable ground and still count, and how close a route must end to
## its destination to count as having arrived. Roughly a body's width: enough to forgive a spawn
## ring that lands slightly off the mesh, far too little to forgive the sea.
const SNAP_TOLERANCE: float = 1.0


## The nearest point of walkable ground, or the point itself when there is nothing to snap to.
static func closest_point(world: World3D, point: Vector3) -> Vector3:
	var map := world.navigation_map
	if NavigationServer3D.map_get_regions(map).is_empty():
		return point
	return NavigationServer3D.map_get_closest_point(map, point)


## Whether an actor standing here could walk to `toward`.
##
## A path query always answers: when the destination cannot be reached it returns the route to the
## closest point it could get to. So the test is not that a route exists, it is that the route ends
## where it was asked to — which is the difference between "there is ground under both of them" and
## "these two are on the same island".
static func can_walk_between(
	world: World3D, from: Vector3, toward: Vector3, tolerance := SNAP_TOLERANCE
) -> bool:
	var map := world.navigation_map
	if NavigationServer3D.map_get_regions(map).is_empty():
		return false
	var goal := NavigationServer3D.map_get_closest_point(map, toward)
	var route := NavigationServer3D.map_get_path(map, from, goal, true)
	if route.is_empty():
		return false
	return route[route.size() - 1].distance_to(goal) <= tolerance


## Whether an actor spawned here would be standing on ground, and on ground it can leave to reach
## `toward` — the player, in every case that matters.
##
## The snap is measured flat: the height a spawn point is handed is a guess, and holding it to the
## centimetre would reject perfectly good ground for being a metre too high.
static func is_spawnable(
	world: World3D, point: Vector3, toward: Vector3, tolerance := SNAP_TOLERANCE
) -> bool:
	var map := world.navigation_map
	if NavigationServer3D.map_get_regions(map).is_empty():
		return false
	var standing := NavigationServer3D.map_get_closest_point(map, point)
	if Vector2(standing.x - point.x, standing.z - point.z).length() > tolerance:
		return false
	return can_walk_between(world, standing, toward, tolerance)
