extends Node
## Proof that the mix is a mix: an order, a ceiling, and one key.
##
## The waveforms themselves are `verify_audio`'s. This is about their relationship, which is the
## only thing that can go wrong once each of them is individually fine — a footfall at a hit's level
## walks over the fight, four loud things at once sum past full scale, and two sounds that disagree
## about the key grind when they arrive together.
## Run: godot --headless --path . res://tools/verify_mix.tscn

const MANAGER: String = "res://scripts/autoload/audio_manager.gd"
## How many loud sounds a night wave really puts in the air at once. Written out rather than taken
## from `VOICES`: twelve voices can all be busy, but holding the mix to twelve simultaneous
## telegraphs would make the game inaudible to protect against something that never happens.
const AT_ONCE: int = 4
## A minor, as semitones above the root. The game is in it because the bed, the perfect parry and
## the perfect signature always were, and the three that were not have been moved.
const A_MINOR: Array[int] = [0, 2, 3, 5, 7, 8, 10]
## Half a semitone. Anything further from a note than this is a different note.
const QUARTER_TONE: float = 0.5
## Below this a partial is a body rather than a pitch — a thud at 150 Hz is what a fist sounds like
## hitting a man, and it has no business being in any key.
const LOWEST_PITCH: float = 380.0
## The one tone deliberately outside the key. The dry-fire warning is two clicks a semitone apart
## and has to be heard as *not* music; 932 Hz is B flat, which A minor does not contain.
const OFF_KEY: Array[float] = [932.0]
## Fewer named tones than this means the search stopped finding them and the check stopped checking.
const TONES_AT_LEAST: int = 10
## Pitches built at runtime rather than written down, and where each is covered instead: the impact
## bodies come from `IMPACTS` and are under `LOWEST_PITCH`; an ending's notes are built from the
## named ones two lines above it; a layer's voices come from `LAYERS` and are checked from the table
## itself. A name that is not one of these fails rather than passing unseen.
const COMPUTED: Array[String] = ["float", "notes", "hertz"]
## What each voice of a layer is above the one below it.
const FIFTH: float = 1.5

var _failures: PackedStringArray = []


func _ready() -> void:
	_run()


func _run() -> void:
	_check_the_mix_is_ordered()
	_check_a_busy_fight_does_not_clip()
	_check_everything_tonal_is_in_the_same_key()
	_report()


## **The mix, as an ordering rather than as a set of numbers somebody liked once.**
##
## This is the check that keeps the whole set usable. Every sound here is individually fine and the
## only thing that can go wrong is their relationship: a footfall at a hit's level walks over the
## fight, and a telegraph under one is a warning the player will not hear in a crowd. So what is
## asserted is the order, and the order is the design — quietest is the body you already control,
## loudest is the thing about to hit you.
func _check_the_mix_is_ordered() -> void:
	var rungs: Array[Array] = [
		[&"step_sand", &"whiff"],
		[&"step_water", &"whiff"],
		[&"roll", &"whiff"],
		[&"whiff", &"hit"],
		[&"hurt", &"telegraph"],
		[&"hit", &"telegraph"],
	]
	for rung: Array in rungs:
		var under: StringName = rung[0]
		var over: StringName = rung[1]
		var quiet := AudioManager.peak_of(under)
		var loud := AudioManager.peak_of(over)
		if quiet >= loud:
			_fail(
				(
					"%s peaks at %.2f and %s at %.2f — the quieter one is not quieter"
					% [under, quiet, over, loud]
				)
			)


## Several of these arrive at once — three farmers commit at night while a chain lands — and each
## was normalised as though it were alone. Uncorrelated sources sum as the root of the sum of
## squares, so the four loudest in the game have to fit inside full scale together.
##
## The count is written out rather than taken from `VOICES`: twelve voices can all be busy, but four
## *loud* things at once is what a night wave actually sounds like, and holding the mix to twelve
## simultaneous telegraphs would make the game inaudible to protect against something that never
## happens.
func _check_a_busy_fight_does_not_clip() -> void:
	var loudest: Array[float] = []
	for id: StringName in AudioManager.every_sound():
		loudest.append(AudioManager.peak_of(id))
	loudest.sort()
	loudest.reverse()
	var square := 0.0
	for index: int in mini(AT_ONCE, loudest.size()):
		square += loudest[index] * loudest[index]
	var together := sqrt(square)
	if together > 1.0:
		_fail(
			(
				"the %d loudest sounds reach %.2f of full scale together — a night wave clips"
				% [AT_ONCE, together]
			)
		)


## **The whole game is in A minor.** Not decoration: two sounds that arrive together and disagree
## about the key grind, and the three that did were the wave sting, the merchant and the two endings
## — the three most musical moments there are.
##
## Every partial named in `AudioManager` has to sit within a quarter-tone of a note in the scale.
## The dry-fire warning is the one exception and it is deliberate: it has to be heard as *not*
## music, so it is written down rather than quietly skipped.
func _check_everything_tonal_is_in_the_same_key() -> void:
	var expression := RegEx.new()
	expression.compile("(?:SoundBank\\.)?tone\\(\\s*samples,\\s*([A-Za-z_0-9.]+)")
	var file := FileAccess.open(MANAGER, FileAccess.READ)
	if file == null:
		_fail("cannot read %s" % MANAGER)
		return
	# Constants as well as literals. The three sounds that were moved into key are written with named
	# notes, so a scan that only read numbers would skip exactly the ones this check is about.
	var named: Dictionary = AudioManager.get_script().get_script_constant_map()
	var checked := 0
	for found: RegExMatch in expression.search_all(file.get_as_text()):
		var written := found.get_string(1)
		var hertz := written.to_float() if written.is_valid_float() else -1.0
		if hertz < 0.0:
			if COMPUTED.has(written):
				continue
			if not named.has(written):
				_fail('"%s" is a pitch this check cannot resolve, so it went unchecked' % written)
				continue
			hertz = float(named[written])
		if hertz < LOWEST_PITCH or OFF_KEY.has(hertz):
			continue
		checked += 1
		if not _in_the_key(hertz):
			_fail(
				(
					"%s (%.0f Hz) is not a note of the home key — two keys at once grind"
					% [written, hertz]
				)
			)
	if checked < TONES_AT_LEAST:
		_fail("only %d tones were checked against the key, which is fewer than there are" % checked)
	_check_the_bed_stays_in_the_key(named)


## The bed is stacked fifths, and a stack of fifths **leaves the key on the third step**: A, E, B,
## then F sharp, which A minor does not contain. Three layers were reaching it, so the one sound
## playing under every other sound in the game disagreed with the three most musical moments in it.
##
## Checked from the table rather than from the loop that reads it: the loop multiplies, and what has
## to be true is true of every note it can produce.
func _check_the_bed_stays_in_the_key(named: Dictionary) -> void:
	var layers: Dictionary = named["LAYERS"]
	for id: StringName in layers:
		var voice: Dictionary = layers[id]
		var root := float(voice["root"])
		for step: int in int(voice["voices"]):
			var hertz := root * pow(FIFTH, float(step))
			if not _in_the_key(hertz):
				_fail(
					(
						"%s reaches %.0f Hz on its %d%s voice, which is outside the home key"
						% [id, hertz, step + 1, "st" if step == 0 else "th"]
					)
				)


## Whether a frequency lands on a note of A minor, in any octave, within a quarter-tone.
func _in_the_key(hertz: float) -> bool:
	var semitones := 12.0 * log(hertz / AudioManager.A) / log(2.0)
	var nearest := roundf(semitones)
	if absf(semitones - nearest) > QUARTER_TONE:
		return false
	return A_MINOR.has(int(posmod(nearest, 12.0)))


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				"mix OK — quiet things stay under loud ones, four at once fit inside full scale, "
				+ "and everything with a pitch is in the same key"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr("mix FAILED — %s" % failure)
	get_tree().quit(1)
