<#
.SYNOPSIS
    Measures what moving a sibling's vendor/grado-factorio-tools pin from -Old to -New changes: each
    form the sibling lists is run at both pins, in two clones of the sibling at GitHub's main, and
    its output and exit code are kept in -Out with a table that compares them. Exit 0 means the
    measurement was made, whatever it found; exit 1 means it could not be made, and says why.

.DESCRIPTION
    WHY (grado-factorio-tools#247). docs/agents/issue-tracker.md, Pin tickets, described the
    measurement in prose, and each sibling session wrote it by hand and got it wrong first: on
    grado-factorio-modpack's PR #387 (2026-10-26) the first run put the pin's copy at the wrong
    path, gave a hook its input without a cwd and ran a -SelfTest -Settings with vendor/ empty, and
    was discarded; PR #380 discarded a first run of its -Body form. The why of measuring in a clone,
    and what the clone cannot see, stay on that page.

    WHERE IT RUNS. From the sibling's vendor/grado-factorio-tools/scripts/, with the submodule
    checked out at the new pin. The sibling is the repository the submodule sits in. Both pins must
    be commits of the submodule's repository, from which both copies are made with `git archive`;
    where either is not, it refuses, naming the commit.

    WHAT IT DOES, in -Out, which must be empty or not there:
    - ls-remote.txt: `git ls-remote <origin> refs/heads/main`, origin being the sibling's.
    - clone-old/ and clone-new/: two clones of the sibling, from one fetch of origin's main, both
      detached there with origin/main set to it; with -Ref, detached at that commit instead, as
      A BRANCH MEASUREMENT says. Each clone's vendor/grado-factorio-tools/scripts/
      holds its pin's copy of scripts/. The clones share no directory, so a form that writes into
      its clone leaves the other pin's run as it was. The old pin runs first.
    - <form>.old.txt, <form>.old.exit, <form>.new.txt and <form>.new.exit for every form: its
      output, stdout and stderr together, and its exit code, run with pwsh -NoProfile -File in
      its clone's root.
    - breaking.txt: the breaking commits of the move, those -Old..-New brings in and those a pin
      moved back drops, marked dropped, for the pull request's Merge Danger; "none" where there is
      none. The rule and the text are breaking-lib.ps1's (grado-factorio-tools#255), which its
      header states with an example.
    - table.md: a line naming the forms file read and where from, with -Ref the lines A BRANCH
      MEASUREMENT names under it, then a Markdown table of each
      form, its old and new exit, whether the outputs are the same, and each pin's last non-empty
      output line; a form whose outputs differ while those lines are the same reads "differs above
      the last line". Outputs are compared with each clone's own path written as <clone>, so a path
      that only names the clone is no difference. Under the table, each
      `git grep -n vendor/grado-factorio-tools/scripts` hit in the sibling that no form runs,
      matched by script name: a hit is run when every script of this repository it names is a form's
      tools script, wherever the hit sits (#247's brief).

    It reports and does not judge: a form that differs, or fails at both pins, is evidence for the
    pull request, and the run still exits 0. It exits 1 only when it cannot measure: a pin missing,
    a forms file it cannot read, a clone, fetch or archive that fails, gh or the remote out of
    reach, or, for a {prbody} form, an origin that names no github.com/<owner>/<repository>. It
    fetches, lists the remote and reads pull requests with gh; nothing downloaded is run but the
    sibling's own scripts, at origin's main, as its forms file lists them; that file is read at
    origin's main too, unless -Forms is absolute.

    THE FORMS FILE, the one contract between this repository and each sibling: a PowerShell data
    file the sibling keeps, read with Import-PowerShellDataFile: a relative -Forms in the clone of
    origin's main, an absolute one from that path as given, as the sibling's working tree, so that a
    form the pin ticket's branch adds is run (#464). Either way each form runs in both clones, at
    origin's main, so a `sibling` form whose script only that branch adds fails at both pins; and
    table.md's first line names the file read; for an absolute one, it says it was not read from a
    commit. It
    holds Forms, a list; each form has a Name, used in the file names; From, `tools` for a script of
    this repository, found in the pin's copy, or `sibling` for one of the sibling's own, found from
    its clone's root; Script, its path from there; and Args, a list of arguments. In an argument
    these are replaced:
    - {tools}: the pin's copy of scripts/, in that clone.
    - {headmsg}: the path of a file holding the clone's HEAD commit message, as
      `git log -1 --format=%B` prints it, in UTF-8 with no BOM, each line ending in LF; a CR in
      the message is not kept.
    - {prbody:last-merged:<n>}: the body of one of the sibling's last <n> merged pull requests,
      read with gh. The form is run once for each, as <form>-pr<number>, with the body in place of
      the placeholder and in the environment variable PR_BODY.
    - {stdin:<text>}: an argument that is this alone is taken out, and <text> is given to the
      form on its stdin, as a hook's tool call is. Its cwd may be `.`: the form runs in the clone.
    An example is the second below.

    A BRANCH MEASUREMENT, WITH -Ref (grado-factorio-tools#476). Without -Ref the clones are at
    GitHub's main, so a sibling pull request that adds a form, or a script a form runs, cannot be
    measured on its branch; realistic-fusion-refreshed PR #868 and true-nukes-refreshed PR #78
    each built a stand-in for it by hand. -Ref names a commit of the sibling's checkout, `HEAD`, a
    branch or a SHA, which is resolved there once, before -Out is written, to a full SHA; a name
    that is no commit there fails the run, naming it, with -Out left as it was. Both clones are
    then detached at that SHA; origin's main is still fetched, and each clone's origin/main set to
    it. {headmsg} is that commit's message and the grep is at it. ls-remote.txt is unchanged.
    table.md gains, under its forms line, a line naming -Ref as given, its SHA and the checkout,
    saying it is a local commit, not GitHub's main, with ls-remote.txt's SHA; then, where the
    checkout holds any, a line naming each file with uncommitted changes or untracked there. That
    list is git status against the checkout's HEAD, not the -Ref commit. Where -Ref is HEAD the
    clones hold none of those changes, as only committed content reaches them: a file committed
    at HEAD is in the clones as committed, without its edits, and one never committed, staged or
    untracked, is not there. With -Ref other than HEAD, the list says nothing of what the -Ref
    commit holds. The run goes on. The output prints both lines with the table. A relative -Forms
    is read as committed at -Ref, an absolute one from the working tree as without it: with -Ref,
    commit the forms file and give it relative.
    Only the sibling pull request whose branch is measured cites a -Ref run, at its head or saying
    what came after; a pin move's pull request cites a run without -Ref, at GitHub's main (Truls,
    #476's triage, rulings 6 and 7).

    WHAT IT CANNOT SEE. What Pin tickets says the copy cannot: the clone's own submodule is not
    initialised, its index matches HEAD, and without -Ref a form over origin/main...HEAD reads
    nothing; with -Ref it reads the measured branch's commits since origin's main. A form
    the sibling's file does not list, though the grep under the table names each reference no form
    runs, by name only: a script one form runs may still be called with other arguments elsewhere.
    And what a difference means, which is the pull request's to say.

.PARAMETER Old
    The commit the sibling's pin is at now.

.PARAMETER New
    The commit the pin moves to.

.PARAMETER Out
    The directory everything is written to; empty or not there. Nothing in it is committed.

.PARAMETER Forms
    The forms file. A relative path is read in the clone of the sibling at origin's main; an
    absolute one from that path, as the sibling's working tree. Defaults to scripts/pin-forms.psd1.
    With -Ref, a relative one is read as committed at that commit.

.PARAMETER Ref
    A commit of the sibling's checkout, as `HEAD`, a branch or a SHA, to clone at instead of
    origin's main: a branch measurement, as above. Left out, the run is at origin's main; given
    empty, the run fails before -Out is written.

.PARAMETER SelfTest
    Build, in a temp directory and offline, a tools repository whose pins have between them a plain
    commit, a `!` with no footer, a BREAKING-CHANGE footer and a BREAKING CHANGE footer with a
    trailer in its paragraph, and a sibling holding a forms file, whose origin is a local path, and
    measure the move with pull request bodies read from a stub. Check each form's output and exit at
    both pins, each placeholder, breaking.txt and breaking-lib.ps1's rule, forward, back and over an
    empty range, table.md's rows, a "differs above the last line" row among them, a sibling
    reference no form runs being listed, by script name, and that a write into one clone does not
    show in the other's run. Check the forms file table.md names, and that an absolute -Forms
    outside the clone is what is run, or, naming no file, fails naming it. Check that without -Ref
    ls-remote.txt is origin's main and table.md has no branch measurement line; that with -Ref
    naming a local branch, both clones are at its commit with origin/main at origin's, a script
    only it adds is run, and table.md names the -Ref and the files uncommitted or untracked; and
    that a -Ref naming no commit fails with -Out not written. Then run this script
    itself: copied into the tools repository, with a pin that is not there, it exits 1, naming it;
    copied into a sibling that holds the tools repository as its submodule, with forms that differ
    and none that reads gh, it exits 0, and with a -Ref naming no commit or an empty one, 1. Needs
    git, and no
    game and no network.

.EXAMPLE
    From the sibling's root, with the submodule at the new pin:

        pwsh -File vendor/grado-factorio-tools/scripts/pin-measure.ps1 -Old 8189e45 -New 2c13393 -Out ../pin-8189e45-2c13393

.EXAMPLE
    A branch measurement, of the sibling checkout's HEAD, with its forms file committed there:

        pwsh -File vendor/grado-factorio-tools/scripts/pin-measure.ps1 -Old 36b34f7 -New 36b34f7 -Ref HEAD -Out ../pin-branch

.EXAMPLE
    A forms file, scripts/pin-forms.psd1 in the sibling:

        @{
            Forms = @(
                @{ Name = 'markdown'; From = 'tools'; Script = 'markdown-check.ps1'; Args = @('-All') }
                @{ Name = 'msg'; From = 'tools'; Script = 'commit-check.ps1'; Args = @('-ScopeFile', 'commit-scopes.txt', '{headmsg}') }
                @{ Name = 'body'; From = 'tools'; Script = 'pr-body-check.ps1'; Args = @('-Body', '{prbody:last-merged:2}') }
                @{ Name = 'cd-hook'; From = 'tools'; Script = 'refuse-cd-into-mod-cache.ps1'; Args = @('-Root', '.', '{stdin:{"cwd":".","tool_input":{"command":"cd .mod-cache"}}}') }
                @{ Name = 'ship'; From = 'sibling'; Script = 'scripts/ship-check.ps1'; Args = @('-Tools', '{tools}') }
            )
        }
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $Old,
    [string] $New,
    [string] $Out,
    [string] $Forms = 'scripts/pin-forms.psd1',
    [string] $Ref,
    [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Runs git with the arguments after the first, and throws, naming what the first says was being
# done, when it fails; returns what it printed. A plain function, so a -C or -E is git's.
function Invoke-Git {
    $What = $args[0]; $GitArgs = @($args | Select-Object -Skip 1)
    $said = & git @GitArgs 2>&1
    if ($LASTEXITCODE) { throw "$What failed: git $($GitArgs -join ' '): $($said -join ' ')" }
    $said
}

# Get-BreakingCommit and Format-BreakingCommit, the one rule for a pin move's breaking commits.
. "$PSScriptRoot/breaking-lib.ps1"

# breaking.txt, in $Out: the breaking commits of the move from $Old to $New in $Tools, as
# Format-BreakingCommit writes them.
function Write-BreakingList {
    param([string] $Tools, [string] $Old, [string] $New, [string] $Out)
    $text = Format-BreakingCommit @(Get-BreakingCommit -Repo $Tools -Old $Old -New $New)
    Set-Content -LiteralPath (Join-Path $Out 'breaking.txt') -Value $text
}

# The last line of $Text that is not blank, ready for a table cell.
function Get-LastLine {
    param([string] $Text)
    $last = @($Text -split '\r?\n' | Where-Object { $_.Trim() }) | Select-Object -Last 1
    "$last".Trim() -replace '\|', '\|'
}

# The owner/repository gh reads pull requests from, out of the sibling's $Origin: a URL, or a
# local path that holds github.com/<owner>/<repository>, in either slash; it throws, naming
# $Origin, where none is there.
function Get-RepoSlug {
    param([string] $Origin)
    if ($Origin -notmatch 'github\.com[:/\\]([^:/\\]+)[/\\]([^/\\]+?)(?:\.git)?$') {
        throw "the sibling's origin, $Origin, names no github.com repository, so gh cannot read its pull requests."
    }
    "$($Matches[1])/$($Matches[2])"
}

# The last $Last merged pull requests of $Slug, newest first, as @{ Number; Body }, from gh's
# stdout alone: gh 2.105.0 writes a hint: block to stderr for some reads while exiting 0, and a
# parse of both streams fails on it (#511). Where gh exits non-zero, it throws with what gh wrote.
function Get-MergedBody {
    param([string] $Slug, [int] $Last)
    $said = @(gh pr list --repo $Slug --state merged --limit 30 --json number,body,mergedAt 2>&1)
    if ($LASTEXITCODE) { throw "gh could not read $Slug's merged pull requests: $(($said | ForEach-Object { "$_" }) -join ' ')" }
    @($said | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { "$_" }) -join "`n" | ConvertFrom-Json |
        Sort-Object mergedAt -Descending | Select-Object -First $Last | ForEach-Object { @{ Number = $_.number; Body = $_.body } }
}

# The runs of one form: each its name, its arguments with the placeholders filled, its stdin and
# its PR_BODY. $Bodies reads the last <n> merged pull requests' bodies as @{ Number; Body }.
function Expand-Form {
    param([hashtable] $Form, [string] $Tools, [string] $HeadMsg, [scriptblock] $Bodies)
    $stdin = $null
    $args_ = foreach ($a in @($Form.Args)) {
        $a = "$a"
        if ($a -match '^\{stdin:(.*)\}$') { $stdin = $Matches[1]; continue }
        $a.Replace('{tools}', $Tools).Replace('{headmsg}', $HeadMsg)
    }
    $args_ = @($args_)
    $pr = @($args_ | Where-Object { $_ -match '\{prbody:last-merged:(\d+)\}' })
    if (-not $pr) { return , @{ Name = $Form.Name; Args = $args_; Stdin = $stdin; Body = $null } }
    $null = $pr[0] -match '\{prbody:last-merged:(\d+)\}'
    $token = $Matches[0]
    foreach ($b in & $Bodies ([int] $Matches[1])) {
        , @{ Name = "$($Form.Name)-pr$($b.Number)"; Args = @($args_ | ForEach-Object { $_.Replace($token, [string] $b.Body) }); Stdin = $stdin; Body = [string] $b.Body }
    }
}

# The measurement, into $Out: see the header. $Tools is this repository, $Sibling the sibling's
# checkout, and $Bodies reads pull request bodies, as Expand-Form says. With $Ref, a branch
# measurement: both clones at that commit of $Sibling, not at origin's main (#476).
function Invoke-PinMeasure {
    param([string] $Tools, [string] $Sibling, [string] $Old, [string] $New, [string] $Out, [string] $Forms, [scriptblock] $Bodies,
        [string] $Ref)
    $pins = [ordered]@{}
    foreach ($p in @{ old = $Old; new = $New }.GetEnumerator() | Sort-Object Name -Descending) {
        $sha = git -C $Tools rev-parse --verify --quiet "$($p.Value)^{commit}" 2>$null
        if ($LASTEXITCODE -or -not $sha) { throw "the $($p.Name) pin, $($p.Value), is not a commit of $Tools; fetch it there first." }
        $pins[$p.Name] = $sha
    }
    # Resolved once, before -Out is touched, so every later output names the one commit; and what
    # the checkout holds that no commit does, which the clones therefore lack.
    $refSha = ''
    $uncommitted = @()
    if ($Ref) {
        $refSha = "$(git -C $Sibling rev-parse --verify --quiet "$Ref^{commit}" 2>$null)".Trim()
        if ($LASTEXITCODE -or -not $refSha) { throw "-Ref $Ref is not a commit of the sibling checkout $Sibling, so nothing was measured." }
        $uncommitted = @(Invoke-Git 'listing what is uncommitted in the sibling' -C $Sibling status --porcelain=v1 --untracked-files=all |
                ForEach-Object { "$_".Substring(3) })
    }
    if ((Test-Path -LiteralPath $Out) -and (Get-ChildItem -LiteralPath $Out -Force)) { throw "$Out is not empty; give a new directory." }
    New-Item -ItemType Directory -Path $Out -Force | Out-Null
    $Out = (Resolve-Path -LiteralPath $Out).Path

    $origin = Invoke-Git "reading the sibling's origin" -C $Sibling remote get-url origin
    Invoke-Git "listing the sibling's origin" ls-remote $origin refs/heads/main | Set-Content -LiteralPath (Join-Path $Out 'ls-remote.txt')
    $clones = [ordered]@{}
    foreach ($pin in $pins.Keys) {
        $clone = Join-Path $Out "clone-$pin"
        # The first clone fetches origin's main once; the second is made from the first.
        $from = if ($clones.Count) { $clones['old'] } else { $Sibling }
        Invoke-Git 'cloning the sibling' clone --quiet --no-checkout $from $clone | Out-Null
        if (-not $clones.Count) {
            Invoke-Git "fetching origin's main" -C $clone fetch --quiet $origin main | Out-Null
            $main = Invoke-Git 'reading the fetch' -C $clone rev-parse FETCH_HEAD
            # HEAD is the -Ref commit where one is given; origin/main is origin's main either way.
            $head = if ($refSha) { $refSha } else { $main }
        }
        Invoke-Git 'checking out the clone' -C $clone -c advice.detachedHead=false switch --quiet --detach $head | Out-Null
        Invoke-Git 'setting origin/main' -C $clone update-ref refs/remotes/origin/main $main | Out-Null
        $scripts = Join-Path $clone 'vendor/grado-factorio-tools'
        New-Item -ItemType Directory -Path $scripts -Force | Out-Null
        $zip = Join-Path $Out "scripts-$pin.zip"
        Invoke-Git "archiving the $pin pin's scripts" -C $Tools archive --format=zip -o $zip $pins[$pin] scripts | Out-Null
        Expand-Archive -LiteralPath $zip -DestinationPath $scripts
        Remove-Item -LiteralPath $zip
        $clones[$pin] = $clone
    }

    # A relative -Forms is read in the clone, at origin's main or the -Ref commit; an absolute one
    # from where it names, as the sibling's working tree, so a form the pin ticket's branch adds is
    # run (#464).
    $fromTree = [IO.Path]::IsPathFullyQualified($Forms)
    $file = if ($fromTree) { $Forms } else { Join-Path $clones['old'] $Forms }
    $formsLine = if ($fromTree) { "Forms read from ``$Forms``, in the working tree, not from a commit." }
    elseif ($refSha) { "Forms read from ``$Forms`` in the clone at the -Ref commit, $($refSha.Substring(0, 7))." }
    else { "Forms read from ``$Forms`` in the clone of origin's main at $($main.Substring(0, 7))." }
    # A branch measurement says so under the forms line, and names what it could not see (#476).
    $spans = @($uncommitted | ForEach-Object { '`' + $_ + '`' }) -join ', '
    $refLines = @(if ($refSha) {
            "Branch measurement: -Ref ``$Ref`` is $refSha in the sibling checkout $Sibling, a local commit, not GitHub's main, which ls-remote.txt gives as $main."
            if ($uncommitted) { "Changed or untracked against the sibling checkout's HEAD, not the -Ref commit; where -Ref is HEAD, the clones hold none of these changes: $spans." }
        })
    $list = try { @((Import-PowerShellDataFile -LiteralPath $file).Forms) } catch { throw "the forms file $file could not be read: $($_.Exception.Message)" }
    $rows = [Collections.Generic.List[object]]::new()
    $runScripts = [Collections.Generic.List[object]]::new()
    $results = @{}
    foreach ($pin in $pins.Keys) {
        $clone = $clones[$pin]
        $copy = Join-Path $clone 'vendor/grado-factorio-tools/scripts'
        $headMsg = Join-Path $Out "head-message.$pin.msg"
        # git writes UTF-8, which the console's own code page would mangle in a subject's emoji;
        # the file is written as git printed it, LF and no BOM.
        $was = [Console]::OutputEncoding
        try {
            [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
            $lines = @(Invoke-Git 'reading the HEAD message' -C $clone log -1 --format=%B)
        }
        finally { [Console]::OutputEncoding = $was }
        [IO.File]::WriteAllText($headMsg, ($lines -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
        foreach ($form in $list) {
            $script = if ($form.From -eq 'tools') { Join-Path $copy $form.Script } else { Join-Path $clone $form.Script }
            if ($pin -eq 'old') { $runScripts.Add($form) }
            foreach ($run in Expand-Form -Form $form -Tools $copy -HeadMsg $headMsg -Bodies $Bodies) {
                $was = $env:PR_BODY
                Push-Location -LiteralPath $clone
                try {
                    if ($null -ne $run.Body) { $env:PR_BODY = $run.Body }
                    $said = if ($null -ne $run.Stdin) { $run.Stdin | & pwsh -NoProfile -File $script @($run.Args) 2>&1 | Out-String }
                    else { & pwsh -NoProfile -File $script @($run.Args) 2>&1 | Out-String }
                    $code = $LASTEXITCODE
                }
                finally { Pop-Location; $env:PR_BODY = $was }
                Set-Content -LiteralPath (Join-Path $Out "$($run.Name).$pin.txt") -Value $said -NoNewline
                Set-Content -LiteralPath (Join-Path $Out "$($run.Name).$pin.exit") -Value $code
                if (-not $results.ContainsKey($run.Name)) { $results[$run.Name] = @{}; $rows.Add($run.Name) }
                # Each clone's own path, as either slash writes it, is the same <clone> in both.
                $results[$run.Name][$pin] = @{ Code = $code; Said = $said; Same = $said.Replace($clone, '<clone>').Replace(($clone -replace '\\', '/'), '<clone>') }
            }
        }
    }

    Write-BreakingList -Tools $Tools -Old $pins['old'] -New $pins['new'] -Out $Out

    $table = [Collections.Generic.List[string]]::new()
    $table.Add($formsLine)
    foreach ($l in $refLines) { $table.Add($l) }
    $table.Add('')
    $table.Add('| form | old exit | new exit | output | old last line | new last line |')
    $table.Add('| --- | --- | --- | --- | --- | --- |')
    foreach ($name in $rows) {
        $o = $results[$name]['old']; $n = $results[$name]['new']
        $oldLast = Get-LastLine $o.Said; $newLast = Get-LastLine $n.Said
        $verdict = if ($o.Same -ceq $n.Same) { 'same' } elseif ((Get-LastLine $o.Same) -ceq (Get-LastLine $n.Same)) { 'differs above the last line' } else { 'differs' }
        $table.Add("| $name | $($o.Code) | $($n.Code) | $verdict | $oldLast | $newLast |")
    }
    $hits = @(git -C $clones['old'] grep -n vendor/grado-factorio-tools/scripts HEAD -- 2>$null | ForEach-Object { $_ -replace '^HEAD:', '' })
    $toolNames = @($runScripts | Where-Object { $_.From -eq 'tools' } | ForEach-Object { Split-Path -Leaf $_.Script })
    $unrun = foreach ($hit in $hits) {
        $named = @([regex]::Matches($hit, 'vendor/grado-factorio-tools/scripts/([\w.-]+)') | ForEach-Object { $_.Groups[1].Value })
        if ($named -and -not ($named | Where-Object { $_ -notin $toolNames })) { continue }
        $hit
    }
    $table.Add('')
    $table.Add("Sibling references no form runs (``git grep -n vendor/grado-factorio-tools/scripts`` at $($head.Substring(0, 7))):")
    $table.Add('')
    # Two backticks, and a space inside each, so a hit's own backticks stay in the span.
    if ($unrun) { foreach ($u in $unrun) { $table.Add("- ```` $u ````") } } else { $table.Add('- none') }
    Set-Content -LiteralPath (Join-Path $Out 'table.md') -Value $table
    $table
}

if ($SelfTest) {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "pin-measure-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    $toolsRepo = Join-Path $temp 'tools'; $sib = Join-Path $temp 'sibling'; $outDir = Join-Path $temp 'out'
    $failures = 0; $n = 0
    $check = {
        param([string] $Name, [bool] $Ok, [string] $Said)
        $script:n++
        Write-Host ("self-test {0}: {1} -- {2}" -f $script:n, $Name, $(if ($Ok) { 'ok' } else { 'FAILED' }))
        if (-not $Ok) { $script:failures++; if ($Said) { Write-Host "    $Said" } }
    }
    $write = { param($path, [string[]] $text) New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null; Set-Content -LiteralPath $path -Value $text }
    $commit = { param($repo, [string[]] $msg) git -C $repo add -A; git -C $repo commit --quiet @($msg | ForEach-Object { '-m', $_ }); git -C $repo rev-parse HEAD }
    try {
        foreach ($r in $toolsRepo, $sib) {
            New-Item -ItemType Directory -Path $r -Force | Out-Null
            git -C $r init --quiet -b main; if ($LASTEXITCODE) { throw 'git init failed; the self-test needs git.' }
            git -C $r config user.email self-test@example.com; git -C $r config user.name self-test
        }
        $tool = {
            param([string] $above, [string] $last)
            'param($Mode, $Value)', 'switch ($Mode) {', "  'same' { 'same' }", "  'above' { '$above'; 'last' }", "  'last' { '$last' }",
            "  'stdin' { 'stdin: ' + [Console]::In.ReadToEnd() }", "  'headmsg' { 'head: ' + (Get-Content -LiteralPath `$Value -Raw).Trim() }",
            "  'prbody' { 'arg: ' + `$Value + '; env: ' + `$env:PR_BODY }", "  'tools' { 'tools has t.ps1: ' + (Test-Path (Join-Path `$Value 't.ps1')) }", '}', "exit $(if ($last -eq 'v2') { 3 } else { 0 })"
        }
        & $write (Join-Path $toolsRepo 'scripts/t.ps1') (& $tool 'one' 'v1')
        $oldPin = & $commit $toolsRepo '✨ feat: one'
        # Between the pins: a plain commit, a `!` with no footer, a footer spelt with a hyphen, and
        # the new pin, whose footer has a trailer in its paragraph.
        & $write (Join-Path $toolsRepo 'scripts/other.txt') 'plain'
        $null = & $commit $toolsRepo '🐛 fix: plain', 'Not breaking.'
        & $write (Join-Path $toolsRepo 'scripts/other.txt') 'bang'
        $null = & $commit $toolsRepo '✨ feat!: bang'
        & $write (Join-Path $toolsRepo 'scripts/other.txt') 'hyphen'
        $null = & $commit $toolsRepo '✨ feat: hyphen', 'BREAKING-CHANGE: written with a hyphen.'
        & $write (Join-Path $toolsRepo 'scripts/t.ps1') (& $tool 'two' 'v2')
        $newPin = & $commit $toolsRepo '✨ feat!: two', 'Body.', "BREAKING CHANGE: t.ps1 says v2.`nIt exits 3.`nCo-Authored-By: someone <a@b.c>"
        & $write (Join-Path $sib 'scripts/w.ps1') 'if (Test-Path marker.txt) { ''marker seen'' } else { ''no marker'' }', 'Set-Content marker.txt x'
        & $write (Join-Path $sib 'docs/use.md') 'Run `vendor/grado-factorio-tools/scripts/t.ps1` and `vendor/grado-factorio-tools/scripts/unrun.ps1`.'
        & $write (Join-Path $sib 'docs/run.md') 'Run `vendor/grado-factorio-tools/scripts/t.ps1` alone.'
        & $write (Join-Path $sib 'scripts/w2.ps1') '# runs vendor/grado-factorio-tools/scripts/elsewhere.ps1'
        # For the run of this script itself: forms that differ, and none that reads gh.
        & $write (Join-Path $sib 'scripts/pin-forms-offline.psd1') "@{ Forms = @( @{ Name = 'last'; From = 'tools'; Script = 't.ps1'; Args = @('last') } ) }"
        & $write (Join-Path $sib 'scripts/pin-forms.psd1') @(
            '@{ Forms = @(',
            "  @{ Name = 'same'; From = 'tools'; Script = 't.ps1'; Args = @('same') }",
            "  @{ Name = 'above'; From = 'tools'; Script = 't.ps1'; Args = @('above') }",
            "  @{ Name = 'last'; From = 'tools'; Script = 't.ps1'; Args = @('last') }",
            "  @{ Name = 'stdin'; From = 'tools'; Script = 't.ps1'; Args = @('stdin', '{stdin:{""cwd"":"".""}}') }",
            "  @{ Name = 'headmsg'; From = 'tools'; Script = 't.ps1'; Args = @('headmsg', '{headmsg}') }",
            "  @{ Name = 'prbody'; From = 'tools'; Script = 't.ps1'; Args = @('prbody', 'body={prbody:last-merged:2}') }",
            "  @{ Name = 'tools'; From = 'tools'; Script = 't.ps1'; Args = @('tools', '{tools}') }",
            "  @{ Name = 'writes'; From = 'sibling'; Script = 'scripts/w2.ps1'; Args = @() }",
            "  @{ Name = 'marker'; From = 'sibling'; Script = 'scripts/w.ps1'; Args = @() }",
            ') }')
        # A subject outside ASCII, so a {headmsg} read in the console's code page would show.
        $null = & $commit $sib '✨ feat: the sibling at main'
        git -C $sib remote add origin $sib
        $stub = { param([int] $count) @(@{ Number = 8; Body = 'body eight' }, @{ Number = 7; Body = 'body seven' }) | Select-Object -First $count }
        $table = $null
        # The console is set to Latin-1, which reads git's ASCII as it is and mangles its UTF-8, as
        # a Windows console's code page does; and it is to be Latin-1 still after the run.
        $was = [Console]::OutputEncoding
        try {
            [Console]::OutputEncoding = [Text.Encoding]::Latin1
            $threw = try { $table = @(Invoke-PinMeasure -Tools $toolsRepo -Sibling $sib -Old $oldPin -New $newPin -Out $outDir -Forms 'scripts/pin-forms.psd1' -Bodies $stub); '' } catch { $_.Exception.Message }
            $page = [Console]::OutputEncoding.CodePage
        }
        finally { [Console]::OutputEncoding = $was }
        & $check 'the measurement returns, with forms that differ' (-not $threw -and $table) $threw
        & $check "the console's output encoding is the same after the run as before it" ($page -eq [Text.Encoding]::Latin1.CodePage) "$page"
        $gitMsg = Join-Path $temp 'head-message.git'
        git -C $sib log -1 --format=%B --output=$gitMsg
        $written = [IO.File]::ReadAllBytes((Join-Path $outDir 'head-message.old.msg')); $held = [IO.File]::ReadAllBytes($gitMsg)
        & $check "{headmsg}'s file is byte for byte what git log -1 --format=%B prints, for a message with an emoji in its subject and no CR" (
            [Linq.Enumerable]::SequenceEqual($written, $held)) "written: $([BitConverter]::ToString($written)); git: $([BitConverter]::ToString($held))"
        $slugs = @('C:\src\github.com\trulsjo\grado-factorio-modpack.git', 'C:/src/github.com/trulsjo/grado-factorio-modpack.git',
            'git@github.com:trulsjo/grado-factorio-modpack.git', 'https://github.com/trulsjo/grado-factorio-modpack') | ForEach-Object {
            try { Get-RepoSlug $_ } catch { "threw: $($_.Exception.Message)" } }
        $refused = try { "returned: $(Get-RepoSlug 'C:\src\elsewhere\grado-factorio-modpack.git')" } catch { $_.Exception.Message }
        & $check 'the slug is read from an origin in backslashes, in forward slashes, as git@github.com: and as https://github.com/; one naming no github.com is refused, naming it' (
            @($slugs | Where-Object { $_ -ceq 'trulsjo/grado-factorio-modpack' }).Count -eq 4 -and
            $refused -match '^the sibling''s origin, C:\\src\\elsewhere\\grado-factorio-modpack\.git, names no github\.com repository') "$($slugs -join ', ') | $refused"
        $read = { param($name) $p = Join-Path $outDir $name; if (Test-Path -LiteralPath $p) { (Get-Content -LiteralPath $p -Raw).Trim() } else { "<no $name>" } }
        $names = 'same', 'above', 'last', 'stdin', 'headmsg', 'prbody-pr8', 'prbody-pr7', 'tools', 'writes', 'marker'
        $missing = @(foreach ($f in $names) { foreach ($pin in 'old', 'new') { foreach ($ext in 'txt', 'exit') { if (-not (Test-Path -LiteralPath (Join-Path $outDir "$f.$pin.$ext"))) { "$f.$pin.$ext" } } } })
        & $check "each form's output and exit kept at both pins" (-not $missing) "missing: $missing"
        & $check 'the exits are kept as each pin gave them' ((& $read 'last.old.exit') -eq '0' -and (& $read 'last.new.exit') -eq '3' -and (& $read 'last.new.txt') -eq 'v2') "$(& $read 'last.old.exit') $(& $read 'last.new.exit') $(& $read 'last.new.txt')"
        & $check '{stdin:<text>} is given on stdin and taken out of the arguments' ((& $read 'stdin.old.txt') -eq 'stdin: {"cwd":"."}') (& $read 'stdin.old.txt')
        # The emoji is the form's own output, read back in Latin-1: the file's bytes are held above.
        & $check "{headmsg} is a file holding the clone's HEAD message" ((& $read 'headmsg.old.txt') -cmatch '^head: \S+ feat: the sibling at main$') (& $read 'headmsg.old.txt')
        & $check '{prbody:last-merged:2} runs once per body, in place and in PR_BODY' ((& $read 'prbody-pr8.new.txt') -eq 'arg: body=body eight; env: body eight' -and (& $read 'prbody-pr7.old.txt') -eq 'arg: body=body seven; env: body seven') "$(& $read 'prbody-pr8.new.txt') | $(& $read 'prbody-pr7.old.txt')"
        & $check "{tools} is the pin's copy of scripts/" ((& $read 'tools.old.txt') -eq 'tools has t.ps1: True') (& $read 'tools.old.txt')
        & $check "a form that writes into its clone does not show in the other pin's run" ((& $read 'marker.old.txt') -eq 'no marker' -and (& $read 'marker.new.txt') -eq 'no marker') "$(& $read 'marker.old.txt') | $(& $read 'marker.new.txt')"
        $forward = (Format-BreakingCommit @(Get-BreakingCommit -Repo $toolsRepo -Old $oldPin -New $newPin)) -join "`n"
        $back = (Format-BreakingCommit @(Get-BreakingCommit -Repo $toolsRepo -Old $newPin -New $oldPin)) -join "`n"
        $breaking = (& $read 'breaking.txt') -replace "`r"
        & $check "breaking.txt holds Format-BreakingCommit's text of the move, subject and indented footer" (
            $breaking -ceq $forward -and $breaking -cmatch "(?m)^breaking: $($newPin.Substring(0, 4))[0-9a-f]* ✨ feat!: two\n    BREAKING CHANGE: t\.ps1 says v2\.\n    It exits 3\.$") $breaking
        & $check 'a ! commit with no footer is listed, with a note under it' ($forward -cmatch '(?m)^breaking: [0-9a-f]+ ✨ feat!: bang\n    \(no BREAKING CHANGE: footer\)$') $forward
        & $check 'a BREAKING-CHANGE: footer is listed' ($forward -cmatch '(?m)^breaking: [0-9a-f]+ ✨ feat: hyphen\n    BREAKING-CHANGE: written with a hyphen\.$') $forward
        & $check "a trailer in the footer's paragraph is not printed" ($forward -match 'It exits 3\.' -and $forward -notmatch 'Co-Authored-By') $forward
        & $check 'a plain commit in the range is not listed' ($forward -notmatch 'fix: plain' -and @($forward -split "`n" | Where-Object { $_ -like 'breaking*' }).Count -eq 3) $forward
        & $check 'a pin moved back lists its breaking commits as dropped' (
            @($back -split "`n" | Where-Object { $_ -like 'breaking, dropped: *' }).Count -eq 3 -and $back -notmatch '(?m)^breaking: ' -and $back -match 'dropped: [0-9a-f]+ ✨ feat!: bang') $back
        $emptyOut = Join-Path $temp 'empty'; New-Item -ItemType Directory -Path $emptyOut | Out-Null
        Write-BreakingList -Tools $toolsRepo -Old $oldPin -New $oldPin -Out $emptyOut
        $empty = "$(Get-Content -LiteralPath (Join-Path $emptyOut 'breaking.txt') -Raw)".Trim()
        & $check 'an empty range writes none to breaking.txt' ($empty -ceq 'none') $empty
        # Commits off the old pin, outside the fixture's range, each a move of its own.
        $side = { param([string[]] $msg) git -C $toolsRepo commit-tree "$oldPin^{tree}" -p $oldPin @($msg | ForEach-Object { '-m', $_ }) }
        $text = { param($to) (Format-BreakingCommit @(Get-BreakingCommit -Repo $toolsRepo -Old $oldPin -New $to)) -join "`n" }
        $para = & $text (& $side 'feat: para', 'BREAKING CHANGE: the footer.', 'A later paragraph.')
        & $check 'a footer ends at a blank line: a later paragraph is not printed' ($para -cmatch '(?m)^    BREAKING CHANGE: the footer\.$' -and $para -notmatch 'later paragraph') $para
        $two = & $text (& $side 'feat: two', 'BREAKING CHANGE: first.', 'BREAKING-CHANGE: second.')
        & $check 'a body with two footers prints both, in order' ($two -cmatch '(?m)^    BREAKING CHANGE: first\.\n    BREAKING-CHANGE: second\.$') $two
        $plain = @(Get-BreakingCommit -Repo $toolsRepo -Old $oldPin -New (& $side 'fix: say "wow!: x"', 'breaking change: written in lower case.'))
        & $check 'a !: after the first colon, and a footer in lower case, are not breaking' (-not $plain) ($plain | Out-String)
        $order = @(Get-BreakingCommit -Repo $toolsRepo -Old (& $side 'feat!: side') -New $newPin | ForEach-Object Dropped)
        & $check 'a pin moved sideways lists what it brings in, then what it drops' (($order -join ',') -ceq 'False,False,False,True') ($order -join ',')
        # The console is set to UTF-16 first, which no caller leaves it at, so a library that set
        # UTF-8 and kept it would show; and the throw carries git's own words.
        $was = [Console]::OutputEncoding
        try {
            [Console]::OutputEncoding = [Text.Encoding]::Unicode
            $threw = try { $null = Get-BreakingCommit -Repo $toolsRepo -Old 0123456789abcdef -New $newPin; '' } catch { $_.Exception.Message }
            $page = [Console]::OutputEncoding.CodePage
        }
        finally { [Console]::OutputEncoding = $was }
        & $check "a range git cannot read throws, naming it with git's message, and the console's encoding is left as it was" (
            $threw -match 'could not read the range 0123456789abcdef\.\..*fatal' -and $page -eq 1200) "$threw $page"
        $md = & $read 'table.md'
        & $check "table.md's rows: same, differs above the last line, differs" (
            $md -match '(?m)^\| same \| 0 \| 3 \| same \| same \| same \|\r?$' -and
            $md -match '(?m)^\| above \| 0 \| 3 \| differs above the last line \| last \| last \|\r?$' -and
            $md -match '(?m)^\| last \| 0 \| 3 \| differs \| v1 \| v2 \|\r?$' -and
            $md -match '(?m)^\| tools \| 0 \| 3 \| same \|') $md
        & $check 'a sibling reference to a script no form runs is listed, even inside a script a form runs; one naming only run scripts is not' (
            $md -match 'docs/use\.md:1:.*unrun\.ps1' -and $md -match 'scripts/w2\.ps1:1:.*elsewhere\.ps1' -and $md -notmatch 'docs/run\.md') $md
        # The first line, then a blank one, so the table under it is a table and not a paragraph.
        $sibMain = "$(git -C $sib rev-parse HEAD)".Trim().Substring(0, 7)
        $mdLines = $md -split '\r?\n'
        & $check "table.md opens with a relative -Forms named as read in the clone of origin's main, at the sibling's main, then a blank line and the table" (
            $mdLines[0] -ceq "Forms read from ``scripts/pin-forms.psd1`` in the clone of origin's main at $sibMain." -and
            $mdLines[1] -eq '' -and $mdLines[2] -like '| form |*') $md
        $again = try { Invoke-PinMeasure -Tools $toolsRepo -Sibling $sib -Old $oldPin -New $newPin -Out $outDir -Forms 'scripts/pin-forms.psd1' -Bodies $stub | Out-Null; '' } catch { $_.Exception.Message }
        & $check 'an -Out that is not empty is refused' ($again -match 'not empty') $again
        # An absolute -Forms outside the clone, as a sibling's working tree is, with a form the
        # clone's own forms file lacks: that form is run at both pins.
        $wtForms = Join-Path $temp 'working-tree/pin-forms.psd1'
        & $write $wtForms "@{ Forms = @( @{ Name = 'branch-only'; From = 'tools'; Script = 't.ps1'; Args = @('last') } ) }"
        $outAbs = Join-Path $temp 'out-abs'
        $threw = try { $null = Invoke-PinMeasure -Tools $toolsRepo -Sibling $sib -Old $oldPin -New $newPin -Out $outAbs -Forms $wtForms -Bodies $stub; '' } catch { $_.Exception.Message }
        $mdAbs = if (Test-Path -LiteralPath (Join-Path $outAbs 'table.md')) { Get-Content -LiteralPath (Join-Path $outAbs 'table.md') -Raw } else { "<no table.md> $threw" }
        & $check 'an absolute -Forms is read from that path: a form only it lists is run at both pins' (
            -not $threw -and $mdAbs -match '(?m)^\| branch-only \| 0 \| 3 \| differs \| v1 \| v2 \|\r?$' -and $mdAbs -notmatch '(?m)^\| same \|') $mdAbs
        $absLines = $mdAbs -split '\r?\n'
        & $check 'table.md opens with an absolute -Forms named by its path, as read from the working tree, not from a commit, then a blank line' (
            $absLines[0] -ceq "Forms read from ``$wtForms``, in the working tree, not from a commit." -and $absLines[1] -eq '') $mdAbs
        $noFile = Join-Path $temp 'working-tree/no-such-forms.psd1'
        $threw = try { $null = Invoke-PinMeasure -Tools $toolsRepo -Sibling $sib -Old $oldPin -New $newPin -Out (Join-Path $temp 'out-none') -Forms $noFile -Bodies $stub; '' } catch { $_.Exception.Message }
        & $check 'an absolute -Forms naming no file fails, naming the path' ($threw.Contains("the forms file $noFile could not be read")) $threw
        # Without -Ref, ls-remote.txt is origin's main as git lists it, and table.md holds no
        # line of a branch measurement (#476).
        $sibMainFull = "$(git -C $sib rev-parse HEAD)".Trim()
        & $check 'without -Ref, ls-remote.txt is origin''s main and table.md has no branch measurement line' (
            (& $read 'ls-remote.txt') -ceq "$sibMainFull`trefs/heads/main" -and $md -notmatch 'Branch measurement|Uncommitted') "$(& $read 'ls-remote.txt') | $md"
        # And table.md whole, line for line, as the script wrote it before -Ref was added, for the
        # absolute -Forms run, whose one form makes every line fixed: the forms line, the table,
        # and the grep line at origin's main with the two hits no form runs (#476).
        $wholeAbs = @(
            "Forms read from ``$wtForms``, in the working tree, not from a commit.", '',
            '| form | old exit | new exit | output | old last line | new last line |', '| --- | --- | --- | --- | --- | --- |',
            '| branch-only | 0 | 3 | differs | v1 | v2 |', '',
            "Sibling references no form runs (``git grep -n vendor/grado-factorio-tools/scripts`` at $sibMain):", '',
            '- `` docs/use.md:1:Run `vendor/grado-factorio-tools/scripts/t.ps1` and `vendor/grado-factorio-tools/scripts/unrun.ps1`. ``',
            '- `` scripts/w2.ps1:1:# runs vendor/grado-factorio-tools/scripts/elsewhere.ps1 ``') -join "`n"
        $gotAbs = ($mdAbs -replace '\r', '').TrimEnd("`n")
        & $check 'without -Ref, table.md is held whole, line for line, as before -Ref was added' ($gotAbs -ceq $wholeAbs) "got:`n$gotAbs`nwanted:`n$wholeAbs"
        # A branch measurement: a local branch, not on origin's main, adds a script and the form
        # that runs it, committed; then an uncommitted edit and an untracked file, which the
        # clones lack.
        git -C $sib switch --quiet -c feature
        & $write (Join-Path $sib 'scripts/branch-only.ps1') "'branch script ran'"
        & $write (Join-Path $sib 'scripts/pin-forms-ref.psd1') "@{ Forms = @( @{ Name = 'branch-script'; From = 'sibling'; Script = 'scripts/branch-only.ps1'; Args = @() } ) }"
        $refSha = & $commit $sib 'feat: a branch form'
        & $write (Join-Path $sib 'scripts/branch-only.ps1') "'edited, not committed'"
        & $write (Join-Path $sib 'untracked.txt') 'not committed'
        $outRef = Join-Path $temp 'out-ref'
        try { $threw = try { $null = Invoke-PinMeasure -Tools $toolsRepo -Sibling $sib -Old $oldPin -New $newPin -Out $outRef -Forms 'scripts/pin-forms-ref.psd1' -Bodies $stub -Ref 'feature'; '' } catch { $_.Exception.Message } }
        finally { git -C $sib checkout --quiet -- scripts/branch-only.ps1; Remove-Item -LiteralPath (Join-Path $sib 'untracked.txt'); git -C $sib switch --quiet main }
        $mdRef = if (Test-Path -LiteralPath (Join-Path $outRef 'table.md')) { Get-Content -LiteralPath (Join-Path $outRef 'table.md') -Raw } else { "<no table.md> $threw" }
        $heads = @(foreach ($pin in 'old', 'new') { "$(git -C (Join-Path $outRef "clone-$pin") rev-parse HEAD)".Trim(); "$(git -C (Join-Path $outRef "clone-$pin") rev-parse origin/main)".Trim() })
        & $check 'with -Ref, both clones are at that commit with origin/main at origin''s, and a script only it adds is run at both pins, as committed' (
            -not $threw -and ($heads -join ' ') -ceq "$refSha $sibMainFull $refSha $sibMainFull" -and $refSha -cne $sibMainFull -and
            $mdRef -match '(?m)^\| branch-script \| 0 \| 0 \| same \| branch script ran \| branch script ran \|\r?$') "$($heads -join ' ') | $mdRef"
        $refLines = $mdRef -split '\r?\n'
        & $check 'with -Ref, table.md names the -Ref as given and its full SHA under the forms line, then the uncommitted and untracked files, then a blank line' (
            $refLines[0] -ceq "Forms read from ``scripts/pin-forms-ref.psd1`` in the clone at the -Ref commit, $($refSha.Substring(0, 7))." -and
            $refLines[1] -ceq "Branch measurement: -Ref ``feature`` is $refSha in the sibling checkout $sib, a local commit, not GitHub's main, which ls-remote.txt gives as $sibMainFull." -and
            $refLines[2] -ceq 'Changed or untracked against the sibling checkout''s HEAD, not the -Ref commit; where -Ref is HEAD, the clones hold none of these changes: `scripts/branch-only.ps1`, `untracked.txt`.' -and
            $refLines[3] -eq '' -and (Get-Content -LiteralPath (Join-Path $outRef 'ls-remote.txt') -Raw).Trim() -ceq "$sibMainFull`trefs/heads/main") $mdRef
        & $check 'with -Ref, the grep line names the -Ref commit, where the clones are, not origin''s main' (
            $refLines -ccontains "Sibling references no form runs (``git grep -n vendor/grado-factorio-tools/scripts`` at $($refSha.Substring(0, 7))):") $mdRef
        $outBad = Join-Path $temp 'out-bad-ref'
        $threw = try { $null = Invoke-PinMeasure -Tools $toolsRepo -Sibling $sib -Old $oldPin -New $newPin -Out $outBad -Forms 'scripts/pin-forms.psd1' -Bodies $stub -Ref 'no-such-ref'; '' } catch { $_.Exception.Message }
        & $check 'a -Ref that names no commit of the checkout fails, naming it, and -Out is not written' (
            $threw -ceq "-Ref no-such-ref is not a commit of the sibling checkout $sib, so nothing was measured." -and -not (Test-Path -LiteralPath $outBad)) $threw
        # The merged pull requests' reader, with a gh of its own first on the path (#511): one that
        # exits 0 with a hint: on stderr and the list on stdout, and one that exits 1.
        $standIn = {
            param([string] $Name, [string] $Out, [string[]] $Err, [int] $Code)
            $bin = Join-Path $temp $Name
            New-Item -ItemType Directory -Path $bin -Force | Out-Null
            if ($IsWindows) {
                # The redirection first: after the text, cmd keeps the space before it.
                $lines = @('@echo off') + @($Err | ForEach-Object { ">&2 echo $_" }); if ($Out) { $lines += "echo $Out" }
                Set-Content -LiteralPath (Join-Path $bin 'gh.cmd') -Value (($lines + "exit /b $Code") -join "`r`n")
            }
            else {
                $lines = @('#!/bin/sh') + @($Err | ForEach-Object { "printf '%s\n' '$_' >&2" }); if ($Out) { $lines += "printf '%s\n' '$Out'" }
                Set-Content -LiteralPath (Join-Path $bin 'gh') -Value (($lines + "exit $Code") -join "`n")
                chmod +x (Join-Path $bin 'gh')
            }
            $bin
        }
        $merged = '[{"number":4,"body":"four","mergedAt":"2026-01-04T00:00:00Z"},{"number":5,"body":"five","mergedAt":"2026-01-05T00:00:00Z"},{"number":3,"body":"three","mergedAt":"2026-01-03T00:00:00Z"}]'
        # gh 2.105.0's block as #511's triage comment quotes it: only its first line opens hint:.
        $hint = @('hint: if you need to wait for the checks of this pull request to finish before continuing, use this instead of polling:',
            '    gh event listen --resource https://github.com/octo/repo/pull/12 --event com.github.pull_request.check_suite.status.changed.v1',
            '  - It prints the first event as a JSON line on stdout and exits; run it again to wait for the next one.')
        $hinted = & $standIn 'gh-hinted' $merged $hint 0
        $refusing = & $standIn 'gh-refusing' '' 'HTTP 404: Not Found' 1
        $kept = $env:PATH
        try {
            $env:PATH = "$hinted$([IO.Path]::PathSeparator)$kept"
            $read = try { @(Get-MergedBody -Slug 'octo/repo' -Last 2) } catch { $_.Exception.Message }
            $env:PATH = "$refusing$([IO.Path]::PathSeparator)$kept"
            $threw = try { $null = Get-MergedBody -Slug 'octo/repo' -Last 2; '' } catch { $_.Exception.Message }
        }
        finally { $env:PATH = $kept }
        & $check 'a gh that exits 0 with a hint: on stderr has its merged pull requests read from stdout, newest first (#511)' (
            $read -isnot [string] -and @($read).Count -eq 2 -and $read[0].Number -eq 5 -and $read[0].Body -ceq 'five' -and $read[1].Number -eq 4) "$read"
        & $check 'a gh that exits 1 throws, naming the repository and what gh wrote on stderr (#511)' (
            $threw -ceq "gh could not read octo/repo's merged pull requests: HTTP 404: Not Found") $threw
        # The script itself, from inside the tools repository, with a pin that is not there.
        Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $toolsRepo 'scripts/pin-measure.ps1')
        Copy-Item -LiteralPath "$PSScriptRoot/breaking-lib.ps1" -Destination (Join-Path $toolsRepo 'scripts/breaking-lib.ps1')
        $said = & pwsh -NoProfile -File (Join-Path $toolsRepo 'scripts/pin-measure.ps1') -Old 0123456789abcdef -New $newPin -Out (Join-Path $temp 'out2') 2>&1 | Out-String
        & $check 'a pin missing from the tools repository: exit 1, naming it' ($LASTEXITCODE -eq 1 -and $said -match '0123456789abcdef') "$LASTEXITCODE $said"
        # The script itself, as a sibling runs it: from its submodule, with forms that differ.
        git -C $sib -c protocol.file.allow=always submodule add --quiet $toolsRepo vendor/grado-factorio-tools 2>&1 | Out-Null
        $inSub = Join-Path $sib 'vendor/grado-factorio-tools/scripts/pin-measure.ps1'
        Copy-Item -LiteralPath $PSCommandPath -Destination $inSub
        Copy-Item -LiteralPath "$PSScriptRoot/breaking-lib.ps1" -Destination (Join-Path (Split-Path $inSub) 'breaking-lib.ps1')
        $out3 = Join-Path $temp 'out3'
        $said = & pwsh -NoProfile -File $inSub -Old $oldPin -New $newPin -Out $out3 -Forms 'scripts/pin-forms-offline.psd1' 2>&1 | Out-String
        $code = $LASTEXITCODE
        $row = if (Test-Path -LiteralPath (Join-Path $out3 'table.md')) { Get-Content -LiteralPath (Join-Path $out3 'table.md') -Raw } else { '' }
        & $check 'run from a sibling, with forms that differ: exit 0' ($code -eq 0 -and $row -match '(?m)^\| last \| 0 \| 3 \| differs \|') "$code $said"
        $out4 = Join-Path $temp 'out4'
        $said = & pwsh -NoProfile -File $inSub -Old $oldPin -New $newPin -Out $out4 -Ref no-such-ref 2>&1 | Out-String
        & $check 'run from a sibling with a -Ref that names no commit: exit 1, naming it, and -Out not written' (
            $LASTEXITCODE -eq 1 -and $said -match 'FAILED - pin-measure: -Ref no-such-ref is not a commit' -and -not (Test-Path -LiteralPath $out4)) "$LASTEXITCODE $said"
        $out5 = Join-Path $temp 'out5'
        $said = & pwsh -NoProfile -File $inSub -Old $oldPin -New $newPin -Out $out5 -Ref '' 2>&1 | Out-String
        & $check 'run from a sibling with an empty -Ref: exit 1, naming it, and -Out not written' (
            $LASTEXITCODE -eq 1 -and $said -match 'FAILED - pin-measure: -Ref is empty' -and -not (Test-Path -LiteralPath $out5)) "$LASTEXITCODE $said"
    }
    finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $n case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $n cases."
    exit 0
}

try {
    if (-not ($Old -and $New -and $Out)) { throw 'give -Old, -New and -Out.' }
    # An empty -Ref would read as left out and measure GitHub's main, where a branch was asked for.
    if ($PSBoundParameters.ContainsKey('Ref') -and -not $Ref) { throw "-Ref is empty; give a commit, or leave -Ref out to measure GitHub's main." }
    $tools = Split-Path $PSScriptRoot -Parent
    $sibling = git -C $tools rev-parse --show-superproject-working-tree 2>$null
    $bodies = {
        param([int] $count)
        Get-MergedBody -Slug (Get-RepoSlug (git -C $sibling remote get-url origin)) -Last $count
    }
    # The pins are checked first, so a pin that is not there is named before anything else.
    foreach ($pin in $Old, $New) {
        git -C $tools rev-parse --verify --quiet "$pin^{commit}" *> $null
        if ($LASTEXITCODE) { throw "the pin $pin is not a commit of $tools; fetch it there first." }
    }
    if (-not $sibling) { throw "$tools is not a submodule of a sibling; run this from the sibling's vendor/grado-factorio-tools/scripts/." }
    Invoke-PinMeasure -Tools $tools -Sibling $sibling -Old $Old -New $New -Out $Out -Forms $Forms -Bodies $bodies -Ref $Ref
    Write-Host ''
    Write-Host "OK - pin-measure: measured $Old to $New; everything is in $Out."
    exit 0
}
catch {
    [Console]::Error.WriteLine("FAILED - pin-measure: $($_.Exception.Message)")
    exit 1
}
