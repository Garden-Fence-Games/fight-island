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
| Health | 100, no regeneration — [coconuts](#coconuts) are the one exception |
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

Fists are always available. The **stick and the gun are both ground pickups from wave 1**, dropped
where the player can see them. Pickups last the whole run; swapping is free and instant — no
animation, no penalty, no cooldown, because the interesting decision is which weapon suits the
moment and not whether the player can afford to find out.

They used to arrive in waves 2 and 4, and holding them back cost more than it bought. A weapon
nobody has found is a weapon that does not exist — and behind the gun sat an upgrade track the
merchant could not sell, so a player saving for it had money with nowhere to go for four waves. The
three weapons are a *choice*, not a drip feed: the whole subject of the game is which one suits the
moment, and that question cannot be asked until all three are in the bag. Ammunition comes off the
bodies from the first wave for the same reason.

**The bag is on screen**, bottom right: the three weapons in the order the key walks along them, the
one in hand lit, the ones carried dim, and the ones nobody has picked up yet dimmer still, badged
with the wave they arrive in instead of a key. A weapon the player owns and cannot see is a weapon
they do not use, and an empty slot says there is something out there to go and find. An unfound slot
is shown rather than hidden for the same reason the merchant shows a locked card.

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
25 on a pirate. It had been in the resources since M1 with no row here, which is the drift this
document exists to prevent, so it is tabled now.

**Poise no longer decides whether an enemy reacts, only how hard.** Every hit that lands throws
him, and therefore opens the next one — that is what makes a combo a combo rather than three swings
at a man who is already walking away. What breaking his poise buys is the difference between rocked
and sprawling: the blow's own `Stagger` figure becomes a push, and a blow that broke poise pushes
**1.8×** as hard. Read the three poise numbers against that: **the stick's overhead is the only
single blow that sends a reaper sprawling**, which is a large part of why the stick is the answer
to him — but every other blow still rocks him and still leaves him open.

The three figures that turn a `Stagger` number into a knockdown — the push per point of it
(12 m/s), the broken-poise multiplier (1.8) and the ceiling below — are one `KnockdownData` in
`data/combat/knockdown.tres`. They are the same conversion for every attack in the game, which is
why they are one resource rather than another column on the table above.

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

## Coconuts

The island's one source of health while a wave is on. **Two sources, doing different jobs:** the
merchant's Health track is bought, costs a wave's money and heals to full; a coconut is walked over
mid-fight and gives back a fixed 25. If a coconut filled the bar there would be no reason to buy
the track.

They fall out of the palms, at random, and land at the foot of the tree they fell from. Walking over
one takes it — no button and no prompt, because a coconut exists to be grabbed in the middle of a
crowd and a prompt there is a moment the player is committed to something other than the fight.
Walking over one at full health leaves it lying.

| | |
|---|---|
| Restores | 25, clamped at maximum HP |
| Owed per wave | 0.15 per enemy in it, rounded down |
| On the island at once | 2 on wave 1, +0.25 a wave, never more than 6 |
| Lands within | 1.6 m of its own palm |
| Lies there for | 20 s, fading over the last 1.2 |
| Palms eligible | 7–24 m from the player |

**The ceiling is the dial.** The supply follows the crowd, so a wave that presses harder supplies
more and the wave tuning does not have to carry a second curve. But the crowd more than doubles over
fifteen waves and a ceiling rising with it would never bind — it would sit above what the rate
produces at every wave and brake nothing, exactly where braking matters. So it rises deliberately
more slowly: more coconuts late on in absolute terms, and fewer per enemy, so the pressure still
climbs while the island is more generous than it was at wave 2.

Whatever a wave does not spend dies with the wave. A wave cleared early handing its unused supply to
the next one is the quiet way a ceiling stops meaning anything.

## The water

Wading costs speed, for the player and for the enemies alike — full speed at the waterline, down to
a third of it at the wading limit. It is the cheapest way to make the shoreline mean something: the
beach stops being scenery and becomes somewhere you think twice about being caught. Enemies pay the
same toll, so backing into the shallows is a real decision rather than a free escape.

## Enemies

Three farmers, **one rig and one mesh, three textures** — and one pirate, who has a model of his own
and is therefore the only body in the game pooled apart. They are behaviourally distinct — identical
bodies in different shirts would be decoration, not design — and together they stop any single
answer from working.

| | Farmhand | Reaper | Pirate |
|---|---|---|---|
| Role | the swarm | the bruiser | the punishment |
| Health | 45 | 90 | 70 |
| Damage | 8 | 16 | **22** |
| Move speed | 3.4 m/s | 2.4 m/s | 3.0 m/s |
| Windup — the telegraph | 0.45 s | 0.75 s | **0.80 s** |
| Active | 0.12 s | 0.18 s | 0.20 s |
| Recovery | 0.60 s | 0.95 s | 0.90 s |
| Reach | 1.6 m, 60° | 2.8 m, **160°** | 2.0 m, 90° |
| Poise | 15 | 30 | 25 |
| Notices the player at | 9 m | 9 m | 9 m |
| Rouses others within | 7 m | 7 m | 7 m |
| Money on kill | 2 | 5 | 8 |
| Enters at wave | 1 | 3 | 4 |

**A farmer minds his own business until he notices you.** He stands where he appeared; he does not
set off from the horizon. This is what lets a wave build instead of arriving as one flat press — the
player sees a farmer before the farmer sees them, and distance carries information again.

Four rules make that read as calm rather than as broken:

- **Noticing spreads.** A roused farmer rouses everyone within 7 m, so a group turns together. One
  waking alone while the two beside him keep staring at the sea looks like a bug.
- **Being hit always wakes him**, whatever the distance. Without it a farmer hit from outside his
  own notice radius could be shot at
  someone from outside their own notice radius forever.
- **Noticing is one way.** He does not lose interest because the player stepped back. A leash would
  make the edge of every crowd breathe in and out.
- **Being ignored wakes him too.** Ten seconds standing unnoticed and he comes looking, rousing the
  men beside him as he goes — half that after dark, because the hour's rousing is the dial that
  already says how fast the island turns on the player.

The radius has to stay well under the twelve metres the spawn search keeps bodies away from the
player, or farmers arrive already awake and none of this exists.

**The fourth rule is what stops the waiting from being the wave.** Standing still is a read, not a
state: without a clock on it, a body nobody walks up to stands there until daybreak, and the player
who has cleared what is near them has to go and fetch the rest one at a time. On a four-minute wave
that is most of the wave spent walking. Ten seconds is long enough to see a farmer arrive and
decide about him, and short enough that the island always comes to you in the end.

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

**Pirate.** A length of wood, swung with both hands. He hits for **22** — nearly three farmhands —
and he is the only archetype that can take a quarter of the player's health off a single mistake.

Two things keep that fair rather than cheap. He telegraphs for **0.80 s**, the longest wind-up in
the game, and his warning is the lowest and the longest of the four: a pirate committing is
audible under a crowd and readable across the island. And **he is a tenth of a wave** — enough that
every wave from the third has some, few enough that he is read one at a time rather than fought as
a crowd.

He is deliberately **not** a heavier reaper. The reaper's 160° sweep is a geometry problem: you
cannot sidestep it. The pirate's 90° arc can be walked out of by anyone who saw it coming, and the
whole of him is whether you did.

## Enemy AI

States: `Spawn → Idle → Chase → Strafe → WindUp → Attack → Recover`, plus `Stagger`, `Flinch`,
`Dead`.

**`Stagger` is two phases, and a knockdown is physics.** A hit hard enough to throw a rigged enemy
hands his skeleton to the simulator: nothing animates while it has him, he tumbles where the blow
sent him, and the body node catches up with wherever his hips came to rest — leaving it where he was
hit would teleport him back in front of the player who just watched him fall. He then **gets up the
way he fell**: off his back he sits up and stands in 1.2 s, off his front he rolls over first and
takes 1.65 s. Those are the clips' own lengths, and the rise lasts exactly as long as the one
playing. A rig without get-up clips falls back to `KnockdownData.rise_time`, 0.7 s. He does not
watch the player while he is down.

The fall ends when he stops moving, which is almost always what happens. When it does not — wedged
against a rock, caught on a slope — he is taken back after **four times the attack's own `Stagger`
figure**, so a jab that tips a man over does not put him down for as long as an uppercut does. An
enemy with no rig, or one whose skeleton did not resolve, falls back to standing still for the
attack's stagger duration, which is what this state used to be.

Two global rules keep a crowd fair rather than unfair:

- **An attack-token pool of 2.** Only two enemies may be in `WindUp` or `Attack` at once; the rest
  strafe. Night widens it to 3, and that is the change a player feels rather than reads.
- **Minimum 1.2 m separation** steering, so bodies never stack into an unreadable blob.

## Elites

From wave 4, any archetype can roll elite: the same scene with health ×2.0, damage ×1.4, scale
×1.15, an emissive tint and 3× money. **No new model and no new texture** — an elite must read as
"that one, but worse", instantly.

## Waves

`n` is the wave index, 1-based. **A wave lasts ninety seconds** — see *The day and the night* below —
so `enemy_count` is a budget the island draws on to stay populated for that long, not a queue to be
emptied.

```
enemy_count(n)   = 16 + floor(n * 1.2)                   # w1=17  w5=22  w10=28  w15=34
max_alive(n)     = clamp(4 + floor(n * 0.8), 4, 14)
hp_mult(n)       = 1.0 + 0.18 * (n - 1)                  # w15 = 3.52
dmg_mult(n)      = 1.0 + 0.10 * (n - 1)                  # w15 = 2.40
speed_mult(n)    = min(1.0 + 0.03 * (n - 1), 1.35)
windup_mult(n)   = max(1.0 - 0.02 * (n - 1), 0.75)
elite_chance(n)  = n < 4 ? 0.0 : min(0.10 + 0.05 * (n - 4), 0.40)
```

The telegraph shortens with the waves but never drops below 0.75 of its base. An unreadable
telegraph is not difficulty.

**The roster is a budget that can be spent.** Once the island is full a body only enters when one
falls, so what the budget costs is a rate of killing — `tools/measure_waves.tscn` measures it at a
little over twenty bodies in ninety seconds, on the stick, at the levels the run affords. The
figures above sit just above that: a wave ends early when the budget runs dry and nothing is
standing, and outrunning a wave is something a good player should be able to do. It was
`12 + floor(n * 6)` when a wave ran four minutes, which after the wave was cut to ninety seconds
promised a hundred and two bodies at wave fifteen and delivered twenty-two.

**The crowd is not what hurts, and `max_alive` is not the damage dial.** `AttackTokens` lets two
bodies commit at once and three at night, in **every wave of the run** — so what the player takes is
the pool's, and what the crowd adds is bodies to walk through, to see past, and to be cut off by.
Both matter and they are not the same lever: incoming damage is carried by `dmg_mult` and by the
mix below, and the crowd is what makes waves twelve to fifteen an endurance test rather than a
harder version of wave six.

### Composition

Each spawn rolls an archetype against the wave's mix. The result is rounded to whole enemies, and
the farmhand always takes the remainder.

| Wave | Farmhand | Reaper | Pirate |
|---|---|---|---|
| 1–2 | 100 % | — | — |
| 3 | 85 % | 15 % | — |
| 4 | 72 % | 18 % | 10 % |
| 5 | 68 % | 22 % | 10 % |
| 6–7 | 64 % | 26 % | 10 % |
| 8–11 | 55 % | 35 % | 10 % |
| 12–15 | 45 % | 45 % | 10 % |

**One new thing at a time, and never in the waves that teach.** Waves 1 and 2 are farmhands and
nothing else, because that is where the player uses what the tutorial taught rather than meeting
somebody new. Then the reaper at 3 and the pirate at 4, each its own step, in the band the design
gives to pressure. From 5 on nothing new arrives and the mix simply hardens: by wave 12 a body on
the island is as likely to be a reaper as a farmhand.

**Ten per cent is a roll per spawn and not a quota.** At wave 5 the island sends twenty-two bodies
and about two of them are pirates; *which* two, and whether it is one or four, is the wave's own
business. A fixed number per wave would be a schedule the player learns. A chance is a thing that
happens to them, and the pirate is the archetype that has to be able to arrive at the wrong moment.

**His share is taken off the other two proportionally, not off the farmhand alone**, so the shape
they make is untouched at every band and the farmhand is still the most common thing on the island
until the very last of them. Ten per cent flat rather than a ramp — he is a hazard, and a hazard
that grows on a schedule stops being one.

**Implemented in M2, tuned in M3.** `data/waves/standard.tres` carries every coefficient above, and
`tools/verify_waves.tscn` asserts the table and the resource still agree — including the floors and
ceilings, which are what a tuning pass is most likely to break. A band normalises over what it can
actually spawn, so a row naming an archetype that is missing costs nothing.

**The curve itself is measured rather than argued about.** `tools/measure_waves.tscn` reads these
resources and prints, for each of the fifteen, the crowd, the hit points standing, the damage coming
in by day and by night, how long the player lives under full contact, and how much of the roster can
physically arrive. It changes nothing and asserts nothing — it is the page a tuning pass is read
off, and re-running it is how the next one starts.

### The intended shape

Waves 1–3 teach. 4–7 add pressure through numbers. 8–11 introduce elites and force weapon
rotation. 12–15 are an endurance test of the defensive kit.

Measured at the night pool, wave to wave, incoming damage steps by about 11 and 14 per cent through
the teaching waves, by 17 to 22 through 4–6 where three archetypes arrive, by 5 to 14 through the
middle, and by under 5 across 12–15 — which is the endurance band doing what it says: nothing new
to understand, and no let-up.

## The day and the night

**A wave is one turn of the day.** It opens at first light, the sun climbs, goes down partway
through, and the player finishes it in the dark. Survive the night and the wave is passed — a
banner says so, and the next wave begins at daybreak.

```
Dawn 0:10  →  Day 0:35  →  Dusk 0:10  →  Night 0:35    = ninety seconds, one wave
07:00         09:00        18:00         19:00          → back to 07:00
 turning       holds 26s    turning       holds 26s      → forty-five of light, forty-five of dark
```

This is what makes a wave a **ramp the player can see coming** rather than a flat block of
difficulty. They are not told the wave is about to get harder; the light tells them.

### What night changes

| | Dawn | Day | Dusk | Night |
|---|---|---|---|---|
| Opens at | 07:00 | 09:00 | 18:00 | 19:00 |
| Lasts | 0:10 | 0:35 | 0:10 | 0:35 |
| Spent turning | all of it | the last quarter | all of it | the last quarter |
| Damage | ×1.00 | ×1.00 | ×1.10 | ×1.25 |
| Telegraph | ×1.00 | ×1.00 | ×0.95 | ×0.88 |
| Rousing carries | ×1.0 | ×1.0 | ×1.4 | ×2.0 |
| Melee attack tokens | 2 | 2 | 2 | 3 |

**Dawn carries the day's rules on purpose.** It is ten seconds taken off the day, not added to
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

**The notice radius is deliberately not scaled.** A farmer arrives between 12 m and 18 m away and
a farmer notices at 9 m — any night bonus on the radius and every wave charges from the
horizon again. What night does scale is the **patience**: ten seconds of standing ignored in
daylight, five after dark, on the same `rouse_scale` that already carries a shout further.

**The telegraph floor wins.** Night multiplies the wind-up *before* `windup_floor`, never after, so
it shortens telegraphs in the early waves and does nothing at all past wave 9. An unreadable
telegraph is not difficulty whatever time it is; late-night pressure is the damage and the third
token instead.

### Ending a wave

A wave ends when its night does, or earlier if the roster runs out and nothing is left standing —
which is what a player fast enough to outpace the island has earned. Bodies still on their feet at
daybreak are **sent home rather than killed**: the wave is passed, and nobody is paid for a fight
that did not happen.

**The light never sits still on the way over.** Dawn and dusk spend **all** of themselves turning,
because that is what they are for; day and night hold their look and turn over their last quarter.
So the sky slides for about nine seconds out of the day, straight through the ten of dusk, into the
night — twenty seconds of continuous change rather than a hold and then a flip. A phase that held
its own look and then handed over in the last few seconds was the abrupt version of the thing dusk
was added to smooth.

**Consequence, stated plainly:** fifteen waves at ninety seconds is about twenty-five minutes of
play. The wave length is four numbers in `data/day/` and nothing else reads it, so changing how long
a run takes is a tuning pass rather than a rewrite — which is exactly how six minutes became four,
and four became ninety seconds.

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

Fifteen waves with no flawless bonus earn **2 010** in wave rewards. Maxing a single track costs
**795**, so the rewards alone afford two full tracks and change. That gap is the design.

**The bodies pay for a third.** About twenty-four a wave are felled at two apiece, which is another
**680** or so across a run and takes it to roughly three and a half tracks out of five — measured by
`tools/measure_waves.tscn`, which counts what can physically be killed rather than what is sent.
`verify_waves` asserts the reward curve and not this total, because how many bodies a player fells
is a fact about the player; the guard rail holds the *shape* — rewards flat, costs geometric — and
the shape is what stops a run from buying everything.

### The sea

**Wading costs speed. Standing in it costs health.** The island is not round, so the boundary has
always been depth rather than a circle: walk down the sand, wade in to the shins, and the sea pushes
back. Nothing is ever blocked, so the edge of the world is felt as the shape of the place.

The push alone was a wall to bounce off — it beats a walk before the water is over a head, so nobody
could ever reach anything out there. Now the bar comes down past the wading limit, faster the deeper
you are:

| | Depth | |
|---|---|---|
| Wading | 0 – 1.1 m | costs speed, down to 35 % at the limit |
| Out of your depth | 1.1 – 1.6 m | the bar comes down, 0 to **20 health a second** |
| Forcing | out of your depth, heading out to sea | that drain **doubles every second** of forcing, up to **×10** |
| Drowned | — | 0 HP ends the run; the body struggles and sinks **1.6 m** at **0.45 m/s** |

**Insisting is exponential.** Forcing is walking out against the push — heading out to sea, within
a 0.3 dot of straight out, in the water that shoves back. Its clock resets the moment the player
stands still, walks along the shore or turns back, so the sea is only merciless to somebody fighting
it: a player drifting out of their depth loses the bar at the ordinary rate, one who keeps pushing
loses it in about three seconds. **Every point of it is still reversible**: stop pushing outward and
the sea carries you back in. There is no line you cross and no threshold that kills —
a threshold is unreadable, the player is fine and then the run is over, while a bar coming down is
on the screen they already watch and it tells them how long they have.

It is the only thing in the game that can end a run **without a fight**, which is why the warning is
the whole of the feature and the death is only where it stops.

### Upgrade tracks

Level cap 5, one purchase per wave, bought from the merchant. Leftover money carries over.

**A weapon's track is not for sale until the weapon is in the bag.** Fifteen per cent more damage on
something the player cannot swing yet is money spent on nothing — a purchase they would only
discover was worthless later, by which time the run has moved on. Both weapons lie on the island
from wave 1 now, so the gate is the few minutes between a wave starting and the weapon being walked
over rather than four waves of a locked card; it stays because *found* is the honest condition and
a wave number never was. The card **stays on the shelf and says where the weapon turns up** rather
than disappearing. The gate is on the purchase itself, not on the button — greying out a card that
`buy()` would still honour is not a gate.

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

### The floor under the switches

Every accessibility switch takes something away, and each of them was written to remove a *visual*:
the shake, the freeze, the flash. They are checked one at a time — the slider means nought at
nought, reduce-flashing damps the flare and leaves the debris — and one at a time is not the
question a player who needs all of them is asking.

So the rule is stated once, and `verify_access` holds it with every switch at the end of its travel
at the same time. **A switch may take away emphasis. It may never take away a signal.** Three things
survive whatever is turned off, and the game cannot be played without any of them:

- **The telegraph**, because it is geometry. A body rears back over its wind-up, and a lean survives
  greyscale, a colourblind player, a camera twenty metres up and every switch in the menu. That is
  the argument for the lean over the ring it replaced, and it is why no colourblind option is needed
  for it.
- **The difference between a perfect hit and an ordinary one**, in more than one way that is neither
  colour nor brightness: more debris, thrown faster, lasting longer. Damage numbers are off by
  default, so the effect is carrying the whole message — and the two things these switches touch are
  exactly colour and brightness.
- **A clock nobody left stopped.** Hitstop off means the game never slows, including after a burst
  of requests: a counter that goes up without coming back down is how a clock ends up stopped for
  good.

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

### The farmers have voices, and they are the only thing not synthesised

Nine recorded lines for a farmer and two cries for a gull, the project's own. They are the one thing
a sine cannot do.

**A farmer speaks when he notices you, and now and then on the way over** — not on his wind-up. The
wind-up already carries the one sound the player must hear, and everything in this game refuses to
shout over a telegraph: a camera knock does, the music does, and a voice would be worse than either
because it comes from the same body.

What makes it read as *coming towards you* is **Doppler**. Each body carries its own
`AudioStreamPlayer3D` rather than borrowing one of the pooled positional voices, because a pooled
voice is put at a point and played — stationary for its whole length, and a stationary sound cannot
say *closing*. The pitch rises as he closes and falls as he leaves, which is a cue nobody has to
learn.

They sit at 0.30 against a wind-up's 0.95, and `verify_voices` fails if that order ever reverses.

### Dying has a sound, and it is ours

A yelp that slides down most of an octave in two thirds of a second while a rasp on top falls with
it. The famous one is a recording under copyright and there is no version of it this project could
ship, so this is the same joke built out of the same parts.

Off the key on purpose, like the dry-fire warning: a death is not a musical event, and a scream that
landed on the tonic would read as the game approving.

### One key, and room to be a mix

**The whole game is in A minor.** It was already mostly true and nobody had written it down — the
bed is stacked fifths on A, the perfect parry is a bell on A and E, the perfect signature is E, the
pickup is E and B. Three sounds were in C and G: the wave sting, the merchant, and the two endings.
Those are the three most *musical* moments there are, so they were the three that rang against
everything else. They are A–C–E, A–E, and A–E–A now.

The bed had the same fault one level down. A stack of fifths **leaves the key on the third step** —
A, E, B, then F sharp, which A minor does not contain — and two of the three layers were reaching
it, so the sound playing under every other sound disagreed with all of them. The stack stops at
three.

**Everything is 6 dB quieter, and the figure is derived.** Several sounds arrive at once — three
farmers commit at night while a chain lands — and each was normalised to its own peak as though it
were alone. Uncorrelated sources sum as the root of the sum of squares, so four at 0.9 reach 1.8 and
the master clips. A headroom of one half puts those four at 0.9.

The table of declared peaks is untouched: it is the **shape** of the mix, and one figure moves the
whole thing down together rather than nine figures drifting apart. `tools/verify_mix.tscn` holds the
order, the ceiling and the key.

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

### Four archetypes, four warnings

Every wind-up **climbs** — a warning that does not rise reads as a drone — and they differ in where
they climb from and to, which is the one thing that survives several of them at once in a crowd at
night:

| | climbs | over |
|---|---|---|
| Farmhand | 300 → 690 Hz | 0.30 s |
| Reaper | 150 → 300 Hz | 0.42 s |
| Pirate | 200 → 380 Hz | 0.48 s |

They are set apart rather than ranked. Several commit at once in a crowd at night, and an archetype
the ear cannot pick out of that is one the player cannot answer differently — so the check holds the
gap between them and nothing else. The pirate's is the longest and the only one that climbs less
than an octave, which is what makes him the one you feel coming rather than the one that pierces.

### The bed lifts with the island

Three loops on the **MusicDuck** bus, and they are one piece of music getting louder rather than three
cues taking turns — same length so they never drift apart, all built on stacked fifths so any pair
of them agrees, and they **stack**: a layer above its range stays full rather than handing over.

| | root | arrives at | full at |
|---|---|---|---|
| Ground | 55 Hz | always on during a fight | 0.15 |
| Pulse | 82.5 Hz | 0.20 | 0.55 |
| Edge | 220 Hz | 0.60 | 0.95 |

**Pressure is bodies on the island, not time.** A wave three minutes through is not a tense wave if
nobody is left, and a wave thirty seconds in with eight farmers closing is. Measured against what
*this* wave allows at once rather than a constant, so a full island sounds full at wave 1 and at
wave 15. Between waves it is zero, and the breather is silent — which is the only pacing tool the
game has.

Nothing in the layers is rhythmic and nothing shares a frequency with the perfect signature or with
any wind-up. A bed the ear can count against is a metronome, and a player fights a metronome instead
of reading a fight.

**A telegraph outranks the bed**, the way it outranks a camera knock: the MusicDuck bus drops 14 dB
while anything is winding up and eases back after. Half a bed over a wind-up is still a bed over it.

**The duck has a bus of its own, under the one the player owns.** `MusicDuck` carries the bed and
the soundtrack and sends to **Music**, which nothing writes but the volume slider — so a wind-up
ducks the music underneath what the player asked for rather than instead of it.

### Nothing the player needs is on a bus they may mute

Music and Ambience exist to be switched off. Everything that tells the player something is on
**SFX**, and `tools/verify_music.tscn` walks every voice to prove it — a slider at the bottom must
cost atmosphere and never information.

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
