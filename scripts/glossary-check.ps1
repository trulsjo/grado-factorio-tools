<#
.SYNOPSIS
    Reports each use, in the lines a commit range adds to tracked Markdown, of a word that
    GLOSSARY.md lists on an `_Avoid_` line: <file>:<line>: the word, and the term that avoids it.
    Over a range it fails on a use that is not marked deliberate: exit 1 if it reports one. It fails
    too on a GLOSSARY.md that gives it no word to match, which is a run that read nothing.

.DESCRIPTION
    WHERE IT CAME FROM (grado-factorio-tools#348, #319 ruling 7). grado-factorio-modpack's
    scripts/glossary-check.ps1 at bf4b121, read 2026-11-06. What changed in the move: the words left
    to the reviewer, a list in the modpack's script, are -Left, since each repository has its own;
    and the self-test names no file of that repository.

    WHY (grado-factorio-modpack#164). A GLOSSARY.md gives most terms an `_Avoid_` line, and nothing
    read new prose against them. On the modpack's PR #163 (2026-10-06) a later review found
    "confirms" in new text, a word its *Measured* avoids, after the first review had passed it.

    WHY IT FAILS (grado-factorio-modpack#198). Until 2026-10-09 it reported and exited 0, and left
    each use to the reviewer. On the modpack's PR #193 a reported use was judged not wrong and left
    with no marker, and only added lines are read, so that use is not reported again while its line
    stands. Now a reported use is reworded or marked, and whether a marker is honest is the
    reviewer's.

    WHAT RUNS IT. A consumer's CI, over a pull request's commits, with the self-test. Here,
    .github/workflows/check.yml's step and scripts/check.ps1, and so the pre-push hook, each over
    origin/main...HEAD with -LeftFile glossary-left.txt (grado-factorio-tools#443): PR #437 and PR
    #438 passed the hook and went red in CI on an avoided word.

    WHAT IT READS AS WHAT. GLOSSARY.md is read as it is at the end of the range. A term is a line
    opening `**Term**:`, and its avoid line runs from `_Avoid_:` to the next blank line. A remark in
    parentheses belongs to the entry before it and is dropped; what is left is split at every comma
    and semicolon, and `a/b` is two words. A word ending in -ed is matched in its other verb forms
    too (confirmed: confirm, confirms, confirming), and any other with a plural -s. Case is not
    read. Only added lines are read, as they are at the end of the range, and nothing inside a
    fenced code block.

    WHICH ENTRIES IT DOES NOT MATCH. -List prints them, each with why, from the glossary as it is:
    an entry that carries a condition ("above/below without saying of what", a quoted word "for" or
    "as" something) takes a reader, and so does a word -Left names, which is in ordinary use in that
    repository and avoided only as a word for one term.

    A DELIBERATE USE IS MARKED on its own line with an HTML comment naming the word as it stands
    there: <!-- deliberate: confirms -->. A marked use is not reported. A word inside double quotes
    or a code span is being mentioned and is not reported either.

    WHAT FAILS WITH NOTHING READ (grado-factorio-modpack#362). A GLOSSARY.md that git cannot read at
    the range's end: exit 1 in every mode but -SelfTest. One that is empty, and one with no
    `_Avoid_` entry whose word is matched: exit 1 with -Range and -All, since there is no word to
    read a line against. -List still prints what it found and exits 0, since it lists and shows why
    an entry is not matched. A range that adds no Markdown line passes, and says it read no file:
    that run had nothing to check. A -LeftFile not there, one that leaves no word, or one with a
    line giving no why: exit 1. An end of -Range git cannot resolve, as an origin/main never
    fetched: exit 1, naming it.

    WHAT IT CANNOT SEE. Whether a use is wrong. A phrase or a quotation broken over two lines. A
    line that was moved and not changed is reported as added. GLOSSARY.md itself, where the words
    are listed. An irregular verb form (read, chose). Markdown outside `.md` files.

.PARAMETER Range
    Read the lines a commit range adds: -Range origin/main...HEAD. Three dots over a branch: two
    would compare the two tips, and judge a branch behind `main` on what `main` changed since.

.PARAMETER All
    Read every line of every tracked Markdown file, as at HEAD. For measuring how often a word is
    used: it counts and does not fail on a use.

.PARAMETER List
    Print the avoid entries that are matched and those that are not, with why.

.PARAMETER Left
    The words left to the reviewer: a dictionary of patterns, each matched against one word of an
    entry as it stands in a line, to why it is left. A dictionary binds when the script is run from
    PowerShell, as a step with `shell: pwsh` runs it, not through `pwsh -File`. Empty unless given.

.PARAMETER LeftFile
    The words left to the reviewer, read from a file, so a run through `pwsh -File` can give them: a
    pattern and its why to a line, split at the first space, with blank lines and `#` lines skipped.
    Added to -Left, which wins on a pattern both name. This repository's is glossary-left.txt.

.PARAMETER SelfTest
    Prove an avoided word is reported and that a clean line, a marked use, a mention and a word
    -Left names pass, and that over a range the script exits 1 on an unmarked use, 0 once it is
    marked and 0 where the range only removes lines, and 1 where GLOSSARY.md has no matched
    `_Avoid_` entry, is empty or is missing, while -List on the unmatched one exits 0 and says why;
    and that -LeftFile leaves the words it names over a range and no other, and that a file missing,
    empty or with no why, an end of the range not there, each exit 1, where a range that adds
    nothing exits 0 saying so. Those three cases need git.

.EXAMPLE
    From a CI step whose shell is pwsh, with the words left to the reviewer:

        ./vendor/grado-factorio-tools/scripts/glossary-check.ps1 -Range origin/main...HEAD -Left ([ordered] @{ '^mods?$' = 'what every member is; avoided only as a word for a pack' })

.EXAMPLE
    With the words left read from a file, as this repository's CI and check.ps1 run it:

        pwsh -File scripts/glossary-check.ps1 -Range origin/main...HEAD -LeftFile glossary-left.txt

.EXAMPLE
    With none left:

        pwsh -File scripts/glossary-check.ps1 -Range origin/main...HEAD
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $Range,
    [switch] $All,
    [switch] $List,
    [System.Collections.IDictionary] $Left = @{},
    [string] $LeftFile,
    [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

function Get-Avoided {
    <#  The avoid entries of a glossary, each as @{ Term; Entry; Pattern; Why }. Why is set on an
        entry that is not matched, and Pattern on one that is.  #>
    param([Parameter(Mandatory)] [AllowEmptyString()] [string[]] $Glossary)

    $term = $null
    for ($i = 0; $i -lt $Glossary.Count; $i++) {
        if ($Glossary[$i] -match '^\*\*(.+?)\*\*:') { $term = $Matches[1]; continue }
        if ($Glossary[$i] -notmatch '^_Avoid_:\s*(.*)$') { continue }
        $text = $Matches[1]
        while ($i + 1 -lt $Glossary.Count -and $Glossary[$i + 1] -match '\S' -and $Glossary[$i + 1] -notmatch '^(\*\*|#)') { $text += ' ' + $Glossary[++$i] }
        do { $before = $text; $text = $text -replace '\s*\([^()]*\)' } while ($text -ne $before)
        foreach ($entry in $text -split '[,;]' | ForEach-Object { $_.Trim() -replace '^(and|or)\s+' } | Where-Object { $_ }) {
            $words = @(($entry -replace '"').ToLowerInvariant() -split '/')
            $key = $Left.Keys | Where-Object { $words -match $_ } | Select-Object -First 1
            $why = if ($entry -match '^"[^"]+"\s+\S|\s(without|for|as)\s|\son its own$') { 'carries a condition, which takes a reader' }
                elseif ($key) { $Left[$key] }
            $forms = foreach ($w in $words) {
                $escaped = [regex]::Escape($w) -replace '\\ ', '\s+'
                if ($w -match 'ied$') { ($escaped -replace 'ied$') + '(?:y|ies|ied|ying)' }
                elseif ($w -match 'ed$') { ($escaped -replace 'ed$') + '(?:e|es|ed|s|ing)?' }
                else { $escaped + 's?' }
            }
            @{ Term = $term; Entry = $entry; Why = $why; Pattern = "(?<![\w-])(?:$($forms -join '|'))(?![\w-])" }
        }
    }
}

function Find-Avoided {
    <#  The uses of a matched avoid entry on the numbered lines of one file, each as @{ Line; Word;
        Term; Entry }.  #>
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Lines,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [int[]] $Numbers,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [hashtable[]] $Avoided
    )

    $fenced = [bool[]]::new($Lines.Count + 1)
    $fence = $null
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $fenced[$i + 1] = $true
        if ($fence) { if ($Lines[$i] -match "^\s*$([regex]::Escape($fence))+\s*$") { $fence = $null } }
        elseif ($Lines[$i] -match '^\s*(`{3,}|~{3,})') { $fence = $Matches[1] }
        else { $fenced[$i + 1] = $false }
    }
    foreach ($n in $Numbers | Where-Object { $_ -le $Lines.Count -and -not $fenced[$_] }) {
        $line = $Lines[$n - 1]
        $marked = if ($line -match '<!--\s*deliberate:\s*(.*?)\s*-->') { $Matches[1].ToLowerInvariant() -split '\s*,\s*' } else { @() }
        $prose = $line -replace '<!--.*?-->|`[^`]*`|"[^"]*"|“[^”]*”'
        foreach ($a in $Avoided | Where-Object { -not $_.Why }) {
            foreach ($m in [regex]::Matches($prose, $a.Pattern, 'IgnoreCase')) {
                $word = $m.Value.ToLowerInvariant()
                if ($word -in $marked -or ($Left.Keys | Where-Object { $word -match $_ })) { continue }
                @{ Line = $n; Word = $m.Value; Term = $a.Term; Entry = $a.Entry }
            }
        }
    }
}

if ($SelfTest) {
    $glossary = "**Measured**:", "Run and written down.", "_Avoid_: confirmed, verified (neither says", "which grade), `"measured`" for anything undated", "", "**Portal entry**:", "A page.", "_Avoid_: portal page, above/below without saying of what"
    $avoided = @(Get-Avoided -Glossary $glossary)
    $find = { param([string] $text) $lines = $text -split "`n"; @(Find-Avoided -Lines $lines -Numbers (1..$lines.Count) -Avoided $avoided | ForEach-Object { "$($_.Line): $($_.Word) ($($_.Term))" }) }
    # A case passes on one output, $true (#419). Any other output fails it, saying
    # why: [bool] of two values or more is true whatever they are, so a case that
    # leaked a line passed on a false verdict.
    $judgeCase = {
        param([scriptblock] $CaseBlock)
        $caseOutput = @(& $CaseBlock)
        if ($caseOutput.Count -ne 1) { Write-Host "    gave $($caseOutput.Count) values, not one [bool]"; return $false }
        if ($caseOutput[0] -isnot [bool]) { Write-Host "    gave $($null -eq $caseOutput[0] ? '$null' : $caseOutput[0].GetType().Name), not a [bool]"; return $false }
        $caseOutput[0]
    }
    # A case that leaks a value, judged by the loop's own line, which must fail it:
    # so a loop put back to [bool] of the whole output fails the run (#419).
    $leakCase = 'the loop fails a case giving $null and then $false (#419); ok here means it was failed'
    $cases = @(
        @{ Name = $leakCase; Test = { $null; $false } }
        @{ Name = 'a case passes on one $true; two values, a string or none fail it, and say so (#419)'; Test = {
            (& $judgeCase { $true }) -eq $true -and (& $judgeCase { $false }) -eq $false -and
                "$(& $judgeCase { $null; $true } 6>&1)" -ceq '    gave 2 values, not one [bool] False' -and
                "$(& $judgeCase { 'x' } 6>&1)" -ceq '    gave String, not a [bool] False' -and "$(& $judgeCase { } 6>&1)" -ceq '    gave 0 values, not one [bool] False' }}
        @{ Name = 'an avoided word is reported with its line and its term, in another verb form too'; Test = {
            $f = @(& $find "fine`nThe load confirms it, and was Verified on the portal pages.")
            $f.Count -eq 3 -and $f[0] -eq '2: confirms (Measured)' -and $f[1] -eq '2: Verified (Measured)' -and $f[2] -eq '2: portal pages (Portal entry)' } }
        @{ Name = 'a clean line passes, and so does a longer word that holds an avoided one'; Test = {
            @(& $find 'The load was measured on 2026-10-08; the confirmation is a step.').Count -eq 0 } }
        @{ Name = 'a marked use is not reported, and an unmarked word beside it still is'; Test = {
            $f = @(& $find 'The reviewer confirms its fix, verified. <!-- deliberate: confirms -->')
            $f.Count -eq 1 -and $f[0] -eq '1: verified (Measured)' } }
        @{ Name = 'a word in double quotes, in a code span or inside a fence is not reported'; Test = {
            @(& $find ('An old "confirmed" and `verified` are mentions.', '', '```', 'it confirms', '```' -join "`n")).Count -eq 0 } }
        @{ Name = 'an entry with a condition is listed as not matched, and a remark in parentheses is no entry'; Test = {
            $unmatched = @($avoided | Where-Object Why | ForEach-Object Entry)
            $avoided.Count -eq 5 -and $unmatched.Count -eq 2 -and $unmatched[0] -eq '"measured" for anything undated' -and $unmatched[1] -eq 'above/below without saying of what' } }
        @{ Name = 'a word -Left names is listed as not matched with its why, and is not reported in any form, where one -Left does not name still is'; Test = {
            $Left = [ordered] @{ '^verified$' = 'left here on purpose' }
            $withLeft = @(Get-Avoided -Glossary $glossary)
            $leftEntry = @($withLeft | Where-Object Why | Where-Object Entry -eq 'verified')
            $f = @(Find-Avoided -Lines 'It was verified, and it confirms.' -Numbers 1 -Avoided $withLeft | ForEach-Object Word)
            $leftEntry.Count -eq 1 -and $leftEntry[0].Why -eq 'left here on purpose' -and $f.Count -eq 1 -and $f[0] -eq 'confirms' } }
        @{ Name = 'over a range the script exits 1 on an unmarked use and names it, in a file whose name holds a space, 0 once the use is marked, and 0 where a file only loses the line below an unmarked use, saying it read no line'; Test = {
            $temp = Join-Path ([IO.Path]::GetTempPath()) "glossary-check-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
            New-Item -ItemType Directory -Path $temp -Force | Out-Null
            try {
                $git = { git -C $temp -c user.name=selftest -c user.email=selftest@example.invalid -c core.autocrlf=false -c commit.gpgsign=false @args | Out-Null; if ($LASTEXITCODE -ne 0) { throw "git $args failed; the self-test needs git." } }
                $commit = { param([string] $text) Set-Content -LiteralPath (Join-Path $temp 'a b.md') -Value ($text -split "`n"); & $git add -A; & $git commit --quiet -m x }
                $run = { param([string] $range) Push-Location $temp; try { $text = (& pwsh -NoProfile -File $PSCommandPath -Range $range 2>&1 | Out-String) } finally { Pop-Location }; @{ Code = $LASTEXITCODE; Text = $text } }
                & $git init --quiet
                Set-Content -LiteralPath (Join-Path $temp 'GLOSSARY.md') -Value $glossary
                & $commit 'fine'
                & $commit "fine`nIt was verified."
                & $commit "fine`nIt was verified. <!-- deliberate: verified -->"
                # An unmarked use an earlier commit added, then the line below it removed: a hunk
                # of +1,0 read as one line would report it.
                & $commit "It was verified.`nfine"
                & $commit 'It was verified.'
                $red = & $run 'HEAD~4..HEAD~3'
                $green = & $run 'HEAD~4..HEAD~2'
                $removed = & $run 'HEAD~1..HEAD'
                Write-Host ($red.Text.TrimEnd() -replace '(?m)^', '    ')
                if ($removed.Code -ne 0) { Write-Host ($removed.Text.TrimEnd() -replace '(?m)^', '    ') }
                $red.Code -eq 1 -and $red.Text -match '(?m)^a b\.md:2: "verified"' -and $green.Code -eq 0 -and $removed.Code -eq 0 -and
                    $removed.Text -match 'OK - glossary-check: HEAD~1\.\.HEAD adds no line to a Markdown file but GLOSSARY\.md, so none was read'
            }
            finally { Remove-Item -LiteralPath $temp -Recurse -Force }
        } }
        @{ Name = 'over a range the script exits 1, saying so, where GLOSSARY.md has no _Avoid_ line it matches, is empty or is missing, and -List on the unmatched one prints why and exits 0'; Test = {
            $temp = Join-Path ([IO.Path]::GetTempPath()) "glossary-check-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
            New-Item -ItemType Directory -Path $temp -Force | Out-Null
            try {
                $git = { git -C $temp -c user.name=selftest -c user.email=selftest@example.invalid -c core.autocrlf=false -c commit.gpgsign=false @args | Out-Null; if ($LASTEXITCODE -ne 0) { throw "git $args failed; the self-test needs git." } }
                $commit = { param([string[]] $lines) Set-Content -LiteralPath (Join-Path $temp 'GLOSSARY.md') -Value $lines; Add-Content -LiteralPath (Join-Path $temp 'a.md') -Value 'It was verified.'; & $git add -A; & $git commit --quiet -m x }
                $run = { param([string] $range) Push-Location $temp; try { $text = (& pwsh -NoProfile -File $PSCommandPath -Range $range 2>&1 | Out-String) } finally { Pop-Location }; @{ Code = $LASTEXITCODE; Text = $text } }
                & $git init --quiet
                & $commit $glossary
                & $commit '**Measured**:', 'Run and written down.'
                & $commit '**Portal entry**:', '_Avoid_: above/below without saying of what'
                Push-Location $temp; try { $listed = (& pwsh -NoProfile -File $PSCommandPath -List 2>&1 | Out-String); $listedCode = $LASTEXITCODE } finally { Pop-Location }
                & $commit @()
                & $git rm --quiet GLOSSARY.md
                Add-Content -LiteralPath (Join-Path $temp 'a.md') -Value 'Verified again.'
                & $git add -A
                & $git commit --quiet -m x
                $none = & $run 'HEAD~4..HEAD~3'
                $unmatched = & $run 'HEAD~3..HEAD~2'
                $empty = & $run 'HEAD~2..HEAD~1'
                $missing = & $run 'HEAD~1..HEAD'
                foreach ($r in $none, $unmatched, $empty, $missing) { if ($r.Code -ne 1) { Write-Host ($r.Text.TrimEnd() -replace '(?m)^', '    ') } }
                if ($listedCode -ne 0) { Write-Host ($listed.TrimEnd() -replace '(?m)^', '    ') }
                $listedCode -eq 0 -and $listed -match 'above/below without saying of what -- carries a condition' -and
                    $none.Code -eq 1 -and $none.Text -match 'FAILED - glossary-check: GLOSSARY\.md at HEAD~3 has no _Avoid_ entry' -and
                    $unmatched.Code -eq 1 -and $unmatched.Text -match 'has no _Avoid_ entry' -and
                    $empty.Code -eq 1 -and $empty.Text -match 'has no _Avoid_ entry' -and
                    $missing.Code -eq 1 -and $missing.Text -match 'FAILED - glossary-check: git could not read GLOSSARY\.md at HEAD'
            }
            finally { Remove-Item -LiteralPath $temp -Recurse -Force }
        } }
        @{ Name = 'over a range -LeftFile leaves the words it names and no other, a missing or empty file or one with no why fails, an end not there fails, and an empty range says it read nothing (#443)'; Test = {
            $temp = Join-Path ([IO.Path]::GetTempPath()) "glossary-check-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
            New-Item -ItemType Directory -Path $temp -Force | Out-Null
            try {
                $git = { git -C $temp -c user.name=selftest -c user.email=selftest@example.invalid -c core.autocrlf=false -c commit.gpgsign=false @args | Out-Null; if ($LASTEXITCODE -ne 0) { throw "git $args failed; the self-test needs git." } }
                $commit = { param([string] $text) Set-Content -LiteralPath (Join-Path $temp 'a.md') -Value ($text -split "`n"); & $git add -A; & $git commit --quiet -m x }
                $run = { param([string] $range, [string] $file) Push-Location $temp; try { $text = (& pwsh -NoProfile -File $PSCommandPath -Range $range -LeftFile $file 2>&1 | Out-String) } finally { Pop-Location }; @{ Code = $LASTEXITCODE; Text = $text } }
                $leftFile = { param([string] $name, [string[]] $lines) $p = Join-Path ([IO.Path]::GetTempPath()) "$name-$([guid]::NewGuid().ToString('N').Substring(0, 8)).txt"; Set-Content -LiteralPath $p -Value $lines; $p }
                & $git init --quiet
                Set-Content -LiteralPath (Join-Path $temp 'GLOSSARY.md') -Value $glossary
                & $commit 'fine'
                & $commit "fine`nIt was verified."
                & $commit "fine`nIt was verified.`nIt confirms."
                & $git commit --quiet --allow-empty -m empty
                $left = & $leftFile 'left' '# why each is left', '^verified$ left here on purpose'
                $files = @($left, (& $leftFile 'empty' '# a comment and nothing else'), (& $leftFile 'nowhy' '^verified$'))
                try {
                    $leftOne = & $run 'HEAD~3..HEAD~2' $left
                    $other = & $run 'HEAD~2..HEAD~1' $left
                    $missing = & $run 'HEAD~3..HEAD~2' (Join-Path $temp 'not-there.txt')
                    $empty = & $run 'HEAD~3..HEAD~2' $files[1]
                    $noWhy = & $run 'HEAD~3..HEAD~2' $files[2]
                    $noEnd = & $run 'not-there...HEAD' $left
                    $nothing = & $run 'HEAD~1..HEAD' $left
                }
                finally { Remove-Item -LiteralPath $files -Force -ErrorAction SilentlyContinue }
                foreach ($r in $leftOne, $other, $missing, $empty, $noWhy, $noEnd, $nothing) { Write-Host ($r.Text.TrimEnd() -replace '(?m)^', '    ') }
                $leftOne.Code -eq 0 -and $other.Code -eq 1 -and $other.Text -match '(?m)^a\.md:3: "confirms"' -and $other.Text -notmatch '"verified"' -and
                    $missing.Code -eq 1 -and $missing.Text -match 'FAILED - glossary-check: -LeftFile .*not-there\.txt is not there' -and
                    $empty.Code -eq 1 -and $empty.Text -match 'FAILED - glossary-check: -LeftFile .* leaves no word' -and
                    $noWhy.Code -eq 1 -and $noWhy.Text -match 'FAILED - glossary-check: -LeftFile .* has a line with no why' -and
                    $noEnd.Code -eq 1 -and $noEnd.Text -match 'FAILED - glossary-check: not-there is not there, so no line of not-there\.\.\.HEAD was read' -and
                    $nothing.Code -eq 0 -and $nothing.Text -match 'OK - glossary-check: HEAD~1\.\.HEAD adds no line to a Markdown file but GLOSSARY\.md, so none was read'
            }
            finally { Remove-Item -LiteralPath $temp -Recurse -Force }
        } }
    )
    $failures = 0
    $n = 0
    foreach ($c in $cases) {
        $n++
        $ok = try { & $judgeCase $c.Test } catch { Write-Host "    threw: $($_.Exception.Message)"; $false }
        if ($c.Name -ceq $leakCase) { $ok = -not $ok }
        Write-Host ("self-test {0}/{1}: {2} -- {3}" -f $n, $cases.Count, $c.Name, $(if ($ok) { 'ok' } else { 'FAILED' }))
        if (-not $ok) { $failures++ }
    }
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $($cases.Count) case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $($cases.Count) cases."
    exit 0
}

if ($Range -and $Range -notmatch '\.\.+[^.]') { throw '-Range needs both ends, as origin/main...HEAD: the files are read at its end.' }
$revision = if ($Range) { $Range -replace '^.*\.\.+' } else { 'HEAD' }
# A file that leaves nothing is a file misnamed or emptied, not a choice to leave nothing (#443).
if ($PSBoundParameters.ContainsKey('LeftFile')) {
    if (-not (Test-Path -LiteralPath $LeftFile -PathType Leaf)) { Write-Host "FAILED - glossary-check: -LeftFile $LeftFile is not there, so no line was read."; exit 1 }
    $fromFile = [ordered] @{}
    foreach ($l in Get-Content -LiteralPath $LeftFile | Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*#' }) {
        if ($l -notmatch '^\s*(\S+)\s+(\S.*?)\s*$') { Write-Host "FAILED - glossary-check: -LeftFile $LeftFile has a line with no why after its pattern: $l"; exit 1 }
        $fromFile[$Matches[1]] = $Matches[2]
    }
    if (-not $fromFile.Count) { Write-Host "FAILED - glossary-check: -LeftFile $LeftFile leaves no word, so no line was read."; exit 1 }
    foreach ($k in $Left.Keys) { $fromFile[$k] = $Left[$k] }
    $Left = $fromFile
}
# Both ends there before a line is read: a range git cannot resolve is no range read (#443).
if ($Range) {
    foreach ($end in @($Range -split '\.\.\.?') | Where-Object { $_ }) {
        git rev-parse --verify --quiet "$end^{commit}" *> $null
        if ($LASTEXITCODE -ne 0) { Write-Host "FAILED - glossary-check: $end is not there, so no line of $Range was read. Fetch it, or run where it is."; exit 1 }
    }
}
# A glossary that gives the script no word to match leaves nothing it reads able to fail
# (grado-factorio-modpack#362).
$glossary = @(git show "${revision}:GLOSSARY.md" 2>$null)
if ($LASTEXITCODE -ne 0) { Write-Host "FAILED - glossary-check: git could not read GLOSSARY.md at $revision, so no line was read against it. Run it inside the repository."; exit 1 }
$avoided = @(if ($glossary) { Get-Avoided -Glossary $glossary })

if ($List) {
    Write-Host 'Matched:'
    $avoided | Where-Object { -not $_.Why } | ForEach-Object { Write-Host "  $($_.Term): $($_.Entry)" }
    Write-Host 'Not matched, and left to the reviewer:'
    $avoided | Where-Object Why | ForEach-Object { Write-Host "  $($_.Term): $($_.Entry) -- $($_.Why)" }
    Write-Host 'Forms of a matched word that are left as well:'
    $Left.GetEnumerator() | Where-Object { $key = $_.Key; -not ($avoided | Where-Object { $_.Why -eq $Left[$key] }) } | ForEach-Object { Write-Host "  $($_.Key) -- $($_.Value)" }
    exit 0
}
# After -List, which is how a reader sees why no entry is matched.
if (-not ($avoided | Where-Object { -not $_.Why })) { Write-Host "FAILED - glossary-check: GLOSSARY.md at $revision has no _Avoid_ entry whose word it matches, so no line was read against it. -List shows why."; exit 1 }

# The added lines of each Markdown file: every line with -All, or what the range's diff adds.
$added = [ordered] @{}
if ($Range) {
    $file = $null
    foreach ($d in git -c core.quotepath=off diff --unified=0 --diff-filter=ACMR $Range -- '*.md') {
        # git ends the name with a tab where it holds a space.
        if ($d -match '^\+\+\+ b/(.+?)\t?$') { $file = $Matches[1]; $added[$file] = [System.Collections.Generic.List[int]]::new() }
        elseif ($d -match '^@@ -\S+ \+(\d+)(?:,(\d+))? @@') {
            $count = if ($Matches[2]) { [int] $Matches[2] } else { 1 }
            for ($k = 0; $k -lt $count; $k++) { $added[$file].Add([int] $Matches[1] + $k) }
        }
    }
}
elseif ($All) { foreach ($f in git -c core.quotepath=off ls-files '*.md') { $added[$f] = $null } }
else { throw 'Say what to read: -Range origin/main...HEAD, -All, -List or -SelfTest.' }
if ($LASTEXITCODE -ne 0) { throw 'git could not list the lines to read. Run it inside the repository.' }

$found = 0
$added.Remove('GLOSSARY.md')
foreach ($f in $added.Keys) {
    $lines = @(git show "${revision}:$f")
    if ($LASTEXITCODE -ne 0) { throw "git could not read ${revision}:$f." }
    $numbers = @(if ($null -eq $added[$f]) { 1..[Math]::Max(1, $lines.Count) } else { $added[$f] })
    foreach ($u in Find-Avoided -Lines $lines -Numbers $numbers -Avoided $avoided) {
        Write-Host "${f}:$($u.Line): `"$($u.Word)`" - *$($u.Term)* avoids $($u.Entry)"
        $found++
    }
}
Write-Host ''
if ($found -and $Range) { Write-Host "FAILED - glossary-check: $found unmarked use(s) of an avoided word in $($added.Count) Markdown file(s). Reword each, or mark a deliberate one <!-- deliberate: word -->."; exit 1 }
if ($found) { Write-Host "glossary-check: $found use(s) of an avoided word in $($added.Count) Markdown file(s). -All counts and does not fail."; exit 0 }
# Lines, not files: a file the range only removes lines from is listed with none (PR #452's review).
if ($Range -and -not @($added.Values | Where-Object { $_.Count }).Count) { Write-Host "OK - glossary-check: $Range adds no line to a Markdown file but GLOSSARY.md, so none was read."; exit 0 }
Write-Host "OK - glossary-check: $($added.Count) Markdown file(s), no unmarked use of an avoided word."
exit 0
