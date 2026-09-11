# 0001 — GDScript, not C#

**Status:** Accepted
**Date:** 2026-09-11

## Context

The project was created with the Godot .NET editor, so `project.godot` carried a
`[dotnet] project/assembly_name` block. No `.cs`, `.csproj` or `.sln` file was ever created, so
nothing was committed either way. The only Godot installed locally is the mono build.

## Decision

GDScript, statically typed. The `[dotnet]` block is removed.

## Consequences

- Instant iteration: no build step between editing and running.
- Nothing extra to sign or notarise on macOS, and no .NET runtime in the shipped bundle.
- The whole ecosystem's examples, addons and answers are GDScript first.
- The mono editor still runs the project fine, but it exports with mono templates and fatter
  binaries. Prefer the standard build locally, or let CI produce shippable artifacts.
- Never add C# later without superseding this record. Mixing the two doubles the conventions
  surface for no gain at this scale.

## Alternatives rejected

**C#** — stronger typing and closer to the team's TypeScript habits, but a compile step on every
change, a heavier macOS release path, and fewer worked examples for the gameplay problems this
project actually has.

**Hybrid GDScript plus C#** — powerful in a large team, and pure overhead in a small one.
