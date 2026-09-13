extends Node
## Headless proof that the in-run HUD reads the bus and nothing else: every element answers a
## signal, the ammo panel only exists with a ranged weapon in hand, and damage numbers stay off
## until they are asked for.
## Runs as a scene rather than with --script, because --script starts no autoloads and the HUD is
## nothing but autoload listeners.
## Run: godot --headless --path . res://tools/verify_hud.tscn

const HUD: String = "res://scenes/ui/hud.tscn"
const SETTLE_FRAMES: int = 4
## Longer than the chip's punch, which grows for 0.08 and settles back over 0.2.
const PULSE_SETTLE: float = 0.4
## Inside the growing half of that punch, so the scale read is one the player would see.
const PULSE_SAMPLE: float = 0.04

var _failures: PackedStringArray = []
var _hud: CanvasLayer = null
var _target: Node3D = null
var _kept_run: Dictionary = {}


func _ready() -> void:
	_run()


func _run() -> void:
	# Driving a run writes one to disk. Whatever this machine already had goes back at the end: a
	# check that eats the developer's run is worse than no check.
	_kept_run = SaveManager.read_json(SaveManager.RUN_PATH)
	_hud = (load(HUD) as PackedScene).instantiate() as CanvasLayer
	add_child(_hud)
	_target = Node3D.new()
	add_child(_target)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 2.0, 6.0)
	add_child(camera)
	camera.make_current()
	await get_tree().process_frame

	_check_vitals()
	_check_wave_and_money()
	await _check_the_clock()
	await _check_ammo_follows_the_weapon()
	await _check_damage_numbers()
	await _check_credit_numbers()
	await _check_the_round_floats_off_the_body()
	await _check_the_feed_reports_what_arrived()
	await _check_the_chip_answers_money_arriving()
	await _check_one_kill_punches_both_chips()
	await _check_the_banner_announces_the_wave()
	await _check_a_late_hud_reads_the_bag()
	_check_stats_are_tallied()
	_put_the_run_back()
	_report()


func _put_the_run_back() -> void:
	if _kept_run.is_empty():
		SaveManager.clear_run()
		return
	SaveManager.write_json(SaveManager.RUN_PATH, _kept_run)


## Quarter past eight in the evening, which catches the two ways a clock face goes wrong: minutes
## printed as a fraction of an hour, and an hour that loses its leading zero at midnight.
func _check_the_clock() -> void:
	for hour: float in [20.25, 0.5]:
		GameState.hour = hour
		await get_tree().process_frame
		var reads := _label("Root/TopRight/ClockChip/Clock").text
		var wanted := "20:15" if is_equal_approx(hour, 20.25) else "00:30"
		if reads != wanted:
			_fail("the clock reads %s at %.2f, expected %s" % [reads, hour, wanted])


func _check_vitals() -> void:
	EventBus.player_damaged.emit(78.0, 100.0)
	EventBus.stamina_changed.emit(40.0, 100.0)
	var health := _label("Root/BottomLeft/Health/Row/Value")
	var stamina := _label("Root/BottomLeft/Stamina/Row/Value")
	if health.text != "78/100":
		_fail("health reads %s, expected 78/100" % health.text)
	if stamina.text != "40%":
		_fail("stamina reads %s, expected 40%%" % stamina.text)
	# Low health is the one place the HUD raises its voice.
	EventBus.player_damaged.emit(20.0, 100.0)
	if health.theme_type_variation != &"HudValueAlert":
		_fail("health should switch to the alert variation under a third")


## From a fresh run, deliberately. `GameState` restores a saved run at boot, so a developer with a
## run on this machine would start this check with their own money already in the purse — the
## check would fail for a reason that has nothing to do with the HUD.
func _check_wave_and_money() -> void:
	GameState.begin_run()
	EventBus.wave_started.emit(7, 12)
	GameState.earn(1450)
	if _label("Root/TopRight/WaveChip/Wave").text != "WAVE 07":
		_fail("wave reads %s, expected WAVE 07" % _label("Root/TopRight/WaveChip/Wave").text)
	if _label("Root/TopRight/MoneyChip/Money").text != "$1,450":
		_fail("money reads %s, expected $1,450" % _label("Root/TopRight/MoneyChip/Money").text)


func _check_ammo_follows_the_weapon() -> void:
	var ammo := _hud.get_node("Root/BottomRight/Ammo") as PanelContainer
	var melee := WeaponData.new()
	EventBus.weapon_equipped.emit(melee)
	await get_tree().process_frame
	if ammo.visible:
		_fail("ammo should be hidden with a melee weapon in hand")
	var gun := WeaponData.new()
	gun.is_ranged = true
	EventBus.weapon_equipped.emit(gun)
	EventBus.ammo_changed.emit(8, 24)
	await get_tree().process_frame
	if not ammo.visible:
		_fail("ammo should appear with a ranged weapon in hand")
	if _label("Root/BottomRight/Ammo/Rows/Row/Magazine").text != "08":
		_fail("magazine should read 08")


func _check_damage_numbers() -> void:
	if Settings.DEFAULTS[&"gameplay_damage_numbers"]:
		_fail("damage numbers must default to off")
	var numbers := _hud.get_node("Root/Numbers") as Control
	var restore: Variant = Settings.get_value(&"gameplay_damage_numbers")
	Settings.set_value(&"gameplay_damage_numbers", false)
	EventBus.attack_landed.emit(_target, 12.0, false, null)
	await get_tree().process_frame
	if numbers.get_child_count() != 0:
		_fail("a damage number appeared while the setting was off")
	Settings.set_value(&"gameplay_damage_numbers", true)
	EventBus.attack_landed.emit(_target, 12.0, true, null)
	await get_tree().process_frame
	if numbers.get_child_count() != 1:
		_fail("the setting is on and no damage number appeared")
	Settings.set_value(&"gameplay_damage_numbers", restore)


## The opposite default to the damage numbers, and the reason is the design rather than symmetry:
## a player has to learn that killing pays, and that is one number per body where damage is one per
## hit. A body worth nothing is the case worth checking — the tutorial's farmhands pay no money, and
## a `+$0` over every one of them would be the first thing anyone ever learns about the economy.
func _check_credit_numbers() -> void:
	if not Settings.DEFAULTS[&"gameplay_credit_numbers"]:
		_fail("credit numbers must default to on")
	var numbers := _hud.get_node("Root/Numbers") as Control
	var restore: Variant = Settings.get_value(&"gameplay_credit_numbers")
	_clear(numbers)

	Settings.set_value(&"gameplay_credit_numbers", false)
	EventBus.enemy_died.emit(_target, &"farmhand", 5)
	await get_tree().process_frame
	if numbers.get_child_count() != 0:
		_fail("a credit number appeared while the setting was off")

	Settings.set_value(&"gameplay_credit_numbers", true)
	EventBus.enemy_died.emit(_target, &"farmhand", 5)
	await get_tree().process_frame
	if numbers.get_child_count() != 1:
		_fail("the setting is on and no credit number appeared")
	elif (numbers.get_child(0) as Label).text != "+$5":
		_fail("a credit number reads %s, expected +$5" % (numbers.get_child(0) as Label).text)

	_clear(numbers)
	EventBus.enemy_died.emit(_target, &"farmhand", 0)
	await get_tree().process_frame
	if numbers.get_child_count() != 0:
		_fail("a body worth nothing still floated a number")
	Settings.set_value(&"gameplay_credit_numbers", restore)
	_clear(numbers)


## A round is the second thing a kill pays, so it leaves the body the way the money does and answers
## the same setting. The merchant's rounds must not: they were bought off a screen, and a number
## floating off a body that is not there would land wherever the last corpse happened to be.
func _check_the_round_floats_off_the_body() -> void:
	var numbers := _hud.get_node("Root/Numbers") as Control
	var restore: Variant = Settings.get_value(&"gameplay_credit_numbers")
	Settings.set_value(&"gameplay_credit_numbers", true)
	_clear(numbers)

	EventBus.rounds_scavenged.emit(1, _target)
	await get_tree().process_frame
	if numbers.get_child_count() != 1:
		_fail("a scavenged round floated nothing off the body that dropped it")
	elif (numbers.get_child(0) as Label).text != "+1 ammo":
		_fail("a scavenged round reads %s, expected +1 ammo" % (numbers.get_child(0) as Label).text)

	_clear(numbers)
	EventBus.rounds_scavenged.emit(2, null)
	await get_tree().process_frame
	if numbers.get_child_count() != 0:
		_fail("the merchant's rounds floated a number off a body that does not exist")

	Settings.set_value(&"gameplay_credit_numbers", restore)
	_clear(numbers)


## Driven on a feed of its own rather than the HUD's, which by this point in the run is carrying
## lines from every case above it — and a merge reads the line already standing.
##
## The two things worth holding are the ceiling and the merge: a wave pays per body, so one line per
## farmer would be a wall of text laid over the fight it is reporting on.
func _check_the_feed_reports_what_arrived() -> void:
	if not (_hud.get_node("Root/BottomRight/Feed") is PickupFeed):
		_fail("the HUD's bottom-right feed is not a PickupFeed")
	var feed := PickupFeed.new()
	add_child(feed)
	GameState.begin_run()
	await get_tree().process_frame

	GameState.earn(25)
	GameState.earn(30)
	await get_tree().process_frame
	if feed.get_child_count() != 1:
		_fail("two payouts in one instant took %d lines, expected one" % feed.get_child_count())
	elif (feed.get_child(0) as Label).text != "+$55":
		_fail("merged payouts read %s, expected +$55" % (feed.get_child(0) as Label).text)

	EventBus.rounds_scavenged.emit(1, _target)
	await get_tree().process_frame
	if feed.get_child_count() != 2:
		_fail("rounds landed on the money's line instead of starting their own")

	for _index: int in PickupFeed.LINES + 2:
		EventBus.weapon_found.emit(&"gun")
	await get_tree().process_frame
	if feed.get_child_count() != PickupFeed.LINES:
		_fail(
			(
				"the feed stands %d lines deep, expected %d"
				% [feed.get_child_count(), PickupFeed.LINES]
			)
		)

	feed.queue_free()
	await get_tree().process_frame
	GameState.end_run()


## Money arriving has to be visible on the chip too: a two-digit number changing in the corner of a
## fight is not something the eye catches on its own. Spending stays silent, and a player who asked
## for less flashing gets the text without the punch.
func _check_the_chip_answers_money_arriving() -> void:
	var chip := _hud.get_node("Root/TopRight/MoneyChip") as PanelContainer
	var restore: Variant = Settings.get_value(&"access_reduce_flashing")

	Settings.set_value(&"access_reduce_flashing", false)
	await _settle(chip)
	GameState.earn(25)
	await _sample()
	if chip.scale.x <= 1.0:
		_fail("the money chip did not answer money arriving")

	# Spending is the player's own doing, and they watched the price while they did it.
	await _settle(chip)
	GameState.spend(25)
	await _sample()
	if chip.scale.x > 1.0:
		_fail("the money chip punched on a purchase, which the player already watched")

	await _settle(chip)
	Settings.set_value(&"access_reduce_flashing", true)
	GameState.earn(25)
	await _sample()
	if chip.scale.x > 1.0:
		_fail("the chip punched with reduced flashing asked for")
	Settings.set_value(&"access_reduce_flashing", restore)
	await _settle(chip)


## The payout and the scavenged round come off one body, so both chips answer the same kill. A HUD
## that kept one tween handle for the two of them left the money chip stretched wherever its tween
## had got to when the round arrived, and nothing put it back.
func _check_one_kill_punches_both_chips() -> void:
	var chip := _hud.get_node("Root/TopRight/MoneyChip") as PanelContainer
	var ammo := _hud.get_node("Root/BottomRight/Ammo") as PanelContainer
	var restore: Variant = Settings.get_value(&"access_reduce_flashing")
	Settings.set_value(&"access_reduce_flashing", false)
	await _settle(chip)
	await _settle(ammo)

	GameState.earn(25)
	EventBus.rounds_scavenged.emit(2, null)
	await _sample()
	if chip.scale.x <= 1.0 or ammo.scale.x <= 1.0:
		_fail("a kill that paid and dropped a round did not punch both chips")

	await get_tree().create_timer(PULSE_SETTLE, true, false, true).timeout
	if not is_equal_approx(chip.scale.x, 1.0) or not is_equal_approx(ammo.scale.x, 1.0):
		_fail(
			(
				"a chip was left stretched after both pulsed — money %.3f, ammo %.3f"
				% [chip.scale.x, ammo.scale.x]
			)
		)
	Settings.set_value(&"access_reduce_flashing", restore)


## Waits out a pulse and puts the chip back, so one case's tween can never be read as the next
## case's answer. Frames would not do it: a punch lasts most of a third of a second and a headless
## frame is worth almost no time at all.
func _settle(chip: Control) -> void:
	await get_tree().create_timer(PULSE_SETTLE, true, false, true).timeout
	chip.scale = Vector2.ONE


## Read while the punch is still growing rather than a frame after the press. A single headless
## frame can be worth so little time that a real pulse has not visibly moved yet, which would read
## as no pulse at all.
func _sample() -> void:
	await get_tree().create_timer(PULSE_SAMPLE, true, false, true).timeout


## Numbers are freed by their own tween, which outlives the frame a check looks at. Clearing by hand
## keeps each case counting only the labels it caused.
func _clear(numbers: Control) -> void:
	for child: Node in numbers.get_children():
		numbers.remove_child(child)
		child.free()


## The one thing in the HUD that announces rather than reports, and the whole reward for surviving
## a night. Run after the money check, because passing a wave pays on the way through, and before
## the tally, which clears a wave of its own.
func _check_the_banner_announces_the_wave() -> void:
	var banner := _label("Root/Banner")
	if banner.modulate.a > 0.0:
		_fail("the banner should be invisible until a wave is passed")
	EventBus.wave_cleared.emit(3, 100)
	await get_tree().process_frame
	if banner.text != "WAVE 03 PASSED":
		_fail("the banner reads %s, expected WAVE 03 PASSED" % banner.text)
	if banner.modulate.a <= 0.0:
		_fail("the banner should be on screen when a wave is passed")


## A HUD is always built after the bag. A resumed run announces its ammunition while `GameState`
## is still booting, and a fresh one equips before the arena scene is swapped in — both emissions
## land where no HUD is listening, so the panel has to read the bag on the way up. It did not, and
## a player who continued a run carrying the gun had no counter for the rest of it.
func _check_a_late_hud_reads_the_bag() -> void:
	GameState.begin_run()
	GameState.loadout.find_weapon(&"gun")
	GameState.loadout.spend(2)
	var late := (load(HUD) as PackedScene).instantiate() as CanvasLayer
	add_child(late)
	await get_tree().process_frame
	var ammo := late.get_node("Root/BottomRight/Ammo") as PanelContainer
	if not ammo.visible:
		_fail("a HUD built with the gun already in the bag never showed the ammo panel")
	var magazine := (late.get_node("Root/BottomRight/Ammo/Rows/Row/Magazine") as Label).text
	var reserve := (late.get_node("Root/BottomRight/Ammo/Rows/Row/Reserve") as Label).text
	if magazine != "04" or reserve != "24":
		_fail("a late HUD reads %s/%s, expected 04/24" % [magazine, reserve])
	late.queue_free()
	await get_tree().process_frame
	GameState.end_run()


func _check_stats_are_tallied() -> void:
	GameState.begin_run()
	EventBus.attack_landed.emit(_target, 12.0, true, null)
	EventBus.parry_perfect.emit()
	EventBus.enemy_died.emit(_target, &"farmhand", 5)
	EventBus.wave_cleared.emit(1, 50)
	if GameState.stats.perfect_hits != 1 or GameState.stats.perfect_parries != 1:
		_fail("the perfect counters are not collected during the run")
	if GameState.stats.kills_of(&"farmhand") != 1:
		_fail("kills are not tallied by archetype")
	if GameState.stats.waves_cleared != 1:
		_fail("a cleared wave was not counted")
	if GameState.money != 55 or GameState.stats.money_earned != 55:
		_fail("the kill and the wave reward did not both reach the run state")
	GameState.end_run()


func _label(path: String) -> Label:
	return _hud.get_node(path) as Label


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	for _index: int in SETTLE_FRAMES:
		await get_tree().process_frame
	if _failures.is_empty():
		print(
			(
				"hud OK — vitals, wave, money, ammo, damage numbers, a kill paying where the player "
				+ "can see it, and the run tally"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
