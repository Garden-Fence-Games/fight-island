# Teaching the game

## The decision: a few lines on a clock, then wave 1

A new run opens on the player waking up (`RunIntro`). The moment the camera settles, four lines
appear one after the other at the bottom of the screen, each for its own few seconds:

| # | Line | Names |
|---|---|---|
| 1 | *You were drunk, now you're angry* | — |
| 2 | *[attack] to punch and [dodge] to dodge* | `attack`, `dodge` |
| 3 | *[sprint] to sprint* | `sprint` |
| 4 | *Now, survive!* | — |

When the last one goes, **wave 1 starts at once** — the ordinary wave, off the formula, like every
wave after it. The island is empty while the lines are up: the wave director is halted, nothing
spawns, and the player can already walk, swing and roll.

## Why a clock and not the buttons

The first tutorial was wave 1 itself: seven lessons, each closing when the player performed it —
walk three metres, land a chained hit, land a perfect one, roll through a swing, parry. It read
well on paper and broke in play. A lesson waiting for an input is a lesson that can wait for ever,
and the parry lesson held the whole wave open until a perfect parry landed, which a new player may
simply not manage.

So **nothing waits for the player.** A line gives way when its time is up whatever was or was not
pressed, and the run always reaches wave 1. The timing lessons — the chain, the perfect window, the
parry — are left to the fight, where the flash and the hitstop already say them.

## The lines

- **Device-aware.** A line names **actions**, not keys — `prompt_actions` — and each `{n}` in the
  string is the glyph of the n-th action on the device in hand, re-rendered the moment the hand
  moves or a binding changes. A player on a pad never reads the word "mouse".
- **It never blocks.** No modal, no pause. The player has a body the whole time.
- **After the opening, not over it.** `RunIntro` holds the director still while the camera turns,
  so the clock starts when the player can act.

## Which runs show it

**Every run begun from the title**, exactly like the opening it follows — `GameState.begin_run(true)`
sets `tutorial_owed` beside `intro_owed`, and the director spends it. A retry from the summary, a
restart from the pause menu and a resumed run go straight to the fight: that is the same player
straight back in. It used to switch its own setting off at the end, which made it a once-per-machine
tutorial; it no longer touches the setting.

**Show tutorial prompts** in the options menu is the player's way to skip it. Turning it off while
the lines are up skips the rest and starts wave 1 there and then.

## How it is built

A `TutorialDirector` node in the arena reads **`TutorialStep` resources** under `data/tutorial/` —
`id`, `prompt_key` (a localisation key, never a literal), `prompt_actions`, and `seconds`, how long
the line stays. The order, the wording and the timing are data; re-timing a line is an inspector
edit.

`TutorialPrompt` draws the line and knows nothing about when; the director owns the clock and hands
the island to `WaveDirector.start_wave(1)` when it runs out.

`tools/verify_tutorial.tscn` holds it: it never presses anything, lets time pass, and asks that every
line gives way after its own time and that wave 1 is running at the end.
