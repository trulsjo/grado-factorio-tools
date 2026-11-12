<#
.SYNOPSIS
    Holds the comment lines of the files it is given to a width: in a PowerShell script each line
    of a block comment and each # line, and in any other file, a hook or a workflow, each line
    that begins with #, a shebang aside. Exit 0 means no line it read is over the limit, or, with
    no -All, that nothing -Path names is staged, which it says.

.DESCRIPTION
    WHY (grado-factorio-tools#344, #316 ruling 4). Two checks held comment lines to 100
    characters: this repository's pre-commit hook, through comment-line-lib.ps1, on the staged
    scripts, and grado-factorio-modpack's header-length-check.ps1, on its scripts, hooks and
    workflows. This is one check, the rule the library's and the scope a call: the modpack's is
    the second example below.

    WHAT IT READS. The files git lists for each pathspec in -Path, a glob from the repository
    root, as staged: with no -All the staged ones, added, copied, modified or renamed, which is
    what the commit will hold; with -All every tracked one. check-input-lib.ps1's Get-CheckInput
    lists them, and names what a run that read nothing failed at. They are written out of the index
    by checkout-index into a scratch directory, so the working tree is neither read nor touched. It
    may be run from anywhere in the repository.

    THE RULE is comment-line-lib.ps1's. A .ps1 file is read by Get-LongCommentLine, from the
    parser's comment tokens, a help block's .EXAMPLE section exempt; any other file by
    Get-LongHashLine. A line of one word after its marker is exempt in both, as an address is.

    WHAT FAILS WITH NOTHING READ. -All that lists no file, as from a pathspec that matches none
    or in a clone whose checkout failed: exit 1. With no -All, nothing staged passes and says so,
    since that commit has nothing to check.

    WHAT A REFUSAL NAMES. Each refused file with its lines, and the markdown-rewrap.ps1 -Comment
    command that rewraps it at the limit, by its path from the repository root, each path in
    single quotes so the command runs as printed in PowerShell from the root (#378). The rewrap
    reads the working tree, not what this read, so the refusal warns that staging the file again
    stages any edit to it that was not staged.

    WHAT IT CANNOT SEE. An edit not staged. In a file that is not PowerShell, whether a # line is
    a comment, and a block comment of another language. What the PowerShell rule cannot see is in
    check.ps1's header, under A COMMENT OR HEADER LINE. -SelfTest runs the reading and the rule
    on a scratch repository, and the script once through pwsh with a comma list, from a folder
    whose name is not ASCII.

.PARAMETER Path
    The git pathspecs to read, as globs from the repository root. scripts/*.ps1 unless given.

.PARAMETER Limit
    The characters a comment line may run to. 100 unless given.

.PARAMETER All
    Read every tracked file -Path names, as staged, not only the staged ones.

.PARAMETER SelfTest
    Run the cases, on a scratch repository and on strings, and nothing else. Needs git.

.EXAMPLE
    pwsh -File scripts/comment-line-check.ps1 -All

.EXAMPLE
    pwsh -File vendor/grado-factorio-tools/scripts/comment-line-check.ps1 -Path 'scripts/*.ps1,.githooks/*,.github/workflows/*.yml'
#>

#Requires -Version 7
param(
    [string[]] $Path = @('scripts/*.ps1'),
    [int] $Limit = 100,
    [switch] $All,
    [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'
# A list handed through pwsh -File arrives as one string, as the hook and a sibling hand it.
$Path = @($Path | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
. "$PSScriptRoot/comment-line-lib.ps1"
. "$PSScriptRoot/check-input-lib.ps1"

# The check over the repository at $Root, or with none the one the current location is in, as
# its exit code and the lines it prints.
function Invoke-CommentLineCheck {
    param([string] $Root = '', [Parameter(Mandatory)] [string[]] $Path,
        [Parameter(Mandatory)] [int] $Limit, [switch] $All)
    # The index is read, not the disk, so no -OnDisk.
    $in = Get-CheckInput -Name 'comment-line check' -Root $Root -Path $Path -Staged:(-not $All)
    if ($in.Failure) { return @{ Code = 1; Lines = @($in.Failure) } }
    $Root = $in.Root
    $files = $in.Files
    if (-not $files) { return @{ Code = 0; Lines = @("OK - comment-line check: no file for $($Path -join ', ') is staged, so none was read.") } }
    $scratch = Join-Path ([IO.Path]::GetTempPath()) "comment-lines-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    try {
        git -C $Root checkout-index "--prefix=$scratch/" -- @files
        if ($LASTEXITCODE) { throw "git could not write the files of $Root out." }
        $refused = @(foreach ($f in $files) {
                $copy = Join-Path $scratch $f
                $long = @(if ($f -like '*.ps1') { Get-LongCommentLine -Path $copy -Limit $Limit }
                    else { Get-LongHashLine -Lines ([IO.File]::ReadAllLines($copy)) -Limit $Limit })
                if ($long) { @{ File = $f; Lines = $long } }
            })
    }
    finally { Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue }
    $as = if ($All) { '' } else { ', as staged' }
    if (-not $refused) {
        return @{ Code = 0; Lines = @("OK - comment-line check$($as): $($files.Count) file(s) read, no comment line over $Limit.") }
    }
    $rewrap = [IO.Path]::GetRelativePath($Root, (Join-Path $PSScriptRoot 'markdown-rewrap.ps1')) -replace '\\', '/'
    $lines = @($refused | ForEach-Object { "$($_.File): comment lines over $Limit characters, line $($_.Lines -join ', ')." })
    $lines += 'Rewrap each with its command, then stage it again. The rewrap reads the file on disk, so staging it again stages with it any edit that was not staged:'
    # Each path quoted for PowerShell, each kind of single quote it reads doubled, the curly
    # ones too, so the command runs as printed for any path git lists (#378).
    $quote = { param([string] $s) "'$([System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($s))'" }
    $lines += @($refused | ForEach-Object { "    pwsh -NoProfile -File $(& $quote $rewrap) -Comment -MaxLineLength $Limit -Path $(& $quote $_.File)" })
    $lines += "FAILED - comment-line check$($as): $($refused.Count) of $($files.Count) file(s) read have a comment line over $Limit."
    @{ Code = 1; Lines = $lines }
}

if ($SelfTest) {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "comment-line-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    # Not ASCII, so the run through pwsh holds the root read in UTF-8.
    $repo = Join-Path $temp 'repø'
    New-Item -ItemType Directory -Path (Join-Path $repo 'scripts'), (Join-Path $repo '.githooks'), (Join-Path $repo '.github/workflows') -Force | Out-Null
    $long = 'word ' * 20 + 'x'
    # Its directory made first: git rm takes an emptied one away.
    $file = { param($name, [string[]] $text)
        $at = Join-Path $repo $name; New-Item -ItemType Directory -Path (Split-Path $at) -Force | Out-Null
        Set-Content -LiteralPath $at -Value $text }
    $git = { git -C $repo -c user.name=selftest -c user.email=selftest@example.invalid -c core.autocrlf=false -c commit.gpgsign=false @args | Out-Null
        if ($LASTEXITCODE) { throw "git $args failed; the self-test needs git." } }
    # The script's own default -Path, the one the pre-commit hook runs, so a case holds it.
    $defaultPath = $Path
    $run = { param([string[]] $Path = $defaultPath, [switch] $All, [int] $Limit = 100)
        Invoke-CommentLineCheck -Root $repo -Path $Path -Limit $Limit -All:$All }
    $rewrap = [IO.Path]::GetRelativePath($repo, (Join-Path $PSScriptRoot 'markdown-rewrap.ps1')) -replace '\\', '/'
    try {
        & $git init --quiet
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
            'with nothing tracked, -All fails and says it read nothing; with nothing staged, the run passes and says so' = {
                $all = & $run -All; $none = & $run
                $all.Code -eq 1 -and $all.Lines[-1] -eq 'FAILED - comment-line check: no tracked file for scripts/*.ps1, so nothing was read.' -and
                    $none.Code -eq 0 -and $none.Lines[-1] -eq 'OK - comment-line check: no file for scripts/*.ps1 is staged, so none was read.' }
            'a hook''s or a workflow''s # line over the limit is named; a shebang, code, an address and a line at the limit are not' = {
                $got = @(Get-LongHashLine -Limit 100 -Lines @(
                        "#!/bin/sh $long", "# $long", "echo $long", "      # $long", "        run: pwsh $long",
                        "# https://example.com/$('x' * 101)", ('# ' + ('ab ' * 33).Substring(0, 98)), ''))
                "$got" -eq '2 4' }
            'the staged scripts are read as staged: a fix not staged still fails, by file and line, and a long line not staged passes' = {
                & $file 'scripts/b.ps1' '$b = 1', "# $long"; & $git add scripts/b.ps1
                & $file 'scripts/b.ps1' '$b = 1', '# short'; $fixedUnstaged = & $run
                & $git add scripts/b.ps1; & $file 'scripts/b.ps1' '$b = 1', "# $long"; $longUnstaged = & $run
                & $git rm --cached --quiet -f scripts/b.ps1; Remove-Item -LiteralPath (Join-Path $repo 'scripts/b.ps1')
                $fixedUnstaged.Code -eq 1 -and $fixedUnstaged.Lines[0] -eq 'scripts/b.ps1: comment lines over 100 characters, line 2.' -and
                    $fixedUnstaged.Lines[-1] -eq 'FAILED - comment-line check, as staged: 1 of 1 file(s) read have a comment line over 100.' -and
                    $longUnstaged.Code -eq 0 -and $longUnstaged.Lines[-1] -eq 'OK - comment-line check, as staged: 1 file(s) read, no comment line over 100.' }
            '-All reads a tracked file that is not staged, which the run with no switch does not' = {
                & $file 'scripts/old.ps1' '<#', "    $long", '#>'; & $git add scripts/old.ps1; & $git commit --quiet -m old
                $all = & $run -All; $staged = & $run
                & $git rm --quiet -f scripts/old.ps1; & $git commit --quiet -m gone
                $all.Code -eq 1 -and $all.Lines[0] -eq 'scripts/old.ps1: comment lines over 100 characters, line 2.' -and
                    $all.Lines[-1] -eq 'FAILED - comment-line check: 1 of 1 file(s) read have a comment line over 100.' -and
                    $staged.Code -eq 0 }
            '-Path widens the scope to hooks and workflows, read by the # rule, and without it they are not read' = {
                & $file '.githooks/pre-commit' '#!/bin/sh', "# $long", "echo $long"
                & $file '.github/workflows/check.yml' 'jobs:', "        run: pwsh -File $long", "      # $long"
                & $file 'scripts/c.ps1' '# short'; & $git add -A
                $wide = & $run -Path 'scripts/*.ps1', '.githooks/*', '.github/workflows/*.yml'
                $narrow = & $run
                & $git rm --cached --quiet -r -f .githooks .github scripts/c.ps1
                Remove-Item -LiteralPath (Join-Path $repo '.githooks/pre-commit'), (Join-Path $repo '.github/workflows/check.yml'), (Join-Path $repo 'scripts/c.ps1')
                $wide.Code -eq 1 -and $wide.Lines -contains '.githooks/pre-commit: comment lines over 100 characters, line 2.' -and
                    $wide.Lines -contains '.github/workflows/check.yml: comment lines over 100 characters, line 3.' -and
                    $wide.Lines[-1] -eq 'FAILED - comment-line check, as staged: 2 of 3 file(s) read have a comment line over 100.' -and
                    $narrow.Code -eq 0 -and $narrow.Lines[-1] -match '1 file\(s\) read' }
            'a refusal names the rewrap command at the limit for each refused file and no other, and warns that staging again takes unstaged edits' = {
                & $file 'scripts/a.ps1' "# $long"; & $file 'scripts/b.ps1' "# $long"; & $file 'scripts/c.ps1' '# short'; & $git add -A
                $end = & $run
                & $git rm --cached --quiet -f scripts/a.ps1 scripts/b.ps1 scripts/c.ps1
                Remove-Item -LiteralPath (Join-Path $repo 'scripts/a.ps1'), (Join-Path $repo 'scripts/b.ps1'), (Join-Path $repo 'scripts/c.ps1')
                $commands = @($end.Lines | Where-Object { $_ -match 'markdown-rewrap\.ps1' } | ForEach-Object { $_.Trim() })
                $end.Code -eq 1 -and $commands.Count -eq 2 -and
                    $commands -contains "pwsh -NoProfile -File '$rewrap' -Comment -MaxLineLength 100 -Path 'scripts/a.ps1'" -and
                    $commands -contains "pwsh -NoProfile -File '$rewrap' -Comment -MaxLineLength 100 -Path 'scripts/b.ps1'" -and
                    ($end.Lines -join ' ') -match 'stages with it any edit that was not staged' }
            'a refusal''s command, run as printed from the root, rewraps a file whose path holds a space, an apostrophe or a curly one (#378)' = {
                $curly = "scripts/it$([char] 0x2019)s smart.ps1"
                & $file 'scripts/my file.ps1' "# $long"; & $file "scripts/it's.ps1" "# $long"; & $file $curly "# $long"; & $git add -A
                $end = & $run
                $commands = @($end.Lines | Where-Object { $_ -match 'markdown-rewrap\.ps1' } | ForEach-Object { $_.Trim() })
                Push-Location $repo
                try { foreach ($c in $commands) { & pwsh -NoProfile -Command $c 2>&1 | Out-Null } } finally { Pop-Location }
                $wrapped = @('scripts/my file.ps1', "scripts/it's.ps1", $curly | Where-Object {
                        $l = [IO.File]::ReadAllLines((Join-Path $repo $_)); $l.Count -eq 2 -and -not @($l | Where-Object { $_.Length -gt 100 }) })
                & $git rm --cached --quiet -f 'scripts/my file.ps1' "scripts/it's.ps1" $curly
                Remove-Item -LiteralPath (Join-Path $repo 'scripts/my file.ps1'), (Join-Path $repo "scripts/it's.ps1"), (Join-Path $repo $curly)
                $end.Code -eq 1 -and $commands.Count -eq 3 -and $wrapped.Count -eq 3 }
            'a staged deletion is not read, a non-ASCII name is, and -Path handed through pwsh as one comma list reads each, from a folder whose name is not ASCII in a code page that reads git''s UTF-8 wrong (#374)' = {
                & $file 'scripts/gone.ps1' '# short'; & $git add -A; & $git commit --quiet -m gone
                & $git rm --quiet scripts/gone.ps1
                & $file 'scripts/sær ø.ps1' "# $long"; & $file '.githooks/pre-commit' "# $long"; & $git add -A
                Push-Location $repo
                try { $said = @(& pwsh -NoProfile -Command "[Console]::OutputEncoding = [Text.Encoding]::Latin1; & '$PSCommandPath' -Path 'scripts/*.ps1, .githooks/*'; exit `$LASTEXITCODE" 2>&1 | ForEach-Object { "$_" }); $code = $LASTEXITCODE }
                finally { Pop-Location }
                $end = @{ Code = $code; Lines = $said }
                # In-process, in a code page that reads git's UTF-8 wrong, as Windows' can.
                $was = [Console]::OutputEncoding; [Console]::OutputEncoding = [Text.Encoding]::Latin1
                try { $latin = & $run } finally { [Console]::OutputEncoding = $was }
                & $git rm --cached --quiet -f 'scripts/sær ø.ps1' .githooks/pre-commit; & $git commit --quiet -m clean
                Remove-Item -LiteralPath (Join-Path $repo 'scripts/sær ø.ps1'), (Join-Path $repo '.githooks/pre-commit')
                $end.Code -eq 1 -and $end.Lines -contains 'scripts/sær ø.ps1: comment lines over 100 characters, line 1.' -and
                    $end.Lines -contains '.githooks/pre-commit: comment lines over 100 characters, line 1.' -and
                    $end.Lines[-1] -eq 'FAILED - comment-line check, as staged: 2 of 2 file(s) read have a comment line over 100.' -and
                    $latin.Code -eq 1 -and $latin.Lines[0] -eq 'scripts/sær ø.ps1: comment lines over 100 characters, line 1.' }
            '-Limit sets the width: a 103-character line fails at 100 and passes at 110' = {
                & $file 'scripts/d.ps1' "# $long"; & $git add -A
                $at100 = & $run; $at110 = & $run -Limit 110
                & $git rm --cached --quiet -f scripts/d.ps1; Remove-Item -LiteralPath (Join-Path $repo 'scripts/d.ps1')
                $at100.Code -eq 1 -and $at110.Code -eq 0 -and $at110.Lines[-1] -match 'no comment line over 110' }
        }
        $failures = 0; $n = 0
        foreach ($name in $cases.Keys) {
            $n++
            $ok = try { & $judgeCase $cases[$name] } catch { Write-Host "    threw: $($_.Exception.Message)"; $false }
            if ($name -ceq $leakCase) { $ok = -not $ok }
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

$end = Invoke-CommentLineCheck -Path $Path -Limit $Limit -All:$All
$end.Lines | ForEach-Object { Write-Host $_ }
exit $end.Code
