# Context

Shared tooling for the Factorio mod projects: the scripts that are about *a* Factorio mod rather
than *this* one. The language here is deliberately the sibling `realistic-fusion-refreshed`'s, so
that a script keeps its meaning when it changes repository.

## Language

### What this repository holds

**Tool**:
A script that serves any mod project rather than one of them. The umbrella term for everything
here; check, probe and bench are the three shapes of tool that assert something, and a tool need
not be any of them — a viewer and a fetcher are tools too.
_Avoid_: utility, helper, tooling (as a count noun)

**Entanglement**:
How tightly a tool is coupled to one mod's domain, *whether or not it names that mod*. Counting a
script's references to the project is a proxy for it and an undercounting one: a tool can be welded
to a mod through an assumed directory layout, an invariant, or a table of that repository's agreed
conventions while naming it zero times.
_Avoid_: coupling, project-specificity

### Script shapes

Inherited verbatim from `realistic-fusion-refreshed`, because a script that moves here must not
change what it is on the way. What separates the three is what each one asserts.

**Check**:
A script that asserts an invariant. It is a gate: it passes or fails, and a failure blocks.
`commit-check.ps1` is one.
_Avoid_: checker, validator, linter

**Probe**:
A script that asserts nothing. It answers a question a decision is waiting on, and exit 0 means it
ran and reported — never that the answer was the hoped-for one.
_Avoid_: investigation, spike

**Bench**:
A script that asserts only its own validity. It refuses to report a number it cannot stand behind,
and nothing blocks on it, because no gate runs it.
_Avoid_: benchmark script, perf test

### Moving work between repositories

**Extraction**:
Moving a script out of the repository it was written in and into this one, leaving nothing behind.
A copy that stays is not an extraction, because two copies that drift are worse than one file in
the wrong repository.
_Avoid_: copy, port, share, migrate

**Origin**:
The repository and commit a script was extracted from, recorded so its history stays recoverable
after the move.
_Avoid_: source repo, upstream — "upstream" means predecessor mod code in the sibling repository
and must not be reused for this.

**Consumer**:
A repository that resolves a tool from here rather than holding a copy of it. The counterpart of
*origin*: origin is where a tool was written, consumer is where it is used after the move — and a
repository is usually both. A repository holding its own copy is not a consumer, however identical
that copy is today.
_Avoid_: client, dependent, downstream — "upstream" here means predecessor mod code in the sibling
repository, so "downstream" cannot be pressed into service as its mirror.

**Pin move**:
A change to the commit of this repository that a consumer records for its `vendor/` submodule. Its
range is the commits between the old pin and the new one.
_Avoid_: pin bump, upgrade

**Stub page**:
A page at a fixed path that a skill or a repository's `CLAUDE.md` sends a session to, such as
`docs/agents/issue-tracker.md`, that holds one repository's own parts and links a shared page
here for the rest. Where `/setup-matt-pocock-skills` writes the page, its first line warns that
re-running the skill rewrites it in place and drops the link. A stub the skill does not write,
as `docs/agents/code-review.md`, which `CLAUDE.md` sends a review to, carries none. A sibling's stub
links the shared page by its `vendor/` path with the GitHub URL beside it; this repository's own
by a relative link ([ADR 0003](docs/adr/0003-shared-agent-docs-are-linked-from-the-pin-never-imported.md)).
_Avoid_: pointer page, shim, copy — a stub holds none of the shared page's rules.

**Breaking commit**:
A commit that calls itself breaking, by the rule in `scripts/breaking-lib.ps1`'s header. What it
breaks is a consumer's interface, as `CLAUDE.md` defines a breaking change.
_Avoid_: breaking change, when the commit is meant

### Reviewing a change

**Answer**:
The file a review lane or a panel reviewer writes its findings to, outside the repository, and
adds a `Turn` section to on each confirmation turn: `docs/agents/review-brief.md`'s
*The answer is a file*, and the `review-panel` skill's answer file (#458).
_Avoid_: "report" for the file a lane writes — the word stays as the verb and as the session's own
account to Truls.

### The game

**Line**:
A major.minor version of the game, such as `2.1`: the `factorio_version` a mod declares in its
`info.json`.
_Avoid_: game version, release, branch

**Build**:
One installable version of the game, such as `2.1.23`, on the line its first two parts name. It is
what `Factorio.exe --version` prints after `Version:`, not the number it prints after `build`,
such as `87750`. A measurement of the game is made on a build and names it.
_Avoid_: game version, release, patch
