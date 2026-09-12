extends Node
## Cross-cutting signals only, and no state. Exists so the HUD, audio and telemetry can listen to
## combat without anything holding a reference to them. A component talking to its own owner uses
## a signal on the component instead.
##
## It has one piece of behaviour, and only because it is the one node that sees every event in every
## scene: it notices which device the player just used and says so. The **answer** is kept by
## `Devices`, not here, so the no-state rule still holds — this is the noticing, not the knowing.

signal player_damaged(current: float, maximum: float)
signal player_died
signal stamina_changed(current: float, maximum: float)
## The attack rides along because a blow's *sound* belongs to the weapon that threw it, the way its
## burst already belongs to the `AttackData` that names it. Five of the six listeners ignore it; the
## one that does not would otherwise have to ask the bag what is in hand at the moment of contact,
## and a swap during a swing would make that a lie.
signal attack_landed(target: Node3D, damage: float, perfect: bool, attack: AttackData)
## A swing whose active window closed without touching anything. It carries the attack because what
## a whiff sounds like depends on what was swung, and because nothing else can reconstruct it once
## the state has moved on.
signal attack_whiffed(attack: AttackData)
signal parry_perfect
signal parry_late
## A foot went down, and whether it went down in water. Carried because the surf and the sand are
## two sounds, and the only thing that knows which is the body that just covered the ground.
signal footstep_taken(wading: bool)
## A farmer has begun committing, and where he is standing. **The position is the whole point**: a
## wind-up the player cannot see is the one they most need to hear, so this is the one sound in the
## game that has to arrive from a direction. It carries a point rather than the body, because by the
## time a listener acts on it the only thing it needs is where to put the voice.
## The archetype rides along for the same reason. A reaper's wind-up and a thrower's must not sound
## alike: the thrower is the one the player cannot see coming, and sound is the only warning the
## design gives them.
signal telegraph_began(where: Vector3, archetype: EnemyData)
signal enemy_spawned(enemy: Node3D)
## The archetype travels with the death because the tally outlives the node that carried it.
signal enemy_died(enemy: Node3D, archetype: StringName, money: int)
signal hitstop_requested(duration: float)
## The camera should be knocked, and by how much. A request rather than an order: the camera scales
## it by the player's own setting, and a player who has turned shake off is not asking for less of
## it, they are asking for none.
signal shake_requested(strength: float)
## A wave has begun, and how many bodies it will send in total.
## The counter is open. The one moment in a run where nothing is trying to kill the player, and it
## had no sound at all — a screen arriving in silence reads as the game having stopped rather than
## as the fight having paused.
signal merchant_opened
## The run is over, and which way. Separate from `player_died` because a victory and a death are the
## same screen and the opposite feeling, and the only thing that can say so is a sound.
signal run_ended(victory: bool)
signal wave_started(wave: int, enemies: int)
## The last of them is down. The reward travels with it so the economy can stay a listener rather
## than something the director has to know about.
signal wave_cleared(wave: int, reward: int)
## The player has finished a chain and cannot attack for `seconds`. Presentation exists because of
## this pair: a wait nobody can see reads as a dropped input, and the player blames the game — and
## they are right to, because nothing told them.
signal chain_spent(seconds: float)
signal chain_ready
signal weapon_equipped(weapon: WeaponData)
## A weapon was picked up for the first time. Distinct from equipping it, because finding the gun is
## a moment and putting it back in your hands is not.
signal weapon_found(id: StringName)
signal ammo_changed(magazine: int, reserve: int)
## A body left a round behind. Separate from `ammo_changed` because that one fires for spending and
## reloading too, and the HUD only has something to announce when ammunition *arrives*.
signal rounds_scavenged(rounds: int)
## The trigger was pulled on an empty magazine. It exists so the moment is **audible**: a press that
## does nothing at all reads as a dropped input, and the player blames the game rather than their
## own ammunition.
signal weapon_dry_fired
signal weapon_reloaded
## A round left the barrel, whether or not it found anybody. Fired **per round**, so the double tap
## cracks twice — and separate from `attack_landed` because a gun that only makes a noise when it
## hits is a gun the player cannot tell they fired.
signal weapon_fired(attack: AttackData)
## A blow arrived while the player was rolling through it. Distinct from a dodge that merely
## happened: the lesson is not the button, it is the moment — and only this says the moment was
## right.
signal dodge_evaded
## The player's state machine moved. Cross-cutting because a sprint, a roll and a death are each
## something audio and the tutorial want to know about without holding the player.
signal player_state_changed(state: StringName)
## The hand moved from the keyboard to the pad or back. Everything that prints a glyph listens, so
## a player who picks up a controller mid-menu never reads the word "mouse".
signal input_device_changed(device: int)
## An action was rebound. Every glyph on screen is now potentially wrong, and this is what tells
## them — a badge that still says the old key is a badge the player will trust and be wrong.
signal bindings_changed


func _input(event: InputEvent) -> void:
	if Devices.notice(event):
		input_device_changed.emit(Devices.last_used())
