<#
.SYNOPSIS
    Runs a list of reverts, and with -Defaults and -Conditions the reverts it writes, on a copy of
    the repository, one at a time, and reports each as failing, passing, crashed or timed out its
    self-test, or as refused. Exit 0 means every revert was run or refused; it says nothing of what
    they found, which the report does.

.DESCRIPTION
    WHY (grado-factorio-tools#284). A review's bug scan, and the session answering it, revert each
    claim of a script on a copy and run its -SelfTest, as docs/agents/review-brief.md's *The
    reverts* asks. Each wrote its own driver, and in one session (2026-10-27/28) three misread their
    runs: a sed revert that deleted the case along with the check, a self-test that threw before its
    summary line read as passing, and a slow self-test run by hand per revert.

    THE COPY is a git working tree the caller made, a clone at the commit under review. It is
    refused, exit 1 and nothing run, when it has uncommitted changes or untracked files, which are
    named.

    THE LIST is a PowerShell data file:

        @{ Reverts = @(
            @{ Name = 'F1'; File = 'scripts/x.ps1'; Find = 'if ($a) {'; Replace = 'if ($true) {'
               SelfTest = 'scripts/x.ps1'; Args = @('-NoGame'); Lines = 1 }
        ) }

    THE DEFAULT REVERTS (grado-factorio-tools#382). In PR #374 a self-test passed four times
    whatever a parameter's default was, because its runner carried a default of its own, and each
    was found only by a reviewer who thought to revert that default by hand. With -Defaults, for
    each script it names, a path from the copy's root, the run writes the reverts itself, after the
    list's, from the script's param() block as the parser reads it. A default revert is, for a list
    default, one per element, that element dropped from it: `$Path = @('a', 'b')` gives
    `$Path = @('b')` and `$Path = @('a')`, and a lone element dropped gives `@()`. A default is a
    list where it is written as one, `@()` of constants comma-separated or one to a line, or a
    parenthesised comma list of them, or where the parameter's type is a list, an array as
    [string[]] or [array] (#394), and its default one constant, in parentheses or not. Parentheses
    round a list, a hashtable or $null are read through, so (@('a')) and (('a', 'b')) are lists and
    ($null) is $null. A constant is a number or a string with nothing expanded in it. For a scalar
    default it is one revert, another value put in its place: a string gets -reverted after it, a
    number 1 added, $true or $false the other. Each is named `default -<Name> ...`, edits the text
    from the parameter's variable to the end of its default, its Find running from the script's
    param( so that a self-test's runner that repeats the default does not make it occur twice (as
    two did in the first run for #382's pull request), and runs the script's own -SelfTest with no
    Args, as a list's revert is run and in the same table. The run prints how many it wrote for each
    script, and a line for each default it wrote none for: one computed at run time, as
    `(Get-Date)`, `"$x"` or a list holding either, on any parameter; $null, on any parameter; an
    empty list; and a shape it does not read, with its text: a hashtable, in parentheses or not, or
    one written-out value in parentheses, a constant, $true or $false, on a parameter whose type is
    not a list (#391, #394). A script it writes no revert for, or that does not parse, fails the
    run, exit 1 and nothing run, as a step that read nothing.

    THE CONDITION REVERTS (grado-factorio-tools#400). On PR #395 the panel found 14 guards whose
    reverts passed the self-test after two hand-written lists of 40 and 101; 12 were of three shapes
    a parser can find. With -Conditions, for each script it names, a path from the copy's root, the
    run writes, after the default reverts, one revert per operand of an -and or -or chain, that
    operand dropped with the operator beside it, and one per element of a comma list on the right of
    -in or -notin, or of a comma list of type literals elsewhere, that element dropped with its
    comma. A chain is read whole: in `$a -and $b -and $c` each of the three is dropped once, and a
    chain inside an operand, in parentheses or of the other operator, is a chain of its own. Each
    Find is the whole lines the chain or list spans, and Lines is their count; each is named
    `condition <file>:<line> <operator> drops <text>`, or `type list` for the operator, with (1 of
    2), (2 of 2) after it where two would share a name, in their order there, and runs the script's
    own -SelfTest with no Args. A shape whose Find occurs other than once, or a list of one element,
    is named with its line, and no revert written for it. A self-test's verdict gets none either
    (#407): dropping an operand of a conjunction that holds leaves it holding, so no self-test can
    fail that revert. Inside the clause of an if whose condition is $SelfTest, or a function named
    Invoke-SelfTest, an -and chain is a verdict where it is the last statement of a script block
    that is a hashtable's value under a string key, as `Test = { }` or
    `'<what the case holds>' = { }` (#411); the whole of a parenthesised argument to a command
    invoked with & on a variable, as `& $check '<name>' (<chain>) $said` (#411); or the value
    assigned to a variable its script block reads only as an if's condition or the operand of -not
    or !. Each is named, `revert-run: <file>, skipped as a verdict: line <n>, <k> operand(s)`. An
    -or verdict, a chain inside a verdict's operand, one not its block's last statement, one under a
    key that is not a string, as `$key`, one passed to a command named otherwise, as `& 'name'` or
    `Check`, or invoked other than with &, as `. $check`, and any other chain keep their reverts.
    With -Base <ref>, only an operand or element on a line `git -C <copy> diff -U0 <ref>` adds or
    changes is dropped. As with -Defaults, a script it writes no revert for, -Base or not, or that
    does not parse, fails the run, exit 1 and nothing run.

    File and SelfTest are paths from the copy's root. Args is optional, handed to the self-test
    after -SelfTest. Lines is optional, 1 unless given. Find and Replace are exact text, matched
    with case; a line break in either, LF or CRLF, is read as the file's own.

    EACH REVERT, IN ORDER. Refused, and not run, where Find is empty; where File is not a file git
    tracks in the copy under that very name, of those `git -C <copy> ls-files` gives once for the
    run, as one outside the copy, an untracked one, or one named in another case, which git's status
    could not check restored; where Find occurs in File other than exactly once, naming the count;
    where git reads File as binary; or where the edit changes no line or more than Lines, removed or
    added, by `git -C <copy> diff --numstat --stat -- <File>`. A refused revert leaves the file as
    it was. Otherwise that call's stat, of File alone, is printed and the self-test is run, as
    `pwsh -NoProfile -File <SelfTest> -SelfTest <Args>`, from the copy's root, for at most
    -TimeoutSeconds, 600 unless given (grado-factorio-tools#424). Its result is: *fails*, it exited
    other than 0 and its last summary line is `FAILED - self-test...`; *passes*, it exited 0 and
    that line is `OK - self-test...`, which code-review.md makes a finding; *crashed*, anything
    else, as no summary line, whatever the exit code, a summary line its exit code contradicts, or
    output still held open 5 s after it exited, by a process it left running, whose output is then
    not waited for; *timed out*, still running at the limit, when it is killed with its child
    processes and the seconds it ran are its summary, with no exit code. A self-test that loops
    under the revert and one merely slower than the limit look the same, so a timeout is a lead to
    check, as a crash is, not a verdict. The file is then restored by writing back the bytes read
    before the edit, as it stood, where git might write it with other line ends
    (grado-factorio-tools#422), and the copy checked clean again: one left dirty stops the run, exit
    1, naming what is left and reporting the reverts run so far.

    THE REPORT is a line giving the time limit before the first revert runs, a line per revert as it
    runs, and at the end a Markdown table of name, result, exit code and summary line, for a review
    comment.

    WHAT IT CANNOT SEE. Whether a revert is the right one: a Find that matches once but in the wrong
    place is run. Whether a self-test that timed out loops under the revert or is only slower than
    -TimeoutSeconds, which it reports alike. A process a self-test left running, which is not ended:
    one that holds the output open makes the revert crashed, and one that does not is not seen. A
    self-test whose summary line is worded other than this repository's `OK - self-test` and
    `FAILED - self-test`, which reads as crashed; check.ps1 fails such a self-test among those it
    runs (grado-factorio-tools#297), not one that needs the game, nor one in a sibling. A revert
    across two files, or by a pattern. A self-test that changes a tracked file and puts it back. Of
    -Defaults: a default computed at run time, which it names and writes no revert for; a hashtable,
    in parentheses or not, and one constant, $true or $false in parentheses on a parameter whose
    type is not a list, shapes it does not read, which it names with their text and writes no revert
    for; a list type other than an array and [array], as a generic list, whose default, if one
    constant not in parentheses, is read as a scalar's; a parameter with no param() default, as one
    the script's body sets when it is not given, which it does not name; a function's parameters;
    which of a scalar's other values matter, as it tries one; and a default revert whose self-test
    needs Args, as -NoGame. Of -Conditions: a regex alternation, as `a|b`; how many times a loop
    runs; a condition built in more than one statement, as `$x = $a; if ($x -and $b)`, whose $a it
    does not drop; a list on the right of -in in parentheses or @(), or held in a variable; -cin and
    -cnotin, which match with case, though a list of type literals on their right is read as a type
    list; -contains, -xor, -not and the comparison operators; a type list that holds anything but
    type literals; a condition revert whose self-test needs Args; a verdict of another shape, as an
    -and chain a function a case calls returns, one under a key built at run time, as `"$name"`, one
    passed in $( ) or piped inside its parentheses, or a variable read once as a value, which keeps
    its reverts and passes; a skipped chain that is not a verdict, as one in a block under a string
    key that a case runs for its effect, or one passed to & $<variable> that the command reads other
    than as its verdict, whose reverts might have failed; a self-test that is neither an if
    ($SelfTest) clause nor Invoke-SelfTest, in which nothing is skipped; a verdict variable read
    outside the script block it is assigned in, as by a function through dynamic scope or after the
    pipeline whose ForEach-Object block assigned it, a read it does not see, so the chain may be
    skipped though such a read takes its value; a variable read only as a truth value but meant to
    be false, as `if ($stale) { $failures++ }`, whose skipped reverts would have failed (PR #408's
    review panel); and with -Base, a condition the diff deletes, which leaves nothing to drop, or
    one it changes by a line outside the operand, as the `if (` above it.

.PARAMETER Copy
    The git working tree to revert in.

.PARAMETER List
    The .psd1 file of reverts. None unless given; -List, -Defaults, -Conditions or more than one
    must be.

.PARAMETER Defaults
    The scripts, as paths from the copy's root, whose default reverts are written and run after the
    list's. None unless given.

.PARAMETER Conditions
    The scripts, as paths from the copy's root, whose condition reverts are written and run after
    the default reverts. None unless given.

.PARAMETER Base
    A ref of the copy: -Conditions then writes reverts only on the lines `git diff <ref>` changes.
    Only with -Conditions.

.PARAMETER TimeoutSeconds
    How long each revert's self-test may run before it is killed and reported timed out, in seconds,
    from 1 to 2147483. 600 unless given.

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
    # At most int's milliseconds, which WaitForExit takes.
    [Parameter(ParameterSetName = 'Run')] [ValidateRange(1, 2147483)] [int] $TimeoutSeconds = 600,
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
    # A value written out, not computed: a string with nothing expanded in it, or a number. The
    # parser makes the first a StringConstantExpressionAst, the one type derived from
    # ConstantExpressionAst, whatever its quotes, and an ExpandableStringExpressionAst only of a
    # string with something expanded in it; a ConstantExpressionAst of its own it makes only of a
    # number, or of an attribute's named argument given no value, which is no default (#415,
    # PowerShell 7.6.9's parser).
    $isConstant = { param($e) $e -is [System.Management.Automation.Language.ConstantExpressionAst] }
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
        # A parenthesised default has one statement, which gives its expression, the elements of a
        # comma list, at least one, or none and is computed: so one not computed, of fewer than
        # two elements, has one (#416).
        if ($single -and -not $computed -and ((& $isConstant $elements[0]) -or (& $isBool $elements[0]))) {
            $unwritten.Add("-${name}: its default is a value in parentheses, $shown, a shape -Defaults does not read"); continue
        }
        if ($null -ne $elements) {
            if ($computed -or @($elements | Where-Object { -not ((& $isConstant $_) -or (& $isBool $_)) })) {
                $unwritten.Add("-${name}: its default is computed at run time"); continue
            }
            if (-not $elements) { $unwritten.Add("-${name}: its default is an empty list, with no element to drop"); continue }
            for ($i = 0; $i -lt $elements.Count; $i++) {
                $rest = @(for ($j = 0; $j -lt $elements.Count; $j++) { if ($j -ne $i) { $elements[$j].Extent.Text } })
                & $revert "drops $($elements[$i].Extent.Text)" "@($($rest -join ', '))"
            }
            continue
        }
        $was = $default.Extent.Text
        # A string, then any other constant, a number, as $isConstant reads them (#417).
        if ($default -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
            $other = "'$("$($default.Value)-reverted" -replace "'", "''")'"
            & $revert "$was -> $other" $other
        }
        elseif ($default -is [System.Management.Automation.Language.ConstantExpressionAst]) {
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

# The shapes in the order their reverts are written (#400): by where each starts, and of two that
# start together, as a chain inside one of the other operator or a type list at a chain's start,
# the outer, which ends later, first. Sort-Object without -Stable keeps tied items in their order
# only while there are few of them, so the second key is what holds it.
function Get-ShapeOrder {
    param([object[]] $Shapes)
    @($Shapes | Sort-Object { $_.Node.Extent.StartOffset }, { -$_.Node.Extent.EndOffset })
}

# The condition reverts of the script at $Script, a path from $Root (#400): one per operand of an
# -and or -or chain, that operand dropped with its operator, and one per element of a comma list
# on the right of -in or -notin, or of a comma list of type literals, that element dropped with
# its comma. Each Find is the whole lines the chain or list spans. With $Since, only an operand or
# element on a line `git diff $Since` changes. Unwritten names each shape whose Find occurs other
# than once, and each list of one element.
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
    $skipped = [System.Collections.Generic.List[string]]::new()
    foreach ($s in @(Get-ShapeOrder -Shapes @($shapes))) {
        $parts = $s.Parts
        $drops = @(for ($i = 0; $i -lt $parts.Count; $i++) {
                $lines = $parts[$i].Extent.StartLineNumber..$parts[$i].Extent.EndLineNumber
                if ($null -eq $changed -or @($lines | Where-Object { $changed.Contains($_) })) { $i }
            })
        # By its count: a lone index 0 reads false.
        if (-not $drops.Count) { continue }
        $line = $s.Node.Extent.StartLineNumber
        # A self-test's verdict holds with any of its operands dropped, so no self-test can fail
        # such a revert (#407).
        if ($s.Node -is [System.Management.Automation.Language.BinaryExpressionAst] -and $s.Node.Operator -eq 'And' -and
            (Test-SelfTestRegion -Node $s.Node) -and (Test-Verdict -Chain $s.Node)) {
            $skipped.Add("line $line, $($parts.Count) operand(s)"); continue
        }
        # A list of one element, as ,'a', has nothing left once that is dropped.
        if ($parts.Count -lt 2) { $unwritten.Add("line $line, a $($s.Op) of one element"); continue }
        # The whole lines the shape spans, so that the Find is more likely to occur once. \z, as $
        # also matches before a last line break, which a shape at a line's start follows.
        $start = $s.Node.Extent.StartOffset - $origin; $end = $s.Node.Extent.EndOffset - $origin
        $from = $start - [regex]::Match($text.Substring(0, $start), '[^\r\n]*\z').Length
        $to = $end + [regex]::Match($text.Substring($end), '^[^\r\n]*').Length
        $find = $text.Substring($from, $to - $from)
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
    # Two reverts that drop the same text on one line are told apart by their order there.
    foreach ($g in @($reverts | Group-Object -CaseSensitive { $_.Name } | Where-Object Count -gt 1)) {
        $n = 0
        foreach ($r in $g.Group) { $n++; $r.Name += " ($n of $($g.Count))" }
    }
    @{ Reverts = @($reverts); Unwritten = @($unwritten); Skipped = @($skipped) }
}

# Whether $Node is inside a script's self-test (#407): the clause of an if whose condition is
# $SelfTest, or a function named Invoke-SelfTest.
function Test-SelfTestRegion {
    param([Parameter(Mandatory)] [System.Management.Automation.Language.Ast] $Node)
    for ($p = $Node.Parent; $p; $p = $p.Parent) {
        if ($p -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $p.Name -eq 'Invoke-SelfTest') { return $true }
        # A clause's block is the Item2 its parent if names; no other node is.
        if ($p.Parent -is [System.Management.Automation.Language.IfStatementAst]) {
            foreach ($clause in $p.Parent.Clauses) {
                if ([object]::ReferenceEquals($clause.Item2, $p) -and $clause.Item1.Extent.Text -eq '$SelfTest') { return $true }
            }
        }
    }
    $false
}

# The statement $Expression is the whole of, as `$a -and $b` on a line of its own, or nothing.
function Get-ExpressionStatement {
    param([System.Management.Automation.Language.Ast] $Expression)
    $command = $Expression.Parent
    if ($command -isnot [System.Management.Automation.Language.CommandExpressionAst]) { return }
    $pipe = $command.Parent
    if ($pipe -is [System.Management.Automation.Language.PipelineAst] -and @($pipe.PipelineElements).Count -eq 1) { $pipe }
}

# Whether the -and chain $Chain is a self-test's verdict (#407, #411): the last statement of a
# script block that is a hashtable's value under a string key, as `Test = { }` or a case named by
# its key; the whole of a parenthesised argument to a command invoked with & on a variable, as
# `& $check '<name>' (<chain>)`; or the value assigned to a variable that its scope reads only as
# a truth value, an if's condition or the operand of -not or !.
function Test-Verdict {
    param([Parameter(Mandatory)] [System.Management.Automation.Language.Ast] $Chain)
    # An assignment holds its value as an expression statement with no pipeline round it.
    $statement = if ($Chain.Parent.Parent -is [System.Management.Automation.Language.AssignmentStatementAst]) { $Chain.Parent } else { Get-ExpressionStatement $Chain }
    if (-not $statement) { return $false }
    $holder = $statement.Parent
    if ($holder -is [System.Management.Automation.Language.ParenExpressionAst]) {
        $command = $holder.Parent
        return $command -is [System.Management.Automation.Language.CommandAst] -and $command.InvocationOperator -eq 'Ampersand' -and
            $command.CommandElements[0] -is [System.Management.Automation.Language.VariableExpressionAst]
    }
    if ($holder -is [System.Management.Automation.Language.NamedBlockAst] -and [object]::ReferenceEquals(@($holder.Statements)[-1], $statement)) {
        $block = $holder.Parent.Parent
        $value = if ($block -is [System.Management.Automation.Language.ScriptBlockExpressionAst]) { Get-ExpressionStatement $block }
        # None where the block is assigned, as `$t = { ... }`, not a statement of its own.
        if ($value -and $value.Parent -is [System.Management.Automation.Language.HashtableAst]) {
            foreach ($pair in $value.Parent.KeyValuePairs) {
                if ([object]::ReferenceEquals($pair.Item2, $value) -and $pair.Item1 -is [System.Management.Automation.Language.StringConstantExpressionAst]) { return $true }
            }
        }
        return $false
    }
    # The chain is the assignment's Right, as its Left is never an -and chain.
    if ($holder -isnot [System.Management.Automation.Language.AssignmentStatementAst] -or $holder.Operator -ne 'Equals' -or
        $holder.Left -isnot [System.Management.Automation.Language.VariableExpressionAst]) { return $false }
    $name = $holder.Left.VariablePath.UserPath
    $scope = $holder.Parent
    while ($scope -isnot [System.Management.Automation.Language.ScriptBlockAst]) { $scope = $scope.Parent }
    # A variable whose parent is an assignment is its Left, as a Right is a statement: a write.
    $reads = @($scope.FindAll({ param($n)
                $n -is [System.Management.Automation.Language.VariableExpressionAst] -and $n.VariablePath.UserPath -eq $name -and
                $n.Parent -isnot [System.Management.Automation.Language.AssignmentStatementAst] }, $true))
    if (-not $reads) { return $false }
    foreach ($r in $reads) {
        $negated = $r.Parent -is [System.Management.Automation.Language.UnaryExpressionAst] -and $r.Parent.TokenKind -in 'Not', 'Exclaim'
        # A pipeline whose parent is an if is one of its conditions; its bodies are blocks.
        $condition = Get-ExpressionStatement $r
        $tested = $condition -and $condition.Parent -is [System.Management.Automation.Language.IfStatementAst]
        if (-not ($negated -or $tested)) { return $false }
    }
    $true
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

# A revert's self-test, `pwsh -NoProfile -File <SelfTest> -SelfTest <Arguments>` from $Root,
# killed with its child processes once it has run $TimeoutSeconds (#424): its exit code, its
# output, stdout then stderr, whether it timed out, whether a pipe was still held open
# $HELD_SECONDS after it ended, which leaves that pipe's output out, and the seconds it ran.
$HELD_SECONDS = 5
function Invoke-BoundedSelfTest {
    param([Parameter(Mandatory)] [string] $Root, [Parameter(Mandatory)] [string] $SelfTest, [object[]] $Arguments = @(),
        [Parameter(Mandatory)] [int] $TimeoutSeconds)
    # The pwsh `& pwsh` would run, by the command lookup's PATH.
    $start = [Diagnostics.ProcessStartInfo]::new((Get-Command pwsh -CommandType Application | Select-Object -First 1).Source)
    foreach ($a in '-NoProfile', '-File', $SelfTest, '-SelfTest') { $start.ArgumentList.Add($a) }
    # Not @($Arguments): of $null, as an if that yields @() assigns, that is one element, handed
    # on as an empty string the self-test binds to its first positional parameter.
    foreach ($a in $Arguments) { $start.ArgumentList.Add([string] $a) }
    $start.WorkingDirectory = $Root
    $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true; $start.UseShellExecute = $false
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $process = [Diagnostics.Process]::Start($start)
    # Both read as they come, so that neither pipe fills and stalls the self-test.
    $out = $process.StandardOutput.ReadToEndAsync(); $err = $process.StandardError.ReadToEndAsync()
    $inTime = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $inTime) { $process.Kill($true); $process.WaitForExit() }
    $clock.Stop()
    # A process the self-test started and left running holds its pipes open after it ends, and a
    # read to their end would wait as long: past a few seconds, a pipe still open is not waited for.
    $closed = [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]] @($out, $err), $HELD_SECONDS * 1000)
    @{ Code = $(if ($inTime) { $process.ExitCode } else { $null }); Said = (@($out, $err) | Where-Object IsCompleted | ForEach-Object Result) -join ''
        TimedOut = -not $inTime; Held = -not $closed; Seconds = $clock.Elapsed.TotalSeconds.ToString('0.0', [cultureinfo]::InvariantCulture) }
}

# One revert applied, run and restored; returns its row. Throws when the copy is left dirty.
function Invoke-Revert {
    param([Parameter(Mandatory)] [string] $Root, [Parameter(Mandatory)] [hashtable] $Revert, [Parameter(Mandatory)] [int] $TimeoutSeconds,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.Generic.HashSet[string]] $Tracked)
    $row = @{ Name = $Revert.Name; Result = 'refused'; Exit = ''; Summary = '' }
    $lines = if ($Revert.ContainsKey('Lines')) { [int] $Revert.Lines } else { 1 }
    $find = [string] $Revert.Find; $replace = [string] $Revert.Replace
    # An empty Find occurs everywhere, and counting it would never end.
    if (-not $find) { $row.Summary = 'Find is empty'; return $row }
    # Only a file git tracks under this very name, of the names `git ls-files` gave the run, can be
    # checked clean by git after its restore: not one outside the copy, an untracked one, or one
    # named in another case, which Windows would let be written (#422).
    $file = $Revert.File -replace '\\', '/'
    if (-not $Tracked.Contains($file)) { $row.Summary = "$($Revert.File) is not a file git tracks in the copy under that name"; return $row }
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
        # One call prints both, the numstat line first, then the stat's (#422). The stat is of the
        # file alone, which on a copy checked clean before each revert is the whole copy's.
        $diff = @(git -C $Root diff --numstat --stat -- $file)
        if ($LASTEXITCODE) { throw "git diff --numstat --stat -- $file failed in $Root." }
        $numstat = if ($diff) { "$($diff[0])".Trim() } else { '' }
        $counts = if ($numstat) { @($numstat -split '\s+')[0..1] } else { '0', '0' }
        # git counts no lines of a file it reads as binary, and prints - for each.
        if ($counts -contains '-') { $row.Summary = "git reads $file as binary, so its changed lines cannot be counted"; return $row }
        $added, $removed = $counts | ForEach-Object { [int] $_ }
        if (-not ($added -or $removed)) { $row.Summary = 'the edit changes no line'; return $row }
        if ($added -gt $lines -or $removed -gt $lines) { $row.Summary = "the edit changes $added added and $removed removed lines, more than Lines = $lines"; return $row }
        Write-Host "revert-run: $($Revert.Name), git -C <copy> diff --stat -- ${file}:"
        $diff | Select-Object -Skip 1 | ForEach-Object { Write-Host "    $_" }
        $extra = if ($Revert.ContainsKey('Args')) { @($Revert.Args) } else { @() }
        $ran = Invoke-BoundedSelfTest -Root $Root -SelfTest (Join-Path $Root $Revert.SelfTest) -Arguments $extra -TimeoutSeconds $TimeoutSeconds
        if ($ran.TimedOut) { $row.Result = 'timed out'; $row.Summary = "killed after $($ran.Seconds) s, at the limit of $TimeoutSeconds s" }
        elseif ($ran.Held) {
            $row.Result = 'crashed'; $row.Exit = "$($ran.Code)"
            $row.Summary = "its output was still held open $HELD_SECONDS s after it exited, by a process it left running"
        }
        else {
            $judged = Get-RevertResult -ExitCode $ran.Code -Said $ran.Said
            $row.Result = $judged.Result; $row.Exit = "$($ran.Code)"; $row.Summary = $judged.Summary
        }
        $row
    }
    # The bytes read before the edit, written back (#422): on a copy checked clean they are the file
    # as it stood, and the status the run reads after each revert catches one git holds otherwise.
    finally { [IO.File]::WriteAllBytes($path, $bytes) }
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
    param([Parameter(Mandatory)] [string] $Root, [string] $ListPath = '', [string[]] $Defaults = @(), [string[]] $Conditions = @(), [string] $Since = '',
        [Parameter(Mandatory)] [int] $TimeoutSeconds)
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
        foreach ($v in $written.Skipped) { Write-Host "revert-run: $script, skipped as a verdict: $v" }
        # As for -Defaults, a script named that yields no revert read nothing.
        if (-not $written.Reverts) { throw "-Conditions names $script, for which no condition revert could be written$(if ($Since) { " on lines changed since $Since" }), so no revert was run." }
        foreach ($r in $written.Reverts) { $all.Add($r) }
    }
    # The names git tracks, read once for every revert (#422), matched with case as git gives them.
    $tracked = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $names = @(git -C $Root ls-files)
    if ($LASTEXITCODE) { throw "git ls-files failed in $Root." }
    foreach ($t in $names) { [void] $tracked.Add($t) }
    Write-Host "revert-run: each self-test run is limited to $TimeoutSeconds s, by -TimeoutSeconds."
    $rows = [System.Collections.Generic.List[object]]::new()
    try {
        foreach ($r in $all) {
            $row = Invoke-Revert -Root $Root -Revert $r -TimeoutSeconds $TimeoutSeconds -Tracked $tracked # strict-lists: one
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

# The run as the command line gives it, its summary line printed: returns the exit code, 1 where
# the run throws, else 0. The self-test calls it in its own process (#422).
function Invoke-Main {
    param([Parameter(Mandatory)] [string] $Copy, [string] $List = '', [string[]] $Defaults = @(), [string[]] $Conditions = @(), [string] $Base = '',
        [Parameter(Mandatory)] [int] $TimeoutSeconds)
    try { $rows = @(Invoke-RevertRun -Root (Resolve-Path -LiteralPath $Copy).Path -ListPath $List -Defaults $Defaults -Conditions $Conditions -Since $Base -TimeoutSeconds $TimeoutSeconds) }
    catch { Write-Host "FAILED - revert-run: $($_.Exception.Message)"; return 1 }
    $counts = ($rows | ForEach-Object { $_.Result } | Group-Object | Sort-Object Name | ForEach-Object { "$($_.Count) $($_.Name)" }) -join ', '
    Write-Host "OK - revert-run: $($rows.Count) revert(s) run or refused: $counts."
    0
}

function Invoke-SelfTest {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "revert-run-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    $repo = Join-Path $temp 'copy'
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    $git = { git -C $repo -c user.name=selftest -c user.email=selftest@example.invalid -c commit.gpgsign=false @args; if ($LASTEXITCODE) { throw "git $args failed; the self-test needs git." } }
    # A self-test stub: it fails when $a is reverted, passes whatever else changes, and with -Mode
    # throws before its summary line, leaves a file behind, runs past any time limit a case sets
    # waiting on a child of its own, or passes leaving a child running that holds its output open;
    # each child's process id goes to -PidFile.
    $stub = @(
        'param([switch] $SelfTest, [string] $Mode, [string] $PidFile)'
        "`$a = 'alpha'"
        "`$b = 'beta'"
        "`$c = 'gamma'"
        "if (`$Mode -eq 'throw') { throw 'boom before the summary' }"
        "if (`$Mode -eq 'dirty') { Set-Content -LiteralPath (Join-Path `$PSScriptRoot 'left.txt') -Value x }"
        # -NoNewWindow hands the child this pwsh's pipes, so it holds them as long as it runs.
        "if (`$Mode -in 'sleep', 'linger') { `$s = Start-Process ([Environment]::ProcessPath) -ArgumentList '-NoProfile', '-Command', 'Start-Sleep -Seconds 300' -NoNewWindow -PassThru; Set-Content -LiteralPath `$PidFile -Value `$s.Id }"
        "if (`$Mode -eq 'sleep') { `$s.WaitForExit() }"
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
        '    $PQ = ((@(''q''))), $PF = ($false), $PE = ("$x"), $PS = ($s = 1), [string[]] $PB = ($true),'
        '    [int[]] $Nums = @(1, 2), [bool] $Off = $false, [string] $Interp = "$x", $Var = $x, $PC = (''c'' | Sort-Object))'
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
        # Two elements of one text: their reverts' names differ only by their order.
        "`$dup = `$x -in 'a', 'a'"
        # Two lists of one element, named and not written.
        "`$one = `$x -in ,'b'"
        '$single = ,[string]'
        # A chain inside a chain of the other operator, with no parentheses, is a chain of its own.
        "`$mix = `$k -and `$x -eq 'b' -or `$x -eq 'c'"
        # A chain at a line's start, with more after it on the line.
        "`$x -ne 'z' -and `$k | Out-Null"
        "if (@(`$ok, `$hit, `$no, `$or, `$typed, (`$types -contains `$k), `$two) -notcontains `$false) { Write-Host 'OK - self-test passed: all 1 cases.'; exit 0 }"
        "Write-Host 'FAILED - self-test: 1 of 1 case(s) did not hold.'"
        'exit 1'
    ) -join "`n"
    [IO.File]::WriteAllText((Join-Path $repo 'conditions.ps1'), "$conditions`n")
    # The few reverts each of -Defaults and -Conditions runs through the command line (#409): one
    # that fails, one that passes, and a default and a list it names and writes no revert for.
    $verdict = "{ Write-Host 'OK - self-test passed: all 1 cases.'; exit 0 }`nWrite-Host 'FAILED - self-test: 1 of 1 case(s) did not hold.'`nexit 1"
    [IO.File]::WriteAllText((Join-Path $repo 'few-defaults.ps1'),
        "param([switch] `$SelfTest, [string[]] `$Kinds = @('a', 'b'), `$When = (Get-Date))`nif (`$Kinds -contains 'a') $verdict`n")
    [IO.File]::WriteAllText((Join-Path $repo 'few-conditions.ps1'),
        "param([switch] `$SelfTest)`n`$x = 'b'`n`$one = `$x -in ,'b'`nif (`$x -in 'a', 'b') $verdict`n")
    & $git add stub.ps1 bin.dat .gitignore defaults.ps1 nodefault.ps1 broken.ps1 conditions.ps1 few-defaults.ps1 few-conditions.ps1
    & $git commit --quiet -m stub
    $list = { param([string] $name, [string] $text) $p = Join-Path $temp "$name.psd1"; Set-Content -LiteralPath $p -Value $text; $p }
    $one = { param([string] $Find, [string] $Replace, [string] $More = '') "@{ Name = 'R'; File = 'stub.ps1'; Find = '$Find'; Replace = '$Replace'; SelfTest = 'stub.ps1'$More }" }
    # The run in this process, as the command line makes it, with what it printed and the exit
    # code it would end with (#422). The cases about the command line itself, a list that arrives
    # through pwsh -File as one string, each exit code pwsh ends with, and a run bounded from
    # outside, start a pwsh of their own.
    $main = { param([hashtable] $given)
        $said = [System.Collections.Generic.List[string]]::new(); $code = $null
        foreach ($o in @(Invoke-Main @given -TimeoutSeconds 600 6>&1)) {
            if ($o -is [System.Management.Automation.InformationRecord]) { $said.Add("$o") } else { $code = $o }
        }
        @{ Code = $code; Text = ($said -join "`n") + "`n" } }
    $run = { param([string] $listPath) & $main @{ Copy = $repo; List = $listPath } }
    $same = { [IO.File]::ReadAllText($stubPath) -ceq "$stub`n" -and -not @(Get-DirtyPath -Root $repo) }
    # Each written revert that fails three of Invoke-Revert's refusals, or does not parse, named
    # with why (#409): its Find occurs once in its file, and the edit changes at least one line and
    # no more than Lines, counted as the run counts them, by git's numstat, here in one git process
    # for them all. The run does not refuse an edit that does not parse, but would read it as
    # crashed. The run's other refusals, an empty Find, an untracked File and a binary one, are not
    # checked: no written revert reaches them. None where each fits.
    $fits = { param([hashtable[]] $reverts)
        $dir = Join-Path $temp "fits-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
        New-Item -ItemType Directory -Path (Join-Path $dir 'a'), (Join-Path $dir 'b') | Out-Null
        $edits = @{}
        $misfits = @(for ($i = 0; $i -lt $reverts.Count; $i++) {
                $r = $reverts[$i]
                $text = [IO.File]::ReadAllText((Join-Path $repo $r.File))
                $count = Get-OccurrenceCount -Text $text -Find $r.Find
                if ($count -ne 1) { "$($r.Name): Find occurs $count times"; continue }
                $at = $text.IndexOf($r.Find, [StringComparison]::Ordinal)
                $edited = $text.Substring(0, $at) + $r.Replace + $text.Substring($at + $r.Find.Length)
                $tokens = $null; $errors = $null
                [void] [System.Management.Automation.Language.Parser]::ParseInput($edited, [ref] $tokens, [ref] $errors)
                if ($errors) { "$($r.Name): the edit does not parse"; continue }
                [IO.File]::WriteAllText((Join-Path $dir "a/$i"), $text); [IO.File]::WriteAllText((Join-Path $dir "b/$i"), $edited)
                $edits["$i"] = $r
            })
        $counted = @{}
        # Relative, as git quotes a path with a backslash in it.
        foreach ($line in @(git -C $dir diff --no-index --numstat -- a b)) {
            if ($line -match '^(\d+)\t(\d+)\t.*/(\d+)$') { $counted[$Matches[3]] = @([int] $Matches[1], [int] $Matches[2]) }
        }
        $misfits += @(foreach ($k in $edits.Keys | Sort-Object { [int] $_ }) {
                $c = $counted[$k]; $r = $edits[$k]
                if (-not $c) { "$($r.Name): the edit changes no line" }
                elseif ($c[0] -gt $r.Lines -or $c[1] -gt $r.Lines) { "$($r.Name): the edit changes $($c[0]) added and $($c[1]) removed lines, more than Lines = $($r.Lines)" }
            })
        if ($misfits) { Write-Host "    would not run as written: $($misfits -join '; ')" }
        $misfits }

    # A case passes on one output, $true (#419). Any other output fails it, saying
    # why: [bool] of two values or more is true whatever they are, so a case that
    # leaked a line passed on a false verdict.
    $judgeCase = {
        param([scriptblock] $CaseBlock)
        $caseOutput = @(& $CaseBlock)
        if ($caseOutput.Count -ne 1) { Write-Host "    gave $($caseOutput.Count) values, not one [bool]"; return $false }
        if ($caseOutput[0] -isnot [bool]) { Write-Host "    gave $($null -eq $caseOutput[0] ? '$null' : $caseOutput[0].GetType().Name), not a [bool]"; return $false }
        $caseOutput[0]
    }
    # A case that leaks a value, judged by the loop's own line, which must fail it:
    # so a loop put back to [bool] of the whole output fails the run (#419).
    $leakCase = 'the loop fails a case giving $null and then $false (#419); ok here means it was failed'
    $cases = @(
        @{ Name = $leakCase; Test = { $null; $false } }
        @{ Name = 'a case passes on one $true; two values, a string or none fail it, and say so (#419)'; Test = {
            (& $judgeCase { $true }) -eq $true -and (& $judgeCase { $false }) -eq $false -and
                "$(& $judgeCase { $null; $true } 6>&1)" -ceq '    gave 2 values, not one [bool] False' -and
                "$(& $judgeCase { 'x' } 6>&1)" -ceq '    gave String, not a [bool] False' -and "$(& $judgeCase { } 6>&1)" -ceq '    gave 0 values, not one [bool] False' }}
        @{ Name = '-Defaults writes one revert per element of a list default and one per scalar default, names each default it cannot write, each revert one the run would run, and runs a few through the command line as a list''s are, one failing and one passing (#409), each given 600 s with -TimeoutSeconds left out (#424)'; Test = {
            $written = Get-DefaultRevert -Root $repo -Script 'defaults.ps1'
            # Each Replace is the Find's text up to the variable, then the new default: its tail.
            $said = @($written.Reverts | ForEach-Object { "$($_.Name) => $([regex]::Match($_.Replace, '\$\w+ = (?:(?!\$\w+ = ).)*$').Value)" })
            # And its head, up to the tail's variable, is the Find's own, so no revert changes an
            # earlier default on its way to its own.
            $heads = @($written.Reverts | Where-Object {
                    $tail = [regex]::Match($_.Replace, '\$\w+ = (?:(?!\$\w+ = ).)*$')
                    -not $_.Find.StartsWith($_.Replace.Substring(0, $tail.Index) + [regex]::Match($tail.Value, '^\$\w+ = ').Value, [StringComparison]::Ordinal) })
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
                "default -PQ drops 'q' => `$PQ = @()", 'default -PB drops $true => $PB = @()',
                'default -Nums drops 1 => $Nums = @(2)', 'default -Nums drops 2 => $Nums = @(1)', 'default -Off $false -> $true => $Off = $true')
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
                '-PE: its default is computed at run time', '-PS: its default is computed at run time',
                '-Interp: its default is computed at run time', '-Var: its default is computed at run time', '-PC: its default is computed at run time')
            # The lines each default spans, which its revert may change.
            $spans = @($written.Reverts | ForEach-Object { "$($_.Name.Split(' ')[1])=$($_.Lines)" } | Sort-Object -Unique)
            # The check of the list itself names each revert the run would refuse or could not
            # parse, and passes a deletion and an addition of one line.
            $r = { param($name, $find, $replace, $lines = 1) @{ Name = $name; File = 'stub.ps1'; Find = $find; Replace = $replace; Lines = $lines } }
            $misfit = @(& $fits @(
                    (& $r 'twice' "'alpha'" "'x'"), (& $r 'parse' "`$b = 'beta'" "`$b = ('beta'"), (& $r 'same' "`$b = 'beta'" "`$b = 'beta'"),
                    (& $r 'added' "`$b = 'beta'" "`$b = 1`n`$b2 = 2`n`$b3 = 3"), (& $r 'removed' "`$b = 'beta'`n`$c = 'gamma'" "`$b = 1"),
                    (& $r 'deleted' "`$b = 'beta'`n" ''), (& $r 'appended' "`$b = 'beta'" "`$b = 'beta'`n`$z = 1")))
            $wantMisfit = @('twice: Find occurs 2 times', 'parse: the edit does not parse', 'same: the edit changes no line',
                'added: the edit changes 3 added and 1 removed lines, more than Lines = 1', 'removed: the edit changes 1 added and 2 removed lines, more than Lines = 1')
            # Through the command line, a fixture of two reverts, one failing and one passing.
            $got = & pwsh -NoProfile -File $PSCommandPath -Copy $repo -Defaults 'few-defaults.ps1' 2>&1 | Out-String
            $code = $LASTEXITCODE
            Write-Host ($got.TrimEnd() -replace '(?m)^', '    ')
            $rows = @([regex]::Matches($got, '(?m)^\| (default [^|]+) \| (\w+) \|') | ForEach-Object { "$($_.Groups[1].Value.Trim()): $($_.Groups[2].Value)" })
            $printed = @([regex]::Matches($got, '(?m)^revert-run: few-defaults\.ps1, not written: (.+)\.\r?$') | ForEach-Object { $_.Groups[1].Value })
            ($said -join '|') -ceq ($want -join '|') -and -not $heads -and ($written.Unwritten -join '|') -ceq ($unwritten -join '|') -and
                ($spans -join ' ') -ceq '-Count=1 -Kinds=1 -Loose=1 -Main=1 -Nums=1 -Off=1 -On=1 -One=1 -OneParen=1 -PA=1 -Paren=1 -PB=1 -PL=1 -PQ=1 -PX=1 -PY=1 -Quoted=1 -Single=1 -Stacked=4 -Wrapped=2' -and
                @($written.Reverts | Where-Object { -not $_.Find.StartsWith('param([switch] $SelfTest, ') -or $_.SelfTest -ne 'defaults.ps1' }).Count -eq 0 -and
                (@($written.Reverts | ForEach-Object { $_.File } | Sort-Object -Unique) -join '|') -ceq 'defaults.ps1' -and
                -not (& $fits $written.Reverts) -and ($misfit -join '|') -ceq ($wantMisfit -join '|') -and
                $code -eq 0 -and $got -match '(?m)^revert-run: 2 default revert\(s\) written for few-defaults\.ps1\.' -and
                $got -match '(?m)^revert-run: each self-test run is limited to 600 s, by -TimeoutSeconds\.' -and
                ($printed -join '|') -ceq '-When: its default is computed at run time' -and
                ($rows -join '|') -ceq "default -Kinds drops 'a': fails|default -Kinds drops 'b': passes" -and (& $same) } }
        @{ Name = '-Defaults reads a comma list, and fails, exit 1 and nothing run, a script that yields no revert or does not parse (#389)'; Test = {
            $none = & pwsh -NoProfile -File $PSCommandPath -Copy $repo -Defaults 'defaults.ps1,nodefault.ps1' 2>&1 | Out-String; $noneCode = $LASTEXITCODE
            $b = & $main @{ Copy = $repo; Defaults = @('broken.ps1') }; $broken = $b.Text; $brokenCode = $b.Code
            Write-Host (($none + $broken).TrimEnd() -replace '(?m)^', '    ')
            $noneCode -eq 1 -and $none -match '(?m)^revert-run: 26 default revert\(s\) written for defaults\.ps1\.' -and
                $none -match '-Defaults names nodefault\.ps1, for which no default revert could be written, so no revert was run' -and
                $none -notmatch '(?m)^revert-run: default ' -and
                $brokenCode -eq 1 -and $broken -match 'broken\.ps1 does not parse, so its defaults cannot be read' -and (& $same) } }
        @{ Name = '-Conditions writes one revert per operand of an -and or -or chain and per element of an -in, -notin or type list, with a chain over two lines whose Find and Lines span both and two reverts of one text told apart by their order, a chain at a line''s start or inside one of the other operator, a list of one element named and not written, names a shape whose Find is not unique, each revert one the run would run, and runs a few through the command line as a list''s are, one failing and one passing (#400, #409)'; Test = {
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
                "${c}:14 -or drops `$x -eq 'b' => `$two = `$x -eq 'n'", "${c}:15 -or drops `$x -eq 'n' => `$two = `$x -eq 'b'",
                "${c}:16 -in drops 'a' (1 of 2) => `$dup = `$x -in 'a'", "${c}:16 -in drops 'a' (2 of 2) => `$dup = `$x -in 'a'",
                "${c}:19 -or drops `$k -and `$x -eq 'b' => `$mix = `$x -eq 'c'", "${c}:19 -or drops `$x -eq 'c' => `$mix = `$k -and `$x -eq 'b'",
                "${c}:19 -and drops `$k => `$mix = `$x -eq 'b' -or `$x -eq 'c'", "${c}:19 -and drops `$x -eq 'b' => `$mix = `$k -or `$x -eq 'c'",
                "${c}:20 -and drops `$x -ne 'z' => `$k | Out-Null", "${c}:20 -and drops `$k => `$x -ne 'z' | Out-Null")
            $unwritten = @('line 10, a -or whose Find occurs 2 times', 'line 11, a -or whose Find occurs 2 times', 'line 17, a -in of one element',
                'line 18, a type list of one element')
            # Through the command line, a fixture of two reverts, one failing and one passing.
            $got = & pwsh -NoProfile -File $PSCommandPath -Copy $repo -Conditions 'few-conditions.ps1' 2>&1 | Out-String
            $code = $LASTEXITCODE
            Write-Host ($got.TrimEnd() -replace '(?m)^', '    ')
            $rows = @([regex]::Matches($got, '(?m)^\| (condition [^|]+) \| (\w+) \|') | ForEach-Object { "$($_.Groups[1].Value.Trim()): $($_.Groups[2].Value)" })
            $printed = @([regex]::Matches($got, '(?m)^revert-run: few-conditions\.ps1, not written: (.+)\.\r?$') | ForEach-Object { $_.Groups[1].Value })
            $f = 'condition few-conditions.ps1:4 -in drops'
            ($said -join '|') -ceq ($want -join '|') -and ($written.Unwritten -join '|') -ceq ($unwritten -join '|') -and
                @($written.Reverts | Where-Object { $_.File -ne 'conditions.ps1' -or $_.SelfTest -ne 'conditions.ps1' -or $_.Lines -ne ($_.Name -match ':1[45] ' ? 2 : 1) }).Count -eq 0 -and
                -not (& $fits $written.Reverts) -and
                $code -eq 0 -and $got -match '(?m)^revert-run: 2 condition revert\(s\) written for few-conditions\.ps1\.' -and
                ($printed -join '|') -ceq 'line 3, a -in of one element' -and
                ($rows -join '|') -ceq "$f 'a': passes|$f 'b': fails" -and (& $same) } }
        @{ Name = '-Conditions fails, exit 1 and nothing run, a script that yields no revert, does not parse or is not in the copy (#400)'; Test = {
            $r = & $main @{ Copy = $repo; Conditions = @('nodefault.ps1') }; $none = $r.Text; $noneCode = $r.Code
            $r = & $main @{ Copy = $repo; Conditions = @('conditions.ps1', 'broken.ps1') }; $broken = $r.Text; $brokenCode = $r.Code
            $r = & $main @{ Copy = $repo; Conditions = @('no-such.ps1') }; $missing = $r.Text; $missingCode = $r.Code
            Write-Host (($none + $broken + $missing).TrimEnd() -replace '(?m)^', '    ')
            $noneCode -eq 1 -and $none -match '-Conditions names nodefault\.ps1, for which no condition revert could be written, so no revert was run' -and
                $brokenCode -eq 1 -and $broken -match 'broken\.ps1 does not parse, so its conditions cannot be read' -and
                $broken -match '(?m)^revert-run: 23 condition revert\(s\) written for conditions\.ps1\.' -and $broken -notmatch '(?m)^revert-run: condition ' -and
                $missingCode -eq 1 -and $missing -match '-Conditions names no-such\.ps1, which is not a file in the copy' -and (& $same) } }
        @{ Name = '-Conditions writes no revert of an -and verdict in a self-test, the last statement of a block under a string key, a variable read only as a truth value, or a chain in parentheses passed to & $<variable>, and names each it skips; an -or verdict, a chain inside a verdict''s operand, one read as a value, one not last, one under a key not a string, one passed to a command not invoked with & on a variable, and each outside the self-test keep theirs (#407, #411)'; Test = {
            $verdicts = @(
                'param([switch] $SelfTest)'
                "`$x = 'b'"
                'if ($SelfTest) {'
                "    `$cases = @(@{ Name = 'one'; Test = { `$x -ne 'a' -and `$x -ne 'c' } }"
                "        @{ Name = 'two'; Test = { `$x -eq 'b' -or `$x -eq 'd' } }"
                "        @{ Name = 'three'; Test = { `$x -ne 'e' -and (`$x -ne 'f' -and `$x -ne 'g') } }"
                "        @{ Name = 'four'; Test = { `$x -ne 'h' -and `$x -ne 'i'; 'last' } })"
                "    `$vOk = `$x -ne 'j' -and `$x -ne 'k'"
                "    if (-not `$vOk) { 'no' }"
                "    Write-Host `"`$(if (`$vOk) { 'ok' })`""
                "    `$both = !`$vOk"
                "    `$flag = `$x -ne 'l' -and `$x -ne 'm'"
                '    $flag | Out-Null'
                # Not verdicts, each of a shape one guard of Test-Verdict tells apart: a Test
                # block ending in a pipeline of two, a bare block and an assigned one, a key other
                # than Test or not a string, a += and a member assigned, and variables read under
                # -bnot, copied or written out as a statement of its own.
                "    @{ Test = { `$x -ne 'u1' -and `$x -ne 'u2' | Out-Null } }"
                "    { `$x -ne 'v1' -and `$x -ne 'v2' }"
                "    `$tb = { `$x -ne 't1' -and `$x -ne 't2' }"
                "    @{ Test = { 'x' }; Other = { `$x -ne 'w3' -and `$x -ne 'w4' } }"
                "    @{ `$key = { `$x -ne 'w1' -and `$x -ne 'w2' } }"
                "    `$plus += `$x -ne 'y1' -and `$x -ne 'y2'"
                '    if ($plus) { }'
                "    `$h.Ok = `$x -ne 'z1' -and `$x -ne 'z2'"
                "    `$bOk = `$x -ne 'b1' -and `$x -ne 'b2'"
                '    $bits = -bnot $bOk'
                "    `$cOk = `$x -ne 'c1' -and `$x -ne 'c2'"
                '    $copy = $cOk'
                "    `$dOk = `$x -ne 'd1' -and `$x -ne 'd2'"
                '    $dOk'
                # #411's shapes: a block under a quoted key, and a chain in parentheses passed to a
                # command invoked with & on a variable; then the boundaries that keep their reverts.
                "    @{ 'a case' = { `$x -ne 'k1' -and `$x -ne 'k2' } }"
                "    & `$check 'one' (`$x -ne 'g1' -and `$x -ne 'g2') `$x"
                "    & `$check 'two' (`$x -eq 'g3' -or `$x -eq 'g4')"
                "    & `$check 'three' ((`$x -ne 'g5' -and `$x -ne 'g6') -and `$x -ne 'g7')"
                "    & 'check' 'four' (`$x -ne 'g8' -and `$x -ne 'g9')"
                "    Check 'five' (`$x -ne 'g10' -and `$x -ne 'g11')"
                "    & `$check 'six' (`$x -ne 'g12' -and `$x -ne 'g13' | Out-Null)"
                # Dot-sourced, not invoked with &; and a block under $key beside a string key.
                "    . `$check 'seven' (`$x -ne 'g16' -and `$x -ne 'g17')"
                "    @{ 'name' = 1; `$key = { `$x -ne 'g18' -and `$x -ne 'g19' } }"
                '}'
                'function Invoke-SelfTest {'
                "    @{ Test = { `$x -ne 'n' -and `$x -ne 'o' } }"
                '}'
                # Outside the region: another function, and an elseif beside an if ($SelfTest).
                'function Other {'
                "    @{ Test = { `$x -ne 'o1' -and `$x -ne 'o2' } }"
                '}'
                'if ($SelfTest) { } elseif ($x) {'
                "    @{ Test = { `$x -ne 'e1' -and `$x -ne 'e2' } }"
                '}'
                "`$out = @{ Test = { `$x -ne 'p' -and `$x -ne 'q' } }"
                "`$outOk = `$x -ne 'r' -and `$x -ne 's'"
                'if ($outOk) { }'
                "& `$check 'out' (`$x -ne 'g14' -and `$x -ne 'g15')"
            ) -join "`n"
            $verdictDir = Join-Path $temp 'verdicts'
            New-Item -ItemType Directory -Path $verdictDir -Force | Out-Null
            [IO.File]::WriteAllText((Join-Path $verdictDir 'verdicts.ps1'), "$verdicts`n")
            $written = Get-ConditionRevert -Root $verdictDir -Script 'verdicts.ps1'
            $dropped = @($written.Reverts | ForEach-Object { ($_.Name -split ' ', 3)[2] -replace '^.*drops ' })
            $want = @("`$x -eq 'b'", "`$x -eq 'd'", "`$x -ne 'f'", "`$x -ne 'g'", "`$x -ne 'h'", "`$x -ne 'i'", "`$x -ne 'l'", "`$x -ne 'm'") +
                @('u1', 'u2', 'v1', 'v2', 't1', 't2', 'w1', 'w2', 'y1', 'y2', 'z1', 'z2', 'b1', 'b2', 'c1', 'c2', 'd1', 'd2' | ForEach-Object { "`$x -ne '$_'" }) +
                @("`$x -eq 'g3'", "`$x -eq 'g4'") +
                @('g5', 'g6', 'g8', 'g9', 'g10', 'g11', 'g12', 'g13', 'g16', 'g17', 'g18', 'g19', 'o1', 'o2', 'e1', 'e2', 'p', 'q', 'r', 's', 'g14', 'g15' | ForEach-Object { "`$x -ne '$_'" })
            $skips = (4, 6, 8, 17, 28, 29, 31, 39 | ForEach-Object { "line $_, 2 operand(s)" }) -join '|'
            # In this process, on a script whose only chains are verdicts: each is named,
            # and with no revert left the run fails, having run nothing.
            [IO.File]::WriteAllText((Join-Path $repo 'verdicts.ps1'), (@(
                        "if (`$SelfTest) { `$ok = `$x -ne 'a' -and `$x -ne 'c'; if (`$ok) { }"
                        "    @{ 'one' = { `$x -ne 'a' -and `$x -ne 'c' -and `$x -ne 'd' } }"
                        "    & `$check 'two' (`$x -ne 'a' -and `$x -ne 'e') }") -join "`n") + "`n")
            & $git add verdicts.ps1; & $git commit --quiet -m 'verdicts'
            $r = & $main @{ Copy = $repo; Conditions = @('verdicts.ps1') }; $got = $r.Text; $code = $r.Code
            Write-Host ($got.TrimEnd() -replace '(?m)^', '    ')
            $printed = @([regex]::Matches($got, '(?m)^revert-run: verdicts\.ps1, skipped as a verdict: (.+?)\r?$') | ForEach-Object { $_.Groups[1].Value })
            ($dropped -join '|') -ceq ($want -join '|') -and ($written.Skipped -join '|') -ceq $skips -and
                $code -eq 1 -and ($printed -join '|') -ceq 'line 1, 2 operand(s)|line 2, 3 operand(s)|line 3, 2 operand(s)' -and
                $got -notmatch '(?m)^revert-run: condition ' -and (& $same) } }
        @{ Name = '-Base writes condition reverts only on the lines git diff <ref> changes, a hunk of one line or more, a list of one element on a changed line named and not written, the first operand of a chain over two lines when only its line changed, says the ref in the line it prints, drops nothing where no line changed, naming the ref when that fails the run, or where a hunk only deletes, and fails with no -Conditions or a ref git cannot diff (#400)'; Test = {
            # Lines 5 and 6 changed in one hunk, line 9 in a hunk of its own, and line 17, a list of
            # one element, in another.
            $lines = [IO.File]::ReadAllText((Join-Path $repo 'conditions.ps1')) -split "`n"
            $lines[4] = "`$hit = `$x -in 'a', 'b', 'c'"; $lines[5] = "`$no = `$x -notin 'q', 'r', 's'"; $lines[8] = '$typed = $k -in [string], [int], [char]'; $lines[16] = "`$one = `$x -in ,'c'"
            [IO.File]::WriteAllText((Join-Path $repo 'conditions.ps1'), ($lines -join "`n"))
            & $git commit --quiet -am 'base'
            $written = Get-ConditionRevert -Root $repo -Script 'conditions.ps1' -Since 'HEAD~1'
            $said = @($written.Reverts | ForEach-Object { $_.Name -replace '^condition conditions\.ps1:' })
            $r = & $main @{ Copy = $repo; List = (& $list 'base' "@{ Reverts = @( $(& $one "`$b = ''beta''" "`$b = ''other''") ) }"); Base = 'HEAD~1' }
            $alone = $r.Text; $aloneCode = $r.Code
            $r = & $main @{ Copy = $repo; Conditions = @('conditions.ps1'); Base = 'no-such-ref' }; $badRef = $r.Text; $badRefCode = $r.Code
            Write-Host (($alone + $badRef).TrimEnd() -replace '(?m)^', '    ')
            # A chain over two lines, of which only the first operand's line changed.
            [IO.File]::WriteAllText((Join-Path $repo 'spans.ps1'), "`$ok = `$x -ne 'a' -and`n    `$x -ne 'z'`n")
            & $git add spans.ps1; & $git commit --quiet -m 'spans'
            [IO.File]::WriteAllText((Join-Path $repo 'spans.ps1'), "`$ok = `$x -ne 'b' -and`n    `$x -ne 'z'`n")
            & $git commit --quiet -am 'first'
            $spans = @((Get-ConditionRevert -Root $repo -Script 'spans.ps1' -Since 'HEAD~1').Reverts)
            # In this process, the written line names the ref.
            $r = & $main @{ Copy = $repo; Conditions = @('spans.ps1'); Base = 'HEAD~1' }; $since = $r.Text; $sinceCode = $r.Code
            Write-Host ($since.TrimEnd() -replace '(?m)^', '    ')
            # No line changed since the ref: nothing to drop.
            $nothing = @((Get-ConditionRevert -Root $repo -Script 'spans.ps1' -Since 'HEAD').Reverts)
            # In this process, the failure names the ref that left nothing.
            $r = & $main @{ Copy = $repo; Conditions = @('spans.ps1'); Base = 'HEAD' }; $noneSince = $r.Text; $noneSinceCode = $r.Code
            Write-Host ($noneSince.TrimEnd() -replace '(?m)^', '    ')
            # A line deleted after a condition, a hunk +1,0, changes no line of the condition.
            [IO.File]::WriteAllText((Join-Path $repo 'del.ps1'), "`$a = `$x -ne 'a' -and `$x -ne 'b'`n# gone`n")
            & $git add del.ps1; & $git commit --quiet -m 'del'
            [IO.File]::WriteAllText((Join-Path $repo 'del.ps1'), "`$a = `$x -ne 'a' -and `$x -ne 'b'`n")
            & $git commit --quiet -am 'deleted'
            $deleted = @((Get-ConditionRevert -Root $repo -Script 'del.ps1' -Since 'HEAD~1').Reverts)
            $nothing.Count -eq 0 -and $deleted.Count -eq 0 -and $noneSinceCode -eq 1 -and
                $noneSince -match 'spans\.ps1, for which no condition revert could be written on lines changed since HEAD, so no revert was run' -and
                $sinceCode -eq 0 -and $since -match '(?m)^revert-run: 1 condition revert\(s\) written for spans\.ps1, on lines changed since HEAD~1\.\r?$' -and
                $spans.Count -eq 1 -and $spans[0].Name -ceq "condition spans.ps1:1 -and drops `$x -ne 'b'" -and $spans[0].Lines -eq 2 -and
                $spans[0].Find -ceq "`$ok = `$x -ne 'b' -and`n    `$x -ne 'z'" -and $spans[0].Replace -ceq "`$ok = `$x -ne 'z'" -and
                ($said -join '|') -ceq "5 -in drops 'a'|5 -in drops 'b'|5 -in drops 'c'|6 -notin drops 'q'|6 -notin drops 'r'|6 -notin drops 's'|9 -in drops [string]|9 -in drops [int]|9 -in drops [char]" -and
                ($written.Unwritten -join '|') -ceq 'line 17, a -in of one element' -and $aloneCode -eq 1 -and $alone -match '-Base limits -Conditions, which is not given' -and
                $badRefCode -eq 1 -and $badRef -match '-Base no-such-ref is not a ref git can diff in the copy' -and (& $same) } }
        @{ Name = 'of two shapes that start together, the outer comes first: Get-ShapeOrder given each inner first, and 30 chains each inside one of the other operator (#400)'; Test = {
            # Given inner first, a sort that keeps tied items in order leaves them so, and one that
            # does not turns some over; only the second key puts every outer first, on any runtime.
            $fake = { param($at, $to, $tag) @{ Tag = $tag; Node = [pscustomobject]@{ Extent = [pscustomobject]@{ StartOffset = $at; EndOffset = $to } } } }
            $given = @(for ($i = 0; $i -lt 30; $i++) { & $fake (10 * $i) (10 * $i + 3) "inner$i"; & $fake (10 * $i) (10 * $i + 8) "outer$i" })
            $sorted = @(Get-ShapeOrder -Shapes $given | ForEach-Object { $_.Tag })
            $wantSorted = @(for ($i = 0; $i -lt 30; $i++) { "outer$i"; "inner$i" })
            # Read from a script: with 60 tied shapes, Sort-Object on 7.6.9 turns some over too.
            $nests = Join-Path $temp 'nests'
            New-Item -ItemType Directory -Path $nests -Force | Out-Null
            $chains = for ($i = 1; $i -le 30; $i++) { "`$m$i = `$k -and `$x -eq 'b$i' -or `$x -eq 'c$i'" }
            [IO.File]::WriteAllText((Join-Path $nests 'nests.ps1'), (($chains -join "`n") + "`n"))
            $order = @((Get-ConditionRevert -Root $nests -Script 'nests.ps1').Reverts | ForEach-Object { ($_.Name -split ' ')[1, 2] -join ' ' })
            $want = @(for ($i = 1; $i -le 30; $i++) { "nests.ps1:$i -or"; "nests.ps1:$i -or"; "nests.ps1:$i -and"; "nests.ps1:$i -and" })
            ($sorted -join '|') -ceq ($wantSorted -join '|') -and ($order -join '|') -ceq ($want -join '|') -and (& $same) } }
        @{ Name = 'with neither -List, -Defaults nor -Conditions, and with -Defaults naming no file of the copy, the run fails, exit 1, and runs nothing'; Test = {
            $r = & $main @{ Copy = $repo }; $neither = $r.Text; $neitherCode = $r.Code
            $r = & $main @{ Copy = $repo; Defaults = @('no-such.ps1') }; $missing = $r.Text; $missingCode = $r.Code
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
        @{ Name = 'a self-test still running at -TimeoutSeconds is killed with the child it waits on and reported timed out within a few seconds of the limit, with the seconds it ran and no exit code; one that leaves a child holding its output open is reported crashed a few seconds after it exits; the copy is clean after each, and the next revert runs (#424)'; Test = {
            $sleepPid = Join-Path $temp 'sleep.pid'; $lingerPid = Join-Path $temp 'linger.pid'
            $p = & $list 'timeout' ("@{ Reverts = @( $(& $one "`$b = ''beta''" "`$b = ''other''" "; Args = @('-Mode', 'sleep', '-PidFile', '$sleepPid')"), " +
                "$(& $one "`$b = ''beta''" "`$b = ''held''" "; Args = @('-Mode', 'linger', '-PidFile', '$lingerPid')"), $(& $one "`$b = ''beta''" "`$b = ''next''") ) }")
            # The case's own bound on the run, not the run's code: with the run's limit reverted it
            # fails this case rather than hanging the self-test.
            $start = [Diagnostics.ProcessStartInfo]::new((Get-Command pwsh -CommandType Application | Select-Object -First 1).Source)
            foreach ($a in '-NoProfile', '-File', $PSCommandPath, '-Copy', $repo, '-List', $p, '-TimeoutSeconds', '8') { $start.ArgumentList.Add($a) }
            $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true; $start.UseShellExecute = $false
            $child = [Diagnostics.Process]::Start($start)
            $out = $child.StandardOutput.ReadToEndAsync(); $err = $child.StandardError.ReadToEndAsync()
            $bounded = $child.WaitForExit(90000)
            if (-not $bounded) { $child.Kill($true); $child.WaitForExit(); & $git checkout -q -- stub.ps1; Write-Host '    the run was still going after 90 s, and was killed' }
            # The sleep's child is ended only by a kill of the whole tree; the linger's is left on
            # purpose, and holds this run's output too, so it is ended before that is read.
            $alive = { param([string] $f) (Test-Path -LiteralPath $f) -and $null -ne (Get-Process -Id ([int] (Get-Content -LiteralPath $f -Raw).Trim()) -ErrorAction SilentlyContinue) }
            $orphan = & $alive $sleepPid
            foreach ($f in $sleepPid, $lingerPid) { if (& $alive $f) { Stop-Process -Id ([int] (Get-Content -LiteralPath $f -Raw).Trim()) -Force } }
            [void] [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]] @($out, $err), 10000)
            $text = (@($out, $err) | Where-Object IsCompleted | ForEach-Object Result) -join ''
            Write-Host ($text.TrimEnd() -replace '(?m)^', '    ')
            if ($orphan) { Write-Host '    the sleeping self-test''s child was still running after the kill' }
            $after = if ($text -match '(?m)^revert-run: R -- timed out: killed after (\d+\.\d) s, at the limit of 8 s\r?$') { [double] $Matches[1] } else { -1 }
            $bounded -and $child.ExitCode -eq 0 -and $after -ge 8 -and $after -lt 13 -and (Test-Path -LiteralPath $sleepPid) -and -not $orphan -and
                $text -match '(?m)^\| R \| timed out \|  \| killed after \d+\.\d s, at the limit of 8 s \|' -and
                $text -match '(?m)^revert-run: R -- crashed \(exit 0\): its output was still held open 5 s after it exited, by a process it left running\r?$' -and
                @([regex]::Matches($text, '(?m)^revert-run: R -- ')).Count -eq 3 -and $text -match '(?m)^revert-run: R -- passes \(exit 0\)' -and
                $text -match '(?m)^OK - revert-run: 3 revert\(s\) run or refused: 1 crashed, 1 passes, 1 timed out\.' -and (& $same) } }
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
        @{ Name = 'a Find with a line break matches a CRLF file, and one from a CRLF list an LF file, a file with a byte-order mark keeps it, a file git would write back with other line ends is restored as it stood (#422), and a list it cannot read, or one with no Reverts or a field missing, fails'; Test = {
            $crlf = Join-Path $temp 'crlf'
            New-Item -ItemType Directory -Path $crlf | Out-Null
            git -C $crlf init --quiet; git -C $crlf config core.autocrlf false
            [IO.File]::WriteAllText((Join-Path $crlf 'stub.ps1'), ($stub -replace "`n", "`r`n") + "`r`n")
            # With a byte-order mark: an edit that dropped it would change line 1 too.
            [IO.File]::WriteAllText((Join-Path $crlf 'bom.ps1'), "$stub`n", [Text.UTF8Encoding]::new($true))
            # LF on disk, which git reads as clean but would write back with CRLF, by its eol.
            [IO.File]::WriteAllText((Join-Path $crlf 'lf.ps1'), "$stub`n")
            [IO.File]::WriteAllText((Join-Path $crlf '.gitattributes'), "lf.ps1 text eol=crlf`n")
            git -C $crlf add stub.ps1 bom.ps1 lf.ps1 .gitattributes; git -C $crlf -c user.name=s -c user.email=s@example.invalid -c commit.gpgsign=false commit --quiet -m stub
            $lfBytes = "$([IO.File]::ReadAllBytes((Join-Path $crlf 'lf.ps1')))"
            $bom = "@{ Name = 'B'; File = 'bom.ps1'; Find = '`$c = ''gamma'''; Replace = '`$c = ''other'''; SelfTest = 'bom.ps1' }"
            $lf = "@{ Name = 'L'; File = 'lf.ps1'; Find = '`$c = ''gamma'''; Replace = '`$c = ''other'''; SelfTest = 'lf.ps1' }"
            $p = & $list 'crlf' "@{ Reverts = @( $(& $one "`$a = ''alpha''`n`$b = ''beta''" "`$a = ''other''`n`$b = ''beta''"), $bom, $lf ) }"
            $matched = (& $main @{ Copy = $crlf; List = $p }).Text
            $restored = "$([IO.File]::ReadAllBytes((Join-Path $crlf 'lf.ps1')))" -ceq $lfBytes -and -not @(Get-DirtyPath -Root $crlf)
            Write-Host ($matched.TrimEnd() -replace '(?m)^', '    ')
            # A list saved with CRLF, its Find spanning two lines of the LF stub.
            $crlfList = & $list 'crlf-list' "@{ Reverts = @( $(& $one "`$a = ''alpha''`n`$b = ''beta''" "`$a = ''other''`n`$b = ''beta''") ) }"
            [IO.File]::WriteAllText($crlfList, ([IO.File]::ReadAllText($crlfList) -replace '\r?\n', "`r`n"))
            $fromCrlf = & $run $crlfList
            $broken = & $run (& $list 'broken' '@{ Reverts = ')
            $empty = & $run (& $list 'empty' '@{ Other = 1 }')
            $field = & $run (& $list 'field' "@{ Reverts = @( @{ Name = 'R'; File = 'stub.ps1' } ) }")
            $matched -match '(?m)^revert-run: R -- fails \(exit 1\)' -and $matched -match '(?m)^revert-run: B -- passes \(exit 0\)' -and
                $matched -match '(?m)^revert-run: L -- passes \(exit 0\)' -and $restored -and
                $fromCrlf.Text -match '(?m)^revert-run: R -- fails \(exit 1\)' -and (& $same) -and
                $broken.Code -eq 1 -and $broken.Text -match 'cannot be read' -and $empty.Code -eq 1 -and $empty.Text -match 'holds no Reverts' -and
                $field.Code -eq 1 -and $field.Text -match 'lacks Find, Replace, SelfTest' } }
    )

    $failures = 0
    $n = 0
    try {
        foreach ($c in $cases) {
            $n++
            $ok = try { & $judgeCase $c.Test } catch { Write-Host "    threw: $($_.Exception.Message)"; $false }
            if ($c.Name -ceq $leakCase) { $ok = -not $ok }
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

exit (Invoke-Main -Copy $Copy -List $List -Defaults $Defaults -Conditions $Conditions -Base $Base -TimeoutSeconds $TimeoutSeconds)
