<#
.SYNOPSIS
    Runs a list of reverts on a copy of the repository, one at a time, and reports each as
    failing, passing or crashed its self-test, or as refused. Exit 0 means every revert on the
    list was run or refused; it says nothing of what they found, which the report does.

.DESCRIPTION
    WHY (grado-factorio-tools#284). A review's bug scan, and the session answering it, revert
    each claim of a script on a copy and run its -SelfTest, as docs/agents/review-brief.md's
    *The reverts* asks. Each wrote its own driver, and in one session (2026-10-27/28) three
    misread their runs: a sed revert that deleted the case along with the check, a self-test that
    threw before its summary line read as passing, and a slow self-test run by hand per revert.

    THE COPY is a git working tree the caller made, a clone at the commit under review. It is
    refused, exit 1 and nothing run, when it has uncommitted changes or untracked files, which are
    named.

    THE LIST is a PowerShell data file:

        @{ Reverts = @(
            @{ Name = 'F1'; File = 'scripts/x.ps1'; Find = 'if ($a) {'; Replace = 'if ($true) {'
               SelfTest = 'scripts/x.ps1'; Args = @('-NoGame'); Lines = 1 }
        ) }

    File and SelfTest are paths from the copy's root. Args is optional, handed to the self-test
    after -SelfTest. Lines is optional, 1 unless given. Find and Replace are exact text, matched
    with case; a line break in either, LF or CRLF, is read as the file's own.

    EACH REVERT, IN ORDER. Refused, and not run, where Find is empty; where File is not a file
    git tracks in the copy under that very name, as one outside the copy, an untracked one, or
    one named in another case, which git could not restore; where Find occurs in File other than
    exactly once, naming the count; where git reads File as binary; or where the edit changes no
    line or more than Lines, removed or added, by `git -C <copy> diff --numstat`. A refused revert
    leaves the file as it was.
    Otherwise `git -C <copy> diff --stat` is printed and the self-test is run, as
    `pwsh -NoProfile -File <SelfTest> -SelfTest <Args>`, from the copy's root. Its result is:
    *fails*, it exited other than 0 and its last summary line is `FAILED - self-test...`;
    *passes*, it exited 0 and that line is `OK - self-test...`, which code-review.md makes a
    finding; *crashed*, anything else, as no summary line, whatever the exit code, or a summary
    line its exit code contradicts. The file is then restored with
    `git -C <copy> checkout -- <File>`, and the copy checked clean again: one left dirty stops the
    run, exit 1, naming what is left and reporting the reverts run so far.

    THE REPORT is a line per revert as it runs, and at the end a Markdown table of name, result,
    exit code and summary line, for a review comment.

    WHAT IT CANNOT SEE. Whether a revert is the right one: a Find that matches once but in the
    wrong place is run. A self-test whose summary line is worded other than this repository's
    `OK - self-test` and `FAILED - self-test`, which reads as crashed; check.ps1 fails such a
    self-test among those it runs (grado-factorio-tools#297), not one that needs the game, nor one
    in a sibling. A revert across two files,
    or by a pattern. A self-test that changes a tracked file and puts it back.

.PARAMETER Copy
    The git working tree to revert in.

.PARAMETER List
    The .psd1 file of reverts.

.PARAMETER SelfTest
    Run the cases that hold the runner to what this header says, on a scratch repository, naming
    each as it runs. Needs git.

.EXAMPLE
    pwsh -File scripts/revert-run.ps1 -Copy C:/scratch/copy -List C:/scratch/reverts.psd1
#>

#Requires -Version 7
[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    [Parameter(ParameterSetName = 'Run', Mandatory)] [string] $Copy,
    [Parameter(ParameterSetName = 'Run', Mandatory)] [string] $List,
    [Parameter(ParameterSetName = 'SelfTest', Mandatory)] [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# What is uncommitted or untracked in the copy, one path to a line, or nothing.
function Get-DirtyPath {
    param([Parameter(Mandatory)] [string] $Root)
    $status = @(git -C $Root status --porcelain --untracked-files=all)
    if ($LASTEXITCODE) { throw "git status failed in $Root; is it a git working tree?" }
    $status | Where-Object { $_ } | ForEach-Object { $_.Substring(3) }
}

# How many times $Find stands in $Text, matched with case.
function Get-OccurrenceCount {
    param([string] $Text, [string] $Find)
    $count = 0; $at = 0
    while (($at = $Text.IndexOf($Find, $at, [StringComparison]::Ordinal)) -ge 0) { $count++; $at += $Find.Length }
    $count
}

# The self-test's result from its exit code and what it printed: fails, passes or crashed, and
# its last summary line.
function Get-RevertResult {
    param([int] $ExitCode, [string] $Said)
    $summary = @([regex]::Matches($Said, '(?m)^(OK|FAILED) - self-test.*$') | ForEach-Object { $_.Value.TrimEnd() })
    $last = if ($summary) { $summary[-1] } else { '' }
    $result = if ($last -like 'FAILED*' -and $ExitCode) { 'fails' } elseif ($last -like 'OK*' -and -not $ExitCode) { 'passes' } else { 'crashed' }
    @{ Result = $result; Summary = $last }
}

# One revert applied, run and restored; returns its row. Throws when the copy is left dirty.
function Invoke-Revert {
    param([Parameter(Mandatory)] [string] $Root, [Parameter(Mandatory)] [hashtable] $Revert)
    $row = @{ Name = $Revert.Name; Result = 'refused'; Exit = ''; Summary = '' }
    $lines = if ($Revert.ContainsKey('Lines')) { [int] $Revert.Lines } else { 1 }
    $find = [string] $Revert.Find; $replace = [string] $Revert.Replace
    # An empty Find occurs everywhere, and counting it would never end.
    if (-not $find) { $row.Summary = 'Find is empty'; return $row }
    # Only a file git tracks under this very name can be restored by git: not one outside the
    # copy, an untracked one, or one named in another case, which Windows would let be written.
    $file = $Revert.File -replace '\\', '/'
    $tracked = @(git -C $Root ls-files -- $file 2>$null)
    if ($LASTEXITCODE -or $tracked.Count -ne 1 -or $tracked[0] -cne $file) { $row.Summary = "$($Revert.File) is not a file git tracks in the copy under that name"; return $row }
    $path = Join-Path $Root $file
    $bytes = [IO.File]::ReadAllBytes($path)
    $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $text = [Text.UTF8Encoding]::new($false).GetString($bytes, $(if ($bom) { 3 } else { 0 }), $bytes.Length - $(if ($bom) { 3 } else { 0 }))
    # A line break in the list, LF or CRLF, is read as the file's own.
    $find = $find -replace '\r\n', "`n"; $replace = $replace -replace '\r\n', "`n"
    if ($text.Contains("`r`n")) { $find = $find -replace '\n', "`r`n"; $replace = $replace -replace '\n', "`r`n" }
    $count = Get-OccurrenceCount -Text $text -Find $find
    if ($count -ne 1) { $row.Summary = "Find occurs $count times in $file, not once"; return $row }
    $at = $text.IndexOf($find, [StringComparison]::Ordinal)
    $edited = $text.Substring(0, $at) + $replace + $text.Substring($at + $find.Length)
    [IO.File]::WriteAllText($path, $edited, [Text.UTF8Encoding]::new($bom))
    try {
        $numstat = "$(git -C $Root diff --numstat -- $file)".Trim()
        if ($LASTEXITCODE) { throw "git diff --numstat -- $file failed in $Root." }
        $counts = if ($numstat) { @($numstat -split '\s+')[0..1] } else { '0', '0' }
        # git counts no lines of a file it reads as binary, and prints - for each.
        if ($counts -contains '-') { $row.Summary = "git reads $file as binary, so its changed lines cannot be counted"; return $row }
        $added, $removed = $counts | ForEach-Object { [int] $_ }
        if (-not ($added -or $removed)) { $row.Summary = 'the edit changes no line'; return $row }
        if ($added -gt $lines -or $removed -gt $lines) { $row.Summary = "the edit changes $added added and $removed removed lines, more than Lines = $lines"; return $row }
        Write-Host "revert-run: $($Revert.Name), git -C <copy> diff --stat:"
        git -C $Root diff --stat | ForEach-Object { Write-Host "    $_" }
        $extra = if ($Revert.ContainsKey('Args')) { @($Revert.Args) } else { @() }
        Push-Location $Root
        try { $said = & pwsh -NoProfile -File (Join-Path $Root $Revert.SelfTest) -SelfTest @extra 2>&1 | Out-String; $code = $LASTEXITCODE }
        finally { Pop-Location }
        $judged = Get-RevertResult -ExitCode $code -Said $said
        $row.Result = $judged.Result; $row.Exit = "$code"; $row.Summary = $judged.Summary
        $row
    }
    finally {
        git -C $Root checkout -q -- $file
        if ($LASTEXITCODE) { throw "git checkout -- $file failed in $Root." }
    }
}

# The rows as a Markdown table, for a review comment.
function Format-RevertTable {
    param([object[]] $Rows)
    '| Revert | Result | Exit | Summary line |'
    '|---|---|---|---|'
    foreach ($r in $Rows) { "| $($r.Name) | $($r.Result) | $($r.Exit) | $(($r.Summary -replace '\|', '\|')) |" }
}

# The run over $ListPath in $Root: the rows, printed as they go and as a table; throws where it
# cannot run.
function Invoke-RevertRun {
    param([Parameter(Mandatory)] [string] $Root, [Parameter(Mandatory)] [string] $ListPath)
    $dirty = @(Get-DirtyPath -Root $Root)
    if ($dirty) { throw "the copy $Root has uncommitted changes, so no revert was run: $($dirty -join ', ')" }
    $data = try { Import-PowerShellDataFile -LiteralPath $ListPath } catch { throw "the list $ListPath cannot be read: $($_.Exception.Message)" }
    if (-not $data.ContainsKey('Reverts') -or -not @($data.Reverts)) { throw "the list $ListPath holds no Reverts." }
    foreach ($r in @($data.Reverts)) {
        $missing = @('Name', 'File', 'Find', 'Replace', 'SelfTest' | Where-Object { -not ($r -is [hashtable] -and $r.ContainsKey($_)) })
        if ($missing) { throw "a revert in $ListPath lacks $($missing -join ', ')." }
    }
    $rows = [System.Collections.Generic.List[object]]::new()
    try {
        foreach ($r in @($data.Reverts)) {
            $row = Invoke-Revert -Root $Root -Revert $r
            $rows.Add($row)
            Write-Host "revert-run: $($row.Name) -- $($row.Result)$(if ($row.Exit) { " (exit $($row.Exit))" }): $($row.Summary)"
            $left = @(Get-DirtyPath -Root $Root)
            if ($left) { throw "after $($row.Name) the copy is left dirty, so no later revert was run: $($left -join ', ')" }
        }
    }
    finally {
        Write-Host ''
        Format-RevertTable -Rows $rows | ForEach-Object { Write-Host $_ }
    }
    $rows
}

function Invoke-SelfTest {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "revert-run-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    $repo = Join-Path $temp 'copy'
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    $git = { git -C $repo -c user.name=selftest -c user.email=selftest@example.invalid -c commit.gpgsign=false @args; if ($LASTEXITCODE) { throw "git $args failed; the self-test needs git." } }
    # A self-test stub: it fails when $a is reverted, passes whatever else changes, and with -Mode
    # throws before its summary line or leaves a file behind.
    $stub = @(
        'param([switch] $SelfTest, [string] $Mode)'
        "`$a = 'alpha'"
        "`$b = 'beta'"
        "`$c = 'gamma'"
        "if (`$Mode -eq 'throw') { throw 'boom before the summary' }"
        "if (`$Mode -eq 'dirty') { Set-Content -LiteralPath (Join-Path `$PSScriptRoot 'left.txt') -Value x }"
        "if (`$Mode -eq 'root' -and (Get-Location).Path -ne `$PSScriptRoot) { Write-Host 'FAILED - self-test: not run from the copy''s root.'; exit 1 }"
        "if (`$a -eq 'alpha') { Write-Host 'OK - self-test passed: all 1 cases.'; exit 0 }"
        "Write-Host 'FAILED - self-test: 1 of 1 case(s) did not hold.'"
        'exit 1'
    ) -join "`n"
    $stubPath = Join-Path $repo 'stub.ps1'
    & $git init --quiet
    & $git config core.autocrlf false
    [IO.File]::WriteAllText($stubPath, "$stub`n")
    # A file git reads as binary, and an ignored one, which leaves the copy clean.
    [IO.File]::WriteAllBytes((Join-Path $repo 'bin.dat'), [byte[]] @(0x61, 0x62, 0x00, 0x63, 0x0A))
    Set-Content -LiteralPath (Join-Path $repo '.gitignore') -Value 'ignored.txt'
    Set-Content -LiteralPath (Join-Path $repo 'ignored.txt') -Value 'ignored one'
    Set-Content -LiteralPath (Join-Path $temp 'outside.txt') -Value 'outside one'
    & $git add stub.ps1 bin.dat .gitignore
    & $git commit --quiet -m stub
    $list = { param([string] $name, [string] $text) $p = Join-Path $temp "$name.psd1"; Set-Content -LiteralPath $p -Value $text; $p }
    $one = { param([string] $Find, [string] $Replace, [string] $More = '') "@{ Name = 'R'; File = 'stub.ps1'; Find = '$Find'; Replace = '$Replace'; SelfTest = 'stub.ps1'$More }" }
    $run = {
        param([string] $listPath)
        $text = & pwsh -NoProfile -File $PSCommandPath -Copy $repo -List $listPath 2>&1 | Out-String
        @{ Code = $LASTEXITCODE; Text = $text }
    }
    $same = { [IO.File]::ReadAllText($stubPath) -ceq "$stub`n" -and -not @(Get-DirtyPath -Root $repo) }

    $cases = @(
        @{ Name = 'Find occurring 0 times, twice, or only ignoring case is refused with the count, and so is an edit that changes no line; the file is unchanged'; Test = {
            $p = & $list 'count' "@{ Reverts = @( $(& $one 'zzz' 'y'), $(& $one "''alpha''" "''other''"), $(& $one "`$A = ''ALPHA''" 'y'), $(& $one "`$b = ''beta''" "`$b = ''beta''") ) }"
            $got = & $run $p
            Write-Host ($got.Text.TrimEnd() -replace '(?m)^', '    ')
            $got.Code -eq 0 -and @([regex]::Matches($got.Text, '(?m)^revert-run: R -- refused: Find occurs 0 times in stub\.ps1')).Count -eq 2 -and
                $got.Text -match '(?m)^revert-run: R -- refused: Find occurs 2 times in stub\.ps1' -and
                $got.Text -match '(?m)^revert-run: R -- refused: the edit changes no line' -and (& $same) } }
        @{ Name = 'an empty Find, a File outside the copy, ignored or named in another case, and a binary File are refused, and no file is changed'; Test = {
            $at = { param($file, $find) "@{ Name = 'R'; File = '$file'; Find = '$find'; Replace = 'zz'; SelfTest = 'stub.ps1' }" }
            $p = & $list 'refused' "@{ Reverts = @( $(& $at 'stub.ps1' ''), $(& $at '../outside.txt' 'outside'), $(& $at 'ignored.txt' 'ignored'), $(& $at 'STUB.PS1' 'alpha'), $(& $at 'bin.dat' 'ab') ) }"
            $got = & $run $p
            Write-Host ($got.Text.TrimEnd() -replace '(?m)^', '    ')
            $untouched = (Get-Content -LiteralPath (Join-Path $temp 'outside.txt') -Raw).Trim() -eq 'outside one' -and
                (Get-Content -LiteralPath (Join-Path $repo 'ignored.txt') -Raw).Trim() -eq 'ignored one' -and
                "$([IO.File]::ReadAllBytes((Join-Path $repo 'bin.dat')))" -eq '97 98 0 99 10'
            $got.Code -eq 0 -and $got.Text -match '(?m)^revert-run: R -- refused: Find is empty' -and
                @([regex]::Matches($got.Text, '(?m)^revert-run: R -- refused: \S+ is not a file git tracks in the copy under that name')).Count -eq 3 -and
                $got.Text -match '(?m)^revert-run: R -- refused: git reads bin\.dat as binary' -and $untouched -and (& $same) } }
        @{ Name = 'an edit changing two lines is refused with Lines unset, and runs with Lines = 2'; Test = {
            $two = { param($more) & $one "`$b = ''beta''`n`$c = ''gamma''" "`$b = ''x''`n`$c = ''y''" $more }
            $refused = & $run (& $list 'two' "@{ Reverts = @( $(& $two '') ) }")
            $allowed = & $run (& $list 'two-allowed' "@{ Reverts = @( $(& $two '; Lines = 2') ) }")
            Write-Host ($refused.Text.TrimEnd() -replace '(?m)^', '    ')
            $refused.Code -eq 0 -and $refused.Text -match '(?m)^revert-run: R -- refused: the edit changes 2 added and 2 removed lines, more than Lines = 1' -and
                $allowed.Code -eq 0 -and $allowed.Text -match '(?m)^revert-run: R -- passes \(exit 0\)' -and (& $same) } }
        @{ Name = 'a self-test that fails is reported fails, with its summary line'; Test = {
            $got = & $run (& $list 'fails' "@{ Reverts = @( $(& $one "`$a = ''alpha''" "`$a = ''other''") ) }")
            Write-Host ($got.Text.TrimEnd() -replace '(?m)^', '    ')
            $got.Code -eq 0 -and $got.Text -match '(?m)^revert-run: R -- fails \(exit 1\): FAILED - self-test: 1 of 1 case\(s\) did not hold\.' -and
                $got.Text -match '(?m)^\| R \| fails \| 1 \| FAILED - self-test: 1 of 1' -and $got.Text -match 'stub\.ps1 \| 2 \+-' -and (& $same) } }
        @{ Name = 'a self-test that passes is reported passes, run from the copy''s root'; Test = {
            $got = & $run (& $list 'passes' "@{ Reverts = @( $(& $one "`$b = ''beta''" "`$b = ''other''" "; Args = @('-Mode', 'root')") ) }")
            Write-Host ($got.Text.TrimEnd() -replace '(?m)^', '    ')
            $got.Code -eq 0 -and $got.Text -match '(?m)^revert-run: R -- passes \(exit 0\): OK - self-test passed' -and (& $same) } }
        @{ Name = 'a self-test that throws before its summary line is reported crashed, whatever its exit code'; Test = {
            $got = & $run (& $list 'crashed' "@{ Reverts = @( $(& $one "`$b = ''beta''" "`$b = ''other''" "; Args = @('-Mode', 'throw')") ) }")
            Write-Host ($got.Text.TrimEnd() -replace '(?m)^', '    ')
            $judged = @((Get-RevertResult -ExitCode 0 -Said 'no summary').Result, (Get-RevertResult -ExitCode 1 -Said 'OK - self-test passed: all 1 cases.').Result,
                (Get-RevertResult -ExitCode 0 -Said 'FAILED - self-test: 1 of 1').Result)
            # The last summary line is judged: one that runs another's self-test prints two.
            $last = Get-RevertResult -ExitCode 1 -Said "OK - self-test passed: all 2 cases.`nFAILED - self-test: 1 of 3 case(s) did not hold."
            $got.Code -eq 0 -and $got.Text -match '(?m)^revert-run: R -- crashed \(exit 1\): \r?$' -and "$judged" -eq 'crashed crashed crashed' -and
                $last.Result -eq 'fails' -and $last.Summary -eq 'FAILED - self-test: 1 of 3 case(s) did not hold.' -and (& $same) } }
        @{ Name = 'the file is restored after each revert, and a copy left dirty by one is caught before the next'; Test = {
            $both = "@{ Reverts = @( $(& $one "`$b = ''beta''" "`$b = ''other''" "; Args = @('-Mode', 'dirty')"), $(& $one "`$a = ''alpha''" "`$a = ''other''") ) }"
            $got = & $run (& $list 'dirty' $both)
            Write-Host ($got.Text.TrimEnd() -replace '(?m)^', '    ')
            $restored = [IO.File]::ReadAllText($stubPath) -ceq "$stub`n"
            Remove-Item -LiteralPath (Join-Path $repo 'left.txt') -ErrorAction SilentlyContinue
            $got.Code -eq 1 -and $got.Text -match 'after R the copy is left dirty, so no later revert was run: left\.txt' -and
                @([regex]::Matches($got.Text, '(?m)^revert-run: R -- ')).Count -eq 1 -and $restored -and (& $same) } }
        @{ Name = 'a copy with uncommitted changes at the start is refused, exit 1, and no revert is run'; Test = {
            [IO.File]::AppendAllText($stubPath, "# edited`n")
            try { $got = & $run (& $list 'start' "@{ Reverts = @( $(& $one "`$b = ''beta''" "`$b = ''other''") ) }") }
            finally { & $git checkout -q -- stub.ps1 }
            Write-Host ($got.Text.TrimEnd() -replace '(?m)^', '    ')
            $got.Code -eq 1 -and $got.Text -match 'has uncommitted changes, so no revert was run: stub\.ps1' -and $got.Text -notmatch '(?m)^revert-run: R -- ' -and (& $same) } }
        @{ Name = 'a Find with a line break matches a CRLF file, and one from a CRLF list an LF file, a file with a byte-order mark keeps it, and a list it cannot read, or one with no Reverts or a field missing, fails'; Test = {
            $crlf = Join-Path $temp 'crlf'
            New-Item -ItemType Directory -Path $crlf | Out-Null
            git -C $crlf init --quiet; git -C $crlf config core.autocrlf false
            [IO.File]::WriteAllText((Join-Path $crlf 'stub.ps1'), ($stub -replace "`n", "`r`n") + "`r`n")
            # With a byte-order mark: an edit that dropped it would change line 1 too.
            [IO.File]::WriteAllText((Join-Path $crlf 'bom.ps1'), "$stub`n", [Text.UTF8Encoding]::new($true))
            git -C $crlf add stub.ps1 bom.ps1; git -C $crlf -c user.name=s -c user.email=s@example.invalid -c commit.gpgsign=false commit --quiet -m stub
            $bom = "@{ Name = 'B'; File = 'bom.ps1'; Find = '`$c = ''gamma'''; Replace = '`$c = ''other'''; SelfTest = 'bom.ps1' }"
            $p = & $list 'crlf' "@{ Reverts = @( $(& $one "`$a = ''alpha''`n`$b = ''beta''" "`$a = ''other''`n`$b = ''beta''"), $bom ) }"
            $matched = & pwsh -NoProfile -File $PSCommandPath -Copy $crlf -List $p 2>&1 | Out-String
            Write-Host ($matched.TrimEnd() -replace '(?m)^', '    ')
            # A list saved with CRLF, its Find spanning two lines of the LF stub.
            $crlfList = & $list 'crlf-list' "@{ Reverts = @( $(& $one "`$a = ''alpha''`n`$b = ''beta''" "`$a = ''other''`n`$b = ''beta''") ) }"
            [IO.File]::WriteAllText($crlfList, ([IO.File]::ReadAllText($crlfList) -replace '\r?\n', "`r`n"))
            $fromCrlf = & $run $crlfList
            $broken = & $run (& $list 'broken' '@{ Reverts = ')
            $empty = & $run (& $list 'empty' '@{ Other = 1 }')
            $field = & $run (& $list 'field' "@{ Reverts = @( @{ Name = 'R'; File = 'stub.ps1' } ) }")
            $matched -match '(?m)^revert-run: R -- fails \(exit 1\)' -and $matched -match '(?m)^revert-run: B -- passes \(exit 0\)' -and
                $fromCrlf.Text -match '(?m)^revert-run: R -- fails \(exit 1\)' -and (& $same) -and
                $broken.Code -eq 1 -and $broken.Text -match 'cannot be read' -and $empty.Code -eq 1 -and $empty.Text -match 'holds no Reverts' -and
                $field.Code -eq 1 -and $field.Text -match 'lacks Find, Replace, SelfTest' } }
    )

    $failures = 0
    $n = 0
    try {
        foreach ($c in $cases) {
            $n++
            $ok = try { [bool] (& $c.Test) } catch { Write-Host "    threw: $($_.Exception.Message)"; $false }
            Write-Host ("self-test {0}/{1}: {2} -- {3}" -f $n, $cases.Count, $c.Name, $(if ($ok) { 'ok' } else { 'FAILED' }))
            if (-not $ok) { $failures++ }
        }
    }
    finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $($cases.Count) case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $($cases.Count) cases."
    exit 0
}

if ($SelfTest) { Invoke-SelfTest }

try { $rows = @(Invoke-RevertRun -Root (Resolve-Path -LiteralPath $Copy).Path -ListPath $List) }
catch { Write-Host "FAILED - revert-run: $($_.Exception.Message)"; exit 1 }
$counts = ($rows | ForEach-Object { $_.Result } | Group-Object | Sort-Object Name | ForEach-Object { "$($_.Count) $($_.Name)" }) -join ', '
Write-Host "OK - revert-run: $($rows.Count) revert(s) run or refused: $counts."
exit 0
