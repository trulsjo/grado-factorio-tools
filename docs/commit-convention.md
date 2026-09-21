# Commit convention

**This is the canonical declaration of the commit-message convention** for this repository and for
both repositories that consume it. [Conventional Commits](https://www.conventionalcommits.org/)
with a [gitmoji](https://gitmoji.dev/) prefix. One format, no exceptions:

```
<emoji> <type>(<scope>): <subject>

<body>

<footer>
```

`scripts/commit-check.ps1` enforces what is written here. Two things stay with the consuming
repository, because both are its own domain rather than shared mechanics: its **scope vocabulary**,
and **what counts as a breaking change**. Everything else on this page is shared.

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

A type takes its own emoji, or one of the situational emoji below. It never takes another type's.

## Situational emoji

These are accepted **with any type**, rather than having a type of their own: 🎉 to begin a
project, 🚚 to move or rename files, 🔥 to remove code or files, 🌐 for localisation, 💄 for icons
and other visual assets, 🚧 for work in progress, 🔀 for a merge commit written by hand.

🔀 is declared here because the check has always accepted it and no document said so — a drift
found on 2026-09-21 while extracting the check. `realistic-fusion-refreshed` had eight hand-written
merge commits depending on it at `8a4fb90` (2026-09-21).

## Body

Explain *why*, not what the diff already shows. Wrap at 72 — with two exemptions the check makes on
purpose, both listed under *What the check is blind to*.

## Breaking changes

Put `!` before the colon *and* a `BREAKING CHANGE:` footer explaining the migration.

**What counts as a breaking change is each repository's own**, and stays in its `CLAUDE.md`
alongside its scope vocabulary. This page owns the mechanism; the definition is domain knowledge,
and this repository's rule is that one mod's domain does not live here. A mod repository's answer
is save compatibility; a modpack's is a dependency change an existing save cannot survive; this
repository's is a consuming repository's interface. Three different rules, one `!` and one footer.

## Example

Illustrative. The SHA is a placeholder, not a commit in any repository.

```
🚚 refactor(pack): adopt pack-mods.ps1 from the mod repo

Moved from realistic-fusion-refreshed at 4fc73cf. Removed there in the
same change; no copy is left behind.
```

## What the check is blind to

A gate that overstates its coverage is worse than no gate, so:

- **No PowerShell, no gate at all.** The hook reports that the message was not checked and lets the
  commit through. Same when the check cannot be resolved — a renamed script, or an uninitialised
  submodule in a consuming repository. This is the largest blind spot and it is deliberate: a
  machine that was never going to run the gates is not blocked by them.
- **Imperative mood.** Not mechanically checkable, and not checked. "adds a gate" passes.
- **Whether the type is the right one.** `feat` on a bug fix is accepted.
- **Whether the scope means anything.** Any non-empty text without parentheses in it is accepted,
  and no repository's vocabulary is read. `()` and a scope containing parentheses are rejected, but
  by the format rule rather than by anything that knows what a scope is.
- **Trailer lines are exempt from the 72-character body rule.** A `Key: value` block at the end of
  the message is skipped, because `Co-Authored-By:` and `Claude-Session:` end in an address or a
  URL that cannot be broken, and git parses that block by position.
- **A line whose longest single word exceeds the limit passes.** No wrapping makes it fit, and
  flagging it would only teach people to ignore the gate. A bare long URL is the real case.
- **`fixup!`, `squash!`, `amend!`, `Merge …` and `Revert "…"` subjects skip every rule**, because
  git writes or rewrites them rather than a person.
- **This page.** The type table and the situational list are literals in `scripts/commit-check.ps1`,
  and the script's header restates several of these rules in prose — so this convention has three
  homes, not two, and none is compared against another. Deliberate, and reasoned in
  [ADR 0002](adr/0002-the-commit-convention-is-declared-in-one-document.md). That header also still
  names `CLAUDE.md` as where the rules live, which it no longer is; that is
  [issue #10](https://github.com/trulsjo/grado-factorio-tools/issues/10), deferred because editing
  the script would end the byte-identical transfer the extraction rests on.
