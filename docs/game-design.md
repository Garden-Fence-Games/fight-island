# Game design

**This document is the single source of truth for every number in the game.** Once `data/*.tres`
exists, the tables here and those resources must agree, and they move in the same pull request.

## Pitch

You land alone on an island. Enemies come in waves. You have three things to fight with — your
fists, a wooden stick you pick up, and a gun — and which one you hold matters far less than when
you press the button. Every wave you clear pays for exactly one upgrade, and no run ever affords
them all.

## Core loop

**Outer:** wave → fight → clear → reward → one upgrade from the merchant → five-second breather →
next wave.

**Inner:** approach → read the telegraph → dodge or parry → punish window → chain attack 1 into 2
into 3 → reset spacing.

## Design pillars

1. **Timing over inventory.** Variety comes from nine attacks with windows, not from a bigger bag.
2. **Scarcity of choice.** One purchase per wave. The interesting decision is what you give up.
3. **Readability.** One player, three farmers and three weapons, all legible from **one fixed
   camera angle**. Every enemy shares a silhouette; only the texture and the behaviour change, and
   the world is only ever seen from one direction.

## The timing system

This is the headline mechanic and it has two layers.

**Layer 1 — the chain window.** Attack 2 only exists if the button is pressed inside attack 1's
chain window; attack 3 likewise after 2. Miss the window and the chain resets to attack 1. A
player who mashes only ever sees the first attack of every weapon.

**Layer 2 — the perfect window.** The last slice of the chain window is *perfect*. A perfect input
applies the damage multiplier plus 0.08 s of hitstop, a bright flash and a sound of its own. The
player should know they nailed it without reading a number.

Input is buffered for **0.15 s**, so a slightly early press still lands inside the window.

Windows are measured from the start of the attack's recovery, and **the windows on attack N
govern the press that produces attack N + 1**. A finisher ends the chain, so it carries no windows
of its own.

**Layer 3 — the chain costs a beat.** Finishing a chain locks out attacking for a moment, measured
from the end of the finisher's recovery. Everything else stays available: dodge, parry, sprint and
movement, because the point is that the player has something to do in the gap. The rhythm is
*commit, then reposition* — the enemy's telegraph read from the other side.

The lockout is charged **per finished chain, never per attack**: stopping at one or two and stepping
out stays free and fast, which is what makes "should I finish this?" a question rather than a
formality. A **perfect** finisher pays less than half, so the game's subject sits on the move that
costs the most.

| Weapon | After a chain | After a perfect finisher |
|---|---|---|
| Fists | 0.35 s | 0.15 s |
| Stick | 0.50 s | 0.22 s |
| Gun | — | — |

**The gun has no lockout on purpose.** Its rhythm is the magazine and the 1.6 s reload, which is a
forced pause with a far better texture than a timer. Two answers to the same question would only
blur both.

Two properties this has to keep, and `tools/verify_combat.tscn` fails if either goes:

- **A press during the lockout is refused, not eaten.** A press a hair early still lands the moment
  the weapon is ready, exactly like the input buffer everywhere else.
- **It survives being hit.** The clock starts when the finisher enters its recovery rather than when
  the recovery ends, so a stagger cannot clear the debt — otherwise taking a hit would be the fast
  way out of it.

**Why it is not just stamina.** A fist chain costs 29 of 100, so mashing already runs the bar dry.
But the Fists track cuts stamina cost by 5% a level, so at level 5 stamina stops being the limiter —
and the rhythm would quietly dissolve for exactly the player who invested in it. The lockout does
not scale with upgrades.

## Player

| | |
|---|---|
| Health | 100, no regeneration |
| I-frames after being hit | 0.40 s |
| Hit-stun | 0.25 s |
| Stamina | 100 |
| Stamina regen | 20/s, after 0.8 s idle — 1.2 s after a whiffed heavy |
| Move speed | 3.2 m/s |
| Sprint speed | 5.0 m/s |
| Turn rate | 720°/s |
| Movement while attacking | none — attacks are committed |

Stamina gates dodge, sprint, parry and melee attacks. It never gates the gun trigger.

**Walking is slower than a farmhand.** 3.2 m/s against his 3.4, so the only thing that outruns a
farmer is a sprint, and a sprint costs stamina — retreat is a decision with a price rather than the
state you sit in. The dodge covers its 3.2 m faster than a sprint could, and does not become the
way to get around: 22 stamina for 3.2 m against 6.6 for the 2.75 m a sprint covers in the same time
is three times the price per metre.

## Weapons

Fists are always available. The **stick** is a ground pickup that spawns during wave 2, the **gun**
during wave 4. Pickups last the whole run; swapping is free and instant.

| Weapon | # | Attack | Damage | Stamina | Windup | Active | Recovery | Chain window | Perfect window | Perfect × | Range | Arc | Stagger |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Fists | 1 | Jab | 8 | 6 | 0.12 | 0.08 | 0.22 | 0.10–0.45 | 0.33–0.45 | ×1.35 | 1.4 m | 70° | 0.10 |
| Fists | 2 | Cross | 12 | 9 | 0.16 | 0.09 | 0.28 | 0.12–0.45 | 0.33–0.45 | ×1.35 | 1.5 m | 70° | 0.15 |
| Fists | 3 | Uppercut | 20 | 14 | 0.28 | 0.12 | 0.50 | — | — | ×1.35 | 1.6 m | 60° | 0.60 |
| Stick | 1 | Backhand | 14 | 10 | 0.20 | 0.12 | 0.30 | 0.14–0.50 | 0.38–0.50 | ×1.35 | 2.4 m | 120° | 0.15 |
| Stick | 2 | Return | 18 | 12 | 0.22 | 0.12 | 0.34 | 0.16–0.50 | 0.38–0.50 | ×1.35 | 2.4 m | 120° | 0.20 |
| Stick | 3 | Overhead | 30 | 18 | 0.45 | 0.14 | 0.65 | — | — | ×1.35 | 2.6 m | 45° | 0.90 |
| Gun | 1 | Single shot | 22 | 0 | 0.10 | hitscan | 0.35 | 0.08–0.40 | 0.28–0.40 | ×1.25 | 25 m | 2° | 0.10 |
| Gun | 2 | Double tap | 2 × 16 | 0 | 0.08 | hitscan | 0.55 | 0.10–0.45 | 0.33–0.45 | ×1.25 | 22 m | 3° | 0.15 |
| Gun | 3 | Charged shot | 55 | 12 | 0.70 charge | hitscan | 0.60 | — | — | ×1.50 | 30 m | 1° | 1.10 |

A finisher has no windows of its own: the press that produced it was timed against the previous
attack's recovery, and its perfect multiplier applies to that press.

**Implemented in M1:** the fists, exactly as tabled above. `tools/verify_combat.tscn` asserts the
jab's damage, the perfect multiplier, both chain-window boundaries, the chain lockout and the parry
outcome, so the table and `data/attacks/*.tres` cannot drift apart unnoticed.

**Ammunition.** Magazine 6, reload 1.6 s. The reserve starts at 24 and each cleared wave grants
**+8**. Attacks 1/2/3 cost 1/2/1 rounds; attack 2 needs at least 2 in the magazine.

**Sanity check on the full chain:** fists 40 damage over 1.55 s for 29 stamina; stick 62 over
2.39 s for 40 stamina; gun 109 over 1.78 s for 4 rounds and 12 stamina. Fists are the safe
default, the stick trades commitment for reach and crowd control, the gun is the burst you ration.

## Defensive kit

| Action | Stamina | Duration | I-frames | Notes |
|---|---|---|---|---|
| Dodge roll | 22 | 0.55 s | 0.30 s, from 0.05 s | 3.2 m travel; direction from the move vector, backward if neutral; 0.15 s cooldown |
| Sprint | 12/s | held | — | needs ≥ 10 stamina to start, cancels on attack, 0.25 s ramp |
| Parry — perfect | 10 on press | window 0.00–0.12 s | full negate | attacker staggered 1.0 s, **+25 stamina refunded**, 0.10 s hitstop |
| Parry — late | 10 on press | window 0.12–0.22 s | 50 % reduction | player staggered 0.25 s, no refund |
| Parry — missed | 10 on press | 0.22–0.45 s recovery | none | fully vulnerable — the cost of mashing |

Parry is a **tap**, not a held stance. One defensive button, and all the difficulty in the timing.

## The water

Wading costs speed, for the player and for the enemies alike — full speed at the waterline, down to
a third of it at the wading limit. It is the cheapest way to make the shoreline mean something: the
beach stops being scenery and becomes somewhere you think twice about being caught. Enemies pay the
same toll, so backing into the shallows is a real decision rather than a free escape.

## Enemies

Three farmers, **one rig and one mesh, three textures**. They are behaviourally distinct — three
identical bodies in different shirts would be decoration, not design — and together they form a
triangle that stops any single answer from working.

| | Farmhand | Reaper | Thrower |
|---|---|---|---|
| Role | the swarm | the bruiser | the pressure |
| Health | 45 | 90 | 40 |
| Damage | 8 | 16 | 10 |
| Move speed | 3.4 m/s | 2.4 m/s | 2.8 m/s |
| Windup — the telegraph | 0.45 s | 0.75 s | 0.60 s |
| Active | 0.12 s | 0.18 s | projectile |
| Recovery | 0.60 s | 0.95 s | 0.80 s |
| Reach | 1.6 m, 60° | 2.8 m, **160°** | 14 m |
| Poise | 15 | 30 | 10 |
| Notices the player at | 9 m | 9 m | 12 m |
| Rouses others within | 7 m | 7 m | 7 m |
| Money on kill | 2 | 5 | 4 |
| Enters at wave | 1 | 3 | 5 |

**A farmer minds his own business until he notices you.** He stands where he appeared; he does not
set off from the horizon. This is what lets a wave build instead of arriving as one flat press — the
player sees a farmer before the farmer sees them, and distance carries information again.

Three rules make that read as calm rather than as broken:

- **Noticing spreads.** A roused farmer rouses everyone within 7 m, so a group turns together. One
  waking alone while the two beside him keep staring at the sea looks like a bug.
- **Being hit always wakes him**, whatever the distance. Without it the thrower could plink at
  someone from outside their own notice radius forever.
- **Noticing is one way.** He does not lose interest because the player stepped back. A leash would
  make the edge of every crowd breathe in and out.

The radius has to stay well under the twelve metres the spawn search keeps bodies away from the
player, or farmers arrive already awake and none of this exists.

**Farmhand.** Bare hands, quick, fragile, and always the majority of a wave. He is what teaches the
parry, and what makes a crowd feel like a crowd.

**The arc is enforced, not approximated.** A hitbox is a box around the attacker wide enough to hold
everything the swing could reach, and a contact is then confirmed against the weapon's own `reach`
and `arc_degrees`. The box used to *be* the shape — a rectangle from the nose out to the reach — and
it was wrong at both ends: its corners reached half again the weapon's length, and because it ran
from the attacker's nose backwards it clipped the arc short of its own angle, so a 160° sweep was
never 160°. Whichever way that box was sized, the number here was not the number the player felt.

**Reaper.** A scythe on a wide horizontal sweep. The 160° arc is the point: **sidestepping does not
work on him** — you dodge backward, dodge through, or parry. He is slow enough to be read and
punishing enough that reading him matters. He is also the reason the stick exists.

**Thrower.** Stays at range and lobs stones. The projectile is slow enough to sidestep, so he is
never unfair, but he **never stops** — he retreats when the player comes within 5 m. He is what
stops the player from camping one corner, and he is the single best argument for the gun.

## Enemy AI

States: `Spawn → Idle → Chase → Strafe → WindUp → Attack → Recover`, plus `Stagger`, `Flinch`,
`Dead`. The thrower adds `Retreat`.

Three global rules keep a crowd fair rather than unfair:

- **A melee attack-token pool of 2.** Only two melee enemies may be in `WindUp` or `Attack` at
  once; the rest strafe.
- **A separate ranged token of 1.** Throwers queue on their own, so at most one stone is in the
  air. Sharing the melee pool would let throwers starve the melee enemies and make waves passive.
- **Minimum 1.2 m separation** steering, so bodies never stack into an unreadable blob.

## Elites

From wave 4, any archetype can roll elite: the same scene with health ×2.0, damage ×1.4, scale
×1.15, an emissive tint and 3× money. **No new model and no new texture** — an elite must read as
"that one, but worse", instantly.

## Waves

`n` is the wave index, 1-based.

```
enemy_count(n)   = 3 + floor(n * 1.6)                    # w1=4  w5=11  w10=19  w15=27
max_alive(n)     = clamp(4 + floor(n * 0.8), 4, 12)
hp_mult(n)       = 1.0 + 0.18 * (n - 1)                  # w15 = 3.52
dmg_mult(n)      = 1.0 + 0.10 * (n - 1)                  # w15 = 2.40
speed_mult(n)    = min(1.0 + 0.03 * (n - 1), 1.35)
windup_mult(n)   = max(1.0 - 0.02 * (n - 1), 0.75)
elite_chance(n)  = n < 4 ? 0.0 : min(0.10 + 0.05 * (n - 4), 0.40)
```

The telegraph shortens with the waves but never drops below 0.75 of its base. An unreadable
telegraph is not difficulty.

### Composition

Each spawn rolls an archetype against the wave's mix. The result is rounded to whole enemies, and
the farmhand always takes the remainder.

| Wave | Farmhand | Reaper | Thrower |
|---|---|---|---|
| 1–2 | 100 % | — | — |
| 3–4 | 80 % | 20 % | — |
| 5–7 | 65 % | 20 % | 15 % |
| 8–11 | 50 % | 30 % | 20 % |
| 12–15 | 40 % | 35 % | 25 % |

A wave never opens with a thrower: the first spawn of every wave is melee, so the player is never
shot at before anything is on screen.

**Implemented in M2.** `data/waves/standard.tres` carries every coefficient above, and
`tools/verify_waves.tscn` asserts the table and the resource still agree — including the floors and
ceilings, which are what a tuning pass is most likely to break. The composition bands are in the
resource in full; the reaper and thrower rows name archetypes that do not exist yet, and a band
normalises over what it can actually spawn, so those rows cost nothing until #8 and #9 land.

### The intended shape

Waves 1–3 teach. 4–7 add pressure through numbers. 8–11 introduce elites and force weapon
rotation. 12–15 are an endurance test of the defensive kit.

## Economy

```
wave_reward(n)      = 50 + 12 * (n - 1)                  # w1=50  w10=158  w15=218
flawless_bonus      = +30 % if the wave was cleared without taking damage
kill_bonus          = 2 per enemy, 6 per elite
upgrade_cost(level) = round_to_5(50 * pow(1.6, level))   # 50, 80, 130, 205, 330
```

Fifteen waves with no flawless bonus earn about **2 010** plus kills. Maxing a single track costs
**795**, so a run affords roughly two full tracks and change. That gap is the design.

### Upgrade tracks

Level cap 5, one purchase per wave, bought from the merchant. Leftover money carries over.

| Track | Per level | At level 5 |
|---|---|---|
| Health | +20 max HP, heals to full on purchase | 200 HP |
| Stamina | +15 max stamina, +2/s regen | 175 stamina, 30/s |
| Fists | +15 % damage, −5 % stamina cost | ×1.75 damage, −25 % cost |
| Stick | +15 % damage, +5 % range and arc | ×1.75 damage, 3.1 m reach |
| Gun | +15 % damage, +1 magazine, +6 reserve | ×1.75 damage, magazine 11 |

## Win and lose

A run is 15 waves; clearing wave 15 is a **victory** and unlocks an endless mode that continues
the same formulas past `n = 15`. Reaching 0 HP ends the run immediately — there is no revive.

The run is saved between waves. Forty minutes is too long to lose to a closed laptop.

## Feel and feedback budget

Hitstop on perfect hits and perfect parries only. Screenshake on the three finishers and on taking
damage, with a slider in the options. Camera kick on the charged shot. Damage numbers exist but
are **off by default** — the feedback should be felt.

## Out of scope for v1

Multiplayer · a fourth weapon · a fourth enemy · a boss · a second biome · progression carried between runs. Each
is a different game; adding one before wave 15 is tuned is how this one stops shipping.

## Tuning protocol

Change the `.tres`, update the table in this file, and say why in the pull request body. Both
halves in the same PR — a number that disagrees with this document is a bug in the document.
