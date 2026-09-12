extends Node
## Every sound the fight makes, synthesised at startup rather than shipped as files.
##
## The subject of this game is timing, and the eye is on the enemy — not on the player, and not on
## the flash around their own fist. **A perfect hit has to be recognisable with the screen off.**
## That is what these are for, and it is why they are here before any audio asset exists: a wave
## lasts six minutes, and a window the player can only see is a window they will miss.
##
## The five sounds are one family with one idea in it: **the ring is the reward.** A normal hit is a
## thud that stops. A perfect hit is the same thud with a bright partial that keeps going. A late
## parry is a dull short version of the perfect parry's bell. Nothing differs by loudness alone,
## because loudness is the first thing a player turns down and the first thing a busy fight buries.
##
## Baked into `AudioStreamWAV` once, not pushed through an `AudioStreamGenerator` frame by frame: a
## one-shot does not want a live synthesiser it can starve, and a waveform built once is a waveform
## that sounds the same every time — which is the whole point of a signature.

## Enough for a thud and a ring; the highest partial here is under 3 kHz. Halving the rate halves
## the bytes and changes nothing anybody can hear.
const MIX_RATE: int = 22050
## How many sounds may overlap. A chain into a parry into a hit is three, and a crowd adds no more
## because only the player's own timing is voiced.
const VOICES: int = 8
## Sine partials are summed, so a raw buffer can pass one. Everything is scaled to this afterwards
## rather than hoping.
const PEAK: float = 0.9
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
## Small random pitch on repeated sounds, so a chain does not sound like a machine. The perfect hit
## and both parries are left alone: a signature that moves is not one.
const JITTER: float = 0.04

var _sounds: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _noise := RandomNumberGenerator.new()


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
	EventBus.attack_landed.connect(_on_attack_landed)
	EventBus.attack_whiffed.connect(_on_attack_whiffed)
	EventBus.parry_perfect.connect(_on_parry_perfect)
	EventBus.parry_late.connect(_on_parry_late)


## Plays one of the five. Unknown ids are ignored rather than pushed as an error: a caller asking
## for a sound that does not exist yet should go quiet, not spam the log for the rest of the run.
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


## The baked waveform, for anything that wants to measure rather than hear it.
func sound(id: StringName) -> AudioStreamWAV:
	return _sounds.get(id)


## The oldest voice is not reused while it is still ringing — a perfect parry cut short by the next
## jab is the one sound in the game that must never be.
func _free_voice() -> AudioStreamPlayer:
	for voice: AudioStreamPlayer in _voices:
		if not voice.playing:
			return voice
	return null


func _build() -> void:
	_sounds[&"hit"] = _hit(false)
	_sounds[&"perfect"] = _hit(true)
	_sounds[&"whiff"] = _whiff()
	_sounds[&"parry_perfect"] = _parry(true)
	_sounds[&"parry_late"] = _parry(false)


## A thud and a snap of contact. The perfect one adds a partial that outlasts both by a quarter of
## a second — the tail is what the ear keys on when the eye is elsewhere.
func _hit(perfect: bool) -> AudioStreamWAV:
	var ring := 0.13
	var samples := _silence(ring if perfect else BODY_DECAY)
	_tone(samples, 150.0, 0.9, BODY_DECAY)
	_hiss(samples, 0.5, 0.018, 11)
	if perfect:
		_tone(samples, 1320.0, 0.38, ring)
		_tone(samples, 1980.0, 0.16, 0.10)
	return _bake(samples)


## No transient at all, and that is the point: nothing was struck, so nothing snaps. Filtered noise
## falling away, which reads as air rather than as contact.
func _whiff() -> AudioStreamWAV:
	var samples := _silence(0.09)
	_hiss(samples, 0.30, 0.09, 23)
	_soften(samples, 0.25)
	_swell(samples, 0.06)
	return _bake(samples)


## A bell. The perfect one rings for half a second on three partials; the late one is the same bell
## damped — one partial, a fifth of the length. Same voice, and the difference is all in the tail.
func _parry(perfect: bool) -> AudioStreamWAV:
	var samples := _silence(0.30 if perfect else 0.055)
	_hiss(samples, 0.8 if perfect else 0.4, 0.008, 37)
	if perfect:
		_tone(samples, 880.0, 0.40, 0.30)
		_tone(samples, 1318.0, 0.25, 0.24)
		_tone(samples, 2640.0, 0.12, 0.14)
		return _bake(samples)
	_tone(samples, 440.0, 0.25, 0.055)
	return _bake(samples)


## Sized from the slowest decay the sound is about to use, so nothing is ever cut off mid-ring.
func _silence(slowest_decay: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(slowest_decay * DECAYED * float(MIX_RATE)))
	return samples


## A decaying sine, added in. `decay` is the time constant, so the partial is down to a thirtieth of
## itself after three of them.
func _tone(samples: PackedFloat32Array, hertz: float, amplitude: float, decay: float) -> void:
	var step := TAU * hertz / float(MIX_RATE)
	for index: int in samples.size():
		var seconds := float(index) / float(MIX_RATE)
		samples[index] += sin(step * float(index)) * amplitude * exp(-seconds / decay)


## Decaying noise, from a seeded source so the waveform is the same on every machine and every run.
## A signature that is regenerated differently each launch is not a signature.
func _hiss(samples: PackedFloat32Array, amplitude: float, decay: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index: int in samples.size():
		var seconds := float(index) / float(MIX_RATE)
		samples[index] += rng.randf_range(-1.0, 1.0) * amplitude * exp(-seconds / decay)


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


## Normalised to a fixed peak, ramped off the zero line, and packed to 16-bit. Normalising rather
## than trusting the sum is what keeps a fourth partial from silently clipping the other three.
func _bake(samples: PackedFloat32Array) -> AudioStreamWAV:
	var loudest := 0.0
	for value: float in samples:
		loudest = maxf(loudest, absf(value))
	var scale := PEAK / loudest if loudest > 0.0 else 0.0
	var ramp := maxi(int(RAMP * float(MIX_RATE)), 1)
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	var last := samples.size() - 1
	for index: int in samples.size():
		var value := samples[index] * scale
		if index < ramp:
			value *= float(index) / float(ramp)
		if last - index < ramp:
			value *= float(last - index) / float(ramp)
		bytes.encode_s16(index * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream


func _on_attack_landed(_target: Node3D, _damage: float, perfect: bool) -> void:
	play(&"perfect" if perfect else &"hit", 0.0 if perfect else JITTER)


func _on_attack_whiffed(_attack: AttackData) -> void:
	play(&"whiff", JITTER)


func _on_parry_perfect() -> void:
	play(&"parry_perfect")


func _on_parry_late() -> void:
	play(&"parry_late")
