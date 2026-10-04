# 0013 — ZenNotes follows the shared documentation standard

**Status:** Accepted
**Date:** 2026-10-04

## Context

The ZenNotes folder had grown to thirteen notes in two sub-folders, written as long prose with
the project's history mixed into its current state. Every project in the vault used a different
shape, so nothing could be found by habit.

## Decision

The Fight Island notes follow the vault-wide standard,
`~/Documents/ZenNotes/inbox/Standard de documentation.md`. The split from
[0005](0005-docs-split-repo-zennotes.md) is unchanged: `docs/` says how and how much, ZenNotes
says where we are and why.

- Five flat notes: the hub `Fight Island`, then `Fight Island - Produit` (game design),
  `Fight Island - Technique`, `Fight Island - Exploitation` and `Fight Island - Ressources`.
- The hub holds the status (`## État`) and the open questions (`## Décisions à trancher`).
- Rule plus reason, present tense, tables and Mermaid. No history: the past lives in git and in
  these ADRs.

## Consequences

- The trigger table in `contributing.md` points at the new notes and sections.
- `/sync-notes` reads `## État` and `## Décisions à trancher` in the hub.
- The previous notes are kept in the vault's `archive/`.

## Alternatives rejected

**Keeping the prose-first tone.** It read well once and was slow to scan every time after; the
same facts fit in a third of the space as tables.
