# Changelog

All notable changes to this project are documented here, following
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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

### Changed

- The camera is **fixed** and only follows the player. Framing it from one direction for the whole
  game means every silhouette reads the same way, the island is composed for one viewpoint, and a
  telegraph can never hide behind geometry.

### Removed

- The `[dotnet]` block from `project.godot` — this is a GDScript project.
- Five input actions that a fixed camera has no use for: `camera_left`, `camera_right`,
  `camera_up`, `camera_down`, `camera_recenter`.

[Unreleased]: https://github.com/pepito2t/fight-island/commits/main
