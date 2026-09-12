extends Node
## Headless proof that **every signal on the bus has both ends**: something raises it, and something
## is listening when it does.
##
## `EventBus` is the one place in this project where a thing can exist, look completely correct and
## do nothing at all. A signal is declared, documented, emitted from the right moment — and if
## nobody connected to it, the fight goes on exactly as if the line were not there. Nothing in a
## diff shows it, no screen looks wrong, and the emitter keeps firing into silence.
##
## It is the same shape as a settings row that reaches nothing, which has now shipped three times
## (see `verify_settings`), and it had shipped here once: `perfect_timing` was raised on every
## perfect hit and heard by nobody, because everything that cares already reads the `perfect` flag
## on `attack_landed`.
##
## **A headless check counts as a listener.** `enemy_spawned` has no gameplay consumer at all — it
## exists so `verify_waves` and `verify_day_night` can watch bodies arrive instead of polling a
## group every frame, which is a real use and a good one. A rule that only looked at `scripts/`
## would have called it dead and deleted the thing two checks are built on. That nearly happened.
## Run: godot --headless --path . res://tools/verify_bus.tscn

const BUS: String = "res://scripts/autoload/event_bus.gd"
## Everywhere a signal can legitimately be raised or answered.
const SOURCES: PackedStringArray = ["res://scripts/", "res://tools/", "res://tests/"]

var _failures: PackedStringArray = []


func _ready() -> void:
	_run()


func _run() -> void:
	var signals := _declared_signals()
	if signals.size() < 20:
		_fail("only found %d signals on the bus — the parse is broken" % signals.size())
		_report()
		return
	var bodies := _every_script()
	if bodies.size() < 40:
		_fail("only found %d scripts to search — the walk is broken" % bodies.size())
		_report()
		return

	for name: String in signals:
		# Asked of the object as well as of the file: a name this check misreads would otherwise be
		# a name nothing emits and nothing hears, which is a failure about the parse and not the bus.
		if not EventBus.has_signal(name):
			_fail("%s is declared in %s and the bus does not carry it" % [name, BUS])
			continue
		var raised := _files_containing(bodies, "%s.emit(" % name)
		var heard := _files_containing(bodies, "%s.connect(" % name)
		if raised.is_empty():
			# One line, not two. A signal with neither end is one fact, and reporting the missing
			# listener as well would name an emitter that does not exist.
			_fail("nothing ever raises %s" % name)
			continue
		if heard.is_empty():
			_fail(
				(
					(
						"nothing ever listens for %s — it is raised by %s and heard by nobody, which "
						+ "is a line that looks like a feature and is not one"
					)
					% [name, ", ".join(raised)]
				)
			)
	_report()


## The signals the bus declares, read from its own source. `get_signal_list()` would answer with
## every signal a `Node` has ever had as well, and this is a question about the twenty-odd lines
## somebody wrote.
func _declared_signals() -> PackedStringArray:
	var found := PackedStringArray()
	var file := FileAccess.open(BUS, FileAccess.READ)
	if file == null:
		_fail("%s is missing or unreadable" % BUS)
		return found
	while not file.eof_reached():
		var line := file.get_line()
		if not line.begins_with("signal "):
			continue
		var rest := line.substr("signal ".length())
		var opens := rest.find("(")
		found.append((rest.substr(0, opens) if opens > 0 else rest).strip_edges())
	file.close()
	return found


func _files_containing(bodies: Dictionary, needle: String) -> PackedStringArray:
	var found := PackedStringArray()
	for path: Variant in bodies:
		if str(bodies[path]).contains(needle):
			found.append(str(path).get_file())
	return found


## Every script, with its comment lines dropped. A signal named in a docstring is a mention and not
## a consumer, and telling those apart is the whole job — `event_bus.gd` explains most of its own
## signals in prose directly above them.
func _every_script() -> Dictionary:
	var bodies: Dictionary = {}
	for root: String in SOURCES:
		for path: String in _walk(root):
			bodies[path] = _without_comments(path)
	return bodies


func _walk(where: String) -> PackedStringArray:
	var found := PackedStringArray()
	var directory := DirAccess.open(where)
	if directory == null:
		return found
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		var path := where.path_join(entry)
		if directory.current_is_dir():
			found.append_array(_walk(path))
		elif entry.ends_with(".gd"):
			found.append(path)
		entry = directory.get_next()
	directory.list_dir_end()
	return found


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


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				"bus OK — every one of the %d signals is raised by something and heard by something"
				% _declared_signals().size()
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr("bus FAILED — %s" % failure)
	get_tree().quit(1)
