# Roadmap

Each milestone states its goal in one sentence, what it delivers, and the exit criterion that
proves it is done. Durations are estimates for one person working part-time.

## M0 — Foundations · **done**

**Goal:** anyone opening this repository knows everything without asking.

- Full `docs/` set, `README.md`, `CLAUDE.md`, shared `.claude/` setup
- `project.godot`: `[dotnet]` removed, version stamped, display and rendering settings, ten named
  physics layers, and the complete input map — 21 actions, each bound on both schemes
- `tools/verify_project_config.gd` as a headless guard
- `.gitignore`, `.gitattributes` with LFS, `.editorconfig`, `export_presets.cfg`
- GitHub Actions: lint and headless validation on every PR, exports and an itch.io publish on
  tags. **CI is the only source of shippable binaries** — local export templates are optional
- PR and issue templates
- ZenNotes folder created

**Exit:** the project opens with zero errors and zero warnings, `verify_project_config` passes, and
`docs/` answers every question a new contributor would ask.

## M1 — Prototype · **done**

**Goal:** *"I can kill an enemy with my fists and it feels like something."*

- [x] `boot.tscn` → `main.tscn` → a grey-box `arena.tscn`, and `run/main_scene` set
- [x] Camera rig: one fixed angle that follows the player, with eased zoom
- [x] Player with the node FSM: idle, move, sprint, dodge, parry, attack, hurt, dead
- [x] `HealthComponent` and `StaminaComponent`
- [x] The hitbox/hurtbox pattern working end to end
- [x] The fist three-attack chain with both timing layers, hitstop and a flash
- [x] The farmhand with the full FSM, a wind-up that shortens with the waves, and the attack-token
  pool
- [x] A debug HUD showing health, stamina, state and the chain index
- [x] Sound — five hit-and-parry signatures, **synthesised at startup rather than shipped as
      files**, so the perfect window is recognisable with the screen off. It was the last box, and
      it waited on nothing: there is still not an audio asset in the repository

**Exit:** a 60-second grey-box fight where a perfect parry and a perfect chain are *felt*, not read
off a number.

## M2 — Vertical slice · **in progress**

**Goal:** one complete ten-minute run.

- [x] Stick and gun with their six attacks, ground pickups, instant swapping, ammo and reload
- [x] `WaveDirector`, `SpawnDirector`, enemy pooling
- [x] Waves 1 to 5 on the real formulas from `WaveConfig`
- [x] `Economy` and the five-track upgrade screen, with the merchant — see [menus.md](menus.md)
- [x] Title, pause and options screens, all navigable on a pad
- [x] The tutorial director, driven by step resources — see [tutorial.md](tutorial.md)
- [x] Real HUD, death screen, retry, pause, options
- [x] Island blockout with navigable geometry
- [ ] First audio pass — `AudioManager` voices the player's own timing and nothing else yet. No
      music, no ambience, no enemy or menu sound, and `assets/audio/` holds a bus layout and
      nothing else

**Exit:** the run plays start to finish on a gamepad **and** on keyboard and mouse, and the balance
table in `docs/game-design.md` matches the shipped `.tres` values.

The second half of that exit is machine-checked — `verify_combat`, `verify_waves` and
`verify_day_night` read the document and fail on a figure that drifted. The first half is not, and
cannot be: somebody has to play the run through on each scheme and say so.

## M3 — Content (~6 weeks)

**Goal:** the game is the game.

- Fifteen waves, tuned; elites
- Final art for the island, both characters and the three weapons — the primitives go away
- Animation pass, VFX pass, full audio — **the enemy wind-up is owed an animation**, see below
- Main menu, settings, credits
- Every player-facing string through `tr()`, with no literal left in a scene or a script. **The
  game ships in English and in nothing else** — see [menus.md](menus.md); the `tr()` layer is there
  so a menu is not rewritten the day someone wants a second locale, not because one is planned
- Balance telemetry in debug builds: time per wave, deaths per wave, upgrade pick rate

**Save and load came early** and is off this list: `SaveManager`, JSON under `user://`, and
`verify_save` in CI. It arrived with the run flow in M2 because a run you cannot resume is a run
nobody plays twice.

**The wind-up has no picture at the moment.** The ring that used to fill on the ground under a
farmer committing has been taken out, and nothing has replaced it: the timing is intact and every
check of it still passes, but a player reads a wind-up as a body that has stopped moving. The
replacement is an animation on the enemy rig, which is why this sits here rather than in M2 — and
until it lands the game is harder to read than the numbers in
[game-design.md](game-design.md) describe.

**The art has not started, whatever the screenshots suggest.** The player's rig and the island's
vegetation, stone and huts are prototype dressing: CC0 stand-ins, on a Mixamo skeleton whose
redistribution terms [`credits.md`](credits.md) flags `prototype only`. Both are replaced here, so
counting the primitives that have already gone counts the wrong thing.

**Exit:** three people who have never played reach wave 5 without being told the rules, and at
least one reaches wave 15.

## M4 — Polish (~4 weeks)

**Goal:** it stops feeling like a prototype.

- Game feel pass: hitstop curves, screenshake budget, camera kick, impact VFX, rumble
- 60 fps on both reference machines
- Accessibility: full rebinding, hold-versus-tap sprint, aim assist, damage-number toggle,
  colourblind-safe telegraphs, screenshake slider
- Bug bash, and a demo build on itch.io

**Exit:** no known crash, no frame below 55 fps on the reference machines, and a 60-second trailer
cut from real footage.

## M5 — Release (~3 weeks)

**Goal:** people can play it.

- itch.io release: page, capsule art, description, both builds published by `butler` on tag
- macOS notarisation resolved, or the limitation documented for players
- **Then, if the 100 USD is spent:** Steamworks account, App ID, depots, a manual `steamcmd`
  upload, a `beta` playtest, and promotion to `default`

**Exit:** the game runs from a clean download on a clean Mac and a clean Windows machine.

## Open decisions

These are tracked in ZenNotes under *Décisions à trancher*, each with a recommended default so
nothing blocks. The ones with money or a deadline attached:

| Decision | Gates | Default if nobody decides |
|---|---|---|
| Licence for the repository | the public itch.io release | all rights reserved on the code |
| Apple Developer membership, ~99 USD/year | a macOS build that launches | buy it during M4 |
| Steam Direct, 100 USD + 30 days | M5 | ship on itch.io first, decide after |
| Music and SFX: CC0, commissioned, or bought | M4 | CC0 through M3, decide before M4 |
