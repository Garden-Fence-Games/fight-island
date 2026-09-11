# 0002 — Godot file naming overrides the global kebab-case rule

**Status:** Accepted
**Date:** 2026-09-11

## Context

The global `~/.claude/CLAUDE.md` mandates `kebab-case` file and folder names for all languages.
Godot's official style guide mandates `snake_case` for `.gd`, `.tscn`, `.tres` and assets, and
`PascalCase` for `class_name` and node names. The two cannot both hold inside `res://`.

## Decision

Inside this repository, **Godot wins for engine files**. Everything else keeps kebab-case.

| Zone | Convention |
|---|---|
| Anything Godot loads — `scenes/`, `scripts/`, `assets/`, `data/`, `addons/` | `snake_case` |
| Node names, `class_name`, custom Resource types | `PascalCase` |
| `docs/`, `tools/`, `.github/` | `kebab-case` |

## Consequences

- `preload("res://scripts/actors/player/player.gd")` reads like every other Godot project.
- The editor generates files itself — `*.import` sidecars, `export_presets.cfg`, `.godot/` — and
  their casing cannot be controlled. Enforcing kebab-case would produce a permanently mixed tree.
- Reviewers must not "fix" snake_case `.gd` files. This record is the answer.

## Alternatives rejected

**Kebab-case everywhere.** The decisive argument is not consistency, it is correctness: Godot's
`res://` filesystem is **case-sensitive even when macOS is not**, so a casing mistake runs locally
and fails only after export, on another machine. Fighting the engine's convention multiplies the
chances of exactly that bug.
