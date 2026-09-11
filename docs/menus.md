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

Four entries, in this order: **Play · Options · Credits · Quit**.

Play starts a run immediately. There is no character select, no difficulty select, no save-slot
list — a run is forty minutes and the game has one difficulty, so anything between the button and
the fight is furniture.

The background is the island with the camera drifting slowly. Not a pre-rendered image: the real
arena scene, so the title screen can never look like a different game than the one that follows.
Until the island is composed for it, a grey wash stands in — one node named `Background`, which is
the only thing that changes when the arena moves in.

When a run is in progress and the player quit to title, Play becomes **Continue**, and a second
entry **New run** appears below it.

## Pause

Opens on `pause` (`Esc` / Start). Sets `get_tree().paused = true`, which is why the camera rig and
the hit-feedback node must both respect `PROCESS_MODE_PAUSABLE` — a camera that keeps drifting
behind a pause menu feels broken even though nothing is wrong.

**Resume · Options · Restart run · Quit to title.** Restart and Quit both confirm, because both
throw away up to forty minutes. Nothing else in the game confirms anything.

The cursor is visible at all times, so the pause menu has nothing to release.

## Options

Five categories. Each is a tab, navigable with the shoulder buttons on a pad.

### Gameplay

| Setting | Default | Why it exists |
|---|---|---|
| Sprint | hold on keyboard, toggle on pad | The two audiences genuinely expect different things |
| Aim assist | soft | The gun is unplayable on a stick without it, and unsatisfying with too much |
| Show tutorial prompts | on until completed once | See [tutorial.md](tutorial.md) |
| Damage numbers | **off** | The design says the hit should be felt; the numbers are a debugging comfort |

### Controls

Full rebinding of every action, both devices, written as serialised `InputEvent`s into
`settings.json` and rebuilt into the `InputMap` at boot. Plus mouse sensitivity (in degrees per 100
pixels, so it survives a resolution change), stick sensitivity, and invert Y.

Debug actions are not listed and not rebindable.

A **Reset to defaults** entry per device, because a player who has bound two things to the same key
needs a way out that is not deleting a file.

### Video

Resolution, window mode (windowed / borderless / exclusive fullscreen), vsync, and a frame cap.

Exclusive fullscreen rather than plain fullscreen on Windows — it is what the platform actually
wants for a game, and the difference shows up as input latency.

### Audio

Master, Music, SFX, Ambience. Four sliders against the four buses, in decibels internally and
0–100 on screen.

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

## Run summary

Shown on death and on victory, with the same layout so the shape is familiar:

- Waves cleared, and the wave that ended it
- Time
- Enemies felled, by archetype
- Perfect hits and perfect parries — the two numbers that say whether the player is getting better
- Money earned and spent, and the upgrade levels reached

Then **Retry** (a fresh run, straight into wave 1) and **Title**.

Victory adds a single line unlocking endless, and nothing else. No score screen, no rank.

## HUD during the fight

The least possible. Health and stamina bottom-left, ammo bottom-right when the gun is held, wave
number and money top-right. Everything else is the world.

The debug overlay from M1 stays behind `F3` in debug builds and is stripped from release.

## Localisation

Every string on every screen goes through `tr()` with a key from the first line of code, prefixed
`UI_`, `HUD_`, `OPT_` or `TUT_`. The keys live in `assets/locale/ui.csv`.

**The game ships in English and in nothing else.** The `tr()` layer stays because a menu built with
literals is a menu that gets rewritten the day a second locale is wanted — but no second locale is
planned, and a French column is not a deliverable.

## What is deliberately absent

- **No settings that need a restart.** If a setting cannot apply live, it is built wrong.
- **No launcher, no engine splash, no publisher card.** The studio sting is the one thing before
  the title, and any button skips it.
- **No difficulty menu.** See Accessibility.
- **No online anything** — no leaderboards, no accounts, no telemetry prompt.
