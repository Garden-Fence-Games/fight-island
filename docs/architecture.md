# Architecture

## Principle

**Composition over inheritance.** Nothing in `scripts/actors/` inherits from a `BaseCharacter`.
Behaviour is assembled from components that neither know nor care who owns them. A player and an
enemy both have health because both carry a `HealthComponent`, not because they share an ancestor.

## Layout

```
res://
  assets/{models,textures,materials,audio,fonts}/   imported, engine-ready
  art-source/                                       .blend and texture sources, not imported
  data/{weapons,attacks,upgrades,waves}/            .tres only — the balance surface
  scenes/{boot,main,world,actors,weapons,ui,fx}/
  scripts/
    autoload/     event_bus.gd, game_state.gd, audio_manager.gd
    resources/    attack_data.gd, weapon_data.gd, upgrade_track.gd, wave_config.gd
    components/   health_component.gd, stamina_component.gd, hitbox.gd, hurtbox.gd,
                  hit_info.gd, state_machine.gd, state.gd
    actors/       player/, enemy/, merchant/ — each with its states/
    systems/      wave_director.gd, spawn_director.gd, economy.gd, save_manager.gd
    camera/       camera_rig.gd
    ui/
  tests/
  tools/                                            EditorScripts and headless guards, never shipped
```

## Hitbox and hurtbox

Stated precisely so it is never re-derived.

**`Hitbox extends Area3D`** — `monitoring = true`, `monitorable = false`, `collision_layer = 0`,
mask = the opposing hurtbox layer. Carries `attack_data: AttackData`, `source: Node3D`,
`damage_scale: float`. Its `CollisionShape3D.disabled = true` at rest; the animation's
**call-method track** switches it on for the active frames and off afterwards. A per-swing
`_already_hit: Array[int]` of instance IDs stops one swing hitting twice.

**`Hurtbox extends Area3D`** — the mirror: `monitoring = false`, `monitorable = true`,
`collision_layer` = its own hurtbox layer, `mask = 0`. Holds a reference to its `HealthComponent`
and emits `hurt(info: HitInfo)`.

**`HitInfo extends RefCounted`** — damage, direction, source, stagger, poise, the perfect flag,
hitstop. One instance per contact. Deliberately **not** a `Resource`: a Resource has disk identity
and would be silently shared between contacts.

## Physics layers

Named in `project.godot` so the editor shows words instead of numbers. Reference them through a
constants script, never as raw integers.

| # | Name | # | Name |
|---|---|---|---|
| 1 | `world` | 6 | `player_hurtbox` |
| 2 | `player_body` | 7 | `enemy_hurtbox` |
| 3 | `enemy_body` | 8 | `interactable` |
| 4 | `player_hitbox` | 9 | `camera_occluder` |
| 5 | `enemy_hitbox` | 10 | `spawn_blocker` |

## State machines

Node-based: `StateMachine extends Node` with `State extends Node` children. Each state implements
`enter(msg: Dictionary)`, `exit()`, `update(delta)`, `physics_update(delta)`, `handle_input(event)`,
and the machine emits `transitioned(state_name: StringName)`.

Chosen over an enum- or resource-based FSM because states are visible and re-orderable in the
editor, can carry `@export` tuning per instance, and are reused across actors by composing the
machine rather than inheriting the actor.

- **Player:** `Idle`, `Move`, `Sprint`, `Dodge`, `Parry`, `Attack`, `Reload`, `Hurt`, `Dead`.
- **Enemy:** `Spawn`, `Idle`, `Chase`, `Strafe`, `WindUp`, `Attack`, `Recover`, `Stagger`, `Dead`,
  plus `Retreat` for the thrower.

`Attack` is **one** state driven by `AttackData`. The nine player attacks are data, not nine states.

The same applies to the enemies: **one `enemy.tscn`, three `EnemyData` resources.** Farmhand,
reaper and thrower differ by their stats, their attack and their material — not by three scenes to
keep in sync. A fourth archetype would be a `.tres`, not a branch.

## Data-driven balance

Custom `Resource` classes are the tuning surface. Changing a weapon never touches a script.

- **`AttackData`** — `id`, `damage`, `stamina_cost`, `windup`, `active`, `recovery`,
  `chain_window: Vector2`, `perfect_window: Vector2`, `perfect_multiplier`, `range`,
  `arc_degrees`, `stagger`, `poise_damage`, `ammo_cost`, `animation: StringName`, `hitstop`,
  `sfx`, `vfx`.
- **`EnemyData`** — `id`, `display_name`, `health`, `damage`, `move_speed`, `attack: AttackData`,
  `poise`, `money`, `material: StandardMaterial3D`, `is_ranged`, `preferred_range`,
  `first_wave`.
- **`WeaponData`** — `id`, `display_name`, `model: PackedScene`, `attacks: Array[AttackData]`,
  `is_ranged`, `magazine`, `reload_time`, `upgrade_track: UpgradeTrack`.
- **`UpgradeTrack`** — `id`, `display_name`, `icon`, `max_level`, `levels: Array[UpgradeLevel]`.
- **`WaveConfig`** — every coefficient from the scaling formulas, exported so waves are tuned in
  the inspector.

## Autoloads — three, and why not four

- **`EventBus`** — signals only, zero state. It exists so the wave director and the HUD never hold
  a reference to each other.
- **`GameState`** — the *current run*: wave index, money, upgrade levels, equipped weapon, ammo
  reserve, seed, run stats. It owns run data and nothing else: no gameplay logic, no node
  references.
- **`AudioManager`** — bus setup, a pool of `AudioStreamPlayer3D`, music crossfade. Genuinely
  global because a sound outlives the scene that triggered it.

**`SaveManager` is deliberately not an autoload.** It is stateless file I/O, so a
`class_name SaveManager extends RefCounted` with static methods gives the same call site without a
node in the tree, without `_ready` ordering, and without another singleton to mock in tests.
See [ADR 0004](decisions/0004-three-autoloads.md).

Rejected outright: `Settings` (folded into `SaveManager` and `GameState`), `SceneManager` (a
forty-line `main.gd` covers four scenes), `DebugManager` (a scene behind an action).

## Signals

Named as a past-tense fact, never as a command and never `on_*`:

`wave_started(index)` · `wave_cleared(index, reward)` · `enemy_spawned(enemy)` ·
`enemy_died(enemy, money)` · `player_damaged(current, max)` · `player_died()` ·
`stamina_changed(current, max)` · `weapon_equipped(data)` · `ammo_changed(mag, reserve)` ·
`attack_landed(info)` · `perfect_timing()` · `parry_perfect()` · `money_changed(amount)` ·
`upgrade_purchased(track_id, level)` · `run_started(seed)` · `run_ended(victory, wave)`

**The rule:** a component talking to its owner uses a direct signal on the component. The
`EventBus` is only for cross-cutting listeners — HUD, audio, telemetry.

## Wave spawning

`main.tscn` → `arena.tscn` holds a `WaveDirector` and N `SpawnPoint` markers.

`WaveDirector.start_wave(n)` reads `WaveConfig`, computes the budget and emits `wave_started`. The
`SpawnDirector` drip-feeds spawns respecting `max_alive(n)`, choosing points more than 12 m from
the player, preferring off-camera, and rejecting any point whose `spawn_blocker` overlap test
fails. Each enemy is leased from a pre-warmed pool of 32. `enemy_died` decrements the counter; at
zero the director emits `wave_cleared`, `Economy` credits the money, the upgrade screen opens,
`upgrade_purchased` applies modifiers to the live player, and after a five-second breather the next
wave starts.

## Camera rig

`CameraRig (Node3D, yaw) → PitchPivot (Node3D) → SpringArm3D → Camera3D`.

**The angle is fixed and never turns**: yaw −45°, pitch −50°, for the whole game. The rig follows
the player through a damped smooth rather than being parented to them, and the spring arm runs
**6–16 m** with eased zoom.

Fixing it is a design decision, not a simplification. Every silhouette reads the same way every
time; the island only has to be composed for one viewpoint; and a telegraph can never end up behind
geometry because the player happened to have turned the camera. The cost is that the arena must be
authored so nothing important sits in the one blind direction.

Occlusion is handled by **fading** what comes between the camera and the player, not by dodging it.
With a fixed angle the offenders are known at authoring time, which a moving camera could never
promise.

The spring arm's collision mask is **zero**, on purpose. Letting it push the camera out of geometry
sounds harmless and is not: the moment the island had trees, the arm collapsed against whatever
stood behind the player and sprang back when it cleared, which reads as the camera lurching. A
fixed camera has to actually be fixed.

## Save format

JSON under `user://`:

- `settings.json` — audio buses, input remaps, display, camera sensitivity and invert, accessibility
- `progress.json` — best wave, runs played, victories, endless unlocked
- `run.json` — the between-waves snapshot

Every file carries `"version": 1` and passes through a `migrate()` switch on load.

**Never `ResourceLoader.load()` from `user://`.** A `.tres` can carry a script path, and that is
arbitrary code execution on a file the player can edit.

## Performance budget

60 fps at 1080p on an Apple M-series and a GTX 1060. At most 30 enemies on screen, pooled, with
capsule collision shapes only. No `get_node` per frame — `@onready` everywhere. Physics at 60 Hz.
`_physics_process` for gameplay, `_process` for visuals. **Hit registration uses physics-frame
state, never an interpolated visual transform.**

## The island

Generated and baked, not hand-placed: `tools/build_island.gd` → `scenes/world/island.tscn`. The
rules it works to are in `docs/asset-pipeline.md`, and `tools/verify_island.tscn` enforces the ones
combat depends on — a clear fighting core, a flat fighting core, tall geometry only on the far side
of the fixed camera, and a boundary that lets the player reach the water.

The boundary is **depth, not a radius**. The coastline is not a circle, so a circular fence would
either shut off half the beach or let the player swim away on the other side. Wade in to the shins
and the sea pushes back; nothing is ever blocked, so the edge of the world is felt as the shape of
the place.

## A Node3D faces -Z

The yaw that points a node along `direction` is `atan2(-direction.x, -direction.z)`, not
`atan2(direction.x, direction.z)`. The wrong one is off by 180° and produces an enemy that
carefully turns its back before swinging — which looks like a broken hitbox, not a broken
rotation. It cost an afternoon once; `tools/verify_combat.tscn` now fails if it comes back.

## Testing

gdUnit4. Unit-test the pure parts that carry the design: the `WaveConfig` formulas, the `Economy`
cost curve, `AttackData` window arithmetic, upgrade application. Do not unit-test FSM transitions —
drive a headless scene instead.

Two headless guards run in CI and locally:

- **`tools/verify_project_config.gd`** — fails when an input action or a physics layer goes
  missing. Runs with `--script`, because it touches no autoload.
- **`tools/verify_combat.tscn`** — asserts that a jab deals its tabled damage, that a perfect hit
  multiplies it, that the chain window opens and closes where the design says, that a perfect parry
  negates, and that a farmhand left alone crosses the arena and connects. It runs as a **scene**,
  not with `--script`: `--script` starts no autoloads, so every script touching the `EventBus`
  would fail there for the wrong reason.

Booting the game headless (`--quit-after`) and failing on any error *or warning* catches more than
either, for a tenth of the effort.
