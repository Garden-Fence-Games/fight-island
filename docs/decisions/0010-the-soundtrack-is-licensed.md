# 0010 — Everything is synthesised, except the voices and the soundtrack

**Status:** Accepted
**Date:** 2026-09-14

## Context

Sound was the most visible placeholder a fighting game can have: a hit that sounds hollow cancels
every hour spent on the timing. The open question was whether audio would be CC0, commissioned or
bought, and it was framed as one question because it was assumed one answer would cover the whole
soundtrack-and-effects problem.

It does not. A hit signature and a piece of music fail in different ways. A hit has to be *read* —
mid-fight, under a crowd, with the eye on the enemy rather than on the player's own hand — and what
makes it readable is being able to tune it against the frame it lands on. A track has to be *liked*,
which is not something tuning produces.

## Decision

**Every sound the island makes is synthesised at startup** — the combat signatures, the footfalls,
the wind-up, the gunshots, the stings, the death cry and the surf bed alike. Nothing is fetched, and
the shipped game carries no sound effect files at all.

**Two exceptions, for two different reasons.**

- **The voices are ours**, recorded for this project. A voice is the one thing a sine cannot do.
- **The soundtrack is licensed**, drawn as a shuffle bag from the moment the game boots. It is the
  only third-party content in the game that is neither CC0 nor ours.

So the original question splits: the effects were never bought, because synthesis answered them
better than a library would have; the music was, because nothing else would have.

## Consequences

- A hit signature is a handful of numbers, so making a parry read differently from a perfect strike
  is an edit rather than a search through a sound pack. Nothing in the game distinguishes itself by
  volume alone — the first thing a player turns down and the first thing a loud fight buries.
- No audio files in Git LFS for effects, and no licence to track for them.
- **The soundtrack is the one thing in `docs/credits.md` that still has to be cleared.** A
  subscription licence is granted to a subscriber for a use, not to a file for ever, and the use
  here is a commercial game on itch.io and then on Steam. That has to be confirmed against the
  actual terms before release — cheap to check now, expensive to discover afterwards.
- Replacing the soundtrack later costs five rows in a document and five files. Replacing the effects
  would cost the tuning, which is why they are the half that was not bought.

## Alternatives rejected

**CC0 for everything, including music.** The original default. It survives for the island's props
and it does not survive for the soundtrack: free music that fits a game is rarer than free rocks
that fit an island, and the search is not cheaper than the licence.

**Commissioned effects.** Would have produced a better-sounding hit than a sine and a worse-tuned
one, because the iteration loop runs through somebody else's calendar.

**Shipping sampled effects from a pack.** The thing this decision exists to avoid: a library hit is
a fixed object, and the whole design rests on the player hearing the difference between a normal
strike and a perfect one.
