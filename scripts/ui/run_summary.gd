class_name RunSummary
extends Control
## Shown on death and on victory, with the same layout both times so the shape is familiar. The
## only difference is the colour, the verdict at the top, and one line on victory.
##
## **Perfect hits and perfect parries are the two numbers that matter.** Everything else on this
## screen is trivia; those two are how a player finds out they are getting better, which is why
## they are the only figures set in the accent colour.

signal retried
signal left

const ROW_HEIGHT: float = 48.0

var won: bool = false

@onready var verdict: Label = $Content/Column/Head/Verdict
@onready var rule: ColorRect = $Content/Column/Head/Rule
@onready var combat: VBoxContainer = $Content/Column/Panels/Combat/Box/Rows
@onready var combat_heading: Label = $Content/Column/Panels/Combat/Box/Heading
@onready var enemies: VBoxContainer = $Content/Column/Panels/Enemies/Box/Rows
@onready var enemies_heading: Label = $Content/Column/Panels/Enemies/Box/Heading
@onready var upgrades: VBoxContainer = $Content/Column/Panels/Upgrades/Box/Rows
@onready var upgrades_heading: Label = $Content/Column/Panels/Upgrades/Box/Heading
@onready var endless: Label = $Content/Column/Endless
@onready var retry: Button = $Content/Column/Buttons/Retry
@onready var title: Button = $Content/Column/Buttons/Title


func _ready() -> void:
	retry.pressed.connect(_on_retry_pressed)
	title.pressed.connect(_on_title_pressed)
	retry.text = tr("UI_RETRY").to_upper()
	title.text = tr("UI_TITLE").to_upper()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_title_pressed()


## `victory` decides the palette and the one extra line. There is no score and no rank: a run is
## fifteen waves or it is not, and a letter grade on top of that would be a second game.
func show_run(victory: bool) -> void:
	won = victory
	var stats := GameState.stats
	var key := "SUMMARY_VICTORY" if victory else "SUMMARY_DEFEAT"
	verdict.text = (tr(key) % stats.ended_on_wave).to_upper()
	verdict.theme_type_variation = &"VerdictWon" if victory else &"Verdict"
	rule.color = Color(0.7843, 0.7843, 0.7608) if victory else Color(0.8275, 0.2275, 0.2275)
	for heading: Label in [combat_heading, enemies_heading, upgrades_heading]:
		heading.theme_type_variation = &"SummaryHeadingWon" if victory else &"SummaryHeading"
		heading.text = tr(heading.text).to_upper()
		heading.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	endless.visible = victory
	endless.text = tr("SUMMARY_ENDLESS")
	_fill_combat(stats)
	_fill_enemies(stats)
	_fill_upgrades()
	# Death lands on Retry and victory lands on Title: each is the thing the player came for.
	if victory:
		title.grab_focus()
	else:
		retry.grab_focus()


func _fill_combat(stats: RunStats) -> void:
	_clear(combat)
	_row(combat, tr("SUMMARY_WAVES"), str(stats.waves_cleared), false)
	_row(combat, tr("SUMMARY_TIME"), stats.formatted_time(), false)
	_row(combat, tr("SUMMARY_EARNED"), "$%d" % stats.money_earned, false)
	_row(combat, tr("SUMMARY_SPENT"), "$%d" % stats.money_spent, false)
	_row(combat, tr("SUMMARY_PERFECT_HITS"), str(stats.perfect_hits), true)
	_row(combat, tr("SUMMARY_PERFECT_PARRIES"), str(stats.perfect_parries), true)


## What the run actually felled, by archetype. An archetype that never turned up has no line,
## because the alternative is this screen keeping its own list of every enemy in the game.
func _fill_enemies(stats: RunStats) -> void:
	_clear(enemies)
	for archetype: StringName in stats.archetypes_seen():
		var name := tr("ENEMY_%s" % String(archetype).to_upper())
		_row(enemies, name, str(stats.kills_of(archetype)), false)


func _fill_upgrades() -> void:
	_clear(upgrades)
	for track: UpgradeTrack in Upgrades.all():
		_row(upgrades, track.display_name, tr("MERCHANT_LEVEL") % GameState.level_of(track), false)


func _clear(box: VBoxContainer) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _row(box: VBoxContainer, name: String, value: String, accent: bool) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.theme_type_variation = &"StatName"
	label.text = name.to_upper()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var figure := Label.new()
	figure.theme_type_variation = &"StatValueHot" if accent else &"StatValue"
	figure.text = value
	figure.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	figure.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	row.add_child(figure)
	box.add_child(row)


func _on_retry_pressed() -> void:
	retried.emit()


func _on_title_pressed() -> void:
	left.emit()
