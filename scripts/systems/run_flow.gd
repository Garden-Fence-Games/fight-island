class_name RunFlow
extends CanvasLayer
## What comes up between the fighting: the merchant after a wave, the summary after the last one or
## after a death. It listens on the bus and owns no gameplay — the wave director does not know the
## merchant exists, and the merchant does not know a wave does.
##
## Both screens stop the tree, which is what buys the merchant its breather: the director's own
## five-second gap only starts once the cards are gone.

const MERCHANT_SCENE: String = "res://scenes/ui/merchant_screen.tscn"
const SUMMARY_SCENE: String = "res://scenes/ui/run_summary.tscn"
const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"
const RUN_SCENE: String = "res://scenes/main/main.tscn"
## A beat before the screen arrives, so the last body finishes falling and the death reads as a
## death rather than as a menu.
const DELAY: float = 1.2

@export var config: WaveConfig = null

var _screen: Control = null


func _ready() -> void:
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.player_died.connect(_on_player_died)
	if merchant_is_owed():
		_open_merchant()


## A run resumed between two waves still owes its merchant: the wave was cleared before the player
## closed the game, and losing that wave's one purchase to a closed laptop is exactly what saving
## the run exists to prevent. Public and free of side effects so the headless check can ask it
## without standing up an arena.
func merchant_is_owed() -> bool:
	if not GameState.run_in_progress or GameState.wave_in_progress or GameState.wave <= 0:
		return false
	return GameState.can_buy_anything()


func _on_wave_cleared(wave: int, _reward: int) -> void:
	if config != null and wave >= config.final_wave:
		_open_summary(true)
		return
	# Nothing to sell means nothing to open: the player already spent this wave's one purchase.
	if GameState.can_buy_anything():
		_open_merchant()


func _on_player_died() -> void:
	_open_summary(false)


func _open_merchant() -> void:
	await _wait(DELAY)
	if _screen != null:
		return
	var merchant := _open(MERCHANT_SCENE) as MerchantScreen
	merchant.closed.connect(_on_screen_closed)
	EventBus.merchant_opened.emit()
	get_tree().paused = true


func _open_summary(victory: bool) -> void:
	await _wait(DELAY)
	if _screen != null:
		return
	GameState.end_run()
	EventBus.run_ended.emit(victory)
	var summary := _open(SUMMARY_SCENE) as RunSummary
	summary.retried.connect(_on_retry)
	summary.left.connect(_on_leave)
	get_tree().paused = true
	summary.show_run(victory)


func _open(scene: String) -> Control:
	_screen = (load(scene) as PackedScene).instantiate() as Control
	add_child(_screen)
	return _screen


## Unscaled and running while paused, because a hitstop or a pause must not stretch this beat.
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _on_screen_closed() -> void:
	_screen = null
	get_tree().paused = false


func _on_retry() -> void:
	_on_screen_closed()
	GameState.begin_run()
	get_tree().change_scene_to_file(RUN_SCENE)


func _on_leave() -> void:
	_on_screen_closed()
	get_tree().change_scene_to_file(TITLE_SCENE)
