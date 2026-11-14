#Requires -Version 7
<#
    Two jobs for a session hook's -SelfTest: which entries of a .claude/settings.json wire the hook
    (Get-HookWiring, grado-factorio-tools#461), and whether their `matcher` starts it for a tool
    (Test-HookMatcher and Get-UnstartedShellTool, #120). Dot-source it:

        . "$PSScriptRoot/hook-matcher.ps1"
        $leaf = Split-Path $PSCommandPath -Leaf
        $read = Get-HookWiring -Path $Settings -Event PreToolUse -Script $leaf
        Get-UnstartedShellTool -Entry $read.Entries

    ONE READER (#461). Each hook's self-test kept its own copy of the reader until #461. Six read
    `.hooks.PreToolUse` bare, which strict mode throws on in a file with no such key, and every copy
    took the first entry naming the script, so a wiring of one entry per shell tool was told one
    tool was not started (PR #460's review). Get-HookWiring reads each key where it stands, takes
    the first command that names the script by its whole file name, and returns every entry that
    runs that command. An entry naming the script in another command is left out (PR #465's
    review): the self-tests run the one command, so that entry's matcher would be credited with a
    command no test ran.

    WHY. Each session hook's self-test here, on 2026-10-12, ran the command a .claude/settings.json
    wires and read nothing else of the entry. With the matcher narrowed from `Bash|PowerShell` to
    `Bash` each passed (2026-10-12), while a session would no longer start the hook for the
    PowerShell tool.

    THE RULE IS THE CLIENT'S, READ 2026-10-12 from *Matcher patterns* in Claude Code's hooks
    reference, https://code.claude.com/docs/en/hooks, and Test-HookMatcher follows it:

      - `"*"`, `""`, or omitted: "Match all".
      - "Only letters, digits, `_`, `-`, spaces, `,`, and `|`": "Exact string, or list of exact
        strings separated by `|` or `,` with optional surrounding whitespace".
      - "Contains any other character": "JavaScript regular expression, unanchored", "which
        succeeds on a match anywhere in the value".
      - "For tool events, that field is `tool_name`."

    So `BashOutput` does not start a hook for Bash, and `Bash.*` does.

    BOTH SHELL TOOLS ARE DEMANDED, Bash and PowerShell, ruled by Truls 2026-10-12: a session on
    Windows has both, and a hook wired for one is gone round with the other.

    WHAT -SelfTest MEANS HERE. Run as a script with -SelfTest, it holds Test-HookMatcher to a table
    of matchers, Get-UnstartedShellTool to six entries and to a wiring of two, and Get-HookWiring to
    settings files with no hooks key, no key for the event, an event that is no list, a first entry
    wiring another script, two entries running the script's command, a longer name holding the
    script's, and an entry naming the script in another command. Exit 0 means the matchers are read
    as the reference's words above say and, where it says nothing, as chosen here: names are
    compared in exact case, a matcher of spaces alone starts nothing, and neither does one that is
    no string or a pattern .NET cannot compile; and that the wiring is every entry running the
    first command that names the script, read without a throw.

    WHAT IT CANNOT SEE. Whether the client does what its reference says: no session was run with a
    narrowed matcher. Where JavaScript's regular expressions and .NET's differ: the pattern is given
    to .NET with its ECMAScript option, and one that .NET compiles and JavaScript refuses, as
    `(?i)bash|powershell` is (grado-factorio-tools#120's review, 2026-10-12), is read here as .NET
    reads it. Any other key of the entry, and so a handler's `if`, which narrows further. A script
    named in a command by anything but its whole file name, as through a variable. Whether a
    command naming the script, other than the first, runs it: its entry is left out, so a tool only
    such an entry starts is told unstarted. Settings in another file than the one the entries came
    from, and a session whose hooks are turned off.
#>

function Test-HookMatcher {
    <#  Whether a hook entry with $Matcher is started for the tool named $Tool. $null is an entry
        with no matcher.  #>
    param([AllowNull()] $Matcher, [Parameter(Mandatory)] [string] $Tool)

    if ($null -eq $Matcher) { return $true }
    if ($Matcher -isnot [string]) { return $false }
    if ($Matcher -in '', '*') { return $true }
    # \z and not $, which .NET also matches before a last newline: that matcher is a pattern.
    if ($Matcher -cmatch '\A[A-Za-z0-9_\- ,|]+\z') { return $Tool -cin ($Matcher -split '[|,]').Trim() }
    try { [regex]::IsMatch($Tool, $Matcher, 'ECMAScript') } catch { $false }
}

function Get-UnstartedShellTool {
    <#  The shell tools that no entry of $Entry, entries of hooks.PreToolUse, starts its hooks for
        by its matcher: a tool one entry leaves out and another starts is started. Nothing when they
        start both; both when $Entry is empty.  #>
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Entry)

    # A loop, not a pipeline: a matcher that is a list would be unrolled into its strings.
    foreach ($tool in 'Bash', 'PowerShell') {
        $started = $false
        foreach ($e in $Entry) { if (Test-HookMatcher -Matcher $e.PSObject.Properties['matcher']?.Value -Tool $tool) { $started = $true } }
        if (-not $started) { $tool }
    }
}

function Get-EntryMatcher {
    <#  The matchers of $Entry, as a failure line prints them: each in backticks, `none` for an
        entry with no matcher.  #>
    param([AllowEmptyCollection()] [object[]] $Entry)
    @($Entry | ForEach-Object { $m = $_.PSObject.Properties['matcher']?.Value; if ($null -eq $m) { 'none' } else { "``$m``" } }) -join ', '
}

function Get-HookWiring {
    <#  The wiring the settings file $Path holds for the script named $Script under the hook event
        $Event: Command, the first command of that event's entries that names the script by its
        whole file name; and Entries, every entry with that command, in the file's order. Each key
        is read only where it stands, so a file with no hooks key, no key for the event, an event
        that is no list, or no entry naming the script gives no entries and an empty command, and
        throws only where it is no JSON.  #>
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Event,
        [Parameter(Mandatory)] [string] $Script
    )
    # The whole file name: no word character, dot or hyphen on either side of it.
    $names = "(?<![\w.-])$([regex]::Escape($Script))(?![\w.-])"
    $field = { param($object, [string] $key) if ($object -is [psobject]) { $object.PSObject.Properties[$key]?.Value } }
    # The commands of one entry that name the script, each read from its own handler.
    $naming = { param($entry) @(@(& $field $entry 'hooks') | ForEach-Object { & $field $_ 'command' } | Where-Object { $_ -is [string] -and $_ -match $names }) }
    $settings = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    # An event that is no list of entries holds none. Assigned in place, not taken from $field or
    # an if as their output, which would unroll a list of one entry into no list.
    $hooks = & $field $settings 'hooks'
    $listed = $null
    if ($hooks -is [psobject]) { $listed = $hooks.PSObject.Properties[$Event]?.Value }
    $all = @()
    if ($listed -is [array]) { $all = $listed }
    $first = @($all | ForEach-Object { & $naming $_ }) | Select-Object -First 1
    $command = if ($null -eq $first) { '' } else { [string] $first }
    # Only the entries that run that command: the self-tests run it and nothing else.
    $entries = @(if ($command) { $all | Where-Object { @(& $naming $_) -ccontains $command } })
    @{ Entries = $entries; Command = $command }
}

# Only when run as a script. Dot-sourced, InvocationName is '.', and a caller's own -SelfTest is
# not this one. No param block, because dot-sourcing one would overwrite the caller's $SelfTest.
if ($MyInvocation.InvocationName -ne '.' -and $args -contains '-SelfTest') {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    # Each: the matcher, the tool, and whether the hook is started for it.
    $cases = @(
        @('Bash|PowerShell', 'Bash', $true),
        @('Bash|PowerShell', 'PowerShell', $true),
        @('Bash', 'Bash', $true),
        @('Bash', 'PowerShell', $false),
        @('PowerShell', 'Bash', $false),
        @('Bash, PowerShell', 'PowerShell', $true),
        @(' Bash | PowerShell ', 'Bash', $true),
        @('Edit|Write|PowerShell,Bash', 'Bash', $true),
        @('BashOutput|PowerShell', 'Bash', $false),
        @('BashOutput|PowerShell', 'PowerShell', $true),
        @('Bash|PowerShellScript', 'PowerShell', $false),
        @('bash|powershell', 'Bash', $false),
        @('Edit|Write', 'PowerShell', $false),
        @('*', 'PowerShell', $true),
        @('', 'Bash', $true),
        @($null, 'PowerShell', $true),
        @(' ', 'Bash', $false),
        @('.*', 'PowerShell', $true),
        @('Bash.*', 'Bash', $true),
        @('Bash.*', 'PowerShell', $false),
        @('BashOutput.*', 'Bash', $false),
        @('Shell$', 'PowerShell', $true),
        @('Shell$', 'Bash', $false),
        @('^(Bash|PowerShell)$', 'PowerShell', $true),
        @('^Bash$|^PowerShell$', 'Bash', $true),
        @('^bash$', 'Bash', $false),
        @('Edit.*', 'NotebookEdit', $true),
        @('^Notebook', 'NotebookEdit', $true),
        @('mcp__memory', 'mcp__memory__create_entities', $false),
        @('mcp__memory__.*', 'mcp__memory__create_entities', $true),
        @('(Bash', 'Bash', $false),
        @("Bash|PowerShell`n", 'Bash', $true),
        @("Bash|PowerShell`n", 'PowerShell', $false)
    )
    $failures = 0
    $n = 0
    $total = $cases.Count + 7
    foreach ($c in $cases) {
        $n++
        $ok = (Test-HookMatcher -Matcher $c[0] -Tool $c[1]) -eq $c[2]
        Write-Host ("self-test {0}/{1}: {2} {3} for {4} -- {5}" -f $n, $total,
            $(if ($null -eq $c[0]) { 'no matcher' } else { "matcher ``$($c[0] -replace '\n', '\n')``" }),
            $(if ($c[2]) { 'starts the hook' } else { 'does not start the hook' }), $c[1], $(if ($ok) { 'ok' } else { 'FAILED' }))
        if (-not $ok) { $failures++ }
    }
    $n++
    $gaps = { param($json) @(Get-UnstartedShellTool -Entry ($json | ConvertFrom-Json)) -join ',' }
    $ok = (& $gaps '{"matcher":"Bash|PowerShell","hooks":[]}') -eq '' -and (& $gaps '{"hooks":[]}') -eq '' -and
        (& $gaps '{"matcher":"Bash","hooks":[]}') -eq 'PowerShell' -and (& $gaps '{"matcher":"PowerShell","hooks":[]}') -eq 'Bash' -and
        (& $gaps '{"matcher":"Edit|Write","hooks":[]}') -eq 'Bash,PowerShell' -and
        (& $gaps '{"matcher":["Bash","PowerShell"],"hooks":[]}') -eq 'Bash,PowerShell'
    Write-Host ("self-test {0}/{1}: an entry names the shell tools its matcher leaves out, both where the matcher is no string, and none where it has no matcher -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
    if (-not $ok) { $failures++ }
    # Get-HookWiring, on settings files written to a scratch file. Each case gives what it read,
    # or the throw.
    $file = Join-Path ([IO.Path]::GetTempPath()) "hook-matcher-$([guid]::NewGuid().ToString('N').Substring(0, 8)).json"
    $wiring = {
        param([string] $json, [string] $event = 'PreToolUse')
        Set-Content -LiteralPath $file -Value $json
        try { Get-HookWiring -Path $file -Event $event -Script 'the-hook.ps1' } catch { @{ Entries = @(); Command = "threw: $($_.Exception.Message)" } }
    }
    try {
        $n++
        $noHooks = & $wiring '{"permissions":{}}'
        $noEvent = & $wiring '{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"pwsh -File the-hook.ps1"}]}]}}'
        $noName = & $wiring '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"echo other"},{"type":"prompt"}]},{"matcher":"Bash"}]}}'
        $ok = -not $noHooks.Entries -and $noHooks.Command -ceq '' -and -not $noEvent.Entries -and $noEvent.Command -ceq '' -and
            -not $noName.Entries -and $noName.Command -ceq ''
        Write-Host ("self-test {0}/{1}: a settings file with no hooks key, one with no key for the event, and one whose entries name another script or have no command, wire none, and none throws -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
        if (-not $ok) { $failures++; foreach ($r in $noHooks, $noEvent, $noName) { Write-Host "    $(@($r.Entries).Count) entries, command '$($r.Command)'" } }
        $n++
        $second = & $wiring '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"echo other"}]},{"matcher":"Bash|PowerShell","hooks":[{"type":"command","command":"echo first"},{"type":"command","command":"pwsh -File scripts/the-hook.ps1"}]}]}}'
        $ok = @($second.Entries).Count -eq 1 -and $second.Entries[0].matcher -ceq 'Bash|PowerShell' -and $second.Command -ceq 'pwsh -File scripts/the-hook.ps1'
        Write-Host ("self-test {0}/{1}: the wiring is the entry whose command names the script, not the first entry, and its command is the one that names it, not the entry's first -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
        if (-not $ok) { $failures++; Write-Host "    $(@($second.Entries).Count) entries, command '$($second.Command)'" }
        $n++
        $split = & $wiring '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"pwsh -File scripts/the-hook.ps1"}]},{"matcher":"PowerShell","hooks":[{"type":"command","command":"pwsh -File scripts/the-hook.ps1"}]}]}}'
        $gapsSplit = @(Get-UnstartedShellTool -Entry $split.Entries)
        $ok = @($split.Entries).Count -eq 2 -and -not $gapsSplit -and $split.Command -ceq 'pwsh -File scripts/the-hook.ps1' -and
            (Get-EntryMatcher $split.Entries) -ceq '`Bash`, `PowerShell`'
        Write-Host ("self-test {0}/{1}: a wiring of two entries naming the script, matcher Bash and matcher PowerShell, is read whole and starts the hook for both shell tools -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
        if (-not $ok) { $failures++; Write-Host "    $(@($split.Entries).Count) entries, unstarted: $($gapsSplit -join ', ')" }
        $n++
        $session = & $wiring '{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"pwsh -File the-hook.ps1 -Root ."}]}]}}' 'SessionStart'
        $noArray = & $wiring '{"hooks":{"PreToolUse":{"matcher":"Bash","hooks":[{"type":"command","command":"pwsh -File the-hook.ps1"}]}}}'
        $ok = @($session.Entries).Count -eq 1 -and $session.Command -ceq 'pwsh -File the-hook.ps1 -Root .' -and -not $noArray.Entries -and
            @(Get-UnstartedShellTool -Entry @()).Count -eq 2
        Write-Host ("self-test {0}/{1}: the event is the one given, SessionStart read as PreToolUse is; an event that is no list of entries wires none; no entries start neither shell tool -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
        if (-not $ok) { $failures++; Write-Host "    session: '$($session.Command)', not a list: '$($noArray.Command)'" }
        $n++
        # The name is the file's whole name: a longer name holding it, or a backup of it, is
        # another script, and its entry's matcher is not this hook's. Those entries come first,
        # so a name matched inside another would be taken as the command.
        $longer = & $wiring '{"hooks":{"PreToolUse":[{"matcher":"PowerShell","hooks":[{"type":"command","command":"pwsh -File scripts/my-the-hook.ps1"}]},{"matcher":"PowerShell","hooks":[{"type":"command","command":"pwsh -File scripts/the-hook.ps1.bak"}]},{"matcher":"Bash","hooks":[{"type":"command","command":"pwsh -File \"vendor\\tools\\scripts\\the-hook.ps1\" -Root ."}]}]}}'
        $gapsLonger = @(Get-UnstartedShellTool -Entry $longer.Entries) -join ','
        $ok = @($longer.Entries).Count -eq 1 -and $longer.Command -ceq 'pwsh -File "vendor\tools\scripts\the-hook.ps1" -Root .' -and $gapsLonger -ceq 'PowerShell'
        Write-Host ("self-test {0}/{1}: a command names the script by its whole file name, after a slash, a backslash or a space; my-the-hook.ps1 and the-hook.ps1.bak name another, whose entry starts nothing for it -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
        if (-not $ok) { $failures++; Write-Host "    $(@($longer.Entries).Count) entries, command '$($longer.Command)', unstarted: $gapsLonger" }
        $n++
        # The self-tests run Command alone, so an entry whose command naming the script is another
        # is not the wiring they ran, and its matcher starts nothing for it.
        $other = & $wiring '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"pwsh -File scripts/the-hook.ps1"}]},{"matcher":"PowerShell","hooks":[{"type":"command","command":"echo scripts/the-hook.ps1"}]}]}}'
        $gapsOther = @(Get-UnstartedShellTool -Entry $other.Entries) -join ','
        $ok = @($other.Entries).Count -eq 1 -and $other.Command -ceq 'pwsh -File scripts/the-hook.ps1' -and $gapsOther -ceq 'PowerShell'
        Write-Host ("self-test {0}/{1}: an entry whose command naming the script is not the command the wiring runs is not read as wiring it, so its matcher starts no tool -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
        if (-not $ok) { $failures++; Write-Host "    $(@($other.Entries).Count) entries, command '$($other.Command)', unstarted: $gapsOther" }
    }
    finally { Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue }
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $total case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $total cases."
    exit 0
}
