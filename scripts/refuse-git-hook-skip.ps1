<#
.SYNOPSIS
    A hook for agent sessions: refuses a shell command that runs `git commit` or `git push` with
    the repository's hooks skipped. Exit 2 refuses the command before it runs and says to run it
    without the switch; exit 0 lets it run, and means only that this saw no such switch.

.DESCRIPTION
    WHY (grado-factorio-tools#118). On 2026-10-12 a session here pushed a branch with
    `git push --no-verify`, unasked, and so past .githooks/pre-push, which runs scripts/check.ps1.
    Nothing stopped it. The hooks are slow on a loaded machine, which is what tempts a session,
    and is a reason for a longer timeout and not for skipping them.

    HOW IT IS WIRED. In .claude/settings.json, a PreToolUse hook on the two shell tools, matcher
    `Bash|PowerShell`. This repository's own tracked settings wire it as the first example below
    shows, and a consumer names the script under vendor/grado-factorio-tools/ in its own. The
    session hands the hook the tool call as JSON on stdin: this reads `tool_input.command`. The
    `case` keeps PowerShell from starting before every shell command: whatever is refused names
    one of the two subcommands.

    WHAT IT REFUSES. A command in which the word `git`, alone or at the end of a path, is
    followed by `commit` or `push` as its subcommand, and by --no-verify, or an abbreviation
    of it that git takes; `git commit` with -n, alone or among other short switches, as -an; and
    either subcommand after a -c or --config-env that names core.hooksPath. A command inside
    $( ) or backticks is read as one, where it does not stand inside a quoted string.

    WHAT IT LETS THROUGH. Everything else, and so `git push -n`, which is a dry run and skips
    nothing, and a switch that is only named inside a quoted message.

    WHAT IT CANNOT SEE. A script, an alias or a program that passes the switch itself. A command
    written inside a quoted string for something else to run: sh -c, pwsh -Command, eval,
    Start-Process, or a substitution inside double quotes. A switch written with a backslash in
    it, and a hooks path that comes from a file named with -c include.path. A hook
    manager turned off through the environment, as HUSKY=0 is, and a hooks path set there, with
    GIT_CONFIG_COUNT and its kind. A hooks path set by an earlier `git config`, and a hook file
    that was edited or removed. A clone that never set core.hooksPath, where git runs no hook of
    this repository's and there is nothing to skip. A command whose switch or subcommand comes
    from a variable or a substitution. Any other subcommand that takes --no-verify, as merge, am
    and rebase do. A person's own terminal: this is a session's hook. And whether the settings
    still reach it, unless -SelfTest is run. That reads the wired command and the matcher of
    its entry, and nothing else of the settings: not a handler's `if`, which narrows further,
    and not whether a session reads a matcher as hook-matcher.ps1 does. A wiring with an entry
    for each shell tool fails it, since one entry is read.
    It reads the command as text and does not parse the shell, so it errs towards refusing: a
    `git commit --no-verify` that is only echoed, or stands on a line of a here-document that
    is not inside quotes, is refused too. So is a `git commit` whose message is cut short
    where this reads it: by an apostrophe written as '\'', or by an abbreviation of --message,
    with -n as the next word; and one with -n in a comment after it. Write such a text to a
    file with another tool, and give a message with -F.

    TO CHECK IT, run the second example below.

.PARAMETER SelfTest
    Prove it refuses what it should and lets the rest through, that the wired command
    reaches it, and that the matcher beside that command starts the hook for the Bash tool and
    for the PowerShell tool. The case that runs the command needs sh: the one on the path, or
    the one Git for Windows ships.

.PARAMETER Settings
    With -SelfTest: the .claude/settings.json whose wiring the last two cases read, with that
    file's repository as the project. Defaults to this repository's own. They take the first
    command, of any PreToolUse entry, that names this script: one runs it, and the other reads
    that entry's matcher (grado-factorio-tools#120) and fails, naming the tool and the file,
    unless a session would start the hook for Bash and for PowerShell. An entry with no matcher
    passes: it is started for every tool. How a matcher is read is in hook-matcher.ps1. A
    consumer gives its own file to know its wiring still reaches the hook, from both tools.

.EXAMPLE
    The wired command: the PreToolUse hook in this repository's .claude/settings.json, as HOW IT
    IS WIRED says.

        i=$(cat); case $i in *commit*|*push*) printf '%s' "$i" | pwsh -NoProfile -File "$CLAUDE_PROJECT_DIR/scripts/refuse-git-hook-skip.ps1";; esac

.EXAMPLE
    To check it. The first is refused with exit 2, the second passes with exit 0:

        '{"tool_input":{"command":"git push --no-verify"}}' | pwsh -NoProfile -File scripts/refuse-git-hook-skip.ps1; $LASTEXITCODE
        '{"tool_input":{"command":"git push -n"}}' | pwsh -NoProfile -File scripts/refuse-git-hook-skip.ps1; $LASTEXITCODE
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [switch] $SelfTest,
    [string] $Settings
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-SkipsHooks {
    <#  Whether $Command holds a git commit or git push that is told to skip the hooks.  #>
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Command)

    # Words and the marks that end a command. A quoted stretch stays inside its word, so a
    # message is one word however much it holds; a line continuation is no end of line. A
    # backtick outside quotes ends a command too: sh starts one there.
    $tokens = [regex]::Matches(($Command -replace '[\\`]\r?\n', ' '),
        '(?<word>(?:"(?:[\\`].|[^"\\`])*"|''[^'']*''|[^\s;&|(){}`"''])+)|(?<end>[;&|(){}`\n])')
    $commands = @(, [System.Collections.Generic.List[string]]::new())
    foreach ($t in $tokens) {
        if ($t.Groups['end'].Success) { $commands += , [System.Collections.Generic.List[string]]::new() }
        else { $commands[-1].Add(($t.Value -replace '["'']', '')) }
    }

    foreach ($words in $commands) {
        $i = 0
        while ($i -lt $words.Count -and $words[$i] -notmatch '^(?:.*[\\/])?git(?:\.exe)?$') { $i++ }
        # git's own options, up to the subcommand. Those listed take the next word as their value.
        $hooksPath = $false
        for ($i++; $i -lt $words.Count -and $words[$i].StartsWith('-'); $i++) {
            if ($words[$i] -cin '-c', '-C', '--git-dir', '--work-tree', '--namespace', '--config-env') { $i++ }
            if ($i -lt $words.Count -and $words[$i] -match 'core\.hookspath') { $hooksPath = $true }
        }
        if ($i -ge $words.Count -or $words[$i] -notin 'commit', 'push') { continue }
        if ($hooksPath) { return $true }
        $commit = $words[$i] -eq 'commit'
        for ($i++; $i -lt $words.Count -and $words[$i] -ne '--'; $i++) {
            # --no-veri is the shortest git takes: --no-ver could be --no-verbose.
            if ($words[$i] -match '^--no-veri(fy?)?$') { return $true }
            # -n among short switches, before any that takes the rest of the word as its value.
            if ($commit -and $words[$i] -cmatch '^-[^-mFCctSu]*n') { return $true }
            # A switch whose value is the next word: a message is not read for switches.
            if ($words[$i] -cmatch '^(-[^-mFCct]*[mFCct]|--message|--file)$') { $i++ }
        }
    }
    $false
}

if ($SelfTest) {
    # Each: the command, and whether it is refused.
    $cases = @(
        @('git commit --no-verify -m "x"', $true),
        @('git push --no-verify', $true),
        @('git push --no-verify origin --delete 113-linux-probe', $true),
        @('git push origin main --no-verify', $true),
        @('git commit -n -m "x"', $true),
        @('git commit -anm "x"', $true),
        @('git commit -m "x" -n', $true),
        @('git commit --no-veri -m "x"', $true),
        @('git commit "--no-verify" -m x', $true),
        @('git -c core.hooksPath=/dev/null commit -m "x"', $true),
        @('git -c "core.hookspath=" push', $true),
        @('git -C vendor/grado-factorio-tools -c core.hooksPath= push', $true),
        @('git --config-env=core.hooksPath=NONE commit -m x', $true),
        @('git add -A && git commit --no-verify -m "x"', $true),
        @('git status; git push --no-verify', $true),
        @("git add a.txt`ngit commit -m `"x`" --no-verify", $true),
        @("git commit -m `"x`" \`n  --no-verify", $true),
        @('if git diff --quiet; then git push --no-verify; fi', $true),
        @('(cd docs && git commit -n -m x)', $true),
        @('"C:/Program Files/Git/cmd/git.exe" push --no-verify', $true),
        @('/usr/bin/git commit -n', $true),
        @('o=`git push --no-verify 2>&1`', $true),
        @('o=$(git commit -n -m x)', $true),
        @('git --config-env core.hooksPath=NONE commit -m x', $true),
        @('git --git-dir .git --work-tree . --namespace x commit -n', $true),
        @('git commit -uno -m x', $false),
        @('git commit --message "-n" --file msg.txt', $false),
        @('git push -n', $false),
        @('git push -n origin main', $false),
        @('git push --dry-run', $false),
        @('git commit -m "never pass --no-verify"', $false),
        @('git commit -m ''-n is refused, and so is --no-verify''', $false),
        @('git commit -am "--no-verify"', $false),
        @('git commit -m "x" -F - --no-verify', $true),
        @('echo git commit --no-verify', $true),
        @("git commit -m `"`$(cat <<'EOF'`nrefuse --no-verify`n`nand git commit -n too`nEOF`n)`"", $false),
        @('git commit -mn', $false),
        @('git commit -m x -- -n', $false),
        @('git commit -F msg.txt', $false),
        @('git commit --amend --no-edit', $false),
        @('git push --force-with-lease', $false),
        @('git push -u origin 118-refuse-hook-skip', $false),
        @('git -C vendor/grado-factorio-tools push', $false),
        @('git -c user.name=x commit -m "x"', $false),
        @('git config core.hooksPath .githooks', $false),
        @('git log -n 5', $false),
        @('git merge --no-verify topic', $false),
        @('git commit -m x; grep -n pattern file', $false),
        @('git status && ls -n', $false),
        @('gh pr create --title "x" --body "ran git push --no-verify once"', $false),
        @('grep -rn -- "--no-verify" docs', $false),
        @('ls .git/hooks', $false),
        @('', $false)
    )
    $failures = 0
    $n = 0
    $total = $cases.Count + 2
    foreach ($c in $cases) {
        $n++
        $ok = (Test-SkipsHooks -Command $c[0]) -eq $c[1]
        Write-Host ("self-test {0}/{1}: {2}: `{3}` -- {4}" -f $n, $total, $(if ($c[1]) { 'refused' } else { 'allowed' }), ($c[0] -replace '\r?\n', '\n'), $(if ($ok) { 'ok' } else { 'FAILED' }))
        if (-not $ok) { $failures++ }
    }
    # The wiring as the session runs it: the command the settings file wires for this script,
    # through sh, with the tool call on stdin. Exit 2 and the reason for a skip, exit 0 and
    # silence for the others.
    $n++
    $Settings = (Resolve-Path -LiteralPath ($Settings ? $Settings : (Join-Path $PSScriptRoot '../.claude/settings.json'))).Path
    $names = [regex]::Escape((Split-Path $PSCommandPath -Leaf))
    $entry = @((Get-Content -LiteralPath $Settings -Raw | ConvertFrom-Json).hooks.PreToolUse) |
        Where-Object { @($_.hooks.command) -match $names } | Select-Object -First 1
    $wired = if ($entry) { @($entry.hooks.command) -match $names | Select-Object -First 1 }
    $env:CLAUDE_PROJECT_DIR = Split-Path (Split-Path $Settings -Parent) -Parent
    # Git for Windows keeps its sh, and the cat beside it, off the path PowerShell sees.
    $sh = (Get-Command sh -ErrorAction SilentlyContinue)?.Source ?? (Join-Path (git --exec-path) "../../../usr/bin/sh.exe")
    $env:PATH = "$(Split-Path $sh)$([IO.Path]::PathSeparator)$env:PATH"
    $through = {
        param($command)
        $text = (@{ tool_input = @{ command = $command } } | ConvertTo-Json -Compress) | & $sh -c $wired 2>&1 | Out-String
        @{ Code = $LASTEXITCODE; Text = $text }
    }
    if (-not $wired) { $ok = $false; Write-Host "    $Settings wires no command that names this script" }
    else {
        $refused = & $through 'git push --no-verify origin main'
        $short = & $through 'git commit -n -m "x"'
        $dry = & $through 'git push -n'
        $plain = & $through 'git status'
        $ok = $refused.Code -eq 2 -and $refused.Text -match 'Refused' -and $refused.Text -match 'without' -and
            $short.Code -eq 2 -and $dry.Code -eq 0 -and -not $dry.Text.Trim() -and $plain.Code -eq 0 -and -not $plain.Text.Trim()
        if (-not $ok) { foreach ($r in $refused, $short, $dry, $plain) { Write-Host "    $($r.Code) $($r.Text)" } }
    }
    Write-Host ("self-test {0}/{1}: the wired hook refuses a push and a commit that skip the hooks with exit 2 and a reason, and passes a dry run and a plain command -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
    if (-not $ok) { $failures++ }
    # Which tools the session starts that command for: the matcher of the entry it was read from.
    $n++
    . "$PSScriptRoot/hook-matcher.ps1"
    $unstarted = @(if ($entry) { Get-UnstartedShellTool -Entry $entry })
    foreach ($tool in $unstarted) { Write-Host "    $Settings`: the matcher ``$($entry.matcher)`` does not start the hook for the $tool tool" }
    $ok = $entry -and -not $unstarted
    Write-Host ("self-test {0}/{1}: the matcher of the entry that wires the hook starts it for the Bash tool and for the PowerShell tool -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
    if (-not $ok) { $failures++ }
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $total case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $total cases."
    exit 0
}

try {
    $refuse = Test-SkipsHooks -Command ([string] ([Console]::In.ReadToEnd() | ConvertFrom-Json).tool_input.command)
}
catch {
    # Loud, and not a refusal: a hook that cannot read its input must not stop every command.
    [Console]::Error.WriteLine("refuse-git-hook-skip: could not read the tool call, so the command was NOT checked: $($_.Exception.Message)")
    exit 1
}
if ($refuse) {
    [Console]::Error.WriteLine(@"
Refused: this command would run git commit or git push with the hooks skipped: --no-verify,
commit's -n, or a core.hooksPath given for the one command. The hooks are this repository's gates.
Run the command again without the switch, with a longer timeout if the hook is slow. If a hook
fails, fix what it reports or tell the user: do not go round it.
"@)
    exit 2
}
exit 0
