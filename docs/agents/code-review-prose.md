# Code review — the prose rules

The prose lane loads this page, after [code-review.md](code-review.md); the bug scan does not. The
evidence is in [code-review-evidence.md](code-review-evidence.md).

## Review the prose, not only the code

The shared checks are in
[`docs/code-review-rules.md`](../code-review-rules.md)'s *Prose*; the lane loads that section too,
and a pull request body is prose. This repository's own:

- **When a change supersedes a figure, grep for the old one**, and read every hit in
  `docs/extraction-plan.md`, `docs/adr/`, `CLAUDE.md`, `GLOSSARY.md`, this page,
  `code-review.md` and `code-review-evidence.md`.
- **An old figure struck through beside what replaced it is not a defect; an unmarked one is.**
- **A statement about a sibling repository**, the diff's, a lane's or the session's, is read
  with the passage around it and carries the commit and the date; one without is a finding.
- **A sibling's ticket or pull request is written with its repository**, as
  `trulsjo/grado-factorio-modpack#267` or `grado-factorio-modpack#267`, in a commit message, a
  pull request body, a ticket and a page: a bare `#267` here is this repository's. One bare is a
  finding.
- **Check a claim about entanglement against the file, not the reference count.**
- **A pull request body's `## Summary` prose is brief, with no preamble**, as the
  `mattpocock-skills:pr` skill asks. Prose that restates the visual, a preamble, or prose past
  what the visual needs is a finding.
- **Flag a header or comment that lists what the code lists**: self-test cases, fixtures, a count
  of them, a list of refusals.
- **Where a change writes in a ruling it cites, name what carries each rule it adds**: a cited
  ruling, or the page it moved from unchanged; a rule with neither is a finding. Reasoning, an
  incident or a quotation is no rule. PR #437 added two: a confirmer that "runs no check and no
  revert", and one set of lines for a fix's turn and a later commit's (#447).
