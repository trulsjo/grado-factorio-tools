<#
.SYNOPSIS
    Checks that every commit a pull request body cites is on the main branch. Exit 0 means each
    word in the body that names a commit of this repository names one that is an ancestor of
    origin/main; exit 1 names each that is not.

.DESCRIPTION
    WHY (grado-factorio-tools#96). Pull requests here are rebase-merged, which rewrites every
    SHA on the branch, so a body that cites a branch commit cites something the merge deletes.
    docs/agents/issue-tracker.md says to cite the pull request, and a SHA only once it is on
    main. On PR #94 (2026-10-09) the body cited a commit of its own branch and a reviewer found
    it; a fixed pattern is a check's work.

    WHAT IT READS. Every word of 7 to 40 hexadecimal characters, in either case, with no letter,
    digit or underscore against it, wherever it stands: prose, a code span, a fenced block, an
    address. Each is asked of git as a commit. One that names a commit is on main when
    `git merge-base --is-ancestor` says so. A word of digits alone is read like any other, since
    an abbreviated SHA can be all digits; a count or a run id is passed over unless it happens
    to abbreviate a commit here.

    A SHALLOW CLONE IS REFUSED, and nothing is checked: there an ancestor cannot be told from a
    commit whose history was cut off. CI therefore fetches the whole history for this. Whatever
    else git cannot answer fails the run too; nothing passes for not having been asked.

    WHAT IT CANNOT SEE. A word that names no commit in this clone is counted, said to be
    unchecked, and passes: a commit of a sibling repository, or one from before a rebase that a
    fresh clone no longer holds. Run locally, origin/main is as this clone last fetched it, so
    a commit that reached main since is reported. A commit cited by fewer than 7 characters is
    not read. Whether a commit on main is the one the prose means. Anything else a body says.
    And a word is asked of git as a name, so a branch or a tag whose name is 7 to 40 hexadecimal
    characters answers for the commit it points at.

.PARAMETER Path
    The file holding the body, as handed to `gh pr create --body-file`.

.PARAMETER Body
    The body itself. For CI, which has it in the environment: -Body "$env:PR_BODY". The quotes
    matter: without them an empty body is no argument at all.

.PARAMETER Main
    The branch a cited commit must be on. origin/main unless said.

.PARAMETER SelfTest
    Run the cases that hold the check to what this header says, naming each as it runs. Needs
    git, for fixture repositories in a temp directory.

.EXAMPLE
    pwsh -File scripts/pr-body-check.ps1 ../scratch/body.md

.EXAMPLE
    ./scripts/pr-body-check.ps1 -Body "$env:PR_BODY"
#>

#Requires -Version 7
[CmdletBinding(DefaultParameterSetName = 'Path')]
param(
    [Parameter(ParameterSetName = 'Path', Mandatory, Position = 0)] [string] $Path,
    [Parameter(ParameterSetName = 'Body', Mandatory)] [AllowEmptyString()] [string] $Body,
    [Parameter(ParameterSetName = 'SelfTest', Mandatory)] [switch] $SelfTest,
    [string] $Main = 'origin/main'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

function Test-Body {
    <#  What the words of $Text that could be a SHA name in the repository at $Top, as
        @{ Off; On; Unknown }: the words naming a commit that is not on $Main, how many name one
        that is, and how many name no commit there.  #>
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Text,
        [Parameter(Mandatory)] [string] $Top,
        [Parameter(Mandatory)] [string] $Main
    )
    if ((git -C $Top rev-parse --is-shallow-repository) -ne 'false') {
        throw "This clone is shallow, so a commit on $Main cannot be told from one whose history was cut off. Fetch the whole history (git fetch --unshallow)."
    }
    $null = git -C $Top rev-parse --verify --quiet "$Main^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) { throw "git cannot resolve $Main here, so nothing can be checked against it. Fetch it, or name the branch with -Main." }

    $result = @{ Off = @(); On = 0; Unknown = 0 }
    $words = [regex]::Matches($Text, '(?<![0-9A-Za-z_])[0-9a-fA-F]{7,40}(?![0-9A-Za-z_])') | ForEach-Object Value | Sort-Object -Unique
    foreach ($word in $words) {
        $commit = git -C $Top rev-parse --verify --quiet "$word^{commit}" 2>$null
        if ($LASTEXITCODE -ne 0) { $result.Unknown++; continue }
        git -C $Top merge-base --is-ancestor $commit $Main
        if ($LASTEXITCODE -eq 0) { $result.On++ }
        elseif ($LASTEXITCODE -eq 1) { $result.Off += $word }
        else { throw "git could not say whether $word is on $Main." }
    }
    $result
}

function Invoke-SelfTest {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "pr-body-check-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    $repo = Join-Path $temp 'repo'
    $shallow = Join-Path $temp 'shallow'
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    git -C $repo init --quiet
    if ($LASTEXITCODE -ne 0) { throw 'git init failed; the self-test needs git.' }
    $commit = {
        git -C $repo -c user.name=self-test -c user.email=self-test@example.invalid -c commit.gpgsign=false commit --quiet --allow-empty -m $args[0] 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "git could not commit '$($args[0])' in the fixture repository." }
        git -C $repo rev-parse HEAD
    }
    # Two commits on main, so that a clone of depth 1 is shallow, and one on the branch after it.
    $root = & $commit 'the first on main'
    $onMain = & $commit 'the second on main'
    git -C $repo update-ref refs/remotes/origin/main $onMain
    $onBranch = & $commit 'on the branch'
    $check = { param([string] $text, [string] $top = $repo, [string] $main = 'origin/main') Test-Body -Text $text -Top $top -Main $main }
    $run = {
        param([string[]] $Arguments)
        Push-Location $repo
        try { $text = (& pwsh -NoProfile -File $PSCommandPath @Arguments 2>&1 | Out-String) } finally { Pop-Location }
        @{ Code = $LASTEXITCODE; Text = $text }
    }

    $cases = @(
        @{ Name = 'a commit on the branch and not on main is refused, in full or abbreviated, and named once'; Test = {
            $r = & $check "Run at ``$($onBranch.Substring(0, 7))``, which is $onBranch, and again at $($onBranch.Substring(0, 7).ToUpperInvariant())."
            $r.Off.Count -eq 2 -and $r.Off -contains $onBranch -and $r.Off -contains $onBranch.Substring(0, 7) -and $r.On -eq 0 } }
        @{ Name = 'a commit on main passes, in full, abbreviated, in capitals and at the end of an address; -Main names another branch to be on'; Test = {
            $r = & $check "At $onMain, at ``$($root.Substring(0, 9))``, at $($onMain.Substring(0, 12).ToUpperInvariant()) and https://example.com/commit/$($root.Substring(0, 7))"
            $other = & $check "At $onBranch." $repo 'HEAD'
            $r.Off.Count -eq 0 -and $r.On -eq 4 -and $r.Unknown -eq 0 -and $other.Off.Count -eq 0 -and $other.On -eq 1 } }
        @{ Name = 'a word that names no commit here is counted as unchecked and passes: a run id, a count, a commit of another repository, a tree'; Test = {
            $tree = git -C $repo rev-parse 'HEAD^{tree}'
            $r = & $check "Run 37917514429 took 1234567 ms; the modpack is at ``0123abc`` and defaced nothing. The tree is $tree."
            $r.Off.Count -eq 0 -and $r.On -eq 0 -and $r.Unknown -eq 5 } }
        @{ Name = 'a word that is not 7 to 40 hexadecimal characters standing alone is not read'; Test = {
            $six = $onBranch.Substring(0, 6)
            $r = & $check "Six, $six; inside a word, x$($onBranch.Substring(0, 8)), _$($onBranch.Substring(0, 8)) and $($onBranch.Substring(0, 8))_y; 41 of them, $($onBranch)0; and an empty body."
            $empty = & $check ''
            $r.Off.Count -eq 0 -and $r.On -eq 0 -and $r.Unknown -eq 0 -and $empty.Off.Count -eq 0 -and $empty.Unknown -eq 0 } }
        @{ Name = 'a shallow clone is refused, and so is a main branch git cannot resolve'; Test = {
            git clone --quiet --depth 1 "file:///$($repo -replace '\\', '/')" $shallow 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'git could not make the shallow fixture.' }
            $atShallow = try { & $check 'nothing' $shallow; 'ran' } catch { $_.Exception.Message }
            $noMain = try { & $check 'nothing' $repo 'origin/nowhere'; 'ran' } catch { $_.Exception.Message }
            Write-Host "    $atShallow`n    $noMain"
            $atShallow -match 'shallow' -and $noMain -match 'origin/nowhere' } }
        @{ Name = 'run on a body file it exits 1 naming the branch commit, and 0 on a body that cites none; an empty -Body passes'; Test = {
            $file = Join-Path $temp 'body.md'
            Set-Content -LiteralPath $file -Value "## Evidence`n`nRun at ``$($onBranch.Substring(0, 7))``, after $($onMain.Substring(0, 7)) and 0123abc."
            $refused = & $run @($file)
            Set-Content -LiteralPath $file -Value "Run on PR #94, after $($onMain.Substring(0, 7))."
            $passed = & $run @($file)
            $empty = & $run @('-Body', '')
            Write-Host ($refused.Text.TrimEnd() -replace '(?m)^', '    ')
            Write-Host ($passed.Text.TrimEnd() -replace '(?m)^', '    ')
            $refused.Code -eq 1 -and $refused.Text -match "(?m)^pr-body-check: $($onBranch.Substring(0, 7)) is a commit that is not on origin/main" -and
                $refused.Text -match '1 named no commit here' -and $passed.Code -eq 0 -and $passed.Text -match '(?m)^OK - pr-body-check: 1 ' -and $empty.Code -eq 0 } }
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

$top = git rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) { throw 'git found no repository here. Run it inside the repository.' }
if ($Path) { $Body = Get-Content -LiteralPath $Path -Raw }

$read = Test-Body -Text "$Body" -Top $top -Main $Main
foreach ($word in $read.Off) {
    Write-Host "pr-body-check: $word is a commit that is not on $Main. A rebase-merge rewrites it: cite the pull request, or the commit once it is on main."
}
$unchecked = if ($read.Unknown) { " $($read.Unknown) named no commit here and were NOT checked." } else { '' }
if ($read.Off) {
    Write-Host ''
    Write-Host "FAILED - pr-body-check: $($read.Off.Count) word(s) of the body name a commit that is not on $Main.$unchecked"
    exit 1
}
Write-Host "OK - pr-body-check: $($read.On) word(s) of the body name a commit, each on $Main.$unchecked"
exit 0
