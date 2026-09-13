extends Node
## Every sound the island makes, synthesised at startup rather than shipped as files.
##
## The subject of this game is timing, and the eye is on the enemy — not on the player, and not on
## the flash around their own fist. **A perfect hit has to be recognisable with the screen off.**
## That is what the five signatures are for, and it is why they were here before any audio asset
## existed: a wave lasts six minutes, and a window the player can only see is a window they will
## miss.
##
## The signatures are one family with one idea in it: **the ring is the reward.** A normal hit is a
## thud that stops. A perfect hit is the same thud with a bright partial that keeps going. A late
## parry is a dull short version of the perfect parry's bell. Nothing differs by loudness alone,
## because loudness is the first thing a player turns down and the first thing a busy fight buries.
##
## Everything added since divides into three, and the division is what keeps the mix legible:
##
## - **The player's own body** — footfalls, a roll, a reload, a trigger on an empty magazine. Flat,
##   quiet, and never the thing you are listening for. They exist so the player knows the game
##   heard them.
## - **The world** — a farmer committing, a body going down. **Positional**, because a wind-up the
##   player cannot see is the one they most need to hear, and a direction is the only thing that
##   makes a crowd survivable.
## - **The bed** — the surf, looping on its own bus, which is the only sound here with no event
##   behind it.
##
## Loudness is declared per sound rather than normalised to one peak for all of them. It has to be:
## a footfall at a hit's level buries the fight it is walking through, and the telegraph has to cut
## through three of them. `peak_of` reports what each one asked for, so the mix is a table a check
## can read rather than a set of numbers tuned until it sounded fine once.
##
## Baked into `AudioStreamWAV` once, not pushed through an `AudioStreamGenerator` frame by frame: a
## one-shot does not want a live synthesiser it can starve, and a waveform built once is a waveform
## that sounds the same every time — which is the whole point of a signature.

## Enough for a thud and a ring; the highest partial here is under 3 kHz. Halving the rate halves
## the bytes and changes nothing anybody can hear.
const MIX_RATE: int = 22050
## How many flat sounds may overlap. A chain into a parry into a hit is three, and locomotion now
## shares this pool — a sprint puts a footfall in it every fifth of a second. Raised so that a
## running player can never be the reason a perfect parry finds no voice.
const VOICES: int = 12
## How many sounds may come from somewhere. Three farmers may commit at once at night, and a body
## can go down while they do.
const POSITIONAL_VOICES: int = 6
## How far a positional sound carries. It has to beat what the camera shows — the eye reaches about
## twenty metres at the default zoom and twenty-four at the furthest — because a telegraph that is
## only audible once its owner is on screen is a telegraph the ring already gave you.
const REACH: float = 34.0
## Sine partials are summed, so a raw buffer can pass one. Everything is scaled to the peak it
## declares afterwards rather than hoping.
const PEAK: float = 0.9
## What the player's own body is worth in the mix. A footfall is confirmation, not information, and
## it happens twice a second for the whole run.
const FOOTFALL_PEAK: float = 0.28
## A roll, a reload, a dry trigger, a body going down: moments worth hearing and never worth
## listening for.
const INCIDENTAL_PEAK: float = 0.55
## A miss is the least interesting thing that happens in a fight, and it used to be as loud as a
## landed blow. Under a hit by enough to be heard as the lesser of the two.
const WHIFF_PEAK: float = 0.45
## The one sound that has to be heard over everything else, so it is the loudest thing in the game —
## above a landed blow, which is the loudest thing the player causes. The margin is small because
## peak is not really how a wind-up cuts through: it arrives from a direction and it climbs, and
## both of those beat a decibel. It is still not allowed to be the quieter of the two.
const TELEGRAPH_PEAK: float = 0.95
## A wave passing is the only sound in the game the player is allowed to sit and enjoy.
const STING_PEAK: float = 0.7
## The bed sits under the whole game without ever being the reason something was missed.
const SURF_PEAK: float = 0.3
## A waveform that starts or ends at full amplitude clicks. Two milliseconds is inaudible and
## enough to stop it.
const RAMP: float = 0.002
## How many time constants a buffer runs for. Six puts the slowest partial at a four-hundredth of
## itself, which is inaudible — and a buffer that ends while the sound is still going does not fade
## out, it stops dead. The length is derived from the decays rather than typed next to them, because
## a decay tuned by ear and a length left behind is a click nobody hears in a diff.
const DECAYED: float = 6.0
## The thud both hits share. Short, because a jab that rings is a jab that covers the next one — and
## because what tells a perfect hit apart has to be the partial on top, not a longer body.
const BODY_DECAY: float = 0.035
## The partial the perfect window adds, and how long it rings. **The same in every impact family**:
## it is the signature, and a player who learns it on fists has learnt it on the gun.
const PERFECT_PARTIAL: float = 1320.0
const PERFECT_RING: float = 0.13
## The body of a blow, per weapon. Pitch, how long it rings, and how much contact grain rides on top
## — a fist is a dull knock on a body, a stick is wood that cracks and carries, a round is sharp and
## over at once. The generic row is what an attack that names no family gets.
##
## `grain` only seeds the noise. Two families sharing a seed would share their contact exactly,
## which is the one way two of these could accidentally become the same sound.
##
## **The fists are the base**, and they keep the plain ids `hit` and `perfect` rather than getting a
## fourth waveform of their own. That is not an accident of implementation: the fists are the weapon
## the player never puts down and never runs out of, so a blow landing in this game sounds like a
## fist landing unless something else is in hand. An attack naming a family nothing registered falls
## back here — audibly the fist, and `verify_audio` fails the build before anyone hears it.
const BASE_IMPACT: StringName = &"fist"
const IMPACTS: Dictionary = {
	&"fist": {"hertz": 150.0, "decay": 0.035, "contact": 0.5, "snap": 0.018, "grain": 11},
	&"stick": {"hertz": 240.0, "decay": 0.075, "contact": 0.72, "snap": 0.010, "grain": 29},
	&"gun": {"hertz": 320.0, "decay": 0.022, "contact": 0.34, "snap": 0.006, "grain": 47},
}
## A wind-up, per archetype. All three climb — a warning that does not rise is a warning the ear
## reads as a drone — and they differ in **where they climb from and to**, which is the one thing
## that survives three of them at once in a crowd at night.
##
## The thrower is the outlier on purpose: he strikes from fourteen metres and is the one archetype
## the player may never see coming, so his is the highest and the longest, and the only one that
## climbs more than an octave.
##
## **The farmhand is the base**, keeping the plain `telegraph` id for the same reason the fists keep
## `hit`: he is the archetype every wave is made of, and a wind-up in this game sounds like a
## farmhand's unless somebody rarer is committing.
const BASE_TELEGRAPH: StringName = &"farmhand"
const TELEGRAPHS: Dictionary = {
	&"farmhand": {"from": 300.0, "to": 690.0, "seconds": 0.30, "grain": 61},
	&"reaper": {"from": 150.0, "to": 300.0, "seconds": 0.42, "grain": 67},
	&"thrower": {"from": 520.0, "to": 1240.0, "seconds": 0.36, "grain": 73},
}
## Small random pitch on repeated sounds, so a chain does not sound like a machine. The perfect hit
## and both parries are left alone: a signature that moves is not one.
const JITTER: float = 0.04
## Footfalls get more of it than anything else. Two identical steps in a row is the single most
## artificial sound a game can make, and the ear catches it long before it catches a pitch.
const STEP_JITTER: float = 0.12
## How many rounds have to be left for the warning to sound. One: the shot that empties the magazine
## is too late to act on, and two is a warning the player hears most of a wave before it matters.
const LAST_ROUNDS: int = 1
## A swing gets nearly as much. Three misses in a chain is the same trap as three identical steps,
## and a whiff carries no timing information that a wandering pitch could damage.
const SWING_JITTER: float = 0.09
## How long the surf bed runs before it comes back round. Long enough that the ear does not learn
## it, short enough to stay a reasonable amount of memory at this rate — six seconds of mono at
## 22 kHz is a quarter of a megabyte, once, for the whole game.
const SURF_SECONDS: float = 6.0
## Whole swells across the bed, and the next one up gets one more. Two and three give periods of
## three and two seconds, which do not divide into each other — so the water never settles into a
## rhythm the ear can count, and a wave every three seconds is a metronome.
const SURF_SWELLS: int = 2
## What a music layer is normalised to. Well under the bed, which is itself well under the fight: a
## layer that competes with a wind-up has put atmosphere in front of information.
## How far apart the three notes of an ending fall, and how long the last one holds. Slower than the
## wave sting: a run finishing is the one moment in the game nobody is in a hurry.
const ENDING_STEP: float = 0.22
const ENDING_RING: float = 0.55
## The one looping sound that is not music. Named so a check can tell the bed apart from a one-shot
## without knowing what a surf is.
const BED_SOUND: StringName = &"surf"
const MUSIC_PEAK: float = 0.22
## How long every layer runs before it comes round. **The same for all of them**, or they drift out
## of phase within a minute and the lift stops being one piece of music getting louder.
const MUSIC_SECONDS: float = 8.0
## How far the second voice of each pair is pushed off the first. Three cents: slow enough that the
## beating reads as movement rather than as tuning, and small enough that it is still one note.
const DETUNE: float = 1.003
## The three layers, and what each is for. A **share of the pressure** rather than a threshold:
## `ground` is the sound of a fight happening at all, `pulse` arrives as the island fills, and
## `edge` only ever reaches full at the top. `from` and `to` are the pressure either side of the
## layer's own fade, so the three hand over rather than switching.
##
## The root is 55 Hz — A, low enough to sit under every partial in the game. Nothing here shares a
## frequency with the perfect signature at 1320 Hz or with any wind-up, which is the whole reason a
## music bed is allowed to exist during a fight.
const LAYERS: Dictionary = {
	&"music_ground": {"root": 55.0, "voices": 2, "from": 0.0, "to": 0.15, "swells": 2},
	&"music_pulse": {"root": 82.5, "voices": 3, "from": 0.2, "to": 0.55, "swells": 5},
	&"music_edge": {"root": 220.0, "voices": 4, "from": 0.6, "to": 0.95, "swells": 8},
}
## How much of the bed's tail is folded back over its head to make the seam. A loop assembled from
## noise has no natural join; this is what stops the wrap being an audible tick every few seconds.
const SURF_SEAM: float = 0.25

var _sounds: Dictionary = {}
var _peaks: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _placed: Array[AudioStreamPlayer3D] = []
var _bed: AudioStreamPlayer = null
var _noise := RandomNumberGenerator.new()
var _health_seen: float = -1.0


func _ready() -> void:
	# Hitstop drives Engine.time_scale to a fifth. Audio does not run on that clock, but the pool
	# must not be paused by a menu either — a sound cut off mid-ring reads as a bug in the fight.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	for _index: int in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"SFX"
		add_child(voice)
		_voices.append(voice)
	for _index: int in POSITIONAL_VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.bus = &"SFX"
		# Inverse rather than inverse-square: the square law is what silences a farmer ten metres
		# behind the player, and ten metres behind the player is exactly where he matters.
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		voice.max_distance = REACH
		voice.unit_size = 8.0
		add_child(voice)
		_placed.append(voice)
	_start_the_bed()
	EventBus.attack_landed.connect(_on_attack_landed)
	EventBus.attack_whiffed.connect(_on_attack_whiffed)
	EventBus.parry_perfect.connect(_on_parry_perfect)
	EventBus.parry_late.connect(_on_parry_late)
	EventBus.footstep_taken.connect(_on_footstep_taken)
	EventBus.telegraph_began.connect(_on_telegraph_began)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.player_state_changed.connect(_on_player_state_changed)
	EventBus.weapon_found.connect(_on_weapon_found)
	EventBus.weapon_reloaded.connect(_on_weapon_reloaded)
	EventBus.weapon_dry_fired.connect(_on_weapon_dry_fired)
	EventBus.weapon_fired.connect(_on_weapon_fired)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.merchant_opened.connect(_on_merchant_opened)
	EventBus.run_ended.connect(_on_run_ended)


## The bed is the one sound still going when the game is asked to close, and a stream left playing
## at teardown is two objects the engine reports as leaked on the way out. Nothing about it is
## visible in the game; it is visible in CI, which fails the boot on any warning at all — which is
## exactly what a leak check is for.
func _exit_tree() -> void:
	if _bed == null:
		return
	_bed.stop()
	_bed.stream = null


## Plays a sound flat, in front of the player. Unknown ids are ignored rather than pushed as an
## error: a caller asking for a sound that does not exist yet should go quiet, not spam the log for
## the rest of the run.
func play(id: StringName, jitter: float = 0.0) -> void:
	var stream: AudioStreamWAV = _sounds.get(id)
	if stream == null:
		return
	var voice := _free_voice()
	if voice == null:
		return
	voice.stream = stream
	voice.pitch_scale = 1.0 + _noise.randf_range(-jitter, jitter)
	voice.play()


## The same, from a point in the world. What this buys over `play` is the only thing that makes a
## crowd answerable: a player who cannot see the farmer winding up behind them can still hear which
## side he is on.
func play_at(id: StringName, where: Vector3, jitter: float = 0.0) -> void:
	var stream: AudioStreamWAV = _sounds.get(id)
	if stream == null:
		return
	var voice := _free_positional_voice()
	if voice == null:
		return
	voice.stream = stream
	voice.global_position = where
	voice.pitch_scale = 1.0 + _noise.randf_range(-jitter, jitter)
	voice.play()


## The baked waveform, for anything that wants to measure rather than hear it.
func sound(id: StringName) -> AudioStreamWAV:
	return _sounds.get(id)


## What peak a sound was normalised to. The mix is a decision, so it is readable rather than
## implied: a check can assert that a footfall sits under a hit without anybody having to listen.
func peak_of(id: StringName) -> float:
	return float(_peaks.get(id, 0.0))


## The looping bed, for a check that wants to know it is running rather than hear it.
func bed() -> AudioStreamPlayer:
	return _bed


## The oldest voice is not reused while it is still ringing — a perfect parry cut short by the next
## jab is the one sound in the game that must never be.
func _free_voice() -> AudioStreamPlayer:
	for voice: AudioStreamPlayer in _voices:
		if not voice.playing:
			return voice
	return null


func _free_positional_voice() -> AudioStreamPlayer3D:
	for voice: AudioStreamPlayer3D in _placed:
		if not voice.playing:
			return voice
	return null


func _build() -> void:
	_register(&"hit", _hit(BASE_IMPACT, false), PEAK)
	_register(&"perfect", _hit(BASE_IMPACT, true), PEAK)
	for family: StringName in IMPACTS:
		if family == BASE_IMPACT:
			continue
		_register(StringName("hit_%s" % family), _hit(family, false), PEAK)
		_register(StringName("perfect_%s" % family), _hit(family, true), PEAK)
	for archetype: StringName in TELEGRAPHS:
		if archetype == BASE_TELEGRAPH:
			continue
		_register(StringName("telegraph_%s" % archetype), _telegraph_of(archetype), TELEGRAPH_PEAK)
	_register(&"low_ammo", _low_ammo(), INCIDENTAL_PEAK)
	_register(&"whiff", _whiff(), WHIFF_PEAK)
	_register(&"shot", _shot(false), PEAK)
	_register(&"shot_heavy", _shot(true), PEAK)
	_register(&"parry_perfect", _parry(true), PEAK)
	_register(&"parry_late", _parry(false), PEAK)
	_register(&"step_sand", _step(false), FOOTFALL_PEAK)
	_register(&"step_water", _step(true), FOOTFALL_PEAK)
	_register(&"roll", _roll(), FOOTFALL_PEAK)
	_register(&"reload", _reload(), INCIDENTAL_PEAK)
	_register(&"dry_fire", _dry_fire(), INCIDENTAL_PEAK)
	_register(&"hurt", _hurt(), INCIDENTAL_PEAK)
	_register(&"enemy_down", _enemy_down(), INCIDENTAL_PEAK)
	_register(&"pickup", _pickup(), INCIDENTAL_PEAK)
	_register(&"telegraph", _telegraph(), TELEGRAPH_PEAK)
	_register(&"wave_cleared", _sting(), STING_PEAK)
	_register(&"merchant", _merchant(), INCIDENTAL_PEAK)
	_register(&"victory", _ending(true), STING_PEAK)
	_register(&"defeat", _ending(false), STING_PEAK)
	_register(&"surf", _surf(), SURF_PEAK)
	for layer: StringName in LAYERS:
		_register(layer, _layer(layer), MUSIC_PEAK)


func _register(id: StringName, stream: AudioStreamWAV, peak: float) -> void:
	_sounds[id] = stream
	_peaks[id] = peak


## A thud and a snap of contact. The perfect one adds a partial that outlasts both by a quarter of
## a second — the tail is what the ear keys on when the eye is elsewhere.
##
## **The body is the weapon; the ring is the timing.** A fist, a stick and a round do not land
## alike, so each family gets its own body — a different pitch, a different amount of contact, a
## different length. What they must never differ in is the **partial the perfect window adds**: that
## one is the signature, it is the same 1320 Hz in all of them, and a player who learns it on fists
## has learnt it on the gun. Three signatures would be three things to learn in the half second
## there is.
##
## Nothing here differs by loudness. All six normalise to the same peak, for the reason the whole
## family exists: loudness is the first thing a player turns down and the first thing a busy fight
## buries.
func _hit(family: StringName, perfect: bool) -> AudioStreamWAV:
	var voice: Dictionary = IMPACTS.get(family, IMPACTS[BASE_IMPACT])
	var body := float(voice["decay"])
	var samples := _silence(maxf(PERFECT_RING if perfect else 0.0, body))
	_tone(samples, float(voice["hertz"]), 0.9, body)
	_hiss(samples, float(voice["contact"]), float(voice["snap"]), int(voice["grain"]))
	if perfect:
		_tone(samples, PERFECT_PARTIAL, 0.38, PERFECT_RING)
		_tone(samples, PERFECT_PARTIAL * 1.5, 0.16, 0.10)
	return _bake(samples, PEAK)


## A swing through air: something **passing**, not something failing to arrive.
##
## No transient at all, and that is the point — nothing was struck, so nothing snaps. What it does
## have is a shape: dark noise that swells, peaks in the middle and falls away. That is the whole
## difference between a swish and a wash of hiss, and it is why the level rises and falls rather
## than merely decaying. A sound that starts at its loudest is a sound that started with contact.
##
## Two things it deliberately is not. It is **not as loud as a hit** — a miss is the least
## interesting thing that can happen in a fight, and it used to come out at the same peak as a
## landed blow. And it is **not half a second long**: a decay of 0.09 ran the buffer six time
## constants deep, so every missed jab washed for 540 ms over the top of whatever came next. Air
## moves past in a sixth of a second.
func _whiff() -> AudioStreamWAV:
	var samples := _span(0.17)
	_hiss(samples, 0.9, INF, 23)
	# Twice, at different weights. One pass leaves white noise sounding like escaping steam; the
	# second takes the top off it, and what is left reads as air rather than as a hiss.
	_soften(samples, 0.14)
	_soften(samples, 0.40)
	_swell(samples, 0.055)
	_release(samples, 0.09)
	return _bake(samples, WHIFF_PEAK)


## The report. A crack and a body, both very short, and nothing that rings: what makes a gunshot a
## gunshot is that it is over before the ear has finished deciding what it was.
##
## The charged shot is the same report an octave lower and longer — one report scaled rather than
## two waveforms, because what differs between the gun's three attacks is weight, not identity.
func _shot(heavy: bool) -> AudioStreamWAV:
	var samples := _silence(0.09 if heavy else 0.05)
	_hiss(samples, 0.9, 0.012 if heavy else 0.006, 71)
	_tone(samples, 70.0 if heavy else 120.0, 0.8, 0.09 if heavy else 0.05)
	_soften(samples, 0.45 if heavy else 0.65)
	return _bake(samples, PEAK)


## A bell. The perfect one rings for half a second on three partials; the late one is the same bell
## damped — one partial, a fifth of the length. Same voice, and the difference is all in the tail.
func _parry(perfect: bool) -> AudioStreamWAV:
	var samples := _silence(0.30 if perfect else 0.055)
	_hiss(samples, 0.8 if perfect else 0.4, 0.008, 37)
	if perfect:
		_tone(samples, 880.0, 0.40, 0.30)
		_tone(samples, 1318.0, 0.25, 0.24)
		_tone(samples, 2640.0, 0.12, 0.14)
		return _bake(samples, PEAK)
	_tone(samples, 440.0, 0.25, 0.055)
	return _bake(samples, PEAK)


## A foot in sand, and a foot in the surf. Both are noise and neither has a pitch: sand is a scuff
## with the top taken off it, and water is the same scuff wetter, brighter and twice as long, with
## the swell that makes it read as something displaced rather than something struck.
##
## Deliberately the quietest things in the game. The player walks for six minutes a wave, and a
## footfall that competes with the fight is a footfall that hides it.
func _step(wading: bool) -> AudioStreamWAV:
	if not wading:
		var sand := _silence(0.014)
		_hiss(sand, 0.7, 0.014, 5)
		_soften(sand, 0.30)
		return _bake(sand, FOOTFALL_PEAK)
	var water := _silence(0.045)
	_hiss(water, 0.7, 0.045, 7)
	_soften(water, 0.55)
	_swell(water, 0.012)
	return _bake(water, FOOTFALL_PEAK)


## A roll: air, and then a body arriving. The swish alone would be a slower whiff, so the shoulder
## landing is in it — a low thump two thirds of the way through, which is the thing that separates
## going to ground from swinging at it.
##
## Its length is designed rather than derived. A decay of 0.16 ran the buffer most of a second,
## which is twice the roll itself and long enough to still be sounding when the player is back on
## their feet and swinging.
func _roll() -> AudioStreamWAV:
	var samples := _span(0.34)
	_hiss(samples, 0.9, INF, 29)
	_soften(samples, 0.10)
	_swell(samples, 0.10)
	_tone(samples, 110.0, 0.55, 0.05, 0.20)
	_release(samples, 0.08)
	return _bake(samples, FOOTFALL_PEAK)


## Two dry clacks, a magazine out and a magazine in. Nothing rings: it is the one sound in the game
## that is purely mechanical, and that is what separates it from everything that hits.
func _reload() -> AudioStreamWAV:
	var samples := _silence(0.008, 0.10)
	_hiss(samples, 0.8, 0.006, 41)
	_hiss(samples, 0.6, 0.008, 43, 0.10)
	_soften(samples, 0.75)
	return _bake(samples, INCIDENTAL_PEAK)


## The trigger on an empty magazine. One dead click and a stub of low body — the sound of a thing
## not happening, which is exactly what the player needs told: a press that produces nothing at all
## reads as a dropped input, and they blame the game rather than their own ammunition.
func _dry_fire() -> AudioStreamWAV:
	var samples := _silence(0.012)
	_hiss(samples, 0.7, 0.005, 47)
	_tone(samples, 210.0, 0.25, 0.012)
	_soften(samples, 0.8)
	return _bake(samples, INCIDENTAL_PEAK)


## Taking a hit. Lower and duller than landing one, and with the top rolled off: the player has to
## be able to tell, with the screen off, whether that thud was theirs or the farmer's.
func _hurt() -> AudioStreamWAV:
	var samples := _silence(0.055)
	_tone(samples, 88.0, 0.9, 0.055)
	_hiss(samples, 0.4, 0.022, 53)
	_soften(samples, 0.18)
	return _bake(samples, INCIDENTAL_PEAK)


## A body going down: a fall rather than an impact. The pitch drops away instead of ringing, which
## is the one shape in this whole set that nothing else uses — and it arrives from where the body
## was standing, so a kill behind the player still reads as a kill.
func _enemy_down() -> AudioStreamWAV:
	var samples := _span(0.34)
	_fall(samples, 340.0, 120.0, 0.7)
	_hiss(samples, 0.35, 0.05, 59)
	_soften(samples, 0.22)
	_release(samples, 0.14)
	return _bake(samples, INCIDENTAL_PEAK)


## Finding a weapon. Two notes going up, which is the shortest way a game has ever said *that one
## is yours now*.
func _pickup() -> AudioStreamWAV:
	var samples := _silence(0.10, 0.07)
	_tone(samples, 660.0, 0.5, 0.09)
	_tone(samples, 990.0, 0.45, 0.10, 0.07)
	return _bake(samples, INCIDENTAL_PEAK)


## **The most important sound in the game, and the only one that rises.**
##
## Everything else here decays, because everything else reports something that already happened. A
## telegraph reports something that has not happened yet, so it goes the other way: the pitch and
## the level both climb, and the ear reads a climb as a thing arriving. That is a categorical
## difference rather than a matter of degree, which is what lets it survive three farmers, a fight
## and a player who has turned the music up.
##
## It releases at the end rather than swelling into the cut, or the buffer would stop dead at full
## amplitude — and a telegraph that ends in a click is a telegraph the player flinches at twice.
func _telegraph() -> AudioStreamWAV:
	return _telegraph_of(&"")


## The same shape at an archetype's own pitch. One climb rather than three hand-built warnings,
## because what must be shared is that it *rises* — and what must differ is where from and to.
func _telegraph_of(archetype: StringName) -> AudioStreamWAV:
	var voice: Dictionary = TELEGRAPHS.get(archetype, TELEGRAPHS[BASE_TELEGRAPH])
	var samples := _span(float(voice["seconds"]))
	_climb(samples, float(voice["from"]), float(voice["to"]), 0.75)
	_hiss(samples, 0.16, 0.02, int(voice["grain"]))
	_release(samples, 0.07)
	return _bake(samples, TELEGRAPH_PEAK)


## The last round in the magazine. Two short clicks a semitone apart, dry and quiet: running out is
## a **designed** moment and the answer to it is to close on the next farmer, which is a decision
## the player has to be able to make before the trigger stops answering rather than after.
##
## Deliberately not a musical interval and deliberately under the shot that carried it — it arrives
## in the same breath as a gunshot and must not be mistaken for part of one.
func _low_ammo() -> AudioStreamWAV:
	var samples := _silence(0.05, 0.07)
	_tone(samples, 880.0, 0.6, 0.02)
	_tone(samples, 932.0, 0.6, 0.05, 0.07)
	_soften(samples, 0.30)
	return _bake(samples, INCIDENTAL_PEAK)


## A wave passed. Three notes up, and the only sound in the game allowed to be musical: it is the
## one moment nothing is trying to kill the player, so it is the one moment a chord costs nothing.
func _sting() -> AudioStreamWAV:
	var samples := _silence(0.42, 0.30)
	_tone(samples, 523.0, 0.5, 0.20)
	_tone(samples, 659.0, 0.5, 0.24, 0.15)
	_tone(samples, 784.0, 0.5, 0.42, 0.30)
	return _bake(samples, STING_PEAK)


## The counter opening. Two notes a fifth apart and nothing above them — quiet, warm and over
## quickly, because the merchant is a pause rather than an event and a sting here would tell the
## player something happened when what happened is that nothing is happening.
func _merchant() -> AudioStreamWAV:
	var samples := _silence(0.30, 0.09)
	_tone(samples, 392.0, 0.6, 0.22)
	_tone(samples, 587.0, 0.45, 0.30, 0.09)
	_soften(samples, 0.25)
	return _bake(samples, INCIDENTAL_PEAK)


## The end of a run, either way. **The same three notes in the same order**, and the whole
## difference is where they go: up for a victory, down for a death. One shape, two readings —
## a player does not have to learn two sounds to know which one they got, and a summary screen that
## arrives in silence reads as the game having crashed rather than ended.
func _ending(victory: bool) -> AudioStreamWAV:
	var notes: Array[float] = [523.0, 392.0, 262.0]
	if victory:
		notes = [392.0, 523.0, 784.0]
	var samples := _silence(ENDING_RING, ENDING_STEP * 2.0)
	for index: int in notes.size():
		var last := index == notes.size() - 1
		_tone(
			samples,
			notes[index],
			0.5,
			ENDING_RING if last else ENDING_STEP * 1.6,
			ENDING_STEP * float(index)
		)
	return _bake(samples, STING_PEAK)


## The surf, and nothing else. It is the only sound here with no event behind it, and the only one
## that loops.
##
## Two slow swells at frequencies that do not divide into each other, so the bed never settles into
## a rhythm the ear can count — a wave every three seconds is a metronome, and a metronome under a
## fight is worse than silence.
func _surf() -> AudioStreamWAV:
	var noise := _span(SURF_SECONDS + SURF_SEAM)
	_hiss(noise, 0.9, INF, 67)
	_soften(noise, 0.08)
	# Joined first, then breathed over what is left: the swells have to be whole across the buffer
	# that actually loops, not across the longer one the seam was cut out of.
	var samples := _join(noise)
	_breathe(samples, SURF_SWELLS, 0.55)
	_breathe(samples, SURF_SWELLS + 1, 0.30)
	return _bake_loop(samples, SURF_PEAK)


## One layer of the music: a chord that breathes, built on the same seam the surf uses.
##
## Detuned rather than in unison. Two sines a few cents apart beat slowly against each other, which
## is the difference between a drone that is a sound and a drone that is a test tone — and it is
## free, where a filter sweep would not be.
##
## **Nothing here is rhythmic in the sense a fight is.** The swells are slow and their counts do not
## divide into each other, for the reason the surf's do not: a bed the ear can count against is a
## metronome, and a metronome is a thing the player starts fighting to instead of reading.
func _layer(id: StringName) -> AudioStreamWAV:
	var voice: Dictionary = LAYERS[id]
	var samples := _span(MUSIC_SECONDS + SURF_SEAM)
	var root := float(voice["root"])
	for step: int in int(voice["voices"]):
		# A fifth above each time, which stacks without ever landing on a third — a bed with a mode
		# in it is a bed that has an opinion about the scene, and this one has to survive six
		# minutes of whatever the player is doing.
		var hertz := root * pow(1.5, float(step))
		_tone(samples, hertz, 0.7 / float(step + 1), INF)
		_tone(samples, hertz * DETUNE, 0.7 / float(step + 1), INF)
	var looped := _join(samples)
	_breathe(looped, int(voice["swells"]), 0.45)
	_breathe(looped, int(voice["swells"]) + 1, 0.2)
	return _bake_loop(looped, MUSIC_PEAK)


## Sized from the slowest decay the sound is about to use, and from how late the last of it starts,
## so nothing is ever cut off mid-ring.
func _silence(slowest_decay: float, last_starts_at: float = 0.0) -> PackedFloat32Array:
	return _span(last_starts_at + slowest_decay * DECAYED)


## A buffer of exactly this many seconds, for the sounds whose length is designed rather than
## derived from a decay — a telegraph is as long as the warning needs to be.
func _span(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(maxi(int(seconds * float(MIX_RATE)), 2))
	return samples


## A decaying sine, added in. `decay` is the time constant, so the partial is down to a thirtieth of
## itself after three of them. `at` is when it starts, for the sounds that are two notes rather than
## a chord.
func _tone(
	samples: PackedFloat32Array, hertz: float, amplitude: float, decay: float, at: float = 0.0
) -> void:
	var step := TAU * hertz / float(MIX_RATE)
	var from := mini(int(at * float(MIX_RATE)), samples.size())
	for index: int in range(from, samples.size()):
		var seconds := float(index - from) / float(MIX_RATE)
		samples[index] += sin(step * float(index - from)) * amplitude * exp(-seconds / decay)


## Decaying noise, from a seeded source so the waveform is the same on every machine and every run.
## A signature that is regenerated differently each launch is not a signature. An infinite decay is
## noise that never falls away, which is what a bed is made of.
func _hiss(
	samples: PackedFloat32Array, amplitude: float, decay: float, seed_value: int, at: float = 0.0
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var from := mini(int(at * float(MIX_RATE)), samples.size())
	for index: int in range(from, samples.size()):
		var seconds := float(index - from) / float(MIX_RATE)
		samples[index] += rng.randf_range(-1.0, 1.0) * amplitude * exp(-seconds / decay)


## A sine whose pitch climbs across the whole buffer while its level climbs with it. The phase is
## carried rather than recomputed from the index: a frequency that changes means the angle has to be
## integrated, and `sin(t × f(t))` is a different and much worse sound than a sweep.
func _climb(
	samples: PackedFloat32Array, from_hertz: float, to_hertz: float, amplitude: float
) -> void:
	var phase := 0.0
	var last := float(maxi(samples.size() - 1, 1))
	for index: int in samples.size():
		var through := float(index) / last
		phase += TAU * lerpf(from_hertz, to_hertz, through) / float(MIX_RATE)
		samples[index] += sin(phase) * amplitude * through


## The same, going down and fading out — a fall rather than an arrival.
func _fall(
	samples: PackedFloat32Array, from_hertz: float, to_hertz: float, amplitude: float
) -> void:
	var phase := 0.0
	var last := float(maxi(samples.size() - 1, 1))
	for index: int in samples.size():
		var through := float(index) / last
		phase += TAU * lerpf(from_hertz, to_hertz, through) / float(MIX_RATE)
		samples[index] += sin(phase) * amplitude * (1.0 - through)


## A one-pole low pass, run once over the buffer. Enough to turn white noise into air.
func _soften(samples: PackedFloat32Array, weight: float) -> void:
	var carried := 0.0
	for index: int in samples.size():
		carried += (samples[index] - carried) * weight
		samples[index] = carried


## Fades a sound in over its first stretch, which is what makes noise read as a swing passing rather
## than as something being hit.
func _swell(samples: PackedFloat32Array, seconds: float) -> void:
	var over := maxi(int(seconds * float(MIX_RATE)), 1)
	for index: int in mini(over, samples.size()):
		samples[index] *= float(index) / float(over)


## Fades a sound out over its last stretch. The mirror of `_swell`, and what a sound that rises has
## to end with: a buffer that stops at full amplitude does not finish, it is interrupted.
##
## **Squared, where the swell is linear.** A linear fade is still at a fiftieth of full a couple of
## milliseconds from the end, which is audible as a stop — and it is exactly what the cut-off check
## measures, because a tail that is still there when the buffer runs out is a tail that was cut. The
## square drops the last two milliseconds to well under a thousandth while leaving the shape of the
## fade, which the ear reads, untouched.
func _release(samples: PackedFloat32Array, seconds: float) -> void:
	var over := maxi(int(seconds * float(MIX_RATE)), 1)
	var last := samples.size() - 1
	for index: int in mini(over, samples.size()):
		var through := float(index) / float(over)
		samples[last - index] *= through * through


## A slow rise and fall across the whole buffer, counted in whole swells rather than in hertz. This
## is what turns a flat hiss into water: the noise does not change, the amount of it does.
##
## **Whole cycles, which is why the count is an integer.** A fractional swell would leave the bed at
## a different level from the one it started at, and the seam would then have to hide a step in
## volume as well as a step in the noise — which is the one thing a cross-fade cannot do.
func _breathe(samples: PackedFloat32Array, swells: int, depth: float) -> void:
	var last := float(maxi(samples.size() - 1, 1))
	var turns := float(maxi(swells, 1))
	for index: int in samples.size():
		var through := float(index) / last
		samples[index] *= 1.0 - depth + depth * (0.5 - 0.5 * cos(TAU * turns * through))


## Ramped off the zero line, normalised to the peak it was asked for, and packed to 16-bit.
## Normalising rather than trusting the sum is what keeps a fourth partial from silently clipping
## the other three; asking for a peak rather than sharing one is what keeps a footfall under a hit.
##
## **The ramp goes on before the peak is measured, not after.** A short sound is loudest within a
## millisecond or two of starting — a dry click is nothing else — so a ramp applied afterwards eats
## the very sample the normalisation was aimed at, and the sound comes out well under what it asked
## for. The dry trigger landed at 0.33 against the 0.55 it declared, which is how a mix that was
## written down as a table stops being the mix that plays.
func _bake(samples: PackedFloat32Array, peak: float) -> AudioStreamWAV:
	var ramp := maxi(int(RAMP * float(MIX_RATE)), 1)
	var last := samples.size() - 1
	for index: int in mini(ramp, samples.size()):
		samples[index] *= float(index) / float(ramp)
		samples[last - index] *= float(index) / float(ramp)
	return _wav(_encode(samples, samples.size(), _scale_to(samples, peak)), false)


## The same, for the one sound that comes back round.
##
## **A loop may not be ramped.** The two millisecond fade that stops a one-shot clicking is, on a
## loop, a hole punched in the bed every time it wraps — so there is no ramp here at all, and the
## join is made by `_join` before anything is shaped.
func _bake_loop(samples: PackedFloat32Array, peak: float) -> AudioStreamWAV:
	return _wav(_encode(samples, samples.size(), _scale_to(samples, peak)), true)


## Folds a buffer's tail back over its head and returns it short by exactly that much, so the result
## meets itself where it wraps. Noise has no natural join; this makes one.
##
## **It has to run before the envelope, not after.** Shaping first and cutting second was the first
## version and it left a seam 33% apart in level: whole swells across the *whole* buffer are not
## whole swells across what is kept, so the bed came back round to a different point in its own
## breathing. Join the noise, then breathe over what survived.
func _join(samples: PackedFloat32Array) -> PackedFloat32Array:
	var seam := mini(maxi(int(SURF_SEAM * float(MIX_RATE)), 1), samples.size() / 2)
	var kept := samples.size() - seam
	for index: int in seam:
		var through := float(index) / float(seam)
		samples[index] = samples[index] * through + samples[kept + index] * (1.0 - through)
	samples.resize(kept)
	return samples


func _encode(samples: PackedFloat32Array, count: int, scale: float) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for index: int in count:
		bytes.encode_s16(index * 2, int(clampf(samples[index] * scale, -1.0, 1.0) * 32767.0))
	return bytes


func _scale_to(samples: PackedFloat32Array, peak: float) -> float:
	var loudest := 0.0
	for value: float in samples:
		loudest = maxf(loudest, absf(value))
	return peak / loudest if loudest > 0.0 else 0.0


func _wav(bytes: PackedByteArray, looping: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = bytes.size() / 2 - 1
	return stream


## The bed starts with the game and never stops. On its own bus, so a player who wants the island
## quiet and the fight loud has a slider that does exactly that.
##
## **Except where there is nobody to hear it.** A headless run has no audio output, and a stream
## still playing when the engine tears down is two objects it reports as leaked — the audio server
## releases a playback on its next iteration, and at quit there is no next iteration. That is
## engine behaviour and it is not specific to a loop; it is simply guaranteed by one, because a bed
## is playing at every moment including the last. CI fails a boot on any warning at all, and the
## right answer is to leave the gate alone rather than to teach it to ignore a real leak.
##
## The waveform is still built and still assigned, so the loop, its seam and its length are exactly
## as checkable headless as everything else here. The only thing skipped is the playing.
func _start_the_bed() -> void:
	_bed = AudioStreamPlayer.new()
	_bed.bus = &"Ambience"
	_bed.stream = sound(&"surf")
	add_child(_bed)
	if DisplayServer.get_name() != "headless":
		_bed.play()


## The family the attack names, or the generic thud when it names none. The perfect one never gets
## jitter: a signature that moves is not one, and that holds for all three families.
func _on_attack_landed(_target: Node3D, _damage: float, perfect: bool, attack: AttackData) -> void:
	var family := attack.impact_sound if attack != null else &""
	var id := StringName("%s_%s" % ["perfect" if perfect else "hit", family])
	if not _sounds.has(id):
		id = &"perfect" if perfect else &"hit"
	play(id, 0.0 if perfect else JITTER)


## Only a weapon that moves through air makes the sound of moving through air. A shot that found
## nobody has already been heard — it cracked when the round left — and following it with a swish
## was the gun swinging an arm it does not have.
func _on_attack_whiffed(attack: AttackData) -> void:
	if attack != null and attack.is_hitscan:
		return
	play(&"whiff", SWING_JITTER)


## The report, and — on the round that leaves one behind — the warning. Running dry is a designed
## moment, and a player who only learns about it when the trigger stops answering has been told
## about it one round too late to do anything with it.
func _on_weapon_fired(attack: AttackData) -> void:
	if attack == null:
		return
	play(&"shot_heavy" if attack.charges else &"shot", JITTER)
	if GameState.loadout != null and GameState.loadout.magazine == LAST_ROUNDS:
		play(&"low_ammo")


func _on_parry_perfect() -> void:
	play(&"parry_perfect")


func _on_parry_late() -> void:
	play(&"parry_late")


func _on_footstep_taken(wading: bool) -> void:
	play(&"step_water" if wading else &"step_sand", STEP_JITTER)


## From where he is standing, and pitched a little differently each time. Three farmers committing
## together on one waveform would arrive as a single louder farmer, which is the opposite of what
## the sound is for.
func _on_merchant_opened() -> void:
	play(&"merchant")


func _on_run_ended(victory: bool) -> void:
	play(&"victory" if victory else &"defeat")


func _on_telegraph_began(where: Vector3, archetype: EnemyData) -> void:
	var id := archetype.telegraph_sound if archetype != null else &""
	play_at(id if _sounds.has(id) else &"telegraph", where, JITTER)


func _on_enemy_died(enemy: Node3D, _archetype: StringName, _money: int) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	play_at(&"enemy_down", enemy.global_position, JITTER)


## The bus carries the health that resulted, so a drop is what a hit looks like from here — and a
## heal at the merchant must not sound like one. The same comparison the wave director makes to
## decide whether a wave was flawless.
func _on_player_damaged(current: float, _maximum: float) -> void:
	var dropped := _health_seen >= 0.0 and current < _health_seen
	_health_seen = current
	if dropped:
		play(&"hurt", JITTER)


## A roll and a reload are states, and the bus already says when the player enters one — the signal
## exists for exactly this. Cheaper than two more signals, and it cannot drift out of step with the
## animation, because it *is* the transition the animation plays.
func _on_player_state_changed(state: StringName) -> void:
	if state == &"Dodge":
		play(&"roll", JITTER)


func _on_weapon_found(_id: StringName) -> void:
	play(&"pickup")


func _on_weapon_reloaded() -> void:
	play(&"reload", JITTER)


func _on_weapon_dry_fired() -> void:
	play(&"dry_fire", JITTER)


func _on_wave_cleared(_wave: int, _reward: int) -> void:
	play(&"wave_cleared")
