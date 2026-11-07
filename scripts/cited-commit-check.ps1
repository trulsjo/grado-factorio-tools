<#
.SYNOPSIS
    Reads the tracked files -Path names and fails on each word shaped like a commit hash that
    names a commit of this clone which origin/main does not reach. Exit 0 means every such word
    outside -Exempt's pages names a commit origin/main reaches, or no commit here at all.

.DESCRIPTION
    WHY (grado-factorio-tools#346, #319 rulings 4 and 8). A rebase merge puts a reworded or
    rebased copy of each commit on main, and the branch's own commits are then reachable from no
    ref: git gc can lose them, and a reader who follows a cited one finds nothing. On
    realistic-fusion-refreshed's #815 a skill cited the pre-reword copy of #811's first commit,
    and only a reviewer running git branch -a --contains caught it (its #817). This is that
    repository's ship-check.ps1 section 17, at 4de346d, over the whole tree; pr-body-check.ps1
    asks the same of a pull request's body.

    WHAT IT READS. Each file git tracks that a pathspec in -Path names, a glob from the
    repository root, less those -Exempt names: a page that records a commit on purpose, as a log
    of what a branch held (Truls, 2026-10-27, on realistic-fusion-refreshed's #817). Unless given,
    -Path is that repository's five extensions, the .md, .lua, .ps1, .py and .js files (Truls, on
    grado-factorio-tools#346). Each is read from the working tree, and a file git tracks that is
    not there is not counted as read. In a .md file, a line inside a ``` or ~~~ fence, closed by
    the same kind, is not read; in any other file, every line is. A word of 7 to 40 hexadecimal
    characters, with no letter, digit or _ either side, is asked of git: cat-file names its
    commit, or says there is none, and rev-list lists every commit -Main reaches. Two processes
    for the whole tree, not two per word.

    WHAT FAILS WITH NOTHING ASKED. A shallow clone, or one where -Main does not resolve: there a
    commit on main cannot be told from one whose history was cut off, so the run fails rather
    than passing. So does a -Path that names no tracked file. CI checks out with fetch-depth 0.

    WHERE IT RUNS. In CI only (#319 ruling 8): a commit is never on origin/main before it is
    pushed, so a run before then would report the branch's own commits.

    WHAT IT CANNOT SEE. A word that names no commit in this clone, which passes: a fresh clone
    never fetched the pre-reword copy of a commit, so CI is blind to the case #815 had, and a
    clone that made the commit is not. A prefix two objects share. A hash of 6 characters or
    fewer. -Main as this clone last fetched it. Whether a commit on main is the one the prose
    means. A hash in a fence, in an exempt page, or in a file -Path does not name. A fence opened
    inside a block quote or a list is read as a fence all the same. -SelfTest runs the reading
    on a scratch repository; the script's own call of it, and its exit, are not run.

.PARAMETER Path
    The git pathspecs of the files to read, as globs from the repository root. The tracked .md,
    .lua, .ps1, .py and .js files unless given.

.PARAMETER Exempt
    The git pathspecs of the pages that may cite a commit main does not reach: the records.

.PARAMETER Main
    The ref every cited commit must be reachable from. origin/main unless given.

.PARAMETER SelfTest
    Run the cases, on a scratch repository, and nothing else. Needs git.

.EXAMPLE
    pwsh -File scripts/cited-commit-check.ps1 -Exempt 'docs/measurements.md'
#>

#Requires -Version 7
param(
    [string[]] $Path = @('**/*.md', '**/*.lua', '**/*.ps1', '**/*.py', '**/*.js'),
    [string[]] $Exempt = @(),
    [string] $Main = 'origin/main',
    [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'
# git's paths are UTF-8; read in the console's code page, a non-ASCII name names no file.
[Console]::OutputEncoding = [Text.Encoding]::UTF8
# A list handed through pwsh -File arrives as one string.
$Path = @($Path | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$Exempt = @($Exempt | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$HASH_WORD = '(?<![0-9A-Za-z_])[0-9a-fA-F]{7,40}(?![0-9A-Za-z_])'

# The check over the repository at $Root, as its exit code and the lines it prints.
function Invoke-CitedCommitCheck {
    param([Parameter(Mandatory)] [string] $Root, [Parameter(Mandatory)] [string[]] $Path,
        [AllowEmptyCollection()] [string[]] $Exempt = @(), [Parameter(Mandatory)] [string] $Main)
    $fail = { param([string] $why) @{ Code = 1; Lines = @("FAILED - cited-commit-check: $why") } }
    if ((git -C $Root rev-parse --is-shallow-repository 2>$null) -ne 'false') {
        return & $fail "$Root is a shallow clone, or no repository, so a commit on $Main cannot be told from one whose history was cut off. Fetch the whole history."
    }
    $null = git -C $Root rev-parse --verify --quiet "$Main^{commit}" 2>$null
    if ($LASTEXITCODE) { return & $fail "git cannot resolve $Main, so no cited commit can be checked against it. Fetch it." }
    $specs = @($Path | ForEach-Object { ":(glob)$_" }) + @($Exempt | ForEach-Object { ":(glob,exclude)$_" })
    $files = @("$(git -C $Root -c core.quotePath=false ls-files -z -- @specs)".Split("`0") | Where-Object { $_ })
    if ($LASTEXITCODE) { throw "git could not list the files of $Root." }
    if (-not $files) { return & $fail "no tracked file for $($Path -join ', '), so nothing was read." }

    $words = [System.Collections.Generic.List[object]]::new()
    $read = 0
    foreach ($f in $files) {
        $full = Join-Path $Root $f
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
        $read++
        $fence = $null
        $n = 0
        foreach ($line in [IO.File]::ReadAllLines($full)) {
            $n++
            if ($f -like '*.md') {
                if ($fence) { if ($line -match "^\s*$([regex]::Escape($fence))+\s*$") { $fence = $null }; continue }
                if ($line -match '^\s*(`{3,}|~{3,})') { $fence = $Matches[1]; continue }
            }
            foreach ($m in [regex]::Matches($line, $HASH_WORD)) { $words.Add(@{ File = $f; Line = $n; Hash = $m.Value }) }
        }
    }
    $unique = @($words | ForEach-Object { $_.Hash } | Sort-Object -Unique)
    $named = @{}
    if ($unique) {
        $answers = @($unique | ForEach-Object { "$_^{commit}" } | git -C $Root cat-file --batch-check 2>$null)
        for ($i = 0; $i -lt $unique.Count; $i++) {
            if ($answers[$i] -match '^([0-9a-f]{40}) commit') { $named[$unique[$i]] = $Matches[1] }
        }
    }
    $reached = [System.Collections.Generic.HashSet[string]]::new([string[]] @(git -C $Root rev-list $Main))
    if ($LASTEXITCODE) { throw "git could not list the commits $Main reaches." }
    $bad = @($words | Where-Object { $named.ContainsKey($_.Hash) -and -not $reached.Contains($named[$_.Hash]) })
    if ($bad) {
        $lines = @($bad | ForEach-Object { "$($_.File):$($_.Line): cites commit $($_.Hash), which $Main does not reach, so a rebase or git gc can take it away; cite the commit main holds, or the pull request." })
        return @{ Code = 1; Lines = $lines + "FAILED - cited-commit-check: $($bad.Count) of $($words.Count) word(s) read in $read file(s) cite a commit $Main does not reach." }
    }
    @{ Code = 0; Lines = @("OK - cited-commit-check: $($words.Count) word(s) read in $read file(s); each that names a commit here names one $Main reaches.") }
}

if ($SelfTest) {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "cited-commit-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    $repo = Join-Path $temp 'repo'
    New-Item -ItemType Directory -Path (Join-Path $repo 'docs'), (Join-Path $temp 'shallow') -Force | Out-Null
    $git = { git -C $repo -c user.name=selftest -c user.email=selftest@example.invalid -c core.autocrlf=false -c commit.gpgsign=false @args
        if ($LASTEXITCODE) { throw "git $args failed; the self-test needs git." } }
    $file = { param($name, [string[]] $text) Set-Content -LiteralPath (Join-Path $repo $name) -Value $text }
    $run = { param([string[]] $Path = @('**/*.md', '**/*.lua', '**/*.ps1', '**/*.py', '**/*.js'), [string[]] $Exempt = @(), [string] $Main = 'main') Invoke-CitedCommitCheck -Root $repo -Path $Path -Exempt $Exempt -Main $Main }
    try {
        & $git init --quiet --initial-branch=main
        & $file 'docs/a.md' 'start'; & $git add -A; & $git commit --quiet -m one
        $onMain = (& $git rev-parse HEAD).Substring(0, 7)
        & $git switch --quiet -c side; & $file 'docs/a.md' 'side'; & $git commit --quiet -am two
        $offMain = (& $git rev-parse HEAD).Substring(0, 7)
        & $git switch --quiet main
        $cases = [ordered]@{
            'a commit main reaches passes, by a short and a full hash; one it does not reach fails, by file, line and word' = {
                $full = & $git rev-parse $onMain
                & $file 'docs/a.md' "On main: $onMain and $full.", "Off main: $offMain."
                $end = & $run
                $end.Code -eq 1 -and ($end.Lines -join '|') -eq ("docs/a.md:2: cites commit $offMain, which main does not reach, so a rebase or git gc can take it away; cite the commit main holds, or the pull request.|" +
                    "FAILED - cited-commit-check: 1 of 3 word(s) read in 1 file(s) cite a commit main does not reach.") }
            'a hex word that names no commit passes, and one inside a longer word is not read' = {
                & $file 'docs/a.md' 'A colour deadbeef, a hash 0123456789abcdef0123, and x' + $offMain + 'y.'
                $end = & $run
                $end.Code -eq 0 -and $end.Lines[-1] -eq 'OK - cited-commit-check: 2 word(s) read in 1 file(s); each that names a commit here names one main reaches.' }
            'a hash inside a fence is not read, and one after the fence closes is' = {
                & $file 'docs/a.md' '```text', $offMain, '```', '~~~', $offMain, '~~~', "After: $offMain"
                $end = & $run
                $end.Code -eq 1 -and $end.Lines[0] -match '^docs/a\.md:7: cites commit ' -and $end.Lines.Count -eq 2 }
            'an exempt page is not read, -Path narrows what is, and by default a script is read, every line' = {
                & $file 'docs/a.md' "Record: $offMain"; & $file 'docs/b.ps1' "# Cites $offMain"; & $git add -A
                $exempt = & $run -Path '**/*.md' -Exempt 'docs/a.md'
                $wide = & $run -Exempt 'docs/a.md'
                & $git rm --cached --quiet docs/b.ps1; Remove-Item -LiteralPath (Join-Path $repo 'docs/b.ps1')
                $exempt.Code -eq 1 -and $exempt.Lines[-1] -match 'no tracked file for \*\*/\*\.md' -and
                    $wide.Code -eq 1 -and $wide.Lines[0] -match '^docs/b\.ps1:1: cites commit ' -and $wide.Lines.Count -eq 2 }
            'by default a script is read too, fences and all; a ~~~ does not close a ``` fence; a non-ASCII name is read; a tracked file gone from disk is not counted (#374)' = {
                & $file 'docs/a.md' '```', '~~~', $offMain, '```'
                & $file 'docs/b.ps1' '# ```', "# $offMain"
                & $file 'docs/bløkk ø.md' "Cites $offMain."
                & $file 'docs/gone.md' 'x'; & $git add -A; Remove-Item -LiteralPath (Join-Path $repo 'docs/gone.md')
                $end = & $run
                & $git rm --cached --quiet docs/b.ps1 'docs/bløkk ø.md' docs/gone.md
                Remove-Item -LiteralPath (Join-Path $repo 'docs/b.ps1'), (Join-Path $repo 'docs/bløkk ø.md')
                ($end.Lines[0..1] -join '|') -match '^docs/b\.ps1:2: cites commit .*\|docs/bløkk ø\.md:1: cites commit ' -and
                    $end.Lines[-1] -eq 'FAILED - cited-commit-check: 2 of 2 word(s) read in 3 file(s) cite a commit main does not reach.' }
            'a shallow clone, a -Main that does not resolve, and a -Path that names no tracked file each fail' = {
                & $file 'docs/a.md' 'nothing'
                $shallow = Join-Path $temp 'shallow/clone'
                git clone --quiet --depth 1 "file://$($repo -replace '\\', '/')" $shallow 2>$null
                $cut = Invoke-CitedCommitCheck -Root $shallow -Path '*.md' -Main 'origin/main'
                $nomain = & $run -Main 'no-such-ref'
                $none = & $run -Path '*.txt'
                $cut.Code -eq 1 -and $cut.Lines[0] -match 'shallow clone' -and
                    $nomain.Code -eq 1 -and $nomain.Lines[0] -match 'cannot resolve no-such-ref' -and
                    $none.Code -eq 1 -and $none.Lines[0] -match 'no tracked file for \*\.txt' }
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
if ($LASTEXITCODE -or -not $root) { Write-Host 'FAILED - cited-commit-check: not in a git repository, so nothing was read.'; exit 1 }
$end = Invoke-CitedCommitCheck -Root $root -Path $Path -Exempt $Exempt -Main $Main
$end.Lines | ForEach-Object { Write-Host $_ }
exit $end.Code
