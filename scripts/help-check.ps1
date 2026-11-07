<#
.SYNOPSIS
    Reads each script under the paths it is given and fails on a comment-based help block that
    PowerShell does not read, on a #Requires line it reads as help text, and on a script that
    does not parse. Exit 0 means every help block in every *.ps1 there is help PowerShell reads.

.DESCRIPTION
    WHY (grado-factorio-tools#342, #316 rulings 1 and 5). When PowerShell cannot read a help
    block it drops it without a word, and Get-Help shows only the syntax line; the block reads
    the same in the file either way. true-nukes-refreshed met it three times on 2026-11-05, a
    line inside the block that starts with a dot and is no help keyword, and
    realistic-fusion-refreshed in twenty-eight scripts, a #Requires line above the block (its
    #151). This merges the two checks: true-nukes-refreshed's scripts/tests/script-help.ps1 at
    78486d2, whose method it keeps, and realistic-fusion-refreshed's scripts/ship-check.ps1
    section 5 at 4de346d, whose #Requires diagnosis it names as a cause.

    THE METHOD. In each *.ps1 under -Path, a directory read with its subdirectories, the block
    comments with a .SYNOPSIS line are found from the parser's comment tokens, so text in a
    string does not count. Rather than repeat PowerShell's rules for which block is whose help,
    it asks the parser: each block is blanked out, its line breaks kept, the script reparsed, and
    the help the parser gives the script and every function compared. A block whose removal
    changes nothing is not read, and fails.

    WHAT A FAILURE NAMES. The script and the block's first line, and each cause it can see: a
    line in the block that starts with a dot and is no help keyword, and a #Requires line above
    the block, which detaches it. Apart from those, a #Requires line on the line straight after a
    read block's closing line, which PowerShell reads into the block's last section and shows as
    help text, fails too; a blank line between them is the fix. A script that does not parse fails,
    naming the parser's first error, and so does a -Path that holds no *.ps1.

    WHAT IT CANNOT SEE. Help written as # line comments. A script whose help block has no
    .SYNOPSIS, which is not read as one, so a script that should have help and has none passes.
    Whether the help says anything true. -SelfTest runs the rule on strings and a scratch folder;
    the script's own call of it, and its exit, are not run.

.PARAMETER Path
    The scripts, or directories of scripts, to read.

.PARAMETER SelfTest
    Run the cases that hold the check to what this header says, naming each as it runs.

.EXAMPLE
    pwsh -File scripts/help-check.ps1 scripts
#>

#Requires -Version 7
[CmdletBinding(DefaultParameterSetName = 'Path')]
param(
    [Parameter(ParameterSetName = 'Path', Mandatory, Position = 0)] [string[]] $Path,
    [Parameter(ParameterSetName = 'SelfTest', Mandatory)] [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# A list handed through pwsh -File arrives as one string.
if ($Path) { $Path = @($Path | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }

$KEYWORDS = 'SYNOPSIS', 'DESCRIPTION', 'PARAMETER', 'EXAMPLE', 'INPUTS', 'OUTPUTS', 'NOTES', 'LINK', 'COMPONENT',
    'ROLE', 'FUNCTIONALITY', 'FORWARDHELPTARGETNAME', 'FORWARDHELPCATEGORY', 'REMOTEHELPRUNSPACE', 'EXTERNALHELP'

# All the help the parser reads in a script: the script's own and each function's, by where the
# function starts, as the comment block the parser built.
function Get-HelpSignature {
    param([System.Management.Automation.Language.ScriptBlockAst] $Ast)
    $help = $Ast.GetHelpContent()
    $parts = @("script: $(if ($help) { $help.GetCommentBlock() } else { '-' })")
    foreach ($f in $Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
        $h = $f.GetHelpContent()
        $parts += "$($f.Extent.StartOffset): $(if ($h) { $h.GetCommentBlock() } else { '-' })"
    }
    $parts -join "`n"
}

# What is wrong with the help in one script's text, a line each, $Where naming the script.
function Get-HelpProblem {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text, [Parameter(Mandatory)] [string] $Where)
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref] $tokens, [ref] $errors)
    if ($errors) { return "$($Where): does not parse: $($errors[0].Message)" }
    $comments = @($tokens | Where-Object Kind -eq 'Comment')
    $requires = @($comments | Where-Object { $_.Text -match '^#requires\b' })
    $blocks = @($comments | Where-Object { $_.Text.StartsWith('<#') -and $_.Text -match '(?m)(?:^|<#)[ \t]*\.SYNOPSIS\b' })
    $read = Get-HelpSignature $ast
    foreach ($block in $blocks) {
        $first = $block.Extent.StartLineNumber
        $blank = $Text.Substring(0, $block.Extent.StartOffset) + ($block.Text -replace '[^\r\n]', ' ') + $Text.Substring($block.Extent.EndOffset)
        $t2 = $null; $e2 = $null
        $without = [System.Management.Automation.Language.Parser]::ParseInput($blank, [ref] $t2, [ref] $e2)
        if ((Get-HelpSignature $without) -ne $read) {
            # Read: it fails only where a #Requires line on the next line is read into it.
            foreach ($r in $requires | Where-Object { $_.Extent.StartLineNumber -eq $block.Extent.EndLineNumber + 1 }) {
                "$($Where):$($r.Extent.StartLineNumber): the #Requires line straight after the help block of line $first is read as help text; put a blank line between the #> and it"
            }
            continue
        }
        "$($Where):$($first): a help block PowerShell does not read"
        $lines = @($block.Text -split '\r?\n')
        for ($n = 0; $n -lt $lines.Count; $n++) {
            $l = $lines[$n].Trim() -replace '^<#\s*', ''
            if ($l -match '^\.([A-Za-z]+)' -and $Matches[1].ToUpperInvariant() -notin $KEYWORDS) {
                "    line $($first + $n) starts with a dot but is no help keyword: $l"
            }
        }
        foreach ($r in $requires | Where-Object { $_.Extent.EndOffset -le $block.Extent.StartOffset }) {
            "    line $($r.Extent.StartLineNumber): a #Requires line above the block detaches it; move it below the block, after a blank line"
        }
    }
}

# The check over -Path, as its exit code and the lines it prints. $Root is what each script's
# name is given relative to.
function Invoke-HelpCheck {
    param([Parameter(Mandatory)] [string[]] $Path, [Parameter(Mandatory)] [string] $Root)
    $files = @(foreach ($p in $Path) {
            if (Test-Path -LiteralPath $p -PathType Container) { Get-ChildItem -LiteralPath $p -Recurse -Filter '*.ps1' -File }
            elseif (Test-Path -LiteralPath $p -PathType Leaf) { Get-Item -LiteralPath $p }
        })
    if (-not $files) { return @{ Code = 1; Lines = @("FAILED - help-check: no *.ps1 under $($Path -join ', '), so nothing was read.") } }
    $problems = @(foreach ($f in $files) {
            Get-HelpProblem -Text ([IO.File]::ReadAllText($f.FullName)) -Where ([IO.Path]::GetRelativePath($Root, $f.FullName) -replace '\\', '/')
        })
    if ($problems) {
        return @{ Code = 1; Lines = @($problems) + "FAILED - help-check: help PowerShell does not read, a #Requires line read as help, or a script that does not parse, among $($files.Count) script(s)." }
    }
    @{ Code = 0; Lines = @("OK - help-check: PowerShell reads every help block in the $($files.Count) script(s) read.") }
}

if ($SelfTest) {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "help-check-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -ItemType Directory -Path (Join-Path $temp 'scripts/sub'), (Join-Path $temp 'empty') -Force | Out-Null
    $script = { param([string[]] $lines) ($lines -join "`n") + "`n" }
    $good = & $script '<#', '.SYNOPSIS', '    Short.', '.DESCRIPTION', '    Long.', '#>', '', '#Requires -Version 7', 'param()',
        'function f {', '    <#  .SYNOPSIS', '        A function''s help.', '    #>', '    1', '}'
    try {
        $cases = [ordered]@{
            'a script whose help and whose function''s help are read, with #Requires after a blank line, has no problem' = {
                @(Get-HelpProblem -Text $good -Where 'good.ps1').Count -eq 0 }
            'a line in the block that starts with a dot and is no help keyword makes the block unread, and is named' = {
                $got = @(Get-HelpProblem -Where 'dot.ps1' -Text (& $script '<#', '.SYNOPSIS', '    Short.', '.githooks is a folder', '#>', 'param()'))
                ($got -join '|') -eq 'dot.ps1:1: a help block PowerShell does not read|    line 4 starts with a dot but is no help keyword: .githooks is a folder' }
            'a #Requires line above the block detaches it, and is named as the cause' = {
                $got = @(Get-HelpProblem -Where 'above.ps1' -Text (& $script '#Requires -Version 7', '<#', '.SYNOPSIS', '    Short.', '#>', 'param()'))
                ($got -join '|') -eq 'above.ps1:2: a help block PowerShell does not read|    line 1: a #Requires line above the block detaches it; move it below the block, after a blank line' }
            'a #Requires line straight after the #> is read as help text and fails; with a blank line between, it does not' = {
                $got = @(Get-HelpProblem -Where 'below.ps1' -Text (& $script '<#', '.SYNOPSIS', '    Short.', '#>', '#Requires -Version 7', 'param()'))
                $gap = @(Get-HelpProblem -Where 'gap.ps1' -Text (& $script '<#', '.SYNOPSIS', '    Short.', '#>', '', '#Requires -Version 7', 'param()'))
                ($got -join '|') -eq 'below.ps1:5: the #Requires line straight after the help block of line 1 is read as help text; put a blank line between the #> and it' -and
                    $gap.Count -eq 0 }
            'a function''s help block that is not read fails, by its own line' = {
                $got = @(Get-HelpProblem -Where 'fn.ps1' -Text (& $script 'param()', 'function f {', '    <#', '    .SYNOPSIS', '        Short.', '    .NET reads this', '    #>', '    1', '}'))
                ($got -join '|') -eq 'fn.ps1:3: a help block PowerShell does not read|    line 6 starts with a dot but is no help keyword: .NET reads this' }
            'a .SYNOPSIS in a string is no block, and a script that does not parse fails, naming the error' = {
                $string = @(Get-HelpProblem -Where 's.ps1' -Text (& $script '$x = @''', '<#', '.SYNOPSIS', '    In a string.', '.bad line', '#>', '''@'))
                $broken = @(Get-HelpProblem -Where 'b.ps1' -Text (& $script 'param(', '<#', '.SYNOPSIS', '    Short.', '#>'))
                $string.Count -eq 0 -and $broken.Count -eq 1 -and $broken[0] -match '^b\.ps1: does not parse: ' }
            'a folder is read with its subdirectories, each problem named by its path; one with no *.ps1 fails' = {
                Set-Content -LiteralPath (Join-Path $temp 'scripts/good.ps1') -Value $good -NoNewline
                Set-Content -LiteralPath (Join-Path $temp 'scripts/sub/bad.ps1') -Value (& $script '#Requires -Version 7', '<#', '.SYNOPSIS', '    S.', '#>') -NoNewline
                $end = Invoke-HelpCheck -Path (Join-Path $temp 'scripts') -Root $temp
                $none = Invoke-HelpCheck -Path (Join-Path $temp 'empty') -Root $temp
                $fine = Invoke-HelpCheck -Path (Join-Path $temp 'scripts/good.ps1') -Root $temp
                $end.Code -eq 1 -and $end.Lines[0] -eq 'scripts/sub/bad.ps1:2: a help block PowerShell does not read' -and
                    $end.Lines[-1] -match 'among 2 script\(s\)\.$' -and
                    $none.Code -eq 1 -and $none.Lines[-1] -match '^FAILED - help-check: no \*\.ps1 under ' -and
                    $fine.Code -eq 0 -and $fine.Lines[-1] -eq 'OK - help-check: PowerShell reads every help block in the 1 script(s) read.' }
        }
        $failures = 0; $n = 0
        foreach ($name in $cases.Keys) {
            $n++
            $ok = try { [bool] (& $cases[$name]) } catch { Write-Host "    threw: $($_.Exception.Message)"; $false }
            Write-Host ("self-test {0}/{1}: {2} -- {3}" -f $n, $cases.Count, $name, $(if ($ok) { 'ok' } else { 'FAILED' }))
            if (-not $ok) { $failures++ }
        }
    }
    finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $($cases.Count) case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $($cases.Count) cases."
    exit 0
}

$end = Invoke-HelpCheck -Path $Path -Root (Get-Location).Path
$end.Lines | ForEach-Object { Write-Host $_ }
exit $end.Code
