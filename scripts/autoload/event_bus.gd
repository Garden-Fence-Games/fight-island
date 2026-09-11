extends Node
## Cross-cutting signals only, and no state. Exists so the HUD, audio and telemetry can listen to
## combat without anything holding a reference to them. A component talking to its own owner uses
## a signal on the component instead.

signal player_damaged(current: float, maximum: float)
signal player_died
signal stamina_changed(current: float, maximum: float)
signal attack_landed(target: Node3D, damage: float, perfect: bool)
signal perfect_timing
signal parry_perfect
signal parry_late
signal enemy_spawned(enemy: Node3D)
signal enemy_died(enemy: Node3D, money: int)
signal hitstop_requested(duration: float)
## The player has finished a chain and cannot attack for `seconds`. Presentation exists because of
## this pair: a wait nobody can see reads as a dropped input, and the player blames the game — and
## they are right to, because nothing told them.
## A wave has begun, and how many bodies it will send in total.
signal wave_started(wave: int, enemies: int)
## The last of them is down. The reward travels with it so the economy can stay a listener rather
## than something the director has to know about.
signal wave_cleared(wave: int, reward: int)
signal chain_spent(seconds: float)
signal chain_ready
