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

## The hint bar

Every screen ends its header with a line of hints — *what this button does here*. They name an
**action**, never a key, and their word is a **translation key**, never a word.

Both halves were written out by hand on nine labels across seven screens (`[B / ESC] BACK`, and the
same again), and both halves were wrong. The glyph stopped being true the moment a player rebound
anything or picked up a controller — which is exactly what `MenuEntry` has done correctly since the
menus were built — and the word was English in every language. `HintLabel` is the shared answer, and
`verify_glyphs` fails on any scene that writes a glyph out by hand.

## Title

Three entries, in this order: **Play · Options · Quit**.

Play starts a run immediately. There is no character select, no difficulty select, no save-slot
list — a run is forty minutes and the game has one difficulty, so anything between the button and
the fight is furniture.

Credits are not a title entry: the layout holds three rows without crowding the logo, and a fourth
that nobody opens twice is not worth the height. Nor are they a sixth Options tab — the design draws
five. They sit **beside the version number**, as a discreet line under the menu, and open as an
overlay the way Options does.

What the overlay shows is not written anywhere near it. `docs/credits.md` is the list; the game
reads `data/credits.tres`, baked from that document by `tools/build_credits.gd`; and
`tools/verify_credits.tscn` fails the build if the two have come apart or if a baked row never
reaches a label. Adding an asset is a row in the document and a rebuild — this screen is never
edited for it, because a second hand-kept copy of an attribution list goes wrong by leaving somebody
out.

The background is the island with the camera drifting slowly, blurred and dimmed. Not a pre-rendered
image: `scenes/world/vista.tscn` instances **the same `island.tscn` the fight happens on**, lit by
the same `island_sky.tscn` the arena uses, so the title cannot look like a different game than the
one that follows. It is blurred by the **pause menu's own shader**, for the same reason: two
treatments of "the world behind a menu" would drift apart.

The vista camera **swings through a narrow arc rather than orbiting**. The island is composed for
one angle — that is the fixed camera's bargain — so a full orbit would show it from the side nobody
built, and the title would become the one place in the game that lies about what the island looks
like.

It is added in code rather than sitting in the scene, and that is not a style choice: a headless
boot has no renderer to draw an island with, and the dummy one answers a material query on it with
an error about the absence of a GPU rather than about the game. The consequence is worth stating —
**CI boots the title without its backdrop**, so a broken vista is a thing a human has to see.

When a run is in progress and the player quit to title, Play becomes **Continue**, and a second
entry **New run** appears below it.

**Continue survives closing the game.** The run is on disk, so the entry is there on the next
launch too — it reads `run.json`, not a variable that only lives as long as the process. A run
resumed between two waves reopens the merchant it had not spent yet; one resumed halfway through a
wave fights that wave again from its start. A run that ended, in a death or in a victory, is not
resumable and the file is gone.

Every entry carries the glyph that fires it, **for the device in hand** — `ENTER` or `A` on the
focused row, `O` or `Y` on Options, `ESC` or `B` on Quit. New run takes `N` or `Y`, and Options
loses its badge entirely while a run is waiting, because the pad has one Y.

**A row names an action, never a key.** The badge prints whatever that action is bound to right
now, so it follows a rebind, and it swaps the moment the player picks up a controller — a menu
telling a pad player to press `Space` has sent them looking for a key that is not in their hands.
See [the glyphs](#glyphs) below.

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

**Every setting here has something listening.** That was once an aspiration — aim assist and
tutorial prompts were stored and waiting for the gun and the tutorial to arrive. Both arrived and
nobody came back, so aim assist spent several milestones persisting and moving nothing. It is read
now, by `AimComponent`, and `verify_aim` fails if it stops being.

**A setting whose feature is taken away goes with it.** There was a colourblind-telegraph toggle
here, and it thickened the ring the wind-up used to draw. The ring is gone, so the toggle is gone:
a switch that persists and moves nothing is worse than a missing one, because a player who needs it
will set it and believe they are covered.

### Gameplay

| Setting | Default | Why it exists |
|---|---|---|
| Sprint | **auto** — hold on keyboard, toggle on pad, decided per press | The two audiences genuinely expect different things, and a player who disagrees can say so — [ADR 0007](decisions/0007-sprint-hold-or-toggle.md) |
| Aim assist | soft | The gun is unplayable on a stick without it, and unsatisfying with too much. `soft` takes half the error off, `strong` takes all of it, and neither reaches outside a 12° cone or past what the weapon in hand can hit — a wider one starts choosing targets, which is worse than missing |
| Show tutorial prompts | on | Off skips the lines before wave 1 on a new run — see [tutorial.md](tutorial.md) |
| Damage numbers | **off** | The design says the hit should be felt; the numbers are a debugging comfort |
| Credit numbers | **on** | The opposite default, and for the opposite reason: that a kill pays is a rule the player has to learn, and it is one number per body rather than one per hit |

### Controls

Full rebinding of every action, both devices, rebuilt into the `InputMap` at boot. **And nothing
else**, which is a decision rather than an omission.

Mouse sensitivity, stick sensitivity and invert Y were listed here and shipped as three rows that
moved nothing. They were written for a camera that can be turned, and this one cannot be — the yaw
and the pitch are constants on `CameraRig`, the mouse aims by where the cursor lands on the ground
and the stick by the direction it points. There is no look delta to scale and no pitch to invert,
so there was never anything for the three of them to reach. A slider that persists and changes
nothing is worse than a missing one: a player who needs it sets it and believes they are covered.

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

Master, Music, SFX, Ambience. Four sliders against the four buses the player owns, in decibels
internally and 0–100 on screen, all four defaulting to 100 until the audio pass has something to
balance. The fifth bus, **MusicDuck**, has no slider and never will: it sends to Music and exists so
that a wind-up ducks the soundtrack underneath the player's setting instead of overwriting it.

Sliders are **ten blocks, not a bar with a thumb**: a value that only ever moves in tenths is
readable at a glance and reachable in ten presses on a pad.

### Accessibility

| Setting | Default |
|---|---|
| Screen shake | 100 %, sliding to 0 |
| Hitstop | on |
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

The least possible. Health and stamina bottom-left, ammo bottom-right when the gun is held, the
soundtrack row, wave number and money top-right — each **96 px in from its own corner**, nothing
anywhere else.

Every element listens on the `EventBus` and holds no reference to the player, so the HUD survives a
death, a restart and a player that does not exist yet. The health figure is the one thing allowed
to raise its voice: under a third of maximum it turns red.

**The ammo panel only exists with a ranged weapon in hand.** A melee player never sees a magazine
of zero — the panel is absent, not empty.

Damage numbers float off the enemy that was hit and are **off by default**. The design says the hit
should be felt; the numbers are a debugging comfort, and they live in Options → Gameplay.

**Credit numbers are the one floating number that is on by default**, because they answer a question
the player cannot answer by feel: whether killing that body was worth anything. They rise off the
body that died, read the payout the wallet was actually paid — the elite multiplier included, since
both come off the same signal — and a body worth nothing floats nothing.

The money chip answers at the same time, with a short punch. A two-digit number changing in the
corner of a fight is not something the eye catches on its own, so the chip is what carries the news
and the counter is what confirms it. **Spending is silent**: the player pressed the button and
watched the price, and being punched at afterwards tells them nothing they did not just do. The
punch is also the half a player can turn off — it respects *Reduce flashing*, while the number
itself stays, because suppressing it would remove information rather than motion.

**The soundtrack row sits above the wave chip, and in the same place on the title screen and behind
the pause menu.** One row the player learns once: what is playing, a button to silence it and a
button for the next track. It is built out of the chips the rest of the HUD is built out of — the
same frame, the same border, one size down — because a widget with its own look reads as something
that arrived from another game.

The two buttons say **Mute** and **Next** rather than carrying a speaker and a skip glyph. A row
this small has no space for an icon that has to be guessed at, and the mute button names what
pressing it does rather than the state it is already in. Muting greys out **Next**: with the
soundtrack off there is nothing to skip. They are **mouse-only** — `FOCUS_NONE`, so a widget in the
corner never takes the caret off a menu column or off the fight. The music slider in
Options → Audio is what a pad reaches for.

The row **disappears when there is no soundtrack**. An empty playlist is a data change, and a row
showing nothing with two dead buttons reads as broken rather than as absent.

The debug overlay from M1 stays behind `F3` in debug builds, starts hidden, and a release build
never carries it at all.

## Glyphs

**A player on a pad must never read the word "mouse."** That is the whole rule, and it is not a
nicety: a glyph naming hardware the player is not holding sends them looking for a key that is not
there, which is worse than showing nothing.

So nothing on screen holds a key name. A menu row and a tutorial prompt each name an **action**, and
`Devices` answers with what that action is bound to on the device in hand. Two things make it
change, and both are signals on the bus: `input_device_changed` when the hand moves, and
`bindings_changed` when a rebind lands.

**The device is the last one touched**, not one picked at launch. Someone with a keyboard and a pad
in front of them is the normal case. A mouse *moving* counts — it is the clearest statement there is
that the hand left the pad — while a stick must travel past half its range, or a controller resting
with drift would flip every badge on screen for ever.

Three display rules, all in `Devices` rather than in `InputBindings`, because the options screen has
a column to print a long name in and a badge does not:

- A stick is **one thing**. `L-STICK X +` and `L-STICK Y -` are the same thumb, so the direction and
  the axis letter come off and four movement actions dedupe to a single `L-STICK`.
- Long key names are shortened on a badge: `ESCAPE` reads `ESC`, matching the design's chip.
- Xbox naming is the default. A pad that calls its buttons something else still reports the same
  indices, so a PlayStation glyph set is a second table and no new code.

One row in the game names a **different action per device**, and it is the pause menu's Resume:
`Esc` on a keyboard and `A` on a pad. Those are not two names for one binding, they are two bindings
that both mean *get me out of here*, which is why `MenuEntry` carries a `gamepad_action` override at
all. Nothing else uses it.

## Typography

Two faces, both SIL OFL, both in `assets/fonts/` and both credited.

- **Oswald Medium** is the display face: headings, menu titles, buttons, dialog buttons and the
  pause title. Eight theme type variations point at it, so it is one line in
  `assets/themes/ui_theme.tres` and nothing else.
- **Inter SemiBold** is everything else — every row, caption, value and readout.

The display face is **condensed and open**, and that is a requirement rather than a taste. It
replaced Badeen Display, which was chosen for impact and failed on the only thing a menu owes the
player: at 40 px, `THE STUDIO` read as a row of filled blocks, because the counters close up at
every size. A face whose counters survive is the bar for replacing this one too.

Badeen also drew its Latin digits as composites of the Arabic-Indic forms — its `0` printed `٠` —
which had forced a standing rule that no string carrying a number could be set in it. **That rule is
gone with the font.** Oswald's digits are Latin digits, so a number can be set wherever it belongs.

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
