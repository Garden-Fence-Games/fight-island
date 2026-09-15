extends Node
## Proof that a kill still pays what it paid, now that the pay is thrown out of the body and walked
## over: the coins add up, the arc is high enough to be seen, walking near a piece takes it, a full
## pocket refuses a round, and the end of a wave loses nothing.
##
## Whatever run is on this machine is put back at the end.
## Run: godot --headless --path . res://tools/verify_loot.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
## Frames enough for the longest flight, at sixty a second, with room.
const FLIGHT_FRAMES: int = 90
## Frames enough for a pull from the edge of its reach, at its speed, with room.
const PULL_FRAMES: int = 45
## How far from the player a shower is thrown, so nothing is taken before the check asks for it.
const AWAY: Vector3 = Vector3(12.0, 0.0, 0.0)

var _failures: PackedStringArray = []
var _arena: Node3D = null
var _director: LootDirector = null
var _player: Player = null
var _data: LootData = null
var _kept_run: Dictionary = {}


func _ready() -> void:
	_run()


func _run() -> void:
	_kept_run = SaveManager.read_json(SaveManager.RUN_PATH)
	GameState.begin_run()
	await _open_the_arena()
	if _director == null or _player == null:
		_report()
		return
	_check_the_coins_add_up()
	_check_the_sweep_beats_the_merchant()
	await _check_a_kill_throws_its_pay()
	await _check_the_arc_is_seen()
	await _check_walking_over_it_takes_it()
	await _check_near_is_close_enough()
	await _check_a_full_pocket_refuses_a_round()
	await _check_the_end_of_a_wave_loses_nothing()
	await _check_a_piece_builds_almost_nothing()
	_put_the_run_back()
	_report()


func _open_the_arena() -> void:
	_arena = (load(ARENA) as PackedScene).instantiate() as Node3D
	add_child(_arena)
	await get_tree().physics_frame
	var tutorial := _arena.get_node_or_null(^"TutorialDirector") as TutorialDirector
	if tutorial != null:
		tutorial.stand_down()
	var waves := _arena.get_node_or_null(^"WaveDirector") as WaveDirector
	if waves != null:
		waves.halt()
	_director = _arena.get_node_or_null(^"LootDirector") as LootDirector
	_player = _arena.get_node_or_null(^"Player") as Player
	if _director == null:
		_fail("the arena has no LootDirector — nothing throws a kill's pay")
		return
	_data = _director.data
	if _data == null:
		_fail("the loot director has no data")
		_director = null


## Every coin of a shower together is exactly what the body was worth, and a rich body is a bigger
## shower rather than a hundred coins.
func _check_the_coins_add_up() -> void:
	for money: int in [0, 1, 2, 5, 8, 24, 100]:
		var values := _data.coin_values(money)
		var total := 0
		for value: int in values:
			total += value
		if total != money:
			_fail("a body worth %d sprays coins adding up to %d" % [money, total])
		if values.size() > _data.coins_most:
			_fail(
				(
					"a body worth %d sprays %d coins, over the %d ceiling"
					% [money, values.size(), _data.coins_most]
				)
			)
		if money > 0 and values.is_empty():
			_fail("a body worth %d sprays no coin at all" % money)


func _check_the_sweep_beats_the_merchant() -> void:
	if _data.sweep_after >= RunFlow.DELAY:
		_fail(
			(
				"the sweep lands %.2f s after a wave and the merchant opens at %.2f, before it"
				% [_data.sweep_after, RunFlow.DELAY]
			)
		)


## A death on the bus throws the body's money out as coins, and a round when the gun is carried.
## **What a piece costs to build**, which is the one allocation path left inside a fight: the two
## pools exist so nothing is constructed mid-wave, and loot was not in either. The runner on wave 3
## pays thirty-five pieces in a single call, in the frame the kill is meant to land.
##
## Asserted as a property rather than timed. A stopwatch here would measure this machine and would
## pass or fail by the weather; what has to stay true is that a second coin points at the first
## coin's mesh instead of building one of its own.
##
## And the flare's material must go the other way — **each piece needs its own**, because every one
## of them writes `albedo_color` on its own twinkle. Sharing it is the defect this repository has
## already met in the hitboxes and again in the impact flares, so the check holds both directions at
## once.
func _check_a_piece_builds_almost_nothing() -> void:
	_clear()
	var body := Node3D.new()
	_arena.add_child(body)
	body.global_position = _player.global_position + AWAY
	EventBus.enemy_died.emit(body, &"farmhand", 6)
	await get_tree().physics_frame

	var coins := _pieces(Loot.Kind.COIN)
	if coins.size() < 2:
		_fail("a body worth 6 threw %d coins, and this needs two to compare" % coins.size())
		return
	var first := coins[0].get_node_or_null(^"Spin/Body") as MeshInstance3D
	var second := coins[1].get_node_or_null(^"Spin/Body") as MeshInstance3D
	if first == null or second == null:
		_fail("a coin has no body to look at")
		return
	if first.mesh != second.mesh:
		_fail("two coins carry two meshes, so every piece of a payout builds its own")

	var one := coins[0].get_node_or_null(^"Flare") as MeshInstance3D
	var two := coins[1].get_node_or_null(^"Flare") as MeshInstance3D
	if one == null or two == null:
		_fail("a coin has no flare to look at")
		return
	if one.mesh != two.mesh:
		_fail("two flares carry two quads, and nothing writes to a quad")
	if one.material_override != null and one.material_override == two.material_override:
		_fail("two coins share one flare material, so they twinkle in step")
	_clear()


func _check_a_kill_throws_its_pay() -> void:
	_clear()
	GameState.loadout = Loadout.new()
	var body := Node3D.new()
	_arena.add_child(body)
	body.global_position = _player.global_position + AWAY
	EventBus.enemy_died.emit(body, &"farmhand", 5)
	var coins := _pieces(Loot.Kind.COIN)
	var total := 0
	for coin: Loot in coins:
		total += coin.amount
	if total != 5:
		_fail("a body worth 5 threw coins worth %d" % total)
	if not _pieces(Loot.Kind.ROUND).is_empty():
		_fail("a round was thrown for a player with no gun to put it in")
	body.queue_free()
	_clear()
	GameState.loadout.find_weapon(&"gun")
	var chance := Arsenal.find(&"gun").scavenge_chance
	# A body that drops rounds throws one, two or three of them, each its own piece on the sand.
	for pair: Array in [[0.1, 1], [0.5, 2], [0.9, 3]]:
		_director.spray(_player.global_position + AWAY, 2, chance * 0.5, pair[0])
		if _pieces(Loot.Kind.ROUND).size() != pair[1]:
			_fail(
				(
					"a count roll of %.1f threw %d rounds, expected %d"
					% [pair[0], _pieces(Loot.Kind.ROUND).size(), pair[1]]
				)
			)
		_clear()
		await get_tree().process_frame
	_director.spray(_player.global_position + AWAY, 2, 1.0)
	if not _pieces(Loot.Kind.ROUND).is_empty():
		_fail("a roll past the chance threw a round anyway")
	_clear()
	await get_tree().physics_frame


## Up above both of its ends by at least the lowest apex the table allows, and down on the sand by
## the end of its longest flight — the arc is the part that lets the player see it coming.
func _check_the_arc_is_seen() -> void:
	var from := _player.global_position + AWAY
	var pieces := _director.spray(from, 1, 1.0)
	if pieces.is_empty():
		_fail("a body worth 1 threw nothing")
		return
	var coin := pieces[0]
	var peak := -INF
	for _frame: int in FLIGHT_FRAMES:
		if not is_instance_valid(coin) or coin.has_landed():
			break
		peak = maxf(peak, coin.global_position.y)
		await get_tree().physics_frame
	if not is_instance_valid(coin) or not coin.has_landed():
		_fail("a coin was still in the air after %d frames" % FLIGHT_FRAMES)
		return
	var higher_end := maxf(from.y + _data.leaves_at, coin.lands_at().y)
	if peak < higher_end + _data.apex_lowest * 0.9:
		_fail(
			(
				"a coin peaked %.2f m above its higher end, and the table asks for at least %.2f"
				% [peak - higher_end, _data.apex_lowest]
			)
		)
	if absf(coin.global_position.y - coin.lands_at().y) > _data.bounce_height + 0.01:
		_fail(
			(
				"a coin came down %.2f m off the sand it was aimed at"
				% absf(coin.global_position.y - coin.lands_at().y)
			)
		)
	_clear()


## Standing on it takes it, and the purse rises by exactly what it carried.
func _check_walking_over_it_takes_it() -> void:
	var coin := await _a_landed_coin(5)
	if coin == null:
		return
	var before := GameState.money
	_player.global_position = coin.global_position
	for _frame: int in 4:
		await get_tree().physics_frame
	if is_instance_valid(coin) and not coin.is_queued_for_deletion():
		_fail("standing on a coin did not take it")
	if GameState.money - before != 5:
		_fail("taking a coin worth 5 put %d in the purse" % (GameState.money - before))
	_clear()


## Near is enough: inside the pull, outside the take, it flies in on its own.
func _check_near_is_close_enough() -> void:
	var coin := await _a_landed_coin(3)
	if coin == null:
		return
	var before := GameState.money
	var between := (_data.takes_within + _data.pulls_within) / 2.0
	var at := coin.global_position + Vector3(between, 0.0, 0.0)
	for _frame: int in PULL_FRAMES:
		_player.global_position = at
		await get_tree().physics_frame
		if not is_instance_valid(coin) or coin.is_queued_for_deletion():
			break
	if GameState.money - before != 3:
		_fail(
			(
				"a coin %.2f m away never came in (the pull reaches %.2f m)"
				% [between, _data.pulls_within]
			)
		)
	_clear()


## A pocket at its ceiling does not take a round, and the round waits on the sand until there is
## room.
func _check_a_full_pocket_refuses_a_round() -> void:
	GameState.loadout = Loadout.new()
	GameState.loadout.find_weapon(&"gun")
	var gun := Arsenal.find(&"gun")
	GameState.loadout.rounds = gun.ammo_cap
	var pieces := _director.spray(_player.global_position + AWAY, 0, 0.0, 0.0)
	if pieces.size() != 1:
		_fail("a roll of nothing, and a count roll of nothing, did not throw exactly one round")
		_clear()
		return
	var shell := pieces[0]
	for _frame: int in FLIGHT_FRAMES:
		await get_tree().physics_frame
	_player.global_position = shell.global_position
	for _frame: int in 6:
		await get_tree().physics_frame
	if not is_instance_valid(shell) or shell.is_queued_for_deletion():
		_fail("a full pocket took a round")
		return
	GameState.loadout.rounds -= 1
	for _frame: int in 6:
		await get_tree().physics_frame
	if is_instance_valid(shell) and not shell.is_queued_for_deletion():
		_fail("a round still lay there once the pocket had room")
	elif GameState.loadout.carried() != gun.ammo_cap:
		_fail(
			(
				"taking a round left %d carried, expected %d"
				% [GameState.loadout.carried(), gun.ammo_cap]
			)
		)
	_clear()


## Coins nobody walked over still reach the purse once the wave is cleared, and before the merchant.
func _check_the_end_of_a_wave_loses_nothing() -> void:
	var before := GameState.money
	_director.spray(_player.global_position + AWAY * 2.0, 8, 1.0)
	EventBus.wave_cleared.emit(1, 0)
	await get_tree().create_timer(RunFlow.DELAY, true, false, true).timeout
	if GameState.money - before != 8:
		_fail(
			(
				"a wave left 8 in coins on the sand and %d reached the purse before the merchant"
				% (GameState.money - before)
			)
		)
	if not _director.lying_about().is_empty():
		_fail("%d pieces were still lying about after the sweep" % _director.lying_about().size())


func _a_landed_coin(worth: int) -> Loot:
	var pieces := _director.spray(_player.global_position + AWAY, worth, 1.0)
	if pieces.is_empty():
		_fail("a body worth %d threw nothing" % worth)
		return null
	var coin := pieces[0]
	# One coin carrying the lot, so the purse can be read against it.
	for extra: Loot in pieces.slice(1):
		coin.amount += extra.amount
		extra.queue_free()
	for _frame: int in FLIGHT_FRAMES:
		if coin.has_landed():
			break
		await get_tree().physics_frame
	for _frame: int in 12:
		await get_tree().physics_frame
	if not coin.has_landed():
		_fail("a coin never landed")
		return null
	return coin


func _pieces(kind: Loot.Kind) -> Array[Loot]:
	var found: Array[Loot] = []
	for piece: Loot in _director.lying_about():
		if piece.kind == kind:
			found.append(piece)
	return found


func _clear() -> void:
	for piece: Loot in _director.lying_about():
		piece.queue_free()


func _put_the_run_back() -> void:
	GameState.end_run()
	if _kept_run.is_empty():
		SaveManager.erase(SaveManager.RUN_PATH)
	else:
		SaveManager.write_json(SaveManager.RUN_PATH, _kept_run)


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	for _index: int in 4:
		await get_tree().physics_frame
	if _failures.is_empty():
		print(
			(
				"loot OK — a kill's coins add up, arc high enough to see, come to a player who "
				+ "walks near, a full pocket leaves its round, and the end of a wave loses nothing"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
