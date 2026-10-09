# Issue tracker: GitHub

Issues and specs for this repo live as GitHub issues. Use the `gh` CLI for all operations.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Write a multi-line body to a file and pass `--body-file <path>`; the same goes for `gh issue comment` and `gh pr create`. Write the file with the Write tool: a heredoc that writes the file is no safer. On 2026-10-08 one command of three such heredocs, 118 lines meant to write the bodies of what became #74, #75 and #76, failed here under the Bash tool with `unexpected EOF while looking for matching '` (recorded on PR #81), and `realistic-fusion-refreshed`'s tracker page (read 2026-10-08) records heredoc bodies failing with the same message.
- **A figure in a ticket carries the command that gave it**: a number, a count, a size, a commit,
  or the date of a measurement is followed by the command that printed it, or by where it was
  read and when. A figure with no command, such as one a harness reported in a session, says so,
  with the date. The session that implements the ticket runs the command before it copies the
  figure anywhere; if the two disagree, the page gets what the command printed and the pull
  request says the ticket was wrong. On 2026-10-09 #87's ticket gave PR #85's first review the
  merged pull request's line counts, 79 added and 27 deleted, where
  `git diff --shortstat 49b0332~1 ac1108d` gives 73 and 24, and the figure reached a page before
  a review caught it.
- **Read an issue**: `gh issue view <number> --comments`, filtering comments by `jq` and also fetching labels.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with appropriate `--label` and `--state` filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

Infer the repo from `git remote -v`; `gh` does this automatically when run inside a clone.

## Branches, pull requests and follow-up tickets

- **Work happens on a branch named `<issue>-<slug>`, never on `main`.** Pull requests are
  rebase-merged, which rewrites every SHA on the branch: cite the pull request, not a branch commit.
  A SHA may be cited once it is on `main`.
- **A pull request carries one `Closes #N` line per ticket it closes.** Its title is checked; see
  *Pull request titles* in [`docs/commit-convention.md`](../commit-convention.md).
- **Pull request body**: written with the `mattpocock-skills:pr` skill, where that plugin is
  installed. This repository adds to what it produces: above its template, the `Closes` lines of
  the rule above, where the branch closes any ticket; below it, nothing.
  The body does not recount the review: each review posts its findings as one comment on the
  pull request, by the rule in [`code-review.md`](code-review.md).
- **The bar for a follow-up ticket** (Truls, 2026-10-06): a leftover from a review, a session or
  a retro becomes a ticket only if a real mod hit it or a consumer's gate needs it. Anything else
  is named in the session report and not filed. A ticket Truls asks for directly is not held to
  the bar.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; `/triage` reads this flag.)_

When set to `yes`, PRs run through the same labels and states as issues, using the `gh pr` equivalents:

- **Read a PR**: `gh pr view <number> --comments` and `gh pr diff <number>` for the diff.
- **List external PRs for triage**: `gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments` then keep only `authorAssociation` of `CONTRIBUTOR`, `FIRST_TIME_CONTRIBUTOR`, or `NONE` (drop `OWNER`/`MEMBER`/`COLLABORATOR`).
- **Comment / label / close**: `gh pr comment`, `gh pr edit --add-label`/`--remove-label`, `gh pr close`.

GitHub shares one number space across issues and PRs, so a bare `#42` may be either: resolve with `gh pr view 42` and fall back to `gh issue view 42`.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body. `gh issue create --label wayfinder:map`.
- **Child ticket**: an issue linked to the map as a GitHub sub-issue (`gh api` on the sub-issues endpoint). Where sub-issues aren't enabled, add the child to a task list in the map body and put `Part of #<map>` at the top of the child body. Labels: `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`). Once claimed, the ticket is assigned to the driving dev.
- **Blocking**: GitHub's **native issue dependencies**, the canonical, UI-visible representation. Add an edge with `gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`, where `<blocker-db-id>` is the blocker's numeric **database id** (`gh api repos/<owner>/<repo>/issues/<n> --jq .id`, _not_ the `#number` or `node_id`). GitHub reports `issue_dependencies_summary.blocked_by` (open blockers only, the live gate). Where dependencies aren't available, fall back to a `Blocked by: #<n>, #<n>` line at the top of the child body. A ticket is unblocked when every blocker is closed.
- **Frontier query**: list the map's open children (`gh issue list --state open`, scoped to the map's sub-issues / task list), drop any with an open blocker (`issue_dependencies_summary.blocked_by > 0`, or an open issue in the `Blocked by` line) or an assignee; first in map order wins.
- **Claim**: `gh issue edit <n> --add-assignee @me`, the session's first write.
- **Resolve**: `gh issue comment <n> --body "<answer>"`, then `gh issue close <n>`, then append a context pointer (gist + link) to the map's Decisions-so-far.
