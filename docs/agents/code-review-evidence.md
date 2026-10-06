# Code review — the evidence behind the rules

The rules are in [code-review.md](code-review.md), which is what a review loads. This page holds
what was measured and what was found, so that page can stay short and nothing measured is lost.
Moved here from that page on 2026-10-06
([#65](https://github.com/trulsjo/grado-factorio-tools/issues/65)); the text of each section is as
it stood there, apart from the first.

## How a review is run

Decided 2026-10-06, settling
[#62](https://github.com/trulsjo/grado-factorio-tools/issues/62). The figures are that ticket's,
from a retro of the ten sessions of 2026-10-01 to 2026-10-06, and were not measured again when
this page was written.

- Each session ran the review twice, once inside `/implement` and once on the pull request.
- A review ran 8 to 14 subagents and 8 to 27 million cache-read tokens, for diffs of 16 to 115
  added lines.
- Across eight pull request reviews, two comments were posted.
- The history lane and the earlier-pull-request-comments lane came back empty in nearly every
  review.

**What was dropped, so the choice can be revisited.** The plugin runs five review lanes: `CLAUDE.md`
compliance, a bug scan, the git history of the touched code, comments on earlier pull requests
that touched the same files, and compliance with comments in the code. It then scores each finding
with an agent of its own. This repository keeps the bug scan, folds the `CLAUDE.md` and
code-comment lanes into one prose lane, drops the history and earlier-comments lanes, and has the
reviewing session score. If a defect is ever found that only one of the dropped lanes would have
caught, that is the evidence for bringing it back.

The rule against a header listing what the code lists was added the same day, settling
[#61](https://github.com/trulsjo/grado-factorio-tools/issues/61): most findings across the reviews
of #31 to #56 were such a list gone stale, and #48 and #52 were tickets for exactly that.

## Where the first two rules came from

Both were decided by Truls in the sibling
[realistic-fusion-refreshed](https://github.com/trulsjo/realistic-fusion-refreshed), and adopted here
on 2026-09-21 because this repository hit the first of them on its first pull request, exactly as
the modpack did on its own.

1. **The threshold gates the comment, not the report** — decided 2026-08-26, settling
   [realistic-fusion-refreshed#128](https://github.com/trulsjo/realistic-fusion-refreshed/issues/128).
2. **Review the prose, not only the code** — decided 2026-09-03, widened 2026-09-14 settling
   [realistic-fusion-refreshed#331](https://github.com/trulsjo/realistic-fusion-refreshed/issues/331).

## Why the threshold cannot be read as "these findings do not matter"

The `/code-review` workflow scores each candidate finding and drops anything below 80. The rubric
offers exactly five values — **0, 25, 50, 75, 100** — and the filter admits 80 or more. So it
admits exactly one of them. The effective rule is *score exactly 100*, and the 75 band, which the
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
| the banned word | 75 | `CLAUDE.md` wrote "one checker" in the same commit that added `GLOSSARY.md` listing `checker` under `_Avoid_`, for the concept `GLOSSARY.md` uses as its worked example |
| the situational count | 75 | the commit message and PR body claimed the sibling has "seven" situational emoji. It lists six. The seventh, 🔀, existed only in `commit-check.ps1` — **declared 2026-09-21** in `docs/commit-convention.md`, and recharacterised by ADR 0002 as undetected drift rather than a deliberate omission |

A fourth, `CLAUDE.md` still enumerating the repository as three files in the section that then
recorded its state, scored 60, was partly pre-existing, and was fixed 2026-09-21. The siblings
measured the same shape: ten findings and zero posted across realistic-fusion-refreshed's PRs #124,
#126 and #127, nine of them real; nine findings and zero posted on the modpack's first PR, the two
highest both real.

**Note the pattern in all three of this repository's 75s: the shipped artefact was correct and the
prose describing it was wrong.** The emoji table was right and the sentence counting it was wrong.

## Why the prose is reviewed

**This repository is almost entirely prose.** ~~Nothing has been extracted, so there is no script
here to run, no gate to fail.~~ **Changed 2026-09-21:** `scripts/commit-check.ps1` is here and
gates every commit. Nothing can still be loaded in Factorio to contradict a claim, and the one gate
there is reads the *shape* of a commit message and says so in its own header — so the point is
undiminished. A wrong sentence in this repository has no natural enemy.

Three quantified claims — "the check exists exactly once", "nothing has been extracted", "that repo
was never ungated" — were each written in this repository, and each was false.

The reference count that `docs/extraction-plan.md` uses for entanglement is a proxy its own method
section admits is an undercount, and its best case was wrong: see the table below.

### Measured, not assumed

Every defect this repository has produced has been prose, and none was catchable by the machinery
it has. There is a gate now — `scripts/commit-check.ps1`, since 2026-09-21 — and it reads the shape
of a commit message, not the truth of a sentence. It would have caught none of these:

| what escaped | where it was |
|---|---|
| **the extraction spec argued from a false premise** — that moving the commit check removes duplication. Caught by a grilling pass, not a review. ~~It removes none: the check exists exactly once, and the two repositories without it had shipped 135 pull requests between them.~~ **The correction was itself wrong, 2026-09-21**, and in the opposite direction: `grado-factorio-modpack` held a byte-identical copy, so the check existed twice; only one repository was ungated, and only for its first three commits; and 135 is `realistic-fusion-refreshed`'s own PR count, never a total for the two. The duplication is real | issue #1, rewritten twice |
| **"0 project references" was read as "portable"** and the inference was the thing to watch. The plan's own method section warns the count undercounts; the verdict column ignored its own warning | `docs/extraction-plan.md` |
| ~~the emoji table is what couples `commit-check.ps1` to one repository~~ — the worked example of the row above, and **it did not survive measurement (2026-09-21)**: all three type tables are identical, so the table coupled the check to nothing. The coupling is real but elsewhere — the script's header names `CLAUDE.md` as the authority and carries the sibling's own measurements into a repository where they are false | `docs/extraction-plan.md`, ADR 0002, issue #10 |
| **a blocking edge that was simply wrong** — ticket #3 was marked blocked by the consumption decision. A repository that *holds* a check consumes it through no mechanism at all; it has the file | the tracker, corrected |
| **the worked example broke the rule it demonstrates** — the commit-message example in `CLAUDE.md` exceeded 72 characters by one and by two. Found only by running the sibling's check against it | `CLAUDE.md`, fixed |

Three of those four are a claim stated more confidently than its evidence allowed, and the fourth is
a document failing its own stated rule. **Two documents written in one session agree with each other
by construction**, which is why the two defects that were caught cleanly were caught by something
outside the session: a script that had never read them, and a reader with no memory of writing them.

## Why it is written here rather than fixed at source

The workflow is a plugin, at `~/.claude/plugins/cache/claude-plugins-official/code-review/`. It is
not this repository's to edit, and editing a cache would be undone by the next plugin update. So
this is a convention, and `CLAUDE.md` points at the rules page so a review session loads it before
running.

Nothing about the rubric or the 80 is changed. The reporting rule drops one assumption — that a
filtered finding is a discarded one. The prose rules add one obligation the rubric never mentions,
because a plugin that reviews code cannot know that here there was once no code at all. Since
2026-10-06 the lanes and who scores are changed too, as the first section says.
