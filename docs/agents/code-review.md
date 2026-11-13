# Code review — this repository's values

**The procedure is [`docs/code-review-procedure.md`](../code-review-procedure.md), and the shared
rules [`docs/code-review-rules.md`](../code-review-rules.md).** This page gives this repository's
values and its own steps. The evidence is in [code-review-evidence.md](code-review-evidence.md).

## How a review is run

- **When: on the pull request.** Skip the review step inside `/implement` or any skill. Before
  pushing any commit, the session runs whatever its diff or message says a script or a command
  does, prints, refuses or exits with.
- **Second pass: `on request`**, the panel of [review-panel.md](review-panel.md), when Truls asks.
- **Trigger page:** this page. **Brief template:** [review-brief.md](review-brief.md).
  **Reviewer's copy:** a clone. **Raw output:** none. **Merge workflow:** `check.yml`.
- **Two lanes.** A bug scan; and a prose lane applying the **further reading**,
  [code-review-prose.md](code-review-prose.md), which the bug scan does not load. The prose
  lane takes in the `/code-review` plugin's `CLAUDE.md` and code-comment lanes.
- **Check run: the bug scan runs `scripts/check.ps1` unless CI's check passes on the commit the
  review reads.** The session looks before the lane starts, with
  `gh run list --workflow check.yml --commit <full SHA> --json databaseId,headSha,status,conclusion`.
  Either way the bug scan runs each self-test that script's header says the change calls for
  and CI does not run, those that need the game among them.
- **Test claims: `scripts/revert-run.ps1`.** The bug scan reverts each claim of a script on a
  copy, and each condition on a line the diff adds or changes that the claims leave out; a
  revert that fails nothing is a finding.
- **One fresh agent runs both lanes** when the change touches no script; anything else gets an
  agent per lane. It touches one when its diff changes a line of code in `scripts/`,
  `.githooks/` or `.github/workflows`; help text and message strings alone do not.
- **The working tree stays on the branch the lanes read until every lane has reported**: a
  check run across a switch reads two branches' files.
- **The reviewing session scores each finding itself**, on the plugin's rubric. Where a rule on a
  review page sets a finding's score, the session gives it, which is not re-grading.
- **A check fails when the rules it reads, or the set it must cover, come back empty, and its
  self-test covers that run.** A run that only has nothing to check this time, such as a commit
  that stages no Markdown, may pass, and says it read nothing. A lister that does not fail is
  outside this.

## What is reported

- **Where recorded: one comment on the pull request**, posted once each fix is confirmed, with
  each finding's score and whether it was verified. A review with no finding says so there.
  Its bug scan section says which check it stands on: CI's run, by its id, or a local run.
  The comment is not edited once posted, and the plugin's own comment format is not used.
- **The threshold is a score of 80 or more**: such a finding is fixed; the rest are recorded.
- **A change that does other than an acceptance criterion, the *Asked*, or a ruling of Truls's,
  on a ticket it closes asks is a finding scored 80**, in either lane, shown by a read of the
  change or an input that was run, unless the pull request cites Truls's comment allowing it.
- **A pushed commit is not rewritten, with one exception**: a finding about the tip commit's
  body may be fixed by one amend and one force-push, on the session's own branch, its pull
  request unmerged, before any fix commit makes it no longer the tip. The outcome names the
  commit by subject as amended. A body below the tip is recorded.
