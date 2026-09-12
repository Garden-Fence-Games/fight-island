class_name SaveManager
extends RefCounted
## Every read and write under `user://`, and nothing else. Static by design — see ADR 0004: file
## I/O needs no node in the tree, no `_ready` ordering and no singleton to mock.
##
## **JSON, never a `.tres`.** A resource file can carry a script path, and these files live in a
## directory the player can edit, so loading one would be arbitrary code execution.

const SETTINGS_PATH: String = "user://settings.json"


static func read_settings() -> Dictionary:
	return read_json(SETTINGS_PATH)


static func write_settings(values: Dictionary) -> void:
	write_json(SETTINGS_PATH, values)


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
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("save: %s is not a JSON object" % path)
		return {}
	return parsed as Dictionary


static func write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("save: cannot write %s (%d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t", true))
	file.close()
	return true
