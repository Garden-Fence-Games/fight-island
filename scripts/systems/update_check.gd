class_name UpdateCheck
extends Node
## Asks itch.io whether a newer build has been published, and says so once. Nothing else.
##
## **It informs, it never downloads.** A binary that replaces itself fights Gatekeeper, code signing
## and antivirus, and the macOS bundle is sealed — modifying it breaks the seal and brings back the
## "is damaged" refusal that a whole release went into fixing. A player who wants the new version
## opens the page and gets it the way they got this one.
##
## **It is never blocking and never loud.** Offline, itch down, a slow DNS, a reply that is not what
## this expects: the game says nothing at all and carries on. There is no error path a player can
## meet, because there is nothing here worth interrupting anybody for.
##
## This is the only network request the game makes, which is why it can be turned off.

## Emitted once, and only when the published version is genuinely ahead of this build.
signal newer_version_found(version: String)

const DATA: String = "res://data/update_check.tres"
const SETTING: StringName = &"gameplay_update_check"

@export var data: UpdateCheckData = null

var _request: HTTPRequest = null


func _ready() -> void:
	if data == null:
		data = load(DATA) as UpdateCheckData


## True when the check may run at all. Headless is excluded because the checks in `tools/` drive the
## title screen, and a suite that reaches the network is a suite that fails when a café's wifi does.
func is_allowed() -> bool:
	if data == null or DisplayServer.get_name() == "headless":
		return false
	return bool(Settings.get_value(SETTING))


## Starts the ask. Returns immediately; the answer arrives on the signal, or never.
func ask() -> void:
	if not is_allowed() or _request != null:
		return
	_request = HTTPRequest.new()
	_request.timeout = data.timeout_seconds
	add_child(_request)
	_request.request_completed.connect(_on_request_completed)
	var url := (
		"%s?target=%s&channel_name=%s"
		% [data.endpoint, data.target.uri_encode(), channel().uri_encode()]
	)
	# A failure to even start is the same as no answer, and is worth exactly as much noise.
	if _request.request(url) != OK:
		_forget_the_request()


## The channel this platform's build was pushed to.
func channel() -> String:
	if data == null:
		return ""
	var named: Variant = data.channels.get(OS.get_name())
	return (
		str(named)
		if named is String and not (named as String).is_empty()
		else data.fallback_channel
	)


## What this build calls itself, from the one place that is allowed to know.
static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


## Whether `published` is a later version than `running`.
##
## Compared field by field as integers rather than as text, because "1.10.0" is ahead of "1.9.0" and
## a string comparison says the opposite. Anything that does not parse is **not** newer: a reply
## nobody can read must not put a notice in front of a player.
static func is_newer(published: String, running: String) -> bool:
	var left := _fields(published)
	var right := _fields(running)
	if left.is_empty() or right.is_empty():
		return false
	for index: int in maxi(left.size(), right.size()):
		var a: int = left[index] if index < left.size() else 0
		var b: int = right[index] if index < right.size() else 0
		if a != b:
			return a > b
	return false


## The version in a reply, or an empty string when there is not one to be had. Public so a check can
## feed it the shapes a live endpoint cannot be asked to produce on demand.
static func version_in(body: PackedByteArray) -> String:
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return ""
	if not json.data is Dictionary:
		return ""
	var latest: Variant = (json.data as Dictionary).get("latest")
	return latest as String if latest is String else ""


func _on_request_completed(
	result: int, code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	_forget_the_request()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var published := version_in(body)
	if published.is_empty() or not is_newer(published, current_version()):
		return
	newer_version_found.emit(published)


func _forget_the_request() -> void:
	if _request != null:
		_request.queue_free()
		_request = null


static func _fields(version: String) -> Array[int]:
	var fields: Array[int] = []
	for part: String in version.strip_edges().split(".", false):
		if not part.is_valid_int():
			return []
		fields.append(part.to_int())
	return fields
