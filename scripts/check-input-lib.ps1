#Requires -Version 7
<#
    The files a check is given, listed by one function (grado-factorio-tools#381). Dot-source it:

        . "$PSScriptRoot/check-input-lib.ps1"
        $in = Get-CheckInput -Name 'my-check' -Path '**/*.md' -Exempt 'docs/log.md' -OnDisk
        if ($in.Failure) { Write-Host $in.Failure; exit 1 }
        foreach ($f in $in.Files) { ... Join-Path $in.Root $f ... }

    WHY. cited-commit-check.ps1, line-cite-check.ps1 and comment-line-check.ps1 each carried a copy
    of this routine, and each copy had the same three bugs, fixed three times in PR #374: a
    non-ASCII file name read in the console's code page, the root read before UTF-8 was set, and a
    run whose files were all gone from disk passing with 0 read.

    Get-CheckInput -Name <check> [-Root <path>] -Path <pathspecs> [-Exempt <pathspecs>] [-Staged]
    [-OnDisk]. Each pathspec is a glob from the repository root. In order, it:
    - sets [Console]::OutputEncoding to UTF-8, before its first git call, and leaves it so, so a
      caller's later git call reads git's UTF-8 too;
    - with no -Root, finds the root from the current location, with git rev-parse;
    - lists, with -z, every tracked file -Path names, or with -Staged the staged ones, added,
      copied, modified or renamed, as git diff --cached gives them;
    - drops those -Exempt names;
    - with -OnDisk, as for a caller that reads the working tree, keeps the files on disk, a
      folder standing where git lists a file not among them. Without
      it, as for a caller that reads the index, the list is as git gives it.

    WHAT IT RETURNS. A hashtable: Root, with no -Root the repository's root as git gives it, with /
    between its folders, and with -Root that as it was given, not checked to be the top of a
    repository, so a subfolder given reads its pathspecs from that subfolder; Files, the paths from
    Root, tracked or staged alike, in git's order; Listed, how many files the listing gave after
    -Exempt and before -OnDisk; and Failure, $null or the line to print, which opens
    `FAILED - <Name>: `. On the not-in-a-repository failure Root is '', Files empty, Listed 0.

    WHAT FAILS. A run that leaves nothing to read fails, and Failure names the step that emptied it:
    not in a git repository; no file for -Path; every file for -Path exempt; or, with -OnDisk, none
    of them on disk. The empty runs that are not a failure: with -Staged, nothing staged for -Path,
    or every staged file exempt, as a commit that stages only a page -Exempt names; each returns no
    Files and no Failure, and the caller says it read nothing, as docs/agents/code-review.md's
    read-nothing rule allows. A git listing that fails throws.

    WHAT IT CANNOT SEE. What the caller then reads of each file: a file read as empty, or one the
    caller's own filter drops, as an extension, is the caller's to count. A file staged for
    deletion, which -Staged leaves out. A pathspec's magic other than glob: each is given as :(glob)
    and each exempt one as :(glob,exclude). A file name holding a line break.

    -SelfTest, run as a script, holds the cases on a scratch repository; it needs git.
#>

function Get-CheckInput {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [string] $Root = '',
        [Parameter(Mandatory)] [string[]] $Path,
        [AllowEmptyCollection()] [string[]] $Exempt = @(),
        [switch] $Staged,
        [switch] $OnDisk
    )
    # git's paths are UTF-8; read in the console's code page, a non-ASCII name names no file, and
    # a non-ASCII root no folder. So before the first git call, the root's included.
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
    $end = { param([string[]] $files, [int] $listed, [string] $why)
        @{ Root = $Root; Files = @($files); Listed = $listed; Failure = $(if ($why) { "FAILED - ${Name}: $why" } else { $null }) } }
    if (-not $Root) {
        # Empty where git finds no repository, so Root is '' in that failure's answer.
        $Root = "$(git rev-parse --show-toplevel 2>$null)"
        if (-not $Root) { return & $end @() 0 'not in a git repository, so nothing was read.' }
    }
    $kind = if ($Staged) { 'staged' } else { 'tracked' }
    $named = $Path -join ', '
    $list = { param([string[]] $specs)
        # --relative, so a subfolder given as -Root lists from it, as ls-files does. Under -z git
        # quotes no path, so core.quotePath is not set.
        $out = if ($Staged) { git -C $Root diff --cached --name-only --relative --diff-filter=ACMR -z -- @specs }
        else { git -C $Root ls-files -z -- @specs }
        if ($LASTEXITCODE) { throw "git could not list the $kind files of $Root." }
        @("$out".Split("`0") | Where-Object { $_ }) }
    $include = @($Path | ForEach-Object { ":(glob)$_" })
    $matched = @(& $list $include)
    if (-not $matched) {
        if ($Staged) { return & $end @() 0 '' }
        return & $end @() 0 "no tracked file for $named, so nothing was read."
    }
    $files = $matched
    if ($Exempt) {
        $files = @(& $list ($include + @($Exempt | ForEach-Object { ":(glob,exclude)$_" })))
        # Staged, every match exempt is a commit with nothing to check, as nothing staged is.
        if (-not $files -and $Staged) { return & $end @() 0 '' }
        if (-not $files) { return & $end @() 0 "all $($matched.Count) $kind file(s) for $named are exempt by $($Exempt -join ', '), so nothing was read." }
    }
    $listed = $files.Count
    if ($OnDisk) {
        $files = @($files | Where-Object { Test-Path -LiteralPath (Join-Path $Root $_) -PathType Leaf })
        if (-not $files) { return & $end @() $listed "none of the $listed $kind file(s) for $named is on disk, so nothing was read." }
    }
    & $end $files $listed ''
}

# Only when run as a script. Dot-sourced, InvocationName is '.', and a caller's own -SelfTest is
# not this one. No param block, because dot-sourcing one would overwrite the caller's $SelfTest.
if ($MyInvocation.InvocationName -ne '.' -and $args -contains '-SelfTest') {
    $ErrorActionPreference = 'Stop'
    $temp = Join-Path ([IO.Path]::GetTempPath()) "check-input-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    # Not ASCII, so a root read in the console's code page names no folder.
    $repo = Join-Path $temp 'repø'
    $outside = Join-Path $temp 'outside'
    New-Item -ItemType Directory -Path (Join-Path $repo 'docs'), $outside -Force | Out-Null
    $git = { git -C $repo -c user.name=selftest -c user.email=selftest@example.invalid -c core.autocrlf=false -c commit.gpgsign=false @args | Out-Null
        if ($LASTEXITCODE) { throw "git $args failed; the self-test needs git." } }
    $file = { param($name, [string] $text = 'x') Set-Content -LiteralPath (Join-Path $repo $name) -Value $text }
    # A code page in which git's UTF-8 is read wrong, as a Windows console's is, for the length of
    # one call; the console's own is put back after.
    $latin = { param([scriptblock] $call)
        $was = [Console]::OutputEncoding; [Console]::OutputEncoding = [Text.Encoding]::Latin1
        try { & $call } finally { [Console]::OutputEncoding = $was } }
    $get = { param([hashtable] $more = @{}) Get-CheckInput -Name 'demo' -Root $repo @more }
    try {
        & $git init --quiet
        New-Item -ItemType Directory -Path (Join-Path $repo 'docs/deep') -Force | Out-Null
        & $file 'docs/a.md'; & $file 'docs/b.md'; & $file 'docs/c.ps1'; & $file 'top.md'; & $file 'docs/deep/d.md'
        & $git add -A; & $git commit --quiet -m one
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
        $cases = [ordered]@{
            $leakCase = { $null; $false }
            'a case passes on one $true; two values, a string or none fail it, and say so (#419)' = {
                (& $judgeCase { $true }) -eq $true -and (& $judgeCase { $false }) -eq $false -and
                    "$(& $judgeCase { $null; $true } 6>&1)" -ceq '    gave 2 values, not one [bool] False' -and
                    "$(& $judgeCase { 'x' } 6>&1)" -ceq '    gave String, not a [bool] False' -and "$(& $judgeCase { } 6>&1)" -ceq '    gave 0 values, not one [bool] False' }
            'the tracked files -Path names are listed and counted, in git''s order, less those -Exempt names' = {
                $all = & $get @{ Path = 'docs/*.md' }
                $less = & $get @{ Path = 'docs/*.md', 'docs/*.ps1'; Exempt = 'docs/b.md' }
                -not $all.Failure -and ($all.Files -join '|') -eq 'docs/a.md|docs/b.md' -and $all.Listed -eq 2 -and
                    -not $less.Failure -and ($less.Files -join '|') -eq 'docs/a.md|docs/c.ps1' -and $less.Listed -eq 2 }
            'each pathspec, and each exempt one, is a glob: * stays in its folder, ** crosses folders (#389)' = {
                $top = & $get @{ Path = '*.md' }
                $every = & $get @{ Path = '**/*.md' }
                $less = & $get @{ Path = '**/*.md'; Exempt = 'docs/*.md' }
                ($top.Files -join '|') -eq 'top.md' -and ($every.Files -join '|') -eq 'docs/a.md|docs/b.md|docs/deep/d.md|top.md' -and
                    ($less.Files -join '|') -eq 'docs/deep/d.md|top.md' }
            'a -Path that names no tracked file fails, naming that step' = {
                $got = & $get @{ Path = '*.txt', 'none/*' }
                $got.Failure -eq 'FAILED - demo: no tracked file for *.txt, none/*, so nothing was read.' -and -not $got.Files }
            'a -Path whose every file is exempt fails, naming that step' = {
                $got = & $get @{ Path = 'docs/*.md'; Exempt = 'docs/a.md', 'docs/b.md' }
                $got.Failure -eq 'FAILED - demo: all 2 tracked file(s) for docs/*.md are exempt by docs/a.md, docs/b.md, so nothing was read.' -and -not $got.Files }
            'with -OnDisk, a file gone from disk, or a folder in its place, is dropped and a run whose files are all gone fails, naming that step; without it, the list is git''s' = {
                Remove-Item -LiteralPath (Join-Path $repo 'docs/a.md')
                try {
                    $some = & $get @{ Path = 'docs/*.md'; OnDisk = $true }
                    $gone = & $get @{ Path = 'docs/a.md'; OnDisk = $true }
                    $index = & $get @{ Path = 'docs/a.md' }
                }
                finally { & $git checkout --quiet -- docs/a.md }
                # A folder where git lists a file, as a checkout of another branch can leave.
                Remove-Item -LiteralPath (Join-Path $repo 'docs/b.md'); New-Item -ItemType Directory -Path (Join-Path $repo 'docs/b.md') | Out-Null
                try { $folder = & $get @{ Path = 'docs/b.md'; OnDisk = $true } }
                finally { Remove-Item -LiteralPath (Join-Path $repo 'docs/b.md') -Recurse; & $git checkout --quiet -- docs/b.md }
                -not $some.Failure -and ($some.Files -join '|') -eq 'docs/b.md' -and $some.Listed -eq 2 -and
                    $gone.Failure -eq 'FAILED - demo: none of the 1 tracked file(s) for docs/a.md is on disk, so nothing was read.' -and $gone.Listed -eq 1 -and -not $gone.Files -and
                    -not $index.Failure -and ($index.Files -join '|') -eq 'docs/a.md' -and
                    $folder.Failure -eq 'FAILED - demo: none of the 1 tracked file(s) for docs/b.md is on disk, so nothing was read.' }
            'with -Staged, the staged files are listed, a staged deletion not among them, and neither nothing staged nor every staged file exempt is a failure; a subfolder as -Root lists from it, staged or tracked (PR #389)' = {
                $none = & $get @{ Path = 'docs/*'; Staged = $true }
                & $file 'docs/a.md' 'edited'; & $file 'docs/new.md' 'new'; & $git add -A; & $git rm --quiet --cached docs/b.md
                try {
                    $some = & $get @{ Path = 'docs/*.md'; Staged = $true }
                    $exempt = & $get @{ Path = 'docs/*.md'; Exempt = 'docs/*'; Staged = $true }
                    $sub = Join-Path $repo 'docs'
                    $subStaged = Get-CheckInput -Name 'demo' -Root $sub -Path '*.md' -Staged -OnDisk
                    $subTracked = Get-CheckInput -Name 'demo' -Root $sub -Path '*.md' -OnDisk
                }
                finally { & $git reset --quiet; & $git checkout --quiet -- docs/a.md; Remove-Item -LiteralPath (Join-Path $repo 'docs/new.md') }
                -not $none.Failure -and -not $none.Files -and $none.Listed -eq 0 -and
                    -not $some.Failure -and ($some.Files -join '|') -eq 'docs/a.md|docs/new.md' -and
                    -not $exempt.Failure -and -not $exempt.Files -and
                    -not $subStaged.Failure -and ($subStaged.Files -join '|') -eq 'a.md|new.md' -and
                    -not $subTracked.Failure -and ($subTracked.Files -join '|') -eq 'a.md|new.md' }
            'a non-ASCII file name is listed, and found on disk, with the console in a code page that reads git''s UTF-8 wrong' = {
                & $file 'docs/bløkk ø.md'; & $git add -A
                try { $got = & $latin { & $get @{ Path = 'docs/b*.md'; OnDisk = $true } } }
                finally { & $git rm --cached --quiet 'docs/bløkk ø.md'; Remove-Item -LiteralPath (Join-Path $repo 'docs/bløkk ø.md') }
                -not $got.Failure -and ($got.Files -join '|') -eq 'docs/b.md|docs/bløkk ø.md' }
            'a -Root that is no repository throws, as a git listing that fails does (#389)' = {
                try { $null = Get-CheckInput -Name 'demo' -Root $outside -Path '*' 2>$null; $false }
                catch { $_.Exception.Message -eq "git could not list the tracked files of $outside." } }
            'with no -Root, the root is found from a folder whose name is not ASCII, in that code page; outside a repository the run fails, naming that step' = {
                Push-Location (Join-Path $repo 'docs')
                try { $got = & $latin { Get-CheckInput -Name 'demo' -Path 'docs/a.md' -OnDisk } }
                finally { Pop-Location }
                Push-Location $outside
                try { $none = Get-CheckInput -Name 'demo' -Path '*' }
                finally { Pop-Location }
                # git is asked outside any repository, by the ceiling, wherever the scratch is.
                -not $got.Failure -and $got.Root.EndsWith('/repø') -and ($got.Files -join '|') -eq 'docs/a.md' -and
                    $none.Failure -eq 'FAILED - demo: not in a git repository, so nothing was read.' -and $none.Root -eq '' -and
                    -not $none.Files -and $none.Listed -eq 0 }
        }
        $failures = 0; $n = 0
        $was = $env:GIT_CEILING_DIRECTORIES; $env:GIT_CEILING_DIRECTORIES = $temp
        try {
            foreach ($name in $cases.Keys) {
                $n++
                $ok = try { & $judgeCase $cases[$name] } catch { Write-Host "    threw: $($_.Exception.Message)"; $false }
                if ($name -ceq $leakCase) { $ok = -not $ok }
                Write-Host ("self-test {0}/{1}: {2} -- {3}" -f $n, $cases.Count, $name, $(if ($ok) { 'ok' } else { 'FAILED' }))
                if (-not $ok) { $failures++ }
            }
        }
        finally { $env:GIT_CEILING_DIRECTORIES = $was }
    }
    finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $($cases.Count) case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $($cases.Count) cases."
    exit 0
}
