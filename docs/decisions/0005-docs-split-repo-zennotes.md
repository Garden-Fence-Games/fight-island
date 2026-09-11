# 0005 — What lives in the repo and what lives in ZenNotes

**Status:** Accepted
**Date:** 2026-09-11

## Context

Project documentation has two audiences with different needs and different lifetimes: the
developer reading while coding, and the person asking where the project stands. Keeping both in
one place produces a document that is half stale status and half reference, and trustworthy as
neither.

## Decision

**`docs/` says how and how much. ZenNotes says where we are and why.**

- `docs/` is English, versioned with the code, and holds the technical reference. Every balance
  number lives there and in `data/*.tres`, and nowhere else.
- ZenNotes — `~/Documents/ZenNotes/inbox/tmbk/Garden Fence/Fight Island/` — is French and holds
  the human layer: pitch, decisions and their rationale, status, costs, deadlines. It may state an
  intention but **never a coefficient**.
- Each ZenNotes Documentation note ends with a `## Dans le dépôt` pointer list. That is the only
  cross-reference, and it points one way.
- `docs/` mentions ZenNotes in exactly two places — `CLAUDE.md` and `contributing.md` — without a
  path-by-path index that would need maintaining.

## Consequences

- Repo docs update in the same pull request; ZenNotes updates per milestone, and immediately when
  a decision closes or the status line becomes false. ZenNotes is not in git, so a per-PR rule
  could not be enforced and would rot into a lie.
- An open question lives in ZenNotes under *Décisions à trancher* with a recommended default. When
  it closes it becomes an ADR here and its line is deleted there.
- `/sync-notes` drafts the status refresh from the roadmap and the commit log.

## Alternatives rejected

**Everything in the repo.** Status notes in git go stale between releases and nobody reads them.
**Everything in ZenNotes.** Technical reference has to ship with the code it describes, or it
drifts within two commits.
