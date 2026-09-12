class_name ArchetypeShare
extends Resource
## One archetype's slice of a wave's composition.
##
## A resource for two fields looks like ceremony until you try the alternative: two parallel arrays
## on WaveBand, one of archetypes and one of weights, which go out of step the first time someone
## inserts a row in the inspector and stay wrong silently.

@export var enemy: EnemyData = null
## Relative, not a percentage. The band normalises over whatever it can actually spawn, so a share
## pointing at an archetype that does not exist yet costs nothing.
@export var share: float = 1.0
