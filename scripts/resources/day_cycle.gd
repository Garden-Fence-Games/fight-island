class_name DayCycle
extends Resource
## One wave is one turn of the day: it opens in daylight, the sun goes down partway through, and
## the player finishes it in the dark. Clear the night and the wave is passed.
##
## Measuring it in seconds rather than in waves is what makes the wave itself a ramp. The player
## does not face a wave that is uniformly harder than the last one; they face a wave that gets
## harder while they are standing in it, and they can see it coming — the light tells them.
##
## The phases run in order and add up to the wave, so the array is the whole design: its total is
## how long a wave lasts, and where night sits in it is when night falls.

const HOURS_IN_A_DAY: float = 24.0
## What a phase turns over when it does not say. Each phase carries its own `turning_share`, because
## how long a look should slide is a fact about that look — a day holds and a dusk does not.
const TURNING_SHARE: float = 0.25

@export var phases: Array[DayPhase] = []


## How long a wave lasts.
func wave_seconds() -> float:
	var total := 0.0
	for phase: DayPhase in phases:
		if phase != null:
			total += maxf(phase.seconds, 0.0)
	return total


## Whose rules are in force this far into the wave, or null when nothing has been configured —
## which is what lets an arena with no cycle play exactly as it did before one existed.
func phase_at(seconds: float) -> DayPhase:
	var span := wave_seconds()
	if span <= 0.0:
		return null
	var into := fposmod(seconds, span)
	for phase: DayPhase in phases:
		if phase == null:
			continue
		if into < maxf(phase.seconds, 0.0):
			return phase
		into -= maxf(phase.seconds, 0.0)
	return null


## What the clock reads. Exact at both ends of every phase, so the face and the sky never disagree
## about the moment night falls.
func hour_at(seconds: float) -> float:
	var span := wave_seconds()
	if span <= 0.0:
		return 0.0
	var into := fposmod(seconds, span)
	for phase: DayPhase in phases:
		if phase == null:
			continue
		var lasts := maxf(phase.seconds, 0.0)
		if into < lasts and lasts > 0.0:
			var walked := into / lasts
			return fposmod(phase.starts_at_hour + hours_of(phase) * walked, HOURS_IN_A_DAY)
		into -= lasts
	return 0.0


## Nought while a phase holds its look, rising to one at the moment it hands over.
func turn_amount(seconds: float) -> float:
	var phase := phase_at(seconds)
	if phase == null or phase.seconds <= 0.0:
		return 0.0
	var span := wave_seconds()
	var into := fposmod(seconds - _opens_at(phase), span)
	var window := phase.seconds * _turning_share_of(phase)
	if window <= 0.0:
		return 0.0
	var holds_until := phase.seconds - window
	if into <= holds_until:
		return 0.0
	return clampf((into - holds_until) / window, 0.0, 1.0)


## What share of a phase is a turn, from the phase itself. Falls back to the constant so a resource
## written before phases carried one still behaves the way it did.
func _turning_share_of(phase: DayPhase) -> float:
	var share: float = phase.get("turning_share")
	return share if share > 0.0 else TURNING_SHARE


## The phase a look is turning into.
func after(phase: DayPhase) -> DayPhase:
	if phase == null or phases.is_empty():
		return null
	var found := phases.find(phase)
	if found < 0:
		return null
	for step: int in phases.size():
		var next: DayPhase = phases[(found + 1 + step) % phases.size()]
		if next != null:
			return next
	return null


## How many hours a phase covers: from its own opening hour to the next one's.
func hours_of(phase: DayPhase) -> float:
	var next := after(phase)
	if phase == null or next == null or next == phase:
		return HOURS_IN_A_DAY
	return fposmod(next.starts_at_hour - phase.starts_at_hour, HOURS_IN_A_DAY)


func _opens_at(phase: DayPhase) -> float:
	var opens := 0.0
	for other: DayPhase in phases:
		if other == phase:
			return opens
		if other != null:
			opens += maxf(other.seconds, 0.0)
	return 0.0
