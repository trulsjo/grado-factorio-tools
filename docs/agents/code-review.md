# Code review — this repository's rules

On top of the `/code-review` plugin. The evidence is in
[code-review-evidence.md](code-review-evidence.md).

## How a review is run

- **Once per change, on the pull request.** Skip the review step inside `/implement` or any
  skill: open the pull request first. Asked to review again, review only the commits since.
  Before pushing any commit, the session runs whatever its diff or message says a script or a
  command does, prints, refuses or exits with.
- **Two lanes.** A bug scan; and a prose lane applying the rules in
  [code-review-prose.md](code-review-prose.md), which that lane loads and the bug scan does
  not. The prose lane takes in the plugin's `CLAUDE.md` and code-comment lanes.
- **The bug scan runs `scripts/check.ps1` unless CI's check has passed on the commit the
  review reads.** Then it names that run and does not run the check again; where the run has
  failed or not finished, it runs it. The session looks before the lane starts, with
  `gh run list --workflow check.yml --commit <full SHA> --json databaseId,headSha,status,conclusion`.
  Either way the bug scan runs each self-test that script's header says the change calls for
  and CI does not run, those that need the game among them.
- **One fresh agent runs both lanes** when the change touches no script, or when each commit
  since the last review answers one of its findings; anything else gets an agent per lane.
  It touches one when its diff changes a line of code in `scripts/`, `.githooks/` or
  `.github/workflows`; help text and message strings alone do not.
- **The reviewing session scores each finding itself**, on the plugin's rubric.

## What is reported

- **Each review posts one comment on the pull request** once its findings are acted on: every
  finding that survived verification, its score, whether it was verified and its outcome. A
  review with no finding says so there. Its bug scan section says which check it stands on:
  CI's run, by its id, or a local run. The comment is not edited once posted, and the
  plugin's own comment format is not used.
- **A finding at 80 or more must be fixed; the rest are recorded.**
- **A pushed commit is not rewritten, with one exception**: a finding about the tip commit's
  body may be fixed by one amend and one force-push, on the session's own branch, its pull
  request unmerged. The outcome names the commit by subject as amended. A body below
  the tip is recorded.
- **Do not re-score to make a finding binding.** Say it matters and let a human decide.
