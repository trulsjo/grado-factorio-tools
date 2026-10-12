<#
.SYNOPSIS
    Prints, as Markdown, the prototype names two mod sets each define on their own, and which
    definition a dump of the two together holds. Exit 0 means the tables were printed.

.DESCRIPTION
    WHAT IT READS. Four dumps from get-dump.ps1, and it writes nothing:

      -Base    neither set: the game alone
      -First   the first set alone, e.g. Space Age
      -Second  the second set alone, e.g. an overhaul pack, base only
      -Both    the two together

    A SHARED NAME is a type and name that -First has and -Second has and -Base has not. When two
    mods define one name the game keeps one prototype and logs nothing, so this is the only
    place the collision shows (grado-factorio-modpack#134).

    WHAT -Both HOLDS, per name: the first's when its prototype is the same as in -First, field
    for field; the second's when it is the same as in -Second; both when the two are the same;
    and mixed when it is neither, with the top-level fields in which it differs from each.

    WHAT IT CANNOT SEE. Which mod wrote the definition, and why: that is read from the mods'
    source. A name both sets change that -Base already has. And a name one set defines only
    when the other is loaded.

.PARAMETER SelfTest
    Compare four fixture dumps in a temp directory and check what is printed. No game.

.EXAMPLE
    pwsh -File scripts/dump-shared-names.ps1 -Base <base> -First <Space Age> -Second <pack> -Both <pack with Space Age>
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $Base,
    [string] $First,
    [string] $Second,
    [string] $Both,
    [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'dump-lib.ps1')

function Write-SharedNames {
    param([Parameter(Mandatory)] [string] $Base, [Parameter(Mandatory)] [string] $First, [Parameter(Mandatory)] [string] $Second, [Parameter(Mandatory)] [string] $Both)
    $docs = @($Base, $First, $Second, $Both | ForEach-Object { Open-Dump $_ })
    try {
        # Not $base and so on: a variable name is the parameter of that name whatever its case.
        $inBase, $inFirst, $inSecond, $inBoth = $docs | ForEach-Object { Get-DumpIndex $_ }
        $firstLabel = Get-DumpLabel $First; $secondLabel = Get-DumpLabel $Second; $bothLabel = Get-DumpLabel $Both
        $shared = [ordered]@{}
        foreach ($type in $inFirst.Keys | Sort-Object) {
            if (-not $inSecond.ContainsKey($type)) { continue }
            $names = [string[]] @($inFirst[$type].Keys | Where-Object { $inSecond[$type].ContainsKey($_) -and -not ($inBase.ContainsKey($type) -and $inBase[$type].ContainsKey($_)) })
            [Array]::Sort($names, [StringComparer]::Ordinal)
            if ($names) { $shared[$type] = $names }
        }
        $count = ($shared.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
        "**$([int] $count) prototype names are defined by $firstLabel and by $secondLabel, and are not in $(Get-DumpLabel $Base).**"
        if (-not $count) { return }
        ''
        Format-MarkdownTable 'Type', 'Count', 'Names' @(foreach ($type in $shared.Keys) { , @("``$type``", $shared[$type].Count, (Format-Names $shared[$type])) })
        ''
        $tally = [ordered]@{ "the first's" = 0; "the second's" = 0; 'both' = 0; 'mixed' = 0; 'not there' = 0 }
        $rows = foreach ($type in $shared.Keys) {
            foreach ($name in $shared[$type]) {
                if (-not ($inBoth.ContainsKey($type) -and $inBoth[$type].ContainsKey($name))) { $tally['not there']++; , @("``$name``", "``$type``", 'not there', '', ''); continue }
                $fromFirst = @(Compare-DumpElement $inBoth[$type][$name] $inFirst[$type][$name])
                $fromSecond = @(Compare-DumpElement $inBoth[$type][$name] $inSecond[$type][$name])
                $holds = if (-not $fromFirst -and -not $fromSecond) { 'both' } elseif (-not $fromFirst) { "the first's" } elseif (-not $fromSecond) { "the second's" } else { 'mixed' }
                $tally[$holds]++
                , @("``$name``", "``$type``", $holds, ($fromFirst -join ', '), ($fromSecond -join ', '))
            }
        }
        "What $bothLabel holds for each. The first is $firstLabel and the second is ${secondLabel}:"
        ''
        Format-MarkdownTable 'Name', 'Type', 'Holds', 'Differs from the first in', 'Differs from the second in' @($rows)
        ''
        "Of the $([int] $count): $(@($tally.Keys | Where-Object { $tally[$_] } | ForEach-Object { "$($tally[$_]) $_" }) -join ', ')."
    }
    finally { $docs | ForEach-Object { $_.Dispose() } }
}

function Invoke-SelfTest {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "dump-shared-names-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -ItemType Directory -Path $temp | Out-Null
    try {
        $put = { param($name, $json) $path = Join-Path $temp "$name.json"; Set-Content -LiteralPath $path -Value $json; $path }
        $base = & $put 'base' '{"item":{"old":{"name":"old","v":0}}}'
        $first = & $put 'first' '{"item":{"old":{"name":"old","v":1},"a":{"name":"a","v":1},"b":{"name":"b","v":1},"c":{"name":"c","v":1,"w":1},"d":{"name":"d"},"mine":{"name":"mine"}},"fluid":{"a":{"name":"a"}}}'
        $second = & $put 'second' '{"item":{"old":{"name":"old","v":2},"a":{"name":"a","v":2},"b":{"name":"b","v":2},"c":{"name":"c","v":2,"w":2},"d":{"name":"d"}},"recipe":{"a":{"name":"a"}}}'
        $both = & $put 'both' '{"item":{"old":{"name":"old","v":2},"a":{"name":"a","v":1},"b":{"name":"b","v":2},"c":{"name":"c","v":1,"w":2},"d":{"name":"d"}}}'
        $out = (Write-SharedNames -Base $base -First $first -Second $second -Both $both) -join "`n"
        $cases = [ordered]@{
            'a name the base has, and a name one set has, are not shared' = $out -match '\*\*4 prototype names' -and $out -notmatch '`old`|`mine`'
            'a name shared across two types is not shared'                = $out -notmatch '`fluid`|`recipe`'
            "the first's, the second's, both and mixed are told apart"    = $out -match "\| ``a`` \| ``item`` \| the first's \|  \| v \|" -and $out -match "\| ``b`` \| ``item`` \| the second's \| v \|  \|" -and
                $out -match '\| `c` \| `item` \| mixed \| w \| v \|' -and $out -match '\| `d` \| `item` \| both \|  \|  \|'
            'the tally adds up'                                           = $out -match "Of the 4: 1 the first's, 1 the second's, 1 both, 1 mixed\."
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
if (-not ($Base -and $First -and $Second -and $Both)) { throw 'Name four dumps: -Base, -First, -Second and -Both; get-dump.ps1 gives a path. Or -SelfTest.' }
Write-SharedNames -Base $Base -First $First -Second $Second -Both $Both
exit 0
