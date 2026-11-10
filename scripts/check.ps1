<#
.SYNOPSIS
    Parses every script under scripts/, holds their comment lines to a width, reads their list
    parameters with param-check.ps1, their variables' spelling with variable-case-check.ps1,
    their help with help-check.ps1 and their strict-mode reads with strict-list-check.ps1, holds
    README.md to naming each of their parameters, runs every
    self-test that needs neither the game nor the network, holds the agent pages to their size
    limits, and runs markdown-check.ps1 over the tracked Markdown. Exit 0 means all of that held, on
    a tree that did not change while it was read, or one git could write no tree of, which it says.
    With -SkipIfPassed, as the pre-push hook runs it, exit 0 may instead mean that nothing ran,
    because a run recorded that this same tree passed it, or that the self-tests ran none, because
    the tree differs from one that passed only in whitespace between a script's tokens; the run
    then says so.

.DESCRIPTION
    THE ONE COMMAND BEFORE A PUSH (grado-factorio-tools#60). The only gate here was commit-msg,
    which reads a message and no script. Each -SelfTest was run by hand, session by session, and
    review lanes reported more than once that no lane had run them. .githooks/pre-push runs this,
    and so does the workflow in .github/workflows/ on every pull request and on main, on Windows
    and on Linux (grado-factorio-tools#117). Nothing here is left out on either: a self-test
    that cannot pass on one of them fails this check there. What a self-test itself skips off
    Windows, it names. A local run covers the platform it runs on, as the pre-push hook's covers
    the development machine's Windows; CI's two jobs are where it runs on the other
    (grado-factorio-tools#286).

    WHAT IT RUNS. A parse of each script beside it, which finds a syntax error on a line no
    self-test reaches, and in the libraries that have no self-test. Then param-check.ps1 over the
    same scripts, for a list parameter that `pwsh -File` would hand over as one string
    (grado-factorio-tools#163), and variable-case-check.ps1, for one scope spelling a variable
    two ways that differ only in case (grado-factorio-tools#285), and help-check.ps1, for a help
    block PowerShell does not read (grado-factorio-tools#342), and strict-list-check.ps1, for a
    read of .Count, .Id or .Name that strict mode can throw on (grado-factorio-tools#373), and
    line-cite-check.ps1 over the tracked files with CI's floors, -MinCitations 50
    -MinContinuations 4, for prose that cites our own code by line number: #319 ruling 8 had it
    in CI alone, and on PR #403 the pre-push run passed what CI then refused, so Truls amended the
    ruling for it (grado-factorio-tools#404). Each of these is a step of $TOOL_STEPS. Then
    -SelfTest of each script in $SELF_TESTS, each in a pwsh of its own, so one script's `exit`
    does not end the run, and -SelfTest -NoGame of each in $NO_GAME_CASES: the cases of a script
    that needs the game which read no game's output but a log written for them
    (grado-factorio-tools#175). They run four at
    a time, or as many as the machine has processors where that is fewer, and at least two
    (grado-factorio-tools#296): twelve at a time ended no sooner and took the self-tests twice as
    long in all. They are printed in list order once all have finished, each with its own time.
    Two self-tests that collide when run together, over a shared path or setting, fail only on a
    run that happens to overlap them: fifteen full runs on Windows passed when this was made. A
    self-test that passes prints one line here; one that fails prints everything it said. One that
    exits 0 fails where its last summary line, a line opening `OK - self-test` or
    `FAILED - self-test`, which revert-run.ps1 reads too, is missing or is FAILED
    (grado-factorio-tools#297); or where it says it passed with 0 cases, all of them or 0 of
    some, as a -NoGame broken to run nothing would (grado-factorio-tools#181). It reads the output,
    so a self-test that counts a case it did not run is not seen.

    A COMMENT OR HEADER LINE OF A SCRIPT HERE IS HELD TO $COMMENT_LINE_LIMIT, the Markdown's limit
    (grado-factorio-tools#181): this header had a line of 147 characters, from
    grado-factorio-tools#179. A line counts when it is in a block comment or begins with #, as the
    parser's comment tokens give them, so a # line in a here-string is not one. A line in a help
    block's .EXAMPLE section, from that keyword to the next help keyword, with or without an
    argument, is not counted, as an example is copied whole; nor is a line of one word after its
    indent and comment marker, as an address is, which cannot be broken (Truls, 2026-10-21, on
    grado-factorio-tools#181). Not read: a code line, and a # comment after code on one, however
    long; a block comment opened after code is read from its first line, code and all; and
    characters are counted as UTF-16 units, so a character outside the Basic Multilingual Plane
    counts as two. The rule is in comment-line-lib.ps1, which comment-line-check.ps1 loads too,
    and the pre-commit hook runs that on the staged scripts before a commit
    (grado-factorio-tools#225, #344).

    README.MD NAMES EVERY SCRIPT PARAMETER (grado-factorio-tools#194). CLAUDE.md says README says
    what each script does, and PR #192 added markdown-check.ps1 -Path with no line there. Each
    parameter of a script's own param block, read with the parser, has to appear in README.md as
    -<Name>, in case and up to a word boundary; one that does not fails, named as
    <script> -<Name>, and so does a README.md that is not there. Not seen: where README names it,
    so a parameter named only under another script's section, or one -Name shared by several
    scripts, passes; what README says of it; a function's parameters; and a script outside
    scripts/.

    THE PAGES AN AGENT ALWAYS LOADS HAVE A SIZE LIMIT (grado-factorio-tools#69). CLAUDE.md loads on
    every turn and the code-review rules before every review; grado-factorio-tools#65 cut both, and
    the next edit took CLAUDE.md back over its limit before anyone looked. The prose rules are a
    page of their own, which a review's prose lane loads, with a limit of its own
    (grado-factorio-tools#116). The limits are in
    $PAGE_LIMITS and nowhere else. A page is measured with LF line endings, which is how the
    repository stores it, so a checkout with CRLF gets the same answer.

    THE TRACKED MARKDOWN IS READ BY markdown-check.ps1 -All (grado-factorio-tools#74). A page that
    moves leaves its links behind, and nothing else reads them. This script had a link check of
    its own until that one moved here; it asked the disk, in any case, and read no `[x]: path`
    line. What is checked now, and what is not, is in that script's header. It is handed
    $MARKDOWN_LINE_LIMIT, so a prose line left unwrapped fails here (grado-factorio-tools#93); that
    check is silent on length for a repository that hands it none.

    WHAT IT DOES NOT RUN. The self-tests in $NEEDS_GAME, because each starts Factorio, and a CI
    runner has no game: of one in $NO_GAME_CASES too, the cases that start it. Every script named
    there loads its mods through the harness, and the harness reads through mod-info.ps1. So
    after a change to either of those run all of them by hand, and after a change to one of the
    others, its own:

        pwsh -File scripts/load-harness.ps1 -SelfTest

    A script that declares a -SelfTest the way these do and is named in neither list below fails
    this check, so a new one is not left out in silence. So does one whose own param block
    declares $NoGame and that is not in $NO_GAME_CASES, whose no-game cases would otherwise not
    run (grado-factorio-tools#181). A -SelfTest declared some other way is missed, and so is a
    -NoGame read from $args.

    WHAT IT CANNOT SEE. A parse proves syntax and nothing else: a misspelled cmdlet or variable
    parses. No linter runs. It reads the working tree, so through the pre-push hook it checks
    what is on disk, which is not the commits being pushed when the tree has uncommitted edits.
    The Markdown is the exception: it is read as staged, so an edit not yet staged is not seen,
    and a link to a file not yet added is reported. A file with such an edit is named, as
    markdown-check.ps1 names it, and the check still passes.
    And fetch-mods.ps1's self-test listens on a loopback port, so it fails where that is refused.

    A PASS IS RECORDED, AND -SkipIfPassed READS IT (grado-factorio-tools#176). The pre-push hook
    ran this again on a tree it had just passed, minutes each time. A pass records the tree it
    read in the repository's git directory, in check-passed, never in a tracked file: the working
    tree's tracked and unignored files, written as a git tree, and the index's tree, since the
    Markdown is read as staged. A tree that is not the same at the end of the run as at the
    start fails the run, record or none, and the run names each path that changed in either
    tree (grado-factorio-tools#366): no one tree passed. The tree ids decide; where git cannot
    diff them, as after a prune of the start tree's objects, the run still fails and says it
    could not name the paths. A changed file git cannot read makes no tree, so nothing is
    compared or skipped, the record is deleted, an earlier pass's too, and the run says so
    before its last line. A run that ends in
    FAILED deletes the record; one cut short, by an error or Ctrl-C,
    leaves it. A record that does not hold both trees and a time, such as an empty file, is no
    record. With -SkipIfPassed, as the hook runs it, a tree that matches the record runs nothing,
    and the run says so, naming both trees and when they passed. A skip shows that this same tree
    passed once; it cannot see what is outside the tree: an ignored file, the pwsh or git in use,
    the loopback port fetch-mods.ps1 needs, or a self-test that passes only sometimes. CI runs
    without the switch.

    A SKIP OF THE SELF-TESTS ON A CHANGE OF WHITESPACE BETWEEN TOKENS (grado-factorio-tools#405).
    On PR #403 one space put back in one line ran the whole check, follow-pin.ps1's self-test
    alone for 313 s. With -SkipIfPassed, where the record's trees and this tree's differ only
    in .ps1 files changed in place, and each such file's tokens, read by the parser with comments
    and line breaks, are the same in both by kind and text, the run names those files and
    the passed tree, and runs no self-test, none of $TOOL_STEPS marked Parsed, and not README's
    reading of the parameters. It still runs the parse and the width check, which a space can fail
    (an indent counts), line-cite-check.ps1, the page limits and the Markdown check, and a pass
    is recorded for this tree. Any other changed file, a .ps1 added, deleted or changing mode, a
    blob git cannot read, or a change to a token's text, a comment's included, runs the whole
    check. No self-test was found that reads a tracked script by column or width, searched with
    grep for each read of a file from $PSScriptRoot or $PSCommandPath and for each column, offset
    and Get-LongCommentLine in scripts/: strict-list-check.ps1's reads its fixtures by line and
    by offset order, which such a change keeps. It cannot see a self-test that reads a script by
    column, as a parse error's message names one, or one written after that search.

    -SelfTest holds the record and its reading, Get-TokenOnlyChange, Get-RunPlan, and
    Get-RunStart and Invoke-RunPlan, which decide the skip and follow the plan, against a
    scratch repository, and this check runs
    it like the others (grado-factorio-tools#176's review); a file made unreadable off Windows
    needs a user other than root.

    HOW LONG IT TAKES ON THE DEVELOPMENT MACHINE DEPENDS ON WHAT ELSE IS RUNNING THERE
    (grado-factorio-tools#70). On a quiet machine it is under twice CI's time; it was reported as
    ten times slower while review lanes and the game were running beside it. No step here carries
    that. Each line prints its seconds so two runs can be compared; the measurement is in
    docs/measurements.md. Run at once, a self-test takes longer than alone, as the others share the
    processors: the slowest, follow-pin.ps1's, about 73 s alone and 124 s here four at a time,
    so the run ends no sooner than it does (grado-factorio-tools#296). On 2026-11-10 it took
    152 to 181 s alone, three runs, and 93 to 94 s once its setup stopped running
    `git submodule update` (grado-factorio-tools#406).

.PARAMETER SkipIfPassed
    Run nothing when the record says this tree passed, as above.

.PARAMETER SelfTest
    Run the cases that hold the record and its reading, in a scratch repository, and those that
    hold the functions each script and each self-test's run are judged by, on strings and on files
    outside it, and those that hold the two loops, Test-ScriptFolder and Invoke-SelfTestRun, over
    a folder of fixture scripts outside it with lists of their own, some of them run as
    self-tests, and the one that holds Get-ReadmeProblem over a fixture script and README there,
    those that hold $TOOL_STEPS's line-cite-check.ps1 step and Invoke-ToolStep over fixture scripts,
    and Get-TokenOnlyChange, Get-RunPlan and Get-RunStart in the scratch repository, and
    Invoke-RunPlan with blocks of its own; and nothing else. The run's own blocks, its call of
    each loop and of Get-ReadmeProblem, with this folder, this README and this script's lists,
    are not run, nor its run of param-check.ps1, variable-case-check.ps1, help-check.ps1 and
    strict-list-check.ps1 over this folder: a run that stopped making a call, or passed it a list
    less, would still pass. Nor is its reading of the record for -SkipIfPassed, its exit where
    Get-RunStart says skip, its call of Complete-Run, or its exit with the code that returns: the
    cases hold the record, the skip and the code, not that the run reads the one or exits with
    the others. Needs git, and no game.

.EXAMPLE
    pwsh -File scripts/check.ps1
#>

#Requires -Version 7
param([switch] $SkipIfPassed, [switch] $SelfTest)
$ErrorActionPreference = 'Stop'

$SELF_TESTS = @('check.ps1', 'check-input-lib.ps1', 'cited-commit-check.ps1', 'comment-line-check.ps1', 'commit-check.ps1', 'compare-resource-counts.ps1', 'dump-diff.ps1', 'dump-keys.ps1', 'dump-planets.ps1', 'dump-shared-names.ps1', 'fetch-mods.ps1',
    'follow-pin.ps1', 'get-dump.ps1', 'help-check.ps1', 'hook-matcher.ps1', 'line-cite-check.ps1', 'markdown-check.ps1', 'markdown-rewrap.ps1', 'mod-info.ps1', 'pack-mods.ps1', 'param-check.ps1', 'pin-measure.ps1', 'pr-body-check.ps1',
    'refuse-backtick-substitution.ps1', 'refuse-cd-into-mod-cache.ps1', 'refuse-git-discard.ps1', 'refuse-git-hook-skip.ps1', 'refuse-pr-body.ps1', 'refuse-python-heredoc.ps1', 'resolve-modpack.ps1', 'revert-run.ps1', 'self-test-halves.ps1', 'strict-list-check.ps1',
    'variable-case-check.ps1')
# Has a self-test this does not run, and why: it needs Factorio installed.
$NEEDS_GAME = @('dump-walk.ps1', 'load-harness.ps1', 'locale-check.ps1', 'trace-definitions.ps1', 'tree-viewer.ps1')
# Of those, each whose -SelfTest -NoGame runs the cases that need no game. This runs them.
$NO_GAME_CASES = @('trace-definitions.ps1')
# Bytes, with LF line endings; a page must be under its limit. Paths are from the repository root.
$PAGE_LIMITS = [ordered]@{ 'CLAUDE.md' = 4200; 'docs/agents/code-review.md' = 3779; 'docs/agents/code-review-prose.md' = 2000 }
# Characters a line of tracked Markdown prose may run to. What counts is in markdown-check.ps1's
# header.
$MARKDOWN_LINE_LIMIT = 100
# Characters a comment or header line of a script here may run to: the Markdown's, as above.
$COMMENT_LINE_LIMIT = $MARKDOWN_LINE_LIMIT
# The checks run as scripts of their own, from the repository root, in this order: each passes
# where it exits 0 and prints a line opening OK - <its name>:. Parsed, a check that reads the
# parsed scripts, which a change of whitespace between tokens alone leaves as they were (#405).
# line-cite-check.ps1 has CI's floors, so the pre-push hook refuses what CI would (#404).
$TOOL_STEPS = @(
    @{ Script = 'param-check.ps1'; Args = @('scripts'); Parsed = $true; Failure = 'param-check.ps1 found a list parameter never split on a comma' }
    @{ Script = 'variable-case-check.ps1'; Args = @('scripts'); Parsed = $true; Failure = 'variable-case-check.ps1 found a variable spelt two ways in one scope' }
    @{ Script = 'help-check.ps1'; Args = @('scripts'); Parsed = $true; Failure = 'help-check.ps1 found help PowerShell does not read, or a script that does not parse' }
    @{ Script = 'strict-list-check.ps1'; Args = @('scripts'); Parsed = $true; Failure = 'strict-list-check.ps1 found a read strict mode can throw on, or read no strict-mode script' }
    @{ Script = 'line-cite-check.ps1'; Args = @('-MinCitations', '50', '-MinContinuations', '4'); Parsed = $false
       Failure = 'line-cite-check.ps1 found prose citing our own code by line number, or fewer citations than its floors' }
)

$root = Split-Path $PSScriptRoot -Parent
$failed = [System.Collections.Generic.List[string]]::new()
$clock = [Diagnostics.Stopwatch]::new()
# What a step took, for the end of its line. Invariant, so a log reads the same on every machine.
$took = { '({0}s)' -f $clock.Elapsed.TotalSeconds.ToString('0.0', [cultureinfo]::InvariantCulture) }

# The tree as this check reads it: the working tree's tracked and unignored files, written as a
# tree from a copy of the index, then the index itself, which the Markdown is read from. Empty
# where git cannot say, as outside a repository or with a changed file it cannot read, and then
# no pass is recorded or skipped.
function Get-CheckedTree {
    param([Parameter(Mandatory)] [string] $Root)
    $index = git -C $Root rev-parse --path-format=absolute --git-path index 2>$null
    if ($LASTEXITCODE) { return '' }
    $copy = New-TemporaryFile
    $was = $env:GIT_INDEX_FILE
    try {
        # With no index yet, git makes one; an empty file it would refuse.
        if (Test-Path -LiteralPath $index) { Copy-Item -LiteralPath $index -Destination $copy -Force } else { Remove-Item -LiteralPath $copy }
        $env:GIT_INDEX_FILE = $copy.FullName
        git -C $Root add -A 2>$null
        if ($LASTEXITCODE) { return '' }
        $work = git -C $Root write-tree 2>$null
        if ($LASTEXITCODE) { return '' }
        $env:GIT_INDEX_FILE = $was
        $staged = git -C $Root write-tree 2>$null
        if ($LASTEXITCODE) { return '' }
        "$work $staged"
    }
    finally { $env:GIT_INDEX_FILE = $was; Remove-Item -LiteralPath $copy -Force -ErrorAction SilentlyContinue }
}

# The record's trees and time, or nothing: no file, or one that does not hold all three, such as
# the empty file a cut-off write leaves, is no record.
function Read-PassRecord {
    param([string] $Record)
    if (-not $Record -or -not (Test-Path -LiteralPath $Record)) { return $null }
    $parts = @("$(Get-Content -LiteralPath $Record -Raw)".Trim() -split ' ', 3)
    if ($parts.Count -lt 3) { return $null }
    @{ Tree = "$($parts[0]) $($parts[1])"; Working = $parts[0]; Index = $parts[1]; At = $parts[2] }
}

# Whether the tree now differs from $Tree, taken at the start of a run, and the paths that differ:
# the working tree pair and the index pair, each path once. The tree ids decide; the paths only
# name the change, and are none where git cannot diff the trees, as when the start tree's objects
# were pruned. Compared is false where either tree is empty, as git could write none.
function Get-TreeChange {
    param([string] $Root, [string] $Tree)
    $now = if ($Tree) { Get-CheckedTree -Root $Root }
    if (-not $now) { return @{ Compared = $false; Changed = $false; Paths = @() } }
    if ($now -eq $Tree) { return @{ Compared = $true; Changed = $false; Paths = @() } }
    $was = $Tree.Split(' '); $is = $now.Split(' ')
    $paths = foreach ($i in 0, 1) { git -C $Root -c core.quotePath=false diff-tree -r --name-only $was[$i] $is[$i] 2>$null }
    @{ Compared = $true; Changed = $true; Paths = @($paths | Where-Object { $_ } | Sort-Object -Unique) }
}

# The end of a run, as its exit code and the lines it prints. A tree changed since $Tree, the tree
# at the start, is a failure beside $Failed, naming each changed path. A failed run deletes the
# record, and so does one where no tree could be compared, which says so; a pass records $Tree.
function Complete-Run {
    param([string] $Root, [string] $Record, [string] $Tree, [string[]] $Failed, [string] $Pass)
    $failures = @($Failed | Where-Object { $_ })
    $lines = @()
    $change = Get-TreeChange -Root $Root -Tree $Tree
    if (-not $change.Compared) {
        $lines += 'check: git could write no tree at the start or the end of the run, so the tree was not compared and nothing is recorded for -SkipIfPassed.'
    }
    elseif ($change.Changed) {
        $failures += $change.Paths ? "the tree changed while it was read: $($change.Paths -join ', ')" : 'the tree changed while it was read, and git could not name the paths'
    }
    # A failed run, and one that compared nothing, leave no record, not even an earlier pass's.
    if ($Record -and ($failures -or -not $change.Compared)) { Remove-Item -LiteralPath $Record -Force -ErrorAction SilentlyContinue }
    if ($failures) { return @{ Code = 1; Lines = $lines + "FAILED - check: $($failures -join '; ')." } }
    if ($Record -and $change.Compared) {
        Set-Content -LiteralPath $Record -Value "$Tree $([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ', [cultureinfo]::InvariantCulture))"
    }
    @{ Code = 0; Lines = $lines + $Pass }
}

# A blob's text exactly as git stores it, line endings and all, or $null where git cannot read it.
function Read-Blob {
    param([string] $Root, [string] $Id)
    $start = [Diagnostics.ProcessStartInfo]::new('git')
    foreach ($a in '-C', $Root, 'cat-file', 'blob', $Id) { $start.ArgumentList.Add($a) }
    $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true; $start.UseShellExecute = $false
    $start.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $git = [Diagnostics.Process]::Start($start)
    $errors = $git.StandardError.ReadToEndAsync()
    $text = $git.StandardOutput.ReadToEnd()
    $git.WaitForExit(); [void] $errors.Result
    if ($git.ExitCode) { $null } else { $text }
}

# A script's tokens as the parser gives them, comments and line breaks included, each by its kind
# and its text: two scripts whose keys are equal differ at most in the whitespace between tokens
# on a line, as every line break is a NewLine token or inside one's text.
function Get-TokenKey {
    param([AllowEmptyString()] [string] $Text)
    $tokens = $null; $errors = $null
    [void] [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref] $tokens, [ref] $errors)
    @($tokens | ForEach-Object { "$($_.Kind) $($_.Text)" }) -join "`n"
}

# The scripts that differ between the tree pairs $From, the recorded pass's, and $To, this run's,
# where each differs only in whitespace between its tokens (#405): a .ps1 modified in place in
# the working tree pair, the index pair or both, with the same token key before and after. None
# where the pairs are the same, or where any other path differs, a .ps1 is added, deleted or
# changes mode, or git cannot read a tree or a blob: then the whole check runs.
function Get-TokenOnlyChange {
    param([string] $Root, [string] $From, [string] $To)
    if (-not $From -or -not $To -or $From -eq $To) { return @() }
    $was = $From.Split(' '); $is = $To.Split(' ')
    $files = [System.Collections.Generic.List[string]]::new()
    foreach ($i in 0, 1) {
        if ($was[$i] -eq $is[$i]) { continue }
        $raw = @(git -C $Root -c core.quotePath=false diff-tree -r --no-renames $was[$i] $is[$i] 2>$null)
        if ($LASTEXITCODE) { return @() }
        foreach ($line in $raw) {
            # An added or deleted .ps1 has mode 000000 on one side, so it is refused here as a mode
            # change is; a blob git cannot read, as after a prune, is refused below.
            if ($line -cnotmatch '^:(\d+) (\d+) ([0-9a-f]+) ([0-9a-f]+) [A-Z]\t(.+\.ps1)$' -or $Matches[1] -ne $Matches[2]) { return @() }
            $path = $Matches[5]
            $before = Read-Blob -Root $Root -Id $Matches[3]; $after = Read-Blob -Root $Root -Id $Matches[4]
            if ($null -eq $before -or $null -eq $after -or (Get-TokenKey $before) -cne (Get-TokenKey $after)) { return @() }
            if (-not $files.Contains($path)) { $files.Add($path) }
        }
    }
    @($files | Sort-Object { $_ })
}

# What a run runs. On a tree whose only change since the recorded pass is whitespace between
# tokens (#405), the parse and the width check, the Markdown and page checks and each tool step
# that does not read the parsed scripts; not the steps that do, the README's reading of their
# parameters, or the self-tests.
function Get-RunPlan {
    param([object[]] $Steps, [switch] $TokensOnly)
    @{ Scripts = $true; Steps = @($Steps | Where-Object { -not ($TokensOnly -and $_.Parsed) }); Readme = -not $TokensOnly; SelfTests = -not $TokensOnly }
}

# What a run does, from $Passed, the record -SkipIfPassed read or nothing, and $Tree, this tree:
# Skip, the line of a run that runs nothing, where the tree is the one that passed. Else Files,
# the .ps1 files whose only change since the pass is whitespace between tokens (#405), Notice,
# the line naming them, Plan, by Get-RunPlan, and Pass, the line a pass ends with.
function Get-RunStart {
    param([string] $Root, [hashtable] $Passed, [string] $Tree, [object[]] $Steps)
    if ($Passed -and $Passed.Tree -eq $Tree) {
        return @{ Skip = "OK - check skipped: this tree (working $($Passed.Working), index $($Passed.Index)) passed it at $($Passed.At). Nothing was run." }
    }
    $files = if ($Passed) { @(Get-TokenOnlyChange -Root $Root -From $Passed.Tree -To $Tree) } else { @() }
    $notice = if ($files) {
        "check: since the tree that passed at $($Passed.At) (working $($Passed.Working), index $($Passed.Index)), only whitespace between " +
        "tokens changed, in $($files -join ', '). The self-tests, the checks that read the parsed scripts and README's reading of their " +
        'parameters are not run; the rest is.'
    }
    $pass = if ($files) { "OK - check passed, with no self-test run: only whitespace between tokens changed since the tree that passed at $($Passed.At)." }
        else { "OK - check passed. Not run, because each needs the game: -SelfTest of $($NEEDS_GAME -join ', '); of $($NO_GAME_CASES -join ', '), only the cases that need no game ran." }
    @{ Skip = $null; Files = $files; Notice = $notice; Plan = Get-RunPlan -Steps $Steps -TokensOnly:([bool] $files); Pass = $pass }
}

# Runs what $Plan names, in a run's order, each part by its block in $Do: Scripts, the parse and
# the width check; Step, given each of the plan's steps; Readme; SelfTests. What a block returns
# is its failures, each added to $Failed.
function Invoke-RunPlan {
    param([hashtable] $Plan, [hashtable] $Do, [System.Collections.Generic.List[string]] $Failed)
    if ($Plan.Scripts) { foreach ($f in & $Do.Scripts) { $Failed.Add($f) } }
    foreach ($step in $Plan.Steps) { foreach ($f in & $Do.Step $step) { $Failed.Add($f) } }
    if ($Plan.Readme) { foreach ($f in & $Do.Readme) { $Failed.Add($f) } }
    if ($Plan.SelfTests) { foreach ($f in & $Do.SelfTests) { $Failed.Add($f) } }
}

# One of $TOOL_STEPS run from $Root, with $Folder its scripts' folder, its line printed with $Took
# after it; returns its failure, or nothing.
function Invoke-ToolStep {
    param([string] $Root, [string] $Folder, [hashtable] $Step, [scriptblock] $Took = { '' })
    $name = [IO.Path]::GetFileNameWithoutExtension($Step.Script)
    Push-Location $Root
    try { $said = & pwsh -NoProfile -File (Join-Path $Folder $Step.Script) @($Step.Args) 2>&1 | Out-String; $code = $LASTEXITCODE } finally { Pop-Location }
    $bad = $code -or $said -notmatch "(?m)^OK - $([regex]::Escape($name)): "
    Write-Host "check: $($Step.Script) $($Step.Args -join ' ') -- $($bad ? 'FAILED' : 'ok') $(& $Took)"
    if ($bad) {
        $said.TrimEnd() -split "`n" | ForEach-Object { Write-Host "    $_" }
        $Step.Failure
    }
}

# Get-LongCommentLine, the width rule, lives where comment-line-check.ps1 loads it too.
. "$PSScriptRoot/comment-line-lib.ps1"

# Whether a self-test's output says it ran no case: it never says `self-test`, or it passed
# with 0 cases, all of them or 0 of some.
function Test-RanNoCase {
    param([string] $Said)
    $Said -notmatch 'self-test' -or $Said -match '(?m)^OK - self-test passed: (all )?0 (of \d+ )?cases?\b'
}

# What is wrong with how a script stands in the lists: a -SelfTest in none of them, read from the
# text, or a -NoGame in the script's own param block that $NO_GAME_CASES does not name.
function Get-ListProblem {
    param([string] $Name, [string] $Text, [string[]] $SelfTests, [string[]] $NeedsGame, [string[]] $NoGameCases)
    if ($Text -match '\[switch\]\s*\$SelfTest|\$args -contains ''-SelfTest''' -and $Name -notin $SelfTests + $NeedsGame) {
        "$Name has a -SelfTest that is neither run here nor named as needing the game"
    }
    # The script's own param block, so the name in a string or a function's block is not read.
    $own = [Management.Automation.Language.Parser]::ParseInput($Text, [ref] $null, [ref] $null).ParamBlock
    if ($own -and $own.Parameters.Name.VariablePath.UserPath -contains 'NoGame' -and $Name -notin $NoGameCases) {
        "$Name declares -NoGame and is not in `$NO_GAME_CASES, so its no-game cases are not run"
    }
}

# What is wrong with one script: how it stands in the lists, and its comment lines over the limit.
function Get-ScriptProblem {
    param([string] $Path, [int] $Limit, [string[]] $SelfTests, [string[]] $NeedsGame, [string[]] $NoGameCases)
    $name = Split-Path -Leaf $Path
    Get-ListProblem -Name $name -Text (Get-Content -LiteralPath $Path -Raw) -SelfTests $SelfTests -NeedsGame $NeedsGame -NoGameCases $NoGameCases
    $long = @(Get-LongCommentLine -Path $Path -Limit $Limit)
    if ($long) { "$name has comment lines over $Limit characters, line $($long -join ', ')" }
}

# What is wrong with one self-test's run: it exited other than 0; its last summary line, one
# opening `OK - self-test` or `FAILED - self-test` as revert-run.ps1 reads it, is missing or is
# FAILED (#297); or it said it ran no case.
function Get-RunProblem {
    param([string] $Run, [int] $ExitCode, [string] $Said)
    $summary = @([regex]::Matches($Said, '(?m)^(OK|FAILED) - self-test') | ForEach-Object { $_.Groups[1].Value })
    if ($ExitCode) { "$Run exited $ExitCode" }
    elseif (-not $summary) { "$Run printed no OK - self-test or FAILED - self-test line" }
    elseif ($summary[-1] -eq 'FAILED') { "$Run said FAILED - self-test and exited 0" }
    elseif (Test-RanNoCase $Said) { "$Run ran no case" }
}

# Each script in $Folder parsed and judged by Get-ScriptProblem, a line printed for each; returns
# what failed.
function Test-ScriptFolder {
    param([string] $Folder, [int] $Limit, [string[]] $SelfTests, [string[]] $NeedsGame, [string[]] $NoGameCases)
    foreach ($script in Get-ChildItem -LiteralPath $Folder -Filter *.ps1 | Sort-Object Name) {
        $errors = $null
        [void] [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref] $null, [ref] $errors)
        Write-Host "check: $($script.Name) parses -- $($errors ? 'FAILED' : 'ok')"
        foreach ($e in $errors) { Write-Host "    line $($e.Extent.StartLineNumber): $($e.Message)" }
        if ($errors) { "$($script.Name) does not parse" }

        foreach ($problem in Get-ScriptProblem -Path $script.FullName -Limit $Limit -SelfTests $SelfTests -NeedsGame $NeedsGame -NoGameCases $NoGameCases) {
            Write-Host "check: $problem -- FAILED"
            $problem
        }
    }
}

# Each top-level parameter of a script in $Folder that $Readme never names as -<Name>, in case and
# up to a word boundary, as "<script> -<Name> is not named in README.md"; a README not there is one.
function Get-ReadmeProblem {
    param([string] $Folder, [string] $Readme)
    if (-not (Test-Path -LiteralPath $Readme -PathType Leaf)) { return "$Readme is not there, so no script parameter was checked against it" }
    $text = Get-Content -LiteralPath $Readme -Raw
    foreach ($script in Get-ChildItem -LiteralPath $Folder -Filter *.ps1 | Sort-Object Name) {
        $block = [Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref] $null, [ref] $null).ParamBlock
        foreach ($name in @($block.Parameters.Name.VariablePath.UserPath | Where-Object { $_ })) {
            if ($text -cnotmatch ('-' + [regex]::Escape($name) + '\b')) { "$($script.Name) -$name is not named in $(Split-Path -Leaf $Readme)" }
        }
    }
}

# -SelfTest of each of $SelfTests and -SelfTest -NoGame of each of $NoGameCases in $Folder, each in
# a pwsh of its own and all at once (#296), judged by Get-RunProblem; once all have finished, a
# line for each, with its own time, in list order; returns what failed.
function Invoke-SelfTestRun {
    param([string] $Folder, [string[]] $SelfTests, [string[]] $NoGameCases,
          [int] $ThrottleLimit = [Math]::Max(2, [Math]::Min(4, [Environment]::ProcessorCount)))
    $runs = @(@($SelfTests | Where-Object { $_ } | ForEach-Object { , @($_, '-SelfTest') }) +
              @($NoGameCases | Where-Object { $_ } | ForEach-Object { , @($_, '-SelfTest', '-NoGame') }))
    if (-not $runs) { return }
    $done = @(0..($runs.Count - 1) | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
        $name = ($using:runs)[$_][0]; $switches = @(($using:runs)[$_] | Select-Object -Skip 1)
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $said = & pwsh -NoProfile -File (Join-Path $using:Folder $name) @switches 2>&1 | Out-String
        @{ Index = $_; Run = "$name $switches"; Code = $LASTEXITCODE; Said = $said; Seconds = $clock.Elapsed.TotalSeconds }
    }) | Sort-Object { $_.Index }
    foreach ($run in $done) {
        # Exit 0 having run no case is not a pass: mod-info.ps1 has no param block, so it would
        # take a -SelfTest it no longer answers in silence, and a broken -NoGame passed with all 0
        # cases.
        $problem = Get-RunProblem -Run $run.Run -ExitCode $run.Code -Said $run.Said
        $time = '({0}s)' -f $run.Seconds.ToString('0.0', [cultureinfo]::InvariantCulture)
        Write-Host "check: $($run.Run) -- $($problem ? 'FAILED' : 'ok') $time"
        if ($problem) {
            $run.Said.TrimEnd() -split "`n" | ForEach-Object { Write-Host "    $_" }
            $problem
        }
    }
}

if ($SelfTest) {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "check-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    $repo = Join-Path $temp 'repo'; $outside = Join-Path $temp 'outside'; $rec = Join-Path $temp 'check-passed'
    New-Item -ItemType Directory -Path $repo, $outside -Force | Out-Null
    $file = { param($name, $text) Set-Content -LiteralPath (Join-Path $repo $name) -Value $text }
    try {
        git -C $repo init --quiet; if ($LASTEXITCODE) { throw 'git init failed; the self-test needs git.' }
        & $file '.gitignore' 'ignored.txt'; & $file 'a.txt' 'one'
        git -C $repo add -A
        $base = Get-CheckedTree -Root $repo
        $changed = {
            param([scriptblock] $Change, [scriptblock] $Undo)
            & $Change; $t = Get-CheckedTree -Root $repo; & $Undo
            $t -and $t -ne $base
        }
        # Get-TokenOnlyChange from the tree with $Before's files, added to the index, to the one
        # with $After's written over them, and those in $Stage added to the index too; every
        # file is then taken out again.
        $tokenRun = {
            param([hashtable] $Before, [hashtable] $After, [string[]] $Stage = @())
            foreach ($k in $Before.Keys) { [IO.File]::WriteAllText((Join-Path $repo $k), $Before[$k]) }
            git -C $repo add -- @($Before.Keys)
            $from = Get-CheckedTree -Root $repo
            foreach ($k in $After.Keys) { [IO.File]::WriteAllText((Join-Path $repo $k), $After[$k]) }
            foreach ($k in $Stage) { [IO.File]::WriteAllText((Join-Path $repo $k), $Before[$k].Replace('{ ', '{    ')); git -C $repo add -- $k }
            try { @(Get-TokenOnlyChange -Root $repo -From $from -To (Get-CheckedTree -Root $repo)) }
            finally {
                $all = @($Before.Keys) + @($After.Keys) | Sort-Object -Unique
                git -C $repo rm --cached --quiet --ignore-unmatch -- @($all)
                foreach ($k in $all) { Remove-Item -LiteralPath (Join-Path $repo $k) -ErrorAction SilentlyContinue }
            }
        }
        $cases = [ordered]@{
            'a pass over an unchanged tree exits 0 and records the tree, which reads back as that tree' = {
                $end = Complete-Run -Root $repo -Record $rec -Tree $base -Pass 'OK - passed'
                $base -and $end.Code -eq 0 -and ($end.Lines -join '|') -eq 'OK - passed' -and
                    (Read-PassRecord $rec).Tree -eq $base -and (Get-CheckedTree -Root $repo) -eq $base }
            'an unstaged edit, an untracked file and a staged-only change each make another tree; an ignored file does not' = {
                $edit = & $changed { & $file 'a.txt' 'two' } { & $file 'a.txt' 'one' }
                $new = & $changed { & $file 'b.txt' 'new' } { Remove-Item -LiteralPath (Join-Path $repo 'b.txt') }
                $staged = & $changed { & $file 'a.txt' 'two'; git -C $repo add a.txt; & $file 'a.txt' 'one' } { git -C $repo add a.txt }
                & $file 'ignored.txt' 'x'; $ignored = (Get-CheckedTree -Root $repo) -eq $base; Remove-Item -LiteralPath (Join-Path $repo 'ignored.txt')
                $edit -and $new -and $staged -and $ignored -and (Get-CheckedTree -Root $repo) -eq $base }
            'a failed run exits 1, names its failure and deletes the record' = {
                Complete-Run -Root $repo -Record $rec -Tree $base -Pass 'OK' | Out-Null
                $end = Complete-Run -Root $repo -Record $rec -Tree $base -Failed 'x broke' -Pass 'OK'
                $end.Code -eq 1 -and $end.Lines[-1] -eq 'FAILED - check: x broke.' -and -not (Test-Path -LiteralPath $rec) }
            'a tree changed while it was read fails the run and names each changed path once (#366)' = {
                Complete-Run -Root $repo -Record $rec -Tree $base -Pass 'OK' | Out-Null
                # a.txt differs in the working tree and in the index; b.txt is new in the working
                # tree only; c.txt is staged and gone from the working tree, so in the index only.
                & $file 'a.txt' 'two'; git -C $repo add a.txt; & $file 'a.txt' 'three'; & $file 'b.txt' 'new'
                & $file 'c.txt' 'staged'; git -C $repo add c.txt; Remove-Item -LiteralPath (Join-Path $repo 'c.txt')
                try {
                    $alone = Complete-Run -Root $repo -Record $rec -Tree $base -Pass 'OK'
                    $also = Complete-Run -Root $repo -Record $rec -Tree $base -Failed 'x broke' -Pass 'OK'
                    # The old guard compared only where there was a record path (#366).
                    $none = Complete-Run -Root $repo -Record '' -Tree $base -Pass 'OK'
                }
                finally {
                    & $file 'a.txt' 'one'; git -C $repo add a.txt; git -C $repo rm --cached --quiet c.txt
                    Remove-Item -LiteralPath (Join-Path $repo 'b.txt')
                }
                $said = 'the tree changed while it was read: a.txt, b.txt, c.txt'
                $alone.Code -eq 1 -and $alone.Lines[-1] -eq "FAILED - check: $said." -and
                    $also.Code -eq 1 -and $also.Lines[-1] -eq "FAILED - check: x broke; $said." -and
                    $none.Code -eq 1 -and $none.Lines[-1] -eq "FAILED - check: $said." -and
                    -not (Test-Path -LiteralPath $rec) -and (Get-CheckedTree -Root $repo) -eq $base }
            'a start tree git cannot read back still fails the run, which says the paths could not be named' = {
                # As after a prune of the start tree's objects mid-run.
                $end = Complete-Run -Root $repo -Record $rec -Tree "$('1' * 40) $('2' * 40)" -Pass 'OK'
                $end.Code -eq 1 -and $end.Lines[-1] -eq 'FAILED - check: the tree changed while it was read, and git could not name the paths.' -and
                    -not (Test-Path -LiteralPath $rec) }
            'an empty record, or one cut short, is no record, and reading it throws nothing' = {
                Set-Content -LiteralPath $rec -Value '' -NoNewline; $empty = Read-PassRecord $rec
                Set-Content -LiteralPath $rec -Value $base.Split(' ')[0]; $short = Read-PassRecord $rec
                Remove-Item -LiteralPath $rec
                $null -eq $empty -and $null -eq $short -and $null -eq (Read-PassRecord $rec) }
            'a changed file git cannot read, and a directory outside a repository, make no tree; a run with none, at its start or its end, is not compared and keeps no record' = {
                # A record of an earlier pass, each time, so that one kept or written is seen.
                $seed = { Set-Content -LiteralPath $rec -Value "$base 2026-01-01T00:00:00Z" }
                $path = Join-Path $repo 'a.txt'; & $file 'a.txt' 'two'
                # Locked on Windows; unreadable elsewhere, which needs a user other than root.
                $lock = if ($IsWindows) { [IO.File]::Open($path, 'Open', 'Read', 'None') } else { chmod 000 $path; $null }
                try {
                    $unread = Get-CheckedTree -Root $repo
                    & $seed; $atEnd = Complete-Run -Root $repo -Record $rec -Tree $base -Pass 'OK'
                    $keptAtEnd = Test-Path -LiteralPath $rec
                }
                finally { if ($lock) { $lock.Dispose() } else { chmod 644 $path } }
                & $file 'a.txt' 'one'
                & $seed; $atStart = Complete-Run -Root $repo -Record $rec -Tree '' -Pass 'OK'
                $keptAtStart = Test-Path -LiteralPath $rec
                $notCompared = { param($end) $end.Code -eq 0 -and ($end.Lines -join '|') -match '^check: [^|]*not compared[^|]*\|OK$' }
                # Said once, and of the run, not of a pass, where the run failed too.
                $failedToo = Complete-Run -Root $repo -Record $rec -Tree '' -Failed 'x broke' -Pass 'OK'
                $unread -eq '' -and (Get-CheckedTree -Root $outside) -eq '' -and
                    (& $notCompared $atEnd) -and (& $notCompared $atStart) -and -not $keptAtEnd -and -not $keptAtStart -and
                    $failedToo.Code -eq 1 -and $failedToo.Lines[0] -match 'not compared' -and $failedToo.Lines[0] -notmatch 'this pass' -and $failedToo.Lines[-1] -eq 'FAILED - check: x broke.' }
            'a comment or header line over the limit is named; code, a here-string, .EXAMPLE and an address are not' = {
                $long = 'word ' * 20 + 'x'; $script = Join-Path $outside 'long.ps1'
                Set-Content -LiteralPath $script -Value @(
                    '<#', '.SYNOPSIS', "    $long", '.EXAMPLE', "    $long", '.NOTES', "    $long", '#>',
                    "# $long", "`$a = '$long'", "`$b = 1 # $long", "`$c = @'", "# $long", "'@", "    # $('y' * 94)",
                    "<#", "    https://example.com/$('x' * 101)", "    two $long", "#>", "#   https://example.com/$('x' * 101)",
                    '<#', '.EXAMPLE', "    $long", '.PARAMETER Name', "    $long", '.NET reads this', "    $long", '#>')
                $got = @(Get-LongCommentLine -Path $script -Limit 100)
                "$got" -eq '3 7 9 18 25 27' }
            'a self-test whose output says it ran no case is not a pass' = {
                (Test-RanNoCase 'OK - self-test passed: all 0 cases.') -and (Test-RanNoCase 'nothing said') -and
                (Test-RanNoCase 'OK - self-test passed: 0 of 2 cases; 2 skipped off Windows') -and
                -not (Test-RanNoCase 'OK - self-test passed: all 10 cases.') -and -not (Test-RanNoCase 'OK - self-test passed.') }
            'a -NoGame not in $NO_GAME_CASES, and a -SelfTest in neither list, are named' = {
                $both = 'param([switch] $SelfTest, [switch] $NoGame)'
                $lists = @{ SelfTests = @('a.ps1'); NeedsGame = @('g.ps1', 'n.ps1'); NoGameCases = @('n.ps1') }
                $unlisted = @(Get-ListProblem -Name 'u.ps1' -Text 'param([switch] $SelfTest)' @lists)
                $noGame = @(Get-ListProblem -Name 'g.ps1' -Text $both @lists)
                # Named only in a string or a function's own param block, as this script names it.
                $quoted = "param([switch] `$SelfTest)`n`$x = '[switch] `$NoGame'`nfunction f { param([switch] `$NoGame) }"
                $unlisted.Count -eq 1 -and $noGame.Count -eq 1 -and $noGame[0] -match 'NoGame' -and
                -not (Get-ListProblem -Name 'a.ps1' -Text $quoted @lists) -and
                -not (Get-ListProblem -Name 'n.ps1' -Text $both @lists) -and -not (Get-ListProblem -Name 'a.ps1' -Text $both.Replace(', [switch] $NoGame', '') @lists) }
            "one script's problems are its list and width problems; one run's is its exit, then no case" = {
                $script = Join-Path $outside 'bad.ps1'
                Set-Content -LiteralPath $script -Value 'param([switch] $SelfTest, [switch] $NoGame)', "# $('word ' * 20)x"
                $bad = @(Get-ScriptProblem -Path $script -Limit 100)
                Set-Content -LiteralPath $script -Value 'param([switch] $SelfTest)', '# short'
                $good = @(Get-ScriptProblem -Path $script -Limit 100 -SelfTests 'bad.ps1')
                $bad.Count -eq 3 -and $bad[2] -eq 'bad.ps1 has comment lines over 100 characters, line 2' -and -not $good -and
                (Get-RunProblem 'x.ps1 -SelfTest' 0 'OK - self-test passed: all 0 cases.') -eq 'x.ps1 -SelfTest ran no case' -and
                (Get-RunProblem 'x.ps1 -SelfTest' 1 'OK - self-test passed: all 3 cases.') -eq 'x.ps1 -SelfTest exited 1' -and
                (Get-RunProblem 'x.ps1 -SelfTest' 1 'ParserError: no case ran') -eq 'x.ps1 -SelfTest exited 1' -and
                -not (Get-RunProblem 'x.ps1 -SelfTest' 0 'OK - self-test passed: all 3 cases.') }
            'a run with no summary line, or whose last one says FAILED with exit 0, is not a pass (#297)' = {
                (Get-RunProblem 'x.ps1 -SelfTest' 0 "self-test: a case -- ok`nx: 3 checks, 0 failures.") -eq
                    'x.ps1 -SelfTest printed no OK - self-test or FAILED - self-test line' -and
                (Get-RunProblem 'x.ps1 -SelfTest' 0 "OK - self-test passed: all 3 cases.`nFAILED - self-test: 1 of 3 case(s) did not hold.") -eq
                    'x.ps1 -SelfTest said FAILED - self-test and exited 0' -and
                # The last line rules: a FAILED line before the run's own OK is not the run's.
                # A line that quotes one past its start is not one.
                -not (Get-RunProblem 'x.ps1 -SelfTest' 0 ("    FAILED - self-test: a child's.`nFAILED - self-test: 1 of 1`n" +
                    "OK - self-test passed: all 3 cases.`nthe child said FAILED - self-test: 1 of 1")) }
            "a folder's scripts and self-tests are each judged, against the lists the run is given" = {
                $folder = Join-Path $outside 'scripts'; New-Item -ItemType Directory -Path $folder | Out-Null
                $say = { param($name, [string[]] $text) Set-Content -LiteralPath (Join-Path $folder $name) -Value $text }
                $pass = "'OK - self-test passed: all 1 cases.'"
                & $say 'bad.ps1' 'param([switch] $SelfTest, [switch] $NoGame)', "# $('word ' * 20)x", "'OK - self-test passed: all 0 cases.'"
                & $say 'broken.ps1' 'if ('
                & $say 'crash.ps1' 'param([switch] $SelfTest)', 'exit 3'
                # Passes only when run without -NoGame, so its no-game run is told from no run.
                & $say 'game.ps1' 'param([switch] $SelfTest, [switch] $NoGame)', 'if ($NoGame) { exit 4 }', $pass
                & $say 'good.ps1' 'param([switch] $SelfTest)', $pass
                $lists = @{ SelfTests = 'bad.ps1', 'crash.ps1', 'good.ps1'; NoGameCases = @('game.ps1') }
                # Their lines go to the host; only what failed is kept.
                $scripts = @(Test-ScriptFolder -Folder $folder -Limit 100 -NeedsGame 'game.ps1' @lists 6>$null)
                $runs = @(Invoke-SelfTestRun -Folder $folder @lists 6>$null)
                ($scripts -join '|') -eq ('bad.ps1 declares -NoGame and is not in $NO_GAME_CASES, so its no-game cases are not run|' +
                    'bad.ps1 has comment lines over 100 characters, line 2|broken.ps1 does not parse') -and
                ($runs -join '|') -eq 'bad.ps1 -SelfTest ran no case|crash.ps1 -SelfTest exited 3|game.ps1 -SelfTest -NoGame exited 4' }
            # PARALLEL (#296): the slow run is first and finishes last, so a line printed as each
            # run finishes is out of list order; and two runs that each sleep finish in less than
            # the sum of their own times.
            'the self-tests run at once, and are printed and returned in list order, a failure with its output' = {
                $folder = Join-Path $outside 'parallel'; New-Item -ItemType Directory -Path $folder | Out-Null
                $say = { param($name, [string[]] $text) Set-Content -LiteralPath (Join-Path $folder $name) -Value $text }
                $pass = "'OK - self-test passed: all 1 cases.'"
                & $say 'slow.ps1' 'param([switch] $SelfTest)', 'Start-Sleep -Seconds 3', $pass
                & $say 'fail.ps1' 'param([switch] $SelfTest)', "'boom from fail'", 'exit 1'
                & $say 'quick.ps1' 'param([switch] $SelfTest)', $pass
                $out = @(Invoke-SelfTestRun -Folder $folder -SelfTests 'slow.ps1', 'fail.ps1', 'quick.ps1' 6>&1)
                $lines = @($out | Where-Object { $_ -is [Management.Automation.InformationRecord] } | ForEach-Object { "$_" })
                $returned = @($out | Where-Object { $_ -is [string] })
                $order = @($lines | Where-Object { $_ -match '^check: ' } | ForEach-Object { ($_ -split ' ')[1] })
                $boom = [array]::IndexOf($lines, '    boom from fail')
                ($order -join ' ') -eq 'slow.ps1 fail.ps1 quick.ps1' -and $boom -gt 0 -and
                $lines[$boom - 1] -match '^check: fail\.ps1 -SelfTest -- FAILED' -and ($returned -join '|') -eq 'fail.ps1 -SelfTest exited 1' }
            'a run of only -NoGame cases runs those alone, and a run of none runs nothing' = {
                $folder = Join-Path $outside 'lists'; New-Item -ItemType Directory -Path $folder | Out-Null
                Set-Content -LiteralPath (Join-Path $folder 'n.ps1') -Value 'param([switch] $SelfTest, [switch] $NoGame)',
                    "if (-not `$NoGame) { exit 5 }", "'OK - self-test passed: all 1 cases.'"
                $only = @(Invoke-SelfTestRun -Folder $folder -NoGameCases 'n.ps1' 6>&1 | ForEach-Object { "$_" })
                $none = @(Invoke-SelfTestRun -Folder $folder 6>&1)
                ($only -join '|') -match '^check: n\.ps1 -SelfTest -NoGame -- ok \([\d.]+s\)$' -and $none.Count -eq 0 }
            'two runs that each sleep finish in less time than their own times summed' = {
                $folder = Join-Path $outside 'overlap'; New-Item -ItemType Directory -Path $folder | Out-Null
                foreach ($name in 'a.ps1', 'b.ps1') {
                    Set-Content -LiteralPath (Join-Path $folder $name) -Value 'param([switch] $SelfTest)', 'Start-Sleep -Seconds 2',
                        "'OK - self-test passed: all 1 cases.'"
                }
                $wall = [Diagnostics.Stopwatch]::StartNew()
                $lines = @(Invoke-SelfTestRun -Folder $folder -SelfTests 'a.ps1', 'b.ps1' 6>&1 | ForEach-Object { "$_" })
                $wall.Stop()
                $own = ($lines | Where-Object { $_ -match '^check: .* -- ok \(([\d.]+)s\)$' } | ForEach-Object {
                    [double] ($_ -replace '^.*\(([\d.]+)s\)$', '$1') } | Measure-Object -Sum)
                $own.Count -eq 2 -and $wall.Elapsed.TotalSeconds -lt $own.Sum }
            'a script parameter README never names as -Name is named; one it names, and a function''s, are not; no README fails' = {
                $folder = Join-Path $outside 'readme'; New-Item -ItemType Directory -Path $folder | Out-Null
                Set-Content -LiteralPath (Join-Path $folder 'p.ps1') -Value 'param([string] $Named, [switch] $Unnamed, [int] $NamedLonger)', 'function f { param($Inner) }'
                $readme = Join-Path $outside 'README.md'
                Set-Content -LiteralPath $readme -Value 'Pass -Named, and -NamedLong is another word. Unnamed alone is no flag; -inner is not -Inner.'
                $got = @(Get-ReadmeProblem -Folder $folder -Readme $readme)
                $none = @(Get-ReadmeProblem -Folder $folder -Readme (Join-Path $outside 'no-README.md'))
                ($got -join '|') -eq 'p.ps1 -Unnamed is not named in README.md|p.ps1 -NamedLonger is not named in README.md' -and
                    $none.Count -eq 1 -and $none[0] -match 'no-README\.md is not there' }
            'line-cite-check.ps1 runs over the tree with CI''s floors, on every run, and a tool step that fails, or prints no OK line, fails the run (#404)' = {
                $cite = @($TOOL_STEPS | Where-Object { $_.Script -eq 'line-cite-check.ps1' })
                $full = Get-RunPlan -Steps $TOOL_STEPS; $skip = Get-RunPlan -Steps $TOOL_STEPS -TokensOnly
                $folder = Join-Path $outside 'tools'; New-Item -ItemType Directory -Path $folder | Out-Null
                Set-Content -LiteralPath (Join-Path $folder 'good-x.ps1') -Value "'OK - good-x: fine.'"
                Set-Content -LiteralPath (Join-Path $folder 'bad-x.ps1') -Value "'OK - bad-x: it says so.'", 'exit 1'
                Set-Content -LiteralPath (Join-Path $folder 'mute-x.ps1') -Value "'nothing to say'"
                $got = foreach ($s in 'good-x.ps1', 'bad-x.ps1', 'mute-x.ps1') { Invoke-ToolStep -Root $repo -Folder $folder -Step @{ Script = $s; Args = @(); Failure = "$s failed" } 6>$null }
                $cite.Count -eq 1 -and ($cite[0].Args -join ' ') -ceq '-MinCitations 50 -MinContinuations 4' -and
                    @($full.Steps | Where-Object { $_.Script -eq 'line-cite-check.ps1' }).Count -eq 1 -and @($skip.Steps | Where-Object { $_.Script -eq 'line-cite-check.ps1' }).Count -eq 1 -and
                    ($got -join '|') -ceq 'bad-x.ps1 failed|mute-x.ps1 failed' }
            'a tree whose only change since the pass is whitespace between tokens in a .ps1 names the file, and its plan runs no self-test and no step that reads the parsed scripts (#405)' = {
                $script = "param([switch] `$SelfTest)`n# A comment.`nif (`$SelfTest) { `$a = 1 }`n"
                $spaced = "param( [switch]  `$SelfTest )`n# A comment.`nif (`$SelfTest)   {  `$a = 1 }`n"
                $got = & $tokenRun @{ 's.ps1' = $script; 't.ps1' = $script } @{ 's.ps1' = $spaced } -Stage 't.ps1'
                $plan = Get-RunPlan -Steps $TOOL_STEPS -TokensOnly
                ($got -join '|') -ceq 's.ps1|t.ps1' -and $plan.Scripts -and -not $plan.SelfTests -and -not $plan.Readme -and
                    -not @($plan.Steps | Where-Object { $_.Parsed }) -and @($plan.Steps).Count -eq @($TOOL_STEPS | Where-Object { -not $_.Parsed }).Count }
            'a changed token, comment or line count, an added .ps1 or any other changed file runs the whole check (#405)' = {
                $script = "param([switch] `$SelfTest)`n# A comment.`nif (`$SelfTest) { `$a = 1 }`n"
                $spaced = $script.Replace('{ $a', '{   $a')
                $runs = @(
                    (& $tokenRun @{ 's.ps1' = $script } @{ 's.ps1' = $script.Replace('$a = 1', '$a = 2') })
                    (& $tokenRun @{ 's.ps1' = $script } @{ 's.ps1' = $script.Replace('# A comment.', '#  A comment.') })
                    (& $tokenRun @{ 's.ps1' = $script } @{ 's.ps1' = $script.Replace("`n# A", "`n`n# A") })
                    (& $tokenRun @{ 's.ps1' = $script } @{ 's.ps1' = $spaced; 'n.ps1' = $script })
                    (& $tokenRun @{ 's.ps1' = $script } @{ 's.ps1' = $spaced; 'e.ps1' = '' })
                    # A Markdown file whose words are only spaced anew would be the same in tokens.
                    (& $tokenRun @{ 's.ps1' = $script; 'n.md' = 'one two' } @{ 's.ps1' = $spaced; 'n.md' = 'one  two' }))
                # A mode changed in the index, both blobs readable and the same in tokens.
                [IO.File]::WriteAllText((Join-Path $repo 'm.ps1'), $script); git -C $repo add m.ps1
                $from = Get-CheckedTree -Root $repo
                git -C $repo update-index --chmod=+x m.ps1
                $mode = @(Get-TokenOnlyChange -Root $repo -From $from -To (Get-CheckedTree -Root $repo))
                git -C $repo rm --cached --quiet m.ps1; Remove-Item -LiteralPath (Join-Path $repo 'm.ps1')
                # Two trees whose s.ps1 is a blob git does not hold, as after a prune: neither
                # side can be read, so none is the same in tokens.
                # Each in an index of its own: a tree piped to mktree here ends in CRLF.
                $gone = foreach ($id in ('1' * 40), ('2' * 40)) {
                    $env:GIT_INDEX_FILE = Join-Path $outside "gone-$id"
                    try { git -C $repo update-index --add --cacheinfo "100644,$id,s.ps1"; git -C $repo write-tree --missing-ok }
                    finally { Remove-Item Env:GIT_INDEX_FILE }
                }
                $pruned = @(Get-TokenOnlyChange -Root $repo -From "$($gone[0]) $($gone[0])" -To "$($gone[1]) $($gone[1])")
                $full = Get-RunPlan -Steps $TOOL_STEPS
                $alone = @(& $tokenRun @{ 's.ps1' = $script } @{ 's.ps1' = $spaced })
                -not @($runs | Where-Object { $_ }) -and -not $mode -and -not $pruned -and $gone.Count -eq 2 -and ($alone -join '|') -ceq 's.ps1' -and $full.SelfTests -and $full.Readme -and $full.Scripts -and
                    @($full.Steps).Count -eq $TOOL_STEPS.Count }
            'a comment line pushed over the width by added indentation is a skip by tokens, and the width check, which still runs, fails it (#405)' = {
                $comment = "# $('word ' * 19)xx"
                $flat = "if (`$a) {`n$comment`n}`n"; $deep = "if (`$a) {`n    $comment`n}`n"
                $got = & $tokenRun @{ 'w.ps1' = $flat } @{ 'w.ps1' = $deep }
                $path = Join-Path $outside 'w.ps1'; [IO.File]::WriteAllText($path, $deep)
                $width = @(Get-ScriptProblem -Path $path -Limit 100)
                ($got -join '|') -ceq 'w.ps1' -and (Get-RunPlan -Steps $TOOL_STEPS -TokensOnly).Scripts -and
                    ($width -join '|') -ceq 'w.ps1 has comment lines over 100 characters, line 2' }
            'a run follows its start: the tree that passed runs nothing; one changed only in whitespace between tokens names its files, runs the parse and width check and the steps that read no parsed script, adds what each returns to the failures, and passes saying no self-test ran; with no record every part runs (#404, #405)' = {
                $script = "param([switch] `$SelfTest)`n# A comment.`nif (`$SelfTest) { `$a = 1 }`n"
                [IO.File]::WriteAllText((Join-Path $repo 'r.ps1'), $script); git -C $repo add r.ps1
                try {
                    $from = Get-CheckedTree -Root $repo
                    $record = @{ Tree = $from; Working = $from.Split(' ')[0]; Index = $from.Split(' ')[1]; At = '2026-11-10T00:00:00Z' }
                    $same = Get-RunStart -Root $repo -Passed $record -Tree $from -Steps $TOOL_STEPS
                    [IO.File]::WriteAllText((Join-Path $repo 'r.ps1'), $script.Replace('{ $a', '{   $a'))
                    $now = Get-CheckedTree -Root $repo
                    $spaced = Get-RunStart -Root $repo -Passed $record -Tree $now -Steps $TOOL_STEPS
                    $none = Get-RunStart -Root $repo -Passed $null -Tree $now -Steps $TOOL_STEPS
                }
                finally { git -C $repo rm --cached --quiet -- r.ps1; Remove-Item -LiteralPath (Join-Path $repo 'r.ps1') }
                # Each block returns its own name as its failure, so the failures are the parts run.
                $do = @{ Scripts = { 'scripts' }; Step = { param($s) $s.Script }; Readme = { 'readme' }; SelfTests = { 'self-tests' } }
                $ran = foreach ($s in $spaced, $none) {
                    $failed = [System.Collections.Generic.List[string]]::new()
                    Invoke-RunPlan -Plan $s.Plan -Do $do -Failed $failed
                    $failed -join '|'
                }
                $same.Skip -ceq "OK - check skipped: this tree (working $($record.Working), index $($record.Index)) passed it at 2026-11-10T00:00:00Z. Nothing was run." -and
                    -not $spaced.Skip -and ($spaced.Files -join '|') -ceq 'r.ps1' -and $spaced.Notice -like '*only whitespace between tokens changed, in r.ps1.*' -and
                    $spaced.Pass -like 'OK - check passed, with no self-test run:*' -and $ran[0] -ceq 'scripts|line-cite-check.ps1' -and
                    -not $none.Skip -and -not $none.Files -and -not $none.Notice -and $none.Pass -like 'OK - check passed. Not run, because each needs the game:*' -and
                    $ran[1] -ceq ((@('scripts') + @($TOOL_STEPS | ForEach-Object { $_.Script }) + @('readme', 'self-tests')) -join '|') }
        }
        $failures = 0; $n = 0
        foreach ($name in $cases.Keys) {
            $n++
            $ok = try { [bool] (& $cases[$name]) } catch { Write-Host "    threw: $($_.Exception.Message)"; $false }
            Write-Host ("self-test {0}/{1}: {2} -- {3}" -f $n, $cases.Count, $name, $(if ($ok) { 'ok' } else { 'FAILED' }))
            if (-not $ok) { $failures++ }
        }
    }
    finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $($cases.Count) case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $($cases.Count) cases."
    exit 0
}

$record = git -C $root rev-parse --path-format=absolute --git-path check-passed 2>$null
$tree = Get-CheckedTree -Root $root
$passed = if ($SkipIfPassed -and $tree) { Read-PassRecord $record }
$start = Get-RunStart -Root $root -Passed $passed -Tree $tree -Steps $TOOL_STEPS
if ($start.Skip) { Write-Host $start.Skip; exit 0 }
if ($start.Notice) { Write-Host $start.Notice }

Invoke-RunPlan -Plan $start.Plan -Failed $failed -Do @{
    Scripts = {
        $clock.Restart()
        Test-ScriptFolder -Folder $PSScriptRoot -Limit $COMMENT_LINE_LIMIT -SelfTests $SELF_TESTS -NeedsGame $NEEDS_GAME -NoGameCases $NO_GAME_CASES
        Write-Host "check: every script parsed $(& $took)"
    }
    # From the root, so each script is named by its path from there.
    Step = { param($step) $clock.Restart(); Invoke-ToolStep -Root $root -Folder $PSScriptRoot -Step $step -Took $took }
    Readme = {
        $clock.Restart()
        $unnamed = @(Get-ReadmeProblem -Folder $PSScriptRoot -Readme (Join-Path $root 'README.md'))
        Write-Host "check: README.md names every script parameter -- $($unnamed ? 'FAILED' : 'ok') $(& $took)"
        foreach ($f in $unnamed) { Write-Host "    $f" }
        $unnamed
    }
    SelfTests = { Invoke-SelfTestRun -Folder $PSScriptRoot -SelfTests $SELF_TESTS -NoGameCases $NO_GAME_CASES }
}

$clock.Restart()
foreach ($page in $PAGE_LIMITS.Keys) {
    $path = Join-Path $root $page
    # A page that is not there fails too: renamed, its limit would otherwise lapse in silence.
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Write-Host "check: $page is not there to measure -- FAILED"
        $failed.Add("$page, which has a size limit, was not found")
        continue
    }
    # Decoded from the bytes, not with ReadAllText, which drops a byte-order mark the file stores.
    $text = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($path))
    $bytes = [Text.Encoding]::UTF8.GetByteCount(($text -replace "`r`n", "`n"))
    $over = $bytes -ge $PAGE_LIMITS[$page]
    Write-Host "check: $page is $bytes bytes, limit $($PAGE_LIMITS[$page]) -- $($over ? 'FAILED' : 'ok')"
    if ($over) { $failed.Add("$page is $bytes bytes and must be under $($PAGE_LIMITS[$page])") }
}

# In the repository root, because the Markdown check reads the repository it stands in. No file
# read is a failure too: a run outside a repository must not pass for having had nothing to read.
$clock.Restart()
Push-Location $root
try { $said = & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'markdown-check.ps1') -All -MaxLineLength $MARKDOWN_LINE_LIMIT 2>&1 | Out-String } finally { Pop-Location }
$bad = $LASTEXITCODE -or $said -notmatch 'markdown-check: [1-9]\d* Markdown file'
Write-Host "check: markdown-check.ps1 -All -MaxLineLength $MARKDOWN_LINE_LIMIT -- $($bad ? 'FAILED' : 'ok') $(& $took)"
if ($bad) {
    $said.TrimEnd() -split "`n" | ForEach-Object { Write-Host "    $_" }
    $failed.Add("markdown-check.ps1 -All -MaxLineLength $MARKDOWN_LINE_LIMIT found something, or read no file")
}
# Shown on a pass too: a pass says nothing of an edit that was not read.
elseif ($said -match '(?ms)^markdown-check: \d+ file\(s\) have unstaged edits.*?(?=^OK - )') { $Matches[0].TrimEnd() -split "`n" | ForEach-Object { Write-Host "    $_" } }

Write-Host ''
# A tree that did not stand still while it was read fails the run, with or without a record:
# an edit during the run means no one tree passed (grado-factorio-tools#366).
$end = Complete-Run -Root $root -Record $record -Tree $tree -Failed $failed -Pass $start.Pass
$end.Lines | ForEach-Object { Write-Host $_ }
exit $end.Code
