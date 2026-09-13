class_name CreditsScreen
extends Control
## Who made what, read off `data/credits.tres` rather than typed into this scene.
##
## An overlay like the options screen, opened from the title and closed back to it, so it costs no
## scene lifecycle and whatever is behind it stays behind it.
##
## **Nothing here knows what is in the list.** Adding an asset is a row in `docs/credits.md` and a
## rebuild; this file is never touched for it. That is the whole point: CC0 attribution the player
## cannot see is an intention rather than a credit, and a hand-kept second copy of the list goes
## wrong in exactly the direction that matters — by leaving somebody out.

signal closed

const ROLL: String = "res://data/credits.tres"
## The columns, as a share of the width left after the subject takes its own. Author and licence are
## short and the source can be a sentence, so the source takes what the other two leave.
const SUBJECT_WIDTH: float = 420.0
const AUTHOR_WIDTH: float = 220.0
const LICENCE_WIDTH: float = 200.0
## How fast the pad and the arrow keys wind the list, in pixels a second. Fast enough to cross the
## list without holding the stick down for an age, slow enough to read on the way past.
const SCROLL_SPEED: float = 900.0
const HEADING_GAP: int = 28

@onready var title: Label = $Content/Column/Header/TopRow/Title
@onready var scroll: ScrollContainer = $Content/Column/Panel/Scroll
@onready var rows: VBoxContainer = $Content/Column/Panel/Scroll/Rows


func _ready() -> void:
	title.text = tr("UI_CREDITS").to_upper()
	var roll := load(ROLL) as CreditsRoll
	if roll == null:
		push_error("credits: %s is missing — run tools/build_credits.gd" % ROLL)
		return
	_build_section("CREDITS_STUDIO", roll.studio, false)
	_build_section("CREDITS_PEOPLE", roll.people, false)
	_build_section("CREDITS_ASSETS", roll.assets, true)
	_build_section("CREDITS_TOOLS", roll.tools, false)
	UiSounds.arm(self)


## Held rather than pressed: a list is wound, not stepped through. Read in `_process` because the
## screen may be open over a stopped tree and `_physics_process` would never run.
func _process(delta: float) -> void:
	var wind := Input.get_axis(&"ui_up", &"ui_down")
	if not is_zero_approx(wind):
		scroll.scroll_vertical += int(wind * SCROLL_SPEED * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()


func _build_section(key: String, entries: Array[CreditEntry], with_author: bool) -> void:
	if entries.is_empty():
		return
	if rows.get_child_count() > 0:
		rows.add_child(_gap())
	rows.add_child(_heading(key))
	for entry: CreditEntry in entries:
		rows.add_child(_row(entry, with_author))


func _heading(key: String) -> Label:
	var label := Label.new()
	label.text = tr(key).to_upper()
	label.theme_type_variation = &"Heading"
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return label


## Air above a heading that is not the first. The list separation is tuned for rows, and a second
## section starting one row-gap below the last credit reads as part of it.
func _gap() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, HEADING_GAP)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


## One credit, as a line: what it is, who made it, under what, and where it came from. The source
## keeps its link text rather than its URL — a raw address in a column reads as noise, and the
## document beside it is where somebody chasing the licence will go anyway. The studio is the one
## row that breaks that rule, because an address nobody can read is not a way of being found.
##
## **Only the cells a row actually has.** Every table here is a different shape — the studio carries
## an address and no licence, a person carries a role and no source — and drawing the empty ones
## would hold a column open across sections that have nothing to put in it.
func _row(entry: CreditEntry, with_author: bool) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	line.add_child(_cell(entry.subject, SUBJECT_WIDTH, false))
	if with_author:
		line.add_child(_cell(entry.author, AUTHOR_WIDTH, true))
	if not entry.licence.is_empty():
		line.add_child(_cell(entry.licence, LICENCE_WIDTH, true))
	if not entry.source.is_empty():
		line.add_child(_cell(entry.source, 0.0, true))
	return line


func _cell(text: String, width: float, quiet: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.custom_minimum_size = Vector2(width, 0.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if width <= 0.0 else 0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if quiet:
		label.theme_type_variation = &"Caption"
	return label
