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

`arena.tscn` holds `WaveDirector → SpawnDirector → EnemyPool`, in that nesting: the director owns
where bodies come from, which owns the bodies. They are children rather than exported node
references, because node exports do not resolve in a hand-written `.tscn` (ADR 0006).

`WaveDirector.start_wave(n)` reads `WaveConfig`, emits `wave_started`, then **drip-feeds**: the
count is how many arrive in total, `max_alive(n)` is how many the player faces at once, and the gap
between those two is what makes a late wave pressure rather than a wall. `enemy_died` brings the
director back; when nothing is owed and nothing is alive it emits `wave_cleared` with the reward and
starts the breather. The economy and the HUD are listeners — the director does not know they exist.

**Every number comes from the resource**, including the elite chance the elite pass will read. A
table split across two files is a table that starts disagreeing.

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
so height above the ground is simply height above that origin. **A palm arrives as one mesh of two
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
- **`tools/verify_combat.tscn`** also covers the chain lockout: that a finished chain announces
  itself on the bus, refuses a press without consuming it, expires, costs nothing when the player
  stops at two attacks, waits less after a perfect finisher, and never blocks a dodge.
- **`tools/verify_waves.tscn`** — asserts the wave table and `data/waves/standard.tres` still
  agree, then runs a wave: it arrives out of shot and more than twelve metres out, never exceeds
  `max_alive`, clears when the last body dies, pays the tabled reward, and reuses bodies rather than
  making them. The spawn rules are checked against **two hundred points from the search**, not
  against the four a wave happened to use — with the "never in shot" rule deleted, a four-body wave
  still passed, which made that check decorative.
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
