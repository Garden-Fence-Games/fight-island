extends Node
## Proof that the credits the player is shown are the credits the repository keeps.
##
## `docs/credits.md` carries the rule — a file with no row does not ship — and the screen is what
## turns that rule into an attribution somebody can actually read. Two ways it could quietly stop
## being true: a row added to the document and never baked, or a row baked and never drawn. Both are
## checked here, because both fail in the same direction, by leaving somebody out.
## Run: godot --headless --path . res://tools/verify_credits.tscn

const ROLL: String = "res://data/credits.tres"
const SCREEN: String = "res://scenes/ui/credits_screen.tscn"
const TITLE: String = "res://scenes/ui/title_screen.tscn"
## Rows the document is expected to carry at the very least. Not a count of today's table — that
## would need editing every time an asset lands — but a floor under "the parser returned something".
const AT_LEAST: int = 4

var _failures: PackedStringArray = []


func _ready() -> void:
	_run()


func _run() -> void:
	_check_the_document_still_parses()
	_check_the_baked_roll_matches_the_document()
	await _check_every_row_reaches_the_screen()
	await _check_the_title_opens_and_closes_it()
	_report()


func _check_the_document_still_parses() -> void:
	var fresh := CreditsSource.parse()
	if fresh == null:
		_fail("%s could not be read at all" % CreditsSource.DOCUMENT)
		return
	if fresh.studio.is_empty():
		_fail(
			(
				"%s names no studio — the game has to say whose it is and where to find them"
				% CreditsSource.DOCUMENT
			)
		)
	if fresh.people.is_empty():
		_fail(
			(
				"%s names nobody — the people are the credit a player is actually owed"
				% CreditsSource.DOCUMENT
			)
		)
	if fresh.assets.size() < AT_LEAST or fresh.tools.is_empty():
		_fail(
			(
				(
					"%s parsed to %d assets and %d tools, which is fewer than the document plainly has "
					+ "— the table shape and the parser have come apart"
				)
				% [CreditsSource.DOCUMENT, fresh.assets.size(), fresh.tools.size()]
			)
		)


## The baked resource against a fresh read of the document, field by field. A row added to one and
## not the other fails here rather than on the screen after release.
func _check_the_baked_roll_matches_the_document() -> void:
	var fresh := CreditsSource.parse()
	var baked := load(ROLL) as CreditsRoll
	if fresh == null:
		return
	if baked == null:
		_fail("%s is missing — run tools/build_credits.gd" % ROLL)
		return
	_compare("studio", fresh.studio, baked.studio)
	_compare("people", fresh.people, baked.people)
	_compare("assets", fresh.assets, baked.assets)
	_compare("tools", fresh.tools, baked.tools)


func _compare(which: String, fresh: Array[CreditEntry], baked: Array[CreditEntry]) -> void:
	if fresh.size() != baked.size():
		_fail(
			(
				"%s has %d %s rows and %s has %d — run tools/build_credits.gd"
				% [CreditsSource.DOCUMENT, fresh.size(), which, ROLL, baked.size()]
			)
		)
		return
	for index: int in fresh.size():
		var written := _flatten(fresh[index])
		var shipped := _flatten(baked[index])
		if written != shipped:
			_fail(
				(
					"%s row %d reads %s and %s reads %s — run tools/build_credits.gd"
					% [which, index, written, ROLL, shipped]
				)
			)
			return


func _flatten(entry: CreditEntry) -> String:
	return "%s | %s | %s | %s" % [entry.subject, entry.author, entry.licence, entry.source]


## Every subject and every licence, found in the text of some label on the built screen. Reading the
## labels rather than the resource is the point: a screen that loaded the roll and drew half of it
## would satisfy any check that only asked the roll.
func _check_every_row_reaches_the_screen() -> void:
	var screen := (load(SCREEN) as PackedScene).instantiate() as CreditsScreen
	add_child(screen)
	await get_tree().process_frame
	var drawn := _text_of(screen)
	var roll := load(ROLL) as CreditsRoll
	if roll == null:
		screen.queue_free()
		return
	for entry: CreditEntry in roll.every():
		if not drawn.has(entry.subject):
			_fail('"%s" is credited in %s and is nowhere on the screen' % [entry.subject, ROLL])
		if not entry.licence.is_empty() and not drawn.has(entry.licence):
			_fail('"%s" is on screen without its licence, "%s"' % [entry.subject, entry.licence])
		# A source is an address or a provenance, and both are the half of the row that says where
		# to go next. The studio's is the only one a player is meant to type, which is why it is
		# checked rather than assumed to have come along with the name.
		if not entry.source.is_empty() and not drawn.has(entry.source):
			_fail('"%s" is on screen without its source, "%s"' % [entry.subject, entry.source])
	screen.queue_free()
	await get_tree().process_frame


func _text_of(node: Node) -> PackedStringArray:
	var found := PackedStringArray()
	var label := node as Label
	if label != null and not label.text.is_empty():
		found.append(label.text)
	for child: Node in node.get_children():
		found.append_array(_text_of(child))
	return found


## The route to it, and back. A screen nothing opens is a screen nobody sees, and back has to return
## exactly one level rather than to the desktop.
func _check_the_title_opens_and_closes_it() -> void:
	var title := (load(TITLE) as PackedScene).instantiate() as Control
	add_child(title)
	await get_tree().process_frame
	var entry := title.get_node_or_null(^"Content/Column/Footer/Credits") as MenuEntry
	if entry == null:
		_fail("the title screen has no credits entry beside its version")
		title.queue_free()
		return
	entry.pressed.emit()
	await get_tree().process_frame
	var opened := _first_credits_screen(title)
	if opened == null:
		_fail("pressing the title's credits entry opened nothing")
		title.queue_free()
		return
	opened.close()
	await get_tree().process_frame
	if _first_credits_screen(title) != null:
		_fail("closing the credits left them on screen")
	if get_tree().current_scene == null and not title.is_inside_tree():
		_fail("closing the credits took the title down with them")
	title.queue_free()
	await get_tree().process_frame


func _first_credits_screen(node: Node) -> CreditsScreen:
	for child: Node in node.get_children():
		var screen := child as CreditsScreen
		if screen != null and not screen.is_queued_for_deletion():
			return screen
	return null


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print("credits OK — the document is the list, and every row of it is on the screen")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
