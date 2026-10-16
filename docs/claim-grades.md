# Claim grades

**This page is where the three claim grades are defined, for the repositories that link to it.**
A claim in a document is graded by its evidence: *Measured*, *Read from source* or *Inferred*,
or it has no grade. The rules below say how a reviewer checks those grades.

A repository that adopts the grades states its own scope, meaning which files they apply to and
why, beside its link to this page. This page sets no scope. This repository does not apply the
grades to its own docs (Truls, 2026-10-16, on
[#159](https://github.com/trulsjo/grado-factorio-tools/issues/159)).

The text was taken from trulsjo/grado-factorio-modpack at `39dfb8c` (read 2026-10-16), with the
meanings unchanged. The grades come from its `GLOSSARY.md`: added in
trulsjo/grado-factorio-modpack#157 (2026-10-06), with *Measured* amended in
trulsjo/grado-factorio-modpack#292 (2026-10-15). The rules come from its
`docs/agents/code-review.md`, *A claim has a grade, and two of the three are always marked*.
An example that comes from one repository names it.

## The grades

**Measured**:
The thing itself was run or queried and the result written down: a script's output over a data
dump, a load's log, a portal reading, or what a person saw in a play session. It carries its day,
and its build where a game was run, stated with the claim or by the section it stands in. A search
that finds nothing is measured, and carries what was searched. A cause is measured when the run
itself tested it: it changed one named thing, taken from the record as what actually differed,
the record shows every other input held, in one run or in two whose recorded inputs are otherwise
equal, and the result changed. The claim is limited to what was run.
The strongest of three grades of evidence, above *Read from source* and *Inferred*.
_Avoid_: confirmed, verified, observed, checked (none says which grade is meant); "measured" for
anything whose day neither it nor its section gives

**Read from source**:
Taken from a mod's code or data files, with nothing executed. It carries the release that was read.
A portal description or a changelog is not source: what an author says is quoted and attributed,
and has no grade until someone measures it or reads the source. Weaker than *Measured*, because
nothing ran.
_Avoid_: read or reading on its own (a portal reading is *Measured*), "the mod does" for what its
source says it would do

**Inferred**:
Concluded from other claims, and it names them. The weakest of the three grades, below *Read from
source*. A conclusion takes the weakest grade among its parts, and the step that joins them is
itself inferred: a cause joined to a measured effect is inferred, however solid each half is,
unless the cause itself was tested as *Measured* says. That nothing exists is inferred from a
search that found nothing. From grado-factorio-modpack: "`SpaceMod` has no 2.0 release" was
measured, and "SpaceX is dead" was inferred from it and wrong.
_Avoid_: assumed (a claim that names nothing it rests on has no grade; it is marked "not measured"
or it is a finding), likely without saying from what

## The rules of review

- ***Measured* may go unmarked inside a section that says how and when it was measured.** Two
  examples, both from grado-factorio-modpack: a load record's build line, and a catalogue
  header's portal-reading date.
- ***Read from source* and *Inferred* are marked every time**, and again wherever the conclusion
  is repeated.
- **Each grade has something it carries**: its day and build, the release read, or the claims it
  rests on. A claim without it is not that grade.
- **A conclusion takes the weakest grade among its parts.**
- **A claim that names nothing it rests on has no grade**: it is marked "not measured", or it is a
  finding.
