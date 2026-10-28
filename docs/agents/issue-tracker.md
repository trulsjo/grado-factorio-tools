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
- **An acceptance criterion on what a script does names the self-test case that fails when that
  behaviour is reverted**, or says the behaviour is held by a manual run only. The second is a
  decision recorded in the ticket, not a gap a review finds. The rule is for criteria on a
  script's behaviour, not on prose, a label or a page; how a revert is made and shown is
  [`review-brief.md`](review-brief.md)'s *The reverts*. #221's brief held one half of its ruling
  to the self-test and the other, a type with no `stack_size` still refused, to a manual stub run.
  On PR #223, on 2026-10-25, the bug scan reverted the `Test-Stackable` condition and `-SelfTest`
  still passed (its review comment, bug finding 1, score 75), and a third half was added in a fix
  round.
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
  that a failure of either stops it. The body file is drafted first, by the pr skill, as
  *Pull request body* below says:

      pwsh -File scripts/commit-check.ps1 -ScopeFile commit-scopes.txt -Title "<title>" && pwsh -File scripts/pr-body-check.ps1 <body file> -CiteSiblings -RequireSummaryVisual && gh pr create --title "<title>" --body-file <body file>

  PR #104 was opened with a 76-character title, by the session's account of 2026-10-11: the
  check ran in a command joined with `;`, which does not stop on a failure.
  `scripts/refuse-pr-body.ps1`, a session hook, refuses a `gh pr create` or `gh pr edit` whose
  body the check fails, or whose body is not a file named in full (#259): PR #252 was opened
  with a failing body, its check piped to `tail`, whose 0 let `&&` go on. The chain is still
  written out, because the hook checks the body only, not the title, and a person's terminal and
  a sibling without the hook have no hook.
  Under `-CiteSiblings`, a statement about consumers in general, or about a fixture a self-test
  builds, says *consumer*, [GLOSSARY.md](../../GLOSSARY.md)'s word for a repository that resolves
  a tool from here; one about a sibling names it, with its commit and the date it was read
  (#287). The check reads *sibling* as naming one: PR #283's first body was refused for five generic
  statements so worded, by that session's account (2026-10-28).
- **A pull request carries one `Closes #N` line per ticket it closes**, and no other closing
  keyword before an issue reference: GitHub closes on "closed: #103" in a sentence too, as on
  PR #105 (2026-10-11), and `scripts/pr-body-check.ps1` fails such a line. Its title is checked;
  see *Pull request titles* in [`docs/commit-convention.md`](../commit-convention.md).
- **Pull request body: load the `mattpocock-skills:pr` skill with the Skill tool, then draft the
  body by its template**, before the create command above runs. The skill fills `## Summary`
  with the smallest visual that makes the point, a diagram, a diff sketch, a tree or pseudocode,
  and brief prose beside it; `## Evidence` with a run before and after; and `## Merge Danger`.
  Where the plugin is not installed, the template is filled by hand. The session of PRs #249 to
  #252 and #257 drafted without loading it, and their Summaries held no visual (#263).
  The three headings stand once each and in that order (Truls, 2026-10-19,
  grado-factorio-modpack#320; for this repository, 2026-10-20, #171). `scripts/pr-body-check.ps1`
  holds a body to the three, and to the template's **Before:** and **After:** under
  `## Evidence` and **Door:** and **Blast Radius:** under `## Merge Danger`, and with
  `-RequireSummaryVisual` `## Summary` to a fenced or indented code block (#264); a change with
  nothing to show says none after **Before:** and **After:** (Truls, 2026-10-21, #185), this
  repository's one departure from the template, which asks for a before and after.
  Among what this repository adds to the template: above it, the `Closes` lines of the rule
  above, where the branch closes any ticket; inside it, what `-CiteSiblings` and the
  *Blast Radius* rule below ask of its prose; below it, nothing.
  *Evidence* cites `scripts/check.ps1` by CI's run id once that run has passed on every job on
  the pull request's tip; until then it names the platform of the run it cites, as "passed
  locally, on Windows, in the pre-push hook", and a body edited after CI passes replaces the
  second with the first (#286). PR #283's first body cited the pre-push run as passing, and CI's
  run 40596186420 on that commit failed on ubuntu-latest.
  The body does not recount the review: each review posts its findings as one comment on the
  pull request, by the rule in [`code-review.md`](code-review.md).
- **The Blast Radius of a change to a script names each place a sibling uses it**, found by two
  greps of the whole sibling at a cited commit, documents included, not its gates alone. The
  first, `git -C <sibling> grep -n vendor/grado-factorio-tools/scripts/<script> <commit>`, lists
  each line that spells the script's path. The second lists each line where the tools path ends,
  as a path held to name a script apart from it does:

  ```sh
  git -C <sibling> grep -n -E "vendor/grado-factorio-tools/scripts/?['\"]?\)?[[:space:]]*$" <commit>
  ```

  Each of its hits is read, and each script the sibling runs through the path it holds is named:
  grado-factorio-modpack's `scripts/stage-pack.ps1` at `2cd7936` (read 2026-10-26) sets
  `$TOOLS = Join-Path $ROOT 'vendor/grado-factorio-tools/scripts'` on line 151 and runs
  `pack-mods.ps1`, `game-mods.ps1`, `load-harness-lib.ps1`, `resolve-modpack.ps1` and
  `fetch-mods.ps1` through it, where the first grep for `pack-mods.ps1` prints nothing (PR #250's
  review, finding 1). That line is the second grep's one hit in that sibling, and
  realistic-fusion-refreshed at `07bb886` has none, where *Pin tickets*' grep for
  `vendor/grado-factorio-tools/scripts` lists 73 lines in the modpack and 48 in
  realistic-fusion-refreshed (2026-10-26). It cannot see a path built in more than one step, as
  `Join-Path $ROOT 'vendor/grado-factorio-tools'` and then `'scripts'`, which neither sibling has
  at those commits: the one line in each that ends at `vendor/grado-factorio-tools` is its
  `.gitmodules` path. The body cites the commit and the date, as
  `pr-body-check.ps1 -CiteSiblings` asks. PR #223's first body grepped
  realistic-fusion-refreshed's gates only, and missed its `docs/agents/shipping.md`, which at
  `ff59e79` (read 2026-10-25) runs `locale-check.ps1 -Prefix rf-` by hand before shipping; the
  review's prose lane found it (finding 2, score 40).
- **A revert a pull request cites as evidence shows that its copy differs**, with
  `git -C <copy> diff --stat`, as [`review-brief.md`](review-brief.md) asks of a review lane
  under *The reverts* (Truls, 2026-10-21, #183). Until PR #276, both pages compared the copy's
  file with the working tree's, `git diff --no-index --stat <file> <copy>/<file>`, which on a
  working tree on another branch showed that branch's lines and hid the revert (PR #276's
  review, bug finding 1, 2026-10-27). On 2026-10-20, fixing PR #178's
  review findings, a `perl` revert of the changed-tree guard matched nothing, and the copy's
  self-test passed 5 of 5 on an unchanged file, which reads as "this fix is not tested". An empty
  diff showed it; with the pattern fixed, the revert failed case 3, by that session's account.
- **The bar for a follow-up ticket** (Truls, 2026-10-06): a leftover from a review, a session or
  a retro becomes a ticket only if a real mod hit it or a consumer's gate needs it. Anything else
  is named in the session report and not filed. A ticket Truls asks for directly is not held to
  the bar.

## Pin tickets

A pin ticket asks a sibling to move its `vendor/grado-factorio-tools` pin, and measures what the
move changes for the sibling's gates. **The measurement is made in a copy of the sibling at
GitHub's `main` that no other session uses, never in the sibling's checkout**: on 2026-10-23 the
modpack's checkout was on another session's branch, whose staging changed a run between two
reads (#195, from grado-factorio-modpack#353). A `git worktree` is not an option: a hook blocks
it.

**`scripts/pin-measure.ps1` makes the measurement**, in one command run from the sibling's
`vendor/grado-factorio-tools/scripts/` with the submodule at the new pin (#247). It clones the
sibling twice at GitHub's `main`, fills each clone's `vendor/` with one pin's copy of `scripts/`,
runs each form the sibling's forms file lists at both pins, and writes each output and exit code,
a table that compares them and the move's breaking commits to the directory it is given. Its
header holds the commands, the forms file's shape and what each output file is. Each sibling
hand-wrote this from the prose that stood here, and got it wrong first: on
grado-factorio-modpack's PR #387 (2026-10-26) the first run had three bugs and was discarded.

**What is run** is the sibling's forms file, which it keeps and extends. A script the range
changes counts with every script here that dot-sources or loads it, as the harness's scripts load
`load-harness-lib.ps1`; `git grep -l <changed file> <new> -- scripts` in this repository names
them. The forms file lists the `-SelfTest` of each script the range changes, and of each script
here that loads one, as a form run from the pin's copy, so each runs at both pins: the
measurement made by hand ran each copy's `-SelfTest`, and PR #251's rewrite dropped that step
without saying so (its review, prose finding 6, 2026-10-26). Three things hold for such a form
(PR #257's review, findings 1 to 3, 2026-10-26):

- **A self-test that reads outside `scripts/`** is given the argument its header names for it,
  or is run in this repository at each pin instead: the pin's copy holds `scripts/` alone, so
  `refuse-git-hook-skip.ps1 -SelfTest` and `refuse-python-heredoc.ps1 -SelfTest`, which default
  `-Settings` to `.claude/settings.json` beside `scripts/`, exit 1 from it at both pins.
- **Its exit codes are what is compared**, not its output: `param-check.ps1 -SelfTest` prints its
  temp directory and `pr-body-check.ps1 -SelfTest` a scratch commit's hash, which differ on every
  run, so the table can read a self-test as differing where nothing changed.
- **A self-test that needs the game**, as one of `check.ps1`'s `$NEEDS_GAME` does, is the
  sibling's to list or leave out; `trace-definitions.ps1 -SelfTest -NoGame` runs the cases of
  that script that need none.

The forms are read from the whole sibling, not from its gate files alone: a
sibling's gate scripts run ours too, as realistic-fusion-refreshed's `scripts/ship-check.ps1` runs
`markdown-check.ps1` and its `scripts/factorio-lib.ps1` dot-sources `load-harness-lib.ps1` (both
at `34f5ebe`, read 2026-10-23; PR #197's review). The script lists, under its table, each place
the sibling names `vendor/grado-factorio-tools/scripts` that no form runs; a hit in a sibling
script counts where a gate runs that script, which its `.github/workflows/`, `.githooks/` or
`.claude/settings.json` says, and is then added as a form. The ticket records the sibling commit,
and each command with what it printed, as *Conventions* asks.

**Each form that differs is named in the sibling's pull request**, with what the difference is:
the script reports and does not judge, and exits 0 whatever it found. Its table goes in
*Evidence*.

**Each breaking commit of the move is named too** (#244, #255). The script writes them to its
`breaking.txt`, by the one rule, in `scripts/breaking-lib.ps1`, whose header states it: the
breaking commits the move brings in, and those a pin moved back drops, marked `dropped`; `none`
where there is none. This page held a shell command of its own for the list until #255, whose
triage grill (Truls, 2026-10-26) reversed #244's asking for it here, so that the rule has one
home. The sibling's pull request names each, a dropped one included, under *Merge Danger*, with
what it changes for the sibling, or that it changes nothing there and why; of a dropped one,
that the move undoes it. The list goes to the sibling's pre-PR reviewer with the rest of the
measurement. On grado-factorio-modpack's PR #387 (2026-10-26),
moving the pin from `8189e45` to `2c13393`, the range's one breaking commit, `67c7e60`, made
`-With space-age` enable `quality` too. No gate runs the harness, so the measurement, the pre-PR
review and the first body all missed it; the plugin pass found it (PR #387's comment
`issuecomment-6413089659`, finding 2, read 2026-10-26).

What the copy cannot see: the sibling's own submodule is not initialised, so `vendor/` holds
only the pin's `scripts/`, and a link to anything else there is reported as not checked; its
index matches `HEAD`, so a no-argument form reads no staged file; and a form over
`origin/main...HEAD` reads nothing at `main`, so a range of the sibling's own history, as
`HEAD~20...HEAD`, stands in for a pull request's and is named as such.

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
