extends Node
## Proof that the recorded voices are there, are quiet, and come from a body that moves.
##
## These are the only sounds in the game that are **not** synthesised, which makes them the only
## ones that can go missing: a synthesised sound is code and fails loudly, a file is a file and a
## project that forgets to ship it is a project that goes quiet in exactly one place.
##
## The mix matters as much as the presence. A farmer shouting is flavour; a farmer *committing* is
## the one sound the whole game is built around being able to hear, so a voice that drew level with
## a wind-up would be taking away the thing it decorates.
## Run: godot --headless --path . res://tools/verify_voices.tscn

const ENEMY: String = "res://scenes/actors/enemy.tscn"
const BIRD: String = "res://scenes/world/bird.tscn"
## The families there have to be, and the least each may hold. Written out: a directory scan that
## found nothing would otherwise report a tidy pass over an empty folder.
const FAMILIES: Dictionary = {&"farmer": 6, &"gull": 2}
## The longest a line may run. A farmer who shouts for six seconds is still shouting when he has
## been dead for four.
const LONGEST: float = 5.0
## Recorded voice is mono on purpose — a positional source is placed by the engine, and a stereo
## file hands it a pan that fights the position.
const CHANNELS: int = 1
## Where a voice is judged against a wind-up. A farmer shouts on his way in, so the middle figure is
## the range he is usually at and the other two are either side of it.
const RANGES: Array[float] = [3.0, 8.0, 15.0]
## How far under a wind-up a voice has to stay, in decibels. Six is about where one sound is heard
## as being behind another rather than beside it.
const UNDER_A_WIND_UP: float = 6.0
## What the engine will not amplify a close source past, which is `max_db`'s default.
const CLOSE_CEILING: float = 3.0

var _failures: PackedStringArray = []


func _ready() -> void:
	_run()


func _run() -> void:
	_check_every_family_is_there()
	_check_a_line_is_short_and_mono()
	_check_a_voice_stays_under_a_wind_up()
	await _check_a_body_carries_its_own_voice(ENEMY, &"farmer")
	await _check_a_body_carries_its_own_voice(BIRD, &"gull")
	_report()


func _check_every_family_is_there() -> void:
	for kind: StringName in FAMILIES:
		var clips := AudioManager.voices_of(kind)
		var least: int = FAMILIES[kind]
		if clips.size() < least:
			_fail(
				(
					(
						"the %s family has %d clips and needs at least %d — a family is files, and a "
						+ "project that forgets one goes quiet in exactly one place"
					)
					% [kind, clips.size(), least]
				)
			)


## Mono, and short enough to be over before the moment it belongs to is.
func _check_a_line_is_short_and_mono() -> void:
	for kind: StringName in FAMILIES:
		for clip: AudioStream in AudioManager.voices_of(kind):
			var wav := clip as AudioStreamWAV
			if wav == null:
				continue
			if wav.stereo:
				_fail("a %s line is stereo, which fights the position the engine puts it at" % kind)
			if wav.get_length() > LONGEST:
				_fail(
					(
						"a %s line runs %.1f s, and the longest a line may run is %.1f"
						% [kind, wav.get_length(), LONGEST]
					)
				)


## The line the whole mix rests on. Checked against the wind-up rather than against a number,
## because what must never happen is a voice drawing level with the one sound the player has to
## hear — and the wind-up's own figure is where that is decided.
##
## **At a distance, and at several of them.** The previous version compared the gain a voice is
## played at against the peak a wind-up is baked to: two numbers in different units, neither of them
## a loudness. It passed contentedly while the farmers sat thirteen decibels under where the table
## said they were, because there was nothing in it that could have noticed.
##
## The two do not carry alike either — a wind-up has the wider unit size precisely so it reaches
## further — so the comparison is made where the player stands rather than at the source.
func _check_a_voice_stays_under_a_wind_up() -> void:
	var warning := linear_to_db(AudioManager.level_of(&"telegraph"))
	var shout := linear_to_db(AudioManager.gain_of_voice(&"farmer")) + MixTable.FARMER_AS_RECORDED
	for metres: float in RANGES:
		var heard := shout + _carries(AudioManager.VOICE_UNIT, metres)
		var over := warning + _carries(AudioManager.POSITIONAL_UNIT, metres)
		if heard > over - UNDER_A_WIND_UP:
			_fail(
				(
					"at %.0f m a voice is %.1f dB against a wind-up at %.1f — flavour is drowning it"
					% [metres, heard, over]
				)
			)


## What the engine does to a positional sound between the body and the ear: inverse distance, and a
## ceiling close in that `max_db` puts there whatever the arithmetic says.
func _carries(unit: float, metres: float) -> float:
	return minf(linear_to_db(unit / maxf(metres, 0.01)), CLOSE_CEILING)


## Its own player, moving with the body. A pooled voice is put at a point and played, so it is
## stationary for its whole length — and a stationary sound cannot say *closing*, which is the only
## thing this was added for.
func _check_a_body_carries_its_own_voice(path: String, kind: StringName) -> void:
	var body := (load(path) as PackedScene).instantiate()
	add_child(body)
	await get_tree().process_frame
	var voice := body.get_node_or_null(^"Voice") as VoiceComponent
	if voice == null:
		_fail("%s carries no voice of its own" % path.get_file())
		body.queue_free()
		return
	if voice.kind != kind:
		_fail('%s draws from "%s" rather than "%s"' % [path.get_file(), voice.kind, kind])
	if voice.doppler_tracking == AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED:
		_fail(
			(
				(
					"%s has no Doppler, so a body closing on the player sounds exactly like one "
					+ "standing still"
				)
				% path.get_file()
			)
		)
	if voice.max_distance > AudioManager.REACH + 0.01:
		_fail("%s carries further than anything else on the island" % path.get_file())
	body.queue_free()
	await get_tree().process_frame


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				"voices OK — both families are shipped, every line is mono and short, they sit "
				+ "under a wind-up, and they move with the body that says them"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr("voices FAILED — %s" % failure)
	get_tree().quit(1)
