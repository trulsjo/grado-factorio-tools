# Code review rules

**This page holds the review rules the repositories that link to it share**: what the threshold
does, and the prose checks every review makes. How and when a review runs is not on this page.
Each repository's `docs/agents/code-review.md` links this page and names its threshold.

Ruled by Truls on 2026-11-06 in
[*Rulings: code review rules*](https://github.com/trulsjo/grado-factorio-tools/issues/327),
rulings 1 and 2, with the threshold worded by
[*Rulings: a shared code review procedure*](https://github.com/trulsjo/grado-factorio-tools/issues/332),
ruling 7. Gathered from three review pages, read 2026-11-06: trulsjo/grado-factorio-tools's
*What is reported* at `e70669f`, trulsjo/grado-factorio-modpack's *The threshold gates the
comment, not the report* at `987e638`, and trulsjo/realistic-fusion-refreshed's *The verdict
sorts the comment, not the report* and *Review the prose, not only the code* at `9fd78b5`.

## The threshold sorts the comment, not the report

**The threshold is the grade at which a finding must be fixed.** Each repository names its own
value beside its link to this page: a score, a verdict, or every finding.

- **Every finding is reported, whatever its grade**, a verifier's verdict included. The threshold
  decides what must be fixed, and where a review posts more than one comment, which comment lists
  the finding. It does not decide what the person who ran the review is told, nor what reaches the
  pull request.
- **A review that posts nothing must still say what it set aside**: each finding, its grade, and
  whether it was verified. A silent pass and a filtered pass must never look the same.
- **A finding is not re-graded to move it across the threshold.** Where it matters more than its
  grade says, the review says so beside it, and a human decides. A grade raised to route around
  the threshold destroys the only signal the grade carries.

## Prose

Whether the sentence beside a number says what the number says is a review's job. Each repository
keeps its own prose checks beside its link to this page; these two are shared.

- **Check every number in prose against a number in the diff, and do the arithmetic.** Not "does
  this look plausible": add it up, multiply it out. A count, a percentage, a tally of kept,
  replaced and dropped: each is a claim with an arithmetic answer.
- **Treat a quantifier as an instruction to list every case.** "Every", "none", "the only one", "no
  replacement was found": a claim about all or none of a set is checked by walking the set, never
  by agreeing with its tone. A fix that adds a figure walks again every quantifier that covers the
  place it lands.
