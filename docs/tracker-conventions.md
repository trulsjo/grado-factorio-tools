# Tracker conventions

**This page is where the issue-tracker conventions are declared, for the repositories that link
to it.** Each of them keeps a stub page at `docs/agents/issue-tracker.md`, the path the
`mattpocock-skills` expect: the setup template's core, that repository's own parts, and a link
here.

The rules were taken from the four `docs/agents/issue-tracker.md` pages, read 2026-11-06:
trulsjo/grado-factorio-tools at `e70669f`, trulsjo/grado-factorio-modpack at `987e638`,
trulsjo/realistic-fusion-refreshed at `9fd78b5` and trulsjo/true-nukes-refreshed at `78486d2`,
as ruled in
[*Rulings: tracker and ticket conventions*](https://github.com/trulsjo/grado-factorio-tools/issues/325)
(rulings 2 to 6) and
[*Rulings: confirm the proposed leaves*](https://github.com/trulsjo/grado-factorio-tools/issues/330)
(item 4). An incident is told as the page it came from tells it, and names that repository.

## Read an issue with `--json`, not `--comments`

```sh
gh issue view <number> --json title,body,labels,comments --jq '{title, body, labels: [.labels[].name], comments: [.comments[].body]}'
```

One call gets the body, the labels and every comment. A pull request is read the same way,
`gh pr view <number> --json title,body,comments`, and `gh pr diff <number>` gives its diff.

**Not `gh issue view <number> --comments`**: outside a terminal, as under an agent's shell tool,
it prints the comments and never the body, so nothing at all for an issue with no comments, and
exits 0. Three repositories found this apart: trulsjo/grado-factorio-modpack and
trulsjo/realistic-fusion-refreshed on 2026-10-06, the second with gh 2.102.0, and
trulsjo/grado-factorio-tools on 2026-10-14, with gh 2.102.0, on
[#145](https://github.com/trulsjo/grado-factorio-tools/issues/145), which has no comments
([#148](https://github.com/trulsjo/grado-factorio-tools/issues/148)).

## Multi-line bodies go through `--body-file`

A body of more than one line, for `gh issue create`, `gh issue comment`, `gh pr create` or
`gh pr edit`, is written to a file and passed as `--body-file <path>`. **The file is written with
the Write tool, never with a heredoc**: a heredoc that writes the file is no safer than one that
is the body. The setup template's "use a heredoc for multi-line bodies" is not followed.

- trulsjo/grado-factorio-tools: on 2026-10-08 one command of three heredocs, 118 lines meant to
  write three ticket bodies, failed under the Bash tool with
  `unexpected EOF while looking for matching '` (recorded on PR #81 there).
- trulsjo/realistic-fusion-refreshed: heredoc bodies failed with the same message, every failing
  command over 60 lines; on 2026-10-06 one command of six heredocs ended in
  `here-document at line 214 delimited by end-of-file`, with two body files never written and one
  cut short. Its page keeps the rest of that history.
- trulsjo/grado-factorio-modpack: its `scripts/ask-before-download.ps1` refuses a heredoc when one
  of its lines opens with a command it matches (measured 2026-10-08, recorded on PR #186 there).

## Search the open issues before filing

Right before each `gh issue create`, search the open issues and check that none already covers the
new ticket:
`gh issue list --state open --limit 500 --search "<topic words>" --json number,title,body`. The
`--limit` matters: without it `gh` fetches 30 (`gh issue list --help`, gh 2.103.3), and on
2026-11-07 `gh issue list --state all --json number --jq length` printed 30 on
trulsjo/grado-factorio-tools, where the same with `--limit 500` printed 244. The new ticket names
any open one it touches.

- **Right before, not earlier in the session.** Other sessions file on the same tracker at the
  same time, so a check made earlier is stale (trulsjo/true-nukes-refreshed).
- **Search for the concept, not only the wording**, and say in the pull request or the session's
  report what was searched for. trulsjo/realistic-fusion-refreshed#639 was filed on 2026-10-07
  and closed as a duplicate of trulsjo/realistic-fusion-refreshed#591, open since 2026-10-05:
  both asked for the gate history to move out of a `CLAUDE.md` section, under titles that share
  no noun but `CLAUDE.md`. The session that filed trulsjo/realistic-fusion-refreshed#639 had not
  searched.
- **Search the other trackers the stub names too.** On 2026-10-09 a line-length ticket for
  trulsjo/grado-factorio-modpack's own Markdown check was close to being filed beside
  trulsjo/grado-factorio-tools#93, which had ruled the same day that the limit lives in the shared
  check (by the account of the session that filed trulsjo/grado-factorio-modpack#209).

Which other trackers to search is each repository's, and its stub names them.

## Blocked by

A ticket that waits on another records it in three places, kept in step:

1. **The native edge**, GitHub's issue dependency, which the UI shows and the frontier query
   reads (`issue_dependencies_summary.blocked_by`, open blockers only):

   ```sh
   gh api --method POST repos/<owner>/<repo>/issues/<n>/dependencies/blocked_by -F issue_id=<blocker-db-id>
   ```

   `<blocker-db-id>` is the blocker's numeric database id, not its `#number` or `node_id`, read
   from the blocker's own repository, which may be another:
   `gh api repos/<owner>/<repo>/issues/<blocker> --jq .id`.
2. **A `## Blocked by` section in the ticket's body**, one bullet per blocker (`- #<n>`, then
   why, if it helps). It serves a reader outside the UI, and stands in for the edges where
   dependencies are not available.
3. **No `ready-for-agent`** while any blocker is open: the label says a ticket can be picked up,
   and a blocked one cannot. A ticket filed with an open blocker is filed without it; one made to
   wait later loses it in the same step as the edge and the section are written. On 2026-10-12
   trulsjo/grado-factorio-modpack#225 was handed to a session as `ready-for-agent`, with "None"
   under its "Blocked by", while a decision of the day before that it waits stood in its
   comments (by that repository's page).

**Each write is read back**:
`gh api repos/<owner>/<repo>/issues/<n>/dependencies/blocked_by --jq '[.[].number]'`, and the
section is made to match what it prints. An edge added or removed changes the section in the
same pass. Blockers are filed first, so their numbers exist when the blocked ticket is written,
and a new issue is named by the number in the URL `gh issue create` prints.

What a session may run unasked for the POST, and in which tool, is each repository's
`.claude/settings.json`, and its stub says so.

## Before closing

**List what hangs off the issue**, right before closing it:
`gh api repos/<owner>/<repo>/issues/<n>/dependencies/blocking --jq '[.[].number]'` for the
issues it blocks, and `gh issue list --state open --search "<n>"` for open issues that name it,
such as a child's `## Parent`. Re-parent or close each in the same pass: an open child of a
closed issue reports to nothing (trulsjo/true-nukes-refreshed).

**Close a duplicate with `gh issue close <n> --duplicate-of <m>`** (gh 2.103.1, read from
`gh issue close --help` on 2026-10-26, not run, as trulsjo/grado-factorio-modpack's page
records). Comment
on `<m>` first, listing what `<n>` has that `<m>`'s body lacks: criteria, and any ruling it
leaves open. While that ruling is open, `ready-for-agent` comes off `<m>`. On 2026-10-25
trulsjo/grado-factorio-tools#210 was closed as a duplicate of trulsjo/grado-factorio-tools#208
with a ruling open, first by `gh issue close --reason "not planned"` and then set to duplicate
through `gh api`.

## The bar for a follow-up ticket

Ruled by Truls on 2026-10-06 for trulsjo/grado-factorio-tools, and spread on 2026-11-06 to every
repository that links this page
([#330](https://github.com/trulsjo/grado-factorio-tools/issues/330), item 4): **a leftover from a
review, a session or a retro becomes a ticket only if a real mod hit it or a consumer's gate
needs it.** Anything else is named in the session report and not filed. A ticket Truls asks for
directly is not held to the bar.
