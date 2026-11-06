# Writing agent docs

**How the repositories that link this page keep the documents an agent reads**: a `CLAUDE.md`,
which loads into every session on every turn, and the pages it links, which load when followed.

Ruled by Truls on 2026-11-06 in
[*Rulings: the shared parts of each CLAUDE.md*](https://github.com/trulsjo/grado-factorio-tools/issues/328),
rulings 3 and 4, with "evidence on its own page" sent there by
[*Rulings: code review rules*](https://github.com/trulsjo/grado-factorio-tools/issues/327).
Gathered from four sources, read 2026-11-06: trulsjo/grado-factorio-modpack's `CLAUDE.md`,
*Conventions*, at `987e638`; trulsjo/realistic-fusion-refreshed's `docs/agents/state-detail.md`
and the cite rule in its `CLAUDE.md`, both at `9fd78b5`; trulsjo/true-nukes-refreshed's cite rule
at `78486d2`; and trulsjo/grado-factorio-tools's `$PAGE_LIMITS` in `scripts/check.ps1` at
`e70669f`. The reason for the cite rule is from rf's ADR 0032.

## The live rule only

- **A `CLAUDE.md` states the live rule only.** It is loaded into every session, so a line there
  is paid for on every turn. When a line changes, its old wording does not stay beside the new.
- **History and evidence go on a page of their own**, linked from where the rule stands: the
  dated trail of a rule, the incidents that showed it, what was measured. A sentence added where
  none stood owes the trail nothing.
- **A rule every session needs keeps a one-line form in `CLAUDE.md`**, with the link to the page
  that states it in full.
- **Each repository sets its own size limits.** trulsjo/grado-factorio-tools holds three agent
  pages to a byte count in `scripts/check.ps1`'s `$PAGE_LIMITS`.

## Cite our own code by symbol, never by line number

**Our own code is cited by its symbol**: the function, field, constant or prototype, with a
repository-relative path, since two files may share a name (realistic-fusion-refreshed has two
`entities.lua`). A comment with no symbol is cited by a quoted fragment of its own words.
trulsjo/realistic-fusion-refreshed's ADR 0032 at `9fd78b5` gives the reason: two pull requests
moved `control.lua`'s `get_capacity` call sites and left a research note pointing at the old
lines.

**Ancestor, vanilla and third-party code keeps its line numbers**: a predecessor mod, the game's
own Lua, another author's mod. Those trees are never edited here. So our own code is, by that
contrast, the code a repository's own commits edit (the session's reading of the two rules).
