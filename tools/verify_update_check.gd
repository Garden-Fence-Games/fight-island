extends Node
## Headless proof of the update notice: which replies put a line in front of a player, and — far
## more important — which ones must not.
##
## **No network.** The decision is fed the shapes a live endpoint cannot be asked to produce on
## demand, because a check that reached itch.io would fail whenever a café's wifi did, and would
## pass for reasons nobody could reproduce.
## Run: godot --headless --path . res://tools/verify_update_check.tscn

const DATA: String = "res://data/update_check.tres"

var _failures: PackedStringArray = []


func _ready() -> void:
	_check_the_order_is_numeric()
	_check_nothing_readable_is_never_newer()
	_check_a_reply_yields_its_version()
	_check_the_shipped_data_points_somewhere()
	_check_headless_never_asks()
	_report()


## The whole decision, and the one that is easy to get wrong: 1.10.0 is ahead of 1.9.0, which a
## string comparison denies.
func _check_the_order_is_numeric() -> void:
	var ahead := [["1.1.0", "1.0.0"], ["1.10.0", "1.9.0"], ["2.0.0", "1.99.99"], ["1.0.1", "1.0.0"]]
	for pair: Array in ahead:
		if not UpdateCheck.is_newer(pair[0], pair[1]):
			_fail("%s should read as newer than %s" % [pair[0], pair[1]])
	var behind := [["1.0.0", "1.0.0"], ["0.9.0", "1.0.0"], ["1.9.0", "1.10.0"], ["1.0.0", "1.0.1"]]
	for pair: Array in behind:
		if UpdateCheck.is_newer(pair[0], pair[1]):
			_fail("%s should not read as newer than %s" % [pair[0], pair[1]])
	# Fields the other side does not have count as zero, so a longer version is not newer for it.
	if UpdateCheck.is_newer("1.0.0.0", "1.0.0"):
		_fail("a version with a trailing zero field read as newer than the same version")


## A reply nobody can read must not put a notice in front of a player. Every one of these is a real
## shape: a truncated body, a captive portal answering HTML, a field of the wrong type.
func _check_nothing_readable_is_never_newer() -> void:
	for junk: String in ["", "   ", "latest", "9.9.9-beta", "v1.1.0", "1.1.x", "1..0", "-1.0.0"]:
		if UpdateCheck.is_newer(junk, "1.0.0"):
			_fail('"%s" was treated as a version ahead of 1.0.0' % junk)
	for body: String in ["", "not json", "[]", "{}", '{"latest": 3}', '{"latest": null}']:
		if not UpdateCheck.version_in(body.to_utf8_buffer()).is_empty():
			_fail("a reply of %s yielded a version" % body)


func _check_a_reply_yields_its_version() -> void:
	var published := UpdateCheck.version_in('{"latest":"1.2.3"}'.to_utf8_buffer())
	if published != "1.2.3":
		_fail('the live reply shape yielded "%s" rather than 1.2.3' % published)
	var running := UpdateCheck.current_version()
	if running.is_empty():
		_fail("the build does not know its own version, so nothing can be compared to it")
	if UpdateCheck.is_newer(running, running):
		_fail("a build read as newer than itself, so every launch would show the notice")


func _check_the_shipped_data_points_somewhere() -> void:
	var data := load(DATA) as UpdateCheckData
	if data == null:
		_fail("the shipped update_check.tres does not load as UpdateCheckData")
		return
	if not data.endpoint.begins_with("https://"):
		_fail("the endpoint is not https, so the answer could be anybody's")
	if not data.page.begins_with("https://"):
		_fail("the page is not https")
	if data.target.is_empty() or not data.target.contains("/"):
		_fail("the target is not a user/game pair")
	if data.timeout_seconds <= 0.0:
		_fail("the timeout is not a wait, so the request would never give up")
	var check := UpdateCheck.new()
	check.data = data
	add_child(check)
	if check.channel().is_empty():
		_fail("no channel resolves for this platform, not even the fallback")
	check.queue_free()


## The suite drives the title screen, and the title screen asks. It must not reach the network here
## — under any setting — or this whole suite starts failing when a café's wifi does.
func _check_headless_never_asks() -> void:
	Settings.set_value(UpdateCheck.SETTING, true)
	var check := UpdateCheck.new()
	add_child(check)
	if check.is_allowed():
		_fail("the update check would run headless, which puts CI on the network")
	check.queue_free()


func _fail(message: String) -> void:
	_failures.append("  " + message)


func _report() -> void:
	if _failures.is_empty():
		print("update check OK — only a readable, genuinely newer version speaks up")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
