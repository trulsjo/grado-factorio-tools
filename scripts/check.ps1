<#
.SYNOPSIS
    Parses every script under scripts/, runs every self-test that needs neither the game nor the
    network, holds the agent pages to their size limits, and runs markdown-check.ps1 over the
    tracked Markdown. Exit 0 means all of that held.

.DESCRIPTION
    THE ONE COMMAND BEFORE A PUSH (grado-factorio-tools#60). The only gate here was commit-msg,
    which reads a message and no script. Each -SelfTest was run by hand, session by session, and
    review lanes reported more than once that no lane had run them. .githooks/pre-push runs this,
    and so does the workflow in .github/workflows/ on every pull request and on main.

    WHAT IT RUNS. A parse of each script beside it, which finds a syntax error on a line no
    self-test reaches, and in the libraries that have no self-test. Then -SelfTest of each script
    in $SELF_TESTS, each in a pwsh of its own, so one script's `exit` does not end the run. A
    self-test that passes prints one line here; one that fails prints everything it said.

    THE PAGES AN AGENT ALWAYS LOADS HAVE A SIZE LIMIT (grado-factorio-tools#69). CLAUDE.md loads on
    every turn and the code-review rules before every review; grado-factorio-tools#65 cut both, and
    the next edit took CLAUDE.md back over its limit before anyone looked. The limits are in
    $PAGE_LIMITS and nowhere else. A page is measured with LF line endings, which is how the
    repository stores it, so a checkout with CRLF gets the same answer.

    THE TRACKED MARKDOWN IS READ BY markdown-check.ps1 -All (grado-factorio-tools#74). A page that
    moves leaves its links behind, and nothing else reads them. This script had a link check of
    its own until that one moved here; it asked the disk, in any case, and read no `[x]: path`
    line. What is checked now, and what is not, is in that script's header.

    WHAT IT DOES NOT RUN. load-harness.ps1 -SelfTest, because it starts Factorio, and a CI runner
    has no game. After a change to the harness or to mod-info.ps1, which the harness reads
    through, run it by hand:

        pwsh -File scripts/load-harness.ps1 -SelfTest

    A script that declares a -SelfTest the way these do and is named in neither list below fails
    this check, so a new one is not left out in silence. One declared some other way is missed.

    WHAT IT CANNOT SEE. A parse proves syntax and nothing else: a misspelled cmdlet or variable
    parses. No linter runs. It reads the working tree, so through the pre-push hook it checks
    what is on disk, which is not the commits being pushed when the tree has uncommitted edits.
    The Markdown is the exception: it is read as staged, so an edit not yet staged is not seen.
    And fetch-mods.ps1's self-test listens on a loopback port, so it fails where that is refused.

    HOW LONG IT TAKES ON THE DEVELOPMENT MACHINE DEPENDS ON WHAT ELSE IS RUNNING THERE
    (grado-factorio-tools#70). On a quiet machine it is under twice CI's time; it was reported as
    ten times slower while review lanes and the game were running beside it. No step here carries
    that. Each line prints its seconds so two runs can be compared; the measurement is in
    docs/measurements.md.

.EXAMPLE
    pwsh -File scripts/check.ps1
#>

#Requires -Version 7
$ErrorActionPreference = 'Stop'

$SELF_TESTS = @('commit-check.ps1', 'fetch-mods.ps1', 'get-dump.ps1', 'markdown-check.ps1', 'mod-info.ps1', 'pack-mods.ps1',
    'refuse-cd-into-mod-cache.ps1', 'resolve-modpack.ps1')
# Has a self-test this does not run, and why: it needs Factorio installed.
$NEEDS_GAME = @('load-harness.ps1')
# Bytes, with LF line endings; a page must be under its limit. Paths are from the repository root.
$PAGE_LIMITS = [ordered]@{ 'CLAUDE.md' = 4000; 'docs/agents/code-review.md' = 3000 }

$root = Split-Path $PSScriptRoot -Parent
$failed = [System.Collections.Generic.List[string]]::new()
$clock = [Diagnostics.Stopwatch]::new()
# What a step took, for the end of its line. Invariant, so a log reads the same on every machine.
$took = { '({0}s)' -f $clock.Elapsed.TotalSeconds.ToString('0.0', [cultureinfo]::InvariantCulture) }

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
try { $said = & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'markdown-check.ps1') -All 2>&1 | Out-String } finally { Pop-Location }
$bad = $LASTEXITCODE -or $said -notmatch 'markdown-check: [1-9]\d* Markdown file'
Write-Host "check: markdown-check.ps1 -All -- $($bad ? 'FAILED' : 'ok') $(& $took)"
if ($bad) {
    $said.TrimEnd() -split "`n" | ForEach-Object { Write-Host "    $_" }
    $failed.Add('markdown-check.ps1 -All found something, or read no file')
}

Write-Host ''
if ($failed) { Write-Host "FAILED - check: $($failed -join '; ')."; exit 1 }
Write-Host "OK - check passed. Not run: $($NEEDS_GAME -join ', ') -SelfTest, which needs the game."
exit 0
