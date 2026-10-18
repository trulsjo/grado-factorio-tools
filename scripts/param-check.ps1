<#
.SYNOPSIS
    Reads the param block of each script in a directory and fails on a list parameter that is
    never split on commas. Exit 0 means every top-level [string[]] parameter of every *.ps1 there
    takes the remaining arguments or is split on a comma by a statement of its script.

.DESCRIPTION
    WHY (grado-factorio-tools#163). Under `pwsh -File`, a [string[]] parameter gets `-With a,b`
    as one string, "a,b"; called from PowerShell it gets two. Five scripts here split their lists
    in the body, each on its own, and count-resources.ps1, merged in PR #162, split neither of
    its two: `-With space-age,quality` reached Resolve-BundledSelection as one name and threw.
    A parameter that takes the remaining arguments binds each argument by itself, and is passed.

    WHAT IT READS. With PowerShell's parser, the param block at the top of each *.ps1 in -Path,
    not in its subdirectories. A parameter typed [string[]] is reported unless its [Parameter()]
    names ValueFromRemainingArguments, or one of the script's top-level statements holds both a
    reference to its variable and a -split whose right side is a string with a comma in it. So
    `$With = @($With -split ',')` passes, and so does a foreach over several lists that splits
    each. A function's param block is not read: a function is called from PowerShell, where a
    comma list binds as an array.

    WHAT IT CANNOT SEE. Whether the split runs before the parameter's first use, or on every
    path: a statement that names the variable and splits something else on a comma passes it.
    ValueFromRemainingArguments = $false is read as taking the remaining arguments. A list
    parameter typed other than [string[]], such as [object[]] or [int[]].

.PARAMETER Path
    The directory whose scripts are read.

.PARAMETER SelfTest
    Run the cases that hold the check to what this header says, naming each as it runs.

.EXAMPLE
    pwsh -File scripts/param-check.ps1 scripts
#>

#Requires -Version 7
[CmdletBinding(DefaultParameterSetName = 'Path')]
param(
    [Parameter(ParameterSetName = 'Path', Mandatory, Position = 0)] [string] $Path,
    [Parameter(ParameterSetName = 'SelfTest', Mandatory)] [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-UnsplitParameter {
    <#  The name of each top-level [string[]] parameter of the script at $File that neither takes
        the remaining arguments nor is split on a comma by a top-level statement, and how many
        such list parameters it has, as @{ Lists; Unsplit }.  #>
    param([Parameter(Mandatory)] [string] $File)
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($File, [ref] $null, [ref] $null)
    $result = @{ Lists = 0; Unsplit = @() }
    if (-not $ast.ParamBlock) { return $result }
    $statements = @($ast.BeginBlock, $ast.ProcessBlock, $ast.EndBlock | Where-Object { $_ } | ForEach-Object Statements)
    foreach ($p in $ast.ParamBlock.Parameters) {
        if ($p.StaticType -ne [string[]]) { continue }
        $result.Lists++
        $rest = $p.Attributes | Where-Object { $_ -is [System.Management.Automation.Language.AttributeAst] -and $_.TypeName.Name -eq 'Parameter' } |
            ForEach-Object NamedArguments | Where-Object ArgumentName -eq 'ValueFromRemainingArguments'
        if ($rest) { continue }
        $name = $p.Name.VariablePath.UserPath
        $split = $statements | Where-Object {
            $_.Find({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] -and $n.VariablePath.UserPath -eq $name }, $true) -and
            $_.Find({ param($n) $n -is [System.Management.Automation.Language.BinaryExpressionAst] -and $n.Operator -in 'Split', 'Isplit', 'Csplit' -and
                $n.Right -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $n.Right.Value.Contains(',') }, $true)
        }
        if (-not $split) { $result.Unsplit += $name }
    }
    $result
}

function Invoke-SelfTest {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "param-check-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    $script = { param([string] $text) $f = Join-Path $temp "case-$([guid]::NewGuid().ToString('N').Substring(0, 8)).ps1"; Set-Content -LiteralPath $f -Value $text; $f }
    $read = { param([string] $text) Get-UnsplitParameter (& $script $text) }
    $run = {
        param([string] $dir)
        $text = & pwsh -NoProfile -File $PSCommandPath $dir 2>&1 | Out-String
        @{ Code = $LASTEXITCODE; Text = $text }
    }

    $cases = @(
        @{ Name = 'a [string[]] parameter never split is reported, and one of two is named alone when only the other is split'; Test = {
            $one = & $read 'param([string[]] $L) $L'
            $two = & $read "param([string[]] `$A, [string[]] `$B)`n`$B = @(`$B -split ',')`n`$A + `$B"
            $one.Lists -eq 1 -and "$($one.Unsplit)" -eq 'L' -and $two.Lists -eq 2 -and "$($two.Unsplit)" -eq 'A' } }
        @{ Name = 'a split on a comma passes: the parameter split itself, through ForEach-Object, inside a foreach over several lists, and with -csplit'; Test = {
            $self = & $read "param([string[]] `$L)`n`$L = @(`$L -split ',' | Where-Object { `$_ })"
            $each = & $read "param([string[]] `$L)`n`$L = @(`$L | ForEach-Object { `$_ -split ',' })"
            $loop = & $read "param([string[]] `$A, [string[]] `$B)`n`$A, `$B = foreach (`$x in `$A, `$B) { , @(`$x | ForEach-Object { `$_ -split ',' }) }"
            $case = & $read "param([string[]] `$L)`nif (`$L) { `$L = `$L -csplit '\s*,\s*' }"
            -not ($self, $each, $loop, $case | Where-Object { $_.Unsplit }) -and $loop.Lists -eq 2 } }
        @{ Name = 'a split on something other than a comma, or of another variable alone, does not pass it'; Test = {
            $space = & $read "param([string[]] `$L)`n`$L = `$L -split ' '"
            $other = & $read "param([string[]] `$L, [string] `$S)`n`$parts = `$S -split ','`n`$L"
            "$($space.Unsplit)" -eq 'L' -and "$($other.Unsplit)" -eq 'L' } }
        @{ Name = 'a parameter taking the remaining arguments passes, and so does one typed [string]'; Test = {
            $rest = & $read 'param([Parameter(ValueFromRemainingArguments)] [string[]] $L, [string] $S) $L'
            $rest.Lists -eq 1 -and -not $rest.Unsplit } }
        @{ Name = 'a function''s [string[]] parameter is not read, and neither is a script with no param block'; Test = {
            $fn = & $read "function f { param([string[]] `$L) `$L }`nf a b"
            $none = & $read 'Write-Host hello'
            $fn.Lists -eq 0 -and $none.Lists -eq 0 } }
        @{ Name = 'run on a directory it exits 1 naming the script and each parameter, and 0 when every list is split; a subdirectory is not read'; Test = {
            $bad = Join-Path $temp 'bad'; $good = Join-Path $temp 'good'
            New-Item -ItemType Directory -Path $bad, (Join-Path $good 'sub') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $bad 'count.ps1') -Value 'param([string[]] $Mods, [string[]] $With) $Mods + $With'
            Set-Content -LiteralPath (Join-Path $good 'ok.ps1') -Value "param([string[]] `$With)`n`$With = @(`$With -split ',')"
            Set-Content -LiteralPath (Join-Path $good 'sub/deep.ps1') -Value 'param([string[]] $L) $L'
            $refused = & $run $bad
            $passed = & $run $good
            Write-Host ($refused.Text.TrimEnd() -replace '(?m)^', '    ')
            Write-Host ($passed.Text.TrimEnd() -replace '(?m)^', '    ')
            $refused.Code -eq 1 -and $refused.Text -match '(?m)^param-check: count\.ps1 -Mods ' -and $refused.Text -match '(?m)^param-check: count\.ps1 -With ' -and
                $refused.Text -match '(?m)^FAILED - param-check: 2 ' -and $passed.Code -eq 0 -and $passed.Text -match '(?m)^OK - param-check: 1 list parameter\(s\) in 1 script' } }
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
$lists = 0
$unsplit = 0
foreach ($s in $scripts) {
    $r = Get-UnsplitParameter $s.FullName
    $lists += $r.Lists
    foreach ($name in $r.Unsplit) {
        $unsplit++
        Write-Host "param-check: $($s.Name) -$name is a [string[]] parameter that is never split on a comma. Under pwsh -File, -$name a,b arrives as one string: split it, as `$$name = @(`$$name -split ',' | Where-Object { `$_ }), or take the remaining arguments."
    }
}
if ($unsplit) {
    Write-Host ''
    Write-Host "FAILED - param-check: $unsplit of $lists list parameter(s) in $($scripts.Count) script(s) are never split on a comma."
    exit 1
}
Write-Host "OK - param-check: $lists list parameter(s) in $($scripts.Count) script(s), each split on a comma or taking the remaining arguments."
exit 0
