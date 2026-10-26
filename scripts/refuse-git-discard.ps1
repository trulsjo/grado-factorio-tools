<#
.SYNOPSIS
    A hook for agent sessions: refuses a git command that would discard, overwrite or hide
    uncommitted work in the working tree it runs against. Exit 2 refuses the command before it
    runs and says what to do instead; exit 0 lets it run.

.DESCRIPTION
    WHY (grado-factorio-tools#224, from grado-factorio-modpack#366). On 2026-10-23 a reviewer
    subagent of a session ran `git checkout --detach` in that session's working tree and put the
    branch back. The tree was clean, so nothing was lost, by the reviewer's own report. On a tree
    with uncommitted work a checkout carries or refuses the changes, and a reset discards them.
    The risk is the same in every repository a session works in, so the hook lives here. Truls
    ruled what it refuses on 2026-10-25, in grado-factorio-modpack#366's triage.

    HOW A CONSUMER WIRES IT. This repository cannot: a session reads its hooks from the
    consumer's own tracked settings. In .claude/settings.json, a PreToolUse hook on the two shell
    tools, matcher `Bash|PowerShell`, whose command is the first example below. The session hands
    the hook the tool call as JSON on stdin: this reads `tool_input.command` and `cwd`. The `case`
    starts this script only when that JSON names one of the six subcommands, since starting
    PowerShell takes a second and the hook runs before every shell command. Where the script is
    not there, as in a clone whose submodule was never fetched, the wired command lets the shell
    command run and prints JSON that tells the agent it was not checked, as
    refuse-cd-into-mod-cache.ps1's wiring does; -SelfTest runs both branches of the wiring.

    WHAT IT REFUSES. A tree is dirty when a tracked file has changed, staged or not; an untracked
    file does not count, since a checkout refuses to overwrite one and a reset keeps it. On a dirty
    tree: `git checkout` with any argument but `-b`, so `git checkout <rev>`, `git checkout --
    <path>` and `git checkout --detach`; `git switch` with any argument but `-c` or `--create`;
    `git reset --hard`, `--merge` or `--keep`; `git restore` without `--staged` or `-S`, or with
    `--worktree` or `-W`; and `git stash`, bare or with `push`, `save` or an option, which hides
    the work. A redirection, as `2>&1` or `> out.log`, is not read as an argument, so
    `git stash 2>&1` is a bare stash. On any tree with an untracked file: `git clean`, whatever
    its options, a dry run included, since those files are what it deletes; with `-x` or `-X`,
    alone or among other short options as in `-fdx`, on a tree with an ignored file too, which
    those delete (PR #252's review, 2026-10-26). It binds every caller, the main session and a
    subagent alike (Truls's ruling): the main session commits before it switches branches.

    WHAT IT LETS THROUGH. On a dirty tree: `git switch -c` and `git checkout -b`, which carry the
    work to a new branch; `git reset --soft` and a mixed `git reset`; `git restore --staged`;
    `git stash list`, `show`, `pop`, `apply` and the rest that hide nothing; and every other git
    command. Each of those forms on a clean tree, and `git clean` where nothing is untracked.

    WHERE IT READS THE TREE. In the repository the command would run in: the call's `cwd`, moved
    by a `cd`, `Set-Location` or `pushd` earlier in the command to a literal path, and by each
    `git -C <path>` the git call names. The tree is read as it stands before the command runs,
    so `git commit -am x && git switch main` on a dirty tree is refused: commit in one call and
    switch in the next. A git call in a compound, after `&&`, `||`, `;`, `|`, `&` or a newline,
    or inside parentheses or braces, is found, and so is one after the assignments that lead a
    command, as `MSYS_NO_PATHCONV=1 git ...`; a `x=y` word later in the call is an argument.

    IT FAILS OPEN, LOUDLY (Truls's ruling). Where it cannot tell, it lets the command run and
    prints, on stdout, JSON whose additionalContext tells the agent the command was NOT checked:
    a call that holds no command, a git call it would judge outside a repository or where git
    cannot read the tree, one that names its repository with `--git-dir` or `--work-tree`, and a
    command whose quotes it cannot pair. A command with no git call it judges is let through in
    silence.

    WHAT IT CANNOT SEE. A git call it does not read as one: through an alias, git's own or the
    shell's, through a variable, or from a script or program that runs git itself. A directory
    reached through a variable, a substitution or a wildcard, and a `cd` in a subshell, read as
    if it lasted. Short options run together, as `git restore -SW`, and an option written
    `-bnew` or `--create=x`. Both shells' quoting is read roughly: a word in double or single
    quotes is one word with its quotes taken off, a backslash or backtick escapes the character
    after it, and nothing is expanded. And whether a session hands a subagent's calls to the hook
    at all, which is not measured.

    TO CHECK IT, run the second example below.

.PARAMETER SelfTest
    Build a scratch repository with a second branch, a clean one beside it and a directory
    outside both, and prove: each refused form refused on a dirty tree and let through on a clean
    one; a staged-only change counted as dirty; each let-through form let through on a dirty
    tree; `git clean` refused with an untracked file and let through without, and with `-x` or
    `-X` refused with an ignored file alone; a stash with a redirection refused; a form inside a
    compound found; `git -C` and a `cd` moving where the tree is read; a call that holds no
    command, one outside a repository, one with `--git-dir` and one with an unpaired quote let
    through with the NOT-checked message. Then the wired command, run through sh, refuses with
    exit 2 and a reason, and where the project holds no hook script exits 0 and prints JSON that
    tells the agent. Needs git, and sh: the one on the path, or the one Git for Windows ships.

.EXAMPLE
    The wired command: the PreToolUse hook a consumer puts in its .claude/settings.json.

        i=$(cat); case $i in *checkout*|*switch*|*reset*|*restore*|*stash*|*clean*) h="$CLAUDE_PROJECT_DIR/vendor/grado-factorio-tools/scripts/refuse-git-discard.ps1"; if [ -f "$h" ]; then printf '%s' "$i" | pwsh -NoProfile -File "$h"; else printf '%s' '{"systemMessage":"refuse-git-discard: the hook script was not found, so this command was NOT checked. git submodule update --init fetches it.","hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"refuse-git-discard: the hook script was not found, so this command was NOT checked. git submodule update --init fetches it."}}'; fi;; esac

.EXAMPLE
    To check it, in a repository with an uncommitted edit to a tracked file. The first is refused
    with exit 2, the second passes with exit 0:

        '{"cwd":".","tool_input":{"command":"git status && git reset --hard"}}' | pwsh -NoProfile -File scripts/refuse-git-discard.ps1; $LASTEXITCODE
        '{"cwd":".","tool_input":{"command":"git switch -c keep-this"}}' | pwsh -NoProfile -File scripts/refuse-git-discard.ps1; $LASTEXITCODE
#>

#Requires -Version 7
[CmdletBinding()]
param([switch] $SelfTest)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The words of $Command, quotes taken off, with each operator that ends a command as a word of its
# own, and $null where a quote is left open: what is left over is the open quote.
function Split-ShellCommand {
    param([AllowEmptyString()] [string] $Command)
    $pattern = '(?<op>&&|\|\||[;|&\n(){}])|(?<word>(?:[^\s;|&(){}"''\\`]|[\\`].|"(?:[^"\\`]|[\\`].)*"|''[^'']*'')+)|[ \t\r]+'
    $matched = [regex]::Matches($Command, $pattern)
    if (($matched | Measure-Object Length -Sum).Sum -ne $Command.Length) { return $null }
    , @(foreach ($m in $matched) {
            if ($m.Groups['op'].Success) { @{ Op = $m.Value } }
            elseif ($m.Groups['word'].Success) { @{ Word = $m.Value -replace '"|''', '' } }
        })
}

# $Words less each redirection: a word that is one, as `2>` or `>`, with the word after it, and one
# with its target joined on, as `>/dev/null`. `2>&1` reaches here as `2>`, its `&` an operator.
function Remove-Redirection {
    param([string[]] $Words)
    for ($k = 0; $k -lt $Words.Count; $k++) {
        if ($Words[$k] -match '^[\d*]*[<>]{1,2}$') { $k++; continue }
        if ($Words[$k] -match '^[\d*]*[<>]{1,2}') { continue }
        $Words[$k]
    }
}

# What a git call's subcommand and arguments need of the tree to be refused: 'dirty', 'untracked',
# 'ignored' for a clean that deletes ignored files too, or nothing, which lets it through.
function Get-GitRisk {
    param([string] $Subcommand, [string[]] $Rest)
    $Rest = @(Remove-Redirection $Rest)
    $has = { param([string[]] $names) [bool] ($Rest | Where-Object { $_ -cin $names }) }
    switch -CaseSensitive ($Subcommand) {
        'checkout' { if ($Rest -and -not (& $has '-b')) { 'dirty' } }
        'switch' { if ($Rest -and -not (& $has '-c', '--create')) { 'dirty' } }
        'reset' { if (& $has '--hard', '--merge', '--keep') { 'dirty' } }
        'restore' { if (-not (& $has '--staged', '-S') -or (& $has '--worktree', '-W')) { 'dirty' } }
        'stash' { if (-not $Rest -or $Rest[0] -cin 'push', 'save' -or $Rest[0] -like '-*') { 'dirty' } }
        # -x or -X, alone or among other short options, as -fdx: ignored files are deleted too.
        'clean' { if ($Rest -cmatch '^-[^-]*[xX]') { 'ignored' } else { 'untracked' } }
    }
}

# The tree at $Dir: its top, whether a tracked file has changed, whether a file is untracked, and,
# with -Ignored, whether a file is ignored; $null where git cannot say, as outside a repository.
function Get-TreeState {
    param([string] $Dir, [switch] $Ignored)
    $top = git -C $Dir rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE) { return $null }
    $lines = @(git -C $Dir status --porcelain=v1 --untracked-files=normal @(if ($Ignored) { '--ignored' }) 2>$null)
    if ($LASTEXITCODE) { return $null }
    @{ Top = $top; Dirty = [bool] ($lines | Where-Object { $_ -notlike '`?`? *' -and $_ -notlike '!! *' })
        Untracked = [bool] ($lines | Where-Object { $_ -like '`?`? *' }); Ignored = [bool] ($lines | Where-Object { $_ -like '!! *' }) }
}

# What to do with $Command run from $Cwd: @{ Refuse = <reason> }, @{ Unchecked = <why> }, or $null
# to let it through in silence.
function Get-GitRefusal {
    param([AllowEmptyString()] [string] $Command, [string] $Cwd)
    if (-not $Command.Trim()) { return @{ Unchecked = 'the tool call held no command' } }
    $words = Split-ShellCommand $Command
    if ($null -eq $words) {
        if ($Command -match '\bgit\b') { return @{ Unchecked = 'its quotes could not be paired, so its git calls could not be read' } }
        return $null
    }
    $dir = $Cwd
    $segment = [Collections.Generic.List[string]]::new()
    foreach ($w in @($words) + @(@{ Op = 'end' })) {
        if (-not $w.ContainsKey('Op')) { $segment.Add($w.Word); continue }
        # The assignments that lead a command, as `MSYS_NO_PATHCONV=1 git ...`; not a later one.
        $lead = 0
        while ($lead -lt $segment.Count -and $segment[$lead] -match '^\w+=') { $lead++ }
        $s = @($segment | Select-Object -Skip $lead)
        $segment.Clear()
        if (-not $s) { continue }
        # A move to a literal directory lasts for what follows it.
        if ($s[0] -in 'cd', 'chdir', 'pushd', 'sl', 'Set-Location', 'Push-Location') {
            $target = @($s | Select-Object -Skip 1 | Where-Object { $_ -notlike '-*' })[0]
            if ($target -and $target -notmatch '[$*?%]') { $dir = [IO.Path]::GetFullPath($target, $dir) }
            continue
        }
        if ($s[0] -notmatch '^(.*[\\/])?git(\.exe)?$') { continue }
        $at = $dir
        $i = 1
        while ($i -lt $s.Count -and $s[$i] -like '-*') {
            if ($s[$i] -match '^--(git-dir|work-tree)') { return @{ Unchecked = "``git $($s[$i])`` names its repository, and this reads only the directory a git call runs in" } }
            if ($s[$i] -ceq '-C') { $at = [IO.Path]::GetFullPath($s[$i + 1], $at); $i += 2 }
            elseif ($s[$i] -ceq '-c') { $i += 2 }
            else { $i++ }
        }
        if ($i -ge $s.Count) { continue }
        $risk = Get-GitRisk -Subcommand $s[$i] -Rest @($s | Select-Object -Skip ($i + 1))
        if (-not $risk) { continue }
        $call = "git $(@($s | Select-Object -Skip $i) -join ' ')"
        $tree = Get-TreeState $at -Ignored:($risk -eq 'ignored')
        if (-not $tree) { return @{ Unchecked = "git could not read a working tree at $at for ``$call``" } }
        if ($risk -eq 'ignored' -and ($tree.Untracked -or $tree.Ignored)) {
            return @{ Refuse = "``$call`` would delete the untracked and ignored files in $($tree.Top), which are what it deletes." }
        }
        if ($risk -eq 'dirty' -and $tree.Dirty) {
            return @{ Refuse = "``$call`` would discard, overwrite or hide uncommitted work in $($tree.Top): a tracked file there has changed, staged or not." }
        }
        if ($risk -eq 'untracked' -and $tree.Untracked) {
            return @{ Refuse = "``$call`` would delete the untracked files in $($tree.Top), which are what it deletes." }
        }
    }
    $null
}

# The JSON that tells the agent a command was let through unchecked, and why.
function Format-Unchecked {
    param([string] $Why)
    $text = "refuse-git-discard: $Why, so this command was NOT checked for discarding uncommitted work."
    @{ systemMessage = $text; hookSpecificOutput = @{ hookEventName = 'PreToolUse'; additionalContext = $text } } | ConvertTo-Json -Compress
}

if ($SelfTest) {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "refuse-git-discard-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    $repo = Join-Path $temp 'repo'; $clean = Join-Path $temp 'clean'; $outside = Join-Path $temp 'outside'
    New-Item -ItemType Directory -Path $repo, $clean, $outside -Force | Out-Null
    $failures = 0; $n = 0
    $check = {
        param([string] $Name, [bool] $Ok, [string] $Said)
        $script:n++
        Write-Host ("self-test {0}: {1} -- {2}" -f $script:n, $Name, $(if ($Ok) { 'ok' } else { 'FAILED' }))
        if (-not $Ok) { $script:failures++; if ($Said) { Write-Host "    $Said" } }
    }
    $verdict = { param($r) if (-not $r) { 'through' } elseif ($r.ContainsKey('Refuse')) { 'refused' } else { 'unchecked' } }
    try {
        foreach ($r in $repo, $clean) {
            git -C $r init --quiet; if ($LASTEXITCODE) { throw 'git init failed; the self-test needs git.' }
            git -C $r config user.email self-test@example.com; git -C $r config user.name self-test
            Set-Content -LiteralPath (Join-Path $r 'a.txt') -Value 'one'
            New-Item -ItemType Directory -Path (Join-Path $r 'sub') | Out-Null
            Set-Content -LiteralPath (Join-Path $r 'sub/b.txt') -Value 'one'
            Set-Content -LiteralPath (Join-Path $r '.gitignore') -Value '*.log'
            git -C $r add -A; git -C $r commit --quiet -m one; git -C $r branch other
        }
        $dirty = { Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'two' }
        $tidy = { git -C $repo checkout --quiet -- a.txt }
        $refused = 'git checkout other', 'git checkout -- a.txt', 'git checkout --detach', 'git switch other',
            'git reset --hard', 'git reset --merge', 'git reset --keep', 'git restore a.txt',
            'git restore --staged --worktree a.txt', 'git stash', 'git stash push -m keep', 'git stash -u',
            # A redirection is not the stash's argument; an assignment after `git` does not lead it.
            'git stash 2>&1', 'git stash > stash.log', 'git stash 2>/dev/null', 'git stash push -m note=wip'
        $through = 'git switch -c keep', 'git checkout -b keep', 'git reset --soft HEAD', 'git reset', 'git reset HEAD a.txt',
            'git restore --staged a.txt', 'git restore -S a.txt', 'git stash list', 'git stash list 2>&1', 'git status',
            'git checkout', 'git clean -fd'
        foreach ($c in $refused) {
            & $dirty; $onDirty = & $verdict (Get-GitRefusal $c $repo)
            & $tidy; $onClean = & $verdict (Get-GitRefusal $c $repo)
            & $check "``$c``: refused on a dirty tree, let through on a clean one" ($onDirty -eq 'refused' -and $onClean -eq 'through') "dirty: $onDirty, clean: $onClean"
        }
        & $dirty
        foreach ($c in $through) {
            $got = & $verdict (Get-GitRefusal $c $repo)
            & $check "``$c``: let through on a dirty tree" ($got -eq 'through') $got
        }
        git -C $repo add a.txt; & $tidy
        $staged = & $verdict (Get-GitRefusal 'git switch other' $repo)
        git -C $repo reset --quiet; & $tidy
        & $check 'a change that is only staged makes the tree dirty' ($staged -eq 'refused') $staged
        Set-Content -LiteralPath (Join-Path $repo 'sub/new.txt') -Value 'new'
        $withNew = & $verdict (Get-GitRefusal 'git clean -fd' $repo)
        $dryRun = & $verdict (Get-GitRefusal 'git clean -n' $repo)
        $notDirty = & $verdict (Get-GitRefusal 'git reset --hard' $repo)
        Remove-Item -LiteralPath (Join-Path $repo 'sub/new.txt')
        $without = & $verdict (Get-GitRefusal 'git clean -fd' $repo)
        & $check '`git clean` refused with an untracked file, a dry run too, and let through without; an untracked file alone does not make the tree dirty' ($withNew -eq 'refused' -and $dryRun -eq 'refused' -and $without -eq 'through' -and $notDirty -eq 'through') "with: $withNew, dry run: $dryRun, without: $without, reset --hard: $notDirty"
        # An ignored file only: what -x and -X delete, and a plain clean keeps.
        Set-Content -LiteralPath (Join-Path $repo 'sub/kept.log') -Value 'kept'
        $fdx = & $verdict (Get-GitRefusal 'git clean -fdx' $repo)
        $bigX = & $verdict (Get-GitRefusal 'git clean -f -X' $repo)
        $plain = & $verdict (Get-GitRefusal 'git clean -fd' $repo)
        Remove-Item -LiteralPath (Join-Path $repo 'sub/kept.log')
        $noneIgnored = & $verdict (Get-GitRefusal 'git clean -fdx' $repo)
        & $check '`git clean -x` and `-X` refused with an ignored file, a plain clean not; `-x` let through with nothing ignored or untracked' ($fdx -eq 'refused' -and $bigX -eq 'refused' -and $plain -eq 'through' -and $noneIgnored -eq 'through') "-fdx: $fdx, -f -X: $bigX, -fd: $plain, -fdx with none: $noneIgnored"
        & $dirty
        $compound = 'git status && git reset --hard', 'git log -1; git stash', "echo x |`ngit checkout other", '(git switch other)',
            'MSYS_NO_PATHCONV=1 git checkout other', '& git reset --hard', 'git -c core.quotePath=false checkout other'
        foreach ($c in $compound) {
            $got = & $verdict (Get-GitRefusal $c $repo)
            & $check "a form in ``$($c -replace "`n", '\n')`` is found" ($got -eq 'refused') $got
        }
        $quoted = & $verdict (Get-GitRefusal 'git commit -m "never git reset --hard"; echo git checkout other' $repo)
        & $check 'a form inside quotes, or not where a command stands, is not a git call' ($quoted -eq 'through') $quoted
        $cases = [ordered]@{
            "``git -C`` to the dirty tree, from outside any repository" = @("git -C `"$repo`" reset --hard", $outside, 'refused')
            "``git -C`` to a clean tree, from the dirty one" = @("git -C `"$clean`" reset --hard", $repo, 'through')
            "``git -C`` relative, from the dirty tree's parent" = @('git -C repo checkout other', $temp, 'refused')
            'a `cd` into the dirty tree earlier in the command' = @("cd `"$repo`" && git switch other", $outside, 'refused')
            'a `cd` out of the dirty tree to a clean one' = @('cd ../clean; git switch other', $repo, 'through')
            'a git call outside any repository' = @('git reset --hard', $outside, 'unchecked')
            'a git call naming --git-dir' = @("git --git-dir=$repo/.git reset --hard", $repo, 'unchecked')
            'an unpaired quote around a git call' = @('git checkout "other', $repo, 'unchecked')
            'an unpaired quote with no git in it' = @('echo "x', $repo, 'through')
            'a command with no git call' = @('ls -la', $repo, 'through')
        }
        foreach ($name in $cases.Keys) {
            $c = $cases[$name]; $got = Get-GitRefusal $c[0] $c[1]
            $said = & $verdict $got
            & $check "${name}: $($c[2])" ($said -eq $c[2]) "$said $(if ($got) { $got.Values })"
        }
        # The script itself, with the call on stdin: a refusal is exit 2 and a reason on stderr; a
        # call it cannot check is exit 0 and the JSON on stdout; one it lets through, exit 0 and
        # nothing.
        $run = {
            param($json)
            $out = $json | & pwsh -NoProfile -File $PSCommandPath 2>&1 | Out-String
            @{ Code = $LASTEXITCODE; Text = $out }
        }
        $no = & $run '{"cwd":"."}'
        $outRun = & $run (@{ cwd = $outside; tool_input = @{ command = 'git stash' } } | ConvertTo-Json -Compress)
        $toldNo = try { ($no.Text | ConvertFrom-Json).hookSpecificOutput.additionalContext -match 'NOT checked' } catch { $false }
        $toldOut = try { ($outRun.Text | ConvertFrom-Json).hookSpecificOutput.additionalContext -match 'NOT checked' } catch { $false }
        & $check 'run on a call that holds no command, and on one outside a repository: exit 0 and the NOT-checked JSON' ($no.Code -eq 0 -and $toldNo -and $outRun.Code -eq 0 -and $toldOut) "$($no.Code) $($no.Text) | $($outRun.Code) $($outRun.Text)"
        # The wiring as the session runs it, through sh, for a project that holds this script and
        # for one that does not.
        # Read from the header's first example, so the command shown is the command run.
        $wired = [regex]::Match((Get-Content -LiteralPath $PSCommandPath -Raw), 'i=\$\(cat\).*?esac').Value.Replace('/vendor/grado-factorio-tools/scripts/', '/scripts/')
        $sh = (Get-Command sh -ErrorAction SilentlyContinue)?.Source ?? (Join-Path (git --exec-path) '../../../usr/bin/sh.exe')
        $env:PATH = "$(Split-Path $sh)$([IO.Path]::PathSeparator)$env:PATH"
        $wire = {
            param($project, $command)
            $env:CLAUDE_PROJECT_DIR = $project
            $text = (@{ cwd = $repo; tool_input = @{ command = $command } } | ConvertTo-Json -Compress) | & $sh -c $wired 2>&1 | Out-String
            @{ Code = $LASTEXITCODE; Text = $text }
        }
        $tools = Split-Path $PSScriptRoot -Parent
        $wRefused = & $wire $tools 'git switch other'
        $wPlain = & $wire $tools 'git status'
        $wAbsent = & $wire $outside 'git switch other'
        $toldAbsent = try { ($wAbsent.Text | ConvertFrom-Json).hookSpecificOutput.hookEventName -ceq 'PreToolUse' -and ($wAbsent.Text | ConvertFrom-Json).hookSpecificOutput.additionalContext } catch { $false }
        # The advice leads with git show after committing, and names no git worktree, which a hook
        # on the development machine blocks (Truls, 2026-10-26, on grado-factorio-tools#224).
        $advice = $wRefused.Text -match 'Commit the work first\. To read another revision without leaving this one: git show ' -and $wRefused.Text -notmatch 'worktree add'
        & $check 'the wired command refuses with exit 2, a reason and git show as the advice after committing, passes a plain command, and where the script is not there exits 0 and prints JSON telling the agent' ($wRefused.Code -eq 2 -and $wRefused.Text -match 'Refused' -and $advice -and $wPlain.Code -eq 0 -and -not $wPlain.Text.Trim() -and $wAbsent.Code -eq 0 -and $toldAbsent) "refused: $($wRefused.Code) $($wRefused.Text) | plain: $($wPlain.Code) $($wPlain.Text) | absent: $($wAbsent.Code) $($wAbsent.Text)"
    }
    finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $n case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $n cases."
    exit 0
}

try {
    $call = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $command = if ($call -and $call.PSObject.Properties['tool_input'] -and $call.tool_input.PSObject.Properties['command']) { [string] $call.tool_input.command } else { '' }
    $cwd = if ($call -and $call.PSObject.Properties['cwd'] -and $call.cwd) { [IO.Path]::GetFullPath([string] $call.cwd) } else { (Get-Location).Path }
    $verdict = Get-GitRefusal -Command $command -Cwd $cwd
}
catch { $verdict = @{ Unchecked = "the tool call could not be read ($($_.Exception.Message))" } }
if ($verdict -and $verdict.ContainsKey('Unchecked')) { Format-Unchecked $verdict.Unchecked; exit 0 }
if ($verdict) {
    [Console]::Error.WriteLine(@"
Refused: $($verdict.Refuse)
Commit the work first. To read another revision without leaving this one: git show <rev>:<path>,
git log -p, or git blame <rev> -- <path>.
"@)
    exit 2
}
exit 0
