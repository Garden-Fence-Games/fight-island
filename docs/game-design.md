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
3. **Readability.** Two characters and three weapons, all legible from a high angled camera.

## The timing system

This is the headline mechanic and it has two layers.

**Layer 1 — the chain window.** Attack 2 only exists if the button is pressed inside attack 1's
chain window; attack 3 likewise after 2. Miss the window and the chain resets to attack 1. A
player who mashes only ever sees the first attack of every weapon.

**Layer 2 — the perfect window.** The last slice of the chain window is *perfect*. A perfect input
applies the damage multiplier plus 0.08 s of hitstop, a bright flash and a sound of its own. The
player should know they nailed it without reading a number.

Input is buffered for **0.15 s**, so a slightly early press still lands inside the window.

Windows are measured from the start of the attack's recovery.

## Player

| | |
|---|---|
| Health | 100, no regeneration |
| I-frames after being hit | 0.40 s |
| Hit-stun | 0.25 s |
| Stamina | 100 |
| Stamina regen | 20/s, after 0.8 s idle — 1.2 s after a whiffed heavy |
| Move speed | 4.2 m/s |
| Sprint speed | 6.6 m/s |
| Turn rate | 720°/s |
| Movement while attacking | none — attacks are committed |

Stamina gates dodge, sprint, parry and melee attacks. It never gates the gun trigger.

## Weapons

Fists are always available. The **stick** is a ground pickup that spawns during wave 2, the **gun**
during wave 4. Pickups last the whole run; swapping is free and instant.

| Weapon | # | Attack | Damage | Stamina | Windup | Active | Recovery | Chain window | Perfect window | Perfect × | Range | Arc | Stagger |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Fists | 1 | Jab | 8 | 6 | 0.12 | 0.08 | 0.22 | 0.10–0.45 | 0.33–0.45 | ×1.35 | 1.4 m | 70° | 0.10 |
| Fists | 2 | Cross | 12 | 9 | 0.16 | 0.09 | 0.28 | 0.12–0.45 | 0.33–0.45 | ×1.35 | 1.5 m | 70° | 0.15 |
| Fists | 3 | Uppercut | 20 | 14 | 0.28 | 0.12 | 0.50 | finisher | 0.00–0.10 | ×1.35 | 1.6 m | 60° | 0.60 |
| Stick | 1 | Backhand | 14 | 10 | 0.20 | 0.12 | 0.30 | 0.14–0.50 | 0.38–0.50 | ×1.35 | 2.4 m | 120° | 0.15 |
| Stick | 2 | Return | 18 | 12 | 0.22 | 0.12 | 0.34 | 0.16–0.50 | 0.38–0.50 | ×1.35 | 2.4 m | 120° | 0.20 |
| Stick | 3 | Overhead | 30 | 18 | 0.45 | 0.14 | 0.65 | finisher | 0.00–0.12 | ×1.35 | 2.6 m | 45° | 0.90 |
| Gun | 1 | Single shot | 22 | 0 | 0.10 | hitscan | 0.35 | 0.08–0.40 | 0.28–0.40 | ×1.25 | 25 m | 2° | 0.10 |
| Gun | 2 | Double tap | 2 × 16 | 0 | 0.08 | hitscan | 0.55 | 0.10–0.45 | 0.33–0.45 | ×1.25 | 22 m | 3° | 0.15 |
| Gun | 3 | Charged shot | 55 | 12 | 0.70 charge | hitscan | 0.60 | finisher | release 0.60–0.75 | ×1.50 | 30 m | 1° | 1.10 |

A finisher has no chain window; its perfect window is on the press, timed against the previous
attack's recovery.

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

## Enemy

| | |
|---|---|
| Health | 60 |
| Contact damage | 10 |
| Move speed | 3.0 m/s |
| Aggro radius | 18 m |
| Attack range | 1.8 m |
| Windup — the telegraph | 0.55 s |
| Active | 0.15 s |
| Recovery | 0.70 s |
| Poise | 20 — staggers when 20 poise damage lands within 2 s |
| Money on kill | 2 |

States: `Spawn → Idle → Chase → Strafe → WindUp → Attack → Recover`, plus `Stagger`, `Flinch`,
`Dead`.

Two global rules keep a crowd fair rather than unfair:

- **Attack-token pool of 2.** Only two enemies may be in `WindUp` or `Attack` at once; the rest
  strafe.
- **Minimum 1.2 m separation** steering force, so bodies never stack into an unreadable blob.

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

An **elite** is the same enemy scene with health ×2.0, damage ×1.4, scale ×1.15, an emissive tint
and 3× money. No new model — the two-character constraint holds.

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

Multiplayer · a fourth weapon · a boss · a second biome · progression carried between runs. Each
is a different game; adding one before wave 15 is tuned is how this one stops shipping.

## Tuning protocol

Change the `.tres`, update the table in this file, and say why in the pull request body. Both
halves in the same PR — a number that disagrees with this document is a bug in the document.
