#Requires -Version 7
<#
    The runner a script's -SelfTest hands its halves to, and the runner's own canary. Dot-source it:

        . "$PSScriptRoot/self-test-halves.ps1"
        Invoke-SelfTestHalves -Halves @(
            @{ Name = 'repo-passes';     Body = { ...; 'the repository passes' } }
            @{ Name = 'canary-is-seen';  Body = { ...; 'a planted fault is reported' } }
        )

    load-harness-lib.ps1 dot-sources it, so a caller of the harness library has it already.

    WHERE IT CAME FROM. realistic-fusion-refreshed's factorio-lib.ps1, at c48fadf
    (grado-factorio-tools#100). Invoke-SelfTestHalves keeps its name and code. Test-SelfTestRunner
    keeps its name and its cases; its last case no longer rewrites where a copy of the file finds
    the harness, because this file loads nothing.

    IT IS A FILE OF ITS OWN FOR THAT CASE. The canary's last case breaks a copy of this file and
    loads the copy in a child process. A file that dot-sources nothing can be copied anywhere.

    WHAT -SelfTest MEANS HERE. Run as a script with -SelfTest, it runs Test-SelfTestRunner through
    Invoke-SelfTestHalves. Exit 0 means the runner numbered, refused and failed as the canary's
    cases say. It says nothing about any gate that uses the runner: a half that asserts the wrong
    thing still returns its one string.
#>

function Invoke-SelfTestHalves {
    <#  Run a gate's -SelfTest halves in order, numbering them as they run.

        A half is declared with a NAME and a body, in one ordered list, and this counts them. The
        total in `N/M` is the list's length, so it is written once instead of once per label, and a
        half added anywhere changes no other half's label.

        The name is the handle a reader and a document use. An ordinal is invalidated by a half
        inserted above it, silently and in prose no gate reads.

        A BODY RETURNS WHAT IT PROVED, as one string, and that string is the printed line. Returning
        nothing is a failure rather than a pass, because "the body never ran" and "the body ran and
        proved nothing" are the same silence -- and a self-test runner that can skip a half while
        reporting a pass is the exact fault a -SelfTest exists to prevent. A body signals failure
        the way a gate does: `throw`, or `exit`.

        -Format is a .NET format string over {0} the ordinal, {1} the total and {2} the message.

        Test-SelfTestRunner below is this function's canary.  #>
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Halves,
        [string] $Format = 'self-test {0}/{1}: {2}'
    )

    if ($Halves.Count -eq 0) { throw 'Invoke-SelfTestHalves: no halves were declared, so a pass would prove nothing.' }

    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($half in $Halves) {
        if ($null -eq $half) { throw 'Invoke-SelfTestHalves: a half is $null, not a hashtable of Name and Body.' }
        if ($half -isnot [System.Collections.IDictionary]) {
            throw "Invoke-SelfTestHalves: a half is a $($half.GetType().Name), not a hashtable of Name and Body."
        }
        $name = [string]$half['Name']
        if (-not $name.Trim()) { throw 'Invoke-SelfTestHalves: a half was declared with no Name.' }
        if ($half['Body'] -isnot [scriptblock]) {
            throw "Invoke-SelfTestHalves: half '$name' has no Body, so it would be counted without running."
        }
        if (-not $seen.Add($name)) {
            throw "Invoke-SelfTestHalves: '$name' is declared twice, so neither prose nor a failure could name one of them."
        }
    }

    $total = $Halves.Count
    $ran   = 0
    foreach ($half in $Halves) {
        $name = [string]$half['Name']
        try { $result = & $half['Body'] }
        catch { throw "-SelfTest half '$name' FAILED: $($_.Exception.Message)" }

        # Strict, and deliberately loud: a body that leaks pipeline output -- PowerShell's
        # commonest accident -- fails here rather than printing someone's stray object as the
        # thing the half proved.
        $message = @($result | Where-Object { $null -ne $_ })
        if ($message.Count -ne 1 -or $message[0] -isnot [string] -or -not ([string]$message[0]).Trim()) {
            $what = if ($message.Count -eq 0) { 'returned nothing' } else { "returned $($message.Count) value(s): $($message -join ' | ')" }
            throw ("-SelfTest half '$name' FAILED: it $what, so there is no evidence it ran. A half " +
                   'returns one string saying what it proved; pipe anything else to Out-Null.')
        }

        $ran++
        Write-Host ($Format -f $ran, $total, ([string]$message[0]))
    }

    # The runner's own floor: the count printed and the count run come from one loop, and this is
    # what says so out loud if an edit ever separates them. No edit in this file can reach it today,
    # which is why Test-SelfTestRunner reaches it the only way left -- by loading a COPY of this
    # file whose run loop takes every half but the last, in a child process.
    if ($ran -ne $total) {
        throw "-SelfTest FAILED: $ran of $total declared halves ran. A skipped half would have been reported as a pass."
    }
}

function Test-SelfTestRunner {
    <#  Invoke-SelfTestHalves' canary. Returns what it proved; throws on the first case it fails.

        It is a canary rather than a comment because the runner is shared code: a runner that
        skipped a half, or counted one it never ran, would report a clean pass over a gate that did
        not execute, in every gate that uses it at once. It starts no game.  #>

    $lines = { param($h, $f)
        if ($f) { Invoke-SelfTestHalves -Halves $h -Format $f 6>&1 | ForEach-Object { [string]$_ } }
        else    { Invoke-SelfTestHalves -Halves $h            6>&1 | ForEach-Object { [string]$_ } }
    }

    # 1. The total is the list's length and the ordinal is the run order -- neither is written down.
    $three = & $lines @(
        @{ Name = 'a'; Body = { 'first' } }
        @{ Name = 'b'; Body = { 'second' } }
        @{ Name = 'c'; Body = { 'third' } }
    ) $null
    $want = @('self-test 1/3: first', 'self-test 2/3: second', 'self-test 3/3: third')
    if (($three -join "`n") -cne ($want -join "`n")) {
        throw "runner canary: three halves printed [$($three -join ' | ')], expected [$($want -join ' | ')]"
    }

    # 2. ONE half passed as a bare hashtable still runs one half. PowerShell unrolls a single item
    # out of an array and iterates a hashtable's entries, so the shape that would silently run zero
    # halves -- or count one and run none -- is a single declaration, not a long list.
    # @() around the result because one line comes back as a bare string, and $one[0] on a string
    # is its first character, not the line.
    $one = @(& $lines @{ Name = 'only'; Body = { 'alone' } } '  {0}/{1} ok: {2}')
    if ($one.Count -ne 1 -or $one[0] -cne '  1/1 ok: alone') {
        throw "runner canary: a lone half printed $(@($one).Count) line(s): $($one -join ' | ')"
    }

    # 3. A body that proves nothing is a failure. This is the case the whole runner turns on: it is
    # what "the half did not run" looks like from outside.
    $cases = @(
        @{ What = 'a body returning nothing';   Halves = @(@{ Name = 'silent'; Body = { } });        Says = 'returned nothing' }
        @{ What = 'a half with no body';        Halves = @(@{ Name = 'bodyless' });                  Says = 'has no Body' }
        @{ What = 'two halves sharing a name';  Halves = @(@{ Name = 'twin'; Body = { 'x' } }, @{ Name = 'twin'; Body = { 'y' } }); Says = 'declared twice' }
        @{ What = 'a body that throws';         Halves = @(@{ Name = 'angry'; Body = { throw 'the sheet is wrong' } }); Says = 'the sheet is wrong' }
        @{ What = 'an empty list';              Halves = @();                                        Says = 'no halves' }
        # A null entry is refused, and the refusal is the PARAMETER BINDER's rather than this
        # function's: a mandatory collection parameter rejects a null element before the body runs,
        # so the guard inside is insurance for a caller that gets past the binder rather than the
        # thing under test here. The case asserts the refusal, not which layer wrote it.
        @{ What = 'a null entry';               Halves = @(@{ Name = 'real'; Body = { 'x' } }, $null); Says = 'null' }
        # The leak, which the strict test above exists for and which nothing else here reaches: a
        # body that emits a stray object as well as its message.
        @{ What = 'a body leaking a second value'; Halves = @(@{ Name = 'leaky'; Body = { 'stray'; 'the message' } }); Says = 'returned 2 value(s)' }
    )
    foreach ($case in $cases) {
        $caught = $null
        try { & $lines $case.Halves $null | Out-Null }
        catch { $caught = $_.Exception.Message }
        if (-not $caught) { throw "runner canary: $($case.What) was reported as a pass." }
        if ($caught -notlike "*$($case.Says)*") {
            throw "runner canary: $($case.What) failed without saying '$($case.Says)': $caught"
        }
    }

    # 4. A failing half is named. An ordinal in the failure would send a reader to whichever half
    # holds that position today.
    $named = $null
    try { & $lines @(@{ Name = 'first'; Body = { 'ok' } }, @{ Name = 'second'; Body = { throw 'nope' } }) $null | Out-Null }
    catch { $named = $_.Exception.Message }
    if ($named -notlike "*'second'*") { throw "runner canary: a failing half was not named: $named" }

    # 5. THE FLOOR, WHICH NOTHING ABOVE CAN REACH. The count printed and the count run come from one
    # loop, so the only way to make them disagree is to edit that loop -- which is exactly the edit
    # the floor stands against. So it is made: a copy of this file whose run loop takes every half
    # but the last, loaded in a CHILD process, because dot-sourcing it here would replace the
    # runner under test with the broken one for the rest of the run.
    $mine = $MyInvocation.MyCommand.ScriptBlock.File
    if (-not $mine) { throw 'runner canary: cannot find this file on disk, so the floor cannot be exercised.' }
    $copy = Join-Path ([IO.Path]::GetTempPath()) ('runner-floor-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.ps1')
    try {
        # NORMALISED TO LF BEFORE ANYTHING IS MATCHED. `n here is a bare line feed, and a clone
        # whose git writes CRLF would otherwise fail the comparison below and throw "could not be
        # broken" instead of reaching the floor.
        $loop = "    `$ran   = 0`n    foreach (`$half in `$Halves) {"
        $source = (Get-Content -LiteralPath $mine -Raw) -replace "`r`n", "`n"
        if (-not $source.Contains($loop)) {
            throw 'runner canary: the run loop is not written the way the floor case expects, so it could not be broken.'
        }
        $skips = "    `$ran   = 0`n    foreach (`$half in @(`$Halves | Select-Object -First ([Math]::Max(1, `$Halves.Count - 1)))) {"
        Set-Content -LiteralPath $copy -Value $source.Replace($loop, $skips) -Encoding utf8

        $pwsh = Join-Path $PSHOME $(if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' })
        $said = & $pwsh -NoProfile -Command (
            ". '$copy'; try { Invoke-SelfTestHalves -Halves @(" +
            "@{ Name = 'a'; Body = { 'first' } }, @{ Name = 'b'; Body = { 'second' } }) | Out-Null; " +
            "'NO FLOOR' } catch { `$_.Exception.Message }") 2>&1
        $said = ($said | ForEach-Object { "$_" }) -join ' '
        if ($said -notlike '*1 of 2 declared halves ran*') {
            throw "runner canary: a runner that skips a half was not caught by the floor. It said: $said"
        }
    } finally { Remove-Item -LiteralPath $copy -Force -ErrorAction SilentlyContinue }

    return ('the runner numbers halves from the list itself (a derived total, a lone half, a body ' +
            'proving nothing, a body leaking a second value, a bodyless half, a null entry, a ' +
            'duplicate name, a throwing body, an empty list, a failure that names its half, and a ' +
            'copy of the runner that skips one, caught by the floor).')
}

# Only when run as a script. Dot-sourced, InvocationName is '.', and a caller's own -SelfTest is
# not this one. No param block, because dot-sourcing one would overwrite the caller's $SelfTest.
if ($MyInvocation.InvocationName -ne '.' -and $args -contains '-SelfTest') {
    $ErrorActionPreference = 'Stop'
    try { Invoke-SelfTestHalves -Halves @(@{ Name = 'runner-canary'; Body = { Test-SelfTestRunner } }) }
    catch { Write-Host "FAILED - self-test: $($_.Exception.Message)"; exit 1 }
    Write-Host ''
    Write-Host 'OK - self-test passed: the runner''s canary.'
    exit 0
}
