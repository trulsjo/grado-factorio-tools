<#
.SYNOPSIS
    Brings a sibling's vendor/grado-factorio-tools submodule to the pin the new HEAD records,
    run by the sibling's post-checkout and post-merge hooks, and post-rewrite after a rebase.
    It always exits 0: a hook's exit status becomes the checkout's, and the checkout is done.

.DESCRIPTION
    WHY (grado-factorio-tools#253, from grado-factorio-modpack#391). A branch switch or a merge
    leaves the submodule at the pin it was on. Measured 2026-10-26 in grado-factorio-modpack: a
    `git switch --detach 2cd7936` left it at 2c13393 where that commit records 8189e45, and git
    status showed ` M vendor/grado-factorio-tools`, which a `git add -A` then stages as a pin move
    nobody meant.

    WHERE IT RUNS. From the sibling's root, which is where git runs a hook, called by the
    sibling's .githooks/<hook> wrapper with the hook's name and git's arguments; the second
    example below is one. It runs from the copy in vendor/ that is checked out when the hook
    fires, the old pin's, and reads nothing of the new pin's copy.

    WHAT IT COMPARES. The gitlink of -Path, the commit the tree records for the submodule, in the
    old HEAD and the new one:
    - post-checkout: the old and new HEAD are git's first two arguments. It acts only on a branch
      checkout, whose third argument is 1; a file checkout, 0, is never acted on.
    - post-merge: the old HEAD is ORIG_HEAD, the new one HEAD.
    - post-rewrite: only after a rebase, its first argument `rebase`. The old HEAD is the commit
      the rebase replayed onto, the parent of the first rewritten commit git lists on stdin: the
      rebase checked it out, and post-checkout followed its pin. The new one is HEAD. An amend
      is never acted on: it changes a gitlink only by committing the submodule as it stands.
      Measured 2026-10-27 on git 2.37.3 with only post-checkout and post-merge wired: a
      `git rebase main` onto a main that moved the pin left the submodule in step, by
      post-checkout on the rebase's own checkout; where the branch rebased moved the pin itself,
      it was left at main's pin, with HEAD recording the branch's, and ` M` in git status.
    Where the pin did not change, or either HEAD records none, as a clone's first checkout, which
    has no old HEAD, it prints nothing.

    WHEN IT UPDATES. Only a submodule that is initialised, clean, and at the pin the old HEAD
    recorded: it runs `git submodule update -- <path>`, which fetches a pin the clone does not
    hold, and prints `<hook>: <path> <old7> -> <new7>`.

    WHEN IT LEAVES IT, printing one line that says why and the command to run:
    - the submodule is not initialised;
    - its clone has uncommitted changes, an untracked file among them;
    - its HEAD is not the old HEAD's pin, as when a newer tools commit was checked out there to
      try it;
    - git cannot read the submodule's HEAD;
    - `git submodule update` failed, as when the pin could not be fetched.
    A hook it does not serve, or anything else that fails, prints one line saying the submodule
    was not checked, with the command to bring it to the pin HEAD records. It runs with git's
    GIT_DIR, GIT_WORK_TREE and GIT_INDEX_FILE taken out of its environment, which git sets for a
    hook when it is run with --git-dir, so its git calls into the submodule read the submodule.

    WHAT IT CANNOT SEE. A HEAD moved by a command that runs none of these hooks: `git reset
    --hard` leaves the submodule as it was, and so do `git rebase --abort` and `--quit`, after
    the rebase's own checkout moved it. A `git merge --squash`, whose post-merge sees ORIG_HEAD
    and HEAD the same while the index records the new pin, so it prints nothing. After each,
    `git submodule update -- vendor/grado-factorio-tools` brings it there. A checkout made while
    vendor/ holds a pin older than this script, whose copy has none to run, and a clone with no
    pwsh: the wrapper below skips both, saying nothing. A change to the submodule's own submodules,
    which it never updates. And whether the new pin's scripts work: it moves the checkout, and the
    sibling's gates judge the rest.

.PARAMETER Hook
    The hook that runs it: post-checkout, post-merge or post-rewrite.

.PARAMETER HookArgs
    The arguments git gave the hook, passed through unchanged.

.PARAMETER Path
    The submodule's path from the sibling's root. Defaults to vendor/grado-factorio-tools.

.PARAMETER SelfTest
    Build, in a temp directory, a tools repository of four commits and a sibling holding it as a
    submodule, with this script wired into its post-checkout, post-merge and post-rewrite hooks,
    and hold each case above by running git. Needs git, and no game and no network.

.EXAMPLE
    Run by hand from a sibling's root, as post-checkout would be after a switch from the
    previous HEAD:

        pwsh -File vendor/grado-factorio-tools/scripts/follow-pin.ps1 post-checkout HEAD@{1} HEAD 1

.EXAMPLE
    A sibling's .githooks/post-checkout, and the same for post-merge and post-rewrite, each
    committed executable (`git add --chmod=+x .githooks/post-checkout`): off Windows, git ignores a
    hook that is not.

        #!/bin/sh
        # Brings vendor/grado-factorio-tools to the pin the new HEAD records.
        f=vendor/grado-factorio-tools/scripts/follow-pin.ps1
        [ -f "$f" ] && command -v pwsh >/dev/null && pwsh -NoProfile -File "$f" post-checkout "$@"
        exit 0
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [Parameter(Position = 0)] [string] $Hook,
    [Parameter(Position = 1, ValueFromRemainingArguments)] [string[]] $HookArgs = @(),
    [string] $Path = 'vendor/grado-factorio-tools',
    [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The commit $Commit's tree records for $Sub, or '' where it records none.
function Get-Pin {
    param([string] $Commit, [string] $Sub)
    $entry = git ls-tree $Commit -- $Sub 2>$null
    if ($LASTEXITCODE -or "$entry" -notmatch '^160000 commit ([0-9a-f]+)\t') { return '' }
    $Matches[1]
}

# What the hook does: see the header. Returns the line it prints, or $null for none.
function Invoke-FollowPin {
    param([string] $Hook, [string[]] $HookArgs, [string] $Sub, [AllowEmptyString()] [string] $Rewritten = '')
    $old, $new = switch ($Hook) {
        'post-checkout' { if (@($HookArgs).Count -ge 3 -and $HookArgs[2] -eq '1') { $HookArgs[0], $HookArgs[1] } }
        'post-merge' { 'ORIG_HEAD', 'HEAD' }
        # The rebase checked out the commit it replays onto, which post-checkout followed: the
        # first rewritten commit's parent.
        'post-rewrite' {
            $first = [regex]::Match($Rewritten, '^[0-9a-f]+ ([0-9a-f]+)', 'Multiline')
            if (@($HookArgs).Count -ge 1 -and $HookArgs[0] -eq 'rebase' -and $first.Success) { "$($first.Groups[1].Value)^", 'HEAD' }
        }
        default { throw "$Hook is not a hook this serves: give post-checkout, post-merge or post-rewrite." }
    }
    $was = Get-Pin $old $Sub; $now = Get-Pin $new $Sub
    if (-not $was -or -not $now -or $was -eq $now) { return $null }
    $short = { param($c) $c.Substring(0, 7) }
    $run = "git submodule update -- $Sub"
    $records = "the new HEAD records $(& $short $now)"
    if (-not (Test-Path -LiteralPath (Join-Path $Sub '.git'))) { return "${Hook}: $Sub is not initialised, so it was left; $records. To bring it there: git submodule update --init -- $Sub" }
    $at = git -C $Sub rev-parse HEAD 2>$null
    if ($LASTEXITCODE) { return "${Hook}: git could not read $Sub's HEAD, so it was left; $records. To bring it there: $run" }
    $dirty = git -C $Sub status --porcelain 2>$null
    if ($LASTEXITCODE -or $dirty) { return "${Hook}: $Sub has uncommitted changes, so it was left at $(& $short $at); $records. Once they are dealt with: $run" }
    if ($at -ne $was) { return "${Hook}: $Sub is at $(& $short $at), not the $(& $short $was) the old HEAD records, so it was left; $records. To bring it there: $run" }
    $said = git submodule update --quiet -- $Sub 2>&1
    if ($LASTEXITCODE) { return "${Hook}: git submodule update failed, so $Sub was left at $(& $short $at); $records. $(($said | Select-Object -Last 1) -replace '\s+$'). To retry: $run" }
    "${Hook}: $Sub $(& $short $was) -> $(& $short $now)"
}

if ($SelfTest) {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "follow-pin-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    $tools = Join-Path $temp 'tools'; $sib = Join-Path $temp 'sibling'; $noHooks = Join-Path $temp 'no-hooks'
    $sub = 'vendor/grado-factorio-tools'; $subDir = Join-Path $sib $sub
    $failures = 0; $n = 0; $codes = [Collections.Generic.List[string]]::new()
    $check = {
        param([string] $Name, [bool] $Ok, [string] $Said)
        $script:n++
        Write-Host ("self-test {0}: {1} -- {2}" -f $script:n, $Name, $(if ($Ok) { 'ok' } else { 'FAILED' }))
        if (-not $Ok) { $script:failures++; if ($Said) { Write-Host "    $($Said.Trim() -replace "`n", "`n    ")" } }
    }
    # git in the sibling, its output and its hooks' together; each exit code is kept, as a hook's
    # exit status would become a checkout's.
    $git = { $said = & git -C $sib @args 2>&1 | Out-String; $codes.Add("git $($args -join ' '): $LASTEXITCODE"); $said }
    # A step that sets up a case and is not one: git with no hooks, so no pwsh is started for it
    # (#296), then the submodule brought to the pin the new HEAD records, where the hook would have
    # left it or the step after it put it.
    $setup = {
        $null = & git -C $sib -c "core.hooksPath=$noHooks" @args 2>&1; $codes.Add("setup git $($args -join ' '): $LASTEXITCODE")
        git -C $sib submodule --quiet update
    }
    # This script run as a hook would be, from the sibling's root, with $stdin on its stdin.
    $direct = {
        param([string] $stdin, [string[]] $a)
        Push-Location -LiteralPath $sib
        try { $said = $stdin | & pwsh -NoProfile -File $PSCommandPath @a 2>&1 | Out-String; $codes.Add("direct $($a -join ' '): $LASTEXITCODE"); $said }
        finally { Pop-Location }
    }
    $at = { (git -C $subDir rev-parse HEAD) }
    $short = { param($c) $c.Substring(0, 7) }
    $line = { param([string] $hook, $from, $to) "${hook}: $sub $(& $short $from) -> $(& $short $to)" }
    # The fixture's file:// submodule fetches need this, as git 2.38.1 and later refuse them.
    $was = $env:GIT_CONFIG_COUNT
    $env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'protocol.file.allow'; $env:GIT_CONFIG_VALUE_0 = 'always'
    try {
        New-Item -ItemType Directory -Path $noHooks -Force | Out-Null
        foreach ($r in $tools, $sib) {
            New-Item -ItemType Directory -Path $r -Force | Out-Null
            git -C $r init --quiet -b main; if ($LASTEXITCODE) { throw 'git init failed; the self-test needs git.' }
            git -C $r config user.email self-test@example.com; git -C $r config user.name self-test
            git -C $r config core.autocrlf false
        }
        $pins = foreach ($p in 'a', 'b', 'c') {
            Set-Content -LiteralPath (Join-Path $tools 'f.txt') -Value $p
            git -C $tools add -A; git -C $tools commit --quiet -m $p; git -C $tools rev-parse HEAD
        }
        $A, $B, $C = $pins
        git -C $sib submodule --quiet add $tools $sub 2>&1 | Out-Null
        git -C $subDir -c advice.detachedHead=false checkout --quiet $A
        git -C $sib add -A; git -C $sib commit --quiet -m 'tools at a'
        $hooks = Join-Path $sib 'hooks'
        New-Item -ItemType Directory -Path $hooks | Out-Null
        foreach ($h in 'post-checkout', 'post-merge', 'post-rewrite') {
            [IO.File]::WriteAllText((Join-Path $hooks $h), "#!/bin/sh`npwsh -NoProfile -File '$($PSCommandPath -replace '\\', '/')' $h `"`$@`"`nexit 0`n")
            # Off Windows, git runs only a hook file that is executable, and ignores the rest.
            if (-not $IsWindows) { chmod +x (Join-Path $hooks $h); if ($LASTEXITCODE) { throw 'chmod failed on a hook.' } }
        }
        Set-Content -LiteralPath (Join-Path $sib '.git/info/exclude') -Value 'hooks/'
        git -C $sib config core.hooksPath hooks
        # The branches: moveB records b; sameA records a, with a commit of its own; topicC, from
        # main, records c.
        & $setup switch --quiet -c moveB
        git -C $subDir checkout --quiet $B; git -C $sib add $sub; git -C $sib commit --quiet -m 'tools at b'
        & $setup switch --quiet -c sameA main
        Set-Content -LiteralPath (Join-Path $sib 'x.txt') -Value x; git -C $sib add x.txt; git -C $sib commit --quiet -m 'x'
        & $setup switch --quiet main

        $said = & $git switch --quiet moveB
        & $check 'a branch switch that changes the pin updates it and prints the line' ($said.Trim() -ceq (& $line 'post-checkout' $A $B) -and (& $at) -eq $B) $said
        & $setup switch --quiet main
        $said = & $git switch --quiet sameA
        & $check 'a branch switch that does not change the pin prints nothing' ($said -ceq '' -and (& $at) -eq $A) $said
        & $setup switch --quiet main
        $mainSha = git -C $sib rev-parse main; $moveSha = git -C $sib rev-parse moveB
        # An amend whose rewritten commit's parent records b, as a rebase's would be read; a
        # clone's first checkout, whose old HEAD is all zeros and records no pin; and a switch to a
        # commit whose tree, git's empty tree, records none.
        $afterB = git -C $sib commit-tree "moveB^{tree}" -p $moveSha -m 'after b'
        $noPin = git -C $sib commit-tree 4b825dc642cb6eb9a060e54bf8d69288fbee4904 -m 'no submodule'
        $said = (& $direct '' 'post-checkout', $mainSha, $moveSha, '0') + (& $direct "$afterB $afterB" 'post-rewrite', 'amend') +
            (& $direct '' 'post-checkout', ('0' * 40), $moveSha, '1') + (& $direct '' 'post-checkout', $mainSha, $noPin, '1')
        & $check "a file checkout, an amend, a first checkout and a commit with no pin do nothing" (-not $said.Trim() -and (& $at) -eq $A) $said
        # Run with --git-dir, git hands the hooks GIT_DIR, which must not reach the submodule's git.
        $said = & $git --git-dir="$sib/.git" --work-tree=$sib switch --quiet moveB
        & $check 'a switch with GIT_DIR set updates it too' ($said.Trim() -ceq (& $line 'post-checkout' $A $B) -and (& $at) -eq $B) $said
        & $setup switch --quiet main
        $said = & $git merge --quiet --ff-only moveB
        & $check 'a merge that moves the pin updates it, from ORIG_HEAD' ($said -match [regex]::Escape((& $line 'post-merge' $A $B)) -and (& $at) -eq $B) $said
        git -C $sib reset --quiet --hard $mainSha; git -C $sib submodule --quiet update

        Add-Content -LiteralPath (Join-Path $subDir 'f.txt') -Value 'edited'
        $said = & $git switch --quiet moveB
        & $check 'a submodule with uncommitted changes is left, with its line' ($said -match "post-checkout: $sub has uncommitted changes, so it was left at $(& $short $A); the new HEAD records $(& $short $B)\. Once they are dealt with: git submodule update -- $sub" -and (& $at) -eq $A) $said
        git -C $subDir checkout --quiet -- .; & $setup switch --quiet main

        git -C $subDir checkout --quiet $C
        $said = & $git switch --quiet moveB
        & $check 'a submodule off the old pin is left, with its line' ($said -match "post-checkout: $sub is at $(& $short $C), not the $(& $short $A) the old HEAD records, so it was left; the new HEAD records $(& $short $B)\." -and (& $at) -eq $C) $said
        & $setup switch --quiet main

        git -C $sib submodule --quiet deinit --force $sub
        $said = & $git switch --quiet moveB
        & $check 'a submodule not initialised is left, with its line' ($said -match "post-checkout: $sub is not initialised, so it was left; the new HEAD records $(& $short $B)\. To bring it there: git submodule update --init -- $sub") $said
        & $setup switch --quiet main; git -C $sib submodule --quiet update --init

        # A pin the clone does not hold: d is committed in tools after the clone, and a pin that
        # is nowhere, which no fetch can bring.
        Set-Content -LiteralPath (Join-Path $tools 'f.txt') -Value 'd'; git -C $tools commit --quiet -am d; $D = git -C $tools rev-parse HEAD
        $nowhere = 'f' * 40
        foreach ($branch in @{ Name = 'moveD'; Pin = $D }, @{ Name = 'moveNowhere'; Pin = $nowhere }) {
            & $setup switch --quiet --no-guess -c $branch.Name main
            git -C $sib update-index --cacheinfo "160000,$($branch.Pin),$sub"; git -C $sib commit --quiet -m $branch.Name
            & $setup switch --quiet main
        }
        $said = & $git switch --quiet moveD
        & $check 'a pin the clone does not hold is fetched' ($said -match [regex]::Escape((& $line 'post-checkout' $A $D)) -and (& $at) -eq $D) $said
        & $setup switch --quiet main
        $said = & $git switch --quiet moveNowhere
        & $check 'a pin that cannot be fetched is left, with the command to retry' ($said -match "post-checkout: git submodule update failed, so $sub was left at $(& $short $A); the new HEAD records ffffff\w*\..*To retry: git submodule update -- $sub" -and (& $at) -eq $A) $said
        & $setup switch --quiet main

        # A rebase of a branch that moves the pin itself onto one that moved it: post-checkout
        # takes the submodule to moveB's pin, and post-rewrite to the branch's.
        & $setup switch --quiet -c topicC main
        git -C $subDir checkout --quiet $C; git -C $sib add $sub; git -C $sib commit --quiet -m 'tools at c'
        $said = & $git rebase --quiet -X theirs moveB
        & $check "a rebase onto a moved pin, of a branch that moves it, ends at the branch's pin" (
            $said -match [regex]::Escape((& $line 'post-rewrite' $B $C)) -and (& $at) -eq $C -and -not (git -C $sib status --porcelain)) $said

        $said = & $direct '' 'pre-commit'
        & $check 'a hook it does not serve prints a line' ($said -match 'pre-commit is not a hook this serves') $said
        $bad = @($codes | Where-Object { $_ -notmatch ': 0$' })
        & $check "every case exits 0, and so every git command the hooks ran in ($($codes.Count) runs)" (-not $bad) ($bad -join "`n")
    }
    finally {
        $env:GIT_CONFIG_COUNT = $was; Remove-Item Env:GIT_CONFIG_KEY_0, Env:GIT_CONFIG_VALUE_0 -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $n case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $n cases."
    exit 0
}

# A hook may run with git's own GIT_DIR and GIT_INDEX_FILE set, which a git -C into the submodule
# would take for its own; the sibling's root is the cwd, so git finds it without them.
foreach ($v in 'GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE') { Remove-Item -LiteralPath "Env:$v" -ErrorAction SilentlyContinue }
try {
    # post-rewrite is given each rewritten commit on stdin, as `<old> <new>`.
    $rewritten = if ($Hook -eq 'post-rewrite') { [Console]::In.ReadToEnd() } else { '' }
    $line = Invoke-FollowPin -Hook $Hook -HookArgs $HookArgs -Sub $Path -Rewritten $rewritten
    if ($line) { Write-Host $line }
}
catch { Write-Host "${Hook}: $($_.Exception.Message) $Path was not checked; to bring it to the pin HEAD records: git submodule update -- $Path" }
exit 0
