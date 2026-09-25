# Grado Factorio Tools — agent notes

Shared tooling for the Factorio mod projects. See `README.md` for what belongs here; this file is how
to work in the repo.

**Long-term context lives in the brain**, not here — the decision trail and what was measured versus
assumed. `CLAUDE.local.md` has the path and is git-ignored. Read it at session start.

## State

**The first extraction is finished.** `scripts/commit-check.ps1` is here, moved from
`realistic-fusion-refreshed` at `8a4fb90`, and no copy of it remains anywhere. Both
`realistic-fusion-refreshed` and `grado-factorio-modpack` resolve it from this repo as a submodule
at `vendor/grado-factorio-tools`, each pinned to a commit it bumps deliberately. One check, three
repositories, no copies — see
[issue #1](https://github.com/trulsjo/grado-factorio-tools/issues/1).

The pins, the bump commits and the tripwire's answer are in `docs/extraction-plan.md`.

**Two more are extracted and finished.** `fetch-mods.ps1` and the load-check harness are here and
nowhere else (#15 and #16 here, contracted by that repository's #456 to #462) — see *Expanded and
contracted* in `docs/extraction-plan.md`.
`resolve-modpack.ps1` was written here, not moved (#14). Everything else named in the plan still
lives in `realistic-fusion-refreshed`, still works there, and is still covered by that repo's
gates.

## The rule that matters most here

**Nothing is moved out of a working repo without agreement.** `realistic-fusion-refreshed` is actively
developed and its `ship-check` and `load-check` gates depend on the scripts earmarked here. Extraction
is a refactor of someone's working build, not a copy — and the cost of breaking it exceeds the
duplication it removes.

So: propose an extraction, name what it breaks, and wait. Do not start by moving a file to see what
happens.

**Copying is not extracting.** Two copies that drift are worse than one file in the wrong repo.
Whatever moves leaves nothing behind.

## The decisions that are Truls's

- **Which scripts move, and in what order.**
- ~~**How the sibling repos consume this one.**~~ **Decided 2026-09-21: a git submodule**, pinned to
  a commit each sibling bumps deliberately. See
  [ADR 0001](docs/adr/0001-siblings-consume-this-repo-as-a-submodule.md), which records why
  vendoring and a published module were rejected, and the audience assumption the choice rests on.
- **Where the mod portal API key lives** and what gates a release.
- ~~**The licence.**~~ **Decided 2026-09-21: MIT**, in `LICENSE`. The sibling
  `realistic-fusion-refreshed` is LGPLv3 because it carries Krastorio 2 code; that reasoning does
  not transfer to tooling written from scratch. Forced now rather than later because a submodule
  makes this repo a build dependency of two others, so "all rights reserved by default" stopped
  being harmless.

Do not settle any of them as a side effect of doing something else. Recording options with trade-offs
is welcome; choosing between them is not.

## What belongs here, and what does not

**Belongs:** anything about *a* Factorio mod rather than *this* Factorio mod. Coexistence checking,
the tech tree viewer, packing and uploading, commit-message checking, locale and prototype-name rules.

**Does not belong:** anything encoding one mod's domain. A reactor invariant, a fuel table, a balance
figure, a prototype name. **If a script needs to know `rf-`, it stays where it is.**

The line is not always obvious. `load-check.ps1` is the worked example: its harness — build an
isolated mod directory, junction or zip the mods in, create a throwaway map, report which way it
loaded — is general, while thirteen of its invariants are Realistic Fusion's own. The file does not
move; the harness might.

## Factorio specifics

- Mods are **Lua**. The API has **three stages**: `settings` and `prototype` run at start-up,
  `runtime` runs during gameplay. Tooling here mostly drives the game from outside rather than running
  inside it.
- API docs are published **per game version** at <https://lua-api.factorio.com/>. Check claims against
  the version being targeted rather than from memory. `/stable/` and `/latest/` both move, and
  `latest` is the **experimental** build — pin an explicit version when recording a fact.
- The **mod portal API** is the source for what exists and at what version:
  `https://mods.factorio.com/api/mods/<name>/full` gives each release's `info_json`, including
  `factorio_version` and dependencies. No key needed for reads. **Publishing needs an API key**, which
  is a different credential from the `player-data.json` token used for downloads.
- **Check `factorio_version` for any `2.x`, not `== "2.0"` exactly.** A mod that moved to 2.1 is not
  missing.
- **A mod missing under one name is not a mod that does not exist.** Learned on 2026-09-20 in the
  sibling modpack repo: `SpaceMod` has no 2.0 release, but `SpaceModFeorasFork` is a live fork on 2.1.
  Search titles and summaries, not just names.

## Conventions

- Default branch `main`. Commit email is set per-repo — do not change it.
- `CLAUDE.local.md` is personal and git-ignored. Never commit it, and never move its contents into a
  tracked file.
- **A script does one job and says so in its header.** The sibling repo's convention: a
  `.SYNOPSIS`/`.DESCRIPTION` block that states what exit 0 means, and what the script cannot see.
- **State what a check is blind to**, in the script itself. A gate that overstates its coverage is
  worse than no gate.
- **When a script moves here, record where it came from** in `docs/extraction-plan.md` — the origin
  repo and commit — so its history is recoverable.
- Cite our own code by symbol, not line number.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/) with a [gitmoji](https://gitmoji.dev/)
prefix. One format, no exceptions:

```
<emoji> <type>(<scope>): <subject>

<body>

<footer>
```

**The rules live in [`docs/commit-convention.md`](docs/commit-convention.md)** — the type table,
the situational emoji, the subject and body limits, and what the check is blind to. That page is
the single declaration for this repository and for both that consume it: since
[#9](https://github.com/trulsjo/grado-factorio-tools/issues/9) and
[#4](https://github.com/trulsjo/grado-factorio-tools/issues/4) each sibling points here for the
table and keeps only its own scope vocabulary. A rejected message names the page too. Reasoning in
[ADR 0002](docs/adr/0002-the-commit-convention-is-declared-in-one-document.md).

Three things are this repository's own:

- **Scope vocabulary.** Use the tool (`coexistence`, `tree-viewer`, `pack`, `upload`,
  `commit-check`) or the area (`docs`, `repo`).
- **What counts as a breaking change.** Here: anything that breaks a consuming repository's
  interface. The `!` and the `BREAKING CHANGE:` footer are shared mechanics; what triggers them is
  domain knowledge, and a sibling's answer is its own — save compatibility in the mod repo, a
  dependency change an existing save cannot survive in the modpack.
- **Extraction** — use **🚚 `refactor`**, and name the origin repo and commit in the body.

`.githooks/commit-msg` runs `scripts/commit-check.ps1` on the message before the commit is written.
Git does not track `.git/hooks`, so each clone opts in once:

    git config core.hooksPath .githooks

## Agent skills

### Issue tracker

Issues live as GitHub issues on `trulsjo/grado-factorio-tools`, driven via the `gh` CLI.
See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical roles, each label string equal to its name. See `docs/agents/triage-labels.md`.

### Code review

Two conventions on top of the `/code-review` plugin: a filtered finding is still reported, and the
prose is reviewed as carefully as the code, because here there is nothing but prose. **Load
`docs/agents/code-review.md` before running a review.**

### Domain docs

Single-context: `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
