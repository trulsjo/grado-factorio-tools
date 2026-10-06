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
