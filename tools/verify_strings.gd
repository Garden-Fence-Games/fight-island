extends Node
## Proof that every string shaped like a translation key is one.
##
## `tr()` answers an unknown key with the key itself, which is the worst possible failure: nothing
## is logged, nothing is null, and the player reads `SUMMARY_PERFECT_PARRIES` off the screen. It is
## also the easiest one to cause, because keys live in four places — a `tr()` call, a `label_key` on
## a scene, a `display_name` in a `.tres`, and the CSV — and only one of those four is the CSV.
##
## The rule is symmetrical, and both halves are failures:
##
## - **A key that does not resolve** is a string the player will read raw.
## - **A row nobody asks for** is a translation somebody will one day pay to have translated into
##   eleven languages for a screen that no longer exists.
##
## What counts as "shaped like a key" is deliberately mechanical — upper case, digits and
## underscores, at least two words. Prose never looks like that, and anything that does and is not a
## key is a string pretending to be one.
## Run: godot --headless --path . res://tools/verify_strings.tscn

const CSV: String = "res://assets/locale/ui.csv"
## Where a key can be written. `.gd` is searched only inside `tr("...")`, which is unambiguous;
## scenes and resources are searched for the shape, because `label_key`, `prompt_key` and
## `display_name` are three names for the same idea and a fourth will arrive.
const SCANNED: Array[String] = ["res://scenes", "res://data", "res://scripts"]
## Strings that look like keys and are not. `Devices` spells keyboard caps in upper case — `ENTER`
## is what a badge prints, not something to translate, and a game that translated it would print
## the French for "enter" on a key marked ENTER.
const NOT_KEYS: Array[String] = [
	"BACK",
	"BACKSPACE",
	"BKSP",
	"DELETE",
	"ENTER",
	"ESCAPE",
	"GUIDE",
	"PAGEDOWN",
	"PAGEUP",
	"PGDN",
	"PGUP",
	"START",
]

var _failures: PackedStringArray = []
var _keys: Dictionary = {}
var _asked: Dictionary = {}
var _prefixes: PackedStringArray = []


func _ready() -> void:
	_run()


func _run() -> void:
	_read_the_csv()
	if _keys.is_empty():
		_fail("%s holds no keys at all" % CSV)
		_report()
		return
	for root: String in SCANNED:
		_walk(root)
	_check_every_key_asked_for_resolves()
	_check_every_row_is_asked_for()
	_report()


func _read_the_csv() -> void:
	var file := FileAccess.open(CSV, FileAccess.READ)
	if file == null:
		_fail("cannot read %s" % CSV)
		return
	var first := true
	while not file.eof_reached():
		var row := file.get_csv_line()
		if first:
			first = false
			continue
		if row.size() < 2 or row[0].strip_edges().is_empty():
			continue
		_keys[row[0].strip_edges()] = row[1]


func _walk(directory: String) -> void:
	for name: String in DirAccess.get_directories_at(directory):
		_walk("%s/%s" % [directory, name])
	for name: String in DirAccess.get_files_at(directory):
		var path := "%s/%s" % [directory, name.trim_suffix(".remap")]
		if path.ends_with(".gd") or path.ends_with(".tscn") or path.ends_with(".tres"):
			_collect(path, _shapes())


func _collect(path: String, expression: RegEx) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	for found: RegExMatch in _formats().search_all(text):
		_prefixes.append(found.get_string(1))
	for found: RegExMatch in expression.search_all(text):
		var key := found.get_string(1)
		if NOT_KEYS.has(key):
			continue
		if not _asked.has(key):
			_asked[key] = path
	file.close()


## Any key-shaped string, wherever it is written. **Quoted**, which is what keeps a constant or an
## enum member out of it — `const STICK_WAKE` is a name and `"OPT_SPRINT"` is a string somebody
## reads. Two words at least, so a one-word value is never mistaken for a line of prose.
##
## Searching only `tr("...")` was the first attempt and it was far too narrow: half the keys in this
## project are never passed to `tr` at the call site at all. They sit in `OptionsScreen.PAGES`, in a
## `label_key` on a scene, in a `display_name` on a `.tres` — `tr` sees them much later, if ever.
## A key built by formatting, as its fixed prefix: `"OPT_BIND_%s"` gives `OPT_BIND_`.
func _formats() -> RegEx:
	var expression := RegEx.new()
	expression.compile('"([A-Z][A-Z0-9_]*_)%s"')
	return expression


func _shapes() -> RegEx:
	var expression := RegEx.new()
	expression.compile('"([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)"')
	return expression


## The half the player sees. A key with no row resolves to itself, so the screen reads the key.
func _check_every_key_asked_for_resolves() -> void:
	for key: String in _asked:
		if _keys.has(key):
			continue
		_fail(
			(
				'%s asks for "%s" and %s has no row for it — the screen will read the key'
				% [String(_asked[key]).get_file(), key, CSV.get_file()]
			)
		)


## And the half nobody sees. A row nothing asks for is a string somebody will one day pay to have
## translated for a screen that no longer exists.
##
## A key assembled at runtime — `"OPT_BIND_%s" % action` — has no literal anywhere, so the prefix
## counts for every row under it. That is a real hole in a scanner and the honest way to plug it:
## the alternative is to drop this half of the check, and it is the half that found `UI_BACK`, a row
## that existed for a hint bar which had written its own English out by hand instead.
func _check_every_row_is_asked_for() -> void:
	for key: String in _keys:
		if _asked.has(key) or _built_at_runtime(key):
			continue
		_fail('%s carries "%s" and nothing in the project asks for it' % [CSV.get_file(), key])


func _built_at_runtime(key: String) -> bool:
	for prefix: String in _prefixes:
		if key.begins_with(prefix):
			return true
	return false


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				"strings OK — %d keys, every one of them asked for and every one of them answered"
				% _keys.size()
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr("strings FAILED — %s" % failure)
	get_tree().quit(1)
