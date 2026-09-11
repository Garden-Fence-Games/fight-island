# 0004 — Three autoloads, and `SaveManager` as a static class

**Status:** Accepted
**Date:** 2026-09-11

## Context

Autoloads are convenient and they accumulate. Each one is global mutable state, an implicit
dependency in every script that touches it, and something to stand up in a test.

## Decision

Exactly three: **`EventBus`** (signals only, zero state), **`GameState`** (the current run),
**`AudioManager`** (buses, player pool, music).

**`SaveManager` is not an autoload.** It is `class_name SaveManager extends RefCounted` with
static methods.

## Consequences

- `SaveManager.write_settings(...)` reads identically at the call site, without a node in the
  tree, without `_ready` ordering, and without a singleton to mock.
- `GameState` owns run data and nothing else — no gameplay logic, no node references. Keeping it
  that narrow is what stops it becoming a god object.
- `EventBus` is only for cross-cutting listeners. A component talking to its owner uses a direct
  signal on the component.

## Alternatives rejected

**`Settings`** — folded into `SaveManager` and `GameState`.
**`SceneManager`** — a forty-line `main.gd` covers four scenes.
**`DebugManager`** — a scene toggled by an action.
