class_name Hitscan
extends Node3D
## The gun's half of the hitbox pattern: a ray instead of a volume, resolved the instant the windup
## ends.
##
## A bullet has no travel and no swing, so it gets no active frames. Arming a box for a tenth of a
## second would mean a farmer could walk into a shot that had already been fired — which is the
## opposite of what makes a gun read as a gun.
##
## It builds the same `HitInfo` and calls the same `take_hit` the hitbox does, so a parry, a set of
## invulnerability frames and a death all behave identically whether the blow was a fist or a round.

signal landed(target: Node3D, info: HitInfo)

## Where the round leaves the body, and what it is aimed at: chest height at both ends, so a shot
## travels flat. An arc would be prettier and would also make the thing impossible to read.
const MUZZLE_HEIGHT: float = 1.1

## What the ray may hit. The same mask the hitbox beside it carries — enemy hurtboxes, and nothing
## else. **Terrain is deliberately not in it**: see `docs/game-design.md` on what a boulder does to
## a shot, which is currently nothing.
@export_flags_3d_physics var mask: int = PhysicsLayers.BIT_ENEMY_HURTBOX


## The body that was hit, or null for a miss. One ray, one answer: the double tap fires twice and
## may legitimately hit the same farmer both times, so nothing is remembered between shots.
func fire(attack: AttackData, source: Node3D, perfect: bool, scale_damage: float = 1.0) -> Node3D:
	var hurtbox := _first_in_the_way(attack, source)
	if hurtbox == null:
		return null
	var info := HitInfo.new(attack, source, perfect, scale_damage)
	if not hurtbox.take_hit(info):
		return null
	landed.emit(hurtbox.owner, info)
	return hurtbox.owner as Node3D


## The nearest hurtbox along the shot, or null. Flat and at chest height at both ends: an arc would
## be prettier and would also make the thing impossible to read at a glance.
func _first_in_the_way(attack: AttackData, source: Node3D) -> Hurtbox:
	if attack == null or source == null:
		return null
	var world := source.get_world_3d()
	var forward := -source.global_transform.basis.z
	forward.y = 0.0
	if world == null or forward.is_zero_approx():
		return null
	var from := source.global_position + Vector3.UP * MUZZLE_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(
		from, from + forward.normalized() * attack.reach
	)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = mask
	var excluded: Array[RID] = [source.get_rid()]
	# Past any corpse in the way. A body lying in the line of fire is not cover, and a round it
	# swallowed would be a miss on the farmer standing behind it.
	for _corpse: int in 8:
		query.exclude = excluded
		var found := world.direct_space_state.intersect_ray(query).get("collider") as Hurtbox
		if not (found is CorpseHurtbox):
			return found
		excluded.append(found.get_rid())
	return null
