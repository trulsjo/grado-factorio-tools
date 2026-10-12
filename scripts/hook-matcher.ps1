#Requires -Version 7
<#
    Whether a session hook's `matcher` starts the hook for a tool, for the -SelfTest of the two
    session hooks here, refuse-cd-into-mod-cache.ps1 and refuse-git-hook-skip.ps1
    (grado-factorio-tools#120). Dot-source it:

        . "$PSScriptRoot/hook-matcher.ps1"
        Get-UnstartedShellTool -Entry $settings.hooks.PreToolUse[0]

    WHY. Each of those self-tests ran the command a .claude/settings.json wires and read nothing
    else of the entry. With the matcher narrowed from `Bash|PowerShell` to `Bash` both passed
    (2026-10-12), while a session would no longer start the hook for the PowerShell tool.

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

    WHAT -SelfTest MEANS HERE. Run as a script with -SelfTest, it holds Test-HookMatcher to a
    table of matchers. Exit 0 means the function reads those as the reference's words above say.

    WHAT IT CANNOT SEE. Whether the client does what its reference says: no session was run with
    a narrowed matcher. Case: the reference says "exact" and no more, and this compares in exact
    case. Where JavaScript's regular expressions and .NET's differ: the pattern is given to .NET
    with its ECMAScript option, and one .NET cannot compile counts as starting nothing. Any
    other key of the entry, and so a handler's `if`, which narrows further. A hook wired by one
    entry for each tool: only the entry it is handed is read. Settings in another file than the
    one it is handed, and a session whose hooks are turned off.
#>

function Test-HookMatcher {
    <#  Whether a hook entry with $Matcher is started for the tool named $Tool. $null is an
        entry with no matcher.  #>
    param([AllowNull()] $Matcher, [Parameter(Mandatory)] [string] $Tool)

    if ($null -eq $Matcher -or [string] $Matcher -in '', '*') { return $true }
    if ($Matcher -cmatch '^[A-Za-z0-9_\- ,|]+$') { return $Tool -cin ($Matcher -split '[|,]').Trim() }
    try { [regex]::IsMatch($Tool, $Matcher, 'ECMAScript') } catch { $false }
}

function Get-UnstartedShellTool {
    <#  The shell tools the matcher of $Entry, one entry of hooks.PreToolUse, does not start its
        hooks for. Nothing when it starts them for both.  #>
    param([Parameter(Mandatory)] $Entry)

    $matcher = $Entry.PSObject.Properties['matcher']?.Value
    'Bash', 'PowerShell' | Where-Object { -not (Test-HookMatcher -Matcher $matcher -Tool $_) }
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
        @('(Bash', 'Bash', $false)
    )
    $failures = 0
    $n = 0
    $total = $cases.Count + 1
    foreach ($c in $cases) {
        $n++
        $ok = (Test-HookMatcher -Matcher $c[0] -Tool $c[1]) -eq $c[2]
        Write-Host ("self-test {0}/{1}: {2} {3} for {4} -- {5}" -f $n, $total,
            $(if ($null -eq $c[0]) { 'no matcher' } else { "matcher ``$($c[0])``" }),
            $(if ($c[2]) { 'starts the hook' } else { 'does not start the hook' }), $c[1], $(if ($ok) { 'ok' } else { 'FAILED' }))
        if (-not $ok) { $failures++ }
    }
    $n++
    $gaps = { param($json) @(Get-UnstartedShellTool -Entry ($json | ConvertFrom-Json)) -join ',' }
    $ok = (& $gaps '{"matcher":"Bash|PowerShell","hooks":[]}') -eq '' -and (& $gaps '{"hooks":[]}') -eq '' -and
        (& $gaps '{"matcher":"Bash","hooks":[]}') -eq 'PowerShell' -and (& $gaps '{"matcher":"PowerShell","hooks":[]}') -eq 'Bash' -and
        (& $gaps '{"matcher":"Edit|Write","hooks":[]}') -eq 'Bash,PowerShell'
    Write-Host ("self-test {0}/{1}: an entry names the shell tools its matcher leaves out, and none where it has no matcher -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
    if (-not $ok) { $failures++ }
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $total case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $total cases."
    exit 0
}
