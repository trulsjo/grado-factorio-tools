# Code review — this repository's rules

On top of the `/code-review` plugin. The evidence is in
[code-review-evidence.md](code-review-evidence.md).

## How a review is run

- **Once per change, on the pull request.** Skip the review step inside `/implement` or any
  skill: open the pull request first. Asked to review again, review only the commits since.
  Before pushing any commit, the session runs whatever its diff or message says a script or a
  command does, prints, refuses or exits with.
- **Two lanes.** A bug scan, which runs `scripts/check.ps1` and each self-test its header says
  the change calls for; and a prose lane applying the rules below, which takes in the
  plugin's `CLAUDE.md` and code-comment lanes.
- **One fresh agent runs both lanes** when the change touches no script, or when each commit
  since the last review answers one of its findings; anything else gets an agent per lane.
  It touches one when its diff changes a line of code in `scripts/`, `.githooks/` or
  `.github/workflows`; help text and message strings alone do not.
- **The reviewing session scores each finding itself**, on the plugin's rubric.

## What is reported

- **Each review posts one comment on the pull request** once its findings are acted on: every
  finding that survived verification, its score, whether it was verified and its outcome. A
  review with no finding says so there. The comment is not edited once posted, and the
  plugin's own comment format is not used.
- **A finding at 80 or more must be fixed; the rest are recorded.**
- **A pushed commit is not rewritten, with one exception**: a finding about the tip commit's
  body may be fixed by one amend and one force-push, on the session's own branch, its pull
  request unmerged. The outcome names the commit by subject as amended. A body below
  the tip is recorded.
- **Do not re-score to make a finding binding.** Say it matters and let a human decide.

## Review the prose, not only the code

- **Check every number in prose, the pull request body included, against the diff, and do the
  arithmetic.**
- **Treat a quantifier as an instruction to enumerate.** "All" and "none" are checked by walking
  the set.
- **When a change supersedes a figure, grep for the old one**, and read every hit in
  `docs/extraction-plan.md`, `docs/adr/`, `CLAUDE.md`, `GLOSSARY.md` and these two pages.
- **An old figure struck through beside what replaced it is not a defect; an unmarked one is.**
- **A statement about a sibling repository**, the diff's, a lane's or the session's, is read
  with the passage around it and carries the commit and the date; one without is a finding.
  The session opens the place itself before the statement goes into the comment; unopened, it
  is left out and told to Truls in the report.
- **Check a claim about entanglement against the file, not the reference count.**
- **Flag a header or comment that lists what the code lists**: self-test cases, fixtures, a count
  of them, a list of refusals.
