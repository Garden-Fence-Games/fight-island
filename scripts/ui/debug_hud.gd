class_name DebugHud
extends CanvasLayer
## The timing readout, and nothing a player is meant to see: the real HUD is scenes/ui/hud.tscn.
## F3 shows it, it starts hidden, and a release build never carries it at all.

var player: Player = null

var _state_name: StringName = &""
var _last_hit: String = "-"
var _wave: String = "-"

@onready var health_bar: ProgressBar = $Panel/Rows/Health
@onready var stamina_bar: ProgressBar = $Panel/Rows/Stamina
@onready var readout: Label = $Panel/Rows/Readout


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	visible = GameState.debug_overlay_visible
	player = get_tree().get_first_node_in_group(&"player") as Player
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.stamina_changed.connect(_on_stamina_changed)
	EventBus.attack_landed.connect(_on_attack_landed)
	EventBus.parry_perfect.connect(_on_parry_perfect)
	EventBus.parry_late.connect(_on_parry_late)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	GameState.debug_overlay_toggled.connect(_on_toggled)
	if player != null and player.machine != null:
		player.machine.transitioned.connect(_on_transitioned)


func _process(_delta: float) -> void:
	if readout == null:
		return
	var locked := player.lockout_left() if player != null else 0.0
	readout.text = (
		"%s   chain %d   %s   %d fps\nwave %s   alive %d\nlast: %s"
		% [
			_state_name,
			player.chain_index if player != null else -1,
			"spent %.2fs" % locked if locked > 0.0 else "ready",
			Engine.get_frames_per_second(),
			_wave,
			get_tree().get_nodes_in_group(&"enemies").size(),
			_last_hit
		]
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_overlay"):
		GameState.toggle_debug_overlay()


func _on_toggled(shown: bool) -> void:
	visible = shown


func _on_transitioned(state_name: StringName) -> void:
	_state_name = state_name


func _on_player_damaged(current: float, maximum: float) -> void:
	if health_bar == null:
		return
	health_bar.max_value = maximum
	health_bar.value = current


func _on_stamina_changed(current: float, maximum: float) -> void:
	if stamina_bar == null:
		return
	stamina_bar.max_value = maximum
	stamina_bar.value = current


func _on_attack_landed(_target: Node3D, damage: float, perfect: bool, _attack: AttackData) -> void:
	_last_hit = "%.0f damage%s" % [damage, "  PERFECT" if perfect else ""]


func _on_wave_started(wave: int, enemies: int) -> void:
	_wave = "%d (%d coming)" % [wave, enemies]


func _on_wave_cleared(wave: int, reward: int) -> void:
	_wave = "%d cleared, +%d" % [wave, reward]


func _on_parry_perfect() -> void:
	_last_hit = "PERFECT PARRY"


func _on_parry_late() -> void:
	_last_hit = "late parry"
