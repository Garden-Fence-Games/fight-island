# Roadmap

Each milestone states its goal in one sentence, what it delivers, and the exit criterion that
proves it is done. Durations are estimates for one person working part-time.

## M0 — Foundations (~1 week)

**Goal:** anyone opening this repository knows everything without asking.

- Full `docs/` set, `README.md`, `CLAUDE.md`, shared `.claude/` setup
- `project.godot`: `[dotnet]` removed, version stamped, display and rendering settings, ten named
  physics layers, and the complete input map — 26 actions, each bound on both schemes
- `tools/verify_project_config.gd` as a headless guard
- `.gitignore`, `.gitattributes` with LFS, `.editorconfig`, `export_presets.cfg`
- GitHub Actions: lint and headless validation on every PR, exports and an itch.io publish on
  tags. **CI is the only source of shippable binaries** — local export templates are optional
- PR and issue templates
- ZenNotes folder created

**Exit:** the project opens with zero errors and zero warnings, `verify_project_config` passes, and
`docs/` answers every question a new contributor would ask.

## M1 — Prototype (~3 weeks)

**Goal:** *"I can kill an enemy with my fists and it feels like something."*

- `boot.tscn` → `main.tscn` → a grey-box `arena.tscn`, and `run/main_scene` finally set
- Camera rig complete: free yaw, clamped pitch, eased zoom, occlusion
- Player with the node FSM: move, sprint, dodge, parry
- `HealthComponent` and `StaminaComponent`
- The hitbox/hurtbox pattern working end to end
- The fist three-attack chain with both timing layers and visible feedback — hitstop, flash, a
  sound of its own
- One enemy with the full FSM and a readable telegraph
- A debug HUD showing health, stamina and current state

**Exit:** a 60-second grey-box fight where a perfect parry and a perfect chain are *felt*, not read
off a number.

## M2 — Vertical slice (~4 weeks)

**Goal:** one complete ten-minute run.

- Stick and gun with their six attacks, ground pickups, instant swapping, ammo and reload
- `WaveDirector`, `SpawnDirector`, enemy pooling
- Waves 1 to 5 on the real formulas from `WaveConfig`
- `Economy` and the five-track upgrade screen, with the merchant
- Real HUD, death screen, retry, pause, options
- Island blockout with navigable geometry
- First audio pass

**Exit:** the run plays start to finish on a gamepad **and** on keyboard and mouse, and the balance
table in `docs/game-design.md` matches the shipped `.tres` values.

## M3 — Content (~6 weeks)

**Goal:** the game is the game.

- Fifteen waves, tuned; elites
- Final art for the island, both characters and the three weapons — the primitives go away
- Animation pass, VFX pass, full audio
- Main menu, settings, credits
- Save and load; FR and EN localisation
- Balance telemetry in debug builds: time per wave, deaths per wave, upgrade pick rate

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
