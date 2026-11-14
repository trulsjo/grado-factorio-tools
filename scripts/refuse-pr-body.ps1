<#
.SYNOPSIS
    A hook for agent sessions: refuses `gh pr create` or `gh pr edit` whose body pr-body-check.ps1
    fails, or whose body this cannot read from a file, and `gh pr comment`, `gh issue create` or
    `gh issue comment` whose body file markdown-check.ps1 -Body fails, or that this cannot read.
    Exit 2 refuses the command before it runs, with the check's report or what to write instead on
    stderr; exit 0 lets it run, and means only that each body file this checked passed: a call with
    `--help` or `-h` is not checked. Exit 1 says on stderr that the command could not be checked, as
    where the tool call cannot be read; the command still runs.

.DESCRIPTION
    WHY (grado-factorio-tools#259). PR #252 was opened with a body the check failed. The session ran
    `pr-body-check.ps1 ... 2>&1 | tail -4 && gh pr create ...`: the pipe's exit code was tail's, 0,
    so `&&` went on. docs/agents/issue-tracker.md asks for that chain without a pipe, and the
    session's memory held that a pipe hides an exit code; neither stopped it. CI checks the body
    only once the pull request exists. Of a comment or an issue (#386): in PR #374's session a
    review comment was posted after its check refused the file, and six tickets were filed with no
    check run.

    HOW IT IS WIRED. In .claude/settings.json, a PreToolUse hook on the two shell tools, matcher
    `Bash|PowerShell`, as refuse-git-hook-skip.ps1 is. A consumer's command is the first example
    below (ADR 0004), which names the script under vendor/grado-factorio-tools/ and, where it is not
    there, lets the command run and tells the agent which path is missing. This repository's own
    tracked settings wire it from scripts/. The session hands the hook the tool call as JSON on
    stdin: this reads `tool_input.command` and `cwd`. Every argument the wiring passes goes to
    pr-body-check.ps1 unchanged, after the body file; the example passes none, the check's defaults,
    and a consumer adds on its own line the ones its gate uses (ADR 0004 decision 5). This
    repository passes -CiteSiblings -RequireSummaryVisual, as CI and the create command do, and
    -CheckRuns, as CI does. With -CheckRuns among them, a `gh pr edit` also hands the check -Head
    and the head `gh pr view` names for the pull request the edit names in the word after `edit`, or
    for the current branch's where that word is an option, as in `gh pr edit -F b.md 459` (#455);
    where gh names none, the check reads no run and says so. A `gh pr create` hands no head: the
    pull request does not exist yet. The check runs in `cwd`, since it asks git about the commits a
    body cites, and gh which pull request a branch has. The `case` keeps PowerShell from starting
    before every shell command: whatever is refused holds `gh` and `pr`, or `gh` and `issue`.

    WHAT IT REFUSES, for each `gh pr create` and `gh pr edit` in the command (Truls's rulings on
    #259, 2026-10-26):
    - a body given inline, `--body`, `--body=`, `-b`, attached or not;
    - a `gh pr create` with no `--body-file` or `-F`, whatever else it uses: `--fill`,
      `--editor`, `--web`, `--template`, or nothing;
    - a body file given no path, `--body-file=` with nothing after it among them, `-` (standard
      input), or a path holding `$`, `%`, a backtick or
      a leading `~`, which the shell expands and this cannot;
    - a path, taken against `cwd` where it is relative, that names no file;
    - a body file pr-body-check.ps1 fails, with that check's report.

    For each `gh pr comment`, `gh issue create` and `gh issue comment` (#386): a body file given no
    path, `-`, a path through the shell, or one that names no file, as for a pull request's body;
    and a body file markdown-check.ps1 -Body fails, with that check's report. The wiring's arguments
    are pr-body-check.ps1's and do not reach it. An inline body, and a command with no body file, as
    one that opens an editor, are let through (Truls's ruling 3 on #386).

    WHAT IT LETS THROUGH. A `gh pr create` or `gh pr edit` each of whose body files passes the
    check; a `gh pr edit` that touches no body, as `--title` or `--add-label` alone; a
    `gh pr comment`, `gh issue create` or `gh issue comment` each of whose body files passes
    markdown-check.ps1 -Body, or that has an inline body or no body file; any of the five with
    `--help` or `-h`; every other gh command. A Git Bash path, `/c/...`, is read as `C:/...` on
    Windows. The title is not checked (ruling 4).

    WHAT IT CANNOT SEE. A command inside a quoted string, as `sh -c` or `pwsh -Command`, a script,
    an alias, or a variable; a body written by `gh api`, `gh issue edit`, a `--comment` on
    `gh issue close` or any other way than these five subcommands; a comment's or an issue's inline
    body; a body file in a cluster of short options, as `-dF body.md`, which on `gh pr create` is
    refused as no body file and on `gh pr edit` goes unchecked; a person's own terminal: this is a
    session's hook. A file the command itself writes before gh runs, as
    `... > body.md && gh pr create -F body.md`, is checked as it stands when the hook runs. And
    whether the settings still reach it, unless -SelfTest is run, which reads the wired command and
    the matcher of its entry, and nothing else of the settings.

    WHAT IT REFUSES WRONGLY. It reads the command as text and does not parse the shell, so text that
    names one of the five subcommands outside quotes is read as a command: in a heredoc, in an
    `echo`, in a comment, between backticks, or after a lone apostrophe in a here-string. A value of
    another option that begins `-b`, as `--title '-bump deps'`, reads as an inline body. Write such
    text to a file and pass the file.

    TO CHECK IT, run the second example below.

.PARAMETER SelfTest
    Prove it refuses what it should and lets the rest through, that the arguments after it reach the
    check, that the wired command reaches it, that the matcher beside that command starts the hook
    for the Bash tool and for the PowerShell tool, and that the first example's form refuses where
    the script is and, where it is not, exits 0 and prints JSON naming the missing path. The cases
    that run a command need sh: the one on the path, or the one Git for Windows ships.

.PARAMETER Settings
    With -SelfTest: the .claude/settings.json read by the case that runs the wired command and the
    one that reads its matcher, with that file's repository as the project. Defaults to this
    repository's own.

.PARAMETER CheckArgs
    The arguments that follow the body file on pr-body-check.ps1's command line: every argument this
    is given that it does not take itself. None by default. pr-body-check.ps1's header names its
    options; a consumer's gate may pass -CiteSiblings and -RequireSummaryVisual, as this
    repository's does, which also passes -CheckRuns. With -CheckRuns, -Head is added on
    `gh pr edit`, as HOW IT IS WIRED says.

.EXAMPLE
    The wired command: the PreToolUse hook a consumer puts in its .claude/settings.json, as HOW
    IT IS WIRED says. It passes the check no argument, its defaults; a consumer adds after the
    script's path the ones its gate uses, as -CiteSiblings -RequireSummaryVisual.

        i=$(cat); case $i in *gh*pr*|*gh*issue*) h="$CLAUDE_PROJECT_DIR/vendor/grado-factorio-tools/scripts/refuse-pr-body.ps1"; if [ -f "$h" ]; then printf '%s' "$i" | pwsh -NoProfile -File "$h"; else m='refuse-pr-body: vendor/grado-factorio-tools/scripts/refuse-pr-body.ps1 was not found, so this command was NOT checked by the pull request body hook. git submodule update --init fetches the script.'; printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}' "$m" "$m"; fi;; esac

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

# The head of the pull request $Selector names, a number, an address or a branch, or with none
# the current branch's, as gh names it from the current location; nothing where gh cannot.
$GhHead = {
    param([string] $Selector)
    $named = @(if ($Selector) { $Selector })
    $h = gh pr view @named --json headRefOid --jq .headRefOid 2>$null
    if ($LASTEXITCODE -eq 0 -and "$h".Trim()) { "$h".Trim() }
}

function Get-CheckArgument {
    <#  The arguments for pr-body-check.ps1 after the body file, for `gh $Sub` with $Rest the words
        after the subcommand: $CheckArgs, and on `gh pr edit` with -CheckRuns among them, -Head and
        the head $HeadOf gives for the pull request $Rest's first word names, where that word is not
        an option, or for none, the current branch's, where it is (#455): `gh pr edit -F b.md 459`
        gets the current branch's head, not 459's. Where $HeadOf gives none, no -Head: the check
        then reads no run, and says so.  #>
    param([Parameter(Mandatory)] [string] $Sub, [string[]] $Rest = @(), [string[]] $CheckArgs = @(),
        [Parameter(Mandatory)] [scriptblock] $HeadOf)
    $CheckArgs
    if ($Sub -ne 'pr edit' -or $CheckArgs -notcontains '-CheckRuns') { return }
    $selector = if ($Rest.Count -and $Rest[0] -notmatch '^-') { $Rest[0] } else { '' }
    $head = & $HeadOf $selector
    if ($head) { '-Head'; $head }
}

function Get-PrBodyRefusal {
    <#  Why $Command is refused, run in $Cwd, or nothing where it is not. $HeadOf names a pull
        request's head for Get-CheckArgument.  #>
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Command,
        [Parameter(Mandatory)] [string] $Cwd,
        [string[]] $CheckArgs = @(),
        [scriptblock] $HeadOf = $GhHead
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
            if ($words[$i] -notmatch '^(?:.*[\\/])?gh(?:\.exe)?$') { continue }
            # A pull request's body is held to pr-body-check.ps1; a comment's or an issue's, to
            # markdown-check.ps1 -Body (#386).
            $prose = $words[$i + 1] -eq 'pr' -and $words[$i + 2] -eq 'comment' -or
                $words[$i + 1] -eq 'issue' -and $words[$i + 2] -in 'create', 'comment'
            if (-not $prose -and ($words[$i + 1] -ne 'pr' -or $words[$i + 2] -notin 'create', 'edit')) { continue }
            $sub = "$($words[$i + 1]) $($words[$i + 2])"
            $files = [System.Collections.Generic.List[object]]::new()
            $inline = $help = $false
            for ($j = $i + 3; $j -lt $words.Count; $j++) {
                $w = $words[$j]
                if ($w -cmatch '^(?:--body(?:=.*)?|-b.*)$') { $inline = $true }
                elseif ($w -cin '--body-file', '-F') { $files.Add($(if ($j + 1 -lt $words.Count) { $words[++$j] })) }
                # An attached value may be empty, as `--body-file=`: a body file with no path.
                elseif ($w -cmatch '^(?:--body-file=|-F)(.*)$') { $files.Add($Matches[1]) }
                elseif ($w -cin '--help', '-h') { $help = $true }
            }
            if ($help) { continue }
            # An inline body, or none, of a comment or an issue is let through (#386's ruling 3).
            if ($inline -and -not $prose) { return "gh $sub gives its body inline, which the check cannot read. Write the body to a file and pass --body-file <path>." }
            if ($sub -eq 'pr create' -and -not $files.Count) { return 'gh pr create is given no --body-file, so its body cannot be checked. Write the body to a file and pass --body-file <path>.' }
            # Asked of gh once, and only where a body file is checked, from $Cwd.
            $bodyArgs = $null
            foreach ($f in $files) {
                if (-not $f) { return "gh $sub is given --body-file with no path. Pass the body file's path." }
                if ($f -eq '-') { return "gh $sub reads its body from standard input, which the check cannot read. Pass --body-file <path>." }
                if ($f -match '[$%`]|^~') { return "gh $sub's body file, $f, is named through the shell, which this cannot expand. Write its path in full." }
                $path = if ($IsWindows -and $f -match '^/([a-zA-Z])(/.*)?$') { "$($Matches[1]):$($Matches[2] ?? '/')" } else { $f }
                if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path $Cwd $path }
                if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return "gh $sub's body file, $f, is not there ($path). Write it first, then run gh." }
                Push-Location -LiteralPath $Cwd
                try {
                    if (-not $prose -and $null -eq $bodyArgs) {
                        $bodyArgs = @(Get-CheckArgument -Sub $sub -Rest @($words | Select-Object -Skip ($i + 3)) -CheckArgs $CheckArgs -HeadOf $HeadOf)
                    }
                    $check = if ($prose) { 'markdown-check.ps1 -Body' } else { "pr-body-check.ps1 $($bodyArgs -join ' ')".TrimEnd() }
                    $report = if ($prose) { pwsh -NoProfile -File (Join-Path $PSScriptRoot 'markdown-check.ps1') -Body $path 2>&1 | Out-String }
                    else { pwsh -NoProfile -File (Join-Path $PSScriptRoot 'pr-body-check.ps1') $path @bodyArgs 2>&1 | Out-String }
                }
                finally { Pop-Location }
                if ($LASTEXITCODE -ne 0) { return "gh $sub's body, $f, fails $check. Fix the body and run gh again.`n$($report.TrimEnd())" }
            }
        }
    }
    $null
}

if ($SelfTest) {
    $root = Split-Path $PSScriptRoot -Parent
    # A name without "pr", so the wired case's gh issue command reaches the hook by the wiring's
    # pattern for gh issue, not by its path.
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "refuse-body-$PID"
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $body = "## Summary`n`n{0}`n`n## Evidence`n`n**Before:** none`n`n**After:** none`n`n## Merge Danger`n`n**Door:** none`n`n**Blast Radius:** none`n"
    $good = Join-Path $tmp 'good.md'
    Set-Content -LiteralPath $good -NoNewline -Value ($body -f '    a visual')
    $plain = Join-Path $tmp 'plain.md'
    Set-Content -LiteralPath $plain -NoNewline -Value ($body -f 'No visual.')
    $bad = Join-Path $tmp 'bad.md'
    Set-Content -LiteralPath $bad -NoNewline -Value 'No headings at all.'
    # A comment's or an issue's body: one markdown-check.ps1 -Body passes, and one it fails, for
    # a relative link, which GitHub resolves against the page.
    $note = Join-Path $tmp 'note.md'
    Set-Content -LiteralPath $note -Value 'A plain comment, with [an address](https://example.com/).'
    $linked = Join-Path $tmp 'linked.md'
    Set-Content -LiteralPath $linked -Value 'See [the page](docs/page.md).'
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
        @('gh pr edit 5 -btext', @(), 'inline'),
        @('/usr/bin/gh.exe pr create --body text', @(), 'inline'),
        @('gh pr create --fill', @(), 'no --body-file'),
        @('gh pr create --title t', @(), 'no --body-file'),
        @('gh pr create --body-file $R/x.md', @(), 'in full'),
        @('gh pr create --body-file "$(pwd)/x.md"', @(), 'in full'),
        @('gh pr create --body-file %TEMP%/x.md', @(), 'in full'),
        @('gh pr create --body-file ~/x.md', @(), 'in full'),
        @('gh pr create --body-file -', @(), 'standard input'),
        @('gh pr create --body-file', @(), 'no path'),
        @('gh pr edit 5 --body-file=', @(), 'no path'),
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
        @('gh pr create -h', @(), $null),
        @("gh pr edit 5 --title t; git commit -F `"$bad`"", @(), $null),
        @("gh issue create --title t --body-file `"$linked`"", $visual, 'fails markdown-check\.ps1 -Body'),
        @("gh issue create --title t -F `"$note`"", $visual, $null),
        @("gh pr comment 5 --body-file `"$linked`"", $visual, 'fails markdown-check\.ps1 -Body'),
        @("gh pr comment 5 -F `"$note`"", $visual, $null),
        @("gh issue comment 5 -F`"$linked`"", $visual, 'fails markdown-check\.ps1 -Body'),
        @("gh issue comment 5 --body-file=`"$note`"", $visual, $null),
        @("gh issue comment 5 --body-file=`"$linked`"", $visual, 'fails markdown-check\.ps1 -Body'),
        @('gh issue create --title t --body-file=', @(), 'no path'),
        @('gh pr comment 5 --body-file=', @(), 'no path'),
        @('gh issue comment 5 --body "inline, not seen"', @(), $null),
        @('gh issue create --title t -b text', @(), $null),
        @('gh issue create --title t --body-file $S/x.md', @(), 'in full'),
        @('gh issue comment 5 -F -', @(), 'standard input'),
        @('gh issue comment 5 -F', @(), 'no path'),
        @("gh pr comment 5 --body-file `"$tmp/missing.md`"", @(), 'not there'),
        @('gh issue create --title t', @(), $null),
        @("gh issue view 5; gh issue close 5 --comment x", @(), $null),
        @('gh pr view 5 --json body', @(), $null),
        # Bodies given to subcommands outside the five, which a check would refuse (ruling 2, #386).
        @("gh issue edit 5 --body x; gh pr review 5 -F `"$bad`"", @(), $null),
        @('git status', @(), $null),
        @('', @(), $null)
    )
    $failures = 0
    $n = 0
    $total = $cases.Count + 5
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
    # The head of the pull request a gh pr edit names reaches the check with -CheckRuns, and only
    # then (#455), asked of gh stood in, once, with the edit's selector or none.
    $n++
    $asked = [System.Collections.Generic.List[string]]::new()
    $stub = { param([string] $Selector) $asked.Add("<$Selector>"); 'abc1234def' }
    $runs = '-CiteSiblings', '-CheckRuns'
    $edit = @(Get-CheckArgument -Sub 'pr edit' -Rest @('5', '-F', 'b.md') -CheckArgs $runs -HeadOf $stub)
    $branch = @(Get-CheckArgument -Sub 'pr edit' -Rest @('-F', 'b.md') -CheckArgs $runs -HeadOf $stub)
    $create = @(Get-CheckArgument -Sub 'pr create' -Rest @('-F', 'b.md') -CheckArgs $runs -HeadOf $stub)
    $off = @(Get-CheckArgument -Sub 'pr edit' -Rest @('5') -CheckArgs @('-CiteSiblings') -HeadOf $stub)
    $none = @(Get-CheckArgument -Sub 'pr edit' -Rest @('5') -CheckArgs $runs -HeadOf { })
    $through = Get-PrBodyRefusal -Command "gh pr edit 7 -F `"$good`" -F `"$good`"" -Cwd $root -CheckArgs ($visual + '-CheckRuns') -HeadOf $stub
    # The check itself is given the head: its report on a body it fails says it held the runs to
    # one, where with no head it says it read none. No run is cited, so gh is not asked.
    $failing = "gh pr edit 7 -F `"$bad`""
    $headed = [string] (Get-PrBodyRefusal -Command $failing -Cwd $root -CheckArgs @('-CheckRuns') -HeadOf { 'abc1234def' })
    $headless = [string] (Get-PrBodyRefusal -Command $failing -Cwd $root -CheckArgs @('-CheckRuns') -HeadOf { })
    $ok = ($edit -join ' ') -ceq '-CiteSiblings -CheckRuns -Head abc1234def' -and ($branch -join ' ') -ceq '-CiteSiblings -CheckRuns -Head abc1234def' -and
        ($create -join ' ') -ceq '-CiteSiblings -CheckRuns' -and ($off -join ' ') -ceq '-CiteSiblings' -and ($none -join ' ') -ceq '-CiteSiblings -CheckRuns' -and
        -not $through -and ($asked -join ' ') -ceq '<5> <> <7>' -and
        $headed -match 'problem\(s\) with the cited runs' -and $headed -notmatch 'No head was given' -and $headless -match 'No head was given'
    if (-not $ok) { Write-Host "    $($edit -join ' ') | $($branch -join ' ') | $($create -join ' ') | $($off -join ' ') | $($none -join ' ') | $through | $($asked -join ' ') | $headed | $headless" }
    Write-Host ("self-test {0}/{1}: gh pr edit with -CheckRuns hands the check -Head and the head gh names for the pull request it names, asked once, and the check is run with it; gh pr create, a wiring without -CheckRuns and a head gh cannot name hand none -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
    if (-not $ok) { $failures++ }
    Pop-Location
    # The wiring as the session runs it: the command the settings file wires for this script,
    # through sh, with the tool call on stdin. Exit 2 and the reason for an inline body and for an
    # issue's body file the check fails, so the wiring hands it gh issue commands; exit 0 and
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
        param($command, $cwd = $root)
        $text = (@{ tool_input = @{ command = $command }; cwd = $cwd } | ConvertTo-Json -Compress) | & $sh -c $wired 2>&1 | Out-String
        @{ Code = $LASTEXITCODE; Text = $text }
    }
    if (-not $wired) { $ok = $false; Write-Host "    $Settings wires no command that names this script" }
    else {
        $refused = & $through 'gh pr create --body text'
        # Run from the temporary folder, with cwd '.' and the file by its name, so the input holds
        # no path, and no clone's or user's path can match the wiring's pattern for gh pr instead.
        Push-Location -LiteralPath $tmp
        try { $issue = & $through 'gh issue create --title t --body-file linked.md' '.' }
        finally { Pop-Location }
        $edit = & $through 'gh pr edit 1 --title t'
        $other = & $through 'git status'
        $ok = $refused.Code -eq 2 -and $refused.Text -match 'Refused' -and $refused.Text -match '--body-file' -and
            $issue.Code -eq 2 -and $issue.Text -match 'Refused: gh issue create''s body' -and
            $edit.Code -eq 0 -and -not $edit.Text.Trim() -and $other.Code -eq 0 -and -not $other.Text.Trim()
        if (-not $ok) { foreach ($r in $refused, $issue, $edit, $other) { Write-Host "    $($r.Code) $($r.Text)" } }
    }
    Remove-Item -LiteralPath $tmp -Recurse -Force
    Write-Host ("self-test {0}/{1}: the wired hook refuses an inline body, and an issue's body file the check fails, with exit 2 and a reason, and passes an edit of the title and a plain command -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
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
    # The first example's form (#358, ADR 0004), read from the header so the command shown is the
    # command run: for a project with no hook script it exits 0 and names the missing path in both
    # fields; for this repository, read from scripts/, it refuses.
    $n++
    $form = [regex]::Match((Get-Content -LiteralPath $PSCommandPath -Raw), 'i=\$\(cat\).*?esac').Value
    $empty = Join-Path ([IO.Path]::GetTempPath()) "hook-form-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -ItemType Directory -Path $empty | Out-Null
    $call = @{ tool_name = 'Bash'; cwd = $empty; tool_input = @{ command = 'gh pr create --body text' } } | ConvertTo-Json -Compress
    $kept = $env:CLAUDE_PROJECT_DIR
    try {
        $env:CLAUDE_PROJECT_DIR = $empty
        $absentText = $call | & $sh -c $form 2>$null | Out-String
        $absentCode = $LASTEXITCODE
        $env:CLAUDE_PROJECT_DIR = Split-Path $PSScriptRoot -Parent
        $hereText = $call | & $sh -c $form.Replace('/vendor/grado-factorio-tools/scripts/', '/scripts/') 2>&1 | Out-String
        $hereCode = $LASTEXITCODE
    }
    finally { Remove-Item -LiteralPath $empty -Recurse -Force; $env:CLAUDE_PROJECT_DIR = $kept }
    $ok = try {
        $told = $absentText | ConvertFrom-Json
        $form -and $absentCode -eq 0 -and $told.hookSpecificOutput.hookEventName -ceq 'PreToolUse' -and
            $told.hookSpecificOutput.additionalContext -match "vendor/grado-factorio-tools/scripts/$names was not found" -and
            $told.systemMessage -ceq $told.hookSpecificOutput.additionalContext -and $hereCode -eq 2
    } catch { $false }
    if (-not $ok) { Write-Host "    absent: $absentCode $absentText"; Write-Host "    here: $hereCode $hereText" }
    Write-Host ("self-test {0}/{1}: the first example's form refuses where the script is, and where it is not exits 0 and prints JSON naming the missing path to the agent -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
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
    [Console]::Error.WriteLine("refuse-pr-body: could not check the command, so it was NOT checked: $($_.Exception.Message)")
    exit 1
}
if ($refusal) {
    [Console]::Error.WriteLine("Refused: $refusal")
    exit 2
}
exit 0
