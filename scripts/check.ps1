<#
.SYNOPSIS
    Parses every script under scripts/ and runs every self-test that needs neither the game nor
    the network. Exit 0 means every script parsed and every one of those self-tests passed.

.DESCRIPTION
    THE ONE COMMAND BEFORE A PUSH (grado-factorio-tools#60). The only gate here was commit-msg,
    which reads a message and no script. Each -SelfTest was run by hand, session by session, and
    review lanes reported more than once that no lane had run them. .githooks/pre-push runs this,
    and so does the workflow in .github/workflows/ on every pull request and on main.

    WHAT IT RUNS. A parse of each script beside it, which finds a syntax error on a line no
    self-test reaches, and in the libraries that have no self-test. Then -SelfTest of each script
    in $SELF_TESTS, each in a pwsh of its own, so one script's `exit` does not end the run. A
    self-test that passes prints one line here; one that fails prints everything it said.

    WHAT IT DOES NOT RUN. load-harness.ps1 -SelfTest, because it starts Factorio, and a CI runner
    has no game. After a change to the harness or to mod-info.ps1, which the harness reads
    through, run it by hand:

        pwsh -File scripts/load-harness.ps1 -SelfTest

    A script that gains a -SelfTest and is named in neither list below fails this check, so a new
    one is not left out in silence.

    WHAT IT CANNOT SEE. A parse proves syntax and nothing else: a misspelled cmdlet or variable
    parses. No linter runs. It reads the working tree, so through the pre-push hook it checks
    what is on disk, which is not the commits being pushed when the tree has uncommitted edits.
    And fetch-mods.ps1's self-test listens on a loopback port, so it fails where that is refused.

.EXAMPLE
    pwsh -File scripts/check.ps1
#>

#Requires -Version 7
$ErrorActionPreference = 'Stop'

$SELF_TESTS = 'commit-check.ps1', 'fetch-mods.ps1', 'mod-info.ps1', 'pack-mods.ps1', 'resolve-modpack.ps1'
# Has a self-test this does not run, and why: it needs Factorio installed.
$NEEDS_GAME = @('load-harness.ps1')

$failed = [System.Collections.Generic.List[string]]::new()

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

foreach ($name in $SELF_TESTS) {
    $said = & pwsh -NoProfile -File (Join-Path $PSScriptRoot $name) -SelfTest 2>&1 | Out-String
    Write-Host "check: $name -SelfTest -- $($LASTEXITCODE ? 'FAILED' : 'ok')"
    if ($LASTEXITCODE) {
        $said.TrimEnd() -split "`n" | ForEach-Object { Write-Host "    $_" }
        $failed.Add("$name -SelfTest exited $LASTEXITCODE")
    }
}

Write-Host ''
if ($failed) { Write-Host "FAILED - check: $($failed -join '; ')."; exit 1 }
Write-Host "OK - check passed. Not run: $($NEEDS_GAME -join ', ') -SelfTest, which needs the game."
exit 0
