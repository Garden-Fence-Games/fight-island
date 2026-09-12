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
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("save: cannot read %s (%d)" % [path, FileAccess.get_open_error()])
		return {}
	var text := file.get_as_text()
	file.close()
	# An instance rather than `JSON.parse_string`, which logs an engine error of its own. A half
	# written file is the player's to have, not a fault of the game, and one warning says it better
	# than a parser stack trace does.
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("save: %s is not readable JSON (%s)" % [path, json.get_error_message()])
		return {}
	if not json.data is Dictionary:
		push_warning("save: %s is not a JSON object" % path)
		return {}
	return json.data as Dictionary


static func write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("save: cannot write %s (%d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t", true))
	file.close()
	return true


static func erase(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if error != OK:
		push_warning("save: cannot delete %s (%d)" % [path, error])


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
