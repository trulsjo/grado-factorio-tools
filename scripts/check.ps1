<#
.SYNOPSIS
    Parses every script under scripts/, reads their list parameters with param-check.ps1, runs
    every self-test that needs neither the game nor the network, holds the agent pages to their
    size limits, and runs markdown-check.ps1 over the tracked Markdown. Exit 0 means all of that held.

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
    its own, so one script's `exit` does not end the run. A self-test that passes prints one line
    here; one that fails prints everything it said.

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
    runner has no game. Every script named there loads its mods through the harness, and the
    harness reads through mod-info.ps1. So after a change to either of those run all of them by
    hand, and after a change to one of the others, its own:

        pwsh -File scripts/load-harness.ps1 -SelfTest

    A script that declares a -SelfTest the way these do and is named in neither list below fails
    this check, so a new one is not left out in silence. One declared some other way is missed.

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
    run as at the start. A run that fails deletes the record. With -SkipIfPassed, as the hook runs
    it, a tree that matches the record runs nothing, and the run says so, naming both trees and
    when they passed. A skip shows that this same tree passed once; it cannot see what is outside
    the tree: an ignored file, the pwsh or git in use, the loopback port fetch-mods.ps1 needs, or
    a self-test that passes only sometimes. CI runs without the switch.

    HOW LONG IT TAKES ON THE DEVELOPMENT MACHINE DEPENDS ON WHAT ELSE IS RUNNING THERE
    (grado-factorio-tools#70). On a quiet machine it is under twice CI's time; it was reported as
    ten times slower while review lanes and the game were running beside it. No step here carries
    that. Each line prints its seconds so two runs can be compared; the measurement is in
    docs/measurements.md.

.PARAMETER SkipIfPassed
    Run nothing when the record says this tree passed, as above.

.EXAMPLE
    pwsh -File scripts/check.ps1
#>

#Requires -Version 7
param([switch] $SkipIfPassed)
$ErrorActionPreference = 'Stop'

$SELF_TESTS = @('commit-check.ps1', 'compare-resource-counts.ps1', 'dump-diff.ps1', 'dump-keys.ps1', 'dump-planets.ps1', 'dump-shared-names.ps1', 'fetch-mods.ps1',
    'get-dump.ps1', 'hook-matcher.ps1', 'markdown-check.ps1', 'mod-info.ps1', 'pack-mods.ps1', 'param-check.ps1', 'pr-body-check.ps1',
    'refuse-cd-into-mod-cache.ps1', 'refuse-git-hook-skip.ps1', 'resolve-modpack.ps1', 'self-test-halves.ps1')
# Has a self-test this does not run, and why: it needs Factorio installed.
$NEEDS_GAME = @('dump-walk.ps1', 'load-harness.ps1', 'locale-check.ps1', 'trace-definitions.ps1', 'tree-viewer.ps1')
# Bytes, with LF line endings; a page must be under its limit. Paths are from the repository root.
$PAGE_LIMITS = [ordered]@{ 'CLAUDE.md' = 4000; 'docs/agents/code-review.md' = 3000; 'docs/agents/code-review-prose.md' = 2000 }
# Characters a line of tracked Markdown prose may run to. What counts is in markdown-check.ps1's header.
$MARKDOWN_LINE_LIMIT = 100

$root = Split-Path $PSScriptRoot -Parent
$failed = [System.Collections.Generic.List[string]]::new()
$clock = [Diagnostics.Stopwatch]::new()
# What a step took, for the end of its line. Invariant, so a log reads the same on every machine.
$took = { '({0}s)' -f $clock.Elapsed.TotalSeconds.ToString('0.0', [cultureinfo]::InvariantCulture) }

# The tree as this check reads it: the working tree's tracked and unignored files, written as a
# tree from a copy of the index, then the index itself, which the Markdown is read from. Empty
# where git cannot say, as outside a repository, and then no pass is recorded or skipped.
function Get-CheckedTree {
    $index = git -C $root rev-parse --path-format=absolute --git-path index 2>$null
    if ($LASTEXITCODE) { return '' }
    $copy = New-TemporaryFile
    $was = $env:GIT_INDEX_FILE
    try {
        if (Test-Path -LiteralPath $index) { Copy-Item -LiteralPath $index -Destination $copy -Force }
        $env:GIT_INDEX_FILE = $copy.FullName
        git -C $root add -A 2>$null
        $work = git -C $root write-tree 2>$null
        if ($LASTEXITCODE) { return '' }
        $env:GIT_INDEX_FILE = $was
        $staged = git -C $root write-tree 2>$null
        if ($LASTEXITCODE) { return '' }
        "$work $staged"
    }
    finally { $env:GIT_INDEX_FILE = $was; Remove-Item -LiteralPath $copy -Force -ErrorAction SilentlyContinue }
}
$record = git -C $root rev-parse --path-format=absolute --git-path check-passed 2>$null
$tree = Get-CheckedTree
if ($SkipIfPassed -and $tree -and (Test-Path -LiteralPath $record)) {
    $passed = (Get-Content -LiteralPath $record -Raw).Trim() -split ' ', 3
    if ("$($passed[0]) $($passed[1])" -eq $tree) {
        Write-Host "OK - check skipped: this tree (working $($passed[0]), index $($passed[1])) passed it at $($passed[2]). Nothing was run."
        exit 0
    }
}

$clock.Restart()
foreach ($script in Get-ChildItem -LiteralPath $PSScriptRoot -Filter *.ps1 | Sort-Object Name) {
    $errors = $null
    [void] [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref] $null, [ref] $errors)
    Write-Host "check: $($script.Name) parses -- $($errors ? 'FAILED' : 'ok')"
    foreach ($e in $errors) { Write-Host "    line $($e.Extent.StartLineNumber): $($e.Message)" }
    if ($errors) { $failed.Add("$($script.Name) does not parse") }

    $hasSelfTest = (Get-Content -LiteralPath $script.FullName -Raw) -match '\[switch\]\s*\$SelfTest|\$args -contains ''-SelfTest'''
    if ($hasSelfTest -and $script.Name -notin $SELF_TESTS + $NEEDS_GAME) {
        Write-Host "check: $($script.Name) has a -SelfTest that is neither run here nor named as needing the game -- FAILED"
        $failed.Add("$($script.Name) has a -SelfTest this check does not know")
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

foreach ($name in $SELF_TESTS) {
    $clock.Restart()
    $said = & pwsh -NoProfile -File (Join-Path $PSScriptRoot $name) -SelfTest 2>&1 | Out-String
    # Exit 0 having run no case is not a pass: mod-info.ps1 has no param block, so it would take
    # a -SelfTest it no longer answers in silence.
    $ran = $said -match 'self-test'
    Write-Host "check: $name -SelfTest -- $($LASTEXITCODE -or -not $ran ? 'FAILED' : 'ok') $(& $took)"
    if ($LASTEXITCODE -or -not $ran) {
        $said.TrimEnd() -split "`n" | ForEach-Object { Write-Host "    $_" }
        $failed.Add($ran ? "$name -SelfTest exited $LASTEXITCODE" : "$name -SelfTest ran no case")
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
    if ($record) { Remove-Item -LiteralPath $record -Force -ErrorAction SilentlyContinue }
    Write-Host "FAILED - check: $($failed -join '; ')."
    exit 1
}
# Recorded only for a tree that stood still while it was read: an edit during the run means
# no one tree passed.
if ($tree -and $tree -eq (Get-CheckedTree)) {
    Set-Content -LiteralPath $record -Value "$tree $([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ', [cultureinfo]::InvariantCulture))"
}
elseif ($tree) { Write-Host 'check: the tree changed while it was read, so this pass is not recorded for -SkipIfPassed.' }
Write-Host "OK - check passed. Not run, because each needs the game: -SelfTest of $($NEEDS_GAME -join ', ')."
exit 0
