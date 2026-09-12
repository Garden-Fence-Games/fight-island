extends Node
## Headless proof that the in-run HUD reads the bus and nothing else: every element answers a
## signal, the ammo panel only exists with a ranged weapon in hand, and damage numbers stay off
## until they are asked for.
## Runs as a scene rather than with --script, because --script starts no autoloads and the HUD is
## nothing but autoload listeners.
## Run: godot --headless --path . res://tools/verify_hud.tscn

const HUD: String = "res://scenes/ui/hud.tscn"
const SETTLE_FRAMES: int = 4

var _failures: PackedStringArray = []
var _hud: CanvasLayer = null
var _target: Node3D = null


func _ready() -> void:
	_run()


func _run() -> void:
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
	await _check_ammo_follows_the_weapon()
	await _check_damage_numbers()
	_check_stats_are_tallied()
	_report()


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


func _check_wave_and_money() -> void:
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
	EventBus.attack_landed.emit(_target, 12.0, false)
	await get_tree().process_frame
	if numbers.get_child_count() != 0:
		_fail("a damage number appeared while the setting was off")
	Settings.set_value(&"gameplay_damage_numbers", true)
	EventBus.attack_landed.emit(_target, 12.0, true)
	await get_tree().process_frame
	if numbers.get_child_count() != 1:
		_fail("the setting is on and no damage number appeared")
	Settings.set_value(&"gameplay_damage_numbers", restore)


func _check_stats_are_tallied() -> void:
	GameState.begin_run()
	EventBus.attack_landed.emit(_target, 12.0, true)
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
		print("hud OK — vitals, wave, money, ammo, damage numbers, run tally")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
