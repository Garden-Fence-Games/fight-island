extends Node
## The current run, and nothing else: no gameplay logic and no node references. Waves and money
## arrive in M2; for now it carries the run seed and the debug flags the prototype needs.

signal debug_overlay_toggled(visible: bool)

var run_seed: int = 0
var debug_overlay_visible: bool = true

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	run_seed = _rng.seed


func toggle_debug_overlay() -> void:
	debug_overlay_visible = not debug_overlay_visible
	debug_overlay_toggled.emit(debug_overlay_visible)
