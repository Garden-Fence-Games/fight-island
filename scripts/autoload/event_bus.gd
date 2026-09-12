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
signal attack_landed(target: Node3D, damage: float, perfect: bool)
signal perfect_timing
## A swing whose active window closed without touching anything. It carries the attack because what
## a whiff sounds like depends on what was swung, and because nothing else can reconstruct it once
## the state has moved on.
signal attack_whiffed(attack: AttackData)
signal parry_perfect
signal parry_late
signal enemy_spawned(enemy: Node3D)
## The archetype travels with the death because the tally outlives the node that carried it.
signal enemy_died(enemy: Node3D, archetype: StringName, money: int)
signal hitstop_requested(duration: float)
## A wave has begun, and how many bodies it will send in total.
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
## The trigger was pulled on an empty magazine. It exists so the moment is **audible**: a press that
## does nothing at all reads as a dropped input, and the player blames the game rather than their
## own ammunition.
signal weapon_dry_fired
signal weapon_reloaded
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
