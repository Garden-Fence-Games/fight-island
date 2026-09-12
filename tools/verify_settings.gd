extends Node
## Headless proof that **every setting reaches something.**
##
## This is the third time the same bug has shipped. `access_colourblind_telegraphs` existed to
## thicken a ring and outlived the ring. Aim assist was a row, a default and a saved value that
## nothing ever read, for as long as the gun has existed. Mouse sensitivity, stick sensitivity and
## invert Y were written for a camera that can be turned and this one cannot be. Each one persisted
## across launches and moved nothing.
##
## It is the worst shape a settings bug has, because the failure is silent and lands on exactly the
## player who needed the setting: they find it, set it, and believe they are covered. Nothing in a
## diff shows it, no screen looks wrong, and the row keeps remembering its value.
##
## So the rule is machine-checked: a key in `Settings.DEFAULTS` has to be **applied by `Settings`
## itself** — the audio buses, the window, the vsync, the frame cap — **or read by some other
## script.** A key whose only other mention is the options row that draws it is a dead setting, and
## that is precisely what all three of them looked like.
##
## It reads the project's own source to do it, which is unusual but not new here: `verify_waves`
## reads `docs/game-design.md` and `verify_credits` reads `docs/credits.md`. A check that can only
## see runtime state cannot see a consumer that does not exist.
## Run: godot --headless --path . res://tools/verify_settings.tscn

## Where the settings are declared, and the one file whose mention of a key proves nothing: drawing
## a row for a setting is not reading it, and a row for a dead setting is the bug itself.
const STORE: String = "res://scripts/systems/settings.gd"
const SCREEN: String = "res://scripts/ui/options_screen.gd"
## Everything that could hold a consumer.
const SOURCES: PackedStringArray = ["res://scripts/"]

var _failures: PackedStringArray = []


func _ready() -> void:
	_run()


func _run() -> void:
	var files := _every_script()
	if files.size() < 20:
		_fail(
			"only found %d scripts to search — the walk is broken, not the settings" % files.size()
		)
		_report()
		return
	# Read once and cached: the outer loop is every setting and the inner every script, and reading
	# a hundred files twenty times over is a check that takes long enough for somebody to switch off.
	var bodies: Dictionary = {}
	for path: String in files:
		bodies[path] = _without_comments(path)

	_check_the_store_is_the_one_that_declares_them(bodies)
	for key: StringName in Settings.DEFAULTS:
		_check_something_reaches(key, bodies)
	_report()


## Every setting has to be **declared** in `Settings`, or the check below is searching for keys that
## some other file invented and nothing keeps a list of.
func _check_the_store_is_the_one_that_declares_them(bodies: Dictionary) -> void:
	var store := str(bodies.get(STORE, ""))
	if store.is_empty():
		_fail("%s is missing or unreadable, so nothing here can be trusted" % STORE)
		return
	for key: StringName in Settings.DEFAULTS:
		if not store.contains(String(key)):
			_fail("%s is a setting that %s does not mention" % [key, STORE])


## The rule, for one key. Applied by the store outside its own declaration, or read by any script
## that is not the screen drawing its row.
func _check_something_reaches(key: StringName, bodies: Dictionary) -> void:
	var name := String(key)
	var readers: PackedStringArray = []
	for path: Variant in bodies:
		var text := str(bodies[path])
		if not text.contains(name):
			continue
		if path == SCREEN:
			# A row is not a consumer. This is the whole point.
			continue
		if path == STORE:
			# The store mentions every key once to declare it. Anything beyond that — a match arm
			# in `_apply`, a bus table, a helper like `sprint_is_toggle` — is it doing the work.
			if text.count(name) > 1:
				readers.append("%s (applies it)" % path)
			continue
		readers.append(str(path))
	if readers.is_empty():
		_fail(
			(
				(
					"%s is stored, defaulted and drawn, and **nothing reads it** — a setting that "
					+ "persists and moves nothing is worse than one that is missing"
				)
				% name
			)
		)


## Comment lines stripped before anything is searched. A key named in a docstring is a mention and
## not a consumer, and this check exists precisely to tell those two apart — a note explaining why a
## setting matters would otherwise keep a dead setting looking alive.
func _without_comments(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var kept := ""
	while not file.eof_reached():
		var line := file.get_line()
		if not line.strip_edges().begins_with("#"):
			kept += line + "\n"
	file.close()
	return kept


func _every_script() -> PackedStringArray:
	var found := PackedStringArray()
	for root: String in SOURCES:
		_walk(root, found)
	return found


func _walk(where: String, into: PackedStringArray) -> void:
	var directory := DirAccess.open(where)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		var path := where.path_join(entry)
		if directory.current_is_dir():
			_walk(path, into)
		elif entry.ends_with(".gd"):
			into.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				(
					"settings OK — every one of the %d settings is either applied by Settings itself "
					+ "or read by something that is not the row drawing it"
				)
				% Settings.DEFAULTS.size()
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr("settings FAILED — %s" % failure)
	get_tree().quit(1)
