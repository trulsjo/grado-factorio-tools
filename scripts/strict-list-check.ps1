<#
.SYNOPSIS
    Reads each strict-mode script under the paths it is given and fails on a property read
    strict mode can throw on: .Count off a command result that can be $null or one object, or .Id
    or .Name off any command result. Exit 0 means each path given held a script outside the
    fixture folder, at least one script read sets strict mode, and no such read was found in
    them (#375).

.DESCRIPTION
    WHERE IT CAME FROM (grado-factorio-tools#343, #316 rulings 2 and 5). true-nukes-refreshed's
    scripts/tests/strict-lists.ps1 and its fixtures in scripts/tests/strict-lists/, at 78486d2,
    read 2026-11-06. The rule, the method and what it cannot see are its own, kept as they were;
    what changed is how it is run: the fixtures are its -SelfTest, here in strict-list-check/
    beside it, and a run reads the paths it is given. The marker keeps its name.

    WHY. Under Set-StrictMode -Version Latest a command that outputs nothing gives $null, and one
    that outputs one object gives that object. Reading .Count off either throws, and so does
    reading the .Id or .Name of $null or of an empty array. All of it shows only on the run that
    finds nothing or one, often minutes into a real check; it happened six times on 2026-11-05.

    The fixes differ by property. For .Count, wrap the command in @(...), which always gives an
    array. For .Id and .Name, take them with ForEach-Object Id or ForEach-Object Name, which gives
    nothing for nothing; @(...) does not help there, since an empty array has no .Name.
    A statement that always outputs exactly one object, such as one calling Start-Process
    -PassThru, is right for .Id and .Name: put the comment # strict-lists: one straight after it,
    on the line where it ends (a ; between is fine). One object still has no .Count, so the
    marker never makes a .Count read safe. In $a, $b = ... only the first variable gets the one
    object. A marker after a line with several unsafe reads covers none of them; nor does a
    marker after a string cover a statement inside it.

    It parses each .ps1 that calls Set-StrictMode and gives each value a state:
      bare      a command result as PowerShell hands it over: Get-Thing, (Get-Thing),
                $(Get-Thing), [type](Get-Thing), $a, $b = Get-Thing, or a foreach, while, if,
                switch or try statement used as a value, whose output is unrolled
      wrapped   @(...) around a command or a bare or wrapped variable, or a command added to an
                array with +=
      one       a statement marked # strict-lists: one
    Reading .Count is unsafe off bare and one; reading .Id or .Name, off bare and wrapped. A type
    constraint does not wrap: [string[]] $x = Get-Thing gives $null for nothing.

    A variable's state at a read is that of every assignment that can reach it, in the same
    function (or the script, outside any). It errs towards flagging. Going back from the read,
    each assignment counts until one that surely runs before it: one directly in a block holding
    the read, not in a branch, a switch clause, a try, catch or finally block, a loop, a script
    block or a for loop's iterator. An assignment in another branch of an if does not reach the
    read on the same pass. Loops include switch, which runs its clauses once per item and runs
    every clause that matches. Inside a loop, the assignments after the read also count, back to
    the last one directly in the loop body, and so do those in other branches of an if in the
    loop; this is skipped when an assignment before the read in the same loop surely ran, other
    than a for loop's initializer. A compound assignment (+=) keeps the state the variable had,
    and a variable copied from another ($q = $p) takes that one's state.

    THE SELF-TEST runs the check on the fixtures in strict-list-check/, where each line it must
    flag carries the comment # expect: flag, or # expect: flag 2 for two reads, and fails unless
    it flags each line exactly that often. Then it runs each strict-mode fixture and requires,
    read by read, that every read runs and that exactly the flagged ones throw, so a fixture
    cannot pin a wrong belief about strict mode; a line marked "known false hit" or "known miss"
    excuses the one disagreement it names, and only of that kind. A run with -Path skips that
    folder. Then it runs itself in a pwsh of its own, as a gate does, over paths that must each
    fail, naming why: a folder whose one script sets no strict mode, a folder with no script
    beside one with a script, the fixture folder alone, and a script that does not parse. Last,
    it runs scratch fixtures, each untrue in one way, and requires each to be named for that way
    (#376).

    What it cannot see: a command result passed in as a parameter, a variable assigned in one
    function and read in another, a copy made inside a loop of a variable assigned later in that
    loop, an assignment inside the read itself (($j = Get-Thing).Count), $_ in a pipeline, a
    script block a command runs repeatedly, such as ForEach-Object { }, which it does not treat
    as a loop, other properties (.Length, .Exit) and results of method calls.

    What it flags wrongly: a foreach, if, switch or try used as a value when no branch can give
    $null or one object, such as one whose branches each give a hashtable or an array as one
    object (, @(...)); and a bare value reassigned in every branch of an if and its else. For .Id
    and .Name, mark such a statement; for .Count, the marker does not help, so assign a wrapped
    value instead. It runs no game.

    WHERE IT RUNS HERE. check.ps1 runs its -SelfTest, and a run over this repository's scripts/
    (#373), whose 35 reads of 2026-11-07 were each fixed or marked.

.PARAMETER Path
    The scripts, or directories of scripts read with their subdirectories, to check.

.PARAMETER SelfTest
    Run the check on its fixtures, and the fixtures under strict mode, and nothing else.

.EXAMPLE
    pwsh -File scripts/strict-list-check.ps1 scripts
#>
using namespace System.Management.Automation.Language
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

$properties = 'Count', 'Id', 'Name'
$marker = '^#\s*strict-lists:\s*one\b'
$fixtures = Join-Path $PSScriptRoot 'strict-list-check'
# What each script is named relative to.
$root = (Get-Location).Path

# What may run zero times, or more than once, so an assignment inside does not surely come first.
$conditional = [LoopStatementAst], [IfStatementAst], [SwitchStatementAst], [TryStatementAst], [TrapStatementAst],
    [ScriptBlockAst], [PipelineChainAst]

function Get-Source([Ast] $Node, [scriptblock] $Resolve) {
    # A value's state: 'bare', 'wrapped', 'one' (from a marked variable), or $null for a value no
    # command produced. $Resolve gives a variable's state where it is read.
    if ($Node -is [PipelineAst]) {
        if (@($Node.PipelineElements | Where-Object { $_ -is [CommandAst] }).Count) { return 'bare' }
        if ($Node.PipelineElements.Count -eq 1 -and $Node.PipelineElements[0] -is [CommandExpressionAst]) {
            return Get-Source $Node.PipelineElements[0].Expression $Resolve
        }
        return $null
    }
    # An assignment's right side is an expression statement when it holds no pipeline.
    if ($Node -is [CommandExpressionAst]) { return Get-Source $Node.Expression $Resolve }
    if ($Node -is [LoopStatementAst] -or $Node -is [IfStatementAst] -or $Node -is [SwitchStatementAst] -or
        $Node -is [TryStatementAst]) { return 'bare' }
    if ($Node -is [VariableExpressionAst]) { return & $Resolve $Node }
    if ($Node -is [ParenExpressionAst]) { return Get-Source $Node.Pipeline $Resolve }
    if ($Node -is [ConvertExpressionAst]) { return Get-Source $Node.Child $Resolve }
    if ($Node -is [SubExpressionAst] -or $Node -is [ArrayExpressionAst]) {
        $inner = @($Node.SubExpression.Statements | ForEach-Object { Get-Source $_ $Resolve })
        $empty = $inner -contains 'bare' -or $inner -contains 'wrapped'
        if ($Node -is [ArrayExpressionAst]) {
            # @( ) always gives an array: empty if what it holds can be; one marked object is safe.
            if ($empty) { return 'wrapped' }
            return $null
        }
        # $( ) unrolls what it holds.
        if ($empty) { return 'bare' }
        if ($inner -contains 'one') { return 'one' }
        return $null
    }
    return $null
}

function Join-State([object[]] $States) {
    # One state for several that can reach the same place, unsafe wherever any of them is.
    if ($States -contains 'bare' -or ($States -contains 'wrapped' -and $States -contains 'one')) { return 'bare' }
    if ($States -contains 'wrapped') { return 'wrapped' }
    if ($States -contains 'one') { return 'one' }
    return $null
}

function Test-Unsafe([string] $State, [string] $Property) {
    if ($Property -eq 'Count') { return $State -in 'bare', 'one' }
    return $State -in 'bare', 'wrapped'
}

function Get-Scope([Ast] $Node) {
    # The start of the node's nearest enclosing function, or -1 for the script itself.
    for ($p = $Node.Parent; $p; $p = $p.Parent) {
        if ($p -is [FunctionDefinitionAst]) { return $p.Extent.StartOffset }
    }
    return -1
}

function Get-Loops([Ast] $Node) {
    # The loops around the node, innermost first, up to its function. A switch counts: it runs
    # its clauses once per item of a list, and every clause that matches.
    for ($p = $Node.Parent; $p -and $p -isnot [FunctionDefinitionAst]; $p = $p.Parent) {
        if ($p -is [LoopStatementAst] -or $p -is [SwitchStatementAst]) { $p }
    }
}

function Test-Inside([Ast] $Node, [Ast] $Outer) {
    $Node.Extent.StartOffset -ge $Outer.Extent.StartOffset -and $Node.Extent.EndOffset -le $Outer.Extent.EndOffset
}

function Test-Direct([Ast] $Node, [Ast] $Outer) {
    # Whether the node surely runs, and runs first, whenever $Outer is reached: no branch, loop
    # or script block between them. Reaching $Outer through a branch, a switch clause, a try,
    # catch or finally block, or a for loop's iterator (which runs after the body) is not direct;
    # through a condition it is.
    $child = $Node
    for ($p = $Node.Parent; $p; $p = $p.Parent) {
        if ($p -eq $Outer) {
            if ($p -is [IfStatementAst] -or $p -is [SwitchStatementAst] -or $p -is [TryStatementAst]) {
                return $child -isnot [StatementBlockAst] -and $child -isnot [CatchClauseAst]
            }
            if ($p -is [ForStatementAst] -and $child -eq $p.Iterator) { return $false }
            return $true
        }
        foreach ($t in $conditional) { if ($p -is $t) { return $false } }
        $child = $p
    }
    return $true
}

function Get-Reaching([object[]] $Records, [Ast] $At, [switch] $Loops) {
    # The assignments, of one variable in one scope, whose value can be the one read at $At.
    $start = $At.Extent.StartOffset
    $stop = $null
    $otherBranch = [System.Collections.Generic.List[object]]::new()
    $prior = @($Records | Where-Object { $_.Ast.Extent.EndOffset -le $start })
    for ($i = $prior.Count - 1; $i -ge 0; $i--) {
        $rec = $prior[$i]
        $common = $rec.Ast.Parent
        while ($common -and -not (Test-Inside $At $common)) { $common = $common.Parent }
        $branch = $rec.Ast
        while ($branch.Parent -ne $common) { $branch = $branch.Parent }
        # An assignment in one branch of an if never reaches a read in another on the same pass.
        if ($common -is [IfStatementAst] -and $branch -is [StatementBlockAst]) { $otherBranch.Add($rec); continue }
        $rec
        if (Test-Direct $rec.Ast $common) { $stop = $rec; break }
    }
    if (-not $Loops) { return }
    foreach ($loop in @(Get-Loops $At)) {
        # An assignment before the read in this loop sets the value on every pass, unless it is
        # a for loop's initializer, which runs only once.
        $init = if ($loop -is [ForStatementAst]) { $loop.Initializer } else { $null }
        if ($stop -and (Test-Inside $stop.Ast $loop) -and -not ($init -and (Test-Inside $stop.Ast $init))) { break }
        # On the next pass, another branch of an if in the loop can have run.
        $otherBranch | Where-Object { Test-Inside $_.Ast $loop }
        $later = @($Records | Where-Object { $_.Ast.Extent.StartOffset -gt $start -and (Test-Inside $_.Ast $loop) })
        for ($i = $later.Count - 1; $i -ge 0; $i--) {
            $later[$i]
            if (Test-Direct $later[$i].Ast $loop) { break }
        }
    }
}

function Get-VarName([VariableExpressionAst] $Var) {
    $Var.VariablePath.UserPath -replace '^(script|global|local|private):', ''
}

function Get-Target([Ast] $Left) {
    # The plain variables an assignment's left side sets: $x, [type] $x, or $a, $b.
    if ($Left -is [ConvertExpressionAst]) { $Left = $Left.Child }
    if ($Left -is [VariableExpressionAst]) { return $Left }
    if ($Left -is [ArrayLiteralAst]) {
        foreach ($e in $Left.Elements) {
            if ($e -is [ConvertExpressionAst]) { $e = $e.Child }
            if ($e -is [VariableExpressionAst]) { $e }
        }
    }
}

function Get-FlatTokens([Token[]] $Tokens) {
    # Every token, with those inside expandable strings, which the parser nests.
    foreach ($t in $Tokens) {
        $t
        if ($t -is [StringExpandableToken] -and $t.NestedTokens) { Get-FlatTokens @($t.NestedTokens) }
    }
}

function Invoke-Check([IO.FileInfo[]] $Files) {
    foreach ($file in $Files) {
        $tokens = $null
        $errors = $null
        $ast = [Parser]::ParseFile($file.FullName, [ref] $tokens, [ref] $errors)
        $where = [IO.Path]::GetRelativePath($root, $file.FullName)
        if ($errors) {
            [pscustomobject]@{ File = $file.FullName; Line = 0; Text = "$($where): does not parse: $($errors[0].Message)" }
            continue
        }
        $strict = @($ast.FindAll({ param($n) $n -is [CommandAst] -and $n.GetCommandName() -eq 'Set-StrictMode' }, $true))
        if (-not $strict.Count) { continue }
        $script:checked++
        $lines = @(Get-Content -LiteralPath $file.FullName)

        # Where each marker attaches: the end of the token right before it on its line, skipping
        # ; and line continuations. A statement ending exactly there is marked. With the tokens
        # inside strings included, a statement inside a string ends before the string does.
        $flat = @(Get-FlatTokens $tokens)
        $markedEnds = [System.Collections.Generic.HashSet[int]]::new()
        foreach ($m in @($flat | Where-Object { $_.Kind -eq 'Comment' -and $_.Text -match $marker })) {
            $anchor = $null
            foreach ($t in $flat) {
                if ($t.Extent.EndOffset -le $m.Extent.StartOffset -and
                    $t.Kind -notin 'Semi', 'LineContinuation', 'NewLine', 'Comment' -and
                    (-not $anchor -or $t.Extent.EndOffset -gt $anchor.Extent.EndOffset)) { $anchor = $t }
            }
            if ($anchor -and $anchor.Extent.EndLineNumber -eq $m.Extent.StartLineNumber) {
                [void] $markedEnds.Add($anchor.Extent.EndOffset)
            }
        }

        # Every assignment to a variable, by scope and name, in source order, with the state it
        # leaves the variable in.
        $assigned = @{}
        # While assignments are worked out, a variable resolves from those before it: later ones
        # in a loop are not known yet, so a copy made inside a loop misses a value carried round it.
        $resolve = {
            param([VariableExpressionAst] $Var)
            $k = "$(Get-Scope $Var)|$(Get-VarName $Var)"
            if (-not $assigned.ContainsKey($k)) { return $null }
            Join-State @(Get-Reaching $assigned[$k].ToArray() $Var | ForEach-Object State)
        }
        # Once all are known, an inline read resolves round loops too, like a plain one.
        $resolveAll = {
            param([VariableExpressionAst] $Var)
            $k = "$(Get-Scope $Var)|$(Get-VarName $Var)"
            if (-not $assigned.ContainsKey($k)) { return $null }
            Join-State @(Get-Reaching $assigned[$k].ToArray() $Var -Loops | ForEach-Object State)
        }
        $all = @($ast.FindAll({ param($n) $n -is [AssignmentStatementAst] }, $true) | Sort-Object { $_.Extent.StartOffset })
        foreach ($a in $all) {
            $targets = @(Get-Target $a.Left)
            if (-not $targets.Count) { continue }
            $marked = $markedEnds.Contains($a.Extent.EndOffset)
            $source = if ($marked) { 'one' } else { Get-Source $a.Right $resolve }
            $records = foreach ($t in $targets) {
                $key = "$(Get-Scope $a)|$(Get-VarName $t)"
                if (-not $assigned.ContainsKey($key)) { $assigned[$key] = [System.Collections.Generic.List[object]]::new() }
                $state = $source
                if ($targets.Count -gt 1 -and $source) {
                    # $a, $b = ... splits the value: past the first variable, any can be $null.
                    $state = if ($marked -and $t -eq $targets[0]) { 'one' } else { 'bare' }
                }
                if ($a.Operator -ne [TokenKind]::Equals) {
                    # += and the like keep what the variable held; a command added to a value
                    # no command produced makes an array that can be empty.
                    $prev = Join-State @(Get-Reaching $assigned[$key].ToArray() $a | ForEach-Object State)
                    $state = if ($prev -in 'bare', 'wrapped') { $prev } elseif ($source) { 'wrapped' } else { $prev }
                }
                @{ Key = $key; Record = [pscustomobject]@{ Ast = $a; Line = $a.Extent.StartLineNumber; State = $state } }
            }
            # Added after all are worked out, so $x = @($x) reads the state from before.
            foreach ($rec in @($records)) { $assigned[$rec.Key].Add($rec.Record) }
        }

        $reads = @($ast.FindAll({ param($n)
                    $n -is [MemberExpressionAst] -and $n -isnot [InvokeMemberExpressionAst] -and
                    $n.Member -is [StringConstantExpressionAst] -and $n.Member.Value -in $properties
                }, $true))
        # Inline reads first, so a marker can tell whether its statement holds only one.
        $inline = @(foreach ($r in $reads) {
                if ($r.Expression -is [VariableExpressionAst]) { continue }
                $state = Get-Source $r.Expression $resolveAll
                if (Test-Unsafe $state $r.Member.Value) { [pscustomobject]@{ Read = $r; State = $state } }
            })
        foreach ($r in $reads) {
            $prop = $r.Member.Value
            $target = $r.Expression
            $why = $null
            if ($target -is [VariableExpressionAst]) {
                $key = "$(Get-Scope $r)|$(Get-VarName $target)"
                if (-not $assigned.ContainsKey($key)) { continue }
                $reaching = @(Get-Reaching $assigned[$key].ToArray() $r -Loops)
                $bad = @($reaching | Where-Object { Test-Unsafe $_.State $prop } | Select-Object -First 1)
                if ($bad.Count) {
                    $kind = switch ($bad[0].State) { 'wrapped' { 'a wrapped' } 'one' { 'a single-object' } default { 'an unwrapped' } }
                    $why = "off `$$(Get-VarName $target), assigned $kind command result on line $($bad[0].Line)"
                }
            } else {
                $mine = @($inline | Where-Object { $_.Read -eq $r })
                if (-not $mine.Count) { continue }
                # A marked statement around the read covers it if it holds no other unsafe read,
                # and only for .Id and .Name: its one object has no .Count.
                $covered = $false
                for ($s = $r.Parent; $s -and -not $covered -and -not (Test-Unsafe 'one' $prop); $s = $s.Parent) {
                    if ($s -is [StatementAst] -and $markedEnds.Contains($s.Extent.EndOffset)) {
                        $covered = @($inline | Where-Object { Test-Inside $_.Read $s }).Count -eq 1
                    }
                }
                if (-not $covered) {
                    $kind = switch ($mine[0].State) { 'wrapped' { 'a wrapped' } 'one' { 'a single-object' } default { 'an unwrapped' } }
                    $why = "off $kind command result"
                }
            }
            if (-not $why) { continue }
            $fix = if ($prop -eq 'Count') { 'wrap the command in @(...)' } else {
                "take it with ForEach-Object $prop, or end a statement that always outputs one object with # strict-lists: one"
            }
            $line = $r.Extent.StartLineNumber
            [pscustomobject]@{
                File   = $file.FullName
                Line   = $line
                Offset = $r.Extent.StartOffset
                Text   = "$($where):$($line): .$prop $why; $fix`n      $($lines[$line - 1].Trim())"
            }
        }
    }
}

function Get-FixtureRun([IO.FileInfo] $File) {
    # Runs a fixture in a fresh runspace, so it sees none of this script's variables and cannot
    # move its location, with every read wrapped to record that it ran and whether strict mode
    # refused it (PropertyNotFoundStrict); any other error stops the run. The read's value passes
    # through unchanged, arrays and all. Start-Process is replaced by this process's own Process
    # object: one object, with an .Id and a .Name, and no .Count. Gives each read: its offset,
    # line and property, and whether it ran and threw.
    $tokens = $null
    $errors = $null
    $ast = [Parser]::ParseFile($File.FullName, [ref] $tokens, [ref] $errors)
    $text = $ast.Extent.Text
    $reads = @($ast.FindAll({ param($n)
                $n -is [MemberExpressionAst] -and $n -isnot [InvokeMemberExpressionAst] -and
                $n.Member -is [StringConstantExpressionAst] -and $n.Member.Value -in $properties
            }, $true) | Sort-Object { $_.Extent.StartOffset } -Descending)
    foreach ($r in $reads) {
        if (@($reads | Where-Object { $_ -ne $r -and (Test-Inside $_ $r) }).Count) {
            throw "$($File.Name):$($r.Extent.StartLineNumber): a read inside another read cannot be run as a fixture"
        }
    }
    $code = [System.Text.StringBuilder]::new($text)
    foreach ($r in $reads) {
        $s = $r.Extent.StartOffset
        [void] $code.Remove($s, $r.Extent.EndOffset - $s)
        [void] $code.Insert($s, ("`$(try { `$null = `$__ran.Add($s); Write-Output -NoEnumerate -InputObject ($($r.Extent.Text)) } " +
                "catch { if (`$_.FullyQualifiedErrorId -like 'PropertyNotFoundStrict*') { `$null = `$__threw.Add($s) } else { throw } })"))
    }
    $prelude = "`$ErrorActionPreference = 'Stop'`n" +
        "function Start-Process { [System.Diagnostics.Process]::GetCurrentProcess() }`n" +
        "`$__ran = [System.Collections.Generic.HashSet[int]]::new()`n" +
        "`$__threw = [System.Collections.Generic.HashSet[int]]::new()`n"
    # The results are read from the runspace's own variables, not from the fixture's output,
    # which the fixture controls.
    $epilogue = "`n`$__strictListsDone = `$true"
    $ps = [powershell]::Create()
    try {
        [void] $ps.AddScript($prelude + $code.ToString() + $epilogue).Invoke()
        # An error that does not stop the script, such as Write-Error -ErrorAction Continue,
        # lands in the error stream, not in an exception.
        if ($ps.HadErrors -and $ps.Streams.Error.Count) { throw "it wrote an error: $($ps.Streams.Error[0])" }
        $state = $ps.Runspace.SessionStateProxy
        if ($state.GetVariable('__strictListsDone') -ne $true) {
            throw 'it ended before its last line, by a return, an exit or a break outside a loop'
        }
        $result = @{ Ran = $state.GetVariable('__ran'); Threw = $state.GetVariable('__threw') }
    } finally { $ps.Dispose() }
    foreach ($r in $reads) {
        $s = $r.Extent.StartOffset
        [pscustomobject]@{
            Offset = $s
            Line   = $r.Extent.StartLineNumber
            Read   = ".$($r.Member.Value)"
            Ran    = $result.Ran.Contains($s)
            Threw  = $result.Threw.Contains($s)
        }
    }
}

function Get-Files([string[]] $From) {
    @($From | ForEach-Object {
            if (Test-Path -LiteralPath $_ -PathType Container) {
                Get-ChildItem -LiteralPath $_ -Recurse -Filter '*.ps1' -File
            } else { Get-Item -LiteralPath $_ }
        })
}


if ($SelfTest) {
    $root = $PSScriptRoot
    # First the fixtures: the check must flag exactly the lines marked # expect: flag, as many
    # times as # expect: flag <n> says (once without a number).
    $script:checked = 0
    $fixtureFiles = Get-Files $fixtures
    $want = @{}
    foreach ($f in $fixtureFiles) {
        $n = 0
        foreach ($l in Get-Content -LiteralPath $f.FullName) {
            $n++
            if ($l -match '#\s*expect:\s*flag(?:\s+(\d+))?\b') { $want["$($f.Name):$n"] = if ($Matches[1]) { [int] $Matches[1] } else { 1 } }
        }
    }
    $got = @{}
    $fixtureHits = @(Invoke-Check $fixtureFiles)
    foreach ($hit in $fixtureHits) {
        $k = "$(Split-Path $hit.File -Leaf):$($hit.Line)"
        $got[$k] = 1 + $(if ($got.ContainsKey($k)) { $got[$k] } else { 0 })
    }
    # Each line flagged other than its # expect: says, by name and line.
    function Get-FixtureMismatch([hashtable] $Want, [hashtable] $Got) {
        @(@($Want.Keys) + @($Got.Keys) | Sort-Object -Unique | ForEach-Object {
                $w = if ($Want.ContainsKey($_)) { $Want[$_] } else { 0 }
                $g = if ($Got.ContainsKey($_)) { $Got[$_] } else { 0 }
                if ($w -ne $g) { "$($_): flagged $g time(s), expected $w" }
            })
    }
    $wrong = @(Get-FixtureMismatch $want $got)
    $expected = ($want.Values | Measure-Object -Sum).Sum
    Write-Host "self-test 1/7: the check flags each fixture line as often as its # expect: flag says -- $(if (-not $want.Count -or $wrong.Count) { 'FAILED' } else { 'ok' })"
    $wrong | ForEach-Object { Write-Host "    $_" }
    # That the comparison can fail: the fixtures all match, so case 1 alone cannot show it.
    $canary = @(Get-FixtureMismatch @{ 'a.ps1:3' = 1; 'a.ps1:5' = 2 } @{ 'a.ps1:5' = 2; 'a.ps1:9' = 1 })
    $canaryOk = ($canary -join '|') -eq 'a.ps1:3: flagged 0 time(s), expected 1|a.ps1:9: flagged 1 time(s), expected 0'
    Write-Host "self-test 2/7: a line flagged less, or more, than its # expect: says is named -- $(if ($canaryOk) { 'ok' } else { 'FAILED' })"

    # Then PowerShell itself: run each strict-mode fixture and require, read by read, that every
    # read runs and that exactly the flagged ones throw, so a fixture cannot pin a wrong belief
    # about strict mode. On a line marked "known false hit", a flagged read may run safely; on one
    # marked "known miss", an unflagged read may throw. Neither excuses the other kind, or a read
    # that never ran.
    # Each way a fixture can be untrue, named: a function, so case 7 holds it on scratch fixtures.
    function Get-FixtureUntruth([IO.FileInfo[]] $Files, [object[]] $Hits) {
        $flagged = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($hit in $Hits) { [void] $flagged.Add("$(Split-Path $hit.File -Leaf):$($hit.Offset)") }
        foreach ($f in $Files) {
            $source = @(Get-Content -LiteralPath $f.FullName)
            if (-not @($source -match '^\s*Set-StrictMode\b').Count) { continue }
            try { $run = @(Get-FixtureRun $f) } catch { "$($f.Name): stopped when run: $($_.Exception.Message)"; continue }
            $excused = @{}
            foreach ($read in $run) {
                $at = "$($f.Name):$($read.Line): $($read.Read)"
                $text = $source[$read.Line - 1]
                $isFlagged = $flagged.Contains("$($f.Name):$($read.Offset)")
                if (-not $read.Ran) { "$at never ran, so the fixture proves nothing about it"; continue }
                if ($isFlagged -and -not $read.Threw) {
                    if ($text -match '#.*\bknown false hit\b') { $excused["$($read.Line)|false hit"] = $true } else { "$at is flagged, but strict mode let it through" }
                }
                if ($read.Threw -and -not $isFlagged) {
                    if ($text -match '#.*\bknown miss\b') { $excused["$($read.Line)|miss"] = $true } else { "$at threw under strict mode, but is not flagged" }
                }
            }
            # A tag whose disagreement has gone would quietly excuse the next one on its line:
            # each tag on a line with reads must excuse one of them, and a tag on a comment-only
            # line, left behind when its read went, has nothing to excuse.
            $readLines = @($run | ForEach-Object Line | Sort-Object -Unique)
            for ($n = 1; $n -le $source.Count; $n++) {
                if ($n -in $readLines) {
                    foreach ($kind in 'false hit', 'miss') {
                        if ($source[$n - 1] -match "#.*\bknown $kind\b" -and -not $excused.ContainsKey("$n|$kind")) {
                            "$($f.Name):$($n): says known $kind, but none of its reads disagree with strict mode that way now"
                        }
                    }
                } elseif ($source[$n - 1] -match '^\s*#\s*known (false hit|miss)\b') {
                    "$($f.Name):$($n): says known $($Matches[1]) on a line with no reads"
                }
            }
        }
    }
    $untrue = @(Get-FixtureUntruth $fixtureFiles $fixtureHits)
    Write-Host "self-test 3/7: each strict-mode fixture, run, throws on exactly the reads the check flags -- $(if ($untrue.Count) { 'FAILED' } else { 'ok' })"
    $untrue | ForEach-Object { Write-Host "    $_" }

    # Then a run over paths of its own, in a pwsh of its own, as a gate runs it: one that read no
    # strict-mode script, and a -Path that holds no script beside one that does (#375).
    $temp = Join-Path ([IO.Path]::GetTempPath()) "strict-list-check-$([guid]::NewGuid().ToString('N'))"
    $lax = Join-Path $temp 'lax'; $strict = Join-Path $temp 'strict'; $empty = Join-Path $temp 'empty'
    $broken = Join-Path $temp 'broken'; $bad = Join-Path $temp 'bad'
    foreach ($d in $lax, $strict, $empty, $broken, $bad) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    Set-Content -LiteralPath (Join-Path $lax 'lax.ps1') -Value "'no strict mode here'"
    Set-Content -LiteralPath (Join-Path $strict 'strict.ps1') -Value 'Set-StrictMode -Version Latest'
    Set-Content -LiteralPath (Join-Path $empty 'notes.md') -Value 'no script here'
    Set-Content -LiteralPath (Join-Path $broken 'broken.ps1') -Value 'Set-StrictMode -Version Latest', 'function {'
    $run = { param([string] $Paths) $said = & pwsh -NoProfile -File $PSCommandPath $Paths 2>&1 | Out-String; @{ Code = $LASTEXITCODE; Text = $said } }
    # Scratch fixtures, each untrue one way, and the line Get-FixtureUntruth must name for it.
    $badFixtures = [ordered]@{
        'never.ps1'   = @(@('if ($false) { @(1).Count }'), 'never.ps1:2: .Count never ran')
        'wrote.ps1'   = @(@("Write-Error 'x' -ErrorAction Continue", '@(1).Count'), 'wrote.ps1: stopped when run: it wrote an error')
        'early.ps1'   = @(@('@(1).Count', 'return', '@(2).Count'), 'early.ps1: stopped when run: it ended before its last line')
        'stale.ps1'   = @(@('@(1).Count  # known miss'), 'stale.ps1:2: says known miss, but none of its reads disagree')
        'comment.ps1' = @(@('# known false hit', '@(1).Count'), 'comment.ps1:2: says known false hit on a line with no reads')
        'nested.ps1'  = @(@('(Get-Item .).Name.Name'), 'nested.ps1: stopped when run: nested.ps1:2: a read inside another read')
        'other.ps1'   = @(@("(Get-Item -LiteralPath 'no-such-path-strict-list-check').Name"), 'other.ps1: stopped when run: ')
        # A tag excuses only its own kind: each of these is named twice, the second for the tag.
        'hit.ps1'     = @(@('(Get-Item .).Name  # known miss'),
            @('hit.ps1:2: .Name is flagged, but strict mode let it through', 'hit.ps1:2: says known miss, but none'))
        'miss.ps1'    = @(@("'text'.Count  # known false hit"),
            @('miss.ps1:2: .Count threw under strict mode, but is not flagged', 'miss.ps1:2: says known false hit, but none'))
    }
    foreach ($k in $badFixtures.Keys) { Set-Content -LiteralPath (Join-Path $bad $k) -Value (@('Set-StrictMode -Version Latest') + $badFixtures[$k][0]) }
    try {
        $alone = & $run $strict
        $none = & $run $lax
        $beside = & $run "$strict,$empty"
        $fixtureOnly = & $run $fixtures
        $unparsed = & $run $broken
        $badFiles = @(Get-Files $bad)
        $badSaid = @(Get-FixtureUntruth $badFiles @(Invoke-Check $badFiles))
    } finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
    # The run over the strict folder alone passes, so the two below fail for what they hold.
    $noneOk = $alone.Code -eq 0 -and $none.Code -eq 1 -and
        $none.Text -match '(?m)^FAILED - strict-list-check: none of the 1 script\(s\) read sets strict mode'
    Write-Host "self-test 4/7: a run that read no strict-mode script fails, saying so -- $(if ($noneOk) { 'ok' } else { 'FAILED' })"
    if (-not $noneOk) { "$($alone.Text)$($none.Text)".TrimEnd() -split "`n" | ForEach-Object { Write-Host "    $_" } }
    $besideOk = $alone.Code -eq 0 -and $beside.Code -eq 1 -and
        $beside.Text -match "(?m)^FAILED - strict-list-check: $([regex]::Escape($empty)) holds no script" -and
        $beside.Text -notmatch "(?m)^FAILED - strict-list-check: $([regex]::Escape($strict)) holds"
    Write-Host "self-test 5/7: a -Path that holds no script, beside one that does, fails, naming it -- $(if ($besideOk) { 'ok' } else { 'FAILED' })"
    if (-not $besideOk) { $beside.Text.TrimEnd() -split "`n" | ForEach-Object { Write-Host "    $_" } }
    # A run given the fixture folder alone skips it; a script that does not parse is named (#376).
    $skipOk = $fixtureOnly.Code -eq 1 -and $fixtureOnly.Text -match '(?m)^FAILED - strict-list-check: .* holds no script outside the fixture folder' -and
        $unparsed.Code -eq 1 -and $unparsed.Text -match '(?m)broken\.ps1: does not parse: '
    Write-Host "self-test 6/7: a run skips the fixture folder, and names a script that does not parse -- $(if ($skipOk) { 'ok' } else { 'FAILED' })"
    if (-not $skipOk) { "$($fixtureOnly.Text)$($unparsed.Text)".TrimEnd() -split "`n" | ForEach-Object { Write-Host "    $_" } }
    # Each scratch fixture is named for its own fault, so a guard of the runner that stopped
    # holding would let a fixture prove nothing (#376).
    $wantSaid = @($badFixtures.Keys | ForEach-Object { $badFixtures[$_][1] })
    $missed = @($wantSaid | Where-Object { $w = $_; -not @($badSaid | Where-Object { $_.StartsWith($w) }).Count })
    $runnerOk = -not $missed.Count -and $badSaid.Count -eq $wantSaid.Count
    Write-Host "self-test 7/7: the fixture run names a read that never ran, an error, an early end, a stale or stray tag, a tag of the other kind, a read in a read and another error -- $(if ($runnerOk) { 'ok' } else { 'FAILED' })"
    if (-not $runnerOk) { $missed | ForEach-Object { Write-Host "    not named: $_" }; $badSaid | ForEach-Object { Write-Host "    said: $_" } }
    Write-Host ''
    $failures = @(@(-not $want.Count -or $wrong.Count) + @(-not $canaryOk) + @([bool] $untrue.Count) + @(-not $noneOk) + @(-not $besideOk) +
        @(-not $skipOk) + @(-not $runnerOk) | Where-Object { $_ }).Count
    if ($failures) { Write-Host "FAILED - self-test: $failures of 7 case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all 7 cases, $expected fixture flags as expected and as strict mode throws."
    exit 0
}

$script:checked = 0
$fixtureRoot = (Resolve-Path $fixtures).Path.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$files = [System.Collections.Generic.List[IO.FileInfo]]::new()
# Each -Path is held to a script of its own: one that holds none, beside one that does, would
# pass unread (#375).
$holdsNone = @(foreach ($p in $Path) {
        $mine = @(Get-Files $p | Where-Object { -not $_.FullName.StartsWith($fixtureRoot, [StringComparison]::OrdinalIgnoreCase) })
        if (-not $mine.Count) { $p; continue }
        $files.AddRange([IO.FileInfo[]] $mine)
    })
if ($holdsNone.Count) {
    foreach ($p in $holdsNone) { Write-Host "FAILED - strict-list-check: $p holds no script outside the fixture folder, so nothing there was read." }
    exit 1
}
$found = @(Invoke-Check $files.ToArray())
if ($found.Count) {
    $found | ForEach-Object { Write-Host "$($_.Text)" }
    Write-Host "FAILED - strict-list-check: $($found.Count) read(s) strict mode can throw on, in $script:checked strict-mode script(s)."
    exit 1
}
if (-not $script:checked) {
    Write-Host "FAILED - strict-list-check: none of the $($files.Count) script(s) read sets strict mode, so no read was checked."
    exit 1
}
Write-Host "OK - strict-list-check: no unsafe .$($properties -join '/.') read in $script:checked strict-mode script(s)."
exit 0
