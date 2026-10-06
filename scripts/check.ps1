<#
.SYNOPSIS
    Parses every script under scripts/, runs every self-test that needs neither the game nor the
    network, and holds the agent pages to their size limits and Markdown links to files that
    exist. Exit 0 means all of that held.

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

    A RELATIVE LINK IN A TRACKED MARKDOWN FILE HAS TO NAME A FILE THAT EXISTS. A page that moves
    leaves its links behind, and nothing else reads them.

    WHAT IT DOES NOT RUN. load-harness.ps1 -SelfTest, because it starts Factorio, and a CI runner
    has no game. After a change to the harness or to mod-info.ps1, which the harness reads
    through, run it by hand:

        pwsh -File scripts/load-harness.ps1 -SelfTest

    A script that declares a -SelfTest the way these do and is named in neither list below fails
    this check, so a new one is not left out in silence. One declared some other way is missed.

    WHAT IT CANNOT SEE. A parse proves syntax and nothing else: a misspelled cmdlet or variable
    parses. No linter runs. It reads the working tree, so through the pre-push hook it checks
    what is on disk, which is not the commits being pushed when the tree has uncommitted edits.
    And fetch-mods.ps1's self-test listens on a loopback port, so it fails where that is refused.
    Of a link it checks the file and nothing after a `#`: an anchor to a heading that is gone
    passes. A link to another site is not followed, a reference-style link (`[x]: path`) is not
    read, and neither is a path that is only named in backticks.

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

$SELF_TESTS = @('commit-check.ps1', 'fetch-mods.ps1', 'mod-info.ps1', 'pack-mods.ps1', 'resolve-modpack.ps1')
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
    $bytes = [Text.Encoding]::UTF8.GetByteCount(([IO.File]::ReadAllText($path) -replace "`r`n", "`n"))
    $over = $bytes -ge $PAGE_LIMITS[$page]
    Write-Host "check: $page is $bytes bytes, limit $($PAGE_LIMITS[$page]) -- $($over ? 'FAILED' : 'ok')"
    if ($over) { $failed.Add("$page is $bytes bytes and must be under $($PAGE_LIMITS[$page])") }
}

# Tracked files only, so a scratch note or another tool's output is not this check's business.
$pages = @(git -C $root -c core.quotePath=false ls-files -- '*.md')
if ($LASTEXITCODE -ne 0 -or -not $pages) {
    Write-Host 'check: git listed no tracked Markdown file, so no link was checked -- FAILED'
    $failed.Add('no tracked Markdown file to check links in')
}
$links = 0
$broken = 0
foreach ($page in $pages) {
    $path = Join-Path $root $page
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }   # deleted, not yet committed
    foreach ($m in [regex]::Matches((Get-Content -LiteralPath $path -Raw), '\]\(\s*<?([^)\s>#]+)[^)]*\)')) {
        $target = $m.Groups[1].Value
        if ($target -match '^[A-Za-z][A-Za-z0-9+.-]*:') { continue }       # another site, or mailto:
        $links++
        if (-not (Test-Path -LiteralPath (Join-Path (Split-Path $path -Parent) ([uri]::UnescapeDataString($target))))) {
            $broken++
            Write-Host "check: $page links to $target, which does not exist -- FAILED"
            $failed.Add("$page links to $target, which does not exist")
        }
    }
}
Write-Host "check: $links relative link(s) in $($pages.Count) tracked Markdown file(s), $broken broken -- $($broken ? 'FAILED' : 'ok') $(& $took)"

Write-Host ''
if ($failed) { Write-Host "FAILED - check: $($failed -join '; ')."; exit 1 }
Write-Host "OK - check passed. Not run: $($NEEDS_GAME -join ', ') -SelfTest, which needs the game."
exit 0
