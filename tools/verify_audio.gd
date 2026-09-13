extends Node
## Headless proof that every sound is its own sound, and that the claims the design rests on are
## true of the waveforms: **a perfect hit rings longer than a normal one, a perfect parry rings
## longer than a late one, a swing through air passes rather than striking, and a wind-up climbs.**
##
## Nobody can listen to a check, so what is measured is the property that makes the listening work.
## For the two rewarded pairs it is the tail — loudness is not it, because a player turns the volume
## down and a busy fight buries a decibel. For the telegraph it is the shape of the envelope, which
## is the one thing that separates a thing arriving from a thing that already happened.
##
## Loudness *is* asserted, but only ever as an ordering: what matters is not that a footfall sits at
## 0.28 but that it sits under a swing, which sits under a hit. The numbers are a mix and the
## ordering is the design, so the ordering is what a check should hold.
##
## Two things are checked here that no waveform can show. The telegraph has to play on a positional
## voice, because a warning with no direction in it cannot answer the farmer behind the player. And
## a missed shot has to play **nothing** — the round already cracked when it left, and following it
## with a swish is the gun swinging an arm it does not have.
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
## Every one-shot, and nothing else pretending to be one more. The bed is not in it: it loops, so
## half the properties asserted here are ones it is *supposed* to break.
const EXPECTED: Array[StringName] = [
	&"hit",
	&"perfect",
	&"whiff",
	&"parry_perfect",
	&"parry_late",
	&"shot",
	&"shot_heavy",
	&"step_sand",
	&"step_water",
	&"roll",
	&"reload",
	&"dry_fire",
	&"hurt",
	&"enemy_down",
	&"pickup",
	&"telegraph",
	&"wave_cleared",
	&"low_ammo",
	&"merchant",
	&"victory",
	&"defeat",
	&"death_cry",
]
## The three music layers, checked on their own terms like the bed is: they loop, they carry no
## event, and they are the one thing here allowed to be muted.
const MUSIC: Array[StringName] = [&"music_ground", &"music_pulse", &"music_edge"]
## The impact families, and the wind-ups. Listed here rather than read off `AudioManager.IMPACTS`,
## for the reason the mutation sweep exists: a check that takes its list from the thing it is
## checking passes on a table with a row missing.
## The fists are the base and keep the plain `hit` and `perfect` ids, so they are not in this list —
## they are already two rows above it.
const FAMILIES: Array[StringName] = [&"stick", &"gun"]
## The farmhand is the base and keeps the plain `telegraph` id, so he is not in this list either.
const ARCHETYPES: Array[StringName] = [&"pirate"]
## The one looping sound, checked on its own terms.
const BED: StringName = &"surf"
## How close a baked peak has to be to the peak it declared. Tight: this is arithmetic, not taste,
## and the only thing that moves it is a normalisation that did not happen.
## How far a baked sound may sit from the level it declared. A decibel: past that the table has
## stopped describing the mix that plays.
const LEVEL_TOLERANCE: float = 1.0
## A floor under the logarithm, so an empty buffer reports as silent rather than as minus
## infinity.
const QUIETEST: float = 0.00001
## Where a rising sound's peak has to sit, as a share of its length. Past halfway, because the
## claim is that it climbs — not that it happens to be loudest a little later than a thud.
const CLIMBS_PAST: float = 0.5
## The longest a swing through air may last. It used to run 540 ms, which is most of a second of
## hiss laid over whatever the player did next.
const SWING_LASTS: float = 0.25
## How closely the two ends of the bed have to agree in level for the wrap to be inaudible. A loop
## that steps in volume ticks every time it comes round, and a tick under a fight is the kind of
## thing a player hears for an hour without being able to say what it is.
const SEAM_MATCHES: float = 0.25
## Where the bed's ends are measured, as a share of its length.
const SEAM_WINDOW: float = 0.04
## Frames a stopped voice pool is given to report itself free. Generous, because what is being
## waited on is the audio server's own iteration rather than anything this check controls — and a
## bound reached is reported as a failure, so generosity costs nothing but patience.
const DRAINS_WITHIN: int = 120
## Frames a sound is given to start before its absence is taken as an answer. Only the one check
## that asserts silence needs it: every other case can stop waiting the moment it hears something,
## and a check that expects nothing has nothing to stop on.
const SPEAKS_UP_WITHIN: int = 20

## How much of the signature a perfect hit has to carry at the partial's own frequency, and how
## little a plain one may. Both as a share of the tail's own energy, so they mean the same thing on
## a loud weapon and a quiet one.
const SIGNATURE_CARRIES: float = 0.2
const SIGNATURE_ABSENT: float = 0.25

## The first slice of a blow, where the body lives. The tail after it is the perfect partial, which
## is identical across families on purpose.
const BODY_WINDOW: float = 0.03
## How far apart two bodies have to measure before the ear would call them different sounds, and how
## far apart two wind-ups have to end up. Both in the same units as `_brightness`, which is roughly
## how much of the waveform is edge rather than tone.
const BODIES_DIFFER_BY: float = 0.02
const ARCHETYPES_DIFFER_BY: float = 0.01
## How closely the perfect rings have to agree across weapons. It is the same partial in all of
## them, so the only reason to allow any slack at all is the different body underneath it.
const RINGS_ALIKE_WITHIN: float = 0.25

const ATTACKS: String = "res://data/attacks"
const ENEMIES: String = "res://data/enemies"

var _failures: PackedStringArray = []


func _ready() -> void:
	_run()


func _run() -> void:
	# The one listener there is. `AudioManager` stays quiet headless because a one-shot still in
	# flight at teardown is an object the engine reports as leaked (#145) — and "there is nobody to
	# hear it" is exactly false here, because this check is about to ask which voice is carrying
	# which waveform.
	_check_a_headless_game_is_silent_until_something_listens()
	AudioManager.audible = true
	_check_every_sound_exists()
	_check_none_of_them_is_another()
	_check_the_perfect_hit_rings_longer()
	_check_the_perfect_parry_rings_longer()
	_check_a_swing_through_air_has_no_impact_in_it()
	_check_a_swing_reads_as_a_pass()
	_check_the_telegraph_is_the_one_sound_that_climbs()
	_check_every_weapon_lands_differently()
	_check_the_perfect_ring_is_the_same_in_every_family()
	_check_every_archetype_announces_itself_differently()
	_check_the_data_names_sounds_that_exist()
	_check_the_bed_comes_round_cleanly()
	_check_nothing_clips_or_clicks()
	_check_nothing_is_cut_off()
	await _check_the_right_sound_answers_each_signal()
	await _check_the_telegraph_comes_from_somewhere()
	await _check_a_missed_shot_does_not_swish()
	await _check_the_last_round_announces_itself()
	# Nothing left ringing. A voice still playing when the engine tears down is two objects it
	# reports as leaked, and a check that ends in a warning is a check nobody trusts the next time
	# a warning means something.
	await _silence_everything()
	_report()


func _check_every_sound_exists() -> void:
	for id: StringName in _every_sound():
		var stream := AudioManager.sound(id) as AudioStreamWAV
		if stream == null:
			_fail("there is no %s sound" % id)
			continue
		if stream.data.size() < 2:
			_fail("the %s sound is empty" % id)


## Seventeen names pointing at one waveform would satisfy every other check here and would be
## seventeen sounds in the log and one in the ear. It is the cheap way a set of sounds rots: a
## `_build` that forgets a line leaves an id resolving to whatever was registered before it.
func _check_none_of_them_is_another() -> void:
	for first: StringName in _every_sound():
		for second: StringName in _every_sound():
			if first == second:
				continue
			var one := AudioManager.sound(first) as AudioStreamWAV
			var other := AudioManager.sound(second) as AudioStreamWAV
			if one == null or other == null:
				continue
			if one.data == other.data:
				_fail("%s and %s are the same waveform" % [first, second])
				return


## Every id there is, the per-family ones included. The originals are a written-out list on purpose;
## these are built from two written-out lists for the same reason.
func _every_sound() -> Array[StringName]:
	var all: Array[StringName] = EXPECTED.duplicate()
	for family: StringName in FAMILIES:
		all.append(StringName("hit_%s" % family))
		all.append(StringName("perfect_%s" % family))
	for archetype: StringName in ARCHETYPES:
		all.append(StringName("telegraph_%s" % archetype))
	return all


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


## **The one sound in the game that climbs.**
##
## Everything else reports something that has already happened, so it is loudest the moment it
## begins and falls away. A telegraph reports something that has *not* happened yet, and the ear
## reads a rise as a thing arriving. That difference is categorical rather than a matter of degree,
## which is what lets a wind-up survive three farmers, a fight, and a player who has the music up.
##
## Asserted twice over, because a single peak index is one loud sample away from meaning nothing:
## the loudest moment sits in the second half, *and* the opening is quieter than the close.
func _check_the_telegraph_is_the_one_sound_that_climbs() -> void:
	var samples := _samples(&"telegraph")
	if samples.size() < 4:
		_fail("there is no telegraph sound")
		return
	var share := _peak_share(&"telegraph")
	if share <= CLIMBS_PAST:
		_fail(
			(
				"the telegraph is loudest %.0f%% of the way through — a warning has to climb"
				% [share * 100.0]
			)
		)
	var length := float(samples.size()) / float(AudioManager.MIX_RATE)
	var opens := _loudest(&"telegraph", 0.0, length * 0.2)
	var closes := _loudest(&"telegraph", length * 0.6, length)
	if opens >= closes:
		_fail("the telegraph opens at %.2f and closes at %.2f — it does not rise" % [opens, closes])


## Three weapons, three bodies. The bodies are what the ear reads as *what hit me*, and two families
## that only differed in level would be one sound with a volume knob — which is the thing this whole
## family of sounds exists to avoid.
##
## Measured on the body rather than on the whole buffer: the tail is where the perfect partial lives
## and it is deliberately identical across families, so comparing whole waveforms would find a
## difference that is not the one being claimed.
func _check_every_weapon_lands_differently() -> void:
	var bodies: Dictionary = {}
	for id: StringName in _every_impact():
		bodies[id] = _brightness(id, 0.0, BODY_WINDOW)
	for first: StringName in bodies:
		for second: StringName in bodies:
			if first == second:
				continue
			var gap := absf(float(bodies[first]) - float(bodies[second]))
			if gap < BODIES_DIFFER_BY:
				_fail(
					(
						(
							"%s and %s land with the same body (%.4f against %.4f) — a weapon you "
							+ "cannot hear is a weapon that only changed the number"
						)
						% [first, second, float(bodies[first]), float(bodies[second])]
					)
				)
				return


## And the other half, which matters more: **the perfect window sounds the same whatever is in
## hand**. It is the signature of the entire game, a player who learns it on fists has to have
## learnt it on the gun, and three signatures would be three things to learn in the half second
## there is to read one.
##
## Measured at the partial's own frequency rather than on the brightness of the tail. Brightness
## reported the stick as a third duller than the fists and was right to: its body rings for twice as
## long and is still under the tail. That is a true fact about the body and says nothing about
## whether the signature is there, which is the only thing being claimed.
func _check_the_perfect_ring_is_the_same_in_every_family() -> void:
	for id: StringName in _every_perfect():
		var plain := StringName(String(id).replace("perfect", "hit"))
		var rung := _partial(id, AudioManager.PERFECT_PARTIAL, TAIL_FROM, TAIL_TO)
		var silent := _partial(plain, AudioManager.PERFECT_PARTIAL, TAIL_FROM, TAIL_TO)
		if rung < SIGNATURE_CARRIES:
			_fail(
				(
					(
						"%s carries %.3f of the signature at %.0f Hz — the reward is missing on that "
						+ "weapon"
					)
					% [id, rung, AudioManager.PERFECT_PARTIAL]
				)
			)
		if silent > rung * SIGNATURE_ABSENT:
			_fail(
				(
					(
						"%s already carries %.3f at %.0f Hz against %s's %.3f — a plain hit that rings "
						+ "is a perfect window nobody can hear"
					)
					% [plain, silent, AudioManager.PERFECT_PARTIAL, id, rung]
				)
			)


## A farmhand's wind-up and a pirate's must not sound alike. Several of them commit at once in a
## crowd at night, and an archetype the ear cannot pick out of that is an archetype the player
## cannot answer differently.
##
## **There is no "one that stands out" any more.** That claim belonged to the thrower, who struck
## from fourteen metres and was the one the player might never see; with him gone, every wind-up
## here is attached to a body already on screen, and what is left to assert is that they differ.
func _check_every_archetype_announces_itself_differently() -> void:
	var pitches: Dictionary = {}
	for id: StringName in _every_telegraph():
		var length := float(_samples(id).size()) / float(AudioManager.MIX_RATE)
		# Both windows sit past the contact noise. Measured from the first sample, the burst of
		# hiss at the head reads brighter than any pitch the climb ever reaches, and all three
		# wind-ups looked like they were falling.
		var opens := _brightness(id, length * 0.35, length * 0.5)
		var closes := _brightness(id, length * 0.6, length * 0.85)
		if opens >= closes:
			_fail(
				(
					(
						"%s reads %.4f a third of the way through and %.4f near the end — every "
						+ "wind-up has to rise"
					)
					% [id, opens, closes]
				)
			)
		pitches[id] = closes
	for first: StringName in pitches:
		for second: StringName in pitches:
			if first == second:
				continue
			if absf(float(pitches[first]) - float(pitches[second])) < ARCHETYPES_DIFFER_BY:
				_fail(
					(
						"%s and %s climb to the same place (%.4f against %.4f)"
						% [first, second, float(pitches[first]), float(pitches[second])]
					)
				)
				return


## A `.tres` naming a sound nothing registered is silence where a signature should be, and it fails
## as a typo rather than as a missing noise nobody noticed. Both fallbacks are deliberate, so what
## is checked is that the name **resolves**, not that it is non-empty.
func _check_the_data_names_sounds_that_exist() -> void:
	for file_name: String in DirAccess.get_files_at(ATTACKS):
		var attack := load("%s/%s" % [ATTACKS, file_name.trim_suffix(".remap")]) as AttackData
		if attack == null or attack.impact_sound.is_empty():
			continue
		if not _resolves(attack.impact_sound, "hit_%s", AudioManager.BASE_IMPACT):
			_fail('%s lands with "%s", which is not a sound' % [file_name, attack.impact_sound])
	for file_name: String in DirAccess.get_files_at(ENEMIES):
		var data := load("%s/%s" % [ENEMIES, file_name.trim_suffix(".remap")]) as EnemyData
		if data == null or data.telegraph_sound.is_empty():
			continue
		if AudioManager.sound(data.telegraph_sound) == null:
			_fail('%s winds up with "%s", which is not a sound' % [file_name, data.telegraph_sound])


## Whether a family name reaches a waveform — either its own, or the base pair it shares.
func _resolves(family: StringName, pattern: String, base: StringName) -> bool:
	if family == base:
		return true
	return AudioManager.sound(StringName(pattern % family)) != null


func _every_impact() -> Array[StringName]:
	var all: Array[StringName] = [&"hit"]
	for family: StringName in FAMILIES:
		all.append(StringName("hit_%s" % family))
	return all


func _every_perfect() -> Array[StringName]:
	var all: Array[StringName] = [&"perfect"]
	for family: StringName in FAMILIES:
		all.append(StringName("perfect_%s" % family))
	return all


func _every_telegraph() -> Array[StringName]:
	var all: Array[StringName] = [&"telegraph"]
	for archetype: StringName in ARCHETYPES:
		all.append(StringName("telegraph_%s" % archetype))
	return all


## A swing through air is something **passing**: it swells, peaks and falls. A sound that is loudest
## at its first sample is a sound that began with contact, and the transient check above cannot see
## the difference between a quiet snap and a burst of noise that merely starts at full level.
##
## And it may not wash. At a decay of 0.09 the buffer ran 540 ms — most of a second of hiss laid
## over whatever the player did next, which in a chain is the following swing.
func _check_a_swing_reads_as_a_pass() -> void:
	var share := _peak_share(&"whiff")
	if share < 0.15:
		_fail(
			"a swing is loudest %.0f%% in — that is an impact, not air going past" % [share * 100.0]
		)
	var lasts := _tail(&"whiff")
	if lasts > SWING_LASTS:
		_fail(
			(
				"a swing through air lasts %.0f ms, which is a wash — %.0f ms is the ceiling"
				% [lasts * 1000.0, SWING_LASTS * 1000.0]
			)
		)


## The bed is the only sound that comes back round, so it is the only one that can tick.
##
## Two things have to hold and neither is visible in a diff: the engine has to be told to loop it at
## all, and the two ends have to agree in level — a loop assembled from noise has no natural join,
## and a step in volume at the wrap is a click a player hears for an hour without ever being able
## to say what it is.
func _check_the_bed_comes_round_cleanly() -> void:
	var stream := AudioManager.sound(BED) as AudioStreamWAV
	if stream == null or stream.data.size() < 4:
		_fail("there is no surf")
		return
	if stream.loop_mode != AudioStreamWAV.LOOP_FORWARD:
		_fail("the surf is not set to loop, so the island goes quiet after one pass")
	var last := stream.data.size() / 2 - 1
	if stream.loop_end != last:
		_fail("the surf loops to sample %d of %d — it drops its own tail" % [stream.loop_end, last])
	var samples := _samples(BED)
	var length := float(samples.size()) / float(AudioManager.MIX_RATE)
	var opens := _level(samples, 0.0, length * SEAM_WINDOW)
	var closes := _level(samples, length * (1.0 - SEAM_WINDOW), length)
	if opens <= 0.0 or closes <= 0.0:
		_fail("the surf is silent at one of its ends")
		return
	var apart := absf(opens - closes) / maxf(opens, closes)
	if apart > SEAM_MATCHES:
		_fail(
			(
				"the surf opens at %.3f and closes at %.3f — %.0f%% apart, so the wrap ticks"
				% [opens, closes, apart * 100.0]
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
		# Against the level the sound asked for, not a floor every sound shares. A footfall is meant
		# to be quieter than a hit, so a blanket minimum would either pass an unnormalised buffer or
		# forbid the mix having any shape at all.
		#
		# **Loudness, not peak.** The peak a sound comes out at is measured rather than asked for
		# now, so comparing the two would be asking a number whether it equals itself. What is a
		# decision, and therefore what is worth checking, is how loud the sound is.
		var wanted := linear_to_db(AudioManager.level_of(id))
		var heard := linear_to_db(maxf(SoundBank.loudness(samples), QUIETEST))
		if absf(heard - wanted) > LEVEL_TOLERANCE:
			_fail("the %s sound asked for %.1f dB and came out at %.1f" % [id, wanted, heard])
		if absf(samples[0]) > 0.02:
			_fail("the %s sound starts at %.3f, which is a click" % [id, samples[0]])


## The wiring, driven through the bus the way the fight drives it. A perfect hit that plays the
## normal sound is the one failure this whole issue exists to prevent, and nothing else here would
## notice it.
func _check_the_right_sound_answers_each_signal() -> void:
	var cases: Array[Array] = [
		[&"perfect", func() -> void: EventBus.attack_landed.emit(null, 12.0, true, null)],
		[&"hit", func() -> void: EventBus.attack_landed.emit(null, 8.0, false, null)],
		[&"whiff", func() -> void: EventBus.attack_whiffed.emit(null)],
		[&"parry_perfect", func() -> void: EventBus.parry_perfect.emit()],
		[&"parry_late", func() -> void: EventBus.parry_late.emit()],
		[&"step_sand", func() -> void: EventBus.footstep_taken.emit(false)],
		[&"step_water", func() -> void: EventBus.footstep_taken.emit(true)],
		[&"roll", func() -> void: EventBus.player_state_changed.emit(&"Dodge")],
		[&"reload", func() -> void: EventBus.weapon_reloaded.emit()],
		[&"dry_fire", func() -> void: EventBus.weapon_dry_fired.emit()],
		[&"pickup", func() -> void: EventBus.weapon_found.emit(&"gun")],
		[&"wave_cleared", func() -> void: EventBus.wave_cleared.emit(3, 40)],
		[&"shot", func() -> void: EventBus.weapon_fired.emit(_an_attack(false))],
		[&"shot_heavy", func() -> void: EventBus.weapon_fired.emit(_an_attack(true))],
		[&"merchant", func() -> void: EventBus.merchant_opened.emit()],
		[&"victory", func() -> void: EventBus.run_ended.emit(true)],
		[&"defeat", func() -> void: EventBus.run_ended.emit(false)],
		[&"death_cry", func() -> void: EventBus.player_died.emit()],
	]
	for case: Array in cases:
		var wanted: StringName = case[0]
		var fire: Callable = case[1]
		fire.call()
		# Waited for rather than read one frame later. A voice does not report itself playing the
		# instant it is told to, for the same reason a stopped one does not report itself free: the
		# audio server runs on its own iteration. Reading too early says "nothing came out" about a
		# sound that was about to.
		for _frame: int in DRAINS_WITHIN:
			if _anything_playing():
				break
			await get_tree().process_frame
		var heard := _now_playing()
		if heard != wanted:
			_fail("the fight asked for %s and %s came out" % [wanted, heard])
		await _silence_everything()
	cases.clear()


## Running dry is a **designed** moment, and the answer to it is to close on the next farmer rather
## than back away from him. A player who only finds out when the trigger stops answering has been
## told one round too late to do anything with it.
##
## Both halves: the round that leaves one behind speaks, and the ones before it do not. Without the
## second, a warning on every shot would pass — and a warning on every shot is no warning.
func _check_the_last_round_announces_itself() -> void:
	var kept := GameState.loadout.magazine
	for rounds: int in [4, 2, 1]:
		GameState.loadout.magazine = rounds
		EventBus.weapon_fired.emit(_an_attack(false))
		for _frame: int in DRAINS_WITHIN:
			if _anything_playing():
				break
			await get_tree().process_frame
		var warned := _voice_playing(&"low_ammo") != null
		if rounds == 1 and not warned:
			_fail("the shot that left one round behind said nothing about it")
		elif rounds != 1 and warned:
			_fail("the gun warned about running dry with %d rounds still in it" % rounds)
		await _silence_everything()
	GameState.loadout.magazine = kept


## The voice carrying one particular sound, or null. `_now_playing` answers with whatever it finds
## first, which is no use when two sounds are deliberately in the air at once.
func _voice_playing(id: StringName) -> AudioStreamPlayer:
	var wanted := AudioManager.sound(id) as AudioStreamWAV
	for child: Node in AudioManager.get_children():
		var voice := child as AudioStreamPlayer
		if voice != null and voice.playing and voice.stream == wanted:
			return voice
	return null


## The guard on the guard. `audible` defaults to false headless and that is the whole of the fix for
## #145; a default flipped back would put the leak straight back, and it is a leak **CI cannot see**
## — the boot gate greps every boot for a warning and the Linux runner does not reproduce this one.
## It was green while a developer on the same commit was not, which is the part that rots.
##
## Read before the check turns it on, because after that it says nothing.
func _check_a_headless_game_is_silent_until_something_listens() -> void:
	if DisplayServer.get_name() != "headless":
		return
	if AudioManager.audible:
		_fail(
			(
				"a headless game starts audible — a one-shot in flight at teardown leaks, and no "
				+ "runner this project uses would report it"
			)
		)


## An `AttackData` standing in for a round, built rather than loaded: what the sound branches on is
## two flags, and a check that loaded the real gun would be asserting the data file instead of the
## wiring — `verify_weapons` is where the gun's own figures are held to the table.
func _an_attack(charged: bool) -> AttackData:
	var attack := AttackData.new()
	attack.is_hitscan = true
	attack.charges = charged
	return attack


## **A wind-up has to arrive from a direction**, and that is the whole of why it exists: the ring on
## the ground answers a farmer the player can see, and the two behind them are answered by nothing
## else. A telegraph on a flat voice is a telegraph that says a farmer is committing *somewhere*.
##
## The position is asserted too. A voice that plays at the origin carries a direction, just not the
## right one — and at the origin it is the middle of the island, so it would sound plausible from
## almost anywhere and be wrong everywhere.
func _check_the_telegraph_comes_from_somewhere() -> void:
	var where := Vector3(7.0, 0.0, -11.0)
	EventBus.telegraph_began.emit(where, null)
	for _frame: int in DRAINS_WITHIN:
		if _anything_playing():
			break
		await get_tree().process_frame
	if _now_playing() == &"telegraph":
		_fail("the telegraph played flat — a warning with no direction in it")
	var voice := _placed_voice(&"telegraph")
	if voice == null:
		_fail("nothing positional played the telegraph")
		await _silence_everything()
		return
	if voice.global_position.distance_to(where) > 0.01:
		_fail("the telegraph plays at %v and the farmer is at %v" % [voice.global_position, where])
	await _silence_everything()


## A shot that found nobody has already been heard: it cracked when the round left. Following it
## with a swish was the gun swinging an arm it does not have, and it is the one case in the whole
## set where the right answer to a signal is silence.
func _check_a_missed_shot_does_not_swish() -> void:
	EventBus.attack_whiffed.emit(_an_attack(false))
	# Given the same room to be heard as every other case, or this would pass by reading before a
	# sound it is asserting the absence of had a chance to start.
	for _frame: int in SPEAKS_UP_WITHIN:
		await get_tree().process_frame
	var heard := _now_playing()
	if heard != &"nothing":
		_fail("a missed shot played %s — a gun does not swing through air" % heard)
	await _silence_everything()


func _placed_voice(id: StringName) -> AudioStreamPlayer3D:
	for voice: Node in AudioManager.get_children():
		var player := voice as AudioStreamPlayer3D
		if player == null or not player.playing:
			continue
		if player.stream == AudioManager.sound(id):
			return player
	return null


func _now_playing() -> StringName:
	for voice: Node in AudioManager.get_children():
		var player := voice as AudioStreamPlayer
		if player == null or not player.playing:
			continue
		for id: StringName in EXPECTED:
			if player.stream == AudioManager.sound(id):
				return id
	return &"nothing"


## Both pools, and **it waits until they are actually idle.**
##
## `AudioStreamPlayer3D` does not descend from `AudioStreamPlayer` — they are siblings under Node —
## so stopping one kind leaves the other ringing into the next measurement.
##
## The waiting is the part that matters, and it cost a flaky run to learn. `stop()` does not make a
## voice report itself free within the same frame: the audio server releases it on its own
## iteration, which is not frame-locked. The wiring table drives fourteen sounds through a pool of
## twelve, so a voice still counted as busy from two cases ago means `play` finds nothing free and
## returns in silence — and the check then reports that the fight asked for a sound and nothing came
## out, which is true, and about the check rather than about the game. It failed on `dry_fire` once
## and passed twice with nothing changed, which is the worst way for a check to behave.
##
## Bounded, and a bound reached is a failure rather than a shrug: a pool that never drains is
## something to be told about, not to wait longer for.
func _silence_everything() -> void:
	for voice: Node in AudioManager.get_children():
		var flat := voice as AudioStreamPlayer
		if flat != null:
			flat.stop()
		var placed := voice as AudioStreamPlayer3D
		if placed != null:
			placed.stop()
	for _frame: int in DRAINS_WITHIN:
		if not _anything_playing():
			return
		await get_tree().process_frame
	_fail("the voice pool would not drain — something is still playing after it was stopped")


func _anything_playing() -> bool:
	for voice: Node in AudioManager.get_children():
		# The sea is the exception: it is meant to be playing, and headless it never starts. Skipped
		# by identity rather than by what it carries, because it is a subtree of its own now.
		if voice == AudioManager.bed():
			continue
		var flat := voice as AudioStreamPlayer
		if flat != null and flat.playing:
			return true
		var placed := voice as AudioStreamPlayer3D
		if placed != null and placed.playing:
			return true
	return false


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
## How much of a window is ringing at one frequency, as a share of everything in it. A single bin
## rather than a whole transform: there is exactly one partial anybody is asking about, and the
## question is whether it is there.
func _partial(id: StringName, hertz: float, from: float, to: float) -> float:
	var samples := _samples(id)
	var first := maxi(int(from * float(AudioManager.MIX_RATE)), 0)
	var after := mini(int(to * float(AudioManager.MIX_RATE)), samples.size())
	if after - first < 2:
		return 0.0
	var step := TAU * hertz / float(AudioManager.MIX_RATE)
	var cosine := 0.0
	var sine := 0.0
	var energy := 0.0
	for index: int in range(first, after):
		var angle := step * float(index - first)
		cosine += samples[index] * cos(angle)
		sine += samples[index] * sin(angle)
		energy += samples[index] * samples[index]
	if energy <= 0.0:
		return 0.0
	# Two over N is what a full-amplitude sine at this frequency would score, so a pure tone reads
	# as one and the figure means the same thing whatever the window length is.
	var span := float(after - first)
	return sqrt(cosine * cosine + sine * sine) * 2.0 / span / sqrt(energy / span) / sqrt(2.0)


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


## Where a sound is loudest, as a share of its own length. The shape of the envelope in one number:
## nought is a sound that begins at its peak, and anything past a half is a sound that arrives.
func _peak_share(id: StringName) -> float:
	var samples := _samples(id)
	if samples.size() < 2:
		return 0.0
	var loudest := 0.0
	var at := 0
	for index: int in samples.size():
		var value := absf(samples[index])
		if value > loudest:
			loudest = value
			at = index
	return float(at) / float(samples.size() - 1)


## Average level over a window, rather than its single loudest sample. Noise is spiky, so a peak
## says nothing about how loud a stretch of it *sounds* — which is the only thing that matters when
## the question is whether two ends of a loop match.
func _level(samples: PackedFloat32Array, from: float, to: float) -> float:
	var first := maxi(int(from * float(AudioManager.MIX_RATE)), 0)
	var after := mini(int(to * float(AudioManager.MIX_RATE)), samples.size())
	if after <= first:
		return 0.0
	var total := 0.0
	for index: int in range(first, after):
		total += samples[index] * samples[index]
	return sqrt(total / float(after - first))


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
				"audio OK — every sound is its own waveform, three "
				+ "weapons land with three bodies and one signature, two archetypes wind up "
				+ "from two pitches that stay apart, the last round says so, "
				+ "a swing through air passes rather than snapping, and the surf comes back "
				+ "round without a tick"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr("audio FAILED — %s" % failure)
	get_tree().quit(1)
