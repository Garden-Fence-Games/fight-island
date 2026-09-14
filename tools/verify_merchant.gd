extends Node
## Headless proof of the two rules the economy is built on and the one thing the summary must not
## get wrong: a purchase reaches the living body straight away, there is exactly one of them per
## wave, and leftover money carries.
##
## The upgrade effects are the interesting half. A card that says "twenty more hit points" and does
## not give them is a lie no diff would catch.
## Run: godot --headless --path . res://tools/verify_merchant.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
const SUMMARY: String = "res://scenes/ui/run_summary.tscn"
const MERCHANT_SCENE: String = "res://scenes/ui/merchant_screen.tscn"
const SETTLE_FRAMES: int = 8

var _failures: PackedStringArray = []
var _player: Player = null
var _kept_run: Dictionary = {}


func _ready() -> void:
	_run()


func _run() -> void:
	# Driving a run writes one to disk. Whatever this machine already had goes back at the end: a
	# check that eats the developer's run is worse than no check.
	_kept_run = SaveManager.read_json(SaveManager.RUN_PATH)
	var arena := (load(ARENA) as PackedScene).instantiate()
	add_child(arena)
	# Wave 1 belongs to the tutorial now, and a lesson holding it open would leave this check
	# waiting for a parry nobody is going to throw. This one is not about the lesson.
	var tutorial := arena.get_node_or_null(^"TutorialDirector") as TutorialDirector
	if tutorial != null:
		tutorial.stand_down()
	await get_tree().physics_frame
	_player = arena.get_node("Player") as Player
	if _player == null:
		_fail("the arena holds no player")
		_report()
		return

	_check_tracks_are_data()
	_check_prices_follow_the_curve()
	await _check_health_reaches_the_body()
	_check_one_purchase_a_wave()
	await _check_later_waves_sell_more()
	_check_money_carries()
	await _check_a_weapon_track_moves_the_swing()
	await _check_the_summary_reads_the_run()
	# Last, and it puts the bag back: it empties the loadout to ask its question, and every check
	# above it buys.
	_check_the_merchant_sells_only_what_is_carried()
	_put_the_run_back()
	_report()


func _put_the_run_back() -> void:
	if _kept_run.is_empty():
		SaveManager.clear_run()
		return
	SaveManager.write_json(SaveManager.RUN_PATH, _kept_run)


func _check_tracks_are_data() -> void:
	var tracks := Upgrades.all()
	if tracks.size() != 5:
		_fail("expected five upgrade tracks, found %d" % tracks.size())
	for track: UpgradeTrack in tracks:
		if track.id.is_empty() or track.next_level_key.is_empty():
			_fail("a track is missing its id or its copy")
		if tr(track.next_level_key) == track.next_level_key:
			_fail("%s has no string for %s" % [track.id, track.next_level_key])


## The card shows what `Economy` says and nothing of its own, so the price on screen and the price
## in the design cannot drift apart.
func _check_prices_follow_the_curve() -> void:
	GameState.begin_run()
	var track := Upgrades.find(&"health")
	for owned: int in Economy.LEVEL_CAP:
		GameState.upgrade_levels[track.id] = owned
		if GameState.price_of(track) != Economy.upgrade_cost(owned):
			_fail("the merchant price for level %d is not the cost curve" % owned)
	GameState.upgrade_levels = {}


func _check_health_reaches_the_body() -> void:
	GameState.begin_run()
	EventBus.wave_started.emit(1, 4)
	GameState.earn(1000)
	var track := Upgrades.find(&"health")
	var before := _player.health.max_health
	_player.health.current_health = 1.0
	if not GameState.buy(track):
		_fail("a health purchase the player could afford was refused")
		return
	await get_tree().process_frame
	if not is_equal_approx(_player.health.max_health, before + track.max_health):
		_fail(
			(
				"max health is %.0f, expected %.0f"
				% [_player.health.max_health, before + track.max_health]
			)
		)
	# Buying more life and not getting it now is a purchase nobody makes twice.
	if not is_equal_approx(_player.health.current_health, _player.health.max_health):
		_fail("the health purchase did not heal to full")


## The shop sells what the player carries. Fifteen per cent more damage on a gun that turns up two
## waves from now is money spent on nothing, and the card said nothing about it.
##
## Held on `can_buy` rather than on the card, because the card is one of two ways to reach a
## purchase and the other is `buy` — a gate that only greyed a button out would be a gate.
func _check_the_merchant_sells_only_what_is_carried() -> void:
	var gun := Upgrades.find(&"gun")
	if gun == null or gun.weapon == &"":
		_fail("there is no gun track naming a weapon to gate on")
		return
	var carried := GameState.loadout.found.duplicate()
	GameState.money = 99999
	# A wave nothing has been bought in yet, since one purchase a wave is the other rule here.
	GameState.wave = 99
	GameState.loadout.found.clear()
	if GameState.can_buy(gun):
		_fail("the gun track is for sale before the gun has been found")
	if GameState.buy(gun):
		_fail("a gun upgrade was bought before the gun had been found")
	GameState.loadout.find_weapon(&"gun")
	if not GameState.can_buy(gun):
		_fail("the gun track is still refused once the gun is in the bag")
	GameState.loadout.found = carried


func _check_one_purchase_a_wave() -> void:
	var stamina := Upgrades.find(&"stamina")
	if GameState.can_buy(stamina):
		_fail("a second purchase was offered in the same wave")
	if GameState.buy(stamina):
		_fail("a second purchase in the same wave went through")
	EventBus.wave_started.emit(2, 6)
	if not GameState.can_buy(stamina):
		_fail("the next wave did not open the merchant again")


## Wave four sells two, and the same track may be both of them. The screen stays open after the
## first and closes after the second.
func _check_later_waves_sell_more() -> void:
	var stamina := Upgrades.find(&"stamina")
	EventBus.wave_started.emit(4, 20)
	GameState.earn(5000)
	var level := GameState.level_of(stamina)
	if GameState.purchases_left() != 2:
		_fail("wave 4 sells %d upgrades, expected 2" % GameState.purchases_left())
	var screen := (load(MERCHANT_SCENE) as PackedScene).instantiate() as MerchantScreen
	add_child(screen)
	await get_tree().process_frame
	var card: UpgradeCard = null
	for child: Node in screen.cards.get_children():
		if (child as UpgradeCard).track == stamina:
			card = child as UpgradeCard
	if card == null:
		_fail("the merchant has no stamina card")
		screen.queue_free()
		return
	screen._on_card_pressed(card)
	await get_tree().process_frame
	if not is_instance_valid(screen) or screen.is_queued_for_deletion():
		_fail("the merchant closed after the first of two purchases")
		return
	screen._on_card_pressed(card)
	await get_tree().process_frame
	if is_instance_valid(screen) and not screen.is_queued_for_deletion():
		_fail("the merchant stayed open with its allowance spent")
		screen.queue_free()
	if GameState.level_of(stamina) != level + 2:
		_fail(
			(
				"two purchases of the same track in one wave left it at %d"
				% GameState.level_of(stamina)
			)
		)
	if GameState.buy(Upgrades.find(&"health")):
		_fail("a third purchase went through in a wave that sells two")
	# Back to the second wave the checks after this one are written against.
	EventBus.wave_started.emit(2, 6)


func _check_money_carries() -> void:
	var before := GameState.money
	var stamina := Upgrades.find(&"stamina")
	var price := GameState.price_of(stamina)
	if not GameState.buy(stamina):
		_fail("the second wave's purchase was refused")
		return
	if GameState.money != before - price:
		_fail("money left over did not carry")
	if GameState.stats.money_spent <= 0:
		_fail("the purchase was not counted as money spent")


func _check_a_weapon_track_moves_the_swing() -> void:
	EventBus.wave_started.emit(3, 8)
	GameState.earn(1000)
	var fists := Upgrades.find(&"fists")
	var before := _player.damage_multiplier
	if not GameState.buy(fists):
		_fail("a fists purchase the player could afford was refused")
		return
	await get_tree().process_frame
	# The player holds the fists, so the fists track pays out.
	if not is_equal_approx(_player.damage_multiplier, before + fists.damage):
		_fail("the fists upgrade did not reach the swing")
	if _player.stamina_cost_multiplier >= 1.0:
		_fail("the fists upgrade did not make the swing cheaper")


func _check_the_summary_reads_the_run() -> void:
	GameState.stats.perfect_hits = 12
	GameState.stats.perfect_parries = 5
	GameState.stats.record_kill(&"farmhand")
	GameState.end_run()
	var summary := (load(SUMMARY) as PackedScene).instantiate() as RunSummary
	add_child(summary)
	await get_tree().process_frame
	summary.show_run(false)
	if summary.endless.visible:
		_fail("a death offered endless mode")
	if summary.combat.get_child_count() != 6:
		_fail("the combat panel is not the six lines the design asks for")
	summary.show_run(true)
	if not summary.endless.visible:
		_fail("a victory did not unlock endless")
	if summary.upgrades.get_child_count() != Upgrades.all().size():
		_fail("the upgrades panel does not list every track")
	summary.queue_free()


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	for _index: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	if _failures.is_empty():
		print(
			"merchant OK — prices, one more a visit every three waves, money carries, and the body grows"
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
