extends Node
## Headless proof that the five sounds are five sounds, and that the one claim the design rests on
## is true of the waveform: **a perfect hit rings longer than a normal one, and a perfect parry
## rings longer than a late one.**
##
## Nobody can listen to a check. What can be measured is the property that makes the listening work:
## the tail. Loudness is not it — a player turns the volume down and a busy fight buries a decibel —
## so what is asserted is how long each sound goes on for, and that the two pairs differ by a margin
## an ear can hold onto.
## Run: godot --headless --path . res://tools/verify_audio.tscn

## Where a sound is counted as over: a hundredth of its own peak, which is about forty decibels down
## and below anything audible over a fight.
const SILENCE: float = 0.01
## A tail has to outlast its plain version by this much. Twice, not more: for the parries the
## length *is* the difference — the same bell, damped — but for the hits it is only half the story,
## and the other half is checked separately below. A bound picked so that a test passes is worth
## nothing; this one is picked because a doubling is what an ear holds onto with nothing to compare
## against.
const TELLS_APART: float = 2.0
## How much brighter the perfect hit's tail has to be than the plain one's. A perfect hit is not a
## longer thud, it is a thud *with a partial the other one does not contain at all* — a categorical
## difference rather than a degree, and the only one that survives a fight full of other noise.
const BRIGHTER: float = 3.0
## The window the two hits are compared over: past the transient they share, inside the shorter of
## the two. What is being compared is what is still ringing, not what struck.
const TAIL_FROM: float = 0.06
const TAIL_TO: float = 0.15
## Where a transient lives. A hit snaps inside this; a swing through empty air must not.
const TRANSIENT: float = 0.012
## The five, and nothing else pretending to be a sixth.
const EXPECTED: Array[StringName] = [&"hit", &"perfect", &"whiff", &"parry_perfect", &"parry_late"]

var _failures: PackedStringArray = []


func _ready() -> void:
	_run()


func _run() -> void:
	_check_all_five_exist()
	_check_none_of_them_is_another()
	_check_the_perfect_hit_rings_longer()
	_check_the_perfect_parry_rings_longer()
	_check_a_swing_through_air_has_no_impact_in_it()
	_check_nothing_clips_or_clicks()
	_check_nothing_is_cut_off()
	await _check_the_right_sound_answers_each_signal()
	_report()


func _check_all_five_exist() -> void:
	for id: StringName in EXPECTED:
		var stream := AudioManager.sound(id) as AudioStreamWAV
		if stream == null:
			_fail("there is no %s sound" % id)
			continue
		if stream.data.size() < 2:
			_fail("the %s sound is empty" % id)


## Five names pointing at one waveform would satisfy every other check here and would be five
## sounds in the log and one in the ear.
func _check_none_of_them_is_another() -> void:
	for first: StringName in EXPECTED:
		for second: StringName in EXPECTED:
			if first == second:
				continue
			var one := AudioManager.sound(first) as AudioStreamWAV
			var other := AudioManager.sound(second) as AudioStreamWAV
			if one == null or other == null:
				continue
			if one.data == other.data:
				_fail("%s and %s are the same waveform" % [first, second])
				return


## The whole design in one place. The eye is on the enemy, so what says "that one counted" has to
## be the tail — and it is not merely a longer thud. It is a bright partial the plain hit lacks.
func _check_the_perfect_hit_rings_longer() -> void:
	_check_the_tail_is_longer(&"perfect", &"hit")
	var ringing := _brightness(&"perfect", TAIL_FROM, TAIL_TO)
	var dull := _brightness(&"hit", TAIL_FROM, TAIL_TO)
	if ringing < dull * BRIGHTER:
		_fail(
			(
				(
					"a perfect hit's tail is %.3f bright against a plain hit's %.3f — it has to carry"
					+ " a partial the plain one does not, not just last longer"
				)
				% [ringing, dull]
			)
		)


func _check_the_perfect_parry_rings_longer() -> void:
	_check_the_tail_is_longer(&"parry_perfect", &"parry_late")


func _check_the_tail_is_longer(rewarded: StringName, plain: StringName) -> void:
	var long_tail := _tail(rewarded)
	var short_tail := _tail(plain)
	if short_tail <= 0.0:
		_fail("the %s sound has no length at all" % plain)
		return
	if long_tail < short_tail * TELLS_APART:
		_fail(
			(
				(
					"%s rings %.0f ms against %s's %.0f ms — it has to be %.0f times longer to be"
					+ " heard as a different thing"
				)
				% [rewarded, long_tail * 1000.0, plain, short_tail * 1000.0, TELLS_APART]
			)
		)


## Nothing was struck, so nothing may snap. A whiff that opens on a transient reads as a hit that
## did no damage, which is worse than no sound at all.
func _check_a_swing_through_air_has_no_impact_in_it() -> void:
	var swing := _loudest(&"whiff", 0.0, TRANSIENT)
	var contact := _loudest(&"hit", 0.0, TRANSIENT)
	if swing >= contact * 0.5:
		_fail(
			(
				"a swing through air opens at %.2f against a hit's %.2f — it sounds like contact"
				% [swing, contact]
			)
		)


## A partial added without normalising clips, and a waveform that starts at full amplitude clicks.
## Both are inaudible in a diff and obvious in a headset.
func _check_nothing_clips_or_clicks() -> void:
	for id: StringName in EXPECTED:
		var samples := _samples(id)
		if samples.is_empty():
			continue
		var loudest := 0.0
		var clipped := 0
		for value: float in samples:
			loudest = maxf(loudest, absf(value))
			if absf(value) >= 0.999:
				clipped += 1
		if clipped > 1:
			_fail("the %s sound clips on %d samples" % [id, clipped])
		if loudest < 0.5:
			_fail("the %s sound peaks at %.2f — it was never normalised" % [id, loudest])
		if absf(samples[0]) > 0.02:
			_fail("the %s sound starts at %.3f, which is a click" % [id, samples[0]])


## The wiring, driven through the bus the way the fight drives it. A perfect hit that plays the
## normal sound is the one failure this whole issue exists to prevent, and nothing else here would
## notice it.
func _check_the_right_sound_answers_each_signal() -> void:
	var cases: Array[Array] = [
		[&"perfect", func() -> void: EventBus.attack_landed.emit(null, 12.0, true)],
		[&"hit", func() -> void: EventBus.attack_landed.emit(null, 8.0, false)],
		[&"whiff", func() -> void: EventBus.attack_whiffed.emit(null)],
		[&"parry_perfect", func() -> void: EventBus.parry_perfect.emit()],
		[&"parry_late", func() -> void: EventBus.parry_late.emit()],
	]
	for case: Array in cases:
		var wanted: StringName = case[0]
		var fire: Callable = case[1]
		fire.call()
		await get_tree().process_frame
		var heard := _now_playing()
		if heard != wanted:
			_fail("the fight asked for %s and %s came out" % [wanted, heard])
		await _silence_everything()
	cases.clear()


func _now_playing() -> StringName:
	for voice: Node in AudioManager.get_children():
		var player := voice as AudioStreamPlayer
		if player == null or not player.playing:
			continue
		for id: StringName in EXPECTED:
			if player.stream == AudioManager.sound(id):
				return id
	return &"nothing"


func _silence_everything() -> void:
	for voice: Node in AudioManager.get_children():
		var player := voice as AudioStreamPlayer
		if player != null:
			player.stop()
	await get_tree().process_frame


## How long a sound goes on for: the last moment it is still above a hundredth of its own peak.
func _tail(id: StringName) -> float:
	var samples := _samples(id)
	if samples.is_empty():
		return 0.0
	var loudest := 0.0
	for value: float in samples:
		loudest = maxf(loudest, absf(value))
	if loudest <= 0.0:
		return 0.0
	var last := 0
	for index: int in samples.size():
		if absf(samples[index]) >= loudest * SILENCE:
			last = index
	return float(last) / float(AudioManager.MIX_RATE)


## How high the sound sits, without an FFT: the derivative of a sine grows with its frequency, so
## the ratio of the differentiated signal's level to the signal's own stands in for pitch. A 150 Hz
## thud lands near 0.04 at this rate; a 1320 Hz ring near 0.38.
func _brightness(id: StringName, from: float, to: float) -> float:
	var samples := _samples(id)
	var first := maxi(int(from * float(AudioManager.MIX_RATE)), 1)
	var after := mini(int(to * float(AudioManager.MIX_RATE)), samples.size())
	if after <= first:
		return 0.0
	var level := 0.0
	var slope := 0.0
	for index: int in range(first, after):
		level += samples[index] * samples[index]
		var step := samples[index] - samples[index - 1]
		slope += step * step
	if level <= 0.0:
		return 0.0
	return sqrt(slope / level)


## A sound that ends while it is still going does not fade out, it stops dead — and a buffer sized
## by hand next to a decay tuned by ear is exactly how that happens. It did, on the first run here.
func _check_nothing_is_cut_off() -> void:
	for id: StringName in EXPECTED:
		var samples := _samples(id)
		if samples.size() < 2:
			continue
		var loudest := 0.0
		for value: float in samples:
			loudest = maxf(loudest, absf(value))
		# Read from before the anti-click ramp, not from the last sample. The ramp fades the tail to
		# zero whatever is under it, so measuring the end measures the ramp — which passed a buffer
		# cut to a third of its decay without a word.
		var ramp := int(AudioManager.RAMP * float(AudioManager.MIX_RATE))
		var at := samples.size() - ramp - 2
		if at < 1:
			continue
		var ends_at := absf(samples[at])
		if ends_at > loudest * SILENCE:
			_fail(
				(
					(
						"the %s sound is still at %.0f%% of its peak when the buffer ends — it is cut"
						+ " off, not decayed"
					)
					% [id, 100.0 * ends_at / loudest]
				)
			)


func _loudest(id: StringName, from: float, to: float) -> float:
	var samples := _samples(id)
	var first := int(from * float(AudioManager.MIX_RATE))
	var after := mini(int(to * float(AudioManager.MIX_RATE)), samples.size())
	var peak := 0.0
	for index: int in range(first, after):
		peak = maxf(peak, absf(samples[index]))
	return peak


## The 16-bit waveform back as floats, which is the only form any of this can be measured in.
func _samples(id: StringName) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var stream := AudioManager.sound(id) as AudioStreamWAV
	if stream == null:
		return out
	var bytes := stream.data
	out.resize(bytes.size() / 2)
	for index: int in out.size():
		out[index] = float(bytes.decode_s16(index * 2)) / 32767.0
	return out


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				"audio OK — five distinct sounds, the perfect hit and the perfect parry ring "
				+ "longer than their plain versions, and a swing through air never snaps"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr("audio FAILED — %s" % failure)
	get_tree().quit(1)
