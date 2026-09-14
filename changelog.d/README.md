# changelog.d

One file per change, assembled into `CHANGELOG.md` at release time by
`tools/assemble-changelog.sh`.

**Write your entry here, not in `CHANGELOG.md`.** Two pull requests then add two files and never
touch the same line of the same file. Appending to a shared `## [Unreleased]` block is what made
five branches conflict in a single evening, always on this one file and never on code — and a
conflict whose answer is always *keep both sides* is a conflict people stop reading.

## The file

`<section>-<slug>.md`, lowercase and hyphenated. The section is one of **added**, **changed**,
**deprecated**, **removed**, **fixed**, **security** — Keep a Changelog's six, and the assembler
groups by it. The slug says what changed, so that `git log --stat` is readable, and it is also the sort
key: inside a section the assembler lists fragments in filename order.

```
changelog.d/added-coins-and-rounds-spray-out-of-the-body.md
changelog.d/fixed-three-mutations-pointed-at-code-that-had-moved.md
```

The content is the entry exactly as it should read in the changelog: a Markdown bullet, bold lead
sentence, continuation lines indented two spaces, wrapped at 100 columns like the rest of the
repository. One file may hold more than one bullet if they are the same change seen twice, but two
unrelated changes are two files.

```markdown
- **A body that drops rounds drops one, two or three**, each a third of the time and each its own
  piece on the sand. How often a body drops any is unchanged.
```

Write the *why*, not the diff. The bullet is read by someone who was not in the pull request.

## The checks

`tools/assemble-changelog.sh --lint` refuses a name the assembler cannot place, and CI runs it. A
fragment named wrong is not a warning: it is a written entry that vanishes at release with nobody
looking for it.

`tools/assemble-changelog.sh --preview` prints what the next release will read.

## At release

`tools/assemble-changelog.sh 0.3.0` writes the section into `CHANGELOG.md`, adds the compare link,
and deletes the fragments. Commit the deletion with the release.
