# Teaching the game

## The problem

This game's subject is timing. Timing cannot be explained — a player who reads *"press again
inside the chain window"* has learned a sentence, not a rhythm. Worse, a game whose whole appeal is
in the hands is the kind people skip the text of fastest.

So the rule for this project:

> **Nothing is taught with a wall of text, and nothing is taught outside the fight.**

## The decision: wave 1 is the tutorial

There is no tutorial mode, no training room, no separate scene to build and maintain. **Wave 1 is
a hand-authored teaching wave** that happens to also be the first wave of the run.

It differs from waves 2–15 in three ways, and in no others:

1. It spawns enemies **one at a time**, on demand, instead of on the wave formula.
2. Its farmhands have a **longer telegraph** and, for the first two steps, do not attack at all.
3. It **does not advance on a timer**. It advances when the player does the thing.

Everything else — the camera, the damage, the stamina, the feel — is the real game from the first
second. The player is never practising; they are already playing, and the game is choosing what to
throw at them.

## The seven steps

Each step shows **one** prompt, and clears when the player performs the action **once**. Never two
prompts at a time. Never a prompt for something already demonstrated.

| # | Teaches | Clears when | What the wave does |
|---|---|---|---|
| 1 | Move | the player has travelled 3 m | nothing spawns yet |
| 2 | Attack | the first hit lands | one farmhand spawns, and will not attack |
| 3 | **Chain** | attack 2 of a chain lands | that farmhand has inflated health so it survives the lesson |
| 4 | **Perfect** | a perfect hit lands | same farmhand, still passive |
| 5 | Dodge | a dodge passes through an attack | the farmhand starts attacking |
| 6 | Parry | a **perfect** parry lands | the farmhand keeps telegraphing, patiently, as long as it takes |
| 7 | Sprint | the player sprints | a second farmhand spawns further away |

Then the prompts stop for the rest of the run, and wave 2 begins on the normal formula.

### Why this order

Movement first, and **there is no camera lesson** — the camera is fixed and follows on its own, so
there is nothing to teach. That is one fewer thing standing between the player and the fight, and
it is the clearest argument for the fixed angle.

Attack before defence, because hitting something is the reward that buys attention for the rest.

**Chain before perfect**, because the perfect window lives inside the chain window — teaching them
in the other order would mean teaching a timing that does not yet have anything to attach to.

Dodge before parry, because dodge forgives and parry does not. A player who can dodge has a way to
survive while they learn to parry.

Parry last, and **the wave does not end until it lands**. It is the hardest input in the game and
the one that makes everything after it work. A player who reaches wave 2 without ever having
parried will be lost by wave 5.

Sprint last because it is the least important. It is a convenience, not a mechanic.

## The prompts

One line, bottom-centre, with the glyph for the device currently in use. It fades in after a beat
of silence — never the instant the step opens, because a player who was already doing the right
thing should never see it.

```
Press [LMB] again as the flash fades
```

Rules:

- **Device-aware.** The glyph set swaps the moment the player touches the other device. A player on
  a pad must never read the word "mouse".
- **Verb first, no prose.** *"Dodge through the swing"*, not *"You can press Space to perform a
  dodge roll, which grants brief invulnerability"*.
- **It names the reward, once.** When the first perfect hit lands, the line becomes
  *"Perfect"* for a moment. That is the only time the game uses the word; after that the flash and
  the hitstop carry it.
- **It never blocks.** No modal, no pause, no "press any key to continue". The fight keeps running
  underneath.
- **It never repeats.** A cleared step never shows again in that run.

## A player who already knows

Every step is **satisfied retroactively**. If the player chains three attacks before the chain
prompt would have appeared, steps 2, 3 and 4 all close silently and the wave moves on.

A player who is good at action games should be able to finish wave 1 **without seeing a single
prompt**. That is the design target, and it is the honest test of whether the game reads without
being explained.

## No failure while teaching

During wave 1 the player's health never drops below 1. Silently — the game does not say so, and the
damage numbers and the flash all behave normally.

The reason: a player who dies during the parry lesson has learned that parrying is dangerous, which
is the opposite of true. But telling them they are safe removes the tension that makes the lesson
stick. So they are protected, and they never find out.

This stops at wave 2, with no announcement.

## Second run

Cleared steps persist in `progress.json`. On a second run the whole thing is off: wave 1 spawns on
the formula like any other wave.

The options menu carries a **Show tutorial prompts** toggle, defaulting to off once the tutorial
has been completed once. Nobody should have to sit through it twice, and nobody should have to hunt
for the switch when a friend tries the game on their machine.

## What this is not

- **Not a separate scene.** No `tutorial.tscn` to keep in sync with the arena.
- **Not a cutscene, and not a voice.** There is no narrator, no character explaining the island.
- **Not a glossary.** The words "chain window" and "perfect window" appear in this repository and
  never in the game.
- **Not skippable by a button**, because there is nothing to skip: a player who performs the actions
  is already past it.

## How it is built

A `TutorialDirector` node lives in the arena and is driven by **`TutorialStep` resources** under
`data/tutorial/`, so the order and the wording are data like everything else.

Each `TutorialStep` carries: `id`, `prompt_key` (a localisation key, never a literal), the
`EventBus` signal that satisfies it, an optional predicate, and what the wave should do while the
step is open.

It listens on the `EventBus` and touches nothing else — `attack_landed` already carries the perfect
flag, `parry_perfect` already fires, and the player already reports its state transitions. **This
is what the bus was for**: the tutorial observes the whole fight without a single system knowing
it exists, and deleting the director cannot break combat.

The hook it needed is in: `SpawnDirector.spawn` and `spawn_at` both take `harmless`, and a harmless
body is refused the attack token — the one gate every path into `WindUp` goes through. He still
closes and still circles, so he reads as a threat while being unable to be one. The longer telegraph
is the `windup` multiplier the wave scaling already used.

Two details worth stating, because they are not obvious from the table:

- **A step says how many bodies should be standing, not how many to send.** The director tops up, so
  a farmhand killed during the chain lesson is replaced and the lesson survives being played well.
- **The wave director is halted, not replaced.** When the last lesson closes, the tutorial hands the
  island back and the ordinary breather runs — so wave 2 arrives exactly like every other wave.

The protection during wave 1 is `HealthComponent.minimum_health`, raised to one and dropped again
after. Everything else — the flash, the numbers, the stagger — behaves normally.

**The glyph is device-aware.** A step names **actions**, not keys — `prompt_actions` — and the line
is rendered with whatever those actions are bound to on the device in hand, then re-rendered when
the hand moves or a binding changes. The string itself carries a `{0}` and nothing else, so a
translator never has to know what a controller is called.

Movement names all four of its actions and the glyph deduplicates them: `W A S D` on a keyboard, a
single `L-STICK` on a pad. A stick is one thing to the player even though the engine reports it as
four half-axes, and a prompt listing all four describes a shape nobody has.

A lesson about **timing** names no action at all — the chain and the perfect window have no button
to press that the previous lesson did not already teach — so those strings have no `{0}` and are
shown exactly as written.

## The test

The exit criterion, and it is not negotiable:

> **Three people who have never played reach wave 5 without being told anything.**

If they cannot, the answer is not a longer prompt. It is a slower telegraph, a wider window, or an
earlier lesson.
