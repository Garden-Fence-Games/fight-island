class_name OptionsScreen
extends Control
## The five categories, built from the table below rather than from five hand-drawn pages: the
## settings surface is a list, and a list belongs in one readable place where it cannot drift out
## of step with `Settings.DEFAULTS`.
##
## It is an overlay, not a scene of its own, so the same screen answers from the title and from the
## pause menu without either of them losing what is behind it. `PROCESS_MODE_ALWAYS`, because from
## pause the tree is stopped and a frozen options screen is a soft lock.

signal closed

const ROW_SCENE: String = "res://scenes/ui/option_row.tscn"
const KEYBIND_SCENE: String = "res://scenes/ui/keybind_row.tscn"
const TAB_WIDTH: float = 180.0
const BIND_COLUMN: float = 180.0

## Everything the player can change, in the order it appears. `kind` and `values` are the only
## things that differ between a volume and a window mode, which is why one row scene covers both.
const PAGES: Array = [
	{
		"tab": "OPT_TAB_GAMEPLAY",
		"rows":
		[
			{
				"setting": &"gameplay_sprint_mode",
				"label": "OPT_SPRINT",
				"kind": OptionRow.Kind.PICKER,
				"values": ["auto", "hold", "toggle"],
				"value_keys": ["OPT_SPRINT_AUTO", "OPT_SPRINT_HOLD", "OPT_SPRINT_TOGGLE"],
			},
			{
				"setting": &"gameplay_aim_assist",
				"label": "OPT_AIM_ASSIST",
				"kind": OptionRow.Kind.PICKER,
				"values": ["off", "soft", "strong"],
				"value_keys": ["OPT_OFF", "OPT_AIM_SOFT", "OPT_AIM_STRONG"],
			},
			{
				"setting": &"gameplay_tutorial_prompts",
				"label": "OPT_TUTORIAL_PROMPTS",
				"kind": OptionRow.Kind.TOGGLE,
			},
			{
				"setting": &"gameplay_damage_numbers",
				"label": "OPT_DAMAGE_NUMBERS",
				"kind": OptionRow.Kind.TOGGLE,
			},
			{
				"setting": &"gameplay_credit_numbers",
				"label": "OPT_CREDIT_NUMBERS",
				"kind": OptionRow.Kind.TOGGLE,
			},
		],
	},
	{
		# Rebinding and nothing else. The three rows that used to sit here — mouse sensitivity, stick
		# sensitivity, invert Y — were for a camera that can be turned, and this one cannot be: see
		# `CameraRig`. There is no look delta to scale and no pitch to invert.
		"tab": "OPT_TAB_CONTROLS",
		"bindings": true,
		"rows": [],
	},
	{
		"tab": "OPT_TAB_VIDEO",
		"rows":
		[
			{
				"setting": &"video_window_mode",
				"label": "OPT_WINDOW_MODE",
				"kind": OptionRow.Kind.PICKER,
				"values": ["windowed", "borderless", "fullscreen"],
				"value_keys": ["OPT_WINDOWED", "OPT_BORDERLESS", "OPT_FULLSCREEN"],
			},
			{
				"setting": &"video_resolution",
				"label": "OPT_RESOLUTION",
				"kind": OptionRow.Kind.PICKER,
				"values": ["1280x720", "1600x900", "1920x1080", "2560x1440", "3840x2160"],
				"value_keys":
				["1280 × 720", "1600 × 900", "1920 × 1080", "2560 × 1440", "3840 × 2160"],
			},
			{
				"setting": &"video_vsync",
				"label": "OPT_VSYNC",
				"kind": OptionRow.Kind.PICKER,
				"values": ["off", "on", "adaptive"],
				"value_keys": ["OPT_OFF", "OPT_ON", "OPT_ADAPTIVE"],
			},
			{
				"setting": &"video_frame_cap",
				"label": "OPT_FRAME_CAP",
				"kind": OptionRow.Kind.PICKER,
				"values": ["0", "60", "120", "144", "240"],
				"value_keys": ["OPT_UNLIMITED", "60", "120", "144", "240"],
			},
			{
				"setting": &"video_pixel_look",
				"label": "OPT_PIXEL_LOOK",
				"kind": OptionRow.Kind.TOGGLE
			},
		],
	},
	{
		"tab": "OPT_TAB_AUDIO",
		"rows":
		[
			{"setting": &"audio_master", "label": "OPT_MASTER", "kind": OptionRow.Kind.SLIDER},
			{"setting": &"audio_music", "label": "OPT_MUSIC", "kind": OptionRow.Kind.SLIDER},
			{"setting": &"audio_sfx", "label": "OPT_SFX", "kind": OptionRow.Kind.SLIDER},
			{"setting": &"audio_ambience", "label": "OPT_AMBIENCE", "kind": OptionRow.Kind.SLIDER},
		],
	},
	{
		"tab": "OPT_TAB_ACCESS",
		"rows":
		[
			{
				"setting": &"access_screen_shake",
				"label": "OPT_SCREEN_SHAKE",
				"kind": OptionRow.Kind.SLIDER,
				"suffix": "%",
			},
			{"setting": &"access_hitstop", "label": "OPT_HITSTOP", "kind": OptionRow.Kind.TOGGLE},
			{
				"setting": &"access_hold_to_confirm",
				"label": "OPT_HOLD_TO_CONFIRM",
				"kind": OptionRow.Kind.TOGGLE,
			},
			{
				"setting": &"access_reduce_flashing",
				"label": "OPT_REDUCE_FLASHING",
				"kind": OptionRow.Kind.TOGGLE,
			},
		],
	},
]

var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _page: int = 0

@onready var title: Label = $Content/Column/Header/TopRow/Title
@onready var tabs: HBoxContainer = $Content/Column/Header/Tabs
@onready var page_box: VBoxContainer = $Content/Column/Panel/Scroll/Pages


func _ready() -> void:
	title.text = tr("UI_OPTIONS").to_upper()
	for index: int in PAGES.size():
		_tab_buttons.append(_build_tab(index))
		_pages.append(_build_page(PAGES[index]))
	show_page(0)
	UiSounds.arm(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	if event.is_action_pressed(&"menu_prev_tab"):
		get_viewport().set_input_as_handled()
		show_page(wrapi(_page - 1, 0, _pages.size()))
	elif event.is_action_pressed(&"menu_next_tab"):
		get_viewport().set_input_as_handled()
		show_page(wrapi(_page + 1, 0, _pages.size()))


func close() -> void:
	closed.emit()
	queue_free()


func _build_tab(index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(TAB_WIDTH, 0.0)
	button.focus_mode = Control.FOCUS_NONE
	button.text = tr(str(PAGES[index]["tab"])).to_upper()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.pressed.connect(show_page.bind(index))
	tabs.add_child(button)
	return button


func _build_page(page: Dictionary) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.visible = false
	page_box.add_child(column)
	if bool(page.get("bindings", false)):
		_build_bindings(column)
	for row: Dictionary in page["rows"]:
		column.add_child(_build_row(row))
	if bool(page.get("bindings", false)):
		column.add_child(_build_resets())
	return column


func _build_row(row: Dictionary) -> OptionRow:
	var control := (load(ROW_SCENE) as PackedScene).instantiate() as OptionRow
	control.setting = row["setting"]
	control.label_key = str(row["label"])
	control.kind = row["kind"]
	control.values = PackedStringArray(row.get("values", []))
	control.value_keys = PackedStringArray(row.get("value_keys", []))
	control.minimum = float(row.get("minimum", 0.0))
	control.maximum = float(row.get("maximum", 100.0))
	control.step = float(row.get("step", 10.0))
	control.suffix = str(row.get("suffix", ""))
	return control


func _build_bindings(column: VBoxContainer) -> void:
	column.add_child(_build_bind_header())
	for action: String in InputBindings.rebindable():
		var row := (load(KEYBIND_SCENE) as PackedScene).instantiate() as KeybindRow
		row.action = action
		column.add_child(row)


func _build_bind_header() -> PanelContainer:
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"ColumnHeader"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	frame.add_child(row)
	row.add_child(_column_label("OPT_ACTION", 0.0, HORIZONTAL_ALIGNMENT_LEFT))
	row.add_child(_column_label("OPT_KEYBOARD", BIND_COLUMN, HORIZONTAL_ALIGNMENT_CENTER))
	row.add_child(_column_label("OPT_GAMEPAD", BIND_COLUMN, HORIZONTAL_ALIGNMENT_CENTER))
	return frame


func _column_label(key: String, width: float, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"BindPad"
	label.text = tr(key).to_upper()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.horizontal_alignment = alignment
	label.custom_minimum_size = Vector2(width, 0.0)
	if is_zero_approx(width):
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


## Per device, because a player who has bound two things to the same key needs a way out that is
## not deleting a file — and needs it without losing the half that still works.
func _build_resets() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	for device: int in [InputBindings.Device.KEYBOARD, InputBindings.Device.GAMEPAD]:
		var button := Button.new()
		button.theme_type_variation = &"ResetButton"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = (
			tr(
				(
					"OPT_RESET_KEYBOARD"
					if device == InputBindings.Device.KEYBOARD
					else "OPT_RESET_GAMEPAD"
				)
			)
			. to_upper()
		)
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.pressed.connect(_on_reset_pressed.bind(device))
		row.add_child(button)
	return row


## Which category is on screen. Public because the shoulder buttons, the tab strip and the
## headless check all ask for the same thing.
func show_page(index: int) -> void:
	_page = index
	for slot: int in _pages.size():
		_pages[slot].visible = slot == index
		_tab_buttons[slot].theme_type_variation = (
			&"TabButtonActive" if slot == index else &"TabButton"
		)
	_focus_first(_pages[index])


func _focus_first(page: Control) -> void:
	for child: Node in page.get_children():
		var button := child as Button
		if button != null and button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus()
			return


func _on_reset_pressed(device: InputBindings.Device) -> void:
	InputBindings.reset_device(device)
	for node: Node in _pages[_page].get_children():
		var row := node as KeybindRow
		if row != null:
			row.refresh()
