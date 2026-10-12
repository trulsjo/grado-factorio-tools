<#
.SYNOPSIS
    Prints, as Markdown, what differs between two --dump-data dumps: the prototypes one has and
    the other has not, by type, and those both have that differ, by the fields that differ. Exit 0
    means the comparison was printed, whatever it found.

.DESCRIPTION
    WHAT IT READS. Two dumps, e.g. a staged pack and the same pack with one member disabled, both
    from get-dump.ps1. The first is "with" and the second "without": a prototype in the first
    alone is "added". It writes nothing.

    HOW TWO PROTOTYPES ARE COMPARED. Field for field, at the top level of the prototype: a field
    is named when its value differs anywhere inside it, or when one side lacks it. Key order
    inside a table does not count.

    WHAT IT CANNOT SEE. Which mod made a difference: with one member disabled it is that member
    or anything that reacts to it. What a mod does at run time. And time: the data stage's
    seconds are in the dump's log, which get-dump.ps1 keeps beside it.

.PARAMETER With
    The first dump.

.PARAMETER Without
    The second dump.

.PARAMETER MaxNames
    A row lists its names when it has this many or fewer, and counts them otherwise.

.PARAMETER SelfTest
    Compare two fixture dumps in a temp directory and check what is printed. No game.

.EXAMPLE
    pwsh -File scripts/dump-diff.ps1 <dump of the pack> <dump with one member disabled>
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [Parameter(Position = 0)] [string] $With,
    [Parameter(Position = 1)] [string] $Without,
    [int] $MaxNames = 20,
    [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'dump-lib.ps1')

function Write-DumpDifference {
    param([Parameter(Mandatory)] [string] $With, [Parameter(Mandatory)] [string] $Without, [int] $MaxNames = 20)
    $docWith = Open-Dump $With
    $docWithout = Open-Dump $Without
    try {
        $a = Get-DumpIndex $docWith
        $b = Get-DumpIndex $docWithout
        $names = { param($list) if ($list.Count -le $MaxNames) { Format-Names $list } else { '' } }
        $added = [ordered]@{}; $removed = [ordered]@{}; $changed = [ordered]@{}
        $total = @{ With = 0; Without = 0; Added = 0; Removed = 0; Changed = 0 }
        foreach ($type in @($a.Keys) + @($b.Keys) | Sort-Object -Unique) {
            $left = $a[$type] ?? @{}; $right = $b[$type] ?? @{}
            $total.With += $left.Count; $total.Without += $right.Count
            $new = @($left.Keys | Where-Object { -not $right.ContainsKey($_) })
            $old = @($right.Keys | Where-Object { -not $left.ContainsKey($_) })
            if ($new) { $added[$type] = $new; $total.Added += $new.Count }
            if ($old) { $removed[$type] = $old; $total.Removed += $old.Count }
            foreach ($name in $left.Keys) {
                if (-not $right.ContainsKey($name) -or $left[$name].GetRawText() -ceq $right[$name].GetRawText()) { continue }
                $fields = @(Compare-DumpElement $left[$name] $right[$name])
                if (-not $fields) { continue }
                $key = "$type`t$($fields -join ', ')"
                $changed[$key] = @(@($changed[$key]) + $name | Where-Object { $_ })
                $total.Changed++
            }
        }
        $size = { param($path) ((Get-Item -LiteralPath $path).Length / 1e6).ToString('0.0', [cultureinfo]::InvariantCulture) + ' MB' }
        Format-MarkdownTable '', 'With', 'Without' @(
            , @('Prototypes', (Format-Count $total.With), (Format-Count $total.Without))
            , @('Size of the dump', (& $size $With), (& $size $Without))
        )
        ''
        "**$(Format-Count $total.Added) prototypes are in the first dump alone, $(Format-Count $total.Removed) in the second alone, and $(Format-Count $total.Changed) are in both and differ.**"
        foreach ($set in @{ Title = 'In the first dump alone'; Rows = $added }, @{ Title = 'In the second dump alone'; Rows = $removed }) {
            if (-not $set.Rows.Count) { continue }
            ''; "$($set.Title):"; ''
            Format-MarkdownTable 'Type', 'Count', 'Names' @(foreach ($type in $set.Rows.Keys) { , @("``$type``", (Format-Count $set.Rows[$type].Count), (& $names $set.Rows[$type])) })
        }
        if ($changed.Count) {
            ''; 'In both, and different:'; ''
            Format-MarkdownTable 'Type', 'Fields that differ', 'Count', 'Names' @(
                foreach ($key in $changed.Keys) { $type, $fields = $key -split "`t"; , @("``$type``", $fields, (Format-Count $changed[$key].Count), (& $names $changed[$key])) })
        }
    }
    finally { $docWith.Dispose(); $docWithout.Dispose() }
}

function Invoke-SelfTest {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "dump-diff-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -ItemType Directory -Path $temp | Out-Null
    try {
        $with = Join-Path $temp 'with.json'; $without = Join-Path $temp 'without.json'
        Set-Content -LiteralPath $with -Value '{"recipe":{"a":{"name":"a","order":"x","ingredients":[{"name":"i","amount":1}]},"b":{"name":"b","k":{"p":1,"q":2}},"new":{"name":"new"}},"item":{"only":{"name":"only"}},"fluid":{"f":{"flags":["x"],"e":[],"n":[[1,2]]}}}'
        Set-Content -LiteralPath $without -Value '{"recipe":{"a":{"name":"a","order":"y","ingredients":[{"name":"i","amount":2}]},"b":{"k":{"q":2,"p":1},"name":"b"},"old":{"name":"old"}},"fluid":{"f":{"flags":"x","e":null,"n":[1,2]}}}'
        $out = (Write-DumpDifference $with $without) -join "`n"
        $cases = [ordered]@{
            'the totals count each side'                               = $out -match '\| Prototypes \| 5 \| 4 \|'
            'added, removed and changed are counted'                   = $out -match '\*\*2 prototypes are in the first dump alone, 1 in the second alone, and 2 are in both and differ\.\*\*'
            'a type one side lacks is listed'                          = $out -match '\| `item` \| 1 \| `only` \|'
            'a change is listed by the fields that differ'             = $out -match '\| `recipe` \| ingredients, order \| 1 \| `a` \|'
            'key order inside a table is not a difference'             = $out -notmatch '`b`'
            'a list of one is not its element, nor an empty list nothing' = $out -match '\| `fluid` \| e, flags, n \| 1 \| `f` \|'
            'a row over -MaxNames counts and does not list'            = ((Write-DumpDifference $with $without -MaxNames 0) -join "`n") -match '\| `recipe` \| ingredients, order \| 1 \|  \|'
        }
        $failures = 0; $n = 0
        foreach ($name in $cases.Keys) {
            $n++
            Write-Host ("self-test {0}/{1}: {2} -- {3}" -f $n, $cases.Count, $name, $(if ($cases[$name]) { 'ok' } else { 'FAILED' }))
            if (-not $cases[$name]) { $failures++ }
        }
        Write-Host ''
        if ($failures) { Write-Host $out; Write-Host "FAILED - self-test: $failures of $($cases.Count) case(s) did not hold."; exit 1 }
        Write-Host "OK - self-test passed: all $($cases.Count) cases."
        exit 0
    }
    finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}

if ($SelfTest) { Invoke-SelfTest }
if (-not $With -or -not $Without) { throw 'Name two dumps; get-dump.ps1 gives a path. Or -SelfTest.' }
Write-DumpDifference -With $With -Without $Without -MaxNames $MaxNames
exit 0
