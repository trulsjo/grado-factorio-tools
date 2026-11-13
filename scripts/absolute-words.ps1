<#
.SYNOPSIS
    Lists each line a commit range adds, in Markdown, in a comment or in a commit message, that
    holds an absolute word: <where>: <kind>: <words>: <the line>. It lists and does not fail.

.DESCRIPTION
    WHERE IT CAME FROM (grado-factorio-tools#354, #329 ruling 1). grado-factorio-modpack's
    scripts/absolute-words.ps1 at e7a9586, read 2026-11-06. What changed in the move: the header
    names that repository's tickets and pages as its own, the comment above $WORDS names the
    ruling's repository, and the self-test's list is $listed. The review step that walks the list is
    grado-factorio-tools#355's.

    WHY (grado-factorio-modpack#219). The review rules say "Treat a quantifier as an instruction to
    enumerate", and the session that wrote the lines had not walked them: in the modpack, five of
    the eleven findings of PR #210's first review were one such word, and three of the eight of PR
    #216's (grado-factorio-modpack#213, counted 2026-10-10). The list is for the session to walk
    before it hands the change to a reviewer: does the sentence hold for each thing it covers.

    WHY IT DOES NOT FAIL. The words are in ordinary use. Of the 92 lines grado-factorio-modpack#213
    read, code and words it tried and left out among them, 30 used a word in passing. Exit 0 says
    the range was read, and nothing about what was listed. A range git cannot read exits non-zero.

    WHAT IT READS. The lines the range's diff adds, as they are at the end of the range. In a `.md`
    file, each of them. In any other file, the comment lines: one that opens with `#`, and one
    inside a PowerShell block comment. That covers the scripts, the workflow and the hooks. Then
    each line of each commit message in the range but the `Co-Authored-By` line. A word is matched
    whole and in any case: "overall" and "first-class" hold none.

    WHAT IT LEAVES. Code. On the two pull requests counted it added 15 and 6 lines, most of them a
    result string or a parameter named `All`, and one faulted wording, a self-test case's name.

    WHAT IT CANNOT SEE. Whether a line makes a claim. A claim with none of the words in $WORDS. A
    phrase broken over two lines. A comment after code on its line, the rest of a block comment that
    opens there, and a comment in a file that marks them another way, such as Lua's. A line of code
    that opens with `#` inside a string that runs over lines is read as a comment. A line that was
    moved and not changed is listed as added. A file git calls binary, and what a moved submodule
    pin brings in.

.PARAMETER Range
    The commit range, with both ends: -Range origin/main...HEAD. The diff is read as given, and the
    commit messages are those of the same two ends with two dots.

.PARAMETER SelfTest
    Prove a word is found whole and as a phrase, which lines are comment, and over a range in a
    repository it builds: which lines are listed and which are not, and what it exits with. That
    part needs git.

.EXAMPLE
    pwsh -File scripts/absolute-words.ps1 -Range origin/main...HEAD
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $Range,
    [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

# grado-factorio-modpack#213's thirteen and "cannot", as Truls ruled on 2026-10-10 (its #219).
$WORDS = 'only', 'every', 'each', 'all', 'none', 'nothing', 'never', 'always', 'first', 'last', 'alone', 'the one', 'with or without', 'cannot'
$PATTERN = '(?i)(?<![\w-])(?:' + (($WORDS | ForEach-Object { [regex]::Escape($_) -replace '\\ ', '\s+' }) -join '|') + ')(?![\w-])'

# The listed words a line holds, each once, in lower case.
function Find-Words([string] $Text) {
    @([regex]::Matches($Text, $PATTERN) | ForEach-Object { ($_.Value -replace '\s+', ' ').ToLowerInvariant() } | Sort-Object -Unique)
}

# The numbers of the lines that are comment: one opening with #, or inside a block comment.
function Get-CommentNumbers([string[]] $Lines) {
    $inside = $false
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($inside -or $Lines[$i] -match '^\s*<#') { $i + 1; $inside = $Lines[$i] -notmatch '#>' }
        elseif ($Lines[$i] -match '^\s*#') { $i + 1 }
    }
}

if ($SelfTest) {
    $listed = { param([string] $text) @(Find-Words $text) -join '|' }
    $temp = Join-Path ([IO.Path]::GetTempPath()) "absolute-words-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    try {
        # One repository and two runs for the cases over a range. The second commit adds a line
        # of each kind, and a line of code and a Co-Authored-By line that hold a word.
        $git = { git -C $temp -c user.name=selftest -c user.email=selftest@example.invalid -c core.autocrlf=false -c commit.gpgsign=false @args | Out-Null; if ($LASTEXITCODE -ne 0) { throw "git $args failed; the self-test needs git." } }
        $write = { param([string] $name, [string[]] $lines) $p = Join-Path $temp $name; New-Item -ItemType Directory -Path (Split-Path $p) -Force | Out-Null; Set-Content -LiteralPath $p -Value $lines }
        $run = { param([string] $range) Push-Location $temp; try { $text = (& pwsh -NoProfile -File $PSCommandPath -Range $range 2>&1 | Out-String) } finally { Pop-Location }; @{ Code = $LASTEXITCODE; Text = $text -replace "`r" } }
        & $git init --quiet
        & $write 'a.md' @('It always stood here.')
        & $git add -A
        & $git commit --quiet -m base
        & $write 'a.md' @('It always stood here.', 'Only the first is read.')
        & $write 'scripts/a.ps1' @('<#', '    It cannot fail.', '#>', '# each line is read', "`$all = 'every one'  # the last")
        & $write '.github/workflows/check.yml' @('# every pull request', 'name: all')
        & $write 'my notes.md' @('All of it.')
        & $write '.githooks/pre-commit' @('#!/bin/sh', '# never skipped', 'echo "all of it"')
        & $write 'message.txt' @('add the files', '', 'Nothing else moves.', '', 'Co-Authored-By: All Of Us <all@example.invalid>')
        & $git add -A -- a.md 'my notes.md' scripts .github .githooks
        & $git commit --quiet -F (Join-Path $temp 'message.txt')
        $out = & $run 'HEAD~1...HEAD'
        $bad = & $run 'no-such-branch...HEAD'
    }
    finally { Remove-Item -LiteralPath $temp -Recurse -Force }
    Write-Host ($out.Text.TrimEnd() -replace '(?m)^', '    ')

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
        @{ Name = 'a word is found in any case, each once, and "cannot" is one of them'; Test = {
            (& $listed 'Only the first holds; ONLY that one cannot.') -eq 'cannot|first|only' } }
        @{ Name = '"the one" and "with or without" are found as phrases'; Test = {
            (& $listed 'It is the one file, with or without a header.') -eq 'the one|with or without' } }
        @{ Name = 'a word inside a longer word is not found: overall, first-class, walls, the one-file rule'; Test = {
            (& $listed 'Overall the first-class walls stand, lastly by the one-file rule.') -eq '' } }
        @{ Name = 'a comment is a line that opens with # or stands inside a block comment, and not one after code'; Test = {
            (@(Get-CommentNumbers @('<#', '    text', '#>', '$a = 1  # after code', '    # indented', '<# one line #>', 'echo x')) -join ' ') -eq '1 2 3 5 6' } }
        @{ Name = 'an added Markdown line is listed with its file, line and words, and one the range did not add is not'; Test = {
            $out.Text -match '(?m)^a\.md:2: Markdown: first, only: Only the first is read\.$' -and $out.Text -notmatch 'a\.md:1:' } }
        @{ Name = 'a file whose name holds a space is read'; Test = {
            $out.Text -match '(?m)^my notes\.md:1: Markdown: all: All of it\.$' } }
        @{ Name = 'an added comment line is listed: of a script, of the workflow and of a hook'; Test = {
            $out.Text -match '(?m)^scripts/a\.ps1:2: comment: cannot: It cannot fail\.$' -and $out.Text -match '(?m)^scripts/a\.ps1:4: comment: each: ' -and
                $out.Text -match '(?m)^\.github/workflows/check\.yml:1: comment: every: ' -and $out.Text -match '(?m)^\.githooks/pre-commit:2: comment: never: ' } }
        @{ Name = 'an added line of code that holds a word is not listed'; Test = {
            $out.Text -notmatch 'a\.ps1:5:|check\.yml:2:|pre-commit:3:' } }
        @{ Name = 'a commit-message line is listed by its short hash and line'; Test = {
            $out.Text -match '(?m)^[0-9a-f]{7}:3: commit message: nothing: Nothing else moves\.$' } }
        @{ Name = 'the Co-Authored-By line is not listed'; Test = {
            $out.Text -notmatch 'Co-Authored-By' } }
        @{ Name = 'it exits 0 with lines listed, and ends with the count of each kind'; Test = {
            $out.Code -eq 0 -and $out.Text -match '7 line\(s\).*Markdown 2, comment 4, commit message 1\.' } }
        @{ Name = 'a range git cannot read exits non-zero'; Test = {
            $bad.Code -ne 0 } }
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

if ($Range -notmatch '^(.+?)\.{2,3}([^.].*)$') { throw 'Say what to read: -Range origin/main...HEAD, with both ends, or -SelfTest.' }
$base, $tip = $Matches[1], $Matches[2]

# The numbers of the lines the diff adds, by file.
$added = [ordered] @{}
$file = $null
foreach ($d in git -c core.quotepath=off diff --unified=0 --diff-filter=ACMR --ignore-submodules=all $Range) {
    if ($d -match '^\+\+\+ b/(.+?)\t?$') { $file = $Matches[1]; $added[$file] = [System.Collections.Generic.List[int]]::new() }
    elseif ($d -match '^@@ -\S+ \+(\d+)(?:,(\d+))? @@') {
        $count = if ($Matches[2]) { [int] $Matches[2] } else { 1 }
        for ($k = 0; $k -lt $count; $k++) { $added[$file].Add([int] $Matches[1] + $k) }
    }
}
if ($LASTEXITCODE -ne 0) { throw "git could not read the range $Range. Run it inside the repository." }

$rows = @(
    foreach ($f in $added.Keys) {
        $lines = @(git show "${tip}:$f")
        if ($LASTEXITCODE -ne 0) { throw "git could not read ${tip}:$f." }
        $kind = 'Markdown'
        $numbers = $added[$f]
        if ($f -notmatch '\.md$') { $kind = 'comment'; $comment = @(Get-CommentNumbers $lines); $numbers = @($numbers | Where-Object { $_ -in $comment }) }
        foreach ($n in $numbers) { [pscustomobject] @{ Kind = $kind; Where = "${f}:$n"; Text = $lines[$n - 1] } }
    }
    foreach ($sha in git rev-list --reverse "$base..$tip") {
        $n = 0
        foreach ($l in git log -1 --format=%B $sha) {
            $n++
            if ($l -notmatch '^Co-Authored-By:') { [pscustomobject] @{ Kind = 'commit message'; Where = "$($sha.Substring(0, 7)):$n"; Text = $l } }
        }
    }
)
if ($LASTEXITCODE -ne 0) { throw "git could not read the commits of $base..$tip." }

$counts = [ordered] @{ 'Markdown' = 0; 'comment' = 0; 'commit message' = 0 }
foreach ($r in $rows) {
    $found = @(Find-Words $r.Text)
    if (-not $found) { continue }
    Write-Host "$($r.Where): $($r.Kind): $($found -join ', '): $($r.Text.Trim())"
    $counts[$r.Kind]++
}
$total = ($counts.Values | Measure-Object -Sum).Sum
Write-Host ''
Write-Host "absolute-words: $total line(s) to walk in ${Range}: $(($counts.GetEnumerator() | ForEach-Object { "$($_.Key) $($_.Value)" }) -join ', '). It lists and does not fail."
exit 0
