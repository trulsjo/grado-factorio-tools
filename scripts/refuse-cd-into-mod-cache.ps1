<#
.SYNOPSIS
    A hook for agent sessions: refuses a shell command that changes directory into the mod cache,
    .mod-cache/ under the repository root it is given. Exit 2 refuses the command before it runs
    and says what to do instead; exit 0 lets it run.

.DESCRIPTION
    WHY (grado-factorio-modpack#150, where this was written). An agent session's tooling writes
    state files into whatever directory its shell stands in. On 2026-10-05 a command that changed
    directory into a mod in the cache left two state directories there, one of them inside the
    mod, and a file inside a mod is part of what the game loads. Reading the cache by path from
    the repository root leaves nothing behind.

    HOW A CONSUMER WIRES IT. This repository cannot: a session reads its hooks from the
    consumer's own tracked settings. In .claude/settings.json, a PreToolUse hook on the two shell
    tools, matcher `Bash|PowerShell`, whose command is the first example below, the wired
    command.

    The session hands the hook the tool call as JSON on stdin: this reads `tool_input.command`
    and `cwd`. The `case` starts this script only when that JSON holds the cache's name, because
    starting PowerShell took a second on the machine it was written on (2026-10-06) and the hook
    runs before every shell command.

    WHERE THE SCRIPT IS NOT THERE (grado-factorio-tools#115), as in a clone whose submodule was
    never fetched, the wired command lets the shell command run and prints JSON that tells the
    agent it was not checked. Without that branch pwsh exits 64 for the missing file
    (measured 2026-10-08, PowerShell 7.6.6). What reaches the agent from that exit was not
    measured. By the account of grado-factorio-modpack#228, read 2026-10-12, a wiring of that
    repository's that said so on stderr and exited 1 was measured on 2026-10-11 with Claude
    Code 2.1.296, and what the tool call returned to the agent held nothing of it. -SelfTest
    holds a wiring to telling the agent, the consumer's too when it is given -Settings: a
    case runs the wired command for a project that holds no hook script, and fails unless
    that exits 0 and prints, on stdout, JSON whose hookSpecificOutput names the PreToolUse
    event and carries an additionalContext that is not empty. So a quote that breaks the JSON
    fails here; a percent sign that only mangles the message does not. The case has no
    switch to leave it out. A consumer whose wiring refuses the command in that branch, or
    says nothing, fails it, and is to tell the agent and let the command run, as the wired
    command does.

    WHAT IT REFUSES. A cd, chdir, pushd, sl, Set-Location or Push-Location, standing where a
    command can stand, whose target resolves to the cache or anything under it: relative or
    absolute, and on Windows with either slash, as /c/... or C:\.... A relative target is resolved
    from where the earlier ones in the command left the shell, and from where it started, since
    one in a subshell does not last. A target it cannot resolve - one holding a variable, a
    substitution or a wildcard - is refused if it holds the cache's name. And any command at all
    while the shell already stands in the cache, unless it begins by changing directory out.

    WHAT IT LETS THROUGH. Everything else, and so a command that reads, lists or searches the
    cache by path, and a script that is given a path and never stands there, as fetch-mods.ps1,
    get-dump.ps1 and the load harness are.

    WHAT IT CANNOT SEE. A script or program that changes directory itself. A target that reaches
    the cache through a variable, a wildcard, a link or a junction whose text does not say so.
    `git -C`, and a tool's own working-directory option. The cache spelt in another case than the
    wiring's `case` names it, which Windows opens and the wiring does not start this script for.
    Off Windows, a target written with a backslash, which pwsh takes as a separator there and
    this does not (ruled for grado-factorio-tools#113); and /c/... or /mnt/c/... is read there as
    the path it says, not as a drive. Anything under WSL, where it has not been run.
    It reads the command as text and does not parse the shell, so
    `cd .mod-cache` where a command could stand is refused inside a quoted string too: after a
    `;`, `&`, `|`, `(` or `{`, or at the start of a line. And whether a consumer's settings still
    reach it, unless -SelfTest is given them. That reads the wired command and the matcher of
    its entry, and nothing else of the settings: not a handler's `if`, which narrows further,
    and not whether a session reads a matcher as hook-matcher.ps1 does. A wiring with an entry
    for each shell tool fails it, since one entry is read.

    TO CHECK IT, run the second example below.

.PARAMETER Root
    The repository whose cache is guarded. The wiring gives "$CLAUDE_PROJECT_DIR". Without it
    nothing is checked, which is said on stderr with exit 1, not 2.

.PARAMETER CacheName
    The cache directory's name under the root. Defaults to .mod-cache, which is where
    fetch-mods.ps1 puts one. A consumer with another name gives it here and in the wiring's `case`.

.PARAMETER SelfTest
    Prove it refuses what it should and lets the rest through, that a wired command reaches
    it, and that the wiring tells the agent where the script is not there. With -Settings, also
    that the matcher beside that command starts the hook for both shell tools. The cases that run
    the wiring need sh: the one on the path, or the one Git for Windows ships. Off
    Windows the cases that are a Windows way of writing a path are not run, and each says so on
    its line: a backslash as separator, Git Bash's /c/... and WSL's /mnt/c/.... What each
    platform printed, and when, is in docs/measurements.md.

.PARAMETER Settings
    With -SelfTest: a consumer's .claude/settings.json. The cases that run the wiring then run
    the command wired there, its first PreToolUse hook, with that file's repository as the
    project, where they would otherwise run the wired command against this script. A consumer
    runs this to know its wiring still reaches the hook, and still tells the agent when it cannot.
    A last case, run only with -Settings, reads the matcher of that first PreToolUse entry
    (grado-factorio-tools#120) and fails, naming the tool and the file, unless a session would
    start the hook for the Bash tool and for the PowerShell tool. An entry with no matcher
    passes: it is started for every tool. How a matcher is read is in hook-matcher.ps1. The
    wired command comes from no file and has no matcher, so without -Settings none is read.

.EXAMPLE
    The wired command: the PreToolUse hook a consumer puts in its .claude/settings.json, as
    HOW A CONSUMER WIRES IT says.

        i=$(cat); case $i in *mod-cache*) h="$CLAUDE_PROJECT_DIR/vendor/grado-factorio-tools/scripts/refuse-cd-into-mod-cache.ps1"; if [ -f "$h" ]; then printf '%s' "$i" | pwsh -NoProfile -File "$h" -Root "$CLAUDE_PROJECT_DIR"; else printf '%s' '{"systemMessage":"refuse-cd-into-mod-cache: the hook script was not found, so this command was NOT checked. git submodule update --init fetches it.","hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"refuse-cd-into-mod-cache: the hook script was not found, so this command was NOT checked. git submodule update --init fetches it."}}'; fi;; esac

.EXAMPLE
    To check it, from a repository root. The first is refused with exit 2, the second passes
    with exit 0:

        '{"cwd":".","tool_input":{"command":"cd .mod-cache/a-set && ls"}}' | pwsh -NoProfile -File scripts/refuse-cd-into-mod-cache.ps1 -Root .; $LASTEXITCODE
        '{"cwd":".","tool_input":{"command":"ls .mod-cache/a-set"}}' | pwsh -NoProfile -File scripts/refuse-cd-into-mod-cache.ps1 -Root .; $LASTEXITCODE
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $Root,
    [string] $CacheName = '.mod-cache',
    [switch] $SelfTest,
    [string] $Settings
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-EntersCache {
    <#  Whether $Command, run by a shell standing in $Cwd, would stand in $Root/$CacheName.  #>
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Command,
        [Parameter(Mandatory)] [string] $Cwd,
        [Parameter(Mandatory)] [string] $Root,
        [string] $CacheName = '.mod-cache'
    )

    # ~ becomes what .NET resolves, and on Windows so do Git Bash's /c/... and WSL's /mnt/c/....
    # Off Windows /c/... is the directory it says, and c:/... would be read as a relative path.
    $native = {
        param($p)
        $p = $p -replace '^~(?=$|[\\/])', $HOME
        if ($IsWindows) { $p -replace '^/(?:mnt/)?([a-zA-Z])(?=$|/)', '$1:' } else { $p }
    }
    $cache = [IO.Path]::GetFullPath((Join-Path $Root $CacheName))
    $inside = { param($p) $p -eq $cache -or $p.StartsWith($cache + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) }

    $start = $here = [IO.Path]::GetFullPath((& $native $Cwd), $Root)
    $moves = [regex]::Matches($Command,
        '(?:^|[;&|({\n]|\b(?:then|do|else|if|elif|while|until)\s)\s*(?:cd|chdir|pushd|sl|Set-Location|Push-Location)\s+(?:--?\w*\s+)*("[^"]*"|''[^'']*''|[^\s;&|)}]+)', 'IgnoreCase')
    if ((& $inside $here) -and -not ($moves.Count -and $moves[0].Index -eq 0)) { return $true }
    foreach ($m in $moves) {
        $target = $m.Groups[1].Value.Trim('"', "'")
        if ($target -match '[$`%*?]') {
            if ($target -match [regex]::Escape($CacheName)) { return $true }
            continue
        }
        $here = [IO.Path]::GetFullPath((& $native $target), $here)
        if ((& $inside $here) -or (& $inside ([IO.Path]::GetFullPath((& $native $target), $start)))) { return $true }
    }
    $false
}

if ($SelfTest) {
    $fixture = Join-Path ([IO.Path]::GetTempPath()) 'refuse-cd-selftest/repo'
    # The fixture as Git Bash writes it. Off Windows there is no drive to name, and the cases
    # that use this are not run: /c stands in so that their lines still show the form.
    $posix = if ($IsWindows) { "/$($fixture.Substring(0, 1).ToLower())" + ($fixture.Substring(2) -replace '\\', '/') } else { "/c$fixture" }
    # Each: the command, where the shell stands (relative to the root), whether it is refused,
    # and, on one that is a Windows way of writing a path, a mark that it is.
    $cases = @(
        @('cd .mod-cache', '.', $true),
        @('cd .mod-cache/Grado_ABC/flib/prototypes && ls', '.', $true),
        @('cd ./.mod-cache/', '.', $true),
        @('if cd .mod-cache; then ls; fi', '.', $true),
        @('cd -P .mod-cache', '.', $true),
        @('(cd docs && ls); cd .mod-cache', '.', $true),
        @("cd `"$fixture\.mod-cache\Grado_ABC`"", '.', $true, 'windows'),
        @("cd '$posix/.mod-cache' && pwd", '.', $true, 'windows'),
        @("cd /mnt$posix/.mod-cache", '.', $true, 'windows'),
        @('git status; cd .mod-cache', '.', $true),
        @('ls && (cd .mod-cache/Grado_ABC; ls)', '.', $true),
        @('Set-Location -LiteralPath .mod-cache\Grado_ABC', '.', $true, 'windows'),
        @('Push-Location .mod-cache; Get-ChildItem; Pop-Location', '.', $true),
        @('pushd .mod-cache', '.', $true),
        @('cd ../.mod-cache/Grado_ABC', 'docs', $true),
        @('cd docs && cd ../.mod-cache', '.', $true),
        @('cd "$CACHE/.mod-cache/Grado_ABC"', '.', $true),
        @('ls', '.mod-cache/Grado_ABC', $true),
        @('cd flib', '.mod-cache/Grado_ABC', $true),
        @('git status && cd ../..', '.mod-cache/Grado_ABC', $true),
        @('cd ../.. && git status', '.mod-cache/Grado_ABC', $false),
        @("cd `"$fixture`"", '.mod-cache', $false),
        @('ls .mod-cache/Grado_ABC', '.', $false),
        @('grep -rn "name" .mod-cache/Grado_ABC/flib/info.json', '.', $false),
        @('Get-ChildItem -LiteralPath .mod-cache/Grado_ABC -Recurse', '.', $false),
        @('git -C .mod-cache/Grado_ABC/flib log', '.', $false),
        @('pwsh -File scripts/stage-pack.ps1 Grado_ABC', '.', $false),
        @('pwsh -File scripts/get-dump.ps1 Grado_ABC', '.', $false),
        @('pwsh -File vendor/grado-factorio-tools/scripts/load-harness.ps1 ".mod-cache/Grado_ABC"', '.', $false),
        @('cd docs && ls', '.', $false),
        @('cd .mod-cache-notes', '.', $false),
        @('cd .mod-cache/..', '.', $false),
        @('cd docs && cd agents', '.', $false),
        @('cd -', '.', $false),
        @('git commit -m "never cd .mod-cache again"', '.', $false),
        @('echo cd .mod-cache', '.', $false),
        @('', '.', $false)
    )
    $failures = 0
    $skipped = 0
    $n = 0
    # The last case reads a settings file, and without -Settings there is none.
    $total = $cases.Count + 4 + [bool] $Settings
    foreach ($c in $cases) {
        $n++
        if ($c.Count -gt 3 -and -not $IsWindows) {
            $skipped++
            Write-Host ("self-test {0}/{1}: refused from {2}: `{3}` -- skipped: a Windows way of writing a path, not run off Windows" -f $n, $total, $c[1], $c[0])
            continue
        }
        $got = Test-EntersCache -Command $c[0] -Cwd (Join-Path $fixture $c[1]) -Root $fixture
        $ok = $got -eq $c[2]
        Write-Host ("self-test {0}/{1}: {2} from {3}: `{4}` -- {5}" -f $n, $total, $(if ($c[2]) { 'refused' } else { 'allowed' }), $c[1], $c[0], $(if ($ok) { 'ok' } else { 'FAILED' }))
        if (-not $ok) { $failures++ }
    }
    # An absolute path whose first directory is one letter, which is what Git Bash's drive form
    # looks like: off Windows it is that directory, and must not be read as a drive.
    $n++
    $letter = if ($IsWindows) { $fixture -replace '\\', '/' } else { '/t/refuse-cd-selftest/repo' }
    $ok = (Test-EntersCache -Command "cd `"$letter/.mod-cache`"" -Cwd $letter -Root $letter) -and
        (Test-EntersCache -Command 'ls' -Cwd "$letter/.mod-cache/Grado_ABC" -Root $letter) -and
        -not (Test-EntersCache -Command "cd `"$letter/docs`"" -Cwd $letter -Root $letter)
    Write-Host ("self-test {0}/{1}: refused from {2}: cd {2}/.mod-cache, and ls from inside it; allowed: cd {2}/docs -- {3}" -f $n, $total, $letter, $(if ($ok) { 'ok' } else { 'FAILED' }))
    if (-not $ok) { $failures++ }
    $n++
    $named = { param($c) Test-EntersCache -Command $c -Cwd $fixture -Root $fixture -CacheName 'kept-mods' }
    $ok = (& $named 'cd kept-mods/a-set') -and (& $named 'cd "$HERE/kept-mods"') -and -not (& $named 'cd .mod-cache')
    Write-Host ("self-test {0}/{1}: a cache given another name is the one guarded, and .mod-cache is then not -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
    if (-not $ok) { $failures++ }
    # The wiring as the session runs it: a hook's command, through sh, with the tool call on
    # stdin. Exit 2 and the reason for one, exit 0 and silence for the others. The command is the
    # consumer's when -Settings names its file, and otherwise the one the header shows, with
    # this repository as the project so that it finds this script.
    $n++
    if ($Settings) {
        $Settings = (Resolve-Path -LiteralPath $Settings).Path
        $entry = (Get-Content -LiteralPath $Settings -Raw | ConvertFrom-Json).hooks.PreToolUse[0]
        $wired = $entry.hooks[0].command
        $project = Split-Path (Split-Path $Settings -Parent) -Parent
    }
    else {
        $wired = 'i=$(cat); case $i in *mod-cache*) h="$CLAUDE_PROJECT_DIR/scripts/refuse-cd-into-mod-cache.ps1"; if [ -f "$h" ]; then printf ''%s'' "$i" | pwsh -NoProfile -File "$h" -Root "$CLAUDE_PROJECT_DIR"; else printf ''%s'' ''{"systemMessage":"refuse-cd-into-mod-cache: the hook script was not found, so this command was NOT checked. git submodule update --init fetches it.","hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"refuse-cd-into-mod-cache: the hook script was not found, so this command was NOT checked. git submodule update --init fetches it."}}''; fi;; esac'
        $project = Split-Path $PSScriptRoot -Parent
    }
    $env:CLAUDE_PROJECT_DIR = $project
    # Git for Windows keeps its sh, and the cat beside it, off the path PowerShell sees.
    $sh = (Get-Command sh -ErrorAction SilentlyContinue)?.Source ?? (Join-Path (git --exec-path) "../../../usr/bin/sh.exe")
    $env:PATH = "$(Split-Path $sh)$([IO.Path]::PathSeparator)$env:PATH"
    $through = {
        param($command)
        $text = (@{ cwd = $project; tool_input = @{ command = $command } } | ConvertTo-Json -Compress) | & $sh -c $wired 2>&1 | Out-String
        @{ Code = $LASTEXITCODE; Text = $text }
    }
    $refused = & $through 'cd .mod-cache/Grado_ABC && ls'
    $read = & $through 'ls .mod-cache/Grado_ABC'
    $plain = & $through 'git status'
    $ok = $refused.Code -eq 2 -and $refused.Text -match 'Refused' -and $refused.Text -match 'repository root' -and
        $read.Code -eq 0 -and -not $read.Text.Trim() -and $plain.Code -eq 0 -and -not $plain.Text.Trim()
    Write-Host ("self-test {0}/{1}: the wired hook refuses a cd into the cache with exit 2 and a reason, and passes a read by path and a plain command -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
    if (-not $ok) { $failures++; Write-Host "    refused: $($refused.Code) $($refused.Text)"; Write-Host "    read: $($read.Code) $($read.Text)"; Write-Host "    plain: $($plain.Code) $($plain.Text)" }
    # The same command for a project with no hook script, as a clone without the submodule is:
    # the command runs, and what is printed tells the agent it was not checked.
    $n++
    $env:CLAUDE_PROJECT_DIR = $project = Join-Path $fixture 'no-hook-script'
    # Stdout alone, where the cases before take stderr too: what a hook prints for the session
    # to read is its stdout.
    $absent = @{ Text = (@{ cwd = $project; tool_input = @{ command = 'cd .mod-cache/Grado_ABC && ls' } } | ConvertTo-Json -Compress) | & $sh -c $wired 2>$null | Out-String }
    $absent.Code = $LASTEXITCODE
    $ok = $absent.Code -eq 0 -and $(try {
            $told = ($absent.Text | ConvertFrom-Json).hookSpecificOutput
            $told.hookEventName -ceq 'PreToolUse' -and [bool] ([string] $told.additionalContext).Trim()
        } catch { $false })
    Write-Host ("self-test {0}/{1}: where the project holds no hook script, the wired command exits 0 and prints JSON telling the agent the command was not checked -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
    if (-not $ok) { $failures++; Write-Host "    $($absent.Code) $($absent.Text)" }
    # Which tools the session starts that command for: the matcher of the entry it was read
    # from. The command the header shows comes from no file, and has no matcher to read.
    if ($Settings) {
        $n++
        . "$PSScriptRoot/hook-matcher.ps1"
        $unstarted = @(Get-UnstartedShellTool -Entry $entry)
        foreach ($tool in $unstarted) { Write-Host "    $Settings`: the matcher ``$($entry.matcher)`` does not start the hook for the $tool tool" }
        Write-Host ("self-test {0}/{1}: the matcher of the entry that wires the hook starts it for the Bash tool and for the PowerShell tool -- {2}" -f $n, $total, $(if ($unstarted) { 'FAILED' } else { 'ok' }))
        if ($unstarted) { $failures++ }
    }
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $total case(s) did not hold."; exit 1 }
    if ($skipped) { Write-Host "OK - self-test passed: $($total - $skipped) of $total cases; $skipped skipped off Windows, each named above."; exit 0 }
    Write-Host "OK - self-test passed: all $total cases."
    exit 0
}

try {
    if (-not $Root) { throw 'no -Root was given, and the cache is found under it' }
    $Root = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Root)
    $call = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $refuse = Test-EntersCache -Command ([string] $call.tool_input.command) -Cwd ([string] $call.cwd) -Root $Root -CacheName $CacheName
}
catch {
    # Loud, and not a refusal: a hook that cannot read its input must not stop every command.
    [Console]::Error.WriteLine("refuse-cd-into-mod-cache: could not read the tool call, so the command was NOT checked: $($_.Exception.Message)")
    exit 1
}
if ($refuse) {
    [Console]::Error.WriteLine(@"
Refused: this command would stand in the mod cache, $(Join-Path $Root $CacheName).
A session's tooling writes state files into the directory its shell stands in, and a file inside a
mod there is part of what the game loads. Run it from the repository root and name the cache by
path instead: ls $CacheName/<set>, Get-ChildItem -LiteralPath $CacheName/<set>, git -C <path>, or
a script given the path. If the shell already stands there, cd out first.
"@)
    exit 2
}
exit 0
