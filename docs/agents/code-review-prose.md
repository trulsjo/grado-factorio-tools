# Code review — the prose rules

The prose lane of a review loads this page, and the bug scan does not. How a review is run and
what it reports are in [code-review.md](code-review.md); the evidence is in
[code-review-evidence.md](code-review-evidence.md).

## Review the prose, not only the code

- **Check every number in prose, the pull request body included, against the diff, and do the
  arithmetic.**
- **Treat a quantifier as an instruction to enumerate.** "All" and "none" are checked by walking
  the set.
- **When a change supersedes a figure, grep for the old one**, and read every hit in
  `docs/extraction-plan.md`, `docs/adr/`, `CLAUDE.md`, `GLOSSARY.md`, this page,
  `code-review.md` and `code-review-evidence.md`.
- **An old figure struck through beside what replaced it is not a defect; an unmarked one is.**
- **A statement about a sibling repository**, the diff's, a lane's or the session's, is read
  with the passage around it and carries the commit and the date; one without is a finding.
  The session opens the place itself before the statement goes into the comment; unopened, it
  is left out and told to Truls in the report.
- **Check a claim about entanglement against the file, not the reference count.**
- **Flag a header or comment that lists what the code lists**: self-test cases, fixtures, a count
  of them, a list of refusals.
