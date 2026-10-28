<#
.SYNOPSIS
    Reads each script in a directory and fails on a scope that spells one variable two ways
    that differ only in case. Exit 0 means that in every *.ps1 there, each scope spells each of
    its variables one way.

.DESCRIPTION
    WHY (grado-factorio-tools#285). PowerShell variable names ignore case, so $KEYWORD and
    $keyword are one variable. In one session, by its account (2026-10-27/28), a scriptblock in
    markdown-rewrap.ps1 set $keyword = '' and emptied the pattern held in $KEYWORD, and a
    foreach ($b in ...) in follow-pin.ps1's self-test replaced the commit held in $B. Neither
    showed an error where it went wrong.

    THE RULE. Within one scope, every variable is spelt one way. A scope is the script itself, a
    function, a scriptblock or a trap's body, each with its own parameters, a function's written
    after its name as much as in a param block. A scope holds only the variables written in it,
    not those of one nested in it, with one exception: a scriptblock handed to ForEach-Object or
    Where-Object, or an alias of either ($CALLER_SCOPE_COMMANDS), module-qualified or not, bare,
    in parentheses or after -Process:, is read as part of the scope it stands in, as PowerShell
    runs it there (Truls, 2026-10-28, on #285); but not with -Parallel, which runs it in a
    runspace of its own. A name with a scope or drive qualifier, as $script:x, $env:x, $global:x
    or $using:x, is outside the rule. Two spellings in one scope fail, naming the script, each
    spelling and the first line it stands on. A script that does not parse fails, named as such,
    and so does a -Path that holds no *.ps1. Only the scripts in -Path are read, not those in its
    subdirectories.

    WHAT IT CANNOT SEE. A variable reached through Get-Variable, Set-Variable or a string. A
    dot-sourced file's variables, which join the caller's scope. Any other scriptblock that runs
    in its parent's scope, read here as its own, among them one run with `.` rather than `&`,
    one held in a variable and then handed to ForEach-Object, one handed to a .ForEach() or
    .Where() method, and one handed to Measure-Command. A child scope that reads its parent's
    variable under another spelling, as & { $X } inside a scope that sets $x, which is one
    variable read across scopes. An automatic variable spelt two ways, as $True and $true, fails
    like any other.

.PARAMETER Path
    The directory whose scripts are read.

.PARAMETER SelfTest
    Run the cases that hold the check to what this header says, naming each as it runs.

.EXAMPLE
    pwsh -File scripts/variable-case-check.ps1 scripts
#>

#Requires -Version 7
[CmdletBinding(DefaultParameterSetName = 'Path')]
param(
    [Parameter(ParameterSetName = 'Path', Mandatory, Position = 0)] [string] $Path,
    [Parameter(ParameterSetName = 'SelfTest', Mandatory)] [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The commands, and their aliases, whose scriptblock runs in the caller's scope (Truls, on #285).
$CALLER_SCOPE_COMMANDS = @('ForEach-Object', '%', 'foreach', 'Where-Object', '?', 'where')

function Get-CallerScopeCommand {
    <#  The command that hands the scriptblock $Block to be run in its caller's scope, or nothing:
        one of $CALLER_SCOPE_COMMANDS, module-qualified or not, the block given bare, in
        parentheses or after -Process:, and without -Parallel, which runs it in a runspace of
        its own.  #>
    param([Parameter(Mandatory)] [System.Management.Automation.Language.ScriptBlockAst] $Block)
    $at = $Block.Parent
    if ($at -isnot [System.Management.Automation.Language.ScriptBlockExpressionAst]) { return }
    $at = $at.Parent
    while ($at -is [System.Management.Automation.Language.CommandExpressionAst] -or $at -is [System.Management.Automation.Language.PipelineAst] -or
        $at -is [System.Management.Automation.Language.ParenExpressionAst] -or $at -is [System.Management.Automation.Language.CommandParameterAst]) { $at = $at.Parent }
    if ($at -isnot [System.Management.Automation.Language.CommandAst]) { return }
    if (("$($at.GetCommandName())" -replace '^.*\\') -notin $CALLER_SCOPE_COMMANDS) { return }
    $parallel = $at.CommandElements | Where-Object {
        $_ -is [System.Management.Automation.Language.CommandParameterAst] -and $_.ParameterName.Length -ge 2 -and 'parallel'.StartsWith($_.ParameterName.ToLowerInvariant()) }
    if (-not $parallel) { $at }
}

function Get-VariableScope {
    <#  The scope $Variable is written in: the nearest scriptblock, or the function whose
        parameters are written after its name, or a trap's body, which runs in a scope of its own;
        past a block handed to a command that runs it in its caller's scope.  #>
    param([Parameter(Mandatory)] [System.Management.Automation.Language.VariableExpressionAst] $Variable)
    $at = $Variable.Parent
    while ($true) {
        while ($at -isnot [System.Management.Automation.Language.ScriptBlockAst] -and $at -isnot [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $at -isnot [System.Management.Automation.Language.TrapStatementAst]) { $at = $at.Parent }
        if ($at -is [System.Management.Automation.Language.FunctionDefinitionAst]) { return $at.Body }
        if ($at -is [System.Management.Automation.Language.TrapStatementAst]) { return $at }
        $command = Get-CallerScopeCommand -Block $at
        if (-not $command) { return $at }
        $at = $command
    }
}

function Get-CaseClash {
    <#  Each variable that a scope of the script at $File spells more than one way, as
        @{ Spellings = @(@{ Name; Line }) }, one entry per spelling at its first line, in order of
        those lines.  #>
    param([Parameter(Mandatory)] [string] $File)
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($File, [ref] $null, [ref] $errors)
    if ($errors) { throw "$(Split-Path $File -Leaf) does not parse: line $($errors[0].Extent.StartLineNumber), $($errors[0].Message)" }
    # Not @{}: a key such as values would shadow .Values, which is read below.
    $scopes = [System.Collections.Generic.Dictionary[object, object]]::new()
    foreach ($v in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] }, $true)) {
        $name = $v.VariablePath.UserPath
        # $script:x, $env:x and the like name a scope or a drive, not this one; $using:x keeps its
        # qualifier on the expression around it.
        if ($name.Contains(':') -or $v.Parent -is [System.Management.Automation.Language.UsingExpressionAst]) { continue }
        $at = Get-VariableScope -Variable $v
        if (-not $scopes.ContainsKey($at)) { $scopes[$at] = [System.Collections.Generic.Dictionary[string, object]]::new([StringComparer]::OrdinalIgnoreCase) }
        $variable = $scopes[$at]
        if (-not $variable.ContainsKey($name)) { $variable[$name] = [System.Collections.Generic.Dictionary[string, int]]::new([StringComparer]::Ordinal) }
        # The smallest line, as the walk does not go in the order of the source: a loop's
        # condition comes before its body.
        $spellings = $variable[$name]
        $line = $v.Extent.StartLineNumber
        if (-not $spellings.ContainsKey($name) -or $line -lt $spellings[$name]) { $spellings[$name] = $line }
    }
    foreach ($variable in $scopes.Values) {
        foreach ($spellings in $variable.Values) {
            if ($spellings.Count -gt 1) { @{ Spellings = @($spellings.GetEnumerator() | Sort-Object Value, Key | ForEach-Object { @{ Name = $_.Key; Line = $_.Value } }) } }
        }
    }
}

function Invoke-SelfTest {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "variable-case-check-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    $script = { param([string] $text) $f = Join-Path $temp "case-$([guid]::NewGuid().ToString('N').Substring(0, 8)).ps1"; Set-Content -LiteralPath $f -Value $text; $f }
    # Each clash as "name@line,name@line", joined by "|".
    $read = { param([string] $text) (@(Get-CaseClash (& $script $text)) | ForEach-Object { ($_.Spellings | ForEach-Object { "$($_.Name)@$($_.Line)" }) -join ',' }) -join '|' }
    $run = {
        param([string] $dir)
        $text = & pwsh -NoProfile -File $PSCommandPath $dir 2>&1 | Out-String
        @{ Code = $LASTEXITCODE; Text = $text }
    }

    $cases = @(
        @{ Name = 'a scriptblock that assigns $keyword while reading $KEYWORD fails, naming both at their first lines'; Test = {
            $got = & $read "function f {`n    `$KEYWORD = '^x'`n    & {`n        `$m = 'a' -cmatch `$KEYWORD`n        `$keyword = ''`n    }`n}"
            $got -eq 'KEYWORD@4,keyword@5' } }
        @{ Name = 'a foreach ($b in ...) in a scope that holds $B fails'; Test = {
            $got = & $read "`$B = 'abc123'`nforeach (`$b in @(@{ x = 1 })) { `$b.x }`n`$B.Substring(0, 3)"
            $got -eq 'B@1,b@2' } }
        @{ Name = 'a block handed to ForEach-Object, Where-Object or an alias of either is read in the scope around it; a block run with & is not'; Test = {
            $foreach = & $read "`$KEYWORD = '^x'`n1 | ForEach-Object { `$keyword = '' }"
            $aliases = & $read "`$Out = 1`n1 | % { 2 | ? { `$out } }"
            $called = & $read "`$KEYWORD = '^x'`n& { `$keyword = '' }"
            # Each name of the ruling, and the forms a block is handed in.
            $named = & $read "`$A = 1`n1 | Where-Object { `$a }`n`$B = 1`n1 | foreach { `$b }`n`$C = 1`n1 | where { `$c }"
            $forms = & $read "`$D = 1`n1 | Microsoft.PowerShell.Core\ForEach-Object { `$d }`n`$E = 1`n1 | ForEach-Object ({ `$e })`n`$F = 1`n1 | ForEach-Object -Process:{ `$f }"
            # -Parallel runs the block in a runspace of its own, and -Pa is -Parallel too.
            $parallel = & $read "`$G = 1`n1 | ForEach-Object -Parallel { `$g = 2 }`n1 | % -Pa { `$g }"
            $foreach -eq 'KEYWORD@1,keyword@2' -and $aliases -eq 'Out@1,out@2' -and $called -eq '' -and
                $named -eq 'A@1,a@2|B@3,b@4|C@5,c@6' -and $forms -eq 'D@1,d@2|E@3,e@4|F@5,f@6' -and $parallel -eq '' } }
        @{ Name = 'a trap''s body is a scope of its own, and each spelling is named at its first line though the walk reads a loop''s condition first'; Test = {
            $trap = & $read "`$X = 1`ntrap { `$x = 2; continue }"
            $loop = & $read "`$A = 0`ndo {`n    `$a++`n} while (`$a -lt 3)"
            $trapFirst = & $read "`$x = 1`n& { trap { `$y; continue }; `$Y }"
            $trap -eq '' -and $loop -eq 'A@1,a@3' -and $trapFirst -eq '' } }
        @{ Name = 'a nested scriptblock''s own $Name parameter, in a function that uses $name, passes, and so does a nested function''s'; Test = {
            $block = & $read "function f {`n    `$name = 'a'`n    `$g = { param(`$Name) `$Name }`n    & `$g `$name`n}"
            $nested = & $read "function f {`n    `$name = 'a'`n    function g([string] `$Name) { `$Name }`n    g `$name`n}"
            $block -eq '' -and $nested -eq '' } }
        @{ Name = 'a function''s parameter belongs to the function: param($Out) with $out = ... in its body fails, and so does one written after the name'; Test = {
            $block = & $read "function f {`n    param(`$Out)`n    `$out = 'x'`n}"
            $after = & $read "function f([string] `$Out) {`n    `$out = 'x'`n}"
            $block -eq 'Out@2,out@3' -and $after -eq 'Out@1,out@2' } }
        @{ Name = '$script:X beside $x passes, and so do $env:Path beside $path and $env:PATH, $global:N beside $n and $global:n, and $using:k beside $K'; Test = {
            $got = & $read "`$x = 1`n`$script:X = 2`n`$path = `$env:Path`n`$p = `$env:PATH`n`$n = `$global:N`n`$global:n = 1"
            $using = & $read "function f {`n    `$K = 1`n    1 | ForEach-Object -Parallel { `$using:k }`n    & { `$using:k }`n}"
            $got -eq '' -and $using -eq '' } }
        @{ Name = 'one spelling used many times passes, and three spellings are named each at its first line'; Test = {
            $one = & $read "`$a = 1`n`$a++`n`$a"
            $three = & $read "`$Abc = 1`n`$abc = 2`n`$Abc`n`$ABC = 3"
            $one -eq '' -and $three -eq 'Abc@1,abc@2,ABC@4' } }
        @{ Name = 'run on a directory it exits 1 naming the script and each spelling, and 0 when each is spelt one way; a subdirectory is not read'; Test = {
            $bad = Join-Path $temp 'bad'; $good = Join-Path $temp 'good'
            New-Item -ItemType Directory -Path $bad, (Join-Path $good 'sub') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $bad 'clash.ps1') -Value "`$Out = 1`n`$out = 2"
            Set-Content -LiteralPath (Join-Path $good 'ok.ps1') -Value "`$out = 1`n`$out"
            Set-Content -LiteralPath (Join-Path $good 'sub/deep.ps1') -Value "`$Out = 1`n`$out = 2"
            $refused = & $run $bad
            $passed = & $run $good
            Write-Host ($refused.Text.TrimEnd() -replace '(?m)^', '    ')
            Write-Host ($passed.Text.TrimEnd() -replace '(?m)^', '    ')
            $refused.Code -eq 1 -and $refused.Text -match '(?m)^variable-case-check: clash\.ps1 spells one variable 2 ways: \$Out at line 1, \$out at line 2' -and
                $refused.Text -match '(?m)^FAILED - variable-case-check: 1 ' -and $passed.Code -eq 0 -and $passed.Text -match '(?m)^OK - variable-case-check: 1 script\(s\)' } }
        @{ Name = 'a script that does not parse fails, named as such, and so does a directory with no script in it'; Test = {
            $broken = Join-Path $temp 'broken'; $empty = Join-Path $temp 'empty'
            New-Item -ItemType Directory -Path $broken, $empty -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $broken 'half.ps1') -Value 'param([string[]] $L'
            $unparsed = & $run $broken
            $none = & $run $empty
            Write-Host ($unparsed.Text.TrimEnd() -replace '(?m)^', '    ')
            Write-Host ($none.Text.TrimEnd() -replace '(?m)^', '    ')
            $unparsed.Code -eq 1 -and $unparsed.Text -match 'half\.ps1 does not parse' -and
                $none.Code -eq 1 -and $none.Text -match '(?m)^FAILED - variable-case-check: no \*\.ps1 in ' } }
    )

    $failures = 0
    $n = 0
    try {
        foreach ($c in $cases) {
            $n++
            $ok = try { [bool] (& $c.Test) } catch { Write-Host "    threw: $($_.Exception.Message)"; $false }
            Write-Host ("self-test {0}/{1}: {2} -- {3}" -f $n, $cases.Count, $c.Name, $(if ($ok) { 'ok' } else { 'FAILED' }))
            if (-not $ok) { $failures++ }
        }
    }
    finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $($cases.Count) case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $($cases.Count) cases."
    exit 0
}

if ($SelfTest) { Invoke-SelfTest }

$scripts = @(Get-ChildItem -LiteralPath $Path -Filter *.ps1 -File | Sort-Object Name)
# A path that holds no script must not pass for having had nothing to read.
if (-not $scripts) { Write-Host "FAILED - variable-case-check: no *.ps1 in $Path."; exit 1 }
$clashes = 0
foreach ($s in $scripts) {
    foreach ($clash in @(Get-CaseClash $s.FullName)) {
        $clashes++
        $named = ($clash.Spellings | ForEach-Object { "`$$($_.Name) at line $($_.Line)" }) -join ', '
        Write-Host "variable-case-check: $($s.Name) spells one variable $($clash.Spellings.Count) ways: $named. PowerShell reads them as one variable: spell it one way."
    }
}
if ($clashes) {
    Write-Host ''
    Write-Host "FAILED - variable-case-check: $clashes variable(s) in $($scripts.Count) script(s) are spelt more than one way in one scope."
    exit 1
}
Write-Host "OK - variable-case-check: $($scripts.Count) script(s), each scope spelling each variable one way."
exit 0
