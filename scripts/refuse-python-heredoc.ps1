<#
.SYNOPSIS
    A hook for agent sessions: refuses a shell command that runs Python with its script read
    from a heredoc. Exit 2 refuses the command before it runs and says to write the script to a
    file, with raw strings, and run that, or to use the Edit tool; exit 0 lets it run, and means
    only that this saw no such command. Exit 1 says on stderr that the tool call could not be
    read and was not checked; the command still runs.

.DESCRIPTION
    WHY (grado-factorio-tools#240). In the session of PRs #235 to #238, 51 shell calls ran
    `python - <<'PYEOF'`, and 16 of them printed `SyntaxWarning: invalid escape sequence`: a
    Python string, not raw, holding a PowerShell or regex backslash. One such edit halved a
    regex's backslashes, by that session's account. Python reads a string that is not raw the
    same way from a file, so the refusal asks for raw strings too. What a file adds: it can be
    read back, grepped and run again, which a heredoc's script cannot. And under the Bash tool a
    heredoc holding quotes has failed to parse, and `python -` reading one has hung, by Truls's
    agent memory (2026-10-08 to 2026-10-18). The Edit tool needs no script at all.

    HOW IT IS WIRED. In .claude/settings.json, a PreToolUse hook on the two shell tools, matcher
    `Bash|PowerShell`, as refuse-git-hook-skip.ps1 is. This repository's own tracked settings
    wire it as the first example below shows, and a consumer names the script under
    vendor/grado-factorio-tools/ in its own. The session hands the hook the tool call as JSON on
    stdin: this reads `tool_input.command`. The `case` keeps PowerShell from starting before
    every shell command: whatever is refused holds `py` and `<<`.

    WHAT IT REFUSES. A command in which the word `python`, with a version as `python3.12` or
    none, `pythonw` or `py`, alone or at the end of a path, with or without `.exe`, is followed
    by a heredoc, `<<` or `<<-`, before the command ends, and by no script before it: its other
    words are options, `-`, or an output redirection, as `2>&1` or `> out.txt`. An option that takes
    the next word as its value, -W, -X or -Q, is read with it. Every word of a command is read, so a
    word before Python, as `env`, `exec`, `sudo` or a variable set for it, does not hide it.

    WHAT IT LETS THROUGH. `python -c` and `python -m`, alone or after switches that take no
    value, as -Imjson.tool, whose code is their argument and not the heredoc; `python <file>`,
    with or without a heredoc, which is then the script's input; a script on stdin from a file,
    `python - < edit.py`; a here-string, `<<<`, which holds one line; and every command with no
    Python in it.

    WHAT IT CANNOT SEE. A heredoc piped into Python, as `cat <<EOF | python -`, and Python
    started from a script, an alias, a variable or inside a quoted string, as `sh -c`. A
    here-string piped to Python under the PowerShell tool, @' '@ | python -. Other interpreters
    reading a heredoc, as `node` and `perl` do. A person's own terminal: this is a session's
    hook. And whether the settings still reach it, unless -SelfTest is run, which reads the
    wired command and the matcher of its entry, and nothing else of the settings. It reads the
    command as text and does not parse the shell, and so does not skip a heredoc's body. That
    errs towards refusing where a body's line reads `python - <<EOF`, and the other way where a
    body holds a lone apostrophe, as `it's`: the quote it opens runs to the next one, and a
    Python heredoc after it is read as quoted text and let through.

    TO CHECK IT, run the second example below.

.PARAMETER SelfTest
    Prove it refuses what it should and lets the rest through, that the wired command
    reaches it, and that the matcher beside that command starts the hook for the Bash tool and
    for the PowerShell tool. The case that runs the command needs sh: the one on the path, or
    the one Git for Windows ships.

.PARAMETER Settings
    With -SelfTest: the .claude/settings.json read by the case that runs the wired command and
    the one that reads its matcher, with that file's repository as the project. Defaults to
    this repository's own. They take the first command, of any PreToolUse entry, that names this
    script, as refuse-git-hook-skip.ps1's do.

.EXAMPLE
    The wired command: the PreToolUse hook in this repository's .claude/settings.json, as HOW IT
    IS WIRED says.

        i=$(cat); case $i in *py*'<<'*) printf '%s' "$i" | pwsh -NoProfile -File "$CLAUDE_PROJECT_DIR/scripts/refuse-python-heredoc.ps1";; esac

.EXAMPLE
    To check it. The first is refused with exit 2, the second passes with exit 0:

        '{"tool_input":{"command":"python - <<EOF\nprint(1)\nEOF"}}' | pwsh -NoProfile -File scripts/refuse-python-heredoc.ps1; $LASTEXITCODE
        '{"tool_input":{"command":"python -I edit.py"}}' | pwsh -NoProfile -File scripts/refuse-python-heredoc.ps1; $LASTEXITCODE
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [switch] $SelfTest,
    [string] $Settings
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-PythonHeredoc {
    <#  Whether $Command runs Python with its script read from a heredoc.  #>
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Command)

    # Words and the marks that end a command, as refuse-git-hook-skip.ps1's Test-SkipsHooks reads
    # them, with a heredoc's `<<` made a word of its own first, so `python -<<EOF` is read too,
    # and each output redirection taken out with its target, so `2>&1` neither ends the command
    # at its `&` nor reads as a script.
    $text = ($Command -replace '[\\`]\r?\n', ' ') -replace '(?<!<)<<(?!<)', ' << ' -replace
        '(?:\d*|&)>>?\s*(?:&[\d-]|[^\s''"`;&|()<>]+)', ' '
    $tokens = [regex]::Matches($text,
        '(?<word>(?:"(?:[\\`].|[^"\\`])*"|''[^'']*''|[^\s;&|(){}`"''])+)|(?<end>[;&|(){}`\n])')
    $commands = @(, [System.Collections.Generic.List[string]]::new())
    foreach ($t in $tokens) {
        if ($t.Groups['end'].Success) { $commands += , [System.Collections.Generic.List[string]]::new() }
        else { $commands[-1].Add(($t.Value -replace '["'']', '')) }
    }

    foreach ($words in $commands) {
        for ($i = 0; $i -lt $words.Count; $i++) {
            if ($words[$i] -notmatch '^(?:.*[\\/])?(?:python[\d.]*w?|py)(?:\.exe)?$') { continue }
            for ($j = $i + 1; $j -lt $words.Count; $j++) {
                $w = $words[$j]
                if ($w -match '^<<(?!<)') { return $true }
                # A script, or code given as an argument, alone or after a cluster of switches
                # that take no value: the heredoc, if any, is its input.
                if ($w -cmatch '^-[bBdEhiIOPqsSuvVx]*[cm]' -or $w -notmatch '^-') { break }
                # An option whose value is the next word.
                if ($w -cmatch '^-[WXQ]$') { $j++ }
            }
        }
    }
    $false
}

if ($SelfTest) {
    # Each: the command, and whether it is refused.
    $cases = @(
        @("python - <<'PYEOF'`nprint(1)`nPYEOF", $true),
        @("python3 - <<'EOF'`nprint(1)`nEOF", $true),
        @("python3 <<EOF`nprint(1)`nEOF", $true),
        @("py -3 - <<EOF`nprint(1)`nEOF", $true),
        @("python -I - <<'EOF'`nprint(1)`nEOF", $true),
        @("python -X utf8 - <<EOF`nprint(1)`nEOF", $true),
        @("python -<<EOF`nprint(1)`nEOF", $true),
        @("python - <<-EOF`n`tprint(1)`n`tEOF", $true),
        @("/usr/bin/python3 - <<EOF`nprint(1)`nEOF", $true),
        @("`"C:/Program Files/Python313/python.exe`" - <<EOF`nprint(1)`nEOF", $true),
        @("cd docs && python - <<'EOF'`nprint(1)`nEOF", $true),
        @("git add a && python3 - <<'EOF' && git status`nprint(1)`nEOF", $true),
        @("out=`$(python - <<'EOF'`nprint(1)`nEOF`n)", $true),
        @("echo hi; python <<EOF`nprint(1)`nEOF", $true),
        @("python - 2>&1 <<'EOF'`nprint(1)`nEOF", $true),
        @("python3 - 2>/dev/null <<'EOF'`nprint(1)`nEOF", $true),
        @("python - > out.txt <<'EOF'`nprint(1)`nEOF", $true),
        @("python3.12 - <<'EOF'`nprint(1)`nEOF", $true),
        @("env PYTHONIOENCODING=utf-8 python - <<'EOF'`nprint(1)`nEOF", $true),
        @("exec python3 - <<'EOF'`nprint(1)`nEOF", $true),
        @('python -I edit.py', $false),
        @('python3 -I C:/scratch/edit.py arg', $false),
        @("python edit.py <<EOF`ninput`nEOF", $false),
        @('python -c "print(1)"', $false),
        @("python3 -c 'import sys; print(sys.argv)' <<EOF`nx`nEOF", $false),
        @("python -m json.tool <<EOF`n{}`nEOF", $false),
        @("python -Imjson.tool <<EOF`n{}`nEOF", $false),
        @("python -Xfrozen_modules=off - <<EOF`nprint(1)`nEOF", $true),
        @("cat <<'EOF' > notes.md`nInstall py`n- << starts a heredoc`nEOF", $false),
        @('python3 <<< "print(1)"', $false),
        @('python - < edit.py', $false),
        @("cat <<EOF > notes.txt`nline`nEOF", $false),
        @("gh issue create --body `"never run python - <<EOF`"", $false),
        @("pythonic - <<EOF`nx`nEOF", $false),
        @('pwsh -NoProfile -File scripts/check.ps1', $false),
        @('', $false)
    )
    $failures = 0
    $n = 0
    $total = $cases.Count + 3
    foreach ($c in $cases) {
        $n++
        $ok = (Test-PythonHeredoc -Command $c[0]) -eq $c[1]
        Write-Host ("self-test {0}/{1}: {2}: `{3}` -- {4}" -f $n, $total, $(if ($c[1]) { 'refused' } else { 'allowed' }), ($c[0] -replace '\r?\n', '\n'), $(if ($ok) { 'ok' } else { 'FAILED' }))
        if (-not $ok) { $failures++ }
    }
    # The wiring as the session runs it: the command the settings file wires for this script,
    # through sh, with the tool call on stdin. Exit 2 and the reason for a heredoc, exit 0 and
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
        $refused = & $through "python - <<'EOF'`nprint(1)`nEOF"
        $file = & $through 'python -I edit.py'
        $plain = & $through 'git status'
        $ok = $refused.Code -eq 2 -and $refused.Text -match 'Refused' -and $refused.Text -match 'Write tool' -and
            $file.Code -eq 0 -and -not $file.Text.Trim() -and $plain.Code -eq 0 -and -not $plain.Text.Trim()
        if (-not $ok) { foreach ($r in $refused, $file, $plain) { Write-Host "    $($r.Code) $($r.Text)" } }
    }
    Write-Host ("self-test {0}/{1}: the wired hook refuses Python from a heredoc with exit 2 and a reason, and passes a script file and a plain command -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
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
    $refuse = Test-PythonHeredoc -Command ([string] ([Console]::In.ReadToEnd() | ConvertFrom-Json).tool_input.command)
}
catch {
    # Loud, and not a refusal: a hook that cannot read its input must not stop every command.
    [Console]::Error.WriteLine("refuse-python-heredoc: could not read the tool call, so the command was NOT checked: $($_.Exception.Message)")
    exit 1
}
if ($refuse) {
    [Console]::Error.WriteLine(@"
Refused: this command runs Python with its script read from a heredoc, which cannot be read
back or run again. Write the script to a file with the Write tool and run python -I <file>, or
make the change with the Edit tool. Write each regex and path as a raw string, r'...': in a
string that is not raw, Python changes a backslash escape, from a file as from a heredoc.
"@)
    exit 2
}
exit 0
