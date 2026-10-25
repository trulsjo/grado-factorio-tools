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
- **The bug scan runs `scripts/check.ps1` unless CI's check passes on the commit the review
  reads.** It waits on a run not yet finished with `gh run watch <id> --exit-status`, and names a
  run that passed instead of running the check. The session looks before the lane starts, with
  `gh run list --workflow check.yml --commit <full SHA> --json databaseId,headSha,status,conclusion`.
  Either way the bug scan runs each self-test that script's header says the change calls for
  and CI does not run, those that need the game among them. It reverts each claim of a script
  on a copy, as the brief says; a revert that fails nothing is a finding.
- **One fresh agent runs both lanes** when the change touches no script, or when each commit
  since the last review answers one of its findings; anything else gets an agent per lane.
  It touches one when its diff changes a line of code in `scripts/`, `.githooks/` or
  `.github/workflows`; help text and message strings alone do not.
- **The session hands each lane [review-brief.md](review-brief.md)**, filled in with the change's
  particulars.
- **The working tree stays on the branch the lanes read until every lane has reported**: a
  check run across a switch reads two branches' files.
- **The reviewing session scores each finding itself**, on the plugin's rubric.
- **A check fails when the rules it reads, or the set it must cover, come back empty, and its
  self-test covers that run.** A run that only has nothing to check this time, such as a commit
  that stages no Markdown, may pass, and says it read nothing. A lister that does not fail is
  outside this.

## What is reported

- **Each review posts one comment on the pull request** once its findings are acted on: every
  finding that survived verification, its score, whether it was verified and its outcome. A
  review with no finding says so there. Its bug scan section says which check it stands on:
  CI's run, by its id, or a local run. The comment is not edited once posted, and the
  plugin's own comment format is not used.
- **A finding at 80 or more must be fixed; the rest are recorded.**
- **A pushed commit is not rewritten, with one exception**: a finding about the tip commit's
  body may be fixed by one amend and one force-push, on the session's own branch, its pull
  request unmerged, before any fix commit makes it no longer the tip. The outcome names the
  commit by subject as amended. A body below the tip is recorded.
- **Do not re-score to make a finding binding.** Say it matters and let a human decide.

