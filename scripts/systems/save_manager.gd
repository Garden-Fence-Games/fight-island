class_name SaveManager
extends RefCounted
## Every read and write under `user://`, and nothing else. Static by design — see ADR 0004: file
## I/O needs no node in the tree, no `_ready` ordering and no singleton to mock.
##
## **JSON, never a `.tres`.** A resource file can carry a script path, and these files live in a
## directory the player can edit, so loading one would be arbitrary code execution.
##
## Three files, because they have three lifetimes. Settings belong to the machine and outlive every
## run. Progress belongs to the player and outlives every run too, but only records what they have
## already been shown. The run belongs to one sitting and is deleted the moment it ends.

const SETTINGS_PATH: String = "user://settings.json"
const RUN_PATH: String = "user://run.json"
const PROGRESS_PATH: String = "user://progress.json"

## Bumped whenever a stored shape changes. An older file goes through `_migrate`; a **newer** one is
## discarded, because nothing in this build can know what a field it has never heard of means, and
## guessing would corrupt a save the player can still open with the build that wrote it.
const VERSION: int = 1
const VERSION_KEY: String = "version"

## What a half-written file is called. A write lands here first and is renamed over the real path
## only once it is closed, so an interruption costs the save being written and never the one already
## on disk.
const TEMP_SUFFIX: String = ".tmp"


static func read_settings() -> Dictionary:
	return read_versioned(SETTINGS_PATH)


static func write_settings(values: Dictionary) -> void:
	write_versioned(SETTINGS_PATH, values)


static func read_run() -> Dictionary:
	return read_versioned(RUN_PATH)


static func write_run(data: Dictionary) -> void:
	write_versioned(RUN_PATH, data)


## A run file exists and this build can read it. Asked by the title screen, which offers Continue
## on the answer — so a file from a newer build has to say no rather than throw.
static func has_run() -> bool:
	return not read_run().is_empty()


static func clear_run() -> void:
	erase(RUN_PATH)


static func read_progress() -> Dictionary:
	return read_versioned(PROGRESS_PATH)


static func write_progress(data: Dictionary) -> void:
	write_versioned(PROGRESS_PATH, data)


## Reads, then migrates. An empty dictionary means *use your defaults* and covers every failure the
## caller cannot do anything about: missing, unreadable, truncated, not an object, or from a build
## that does not exist yet.
static func read_versioned(path: String) -> Dictionary:
	return _migrate(path, read_json(path))


## Stamps the version on the way out, so the next build can tell what it is holding.
static func write_versioned(path: String, data: Dictionary) -> bool:
	var stamped := data.duplicate(true)
	stamped[VERSION_KEY] = VERSION
	return write_json(path, stamped)


## An empty dictionary for every failure — missing, unreadable, or not a JSON object. The caller
## has defaults and a warning is more use than a crash on a file the player owns.
static func read_json(path: String) -> Dictionary:
	# The real file first, then the sibling a rename never finished moving. A real file that parses
	# **wins** even though the temporary one is newer: the only way both exist is a failed rename,
	# and then the real file is the last save known to be whole. Losing the newest wave beats
	# promoting a write that was never confirmed.
	for candidate: String in [path, path + TEMP_SUFFIX]:
		if not FileAccess.file_exists(candidate):
			continue
		var file := FileAccess.open(candidate, FileAccess.READ)
		if file == null:
			push_warning("save: cannot read %s (%d)" % [candidate, FileAccess.get_open_error()])
			continue
		var text := file.get_as_text()
		file.close()
		# An instance rather than `JSON.parse_string`, which logs an engine error of its own. A half
		# written file is the player's to have, not a fault of the game, and one warning says it
		# better than a parser stack trace does.
		var json := JSON.new()
		if json.parse(text) != OK:
			push_warning(
				"save: %s is not readable JSON (%s)" % [candidate, json.get_error_message()]
			)
			continue
		if not json.data is Dictionary:
			push_warning("save: %s is not a JSON object" % candidate)
			continue
		if candidate != path:
			push_warning("save: %s recovered from an unfinished write" % path)
		return json.data as Dictionary
	return {}


## Written beside the target and moved into place, never over it. `FileAccess.WRITE` truncates the
## instant it opens, so writing in place means that between the open and the close the only copy on
## disk is empty or half a file — and a run is written on every wave and every purchase, which is
## forty-odd chances a run for a force quit to land inside that window.
static func write_json(path: String, data: Dictionary) -> bool:
	var temporary := path + TEMP_SUFFIX
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_warning("save: cannot write %s (%d)" % [temporary, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t", true))
	file.close()
	var error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)
	)
	if error != OK:
		push_warning("save: cannot move %s into place (%d)" % [path, error])
		return false
	return true


## Both files, because a leftover temporary is a run that comes back from the dead: `read_json`
## promotes a sibling when the real path is gone, and a deleted run is exactly that shape.
static func erase(path: String) -> void:
	_remove(path)
	_remove(path + TEMP_SUFFIX)


## Where an old file becomes a current one. Version 0 is everything written before the stamp
## existed: its settings are still readable key for key, so there is nothing to move and the stamp
## is the whole migration.
static func _migrate(path: String, data: Dictionary) -> Dictionary:
	if data.is_empty():
		return data
	var stored := int(data.get(VERSION_KEY, 0))
	if stored > VERSION:
		push_warning("save: %s was written by a newer build (v%d), ignoring it" % [path, stored])
		return {}
	return data


static func _remove(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if error != OK:
		push_warning("save: cannot delete %s (%d)" % [path, error])


## A number out of a value the player could have edited.
##
## JSON hands back a float, or a String, or — on a file somebody opened in a text editor — an
## object or a list. `int()` has **no constructor** for those two: it does not return zero, it
## faults, and the fault takes the whole restore with it. Every read of a stored file goes through
## here, so a wrong shape costs one field and not the run.
static func as_int(value: Variant, fallback: int) -> int:
	if value is float or value is int or value is bool:
		return int(value)
	if value is String or value is StringName:
		return String(value).to_int()
	return fallback


static func as_float(value: Variant, fallback: float) -> float:
	if value is float or value is int or value is bool:
		return float(value)
	if value is String or value is StringName:
		return String(value).to_float()
	return fallback


static func as_bool(value: Variant, fallback: bool) -> bool:
	if value is bool or value is float or value is int:
		return bool(value)
	return fallback


## A name out of a stored key. JSON has no StringName, and a String key would never answer a lookup
## that takes one — but a list or an object is not a name either, and `StringName()` faults on them.
static func as_name(value: Variant, fallback: StringName) -> StringName:
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	if value is float or value is int or value is bool:
		return StringName(str(value))
	return fallback


## Whether a stored value can be read as a number at all. For the fields a caller cannot do without:
## present but unreadable is the same as absent, and falling back would invent a run rather than
## refuse one.
static func is_number(value: Variant) -> bool:
	if value is float or value is int or value is bool:
		return true
	return (value is String or value is StringName) and String(value).is_valid_float()
