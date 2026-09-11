# 0003 — glTF `.glb` as the engine-facing source, not direct `.blend` import

**Status:** Accepted
**Date:** 2026-09-11

## Context

Godot 4 imports `.blend` files natively by shelling out to Blender, which removes the export step
and any drift between the art file and the engine. It requires a configured Blender executable on
every machine that reimports — including CI runners and any build machine. Blender is not
currently installed here at all.

## Decision

`.blend` files live in `art-source/`, tracked by Git LFS. **`.glb` files are committed** to
`assets/models/` and are what the engine loads.

Direct `.blend` import is allowed during blockout. Switch before the first CI export.

## Consequences

- CI and the release path depend on nothing but Godot.
- `.glb` is an explicit, inspectable, version-stable contract.
- It costs one export click per art iteration.
- Both files are committed for every model, so the repository carries some redundancy. LFS makes
  that affordable.

## Alternatives rejected

**Direct `.blend` import everywhere.** Fastest inner loop, but it puts a Blender installation on
the critical path of every build, and the import is sensitive to the Blender version that wrote
the file.
