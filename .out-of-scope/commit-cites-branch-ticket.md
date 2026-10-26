# A commit check that each commit cites its branch's ticket

`commit-check.ps1` does not read a branch's name, and does not ask each commit to cite the
tickets that name holds. Truls ruled this out on 2026-10-26, closing #245.

## What was asked

#245 asked `commit-check.ps1 -Range` to read the ticket numbers a branch's name opens with, and
warn on each commit in the range whose message cites none of them. It came from the retro of
trulsjo/grado-factorio-modpack#387, whose fix commit cited grado-factorio-modpack#386 and not its
branch's grado-factorio-modpack#383 (read 2026-10-26 at `58132ee`, that pull request's head). The
rule it leaned on is `docs/commit-convention.md`'s "cite the ticket where there is one", which
governs a body.

## Why it is out of scope

The check would flag mostly commits that cite on purpose. Measured on 2026-10-26 (10:26 UTC),
with grado-factorio-modpack's `main` at `2cd7936` and realistic-fusion-refreshed's at `aac0922`,
over the last 30 merged pull requests of each, counting every number in a branch's name as one
of its tickets, and the three names that give a range by its ends as the whole range:

| Repository | Branch names opening with a number | Commits citing none of them | Commits read |
|---|---|---|---|
| grado-factorio-modpack | 28 of 30 | 11, in 7 pull requests | 103 |
| realistic-fusion-refreshed | 8 of 30 | 83, in 23 pull requests | 238 |

Of those commits, 6 of 11 in grado-factorio-modpack and 54 of 83 in realistic-fusion-refreshed
cite their own pull request instead, by design: a fix commit that names "the plugin pass on PR
#360" (grado-factorio-modpack#360's), or realistic-fusion-refreshed's "add #779's rows to the
review figures". On realistic-fusion-refreshed#779, 11 of 21 commits cite none of the branch's
numbers. 22 of that repository's 30 branch names open with a word, often a prefix (`feat/767-…`,
`chore/765-753-…`), and in both repositories some names carry a pull request's number and no
ticket's (`retro-380-tracker-lines` in grado-factorio-modpack, `retro-713-followups` in
realistic-fusion-refreshed).

Narrowing the check to accept the pull request's own number as well leaves a residue of the kind
#245 was filed for, a fix commit that cites neither, which a reviewer catches by reading and the
author fixes by a reword before the push. That does not earn a rule in a check three repositories
share, where every rule is surface each of them carries.

What the commit convention asks stays as it is. A missing citation is the reviewer's to judge,
as it was on grado-factorio-modpack#380 and grado-factorio-modpack#387.

## How it was measured

For each repository, `gh pr list --state merged --limit 30 --json number,headRefName,commits`,
then, per pull request, every run of digits in `headRefName`, and each commit whose headline and
body hold no `#<n>` for any of them, read with `#<n>` followed by a non-digit or the end. Three
names give a range by its ends, and each was read as the range its pull request closes:
grado-factorio-modpack's `368-371-move-to-2.1` and realistic-fusion-refreshed's
`feat/760-762-review-skill-guards` and `tickets-575-578`. Read as two numbers each, as first
counted, they add 2 and 4 commits. The count is of the commits on each pull request as it was
before its rebase merge.

## Prior requests

- #245: "Warn on a commit that cites none of its branch's tickets"
