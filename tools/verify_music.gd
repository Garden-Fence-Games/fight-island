extends Node
## Proof that the bed lifts with the island, gets out of the way of a wind-up, and never carries
## anything the player needs.
##
## The music is the only pacing tool the game has between waves, and it is also the one sound a
## player is entirely free to switch off. Both of those are promises: it has to *do* something, and
## muting it has to cost nothing but atmosphere.
## Run: godot --headless --path . res://tools/verify_music.tscn

const MAIN: String = "res://scenes/main/main.tscn"
const FARMHAND: String = "res://data/enemies/farmhand.tres"
## The buses that are allowed to be switched off without losing information, and the one that is
## not. Written out rather than read off the layout, so a bus renamed in the editor fails here.
const ATMOSPHERE: Array[StringName] = [&"Music", &"Ambience"]
const INFORMATION: StringName = &"SFX"
## Long enough for the mix to follow a change — `MusicBed.FOLLOWS` is deliberately slow, so a check
## reading one frame later would be reading the old island.
const SETTLES: float = 4.0
## How far the bus has to come down to count as ducked, and how close to nought to count as back.
const DUCKED_PAST: float = -4.0
const BACK_WITHIN: float = 1.0
## How many bodies to stand up for the loud case. Past what any wave allows at once, so the pressure
## saturates and the top layer has to be at full — an island that cannot reach full pressure is a
## bed whose last layer never arrives.
const A_CROWD: int = 16
## What counts as off. Silence is -80 dB rather than nothing at all, which reads as 0.0001 in linear
## and is not zero — the first version of this check failed the breather for being 0.000.
const AUDIBLE: float = 0.001
const FLOATING_POINT: float = 0.0001
## How much louder a full island has to be than a nearly empty one before the lift is worth having.
const LIFTS_BY: float = 3.0

var _failures: PackedStringArray = []
var _main: Node = null
var _bed: MusicBed = null
var _arena: Node3D = null


func _ready() -> void:
	_run()


func _run() -> void:
	GameState.begin_run()
	_main = (load(MAIN) as PackedScene).instantiate()
	add_child(_main)
	_bed = _main.get_node_or_null(^"MusicBed") as MusicBed
	_arena = _main.get_node_or_null(^"Arena") as Node3D
	if _bed == null or _arena == null:
		_fail("the game has no music bed or no arena")
		_report()
		return
	var tutorial := _arena.get_node_or_null(^"TutorialDirector") as TutorialDirector
	if tutorial != null:
		tutorial.stand_down()
	var director := _arena.get_node_or_null(^"WaveDirector") as WaveDirector
	if director != null:
		director.halt()
	await get_tree().physics_frame

	_check_every_layer_is_the_same_length()
	_check_the_bed_only_ever_rises()
	await _check_the_breather_is_silent_and_a_crowd_is_not()
	await _check_a_wind_up_ducks_the_bed_and_it_comes_back()
	_check_nothing_the_player_needs_is_on_a_bus_they_may_mute()
	_report()


## Three loops of different lengths drift apart inside a minute, and what was one piece of music
## getting louder becomes three loops arguing. Nothing else keeps them together — they are separate
## players, started at separate moments, with no clock between them.
func _check_every_layer_is_the_same_length() -> void:
	var length := -1
	for id: StringName in AudioManager.LAYERS:
		var stream := AudioManager.sound(id) as AudioStreamWAV
		if stream == null:
			_fail("there is no %s layer" % id)
			continue
		if stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			_fail("%s does not loop, so the bed stops partway through a wave" % id)
		if length < 0:
			length = stream.data.size()
		elif stream.data.size() != length:
			_fail(
				(
					(
						"%s is %d bytes and another layer is %d — layers of different lengths drift "
						+ "apart and stop being one piece of music"
					)
					% [id, stream.data.size(), length]
				)
			)
			return


## The mix walked end to end. Two things have to be true of it and neither is about the ranges
## overlapping — the layers **stack**, they do not take turns, so a gap between one layer's top and
## the next one's bottom costs nothing. The first version of this check asserted the overlap, and
## the island was right and the check was wrong.
##
## What is actually promised: a fight never starts in silence, and filling the island never makes
## the bed quieter.
func _check_the_bed_only_ever_rises() -> void:
	var quietest := _bed.loudness_at(0.0)
	if quietest > AUDIBLE:
		_fail("the bed reads %.3f on an empty island, which is not a breather" % quietest)
	var last := 0.0
	var steps := 40
	for index: int in range(1, steps + 1):
		var pressure := float(index) / float(steps)
		var now := _bed.loudness_at(pressure)
		if now + FLOATING_POINT < last:
			_fail(
				(
					(
						"the bed falls from %.3f to %.3f as the island fills past %.2f — more trouble "
						+ "has to mean more music"
					)
					% [last, now, pressure]
				)
			)
			return
		if now <= AUDIBLE:
			_fail(
				(
					"the bed is silent at %.2f pressure — a fight is happening and nothing is on"
					% pressure
				)
			)
			return
		last = now
	if last <= _bed.loudness_at(0.05) * LIFTS_BY:
		_fail(
			(
				"a full island reads %.3f against %.3f nearly empty — the bed barely moves"
				% [last, _bed.loudness_at(0.05)]
			)
		)


## The whole claim, measured on a real island: nothing on it between waves, and a great deal on it
## when it is full.
func _check_the_breather_is_silent_and_a_crowd_is_not() -> void:
	GameState.wave_in_progress = false
	await _advance(SETTLES)
	var breather := _bed.loudness()
	if breather > AUDIBLE:
		_fail("the bed is at %.3f between waves, and a breather is supposed to be one" % breather)
	GameState.wave_in_progress = true
	var standing := await _stand_up_a_crowd()
	await _advance(SETTLES)
	var crowded := _bed.loudness()
	if crowded <= breather + AUDIBLE:
		_fail(
			(
				"a full island reads %.3f against %.3f empty — the bed does not lift"
				% [crowded, breather]
			)
		)
	for body: Enemy in standing:
		body.retire()
	await get_tree().physics_frame
	GameState.wave_in_progress = false


## A telegraph outranks the bed the way it outranks a camera knock. It is the one thing the player
## has to hear, and half a bed over it is still a bed over it.
func _check_a_wind_up_ducks_the_bed_and_it_comes_back() -> void:
	var before := _bed.duck_db()
	EventBus.telegraph_began.emit(Vector3.ZERO, load(FARMHAND) as EnemyData)
	await _advance(0.5)
	var ducked := _bed.duck_db()
	if ducked > DUCKED_PAST:
		_fail(
			(
				(
					"the bus sat at %.1f dB while a farmer was committing, against %.1f before — the "
					+ "music did not get out of the way"
				)
				% [ducked, before]
			)
		)
	await _advance(SETTLES)
	if _bed.duck_db() < -BACK_WITHIN:
		_fail(
			(
				(
					"the bus is still at %.1f dB long after the wind-up — a duck that does not come "
					+ "back is a mix that quietly fades out over a wave"
				)
				% _bed.duck_db()
			)
		)


## The line the whole thing rests on. Music and Ambience exist to be switched off; if anything that
## tells the player something plays on either of them, a slider at the bottom is a player who has
## been quietly made worse at the game.
func _check_nothing_the_player_needs_is_on_a_bus_they_may_mute() -> void:
	for bus: StringName in ATMOSPHERE:
		if AudioServer.get_bus_index(String(bus)) < 0:
			_fail("there is no %s bus" % bus)
	if AudioServer.get_bus_index(String(INFORMATION)) < 0:
		_fail("there is no %s bus" % INFORMATION)
		return
	# The soundtrack belongs on a bus the player may mute — that is the whole of what it is for — so
	# it is the one child besides the bed that is allowed off `SFX`. Recognised by identity rather
	# than by a name or a stream: a jukebox renamed, or playing nothing because the playlist is
	# still empty, is still the jukebox.
	var box := AudioManager.jukebox()
	if box == null:
		_fail("there is no jukebox, so there is no soundtrack to mute")
	elif box.bus != &"Music":
		_fail(
			(
				(
					"the soundtrack plays on %s rather than Music — on anything else the player cannot "
					+ "switch it off, and a soundtrack they cannot switch off is information"
				)
				% box.bus
			)
		)
	for child: Node in AudioManager.get_children():
		var flat := child as AudioStreamPlayer
		var placed := child as AudioStreamPlayer3D
		var bus: StringName = flat.bus if flat != null else (placed.bus if placed != null else &"")
		var carrying: StringName = _sound_on(flat, placed)
		if bus.is_empty() or carrying == AudioManager.BED_SOUND or child == box:
			continue
		if bus != INFORMATION:
			_fail(
				'a voice for "%s" plays on the %s bus, which the player may mute' % [carrying, bus]
			)
			return
	for id: StringName in AudioManager.LAYERS:
		for child: Node in _bed.get_children():
			var player := child as AudioStreamPlayer
			if (
				player != null
				and player.stream == AudioManager.sound(id)
				and player.bus != &"Music"
			):
				_fail("the %s layer plays on %s rather than Music" % [id, player.bus])
				return


func _sound_on(flat: AudioStreamPlayer, placed: AudioStreamPlayer3D) -> StringName:
	var stream: AudioStream = (
		flat.stream if flat != null else (placed.stream if placed != null else null)
	)
	if stream == null:
		return &"a pooled voice"
	for id: StringName in [AudioManager.BED_SOUND]:
		if AudioManager.sound(id) == stream:
			return id
	return &"an unnamed stream"


func _stand_up_a_crowd() -> Array[Enemy]:
	var standing: Array[Enemy] = []
	var director := _arena.get_node_or_null(^"WaveDirector/SpawnDirector") as SpawnDirector
	var data := load(FARMHAND) as EnemyData
	if director == null or data == null:
		_fail("no crowd could be stood up")
		return standing
	for index: int in A_CROWD:
		var angle := TAU * float(index) / float(A_CROWD)
		var where := Vector3(cos(angle), 0.0, sin(angle)) * 14.0
		var body := director.spawn_at(data, where, 1.0, 1.0, 1.0, 1.0, null, true)
		if body != null:
			standing.append(body)
	await get_tree().physics_frame
	return standing


func _advance(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().process_frame
		elapsed += 1.0 / 60.0


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				"music OK — the soundtrack is mutable, three layers of one length that only ever "
				+ "rise as the island fills, silent "
				+ "in the breather, out of the way of a wind-up, and carrying nothing the player "
				+ "needs"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr("music FAILED — %s" % failure)
	get_tree().quit(1)
