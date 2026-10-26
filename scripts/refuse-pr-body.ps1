<#
.SYNOPSIS
    A hook for agent sessions: refuses `gh pr create` or `gh pr edit` whose body
    pr-body-check.ps1 fails, or whose body this cannot read from a file. Exit 2 refuses the
    command before it runs, with the check's report or what to write instead on stderr; exit 0
    lets it run, and means only that each body file this saw passed the check. Exit 1 says on
    stderr that the tool call could not be read and was not checked; the command still runs.

.DESCRIPTION
    WHY (grado-factorio-tools#259). PR #252 was opened with a body the check failed. The
    session ran `pr-body-check.ps1 ... 2>&1 | tail -4 && gh pr create ...`: the pipe's exit code
    was tail's, 0, so `&&` went on. docs/agents/issue-tracker.md asks for that chain without a
    pipe, and the session's memory held that a pipe hides an exit code; neither stopped it. CI
    checks the body only once the pull request exists.

    HOW IT IS WIRED. In .claude/settings.json, a PreToolUse hook on the two shell tools, matcher
    `Bash|PowerShell`, as refuse-git-hook-skip.ps1 is. This repository's own tracked settings
    wire it as the first example below shows, and a consumer names the script under
    vendor/grado-factorio-tools/ in its own. The session hands the hook the tool call as JSON on
    stdin: this reads `tool_input.command` and `cwd`. Every argument the wiring passes goes to
    pr-body-check.ps1 unchanged, after the body file; this repository passes -CiteSiblings
    -RequireSummaryVisual, as CI and the create command do. The check runs in `cwd`, since it
    asks git about the commits a body cites. The `case` keeps PowerShell from starting before
    every shell command: whatever is refused holds `gh` and `pr`.

    WHAT IT REFUSES, for each `gh pr create` and `gh pr edit` in the command (Truls's rulings on
    #259, 2026-10-26):
    - a body given inline, `--body`, `--body=`, `-b`, attached or not;
    - a `gh pr create` with no `--body-file` or `-F`, whatever else it uses: `--fill`,
      `--editor`, `--web`, `--template`, or nothing;
    - a body file given no path, `-` (standard input), or a path holding `$`, `%`, a backtick or
      a leading `~`, which the shell expands and this cannot;
    - a path, taken against `cwd` where it is relative, that names no file;
    - a body file pr-body-check.ps1 fails, with that check's report.

    WHAT IT LETS THROUGH. A `gh pr create` or `gh pr edit` each of whose body files passes the
    check; a `gh pr edit` that touches no body, as `--title` or `--add-label` alone; any of them
    with `--help` or `-h`; every other gh command. A Git Bash path, `/c/...`, is read as `C:/...`
    on Windows. The title is not checked (ruling 4).

    WHAT IT CANNOT SEE. A command inside a quoted string, as `sh -c` or `pwsh -Command`, a
    script, an alias, or a variable; a body written by `gh api` or any other way than these
    two subcommands; a body file in a cluster of short options, as `-dF body.md`, which on
    `gh pr create` is refused as no body file and on `gh pr edit` goes unchecked; a person's own
    terminal: this is a session's hook. A file the command itself writes before gh runs, as
    `... > body.md && gh pr create -F body.md`, is checked as it stands when the hook runs. And
    whether the settings still reach it, unless -SelfTest is run, which reads the wired
    command and the matcher of its entry, and nothing else of the settings.

    TO CHECK IT, run the second example below.

.PARAMETER SelfTest
    Prove it refuses what it should and lets the rest through, that the arguments after it
    reach the check, that the wired command reaches it, and that the matcher beside that
    command starts the hook for the Bash tool and for the PowerShell tool. The case that runs
    the command needs sh: the one on the path, or the one Git for Windows ships.

.PARAMETER Settings
    With -SelfTest: the .claude/settings.json whose wiring the last two cases read, with that
    file's repository as the project. Defaults to this repository's own.

.PARAMETER CheckArgs
    The arguments that follow the body file on pr-body-check.ps1's command line, as
    -CiteSiblings -RequireSummaryVisual: every argument this is given that it does not take
    itself.

.EXAMPLE
    The wired command: the PreToolUse hook in this repository's .claude/settings.json, as HOW IT
    IS WIRED says.

        i=$(cat); case $i in *gh*pr*) printf '%s' "$i" | pwsh -NoProfile -File "$CLAUDE_PROJECT_DIR/scripts/refuse-pr-body.ps1" -CiteSiblings -RequireSummaryVisual;; esac

.EXAMPLE
    To check it. The first is refused with exit 2, the second passes with exit 0:

        '{"tool_input":{"command":"gh pr create --body x"}}' | pwsh -NoProfile -File scripts/refuse-pr-body.ps1; $LASTEXITCODE
        '{"tool_input":{"command":"gh pr edit 1 --title x"}}' | pwsh -NoProfile -File scripts/refuse-pr-body.ps1; $LASTEXITCODE
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [switch] $SelfTest,
    [string] $Settings,
    [Parameter(ValueFromRemainingArguments)] [string[]] $CheckArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PrBodyRefusal {
    <#  Why $Command is refused, run in $Cwd, or nothing where it is not.  #>
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Command,
        [Parameter(Mandatory)] [string] $Cwd,
        [string[]] $CheckArgs = @()
    )

    # Words and the marks that end a command, as refuse-git-hook-skip.ps1's Test-SkipsHooks reads
    # them. A `$(` splits at its parenthesis and leaves the `$` its own word, and a backtick
    # ends the command: either way the body file's word is not a path this can read.
    $tokens = [regex]::Matches(($Command -replace '[\\`]\r?\n', ' '),
        '(?<word>(?:"(?:[\\`].|[^"\\`])*"|''[^'']*''|[^\s;&|(){}`"''])+)|(?<end>[;&|(){}`\n])')
    $commands = @(, [System.Collections.Generic.List[string]]::new())
    foreach ($t in $tokens) {
        if ($t.Groups['end'].Success) { $commands += , [System.Collections.Generic.List[string]]::new() }
        else { $commands[-1].Add(($t.Value -replace '["'']', '')) }
    }

    foreach ($words in $commands) {
        for ($i = 0; $i + 2 -lt $words.Count; $i++) {
            if ($words[$i] -notmatch '^(?:.*[\\/])?gh(?:\.exe)?$' -or $words[$i + 1] -ne 'pr' -or
                $words[$i + 2] -notin 'create', 'edit') { continue }
            $sub = $words[$i + 2]
            $files = [System.Collections.Generic.List[object]]::new()
            $inline = $help = $false
            for ($j = $i + 3; $j -lt $words.Count; $j++) {
                $w = $words[$j]
                if ($w -cmatch '^(?:--body(?:=.*)?|-b.*)$') { $inline = $true }
                elseif ($w -cin '--body-file', '-F') { $files.Add($(if ($j + 1 -lt $words.Count) { $words[++$j] })) }
                elseif ($w -cmatch '^(?:--body-file=|-F)(.+)$') { $files.Add($Matches[1]) }
                elseif ($w -cin '--help', '-h') { $help = $true }
            }
            if ($help) { continue }
            if ($inline) { return "gh pr $sub gives its body inline, which the check cannot read. Write the body to a file and pass --body-file <path>." }
            if ($sub -eq 'create' -and -not $files.Count) { return 'gh pr create is given no --body-file, so its body cannot be checked. Write the body to a file and pass --body-file <path>.' }
            foreach ($f in $files) {
                if (-not $f) { return "gh pr $sub is given --body-file with no path. Pass the body file's path." }
                if ($f -eq '-') { return "gh pr $sub reads its body from standard input, which the check cannot read. Pass --body-file <path>." }
                if ($f -match '[$%`]|^~') { return "gh pr $sub's body file, $f, is named through the shell, which this cannot expand. Write its path in full." }
                $path = if ($IsWindows -and $f -match '^/([a-zA-Z])(/.*)?$') { "$($Matches[1]):$($Matches[2] ?? '/')" } else { $f }
                if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path $Cwd $path }
                if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return "gh pr $sub's body file, $f, is not there ($path). Write it first, then run gh." }
                Push-Location -LiteralPath $Cwd
                try { $report = pwsh -NoProfile -File (Join-Path $PSScriptRoot 'pr-body-check.ps1') $path @CheckArgs 2>&1 | Out-String }
                finally { Pop-Location }
                if ($LASTEXITCODE -ne 0) { return "gh pr $sub's body, $f, fails pr-body-check.ps1 $($CheckArgs -join ' '). Fix the body and run gh again.`n$($report.TrimEnd())" }
            }
        }
    }
    $null
}

if ($SelfTest) {
    $root = Split-Path $PSScriptRoot -Parent
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "refuse-pr-body-$PID"
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $body = "## Summary`n`n{0}`n`n## Evidence`n`n**Before:** none`n`n**After:** none`n`n## Merge Danger`n`n**Door:** none`n`n**Blast Radius:** none`n"
    $good = Join-Path $tmp 'good.md'
    Set-Content -LiteralPath $good -NoNewline -Value ($body -f '    a visual')
    $plain = Join-Path $tmp 'plain.md'
    Set-Content -LiteralPath $plain -NoNewline -Value ($body -f 'No visual.')
    $bad = Join-Path $tmp 'bad.md'
    Set-Content -LiteralPath $bad -NoNewline -Value 'No headings at all.'
    $rel = [IO.Path]::GetRelativePath($root, $good) -replace '\\', '/'
    $msys = $good -replace '\\', '/' -replace '^([a-zA-Z]):', { '/' + $_.Groups[1].Value.ToLower() }
    $visual = '-CiteSiblings', '-RequireSummaryVisual'
    # Each: the command, the check's arguments, and a pattern its refusal matches, or $null where
    # it passes.
    $cases = @(
        @('gh pr create --title t --body "text"', @(), 'inline'),
        @('gh pr create -b "text"', @(), 'inline'),
        @('gh pr create --body=text', @(), 'inline'),
        @('gh pr edit 5 --body "text"', @(), 'inline'),
        @('gh pr create --fill', @(), 'no --body-file'),
        @('gh pr create --title t', @(), 'no --body-file'),
        @('gh pr create --body-file $R/x.md', @(), 'in full'),
        @('gh pr create --body-file "$(pwd)/x.md"', @(), 'in full'),
        @('gh pr create --body-file %TEMP%/x.md', @(), 'in full'),
        @('gh pr create --body-file ~/x.md', @(), 'in full'),
        @('gh pr create --body-file -', @(), 'standard input'),
        @('gh pr create --body-file', @(), 'no path'),
        @("gh pr create --body-file `"$tmp/missing.md`"", @(), 'not there'),
        @("gh pr create --title t --body-file `"$bad`"", @(), 'fails pr-body-check'),
        @("gh pr edit 5 -F `"$bad`"", @(), 'fails pr-body-check'),
        @("pwsh -NoProfile -File scripts/pr-body-check.ps1 `$R/body.md -CiteSiblings 2>&1 | tail -4 && gh pr create --base main --head x --title `"`$T`" --body-file `$R/body.md", @(), 'in full'),
        @("gh pr create --body-file `"$plain`"", $visual, 'RequireSummaryVisual'),
        @("gh pr create --body-file `"$plain`"", @('-CiteSiblings'), $null),
        @("gh pr create --title t --body-file `"$good`"", $visual, $null),
        @("gh pr create -F $rel", $visual, $null),
        @("gh pr create --body-file=`"$good`"", $visual, $null),
        @("gh pr edit 5 -F`"$good`"", $visual, $null),
        @("gh pr create --body-file $msys", $visual, $null),
        @('gh pr edit 5 --title t --add-label x', @(), $null),
        @('gh pr create --help', @(), $null),
        @('gh pr view 5 --json body', @(), $null),
        @('git status', @(), $null),
        @('', @(), $null)
    )
    $failures = 0
    $n = 0
    $total = $cases.Count + 3
    # Run from elsewhere than -Cwd, so a relative path read against this process's location fails.
    Push-Location -LiteralPath $tmp
    foreach ($c in $cases) {
        $n++
        $got = Get-PrBodyRefusal -Command $c[0] -Cwd $root -CheckArgs $c[1]
        $ok = if ($c[2]) { $got -and $got -match $c[2] } else { -not $got }
        if (-not $ok) { Write-Host "    got: $got" }
        Write-Host ("self-test {0}/{1}: {2}: `{3}` {4} -- {5}" -f $n, $total, $(if ($c[2]) { 'refused' } else { 'allowed' }), $c[0], ($c[1] -join ' '), $(if ($ok) { 'ok' } else { 'FAILED' }))
        if (-not $ok) { $failures++ }
    }
    Pop-Location
    Remove-Item -LiteralPath $tmp -Recurse -Force
    # The wiring as the session runs it: the command the settings file wires for this script,
    # through sh, with the tool call on stdin. Exit 2 and the reason for an inline body, exit 0
    # and silence for the others.
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
        $text = (@{ tool_input = @{ command = $command }; cwd = $root } | ConvertTo-Json -Compress) | & $sh -c $wired 2>&1 | Out-String
        @{ Code = $LASTEXITCODE; Text = $text }
    }
    if (-not $wired) { $ok = $false; Write-Host "    $Settings wires no command that names this script" }
    else {
        $refused = & $through 'gh pr create --body text'
        $edit = & $through 'gh pr edit 1 --title t'
        $other = & $through 'git status'
        $ok = $refused.Code -eq 2 -and $refused.Text -match 'Refused' -and $refused.Text -match '--body-file' -and
            $edit.Code -eq 0 -and -not $edit.Text.Trim() -and $other.Code -eq 0 -and -not $other.Text.Trim()
        if (-not $ok) { foreach ($r in $refused, $edit, $other) { Write-Host "    $($r.Code) $($r.Text)" } }
    }
    Write-Host ("self-test {0}/{1}: the wired hook refuses an inline body with exit 2 and a reason, and passes an edit of the title and a plain command -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
    if (-not $ok) { $failures++ }
    # A tool call it cannot read: exit 1 and a line on stderr, not a refusal.
    $n++
    $unread = 'not json' | pwsh -NoProfile -File $PSCommandPath 2>&1 | Out-String
    $ok = $LASTEXITCODE -eq 1 -and $unread -match 'NOT checked'
    if (-not $ok) { Write-Host "    $LASTEXITCODE $unread" }
    Write-Host ("self-test {0}/{1}: a tool call it cannot read exits 1 and says it was not checked -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
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
    $call = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $cwd = if ($call.PSObject.Properties['cwd'] -and $call.cwd) { [string] $call.cwd } else { (Get-Location).Path }
    $refusal = Get-PrBodyRefusal -Command ([string] $call.tool_input.command) -Cwd $cwd -CheckArgs @($CheckArgs | Where-Object { $_ })
}
catch {
    # Loud, and not a refusal: a hook that cannot read its input must not stop every command.
    [Console]::Error.WriteLine("refuse-pr-body: could not read the tool call, so the command was NOT checked: $($_.Exception.Message)")
    exit 1
}
if ($refusal) {
    [Console]::Error.WriteLine("Refused: $refusal")
    exit 2
}
exit 0
