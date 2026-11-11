# Grado Factorio Tools — agent notes

`README.md` says what belongs here and what each script does;
[`docs/extraction-plan.md`](docs/extraction-plan.md) says what has moved here and what is still
earmarked.

**Read through another repository's `vendor/`?** Follow its `CLAUDE.md`, not this one (ADR 0003).

**Long-term context lives in the brain**, not here. `CLAUDE.local.md` has the path. Read it at
session start.

## The rule that matters most

**Nothing is moved out of a working repo without agreement.** `realistic-fusion-refreshed` is
actively developed and its gates depend on the scripts earmarked here. Propose an extraction, name
what it breaks, and wait. Do not start by moving a file to see what happens.

**Copying is not extracting.** Whatever moves leaves nothing behind: two copies that drift are
worse than one file in the wrong repo.

**If a script needs to know `rf-`, it stays where it is.** What belongs here is about *a* Factorio
mod, not *this* one.

## The decisions that are Truls's

- **Which scripts move, and in what order.**
- **Where the mod portal API key lives**, and what gates a release.

Do not settle either as a side effect of doing something else. Recording options with trade-offs
is welcome; choosing between them is not. How the siblings consume this repo is decided: a pinned
submodule, [ADR 0001](docs/adr/0001-siblings-consume-this-repo-as-a-submodule.md).

## Working here

- **Tests are each script's `-SelfTest`.** `pwsh -File scripts/check.ps1` runs all but those
  that need the game, and names them: run each as `pwsh -File scripts/<script> -SelfTest`.
- **Factorio is installed on the development machine**, and `load-harness.ps1` runs it headless and
  isolated from the player's game. So a ticket that needs a measurement of the game is
  `ready-for-agent`.
- The hooks, pre-commit, commit-msg and pre-push, are opted into once per clone:
  `git config core.hooksPath .githooks`.
- **A session asks before it downloads a program and runs it here**;
  [`scripts/ask-before-download.ps1`](scripts/ask-before-download.ps1) refuses one, and its header
  holds the reason.
- Commit email is set per-repo — do not change it.
- `CLAUDE.local.md` is never committed, and its contents never move into a tracked file.
- **A script does one job and says so in its header**: what exit 0 means, and what the script
  cannot see. A gate that overstates its coverage is worse than no gate.
- **When a script moves here, record its origin repo and commit** in `docs/extraction-plan.md`.
- Cite our own code by symbol, not line number
  ([`docs/writing-agent-docs.md`](docs/writing-agent-docs.md)).

## Factorio facts to check, not remember

- The game: [`docs/factorio-facts.md`](docs/factorio-facts.md). Read the installed build with
  `Factorio.exe --version`, and pin an explicit build when recording a fact.
- The mod portal: [`docs/mod-portal.md`](docs/mod-portal.md), before querying it.

## Commit messages

`<emoji> <type>(<scope>): <subject>`. The rules are in
[`docs/commit-convention.md`](docs/commit-convention.md). Three things are this repository's own:

- **Scopes**: a scope is the tool or the area. They are listed in `commit-scopes.txt` and nowhere
  else; the check reads it.
- **A breaking change** is anything that breaks a consuming repository's interface.
- **An extraction** is 🚚 `refactor`, naming the origin repo and commit in the body.

## Agent skills

- **Before starting a ticket**, read `docs/agents/issue-tracker.md`: work starts on a
  `ready-for-agent` one, on a branch, never `main`. Tracker and pull request conventions are
  there; the shared ones in [`docs/tracker-conventions.md`](docs/tracker-conventions.md).
- **Triage labels**: `docs/agents/triage-labels.md`.
- **Code review**: **load `docs/agents/code-review.md` before running a review.** One review, on
  the pull request; the prose is reviewed as carefully as the code.
- **Domain docs**: `GLOSSARY.md` and `docs/adr/`. `docs/agents/domain.md`.
