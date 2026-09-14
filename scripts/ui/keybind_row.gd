class_name KeybindRow
extends Button
## One action and the two things that fire it. Accept starts a capture, and **the device the player
## presses with decides which column changes** — so one row rebinds both without ever asking which
## half they meant.
##
## Escape cancels rather than binds. It costs the player the ability to put an action on Escape,
## and it buys them a way out of a capture they opened by accident, which is the better trade.

signal rebound

const LISTENING_KEY: String = "OPT_BIND_LISTENING"
const AXIS_THRESHOLD: float = 0.6

var action: String = "":
	set = _set_action

var _capturing: bool = false

@onready var title: Label = $Row/Title
@onready var keyboard: PanelContainer = $Row/Keyboard
@onready var keyboard_key: Label = $Row/Keyboard/Key
@onready var gamepad: PanelContainer = $Row/Gamepad
@onready var gamepad_key: Label = $Row/Gamepad/Key


func _ready() -> void:
	set_process_unhandled_input(false)
	focus_entered.connect(_on_focus_changed)
	focus_exited.connect(_on_focus_changed)
	mouse_entered.connect(grab_focus)
	pressed.connect(_start_capture)
	refresh()
	_on_focus_changed()


## A row that leaves the screen takes its capture with it.
##
## Without this a hidden row keeps listening: it swallows the Escape meant for the options screen,
## and it binds the next key pressed on a page the player has already moved on to, with nothing on
## screen to say it happened.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _capturing and not is_visible_in_tree():
		_stop_capture()


func _unhandled_input(event: InputEvent) -> void:
	if not _capturing:
		return
	if event is InputEventMouseMotion or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed(&"ui_cancel"):
		_stop_capture()
		return
	if not _is_bindable(event):
		return
	InputBindings.bind(action, event)
	_stop_capture()
	rebound.emit()


func refresh() -> void:
	if title == null:
		return
	title.text = tr("OPT_BIND_%s" % action.to_upper()).to_upper()
	keyboard_key.text = InputBindings.describe(action, InputBindings.Device.KEYBOARD)
	gamepad_key.text = InputBindings.describe(action, InputBindings.Device.GAMEPAD)


func _set_action(value: String) -> void:
	action = value
	refresh()


## A press, a click, a pad button, or a stick pushed far enough to mean it. Anything else is the
## player still moving, not choosing.
func _is_bindable(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		return absf((event as InputEventJoypadMotion).axis_value) >= AXIS_THRESHOLD
	return event.is_pressed() and InputBindings.device_of(event) >= 0


func _start_capture() -> void:
	if _capturing:
		return
	_capturing = true
	title.text = tr(LISTENING_KEY).to_upper()
	keyboard.theme_type_variation = &"BindChipActive"
	gamepad.theme_type_variation = &"BindChipActive"
	# A frame late, or the press that opened the capture would be the press that closes it.
	call_deferred("set_process_unhandled_input", true)


func _stop_capture() -> void:
	_capturing = false
	set_process_unhandled_input(false)
	keyboard.theme_type_variation = &"BindChip"
	gamepad.theme_type_variation = &"BindChip"
	refresh()


func _on_focus_changed() -> void:
	# Focus leaving is the player moving on — to another row, to the tab strip, out of the screen.
	# A capture that outlives it is a capture nobody can see, and two rows listening at once is a
	# coin toss over which one the next key lands on.
	if _capturing and not has_focus():
		_stop_capture()
	title.theme_type_variation = &"RowLabelActive" if has_focus() else &"RowLabel"
