# Issue tracker: GitHub

Issues and specs for this repo live as GitHub issues. Use the `gh` CLI for all operations.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Write a multi-line body to a
  file and pass `--body-file <path>`; the same goes for `gh issue comment` and `gh pr create`. Write
  the file with the Write tool: a heredoc that writes the file is no safer. On 2026-10-08 one
  command of three such heredocs, 118 lines meant to write the bodies of what became #74, #75 and
  #76, failed here under the Bash tool with `unexpected EOF while looking for matching '` (recorded
  on PR #81), and `realistic-fusion-refreshed`'s tracker page (read 2026-10-08) records heredoc
  bodies failing with the same message.
- **A figure in a ticket carries the command that gave it**: a number, a count, a size, a commit,
  or the date of a measurement is followed by the command that printed it, or by where it was
  read and when. A figure with no command, such as one a harness reported in a session, says so,
  with the date. The session that implements the ticket runs the command before it copies the
  figure anywhere; if the two disagree, the page gets what the command printed and the pull
  request says the ticket was wrong. On 2026-10-09 #87's ticket gave PR #85's first review the
  merged pull request's line counts, 79 added and 27 deleted, where
  `git diff --shortstat 49b0332~1 ac1108d` gives 73 and 24, and the figure reached a page before
  a review caught it.
- **What a ticket states**: a statement about the repository or about a past pull request is read
  from the source when the ticket is written. One that was not read is marked as an account, as
  #89 does with "by its #195's account and not re-read here". A statement about what a command
  prints, lists or exits with is run when the ticket is written, and the ticket shows the command
  and what it printed: the source says which command runs, not what it prints. Where it cannot be
  run, the statement is marked as not run and the run is an acceptance criterion. On 2026-10-11
  #106 said, "read from source, not run for this ticket", that with a two-dot range the files
  `main` changed since are listed too. The first run, on PR #107, showed that false for a file
  the base added.
- **A command that printed nothing** has shown what it prints for that input only. Before a
  ticket, a page or a pull request body records what the command does, it is run again on an
  input that should print something, and the record shows both runs. #148 ran
  `gh issue view <number> --comments` on #145, which has no comments, and recorded "printed
  nothing"; what the command does is under *Read an issue*.
- **Read an issue**:
  `gh issue view <number> --json title,body,labels,comments --jq '{title, body, labels: [.labels[].name], comments: [.comments[].body]}'`.
  Not `gh issue view <number> --comments`: on 2026-10-14, with gh 2.102.0 and outside a
  terminal, it printed a ticket's comments and never its body, so nothing at all for #145, which
  has none, and exited 0 (#148). All five review lanes of that day's session met the same, by
  their own accounts, and fell back to `--json`.
- **List issues**:
  `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`
  with appropriate `--label` and `--state` filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

Infer the repo from `git remote -v`; `gh` does this automatically when run inside a clone.

## Branches, pull requests and follow-up tickets

- **Work starts on a ticket labelled `ready-for-agent`.** On one without it, the session names
  what in the ticket is still open and waits for Truls, before it creates a branch: triage is
  Truls's. On 2026-10-14 `/implement #135` was run on a ticket with no state label, and a branch was
  made before Truls stopped it (by #137's account).
- **A session does what each acceptance criterion asks, or asks Truls first.** Where it means to
  do otherwise, it stops before building the other form. Where the asked form can be run, it
  runs it and asks Truls with the criterion, the command and what it printed; a reason with no
  run is not grounds to ask. Where it cannot, as for "the page cites PR #151", it asks with the
  criterion and what it read, naming each place. Truls's answer is a comment on the ticket, and
  the pull request cites it where it does other than the criterion says. PR #151's brief first
  had the bug scan revert in the working tree where #150 asked for a copy, on the reason that a
  reverted copy of a library is never loaded. In a copy with `game-mods.ps1` changed,
  `resolve-modpack.ps1 -SelfTest` failed 4 of 19 cases (the review comment on PR #151, finding 2,
  2026-10-14): the copy's library was loaded.
- **Work happens on a branch named `<issue>-<slug>`, never on `main`.** Pull requests are
  rebase-merged, which rewrites every SHA on the branch: cite the pull request, not a branch commit.
  A SHA may be cited once it is on `main`. `scripts/pr-body-check.ps1` holds a body to this: CI
  runs it, and so does the session, on the body file, before `gh pr create`.
- **The title and the body are checked before the create, in one command joined with `&&`**, so
  that a failure of either stops it:

      pwsh -File scripts/commit-check.ps1 -ScopeFile commit-scopes.txt -Title "<title>" && pwsh -File scripts/pr-body-check.ps1 <body file> -CiteSiblings && gh pr create --title "<title>" --body-file <body file>

  PR #104 was opened with a 76-character title, by the session's account of 2026-10-11: the
  check ran in a command joined with `;`, which does not stop on a failure.
- **A pull request carries one `Closes #N` line per ticket it closes**, and no other closing
  keyword before an issue reference: GitHub closes on "closed: #103" in a sentence too, as on
  PR #105 (2026-10-11), and `scripts/pr-body-check.ps1` fails such a line. Its title is checked;
  see *Pull request titles* in [`docs/commit-convention.md`](../commit-convention.md).
- **Pull request body**: the `mattpocock-skills:pr` template's `## Summary`, `## Evidence` and
  `## Merge Danger`, once each and in that order (Truls, 2026-10-19,
  grado-factorio-modpack#320; for this repository, 2026-10-20, #171), filled with that skill
  where it is installed and by hand where not. `scripts/pr-body-check.ps1` holds a body to the
  three. This repository adds to the template: above it, the `Closes` lines of the rule above,
  where the branch closes any ticket; below it, nothing.
  The body does not recount the review: each review posts its findings as one comment on the
  pull request, by the rule in [`code-review.md`](code-review.md).
- **The bar for a follow-up ticket** (Truls, 2026-10-06): a leftover from a review, a session or
  a retro becomes a ticket only if a real mod hit it or a consumer's gate needs it. Anything else
  is named in the session report and not filed. A ticket Truls asks for directly is not held to
  the bar.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature
requests; `/triage` reads this flag.)_

When set to `yes`, PRs run through the same labels and states as issues, using the `gh pr`
equivalents:

- **Read a PR**:
  `gh pr view <number> --json title,body,comments --jq '{title, body, comments: [.comments[].body]}'`,
  not `--comments`, which leaves the body out as on an issue, and `gh pr diff <number>` for the
  diff.
- **List external PRs for triage**:
  `gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments` then
  keep only `authorAssociation` of `CONTRIBUTOR`, `FIRST_TIME_CONTRIBUTOR`, or `NONE` (drop
  `OWNER`/`MEMBER`/`COLLABORATOR`).
- **Comment / label / close**: `gh pr comment`, `gh pr edit --add-label`/`--remove-label`,
  `gh pr close`.

GitHub shares one number space across issues and PRs, so a bare `#42` may be either: resolve with
`gh pr view 42` and fall back to `gh issue view 42`.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Read it as *Read an issue* says, above.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body.
  `gh issue create --label wayfinder:map`.
- **Child ticket**: an issue linked to the map as a GitHub sub-issue (`gh api` on the sub-issues
  endpoint). Where sub-issues aren't enabled, add the child to a task list in the map body and put
  `Part of #<map>` at the top of the child body. Labels: `wayfinder:<type>`
  (`research`/`prototype`/`grilling`/`task`). Once claimed, the ticket is assigned to the driving
  dev.
- **Blocking**: GitHub's **native issue dependencies**, the canonical, UI-visible representation.
  Add an edge with
  `gh api --method POST repos/trulsjo/grado-factorio-tools/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`,
  or the same with `grado-factorio-modpack` for a child there. `<blocker-db-id>` is the
  blocker's numeric **database id**, _not_ its `#number` or `node_id`, read from the blocker's
  own repository, which may be the other one: `gh api repos/trulsjo/<repo>/issues/<n> --jq .id`.
  GitHub reports `issue_dependencies_summary.blocked_by` (open blockers only, the live gate).
  Where dependencies aren't available, fall back to a `Blocked by: #<n>, #<n>` line at the top
  of the child body. A ticket is unblocked when every blocker is closed.

  **Run the POST with the Bash tool: a `Bash(...)` rule in the tracked `.claude/settings.json`
  allows it there, in this spelling, for a ticket of this repository or of
  `grado-factorio-modpack`, and the file has no `PowerShell(...)` rule** (#135, after
  trulsjo/grado-factorio-modpack#267). `-X POST` for `--method POST`, and the DELETE that
  removes an edge, are not covered. Not measured: that the client honours the rule.
  trulsjo/grado-factorio-modpack#233's run on a branch with the rule was not made, by Truls's
  decision (#135's first comment), and trulsjo/grado-factorio-modpack#267 left the rule
  unmeasured because the refusal of the write on 2026-10-12 was one event, so a run on a commit
  without the rule might be allowed as well, and a run with the rule would then show nothing
  (both read 2026-10-14). One tool keeps one unmeasured rule set, and a `PowerShell(...)` pair
  would need an edit to the settings file, which the auto-mode check refused in a
  `grado-factorio-modpack` session on 2026-10-13 until Truls allowed it in that session: ruled on
  trulsjo/grado-factorio-modpack#269, which gives the date, and the refusal is recorded in
  trulsjo/grado-factorio-modpack#266's body, *Seen and said* (both read 2026-10-14). If the POST
  in this spelling, run with the Bash tool as a command of its own, is refused, the rule is not
  honoured: file a ticket with the transcript's lines and the client's version.
- **Frontier query**: list the map's open children (`gh issue list --state open`, scoped to the
  map's sub-issues / task list), drop any with an open blocker
  (`issue_dependencies_summary.blocked_by > 0`, or an open issue in the `Blocked by` line) or an
  assignee; first in map order wins.
- **Claim**: `gh issue edit <n> --add-assignee @me`, the session's first write.
- **Resolve**: `gh issue comment <n> --body "<answer>"`, then `gh issue close <n>`, then append a
  context pointer (gist + link) to the map's Decisions-so-far.
