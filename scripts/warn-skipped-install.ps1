<#
.SYNOPSIS
    A SessionStart hook for agent sessions: warns when the clone a session starts in skipped an
    install step, core.hooksPath not set to .githooks or a submodule not initialised. Where it finds
    either, it prints JSON whose systemMessage and additionalContext name each step and the command
    that takes it; where it finds neither, it prints nothing. It always exits 0: a session is never
    stopped by it.

.DESCRIPTION
    WHY (grado-factorio-tools#317 ruling 6, #357). A consumer's clone takes two install steps that
    git does not track: `git config core.hooksPath .githooks`, without which git runs none of the
    repository's hooks, and `git submodule update --init`, without which vendor/ is empty and every
    script the consumer resolves from there is missing. A clone that skipped the first commits and
    pushes past its gates and says nothing.

    HOW A CONSUMER WIRES IT. In its tracked .claude/settings.json, a SessionStart hook whose command
    is the first example below: the form ADR 0004 rules for a shared hook, with no `case`, since a
    session starts once. Where the script is not there, the submodule was never fetched, and the
    command's own branch says so, naming the missing path. Whether this repository wires it in its
    own settings is not ruled (#357).

    WHAT IT WARNS OF, in the repository -Root names:
    - core.hooksPath, read with `git config --type=path --get`, that does not name the root's
      .githooks directory, where the root holds one. The path is resolved against the root before
      it is compared (#462), so `./.githooks/` and the directory's full path name it as `.githooks`
      does; on Windows the two are compared in any case. A repository with no such directory has no
      hooks to skip, and is not warned of.
    - each submodule `git submodule status` marks `-`, not initialised, named by its whole path,
      spaces included (#462).
    Each of those is a step found skipped, and the warning opens them with "this clone skipped an
    install step." A check it could not make is said in other words, opened with "a check for
    skipped install steps could not be made." (#462): where git cannot read the root as a
    repository, where it cannot list the submodules, and where the script itself fails. A warning
    holding both says each.

    WHAT IT CANNOT SEE. A hooks directory that is not .githooks, or a hook file that is not
    executable off Windows, where git skips it. A submodule initialised at a commit other than the
    pin, which `git submodule status` marks `+` and follow-pin.ps1 is for. A hooks path set in the
    environment, or for one command, and one reaching .githooks through a link, which is compared as
    the path it spells. A submodule path git prints quoted. Whether the session shows the warning:
    what the client does with a SessionStart hook's output is not measured here.

.PARAMETER Root
    The repository to read. The wiring gives "$CLAUDE_PROJECT_DIR". Defaults to the current
    directory.

.PARAMETER SelfTest
    Build scratch repositories and prove: a clone with core.hooksPath unset, one with it set
    elsewhere, and one with it set to another repository's .githooks in full, are warned of; one
    with a submodule not initialised is warned of, naming its path, a path with a space whole; one
    that needs neither prints nothing, with the hooks path written ./.githooks/ or in full; a
    .githooks-less repository is not warned of its hooks path; a directory outside any repository
    is said to be not checked, and the script run there says a check could not be made and not that
    a step was skipped; a skip found and a check not made are each opened in their own words. Then
    the first example's
    command, run through sh, where the project holds no script exits 0 and prints JSON naming the
    missing path, and for this repository runs the script. A settings file's command naming this
    script, found by its name among the SessionStart entries, is run with this repository's scripts:
    it must warn the clone that skipped a step and say nothing for the one that did not, a command
    that never runs the script fails that, and a file with no SessionStart entry wires none. With
    -Settings, that file's command is held to the same. Needs git, and sh: the one on the path, or
    the one Git for Windows ships.

.PARAMETER Settings
    With -SelfTest: a consumer's .claude/settings.json, whose SessionStart command naming this
    script is run on the self-test's two clones, with this repository's scripts in place of the path
    it names. The first command of any entry that names it is taken (#315 ruling 3). Without it no
    settings file of a repository is read, since this repository does not wire the hook.

.EXAMPLE
    The wired command: the SessionStart hook a consumer puts in its .claude/settings.json, as HOW A
    CONSUMER WIRES IT says. It gives -Root, the one option, the project.

        cat >/dev/null; h="$CLAUDE_PROJECT_DIR/vendor/grado-factorio-tools/scripts/warn-skipped-install.ps1"; if [ -f "$h" ]; then pwsh -NoProfile -File "$h" -Root "$CLAUDE_PROJECT_DIR"; else m='warn-skipped-install: vendor/grado-factorio-tools/scripts/warn-skipped-install.ps1 was not found: the submodule is not initialised, so this clone was NOT checked for skipped install steps. git submodule update --init fetches it.'; printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}' "$m" "$m"; fi

.EXAMPLE
    To check it, from a repository root. It prints nothing where nothing was skipped:

        pwsh -NoProfile -File scripts/warn-skipped-install.ps1 -Root .; $LASTEXITCODE
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $Root = '.',
    [switch] $SelfTest,
    [string] $Settings
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-Finding {
    <#  One finding: a step found skipped ($Kind 'skipped') or a check that could not be made
        ('not checked'), and the sentence that says it.  #>
    param([Parameter(Mandatory)] [ValidateSet('skipped', 'not checked')] [string] $Kind, [Parameter(Mandatory)] [string] $Text)
    [pscustomobject] @{ Kind = $Kind; Text = $Text }
}

function Get-SkippedInstall {
    <#  What the repository at $Dir was found to skip, as findings (New-Finding): each install step
        it skipped, as a sentence that names the command that takes it, and each check git could
        not make, as a sentence saying so.  #>
    param([Parameter(Mandatory)] [string] $Dir)
    $top = git -C $Dir rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -or -not $top) { return New-Finding 'not checked' "git could not read $Dir as a repository, so it was NOT checked for skipped install steps." }
    $hooksDir = Join-Path $top '.githooks'
    if (Test-Path -LiteralPath $hooksDir -PathType Container) {
        # In a string, so an unset path is '' and not $null: [string] of no output is $null.
        # --type=path expands a leading ~ as git does where it reads the hooks.
        $path = "$(git -C $top config --type=path --get core.hooksPath 2>$null)"
        # Resolved against the top, where git runs the hooks from, so that ./.githooks/ and the
        # directory's full path name it as .githooks does. Windows's paths are compared in any case.
        $full = { param([string] $p) [IO.Path]::GetFullPath($p, $top).TrimEnd('\', '/') }
        $same = $path.Trim() -and $(if ($IsWindows) { (& $full $path.Trim()) -ieq (& $full $hooksDir) } else { (& $full $path.Trim()) -ceq (& $full $hooksDir) })
        if (-not $same) {
            $was = if ($path) { "is $path" } else { 'is not set' }
            New-Finding 'skipped' "core.hooksPath $was, so git runs none of this repository's hooks: git config core.hooksPath .githooks"
        }
    }
    $status = @(git -C $top submodule status 2>$null)
    if ($LASTEXITCODE) { return New-Finding 'not checked' "git could not list the submodules of $top, so they were NOT checked." }
    foreach ($line in $status) {
        # The whole rest of the line: git prints no describe for a submodule it has not
        # initialised, and a path may hold spaces.
        if ($line -match '^-[0-9a-f]+ (.+)$') { New-Finding 'skipped' "the submodule $($Matches[1]) is not initialised: git submodule update --init" }
    }
}

# The JSON a SessionStart hook prints for $Findings, or nothing where there are none. A step found
# skipped and a check not made are each opened in their own words, so that a check that did not run
# never reads as a skip found.
function Format-Warning {
    param([object[]] $Findings)
    if (-not $Findings) { return }
    $skipped = @($Findings | Where-Object Kind -ceq 'skipped' | ForEach-Object Text)
    $unchecked = @($Findings | Where-Object Kind -ceq 'not checked' | ForEach-Object Text)
    $parts = @(
        if ($skipped) { "this clone skipped an install step. $($skipped -join ' Also, ')" }
        if ($unchecked) { "a check for skipped install steps could not be made. $($unchecked -join ' Also, ')" }
    )
    $text = "warn-skipped-install: $($parts -join ' Separately, ')"
    @{ systemMessage = $text; hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $text } } | ConvertTo-Json -Compress
}

if ($SelfTest) {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "warn-skipped-install-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -ItemType Directory -Path $temp | Out-Null
    $failures = 0; $n = 0
    $check = {
        param([string] $Name, [bool] $Ok, [string] $Said)
        $script:n++
        Write-Host ("self-test {0}: {1} -- {2}" -f $script:n, $Name, $(if ($Ok) { 'ok' } else { 'FAILED' }))
        if (-not $Ok) { $script:failures++; if ($Said) { Write-Host "    $Said" } }
    }
    try {
        # No param block: a declared parameter would take git's own -A as its name.
        $git = { $at = $args[0]; $a = @($args | Select-Object -Skip 1); git -C $at -c protocol.file.allow=always @a 2>&1 | Out-Null; if ($LASTEXITCODE) { throw "git $($a -join ' ') failed in $at" } }
        $commit = { param([string] $at) & $git $at add -A; & $git $at -c user.name=t -c user.email=t@t commit --quiet -m one }
        # The sentences of what a directory was found to skip.
        $said = { param([string] $at) @(Get-SkippedInstall $at | ForEach-Object Text) }
        # A repository to stand as the submodule, and one that holds it twice, once at a path with
        # a space, with .githooks and the hooks path set: a clone that needs neither step.
        $sub = Join-Path $temp 'sub'; $whole = Join-Path $temp 'whole'
        foreach ($r in $sub, $whole) { New-Item -ItemType Directory -Path $r | Out-Null; & $git $r init --quiet }
        Set-Content -LiteralPath (Join-Path $sub 'a.txt') -Value 'one'; & $commit $sub
        New-Item -ItemType Directory -Path (Join-Path $whole '.githooks') | Out-Null
        Set-Content -LiteralPath (Join-Path $whole '.githooks/commit-msg') -Value '#!/bin/sh'
        & $git $whole submodule add --quiet $sub vendor/tools
        & $git $whole submodule add --quiet $sub 'vendor/tool kit'
        & $commit $whole
        & $git $whole config core.hooksPath .githooks
        # A clone of it, which git makes with no hooks path and no submodule initialised.
        $clone = Join-Path $temp 'clone'
        & $git $temp clone --quiet $whole $clone
        $none = @(& $said $whole)
        & $check 'a clone with the hooks path set and its submodule initialised is warned of nothing' (-not $none) ($none -join ' | ')
        $both = @(& $said $clone)
        & $check 'a fresh clone is warned that core.hooksPath is not set, naming the command' ([bool] ($both -match 'core\.hooksPath is not set.*git config core\.hooksPath \.githooks')) ($both -join ' | ')
        & $check 'and that its submodule is not initialised, naming its path and the command' ([bool] ($both -match 'the submodule vendor/tools is not initialised: git submodule update --init')) ($both -join ' | ')
        & $check 'a submodule not initialised whose path holds a space is named by its whole path' ([bool] ($both -cmatch '^the submodule vendor/tool kit is not initialised: ')) ($both -join ' | ')
        & $git $clone config core.hooksPath hooks
        $elsewhere = @(& $said $clone)
        & $check 'a hooks path set elsewhere is warned of, naming it' ([bool] ($elsewhere -match 'core\.hooksPath is hooks,')) ($elsewhere -join ' | ')
        & $git $clone config core.hooksPath ./.githooks/
        & $git $clone submodule update --init --quiet
        $fixed = @(& $said $clone)
        & $check 'the clone with both steps taken, the hooks path written ./.githooks/, is warned of nothing' (-not $fixed) ($fixed -join ' | ')
        & $git $clone config core.hooksPath (Join-Path $clone '.githooks')
        $inFull = @(& $said $clone)
        & $check 'a hooks path naming the clone''s .githooks by its full path is warned of nothing' (-not $inFull) ($inFull -join ' | ')
        & $git $clone config core.hooksPath (Join-Path $whole '.githooks')
        $another = @(& $said $clone)
        & $check 'a full hooks path naming another repository''s .githooks is warned of, naming it' ([bool] ($another -match 'core\.hooksPath is .*whole.*\.githooks, so git runs none')) ($another -join ' | ')
        $bare = Join-Path $temp 'bare'
        New-Item -ItemType Directory -Path $bare | Out-Null; & $git $bare init --quiet
        $noHooks = @(& $said $bare)
        & $check 'a repository with no .githooks directory is not warned of its hooks path' (-not $noHooks) ($noHooks -join ' | ')
        $outside = Join-Path $temp 'outside'
        New-Item -ItemType Directory -Path $outside | Out-Null
        $notRepo = @(& $said $outside)
        & $check 'a directory outside any repository is said to be NOT checked' ([bool] ($notRepo -match 'NOT checked')) ($notRepo -join ' | ')
        # The script itself: JSON for a clone that skipped a step, nothing for one that did not,
        # exit 0 for both.
        & $git $clone config --unset core.hooksPath
        $warned = pwsh -NoProfile -File $PSCommandPath -Root $clone 2>&1 | Out-String; $warnedCode = $LASTEXITCODE
        $quiet = pwsh -NoProfile -File $PSCommandPath -Root $whole 2>&1 | Out-String; $quietCode = $LASTEXITCODE
        $told = try { $warned | ConvertFrom-Json } catch { $null }
        $ok = $warnedCode -eq 0 -and $told -and $told.hookSpecificOutput.hookEventName -ceq 'SessionStart' -and
            $told.hookSpecificOutput.additionalContext -match 'core\.hooksPath' -and $told.systemMessage -ceq $told.hookSpecificOutput.additionalContext -and
            $quietCode -eq 0 -and -not $quiet.Trim()
        & $check 'run on a clone that skipped a step it exits 0 and prints SessionStart JSON; on one that did not, exits 0 and prints nothing' $ok "warned: $warnedCode $warned | quiet: $quietCode $quiet"
        # Outside a repository nothing was checked, and the warning says that, not that a step
        # was skipped.
        $unread = pwsh -NoProfile -File $PSCommandPath -Root $outside 2>&1 | Out-String; $unreadCode = $LASTEXITCODE
        $toldUnread = try { ($unread | ConvertFrom-Json).hookSpecificOutput.additionalContext } catch { '' }
        & $check 'run outside a repository it exits 0 and says a check could not be made and nothing was checked, not that a step was skipped' ($unreadCode -eq 0 -and $toldUnread -cmatch '^warn-skipped-install: a check for skipped install steps could not be made\. .*NOT checked' -and $toldUnread -notmatch 'skipped an install step') "$unreadCode $unread"
        # A skip found and a check not made in one result: each opened as it is.
        $mixed = (Format-Warning @((New-Finding 'skipped' 'Step one.'), (New-Finding 'not checked' 'Check two.'), (New-Finding 'skipped' 'Step three.')) | ConvertFrom-Json).systemMessage
        & $check 'a skip found and a check not made are each opened in their own words' ($mixed -ceq 'warn-skipped-install: this clone skipped an install step. Step one. Also, Step three. Separately, a check for skipped install steps could not be made. Check two.') $mixed
        # The first example's form, read from the header so the command shown is the command run.
        $form = [regex]::Match((Get-Content -LiteralPath $PSCommandPath -Raw), 'cat >/dev/null;.*?; fi').Value
        $sh = (Get-Command sh -ErrorAction SilentlyContinue)?.Source ?? (Join-Path (git --exec-path) '../../../usr/bin/sh.exe')
        $env:PATH = "$(Split-Path $sh)$([IO.Path]::PathSeparator)$env:PATH"
        $wire = {
            param($project, $line)
            $env:CLAUDE_PROJECT_DIR = $project
            $text = '{"hook_event_name":"SessionStart"}' | & $sh -c $line 2>$null | Out-String
            @{ Code = $LASTEXITCODE; Text = $text }
        }
        $absent = & $wire $outside $form
        $here = & $wire $clone $form.Replace('$CLAUDE_PROJECT_DIR/vendor/grado-factorio-tools/scripts/', ($PSScriptRoot -replace '\\', '/') + '/')
        $ok = try {
            $parsed = $absent.Text | ConvertFrom-Json
            $form -and $absent.Code -eq 0 -and $parsed.hookSpecificOutput.hookEventName -ceq 'SessionStart' -and
                $parsed.hookSpecificOutput.additionalContext -match 'vendor/grado-factorio-tools/scripts/warn-skipped-install\.ps1 was not found' -and
                $parsed.systemMessage -ceq $parsed.hookSpecificOutput.additionalContext -and
                $here.Code -eq 0 -and ($here.Text | ConvertFrom-Json).hookSpecificOutput.additionalContext -match 'core\.hooksPath is not set'
        } catch { $false }
        & $check 'the first example''s command, where the script is not there, exits 0 and names the missing path; where it is, runs it on the project' $ok "absent: $($absent.Code) $($absent.Text) | here: $($here.Code) $($here.Text)"
        # The wiring a settings file holds, found by this script's name among the SessionStart
        # entries (#315 ruling 3) by hook-matcher.ps1's Get-HookWiring, which reads each key only
        # where it stands. The wired command is run with this repository's scripts in place of a
        # consumer's vendor/ or scripts/ path, on the clone that skipped a step, which it must warn
        # of, and on the one that skipped none, where it must print nothing: a command that never
        # runs the script passes the second and fails the first.
        . "$PSScriptRoot/hook-matcher.ps1"
        $wiredCommand = { param([string] $path) (Get-HookWiring -Path $path -Event SessionStart -Script (Split-Path $PSCommandPath -Leaf)).Command }
        $scriptsDir = ($PSScriptRoot -replace '\\', '/') + '/'
        $wiredWarns = {
            param([string] $line)
            $local = $line.Replace('$CLAUDE_PROJECT_DIR/vendor/grado-factorio-tools/scripts/', $scriptsDir).Replace('$CLAUDE_PROJECT_DIR/scripts/', $scriptsDir)
            $warns = & $wire $clone $local; $silent = & $wire $whole $local
            $told = try { $warns.Text | ConvertFrom-Json } catch { $null }
            @{ Ok = [bool] ($warns.Code -eq 0 -and $told -and $told.hookSpecificOutput.additionalContext -match 'core\.hooksPath is not set' -and $silent.Code -eq 0 -and -not $silent.Text.Trim())
                Said = "skipped: $($warns.Code) $($warns.Text) | whole: $($silent.Code) $($silent.Text)" }
        }
        $fixture = Join-Path $temp 'settings.json'
        $write = { param([string[]] $commands) @{ hooks = @{ SessionStart = @(@{ hooks = @($commands | ForEach-Object { @{ type = 'command'; command = $_ } }) }) } } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $fixture }
        & $write @('echo first', $form)
        $named = & $wiredCommand $fixture
        $real = if ($named) { & $wiredWarns $named } else { @{ Ok = $false; Said = 'no command found' } }
        & $write @(': # warn-skipped-install.ps1')
        $stub = & $wiredWarns (& $wiredCommand $fixture)
        @{ hooks = @{ PreToolUse = @() } } | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $fixture
        $none = try { & $wiredCommand $fixture } catch { "threw: $($_.Exception.Message)" }
        & $check 'a settings file''s command naming this script is found and warns a clone that skipped a step and says nothing for one that did not; a command that never runs the script fails that; a file with no SessionStart entry wires none' ($named -ceq $form -and $real.Ok -and -not $stub.Ok -and -not $none) "named: $($real.Said) | stub held: $($stub.Ok) | none: $none"
        if ($Settings) {
            $Settings = (Resolve-Path -LiteralPath $Settings).Path
            $wired = & $wiredCommand $Settings
            $ran = if ($wired) { & $wiredWarns $wired }
            & $check "the SessionStart command $Settings wires for this script warns a clone that skipped a step and says nothing for one that did not" ([bool] ($wired -and $ran.Ok)) $(if ($wired) { $ran.Said } else { "$Settings wires no SessionStart command that names this script" })
        }
    }
    catch { & $check 'the fixture was built' $false $_.Exception.Message }
    finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $n case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $n cases."
    exit 0
}

try { Format-Warning @(Get-SkippedInstall $Root) }
catch {
    # Loud, and not a stop: a session starts whatever this finds.
    Format-Warning (New-Finding 'not checked' "it could not read $Root ($($_.Exception.Message)), so the clone was NOT checked for skipped install steps.")
}
exit 0
