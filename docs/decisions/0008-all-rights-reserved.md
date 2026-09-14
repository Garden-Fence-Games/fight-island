# 0008 — All rights reserved, with third-party assets under their own terms

**Status:** Accepted
**Date:** 2026-09-14

## Context

The repository shipped without a `LICENSE` file. While it was private that cost nothing, but the
itch.io release makes the code and the assets readable by whoever unpacks a build, and a repository
with no licence is not "closed by default" in any way a buyer or a contributor can rely on — it is
simply silent. `README.md` said *not yet decided*, and `docs/roadmap.md` carried the question in its
open-decisions table with *all rights reserved on the code* as the default if nobody chose.

The tree is not uniformly ours. `docs/credits.md` lists third-party sources under their own terms,
several flagged `prototype only`, and a repository-wide licence that swept them up would be claiming
rights Garden Fence does not hold.

## Decision

**All rights reserved**, in a `LICENSE` file at the root, covering code **and** assets.

Third-party assets keep the licences they came with. `docs/credits.md` governs them, `LICENSE` says
so explicitly, and nothing in `LICENSE` grants a right over an asset Garden Fence does not hold.

Buying or downloading a build grants the right to play it, and nothing more.

## Consequences

- `README.md` points at `LICENSE` instead of deferring to the roadmap.
- The open-decisions row is gone from `docs/roadmap.md`; this file is the answer.
- Anyone who wants to reuse a part of this repository has to ask. That is the intended friction.
- Adding a third-party asset still means a row in `docs/credits.md` — the licence now depends on
  that file being right, so the existing rule has teeth it did not have before.

## Alternatives rejected

**A permissive open-source licence (MIT, Apache-2.0).** This is a commercial game meant for itch.io
and possibly Steam, not a library. MIT on the code would also sit awkwardly beside assets that
cannot be MIT, and the mismatch is exactly the thing people get wrong when they copy a repository.

**A source-available licence (BSL, PolyForm).** More precise, and a real option later if the code
ever wants readers. It buys nothing today: there is no audience asking to read it, and every extra
clause is a clause to defend.

**Leaving it undecided until the release.** That is what produced this issue. The default was
already written down; what was missing was a file, and the file costs half an hour.
