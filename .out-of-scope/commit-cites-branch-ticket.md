# A commit check that each commit cites its branch's ticket

`commit-check.ps1` does not read a branch's name, and does not ask each commit to cite the
tickets that name holds. Truls ruled this out on 2026-10-26, closing #245.

## What was asked

#245 asked `commit-check.ps1 -Range` to read the ticket numbers a branch's name opens with, and
warn on each commit in the range whose message cites none of them. It came from the retro of
trulsjo/grado-factorio-modpack#387, whose fix commit cited #386 and not its branch's #383, the
second such commit in that repository (PR #380's pre-PR finding 13 was the first). The rule it
leaned on is `docs/commit-convention.md`'s "cite the ticket where there is one", which governs a
body.

## Why it is out of scope

The check would flag mostly commits that cite on purpose. Measured on 2026-10-26 (10:26 UTC)
over the last 30 merged pull requests of each sibling, counting every number in a branch's name
as one of its tickets:

| Repository | Branch names opening with a number | Commits citing none of them | Commits read |
|---|---|---|---|
| grado-factorio-modpack | 28 of 30 | 13, in 8 pull requests | 103 |
| realistic-fusion-refreshed | 8 of 30 | 87, in 24 pull requests | 238 |

Most of those commits cite their own pull request instead, by design: a fix commit that names
"the plugin pass on PR #360", or realistic-fusion-refreshed's "add #779's rows to the review
figures". On that repository's PR #779, 11 of 21 commits cite none of the branch's numbers. Its
branch names carry a prefix (`feat/767-…`, `chore/765-753-…`), and some names carry a pull
request's number and no ticket's (`retro-380-tracker-lines`, `retro-713-followups`).

Narrowing the check to accept the pull request's own number as well leaves a residue of the kind
#245 was filed for, a fix commit that cites neither, which a reviewer catches by reading and the
author fixes by a reword before the push. That does not earn a rule in a check three repositories
share, where every rule is surface each of them carries.

What the commit convention asks stays as it is. A missing citation is the reviewer's to judge,
as it was on PR #380 and #387.

## How it was measured

For each repository, `gh pr list --state merged --limit 30 --json number,headRefName,commits`,
then, per pull request, every run of digits in `headRefName`, and each commit whose headline and
body hold no `#<n>` for any of them, read with `#<n>` followed by a non-digit or the end. The
count is of the commits on each pull request as it was before its rebase merge.

## Prior requests

- #245: "Warn on a commit that cites none of its branch's tickets"
