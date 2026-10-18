<#
.SYNOPSIS
    Compares the resource counts of runs with a mod and runs without it, and prints each resource
    one side places and the other places on no surface. Exit 0 means the comparison was printed,
    whatever it found; exit 1 means it refused, and printed only why.

.DESCRIPTION
    WHAT IT READS. The JSONs count-resources.ps1 copies out of grado-count, at tick 600: -With
    the runs with the mod -Under names, -Without the runs without it. A side may be more than
    one JSON, because the square counted may differ by surface, as Nauvis from a radius-48 run
    and the other planets from a radius-24 run. For each surface it takes the JSON that generated
    the most chunks there. It writes nothing.

    WHAT IT PRINTS. Each resource placed, an entity of it counted, on some surface on one side
    and on no surface on the other, either way. Then per surface what each side places there and
    the other does not. A resource neither side places is no difference and is not listed. This
    is the rule trulsjo/grado-factorio-modpack ruled for rso-mod's membership, in its
    docs/decisions.md (grado-factorio-tools#161): an ore counts when it is placed without the mod
    and unplaced with it, on the same seed and set, and unplaced means no planet has an entity of
    it in the area counted. The area is not decided here: each square is read from the JSONs.

    WHEN IT REFUSES, it prints why and nothing else:
      - a JSON lacks the map seed, tick 600's counts, or a surface's radius, as one written by
        grado-count before 0.1.0 does;
      - the seeds differ, between the sides or inside one;
      - a side's JSONs differ in active_mods, so they are not one set;
      - the mod -Under names is not active on the with side, or is on the without side;
      - the two sides' active_mods differ in a mod's name or version other than -Under's and
        those -AlsoDiffers names: the "same set" of the rule;
      - a surface is counted on one side only;
      - a surface's square differs between the two sides.

    WHAT IT CANNOT SEE. Anything grado-count cannot, which its control.lua lists: an ore placed
    only outside the square reads as unplaced. Whether the mods on disk were the ones named:
    active_mods holds names and versions, so a changed copy of a mod at the same version, as a
    guarded rso-mod, is the same set to it. How many entities differ: placed is one or more.

.PARAMETER With
    The JSONs of the runs with the mod.

.PARAMETER Without
    The JSONs of the runs without it.

.PARAMETER Under
    The mod the comparison is about.

.PARAMETER AlsoDiffers
    Mods that may also differ between the sides, as the pack mods that require -Under's mod and
    so leave with it.

.PARAMETER SelfTest
    Compare fixture JSONs in a temp directory: each refusal refuses, and a resource neither side
    places is not reported. No game.

.EXAMPLE
    pwsh -File scripts/compare-resource-counts.ps1 -Under rso-mod `
        -With counts/abcs-rso-r48.json,counts/abcs-rso-r24.json `
        -Without counts/abcs-norso-r48.json,counts/abcs-norso-r24.json `
        -AlsoDiffers Grado_ABC,Grado_ABCS,Grado_ChangingBase,Grado_NonChanging
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string[]] $With = @(),
    [string[]] $Without = @(),
    [string] $Under,
    [string[]] $AlsoDiffers = @(),
    [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Keys($table) { if ($table -is [System.Collections.IDictionary]) { @($table.Keys) } else { @() } }

function Read-Side([string[]] $Paths, [string] $Label, $Refusals) {
    foreach ($path in $Paths) {
        $j = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
        $leaf = Split-Path $path -Leaf
        $counts = if ($j.counts -is [System.Collections.IDictionary]) { $j.counts['t600'] }
        $lacks = @(if ($null -eq $j['seed']) { 'the map seed' }
            if ($counts -isnot [System.Collections.IDictionary]) { "tick 600's counts" }
            else { foreach ($s in $counts.Keys) { if ($null -eq $counts[$s]['radius']) { "$s's radius" } } }
            if ($j['active_mods'] -isnot [System.Collections.IDictionary]) { 'active_mods' })
        if ($lacks) { $Refusals.Add("$Label $leaf lacks $($lacks -join ', '): it was not written by grado-count 0.1.0 or later"); continue }
        [pscustomobject]@{ Leaf = $leaf; Seed = $j.seed; Mods = $j.active_mods; Surfaces = $counts }
    }
}

function Format-Names($names) { if ($names) { (@($names) | Sort-Object) -join ', ' } else { 'none' } }

function Get-ModDifference($a, $b) {
    @(@(Get-Keys $a) + @(Get-Keys $b) | Sort-Object -Unique | Where-Object { "$($a[$_])" -cne "$($b[$_])" })
}

function Compare-ResourceCount {
    <#  Returns Refused, and Lines: the refusals when it refused, the comparison when not.  #>
    param([string[]] $With, [string[]] $Without, [string] $Under, [string[]] $AlsoDiffers = @())

    $refusals = [System.Collections.Generic.List[string]]::new()
    $sides = [ordered]@{ with = @(Read-Side $With 'with' $refusals); without = @(Read-Side $Without 'without' $refusals) }
    $refused = { [pscustomobject]@{ Refused = $true; Lines = @($refusals) } }
    if ($refusals.Count) { return & $refused }

    $seeds = @{ with = @($sides.with.Seed | Sort-Object -Unique); without = @($sides.without.Seed | Sort-Object -Unique) }
    if ($seeds.with.Count -gt 1 -or $seeds.without.Count -gt 1 -or "$($seeds.with)" -ne "$($seeds.without)") {
        $refusals.Add("the seeds differ: with $($seeds.with -join ' and '), without $($seeds.without -join ' and ')")
    }
    foreach ($label in $sides.Keys) {
        $first = $sides[$label][0]
        foreach ($run in $sides[$label] | Select-Object -Skip 1) {
            $d = Get-ModDifference $first.Mods $run.Mods
            if ($d) { $refusals.Add("the $label side is not one set: $($first.Leaf) and $($run.Leaf) differ in $(Format-Names $d)") }
        }
    }
    $modsWith = $sides.with[0].Mods; $modsWithout = $sides.without[0].Mods
    if (-not $modsWith.Contains($Under)) { $refusals.Add("-Under $Under is not active on the with side") }
    if ($modsWithout.Contains($Under)) { $refusals.Add("-Under $Under is active on the without side") }
    $differs = @(Get-ModDifference $modsWith $modsWithout)
    $unnamed = @($differs | Where-Object { $_ -cne $Under -and $_ -cnotin $AlsoDiffers })
    if ($unnamed) { $refusals.Add("not the same set: active_mods also differ in $(Format-Names $unnamed), which neither -Under nor -AlsoDiffers names") }

    # Per surface, the run that generated the most chunks of it.
    $pick = @{}
    foreach ($label in $sides.Keys) {
        $pick[$label] = @{}
        foreach ($run in $sides[$label]) {
            foreach ($s in $run.Surfaces.Keys) {
                $c = $run.Surfaces[$s]
                if (-not $pick[$label].ContainsKey($s) -or $c.chunks -gt $pick[$label][$s].Count.chunks) { $pick[$label][$s] = @{ Count = $c; Leaf = $run.Leaf } }
            }
        }
    }
    $surfaces = @(@($pick.with.Keys) + @($pick.without.Keys) | Sort-Object -Unique)
    $side = { param($r) 2 * $r + 1 }
    foreach ($s in $surfaces) {
        $a = $pick.with[$s]; $b = $pick.without[$s]
        if (-not $a -or -not $b) { $refusals.Add("$s is counted on the $(if ($a) { 'with' } else { 'without' }) side only"); continue }
        if ($a.Count.radius -ne $b.Count.radius) {
            $refusals.Add("$s's square differs: $(& $side $a.Count.radius) chunks a side with, $(& $side $b.Count.radius) without")
        }
    }
    if ($refusals.Count) { return & $refused }

    $placed = { param($p) @(Get-Keys $p.Count.resources | Where-Object { $p.Count.resources[$_] -gt 0 }) }
    $all = @{ with = @(); without = @() }
    $rows = foreach ($s in $surfaces) {
        $a = & $placed $pick.with[$s]; $b = & $placed $pick.without[$s]
        $all.with += $a; $all.without += $b
        $n = & $side $pick.with[$s].Count.radius
        "- ${s}, $n by $n chunks ($($pick.with[$s].Leaf) and $($pick.without[$s].Leaf)): placed without and not with: " +
            "$(Format-Names @($b | Where-Object { $_ -cnotin $a })); placed with and not without: $(Format-Names @($a | Where-Object { $_ -cnotin $b }))"
    }
    $lost = @($all.without | Sort-Object -Unique | Where-Object { $_ -cnotin $all.with })
    $gained = @($all.with | Sort-Object -Unique | Where-Object { $_ -cnotin $all.without })
    $lines = @(
        "compare-resource-counts: seed $($seeds.with), $($surfaces.Count) surface(s), with $Under against without it."
        $(if ($differs | Where-Object { $_ -cne $Under }) { "Also differs, as -AlsoDiffers allows: $(Format-Names @($differs | Where-Object { $_ -cne $Under }))." })
        ''
        "Placed without $Under, and on no surface with it: $(Format-Names $lost)."
        "Placed with $Under, and on no surface without it: $(Format-Names $gained)."
        ''
        'Per surface:'
        ''
    ) + @($rows)
    [pscustomobject]@{ Refused = $false; Lines = @($lines | Where-Object { $null -ne $_ }) }
}

function Invoke-SelfTest {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "compare-resource-counts-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -ItemType Directory -Path $temp | Out-Null
    try {
        $mods = @{ base = '2.0.77'; 'space-age' = '2.0.77'; 'grado-count' = '0.1.0' }
        # A run: its seed, its mods, and per surface a radius and the resources it places.
        $write = {
            param([string] $name, [hashtable] $surfaces, [hashtable] $extraMods = @{}, $seed = 140140, [switch] $old)
            $counts = @{}
            foreach ($s in $surfaces.Keys) {
                $r, $res = $surfaces[$s]
                $counts[$s] = @{ seed = $seed + $s.Length; chunks = [math]::Pow(2 * $r + 1, 2); resources = $res }
                if (-not $old) { $counts[$s].radius = $r }
            }
            $m = $mods.Clone(); foreach ($k in $extraMods.Keys) { $m[$k] = $extraMods[$k] }
            $doc = @{ counts = @{ t120 = $counts; t600 = $counts }; active_mods = $m; prototypes = @{ "never-placed" = @{ autoplace = $true } } }
            if (-not $old) { $doc.seed = $seed }
            $path = Join-Path $temp "$name.json"
            $doc | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path
            $path
        }
        $rso = @{ 'rso-mod' = '7.0.26' }
        # With: rso-mod hides ore-b everywhere, and ore-x on Nauvis's r24 square (the r48 file
        # still has it there). Neither side places never-placed, an empty table on Vulcanus.
        $w48 = & $write 'w48' @{ nauvis = 48, @{ 'ore-a' = 5; 'ore-x' = 1 } } $rso
        $w24 = & $write 'w24' @{ nauvis = 24, @{ 'ore-a' = 2 }; vulcanus = 24, @{ 'never-placed' = 0 } } $rso
        $o48 = & $write 'o48' @{ nauvis = 48, @{ 'ore-a' = 5; 'ore-b' = 3; 'ore-x' = 2 } }
        $o24 = & $write 'o24' @{ nauvis = 24, @{ 'ore-a' = 2 }; vulcanus = 24, @{ 'ore-b' = 1 } }
        $run = { param($with, $without, $also = @()) Compare-ResourceCount -With $with -Without $without -Under 'rso-mod' -AlsoDiffers $also }
        $ok = & $run @($w48, $w24) @($o48, $o24)
        $okText = $ok.Lines -join "`n"
        $refuses = { param($r, $pattern) $r.Refused -and ($r.Lines -join "`n") -match $pattern -and ($r.Lines -join "`n") -notmatch 'Placed' }

        $cases = [ordered]@{
            'a resource placed without and on no surface with is reported' = -not $ok.Refused -and $okText -match '(?m)^Placed without rso-mod, and on no surface with it: ore-b\.$'
            'nothing is reported the other way'                            = $okText -match '(?m)^Placed with rso-mod, and on no surface without it: none\.$'
            'per surface, what one side places and the other does not'     = $okText -match '(?m)^- vulcanus, 49 by 49 chunks \(w24\.json and o24\.json\): placed without and not with: ore-b; placed with and not without: none$'
            'each surface is read from the run with the most chunks there' = $okText -match '(?m)^- nauvis, 97 by 97 chunks \(w48\.json and o48\.json\): placed without and not with: ore-b;'
            'a resource neither side places is not reported'               = $okText -notmatch 'never-placed'
            'it refuses different seeds'                                   = & $refuses (& $run @($w48) @((& $write 'o48s' @{ nauvis = 48, @{ 'ore-a' = 1 } } -seed 307307))) 'the seeds differ: with 140140, without 307307'
            'it refuses a side of two seeds'                               = & $refuses (& $run @($w48, (& $write 'w24s' @{ vulcanus = 24, @{} } $rso -seed 307307)) @($o48, $o24)) 'the seeds differ'
            'it refuses different squares'                                 = & $refuses (& $run @($w48) @($o24)) "nauvis's square differs: 97 chunks a side with, 49 without"
            'it refuses a surface counted on one side only'                = & $refuses (& $run @($w48, $w24) @($o48)) 'vulcanus is counted on the with side only'
            'it refuses a mod that differs and is not named'               = & $refuses (& $run @($w48) @((& $write 'o48m' @{ nauvis = 48, @{} } @{ 'Grado_ABC' = '0.1.0' }))) 'not the same set: active_mods also differ in Grado_ABC'
            'a mod -AlsoDiffers names is let through'                      = -not (& $run @($w48) @((& $write 'o48a' @{ nauvis = 48, @{} } @{ 'Grado_ABC' = '0.1.0' })) @('Grado_ABC')).Refused
            'it refuses a version that differs and is not named'           = & $refuses (& $run @($w48) @((& $write 'o48v' @{ nauvis = 48, @{} } @{ base = '2.0.76' }))) 'also differ in base'
            'it refuses -Under absent from the with side'                  = & $refuses (& $run @($o48) @($o48)) '-Under rso-mod is not active on the with side'
            'it refuses -Under active on the without side'                 = & $refuses (& $run @($w48) @($w48)) '-Under rso-mod is active on the without side'
            "it refuses a side whose runs are not one set"                 = & $refuses (& $run @($w48, (& $write 'w24m' @{ vulcanus = 24, @{} } ($rso + @{ extra = '1.0.0' }))) @($o48, $o24)) 'the with side is not one set'
            'it refuses a JSON from before radius was written'             = & $refuses (& $run @((& $write 'old' @{ nauvis = 48, @{} } $rso -old)) @($o48)) 'with old\.json lacks the map seed, nauvis''s radius'
        }
        $failures = 0; $n = 0
        foreach ($name in $cases.Keys) {
            $n++
            Write-Host ("self-test {0}/{1}: {2} -- {3}" -f $n, $cases.Count, $name, $(if ($cases[$name]) { 'ok' } else { 'FAILED' }))
            if (-not $cases[$name]) { $failures++ }
        }
        Write-Host ''
        if ($failures) { Write-Host $okText; Write-Host "FAILED - self-test: $failures of $($cases.Count) case(s) did not hold."; exit 1 }
        Write-Host "OK - self-test passed: all $($cases.Count) cases."
        exit 0
    }
    finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}

if ($SelfTest) { Invoke-SelfTest }
# Under pwsh -File a comma list arrives as one string.
$With, $Without, $AlsoDiffers = foreach ($list in $With, $Without, $AlsoDiffers) { , @($list | ForEach-Object { $_ -split ',' } | Where-Object { $_ }) }
if (-not $With -or -not $Without -or -not $Under) { throw 'Name -With and -Without JSONs from count-resources.ps1, and -Under the mod. Or -SelfTest.' }
$result = Compare-ResourceCount -With $With -Without $Without -Under $Under -AlsoDiffers $AlsoDiffers
if ($result.Refused) {
    Write-Host 'REFUSED - compare-resource-counts:'
    $result.Lines | ForEach-Object { Write-Host "  - $_" }
    exit 1
}
$result.Lines | ForEach-Object { Write-Host $_ }
exit 0
