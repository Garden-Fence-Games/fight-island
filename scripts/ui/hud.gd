extends CanvasLayer
## The least possible while the fight is on: health and stamina bottom-left, ammo bottom-right when
## a ranged weapon is held, wave and money top-right. Everything else is the world.
##
## It listens on the EventBus and holds no reference to the player, so it survives a respawn, a
## restart and a player that does not exist yet — nothing here has to be wired to a node.

const DAMAGE_RISE: float = 56.0
const DAMAGE_LIFE: float = 0.7
const DAMAGE_HEIGHT: float = 1.6
const LOW_HEALTH: float = 0.35
const MINUTES_IN_AN_HOUR: float = 60.0
## How long "wave one passed" stays up. Long enough to read at a glance while the merchant is
## opening behind it, short enough not to sit over the first farmer of the next wave.
const BANNER_LIFE: float = 2.2
const BANNER_FADE: float = 0.4

@onready var wave_chip: PanelContainer = $Root/TopRight/WaveChip
@onready var wave: Label = $Root/TopRight/WaveChip/Wave
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
	EventBus.attack_landed.connect(_on_attack_landed)
	ammo.visible = false
	# Captions are capitals in the design system and a Godot theme carries no text transform.
	for caption: Label in captions:
		caption.text = tr(caption.text).to_upper()
	_on_money_changed(GameState.money, 0)
	_on_wave_started(GameState.wave, 0)


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


func _on_money_changed(balance: int, _delta: int) -> void:
	money.text = "$%s" % _grouped(balance)


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


func _on_attack_landed(target: Node3D, damage: float, perfect: bool) -> void:
	if not bool(Settings.get_value(&"gameplay_damage_numbers")) or target == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var head := target.global_position + Vector3.UP * DAMAGE_HEIGHT
	if camera.is_position_behind(head):
		return
	_spawn_number(camera.unproject_position(head), damage, perfect)


func _spawn_number(at: Vector2, damage: float, perfect: bool) -> void:
	var label := Label.new()
	label.theme_type_variation = &"DamageNumberPerfect" if perfect else &"DamageNumber"
	label.text = str(roundi(damage))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = at
	numbers.add_child(label)
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(label, "position:y", at.y - DAMAGE_RISE, DAMAGE_LIFE)
	tween.tween_property(label, "modulate:a", 0.0, DAMAGE_LIFE)
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
