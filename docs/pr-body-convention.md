# Pull request body convention

**This page declares what `scripts/pr-body-check.ps1` checks in a pull request body**, for the
repositories that link to it, on
[ADR 0002](adr/0002-the-commit-convention-is-declared-in-one-document.md)'s pattern: the check and
the page that declares it live in one repository. The script's header says how each rule is read,
and what it cannot see. Each repository's `docs/agents/issue-tracker.md` links this page and keeps
its own additions beside the link.

Ruled by Truls on 2026-11-06 in
[*Rulings: pull request body rules*](https://github.com/trulsjo/grado-factorio-tools/issues/326),
rulings 1, 2 and 4. Gathered from three tracker pages, read 2026-11-06:
trulsjo/grado-factorio-tools at `e70669f`, trulsjo/grado-factorio-modpack at `987e638` and
trulsjo/realistic-fusion-refreshed at `9fd78b5`.

## The four rules every run checks

1. **A commit the body cites is on `main`.** Pull requests are rebase-merged, which rewrites every
   commit on the branch, so a branch commit's hash names something the merge deletes. A hash may
   be cited once it is on `main`. The check asks git whether each word that names a commit is an
   ancestor of `origin/main`.
2. **A closing keyword stands only in a bare `Closes #N` line**, one ticket to a line. GitHub
   closes an issue on a closing keyword before a reference anywhere in the body, whether the
   author meant it or not: trulsjo/grado-factorio-tools's PR #105 said "No ticket is closed:
   #103" on 2026-10-11, and GitHub listed that issue as one the merge would close.
3. **The `mattpocock-skills:pr` template's three headings**, `## Summary`, `## Evidence` and
   `## Merge Danger`, stand once each and in that order. Other sections may stand before, between
   and after them.
4. **The template's four markers**: `**Before:**` and `**After:**` under `## Evidence`, and
   `**Door:**` and `**Blast Radius:**` under `## Merge Danger`.

## What each switch adds

- **`-CiteSiblings`**: a statement about a sibling repository carries a commit and an ISO date.
  The script's header says which words make a sentence such a statement.
- **`-RequireSummaryVisual`**: `## Summary` holds a fenced or an indented code block.
- **`-CheckRuns`**, with `-Head` and the pull request's head commit: each run of the repository's
  `check` workflow the body cites ran on the head, and its step that runs `scripts/check.ps1`
  passed on every job. With no `-Head`, no run is read. The script's header says which words make
  a number a cited run.

**The switches are each repository's choice** (ruling 4). A repository turns one on in its own CI
line and its own hook line.

## Naming a branch commit

**Never by its hash; by its hash once it is on `main`.** Any of three ways names a branch commit,
and a repository may use any of them (ruling 2):

- **the pull request**, as "PR #367";
- **its role**, as "the fix commit" or "the ticket commit for #N";
- **its subject, in quotes**.

The check cannot tell these apart, and they do not conflict.

## Before a create

The body is checked before it is sent, joined with `&&` so that a failure stops the create:

```sh
pwsh -File <scripts>/pr-body-check.ps1 <body file> [switches] && gh pr create ... --body-file <body file>
```

`<scripts>` is `scripts` in this repository and `vendor/grado-factorio-tools/scripts` in a
sibling. The same holds for `gh pr edit --body-file`. A check joined with `;`, or piped to another
command, does not stop the create on a failure.
