# Grado Factorio Tools — agent notes

Shared tooling for the Factorio mod projects. See `README.md` for what belongs here; this file is how
to work in the repo.

**Long-term context lives in the brain**, not here — the decision trail and what was measured versus
assumed. `CLAUDE.local.md` has the path and is git-ignored. Read it at session start.

## State

**Empty skeleton**, created 2026-09-20. A README, this file, and `docs/extraction-plan.md`. **No
tooling has been extracted.** Every script named in the plan still lives in
`realistic-fusion-refreshed`, still works there, and is still covered by that repo's gates.

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
- **How the sibling repos consume this one** — git submodule, vendored copy, published PowerShell
  module. None is chosen, and the answer shapes every extraction after it.
- **Where the mod portal API key lives** and what gates a release.
- **The licence.** No `LICENSE` file yet. The sibling `realistic-fusion-refreshed` is LGPLv3 because
  it carries Krastorio 2 code; that reasoning does not transfer to tooling written from scratch.

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
prefix. The rules below are `realistic-fusion-refreshed`'s, adopted here so that one check can
serve both repos — only the scope vocabulary and the extraction rule are this repo's own. One
format, no exceptions:

```
<emoji> <type>(<scope>): <subject>

<body>

<footer>
```

**Subject line**

- Imperative mood, lowercase after the colon, no trailing period, whole line ≤ 72 characters.
- `<scope>` is optional but preferred. Use the tool (`coexistence`, `tree-viewer`, `pack`, `upload`,
  `commit-check`) or the area (`docs`, `repo`).
- The emoji is the *rendered* character, not the `:shortcode:`.

**Types, and the emoji that goes with each**

| Type | Emoji | Use for |
|---|---|---|
| `feat` | ✨ | a new capability |
| `fix` | 🐛 | a bug fix |
| `docs` | 📝 | documentation only |
| `refactor` | ♻️ | restructuring with no behaviour change |
| `perf` | ⚡️ | performance |
| `test` | ✅ | tests |
| `build` | 📦 | packaging, dependencies |
| `chore` | 🔧 | tooling and config |
| `style` | 🎨 | formatting and code structure only |
| `revert` | ⏪️ | reverting a previous commit |

A few situational ones worth knowing: 🎉 to begin a project, 🚚 to move or rename files, 🔥 to remove
code or files, 🌐 for localisation, 💄 for icons and other visual assets, 🚧 for work in progress.

**Extraction** — use **🚚 `refactor`**, and name the origin repo and commit in the body.

**Body** — explain *why*, not what the diff already shows. Wrap at 72. Reference the Factorio API
version when a change depends on one.

**Breaking changes** — for anything that breaks a consuming repo's interface, put `!` before the
colon *and* a `BREAKING CHANGE:` footer explaining the migration.

Example:

```
🚚 refactor(commit-check): adopt commit-check.ps1 from the mod repo

Moved from realistic-fusion-refreshed at 4fc73cf. It had no references
to that project, so it transfers unchanged. Removed there in the same
change; no copy is left behind.
```

## Agent skills

### Issue tracker

Issues live as GitHub issues on `trulsjo/grado-factorio-tools`, driven via the `gh` CLI.
See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical roles, each label string equal to its name. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
