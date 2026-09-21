# Code review — two rules this repository adds

Both are conventions layered on the `/code-review` plugin rather than changes to it; see *Why it is
written here rather than fixed at source* at the foot.

Both were decided by Truls in the sibling
[realistic-fusion-refreshed](https://github.com/trulsjo/realistic-fusion-refreshed), and adopted here
on 2026-09-21 because this repository hit the first of them on its first pull request, exactly as
the modpack did on its own.

1. **[The threshold gates the comment, not the report](#the-threshold-gates-the-comment-not-the-report)**
   — decided 2026-08-26, settling
   [realistic-fusion-refreshed#128](https://github.com/trulsjo/realistic-fusion-refreshed/issues/128).
2. **[Review the prose, not only the code](#review-the-prose-not-only-the-code)** — decided
   2026-09-03, widened 2026-09-14 settling
   [realistic-fusion-refreshed#331](https://github.com/trulsjo/realistic-fusion-refreshed/issues/331).

## The threshold gates the comment, not the report

The `/code-review` workflow scores each candidate finding and drops anything below 80. **That filter
governs what gets posted to the pull request. It does not govern what gets told to the person who
ran the review.**

### The rule

**Report every finding that survived verification, whatever it scored.** Post to the PR only what
clears the threshold, exactly as the workflow says.

**A review that posts nothing must still say what it filtered.** Name each finding, its score, and
whether it was independently verified. A silent pass and a filtered pass must never look the same.

**Do not re-score to get a finding published.** The threshold is deliberately conservative and stays
where it is. If a filtered finding matters, say so in the report and let a human decide; inflating a
score to route around the filter destroys the only signal the score carries.

### Why the threshold cannot be read as "these findings do not matter"

The rubric offers exactly five values — **0, 25, 50, 75, 100** — and the filter admits 80 or more. So
it admits exactly one of them. The effective rule is *score exactly 100*, and the 75 band, which the
rubric itself defines as

> Highly confident. The agent double checked the issue, and verified that it is very likely it is a
> real issue that will be hit in practice … The issue is very important

is discarded by construction. A finding can be verified, important, and dropped.

**Measured here, on the first pull request this repository ever had.**
[PR #5](https://github.com/trulsjo/grado-factorio-tools/pull/5): five review lanes, eight findings,
**zero posted**. Three scored 75, all three were real, and all three were fixed by rewriting the
branch:

| finding | score | what it was |
|---|---|---|
| the rejection rationale | 75 | `docs/extraction-plan.md` said the vendored copy "was rejected partly on cost". ADR 0001, added in the same PR, rejects it on the no-network constraint and on principle — cost is what ruled out the *published module*. Two documents in one changeset disagreed about their own decision |
| the banned word | 75 | `CLAUDE.md` wrote "one checker" in the same commit that added `CONTEXT.md` listing `checker` under `_Avoid_`, for the concept `CONTEXT.md` uses as its worked example |
| the situational count | 75 | the commit message and PR body claimed the sibling has "seven" situational emoji. It lists six. The seventh, 🔀, exists only in `commit-check.ps1`, which the sibling's own `CLAUDE.md` deliberately omits |

A fourth, `CLAUDE.md`'s State section still enumerating the repository as three files, scored 60 and
is partly pre-existing. The siblings measured the same shape: ten findings and zero posted across
realistic-fusion-refreshed's PRs #124, #126 and #127, nine of them real; nine findings and zero
posted on the modpack's first PR, the two highest both real.

**Note the pattern in all three of this repository's 75s: the shipped artefact was correct and the
prose describing it was wrong.** The emoji table was right and the sentence counting it was wrong.

## Review the prose, not only the code

**This repository is prose and nothing else.** Nothing has been extracted, so there is no script
here to run, no gate to fail, and nothing that can be loaded in Factorio to contradict a claim. The
first gate it will get is the commit check, which reads the *shape* of a commit message and says so
in its own header. A wrong sentence in this repository has no natural enemy.

### The rule

**Check every number in prose against a number in the diff, and do the arithmetic.** Not "does this
look plausible" — count it out. A line count, a reference count, a number of types in a table, a
tally of repositories: each is a claim with an arithmetic answer, and the answer is usually in the
same diff.

**Treat a quantifier as an instruction to enumerate.** "Nothing has been extracted", "every
earmarked script still lives there", "none of the three repos has CI" — a claim about *all* or
*none* of a set is checked by walking the set, never by agreeing with its tone.

**When a change supersedes a figure, grep the repository for the old one**, and read every hit in a
file that records a measurement. Here that is `docs/extraction-plan.md`, `docs/adr/`, `CLAUDE.md`,
`CONTEXT.md` and this file. A correction landing in three places and missing the fourth is worse
than none, because the survivor then reads as deliberate.

**An old figure inside a block that says what replaced it is not a defect; an unmarked one is.** The
house style strikes the old reading through and states what settled it, with a date and usually an
ADR or issue number, rather than erasing it.

**A measurement of the sibling repository is a measurement.** Every line count, reference count and
verdict in `docs/extraction-plan.md` came from a command run against a checkout on a particular day,
and that checkout is actively developed. An undated one is a finding.

**Check a claim about entanglement against the file, not against the count.** The reference count is
a proxy this repository's own method section admits is an undercount. See below: its best case was
wrong.

**This binds the reviewer.** An author who greps before opening the pull request saves a round, but
the obligation lives in the review.

### Measured, not assumed

Every defect this repository has produced has been prose, and none was catchable by machinery
because there is no machinery:

| what escaped | where it was |
|---|---|
| **the extraction spec argued from a false premise** — that moving the commit check removes duplication. It removes none: the check exists exactly once, and the two repositories without it had shipped 135 pull requests between them without missing it. Caught by a grilling pass, not a review | issue #1, rewritten |
| **"0 project references" was read as "portable"** and it is not. `commit-check.ps1` names the project zero times and is still coupled to one repository's convention through its emoji table. The plan's own method section warns the count undercounts; the verdict column ignored its own warning | `docs/extraction-plan.md` |
| **a blocking edge that was simply wrong** — ticket #3 was marked blocked by the consumption decision. A repository that *holds* a check consumes it through no mechanism at all; it has the file | the tracker, corrected |
| **the worked example broke the rule it demonstrates** — the commit-message example in `CLAUDE.md` exceeded 72 characters by one and by two. Found only by running the sibling's check against it | `CLAUDE.md`, fixed |

Three of those four are a claim stated more confidently than its evidence allowed, and the fourth is
a document failing its own stated rule. **Two documents written in one session agree with each other
by construction**, which is why the two defects that were caught cleanly were caught by something
outside the session: a script that had never read them, and a reader with no memory of writing them.

## Why it is written here rather than fixed at source

The workflow is a plugin, at `~/.claude/plugins/cache/claude-plugins-official/code-review/`. It is
not this repository's to edit, and editing a cache would be undone by the next plugin update. So
this is a convention, and `CLAUDE.md` points at it so a review session loads it before running.

Nothing about the scoring, the rubric or the 80 is changed. The first rule drops one assumption —
that a filtered finding is a discarded one. The second adds one obligation the rubric never
mentions, because a plugin that reviews code cannot know that here there is no code at all yet.
