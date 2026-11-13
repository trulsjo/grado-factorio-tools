<#
.SYNOPSIS
    Rewords one commit of an unpushed branch from a message file, whether or not it is the tip,
    replays the commits above it, and shows that no tree changed: one line per rewritten commit,
    old hash and new.

.DESCRIPTION
    WHERE IT CAME FROM (grado-factorio-tools#356, #329 ruling 2). grado-factorio-modpack's
    scripts/reword-commit.ps1 at 233822d, read 2026-11-14. What changed in the move: the commit
    check is the commit-check.ps1 beside this script, not one under vendor/; the repository's
    commit-scopes.txt reaches it, as its commit-msg hook hands it on (#317 ruling 2), with
    -ScopeFile for another; the refusal of a pushed commit names no page of that repository's.

    WHY (grado-factorio-modpack#207). A finding in a commit message is fixed by rewording that
    commit, and the reviewer is given the new hash and checks that the tree did not change.
    `git commit --amend` reaches the tip only, and a session has no interactive rebase. On
    grado-factorio-modpack's PR #205 (2026-10-09) the ticket commit was reworded twice, the
    second time under the commit of fixes.

    WHAT IT DOES. Each commit from the named one to the tip is written again with
    `git commit-tree`: the same tree, author and author date, on the new parent. The named commit
    takes the message file; the others keep their message. The commit check then reads the new
    commits, and if it rejects one the branch is not moved. Until the move nothing has changed,
    so a refusal or a rejected message leaves the branch where it was. The index and the working
    tree are not touched.

    WHAT IT REFUSES, changing nothing: a name that is no commit; a commit that is not in
    <base>..HEAD; a commit already on origin/<branch>, because once the branch is pushed the
    message stays; staged changes in the index; a detached HEAD; a merge commit among those to
    replay.

    WHAT IT CANNOT SEE. Whether the new message is true: that is the reviewer's. A push to a
    remote other than `origin`, or one this clone has not fetched. A commit-msg hook is not run:
    the commit check beside this script is run directly, and a check of the repository's own
    that its hook chains, as the modpack's member-change-check.ps1, is not. Where the commit check
    is not there, it says the messages were NOT checked and goes on. The committer date is the
    time of the rewrite. The replaced commits stay in the reflog.

.PARAMETER Commit
    The commit to reword: a hash, or anything `git rev-parse` takes.

.PARAMETER MessageFile
    The file holding the new message, whole. Trailing blank lines are dropped.

.PARAMETER Base
    Where the branch left: commits in <Base>..HEAD can be reworded. origin/main unless said.

.PARAMETER ScopeFile
    The scope list the commit check holds the new messages to. Defaults to commit-scopes.txt at
    the repository's top, where there is one; where there is none, any scope passes, as
    commit-check.ps1 does without it.

.PARAMETER SelfTest
    Prove a tip and a commit below the tip are reworded with trees, authors, dates and later
    messages kept, that a commit off the branch, one already pushed and staged changes are
    refused, and that a rejected message, a scope the repository's commit-scopes.txt does not
    list among them, leaves the branch where it was. Needs git, for a fixture repository in a
    temp directory, and commit-check.ps1 beside this script.

.EXAMPLE
    From a consumer's root:

        pwsh -File vendor/grado-factorio-tools/scripts/reword-commit.ps1 -Commit 879f5e5 -MessageFile ../scratch/message.txt

.EXAMPLE
    pwsh -File scripts/reword-commit.ps1 -SelfTest
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $Commit,
    [string] $MessageFile,
    [string] $Base = 'origin/main',
    [string] $ScopeFile,
    [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'
# git's output is UTF-8, and a subject here opens with an emoji.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$check = Join-Path $PSScriptRoot 'commit-check.ps1'
$utf8 = [System.Text.UTF8Encoding]::new($false)

if ($SelfTest) {
    $new = '🔧 chore(repo): say it another way'
    # A fixed committer date, which the runs below inherit, so the hashes the self-test prints are
    # the same on every run (grado-factorio-modpack#407). Each fixture commit gives its own author
    # date.
    $env:GIT_COMMITTER_DATE = '2026-01-05T12:00:00+00:00'
    $fixture = {
        $temp = Join-Path ([IO.Path]::GetTempPath()) "reword-commit-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
        New-Item -ItemType Directory -Path $temp -Force | Out-Null
        $git = { git -C $temp -c core.autocrlf=false -c commit.gpgsign=false @args | Out-Null; if ($LASTEXITCODE -ne 0) { throw "git $args failed; the self-test needs git." } }
        & $git init --quiet --initial-branch=work
        & $git config user.name 'Sélf Tèst'
        & $git config user.email selftest@example.invalid
        & $git config commit.gpgsign false
        foreach ($n in 0..3) {
            Add-Content -LiteralPath (Join-Path $temp 'a.txt') -Value "line $n"
            & $git add -A
            & $git commit --quiet --date "2026-01-0$($n + 1)T12:00:00+00:00" -m "📝 docs(repo): add line $n" -m "The body of commit $n."
            if ($n -eq 0) { & $git update-ref refs/remotes/origin/main HEAD }
        }
        [IO.File]::WriteAllText((Join-Path $temp 'new.txt'), "$new`n`nA new body.`n", $utf8)
        [IO.File]::WriteAllText((Join-Path $temp 'bad.txt'), "not a conventional message`n", $utf8)
        $temp
    }
    $run = { param([string] $temp, [string] $commit, [string] $file)
        Push-Location $temp
        try { $text = (& pwsh -NoProfile -File $PSCommandPath -Commit $commit -MessageFile (Join-Path $temp $file) 2>&1 | Out-String) } finally { Pop-Location }
        @{ Code = $LASTEXITCODE; Text = $text } }
    $log = { param([string] $temp, [string] $format, [string] $range) @(git -C $temp log --reverse "--format=$format" $range) -join "`n" }
    $refused = { param([string] $temp, [hashtable] $r, [string] $before, [string] $why)
        if ($r.Code -ne 1 -or $r.Text -notmatch $why) { Write-Host ($r.Text.TrimEnd() -replace '(?m)^', '    ') }
        $r.Code -eq 1 -and $r.Text -match $why -and (git -C $temp rev-parse HEAD) -eq $before }
    $cases = @(
        @{ Name = 'the tip is reworded: new message, same tree, the commit below it untouched'; Test = { param($t)
            $tree = git -C $t rev-parse 'HEAD^{tree}'; $below = git -C $t rev-parse HEAD~1
            $r = & $run $t HEAD new.txt
            if ($r.Code -ne 0) { Write-Host ($r.Text.TrimEnd() -replace '(?m)^', '    ') }
            $r.Code -eq 0 -and (git -C $t log -1 --format=%s) -eq $new -and (git -C $t rev-parse 'HEAD^{tree}') -eq $tree -and (git -C $t rev-parse HEAD~1) -eq $below } }
        @{ Name = 'a commit below the tip is reworded: later messages, authors, dates and every tree kept, the working tree untouched, each pair of hashes printed'; Test = { param($t)
            Add-Content -LiteralPath (Join-Path $t 'a.txt') -Value 'not staged'
            $old = @(git -C $t rev-list --reverse origin/main..HEAD)
            $was = @{ Later = & $log $t '%B' 'HEAD~2..HEAD'; Authors = & $log $t '%an <%ae> %aI' 'origin/main..HEAD'; Trees = & $log $t '%T' 'origin/main..HEAD' }
            $r = & $run $t HEAD~2 new.txt
            Write-Host ($r.Text.TrimEnd() -replace '(?m)^', '    ')
            $now = @(git -C $t rev-list --reverse origin/main..HEAD)
            $printed = -not (0..2 | Where-Object { $r.Text -notmatch "$($old[$_].Substring(0, 7)).*$($now[$_].Substring(0, 7))" })
            $r.Code -eq 0 -and $printed -and $now[0] -ne $old[0] -and $now[2] -ne $old[2] -and
                (git -C $t log -1 --format=%s HEAD~2) -eq $new -and (git -C $t log -1 --format=%b HEAD~2) -match 'A new body' -and
                (& $log $t '%B' 'HEAD~2..HEAD') -eq $was.Later -and (& $log $t '%an <%ae> %aI' 'origin/main..HEAD') -eq $was.Authors -and
                $was.Authors -match 'Sélf Tèst' -and (& $log $t '%T' 'origin/main..HEAD') -eq $was.Trees -and
                (Get-Content -LiteralPath (Join-Path $t 'a.txt'))[-1] -eq 'not staged' -and -not (git -C $t diff --cached --name-only) } }
        @{ Name = 'a commit that is not on the branch is refused'; Test = { param($t)
            $before = git -C $t rev-parse HEAD
            & $refused $t (& $run $t origin/main new.txt) $before 'not in origin/main\.\.HEAD' } }
        @{ Name = 'a commit already on the branch''s remote is refused, and the one above it is not'; Test = { param($t)
            git -C $t update-ref refs/remotes/origin/work HEAD~1
            $before = git -C $t rev-parse HEAD
            (& $refused $t (& $run $t HEAD~1 new.txt) $before 'already on origin/work') -and (& $run $t HEAD new.txt).Code -eq 0 } }
        @{ Name = 'staged changes are refused'; Test = { param($t)
            Add-Content -LiteralPath (Join-Path $t 'a.txt') -Value 'staged'; git -C $t add a.txt
            $before = git -C $t rev-parse HEAD
            & $refused $t (& $run $t HEAD new.txt) $before 'staged changes' } }
        @{ Name = 'a message the commit check rejects leaves the branch where it was'; Test = { param($t)
            $before = git -C $t rev-parse HEAD
            & $refused $t (& $run $t HEAD~1 bad.txt) $before 'rejected' } }
        # The repository's scope list reaches the check, untracked here so the tree stays clean:
        # a scope it does not list is rejected, one it lists passes.
        @{ Name = 'a scope the repository''s commit-scopes.txt does not list is rejected, and one it lists passes'; Test = { param($t)
            [IO.File]::WriteAllText((Join-Path $t 'commit-scopes.txt'), "repo`n", $utf8)
            [IO.File]::WriteAllText((Join-Path $t 'unlisted.txt'), "🔧 chore(other): say it another way`n", $utf8)
            [IO.File]::WriteAllText((Join-Path $t 'listed.txt'), "🔧 chore(repo): say it another way`n", $utf8)
            $before = git -C $t rev-parse HEAD
            (& $refused $t (& $run $t HEAD unlisted.txt) $before "'other' is not a scope this repository lists") -and (& $run $t HEAD listed.txt).Code -eq 0 } }
    )
    $failures = 0
    $n = 0
    foreach ($c in $cases) {
        $n++
        $temp = $null
        $ok = try { $temp = & $fixture; [bool] (& $c.Test $temp) } catch { Write-Host "    threw: $($_.Exception.Message)"; $false } finally { if ($temp) { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue } }
        Write-Host ("self-test {0}/{1}: {2} -- {3}" -f $n, $cases.Count, $c.Name, $(if ($ok) { 'ok' } else { 'FAILED' }))
        if (-not $ok) { $failures++ }
    }
    Remove-Item Env:GIT_COMMITTER_DATE -ErrorAction SilentlyContinue
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $($cases.Count) case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $($cases.Count) cases."
    exit 0
}

function Stop-Refused([string] $why) { Write-Host "REFUSED - reword-commit: $why Nothing was changed."; exit 1 }

if (-not $Commit -or -not $MessageFile) { throw 'Say what to reword: -Commit <sha> -MessageFile <path>, or -SelfTest.' }
if (-not (Test-Path -LiteralPath $MessageFile)) { throw "There is no message file at $MessageFile." }

$sha = git rev-parse --verify --quiet "$Commit^{commit}"
if ($LASTEXITCODE -ne 0) { Stop-Refused "$Commit names no commit here." }
$branch = git symbolic-ref --quiet --short HEAD
if ($LASTEXITCODE -ne 0) { Stop-Refused 'HEAD is detached, so there is no branch to move.' }
$commits = @(git rev-list --reverse "$Base..HEAD")
$at = [array]::IndexOf($commits, $sha)
if ($at -lt 0) { Stop-Refused "$Commit is not in $Base..HEAD." }
git show-ref --verify --quiet "refs/remotes/origin/$branch"
if ($LASTEXITCODE -eq 0) {
    git merge-base --is-ancestor $sha "refs/remotes/origin/$branch"
    if ($LASTEXITCODE -eq 0) { Stop-Refused "$Commit is already on origin/$branch. Once the branch is pushed the message stays, and the pull request's body says what holds." }
}
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) { Stop-Refused 'The index holds staged changes.' }
$replay = @($commits[$at..($commits.Count - 1)])
foreach ($c in $replay) {
    if (@((git rev-list --parents -n 1 $c) -split ' ').Count -gt 2) { Stop-Refused "$($c.Substring(0, 7)) is a merge commit, which this does not replay." }
}

# Write each commit again on its new parent: same tree, author and author date.
$sign = if ((git config --get --type=bool commit.gpgsign) -eq 'true') { @('-S') } else { @() }
$scratch = [IO.Path]::GetTempFileName()
$parent = git rev-parse "$sha^"
$map = [ordered] @{}
try {
    foreach ($c in $replay) {
        # git writes the old message itself, so no code page stands between the two commits.
        if ($c -eq $sha) { $message = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $MessageFile)) }
        else { git log -1 --format=%B "--output=$scratch" $c; $message = [IO.File]::ReadAllText($scratch) }
        [IO.File]::WriteAllText($scratch, (($message -replace "`r`n", "`n").TrimEnd() + "`n"), $utf8)
        $env:GIT_AUTHOR_NAME, $env:GIT_AUTHOR_EMAIL, $env:GIT_AUTHOR_DATE = git log -1 --format='%an%n%ae%n%aI' $c
        $made = git commit-tree @sign -p $parent -F $scratch "$c^{tree}"
        if ($LASTEXITCODE -ne 0 -or -not $made) { throw "git commit-tree failed on $c. Nothing was changed." }
        $map[$c] = $made
        $parent = $made
    }
}
finally {
    Remove-Item -LiteralPath $scratch -Force -ErrorAction SilentlyContinue
    Remove-Item Env:GIT_AUTHOR_NAME, Env:GIT_AUTHOR_EMAIL, Env:GIT_AUTHOR_DATE -ErrorAction SilentlyContinue
}

foreach ($c in $map.Keys) {
    if ((git rev-parse "$c^{tree}") -ne (git rev-parse "$($map[$c])^{tree}")) { Write-Host "FAILED - reword-commit: the tree of $c changed. Nothing was changed on the branch."; exit 1 }
}
if (-not $ScopeFile) {
    $listed = Join-Path (git rev-parse --show-toplevel) 'commit-scopes.txt'
    if (Test-Path -LiteralPath $listed) { $ScopeFile = $listed }
}
if (Test-Path -LiteralPath $check) {
    $scopes = if ($ScopeFile) { @('-ScopeFile', $ScopeFile) } else { @() }
    $out = & pwsh -NoProfile -File $check -Range "$Base..$parent" @scopes 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Write-Host $out.TrimEnd()
        Write-Host "FAILED - reword-commit: the commit check rejected a message. Nothing was changed: $branch is still at $((git rev-parse --short HEAD))."
        exit 1
    }
}
else { Write-Host "reword-commit: $check not found, so the messages were NOT checked." }

$tip = git rev-parse HEAD
git update-ref -m "reword-commit: $($sha.Substring(0, 7))" "refs/heads/$branch" $parent $tip
if ($LASTEXITCODE -ne 0) { throw "git could not move $branch. It is still at $tip." }

foreach ($c in $map.Keys) {
    $old = $c.Substring(0, 7); $made = $map[$c].Substring(0, 7)
    if ($c -eq $sha) { Write-Host "The message of $old was reworded, new $made`: ``git log -1 --format=%B $made``, and ``git diff $old $made`` is empty." }
    else { Write-Host "$old was replayed above it as $made, message kept: ``git diff $old $made`` is empty." }
}
Write-Host "OK - reword-commit: $($map.Count) commit(s) rewritten on $branch, every tree unchanged."
