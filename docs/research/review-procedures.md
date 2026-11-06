# Survey: code review procedures across the mod repositories

Research for [#331](https://github.com/trulsjo/grado-factorio-tools/issues/331), part of the map
[#309](https://github.com/trulsjo/grado-factorio-tools/issues/309). It compares how the four
repositories run a code review, step by step, and proposes which steps one shared procedure could
hold. Truls amended *Rulings: code review rules*
([#327](https://github.com/trulsjo/grado-factorio-tools/issues/327)) on 2026-11-06 so that the four
review in similar ways. Every ruling below is a proposal with its reason. Truls rules, in
[#332](https://github.com/trulsjo/grado-factorio-tools/issues/332).

**Out of scope, already ruled:** the threshold rule ("the threshold sorts the comment, not the
report", with "do not re-score") and the shared prose checks go to `docs/code-review-rules.md`
(#327, rulings 1 and 2). This page is about the procedure only: when a review runs, who reviews,
what each reviewer is briefed with and given, how findings are reported and answered, and what
gates a merge.

## What was read

Tracked files only, on 2026-11-06, each at the tip of `origin/main`:

| Repository | Short name | Commit | Tools pin | Procedure pages and skills read |
|---|---|---|---|---|
| grado-factorio-tools | tools | `e70669f` | — | `docs/agents/code-review.md`, `review-brief.md`, `code-review-prose.md`; headings of `code-review-evidence.md` |
| grado-factorio-modpack | modpack | `987e638` | `36b34f7` | `docs/agents/code-review.md`, `pre-pr-review-brief.md`; headings of `code-review-why.md` |
| realistic-fusion-refreshed | rf | `9fd78b5` | `36b34f7` | `docs/agents/code-review.md`, `plugin-pass.md` (its *What the session does*), `.claude/skills/pre-pr-review/SKILL.md`, `.claude/skills/plugin-pass/SKILL.md` |
| true-nukes-refreshed | tn | `78486d2` | `36b34f7` | none tracked; the user-level `review-panel` skill (below) |

Also read: the code review triggers in each `CLAUDE.md` (*Agent skills* in tools and modpack,
*Code review* in rf; tn's *Agent skills* has no code review entry), each repository's
`.github/workflows/`, and each tracker page's pull request section where it says what a body
carries.

**tn's practice is user-level, and is described here, not ruled** (the map's Notes). It is the
skill at `~/.claude-personal/skills/review-panel/` (`SKILL.md`, `brief-template.md`,
`scripts/panel.py`, `scripts/switch_ids.py`), read on 2026-11-06. It drives three reviewer agents
in Herdr spaces, `tn-codex`, `tn-antigravity` and `tn-fable`. Where a cell below says
"tn (user-level)", the source is that skill; where it says "tn (observed)", the source is tn's
pull requests.

**What the repositories do, as against what their pages say,** was sampled from GitHub on
2026-11-06 (`gh pr list --state merged --json number,comments,mergedBy`):

- Every merged pull request in the samples below was merged by `trulsjo`, and `main` has no branch
  protection and no ruleset in any of the four
  (`gh api repos/trulsjo/<repo>/branches/main/protection` answers 404 "Branch not protected";
  `.../rulesets` answers `[]`). So in all four the merge gate is Truls, plus whatever the pages
  ask of the session before it.
- tools: 20 of the last 20 merged pull requests carry a comment matching "review".
- modpack: 16 of the last 20 carry a comment matching `plugin pass` or `## Code review`, though
  its page says the plugin pass runs only when Truls asks. Whether each was asked for was not
  checked.
- rf: each of the last 5 carries the two plugin-pass comments, `### Code review` and
  `### What the plugin pass raised and did not post`.
- tn: 14 of the last 21 carry a `Combined review` comment; the 7 without are
  true-nukes-refreshed#64, true-nukes-refreshed#53, true-nukes-refreshed#49,
  true-nukes-refreshed#48, true-nukes-refreshed#47, true-nukes-refreshed#28 and
  true-nukes-refreshed#15.

The procedure pages are not copies of one another, so drift is measured once, where two share an
origin. modpack's *One review before the pull request* (decided there 2026-10-06,
grado-factorio-modpack#151, a day after rf's
[realistic-fusion-refreshed#592](https://github.com/trulsjo/realistic-fusion-refreshed/issues/592))
and rf's *A review before the pull request, and the plugin pass after it* are 123 and 245 lines;
`git diff --no-index --numstat` on the two sections gives +239 −117, so 6 of modpack's 123 lines
survive unchanged in rf's. Both still hold, in different wording, the same core: one fresh
subagent, handed the diff, the rules page and the evidence; the same reviewer confirms each fix;
findings go in the pull request's body; a plugin-pass finding the pre-PR review missed gets its
class named, with "One-off, no rule" an answer.

## The steps, compared

"Same" means the four do it alike, "near" alike in substance with different detail, "different"
otherwise. The reason a step differs is given as **fitted** (it serves a gate or a fact of that
repository) or **drift** (the repositories grew apart with no reason that one of them states).

| Step | tools | modpack | rf | tn | Same, near, or different, and why it differs | Proposed |
|---|---|---|---|---|---|---|
| **1. When the review runs** | On the pull request, once per change. Skip the review step inside `/implement` or any skill: open the PR first (`code-review.md`, *How a review is run*). | Before the PR exists, and before the branch is first pushed (`code-review.md`, *One review before the pull request*). | Before the PR exists (the pre-PR review), and the plugin pass after it is opened (`code-review.md`, fourth rule). | On the PR (tn (user-level): `review-panel`, *Review a PR*). | Different. tools' on-PR timing is fitted: its bug scan stands on CI's `check.yml` run on the commit, which needs a push. modpack's pre-push timing is fitted: a commit message can still be reworded. rf and modpack share an origin (realistic-fusion-refreshed#592), and rf added a second pass. tn's is the panel's, which reads `gh pr view` and `gh pr diff`. | **Shared with a parameter**: "a review before the merge, of every commit"; the parameter is whether it runs before the PR, on it, or both. |
| **2. Which changes get one** | Every change, once; asked again, only the commits since. | "Every branch with a diff… No branch is exempt for being small." | Every branch; one review per part reviewed apart (realistic-fusion-refreshed#781); every PR gets the plugin pass, documentation-only included (realistic-fusion-refreshed#593). | No tracked rule. tn (observed): 14 of the last 21 merged PRs carry a combined review. | Near in tools, modpack and rf; tn has no rule. | **Shared**: every change with a diff gets a review, none exempt for size. |
| **3. What starts it** | `CLAUDE.md` *Agent skills*: "load `docs/agents/code-review.md` before running a review". | `CLAUDE.md` *Code review*; "`/code-review` in an implement skill means the pre-PR review". | `CLAUDE.md` *Code review* lists conditions and sections; `/pre-pr-review` and `/plugin-pass` (tracked skills). | The user asks; the session loads `review-panel`. tn's `CLAUDE.md` names no review. | Near: each `CLAUDE.md` points at a page, except tn's. Fitted to each page's name. | **Shared with a parameter**: the `CLAUDE.md` trigger line, with the page path as parameter. (tn's page is ruled by #327 ruling 4.) |
| **4. How many passes** | One review, one or two agents. | One pre-PR review; the plugin pass "when Truls asks for it, and not otherwise". | Two: pre-PR review, then the plugin pass on every PR. | One panel round per head; tn (observed) PR true-nukes-refreshed#66 had three rounds, each on the head at the time. | Different. rf's second pass is fitted to its measurement (`plugin-pass.md`, *Measured, not assumed*). modpack's "on request" is a cost choice (grado-factorio-modpack#151), though the sample shows it run on most PRs. tools splits by lane instead. tn gets breadth from three models instead of a second pass. | **Shared with a parameter**: the second pass, `none`, `on request` or `every PR`. |
| **5. Who reviews** | One fresh agent runs both lanes when the change touches no script, or each commit answers a finding; otherwise one agent per lane. | One fresh subagent. | Pre-PR: one fresh `general-purpose` subagent, "never a fork, since a fork has already read the author's reasoning". Plugin pass: five reviewers on Sonnet, then one verifier on Sonnet. | Three persistent agents of three vendors (Codex, Antigravity's `agy`, Claude Code on Fable), each in its own Herdr space and git worktree. | Near on independence: all four use a reviewer that did not write the change. Different on how many and which models; tn's panel is user-level infrastructure. | **Shared**: the reviewer did not write the change and is not a fork. **Local**: how many and which. |
| **6. Lanes** | Bug scan, and prose lane; the prose lane loads `code-review-prose.md`, the bug scan does not. | None: one reviewer, rules page read whole. | Pre-PR: none. Plugin pass: the plugin's five tasks (`CLAUDE.md` compliance, shallow bug scan, blame and history, earlier PRs, code comments), each told prose is a bug. | None: each of the three gets the same brief. | Different. tools' split is fitted to its prose page's 2,000-byte limit and the bug scan's script work. rf's five are the plugin's. | **Local**. |
| **7. The brief's home** | `docs/agents/review-brief.md`, one template, blanks `<like this>`; a lane that runs both gets both *Reads first* lines. | `docs/agents/pre-pr-review-brief.md`: a review turn and a confirmation turn, blanks `<like this>`, "sent… as it stands". | Templates inside the two tracked skills, step 3 of `/pre-pr-review` and steps 2 and 4 of `/plugin-pass`. | `brief-template.md` in the user-level skill, plus the answer instructions `panel.py send` appends. | Near: all four keep a written template whose blanks the session fills, and none lets the session brief freehand. Where it lives is drift, except rf's skills, which are fitted to running steps. | **Shared with a parameter**: a brief is a written template, filled and sent as it stands; the parameter is its path. |
| **8. What the brief leaves out** | — | — | "nothing about what the author thinks is right, and nothing that excuses a commit in the diff". | "Name what the maintainer has already accepted, so reviewers don't re-raise it". | Different, and opposed: rf withholds the author's view; tn hands over settled decisions. Both have a reason; modpack's "What is not under review, such as a decision of Truls's" sits between them. | **Shared**: the brief names Truls's settled decisions as not under review and nothing of the author's own view. Proposed as the reconciliation, since modpack already words it so. |
| **9. Read-only** | "Edit no file… commit nothing, push nothing, and post nothing to GitHub." | "The review is read-only… posts nothing to GitHub"; no download or install. | Read-only; plugin-pass briefs also name `git checkout`, `switch`, `stash`, `reset`, `worktree`, "no gate, nothing left running in the background, and no message to another agent". | "do not edit, commit, check out branches, push, or post anything to GitHub; do not run the game or the repo's long-running checks… start no subagents". | Same in substance; the forbidden lists grew from each repository's incidents (rf realistic-fusion-refreshed#650's detached `HEAD`). | **Shared**: read-only, posts nothing. The list of forbidden commands as a shared floor, each repository adding its own. |
| **10. Where a reviewer may change files** | Reverts run on a clone of the commit outside the repo, via `scripts/revert-run.ps1`. | — (nothing planted). | Its own worktree for any planting (third rule); plugin-pass subagents in a worktree not the session's, by `herdr worktree create` or `isolation: "worktree"`. | Each agent has its own worktree; reads with `git show origin/<branch>:<path>`. | Near: all keep the reviewer's work off the session's checkout. Mechanism is fitted (tools' self-tests ask git for `origin/main`, so a clone). | **Shared**: a reviewer that must change a file does it in a copy of its own, never the session's checkout. **Parameter**: clone or worktree. |
| **11. Given: the diff** | `git diff origin/main...<full SHA>` and each touched file whole. | `git diff origin/main...HEAD` after `git fetch origin`, and a `git cherry -v` pass first. | `git fetch origin main`, then `git diff origin/main...HEAD` (realistic-fusion-refreshed#755, realistic-fusion-refreshed#758); plugin pass reads `gh pr diff <n>`. | `gh pr diff <N>` and `git diff -w origin/main...origin/<branch>` after `git fetch origin`. | Same: a three-dot diff against a fetched `origin/main`. | **Shared**. |
| **12. Given: the commit messages and PR body** | Prose lane: `git log origin/main..<SHA>` and `gh pr view`. | `git log --format=%B origin/main..HEAD`; the PR body draft at confirmation (grado-factorio-modpack#273). | Pre-PR: messages are part of the diff's review; step 7 reads them again. | `gh pr view --json 'title,body,commits,…'`; "anything wrong in the PR body, the commits or the issue's notes". | Same: messages and body are reviewed as text. | **Shared**. |
| **13. Given: the tickets** | Each closed ticket with `gh issue view --json title,body,labels,comments`. | `gh issue view <N> --json title,body,comments`. | The **Read an issue** command of `issue-tracker.md`. | `gh issue view <issue> --json 'title,body,comments'`. | Same: the ticket with its comments, by `--json`. | **Shared** (the command is already lifted to `tracker-conventions.md`, #325). |
| **14. Held against the ticket** | A change that does other than an acceptance criterion, the *Asked* or a ruling of Truls's "is a finding scored 80", unless the PR cites Truls allowing it. | Tickets handed; no stated spec check. | "hold the diff against its acceptance criteria". | The brief names the issue and what was accepted on it. | Near: three of four hold the diff to the ticket; tools makes it binding by score. | **Shared**: the diff is held against each closed ticket's acceptance criteria. The score tools gives it is under the threshold rule (#327). |
| **15. Given: the rules page** | `CLAUDE.md`, `code-review.md`; the prose lane `code-review-prose.md`. | `code-review.md` whole, `GLOSSARY.md`, `claim-grades.md`. | `code-review.md` whole; the plugin pass's reviewers its *Review the prose* section. | "Check against CLAUDE.md and the commit convention". | Near; tn has no page (ruling 4 of #327 gives it one). | **Shared**: the reviewer reads the shared `code-review-rules.md` and the repository's `code-review.md`. **Parameter**: what else (glossary, claim grades). |
| **16. Given: check results** | The bug scan runs `scripts/check.ps1` unless CI's `check.yml` passed on the commit, then the self-tests CI does not run. | The session runs `commit-check.ps1`, `markdown-check.ps1`, `glossary-check.ps1`, `absolute-words.ps1`, `mentions.ps1` (and the resolve if an `info.json` changed) and hands the output. | The session runs `run-gates.ps1`, or `ship-check.ps1` alone for markdown-only, and hands the output. | Reviewers are told not to run long checks; tn has no CI. | Different, and fitted: each list is that repository's checks. Who runs them differs: tools' reviewer, the session elsewhere. | **Shared with a parameter**: the review stands on a named check run, CI's by id or a local one, reported in the review; the parameter is the check list. |
| **17. Given: raw output behind figures** | — | Required on a branch that records measurements; "A figure whose raw output is gone is a finding". | Required: the probe's report in `.probe-reports/`. | — | Different: fitted to modpack and rf, whose branches record measurements (portal readings, probes). tools and tn record few figures. | **Shared with a parameter**: the rule, with "applies to branches that record measurements"; the evidence's location is the parameter. |
| **18. Given: agent-facing files whole** | — | — | Each skill file, `docs/agents/` page and `CLAUDE.md` the diff changes, read whole (realistic-fusion-refreshed#647). | — | Different: rf alone; drift rather than fit, since all four change such files. | **Shared** (proposed spread of rf's rule): a sentence a change made false and did not touch is in no hunk. |
| **19. Tests shown able to fail** | The bug scan reverts each claim of a script on the clone, and each condition on a changed line; "a revert that fails nothing is a finding". | — | — | "For every test outcome the PR reports, check the test could have reported the opposite… a run against the code before the fix goes red". | Near between tools and tn (the same idea, by run in tools, by reading or run in tn). modpack and rf rely on their pre-PR evidence instead. | **Shared with a parameter**: each test claim is shown able to fail; the parameter is how (tools' `revert-run.ps1`, or the reviewer's reading). |
| **20. Finding fields** | Place, Text, Failure, Right, Score. | Where, Evidence, Fix; no score. | Pre-PR: file and quoted words, what is wrong, source; no score. Plugin reviewers: also "why it was flagged". | `<severity> <file>, <symbol>: <what is wrong and why>. Fix:`, "In repo:" or "Hypothetical:" first. | Near on the four fields (place, quoted text, what fails with evidence, fix). Different on the grade, below. | **Shared**: place, quoted text, failure with its evidence, fix. |
| **21. The finding's grade** | A suggested score 0–100 on the plugin's rubric; the session scores. | None; "a score it gave itself would read as the plugin pass's". | Pre-PR: none (realistic-fusion-refreshed#610). Plugin pass: the verifier's verdict, real, not real or not verified (realistic-fusion-refreshed#626). | Severity: blocking, should-fix, nit; the session rates each "correct, fair, or wrong". | Different. Each grade feeds its own sort: tools' 80 must-fix, rf's verdicts sort two comments, tn's severity orders the table. The threshold rule itself is ruled (#327). | **Local** for which grade; the sort rule is #327's. Flagged for #332: the shared page must word "the threshold" so that a verdict and a severity can each stand in for a score. |
| **22. What is also reported** | "Nothing found", with what was read and run. | *Read and found correct*, one line each. | What the reviewer did not check, which the session must answer item by item (realistic-fusion-refreshed#636); plugin reviewers list what they noticed and did not raise. | "Checked and sound: <one line>". | Near: all four ask the reviewer to say what it checked. Only rf asks what it did not check, and binds the session to it. | **Shared**: what was checked and found right, and what was not checked. Answering the not-checked list is proposed as shared too. |
| **23. How the report travels** | Returned as the lane's reply. | Written to `<scratch>/review.md` with the file tool, then at most five lines; a reply was cut off twice. | One line per finding, detail on request by SendMessage; "a long reply arrives cut off". The report arrives once the session's turn ends (realistic-fusion-refreshed#648). | A file in `%TEMP%\review-panel\`, at most 400 words; `collect` reads it. | Near between modpack and tn (a file, a cap); rf solves the same cut-off another way; tools has no rule. Drift: all four saw or could see the cut-off. | **Shared**: the report is a file outside the repository, with a short reply naming it. |
| **24. The session checks each finding** | "every finding that survived verification", scored by the session. | No stated step; the session fixes. | The plugin pass's verifier checks each candidate against one source. | "Check each claim against the code before you rate it". | Near in three; modpack has none stated. | **Shared**: no finding is acted on or posted unchecked. **Local**: whether a verifier subagent does it. |
| **25. Who decides what is fixed** | "A finding at 80 or more must be fixed; the rest are recorded." | Every finding fixed or left with the reason; one needing Truls is "listed as unfixed and waiting on him". | Real or not-verified candidates fixed or left with a reason; two kinds of fix put to Truls first (realistic-fusion-refreshed#782: a load-time `error()`, a `CLAUDE.md` edit). | "The maintainer decides what to fix: present the table and ask." | Different. tools and rf let the session fix; tn asks every time; modpack and rf send Truls's calls to him. | **Shared**: a finding that needs Truls's decision is not fixed by the session and is listed as waiting on him. **Local**: the rest. |
| **26. Fix commits** | — (fix commits; the tip body may be amended once). | "The fixes are one commit of their own, after the ticket commits." | Fixes committed after the tag `pre-pr-reviewed`; a held fix marked `yes, not confirmed` (realistic-fusion-refreshed#643). | tn (observed): fixes in later commits, cited by SHA in the combined comment. | Near: fixes are commits of their own, not folded in. | **Shared**. |
| **27. Who confirms a fix** | Asked again, a review of the commits since. | The same subagent, continued, reads each fix commit as new diff. | The same reviewer, continued, handed the fix diff "and nothing else"; it also confirms the plugin pass's fixes. | A new round on the new head (PR true-nukes-refreshed#66: three). | Near: modpack and rf identical in substance; tools and tn re-review. | **Shared**: the reviewer that raised a finding confirms its fix from the fix diff, with no list of what was done; a fresh one is handed the report where it cannot be continued. |
| **28. A finding in a commit message** | Not rewritten, except one amend and force-push of the tip body before any fix commit. | Reworded before the first push (`reword-commit.ps1`); once pushed, the message stays. | Reworded, with `--force-with-lease` on an unmerged branch, unless a later message names and narrows it (realistic-fusion-refreshed#640, realistic-fusion-refreshed#783). | No rule; IDs switched after merge (`switch_ids.py`). | Different, and fitted to step 1's timing: the later a review runs, the more a rewrite costs. | **Local**, until step 1 converges. |
| **29. Where findings are posted** | One PR comment, not edited, in its own format; says which check it stood on. | Pre-PR findings in the PR body (via `pr-body.ps1`); plugin pass comments. | Pre-PR findings table in the body under `## Pre-PR review`; two plugin-pass comments. | One combined comment after the fixes, "when asked", with an AI disclaimer and an Outcome column. | Different, fitted to step 1: a pre-PR review has no PR to comment on, so the body; an on-PR review comments. | **Shared with a parameter**: every finding and its outcome is recorded on the PR once, in one place; the parameter is body or comment. |
| **30. A missed finding's class** | — | Named in the PR; a script-detectable class becomes a ticket, one of judgement a line in the page; "One-off, no rule" is an answer. | Same, from the pre-PR reviewer's own report (realistic-fusion-refreshed#820); a class becomes a `ship-check.ps1` section. | — | Same between modpack and rf; absent where there is no second pass. | **Shared with a parameter**: applies where a second pass runs (step 4). |
| **31. Recording cost** | — | — | Reviewer's and main session's tokens in the body, rows in `review-figures.md` (`tools/review-usage.py`). | — | Different: rf alone, for its revisits of the plugin-pass rule. | **Local**. |
| **32. What gates the merge** | Truls merges (observed); CI's `check.yml`; every finding at 80 or more fixed; the comment posted. | "The merge is Truls's"; not merged while a plugin pass or its confirmation runs (grado-factorio-modpack#159); the check run's result a comment on the PR. | Truls merges (observed); `gates.yml`, which runs the body check too; the plugin pass and its confirmation done; step 7's reading after the last fix. | Truls merges (observed); no CI; the panel's findings answered as he decides. | Near: Truls merges in all four, with no branch protection. What must be done first differs by the gates each has (tn has no CI until the CI ruling, #320, lands). | **Shared with a parameter**: Truls merges; not while a review or confirmation runs; after the named CI workflow passes on the head. The parameter is the workflow. |
| **33. After the merge** | Cite the PR, not a branch commit (`issue-tracker.md`). | Two clearing points (grado-factorio-modpack#159): after the PR opens and after the merge, with what each needs. | Delete the tag `pre-pr-reviewed`. | `switch_ids.py` moves the body's and comments' IDs to the `main` copies; panel worktrees fast-forwarded, panel restarted. | Different. How a commit is named is ruled by *Rulings: pull request body rules* (#326). | **Local** (the naming is #326's). |

## A proposed shared procedure

Built only from the rows marked shared, or shared with a parameter. Each repository's parameters
are named after the outline.

1. **Every change with a diff gets a review before its merge**, of every commit on the branch,
   none exempt for size (rows 1, 2). Each `CLAUDE.md` names the page to load first (row 3).
2. **The reviewer did not write the change and is not a fork** (row 5). It is briefed from a
   written template, filled and sent as it stands (row 7), which names Truls's settled decisions
   as not under review and nothing of the author's own view (row 8).
3. **It is read-only and posts nothing**, under a shared floor of forbidden commands; a file it
   must change, it changes in a copy of its own (rows 9, 10).
4. **It is handed** the three-dot diff against a fetched `origin/main`, the commit messages and
   the PR body or its draft, each closed ticket with its comments by `--json`, the shared rules
   page and the repository's `code-review.md`, each agent-facing file the diff changes, whole,
   a named check run, and, on a branch that records measurements, the raw output behind each
   figure (rows 11 to 18).
5. **It holds the diff against each ticket's acceptance criteria, and shows each test claim able
   to fail** (rows 14, 19).
6. **It writes its report to a file outside the repository** and replies with a short line naming
   it (row 23). Each finding gives place, quoted text, failure with evidence, and fix (row 20),
   graded as the repository grades (row 21, local). The report says what was checked and found
   right, and what was not checked; the session answers each item not checked (row 22).
7. **The session checks each finding before acting on it** (row 24). A finding that needs Truls's
   decision is listed as waiting on him and not fixed (row 25).
8. **Fixes are commits of their own** (row 26), and **the reviewer that raised a finding
   confirms its fix** from the fix diff alone, with no list of what was done (row 27).
9. **Every finding and its outcome is recorded once on the pull request** (row 29). Where a
   second pass runs (row 4), a finding it raised that the first missed has its class named, as a
   ticket for a check, a line in the page, or "one-off, no rule" (row 30).
10. **Truls merges**, not while a review or confirmation runs, and after the CI workflow passes on
    the head (row 32).

| Parameter | tools | modpack | rf | tn |
|---|---|---|---|---|
| When (row 1) | on the PR | before the PR, before first push | before the PR, and on it | on the PR |
| Second pass (row 4) | none (two lanes instead) | on request | every PR (`/plugin-pass`) | none (three-agent panel) |
| Trigger line and page (row 3) | `docs/agents/code-review.md` | `docs/agents/code-review.md` | `docs/agents/code-review.md` | `docs/agents/code-review.md` (to be written, #327 ruling 4) |
| Brief template (row 7) | `docs/agents/review-brief.md` | `docs/agents/pre-pr-review-brief.md` | `.claude/skills/pre-pr-review/SKILL.md`, `.claude/skills/plugin-pass/SKILL.md` | none tracked; user-level `brief-template.md` today |
| Reviewer's copy (row 10) | clone | — | own worktree | the panel's worktrees (user-level) |
| Further reading (row 15) | `code-review-prose.md` (prose lane) | `GLOSSARY.md`, `claim-grades.md` | `claim-grades.md` for `docs/adr/` and `docs/research/` | — |
| Check run (row 16) | `scripts/check.ps1`, CI `check.yml` | the five scripts and the resolve of `pre-pr-review-brief.md` | `scripts/run-gates.ps1` or `ship-check.ps1` | none until the CI ruling (#320) lands |
| Raw output (row 17) | — | `<scratch>`, by command | `.probe-reports/` | — |
| Test claims (row 19) | `scripts/revert-run.ps1` | reviewer's reading | reviewer's reading | reviewer's reading |
| Where recorded (row 29) | one PR comment | PR body (`pr-body.ps1`) | PR body table, plus two plugin-pass comments | one combined PR comment |
| Merge gate workflow (row 32) | `check.yml` | `check.yml` | `gates.yml` | none yet |

**Rows left local** and why: lanes (6), the grade (21), who fixes the rest (25), commit-message
rewrites (28), cost records (31) and after-merge steps (33). Row 28 follows row 1: once the
timing converges, the rewrite rule can too. Row 21 is the largest open seam, because the shared
threshold rule (#327) is written about a score, and only tools still scores.

**Three proposals that matter most:**

- **Row 1 is the hinge.** Four timings exist, and rows 16, 28 and 29 follow from them. A shared
  "before the merge, of every commit" with timing as a parameter keeps each repository's gates;
  converging the timing itself would mean tools giving up its CI-backed bug scan, or modpack and
  rf giving up pre-push rewording.
- **Row 27, the same reviewer confirms each fix from the fix diff alone**, is the step two
  repositories already share almost word for word, and the one tn's and tools' re-review practice
  lacks: rf's realistic-fusion-refreshed#594 shows why the list of what was done is withheld.
- **Row 23, the report as a file** removes a failure modpack and rf both measured (replies cut
  off), and tn's panel already does it.

## What could not be determined

- **Whether modpack's plugin passes were each asked for.** 16 of its last 20 merged PRs carry a
  plugin-pass or `## Code review` comment, against a rule that runs it only on request; reading
  whether Truls asked each time needs the sessions, which are not tracked.
- **tools' practice behind "on top of the `/code-review` plugin".** Its page uses the plugin's
  rubric for scores, but whether the plugin itself runs, or only `review-brief.md`'s lanes, is not
  said, and its recent comments open `## Review of <SHA>` or the AI disclaimer, not the plugin's
  `### Code review`.
- **Why tn's seven recent PRs without a combined comment had none**, the seven listed under
  *What was read*: no tracked tn rule says when the panel runs.
- **How tn's sessions answer findings beyond the combined comment.** The skill says the
  maintainer decides; whether fixes are confirmed by the same reviewer agent or by a fresh round
  was read only from PR true-nukes-refreshed#66's three rounds.
- **The cost of each procedure.** rf alone measures it (`review-figures.md`); no figure exists
  for the others, so a shared step chosen on cost has evidence from one repository only.
- **The full pages were not all read.** `code-review-evidence.md` (tools, rf),
  `code-review-why.md` (modpack), `code-review-history.md` and `review-figures.md` (rf) were read
  by their headings only, and `plugin-pass.md` past *What the session does* was not read. They
  hold evidence and history, not steps, by their own introductions.
