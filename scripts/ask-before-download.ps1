<#
.SYNOPSIS
    A hook for agent sessions: refuses a shell command that installs a package or fetches a program
    from anywhere but mods.factorio.com and the hosts -AllowedHost adds, and tells the session to
    ask Truls. It prints the reason to stderr and exits 2; for any other command it prints nothing
    and exits 0. Exit 1 says on stderr that the tool call could not be read, and the command runs.

.DESCRIPTION
    WHERE IT CAME FROM (grado-factorio-tools#353, #323 ruling 1). grado-factorio-modpack's
    scripts/ask-before-download.ps1 at 0653339, read 2026-11-06. What changed in the move: the
    allowed host is -AllowedHost, mods.factorio.com unless more are given; the self-test finds the
    wiring by this script's name in the settings file -Settings names, not by its place there (#315
    ruling 3), and runs the first example's missing-script branch; its cases name no file of that
    repository.

    WHY (grado-factorio-modpack#179). On 2026-10-07 a subagent surveying Markdown linters fetched
    five binaries from GitHub releases, and Node, Python and Ruby packages, into the session's
    scratch directory and ran them on this machine. Truls was told after. The rule, in each
    consumer's CLAUDE.md: a session asks before it downloads a program and runs it here.

    HOW A CONSUMER WIRES IT. In its tracked .claude/settings.json, a PreToolUse hook on the two
    shell tools, matcher `Bash|PowerShell`, whose command is the first example below. The session
    hands the hook the tool call as JSON on stdin: this reads `tool_input.command`. The `case`
    starts this script only when that JSON holds one of its words, since starting PowerShell takes a
    second and the hook runs before every shell command. Where the script is not there, as in a
    clone whose submodule was never fetched, the wired command lets the shell command run and prints
    JSON that tells the agent it was not checked. A consumer that allows another host names it after
    `-AllowedHost` on its own line, as #315 ruling 5 has it. This repository wires it from scripts/.

    WHAT IT REFUSES. Standing where a command can stand: npm install, i, ci, add or exec; npx; pip
    install, also as python -m pip; gem install; cargo install; winget, choco and scoop install; gh
    release download. And a command holding curl, wget, iwr, irm, Invoke-WebRequest,
    Invoke-RestMethod, Start-BitsTransfer or DownloadFile with an http address that ends in .exe,
    .msi, .zip, .tar.gz or .tgz and whose host is not an allowed one.

    WHY IT REFUSES AND DOES NOT ASK. It first answered with a permission decision of "ask". Measured
    2026-10-08 in a session in auto mode, Claude Code 2.1.292, with `npx --version`: the session's
    debug log shows the hook's "ask" taken ("Hook result has permissionBehavior=ask") and then "Slow
    permission decision: 4386ms for Bash (mode=auto, behavior=allow)". The command ran and Truls saw
    no prompt. What "ask" does in another mode was not measured. A refusal by exit 2 is what
    refuse-cd-into-mod-cache.ps1 does. The hook has no switch for a session to set: once Truls has
    said yes he runs it himself, with the `!` prefix at the prompt. The refusal was measured in the
    same session after the change: `npx --version` did not run and the session was shown the reason.

    WHAT IT LETS THROUGH. Everything else, and so a repository's own work: a read of the portal API,
    a mod fetched from the portal, the scripts in vendor/grado-factorio-tools, gh and git. A mod is
    Lua the game runs; grado-factorio-modpack#179 takes fetching one as the project's work and not
    as downloading a program.

    WHAT IT CANNOT SEE. A download made by a script or program it lets through. One made by a
    subagent in a session without this hook, or by a session started outside a repository that wires
    it. Another package manager (pnpm, yarn, pipx, uv, go, dotnet tool, Install-Module), a git clone
    of a program, and an address that does not end in one of the five endings or is built from a
    variable. An installer or fetcher named in another case than the wiring's words, named with .exe
    or .cmd, or reached through cmd /c, sudo, an alias or a full path. An install that opens a
    quoted string, as in bash -c "npm install x", and one with a flag between the program and
    `install`. It reads the command as text and does not parse the shell, so `npm install` is
    refused inside a quoted string too when it follows a newline or a separator there. The cost:
    prose handed to the shell, a commit message or a pull request body in a heredoc, is refused when
    one of its lines opens with a matched command, so pass such text as a file (git commit -F, gh pr
    edit --body-file). And whether the settings still reach it, unless -SelfTest is run on them.

    TO CHECK IT, run the second example below.

.PARAMETER AllowedHost
    Hosts a program may be fetched from besides mods.factorio.com, comma-separated, each matched
    whole and in any case.

.PARAMETER SelfTest
    Prove it refuses what it should and lets the rest through: first by this script's own pattern,
    an added host included, then with every refused case sent through the wired command, so that a
    refused case the wiring never hands over turns the self-test red (grado-factorio-modpack#190).
    Each of the wiring's words has a refused case that holds no other of them, which the self-test
    checks (grado-factorio-modpack#196). The first example's form, run for a project with no hook
    script, exits 0 and prints JSON telling the agent; and the matchers of the entries that wire it
    start it for both shell tools. The wired cases need sh: the one on the path, or the one Git for
    Windows ships. It prints how long it took.

.PARAMETER Settings
    With -SelfTest: the .claude/settings.json whose PreToolUse command naming this script the wired
    cases run, with that file's repository as the project. Defaults to this repository's own. A
    consumer runs it on its own file to know its wiring still reaches the hook.

.EXAMPLE
    The wired command: the PreToolUse hook a consumer puts in its .claude/settings.json, as HOW A
    CONSUMER WIRES IT says.

        i=$(cat); case $i in *npm*|*npx*|*pip*|*gem*|*cargo*|*winget*|*choco*|*scoop*|*release*download*|*.exe*|*.msi*|*.zip*|*.tar.gz*|*.tgz*) h="$CLAUDE_PROJECT_DIR/vendor/grado-factorio-tools/scripts/ask-before-download.ps1"; if [ -f "$h" ]; then printf '%s' "$i" | pwsh -NoProfile -File "$h"; else m='ask-before-download: vendor/grado-factorio-tools/scripts/ask-before-download.ps1 was not found, so this command was NOT checked by the download hook. git submodule update --init fetches the script.'; printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}' "$m" "$m"; fi;; esac

.EXAMPLE
    To check it. The first is refused with exit 2, the second passes with exit 0:

        '{"tool_input":{"command":"npm install -g markdownlint-cli"}}' | pwsh -NoProfile -File scripts/ask-before-download.ps1; $LASTEXITCODE
        '{"tool_input":{"command":"gh issue view 179"}}' | pwsh -NoProfile -File scripts/ask-before-download.ps1; $LASTEXITCODE
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string[]] $AllowedHost = @(),
    [switch] $SelfTest,
    [string] $Settings
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Under pwsh -File, -AllowedHost a,b arrives as one string.
$AllowedHost = @($AllowedHost | ForEach-Object { $_ -split ',' } | ForEach-Object Trim | Where-Object { $_ })

function Get-Download {
    <#  What $Command would install or fetch, as a phrase for the reason, or nothing. A fetch from
        mods.factorio.com or a host in $Allowed is not one.  #>
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Command,
        [string[]] $Allowed = @()
    )

    $install = [regex]::Match($Command,
        '(?:^|[;&|({\n]|\b(?:then|do|else|if|elif|while|until)\s)\s*((?:npm\s+(?:install|i|ci|add|exec)|npx|(?:py(?:thon[\d.]*)?\s+-m\s+)?pip[\d.]*\s+install|gem\s+install|cargo\s+install|(?:winget|choco|scoop)\s+install|gh\s+release\s+download)\b)', 'IgnoreCase')
    if ($install.Success) { return "installs or downloads a package ($($install.Groups[1].Value -replace '\s+', ' '))" }
    if ($Command -notmatch '\b(curl|wget|iwr|irm|Invoke-WebRequest|Invoke-RestMethod|Start-BitsTransfer|DownloadFile)\b') { return }
    $hosts = @('mods.factorio.com') + $Allowed
    foreach ($url in [regex]::Matches($Command, 'https?://([^/\s"''`]+)[^\s"''`]*?\.(?:exe|msi|zip|tar\.gz|tgz)(?![\w./-])', 'IgnoreCase')) {
        if ($url.Groups[1].Value -notin $hosts) { return "fetches $($url.Value)" }
    }
}

if ($SelfTest) {
    # Each: the command, and whether it is refused.
    $cases = @(
        @('npm install -g markdownlint-cli', $true),
        @('cd tools && npm i remark-cli', $true),
        @('npx markdownlint-cli2 "**/*.md"', $true),
        @('pip install pymarkdownlnt', $true),
        @('python -m pip install --user mdformat', $true),
        @('gem install mdl', $true),
        @('cargo install rumdl', $true),
        @('winget install --id Rustlang.Rustup', $true),
        @('choco install ruby -y', $true),
        @('scoop install vale', $true),
        @('gh release download v0.0.150 -R rvben/rumdl', $true),
        @('curl -L -o rumdl.zip https://github.com/rvben/rumdl/releases/download/v0.0.150/rumdl-x86_64-pc-windows-msvc.zip', $true),
        @('Invoke-WebRequest "https://example.com/tool.exe" -OutFile tool.exe', $true),
        @('wget https://example.com/linter.tar.gz', $true),
        @('iwr https://example.com/setup.msi -OutFile setup.msi; Start-Process setup.msi', $true),
        @('curl -LO https://example.com/tool.zip; unzip tool.zip', $true),
        @('curl -sL https://example.com/tool.tgz|tar xz', $true),
        @('curl -LO https://www.factorio.com/get-download/2.0.77/alpha/win64-manual.zip', $true),
        @('curl -s https://mods.factorio.com/api/mods/flib/full', $false),
        @("Invoke-RestMethod 'https://mods.factorio.com/api/mods?page_size=max&version=2.0'", $false),
        @('curl -L -o flib.zip "https://MODS.factorio.com/download/flib/5f7b2c?username=u&token=t.zip"', $false),
        @('pwsh -File vendor/grado-factorio-tools/scripts/fetch-mods.ps1 a-set', $false),
        @('pwsh -File vendor/grado-factorio-tools/scripts/get-dump.ps1 .mod-cache/a-set -With space-age', $false),
        @('gh issue view 179 --json title,body,comments', $false),
        @('gh pr create --title "x" --body "y"', $false),
        @('git fetch origin && git status', $false),
        @('git commit -m "ask before npm install runs"', $false),
        @('echo pip install nothing', $false),
        @('npm test', $false),
        @('curl -s https://example.com/page.html', $false),
        @('ls .mod-cache/a-set/.zips/flib_0.16.5.zip', $false),
        @('', $false)
    )
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $failures = 0
    $n = 0
    $refused = @($cases | Where-Object { $_[1] })
    $total = $cases.Count + $refused.Count + 8
    foreach ($c in $cases) {
        $n++
        $ok = [bool] (Get-Download -Command $c[0]) -eq $c[1]
        Write-Host ("self-test {0}/{1}: {2}: `{3}` -- {4}" -f $n, $total, $(if ($c[1]) { 'refused' } else { 'allowed' }), $c[0], $(if ($ok) { 'ok' } else { 'FAILED' }))
        if (-not $ok) { $failures++ }
    }
    # A host the caller adds: let through with it, refused without, and the default still allowed.
    $n++
    $extra = 'curl -LO https://dl.example.org/tool.zip'
    $ok = -not (Get-Download -Command $extra -Allowed 'DL.example.org') -and [bool] (Get-Download -Command $extra) -and
        -not (Get-Download -Command 'curl -LO https://mods.factorio.com/a.zip' -Allowed 'dl.example.org') -and
        [bool] (Get-Download -Command 'curl -LO https://other.example.org/a.zip' -Allowed 'dl.example.org')
    Write-Host ("self-test {0}/{1}: a host -AllowedHost adds is let through in any case, refused without it, and the portal stays allowed beside it -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
    if (-not $ok) { $failures++ }
    # The wiring as the session runs it: the command the settings file wires for this script,
    # found by name, through sh, with the tool call on stdin. Exit 2 and a reason for every
    # refused case, exit 0 and silence for a portal read and a plain command.
    $Settings = (Resolve-Path -LiteralPath ($Settings ? $Settings : (Join-Path $PSScriptRoot '../.claude/settings.json'))).Path
    # The case for -Settings below runs this with the variable set, to read which file it took.
    if ($env:ASK_BEFORE_DOWNLOAD_SETTINGS_PROBE) { Write-Host "settings: $Settings"; exit 3 }
    $project = Split-Path (Split-Path $Settings -Parent) -Parent
    $names = [regex]::Escape((Split-Path $PSCommandPath -Leaf))
    # The entry is found by the script's name, wherever it stands among the PreToolUse entries.
    . "$PSScriptRoot/hook-matcher.ps1"
    $read = Get-HookWiring -Event PreToolUse -Script (Split-Path $PSCommandPath -Leaf) -Path $Settings
    $entry = $read.Entries
    $wired = $read.Command
    $env:CLAUDE_PROJECT_DIR = $project
    # Git for Windows keeps its sh, and the cat beside it, off the path PowerShell sees.
    $sh = (Get-Command sh -ErrorAction SilentlyContinue)?.Source ?? (Join-Path (git --exec-path) "../../../usr/bin/sh.exe")
    $env:PATH = "$(Split-Path $sh)$([IO.Path]::PathSeparator)$env:PATH"
    $through = {
        param($command, $form = $wired, $at = $project)
        $text = (@{ cwd = $at; tool_input = @{ command = $command } } | ConvertTo-Json -Compress) | & $sh -c $form 2>&1 | Out-String
        @{ Code = $LASTEXITCODE; Text = $text }
    }
    if (-not $wired) { Write-Host "    $Settings wires no command that names this script" }
    # Side by side: each is a start of sh and of this script, and one after another they took
    # most of a minute.
    $runs = @{}
    if ($wired) {
        $refused | ForEach-Object -ThrottleLimit 6 -Parallel {
            $text = (@{ cwd = $using:project; tool_input = @{ command = $_[0] } } | ConvertTo-Json -Compress) | & $using:sh -c $using:wired 2>&1 | Out-String
            @{ Command = $_[0]; Code = $LASTEXITCODE; Text = $text }
        } | ForEach-Object { $runs[$_.Command] = $_ }
    }
    foreach ($c in $refused) {
        $n++
        $r = $runs[$c[0]]
        $ok = $r -and $r.Code -eq 2 -and $r.Text -match 'Ask Truls'
        Write-Host ("self-test {0}/{1}: refused through the wiring: `{2}` -- {3}" -f $n, $total, $c[0], $(if ($ok) { 'ok' } else { 'FAILED' }))
        if (-not $ok) { $failures++; if ($r) { Write-Host "    exit $($r.Code) $($r.Text)" } }
    }
    $n++
    $ok = $false
    if ($wired) {
        $portal = & $through 'curl -s https://mods.factorio.com/api/mods/flib'
        $plain = & $through 'git status'
        $ok = $portal.Code -eq 0 -and -not $portal.Text.Trim() -and $plain.Code -eq 0 -and -not $plain.Text.Trim()
        if (-not $ok) { Write-Host "    portal: $($portal.Code) $($portal.Text)"; Write-Host "    plain: $($plain.Code) $($plain.Text)" }
    }
    Write-Host ("self-test {0}/{1}: the wired hook passes a portal read and a plain command in silence -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
    if (-not $ok) { $failures++ }
    # Each word of the wiring needs a refused case that holds it and none of the others, or the
    # word could leave the wiring with every wired case above still refused
    # (grado-factorio-modpack#196). The words are read from the wiring, as sh reads them: case
    # counts.
    $n++
    $words = @([regex]::Match($wired, 'case \$i in (.+?)\)').Groups[1].Value -split '\|' | Where-Object { $_ })
    $bare = @($words | Where-Object { $w = $_; -not ($refused | Where-Object { $c = $_[0]; $c -clike $w -and -not ($words | Where-Object { $_ -ne $w -and $c -clike $_ }) }) })
    $ok = $words.Count -gt 1 -and -not $bare
    Write-Host ("self-test {0}/{1}: each of the wiring's {2} words has a refused case that holds no other of them -- {3}" -f $n, $total, $words.Count, $(if ($ok) { 'ok' } else { 'FAILED' }))
    if (-not $ok) { $failures++; Write-Host "    without one: $($bare -join ' ')" }
    # The first example's form, for a project with no hook script, as a clone without the
    # submodule is: the command runs, and stdout tells the agent it was not checked. And for this
    # repository, where it finds this script and refuses.
    $n++
    $form = [regex]::Match((Get-Content -LiteralPath $PSCommandPath -Raw), 'i=\$\(cat\).*?esac').Value
    $empty = Join-Path ([IO.Path]::GetTempPath()) "ask-before-download-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -ItemType Directory -Path $empty -Force | Out-Null
    try {
        $env:CLAUDE_PROJECT_DIR = $empty
        $absentText = (@{ cwd = $empty; tool_input = @{ command = 'npx x' } } | ConvertTo-Json -Compress) | & $sh -c $form 2>$null | Out-String
        $absentCode = $LASTEXITCODE
        $env:CLAUDE_PROJECT_DIR = Split-Path $PSScriptRoot -Parent
        $here = & $through 'npx x' ($form.Replace('/vendor/grado-factorio-tools/scripts/', '/scripts/')) $env:CLAUDE_PROJECT_DIR
    }
    finally { Remove-Item -LiteralPath $empty -Recurse -Force; $env:CLAUDE_PROJECT_DIR = $project }
    # The missing path is named in both fields (ADR 0004).
    $parsed = try { $absentText | ConvertFrom-Json } catch { $null }
    $told = if ($parsed -and $parsed.PSObject.Properties['hookSpecificOutput']) { $parsed.hookSpecificOutput }
    $ok = $form -and $absentCode -eq 0 -and $told -and $told.hookEventName -ceq 'PreToolUse' -and
        ([string] $told.additionalContext) -match "vendor/grado-factorio-tools/scripts/$names was not found, so this command was NOT checked" -and
        $parsed.PSObject.Properties['systemMessage'] -and $parsed.systemMessage -ceq $told.additionalContext -and
        $here.Code -eq 2 -and $here.Text -match 'Ask Truls'
    if (-not $ok) { Write-Host "    absent: $absentCode $absentText"; Write-Host "    here: $($here.Code) $($here.Text)" }
    Write-Host ("self-test {0}/{1}: the first example's form refuses where the script is, and where it is not exits 0 and prints JSON telling the agent -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
    if (-not $ok) { $failures++ }
    # Which tools the session starts that command for: the matchers of the entries that wire it.
    $n++
    $unstarted = @(if ($entry) { Get-UnstartedShellTool -Entry $entry })
    foreach ($tool in $unstarted) { Write-Host "    $Settings`: the matcher $(Get-EntryMatcher $entry) does not start the hook for the $tool tool" }
    $ok = $entry -and -not $unstarted
    Write-Host ("self-test {0}/{1}: the matcher of the entry that wires the hook starts it for the Bash tool and for the PowerShell tool -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
    if (-not $ok) { $failures++ }
    # -AllowedHost as the hook passes it, one comma-separated string under pwsh -File: the second
    # host is let through, and refused without the parameter.
    $n++
    $call = @{ tool_input = @{ command = 'curl -LO https://dl.example.org/tool.zip' } } | ConvertTo-Json -Compress
    $call | pwsh -NoProfile -File $PSCommandPath -AllowedHost 'a.example.org,dl.example.org' 2>&1 | Out-Null
    $withHost = $LASTEXITCODE
    $call | pwsh -NoProfile -File $PSCommandPath 2>&1 | Out-Null
    $withoutHost = $LASTEXITCODE
    $ok = $withHost -eq 0 -and $withoutHost -eq 2
    Write-Host ("self-test {0}/{1}: the script run with -AllowedHost 'a.example.org,dl.example.org' lets the second host through, and refuses it without -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
    if (-not $ok) { $failures++; Write-Host "    with: $withHost, without: $withoutHost" }
    # The entry named, not the first: a settings file whose first entry wires another command.
    $n++
    $fixture = Join-Path ([IO.Path]::GetTempPath()) "ask-before-download-settings-$([guid]::NewGuid().ToString('N').Substring(0, 8)).json"
    try {
        @{ hooks = @{ PreToolUse = @(
            @{ matcher = 'Bash'; hooks = @(@{ type = 'command'; command = 'echo other' }) },
            @{ matcher = 'Bash|PowerShell'; hooks = @(@{ type = 'command'; command = "pwsh -File scripts/$(Split-Path $PSCommandPath -Leaf)" }) }
        ) } } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $fixture
        $second = Get-HookWiring -Event PreToolUse -Script (Split-Path $PSCommandPath -Leaf) -Path $fixture
        # -Settings is read: a child self-test given the fixture says it took the fixture. The
        # variable stops it there, so it never reaches this case.
        $env:ASK_BEFORE_DOWNLOAD_SETTINGS_PROBE = '1'
        try { $took = pwsh -NoProfile -File $PSCommandPath -SelfTest -Settings $fixture 2>&1 | Out-String; $tookCode = $LASTEXITCODE }
        finally { $env:ASK_BEFORE_DOWNLOAD_SETTINGS_PROBE = '' }
    }
    finally { Remove-Item -LiteralPath $fixture -Force -ErrorAction SilentlyContinue }
    $ok = $second.Entries -and $second.Entries[0].matcher -ceq 'Bash|PowerShell' -and $second.Command -match $names
    Write-Host ("self-test {0}/{1}: the wiring is read from the entry that names this script, not the first -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
    if (-not $ok) { $failures++ }
    $n++
    $ok = $tookCode -eq 3 -and $took -match "settings: .*$([regex]::Escape((Split-Path $fixture -Leaf)))"
    Write-Host ("self-test {0}/{1}: a -SelfTest given -Settings reads that file -- {2}" -f $n, $total, $(if ($ok) { 'ok' } else { 'FAILED' }))
    if (-not $ok) { $failures++; Write-Host "    exit $tookCode $took" }
    Write-Host ''
    Write-Host "self-test took $($watch.Elapsed.TotalSeconds.ToString('0.0', [cultureinfo]::InvariantCulture)) s."
    if ($failures) { Write-Host "FAILED - self-test: $failures of $total case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $total cases."
    exit 0
}

try { $what = Get-Download -Command ([string] ([Console]::In.ReadToEnd() | ConvertFrom-Json).tool_input.command) -Allowed $AllowedHost }
catch {
    # Loud, and not a refusal: a hook that cannot read its input must not stop every command.
    [Console]::Error.WriteLine("ask-before-download: could not read the tool call, so the command was NOT checked: $($_.Exception.Message)")
    exit 1
}
if ($what) {
    [Console]::Error.WriteLine(@"
Refused: this command $what.
Ask Truls first: a session does not download a program and run it on this machine unasked
(grado-factorio-modpack#179; the reason is in ask-before-download.ps1's header, in
grado-factorio-tools's scripts/, vendored at vendor/grado-factorio-tools/scripts/). If he says yes, he runs the command himself with the !
prefix. Do not rephrase the command to get past this.
"@)
    exit 2
}
exit 0
