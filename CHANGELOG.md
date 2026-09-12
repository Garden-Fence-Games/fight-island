# Changelog

All notable changes to this project are documented here, following
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **No corner of the island answers the reaper's sweep with nothing.** `tools/verify_playfield.tscn`
  walks every square metre of ground the fight can reach — nineteen thousand of them — and fails if
  a dodge from any of them lands only in directions a 160° arc already covers. The camera never
  turns, so a pocket is not something the player can look their way out of; and the first run of it
  found one, on a sandbank a hundred metres out that no enemy can reach, which is what taught the
  check to walk the ground the fight reaches rather than the ground a body can paddle to.

- **Somebody lived on this island before it was an arena.** Five wooden huts stand off the fighting
  core — three of them still standing on their stilts under a plank roof, two collapsed to the bare
  post frame with their planking on the sand around them. They are placed rather than scattered,
  they block, and a standing one fades out of the way of the camera exactly as a boulder does; a
  wreck is a metre high and see-through, so it never fades and never hides a fight.
- Four CC0 models out of Kenney's Survival Kit in `assets/models/camp/`, and `wood` / `woodDark` in
  the island's palette — the pack is the Nature Kit's companion, on the same tile and in the same
  untextured, named-part form the generator already recolours.
- `verify_island` now checks that no hut stands in the surf, and that everything in the camera's
  fade group is wearing a material that can actually fade.
- **The stick and the gun.** Six attacks to the table in `docs/game-design.md`: the stick's 120°
  sweep reaches two bodies at once, which is the whole reason it exists and the answer to the
  reaper; the gun is hitscan, rationed by a magazine of six and a reserve that **only grows between
  waves**.
- The charged shot, the one attack in the game that holds rather than taps. Letting go early
  abandons it and hands the round back, but not the stamina.
- Ground pickups: the stick on wave 2, the gun on wave 4, each weapon carrying its own
  `found_at_wave`. A prompt appears on the weapon itself, in world space, with the glyph for the
  device in hand.
- Weapon switching — three direct keys and a wheel that only ever offers what has been found.
  Free and instant, and the only thing it costs is the chain, whose windows belonged to the old
  weapon.
- `Loadout`, the run's bag: weapons found, what is in hand, and the rounds. Saved with the run, so
  a resumed run is still holding what it was holding, with the ammunition it had left.
- `Hitscan`, `PlayerReload`, `PickupDirector`, `Arsenal`.
- `tools/verify_weapons.tscn` — headless proof that one 120° sweep reaches two farmers and never
  hits either twice, that the gun's figures match the table, that a trigger on an empty magazine
  does not fire, that the reserve grows on a cleared wave and at no other moment, and that a swap
  drops the chain.
- `docs/game-design.md` gained a **poise** column. The numbers had been in the resources since M1
  with no row in the document, which is exactly the drift that document exists to prevent.

- **Every glyph on screen names the device in hand.** A menu row and a tutorial prompt each name an
  *action*, never a key, and `Devices` answers with what that action is bound to on the keyboard or
  the pad — swapping the instant the player picks up a controller, and following a rebind
  everywhere it is shown. A pad player never reads the word "mouse".
- `EventBus.input_device_changed` and `EventBus.bindings_changed`.
- `TutorialStep.prompt_actions`: the movement lesson names all four of its actions and the glyph
  deduplicates them — `W A S D` on a keyboard, one `L-STICK` on a pad, because a stick is one thing
  to the player even though the engine reports it as four half-axes.
- `tools/verify_glyphs.tscn` — headless proof that the badge follows the hand and the hand follows
  the binding: a controller picked up changes the title's Quit row from `ESC` to `B` without
  anything being reopened, no prompt names hardware the player is not holding, and every action a
  screen names has a glyph on both devices — a list gathered from the menus and the tutorial data
  rather than typed out, so a row added tomorrow is covered.

- [ADR 0007](docs/decisions/0007-sprint-hold-or-toggle.md) closes the sprint question: hold on a
  keyboard, toggle on a pad, decided **per press** from the device the press arrived on rather than
  from a mode chosen at launch. No behaviour changed — the decision was already shipped, it just
  had no written record.

- **The island is behind the title screen**, blurred and dimmed, with the camera drifting through a
  narrow arc. The grey wash is gone. It is the same `island.tscn` the fight happens on, lit by the
  same sky, softened by the pause menu's own shader — three things that now cannot drift apart.
- `scenes/world/island_sky.tscn`, the environment and sun lifted out of `arena.tscn` so the title
  and the arena cannot be lit differently.

- **Wave 1 is the tutorial.** A `TutorialDirector` in the arena reads seven `TutorialStep`
  resources, hand-drives that one wave, then hands the island back — wave 2 arrives on the formula
  like every other. Every step closes retroactively, so a player who lands a chained perfect hit
  before being asked closes three lessons at once and never sees a prompt. Cleared steps live in
  `progress.json`; a second run skips the whole thing.
- One prompt at a time, bottom-centre, fading in after a beat of silence. It never blocks, never
  pauses, never repeats.
- The on-demand spawn hook: `SpawnDirector.spawn` and `spawn_at` take `harmless`, and a harmless
  farmer is refused the attack token — he closes and circles but cannot swing.
- `HealthComponent.minimum_health`, raised to one during wave 1 and dropped after. Silently: the
  flash, the numbers and the stagger all behave normally.
- `EventBus.dodge_evaded` — a blow arriving while the player rolls through it, which is the dodge
  lesson. Distinct from a dodge that merely happened.
- `EventBus.player_state_changed`.
- `tools/verify_tutorial.tscn` — headless proof that a chained perfect hit closes three lessons
  with no prompt shown, that a harmless farmer cannot claim a token, that the player cannot be
  taken below one hit point during wave 1, that the parry holds the wave open, and that a second
  run skips the tutorial.

- Saving and resuming a run. `run.json` is written when a wave starts, when one is cleared and when
  an upgrade is bought, so Continue survives closing the game and a run resumed between two waves
  still gets the merchant it had not spent. A finished run deletes its file.
- `progress.json`, holding what outlives a run — the best wave reached today, the tutorial's steps
  next.
- Every file under `user://` now carries a version and passes through a migration on read. A file
  from an older build is accepted, one from a newer build is refused, and an unreadable run file is
  deleted rather than left to fail every launch.
- `tools/verify_save.tscn` — headless proof that a run survives the round trip whole, that a
  missing, truncated, incomplete or future-dated file falls back instead of crashing, and that an
  interrupted wave is fought again rather than skipped.
- Merchant between waves: five cards driven by `UpgradeTrack` resources, one purchase a wave, and
  leftover money that carries. Effects reach the living player the moment they are bought,
  including the heal to full on a health purchase.
- Run summary on death and on victory, the same layout both times: waves, time, money earned and
  spent, kills by archetype, upgrade levels, and the two perfect counters in the accent colour.
  Victory adds one line unlocking endless and nothing else.
- `UpgradeComponent`, which reads its body's base values once and applies `base + level × step`, so
  re-applying never drifts.
- `tools/verify_merchant.tscn` — headless proof that prices follow the cost curve, that a purchase
  reaches the body, that there is exactly one a wave, and that money carries.
- Pause menu on `Esc` / Start: Resume · Options · Restart run · Quit to title, over a blurred and
  dimmed world. Restart and Quit each confirm; nothing else in the game does. Back goes exactly one
  level, and quitting to the title keeps the run so Continue has something to continue.
- `ConfirmDialog`, the only thing in the game that asks twice — and the one consumer of the
  hold-to-confirm accessibility setting.
- `tools/verify_pause.tscn` — headless proof that opening really stops the tree, that back goes one
  level and not two, and that cancelling a restart changes nothing.
- Options screen: five tabs — gameplay, controls, video, audio, accessibility — reachable from the
  title and built from one table, so the rows it draws and the settings that exist cannot drift
  apart. Every setting applies the moment it changes and is written to `user://settings.json`.
- Full input rebinding, both devices, from one row each: the device the player presses with decides
  which column changes. Overrides only, stored in `user://bindings.json`, with a reset per device.
- `OptionRow` and `KeybindRow`, the two rows every settings screen will reuse — a ten-block slider,
  a pill toggle and a `< value >` picker, all on the same focus chrome.
- Damage numbers, hitstop, reduce flashing and the sprint mode now read their setting live. Aim
  assist, tutorial prompts, screen shake and the colourblind telegraphs are stored and waiting for
  the features that will read them.
- `menu_prev_tab` and `menu_next_tab` input actions.
- `tools/verify_options.tscn` — headless proof that every setting has a row, that a row writes
  through to the file, and that a rebind moves the InputMap and comes back on a reset.
- In-run HUD: health and stamina bottom-left, ammo bottom-right with a ranged weapon in hand,
  wave and money top-right. Every element listens on the `EventBus` and holds no reference to the
  player. Damage numbers exist and are off by default.
- Run state: money, the wave index and a `RunStats` tally — perfect hits, perfect parries, kills by
  archetype, money earned and spent, run time — collected while the run happens.
- `Settings` and `SaveManager`, both static classes rather than autoloads: every player-facing
  setting, applied the moment it changes and written to `user://settings.json` as JSON.
- Four audio buses — Master, Music, SFX, Ambience — for the audio settings to act on.
- `tools/verify_hud.tscn` — headless proof that the HUD answers every signal it claims to, that
  ammo follows the weapon, and that damage numbers stay off until asked for.
- Title screen: Play · Options · Quit, pad-navigable from the first frame, with Play becoming
  Continue and a New run entry appearing once a run is under way. Built to the Figma design — the
  tokens, the 96 px margins and the 420 × 72 menu rows. A grey wash stands in for the island until
  the arena is composed behind it.
- A Garden Fence intro sting before the title, skippable with any button.
- `MenuEntry`, the menu row every screen will reuse: caret, label, and the glyph that fires it.
- A shared UI theme under `assets/themes/` carrying the design tokens, the `UI_` string table in
  `assets/locale/ui.csv`, and Badeen Display and Inter under `assets/fonts/`.

### Changed

- **The island's grass grows in two lengths.** Half of it stands between 0.5 m and 0.85 m and the
  other half stays under a third of a metre, drawn as height and width independently rather than
  as one size scaled up. What read as a carpet was never the amount of grass — it was that every
  blade of it was the same length. The tall band stops under 1.1 m, the line the camera's occlusion
  draws to a body, which is the height at which ground cover stops dressing a fight and starts
  hiding one.
- Grass takes its wind over the tall band's own height, so one set of figures now serves both
  lengths: a long blade leans over and the tuft beside it barely stirs.

### Fixed

- Four headless checks read whatever run happened to be saved on the machine. `GameState` restores
  a run at boot, so a developer carrying the gun ran `verify_combat` against gun damage and
  `verify_animation` against an empty magazine. CI never saw it — a clean checkout has no `user://`.
  They now start from a fresh run and put the machine's own back.
- A run quit halfway through a wave came back at the **next** wave, silently skipping the one that
  was interrupted: the wave director read the state's current wave as if it were the last cleared
  one.
- The run clock counted time spent on the title screen with a run suspended behind it.
- Strings with a comma in them were cut short on screen: the locale CSV was written without
  quoting, so the merchant's card copy stopped at its first clause.
- A cold checkout failed to import: `project.godot` lists a translation file the CSV importer has
  not written yet. CI now imports twice and gates on the second pass, which also proves a cold
  import converges rather than merely surviving.
- `menu_options` and `menu_new_run` input actions, so the glyphs the menu prints are real.
- Playable prototype: a grey-box arena, a player who moves, sprints, dodges and parries, the
  three-attack fist chain with its chain and perfect windows, and farmhands that close the
  distance and swing.
- Components: health, stamina, hitbox, hurtbox, and a node-based state machine.
- `EventBus` and `GameState` autoloads, a free-orbit camera rig, hit feedback and a debug overlay.
- Balance as resources under `data/` — three fist attacks, the fists, and the farmhand.
- `tools/verify_combat.tscn` — headless proof of the damage, the perfect multiplier, the chain
  window, the parry and the enemy approach. CI now boots the game instead of parsing files.

- Project configuration: full input map (21 actions, gamepad and keyboard/mouse), named 3D
  physics layers, display and rendering settings, project version.
- `tools/verify_project_config.gd` — headless guard that fails the build when an action or a
  layer goes missing.
- Documentation set under `docs/`, including the game design with its balance tables, the
  architecture, the conventions, the asset pipeline, the release path and five ADRs.
- Shared Claude Code setup under `.claude/`, and `CLAUDE.md` at the root.
- GitHub Actions: lint and headless validation on every pull request, mac and Windows exports
  plus an itch.io publish on tags.
- Git LFS tracking for binary assets, configured before the first asset landed.

### Added

- An island: generated terrain with a real coastline, a beach, gentle inland relief, water you can
  wade into, and scattered palms, rocks and grass. Built by `tools/build_island.gd` and baked to a
  scene; `tools/verify_island.tscn` enforces the composition rules combat depends on — including a
  height ceiling, because a fixed camera cannot look around a wall.
- `tools/screenshot.gd` — two looks at the arena as PNGs, because judging a world by reading its
  generator does not work.
- Water as a shader: depth-graded colour, moving surface, and foam along the whole shoreline,
  derived from the sea floor behind it rather than authored.
- Wading slows the player and the enemies, in proportion to depth.
- Fixed: the six authored boulders carried colliders scaled twice — the shape was already in
  metres and then inherited the visual's scale — so the largest one stopped the player from
  twelve metres away, through open ground. `verify_island` now reads the collider's own scale and
  caps its radius, which is the only way a bug that is invisible by definition gets caught.
- Palms and the larger boulders block. Clearance between blocking props is measured as the gap
  between their surfaces, so the player can always dodge through.

### Changed

- `run/main_scene` is `boot.tscn` again, and boot now opens the intro rather than the arena.
- The game ships in English only. The `tr()` layer stays; a second locale does not.
- The camera is **fixed** and only follows the player. Framing it from one direction for the whole
  game means every silhouette reads the same way, the island is composed for one viewpoint, and a
  telegraph can never hide behind geometry.

### Removed

- The `[dotnet]` block from `project.godot` — this is a GDScript project.
- Five input actions that a fixed camera has no use for: `camera_left`, `camera_right`,
  `camera_up`, `camera_down`, `camera_recenter`.

[Unreleased]: https://github.com/pepito2t/fight-island/commits/main
