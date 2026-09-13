class_name LootDirector
extends Node
## Throws a body's pay out of it when it dies, and sweeps up whatever the player left on the sand.
##
## **A kill pays what it always paid.** The coins add up to exactly `enemy_died`'s money, and a
## round turns up on the gun's own `scavenge_chance` — the roll the bag used to make on the spot.
## Only the arrival moved: it is thrown, lands, and is walked over. See `LootData` and `Loot`.
##
## **The end of a wave empties the sand into the bag.** Whatever is still lying there when the wave
## is cleared flies at the player, and what has not arrived by `LootData.sweep_after` goes in the
## bag anyway — before the merchant opens, so a wave that was too busy to walk over its coins is not
## a wave that paid less. It flies rather than vanishing because the last body of a wave dies on the
## same frame the wave ends, and its coins deserve their arc as much as anyone's.

const DATA: String = "res://data/pickups/loot.tres"

@export var data: LootData = null

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = GameState.run_seed + 5
	if data == null:
		data = load(DATA) as LootData
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.wave_cleared.connect(_on_wave_cleared)


## Throws what a body worth `money` pays, from where it fell. Public so the headless checks can drop
## a known shower without killing anybody. `round_roll` is handed in for the same reason the bag's
## roll always was: a chance that rolls its own dice can only be checked ten thousand times over.
func spray(from: Vector3, money: int, round_roll: float) -> Array[Loot]:
	var thrown: Array[Loot] = []
	if data == null:
		return thrown
	for value: int in data.coin_values(money):
		thrown.append(_throw(Loot.Kind.COIN, value, from))
	if GameState.loadout.rolls_a_round(round_roll):
		thrown.append(_throw(Loot.Kind.ROUND, 1, from))
	return thrown


## Everything still lying on the island, in the air or on the sand.
func lying_about() -> Array[Loot]:
	var found: Array[Loot] = []
	for child: Node in get_children():
		var piece := child as Loot
		if piece != null and not piece.is_queued_for_deletion():
			found.append(piece)
	return found


## Into the bag, all of it. A round the bag has no room for stays lost with the wave: the pocket was
## full, and a pocket that could be overfilled at the bell would not have a ceiling.
func sweep() -> void:
	for piece: Loot in lying_about():
		if not piece.collect():
			piece.queue_free()


func _throw(kind: Loot.Kind, amount: int, from: Vector3) -> Loot:
	var piece := Loot.new()
	piece.kind = kind
	piece.amount = amount
	piece.data = data
	piece.player = get_tree().get_first_node_in_group(&"player") as Node3D
	add_child(piece)
	var viewport := get_viewport()
	var space := viewport.world_3d.direct_space_state if viewport != null else null
	piece.throw(from, _rng, space)
	return piece


func _on_enemy_died(enemy: Node3D, _archetype: StringName, money: int) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	spray(enemy.global_position, money, _rng.randf())


func _on_wave_cleared(_wave: int, _reward: int) -> void:
	if lying_about().is_empty():
		return
	for piece: Loot in lying_about():
		piece.call_in()
	# Unpaused and unscaled, like `RunFlow`'s own beat: the merchant pauses the tree, and a sweep
	# that paused with it would open the shop before the wave's money had arrived.
	await get_tree().create_timer(data.sweep_after, true, false, true).timeout
	if not is_inside_tree():
		return
	sweep()
	# `GameState` saved the run when the wave was cleared, before any of this had landed in the purse.
	GameState.save_run()
