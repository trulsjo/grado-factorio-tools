<#
.SYNOPSIS
    Run from a sibling's root: fails, exit 1, where a tools script one of the sibling's gates runs
    has no form in its forms file, naming each such script and each gate line that runs it. Exit 0
    means each tools script a gate calls, as read below, has a form that names it.

.DESCRIPTION
    WHY (grado-factorio-tools#470, from grado-factorio-modpack#424). The modpack's three pin hooks
    ran follow-pin.ps1 as "$sub/scripts/follow-pin.ps1" from its d04d985 (2026-10-31), and no form
    in its scripts/pin-forms.psd1 ran it until its PR #423, by that ticket's account.
    pin-measure.ps1 lists the unrun references it finds only while a pin move is measured, reports
    and never fails, and finds them by `git grep` for the literal path, which misses a path built
    from a variable. Truls ruled on 2026-11-14 that a -SelfTest form is enough, and that the check
    lives here.

    THE GATES are every file under the sibling's .githooks/ and .github/workflows/, and its
    .claude/settings.json, read from the working tree.

    A TOOLS SCRIPT is a *.ps1 in -Tools, the pin's scripts/. A gate line calls one, other than a
    line whose first character other than a space is `#`, in one of three forms, as grado-factorio-
    modpack's mentions.ps1's Get-CallNames matches them (its 82e836f): the literal path
    `vendor/grado-factorio-tools/scripts/<name>`; `$<var>/scripts/<name>`, where the same file sets
    <var> to a value ending in `vendor/grado-factorio-tools`; or `$<var>/<name>`, where it sets
    <var> to a value ending in `vendor/grado-factorio-tools/scripts`. `${<var>}` is read as
    `$<var>`. A variable is set by an assignment of the shell's, `<var>=<value>` or
    `export <var>=<value>`, on a line that is no comment, at its start or after a space, `;`, `&`,
    `|`, `(` or a JSON string's `"`, its value in `"`, `\"` or `'` quotes, spaces and all, or in
    none. The name is read whole, letters, digits, `.`, `-` and `_`, its trailing dots
    dropped, so `check.ps1` in `commit-check.ps1` is not a call of `check.ps1`; and a name called as
    the sibling's own `scripts/<name>` is not a tools script, even where one shares its name.
    Reading whole files, a variable set to a whole script path, as
    `CHECK="$ROOT/vendor/grado-factorio-tools/scripts/commit-check.ps1"`, is read on its assignment
    line.

    THE FORMS FILE is -Forms, read from the working tree, with Import-PowerShellDataFile; its
    contract is pin-measure.ps1's header's. A form names a tools script when its From is `tools` and
    its Script, with \ read as /, ends in `/<name>` or is `<name>`. A -SelfTest form is enough. A
    `sibling` form never counts for a tools script, even one of the same name.

    IT FAILS, exit 1 and saying which, where the forms file cannot be read, reads empty or holds no
    forms; where no gate file is there; or where -Tools holds no *.ps1: each a step that would
    otherwise leave nothing to read.

    WHAT IT CANNOT SEE. A call through a variable set in another file, as a hook that sources a
    shared file. A tools script named without `.ps1`, or through a path built in more than one step,
    as `Join-Path`, a PowerShell assignment, `$t = 'vendor/...'`, or a substitution. A call in a
    gate file under another directory, as a sibling script that a gate runs and that runs a tools
    script itself. A comment that does not open its line. Whether a form runs the script as the gate
    runs it: ruled, a -SelfTest form is enough. Whether a form's script is in the pin.

.PARAMETER Forms
    The sibling's forms file, a path from the directory the check is run in, or an absolute one.
    Defaults to scripts/pin-forms.psd1, as pin-measure.ps1's -Forms does.

.PARAMETER Tools
    The pin's scripts/ directory, whose *.ps1 are the tools scripts. Defaults to the directory this
    script is in, as it is run from the sibling's submodule.

.PARAMETER SelfTest
    Build fixtures in a temporary directory and prove each case: a name read whole; a namesake of
    the sibling's own; a sibling form not counting; each of the three call forms in each gate
    directory and the settings file; a comment line; a -SelfTest form counting; a missing form
    failing with the script and the gate line; and an unreadable, empty or formless forms file, no
    gate file, and no tools script each failing. Then the second example's command, on a fixture.

.EXAMPLE
    A sibling's gate, from its root, as grado-factorio-modpack#424 wires it:

        pwsh -NoProfile -File vendor/grado-factorio-tools/scripts/form-check.ps1

.EXAMPLE
    pwsh -NoProfile -File vendor/grado-factorio-tools/scripts/form-check.ps1 -Forms scripts/pin-forms.psd1
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $Forms = 'scripts/pin-forms.psd1',
    [string] $Tools = $PSScriptRoot,
    [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TOOLS_PATH = 'vendor/grado-factorio-tools'

# Each call of a tools script in the gate files under $Root, as @{ Name; At }, At being
# `<file>:<line>` with the file's path from $Root; throws where no gate file is there.
function Get-ToolCall {
    param([Parameter(Mandatory)] [string] $Root, [Parameter(Mandatory)] [string[]] $Names)
    $gates = @(foreach ($d in '.githooks', '.github/workflows') {
            $dir = Join-Path $Root $d
            if (Test-Path -LiteralPath $dir) { Get-ChildItem -LiteralPath $dir -File -Recurse }
        }) + @(Get-Item -LiteralPath (Join-Path $Root '.claude/settings.json') -ErrorAction SilentlyContinue)
    if (-not $gates) { throw "no gate file is there: none under .githooks/ or .github/workflows/, and no .claude/settings.json." }
    $asVar = { param($set) @($set | ForEach-Object { '\$\{?' + $_ + '\}?' }) }
    foreach ($g in $gates) {
        $file = [IO.Path]::GetRelativePath($Root, $g.FullName) -replace '\\', '/'
        $lines = @(Get-Content -LiteralPath $g.FullName)
        # The variables the file sets to the submodule's path or to its scripts/, on lines that are
        # no comment: the name after a line's start, a space, `;`, `&`, `|`, `(` or a JSON string's
        # `"`, its value in `"`, `\"` or `'` quotes, which may hold spaces, or in none.
        $roots = [Collections.Generic.HashSet[string]]::new()
        $dirs = [Collections.Generic.HashSet[string]]::new()
        $code = ($lines | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
        $assign = '(?m)(?:^|[\s;&|("])(?:export\s+)?([A-Za-z_]\w*)=(?:\\?"(?<v>[^"\\]*)\\?"|''(?<v>[^'']*)''|(?<v>[^"''\s;\\]*))'
        foreach ($m in [regex]::Matches($code, $assign)) {
            if ($m.Groups['v'].Value -match "$([regex]::Escape($TOOLS_PATH))/?$") { [void] $roots.Add($m.Groups[1].Value) }
            elseif ($m.Groups['v'].Value -match "$([regex]::Escape($TOOLS_PATH))/scripts/?$") { [void] $dirs.Add($m.Groups[1].Value) }
        }
        $via = @("(?:$((@([regex]::Escape($TOOLS_PATH)) + (& $asVar $roots)) -join '|'))/scripts") + (& $asVar $dirs)
        $call = "(?:$($via -join '|'))/([A-Za-z0-9_.-]+)"
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\s*#') { continue }
            foreach ($m in [regex]::Matches($lines[$i], $call)) {
                $name = $m.Groups[1].Value -replace '\.+$'
                if ($name -cin $Names) { @{ Name = $name; At = "${file}:$($i + 1)" } }
            }
        }
    }
}

# The forms of the file at $Path; throws where it cannot be read, reads empty or holds no forms.
function Read-Form {
    param([Parameter(Mandatory)] [string] $Path)
    $text = try { Get-Content -LiteralPath $Path -Raw } catch { throw "the forms file $Path could not be read: $($_.Exception.Message)" }
    if (-not "$text".Trim()) { throw "the forms file $Path reads empty." }
    $data = try { Import-PowerShellDataFile -LiteralPath $Path } catch { throw "the forms file $Path could not be read: $($_.Exception.Message)" }
    $list = @(if ($data.ContainsKey('Forms')) { $data.Forms })
    if (-not $list) { throw "the forms file $Path holds no forms." }
    $list
}

# The check, its lines written, from $Root: 0 where each tools script a gate calls has a form, 1
# where one has none or a step reads nothing.
function Invoke-FormCheck {
    param([Parameter(Mandatory)] [string] $Root, [Parameter(Mandatory)] [string] $Forms, [Parameter(Mandatory)] [string] $Tools)
    try {
        $path = [IO.Path]::GetFullPath($Forms, $Root)
        $list = @(Read-Form -Path $path)
        $names = @(Get-ChildItem -LiteralPath $Tools -Filter *.ps1 -File | ForEach-Object Name)
        if (-not $names) { throw "-Tools $Tools holds no *.ps1, so there is no tools script to look for." }
        $calls = @(Get-ToolCall -Root $Root -Names $names)
    }
    catch { Write-Host "FAILED - form-check: $($_.Exception.Message)"; return 1 }
    $formed = @($list | Where-Object { $_.From -ceq 'tools' } | ForEach-Object { "$($_.Script)" -replace '\\', '/' })
    $missing = @($calls | Group-Object { $_.Name } | Where-Object {
            $n = $_.Name
            -not @($formed | Where-Object { $_ -ceq $n -or $_.EndsWith("/$n", [StringComparison]::Ordinal) })
        })
    foreach ($m in $missing) { Write-Host "form-check: $($m.Name) has no form in $Forms; run by $(@($m.Group | ForEach-Object { $_.At }) -join ', ')." }
    if ($missing) { Write-Host "FAILED - form-check: $($missing.Count) tools script(s) a gate runs have no form in $Forms."; return 1 }
    $scripts = @($calls | ForEach-Object { $_.Name } | Sort-Object -Unique)
    Write-Host "OK - form-check: $($calls.Count) call(s) of $($scripts.Count) tools script(s) read in the gates, each with a form in $Forms."
    0
}

if ($SelfTest) {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "form-check-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    $failures = 0; $n = 0
    $check = {
        param([string] $Name, [bool] $Ok, [string] $Said)
        $script:n++
        Write-Host ("self-test {0}: {1} -- {2}" -f $script:n, $Name, $(if ($Ok) { 'ok' } else { 'FAILED' }))
        if (-not $Ok) { $script:failures++; if ($Said) { Write-Host "    $Said" } }
    }
    $write = { param([string] $path, [string] $text) New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null; [IO.File]::WriteAllText($path, $text) }
    $fixtureTools = Join-Path $temp 'tools'
    foreach ($s in 'check.ps1', 'commit-check.ps1', 'follow-pin.ps1', 'reword-commit.ps1', 'a.ps1', 'b.ps1', 'c.ps1', 'd.ps1') { & $write (Join-Path $fixtureTools $s) '' }
    $k = 0
    # A sibling built from its gate files and forms, the check run there: @{ Code; Text }.
    $sibling = {
        param([hashtable] $files, [string] $forms = 'scripts/pin-forms.psd1', [string] $toolsDir = $fixtureTools)
        $root = Join-Path $temp "sibling-$((++$script:k))"
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        foreach ($f in $files.Keys) { & $write (Join-Path $root $f) $files[$f] }
        $said = [Collections.Generic.List[string]]::new(); $code = $null
        foreach ($o in @(Invoke-FormCheck -Root $root -Forms $forms -Tools $toolsDir 6>&1)) {
            if ($o -is [System.Management.Automation.InformationRecord]) { $said.Add("$o") } else { $code = $o }
        }
        $text = $said -join "`n"
        Write-Host ($text -replace '(?m)^', '    ')
        @{ Code = $code; Text = $text }
    }
    $form = { param([string] $from, [string] $script, [string] $more = '') "@{ Name = 'f'; From = '$from'; Script = '$script'$more }" }
    $formsOf = { param([string[]] $forms) "@{ Forms = @( $($forms -join ', ') ) }" }
    $hook = { param([string] $body) "#!/bin/sh`n$body`n" }
    try {
        $r = & $sibling @{
            '.githooks/commit-msg' = & $hook 'exec pwsh -NoProfile -File "$ROOT/vendor/grado-factorio-tools/scripts/commit-check.ps1" "$1"'
            'scripts/pin-forms.psd1' = & $formsOf (& $form 'tools' 'commit-check.ps1')
        }
        & $check 'a name is read whole: commit-check.ps1 with a form passes, and check.ps1 inside it is no call' ($r.Code -eq 0 -and $r.Text -match '1 call\(s\) of 1 tools script') $r.Text
        $r = & $sibling @{
            '.githooks/pre-push' = & $hook 'pwsh -NoProfile -File scripts/reword-commit.ps1'
            'scripts/pin-forms.psd1' = & $formsOf (& $form 'tools' 'a.ps1')
        }
        & $check 'a sibling script named like a tools script, called as scripts/<name>, is no call' ($r.Code -eq 0 -and $r.Text -match '0 call\(s\)') $r.Text
        $r = & $sibling @{
            '.githooks/post-merge' = & $hook "sub=`"`$ROOT/vendor/grado-factorio-tools`"`nf=`$sub/scripts/follow-pin.ps1"
            'scripts/pin-forms.psd1' = & $formsOf (& $form 'sibling' 'scripts/follow-pin.ps1')
        }
        & $check 'a sibling form of the same name does not count for the tools script: it fails, naming the script and the gate line' ($r.Code -eq 1 -and $r.Text -match '(?m)^form-check: follow-pin\.ps1 has no form in scripts/pin-forms\.psd1; run by \.githooks/post-merge:3\.$') $r.Text
        $r = & $sibling @{
            # A variable set on a comment line, and one set to another folder, are no way in (PR
            # #493's review, F and N).
            '.githooks/post-checkout' = & $hook ("pwsh -File vendor/grado-factorio-tools/scripts/a.ps1`n# vendor/grado-factorio-tools/scripts/d.ps1`n" +
                "pwsh -File vendor/grado-factorio-tools/scripts/not-there.ps1`necho `"see vendor/grado-factorio-tools/scripts/a.ps1.`"`n" +
                "# o2=vendor/grado-factorio-tools/scripts`npwsh -File `$o2/c.ps1`no=/opt/other/scripts`npwsh -File `$o/b.ps1")
            # A quoted value holding a space.
            '.github/workflows/ci.yml' = "jobs:`n  x:`n    steps:`n      - run: |`n          export TOOLS=`"`$GITHUB_WORKSPACE/my dir/vendor/grado-factorio-tools`"`n          pwsh -File `${TOOLS}/scripts/b.ps1`n"
            # A variable set right after a JSON string's quote, and one whose value is in \" quotes.
            '.claude/settings.json' = '{"hooks":{"x":"d=$CLAUDE_PROJECT_DIR/vendor/grado-factorio-tools/scripts; pwsh -File \"$d/c.ps1\"","y":"e=\"$CLAUDE_PROJECT_DIR/vendor/grado-factorio-tools\"; pwsh -File \"$e/scripts/d.ps1\""}}'
            'scripts/pin-forms.psd1' = & $formsOf (& $form 'tools' 'follow-pin.ps1')
        }
        $named = @([regex]::Matches($r.Text, '(?m)^form-check: (\S+) has no form in \S+; run by (.+)\.$') | ForEach-Object { "$($_.Groups[1].Value) $($_.Groups[2].Value)" })
        $settingsAt = '.claude/settings.json' + ':1'
        & $check 'each call form is a call, a literal path in a hook, ${<var>}/scripts/<name> in a workflow with a quoted value holding a space, $<var>/<name> and a \"-quoted value in the settings file, a trailing dot dropped; a comment line, a variable set on one, one set to another folder, and a name that is no tools script, are not' ($r.Code -eq 1 -and ($named -join '|') -ceq "a.ps1 .githooks/post-checkout:2, .githooks/post-checkout:5|b.ps1 .github/workflows/ci.yml:6|c.ps1 $settingsAt|d.ps1 $settingsAt") $r.Text
        $r = & $sibling @{
            '.githooks/post-merge' = & $hook "sub=`"`$ROOT/vendor/grado-factorio-tools`"`n`"`$sub/scripts/follow-pin.ps1`" --check`npwsh -File vendor/grado-factorio-tools/scripts/a.ps1"
            'scripts/pin-forms.psd1' = & $formsOf (& $form 'tools' 'follow-pin.ps1' "; Args = @('-SelfTest')"), (& $form 'tools' 'vendor\grado-factorio-tools\scripts\a.ps1')
        }
        & $check 'a -SelfTest form counts as a form, and a Script written with \ names its script' ($r.Code -eq 0 -and $r.Text -match '2 call\(s\) of 2 tools script') $r.Text
        $gate = @{ '.githooks/commit-msg' = & $hook 'pwsh -File vendor/grado-factorio-tools/scripts/a.ps1' }
        $r = & $sibling ($gate + @{ 'scripts/pin-forms.psd1' = '' })
        $empty = $r.Code -eq 1 -and $r.Text -match 'pin-forms\.psd1 reads empty'
        $r = & $sibling ($gate + @{ 'scripts/pin-forms.psd1' = '@{ Forms = @() }' })
        $none = $r.Code -eq 1 -and $r.Text -match 'pin-forms\.psd1 holds no forms'
        $r = & $sibling ($gate + @{ 'scripts/pin-forms.psd1' = '@{ Other = 1 }' })
        $noKey = $r.Code -eq 1 -and $r.Text -match 'pin-forms\.psd1 holds no forms'
        $r = & $sibling ($gate + @{ 'scripts/pin-forms.psd1' = '@{ Forms = ' })
        $broken = $r.Code -eq 1 -and $r.Text -match 'pin-forms\.psd1 could not be read'
        $r = & $sibling $gate
        $absent = $r.Code -eq 1 -and $r.Text -match 'pin-forms\.psd1 could not be read'
        & $check 'a forms file that reads empty, holds an empty Forms or none, does not parse, or is not there fails, saying which' ($empty -and $none -and $noKey -and $broken -and $absent) ''
        $r = & $sibling @{ 'scripts/pin-forms.psd1' = & $formsOf (& $form 'tools' 'a.ps1') }
        & $check 'a sibling with no gate file fails, saying so' ($r.Code -eq 1 -and $r.Text -match 'no gate file is there') $r.Text
        $bare = Join-Path $temp 'no-tools'
        New-Item -ItemType Directory -Path $bare -Force | Out-Null
        $r = & $sibling ($gate + @{ 'scripts/pin-forms.psd1' = & $formsOf (& $form 'tools' 'a.ps1') }) 'scripts/pin-forms.psd1' $bare
        & $check 'a -Tools with no *.ps1 fails, saying so' ($r.Code -eq 1 -and $r.Text -match 'holds no \*\.ps1') $r.Text
        # The command line, run in a fixture with -Tools and -Forms given.
        $root = Join-Path $temp 'cli'
        & $write (Join-Path $root '.githooks/commit-msg') (& $hook 'pwsh -File vendor/grado-factorio-tools/scripts/a.ps1')
        & $write (Join-Path $root 'forms.psd1') (& $formsOf (& $form 'tools' 'b.ps1'))
        Push-Location -LiteralPath $root
        try { $said = & pwsh -NoProfile -File $PSCommandPath -Forms forms.psd1 -Tools $fixtureTools 2>&1 | Out-String; $code = $LASTEXITCODE } finally { Pop-Location }
        Write-Host ($said.TrimEnd() -replace '(?m)^', '    ')
        & $check 'run as a command from the sibling''s root, a relative -Forms is read there, and a missing form exits 1' ($code -eq 1 -and $said -match 'a\.ps1 has no form in forms\.psd1; run by \.githooks/commit-msg:2') $said
    }
    finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $n case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $n cases."
    exit 0
}

exit (Invoke-FormCheck -Root (Get-Location).Path -Forms $Forms -Tools $Tools)
