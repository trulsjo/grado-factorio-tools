# The brief for a review's agents

The words a review's session hands each lane, written once so that every lane is briefed alike
(#140). How a review is run is in [code-review.md](code-review.md) and the shared page it
links, and the prose rules in
[code-review-prose.md](code-review-prose.md). This page carries three of `code-review.md`'s rules
to the lane, what the bug scan does not load, when the check is not run again, and the
read-nothing rule, and adds three rules of its own. One is an exception to `code-review.md`'s
rule that a revert that fails nothing is a finding: a default revert the pull request lists with
why it passes (#390). The second, with nothing of it in `code-review.md`, is that a case reading
a thrown message through a child's merged output is a finding (#435). The third, there until
the stub of #355, is that a lane waits on a CI run not yet finished and names one that passed.
Any other rule is changed there, or on the shared page where it is a shared step. How a lane
runs a command a rule names, and what of its output it reports, is the brief's
(Truls, 2026-10-26, #232), and so is how the bug scan applies the read-nothing rule, step by step
(#383). The session fills the blanks, written `<like this>`, with what is particular to the
change, and sends the rest as it stands. A lane that runs both reviews is sent both *Reads first*
lines.

This page is the brief template
[`docs/code-review-procedure.md`](../code-review-procedure.md) asks this repository to name, and
it holds that page's steps for a lane (#355): what is not under review, with nothing of what the
session thinks is right; the agent-facing files read whole; the report as a file, with what was
not checked; and, below the brief, the turn that confirms a fix.

---

You are the `<bug scan | prose lane | both>` of the review of pull request `#<number>`,
`<title>`, at `<full SHA>`, in `C:\src\factorio\grado-factorio-tools`. The change:
`<what it does, and the tickets it closes>`. Not under review:
`<each decision of Truls's that the change records, with where he made it | "nothing">`.

**Reads first.** `CLAUDE.md`, `docs/code-review-rules.md`, `docs/agents/code-review.md`, and the
tickets the change closes, each with
`gh issue view <number> --json title,body,labels,comments --jq '{title, body, labels: [.labels[].name], comments: [.comments[].body]}'`.

- The bug scan: the diff, `git diff origin/main...<full SHA>`, and each file it touches, whole.
  It does not load `docs/agents/code-review-prose.md`.
- The prose lane: `docs/agents/code-review-prose.md`, then the diff, the commit messages
  (`git log origin/main..<full SHA>`) and the pull request body (`gh pr view <number>`). It reads
  whole each agent-facing file the diff changes, a `CLAUDE.md`, a page under `docs/agents/`, a
  page under `docs/` that a stub page links, or a skill file: a sentence the change made false
  and did not touch is in no hunk.

**The check.** `<CI's run <id> passed on this commit: name it and do not run the check again |
CI's run <id> has not finished on this commit: in the Bash tool, run gh run watch <id>
--exit-status > <your scratch folder>/watch.txt 2>&1 and keep the watch's exit code, then report
that code and the run's closing line, grep -E '<id>$|\(<id>\) has already completed' <your scratch
folder>/watch.txt | tail -1, not the whole file; if the watch exited 0, name the run and do not
run the check, and if not, run pwsh -File scripts/check.ps1 and report what it printed | CI
has not passed on this commit: run pwsh -File scripts/check.ps1 and report what it printed>`.

**The self-tests CI does not run.** `<each, as pwsh -File scripts/<script> -SelfTest, or "none">`.
Run each and report its last line.

**The reverts.** `<each claim the change makes of a script, with the self-test that covers it |
"none: the change touches no script">`. A claim of a library with no self-test of its own names
its caller's. The bug scan reverts each claim, and each condition on a line the diff adds or
changes that the claims leave out: a script the change adds, on every line. It makes one copy
of the commit for each `revert-run.ps1` run it has going at once, up to four, outside the
repository, a clone, since a self-test may ask git for `origin/main` as GitHub has it, and
`revert-run.ps1` refuses a copy another run has left changed:
`git clone -q https://github.com/trulsjo/grado-factorio-tools <empty scratch folder>`, then
`git -C <copy> checkout -q <full SHA>`. It writes the reverts as a list and runs them with
`pwsh -File scripts/revert-run.ps1 -Copy <copy> -List <list>` (#284); the list's shape and what
each result means are in that script's header. For each script whose `param()` block the change
adds, or whose defaults it edits, it also runs
`pwsh -File scripts/revert-run.ps1 -Copy <copy> -Defaults <scripts>`, which writes those
scripts' default reverts itself (#382, #390); what a default revert is, and which defaults it
writes none for, are in that script's header too. For each script the change touches whose
`-SelfTest` runs with no Args and without the game, one script to a run, it runs
`pwsh -File scripts/revert-run.ps1 -Copy <copy> -Conditions <script> -Base <base>`, with `<base>`
the pull request's base, `git -C <copy> merge-base origin/main <full SHA>` (#402). That run
writes a revert per operand of each `-and` or `-or` chain and per element of each `-in`, `-notin`
or type list on a line the diff adds or changes, each run against the script's own self-test.
**Every other changed condition goes in the lane's list**, beside the claims: a lone test in an
`if`, `elseif` or `while`, as `Get-DefaultRevert`'s `if ($ast.ParamBlock)`; a `-not`, a
comparison, an `-is` or `-isnot`; the shapes the header's *WHAT IT CANNOT SEE* lists under "Of
-Conditions"; and those the run reports as not written. The list leaves out a self-test's
verdicts, skipped or kept, whose reverts pass by construction (#407, #411). A library with no
`-SelfTest`, as `scripts/game-mods.ps1`, has its changed conditions in the list with its caller's
self-test. A script whose self-test needs Args has them in the list with its `Args`, as
`-NoGame` for `trace-definitions.ps1`; one whose self-test needs the game, as the others in
`check.ps1`'s `$NEEDS_GAME`, is not run, and the lane names its changed conditions as not run. A
script with no condition on a changed line fails the run, exit 1, with `-Conditions names
<script>, for which no condition revert could be written on lines changed since <base>, so no
revert was run.`: the lane reports that line, and it is nothing to revert, not a finding. Where
a ticket the change closes has a criterion over all the guards of a script or a function, not
over guards it names, it runs `-Conditions` on that whole script without `-Base`, adds the list
for that script or function as above, and reads the rows within that script or function: a row
outside it is no finding of that run. Each run gives each self-test 600 s unless
`-TimeoutSeconds <s>` is added to the command, and reports one still running then as *timed out*,
which a loop under the revert and a self-test merely slower than the limit both give: a lead to
check, as a crash is, not a verdict (#424). It runs at most four `revert-run.ps1` runs at once,
each on a clone of its own, as `check.ps1` runs at most four self-tests at once, and runs a
*timed out* revert again alone before it reports it: PR #428's bug scan ran eight at once, and
three walk-guard reverts timed out at 120 s (#435); run alone, one of them failed in 106 s (the
review comment on PR #428, finding A). Each revert runs the script's whole self-test: on `main`
at `4534a44`, `-Conditions` writes 133 reverts for `revert-run.ps1`, whose self-test took about
100 s on PR #412's branch, close to 3.7 hours (#402's brief). It reports each run's table. A
revert that fails nothing is a finding, unless it is a default revert the pull request lists
with why it passes, as PR #389 listed `line-cite-check.ps1 -Foreign`. With "none", it reverts
nothing. The session answering a review's findings runs its reverts the same way.

**What reads nothing.** The bug scan applies `code-review.md`'s
[read-nothing rule](code-review.md#how-a-review-is-run) step by step, not to the whole set at
once. It names each step between what a check is given and what it reads: a pathspec, the files
on disk, the exempt ones, an extension, a marker it looks for, a scope parameter. For each, the
run where that step alone leaves nothing must fail, and a self-test case must hold that run; one
that passes, or that no case holds, is a finding. The rule's own exception stands: a run that
only has nothing to check this time, as a commit that stages none of the files, may pass, and
says it read nothing. PR #374's checks passed on nothing five times,
each at one such step, and no one review found them all (#383's table).

**What a thrown message looks like to a case.** The bug scan reads each case the diff adds or
changes that starts a script in a child `pwsh` and reads its merged output (`2>&1`) for text the
script throws, and each case reading a throw the diff adds or changes. The error view wraps a
thrown message at the console's width, so such a case passes or fails by the width and the
length of what the message holds, as a path: each one is a finding. The script writes the
message whole itself, to stderr, and exits, and the case looks for it whole. PR #428's
`dev-launch.ps1` case passed locally and failed CI's run 43290205684 on both runners (#435). An
older case of that shape, in a file the diff touches elsewhere, is no finding of the review.

**Read-only.** Edit no file in the repository, commit nothing, push nothing, and post nothing to
GitHub: the session acts on the findings and posts the review.

**The report is a file.** Write it to `<a scratch folder outside the repository>/<lane>.md` with
the file tool, and end your turn on at most three lines: how many findings, which one matters
most, and the file's path. It has three sections.

**Findings.** Each is numbered, and reported as:

- **Place:** file and line, or the commit by subject, or the pull request body.
- **Text:** the words or code in question, quoted.
- **Failure:** what goes wrong, for whom, with the run or read that shows it.
- **Right:** what would be right.
- **Score:** a suggested score, 0 to 100, on the plugin's rubric.

Nothing found is said plainly there, as "Nothing found".

**Checked and found right.** A line for each thing read or run that held, with how it was
checked, and each file read whole.

**Not checked.** A line for each thing this brief or a rule asks for that the lane did not
check, with why: the session answers each one.

`<anything particular to this change: a claim to check, a sibling to open, a case to run>`

---

**The confirmation turn** is sent to the lane that raised a finding, continued, once its fix is
committed. It holds the lines below and no account of what was done; the session fills their
blanks. Where the lane cannot be continued, a fresh agent is sent the brief's *Reads first* and
*Read-only* paragraphs as they were filled, and the lines below: it runs no check and no revert,
and does not review the change again. The review's comment is posted after this turn, and a
`not fixed` gets another fix and another turn, or is recorded as left.

Confirm the fixes of the review whose report is `<the report file's full path>`, which read the
change at `<the reviewed full SHA>`. The fixes are in `<each fix commit, by full SHA>`: read
`git diff <the reviewed full SHA>..<the last fix's full SHA>`. Not fixed, and why:
`<each finding, by its number | "none">`. Read the diff as new diff: against the report's
findings, and by each rule a review here reads by. Still read-only. Add a section
**Confirmation** to the report file, a line for each finding by its number, `fixed`,
`not fixed: <what is left>` or `left unfixed, as said`, with a new finding numbered on under
**Findings**. End your turn on at most three lines: how many are fixed, what is left, and the
file's path.
