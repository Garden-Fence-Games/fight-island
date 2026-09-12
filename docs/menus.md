# Menus and screens

## Rules that apply to every screen

**Everything is navigable on a pad, from the first frame.** This is why `ui_accept` and `ui_cancel`
were given gamepad bindings in M0 — Godot ships them with none, so a controller player cannot
confirm a menu out of the box. A screen that can only be finished with a mouse is a bug.

**Focus is never lost.** Every screen grabs focus on open and restores it on close. If a player
presses a direction and nothing highlights, that is a bug too.

**Back is always one level.** `Esc` and B go back exactly one step, never to the desktop, never two
screens at once. The only place that quits the game is the title screen's own Quit.

**Settings apply the moment they change.** No Apply button, no confirmation dialog, no "restart to
take effect". They are written to `settings.json` on change.

**Nothing hides behind a submenu it does not need.** Five options in a category is a category; two
options is a row on the parent screen.

## The flow

```
boot ─▶ intro ─▶ title ──▶ [Play] ──▶ run ──┬──▶ [Esc] ──▶ pause ──┬──▶ resume
                                            │                     ├──▶ options
                                            │                     ├──▶ restart run
                                            │                     └──▶ quit to title
                                            ├──▶ wave cleared ──▶ merchant ──▶ next wave
                                            ├──▶ died ──▶ run summary ──┬──▶ retry
                                            │                           └──▶ title
                                            └──▶ wave 15 cleared ──▶ victory ──┬──▶ endless
                                                                               └──▶ title
```

## Intro

A single Garden Fence sting, eight seconds, `assets/video/garden_fence_intro.ogv`. Godot plays Ogg
Theora and nothing else, so the source `.mp4` is transcoded — it is not the shipped file.

**Any button skips it**, and a discreet hint says so after a second and a half. There is nothing
else on the screen and nothing after it but the title.

## Title

Three entries, in this order: **Play · Options · Quit**.

Play starts a run immediately. There is no character select, no difficulty select, no save-slot
list — a run is forty minutes and the game has one difficulty, so anything between the button and
the fight is furniture.

Credits are not a title entry: the layout holds three rows without crowding the logo, and a fourth
that nobody opens twice is not worth the height. They do not have a home yet — the Options screen
is five tabs and a sixth would not be one of the five the design draws.

The background is the island with the camera drifting slowly. Not a pre-rendered image: the real
arena scene, so the title screen can never look like a different game than the one that follows.
Until the island is composed for it, a grey wash stands in — one node named `Background`, which is
the only thing that changes when the arena moves in.

When a run is in progress and the player quit to title, Play becomes **Continue**, and a second
entry **New run** appears below it.

Every entry carries the glyph that fires it — `[A / ENTER]` on the focused row, `[Y / O]` on
Options, `[B / ESC]` on Quit — and each of those is a real binding. New run takes `[Y / N]` and
Options loses its badge while a run is waiting, because the pad has one Y.

## Pause

Opens on `pause` (`Esc` / Start). Sets `get_tree().paused = true`, which is why the camera rig and
the hit-feedback node must both respect `PROCESS_MODE_PAUSABLE` — a camera that keeps drifting
behind a pause menu feels broken even though nothing is wrong. They inherit it from the root, so
neither has to be told.

**Resume · Options · Restart run · Quit to title.** Restart and Quit both confirm, because both
throw away up to forty minutes. Nothing else in the game confirms anything.

**The world behind it is blurred, not hidden.** The player is meant to remember what they are going
back to. It is the screen's own mipmaps read at a level, so the cost does not grow with the radius.

**Quit to title keeps the run.** The title turns Play into Continue precisely because there is one
waiting, and the wave director picks up at the wave the run state remembers. Ending a run is what
New run is for. What is lost is the wave in progress — there is no saving mid-wave.

The cursor is visible at all times, so the pause menu has nothing to release.

### The confirmation

One dialog, used twice. It names what is actually lost, in red, inside the sentence rather than
after it — the fragment is a separate string so a translator can put it where the grammar wants it.

Focus opens on **Cancel**: the dangerous button should take a deliberate move to reach.

With **hold to confirm** on, the confirming button has to be held for three quarters of a second and
fills as it is held. Off, it is a press. That accessibility setting has exactly one consumer, and
this is it.

## Options

Five categories. Each is a tab, navigable with the shoulder buttons on a pad or Q and E on a
keyboard.

The screen is an **overlay, not a scene of its own**: the title and the pause menu each add it as a
child and get it back the same way, so neither loses what is behind it. It runs on
`PROCESS_MODE_ALWAYS`, because from pause the tree is stopped and a frozen options screen is a soft
lock.

**A setting whose feature does not exist yet still exists here and still persists.** Aim assist,
tutorial prompts, screen shake and the colourblind telegraphs are stored and waiting; the code that
reads them arrives with the gun, the tutorial, the camera shake and the wind-up flash. Damage
numbers, hitstop, reduce flashing and the sprint mode already have something listening.

### Gameplay

| Setting | Default | Why it exists |
|---|---|---|
| Sprint | **auto** — hold on keyboard, toggle on pad | The two audiences genuinely expect different things, and a player who disagrees can say so |
| Aim assist | soft | The gun is unplayable on a stick without it, and unsatisfying with too much |
| Show tutorial prompts | on until completed once | See [tutorial.md](tutorial.md) |
| Damage numbers | **off** | The design says the hit should be felt; the numbers are a debugging comfort |

### Controls

Full rebinding of every action, both devices, rebuilt into the `InputMap` at boot. Plus mouse
sensitivity (in degrees per 100 pixels, so it survives a resolution change), stick sensitivity, and
invert Y.

**One row rebinds both devices**, and the device the player presses with decides which column
changes. Escape cancels the capture rather than binding to it — it costs the ability to put an
action on Escape and buys a way out of a capture opened by accident.

Bindings live in `bindings.json`, next to `settings.json` rather than inside it: one file is a flat
table of scalars and the other is a tree of serialised events, and keeping them apart means neither
write can clobber the other. **Only what the player changed is stored**, so an action that gains a
better default in a later build reaches a player who already has a file.

The list is whatever the `InputMap` holds, minus anything named `ui_*` or `debug_*` — one is what
makes the menus work and the other is not the player's business. Nothing is hand-listed, so a new
action appears on the screen the moment it exists.

A **Reset to defaults** entry per device, because a player who has bound two things to the same key
needs a way out that is not deleting a file — and needs it without losing the half that still
works.

### Video

Resolution, window mode (windowed / borderless / exclusive fullscreen), vsync, and a frame cap.

Exclusive fullscreen rather than plain fullscreen on Windows — it is what the platform actually
wants for a game, and the difference shows up as input latency.

### Audio

Master, Music, SFX, Ambience. Four sliders against the four buses, in decibels internally and
0–100 on screen, all four defaulting to 100 until the audio pass has something to balance.

Sliders are **ten blocks, not a bar with a thumb**: a value that only ever moves in tenths is
readable at a glance and reachable in ten presses on a pad.

### Accessibility

| Setting | Default |
|---|---|
| Screen shake | 100 %, sliding to 0 |
| Hitstop | on |
| Colourblind-safe telegraphs | off — adds a shape cue to the wind-up flash, not only a colour |
| Hold-to-confirm | off |
| Reduce flashing | off |

These are not a separate difficulty. The game ships with **one** difficulty; anything that would
have been "easy mode" is either a real accessibility setting or it is balance work.

## Merchant, between waves

Not a shop with a grid. Five cards — health, stamina, fists, stick, gun — each showing its current
level, what the next level does **in words**, and its price. One purchase, then the card grid
closes and the five-second breather starts.

Money left over is shown, and carries. A card the player cannot afford is dimmed but still
readable: seeing what you cannot buy is the whole tension of the economy.

There is no "skip" button — leaving without buying is done by pressing back, and the game does not
ask whether you are sure.

**The cards are `UpgradeTrack` resources**, and the effects are fields on them rather than a branch
somewhere: nothing in the code asks "is this the health track". A sixth track would be a `.tres`.

The screen stops the tree while it is up, which is what buys the breather its five seconds — the
director's gap only starts once the cards are gone. A purchase reaches the living player
immediately, through the `UpgradeComponent` on the body: it reads its own base values once and
applies `base + level × step`, so it is safe to run again on a weapon swap or on a player who
walked back into the arena with a run already under way.

**A weapon track only pays out while its weapon is in hand.** The stick upgrade does nothing for
your fists, which is what makes spreading money across weapons a real decision rather than a
strictly worse one.

## Run summary

Shown on death and on victory, with the same layout so the shape is familiar:

- Waves cleared, and the wave that ended it
- Time
- Enemies felled, by archetype
- Perfect hits and perfect parries — the two numbers that say whether the player is getting better
- Money earned and spent, and the upgrade levels reached

Then **Retry** (a fresh run, straight into wave 1) and **Title**.

Victory adds a single line unlocking endless, and nothing else. No score screen, no rank.

Death opens with **Retry** focused and victory with **Title**: each is what the player came to that
screen for. Only the two perfect counters are set in the accent colour — they are the two numbers
that say whether the player is getting better, and colouring the rest would bury them.

The enemy panel lists what the run actually felled. An archetype that never turned up has no line,
because the alternative is this screen keeping its own list of every enemy in the game.

## HUD during the fight

The least possible. Health and stamina bottom-left, ammo bottom-right when the gun is held, wave
number and money top-right — each **96 px in from its own corner**, nothing anywhere else.

Every element listens on the `EventBus` and holds no reference to the player, so the HUD survives a
death, a restart and a player that does not exist yet. The health figure is the one thing allowed
to raise its voice: under a third of maximum it turns red.

**The ammo panel only exists with a ranged weapon in hand.** A melee player never sees a magazine
of zero — the panel is absent, not empty.

Damage numbers float off the enemy that was hit and are **off by default**. The design says the hit
should be felt; the numbers are a debugging comfort, and they live in Options → Gameplay.

The debug overlay from M1 stays behind `F3` in debug builds, starts hidden, and a release build
never carries it at all.

## Localisation

Every string on every screen goes through `tr()` with a key from the first line of code, prefixed
`UI_`, `HUD_`, `OPT_` or `TUT_`. The keys live in `assets/locale/ui.csv`.

**Numerals are never set in Badeen Display.** Its Latin digits are composites of the
Arabic-Indic forms — `0` draws `٠` — so any string carrying a number is set in Inter. Badeen is for
words.

**The game ships in English and in nothing else.** The `tr()` layer stays because a menu built with
literals is a menu that gets rewritten the day a second locale is wanted — but no second locale is
planned, and a French column is not a deliverable.

## What is deliberately absent

- **No settings that need a restart.** If a setting cannot apply live, it is built wrong.
- **No launcher, no engine splash, no publisher card.** The studio sting is the one thing before
  the title, and any button skips it.
- **No difficulty menu.** See Accessibility.
- **No online anything** — no leaderboards, no accounts, no telemetry prompt.
