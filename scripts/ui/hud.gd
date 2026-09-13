extends CanvasLayer
## The least possible while the fight is on: health and stamina bottom-left, ammo bottom-right when
## a ranged weapon is held, wave and money top-right. Everything else is the world.
##
## It listens on the EventBus and holds no reference to the player, so it survives a respawn, a
## restart and a player that does not exist yet — nothing here has to be wired to a node.

const DAMAGE_RISE: float = 56.0
const DAMAGE_LIFE: float = 0.7
const DAMAGE_HEIGHT: float = 1.6
## Money leaves the body slower and travels less far than damage does. A kill is one event where a
## hit is one of many, so the number that reports it can afford to be read rather than glimpsed.
const CREDIT_RISE: float = 38.0
const CREDIT_LIFE: float = 0.95
## Above the head rather than at it, so a killing blow's damage number and its payout do not start
## life on top of each other.
const CREDIT_HEIGHT: float = 2.1
## A punch, not a throb: the chip grows for a twelfth of a second and settles back over a fifth.
## Asymmetric on purpose — the eye catches the arrival and is not held by the departure.
const PULSE_SCALE: float = 1.12
const PULSE_UP: float = 0.08
const PULSE_DOWN: float = 0.2
const LOW_HEALTH: float = 0.35
const MINUTES_IN_AN_HOUR: float = 60.0
## How long "wave one passed" stays up. Long enough to read at a glance while the merchant is
## opening behind it, short enough not to sit over the first farmer of the next wave.
const BANNER_LIFE: float = 2.2
const BANNER_FADE: float = 0.4

var _pulsing: Dictionary[Control, Tween] = {}

@onready var wave_chip: PanelContainer = $Root/TopRight/WaveChip
@onready var wave: Label = $Root/TopRight/WaveChip/Wave
@onready var money_chip: PanelContainer = $Root/TopRight/MoneyChip
@onready var money: Label = $Root/TopRight/MoneyChip/Money
@onready var clock: Label = $Root/TopRight/ClockChip/Clock
@onready var banner: Label = $Root/Banner
@onready var health_bar: ProgressBar = $Root/BottomLeft/Health/Bar
@onready var health_value: Label = $Root/BottomLeft/Health/Row/Value
@onready var stamina_bar: ProgressBar = $Root/BottomLeft/Stamina/Bar
@onready var stamina_value: Label = $Root/BottomLeft/Stamina/Row/Value
@onready var ammo: PanelContainer = $Root/BottomRight/Ammo
@onready var ammo_magazine: Label = $Root/BottomRight/Ammo/Rows/Row/Magazine
@onready var ammo_reserve: Label = $Root/BottomRight/Ammo/Rows/Row/Reserve
@onready var numbers: Control = $Root/Numbers
@onready var captions: Array[Label] = [
	$Root/BottomLeft/Health/Row/Name,
	$Root/BottomLeft/Stamina/Row/Name,
	$Root/BottomRight/Ammo/Rows/Caption,
]


func _ready() -> void:
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.stamina_changed.connect(_on_stamina_changed)
	GameState.money_changed.connect(_on_money_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.weapon_equipped.connect(_on_weapon_equipped)
	EventBus.ammo_changed.connect(_on_ammo_changed)
	EventBus.rounds_scavenged.connect(_on_rounds_scavenged)
	EventBus.attack_landed.connect(_on_attack_landed)
	EventBus.enemy_died.connect(_on_enemy_died)
	# Captions are capitals in the design system and a Godot theme carries no text transform.
	for caption: Label in captions:
		caption.text = tr(caption.text).to_upper()
	_on_money_changed(GameState.money, 0)
	_on_wave_started(GameState.wave, 0)
	# The bag is read rather than waited for, because every ammunition signal has already gone out
	# by the time this scene exists: a resumed run announces at boot and a fresh one equips before
	# the arena is swapped in. Listening alone left a gun the player was carrying with no counter
	# at all for the rest of the run.
	_on_weapon_equipped(GameState.loadout.weapon())
	_on_ammo_changed(GameState.loadout.magazine, GameState.loadout.reserve)


## Polled rather than signalled: the hour moves every frame that a farmer is falling over, and a
## signal per frame is a signal nobody wants. Rounded to the minute, so the face ticks.
func _process(_delta: float) -> void:
	var minutes := roundi(GameState.hour * MINUTES_IN_AN_HOUR)
	clock.text = "%02d:%02d" % [(minutes / 60) % 24, minutes % 60]


func _on_player_damaged(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_value.text = "%d/%d" % [roundi(current), roundi(maximum)]
	# The number only turns on the player when it is worth turning on them.
	var low: bool = maximum > 0.0 and current / maximum <= LOW_HEALTH
	health_value.theme_type_variation = &"HudValueAlert" if low else &"HudValue"


func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	stamina_value.text = "%d%%" % roundi(current / maximum * 100.0) if maximum > 0.0 else "0%"


func _on_money_changed(balance: int, delta: int) -> void:
	money.text = "$%s" % _grouped(balance)
	if delta > 0:
		_pulse(money_chip)


## Rounds arrive off bodies, one at a time, in the middle of the fight that dropped them — which is
## exactly the moment a counter in the corner goes unread. Same answer as the money chip, for the
## same reason, and it is the only reason ammunition ever announces itself: spending and reloading
## are things the player did on purpose.
func _on_rounds_scavenged(_rounds: int) -> void:
	_pulse(ammo)


## A panel answers when something arrives, because the counter alone does not: a two-digit number
## changing in the corner of a fight is not something the eye is going to catch on its own.
##
## Spending is deliberately silent. The player pressed the button and watched the price — being
## punched at about it afterwards tells them nothing they did not just do.
func _pulse(chip: Control) -> void:
	if bool(Settings.get_value(&"access_reduce_flashing")):
		return
	# Per chip, not per HUD. The money and the ammo both answer to the same kill — the payout and the
	# round come off one body — so a single handle meant the second pulse killed the first one's
	# tween and left that chip stretched for the rest of the run.
	var running: Tween = _pulsing.get(chip)
	if running != null and running.is_valid():
		running.kill()
	# Read every time rather than cached in _ready: a chip is laid out after the first frame, and it
	# resizes when the balance gains a digit or a translation lengthens the string.
	chip.pivot_offset = chip.size * 0.5
	chip.scale = Vector2.ONE
	var tween := create_tween()
	tween.tween_property(chip, "scale", Vector2.ONE * PULSE_SCALE, PULSE_UP)
	tween.tween_property(chip, "scale", Vector2.ONE, PULSE_DOWN)
	_pulsing[chip] = tween


## Nothing before the first wave: a chip reading zero is furniture, and the director takes a
## breath before it sends anything.
func _on_wave_started(index: int, _enemies: int) -> void:
	wave_chip.visible = index >= 1
	wave.text = (tr("HUD_WAVE") % index).to_upper()


## The one thing in the HUD that announces rather than reports. It is the whole reward for surviving
## a night, so it is allowed to be the biggest text on screen for two seconds.
func _on_wave_cleared(index: int, _reward: int) -> void:
	banner.text = (tr("HUD_WAVE_PASSED") % index).to_upper()
	banner.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(BANNER_LIFE)
	tween.tween_property(banner, "modulate:a", 0.0, BANNER_FADE)


## Ammo is the one panel that comes and goes, and the weapon decides — a melee player never sees
## a magazine of zero.
func _on_weapon_equipped(weapon: WeaponData) -> void:
	ammo.visible = weapon != null and weapon.is_ranged


func _on_ammo_changed(magazine: int, reserve: int) -> void:
	ammo_magazine.text = "%02d" % magazine
	ammo_reserve.text = str(reserve)


func _on_attack_landed(target: Node3D, damage: float, perfect: bool, _attack: AttackData) -> void:
	if not bool(Settings.get_value(&"gameplay_damage_numbers")):
		return
	var variation := &"DamageNumberPerfect" if perfect else &"DamageNumber"
	_float_over(target, DAMAGE_HEIGHT, str(roundi(damage)), variation, DAMAGE_RISE, DAMAGE_LIFE)


## What the body was worth, off the same signal the wallet is paid by — so the number on screen and
## the money in the purse can never disagree, elite multiplier included.
##
## A body worth nothing says nothing: the tutorial's farmhands pay no money, and a `+$0` over each
## of them would be the first thing the player ever learns about the economy.
func _on_enemy_died(enemy: Node3D, _archetype: StringName, money_paid: int) -> void:
	if money_paid <= 0 or not bool(Settings.get_value(&"gameplay_credit_numbers")):
		return
	var text := "+$%s" % _grouped(money_paid)
	_float_over(enemy, CREDIT_HEIGHT, text, &"CreditNumber", CREDIT_RISE, CREDIT_LIFE)


## A label that starts over a point in the world and rises off the top of it. Screen space rather
## than a `Label3D`: these are HUD text, they must not be scaled by distance or turned by a camera,
## and the theme carries their look with the rest of the interface.
func _float_over(
	subject: Node3D, height: float, text: String, variation: StringName, rise: float, life: float
) -> void:
	if subject == null or not is_instance_valid(subject):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var over := subject.global_position + Vector3.UP * height
	# Behind the camera unprojects to a point in front of it, which would put the number on the
	# wrong side of the screen rather than nowhere.
	if camera.is_position_behind(over):
		return
	_spawn_number(camera.unproject_position(over), text, variation, rise, life)


func _spawn_number(
	at: Vector2, text: String, variation: StringName, rise: float, life: float
) -> void:
	var label := Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = at
	numbers.add_child(label)
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(label, "position:y", at.y - rise, life)
	tween.tween_property(label, "modulate:a", 0.0, life)
	tween.chain().tween_callback(label.queue_free)


## Thousands separated the way the money chip in the design shows them.
func _grouped(amount: int) -> String:
	var digits := str(absi(amount))
	var out := ""
	for index: int in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			out += ","
		out += digits[index]
	return ("-" if amount < 0 else "") + out
