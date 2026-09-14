# 0008 — Aim assist is an accessibility setting, on by default, and it applies to the mouse

**Status:** Accepted
**Date:** 2026-09-14

## Context

The gun aims with the right stick, and a thumb is not a precise instrument. Without help a pad
player spends the fight fighting the stick instead of the farmers; with too much help the aim starts
choosing targets, and hitting things stops being a skill the player owns. The question had been open
since the prototype and outlived the weapon that raised it: the gun shipped, the magnetism did not.

The usual framing — *aim assist is what a pad needs and an insult on a mouse* — is what kept the
question open. It is also wrong here, because it assumes the reason for the feature is the device.

## Decision

A pull towards the nearest body inside a narrow cone around where the player is already pointing,
as a **three-value accessibility setting**: off, soft, strong. **Soft is the default.**

Three things make it a decision rather than a slider:

- **It pulls towards the body closest in angle, not in distance.** The player has aimed; the thing
  they most likely meant is the one nearest that line. The cone is about the error a thumb makes —
  wide enough to forgive it, narrow enough that it never picks a target the player was not looking
  at.
- **Soft leaves the last of the error with the player**, so an aim that was nearly lined up snaps
  and one that was not still misses. Strong takes all of it, which is what somebody who cannot hold
  a stick steady actually needs.
- **It applies to the mouse too.** This is the part that reads wrong and is right: the feature is an
  accessibility setting, not a pad affordance. Somebody who cannot hold a line with a mouse needs it
  exactly as much, and either way the player asked for it.

The assist is applied once, in `AimComponent.direction()`, so the head, the body, the swing and the
shot all agree about where the player is pointing. Its reach comes from the weapon in hand, so a
pistol reaches across the island and a fist does not drag the body round towards somebody out of
reach.

## Consequences

- Every caller of the aim gets the assist for free and none of them knows it exists. A shot that
  landed somewhere the character was visibly not facing would read as the game missing on its own,
  and that failure is now unreachable.
- The setting is saved like any other, and `tools/verify_aim.tscn` drives the real projection and
  the real group of live enemies — including letting go of a farmer the moment he dies.
- A fourth strength would be one more entry in one dictionary.
- The default is not neutral, and that is deliberate: most players never open the options, and a
  soft pull is closer to right for them than nothing is.

## Alternatives rejected

**No assist at all.** Honest, and it makes the gun a worse weapon than the stick for reasons that
have nothing to do with the design of either.

**Assist on the pad only.** The tidy answer, and it decides for the player which bodies deserve
help. The mouse player with a tremor is the one this would fail, silently.

**Assist that picks the nearest enemy by distance.** Cheaper to compute and wrong in the exact
moment it matters: the body the player is walking past is nearer than the one they are aiming at.
