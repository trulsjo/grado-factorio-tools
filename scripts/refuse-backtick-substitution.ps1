<#
.SYNOPSIS
    A hook for agent sessions: refuses a Bash tool command in which bash would run a backtick
    span as a command substitution. Exit 2 refuses the command before it runs and says to write
    $(...) for a substitution meant to run, or to write text meant to stay literal to a file with
    the Write tool; exit 0 lets it run, and means only that this saw no such backtick. Exit 1
    says on stderr that the tool call could not be read and was not checked; the command still
    runs.

.DESCRIPTION
    WHY (grado-factorio-tools#272). On 2026-10-27, after PRs #270 and #271 were opened, a
    session updated a page with one Bash tool call, `python -I -c "..."`, whose text held
    Markdown code spans in backticks, among them `gh pr create`. Inside double quotes bash runs a
    backtick span, so the call ran `gh pr create` with no arguments, and the page was written
    with the spans' output in place of their text. refuse-pr-body.ps1 was wired and let it
    through; why, in that long command, is not measured.

    HOW IT IS WIRED. In .claude/settings.json, a PreToolUse hook on the two shell tools, matcher
    `Bash|PowerShell`, as refuse-git-hook-skip.ps1 is. This repository's own tracked settings
    wire it as the first example below shows, and a consumer names the script under
    vendor/grado-factorio-tools/ in its own. The session hands the hook the tool call as JSON on
    stdin: this reads `tool_name` and `tool_input.command`. The `case` keeps PowerShell from
    starting before every shell command: whatever is refused holds a backtick.

    WHAT IT REFUSES. Under the Bash tool, a backtick not escaped by a backslash, inside double
    quotes or outside any quotes, and one in the body of a heredoc whose delimiter is unquoted,
    as `<<EOF` or `<<-EOF`, inside `$(...)`, arithmetic `$((...))` and a subshell too. The
    command is read in order, a character at a time, with each `$(...)`, subshell and pair of
    double quotes nested as bash nests them, so an apostrophe inside double quotes opens no
    single-quoted string and one inside `"$(...)"` does. A lone backtick is refused as a span
    is: bash reads it as an unclosed one.

    WHAT IT LETS THROUGH. Every call whose `tool_name` is not `Bash`, in exact case, as the
    PowerShell tool's, where a backtick is the escape character. A backtick inside single
    quotes or `$'...'`; in a `#` comment, from a `#` that starts a word to the line's end; one
    escaped as \` inside double quotes, outside quotes or in an unquoted heredoc's body; one in
    the body of a heredoc whose delimiter is quoted in any part, as <<'EOF', <<"EOF" or <<\EOF,
    also inside `"$(...)"`, as `git commit -m "$(cat <<'EOF' ... EOF )"` writes a message;
    `$(...)`; and every command with no backtick.

    WHAT IT CANNOT SEE. A substitution in a script the command runs, an alias or a function. A
    command run by `sh -c` or `bash -c` with quoting of its own, which is read as the outer
    command's text. A person's own terminal: this is a session's hook. A call with no
    `tool_name` is read as unreadable, exit 1. And whether the settings still reach it, unless
    -SelfTest is run. It does not parse the shell, and where it misreads, it errs either way: a
    `case` pattern's `)` inside `$(...)` ends the `$(...)` early, and `<<` in an arithmetic
    command, as `(( x << 2 ))`, is read as a heredoc. What follows such a misreading may be
    refused where bash runs nothing, or let through where bash runs a span.

    TO CHECK IT, run the second example below.

.PARAMETER SelfTest
    Prove it refuses what it should and lets the rest through, that the wired command reaches
    it for the Bash tool and passes the PowerShell tool's call, and that the matcher beside that
    command starts the hook for the Bash tool and for the PowerShell tool. The cases that run
    the command need sh: the one on the path, or the one Git for Windows ships.

.PARAMETER Settings
    With -SelfTest: the .claude/settings.json read by the cases that run the wired command and
    the one that reads its matcher, with that file's repository as the project. Defaults to
    this repository's own.

.EXAMPLE
    The wired command: the PreToolUse hook in this repository's .claude/settings.json, as HOW IT
    IS WIRED says.

        i=$(cat); case $i in *'`'*) printf '%s' "$i" | pwsh -NoProfile -File "$CLAUDE_PROJECT_DIR/scripts/refuse-backtick-substitution.ps1";; esac

.EXAMPLE
    To check it. The first is refused with exit 2, the second passes with exit 0:

        '{"tool_name":"Bash","tool_input":{"command":"echo \"a `date` b\""}}' | pwsh -NoProfile -File scripts/refuse-backtick-substitution.ps1; $LASTEXITCODE
        '{"tool_name":"Bash","tool_input":{"command":"echo \"a $(date) b\""}}' | pwsh -NoProfile -File scripts/refuse-backtick-substitution.ps1; $LASTEXITCODE
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [switch] $SelfTest,
    [string] $Settings
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-BacktickSubstitution {
    <#  Whether bash, running $Command, would read a backtick in it as a command substitution.  #>
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Command)

    $c = $Command -replace '\r\n', "`n"
    # What the walk is inside, innermost last: '' the command itself, '"' double quotes, '$' a
    # $(...), '(' a subshell, 'A' arithmetic. Single-quoted text and comments are stepped over.
    $stack = [System.Collections.Generic.List[string]]::new()
    $stack.Add('')
    # Heredocs opened on the current line; their bodies follow its newline, in order.
    $heredocs = [System.Collections.Generic.List[hashtable]]::new()
    # Where a backslash escaped a character, and where a subshell's `)` stood: what a `#` after
    # each means differs, as below. -2 is neither yet, and no `$i - 1`.
    $escaped = $subshellEnd = -2
    # Matched from $i, so the command is not copied to match them. The first two are tried only
    # where their quote is at $i; the third, at any `<`, is held there by \G.
    $single = [regex] '''[^'']*''?'
    $ansi = [regex] '\$''(?:\\[\s\S]|[^''\\])*''?'
    $heredoc = [regex] '\G<<(-?)[ \t]*((?:[^\s;&|()<>''"\\]|''[^'']*''|"[^"]*"|\\.)+)'
    $i = 0
    while ($i -lt $c.Length) {
        $ch = $c[$i]
        $in = $stack[-1]
        # At a `$` or `<`, the next three characters, all a StartsWith below reads. Elsewhere no
        # method is called: a copy of the rest per character made the walk quadratic, and a call
        # per character costs as much as the walk (PR #277's second review).
        $rest = $ch -eq '$' -or $ch -eq '<' ? $c.Substring($i, [Math]::Min(3, $c.Length - $i)) : ''
        if ($ch -eq '\') { $escaped = $i + 1; $i += 2; continue }
        if ($ch -eq '`') { return $true }
        if ($rest -and $rest.StartsWith('$((')) { $stack.Add('A'); $stack.Add('A'); $i += 3; continue }
        if ($rest -and $rest.StartsWith('$(')) { $stack.Add('$'); $i += 2; continue }
        if ($in -eq 'A') {
            if ($ch -eq '(') { $stack.Add('A') } elseif ($ch -eq ')') { $stack.RemoveAt($stack.Count - 1) }
            $i++
            continue
        }
        if ($in -eq '"') {
            if ($ch -eq '"') { $stack.RemoveAt($stack.Count - 1) }
            $i++
            continue
        }
        # Unquoted: the command itself, or inside $(...) or a subshell.
        if ($ch -eq "'") { $i += $single.Match($c, $i).Length; continue }
        if ($rest -and $rest.StartsWith('$''')) { $i += $ansi.Match($c, $i).Length; continue }
        if ($ch -eq '"' -or $ch -eq '(') { $stack.Add([string] $ch); $i++; continue }
        if ($ch -eq ')') {
            if ($in -eq '(') { $subshellEnd = $i }
            if ($in -eq '(' -or $in -eq '$') { $stack.RemoveAt($stack.Count - 1) }
            $i++
            continue
        }
        # A comment starts a word: after unescaped blank space or an operator, or a subshell's
        # `)`. After the `)` of $(...) or $((...)), or an escaped space, a `#` is in the word.
        if ($ch -eq '#' -and ($i -eq 0 -or $i - 1 -eq $subshellEnd -or
                ($i - 1 -ne $escaped -and $c[$i - 1] -match '[\s;&|<>(]'))) {
            $end = $c.IndexOf("`n", $i)
            $i = $end -lt 0 ? $c.Length : $end
            continue
        }
        # A here-string, <<<, holds a word, not a body.
        if ($rest -and $rest.StartsWith('<<<')) { $i += 3; continue }
        $m = $ch -eq '<' ? $heredoc.Match($c, $i) : $null
        if ($m -and $m.Success) {
            $heredocs.Add(@{ Strip = [bool] $m.Groups[1].Value; Word = $m.Groups[2].Value })
            $i += $m.Length
            continue
        }
        $i++
        if ($ch -ne "`n") { continue }
        foreach ($h in $heredocs) {
            $quoted = $h.Word -match '[''"\\]'
            $delimiter = $h.Word -replace '[''"\\]', ''
            while ($i -lt $c.Length) {
                $end = $c.IndexOf("`n", $i)
                if ($end -lt 0) { $end = $c.Length }
                $line = $c.Substring($i, $end - $i)
                $i = $end + 1
                if (($h.Strip ? $line.TrimStart("`t") : $line) -ceq $delimiter) { break }
                if (-not $quoted -and $line -match '(?<!\\)(?:\\\\)*`') { return $true }
            }
        }
        $heredocs.Clear()
    }
    $false
}

if ($SelfTest) {
    # Each: the command, and whether it is refused.
    $cases = @(
        @('python -I -c "x = `echo hi`"', $true),
        @('python -I -c "Truls''s `gh pr create`"', $true),
        @('echo `date`', $true),
        @('echo "a ` b"', $true),
        @("cat <<EOF`nnow: ``date```nEOF", $true),
        @("cat <<-EOF`n`tnow: ``date```n`tEOF", $true),
        @("cat <<'EOF'`n``x```nEOF`necho ``date``", $true),
        @('cat <<< "`date`"', $true),
        @('echo "a \\`date`"', $true),
        @("cat <<-'EOF'`n`t``x```n`tEOF`necho ``date``", $true),
        @("cat <<'EOF'`nx`nEOF`necho ok`necho ``date``", $true),
        @("cat <<'EOF'`r`nx`r`nEOF`r`necho ``date``", $true),
        @("cat <<'EOF'`neof`n``date```nEOF", $false),
        @("cat <<EOF '``x``'`nbody`nEOF", $false),
        @("git commit -m `"`$(cat <<'EOF'`nsee ``x```nEOF`n)`"", $false),
        @("echo `"`$(cat <<EOF`nsee ``date```nEOF`n)`"", $true),
        @('echo "$(echo ''`x`'')"', $false),
        @('echo "$(echo "it''s")" `date`', $true),
        @('x="$( (cd a) && echo ''"'' )" `date`', $true),
        @('echo "$(echo $(( (1) )); echo ''`x`'')"', $false),
        @('echo $((1 << 2)) ''`x`''', $false),
        @('echo $(( `date` ))', $true),
        @("echo hi # don't`necho ``date``", $true),
        @("# see <<'EOF'`necho ``date``", $true),
        @('echo hi # a `x` b', $false),
        @('echo a#b `date`', $true),
        @('echo $''it\''s'' `date`', $true),
        @('echo $''a `b`''', $false),
        @("cat <<'EOF'`n``x``", $false),
        @("cat << 'EOF'`n``x```nEOF", $false),
        @("cat << EOF`nit's`nEOF`necho ``date``", $true),
        @("echo `$((1 << 2))`necho '``x``'", $false),
        @('echo "$(( 1 )) ''`x`''"', $true),
        @('echo "a" ''`x`''', $false),
        @('echo "$( (echo a) )" ''`x`''', $false),
        @('echo $(echo a)#b `date`', $true),
        @('echo $((1))#b `date`', $true),
        @('echo a\ #b `date`', $true),
        @('(echo a)#b `date`', $false),
        @("echo a;# it's`necho ``date``", $true),
        @("echo `$(# it's`necho ``date``)", $true),
        @("true &# it's`necho ``date``", $true),
        @("echo a |# it's`ncat; echo ``date``", $true),
        @('echo a >#b `date`', $false),
        @('case a in a) echo;; b) echo `date`;; esac', $true),
        @('echo it''s `date`', $false),
        @('echo $''it `date`', $false),
        @("cat < f <<'EOF'`n``x```nEOF`necho ``date``", $true),
        @('echo ''`date`''', $false),
        @('echo "a \` b"', $false),
        @('echo a \` b', $false),
        @("cat <<'EOF'`n``date```nEOF", $false),
        @("cat <<`"EOF`"`n``date```nEOF", $false),
        @("cat <<\EOF`n``date```nEOF", $false),
        @("cat <<EOF`nnot \``x\`` here`nEOF", $false),
        @('cat <<< ''`date`''', $false),
        @('echo "$(date)"', $false),
        @('git status', $false),
        @('', $false)
    )
    $failures = 0
    $n = 0
    $total = $cases.Count + 4
    foreach ($c in $cases) {
        $n++
        $ok = (Test-BacktickSubstitution -Command $c[0]) -eq $c[1]
        Write-Host ("self-test {0}/{1}: {2}: {3} -- {4}" -f $n, $total, $(if ($c[1]) { 'refused' } else { 'allowed' }), ($c[0] -replace '\r?\n', '\n'), $(if ($ok) { 'ok' } else { 'FAILED' }))
        if (-not $ok) { $failures++ }
    }
    # The wiring as the session runs it: the command the settings file wires for this script,
    # through sh, with the tool call on stdin.
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
        param($tool, $command)
        $text = (@{ tool_name = $tool; tool_input = @{ command = $command } } | ConvertTo-Json -Compress) | & $sh -c $wired 2>&1 | Out-String
        @{ Code = $LASTEXITCODE; Text = $text }
    }
    # The incident's shape, through the wiring: exit 2 and the reason, and nothing else printed,
    # so nothing ran; a plain command passes in silence.
    $n++
    if (-not $wired) { $ok = $false; Write-Host "    $Settings wires no command that names this script" }
    else {
        $refused = & $through 'Bash' 'python -I -c "Truls''s `gh pr create`"'
        $plain = & $through 'Bash' 'git status'
        $ok = $refused.Code -eq 2 -and $refused.Text -match '^Refused' -and $refused.Text -match '\$\(\.\.\.\)' -and
            $refused.Text -match 'Write tool' -and $plain.Code -eq 0 -and -not $plain.Text.Trim()
        if (-not $ok) { foreach ($r in $refused, $plain) { Write-Host "    $($r.Code) $($r.Text)" } }
    }
    Write-Host ("self-test {0}/{1}: the wired hook refuses the incident's command with exit 2 and a reason, and passes a plain one -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
    if (-not $ok) { $failures++ }
    # The PowerShell tool's backtick is its escape character: passed through the wiring.
    $n++
    if (-not $wired) { $ok = $false }
    else {
        $ps = & $through 'PowerShell' 'Write-Output "a`tb"'
        $lower = & $through 'bash' 'echo `date`'
        $ok = $ps.Code -eq 0 -and -not $ps.Text.Trim() -and $lower.Code -eq 0 -and -not $lower.Text.Trim()
        if (-not $ok) { foreach ($r in $ps, $lower) { Write-Host "    $($r.Code) $($r.Text)" } }
    }
    Write-Host ("self-test {0}/{1}: the wired hook passes a PowerShell tool call holding a backtick, and a tool named bash in other case -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
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
    $refuse = $call.tool_name -ceq 'Bash' -and (Test-BacktickSubstitution -Command ([string] $call.tool_input.command))
}
catch {
    # Loud, and not a refusal: a hook that cannot read its input must not stop every command.
    [Console]::Error.WriteLine("refuse-backtick-substitution: could not read the tool call, so the command was NOT checked: $($_.Exception.Message)")
    exit 1
}
if ($refuse) {
    [Console]::Error.WriteLine(@"
Refused: bash would run a backtick span in this command as a command substitution, inside
double quotes, outside quotes or in an unquoted heredoc's body. For a substitution meant to
run, write `$(...). For text meant to stay literal, as Markdown code spans, write it to a file
with the Write tool and pass the file.
"@)
    exit 2
}
exit 0
