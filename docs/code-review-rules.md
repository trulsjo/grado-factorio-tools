# Code review rules

**This page holds the review rules the repositories that link to it share**: what the threshold
does, and the prose checks every review makes. How and when a review runs is not on this page.
Each repository's `docs/agents/code-review.md` links this page and names its threshold.

Ruled by Truls on 2026-11-06 in
[*Rulings: code review rules*](https://github.com/trulsjo/grado-factorio-tools/issues/327),
rulings 1 and 2, with the threshold worded by
[*Rulings: a shared code review procedure*](https://github.com/trulsjo/grado-factorio-tools/issues/332),
ruling 7. Gathered from four review pages, read 2026-11-06: trulsjo/grado-factorio-tools's
*What is reported* and its `docs/agents/code-review-prose.md` (the quantifier check) at
`e70669f`, trulsjo/grado-factorio-modpack's *The threshold gates the comment, not the report*
and *Review the prose, not only the code* at `987e638`, and trulsjo/realistic-fusion-refreshed's
*The verdict sorts the comment, not the report* and *Review the prose, not only the code* at
`9fd78b5`. Two checks under *Prose* were ruled by Truls at triage on 2026-11-07: the stub check
at [#369](https://github.com/trulsjo/grado-factorio-tools/issues/369#issuecomment-6704506057),
with a sibling read at a commit of its own `main` by
[a later comment](https://github.com/trulsjo/grado-factorio-tools/issues/369#issuecomment-6706987161),
and the question of whether a cited check could have failed at
[#370](https://github.com/trulsjo/grado-factorio-tools/issues/370#issuecomment-6704506905). The
rule on a guard deleted as dead was ruled by Truls's filing of
[#401](https://github.com/trulsjo/grado-factorio-tools/issues/401) on 2026-11-08.

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
keeps its own prose checks beside its link to this page; these are shared.

- **Check every number in prose against a number in the diff, and do the arithmetic.** Not "does
  this look plausible": add it up, multiply it out. A count, a percentage, a tally of kept,
  replaced and dropped: each is a claim with an arithmetic answer.
- **Treat a quantifier as an instruction to list every case.** "Every", "none", "the only one", "no
  replacement was found": a claim about all or none of a set is checked by walking the set, never
  by agreeing with its tone. A fix that adds a figure walks again every quantifier that covers the
  place it lands.
- **When the change edits a shared page, read every stub page that links it against it.** The
  stubs are the hits of `git grep -l <the page's file name>`, run in this repository on the
  change and in each sibling at a commit of its `main` cited with its date, whose stubs link
  the page through the pin. A stub sentence that narrows, widens or repeats the shared page is
  a finding: no gate can read it. On trulsjo/grado-factorio-tools's PR #368 two stubs narrowed
  the pages they link, one naming a single way to name a branch commit where three are allowed,
  and one reporting only the findings that survived verification. The PR's own review missed
  both, and the review panel found them
  ([its comment](https://github.com/trulsjo/grado-factorio-tools/pull/368#issuecomment-6703616741),
  findings A and B).
- **For every check the pull request cites as passing, ask whether it could have failed on this
  change.** A check that reads none of what the change touched passes whatever the change does,
  and citing it is a finding, even with its passing run shown. For code a revert answers the
  question. For help text, prose or configuration no revert applies, so the reviewer names what
  the check reads, whether that includes the change, and what in the change it would have
  refused: a check that reads the file and refuses nothing the edit could break is no evidence.
  On trulsjo/grado-factorio-tools's PR #368 the body cited `pr-body-check.ps1 -SelfTest` for an
  edit to that script's help text, and the self-test reads no help text. All three panel
  reviewers found it
  ([their comment](https://github.com/trulsjo/grado-factorio-tools/pull/368#issuecomment-6703616741),
  finding G), and the PR's own review did not.
- **A guard or branch the change deletes as dead carries two things**: a reason no input reaches
  it, read from the code, and a run of the same check or script before and after the deletion,
  over the same inputs, with the same output. A deletion lacking either is a finding. A
  revert that passes the self-test is no evidence of either: a live guard with no case passes
  the same way. Fixing trulsjo/grado-factorio-tools's PR #395's panel finding I
  ([its comment](https://github.com/trulsjo/grado-factorio-tools/pull/395#issuecomment-6725858356)),
  the session first meant to delete four guards of `strict-list-check.ps1` on their passing
  reverts alone, until a side agent raised it.
