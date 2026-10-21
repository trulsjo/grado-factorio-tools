<#
.SYNOPSIS
    Parses every script under scripts/, holds their comment lines to a width, reads their list
    parameters with param-check.ps1, runs every self-test that needs neither the game nor the
    network, holds the agent pages to their size limits, and runs markdown-check.ps1 over the
    tracked Markdown. Exit 0 means all of that held. With -SkipIfPassed, as the pre-push hook runs
    it, exit 0 may instead mean that nothing ran, because a run recorded that this same tree
    passed it; the run then says so.

.DESCRIPTION
    THE ONE COMMAND BEFORE A PUSH (grado-factorio-tools#60). The only gate here was commit-msg,
    which reads a message and no script. Each -SelfTest was run by hand, session by session, and
    review lanes reported more than once that no lane had run them. .githooks/pre-push runs this,
    and so does the workflow in .github/workflows/ on every pull request and on main, on Windows
    and on Linux (grado-factorio-tools#117). Nothing here is left out on either: a self-test
    that cannot pass on one of them fails this check there. What a self-test itself skips off
    Windows, it names.

    WHAT IT RUNS. A parse of each script beside it, which finds a syntax error on a line no
    self-test reaches, and in the libraries that have no self-test. Then param-check.ps1 over the
    same scripts, for a list parameter that `pwsh -File` would hand over as one string
    (grado-factorio-tools#163). Then -SelfTest of each script in $SELF_TESTS, each in a pwsh of
    its own, so one script's `exit` does not end the run, and -SelfTest -NoGame of each in
    $NO_GAME_CASES: the cases of a script that needs the game which read no game's output but a
    log written for them (grado-factorio-tools#175). A self-test that passes prints one line
    here; one that fails prints everything it said. One that exits 0 having run no case fails:
    one that never says `self-test`, or that says it passed with 0 cases, all of them or 0 of
    some, as a -NoGame broken to run nothing would (grado-factorio-tools#181). It reads the
    output, so a self-test that counts a case it did not run is not seen.

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
    counts as two.

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
    Markdown is read as staged. It is recorded only when the tree is the same at the end of the
    run as at the start. A changed file git cannot read makes no tree, so nothing is recorded or
    skipped. A run that ends in FAILED deletes the record; one cut short, by an error or Ctrl-C,
    leaves it. A record that does not hold both trees and a time, such as an empty file, is no
    record. With -SkipIfPassed, as the hook runs it, a tree that matches the record runs nothing,
    and the run says so, naming both trees and when they passed. A skip shows that this same tree
    passed once; it cannot see what is outside the tree: an ignored file, the pwsh or git in use,
    the loopback port fetch-mods.ps1 needs, or a self-test that passes only sometimes. CI runs
    without the switch. -SelfTest holds this against a scratch repository, and this check runs
    it like the others (grado-factorio-tools#176's review); a file made unreadable off Windows
    needs a user other than root.

    HOW LONG IT TAKES ON THE DEVELOPMENT MACHINE DEPENDS ON WHAT ELSE IS RUNNING THERE
    (grado-factorio-tools#70). On a quiet machine it is under twice CI's time; it was reported as
    ten times slower while review lanes and the game were running beside it. No step here carries
    that. Each line prints its seconds so two runs can be compared; the measurement is in
    docs/measurements.md.

.PARAMETER SkipIfPassed
    Run nothing when the record says this tree passed, as above.

.PARAMETER SelfTest
    Run the cases that hold the record and the skip, in a scratch repository, and those that hold
    the functions each script and each self-test's run are judged by, on files outside it, and
    nothing else. The run's loops are not run: a loop that stopped calling those functions, or
    passed them less, would still pass. Needs git.

.EXAMPLE
    pwsh -File scripts/check.ps1
#>

#Requires -Version 7
param([switch] $SkipIfPassed, [switch] $SelfTest)
$ErrorActionPreference = 'Stop'

$SELF_TESTS = @('check.ps1', 'commit-check.ps1', 'compare-resource-counts.ps1', 'dump-diff.ps1', 'dump-keys.ps1', 'dump-planets.ps1', 'dump-shared-names.ps1', 'fetch-mods.ps1',
    'get-dump.ps1', 'hook-matcher.ps1', 'markdown-check.ps1', 'mod-info.ps1', 'pack-mods.ps1', 'param-check.ps1', 'pr-body-check.ps1',
    'refuse-cd-into-mod-cache.ps1', 'refuse-git-hook-skip.ps1', 'resolve-modpack.ps1', 'self-test-halves.ps1')
# Has a self-test this does not run, and why: it needs Factorio installed.
$NEEDS_GAME = @('dump-walk.ps1', 'load-harness.ps1', 'locale-check.ps1', 'trace-definitions.ps1', 'tree-viewer.ps1')
# Of those, each whose -SelfTest -NoGame runs the cases that need no game. This runs them.
$NO_GAME_CASES = @('trace-definitions.ps1')
# Bytes, with LF line endings; a page must be under its limit. Paths are from the repository root.
$PAGE_LIMITS = [ordered]@{ 'CLAUDE.md' = 4000; 'docs/agents/code-review.md' = 3000; 'docs/agents/code-review-prose.md' = 2000 }
# Characters a line of tracked Markdown prose may run to. What counts is in markdown-check.ps1's
# header.
$MARKDOWN_LINE_LIMIT = 100
# Characters a comment or header line of a script here may run to: the Markdown's, as above.
$COMMENT_LINE_LIMIT = $MARKDOWN_LINE_LIMIT

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

# The end of a run: a failed one deletes the record; a pass records $Tree if the tree is still
# $Tree, and otherwise returns the line that says it was not.
function Complete-PassRecord {
    param([string] $Root, [string] $Record, [string] $Tree, [switch] $Failed)
    if (-not $Record) { return }
    if ($Failed) { Remove-Item -LiteralPath $Record -Force -ErrorAction SilentlyContinue; return }
    if (-not $Tree) { return }
    if ($Tree -ne (Get-CheckedTree -Root $Root)) { return 'check: the tree changed while it was read, so this pass is not recorded for -SkipIfPassed.' }
    Set-Content -LiteralPath $Record -Value "$Tree $([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ', [cultureinfo]::InvariantCulture))"
}

# The numbers of a script's comment and header lines over $Limit characters: each line of a <# #>
# block, and a line that begins with #. A help block's .EXAMPLE section is skipped, as an example
# is copied whole. Read from the parser's comment tokens, so a # line in a here-string is not one.
function Get-LongCommentLine {
    param([Parameter(Mandatory)] [string] $Path, [Parameter(Mandatory)] [int] $Limit)
    $tokens = $null
    [void] [Management.Automation.Language.Parser]::ParseFile($Path, [ref] $tokens, [ref] $null)
    $lines = [IO.File]::ReadAllLines($Path)
    # One word after its indent and comment marker, as an address is, cannot be broken.
    $over = { param($line) $line.Length -gt $Limit -and $line -notmatch '^\s*(#+\s*)?\S+\s*$' }
    foreach ($comment in $tokens | Where-Object Kind -eq 'Comment') {
        $first = $comment.Extent.StartLineNumber
        if (-not $comment.Text.StartsWith('<#')) {
            if ($lines[$first - 1] -match '^\s*#' -and (& $over $lines[$first - 1])) { $first }
            continue
        }
        $section = ''
        foreach ($n in $first..$comment.Extent.EndLineNumber) {
            # A help keyword in upper case, as they are written here, with or without an argument:
            # a line beginning `.githooks` or `.NET` is text.
            $keyword = '^\s*\.(SYNOPSIS|DESCRIPTION|PARAMETER|EXAMPLE|INPUTS|OUTPUTS|NOTES|LINK|COMPONENT|ROLE|FUNCTIONALITY)(\s|$)'
            if ($lines[$n - 1] -cmatch $keyword) { $section = $Matches[1] }
            if ($section -ne 'EXAMPLE' -and (& $over $lines[$n - 1])) { $n }
        }
    }
}

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

# What is wrong with one self-test's run: it exited other than 0, or it said it ran no case.
function Get-RunProblem {
    param([string] $Run, [int] $ExitCode, [string] $Said)
    if ($ExitCode) { "$Run exited $ExitCode" } elseif (Test-RanNoCase $Said) { "$Run ran no case" }
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
        $cases = [ordered]@{
            'a pass records the tree, and the record reads back as that tree' = {
                $said = Complete-PassRecord -Root $repo -Record $rec -Tree $base
                $base -and -not $said -and (Read-PassRecord $rec).Tree -eq $base -and (Get-CheckedTree -Root $repo) -eq $base }
            'an unstaged edit, an untracked file and a staged-only change each make another tree; an ignored file does not' = {
                $edit = & $changed { & $file 'a.txt' 'two' } { & $file 'a.txt' 'one' }
                $new = & $changed { & $file 'b.txt' 'new' } { Remove-Item -LiteralPath (Join-Path $repo 'b.txt') }
                $staged = & $changed { & $file 'a.txt' 'two'; git -C $repo add a.txt; & $file 'a.txt' 'one' } { git -C $repo add a.txt }
                & $file 'ignored.txt' 'x'; $ignored = (Get-CheckedTree -Root $repo) -eq $base; Remove-Item -LiteralPath (Join-Path $repo 'ignored.txt')
                $edit -and $new -and $staged -and $ignored -and (Get-CheckedTree -Root $repo) -eq $base }
            'a failed run deletes the record, and a tree changed during a pass is not recorded' = {
                Complete-PassRecord -Root $repo -Record $rec -Tree $base | Out-Null
                Complete-PassRecord -Root $repo -Record $rec -Tree $base -Failed
                $gone = -not (Test-Path -LiteralPath $rec)
                & $file 'a.txt' 'two'; $said = Complete-PassRecord -Root $repo -Record $rec -Tree $base; & $file 'a.txt' 'one'
                $gone -and $said -match 'not recorded' -and -not (Test-Path -LiteralPath $rec) }
            'an empty record, or one cut short, is no record, and reading it throws nothing' = {
                Set-Content -LiteralPath $rec -Value '' -NoNewline; $empty = Read-PassRecord $rec
                Set-Content -LiteralPath $rec -Value $base.Split(' ')[0]; $short = Read-PassRecord $rec
                Remove-Item -LiteralPath $rec
                $null -eq $empty -and $null -eq $short -and $null -eq (Read-PassRecord $rec) }
            'a changed file git cannot read, and a directory outside a repository, make no tree' = {
                $path = Join-Path $repo 'a.txt'; & $file 'a.txt' 'two'
                # Locked on Windows; unreadable elsewhere, which needs a user other than root.
                $lock = if ($IsWindows) { [IO.File]::Open($path, 'Open', 'Read', 'None') } else { chmod 000 $path; $null }
                try { $unread = Get-CheckedTree -Root $repo } finally { if ($lock) { $lock.Dispose() } else { chmod 644 $path } }
                & $file 'a.txt' 'one'
                $unread -eq '' -and (Get-CheckedTree -Root $outside) -eq '' }
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
if ($passed -and $passed.Tree -eq $tree) {
    Write-Host "OK - check skipped: this tree (working $($passed.Working), index $($passed.Index)) passed it at $($passed.At). Nothing was run."
    exit 0
}

$clock.Restart()
foreach ($script in Get-ChildItem -LiteralPath $PSScriptRoot -Filter *.ps1 | Sort-Object Name) {
    $errors = $null
    [void] [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref] $null, [ref] $errors)
    Write-Host "check: $($script.Name) parses -- $($errors ? 'FAILED' : 'ok')"
    foreach ($e in $errors) { Write-Host "    line $($e.Extent.StartLineNumber): $($e.Message)" }
    if ($errors) { $failed.Add("$($script.Name) does not parse") }

    foreach ($problem in Get-ScriptProblem -Path $script.FullName -Limit $COMMENT_LINE_LIMIT -SelfTests $SELF_TESTS -NeedsGame $NEEDS_GAME -NoGameCases $NO_GAME_CASES) {
        Write-Host "check: $problem -- FAILED"
        $failed.Add($problem)
    }
}
Write-Host "check: every script parsed $(& $took)"

$clock.Restart()
$said = & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'param-check.ps1') $PSScriptRoot 2>&1 | Out-String
$bad = $LASTEXITCODE -or $said -notmatch '(?m)^OK - param-check: '
Write-Host "check: param-check.ps1 scripts -- $($bad ? 'FAILED' : 'ok') $(& $took)"
if ($bad) {
    $said.TrimEnd() -split "`n" | ForEach-Object { Write-Host "    $_" }
    $failed.Add('param-check.ps1 found a list parameter never split on a comma')
}

foreach ($run in @($SELF_TESTS | ForEach-Object { , @($_, '-SelfTest') }) + @($NO_GAME_CASES | ForEach-Object { , @($_, '-SelfTest', '-NoGame') })) {
    $name = $run[0]; $switches = @($run | Select-Object -Skip 1)
    $clock.Restart()
    $said = & pwsh -NoProfile -File (Join-Path $PSScriptRoot $name) @switches 2>&1 | Out-String
    # Exit 0 having run no case is not a pass: mod-info.ps1 has no param block, so it would take
    # a -SelfTest it no longer answers in silence, and a broken -NoGame passed with all 0 cases.
    $problem = Get-RunProblem -Run "$name $switches" -ExitCode $LASTEXITCODE -Said $said
    Write-Host "check: $name $switches -- $($problem ? 'FAILED' : 'ok') $(& $took)"
    if ($problem) {
        $said.TrimEnd() -split "`n" | ForEach-Object { Write-Host "    $_" }
        $failed.Add($problem)
    }
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
if ($failed) {
    Complete-PassRecord -Root $root -Record $record -Tree $tree -Failed
    Write-Host "FAILED - check: $($failed -join '; ')."
    exit 1
}
# Recorded only for a tree that stood still while it was read: an edit during the run means
# no one tree passed.
$said = Complete-PassRecord -Root $root -Record $record -Tree $tree
if ($said) { Write-Host $said }
Write-Host "OK - check passed. Not run, because each needs the game: -SelfTest of $($NEEDS_GAME -join ', '); of $($NO_GAME_CASES -join ', '), only the cases that need no game ran."
exit 0
