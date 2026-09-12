class_name CreditsSource
extends RefCounted
## Reads `docs/credits.md` into a `CreditsRoll`.
##
## Shared by the tool that bakes the resource and by the check that proves the two still agree —
## one parser, so a check that used its own could never disagree with the builder for a reason that
## is about the parser rather than about the document.
##
## The document is the source of truth because it is the thing a contributor actually edits when
## they add an asset, and the rule in it — a file with no row does not ship — is worth nothing if
## the row the player sees comes from somewhere else.

const DOCUMENT: String = "res://docs/credits.md"
## The headings the two tables live under. A table under any other heading is prose furniture and is
## left alone.
const ASSET_HEADING: String = "## Assets"
const TOOL_HEADING: String = "## Engine and tools"
## Cells in the assets table. The date a row was added is bookkeeping for the repository and means
## nothing to a player, so it is read and dropped rather than shown.
const ASSET_CELLS: int = 5
const TOOL_CELLS: int = 2


static func parse(path: String = DOCUMENT) -> CreditsRoll:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("credits: cannot read %s" % path)
		return null
	var roll := CreditsRoll.new()
	var heading := ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("#"):
			heading = line
			continue
		if not line.begins_with("|"):
			continue
		var cells := _cells(line)
		if _is_furniture(cells):
			continue
		if heading == ASSET_HEADING and cells.size() == ASSET_CELLS:
			roll.assets.append(_asset_row(cells))
		elif heading == TOOL_HEADING and cells.size() == TOOL_CELLS:
			roll.tools.append(_tool_row(cells))
	return roll


## The cells of one table line, trimmed. A leading and a trailing pipe leave empty strings at both
## ends of the split, and those are the fence rather than a column.
static func _cells(line: String) -> PackedStringArray:
	var parts := line.split("|")
	var cells := PackedStringArray()
	for index: int in parts.size():
		if index == 0 or index == parts.size() - 1:
			continue
		cells.append(parts[index].strip_edges())
	return cells


## A header row or the dashes under it. Both are table drawing, not content.
static func _is_furniture(cells: PackedStringArray) -> bool:
	if cells.is_empty():
		return true
	var first := cells[0]
	if first.begins_with("---") or first.begins_with(":--"):
		return true
	return first == "File" or first == ""


static func _asset_row(cells: PackedStringArray) -> CreditEntry:
	var entry := CreditEntry.new()
	entry.subject = _plain(cells[0])
	entry.source = _plain(cells[1])
	entry.source_url = _link(cells[1])
	entry.author = _plain(cells[2])
	entry.licence = _plain(cells[3])
	return entry


static func _tool_row(cells: PackedStringArray) -> CreditEntry:
	var entry := CreditEntry.new()
	entry.subject = _plain(cells[0])
	entry.source_url = _link(cells[0])
	entry.licence = _plain(cells[1])
	return entry


## The cell as a reader sees it: link text without its target, and none of the emphasis markers a
## label would otherwise print literally.
static func _plain(cell: String) -> String:
	var text := _links().sub(cell, "$1", true)
	text = text.replace("**", "").replace("`", "")
	return text.strip_edges()


## The first link target in the cell, or nothing. One is all a row has ever had, and a row that
## grows a second wants a column rather than a guess about which one matters.
static func _link(cell: String) -> String:
	var found := _links().search(cell)
	return found.get_string(2) if found != null else ""


static func _links() -> RegEx:
	var expression := RegEx.new()
	expression.compile("\\[([^\\]]+)\\]\\(([^)]+)\\)")
	return expression
