<#
.SYNOPSIS
    A hook for agent sessions: refuses a Bash tool command that would hang on its input, that
    holds a heredoc of over 60 lines, or, on Windows, that holds two backslashes in a row. Exit 2
    refuses the command before it runs and says why; exit 0 lets it run, and means only that this
    saw none of the three. Exit 1 says on stderr that the tool call could not be read and was not
    checked; the command still runs.

.DESCRIPTION
    WHERE IT CAME FROM (grado-factorio-tools#352, #322 rulings 2 to 5). realistic-fusion-refreshed's
    tools/refuse-hanging-bash.py at b8b6d89, read 2026-11-06, ported to PowerShell like every other
    shared hook; the one line changed since, at 295ec86, is in its docstring. Its --self-test cases
    are -SelfTest's, with one fixture's mod name made generic. What changed in the port: it is wired
    for both shell tools behind a `case`, and passes a call whose `tool_name` is not `Bash`; the
    refusal log is the consumer's, not the script's repository's; and -SelfTest runs the wiring.
    Below, rf is realistic-fusion-refreshed, and a ticket with no repository named is this one's.

    WHAT HANGS, reproduced on 2026-10-09 under Git Bash on Windows with Python 3.13.14
    (realistic-fusion-refreshed#645): a command left reading the tool's stdin, a pipe nobody closes,
    so a bare `cat` never sees its end (`timeout 8 cat` was still running after 40 s); and
    `python -` or a bare `python` with stdin from /dev/null, which starts the interactive prompt,
    fails on the console's size and tries again without end: two runs of 8 s wrote 12.7 MB of
    traceback between them. Why it takes /dev/null for a console was not established. A heredoc is
    not what hangs: `python - <<'PY'` with a body holding both kinds of quote ran and exited 0, and
    so did `cat <<'X'` with an empty body. Of the three commands realistic-fusion-refreshed#645
    records, the two that ran to the timeout each held a bare `cat` in front of the heredoc, or a
    `< /dev/null` after it, which replaces the heredoc as stdin.

    WHAT IS REFUSED, each simple command of the line judged by itself. `cat` with no file operand,
    when nothing feeds it: no pipe into it, no `<`, no heredoc and no here-string. Python given `-`
    for its script, or given no script and no `-c` or `-m`, when nothing feeds it or when the LAST
    thing redirected into it is /dev/null; an option that prints and exits (`--version`, `-V`,
    `-h`, any option of two hyphens and a name, the launcher's `-0`) counts as a script. A pipe
    feeds the command after it, on the same line or on the next. A pipe into a group, `| {` or
    `| (`, is taken to feed every command after it, to the end of the whole command, the group's
    end not being tracked.

    WHAT IS LET THROUGH ON PURPOSE. `<<` inside a quoted argument: quoted text is blanked before
    anything is looked for, so `echo "a << b"` holds no heredoc and no command of its own. A
    here-string, `<<<`, which feeds a line and ends. A heredoc of $HEREDOC_LINES lines or fewer
    that feeds the command; on Windows it is refused all the same when the command holds a pair of
    backslashes.

    A LONG HEREDOC IS REFUSED TOO (realistic-fusion-refreshed#666), though it does not hang: one
    whose body is over $HEREDOC_LINES lines, 60, counted without the line that ends it. The trouble
    a heredoc has is a body cut short on a quote, `unexpected EOF while looking for matching '`,
    after which nothing runs. A session told to write such a file with the Write tool sent nine Bash
    commands holding a heredoc on 2026-10-09 all the same. LENGTH DOES NOT PREDICT THAT FAILURE: of
    those nine, the one whose longest body was 129 lines, in a command of 132, was cut short, and
    the one of 121, in a command of 124, ran; the other seven, of 34 lines or fewer, ran. So the 60
    is not where heredocs start to fail. It is rf's tracker page's record of the earlier ones,
    "Every command that failed ran past 60 lines", taken as the size past which a body is a file and
    is written as one; kept at 60 by #322 ruling 3. It refuses long heredocs that would have worked.

    A PAIR OF BACKSLASHES IS REFUSED ON WINDOWS (realistic-fusion-refreshed#682, decided by Truls on
    2026-10-12): any command that holds two backslashes in a row, anywhere in it. Such a command
    does not hang. It runs as something other than what was written, because a Bash tool command
    there loses one backslash of every two before bash runs it. Reproduced on 2026-10-11 with GNU
    bash 5.1.16 (msys), each row run as a Bash tool command and read from the session's transcript:

        in the command as sent                                  what the program received
        `A\\\\B` as a line of a `<<'EOF'` heredoc, 4 backslashes  2 backslashes
        `echo 'Z\\Z'`                                            `Z\Z`
        `echo 'a\\\b'`                                           `a\\b`
        `echo 'a\b'`                                             `a\b`, unchanged

    So a pair becomes one and a lone backslash is kept, inside single quotes and a quoted heredoc
    alike, neither of which bash itself touches. A file written with the Write tool is not changed.
    Where it happens, read on 2026-10-12: between the Windows command line and bash's arguments.
    The command line of the bash process held both backslashes of `: 'MARK\\MARK'`, and its
    /proc/$$/cmdline held one. anthropics/claude-code#85856 gives the cause: the command line is
    quoted by the Microsoft C runtime's rules and Git Bash decodes it by its own, so n backslashes
    arrive as ceil(n/2). The test is made on the command as sent and has no exemptions, so three
    shapes are refused though they would run as written: a pair directly before a double quote,
    which is not halved (`echo 'p\\"q'` printed `p\\"q`); a pair inside double quotes, which bash
    halves itself, so the result is what any shell gives; and a pair in a `#` comment. Of 4 315
    Bash tool commands in rf's transcripts on 2026-10-12, 58 held a pair, and one of the 58 had
    its pairs only in the first shape. The PowerShell tool keeps a pair: `Write-Output 'Z\\Z'`
    printed `Z\\Z`, so this passes every call whose `tool_name` is not `Bash`.

    IT IS OFF ON ANY OTHER PLATFORM. The pair is a reason only where $IsWindows is true; under WSL
    or on Linux nothing is halved. -SelfTest judges the cases with it on wherever it runs, so CI's
    Linux runner proves it too. NOTHING RETIRES THIS RULE BUT A PERSON. If Claude Code or Git Bash
    stops halving, every refusal of a pair is a false one. Read anthropics/claude-code#85856
    first. Then take this hook out of the settings for one command and run `echo 'Z\\Z'` as a Bash
    tool command: `Z\Z` means the halving holds.

    HOW A CONSUMER WIRES IT. In its tracked .claude/settings.json, a PreToolUse hook on the two
    shell tools, matcher `Bash|PowerShell`, whose command is the first example below: a `case` on
    `cat`, `py`, `<<` and a backslash, since whatever is refused holds one of them. The tool call
    reaches sh as JSON, which writes a backslash of the command as `\\` but a quote as `\"` and a
    line break as `\n`, so the arm is eight backslashes in quotes: halved, as the shell halves it
    on Windows, four, a pair of the command's; not halved, eight, which a pair is not, and off
    Windows a pair is no reason. The `case` reads only what follows `"tool_input"`: before it
    stand the session's `cwd` and `transcript_path`, which on Windows are paths of `\\`. A
    PowerShell tool call, which the script passes unread, exits before it. Each start of pwsh
    took 1.7 to 4.9 s in five runs on 2026-11-11, and a wider arm, or one that read the paths,
    started it on every call (PR #420's review follow-up). Where the
    script is not there, the wired command lets the shell command run and prints JSON that tells
    the agent it was not checked. It also git-ignores `.claude/refused-bash.log`, below; its
    -SelfTest -Settings fails where git does not ignore that file. This repository wires it from
    scripts/.

    WHAT IS KEPT (realistic-fusion-refreshed#660). Each refusal appends one line of JSON to
    `.claude/refused-bash.log` under $CLAUDE_PROJECT_DIR, the consumer's root (under this repository
    where that is not set): the time, the reason and the command. It is where a false refusal is
    counted from: read the commands there and see which would not have hung, which heredoc would
    have run, or which pair of backslashes was in one of the three shapes that run as written. A
    command let through writes nothing, so a false pass is not in it. A log that cannot be written
    is passed over, and the call is refused just the same.

    WHAT IT CANNOT SEE. Any other reader: only `cat` and Python are known, the two that hung. A
    bare `grep pattern`, `sort` or `jq .` waits the same way; add a reader here when one hangs,
    with what counts as its file operand. A command inside double quotes, `"$(cat)"`, or handed to
    `bash -c '...'`: quoted text is blanked, and a heredoc there is not counted either, however
    long. Where a double-quoted span ends when it holds a `$(...)` with quotes of its own: it is
    taken to end at the first inner `"`, so the rest of such a line is read as commands, and a
    heredoc body inside it with a line opening with `cat` or `python -` is a false refusal. A
    shift inside arithmetic, `$(( 1 << 3 ))`, taken for a heredoc. A reader that is the first
    command of a loop's body, straight after `do`, which is not judged; a later one is, and a
    `cat` there is refused although the loop feeds it. A reader anywhere after a group that a pipe
    fed. A reader behind a wrapper other than the few it skips, or behind a shell function;
    `timeout` is skipped with its `-s` and `-k` values only. A command that hangs for any reason
    other than its stdin. A person's own terminal: this is a session's hook.

    TO CHECK IT, run the second example below.

.PARAMETER SelfTest
    Prove it judges each of rf's cases as wanted; that a case whose reading throws, by a stand-in
    for Get-HangReason, is failed with its threw: line and the cases after it run, and that the
    stand-in is gone after them (#431); that a pass of ConvertTo-Blanked's walk that leaves its
    index where it was throws, naming the index, on a copy made to stall, run in a pwsh of its own
    and given 30 s before it is killed (#421); that a refusal is logged once, a pass not at all, and
    a log that cannot be written refuses all the same; that a pair is the reason on Windows only,
    after a hang and before a long heredoc; that the wired command refuses for the Bash tool, passes
    the PowerShell tool's call and an unreadable one with exit 1, refuses a lone pair on Windows,
    and is started by a pair but not by quotes, line breaks, the paths of a call's `cwd`, one
    backslash or a PowerShell call; that the first example's cases are the wired one's; that the
    first example's form, where the project has no hook script, exits 0 and prints JSON telling the
    agent; that the matcher of the wired entry starts it for both shell tools; and that git ignores
    the settings' repository's .claude/refused-bash.log. The run fails where the cases it reported
    are not the total it names (#431). The wired cases need git and sh: the one on the path, or the
    one Git for Windows ships.

.PARAMETER Settings
    With -SelfTest: the .claude/settings.json whose PreToolUse command naming this script the
    wired cases run, with that file's repository as the project. Defaults to this repository's
    own. A consumer runs it on its own file to know its wiring still reaches the hook and its log
    is ignored.

.EXAMPLE
    The wired command: the PreToolUse hook a consumer puts in its .claude/settings.json, as HOW A
    CONSUMER WIRES IT says. Its .gitignore gains the line `/.claude/refused-bash.log`.

        i=$(cat); case ${i%%'"tool_input"'*} in *'"tool_name"'*'"PowerShell"'*) exit 0;; esac; c=${i#*'"tool_input"'}; case $c in *cat*|*py*|*'<<'*|*'\\\\\\\\'*) h="$CLAUDE_PROJECT_DIR/vendor/grado-factorio-tools/scripts/refuse-hanging-bash.ps1"; if [ -f "$h" ]; then printf '%s' "$i" | pwsh -NoProfile -File "$h"; else m='refuse-hanging-bash: vendor/grado-factorio-tools/scripts/refuse-hanging-bash.ps1 was not found, so this command was NOT checked by the hanging-bash hook. git submodule update --init fetches the script.'; printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}' "$m" "$m"; fi;; esac

.EXAMPLE
    To check it. The first is refused with exit 2, the second passes with exit 0:

        '{"tool_name":"Bash","tool_input":{"command":"git log | head; cat"}}' | pwsh -NoProfile -File scripts/refuse-hanging-bash.ps1; $LASTEXITCODE
        '{"tool_name":"Bash","tool_input":{"command":"git log | cat"}}' | pwsh -NoProfile -File scripts/refuse-hanging-bash.ps1; $LASTEXITCODE
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [switch] $SelfTest,
    [string] $Settings
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Skipped in front of a command's name. Not `do`: see WHAT IT CANNOT SEE.
$WRAPPERS = 'time', 'nohup', 'command', 'exec', 'env', 'winpty', 'then', 'else', 'if', 'elif', '!'
$PYTHON = '^(?:python[\d.]*|py)(?:\.exe)?$'
# A redirect's target ends at an operator, as at a space.
$WORD = '[^\s;&|()<>]+'
$FEED = '<<<\s*' + $WORD + '|<<H|\d*<\s*(?!<)' + $WORD
$NULLS = '/dev/null', 'nul', 'NUL'
# Two backslashes in a row: halved before bash runs the command.
$PAIR = '\\'
# The longest heredoc body let through; the header says why 60.
$HEREDOC_LINES = 60
$HEREDOC = [regex] '\G<<(-?)\s*(?:\\|([''"]))?([\w.-]+)(?(2)\2)'

function ConvertTo-Blanked {
    <#  $Command with each quoted span turned into the word Q, each heredoc into `<<H` with its
        body dropped, and comments gone: what is left can be split on shell operators. Each
        heredoc body's count of lines is added to $Bodies.  #>
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Command,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.Generic.List[int]] $Bodies
    )
    $out = [System.Text.StringBuilder]::new()
    $pending = [System.Collections.Generic.List[object]]::new()
    $i = 0
    $n = $Command.Length
    while ($i -lt $n) {
        $was = $i
        $c = $Command[$i]
        if ($c -eq '\' -and $i + 1 -lt $n) { [void] $out.Append('Q'); $i += 2 }
        elseif ($c -eq "'") {
            $end = $Command.IndexOf("'", $i + 1)
            $i = $end -lt 0 ? $n : $end + 1
            [void] $out.Append('Q')
        }
        elseif ($c -eq '"') {
            $i++
            while ($i -lt $n -and $Command[$i] -ne '"') { $i += $Command[$i] -eq '\' ? 2 : 1 }
            $i++
            [void] $out.Append('Q')
        }
        # Compared in place: a copy of the rest per character would make the walk quadratic.
        elseif ($c -eq '<' -and [string]::CompareOrdinal($Command, $i, '<<<', 0, 3) -eq 0) { [void] $out.Append(' <<< '); $i += 3 }
        elseif ($c -eq '<' -and [string]::CompareOrdinal($Command, $i, '<<', 0, 2) -eq 0) {
            $m = $HEREDOC.Match($Command, $i)
            if (-not $m.Success) { [void] $out.Append('<<'); $i += 2 }
            else {
                $pending.Add(@{ Word = $m.Groups[3].Value; Tabs = [bool] $m.Groups[1].Value })
                [void] $out.Append(' <<H ')
                $i += $m.Length
            }
        }
        elseif ($c -eq "`n" -and $pending.Count) {
            # The bodies start on the next line, in the order their heredocs were opened.
            $i++
            foreach ($p in $pending) {
                $lines = 0
                while ($i -lt $n) {
                    $end = $Command.IndexOf("`n", $i)
                    if ($end -lt 0) { $end = $n }
                    # A command sent with CRLF line ends.
                    $line = $Command.Substring($i, $end - $i).TrimEnd("`r")
                    $i = [Math]::Min($end + 1, $n)
                    if (($p.Tabs ? $line.TrimStart("`t") : $line) -ceq $p.Word) { break }
                    $lines++
                }
                $Bodies.Add($lines)
            }
            $pending.Clear()
            [void] $out.Append("`n")
        }
        elseif ($c -eq '#' -and ($i -eq 0 -or [char]::IsWhiteSpace($Command[$i - 1]))) {
            $end = $Command.IndexOf("`n", $i)
            $i = $end -lt 0 ? $n : $end
        }
        else { [void] $out.Append($c); $i++ }
        # Each branch moves $i by its own arithmetic; one that left it here would walk for ever,
        # as PR #420's bug scan made the comment branch do, so the pass throws instead (#421). No
        # branch has a continue, so that every pass reaches this.
        if ($i -le $was) { throw "the walk over the command stalled at index $was, which a pass left where it was" }
    }
    $out.ToString()
}

function Get-HangReason {
    <#  Why $Command is refused, as a sentence, or nothing: it would hang, it holds a pair of
        backslashes, or it holds a long heredoc, the first of those that applies. -NoPairs leaves
        the second out.  #>
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Command,
        [switch] $NoPairs
    )
    $bodies = [System.Collections.Generic.List[int]]::new()
    $text = ConvertTo-Blanked -Command $Command -Bodies $bodies
    # Output redirects carry `&` and `|` that are not operators; they say nothing about stdin.
    $text = $text -replace ('\d*>&\d+|\d*>&-|&>>?\s*' + $WORD + '|\d*>[>|]?\s*' + $WORD), ' '
    # `|&` is a pipe, and a pipe at a line's end carries on to the next line.
    $text = $text.Replace('|&', '|') -replace '\|&?\s*\n\s*', '| '
    # The last pipeline ended in a pipe: it feeds a group, `| ( cat )`.
    $piped = $false
    foreach ($pipeline in [regex]::Split($text, '\|\||&&|[;&\n(){}]')) {
        $simples = [regex]::Split($pipeline, '\|')
        for ($at = 0; $at -lt $simples.Count; $at++) {
            $simple = $simples[$at]
            $feeds = @([regex]::Matches($simple, $FEED) | ForEach-Object Value)
            $words = [System.Collections.Generic.List[string]]@(($simple -replace $FEED, ' ') -split '\s+' | Where-Object { $_ })
            while ($words.Count -and ($words[0] -match '^\w+=' -or $WRAPPERS -ccontains $words[0])) { $words.RemoveAt(0) }
            if ($words.Count -and $words[0] -ceq 'timeout') {
                $words.RemoveAt(0)
                while ($words.Count -and $words[0].StartsWith('-')) {
                    $drop = $words[0] -ceq '-s' -or $words[0] -ceq '-k' ? 2 : 1
                    $words.RemoveRange(0, [Math]::Min($drop, $words.Count))
                }
                # The duration.
                if ($words.Count) { $words.RemoveAt(0) }
            }
            if (-not $words.Count) { continue }
            $name = ($words[0] -split '/')[-1]
            $arguments = @($words | Select-Object -Skip 1)
            $last = $feeds ? $feeds[-1].TrimStart([char[]] "0123456789< `t") : $null
            $fed = [bool] $feeds -or $at -gt 0 -or $piped
            $fromNull = $null -ne $last -and $NULLS -ccontains $last

            if ($name -ceq 'cat' -and -not $fed -and -not @($arguments | Where-Object { -not $_.StartsWith('-') })) {
                return "``cat`` with no file and nothing fed to it reads the Bash tool's stdin, a pipe that is never closed"
            }
            if ($name -cmatch $PYTHON) {
                $script = $null
                for ($k = 0; $k -lt $arguments.Count; $k++) {
                    $a = $arguments[$k]
                    if ($a -ceq '-W' -or $a -ceq '-X') { continue }
                    if ($k -and ($arguments[$k - 1] -ceq '-W' -or $arguments[$k - 1] -ceq '-X')) { continue }
                    $prints = (($a.StartsWith('--') -or $a.StartsWith('-0')) -and $a -cne '--') -or @('-V', '-VV', '-h', '-?') -ccontains $a
                    if ($a -ceq '-c' -or $a -ceq '-m' -or -not $a.StartsWith('-') -or $a -ceq '-' -or $prints) { $script = $a; break }
                }
                if (($null -eq $script -or $script -ceq '-') -and ($fromNull -or -not $fed)) {
                    if ($fromNull) { return 'Python reading its program from /dev/null starts the interactive prompt here and never ends' }
                    return "Python with no script and nothing fed to it reads the Bash tool's stdin, a pipe that is never closed"
                }
            }
        }
        # Where the group ends is not tracked, so everything after its pipe counts as fed.
        $piped = $piped -or ([bool] $pipeline.Trim() -and -not $simples[-1].Trim())
    }
    if (-not $NoPairs -and $Command.Contains($PAIR)) {
        return 'the command holds two backslashes in a row, and a pair reaches bash as one here; put the text in a file, or use the PowerShell tool, which keeps them'
    }
    $longest = ($bodies | Measure-Object -Maximum).Maximum
    if ($bodies.Count -and $longest -gt $HEREDOC_LINES) {
        return "a heredoc body of $longest lines is over the $HEREDOC_LINES this hook lets through; a long one has been cut short on a quote here, and nothing ran"
    }
}

function Get-Refusal {
    <#  Why the tool call $Call is refused, or nothing; a refusal is appended to $Log on the way.
        A call whose tool_name is not Bash is let through, and one with none is read as Bash's.
        A pair of backslashes is a reason only with -Windows, where one is halved.  #>
    param(
        [Parameter(Mandatory)] [object] $Call,
        [Parameter(Mandatory)] [string] $Log,
        [switch] $Windows
    )
    $tool = $Call.PSObject.Properties['tool_name'] ? [string] $Call.tool_name : 'Bash'
    if ($tool -cne 'Bash') { return }
    $toolInput = $Call.PSObject.Properties['tool_input'] ? $Call.tool_input : $null
    $command = $toolInput -and $toolInput.PSObject.Properties['command'] ? [string] $toolInput.command : ''
    $why = Get-HangReason -Command $command -NoPairs:(-not $Windows)
    if ($why) {
        # The log is a record; the refusal does not wait on it.
        try {
            $line = [ordered] @{ time = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz'); why = $why; command = $command } | ConvertTo-Json -Compress
            [IO.File]::AppendAllText($Log, "$line`n", [Text.UTF8Encoding]::new($false))
        }
        catch { }
    }
    $why
}

if ($SelfTest) {
    # rf's cases: the command, and whether it is refused, with the pair on as on Windows. The first
    # is no command but $THROWS, whose reading throws (#431): the loop's line must fail it with a
    # threw: line and go on, and it is reported ok where it was so failed.
    $THROWS = 'a command whose reading throws'
    $cases = @(
        @($THROWS, $false),
        @('cat > /dev/null', $true),
        @("cat > /dev/null; python - `"`$@`" <<'PY'`nprint(1)`nPY", $true),
        @("python - <<'PY' < /dev/null`nPY`n", $true),
        @("cat > /dev/null < /dev/null; python - < /dev/null; python -c `"print(1)`"", $true),
        @('gh issue list; python < /dev/null', $true),
        @('timeout 8 python -', $true),
        @('FOO=1 python3 -X utf8 -', $true),
        @('git log | head; cat', $true),
        @('timeout -s KILL 5 cat > /dev/null', $true),
        @('if true; then cat; fi', $true),
        @('python -- -', $true),
        # A known false refusal.
        @('while read l; do echo; cat; done < list.txt', $true),
        @('git ls-files | while read f; do cat; done', $false),
        @('while read l; do cat; done < list.txt', $false),
        @('echo hi | { head -1; cat; }', $false),
        @('echo hi | (read x; cat)', $false),
        # A known false pass.
        @("echo hi | (head -1)`ngit status`npython -", $false),
        @('python --version && py -0 && python -V; python3 -h', $false),
        @("git log |`n  cat", $false),
        @('curl -s x |& python -', $false),
        @('echo hi | (cat > f)', $false),
        @('echo hi | { cat; }', $false),
        # A heredoc over $HEREDOC_LINES, one of exactly that many, one that never ends, and CRLF.
        @(("cat > f.py <<'X'`n" + ("line`n" * 61) + "X`n"), $true),
        @(("cat > f.py <<'X'`n" + ("line`n" * 60) + "X`n"), $false),
        @(("git log; python - <<'PY'`n" + ("x = 1`n" * 61)), $true),
        @(("cat > f <<'X'`r`na`r`nX`r`n" + ("echo hi`r`n" * 61)), $false),
        @("cat <<\EOF`npython -`nEOF`n", $false),
        @("cat > /dev/null <<'X'`nX`n", $false),
        @("python - <<'PY'`nimport sys`nprint(`"it's`")`ncat`nPY`necho done", $false),
        @("python - <<< 'print(1)'", $false),
        @("echo `"a << b`"; echo 'cat'", $false),
        @('git log | cat', $false),
        @('cat file.txt | python -', $false),
        @('cat -n "my file" 2>&1', $false),
        @('cat < /dev/null', $false),
        @('python tools/render.py a-machine < /dev/null', $false),
        @("python -c 'print(1)' && python -m json.tool x.json", $false),
        @('git commit -m "cat" # python -', $false),
        # realistic-fusion-refreshed#682: a pair, in quotes, and a lone backslash; in a short
        # heredoc; on a command line; refused though it would run; a line's last character and the
        # next line's first.
        @("echo 'Z\\Z'", $true),
        @("echo 'Z\Z'", $false),
        @("python - <<'PY'`nprint(r`"\\s+`")`nPY", $true),
        @("python - <<'PY'`nprint(r`"\s+`")`nPY", $false),
        @("sed 's/a\\/b/' f.txt", $true),
        @("echo 'p\\`"q' # a\\b", $true),
        @("echo a \`n\ b", $false)
    )
    $failures = 0
    $n = 0
    $total = $cases.Count + 1 + 1 + 3 + 5 + 13
    $report = {
        param([string] $what, [bool] $ok, [string] $why)
        $script:n++
        Write-Host ("self-test {0}/{1}: {2} -- {3}" -f $script:n, $total, $what, $(if ($ok) { 'ok' } else { 'FAILED' }))
        if (-not $ok) { $script:failures++; if ($why) { Write-Host "    $why" } }
    }
    # Get-HangReason, but throwing on $THROWS as the walk does when it stalls; the loop's line is
    # the same for every case. Removed after the loop, so the cases below read the real one.
    $real = ${function:Get-HangReason}
    function Get-HangReason {
        param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Command, [switch] $NoPairs)
        if ($Command -ceq $THROWS) { throw 'the walk over the command stalled at index 0, a stand-in' }
        & $real -Command $Command -NoPairs:$NoPairs
    }
    try {
        foreach ($c in $cases) {
            $shown = $c[0] -replace '\r', '\r' -replace '\n', '\n'
            if ($shown.Length -gt 120) { $shown = $shown.Substring(0, 120) + '...' }
            # A throw, as the walk's when it stalls, fails the case and not the run (#421).
            $why = ''
            $held = try { [bool] (Get-HangReason -Command $c[0]) -eq $c[1] } catch { $why = "threw: $($_.Exception.Message)"; $false }
            if ($c[0] -ceq $THROWS) {
                & $report 'a case whose reading throws is failed with its threw: line, and the cases after it run (#431); ok here means it was failed' (-not $held -and $why -ceq 'threw: the walk over the command stalled at index 0, a stand-in') "held: $held; $why"
                continue
            }
            & $report "$(if ($c[1]) { 'refused' } else { 'allowed' }): $shown" $held $why
        }
    }
    # A throw the loop's line let out stops the run here, saying so, not with the error view.
    catch { Write-Host "`nFAILED - self-test: a command case threw out of the loop, which must fail that case and go on (#431): $($_.Exception.Message)"; exit 1 }
    ${function:Get-HangReason} = $real
    $after = try { Get-HangReason -Command $THROWS; 'read' } catch { "threw: $($_.Exception.Message)" }
    & $report 'the stand-in is gone after the loop: the real Get-HangReason reads that command without throwing (#431)' ($after -ceq 'read') $after

    # The walk's guard (#421), on a copy of ConvertTo-Blanked made to stall as PR #420's bug scan
    # made it: the comment branch without `$c -eq '#' -and`, which at a line break after a space
    # finds that line break at $i and leaves $i there. In a pwsh of its own, given 30 s and then
    # killed, since without the guard the walk never ends.
    $function = (Get-Command ConvertTo-Blanked).ScriptBlock.Ast.Extent.Text
    $stalling = $function.Replace("`$c -eq '#' -and ", '')
    $probe = Join-Path ([IO.Path]::GetTempPath()) "refuse-hanging-bash-stall-$([guid]::NewGuid().ToString('N').Substring(0, 8)).ps1"
    Set-Content -LiteralPath $probe -Value "`$HEREDOC = [regex] '$($HEREDOC.ToString().Replace("'", "''"))'", $stalling,
        '$bodies = [System.Collections.Generic.List[int]]::new()',
        "try { ConvertTo-Blanked -Command `"a ``nb`" -Bodies `$bodies | Out-Null; 'walked' } catch { `$_.Exception.Message }"
    try {
        $start = [Diagnostics.ProcessStartInfo]::new('pwsh')
        foreach ($a in '-NoProfile', '-File', $probe) { $start.ArgumentList.Add($a) }
        $start.RedirectStandardOutput = $true; $start.UseShellExecute = $false
        $child = [Diagnostics.Process]::Start($start)
        $said = $child.StandardOutput.ReadToEndAsync()
        $ended = $child.WaitForExit(30000)
        if (-not $ended) { $child.Kill($true); $child.WaitForExit() }
        $stalled = if ($ended) { $said.Result.Trim() } else { 'still walking after 30 s, and killed' }
    }
    finally { Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue }
    & $report 'a pass of the walk that leaves its index where it was throws, naming the index (#421)' ($stalling -cne $function -and $stalled -ceq 'the walk over the command stalled at index 2, which a pass left where it was') "the stalled copy said: $stalled"

    $scratch = Join-Path ([IO.Path]::GetTempPath()) "refuse-hanging-bash-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -ItemType Directory -Path $scratch -Force | Out-Null
    try {
        # The log: a pass writes nothing; one refusal and two passes leave one line with the
        # time, the reason and the command; a log that cannot be written still refuses.
        $log = Join-Path $scratch 'refused.log'
        $refusedCall = @{ tool_name = 'Bash'; tool_input = @{ command = 'cat' } } | ConvertTo-Json | ConvertFrom-Json
        $passedCall = @{ tool_name = 'Bash'; tool_input = @{ command = 'cat f' } } | ConvertTo-Json | ConvertFrom-Json
        Get-Refusal -Call $passedCall -Log $log | Out-Null
        & $report 'a command let through writes nothing to the log' (-not (Test-Path -LiteralPath $log))
        $why = Get-Refusal -Call $refusedCall -Log $log
        Get-Refusal -Call $passedCall -Log $log | Out-Null
        $lines = @(if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log })
        $entry = if ($lines.Count -eq 1) { $lines[0] | ConvertFrom-Json } else { $null }
        & $report 'one refusal and two passes leave one line: the time, the reason and the command' ([bool] ($entry -and $entry.why -ceq $why -and $entry.command -ceq 'cat' -and $entry.time)) "the log held: $($lines -join ' | ')"
        $unwritable = try { [bool] (Get-Refusal -Call $refusedCall -Log $scratch) } catch { $false }
        & $report 'a log that cannot be written, a directory, still refuses and does not throw' $unwritable

        # When a pair is the reason: on Windows only, after a hang, before a long heredoc.
        $long = "cat > f <<'X'`n" + ("line`n" * ($HEREDOC_LINES + 1)) + "X`n"
        $said = {
            param([string] $command, [bool] $windows)
            [string] (Get-Refusal -Call (@{ tool_name = 'Bash'; tool_input = @{ command = $command } } | ConvertTo-Json | ConvertFrom-Json) -Log $log -Windows:$windows)
        }
        & $report 'a pair is refused on Windows' ((& $said "echo $PAIR" $true) -match 'two backslashes')
        & $report 'a pair is let through elsewhere' (-not (& $said "echo $PAIR" $false))
        & $report 'a long heredoc is refused elsewhere, beside a pair' ((& $said ($long + $PAIR) $false) -match 'heredoc')
        & $report 'a hang comes before a pair' ((& $said "cat # $PAIR" $true) -match 'never closed')
        & $report 'a pair comes before a long heredoc' ((& $said ($long + $PAIR) $true) -match 'two backslashes')

        # The wiring as the session runs it: the command the settings file wires for this script,
        # found by name, through sh, with the tool call on stdin.
        $Settings = (Resolve-Path -LiteralPath ($Settings ? $Settings : (Join-Path $PSScriptRoot '../.claude/settings.json'))).Path
        # The case for -Settings below runs this with the variable set, to read which file it took.
        if ($env:REFUSE_HANGING_BASH_SETTINGS_PROBE) { Write-Host "settings: $Settings"; exit 3 }
        $project = Split-Path (Split-Path $Settings -Parent) -Parent
        $names = [regex]::Escape((Split-Path $PSCommandPath -Leaf))
        # The entry is found by the script's name, wherever it stands among the PreToolUse entries.
        $findWired = {
            param([string] $path)
            $found = @((Get-Content -LiteralPath $path -Raw | ConvertFrom-Json).hooks.PreToolUse) |
                Where-Object { @($_.hooks.command) -match $names } | Select-Object -First 1
            @{ Entry = $found; Command = $(if ($found) { @($found.hooks.command) -match $names | Select-Object -First 1 } else { '' }) }
        }
        $read = & $findWired $Settings
        $entry = $read.Entry
        $wired = $read.Command
        # Git for Windows keeps its sh, and the cat beside it, off the path PowerShell sees.
        $sh = (Get-Command sh -ErrorAction SilentlyContinue)?.Source ?? (Join-Path (git --exec-path) "../../../usr/bin/sh.exe")
        $env:PATH = "$(Split-Path $sh)$([IO.Path]::PathSeparator)$env:PATH"
        # The project the wired command runs for is a copy holding only the settings' scripts
        # folder, so that a refusal logs to the copy and never to the settings' repository.
        $copy = Join-Path $scratch 'project'
        New-Item -ItemType Directory -Path (Join-Path $copy '.claude') -Force | Out-Null
        $scriptsAt = Join-Path $copy ([regex]::Match($wired, '\$CLAUDE_PROJECT_DIR/([^"]*)/' + $names).Groups[1].Value)
        New-Item -ItemType Directory -Path $scriptsAt -Force | Out-Null
        Copy-Item -LiteralPath $PSCommandPath -Destination $scriptsAt
        $through = {
            param([string] $tool, [string] $command, [string] $form = $wired, [string] $at = $copy)
            $env:CLAUDE_PROJECT_DIR = $at
            # The session's shape: on Windows its cwd and transcript_path are paths of `\\`, before
            # tool_input, and the case must not read them.
            $call = [ordered] @{ session_id = 's'; transcript_path = 'C:\Users\someone\.claude\projects\a\t.jsonl'; cwd = 'C:\src\a-project'
                hook_event_name = 'PreToolUse'; tool_name = $tool; tool_input = @{ command = $command } }
            $text = ($call | ConvertTo-Json -Compress) | & $sh -c $form 2>&1 | Out-String
            @{ Code = $LASTEXITCODE; Text = $text }
        }
        $ok = $false
        if (-not $wired) { Write-Host "    $Settings wires no command that names this script" }
        else {
            $refused = & $through 'Bash' 'git log | head; cat'
            $plain = & $through 'Bash' 'git log | cat'
            $logged = Test-Path -LiteralPath (Join-Path $copy '.claude/refused-bash.log')
            $ok = $refused.Code -eq 2 -and $refused.Text -match '^Refused' -and $refused.Text -match 'never closed' -and $logged -and
                $plain.Code -eq 0 -and -not $plain.Text.Trim()
            if (-not $ok) { foreach ($r in $refused, $plain) { Write-Host "    $($r.Code) $($r.Text)" }; Write-Host "    logged under the project: $logged" }
        }
        & $report 'the wired hook refuses a hanging cat with exit 2 and a reason, logs it under the project, and passes a fed one in silence' $ok
        # A pair alone starts the hook only through the case's backslash arm. On Windows the
        # session's shell halves each pair in the wired command before sh reads it, as it halves a
        # Bash tool command: on PR #420 `*\\*` became `*\*`, and a lone pair was let through.
        # PowerShell's start of Git's sh.exe halves them the same way, so on Windows the form is
        # run as written, and reads as the session's; elsewhere it is run as written, as a session
        # there reads it, and halved, as a Windows session does. The refusal is Windows-only, so
        # elsewhere a pass is right.
        $forms = if ($IsWindows) { @(@{ Form = $wired; Halved = $true }) }
                 else { @(@{ Form = $wired; Halved = $false }, @{ Form = $wired.Replace('\\', '\'); Halved = $true }) }
        $ok = $false
        if ($wired) {
            $verdicts = foreach ($f in $forms) { & $through 'Bash' "echo 'Z${PAIR}Z'" $f.Form }
            $ok = if ($IsWindows) { -not @($verdicts | Where-Object { $_.Code -ne 2 -or $_.Text -notmatch 'two backslashes' }) }
                  else { -not @($verdicts | Where-Object { $_.Code -ne 0 }) }
            if (-not $ok) { foreach ($r in $verdicts) { Write-Host "    $($r.Code) $($r.Text)" } }
        }
        & $report 'the wired hook, with each pair in it halved as the session halves it, refuses a lone pair on Windows' $ok
        # The tool call reaches sh as JSON, where every quote is \" and every line break \n, and
        # the cwd before tool_input is a path of \\ on Windows, so an arm matching one backslash,
        # or reading the whole call, starts pwsh on every command (the header). A stub at the
        # wired path says whether it was started. Never for quotes, line breaks and paths, one
        # backslash of the command, or a PowerShell tool call, which the script passes unread;
        # halved, for a pair, the one thing the arm is for.
        $ok = $false
        if ($wired) {
            $stubProject = Join-Path $scratch 'stub'
            $stubAt = Join-Path $stubProject ([regex]::Match($wired, '\$CLAUDE_PROJECT_DIR/([^"]*)/' + $names).Groups[1].Value)
            New-Item -ItemType Directory -Path $stubAt -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $stubAt (Split-Path $PSCommandPath -Leaf)) -Value "Write-Output 'STARTED'"
            $quoted = "git log --format=`"%h %s`" -3`ngit status"
            $started = { param([string] $tool, [string] $command, [string] $form) (& $through $tool $command $form $stubProject).Text -match 'STARTED' }
            $starts = foreach ($f in $forms) {
                @{ Halved = $f.Halved
                   Quoted = & $started 'Bash' $quoted $f.Form
                   Single = & $started 'Bash' "grep -n 'a\.b' x" $f.Form
                   PowerShell = & $started 'PowerShell' 'Get-Content C:\src\x\cat.py' $f.Form
                   Pair = & $started 'Bash' "echo 'a${PAIR}b'" $f.Form }
            }
            $ok = -not @($starts | Where-Object { $_.Quoted -or $_.Single -or $_.PowerShell -or ($_.Halved -and -not $_.Pair) })
            if (-not $ok) { foreach ($s in $starts) { Write-Host "    halved $($s.Halved): quoted $($s.Quoted), one backslash $($s.Single), PowerShell $($s.PowerShell), pair $($s.Pair)" } }
        }
        & $report 'the wired hook is started by a pair, halved as the session halves it, and not by quotes, line breaks, the call''s paths, one backslash or a PowerShell call' $ok
        # The first example is what a consumer copies; its cases must be the ones held above.
        $caseOf = { param([string] $text) [regex]::Match($text, 'i=\$\(cat\);.*?case \$c in [^)]*\)').Value }
        # The example is one line; it ends at its last esac, the first closing the PowerShell skip.
        $exampleCase = & $caseOf ([regex]::Match((Get-Content -LiteralPath $PSCommandPath -Raw), 'i=\$\(cat\).*esac').Value)
        & $report 'the first example''s cases are the wired one''s' ([bool] ($wired -and $exampleCase -and $exampleCase -ceq (& $caseOf $wired))) "example: $exampleCase; wired: $(& $caseOf $wired)"
        $ok = $false
        if ($wired) {
            $ps = & $through 'PowerShell' 'cat'
            $lower = & $through 'bash' 'cat'
            $ok = $ps.Code -eq 0 -and -not $ps.Text.Trim() -and $lower.Code -eq 0 -and -not $lower.Text.Trim()
            if (-not $ok) { foreach ($r in $ps, $lower) { Write-Host "    $($r.Code) $($r.Text)" } }
        }
        & $report 'the wired hook passes a PowerShell tool call, and a tool named bash in other case' $ok
        # JSON that is not an object, a string or an array, is no call either.
        $unreadOk = $true
        foreach ($shape in 'not json', '"cat"', '["cat"]') {
            $unread = $shape | pwsh -NoProfile -File $PSCommandPath 2>&1 | Out-String
            if ($LASTEXITCODE -ne 1 -or $unread -notmatch 'NOT checked') { $unreadOk = $false; Write-Host "    $shape -> $LASTEXITCODE $unread" }
        }
        & $report 'a tool call it cannot read, not JSON or JSON that is no object, exits 1 and says it was not checked' $unreadOk
        # Where the log goes, from a copy at a consumer's vendored path, where the project and the
        # script's repository differ: under $CLAUDE_PROJECT_DIR, else under the script's parent.
        $consumer = Join-Path $scratch 'consumer'
        $vendored = Join-Path $consumer 'vendor/grado-factorio-tools/scripts'
        # Each has its .claude, as a consumer and this repository do; the log does not make one.
        foreach ($d in $vendored, (Join-Path $consumer '.claude'), (Join-Path $consumer 'vendor/grado-factorio-tools/.claude')) {
            New-Item -ItemType Directory -Path $d -Force | Out-Null
        }
        Copy-Item -LiteralPath $PSCommandPath -Destination $vendored
        $sessionDir = $env:CLAUDE_PROJECT_DIR
        try {
            $env:CLAUDE_PROJECT_DIR = $consumer
            $untold = '{"tool_input":{"command":"cat"}}' | pwsh -NoProfile -File (Join-Path $vendored (Split-Path $PSCommandPath -Leaf)) 2>&1 | Out-String
            $untoldCode = $LASTEXITCODE
            $env:CLAUDE_PROJECT_DIR = ''
            $fellBack = '{"tool_input":{"command":"cat"}}' | pwsh -NoProfile -File (Join-Path $vendored (Split-Path $PSCommandPath -Leaf)) 2>&1 | Out-String
            $fellBackCode = $LASTEXITCODE
        }
        finally { $env:CLAUDE_PROJECT_DIR = $sessionDir }
        & $report 'a call with no tool_name is read as the Bash tool''s, and its hanging cat refused' ($untoldCode -eq 2 -and $untold -match 'never closed') "$untoldCode $untold"
        $inProject = @(Get-Content -LiteralPath (Join-Path $consumer '.claude/refused-bash.log') -ErrorAction SilentlyContinue)
        $inScripts = @(Get-Content -LiteralPath (Join-Path $consumer 'vendor/grado-factorio-tools/.claude/refused-bash.log') -ErrorAction SilentlyContinue)
        & $report 'a refusal is logged under $CLAUDE_PROJECT_DIR, not the vendored script''s repository, and under that repository only where the variable is unset' ($fellBackCode -eq 2 -and $inProject.Count -eq 1 -and $inScripts.Count -eq 1) "project log $($inProject.Count) line(s), vendored log $($inScripts.Count), exits $untoldCode $fellBackCode"
        # The first example's form, for a project with no hook script, as a clone without the
        # submodule is: the command runs, and stdout tells the agent it was not checked.
        $form = [regex]::Match((Get-Content -LiteralPath $PSCommandPath -Raw), 'i=\$\(cat\).*esac').Value
        $empty = Join-Path $scratch 'no-hook-script'
        New-Item -ItemType Directory -Path $empty -Force | Out-Null
        $env:CLAUDE_PROJECT_DIR = $empty
        $absentText = (@{ tool_name = 'Bash'; tool_input = @{ command = 'cat' } } | ConvertTo-Json -Compress) | & $sh -c $form 2>$null | Out-String
        $absentCode = $LASTEXITCODE
        # The missing path is named in both fields (ADR 0004).
        $parsed = try { $absentText | ConvertFrom-Json } catch { $null }
        $told = if ($parsed -and $parsed.PSObject.Properties['hookSpecificOutput']) { $parsed.hookSpecificOutput }
        $named = $told -and ([string] $told.additionalContext) -match 'vendor/grado-factorio-tools/scripts/refuse-hanging-bash\.ps1 was not found, so this command was NOT checked' -and
            $parsed.PSObject.Properties['systemMessage'] -and $parsed.systemMessage -ceq $told.additionalContext
        & $report "the first example's form, where the project holds no hook script, exits 0 and prints JSON naming the missing path to the agent" ([bool] ($form -and $absentCode -eq 0 -and $told -and $told.hookEventName -ceq 'PreToolUse' -and $named)) "$absentCode $absentText"
        # Which tools the session starts that command for: the matcher of the entry it was read
        # from.
        . "$PSScriptRoot/hook-matcher.ps1"
        $unstarted = @(if ($entry) { Get-UnstartedShellTool -Entry $entry })
        & $report 'the matcher of the entry that wires the hook starts it for the Bash tool and for the PowerShell tool' ([bool] ($entry -and -not $unstarted)) "$Settings`: the matcher does not start the hook for: $($unstarted -join ', ')"
        # The log is the consumer's, and git ignores it there (#322 ruling 5).
        git -C $project check-ignore -q .claude/refused-bash.log 2>$null
        & $report "git ignores .claude/refused-bash.log in the settings' repository" ($LASTEXITCODE -eq 0) "$project`: add /.claude/refused-bash.log to its .gitignore"
        # The entry named, not the first, and -Settings read: a settings file whose first entry
        # wires another command, and a child self-test given it, stopped by the variable once it
        # says which file it took, so that it never reaches this case.
        $fixture = Join-Path $scratch 'two-entries.json'
        @{ hooks = @{ PreToolUse = @(
            @{ matcher = 'Bash'; hooks = @(@{ type = 'command'; command = 'echo other' }) },
            @{ matcher = 'Bash|PowerShell'; hooks = @(@{ type = 'command'; command = "pwsh -File scripts/$(Split-Path $PSCommandPath -Leaf)" }) }
        ) } } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $fixture
        $second = & $findWired $fixture
        & $report 'the wiring is read from the entry that names this script, not the first' ([bool] ($second.Entry -and $second.Entry.matcher -ceq 'Bash|PowerShell' -and $second.Command -match $names))
        $env:REFUSE_HANGING_BASH_SETTINGS_PROBE = '1'
        try { $took = pwsh -NoProfile -File $PSCommandPath -SelfTest -Settings $fixture 2>&1 | Out-String; $tookCode = $LASTEXITCODE }
        finally { $env:REFUSE_HANGING_BASH_SETTINGS_PROBE = '' }
        & $report 'a -SelfTest given -Settings reads that file' ($tookCode -eq 3 -and $took -match 'settings: .*two-entries\.json') "$tookCode $took"
    }
    finally {
        Remove-Item Env:CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host ''
    # $total is written by hand, so a case added or dropped without it would make the count false
    # (#431).
    if ($n -ne $total) { Write-Host "FAILED - self-test: $n case(s) reported, where `$total says $total."; exit 1 }
    if ($failures) { Write-Host "FAILED - self-test: $failures of $total case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $total cases."
    exit 0
}

try {
    $call = [Console]::In.ReadToEnd() | ConvertFrom-Json
    # Not [pscustomobject], which is [psobject] and so holds a string or an array too.
    if ($call -isnot [System.Management.Automation.PSCustomObject]) { throw 'the tool call is not a JSON object' }
    $root = $env:CLAUDE_PROJECT_DIR ? $env:CLAUDE_PROJECT_DIR : (Split-Path $PSScriptRoot -Parent)
    $why = Get-Refusal -Call $call -Log (Join-Path $root '.claude/refused-bash.log') -Windows:$IsWindows
}
catch {
    # Loud, and not a refusal: a hook that cannot read its input must not stop every command.
    [Console]::Error.WriteLine("refuse-hanging-bash: could not read the tool call, so the command was NOT checked: $($_.Exception.Message)")
    exit 1
}
if ($why) {
    [Console]::Error.WriteLine(@"
Refused before it ran: $why. Write the script or the text to a file with the Write tool and give
the command that file's path. A command left reading can be fed with a pipe or ``< file`` instead.
refuse-hanging-bash.ps1's header says what is refused: in grado-factorio-tools's scripts/,
vendored at vendor/grado-factorio-tools/scripts/.
"@)
    exit 2
}
exit 0
