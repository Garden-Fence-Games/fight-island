class_name PhysicsLayers
extends Object
## The physics layers, by name, as `project.godot` numbers them.
##
## A mask written as `1` says nothing about what it collides with, and a mask written as `1 | 256`
## says it twice as badly. The names live in `project.godot`, `verify_project_config` asserts them,
## and this is how code reaches them — so a layer that moves is renumbered in one place instead of
## being hunted through every raycast that happened to hard-code it.
##
## `BIT_*` is the mask value, the form `collision_mask` and a ray query take. `INDEX_*` is the
## one-based number, the form `set_collision_layer_value` takes.

const INDEX_WORLD: int = 1
const INDEX_PLAYER_BODY: int = 2
const INDEX_ENEMY_BODY: int = 3
const INDEX_PLAYER_HITBOX: int = 4
const INDEX_ENEMY_HITBOX: int = 5
const INDEX_PLAYER_HURTBOX: int = 6
const INDEX_ENEMY_HURTBOX: int = 7
const INDEX_INTERACTABLE: int = 8
const INDEX_CAMERA_OCCLUDER: int = 9
const INDEX_SPAWN_BLOCKER: int = 10

const BIT_WORLD: int = 1 << (INDEX_WORLD - 1)
const BIT_PLAYER_BODY: int = 1 << (INDEX_PLAYER_BODY - 1)
const BIT_ENEMY_BODY: int = 1 << (INDEX_ENEMY_BODY - 1)
const BIT_PLAYER_HITBOX: int = 1 << (INDEX_PLAYER_HITBOX - 1)
const BIT_ENEMY_HITBOX: int = 1 << (INDEX_ENEMY_HITBOX - 1)
const BIT_PLAYER_HURTBOX: int = 1 << (INDEX_PLAYER_HURTBOX - 1)
const BIT_ENEMY_HURTBOX: int = 1 << (INDEX_ENEMY_HURTBOX - 1)
const BIT_INTERACTABLE: int = 1 << (INDEX_INTERACTABLE - 1)
const BIT_CAMERA_OCCLUDER: int = 1 << (INDEX_CAMERA_OCCLUDER - 1)
const BIT_SPAWN_BLOCKER: int = 1 << (INDEX_SPAWN_BLOCKER - 1)
