# 0007 — Sprint is hold on a keyboard and toggle on a pad, and the player can say otherwise

**Status:** Accepted
**Date:** 2026-09-12

## Context

Sprint is held down for most of a fight. Which input shape that should take is not a matter of
taste, because the two audiences arrive with different muscle memory: a keyboard player expects to
hold `Shift`, and a pad player expects to click the stick once and have it stay. Shipping one of
the two makes the other audience fight the control.

The usual answer is a setting, and a setting alone is not enough: it needs a **default that is
already right for whoever is holding whatever they are holding**, or most players never open the
menu and simply find the sprint wrong.

## Decision

Three values, and the default is the third: `hold`, `toggle`, and **`auto`** — hold on a keyboard,
toggle on a pad, decided **per press** rather than once at launch.

Per press is the part that matters. A player who moves from keys to a pad mid-fight, or who has
both in front of them, gets the right behaviour from the device they actually pressed with:
`Settings.sprint_is_toggle(from_gamepad)` is asked at the moment of the press, and the device comes
from the event itself through `InputBindings.device_of`.

The latch that a toggle needs lives on the **body**, not in the sprint state. It has to survive the
state ending — a sprint interrupted by an attack and then resumed is still the same held intention.

## Consequences

- No launch-time device detection, and nothing to re-detect when a controller is plugged in halfway
  through a run. There is no device mode to get out of step with reality.
- A player who wants the other behaviour says so once in **Gameplay → Sprint**, and that answer
  applies to both devices, because someone who asks for a toggle means it.
- `wants_sprint()` is the single question the sprint state asks. Nothing else in the codebase knows
  whether sprint is held or toggled, so a fourth mode would be one more branch in one function.

## Alternatives rejected

**Hold everywhere.** Correct on a keyboard, and a cramp on a pad — the left stick is already being
pushed, and clicking it down for forty minutes is the thing players write about.

**Toggle everywhere.** Correct on a pad, and surprising on a keyboard, where `Shift` has meant
"while I hold this" in every game that came before.

**Detect the device once at launch and pick a default.** Almost right, and wrong exactly when it is
noticed: the player who plugs a controller in during wave 6 is the one who cares most.
