# Commit convention

**This is the canonical declaration of the commit-message convention** for this repository and for
every repository that consumes it. [Conventional Commits](https://www.conventionalcommits.org/)
with a [gitmoji](https://gitmoji.dev/) prefix. One format, no exceptions:

```
<emoji> <type>(<scope>): <subject>

<body>

<footer>
```

`scripts/commit-check.ps1` enforces what is written here. A consuming repository keeps its own
scope vocabulary in its `CLAUDE.md`, because scopes name that repository's own parts; everything
else on this page is shared.

## Subject line

- Imperative mood, lowercase after the colon, no trailing period, whole line ≤ 72 characters.
- `<scope>` is optional but preferred. Each repository declares its own scope vocabulary.
- The emoji is the *rendered* character, not the `:shortcode:`.

## Types, and the emoji that goes with each

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

A type takes its own emoji and no other.

## Situational emoji

These are accepted **with any type**, rather than having a type of their own: 🎉 to begin a
project, 🚚 to move or rename files, 🔥 to remove code or files, 🌐 for localisation, 💄 for icons
and other visual assets, 🚧 for work in progress, 🔀 for a merge commit written by hand.

🔀 is declared here because the check has always accepted it and no document said so — a drift
found on 2026-09-21 while extracting the check, and closed in the direction the check's own header
asked for. `realistic-fusion-refreshed` has eight hand-written merge commits that depend on it.

## Body

Explain *why*, not what the diff already shows. Wrap at 72.

## Breaking changes

For anything that breaks a consuming repository's interface, put `!` before the colon *and* a
`BREAKING CHANGE:` footer explaining the migration.

## Example

```
🚚 refactor(commit-check): adopt commit-check.ps1 from the mod repo

Moved from realistic-fusion-refreshed at 8a4fb90. It had no references
to that project, so it transfers unchanged. Removed there in the same
change; no copy is left behind.
```

## What the check is blind to

- **Imperative mood.** Not mechanically checkable, and not checked. "adds a gate" passes.
- **Whether the type is the right one.** `feat` on a bug fix is accepted.
- **Whether the scope exists.** Any `(text)` is accepted; the vocabulary is not read.
- **This page.** The type table and the situational list are literals in `scripts/commit-check.ps1`
  and are not compared against what is written here. That second home is deliberate and the reason
  is in [ADR 0002](adr/0002-the-commit-convention-is-declared-in-one-document.md).
