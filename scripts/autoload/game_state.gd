extends Node
## The current run, and nothing else: no gameplay logic and no node references. It listens rather
## than being told, so nothing has to remember to keep it up to date.

signal debug_overlay_toggled(visible: bool)

var run_seed: int = 0
var wave: int = 0
var debug_overlay_visible: bool = true

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	run_seed = _rng.seed
	EventBus.wave_started.connect(_on_wave_started)


func _on_wave_started(index: int, _enemies: int) -> void:
	wave = index


func toggle_debug_overlay() -> void:
	debug_overlay_visible = not debug_overlay_visible
	debug_overlay_toggled.emit(debug_overlay_visible)
