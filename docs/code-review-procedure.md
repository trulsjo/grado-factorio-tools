# Code review procedure

**This page holds the review procedure the repositories that link to it share**: the steps of a
review, and the parameters each repository gives. The rules a review applies are on
[`docs/code-review-rules.md`](code-review-rules.md). Each repository's
`docs/agents/code-review.md` is a stub page that links both pages, gives its value for each
parameter under *What each stub gives*, and keeps the steps under *Left to each repository*.

Ruled by Truls on 2026-11-06 in
[*Rulings: a shared code review procedure*](https://github.com/trulsjo/grado-factorio-tools/issues/332),
rulings 1 to 8 and 10, with the step under *Before the reviewer is started* from
[*Rulings: review and session tooling*](https://github.com/trulsjo/grado-factorio-tools/issues/329),
ruling 1. The steps and the parameters are those of
[the survey](research/review-procedures.md), *A proposed shared procedure*, whose rows the
steps below name, as the rulings amend them. Gathered from the review pages of three
repositories, read 2026-11-06: trulsjo/grado-factorio-tools's `docs/agents/code-review.md` and
`review-brief.md` at `e70669f`; trulsjo/grado-factorio-modpack's `docs/agents/code-review.md`
and `pre-pr-review-brief.md` at `987e638`; and trulsjo/realistic-fusion-refreshed's
`docs/agents/code-review.md`, `plugin-pass.md` and its `pre-pr-review` and `plugin-pass` skills
at `9fd78b5`.

## Before the reviewer is started

**The session walks the absolute-words list.** It runs

```sh
pwsh -File scripts/absolute-words.ps1 -Range origin/main...HEAD
```

in this repository, and the same script under `vendor/grado-factorio-tools/` in a repository
that links this page. The script lists each line the range adds, in Markdown, in a comment or in
a commit message, that holds a word such as "only", "every" or "cannot"; it lists and does not
fail, and its header says what it reads. Of each line the session asks whether the sentence
holds for what its word covers, and rewords the one that does not. A word used in passing is
left. In trulsjo/grado-factorio-modpack, 5 of the 11 findings of PR #210's first review and 3 of
the 8 of PR #216's were one such word (grado-factorio-modpack#219, by #329's account).

## The steps

1. **Every change with a diff gets a review before its merge**, of every commit on the branch,
   none exempt for size (rows 1 and 2). When it runs, before the pull request, on it, or both,
   is the repository's. Each `CLAUDE.md` names the page to load first (row 3).
2. **The reviewer did not write the change and is not a fork of the session that did** (row 5).
   It is briefed from a written template, filled and sent as it stands (row 7). The brief names
   what is not under review, such as a decision of Truls's that the change records, and holds
   nothing of what the author thinks is right (row 8).
3. **The review is read-only and posts nothing to GitHub.** The reviewer edits, stages, commits
   and pushes nothing in the session's checkout, to which each repository adds the commands its
   own incidents name. A file it must change, it changes in a copy of its own (rows 9 and 10).
4. **The reviewer is handed** (rows 11 to 18):
   - the three-dot diff against a fetched `origin/main`;
   - the commit messages, and the pull request's body or its draft;
   - each ticket the change closes, with its comments, read as
     [`docs/tracker-conventions.md`](tracker-conventions.md)'s *Read an issue with `--json`*
     says;
   - [`docs/code-review-rules.md`](code-review-rules.md) and the repository's
     `docs/agents/code-review.md`;
   - each agent-facing file the diff changes, to read whole: a `CLAUDE.md`, a page under
     `docs/agents/`, a skill file. A sentence the change made false and did not touch is in no
     hunk;
   - a named check run, CI's by its id or a local one;
   - on a branch that records measurements, the raw output behind each figure.
5. **The reviewer holds the diff against the acceptance criteria of each ticket the change
   closes, and each test claim is shown able to fail** (rows 14 and 19).
6. **The reviewer writes its report to a file outside the repository**, and replies with a short
   line naming the file (row 23): a report sent as a reply has arrived cut off, in the modpack
   and in rf. A finding gives its place, the text quoted, the failure with its evidence, and the
   fix (row 20), graded as the repository grades. The report also says what was checked and
   found right, and what was not checked, and the session answers each thing not checked
   (row 22).
7. **The session checks each finding before it acts on it or posts it** (row 24). A finding that
   needs Truls's decision is not fixed by the session, and is listed as waiting on him (row 25).
8. **Fixes are commits of their own** (row 26). **The reviewer that raised a finding confirms
   its fix, from the fix diff alone**, with no list of what was done (row 27). Where that
   reviewer cannot be continued, a fresh one is handed its report and the fix diff.
9. **Every finding and its outcome is recorded once on the pull request** (row 29). Where a
   second pass runs, a finding it raised that the first pass missed has its class named: as a
   ticket for a check, as a line in a review page, or as "one-off, no rule" (row 30).
10. **Truls merges**: not while a review or a confirmation runs, and after the repository's CI
    workflow passes on the head (row 32).

## What each stub gives

| Parameter | What the stub names |
|---|---|
| When (row 1) | before the pull request, on it, or both |
| Second pass (row 4) | `none`, `on request` or `every PR`, and what runs it |
| Trigger page (row 3) | the page its `CLAUDE.md` says to load before a review |
| Brief template (row 7) | the path of the template a reviewer is briefed from |
| Reviewer's copy (row 10) | where a reviewer changes a file: a clone or a worktree |
| Further reading (row 15) | what a reviewer reads beside the two rules pages |
| Check run (row 16) | the checks a review stands on, and who runs them |
| Raw output (row 17) | where the raw output behind a figure is kept |
| Test claims (row 19) | how a test claim is shown able to fail |
| Where recorded (row 29) | the pull request's body or a comment on it |
| Merge workflow (row 32) | the CI workflow that passes before the merge |

The stub also names the repository's threshold, as
[`docs/code-review-rules.md`](code-review-rules.md) asks.

## Left to each repository

Six steps are no part of this page, and each repository's stub holds its own:

- **lanes** (row 6): whether a review is split among reviewers, and how;
- **the grade** (row 21): a score, a verdict or a severity, and who gives it;
- **who fixes the rest** (row 25): what the session fixes of the findings that do not wait on
  Truls;
- **commit-message rewrites** (row 28): whether a commit a finding names is reworded, which
  follows from when the review runs;
- **cost records** (row 31);
- **after-merge steps** (row 33).

The brief templates and the review skills stay each repository's own (ruling 10): each is the
template step 2 names, and is brought into line with the steps above when its repository links
this page.
