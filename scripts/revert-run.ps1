<#
.SYNOPSIS
    Runs a list of reverts, and with -Defaults and -Conditions the reverts it writes, on a copy of
    the repository, one at a time, and reports each as failing, passing or crashed its self-test, or
    as refused. Exit 0 means every revert was run or refused; it says nothing of what they found,
    which the report does.

.DESCRIPTION
    WHY (grado-factorio-tools#284). A review's bug scan, and the session answering it, revert
    each claim of a script on a copy and run its -SelfTest, as docs/agents/review-brief.md's
    *The reverts* asks. Each wrote its own driver, and in one session (2026-10-27/28) three
    misread their runs: a sed revert that deleted the case along with the check, a self-test that
    threw before its summary line read as passing, and a slow self-test run by hand per revert.

    THE COPY is a git working tree the caller made, a clone at the commit under review. It is
    refused, exit 1 and nothing run, when it has uncommitted changes or untracked files, which are
    named.

    THE LIST is a PowerShell data file:

        @{ Reverts = @(
            @{ Name = 'F1'; File = 'scripts/x.ps1'; Find = 'if ($a) {'; Replace = 'if ($true) {'
               SelfTest = 'scripts/x.ps1'; Args = @('-NoGame'); Lines = 1 }
        ) }

    THE DEFAULT REVERTS (grado-factorio-tools#382). In PR #374 a self-test passed four times
    whatever a parameter's default was, because its runner carried a default of its own, and
    each was found only by a reviewer who thought to revert that default by hand. With -Defaults,
    for each script it names, a path from the copy's root, the run writes the reverts itself,
    after the list's, from the script's param() block as the parser reads it. A default revert
    is, for a list default, one per element, that element dropped from it: `$Path = @('a', 'b')`
    gives `$Path = @('b')` and `$Path = @('a')`, and a lone element dropped gives `@()`. A
    default is a list where it is written as one, `@()` of constants comma-separated or one to a
    line, or a parenthesised comma list of them, or where the parameter's type is a list, an
    array as [string[]] or [array] (#394), and its default one constant, in parentheses or not.
    Parentheses round a list, a hashtable or $null are read through, so (@('a')) and
    (('a', 'b')) are lists and ($null) is $null. A constant is a number or a string with nothing
    expanded in it. For a scalar default it is one revert, another value put in its place: a
    string gets -reverted after it, a number 1 added, $true or $false the other. Each is named
    `default -<Name> ...`, edits the text from the parameter's variable to the end of its default,
    its Find running from the script's param( so that a self-test's runner that repeats the default
    does not make it occur twice (as two did in the first run for #382's pull request), and runs the
    script's own -SelfTest with no Args, as a list's revert is run and in the same table. The run
    prints how many it wrote for each script, and a line for each default it wrote none for: one
    computed at run time, as `(Get-Date)`, `"$x"` or a list holding either, on any parameter; $null,
    on any parameter; an empty list; and a shape it does not read, with its text: a hashtable, in
    parentheses or not, or one written-out value in parentheses, a constant, $true or $false, on a
    parameter whose type is not a list (#391, #394). A script it writes no
    revert for, or that does not parse, fails the run, exit 1 and nothing run, as a step that read
    nothing.

    THE CONDITION REVERTS (grado-factorio-tools#400). On PR #395 the panel found 14 guards whose
    reverts passed the self-test after two hand-written lists of 40 and 101; 12 were of three
    shapes a parser can find. With -Conditions, for each script it names, a path from the copy's
    root, the run writes, after the default reverts, one revert per operand of an -and or -or
    chain, that operand dropped with the operator beside it, and one per element of a comma list
    on the right of -in or -notin, or of a comma list of type literals elsewhere, that element
    dropped with its comma. A chain is read whole: in
    `$a -and $b -and $c` each of the three is dropped once, and a chain inside an operand, in
    parentheses or of the other operator, is a chain of its own. Each Find is the whole lines the
    chain or list spans, and Lines is their count; each is named
    `condition <file>:<line> <operator> drops <text>`, or `type list` for the operator, and runs
    the script's own -SelfTest with no Args. A shape whose Find occurs other than once is named
    with its line, and no revert written for it. With -Base <ref>, only an operand or element on a
    line `git -C <copy> diff -U0 <ref>` adds or changes is dropped. As with -Defaults, a script
    it writes no revert for, -Base or not, or that does not parse, fails the run, exit 1 and
    nothing run.

    File and SelfTest are paths from the copy's root. Args is optional, handed to the self-test
    after -SelfTest. Lines is optional, 1 unless given. Find and Replace are exact text, matched
    with case; a line break in either, LF or CRLF, is read as the file's own.

    EACH REVERT, IN ORDER. Refused, and not run, where Find is empty; where File is not a file
    git tracks in the copy under that very name, as one outside the copy, an untracked one, or
    one named in another case, which git could not restore; where Find occurs in File other than
    exactly once, naming the count; where git reads File as binary; or where the edit changes no
    line or more than Lines, removed or added, by `git -C <copy> diff --numstat`. A refused revert
    leaves the file as it was.
    Otherwise `git -C <copy> diff --stat` is printed and the self-test is run, as
    `pwsh -NoProfile -File <SelfTest> -SelfTest <Args>`, from the copy's root. Its result is:
    *fails*, it exited other than 0 and its last summary line is `FAILED - self-test...`;
    *passes*, it exited 0 and that line is `OK - self-test...`, which code-review.md makes a
    finding; *crashed*, anything else, as no summary line, whatever the exit code, or a summary
    line its exit code contradicts. The file is then restored with
    `git -C <copy> checkout -- <File>`, and the copy checked clean again: one left dirty stops the
    run, exit 1, naming what is left and reporting the reverts run so far.

    THE REPORT is a line per revert as it runs, and at the end a Markdown table of name, result,
    exit code and summary line, for a review comment.

    WHAT IT CANNOT SEE. Whether a revert is the right one: a Find that matches once but in the
    wrong place is run. A self-test whose summary line is worded other than this repository's
    `OK - self-test` and `FAILED - self-test`, which reads as crashed; check.ps1 fails such a
    self-test among those it runs (grado-factorio-tools#297), not one that needs the game, nor one
    in a sibling. A revert across two files,
    or by a pattern. A self-test that changes a tracked file and puts it back.
    Of -Defaults: a default computed at run time, which it names and writes no revert for; a
    hashtable, in parentheses or not, and one constant, $true or $false in parentheses on a
    parameter whose type is not a list, shapes it does not read, which it names with their text
    and writes no revert for; a list type other than an array and [array], as a generic list,
    whose default, if one constant not in parentheses, is read as a scalar's; a
    parameter with no param() default, as one the script's body sets when it is not given, which
    it does not name; a function's parameters; which of a scalar's other values matter, as it
    tries one; and a default revert whose self-test needs Args, as -NoGame.
    Of -Conditions: a regex alternation, as `a|b`; how many times a loop runs; a condition built
    in more than one statement, as `$x = $a; if ($x -and $b)`, whose $a it does not drop; a list
    on the right of -in in parentheses or @(), or held in a variable; -cin and -cnotin,
    which match with case; -contains, -xor, -not and the comparison operators; a type list that
    holds anything but type literals; a condition revert whose self-test needs Args; and with -Base,
    a condition the diff deletes, which leaves nothing to drop, or one it changes by a line outside
    the operand, as the `if (` above it.

.PARAMETER Copy
    The git working tree to revert in.

.PARAMETER List
    The .psd1 file of reverts. None unless given; -List, -Defaults, -Conditions or more than one
    must be.

.PARAMETER Defaults
    The scripts, as paths from the copy's root, whose default reverts are written and run after
    the list's. None unless given.

.PARAMETER Conditions
    The scripts, as paths from the copy's root, whose condition reverts are written and run after
    the default reverts. None unless given.

.PARAMETER Base
    A ref of the copy: -Conditions then writes reverts only on the lines `git diff <ref>`
    changes. Only with -Conditions.

.PARAMETER SelfTest
    Run the cases that hold the runner to what this header says, on a scratch repository, naming
    each as it runs. Needs git.

.EXAMPLE
    pwsh -File scripts/revert-run.ps1 -Copy C:/scratch/copy -List C:/scratch/reverts.psd1

.EXAMPLE
    pwsh -File scripts/revert-run.ps1 -Copy C:/scratch/copy -Defaults 'scripts/a.ps1,scripts/b.ps1'

.EXAMPLE
    pwsh -File scripts/revert-run.ps1 -Copy C:/scratch/copy -Conditions scripts/a.ps1 -Base origin/main
#>

#Requires -Version 7
[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    [Parameter(ParameterSetName = 'Run', Mandatory)] [string] $Copy,
    [Parameter(ParameterSetName = 'Run')] [string] $List = '',
    [Parameter(ParameterSetName = 'Run')] [string[]] $Defaults = @(),
    [Parameter(ParameterSetName = 'Run')] [string[]] $Conditions = @(),
    [Parameter(ParameterSetName = 'Run')] [string] $Base = '',
    [Parameter(ParameterSetName = 'SelfTest', Mandatory)] [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# A list handed through pwsh -File arrives as one string.
$Defaults = @($Defaults | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$Conditions = @($Conditions | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

# The default reverts of the script at $Script, a path from $Root: for each parameter whose
# param() block gives a default, one revert per element of a list default, that element dropped,
# and one for a scalar default, another value put in its place. Each is a revert as a list's is,
# its self-test the script's own. Unwritten names each default it could not write one for, and why.
function Get-DefaultRevert {
    param([Parameter(Mandatory)] [string] $Root, [Parameter(Mandatory)] [string] $Script)
    $file = $Script -replace '\\', '/'
    $path = Join-Path $Root $file
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "-Defaults names $Script, which is not a file in the copy." }
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref] $tokens, [ref] $errors)
    if ($errors) { throw "$Script does not parse, so its defaults cannot be read: $($errors[0].Message)" }
    $text = $ast.Extent.Text
    $reverts = [System.Collections.Generic.List[hashtable]]::new()
    $unwritten = [System.Collections.Generic.List[string]]::new()
    $params = if ($ast.ParamBlock) { @($ast.ParamBlock.Parameters) } else { @() }
    # A value written out, not computed: a string with nothing expanded in it, or a number.
    $isConstant = { param($e)
        $e -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
        ($e -is [System.Management.Automation.Language.ExpandableStringExpressionAst] -and -not @($e.NestedExpressions)) -or
        ($e -is [System.Management.Automation.Language.ConstantExpressionAst] -and $e.Value -is [ValueType]) }
    foreach ($p in $params) {
        $default = $p.DefaultValue
        if (-not $default) { continue }
        $name = $p.Name.VariablePath.UserPath
        # From the script's param( to the end of this default, so the Find occurs once where a
        # self-test's runner repeats the default; only the text from the variable on is replaced,
        # and that is the lines the edit may change.
        $base = $ast.Extent.StartOffset
        $from = $ast.ParamBlock.Extent.StartOffset - $base
        $at = $p.Name.Extent.StartOffset - $base
        $prefix = $text.Substring($from, $at - $from)
        $own = $text.Substring($at, $default.Extent.EndOffset - $base - $at)
        $lines = @($own -split '\r?\n').Count
        $revert = { param([string] $label, [string] $value)
            $reverts.Add(@{ Name = "default -$name $label"; File = $file; Find = $prefix + $own; Replace = $prefix + "`$$name = $value"; SelfTest = $file; Lines = $lines }) }
        # A list default: @() of constants, one to a statement or comma-separated, a parenthesised
        # comma list of them, or a constant on an array-typed parameter. Anything else in it, a
        # command or a variable, is computed at run time, and no revert is written.
        # $null, on a typed parameter as on an untyped one, and a hashtable, named before the
        # list's reading, which would take either for computed (#391).
        # Parentheses round a list, a hashtable or $null are read through, so (@('a')) is a list
        # and ($null) is $null; a line names the default as written (#394).
        $shown = $default.Extent.Text
        while ($default -is [System.Management.Automation.Language.ParenExpressionAst]) {
            $pipe = $default.Pipeline
            $inner = if ($pipe -is [System.Management.Automation.Language.PipelineAst] -and @($pipe.PipelineElements).Count -eq 1 -and
                $pipe.PipelineElements[0] -is [System.Management.Automation.Language.CommandExpressionAst]) { $pipe.PipelineElements[0].Expression }
            $through = $inner -is [System.Management.Automation.Language.ParenExpressionAst] -or $inner -is [System.Management.Automation.Language.ArrayExpressionAst] -or
                $inner -is [System.Management.Automation.Language.HashtableAst] -or
                ($inner -is [System.Management.Automation.Language.VariableExpressionAst] -and $inner.VariablePath.UserPath -eq 'null')
            if (-not $through) { break }
            $default = $inner
        }
        # [array] is a list type too, though its IsArray is false (#394).
        $isList = $p.StaticType.IsArray -or $p.StaticType -eq [array]
        if ($default -is [System.Management.Automation.Language.VariableExpressionAst] -and $default.VariablePath.UserPath -eq 'null') {
            $unwritten.Add("-${name}: its default is `$null, which is no value"); continue
        }
        if ($default -is [System.Management.Automation.Language.HashtableAst]) {
            $unwritten.Add("-${name}: its default is a hashtable, $shown, a shape -Defaults does not read"); continue
        }
        $elements = $null
        $computed = $false
        $single = $false
        # Assigned in each branch: an if that yields an empty array, as @()'s, assigns $null.
        $statements = $null
        if ($default -is [System.Management.Automation.Language.ArrayExpressionAst]) { $statements = @($default.SubExpression.Statements) }
        elseif ($default -is [System.Management.Automation.Language.ParenExpressionAst]) { $statements = @($default.Pipeline) }
        if ($null -ne $statements) {
            $elements = @(foreach ($s in $statements) {
                    $x = if ($s -is [System.Management.Automation.Language.PipelineAst] -and @($s.PipelineElements).Count -eq 1 -and
                        $s.PipelineElements[0] -is [System.Management.Automation.Language.CommandExpressionAst]) { $s.PipelineElements[0].Expression }
                    if ($x -is [System.Management.Automation.Language.ArrayLiteralAst]) { $x.Elements } elseif ($x) { $x } else { $computed = $true }
                })
            # A parenthesised default is a list as a comma list, or as one element on an
            # array-typed parameter; one element on another is a value in parentheses.
            $single = $default -is [System.Management.Automation.Language.ParenExpressionAst] -and $elements.Count -lt 2 -and -not $isList
        }
        elseif ($isList) { $elements = @($default) }
        # One written-out value in parentheses, a constant, $true or $false, is named by its
        # shape before the computed test, which reads $true as a variable (#394).
        $isBool = { param($e) $e -is [System.Management.Automation.Language.VariableExpressionAst] -and $e.VariablePath.UserPath -in 'true', 'false' }
        if ($single -and -not $computed -and $elements.Count -eq 1 -and ((& $isConstant $elements[0]) -or (& $isBool $elements[0]))) {
            $unwritten.Add("-${name}: its default is a value in parentheses, $shown, a shape -Defaults does not read"); continue
        }
        if ($null -ne $elements -and ($computed -or @($elements | Where-Object { -not ((& $isConstant $_) -or (& $isBool $_)) }))) {
            $unwritten.Add("-${name}: its default is computed at run time"); continue
        }
        if ($null -ne $elements) {
            if (-not $elements) { $unwritten.Add("-${name}: its default is an empty list, with no element to drop"); continue }
            for ($i = 0; $i -lt $elements.Count; $i++) {
                $rest = @(for ($j = 0; $j -lt $elements.Count; $j++) { if ($j -ne $i) { $elements[$j].Extent.Text } })
                & $revert "drops $($elements[$i].Extent.Text)" "@($($rest -join ', '))"
            }
            continue
        }
        $was = $default.Extent.Text
        $isString = $default -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
            ($default -is [System.Management.Automation.Language.ExpandableStringExpressionAst] -and -not @($default.NestedExpressions))
        if ($isString) {
            $other = "'$("$($default.Value)-reverted" -replace "'", "''")'"
            & $revert "$was -> $other" $other
        }
        elseif ($default -is [System.Management.Automation.Language.ConstantExpressionAst] -and $default.Value -is [ValueType]) {
            $other = "$($default.Value + 1)"
            & $revert "$was -> $other" $other
        }
        elseif ($default -is [System.Management.Automation.Language.VariableExpressionAst] -and $default.VariablePath.UserPath -in 'true', 'false') {
            $other = if ($default.VariablePath.UserPath -eq 'true') { '$false' } else { '$true' }
            & $revert "$was -> $other" $other
        }
        else { $unwritten.Add("-${name}: its default is computed at run time") }
    }
    @{ Reverts = @($reverts); Unwritten = @($unwritten) }
}

# The condition reverts of the script at $Script, a path from $Root (#400): one per operand of an
# -and or -or chain, that operand dropped with its operator, and one per element of a comma list
# on the right of -in or -notin, or of a comma list of type literals, that element dropped with
# its comma. Each Find is the whole lines the chain or list spans. With $Since, only an operand or
# element on a line `git diff $Since` changes. Unwritten names each shape whose Find occurs other
# than once.
function Get-ConditionRevert {
    param([Parameter(Mandatory)] [string] $Root, [Parameter(Mandatory)] [string] $Script, [string] $Since = '')
    $file = $Script -replace '\\', '/'
    $path = Join-Path $Root $file
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "-Conditions names $Script, which is not a file in the copy." }
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref] $tokens, [ref] $errors)
    if ($errors) { throw "$Script does not parse, so its conditions cannot be read: $($errors[0].Message)" }
    $text = $ast.Extent.Text
    $origin = $ast.Extent.StartOffset
    $changed = $null
    if ($Since) {
        $hunks = @(git -C $Root diff -U0 $Since -- $file 2>$null)
        if ($LASTEXITCODE) { throw "-Base $Since is not a ref git can diff in the copy." }
        $changed = [System.Collections.Generic.HashSet[int]]::new()
        foreach ($h in $hunks) {
            if ($h -match '^@@ -\S+ \+(\d+)(?:,(\d+))? @@') {
                $count = if ($Matches[2]) { [int] $Matches[2] } else { 1 }
                for ($l = [int] $Matches[1]; $l -lt [int] $Matches[1] + $count; $l++) { [void] $changed.Add($l) }
            }
        }
    }
    # Each shape: the node whose lines are the Find, the operator named, and the parts to drop.
    $shapes = [System.Collections.Generic.List[hashtable]]::new()
    $inLists = [System.Collections.Generic.HashSet[object]]::new()
    $isLink = { param($n, $op) $n -is [System.Management.Automation.Language.BinaryExpressionAst] -and $n.Operator -eq $op }
    foreach ($b in @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.BinaryExpressionAst] }, $true))) {
        $op = $b.Operator
        if ($op -eq 'And' -or $op -eq 'Or') {
            # A link inside a longer chain of the same operator is read with that chain.
            if (& $isLink $b.Parent $op) { continue }
            $parts = [System.Collections.Generic.List[object]]::new()
            $walk = { param($n) if (& $isLink $n $op) { & $walk $n.Left; & $walk $n.Right } else { $parts.Add($n) } }
            & $walk $b
            $shapes.Add(@{ Node = $b; Op = $b.ErrorPosition.Text; Parts = @($parts) })
        }
        elseif (($op -eq 'Iin' -or $op -eq 'Inotin') -and $b.Right -is [System.Management.Automation.Language.ArrayLiteralAst]) {
            [void] $inLists.Add($b.Right)
            $shapes.Add(@{ Node = $b.Right; Op = $b.ErrorPosition.Text; Parts = @($b.Right.Elements) })
        }
    }
    foreach ($l in @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.ArrayLiteralAst] }, $true))) {
        if ($inLists.Contains($l) -or @($l.Elements | Where-Object { $_ -isnot [System.Management.Automation.Language.TypeExpressionAst] })) { continue }
        $shapes.Add(@{ Node = $l; Op = 'type list'; Parts = @($l.Elements) })
    }
    $reverts = [System.Collections.Generic.List[hashtable]]::new()
    $unwritten = [System.Collections.Generic.List[string]]::new()
    foreach ($s in @($shapes | Sort-Object { $_.Node.Extent.StartOffset })) {
        $parts = $s.Parts
        $drops = @(for ($i = 0; $i -lt $parts.Count; $i++) {
                $lines = $parts[$i].Extent.StartLineNumber..$parts[$i].Extent.EndLineNumber
                if ($null -eq $changed -or @($lines | Where-Object { $changed.Contains($_) })) { $i }
            })
        # By its count: a lone index 0 reads false.
        if (-not $drops.Count) { continue }
        # The whole lines the shape spans, so that the Find is more likely to occur once.
        $start = $s.Node.Extent.StartOffset - $origin; $end = $s.Node.Extent.EndOffset - $origin
        $from = $start - [regex]::Match($text.Substring(0, $start), '[^\r\n]*$').Length
        $to = $end + [regex]::Match($text.Substring($end), '^[^\r\n]*').Length
        $find = $text.Substring($from, $to - $from)
        $line = $s.Node.Extent.StartLineNumber
        $count = Get-OccurrenceCount -Text $text -Find $find
        if ($count -ne 1) { $unwritten.Add("line $line, a $($s.Op) whose Find occurs $count times"); continue }
        foreach ($i in $drops) {
            # The first part goes with the operator or comma after it; any other, with the one
            # before.
            $cut = if ($i -eq 0) { @($parts[0].Extent.StartOffset, $parts[1].Extent.StartOffset) } else { @($parts[$i - 1].Extent.EndOffset, $parts[$i].Extent.EndOffset) }
            $a = $cut[0] - $origin - $from; $z = $cut[1] - $origin - $from
            $shown = $parts[$i].Extent.Text -replace '\s+', ' '
            $reverts.Add(@{ Name = "condition ${file}:$($parts[$i].Extent.StartLineNumber) $($s.Op) drops $shown"; File = $file; Find = $find
                    Replace = $find.Substring(0, $a) + $find.Substring($z); SelfTest = $file; Lines = @($find -split '\r?\n').Count })
        }
    }
    @{ Reverts = @($reverts); Unwritten = @($unwritten) }
}

# What is uncommitted or untracked in the copy, one path to a line, or nothing.
function Get-DirtyPath {
    param([Parameter(Mandatory)] [string] $Root)
    $status = @(git -C $Root status --porcelain --untracked-files=all)
    if ($LASTEXITCODE) { throw "git status failed in $Root; is it a git working tree?" }
    $status | Where-Object { $_ } | ForEach-Object { $_.Substring(3) }
}

# How many times $Find stands in $Text, matched with case.
function Get-OccurrenceCount {
    param([string] $Text, [string] $Find)
    $count = 0; $at = 0
    while (($at = $Text.IndexOf($Find, $at, [StringComparison]::Ordinal)) -ge 0) { $count++; $at += $Find.Length }
    $count
}

# The self-test's result from its exit code and what it printed: fails, passes or crashed, and
# its last summary line.
function Get-RevertResult {
    param([int] $ExitCode, [string] $Said)
    $summary = @([regex]::Matches($Said, '(?m)^(OK|FAILED) - self-test.*$') | ForEach-Object { $_.Value.TrimEnd() })
    $last = if ($summary) { $summary[-1] } else { '' }
    $result = if ($last -like 'FAILED*' -and $ExitCode) { 'fails' } elseif ($last -like 'OK*' -and -not $ExitCode) { 'passes' } else { 'crashed' }
    @{ Result = $result; Summary = $last }
}

# One revert applied, run and restored; returns its row. Throws when the copy is left dirty.
function Invoke-Revert {
    param([Parameter(Mandatory)] [string] $Root, [Parameter(Mandatory)] [hashtable] $Revert)
    $row = @{ Name = $Revert.Name; Result = 'refused'; Exit = ''; Summary = '' }
    $lines = if ($Revert.ContainsKey('Lines')) { [int] $Revert.Lines } else { 1 }
    $find = [string] $Revert.Find; $replace = [string] $Revert.Replace
    # An empty Find occurs everywhere, and counting it would never end.
    if (-not $find) { $row.Summary = 'Find is empty'; return $row }
    # Only a file git tracks under this very name can be restored by git: not one outside the
    # copy, an untracked one, or one named in another case, which Windows would let be written.
    $file = $Revert.File -replace '\\', '/'
    $tracked = @(git -C $Root ls-files -- $file 2>$null)
    if ($LASTEXITCODE -or $tracked.Count -ne 1 -or $tracked[0] -cne $file) { $row.Summary = "$($Revert.File) is not a file git tracks in the copy under that name"; return $row }
    $path = Join-Path $Root $file
    $bytes = [IO.File]::ReadAllBytes($path)
    $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $text = [Text.UTF8Encoding]::new($false).GetString($bytes, $(if ($bom) { 3 } else { 0 }), $bytes.Length - $(if ($bom) { 3 } else { 0 }))
    # A line break in the list, LF or CRLF, is read as the file's own.
    $find = $find -replace '\r\n', "`n"; $replace = $replace -replace '\r\n', "`n"
    if ($text.Contains("`r`n")) { $find = $find -replace '\n', "`r`n"; $replace = $replace -replace '\n', "`r`n" }
    $count = Get-OccurrenceCount -Text $text -Find $find
    if ($count -ne 1) { $row.Summary = "Find occurs $count times in $file, not once"; return $row }
    $at = $text.IndexOf($find, [StringComparison]::Ordinal)
    $edited = $text.Substring(0, $at) + $replace + $text.Substring($at + $find.Length)
    [IO.File]::WriteAllText($path, $edited, [Text.UTF8Encoding]::new($bom))
    try {
        $numstat = "$(git -C $Root diff --numstat -- $file)".Trim()
        if ($LASTEXITCODE) { throw "git diff --numstat -- $file failed in $Root." }
        $counts = if ($numstat) { @($numstat -split '\s+')[0..1] } else { '0', '0' }
        # git counts no lines of a file it reads as binary, and prints - for each.
        if ($counts -contains '-') { $row.Summary = "git reads $file as binary, so its changed lines cannot be counted"; return $row }
        $added, $removed = $counts | ForEach-Object { [int] $_ }
        if (-not ($added -or $removed)) { $row.Summary = 'the edit changes no line'; return $row }
        if ($added -gt $lines -or $removed -gt $lines) { $row.Summary = "the edit changes $added added and $removed removed lines, more than Lines = $lines"; return $row }
        Write-Host "revert-run: $($Revert.Name), git -C <copy> diff --stat:"
        git -C $Root diff --stat | ForEach-Object { Write-Host "    $_" }
        $extra = if ($Revert.ContainsKey('Args')) { @($Revert.Args) } else { @() }
        Push-Location $Root
        try { $said = & pwsh -NoProfile -File (Join-Path $Root $Revert.SelfTest) -SelfTest @extra 2>&1 | Out-String; $code = $LASTEXITCODE }
        finally { Pop-Location }
        $judged = Get-RevertResult -ExitCode $code -Said $said
        $row.Result = $judged.Result; $row.Exit = "$code"; $row.Summary = $judged.Summary
        $row
    }
    finally {
        git -C $Root checkout -q -- $file
        if ($LASTEXITCODE) { throw "git checkout -- $file failed in $Root." }
    }
}

# The rows as a Markdown table, for a review comment.
function Format-RevertTable {
    param([object[]] $Rows)
    '| Revert | Result | Exit | Summary line |'
    '|---|---|---|---|'
    foreach ($r in $Rows) { "| $($r.Name) | $($r.Result) | $($r.Exit) | $(($r.Summary -replace '\|', '\|')) |" }
}

# The run over $ListPath in $Root: the rows, printed as they go and as a table; throws where it
# cannot run.
function Invoke-RevertRun {
    param([Parameter(Mandatory)] [string] $Root, [string] $ListPath = '', [string[]] $Defaults = @(), [string[]] $Conditions = @(), [string] $Since = '')
    if (-not $ListPath -and -not $Defaults -and -not $Conditions) { throw 'give -List, -Defaults, -Conditions or more than one, so there is a revert to run.' }
    if ($Since -and -not $Conditions) { throw '-Base limits -Conditions, which is not given.' }
    $dirty = @(Get-DirtyPath -Root $Root)
    if ($dirty) { throw "the copy $Root has uncommitted changes, so no revert was run: $($dirty -join ', ')" }
    $all = [System.Collections.Generic.List[object]]::new()
    if ($ListPath) {
        $data = try { Import-PowerShellDataFile -LiteralPath $ListPath } catch { throw "the list $ListPath cannot be read: $($_.Exception.Message)" }
        if (-not $data.ContainsKey('Reverts') -or -not @($data.Reverts)) { throw "the list $ListPath holds no Reverts." }
        foreach ($r in @($data.Reverts)) {
            $missing = @('Name', 'File', 'Find', 'Replace', 'SelfTest' | Where-Object { -not ($r -is [hashtable] -and $r.ContainsKey($_)) })
            if ($missing) { throw "a revert in $ListPath lacks $($missing -join ', ')." }
            $all.Add($r)
        }
    }
    foreach ($script in $Defaults) {
        $written = Get-DefaultRevert -Root $Root -Script $script
        Write-Host "revert-run: $($written.Reverts.Count) default revert(s) written for $script."
        foreach ($u in $written.Unwritten) { Write-Host "revert-run: $script, not written: $u." }
        # A script named that yields no revert is a step that read nothing (#383).
        if (-not $written.Reverts) { throw "-Defaults names $script, for which no default revert could be written, so no revert was run." }
        foreach ($r in $written.Reverts) { $all.Add($r) }
    }
    foreach ($script in $Conditions) {
        $written = Get-ConditionRevert -Root $Root -Script $script -Since $Since
        Write-Host "revert-run: $($written.Reverts.Count) condition revert(s) written for $script$(if ($Since) { ", on lines changed since $Since" })."
        foreach ($u in $written.Unwritten) { Write-Host "revert-run: $script, not written: $u." }
        # As for -Defaults, a script named that yields no revert read nothing.
        if (-not $written.Reverts) { throw "-Conditions names $script, for which no condition revert could be written, so no revert was run." }
        foreach ($r in $written.Reverts) { $all.Add($r) }
    }
    $rows = [System.Collections.Generic.List[object]]::new()
    try {
        foreach ($r in $all) {
            $row = Invoke-Revert -Root $Root -Revert $r # strict-lists: one
            $rows.Add($row)
            Write-Host "revert-run: $($row.Name) -- $($row.Result)$(if ($row.Exit) { " (exit $($row.Exit))" }): $($row.Summary)"
            $left = @(Get-DirtyPath -Root $Root)
            if ($left) { throw "after $($row.Name) the copy is left dirty, so no later revert was run: $($left -join ', ')" }
        }
    }
    finally {
        Write-Host ''
        Format-RevertTable -Rows $rows | ForEach-Object { Write-Host $_ }
    }
    $rows
}

function Invoke-SelfTest {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "revert-run-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    $repo = Join-Path $temp 'copy'
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    $git = { git -C $repo -c user.name=selftest -c user.email=selftest@example.invalid -c commit.gpgsign=false @args; if ($LASTEXITCODE) { throw "git $args failed; the self-test needs git." } }
    # A self-test stub: it fails when $a is reverted, passes whatever else changes, and with -Mode
    # throws before its summary line or leaves a file behind.
    $stub = @(
        'param([switch] $SelfTest, [string] $Mode)'
        "`$a = 'alpha'"
        "`$b = 'beta'"
        "`$c = 'gamma'"
        "if (`$Mode -eq 'throw') { throw 'boom before the summary' }"
        "if (`$Mode -eq 'dirty') { Set-Content -LiteralPath (Join-Path `$PSScriptRoot 'left.txt') -Value x }"
        "if (`$Mode -eq 'root' -and (Get-Location).Path -ne `$PSScriptRoot) { Write-Host 'FAILED - self-test: not run from the copy''s root.'; exit 1 }"
        "if (`$a -eq 'alpha') { Write-Host 'OK - self-test passed: all 1 cases.'; exit 0 }"
        "Write-Host 'FAILED - self-test: 1 of 1 case(s) did not hold.'"
        'exit 1'
    ) -join "`n"
    $stubPath = Join-Path $repo 'stub.ps1'
    & $git init --quiet
    & $git config core.autocrlf false
    [IO.File]::WriteAllText($stubPath, "$stub`n")
    # A file git reads as binary, and an ignored one, which leaves the copy clean.
    [IO.File]::WriteAllBytes((Join-Path $repo 'bin.dat'), [byte[]] @(0x61, 0x62, 0x00, 0x63, 0x0A))
    Set-Content -LiteralPath (Join-Path $repo '.gitignore') -Value 'ignored.txt'
    Set-Content -LiteralPath (Join-Path $repo 'ignored.txt') -Value 'ignored one'
    Set-Content -LiteralPath (Join-Path $temp 'outside.txt') -Value 'outside one'
    # A script whose param() block has a default of each kind: it passes unless 'a' is dropped
    # from -Kinds or -Main is not 'main'.
    $fixture = @(
        'param([switch] $SelfTest, [string[]] $Kinds = @(''a'', ''b''), [string] $Main = ''main'', [int] $Count = 3,'
        '    [bool] $On = $true, $When = (Get-Date), [string] $None, $Nil = $null, [string[]] $Empty = @(), [string[]] $One = ''x'','
        '    [string[]] $Single = @(''s''), $Piped = @(Get-ChildItem), [string] $Quoted = "main", $Paren = (''p'', ''q''),'
        '    [string[]] $Wrapped = @(''w1'','
        '        ''w2''),'
        '    [string[]] $Stacked = @('
        '        ''k1'''
        '        ''k2'''
        '    ),'
        '    [string[]] $Listed = (Get-ChildItem -Name), [string[]] $Expand = "$PSScriptRoot/x",'
        '    $Map = @{ k = 1 }, [string[]] $OneParen = (''o''), [string[]] $TypedNil = $null, $Bare = (''v''),'
        '    $Loose = @(''u''), $PT = ($true), $PN = ($null), $PH = (@{ k = 1 }), $PA = (@(''a'')), $PL = ((''a'', ''b'')),'
        '    [array] $PX = (''x''), $PP = (@(''a'') | Sort-Object), $PV = ($x), [array] $PY = ''y'', $PD = ((''v'')),'
        '    $PQ = ((@(''q''))), $PF = ($false), $PE = ("$x"), $PS = ($s = 1), [string[]] $PB = ($true))'
        '# A runner that repeats two defaults, as a self-test''s does: the Find still occurs once.'
        '$run = { param([string[]] $Kinds = @(''a'', ''b''), [int] $Count = 3) }'
        "if (`$Kinds -contains 'a' -and `$Main -eq 'main') { Write-Host 'OK - self-test passed: all 1 cases.'; exit 0 }"
        "Write-Host 'FAILED - self-test: 1 of 1 case(s) did not hold.'"
        'exit 1'
    ) -join "`n"
    [IO.File]::WriteAllText((Join-Path $repo 'defaults.ps1'), "$fixture`n")
    # One whose param() block gives no default, and one that does not parse.
    [IO.File]::WriteAllText((Join-Path $repo 'nodefault.ps1'), "param([switch] `$SelfTest, [string] `$Name)`n")
    [IO.File]::WriteAllText((Join-Path $repo 'broken.ps1'), "param([string] `$Name = 'x'`n")
    # A script with a condition of each shape -Conditions reads, two of them on twin lines whose
    # Find occurs twice, and two shapes it must not read: it passes unless 'b' leaves -in, [int] a
    # type list, or either -or loses its first operand.
    $conditions = @(
        'param([switch] $SelfTest)'
        "`$x = 'b'"
        '$k = [int]'
        "`$ok = `$x -ne 'a' -and `$x -ne 'z'"
        "`$hit = `$x -in 'a', 'b'"
        "`$no = `$x -notin 'q', 'r'"
        '$types = [string], [int]'
        "`$or = `$x -eq 'b' -or `$x -eq 'y' -or `$x -eq 'w'"
        '$typed = $k -in [string], [int]'
        "`$d = `$x -eq 'd' -or `$x -eq 'b'"
        "`$d = `$x -eq 'd' -or `$x -eq 'b'"
        # Neither a comma list on the right of another operator, nor -in a lone value, is read.
        "`$eq = `$x -eq 'q', 'r'"
        "`$lone = `$x -in 'b'"
        # A chain over two lines: its Find and Lines span both.
        "`$two = `$x -eq 'b' -or"
        "    `$x -eq 'n'"
        "if (@(`$ok, `$hit, `$no, `$or, `$typed, (`$types -contains `$k), `$two) -notcontains `$false) { Write-Host 'OK - self-test passed: all 1 cases.'; exit 0 }"
        "Write-Host 'FAILED - self-test: 1 of 1 case(s) did not hold.'"
        'exit 1'
    ) -join "`n"
    [IO.File]::WriteAllText((Join-Path $repo 'conditions.ps1'), "$conditions`n")
    & $git add stub.ps1 bin.dat .gitignore defaults.ps1 nodefault.ps1 broken.ps1 conditions.ps1
    & $git commit --quiet -m stub
    $list = { param([string] $name, [string] $text) $p = Join-Path $temp "$name.psd1"; Set-Content -LiteralPath $p -Value $text; $p }
    $one = { param([string] $Find, [string] $Replace, [string] $More = '') "@{ Name = 'R'; File = 'stub.ps1'; Find = '$Find'; Replace = '$Replace'; SelfTest = 'stub.ps1'$More }" }
    $run = {
        param([string] $listPath)
        $text = & pwsh -NoProfile -File $PSCommandPath -Copy $repo -List $listPath 2>&1 | Out-String
        @{ Code = $LASTEXITCODE; Text = $text }
    }
    $same = { [IO.File]::ReadAllText($stubPath) -ceq "$stub`n" -and -not @(Get-DirtyPath -Root $repo) }

    $cases = @(
        @{ Name = '-Defaults writes one revert per element of a list default and one per scalar default, names each default it cannot write, and runs them as a list''s'; Test = {
            $written = Get-DefaultRevert -Root $repo -Script 'defaults.ps1'
            # Each Replace is the Find's text up to the variable, then the new default: its tail.
            $said = @($written.Reverts | ForEach-Object { "$($_.Name) => $([regex]::Match($_.Replace, '\$\w+ = (?:(?!\$\w+ = ).)*$').Value)" })
            $want = @(
                "default -Kinds drops 'a' => `$Kinds = @('b')", "default -Kinds drops 'b' => `$Kinds = @('a')",
                "default -Main 'main' -> 'main-reverted' => `$Main = 'main-reverted'", 'default -Count 3 -> 4 => $Count = 4',
                'default -On $true -> $false => $On = $false', "default -One drops 'x' => `$One = @()",
                "default -Single drops 's' => `$Single = @()", "default -Quoted `"main`" -> 'main-reverted' => `$Quoted = 'main-reverted'",
                "default -Paren drops 'p' => `$Paren = @('q')", "default -Paren drops 'q' => `$Paren = @('p')",
                "default -Wrapped drops 'w1' => `$Wrapped = @('w2')", "default -Wrapped drops 'w2' => `$Wrapped = @('w1')",
                "default -Stacked drops 'k1' => `$Stacked = @('k2')", "default -Stacked drops 'k2' => `$Stacked = @('k1')",
                "default -OneParen drops 'o' => `$OneParen = @()", "default -Loose drops 'u' => `$Loose = @()",
                "default -PA drops 'a' => `$PA = @()", "default -PL drops 'a' => `$PL = @('b')", "default -PL drops 'b' => `$PL = @('a')",
                "default -PX drops 'x' => `$PX = @()", "default -PY drops 'y' => `$PY = @()",
                "default -PQ drops 'q' => `$PQ = @()", 'default -PB drops $true => $PB = @()')
            $unwritten = @('-When: its default is computed at run time', '-Nil: its default is $null, which is no value',
                '-Empty: its default is an empty list, with no element to drop', '-Piped: its default is computed at run time',
                '-Listed: its default is computed at run time', '-Expand: its default is computed at run time',
                '-Map: its default is a hashtable, @{ k = 1 }, a shape -Defaults does not read', '-TypedNil: its default is $null, which is no value',
                "-Bare: its default is a value in parentheses, ('v'), a shape -Defaults does not read",
                '-PT: its default is a value in parentheses, ($true), a shape -Defaults does not read', '-PN: its default is $null, which is no value',
                '-PH: its default is a hashtable, (@{ k = 1 }), a shape -Defaults does not read',
                '-PP: its default is computed at run time', '-PV: its default is computed at run time',
                "-PD: its default is a value in parentheses, (('v')), a shape -Defaults does not read",
                '-PF: its default is a value in parentheses, ($false), a shape -Defaults does not read',
                '-PE: its default is computed at run time', '-PS: its default is computed at run time')
            # The lines each default spans, which its revert may change.
            $spans = @($written.Reverts | ForEach-Object { "$($_.Name.Split(' ')[1])=$($_.Lines)" } | Sort-Object -Unique)
            $got = & pwsh -NoProfile -File $PSCommandPath -Copy $repo -Defaults 'defaults.ps1' 2>&1 | Out-String
            $code = $LASTEXITCODE
            Write-Host ($got.TrimEnd() -replace '(?m)^', '    ')
            $rows = @([regex]::Matches($got, '(?m)^\| (default [^|]+) \| (\w+) \|') | ForEach-Object { "$($_.Groups[1].Value.Trim()): $($_.Groups[2].Value)" })
            $printed = @([regex]::Matches($got, '(?m)^revert-run: defaults\.ps1, not written: (.+)\.\r?$') | ForEach-Object { $_.Groups[1].Value })
            ($said -join '|') -ceq ($want -join '|') -and ($written.Unwritten -join '|') -ceq ($unwritten -join '|') -and
                ($printed -join '|') -ceq ($unwritten -join '|') -and
                ($spans -join ' ') -ceq '-Count=1 -Kinds=1 -Loose=1 -Main=1 -On=1 -One=1 -OneParen=1 -PA=1 -Paren=1 -PB=1 -PL=1 -PQ=1 -PX=1 -PY=1 -Quoted=1 -Single=1 -Stacked=4 -Wrapped=2' -and
                @($written.Reverts | Where-Object { -not $_.Find.StartsWith('param([switch] $SelfTest, ') -or $_.SelfTest -ne 'defaults.ps1' }).Count -eq 0 -and
                $code -eq 0 -and $got -match '(?m)^revert-run: 23 default revert\(s\) written for defaults\.ps1\.' -and
                ($rows -join '|') -ceq ((@($want | ForEach-Object { $_ -replace ' => .*$' }) | ForEach-Object {
                            "$($_): $(if ($_ -like '*Kinds drops ''a''' -or $_ -like '*-Main *') { 'fails' } else { 'passes' })" }) -join '|') -and (& $same) } }
        @{ Name = '-Defaults reads a comma list, and fails, exit 1 and nothing run, a script that yields no revert or does not parse (#389)'; Test = {
            $none = & pwsh -NoProfile -File $PSCommandPath -Copy $repo -Defaults 'defaults.ps1,nodefault.ps1' 2>&1 | Out-String; $noneCode = $LASTEXITCODE
            $broken = & pwsh -NoProfile -File $PSCommandPath -Copy $repo -Defaults 'broken.ps1' 2>&1 | Out-String; $brokenCode = $LASTEXITCODE
            Write-Host (($none + $broken).TrimEnd() -replace '(?m)^', '    ')
            $noneCode -eq 1 -and $none -match '(?m)^revert-run: 23 default revert\(s\) written for defaults\.ps1\.' -and
                $none -match '-Defaults names nodefault\.ps1, for which no default revert could be written, so no revert was run' -and
                $none -notmatch '(?m)^revert-run: default ' -and
                $brokenCode -eq 1 -and $broken -match 'broken\.ps1 does not parse, so its defaults cannot be read' -and (& $same) } }
        @{ Name = '-Conditions writes one revert per operand of an -and or -or chain and per element of an -in, -notin or type list, with a chain over two lines whose Find and Lines span both, names a shape whose Find is not unique, and runs them as a list''s (#400)'; Test = {
            $written = Get-ConditionRevert -Root $repo -Script 'conditions.ps1'
            $said = @($written.Reverts | ForEach-Object { "$($_.Name) => $($_.Replace)" })
            $c = 'condition conditions.ps1'
            $want = @(
                "${c}:4 -and drops `$x -ne 'a' => `$ok = `$x -ne 'z'", "${c}:4 -and drops `$x -ne 'z' => `$ok = `$x -ne 'a'",
                "${c}:5 -in drops 'a' => `$hit = `$x -in 'b'", "${c}:5 -in drops 'b' => `$hit = `$x -in 'a'",
                "${c}:6 -notin drops 'q' => `$no = `$x -notin 'r'", "${c}:6 -notin drops 'r' => `$no = `$x -notin 'q'",
                "${c}:7 type list drops [string] => `$types = [int]", "${c}:7 type list drops [int] => `$types = [string]",
                "${c}:8 -or drops `$x -eq 'b' => `$or = `$x -eq 'y' -or `$x -eq 'w'",
                "${c}:8 -or drops `$x -eq 'y' => `$or = `$x -eq 'b' -or `$x -eq 'w'",
                "${c}:8 -or drops `$x -eq 'w' => `$or = `$x -eq 'b' -or `$x -eq 'y'",
                "${c}:9 -in drops [string] => `$typed = `$k -in [int]", "${c}:9 -in drops [int] => `$typed = `$k -in [string]",
                "${c}:14 -or drops `$x -eq 'b' => `$two = `$x -eq 'n'", "${c}:15 -or drops `$x -eq 'n' => `$two = `$x -eq 'b'")
            $unwritten = @('line 10, a -or whose Find occurs 2 times', 'line 11, a -or whose Find occurs 2 times')
            $failing = @("${c}:5 -in drops 'b'", "${c}:7 type list drops [int]", "${c}:8 -or drops `$x -eq 'b'", "${c}:9 -in drops [int]", "${c}:14 -or drops `$x -eq 'b'")
            $got = & pwsh -NoProfile -File $PSCommandPath -Copy $repo -Conditions 'conditions.ps1' 2>&1 | Out-String
            $code = $LASTEXITCODE
            Write-Host ($got.TrimEnd() -replace '(?m)^', '    ')
            $rows = @([regex]::Matches($got, '(?m)^\| (condition [^|]+) \| (\w+) \|') | ForEach-Object { "$($_.Groups[1].Value.Trim()): $($_.Groups[2].Value)" })
            $printed = @([regex]::Matches($got, '(?m)^revert-run: conditions\.ps1, not written: (.+)\.\r?$') | ForEach-Object { $_.Groups[1].Value })
            ($said -join '|') -ceq ($want -join '|') -and ($written.Unwritten -join '|') -ceq ($unwritten -join '|') -and
                ($printed -join '|') -ceq ($unwritten -join '|') -and $code -eq 0 -and
                @($written.Reverts | Where-Object { $_.File -ne 'conditions.ps1' -or $_.SelfTest -ne 'conditions.ps1' -or $_.Lines -ne ($_.Name -match ':1[45] ' ? 2 : 1) }).Count -eq 0 -and
                $got -match '(?m)^revert-run: 15 condition revert\(s\) written for conditions\.ps1\.' -and
                ($rows -join '|') -ceq ((@($want | ForEach-Object { $_ -replace ' => .*$' }) | ForEach-Object {
                            "$($_): $(if ($_ -in $failing) { 'fails' } else { 'passes' })" }) -join '|') -and (& $same) } }
        @{ Name = '-Conditions fails, exit 1 and nothing run, a script that yields no revert, does not parse or is not in the copy (#400)'; Test = {
            $none = & pwsh -NoProfile -File $PSCommandPath -Copy $repo -Conditions 'nodefault.ps1' 2>&1 | Out-String; $noneCode = $LASTEXITCODE
            $broken = & pwsh -NoProfile -File $PSCommandPath -Copy $repo -Conditions 'conditions.ps1,broken.ps1' 2>&1 | Out-String; $brokenCode = $LASTEXITCODE
            $missing = & pwsh -NoProfile -File $PSCommandPath -Copy $repo -Conditions 'no-such.ps1' 2>&1 | Out-String; $missingCode = $LASTEXITCODE
            Write-Host (($none + $broken + $missing).TrimEnd() -replace '(?m)^', '    ')
            $noneCode -eq 1 -and $none -match '-Conditions names nodefault\.ps1, for which no condition revert could be written, so no revert was run' -and
                $brokenCode -eq 1 -and $broken -match 'broken\.ps1 does not parse, so its conditions cannot be read' -and
                $broken -match '(?m)^revert-run: 15 condition revert\(s\) written for conditions\.ps1\.' -and $broken -notmatch '(?m)^revert-run: condition ' -and
                $missingCode -eq 1 -and $missing -match '-Conditions names no-such\.ps1, which is not a file in the copy' -and (& $same) } }
        @{ Name = '-Base writes condition reverts only on the lines git diff <ref> changes, a hunk of one line or more, the first operand of a chain over two lines when only its line changed, says the ref in the line it prints, and fails with no -Conditions or a ref git cannot diff (#400)'; Test = {
            # Lines 5 and 6 changed in one hunk, and line 9 in a hunk of its own.
            $lines = [IO.File]::ReadAllText((Join-Path $repo 'conditions.ps1')) -split "`n"
            $lines[4] = "`$hit = `$x -in 'a', 'b', 'c'"; $lines[5] = "`$no = `$x -notin 'q', 'r', 's'"; $lines[8] = '$typed = $k -in [string], [int], [char]'
            [IO.File]::WriteAllText((Join-Path $repo 'conditions.ps1'), ($lines -join "`n"))
            & $git commit --quiet -am 'base'
            $written = Get-ConditionRevert -Root $repo -Script 'conditions.ps1' -Since 'HEAD~1'
            $said = @($written.Reverts | ForEach-Object { $_.Name -replace '^condition conditions\.ps1:' })
            $alone = & pwsh -NoProfile -File $PSCommandPath -Copy $repo -List (& $list 'base' "@{ Reverts = @( $(& $one "`$b = ''beta''" "`$b = ''other''") ) }") -Base 'HEAD~1' 2>&1 | Out-String
            $aloneCode = $LASTEXITCODE
            $badRef = & pwsh -NoProfile -File $PSCommandPath -Copy $repo -Conditions 'conditions.ps1' -Base 'no-such-ref' 2>&1 | Out-String; $badRefCode = $LASTEXITCODE
            Write-Host (($alone + $badRef).TrimEnd() -replace '(?m)^', '    ')
            # A chain over two lines, of which only the first operand's line changed.
            [IO.File]::WriteAllText((Join-Path $repo 'spans.ps1'), "`$ok = `$x -ne 'a' -and`n    `$x -ne 'z'`n")
            & $git add spans.ps1; & $git commit --quiet -m 'spans'
            [IO.File]::WriteAllText((Join-Path $repo 'spans.ps1'), "`$ok = `$x -ne 'b' -and`n    `$x -ne 'z'`n")
            & $git commit --quiet -am 'first'
            $spans = @((Get-ConditionRevert -Root $repo -Script 'spans.ps1' -Since 'HEAD~1').Reverts)
            # Through the command line, the written line names the ref.
            $since = & pwsh -NoProfile -File $PSCommandPath -Copy $repo -Conditions 'spans.ps1' -Base 'HEAD~1' 2>&1 | Out-String; $sinceCode = $LASTEXITCODE
            Write-Host ($since.TrimEnd() -replace '(?m)^', '    ')
            $sinceCode -eq 0 -and $since -match '(?m)^revert-run: 1 condition revert\(s\) written for spans\.ps1, on lines changed since HEAD~1\.\r?$' -and
                $spans.Count -eq 1 -and $spans[0].Name -ceq "condition spans.ps1:1 -and drops `$x -ne 'b'" -and $spans[0].Lines -eq 2 -and
                $spans[0].Find -ceq "`$ok = `$x -ne 'b' -and`n    `$x -ne 'z'" -and $spans[0].Replace -ceq "`$ok = `$x -ne 'z'" -and
                ($said -join '|') -ceq "5 -in drops 'a'|5 -in drops 'b'|5 -in drops 'c'|6 -notin drops 'q'|6 -notin drops 'r'|6 -notin drops 's'|9 -in drops [string]|9 -in drops [int]|9 -in drops [char]" -and
                -not $written.Unwritten -and $aloneCode -eq 1 -and $alone -match '-Base limits -Conditions, which is not given' -and
                $badRefCode -eq 1 -and $badRef -match '-Base no-such-ref is not a ref git can diff in the copy' -and (& $same) } }
        @{ Name = 'with neither -List, -Defaults nor -Conditions, and with -Defaults naming no file of the copy, the run fails, exit 1, and runs nothing'; Test = {
            $neither = & pwsh -NoProfile -File $PSCommandPath -Copy $repo 2>&1 | Out-String; $neitherCode = $LASTEXITCODE
            $missing = & pwsh -NoProfile -File $PSCommandPath -Copy $repo -Defaults 'no-such.ps1' 2>&1 | Out-String; $missingCode = $LASTEXITCODE
            $neitherCode -eq 1 -and $neither -match 'give -List, -Defaults, -Conditions or more than one' -and
                $missingCode -eq 1 -and $missing -match '-Defaults names no-such\.ps1, which is not a file in the copy' -and (& $same) } }
        @{ Name = 'Find occurring 0 times, twice, or only ignoring case is refused with the count, and so is an edit that changes no line; the file is unchanged'; Test = {
            $p = & $list 'count' "@{ Reverts = @( $(& $one 'zzz' 'y'), $(& $one "''alpha''" "''other''"), $(& $one "`$A = ''ALPHA''" 'y'), $(& $one "`$b = ''beta''" "`$b = ''beta''") ) }"
            $got = & $run $p
            Write-Host ($got.Text.TrimEnd() -replace '(?m)^', '    ')
            $got.Code -eq 0 -and @([regex]::Matches($got.Text, '(?m)^revert-run: R -- refused: Find occurs 0 times in stub\.ps1')).Count -eq 2 -and
                $got.Text -match '(?m)^revert-run: R -- refused: Find occurs 2 times in stub\.ps1' -and
                $got.Text -match '(?m)^revert-run: R -- refused: the edit changes no line' -and (& $same) } }
        @{ Name = 'an empty Find, a File outside the copy, ignored or named in another case, and a binary File are refused, and no file is changed'; Test = {
            $at = { param($file, $find) "@{ Name = 'R'; File = '$file'; Find = '$find'; Replace = 'zz'; SelfTest = 'stub.ps1' }" }
            $p = & $list 'refused' "@{ Reverts = @( $(& $at 'stub.ps1' ''), $(& $at '../outside.txt' 'outside'), $(& $at 'ignored.txt' 'ignored'), $(& $at 'STUB.PS1' 'alpha'), $(& $at 'bin.dat' 'ab') ) }"
            $got = & $run $p
            Write-Host ($got.Text.TrimEnd() -replace '(?m)^', '    ')
            $untouched = (Get-Content -LiteralPath (Join-Path $temp 'outside.txt') -Raw).Trim() -eq 'outside one' -and
                (Get-Content -LiteralPath (Join-Path $repo 'ignored.txt') -Raw).Trim() -eq 'ignored one' -and
                "$([IO.File]::ReadAllBytes((Join-Path $repo 'bin.dat')))" -eq '97 98 0 99 10'
            $got.Code -eq 0 -and $got.Text -match '(?m)^revert-run: R -- refused: Find is empty' -and
                @([regex]::Matches($got.Text, '(?m)^revert-run: R -- refused: \S+ is not a file git tracks in the copy under that name')).Count -eq 3 -and
                $got.Text -match '(?m)^revert-run: R -- refused: git reads bin\.dat as binary' -and $untouched -and (& $same) } }
        @{ Name = 'an edit changing two lines is refused with Lines unset, and runs with Lines = 2'; Test = {
            $two = { param($more) & $one "`$b = ''beta''`n`$c = ''gamma''" "`$b = ''x''`n`$c = ''y''" $more }
            $refused = & $run (& $list 'two' "@{ Reverts = @( $(& $two '') ) }")
            $allowed = & $run (& $list 'two-allowed' "@{ Reverts = @( $(& $two '; Lines = 2') ) }")
            Write-Host ($refused.Text.TrimEnd() -replace '(?m)^', '    ')
            $refused.Code -eq 0 -and $refused.Text -match '(?m)^revert-run: R -- refused: the edit changes 2 added and 2 removed lines, more than Lines = 1' -and
                $allowed.Code -eq 0 -and $allowed.Text -match '(?m)^revert-run: R -- passes \(exit 0\)' -and (& $same) } }
        @{ Name = 'a self-test that fails is reported fails, with its summary line'; Test = {
            $got = & $run (& $list 'fails' "@{ Reverts = @( $(& $one "`$a = ''alpha''" "`$a = ''other''") ) }")
            Write-Host ($got.Text.TrimEnd() -replace '(?m)^', '    ')
            $got.Code -eq 0 -and $got.Text -match '(?m)^revert-run: R -- fails \(exit 1\): FAILED - self-test: 1 of 1 case\(s\) did not hold\.' -and
                $got.Text -match '(?m)^\| R \| fails \| 1 \| FAILED - self-test: 1 of 1' -and $got.Text -match 'stub\.ps1 \| 2 \+-' -and (& $same) } }
        @{ Name = 'a self-test that passes is reported passes, run from the copy''s root'; Test = {
            $got = & $run (& $list 'passes' "@{ Reverts = @( $(& $one "`$b = ''beta''" "`$b = ''other''" "; Args = @('-Mode', 'root')") ) }")
            Write-Host ($got.Text.TrimEnd() -replace '(?m)^', '    ')
            $got.Code -eq 0 -and $got.Text -match '(?m)^revert-run: R -- passes \(exit 0\): OK - self-test passed' -and (& $same) } }
        @{ Name = 'a self-test that throws before its summary line is reported crashed, whatever its exit code'; Test = {
            $got = & $run (& $list 'crashed' "@{ Reverts = @( $(& $one "`$b = ''beta''" "`$b = ''other''" "; Args = @('-Mode', 'throw')") ) }")
            Write-Host ($got.Text.TrimEnd() -replace '(?m)^', '    ')
            $judged = @((Get-RevertResult -ExitCode 0 -Said 'no summary').Result, (Get-RevertResult -ExitCode 1 -Said 'OK - self-test passed: all 1 cases.').Result,
                (Get-RevertResult -ExitCode 0 -Said 'FAILED - self-test: 1 of 1').Result)
            # The last summary line is judged: one that runs another's self-test prints two.
            $last = Get-RevertResult -ExitCode 1 -Said "OK - self-test passed: all 2 cases.`nFAILED - self-test: 1 of 3 case(s) did not hold."
            $got.Code -eq 0 -and $got.Text -match '(?m)^revert-run: R -- crashed \(exit 1\): \r?$' -and "$judged" -eq 'crashed crashed crashed' -and
                $last.Result -eq 'fails' -and $last.Summary -eq 'FAILED - self-test: 1 of 3 case(s) did not hold.' -and (& $same) } }
        @{ Name = 'the file is restored after each revert, and a copy left dirty by one is caught before the next'; Test = {
            $both = "@{ Reverts = @( $(& $one "`$b = ''beta''" "`$b = ''other''" "; Args = @('-Mode', 'dirty')"), $(& $one "`$a = ''alpha''" "`$a = ''other''") ) }"
            $got = & $run (& $list 'dirty' $both)
            Write-Host ($got.Text.TrimEnd() -replace '(?m)^', '    ')
            $restored = [IO.File]::ReadAllText($stubPath) -ceq "$stub`n"
            Remove-Item -LiteralPath (Join-Path $repo 'left.txt') -ErrorAction SilentlyContinue
            $got.Code -eq 1 -and $got.Text -match 'after R the copy is left dirty, so no later revert was run: left\.txt' -and
                @([regex]::Matches($got.Text, '(?m)^revert-run: R -- ')).Count -eq 1 -and $restored -and (& $same) } }
        @{ Name = 'a copy with uncommitted changes at the start is refused, exit 1, and no revert is run'; Test = {
            [IO.File]::AppendAllText($stubPath, "# edited`n")
            try { $got = & $run (& $list 'start' "@{ Reverts = @( $(& $one "`$b = ''beta''" "`$b = ''other''") ) }") }
            finally { & $git checkout -q -- stub.ps1 }
            Write-Host ($got.Text.TrimEnd() -replace '(?m)^', '    ')
            $got.Code -eq 1 -and $got.Text -match 'has uncommitted changes, so no revert was run: stub\.ps1' -and $got.Text -notmatch '(?m)^revert-run: R -- ' -and (& $same) } }
        @{ Name = 'a Find with a line break matches a CRLF file, and one from a CRLF list an LF file, a file with a byte-order mark keeps it, and a list it cannot read, or one with no Reverts or a field missing, fails'; Test = {
            $crlf = Join-Path $temp 'crlf'
            New-Item -ItemType Directory -Path $crlf | Out-Null
            git -C $crlf init --quiet; git -C $crlf config core.autocrlf false
            [IO.File]::WriteAllText((Join-Path $crlf 'stub.ps1'), ($stub -replace "`n", "`r`n") + "`r`n")
            # With a byte-order mark: an edit that dropped it would change line 1 too.
            [IO.File]::WriteAllText((Join-Path $crlf 'bom.ps1'), "$stub`n", [Text.UTF8Encoding]::new($true))
            git -C $crlf add stub.ps1 bom.ps1; git -C $crlf -c user.name=s -c user.email=s@example.invalid -c commit.gpgsign=false commit --quiet -m stub
            $bom = "@{ Name = 'B'; File = 'bom.ps1'; Find = '`$c = ''gamma'''; Replace = '`$c = ''other'''; SelfTest = 'bom.ps1' }"
            $p = & $list 'crlf' "@{ Reverts = @( $(& $one "`$a = ''alpha''`n`$b = ''beta''" "`$a = ''other''`n`$b = ''beta''"), $bom ) }"
            $matched = & pwsh -NoProfile -File $PSCommandPath -Copy $crlf -List $p 2>&1 | Out-String
            Write-Host ($matched.TrimEnd() -replace '(?m)^', '    ')
            # A list saved with CRLF, its Find spanning two lines of the LF stub.
            $crlfList = & $list 'crlf-list' "@{ Reverts = @( $(& $one "`$a = ''alpha''`n`$b = ''beta''" "`$a = ''other''`n`$b = ''beta''") ) }"
            [IO.File]::WriteAllText($crlfList, ([IO.File]::ReadAllText($crlfList) -replace '\r?\n', "`r`n"))
            $fromCrlf = & $run $crlfList
            $broken = & $run (& $list 'broken' '@{ Reverts = ')
            $empty = & $run (& $list 'empty' '@{ Other = 1 }')
            $field = & $run (& $list 'field' "@{ Reverts = @( @{ Name = 'R'; File = 'stub.ps1' } ) }")
            $matched -match '(?m)^revert-run: R -- fails \(exit 1\)' -and $matched -match '(?m)^revert-run: B -- passes \(exit 0\)' -and
                $fromCrlf.Text -match '(?m)^revert-run: R -- fails \(exit 1\)' -and (& $same) -and
                $broken.Code -eq 1 -and $broken.Text -match 'cannot be read' -and $empty.Code -eq 1 -and $empty.Text -match 'holds no Reverts' -and
                $field.Code -eq 1 -and $field.Text -match 'lacks Find, Replace, SelfTest' } }
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

try { $rows = @(Invoke-RevertRun -Root (Resolve-Path -LiteralPath $Copy).Path -ListPath $List -Defaults $Defaults -Conditions $Conditions -Since $Base) }
catch { Write-Host "FAILED - revert-run: $($_.Exception.Message)"; exit 1 }
$counts = ($rows | ForEach-Object { $_.Result } | Group-Object | Sort-Object Name | ForEach-Object { "$($_.Count) $($_.Name)" }) -join ', '
Write-Host "OK - revert-run: $($rows.Count) revert(s) run or refused: $counts."
exit 0
