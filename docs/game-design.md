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
applies the damage multiplier plus the attack's own hitstop, a bright flash and a sound of its
own. The
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

| Weapon | # | Attack | Damage | Stamina | Windup | Active | Recovery | Chain window | Perfect window | Perfect × | Range | Arc | Stagger | Poise |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Fists | 1 | Jab | 8 | 6 | 0.12 | 0.08 | 0.22 | 0.10–0.45 | 0.33–0.45 | ×1.35 | 1.4 m | 70° | 0.10 | 10 |
| Fists | 2 | Cross | 12 | 9 | 0.16 | 0.09 | 0.28 | 0.12–0.45 | 0.33–0.45 | ×1.35 | 1.5 m | 70° | 0.15 | 12 |
| Fists | 3 | Uppercut | 20 | 14 | 0.28 | 0.12 | 0.50 | — | — | ×1.35 | 1.6 m | 60° | 0.60 | 20 |
| Stick | 1 | Backhand | 14 | 10 | 0.20 | 0.12 | 0.30 | 0.14–0.50 | 0.38–0.50 | ×1.35 | 2.4 m | 120° | 0.15 | 15 |
| Stick | 2 | Return | 18 | 12 | 0.22 | 0.12 | 0.34 | 0.16–0.50 | 0.38–0.50 | ×1.35 | 2.4 m | 120° | 0.20 | 18 |
| Stick | 3 | Overhead | 30 | 18 | 0.45 | 0.14 | 0.65 | — | — | ×1.35 | 2.6 m | 45° | 0.90 | 35 |
| Gun | 1 | Single shot | 22 | 0 | 0.10 | hitscan | 0.35 | 0.08–0.40 | 0.28–0.40 | ×1.25 | 25 m | 2° | 0.10 | 8 |
| Gun | 2 | Double tap | 2 × 16 | 0 | 0.08 | hitscan | 0.55 | 0.10–0.45 | 0.33–0.45 | ×1.25 | 22 m | 3° | 0.15 | 8 |
| Gun | 3 | Charged shot | 55 | 12 | 0.70 charge | hitscan | 0.60 | — | — | ×1.50 | 30 m | 1° | 1.10 | 30 |

A finisher has no windows of its own: the press that produced it was timed against the previous
attack's recovery, and its perfect multiplier applies to that press.

**Poise** is what a hit takes off an enemy's stagger meter — 15 on a farmhand, 30 on a reaper,
10 on a thrower. It had been in the resources since M1 with no row here, which is the drift this
document exists to prevent, so it is tabled now. Read it against those three numbers: **the stick's
overhead is the only single blow that staggers a reaper**, which is a large part of why the stick is
the answer to him.

**All three weapons are in**, exactly as tabled above. `tools/verify_combat.tscn` asserts the fists'
damage, the perfect multiplier, both chain-window boundaries, the chain lockout and the parry
outcome; `tools/verify_weapons.tscn` asserts the stick's and the gun's figures, that one 120° sweep
reaches two bodies standing inside it, and that the ammunition behaves as written below.

**Ammunition.** Magazine 6, reload 1.6 s. **The player never holds more than 30 rounds, magazine
included** — the gun arrives at exactly that, 6 in it and 24 in the pocket. Attacks 1/2/3 cost
1/2/1 rounds; attack 2 needs at least 2 in the magazine.

**Nothing refills on a clock.** A cleared wave pays money and not one round. Ammunition enters a
run two ways: **one body in eight leaves a round behind**, and the gun track hands over **+6** the
moment it is bought. That is the whole of the gun's rhythm, and it points the opposite way to the
usual one: an empty pocket is a reason to close on the next farmer rather than to back away from
him. A player who empties it in wave 6 carries that into wave 7 and answers it with the stick until
the bodies pay him back. It is also why the gun has no chain lockout — two answers to the same
question would be one too many.

**The ceiling counts the magazine**, which is what makes the gun track's +1 magazine a rhythm
upgrade rather than a supply one: one more shot before a reload, out of the same thirty.

**The charged shot is held, and letting go early cancels it.** The windup only advances while the
button is down; releasing before it completes abandons the shot and hands the round back, but not
the stamina. Deciding to charge is the commitment, and a cost that can be taken back is not one.
*(The table gives the charged shot no windows of its own, so it is a finisher like the uppercut and
the overhead: the press that produced it was timed against attack 2's recovery, and that press's
perfect flag is the one that applies.)*

**A shot is a ray, resolved the instant the windup ends.** No active frames, because a bullet has
no travel and a farmer must not be able to walk into a shot already fired. **Terrain does not stop
it** — a round currently passes through a boulder, which is a question this document has never
answered either way.

**Sanity check on the full chain:** fists 40 damage over 1.55 s for 29 stamina; stick 62 over
2.39 s for 40 stamina; gun 109 over 1.78 s for 4 rounds and 12 stamina. Fists are the safe
default, the stick trades commitment for reach and crowd control, the gun is the burst you ration.

## Defensive kit

| Action | Stamina | Duration | I-frames | Notes |
|---|---|---|---|---|
| Dodge roll | 22 | 0.55 s | 0.30 s, from 0.05 s | 3.2 m travel; direction from the move vector, backward if neutral; 0.15 s cooldown |
| Sprint | 12/s | held | — | needs ≥ 10 stamina to start, cancels on attack, 0.25 s ramp |
| Parry — perfect | 10 on press | window 0.00–0.12 s | full negate | attacker staggered 1.0 s, **+25 stamina refunded**, 12 frames of hitstop — the whole budget |
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

`n` is the wave index, 1-based. **A wave lasts six minutes** — see *The day and the night* below —
so `enemy_count` is a budget the island draws on to stay populated for that long, not a queue to be
emptied. `max_alive(n)` is what the player actually faces at once, and it is the real pressure dial.

```
enemy_count(n)   = 12 + floor(n * 6)                     # w1=18  w5=42  w10=72  w15=102
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

## The day and the night

**A wave is one turn of the day.** It opens at first light, the sun climbs, goes down partway
through, and the player finishes it in the dark. Survive the night and the wave is passed — a
banner says so, and the next wave begins at daybreak.

```
Dawn 0:30  →  Day 2:15  →  Dusk 0:30  →  Night 2:45    = six minutes, one wave
07:00         09:00        18:00         19:00          → back to 07:00
```

This is what makes a wave a **ramp the player can see coming** rather than a flat block of
difficulty. They are not told the wave is about to get harder; the light tells them.

### What night changes

| | Dawn | Day | Dusk | Night |
|---|---|---|---|---|
| Opens at | 07:00 | 09:00 | 18:00 | 19:00 |
| Lasts | 0:30 | 2:15 | 0:30 | 2:45 |
| Damage | ×1.00 | ×1.00 | ×1.10 | ×1.25 |
| Telegraph | ×1.00 | ×1.00 | ×0.95 | ×0.88 |
| Rousing carries | ×1.0 | ×1.0 | ×1.4 | ×2.0 |
| Melee attack tokens | 2 | 2 | 2 | 3 |

**Dawn carries the day's rules on purpose.** It is thirty seconds taken off the day, not added to
the wave, and every rule in its column is the day's — so the ramp, the economy and how long a wave
lasts are exactly what they were before there was a dawn. What it buys is the read: a player who
starts in low orange light and watches the sun climb has been shown the shape of the turn before
the first thing in it tries to kill them.

**The turn only ever gets meaner, in that order.** Damage and rousing never fall from one phase to
the next, the telegraph never lengthens, and the token pool never shrinks. A phase added for its
look has to sit where its rules already belong — and no single number in this table looks wrong on
the way to breaking that.

**Damage and telegraph are fixed when a farmer arrives**, not looked up when he swings. A farmer who
walked on in daylight stays a daylight farmer for the rest of his life; nightfall changes who
arrives next. Nobody's wind-up changes halfway through itself.

**Rousing and the token pool are global, and they change the moment the sun does.** Rousing is the
one that changes the shape of the fight rather than its numbers: in daylight the player can pick
off the edge of a crowd, after dark one farmer noticing turns the whole beach. The third melee
token is the other — two farmers committing at once is a fight you can answer, three is one you
have to give ground to.

**Noticing is deliberately not scaled.** A farmer arrives between 12 m and 26 m away and the
thrower already notices at 12 m — any night bonus and every wave charges from the horizon again.

**The telegraph floor wins.** Night multiplies the wind-up *before* `windup_floor`, never after, so
it shortens telegraphs in the early waves and does nothing at all past wave 9. An unreadable
telegraph is not difficulty whatever time it is; late-night pressure is the damage and the third
token instead.

### Ending a wave

A wave ends when its night does, or earlier if the roster runs out and nothing is left standing —
which is what a player fast enough to outpace the island has earned. Bodies still on their feet at
daybreak are **sent home rather than killed**: the wave is passed, and nobody is paid for a fight
that did not happen.

**Consequence, stated plainly:** fifteen waves at six minutes is about an hour and a half of play,
not the forty minutes this document used to assume. The wave length is one number in
`data/day/`, and shortening the run is a matter of changing it or of shipping fewer waves.

### The clock and the sky

The HUD shows the hour. It is exact at every phase boundary — 07:00 when the wave starts, 09:00
when the sun is properly up, 18:00 when it starts going down, 19:00 when night falls — so the face
and the sky never disagree about the moment the rules changed.

Each phase holds its look for three quarters of its span and turns into the next across the last
quarter, which is where the sunset lives.

**Night has to stay readable.** Ambient energy goes *up* at night to compensate for a black sky,
and `tools/verify_day_night.tscn` holds night's total light above a floor — a telegraph nobody can
see is not difficulty either.

**Implemented in M2.** The table above is `data/day/`, and the headless check asserts the two still
agree.

## Economy

```
wave_reward(n)      = 50 + 12 * (n - 1)                  # w1=50  w10=158  w15=218
flawless_bonus      = +30 % if the wave was cleared without taking damage
kill_bonus          = 2 per enemy, 6 per elite
finisher_bonus      = ×2 on the body the third hit of a combo kills
upgrade_cost(level) = round_to_5(50 * pow(1.6, level))   # 50, 80, 130, 205, 330
```

The finisher bonus is the one economic lever the player earns with their hands rather than with
their patience. It multiplies, so an elite finished on the third hit pays `2 × 3 × 2 = 12` against a
farmhand's ordinary 2 — and the only way to reach it is to chain twice, because a fresh attack always
starts at the first hit.

It lives on the attack, beside the damage multiplier for perfect timing, and **every weapon's third
attack carries it**: `fist_uppercut`, `stick_overhead`, `gun_charged`. All three weapons therefore
reward finishing equally, so the bonus never argues with the choice of weapon — that choice is
already paid for in reach, stamina and ammunition.

A note on what this rewards, since it is a real cost: lining the uppercut up on a nearly-dead body
means holding the first two hits back, so the bonus asks the player to plan a kill rather than to
mash one. That is the intended trade, and it is why the figure is ×2 rather than an elite's ×3 —
enough to be worth aiming for, not enough to make finishing every body the only correct way to play.

Fifteen waves with no flawless bonus earn about **2 010** plus kills. Maxing a single track costs
**795**, so a run affords roughly two full tracks and change. That gap is the design.

### Upgrade tracks

Level cap 5, one purchase per wave, bought from the merchant. Leftover money carries over.

| Track | Per level | At level 5 |
|---|---|---|
| Health | +20 max HP, heals to full on purchase | 200 HP |
| Stamina | +15 max stamina, +2/s regen | 175 stamina, 30/s |
| Fists | +15 % damage, −5 % stamina cost | ×1.75 damage, −25 % cost |
| Stick | +15 % damage, +5 % range and arc | ×1.75 damage, 3.0 m reach |
| Gun | +15 % damage, +1 magazine, +6 rounds handed over on purchase | ×1.75 damage, magazine 11 |

## Win and lose

A run is 15 waves; clearing wave 15 is a **victory** and unlocks an endless mode that continues
the same formulas past `n = 15`. Reaching 0 HP ends the run immediately — there is no revive.

The run is saved between waves. Forty minutes is too long to lose to a closed laptop.

## Feel and feedback budget

Every one of these effects is individually an improvement and collectively a mess. A hit that stops
time, shakes the screen, flashes the body and kicks the camera is not four times as satisfying — it
is unreadable, and reading a fight is the whole subject. So the emphasis on a blow is **decided in
one table and spent once**, in `scripts/systems/emphasis.gd`, rather than accumulated by whoever
happens to be emitting at the time.

| what happened | stops the clock for | shakes |
|---|---|---|
| A hit that is only a hit | — | — |
| **Perfect hit** | the attack's own figure, 0.06–0.18 s | — |
| Finisher | — | 0.6 |
| A body dies | 3 frames | 0.3 |
| **Perfect parry** | **12 frames — the whole budget** | — |
| The player is hit | — | **1.0** |
| A wave is cleared | — | — |

Three rules hold it together, and `tools/verify_feel.tscn` holds all three:

- **One blow, one spend.** A perfect finisher that kills is one event, not three: the loudest figure
  on each channel wins and nothing is summed. Added up, that blow would stop for 0.20 s and shake at
  0.9; it stops for 0.18 and shakes at 0.6.
- **There is a ceiling** — twelve frames, a fifth of a second, past which a stop reads as the game
  hitching rather than as weight. Written in frames because that is the unit a stop is felt in.
- **Nothing shouts over a telegraph.** A shake requested while anything *in shot* is winding up is
  refused outright. The camera is fixed precisely so a wind-up can never be hidden, and a screen that
  jumps while a farmer commits hands that back. A farmer committing off screen refuses nothing.

A stop **never eats a press**: the input buffer ages on the same scaled clock the stop slows, so a
hitstop lengthens the buffer in real time rather than spending it.

Two things this table says that the game did not say before it was written. **Taking a hit shook
nothing** — the code beside the shake call described "the three finishers and on taking damage" and
only ever did the first. And the **longest stop in the game belonged to the charged shot**, not to
the perfect parry, so the most skilful input in the game was quieter than a held trigger.

Damage numbers exist but are **off by default** — the feedback should be felt.

**Rumble does not exist yet.** When it does it comes through this table like everything else, and it
is off whenever the screen-shake slider is at zero.

### The visible half

A landed hit throws debris and a flare; a **perfect** one throws more of it, further, for longer,
with a brighter flare. Three differences at once, because damage numbers are off by default and the
effect is what carries the information instead — and any single difference is one the player has to
be told about rather than one they notice.

**An enemy winding up currently shows nothing.** There was a ring on the ground that filled as the
telegraph ran; it has been taken out, and the wind-up animation meant to replace it is not authored.
Until it is, the only tell is that the farmer has stopped moving — the timings in this document are
unchanged, and every one of them is harder to answer than the numbers say.

When it comes back it comes back on the body, and it owes three things the ring paid: it must be a
**shape rather than a colour**, because colour alone fails a colourblind player, a greyscale
screenshot and a camera twenty metres up; it must be **the same tell for every archetype**, because
a signal per farmer is one more thing to learn in the half second there is to read it; and it must
be **driven by the wind-up's own duration**, which shortens with the waves and with the hour, so the
picture and the timing cannot drift apart.

### The ring is the reward

The subject of this game is timing, and **the eye is on the enemy** — not on the player, and not on
the flash around their own fist. So the perfect window has to be audible, and a wave lasting six
minutes only makes that more true: a window the player can only *see* is a window they will miss.

Five sounds, synthesised at startup rather than shipped as files, and one idea runs through them:

| | |
|---|---|
| Normal hit | a thud that stops |
| **Perfect hit** | the same thud, plus a bright partial that keeps going |
| Whiff | filtered air, and **no transient at all** — nothing was struck, so nothing snaps |
| **Perfect parry** | a bell, three partials, the longest sound in the game |
| Late parry | the same bell, damped: one partial, a fifth of the length |

**Nothing differs by loudness alone.** Loudness is the first thing a player turns down and the first
thing a busy fight buries. What separates each pair is the tail — how long it rings, and for the two
hits, *what* is ringing: the perfect one carries a partial the plain one does not contain at all.

`tools/verify_audio.tscn` measures exactly that, because nobody can listen to a check: each tail has
to outlast its plain version by at least twice, the perfect hit's tail has to be three times
brighter than the plain one's, and a whiff's opening must stay well under a hit's.

### The body is the weapon, the ring is the timing

A fist, a stick and a round do not land alike, so each has its own **body** — pitch, how long it
rings, how much contact grain sits on top:

| | body |
|---|---|
| Fists | 150 Hz, gone in 35 ms — a dull knock on a body |
| Stick | 240 Hz, twice as long, and more contact — wood that cracks and carries |
| Gun | 320 Hz, over in 22 ms — sharp, and the crack that threw it was a separate sound |

What they must **never** differ in is the partial the perfect window adds. It is 1320 Hz in all
three, because it is the signature of the entire game: a player who learns it on fists has to have
learnt it on the gun, and three signatures would be three things to learn in the half second there
is to read one. The check measures that partial at its own frequency rather than as brightness —
brightness reported the stick a third duller and was right to, because its body is still ringing
under the tail, which is a true fact about the body and says nothing about the signature.

The fists keep the plain `hit` and `perfect` ids rather than getting a fourth waveform. They are the
weapon the player never puts down and never runs out of, so a blow in this game sounds like a fist
landing unless something else is in hand.

### Three archetypes, three warnings

Every wind-up **climbs** — a warning that does not rise reads as a drone — and they differ in where
they climb from and to, which is the one thing that survives three of them at once in a crowd at
night:

| | climbs | over |
|---|---|---|
| Farmhand | 300 → 690 Hz | 0.30 s |
| Reaper | 150 → 300 Hz | 0.42 s |
| **Thrower** | **520 → 1240 Hz** | 0.36 s |

The thrower is the outlier on purpose. He strikes from fourteen metres and is the one archetype the
player may never see coming, so sound is the only warning the design gives them: his is the highest,
the longest climb, and the only one that crosses an octave. The check fails if any other archetype
climbs as high as his.

### Running dry is announced a round early

The shot that leaves **one** round in the magazine plays two short dry clicks a semitone apart.
Running out is a designed moment and the answer to it is to close on the next farmer rather than
back away from him — which is a decision the player has to be able to make before the trigger stops
answering, not after. Two rounds would be a warning heard most of a wave before it mattered.

## Out of scope for v1

Multiplayer · a fourth weapon · a fourth enemy · a boss · a second biome · progression carried between runs. Each
is a different game; adding one before wave 15 is tuned is how this one stops shipping.

## Tuning protocol

Change the `.tres`, update the table in this file, and say why in the pull request body. Both
halves in the same PR — a number that disagrees with this document is a bug in the document.

### Where the evidence comes from

A debug build appends one row per wave to `user://telemetry.csv` — see
[architecture.md](architecture.md). It exists so the three claims this document makes that it cannot
argue for itself can each be answered with data rather than with a feeling:

| The claim | The columns that answer it |
|---|---|
| *The intended shape* — 1–3 teach, 4–7 pressure, 8–11 rotate weapons, 12–15 endure | `wave`, `outcome`, `seconds`: where runs actually end, and whether the time a wave takes climbs the way the shape says it should |
| *A run affords roughly two full tracks and change* — see **Economy** | `earned` and `spent`, summed over a run |
| *Five tracks are five choices* | `bought` across runs. **Stamina is the prime suspect**: surviving beats killing fast when death is final, and a track chosen by everyone every run is not a track, it is a mandatory step wearing a costume |

None of those figures is a balance value, so none of them belongs in a `.tres`. They are what a
balance value is argued from.
