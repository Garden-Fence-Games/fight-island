# Architecture

## Principle

**Composition over inheritance.** Nothing in `scripts/actors/` inherits from a `BaseCharacter`.
Behaviour is assembled from components that neither know nor care who owns them. A player and an
enemy both have health because both carry a `HealthComponent`, not because they share an ancestor.

## Layout

```
res://
  assets/{models,textures,materials,audio,fonts,   imported, engine-ready
          logo,video,locale,themes}/
  art-source/                                       .blend and texture sources, not imported
  data/{weapons,attacks,upgrades,waves}/            .tres only — the balance surface
  scenes/{boot,main,world,actors,weapons,ui,fx}/
  scripts/
    autoload/     event_bus.gd, game_state.gd, audio_manager.gd
    resources/    attack_data.gd, weapon_data.gd, upgrade_track.gd, wave_config.gd
    components/   health_component.gd, stamina_component.gd, hitbox.gd, hurtbox.gd,
                  hit_info.gd, state_machine.gd, state.gd, aim_component.gd,
                  animation_component.gd, head_look_component.gd,
                  weapon_visual_component.gd
    actors/       player/, enemy/, merchant/ — each with its states/
    systems/      wave_director.gd, spawn_director.gd, tutorial_director.gd, economy.gd, devices.gd,
                  save_manager.gd, settings.gd, input_bindings.gd, run_stats.gd, hit_feedback.gd
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

The box is resized per swing, to the reach of the attack being thrown — and **a hitbox duplicates
its shape on `_ready`** because of it. A `.tscn`'s sub-resources are handed to every instance of
that scene rather than copied, so thirty-two pooled bodies were resizing one box between them: the
last one to arm decided how far every open hitbox reached. It is the same trap `DayNight` avoids on
its `WorldEnvironment`, and the rule is general — **anything that writes to a sub-resource of a
scene that is instanced more than once must own a copy of it first.**

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
  `is_ranged`, `magazine`, `reload_time`, `upgrade_track: UpgradeTrack`, and `clip_suffix` — the
  ending appended to a locomotion clip while this weapon is held, so `walk` becomes `walk_gun`
  without the animation component ever learning what a weapon is.
- **`UpgradeTrack`** — `id`, `display_name`, `icon`, `max_level`, `levels: Array[UpgradeLevel]`.
- **`WaveConfig`** — every coefficient from the scaling formulas, exported so waves are tuned in
  the inspector. It also carries the `DayCycle`, because which wave is a night wave is a question
  about the wave table.
- **`DayPhase`** — one stretch of the day: how many seconds it lasts, the hour it opens on, what it
  does to damage, telegraphs, rousing and the melee token pool, and the whole of its look.
- **`DayCycle`** — `phases: Array[DayPhase]`, in order. Their seconds add up to **one wave**. It
  answers three questions off the same array: whose *rules* are in force this far into the wave,
  what the *clock* reads, and how far the *sky* has turned toward the next phase.
- **`EliteRank`** — what being an elite is worth: the health, damage and money multipliers, and the
  mesh scale and emission that make it legible. One instance on `WaveConfig`, shared by every body
  that rolls it, because an elite is the *same scene* — multipliers rather than a second archetype
  is what keeps the difficulty curve from turning into an asset list.

## Autoloads — three, and why not four

- **`EventBus`** — signals only, zero state. It exists so the wave director and the HUD never hold
  a reference to each other.
- **`GameState`** — the *current run*: wave index, money, upgrade levels, equipped weapon, ammo
  reserve, seed, run stats, and the time of day. It owns run data and nothing else: no gameplay
  logic, no node references. The day phase lives here rather than being reached for through the
  wave director because the sky, the clock, the token pool and every enemy want it, and none of
  them should have to find a director to ask.
- **`AudioManager`** — every sound the island makes, **synthesised at startup** rather than shipped
  as files. Genuinely global because a sound outlives the scene that triggered it, and an autoload
  because all but one of them answer a bus signal.

  Three tiers, and the division is what keeps the mix legible. **The player's own body** —
  footfalls, a roll, a reload, a dry trigger — is flat, on the `SFX` bus, and deliberately the
  quietest thing in the game: it is confirmation, not information. **The world** — a farmer
  committing, a body going down — is *positional*, on a pool of `AudioStreamPlayer3D`, because a
  wind-up the player cannot see is the one they most need to hear and a direction is the only thing
  that makes a crowd answerable. **The bed** — the surf — loops on the `Ambience` bus and is the
  only sound with no event behind it.

  Loudness is **declared per sound** rather than normalised to one shared peak, and `peak_of`
  reports what each asked for. It has to be declared: a footfall at a hit's level walks over the
  fight it is walking through. The mix is therefore an ordering a check can assert — footfall under
  swing under hit under telegraph — rather than a set of numbers that sounded fine once.

  Two traps are worth knowing, because both are invisible and both were hit. **The anti-click ramp
  goes on before the peak is measured**: a short sound is loudest a millisecond in, so ramping
  afterwards eats the sample the normalisation was aimed at. And **the bed does not play in a
  headless run** — a stream still playing when the engine tears down is reported as a leak, and CI
  fails a boot on any warning at all. The waveform is still built and assigned, so the loop and its
  seam stay as checkable as everything else.

**`SaveManager` is deliberately not an autoload.** It is stateless file I/O, so a
`class_name SaveManager extends RefCounted` with static methods gives the same call site without a
node in the tree, without `_ready` ordering, and without another singleton to mock in tests.
See [ADR 0004](decisions/0004-three-autoloads.md).

Rejected outright: `Settings`, `SceneManager` (a forty-line `main.gd` covers four scenes),
`DebugManager` (a scene behind an action).

**`EventBus` has exactly one piece of behaviour**, and it is worth knowing why. It is the only node
that sees every event in every scene, so it is where the game notices which device the player just
touched — but the answer is kept by `Devices`, not by the bus. The bus does the noticing; it still
does not do the knowing, so *signals only, zero state* still holds.

**`Settings`, `InputBindings` and `Devices` are static classes too**, next to `SaveManager`. Nothing subscribes to a setting:
every reader asks for the value at the moment it needs it, which is why no signal is missing.
The first read loads the file and applies everything, so a scene launched straight from the
editor behaves exactly like one reached through boot.

## The thrower, and the one stone

Two things about the ranged archetype are not obvious.

**`Retreat` releases its token on the way in.** A body walking backwards is not committing to
anything, and a held token would keep the other thrower waiting for a turn that is not coming.

**The ranged token is held until the stone lands, not until the throw ends.** The design says at
most one stone is in the air, and a throw whose recovery is shorter than its own stone's flight
would otherwise let a second one go. With the figures as they ship the two are the same thing — a
stone crosses its range in 1.17 s while the next thrower needs 1.4 s to claim and wind up, so
nothing in a running fight distinguishes them. Shorten a recovery or slow a stone and it would
matter, and nobody would find out by watching. `verify_combat` therefore checks the rule directly:
throw, release, and assert the pool still shows the token held.

The stone is parented to the thrower's **parent**, not to the thrower. A projectile owned by a body
that dies mid-flight would be freed in the air.

## The tutorial, and what it proves about the bus

Wave 1 is hand-driven by a `TutorialDirector` reading `TutorialStep` resources — see
[tutorial.md](tutorial.md). It is worth stating here because it is the **bus paying for itself**:
the tutorial watches the whole fight without a single combat system knowing it exists, and deleting
the node cannot break anything. `attack_landed` already carries the perfect flag, `parry_perfect`
already fires, and two signals were added for lessons nothing else had a reason to announce —
`dodge_evaded`, a blow arriving while the player rolls through it, and `player_state_changed`.

`dodge_evaded` is not "the player dodged". The lesson is the moment, not the button, and only a hit
that was actually refused says the moment was right.

Movement is the one lesson with no event behind it, and that is the honest answer rather than a gap:
nothing else in this game cares that the player walked, so there is nothing to listen to and the
director measures the distance itself.

## The bag

What the player is carrying is a `Loadout` on `GameState` — which weapons have been found, which is
in hand, and the rounds in the gun and in the pocket. Its own object rather than five fields,
exactly like `RunStats`, and for the reason `GameState`'s own docstring gives: that class is narrow
on purpose, and "the bag" has rules of its own.

**It is run state, not a field on the body.** A player who quits to the title and continues is
holding what they were holding, and the gun still has the rounds they left in it, because the whole
bag goes into `run.json`.

The rules worth stating, because each is a thing a player would notice going wrong:

- **A weapon that has not been found cannot be equipped**, so the wheel is honest about what is in
  the bag and cannot cycle onto an empty hand.
- **The magazine is the gate on a shot, not the reserve.** A shot the magazine cannot pay for is a
  reload the player has to choose to make.
- **Nothing refills the pocket on a clock, and it never holds more than its ceiling — magazine
  included.** Rounds enter a run off the bodies of the dead and across the merchant's counter, and
  a bag already at the ceiling takes none of either. That is the gun's rhythm; see
  `docs/game-design.md`.
- **The scavenge roll arrives rather than being made in the bag.** A one-in-eight that rolls its
  own dice can only be checked by firing it ten thousand times and squinting at the total; one that
  is handed a number can be asked the question with a known answer.
- **A pickup already in the bag does nothing.** Walking over the gun twice must not re-arm one the
  player has half emptied.

A shot is a `Hitscan` beside the hitbox: a **ray** rather than a volume, resolved the instant the
windup ends. A bullet has no travel and no swing, so arming a box for a tenth of a second would let
a farmer walk into a shot that had already been fired. It builds the same `HitInfo` and calls the
same `take_hit`, so a parry, a set of invulnerability frames and a death behave identically whether
the blow was a fist or a round.

## The wallet

`Economy` owns the cost curve and nothing else. The balance lives on `GameState`, and a wave's
reward lives on `WaveConfig` with the rest of that wave's figures — three homes, none of them
duplicating another. The kill bonus is not there at all: it is `EnemyData.money`, per archetype,
and an elite will carry a larger one on its own body the same way it carries scaled health.

**The wallet listens.** The director pays out on the bus when a wave clears and each body pays out
as it dies; neither knows a wallet exists. Money only moves through `earn` and `spend`, so nothing
can change it without `money_changed` going out, and `spend` answers whether the purchase went
through — a merchant that has to check the balance itself is a merchant that can forget to.

**The curve is the design.** Rewards rise by a flat twelve a wave while costs rise by three fifths
a level, so the gap widens on purpose: fifteen waves earn 2 010 and maxing one track costs 795. The
check asserts that ratio as a *band* — two to three tracks a run — rather than as a number, so a
tuning pass that keeps the shape passes and one that flattens the choice does not.

## Signals

Named as a past-tense fact, never as a command and never `on_*`:

`wave_started(index)` · `wave_cleared(index, reward)` · `enemy_spawned(enemy)` ·
`enemy_died(enemy, archetype, money)` · `player_damaged(current, max)` · `player_died()` ·
`stamina_changed(current, max)` · `weapon_equipped(data)` · `ammo_changed(mag, reserve)` ·
`rounds_scavenged(rounds)` ·
`attack_landed(target, damage, perfect)` · `perfect_timing()` · `parry_perfect()` ·
`money_changed(amount)` ·
`upgrade_purchased(track_id, level)` · `run_started(seed)` · `run_ended(victory, wave)`

**The rule:** a component talking to its owner uses a direct signal on the component. The
`EventBus` is only for cross-cutting listeners — HUD, audio, telemetry.

## Measuring the crowd

`tools/stress_enemies.tscn` puts a crowd on the island, wakes it, and reports the physics and
process time at several sizes **in one process** — because a machine with a second Godot on it
drifts between runs by more than any of these differences are worth. It prints the median and the
worst frame, and says so out loud when the two are far enough apart that the run should not be
compared to anything.

It runs headless, so nothing about drawing is measured and nothing about drawing should be read
into it. What it does measure is the side the crowd rules live on.

**What it found, and what was not done because of it.** The two suspects named in #31 were
`Enemy._separation()`, which is every body against every other, and the hitbox polling
`get_overlapping_areas()`. Neither is measurable at the budget:

- The whole physics step is **1–3 ms against the 16.7 ms a 60 Hz frame has**, from zero bodies to
  forty.
- The cost **does** rise with the square of the crowd, and the first version of this note said
  otherwise. The whole-step figure cannot see it: a step is mostly `move_and_slide` and the
  navigation agents, so a term worth a millisecond hides under them and the total reads flat.
  Isolated and taken past the budget, the pass costs **17 µs per body at ten bodies and 77 µs per
  body at sixty** — a per-body cost that climbs with the crowd is the definition of the square
  term. `stress_enemies` now reports that column and that figure, so the claim is re-measurable
  rather than a sentence.
- **It is still not worth fixing**, which is what the original note got right. At the budget of
  thirty the pass is about 1.3 ms, and a spatial grid was written, measured against the scan it
  replaced, and **reverted**: it made no difference at thirty bodies and cost a static cache and
  more code to say the same thing. The decision stands; only its reason changes. *Not quadratic*
  would have meant never looking again, and the difference matters the day the budget rises —
  past about sixty bodies the grid wins by roughly four to one.

The run-to-run noise on a busy machine is larger than the gap between no enemies and forty of them,
which is the most useful single fact here: **nothing on this side is close to the budget**, and the
remaining question in #31 is the GPU, on the two reference machines, with a window.

## Drawing the island

The decoration is scattered from a seed and baked into the scene, and until recently it was baked as
**four `MultiMesh` batches, one per population**. A `MultiMesh` is culled as a single object against
a single bounding box, so a population that spans the island has a box that spans the island —
something in it is always on screen, and none of it is ever discarded. Twelve thousand tufts of
grass were submitted every frame to draw the handful in shot.

`IslandScatter` splits each population across a **24 m grid**, one batch per occupied cell, sharing
one mesh and one material between them. The camera keeps the cells it can see. Two further calls,
both of which are judgements about what a thing is rather than tuning:

- **Grass and pebbles fade out** at 55 m and 70 m. They are a few pixels each past that. Palms and
  rocks have no range at all — they are silhouettes, and the island reading as an island depends on
  them.
- **Grass and pebbles cast no shadow.** The shadow pass draws the whole island, frustum or not, so
  scatter that is invisible in shadow is paid for twice for nothing.

Measured from the game's own camera at 1080p, on the island as it ships:

| | objects | primitives | draw calls |
|---|---|---|---|
| One batch per population, everything casting shadows | 114 | 4 478 154 | 114 |
| Chunked, grass and pebbles faded and out of the shadow pass | 162 | **1 796 286** | 162 |

**Draw calls rose on purpose.** A draw call is cheap and two and a half million submitted primitives
are not; the trade is the whole point.

`tools/measure_draw.tscn` is that measurement, repeatable. It **needs a window** — the headless
renderer is a dummy that draws nothing and reports nothing, so every figure would be nought there.
That is why `verify_island` asserts the *shape* that makes culling possible instead: every
population is more than one batch, and no chunk is wider than the grid plus the widest thing
standing in it. A population shipped as one batch fails, which is the state this started in.

## Effects

`EffectPool` sits in the arena and is found by group, because effects are asked for from states,
components and listeners alike and none of them should hold a path to it. Each scene is warmed in
**one batch the first time it is wanted**; every instance after that has already been used. Thirty
enemies on screen is the budget and an effect instanced per hit is the easiest way to lose it —
a `PackedScene` unpacked and a particle system configured inside the frame the player is meant to be
feeling. An effect hands itself back with a `spent` signal, the same shape as `Projectile` and the
enemy pool.

**`AttackData.vfx` names the effect a landed hit plays**, and it is played from
`PlayerAttack._on_landed` — the one place that knows the attack, the body and whether the timing was
perfect, and the place both the melee hitbox and the gun's hitscan arrive through.

**The impact is `CPUParticles3D`, deliberately.** A burst is a dozen quads at most and costs
nothing, while the GPU kind cannot be asked what it did — it draws or it does not, and a headless
check can only watch it fail to. A perfect hit differs from a plain one in **three ways at once**:
more debris, thrown further, for longer, plus a brighter flare. Any single difference is one the
player has to be told about.

**Nothing draws the wind-up.** There was a ring on the ground under whoever was committing, filling
as the telegraph ran; it is gone, and the clip that replaces it is not authored yet. The timing is
untouched — `WindUp` still holds for `enemy.windup()` seconds and every check of that still passes —
but a player currently reads a wind-up as a farmer who has planted his feet and nothing more. When
the tell comes back it comes back **on the body**, which is where a rigged enemy carries it: no
ground decal, and no separate thing to keep in step with the number.

Whatever draws it will still owe the rule the ring was built for: **a shape, not a colour.** Colour
alone fails a colourblind player, every greyscale screenshot, and any camera far enough away that a
tint is a few pixels.

### The accessibility settings are consumers

Three were stored, persisted and shown in the options screen with **nothing reading them**. Two are
read now, and the third — `access_colourblind_telegraphs` — went out with the ring it thickened
rather than staying on the screen as a switch that moves nothing.

- `access_screen_shake` scales every knock, and **nought means none**. Scaling happens on the camera
  rather than at each emitter, so no emitter has to remember the setting exists.
- `access_reduce_flashing` damps the flare and **leaves the debris alone**: debris is motion, not
  flashing, and removing it would take the hit's readability away in the name of protecting the
  player from it.

## Wave spawning

`arena.tscn` holds `WaveDirector → SpawnDirector → EnemyPool`, in that nesting: the director owns
where bodies come from, which owns the bodies. They are children rather than exported node
references, because node exports do not resolve in a hand-written `.tscn` (ADR 0006).

`WaveDirector.start_wave(n)` reads `WaveConfig`, emits `wave_started`, then **drip-feeds**: the
count is how many arrive in total, `max_alive(n)` is how many the player faces at once, and the gap
between those two is what makes a late wave pressure rather than a wall. `enemy_died` brings the
director back; when nothing is owed and nothing is alive it emits `wave_cleared` with the reward and
starts the breather. The economy and the HUD are listeners — the director does not know they exist.

**Every number comes from the resource**, the elite chance and the `EliteRank` it hands out
included. A table split across two files is a table that starts disagreeing.

The roll is per body, not per wave: a wave is never uniformly worse, an elite is a moment inside a
fight. A null `WaveConfig.elite` switches the whole thing off, which is how the tutorial wave and
the headless checks run the same director without ever meeting one.

## Day and night

**A wave is one turn of the day**, so the director is a clock as well as a queue. It counts seconds
into the wave and each frame writes `GameState.day_elapsed`, `GameState.hour` and
`GameState.day_phase` from the cycle. The wave ends when the elapsed time reaches
`DayCycle.wave_seconds()`, or earlier if the roster is spent and nothing is standing.

`WaveConfig.damage_multiplier(wave, phase)` and `windup_multiplier(wave, phase)` are read **at the
moment a body is sent**, so what a farmer hits for is fixed by the light he walked on in. The floor
under the telegraph is applied after the phase, never before.

Everything downstream is a listener or a reader, and none of them knows a director exists:

- `AttackTokens` resizes its melee pool on `day_phase_changed`. Shrinking it back needs no
  unwinding — a body holding a token keeps it, and the pool refuses the next claim until enough
  have let go.
- `Enemy.rouse()` multiplies its radius by `GameState.rouse_scale()`. **Noticing is deliberately
  left alone**: a farmer arrives no closer than twelve metres and the thrower already notices at
  twelve, so scaling that would put every night wave back to charging from the horizon.
- `DayNight` owns the sun and the `WorldEnvironment` as children and reads `GameState.day_elapsed`
  — the same clock the rules read, so the light and the damage change together. It duplicates the
  environment on `_ready`, because a scene sub-resource is shared by every instance of the scene
  and the headless checks make two arenas in one process. **The shadows are painted from the phase
  too**, not left on the light: a moon at a third of daylight's energy casting noon's shadow is a
  shadow darker than the thing that threw it, and the check holds a dimmer sun to a lighter and
  softer one across the whole table rather than phase by phase.
- The HUD polls the hour rather than being signalled: it moves every frame, and a signal per frame
  is a signal nobody wants. It also listens for `wave_cleared` to put the passed-wave banner up.

`SpawnDirector` answers *where*, under three rules that are each a thing a player would notice going
wrong: far enough away to be seen coming, **never inside the camera's frustum** — feet *and* head,
since the camera looks down — and on ground `Ground.is_spawnable` says the body could walk out of.
The distance is measured **after** snapping to the navmesh, because snapping pulls a point by up to
a metre and a rule checked on the guess is a rule the answer need not obey. When nothing passes,
nothing spawns this tick and the body stays owed: a wave arriving a second late is invisible, a
farmer appearing in shot is not.

Nothing can spawn before the navigation map has synced, which is one more reason the first wave is
not instant.

`EnemyPool` pre-warms 32 bodies. A body is **leased and returned**, never created and freed:
`Enemy.revive()` holds everything that differs between one life and the next — the wave's scaling
included, held per body because `EnemyData` is one shared resource on disk and scaling it in place
would raise every farmer in the game and then save the result.

## Noticing

A farmer stands where he appeared until the fight reaches him. It is four lines of state and one
field, and the only interesting parts are the edges.

**The radius has to be smaller than the spawn distance or the feature does not exist.** The spawn
search keeps bodies 12–26 m from the player; the old aggro radius was 18 m, so more than half of
every wave arrived already charging. Nothing would have failed — there would simply have been no
behaviour. `verify_combat` asserts the inequality directly, against a written-out 12 rather than
against `SpawnDirector`'s own constant.

**Noticing is one way.** `Chase` used to fall back to `Idle` past the radius; it no longer does. A
leash makes the edge of a crowd breathe in and out as the player drifts back and forth, and a farmer
who forgets he was swung at is worse than one who never noticed.

**Rousing spreads, and terminates on its own guard.** `rouse()` returns immediately if the body is
already roused, so each one is visited once however the crowd is arranged — no depth limit, no
visited set. Being hit routes through the same call, which is what stops a thrower plinking at
someone from outside their own notice radius forever.

None of this needed a token change: tokens are claimed on entering `WindUp`, and an idle body never
gets there. Nor did the wave director: a wave ends when the last body *dies*, not when the last one
is fighting, so a field of men who have not noticed anything still holds the wave open.

## Camera rig

`CameraRig (Node3D, yaw) → PitchPivot (Node3D) → SpringArm3D → Camera3D`.

**The angle is fixed and never turns**: yaw −45°, pitch −50°, for the whole game. The rig follows
the player through a damped smooth rather than being parented to them, and the spring arm runs
**11–24 m** with eased zoom, opening at 17.

Fixing it is a design decision, not a simplification. Every silhouette reads the same way every
time; the island only has to be composed for one viewpoint; and a telegraph can never end up behind
geometry because the player happened to have turned the camera. The cost is that the arena must be
authored so nothing important sits in the one blind direction.

### Aim assist

`AimComponent.direction()` is where it happens, so the head, the body, the swing and the shot all
agree about where the player is pointing — a round that landed somewhere the character was visibly
not facing reads as the game missing on its own.

The nearest body **in angle** to where the player is already pointing, inside a 12° cone and inside
the reach of the attack in hand, and the aim is turned that way by the share the setting asks for:
`soft` half of it, `strong` all of it, `off` none. Closest in angle rather than in distance, because
the player has aimed and the thing they meant is the one nearest that line.

It applies to the mouse as much as to the stick. Aim assist on a mouse is normally an insult; this
one is an accessibility setting rather than a pad affordance, and somebody who cannot hold a line
with a mouse needs it exactly as much.

The candidate list is the `enemies` group, which `EnemyDead` leaves the moment a body dies — so
there is no liveness test here, because one could never fire. Two group scans a frame over at most
twelve bodies; `tools/stress_enemies.tscn` shows nothing at forty.

### Where the blind side is

Measured rather than asserted, by `tools/verify_view.tscn`, which marches outward from the player
on 36 bearings and asks the frustum where the ground leaves the frame:

| arm | ground in shot, blind bearing | ground in shot, longest |
|---|---|---|
| 11 m (closest the wheel reaches) | 5.2 m | 22.5 m |
| 17 m (at rest) | 8.5 m | past 30 m |
| 24 m (furthest) | 12.0 m | past 30 m |

The blind side is **bearing 130°**, down-screen — the strip of ground between the player and the
camera, which falls off the bottom of the frame. It is very nearly half the arm, whatever the arm
is, which is what fixes the lower end of the zoom range: a reaper strikes from 2.8 m and covers
1.8 m more while he winds up, so under **4.6 m** of visible ground his swing begins off-screen.
Eleven metres is the first step of the wheel clear of that. The floor was six until this was
measured, and six shows 2.75 m.

Two rules follow from it, and both are checked:

- **A spawn is never in shot** and never closer than 12 m — `SpawnDirector`, held by `verify_waves`.
  The blind side is where arrivals are supposed to come from.
- **A weapon pickup always is** — `PickupDirector`, held by `verify_view`, which drops 768 of them
  from 96 places around the island and fails if one lands where the player has no reason to walk.
  The question is asked at `WeaponPickup.RESTING_HEIGHT` on both sides: asking about the air a metre
  over a weapon accepts ground the weapon itself is off the bottom of the frame on, which is how one
  drop in two hundred was going missing.

The merchant is a screen rather than a body, so the third of issue #39's placement rules has
nothing to bind. **The thrower test is still open**: he strikes from 14 m, and neither "enough
sightline to be a threat" nor "enough cover to close on him" has an honest threshold yet.

Occlusion is handled by **fading** what comes between the camera and the player, not by dodging it.
With a fixed angle the offenders are known at authoring time, which a moving camera could never
promise.

The spring arm's collision mask is **zero**, on purpose. Letting it push the camera out of geometry
sounds harmless and is not: the moment the island had trees, the arm collapsed against whatever
stood behind the player and sprang back when it cleared, which reads as the camera lurching. A
fixed camera has to actually be fixed.

## Occlusion

The camera never moves, so what stands in front of the player is faded rather than dodged.
`OcclusionFader` drives it, and three decisions in it are worth keeping.

**Only the six authored boulders and the standing huts.** Palms are not faded — the body reads
clearly through a crown of fronds, and thinning several hundred trees in and out as someone walks
looks stranger than the trees did. That is a decision rather than an omission, so `verify_camera`
fails if the palms are ever put back in the occluder group. A wrecked hut is left out on the same
grounds: a metre of open post frame never hid anyone, and fading what the player already sees past
reads as a glitch. `verify_island` fails if anything in the group is wearing a material that cannot
fade, because `OcclusionFader` skips those silently.

**Plain transparency, not a dissolve.** Six objects in the transparent queue cost nothing. The
first version dithered pixels away, which is what a `MultiMesh` of several hundred palms would have
required — and it looked like a dissolve effect rather than like stone. Dropping the palms dropped
the need for it.

**The detector is geometry, not physics.** A ray on the `camera_occluder` layer is the obvious
implementation and the wrong one: a boulder's collider is a box seven tenths its size sunk into the
ground, and what hides the player is the silhouette. Each occluder is a sphere around what actually
blocks the view, tested against the segment from the eye to the player's chest, with one distance
check first so nothing beyond the camera is considered at all.

## Save format

JSON under `user://`, four files with three lifetimes. A debug build writes a fifth file in the
same directory, `telemetry.csv`, and it is **not a save** — see *Telemetry* below.

- `settings.json` — every row of the options screen, written the moment it changes
- `bindings.json` — **overrides only**, so changing a default binding later does not need a
  migration and does not strand a player on the old one
- `progress.json` — what outlives a run. Best wave today; the tutorial's cleared steps join it
- `run.json` — the between-waves snapshot, and the only file that is deleted when a run ends

Every file carries `"version"`, stamped on write. An **older** file goes through `_migrate`; a
**newer** one is discarded rather than guessed at, because nothing in this build can know what a
field it has never heard of means, and a wrong guess corrupts a save the player can still open with
the build that wrote it. Version 0 is every file written before the stamp existed, and it is
accepted as-is — refusing it would silently reset the options of everyone who updates.

Anything unreadable — missing, truncated, not an object — falls back to defaults with a warning.
The run file is *deleted* when it cannot be read, so a broken save fails once instead of every
launch, and the title screen does not offer a Continue that does nothing.

**The run seed travels as text.** JSON has one number type and it is a double; a 64-bit seed loses
its low bits in one, and the run would come back on a different island.

A snapshot is taken when a wave starts, when one is cleared, and when an upgrade is bought — so an
interrupted wave is fought again from its start, and the purchase it paid for is not lost with the
window. The run clock counts only while a wave is being fought: a run suspended on the title screen
must not accumulate time nobody spent playing.

**Never `ResourceLoader.load()` from `user://`.** A `.tres` can carry a script path, and that is
arbitrary code execution on a file the player can edit.

## Telemetry

**`Telemetry`** is a plain `Node` in `main.tscn`, beside `HitFeedback`. It appends one row per wave
to `user://telemetry.csv` so fifteen waves can be tuned from what players did rather than from what
the formulas promise: `run, wave, enemies, seconds, outcome, kills, perfect_hits, perfect_parries,
earned, spent, bought, level`.

Not a fourth autoload, and not `DebugManager` wearing a new name — [ADR 0004](decisions/0004-three-autoloads.md)
rejected that, and a node in the run scene has exactly the lifetime the record wants. One run is one
scene, and `_exit_tree` is where the last wave of a victory and the wave a player quits out of both
leave.

**Debug builds only, and not by a guard at the write.** `_ready` calls `start()` only when
`OS.is_debug_build()`, so a release build connects no signal and opens no file — the answer to "does
this ship" is *there is nothing there* rather than *the file stays empty*. Local, no network, no
prompt; `docs/menus.md` lists a telemetry prompt under what is deliberately absent.

**It counts nothing of its own.** Every figure is the difference between two samples of
`GameState.stats`, the tally the run summary already reads. A second counter beside that one would
be a second thing to get wrong, and the two would disagree quietly. The consequence is the failure
mode worth knowing about: writing the sample instead of the difference gives every wave the sum of
the ones before it, and wave one — where the two agree — is the row anybody eyeballing the file looks
at first. `tools/verify_telemetry.tscn` fights two waves with unequal kill counts for that reason.

**The clock is the one figure it measures itself**, accumulated in `_process` rather than taken from
wall time, so the merchant's pause and the gap between waves are charged to neither wave.

A purchase is filed under the wave that **paid** for it: the merchant opens before the next wave
starts, so the row is still open when `upgrade_purchased` arrives.

The file is appended with `FileAccess` and read back by nobody — not even to decide whether the
header is owed, which is a question about existence rather than about contents.

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

## Wind and water

Both are shaders, and both are shaders for the same reason: the thing that has to move is drawn
thousands of times from one mesh, so nothing per-instance can drive it.

**The wind** (`assets/shaders/foliage.gdshader`) runs in the vertex stage. Every plant on the
island is one instance of a `MultiMeshInstance3D` — 380 palms, 24 000 grass tufts — and instances
cannot play separate animations. This did not change when the plants stopped being primitives and
became modelled: a pack of rigged foliage would buy nothing, because the rig could never reach the
instances.

Phase comes from distance along the wind, so a gust travels across the island and neighbours are
naturally out of step. **Nothing is hashed**: a hash is discontinuous, and two plants a metre apart
must not jump to opposite ends of the cycle.

Bend is measured from the instance's own origin, and every model in the pack stands on its origin,
so height above the ground is simply height above that origin. That is also what lets grass of two
lengths share one material: `bend_height` is set to the tall band's height, so bend comes out as
the fraction of it a vertex stands at — a long blade leans over and the short tuft beside it barely
stirs, from the same figures, with nothing per-instance to drive them apart. **A palm arrives as one mesh of two
parts** — trunk and crown together — so the crown reads its real height and bends with the wood it
sits on for nothing. An earlier version built a palm from a trunk mesh and six separate frond
instances, and holding those together took an anchor per frond in the `MultiMesh` custom data,
because a frond five metres up has no idea how high off the ground it is. The modelled palm deleted
the problem and the machinery with it.

What survived is the rule that had kept them together: **no surface of a palm may set a wind figure
for itself.** All of them take the shader's defaults, so there is nothing a tuning pass can change
on the crown without changing it on the trunk. `verify_island` fails if any surface starts to. And
flutter is still measured from the instance's own origin outward, so it is nothing at the trunk and
full at the leaf tips — a leaf flexing along its length, not a crown sliding sideways.

Materials are set **per surface**, never through `material_override`, which takes one material for
a whole mesh. A palm rendered in one flat colour is exactly what buying a modelled palm was meant
to stop, and nothing else in the build would have noticed.

**The water** (`assets/shaders/water.gdshader`) is where the shoreline comes from, and none of it is
authored: the shallow tint, the foam band and the depth at which the sea floor disappears all come
out of comparing the depth buffer with the surface, so they follow the coast wherever the generator
puts it. Four things separate water from tinted glass, and the plane needs all four — the floor
**refracts** as it is seen through the surface, the deep closes over it **opaquely**, the surface is
a **mirror at a grazing angle** and clear from above, and the light breaks into sparks on **ripples
finer than the mesh**. That last one is why the normal is built per pixel: the plane carries a
vertex every nine metres, which facets the whole sea and loses every ripple between two of them.
The swell moves vertices; the ripples never reach the vertex stage, where they would be sampled at
random and read as noise.

**The models carry shapes, not colours.** The island's palette lives in `NATURE_PALETTE` in the
generator, keyed by the material name each model gives its own parts. The pack's colours are not
used — its leaves ship as turquoise and its stone as a pale blue-white — and keying by name means a
pack that renames a part says so at build time instead of rendering in whatever a missing entry
would default to.

**Water the sea cannot reach is not water.** The coastline is a noise field rather than a distance
field, so it dips below the waterline here and there well inland, and the sea is one flat sheet
across the whole world — it fills every one of those dips. `tools/island_water.gd` floods the height
grid inward from its border and lifts whatever the flood cannot reach, so a pool joined to the open
sea by a channel stays a lagoon and a pool with no way out is drained. The threshold is the whole
thing: measured at the crest of the swell there are four bodies of water on this island — the sea
and three puddles. Measured five centimetres higher there is one, because the damp band along the
shore is continuous and the flood walks up the beach, round through the sand and into every puddle.

The lift is *kept*, not just applied to the grid, because `_height_at` is deliberately the one place
the mesh and the collision agree about the ground. A drain applied to the grid alone would leave
props, colliders and the navigation bake all standing under the sand.

## Navigation

The same generator bakes a `NavigationMesh` beside the terrain and hangs it on a
`NavigationRegion3D` in the island scene; every enemy carries a `NavigationAgent3D` and walks the
route it gives, re-asking four times a second. Straight-line chasing stays as the fallback for any
frame with no route — an arena with no navigation mesh still plays.

The navmesh gives the **route**; the existing separation steering keeps bodies apart in close
quarters. Splitting it that way is what stops thirty agents grinding along the same line.

Four things about the bake are not obvious, and each of them cost a debugging session:

- **Winding is load-bearing and silent.** Recast decides what is walkable from the face normal, so
  a reversed ground quad is not a hole in the mesh — it is *no mesh at all*, with nothing logged.
- **Obstacles are sunk and pitched.** A collider floating even a few centimetres above the terrain
  leaves a sliver of walkable ground under it and the hole never appears; a flat top is a floor as
  far as recast is concerned, however high up it is.
- **The mesh is deliberately coarse, and only the boulders are cut out of it.** Every polygon is
  scanned linearly by the queries each agent runs per frame. Carving all thirteen hundred props
  cost 20 ms a frame with thirty farmers; carving only what is genuinely impassable costs a
  fraction of that and walks identically, because the island already guarantees 1.5 m of clearance
  between any two props.
- **Recast leaves walkable ground *inside* solid things** — floor with no way in or out. So
  `Ground.is_spawnable` does not ask "is there navigation mesh here", it asks whether an actor put
  here could walk to the player. That is the question spawning actually needs, and it rejects the
  middle of a boulder and a sandbank across a bay with the same test.

## Aiming

`AimComponent` under the player answers one question — where the body should be looking — and
returns ZERO for "not aiming, face where you are going". Every caller had that behaviour already,
so nothing had to learn a new rule and no path leaves the body pointing somewhere nobody chose.

Three decisions inside it:

- **The device is whichever one was touched last, and neither at launch.** Without the third state
  a pad player would spend the whole game facing wherever the desktop cursor happened to be parked.
  It is also the answer issue #19 needs for its button glyphs.
- **The cursor is projected onto the ground plane at the body's own height**, not at y = 0, so the
  aim stays true as the player walks uphill. The fixed camera is what makes this honest: one angle,
  one ray. With a free camera the same feature is a pile of edge cases.
- **A cursor that lands on nothing holds the last direction** rather than clearing it. Over the sea,
  over the sky, or sitting on the character, the answer is "keep looking where you were" — never
  "spin".

Movement and facing are independent from here on, which forces two rules the combat now depends on:
an attack takes its facing once, on entry, so a swing cannot be steered mid-animation; and a dodge
goes where the stick or the keys say, rolling *away* from the aim when there is no movement input
at all, because rolling into what you are shooting at is not what the button means.

### Who does the pointing, once there is a rig

The aim is one question with two answers, split the day the capsule became a character:

- **While walking or standing, the body faces where it travels** — `Player.locomotion_facing`. A
  body free to point at the cursor while travelling elsewhere plays a forward stride sideways, and
  with one `walk` clip that is a moonwalk. This is also why there are no strafe clips yet: a
  character who always walks the way he faces never needs one.
- **The head carries the aim**, up to the neck's 55°. That is the whole of `HeadLookComponent`.
- **Standing still, the body takes the remainder.** Past the neck's limit it turns just far enough
  to bring the aim back inside the head's reach and stops, so a player can face anything without the
  body ever swinging round for a few degrees of cursor movement.
- **Attacks and dodges do not come through any of this.** A swing snaps to the aim in full, on
  entry: what you point at is what you hit.

The consequence to keep in view: while *moving*, an aim more than 55° off the direction of travel is
not fully expressed. Closing that gap is what strafe clips and a torso split buy, and neither is
worth building before the gun makes shooting-while-moving a real decision.

## The chain lockout

Where it lives is the interesting part. The clock is on `Player`, beside the chain bookkeeping, for
the same reason: it outlives the attack that opened it. `PlayerAttack` starts it when a **finisher
enters its recovery** — not when the recovery ends — so the wait is still measured from the end of
the recovery but a stagger cannot cancel it. A debt a hit clears is a debt worth taking a hit for.

`take_attack_input()` refuses a press during the lockout **without consuming it**, so the 0.15 s
buffer keeps working across the boundary and a press a hair early still lands.

The pair of `EventBus` signals — `chain_spent(seconds)` and `chain_ready` — exists because a wait
nobody can see reads as a dropped input, and the player blames the game. `HitFeedback` listens and
drains the body's colour for the duration; combat itself knows nothing about it. The state is shown
for the whole lockout rather than flashed when a press is refused: seeing that the weapon is not
ready *before* pressing is worth more than being told afterwards.

**The drain multiplies the albedo, so its colour cannot be read on its own.** A value that was a
slate blue over a white capsule takes a textured rig to a fifth of its own brightness — which is how
the third punch of every combo once turned the player black. `tests/test_hit_feedback.gd` holds the
drain between a floor and a ceiling for that reason: dark enough that the lockout is visible, light
enough that the body is still a body. A wait nobody can see reads as a dropped input, and a player
who has turned into a silhouette is not reading anything at all.

## Animation

`AnimationComponent` listens to the `StateMachine`'s `transitioned` signal and plays the clip that
matches the state. It does not know whose skeleton it drives: the `AnimationPlayer` and the machine
are found under its parent when its exports are left null, so a reimport that renames the glTF
nodes does not require touching the scene.

Three decisions worth keeping:

- **The states do not start their own clips.** A state that had to remember would one day forget,
  and that bug is a character frozen mid-stride with nothing in the log to explain it. Driving it
  from the one signal the machine already emits means a new state cannot be added without the
  animation question being answered.
- **A state may still *name* its own clip, and that name wins.** `Attack` is the reason: one state
  drives all nine attacks and which one is running is `AttackData`, so no table could answer for it.
  The component asks — `clip_name()`, and `clip_duration()` to stretch the clip to the attack's own
  windup-active-recovery — rather than the state pushing, because `StateMachine` runs `enter` before
  it emits and a state that started its own clip would have it stopped again one line later. The
  clip bends to the balance figures, never the reverse: the `.tres` is where an attack's timing
  lives, and a punch whose clip ran at its authored speed would have the fist out a frame late for
  ever.
- **A state with no clip plays nothing and says nothing.** The rig arrives one animation at a time,
  so most of the map points at clips that do not exist yet — that is the normal state of affairs,
  not a fault. It also keeps the build green: the import gate fails on any `WARNING` line, so a
  component that complained once per transition would turn main red for having half a rig. It
  emits `clip_missing` instead, and falls back to the rig's `RESET` pose.

**A second table holds a speed per state**, and `Sprint` is the only entry: there is no sprint cycle
yet, and the walk one played twice as fast reads as running for the price of a number. It is kept
apart from the clip table on purpose — authoring the real cycle is then one line changed in `clips`
and one line deleted here, and the borrowed look can never quietly become the intended one. The
speed counts as part of "which animation is playing", or a `Sprint` that shares `Move`'s clip would
be skipped as already-playing and the player would sprint at a stroll.

The state-to-clip map is explicit rather than a lowercase of the state name, because `Move` plays
`walk` and no rule bridges that pair. It is exported, so a state can be pointed at a clip that
already exists while the real one is still being authored.

## The weapon is in the rig, not attached to it

`WeaponVisualComponent` shows and hides the weapon meshes the skeleton already carries. There is no
bone attachment and nothing is spawned: the gun is modelled into the rig, parented to the hand bone,
because that is how the clips were authored — `idle_gun` and `walk_gun` move a gun that is part of
the skeleton. Hiding the mesh is therefore the whole of "not holding it", and hidden is the default,
which is what fists look like.

It takes a flag rather than a `WeaponData`, so it knows neither what a weapon is nor who owns it.
Whoever hands the gun over sets `armed`, which is what lets a pickup, a weapon switch and a headless
check all drive it the same way.

## Head look

`HeadLookComponent` points the head bone at the aim while the body does whatever its clip says. It
is the cheap half of an upper-body split: one bone, a `LookAtModifier3D`, no `AnimationTree` and no
second set of clips. Mixamo only ever hands over full-body animations, so any such split has to be
made at runtime; the torso version is the same idea one layer up and can be added without moving
this.

Four things about it are not obvious, and each was measured rather than assumed:

- **The modifier is built in code**, because a `SkeletonModifier3D` has to be a child of the
  `Skeleton3D` and that skeleton lives inside the imported glTF scene. Authoring it in `player.tscn`
  would mean editable children and the importer's node names pinned into the scene file.
- **It is built deferred.** A parent is still setting up its children while their `_ready` runs, so
  `add_child` on it fails and leaves the target adrift outside the tree, with a head that never
  moves and nothing in the log to say why.
- **The skeleton only runs its modifiers while something is playing.** With no clip the pose never
  changes, the skeleton never updates, and the head freezes. This is why the rig imports with
  `import_rest_as_RESET` on: a state with no clip of its own plays `RESET`, which keeps the
  skeleton live.
- **`get_bone_global_pose()` reports the animated pose *before* modifiers.** It shows a perfectly
  still head no matter where the modifier is actually pointing it, so anything checking the result
  has to read a `BoneAttachment3D` instead.

The turn is clamped to 55°, and past that the head stops and the body carries the rest. Unclamped,
a player running north while aiming south twists the neck through 180°.

## A Node3D faces -Z

The yaw that points a node along `direction` is `atan2(-direction.x, -direction.z)`, not
`atan2(direction.x, direction.z)`. The wrong one is off by 180° and produces an enemy that
carefully turns its back before swinging — which looks like a broken hitbox, not a broken
rotation. It cost an afternoon once; `tools/verify_combat.tscn` now fails if it comes back.

## Testing

**gdUnit4, vendored in `addons/gdUnit4`** and run in CI before anything slow gets a chance to. The
suites live in `tests/` and cover the pure parts that carry the design: the `WaveConfig` curves, the
`Economy` cost curve, `AttackData` window arithmetic, and every way a save file can be wrong.

```
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --ignoreHeadlessMode -a res://tests
```

**They assert properties, not the table.** `tools/verify_waves.tscn` already checks the shipped
numbers against `docs/game-design.md`; a second copy of that table would be a second thing to keep
in step. What the unit tests own instead is what the numbers cannot say: that every curve is the
identity at wave one, that none of them escapes its floor or ceiling at wave two hundred, that no
day phase can push a telegraph under the floor whatever it is tuned to, and that a save file from a
build that does not exist yet is refused rather than half-read.

**Do not unit-test FSM transitions** — drive a headless scene instead, which is what the checks in
`tools/` already do. And nothing in `addons/` is linted or formatted: it is vendored, not ours.

**Every check runs through `tools/run-check.sh`**, in CI and locally, and never as a bare
`godot --headless`. A GDScript file that fails to parse does not fail the check that uses it: the
scene loads without the script, `_ready` never runs, nothing calls `quit()`, and the process sits
in its idle loop forever. The same happens when a runtime error aborts the check halfway — GDScript
abandons the function, so `_report()` is never reached — or when an `await` never resolves. All
three look like a slow machine rather than a broken check.

The runner turns each of them into a failure that says so: a wall clock (`CHECK_SECONDS`, 300 by
default), a scan of the log for parse and compile errors, and one more rule that costs nothing —
**a check that exits cleanly without printing its `OK —` line has not passed, it has stopped.**

```
tools/run-check.sh res://tools/verify_waves.tscn      # a scene
tools/run-check.sh tools/verify_project_config.gd     # a script, run with --script
```

Two headless guards run in CI and locally:

- **`tools/verify_project_config.gd`** — fails when an input action or a physics layer goes
  missing. Runs with `--script`, because it touches no autoload.
- **`tools/verify_combat.tscn`** also covers the chain lockout: that a finished chain announces
  itself on the bus, refuses a press without consuming it, expires, costs nothing when the player
  stops at two attacks, waits less after a perfect finisher, and never blocks a dodge.
- **`tools/verify_waves.tscn`** — asserts the wave table and `data/waves/standard.tres` still
  agree, then runs a wave: it arrives out of shot and more than twelve metres out, never exceeds
  `max_alive`, clears when the last body dies, pays the tabled reward, and reuses bodies rather than
  making them. The spawn rules are checked against **two hundred points from the search**, not
  against the four a wave happened to use — with the "never in shot" rule deleted, a four-body wave
  still passed, which made that check decorative. It also asserts the upgrade cost curve, that a
  run buys about two tracks out of five, that clearing a wave puts both the reward and the kills
  into the purse, and that no wave ever opens with a thrower while one can still turn up later —
  rolled four hundred times a band, because a rule that holds for one seed is not a rule.
- **`tools/verify_aim.tscn`** — drives a real joypad event and a real key press through the
  engine's own input path, and the real camera projection for the cursor, then asserts that holding
  a movement key still walks the body and does not follow its facing, that the body turns at a
  capped rate,
  goes back to facing its movement when the stick is released, does not aim before any device is
  touched, commits its attack facing, and dodges away from the aim rather than into it.
- **`tools/verify_island.tscn`** also covers the foliage: that everything which grows stands in the
  wind and no stone does, that no plant bends from its base, that no palm surface overrides a wind
  figure, that a palm still renders as two colours rather than one, and that palms come out between
  3 and 5.6 m tall — a wrong figure for a model's shipped height is otherwise silent, and the island
  simply comes back with palms three times the size of the fight.
  It also floods the terrain's own collision heights and fails if any water stands where the open
  sea cannot reach it, and it reads the swell height out of the water shader to fail if the waves
  ever grow past the height the drained sand was lifted to — one number, two files.
  `verify_combat` also covers noticing: that a farmer left well clear does not close on his own and
  never telegraphs from outside his reach, that walking up to him starts the chase, that a hit wakes
  him at forty metres, and that rousing crosses three metres but not twenty-five. Both of those
  distances are written out rather than derived from the radius being tested — deriving the far one
  from the data would place it outside any value at all, and the check could never fail. It did not,
  until that was fixed.
- **`tools/verify_camera.tscn`** — parks the body behind a boulder and asserts it goes pale, comes
  back when the body walks out, never fades with nothing in the way, never fades to nothing, and
  that the palms are left alone. The renderer draws nothing headless, so this checks the decision —
  which occluder fades and by how much — not the pixels.
- **`tools/verify_navigation.tscn`** — asserts the island is baked, that a route past a boulder
  bends around it, that a spawn point inside one is refused, and — the only check straight-line
  chasing cannot pass — that a farmhand with a boulder between him and the player still gets there.
- **`tools/verify_combat.tscn`** — asserts that a jab deals its tabled damage, that a perfect hit
  multiplies it, that the chain window opens and closes where the design says, that a perfect parry
  negates, and that a farmhand left alone crosses the arena and connects. It runs as a **scene**,
  not with `--script`: `--script` starts no autoloads, so every script touching the `EventBus`
  would fail there for the wrong reason.

Booting the game headless (`--quit-after`) and failing on any error *or warning* catches more than
either, for a tenth of the effort.
