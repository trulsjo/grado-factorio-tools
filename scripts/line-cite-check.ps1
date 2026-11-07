<#
.SYNOPSIS
    Reads the tracked files -Path names and fails on each citation of one of this repository's
    own files by line number. Exit 0 means none was found, and that each floor given was met.

.DESCRIPTION
    WHY (grado-factorio-tools#347, #319 rulings 5 and 8). A line number is a claim about a file
    that nothing reads, and it goes wrong silently when anyone adds a line above what it points
    at. realistic-fusion-refreshed found the same rot in twelve documents, ten stale by more than
    a hundred lines (its #69, ADR 0032). The repair is to name the function, field or constant,
    which grep can check. This is the matcher of that repository's ship-check.ps1 section 7, at
    4de346d; what counts as its own code there, its archives, vanilla and the game's output, is a
    parameter here, so an ancestor's, vanilla's or a third party's citation by line can pass.

    WHAT IS MATCHED. Two shapes, on one line at a time.
      1. A path and a line, as example/run.ps1:12 or example/a.md:3-9: a path token ending in .lua,
         .ps1, .py, .js, .json or .md, with :N or :N-M after it.
      2. A backticked continuation, `:155` alone in backticks, which inherits the last path token
         before it on the same line. The backticks are required: bare, a colon and a number cannot
         be told from a page range, a ratio or a time.
    A citation is of our own code only when its path resolves to exactly one of the files -Own
    names: the path itself, or one ending in / and the path. A bare name that several files
    share is left, as which is meant cannot be decided here.

    WHAT IS LEFT ALONE. A line -Foreign matches, whole, which is how a repository passes the
    lines that quote an ancestor, vanilla or the game's own output, and with it any continuation
    on it. A file -Own does not name. A line number in running prose, "lines 196-197", with no
    path and no colon: no pattern can trust it, so reading is what finds those.

    THE FLOORS. Both shapes pass by finding nothing, so a pattern that stopped matching would
    pass while checking nothing. -MinCitations and -MinContinuations, when given, fail a run that
    found fewer of each shape, ours or not; a repository sets them below what its tree holds.

    WHAT IT CANNOT SEE. A continuation whose path is on an earlier line; and per line it can also
    take a third party's continuation for ours, where a path of ours stands before it on the
    line. A citation in a file -Path does not name, or not tracked. Whether a cited line is still
    the one meant: it fails every own citation, stale or not. -SelfTest runs the matcher on a
    scratch repository; the script's own call of it, and its exit, are not run.

    WHERE IT RUNS. In CI, a whole-tree check (#319 ruling 8).

.PARAMETER Path
    The git pathspecs of the files to read, as globs from the repository root. The tracked .md,
    .lua, .ps1, .py and .js files unless given.

.PARAMETER Own
    The git pathspecs of the files that are our own code, which a citation must resolve to one of
    to fail. Every tracked file unless given.

.PARAMETER Foreign
    A regular expression; a line it matches is left alone. None unless given.

.PARAMETER MinCitations
    The fewest path-and-line citations, ours or not, a run must find. 0 unless given.

.PARAMETER MinContinuations
    The fewest backticked continuations, ours or not, a run must find. 0 unless given.

.PARAMETER SelfTest
    Run the cases, on a scratch repository, and nothing else. Needs git.

.EXAMPLE
    pwsh -File scripts/line-cite-check.ps1 -Foreign '__|Script @|ORIG/|PORT/|_reference/|RealisticFusion|(?<![\w-])base/' -MinCitations 10 -MinContinuations 8
#>

#Requires -Version 7
param(
    [string[]] $Path = @('**/*.md', '**/*.lua', '**/*.ps1', '**/*.py', '**/*.js'),
    [string[]] $Own = @('**'),
    [string] $Foreign = '',
    [int] $MinCitations = 0,
    [int] $MinContinuations = 0,
    [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'
# git's paths are UTF-8; read in the console's code page, a non-ASCII name names no file.
[Console]::OutputEncoding = [Text.Encoding]::UTF8
# A list handed through pwsh -File arrives as one string.
$Path = @($Path | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$Own = @($Own | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

# A path token, with the line number optional so a continuation can inherit one that carries none.
# The extension ends the word: with js tried first and nothing after, a .json path matched as .js
# with no line, so no .json citation was seen (PR #374's review, bug finding 6).
$OWN_PATH = '(?<![\w./-])([\w./-]+\.(?:lua|ps1|py|json|js|md)(?!\w))(:\d+(?:-\d+)?)?'
$OWN_CONT = '`:(\d+(?:-\d+)?)`'

# The check over the repository at $Root, as its exit code and the lines it prints.
function Invoke-LineCiteCheck {
    param([Parameter(Mandatory)] [string] $Root, [Parameter(Mandatory)] [string[]] $Path,
        [Parameter(Mandatory)] [string[]] $Own, [string] $Foreign = '', [int] $MinCitations = 0, [int] $MinContinuations = 0)
    $list = { param([string[]] $specs) @("$(git -C $Root -c core.quotePath=false ls-files -z -- @($specs | ForEach-Object { ":(glob)$_" }))".Split("`0") | Where-Object { $_ }) }
    $files = & $list $Path
    if ($LASTEXITCODE) { throw "git could not list the files of $Root." }
    if (-not $files) { return @{ Code = 1; Lines = @("FAILED - line-cite-check: no tracked file for $($Path -join ', '), so nothing was read.") } }
    $owned = & $list $Own
    # A path is ours when exactly one own file is it or ends in / and it.
    $ours = { param([string] $p) @($owned | Where-Object { $_ -ceq $p -or $_.EndsWith('/' + $p, [StringComparison]::Ordinal) }).Count -eq 1 }
    $found = [System.Collections.Generic.List[string]]::new()
    $cites = 0; $conts = 0; $read = 0
    foreach ($f in $files) {
        $full = Join-Path $Root $f
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
        $read++
        $n = 0
        foreach ($line in [IO.File]::ReadAllLines($full)) {
            $n++
            if ($Foreign -and $line -match $Foreign) { continue }
            foreach ($m in [regex]::Matches($line, $OWN_PATH)) {
                if (-not $m.Groups[2].Success) { continue }
                $cites++
                if (& $ours $m.Groups[1].Value) { $found.Add("$($f):$($n): cites $($m.Value) by line number") }
            }
            foreach ($m in [regex]::Matches($line, $OWN_CONT)) {
                $conts++
                $before = [regex]::Matches($line.Substring(0, $m.Index), $OWN_PATH)
                if (-not $before.Count) { continue }
                $p = $before[$before.Count - 1].Groups[1].Value
                if (& $ours $p) { $found.Add("$($f):$($n): cites $($m.Value), inheriting $p, by line number") }
            }
        }
    }
    $short = @()
    if ($cites -lt $MinCitations) { $short += "it found $cites path-and-line citation(s), under the floor of $MinCitations, so the pattern may have stopped matching" }
    if ($conts -lt $MinContinuations) { $short += "it found $conts backticked continuation(s), under the floor of $MinContinuations, so the pattern may have stopped matching" }
    if ($found.Count -or $short) {
        $lines = @($found) + @($short | ForEach-Object { "line-cite-check: $_." })
        if ($found.Count) { $lines += 'Name the function, field, constant or section instead: a line number goes stale silently.' }
        return @{ Code = 1; Lines = $lines + "FAILED - line-cite-check: $($found.Count) citation(s) of our own code by line number in $read file(s)$(if ($short) { ', and a floor not met' })." }
    }
    @{ Code = 0; Lines = @("OK - line-cite-check: $read file(s) read, $cites path-and-line citation(s) and $conts continuation(s) found, none of our own code.") }
}

if ($SelfTest) {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "line-cite-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    $repo = Join-Path $temp 'repo'
    $file = { param($name, [string[]] $text)
        $at = Join-Path $repo $name; New-Item -ItemType Directory -Path (Split-Path $at) -Force | Out-Null
        Set-Content -LiteralPath $at -Value $text }
    $run = { param([string[]] $Path = @('**/*.md', '**/*.lua', '**/*.ps1'), [string[]] $Own = @('**'), [string] $Foreign = '', [int] $MinCitations = 0, [int] $MinContinuations = 0)
        Invoke-LineCiteCheck -Root $repo -Path $Path -Own $Own -Foreign $Foreign -MinCitations $MinCitations -MinContinuations $MinContinuations }
    try {
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        git -C $repo init --quiet; if ($LASTEXITCODE) { throw 'git init failed; the self-test needs git.' }
        # Two data.lua, so a bare one is ambiguous; one probe-entry.lua; a vendored copy of tools.
        & $file 'mod/probe-entry.lua' 'x = 1'; & $file 'mod/data.lua' 'y = 1'; & $file 'old/data.lua' 'z = 1'
        & $file 'vendor/lib.ps1' '# lib'; & $file 'docs/a.md' 'start'
        $cases = [ordered]@{
            'a path and a line that resolve to one file fail, by file and line; an ambiguous name and a bare page range do not' = {
                & $file 'docs/a.md' 'See mod/probe-entry.lua:12 and probe-entry.lua:3-4.', 'Not data.lua:5, nor a range 11(2):109-125.'
                git -C $repo add -A
                $end = & $run
                $end.Code -eq 1 -and ($end.Lines[0..1] -join '|') -eq 'docs/a.md:1: cites mod/probe-entry.lua:12 by line number|docs/a.md:1: cites probe-entry.lua:3-4 by line number' -and
                    $end.Lines[-1] -eq 'FAILED - line-cite-check: 2 citation(s) of our own code by line number in 5 file(s).' }
            'a backticked continuation inherits the last path before it on its line; a bare one, and one with no path before it, do not' = {
                & $file 'docs/a.md' 'In mod/data.lua, then mod/probe-entry.lua at `:155`.', 'Alone `:9`, and bare :12 after mod/probe-entry.lua.'
                git -C $repo add -A
                $end = & $run
                ($end.Lines[0..($end.Lines.Count - 3)] -join '|') -eq 'docs/a.md:1: cites `:155`, inheriting mod/probe-entry.lua, by line number' }
            '-Foreign leaves a whole line alone, its continuation too, and -Own leaves a file that is not ours' = {
                & $file 'docs/a.md' 'The archive: ORIG/probe-entry.lua:40 and mod/probe-entry.lua `:7`.', 'Vendored: vendor/lib.ps1:3.'
                git -C $repo add -A
                $foreign = & $run -Foreign 'ORIG/'
                $own = & $run -Foreign 'ORIG/' -Own 'mod/**', 'old/**', 'docs/**'
                ($foreign.Lines[0..($foreign.Lines.Count - 3)] -join '|') -eq 'docs/a.md:2: cites vendor/lib.ps1:3 by line number' -and
                    $own.Code -eq 0 -and $own.Lines[-1] -match '^OK - line-cite-check: 5 file\(s\) read, 1 path-and-line citation\(s\) and 0 continuation\(s\) found' }
            'a floor fails a run that found fewer of a shape, ours or not, and passes one at it' = {
                & $file 'docs/a.md' 'Ancestor ORIG/x.lua:1 and `:2`.'
                git -C $repo add -A
                $at = & $run -MinCitations 1 -MinContinuations 1 -Own 'mod/**'
                $under = & $run -MinCitations 2 -MinContinuations 2 -Own 'mod/**'
                $at.Code -eq 0 -and $under.Code -eq 1 -and
                    ($under.Lines -join '|') -match 'found 1 path-and-line citation\(s\), under the floor of 2' -and
                    ($under.Lines -join '|') -match 'found 1 backticked continuation\(s\), under the floor of 2' -and
                    $under.Lines[-1] -eq 'FAILED - line-cite-check: 0 citation(s) of our own code by line number in 5 file(s), and a floor not met.' }
            'a .json path is a citation, a non-ASCII name is read, a tracked file gone from disk is not counted, and a floor-only failure gives no renaming advice (#374)' = {
                & $file 'docs/a.md' 'start'; & $file 'mod/table.json' '{}'; & $file 'docs/bløkk ø.md' 'See mod/table.json:4.'
                & $file 'docs/gone.md' 'x'; git -C $repo add -A; Remove-Item -LiteralPath (Join-Path $repo 'docs/gone.md')
                $end = & $run
                $floor = & $run -Own 'none/**' -MinCitations 5
                git -C $repo rm --cached --quiet mod/table.json 'docs/bløkk ø.md' docs/gone.md
                Remove-Item -LiteralPath (Join-Path $repo 'mod/table.json'), (Join-Path $repo 'docs/bløkk ø.md')
                $end.Lines[0] -eq 'docs/bløkk ø.md:1: cites mod/table.json:4 by line number' -and
                    $end.Lines[-1] -eq 'FAILED - line-cite-check: 1 citation(s) of our own code by line number in 6 file(s).' -and
                    $floor.Code -eq 1 -and -not ($floor.Lines -match '^Name the function') }
            'a -Path that names no tracked file fails, saying it read nothing' = {
                $end = & $run -Path '**/*.txt'
                $end.Code -eq 1 -and $end.Lines[0] -eq 'FAILED - line-cite-check: no tracked file for **/*.txt, so nothing was read.' }
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

$root = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -or -not $root) { Write-Host 'FAILED - line-cite-check: not in a git repository, so nothing was read.'; exit 1 }
$end = Invoke-LineCiteCheck -Root $root -Path $Path -Own $Own -Foreign $Foreign -MinCitations $MinCitations -MinContinuations $MinContinuations
$end.Lines | ForEach-Object { Write-Host $_ }
exit $end.Code
