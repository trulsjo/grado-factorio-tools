<#
.SYNOPSIS
    A hook for agent sessions: refuses a shell command that writes .claude/settings.json or
    .claude/settings.local.json, and says to make the change with the Edit tool. Exit 2 refuses the
    command before it runs; exit 0 lets it run.

.DESCRIPTION
    WHY (grado-factorio-tools#469, from grado-factorio-modpack#414). A session wrote that
    repository's tracked .claude/settings.json with a script run through the Bash tool. The ticket's
    brief said to stop and ask Truls if the auto-mode check refused the edit, as it had before; but
    a file written by the shell never reaches the Edit tool, so that check was never asked, and
    nothing said so. The content was right; the gate Truls relies on was not reached.

    HOW A CONSUMER WIRES IT. In its tracked .claude/settings.json, a PreToolUse hook on the two
    shell tools, matcher `Bash|PowerShell`, whose command is the first example below (ADR 0004).
    This repository wires it from scripts/ in its own (#323 ruling 3). The session hands the hook
    the tool call as JSON on stdin: this reads `tool_input.command`. The `case` starts this script
    only when that JSON names `settings.json` or `settings.local.json`, in any case, since starting
    PowerShell takes a second and the hook runs before every shell command. Where the script is not
    there, as in a clone whose submodule was never fetched, the wired command lets the shell command
    run and prints JSON that names the missing path and tells the agent it was not checked, as
    refuse-git-discard.ps1's wiring does; -SelfTest runs both branches of the wiring.

    WHAT IT REFUSES. A command that writes either file, named with any directory part before
    `.claude/`, as `./.claude/settings.json` or an absolute path, with / or \ between the parts, in
    any case: a redirection onto it, `>` or `>>`, its target a word of its own or joined on; `tee`
    or `Tee-Object` naming it; `Set-Content`, `Add-Content` or `Out-File` naming it, other than as
    the value of a parameter that begins -Va or -In, as -Value and -InputObject; .NET's
    `::WriteAllText`, `WriteAllLines`, `WriteAllBytes` and their `AppendAll` forms with it as the
    first argument; `sed` with an in-place option, `-i` alone or among other short options, with a
    suffix or not, or `--in-place`, naming it; and `cp`, `mv`, `Copy-Item` or `Move-Item` with it as
    the target. Each redirection, as `2>/dev/null` or `> log.txt`, is set aside before a command's
    arguments are read. The target of `cp` or `mv` is the last word that is no option, and none
    with `-t <dir>` or `-t<dir>`. That of `Copy-Item` or `Move-Item`, and of `cp` or `mv` where an
    argument names one of those cmdlets' parameters by three letters or more, as PowerShell's
    aliases are written (Test-ItemParameter), is Get-ItemTarget's: the value of -Destination, named
    from -Des; else the second word no parameter takes, or the first where -Path or -LiteralPath
    is named, every parameter but a switch taking the word after it, or the value after its colon,
    as `-Destination:<file>`. A
    command is found in a compound, after `&&`, `||`, `;`, `|`, `&` or a newline, or inside
    parentheses or braces, and after the assignments that lead it, as `MSYS_NO_PATHCONV=1 sed -i
    ...`; a command's name may carry a path or `.exe`. A command a `(` broke off goes on after the
    `)` that closes it, at any depth, one word standing for what the parentheses held, as
    `Set-Content -Value (Get-Content b.json) -Path .claude/settings.json` and
    `Copy-Item (Join-Path (Get-Location) b.json) .claude/settings.json`; a `)` that closes no `(`,
    as a case pattern's, ends a command and continues none.

    WHAT IT LETS THROUGH. A read, as `cat`, `Get-Content`, `grep`, `git show` or `git diff`; the
    file as a copy's source, as `cp .claude/settings.json backup.json`; a redirection of it
    elsewhere, as `cat .claude/settings.json > backup.json`, and one that reads it, as
    `sort < .claude/settings.json`; a `>` inside quotes; a file with a
    similar name, as `settings.json.bak` or `my-settings.json`; and every command that names neither
    file, in silence.

    IT FAILS OPEN, LOUDLY. Where a command that names either file has quotes it cannot pair, or
    where the tool call cannot be read, it lets the command run and prints, on stdout, JSON whose
    additionalContext tells the agent the command was NOT checked.

    WHAT IT CANNOT SEE. A write from a script or program the command runs, as
    `pwsh -File build-settings.ps1`, which names the file only inside the script: it reads the
    command line alone (Truls, 2026-11-16, at #469's triage). A path built from a variable or a
    substitution, as `$f` or `$(...)`. A `cd` into `.claude` and then a bare `settings.json`. A
    write by git, as `git checkout -- .claude/settings.json`, which refuse-git-discard.ps1 judges on
    its own grounds. A command named through an alias, as `ac`, or a writer not listed above, as
    `New-Item -Value`, `dd`, `python` or `node`. A command after a shell keyword or a wrapper, as
    `then`, `do`, `else` or `env`, whose name is then read as the keyword's. A copy into the
    directory, as `cp x/settings.json .claude/`, and a redirection written `>|`, whose target the
    `|` cuts off. A parameter given with a colon to `Set-Content`, `Add-Content` or `Out-File`, as
    `-Value:x`, and `cp --target-directory=<dir>`
    or `cp -S <suffix>`, whose value is then read as a file. A .NET writer named inside a quoted
    string, as `Write-Output "[IO.File]::WriteAllText('.claude/settings.json', 'x')"`, which is
    refused though it only prints. Both shells' quoting is
    read roughly: a word in double or single quotes is one word with its quotes taken off, a
    backslash or backtick escapes the character after it, and nothing is expanded. And whether the
    settings still reach it, unless -SelfTest is run on them: that reads the wired command and the
    matchers of the entries that run it, and nothing else of the settings.

    TO CHECK IT, run the second example below.

.PARAMETER SelfTest
    Prove each refused form refused for each file and each let-through form let through, a command
    with an unpaired quote let through with the NOT-checked message, and the script run on a tool
    call on stdin: exit 2 and a reason for a write, exit 0 and nothing for a read, exit 0 and the
    NOT-checked JSON for a call it cannot read. Then the first example's command, run through sh,
    refuses with exit 2 and a reason, passes a read, and where the project holds no hook script
    exits 0 and prints JSON that names the missing path to the agent. Then the command -Settings
    wires, found by this script's name: it refuses with exit 2 and passes a read, and the matchers
    of the entries that run it start it for the Bash tool and for the PowerShell tool. Needs sh: the
    one on the path, or the one Git for Windows ships.

.PARAMETER Settings
    With -SelfTest: the .claude/settings.json whose PreToolUse command naming this script the wired
    cases run, with that file's repository as the project. The first command of any entry that names
    this script is taken, wherever it stands in the file (#315 ruling 3). Defaults to this
    repository's own, which check.ps1, and so CI, runs. A consumer runs it on its own file to know
    its wiring still reaches the hook.

.EXAMPLE
    The wired command: the PreToolUse hook a consumer puts in its .claude/settings.json, as HOW A
    CONSUMER WIRES IT says. The script takes no option.

        i=$(cat); case $i in *[Ss][Ee][Tt][Tt][Ii][Nn][Gg][Ss].[Jj][Ss][Oo][Nn]*|*[Ss][Ee][Tt][Tt][Ii][Nn][Gg][Ss].[Ll][Oo][Cc][Aa][Ll].[Jj][Ss][Oo][Nn]*) h="$CLAUDE_PROJECT_DIR/vendor/grado-factorio-tools/scripts/refuse-settings-write.ps1"; if [ -f "$h" ]; then printf '%s' "$i" | pwsh -NoProfile -File "$h"; else m='refuse-settings-write: vendor/grado-factorio-tools/scripts/refuse-settings-write.ps1 was not found, so this command was NOT checked by the settings-write hook. git submodule update --init fetches the script.'; printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}' "$m" "$m"; fi;; esac

.EXAMPLE
    To check it. The first is refused with exit 2, the second passes with exit 0:

        '{"tool_input":{"command":"sed -i s/x/x/ .claude/settings.json"}}' | pwsh -NoProfile -File scripts/refuse-settings-write.ps1; $LASTEXITCODE
        '{"tool_input":{"command":"cat .claude/settings.json"}}' | pwsh -NoProfile -File scripts/refuse-settings-write.ps1; $LASTEXITCODE
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [switch] $SelfTest,
    [string] $Settings
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# A word that names either settings file, whatever the directory part before `.claude`.
$FILE_AT = '(?i)(?:^|[\\/])\.claude[\\/]settings(?:\.local)?\.json$'

# Copy-Item's and Move-Item's switches, and their parameters that take a value, the common ones
# among them.
$ITEM_SWITCHES = 'Recurse', 'Force', 'PassThru', 'Container', 'Debug', 'Verbose', 'WhatIf', 'Confirm'
$ITEM_VALUED = 'Path', 'LiteralPath', 'Destination', 'Filter', 'Include', 'Exclude', 'Credential', 'ToSession', 'FromSession',
    'ErrorAction', 'WarningAction', 'InformationAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable',
    'OutVariable', 'OutBuffer', 'PipelineVariable', 'ProgressAction'

# Whether $Word names one of Copy-Item's or Move-Item's parameters by three letters or more, with
# one dash, as -ErrorAction or -Des:f: what tells PowerShell's cp from GNU's, whose -rf is no name.
function Test-ItemParameter {
    param([string] $Word)
    if ($Word -notmatch '^-([A-Za-z]{3,})(?::.*)?$') { return $false }
    $name = $Matches[1]
    [bool] @($ITEM_SWITCHES + $ITEM_VALUED | Where-Object { $_.StartsWith($name, [StringComparison]::OrdinalIgnoreCase) })
}

# The words of $Command, with each operator that ends a command as one of its own: a word's Raw
# text, its Bare text with each quoted span blanked to the same length, so that a > inside quotes
# is no redirection, and its Word, with the quotes taken off; $null where a quote is left open.
function Split-ShellCommand {
    param([AllowEmptyString()] [string] $Command)
    $quoted = '"(?:[^"\\`]|[\\`].)*"|''[^'']*'''
    $pattern = '(?<op>&&|\|\||[;|&\n(){}])|(?<word>(?:[^\s;|&(){}"''\\`]|[\\`].|' + $quoted + ')+)|[ \t\r]+'
    $matched = [regex]::Matches($Command, $pattern)
    if (($matched | Measure-Object Length -Sum).Sum -ne $Command.Length) { return $null }
    , @(foreach ($m in $matched) {
            if ($m.Groups['op'].Success) { @{ Op = $m.Value } }
            elseif ($m.Groups['word'].Success) {
                @{ Raw = $m.Value; Word = $m.Value -replace '"|''', ''
                    Bare = [regex]::Replace($m.Value, $quoted, { param($q) '_' * $q.Length }) }
            }
        })
}

# The word of one command, $Words, that names a settings file the command writes, or nothing.
function Get-WrittenSetting {
    param([hashtable[]] $Words)
    # A redirection's target, joined on, as >file, or the word after it, wherever it stands, the
    # command's first word too, as `> f echo x`. Each redirection word, and a target standing alone
    # after one, is set aside; the words left are the command's name and its arguments.
    # $redirect is the operator, > or <, waiting for its target, or nothing.
    $redirect = ''
    $plain = [Collections.Generic.List[string]]::new()
    foreach ($w in $Words) {
        if ($redirect) {
            if ($redirect -eq '>' -and $w.Word -match $FILE_AT) { return $w.Word }
            $redirect = ''; continue
        }
        $at = $w.Bare.LastIndexOfAny([char[]] '<>')
        if ($at -lt 0) { $plain.Add($w.Word); continue }
        $rest = $w.Raw.Substring($at + 1).TrimStart('|') -replace '"|''', ''
        if ($w.Bare[$at] -eq '>' -and $rest -match $FILE_AT) { return $rest }
        if (-not $rest) { $redirect = [string] $w.Bare[$at] }
    }
    if (-not $plain.Count) { return }
    $after = @($plain | Select-Object -Skip 1)
    switch -Regex ([IO.Path]::GetFileNameWithoutExtension($plain[0])) {
        '^(tee|Tee-Object)$' { return $after | Where-Object { $_ -match $FILE_AT } | Select-Object -First 1 }
        '^(Set-Content|Add-Content|Out-File)$' {
            # A -Value or -InputObject is what is written, not where.
            for ($k = 0; $k -lt $after.Count; $k++) {
                if ($after[$k] -match '^(?i)-(va|in)') { $k++; continue }
                if ($after[$k] -match $FILE_AT) { return $after[$k] }
            }
        }
        '^sed$' {
            if ($after -cmatch '^(-[^-]*i|--in-place)') { return $after | Where-Object { $_ -match $FILE_AT } | Select-Object -First 1 }
        }
        '^(cp|mv)$' {
            # PowerShell's aliases of Copy-Item and Move-Item, where an argument names one of their
            # parameters, by three letters or more, as -ErrorAction or -Destination.
            if (@($after | Where-Object { Test-ItemParameter $_ })) {
                $target = Get-ItemTarget -Arguments $after
                if ($target -match $FILE_AT) { return $target }
                return
            }
            # A target directory, -t <dir> or -t<dir>, takes every file named into it.
            if ($after -cmatch '^-t') { return }
            $target = $after | Where-Object { $_ -notlike '-*' } | Select-Object -Last 1
            if ($target -match $FILE_AT) { return $target }
        }
        '^(Copy-Item|Move-Item)$' {
            $target = Get-ItemTarget -Arguments $after
            if ($target -match $FILE_AT) { return $target }
        }
    }
}

# The target of a Copy-Item or Move-Item given $Arguments: the value of -Destination, named from
# -Des; else the second word no parameter takes, or the first where -Path or -LiteralPath is named.
# A parameter takes the word after it, but a switch: a name that is a prefix of one of the
# cmdlets' switches, or a switch's alias. A prefix of a switch and of another parameter is
# ambiguous to PowerShell, which refuses the command.
function Get-ItemTarget {
    param([string[]] $Arguments)
    $loose = [Collections.Generic.List[string]]::new()
    $pathNamed = $false
    for ($k = 0; $k -lt $Arguments.Count; $k++) {
        $a = $Arguments[$k]
        if ($a -notlike '-*') { $loose.Add($a); continue }
        # A parameter given with a colon, as -Confirm:$false or -Destination:f, holds its value.
        $joined = $a -match '^-([^:]+):(.*)$'
        $name = if ($joined) { $Matches[1] } else { $a.Substring(1) }
        $value = if ($joined) { $Matches[2] } else { $Arguments | Select-Object -Skip ($k + 1) -First 1 }
        $isSwitch = $name -in 'wi', 'cf', 'db', 'vb' -or @($ITEM_SWITCHES | Where-Object { $_.StartsWith($name, [StringComparison]::OrdinalIgnoreCase) })
        if ($isSwitch) { continue }
        if (-not $joined) { $k++ }
        if ($name -match '^(?i)des') { return $value }
        if ($name -match '^(?i)(pat|path|l|li\w*|lp|psp\w*)$') { $pathNamed = $true }
    }
    $loose | Select-Object -Skip ($pathNamed ? 0 : 1) -First 1
}

# What to do with $Command: @{ Refuse = <the file as named> }, @{ Unchecked = <why> }, or $null to
# let it through in silence.
function Get-SettingsWrite {
    param([AllowEmptyString()] [string] $Command)
    if ($Command -notmatch '(?i)\.claude[\\/]settings(?:\.local)?\.json') { return $null }
    # .NET's writers take the path inside the parentheses the words are split on.
    foreach ($m in [regex]::Matches($Command, '(?i)::(?:Write|Append)All(?:Text|Lines|Bytes)\s*\(\s*[''"]?([^''",)]+)')) {
        if ($m.Groups[1].Value -match $FILE_AT) { return @{ Refuse = $m.Groups[1].Value } }
    }
    $words = Split-ShellCommand $Command
    if ($null -eq $words) { return @{ Unchecked = 'its quotes could not be paired, so its commands could not be read' } }
    $one = [Collections.Generic.List[hashtable]]::new()
    # The commands a ( broke off, innermost last, as `Set-Content -Value (Get-Content b) -Path f`:
    # each goes on after the ) that closes its (, with one word standing for what the parentheses
    # held, so that a word after them keeps its place, as the target of
    # `Copy-Item (Resolve-Path b) f`. A ) that closes no (, as a case pattern's `a)`, ends a command
    # and continues none.
    $outer = [Collections.Generic.Stack[object]]::new()
    $resumed = $null
    $held = @{ Raw = '(...)'; Word = '(...)'; Bare = '(...)' }
    foreach ($w in @($words) + @(@{ Op = 'end' })) {
        if (-not $w.ContainsKey('Op')) { $one.Add($w); continue }
        # The assignments that lead a command, as `MSYS_NO_PATHCONV=1 sed ...`.
        $lead = 0
        while ($lead -lt $one.Count -and $one[$lead].Word -match '^\w+=') { $lead++ }
        $s = @($one | Select-Object -Skip $lead)
        $one.Clear()
        if ($null -ne $resumed) { $s = @($resumed) + @($held) + $s; $resumed = $null }
        if ($w.Op -eq '(') { $outer.Push(@($s)); continue }
        if ($w.Op -eq ')' -and $outer.Count) { $resumed = $outer.Pop() }
        if (-not $s) { continue }
        $file = Get-WrittenSetting -Words $s
        if ($file) { return @{ Refuse = $file } }
    }
    $null
}

# The JSON that tells the agent a command was let through unchecked, and why.
function Format-Unchecked {
    param([string] $Why)
    $text = "refuse-settings-write: $Why, so this command was NOT checked for a write to .claude/settings.json."
    @{ systemMessage = $text; hookSpecificOutput = @{ hookEventName = 'PreToolUse'; additionalContext = $text } } | ConvertTo-Json -Compress
}

if ($SelfTest) {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "refuse-settings-write-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    $failures = 0; $n = 0
    $check = {
        param([string] $Name, [bool] $Ok, [string] $Said)
        $script:n++
        Write-Host ("self-test {0}: {1} -- {2}" -f $script:n, $Name, $(if ($Ok) { 'ok' } else { 'FAILED' }))
        if (-not $Ok) { $script:failures++; if ($Said) { Write-Host "    $Said" } }
    }
    # A command judged, a throw caught as a verdict of its own, so that the case fails rather than
    # the self-test stopping before its summary line.
    $ask = { param([string] $c) try { Get-SettingsWrite $c } catch { @{ Threw = $_.Exception.Message } } }
    $verdict = { param($r) if (-not $r) { 'through' } elseif ($r.ContainsKey('Refuse')) { 'refused' } elseif ($r.ContainsKey('Threw')) { "threw: $($r.Threw)" } else { 'unchecked' } }
    try {
        # {f} is each settings file in turn.
        $refused = 'echo x > {f}', 'echo x >> {f}', 'echo x>{f}', 'echo x 1>"{f}"', 'echo x | tee {f}', 'echo x | tee -a {f}',
            "'x' | Tee-Object {f}", "'x' | Tee-Object -FilePath '{f}'", 'Set-Content -Path {f} -Value x', 'Set-Content {f} x',
            "'x' | Out-File -FilePath {f}", 'Add-Content -Value x {f}', "[IO.File]::WriteAllText('{f}', 'x')",
            '[System.IO.File]::WriteAllLines("{f}", $l)', "[IO.File]::WriteAllBytes( '{f}', `$b)", "[IO.File]::AppendAllText('{f}', 'x')",
            "sed -i 's/x/y/' {f}", "sed -i.bak 's/x/y/' {f}", "sed -ni 's/x/y/p' {f}", "sed --in-place=.bak 's/x/y/' {f}",
            "/usr/bin/sed -i 's/x/y/' {f}", 'cp backup.json {f}', 'mv -f backup.json {f}', 'Copy-Item backup.json {f} -Force',
            'Copy-Item -Path b.json -Destination {f}', 'Move-Item -Des {f} b.json', "MSYS_NO_PATHCONV=1 sed -i 's/x/y/' {f}",
            # PowerShell's cp and mv, a GNU cp beside them, and a parameter with a colon (turn 2, S
            # and T).
            'cp backup.json {f} -ErrorAction Stop', 'cp -Destination {f} b.json', 'mv -Destination {f} b.json', 'cp b.json {f} -Force',
            'cp -rf backup.json {f}', 'cp -rfv backup.json {f}','Copy-Item -Confirm:$false b.json {f}', 'Copy-Item b.json -Destination:{f}',
            # A case pattern's ), and parentheses two deep (PR #493's review, turn 2, R).
            'case $x in a) cp backup.json {f};; esac', 'case $x in a) sed -i s/x/y/ {f};; esac',
            'Copy-Item (Join-Path (Get-Location) b.json) {f}', 'Copy-Item (Get-Content b.json | Select-Object -First 1) {f}',
            # A redirection that opens a command, or a brace group (PR #493's review, turn 2, Q).
            '> {f}', '>{f} echo x', '{ echo x; } > {f}', '2>/dev/null cp backup.json {f}',
            # Redirections and parameters after the target (PR #493's review, finding A).
            'cp backup.json {f} 2>/dev/null', 'mv tmp.json {f} 2>&1', 'cp backup.json {f} > log.txt',
            'Copy-Item backup.json {f} -ErrorAction Stop', 'Copy-Item backup.json {f} -Exclude *.bak', 'Copy-Item -Recurse b.json {f}', 'Copy-Item -vb b.json {f}',
            'Copy-Item -wi b.json {f}', 'Copy-Item -cf b.json {f}', 'Copy-Item -db b.json {f}', 'Copy-Item (Resolve-Path b.json) {f}',
            'Copy-Item -LiteralPath b.json -Destination {f}', 'Move-Item -Path b.json {f}', 'Set-Content -Value (Get-Content b.json) -Path {f}',
            'git status && cp backup.json {f}', 'cat a.json | sed -i s/x/y/ {f}', '(cp backup.json {f})', 'cp backup.json ./{f}',
            'cp backup.json "C:\src\x\{f}"', 'cp backup.json /c/src/x/{f}', "Set-Content -Path '{b}' -Value x", 'X=1; cp backup.json {f}'
        $through = 'cat {f}', 'Get-Content {f}', 'git show HEAD:{f}', 'git diff -- {f}', 'grep hooks {f}', 'cp {f} backup.json',
            'Copy-Item {f} -Destination b.json', 'cp -t backup {f}', 'cat {f} > backup.json', 'Set-Content -Path b.json -Value {f}',
            "'x' | Out-File -InputObject {f} -FilePath b.json", 'echo "x > {f}"', "sed 's/x/y/' {f}", 'sed --debug s/x/y/ {f}',
            'echo x > {f}.bak', 'echo x > my-settings.json', 'echo x > .claude/my-settings.json', 'cp {f}.bak backup.json',
            # A source named as the target would be, and writes elsewhere (PR #493's review, A and
            # M).
            'Copy-Item backup.json -Path {f}', 'Copy-Item -Debug {f} backup.json', 'cp -tbackup {f}', 'sort < {f}', 'sort <{f}', 'Copy-Item (Resolve-Path {f}) backup.json', 'Copy-Item (Join-Path (Get-Location) {f}) backup.json',
            'cp -Path {f} -Destination backup.json', 'Copy-Item -Destination:backup.json {f}', '> backup.json < {f}',
            "[IO.File]::WriteAllText('backup.json', (Get-Content {f} -Raw))", 'cat {f} >backup.json'
        foreach ($f in '.claude/settings.json', '.claude/settings.local.json') {
            $b = $f.Replace('/', '\').ToUpperInvariant()
            foreach ($c in $refused) {
                $cmd = $c.Replace('{f}', $f).Replace('{b}', $b)
                $got = & $ask $cmd
                & $check "``$cmd``: refused, naming the file" ((& $verdict $got) -eq 'refused' -and $got.Refuse -match '(?i)settings(\.local)?\.json$') "$(& $verdict $got) $(if ($got) { $got.Values })"
            }
            foreach ($c in $through) {
                $cmd = $c.Replace('{f}', $f)
                $got = & $verdict (& $ask $cmd)
                & $check "``$cmd``: let through" ($got -eq 'through') $got
            }
        }
        $cases = [ordered]@{
            'a command that names neither file' = @('ls -la > out.txt', 'through')
            'an unpaired quote in a command that names a settings file' = @('echo "x > .claude/settings.json', 'unchecked')
            'an unpaired quote in a command that names neither file' = @('echo "x', 'through')
        }
        foreach ($name in $cases.Keys) {
            $c = $cases[$name]; $said = & $verdict (& $ask $c[0])
            & $check "${name}: $($c[1])" ($said -eq $c[1]) $said
        }
        # The script itself, with the call on stdin: a refusal is exit 2 and a reason on stderr; a
        # call it cannot read is exit 0 and the JSON on stdout; one it lets through, exit 0 and
        # nothing.
        $run = {
            param($json)
            $out = $json | & pwsh -NoProfile -File $PSCommandPath 2>&1 | Out-String
            @{ Code = $LASTEXITCODE; Text = $out }
        }
        $sRun = & $run (@{ tool_input = @{ command = 'sed -i s/x/y/ .claude/settings.json' } } | ConvertTo-Json -Compress)
        $rRun = & $run (@{ tool_input = @{ command = 'cat .claude/settings.json' } } | ConvertTo-Json -Compress)
        $bad = & $run 'not json'
        $toldBad = try { ($bad.Text | ConvertFrom-Json).hookSpecificOutput.additionalContext -match 'NOT checked' } catch { $false }
        & $check 'run on a write: exit 2, a reason naming the file and the Edit tool; on a read: exit 0 and nothing; on a call it cannot read: exit 0 and the NOT-checked JSON' ($sRun.Code -eq 2 -and $sRun.Text -match 'Refused: .*\.claude/settings\.json' -and $sRun.Text -match 'Edit tool' -and $rRun.Code -eq 0 -and -not $rRun.Text.Trim() -and $bad.Code -eq 0 -and $toldBad) "write: $($sRun.Code) $($sRun.Text) | read: $($rRun.Code) $($rRun.Text) | bad: $($bad.Code) $($bad.Text)"
        # The wiring as the session runs it, through sh, for a project that holds this script and
        # for one that does not, read from the header's first example, so the command shown is the
        # command run.
        $form = [regex]::Match((Get-Content -LiteralPath $PSCommandPath -Raw), 'i=\$\(cat\).*?esac').Value
        $wired = $form.Replace('/vendor/grado-factorio-tools/scripts/', '/scripts/')
        $sh = (Get-Command sh -ErrorAction SilentlyContinue)?.Source ?? (Join-Path (git --exec-path) '../../../usr/bin/sh.exe')
        $env:PATH = "$(Split-Path $sh)$([IO.Path]::PathSeparator)$env:PATH"
        $wire = {
            param($project, $command, $line = $wired)
            $env:CLAUDE_PROJECT_DIR = $project
            $text = (@{ tool_input = @{ command = $command } } | ConvertTo-Json -Compress) | & $sh -c $line 2>&1 | Out-String
            @{ Code = $LASTEXITCODE; Text = $text }
        }
        $tools = Split-Path $PSScriptRoot -Parent
        $wRefused = & $wire $tools 'sed -i s/x/x/ .claude/settings.json'
        $wRead = & $wire $tools 'cat .claude/settings.json'
        # The case guard matches in any case, as Windows reads the path (PR #493's review, B).
        $wUpper = & $wire $tools 'Set-Content .CLAUDE/SETTINGS.JSON x'
        $wAbsent = & $wire $temp 'sed -i s/x/x/ .claude/settings.json'
        # The missing path is named in both fields (ADR 0004).
        $toldAbsent = try {
            $parsed = $wAbsent.Text | ConvertFrom-Json
            $parsed.hookSpecificOutput.hookEventName -ceq 'PreToolUse' -and $parsed.hookSpecificOutput.additionalContext -match 'vendor/grado-factorio-tools/scripts/refuse-settings-write\.ps1 was not found' -and
                $parsed.systemMessage -ceq $parsed.hookSpecificOutput.additionalContext
        } catch { $false }
        & $check 'the first example''s command refuses with exit 2 and a reason, a path in capitals too, passes a read, and where the script is not there exits 0 and prints JSON naming the missing path to the agent' ($wRefused.Code -eq 2 -and $wRefused.Text -match 'Refused' -and $wUpper.Code -eq 2 -and $wRead.Code -eq 0 -and -not $wRead.Text.Trim() -and $wAbsent.Code -eq 0 -and $toldAbsent) "refused: $($wRefused.Code) $($wRefused.Text) | read: $($wRead.Code) $($wRead.Text) | absent: $($wAbsent.Code) $($wAbsent.Text)"
        # The wiring a settings file holds, found by this script's name wherever it stands among
        # the PreToolUse entries (#315 ruling 3): this repository's own unless -Settings names one.
        . "$PSScriptRoot/hook-matcher.ps1"
        $Settings = (Resolve-Path -LiteralPath ($Settings ? $Settings : (Join-Path $PSScriptRoot '../.claude/settings.json'))).Path
        $read = Get-HookWiring -Event PreToolUse -Script (Split-Path $PSCommandPath -Leaf) -Path $Settings
        $sRefused = $sRead = $sUpper = $null
        if ($read.Command) {
            $project = Split-Path (Split-Path $Settings -Parent) -Parent
            $sRefused = & $wire $project 'sed -i s/x/x/ .claude/settings.json' $read.Command
            $sUpper = & $wire $project 'Set-Content .CLAUDE/SETTINGS.JSON x' $read.Command
            $sRead = & $wire $project 'cat .claude/settings.json' $read.Command
        }
        & $check "the command $Settings wires refuses with exit 2 and a reason, a path in capitals too, and passes a read" ($sRefused -and $sRefused.Code -eq 2 -and $sRefused.Text -match 'Refused' -and $sUpper.Code -eq 2 -and $sRead.Code -eq 0 -and -not $sRead.Text.Trim()) $(if (-not $read.Command) { "$Settings wires no command that names this script" } else { "refused: $($sRefused.Code) $($sRefused.Text) | read: $($sRead.Code) $($sRead.Text)" })
        $unstarted = @(if ($read.Entries) { Get-UnstartedShellTool -Entry $read.Entries })
        & $check 'the matcher of the entry that wires the hook starts it for the Bash tool and for the PowerShell tool' ($read.Entries -and -not $unstarted) $(if ($read.Entries) { "$Settings`: the matcher $(Get-EntryMatcher $read.Entries) does not start the hook for $($unstarted -join ' or ')" } else { "$Settings wires no entry that names this script" })
    }
    finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $n case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $n cases."
    exit 0
}

try {
    $call = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $verdict = Get-SettingsWrite -Command ([string] $call.tool_input.command)
}
catch { $verdict = @{ Unchecked = "the tool call could not be read ($($_.Exception.Message))" } }
if ($verdict -and $verdict.ContainsKey('Unchecked')) { Format-Unchecked $verdict.Unchecked; exit 0 }
if ($verdict) {
    [Console]::Error.WriteLine(@"
Refused: this command writes $($verdict.Refuse) from the shell, so the session's own checks on that
file are never asked. Make the change with the Edit tool, so that they are.
"@)
    exit 2
}
exit 0
