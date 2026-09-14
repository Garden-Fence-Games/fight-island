# 0011 — The game is given away, and what that costs

**Status:** Accepted
**Date:** 2026-09-14

## Context

The price was never written down, and three separate decisions had quietly been taking it as an
input: what the soundtrack licence has to answer for, whether the Steam hundred is an advance or an
expense, and what the repository's own licence should be.

A price left unstated is not neutral. It defaults to *probably paid, decide later*, which is the
reading that makes every one of those three more expensive than it needs to be.

## Decision

**The game is free.** Nothing is sold, and there are no in-app purchases, no cosmetics and no paid
unlocks. A player downloads a build and plays the whole run.

## Consequences

- **The Steam hundred is a flat expense, not an advance.** It is owed for a free title exactly as it
  is for a paid one, and the thousand dollars of revenue that would make it recoverable is not
  coming. So the question is no longer *when does it pay for itself* — it is whether being on Steam
  is worth a hundred dollars, which is a much easier question to answer honestly.
- **The macOS cost does not go away.** Notarisation still needs the paid Apple Developer membership;
  Gatekeeper does not care that the download was free, and *"the application is damaged"* is the
  first thing a player would see without it.
- **The soundtrack licence gets smaller, not absent.** Nothing has to be cleared for sale and no
  revenue term applies — see [0010](0010-the-soundtrack-is-licensed.md). What is left is that a
  subscription is granted to a subscriber for a use rather than to a file for ever, and that these
  tracks ship inside a downloadable build.
- **The repository's licence is still an open question.** Free to play is not open source, and this
  decision deliberately does not answer it. The code and the game are handed out on different terms
  and nothing about giving the game away obliges the repository to follow.
- **There is no storefront copy to write about value.** An itch.io page for a free game sells the
  thing itself, which suits a game whose pitch is one sentence long.

## Alternatives rejected

**A price on itch.io.** The honest reason it was never chosen: this is a first shipped game with a
forty-minute run and one difficulty, and a price tag turns every rough edge into a complaint a buyer
is entitled to make. Free buys the right to ship it when it is good rather than when it is worth
money.

**Free with paid cosmetics.** It would contradict the design out loud. The whole economy is built on
one purchase per wave and on what the player gives up to make it; a second currency that real money
tops up is the same design with its point removed.

**Pay what you want.** Defensible, and it drags the whole revenue-term half of the licence question
back in for an amount that a game with no audience yet would not collect.
